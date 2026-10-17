-- ============================================================
-- ORIMETIER — Phase 7a-2b : RPC inspecteur par jeton, lot 2 : tests LYCAM,
-- MBTI et suivi des élèves (15 fonctions _v2). FICHIER TOUT-EN-UN.
--
-- À coller et lancer UNE SEULE FOIS dans le SQL Editor de Supabase. Il enchaîne :
--   1) la migration (BEGIN ... COMMIT) ;
--   2) le test fonctionnel complet (BEGIN ... DO ... ROLLBACK : aucune trace) ;
--   3) une requête finale (n, controle, ok) : TOUTES les lignes doivent valoir true.
-- Si une étape du test échoue, l'exécution s'arrête sur "ÉCHEC ..." et la requête
-- finale n'est pas affichée. La migration (partie 1) reste alors en place : elle est
-- additive et rejouable, le fichier peut être relancé tel quel après correction.
--
-- Pré-requis : 7a-1 exécutée (inspecteur_session_open, trigger
-- trg_inspecteurs_revoke_sessions). 7a-2a n'est pas nécessaire à ce lot.
-- Migration ADDITIVE : les anciennes fonctions (p_inspecteur_id + p_password),
-- inspecteur_login et les 3 fonctions mortes (inspecteur_lycam_delete_session,
-- inspecteur_mbti_delete_session, inspecteur_add_note) ne sont ni modifiées,
-- ni supprimées, ni recréées.
--
-- Source : code de PRODUCTION du 03/10/2026
-- (prod-inspecteur-fonctions-2026-10-03.csv). Les 15 fonctions de production
-- sont identiques à supabase/reference/live-2026-09-26.sql (l. 958-1403),
-- une seule signature chacune (comparaison automatique : comparaison-7a-2b.md).
--
-- Nouvelles fonctions :
--   inspecteur_lycam_create_session_v2(p_token, p_nom)                         -> text (id lyc…)
--   inspecteur_lycam_save_result_v2(p_token, p_session_id, p_nom, p_prenom, p_naissance,
--                                   p_classe, p_score_total integer, p_band, p_scores jsonb) -> boolean
--   inspecteur_lycam_list_sessions_v2(p_token)                                 -> SETOF lycam_sessions
--   inspecteur_lycam_list_results_v2(p_token, p_session_id)                    -> SETOF lycam_resultats
--   inspecteur_mbti_create_session_v2(p_token, p_nom)                          -> text (id mbt…)
--   inspecteur_mbti_save_result_v2(p_token, p_session_id, p_nom, p_prenom, p_naissance,
--                                  p_classe, p_scores jsonb, p_type_letters text,
--                                  p_hierarchie jsonb, p_egalites jsonb)     -> boolean
--   inspecteur_mbti_list_sessions_v2(p_token)                                  -> SETOF mbti_sessions
--   inspecteur_mbti_list_results_v2(p_token, p_session_id)                     -> SETOF mbti_resultats
--   inspecteur_suivi_add_eleve_v2(p_token, p_nom, p_prenoms, p_classe, p_raisons jsonb) -> text (uuid)
--   inspecteur_suivi_list_eleves_v2(p_token)                                   -> TABLE(...)
--   inspecteur_suivi_get_eleve_v2(p_token, p_suivi_id)                         -> TABLE(...)
--   inspecteur_suivi_delete_eleve_v2(p_token, p_suivi_id)                      -> boolean
--   inspecteur_suivi_set_appreciation_v2(p_token, p_suivi_id, p_appreciation)  -> boolean
--   inspecteur_suivi_add_note_v2(p_token, p_suivi_id, p_date_note, p_texte)    -> boolean
--   inspecteur_suivi_list_notes_v2(p_token, p_suivi_id)                        -> TABLE(id, date_note, texte)
--
-- DIFFÉRENCES AVEC LA PRODUCTION (et seulement celles-ci) :
--   1. Authentification : p_inspecteur_id et p_password disparaissent. La fiche
--      est celle du jeton : v_insp_id := _session_user(p_token, 'inspecteur'),
--      appelée EN PREMIER, qui lève SESSION_INVALIDE (P0401) si le jeton est
--      inconnu, expiré, révoqué, d'un autre rôle, si la fiche n'existe plus ou
--      si elle est bannie. Dans chaque contrôle existant, "id = p_inspecteur_id
--      and password = extensions.crypt(...)" devient "id = v_insp_id", et
--      chaque "inspecteur_id = p_inspecteur_id" devient "inspecteur_id = v_insp_id".
--      Les contrôles existants (banni, appartenance, raise 'unauthorized') sont
--      CONSERVÉS tels quels, même redondants avec _session_user.
--      Nom de variable : v_insp_id (et non v_id), car la production utilise
--      déjà v_id pour l'id généré (create_session : 'lyc…' / 'mbt…' ;
--      suivi_add_eleve : uuid). Dans les RETURNS TABLE, ce nom ne heurte aucune
--      colonne de sortie (id, nom, prenoms, classe, raisons, appreciation_finale,
--      date_ajout, date_note, texte).
--   2. SET search_path TO 'public' ajouté sur les 8 fonctions LYCAM/MBTI (absent
--      en production ; déjà présent sur les 7 fonctions de suivi).
--   Le reste de chaque corps est recopié à l'identique : valeurs de retour
--   (null / false / ensemble vide / found), raise 'unauthorized' et messages
--   métier du suivi, contrôle de l'appartenance d'une session LYCAM/MBTI et
--   d'une fiche de suivi, format des id ('lyc', 'lycr', 'mbt', 'mbtr' + 16
--   caractères md5 ; uuid pour le suivi), alias s. / n. / inspecteurs. /
--   suivi_eleves. des RETURNS TABLE (piège d'ambiguïté de la colonne id).
--
-- COMPORTEMENTS EXISTANTS CONSERVÉS VOLONTAIREMENT (à revoir en Phase 8) :
--   - LYCAM/MBTI : list_sessions et list_results ne refusaient pas le banni
--     (désormais refusé par _session_user) ; un session_id d'un autre
--     inspecteur renvoie un ensemble vide / false, sans erreur ; aucune
--     validation des champs (nom de session, identité, scores, bande, type).
--   - MBTI save_result : p_egalites NULL enregistré en '[]'.
--   - suivi_get_eleve : une fiche d'un autre inspecteur renvoie 0 ligne (pas
--     d'erreur), alors que suivi_list_notes et suivi_add_note lèvent
--     'unauthorized' dans le même cas.
--   - suivi_delete_eleve / suivi_set_appreciation : fiche d'un autre
--     inspecteur ou inexistante -> false (found), sans erreur.
--   - suivi : p_suivi_id non uuid -> erreur de conversion brute (22P02).
--   - suivi_add_note : date libre (JJ/MM/AAAA attendu mais non contrôlé ; une
--     date mal formée fera échouer le tri de suivi_list_notes).
--   - suivi_set_appreciation : chaîne vide -> NULL.
--
-- Droits : SECURITY DEFINER, SET search_path TO 'public', REVOKE ALL FROM
-- public, GRANT EXECUTE TO anon, authenticated. Rejouable : CREATE OR REPLACE.
-- ============================================================


-- ############################################################
-- PARTIE 1 : MIGRATION
-- ############################################################

BEGIN;

-- 0) Garde-fous : 7a-1 exécutée
DO $$
begin
  if to_regprocedure('public._session_user(text,text)') is null then
    raise exception '_session_user absente : exécuter d''abord la Phase 1';
  end if;
  if to_regprocedure('public.inspecteur_session_open(text,text)') is null then
    raise exception 'inspecteur_session_open absente : exécuter d''abord la migration 7a-1';
  end if;
  if not exists (select 1 from pg_trigger t
                 where t.tgrelid = 'public.inspecteurs'::regclass
                   and t.tgname = 'trg_inspecteurs_revoke_sessions') then
    raise exception 'trigger trg_inspecteurs_revoke_sessions absent : exécuter d''abord la migration 7a-1';
  end if;
end $$;

-- ------------------------------------------------------------
-- 1) inspecteur_lycam_create_session_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_lycam_create_session_v2(p_token text, p_nom text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_insp_id text;
  v_ok boolean;
  v_id text;
begin
  v_insp_id := _session_user(p_token, 'inspecteur');
  select exists(
    select 1 from inspecteurs where id = v_insp_id and coalesce(banni,false) = false
  ) into v_ok;
  if not v_ok then return null; end if;

  v_id := 'lyc' || substr(md5(random()::text || clock_timestamp()::text), 1, 16);
  insert into lycam_sessions(id, inspecteur_id, nom) values (v_id, v_insp_id, p_nom);
  return v_id;
end;
$function$;

REVOKE ALL ON FUNCTION public.inspecteur_lycam_create_session_v2(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_lycam_create_session_v2(text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 2) inspecteur_lycam_save_result_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_lycam_save_result_v2(p_token text, p_session_id text, p_nom text, p_prenom text, p_naissance text, p_classe text, p_score_total integer, p_band text, p_scores jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_insp_id text;
  v_ok boolean;
begin
  v_insp_id := _session_user(p_token, 'inspecteur');
  select exists(
    select 1 from inspecteurs where id = v_insp_id and coalesce(banni,false) = false
  ) into v_ok;
  if not v_ok then return false; end if;

  if not exists(select 1 from lycam_sessions where id = p_session_id and inspecteur_id = v_insp_id) then
    return false;
  end if;

  insert into lycam_resultats(id, session_id, inspecteur_id, nom, prenom, naissance, classe, score_total, band, scores)
  values (
    'lycr' || substr(md5(random()::text || clock_timestamp()::text), 1, 16),
    p_session_id, v_insp_id, p_nom, p_prenom, p_naissance, p_classe, p_score_total, p_band, p_scores
  );
  return true;
end;
$function$;

REVOKE ALL ON FUNCTION public.inspecteur_lycam_save_result_v2(text, text, text, text, text, text, integer, text, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_lycam_save_result_v2(text, text, text, text, text, text, integer, text, jsonb) TO anon, authenticated;

-- ------------------------------------------------------------
-- 3) inspecteur_lycam_list_sessions_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_lycam_list_sessions_v2(p_token text)
 RETURNS SETOF lycam_sessions
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_insp_id text;
begin
  v_insp_id := _session_user(p_token, 'inspecteur');
  if not exists(select 1 from inspecteurs where id = v_insp_id) then
    return;
  end if;
  return query select * from lycam_sessions where inspecteur_id = v_insp_id order by created_at desc;
end;
$function$;

REVOKE ALL ON FUNCTION public.inspecteur_lycam_list_sessions_v2(text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_lycam_list_sessions_v2(text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 4) inspecteur_lycam_list_results_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_lycam_list_results_v2(p_token text, p_session_id text)
 RETURNS SETOF lycam_resultats
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_insp_id text;
begin
  v_insp_id := _session_user(p_token, 'inspecteur');
  if not exists(select 1 from inspecteurs where id = v_insp_id) then
    return;
  end if;
  if not exists(select 1 from lycam_sessions where id = p_session_id and inspecteur_id = v_insp_id) then
    return;
  end if;
  return query select * from lycam_resultats where session_id = p_session_id order by created_at asc;
end;
$function$;

REVOKE ALL ON FUNCTION public.inspecteur_lycam_list_results_v2(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_lycam_list_results_v2(text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 5) inspecteur_mbti_create_session_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_mbti_create_session_v2(p_token text, p_nom text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_insp_id text;
  v_ok boolean;
  v_id text;
begin
  v_insp_id := _session_user(p_token, 'inspecteur');
  select exists(
    select 1 from inspecteurs where id = v_insp_id and coalesce(banni,false) = false
  ) into v_ok;
  if not v_ok then return null; end if;

  v_id := 'mbt' || substr(md5(random()::text || clock_timestamp()::text), 1, 16);
  insert into mbti_sessions(id, inspecteur_id, nom) values (v_id, v_insp_id, p_nom);
  return v_id;
end;
$function$;

REVOKE ALL ON FUNCTION public.inspecteur_mbti_create_session_v2(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_mbti_create_session_v2(text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 6) inspecteur_mbti_save_result_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_mbti_save_result_v2(p_token text, p_session_id text, p_nom text, p_prenom text, p_naissance text, p_classe text, p_scores jsonb, p_type_letters text, p_hierarchie jsonb, p_egalites jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_insp_id text;
  v_ok boolean;
begin
  v_insp_id := _session_user(p_token, 'inspecteur');
  select exists(
    select 1 from inspecteurs where id = v_insp_id and coalesce(banni,false) = false
  ) into v_ok;
  if not v_ok then return false; end if;

  if not exists(select 1 from mbti_sessions where id = p_session_id and inspecteur_id = v_insp_id) then
    return false;
  end if;

  insert into mbti_resultats(id, session_id, inspecteur_id, nom, prenom, naissance, classe, scores, type_letters, hierarchie, egalites)
  values (
    'mbtr' || substr(md5(random()::text || clock_timestamp()::text), 1, 16),
    p_session_id, v_insp_id, p_nom, p_prenom, p_naissance, p_classe, p_scores, p_type_letters, p_hierarchie, coalesce(p_egalites, '[]'::jsonb)
  );
  return true;
end;
$function$;

REVOKE ALL ON FUNCTION public.inspecteur_mbti_save_result_v2(text, text, text, text, text, text, jsonb, text, jsonb, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_mbti_save_result_v2(text, text, text, text, text, text, jsonb, text, jsonb, jsonb) TO anon, authenticated;

-- ------------------------------------------------------------
-- 7) inspecteur_mbti_list_sessions_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_mbti_list_sessions_v2(p_token text)
 RETURNS SETOF mbti_sessions
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_insp_id text;
begin
  v_insp_id := _session_user(p_token, 'inspecteur');
  if not exists(select 1 from inspecteurs where id = v_insp_id) then
    return;
  end if;
  return query select * from mbti_sessions where inspecteur_id = v_insp_id order by created_at desc;
end;
$function$;

REVOKE ALL ON FUNCTION public.inspecteur_mbti_list_sessions_v2(text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_mbti_list_sessions_v2(text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 8) inspecteur_mbti_list_results_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_mbti_list_results_v2(p_token text, p_session_id text)
 RETURNS SETOF mbti_resultats
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_insp_id text;
begin
  v_insp_id := _session_user(p_token, 'inspecteur');
  if not exists(select 1 from inspecteurs where id = v_insp_id) then
    return;
  end if;
  if not exists(select 1 from mbti_sessions where id = p_session_id and inspecteur_id = v_insp_id) then
    return;
  end if;
  return query select * from mbti_resultats where session_id = p_session_id order by created_at asc;
end;
$function$;

REVOKE ALL ON FUNCTION public.inspecteur_mbti_list_results_v2(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_mbti_list_results_v2(text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 9) inspecteur_suivi_add_eleve_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_suivi_add_eleve_v2(p_token text, p_nom text, p_prenoms text, p_classe text, p_raisons jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_insp_id text;
  v_id uuid;
begin
  v_insp_id := _session_user(p_token, 'inspecteur');
  if not exists (
    select 1 from inspecteurs
    where id = v_insp_id and coalesce(banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  if coalesce(trim(p_nom), '') = '' or coalesce(trim(p_classe), '') = '' then
    raise exception 'Nom et classe sont obligatoires';
  end if;

  if p_raisons is null or jsonb_typeof(p_raisons) <> 'array' or jsonb_array_length(p_raisons) = 0 then
    raise exception 'Au moins une raison de suivi est obligatoire';
  end if;

  if exists (
    select 1 from jsonb_array_elements_text(p_raisons) as r
    where r not in ('IE','AF','RS','CS','AB','BS','PS')
  ) then
    raise exception 'Raison de suivi invalide';
  end if;

  insert into suivi_eleves(inspecteur_id, nom, prenoms, classe, raisons)
    values (v_insp_id, trim(p_nom), nullif(trim(p_prenoms), ''), trim(p_classe), p_raisons)
    returning id into v_id;

  return v_id::text;
end; $function$;

REVOKE ALL ON FUNCTION public.inspecteur_suivi_add_eleve_v2(text, text, text, text, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_suivi_add_eleve_v2(text, text, text, text, jsonb) TO anon, authenticated;

-- ------------------------------------------------------------
-- 10) inspecteur_suivi_list_eleves_v2 (RETURNS TABLE : alias obligatoires)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_suivi_list_eleves_v2(p_token text)
 RETURNS TABLE(id text, nom text, prenoms text, classe text, raisons jsonb, appreciation_finale text, date_ajout text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_insp_id text;
begin
  v_insp_id := _session_user(p_token, 'inspecteur');
  if not exists (
    select 1 from inspecteurs
    where inspecteurs.id = v_insp_id and coalesce(inspecteurs.banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  return query
    select s.id::text, s.nom, s.prenoms, s.classe, s.raisons, s.appreciation_finale, s.date_ajout
    from suivi_eleves s
    where s.inspecteur_id = v_insp_id
    order by s.nom asc, s.prenoms asc;
end; $function$;

REVOKE ALL ON FUNCTION public.inspecteur_suivi_list_eleves_v2(text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_suivi_list_eleves_v2(text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 11) inspecteur_suivi_get_eleve_v2 (RETURNS TABLE : alias obligatoires)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_suivi_get_eleve_v2(p_token text, p_suivi_id text)
 RETURNS TABLE(id text, nom text, prenoms text, classe text, raisons jsonb, appreciation_finale text, date_ajout text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_insp_id text;
begin
  v_insp_id := _session_user(p_token, 'inspecteur');
  if not exists (
    select 1 from inspecteurs
    where inspecteurs.id = v_insp_id and coalesce(inspecteurs.banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  return query
    select s.id::text, s.nom, s.prenoms, s.classe, s.raisons, s.appreciation_finale, s.date_ajout
    from suivi_eleves s
    where s.id = p_suivi_id::uuid and s.inspecteur_id = v_insp_id;
end; $function$;

REVOKE ALL ON FUNCTION public.inspecteur_suivi_get_eleve_v2(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_suivi_get_eleve_v2(text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 12) inspecteur_suivi_delete_eleve_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_suivi_delete_eleve_v2(p_token text, p_suivi_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_insp_id text;
begin
  v_insp_id := _session_user(p_token, 'inspecteur');
  if not exists (
    select 1 from inspecteurs
    where id = v_insp_id and coalesce(banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  delete from suivi_eleves where id = p_suivi_id::uuid and inspecteur_id = v_insp_id;
  return found;
end; $function$;

REVOKE ALL ON FUNCTION public.inspecteur_suivi_delete_eleve_v2(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_suivi_delete_eleve_v2(text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 13) inspecteur_suivi_set_appreciation_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_suivi_set_appreciation_v2(p_token text, p_suivi_id text, p_appreciation text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_insp_id text;
begin
  v_insp_id := _session_user(p_token, 'inspecteur');
  if not exists (
    select 1 from inspecteurs
    where id = v_insp_id and coalesce(banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  update suivi_eleves
    set appreciation_finale = nullif(trim(p_appreciation), '')
    where id = p_suivi_id::uuid and inspecteur_id = v_insp_id;
  return found;
end; $function$;

REVOKE ALL ON FUNCTION public.inspecteur_suivi_set_appreciation_v2(text, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_suivi_set_appreciation_v2(text, text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 14) inspecteur_suivi_add_note_v2
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_suivi_add_note_v2(p_token text, p_suivi_id text, p_date_note text, p_texte text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_insp_id text;
begin
  v_insp_id := _session_user(p_token, 'inspecteur');
  if not exists (
    select 1 from inspecteurs
    where id = v_insp_id and coalesce(banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  if not exists (select 1 from suivi_eleves where id = p_suivi_id::uuid and inspecteur_id = v_insp_id) then
    raise exception 'unauthorized';
  end if;

  if coalesce(trim(p_date_note), '') = '' or coalesce(trim(p_texte), '') = '' then
    raise exception 'Date et texte de la note sont obligatoires';
  end if;

  insert into suivi_eleves_notes(suivi_eleve_id, date_note, texte)
    values (p_suivi_id::uuid, trim(p_date_note), trim(p_texte));
  return true;
end; $function$;

REVOKE ALL ON FUNCTION public.inspecteur_suivi_add_note_v2(text, text, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_suivi_add_note_v2(text, text, text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 15) inspecteur_suivi_list_notes_v2 (RETURNS TABLE : alias obligatoires)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteur_suivi_list_notes_v2(p_token text, p_suivi_id text)
 RETURNS TABLE(id text, date_note text, texte text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_insp_id text;
begin
  v_insp_id := _session_user(p_token, 'inspecteur');
  if not exists (
    select 1 from inspecteurs
    where inspecteurs.id = v_insp_id and coalesce(inspecteurs.banni, false) = false
  ) then
    raise exception 'unauthorized';
  end if;

  if not exists (
    select 1 from suivi_eleves
    where suivi_eleves.id = p_suivi_id::uuid and suivi_eleves.inspecteur_id = v_insp_id
  ) then
    raise exception 'unauthorized';
  end if;

  return query
    select n.id::text, n.date_note, n.texte
    from suivi_eleves_notes n
    where n.suivi_eleve_id = p_suivi_id::uuid
    order by to_date(n.date_note, 'DD/MM/YYYY') asc, n.created_at asc;
end; $function$;

REVOKE ALL ON FUNCTION public.inspecteur_suivi_list_notes_v2(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_suivi_list_notes_v2(text, text) TO anon, authenticated;

COMMIT;


-- ############################################################
-- PARTIE 2 : TEST FONCTIONNEL COMPLET (ROLLBACK : aucune trace)
-- ############################################################
-- Fiches créées dans la transaction (mots de passe hachés par trg_hash_password) :
--   test_7a2b_a : TEST7A2B Alpha,   tel T7A2B-0001, mot de passe mdp-a-7a2b
--   test_7a2b_b : TEST7A2B Bravo,   tel T7A2B-0002, mot de passe mdp-b-7a2b
--   test_7a2b_c : TEST7A2B Charlie, tel T7A2B-0003, mot de passe mdp-c-7a2b, BANNI
-- Règle suivie : un appel de fonction et la lecture de table qui le contrôle sont
-- toujours deux instructions séparées ; comparaisons en IS DISTINCT FROM.

BEGIN;

insert into public.inspecteurs(id, nom, prenoms, fonction, cio, tel, email, password, active, date_inscription, banni)
values
  ('test_7a2b_a', 'TEST7A2B', 'Alpha', 'Inspecteur d''orientation', 'CIO Test', 'T7A2B-0001',
   'test-7a2b-a@exemple.invalid', 'mdp-a-7a2b', true, '03/10/2026', false),
  ('test_7a2b_b', 'TEST7A2B', 'Bravo', 'Inspecteur d''orientation', 'CIO Test', 'T7A2B-0002',
   'test-7a2b-b@exemple.invalid', 'mdp-b-7a2b', true, '03/10/2026', false),
  ('test_7a2b_c', 'TEST7A2B', 'Charlie', 'Inspecteur d''orientation', 'CIO Test', 'T7A2B-0003',
   'test-7a2b-c@exemple.invalid', 'mdp-c-7a2b', true, '03/10/2026', true);

-- Session d'un AUTRE rôle (élève), insérée directement : _session_user filtre
-- sur le rôle avant toute chose, l'élève n'a pas besoin d'exister.
insert into public.sessions(token_hash, role, user_id, expires_at)
values (encode(extensions.digest('jeton-eleve-test-7a2b', 'sha256'), 'hex'), 'eleve', 'test_7a2b_eleve', now() + interval '1 day');

DO $$
declare
  r jsonb;
  tA text; tB text; tA2 text;
  t_inconnu text := 'jeton-inconnu-test-7a2b';
  t_eleve text := 'jeton-eleve-test-7a2b';
  v_tok text; v_sql text; v_err text; v_state text;
  lycA text; mbtA text; lycB text; mbtB text;
  fA1 text; fA2 text; fB1 text;
  v_n integer; v_txt text; v_j jsonb;
  ok boolean;
begin
  -- 0. Sessions
  r := public.inspecteur_session_open('T7A2B-0001', 'mdp-a-7a2b');
  tA := r->>'token';
  r := public.inspecteur_session_open('T7A2B-0002', 'mdp-b-7a2b');
  tB := r->>'token';
  if tA is null or tB is null then raise exception 'ÉCHEC 0 ouverture des sessions de test'; end if;
  r := public.inspecteur_session_open('T7A2B-0003', 'mdp-c-7a2b');
  if r is distinct from '{"banni": true}'::jsonb then raise exception 'ÉCHEC 0 le banni a obtenu : %', r; end if;
  raise notice '0. sessions A et B ouvertes, C (banni) sans session';

  -- 1. LYCAM : création, résultat, listes
  lycA := public.inspecteur_lycam_create_session_v2(tA, 'Session LYCAM A 7a2b');
  if lycA is null or lycA !~ '^lyc[0-9a-f]{16}$' then raise exception 'ÉCHEC 1 id de session LYCAM : %', lycA; end if;
  select count(*) into v_n from public.lycam_sessions ls
    where ls.id = lycA and ls.inspecteur_id = 'test_7a2b_a' and ls.nom = 'Session LYCAM A 7a2b';
  if v_n is distinct from 1 then raise exception 'ÉCHEC 1 session LYCAM non enregistrée'; end if;
  ok := public.inspecteur_lycam_save_result_v2(tA, lycA, 'Kone', 'Awa', '01/01/2010', '3e', 42, 'moyen', '{"IE": 3}'::jsonb);
  if ok is not true then raise exception 'ÉCHEC 1 lycam_save_result_v2 a renvoyé %', ok; end if;
  select count(*) into v_n from public.lycam_resultats lr
    where lr.session_id = lycA and lr.inspecteur_id = 'test_7a2b_a' and lr.id ~ '^lycr[0-9a-f]{16}$'
      and lr.nom = 'Kone' and lr.score_total = 42 and lr.band = 'moyen' and lr.scores = '{"IE": 3}'::jsonb;
  if v_n is distinct from 1 then raise exception 'ÉCHEC 1 résultat LYCAM mal enregistré'; end if;
  select count(*) into v_n from public.inspecteur_lycam_list_sessions_v2(tA);
  if v_n is distinct from 1 then raise exception 'ÉCHEC 1 A voit % session(s) LYCAM, 1 attendue', v_n; end if;
  select count(*) into v_n from public.inspecteur_lycam_list_results_v2(tA, lycA);
  if v_n is distinct from 1 then raise exception 'ÉCHEC 1 A voit % résultat(s) LYCAM, 1 attendu', v_n; end if;
  ok := public.inspecteur_lycam_save_result_v2(tA, 'lyc_inexistante', 'X', 'Y', null, null, 1, 'b', '{}'::jsonb);
  if ok is not false then raise exception 'ÉCHEC 1 résultat accepté sur une session inexistante'; end if;
  raise notice '1. LYCAM : création (lyc + 16 hex), résultat (lycr…), listes : OK ; session inexistante refusée';

  -- 2. MBTI : création, résultat (égalités NULL -> []), listes
  mbtA := public.inspecteur_mbti_create_session_v2(tA, 'Session MBTI A 7a2b');
  if mbtA is null or mbtA !~ '^mbt[0-9a-f]{16}$' then raise exception 'ÉCHEC 2 id de session MBTI : %', mbtA; end if;
  select count(*) into v_n from public.mbti_sessions ms
    where ms.id = mbtA and ms.inspecteur_id = 'test_7a2b_a';
  if v_n is distinct from 1 then raise exception 'ÉCHEC 2 session MBTI non enregistrée'; end if;
  ok := public.inspecteur_mbti_save_result_v2(tA, mbtA, 'Kone', 'Awa', '01/01/2010', '3e',
          '{"E": 5}'::jsonb, 'ENFP', '["E","N"]'::jsonb, null);
  if ok is not true then raise exception 'ÉCHEC 2 mbti_save_result_v2 a renvoyé %', ok; end if;
  select count(*) into v_n from public.mbti_resultats mr
    where mr.session_id = mbtA and mr.inspecteur_id = 'test_7a2b_a' and mr.id ~ '^mbtr[0-9a-f]{16}$'
      and mr.type_letters = 'ENFP' and mr.egalites = '[]'::jsonb;
  if v_n is distinct from 1 then raise exception 'ÉCHEC 2 résultat MBTI mal enregistré (égalités NULL -> [] attendu)'; end if;
  select count(*) into v_n from public.inspecteur_mbti_list_sessions_v2(tA);
  if v_n is distinct from 1 then raise exception 'ÉCHEC 2 A voit % session(s) MBTI, 1 attendue', v_n; end if;
  select count(*) into v_n from public.inspecteur_mbti_list_results_v2(tA, mbtA);
  if v_n is distinct from 1 then raise exception 'ÉCHEC 2 A voit % résultat(s) MBTI, 1 attendu', v_n; end if;
  raise notice '2. MBTI : création (mbt…), résultat (mbtr…, égalités NULL -> []), listes : OK';

  -- 3. Suivi : ajout (trim, prénoms vides -> NULL), contrôles métier
  fA1 := public.inspecteur_suivi_add_eleve_v2(tA, ' Kone ', ' Awa ', ' 3e ', '["IE","AB"]'::jsonb);
  fA2 := public.inspecteur_suivi_add_eleve_v2(tA, 'Bamba', '', '2nde', '["PS"]'::jsonb);
  if fA1 is null or fA2 is null then raise exception 'ÉCHEC 3 ajout de fiche de suivi'; end if;
  select count(*) into v_n from public.suivi_eleves s
    where s.id = fA1::uuid and s.inspecteur_id = 'test_7a2b_a' and s.nom = 'Kone' and s.prenoms = 'Awa'
      and s.classe = '3e' and s.raisons = '["IE","AB"]'::jsonb;
  if v_n is distinct from 1 then raise exception 'ÉCHEC 3 fiche fA1 mal enregistrée'; end if;
  select s.prenoms into v_txt from public.suivi_eleves s where s.id = fA2::uuid;
  if v_txt is not null then raise exception 'ÉCHEC 3 prénoms vides non convertis en NULL : %', v_txt; end if;
  v_err := null;
  begin perform public.inspecteur_suivi_add_eleve_v2(tA, '  ', 'X', '3e', '["IE"]'::jsonb);
  exception when others then v_err := sqlerrm; end;
  if v_err is distinct from 'Nom et classe sont obligatoires' then raise exception 'ÉCHEC 3 nom vide : %', coalesce(v_err, 'aucune erreur'); end if;
  v_err := null;
  begin perform public.inspecteur_suivi_add_eleve_v2(tA, 'X', 'X', '3e', '[]'::jsonb);
  exception when others then v_err := sqlerrm; end;
  if v_err is distinct from 'Au moins une raison de suivi est obligatoire' then raise exception 'ÉCHEC 3 raisons vides : %', coalesce(v_err, 'aucune erreur'); end if;
  v_err := null;
  begin perform public.inspecteur_suivi_add_eleve_v2(tA, 'X', 'X', '3e', '["XX"]'::jsonb);
  exception when others then v_err := sqlerrm; end;
  if v_err is distinct from 'Raison de suivi invalide' then raise exception 'ÉCHEC 3 raison invalide : %', coalesce(v_err, 'aucune erreur'); end if;
  raise notice '3. suivi_add_eleve_v2 : OK (trim, prénoms vides -> NULL) ; nom vide, raisons vides, raison invalide refusés';

  -- 4. Suivi : liste, lecture, notes, appréciation
  select count(*) into v_n from public.inspecteur_suivi_list_eleves_v2(tA);
  if v_n is distinct from 2 then raise exception 'ÉCHEC 4 A voit % fiche(s), 2 attendues', v_n; end if;
  select x.id into v_txt from public.inspecteur_suivi_list_eleves_v2(tA) x limit 1;
  if v_txt is distinct from fA2 then raise exception 'ÉCHEC 4 tri par nom : première fiche % (Bamba attendue)', v_txt; end if;
  select to_jsonb(x) into v_j from public.inspecteur_suivi_get_eleve_v2(tA, fA1) x;
  if (v_j->>'id') is distinct from fA1 or (v_j->>'nom') is distinct from 'Kone' then raise exception 'ÉCHEC 4 get_eleve_v2 : %', v_j; end if;
  ok := public.inspecteur_suivi_add_note_v2(tA, fA1, '05/10/2026', ' Note deux ');
  if ok is not true then raise exception 'ÉCHEC 4 add_note_v2 a renvoyé %', ok; end if;
  ok := public.inspecteur_suivi_add_note_v2(tA, fA1, '01/10/2026', 'Note une');
  if ok is not true then raise exception 'ÉCHEC 4 add_note_v2 (2) a renvoyé %', ok; end if;
  v_err := null;
  begin perform public.inspecteur_suivi_add_note_v2(tA, fA1, '01/10/2026', '  ');
  exception when others then v_err := sqlerrm; end;
  if v_err is distinct from 'Date et texte de la note sont obligatoires' then raise exception 'ÉCHEC 4 note vide : %', coalesce(v_err, 'aucune erreur'); end if;
  select count(*) into v_n from public.inspecteur_suivi_list_notes_v2(tA, fA1);
  if v_n is distinct from 2 then raise exception 'ÉCHEC 4 % note(s), 2 attendues', v_n; end if;
  select x.texte into v_txt from public.inspecteur_suivi_list_notes_v2(tA, fA1) x limit 1;
  if v_txt is distinct from 'Note une' then raise exception 'ÉCHEC 4 tri des notes par date : % en premier', v_txt; end if;
  ok := public.inspecteur_suivi_set_appreciation_v2(tA, fA1, ' Bien ');
  if ok is not true then raise exception 'ÉCHEC 4 set_appreciation_v2 a renvoyé %', ok; end if;
  select s.appreciation_finale into v_txt from public.suivi_eleves s where s.id = fA1::uuid;
  if v_txt is distinct from 'Bien' then raise exception 'ÉCHEC 4 appréciation enregistrée : %', v_txt; end if;
  raise notice '4. suivi : liste (triée), lecture, 2 notes (triées par date), appréciation : OK';

  -- 5. ISOLATION : B ne voit, ne lit, ne modifie ni ne supprime rien de A
  lycB := public.inspecteur_lycam_create_session_v2(tB, 'Session LYCAM B 7a2b');
  mbtB := public.inspecteur_mbti_create_session_v2(tB, 'Session MBTI B 7a2b');
  fB1 := public.inspecteur_suivi_add_eleve_v2(tB, 'Traore', 'Ali', '1re', '["CS"]'::jsonb);
  if lycB is null or mbtB is null or fB1 is null then raise exception 'ÉCHEC 5 création des données de B'; end if;
  -- LYCAM / MBTI
  select count(*) into v_n from public.inspecteur_lycam_list_sessions_v2(tB) x where x.inspecteur_id is distinct from 'test_7a2b_b';
  if v_n is distinct from 0 then raise exception 'ÉCHEC 5 B voit une session LYCAM de A'; end if;
  select count(*) into v_n from public.inspecteur_lycam_list_results_v2(tB, lycA);
  if v_n is distinct from 0 then raise exception 'ÉCHEC 5 B voit les résultats LYCAM de A'; end if;
  ok := public.inspecteur_lycam_save_result_v2(tB, lycA, 'Intrus', 'B', null, null, 1, 'b', '{}'::jsonb);
  if ok is not false then raise exception 'ÉCHEC 5 B écrit dans une session LYCAM de A'; end if;
  select count(*) into v_n from public.inspecteur_mbti_list_sessions_v2(tB) x where x.inspecteur_id is distinct from 'test_7a2b_b';
  if v_n is distinct from 0 then raise exception 'ÉCHEC 5 B voit une session MBTI de A'; end if;
  select count(*) into v_n from public.inspecteur_mbti_list_results_v2(tB, mbtA);
  if v_n is distinct from 0 then raise exception 'ÉCHEC 5 B voit les résultats MBTI de A'; end if;
  ok := public.inspecteur_mbti_save_result_v2(tB, mbtA, 'Intrus', 'B', null, null, '{}'::jsonb, 'XXXX', '[]'::jsonb, null);
  if ok is not false then raise exception 'ÉCHEC 5 B écrit dans une session MBTI de A'; end if;
  select count(*) into v_n from public.lycam_resultats lr where lr.session_id = lycA;
  if v_n is distinct from 1 then raise exception 'ÉCHEC 5 résultats LYCAM de A modifiés (%)', v_n; end if;
  select count(*) into v_n from public.mbti_resultats mr where mr.session_id = mbtA;
  if v_n is distinct from 1 then raise exception 'ÉCHEC 5 résultats MBTI de A modifiés (%)', v_n; end if;
  -- Suivi
  select count(*) into v_n from public.inspecteur_suivi_list_eleves_v2(tB);
  if v_n is distinct from 1 then raise exception 'ÉCHEC 5 B voit % fiche(s), 1 attendue (la sienne)', v_n; end if;
  select count(*) into v_n from public.inspecteur_suivi_get_eleve_v2(tB, fA1);
  if v_n is distinct from 0 then raise exception 'ÉCHEC 5 B lit une fiche de A'; end if;
  v_err := null;
  begin perform public.inspecteur_suivi_list_notes_v2(tB, fA1);
  exception when others then v_err := sqlerrm; end;
  if v_err is distinct from 'unauthorized' then raise exception 'ÉCHEC 5 B lit les notes de A : %', coalesce(v_err, 'aucune erreur'); end if;
  v_err := null;
  begin perform public.inspecteur_suivi_add_note_v2(tB, fA1, '02/10/2026', 'Intrusion');
  exception when others then v_err := sqlerrm; end;
  if v_err is distinct from 'unauthorized' then raise exception 'ÉCHEC 5 B ajoute une note à A : %', coalesce(v_err, 'aucune erreur'); end if;
  ok := public.inspecteur_suivi_set_appreciation_v2(tB, fA1, 'Piratée');
  if ok is not false then raise exception 'ÉCHEC 5 B modifie l''appréciation de A'; end if;
  ok := public.inspecteur_suivi_delete_eleve_v2(tB, fA1);
  if ok is not false then raise exception 'ÉCHEC 5 B supprime une fiche de A'; end if;
  select count(*) into v_n from public.suivi_eleves s where s.id = fA1::uuid and s.appreciation_finale = 'Bien';
  if v_n is distinct from 1 then raise exception 'ÉCHEC 5 fiche fA1 modifiée ou supprimée par B'; end if;
  select count(*) into v_n from public.suivi_eleves_notes n where n.suivi_eleve_id = fA1::uuid;
  if v_n is distinct from 2 then raise exception 'ÉCHEC 5 notes de fA1 modifiées par B (%)', v_n; end if;
  -- Et inversement : A ne voit ni ne touche rien de B
  select count(*) into v_n from public.inspecteur_suivi_list_eleves_v2(tA) x where x.id = fB1;
  if v_n is distinct from 0 then raise exception 'ÉCHEC 5 A voit une fiche de B'; end if;
  select count(*) into v_n from public.inspecteur_suivi_get_eleve_v2(tA, fB1);
  if v_n is distinct from 0 then raise exception 'ÉCHEC 5 A lit une fiche de B'; end if;
  ok := public.inspecteur_suivi_delete_eleve_v2(tA, fB1);
  if ok is not false then raise exception 'ÉCHEC 5 A supprime une fiche de B'; end if;
  select count(*) into v_n from public.inspecteur_lycam_list_results_v2(tA, lycB);
  if v_n is distinct from 0 then raise exception 'ÉCHEC 5 A lit une session LYCAM de B'; end if;
  select count(*) into v_n from public.inspecteur_mbti_list_results_v2(tA, mbtB);
  if v_n is distinct from 0 then raise exception 'ÉCHEC 5 A lit une session MBTI de B'; end if;
  select count(*) into v_n from public.suivi_eleves s where s.id = fB1::uuid;
  if v_n is distinct from 1 then raise exception 'ÉCHEC 5 fiche fB1 supprimée par A'; end if;
  raise notice '5. ISOLATION : ni B ni A ne voient, lisent, modifient ou suppriment les données de l''autre';

  -- 6. Suppression d'une fiche de suivi par son propriétaire (notes supprimées en cascade)
  ok := public.inspecteur_suivi_delete_eleve_v2(tA, fA2);
  if ok is not true then raise exception 'ÉCHEC 6 delete_eleve_v2 a renvoyé %', ok; end if;
  select count(*) into v_n from public.suivi_eleves s where s.id = fA2::uuid;
  if v_n is distinct from 0 then raise exception 'ÉCHEC 6 fiche fA2 toujours présente'; end if;
  select count(*) into v_n from public.inspecteur_suivi_list_eleves_v2(tA);
  if v_n is distinct from 1 then raise exception 'ÉCHEC 6 A voit % fiche(s), 1 attendue', v_n; end if;
  ok := public.inspecteur_suivi_delete_eleve_v2(tA, fA2);
  if ok is not false then raise exception 'ÉCHEC 6 seconde suppression a renvoyé %', ok; end if;
  raise notice '6. suivi_delete_eleve_v2 : fiche supprimée, seconde suppression -> false';

  -- 7. Jeton inconnu, d'un autre rôle, révoqué : P0401 sur les 15 fonctions
  r := public.inspecteur_session_open('T7A2B-0001', 'mdp-a-7a2b');
  tA2 := r->>'token';
  ok := public.session_close(tA2);
  if ok is not true then raise exception 'ÉCHEC 7 session_close a renvoyé %', ok; end if;
  foreach v_tok in array array[t_inconnu, t_eleve, tA2] loop
    foreach v_sql in array array[
      'select public.inspecteur_lycam_create_session_v2(%L, ''z'')',
      'select public.inspecteur_lycam_save_result_v2(%L, ' || quote_literal(lycA) || ', ''z'', ''z'', null, null, 1, ''b'', ''{}''::jsonb)',
      'select count(*) from public.inspecteur_lycam_list_sessions_v2(%L)',
      'select count(*) from public.inspecteur_lycam_list_results_v2(%L, ' || quote_literal(lycA) || ')',
      'select public.inspecteur_mbti_create_session_v2(%L, ''z'')',
      'select public.inspecteur_mbti_save_result_v2(%L, ' || quote_literal(mbtA) || ', ''z'', ''z'', null, null, ''{}''::jsonb, ''XXXX'', ''[]''::jsonb, null)',
      'select count(*) from public.inspecteur_mbti_list_sessions_v2(%L)',
      'select count(*) from public.inspecteur_mbti_list_results_v2(%L, ' || quote_literal(mbtA) || ')',
      'select public.inspecteur_suivi_add_eleve_v2(%L, ''Z'', ''Z'', ''3e'', ''["IE"]''::jsonb)',
      'select count(*) from public.inspecteur_suivi_list_eleves_v2(%L)',
      'select count(*) from public.inspecteur_suivi_get_eleve_v2(%L, ' || quote_literal(fA1) || ')',
      'select public.inspecteur_suivi_delete_eleve_v2(%L, ' || quote_literal(fA1) || ')',
      'select public.inspecteur_suivi_set_appreciation_v2(%L, ' || quote_literal(fA1) || ', ''z'')',
      'select public.inspecteur_suivi_add_note_v2(%L, ' || quote_literal(fA1) || ', ''01/01/2026'', ''z'')',
      'select count(*) from public.inspecteur_suivi_list_notes_v2(%L, ' || quote_literal(fA1) || ')'
    ] loop
      v_state := null;
      begin
        execute format(v_sql, v_tok);
      exception when others then v_state := sqlstate;
      end;
      if v_state is distinct from 'P0401' then
        raise exception 'ÉCHEC 7 % au lieu de P0401 pour : %', coalesce(v_state, 'aucune erreur'), format(v_sql, left(v_tok, 12) || '…');
      end if;
    end loop;
  end loop;
  select count(*) into v_n from public.suivi_eleves s where s.nom = 'Z' or s.appreciation_finale = 'z';
  if v_n is distinct from 0 then raise exception 'ÉCHEC 7 une fiche a été créée ou modifiée avec un jeton refusé'; end if;
  select count(*) into v_n from public.lycam_sessions ls where ls.nom = 'z';
  if v_n is distinct from 0 then raise exception 'ÉCHEC 7 une session LYCAM a été créée avec un jeton refusé'; end if;
  raise notice '7. jeton inconnu / d''un autre rôle / révoqué : P0401 sur les 15 fonctions, aucune écriture';

  -- 8. Les anciennes fonctions (par mot de passe) marchent toujours (avec B)
  v_txt := public.inspecteur_lycam_create_session('test_7a2b_b', 'mdp-b-7a2b', 'Ancienne LYCAM');
  if v_txt is null then raise exception 'ÉCHEC 8 inspecteur_lycam_create_session'; end if;
  ok := public.inspecteur_lycam_save_result('test_7a2b_b', 'mdp-b-7a2b', v_txt, 'N', 'P', null, null, 10, 'b', '{}'::jsonb);
  if ok is not true then raise exception 'ÉCHEC 8 inspecteur_lycam_save_result'; end if;
  select count(*) into v_n from public.inspecteur_lycam_list_sessions('test_7a2b_b', 'mdp-b-7a2b');
  if v_n is distinct from 2 then raise exception 'ÉCHEC 8 inspecteur_lycam_list_sessions : %', v_n; end if;
  select count(*) into v_n from public.inspecteur_lycam_list_results('test_7a2b_b', 'mdp-b-7a2b', v_txt);
  if v_n is distinct from 1 then raise exception 'ÉCHEC 8 inspecteur_lycam_list_results : %', v_n; end if;
  v_txt := public.inspecteur_mbti_create_session('test_7a2b_b', 'mdp-b-7a2b', 'Ancienne MBTI');
  if v_txt is null then raise exception 'ÉCHEC 8 inspecteur_mbti_create_session'; end if;
  ok := public.inspecteur_mbti_save_result('test_7a2b_b', 'mdp-b-7a2b', v_txt, 'N', 'P', null, null, '{}'::jsonb, 'ISTJ', '[]'::jsonb, null);
  if ok is not true then raise exception 'ÉCHEC 8 inspecteur_mbti_save_result'; end if;
  select count(*) into v_n from public.inspecteur_mbti_list_sessions('test_7a2b_b', 'mdp-b-7a2b');
  if v_n is distinct from 2 then raise exception 'ÉCHEC 8 inspecteur_mbti_list_sessions : %', v_n; end if;
  select count(*) into v_n from public.inspecteur_mbti_list_results('test_7a2b_b', 'mdp-b-7a2b', v_txt);
  if v_n is distinct from 1 then raise exception 'ÉCHEC 8 inspecteur_mbti_list_results : %', v_n; end if;
  v_txt := public.inspecteur_suivi_add_eleve('test_7a2b_b', 'mdp-b-7a2b', 'Ancien', 'Suivi', '1re', '["BS"]'::jsonb);
  if v_txt is null then raise exception 'ÉCHEC 8 inspecteur_suivi_add_eleve'; end if;
  select count(*) into v_n from public.inspecteur_suivi_list_eleves('test_7a2b_b', 'mdp-b-7a2b');
  if v_n is distinct from 2 then raise exception 'ÉCHEC 8 inspecteur_suivi_list_eleves : %', v_n; end if;
  select count(*) into v_n from public.inspecteur_suivi_get_eleve('test_7a2b_b', 'mdp-b-7a2b', v_txt);
  if v_n is distinct from 1 then raise exception 'ÉCHEC 8 inspecteur_suivi_get_eleve : %', v_n; end if;
  ok := public.inspecteur_suivi_add_note('test_7a2b_b', 'mdp-b-7a2b', v_txt, '03/10/2026', 'Ancienne note');
  if ok is not true then raise exception 'ÉCHEC 8 inspecteur_suivi_add_note'; end if;
  select count(*) into v_n from public.inspecteur_suivi_list_notes('test_7a2b_b', 'mdp-b-7a2b', v_txt);
  if v_n is distinct from 1 then raise exception 'ÉCHEC 8 inspecteur_suivi_list_notes : %', v_n; end if;
  ok := public.inspecteur_suivi_set_appreciation('test_7a2b_b', 'mdp-b-7a2b', v_txt, 'Ancienne appréciation');
  if ok is not true then raise exception 'ÉCHEC 8 inspecteur_suivi_set_appreciation'; end if;
  ok := public.inspecteur_suivi_delete_eleve('test_7a2b_b', 'mdp-b-7a2b', v_txt);
  if ok is not true then raise exception 'ÉCHEC 8 inspecteur_suivi_delete_eleve'; end if;
  v_err := null;
  begin perform public.inspecteur_suivi_list_eleves('test_7a2b_b', 'mauvais');
  exception when others then v_err := sqlerrm; end;
  if v_err is distinct from 'unauthorized' then raise exception 'ÉCHEC 8 ancienne fonction avec mauvais mot de passe : %', coalesce(v_err, 'aucune erreur'); end if;
  raise notice '8. les 15 anciennes fonctions par mot de passe marchent toujours (mauvais mot de passe refusé)';

  -- 9. Suppression de la fiche A : jeton révoqué, P0401
  --    (ses données LYCAM/MBTI/suivi sont supprimées d'abord : la FK de suivi_eleves,
  --    et d'éventuelles FK de lycam_*/mbti_*, bloqueraient la suppression)
  delete from public.lycam_resultats where inspecteur_id = 'test_7a2b_a';
  delete from public.lycam_sessions where inspecteur_id = 'test_7a2b_a';
  delete from public.mbti_resultats where inspecteur_id = 'test_7a2b_a';
  delete from public.mbti_sessions where inspecteur_id = 'test_7a2b_a';
  delete from public.suivi_eleves where inspecteur_id = 'test_7a2b_a';
  delete from public.inspecteurs where id = 'test_7a2b_a';
  select count(*) into v_n from public.sessions s
    where s.user_id = 'test_7a2b_a' and s.role = 'inspecteur' and s.revoked = false;
  if v_n is distinct from 0 then raise exception 'ÉCHEC 9 % session(s) de A non révoquée(s)', v_n; end if;
  v_state := null;
  begin perform public.inspecteur_suivi_list_eleves_v2(tA);
  exception when others then v_state := sqlstate; end;
  if v_state is distinct from 'P0401' then raise exception 'ÉCHEC 9 jeton d''une fiche supprimée : %', coalesce(v_state, 'aucune erreur'); end if;
  raise notice '9. fiche A supprimée : sessions révoquées, P0401';
end $$;

ROLLBACK;


-- ############################################################
-- PARTIE 3 : CONTRÔLE FINAL (une seule requête, toutes les lignes = true)
-- On n'arrive ici que si le test de la partie 2 a réussi.
-- ############################################################
with v2 as (
  select p.oid, p.proname, p.prosecdef, p.proconfig, p.prosrc,
         pg_get_function_identity_arguments(p.oid) as args
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in (
      'inspecteur_lycam_create_session_v2', 'inspecteur_lycam_save_result_v2',
      'inspecteur_lycam_list_sessions_v2', 'inspecteur_lycam_list_results_v2',
      'inspecteur_mbti_create_session_v2', 'inspecteur_mbti_save_result_v2',
      'inspecteur_mbti_list_sessions_v2', 'inspecteur_mbti_list_results_v2',
      'inspecteur_suivi_add_eleve_v2', 'inspecteur_suivi_list_eleves_v2',
      'inspecteur_suivi_get_eleve_v2', 'inspecteur_suivi_delete_eleve_v2',
      'inspecteur_suivi_set_appreciation_v2', 'inspecteur_suivi_add_note_v2',
      'inspecteur_suivi_list_notes_v2')
),
anciennes as (
  select p.proname
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in (
      'inspecteur_lycam_create_session', 'inspecteur_lycam_save_result',
      'inspecteur_lycam_list_sessions', 'inspecteur_lycam_list_results',
      'inspecteur_mbti_create_session', 'inspecteur_mbti_save_result',
      'inspecteur_mbti_list_sessions', 'inspecteur_mbti_list_results',
      'inspecteur_suivi_add_eleve', 'inspecteur_suivi_list_eleves',
      'inspecteur_suivi_get_eleve', 'inspecteur_suivi_delete_eleve',
      'inspecteur_suivi_set_appreciation', 'inspecteur_suivi_add_note',
      'inspecteur_suivi_list_notes')
),
mortes as (
  select p.proname
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in ('inspecteur_lycam_delete_session', 'inspecteur_mbti_delete_session', 'inspecteur_add_note',
                      'inspecteur_lycam_delete_session_v2', 'inspecteur_mbti_delete_session_v2', 'inspecteur_add_note_v2')
)
select n, controle, ok from (
  select 1 as n, '15 fonctions _v2 présentes, une signature chacune' as controle,
         (select count(*) = 15 and count(distinct proname) = 15 from v2) as ok
  union all select 2, 'toutes SECURITY DEFINER',
         (select bool_and(prosecdef) from v2)
  union all select 3, 'toutes SET search_path TO public',
         (select bool_and(proconfig @> array['search_path=public']) from v2)
  union all select 4, 'toutes exécutables par anon',
         (select bool_and(has_function_privilege('anon', oid, 'EXECUTE')) from v2)
  union all select 5, 'toutes exécutables par authenticated',
         (select bool_and(has_function_privilege('authenticated', oid, 'EXECUTE')) from v2)
  union all select 6, 'aucune n''utilise crypt',
         (select bool_and(prosrc not like '%crypt%') from v2)
  union all select 7, 'toutes appellent _session_user(p_token, ''inspecteur'') en premier',
         (select bool_and(prosrc ~ '^\s*declare[^;]*;(\s*v_[a-z]+ [a-z]+;)*\s*begin\s*v_insp_id := _session_user\(p_token, ''inspecteur''\);') from v2)
  union all select 8, 'aucune ne prend p_password ni p_inspecteur_id',
         (select bool_and(args !~ 'p_password|p_inspecteur_id') from v2)
  union all select 9, 'les 15 anciennes fonctions (par mot de passe) sont toujours là',
         (select count(*) = 15 and count(distinct proname) = 15 from anciennes)
  union all select 10, 'les 3 fonctions mortes intactes, sans _v2',
         (select count(*) = 3 and bool_and(proname not like '%\_v2') from mortes)
  union all select 11, 'test fonctionnel passé (partie 2)', true
  union all select 12, 'aucune trace : inspecteurs de test',
         (select count(*) = 0 from public.inspecteurs where id like 'test\_7a2b\_%' or tel like 'T7A2B-%')
  union all select 13, 'aucune trace : sessions de test',
         (select count(*) = 0 from public.sessions where user_id like 'test\_7a2b\_%')
  union all select 14, 'aucune trace : lycam_sessions / lycam_resultats',
         (select (select count(*) from public.lycam_sessions where inspecteur_id like 'test\_7a2b\_%')
               + (select count(*) from public.lycam_resultats where inspecteur_id like 'test\_7a2b\_%') = 0)
  union all select 15, 'aucune trace : mbti_sessions / mbti_resultats',
         (select (select count(*) from public.mbti_sessions where inspecteur_id like 'test\_7a2b\_%')
               + (select count(*) from public.mbti_resultats where inspecteur_id like 'test\_7a2b\_%') = 0)
  union all select 16, 'aucune trace : suivi_eleves',
         (select count(*) = 0 from public.suivi_eleves where inspecteur_id like 'test\_7a2b\_%')
  union all select 17, 'aucune trace : suivi_eleves_notes',
         (select count(*) = 0 from public.suivi_eleves_notes
           where suivi_eleve_id not in (select s.id from public.suivi_eleves s)
              or texte in ('Note une', 'Note deux', 'Intrusion', 'Ancienne note'))
) t
order by n;
