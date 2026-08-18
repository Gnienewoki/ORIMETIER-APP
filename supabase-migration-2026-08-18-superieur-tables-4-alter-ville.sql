-- ============================================================
-- ORIMETIER — Migration data-superieur.js → Supabase
-- PHASE 4 / 5 (bis) : ajout d'une colonne "ville" sur universites et
-- grandes_ecoles, sur le même principe que la colonne "contact" ajoutée en
-- Phase 2.
--
-- data-superieur.js ne contient aujourd'hui aucune donnée de ville pour les
-- universités/grandes écoles publiques : la colonne est ajoutée vide
-- (NULL), à remplir manuellement plus tard, établissement par
-- établissement, directement dans Supabase. Elle est prévue pour un futur
-- filtre transversal (par ville), pas utilisée par superieur.js à ce
-- stade — aucun changement d'affichage sur les onglets Universités
-- publiques / Grandes écoles publiques.
--
-- Ne touche à aucun fichier du site (superieur.js / data-superieur.js /
-- superieur.html) et n'insère aucune donnée.
--
-- À exécuter en une fois dans l'éditeur SQL de Supabase.
-- ============================================================

ALTER TABLE public.universites ADD COLUMN IF NOT EXISTS ville text;
ALTER TABLE public.grandes_ecoles ADD COLUMN IF NOT EXISTS ville text;
