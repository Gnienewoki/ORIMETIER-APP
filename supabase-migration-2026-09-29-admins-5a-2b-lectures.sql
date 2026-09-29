-- ============================================================
-- ORIMETIER — Phase 5a-2b : RPC admin par jeton (lectures seules).
--
-- Pré-requis : 5a-1 exécutée (admin_session_open, branche 'admin' de
-- _session_user). Migration ADDITIVE : les anciennes fonctions
-- (p_admin_password) restent en service jusqu'en 5c.
--
-- Nouvelles fonctions (suffixe _v2), toutes en LECTURE SEULE :
--   admin_get_visite_stats_v2                         (live l. 144-161)
--   admin_list_etablissements_full_v2                 (live l. 245-267)
--   admin_list_demandes_inscription_etablissements_v2 (live l. 221-243)
--   admin_list_unclaimed_codes_v2                     (live l. 269-286)
--   admin_list_all_etablissement_codes_v2             (live l. 201-219)
-- Écrites à partir de supabase/reference/live-2026-09-26.sql. Seule la
-- ligne d'authentification change : la vérification admin_config est
-- remplacée par _session_user(p_token, 'admin'), qui lève SESSION_INVALIDE
-- (P0401) si le jeton est invalide, expiré, révoqué, ou si l'admin est
-- désactivé. Types de retour (RETURNS TABLE) identiques au live.
--
-- Piège RETURNS TABLE(id ...) : dans une fonction plpgsql, les colonnes
-- renvoyées sont aussi des variables ; toute colonne non qualifiée dans une
-- requête peut devenir ambiguë. Toutes les colonnes sont donc qualifiées
-- par un alias de table. Seul écart de texte avec le live :
--   admin_get_visite_stats_v2 : "order by jour desc" (nom de colonne de
--   sortie, qui est aussi une variable OUT) devient
--   "order by v.visited_at::date desc" — même tri, sans ambiguïté possible.
--   Le test V3 vérifie que l'ordre des lignes est identique à l'ancienne
--   version.
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
-- 1) admin_get_visite_stats_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_get_visite_stats_v2(p_token text)
 RETURNS TABLE(page text, jour date, visites bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');

  return query
    select v.page, v.visited_at::date as jour, count(*)::bigint as visites
    from visites v
    group by v.page, v.visited_at::date
    order by v.visited_at::date desc, v.page asc;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_get_visite_stats_v2(text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_get_visite_stats_v2(text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 2) admin_list_etablissements_full_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_list_etablissements_full_v2(p_token text)
 RETURNS TABLE(id text, nom text, region text, ville text, quartier text, type text, responsable text, contact_tel text, email text, tel text, tel2 text, tel3 text, site_web text, statut text, active boolean, date_inscription text, filieres_proposees jsonb, photos jsonb, logo_url text, categorie text, sous_categorie text, secteur text, pre_inscrit boolean, reclame boolean, premium boolean, demande_premium boolean, demande_premium_date text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');

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

REVOKE ALL ON FUNCTION public.admin_list_etablissements_full_v2(text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_list_etablissements_full_v2(text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 3) admin_list_demandes_inscription_etablissements_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_list_demandes_inscription_etablissements_v2(p_token text)
 RETURNS TABLE(id text, nom text, region text, ville text, quartier text, type text, responsable text, tel text, tel2 text, tel3 text, email text, site_web text, contact_tel text, date_inscription text, filieres_proposees jsonb, photos jsonb, logo_url text, categorie text, sous_categorie text, secteur text, date_demande text, statut_demande text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');

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

REVOKE ALL ON FUNCTION public.admin_list_demandes_inscription_etablissements_v2(text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_list_demandes_inscription_etablissements_v2(text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 4) admin_list_unclaimed_codes_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_list_unclaimed_codes_v2(p_token text)
 RETURNS TABLE(id text, nom text, region text, ville text, quartier text, categorie text, sous_categorie text, secteur text, code_recuperation text, date_inscription text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');

  return query
    select e.id, e.nom, e.region, e.ville, e.quartier, e.categorie, e.sous_categorie, e.secteur, e.code_recuperation, e.date_inscription
    from etablissements e
    where e.pre_inscrit = true and e.reclame = false
    order by e.categorie, e.secteur, e.region, e.nom;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_list_unclaimed_codes_v2(text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_list_unclaimed_codes_v2(text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 5) admin_list_all_etablissement_codes_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_list_all_etablissement_codes_v2(p_token text)
 RETURNS TABLE(nom text, categorie text, sous_categorie text, ville text, secteur text, code_recuperation text, reclame boolean, date_inscription text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');

  return query
    select e.nom, e.categorie, e.sous_categorie, e.ville, e.secteur, e.code_recuperation, e.reclame, e.date_inscription
    from etablissements e
    where e.pre_inscrit = true and e.code_recuperation is not null
    order by e.nom;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_list_all_etablissement_codes_v2(text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_list_all_etablissement_codes_v2(text) TO anon, authenticated;

COMMIT;

-- ============================================================
-- VÉRIFICATIONS (à lancer après exécution, une requête à la fois)
-- ============================================================
--
-- V1. Anciennes ET nouvelles fonctions présentes (10 lignes attendues)
-- select p.proname, pg_get_function_identity_arguments(p.oid) as args
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('admin_get_visite_stats', 'admin_get_visite_stats_v2',
--                     'admin_list_etablissements_full', 'admin_list_etablissements_full_v2',
--                     'admin_list_demandes_inscription_etablissements', 'admin_list_demandes_inscription_etablissements_v2',
--                     'admin_list_unclaimed_codes', 'admin_list_unclaimed_codes_v2',
--                     'admin_list_all_etablissement_codes', 'admin_list_all_etablissement_codes_v2')
-- order by 1, 2;
--
-- V2. Sécurité des 5 nouvelles fonctions (5 lignes :
--     security_definer = true, config = {search_path=public}, anon = true, authenticated = true)
-- select p.oid::regprocedure as fonction, p.prosecdef as security_definer, p.proconfig as config,
--        has_function_privilege('anon', p.oid, 'EXECUTE') as anon,
--        has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('admin_get_visite_stats_v2', 'admin_list_etablissements_full_v2',
--                     'admin_list_demandes_inscription_etablissements_v2',
--                     'admin_list_unclaimed_codes_v2', 'admin_list_all_etablissement_codes_v2')
-- order by 1;
--
-- V3. Test fonctionnel complet SANS trace : fichier séparé
--     test-5a2b-v3.sql (bloc prêt à coller, ROLLBACK final).
--
-- V4. Aucune trace laissée par V3 (attendu : admin_test = 0, sessions_test = 0,
--     meme_hash = true — le mot de passe de admin_config, modifié
--     temporairement par V3, est bien revenu à l'identique de admins)
-- select (select count(*) from public.admins where id = 'adm_test') as admin_test,
--        (select count(*) from public.sessions where user_id = 'adm_test') as sessions_test,
--        (select a.password = ac.admin_password
--           from public.admins a cross join public.admin_config ac
--          where a.id = 'adm_gnienewoki' and ac.id = 1) as meme_hash;
