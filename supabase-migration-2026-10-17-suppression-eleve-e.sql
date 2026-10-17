-- ============================================================
-- ORIMETIER — Suppression du compte élève : ÉTAPE e (fonctions et rôle 'eleve')
-- Une seule transaction : si une instruction échoue, RIEN n'est appliqué.
--
-- Pré-requis :
--   - étape d exécutée (le garde-fou 0 le vérifie) ;
--   - test à blanc 0 : les 5 lignes « fonction_a_adapter » valent « IDENTIQUE au dépôt »
--     (le garde-fou 0 le revérifie : aucun corps n'est deviné).
--
-- Effets :
--   1. Supprime les lignes de rôle 'eleve' de password_resets puis de sessions.
--   2. Réécrit, à partir de leur dernière version versionnée dans le dépôt :
--        _session_user(text, text)                (supabase-migration-2026-09-28-admins-5a-1-session.sql)
--        password_reset_create(text, text, text)  (supabase-migration-2026-09-27-reset-4a.sql)
--        reset_password_with_token(text, text)    (supabase-migration-2026-09-27-reset-4a.sql)
--      Seule différence : le rôle 'eleve' disparaît. _session_user passe en LISTE BLANCHE
--      ('inspecteur', 'etablissement', 'admin') : un rôle inconnu est refusé (P0401) même
--      si une ligne sessions subsistait, au lieu d'être accepté faute de branche.
--      Corps AVANT / APRÈS complets : suppression-eleve-notes.md.
--   3. NON modifiées (vérifiées identiques au dépôt par le test à blanc) :
--        session_check(text) : ne cite aucun rôle ; elle délègue à _session_user, donc un
--          jeton de rôle 'eleve' y renvoie désormais null (session refusée) ;
--        session_close(text) : révoque n'importe quel jeton, sans notion de rôle.
--   4. Supprime (signatures exactes, sans IF EXISTS) :
--        eleve_session_open(text, text), eleve_save_riasec(text, jsonb),
--        eleve_update_email(text, text), list_eleves(), admin_set_eleve_banni_v2(text, text, boolean).
--   5. Recrée les contraintes CHECK sur role sans 'eleve' :
--        sessions.role        IN ('inspecteur', 'etablissement', 'admin')
--        password_resets.role IN ('inspecteur', 'etablissement')
--      (la contrainte d'origine de sessions n'a pas de nom explicite : elle est retrouvée
--       par sa définition, puis recréée sous le nom sessions_role_check).
--   6. Garde-fou final : plus aucune fonction du schéma public ne lit/écrit la table eleves
--      ni ne cite le rôle 'eleve' (seule exception attendue : admin_upsert_lien_formation_v2,
--      dont 'eleve' est l'audience des liens de formation, sans rapport avec le compte).
--
-- Les tables eleves et notes NE sont PAS supprimées ici (étape f).
-- Retour arrière : suppression-eleve-notes.md, section « Retour arrière de l'étape e ».
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 0) Garde-fous
-- ------------------------------------------------------------
DO $$
declare
  v_md5 text;
  v_autres text;
begin
  -- a) Étape d faite : list_eleves n'est plus exécutable par anon.
  if to_regprocedure('public.list_eleves()') is not null
     and has_function_privilege('anon', 'public.list_eleves()', 'EXECUTE') then
    raise exception 'Étape d non exécutée (anon peut encore exécuter list_eleves) : lancer d''abord l''étape d';
  end if;

  -- b) Les 3 fonctions réécrites sont identiques au dépôt (empreinte du corps, LF ou CRLF).
  select md5(prosrc) into v_md5 from pg_proc where oid = to_regprocedure('public._session_user(text,text)');
  if v_md5 is null or v_md5 not in ('c5f3dc2832f4859ccc2ed6300e7f02e0', '7c954077521978ce4f0e1948008eb87b') then
    raise exception '_session_user différente du dépôt (md5 %) : exporter sa définition avant de continuer', v_md5;
  end if;
  select md5(prosrc) into v_md5 from pg_proc where oid = to_regprocedure('public.password_reset_create(text,text,text)');
  if v_md5 is null or v_md5 not in ('5e2e2eb49c4b18205f8d7d8024675cb0', 'f2383113e4d9ac768f8fcdce8f1cd438') then
    raise exception 'password_reset_create différente du dépôt (md5 %) : exporter sa définition avant de continuer', v_md5;
  end if;
  select md5(prosrc) into v_md5 from pg_proc where oid = to_regprocedure('public.reset_password_with_token(text,text)');
  if v_md5 is null or v_md5 not in ('5643c80b5a7aab2a8db7af577e0be1a6', '40e45e5535a0a329b3069345268e2d53') then
    raise exception 'reset_password_with_token différente du dépôt (md5 %) : exporter sa définition avant de continuer', v_md5;
  end if;

  -- c) Aucune AUTRE fonction ne lit/écrit la table eleves (sinon elle casserait à l'étape f).
  select string_agg(p.oid::regprocedure::text, ', ') into v_autres
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prosrc ~* '(from|join|into|update|table)\s+(public\.)?eleves\M'
    and p.oid not in (
      to_regprocedure('public._session_user(text,text)')::oid,
      to_regprocedure('public.password_reset_create(text,text,text)')::oid,
      to_regprocedure('public.reset_password_with_token(text,text)')::oid,
      coalesce(to_regprocedure('public.eleve_session_open(text,text)')::oid, 0::oid),
      coalesce(to_regprocedure('public.eleve_save_riasec(text,jsonb)')::oid, 0::oid),
      coalesce(to_regprocedure('public.eleve_update_email(text,text)')::oid, 0::oid),
      coalesce(to_regprocedure('public.list_eleves()')::oid, 0::oid),
      coalesce(to_regprocedure('public.admin_set_eleve_banni_v2(text,text,boolean)')::oid, 0::oid)
    );
  if v_autres is not null then
    raise exception 'Fonctions imprévues qui utilisent la table eleves : % — me les envoyer avant de continuer', v_autres;
  end if;
end $$;

-- ------------------------------------------------------------
-- 1) Sessions et réinitialisations de rôle 'eleve'
-- ------------------------------------------------------------
DELETE FROM public.password_resets WHERE role = 'eleve';
DELETE FROM public.sessions WHERE role = 'eleve';

-- ------------------------------------------------------------
-- 2) _session_user : liste blanche des rôles, sans 'eleve'
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
  -- Rôles admis uniquement (le compte élève a été supprimé) : tout autre rôle est
  -- refusé d'emblée, même si une ligne sessions subsistait.
  if coalesce(p_token, '') = '' or p_role is null
     or p_role not in ('inspecteur', 'etablissement', 'admin') then
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

  if p_role = 'inspecteur' and not exists (
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

REVOKE EXECUTE ON FUNCTION public._session_user(text, text) FROM public, anon, authenticated;

-- ------------------------------------------------------------
-- 3) password_reset_create : rôles inspecteur et établissement seulement
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.password_reset_create(p_role text, p_email text, p_token_hash text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_account_id text;
  v_email text;
  v_recent integer;
begin
  if p_role is null or p_role not in ('inspecteur', 'etablissement') then
    return null;
  end if;
  if nullif(trim(p_email), '') is null then
    return null;
  end if;
  if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$' then
    return null;
  end if;

  if p_role = 'inspecteur' then
    select i.id, trim(i.email) into v_account_id, v_email
    from inspecteurs i
    where nullif(trim(i.email), '') is not null
      and lower(trim(i.email)) = lower(trim(p_email))
      and coalesce(i.banni, false) = false;
  else
    select et.id, trim(et.email) into v_account_id, v_email
    from etablissements et
    where nullif(trim(et.email), '') is not null
      and lower(trim(et.email)) = lower(trim(p_email));
  end if;

  if v_account_id is null then
    return null;
  end if;

  -- Sérialise les demandes simultanées pour un même compte, sinon deux
  -- appels parallèles pourraient dépasser la limite.
  perform pg_advisory_xact_lock(hashtext('password_reset:' || p_role || ':' || v_account_id));

  -- Ménage : la limite ne regarde que la dernière heure.
  delete from password_resets pr where pr.created_at < now() - interval '1 day';

  select count(*) into v_recent
  from password_resets pr
  where pr.role = p_role
    and pr.account_id = v_account_id
    and pr.created_at > now() - interval '1 hour';

  if v_recent >= 3 then
    return null;
  end if;

  -- Un seul lien valable à la fois : les précédents sont invalidés.
  update password_resets pr set used = true
  where pr.role = p_role
    and pr.account_id = v_account_id
    and pr.used = false;

  insert into password_resets(token_hash, role, account_id, expires_at)
  values (p_token_hash, p_role, v_account_id, now() + interval '1 hour');

  return v_email;
end; $function$;

REVOKE ALL ON FUNCTION public.password_reset_create(text, text, text) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.password_reset_create(text, text, text) TO service_role;

-- ------------------------------------------------------------
-- 4) reset_password_with_token : sans la branche 'eleve'
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reset_password_with_token(p_token text, p_new_password text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_row password_resets%rowtype;
  v_ok boolean;
begin
  if coalesce(p_token, '') = '' then
    return false;
  end if;
  if p_new_password is null or length(p_new_password) < 4 or p_new_password ~ '^\$2[aby]\$' then
    raise exception 'MOT_DE_PASSE_INVALIDE';
  end if;

  -- FOR UPDATE : deux utilisations simultanées du même lien ne peuvent
  -- pas réussir toutes les deux.
  select pr.* into v_row
  from password_resets pr
  where pr.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
    and pr.used = false
    and pr.expires_at > now()
  for update;

  if not found then
    return false;
  end if;

  if v_row.role = 'inspecteur' then
    update inspecteurs i set password = p_new_password where i.id = v_row.account_id;
  elsif v_row.role = 'etablissement' then
    update etablissements et set password = p_new_password where et.id = v_row.account_id;
  end if;
  v_ok := found;

  update password_resets pr set used = true
  where pr.role = v_row.role
    and pr.account_id = v_row.account_id
    and pr.used = false;

  update sessions s set revoked = true
  where s.role = v_row.role
    and s.user_id = v_row.account_id
    and s.revoked = false;

  return v_ok;
end; $function$;

REVOKE ALL ON FUNCTION public.reset_password_with_token(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.reset_password_with_token(text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 5) Suppression des fonctions élève (signatures exactes)
-- ------------------------------------------------------------
DROP FUNCTION public.eleve_session_open(text, text);
DROP FUNCTION public.eleve_save_riasec(text, jsonb);
DROP FUNCTION public.eleve_update_email(text, text);
DROP FUNCTION public.list_eleves();
DROP FUNCTION public.admin_set_eleve_banni_v2(text, text, boolean);

-- ------------------------------------------------------------
-- 6) Contraintes CHECK sur role, sans 'eleve'
-- ------------------------------------------------------------
DO $$
declare
  r record;
begin
  -- Toutes les contraintes CHECK de sessions / password_resets qui portent sur role
  -- (celle de sessions n'a pas de nom explicite à l'origine).
  for r in
    select con.conname, con.conrelid::regclass::text as tbl
    from pg_constraint con
    where con.contype = 'c'
      and con.conrelid in ('public.sessions'::regclass, 'public.password_resets'::regclass)
      and pg_get_constraintdef(con.oid) ~* '\mrole\M'
  loop
    execute format('ALTER TABLE %s DROP CONSTRAINT %I', r.tbl, r.conname);
  end loop;
end $$;

ALTER TABLE public.sessions
  ADD CONSTRAINT sessions_role_check CHECK (role IN ('inspecteur', 'etablissement', 'admin'));
ALTER TABLE public.password_resets
  ADD CONSTRAINT password_resets_role_check CHECK (role IN ('inspecteur', 'etablissement'));

-- ------------------------------------------------------------
-- 7) Garde-fou final (avant COMMIT)
-- ------------------------------------------------------------
DO $$
declare
  v_autres text;
begin
  select string_agg(p.oid::regprocedure::text, ', ') into v_autres
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and (p.prosrc ~* '(from|join|into|update|table)\s+(public\.)?eleves\M'
         or p.prosrc ~ '''eleve''')
    -- Audience 'eleve' des liens de formation : sans rapport avec le compte élève.
    and p.proname not like 'admin_upsert_lien_formation%';
  if v_autres is not null then
    raise exception 'Il reste des fonctions qui citent eleves ou le rôle ''eleve'' : %', v_autres;
  end if;
  if exists (select 1 from public.sessions where role = 'eleve')
     or exists (select 1 from public.password_resets where role = 'eleve') then
    raise exception 'Il reste des lignes de rôle eleve dans sessions ou password_resets';
  end if;
end $$;

COMMIT;

-- Contrôle : voir supabase-migration-2026-10-17-suppression-eleve-controle.sql, requête « APRÈS e ».
