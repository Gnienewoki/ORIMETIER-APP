-- ============================================================
-- ORIMETIER — tel / email des inspecteurs hors de la clé publique : FICHIER A, ADDITIF.
--
-- ORDRE : 0 -> A (ce fichier) -> contrôle 1 -> déploiement du front (sw v36) -> B -> contrôle 2.
-- Un bloc DO (gardes + installation), atomique : validé s'il va au bout, annulé entièrement à
-- la moindre exception. Relançable (CREATE OR REPLACE, mêmes signatures). Ne modifie RIEN
-- d'existant : list_inspecteurs continue de renvoyer tel et email jusqu'à B.
--
-- CE QUE A INSTALLE :
--   1. admin_list_inspecteurs_contacts_v2(p_token) -> TABLE(id, tel, email)
--      Ouverte par _session_user(p_token, 'admin'), comme admin_list_etablissements_full_v2
--      (SESSION_INVALIDE / P0401 sinon). Alimente la colonne « Contact » de l'onglet admin
--      « Comptes inspecteurs ».
--   2. inspecteur_get_own_v2(p_token) -> TABLE(id, tel, email)
--      Ouverte par _session_user(p_token, 'inspecteur') : renvoie UNIQUEMENT la ligne de
--      l'inspecteur du jeton. Nécessaire car le profil inspecteur affiche aujourd'hui son
--      propre « E-mail de récupération » en le lisant dans list_inspecteurs (inspecteur.js).
--   Pour les deux : SECURITY DEFINER, search_path public, EXECUTE pour anon et authenticated
--   seulement (retiré à PUBLIC). Colonnes qualifiées par alias (piège RETURNS TABLE(id ...)).
-- ============================================================

DO $migration$
declare
  v_sql text;
begin
  -- ================= GARDES
  if to_regprocedure('public._session_user(text,text)') is null then
    raise exception 'GARDE : _session_user(text, text) absente : rien n''est modifié.';
  end if;
  if pg_get_function_result('public._session_user(text,text)'::regprocedure) <> 'text' then
    raise exception 'GARDE : _session_user ne renvoie pas text (id du compte attendu) : rien n''est modifié.';
  end if;
  if to_regprocedure('public.admin_list_etablissements_full_v2(text)') is null then
    raise exception 'GARDE : admin_list_etablissements_full_v2 absente (modèle de la nouvelle fonction admin) : rien n''est modifié.';
  end if;
  if (select count(*) from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = 'inspecteurs' and c.column_name in ('id', 'tel', 'email')) <> 3 then
    raise exception 'GARDE : colonnes inspecteurs.id / tel / email attendues : rien n''est modifié.';
  end if;

  -- ================= INSTALLATION
  foreach v_sql in array array[

-- 1) Admin : téléphone et e-mail de tous les inspecteurs
$ddl$CREATE OR REPLACE FUNCTION public.admin_list_inspecteurs_contacts_v2(p_token text)
 RETURNS TABLE(id text, tel text, email text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');

  return query
    select i.id, i.tel, i.email
    from inspecteurs i
    order by i.id;
end; $function$$ddl$,
$ddl$COMMENT ON FUNCTION public.admin_list_inspecteurs_contacts_v2(text) IS 'Admin (jeton) : tel et email de chaque inspecteur. list_inspecteurs (publique) ne les renvoie plus après la migration contacts-inspecteurs B.'$ddl$,
$ddl$REVOKE ALL ON FUNCTION public.admin_list_inspecteurs_contacts_v2(text) FROM PUBLIC, anon, authenticated$ddl$,
$ddl$GRANT EXECUTE ON FUNCTION public.admin_list_inspecteurs_contacts_v2(text) TO anon, authenticated$ddl$,

-- 2) Inspecteur connecté : SES propres coordonnées, et seulement les siennes
$ddl$CREATE OR REPLACE FUNCTION public.inspecteur_get_own_v2(p_token text)
 RETURNS TABLE(id text, tel text, email text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_inspecteur_id text;
begin
  v_inspecteur_id := _session_user(p_token, 'inspecteur');

  return query
    select i.id, i.tel, i.email
    from inspecteurs i
    where i.id = v_inspecteur_id;
end; $function$$ddl$,
$ddl$COMMENT ON FUNCTION public.inspecteur_get_own_v2(text) IS 'Inspecteur (jeton) : son propre tel et email (profil, e-mail de récupération).'$ddl$,
$ddl$REVOKE ALL ON FUNCTION public.inspecteur_get_own_v2(text) FROM PUBLIC, anon, authenticated$ddl$,
$ddl$GRANT EXECUTE ON FUNCTION public.inspecteur_get_own_v2(text) TO anon, authenticated$ddl$

  ] loop
    execute v_sql;
  end loop;

  raise notice 'A installée : admin_list_inspecteurs_contacts_v2 et inspecteur_get_own_v2. list_inspecteurs inchangée (B la modifiera).';
end;
$migration$;

-- Vérification rapide (attendu : 1 ligne, tout à true). Contrôle complet : fichier controle, requête 1.
select
  to_regprocedure('public.admin_list_inspecteurs_contacts_v2(text)') is not null                    as admin_contacts_presente,
  to_regprocedure('public.inspecteur_get_own_v2(text)') is not null                                 as get_own_presente,
  has_function_privilege('anon', 'public.admin_list_inspecteurs_contacts_v2(text)', 'EXECUTE')      as admin_contacts_execute_anon,
  has_function_privilege('anon', 'public.inspecteur_get_own_v2(text)', 'EXECUTE')                   as get_own_execute_anon;
