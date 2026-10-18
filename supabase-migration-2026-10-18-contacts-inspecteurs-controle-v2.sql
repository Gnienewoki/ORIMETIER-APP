-- ============================================================
-- ORIMETIER — tel / email des inspecteurs hors de la clé publique : CONTRÔLES (LECTURE SEULE).
-- Requête 1 après A, requête 2 après B (sélectionner la requête voulue dans le SQL Editor ;
-- fichier entier = seul le dernier résultat s'affiche).
-- ============================================================

-- ------------------------------------------------------------
-- 1) APRÈS A + A2 — attendu : ok = true sur les 16 lignes
--    (inspecteur_get_own_v2 renvoie 4 colonnes depuis A2 ; admin_list_inspecteurs_contacts_v2 : 3)
-- ------------------------------------------------------------
with f(nom, oid, role_attendu, retour_attendu) as (
  values ('admin_list_inspecteurs_contacts_v2', to_regprocedure('public.admin_list_inspecteurs_contacts_v2(text)'), 'admin',      'TABLE(id text, tel text, email text)'),
         ('inspecteur_get_own_v2',              to_regprocedure('public.inspecteur_get_own_v2(text)'),              'inspecteur', 'TABLE(id text, tel text, email text, message_accueil text)')
), c as (
  select f.nom, f.oid, f.role_attendu, f.retour_attendu, p.prosecdef, p.proconfig, p.proacl, p.proowner,
         case when f.oid is null then null else pg_get_functiondef(f.oid) end as def,
         case when f.oid is null then null else pg_get_function_result(f.oid) end as retour
  from f left join pg_proc p on p.oid = f.oid
)
select n, controle, ok from (
  select 1 as n, c.nom || ' : présente' as controle, c.oid is not null as ok from c
  union all select 2, c.nom || ' : SECURITY DEFINER', coalesce(c.prosecdef, false) from c
  union all select 3, c.nom || ' : search_path = public', coalesce('search_path=public' = any(c.proconfig), false) from c
  union all select 4, c.nom || ' : retour ' || c.retour_attendu, coalesce(c.retour = c.retour_attendu, false) from c
  union all select 5, c.nom || ' : ouverte par _session_user(p_token, ''' || c.role_attendu || ''')',
      coalesce(position('_session_user(p_token, ''' || c.role_attendu || ''')' in c.def) > 0, false) from c
  union all select 6, c.nom || ' : EXECUTE anon et authenticated',
      c.oid is not null and has_function_privilege('anon', c.oid, 'EXECUTE') and has_function_privilege('authenticated', c.oid, 'EXECUTE') from c
  union all select 7, c.nom || ' : aucun EXECUTE pour PUBLIC', c.oid is not null and not exists (
      select 1 from aclexplode(coalesce(c.proacl, acldefault('f', c.proowner))) a where a.grantee = 0 and a.privilege_type = 'EXECUTE') from c
  union all select 8, c.nom || ' : aucun objet dépendant', c.oid is not null and not exists (
      select 1 from pg_depend d where d.refobjid = c.oid and d.deptype = 'n') from c
) t order by n, controle;

-- ------------------------------------------------------------
-- 2) APRÈS B — attendu : ok = true sur les 9 lignes
-- ------------------------------------------------------------
select n, controle, ok from (
  select 1 as n, 'list_inspecteurs : corps sans « tel, email »' as controle,
      position('tel, email' in pg_get_functiondef('public.list_inspecteurs()'::regprocedure)) = 0 as ok
  union all select 2, 'list_inspecteurs : corps avec null::text as tel / as email',
      position('null::text as tel' in pg_get_functiondef('public.list_inspecteurs()'::regprocedure)) > 0
      and position('null::text as email' in pg_get_functiondef('public.list_inspecteurs()'::regprocedure)) > 0
  union all select 3, 'list_inspecteurs : signature de retour inchangée',
      pg_get_function_result('public.list_inspecteurs()'::regprocedure) = 'TABLE(id text, nom text, prenoms text, fonction text, cio text, tel text, email text, active boolean, date_inscription text, certifie boolean, banni boolean, avatar_url text, certification_demandee boolean)'
  union all select 4, 'list_inspecteurs : toujours SECURITY DEFINER',
      (select p.prosecdef from pg_proc p where p.oid = 'public.list_inspecteurs()'::regprocedure)
  union all select 5, 'list_inspecteurs : droits inchangés (PUBLIC, anon, authenticated, service_role)',
      has_function_privilege('anon', 'public.list_inspecteurs()', 'EXECUTE')
      and has_function_privilege('authenticated', 'public.list_inspecteurs()', 'EXECUTE')
      and has_function_privilege('service_role', 'public.list_inspecteurs()', 'EXECUTE')
      and exists (select 1 from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                  where p.oid = 'public.list_inspecteurs()'::regprocedure and a.grantee = 0 and a.privilege_type = 'EXECUTE')
  union all select 6, 'list_inspecteurs : aucun tel ni email renvoyé',
      not exists (select 1 from public.list_inspecteurs() l where l.tel is not null or l.email is not null)
  union all select 7, 'list_inspecteurs : autant de lignes que de comptes',
      (select count(*) from public.list_inspecteurs()) = (select count(*) from public.inspecteurs)
  union all select 8, 'fonctions de A toujours présentes et exécutables par anon',
      to_regprocedure('public.admin_list_inspecteurs_contacts_v2(text)') is not null
      and to_regprocedure('public.inspecteur_get_own_v2(text)') is not null
      and has_function_privilege('anon', 'public.admin_list_inspecteurs_contacts_v2(text)', 'EXECUTE')
      and has_function_privilege('anon', 'public.inspecteur_get_own_v2(text)', 'EXECUTE')
  union all select 9, 'tel et email toujours en base (rien d''effacé)',
      (select count(*) from public.inspecteurs i where i.tel is not null) > 0
) t order by n;
