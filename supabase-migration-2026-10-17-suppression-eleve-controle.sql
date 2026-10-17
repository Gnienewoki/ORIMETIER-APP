-- ============================================================
-- ORIMETIER — Suppression du compte élève : CONTRÔLES (lecture seule)
-- 4 requêtes indépendantes, une par étape. L'éditeur Supabase n'affichant que le
-- dernier résultat, SÉLECTIONNER UNE SEULE requête (de « -- === APRÈS x » jusqu'à son
-- point-virgule) puis « Run selected ».
-- Chaque requête renvoie : controle, attendu, obtenu, ok. Attendu : ok = true partout.
-- ============================================================


-- === APRÈS c (Edge Function redéployée) =====================================
-- À lancer après avoir envoyé une demande « mot de passe oublié » avec role = 'eleve'
-- (commande dans suppression-eleve-notes.md). Attendu : 2 lignes, ok = true.
SELECT controle, attendu, obtenu, obtenu = attendu AS ok
FROM (
  SELECT 1 AS n, 'password_resets eleve créés depuis 1 h' AS controle, '0' AS attendu,
         (SELECT count(*) FROM public.password_resets
          WHERE role = 'eleve' AND created_at > now() - interval '1 hour')::text AS obtenu
  UNION ALL
  SELECT 2, 'password_reset_create toujours réservée à service_role (anon)', 'false',
         has_function_privilege('anon', 'public.password_reset_create(text,text,text)', 'EXECUTE')::text
) t
ORDER BY n;


-- === APRÈS d (accès publics coupés, rien supprimé) ==========================
-- Attendu : 19 lignes, ok = true.
SELECT controle, attendu, obtenu, obtenu = attendu AS ok
FROM (
  SELECT 1 AS n, 'eleves : anon SELECT' AS controle, 'false' AS attendu, has_table_privilege('anon', 'public.eleves', 'SELECT')::text AS obtenu
  UNION ALL SELECT 2, 'eleves : anon INSERT', 'false', has_table_privilege('anon', 'public.eleves', 'INSERT')::text
  UNION ALL SELECT 3, 'eleves : anon UPDATE', 'false', has_table_privilege('anon', 'public.eleves', 'UPDATE')::text
  UNION ALL SELECT 4, 'eleves : anon DELETE', 'false', has_table_privilege('anon', 'public.eleves', 'DELETE')::text
  UNION ALL SELECT 5, 'eleves : authenticated INSERT', 'false', has_table_privilege('authenticated', 'public.eleves', 'INSERT')::text
  UNION ALL SELECT 6, 'eleves : authenticated SELECT', 'false', has_table_privilege('authenticated', 'public.eleves', 'SELECT')::text
  UNION ALL SELECT 7, 'notes : anon SELECT', 'false',
         CASE WHEN to_regclass('public.notes') IS NULL THEN 'false' ELSE has_table_privilege('anon', 'public.notes', 'SELECT')::text END
  UNION ALL SELECT 8, 'policies restantes sur eleves / notes', '0',
         (SELECT count(*) FROM pg_policy WHERE polrelid IN (to_regclass('public.eleves'), to_regclass('public.notes')))::text
  UNION ALL SELECT 9,  'list_eleves : anon EXECUTE', 'false', has_function_privilege('anon', 'public.list_eleves()', 'EXECUTE')::text
  UNION ALL SELECT 10, 'list_eleves : authenticated EXECUTE', 'false', has_function_privilege('authenticated', 'public.list_eleves()', 'EXECUTE')::text
  UNION ALL SELECT 11, 'eleve_session_open : anon EXECUTE', 'false', has_function_privilege('anon', 'public.eleve_session_open(text,text)', 'EXECUTE')::text
  UNION ALL SELECT 12, 'eleve_save_riasec : anon EXECUTE', 'false', has_function_privilege('anon', 'public.eleve_save_riasec(text,jsonb)', 'EXECUTE')::text
  UNION ALL SELECT 13, 'eleve_update_email : anon EXECUTE', 'false', has_function_privilege('anon', 'public.eleve_update_email(text,text)', 'EXECUTE')::text
  UNION ALL SELECT 14, 'admin_set_eleve_banni_v2 : anon EXECUTE', 'false', has_function_privilege('anon', 'public.admin_set_eleve_banni_v2(text,text,boolean)', 'EXECUTE')::text
  UNION ALL SELECT 15, 'admin_set_eleve_banni_v2 : authenticated EXECUTE', 'false', has_function_privilege('authenticated', 'public.admin_set_eleve_banni_v2(text,text,boolean)', 'EXECUTE')::text
  UNION ALL SELECT 16, 'les 5 fonctions élève existent encore (suppression à l''étape e)', '5',
         ((to_regprocedure('public.list_eleves()') IS NOT NULL)::int
        + (to_regprocedure('public.eleve_session_open(text,text)') IS NOT NULL)::int
        + (to_regprocedure('public.eleve_save_riasec(text,jsonb)') IS NOT NULL)::int
        + (to_regprocedure('public.eleve_update_email(text,text)') IS NOT NULL)::int
        + (to_regprocedure('public.admin_set_eleve_banni_v2(text,text,boolean)') IS NOT NULL)::int)::text
  UNION ALL SELECT 17, 'tables eleves et notes toujours présentes', '2',
         ((to_regclass('public.eleves') IS NOT NULL)::int + (to_regclass('public.notes') IS NOT NULL)::int)::text
  UNION ALL SELECT 18, 'session_check toujours appelable par anon', 'true', has_function_privilege('anon', 'public.session_check(text)', 'EXECUTE')::text
  UNION ALL SELECT 19, 'reset_password_with_token toujours appelable par anon', 'true', has_function_privilege('anon', 'public.reset_password_with_token(text,text)', 'EXECUTE')::text
) t
ORDER BY n;


-- === APRÈS e (fonctions supprimées / adaptées, rôle 'eleve' retiré) =========
-- Attendu : 17 lignes, ok = true.
SELECT controle, attendu, obtenu, obtenu = attendu AS ok
FROM (
  SELECT 1 AS n, 'fonctions élève restantes (5 attendues supprimées)' AS controle, '0' AS attendu,
         ((to_regprocedure('public.list_eleves()') IS NOT NULL)::int
        + (to_regprocedure('public.eleve_session_open(text,text)') IS NOT NULL)::int
        + (to_regprocedure('public.eleve_save_riasec(text,jsonb)') IS NOT NULL)::int
        + (to_regprocedure('public.eleve_update_email(text,text)') IS NOT NULL)::int
        + (to_regprocedure('public.admin_set_eleve_banni_v2(text,text,boolean)') IS NOT NULL)::int)::text AS obtenu
  UNION ALL SELECT 2, '_session_user : liste blanche des rôles présente', 'true',
         ((SELECT prosrc FROM pg_proc WHERE oid = to_regprocedure('public._session_user(text,text)'))
            ~ 'p_role not in \(''inspecteur'', ''etablissement'', ''admin''\)')::text
  UNION ALL SELECT 3, '_session_user : ne cite plus eleve', 'false',
         ((SELECT prosrc FROM pg_proc WHERE oid = to_regprocedure('public._session_user(text,text)')) ~* 'eleve')::text
  UNION ALL SELECT 4, 'password_reset_create : ne cite plus eleve', 'false',
         ((SELECT prosrc FROM pg_proc WHERE oid = to_regprocedure('public.password_reset_create(text,text,text)')) ~* 'eleve')::text
  UNION ALL SELECT 5, 'reset_password_with_token : ne cite plus eleve', 'false',
         ((SELECT prosrc FROM pg_proc WHERE oid = to_regprocedure('public.reset_password_with_token(text,text)')) ~* 'eleve')::text
  UNION ALL SELECT 6, '_session_user : anon EXECUTE (doit rester interne)', 'false',
         has_function_privilege('anon', 'public._session_user(text,text)', 'EXECUTE')::text
  UNION ALL SELECT 7, 'password_reset_create : anon EXECUTE', 'false',
         has_function_privilege('anon', 'public.password_reset_create(text,text,text)', 'EXECUTE')::text
  UNION ALL SELECT 8, 'password_reset_create : service_role EXECUTE', 'true',
         has_function_privilege('service_role', 'public.password_reset_create(text,text,text)', 'EXECUTE')::text
  UNION ALL SELECT 9, 'reset_password_with_token : anon EXECUTE', 'true',
         has_function_privilege('anon', 'public.reset_password_with_token(text,text)', 'EXECUTE')::text
  UNION ALL SELECT 10, 'session_check : jeton bidon -> null', 'true',
         (public.session_check('jeton-de-controle-inexistant') IS NULL)::text
  UNION ALL SELECT 11, 'sessions role eleve', '0',
         (SELECT count(*) FROM public.sessions WHERE role = 'eleve')::text
  UNION ALL SELECT 12, 'password_resets role eleve', '0',
         (SELECT count(*) FROM public.password_resets WHERE role = 'eleve')::text
  UNION ALL SELECT 13, 'CHECK sessions.role', 'CHECK ((role = ANY (ARRAY[''inspecteur''::text, ''etablissement''::text, ''admin''::text])))',
         (SELECT pg_get_constraintdef(oid) FROM pg_constraint
          WHERE conrelid = 'public.sessions'::regclass AND conname = 'sessions_role_check')
  UNION ALL SELECT 14, 'CHECK password_resets.role', 'CHECK ((role = ANY (ARRAY[''inspecteur''::text, ''etablissement''::text])))',
         (SELECT pg_get_constraintdef(oid) FROM pg_constraint
          WHERE conrelid = 'public.password_resets'::regclass AND conname = 'password_resets_role_check')
  UNION ALL SELECT 15, 'contraintes CHECK sur role (1 par table)', '2',
         (SELECT count(*) FROM pg_constraint
          WHERE contype = 'c' AND conrelid IN ('public.sessions'::regclass, 'public.password_resets'::regclass)
            AND pg_get_constraintdef(oid) ~* '\mrole\M')::text
  UNION ALL SELECT 16, 'fonctions citant eleves ou ''eleve'' (hors liens de formation)', '0',
         (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
          WHERE n.nspname = 'public'
            AND (p.prosrc ~* '(from|join|into|update|table)\s+(public\.)?eleves\M' OR p.prosrc ~ '''eleve''')
            AND p.proname NOT LIKE 'admin_upsert_lien_formation%')::text
  UNION ALL SELECT 17, 'tables eleves et notes toujours présentes (suppression à l''étape f)', '2',
         ((to_regclass('public.eleves') IS NOT NULL)::int + (to_regclass('public.notes') IS NOT NULL)::int)::text
) t
ORDER BY n;


-- === APRÈS f (tables supprimées) ============================================
-- Attendu : 7 lignes, ok = true.
-- Ligne 5 : la liste exacte peut différer si le test à blanc 0 montrait d'autres tables
-- équipées de trg_hash_password ; l'important est qu'elle ne contienne plus eleves.
SELECT controle, attendu, obtenu, obtenu = attendu AS ok
FROM (
  SELECT 1 AS n, 'table eleves' AS controle, 'absente' AS attendu,
         CASE WHEN to_regclass('public.eleves') IS NULL THEN 'absente' ELSE 'PRÉSENTE' END AS obtenu
  UNION ALL SELECT 2, 'table notes', 'absente',
         CASE WHEN to_regclass('public.notes') IS NULL THEN 'absente' ELSE 'PRÉSENTE' END
  UNION ALL SELECT 3, 'eleves / notes dans une publication (realtime)', '0',
         (SELECT count(*) FROM pg_publication_tables
          WHERE schemaname = 'public' AND tablename IN ('eleves', 'notes'))::text
  UNION ALL SELECT 4, 'hash_password_trigger() toujours présente', 'true',
         (to_regprocedure('public.hash_password_trigger()') IS NOT NULL)::text
  UNION ALL SELECT 5, 'tables équipées de trg_hash_password', 'demandes_inscription_etablissements, etablissements, inspecteurs',
         (SELECT string_agg(c.relname, ', ' ORDER BY c.relname) FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
          WHERE t.tgname = 'trg_hash_password' AND NOT t.tgisinternal)
  UNION ALL SELECT 6, 'fonctions qui lisent/écrivent eleves ou notes', '0',
         (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
          WHERE n.nspname = 'public' AND p.prosrc ~* '(from|join|into|update|table)\s+(public\.)?(eleves|notes)\M')::text
  UNION ALL SELECT 7, 'suivi privé intact (suivi_eleves et suivi_eleves_notes)', '2',
         ((to_regclass('public.suivi_eleves') IS NOT NULL)::int + (to_regclass('public.suivi_eleves_notes') IS NOT NULL)::int)::text
) t
ORDER BY n;
