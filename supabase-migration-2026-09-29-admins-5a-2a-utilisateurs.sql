-- ============================================================
-- ORIMETIER — Phase 5a-2a : RPC admin par jeton (utilisateurs & messagerie).
--
-- Pré-requis : 5a-1 exécutée (admin_session_open, branche 'admin' de
-- _session_user). Migration ADDITIVE : les anciennes fonctions
-- (p_admin_password) restent en service jusqu'en 5c.
--
-- Nouvelles fonctions (suffixe _v2) :
--   admin_set_eleve_banni_v2         (live l. 369-380)
--   admin_set_inspecteur_banni_v2    (live l. 426-437)
--   admin_set_inspecteur_certifie_v2 (live l. 439-452)
--   admin_post_message_v2            (live l. 313-330)
--   admin_delete_message_v2          (live l. 131-142)
-- Écrites à partir de supabase/reference/live-2026-09-26.sql. Seule la
-- ligne d'authentification change : la vérification admin_config est
-- remplacée par _session_user(p_token, 'admin'), qui lève SESSION_INVALIDE
-- (P0401) si le jeton est invalide, expiré, révoqué, ou si l'admin est
-- désactivé. Le reste du corps est identique.
--
-- Pourquoi un nouveau nom (_v2) : (p_admin_password text, …) et
-- (p_token text, …) ont la MÊME liste de types ; PostgreSQL ne peut pas
-- garder les deux sous le même nom, et CREATE OR REPLACE refuse de
-- renommer un paramètre.
--
-- À exécuter en une fois dans l'éditeur SQL de Supabase.
-- ============================================================

BEGIN;

-- Garde-fou : 5a-1 doit avoir été exécutée.
DO $$
begin
  if to_regprocedure('public.admin_session_open(text,text)') is null then
    raise exception 'admin_session_open absente : exécuter d''abord la migration 5a-1';
  end if;
end $$;

-- ------------------------------------------------------------
-- 1) admin_set_eleve_banni_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_eleve_banni_v2(p_token text, p_eleve_id text, p_banni boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');
  update eleves set banni = p_banni where id = p_eleve_id;
  return found;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_set_eleve_banni_v2(text, text, boolean) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_set_eleve_banni_v2(text, text, boolean) TO anon, authenticated;

-- ------------------------------------------------------------
-- 2) admin_set_inspecteur_banni_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_inspecteur_banni_v2(p_token text, p_inspecteur_id text, p_banni boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');
  update inspecteurs set banni = p_banni where id = p_inspecteur_id;
  return found;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_set_inspecteur_banni_v2(text, text, boolean) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_set_inspecteur_banni_v2(text, text, boolean) TO anon, authenticated;

-- ------------------------------------------------------------
-- 3) admin_set_inspecteur_certifie_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_inspecteur_certifie_v2(p_token text, p_inspecteur_id text, p_certifie boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');
  update inspecteurs set certifie = p_certifie,
    certification_demandee = case when p_certifie then false else certification_demandee end
  where id = p_inspecteur_id;
  return found;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_set_inspecteur_certifie_v2(text, text, boolean) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_set_inspecteur_certifie_v2(text, text, boolean) TO anon, authenticated;

-- ------------------------------------------------------------
-- 4) admin_post_message_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_post_message_v2(p_token text, p_texte text, p_type text DEFAULT 'O'::text, p_reply_to text DEFAULT NULL::text, p_attachment_url text DEFAULT NULL::text, p_attachment_type text DEFAULT NULL::text, p_attachment_name text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');
  if p_type not in ('O','C') then return false; end if;
  if p_attachment_type is not null and p_attachment_type not in ('image','pdf') then return false; end if;
  if length(trim(coalesce(p_texte,''))) = 0 and p_attachment_url is null then return false; end if;

  insert into messages_inspecteurs(id, inspecteur_id, inspecteur_nom, texte, date, type, auteur_role, reply_to, attachment_url, attachment_type, attachment_name)
    values ('id' || extract(epoch from clock_timestamp())::bigint::text || floor(random()*1000000)::text,
            null, 'Administration ORIMETIER', p_texte, to_char(now(),'DD/MM/YYYY HH24:MI'), p_type, 'admin', p_reply_to, p_attachment_url, p_attachment_type, p_attachment_name);
  return true;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_post_message_v2(text, text, text, text, text, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_post_message_v2(text, text, text, text, text, text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 5) admin_delete_message_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_delete_message_v2(p_token text, p_message_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');
  delete from messages_inspecteurs where id = p_message_id;
  return found;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_delete_message_v2(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_delete_message_v2(text, text) TO anon, authenticated;

COMMIT;

-- ============================================================
-- VÉRIFICATIONS (à lancer après exécution, une requête à la fois)
-- ============================================================
--
-- V1. Anciennes ET nouvelles fonctions présentes (10 lignes attendues)
-- select p.proname, pg_get_function_identity_arguments(p.oid) as args
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('admin_set_eleve_banni', 'admin_set_eleve_banni_v2',
--                     'admin_set_inspecteur_banni', 'admin_set_inspecteur_banni_v2',
--                     'admin_set_inspecteur_certifie', 'admin_set_inspecteur_certifie_v2',
--                     'admin_post_message', 'admin_post_message_v2',
--                     'admin_delete_message', 'admin_delete_message_v2')
-- order by 1, 2;
--
-- V2. Sécurité des nouvelles fonctions _v2
--     (security_definer = true, config = {search_path=public}, anon = true, authenticated = true)
-- select p.oid::regprocedure as fonction, p.prosecdef as security_definer, p.proconfig as config,
--        has_function_privilege('anon', p.oid, 'EXECUTE') as anon,
--        has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public' and p.proname like 'admin\_%\_v2' escape '\'
-- order by 1;
--
-- V3. Test fonctionnel complet SANS trace, avec un admin temporaire.
--     Utilise le premier élève et le premier inspecteur existants (leur état
--     est modifié puis annulé par le ROLLBACK final). Il faut au moins un
--     élève et un inspecteur en base.
--     Sélectionner et exécuter le bloc ENTIER d'un coup.
--     Succès : la dernière requête affiche "TESTS 5a-2a OK".
--     Échec : une erreur "ÉCHEC ..." indique le test fautif.
-- begin;
-- insert into public.admins(id, nom, email, password)
--   values ('adm_test', 'Admin Test', 'test-5a2@exemple.invalid', 'mdp-test-5a2');
-- do $$
-- declare
--   t text; v_eleve text; v_insp text; v_msg text;
--   v_ancien_banni boolean;
-- begin
--   t := public.admin_session_open('test-5a2@exemple.invalid', 'mdp-test-5a2')->>'token';
--   if t is null then raise exception 'ÉCHEC ouverture de session'; end if;
--   select e.id, coalesce(e.banni, false) into v_eleve, v_ancien_banni from public.eleves e order by e.id limit 1;
--   select i.id into v_insp from public.inspecteurs i order by i.id limit 1;
--   if v_eleve is null or v_insp is null then raise exception 'ÉCHEC pas d''élève ou d''inspecteur pour tester'; end if;
--
--   -- 1) admin_set_eleve_banni_v2
--   if public.admin_set_eleve_banni_v2(t, v_eleve, not v_ancien_banni) is not true then raise exception 'ÉCHEC set_eleve_banni'; end if;
--   if (select coalesce(e.banni, false) from public.eleves e where e.id = v_eleve) = v_ancien_banni then raise exception 'ÉCHEC set_eleve_banni sans effet'; end if;
--   if public.admin_set_eleve_banni_v2(t, 'test_5a2_inexistant', true) is not false then raise exception 'ÉCHEC set_eleve_banni id inconnu'; end if;
--
--   -- 2) admin_set_inspecteur_banni_v2
--   if public.admin_set_inspecteur_banni_v2(t, v_insp, true) is not true then raise exception 'ÉCHEC set_inspecteur_banni'; end if;
--   if (select i.banni from public.inspecteurs i where i.id = v_insp) is not true then raise exception 'ÉCHEC set_inspecteur_banni sans effet'; end if;
--   if public.admin_set_inspecteur_banni_v2(t, 'test_5a2_inexistant', true) is not false then raise exception 'ÉCHEC set_inspecteur_banni id inconnu'; end if;
--
--   -- 3) admin_set_inspecteur_certifie_v2 (certifier remet certification_demandee à false,
--   --    décertifier n'y touche pas)
--   update public.inspecteurs set certification_demandee = true where id = v_insp;
--   if public.admin_set_inspecteur_certifie_v2(t, v_insp, true) is not true then raise exception 'ÉCHEC set_inspecteur_certifie'; end if;
--   if (select i.certifie is true and i.certification_demandee is false from public.inspecteurs i where i.id = v_insp) is not true then raise exception 'ÉCHEC set_inspecteur_certifie sans effet'; end if;
--   update public.inspecteurs set certification_demandee = true where id = v_insp;
--   if public.admin_set_inspecteur_certifie_v2(t, v_insp, false) is not true then raise exception 'ÉCHEC décertification'; end if;
--   if (select i.certifie is false and i.certification_demandee is true from public.inspecteurs i where i.id = v_insp) is not true then raise exception 'ÉCHEC décertification : certification_demandee modifiée'; end if;
--
--   -- 4) admin_post_message_v2 (valeurs par défaut + règles métier)
--   if public.admin_post_message_v2(t, 'test_5a2_message') is not true then raise exception 'ÉCHEC post_message'; end if;
--   select m.id into v_msg from public.messages_inspecteurs m where m.texte = 'test_5a2_message' and m.auteur_role = 'admin' and m.type = 'O';
--   if v_msg is null then raise exception 'ÉCHEC post_message : message introuvable'; end if;
--   if public.admin_post_message_v2(t, 'x', 'Z') is not false then raise exception 'ÉCHEC post_message type invalide accepté'; end if;
--   if public.admin_post_message_v2(t, 'x', 'O', null, 'http://x', 'zip') is not false then raise exception 'ÉCHEC post_message pièce jointe invalide acceptée'; end if;
--   if public.admin_post_message_v2(t, '   ') is not false then raise exception 'ÉCHEC post_message vide accepté'; end if;
--
--   -- 5) admin_delete_message_v2
--   if public.admin_delete_message_v2(t, v_msg) is not true then raise exception 'ÉCHEC delete_message'; end if;
--   if exists (select 1 from public.messages_inspecteurs m where m.id = v_msg) then raise exception 'ÉCHEC delete_message sans effet'; end if;
--   if public.admin_delete_message_v2(t, v_msg) is not false then raise exception 'ÉCHEC delete_message id inconnu'; end if;
--
--   -- Jeton bidon : les 5 fonctions doivent lever SESSION_INVALIDE (P0401)
--   begin perform public.admin_set_eleve_banni_v2('x', v_eleve, true); raise exception 'ÉCHEC jeton bidon accepté (set_eleve_banni)'; exception when sqlstate 'P0401' then null; end;
--   begin perform public.admin_set_inspecteur_banni_v2('x', v_insp, true); raise exception 'ÉCHEC jeton bidon accepté (set_inspecteur_banni)'; exception when sqlstate 'P0401' then null; end;
--   begin perform public.admin_set_inspecteur_certifie_v2('x', v_insp, true); raise exception 'ÉCHEC jeton bidon accepté (set_inspecteur_certifie)'; exception when sqlstate 'P0401' then null; end;
--   begin perform public.admin_post_message_v2('x', 'test_5a2_intrus'); raise exception 'ÉCHEC jeton bidon accepté (post_message)'; exception when sqlstate 'P0401' then null; end;
--   begin perform public.admin_delete_message_v2('x', 'test_5a2_inexistant'); raise exception 'ÉCHEC jeton bidon accepté (delete_message)'; exception when sqlstate 'P0401' then null; end;
--   -- Jeton null refusé
--   begin perform public.admin_set_eleve_banni_v2(null, v_eleve, true); raise exception 'ÉCHEC jeton null accepté'; exception when sqlstate 'P0401' then null; end;
--
--   -- Jeton expiré (created_at reculé aussi : contrainte expires_at > created_at)
--   update public.sessions s set created_at = now() - interval '2 days', expires_at = now() - interval '1 second'
--     where s.token_hash = encode(extensions.digest(t, 'sha256'), 'hex');
--   begin perform public.admin_set_eleve_banni_v2(t, v_eleve, true); raise exception 'ÉCHEC jeton expiré accepté'; exception when sqlstate 'P0401' then null; end;
--
--   -- Jeton révoqué (déconnexion)
--   t := public.admin_session_open('test-5a2@exemple.invalid', 'mdp-test-5a2')->>'token';
--   perform public.session_close(t);
--   begin perform public.admin_set_eleve_banni_v2(t, v_eleve, true); raise exception 'ÉCHEC jeton révoqué accepté'; exception when sqlstate 'P0401' then null; end;
--
--   -- Admin désactivé
--   t := public.admin_session_open('test-5a2@exemple.invalid', 'mdp-test-5a2')->>'token';
--   update public.admins set actif = false where id = 'adm_test';
--   begin perform public.admin_set_eleve_banni_v2(t, v_eleve, true); raise exception 'ÉCHEC admin désactivé accepté'; exception when sqlstate 'P0401' then null; end;
--
--   -- Aucun message intrus n'a été créé par les appels refusés
--   if exists (select 1 from public.messages_inspecteurs m where m.texte = 'test_5a2_intrus') then raise exception 'ÉCHEC message créé avec un jeton bidon'; end if;
-- end $$;
-- select 'TESTS 5a-2a OK' as resultat;
-- rollback;
--
-- V4. Aucune trace laissée par V3 (0, 0 et 0 attendus)
-- select (select count(*) from public.admins where id = 'adm_test') as admin_test,
--        (select count(*) from public.sessions where user_id = 'adm_test') as sessions_test,
--        (select count(*) from public.messages_inspecteurs where texte like 'test_5a2_%') as messages_test;
--
-- V5. Non-régression (manuel) : dans l'application, espace admin actuel
--     (anciennes fonctions) : bannir/débannir un élève, certifier un
--     inspecteur, poster puis supprimer un message → tout fonctionne comme avant.
