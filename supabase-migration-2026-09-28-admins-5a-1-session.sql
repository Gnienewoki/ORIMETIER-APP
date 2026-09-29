-- ============================================================
-- ORIMETIER — Phase 5a-1 : socle des sessions admin par jeton.
--
-- Pré-requis : 5a-0 exécutée (table admins, 'admin' dans le CHECK de
-- sessions.role). Migration ADDITIVE : les anciennes RPC admin
-- (p_admin_password) et admin_login restent en service jusqu'en 5c.
--
--   1) _session_user        : réécrite depuis la définition LIVE (collée le
--                              28/09/2026). Seul ajout : la branche 'admin'
--                              (admin existant dans admins ET actif).
--                              Tout le reste est identique.
--   2) admin_session_open   : (p_email, p_password) -> ouvre une session
--                              admin de 24 h et renvoie
--                              {token, expires_at, id, nom}, ou null
--                              (identifiants incorrects OU compte désactivé :
--                              même réponse, rien n'est révélé).
--   3) Triggers sur admins  : - password_changed_at mis à jour à chaque
--                                changement de mot de passe ;
--                              - révocation des sessions de CET admin au
--                                changement de mot de passe, à la
--                                désactivation (actif -> false) ou à la
--                                suppression du compte.
--
-- PostgREST choisit la fonction d'après les noms d'arguments :
-- admin_session_open(p_email, p_password) ne se confond pas avec
-- admin_login(p_password).
--
-- À exécuter en une fois dans l'éditeur SQL de Supabase.
-- ============================================================

BEGIN;

-- Garde-fou : 5a-0 doit avoir été exécutée.
DO $$
begin
  if to_regclass('public.admins') is null then
    raise exception 'Table public.admins absente : exécuter d''abord la migration 5a-0';
  end if;
end $$;

-- ------------------------------------------------------------
-- 1) _session_user : ajout de la branche 'admin'
-- ------------------------------------------------------------
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
  elsif p_role = 'admin' and not exists (
    select 1 from admins a where a.id = v_user_id and a.actif = true
  ) then
    raise exception 'SESSION_INVALIDE' using errcode = 'P0401';
  end if;

  if v_last_used < now() - interval '10 minutes' then
    update sessions s set last_used_at = now() where s.id = v_session_id;
  end if;

  return v_user_id;
end; $function$;

-- Droits inchangés (CREATE OR REPLACE les conserve) ; réaffirmés par sécurité.
REVOKE EXECUTE ON FUNCTION public._session_user(text, text) FROM public, anon, authenticated;

-- ------------------------------------------------------------
-- 2) admin_session_open : ouverture de session admin (publique)
-- ------------------------------------------------------------
-- null : e-mail/mot de passe incorrects ou vides, ou compte désactivé.
-- {token, expires_at, id, nom} : session ouverte pour 24 h.
-- E-mail inconnu : un calcul bcrypt factice est quand même effectué pour
-- que le temps de réponse ne révèle pas si l'e-mail correspond à un admin.
CREATE OR REPLACE FUNCTION public.admin_session_open(p_email text, p_password text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_admin admins%rowtype;
  v_token text;
  v_expires_at timestamptz;
begin
  if coalesce(trim(p_email), '') = '' or coalesce(p_password, '') = '' then
    return null;
  end if;

  -- Ménage : sessions expirées depuis plus de 7 jours (tous rôles).
  delete from sessions s where s.expires_at < now() - interval '7 days';

  select a.* into v_admin
  from admins a
  where lower(trim(a.email)) = lower(trim(p_email));

  if not found then
    perform extensions.crypt(p_password, extensions.gen_salt('bf'));
    return null;
  end if;

  if v_admin.password <> extensions.crypt(p_password, v_admin.password)
     or v_admin.actif = false then
    return null;
  end if;

  v_token := encode(extensions.gen_random_bytes(32), 'hex');

  insert into sessions(token_hash, role, user_id, expires_at)
  values (encode(extensions.digest(v_token, 'sha256'), 'hex'), 'admin', v_admin.id, now() + interval '24 hours')
  returning expires_at into v_expires_at;

  update admins a set last_login_at = now() where a.id = v_admin.id;

  return jsonb_build_object(
    'token', v_token,
    'expires_at', v_expires_at,
    'id', v_admin.id,
    'nom', v_admin.nom
  );
end; $function$;

REVOKE ALL ON FUNCTION public.admin_session_open(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_session_open(text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 3a) password_changed_at : horodatage du changement de mot de passe
-- ------------------------------------------------------------
-- BEFORE UPDATE : s'exécute avant trg_hash_password (ordre alphabétique des
-- triggers BEFORE) ; la comparaison porte sur la valeur reçue, qui diffère
-- de l'ancien hash dès qu'un nouveau mot de passe est fourni.
CREATE OR REPLACE FUNCTION public.admins_password_changed_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.password is distinct from old.password then
    new.password_changed_at := now();
  end if;
  return new;
end; $function$;

REVOKE ALL ON FUNCTION public.admins_password_changed_trigger() FROM public, anon, authenticated;

CREATE TRIGGER trg_admins_password_changed
  BEFORE UPDATE OF password ON public.admins
  FOR EACH ROW EXECUTE FUNCTION admins_password_changed_trigger();

-- ------------------------------------------------------------
-- 3b) Révocation des sessions de l'admin concerné
-- ------------------------------------------------------------
-- Changement de mot de passe, désactivation ou suppression du compte :
-- toutes les sessions ouvertes de CET admin sont révoquées (les autres
-- admins ne sont pas touchés).
CREATE OR REPLACE FUNCTION public.admins_revoke_sessions_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if tg_op = 'DELETE'
     or new.password is distinct from old.password
     or (old.actif = true and new.actif = false) then
    update sessions s set revoked = true
    where s.role = 'admin' and s.user_id = old.id and s.revoked = false;
  end if;
  return null;
end; $function$;

REVOKE ALL ON FUNCTION public.admins_revoke_sessions_trigger() FROM public, anon, authenticated;

CREATE TRIGGER trg_admins_revoke_sessions
  AFTER UPDATE OF password, actif OR DELETE ON public.admins
  FOR EACH ROW EXECUTE FUNCTION admins_revoke_sessions_trigger();

COMMIT;

-- ============================================================
-- VÉRIFICATIONS (à lancer après exécution, une requête à la fois)
-- ============================================================
--
-- V1. Fonctions : SECURITY DEFINER + search_path, droits anon
--     (admin_session_open : anon = true ; _session_user et les 2 fonctions
--      de trigger : anon = false)
-- select p.oid::regprocedure, p.prosecdef, p.proconfig,
--        has_function_privilege('anon', p.oid, 'EXECUTE') as anon
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('_session_user', 'admin_session_open',
--                     'admins_password_changed_trigger', 'admins_revoke_sessions_trigger');
--
-- V2. Triggers de admins (3 : trg_admins_password_changed, trg_admins_revoke_sessions, trg_hash_password)
-- select tgname, pg_get_triggerdef(t.oid) from pg_trigger t
-- where t.tgrelid = 'public.admins'::regclass and not t.tgisinternal order by 1;
--
-- V3. Test fonctionnel complet SANS trace, avec un admin temporaire.
--     Sélectionner et exécuter le bloc ENTIER d'un coup.
--     Succès : la dernière requête affiche "TESTS 5a-1 OK".
--     Échec : une erreur "ÉCHEC ..." indique le test fautif.
--     Le ROLLBACK final annule tout (admin, sessions).
-- begin;
-- insert into public.admins(id, nom, email, password)
--   values ('adm_test', 'Admin Test', 'test-5a1@exemple.invalid', 'mdp-test-5a1');
-- do $$
-- declare
--   r jsonb; t text; c jsonb;
-- begin
--   -- ouverture : bon e-mail (casse/espaces tolérés) + bon mot de passe
--   r := public.admin_session_open('  TEST-5a1@exemple.invalid ', 'mdp-test-5a1');
--   if r is null or r->>'id' <> 'adm_test' or coalesce(r->>'token', '') = '' then raise exception 'ÉCHEC ouverture'; end if;
--   t := r->>'token';
--   if (r->>'expires_at')::timestamptz > now() + interval '24 hours 1 minute' then raise exception 'ÉCHEC durée > 24 h'; end if;
--   -- vérification du jeton
--   c := public.session_check(t);
--   if c is null or c->>'role' <> 'admin' or c->>'id' <> 'adm_test' then raise exception 'ÉCHEC session_check'; end if;
--   if public._session_user(t, 'admin') <> 'adm_test' then raise exception 'ÉCHEC _session_user'; end if;
--   -- refus
--   if public.admin_session_open('test-5a1@exemple.invalid', 'mauvais') is not null then raise exception 'ÉCHEC mauvais mot de passe accepté'; end if;
--   if public.admin_session_open('inconnu@exemple.invalid', 'mdp-test-5a1') is not null then raise exception 'ÉCHEC e-mail inconnu accepté'; end if;
--   if public.admin_session_open('', '') is not null then raise exception 'ÉCHEC identifiants vides acceptés'; end if;
--   -- mauvais rôle
--   begin
--     perform public._session_user(t, 'eleve');
--     raise exception 'ÉCHEC jeton admin accepté pour le rôle eleve';
--   exception when sqlstate 'P0401' then null;
--   end;
--   -- changement de mot de passe => révocation + horodatage
--   update public.admins set password = 'nouveau-mdp-5a1' where id = 'adm_test';
--   if public.session_check(t) is not null then raise exception 'ÉCHEC session non révoquée après changement de mot de passe'; end if;
--   if (select password_changed_at from public.admins where id = 'adm_test') is null then raise exception 'ÉCHEC password_changed_at'; end if;
--   if public.admin_session_open('test-5a1@exemple.invalid', 'mdp-test-5a1') is not null then raise exception 'ÉCHEC ancien mot de passe encore accepté'; end if;
--   -- désactivation => révocation + connexion refusée
--   r := public.admin_session_open('test-5a1@exemple.invalid', 'nouveau-mdp-5a1');
--   if r is null then raise exception 'ÉCHEC ouverture avec le nouveau mot de passe'; end if;
--   t := r->>'token';
--   update public.admins set actif = false where id = 'adm_test';
--   if public.session_check(t) is not null then raise exception 'ÉCHEC session non révoquée après désactivation'; end if;
--   if public.admin_session_open('test-5a1@exemple.invalid', 'nouveau-mdp-5a1') is not null then raise exception 'ÉCHEC compte désactivé accepté'; end if;
--   -- réactivation + déconnexion
--   update public.admins set actif = true where id = 'adm_test';
--   r := public.admin_session_open('test-5a1@exemple.invalid', 'nouveau-mdp-5a1');
--   t := r->>'token';
--   if public.session_close(t) is not true then raise exception 'ÉCHEC session_close'; end if;
--   if public.session_check(t) is not null then raise exception 'ÉCHEC session active après session_close'; end if;
--   -- suppression du compte => révocation
--   r := public.admin_session_open('test-5a1@exemple.invalid', 'nouveau-mdp-5a1');
--   t := r->>'token';
--   delete from public.admins where id = 'adm_test';
--   if public.session_check(t) is not null then raise exception 'ÉCHEC session active après suppression du compte'; end if;
-- end $$;
-- select 'TESTS 5a-1 OK' as resultat;
-- rollback;
--
-- V4. Aucune trace laissée par V3 (0 et 0 attendus)
-- select (select count(*) from public.admins where id = 'adm_test') as admin_test,
--        (select count(*) from public.sessions where user_id = 'adm_test') as sessions_test;
--
-- V5. La clé publique ne peut pas appeler _session_user (erreur attendue "permission denied")
-- begin; set local role anon; select public._session_user('x', 'admin'); rollback;
