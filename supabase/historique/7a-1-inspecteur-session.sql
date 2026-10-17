-- ============================================================
-- ORIMETIER — Phase 7a-1 : socle des sessions inspecteur par jeton.
--
-- Pré-requis : Phase 1 (sessions, _session_user, session_check,
-- session_close), Phase 3, reset-4a et 5a-1 (_session_user réécrite,
-- admin_session_open) exécutées.
-- Migration ADDITIVE : inspecteur_login et les 26 RPC par mot de passe
-- restent en service jusqu'en 7c. _session_user N'EST PAS modifiée (sa
-- branche 'inspecteur' existe déjà : fiche existante et non bannie).
-- Source du code existant : supabase/reference/live-2026-09-26.sql
-- (inspecteur_login l. 947-955, inchangée depuis d'après l'audit 7).
--
--   1) inspecteur_session_open(p_tel, p_password)
--        Gabarits : eleve_session_open (2a) et etablissement_session_open (6a-1).
--        - téléphone comparé en EXACT (tel = p_tel), comme inspecteur_login :
--          le frontend garde son double essai (numéro normalisé, puis saisie
--          brute) pour les anciens comptes. Index inspecteurs_tel_unique :
--          au plus une fiche ;
--        - fiche sans mot de passe exclue de la recherche (password is not
--          null) : traitée comme un numéro inconnu. Sans ce filtre, crypt(x,
--          NULL) vaut NULL, la comparaison ne serait jamais vraie et la
--          session s'ouvrirait ;
--        - numéro inconnu : calcul bcrypt factice (anti-énumération par le
--          temps de réponse), réponse null ;
--        - mot de passe comparé avec IS DISTINCT FROM ;
--        - compte banni : contrôlé APRÈS le mot de passe ; renvoie
--          {banni:true} et AUCUNE session n'est créée (le frontend affiche
--          « Ce compte a été suspendu », comme aujourd'hui) ;
--        - session de 30 jours ; retour {token, expires_at, id, nom, prenoms}.
--
--   2) Trigger trg_inspecteurs_revoke_sessions (AFTER UPDATE OF password
--      OR DELETE, FOR EACH ROW) : révoque les sessions role='inspecteur'
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
--        - les UPDATE qui ne mettent pas password dans leur SET (avatar,
--          message d'accueil, e-mail, certification, bannissement par
--          l'admin) : le trigger ne se déclenche pas ;
--        - reset_password_with_token révoque déjà les sessions : la double
--          révocation est sans effet (filtre revoked = false) ;
--        - DELETE : défensif (aucune fonction ne supprime un inspecteur ;
--          la FK suivi_eleves.inspecteur_id bloque déjà une fiche qui a des
--          élèves suivis).
--      AFTER (et non BEFORE) : la révocation agit sur une autre table et ne
--      doit avoir lieu que si la modification de la fiche a bien eu lieu
--      (même choix que trg_admins_revoke_sessions et
--      trg_etablissements_revoke_sessions).
--
--   3) REVOKE ALL des droits d'anon, authenticated et PUBLIC sur
--      lycam_sessions, lycam_resultats, mbti_sessions, mbti_resultats,
--      messages_prives, suivi_eleves, suivi_eleves_notes.
--      Vérifié dans le repo le 03/10/2026 : aucun JS/HTML ne lit ni n'écrit
--      ces tables directement (tout passe par les RPC inspecteur_*).
--      UNE dépendance indirecte : supabase-client.js:145 s'abonne en temps
--      réel (postgres_changes) à messages_prives. Supabase ne transmet ces
--      événements qu'à un rôle qui a le droit SELECT sur la table. Après ce
--      REVOKE, un nouveau message privé ne déclenche donc plus SEUL le
--      rafraîchissement automatique. Il reste rechargé à chaque événement
--      des autres tables, à l'ouverture d'une conversation, après un envoi
--      et à chaque changement de page. Si anon a ce droit aujourd'hui, tous
--      les messages privés sont lisibles avec la clé publique : ce REVOKE
--      ferme cette fuite (choix validé). Voir V0, V5 et V6.
--      Non touchés (voulu) : SELECT public sur messages_inspecteurs et notes ;
--      INSERT d'anon sur inspecteurs et eleves (Phase 8).
--
-- Idempotent : CREATE OR REPLACE, DROP TRIGGER IF EXISTS, REVOKE rejouable.
-- À exécuter en une fois dans l'éditeur SQL de Supabase.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 0) Garde-fous
-- ------------------------------------------------------------
DO $$
declare
  t text;
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
  if to_regclass('public.inspecteurs_tel_unique') is null then
    raise exception 'Index inspecteurs_tel_unique absent : vérifier la table inspecteurs avant de continuer';
  end if;
  foreach t in array array['lycam_sessions','lycam_resultats','mbti_sessions','mbti_resultats',
                           'messages_prives','suivi_eleves','suivi_eleves_notes'] loop
    if to_regclass('public.' || t) is null then
      raise exception 'Table public.% absente : migration annulée', t;
    end if;
  end loop;
end $$;

-- ------------------------------------------------------------
-- 1) inspecteur_session_open : ouverture de session (publique)
-- ------------------------------------------------------------
-- null : téléphone/mot de passe incorrects ou vides, numéro inconnu, ou
--        fiche sans mot de passe.
-- {banni:true} : identifiants corrects mais compte suspendu ; aucune session.
-- {token, expires_at, id, nom, prenoms} : session ouverte pour 30 jours.
CREATE OR REPLACE FUNCTION public.inspecteur_session_open(p_tel text, p_password text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_insp inspecteurs%rowtype;
  v_token text;
  v_expires_at timestamptz;
begin
  if coalesce(p_tel, '') = '' or coalesce(p_password, '') = '' then
    return null;
  end if;

  -- Ménage : sessions expirées depuis plus de 7 jours (tous rôles).
  delete from sessions s where s.expires_at < now() - interval '7 days';

  -- Téléphone exact, comme inspecteur_login (index unique : au plus une fiche).
  select i.* into v_insp
  from inspecteurs i
  where i.tel = p_tel
    and i.password is not null;

  if not found then
    perform extensions.crypt(p_password, extensions.gen_salt('bf'));
    return null;
  end if;

  if v_insp.password is distinct from extensions.crypt(p_password, v_insp.password) then
    return null;
  end if;

  if coalesce(v_insp.banni, false) then
    return jsonb_build_object('banni', true);
  end if;

  v_token := encode(extensions.gen_random_bytes(32), 'hex');

  insert into sessions(token_hash, role, user_id, expires_at)
  values (encode(extensions.digest(v_token, 'sha256'), 'hex'), 'inspecteur', v_insp.id, now() + interval '30 days')
  returning expires_at into v_expires_at;

  return jsonb_build_object(
    'token', v_token,
    'expires_at', v_expires_at,
    'id', v_insp.id,
    'nom', v_insp.nom,
    'prenoms', v_insp.prenoms
  );
end; $function$;

REVOKE ALL ON FUNCTION public.inspecteur_session_open(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.inspecteur_session_open(text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 2) Révocation des sessions d'une fiche (mot de passe changé, suppression)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inspecteurs_revoke_sessions_trigger()
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
    where s.role = 'inspecteur' and s.user_id = old.id and s.revoked = false;
  elsif new.password is distinct from old.password then
    update sessions s set revoked = true
    where s.role = 'inspecteur' and s.user_id = old.id and s.revoked = false;
  end if;
  return null;
end; $function$;

REVOKE ALL ON FUNCTION public.inspecteurs_revoke_sessions_trigger() FROM public, anon, authenticated;

DROP TRIGGER IF EXISTS trg_inspecteurs_revoke_sessions ON public.inspecteurs;
CREATE TRIGGER trg_inspecteurs_revoke_sessions
  AFTER UPDATE OF password OR DELETE ON public.inspecteurs
  FOR EACH ROW EXECUTE FUNCTION inspecteurs_revoke_sessions_trigger();

-- ------------------------------------------------------------
-- 3) Tables de l'espace inspecteur : aucun droit direct pour la clé publique
-- ------------------------------------------------------------
REVOKE ALL ON TABLE public.lycam_sessions     FROM anon, authenticated, PUBLIC;
REVOKE ALL ON TABLE public.lycam_resultats    FROM anon, authenticated, PUBLIC;
REVOKE ALL ON TABLE public.mbti_sessions      FROM anon, authenticated, PUBLIC;
REVOKE ALL ON TABLE public.mbti_resultats     FROM anon, authenticated, PUBLIC;
REVOKE ALL ON TABLE public.messages_prives    FROM anon, authenticated, PUBLIC;
REVOKE ALL ON TABLE public.suivi_eleves       FROM anon, authenticated, PUBLIC;
REVOKE ALL ON TABLE public.suivi_eleves_notes FROM anon, authenticated, PUBLIC;

COMMIT;

-- ============================================================
-- VÉRIFICATIONS (une requête à la fois)
-- ============================================================
--
-- V0. (FACULTATIF, À LANCER AVANT la migration) droits directs actuels sur les
--     7 tables : indique notamment si messages_prives était lisible par anon.
-- select table_name, grantee, privilege_type from information_schema.role_table_grants
-- where table_schema = 'public'
--   and table_name in ('lycam_sessions','lycam_resultats','mbti_sessions','mbti_resultats',
--                      'messages_prives','suivi_eleves','suivi_eleves_notes')
--   and grantee in ('anon','authenticated','PUBLIC')
-- order by 1, 2, 3;
--
-- V1. Fonctions : SECURITY DEFINER + search_path + droits
--     inspecteur_session_open : anon = true, authenticated = true
--     inspecteurs_revoke_sessions_trigger et _session_user : anon = false, authenticated = false
-- select p.oid::regprocedure as fonction, p.prosecdef as security_definer, p.proconfig as config,
--        has_function_privilege('anon', p.oid, 'EXECUTE') as anon,
--        has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('inspecteur_session_open', 'inspecteurs_revoke_sessions_trigger', '_session_user');
--
-- V2. Triggers de inspecteurs. Attendu :
--       trg_hash_password               BEFORE  INSERT OR UPDATE OF password
--       trg_inspecteurs_revoke_sessions AFTER   UPDATE OF password OR DELETE
--     (un BEFORE s'exécute toujours avant un AFTER : la révocation compare des hash finaux)
-- select tgname,
--        case when (tgtype & 2) = 2 then 'BEFORE' else 'AFTER' end as moment,
--        pg_get_triggerdef(t.oid)
-- from pg_trigger t
-- where t.tgrelid = 'public.inspecteurs'::regclass and not t.tgisinternal
-- order by 2 desc, 1;
--
-- V3. Droits directs sur les 7 tables (0 ligne attendue)
-- select table_name, grantee, privilege_type from information_schema.role_table_grants
-- where table_schema = 'public'
--   and table_name in ('lycam_sessions','lycam_resultats','mbti_sessions','mbti_resultats',
--                      'messages_prives','suivi_eleves','suivi_eleves_notes')
--   and grantee in ('anon','authenticated','PUBLIC');
--
-- V4. La clé publique ne lit plus ces tables
--     (erreur attendue "permission denied for table messages_prives" ; idem en
--     remplaçant par chacune des 6 autres tables)
-- begin; set local role anon; select count(*) from public.messages_prives; rollback;
--
-- V5. Tables publiées en temps réel (pour information) : si messages_prives figure
--     ici, ses événements ne sont plus transmis à anon (voulu, voir l'en-tête, section 3).
-- select tablename from pg_publication_tables
-- where pubname = 'supabase_realtime'
--   and tablename in ('lycam_sessions','lycam_resultats','mbti_sessions','mbti_resultats',
--                     'messages_prives','suivi_eleves','suivi_eleves_notes',
--                     'inspecteurs','messages_inspecteurs','notes');
--
-- V6. Droits voulus intacts : SELECT public sur messages_inspecteurs et notes,
--     INSERT d'anon sur inspecteurs et eleves (inscription). Attendu : mêmes lignes
--     qu'avant la migration.
-- select table_name, grantee, privilege_type from information_schema.role_table_grants
-- where table_schema = 'public'
--   and table_name in ('messages_inspecteurs','notes','inspecteurs','eleves')
--   and grantee in ('anon','authenticated','PUBLIC')
-- order by 1, 2, 3;
--
-- V7. Aucune session pour un banni ni pour une fiche sans mot de passe.
--     (a) la fonction contrôle bien ces cas (true, true, true) :
-- select p.prosrc like '%i.password is not null%' as exclut_sans_mdp,
--        p.prosrc like '%''banni'', true%' as renvoie_banni,
--        position('''banni'', true' in p.prosrc) < position('insert into sessions' in p.prosrc) as banni_avant_insert
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public' and p.proname = 'inspecteur_session_open';
--     (b) aucune session inspecteur active pour un compte banni (0 attendu) :
-- select count(*) from public.sessions s join public.inspecteurs i on i.id = s.user_id
-- where s.role = 'inspecteur' and s.revoked = false and s.expires_at > now()
--   and coalesce(i.banni, false);
--
-- V8. Test fonctionnel complet SANS trace : fichier séparé 7a-1-tests-rollback.sql,
--     puis sa requête V-trace.
