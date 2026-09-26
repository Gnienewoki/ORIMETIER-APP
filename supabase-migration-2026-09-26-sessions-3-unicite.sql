-- ============================================================
-- ORIMETIER — Jetons de session, Phase 3 : unicité e-mail / téléphone.
--
-- Pourquoi : la réinitialisation de mot de passe (Phase 4) retrouve un
-- compte par e-mail, et l'ouverture de session par téléphone. Un doublon
-- rendrait l'une ou l'autre ambiguë.
--
-- Pré-requis vérifiés le 26/09/2026 :
--   - requête de doublons (e-mail insensible casse/espaces sur eleves,
--     inspecteurs, etablissements ; tel sur eleves, inspecteurs) : 0 ligne ;
--   - index uniques existants : *_pkey, etablissements_code_recuperation_idx,
--     inspecteurs_tel_unique (déjà en place, non recréé ici).
--
-- Index partiels : les lignes sans e-mail (dont les 4204 fiches
-- établissement non réclamées) ne sont pas concernées.
-- Si un doublon apparaissait entre-temps, le script échoue sans rien
-- créer (transaction).
--
-- À exécuter en une fois dans l'éditeur SQL de Supabase.
-- ============================================================

BEGIN;

CREATE UNIQUE INDEX eleves_email_unique
  ON public.eleves (lower(trim(email)))
  WHERE nullif(trim(email), '') IS NOT NULL;

CREATE UNIQUE INDEX inspecteurs_email_unique
  ON public.inspecteurs (lower(trim(email)))
  WHERE nullif(trim(email), '') IS NOT NULL;

CREATE UNIQUE INDEX etablissements_email_unique
  ON public.etablissements (lower(trim(email)))
  WHERE nullif(trim(email), '') IS NOT NULL;

CREATE UNIQUE INDEX eleves_tel_unique
  ON public.eleves (tel)
  WHERE nullif(trim(tel), '') IS NOT NULL;

COMMIT;

-- ============================================================
-- VÉRIFICATION (à lancer après exécution)
-- Attendu : les 4 nouveaux index + inspecteurs_tel_unique.
-- ============================================================
-- select tablename, indexname, indexdef
-- from pg_indexes
-- where schemaname = 'public'
--   and indexname in ('eleves_email_unique', 'inspecteurs_email_unique',
--                     'etablissements_email_unique', 'eleves_tel_unique',
--                     'inspecteurs_tel_unique')
-- order by 1, 2;
