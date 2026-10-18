-- ============================================================
-- ORIMETIER — Inscription inspecteur durcie : FICHIER 0, TEST À BLANC (LECTURE SEULE).
--
-- UNE seule requête, aucune écriture. À lancer AVANT A (et éventuellement après A pour la
-- dernière colonne). Coller le résultat (une ligne) dans la conversation avant de lancer A.
--
-- Attendu avant A (d'après le constat de production et la référence live du 26/09) :
--   etab_register_retour = boolean, etab_claim_v2_retour = jsonb
--   hash_trigger_bcrypt_ok = true (le trigger ne re-hache pas un ^\$2[aby]\$)
--   triggers_inspecteurs contient trg_hash_password (BEFORE INSERT OR UPDATE OF password)
--     et trg_inspecteurs_revoke_sessions (AFTER UPDATE OF password OR DELETE)
--   actifs_vrai = presque tous les inspecteurs (le front envoie active = true) ; actifs_faux =
--     comptes désactivés par l'admin, s'il y en a ; actifs_nul = 0
--   defauts : active false, certification_demandee false (NO), banni / certifie : à lire
--   index_uniques : inspecteurs_tel_unique, inspecteurs_email_unique, + la clé primaire
--   pk_nom = inspecteurs_pkey (sinon le signaler : la fonction A reconnaît « %pkey »)
--   rls_active = true, rls_forcee = false (true bloquerait l'INSERT de la fonction après B)
--   proprietaire_table = postgres
--   policies : contient « insertion inscription inspecteur » (INSERT, {public}, check=true)
--   insert_anon = true, insert_authenticated = true (le trou à fermer en B)
--   update_anon / delete_anon : à lire (signalé dans les notes, non traité ici)
--   inspecteur_register_presente = false avant A, true après A
-- ============================================================

select
  (select string_agg(pg_get_function_identity_arguments(p.oid), ' | ') from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'etablissement_register')                       as etab_register_signature,
  (select string_agg(pg_get_function_result(p.oid), ' | ') from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'etablissement_register')                       as etab_register_retour,
  (select string_agg(pg_get_function_result(p.oid), ' | ') from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'etablissement_claim_v2')                       as etab_claim_v2_retour,
  (select bool_and(position('^\$2[aby]\$' in pg_get_functiondef(p.oid)) > 0) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'hash_password_trigger')                        as hash_trigger_bcrypt_ok,
  (select string_agg(pg_get_functiondef(p.oid), E'\n') from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'hash_password_trigger')                        as hash_trigger_definition,
  (select string_agg(pg_get_triggerdef(t.oid), E'\n' order by t.tgname) from pg_trigger t
     where t.tgrelid = 'public.inspecteurs'::regclass and not t.tgisinternal)                  as triggers_inspecteurs,
  (select count(*) from public.inspecteurs i where i.active is true)                            as actifs_vrai,
  (select count(*) from public.inspecteurs i where i.active is false)                           as actifs_faux,
  (select count(*) from public.inspecteurs i where i.active is null)                            as actifs_nul,
  (select count(*) from public.inspecteurs i where i.certifie is true)                          as nb_certifies,
  (select count(*) from public.inspecteurs i where i.banni is true)                             as nb_bannis,
  (select count(*) from public.inspecteurs i where i.certification_demandee is true)            as nb_certif_demandees,
  (select string_agg(c.column_name || '=' || coalesce(c.column_default, 'NULL') || ' (nullable ' || c.is_nullable || ')', ', ' order by c.column_name)
     from information_schema.columns c
     where c.table_schema = 'public' and c.table_name = 'inspecteurs'
       and c.column_name in ('id', 'active', 'banni', 'certifie', 'certification_demandee', 'date_inscription'))
                                                                                                as defauts,
  (select string_agg(pg_get_indexdef(x.indexrelid), E'\n') from pg_index x
     where x.indrelid = 'public.inspecteurs'::regclass and x.indisunique)                      as index_uniques,
  (select c.conname from pg_constraint c where c.conrelid = 'public.inspecteurs'::regclass and c.contype = 'p') as pk_nom,
  (select c.relrowsecurity from pg_class c where c.oid = 'public.inspecteurs'::regclass)         as rls_active,
  (select c.relforcerowsecurity from pg_class c where c.oid = 'public.inspecteurs'::regclass)    as rls_forcee,
  (select pg_get_userbyid(c.relowner) from pg_class c where c.oid = 'public.inspecteurs'::regclass) as proprietaire_table,
  (select string_agg(p.policyname || ' [' || p.cmd || ' ' || p.roles::text || '] check=' || coalesce(p.with_check, '-'), E'\n' order by p.policyname)
     from pg_policies p where p.schemaname = 'public' and p.tablename = 'inspecteurs')         as policies,
  has_any_column_privilege('anon', 'public.inspecteurs', 'INSERT')                              as insert_anon,
  has_any_column_privilege('authenticated', 'public.inspecteurs', 'INSERT')                     as insert_authenticated,
  has_any_column_privilege('anon', 'public.inspecteurs', 'UPDATE')                              as update_anon,
  has_table_privilege('anon', 'public.inspecteurs', 'DELETE')                                   as delete_anon,
  to_regprocedure('public.inspecteur_register(text,text,text,text,text,text,text,text,text)') is not null
                                                                                                as inspecteur_register_presente;
