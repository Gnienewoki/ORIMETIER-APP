-- ============================================================
-- ORIMETIER — Migration du 2026-08-11
-- admin_bulk_import_etablissements : la fonction ignorait
-- silencieusement 3 catégories de lignes invalides (secteur non
-- reconnu, secteur "public" pour superieur/technique, nom/ville
-- manquant) sans jamais le signaler à l'appelant. Un import où
-- TOUTES les lignes tombaient dans un de ces cas affichait "0
-- établissement(s) importé(s)" sans explication — perçu comme un
-- échec silencieux côté admin. On ajoute 2 colonnes de retour
-- (resultat, raison) pour que chaque ligne soumise soit tracée,
-- importée ou non. Le reste de la logique (v_seq pour l'unicité
-- des ID, génération du code de récupération) est inchangé.
-- ============================================================
DROP FUNCTION IF EXISTS public.admin_bulk_import_etablissements(text, text, text, jsonb);
CREATE OR REPLACE FUNCTION public.admin_bulk_import_etablissements(p_admin_password text, p_categorie text, p_sous_categorie text, p_items jsonb)
 RETURNS TABLE(nom text, ville text, secteur text, code_recuperation text, resultat text, raison text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_item jsonb;
  v_id text;
  v_code text;
  v_secteur text;
  v_sous_categorie text;
  v_type text;
  v_seq bigint := 0;
  v_raison text;
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = p_admin_password) then
    raise exception 'Mot de passe administrateur invalide';
  end if;
  if coalesce(p_categorie, '') not in ('general', 'superieur', 'technique') then
    raise exception 'Catégorie non prise en charge par l''import en masse : %', p_categorie;
  end if;
  if p_categorie = 'superieur' and coalesce(p_sous_categorie, '') not in ('universite', 'grande_ecole') then
    raise exception 'Sous-catégorie obligatoire pour le Supérieur : universite ou grande_ecole';
  end if;

  v_sous_categorie := case when p_categorie = 'superieur' then p_sous_categorie else 'secondaire' end;
  v_type := case
    when p_categorie = 'superieur' then 'Supérieure'
    when p_categorie = 'technique' then 'Secondaire formation professionnelle et technique'
    else 'Secondaire générale'
  end;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_seq := v_seq + 1;
    v_secteur := v_item->>'secteur';
    v_raison := null;

    if coalesce(v_secteur, '') not in ('public','prive') then
      v_raison := 'Secteur invalide (attendu "public" ou "prive", reçu : ' || coalesce(nullif(v_secteur, ''), '(vide)') || ')';
    elsif p_categorie in ('superieur', 'technique') and v_secteur = 'public' then
      v_raison := 'Secteur "public" non pris en charge pour la catégorie "' || p_categorie || '" (aucun onglet basé sur un compte établissement)';
    elsif coalesce(trim(v_item->>'nom'), '') = '' or coalesce(trim(v_item->>'ville'), '') = '' then
      v_raison := 'Nom ou ville manquant';
    end if;

    if v_raison is not null then
      nom := coalesce(trim(v_item->>'nom'), '');
      ville := coalesce(trim(v_item->>'ville'), '');
      secteur := v_secteur;
      code_recuperation := null;
      resultat := 'ignore';
      raison := v_raison;
      return next;
      continue;
    end if;

    -- v_seq garantit l'unicité de l'id au sein de cet appel, même si plusieurs
    -- itérations tombent sur la même seconde/le même tirage aléatoire.
    v_id := 'id' || extract(epoch from clock_timestamp())::bigint::text || v_seq::text || floor(random()*1000000)::text;
    v_code := array_to_string(
      array(
        select substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', (floor(random()*32)+1)::int, 1)
        from generate_series(1,8)
      ), ''
    );

    insert into etablissements(
      id, nom, region, ville, quartier, type, responsable, tel, email, password,
      statut, active, date_inscription, filieres_proposees, photos,
      categorie, sous_categorie, secteur, pre_inscrit, reclame, code_recuperation
    ) values (
      v_id, trim(v_item->>'nom'), nullif(trim(v_item->>'region'),''), trim(v_item->>'ville'), nullif(trim(v_item->>'quartier'),''),
      v_type, nullif(trim(v_item->>'responsable'),''), nullif(trim(v_item->>'tel'),''), null, null,
      'valide', true, to_char(now(),'DD/MM/YYYY'), '[]'::jsonb, '[]'::jsonb,
      p_categorie, v_sous_categorie, v_secteur, true, false, v_code
    );

    nom := trim(v_item->>'nom');
    ville := trim(v_item->>'ville');
    secteur := v_secteur;
    code_recuperation := v_code;
    resultat := 'importe';
    raison := null;
    return next;
  end loop;
end;
$function$;

-- ============================================================
-- 2) Nettoyage des surcharges (overloads) obsolètes
-- Identifiées via l'audit de pg_proc (_db_audit.txt) : ces anciennes
-- signatures sans les paramètres ajoutés depuis restent joignables par
-- PostgreSQL (résolution de surcharge par arité) alors que le code
-- appelant actuel n'utilise plus que la version complète. On les
-- supprime pour éviter tout appel accidentel à une version qui écrit
-- des lignes sans categorie/sous_categorie/secteur/photos (établissements)
-- ou sans type/reply_to/pièce jointe (messages inspecteurs).
-- ============================================================

-- etablissement_register : surcharge sans p_photos/p_categorie/p_sous_categorie/p_secteur
DROP FUNCTION IF EXISTS public.etablissement_register(
  p_id text, p_nom text, p_region text, p_ville text, p_quartier text,
  p_type text, p_responsable text, p_tel text, p_email text, p_password text,
  p_date_inscription text, p_filieres_proposees jsonb
);

-- inspecteur_post_message : surcharge sans p_type/p_reply_to/p_attachment_*
DROP FUNCTION IF EXISTS public.inspecteur_post_message(
  p_inspecteur_id text, p_password text, p_texte text
);
