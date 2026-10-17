-- ============================================================
-- ORIMETIER — Nettoyage 6c-2 : TEST À BLANC (lecture seule)
-- À exécuter dans le SQL Editor de Supabase AVANT nettoyage-6c-2.
-- UNE SEULE requête SELECT (aucune écriture) : l'éditeur n'affiche que le
-- dernier résultat. Colonnes : controle, ok, detail. Dernière ligne : TOTAL.
--
-- Contrôles :
--   1-4   les 4 anciennes fonctions existent avec leur signature exacte ET aucun
--         objet hors de ces 4 n'en dépend :
--           - autres fonctions (schémas non système) dont le corps cite le nom ;
--           - policies RLS ;
--           - vues et vues matérialisées ;
--           - triggers ;
--           - entrées pg_depend ;
--   11-12 les 2 nouvelles fonctions _v2 n'existent pas encore ;
--   21-23 pré-requis : _session_user et les 2 fonctions modèles _v2 existent ;
--   31-32 clé étrangère résultats -> sessions (information : la nouvelle fonction
--         supprime les résultats explicitement, que la contrainte soit en
--         CASCADE ou non ; ok = la contrainte existe).
-- Attendu : ok = true sur toutes les lignes, TOTAL compris.
-- ============================================================
WITH anciennes(ordre, nom, sig) AS (
  VALUES
    (1, 'admin_restore_backup',            'admin_restore_backup(text, jsonb)'),
    (2, 'inspecteur_add_note',             'inspecteur_add_note(text, text, text, text)'),
    (3, 'inspecteur_lycam_delete_session', 'inspecteur_lycam_delete_session(text, text, text)'),
    (4, 'inspecteur_mbti_delete_session',  'inspecteur_mbti_delete_session(text, text, text)')
),
a AS (
  SELECT ordre, nom, sig,
         to_regprocedure('public.' || sig)::oid AS foid,
         '\m' || nom || '\M' AS motif
  FROM anciennes
),
oids AS (SELECT foid FROM a WHERE foid IS NOT NULL),
deps AS (
  -- Autres fonctions dont le corps cite le nom
  SELECT a.ordre,
         'fonction ' || n.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')' AS d
  FROM a
  JOIN pg_proc p ON p.prosrc ~* a.motif
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname NOT LIKE 'pg\_%'
    AND p.oid NOT IN (SELECT foid FROM oids)
  UNION ALL
  -- Policies RLS
  SELECT a.ordre, 'policy ' || pol.polname || ' sur ' || pol.polrelid::regclass::text
  FROM a
  JOIN pg_policy pol
    ON (coalesce(pg_get_expr(pol.polqual, pol.polrelid), '') || ' ' ||
        coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid), '')) ~* a.motif
  UNION ALL
  -- Vues
  SELECT a.ordre, 'vue ' || v.schemaname || '.' || v.viewname
  FROM a
  JOIN pg_views v ON v.definition ~* a.motif
  WHERE v.schemaname NOT IN ('pg_catalog', 'information_schema')
  UNION ALL
  -- Vues matérialisées
  SELECT a.ordre, 'vue matérialisée ' || m.schemaname || '.' || m.matviewname
  FROM a
  JOIN pg_matviews m ON m.definition ~* a.motif
  UNION ALL
  -- Triggers
  SELECT a.ordre, 'trigger ' || t.tgname || ' sur ' || t.tgrelid::regclass::text
  FROM a
  JOIN pg_trigger t ON t.tgfoid = a.foid
  WHERE NOT t.tgisinternal
  UNION ALL
  -- pg_depend : tout objet qui référence la fonction (hors les 4 elles-mêmes)
  SELECT a.ordre,
         'pg_depend ' || pg_describe_object(d.classid, d.objid, d.objsubid) || ' (type ' || d.deptype || ')'
  FROM a
  JOIN pg_depend d ON d.refclassid = 'pg_proc'::regclass AND d.refobjid = a.foid
  WHERE NOT (d.classid = 'pg_proc'::regclass AND d.objid IN (SELECT foid FROM oids))
),
nb AS (
  SELECT a.ordre, count(deps.d) AS n,
         coalesce(string_agg(deps.d, ' | ' ORDER BY deps.d), '') AS det
  FROM a
  LEFT JOIN deps ON deps.ordre = a.ordre
  GROUP BY a.ordre
),
fk AS (
  SELECT r.tbl,
         string_agg(c.conname || ' ON DELETE ' ||
           CASE c.confdeltype WHEN 'c' THEN 'CASCADE' WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT'
                              WHEN 'n' THEN 'SET NULL' WHEN 'd' THEN 'SET DEFAULT' END, ', ') AS det,
         count(c.oid) AS n
  FROM (VALUES ('lycam_resultats', 'lycam_sessions'), ('mbti_resultats', 'mbti_sessions')) AS r(tbl, ref)
  LEFT JOIN pg_constraint c
    ON c.contype = 'f'
   AND c.conrelid = to_regclass('public.' || r.tbl)
   AND c.confrelid = to_regclass('public.' || r.ref)
  GROUP BY r.tbl
),
controles(ordre, controle, ok, detail) AS (
  SELECT a.ordre,
         'ancienne ' || a.sig || ' : existe, aucune dépendance hors liste',
         a.foid IS NOT NULL AND nb.n = 0,
         CASE WHEN a.foid IS NULL THEN 'INTROUVABLE (signature)'
              ELSE nb.n || ' dépendance(s) hors liste' || CASE WHEN nb.n > 0 THEN ' : ' || nb.det ELSE '' END END
  FROM a JOIN nb USING (ordre)
  UNION ALL
  SELECT 11, 'nouvelle inspecteur_lycam_delete_session_v2(text, text) : pas encore créée',
         to_regprocedure('public.inspecteur_lycam_delete_session_v2(text,text)') IS NULL,
         CASE WHEN to_regprocedure('public.inspecteur_lycam_delete_session_v2(text,text)') IS NULL THEN 'absente' ELSE 'EXISTE DÉJÀ' END
  UNION ALL
  SELECT 12, 'nouvelle inspecteur_mbti_delete_session_v2(text, text) : pas encore créée',
         to_regprocedure('public.inspecteur_mbti_delete_session_v2(text,text)') IS NULL,
         CASE WHEN to_regprocedure('public.inspecteur_mbti_delete_session_v2(text,text)') IS NULL THEN 'absente' ELSE 'EXISTE DÉJÀ' END
  UNION ALL
  SELECT 21, 'pré-requis _session_user(text, text)',
         to_regprocedure('public._session_user(text,text)') IS NOT NULL, ''
  UNION ALL
  SELECT 22, 'modèle inspecteur_lycam_list_sessions_v2(text)',
         to_regprocedure('public.inspecteur_lycam_list_sessions_v2(text)') IS NOT NULL, ''
  UNION ALL
  SELECT 23, 'modèle inspecteur_mbti_list_sessions_v2(text)',
         to_regprocedure('public.inspecteur_mbti_list_sessions_v2(text)') IS NOT NULL, ''
  UNION ALL
  SELECT CASE fk.tbl WHEN 'lycam_resultats' THEN 31 ELSE 32 END,
         'clé étrangère ' || fk.tbl || ' -> ' || replace(fk.tbl, '_resultats', '_sessions') || ' (information)',
         fk.n > 0,
         coalesce(fk.det, 'aucune clé étrangère (la suppression explicite des résultats reste correcte)')
  FROM fk
)
SELECT controle, ok, detail
FROM (
  SELECT ordre, controle, ok, detail FROM controles
  UNION ALL
  SELECT 999, 'TOTAL', bool_and(ok),
         count(*) FILTER (WHERE ok) || ' / ' || count(*) || ' contrôles ok'
  FROM controles
) r
ORDER BY ordre;
