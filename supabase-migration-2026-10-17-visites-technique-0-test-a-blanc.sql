-- ============================================================
-- ORIMETIER — Visites : test à blanc AVANT la migration visites-technique-1
-- À exécuter dans le SQL Editor de Supabase. LECTURE SEULE : tout se
-- termine par ROLLBACK, aucune ligne n'est écrite ni modifiée.
-- ============================================================
BEGIN;
SET TRANSACTION READ ONLY;

-- 1. Définition actuelle de log_visite : la liste fermée ne doit PAS encore
--    contenir 'technique.html'.
SELECT pg_get_functiondef('public.log_visite(text)'::regprocedure) AS definition_actuelle;

-- 2. Droits d'exécution actuels (doivent inclure anon) : CREATE OR REPLACE
--    les conserve, la migration n'y touche pas.
SELECT grantee, privilege_type
FROM information_schema.routine_privileges
WHERE routine_schema = 'public' AND routine_name = 'log_visite'
ORDER BY grantee;

-- 3. Aucune contrainte CHECK sur visites.page qui refuserait 'technique.html'
--    (attendu : aucune ligne).
SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.visites'::regclass AND contype = 'c';

-- 4. Répartition actuelle des visites par page (historique, inchangé par la
--    migration) ; 'technique.html' doit être absente.
SELECT page, count(*) AS visites, min(visited_at)::date AS premier_jour, max(visited_at)::date AS dernier_jour
FROM public.visites
GROUP BY page
ORDER BY page;

ROLLBACK;
