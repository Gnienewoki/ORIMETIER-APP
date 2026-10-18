-- ============================================================
-- ORIMETIER — Inscription inspecteur durcie : FICHIER A, MIGRATION ADDITIVE.
--
-- ORDRE : 0 (test à blanc) -> A (ce fichier) -> contrôle « après A » -> déploiement du front
-- (supabase-client.js + sw.js v35) -> B -> contrôle « après B ». Fichier À LANCER EN ENTIER.
-- PAS DE BEGIN / COMMIT : un bloc DO, atomique à lui seul (validé s'il va au bout, annulé
-- entièrement à la moindre exception), puis une requête de vérification.
--
-- CE QUE A INSTALLE (et rien d'autre) :
--   public.inspecteur_register(p_id, p_nom, p_prenoms, p_fonction, p_cio, p_tel, p_email,
--   p_password, p_date_inscription) -> jsonb, SECURITY DEFINER, search_path public.
--   Convention de etablissement_claim_v2 : ne lève pas d'erreur métier, renvoie
--     {ok:true, id}
--     ou {ok:false, erreur: CHAMPS_OBLIGATOIRES | CHAMP_TROP_LONG (+ champ) | MOT_DE_PASSE_INVALIDE
--                          | TEL_DEJA_UTILISE | EMAIL_DEJA_UTILISE | ID_DEJA_UTILISE}.
--   Colonnes imposées par la fonction (jamais par le client) : active = true (valeur envoyée
--   aujourd'hui par le front), certifie = false, banni = false, certification_demandee = false.
--   Mot de passe transmis EN CLAIR à l'INSERT : trg_hash_password le hache (bcrypt). Un mot de
--   passe qui ressemble déjà à un hash bcrypt (^\$2[aby]\$) est refusé, sinon le trigger le
--   stockerait tel quel.
--   EXECUTE : anon et authenticated seulement (retiré à PUBLIC).
--
-- CE QUE A NE FAIT PAS : le droit INSERT direct de anon / authenticated sur inspecteurs et la
-- policy « insertion inscription inspecteur » restent en place (retirés par B, après le
-- déploiement du front). L'ancien front continue donc de fonctionner tel quel.
-- messages_inspecteurs : non touché.
--
-- Relançable : CREATE OR REPLACE (même signature, même corps).
-- ============================================================

DO $migration$
declare
  v_sql text;
begin
  -- ================= GARDES : arrêt sans rien modifier si la base n'est pas dans l'état attendu
  if to_regclass('public.inspecteurs') is null then
    raise exception 'GARDE : table public.inspecteurs absente : rien n''est modifié.';
  end if;
  if to_regclass('public.inspecteurs_tel_unique') is null or to_regclass('public.inspecteurs_email_unique') is null then
    raise exception 'GARDE : index unique inspecteurs_tel_unique ou inspecteurs_email_unique absent (la fonction reconnaît les doublons par ces noms) : rien n''est modifié.';
  end if;
  if not exists (select 1 from pg_trigger t
                 where t.tgrelid = 'public.inspecteurs'::regclass and t.tgname = 'trg_hash_password' and not t.tgisinternal) then
    raise exception 'GARDE : trigger trg_hash_password absent sur inspecteurs (le mot de passe serait stocké en clair) : rien n''est modifié.';
  end if;
  if to_regprocedure('public.hash_password_trigger()') is null then
    raise exception 'GARDE : fonction hash_password_trigger() absente : rien n''est modifié.';
  end if;
  if (select count(*) from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = 'inspecteurs'
        and c.column_name in ('id', 'nom', 'prenoms', 'fonction', 'cio', 'tel', 'email', 'password', 'date_inscription',
                              'active', 'banni', 'certifie', 'certification_demandee')) <> 13 then
    raise exception 'GARDE : une des 13 colonnes attendues manque dans inspecteurs : rien n''est modifié.';
  end if;

  -- ================= INSTALLATION
  foreach v_sql in array array[

$ddl$CREATE OR REPLACE FUNCTION public.inspecteur_register(p_id text, p_nom text, p_prenoms text, p_fonction text, p_cio text, p_tel text, p_email text, p_password text, p_date_inscription text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_tel text;
  v_tel_norm text;
  v_email text;
  v_champ text;
  v_contrainte text;
begin
  -- Champs obligatoires : les mêmes que le front (nom, téléphone, mot de passe) + l'id généré
  if coalesce(trim(p_id), '') = '' or coalesce(trim(p_nom), '') = ''
     or coalesce(trim(p_tel), '') = '' or coalesce(p_password, '') = '' then
    return jsonb_build_object('ok', false, 'erreur', 'CHAMPS_OBLIGATOIRES');
  end if;

  v_champ := case
    when length(trim(p_id)) > 64                                then 'id'
    when length(trim(p_nom)) > 100                              then 'nom'
    when length(coalesce(trim(p_prenoms), '')) > 100            then 'prenoms'
    when length(coalesce(trim(p_fonction), '')) > 150           then 'fonction'
    when length(coalesce(trim(p_cio), '')) > 150                then 'cio'
    when length(trim(p_tel)) > 30                               then 'tel'
    when length(coalesce(trim(p_email), '')) > 254              then 'email'
    when length(p_password) > 128                               then 'password'
    when length(coalesce(trim(p_date_inscription), '')) > 20    then 'date_inscription'
  end;
  if v_champ is not null then
    return jsonb_build_object('ok', false, 'erreur', 'CHAMP_TROP_LONG', 'champ', v_champ);
  end if;

  -- Même règle que reset_password_with_token : un hash bcrypt ne serait pas re-haché par le trigger
  if p_password ~ '^\$2[aby]\$' then
    return jsonb_build_object('ok', false, 'erreur', 'MOT_DE_PASSE_INVALIDE');
  end if;

  v_tel := trim(p_tel);
  v_email := coalesce(trim(p_email), '');
  -- Même normalisation que normalizeTel (utils.js) : rattrape les anciens comptes saisis avec
  -- espaces, points, tirets ou indicatif +225 / 00225
  v_tel_norm := regexp_replace(regexp_replace(v_tel, '[[:space:].-]', '', 'g'), '^(\+|00)225', '');

  if exists (select 1 from inspecteurs i
             where i.tel = v_tel
                or regexp_replace(regexp_replace(trim(i.tel), '[[:space:].-]', '', 'g'), '^(\+|00)225', '') = v_tel_norm) then
    return jsonb_build_object('ok', false, 'erreur', 'TEL_DEJA_UTILISE');
  end if;
  if v_email <> '' and exists (select 1 from inspecteurs i where lower(trim(i.email)) = lower(v_email)) then
    return jsonb_build_object('ok', false, 'erreur', 'EMAIL_DEJA_UTILISE');
  end if;

  begin
    insert into inspecteurs (id, nom, prenoms, fonction, cio, tel, email, password, date_inscription,
                             active, banni, certifie, certification_demandee)
    values (trim(p_id), trim(p_nom), coalesce(trim(p_prenoms), ''), coalesce(trim(p_fonction), ''),
            coalesce(trim(p_cio), ''), v_tel, v_email,
            p_password,   -- en clair : haché par trg_hash_password (BEFORE INSERT)
            coalesce(nullif(trim(p_date_inscription), ''), to_char(current_date, 'DD/MM/YYYY')),
            true, false, false, false);
  exception when unique_violation then
    -- Deux inscriptions simultanées : l'index unique tranche
    get stacked diagnostics v_contrainte = constraint_name;
    if v_contrainte = 'inspecteurs_tel_unique' then
      return jsonb_build_object('ok', false, 'erreur', 'TEL_DEJA_UTILISE');
    elsif v_contrainte = 'inspecteurs_email_unique' then
      return jsonb_build_object('ok', false, 'erreur', 'EMAIL_DEJA_UTILISE');
    elsif v_contrainte like '%pkey' then
      return jsonb_build_object('ok', false, 'erreur', 'ID_DEJA_UTILISE');
    end if;
    raise;
  end;

  return jsonb_build_object('ok', true, 'id', trim(p_id));
end; $function$$ddl$,
$ddl$COMMENT ON FUNCTION public.inspecteur_register(text, text, text, text, text, text, text, text, text) IS 'Inscription publique d''un inspecteur. Impose active = true, certifie / banni / certification_demandee = false. Renvoie {ok:true, id} ou {ok:false, erreur}. Mot de passe haché par trg_hash_password.'$ddl$,
$ddl$REVOKE ALL ON FUNCTION public.inspecteur_register(text, text, text, text, text, text, text, text, text) FROM PUBLIC, anon, authenticated$ddl$,
$ddl$GRANT EXECUTE ON FUNCTION public.inspecteur_register(text, text, text, text, text, text, text, text, text) TO anon, authenticated$ddl$

  ] loop
    execute v_sql;
  end loop;

  raise notice 'A installée : inspecteur_register prête. Droit INSERT direct et policy d''inscription toujours en place (retirés par B).';
end;
$migration$;

-- Vérification (attendu : 1 ligne, toutes les colonnes à true)
select
  to_regprocedure('public.inspecteur_register(text,text,text,text,text,text,text,text,text)') is not null as fonction_presente,
  (select p.prosecdef from pg_proc p where p.oid = to_regprocedure('public.inspecteur_register(text,text,text,text,text,text,text,text,text)')) as security_definer,
  (select coalesce('search_path=public' = any(p.proconfig), false) from pg_proc p
     where p.oid = to_regprocedure('public.inspecteur_register(text,text,text,text,text,text,text,text,text)')) as search_path_public,
  has_function_privilege('anon', 'public.inspecteur_register(text,text,text,text,text,text,text,text,text)', 'EXECUTE') as execute_anon,
  has_function_privilege('authenticated', 'public.inspecteur_register(text,text,text,text,text,text,text,text,text)', 'EXECUTE') as execute_authenticated;
