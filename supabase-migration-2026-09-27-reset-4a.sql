-- ============================================================
-- ORIMETIER — Phase 4a : mot de passe oublié, socle SQL sécurisé.
--
-- La faille corrigée : request_password_reset renvoyait le jeton de
-- réinitialisation à l'appelant (le navigateur), et password_resets le
-- stockait en clair. Désormais :
--   - le jeton est généré par l'Edge Function request-password-reset
--     (Phase 4b), qui n'envoie à la base que son empreinte sha256 ;
--   - password_resets ne contient plus que token_hash ;
--   - la création d'un jeton n'est possible que via la service role key.
--
--   password_reset_create      : (p_role, p_email, p_token_hash) → e-mail
--                                du compte à qui envoyer le lien, ou null
--                                (compte introuvable/banni, limite atteinte).
--                                Réservée à service_role. Limite : 3 demandes
--                                par heure et par compte. Un seul jeton actif
--                                par compte (les précédents sont invalidés).
--   reset_password_with_token  : même signature que le live. Compare
--                                l'empreinte, invalide tous les jetons du
--                                compte, révoque toutes ses sessions.
--   request_password_reset     : supprimée.
--
-- Écrit à partir de supabase/reference/live-2026-09-26.sql :
--   request_password_reset     l. 1511-1539
--   reset_password_with_token  l. 1541-1566
--   hash_password_trigger      l. 896-909 (le trigger laisse passer tel
--                              quel un mot de passe qui ressemble déjà à
--                              un hash bcrypt : refusé ici)
--   trg_hash_password          l. 1578-1585 (eleves, inspecteurs,
--                              etablissements : hachage bcrypt automatique)
-- Modèle d'empreinte repris de la table sessions (Phase 1).
--
-- Pré-requis : Phase 1 (table sessions) et Phase 3 (index uniques sur
-- lower(trim(email))) exécutées.
--
-- Le script s'arrête sans rien modifier si un jeton de réinitialisation
-- est encore actif (il ne devrait y en avoir aucun : le flux est coupé
-- depuis le 2026-09-26 et les jetons expirent après 1 heure).
--
-- À exécuter en une fois dans l'éditeur SQL de Supabase.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 0) Garde-fou : aucun jeton encore utilisable
-- ------------------------------------------------------------
DO $$
begin
  if exists (select 1 from public.password_resets pr where pr.used = false and pr.expires_at > now()) then
    raise exception 'Jeton de réinitialisation encore actif dans password_resets : migration annulée.';
  end if;
end $$;

-- ------------------------------------------------------------
-- 1) Table password_resets : purge des jetons en clair, puis
--    passage au stockage de l'empreinte
-- ------------------------------------------------------------
DELETE FROM public.password_resets;

ALTER TABLE public.password_resets RENAME COLUMN token TO token_hash;

ALTER TABLE public.password_resets
  ALTER COLUMN token_hash SET NOT NULL,
  ALTER COLUMN role SET NOT NULL,
  ALTER COLUMN account_id SET NOT NULL,
  ALTER COLUMN expires_at SET NOT NULL,
  ALTER COLUMN used SET DEFAULT false,
  ALTER COLUMN used SET NOT NULL,
  ALTER COLUMN created_at SET DEFAULT now(),
  ALTER COLUMN created_at SET NOT NULL,
  ADD CONSTRAINT password_resets_token_hash_format CHECK (token_hash ~ '^[0-9a-f]{64}$'),
  ADD CONSTRAINT password_resets_role_check CHECK (role IN ('eleve', 'inspecteur', 'etablissement'));

CREATE UNIQUE INDEX password_resets_token_hash_key ON public.password_resets(token_hash);
-- Limite de fréquence et invalidation des jetons d'un compte.
CREATE INDEX password_resets_role_account_created_idx ON public.password_resets(role, account_id, created_at);

COMMENT ON TABLE public.password_resets IS 'Jetons de réinitialisation de mot de passe. Accès uniquement via fonctions SECURITY DEFINER ; jamais de GRANT à anon/authenticated, jamais dans la publication realtime';
COMMENT ON COLUMN public.password_resets.token_hash IS 'encode(extensions.digest(jeton, ''sha256''), ''hex'') — le jeton lui-même n''est jamais stocké';

ALTER TABLE public.password_resets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.password_resets FROM public, anon, authenticated;

-- ------------------------------------------------------------
-- 2) Suppression de l'ancienne fonction (renvoyait le jeton)
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS public.request_password_reset(text, text);

-- ------------------------------------------------------------
-- 3) password_reset_create : réservée à service_role
-- ------------------------------------------------------------
-- Appelée uniquement par l'Edge Function request-password-reset, qui
-- génère le jeton et ne transmet que son empreinte. Renvoie l'e-mail du
-- compte (destinataire du lien) ou null, sans distinguer les cas : l'Edge
-- Function répond de toute façon {ok:true} (anti-énumération).
-- Recherche insensible à la casse et aux espaces, alignée sur les index
-- uniques de la Phase 3 (un seul compte possible par rôle et par e-mail).
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
  if p_role is null or p_role not in ('eleve', 'inspecteur', 'etablissement') then
    return null;
  end if;
  if nullif(trim(p_email), '') is null then
    return null;
  end if;
  if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$' then
    return null;
  end if;

  if p_role = 'eleve' then
    select e.id, trim(e.email) into v_account_id, v_email
    from eleves e
    where nullif(trim(e.email), '') is not null
      and lower(trim(e.email)) = lower(trim(p_email))
      and coalesce(e.banni, false) = false;
  elsif p_role = 'inspecteur' then
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
-- 4) reset_password_with_token : publique (lien reçu par e-mail)
-- ------------------------------------------------------------
-- false : jeton inconnu, déjà utilisé, expiré, ou compte supprimé entre-temps.
-- Exception MOT_DE_PASSE_INVALIDE : moins de 4 caractères (même règle que
-- le frontend), ou valeur au format d'un hash bcrypt, que
-- hash_password_trigger stockerait telle quelle.
-- Succès : mot de passe changé (haché par trg_hash_password), tous les
-- jetons du compte invalidés, toutes ses sessions révoquées.
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

  if v_row.role = 'eleve' then
    update eleves e set password = p_new_password where e.id = v_row.account_id;
  elsif v_row.role = 'inspecteur' then
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

COMMIT;

-- ============================================================
-- VÉRIFICATIONS (à lancer après exécution, une requête à la fois)
-- ============================================================
--
-- V1. Colonnes de password_resets (token_hash présent, plus de colonne token ;
--     toutes NOT NULL ; used défaut false ; created_at défaut now())
-- select column_name, data_type, is_nullable, column_default
-- from information_schema.columns
-- where table_schema = 'public' and table_name = 'password_resets'
-- order by ordinal_position;
--
-- V2. Contraintes et index (format, rôle, token_hash_key, role_account_created_idx)
-- select conname, pg_get_constraintdef(oid) from pg_constraint
-- where conrelid = 'public.password_resets'::regclass;
-- select indexname, indexdef from pg_indexes
-- where schemaname = 'public' and tablename = 'password_resets';
--
-- V3. Table fermée : RLS activée (true), aucun droit pour anon/authenticated/PUBLIC
--     (0 ligne), absente de la publication realtime (0 ligne)
-- select relrowsecurity from pg_class where oid = 'public.password_resets'::regclass;
-- select grantee, privilege_type from information_schema.role_table_grants
-- where table_schema = 'public' and table_name = 'password_resets'
--   and grantee in ('anon', 'authenticated', 'PUBLIC');
-- select * from pg_publication_tables where tablename = 'password_resets';
--
-- V4. Fonctions : request_password_reset absente ; password_reset_create
--     SEULEMENT service_role ; reset_password_with_token anon + authenticated
--     Attendu :
--       password_reset_create     anon=false authenticated=false service_role=true
--       reset_password_with_token anon=true  authenticated=true  service_role=true
-- select p.proname, pg_get_function_identity_arguments(p.oid) as args
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('request_password_reset', 'password_reset_create', 'reset_password_with_token');
-- select f,
--        has_function_privilege('anon', f, 'EXECUTE') as anon,
--        has_function_privilege('authenticated', f, 'EXECUTE') as authenticated,
--        has_function_privilege('service_role', f, 'EXECUTE') as service_role
-- from unnest(array['public.password_reset_create(text,text,text)',
--                   'public.reset_password_with_token(text,text)']) as f;
--
-- V5. La clé publique ne peut ni lire la table ni créer de jeton
--     (attendu : deux erreurs "permission denied")
-- begin; set local role anon; select * from public.password_resets; rollback;
-- begin; set local role anon; select public.password_reset_create('eleve', 'x@x.x', repeat('a', 64)); rollback;
--
-- V6. Test fonctionnel SANS trace (tout est annulé par le ROLLBACK final).
--     Remplacer <EMAIL_ELEVE> par l'e-mail d'un élève de test NON banni,
--     écrit en MAJUSCULES avec des espaces autour (teste la normalisation).
--     Sélectionner et exécuter le bloc entier d'un coup ; résultats dans
--     l'onglet "Messages"/"Notices".
-- begin;
-- do $$
-- declare
--   t text; h text; r text; ok boolean; n integer; v_id text;
-- begin
--   r := public.password_reset_create('eleve', 'inconnu-' || md5(random()::text) || '@exemple.invalid', repeat('a', 64));
--   raise notice '1. e-mail inconnu -> % (attendu : null)', r;
--
--   t := encode(extensions.gen_random_bytes(32), 'hex');
--   h := encode(extensions.digest(t, 'sha256'), 'hex');
--   r := public.password_reset_create('eleve', '<EMAIL_ELEVE>', h);
--   raise notice '2. demande valide -> % (attendu : l''e-mail de l''élève)', r;
--   select pr.account_id into v_id from password_resets pr where pr.token_hash = h;
--
--   insert into sessions(token_hash, role, user_id, expires_at)
--   values (encode(extensions.digest('jeton-de-test-4a', 'sha256'), 'hex'), 'eleve', v_id, now() + interval '1 day');
--
--   ok := public.reset_password_with_token(repeat('0', 64), 'nouveau-mdp-test');
--   raise notice '3. mauvais jeton -> % (attendu : false)', ok;
--
--   begin
--     perform public.reset_password_with_token(t, '$2a$10$abcdefghijklmnopqrstuv');
--     raise notice '4. mot de passe au format bcrypt -> ACCEPTÉ (ANOMALIE)';
--   exception when others then
--     raise notice '4. mot de passe au format bcrypt -> erreur "%" (attendu : MOT_DE_PASSE_INVALIDE)', sqlerrm;
--   end;
--
--   ok := public.reset_password_with_token(t, 'nouveau-mdp-test');
--   raise notice '5. bon jeton -> % (attendu : true)', ok;
--
--   select count(*) into n from eleves e
--   where e.id = v_id and e.password = extensions.crypt('nouveau-mdp-test', e.password);
--   raise notice '6. nouveau mot de passe haché et reconnu -> % (attendu : 1)', n;
--
--   select count(*) into n from sessions s where s.role = 'eleve' and s.user_id = v_id and s.revoked = false;
--   raise notice '7. sessions encore actives -> % (attendu : 0)', n;
--
--   ok := public.reset_password_with_token(t, 'autre-mdp-test');
--   raise notice '8. jeton réutilisé -> % (attendu : false)', ok;
--
--   -- 1 demande déjà faite à l'étape 2 : la 2e et la 3e passent, la 4e est refusée.
--   r := public.password_reset_create('eleve', '<EMAIL_ELEVE>', encode(extensions.digest('t2', 'sha256'), 'hex'));
--   raise notice '9. 2e demande dans l''heure -> % (attendu : l''e-mail)', r;
--   r := public.password_reset_create('eleve', '<EMAIL_ELEVE>', encode(extensions.digest('t3', 'sha256'), 'hex'));
--   raise notice '10. 3e demande dans l''heure -> % (attendu : l''e-mail)', r;
--   r := public.password_reset_create('eleve', '<EMAIL_ELEVE>', encode(extensions.digest('t4', 'sha256'), 'hex'));
--   raise notice '11. 4e demande dans l''heure -> % (attendu : null)', r;
--
--   select count(*) into n from password_resets pr
--   where pr.role = 'eleve' and pr.account_id = v_id and pr.used = false;
--   raise notice '12. jetons actifs pour ce compte -> % (attendu : 1, le dernier accepté)', n;
-- end $$;
-- rollback;
