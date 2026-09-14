-- ============================================================
-- ORIMETIER — Fix : "column reference "id" is ambiguous" sur 3 fonctions
-- du suivi d'élèves (inspecteur_suivi_list_eleves, inspecteur_suivi_get_eleve,
-- inspecteur_suivi_list_notes).
--
-- Cause : ces 3 fonctions déclarent RETURNS TABLE(id text, ...). En
-- PL/pgSQL, chaque colonne de ce RETURNS TABLE devient une variable de
-- sortie (OUT) déclarée pour toute la durée de la fonction — pas
-- seulement pour le "return query" final. La vérification d'authentification
-- ("where id = p_inspecteur_id", sur la table inspecteurs) et, pour
-- inspecteur_suivi_get_eleve/list_notes, la vérification d'appartenance de
-- la fiche ("where id = p_suivi_id::uuid", sur suivi_eleves) référencent
-- alors un "id" nu qui devient ambigu entre la colonne de la table et
-- cette variable de sortie.
--
-- Même bug déjà rencontré et documenté sur admin_list_demandes_inscription_
-- etablissements et admin_list_unclaimed_codes (cf. supabase-migration-
-- 2026-08-16-demandes-inscription-3-admin-rpcs.sql) : fix identique,
-- qualifier explicitement chaque colonne avec l'alias de sa table.
--
-- Signatures et colonnes de retour inchangées -> aucun ajustement
-- frontend nécessaire (les DROP ci-dessous sont uniquement par prudence/
-- habitude, le CREATE OR REPLACE seul aurait suffi ici puisque rien ne
-- change dans la signature).
--
-- À exécuter en une fois dans l'éditeur SQL de Supabase.
-- ============================================================

DROP FUNCTION IF EXISTS public.inspecteur_suivi_list_eleves(text, text);
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
    where inspecteurs.id = p_inspecteur_id and inspecteurs.password = p_password and coalesce(inspecteurs.banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  return query
    select s.id::text, s.nom, s.prenoms, s.classe, s.raisons, s.appreciation_finale, s.date_ajout
    from suivi_eleves s
    where s.inspecteur_id = p_inspecteur_id
    order by s.nom asc, s.prenoms asc;
end; $function$;

DROP FUNCTION IF EXISTS public.inspecteur_suivi_get_eleve(text, text, text);
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
    where inspecteurs.id = p_inspecteur_id and inspecteurs.password = p_password and coalesce(inspecteurs.banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  return query
    select s.id::text, s.nom, s.prenoms, s.classe, s.raisons, s.appreciation_finale, s.date_ajout
    from suivi_eleves s
    where s.id = p_suivi_id::uuid and s.inspecteur_id = p_inspecteur_id;
end; $function$;

DROP FUNCTION IF EXISTS public.inspecteur_suivi_list_notes(text, text, text);
CREATE OR REPLACE FUNCTION public.inspecteur_suivi_list_notes(p_inspecteur_id text, p_password text, p_suivi_id text)
RETURNS TABLE(id text, date_note text, texte text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if not exists (
    select 1 from inspecteurs
    where inspecteurs.id = p_inspecteur_id and inspecteurs.password = p_password and coalesce(inspecteurs.banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  if not exists (
    select 1 from suivi_eleves
    where suivi_eleves.id = p_suivi_id::uuid and suivi_eleves.inspecteur_id = p_inspecteur_id
  ) then
    raise exception 'unauthorized';
  end if;

  return query
    select n.id::text, n.date_note, n.texte
    from suivi_eleves_notes n
    where n.suivi_eleve_id = p_suivi_id::uuid
    order by to_date(n.date_note, 'DD/MM/YYYY') asc, n.created_at asc;
end; $function$;
