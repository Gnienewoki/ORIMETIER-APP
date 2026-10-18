-- ============================================================
-- ORIMETIER — tel / email des inspecteurs hors de la clé publique : FICHIER 0, TEST À BLANC.
-- LECTURE SEULE, UNE seule requête (une ligne). À lancer avant A ; coller le résultat.
--
-- Attendu avant A :
--   list_inspecteurs_retour = TABLE(id text, nom text, prenoms text, fonction text, cio text,
--     tel text, email text, active boolean, date_inscription text, certifie boolean,
--     banni boolean, avatar_url text, certification_demandee boolean)
--   list_inspecteurs_corps_tel_email = true (le corps contient « tel, email »)
--   list_inspecteurs_langage = sql, list_inspecteurs_secdef = true
--   list_inspecteurs_acl : PUBLIC (=X), anon, authenticated, service_role, postgres
--   list_inspecteurs_dependances = 0
--   session_user_retour = text ; session_user_corps_admin_ok = true (gère le rôle 'admin')
--   session_user_corps_inspecteur_ok = true (gère le rôle 'inspecteur', compte non banni)
--   etab_full_v2_modele_ok = true (SECURITY DEFINER, ouvre par _session_user(p_token, 'admin'))
--   admin_contacts_v2_presente = false, inspecteur_get_own_v2_presente = false (avant A)
--   nb_inspecteurs = nombre de comptes ; nb_avec_email = comptes ayant un e-mail
-- ============================================================

select
  pg_get_function_result('public.list_inspecteurs()'::regprocedure)                         as list_inspecteurs_retour,
  (select position('tel, email' in pg_get_functiondef(p.oid)) > 0 from pg_proc p
     where p.oid = 'public.list_inspecteurs()'::regprocedure)                                as list_inspecteurs_corps_tel_email,
  (select l.lanname from pg_proc p join pg_language l on l.oid = p.prolang
     where p.oid = 'public.list_inspecteurs()'::regprocedure)                                as list_inspecteurs_langage,
  (select p.prosecdef from pg_proc p where p.oid = 'public.list_inspecteurs()'::regprocedure) as list_inspecteurs_secdef,
  (select p.proacl::text from pg_proc p where p.oid = 'public.list_inspecteurs()'::regprocedure) as list_inspecteurs_acl,
  (select count(*) from pg_depend d
     where d.refobjid = 'public.list_inspecteurs()'::regprocedure and d.deptype = 'n')       as list_inspecteurs_dependances,
  (select pg_get_function_result(p.oid) from pg_proc p
     where p.oid = to_regprocedure('public._session_user(text,text)'))                       as session_user_retour,
  (select position('''admin''' in pg_get_functiondef(p.oid)) > 0 from pg_proc p
     where p.oid = to_regprocedure('public._session_user(text,text)'))                       as session_user_corps_admin_ok,
  (select position('''inspecteur''' in pg_get_functiondef(p.oid)) > 0 from pg_proc p
     where p.oid = to_regprocedure('public._session_user(text,text)'))                       as session_user_corps_inspecteur_ok,
  (select p.prosecdef and position('_session_user(p_token, ''admin'')' in pg_get_functiondef(p.oid)) > 0 from pg_proc p
     where p.oid = to_regprocedure('public.admin_list_etablissements_full_v2(text)'))        as etab_full_v2_modele_ok,
  to_regprocedure('public.admin_list_inspecteurs_contacts_v2(text)') is not null            as admin_contacts_v2_presente,
  to_regprocedure('public.inspecteur_get_own_v2(text)') is not null                         as inspecteur_get_own_v2_presente,
  (select count(*) from public.inspecteurs)                                                  as nb_inspecteurs,
  (select count(*) from public.inspecteurs i where coalesce(trim(i.email), '') <> '')        as nb_avec_email;
