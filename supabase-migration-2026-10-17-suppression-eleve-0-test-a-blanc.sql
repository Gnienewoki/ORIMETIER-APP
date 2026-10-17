-- ============================================================
-- ORIMETIER — Suppression du compte élève : TEST À BLANC (étape 0)
-- LECTURE SEULE. UNE SEULE requête (aucun point-virgule intermédiaire) :
-- l'éditeur Supabase n'affiche que le dernier résultat.
-- Colonnes : type, nom, detail (une ligne par constat).
--
-- À lancer AVANT les étapes d, e, f, puis à me rapporter en entier.
--
-- Lignes produites (par ordre) :
--   table                 : présence de eleves et notes
--   nb_lignes             : nombre de lignes de eleves et de notes
--   cle_etrangere_vers    : clés étrangères QUI POINTENT vers eleves / notes
--   cle_etrangere_depuis  : clés étrangères de eleves / notes vers d'autres tables
--   contrainte            : autres contraintes de eleves / notes (PK, UNIQUE, CHECK)
--   trigger               : triggers sur eleves / notes, avec la fonction appelée
--   policy                : policies RLS sur eleves / notes
--   rls                   : RLS active / forcée sur eleves / notes
--   index                 : index de eleves / notes
--   droit_table           : droits (grants) sur eleves / notes, par rôle
--   realtime              : présence dans une publication (supabase_realtime)
--   dependance            : autres objets qui dépendent de eleves / notes (pg_depend,
--                           deptype en clair) — contraintes, triggers et policies
--                           exclus car déjà listés ci-dessus
--   vue                   : vues qui dépendent de eleves / notes (pg_depend + pg_rewrite)
--   fonction_utilise_table: fonctions du schéma public dont le corps lit/écrit
--                           eleves ou notes (FROM / JOIN / INTO / UPDATE / TABLE)
--   check_role            : contraintes CHECK portant sur la colonne role de
--                           sessions et password_resets
--   sessions_eleve        : lignes de sessions avec role = 'eleve' (dont actives)
--   password_resets_eleve : lignes de password_resets avec role = 'eleve' (dont valides)
--   fonction_eleve        : TOUTES les fonctions du schéma public contenant 'eleve'
--                           (nom, arguments ou corps), sauf le suivi privé
--                           inspecteur_suivi_*, inspecteur_lycam_*, inspecteur_mbti_*
--   fonction_a_adapter    : empreinte md5 du corps actuel des fonctions que l'étape e
--                           réécrit (ou vérifie), comparée au corps versionné dans le dépôt
--
-- ATTENDU (d'après le dépôt ; tout écart est à me signaler) :
--   - cle_etrangere_vers : au plus une ligne notes -> eleves ; aucune autre.
--   - vue : aucune ligne.
--   - fonction_utilise_table : eleve_session_open, eleve_save_riasec, eleve_update_email,
--     list_eleves, admin_set_eleve_banni_v2, _session_user, password_reset_create,
--     reset_password_with_token. Rien d'autre.
--   - fonction_eleve : les 8 ci-dessus, plus admin_upsert_lien_formation_v2
--     (audience 'eleve' des liens de formation, sans rapport) et log_visite
--     (clé de page 'eleves.html'). Ces deux-là restent.
--   - fonction_a_adapter : « IDENTIQUE au dépôt » sur les 5 lignes. Si une ligne dit
--     « DIFFÉRENTE », NE PAS lancer l'étape e : m'envoyer la définition actuelle
--     (requête dans suppression-eleve-notes.md).
-- ============================================================
WITH
tbl(nom, oid) AS (
  SELECT 'eleves'::text, to_regclass('public.eleves')
  UNION ALL
  SELECT 'notes'::text, to_regclass('public.notes')
),
cibles AS (
  SELECT nom, oid FROM tbl WHERE oid IS NOT NULL
),
empreintes(sig, md5_lf, md5_crlf) AS (
  VALUES
    ('_session_user(text,text)',                'c5f3dc2832f4859ccc2ed6300e7f02e0', '7c954077521978ce4f0e1948008eb87b'),
    ('password_reset_create(text,text,text)',   '5e2e2eb49c4b18205f8d7d8024675cb0', 'f2383113e4d9ac768f8fcdce8f1cd438'),
    ('reset_password_with_token(text,text)',    '5643c80b5a7aab2a8db7af577e0be1a6', '40e45e5535a0a329b3069345268e2d53'),
    ('session_check(text)',                     '5117769eb605091f13e4d82d9eeb1a74', 'cf5f52d1eb1fa18f9ac725f798c58486'),
    ('session_close(text)',                     'd63e3a76283b8584851c485c12e4b310', '0a7770bbc20b278e4653f71e400d12a1')
),
lignes(ordre, type, nom, detail) AS (
  -- Présence des tables
  SELECT 1, 'table', t.nom, CASE WHEN t.oid IS NULL THEN 'ABSENTE' ELSE 'présente' END
  FROM tbl t

  UNION ALL
  -- Nombre de lignes (requête dynamique : pas d'erreur si une table manquait)
  SELECT 2, 'nb_lignes', c.nom,
         (xpath('/row/n/text()',
                query_to_xml('select count(*) as n from public.' || quote_ident(c.nom), false, true, '')))[1]::text
  FROM cibles c

  UNION ALL
  -- Clés étrangères qui pointent vers eleves / notes
  SELECT 3, 'cle_etrangere_vers', con.conname,
         con.conrelid::regclass::text || ' -> ' || con.confrelid::regclass::text || ' : ' || pg_get_constraintdef(con.oid)
  FROM pg_constraint con
  JOIN cibles c ON con.confrelid = c.oid
  WHERE con.contype = 'f'

  UNION ALL
  -- Clés étrangères de eleves / notes vers d'autres tables
  SELECT 4, 'cle_etrangere_depuis', con.conname,
         con.conrelid::regclass::text || ' -> ' || con.confrelid::regclass::text || ' : ' || pg_get_constraintdef(con.oid)
  FROM pg_constraint con
  JOIN cibles c ON con.conrelid = c.oid
  WHERE con.contype = 'f'

  UNION ALL
  -- Autres contraintes (clé primaire, unicité, CHECK)
  SELECT 5, 'contrainte', con.conname, c.nom || ' : ' || pg_get_constraintdef(con.oid)
  FROM pg_constraint con
  JOIN cibles c ON con.conrelid = c.oid
  WHERE con.contype <> 'f'

  UNION ALL
  -- Triggers
  SELECT 6, 'trigger', tg.tgname, c.nom || ' -> ' || tg.tgfoid::regprocedure::text
  FROM pg_trigger tg
  JOIN cibles c ON tg.tgrelid = c.oid
  WHERE NOT tg.tgisinternal

  UNION ALL
  -- Policies RLS
  SELECT 7, 'policy', pol.polname,
         c.nom || ' : ' ||
         CASE pol.polcmd WHEN 'r' THEN 'SELECT' WHEN 'a' THEN 'INSERT' WHEN 'w' THEN 'UPDATE' WHEN 'd' THEN 'DELETE' ELSE 'ALL' END ||
         ' pour ' || coalesce((SELECT string_agg(CASE r WHEN 0 THEN 'public' ELSE r::regrole::text END, '+')
                              FROM unnest(pol.polroles) r), '?') ||
         ' | USING ' || coalesce(pg_get_expr(pol.polqual, pol.polrelid), '-') ||
         ' | WITH CHECK ' || coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid), '-')
  FROM pg_policy pol
  JOIN cibles c ON pol.polrelid = c.oid

  UNION ALL
  -- RLS active / forcée
  SELECT 8, 'rls', c.nom, 'rls_active=' || cl.relrowsecurity::text || ', rls_forcee=' || cl.relforcerowsecurity::text
  FROM cibles c
  JOIN pg_class cl ON cl.oid = c.oid

  UNION ALL
  -- Index
  SELECT 9, 'index', i.indexrelid::regclass::text, pg_get_indexdef(i.indexrelid)
  FROM pg_index i
  JOIN cibles c ON i.indrelid = c.oid

  UNION ALL
  -- Droits sur les tables, par rôle bénéficiaire
  SELECT 10, 'droit_table', c.nom,
         CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE a.grantee::regrole::text END || ' : ' ||
         string_agg(DISTINCT a.privilege_type, ',')
  FROM cibles c
  JOIN pg_class cl ON cl.oid = c.oid
  CROSS JOIN LATERAL aclexplode(cl.relacl) a
  GROUP BY c.nom, a.grantee

  UNION ALL
  -- Publications (realtime)
  SELECT 11, 'realtime', pt.pubname, pt.schemaname || '.' || pt.tablename
  FROM pg_publication_tables pt
  WHERE pt.schemaname = 'public' AND pt.tablename IN ('eleves', 'notes')

  UNION ALL
  -- Autres objets qui dépendent des tables (contraintes, triggers, policies et type ligne exclus)
  SELECT 12, 'dependance', pg_describe_object(d.classid, d.objid, d.objsubid),
         'dépend de ' || c.nom || ' (deptype ' || d.deptype::text || ')'
  FROM pg_depend d
  JOIN cibles c ON d.refclassid = 'pg_class'::regclass AND d.refobjid = c.oid
  WHERE d.classid NOT IN ('pg_constraint'::regclass, 'pg_trigger'::regclass, 'pg_policy'::regclass, 'pg_type'::regclass)
    AND NOT (d.classid = 'pg_class'::regclass AND d.objid = c.oid)

  UNION ALL
  -- Vues (règles de réécriture) qui dépendent des tables
  SELECT 13, 'vue', r.ev_class::regclass::text,
         'dépend de ' || c.nom || ' (deptype ' || d.deptype::text || ')'
  FROM pg_depend d
  JOIN pg_rewrite r ON d.classid = 'pg_rewrite'::regclass AND d.objid = r.oid
  JOIN cibles c ON d.refclassid = 'pg_class'::regclass AND d.refobjid = c.oid
  WHERE r.ev_class <> c.oid

  UNION ALL
  -- Fonctions dont le corps lit ou écrit eleves / notes
  SELECT 14, 'fonction_utilise_table', p.oid::regprocedure::text,
         'cite : ' || concat_ws(' + ',
           CASE WHEN p.prosrc ~* '(from|join|into|update|table)\s+(public\.)?eleves\M' THEN 'eleves' END,
           CASE WHEN p.prosrc ~* '(from|join|into|update|table)\s+(public\.)?notes\M' THEN 'notes' END)
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.prosrc ~* '(from|join|into|update|table)\s+(public\.)?(eleves|notes)\M'

  UNION ALL
  -- Contraintes CHECK sur la colonne role de sessions et password_resets
  SELECT 15, 'check_role', con.conname, con.conrelid::regclass::text || ' : ' || pg_get_constraintdef(con.oid)
  FROM pg_constraint con
  WHERE con.contype = 'c'
    AND con.conrelid IN (to_regclass('public.sessions'), to_regclass('public.password_resets'))
    AND pg_get_constraintdef(con.oid) ~* '\mrole\M'

  UNION ALL
  -- Sessions de rôle élève
  SELECT 16, 'sessions_eleve', 'sessions',
         (SELECT count(*) FROM public.sessions s WHERE s.role = 'eleve')::text || ' ligne(s), dont ' ||
         (SELECT count(*) FROM public.sessions s WHERE s.role = 'eleve' AND NOT s.revoked AND s.expires_at > now())::text ||
         ' active(s)'

  UNION ALL
  -- Réinitialisations de mot de passe de rôle élève
  SELECT 17, 'password_resets_eleve', 'password_resets',
         (SELECT count(*) FROM public.password_resets pr WHERE pr.role = 'eleve')::text || ' ligne(s), dont ' ||
         (SELECT count(*) FROM public.password_resets pr WHERE pr.role = 'eleve' AND NOT pr.used AND pr.expires_at > now())::text ||
         ' encore valable(s)'

  UNION ALL
  -- Toutes les fonctions contenant 'eleve' (hors suivi privé, LYCAM, MBTI)
  SELECT 18, 'fonction_eleve', p.oid::regprocedure::text,
         'trouvé dans : ' || concat_ws('+',
           CASE WHEN p.proname ~* 'eleve' THEN 'nom' END,
           CASE WHEN pg_get_function_identity_arguments(p.oid) ~* 'eleve' THEN 'arguments' END,
           CASE WHEN p.prosrc ~* 'eleve' THEN 'corps' END) ||
         ' | security_definer=' || p.prosecdef::text ||
         ' | anon=' || has_function_privilege('anon', p.oid, 'EXECUTE')::text ||
         ' | authenticated=' || has_function_privilege('authenticated', p.oid, 'EXECUTE')::text
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND (p.proname ~* 'eleve' OR pg_get_function_identity_arguments(p.oid) ~* 'eleve' OR p.prosrc ~* 'eleve')
    AND p.proname !~ '^inspecteur_(suivi|lycam|mbti)_'

  UNION ALL
  -- Empreinte du corps actuel des fonctions réécrites ou vérifiées par l'étape e
  SELECT 19, 'fonction_a_adapter', e.sig,
         CASE
           WHEN to_regprocedure('public.' || e.sig) IS NULL THEN 'ABSENTE'
           WHEN md5(p.prosrc) IN (e.md5_lf, e.md5_crlf) THEN 'IDENTIQUE au dépôt'
           ELSE 'DIFFÉRENTE du dépôt (md5 ' || md5(p.prosrc) || ') : ne pas lancer l''étape e, exporter la définition'
         END
  FROM empreintes e
  LEFT JOIN pg_proc p ON p.oid = to_regprocedure('public.' || e.sig)
)
SELECT type, nom, detail
FROM lignes
ORDER BY ordre, nom, detail;
