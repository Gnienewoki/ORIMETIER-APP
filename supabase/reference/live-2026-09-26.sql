-- =====================================================================
-- Référence du code LIVE au 26/09/2026 (base Supabase de production).
-- Source de vérité pour toute réécriture de fonction.
-- NE PAS EXÉCUTER TEL QUEL.
-- Contenu : 77 fonctions du schéma public, 5 triggers.
-- =====================================================================

-- ---------------------------------------------------------------------
-- FONCTIONS
-- ---------------------------------------------------------------------

-- admin_bulk_import_etablissements(p_admin_password text, p_categorie text, p_sous_categorie text, p_items jsonb)
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
  if not exists (select 1 from admin_config where id = 1 and admin_password = extensions.crypt(p_admin_password, admin_password)) then
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

-- admin_delete_etablissement(p_admin_password text, p_etab_id text)
CREATE OR REPLACE FUNCTION public.admin_delete_etablissement(p_admin_password text, p_etab_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if not admin_login(p_admin_password) then
    return false;
  end if;
  delete from etablissements where id = p_etab_id;
  return true;
end;
$function$;

-- admin_delete_lien_formation(p_admin_password text, p_id bigint)
CREATE OR REPLACE FUNCTION public.admin_delete_lien_formation(p_admin_password text, p_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = extensions.crypt(p_admin_password, admin_password)) then return false; end if;
  delete from liens_formation where id = p_id;
  return found;
end; $function$;

-- admin_delete_message(p_admin_password text, p_message_id text)
CREATE OR REPLACE FUNCTION public.admin_delete_message(p_admin_password text, p_message_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = extensions.crypt(p_admin_password, admin_password)) then return false; end if;
  delete from messages_inspecteurs where id = p_message_id;
  return found;
end; $function$;

-- admin_get_visite_stats(p_admin_password text)
CREATE OR REPLACE FUNCTION public.admin_get_visite_stats(p_admin_password text)
 RETURNS TABLE(page text, jour date, visites bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where admin_config.id = 1 and admin_config.admin_password = extensions.crypt(p_admin_password, admin_config.admin_password)) then
    raise exception 'unauthorized';
  end if;

  return query
    select v.page, v.visited_at::date as jour, count(*)::bigint as visites
    from visites v
    group by v.page, v.visited_at::date
    order by jour desc, v.page asc;
end; $function$;

-- admin_lier_photos_logo_demande(p_admin_password text, p_demande_id text, p_etablissement_id text)
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
  if not exists (select 1 from admin_config where id = 1 and admin_password = extensions.crypt(p_admin_password, admin_password)) then
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

-- admin_list_all_etablissement_codes(p_admin_password text)
CREATE OR REPLACE FUNCTION public.admin_list_all_etablissement_codes(p_admin_password text)
 RETURNS TABLE(nom text, categorie text, sous_categorie text, ville text, secteur text, code_recuperation text, reclame boolean, date_inscription text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = extensions.crypt(p_admin_password, admin_password)) then
    raise exception 'Mot de passe administrateur invalide';
  end if;

  return query
    select e.nom, e.categorie, e.sous_categorie, e.ville, e.secteur, e.code_recuperation, e.reclame, e.date_inscription
    from etablissements e
    where e.pre_inscrit = true and e.code_recuperation is not null
    order by e.nom;
end;
$function$;

-- admin_list_demandes_inscription_etablissements(p_admin_password text)
CREATE OR REPLACE FUNCTION public.admin_list_demandes_inscription_etablissements(p_admin_password text)
 RETURNS TABLE(id text, nom text, region text, ville text, quartier text, type text, responsable text, tel text, tel2 text, tel3 text, email text, site_web text, contact_tel text, date_inscription text, filieres_proposees jsonb, photos jsonb, logo_url text, categorie text, sous_categorie text, secteur text, date_demande text, statut_demande text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where admin_config.id = 1 and admin_config.admin_password = extensions.crypt(p_admin_password, admin_config.admin_password)) then
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

-- admin_list_etablissements_full(p_admin_password text)
CREATE OR REPLACE FUNCTION public.admin_list_etablissements_full(p_admin_password text)
 RETURNS TABLE(id text, nom text, region text, ville text, quartier text, type text, responsable text, contact_tel text, email text, tel text, tel2 text, tel3 text, site_web text, statut text, active boolean, date_inscription text, filieres_proposees jsonb, photos jsonb, logo_url text, categorie text, sous_categorie text, secteur text, pre_inscrit boolean, reclame boolean, premium boolean, demande_premium boolean, demande_premium_date text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config ac where ac.id = 1 and ac.admin_password = extensions.crypt(p_admin_password, ac.admin_password)) then
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

-- admin_list_unclaimed_codes(p_admin_password text)
CREATE OR REPLACE FUNCTION public.admin_list_unclaimed_codes(p_admin_password text)
 RETURNS TABLE(id text, nom text, region text, ville text, quartier text, categorie text, sous_categorie text, secteur text, code_recuperation text, date_inscription text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config ac where ac.id = 1 and ac.admin_password = extensions.crypt(p_admin_password, ac.admin_password)) then
    raise exception 'Mot de passe administrateur invalide';
  end if;
  return query
    select e.id, e.nom, e.region, e.ville, e.quartier, e.categorie, e.sous_categorie, e.secteur, e.code_recuperation, e.date_inscription
    from etablissements e
    where e.pre_inscrit = true and e.reclame = false
    order by e.categorie, e.secteur, e.region, e.nom;
end;
$function$;

-- admin_login(p_password text)
CREATE OR REPLACE FUNCTION public.admin_login(p_password text)
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists(select 1 from admin_config where id = 1 and admin_password = extensions.crypt(p_password, admin_password));
$function$;

-- admin_marquer_demande_traitee(p_admin_password text, p_demande_id text)
CREATE OR REPLACE FUNCTION public.admin_marquer_demande_traitee(p_admin_password text, p_demande_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = extensions.crypt(p_admin_password, admin_password)) then return false; end if;
  update demandes_inscription_etablissements
    set statut_demande = 'traite'
    where id = p_demande_id::uuid and statut_demande = 'en_attente';
  return found;
end; $function$;

-- admin_post_message(p_admin_password text, p_texte text, p_type text, p_reply_to text, p_attachment_url text, p_attachment_type text, p_attachment_name text)
CREATE OR REPLACE FUNCTION public.admin_post_message(p_admin_password text, p_texte text, p_type text DEFAULT 'O'::text, p_reply_to text DEFAULT NULL::text, p_attachment_url text DEFAULT NULL::text, p_attachment_type text DEFAULT NULL::text, p_attachment_name text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = extensions.crypt(p_admin_password, admin_password)) then return false; end if;
  if p_type not in ('O','C') then return false; end if;
  if p_attachment_type is not null and p_attachment_type not in ('image','pdf') then return false; end if;
  if length(trim(coalesce(p_texte,''))) = 0 and p_attachment_url is null then return false; end if;

  insert into messages_inspecteurs(id, inspecteur_id, inspecteur_nom, texte, date, type, auteur_role, reply_to, attachment_url, attachment_type, attachment_name)
    values ('id' || extract(epoch from clock_timestamp())::bigint::text || floor(random()*1000000)::text,
            null, 'Administration ORIMETIER', p_texte, to_char(now(),'DD/MM/YYYY HH24:MI'), p_type, 'admin', p_reply_to, p_attachment_url, p_attachment_type, p_attachment_name);
  return true;
end; $function$;

-- admin_restore_backup(p_admin_password text, p_payload jsonb)
CREATE OR REPLACE FUNCTION public.admin_restore_backup(p_admin_password text, p_payload jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists(select 1 from admin_config where id = 1 and admin_password = extensions.crypt(p_admin_password, admin_password)) then return false; end if;
  delete from eleves; delete from inspecteurs; delete from etablissements; delete from notes;
  insert into eleves select * from jsonb_populate_recordset(null::eleves, coalesce(p_payload->'eleves', '[]'::jsonb));
  insert into inspecteurs select * from jsonb_populate_recordset(null::inspecteurs, coalesce(p_payload->'inspecteurs', '[]'::jsonb));
  insert into etablissements select * from jsonb_populate_recordset(null::etablissements, coalesce(p_payload->'etablissements', '[]'::jsonb));
  insert into notes select * from jsonb_populate_recordset(null::notes, coalesce(p_payload->'notes', '[]'::jsonb));
  return true;
end; $function$;

-- admin_set_annonce_active(p_admin_password text, p_id integer, p_active boolean)
CREATE OR REPLACE FUNCTION public.admin_set_annonce_active(p_admin_password text, p_id integer, p_active boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = extensions.crypt(p_admin_password, admin_password)) then return false; end if;

  if p_active then
    if (select count(*) from annonce where active = true and id <> p_id) >= 5 then
      return false;
    end if;
  end if;

  update annonce set active = p_active, updated_at = now() where id = p_id;
  return found;
end; $function$;

-- admin_set_eleve_banni(p_admin_password text, p_eleve_id text, p_banni boolean)
CREATE OR REPLACE FUNCTION public.admin_set_eleve_banni(p_admin_password text, p_eleve_id text, p_banni boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = extensions.crypt(p_admin_password, admin_password)) then return false; end if;
  update eleves set banni = p_banni where id = p_eleve_id;
  return found;
end; $function$;

-- admin_set_etab_premium(p_admin_password text, p_etab_id text, p_premium boolean)
CREATE OR REPLACE FUNCTION public.admin_set_etab_premium(p_admin_password text, p_etab_id text, p_premium boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = extensions.crypt(p_admin_password, admin_password)) then return false; end if;
  update etablissements set premium = p_premium where id = p_etab_id;
  return found;
end; $function$;

-- admin_set_etab_statut(p_admin_password text, p_etab_id text, p_statut text)
CREATE OR REPLACE FUNCTION public.admin_set_etab_statut(p_admin_password text, p_etab_id text, p_statut text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists(select 1 from admin_config where id = 1 and admin_password = extensions.crypt(p_admin_password, admin_password)) then return false; end if;
  update etablissements set statut = p_statut where id = p_etab_id;
  return found;
end; $function$;

-- admin_set_filiere_statut(p_admin_password text, p_etab_id text, p_filiere_id text, p_statut text)
CREATE OR REPLACE FUNCTION public.admin_set_filiere_statut(p_admin_password text, p_etab_id text, p_filiere_id text, p_statut text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_filieres jsonb; v_updated jsonb;
begin
  if not exists(select 1 from admin_config where id = 1 and admin_password = extensions.crypt(p_admin_password, admin_password)) then return false; end if;
  select filieres_proposees into v_filieres from etablissements where id = p_etab_id;
  select jsonb_agg(
    case when elem->>'id' = p_filiere_id then elem || jsonb_build_object('statut', p_statut) else elem end
  ) into v_updated from jsonb_array_elements(coalesce(v_filieres, '[]'::jsonb)) elem;
  update etablissements set filieres_proposees = coalesce(v_updated, '[]'::jsonb) where id = p_etab_id;
  return true;
end; $function$;

-- admin_set_inspecteur_banni(p_admin_password text, p_inspecteur_id text, p_banni boolean)
CREATE OR REPLACE FUNCTION public.admin_set_inspecteur_banni(p_admin_password text, p_inspecteur_id text, p_banni boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = extensions.crypt(p_admin_password, admin_password)) then return false; end if;
  update inspecteurs set banni = p_banni where id = p_inspecteur_id;
  return found;
end; $function$;

-- admin_set_inspecteur_certifie(p_admin_password text, p_inspecteur_id text, p_certifie boolean)
CREATE OR REPLACE FUNCTION public.admin_set_inspecteur_certifie(p_admin_password text, p_inspecteur_id text, p_certifie boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = extensions.crypt(p_admin_password, admin_password)) then return false; end if;
  update inspecteurs set certifie = p_certifie,
    certification_demandee = case when p_certifie then false else certification_demandee end
  where id = p_inspecteur_id;
  return found;
end; $function$;

-- admin_supprimer_annonce(p_admin_password text, p_id integer)
CREATE OR REPLACE FUNCTION public.admin_supprimer_annonce(p_admin_password text, p_id integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = extensions.crypt(p_admin_password, admin_password)) then return false; end if;
  delete from annonce where id = p_id and active = false;
  return found;
end; $function$;

-- admin_update_etab_classification(p_admin_password text, p_etab_id text, p_categorie text, p_sous_categorie text, p_secteur text)
CREATE OR REPLACE FUNCTION public.admin_update_etab_classification(p_admin_password text, p_etab_id text, p_categorie text, p_sous_categorie text, p_secteur text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if not admin_login(p_admin_password) then
    return false;
  end if;
  update etablissements
    set categorie = p_categorie, sous_categorie = p_sous_categorie, secteur = p_secteur
    where id = p_etab_id;
  return true;
end;
$function$;

-- admin_upsert_annonce(p_admin_password text, p_id integer, p_type text, p_texte text, p_image_url text)
CREATE OR REPLACE FUNCTION public.admin_upsert_annonce(p_admin_password text, p_id integer, p_type text, p_texte text, p_image_url text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id int;
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = extensions.crypt(p_admin_password, admin_password)) then return null; end if;
  if p_type not in ('texte','image') then return null; end if;
  if p_type = 'texte' and length(trim(coalesce(p_texte,''))) = 0 then return null; end if;
  if p_type = 'image' and length(trim(coalesce(p_image_url,''))) = 0 then return null; end if;

  if p_id is null then
    if (select count(*) from annonce where active = true) >= 5 then
      return null;
    end if;
    insert into annonce(type, texte, image_url, active, created_at, updated_at)
      values (p_type, p_texte, p_image_url, true, now(), now())
      returning id into v_id;
  else
    update annonce set type = p_type, texte = p_texte, image_url = p_image_url, updated_at = now()
      where id = p_id
      returning id into v_id;
  end if;
  return v_id;
end; $function$;

-- admin_upsert_lien_formation(p_admin_password text, p_id bigint, p_titre text, p_description text, p_url text, p_audience text, p_ordre integer)
CREATE OR REPLACE FUNCTION public.admin_upsert_lien_formation(p_admin_password text, p_id bigint, p_titre text, p_description text, p_url text, p_audience text, p_ordre integer DEFAULT NULL::integer)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id bigint;
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = extensions.crypt(p_admin_password, admin_password)) then return null; end if;
  if p_audience not in ('inspecteur','eleve','etudiant','tous') then return null; end if;
  if length(trim(coalesce(p_titre,''))) = 0 or length(trim(coalesce(p_url,''))) = 0 then return null; end if;
  if p_id is null then
    insert into liens_formation(titre, description, url, audience, ordre)
      values (p_titre, p_description, p_url, p_audience, p_ordre)
      returning id into v_id;
  else
    update liens_formation
      set titre = p_titre, description = p_description, url = p_url, audience = p_audience, ordre = p_ordre
      where id = p_id
      returning id into v_id;
  end if;
  return v_id;
end; $function$;

-- admin_valider_premium(p_admin_password text, p_etab_id text)
CREATE OR REPLACE FUNCTION public.admin_valider_premium(p_admin_password text, p_etab_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = extensions.crypt(p_admin_password, admin_password)) then
    return false;
  end if;
  update etablissements set premium = true, demande_premium = false where id = p_etab_id;
  return found;
end; $function$;

-- eleve_login(p_tel text, p_password text)
CREATE OR REPLACE FUNCTION public.eleve_login(p_tel text, p_password text)
 RETURNS TABLE(id text, nom text, prenoms text, classe text, etablissement text, tel text, riasec jsonb, active boolean, date_inscription text, banni boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select id, nom, prenoms, classe, etablissement, tel, riasec, active, date_inscription, banni
  from eleves where tel = p_tel and password = extensions.crypt(p_password, password);
$function$;

-- eleve_save_riasec(p_id text, p_password text, p_riasec jsonb)
CREATE OR REPLACE FUNCTION public.eleve_save_riasec(p_id text, p_password text, p_riasec jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  update eleves set riasec = p_riasec where id = p_id and password = extensions.crypt(p_password, password);
  return found;
end; $function$;

-- eleve_update_email(p_id text, p_password text, p_email text)
CREATE OR REPLACE FUNCTION public.eleve_update_email(p_id text, p_password text, p_email text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  update eleves set email = p_email where id = p_id and password = extensions.crypt(p_password, password);
  return found;
end; $function$;

-- etablissement_add_filiere(p_etab_id text, p_password text, p_nom text, p_diplome text)
CREATE OR REPLACE FUNCTION public.etablissement_add_filiere(p_etab_id text, p_password text, p_nom text, p_diplome text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_etab record;
  v_nouvelle jsonb;
  v_id text;
begin
  if coalesce(trim(p_nom), '') = '' or coalesce(trim(p_diplome), '') = '' then return false; end if;
  select * into v_etab from etablissements where id = p_etab_id and password = extensions.crypt(p_password, password);
  if not found then return false; end if;
  if jsonb_array_length(coalesce(v_etab.filieres_proposees, '[]'::jsonb)) >= 10 then return false; end if;

  v_id := 'id' || extract(epoch from clock_timestamp())::bigint::text || floor(random()*1000000)::text;
  v_nouvelle := jsonb_build_object(
    'id', v_id, 'nom', trim(p_nom), 'diplome', trim(p_diplome),
    'conditions', '', 'statut', 'valide', 'date', to_char(now(),'DD/MM/YYYY')
  );
  update etablissements
    set filieres_proposees = coalesce(filieres_proposees, '[]'::jsonb) || jsonb_build_array(v_nouvelle)
    where id = p_etab_id;
  return true;
end; $function$;

-- etablissement_claim_by_code(p_code text, p_email text, p_password text, p_responsable text, p_tel text, p_tel2 text, p_tel3 text, p_site_web text, p_contact_tel text)
CREATE OR REPLACE FUNCTION public.etablissement_claim_by_code(p_code text, p_email text, p_password text, p_responsable text DEFAULT NULL::text, p_tel text DEFAULT NULL::text, p_tel2 text DEFAULT NULL::text, p_tel3 text DEFAULT NULL::text, p_site_web text DEFAULT NULL::text, p_contact_tel text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_etab record;
begin
  if coalesce(trim(p_code), '') = '' or coalesce(trim(p_email), '') = '' or coalesce(trim(p_password), '') = '' then
    return false;
  end if;
  select * into v_etab from etablissements where code_recuperation = p_code and reclame = false;
  if not found then return false; end if;
  if exists (select 1 from etablissements where email = p_email and id <> v_etab.id) then
    return false;
  end if;

  update etablissements
    set email = p_email, password = p_password, reclame = true, code_recuperation = null,
        responsable = coalesce(nullif(trim(p_responsable), ''), responsable),
        tel = coalesce(nullif(trim(p_tel), ''), tel),
        tel2 = coalesce(nullif(trim(p_tel2), ''), tel2),
        tel3 = coalesce(nullif(trim(p_tel3), ''), tel3),
        site_web = coalesce(nullif(trim(p_site_web), ''), site_web),
        contact_tel = coalesce(nullif(trim(p_contact_tel), ''), contact_tel)
    where id = v_etab.id;
  return true;
end;
$function$;

-- etablissement_delete_filiere(p_etab_id text, p_password text, p_filiere_id text)
CREATE OR REPLACE FUNCTION public.etablissement_delete_filiere(p_etab_id text, p_password text, p_filiere_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_etab record;
  v_found boolean;
  v_new_filieres jsonb;
begin
  -- Authentification : id + mot de passe doivent correspondre
  select * into v_etab from etablissements where id = p_etab_id and password = extensions.crypt(p_password, password);
  if not found then return false; end if;

  -- La filière existe-t-elle bien dans le jsonb actuel ?
  v_found := exists (
    select 1 from jsonb_array_elements(coalesce(v_etab.filieres_proposees, '[]'::jsonb)) f
    where f->>'id' = p_filiere_id
  );
  if not v_found then return false; end if;

  -- Reconstruit le tableau jsonb en excluant la filière ciblée
  select coalesce(jsonb_agg(f), '[]'::jsonb) into v_new_filieres
    from jsonb_array_elements(v_etab.filieres_proposees) f
    where f->>'id' <> p_filiere_id;

  update etablissements set filieres_proposees = v_new_filieres where id = p_etab_id;
  return true;
end; $function$;

-- etablissement_demander_premium(p_etab_id text, p_password text)
CREATE OR REPLACE FUNCTION public.etablissement_demander_premium(p_etab_id text, p_password text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_etab record;
begin
  select * into v_etab from etablissements where id = p_etab_id and password = extensions.crypt(p_password, password);
  if not found then return false; end if;
  if v_etab.premium then return false; end if;

  update etablissements
    set demande_premium = true, demande_premium_date = to_char(now(), 'DD/MM/YYYY')
    where id = p_etab_id;
  return true;
end; $function$;

-- etablissement_get_own(p_etab_id text, p_password text)
CREATE OR REPLACE FUNCTION public.etablissement_get_own(p_etab_id text, p_password text)
 RETURNS TABLE(id text, nom text, region text, ville text, quartier text, type text, responsable text, contact_tel text, email text, tel text, tel2 text, tel3 text, site_web text, statut text, active boolean, date_inscription text, filieres_proposees jsonb, photos jsonb, logo_url text, categorie text, sous_categorie text, secteur text, pre_inscrit boolean, reclame boolean, premium boolean, demande_premium boolean, demande_premium_date text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from etablissements et where et.id = p_etab_id and et.password = extensions.crypt(p_password, et.password)) then
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

-- etablissement_login(p_email text, p_password text)
CREATE OR REPLACE FUNCTION public.etablissement_login(p_email text, p_password text)
 RETURNS TABLE(id text, nom text, ville text, type text, responsable text, tel text, email text, statut text, active boolean, date_inscription text, filieres_proposees jsonb)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select id, nom, ville, type, responsable, tel, email, statut, active, date_inscription, filieres_proposees
  from etablissements where email = p_email and password = extensions.crypt(p_password, password);
$function$;

-- etablissement_register(p_id text, p_nom text, p_region text, p_ville text, p_quartier text, p_type text, p_responsable text, p_tel text, p_email text, p_password text, p_date_inscription text, p_filieres_proposees jsonb, p_photos jsonb, p_categorie text, p_sous_categorie text, p_secteur text, p_tel2 text, p_tel3 text, p_site_web text, p_contact_tel text, p_logo_url text)
CREATE OR REPLACE FUNCTION public.etablissement_register(p_id text, p_nom text, p_region text, p_ville text, p_quartier text, p_type text, p_responsable text, p_tel text, p_email text, p_password text, p_date_inscription text, p_filieres_proposees jsonb, p_photos jsonb DEFAULT '[]'::jsonb, p_categorie text DEFAULT NULL::text, p_sous_categorie text DEFAULT NULL::text, p_secteur text DEFAULT NULL::text, p_tel2 text DEFAULT NULL::text, p_tel3 text DEFAULT NULL::text, p_site_web text DEFAULT NULL::text, p_contact_tel text DEFAULT NULL::text, p_logo_url text DEFAULT NULL::text)
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

-- etablissement_update_contact_extras(p_etab_id text, p_password text, p_tel2 text, p_tel3 text, p_site_web text)
CREATE OR REPLACE FUNCTION public.etablissement_update_contact_extras(p_etab_id text, p_password text, p_tel2 text, p_tel3 text, p_site_web text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_etab record;
begin
  select * into v_etab from etablissements where id = p_etab_id and password = extensions.crypt(p_password, password);
  if not found then return false; end if;
  update etablissements
    set tel2 = nullif(trim(coalesce(p_tel2,'')),''),
        tel3 = nullif(trim(coalesce(p_tel3,'')),''),
        site_web = nullif(trim(coalesce(p_site_web,'')),'')
    where id = p_etab_id;
  return true;
end;
$function$;

-- etablissement_update_info(p_etab_id text, p_password text, p_nom text, p_type text, p_responsable text, p_tel text, p_email text, p_contact_tel text)
CREATE OR REPLACE FUNCTION public.etablissement_update_info(p_etab_id text, p_password text, p_nom text, p_type text, p_responsable text, p_tel text, p_email text, p_contact_tel text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists(select 1 from etablissements where id = p_etab_id and password = extensions.crypt(p_password, password)) then
    return false;
  end if;
  update etablissements
    set nom = p_nom, type = p_type, responsable = p_responsable, tel = p_tel, email = p_email,
        contact_tel = coalesce(nullif(trim(p_contact_tel), ''), contact_tel)
    where id = p_etab_id;
  return true;
end;
$function$;

-- etablissement_update_localisation(p_etab_id text, p_password text, p_region text, p_ville text, p_quartier text)
CREATE OR REPLACE FUNCTION public.etablissement_update_localisation(p_etab_id text, p_password text, p_region text, p_ville text, p_quartier text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_etab record;
begin
  select * into v_etab from etablissements where id = p_etab_id and password = extensions.crypt(p_password, password);
  if not found then return false; end if;
  if p_ville is null or length(trim(p_ville)) = 0 then return false; end if;
  update etablissements set region = p_region, ville = p_ville, quartier = p_quartier where id = p_etab_id;
  return true;
end; $function$;

-- etablissement_update_logo(p_etab_id text, p_password text, p_logo_url text)
CREATE OR REPLACE FUNCTION public.etablissement_update_logo(p_etab_id text, p_password text, p_logo_url text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from etablissements where id = p_etab_id and password = extensions.crypt(p_password, password)) then
    return false;
  end if;
  update etablissements
    set logo_url = nullif(trim(coalesce(p_logo_url,'')),'')
    where id = p_etab_id;
  return true;
end; $function$;

-- etablissement_update_photos(p_etab_id text, p_password text, p_photos jsonb)
CREATE OR REPLACE FUNCTION public.etablissement_update_photos(p_etab_id text, p_password text, p_photos jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_etab record;
begin
  select * into v_etab from etablissements where id = p_etab_id and password = extensions.crypt(p_password, password);
  if not found then return false; end if;
  if not coalesce(v_etab.premium, false) then return false; end if;

  update etablissements
    set photos = (select jsonb_agg(v) from (select v from jsonb_array_elements(p_photos) v limit 10) s)
    where id = p_etab_id;
  return true;
end; $function$;

-- etablissement_verifier_doublon(p_nom text)
CREATE OR REPLACE FUNCTION public.etablissement_verifier_doublon(p_nom text)
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT
    EXISTS(
      SELECT 1 FROM etablissements
      WHERE lower(trim(nom)) = lower(trim(p_nom))
    )
    OR EXISTS(
      SELECT 1 FROM demandes_inscription_etablissements
      WHERE statut_demande = 'en_attente' AND lower(trim(nom)) = lower(trim(p_nom))
    );
$function$;

-- hash_admin_password_trigger()
CREATE OR REPLACE FUNCTION public.hash_admin_password_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.admin_password is not null and new.admin_password <> '' and new.admin_password !~ '^\$2[aby]\$' then
    new.admin_password := extensions.crypt(new.admin_password, extensions.gen_salt('bf'));
  end if;
  return new;
end;
$function$;

-- hash_password_trigger()
CREATE OR REPLACE FUNCTION public.hash_password_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- ne hashe que si une valeur est presente et n'est pas deja un hash bcrypt
  if new.password is not null and new.password <> '' and new.password !~ '^\$2[aby]\$' then
    new.password := extensions.crypt(new.password, extensions.gen_salt('bf'));
  end if;
  return new;
end;
$function$;

-- inspecteur_add_note(p_inspecteur_id text, p_password text, p_eleve_id text, p_texte text)
CREATE OR REPLACE FUNCTION public.inspecteur_add_note(p_inspecteur_id text, p_password text, p_eleve_id text, p_texte text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_insp record;
begin
  select * into v_insp from inspecteurs where id = p_inspecteur_id and password = extensions.crypt(p_password, password);
  if not found or coalesce(v_insp.banni, false) then return false; end if;
  insert into notes(id, eleve_id, inspecteur_id, inspecteur_nom, texte, date)
    values ('id' || extract(epoch from clock_timestamp())::bigint::text || floor(random()*1000000)::text,
            p_eleve_id, v_insp.id, trim(v_insp.nom || ' ' || coalesce(v_insp.prenoms,'')), p_texte, to_char(now(),'DD/MM/YYYY'));
  return true;
end; $function$;

-- inspecteur_list_private_messages(p_inspecteur_id text, p_password text)
CREATE OR REPLACE FUNCTION public.inspecteur_list_private_messages(p_inspecteur_id text, p_password text)
 RETURNS SETOF messages_prives
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if not exists(select 1 from inspecteurs where id = p_inspecteur_id and password = extensions.crypt(p_password, password)) then
    return;
  end if;
  return query
    select * from messages_prives
    where expediteur_id = p_inspecteur_id or destinataire_id = p_inspecteur_id
    order by created_at asc;
end;
$function$;

-- inspecteur_login(p_tel text, p_password text)
CREATE OR REPLACE FUNCTION public.inspecteur_login(p_tel text, p_password text)
 RETURNS TABLE(id text, nom text, prenoms text, fonction text, cio text, tel text, active boolean, date_inscription text, certifie boolean, banni boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select id, nom, prenoms, fonction, cio, tel, active, date_inscription, certifie, banni
  from inspecteurs where tel = p_tel and password = extensions.crypt(p_password, password);
$function$;

-- inspecteur_lycam_create_session(p_inspecteur_id text, p_password text, p_nom text)
CREATE OR REPLACE FUNCTION public.inspecteur_lycam_create_session(p_inspecteur_id text, p_password text, p_nom text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_ok boolean;
  v_id text;
begin
  select exists(
    select 1 from inspecteurs where id = p_inspecteur_id and password = extensions.crypt(p_password, password) and coalesce(banni,false) = false
  ) into v_ok;
  if not v_ok then return null; end if;

  v_id := 'lyc' || substr(md5(random()::text || clock_timestamp()::text), 1, 16);
  insert into lycam_sessions(id, inspecteur_id, nom) values (v_id, p_inspecteur_id, p_nom);
  return v_id;
end;
$function$;

-- inspecteur_lycam_delete_session(p_inspecteur_id text, p_password text, p_session_id text)
CREATE OR REPLACE FUNCTION public.inspecteur_lycam_delete_session(p_inspecteur_id text, p_password text, p_session_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if not exists(select 1 from inspecteurs where id = p_inspecteur_id and password = extensions.crypt(p_password, password)) then
    return false;
  end if;
  delete from lycam_sessions where id = p_session_id and inspecteur_id = p_inspecteur_id;
  return true;
end;
$function$;

-- inspecteur_lycam_list_results(p_inspecteur_id text, p_password text, p_session_id text)
CREATE OR REPLACE FUNCTION public.inspecteur_lycam_list_results(p_inspecteur_id text, p_password text, p_session_id text)
 RETURNS SETOF lycam_resultats
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if not exists(select 1 from inspecteurs where id = p_inspecteur_id and password = extensions.crypt(p_password, password)) then
    return;
  end if;
  if not exists(select 1 from lycam_sessions where id = p_session_id and inspecteur_id = p_inspecteur_id) then
    return;
  end if;
  return query select * from lycam_resultats where session_id = p_session_id order by created_at asc;
end;
$function$;

-- inspecteur_lycam_list_sessions(p_inspecteur_id text, p_password text)
CREATE OR REPLACE FUNCTION public.inspecteur_lycam_list_sessions(p_inspecteur_id text, p_password text)
 RETURNS SETOF lycam_sessions
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if not exists(select 1 from inspecteurs where id = p_inspecteur_id and password = extensions.crypt(p_password, password)) then
    return;
  end if;
  return query select * from lycam_sessions where inspecteur_id = p_inspecteur_id order by created_at desc;
end;
$function$;

-- inspecteur_lycam_save_result(p_inspecteur_id text, p_password text, p_session_id text, p_nom text, p_prenom text, p_naissance text, p_classe text, p_score_total integer, p_band text, p_scores jsonb)
CREATE OR REPLACE FUNCTION public.inspecteur_lycam_save_result(p_inspecteur_id text, p_password text, p_session_id text, p_nom text, p_prenom text, p_naissance text, p_classe text, p_score_total integer, p_band text, p_scores jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_ok boolean;
begin
  select exists(
    select 1 from inspecteurs where id = p_inspecteur_id and password = extensions.crypt(p_password, password) and coalesce(banni,false) = false
  ) into v_ok;
  if not v_ok then return false; end if;

  if not exists(select 1 from lycam_sessions where id = p_session_id and inspecteur_id = p_inspecteur_id) then
    return false;
  end if;

  insert into lycam_resultats(id, session_id, inspecteur_id, nom, prenom, naissance, classe, score_total, band, scores)
  values (
    'lycr' || substr(md5(random()::text || clock_timestamp()::text), 1, 16),
    p_session_id, p_inspecteur_id, p_nom, p_prenom, p_naissance, p_classe, p_score_total, p_band, p_scores
  );
  return true;
end;
$function$;

-- inspecteur_mark_private_read(p_inspecteur_id text, p_password text, p_autre_id text)
CREATE OR REPLACE FUNCTION public.inspecteur_mark_private_read(p_inspecteur_id text, p_password text, p_autre_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if not exists(select 1 from inspecteurs where id = p_inspecteur_id and password = extensions.crypt(p_password, password)) then
    return false;
  end if;
  update messages_prives set lu = true
  where destinataire_id = p_inspecteur_id and expediteur_id = p_autre_id and lu = false;
  return true;
end;
$function$;

-- inspecteur_mbti_create_session(p_inspecteur_id text, p_password text, p_nom text)
CREATE OR REPLACE FUNCTION public.inspecteur_mbti_create_session(p_inspecteur_id text, p_password text, p_nom text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_ok boolean;
  v_id text;
begin
  select exists(
    select 1 from inspecteurs where id = p_inspecteur_id and password = extensions.crypt(p_password, password) and coalesce(banni,false) = false
  ) into v_ok;
  if not v_ok then return null; end if;

  v_id := 'mbt' || substr(md5(random()::text || clock_timestamp()::text), 1, 16);
  insert into mbti_sessions(id, inspecteur_id, nom) values (v_id, p_inspecteur_id, p_nom);
  return v_id;
end;
$function$;

-- inspecteur_mbti_delete_session(p_inspecteur_id text, p_password text, p_session_id text)
CREATE OR REPLACE FUNCTION public.inspecteur_mbti_delete_session(p_inspecteur_id text, p_password text, p_session_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if not exists(select 1 from inspecteurs where id = p_inspecteur_id and password = extensions.crypt(p_password, password)) then
    return false;
  end if;
  delete from mbti_sessions where id = p_session_id and inspecteur_id = p_inspecteur_id;
  return true;
end;
$function$;

-- inspecteur_mbti_list_results(p_inspecteur_id text, p_password text, p_session_id text)
CREATE OR REPLACE FUNCTION public.inspecteur_mbti_list_results(p_inspecteur_id text, p_password text, p_session_id text)
 RETURNS SETOF mbti_resultats
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if not exists(select 1 from inspecteurs where id = p_inspecteur_id and password = extensions.crypt(p_password, password)) then
    return;
  end if;
  if not exists(select 1 from mbti_sessions where id = p_session_id and inspecteur_id = p_inspecteur_id) then
    return;
  end if;
  return query select * from mbti_resultats where session_id = p_session_id order by created_at asc;
end;
$function$;

-- inspecteur_mbti_list_sessions(p_inspecteur_id text, p_password text)
CREATE OR REPLACE FUNCTION public.inspecteur_mbti_list_sessions(p_inspecteur_id text, p_password text)
 RETURNS SETOF mbti_sessions
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if not exists(select 1 from inspecteurs where id = p_inspecteur_id and password = extensions.crypt(p_password, password)) then
    return;
  end if;
  return query select * from mbti_sessions where inspecteur_id = p_inspecteur_id order by created_at desc;
end;
$function$;

-- inspecteur_mbti_save_result(p_inspecteur_id text, p_password text, p_session_id text, p_nom text, p_prenom text, p_naissance text, p_classe text, p_scores jsonb, p_type_letters text, p_hierarchie jsonb, p_egalites jsonb)
CREATE OR REPLACE FUNCTION public.inspecteur_mbti_save_result(p_inspecteur_id text, p_password text, p_session_id text, p_nom text, p_prenom text, p_naissance text, p_classe text, p_scores jsonb, p_type_letters text, p_hierarchie jsonb, p_egalites jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_ok boolean;
begin
  select exists(
    select 1 from inspecteurs where id = p_inspecteur_id and password = extensions.crypt(p_password, password) and coalesce(banni,false) = false
  ) into v_ok;
  if not v_ok then return false; end if;

  if not exists(select 1 from mbti_sessions where id = p_session_id and inspecteur_id = p_inspecteur_id) then
    return false;
  end if;

  insert into mbti_resultats(id, session_id, inspecteur_id, nom, prenom, naissance, classe, scores, type_letters, hierarchie, egalites)
  values (
    'mbtr' || substr(md5(random()::text || clock_timestamp()::text), 1, 16),
    p_session_id, p_inspecteur_id, p_nom, p_prenom, p_naissance, p_classe, p_scores, p_type_letters, p_hierarchie, coalesce(p_egalites, '[]'::jsonb)
  );
  return true;
end;
$function$;

-- inspecteur_post_message(p_inspecteur_id text, p_password text, p_texte text, p_type text, p_reply_to text, p_attachment_url text, p_attachment_type text, p_attachment_name text)
CREATE OR REPLACE FUNCTION public.inspecteur_post_message(p_inspecteur_id text, p_password text, p_texte text, p_type text DEFAULT 'C'::text, p_reply_to text DEFAULT NULL::text, p_attachment_url text DEFAULT NULL::text, p_attachment_type text DEFAULT NULL::text, p_attachment_name text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_insp record;
begin
  if p_type not in ('A','C') then return false; end if;
  if p_attachment_type is not null and p_attachment_type not in ('image','pdf') then return false; end if;
  select * into v_insp from inspecteurs where id = p_inspecteur_id and password = extensions.crypt(p_password, password);
  if not found or coalesce(v_insp.banni, false) then return false; end if;
  if length(trim(coalesce(p_texte,''))) = 0 and p_attachment_url is null then return false; end if;

  insert into messages_inspecteurs(id, inspecteur_id, inspecteur_nom, texte, date, type, auteur_role, reply_to, attachment_url, attachment_type, attachment_name)
    values ('id' || extract(epoch from clock_timestamp())::bigint::text || floor(random()*1000000)::text,
            v_insp.id, trim(v_insp.nom || ' ' || coalesce(v_insp.prenoms,'')), p_texte, to_char(now(),'DD/MM/YYYY HH24:MI'), p_type, 'inspecteur', p_reply_to, p_attachment_url, p_attachment_type, p_attachment_name);
  return true;
end; $function$;

-- inspecteur_post_private_message(p_expediteur_id text, p_password text, p_destinataire_id text, p_texte text, p_attachment_url text, p_attachment_type text, p_attachment_name text)
CREATE OR REPLACE FUNCTION public.inspecteur_post_private_message(p_expediteur_id text, p_password text, p_destinataire_id text, p_texte text, p_attachment_url text DEFAULT NULL::text, p_attachment_type text DEFAULT NULL::text, p_attachment_name text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_ok boolean;
begin
  select exists(
    select 1 from inspecteurs where id = p_expediteur_id and password = extensions.crypt(p_password, password) and coalesce(banni,false) = false
  ) into v_ok;
  if not v_ok then return false; end if;

  if not exists(select 1 from inspecteurs where id = p_destinataire_id and coalesce(banni,false) = false) then
    return false;
  end if;

  insert into messages_prives(id, expediteur_id, destinataire_id, texte, date, attachment_url, attachment_type, attachment_name)
  values (
    'msg' || substr(md5(random()::text || clock_timestamp()::text), 1, 16),
    p_expediteur_id, p_destinataire_id, p_texte,
    to_char(now(), 'DD/MM/YYYY HH24:MI'),
    p_attachment_url, p_attachment_type, p_attachment_name
  );
  return true;
end;
$function$;

-- inspecteur_request_certification(p_inspecteur_id text, p_password text)
CREATE OR REPLACE FUNCTION public.inspecteur_request_certification(p_inspecteur_id text, p_password text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_insp record;
begin
  select * into v_insp from inspecteurs where id = p_inspecteur_id and password = extensions.crypt(p_password, password);
  if not found or coalesce(v_insp.banni, false) then return false; end if;
  update inspecteurs set certification_demandee = true where id = p_inspecteur_id;
  return true;
end; $function$;

-- inspecteur_suivi_add_eleve(p_inspecteur_id text, p_password text, p_nom text, p_prenoms text, p_classe text, p_raisons jsonb)
CREATE OR REPLACE FUNCTION public.inspecteur_suivi_add_eleve(p_inspecteur_id text, p_password text, p_nom text, p_prenoms text, p_classe text, p_raisons jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id uuid;
begin
  if not exists (
    select 1 from inspecteurs
    where id = p_inspecteur_id and password = extensions.crypt(p_password, password) and coalesce(banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  if coalesce(trim(p_nom), '') = '' or coalesce(trim(p_classe), '') = '' then
    raise exception 'Nom et classe sont obligatoires';
  end if;

  if p_raisons is null or jsonb_typeof(p_raisons) <> 'array' or jsonb_array_length(p_raisons) = 0 then
    raise exception 'Au moins une raison de suivi est obligatoire';
  end if;

  if exists (
    select 1 from jsonb_array_elements_text(p_raisons) as r
    where r not in ('IE','AF','RS','CS','AB','BS','PS')
  ) then
    raise exception 'Raison de suivi invalide';
  end if;

  insert into suivi_eleves(inspecteur_id, nom, prenoms, classe, raisons)
    values (p_inspecteur_id, trim(p_nom), nullif(trim(p_prenoms), ''), trim(p_classe), p_raisons)
    returning id into v_id;

  return v_id::text;
end; $function$;

-- inspecteur_suivi_add_note(p_inspecteur_id text, p_password text, p_suivi_id text, p_date_note text, p_texte text)
CREATE OR REPLACE FUNCTION public.inspecteur_suivi_add_note(p_inspecteur_id text, p_password text, p_suivi_id text, p_date_note text, p_texte text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (
    select 1 from inspecteurs
    where id = p_inspecteur_id and password = extensions.crypt(p_password, password) and coalesce(banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  if not exists (select 1 from suivi_eleves where id = p_suivi_id::uuid and inspecteur_id = p_inspecteur_id) then
    raise exception 'unauthorized';
  end if;

  if coalesce(trim(p_date_note), '') = '' or coalesce(trim(p_texte), '') = '' then
    raise exception 'Date et texte de la note sont obligatoires';
  end if;

  insert into suivi_eleves_notes(suivi_eleve_id, date_note, texte)
    values (p_suivi_id::uuid, trim(p_date_note), trim(p_texte));
  return true;
end; $function$;

-- inspecteur_suivi_delete_eleve(p_inspecteur_id text, p_password text, p_suivi_id text)
CREATE OR REPLACE FUNCTION public.inspecteur_suivi_delete_eleve(p_inspecteur_id text, p_password text, p_suivi_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (
    select 1 from inspecteurs
    where id = p_inspecteur_id and password = extensions.crypt(p_password, password) and coalesce(banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  delete from suivi_eleves where id = p_suivi_id::uuid and inspecteur_id = p_inspecteur_id;
  return found;
end; $function$;

-- inspecteur_suivi_get_eleve(p_inspecteur_id text, p_password text, p_suivi_id text)
CREATE OR REPLACE FUNCTION public.inspecteur_suivi_get_eleve(p_inspecteur_id text, p_password text, p_suivi_id text)
 RETURNS TABLE(id text, nom text, prenoms text, classe text, raisons jsonb, appreciation_finale text, date_ajout text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (
    select 1 from inspecteurs
    where inspecteurs.id = p_inspecteur_id and inspecteurs.password = extensions.crypt(p_password, inspecteurs.password) and coalesce(inspecteurs.banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  return query
    select s.id::text, s.nom, s.prenoms, s.classe, s.raisons, s.appreciation_finale, s.date_ajout
    from suivi_eleves s
    where s.id = p_suivi_id::uuid and s.inspecteur_id = p_inspecteur_id;
end; $function$;

-- inspecteur_suivi_list_eleves(p_inspecteur_id text, p_password text)
CREATE OR REPLACE FUNCTION public.inspecteur_suivi_list_eleves(p_inspecteur_id text, p_password text)
 RETURNS TABLE(id text, nom text, prenoms text, classe text, raisons jsonb, appreciation_finale text, date_ajout text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (
    select 1 from inspecteurs
    where inspecteurs.id = p_inspecteur_id and inspecteurs.password = extensions.crypt(p_password, inspecteurs.password) and coalesce(inspecteurs.banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  return query
    select s.id::text, s.nom, s.prenoms, s.classe, s.raisons, s.appreciation_finale, s.date_ajout
    from suivi_eleves s
    where s.inspecteur_id = p_inspecteur_id
    order by s.nom asc, s.prenoms asc;
end; $function$;

-- inspecteur_suivi_list_notes(p_inspecteur_id text, p_password text, p_suivi_id text)
CREATE OR REPLACE FUNCTION public.inspecteur_suivi_list_notes(p_inspecteur_id text, p_password text, p_suivi_id text)
 RETURNS TABLE(id text, date_note text, texte text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (
    select 1 from inspecteurs
    where inspecteurs.id = p_inspecteur_id and inspecteurs.password = extensions.crypt(p_password, inspecteurs.password) and coalesce(inspecteurs.banni, false) = false
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

-- inspecteur_suivi_set_appreciation(p_inspecteur_id text, p_password text, p_suivi_id text, p_appreciation text)
CREATE OR REPLACE FUNCTION public.inspecteur_suivi_set_appreciation(p_inspecteur_id text, p_password text, p_suivi_id text, p_appreciation text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (
    select 1 from inspecteurs
    where id = p_inspecteur_id and password = extensions.crypt(p_password, password) and coalesce(banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  update suivi_eleves
    set appreciation_finale = nullif(trim(p_appreciation), '')
    where id = p_suivi_id::uuid and inspecteur_id = p_inspecteur_id;
  return found;
end; $function$;

-- inspecteur_update_avatar(p_inspecteur_id text, p_password text, p_avatar_url text)
CREATE OR REPLACE FUNCTION public.inspecteur_update_avatar(p_inspecteur_id text, p_password text, p_avatar_url text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_insp record;
begin
  select * into v_insp from inspecteurs where id = p_inspecteur_id and password = extensions.crypt(p_password, password);
  if not found or coalesce(v_insp.banni, false) then return false; end if;
  update inspecteurs set avatar_url = p_avatar_url where id = p_inspecteur_id;
  return true;
end; $function$;

-- inspecteur_update_email(p_id text, p_password text, p_email text)
CREATE OR REPLACE FUNCTION public.inspecteur_update_email(p_id text, p_password text, p_email text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  update inspecteurs set email = p_email where id = p_id and password = extensions.crypt(p_password, password);
  return found;
end; $function$;

-- inspecteur_update_message_accueil(p_inspecteur_id text, p_password text, p_message_accueil text)
CREATE OR REPLACE FUNCTION public.inspecteur_update_message_accueil(p_inspecteur_id text, p_password text, p_message_accueil text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_insp record;
begin
  select * into v_insp from inspecteurs where id = p_inspecteur_id and password = extensions.crypt(p_password, password);
  if not found or coalesce(v_insp.banni, false) then return false; end if;
  update inspecteurs set message_accueil = p_message_accueil where id = p_inspecteur_id;
  return true;
end; $function$;

-- list_eleves()
CREATE OR REPLACE FUNCTION public.list_eleves()
 RETURNS TABLE(id text, nom text, prenoms text, classe text, etablissement text, tel text, email text, riasec jsonb, active boolean, date_inscription text, banni boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select id, nom, prenoms, classe, etablissement, tel, email, riasec, active, date_inscription, banni
  from eleves;
$function$;

-- list_etablissements()
CREATE OR REPLACE FUNCTION public.list_etablissements()
 RETURNS TABLE(id text, nom text, region text, ville text, quartier text, type text, statut text, active boolean, date_inscription text, filieres_proposees jsonb, photos jsonb, logo_url text, categorie text, sous_categorie text, secteur text, pre_inscrit boolean, reclame boolean, email text, tel text, tel2 text, tel3 text, site_web text, premium boolean, demande_premium boolean, demande_premium_date text)
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

-- list_inspecteurs()
CREATE OR REPLACE FUNCTION public.list_inspecteurs()
 RETURNS TABLE(id text, nom text, prenoms text, fonction text, cio text, tel text, email text, active boolean, date_inscription text, certifie boolean, banni boolean, avatar_url text, certification_demandee boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select id, nom, prenoms, fonction, cio, tel, email, active, date_inscription, certifie, banni, avatar_url, certification_demandee
  from inspecteurs;
$function$;

-- log_visite(p_page text)
CREATE OR REPLACE FUNCTION public.log_visite(p_page text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if p_page not in (
    'index.html', 'general.html', 'superieur.html', 'concours.html',
    'eleves.html', 'espaces.html', 'liens-formation.html'
  ) then
    return false;
  end if;

  insert into visites(page, visited_at) values (p_page, now());
  return true;
end; $function$;

-- request_password_reset(p_role text, p_email text)
CREATE OR REPLACE FUNCTION public.request_password_reset(p_role text, p_email text)
 RETURNS TABLE(email text, token text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id text; v_token text;
begin
  if p_role = 'eleve' then
    select e.id into v_id from eleves e where e.email = p_email;
  elsif p_role = 'inspecteur' then
    select i.id into v_id from inspecteurs i where i.email = p_email;
  elsif p_role = 'etablissement' then
    select et.id into v_id from etablissements et where et.email = p_email;
  else
    return;
  end if;

  if v_id is null then
    return;
  end if;

  v_token := encode(extensions.gen_random_bytes(24), 'hex');
  insert into password_resets(token, role, account_id, expires_at)
    values (v_token, p_role, v_id, now() + interval '1 hour');

  return query select p_email, v_token;
end; $function$;

-- reset_password_with_token(p_token text, p_new_password text)
CREATE OR REPLACE FUNCTION public.reset_password_with_token(p_token text, p_new_password text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_row record;
begin
  select * into v_row from password_resets
    where token = p_token and used = false and expires_at > now();
  if not found then return false; end if;

  if v_row.role = 'eleve' then
    update eleves set password = p_new_password where id = v_row.account_id;
  elsif v_row.role = 'inspecteur' then
    update inspecteurs set password = p_new_password where id = v_row.account_id;
  elsif v_row.role = 'etablissement' then
    update etablissements set password = p_new_password where id = v_row.account_id;
  else
    return false;
  end if;

  update password_resets set used = true where token = p_token;
  return true;
end; $function$;

-- ---------------------------------------------------------------------
-- TRIGGERS
-- ---------------------------------------------------------------------

-- admin_config.trg_hash_admin_password
CREATE TRIGGER trg_hash_admin_password BEFORE INSERT OR UPDATE OF admin_password ON public.admin_config FOR EACH ROW EXECUTE FUNCTION hash_admin_password_trigger();

-- demandes_inscription_etablissements.trg_hash_password
CREATE TRIGGER trg_hash_password BEFORE INSERT OR UPDATE OF password ON public.demandes_inscription_etablissements FOR EACH ROW EXECUTE FUNCTION hash_password_trigger();

-- eleves.trg_hash_password
CREATE TRIGGER trg_hash_password BEFORE INSERT OR UPDATE OF password ON public.eleves FOR EACH ROW EXECUTE FUNCTION hash_password_trigger();

-- etablissements.trg_hash_password
CREATE TRIGGER trg_hash_password BEFORE INSERT OR UPDATE OF password ON public.etablissements FOR EACH ROW EXECUTE FUNCTION hash_password_trigger();

-- inspecteurs.trg_hash_password
CREATE TRIGGER trg_hash_password BEFORE INSERT OR UPDATE OF password ON public.inspecteurs FOR EACH ROW EXECUTE FUNCTION hash_password_trigger();
