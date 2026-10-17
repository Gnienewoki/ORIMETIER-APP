-- ============================================================
-- ORIMETIER — Circuit des établissements, étape 3 : VALIDATION et REFUS des
-- demandes d'inscription (demandes_inscription_etablissements). FICHIER TOUT-EN-UN.
--
-- À coller et lancer UNE SEULE FOIS dans le SQL Editor de Supabase. Il enchaîne :
--   1) la migration (BEGIN ... COMMIT) ;
--   2) le test fonctionnel complet (BEGIN ... DO ... ROLLBACK : aucune trace) ;
--   3) une requête finale (n, controle, ok) : TOUTES les lignes doivent valoir true.
-- Si une étape du test échoue, l'exécution s'arrête sur "ÉCHEC ..." et la requête
-- finale n'est pas affichée. La migration (partie 1) reste alors en place : elle est
-- rejouable, le fichier peut être relancé tel quel après correction.
--
-- Pré-requis : Phase 1 (_session_user), 5a-1 (admin_session_open, table admins),
-- 5a-2b (admin_list_demandes_inscription_etablissements_v2), 6a-1
-- (etablissement_session_open) exécutées.
--
-- Décisions Q1 à Q8 (audit-circuit-etablissements.md) : la demande reste dans
-- demandes_inscription_etablissements ; à la validation elle est COPIÉE dans
-- etablissements, hash bcrypt compris (hash_password_trigger laisse passer un hash
-- ^\$2[aby]\$ sans le re-hacher, cf. référence live l.897-910) : l'établissement se
-- connecte avec l'e-mail et le mot de passe choisis à l'inscription, SANS code.
--
-- SOURCES (corps de PRODUCTION) :
--   - etablissement_register : CSV prod du 02/10 (prod-etablissement-fonctions-
--     2026-10-02.csv) = référence live l.737-770, IDENTIQUES. Seule la ligne de
--     contrôle de l'e-mail change (voir plus bas).
--   - admin_list_demandes_inscription_etablissements_v2 : migration 5a-2b du dépôt
--     l.95-117 (exécutée en prod ; fonction absente du CSV du 02/10, non vérifiée
--     contre un export prod). ÉCART avec la consigne : elle ne renvoyait DÉJÀ PAS le
--     hash et renvoyait DÉJÀ statut_demande ; seule la colonne motif_refus est ajoutée.
--   - Génération de l'id : celle de admin_bulk_import_etablissements (live l.73),
--     avec un compteur fixé à 1 (une seule fiche par appel).
--   - Table : migration 2026-08-16 (password NOT NULL, CHECK en ligne
--     ('en_attente','traite') au nom généré automatiquement) + logo_url (08-22).
--
-- Fonctions CRÉÉES :
--   _etab_texte_normalise(text) -> text                          (interne, aucun droit client)
--   admin_valider_demande_v2(p_token, p_demande_id uuid, p_forcer boolean DEFAULT false) -> text
--   admin_refuser_demande_v2(p_token, p_demande_id uuid, p_motif text DEFAULT NULL) -> boolean
--   admin_fiches_proches_demande_v2(p_token, p_demande_id uuid)
--     -> TABLE(id, nom, ville, reclame, a_un_code)
-- Fonctions MODIFIÉES :
--   etablissement_register (même signature) : SEULEMENT le contrôle d'e-mail, désormais
--     lower(trim()) contre les fiches ET les demandes en attente ; message 'DOUBLON: ...'
--     inchangé, mot pour mot.
--   admin_list_demandes_inscription_etablissements_v2 (DROP + CREATE : le type de
--     retour change) : + motif_refus ; toujours sans le hash ; toujours 'en_attente'.
-- Table demandes_inscription_etablissements :
--   + motif_refus text ; password nullable (hash EFFACÉ après validation ou refus) ;
--   CHECK statut_demande élargi à ('en_attente','traite','valide','refuse')
--   ('traite' conservé pour l'historique).
--
-- NON MODIFIÉS (volontairement) : admin_bulk_import_etablissements(_v2),
-- admin_marquer_demande_traitee(_v2), admin_lier_photos_logo_demande(_v2) (retirés à
-- l'étape 9), Premium, list_etablissements (masquage public intact, vérifié).
--
-- Le test (partie 2) crée un admin temporaire (comme le test 5a-2e) : si 5 admins
-- sont déjà actifs, trg_admins_quota le refuse ; désactiver alors un compte de test
-- avant de relancer.
-- ============================================================


-- ############################################################
-- PARTIE 1 : MIGRATION
-- ############################################################

BEGIN;

-- 0) Garde-fous
DO $$
begin
  if to_regprocedure('public._session_user(text,text)') is null then
    raise exception '_session_user absente : exécuter d''abord la Phase 1';
  end if;
  if to_regprocedure('public.admin_session_open(text,text)') is null then
    raise exception 'admin_session_open absente : exécuter d''abord la migration 5a-1';
  end if;
  if to_regprocedure('public.etablissement_session_open(text,text)') is null then
    raise exception 'etablissement_session_open absente : exécuter d''abord la migration 6a-1';
  end if;
  if to_regprocedure('public.admin_list_demandes_inscription_etablissements_v2(text)') is null then
    raise exception 'admin_list_demandes_inscription_etablissements_v2 absente : exécuter d''abord la migration 5a-2b';
  end if;
  if exists (select 1 from public.demandes_inscription_etablissements d
             where d.statut_demande not in ('en_attente','traite','valide','refuse')) then
    raise exception 'Valeur de statut_demande inattendue en base : migration annulée';
  end if;
end $$;

-- ------------------------------------------------------------
-- 1) Table demandes_inscription_etablissements
-- ------------------------------------------------------------
ALTER TABLE public.demandes_inscription_etablissements ADD COLUMN IF NOT EXISTS motif_refus text;
ALTER TABLE public.demandes_inscription_etablissements ALTER COLUMN password DROP NOT NULL;

-- Le CHECK d'origine est déclaré en ligne (nom généré) : on supprime tout CHECK qui
-- porte sur statut_demande, quel que soit son nom, puis on le recrée nommé.
DO $$
declare r record;
begin
  for r in
    select c.conname
    from pg_constraint c
    where c.conrelid = 'public.demandes_inscription_etablissements'::regclass
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ilike '%statut_demande%'
  loop
    execute format('ALTER TABLE public.demandes_inscription_etablissements DROP CONSTRAINT %I', r.conname);
  end loop;
end $$;

ALTER TABLE public.demandes_inscription_etablissements
  ADD CONSTRAINT demandes_inscription_etablissements_statut_demande_check
  CHECK (statut_demande IN ('en_attente','traite','valide','refuse'));

-- ------------------------------------------------------------
-- 2) _etab_texte_normalise : minuscules, sans accents (translate : aucune dépendance
--    à l'extension unaccent), ponctuation -> espace, espaces réduits. '' -> NULL
--    (deux valeurs vides ne sont jamais "proches").
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._etab_texte_normalise(p_texte text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select nullif(trim(regexp_replace(
    translate(
      replace(replace(lower(coalesce(p_texte, '')), 'œ', 'oe'), 'æ', 'ae'),
      'àáâãäåāçćčèéêëēėęìíîïīñńòóôõöøōùúûüūýÿž',
      'aaaaaaaccceeeeeeeiiiiinnooooooouuuuuyyz'),
    '[^a-z0-9]+', ' ', 'g')), '');
$function$;

REVOKE ALL ON FUNCTION public._etab_texte_normalise(text) FROM public, anon, authenticated;

-- ------------------------------------------------------------
-- 3) admin_valider_demande_v2 : copie la demande dans etablissements (atomique)
-- ------------------------------------------------------------
-- Erreurs : DEMANDE_INTROUVABLE, DEMANDE_DEJA_TRAITEE, EMAIL_DEJA_UTILISE,
-- FICHE_PROCHE (fiche NON RÉCLAMÉE de même nom et même ville normalisés), sauf si
-- p_forcer. Renvoie l'id de la fiche créée.
CREATE OR REPLACE FUNCTION public.admin_valider_demande_v2(p_token text, p_demande_id uuid, p_forcer boolean DEFAULT false)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_admin_id text;
  v_d demandes_inscription_etablissements%rowtype;
  v_id text;
  v_contrainte text;
begin
  v_admin_id := _session_user(p_token, 'admin');

  -- FOR UPDATE : deux admins qui valident la même demande en même temps ne créent
  -- pas deux fiches (le second voit DEMANDE_DEJA_TRAITEE).
  select d.* into v_d
  from demandes_inscription_etablissements d
  where d.id = p_demande_id
  for update;
  if not found then
    raise exception 'DEMANDE_INTROUVABLE';
  end if;
  if v_d.statut_demande is distinct from 'en_attente' then
    raise exception 'DEMANDE_DEJA_TRAITEE';
  end if;

  if exists (select 1 from etablissements e where lower(trim(e.email)) = lower(trim(v_d.email))) then
    raise exception 'EMAIL_DEJA_UTILISE';
  end if;

  if not coalesce(p_forcer, false) and exists (
    select 1 from etablissements e
    where coalesce(e.reclame, false) = false
      and _etab_texte_normalise(e.nom) = _etab_texte_normalise(v_d.nom)
      and _etab_texte_normalise(e.ville) = _etab_texte_normalise(v_d.ville)
  ) then
    raise exception 'FICHE_PROCHE';
  end if;

  -- Même format d'id que admin_bulk_import_etablissements (compteur = 1).
  v_id := 'id' || extract(epoch from clock_timestamp())::bigint::text || '1' || floor(random()*1000000)::text;

  begin
    insert into etablissements(
      id, nom, region, ville, quartier, type, responsable, tel, tel2, tel3, email, password,
      site_web, contact_tel, categorie, sous_categorie, secteur, date_inscription,
      logo_url, photos, filieres_proposees,
      statut, active, pre_inscrit, reclame, code_recuperation, premium, demande_premium
    ) values (
      v_id, v_d.nom, v_d.region, v_d.ville, v_d.quartier, v_d.type, v_d.responsable, v_d.tel, v_d.tel2, v_d.tel3,
      trim(v_d.email),
      v_d.password,  -- hash bcrypt recopié TEL QUEL (non re-haché par trg_hash_password)
      v_d.site_web, v_d.contact_tel, v_d.categorie, v_d.sous_categorie, v_d.secteur, v_d.date_inscription,
      v_d.logo_url, coalesce(v_d.photos, '[]'::jsonb),
      -- Filières : même forme jsonb (id, nom, diplome, conditions, statut, date), ordre
      -- conservé, statut passé à 'valide'.
      coalesce((
        select jsonb_agg(case when jsonb_typeof(f.val) = 'object'
                              then f.val || jsonb_build_object('statut', 'valide')
                              else f.val end
                         order by f.ord)
        from jsonb_array_elements(case when jsonb_typeof(v_d.filieres_proposees) = 'array'
                                       then v_d.filieres_proposees else '[]'::jsonb end)
             with ordinality as f(val, ord)
      ), '[]'::jsonb),
      'valide', true, false, true, null, false, false
    );
  exception when unique_violation then
    get stacked diagnostics v_contrainte = constraint_name;
    if v_contrainte = 'etablissements_email_unique' then
      raise exception 'EMAIL_DEJA_UTILISE';
    end if;
    raise;
  end;

  update demandes_inscription_etablissements d
    set statut_demande = 'valide', password = null
    where d.id = p_demande_id;

  return v_id;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_valider_demande_v2(text, uuid, boolean) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_valider_demande_v2(text, uuid, boolean) TO anon, authenticated;

-- ------------------------------------------------------------
-- 4) admin_refuser_demande_v2 : statut 'refuse', motif facultatif, hash effacé
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_refuser_demande_v2(p_token text, p_demande_id uuid, p_motif text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_admin_id text;
  v_statut text;
begin
  v_admin_id := _session_user(p_token, 'admin');

  select d.statut_demande into v_statut
  from demandes_inscription_etablissements d
  where d.id = p_demande_id
  for update;
  if not found then
    raise exception 'DEMANDE_INTROUVABLE';
  end if;
  if v_statut is distinct from 'en_attente' then
    raise exception 'DEMANDE_DEJA_TRAITEE';
  end if;

  update demandes_inscription_etablissements d
    set statut_demande = 'refuse',
        motif_refus = nullif(trim(coalesce(p_motif, '')), ''),
        password = null
    where d.id = p_demande_id;

  return true;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_refuser_demande_v2(text, uuid, text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_refuser_demande_v2(text, uuid, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 5) admin_fiches_proches_demande_v2 : fiches de même nom et même ville normalisés
-- ------------------------------------------------------------
-- Toutes les colonnes sont qualifiées (d., e.) : les noms de sortie (id, nom, ville,
-- reclame) sont aussi des variables PL/pgSQL (piège "column reference is ambiguous").
CREATE OR REPLACE FUNCTION public.admin_fiches_proches_demande_v2(p_token text, p_demande_id uuid)
 RETURNS TABLE(id text, nom text, ville text, reclame boolean, a_un_code boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_nom text;
  v_ville text;
begin
  perform _session_user(p_token, 'admin');

  select d.nom, d.ville into v_nom, v_ville
  from demandes_inscription_etablissements d
  where d.id = p_demande_id;
  if not found then
    raise exception 'DEMANDE_INTROUVABLE';
  end if;

  return query
    select e.id, e.nom, e.ville, coalesce(e.reclame, false), (e.code_recuperation is not null)
    from etablissements e
    where _etab_texte_normalise(e.nom) = _etab_texte_normalise(v_nom)
      and _etab_texte_normalise(e.ville) = _etab_texte_normalise(v_ville)
    order by coalesce(e.reclame, false), e.nom, e.id;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_fiches_proches_demande_v2(text, uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_fiches_proches_demande_v2(text, uuid) TO anon, authenticated;

-- ------------------------------------------------------------
-- 6) etablissement_register : corps PROD, SEULE la ligne e-mail change
--    avant : if exists (select 1 from etablissements where email = p_email) then return false; end if;
--    après : lower(trim()) contre les fiches ET les demandes en attente.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.etablissement_register(p_id text, p_nom text, p_region text, p_ville text, p_quartier text, p_type text, p_responsable text, p_tel text, p_email text, p_password text, p_date_inscription text, p_filieres_proposees jsonb, p_photos jsonb DEFAULT '[]'::jsonb, p_categorie text DEFAULT NULL::text, p_sous_categorie text DEFAULT NULL::text, p_secteur text DEFAULT NULL::text, p_tel2 text DEFAULT NULL::text, p_tel3 text DEFAULT NULL::text, p_site_web text DEFAULT NULL::text, p_contact_tel text DEFAULT NULL::text, p_logo_url text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if p_nom is null or length(trim(p_nom)) = 0 then return false; end if;
  if p_ville is null or length(trim(p_ville)) = 0 then return false; end if;
  if p_email is null or length(trim(p_email)) = 0 then return false; end if;
  if p_password is null or length(trim(p_password)) = 0 then return false; end if;

  if exists (select 1 from etablissements where lower(trim(nom)) = lower(trim(p_nom)))
     or exists (
       select 1 from demandes_inscription_etablissements
       where statut_demande = 'en_attente' and lower(trim(nom)) = lower(trim(p_nom))
     )
  then
    raise exception 'DOUBLON: Établissement déjà préinscrit, contacter le support pour récupérer vos codes de connexion. Tél : 07 87 63 34 81 - Email : gnienewoki@gmail.com';
  end if;

  if exists (select 1 from etablissements e where lower(trim(e.email)) = lower(trim(p_email)))
     or exists (
       select 1 from demandes_inscription_etablissements d
       where d.statut_demande = 'en_attente' and lower(trim(d.email)) = lower(trim(p_email))
     )
  then return false; end if;

  insert into demandes_inscription_etablissements(
    nom, region, ville, quartier, type, responsable, tel, tel2, tel3, email, password,
    date_inscription, filieres_proposees, photos, categorie, sous_categorie, secteur, site_web, contact_tel, logo_url
  ) values (
    p_nom, p_region, p_ville, p_quartier, p_type, p_responsable, p_tel, p_tel2, p_tel3, p_email, p_password,
    p_date_inscription, coalesce(p_filieres_proposees, '[]'::jsonb), coalesce(p_photos, '[]'::jsonb),
    p_categorie, p_sous_categorie, p_secteur, p_site_web, p_contact_tel, p_logo_url
  );
  return true;
end;
$function$;

REVOKE ALL ON FUNCTION public.etablissement_register(text, text, text, text, text, text, text, text, text, text, text, jsonb, jsonb, text, text, text, text, text, text, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.etablissement_register(text, text, text, text, text, text, text, text, text, text, text, jsonb, jsonb, text, text, text, text, text, text, text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 7) admin_list_demandes_inscription_etablissements_v2 : + motif_refus
--    (DROP obligatoire : CREATE OR REPLACE ne peut pas changer le type de retour)
-- ------------------------------------------------------------
DROP FUNCTION public.admin_list_demandes_inscription_etablissements_v2(text);

CREATE FUNCTION public.admin_list_demandes_inscription_etablissements_v2(p_token text)
 RETURNS TABLE(id text, nom text, region text, ville text, quartier text, type text, responsable text, tel text, tel2 text, tel3 text, email text, site_web text, contact_tel text, date_inscription text, filieres_proposees jsonb, photos jsonb, logo_url text, categorie text, sous_categorie text, secteur text, date_demande text, statut_demande text, motif_refus text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');

  return query
    select
      d.id::text, d.nom, d.region, d.ville, d.quartier, d.type,
      d.responsable, d.tel, d.tel2, d.tel3, d.email, d.site_web, d.contact_tel,
      d.date_inscription, d.filieres_proposees, d.photos, d.logo_url,
      d.categorie, d.sous_categorie, d.secteur,
      d.date_demande, d.statut_demande, d.motif_refus
    from demandes_inscription_etablissements d
    where d.statut_demande = 'en_attente'
    order by d.date_demande asc;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_list_demandes_inscription_etablissements_v2(text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_list_demandes_inscription_etablissements_v2(text) TO anon, authenticated;

COMMIT;


-- ############################################################
-- PARTIE 2 : TEST FONCTIONNEL COMPLET (ROLLBACK : aucune trace)
-- ############################################################
-- Tout est créé dans la transaction (préfixe test_etab3, e-mails *-etab3@exemple.invalid) :
--   admin test_etab3_adm (session par admin_session_open, comme le test 5a-2e) ;
--   fiche témoin NON réclamée « Lycée Sainte-Étab3 du Test » à « Bouaké-Etab3 » (avec code) ;
--   fiche RÉCLAMÉE « Collège Etab3 Réclamé » à « Korhogo-Etab3 », e-mail deja-etab3@exemple.invalid ;
--   demandes : A (via etablissement_register : 2 filières, logo, photos), B (nom + ville
--   proches du témoin), C (à refuser), D (e-mail déjà pris, casse différente),
--   E (proche d'une fiche RÉCLAMÉE seulement), G (reste en attente).
-- Règle suivie : un appel de fonction et la lecture de table qui le contrôle sont
-- toujours deux instructions séparées ; comparaisons en IS DISTINCT FROM.

BEGIN;

insert into public.admins(id, nom, email, password)
values ('test_etab3_adm', 'Admin test etab3', 'adm-etab3@exemple.invalid', 'mdp-adm-etab3');

insert into public.etablissements(
  id, nom, region, ville, quartier, type, responsable, tel, email, password,
  statut, active, date_inscription, filieres_proposees, photos, logo_url,
  categorie, sous_categorie, secteur, pre_inscrit, reclame, code_recuperation, premium
) values
  ('test_etab3_temoin', 'Lycée Sainte-Étab3 du Test', 'Gbêkê', 'Bouaké-Etab3', null, 'Secondaire générale', null, null,
   null, null,
   'valide', true, '05/10/2026', '[]'::jsonb, '[]'::jsonb, null,
   'general', 'secondaire', 'prive', true, false, 'TSTETAB3X', false),
  ('test_etab3_recl', 'Collège Etab3 Réclamé', 'Poro', 'Korhogo-Etab3', null, 'Secondaire générale', null, null,
   'deja-etab3@exemple.invalid', 'mdp-recl-etab3',
   'valide', true, '05/10/2026', '[]'::jsonb, '[]'::jsonb, null,
   'general', 'secondaire', 'prive', false, true, null, false);

insert into public.demandes_inscription_etablissements(
  nom, region, ville, quartier, type, responsable, tel, email, password,
  date_inscription, filieres_proposees, photos, categorie, sous_categorie, secteur
) values
  ('LYCEE SAINTE ETAB3, DU TEST', 'Gbêkê', 'bouake etab3', null, 'Secondaire générale', 'Resp B', '0711000002',
   'b-etab3@exemple.invalid', 'mdp-b-etab3', '05/10/2026', '[]'::jsonb, '[]'::jsonb, 'general', 'secondaire', 'prive'),
  ('Ecole Etab3 Refus', 'Tonkpi', 'Man-Etab3', null, 'Secondaire générale', 'Resp C', '0711000003',
   'c-etab3@exemple.invalid', 'mdp-c-etab3', '05/10/2026', '[]'::jsonb, '[]'::jsonb, 'general', 'secondaire', 'prive'),
  ('Ecole Etab3 Doublon Mail', 'Haut-Sassandra', 'Daloa-Etab3', null, 'Secondaire générale', 'Resp D', '0711000004',
   'DEJA-Etab3@Exemple.INVALID', 'mdp-d-etab3', '05/10/2026', '[]'::jsonb, '[]'::jsonb, 'general', 'secondaire', 'prive'),
  ('College Etab3 Reclame', 'Poro', 'korhogo etab3', null, 'Secondaire générale', 'Resp E', '0711000005',
   'e-etab3@exemple.invalid', 'mdp-e-etab3', '05/10/2026', '[]'::jsonb, '[]'::jsonb, 'general', 'secondaire', 'prive'),
  ('Ecole Etab3 Attente', 'Gôh', 'Gagnoa-Etab3', null, 'Secondaire générale', 'Resp G', '0711000007',
   'g-etab3@exemple.invalid', 'mdp-g-etab3', '05/10/2026', '[]'::jsonb, '[]'::jsonb, 'general', 'secondaire', 'prive');

-- Session d'un AUTRE rôle (élève), insérée directement : _session_user filtre sur le
-- rôle avant toute chose, l'élève n'a pas besoin d'exister.
insert into public.sessions(token_hash, role, user_id, expires_at)
values (encode(extensions.digest('jeton-eleve-test-etab3', 'sha256'), 'hex'), 'eleve', 'test_etab3_eleve', now() + interval '1 day');

DO $$
declare
  r jsonb;
  tA text; tE text;
  t_inconnu text := 'jeton-inconnu-test-etab3';
  t_eleve text := 'jeton-eleve-test-etab3';
  v_tok text; v_state text; v_msg text;
  dA uuid; dB uuid; dC uuid; dD uuid; dE uuid; dG uuid;
  hA text;
  v_idA text; v_idB text; v_idE text;
  v_fil jsonb := '[{"id":"f_etab3_1","nom":"2nd cycle","diplome":"BAC D","conditions":"","statut":"en_attente","date":"05/10/2026"},{"id":"f_etab3_2","nom":"1er cycle","diplome":"BEPC","conditions":"","statut":"en_attente","date":"05/10/2026"}]';
  v_fil_valide jsonb := '[{"id":"f_etab3_1","nom":"2nd cycle","diplome":"BAC D","conditions":"","statut":"valide","date":"05/10/2026"},{"id":"f_etab3_2","nom":"1er cycle","diplome":"BEPC","conditions":"","statut":"valide","date":"05/10/2026"}]';
  v_photos jsonb := '["https://exemple.invalid/etab3-p1.png","https://exemple.invalid/etab3-p2.png"]';
  v_attendu jsonb;
  v_j jsonb; v_txt text; v_txt2 text; v_n integer; v_b boolean;
  v_id text;
  ok boolean;
begin
  -- 0. Session admin
  tA := public.admin_session_open('adm-etab3@exemple.invalid', 'mdp-adm-etab3')->>'token';
  if tA is null then raise exception 'ÉCHEC 0 ouverture de la session admin de test'; end if;
  raise notice '0. session admin ouverte';

  -- 1. Demande A par etablissement_register (e-mail avec espaces : trim à la validation)
  ok := public.etablissement_register(
    'ignore', 'Institut Etab3 Normal', 'Lagunes', 'Abidjan-Etab3', 'Cocody', 'Secondaire générale',
    'M. Test Etab3', '0700000001', ' a-etab3@exemple.invalid ', 'MdpOrigine-Etab3!', '05/10/2026',
    v_fil, v_photos, 'general', 'secondaire', 'prive',
    '0700000002', '0700000003', 'https://exemple.invalid/etab3', '0700000009', 'https://exemple.invalid/etab3-logo.png');
  if ok is not true then raise exception 'ÉCHEC 1 etablissement_register (A) a renvoyé %', ok; end if;
  select d.id, d.password into dA, hA
  from public.demandes_inscription_etablissements d
  where d.email = ' a-etab3@exemple.invalid ' and d.statut_demande = 'en_attente';
  if dA is null then raise exception 'ÉCHEC 1 demande A introuvable'; end if;
  if hA is null or hA !~ '^\$2[aby]\$' then raise exception 'ÉCHEC 1 mot de passe de A non haché en bcrypt'; end if;
  select d.id into dB from public.demandes_inscription_etablissements d where d.email = 'b-etab3@exemple.invalid';
  select d.id into dC from public.demandes_inscription_etablissements d where d.email = 'c-etab3@exemple.invalid';
  select d.id into dD from public.demandes_inscription_etablissements d where d.email = 'DEJA-Etab3@Exemple.INVALID';
  select d.id into dE from public.demandes_inscription_etablissements d where d.email = 'e-etab3@exemple.invalid';
  select d.id into dG from public.demandes_inscription_etablissements d where d.email = 'g-etab3@exemple.invalid';
  if dB is null or dC is null or dD is null or dE is null or dG is null then raise exception 'ÉCHEC 1 demandes de test B..G introuvables'; end if;
  raise notice '1. demande A créée par etablissement_register (hash bcrypt), demandes B, C, D, E, G prêtes';

  -- 2. Validation de A : fiche créée avec TOUS les champs
  v_idA := public.admin_valider_demande_v2(tA, dA);
  if v_idA is null or v_idA !~ '^id[0-9]+$' then raise exception 'ÉCHEC 2 id renvoyé : %', v_idA; end if;
  select to_jsonb(e) into v_j from public.etablissements e where e.id = v_idA;
  if v_j is null then raise exception 'ÉCHEC 2 fiche % absente', v_idA; end if;
  v_attendu := jsonb_build_object(
    'nom', 'Institut Etab3 Normal', 'region', 'Lagunes', 'ville', 'Abidjan-Etab3', 'quartier', 'Cocody',
    'type', 'Secondaire générale', 'responsable', 'M. Test Etab3', 'tel', '0700000001',
    'tel2', '0700000002', 'tel3', '0700000003', 'email', 'a-etab3@exemple.invalid',
    'site_web', 'https://exemple.invalid/etab3', 'contact_tel', '0700000009',
    'categorie', 'general', 'sous_categorie', 'secondaire', 'secteur', 'prive',
    'date_inscription', '05/10/2026', 'logo_url', 'https://exemple.invalid/etab3-logo.png',
    'photos', v_photos, 'filieres_proposees', v_fil_valide,
    'statut', 'valide', 'active', true, 'pre_inscrit', false, 'reclame', true,
    'code_recuperation', null, 'premium', false, 'demande_premium', false);
  if not (v_j @> v_attendu) then
    raise exception 'ÉCHEC 2 champs de la fiche : % (attendu au moins %)', v_j - 'password', v_attendu;
  end if;
  if (v_j->'filieres_proposees') is distinct from v_fil_valide then
    raise exception 'ÉCHEC 2 filières : %', v_j->'filieres_proposees';
  end if;
  if (v_j->>'password') is distinct from hA then raise exception 'ÉCHEC 2 hash non recopié tel quel'; end if;
  raise notice '2. validation A : fiche % créée, tous les champs copiés, filières valide, logo/photos, reclame true, pre_inscrit false, hash identique', v_idA;

  -- 3. Connexion avec l'e-mail ET le mot de passe d'origine (sans code)
  r := public.etablissement_session_open('a-etab3@exemple.invalid', 'MdpOrigine-Etab3!');
  tE := r->>'token';
  if tE is null or (r->>'id') is distinct from v_idA then raise exception 'ÉCHEC 3 connexion avec le mot de passe d''origine : %', r; end if;
  r := public.etablissement_session_open('A-ETAB3@EXEMPLE.INVALID', 'MdpOrigine-Etab3!');
  if (r->>'id') is distinct from v_idA then raise exception 'ÉCHEC 3 connexion e-mail en majuscules : %', r; end if;
  r := public.etablissement_session_open('a-etab3@exemple.invalid', 'mauvais-mdp');
  if r is not null then raise exception 'ÉCHEC 3 mauvais mot de passe accepté'; end if;
  raise notice '3. connexion par etablissement_session_open avec l''e-mail et le mot de passe d''origine : OK';

  -- 4. Demande A : 'valide', hash effacé
  select d.statut_demande, d.password into v_txt, v_txt2 from public.demandes_inscription_etablissements d where d.id = dA;
  if v_txt is distinct from 'valide' or v_txt2 is not null then
    raise exception 'ÉCHEC 4 demande A : statut %, hash effacé = %', v_txt, (v_txt2 is null);
  end if;
  raise notice '4. demande A : valide, password NULL';

  -- 5. list_etablissements : fiche visible, contacts / logo / photos MASQUÉS (non Premium)
  select to_jsonb(l) into v_j from public.list_etablissements() l where l.id = v_idA;
  if v_j is null then raise exception 'ÉCHEC 5 fiche A absente de list_etablissements'; end if;
  if (v_j->>'statut') is distinct from 'valide' or (v_j->>'nom') is distinct from 'Institut Etab3 Normal' then
    raise exception 'ÉCHEC 5 fiche publique : %', v_j;
  end if;
  if jsonb_typeof(v_j->'email') is distinct from 'null' or jsonb_typeof(v_j->'tel') is distinct from 'null'
     or jsonb_typeof(v_j->'tel2') is distinct from 'null' or jsonb_typeof(v_j->'tel3') is distinct from 'null'
     or jsonb_typeof(v_j->'site_web') is distinct from 'null' then
    raise exception 'ÉCHEC 5 contacts visibles publiquement : %', v_j;
  end if;
  if jsonb_typeof(v_j->'logo_url') is distinct from 'null' or (v_j->'photos') is distinct from '[]'::jsonb then
    raise exception 'ÉCHEC 5 logo ou photos visibles publiquement : %', v_j;
  end if;
  raise notice '5. list_etablissements : fiche visible, contacts, logo et photos masqués';

  -- 6. E-mail déjà utilisé par une fiche (casse différente) -> EMAIL_DEJA_UTILISE, rien d'écrit
  v_msg := null;
  begin
    perform public.admin_valider_demande_v2(tA, dD);
  exception when others then v_msg := sqlerrm;
  end;
  if v_msg is distinct from 'EMAIL_DEJA_UTILISE' then raise exception 'ÉCHEC 6 % au lieu de EMAIL_DEJA_UTILISE', coalesce(v_msg, 'aucune erreur'); end if;
  select d.statut_demande, d.password into v_txt, v_txt2 from public.demandes_inscription_etablissements d where d.id = dD;
  if v_txt is distinct from 'en_attente' or v_txt2 is null then raise exception 'ÉCHEC 6 demande D modifiée : %', v_txt; end if;
  select count(*) into v_n from public.etablissements e where lower(trim(e.email)) = 'deja-etab3@exemple.invalid';
  if v_n is distinct from 1 then raise exception 'ÉCHEC 6 % fiche(s) avec l''e-mail de D', v_n; end if;
  raise notice '6. e-mail en double (casse différente) : EMAIL_DEJA_UTILISE, demande D intacte';

  -- 7. Fiche proche NON réclamée -> FICHE_PROCHE, puis p_forcer
  v_msg := null;
  begin
    perform public.admin_valider_demande_v2(tA, dB);
  exception when others then v_msg := sqlerrm;
  end;
  if v_msg is distinct from 'FICHE_PROCHE' then raise exception 'ÉCHEC 7 % au lieu de FICHE_PROCHE', coalesce(v_msg, 'aucune erreur'); end if;
  select d.statut_demande into v_txt from public.demandes_inscription_etablissements d where d.id = dB;
  if v_txt is distinct from 'en_attente' then raise exception 'ÉCHEC 7 demande B modifiée malgré FICHE_PROCHE : %', v_txt; end if;
  select count(*) into v_n from public.etablissements e where e.email = 'b-etab3@exemple.invalid';
  if v_n is distinct from 0 then raise exception 'ÉCHEC 7 fiche B créée malgré FICHE_PROCHE'; end if;

  select count(*) into v_n from public.admin_fiches_proches_demande_v2(tA, dB) p;
  if v_n is distinct from 1 then raise exception 'ÉCHEC 7 fiches proches de B : % (1 attendue)', v_n; end if;
  select to_jsonb(p) into v_j from public.admin_fiches_proches_demande_v2(tA, dB) p;
  if v_j is distinct from jsonb_build_object('id', 'test_etab3_temoin', 'nom', 'Lycée Sainte-Étab3 du Test', 'ville', 'Bouaké-Etab3', 'reclame', false, 'a_un_code', true) then
    raise exception 'ÉCHEC 7 fiche proche de B : %', v_j;
  end if;

  v_idB := public.admin_valider_demande_v2(tA, dB, true);
  if v_idB is null or v_idB = v_idA then raise exception 'ÉCHEC 7 validation forcée de B : %', v_idB; end if;
  select count(*) into v_n from public.etablissements e where e.id = v_idB and e.email = 'b-etab3@exemple.invalid' and e.reclame = true;
  if v_n is distinct from 1 then raise exception 'ÉCHEC 7 nouvelle fiche B absente'; end if;
  select to_jsonb(e) into v_j from public.etablissements e where e.id = 'test_etab3_temoin';
  if (v_j->>'code_recuperation') is distinct from 'TSTETAB3X' or (v_j->>'reclame')::boolean is distinct from false
     or jsonb_typeof(v_j->'email') is distinct from 'null' or (v_j->>'nom') is distinct from 'Lycée Sainte-Étab3 du Test' then
    raise exception 'ÉCHEC 7 fiche témoin modifiée : %', v_j - 'password';
  end if;
  raise notice '7. FICHE_PROCHE (témoin non réclamé signalé), puis p_forcer : nouvelle fiche %, témoin intact', v_idB;

  -- 8. Proche d'une fiche RÉCLAMÉE seulement : pas de blocage, mais signalée
  select p.reclame, p.a_un_code into v_b, ok from public.admin_fiches_proches_demande_v2(tA, dE) p where p.id = 'test_etab3_recl';
  if v_b is distinct from true or ok is distinct from false then raise exception 'ÉCHEC 8 fiche réclamée proche de E : reclame %, a_un_code %', v_b, ok; end if;
  v_idE := public.admin_valider_demande_v2(tA, dE);
  if v_idE is null then raise exception 'ÉCHEC 8 validation de E sans forcer'; end if;
  select count(*) into v_n from public.etablissements e where e.id = v_idE;
  if v_n is distinct from 1 then raise exception 'ÉCHEC 8 fiche E absente'; end if;
  raise notice '8. fiche proche RÉCLAMÉE : signalée (reclame true) mais non bloquante';

  -- 9. Refus avec motif, hash effacé, aucune fiche
  ok := public.admin_refuser_demande_v2(tA, dC, '  Dossier incomplet  ');
  if ok is not true then raise exception 'ÉCHEC 9 refus de C a renvoyé %', ok; end if;
  select d.statut_demande, d.motif_refus, d.password into v_txt, v_txt2, v_msg from public.demandes_inscription_etablissements d where d.id = dC;
  if v_txt is distinct from 'refuse' or v_txt2 is distinct from 'Dossier incomplet' or v_msg is not null then
    raise exception 'ÉCHEC 9 demande C : statut %, motif %, hash effacé = %', v_txt, v_txt2, (v_msg is null);
  end if;
  select count(*) into v_n from public.etablissements e where e.email = 'c-etab3@exemple.invalid';
  if v_n is distinct from 0 then raise exception 'ÉCHEC 9 fiche créée pour une demande refusée'; end if;
  raise notice '9. refus de C : refuse, motif "Dossier incomplet", password NULL, aucune fiche';

  -- 10. Second traitement -> DEMANDE_DEJA_TRAITEE (valider et refuser, sur A validée et C refusée)
  foreach v_id in array array[dA::text, dC::text] loop
    v_msg := null;
    begin perform public.admin_valider_demande_v2(tA, v_id::uuid, true); exception when others then v_msg := sqlerrm; end;
    if v_msg is distinct from 'DEMANDE_DEJA_TRAITEE' then raise exception 'ÉCHEC 10 valider % : %', v_id, coalesce(v_msg, 'aucune erreur'); end if;
    v_msg := null;
    begin perform public.admin_refuser_demande_v2(tA, v_id::uuid, 'x'); exception when others then v_msg := sqlerrm; end;
    if v_msg is distinct from 'DEMANDE_DEJA_TRAITEE' then raise exception 'ÉCHEC 10 refuser % : %', v_id, coalesce(v_msg, 'aucune erreur'); end if;
  end loop;
  select count(*) into v_n from public.etablissements e where lower(trim(e.email)) in ('a-etab3@exemple.invalid', 'c-etab3@exemple.invalid');
  if v_n is distinct from 1 then raise exception 'ÉCHEC 10 % fiche(s) pour A/C (1 attendue)', v_n; end if;
  select d.motif_refus into v_txt from public.demandes_inscription_etablissements d where d.id = dC;
  if v_txt is distinct from 'Dossier incomplet' then raise exception 'ÉCHEC 10 motif de C écrasé : %', v_txt; end if;
  raise notice '10. second traitement : DEMANDE_DEJA_TRAITEE, rien de modifié';

  -- 11. Demande inconnue -> DEMANDE_INTROUVABLE sur les 3 fonctions
  v_msg := null;
  begin perform public.admin_valider_demande_v2(tA, gen_random_uuid()); exception when others then v_msg := sqlerrm; end;
  if v_msg is distinct from 'DEMANDE_INTROUVABLE' then raise exception 'ÉCHEC 11 valider : %', coalesce(v_msg, 'aucune erreur'); end if;
  v_msg := null;
  begin perform public.admin_refuser_demande_v2(tA, gen_random_uuid()); exception when others then v_msg := sqlerrm; end;
  if v_msg is distinct from 'DEMANDE_INTROUVABLE' then raise exception 'ÉCHEC 11 refuser : %', coalesce(v_msg, 'aucune erreur'); end if;
  v_msg := null;
  begin perform public.admin_fiches_proches_demande_v2(tA, gen_random_uuid()); exception when others then v_msg := sqlerrm; end;
  if v_msg is distinct from 'DEMANDE_INTROUVABLE' then raise exception 'ÉCHEC 11 fiches proches : %', coalesce(v_msg, 'aucune erreur'); end if;
  raise notice '11. demande inconnue : DEMANDE_INTROUVABLE sur les 3 fonctions';

  -- 12. Jeton établissement / élève / inconnu -> P0401 sur les 3 fonctions, rien d'écrit
  foreach v_tok in array array[tE, t_eleve, t_inconnu] loop
    v_state := null;
    begin perform public.admin_valider_demande_v2(v_tok, dG, true); exception when others then v_state := sqlstate; end;
    if v_state is distinct from 'P0401' then raise exception 'ÉCHEC 12 valider : % au lieu de P0401 (jeton %)', coalesce(v_state, 'aucune erreur'), left(v_tok, 12) || '…'; end if;
    v_state := null;
    begin perform public.admin_refuser_demande_v2(v_tok, dG, 'intrus'); exception when others then v_state := sqlstate; end;
    if v_state is distinct from 'P0401' then raise exception 'ÉCHEC 12 refuser : % au lieu de P0401 (jeton %)', coalesce(v_state, 'aucune erreur'), left(v_tok, 12) || '…'; end if;
    v_state := null;
    begin perform public.admin_fiches_proches_demande_v2(v_tok, dG); exception when others then v_state := sqlstate; end;
    if v_state is distinct from 'P0401' then raise exception 'ÉCHEC 12 fiches proches : % au lieu de P0401 (jeton %)', coalesce(v_state, 'aucune erreur'), left(v_tok, 12) || '…'; end if;
  end loop;
  select d.statut_demande, d.motif_refus, d.password into v_txt, v_txt2, v_msg from public.demandes_inscription_etablissements d where d.id = dG;
  if v_txt is distinct from 'en_attente' or v_txt2 is not null or v_msg is null then raise exception 'ÉCHEC 12 demande G modifiée par un jeton refusé'; end if;
  raise notice '12. jetons établissement / élève / inconnu : P0401 sur les 3 fonctions, demande G intacte';

  -- 13. etablissement_register : e-mail déjà présent (casse différente) -> false
  ok := public.etablissement_register(
    'ignore', 'Institut Etab3 Autre 1', 'Lagunes', 'Abidjan-Etab3', null, 'Secondaire générale',
    null, null, '  A-ETAB3@EXEMPLE.INVALID ', 'mdp-x', '05/10/2026', '[]'::jsonb);
  if ok is distinct from false then raise exception 'ÉCHEC 13 e-mail d''une fiche (majuscules) accepté : %', ok; end if;
  ok := public.etablissement_register(
    'ignore', 'Institut Etab3 Autre 2', 'Lagunes', 'Abidjan-Etab3', null, 'Secondaire générale',
    null, null, 'G-Etab3@EXEMPLE.invalid', 'mdp-x', '05/10/2026', '[]'::jsonb);
  if ok is distinct from false then raise exception 'ÉCHEC 13 e-mail d''une demande en attente (majuscules) accepté : %', ok; end if;
  select count(*) into v_n from public.demandes_inscription_etablissements d where d.nom like 'Institut Etab3 Autre%';
  if v_n is distinct from 0 then raise exception 'ÉCHEC 13 % demande(s) créée(s) malgré l''e-mail pris', v_n; end if;
  v_msg := null;
  begin
    perform public.etablissement_register(
      'ignore', 'lycée sainte-étab3 du test ', 'Gbêkê', 'Bouaké-Etab3', null, 'Secondaire générale',
      null, null, 'h-etab3@exemple.invalid', 'mdp-x', '05/10/2026', '[]'::jsonb);
  exception when others then v_msg := sqlerrm;
  end;
  if v_msg is distinct from 'DOUBLON: Établissement déjà préinscrit, contacter le support pour récupérer vos codes de connexion. Tél : 07 87 63 34 81 - Email : gnienewoki@gmail.com' then
    raise exception 'ÉCHEC 13 message DOUBLON modifié : %', coalesce(v_msg, 'aucune erreur');
  end if;
  raise notice '13. register : e-mail en majuscules (fiche ou demande en attente) refusé, message DOUBLON inchangé';

  -- 14. Liste admin : sans hash, avec statut_demande et motif_refus, en attente seulement
  select to_jsonb(l) into v_j from public.admin_list_demandes_inscription_etablissements_v2(tA) l where l.id = dG::text;
  if v_j is null then raise exception 'ÉCHEC 14 demande G absente de la liste admin'; end if;
  if v_j ? 'password' or not (v_j ? 'motif_refus') or (v_j->>'statut_demande') is distinct from 'en_attente' then
    raise exception 'ÉCHEC 14 colonnes de la liste admin : %', v_j;
  end if;
  select count(*) into v_n from public.admin_list_demandes_inscription_etablissements_v2(tA) l where l.id in (dA::text, dB::text, dC::text, dE::text);
  if v_n is distinct from 0 then raise exception 'ÉCHEC 14 % demande(s) traitée(s) encore listée(s)', v_n; end if;
  raise notice '14. liste admin : sans hash, avec statut_demande et motif_refus, demandes traitées absentes';
end $$;

ROLLBACK;


-- ############################################################
-- PARTIE 3 : CONTRÔLE FINAL (une seule requête, toutes les lignes = true)
-- On n'arrive ici que si le test de la partie 2 a réussi.
-- ############################################################
with f as (
  select p.oid, p.proname, p.prosecdef, p.proconfig, p.prosrc, p.proacl, p.provolatile,
         pg_get_function_identity_arguments(p.oid) as args,
         pg_get_function_result(p.oid) as res,
         -- première instruction après le premier "begin" du corps
         ltrim(regexp_replace(p.prosrc, '^.*?\mbegin\M', ''), E' \t\r\n') as premiere
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in ('admin_valider_demande_v2', 'admin_refuser_demande_v2', 'admin_fiches_proches_demande_v2',
                      'admin_list_demandes_inscription_etablissements_v2', 'etablissement_register', '_etab_texte_normalise')
),
clients as (select * from f where proname <> '_etab_texte_normalise'),
admin4 as (select * from f where proname in ('admin_valider_demande_v2', 'admin_refuser_demande_v2', 'admin_fiches_proches_demande_v2', 'admin_list_demandes_inscription_etablissements_v2')),
liste as (
  select p.prosrc from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'list_etablissements'
)
select n, controle, ok from (
  select 1 as n, 'admin_valider_demande_v2(p_token text, p_demande_id uuid, p_forcer boolean DEFAULT false) -> text' as controle,
         (select count(*) = 1 and bool_and(args = 'p_token text, p_demande_id uuid, p_forcer boolean' and res = 'text'
                 and pg_get_function_arguments(oid) like '%p_forcer boolean DEFAULT false%') from f where proname = 'admin_valider_demande_v2') as ok
  union all select 2, 'admin_refuser_demande_v2(p_token text, p_demande_id uuid, p_motif text DEFAULT NULL) -> boolean',
         (select count(*) = 1 and bool_and(args = 'p_token text, p_demande_id uuid, p_motif text' and res = 'boolean'
                 and pg_get_function_arguments(oid) like '%p_motif text DEFAULT NULL%') from f where proname = 'admin_refuser_demande_v2')
  union all select 3, 'admin_fiches_proches_demande_v2 -> TABLE(id, nom, ville, reclame, a_un_code)',
         (select count(*) = 1 and bool_and(args = 'p_token text, p_demande_id uuid'
                 and res = 'TABLE(id text, nom text, ville text, reclame boolean, a_un_code boolean)') from f where proname = 'admin_fiches_proches_demande_v2')
  union all select 4, 'SECURITY DEFINER (5 fonctions appelables par les clients)',
         (select count(*) = 5 and bool_and(prosecdef) from clients)
  union all select 5, 'SET search_path TO public (6 fonctions)',
         (select count(*) = 6 and bool_and(proconfig @> array['search_path=public']) from f)
  union all select 6, 'exécutables par anon et authenticated',
         (select bool_and(has_function_privilege('anon', oid, 'EXECUTE') and has_function_privilege('authenticated', oid, 'EXECUTE')) from clients)
  union all select 7, 'aucun droit EXECUTE pour PUBLIC',
         (select bool_and(proacl is not null and not exists (select 1 from aclexplode(proacl) a where a.grantee = 0)) from f)
  union all select 8, '_session_user(p_token, ''admin'') en PREMIÈRE instruction (4 fonctions admin)',
         (select count(*) = 4 and bool_and(premiere like 'v\_admin\_id := \_session\_user(p\_token, ''admin'');%'
                                       or premiere like 'perform \_session\_user(p\_token, ''admin'');%') from admin4)
  union all select 9, '_etab_texte_normalise : IMMUTABLE, aucun droit pour anon / authenticated, résultat attendu',
         (select count(*) = 1 and bool_and(provolatile = 'i'
                 and not has_function_privilege('anon', oid, 'EXECUTE')
                 and not has_function_privilege('authenticated', oid, 'EXECUTE')) from f where proname = '_etab_texte_normalise')
         and public._etab_texte_normalise('  Lycée SAINTE-Étab3, du  Test ! ') = 'lycee sainte etab3 du test'
         and public._etab_texte_normalise('Bouaké-Œuvre') = 'bouake oeuvre'
         and public._etab_texte_normalise(' -- ') is null
  union all select 10, 'CHECK statut_demande = en_attente, traite, valide, refuse',
         (select count(*) = 1 and bool_and(pg_get_constraintdef(c.oid) like '%en_attente%' and pg_get_constraintdef(c.oid) like '%traite%'
                 and pg_get_constraintdef(c.oid) like '%valide%' and pg_get_constraintdef(c.oid) like '%refuse%')
            from pg_constraint c
            where c.conrelid = 'public.demandes_inscription_etablissements'::regclass and c.contype = 'c'
              and pg_get_constraintdef(c.oid) ilike '%statut_demande%')
  union all select 11, 'demandes : password nullable, colonne motif_refus text présente',
         (select count(*) = 2 and bool_and(case column_name when 'password' then is_nullable = 'YES' else data_type = 'text' end)
            from information_schema.columns
            where table_schema = 'public' and table_name = 'demandes_inscription_etablissements' and column_name in ('password', 'motif_refus'))
  union all select 12, 'liste admin des demandes : renvoie statut_demande et motif_refus, jamais password',
         (select count(*) = 1 and bool_and(res like '%statut_demande text%' and res like '%motif_refus text%' and res not like '%password%'
                 and prosrc not like '%password%') from f where proname = 'admin_list_demandes_inscription_etablissements_v2')
  union all select 13, 'etablissement_register : une seule signature, e-mail lower(trim()) fiches + demandes, message DOUBLON intact',
         (select count(*) = 1 and bool_and(
                 prosrc like '%lower(trim(e.email)) = lower(trim(p_email))%'
             and prosrc like '%d.statut_demande = ''en_attente'' and lower(trim(d.email)) = lower(trim(p_email))%'
             and prosrc not like '%where email = p_email%'
             and prosrc like '%''DOUBLON: Établissement déjà préinscrit, contacter le support pour récupérer vos codes de connexion. Tél : 07 87 63 34 81 - Email : gnienewoki@gmail.com''%')
            from f where proname = 'etablissement_register')
  union all select 14, 'list_etablissements : masquage contacts, photos et logo intact',
         (select count(*) = 1 and bool_and(
                 prosrc like '%CASE WHEN premium THEN photos ELSE ''[]''::jsonb END AS photos%'
             and prosrc like '%CASE WHEN premium THEN logo_url ELSE NULL END AS logo_url%'
             and prosrc like '%CASE WHEN premium THEN email ELSE NULL END AS email%'
             and prosrc like '%CASE WHEN premium THEN tel ELSE NULL END AS tel%'
             and prosrc like '%CASE WHEN premium THEN site_web ELSE NULL END AS site_web%') from liste)
  union all select 15, 'anciennes fonctions présentes (import, marquer traitée, lier logo/photos, avec et sans _v2)',
         to_regprocedure('public.admin_bulk_import_etablissements(text,text,text,jsonb)') is not null
         and to_regprocedure('public.admin_bulk_import_etablissements_v2(text,text,text,jsonb)') is not null
         and to_regprocedure('public.admin_marquer_demande_traitee(text,text)') is not null
         and to_regprocedure('public.admin_marquer_demande_traitee_v2(text,text)') is not null
         and to_regprocedure('public.admin_lier_photos_logo_demande(text,text,text)') is not null
         and to_regprocedure('public.admin_lier_photos_logo_demande_v2(text,text,text)') is not null
  union all select 16, 'test fonctionnel passé (partie 2)', true
  union all select 17, 'aucune trace : établissements de test',
         (select count(*) = 0 from public.etablissements e
           where e.id like 'test\_etab3\_%' or lower(trim(e.email)) like '%-etab3@exemple.invalid')
  union all select 18, 'aucune trace : demandes de test',
         (select count(*) = 0 from public.demandes_inscription_etablissements d
           where lower(trim(d.email)) like '%-etab3@exemple.invalid')
  union all select 19, 'aucune trace : admin et sessions de test',
         (select count(*) = 0 from public.admins a where a.id = 'test_etab3_adm' or a.email = 'adm-etab3@exemple.invalid')
         and (select count(*) = 0 from public.sessions s where s.user_id like 'test\_etab3\_%')
) t
order by n;
