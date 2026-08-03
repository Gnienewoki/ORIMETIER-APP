-- ============================================================
-- ORIMETIER — Migration Supabase : bannissement élève, avatar
-- inspecteur, certification à la demande, pièces jointes du chat.
--
-- Ce script reprend le CODE RÉEL de tes fonctions existantes (récupéré
-- directement depuis pg_proc le 2026-08-02), pas une reconstitution
-- approximative : inspecteur_post_message, admin_post_message et
-- admin_set_inspecteur_certifie ci-dessous sont tes fonctions actuelles,
-- avec uniquement les ajouts nécessaires (pièces jointes / remise à zéro
-- de la demande de certification). Tout le reste de leur logique
-- (vérifications, format des dates, génération d'id...) est inchangé.
--
-- À exécuter en une fois dans l'éditeur SQL de Supabase.
-- ============================================================

-- ============================================================
-- 1) Bannissement d'un compte élève
-- ============================================================
ALTER TABLE eleves ADD COLUMN IF NOT EXISTS banni boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.admin_set_eleve_banni(p_admin_password text, p_eleve_id text, p_banni boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = p_admin_password) then return false; end if;
  update eleves set banni = p_banni where id = p_eleve_id;
  return found;
end; $function$;

-- eleve_login : code réel existant, avec ajout de la colonne "banni" au
-- résultat renvoyé, pour que l'appli puisse refuser la connexion d'un élève
-- banni dès l'instant de la connexion (comme espEleveLogin() le vérifie déjà
-- côté front-end). Changer les colonnes renvoyées par une fonction TABLE
-- oblige PostgreSQL à d'abord la supprimer (CREATE OR REPLACE seul refuse
-- de changer le type de retour) : DROP explicite ci-dessous.
DROP FUNCTION IF EXISTS public.eleve_login(text, text);
CREATE OR REPLACE FUNCTION public.eleve_login(p_tel text, p_password text)
 RETURNS TABLE(id text, nom text, prenoms text, classe text, etablissement text, tel text, riasec jsonb, active boolean, date_inscription text, banni boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select id, nom, prenoms, classe, etablissement, tel, riasec, active, date_inscription, banni
  from eleves where tel = p_tel and password = p_password;
$function$;

-- ============================================================
-- 2) Photo de profil inspecteur
-- ============================================================
ALTER TABLE inspecteurs ADD COLUMN IF NOT EXISTS avatar_url text;

CREATE OR REPLACE FUNCTION public.inspecteur_update_avatar(p_inspecteur_id text, p_password text, p_avatar_url text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_insp record;
begin
  select * into v_insp from inspecteurs where id = p_inspecteur_id and password = p_password;
  if not found or coalesce(v_insp.banni, false) then return false; end if;
  update inspecteurs set avatar_url = p_avatar_url where id = p_inspecteur_id;
  return true;
end; $function$;

-- ============================================================
-- 3) Certification "à la demande"
-- ============================================================
ALTER TABLE inspecteurs ADD COLUMN IF NOT EXISTS certification_demandee boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.inspecteur_request_certification(p_inspecteur_id text, p_password text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_insp record;
begin
  select * into v_insp from inspecteurs where id = p_inspecteur_id and password = p_password;
  if not found or coalesce(v_insp.banni, false) then return false; end if;
  update inspecteurs set certification_demandee = true where id = p_inspecteur_id;
  return true;
end; $function$;

-- admin_set_inspecteur_certifie : code réel existant, avec ajout de la remise
-- à zéro de certification_demandee quand l'admin certifie le compte.
CREATE OR REPLACE FUNCTION public.admin_set_inspecteur_certifie(p_admin_password text, p_inspecteur_id text, p_certifie boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = p_admin_password) then return false; end if;
  update inspecteurs set certifie = p_certifie,
    certification_demandee = case when p_certifie then false else certification_demandee end
  where id = p_inspecteur_id;
  return found;
end; $function$;

-- ============================================================
-- 4) Pièces jointes dans le chat (photo ou PDF, pas de vidéo)
-- ============================================================
ALTER TABLE messages_inspecteurs ADD COLUMN IF NOT EXISTS attachment_url text;
ALTER TABLE messages_inspecteurs ADD COLUMN IF NOT EXISTS attachment_type text; -- 'image' ou 'pdf'
ALTER TABLE messages_inspecteurs ADD COLUMN IF NOT EXISTS attachment_name text;

-- inspecteur_post_message : code réel existant (version à 5 paramètres,
-- celle réellement appelée par l'application — la version à 3 paramètres
-- sans p_type/p_reply_to est une ancienne surcharge inutilisée, laissée
-- telle quelle), avec ajout des 3 paramètres de pièce jointe.
-- Ajouter des paramètres change la liste de types de la fonction : sans ce
-- DROP, PostgreSQL créerait une 3e surcharge au lieu de remplacer la version
-- à 5 paramètres actuellement utilisée par l'appli.
DROP FUNCTION IF EXISTS public.inspecteur_post_message(text, text, text, text, text);
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
  select * into v_insp from inspecteurs where id = p_inspecteur_id and password = p_password;
  if not found or coalesce(v_insp.banni, false) then return false; end if;
  if length(trim(p_texte)) = 0 then return false; end if;

  insert into messages_inspecteurs(id, inspecteur_id, inspecteur_nom, texte, date, type, auteur_role, reply_to, attachment_url, attachment_type, attachment_name)
    values ('id' || extract(epoch from clock_timestamp())::bigint::text || floor(random()*1000000)::text,
            v_insp.id, trim(v_insp.nom || ' ' || coalesce(v_insp.prenoms,'')), p_texte, to_char(now(),'DD/MM/YYYY HH24:MI'), p_type, 'inspecteur', p_reply_to, p_attachment_url, p_attachment_type, p_attachment_name);
  return true;
end; $function$;

-- admin_post_message : code réel existant, avec ajout des 3 paramètres de
-- pièce jointe. Même raison de DROP que ci-dessus (changement de la liste
-- de types de la fonction).
DROP FUNCTION IF EXISTS public.admin_post_message(text, text, text, text);
CREATE OR REPLACE FUNCTION public.admin_post_message(p_admin_password text, p_texte text, p_type text DEFAULT 'O'::text, p_reply_to text DEFAULT NULL::text, p_attachment_url text DEFAULT NULL::text, p_attachment_type text DEFAULT NULL::text, p_attachment_name text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = p_admin_password) then return false; end if;
  if p_type not in ('O','C') then return false; end if;
  if p_attachment_type is not null and p_attachment_type not in ('image','pdf') then return false; end if;
  if length(trim(p_texte)) = 0 then return false; end if;

  insert into messages_inspecteurs(id, inspecteur_id, inspecteur_nom, texte, date, type, auteur_role, reply_to, attachment_url, attachment_type, attachment_name)
    values ('id' || extract(epoch from clock_timestamp())::bigint::text || floor(random()*1000000)::text,
            null, 'Administration ORIMETIER', p_texte, to_char(now(),'DD/MM/YYYY HH24:MI'), p_type, 'admin', p_reply_to, p_attachment_url, p_attachment_type, p_attachment_name);
  return true;
end; $function$;

-- ============================================================
-- 5) Stockage des fichiers (Storage > Buckets)
-- ============================================================
-- Crée un bucket "orimetier-chat" (Storage > New bucket), coché "Public
-- bucket" (lecture publique nécessaire pour afficher photos/PDF dans le
-- chat). Puis, dans Storage > Policies pour ce bucket, ajoute :
--
-- CREATE POLICY "Public insert orimetier-chat"
-- ON storage.objects FOR INSERT
-- WITH CHECK (bucket_id = 'orimetier-chat');
--
-- ⚠️ Comme le reste de l'application (mots de passe en clair, pas de vraie
-- authentification Supabase Auth), cette policy fait confiance à la clé
-- publique déjà visible dans le code : n'importe qui la possédant peut
-- déposer un fichier dans ce bucket. Limite les abus via une taille max
-- dans les réglages du bucket (ex. 5 Mo).

-- ============================================================
-- 6) Autoriser l'envoi d'une pièce jointe seule (sans texte)
-- ============================================================
-- Avant, un message sans texte était toujours refusé, même avec une pièce
-- jointe : impossible de partager juste une photo/un PDF sans taper un mot.
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
  select * into v_insp from inspecteurs where id = p_inspecteur_id and password = p_password;
  if not found or coalesce(v_insp.banni, false) then return false; end if;
  if length(trim(coalesce(p_texte,''))) = 0 and p_attachment_url is null then return false; end if;

  insert into messages_inspecteurs(id, inspecteur_id, inspecteur_nom, texte, date, type, auteur_role, reply_to, attachment_url, attachment_type, attachment_name)
    values ('id' || extract(epoch from clock_timestamp())::bigint::text || floor(random()*1000000)::text,
            v_insp.id, trim(v_insp.nom || ' ' || coalesce(v_insp.prenoms,'')), p_texte, to_char(now(),'DD/MM/YYYY HH24:MI'), p_type, 'inspecteur', p_reply_to, p_attachment_url, p_attachment_type, p_attachment_name);
  return true;
end; $function$;

CREATE OR REPLACE FUNCTION public.admin_post_message(p_admin_password text, p_texte text, p_type text DEFAULT 'O'::text, p_reply_to text DEFAULT NULL::text, p_attachment_url text DEFAULT NULL::text, p_attachment_type text DEFAULT NULL::text, p_attachment_name text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = p_admin_password) then return false; end if;
  if p_type not in ('O','C') then return false; end if;
  if p_attachment_type is not null and p_attachment_type not in ('image','pdf') then return false; end if;
  if length(trim(coalesce(p_texte,''))) = 0 and p_attachment_url is null then return false; end if;

  insert into messages_inspecteurs(id, inspecteur_id, inspecteur_nom, texte, date, type, auteur_role, reply_to, attachment_url, attachment_type, attachment_name)
    values ('id' || extract(epoch from clock_timestamp())::bigint::text || floor(random()*1000000)::text,
            null, 'Administration ORIMETIER', p_texte, to_char(now(),'DD/MM/YYYY HH24:MI'), p_type, 'admin', p_reply_to, p_attachment_url, p_attachment_type, p_attachment_name);
  return true;
end; $function$;

-- ============================================================
-- 7) Message d'accueil de l'inspecteur (affiché près de sa photo de profil)
-- ============================================================
ALTER TABLE inspecteurs ADD COLUMN IF NOT EXISTS message_accueil text;

CREATE OR REPLACE FUNCTION public.inspecteur_update_message_accueil(p_inspecteur_id text, p_password text, p_message_accueil text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_insp record;
begin
  select * into v_insp from inspecteurs where id = p_inspecteur_id and password = p_password;
  if not found or coalesce(v_insp.banni, false) then return false; end if;
  update inspecteurs set message_accueil = p_message_accueil where id = p_inspecteur_id;
  return true;
end; $function$;

-- ============================================================
-- 8) Localisation de l'établissement (Région / Ville / Quartier)
-- ============================================================
-- "ville" existe déjà. On ajoute région et quartier, remplis à l'inscription
-- (nouveaux établissements) ou complétés ensuite depuis le tableau de bord
-- établissement (fiches déjà inscrites, région/quartier vides au départ).
ALTER TABLE etablissements ADD COLUMN IF NOT EXISTS region text;
ALTER TABLE etablissements ADD COLUMN IF NOT EXISTS quartier text;

CREATE OR REPLACE FUNCTION public.etablissement_update_localisation(p_etab_id text, p_password text, p_region text, p_ville text, p_quartier text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_etab record;
begin
  select * into v_etab from etablissements where id = p_etab_id and password = p_password;
  if not found then return false; end if;
  if p_ville is null or length(trim(p_ville)) = 0 then return false; end if;
  update etablissements set region = p_region, ville = p_ville, quartier = p_quartier where id = p_etab_id;
  return true;
end; $function$;

-- ============================================================
-- 9) Correction du 401 à l'inscription d'un établissement
-- ============================================================
-- espInsertEtablissement() écrivait directement dans la table etablissements
-- (INSERT ... via l'anon key). Comme pour la lecture (cf. supabase-list-
-- functions.sql), la table n'accorde apparemment pas ce droit à l'anon key :
-- Supabase renvoie 401 sur l'INSERT. On applique le même remède que pour les
-- lectures et pour toutes les autres écritures de l'appli (avatar, message
-- d'accueil, chat...) : passer par une fonction SECURITY DEFINER dédiée, qui
-- tourne avec les droits du propriétaire et ne dépend donc plus des
-- permissions accordées à l'anon key sur la table elle-même.
CREATE OR REPLACE FUNCTION public.etablissement_register(
  p_id text, p_nom text, p_region text, p_ville text, p_quartier text, p_type text,
  p_responsable text, p_tel text, p_email text, p_password text, p_date_inscription text,
  p_filieres_proposees jsonb
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
  if exists (select 1 from etablissements where email = p_email) then return false; end if;

  insert into etablissements(id, nom, region, ville, quartier, type, responsable, tel, email, password, statut, active, date_inscription, filieres_proposees)
    values (p_id, p_nom, p_region, p_ville, p_quartier, p_type, p_responsable, p_tel, p_email, p_password, 'en_attente', true, p_date_inscription, coalesce(p_filieres_proposees, '[]'::jsonb));
  return true;
end; $function$;
