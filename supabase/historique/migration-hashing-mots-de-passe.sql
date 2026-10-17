-- Migration : hashing des mots de passe (bcrypt via pgcrypto)
-- Contexte : tous les mots de passe (eleves, inspecteurs, etablissements, 
-- demandes_inscription_etablissements, admin_config) sont actuellement 
-- stockes et compares EN CLAIR. Cette migration :
--   1. Active pgcrypto
--   2. Ajoute des triggers qui hashent automatiquement tout mot de passe 
--      inséré ou modifié (couvre les RPC ET les inserts directs .from())
--   3. Hashe en place tous les mots de passe déjà stockés en clair
--   4. Met à jour toutes les fonctions de vérification pour comparer via crypt()
--
-- A REVOIR PUIS EXECUTER MANUELLEMENT dans le SQL Editor Supabase.
-- Tester ENSUITE les 4 connexions (eleve, inspecteur, etablissement, admin) 
-- + inscription elève/inspecteur + inscription etablissement + reset mdp.

-- ============================================================
-- 1. Extension pgcrypto
-- ============================================================
create extension if not exists pgcrypto;

-- ============================================================
-- 2. Fonction de hashing générique (trigger)
-- ============================================================
create or replace function public.hash_password_trigger()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  -- ne hashe que si une valeur est presente et n'est pas deja un hash bcrypt
  if new.password is not null and new.password <> '' and new.password !~ '^\$2[aby]\$' then
    new.password := crypt(new.password, gen_salt('bf'));
  end if;
  return new;
end;
$$;

create or replace function public.hash_admin_password_trigger()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if new.admin_password is not null and new.admin_password <> '' and new.admin_password !~ '^\$2[aby]\$' then
    new.admin_password := crypt(new.admin_password, gen_salt('bf'));
  end if;
  return new;
end;
$$;

-- ============================================================
-- 3. Triggers sur chaque table concernee
-- ============================================================
drop trigger if exists trg_hash_password on public.eleves;
create trigger trg_hash_password
  before insert or update of password on public.eleves
  for each row execute function public.hash_password_trigger();

drop trigger if exists trg_hash_password on public.inspecteurs;
create trigger trg_hash_password
  before insert or update of password on public.inspecteurs
  for each row execute function public.hash_password_trigger();

drop trigger if exists trg_hash_password on public.etablissements;
create trigger trg_hash_password
  before insert or update of password on public.etablissements
  for each row execute function public.hash_password_trigger();

drop trigger if exists trg_hash_password on public.demandes_inscription_etablissements;
create trigger trg_hash_password
  before insert or update of password on public.demandes_inscription_etablissements
  for each row execute function public.hash_password_trigger();

drop trigger if exists trg_hash_admin_password on public.admin_config;
create trigger trg_hash_admin_password
  before insert or update of admin_password on public.admin_config
  for each row execute function public.hash_admin_password_trigger();

-- ============================================================
-- 4. Hashing en place des mots de passe deja stockes en clair
--    (a executer UNE SEULE FOIS - le trigger ne s'applique qu'aux 
--    futures ecritures, pas aux lignes existantes)
-- ============================================================
update public.eleves
  set password = crypt(password, gen_salt('bf'))
  where password is not null and password <> '' and password !~ '^\$2[aby]\$';

update public.inspecteurs
  set password = crypt(password, gen_salt('bf'))
  where password is not null and password <> '' and password !~ '^\$2[aby]\$';

update public.etablissements
  set password = crypt(password, gen_salt('bf'))
  where password is not null and password <> '' and password !~ '^\$2[aby]\$';

update public.demandes_inscription_etablissements
  set password = crypt(password, gen_salt('bf'))
  where password is not null and password <> '' and password !~ '^\$2[aby]\$';

update public.admin_config
  set admin_password = crypt(admin_password, gen_salt('bf'))
  where admin_password is not null and admin_password <> '' and admin_password !~ '^\$2[aby]\$';

-- ============================================================
-- 5. Mise a jour des fonctions de verification (comparaison via crypt())
--    27 fonctions : 3 logins utilisateur + admin_login + 23 fonctions 
--    admin qui verifient le mot de passe admin en ligne
-- ============================================================

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
  if not exists (select 1 from admin_config where id = 1 and admin_password = crypt(p_admin_password, admin_password)) then
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

CREATE OR REPLACE FUNCTION public.admin_delete_lien_formation(p_admin_password text, p_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = crypt(p_admin_password, admin_password)) then return false; end if;
  delete from liens_formation where id = p_id;
  return found;
end; $function$;

CREATE OR REPLACE FUNCTION public.admin_delete_message(p_admin_password text, p_message_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = crypt(p_admin_password, admin_password)) then return false; end if;
  delete from messages_inspecteurs where id = p_message_id;
  return found;
end; $function$;

CREATE OR REPLACE FUNCTION public.admin_get_visite_stats(p_admin_password text)
 RETURNS TABLE(page text, jour date, visites bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where admin_config.id = 1 and admin_configadmin_password = crypt(p_admin_password, admin_configadmin_password)) then
    raise exception 'unauthorized';
  end if;

  return query
    select v.page, v.visited_at::date as jour, count(*)::bigint as visites
    from visites v
    group by v.page, v.visited_at::date
    order by jour desc, v.page asc;
end; $function$;

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
  if not exists (select 1 from admin_config where id = 1 and admin_password = crypt(p_admin_password, admin_password)) then
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

CREATE OR REPLACE FUNCTION public.admin_list_all_etablissement_codes(p_admin_password text)
 RETURNS TABLE(nom text, categorie text, sous_categorie text, ville text, secteur text, code_recuperation text, reclame boolean, date_inscription text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = crypt(p_admin_password, admin_password)) then
    raise exception 'Mot de passe administrateur invalide';
  end if;

  return query
    select e.nom, e.categorie, e.sous_categorie, e.ville, e.secteur, e.code_recuperation, e.reclame, e.date_inscription
    from etablissements e
    where e.pre_inscrit = true and e.code_recuperation is not null
    order by e.nom;
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_list_demandes_inscription_etablissements(p_admin_password text)
 RETURNS TABLE(id text, nom text, region text, ville text, quartier text, type text, responsable text, tel text, tel2 text, tel3 text, email text, site_web text, contact_tel text, date_inscription text, filieres_proposees jsonb, photos jsonb, logo_url text, categorie text, sous_categorie text, secteur text, date_demande text, statut_demande text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where admin_config.id = 1 and admin_configadmin_password = crypt(p_admin_password, admin_configadmin_password)) then
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

CREATE OR REPLACE FUNCTION public.admin_list_etablissements_full(p_admin_password text)
 RETURNS TABLE(id text, nom text, region text, ville text, quartier text, type text, responsable text, contact_tel text, email text, tel text, tel2 text, tel3 text, site_web text, statut text, active boolean, date_inscription text, filieres_proposees jsonb, photos jsonb, logo_url text, categorie text, sous_categorie text, secteur text, pre_inscrit boolean, reclame boolean, premium boolean, demande_premium boolean, demande_premium_date text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config ac where ac.id = 1 and acadmin_password = crypt(p_admin_password, acadmin_password)) then
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

CREATE OR REPLACE FUNCTION public.admin_list_unclaimed_codes(p_admin_password text)
 RETURNS TABLE(id text, nom text, region text, ville text, quartier text, categorie text, sous_categorie text, secteur text, code_recuperation text, date_inscription text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config ac where ac.id = 1 and acadmin_password = crypt(p_admin_password, acadmin_password)) then
    raise exception 'Mot de passe administrateur invalide';
  end if;
  return query
    select e.id, e.nom, e.region, e.ville, e.quartier, e.categorie, e.sous_categorie, e.secteur, e.code_recuperation, e.date_inscription
    from etablissements e
    where e.pre_inscrit = true and e.reclame = false
    order by e.categorie, e.secteur, e.region, e.nom;
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_login(p_password text)
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists(select 1 from admin_config where id = 1 and admin_password = crypt(p_password, admin_password));
$function$;

CREATE OR REPLACE FUNCTION public.admin_marquer_demande_traitee(p_admin_password text, p_demande_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = crypt(p_admin_password, admin_password)) then return false; end if;
  update demandes_inscription_etablissements
    set statut_demande = 'traite'
    where id = p_demande_id::uuid and statut_demande = 'en_attente';
  return found;
end; $function$;

CREATE OR REPLACE FUNCTION public.admin_post_message(p_admin_password text, p_texte text, p_type text DEFAULT 'O'::text, p_reply_to text DEFAULT NULL::text, p_attachment_url text DEFAULT NULL::text, p_attachment_type text DEFAULT NULL::text, p_attachment_name text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = crypt(p_admin_password, admin_password)) then return false; end if;
  if p_type not in ('O','C') then return false; end if;
  if p_attachment_type is not null and p_attachment_type not in ('image','pdf') then return false; end if;
  if length(trim(coalesce(p_texte,''))) = 0 and p_attachment_url is null then return false; end if;

  insert into messages_inspecteurs(id, inspecteur_id, inspecteur_nom, texte, date, type, auteur_role, reply_to, attachment_url, attachment_type, attachment_name)
    values ('id' || extract(epoch from clock_timestamp())::bigint::text || floor(random()*1000000)::text,
            null, 'Administration ORIMETIER', p_texte, to_char(now(),'DD/MM/YYYY HH24:MI'), p_type, 'admin', p_reply_to, p_attachment_url, p_attachment_type, p_attachment_name);
  return true;
end; $function$;

CREATE OR REPLACE FUNCTION public.admin_restore_backup(p_admin_password text, p_payload jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists(select 1 from admin_config where id = 1 and admin_password = crypt(p_admin_password, admin_password)) then return false; end if;
  delete from eleves; delete from inspecteurs; delete from etablissements; delete from notes;
  insert into eleves select * from jsonb_populate_recordset(null::eleves, coalesce(p_payload->'eleves', '[]'::jsonb));
  insert into inspecteurs select * from jsonb_populate_recordset(null::inspecteurs, coalesce(p_payload->'inspecteurs', '[]'::jsonb));
  insert into etablissements select * from jsonb_populate_recordset(null::etablissements, coalesce(p_payload->'etablissements', '[]'::jsonb));
  insert into notes select * from jsonb_populate_recordset(null::notes, coalesce(p_payload->'notes', '[]'::jsonb));
  return true;
end; $function$;

CREATE OR REPLACE FUNCTION public.admin_set_annonce_active(p_admin_password text, p_id integer, p_active boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = crypt(p_admin_password, admin_password)) then return false; end if;

  if p_active then
    if (select count(*) from annonce where active = true and id <> p_id) >= 5 then
      return false;
    end if;
  end if;

  update annonce set active = p_active, updated_at = now() where id = p_id;
  return found;
end; $function$;

CREATE OR REPLACE FUNCTION public.admin_set_eleve_banni(p_admin_password text, p_eleve_id text, p_banni boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = crypt(p_admin_password, admin_password)) then return false; end if;
  update eleves set banni = p_banni where id = p_eleve_id;
  return found;
end; $function$;

CREATE OR REPLACE FUNCTION public.admin_set_etab_premium(p_admin_password text, p_etab_id text, p_premium boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = crypt(p_admin_password, admin_password)) then return false; end if;
  update etablissements set premium = p_premium where id = p_etab_id;
  return found;
end; $function$;

CREATE OR REPLACE FUNCTION public.admin_set_etab_statut(p_admin_password text, p_etab_id text, p_statut text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists(select 1 from admin_config where id = 1 and admin_password = crypt(p_admin_password, admin_password)) then return false; end if;
  update etablissements set statut = p_statut where id = p_etab_id;
  return found;
end; $function$;

CREATE OR REPLACE FUNCTION public.admin_set_filiere_statut(p_admin_password text, p_etab_id text, p_filiere_id text, p_statut text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_filieres jsonb; v_updated jsonb;
begin
  if not exists(select 1 from admin_config where id = 1 and admin_password = crypt(p_admin_password, admin_password)) then return false; end if;
  select filieres_proposees into v_filieres from etablissements where id = p_etab_id;
  select jsonb_agg(
    case when elem->>'id' = p_filiere_id then elem || jsonb_build_object('statut', p_statut) else elem end
  ) into v_updated from jsonb_array_elements(coalesce(v_filieres, '[]'::jsonb)) elem;
  update etablissements set filieres_proposees = coalesce(v_updated, '[]'::jsonb) where id = p_etab_id;
  return true;
end; $function$;

CREATE OR REPLACE FUNCTION public.admin_set_inspecteur_banni(p_admin_password text, p_inspecteur_id text, p_banni boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = crypt(p_admin_password, admin_password)) then return false; end if;
  update inspecteurs set banni = p_banni where id = p_inspecteur_id;
  return found;
end; $function$;

CREATE OR REPLACE FUNCTION public.admin_set_inspecteur_certifie(p_admin_password text, p_inspecteur_id text, p_certifie boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = crypt(p_admin_password, admin_password)) then return false; end if;
  update inspecteurs set certifie = p_certifie,
    certification_demandee = case when p_certifie then false else certification_demandee end
  where id = p_inspecteur_id;
  return found;
end; $function$;

CREATE OR REPLACE FUNCTION public.admin_supprimer_annonce(p_admin_password text, p_id integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = crypt(p_admin_password, admin_password)) then return false; end if;
  delete from annonce where id = p_id and active = false;
  return found;
end; $function$;

CREATE OR REPLACE FUNCTION public.admin_upsert_annonce(p_admin_password text, p_id integer, p_type text, p_texte text, p_image_url text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id int;
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = crypt(p_admin_password, admin_password)) then return null; end if;
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

CREATE OR REPLACE FUNCTION public.admin_upsert_lien_formation(p_admin_password text, p_id bigint, p_titre text, p_description text, p_url text, p_audience text, p_ordre integer DEFAULT NULL::integer)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id bigint;
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = crypt(p_admin_password, admin_password)) then return null; end if;
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

CREATE OR REPLACE FUNCTION public.admin_valider_premium(p_admin_password text, p_etab_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = crypt(p_admin_password, admin_password)) then
    return false;
  end if;
  update etablissements set premium = true, demande_premium = false where id = p_etab_id;
  return found;
end; $function$;

CREATE OR REPLACE FUNCTION public.eleve_login(p_tel text, p_password text)
 RETURNS TABLE(id text, nom text, prenoms text, classe text, etablissement text, tel text, riasec jsonb, active boolean, date_inscription text, banni boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select id, nom, prenoms, classe, etablissement, tel, riasec, active, date_inscription, banni
  from eleves where tel = p_tel and password = crypt(p_password, password);
$function$;

CREATE OR REPLACE FUNCTION public.inspecteur_login(p_tel text, p_password text)
 RETURNS TABLE(id text, nom text, prenoms text, fonction text, cio text, tel text, active boolean, date_inscription text, certifie boolean, banni boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select id, nom, prenoms, fonction, cio, tel, active, date_inscription, certifie, banni
  from inspecteurs where tel = p_tel and password = crypt(p_password, password);
$function$;

CREATE OR REPLACE FUNCTION public.etablissement_login(p_email text, p_password text)
 RETURNS TABLE(id text, nom text, ville text, type text, responsable text, tel text, email text, statut text, active boolean, date_inscription text, filieres_proposees jsonb)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select id, nom, ville, type, responsable, tel, email, statut, active, date_inscription, filieres_proposees
  from etablissements where email = p_email and password = crypt(p_password, password);
$function$;