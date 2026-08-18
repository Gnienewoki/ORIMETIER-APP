-- ============================================================
-- ORIMETIER — Migration data-superieur.js → Supabase
-- PHASE 2 / 5 (bis) : ajout d'une colonne "contact" sur universites et
-- grandes_ecoles, pour aligner l'affichage public sur la disposition déjà
-- utilisée côté privé (Établissement / Filière / Conditions d'accès /
-- Contact — table etablissements existante, non touchée par cette
-- migration).
--
-- data-superieur.js ne contient aujourd'hui aucune donnée de contact pour
-- les universités/grandes écoles publiques : la colonne est ajoutée vide
-- (NULL), à remplir manuellement plus tard, établissement par
-- établissement, directement dans Supabase.
--
-- Ne touche à aucun fichier du site (superieur.js / data-superieur.js /
-- superieur.html) et n'insère aucune donnée.
--
-- À exécuter en une fois dans l'éditeur SQL de Supabase, après la Phase 1.
-- ============================================================

ALTER TABLE public.universites ADD COLUMN IF NOT EXISTS contact text;
ALTER TABLE public.grandes_ecoles ADD COLUMN IF NOT EXISTS contact text;
