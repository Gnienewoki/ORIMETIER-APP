-- ============================================================
-- ORIMETIER — Phase 5a-4 : admin principal (un seul, transférable).
--
-- Pré-requis : 5a-0, 5a-1 et 5a-3 exécutées.
-- Migration ADDITIVE et rejouable : relancer le script ne change rien
-- (en particulier, il n'annule jamais un transfert déjà fait).
--
--   1) admins.est_principal boolean NOT NULL DEFAULT false.
--   2) Invariant : il y a TOUJOURS exactement un principal, et il est actif.
--        - au plus 1   : index unique partiel admins_un_seul_principal
--                        (vérifié immédiatement, ligne par ligne) ;
--        - actif       : CHECK admins_principal_actif (NOT est_principal OR actif)
--                        (vérifié immédiatement, ligne par ligne) ;
--        - au moins 1  : contrainte-trigger trg_admins_principal,
--                        DEFERRABLE INITIALLY DEFERRED, vérifiée au COMMIT.
--      Transfert atomique, dans UNE transaction : ancien -> false (0 principal
--      toléré jusqu'au COMMIT), puis nouveau -> true (l'index voit 1 principal,
--      le CHECK exige qu'il soit actif) ; au COMMIT, trg_admins_principal
--      compte exactement 1 principal actif, sinon tout est annulé.
--      Deux UPDATE successifs, dans cet ordre : un index unique n'est pas
--      différable, un seul UPDATE pourrait écrire "nouveau = true" avant
--      "ancien = false".
--      Même verrou consultatif que trg_admins_quota (inchangé) : les
--      vérifications de quota et d'invariant sont sérialisées.
--   3) Reprise : adm_gnienewoki devient principal (seulement si aucun
--      principal n'existe encore).
--   4) _admin_exiger_principal(p_admin_id) : fonction interne,
--      exception ADMIN_PRINCIPAL_REQUIS.
--   5) admin_create_admin_v2     : réservée au principal.
--   6) admin_set_admin_actif_v2  : réservée au principal ; cibler le principal
--      avec p_actif = false -> ADMIN_PRINCIPAL_PROTEGE (après
--      ADMIN_AUTO_DESACTIVATION, code inchangé).
--   7) admin_transfer_principal_v2(p_token, p_admin_id) : nouvelle.
--   8) admin_list_admins_v2      : + est_principal (toujours sans mot de passe).
--      Changement du type de retour -> DROP puis CREATE, droits redonnés.
--   9) Commentaires de la table.
--
-- Source des fonctions réécrites : migration 5a-3
-- (supabase-migration-2026-09-29-admins-5a-3-comptes.sql), postérieure à la
-- référence live du 2026-09-26. Lancer V0 AVANT et comparer avec la prod.
--
-- Nouveaux codes d'erreur (message de l'exception, SQLSTATE P0001) :
--   ADMIN_PRINCIPAL_REQUIS, ADMIN_PRINCIPAL_PROTEGE, TRANSFERT_VERS_SOI,
--   CIBLE_INACTIVE ; ADMIN_PRINCIPAL_INVARIANT (contrainte-trigger, filet).
-- Codes existants inchangés : CHAMPS_OBLIGATOIRES, EMAIL_INVALIDE,
--   EMAIL_DEJA_UTILISE, MOT_DE_PASSE_TROP_COURT, ADMINS_LIMITE_ATTEINTE,
--   DERNIER_ADMIN_ACTIF, ADMIN_AUTO_DESACTIVATION.
--
-- Conséquences :
--   - Les autres admins (comptes de test compris) deviennent non principaux :
--     ils restent actifs, comptent toujours dans la limite de 5 et gardent
--     toutes les autres actions admin ; ils ne peuvent plus créer, désactiver
--     ni transférer. Seul le principal peut les désactiver.
--   - Désactiver ou supprimer le principal, même dans le SQL Editor, est
--     refusé : transférer d'abord.
--   - Frontend 5b-3 : un admin non principal recevra ADMIN_PRINCIPAL_REQUIS
--     (message brut tant que le frontend n'est pas adapté).
--
-- À exécuter en une fois dans l'éditeur SQL de Supabase.
-- ============================================================

-- ============================================================
-- V0. À LANCER AVANT EXÉCUTION : définitions EN PRODUCTION des 3 fonctions
--     réécrites ici, à comparer avec la migration 5a-3 (même corps attendu).
-- ============================================================
-- select p.oid::regprocedure as fonction, pg_get_functiondef(p.oid) as definition
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('admin_create_admin_v2', 'admin_set_admin_actif_v2', 'admin_list_admins_v2')
-- order by 1;
--
-- V0b. Pré-requis de données (attendu : gnienewoki_actif = true)
-- select (select a.actif from public.admins a where a.id = 'adm_gnienewoki') as gnienewoki_actif,
--        (select count(*) from public.admins a where a.actif) as admins_actifs;

BEGIN;

-- Garde-fous.
DO $$
begin
  if to_regprocedure('public.admins_quota_trigger()') is null
     or to_regprocedure('public.admin_set_admin_actif_v2(text,text,boolean)') is null then
    raise exception 'Migration 5a-3 absente : exécuter d''abord 5a-3';
  end if;
  if not exists (select 1 from public.admins a where a.id = 'adm_gnienewoki' and a.actif = true) then
    raise exception 'adm_gnienewoki absent ou désactivé : le réactiver d''abord (update admins set actif = true where id = ''adm_gnienewoki'')';
  end if;
end $$;

-- ------------------------------------------------------------
-- 1) Colonne, CHECK et index
-- ------------------------------------------------------------
ALTER TABLE public.admins ADD COLUMN IF NOT EXISTS est_principal boolean NOT NULL DEFAULT false;

DO $$
begin
  if not exists (
    select 1 from pg_constraint c
    where c.conrelid = 'public.admins'::regclass and c.conname = 'admins_principal_actif'
  ) then
    alter table public.admins
      add constraint admins_principal_actif check (not est_principal or actif);
  end if;
end $$;

CREATE UNIQUE INDEX IF NOT EXISTS admins_un_seul_principal
  ON public.admins ((true)) WHERE est_principal;

-- ------------------------------------------------------------
-- 2) Reprise : adm_gnienewoki principal (première exécution seulement)
-- ------------------------------------------------------------
DO $$
begin
  if not exists (select 1 from public.admins a where a.est_principal) then
    update public.admins a set est_principal = true where a.id = 'adm_gnienewoki';
    if not found then
      raise exception 'Reprise : adm_gnienewoki introuvable';
    end if;
  end if;
end $$;

-- ------------------------------------------------------------
-- 3) Invariant "au moins un principal, actif" : contrainte-trigger différée
-- ------------------------------------------------------------
-- Vérifiée au COMMIT (ou à SET CONSTRAINTS ... IMMEDIATE). Le comptage porte
-- sur la table du trigger (tg_relid), comme admins_quota_trigger, et se fait
-- après le verrou consultatif : chaque requête du trigger voit les données
-- validées par les autres transactions + celles de la transaction en cours.
CREATE OR REPLACE FUNCTION public.admins_principal_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_principaux bigint;
  v_principaux_actifs bigint;
begin
  perform pg_advisory_xact_lock(hashtext('orimetier.admins_quota'));

  execute format(
    'select count(*), count(*) filter (where a.actif) from %s a where a.est_principal',
    tg_relid::regclass)
    into v_principaux, v_principaux_actifs;

  if v_principaux <> 1 or v_principaux_actifs <> 1 then
    raise exception 'ADMIN_PRINCIPAL_INVARIANT';
  end if;
  return null;
end; $function$;

REVOKE ALL ON FUNCTION public.admins_principal_trigger() FROM public, anon, authenticated;

-- CREATE OR REPLACE n'existe pas pour une contrainte-trigger : DROP puis CREATE.
DROP TRIGGER IF EXISTS trg_admins_principal ON public.admins;
CREATE CONSTRAINT TRIGGER trg_admins_principal
  AFTER INSERT OR UPDATE OF est_principal, actif OR DELETE ON public.admins
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION admins_principal_trigger();

-- ------------------------------------------------------------
-- 4) _admin_exiger_principal : fonction interne (pas d'accès anon)
-- ------------------------------------------------------------
-- FOR SHARE : un transfert simultané (qui verrouille cette ligne FOR UPDATE)
-- attend la fin de l'appel en cours, ou l'appel en cours relit la ligne
-- après le transfert et échoue proprement.
CREATE OR REPLACE FUNCTION public._admin_exiger_principal(p_admin_id text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform 1 from admins a
  where a.id = p_admin_id and a.est_principal = true
  for share;
  if not found then
    raise exception 'ADMIN_PRINCIPAL_REQUIS';
  end if;
end; $function$;

REVOKE ALL ON FUNCTION public._admin_exiger_principal(text) FROM public, anon, authenticated;

-- ------------------------------------------------------------
-- 5) admin_create_admin_v2 : réservée au principal
-- ------------------------------------------------------------
-- Corps 5a-3 ; seuls changements : v_me, et l'appel à _admin_exiger_principal.
-- Le nouveau compte n'est jamais principal (défaut false).
CREATE OR REPLACE FUNCTION public.admin_create_admin_v2(p_token text, p_nom text, p_email text, p_password text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_me text;
  v_id text;
  v_nom text := trim(coalesce(p_nom, ''));
  v_email text := trim(coalesce(p_email, ''));
begin
  v_me := _session_user(p_token, 'admin');
  perform _admin_exiger_principal(v_me);

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
-- 6) admin_set_admin_actif_v2 : réservée au principal, principal protégé
-- ------------------------------------------------------------
-- Ordre : session, ADMIN_PRINCIPAL_REQUIS, p_actif null -> false,
-- ADMIN_AUTO_DESACTIVATION (inchangé), ADMIN_PRINCIPAL_PROTEGE, UPDATE.
-- Via cette fonction, ADMIN_PRINCIPAL_PROTEGE est en pratique précédé par
-- ADMIN_AUTO_DESACTIVATION (seul le principal appelle, et il n'y en a qu'un) :
-- gardé comme filet, avec le CHECK admins_principal_actif en dessous.
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
  perform _admin_exiger_principal(v_me);

  if p_actif is null then
    return false;
  end if;
  if p_admin_id = v_me and p_actif = false then
    raise exception 'ADMIN_AUTO_DESACTIVATION';
  end if;
  if p_actif = false and exists (
    select 1 from admins a where a.id = p_admin_id and a.est_principal = true
  ) then
    raise exception 'ADMIN_PRINCIPAL_PROTEGE';
  end if;

  update admins a set actif = p_actif where a.id = p_admin_id;
  return found;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_set_admin_actif_v2(text, text, boolean) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_set_admin_actif_v2(text, text, boolean) TO anon, authenticated;

-- ------------------------------------------------------------
-- 7) admin_transfer_principal_v2 : nouvelle
-- ------------------------------------------------------------
-- true : transfert fait ; false : cible inconnue (ou null).
-- Ordre : session, ADMIN_PRINCIPAL_REQUIS, TRANSFERT_VERS_SOI, cible
-- inconnue -> false, CIBLE_INACTIVE, puis les 2 UPDATE (ancien d'abord).
-- La ligne de l'appelant est verrouillée FOR UPDATE en premier : deux
-- transferts simultanés sont sérialisés, le second relit
-- est_principal = false et reçoit ADMIN_PRINCIPAL_REQUIS.
-- Les sessions ne sont pas touchées (ni password ni actif ne changent).
CREATE OR REPLACE FUNCTION public.admin_transfer_principal_v2(p_token text, p_admin_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_me text;
  v_cible_actif boolean;
begin
  v_me := _session_user(p_token, 'admin');

  perform 1 from admins a
  where a.id = v_me and a.est_principal = true
  for update;
  if not found then
    raise exception 'ADMIN_PRINCIPAL_REQUIS';
  end if;

  if p_admin_id = v_me then
    raise exception 'TRANSFERT_VERS_SOI';
  end if;

  select a.actif into v_cible_actif
  from admins a
  where a.id = p_admin_id
  for update;
  if not found then
    return false;
  end if;
  if not v_cible_actif then
    raise exception 'CIBLE_INACTIVE';
  end if;

  update admins a set est_principal = false where a.id = v_me;
  update admins a set est_principal = true where a.id = p_admin_id;
  return true;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_transfer_principal_v2(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_transfer_principal_v2(text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 8) admin_list_admins_v2 : + est_principal, jamais le mot de passe
-- ------------------------------------------------------------
-- Le type de retour change : CREATE OR REPLACE impossible -> DROP puis CREATE.
-- Toutes les colonnes de la requête sont qualifiées par l'alias "a" (les noms
-- de sortie de RETURNS TABLE sont aussi des variables plpgsql).
DROP FUNCTION IF EXISTS public.admin_list_admins_v2(text);

CREATE FUNCTION public.admin_list_admins_v2(p_token text)
 RETURNS TABLE(id text, nom text, email text, actif boolean, est_principal boolean, created_at timestamptz, last_login_at timestamptz)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform _session_user(p_token, 'admin');

  return query
    select a.id, a.nom, a.email, a.actif, a.est_principal, a.created_at, a.last_login_at
    from admins a
    order by a.created_at asc, a.id asc;
end; $function$;

REVOKE ALL ON FUNCTION public.admin_list_admins_v2(text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_list_admins_v2(text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 9) Commentaires
-- ------------------------------------------------------------
COMMENT ON TABLE public.admins IS 'Comptes administrateur nominatifs : 5 actifs au maximum, au moins 1 actif (trigger trg_admins_quota) ; exactement 1 admin principal, toujours actif (index admins_un_seul_principal, CHECK admins_principal_actif, contrainte-trigger différée trg_admins_principal). Accès uniquement via fonctions SECURITY DEFINER ; jamais de GRANT à anon/authenticated, jamais dans la publication realtime. Depuis l''application (RPC par jeton) : lister, changer SON PROPRE mot de passe (tous) ; créer, désactiver/réactiver, transférer le rôle de principal (principal uniquement). Pas de suppression de compte depuis l''application. Réinitialisation du mot de passe d''un autre admin : SQL Editor uniquement';
COMMENT ON COLUMN public.admins.est_principal IS 'true pour exactement un admin, toujours actif. Seul le principal crée, désactive/réactive les admins et transfère ce rôle (admin_transfer_principal_v2). Pour désactiver ou supprimer le principal : transférer d''abord';

COMMIT;

-- ============================================================
-- VÉRIFICATIONS (à lancer après exécution, une requête à la fois)
-- ============================================================
--
-- V1. Colonne, CHECK et index
--     (est_principal : boolean, NO, false ; admins_principal_actif présent ;
--      admins_un_seul_principal : UNIQUE ... WHERE est_principal)
-- select column_name, data_type, is_nullable, column_default
-- from information_schema.columns
-- where table_schema = 'public' and table_name = 'admins' and column_name = 'est_principal';
-- select conname, pg_get_constraintdef(c.oid) from pg_constraint c
-- where c.conrelid = 'public.admins'::regclass and c.conname = 'admins_principal_actif';
-- select indexname, indexdef from pg_indexes
-- where schemaname = 'public' and tablename = 'admins' and indexname = 'admins_un_seul_principal';
--
-- V2. Triggers de admins (5 lignes : trg_admins_password_changed, trg_admins_principal,
--     trg_admins_quota, trg_admins_revoke_sessions, trg_hash_password ;
--     trg_admins_principal : deferrable = true, initdeferred = true)
-- select t.tgname, t.tgdeferrable as deferrable, t.tginitdeferred as initdeferred,
--        pg_get_triggerdef(t.oid)
-- from pg_trigger t
-- where t.tgrelid = 'public.admins'::regclass and not t.tgisinternal order by 1;
--
-- V3. Sécurité (7 lignes) : security_definer = true et config = {search_path=public}
--     partout ; anon = true pour les 4 RPC (admin_create_admin_v2,
--     admin_list_admins_v2, admin_set_admin_actif_v2, admin_transfer_principal_v2),
--     anon = false pour _admin_exiger_principal, admins_principal_trigger,
--     admins_quota_trigger ; sans_mot_de_passe = true pour admin_list_admins_v2.
-- select p.oid::regprocedure as fonction, p.prosecdef as security_definer, p.proconfig as config,
--        has_function_privilege('anon', p.oid, 'EXECUTE') as anon,
--        has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated,
--        pg_get_function_result(p.oid) !~* 'password' as sans_mot_de_passe
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('_admin_exiger_principal', 'admins_principal_trigger', 'admins_quota_trigger',
--                     'admin_create_admin_v2', 'admin_list_admins_v2',
--                     'admin_set_admin_actif_v2', 'admin_transfer_principal_v2')
-- order by 1;
--
-- V4. Exactement 1 principal, actif : adm_gnienewoki
--     (attendu : nb_principaux = 1, principal = adm_gnienewoki, principal_actif = true)
-- select (select count(*) from public.admins a where a.est_principal) as nb_principaux,
--        (select a.id from public.admins a where a.est_principal) as principal,
--        (select a.actif from public.admins a where a.est_principal) as principal_actif;
--
-- V5. La clé publique ne peut pas appeler la fonction interne (erreur attendue "permission denied")
-- begin; set local role anon; select public._admin_exiger_principal('adm_gnienewoki'); rollback;
--
-- V6. Test fonctionnel complet SANS trace : fichier séparé 5a-4-tests-rollback.sql
--     (bloc prêt à coller, ROLLBACK final).
