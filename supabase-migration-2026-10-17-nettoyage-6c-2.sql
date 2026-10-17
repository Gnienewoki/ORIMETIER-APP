-- ============================================================
-- ORIMETIER — Nettoyage 6c-2 : suppression de session LYCAM / MBTI par jeton,
-- puis retrait des 4 dernières anciennes fonctions à mot de passe.
-- À exécuter dans le SQL Editor de Supabase APRÈS :
--   - nettoyage-6c-1 (les 57 anciennes fonctions déjà supprimées) ;
--   - le test à blanc nettoyage-6c-2-test-a-blanc (toutes les lignes ok = true).
--
-- Nouvelles fonctions (modèle : inspecteur_lycam_list_sessions_v2 /
-- inspecteur_mbti_list_sessions_v2 et inspecteur_suivi_delete_eleve_v2, migration 7a-2b) :
--   inspecteur_lycam_delete_session_v2(p_token, p_session_id) -> boolean
--   inspecteur_mbti_delete_session_v2(p_token, p_session_id)  -> boolean
-- Comportement :
--   - inspecteur identifié par _session_user(p_token, 'inspecteur'), appelée EN
--     PREMIER : SESSION_INVALIDE (P0401) si le jeton est inconnu, expiré, révoqué,
--     d'un autre rôle, ou si la fiche est absente ou bannie ;
--   - inspecteur banni : raise 'unauthorized' (comme inspecteur_suivi_delete_eleve_v2) ;
--   - session inexistante OU appartenant à un autre inspecteur : la même erreur
--     'unauthorized', sans distinction (aucune fuite d'information) ;
--   - les résultats de la session sont supprimés explicitement dans la même
--     fonction, puis la session. La clé étrangère session_id ... ON DELETE CASCADE
--     des tables de résultats ferait la même chose ; la suppression explicite ne
--     dépend pas de cette contrainte ;
--   - retourne true (found) une fois la session supprimée.
-- Différence assumée avec inspecteur_suivi_delete_eleve_v2 : celle-ci renvoie
-- false (sans erreur) pour une fiche inconnue ou d'un autre inspecteur. Ici, on lève
-- 'unauthorized', comme inspecteur_suivi_list_notes_v2 / add_note_v2.
--
-- Anciennes fonctions supprimées (sans IF EXISTS : une signature fausse annule
-- toute la transaction) :
--   admin_restore_backup(text, jsonb)
--   inspecteur_add_note(text, text, text, text)
--   inspecteur_lycam_delete_session(text, text, text)
--   inspecteur_mbti_delete_session(text, text, text)
-- Aucune table n'est supprimée ni modifiée.
--
-- Droits : SECURITY DEFINER, SET search_path TO 'public', REVOKE ALL FROM public,
-- GRANT EXECUTE TO anon, authenticated (identiques aux autres fonctions _v2).
-- ============================================================

BEGIN;

-- 0) Garde-fous
DO $$
begin
  if to_regprocedure('public._session_user(text,text)') is null then
    raise exception '_session_user absente : exécuter d''abord la Phase 1';
  end if;
  if to_regprocedure('public.inspecteur_lycam_list_sessions_v2(text)') is null
     or to_regprocedure('public.inspecteur_mbti_list_sessions_v2(text)') is null then
    raise exception 'fonctions LYCAM/MBTI _v2 absentes : exécuter d''abord la migration 7a-2b';
  end if;
end $$;

-- ------------------------------------------------------------
-- 1) inspecteur_lycam_delete_session_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_lycam_delete_session_v2(p_token text, p_session_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_insp_id text;
begin
  v_insp_id := _session_user(p_token, 'inspecteur');
  if not exists (
    select 1 from inspecteurs
    where id = v_insp_id and coalesce(banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  if not exists (select 1 from lycam_sessions where id = p_session_id and inspecteur_id = v_insp_id) then
    raise exception 'unauthorized';
  end if;

  delete from lycam_resultats where session_id = p_session_id;
  delete from lycam_sessions where id = p_session_id and inspecteur_id = v_insp_id;
  return found;
end; $function$;

REVOKE ALL ON FUNCTION public.inspecteur_lycam_delete_session_v2(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_lycam_delete_session_v2(text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 2) inspecteur_mbti_delete_session_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_mbti_delete_session_v2(p_token text, p_session_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_insp_id text;
begin
  v_insp_id := _session_user(p_token, 'inspecteur');
  if not exists (
    select 1 from inspecteurs
    where id = v_insp_id and coalesce(banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  if not exists (select 1 from mbti_sessions where id = p_session_id and inspecteur_id = v_insp_id) then
    raise exception 'unauthorized';
  end if;

  delete from mbti_resultats where session_id = p_session_id;
  delete from mbti_sessions where id = p_session_id and inspecteur_id = v_insp_id;
  return found;
end; $function$;

REVOKE ALL ON FUNCTION public.inspecteur_mbti_delete_session_v2(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_mbti_delete_session_v2(text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 3) Retrait des 4 dernières anciennes fonctions à mot de passe
-- ------------------------------------------------------------
DROP FUNCTION public.admin_restore_backup(text, jsonb);
DROP FUNCTION public.inspecteur_add_note(text, text, text, text);
DROP FUNCTION public.inspecteur_lycam_delete_session(text, text, text);
DROP FUNCTION public.inspecteur_mbti_delete_session(text, text, text);

COMMIT;

-- Contrôle (lecture seule) : les 2 nouvelles fonctions, leurs réglages et leurs droits.
-- Attendu : 2 lignes, retour boolean, security_definer = true,
-- config = {search_path=public}, anon = true, authenticated = true, public = false.
SELECT p.proname AS fonction,
       pg_get_function_identity_arguments(p.oid) AS arguments,
       pg_get_function_result(p.oid) AS retour,
       p.prosecdef AS security_definer,
       p.proconfig AS config,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated,
       EXISTS (SELECT 1 FROM aclexplode(p.proacl) a
               WHERE a.grantee = 0 AND a.privilege_type = 'EXECUTE') AS public,
       p.proacl::text AS acl
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('inspecteur_lycam_delete_session_v2', 'inspecteur_mbti_delete_session_v2')
ORDER BY 1;
