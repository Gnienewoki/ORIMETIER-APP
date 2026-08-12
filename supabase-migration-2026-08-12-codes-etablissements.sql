-- ============================================================
-- ORIMETIER — Migration du 2026-08-12
-- Nouvelle fonction admin_list_all_etablissement_codes : liste
-- permanente de TOUS les établissements pré-inscrits avec leur code
-- de récupération (réclamé ou non), pour l'export CSV/Excel depuis
-- l'espace admin ("📋 Codes établissements").
--
-- Écrite volontairement simple pour éviter le bug d'ambiguïté de
-- colonne qui touche admin_list_unclaimed_codes (traité séparément) :
-- une seule table (pas de jointure), et chaque colonne est qualifiée
-- par l'alias "e." dans le SELECT. Sans cet alias, PostgreSQL peut
-- confondre une colonne de la table avec le paramètre de sortie du
-- même nom déclaré dans RETURNS TABLE(...) (ex: "nom", "ville",
-- "secteur" sont à la fois des colonnes de etablissements ET des OUT
-- params de cette fonction).
--
-- À exécuter en une fois dans l'éditeur SQL de Supabase.
-- ============================================================

DROP FUNCTION IF EXISTS public.admin_list_all_etablissement_codes(text);
CREATE OR REPLACE FUNCTION public.admin_list_all_etablissement_codes(p_admin_password text)
 RETURNS TABLE(nom text, categorie text, sous_categorie text, ville text, secteur text, code_recuperation text, reclame boolean, date_inscription text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = p_admin_password) then
    raise exception 'Mot de passe administrateur invalide';
  end if;

  return query
    select e.nom, e.categorie, e.sous_categorie, e.ville, e.secteur, e.code_recuperation, e.reclame, e.date_inscription
    from etablissements e
    where e.pre_inscrit = true and e.code_recuperation is not null
    order by e.nom;
end;
$function$;
