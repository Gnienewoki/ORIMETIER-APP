-- À exécuter dans le SQL Editor de Supabase (production), EN PREMIER
-- (1 sur 3 de cette migration).
-- ============================================================
-- Nouvelle table : les inscriptions directes d'établissement (formulaire
-- public) n'insèrent plus dans etablissements. Elles créent une DEMANDE que
-- l'admin examine manuellement (pour écarter les doublons non détectés
-- automatiquement, ex. variantes orthographiques) avant de créer
-- l'établissement lui-même via le circuit d'import en masse existant
-- (admin_bulk_import_etablissements, format nom;region;ville;quartier;
-- secteur;responsable;tel — inchangé).
--
-- Mêmes colonnes que les 20 paramètres de etablissement_register, moins
-- p_id (inutile ici, un id de demande est généré séparément). date_demande
-- suit la convention texte "JJ/MM/AAAA HH24:MI" déjà utilisée par
-- date_inscription/date_inscription ailleurs dans l'app (cf.
-- admin_bulk_import_etablissements : to_char(now(),'DD/MM/YYYY')), plutôt
-- qu'un timestamptz, pour rester cohérent avec le reste du schéma.
--
-- Pas de RLS, pas de GRANT à anon/authenticated : même modèle de sécurité
-- que les autres tables (eleves/inspecteurs/etablissements) — accès
-- exclusivement via des fonctions SECURITY DEFINER dédiées.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.demandes_inscription_etablissements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nom text NOT NULL,
  region text,
  ville text NOT NULL,
  quartier text,
  type text,
  responsable text,
  tel text,
  email text NOT NULL,
  password text NOT NULL,
  date_inscription text,
  filieres_proposees jsonb DEFAULT '[]'::jsonb,
  photos jsonb DEFAULT '[]'::jsonb,
  categorie text,
  sous_categorie text,
  secteur text,
  tel2 text,
  tel3 text,
  site_web text,
  contact_tel text,
  date_demande text NOT NULL DEFAULT to_char(now(), 'DD/MM/YYYY HH24:MI'),
  statut_demande text NOT NULL DEFAULT 'en_attente' CHECK (statut_demande IN ('en_attente','traite'))
);
