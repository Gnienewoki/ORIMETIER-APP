-- ============================================================
-- ORIMETIER — Inscription inspecteur durcie : FICHIER B, FERMETURE DE L'INSERT DIRECT.
--
-- À LANCER UNIQUEMENT APRÈS le déploiement du front v2 (supabase-client.js qui appelle
-- inspecteur_register + sw.js 'orimetier-shell-v35') ET après avoir vérifié en production
-- qu'une inscription de test passe par la nouvelle fonction. Sinon l'ancien front (encore en
-- cache chez des visiteurs) ne pourra plus créer de compte : c'est le but, mais seulement une
-- fois le nouveau front en ligne.
--
-- Un bloc DO = une transaction : tout est appliqué, ou rien (à la moindre exception).
--   1. GARDES : inspecteur_register existe, est SECURITY DEFINER et exécutable par anon.
--   2. REVOKE INSERT ON public.inspecteurs FROM PUBLIC, anon, authenticated
--      (le retrait du droit sur la table retire aussi les éventuels droits INSERT par colonne).
--   3. DROP POLICY « insertion inscription inspecteur ».
-- La RLS reste activée : sans policy INSERT ni droit INSERT, double barrière.
-- inspecteur_register (SECURITY DEFINER, propriétaire de la table) n'est pas concernée.
-- messages_inspecteurs : non touché. Les autres droits (SELECT, UPDATE...) : non touchés.
-- Relançable : la deuxième fois, REVOKE est sans effet et la policy est déjà absente.
-- ============================================================

DO $migration$
begin
  -- ================= GARDES
  if to_regprocedure('public.inspecteur_register(text,text,text,text,text,text,text,text,text)') is null then
    raise exception 'GARDE : inspecteur_register absente (lancer A puis déployer le front avant B) : rien n''est modifié.';
  end if;
  if not (select p.prosecdef from pg_proc p
          where p.oid = to_regprocedure('public.inspecteur_register(text,text,text,text,text,text,text,text,text)')) then
    raise exception 'GARDE : inspecteur_register n''est pas SECURITY DEFINER (elle ne pourrait plus insérer après B) : rien n''est modifié.';
  end if;
  if not has_function_privilege('anon', 'public.inspecteur_register(text,text,text,text,text,text,text,text,text)', 'EXECUTE') then
    raise exception 'GARDE : anon ne peut pas exécuter inspecteur_register (l''inscription serait impossible) : rien n''est modifié.';
  end if;
  if (select c.relforcerowsecurity from pg_class c where c.oid = 'public.inspecteurs'::regclass) then
    raise exception 'GARDE : FORCE ROW LEVEL SECURITY actif sur inspecteurs : sans policy INSERT, inspecteur_register elle-même serait bloquée : rien n''est modifié.';
  end if;

  -- ================= FERMETURE
  execute 'REVOKE INSERT ON public.inspecteurs FROM PUBLIC, anon, authenticated';
  execute 'DROP POLICY IF EXISTS "insertion inscription inspecteur" ON public.inspecteurs';

  raise notice 'B appliquée : plus d''INSERT direct dans inspecteurs pour la clé publique ; inscription uniquement par inspecteur_register.';
end;
$migration$;

-- Vérification (attendu : insert_anon = false, insert_authenticated = false,
-- policy_presente = false, fonction_presente = true, execute_anon = true)
select
  has_any_column_privilege('anon', 'public.inspecteurs', 'INSERT')          as insert_anon,
  has_any_column_privilege('authenticated', 'public.inspecteurs', 'INSERT') as insert_authenticated,
  exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = 'inspecteurs'
            and p.policyname = 'insertion inscription inspecteur')           as policy_presente,
  to_regprocedure('public.inspecteur_register(text,text,text,text,text,text,text,text,text)') is not null as fonction_presente,
  has_function_privilege('anon', 'public.inspecteur_register(text,text,text,text,text,text,text,text,text)', 'EXECUTE') as execute_anon;

-- ============================================================
-- RETOUR ARRIÈRE (NE PAS LANCER sauf besoin : rouvre le trou certifie = true).
-- Rétablit exactement l'état d'avant B. À coller seul dans le SQL Editor, sans les « -- ».
-- ============================================================
-- DO $retour$
-- begin
--   execute 'GRANT INSERT ON public.inspecteurs TO anon, authenticated';
--   if not exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = 'inspecteurs'
--                  and p.policyname = 'insertion inscription inspecteur') then
--     execute 'CREATE POLICY "insertion inscription inspecteur" ON public.inspecteurs FOR INSERT TO public WITH CHECK (true)';
--   end if;
--   raise notice 'Retour arrière de B appliqué : INSERT direct rétabli pour anon / authenticated.';
-- end;
-- $retour$;
