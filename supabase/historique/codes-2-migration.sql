-- ============================================================
-- ORIMETIER — Circuit des établissements, cycle B, étape B1 : sécurité des codes de récupération.
-- FICHIER 2 : MIGRATION.
--
-- ORDRE D'EXÉCUTION (SQL Editor de Supabase, chaque fichier EN ENTIER) :
--   1. codes-1-test.sql       test à blanc : DOIT finir sur l'erreur « TEST À BLANC RÉUSSI : tout a
--                             été annulé automatiquement (aucune donnée modifiée) ». Toute autre
--                             erreur (GARDE ..., ÉCHEC ...) = vrai échec : ne pas lancer le 2.
--   2. codes-2-migration.sql  installation pour de bon, puis le tableau (n, controle, ok) : TOUTES
--                             les lignes à true.
-- PAS DE BEGIN / COMMIT / ROLLBACK : chaque fichier tient dans UN bloc DO, atomique à lui seul
-- (validé s'il va au bout, annulé entièrement à la moindre exception, DDL compris).
-- Les blocs GARDES et INSTALLATION sont identiques, mot pour mot, dans les deux fichiers.
--
-- ÉTAT ACTUEL (relevé dans le dépôt) : code_recuperation = 8 signes tirés avec random() (non
-- cryptographique), index unique etablissements_code_recuperation_idx ; etablissement_claim_by_code
-- (anon) cherche la fiche par le CODE SEUL, sans limite ni journal ; lecture des codes par
-- admin_list_unclaimed_codes(_v2) / admin_list_all_etablissement_codes(_v2) (inchangées).
--
-- CE QUE B1 INSTALLE :
--   - etablissement_code_essais : essais de réclamation (echec / succes / remise_a_zero), SANS le
--     code saisi ; etablissement_code_journal : regeneration / annulation (admin_id) et
--     reclamation. RLS activée, aucun droit pour anon / authenticated.
--   - _etab_generer_code() (interne) : 8 signes parmi 31 (ni O/0, ni I/1/L), gen_random_bytes,
--     sans biais, unique.
--   - etablissement_claim_v2(p_etab_id, p_code, p_email, p_password, contacts facultatifs) -> jsonb
--     (anon) : la fiche est cherchée par son ID, le code n'est comparé qu'à celui de CETTE fiche ;
--     5 échecs par heure et par fiche, puis TROP_D_ESSAIS avec reessayer_dans_s et un message ;
--     un succès ou une régénération remet le compteur à zéro ; à la réclamation le code est effacé.
--     Renvoie {ok:true, id} ou {ok:false, erreur: CHAMPS_OBLIGATOIRES | FICHE_INTROUVABLE |
--     FICHE_DEJA_RECLAMEE | TROP_D_ESSAIS | CODE_INVALIDE (+ essais_restants) | EMAIL_DEJA_UTILISE}.
--   - admin_lire_code_v2, admin_regenerer_code_v2, admin_annuler_code_v2 (p_token, p_etab_id) :
--     _session_user(p_token, 'admin') en premier ; FICHE_INTROUVABLE, FICHE_DEJA_RECLAMEE.
--   - etablissement_claim_by_code (code seul) : conservée, mais plus exécutable par anon /
--     authenticated / PUBLIC (le front passera à etablissement_claim_v2 à l'étape B2).
--   - code_recuperation : plus aucun droit direct pour anon / authenticated.
-- GARDES : 4 171 fiches ; exactement 1 fiche réclamée ; aucune clé étrangère vers etablissements ;
--   colonne et index du code présents ; B1 pas encore installée. Sinon arrêt, rien n'est modifié.
-- SIGNALÉ SANS CORRECTION (étape séparée, après B2 et avant le courrier) : lecture directe par la
--   clé publique de email, tel, responsable... et INSERT direct dans etablissements, s'ils existent.
-- ============================================================

-- Ce fichier : un bloc DO (gardes + installation), validé s'il va au bout ; puis la requête
-- finale (n, controle, ok). Relancé après une installation réussie, il s'arrête sur la garde
-- « B1 déjà installée » sans rien modifier.

DO $migration$
declare
  v_n integer; v_m integer; v_txt text; v_sql text; v_priv text; v_roles text[]; v_cols text;
begin
  -- ================= GARDES : arrêt sans rien modifier si la base n'est pas dans l'état attendu
  select count(*) into v_n from public.etablissements;
  if v_n is distinct from 4171 then
    raise exception 'GARDE : % fiches dans etablissements au lieu de 4 171 : rien n''est modifié.', v_n;
  end if;
  select count(*) into v_n from public.etablissements e where coalesce(e.reclame, false);
  if v_n is distinct from 1 then
    raise exception 'GARDE : % fiche(s) réclamée(s) au lieu de 1 : rien n''est modifié.', v_n;
  end if;
  if exists (select 1 from pg_constraint c where c.contype = 'f' and c.confrelid = 'public.etablissements'::regclass) then
    raise exception 'GARDE : une clé étrangère inattendue pointe vers etablissements : rien n''est modifié.';
  end if;
  if not exists (select 1 from information_schema.columns c
                 where c.table_schema = 'public' and c.table_name = 'etablissements' and c.column_name = 'code_recuperation') then
    raise exception 'GARDE : colonne etablissements.code_recuperation absente : rien n''est modifié.';
  end if;
  if to_regclass('public.etablissements_code_recuperation_idx') is null then
    raise exception 'GARDE : index unique etablissements_code_recuperation_idx absent : rien n''est modifié.';
  end if;
  if to_regprocedure('public._session_user(text,text)') is null
     or to_regprocedure('public.etablissement_session_open(text,text)') is null
     or to_regprocedure('public.etablissement_claim_by_code(text,text,text,text,text,text,text,text,text)') is null then
    raise exception 'GARDE : _session_user, etablissement_session_open ou etablissement_claim_by_code absente : rien n''est modifié.';
  end if;
  if to_regclass('public.etablissement_code_essais') is not null
     or to_regclass('public.etablissement_code_journal') is not null
     or to_regprocedure('public.etablissement_claim_v2(text,text,text,text,text,text,text,text,text,text)') is not null then
    raise exception 'GARDE : l''étape B1 semble déjà installée (tables ou etablissement_claim_v2 présentes) : rien n''est modifié.';
  end if;

  -- Signalement SANS correction (étape séparée, après B2 et avant le courrier)
  select string_agg(r.role || '.' || col.c, ', ' order by r.role, col.c) into v_txt
  from unnest(array['anon', 'authenticated']) as r(role),
       unnest(array['email', 'tel', 'tel2', 'tel3', 'responsable', 'contact_tel', 'site_web']) as col(c)
  where has_column_privilege(r.role, 'public.etablissements', col.c, 'SELECT');
  if v_txt is not null then
    raise notice 'ATTENTION (non corrigé ici) : lecture DIRECTE possible par la clé publique, hors masquage Premium : %', v_txt;
  end if;
  select string_agg(r.role, ', ') into v_txt from unnest(array['anon', 'authenticated']) as r(role)
  where has_any_column_privilege(r.role, 'public.etablissements', 'INSERT');
  if v_txt is not null then
    raise notice 'ATTENTION (non corrigé ici) : INSERT DIRECT possible dans etablissements pour : %', v_txt;
  end if;
  select string_agg(r.role || ':' || p.p, ', ') into v_txt
  from unnest(array['anon', 'authenticated']) as r(role), unnest(array['SELECT', 'INSERT', 'UPDATE', 'REFERENCES']) as p(p)
  where has_column_privilege(r.role, 'public.etablissements', 'code_recuperation', p.p);
  raise notice 'Avant B1 : droits de la clé publique sur code_recuperation : %', coalesce(v_txt, 'aucun');

  -- ================= INSTALLATION (chaque instruction exécutée dans ce même bloc)
  foreach v_sql in array array[

-- 1) Journal des essais de réclamation : jamais le code saisi
$ddl$CREATE TABLE public.etablissement_code_essais (
  id bigserial PRIMARY KEY,
  etab_id text NOT NULL,
  resultat text NOT NULL CHECK (resultat IN ('echec', 'succes', 'remise_a_zero')),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
)$ddl$,
$ddl$CREATE INDEX etablissement_code_essais_etab_idx ON public.etablissement_code_essais (etab_id, id)$ddl$,
$ddl$COMMENT ON TABLE public.etablissement_code_essais IS 'Essais de réclamation par code (echec / succes / remise_a_zero). Le code saisi n''est jamais stocké. Accès uniquement via fonctions SECURITY DEFINER.'$ddl$,
$ddl$ALTER TABLE public.etablissement_code_essais ENABLE ROW LEVEL SECURITY$ddl$,
$ddl$REVOKE ALL ON TABLE public.etablissement_code_essais FROM PUBLIC, anon, authenticated$ddl$,
$ddl$REVOKE ALL ON SEQUENCE public.etablissement_code_essais_id_seq FROM PUBLIC, anon, authenticated$ddl$,

-- 2) Journal des actions sur les codes (qui, quand)
$ddl$CREATE TABLE public.etablissement_code_journal (
  id bigserial PRIMARY KEY,
  etab_id text NOT NULL,
  action text NOT NULL CHECK (action IN ('regeneration', 'annulation', 'reclamation')),
  admin_id text,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
)$ddl$,
$ddl$CREATE INDEX etablissement_code_journal_etab_idx ON public.etablissement_code_journal (etab_id, id)$ddl$,
$ddl$COMMENT ON TABLE public.etablissement_code_journal IS 'Actions sur les codes de récupération : regeneration / annulation (admin_id = admin) et reclamation (admin_id NULL). Accès uniquement via fonctions SECURITY DEFINER.'$ddl$,
$ddl$ALTER TABLE public.etablissement_code_journal ENABLE ROW LEVEL SECURITY$ddl$,
$ddl$REVOKE ALL ON TABLE public.etablissement_code_journal FROM PUBLIC, anon, authenticated$ddl$,
$ddl$REVOKE ALL ON SEQUENCE public.etablissement_code_journal_id_seq FROM PUBLIC, anon, authenticated$ddl$,

-- 3) Tirage d'un code : 8 signes, 31 caractères sans ambiguïté (ni O/0, ni I/1/L),
--    octets cryptographiques (gen_random_bytes), sans biais (octets >= 248 rejetés), unique
$ddl$CREATE OR REPLACE FUNCTION public._etab_generer_code()
 RETURNS text
 LANGUAGE plpgsql
 VOLATILE
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_alpha constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_code text;
  v_octets bytea;
  v_i integer;
  v_b integer;
begin
  loop
    v_code := '';
    while length(v_code) < 8 loop
      v_octets := extensions.gen_random_bytes(16);
      for v_i in 0..15 loop
        v_b := get_byte(v_octets, v_i);
        if v_b < 248 and length(v_code) < 8 then
          v_code := v_code || substr(v_alpha, (v_b % 31) + 1, 1);
        end if;
      end loop;
    end loop;
    exit when not exists (select 1 from etablissements e where e.code_recuperation = v_code);
  end loop;
  return v_code;
end; $function$$ddl$,
$ddl$REVOKE ALL ON FUNCTION public._etab_generer_code() FROM PUBLIC, anon, authenticated$ddl$,

-- 4) Réclamation : id de la fiche + code (jamais le code seul), 5 échecs / heure / fiche
--    Renvoie un jsonb (et ne lève pas d'erreur) pour que l'essai raté reste journalisé.
$ddl$CREATE OR REPLACE FUNCTION public.etablissement_claim_v2(p_etab_id text, p_code text, p_email text, p_password text, p_responsable text DEFAULT NULL::text, p_tel text DEFAULT NULL::text, p_tel2 text DEFAULT NULL::text, p_tel3 text DEFAULT NULL::text, p_site_web text DEFAULT NULL::text, p_contact_tel text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_etab etablissements%rowtype;
  v_dernier bigint;
  v_echecs integer;
  v_plus_ancien timestamptz;
  v_attente integer;
  v_contrainte text;
begin
  if coalesce(trim(p_etab_id), '') = '' or coalesce(trim(p_code), '') = ''
     or coalesce(trim(p_email), '') = '' or coalesce(p_password, '') = '' then
    return jsonb_build_object('ok', false, 'erreur', 'CHAMPS_OBLIGATOIRES');
  end if;

  -- Verrou sur la fiche : les essais simultanés sur une même fiche passent l'un après l'autre
  select e.* into v_etab from etablissements e where e.id = p_etab_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'erreur', 'FICHE_INTROUVABLE');
  end if;
  if coalesce(v_etab.reclame, false) then
    return jsonb_build_object('ok', false, 'erreur', 'FICHE_DEJA_RECLAMEE');
  end if;

  -- Échecs de la dernière heure, postérieurs au dernier succès ou à la dernière remise à zéro
  select max(c.id) into v_dernier
  from etablissement_code_essais c where c.etab_id = p_etab_id and c.resultat <> 'echec';
  select count(*), min(t.created_at) into v_echecs, v_plus_ancien
  from (select c.created_at from etablissement_code_essais c
        where c.etab_id = p_etab_id and c.resultat = 'echec'
          and c.id > coalesce(v_dernier, 0)
          and c.created_at > clock_timestamp() - interval '1 hour'
        order by c.id desc limit 5) t;
  if v_echecs >= 5 then
    v_attente := greatest(1, ceil(extract(epoch from (v_plus_ancien + interval '1 hour' - clock_timestamp())))::integer);
    return jsonb_build_object('ok', false, 'erreur', 'TROP_D_ESSAIS', 'reessayer_dans_s', v_attente,
      'message', 'Trop d''essais ratés pour cet établissement. Réessayez dans ' || ceil(v_attente / 60.0)::integer || ' minute(s).');
  end if;

  -- Le code de CETTE fiche uniquement (NULL = code annulé : aucun code n'est accepté)
  if v_etab.code_recuperation is null or upper(trim(p_code)) is distinct from v_etab.code_recuperation then
    insert into etablissement_code_essais(etab_id, resultat) values (p_etab_id, 'echec');
    return jsonb_build_object('ok', false, 'erreur', 'CODE_INVALIDE', 'essais_restants', greatest(0, 4 - v_echecs));
  end if;

  if exists (select 1 from etablissements e where lower(trim(e.email)) = lower(trim(p_email)) and e.id <> p_etab_id)
     or exists (select 1 from demandes_inscription_etablissements d
                where d.statut_demande = 'en_attente' and lower(trim(d.email)) = lower(trim(p_email))) then
    return jsonb_build_object('ok', false, 'erreur', 'EMAIL_DEJA_UTILISE');
  end if;

  begin
    update etablissements
      set email = trim(p_email), password = p_password, reclame = true, code_recuperation = null,
          responsable = coalesce(nullif(trim(p_responsable), ''), responsable),
          tel = coalesce(nullif(trim(p_tel), ''), tel),
          tel2 = coalesce(nullif(trim(p_tel2), ''), tel2),
          tel3 = coalesce(nullif(trim(p_tel3), ''), tel3),
          site_web = coalesce(nullif(trim(p_site_web), ''), site_web),
          contact_tel = coalesce(nullif(trim(p_contact_tel), ''), contact_tel)
      where id = p_etab_id;
  exception when unique_violation then
    get stacked diagnostics v_contrainte = constraint_name;
    if v_contrainte = 'etablissements_email_unique' then
      return jsonb_build_object('ok', false, 'erreur', 'EMAIL_DEJA_UTILISE');
    end if;
    raise;
  end;

  insert into etablissement_code_essais(etab_id, resultat) values (p_etab_id, 'succes');
  insert into etablissement_code_journal(etab_id, action, admin_id) values (p_etab_id, 'reclamation', null);
  return jsonb_build_object('ok', true, 'id', p_etab_id);
end; $function$$ddl$,
$ddl$REVOKE ALL ON FUNCTION public.etablissement_claim_v2(text, text, text, text, text, text, text, text, text, text) FROM PUBLIC$ddl$,
$ddl$GRANT EXECUTE ON FUNCTION public.etablissement_claim_v2(text, text, text, text, text, text, text, text, text, text) TO anon, authenticated$ddl$,

-- 5) Admin : lire le code d'une fiche (seule lecture unitaire du code)
$ddl$CREATE OR REPLACE FUNCTION public.admin_lire_code_v2(p_token text, p_etab_id text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_admin_id text;
  v_code text;
begin
  v_admin_id := _session_user(p_token, 'admin');
  select e.code_recuperation into v_code from etablissements e where e.id = p_etab_id;
  if not found then
    raise exception 'FICHE_INTROUVABLE';
  end if;
  return v_code;
end; $function$$ddl$,
$ddl$REVOKE ALL ON FUNCTION public.admin_lire_code_v2(text, text) FROM PUBLIC$ddl$,
$ddl$GRANT EXECUTE ON FUNCTION public.admin_lire_code_v2(text, text) TO anon, authenticated$ddl$,

-- 6) Admin : régénérer (nouveau code, ancien invalide, compteur d'essais remis à zéro)
$ddl$CREATE OR REPLACE FUNCTION public.admin_regenerer_code_v2(p_token text, p_etab_id text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_admin_id text;
  v_reclame boolean;
  v_code text;
begin
  v_admin_id := _session_user(p_token, 'admin');
  select coalesce(e.reclame, false) into v_reclame from etablissements e where e.id = p_etab_id for update;
  if not found then
    raise exception 'FICHE_INTROUVABLE';
  end if;
  if v_reclame then
    raise exception 'FICHE_DEJA_RECLAMEE';
  end if;
  v_code := _etab_generer_code();
  update etablissements e set code_recuperation = v_code where e.id = p_etab_id;
  insert into etablissement_code_essais(etab_id, resultat) values (p_etab_id, 'remise_a_zero');
  insert into etablissement_code_journal(etab_id, action, admin_id) values (p_etab_id, 'regeneration', v_admin_id);
  return v_code;
end; $function$$ddl$,
$ddl$REVOKE ALL ON FUNCTION public.admin_regenerer_code_v2(text, text) FROM PUBLIC$ddl$,
$ddl$GRANT EXECUTE ON FUNCTION public.admin_regenerer_code_v2(text, text) TO anon, authenticated$ddl$,

-- 7) Admin : annuler (récupération impossible jusqu'à la prochaine régénération)
$ddl$CREATE OR REPLACE FUNCTION public.admin_annuler_code_v2(p_token text, p_etab_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_admin_id text;
  v_reclame boolean;
begin
  v_admin_id := _session_user(p_token, 'admin');
  select coalesce(e.reclame, false) into v_reclame from etablissements e where e.id = p_etab_id for update;
  if not found then
    raise exception 'FICHE_INTROUVABLE';
  end if;
  if v_reclame then
    raise exception 'FICHE_DEJA_RECLAMEE';
  end if;
  update etablissements e set code_recuperation = null where e.id = p_etab_id;
  insert into etablissement_code_journal(etab_id, action, admin_id) values (p_etab_id, 'annulation', v_admin_id);
  return true;
end; $function$$ddl$,
$ddl$REVOKE ALL ON FUNCTION public.admin_annuler_code_v2(text, text) FROM PUBLIC$ddl$,
$ddl$GRANT EXECUTE ON FUNCTION public.admin_annuler_code_v2(text, text) TO anon, authenticated$ddl$,

-- 8) Ancienne réclamation par le code SEUL : plus exécutable par la clé publique (fonction conservée)
$ddl$REVOKE EXECUTE ON FUNCTION public.etablissement_claim_by_code(text, text, text, text, text, text, text, text, text) FROM PUBLIC, anon, authenticated$ddl$

  ] loop
    execute v_sql;
  end loop;

  -- ================= Le code ne doit plus être accessible directement par la clé publique.
  -- Un droit sur TOUTE la table couvrirait la colonne : il est alors remplacé par le même droit
  -- colonne par colonne, sur toutes les colonnes SAUF code_recuperation (les autres droits
  -- existants sont conservés tels quels : la fuite signalée plus haut n'est pas corrigée ici).
  foreach v_priv in array array['SELECT', 'INSERT', 'UPDATE', 'REFERENCES'] loop
    v_roles := array(select r from unnest(array['anon', 'authenticated']) as r
                     where has_table_privilege(r, 'public.etablissements', v_priv));
    if cardinality(v_roles) > 0 then
      select string_agg(quote_ident(c.column_name), ', ' order by c.ordinal_position) into v_cols
      from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = 'etablissements' and c.column_name <> 'code_recuperation';
      execute format('REVOKE %s ON TABLE public.etablissements FROM PUBLIC, anon, authenticated', v_priv);
      execute format('GRANT %s (%s) ON TABLE public.etablissements TO %s', v_priv, v_cols, array_to_string(v_roles, ', '));
      raise notice 'Droit % sur toute la table etablissements remplacé par un droit colonne par colonne (sans code_recuperation) pour %', v_priv, v_roles;
    end if;
  end loop;
  REVOKE ALL (code_recuperation) ON TABLE public.etablissements FROM PUBLIC, anon, authenticated;

  if exists (select 1 from unnest(array['anon', 'authenticated']) as r(role),
                           unnest(array['SELECT', 'INSERT', 'UPDATE', 'REFERENCES']) as p(p)
             where has_column_privilege(r.role, 'public.etablissements', 'code_recuperation', p.p)) then
    raise exception 'ÉCHEC droits : code_recuperation reste accessible à la clé publique : rien n''est modifié.';
  end if;
  raise notice 'Installation B1 : tables, 4 fonctions publiques, tirage sûr, ancienne réclamation fermée, code illisible par la clé publique';
end $migration$;


-- ############################################################
-- CONTRÔLE FINAL (dernière instruction : toutes les lignes = true)
-- ############################################################
with f as (
  select p.oid, p.proname, p.prosecdef, p.proconfig, p.prosrc, p.proacl,
         pg_get_function_identity_arguments(p.oid) as args,
         pg_get_function_result(p.oid) as res,
         ltrim(regexp_replace(p.prosrc, '^.*?\mbegin\M', ''), E' \t\r\n') as premiere
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in ('etablissement_claim_v2', 'admin_lire_code_v2', 'admin_regenerer_code_v2', 'admin_annuler_code_v2', '_etab_generer_code')
),
cli as (select * from f where proname <> '_etab_generer_code'),
adm as (select * from f where proname like 'admin\_%')
select n, controle, ok from (
  select 1 as n, 'tables etablissement_code_essais et etablissement_code_journal : créées, RLS activée, vides' as controle,
         (select count(*) = 2 and bool_and(c.relrowsecurity) from pg_class c
           where c.oid in (to_regclass('public.etablissement_code_essais'), to_regclass('public.etablissement_code_journal')))
         and (select count(*) = 0 from public.etablissement_code_essais)
         and (select count(*) = 0 from public.etablissement_code_journal) as ok
  union all select 2, 'aucun droit de anon / authenticated sur ces deux tables',
         not exists (select 1 from unnest(array['anon', 'authenticated']) as x(role),
                                  unnest(array['public.etablissement_code_essais', 'public.etablissement_code_journal']) as t(t),
                                  unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE']) as p(p)
                     where has_table_privilege(x.role, t.t, p.p))
  union all select 3, 'journal des essais : aucune colonne pour le code saisi (id, etab_id, resultat, created_at)',
         (select string_agg(c.column_name, ',' order by c.ordinal_position) = 'id,etab_id,resultat,created_at'
            from information_schema.columns c where c.table_schema = 'public' and c.table_name = 'etablissement_code_essais')
  union all select 4, 'signatures : claim_v2 -> jsonb ; lire / regenerer -> text ; annuler -> boolean',
         (select count(*) = 4 from cli
           where (proname, args, res) in (
             ('etablissement_claim_v2', 'p_etab_id text, p_code text, p_email text, p_password text, p_responsable text, p_tel text, p_tel2 text, p_tel3 text, p_site_web text, p_contact_tel text', 'jsonb'),
             ('admin_lire_code_v2', 'p_token text, p_etab_id text', 'text'),
             ('admin_regenerer_code_v2', 'p_token text, p_etab_id text', 'text'),
             ('admin_annuler_code_v2', 'p_token text, p_etab_id text', 'boolean')))
  union all select 5, 'SECURITY DEFINER et SET search_path TO public (5 fonctions)',
         (select count(*) = 5 and bool_and(prosecdef and proconfig @> array['search_path=public']) from f)
  union all select 6, 'anon et authenticated exécutent les 4 fonctions publiques ; personne n''exécute _etab_generer_code ; aucun droit PUBLIC',
         (select bool_and(has_function_privilege('anon', oid, 'EXECUTE') and has_function_privilege('authenticated', oid, 'EXECUTE')) from cli)
         and (select bool_and(not has_function_privilege('anon', oid, 'EXECUTE') and not has_function_privilege('authenticated', oid, 'EXECUTE'))
                from f where proname = '_etab_generer_code')
         and (select bool_and(proacl is not null and not exists (select 1 from aclexplode(proacl) a where a.grantee = 0)) from f)
  union all select 7, '_session_user(p_token, ''admin'') en PREMIÈRE instruction (3 fonctions admin)',
         (select count(*) = 3 and bool_and(premiere like 'v\_admin\_id := \_session\_user(p\_token, ''admin'');%') from adm)
  union all select 8, 'ancienne etablissement_claim_by_code (code seul) : présente, plus exécutable par PUBLIC / anon / authenticated',
         to_regprocedure('public.etablissement_claim_by_code(text,text,text,text,text,text,text,text,text)') is not null
         and not has_function_privilege('anon', 'public.etablissement_claim_by_code(text,text,text,text,text,text,text,text,text)', 'EXECUTE')
         and not has_function_privilege('authenticated', 'public.etablissement_claim_by_code(text,text,text,text,text,text,text,text,text)', 'EXECUTE')
         and not exists (select 1 from pg_proc p, aclexplode(p.proacl) a
                          where p.oid = 'public.etablissement_claim_by_code(text,text,text,text,text,text,text,text,text)'::regprocedure and a.grantee = 0)
  union all select 9, 'code_recuperation : aucun droit direct (SELECT, INSERT, UPDATE, REFERENCES) pour anon / authenticated',
         not exists (select 1 from unnest(array['anon', 'authenticated']) as x(role), unnest(array['SELECT', 'INSERT', 'UPDATE', 'REFERENCES']) as p(p)
                     where has_column_privilege(x.role, 'public.etablissements', 'code_recuperation', p.p))
  union all select 10, 'claim_v2 : fiche cherchée par son id (verrouillée), essais journalisés, code effacé à la réclamation',
         (select bool_and(prosrc like '%where e.id = p_etab_id for update%'
                      and prosrc like '%insert into etablissement_code_essais(etab_id, resultat) values (p_etab_id, ''echec'')%'
                      and prosrc like '%reclame = true, code_recuperation = null%')
            from f where proname = 'etablissement_claim_v2')
  union all select 11, 'tirage : gen_random_bytes, alphabet sans O/0, I/1/L',
         (select bool_and(prosrc like '%extensions.gen_random_bytes%' and prosrc like '%''ABCDEFGHJKMNPQRSTUVWXYZ23456789''%')
            from f where proname = '_etab_generer_code')
         and public._etab_generer_code() ~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$'
  union all select 12, 'données inchangées : 4 171 fiches, 1 réclamée',
         (select count(*) = 4171 from public.etablissements)
         and (select count(*) = 1 from public.etablissements e where coalesce(e.reclame, false))
  union all select 13, 'list_etablissements (publique) ne renvoie toujours pas le code',
         (select count(*) = 1 and bool_and(p.prosrc not like '%code_recuperation%')
            from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname = 'list_etablissements')
) t
order by n;
