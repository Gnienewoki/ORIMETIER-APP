-- ============================================================
-- ORIMETIER — Suivi facultatif d'élèves par un inspecteur (chantier séparé
-- de la refonte design). Répertoire privé à chaque inspecteur, en saisie
-- libre uniquement : aucun lien avec un compte élève existant (table
-- eleves) — à ne pas confondre avec la table "notes" existante
-- (inspecteur_add_note), qui elle est rattachée à un vrai compte élève et
-- visible par l'élève sur son propre tableau de bord. Ici, rien n'est
-- jamais visible par un élève ; seul l'inspecteur propriétaire du
-- répertoire peut lire/modifier ses propres fiches (vérifié dans chaque
-- fonction ci-dessous par inspecteur_id = p_inspecteur_id, en plus de
-- l'authentification par mot de passe).
--
-- Deux tables :
--   suivi_eleves       : une fiche par élève suivi (identité en saisie
--                        libre, raisons du suivi, appréciation finale).
--   suivi_eleves_notes : les notes de remédiation au fil du temps
--                        (une note = une date choisie par l'inspecteur +
--                        un texte libre), rattachées à une fiche.
--
-- Les 7 "raisons du suivi" reprennent les 7 dimensions du test LYCAM déjà
-- utilisées ailleurs dans l'app (cf. DIMENSIONS dans lycam.js) : IE, AF,
-- RS, CS, AB, BS, PS. Simple réutilisation des mêmes libellés/codes à
-- titre de catégorisation — aucun lien de calcul avec un résultat LYCAM
-- réel.
--
-- Pas de RLS, pas de GRANT à anon/authenticated : même modèle de sécurité
-- que le reste de l'app (notes, messages...) — accès exclusivement via
-- les fonctions SECURITY DEFINER ci-dessous.
--
-- À exécuter en une fois dans l'éditeur SQL de Supabase.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.suivi_eleves (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inspecteur_id text NOT NULL REFERENCES public.inspecteurs(id),
  nom text NOT NULL,
  prenoms text,
  classe text NOT NULL,
  raisons jsonb NOT NULL DEFAULT '[]'::jsonb,
  appreciation_finale text,
  date_ajout text NOT NULL DEFAULT to_char(now(), 'DD/MM/YYYY')
);
COMMENT ON TABLE public.suivi_eleves IS 'Répertoire privé d''élèves suivis par un inspecteur, en saisie libre (aucun lien avec la table eleves)';
COMMENT ON COLUMN public.suivi_eleves.raisons IS 'Tableau JSON des codes LYCAM sélectionnés, ex. ["IE","AB"] — voir CHECK dans inspecteur_suivi_add_eleve';

CREATE INDEX IF NOT EXISTS suivi_eleves_inspecteur_id_idx ON public.suivi_eleves(inspecteur_id);

CREATE TABLE IF NOT EXISTS public.suivi_eleves_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  suivi_eleve_id uuid NOT NULL REFERENCES public.suivi_eleves(id) ON DELETE CASCADE,
  date_note text NOT NULL,
  texte text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON COLUMN public.suivi_eleves_notes.date_note IS 'Date choisie par l''inspecteur (JJ/MM/AAAA), distincte de created_at qui sert uniquement à départager l''ordre chronologique en cas de dates identiques';

CREATE INDEX IF NOT EXISTS suivi_eleves_notes_suivi_eleve_id_idx ON public.suivi_eleves_notes(suivi_eleve_id);

-- ------------------------------------------------------------
-- RPCs (toutes vérifient inspecteurs.id/password, et que le compte n'est
-- pas banni — même traitement qu'un compte inexistant ailleurs dans
-- l'app, cf. espAccountStillExists côté client).
-- ------------------------------------------------------------

-- Ajoute une fiche de suivi. p_raisons : tableau JSON de codes parmi les 7
-- dimensions LYCAM (au moins une raison obligatoire). Retourne le nouvel id
-- (text, comme tous les id manipulés côté client) ou lève une exception.
CREATE OR REPLACE FUNCTION public.inspecteur_suivi_add_eleve(
  p_inspecteur_id text, p_password text,
  p_nom text, p_prenoms text, p_classe text, p_raisons jsonb
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_id uuid;
begin
  if not exists (
    select 1 from inspecteurs
    where id = p_inspecteur_id and password = p_password and coalesce(banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  if coalesce(trim(p_nom), '') = '' or coalesce(trim(p_classe), '') = '' then
    raise exception 'Nom et classe sont obligatoires';
  end if;

  if p_raisons is null or jsonb_typeof(p_raisons) <> 'array' or jsonb_array_length(p_raisons) = 0 then
    raise exception 'Au moins une raison de suivi est obligatoire';
  end if;

  if exists (
    select 1 from jsonb_array_elements_text(p_raisons) as r
    where r not in ('IE','AF','RS','CS','AB','BS','PS')
  ) then
    raise exception 'Raison de suivi invalide';
  end if;

  insert into suivi_eleves(inspecteur_id, nom, prenoms, classe, raisons)
    values (p_inspecteur_id, trim(p_nom), nullif(trim(p_prenoms), ''), trim(p_classe), p_raisons)
    returning id into v_id;

  return v_id::text;
end; $function$;

-- Répertoire complet de l'inspecteur connecté (sans les notes, chargées à
-- part par élève pour ne pas tout récupérer d'un coup).
CREATE OR REPLACE FUNCTION public.inspecteur_suivi_list_eleves(p_inspecteur_id text, p_password text)
RETURNS TABLE(
  id text, nom text, prenoms text, classe text, raisons jsonb,
  appreciation_finale text, date_ajout text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if not exists (
    select 1 from inspecteurs
    where id = p_inspecteur_id and password = p_password and coalesce(banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  return query
    select s.id::text, s.nom, s.prenoms, s.classe, s.raisons, s.appreciation_finale, s.date_ajout
    from suivi_eleves s
    where s.inspecteur_id = p_inspecteur_id
    order by s.nom asc, s.prenoms asc;
end; $function$;

-- Fiche d'un seul élève suivi (pour l'écran de détail/rapport). Vérifie que
-- la fiche appartient bien à l'inspecteur appelant.
CREATE OR REPLACE FUNCTION public.inspecteur_suivi_get_eleve(p_inspecteur_id text, p_password text, p_suivi_id text)
RETURNS TABLE(
  id text, nom text, prenoms text, classe text, raisons jsonb,
  appreciation_finale text, date_ajout text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if not exists (
    select 1 from inspecteurs
    where id = p_inspecteur_id and password = p_password and coalesce(banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  return query
    select s.id::text, s.nom, s.prenoms, s.classe, s.raisons, s.appreciation_finale, s.date_ajout
    from suivi_eleves s
    where s.id = p_suivi_id::uuid and s.inspecteur_id = p_inspecteur_id;
end; $function$;

-- Supprime une fiche de suivi (et ses notes, via ON DELETE CASCADE).
CREATE OR REPLACE FUNCTION public.inspecteur_suivi_delete_eleve(p_inspecteur_id text, p_password text, p_suivi_id text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if not exists (
    select 1 from inspecteurs
    where id = p_inspecteur_id and password = p_password and coalesce(banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  delete from suivi_eleves where id = p_suivi_id::uuid and inspecteur_id = p_inspecteur_id;
  return found;
end; $function$;

-- Sauvegarde/écrase l'appréciation finale (texte de synthèse pour le rapport).
CREATE OR REPLACE FUNCTION public.inspecteur_suivi_set_appreciation(
  p_inspecteur_id text, p_password text, p_suivi_id text, p_appreciation text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if not exists (
    select 1 from inspecteurs
    where id = p_inspecteur_id and password = p_password and coalesce(banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  update suivi_eleves
    set appreciation_finale = nullif(trim(p_appreciation), '')
    where id = p_suivi_id::uuid and inspecteur_id = p_inspecteur_id;
  return found;
end; $function$;

-- Ajoute une note de remédiation (date choisie par l'inspecteur + texte libre).
CREATE OR REPLACE FUNCTION public.inspecteur_suivi_add_note(
  p_inspecteur_id text, p_password text, p_suivi_id text, p_date_note text, p_texte text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if not exists (
    select 1 from inspecteurs
    where id = p_inspecteur_id and password = p_password and coalesce(banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  if not exists (select 1 from suivi_eleves where id = p_suivi_id::uuid and inspecteur_id = p_inspecteur_id) then
    raise exception 'unauthorized';
  end if;

  if coalesce(trim(p_date_note), '') = '' or coalesce(trim(p_texte), '') = '' then
    raise exception 'Date et texte de la note sont obligatoires';
  end if;

  insert into suivi_eleves_notes(suivi_eleve_id, date_note, texte)
    values (p_suivi_id::uuid, trim(p_date_note), trim(p_texte));
  return true;
end; $function$;

-- Notes de remédiation d'une fiche, triées chronologiquement (date choisie
-- par l'inspecteur en premier critère, created_at pour départager les ex-aequo).
CREATE OR REPLACE FUNCTION public.inspecteur_suivi_list_notes(p_inspecteur_id text, p_password text, p_suivi_id text)
RETURNS TABLE(id text, date_note text, texte text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if not exists (
    select 1 from inspecteurs
    where id = p_inspecteur_id and password = p_password and coalesce(banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  if not exists (select 1 from suivi_eleves where id = p_suivi_id::uuid and inspecteur_id = p_inspecteur_id) then
    raise exception 'unauthorized';
  end if;

  return query
    select n.id::text, n.date_note, n.texte
    from suivi_eleves_notes n
    where n.suivi_eleve_id = p_suivi_id::uuid
    order by to_date(n.date_note, 'DD/MM/YYYY') asc, n.created_at asc;
end; $function$;
