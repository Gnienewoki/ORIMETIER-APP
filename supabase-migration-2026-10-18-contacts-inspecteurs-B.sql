-- ============================================================
-- ORIMETIER — tel / email des inspecteurs hors de la clé publique : FICHIER B.
--
-- À LANCER UNIQUEMENT APRÈS le déploiement du front v2 (sw 'orimetier-shell-v36') : l'onglet
-- admin « Comptes inspecteurs » et le profil inspecteur lisent alors tel / email par
-- admin_list_inspecteurs_contacts_v2 / inspecteur_get_own_v2 (fichier A), plus par
-- list_inspecteurs. Lancé avant, l'ancien front afficherait une colonne Contact et un
-- « E-mail de récupération » vides (rien d'autre ne casse).
--
-- CE QUE B FAIT : CREATE OR REPLACE de list_inspecteurs, PAS de DROP.
--   - signature de retour EXACTEMENT identique (13 colonnes, mêmes noms, mêmes types, même
--     ordre) : les appels existants (espFetchAllRows, .order('id'), .range) restent valides ;
--   - tel et email renvoyés à NULL (null::text) pour tout le monde ;
--   - LANGUAGE sql, SECURITY DEFINER, search_path public : inchangés ;
--   - droits : CREATE OR REPLACE conserve propriétaire et ACL (PUBLIC, anon, authenticated,
--     service_role) ; le bloc vérifie qu'ils sont identiques avant / après.
-- Un bloc DO = une transaction (tout ou rien). Relançable.
-- ============================================================

DO $migration$
declare
  v_attendu constant text := 'TABLE(id text, nom text, prenoms text, fonction text, cio text, tel text, email text, active boolean, date_inscription text, certifie boolean, banni boolean, avatar_url text, certification_demandee boolean)';
  v_acl_avant text;
  v_acl_apres text;
  v_owner_avant oid;
  v_owner_apres oid;
begin
  -- ================= GARDES
  if to_regprocedure('public.list_inspecteurs()') is null then
    raise exception 'GARDE : list_inspecteurs() absente : rien n''est modifié.';
  end if;
  if pg_get_function_result('public.list_inspecteurs()'::regprocedure) <> v_attendu then
    raise exception 'GARDE : signature de retour de list_inspecteurs inattendue (%) : rien n''est modifié.',
      pg_get_function_result('public.list_inspecteurs()'::regprocedure);
  end if;
  if to_regprocedure('public.admin_list_inspecteurs_contacts_v2(text)') is null
     or to_regprocedure('public.inspecteur_get_own_v2(text)') is null then
    raise exception 'GARDE : fichier A non installé (admin_list_inspecteurs_contacts_v2 / inspecteur_get_own_v2 absentes) : rien n''est modifié.';
  end if;
  if not has_function_privilege('anon', 'public.admin_list_inspecteurs_contacts_v2(text)', 'EXECUTE')
     or not has_function_privilege('anon', 'public.inspecteur_get_own_v2(text)', 'EXECUTE') then
    raise exception 'GARDE : les fonctions de A ne sont pas exécutables par anon (le front ne pourrait pas les appeler) : rien n''est modifié.';
  end if;

  select p.proacl::text, p.proowner into v_acl_avant, v_owner_avant
  from pg_proc p where p.oid = 'public.list_inspecteurs()'::regprocedure;

  -- ================= MODIFICATION
  execute $ddl$CREATE OR REPLACE FUNCTION public.list_inspecteurs()
 RETURNS TABLE(id text, nom text, prenoms text, fonction text, cio text, tel text, email text, active boolean, date_inscription text, certifie boolean, banni boolean, avatar_url text, certification_demandee boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  -- tel / email : plus jamais renvoyés à la clé publique (admin : admin_list_inspecteurs_contacts_v2,
  -- inspecteur connecté : inspecteur_get_own_v2). Colonnes conservées pour la compatibilité.
  select i.id, i.nom, i.prenoms, i.fonction, i.cio, null::text as tel, null::text as email,
         i.active, i.date_inscription, i.certifie, i.banni, i.avatar_url, i.certification_demandee
  from inspecteurs i;
$function$$ddl$;

  -- ================= CONTRÔLES (une exception annule tout)
  if pg_get_function_result('public.list_inspecteurs()'::regprocedure) <> v_attendu then
    raise exception 'ÉCHEC : la signature de retour a changé : tout est annulé.';
  end if;
  select p.proacl::text, p.proowner into v_acl_apres, v_owner_apres
  from pg_proc p where p.oid = 'public.list_inspecteurs()'::regprocedure;
  if v_acl_apres is distinct from v_acl_avant or v_owner_apres is distinct from v_owner_avant then
    raise exception 'ÉCHEC : droits ou propriétaire modifiés (avant %, après %) : tout est annulé.', v_acl_avant, v_acl_apres;
  end if;
  if exists (select 1 from public.list_inspecteurs() l where l.tel is not null or l.email is not null) then
    raise exception 'ÉCHEC : list_inspecteurs renvoie encore un tel ou un email : tout est annulé.';
  end if;

  raise notice 'B appliquée : list_inspecteurs ne renvoie plus tel ni email (droits inchangés : %).', v_acl_apres;
end;
$migration$;

-- Vérification rapide (attendu : 0 | 0 | false). Contrôle complet : fichier controle, requête 2.
select
  count(*) filter (where l.tel is not null)   as tel_renvoyes,
  count(*) filter (where l.email is not null) as email_renvoyes,
  (select position('tel, email' in pg_get_functiondef('public.list_inspecteurs()'::regprocedure)) > 0) as corps_contient_tel_email
from public.list_inspecteurs() l;

-- ============================================================
-- RETOUR ARRIÈRE (NE PAS LANCER sauf besoin : ré-expose tel et email à la clé publique).
-- Remet EXACTEMENT le corps de production lu le 18/10/2026. CREATE OR REPLACE : droits conservés.
-- À coller seul dans le SQL Editor, sans les « -- ».
-- ============================================================
-- CREATE OR REPLACE FUNCTION public.list_inspecteurs()
--  RETURNS TABLE(id text, nom text, prenoms text, fonction text, cio text, tel text, email text, active boolean, date_inscription text, certifie boolean, banni boolean, avatar_url text, certification_demandee boolean)
--  LANGUAGE sql
--  SECURITY DEFINER
--  SET search_path TO 'public'
-- AS $function$
--   select id, nom, prenoms, fonction, cio, tel, email, active, date_inscription, certifie, banni, avatar_url, certification_demandee
--   from inspecteurs;
-- $function$;
