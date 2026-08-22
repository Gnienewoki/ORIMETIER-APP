-- Cette migration DOCUMENTE une correction déjà exécutée manuellement en
-- production (SQL Editor Supabase) par l'utilisateur — elle n'a jamais été
-- committée dans le repo jusqu'ici. Aucune action supplémentaire requise :
-- la production a déjà ces définitions. Ce fichier sert uniquement à
-- versionner l'historique (ré-exécuter est sans risque, ces CREATE OR
-- REPLACE sont idempotents et identiques à l'état actuel de la prod).
-- ============================================================
-- Bug : admin_list_etablissements_full et etablissement_get_own déclarent
-- toutes deux "id" comme paramètre de sortie (RETURNS TABLE(id text, ...)),
-- utilisé comme variable PL/pgSQL dans tout le corps de la fonction. La
-- vérification d'accès ("if not exists (select 1 from ... where id = ...)")
-- référence alors un "id" ambigu entre la colonne de la table interrogée
-- (admin_config.id / etablissements.id) et ce paramètre de sortie, ce qui
-- lève "ERROR: column reference "id" is ambiguous" à l'exécution — même
-- piège déjà rencontré et documenté sur ce projet pour
-- admin_list_unclaimed_codes (supabase-migration-2026-08-12-codes-etablissements.sql)
-- et admin_list_demandes_inscription_etablissements
-- (supabase-migration-2026-08-16-demandes-inscription-3-admin-rpcs.sql).
--
-- Fix : qualifier explicitement la table dans la clause de vérification
-- (alias ac. pour admin_config, et. pour etablissements). Le reste du corps
-- (return query, déjà qualifié via l'alias e.) est inchangé — seule la
-- clause de garde était ambiguë. Signature et type de retour inchangés (déjà
-- mis à jour avec logo_url par supabase-migration-2026-08-22-logo-etablissement.sql)
-- -> CREATE OR REPLACE suffit, pas de DROP requis.
-- ============================================================

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
  if not exists (select 1 from admin_config ac where ac.id = 1 and ac.admin_password = p_admin_password) then
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
  if not exists (select 1 from etablissements et where et.id = p_etab_id and et.password = p_password) then
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
