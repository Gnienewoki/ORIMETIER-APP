-- ============================================================
-- ORIMETIER — Nettoyage 6c : suppression des anciennes fonctions à mot de passe
-- À exécuter dans le SQL Editor de Supabase APRÈS le test à blanc
-- nettoyage-6c-0 (attendu : 57 existantes, 0 dépendance hors liste).
--
-- 57 DROP FUNCTION, signatures exactes, SANS « IF EXISTS » : une signature
-- fausse fait échouer la transaction entière (rien n'est alors supprimé).
-- Ordre : les 53 fonctions de la catégorie A (ancienne version à mot de passe
-- avec remplaçante _v2), puis admin_login, etablissement_claim_by_code,
-- etablissement_login, inspecteur_login.
-- Non touchées : admin_restore_backup, inspecteur_add_note,
-- inspecteur_lycam_delete_session, inspecteur_mbti_delete_session.
-- Référence : inventaire-fonctions.md (2026-10-17).
-- ============================================================
BEGIN;

-- Catégorie A (53)
DROP FUNCTION public.admin_delete_etablissement(text, text);
DROP FUNCTION public.admin_delete_lien_formation(text, bigint);
DROP FUNCTION public.admin_delete_message(text, text);
DROP FUNCTION public.admin_get_visite_stats(text);
DROP FUNCTION public.admin_lier_photos_logo_demande(text, text, text);
DROP FUNCTION public.admin_list_demandes_inscription_etablissements(text);
DROP FUNCTION public.admin_list_etablissements_full(text);
DROP FUNCTION public.admin_marquer_demande_traitee(text, text);
DROP FUNCTION public.admin_post_message(text, text, text, text, text, text, text);
DROP FUNCTION public.admin_set_annonce_active(text, integer, boolean);
DROP FUNCTION public.admin_set_eleve_banni(text, text, boolean);
DROP FUNCTION public.admin_set_etab_premium(text, text, boolean);
DROP FUNCTION public.admin_set_etab_statut(text, text, text);
DROP FUNCTION public.admin_set_filiere_statut(text, text, text, text);
DROP FUNCTION public.admin_set_inspecteur_banni(text, text, boolean);
DROP FUNCTION public.admin_set_inspecteur_certifie(text, text, boolean);
DROP FUNCTION public.admin_supprimer_annonce(text, integer);
DROP FUNCTION public.admin_update_etab_classification(text, text, text, text, text);
DROP FUNCTION public.admin_upsert_annonce(text, integer, text, text, text);
DROP FUNCTION public.admin_upsert_lien_formation(text, bigint, text, text, text, text, integer);
DROP FUNCTION public.admin_valider_premium(text, text);
DROP FUNCTION public.etablissement_add_filiere(text, text, text, text);
DROP FUNCTION public.etablissement_delete_filiere(text, text, text);
DROP FUNCTION public.etablissement_demander_premium(text, text);
DROP FUNCTION public.etablissement_get_own(text, text);
DROP FUNCTION public.etablissement_update_contact_extras(text, text, text, text, text);
DROP FUNCTION public.etablissement_update_info(text, text, text, text, text, text, text, text);
DROP FUNCTION public.etablissement_update_localisation(text, text, text, text, text);
DROP FUNCTION public.etablissement_update_logo(text, text, text);
DROP FUNCTION public.etablissement_update_photos(text, text, jsonb);
DROP FUNCTION public.inspecteur_list_private_messages(text, text);
DROP FUNCTION public.inspecteur_lycam_create_session(text, text, text);
DROP FUNCTION public.inspecteur_lycam_list_results(text, text, text);
DROP FUNCTION public.inspecteur_lycam_list_sessions(text, text);
DROP FUNCTION public.inspecteur_lycam_save_result(text, text, text, text, text, text, text, integer, text, jsonb);
DROP FUNCTION public.inspecteur_mark_private_read(text, text, text);
DROP FUNCTION public.inspecteur_mbti_create_session(text, text, text);
DROP FUNCTION public.inspecteur_mbti_list_results(text, text, text);
DROP FUNCTION public.inspecteur_mbti_list_sessions(text, text);
DROP FUNCTION public.inspecteur_mbti_save_result(text, text, text, text, text, text, text, jsonb, text, jsonb, jsonb);
DROP FUNCTION public.inspecteur_post_message(text, text, text, text, text, text, text, text);
DROP FUNCTION public.inspecteur_post_private_message(text, text, text, text, text, text, text);
DROP FUNCTION public.inspecteur_request_certification(text, text);
DROP FUNCTION public.inspecteur_suivi_add_eleve(text, text, text, text, text, jsonb);
DROP FUNCTION public.inspecteur_suivi_add_note(text, text, text, text, text);
DROP FUNCTION public.inspecteur_suivi_delete_eleve(text, text, text);
DROP FUNCTION public.inspecteur_suivi_get_eleve(text, text, text);
DROP FUNCTION public.inspecteur_suivi_list_eleves(text, text);
DROP FUNCTION public.inspecteur_suivi_list_notes(text, text, text);
DROP FUNCTION public.inspecteur_suivi_set_appreciation(text, text, text, text);
DROP FUNCTION public.inspecteur_update_avatar(text, text, text);
DROP FUNCTION public.inspecteur_update_email(text, text, text);
DROP FUNCTION public.inspecteur_update_message_accueil(text, text, text);

-- Sans remplaçante _v2 (4), APRÈS les 53 : admin_delete_etablissement et
-- admin_update_etab_classification (ci-dessus) appellent admin_login.
DROP FUNCTION public.admin_login(text);
DROP FUNCTION public.etablissement_claim_by_code(text, text, text, text, text, text, text, text, text);
DROP FUNCTION public.etablissement_login(text, text);
DROP FUNCTION public.inspecteur_login(text, text);

COMMIT;

-- Contrôle (lecture seule) : fonctions du schéma public dont les arguments
-- contiennent p_password ou p_admin_password. Attendu : 11 lignes :
--   admin_create_admin_v2(p_token text, p_nom text, p_email text, p_password text)
--   admin_restore_backup(p_admin_password text, p_payload jsonb)
--   admin_session_open(p_email text, p_password text)
--   eleve_session_open(p_tel text, p_password text)
--   etablissement_claim_v2(p_etab_id text, p_code text, p_email text, p_password text, p_responsable text, p_tel text, p_tel2 text, p_tel3 text, p_site_web text, p_contact_tel text)
--   etablissement_register(p_id text, p_nom text, p_region text, p_ville text, p_quartier text, p_type text, p_responsable text, p_tel text, p_email text, p_password text, p_date_inscription text, p_filieres_proposees jsonb, p_photos jsonb, p_categorie text, p_sous_categorie text, p_secteur text, p_tel2 text, p_tel3 text, p_site_web text, p_contact_tel text, p_logo_url text)
--   etablissement_session_open(p_email text, p_password text)
--   inspecteur_add_note(p_inspecteur_id text, p_password text, p_eleve_id text, p_texte text)
--   inspecteur_lycam_delete_session(p_inspecteur_id text, p_password text, p_session_id text)
--   inspecteur_mbti_delete_session(p_inspecteur_id text, p_password text, p_session_id text)
--   inspecteur_session_open(p_tel text, p_password text)
SELECT p.proname AS fonction, pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND pg_get_function_identity_arguments(p.oid) ~ '\mp_(admin_)?password\M'
ORDER BY 1, 2;
