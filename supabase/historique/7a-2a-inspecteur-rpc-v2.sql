-- ============================================================
-- ORIMETIER — Phase 7a-2a : RPC inspecteur par jeton, lot 1 : profil et
-- messagerie (8 fonctions _v2).
--
-- Pré-requis : 7a-1 exécutée (inspecteur_session_open, trigger
-- trg_inspecteurs_revoke_sessions). Migration ADDITIVE : les anciennes
-- fonctions (p_inspecteur_id / p_id / p_expediteur_id + p_password) et
-- inspecteur_login restent en service jusqu'en 7c ; elles ne sont ni
-- modifiées ni supprimées ici.
--
-- Source : code de PRODUCTION du 03/10/2026
-- (prod-inspecteur-fonctions-2026-10-03.csv). Comparaison automatique faite
-- le 03/10 (espaces normalisés) : les 27 fonctions inspecteur_* de production
-- sont identiques à supabase/reference/live-2026-09-26.sql, une seule
-- signature chacune ; _session_user identique à 5a-1 ; inspecteur_session_open
-- et inspecteurs_revoke_sessions_trigger identiques à 7a-1 ;
-- reset_password_with_token identique à reset-4a.
--
-- Nouvelles fonctions :
--   inspecteur_post_message_v2(p_token, p_texte, p_type DEFAULT 'C', p_reply_to DEFAULT null,
--                              p_attachment_url DEFAULT null, p_attachment_type DEFAULT null,
--                              p_attachment_name DEFAULT null)
--   inspecteur_post_private_message_v2(p_token, p_destinataire_id, p_texte,
--                              p_attachment_url DEFAULT null, p_attachment_type DEFAULT null,
--                              p_attachment_name DEFAULT null)
--   inspecteur_list_private_messages_v2(p_token)               -> SETOF messages_prives
--   inspecteur_mark_private_read_v2(p_token, p_autre_id)
--   inspecteur_request_certification_v2(p_token)
--   inspecteur_update_avatar_v2(p_token, p_avatar_url)
--   inspecteur_update_message_accueil_v2(p_token, p_message_accueil)
--   inspecteur_update_email_v2(p_token, p_email)
--
-- DIFFÉRENCES AVEC LA PRODUCTION (et seulement celles-ci) :
--   1. Authentification : p_inspecteur_id / p_id / p_expediteur_id et
--      p_password disparaissent. La fiche est celle du jeton :
--      v_id := _session_user(p_token, 'inspecteur'), appelée EN PREMIER, qui
--      lève SESSION_INVALIDE (P0401) si le jeton est inconnu, expiré,
--      révoqué, d'un autre rôle, si la fiche n'existe plus ou si elle est
--      bannie. Le prédicat "id = p_inspecteur_id and password =
--      extensions.crypt(...)" devient "id = v_id". Les contrôles existants
--      (not found, banni) sont CONSERVÉS tels quels, même s'ils sont devenus
--      redondants avec _session_user.
--   2. post_message_v2 : la production contrôlait p_type et le type de pièce
--      jointe AVANT le mot de passe. _session_user passe désormais en premier :
--      un jeton invalide lève toujours P0401 ; le résultat métier (false) est
--      inchangé pour un jeton valide.
--   3. SET search_path TO 'public' ajouté partout (absent en production sur
--      post_private_message, list_private_messages et mark_private_read).
--   4. update_email_v2 : une violation de l'index unique
--      inspecteurs_email_unique (SQLSTATE 23505, nom lu par GET STACKED
--      DIAGNOSTICS) est transformée en exception 'EMAIL_DEJA_UTILISE', comme
--      eleve_update_email / etablissement_update_info_v2. Toute autre
--      violation est relancée telle quelle. (Écart validé, Q11.)
--   Le reste de chaque corps est recopié à l'identique (valeurs de retour,
--   format des id générés, format des dates, nom affiché de l'auteur).
--
-- COMPORTEMENTS EXISTANTS CONSERVÉS VOLONTAIREMENT (à revoir en Phase 8) :
--   - post_message : p_type NULL passe le contrôle (NULL NOT IN -> NULL) et
--     le message est enregistré avec type NULL ; aucune limite de longueur ;
--     p_reply_to non vérifié (id inexistant accepté).
--   - post_private_message : message à soi-même accepté ; type de pièce
--     jointe NON contrôlé (contrairement au chat de groupe) ; texte vide sans
--     pièce jointe accepté ; aucune limite de longueur.
--   - list_private_messages / mark_private_read : ne refusaient pas le banni
--     (désormais refusé par _session_user) ; mark_private_read renvoie true
--     même si aucun message n'était à marquer.
--   - request_certification : acceptée même si le compte est déjà certifié
--     ou a déjà une demande en cours.
--   - update_avatar : URL non contrôlée (NULL ou vide acceptés).
--   - update_message_accueil : aucune limite de longueur côté SQL (le front
--     limite à 200 caractères).
--   - update_email : aucune validation (vide, NULL, format libre acceptés ;
--     pas de trim) ; ne refusait pas le banni.
--
-- Droits : SECURITY DEFINER, SET search_path TO 'public', REVOKE ALL FROM
-- public, GRANT EXECUTE TO anon, authenticated (comme les *_v2 précédentes).
-- Rejouable : CREATE OR REPLACE.
-- À exécuter en une fois dans l'éditeur SQL de Supabase.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 0) Garde-fous : 7a-1 exécutée
-- ------------------------------------------------------------
DO $$
begin
  if to_regprocedure('public._session_user(text,text)') is null then
    raise exception '_session_user absente : exécuter d''abord la Phase 1';
  end if;
  if to_regprocedure('public.inspecteur_session_open(text,text)') is null then
    raise exception 'inspecteur_session_open absente : exécuter d''abord la migration 7a-1';
  end if;
  if not exists (select 1 from pg_trigger t
                 where t.tgrelid = 'public.inspecteurs'::regclass
                   and t.tgname = 'trg_inspecteurs_revoke_sessions') then
    raise exception 'trigger trg_inspecteurs_revoke_sessions absent : exécuter d''abord la migration 7a-1';
  end if;
end $$;

-- ------------------------------------------------------------
-- 1) inspecteur_post_message_v2 (production : inspecteur_post_message)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_post_message_v2(p_token text, p_texte text, p_type text DEFAULT 'C'::text, p_reply_to text DEFAULT NULL::text, p_attachment_url text DEFAULT NULL::text, p_attachment_type text DEFAULT NULL::text, p_attachment_name text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id text; v_insp record;
begin
  v_id := _session_user(p_token, 'inspecteur');
  if p_type not in ('A','C') then return false; end if;
  if p_attachment_type is not null and p_attachment_type not in ('image','pdf') then return false; end if;
  select * into v_insp from inspecteurs where id = v_id;
  if not found or coalesce(v_insp.banni, false) then return false; end if;
  if length(trim(coalesce(p_texte,''))) = 0 and p_attachment_url is null then return false; end if;

  insert into messages_inspecteurs(id, inspecteur_id, inspecteur_nom, texte, date, type, auteur_role, reply_to, attachment_url, attachment_type, attachment_name)
    values ('id' || extract(epoch from clock_timestamp())::bigint::text || floor(random()*1000000)::text,
            v_insp.id, trim(v_insp.nom || ' ' || coalesce(v_insp.prenoms,'')), p_texte, to_char(now(),'DD/MM/YYYY HH24:MI'), p_type, 'inspecteur', p_reply_to, p_attachment_url, p_attachment_type, p_attachment_name);
  return true;
end; $function$;

REVOKE ALL ON FUNCTION public.inspecteur_post_message_v2(text, text, text, text, text, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_post_message_v2(text, text, text, text, text, text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 2) inspecteur_post_private_message_v2 (production : inspecteur_post_private_message)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_post_private_message_v2(p_token text, p_destinataire_id text, p_texte text, p_attachment_url text DEFAULT NULL::text, p_attachment_type text DEFAULT NULL::text, p_attachment_name text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id text;
  v_ok boolean;
begin
  v_id := _session_user(p_token, 'inspecteur');
  select exists(
    select 1 from inspecteurs where id = v_id and coalesce(banni,false) = false
  ) into v_ok;
  if not v_ok then return false; end if;

  if not exists(select 1 from inspecteurs where id = p_destinataire_id and coalesce(banni,false) = false) then
    return false;
  end if;

  insert into messages_prives(id, expediteur_id, destinataire_id, texte, date, attachment_url, attachment_type, attachment_name)
  values (
    'msg' || substr(md5(random()::text || clock_timestamp()::text), 1, 16),
    v_id, p_destinataire_id, p_texte,
    to_char(now(), 'DD/MM/YYYY HH24:MI'),
    p_attachment_url, p_attachment_type, p_attachment_name
  );
  return true;
end;
$function$;

REVOKE ALL ON FUNCTION public.inspecteur_post_private_message_v2(text, text, text, text, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_post_private_message_v2(text, text, text, text, text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 3) inspecteur_list_private_messages_v2 (production : inspecteur_list_private_messages)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_list_private_messages_v2(p_token text)
 RETURNS SETOF messages_prives
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id text;
begin
  v_id := _session_user(p_token, 'inspecteur');
  if not exists(select 1 from inspecteurs where id = v_id) then
    return;
  end if;
  return query
    select * from messages_prives
    where expediteur_id = v_id or destinataire_id = v_id
    order by created_at asc;
end;
$function$;

REVOKE ALL ON FUNCTION public.inspecteur_list_private_messages_v2(text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_list_private_messages_v2(text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 4) inspecteur_mark_private_read_v2 (production : inspecteur_mark_private_read)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_mark_private_read_v2(p_token text, p_autre_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id text;
begin
  v_id := _session_user(p_token, 'inspecteur');
  if not exists(select 1 from inspecteurs where id = v_id) then
    return false;
  end if;
  update messages_prives set lu = true
  where destinataire_id = v_id and expediteur_id = p_autre_id and lu = false;
  return true;
end;
$function$;

REVOKE ALL ON FUNCTION public.inspecteur_mark_private_read_v2(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_mark_private_read_v2(text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 5) inspecteur_request_certification_v2 (production : inspecteur_request_certification)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_request_certification_v2(p_token text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id text; v_insp record;
begin
  v_id := _session_user(p_token, 'inspecteur');
  select * into v_insp from inspecteurs where id = v_id;
  if not found or coalesce(v_insp.banni, false) then return false; end if;
  update inspecteurs set certification_demandee = true where id = v_id;
  return true;
end; $function$;

REVOKE ALL ON FUNCTION public.inspecteur_request_certification_v2(text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_request_certification_v2(text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 6) inspecteur_update_avatar_v2 (production : inspecteur_update_avatar)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_update_avatar_v2(p_token text, p_avatar_url text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id text; v_insp record;
begin
  v_id := _session_user(p_token, 'inspecteur');
  select * into v_insp from inspecteurs where id = v_id;
  if not found or coalesce(v_insp.banni, false) then return false; end if;
  update inspecteurs set avatar_url = p_avatar_url where id = v_id;
  return true;
end; $function$;

REVOKE ALL ON FUNCTION public.inspecteur_update_avatar_v2(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_update_avatar_v2(text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 7) inspecteur_update_message_accueil_v2 (production : inspecteur_update_message_accueil)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_update_message_accueil_v2(p_token text, p_message_accueil text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id text; v_insp record;
begin
  v_id := _session_user(p_token, 'inspecteur');
  select * into v_insp from inspecteurs where id = v_id;
  if not found or coalesce(v_insp.banni, false) then return false; end if;
  update inspecteurs set message_accueil = p_message_accueil where id = v_id;
  return true;
end; $function$;

REVOKE ALL ON FUNCTION public.inspecteur_update_message_accueil_v2(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_update_message_accueil_v2(text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 8) inspecteur_update_email_v2 (production : inspecteur_update_email)
-- ------------------------------------------------------------
-- Lève EMAIL_DEJA_UTILISE si un autre inspecteur porte déjà cet e-mail
-- (index inspecteurs_email_unique, insensible à la casse et aux espaces).
CREATE OR REPLACE FUNCTION public.inspecteur_update_email_v2(p_token text, p_email text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id text;
  v_found boolean;
  v_contrainte text;
begin
  v_id := _session_user(p_token, 'inspecteur');
  begin
    update inspecteurs set email = p_email where id = v_id;
    v_found := found;
  exception when unique_violation then
    get stacked diagnostics v_contrainte = constraint_name;
    if v_contrainte = 'inspecteurs_email_unique' then
      raise exception 'EMAIL_DEJA_UTILISE';
    end if;
    raise;
  end;
  return v_found;
end; $function$;

REVOKE ALL ON FUNCTION public.inspecteur_update_email_v2(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_update_email_v2(text, text) TO anon, authenticated;

COMMIT;

-- ============================================================
-- VÉRIFICATIONS (à lancer après exécution, une requête à la fois)
-- ============================================================
--
-- V1. Les 8 fonctions _v2 : security_definer = true, config = {search_path=public},
--     anon = true, authenticated = true, sans_crypt = true, appelle_session_user = true
-- select p.oid::regprocedure as fonction, p.prosecdef as security_definer, p.proconfig as config,
--        has_function_privilege('anon', p.oid, 'EXECUTE') as anon,
--        has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated,
--        p.prosrc not like '%crypt%' as sans_crypt,
--        p.prosrc like '%_session_user(p_token, ''inspecteur'')%' as appelle_session_user
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('inspecteur_post_message_v2', 'inspecteur_post_private_message_v2',
--                     'inspecteur_list_private_messages_v2', 'inspecteur_mark_private_read_v2',
--                     'inspecteur_request_certification_v2', 'inspecteur_update_avatar_v2',
--                     'inspecteur_update_message_accueil_v2', 'inspecteur_update_email_v2')
-- order by 1;
--     Attendu : 8 lignes, une seule signature par fonction.
--
-- V2. Aucune _v2 ne prend de mot de passe ni d'id d'inspecteur (0 ligne attendue)
-- select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public' and p.proname like 'inspecteur\_%\_v2'
--   and (pg_get_function_identity_arguments(p.oid) ~ 'p_password|p_inspecteur_id|p_expediteur_id|p_id ');
--
-- V3. Anciennes fonctions toujours présentes : 8 lignes attendues (+ inspecteur_login = 9)
-- select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('inspecteur_post_message', 'inspecteur_post_private_message',
--                     'inspecteur_list_private_messages', 'inspecteur_mark_private_read',
--                     'inspecteur_request_certification', 'inspecteur_update_avatar',
--                     'inspecteur_update_message_accueil', 'inspecteur_update_email',
--                     'inspecteur_login')
-- order by 1;
--
-- V4. Comparaison des corps : chaque ancienne fonction suivie de sa _v2 (16 lignes).
--     Différences attendues UNIQUEMENT : l'authentification (_session_user / v_id à
--     la place de l'id + crypt), l'ordre jeton/contrôles de post_message, le
--     search_path, et le bloc EMAIL_DEJA_UTILISE de update_email.
-- select p.oid::regprocedure as fonction, pg_get_functiondef(p.oid) as definition
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and regexp_replace(p.proname, '_v2$', '') in (
--     'inspecteur_post_message', 'inspecteur_post_private_message',
--     'inspecteur_list_private_messages', 'inspecteur_mark_private_read',
--     'inspecteur_request_certification', 'inspecteur_update_avatar',
--     'inspecteur_update_message_accueil', 'inspecteur_update_email')
-- order by regexp_replace(p.proname, '_v2$', ''), p.proname;
--
-- V5. Test fonctionnel complet SANS trace : fichier séparé 7a-2a-tests-rollback.sql,
--     puis sa requête V-trace.
