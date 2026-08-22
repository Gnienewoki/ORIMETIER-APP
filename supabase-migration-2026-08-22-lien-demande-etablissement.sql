-- À exécuter dans le SQL Editor de Supabase (production), après
-- supabase-migration-2026-08-22-logo-etablissement.sql.
-- ============================================================
-- Corrige une perte de données du circuit d'approbation admin : le format
-- texte "nom;region;ville;quartier;secteur;responsable;tel" (7 champs) copié
-- depuis une demande d'inscription vers l'import en masse
-- (admin_bulk_import_etablissements) ne transporte ni photos ni logo_url —
-- ces fichiers, pourtant déjà uploadés par l'établissement à l'inscription
-- directe, restent orphelins dans demandes_inscription_etablissements
-- (jamais recopiés vers etablissements, aucun lien technique entre les deux
-- lignes, cf. diagnostic du 2026-08-22).
--
-- admin_lier_photos_logo_demande() ferme cette boucle manuellement : une fois
-- l'import fait (id de l'établissement connu), l'admin recopie photos/logo_url
-- de la demande vers cet établissement, et la demande est marquée traitée —
-- même mécanisme que admin_marquer_demande_traitee (colonne statut_demande,
-- valeur 'traite', cf. supabase-migration-2026-08-16-demandes-inscription-3-admin-rpcs.sql).
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_lier_photos_logo_demande(p_admin_password text, p_demande_id text, p_etablissement_id text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_photos jsonb;
  v_logo_url text;
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = p_admin_password) then
    return false;
  end if;

  select photos, logo_url into v_photos, v_logo_url
    from demandes_inscription_etablissements
    where id = p_demande_id::uuid and statut_demande = 'en_attente';
  if not found then
    return false;
  end if;

  update etablissements
    set photos = coalesce(v_photos, '[]'::jsonb),
        logo_url = v_logo_url
    where id = p_etablissement_id;
  if not found then
    return false;
  end if;

  update demandes_inscription_etablissements
    set statut_demande = 'traite'
    where id = p_demande_id::uuid;

  return true;
end;
$function$;
