-- ============================================================
-- ORIMETIER — Nettoyage 6c : TEST À BLANC (lecture seule)
-- À exécuter dans le SQL Editor de Supabase AVANT nettoyage-6c-1.
-- UNE SEULE requête SELECT (aucune écriture) : l'éditeur n'affiche que le
-- dernier résultat.
--
-- Pour chacune des 57 fonctions à supprimer (même ordre que 6c-1) :
--   existe                    : signature exacte trouvée (to_regprocedure) ;
--   nb_dependances_hors_liste : nombre d'objets HORS des 57 qui dépendent d'elle :
--     - autres fonctions (schémas non système) dont le corps (prosrc) contient
--       son nom en mot entier ;
--     - policies RLS dont l'expression (USING / WITH CHECK) contient son nom ;
--     - vues et vues matérialisées dont la définition contient son nom ;
--     - triggers qui l'exécutent ;
--     - entrées pg_depend qui la référencent.
--   detail                    : liste de ces objets.
-- Attendu : existe = oui partout, 0 dépendance hors liste partout ; la dernière
-- ligne TOTAL résume (57 existantes / 57, 0 dépendance).
-- Une simple mention en commentaire dans le corps d'une autre fonction compte
-- aussi : lire « detail » avant de conclure.
-- ============================================================
WITH cible(ordre, nom, sig) AS (
  VALUES
    (1, 'admin_delete_etablissement', 'admin_delete_etablissement(text, text)'),
    (2, 'admin_delete_lien_formation', 'admin_delete_lien_formation(text, bigint)'),
    (3, 'admin_delete_message', 'admin_delete_message(text, text)'),
    (4, 'admin_get_visite_stats', 'admin_get_visite_stats(text)'),
    (5, 'admin_lier_photos_logo_demande', 'admin_lier_photos_logo_demande(text, text, text)'),
    (6, 'admin_list_demandes_inscription_etablissements', 'admin_list_demandes_inscription_etablissements(text)'),
    (7, 'admin_list_etablissements_full', 'admin_list_etablissements_full(text)'),
    (8, 'admin_marquer_demande_traitee', 'admin_marquer_demande_traitee(text, text)'),
    (9, 'admin_post_message', 'admin_post_message(text, text, text, text, text, text, text)'),
    (10, 'admin_set_annonce_active', 'admin_set_annonce_active(text, integer, boolean)'),
    (11, 'admin_set_eleve_banni', 'admin_set_eleve_banni(text, text, boolean)'),
    (12, 'admin_set_etab_premium', 'admin_set_etab_premium(text, text, boolean)'),
    (13, 'admin_set_etab_statut', 'admin_set_etab_statut(text, text, text)'),
    (14, 'admin_set_filiere_statut', 'admin_set_filiere_statut(text, text, text, text)'),
    (15, 'admin_set_inspecteur_banni', 'admin_set_inspecteur_banni(text, text, boolean)'),
    (16, 'admin_set_inspecteur_certifie', 'admin_set_inspecteur_certifie(text, text, boolean)'),
    (17, 'admin_supprimer_annonce', 'admin_supprimer_annonce(text, integer)'),
    (18, 'admin_update_etab_classification', 'admin_update_etab_classification(text, text, text, text, text)'),
    (19, 'admin_upsert_annonce', 'admin_upsert_annonce(text, integer, text, text, text)'),
    (20, 'admin_upsert_lien_formation', 'admin_upsert_lien_formation(text, bigint, text, text, text, text, integer)'),
    (21, 'admin_valider_premium', 'admin_valider_premium(text, text)'),
    (22, 'etablissement_add_filiere', 'etablissement_add_filiere(text, text, text, text)'),
    (23, 'etablissement_delete_filiere', 'etablissement_delete_filiere(text, text, text)'),
    (24, 'etablissement_demander_premium', 'etablissement_demander_premium(text, text)'),
    (25, 'etablissement_get_own', 'etablissement_get_own(text, text)'),
    (26, 'etablissement_update_contact_extras', 'etablissement_update_contact_extras(text, text, text, text, text)'),
    (27, 'etablissement_update_info', 'etablissement_update_info(text, text, text, text, text, text, text, text)'),
    (28, 'etablissement_update_localisation', 'etablissement_update_localisation(text, text, text, text, text)'),
    (29, 'etablissement_update_logo', 'etablissement_update_logo(text, text, text)'),
    (30, 'etablissement_update_photos', 'etablissement_update_photos(text, text, jsonb)'),
    (31, 'inspecteur_list_private_messages', 'inspecteur_list_private_messages(text, text)'),
    (32, 'inspecteur_lycam_create_session', 'inspecteur_lycam_create_session(text, text, text)'),
    (33, 'inspecteur_lycam_list_results', 'inspecteur_lycam_list_results(text, text, text)'),
    (34, 'inspecteur_lycam_list_sessions', 'inspecteur_lycam_list_sessions(text, text)'),
    (35, 'inspecteur_lycam_save_result', 'inspecteur_lycam_save_result(text, text, text, text, text, text, text, integer, text, jsonb)'),
    (36, 'inspecteur_mark_private_read', 'inspecteur_mark_private_read(text, text, text)'),
    (37, 'inspecteur_mbti_create_session', 'inspecteur_mbti_create_session(text, text, text)'),
    (38, 'inspecteur_mbti_list_results', 'inspecteur_mbti_list_results(text, text, text)'),
    (39, 'inspecteur_mbti_list_sessions', 'inspecteur_mbti_list_sessions(text, text)'),
    (40, 'inspecteur_mbti_save_result', 'inspecteur_mbti_save_result(text, text, text, text, text, text, text, jsonb, text, jsonb, jsonb)'),
    (41, 'inspecteur_post_message', 'inspecteur_post_message(text, text, text, text, text, text, text, text)'),
    (42, 'inspecteur_post_private_message', 'inspecteur_post_private_message(text, text, text, text, text, text, text)'),
    (43, 'inspecteur_request_certification', 'inspecteur_request_certification(text, text)'),
    (44, 'inspecteur_suivi_add_eleve', 'inspecteur_suivi_add_eleve(text, text, text, text, text, jsonb)'),
    (45, 'inspecteur_suivi_add_note', 'inspecteur_suivi_add_note(text, text, text, text, text)'),
    (46, 'inspecteur_suivi_delete_eleve', 'inspecteur_suivi_delete_eleve(text, text, text)'),
    (47, 'inspecteur_suivi_get_eleve', 'inspecteur_suivi_get_eleve(text, text, text)'),
    (48, 'inspecteur_suivi_list_eleves', 'inspecteur_suivi_list_eleves(text, text)'),
    (49, 'inspecteur_suivi_list_notes', 'inspecteur_suivi_list_notes(text, text, text)'),
    (50, 'inspecteur_suivi_set_appreciation', 'inspecteur_suivi_set_appreciation(text, text, text, text)'),
    (51, 'inspecteur_update_avatar', 'inspecteur_update_avatar(text, text, text)'),
    (52, 'inspecteur_update_email', 'inspecteur_update_email(text, text, text)'),
    (53, 'inspecteur_update_message_accueil', 'inspecteur_update_message_accueil(text, text, text)'),
    (54, 'admin_login', 'admin_login(text)'),
    (55, 'etablissement_claim_by_code', 'etablissement_claim_by_code(text, text, text, text, text, text, text, text, text)'),
    (56, 'etablissement_login', 'etablissement_login(text, text)'),
    (57, 'inspecteur_login', 'inspecteur_login(text, text)')
),
c AS (
  SELECT ordre, nom, sig,
         to_regprocedure('public.' || sig)::oid AS foid,
         '\m' || nom || '\M' AS motif
  FROM cible
),
oids AS (SELECT foid FROM c WHERE foid IS NOT NULL),
deps AS (
  -- Autres fonctions dont le corps cite le nom
  SELECT c.ordre,
         'fonction ' || n.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')' AS d
  FROM c
  JOIN pg_proc p ON p.prosrc ~* c.motif
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname NOT LIKE 'pg\_%'
    AND p.oid NOT IN (SELECT foid FROM oids)
  UNION ALL
  -- Policies RLS
  SELECT c.ordre, 'policy ' || pol.polname || ' sur ' || pol.polrelid::regclass::text
  FROM c
  JOIN pg_policy pol
    ON (coalesce(pg_get_expr(pol.polqual, pol.polrelid), '') || ' ' ||
        coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid), '')) ~* c.motif
  UNION ALL
  -- Vues
  SELECT c.ordre, 'vue ' || v.schemaname || '.' || v.viewname
  FROM c
  JOIN pg_views v ON v.definition ~* c.motif
  WHERE v.schemaname NOT IN ('pg_catalog', 'information_schema')
  UNION ALL
  -- Vues matérialisées
  SELECT c.ordre, 'vue matérialisée ' || m.schemaname || '.' || m.matviewname
  FROM c
  JOIN pg_matviews m ON m.definition ~* c.motif
  UNION ALL
  -- Triggers
  SELECT c.ordre, 'trigger ' || t.tgname || ' sur ' || t.tgrelid::regclass::text
  FROM c
  JOIN pg_trigger t ON t.tgfoid = c.foid
  WHERE NOT t.tgisinternal
  UNION ALL
  -- pg_depend : tout objet qui référence la fonction (hors les 57 elles-mêmes)
  SELECT c.ordre,
         'pg_depend ' || pg_describe_object(d.classid, d.objid, d.objsubid) || ' (type ' || d.deptype || ')'
  FROM c
  JOIN pg_depend d ON d.refclassid = 'pg_proc'::regclass AND d.refobjid = c.foid
  WHERE NOT (d.classid = 'pg_proc'::regclass AND d.objid IN (SELECT foid FROM oids))
),
lignes AS (
  SELECT c.ordre,
         c.sig AS nom,
         CASE WHEN c.foid IS NULL THEN 'NON' ELSE 'oui' END AS existe,
         count(deps.d) AS nb_dependances_hors_liste,
         coalesce(string_agg(deps.d, ' | ' ORDER BY deps.d), '') AS detail
  FROM c
  LEFT JOIN deps ON deps.ordre = c.ordre
  GROUP BY c.ordre, c.sig, c.foid
)
SELECT nom, existe, nb_dependances_hors_liste, detail
FROM (
  SELECT ordre, nom, existe, nb_dependances_hors_liste, detail FROM lignes
  UNION ALL
  SELECT 9999,
         'TOTAL',
         (count(*) FILTER (WHERE existe = 'oui')) || ' existantes / ' || count(*),
         sum(nb_dependances_hors_liste)::bigint,
         (count(*) FILTER (WHERE existe = 'NON')) || ' signature(s) introuvable(s), '
           || (count(*) FILTER (WHERE nb_dependances_hors_liste > 0)) || ' fonction(s) avec dépendances hors liste'
  FROM lignes
) r
ORDER BY ordre;
