-- ============================================================
-- ORIMETIER — Phase 5a-2d : RPC admin par jeton (établissements, écritures simples).
--
-- Pré-requis : 5a-1 exécutée (admin_session_open, branche 'admin' de
-- _session_user). Migration ADDITIVE : les anciennes fonctions
-- (p_admin_password) restent en service jusqu'en 5c.
--
-- Nouvelles fonctions (suffixe _v2) :
--   admin_set_etab_statut_v2             (live l. 395-406)
--   admin_set_filiere_statut_v2          (live l. 408-424)
--   admin_set_etab_premium_v2            (live l. 382-393)
--   admin_valider_premium_v2             (live l. 539-552)
--   admin_update_etab_classification_v2  (live l. 467-482)
-- Écrites à partir de supabase/reference/live-2026-09-26.sql. Seule la
-- ligne d'authentification change : la vérification admin_config (ou
-- l'appel à admin_login() pour admin_update_etab_classification) est
-- remplacée par _session_user(p_token, 'admin'), qui lève SESSION_INVALIDE
-- (P0401) si le jeton est invalide, expiré, révoqué, ou si l'admin est
-- désactivé. Le reste du corps est identique, y compris les valeurs de
-- retour du live :
--   - set_etab_statut / set_etab_premium / valider_premium : false si
--     l'établissement n'existe pas (return found) ;
--   - set_filiere_statut et update_etab_classification : true même si
--     l'établissement ou la filière n'existe pas (return true du live,
--     conservé tel quel).
-- admin_update_etab_classification_v2 ne dépend plus de admin_login()
-- (qui sera supprimée en 5c).
-- Aucune de ces fonctions ne renvoie de RETURNS TABLE : pas de piège
-- d'ambiguïté sur les noms de colonnes.
--
-- À exécuter en une fois dans l'éditeur SQL de Supabase.
-- ============================================================

BEGIN;

-- Garde-fou : 5a-1 doit avoir été exécutée.
DO $$
begin
  if to_regprocedure('public.admin_session_open(text,text)') is null then
    raise exception 'admin_session_open absente : exécuter d''abord la migration 5a-1';
  end if;
end $$;

-- ------------------------------------------------------------
-- 1) admin_set_etab_statut_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_etab_statut_v2(p_token text, p_etab_id text, p_statut text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');
  update etablissements set statut = p_statut where id = p_etab_id;
  return found;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_set_etab_statut_v2(text, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_set_etab_statut_v2(text, text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 2) admin_set_filiere_statut_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_filiere_statut_v2(p_token text, p_etab_id text, p_filiere_id text, p_statut text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_filieres jsonb; v_updated jsonb;
begin
  perform _session_user(p_token, 'admin');
  select filieres_proposees into v_filieres from etablissements where id = p_etab_id;
  select jsonb_agg(
    case when elem->>'id' = p_filiere_id then elem || jsonb_build_object('statut', p_statut) else elem end
  ) into v_updated from jsonb_array_elements(coalesce(v_filieres, '[]'::jsonb)) elem;
  update etablissements set filieres_proposees = coalesce(v_updated, '[]'::jsonb) where id = p_etab_id;
  return true;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_set_filiere_statut_v2(text, text, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_set_filiere_statut_v2(text, text, text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 3) admin_set_etab_premium_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_etab_premium_v2(p_token text, p_etab_id text, p_premium boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');
  update etablissements set premium = p_premium where id = p_etab_id;
  return found;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_set_etab_premium_v2(text, text, boolean) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_set_etab_premium_v2(text, text, boolean) TO anon, authenticated;

-- ------------------------------------------------------------
-- 4) admin_valider_premium_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_valider_premium_v2(p_token text, p_etab_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');
  update etablissements set premium = true, demande_premium = false where id = p_etab_id;
  return found;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_valider_premium_v2(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_valider_premium_v2(text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 5) admin_update_etab_classification_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_update_etab_classification_v2(p_token text, p_etab_id text, p_categorie text, p_sous_categorie text, p_secteur text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');
  update etablissements
    set categorie = p_categorie, sous_categorie = p_sous_categorie, secteur = p_secteur
    where id = p_etab_id;
  return true;
end;
$function$;

REVOKE ALL ON FUNCTION public.admin_update_etab_classification_v2(text, text, text, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_update_etab_classification_v2(text, text, text, text, text) TO anon, authenticated;

COMMIT;

-- ============================================================
-- VÉRIFICATIONS (à lancer après exécution, une requête à la fois)
-- ============================================================
--
-- V1. Anciennes ET nouvelles fonctions présentes (10 lignes attendues)
-- select p.proname, pg_get_function_identity_arguments(p.oid) as args
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('admin_set_etab_statut', 'admin_set_etab_statut_v2',
--                     'admin_set_filiere_statut', 'admin_set_filiere_statut_v2',
--                     'admin_set_etab_premium', 'admin_set_etab_premium_v2',
--                     'admin_valider_premium', 'admin_valider_premium_v2',
--                     'admin_update_etab_classification', 'admin_update_etab_classification_v2')
-- order by 1, 2;
--
-- V2. Sécurité des 5 nouvelles fonctions (5 lignes :
--     security_definer = true, config = {search_path=public}, anon = true, authenticated = true)
-- select p.oid::regprocedure as fonction, p.prosecdef as security_definer, p.proconfig as config,
--        has_function_privilege('anon', p.oid, 'EXECUTE') as anon,
--        has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('admin_set_etab_statut_v2', 'admin_set_filiere_statut_v2',
--                     'admin_set_etab_premium_v2', 'admin_valider_premium_v2',
--                     'admin_update_etab_classification_v2')
-- order by 1;
--
-- V2 bis. admin_update_etab_classification_v2 n'appelle plus admin_login
--     (attendu : appelle_admin_login = false, appelle_session_user = true)
-- select p.prosrc like '%admin_login%' as appelle_admin_login,
--        p.prosrc like '%_session_user(p_token, ''admin'')%' as appelle_session_user
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public' and p.proname = 'admin_update_etab_classification_v2';
--
-- V3. Test fonctionnel complet SANS trace : fichier séparé
--     test-5a2d-v3.sql (bloc prêt à coller, ROLLBACK final).
--
-- V4. Aucune trace laissée par V3 (0, 0 et 0 attendus)
-- select (select count(*) from public.admins where id = 'adm_test') as admin_test,
--        (select count(*) from public.sessions where user_id = 'adm_test') as sessions_test,
--        (select count(*) from public.etablissements where id like 'test_5a2d%') as etab_test;
