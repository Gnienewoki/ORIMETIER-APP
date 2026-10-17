-- ============================================================
-- ORIMETIER — Suppression du compte élève : ÉTAPE d (RÉVERSIBLE)
-- Couper tout accès public aux données élèves, sans rien supprimer.
--
-- Pré-requis :
--   - front sans compte élève déployé (commit b969c96, sw v34) ;
--   - Edge Function redéployée sans le rôle 'eleve' (étape c) ;
--   - test à blanc 0 lancé et rapporté.
--
-- Effets (dans une transaction) :
--   1. Table eleves : plus aucun droit pour PUBLIC, anon, authenticated.
--   2. Table notes  : idem. Ce n'était pas demandé explicitement, mais notes ne contient
--      que des notes sur des élèves inscrits, elle est lisible par tous aujourd'hui
--      (policy « lecture notes », USING true) et le front ne la lit plus.
--   3. Fonctions élève : plus exécutables par PUBLIC, anon, authenticated :
--        list_eleves(), eleve_session_open(text, text), eleve_save_riasec(text, jsonb),
--        eleve_update_email(text, text), admin_set_eleve_banni_v2(text, text, boolean).
--      Elles restent en base (suppression à l'étape e).
--   4. Policies publiques supprimées :
--        « insertion inscription eleve » sur eleves (INSERT pour public, WITH CHECK true),
--        « lecture notes » sur notes (SELECT pour public, USING true).
--      RLS reste activée : sans policy ni droit, plus aucun accès direct.
--
-- Ce qui continue de marcher : tout le site. Le front (b969c96) n'appelle plus aucune de
-- ces fonctions ni tables. service_role et postgres (SQL Editor) gardent leurs accès.
--
-- Sessions élève encore ouvertes : leur jeton reste en base jusqu'à l'étape e, mais il ne
-- sert plus à rien (le front les efface, et les fonctions élève ne sont plus exécutables).
--
-- Retour arrière : bloc commenté en fin de fichier, à coller tel quel si besoin. Il remet
-- les droits « tels que le front les utilisait ». Si le test à blanc 0 a montré d'autres
-- droits (lignes droit_table), les ajuster d'après ce résultat.
-- ============================================================

BEGIN;

-- 0) Garde-fous : les objets visés existent (sinon : rien n'est fait, message clair)
DO $$
begin
  if to_regclass('public.eleves') is null then
    raise exception 'Table public.eleves absente : étape d inutile ou déjà dépassée';
  end if;
  if to_regprocedure('public.list_eleves()') is null
     or to_regprocedure('public.eleve_session_open(text,text)') is null
     or to_regprocedure('public.eleve_save_riasec(text,jsonb)') is null
     or to_regprocedure('public.eleve_update_email(text,text)') is null
     or to_regprocedure('public.admin_set_eleve_banni_v2(text,text,boolean)') is null then
    raise exception 'Une fonction élève attendue est absente : relancer le test à blanc 0 et me l''envoyer';
  end if;
end $$;

-- 1) Table eleves : aucun droit public
REVOKE ALL ON TABLE public.eleves FROM PUBLIC, anon, authenticated;

-- 2) Table notes : aucun droit public (si elle existe)
DO $$
begin
  if to_regclass('public.notes') is not null then
    execute 'REVOKE ALL ON TABLE public.notes FROM PUBLIC, anon, authenticated';
  end if;
end $$;

-- 3) Fonctions élève : plus exécutables publiquement
REVOKE ALL ON FUNCTION public.list_eleves() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.eleve_session_open(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.eleve_save_riasec(text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.eleve_update_email(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_set_eleve_banni_v2(text, text, boolean) FROM PUBLIC, anon, authenticated;

-- 4) Policies publiques
DROP POLICY IF EXISTS "insertion inscription eleve" ON public.eleves;
DO $$
begin
  if to_regclass('public.notes') is not null then
    execute 'DROP POLICY IF EXISTS "lecture notes" ON public.notes';
  end if;
end $$;

COMMIT;

-- Contrôle : voir supabase-migration-2026-10-17-suppression-eleve-controle.sql, requête « APRÈS d ».

-- ============================================================
-- RETOUR ARRIÈRE (à coller tel quel dans le SQL Editor, seulement si besoin)
-- Remet l'état d'avant l'étape d, tel que le front l'utilisait :
--   - INSERT direct sur eleves par la clé publique (inscription) ;
--   - SELECT direct sur notes par la clé publique (chargement) ;
--   - les 5 fonctions exécutables par anon et authenticated
--     (droits d'origine : sessions-2a-eleve.sql l. 104-162, admins-5a-2a-utilisateurs.sql,
--      list_eleves appelée sans jeton par l'ancien front).
-- Ajuster d'après les lignes « droit_table » du test à blanc 0 si elles différaient.
-- ============================================================
-- BEGIN;
-- GRANT INSERT ON TABLE public.eleves TO anon, authenticated;
-- CREATE POLICY "insertion inscription eleve" ON public.eleves FOR INSERT TO public WITH CHECK (true);
-- GRANT SELECT ON TABLE public.notes TO anon, authenticated;
-- CREATE POLICY "lecture notes" ON public.notes FOR SELECT TO public USING (true);
-- GRANT EXECUTE ON FUNCTION public.list_eleves() TO anon, authenticated;
-- GRANT EXECUTE ON FUNCTION public.eleve_session_open(text, text) TO anon, authenticated;
-- GRANT EXECUTE ON FUNCTION public.eleve_save_riasec(text, jsonb) TO anon, authenticated;
-- GRANT EXECUTE ON FUNCTION public.eleve_update_email(text, text) TO anon, authenticated;
-- GRANT EXECUTE ON FUNCTION public.admin_set_eleve_banni_v2(text, text, boolean) TO anon, authenticated;
-- COMMIT;
