-- ============================================================
-- ORIMETIER — Jetons de session, Phase 2a : élève (pilote).
--
-- Ajoute les nouvelles signatures « par jeton » de l'espace élève.
-- Les anciennes (eleve_login, eleve_save_riasec(p_id, p_password, …),
-- eleve_update_email(p_id, p_password, …)) RESTENT EN SERVICE pendant
-- la transition : leur suppression fera l'objet du fichier 2b, après
-- déploiement du frontend et tests.
--
--   eleve_session_open  : vérifie téléphone + mot de passe (logique crypt
--                         reprise du live eleve_login), refuse un compte
--                         banni, ouvre une session de 30 jours et renvoie
--                         le jeton (jamais stocké en base : seulement son
--                         empreinte sha256).
--   eleve_save_riasec   : (p_token, p_riasec) — identité via _session_user.
--   eleve_update_email  : (p_token, p_email) — refuse un e-mail déjà utilisé
--                         par un autre élève (insensible casse/espaces) :
--                         exception EMAIL_DEJA_UTILISE.
--
-- Écrit à partir de supabase/reference/live-2026-09-26.sql :
--   eleve_login        l. 554-563
--   eleve_save_riasec  l. 565-575
--   eleve_update_email l. 577-587
-- Seules les lignes d'authentification changent ; le reste est identique.
--
-- Pré-requis : Phase 1 exécutée (sessions, _session_user, session_check,
-- session_close).
--
-- PostgREST choisit la fonction d'après les NOMS d'arguments : les
-- nouvelles surcharges (p_token, …) ne se confondent pas avec les
-- anciennes (p_id, p_password, …).
--
-- À exécuter en une fois dans l'éditeur SQL de Supabase.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1) eleve_session_open : ouverture de session (publique)
-- ------------------------------------------------------------
-- null            : téléphone/mot de passe incorrects (ou vides).
-- {banni: true}   : identifiants corrects mais compte suspendu ; aucune
--                   session créée (le frontend affiche le message dédié,
--                   comme avec eleve_login qui renvoyait déjà banni).
-- {token, expires_at, id, nom, prenoms, classe, etablissement, tel,
--  riasec, active, date_inscription, banni} : session ouverte.
CREATE OR REPLACE FUNCTION public.eleve_session_open(p_tel text, p_password text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_eleve eleves%rowtype;
  v_token text;
  v_expires_at timestamptz;
begin
  if coalesce(p_tel, '') = '' or coalesce(p_password, '') = '' then
    return null;
  end if;

  -- Ménage : sessions expirées depuis plus de 7 jours (tous rôles).
  delete from sessions s where s.expires_at < now() - interval '7 days';

  -- Vérification identique au live eleve_login. "order by / limit 1" :
  -- eleve_login pouvait renvoyer plusieurs lignes (tel en double) et le
  -- frontend prenait la première ; les doublons sont traités en Phase 3.
  select e.* into v_eleve
  from eleves e
  where e.tel = p_tel and e.password = extensions.crypt(p_password, e.password)
  order by e.id
  limit 1;

  if not found then
    return null;
  end if;

  if coalesce(v_eleve.banni, false) then
    return jsonb_build_object('banni', true);
  end if;

  v_token := encode(extensions.gen_random_bytes(32), 'hex');

  insert into sessions(token_hash, role, user_id, expires_at)
  values (encode(extensions.digest(v_token, 'sha256'), 'hex'), 'eleve', v_eleve.id, now() + interval '30 days')
  returning expires_at into v_expires_at;

  return jsonb_build_object(
    'token', v_token,
    'expires_at', v_expires_at,
    'id', v_eleve.id,
    'nom', v_eleve.nom,
    'prenoms', v_eleve.prenoms,
    'classe', v_eleve.classe,
    'etablissement', v_eleve.etablissement,
    'tel', v_eleve.tel,
    'riasec', v_eleve.riasec,
    'active', v_eleve.active,
    'date_inscription', v_eleve.date_inscription,
    'banni', coalesce(v_eleve.banni, false)
  );
end; $function$;

REVOKE ALL ON FUNCTION public.eleve_session_open(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.eleve_session_open(text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 2) eleve_save_riasec(p_token, p_riasec)
-- ------------------------------------------------------------
-- Jeton invalide/expiré/révoqué ou élève banni : exception
-- SESSION_INVALIDE (P0401) levée par _session_user.
CREATE OR REPLACE FUNCTION public.eleve_save_riasec(p_token text, p_riasec jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id text;
begin
  v_id := _session_user(p_token, 'eleve');
  update eleves e set riasec = p_riasec where e.id = v_id;
  return found;
end; $function$;

REVOKE ALL ON FUNCTION public.eleve_save_riasec(text, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION public.eleve_save_riasec(text, jsonb) TO anon, authenticated;

-- ------------------------------------------------------------
-- 3) eleve_update_email(p_token, p_email)
-- ------------------------------------------------------------
-- Refuse un e-mail déjà porté par un AUTRE élève (comparaison
-- lower(trim(...))) : exception EMAIL_DEJA_UTILISE. La valeur est stockée
-- telle quelle, comme dans le live (le frontend fait déjà le trim).
-- La course entre deux requêtes simultanées sera fermée par l'index
-- unique de la Phase 3.
CREATE OR REPLACE FUNCTION public.eleve_update_email(p_token text, p_email text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id text;
begin
  v_id := _session_user(p_token, 'eleve');

  if nullif(trim(p_email), '') is not null and exists (
    select 1 from eleves e
    where e.id <> v_id
      and nullif(trim(e.email), '') is not null
      and lower(trim(e.email)) = lower(trim(p_email))
  ) then
    raise exception 'EMAIL_DEJA_UTILISE';
  end if;

  update eleves e set email = p_email where e.id = v_id;
  return found;
end; $function$;

REVOKE ALL ON FUNCTION public.eleve_update_email(text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.eleve_update_email(text, text) TO anon, authenticated;

COMMIT;

-- ============================================================
-- VÉRIFICATIONS (à lancer après exécution, une requête à la fois)
-- ============================================================
--
-- V1. Anciennes ET nouvelles signatures présentes (6 lignes attendues :
--     eleve_login, eleve_session_open, 2 × eleve_save_riasec, 2 × eleve_update_email)
-- select p.proname, pg_get_function_identity_arguments(p.oid) as args
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('eleve_login', 'eleve_session_open', 'eleve_save_riasec', 'eleve_update_email')
-- order by 1, 2;
--
-- V2. Droits d'exécution (anon = true, authenticated = true sur les 3)
-- select f,
--        has_function_privilege('anon', f, 'EXECUTE') as anon,
--        has_function_privilege('authenticated', f, 'EXECUTE') as authenticated
-- from unnest(array['public.eleve_session_open(text,text)',
--                   'public.eleve_save_riasec(text,jsonb)',
--                   'public.eleve_update_email(text,text)']) as f;
--
-- V3. SECURITY DEFINER + search_path (security_definer = true, config = {search_path=public})
-- select p.proname, pg_get_function_identity_arguments(p.oid) as args,
--        p.prosecdef as security_definer, p.proconfig as config
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname in ('eleve_session_open', 'eleve_save_riasec', 'eleve_update_email');
--
-- V4. Test fonctionnel SANS trace (tout est annulé par le ROLLBACK final).
--     Remplacer <TEL>, <MOT_DE_PASSE> par ceux d'un élève de test NON banni,
--     et <EMAIL_AUTRE_ELEVE> par l'e-mail d'un AUTRE élève, écrit en
--     MAJUSCULES avec des espaces autour. Sélectionner et exécuter le bloc
--     entier d'un coup ; chaque étape affiche son résultat via NOTICE
--     (onglet "Messages"/"Notices" de l'éditeur).
-- begin;
-- do $$
-- declare r jsonb; t text; ok boolean;
-- begin
--   r := public.eleve_session_open('<TEL>', 'mauvais-mot-de-passe');
--   raise notice '1. mauvais mot de passe -> % (attendu : null)', r;
--
--   r := public.eleve_session_open('<TEL>', '<MOT_DE_PASSE>');
--   t := r->>'token';
--   raise notice '2. bon mot de passe -> jeton de % caractères (attendu : 64), id = %', length(t), r->>'id';
--
--   ok := public.eleve_save_riasec(t, (select e.riasec from eleves e where e.id = r->>'id'));
--   raise notice '3. eleve_save_riasec (valeur inchangée) -> % (attendu : true)', ok;
--
--   begin
--     perform public.eleve_update_email(t, '<EMAIL_AUTRE_ELEVE>');
--     raise notice '4. e-mail déjà pris -> ACCEPTÉ (ANOMALIE)';
--   exception when others then
--     raise notice '4. e-mail déjà pris -> erreur "%" (attendu : EMAIL_DEJA_UTILISE)', sqlerrm;
--   end;
--
--   perform public.session_close(t);
--   begin
--     perform public.eleve_save_riasec(t, null);
--     raise notice '5. jeton fermé -> ACCEPTÉ (ANOMALIE)';
--   exception when sqlstate 'P0401' then
--     raise notice '5. jeton fermé -> SESSION_INVALIDE (attendu)';
--   end;
-- end $$;
-- rollback;
--
-- V5. Compte banni : remplacer par les identifiants d'un élève banni
--     (résultat attendu : {"banni": true}, et aucune ligne ajoutée dans sessions).
-- begin;
-- select public.eleve_session_open('<TEL_BANNI>', '<MOT_DE_PASSE_BANNI>');
-- rollback;
