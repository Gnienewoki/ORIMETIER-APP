-- À exécuter dans le SQL Editor de Supabase (production), EN TROISIÈME
-- (3 sur 3), après supabase-migration-2026-08-16-demandes-inscription-2-register-et-verif.sql.
-- ============================================================
-- Deux nouvelles fonctions admin pour la section "Demandes d'inscription en
-- attente" (admin.js). Même vérification d'authentification que les autres
-- fonctions admin_* (admin_config.id = 1). password n'est jamais renvoyé
-- (même convention que list_eleves/list_inspecteurs/admin_list_etablissements_full)
-- — inutile de toute façon : l'admin fait l'import via
-- admin_bulk_import_etablissements (nom;region;ville;quartier;secteur;
-- responsable;tel), et l'établissement choisira son propre e-mail/mot de
-- passe au moment de réclamer son compte (etablissement_claim_by_code).
-- ============================================================

-- admin_list_demandes_inscription_etablissements : RETURNS TABLE(id text, ...)
-- déclare "id" comme paramètre de sortie (variable plpgsql) dans tout le
-- corps de la fonction. La vérification admin "where id = 1" (non qualifiée)
-- devient donc ambiguë entre admin_config.id et ce OUT param, dès l'exécution
-- (ERROR: column reference "id" is ambiguous) — même bug déjà documenté sur
-- admin_list_unclaimed_codes (cf. supabase-migration-2026-08-12-codes-etablissements.sql).
-- Fix : qualifier explicitement admin_config.id (le SELECT plus bas était
-- déjà correctement qualifié via l'alias "d."). Colonne de sortie "id"
-- inchangée -> aucun ajustement frontend nécessaire.
CREATE OR REPLACE FUNCTION public.admin_list_demandes_inscription_etablissements(p_admin_password text)
RETURNS TABLE(
  id text, nom text, region text, ville text, quartier text, type text,
  responsable text, tel text, tel2 text, tel3 text, email text, site_web text, contact_tel text,
  date_inscription text, filieres_proposees jsonb, photos jsonb,
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
      d.date_inscription, d.filieres_proposees, d.photos,
      d.categorie, d.sous_categorie, d.secteur,
      d.date_demande, d.statut_demande
    from demandes_inscription_etablissements d
    where d.statut_demande = 'en_attente'
    order by d.date_demande asc;
end; $function$;

CREATE OR REPLACE FUNCTION public.admin_marquer_demande_traitee(p_admin_password text, p_demande_id text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = p_admin_password) then return false; end if;
  update demandes_inscription_etablissements
    set statut_demande = 'traite'
    where id = p_demande_id::uuid and statut_demande = 'en_attente';
  return found;
end; $function$;
