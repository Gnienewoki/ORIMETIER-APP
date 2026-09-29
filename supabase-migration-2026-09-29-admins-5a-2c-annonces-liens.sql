-- ============================================================
-- ORIMETIER — Phase 5a-2c : RPC admin par jeton (annonces & liens de formation).
--
-- Pré-requis : 5a-1 exécutée (admin_session_open, branche 'admin' de
-- _session_user). Migration ADDITIVE : les anciennes fonctions
-- (p_admin_password) restent en service jusqu'en 5c.
--
-- Nouvelles fonctions (suffixe _v2) :
--   admin_upsert_annonce_v2         (live l. 484-512)
--   admin_set_annonce_active_v2     (live l. 349-367)
--   admin_supprimer_annonce_v2      (live l. 454-465)
--   admin_upsert_lien_formation_v2  (live l. 514-537)
--   admin_delete_lien_formation_v2  (live l. 118-129)
-- Écrites à partir de supabase/reference/live-2026-09-26.sql. Seule la
-- ligne d'authentification change : la vérification admin_config est
-- remplacée par _session_user(p_token, 'admin'), qui lève SESSION_INVALIDE
-- (P0401) si le jeton est invalide, expiré, révoqué, ou si l'admin est
-- désactivé. Le reste du corps est identique, règles métier comprises :
--   - au plus 5 annonces actives (création et réactivation) ;
--   - annonce de type 'texte' (texte non vide) ou 'image' (URL non vide) ;
--   - seule une annonce INACTIVE peut être supprimée ;
--   - lien : audience inspecteur/eleve/etudiant/tous, titre et URL non vides.
-- Aucune de ces fonctions ne renvoie de RETURNS TABLE : pas de piège
-- d'ambiguïté sur les noms de colonnes.
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
-- 1) admin_upsert_annonce_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_upsert_annonce_v2(p_token text, p_id integer, p_type text, p_texte text, p_image_url text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id int;
begin
  perform _session_user(p_token, 'admin');
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

REVOKE ALL ON FUNCTION public.admin_upsert_annonce_v2(text, integer, text, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_upsert_annonce_v2(text, integer, text, text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 2) admin_set_annonce_active_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_annonce_active_v2(p_token text, p_id integer, p_active boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');

  if p_active then
    if (select count(*) from annonce where active = true and id <> p_id) >= 5 then
      return false;
    end if;
  end if;

  update annonce set active = p_active, updated_at = now() where id = p_id;
  return found;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_set_annonce_active_v2(text, integer, boolean) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_set_annonce_active_v2(text, integer, boolean) TO anon, authenticated;

-- ------------------------------------------------------------
-- 3) admin_supprimer_annonce_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_supprimer_annonce_v2(p_token text, p_id integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');
  delete from annonce where id = p_id and active = false;
  return found;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_supprimer_annonce_v2(text, integer) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_supprimer_annonce_v2(text, integer) TO anon, authenticated;

-- ------------------------------------------------------------
-- 4) admin_upsert_lien_formation_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_upsert_lien_formation_v2(p_token text, p_id bigint, p_titre text, p_description text, p_url text, p_audience text, p_ordre integer DEFAULT NULL::integer)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id bigint;
begin
  perform _session_user(p_token, 'admin');
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

REVOKE ALL ON FUNCTION public.admin_upsert_lien_formation_v2(text, bigint, text, text, text, text, integer) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_upsert_lien_formation_v2(text, bigint, text, text, text, text, integer) TO anon, authenticated;

-- ------------------------------------------------------------
-- 5) admin_delete_lien_formation_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_delete_lien_formation_v2(p_token text, p_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');
  delete from liens_formation where id = p_id;
  return found;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_delete_lien_formation_v2(text, bigint) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_delete_lien_formation_v2(text, bigint) TO anon, authenticated;

COMMIT;

-- ============================================================
-- VÉRIFICATIONS (à lancer après exécution, une requête à la fois)
-- ============================================================
--
-- V1. Anciennes ET nouvelles fonctions présentes (10 lignes attendues)
-- select p.proname, pg_get_function_identity_arguments(p.oid) as args
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('admin_upsert_annonce', 'admin_upsert_annonce_v2',
--                     'admin_set_annonce_active', 'admin_set_annonce_active_v2',
--                     'admin_supprimer_annonce', 'admin_supprimer_annonce_v2',
--                     'admin_upsert_lien_formation', 'admin_upsert_lien_formation_v2',
--                     'admin_delete_lien_formation', 'admin_delete_lien_formation_v2')
-- order by 1, 2;
--
-- V2. Sécurité des 5 nouvelles fonctions (5 lignes :
--     security_definer = true, config = {search_path=public}, anon = true, authenticated = true)
-- select p.oid::regprocedure as fonction, p.prosecdef as security_definer, p.proconfig as config,
--        has_function_privilege('anon', p.oid, 'EXECUTE') as anon,
--        has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('admin_upsert_annonce_v2', 'admin_set_annonce_active_v2',
--                     'admin_supprimer_annonce_v2', 'admin_upsert_lien_formation_v2',
--                     'admin_delete_lien_formation_v2')
-- order by 1;
--
-- V3. Test fonctionnel complet SANS trace : fichier séparé
--     test-5a2c-v3.sql (bloc prêt à coller, ROLLBACK final).
--
-- V4. Aucune trace laissée par V3 (0, 0, 0 et 0 attendus)
-- select (select count(*) from public.admins where id = 'adm_test') as admin_test,
--        (select count(*) from public.sessions where user_id = 'adm_test') as sessions_test,
--        (select count(*) from public.annonce where texte like 'test_5a2c%') as annonces_test,
--        (select count(*) from public.liens_formation where titre like 'test_5a2c%') as liens_test;
--
-- V5. Non-régression (manuel) : dans l'application, espace admin actuel
--     (anciennes fonctions) : les annonces actives s'affichent toujours
--     comme avant le test (aucune n'a été désactivée).
