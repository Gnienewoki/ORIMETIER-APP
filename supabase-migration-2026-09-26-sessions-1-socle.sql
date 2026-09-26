-- ============================================================
-- ORIMETIER — Jetons de session, Phase 1 : socle.
--
-- Remplacera à terme le mot de passe stocké en clair dans le
-- navigateur (localStorage GNK_ESPACES_SESSION) et renvoyé à chaque
-- appel RPC. Cette phase ne crée QUE l'infrastructure : aucune
-- fonction existante n'est modifiée, aucun impact sur l'application.
--
--   public.sessions      : une ligne par connexion ouverte. Le jeton
--                          n'est jamais stocké, seulement son empreinte
--                          sha256 (hex). Le mot de passe est vérifié
--                          une seule fois, à l'ouverture de session
--                          (fonctions *_session_open des phases suivantes,
--                          qui généreront le jeton via
--                          extensions.gen_random_bytes(32)).
--   _session_user        : vérification interne d'un jeton pour un rôle
--                          attendu → user_id, ou exception SESSION_INVALIDE
--                          (SQLSTATE P0401). Non exposée à l'API.
--   session_check        : publique, utilisée au chargement de page.
--   session_close        : publique, déconnexion (révoque le jeton).
--
-- Même modèle de sécurité que le reste de l'app : RLS activé sans
-- aucune policy, aucun droit pour anon/authenticated sur la table,
-- accès exclusivement via fonctions SECURITY DEFINER. Table absente
-- de la publication realtime (ne pas l'y ajouter).
--
-- Pré-requis vérifié dans supabase/reference/live-2026-09-26.sql :
-- aucune fonction sessions/_session_user/session_check/session_close
-- existante. CREATE TABLE sans IF NOT EXISTS volontairement : si une
-- table public.sessions existait déjà, le script échoue sans rien
-- modifier (transaction).
--
-- À exécuter en une fois dans l'éditeur SQL de Supabase.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1) Table
-- ------------------------------------------------------------
CREATE TABLE public.sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  token_hash text NOT NULL UNIQUE,
  role text NOT NULL CHECK (role IN ('eleve', 'inspecteur', 'etablissement', 'admin')),
  user_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  last_used_at timestamptz NOT NULL DEFAULT now(),
  revoked boolean NOT NULL DEFAULT false,
  CHECK (expires_at > created_at)
);
COMMENT ON TABLE public.sessions IS 'Sessions ouvertes (jetons). Accès uniquement via fonctions SECURITY DEFINER ; jamais de GRANT à anon/authenticated, jamais dans la publication realtime';
COMMENT ON COLUMN public.sessions.token_hash IS 'encode(extensions.digest(jeton, ''sha256''), ''hex'') — le jeton lui-même n''est jamais stocké';
COMMENT ON COLUMN public.sessions.user_id IS 'id de eleves / inspecteurs / etablissements selon role ; ''admin'' pour l''administrateur';

-- Révocation en masse (reset de mot de passe, bannissement, suppression).
CREATE INDEX sessions_role_user_id_idx ON public.sessions(role, user_id);

ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.sessions FROM public, anon, authenticated;

-- ------------------------------------------------------------
-- 2) _session_user : vérification interne (non exposée)
-- ------------------------------------------------------------
-- Renvoie le user_id du jeton si : empreinte connue, rôle attendu,
-- non révoqué, non expiré, et compte toujours valide (élève/inspecteur
-- existant et non banni, établissement existant). Sinon lève
-- SESSION_INVALIDE (SQLSTATE P0401), code stable que le frontend
-- détecte pour renvoyer proprement vers la connexion.
-- last_used_at n'est mis à jour qu'au plus toutes les 10 minutes, pour
-- ne pas écrire à chaque appel.
CREATE OR REPLACE FUNCTION public._session_user(p_token text, p_role text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_session_id uuid;
  v_user_id text;
  v_last_used timestamptz;
begin
  if coalesce(p_token, '') = '' or p_role is null then
    raise exception 'SESSION_INVALIDE' using errcode = 'P0401';
  end if;

  select s.id, s.user_id, s.last_used_at
    into v_session_id, v_user_id, v_last_used
  from sessions s
  where s.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
    and s.role = p_role
    and s.revoked = false
    and s.expires_at > now();

  if not found then
    raise exception 'SESSION_INVALIDE' using errcode = 'P0401';
  end if;

  if p_role = 'eleve' and not exists (
    select 1 from eleves e where e.id = v_user_id and coalesce(e.banni, false) = false
  ) then
    raise exception 'SESSION_INVALIDE' using errcode = 'P0401';
  elsif p_role = 'inspecteur' and not exists (
    select 1 from inspecteurs i where i.id = v_user_id and coalesce(i.banni, false) = false
  ) then
    raise exception 'SESSION_INVALIDE' using errcode = 'P0401';
  elsif p_role = 'etablissement' and not exists (
    select 1 from etablissements et where et.id = v_user_id
  ) then
    raise exception 'SESSION_INVALIDE' using errcode = 'P0401';
  end if;

  if v_last_used < now() - interval '10 minutes' then
    update sessions s set last_used_at = now() where s.id = v_session_id;
  end if;

  return v_user_id;
end; $function$;

REVOKE EXECUTE ON FUNCTION public._session_user(text, text) FROM public, anon, authenticated;

-- ------------------------------------------------------------
-- 3) session_check : publique (chargement de page)
-- ------------------------------------------------------------
-- Renvoie {role, id, expires_at} pour un jeton valide, null sinon (jeton
-- inconnu, révoqué, expiré, compte banni ou supprimé). Ne lève jamais
-- SESSION_INVALIDE : le frontend distingue ainsi "session refusée" (null)
-- d'une erreur réseau (exception côté client).
CREATE OR REPLACE FUNCTION public.session_check(p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_role text;
  v_expires_at timestamptz;
  v_user_id text;
begin
  if coalesce(p_token, '') = '' then
    return null;
  end if;

  select s.role, s.expires_at
    into v_role, v_expires_at
  from sessions s
  where s.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex');

  if not found then
    return null;
  end if;

  -- Même règles que partout ailleurs : on délègue à _session_user.
  begin
    v_user_id := _session_user(p_token, v_role);
  exception when sqlstate 'P0401' then
    return null;
  end;

  return jsonb_build_object('role', v_role, 'id', v_user_id, 'expires_at', v_expires_at);
end; $function$;

GRANT EXECUTE ON FUNCTION public.session_check(text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 4) session_close : publique (déconnexion)
-- ------------------------------------------------------------
-- Révoque le jeton fourni. true si une session active a été révoquée,
-- false sinon (jeton inconnu ou déjà révoqué) — sans conséquence côté
-- client, qui efface sa session locale dans tous les cas.
CREATE OR REPLACE FUNCTION public.session_close(p_token text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if coalesce(p_token, '') = '' then
    return false;
  end if;

  update sessions s set revoked = true
  where s.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
    and s.revoked = false;

  return found;
end; $function$;

GRANT EXECUTE ON FUNCTION public.session_close(text) TO anon, authenticated;

COMMIT;

-- ============================================================
-- VÉRIFICATIONS (à lancer après exécution, une requête à la fois)
-- ============================================================
--
-- V1. Table et colonnes (8 lignes attendues)
-- select column_name, data_type, is_nullable, column_default
-- from information_schema.columns
-- where table_schema = 'public' and table_name = 'sessions'
-- order by ordinal_position;
--
-- V2. RLS activé, aucune policy (rls = true, nb_policies = 0)
-- select c.relrowsecurity as rls,
--        (select count(*) from pg_policies p where p.schemaname = 'public' and p.tablename = 'sessions') as nb_policies
-- from pg_class c where c.oid = 'public.sessions'::regclass;
--
-- V3. Aucun droit pour anon / authenticated sur la table (0 ligne attendue)
-- select grantee, privilege_type
-- from information_schema.role_table_grants
-- where table_schema = 'public' and table_name = 'sessions'
--   and grantee in ('anon', 'authenticated', 'PUBLIC');
--
-- V4. Index (sessions_pkey, sessions_token_hash_key, sessions_role_user_id_idx)
-- select indexname, indexdef from pg_indexes
-- where schemaname = 'public' and tablename = 'sessions';
--
-- V5. Droits d'exécution (anon : _session_user = false, session_check = true, session_close = true)
-- select f,
--        has_function_privilege('anon', f, 'EXECUTE') as anon,
--        has_function_privilege('authenticated', f, 'EXECUTE') as authenticated
-- from unnest(array['public._session_user(text,text)',
--                   'public.session_check(text)',
--                   'public.session_close(text)']) as f;
--
-- V6. SECURITY DEFINER + search_path (3 lignes, security_definer = true, config = {search_path=public})
-- select p.proname, p.prosecdef as security_definer, p.proconfig as config
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public' and p.proname in ('_session_user', 'session_check', 'session_close');
--
-- V7. Pas dans la publication realtime (0 ligne attendue)
-- select * from pg_publication_tables where schemaname = 'public' and tablename = 'sessions';
--
-- V8. Test fonctionnel SANS trace (tout est annulé par le ROLLBACK final).
--     Sélectionner et exécuter le bloc entier d'un coup.
-- begin;
-- insert into public.sessions(token_hash, role, user_id, expires_at)
--   values (encode(extensions.digest('jeton-de-test-phase1', 'sha256'), 'hex'), 'admin', 'admin', now() + interval '1 hour');
-- select public.session_check('jeton-de-test-phase1')        as check_valide,     -- {"id": "admin", "role": "admin", ...}
--        public._session_user('jeton-de-test-phase1', 'admin') as user_admin,     -- admin
--        public.session_check('jeton-inconnu')                as check_inconnu,    -- null
--        public.session_close('jeton-de-test-phase1')         as close_1,          -- true
--        public.session_close('jeton-de-test-phase1')         as close_2;          -- false
-- select public.session_check('jeton-de-test-phase1')        as check_apres_close; -- null
-- rollback;
--
-- V9. Mauvais rôle → erreur attendue "SESSION_INVALIDE" (le ROLLBACK est implicite après l'erreur).
-- begin;
-- insert into public.sessions(token_hash, role, user_id, expires_at)
--   values (encode(extensions.digest('jeton-de-test-phase1', 'sha256'), 'hex'), 'admin', 'admin', now() + interval '1 hour');
-- select public._session_user('jeton-de-test-phase1', 'eleve');
-- rollback;
--
-- V10. La clé publique ne peut ni lire la table ni appeler _session_user
--      (erreur attendue "permission denied" sur chacune des deux requêtes, à lancer séparément).
-- begin; set local role anon; select * from public.sessions; rollback;
-- begin; set local role anon; select public._session_user('x', 'admin'); rollback;
