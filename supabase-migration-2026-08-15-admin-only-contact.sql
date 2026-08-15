-- À exécuter dans le SQL Editor de Supabase (production).
-- ============================================================
-- Découpage définitif :
--   PUBLIC (masqué tant que premium=false) : email, site_web, tel, tel2, tel3
--   ADMIN UNIQUEMENT (jamais public, même en premium) : responsable, contact_tel
--     (contact_tel = téléphone du responsable, pas un champ de contact public)
--   INUTILISÉ : contact_email — laissé tel quel en base, jamais exposé par
--     aucune des fonctions ci-dessous (ni publique, ni admin, ni self-service).
-- ============================================================

-- 1) Deux numéros de contact public supplémentaires (compagnons de tel).
ALTER TABLE public.etablissements ADD COLUMN IF NOT EXISTS tel2 text;
ALTER TABLE public.etablissements ADD COLUMN IF NOT EXISTS tel3 text;

-- 2) list_etablissements() : fonction PUBLIQUE. Masque email/site_web/tel/tel2/tel3
--    tant que premium=false. Ne renvoie JAMAIS responsable ni contact_tel (absents
--    du SELECT, quel que soit le statut premium). DROP nécessaire : le type de
--    retour change (colonnes retirées + tel2/tel3 ajoutées).
DROP FUNCTION IF EXISTS public.list_etablissements();
CREATE OR REPLACE FUNCTION public.list_etablissements()
RETURNS TABLE(
  id text, nom text, region text, ville text, quartier text, type text,
  statut text, active boolean, date_inscription text, filieres_proposees jsonb,
  photos jsonb, categorie text, sous_categorie text, secteur text,
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

-- 3) admin_list_etablissements_full(p_admin_password) : réservée à l'admin.
--    Renvoie tout sans masquage, y compris responsable et contact_tel (jamais
--    exposés ailleurs). contact_email reste exclu (inutilisé). Vérification
--    identique à admin_valider_premium (admin_config.id = 1). RAISE EXCEPTION
--    plutôt qu'un tableau vide, pour distinguer côté frontend un échec
--    d'authentification d'un résultat vide légitime.
CREATE OR REPLACE FUNCTION public.admin_list_etablissements_full(p_admin_password text)
RETURNS TABLE(
  id text, nom text, region text, ville text, quartier text, type text,
  responsable text, contact_tel text,
  email text, tel text, tel2 text, tel3 text, site_web text,
  statut text, active boolean, date_inscription text, filieres_proposees jsonb,
  photos jsonb, categorie text, sous_categorie text, secteur text,
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
      e.photos, e.categorie, e.sous_categorie, e.secteur,
      e.pre_inscrit, e.reclame,
      e.premium, e.demande_premium, e.demande_premium_date
    from etablissements e;
end; $function$;

-- 4) etablissement_get_own(p_etab_id, p_password) : self-service, utilisée par
--    le tableau de bord établissement pour voir/modifier sa propre fiche
--    (responsable, contact_tel, email, tel, tel2, tel3, site_web) sans masquage —
--    c'est son propre compte. contact_email reste exclu (inutilisé). Ne renvoie
--    la ligne qu'à l'établissement authentifié pour lui-même.
CREATE OR REPLACE FUNCTION public.etablissement_get_own(p_etab_id text, p_password text)
RETURNS TABLE(
  id text, nom text, region text, ville text, quartier text, type text,
  responsable text, contact_tel text,
  email text, tel text, tel2 text, tel3 text, site_web text,
  statut text, active boolean, date_inscription text, filieres_proposees jsonb,
  photos jsonb, categorie text, sous_categorie text, secteur text,
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
      e.photos, e.categorie, e.sous_categorie, e.secteur,
      e.pre_inscrit, e.reclame,
      e.premium, e.demande_premium, e.demande_premium_date
    from etablissements e
    where e.id = p_etab_id;
end; $function$;
