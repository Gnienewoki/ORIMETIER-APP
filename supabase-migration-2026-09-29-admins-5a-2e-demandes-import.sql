-- ============================================================
-- ORIMETIER — Phase 5a-2e : RPC admin par jeton (demandes d'inscription & import en masse).
--
-- Pré-requis : 5a-1 exécutée (admin_session_open, branche 'admin' de
-- _session_user). Migration ADDITIVE : les anciennes fonctions
-- (p_admin_password) restent en service jusqu'en 5c.
--
-- Nouvelles fonctions (suffixe _v2) :
--   admin_marquer_demande_traitee_v2     (live l. 298-311)
--   admin_lier_photos_logo_demande_v2    (live l. 163-199)
--   admin_bulk_import_etablissements_v2  (live l. 12-101)
-- Écrites à partir de supabase/reference/live-2026-09-26.sql. Seule la
-- ligne d'authentification change : la vérification admin_config est
-- remplacée par _session_user(p_token, 'admin'), qui lève SESSION_INVALIDE
-- (P0401) si le jeton est invalide, expiré, révoqué, ou si l'admin est
-- désactivé. Le reste du corps est identique, règles métier et valeurs de
-- retour comprises :
--   - marquer_demande_traitee : false si la demande est inconnue ou déjà
--     traitée ;
--   - lier_photos_logo_demande : false si la demande est inconnue ou déjà
--     traitée, false si l'établissement est inconnu (la demande n'est alors
--     PAS marquée traitée) ; true sinon ;
--   - p_demande_id est converti en uuid (::uuid) : un identifiant qui n'a
--     pas le format uuid lève une erreur, comme dans le live ;
--   - bulk_import : catégorie general/superieur/technique (sinon erreur),
--     sous-catégorie obligatoire pour le Supérieur (sinon erreur), lignes
--     invalides renvoyées avec resultat = 'ignore' et leur raison.
--
-- RETURNS TABLE de admin_bulk_import_etablissements_v2 (nom, ville, secteur,
-- code_recuperation, resultat, raison) : le corps ne contient AUCUNE
-- référence de colonne de table dans une expression (pas de SELECT/WHERE
-- sur une table). Le seul accès à une table est l'INSERT dans
-- etablissements, dont la liste de colonnes cible n'est jamais remplacée par
-- une variable plpgsql (et ne peut pas être préfixée par un alias en SQL).
-- Les affectations "nom := ..." portent volontairement sur les colonnes de
-- sortie. Aucune ambiguïté possible : le corps est repris à l'identique.
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
-- 1) admin_marquer_demande_traitee_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_marquer_demande_traitee_v2(p_token text, p_demande_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');
  update demandes_inscription_etablissements
    set statut_demande = 'traite'
    where id = p_demande_id::uuid and statut_demande = 'en_attente';
  return found;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_marquer_demande_traitee_v2(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_marquer_demande_traitee_v2(text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 2) admin_lier_photos_logo_demande_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_lier_photos_logo_demande_v2(p_token text, p_demande_id text, p_etablissement_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_photos jsonb;
  v_logo_url text;
begin
  perform _session_user(p_token, 'admin');

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

REVOKE ALL ON FUNCTION public.admin_lier_photos_logo_demande_v2(text, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_lier_photos_logo_demande_v2(text, text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 3) admin_bulk_import_etablissements_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_bulk_import_etablissements_v2(p_token text, p_categorie text, p_sous_categorie text, p_items jsonb)
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
  perform _session_user(p_token, 'admin');
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

REVOKE ALL ON FUNCTION public.admin_bulk_import_etablissements_v2(text, text, text, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_bulk_import_etablissements_v2(text, text, text, jsonb) TO anon, authenticated;

COMMIT;

-- ============================================================
-- VÉRIFICATIONS (à lancer après exécution, une requête à la fois)
-- ============================================================
--
-- V1. Anciennes ET nouvelles fonctions présentes (6 lignes attendues)
-- select p.proname, pg_get_function_identity_arguments(p.oid) as args
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('admin_marquer_demande_traitee', 'admin_marquer_demande_traitee_v2',
--                     'admin_lier_photos_logo_demande', 'admin_lier_photos_logo_demande_v2',
--                     'admin_bulk_import_etablissements', 'admin_bulk_import_etablissements_v2')
-- order by 1, 2;
--
-- V2. Sécurité des 3 nouvelles fonctions (3 lignes :
--     security_definer = true, config = {search_path=public}, anon = true, authenticated = true)
-- select p.oid::regprocedure as fonction, p.prosecdef as security_definer, p.proconfig as config,
--        has_function_privilege('anon', p.oid, 'EXECUTE') as anon,
--        has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('admin_marquer_demande_traitee_v2', 'admin_lier_photos_logo_demande_v2',
--                     'admin_bulk_import_etablissements_v2')
-- order by 1;
--
-- V3. Test fonctionnel complet SANS trace : fichier séparé
--     test-5a2e-v3.sql (bloc prêt à coller, ROLLBACK final).
--
-- V4. Aucune trace laissée par V3 (0, 0, 0 et 0 attendus)
-- select (select count(*) from public.admins where id = 'adm_test') as admin_test,
--        (select count(*) from public.sessions where user_id = 'adm_test') as sessions_test,
--        (select count(*) from public.etablissements where nom like 'test_5a2e%') as etab_test,
--        (select count(*) from public.demandes_inscription_etablissements where nom like 'test_5a2e%') as demandes_test;
