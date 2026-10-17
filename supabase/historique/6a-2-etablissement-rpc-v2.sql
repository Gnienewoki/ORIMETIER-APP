-- ============================================================
-- ORIMETIER — Phase 6a-2 : RPC établissement par jeton (9 fonctions _v2).
--
-- Pré-requis : 6a-1 exécutée (etablissement_session_open, trigger
-- trg_etablissements_revoke_sessions). Migration ADDITIVE : les anciennes
-- fonctions (p_etab_id, p_password) et etablissement_login restent en
-- service jusqu'en 6c ; elles ne sont ni modifiées ni supprimées ici.
--
-- Source : code de PRODUCTION du 02/10/2026
-- (prod-etablissement-fonctions-2026-10-02.csv). Comparaison automatique
-- faite le 02/10 : les 9 fonctions de production sont identiques à
-- supabase/reference/live-2026-09-26.sql (l. 589-861), une seule signature
-- chacune.
--
-- Nouvelles fonctions :
--   etablissement_get_own_v2(p_token)
--   etablissement_update_info_v2(p_token, p_nom, p_type, p_responsable, p_tel, p_email, p_contact_tel DEFAULT null)
--   etablissement_update_localisation_v2(p_token, p_region, p_ville, p_quartier)
--   etablissement_update_contact_extras_v2(p_token, p_tel2, p_tel3, p_site_web)
--   etablissement_update_logo_v2(p_token, p_logo_url)
--   etablissement_update_photos_v2(p_token, p_photos jsonb)
--   etablissement_add_filiere_v2(p_token, p_nom, p_diplome)
--   etablissement_delete_filiere_v2(p_token, p_filiere_id)
--   etablissement_demander_premium_v2(p_token)
--
-- DIFFÉRENCES AVEC LA PRODUCTION (et seulement celles-ci) :
--   1. Authentification : p_etab_id et p_password disparaissent. La fiche est
--      celle du jeton : v_etab_id := _session_user(p_token, 'etablissement'),
--      qui lève SESSION_INVALIDE (P0401) si le jeton est inconnu, expiré,
--      révoqué, d'un autre rôle, ou si la fiche n'existe plus. Le prédicat
--      "id = p_etab_id and password = extensions.crypt(...)" devient
--      "id = v_etab_id". Les "if not found then return false" sont conservés
--      (fiche supprimée entre deux instructions).
--      get_own_v2 ne lève plus 'unauthorized' (remplacé par P0401).
--   2. add_filiere_v2 : _session_user est appelée AVANT le contrôle des champs
--      vides (la production testait les champs avant le mot de passe). Un jeton
--      invalide lève donc toujours P0401 ; le résultat métier est inchangé.
--      (Écart A validé.)
--   3. update_info_v2 : une violation de l'index unique
--      etablissements_email_unique (SQLSTATE 23505) est transformée en
--      exception 'EMAIL_DEJA_UTILISE', comme eleve_update_email /
--      admin_create_admin_v2. Toute autre violation est relancée telle quelle.
--      (Écart B validé.)
--   Le reste de chaque corps est recopié à l'identique (valeurs de retour,
--   limite de 10 filières, 10 photos max, premium exigé pour les photos, etc.).
--   get_own_v2 garde les alias e. / et. (piège d'ambiguïté RETURNS TABLE) ;
--   la variable s'appelle v_etab_id (et non v_id, déjà utilisée par
--   add_filiere pour l'id de la filière).
--
-- COMPORTEMENTS EXISTANTS CONSERVÉS VOLONTAIREMENT (à revoir en Phase 8) :
--   - update_photos : p_photos NULL (ou tableau vide) -> photos = NULL
--     (jsonb_agg sur zéro ligne), pas '[]' ; au-delà de 10 photos, tronque
--     silencieusement aux 10 premières au lieu de refuser.
--   - update_info : aucune validation (nom, e-mail vides acceptés ; l'e-mail de
--     connexion peut être changé sans re-saisie du mot de passe ni révocation) ;
--     contact_tel vide = valeur précédente conservée.
--   - update_contact_extras : aucun contrôle premium côté SQL (seul le front
--     masque le formulaire).
--   - demander_premium : si premium est NULL, la demande passe (seul
--     premium = true la refuse).
--   - update_localisation : seule la ville est obligatoire (region/quartier
--     peuvent être vidés).
--   - delete_filiere / add_filiere : retour false indistinct (filière
--     inexistante, champs vides, limite atteinte).
--
-- Droits : SECURITY DEFINER, SET search_path TO 'public', REVOKE ALL FROM
-- public, GRANT EXECUTE TO anon, authenticated (comme les admin_*_v2).
-- Rejouable : CREATE OR REPLACE.
-- À exécuter en une fois dans l'éditeur SQL de Supabase.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 0) Garde-fous : 6a-1 exécutée
-- ------------------------------------------------------------
DO $$
begin
  if to_regprocedure('public._session_user(text,text)') is null then
    raise exception '_session_user absente : exécuter d''abord la Phase 1';
  end if;
  if to_regprocedure('public.etablissement_session_open(text,text)') is null then
    raise exception 'etablissement_session_open absente : exécuter d''abord la migration 6a-1';
  end if;
  if not exists (select 1 from pg_trigger t
                 where t.tgrelid = 'public.etablissements'::regclass
                   and t.tgname = 'trg_etablissements_revoke_sessions') then
    raise exception 'trigger trg_etablissements_revoke_sessions absent : exécuter d''abord la migration 6a-1';
  end if;
end $$;

-- ------------------------------------------------------------
-- 1) etablissement_get_own_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.etablissement_get_own_v2(p_token text)
 RETURNS TABLE(id text, nom text, region text, ville text, quartier text, type text, responsable text, contact_tel text, email text, tel text, tel2 text, tel3 text, site_web text, statut text, active boolean, date_inscription text, filieres_proposees jsonb, photos jsonb, logo_url text, categorie text, sous_categorie text, secteur text, pre_inscrit boolean, reclame boolean, premium boolean, demande_premium boolean, demande_premium_date text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_etab_id text;
begin
  v_etab_id := _session_user(p_token, 'etablissement');

  return query
    select
      e.id, e.nom, e.region, e.ville, e.quartier, e.type,
      e.responsable, e.contact_tel,
      e.email, e.tel, e.tel2, e.tel3, e.site_web,
      e.statut, e.active, e.date_inscription, e.filieres_proposees,
      e.photos, e.logo_url, e.categorie, e.sous_categorie, e.secteur,
      e.pre_inscrit, e.reclame,
      e.premium, e.demande_premium, e.demande_premium_date
    from etablissements e
    where e.id = v_etab_id;
end; $function$;

REVOKE ALL ON FUNCTION public.etablissement_get_own_v2(text) FROM public;
GRANT EXECUTE ON FUNCTION public.etablissement_get_own_v2(text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 2) etablissement_update_info_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.etablissement_update_info_v2(p_token text, p_nom text, p_type text, p_responsable text, p_tel text, p_email text, p_contact_tel text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_etab_id text;
  v_contrainte text;
begin
  v_etab_id := _session_user(p_token, 'etablissement');
  if not exists(select 1 from etablissements where id = v_etab_id) then
    return false;
  end if;
  begin
    update etablissements
      set nom = p_nom, type = p_type, responsable = p_responsable, tel = p_tel, email = p_email,
          contact_tel = coalesce(nullif(trim(p_contact_tel), ''), contact_tel)
      where id = v_etab_id;
  exception when unique_violation then
    get stacked diagnostics v_contrainte = constraint_name;
    if v_contrainte = 'etablissements_email_unique' then
      raise exception 'EMAIL_DEJA_UTILISE';
    end if;
    raise;
  end;
  return true;
end;
$function$;

REVOKE ALL ON FUNCTION public.etablissement_update_info_v2(text, text, text, text, text, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.etablissement_update_info_v2(text, text, text, text, text, text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 3) etablissement_update_localisation_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.etablissement_update_localisation_v2(p_token text, p_region text, p_ville text, p_quartier text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_etab record; v_etab_id text;
begin
  v_etab_id := _session_user(p_token, 'etablissement');
  select * into v_etab from etablissements where id = v_etab_id;
  if not found then return false; end if;
  if p_ville is null or length(trim(p_ville)) = 0 then return false; end if;
  update etablissements set region = p_region, ville = p_ville, quartier = p_quartier where id = v_etab_id;
  return true;
end; $function$;

REVOKE ALL ON FUNCTION public.etablissement_update_localisation_v2(text, text, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.etablissement_update_localisation_v2(text, text, text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 4) etablissement_update_contact_extras_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.etablissement_update_contact_extras_v2(p_token text, p_tel2 text, p_tel3 text, p_site_web text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_etab record; v_etab_id text;
begin
  v_etab_id := _session_user(p_token, 'etablissement');
  select * into v_etab from etablissements where id = v_etab_id;
  if not found then return false; end if;
  update etablissements
    set tel2 = nullif(trim(coalesce(p_tel2,'')),''),
        tel3 = nullif(trim(coalesce(p_tel3,'')),''),
        site_web = nullif(trim(coalesce(p_site_web,'')),'')
    where id = v_etab_id;
  return true;
end;
$function$;

REVOKE ALL ON FUNCTION public.etablissement_update_contact_extras_v2(text, text, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.etablissement_update_contact_extras_v2(text, text, text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 5) etablissement_update_logo_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.etablissement_update_logo_v2(p_token text, p_logo_url text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_etab_id text;
begin
  v_etab_id := _session_user(p_token, 'etablissement');
  if not exists (select 1 from etablissements where id = v_etab_id) then
    return false;
  end if;
  update etablissements
    set logo_url = nullif(trim(coalesce(p_logo_url,'')),'')
    where id = v_etab_id;
  return true;
end; $function$;

REVOKE ALL ON FUNCTION public.etablissement_update_logo_v2(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.etablissement_update_logo_v2(text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 6) etablissement_update_photos_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.etablissement_update_photos_v2(p_token text, p_photos jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_etab record; v_etab_id text;
begin
  v_etab_id := _session_user(p_token, 'etablissement');
  select * into v_etab from etablissements where id = v_etab_id;
  if not found then return false; end if;
  if not coalesce(v_etab.premium, false) then return false; end if;

  update etablissements
    set photos = (select jsonb_agg(v) from (select v from jsonb_array_elements(p_photos) v limit 10) s)
    where id = v_etab_id;
  return true;
end; $function$;

REVOKE ALL ON FUNCTION public.etablissement_update_photos_v2(text, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION public.etablissement_update_photos_v2(text, jsonb) TO anon, authenticated;

-- ------------------------------------------------------------
-- 7) etablissement_add_filiere_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.etablissement_add_filiere_v2(p_token text, p_nom text, p_diplome text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_etab record;
  v_nouvelle jsonb;
  v_id text;
  v_etab_id text;
begin
  -- Écart A : le jeton est vérifié avant les champs (P0401 prioritaire).
  v_etab_id := _session_user(p_token, 'etablissement');
  if coalesce(trim(p_nom), '') = '' or coalesce(trim(p_diplome), '') = '' then return false; end if;
  select * into v_etab from etablissements where id = v_etab_id;
  if not found then return false; end if;
  if jsonb_array_length(coalesce(v_etab.filieres_proposees, '[]'::jsonb)) >= 10 then return false; end if;

  v_id := 'id' || extract(epoch from clock_timestamp())::bigint::text || floor(random()*1000000)::text;
  v_nouvelle := jsonb_build_object(
    'id', v_id, 'nom', trim(p_nom), 'diplome', trim(p_diplome),
    'conditions', '', 'statut', 'valide', 'date', to_char(now(),'DD/MM/YYYY')
  );
  update etablissements
    set filieres_proposees = coalesce(filieres_proposees, '[]'::jsonb) || jsonb_build_array(v_nouvelle)
    where id = v_etab_id;
  return true;
end; $function$;

REVOKE ALL ON FUNCTION public.etablissement_add_filiere_v2(text, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.etablissement_add_filiere_v2(text, text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 8) etablissement_delete_filiere_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.etablissement_delete_filiere_v2(p_token text, p_filiere_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_etab record;
  v_found boolean;
  v_new_filieres jsonb;
  v_etab_id text;
begin
  -- Authentification : jeton de session (fiche du jeton)
  v_etab_id := _session_user(p_token, 'etablissement');
  select * into v_etab from etablissements where id = v_etab_id;
  if not found then return false; end if;

  -- La filière existe-t-elle bien dans le jsonb actuel ?
  v_found := exists (
    select 1 from jsonb_array_elements(coalesce(v_etab.filieres_proposees, '[]'::jsonb)) f
    where f->>'id' = p_filiere_id
  );
  if not v_found then return false; end if;

  -- Reconstruit le tableau jsonb en excluant la filière ciblée
  select coalesce(jsonb_agg(f), '[]'::jsonb) into v_new_filieres
    from jsonb_array_elements(v_etab.filieres_proposees) f
    where f->>'id' <> p_filiere_id;

  update etablissements set filieres_proposees = v_new_filieres where id = v_etab_id;
  return true;
end; $function$;

REVOKE ALL ON FUNCTION public.etablissement_delete_filiere_v2(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.etablissement_delete_filiere_v2(text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 9) etablissement_demander_premium_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.etablissement_demander_premium_v2(p_token text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_etab record; v_etab_id text;
begin
  v_etab_id := _session_user(p_token, 'etablissement');
  select * into v_etab from etablissements where id = v_etab_id;
  if not found then return false; end if;
  if v_etab.premium then return false; end if;

  update etablissements
    set demande_premium = true, demande_premium_date = to_char(now(), 'DD/MM/YYYY')
    where id = v_etab_id;
  return true;
end; $function$;

REVOKE ALL ON FUNCTION public.etablissement_demander_premium_v2(text) FROM public;
GRANT EXECUTE ON FUNCTION public.etablissement_demander_premium_v2(text) TO anon, authenticated;

COMMIT;

-- ============================================================
-- VÉRIFICATIONS (à lancer après exécution, une requête à la fois)
-- ============================================================
--
-- V1. Les 9 fonctions _v2 : security_definer = true, config = {search_path=public},
--     anon = true, authenticated = true, sans_crypt = true (aucune comparaison de
--     mot de passe dans le corps), appelle_session_user = true. 9 lignes attendues.
-- select p.oid::regprocedure as fonction, p.prosecdef as security_definer, p.proconfig as config,
--        has_function_privilege('anon', p.oid, 'EXECUTE') as anon,
--        has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated,
--        p.prosrc not like '%crypt%' as sans_crypt,
--        p.prosrc like '%_session_user(p_token, ''etablissement'')%' as appelle_session_user
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public' and p.proname like 'etablissement\_%\_v2'
-- order by 1;
--
-- V2. Aucune _v2 ne prend de mot de passe ni de p_etab_id (0 ligne attendue)
-- select p.oid::regprocedure, pg_get_function_identity_arguments(p.oid) as args
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public' and p.proname like 'etablissement\_%\_v2'
--   and (pg_get_function_identity_arguments(p.oid) ilike '%password%'
--        or pg_get_function_identity_arguments(p.oid) ilike '%p_etab_id%');
--
-- V3. Anciennes fonctions toujours présentes : 10 lignes attendues
--     (etablissement_login + les 9 versions par mot de passe)
-- select p.oid::regprocedure as fonction
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('etablissement_login', 'etablissement_get_own', 'etablissement_update_info',
--                     'etablissement_update_localisation', 'etablissement_update_contact_extras',
--                     'etablissement_update_logo', 'etablissement_update_photos',
--                     'etablissement_add_filiere', 'etablissement_delete_filiere',
--                     'etablissement_demander_premium')
--   and pg_get_function_identity_arguments(p.oid) like '%p_password%'
-- order by 1;
--
-- V4. Comparaison des corps : chaque ancienne fonction suivie de sa _v2
--     (18 lignes). Différences attendues UNIQUEMENT : l'authentification
--     (_session_user / v_etab_id à la place de p_etab_id + crypt), l'ordre
--     jeton/champs de add_filiere, et le bloc EMAIL_DEJA_UTILISE de update_info.
-- select p.oid::regprocedure as fonction, pg_get_functiondef(p.oid) as definition
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and regexp_replace(p.proname, '_v2$', '') in (
--     'etablissement_get_own', 'etablissement_update_info', 'etablissement_update_localisation',
--     'etablissement_update_contact_extras', 'etablissement_update_logo', 'etablissement_update_photos',
--     'etablissement_add_filiere', 'etablissement_delete_filiere', 'etablissement_demander_premium')
-- order by regexp_replace(p.proname, '_v2$', ''), p.proname;
--
-- V5. Test fonctionnel complet SANS trace : fichier séparé 6a-2-tests-rollback.sql,
--     puis sa requête V-trace.
