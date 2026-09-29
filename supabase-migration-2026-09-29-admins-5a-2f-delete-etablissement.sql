-- ============================================================
-- ORIMETIER — Phase 5a-2f : RPC admin par jeton (suppression d'établissement).
--
-- Pré-requis : 5a-1 exécutée (admin_session_open, branche 'admin' de
-- _session_user). Migration ADDITIVE : l'ancienne fonction
-- admin_delete_etablissement(p_admin_password, p_etab_id) reste en service
-- jusqu'en 5c.
--
-- Nouvelle fonction :
--   admin_delete_etablissement_v2(p_token, p_etab_id)   (live l. 103-116)
-- Écrite à partir de supabase/reference/live-2026-09-26.sql. Seule la ligne
-- d'authentification change : l'appel à admin_login(p_admin_password) est
-- remplacé par _session_user(p_token, 'admin'), qui lève SESSION_INVALIDE
-- (P0401) si le jeton est invalide, expiré, révoqué, ou si l'admin est
-- désactivé. Le reste est identique au live :
--   - un seul DELETE sur etablissements (where id = p_etab_id) ;
--   - return true dans tous les cas, MÊME pour un id inconnu.
-- Aucun nettoyage des sessions ni des réinitialisations de mot de passe de
-- l'établissement supprimé dans cette version (comportement du live).
--
-- Diagnostic 5a-2f (29/09/2026) : aucune clé étrangère vers etablissements,
-- aucun trigger sur DELETE, aucune règle. La suppression ne touche donc que
-- la ligne de etablissements. Liens non protégés existants : sessions.user_id,
-- password_resets.account_id, eleves.etablissement (texte libre) — non
-- modifiés par cette fonction.
--
-- admin_delete_etablissement_v2 ne dépend plus de admin_login() (qui sera
-- supprimée en 5c).
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
-- admin_delete_etablissement_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_delete_etablissement_v2(p_token text, p_etab_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');
  delete from etablissements where id = p_etab_id;
  return true;
end;
$function$;

REVOKE ALL ON FUNCTION public.admin_delete_etablissement_v2(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_delete_etablissement_v2(text, text) TO anon, authenticated;

COMMIT;

-- ============================================================
-- VÉRIFICATIONS (à lancer après exécution, une requête à la fois)
-- ============================================================
--
-- V1. Ancienne ET nouvelle fonction présentes (2 lignes attendues)
-- select p.proname, pg_get_function_identity_arguments(p.oid) as args
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('admin_delete_etablissement', 'admin_delete_etablissement_v2')
-- order by 1, 2;
--
-- V2. Sécurité de la nouvelle fonction (1 ligne :
--     security_definer = true, config = {search_path=public}, anon = true, authenticated = true,
--     appelle_admin_login = false, appelle_session_user = true)
-- select p.oid::regprocedure as fonction, p.prosecdef as security_definer, p.proconfig as config,
--        has_function_privilege('anon', p.oid, 'EXECUTE') as anon,
--        has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated,
--        p.prosrc like '%admin_login%' as appelle_admin_login,
--        p.prosrc like '%_session_user(p_token, ''admin'')%' as appelle_session_user
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public' and p.proname = 'admin_delete_etablissement_v2';
--
-- V3. Test fonctionnel complet SANS trace : fichier séparé
--     test-5a2f-v3.sql (bloc prêt à coller, ROLLBACK final).
--
-- V4. Aucune trace laissée par V3 (0, 0 et 0 attendus)
-- select (select count(*) from public.admins where id = 'adm_test') as admin_test,
--        (select count(*) from public.sessions where user_id = 'adm_test') as sessions_test,
--        (select count(*) from public.etablissements where id like 'test_5a2f%') as etab_test;
