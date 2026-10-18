-- ============================================================
-- ORIMETIER — tel / email des inspecteurs hors de la clé publique : FICHIER A2.
--
-- À lancer APRÈS A (déjà exécuté, 14/14) et AVANT le déploiement du front contacts-v3.
-- Ajoute message_accueil à inspecteur_get_own_v2 : list_inspecteurs ne le renvoie pas, si
-- bien que le profil l'affichait vide après chaque rechargement (bug ancien).
-- Le type de retour change (3 -> 4 colonnes) : CREATE OR REPLACE est impossible, d'où
-- DROP + CREATE. Sûr : aucun front en production n'appelle encore inspecteur_get_own_v2.
-- Un seul bloc DO, atomique (tout ou rien). Relançable (le DROP vise aussi la version A2).
-- admin_list_inspecteurs_contacts_v2 et list_inspecteurs : non touchées.
-- ============================================================

DO $migration$
declare
  v_sql text;
begin
  -- ================= GARDES
  if to_regprocedure('public._session_user(text,text)') is null then
    raise exception 'GARDE : _session_user(text, text) absente : rien n''est modifié.';
  end if;
  if to_regprocedure('public.inspecteur_get_own_v2(text)') is null then
    raise exception 'GARDE : inspecteur_get_own_v2 absente (lancer A d''abord) : rien n''est modifié.';
  end if;
  if pg_get_function_result('public.inspecteur_get_own_v2(text)'::regprocedure)
       not in ('TABLE(id text, tel text, email text)', 'TABLE(id text, tel text, email text, message_accueil text)') then
    raise exception 'GARDE : retour inattendu de inspecteur_get_own_v2 (%) : rien n''est modifié.',
      pg_get_function_result('public.inspecteur_get_own_v2(text)'::regprocedure);
  end if;
  if not exists (select 1 from information_schema.columns c
                 where c.table_schema = 'public' and c.table_name = 'inspecteurs' and c.column_name = 'message_accueil') then
    raise exception 'GARDE : colonne inspecteurs.message_accueil absente : rien n''est modifié.';
  end if;
  if exists (select 1 from pg_depend d
             where d.refobjid = 'public.inspecteur_get_own_v2(text)'::regprocedure and d.deptype = 'n') then
    raise exception 'GARDE : un objet dépend de inspecteur_get_own_v2 (le DROP le casserait) : rien n''est modifié.';
  end if;

  -- ================= INSTALLATION
  foreach v_sql in array array[
$ddl$DROP FUNCTION IF EXISTS public.inspecteur_get_own_v2(text)$ddl$,
$ddl$CREATE FUNCTION public.inspecteur_get_own_v2(p_token text)
 RETURNS TABLE(id text, tel text, email text, message_accueil text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_inspecteur_id text;
begin
  v_inspecteur_id := _session_user(p_token, 'inspecteur');

  return query
    select i.id, i.tel, i.email, i.message_accueil
    from inspecteurs i
    where i.id = v_inspecteur_id;
end; $function$$ddl$,
$ddl$COMMENT ON FUNCTION public.inspecteur_get_own_v2(text) IS 'Inspecteur (jeton) : son propre tel, email (e-mail de récupération) et message d''accueil.'$ddl$,
$ddl$REVOKE ALL ON FUNCTION public.inspecteur_get_own_v2(text) FROM PUBLIC, anon, authenticated$ddl$,
$ddl$GRANT EXECUTE ON FUNCTION public.inspecteur_get_own_v2(text) TO anon, authenticated$ddl$
  ] loop
    execute v_sql;
  end loop;

  -- ================= CONTRÔLES (une exception annule tout, DROP compris)
  if pg_get_function_result('public.inspecteur_get_own_v2(text)'::regprocedure)
       <> 'TABLE(id text, tel text, email text, message_accueil text)' then
    raise exception 'ÉCHEC : retour de inspecteur_get_own_v2 inattendu après création : tout est annulé.';
  end if;
  if not has_function_privilege('anon', 'public.inspecteur_get_own_v2(text)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'public.inspecteur_get_own_v2(text)', 'EXECUTE') then
    raise exception 'ÉCHEC : EXECUTE manquant pour anon / authenticated : tout est annulé.';
  end if;

  raise notice 'A2 appliquée : inspecteur_get_own_v2 renvoie (id, tel, email, message_accueil).';
end;
$migration$;

-- Vérification finale (attendu : 1 ligne, retour = TABLE(id text, tel text, email text, message_accueil text),
-- puis true sur les 5 autres colonnes)
select
  pg_get_function_result('public.inspecteur_get_own_v2(text)'::regprocedure)                   as retour,
  (select p.prosecdef from pg_proc p where p.oid = 'public.inspecteur_get_own_v2(text)'::regprocedure) as security_definer,
  (select 'search_path=public' = any(p.proconfig) from pg_proc p where p.oid = 'public.inspecteur_get_own_v2(text)'::regprocedure) as search_path_public,
  position('_session_user(p_token, ''inspecteur'')' in pg_get_functiondef('public.inspecteur_get_own_v2(text)'::regprocedure)) > 0 as ouverture_jeton_inspecteur,
  has_function_privilege('anon', 'public.inspecteur_get_own_v2(text)', 'EXECUTE')
    and has_function_privilege('authenticated', 'public.inspecteur_get_own_v2(text)', 'EXECUTE') as execute_anon_authenticated,
  not exists (select 1 from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
              where p.oid = 'public.inspecteur_get_own_v2(text)'::regprocedure and a.grantee = 0 and a.privilege_type = 'EXECUTE') as aucun_execute_public;

-- ============================================================
-- RETOUR ARRIÈRE (NE PAS LANCER sauf besoin) : remet la version de A (3 colonnes).
-- Le front contacts-v3 reste compatible (message d'accueil alors non rechargé, comme avant).
-- À coller seul dans le SQL Editor, sans les « -- ».
-- ============================================================
-- DO $retour$
-- begin
--   execute 'DROP FUNCTION IF EXISTS public.inspecteur_get_own_v2(text)';
--   execute $f$CREATE FUNCTION public.inspecteur_get_own_v2(p_token text)
--  RETURNS TABLE(id text, tel text, email text)
--  LANGUAGE plpgsql
--  SECURITY DEFINER
--  SET search_path TO 'public'
-- AS $function$
-- declare
--   v_inspecteur_id text;
-- begin
--   v_inspecteur_id := _session_user(p_token, 'inspecteur');
--
--   return query
--     select i.id, i.tel, i.email
--     from inspecteurs i
--     where i.id = v_inspecteur_id;
-- end; $function$$f$;
--   execute 'REVOKE ALL ON FUNCTION public.inspecteur_get_own_v2(text) FROM PUBLIC, anon, authenticated';
--   execute 'GRANT EXECUTE ON FUNCTION public.inspecteur_get_own_v2(text) TO anon, authenticated';
-- end;
-- $retour$;
