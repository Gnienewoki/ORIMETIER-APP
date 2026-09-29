-- ============================================================
-- ORIMETIER — Phase 5a-3 : gestion des comptes admin (par jeton).
--
-- Pré-requis : 5a-0 (table admins) et 5a-1 (admin_session_open,
-- _session_user avec branche 'admin', triggers de révocation) exécutées.
-- Migration ADDITIVE : rien n'est supprimé.
--
--   1) Trigger trg_admins_quota sur admins (toute écriture, y compris
--      depuis le SQL Editor) :
--        - au plus 5 admins actifs         -> exception ADMINS_LIMITE_ATTEINTE
--        - jamais 0 admin actif (désactiver ou supprimer le dernier admin
--          actif)                          -> exception DERNIER_ADMIN_ACTIF
--      Verrou pg_advisory_xact_lock : deux transactions simultanées ne peuvent
--      pas dépasser la limite ensemble (la seconde attend la fin de la
--      première, puis recompte avec les données validées).
--      Le comptage porte sur la table du trigger (tg_relid) : la fonction est
--      ainsi testable sur une copie temporaire (test V3), sans toucher aux
--      comptes réels.
--   2) admin_list_admins_v2(p_token)                          : liste, SANS mot de passe.
--   3) admin_create_admin_v2(p_token, p_nom, p_email, p_password)
--                                                             : création (compte actif).
--   4) admin_set_admin_actif_v2(p_token, p_admin_id, p_actif) : désactivation /
--                                                               réactivation.
--   5) admin_change_password_v2(p_token, p_ancien, p_nouveau) : change SON PROPRE
--                                                               mot de passe.
--   6) Commentaire de la table admins mis à jour.
--
-- Choix validés (plan 5a-2/5a-3, section 2) : pas de suppression de compte
-- depuis l'application (désactivation seulement), pas de réinitialisation du
-- mot de passe d'un AUTRE admin depuis l'application (SQL Editor uniquement).
--
-- Erreurs métier (message de l'exception, code SQLSTATE P0001) :
--   CHAMPS_OBLIGATOIRES, EMAIL_INVALIDE, EMAIL_DEJA_UTILISE,
--   MOT_DE_PASSE_TROP_COURT (< 8 caractères), ADMINS_LIMITE_ATTEINTE,
--   DERNIER_ADMIN_ACTIF, ADMIN_AUTO_DESACTIVATION,
--   ANCIEN_MOT_DE_PASSE_INCORRECT, MOT_DE_PASSE_IDENTIQUE.
-- Jeton invalide/expiré/révoqué ou admin désactivé : SESSION_INVALIDE (P0401),
-- levée par _session_user comme pour les autres RPC _v2.
--
-- RÈGLE DE TRANSITION (5a-0) : tant que admin_config existe (jusqu'en 5c), le
-- mot de passe de adm_gnienewoki doit rester identique dans admins et
-- admin_config. NE PAS utiliser admin_change_password_v2 sur ce compte avant
-- la bascule du frontend (5b).
--
-- À exécuter en une fois dans l'éditeur SQL de Supabase.
-- ============================================================

BEGIN;

-- Garde-fou : 5a-0 et 5a-1 doivent avoir été exécutées.
DO $$
begin
  if to_regclass('public.admins') is null then
    raise exception 'Table public.admins absente : exécuter d''abord la migration 5a-0';
  end if;
  if to_regprocedure('public.admin_session_open(text,text)') is null then
    raise exception 'admin_session_open absente : exécuter d''abord la migration 5a-1';
  end if;
  if (select count(*) from public.admins a where a.actif = true) not between 1 and 5 then
    raise exception 'Nombre d''admins actifs hors de [1, 5] : corriger avant d''installer trg_admins_quota';
  end if;
end $$;

-- ------------------------------------------------------------
-- 1) Trigger trg_admins_quota
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admins_quota_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_autres_actifs bigint;
begin
  -- Sérialise toutes les écritures qui touchent au nombre d'admins actifs.
  perform pg_advisory_xact_lock(hashtext('orimetier.admins_quota'));

  if tg_op = 'DELETE' then
    if old.actif then
      execute format('select count(*) from %s a where a.actif = true and a.id <> $1', tg_relid::regclass)
        into v_autres_actifs using old.id;
      if v_autres_actifs = 0 then
        raise exception 'DERNIER_ADMIN_ACTIF';
      end if;
    end if;
    return old;
  end if;

  if tg_op = 'INSERT' then
    if new.actif then
      execute format('select count(*) from %s a where a.actif = true and a.id <> $1', tg_relid::regclass)
        into v_autres_actifs using new.id;
      if v_autres_actifs >= 5 then
        raise exception 'ADMINS_LIMITE_ATTEINTE';
      end if;
    end if;
    return new;
  end if;

  -- UPDATE (de actif)
  if new.actif and not old.actif then
    execute format('select count(*) from %s a where a.actif = true and a.id <> $1', tg_relid::regclass)
      into v_autres_actifs using new.id;
    if v_autres_actifs >= 5 then
      raise exception 'ADMINS_LIMITE_ATTEINTE';
    end if;
  elsif old.actif and not new.actif then
    execute format('select count(*) from %s a where a.actif = true and a.id <> $1', tg_relid::regclass)
      into v_autres_actifs using old.id;
    if v_autres_actifs = 0 then
      raise exception 'DERNIER_ADMIN_ACTIF';
    end if;
  end if;
  return new;
end; $function$;

REVOKE ALL ON FUNCTION public.admins_quota_trigger() FROM public, anon, authenticated;

CREATE TRIGGER trg_admins_quota
  BEFORE INSERT OR UPDATE OF actif OR DELETE ON public.admins
  FOR EACH ROW EXECUTE FUNCTION admins_quota_trigger();

-- ------------------------------------------------------------
-- 2) admin_list_admins_v2 : jamais le mot de passe
-- ------------------------------------------------------------
-- RETURNS TABLE(id, nom, email, actif, ...) : toutes les colonnes de la
-- requête sont qualifiées par l'alias "a" (les noms de sortie sont aussi des
-- variables plpgsql).
CREATE OR REPLACE FUNCTION public.admin_list_admins_v2(p_token text)
 RETURNS TABLE(id text, nom text, email text, actif boolean, created_at timestamptz, last_login_at timestamptz)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');

  return query
    select a.id, a.nom, a.email, a.actif, a.created_at, a.last_login_at
    from admins a
    order by a.created_at asc, a.id asc;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_list_admins_v2(text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_list_admins_v2(text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 3) admin_create_admin_v2 : nouveau compte admin (actif)
-- ------------------------------------------------------------
-- Renvoie {id, nom, email}. Le mot de passe est haché par trg_hash_password.
-- La limite de 5 actifs est vérifiée par trg_admins_quota.
CREATE OR REPLACE FUNCTION public.admin_create_admin_v2(p_token text, p_nom text, p_email text, p_password text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id text;
  v_nom text := trim(coalesce(p_nom, ''));
  v_email text := trim(coalesce(p_email, ''));
begin
  perform _session_user(p_token, 'admin');

  if v_nom = '' or v_email = '' then
    raise exception 'CHAMPS_OBLIGATOIRES';
  end if;
  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'EMAIL_INVALIDE';
  end if;
  if length(coalesce(p_password, '')) < 8 then
    raise exception 'MOT_DE_PASSE_TROP_COURT';
  end if;
  if exists (select 1 from admins a where lower(trim(a.email)) = lower(v_email)) then
    raise exception 'EMAIL_DEJA_UTILISE';
  end if;

  v_id := 'adm_' || encode(extensions.gen_random_bytes(8), 'hex');

  begin
    insert into admins(id, nom, email, password)
    values (v_id, v_nom, v_email, p_password);
  exception when unique_violation then
    -- Course entre deux créations simultanées avec le même e-mail
    -- (index admins_email_unique).
    raise exception 'EMAIL_DEJA_UTILISE';
  end;

  return jsonb_build_object('id', v_id, 'nom', v_nom, 'email', v_email);
end; $function$;

REVOKE ALL ON FUNCTION public.admin_create_admin_v2(text, text, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_create_admin_v2(text, text, text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 4) admin_set_admin_actif_v2 : désactiver / réactiver un admin
-- ------------------------------------------------------------
-- true : fait ; false : admin inconnu ou p_actif null.
-- Se désactiver soi-même : ADMIN_AUTO_DESACTIVATION.
-- Dernier admin actif / limite de 5 : trg_admins_quota.
-- Désactivation : les sessions de l'admin visé sont révoquées par
-- trg_admins_revoke_sessions (5a-1).
CREATE OR REPLACE FUNCTION public.admin_set_admin_actif_v2(p_token text, p_admin_id text, p_actif boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_me text;
begin
  v_me := _session_user(p_token, 'admin');

  if p_actif is null then
    return false;
  end if;
  if p_admin_id = v_me and p_actif = false then
    raise exception 'ADMIN_AUTO_DESACTIVATION';
  end if;

  update admins a set actif = p_actif where a.id = p_admin_id;
  return found;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_set_admin_actif_v2(text, text, boolean) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_set_admin_actif_v2(text, text, boolean) TO anon, authenticated;

-- ------------------------------------------------------------
-- 5) admin_change_password_v2 : changer SON PROPRE mot de passe
-- ------------------------------------------------------------
-- Le changement déclenche (5a-1) la révocation de TOUTES les sessions de cet
-- admin, y compris celle qui fait l'appel : une nouvelle session de 24 h est
-- donc ouverte ici et renvoyée {token, expires_at}, pour que l'utilisateur
-- reste connecté. La révocation (trigger AFTER UPDATE) a lieu à la fin de
-- l'UPDATE, AVANT la création de la nouvelle session : celle-ci n'est pas
-- révoquée.
CREATE OR REPLACE FUNCTION public.admin_change_password_v2(p_token text, p_ancien text, p_nouveau text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_me text;
  v_hash text;
  v_token text;
  v_expires_at timestamptz;
begin
  v_me := _session_user(p_token, 'admin');

  select a.password into v_hash from admins a where a.id = v_me for update;

  if coalesce(p_ancien, '') = '' or v_hash <> extensions.crypt(p_ancien, v_hash) then
    raise exception 'ANCIEN_MOT_DE_PASSE_INCORRECT';
  end if;
  if length(coalesce(p_nouveau, '')) < 8 then
    raise exception 'MOT_DE_PASSE_TROP_COURT';
  end if;
  if p_nouveau = p_ancien then
    raise exception 'MOT_DE_PASSE_IDENTIQUE';
  end if;

  -- trg_hash_password hache ; trg_admins_password_changed met à jour
  -- password_changed_at ; trg_admins_revoke_sessions révoque les sessions.
  update admins a set password = p_nouveau where a.id = v_me;

  v_token := encode(extensions.gen_random_bytes(32), 'hex');
  insert into sessions(token_hash, role, user_id, expires_at)
  values (encode(extensions.digest(v_token, 'sha256'), 'hex'), 'admin', v_me, now() + interval '24 hours')
  returning expires_at into v_expires_at;

  return jsonb_build_object('token', v_token, 'expires_at', v_expires_at);
end; $function$;

REVOKE ALL ON FUNCTION public.admin_change_password_v2(text, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_change_password_v2(text, text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 6) Commentaires de la table admins
-- ------------------------------------------------------------
COMMENT ON TABLE public.admins IS 'Comptes administrateur nominatifs : 5 actifs au maximum, au moins 1 actif (trigger trg_admins_quota). Accès uniquement via fonctions SECURITY DEFINER ; jamais de GRANT à anon/authenticated, jamais dans la publication realtime. Depuis l''application (RPC par jeton) : lister, créer, désactiver/réactiver, changer SON PROPRE mot de passe. Pas de suppression de compte depuis l''application. Réinitialisation du mot de passe d''un autre admin : SQL Editor uniquement';
COMMENT ON COLUMN public.admins.actif IS 'false = compte désactivé : connexion refusée, sessions révoquées (5a-1). 5 actifs au maximum, jamais 0 (trg_admins_quota)';

COMMIT;

-- ============================================================
-- VÉRIFICATIONS (à lancer après exécution, une requête à la fois)
-- ============================================================
--
-- V1a. Fonctions présentes (5 lignes : admins_quota_trigger, admin_list_admins_v2,
--      admin_create_admin_v2, admin_set_admin_actif_v2, admin_change_password_v2)
-- select p.oid::regprocedure as fonction
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('admins_quota_trigger', 'admin_list_admins_v2', 'admin_create_admin_v2',
--                     'admin_set_admin_actif_v2', 'admin_change_password_v2')
-- order by 1;
--
-- V1b. Triggers de admins (4 lignes : trg_admins_password_changed, trg_admins_quota,
--      trg_admins_revoke_sessions, trg_hash_password)
-- select t.tgname, pg_get_triggerdef(t.oid) from pg_trigger t
-- where t.tgrelid = 'public.admins'::regclass and not t.tgisinternal order by 1;
--
-- V2. Sécurité (5 lignes) : security_definer = true et config = {search_path=public}
--     partout ; anon = true pour les 4 RPC, anon = false pour admins_quota_trigger ;
--     sans_mot_de_passe = true pour admin_list_admins_v2.
-- select p.oid::regprocedure as fonction, p.prosecdef as security_definer, p.proconfig as config,
--        has_function_privilege('anon', p.oid, 'EXECUTE') as anon,
--        has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated,
--        pg_get_function_result(p.oid) !~* 'password' as sans_mot_de_passe
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('admins_quota_trigger', 'admin_list_admins_v2', 'admin_create_admin_v2',
--                     'admin_set_admin_actif_v2', 'admin_change_password_v2')
-- order by 1;
--
-- V3. Test fonctionnel complet SANS trace : fichier séparé
--     test-5a3-v3.sql (bloc prêt à coller, ROLLBACK final).
--
-- V4. Aucune trace laissée par V3, et compte réel intact
--     (attendu : admins_test = 0, sessions_orphelines = 0, meme_hash = true,
--      gnienewoki_actif = true)
-- select (select count(*) from public.admins a
--           where a.id like 'adm_test%' or a.email like 'test-5a3%') as admins_test,
--        (select count(*) from public.sessions s
--           where s.role = 'admin'
--             and not exists (select 1 from public.admins a where a.id = s.user_id)) as sessions_orphelines,
--        (select a.password = ac.admin_password
--           from public.admins a cross join public.admin_config ac
--          where a.id = 'adm_gnienewoki' and ac.id = 1) as meme_hash,
--        (select a.actif from public.admins a where a.id = 'adm_gnienewoki') as gnienewoki_actif;
