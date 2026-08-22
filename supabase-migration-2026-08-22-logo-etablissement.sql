-- À exécuter dans le SQL Editor de Supabase (production).
-- ============================================================
-- Ajoute un logo d'établissement (logo_url), sur le modèle EXACT du champ
-- "photos" déjà en place : colonne nullable, masquée publiquement tant que
-- premium=false, modifiable depuis l'espace établissement, incluse dans le
-- circuit demande d'inscription -> admin -> etablissements.
--
-- Règle de masquage (identique à photos/tel/tel2/tel3/site_web) :
--   PUBLIC (masqué tant que premium=false) : logo_url
--   Toujours visible en clair (self-service ou admin) : etablissement_get_own,
--   admin_list_etablissements_full, admin_list_demandes_inscription_etablissements.
--
-- Toutes les fonctions ci-dessous dont le type de retour change (colonne
-- ajoutée à un RETURNS TABLE) sont précédées d'un DROP FUNCTION IF EXISTS
-- explicite avec la signature exacte de la version en production — ajouter
-- un paramètre ou une colonne de sortie via un simple CREATE OR REPLACE crée
-- une fonction surchargée (overload) au lieu de remplacer l'existante, piège
-- déjà rencontré sur ce projet (cf. RAPPORT-ASSAINISSEMENT-2026-08-16.md).
-- ============================================================

-- 1) Colonne logo_url : sur etablissements (fiche définitive) ET sur
--    demandes_inscription_etablissements (les inscriptions directes créent
--    une demande, pas un établissement — cf. étape 2 de
--    supabase-migration-2026-08-16-demandes-inscription-*.sql).
ALTER TABLE public.etablissements ADD COLUMN IF NOT EXISTS logo_url text;
ALTER TABLE public.demandes_inscription_etablissements ADD COLUMN IF NOT EXISTS logo_url text;

-- 2) etablissement_register : version en prod confirmée dans
--    supabase-migration-2026-08-16-demandes-inscription-2-register-et-verif.sql
--    (20 paramètres, insère dans demandes_inscription_etablissements). Ajout
--    de p_logo_url en 21e paramètre, DEFAULT NULL comme p_site_web/p_tel2/
--    p_tel3/p_contact_tel — mêmes types, DROP obligatoire (signature change).
DROP FUNCTION IF EXISTS public.etablissement_register(
  text, text, text, text, text, text, text, text, text, text, text,
  jsonb, jsonb, text, text, text, text, text, text, text
);

CREATE OR REPLACE FUNCTION public.etablissement_register(
  p_id text, p_nom text, p_region text, p_ville text, p_quartier text, p_type text,
  p_responsable text, p_tel text, p_email text, p_password text, p_date_inscription text,
  p_filieres_proposees jsonb, p_photos jsonb DEFAULT '[]'::jsonb,
  p_categorie text DEFAULT NULL::text, p_sous_categorie text DEFAULT NULL::text, p_secteur text DEFAULT NULL::text,
  p_tel2 text DEFAULT NULL::text, p_tel3 text DEFAULT NULL::text, p_site_web text DEFAULT NULL::text,
  p_contact_tel text DEFAULT NULL::text, p_logo_url text DEFAULT NULL::text
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

  if exists (select 1 from etablissements where lower(trim(nom)) = lower(trim(p_nom)))
     or exists (
       select 1 from demandes_inscription_etablissements
       where statut_demande = 'en_attente' and lower(trim(nom)) = lower(trim(p_nom))
     )
  then
    raise exception 'DOUBLON: Établissement déjà préinscrit, contacter le support pour récupérer vos codes de connexion. Tél : 07 87 63 34 81 - Email : gnienewoki@gmail.com';
  end if;

  if exists (select 1 from etablissements where email = p_email) then return false; end if;

  insert into demandes_inscription_etablissements(
    nom, region, ville, quartier, type, responsable, tel, tel2, tel3, email, password,
    date_inscription, filieres_proposees, photos, categorie, sous_categorie, secteur, site_web, contact_tel, logo_url
  ) values (
    p_nom, p_region, p_ville, p_quartier, p_type, p_responsable, p_tel, p_tel2, p_tel3, p_email, p_password,
    p_date_inscription, coalesce(p_filieres_proposees, '[]'::jsonb), coalesce(p_photos, '[]'::jsonb),
    p_categorie, p_sous_categorie, p_secteur, p_site_web, p_contact_tel, p_logo_url
  );
  return true;
end;
$function$;

-- 3) list_etablissements() : fonction PUBLIQUE (cf.
--    supabase-migration-2026-08-15-admin-only-contact.sql). logo_url masqué
--    exactement comme photos : CASE WHEN premium THEN logo_url ELSE NULL END.
DROP FUNCTION IF EXISTS public.list_etablissements();
CREATE OR REPLACE FUNCTION public.list_etablissements()
RETURNS TABLE(
  id text, nom text, region text, ville text, quartier text, type text,
  statut text, active boolean, date_inscription text, filieres_proposees jsonb,
  photos jsonb, logo_url text, categorie text, sous_categorie text, secteur text,
  pre_inscrit boolean, reclame boolean,
  email text, tel text, tel2 text, tel3 text, site_web text,
  premium boolean, demande_premium boolean, demande_premium_date text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT
    id, nom, region, ville, quartier, type,
    statut, active, date_inscription, filieres_proposees,
    CASE WHEN premium THEN photos ELSE '[]'::jsonb END AS photos,
    CASE WHEN premium THEN logo_url ELSE NULL END AS logo_url,
    categorie, sous_categorie, secteur, pre_inscrit, reclame,
    CASE WHEN premium THEN email ELSE NULL END AS email,
    CASE WHEN premium THEN tel ELSE NULL END AS tel,
    CASE WHEN premium THEN tel2 ELSE NULL END AS tel2,
    CASE WHEN premium THEN tel3 ELSE NULL END AS tel3,
    CASE WHEN premium THEN site_web ELSE NULL END AS site_web,
    premium,
    demande_premium, demande_premium_date
  FROM etablissements;
$function$;

-- 4) admin_list_etablissements_full(p_admin_password) : réservée à l'admin,
--    aucun masquage (cf. supabase-migration-2026-08-15-admin-only-contact.sql).
DROP FUNCTION IF EXISTS public.admin_list_etablissements_full(text);
CREATE OR REPLACE FUNCTION public.admin_list_etablissements_full(p_admin_password text)
RETURNS TABLE(
  id text, nom text, region text, ville text, quartier text, type text,
  responsable text, contact_tel text,
  email text, tel text, tel2 text, tel3 text, site_web text,
  statut text, active boolean, date_inscription text, filieres_proposees jsonb,
  photos jsonb, logo_url text, categorie text, sous_categorie text, secteur text,
  pre_inscrit boolean, reclame boolean,
  premium boolean, demande_premium boolean, demande_premium_date text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = p_admin_password) then
    raise exception 'unauthorized';
  end if;

  return query
    select
      e.id, e.nom, e.region, e.ville, e.quartier, e.type,
      e.responsable, e.contact_tel,
      e.email, e.tel, e.tel2, e.tel3, e.site_web,
      e.statut, e.active, e.date_inscription, e.filieres_proposees,
      e.photos, e.logo_url, e.categorie, e.sous_categorie, e.secteur,
      e.pre_inscrit, e.reclame,
      e.premium, e.demande_premium, e.demande_premium_date
    from etablissements e;
end; $function$;

-- 5) etablissement_get_own(p_etab_id, p_password) : self-service, aucun
--    masquage (cf. supabase-migration-2026-08-15-admin-only-contact.sql) —
--    alimente le tableau de bord établissement (etablissement.js).
DROP FUNCTION IF EXISTS public.etablissement_get_own(text, text);
CREATE OR REPLACE FUNCTION public.etablissement_get_own(p_etab_id text, p_password text)
RETURNS TABLE(
  id text, nom text, region text, ville text, quartier text, type text,
  responsable text, contact_tel text,
  email text, tel text, tel2 text, tel3 text, site_web text,
  statut text, active boolean, date_inscription text, filieres_proposees jsonb,
  photos jsonb, logo_url text, categorie text, sous_categorie text, secteur text,
  pre_inscrit boolean, reclame boolean,
  premium boolean, demande_premium boolean, demande_premium_date text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from etablissements where id = p_etab_id and password = p_password) then
    raise exception 'unauthorized';
  end if;

  return query
    select
      e.id, e.nom, e.region, e.ville, e.quartier, e.type,
      e.responsable, e.contact_tel,
      e.email, e.tel, e.tel2, e.tel3, e.site_web,
      e.statut, e.active, e.date_inscription, e.filieres_proposees,
      e.photos, e.logo_url, e.categorie, e.sous_categorie, e.secteur,
      e.pre_inscrit, e.reclame,
      e.premium, e.demande_premium, e.demande_premium_date
    from etablissements e
    where e.id = p_etab_id;
end; $function$;

-- 6) admin_list_demandes_inscription_etablissements(p_admin_password) :
--    ajoute logo_url en sortie, en parallèle de photos (cf.
--    supabase-migration-2026-08-16-demandes-inscription-3-admin-rpcs.sql) —
--    l'admin doit voir le logo soumis au moment d'examiner la demande.
DROP FUNCTION IF EXISTS public.admin_list_demandes_inscription_etablissements(text);
CREATE OR REPLACE FUNCTION public.admin_list_demandes_inscription_etablissements(p_admin_password text)
RETURNS TABLE(
  id text, nom text, region text, ville text, quartier text, type text,
  responsable text, tel text, tel2 text, tel3 text, email text, site_web text, contact_tel text,
  date_inscription text, filieres_proposees jsonb, photos jsonb, logo_url text,
  categorie text, sous_categorie text, secteur text,
  date_demande text, statut_demande text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where admin_config.id = 1 and admin_config.admin_password = p_admin_password) then
    raise exception 'unauthorized';
  end if;

  return query
    select
      d.id::text, d.nom, d.region, d.ville, d.quartier, d.type,
      d.responsable, d.tel, d.tel2, d.tel3, d.email, d.site_web, d.contact_tel,
      d.date_inscription, d.filieres_proposees, d.photos, d.logo_url,
      d.categorie, d.sous_categorie, d.secteur,
      d.date_demande, d.statut_demande
    from demandes_inscription_etablissements d
    where d.statut_demande = 'en_attente'
    order by d.date_demande asc;
end; $function$;

-- 7) etablissement_update_logo(p_etab_id, p_password, p_logo_url) : nouvelle
--    fonction, sur le modèle EXACT de etablissement_update_contact_extras
--    (cf. supabase-migration-2026-08-15-etab-dashboard-contact-fields.sql) —
--    même vérification id+password, même normalisation '' -> NULL. Permet à
--    l'espace établissement d'ajouter/modifier/retirer son logo après
--    inscription (fonctionne aussi pour un compte importé en masse et
--    réclamé, dont logo_url est vide au départ).
CREATE OR REPLACE FUNCTION public.etablissement_update_logo(p_etab_id text, p_password text, p_logo_url text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from etablissements where id = p_etab_id and password = p_password) then
    return false;
  end if;
  update etablissements
    set logo_url = nullif(trim(coalesce(p_logo_url,'')),'')
    where id = p_etab_id;
  return true;
end; $function$;
