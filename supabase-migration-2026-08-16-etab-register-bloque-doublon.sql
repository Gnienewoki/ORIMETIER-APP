-- À exécuter dans le SQL Editor de Supabase (production), EN SECOND,
-- après supabase-migration-2026-08-16-etab-verifier-doublon.sql.
-- ============================================================
-- Ajoute un blocage strict (filet de sécurité, bloquant) contre les
-- inscriptions en doublon d'établissement, en complément de la RPC de
-- vérification en temps réel etablissement_verifier_doublon() côté
-- formulaire. Comparaison insensible à la casse et aux espaces :
-- lower(trim(nom)).
--
-- Version reconstruite à l'identique de la définition confirmée en
-- production le 2026-08-16 (pg_get_functiondef), 20 paramètres, avec
-- uniquement l'ajout de la vérification de doublon avant l'insertion.
-- Signature inchangée -> CREATE OR REPLACE suffit (pas de DROP requis).
-- ============================================================

CREATE OR REPLACE FUNCTION public.etablissement_register(
  p_id text, p_nom text, p_region text, p_ville text, p_quartier text, p_type text,
  p_responsable text, p_tel text, p_email text, p_password text, p_date_inscription text,
  p_filieres_proposees jsonb, p_photos jsonb DEFAULT '[]'::jsonb,
  p_categorie text DEFAULT NULL::text, p_sous_categorie text DEFAULT NULL::text, p_secteur text DEFAULT NULL::text,
  p_tel2 text DEFAULT NULL::text, p_tel3 text DEFAULT NULL::text, p_site_web text DEFAULT NULL::text,
  p_contact_tel text DEFAULT NULL::text
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

  if exists (select 1 from etablissements where lower(trim(nom)) = lower(trim(p_nom))) then
    raise exception 'DOUBLON: Établissement déjà préinscrit, contacter le support pour récupérer vos codes de connexion. Tél : 07 87 63 34 81 - Email : gnienewoki@gmail.com';
  end if;

  if exists (select 1 from etablissements where email = p_email) then return false; end if;

  insert into etablissements(
    id, nom, region, ville, quartier, type, responsable, tel, tel2, tel3, email, password,
    statut, active, date_inscription, filieres_proposees, photos, categorie, sous_categorie, secteur, site_web, contact_tel
  ) values (
    p_id, p_nom, p_region, p_ville, p_quartier, p_type, p_responsable, p_tel, p_tel2, p_tel3, p_email, p_password,
    'en_attente', true, p_date_inscription, coalesce(p_filieres_proposees, '[]'::jsonb), coalesce(p_photos, '[]'::jsonb),
    p_categorie, p_sous_categorie, p_secteur, p_site_web, p_contact_tel
  );
  return true;
end;
$function$;
