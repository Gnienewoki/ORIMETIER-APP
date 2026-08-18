-- ============================================================
-- ORIMETIER — Migration data-superieur.js → Supabase
-- PHASE 1 / 5 : création des tables uniquement.
--
-- Ce script ne fait QUE créer les 5 tables ci-dessous, activer la RLS et
-- autoriser la lecture publique dessus. Il n'insère AUCUNE donnée et ne
-- touche à AUCUN fichier du site (superieur.js / data-superieur.js /
-- superieur.html continuent de fonctionner exactement comme avant tant que
-- ces fichiers ne sont pas modifiés séparément).
--
-- Écriture : aucune policy INSERT/UPDATE/DELETE n'est créée pour anon /
-- authenticated. Avec la RLS activée, ça bloque toute écriture publique par
-- défaut. Les phases suivantes (import initial, puis futures modifications
-- admin) passeront soit par la clé service_role (qui ignore la RLS), soit
-- par des fonctions RPC SECURITY DEFINER vérifiant admin_config, comme le
-- reste du projet (cf. admin_set_eleve_banni dans supabase-migration.sql).
--
-- À exécuter en une fois dans l'éditeur SQL de Supabase.
-- ============================================================

-- ============================================================
-- 1) universites — les universités publiques
-- ============================================================
CREATE TABLE IF NOT EXISTS public.universites (
  code text PRIMARY KEY,
  nom text NOT NULL,
  ordre int
);
COMMENT ON TABLE public.universites IS 'Universités publiques (ex-UNIVERSITES_NOMS de data-superieur.js)';

-- ============================================================
-- 2) universite_filieres — filières proposées par chaque université,
--    déjà résolues (résultat du croisement FILIERES_BASE x UNIV_PAR_NUMERO
--    x EXCLUSIONS x INCLUSIONS fait côté data-superieur.js)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.universite_filieres (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  universite_code text NOT NULL REFERENCES public.universites(code),
  nom text NOT NULL,
  bac text NOT NULL,
  age text NOT NULL,
  criteres text NOT NULL,
  numero_source int,
  ordre int
);
COMMENT ON TABLE public.universite_filieres IS 'Filières par université, résultat déjà résolu (ex-UNIVERSITES de data-superieur.js). numero_source = "n" du tableau PDF d''origine, conservé pour traçabilité uniquement.';

-- ============================================================
-- 3) debouches_filieres — débouchés par filière (source "Universités
--    publiques" du document DOB)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.debouches_filieres (
  nom text PRIMARY KEY,
  debouches text NOT NULL
);
COMMENT ON TABLE public.debouches_filieres IS 'Débouchés par filière, source universités publiques (ex-DEBOUCHES_FILIERES de data-superieur.js)';

-- ============================================================
-- 4) grandes_ecoles — les grandes écoles publiques
-- ============================================================
CREATE TABLE IF NOT EXISTS public.grandes_ecoles (
  id text PRIMARY KEY,
  nom text NOT NULL,
  tutelle text NOT NULL,
  ordre int
);
COMMENT ON TABLE public.grandes_ecoles IS 'Grandes écoles publiques (ex-clés de GRANDES_ECOLES de data-superieur.js)';

-- ============================================================
-- 5) grande_ecole_filieres — filières par grande école
-- ============================================================
CREATE TABLE IF NOT EXISTS public.grande_ecole_filieres (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  grande_ecole_id text NOT NULL REFERENCES public.grandes_ecoles(id),
  nom text NOT NULL,
  bac text NOT NULL,
  age text NOT NULL,
  debouches text NOT NULL,
  ordre int
);
COMMENT ON TABLE public.grande_ecole_filieres IS 'Filières par grande école (ex-GRANDES_ECOLES[...].filieres de data-superieur.js)';

-- ============================================================
-- RLS : lecture publique ouverte, écriture bloquée pour anon/authenticated
-- (pas de policy INSERT/UPDATE/DELETE = pas d'écriture publique possible)
-- ============================================================
ALTER TABLE public.universites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.universite_filieres ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.debouches_filieres ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grandes_ecoles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grande_ecole_filieres ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Lecture publique" ON public.universites
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "Lecture publique" ON public.universite_filieres
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "Lecture publique" ON public.debouches_filieres
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "Lecture publique" ON public.grandes_ecoles
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "Lecture publique" ON public.grande_ecole_filieres
  FOR SELECT TO anon, authenticated USING (true);
