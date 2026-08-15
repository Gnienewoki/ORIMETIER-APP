-- À exécuter dans le SQL Editor de Supabase (production), après
-- supabase-migration-2026-08-15-admin-only-contact.sql.
-- ============================================================
-- Harmonise le formulaire d'inscription directe (établissement NON
-- pré-inscrit) avec le formulaire de récupération de compte : ajoute
-- tel2, tel3 et site_web à etablissement_register().
--
-- ⚠️ La version actuellement en production de cette fonction (avec
-- p_photos/p_categorie/p_sous_categorie/p_secteur) n'existe dans aucun
-- fichier de migration commité — elle a été appliquée directement via
-- l'éditeur SQL Supabase. Ce CREATE OR REPLACE la reconstruit à partir
-- de l'ancienne version connue (supabase-migration.sql) et des noms de
-- colonnes utilisés par ailleurs (photos, categorie, sous_categorie,
-- secteur, site_web). Vérifier la définition réelle avant d'exécuter si
-- un doute existe. Les 3 nouveaux paramètres sont ajoutés en fin de
-- liste avec DEFAULT NULL : comme les appels RPC se font par paramètres
-- nommés (PostgREST), les appels existants restent valides.
-- ============================================================

CREATE OR REPLACE FUNCTION public.etablissement_register(
  p_id text, p_nom text, p_region text, p_ville text, p_quartier text, p_type text,
  p_responsable text, p_tel text, p_email text, p_password text, p_date_inscription text,
  p_filieres_proposees jsonb, p_photos jsonb DEFAULT '[]'::jsonb,
  p_categorie text DEFAULT NULL, p_sous_categorie text DEFAULT NULL, p_secteur text DEFAULT NULL,
  p_tel2 text DEFAULT NULL, p_tel3 text DEFAULT NULL, p_site_web text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if p_nom is null or length(trim(p_nom)) = 0 then return false; end if;
  if p_ville is null or length(trim(p_ville)) = 0 then return false; end if;
  if p_email is null or length(trim(p_email)) = 0 then return false; end if;
  if p_password is null or length(trim(p_password)) = 0 then return false; end if;
  if exists (select 1 from etablissements where email = p_email) then return false; end if;

  insert into etablissements(
    id, nom, region, ville, quartier, type, responsable, tel, tel2, tel3, email, password,
    statut, active, date_inscription, filieres_proposees, photos, categorie, sous_categorie, secteur, site_web
  ) values (
    p_id, p_nom, p_region, p_ville, p_quartier, p_type, p_responsable, p_tel, p_tel2, p_tel3, p_email, p_password,
    'en_attente', true, p_date_inscription, coalesce(p_filieres_proposees, '[]'::jsonb), coalesce(p_photos, '[]'::jsonb),
    p_categorie, p_sous_categorie, p_secteur, p_site_web
  );
  return true;
end; $function$;
