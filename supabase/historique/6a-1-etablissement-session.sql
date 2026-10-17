-- ============================================================
-- ORIMETIER — Phase 6a-1 : socle des sessions établissement par jeton.
--
-- Pré-requis : Phase 1 (sessions, _session_user, session_check,
-- session_close), Phase 3 (index unique etablissements_email_unique) et
-- 5a-1 (_session_user réécrite, admin_session_open) exécutées.
-- Migration ADDITIVE : etablissement_login et les 9 RPC par mot de passe
-- restent en service jusqu'en 6c. _session_user N'EST PAS modifiée (sa
-- branche 'etablissement' existe déjà : fiche existante).
--
--   1) etablissement_session_open(p_email, p_password)
--        Gabarit : admin_session_open (5a-1) et eleve_session_open (2a).
--        - e-mail comparé en lower(trim(...)) des deux côtés (aligné sur
--          l'index unique de la Phase 3 : au plus une fiche) ;
--        - fiches non réclamées (e-mail ou mot de passe NULL) exclues de la
--          recherche : traitées comme un e-mail inconnu, jamais connectables ;
--        - e-mail inconnu : calcul bcrypt factice (anti-énumération par le
--          temps de réponse), réponse null ;
--        - AUCUN contrôle de statut / active / reclame (comportement actuel
--          de etablissement_login conservé) ;
--        - session de 30 jours ; retour {token, expires_at, id, nom} ou null ;
--        - pas de last_login_at (colonne absente de etablissements, non ajoutée).
--
--   2) Trigger trg_etablissements_revoke_sessions (AFTER UPDATE OF password
--      OR DELETE, FOR EACH ROW) : révoque les sessions role='etablissement'
--      de la fiche quand la fiche est supprimée, ou quand son mot de passe
--      CHANGE réellement (OLD.password IS DISTINCT FROM NEW.password).
--
--      Ordre d'exécution : trg_hash_password est un trigger BEFORE ; il
--      s'exécute donc toujours AVANT ce trigger AFTER. La comparaison porte
--      sur l'ancien hash et le hash FINAL stocké, jamais sur du clair :
--        - nouveau mot de passe (même identique à l'ancien) : nouveau sel
--          bcrypt -> hash différent -> sessions révoquées (voulu) ;
--        - réécriture du hash existant tel quel : hash_password_trigger le
--          laisse passer (format $2a/b/y$) -> valeur identique -> rien
--          n'est révoqué ;
--        - UPDATE OF password se déclenche dès que la colonne figure dans le
--          SET, même inchangée : d'où le test IS DISTINCT FROM.
--      Cas existants :
--        - etablissement_update_info ne met pas password dans son SET : le
--          trigger ne se déclenche pas ;
--        - etablissement_claim_by_code change le mot de passe d'une fiche
--          sans session : le trigger tourne et ne révoque rien ;
--        - reset_password_with_token révoque déjà les sessions : la double
--          révocation est sans effet (filtre revoked = false).
--      AFTER (et non BEFORE) : la révocation agit sur une autre table et ne
--      doit avoir lieu que si la modification de la fiche a bien eu lieu
--      (même choix que trg_admins_revoke_sessions en 5a-1).
--
--   3) REVOKE ALL sur demandes_inscription_etablissements pour anon,
--      authenticated et PUBLIC. Aucun accès direct n'est utile : tout passe
--      par des fonctions SECURITY DEFINER (etablissement_register,
--      etablissement_verifier_doublon, admin_*_v2). Vérifié dans le repo le
--      02/10/2026 : aucun JS/HTML ne lit ni n'écrit cette table directement
--      (seulement admin_list_demandes_inscription_etablissements_v2 via
--      espAuthRpc, supabase-client.js:246).
--
-- Idempotent : CREATE OR REPLACE, DROP TRIGGER IF EXISTS, REVOKE rejouable.
-- À exécuter en une fois dans l'éditeur SQL de Supabase.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 0) Garde-fous
-- ------------------------------------------------------------
DO $$
begin
  if to_regclass('public.sessions') is null then
    raise exception 'Table public.sessions absente : exécuter d''abord la Phase 1';
  end if;
  if to_regprocedure('public._session_user(text,text)') is null then
    raise exception '_session_user absente : exécuter d''abord la Phase 1';
  end if;
  if to_regprocedure('public.admin_session_open(text,text)') is null then
    raise exception 'admin_session_open absente : exécuter d''abord la migration 5a-1';
  end if;
  if to_regclass('public.etablissements_email_unique') is null then
    raise exception 'Index etablissements_email_unique absent : exécuter d''abord la Phase 3';
  end if;
end $$;

-- ------------------------------------------------------------
-- 1) etablissement_session_open : ouverture de session (publique)
-- ------------------------------------------------------------
-- null : e-mail/mot de passe incorrects ou vides, e-mail inconnu, ou fiche
--        non réclamée (e-mail ou mot de passe NULL).
-- {token, expires_at, id, nom} : session ouverte pour 30 jours.
CREATE OR REPLACE FUNCTION public.etablissement_session_open(p_email text, p_password text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_etab etablissements%rowtype;
  v_token text;
  v_expires_at timestamptz;
begin
  if coalesce(trim(p_email), '') = '' or coalesce(p_password, '') = '' then
    return null;
  end if;

  -- Ménage : sessions expirées depuis plus de 7 jours (tous rôles).
  delete from sessions s where s.expires_at < now() - interval '7 days';

  -- Fiches non réclamées exclues : elles n'ont ni e-mail ni mot de passe.
  select et.* into v_etab
  from etablissements et
  where nullif(trim(et.email), '') is not null
    and et.password is not null
    and lower(trim(et.email)) = lower(trim(p_email));

  if not found then
    perform extensions.crypt(p_password, extensions.gen_salt('bf'));
    return null;
  end if;

  if v_etab.password <> extensions.crypt(p_password, v_etab.password) then
    return null;
  end if;

  v_token := encode(extensions.gen_random_bytes(32), 'hex');

  insert into sessions(token_hash, role, user_id, expires_at)
  values (encode(extensions.digest(v_token, 'sha256'), 'hex'), 'etablissement', v_etab.id, now() + interval '30 days')
  returning expires_at into v_expires_at;

  return jsonb_build_object(
    'token', v_token,
    'expires_at', v_expires_at,
    'id', v_etab.id,
    'nom', v_etab.nom
  );
end; $function$;

REVOKE ALL ON FUNCTION public.etablissement_session_open(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.etablissement_session_open(text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 2) Révocation des sessions d'une fiche (mot de passe changé, suppression)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.etablissements_revoke_sessions_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- Deux branches séparées : en SQL, OR n'impose aucun ordre d'évaluation,
  -- et NEW n'a pas de valeur pour un DELETE. NEW n'est donc lu que pour un UPDATE.
  if tg_op = 'DELETE' then
    update sessions s set revoked = true
    where s.role = 'etablissement' and s.user_id = old.id and s.revoked = false;
  elsif new.password is distinct from old.password then
    update sessions s set revoked = true
    where s.role = 'etablissement' and s.user_id = old.id and s.revoked = false;
  end if;
  return null;
end; $function$;

REVOKE ALL ON FUNCTION public.etablissements_revoke_sessions_trigger() FROM public, anon, authenticated;

DROP TRIGGER IF EXISTS trg_etablissements_revoke_sessions ON public.etablissements;
CREATE TRIGGER trg_etablissements_revoke_sessions
  AFTER UPDATE OF password OR DELETE ON public.etablissements
  FOR EACH ROW EXECUTE FUNCTION etablissements_revoke_sessions_trigger();

-- ------------------------------------------------------------
-- 3) Demandes d'inscription : aucun droit direct pour la clé publique
-- ------------------------------------------------------------
REVOKE ALL ON TABLE public.demandes_inscription_etablissements FROM anon, authenticated, PUBLIC;

COMMIT;

-- ============================================================
-- VÉRIFICATIONS (à lancer après exécution, une requête à la fois)
-- ============================================================
--
-- V1. Fonctions : SECURITY DEFINER + search_path + droits
--     etablissement_session_open : anon = true, authenticated = true
--     etablissements_revoke_sessions_trigger et _session_user : anon = false, authenticated = false
-- select p.oid::regprocedure as fonction, p.prosecdef as security_definer, p.proconfig as config,
--        has_function_privilege('anon', p.oid, 'EXECUTE') as anon,
--        has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('etablissement_session_open', 'etablissements_revoke_sessions_trigger', '_session_user');
--
-- V2. Triggers de etablissements (attendu : trg_etablissements_revoke_sessions
--     AFTER UPDATE OF password OR DELETE, et trg_hash_password BEFORE INSERT OR UPDATE OF password)
-- select tgname, pg_get_triggerdef(t.oid) from pg_trigger t
-- where t.tgrelid = 'public.etablissements'::regclass and not t.tgisinternal order by 1;
--
-- V3. Droits directs sur demandes_inscription_etablissements (0 ligne attendue)
-- select grantee, privilege_type from information_schema.role_table_grants
-- where table_schema = 'public' and table_name = 'demandes_inscription_etablissements'
--   and grantee in ('anon', 'authenticated', 'PUBLIC');
--
-- V4. La clé publique ne lit plus la table des demandes
--     (erreur attendue "permission denied for table demandes_inscription_etablissements")
-- begin; set local role anon; select count(*) from public.demandes_inscription_etablissements; rollback;
--
-- V5. Aucune fiche non réclamée connectable.
--     (a) la fonction exclut bien les fiches sans e-mail ou sans mot de passe (true, true) :
-- select p.prosrc like '%et.password is not null%' as exclut_sans_mdp,
--        p.prosrc like '%nullif(trim(et.email), '''') is not null%' as exclut_sans_email
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public' and p.proname = 'etablissement_session_open';
--     (b) état des fiches (pour information ; les lignes "connectable = false" ne peuvent
--         jamais ouvrir de session) :
-- select reclame,
--        (password is not null and nullif(trim(email), '') is not null) as connectable,
--        count(*)
-- from public.etablissements group by 1, 2 order by 1, 2;
--     Attendu : aucune ligne reclame = false ET connectable = true. Si une telle ligne
--     existe, c'est une fiche pré-inscrite qui a reçu un e-mail et un mot de passe
--     hors du circuit de réclamation : à examiner avant 6b.
--
-- V6. Test fonctionnel complet SANS trace : fichier séparé 6a-1-tests-rollback.sql,
--     puis sa requête V-trace.
