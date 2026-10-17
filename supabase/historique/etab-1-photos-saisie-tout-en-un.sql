-- ============================================================
-- ORIMETIER — Circuit des établissements, étape 1 : saisie des photos ouverte
-- à TOUS les établissements (Premium ou non). FICHIER TOUT-EN-UN.
--
-- À coller et lancer UNE SEULE FOIS dans le SQL Editor de Supabase. Il enchaîne :
--   1) la migration (BEGIN ... COMMIT) ;
--   2) le test fonctionnel complet (BEGIN ... DO ... ROLLBACK : aucune trace) ;
--   3) une requête finale (n, controle, ok) : TOUTES les lignes doivent valoir true.
-- Si une étape du test échoue, l'exécution s'arrête sur "ÉCHEC ..." et la requête
-- finale n'est pas affichée. La migration (partie 1) reste alors en place : elle est
-- rejouable (CREATE OR REPLACE), le fichier peut être relancé tel quel après correction.
--
-- Pré-requis : 6a-1 (etablissement_session_open, trigger
-- trg_etablissements_revoke_sessions) et 6a-2 (etablissement_update_photos_v2)
-- exécutées.
--
-- Source : corps de PRODUCTION de etablissement_update_photos_v2, tel qu'installé
-- par 6a-2-etablissement-rpc-v2.sql (exécutée en prod le 02/10/2026). Le CSV prod
-- du 02/10 (prod-etablissement-fonctions-2026-10-02.csv) est antérieur à la 6a-2 et
-- ne contient que l'ancienne etablissement_update_photos(p_etab_id, p_password, ...).
--
-- Fonction réécrite (même signature, même type de retour) :
--   etablissement_update_photos_v2(p_token text, p_photos jsonb) -> boolean
--
-- DIFFÉRENCES AVEC LA PRODUCTION (et seulement celles-ci) :
--   1. Le test "if not coalesce(v_etab.premium, false) then return false;" est
--      RETIRÉ : un établissement non Premium peut enregistrer ses photos.
--   2. Une liste vide (ou NULL) enregistre '[]'::jsonb au lieu de NULL
--      (jsonb_agg sur zéro ligne renvoie NULL : coalesce ajouté).
--   Le reste est identique : _session_user(p_token, 'etablissement') EN PREMIER
--   (P0401 si jeton inconnu, expiré, révoqué ou d'un autre rôle), "return false"
--   si la fiche n'existe plus, limite de 10 photos (les suivantes sont ignorées),
--   SECURITY DEFINER, SET search_path TO 'public', REVOKE ALL FROM public, GRANT
--   EXECUTE TO anon, authenticated.
--
-- NON MODIFIÉS (volontairement) :
--   - etablissement_update_photos (ancienne, par mot de passe) : garde son test
--     Premium ; elle n'est plus appelée par le front et sera supprimée en 6c.
--   - list_etablissements : le masquage PUBLIC reste intact (photos -> '[]' et
--     logo_url -> NULL tant que la fiche n'est pas Premium). Le test le vérifie.
--   - etablissement_update_logo_v2 : n'a jamais eu de test Premium côté SQL.
-- ============================================================


-- ############################################################
-- PARTIE 1 : MIGRATION
-- ############################################################

BEGIN;

-- 0) Garde-fous : 6a-1 et 6a-2 exécutées
DO $$
begin
  if to_regprocedure('public._session_user(text,text)') is null then
    raise exception '_session_user absente : exécuter d''abord la Phase 1';
  end if;
  if to_regprocedure('public.etablissement_session_open(text,text)') is null then
    raise exception 'etablissement_session_open absente : exécuter d''abord la migration 6a-1';
  end if;
  if to_regprocedure('public.etablissement_update_photos_v2(text,jsonb)') is null then
    raise exception 'etablissement_update_photos_v2 absente : exécuter d''abord la migration 6a-2';
  end if;
end $$;

-- ------------------------------------------------------------
-- 1) etablissement_update_photos_v2 (sans test Premium, liste vide -> '[]')
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.etablissement_update_photos_v2(p_token text, p_photos jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_etab record; v_etab_id text;
begin
  v_etab_id := _session_user(p_token, 'etablissement');
  select * into v_etab from etablissements where id = v_etab_id;
  if not found then return false; end if;

  update etablissements
    set photos = coalesce((select jsonb_agg(v) from (select v from jsonb_array_elements(p_photos) v limit 10) s), '[]'::jsonb)
    where id = v_etab_id;
  return true;
end; $function$;

REVOKE ALL ON FUNCTION public.etablissement_update_photos_v2(text, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION public.etablissement_update_photos_v2(text, jsonb) TO anon, authenticated;

COMMIT;


-- ############################################################
-- PARTIE 2 : TEST FONCTIONNEL COMPLET (ROLLBACK : aucune trace)
-- ############################################################
-- Fiches créées dans la transaction (mots de passe hachés par trg_hash_password) :
--   test_etab12_np : NON Premium, logo + 0 photo, e-mail np-etab12@exemple.invalid, mdp-np-etab12
--   test_etab12_p  : Premium,     logo + 1 photo, e-mail p-etab12@exemple.invalid,  mdp-p-etab12
--   test_etab12_x  : NON Premium, 1 photo (témoin, ne doit jamais changer), sans session
-- Règle suivie : un appel de fonction et la lecture de table qui le contrôle sont
-- toujours deux instructions séparées ; comparaisons en IS DISTINCT FROM.

BEGIN;

insert into public.etablissements(
  id, nom, region, ville, quartier, type, responsable, tel, email, password,
  statut, active, date_inscription, filieres_proposees, photos, logo_url,
  categorie, sous_categorie, secteur, pre_inscrit, reclame, code_recuperation, premium
) values
  ('test_etab12_np', 'Etablissement test etab12 NP', 'Lagunes', 'Abidjan', null, 'Secondaire générale', null, null,
   'np-etab12@exemple.invalid', 'mdp-np-etab12',
   'valide', true, '04/10/2026', '[]'::jsonb, '[]'::jsonb, 'https://exemple.invalid/logo-np.png',
   'general', 'secondaire', 'prive', false, true, null, false),
  ('test_etab12_p', 'Etablissement test etab12 P', 'Lagunes', 'Abidjan', null, 'Secondaire générale', null, null,
   'p-etab12@exemple.invalid', 'mdp-p-etab12',
   'valide', true, '04/10/2026', '[]'::jsonb, '["https://exemple.invalid/p1.png"]'::jsonb, 'https://exemple.invalid/logo-p.png',
   'general', 'secondaire', 'prive', false, true, null, true),
  ('test_etab12_x', 'Etablissement test etab12 X', 'Lagunes', 'Abidjan', null, 'Secondaire générale', null, null,
   'x-etab12@exemple.invalid', 'mdp-x-etab12',
   'valide', true, '04/10/2026', '[]'::jsonb, '["https://exemple.invalid/x1.png"]'::jsonb, null,
   'general', 'secondaire', 'prive', false, true, null, false);

-- Session d'un AUTRE rôle (élève), insérée directement : _session_user filtre
-- sur le rôle avant toute chose, l'élève n'a pas besoin d'exister.
insert into public.sessions(token_hash, role, user_id, expires_at)
values (encode(extensions.digest('jeton-eleve-test-etab12', 'sha256'), 'hex'), 'eleve', 'test_etab12_eleve', now() + interval '1 day');

DO $$
declare
  r jsonb;
  tNP text; tP text; tNP2 text;
  t_inconnu text := 'jeton-inconnu-test-etab12';
  t_eleve text := 'jeton-eleve-test-etab12';
  v_tok text; v_state text;
  v_douze jsonb;
  v_j jsonb; v_txt text; v_n integer;
  ok boolean;
begin
  -- 0. Sessions
  r := public.etablissement_session_open('np-etab12@exemple.invalid', 'mdp-np-etab12');
  tNP := r->>'token';
  r := public.etablissement_session_open('p-etab12@exemple.invalid', 'mdp-p-etab12');
  tP := r->>'token';
  if tNP is null or tP is null then raise exception 'ÉCHEC 0 ouverture des sessions de test'; end if;
  raise notice '0. sessions NP (non Premium) et P (Premium) ouvertes';

  -- 1. Fiche NON Premium : 12 photos envoyées -> true, 10 stockées dans l'ordre
  select jsonb_agg('https://exemple.invalid/np' || lpad(i::text, 2, '0') || '.png' order by i)
    into v_douze from generate_series(1, 12) i;
  ok := public.etablissement_update_photos_v2(tNP, v_douze);
  if ok is not true then raise exception 'ÉCHEC 1 fiche non Premium : update_photos_v2 a renvoyé %', ok; end if;
  select e.photos into v_j from public.etablissements e where e.id = 'test_etab12_np';
  if jsonb_typeof(v_j) is distinct from 'array' or jsonb_array_length(v_j) is distinct from 10 then
    raise exception 'ÉCHEC 1 % photo(s) stockée(s), 10 attendues : %', jsonb_array_length(v_j), v_j;
  end if;
  if (v_j->>0) is distinct from 'https://exemple.invalid/np01.png' or (v_j->>9) is distinct from 'https://exemple.invalid/np10.png' then
    raise exception 'ÉCHEC 1 ordre ou contenu des photos : %', v_j;
  end if;
  raise notice '1. fiche NON Premium : 12 photos envoyées, 10 stockées (np01..np10)';

  -- 2. Liste vide et NULL -> '[]' (jamais NULL)
  ok := public.etablissement_update_photos_v2(tNP, '[]'::jsonb);
  if ok is not true then raise exception 'ÉCHEC 2 liste vide : update_photos_v2 a renvoyé %', ok; end if;
  select e.photos into v_j from public.etablissements e where e.id = 'test_etab12_np';
  if v_j is distinct from '[]'::jsonb then raise exception 'ÉCHEC 2 liste vide stockée : % (attendu [])', coalesce(v_j::text, 'NULL'); end if;
  ok := public.etablissement_update_photos_v2(tNP, null);
  if ok is not true then raise exception 'ÉCHEC 2 liste NULL : update_photos_v2 a renvoyé %', ok; end if;
  select e.photos into v_j from public.etablissements e where e.id = 'test_etab12_np';
  if v_j is distinct from '[]'::jsonb then raise exception 'ÉCHEC 2 liste NULL stockée : % (attendu [])', coalesce(v_j::text, 'NULL'); end if;
  raise notice '2. liste vide et NULL -> [] (jamais NULL)';

  -- 3. Fiche Premium : toujours autorisée (non-régression)
  ok := public.etablissement_update_photos_v2(tP, '["https://exemple.invalid/p1.png","https://exemple.invalid/p2.png"]'::jsonb);
  if ok is not true then raise exception 'ÉCHEC 3 fiche Premium : update_photos_v2 a renvoyé %', ok; end if;
  select e.photos into v_j from public.etablissements e where e.id = 'test_etab12_p';
  if v_j is distinct from '["https://exemple.invalid/p1.png","https://exemple.invalid/p2.png"]'::jsonb then
    raise exception 'ÉCHEC 3 photos Premium stockées : %', v_j;
  end if;
  raise notice '3. fiche Premium : 2 photos enregistrées';

  -- 4. Jeton inconnu, d'un autre rôle, révoqué : P0401, aucune écriture
  ok := public.etablissement_update_photos_v2(tNP, '["https://exemple.invalid/np-ref.png"]'::jsonb);
  if ok is not true then raise exception 'ÉCHEC 4 préparation : update_photos_v2 a renvoyé %', ok; end if;
  r := public.etablissement_session_open('np-etab12@exemple.invalid', 'mdp-np-etab12');
  tNP2 := r->>'token';
  if tNP2 is null then raise exception 'ÉCHEC 4 ouverture de la 2e session NP'; end if;
  ok := public.session_close(tNP2);
  if ok is not true then raise exception 'ÉCHEC 4 session_close a renvoyé %', ok; end if;
  foreach v_tok in array array[t_inconnu, t_eleve, tNP2] loop
    v_state := null;
    begin
      perform public.etablissement_update_photos_v2(v_tok, '["https://exemple.invalid/intrus.png"]'::jsonb);
    exception when others then v_state := sqlstate;
    end;
    if v_state is distinct from 'P0401' then
      raise exception 'ÉCHEC 4 % au lieu de P0401 pour le jeton %', coalesce(v_state, 'aucune erreur'), left(v_tok, 12) || '…';
    end if;
  end loop;
  select e.photos into v_j from public.etablissements e where e.id = 'test_etab12_np';
  if v_j is distinct from '["https://exemple.invalid/np-ref.png"]'::jsonb then
    raise exception 'ÉCHEC 4 photos NP modifiées par un jeton refusé : %', v_j;
  end if;
  select count(*) into v_n from public.etablissements e where e.photos::text like '%intrus%';
  if v_n is distinct from 0 then raise exception 'ÉCHEC 4 % fiche(s) contiennent la photo intruse', v_n; end if;
  raise notice '4. jeton inconnu / d''un autre rôle / révoqué : P0401, aucune écriture';

  -- 5. La fiche d'un autre établissement (témoin X) est inchangée
  select to_jsonb(e) - 'password' into v_j from public.etablissements e where e.id = 'test_etab12_x';
  if (v_j->'photos') is distinct from '["https://exemple.invalid/x1.png"]'::jsonb
     or (v_j->>'logo_url') is not null
     or (v_j->>'nom') is distinct from 'Etablissement test etab12 X' then
    raise exception 'ÉCHEC 5 fiche témoin X modifiée : %', v_j;
  end if;
  raise notice '5. fiche témoin X inchangée';

  -- 6. Masquage PUBLIC intact (list_etablissements)
  ok := public.etablissement_update_photos_v2(tNP, '["https://exemple.invalid/np-a.png","https://exemple.invalid/np-b.png"]'::jsonb);
  if ok is not true then raise exception 'ÉCHEC 6 préparation : update_photos_v2 a renvoyé %', ok; end if;
  select to_jsonb(l) into v_j from public.list_etablissements() l where l.id = 'test_etab12_np';
  if v_j is null then raise exception 'ÉCHEC 6 fiche NP absente de list_etablissements'; end if;
  if (v_j->'photos') is distinct from '[]'::jsonb then raise exception 'ÉCHEC 6 photos NON Premium visibles publiquement : %', v_j->'photos'; end if;
  if jsonb_typeof(v_j->'logo_url') is distinct from 'null' then raise exception 'ÉCHEC 6 logo NON Premium visible publiquement : %', v_j->'logo_url'; end if;
  select to_jsonb(l) into v_j from public.list_etablissements() l where l.id = 'test_etab12_p';
  if v_j is null then raise exception 'ÉCHEC 6 fiche P absente de list_etablissements'; end if;
  if (v_j->'photos') is distinct from '["https://exemple.invalid/p1.png","https://exemple.invalid/p2.png"]'::jsonb then
    raise exception 'ÉCHEC 6 photos Premium non visibles : %', v_j->'photos';
  end if;
  if (v_j->>'logo_url') is distinct from 'https://exemple.invalid/logo-p.png' then raise exception 'ÉCHEC 6 logo Premium non visible : %', v_j->>'logo_url'; end if;
  -- Les données NP restent bien enregistrées (seul l'affichage public est masqué)
  select e.photos, e.logo_url into v_j, v_txt from public.etablissements e where e.id = 'test_etab12_np';
  if jsonb_array_length(v_j) is distinct from 2 or v_txt is distinct from 'https://exemple.invalid/logo-np.png' then
    raise exception 'ÉCHEC 6 données NP stockées : photos %, logo %', v_j, v_txt;
  end if;
  raise notice '6. list_etablissements : photos et logo masqués pour NP, visibles pour P ; données NP bien stockées';
end $$;

ROLLBACK;


-- ############################################################
-- PARTIE 3 : CONTRÔLE FINAL (une seule requête, toutes les lignes = true)
-- On n'arrive ici que si le test de la partie 2 a réussi.
-- ############################################################
with v2 as (
  select p.oid, p.proname, p.prosecdef, p.proconfig, p.prosrc, p.proacl,
         pg_get_function_identity_arguments(p.oid) as args,
         pg_get_function_result(p.oid) as res
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'etablissement_update_photos_v2'
),
ancienne as (
  select p.prosrc
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'etablissement_update_photos'
),
liste as (
  select p.prosrc
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'list_etablissements'
)
select n, controle, ok from (
  select 1 as n, 'etablissement_update_photos_v2(p_token text, p_photos jsonb) -> boolean, une seule signature' as controle,
         (select count(*) = 1 and bool_and(args = 'p_token text, p_photos jsonb' and res = 'boolean') from v2) as ok
  union all select 2, 'SECURITY DEFINER',
         (select bool_and(prosecdef) from v2)
  union all select 3, 'SET search_path TO public',
         (select bool_and(proconfig @> array['search_path=public']) from v2)
  union all select 4, 'exécutable par anon et authenticated',
         (select bool_and(has_function_privilege('anon', oid, 'EXECUTE')
                      and has_function_privilege('authenticated', oid, 'EXECUTE')) from v2)
  union all select 5, 'aucun droit EXECUTE pour PUBLIC (REVOKE ALL)',
         (select bool_and(proacl is not null
                      and not exists (select 1 from aclexplode(proacl) a where a.grantee = 0)) from v2)
  union all select 6, '_session_user(p_token, ''etablissement'') appelée en premier',
         (select bool_and(prosrc ~ '^\s*declare[^;]*;[^;]*;\s*begin\s*v_etab_id := _session_user\(p_token, ''etablissement''\);') from v2)
  union all select 7, 'plus aucun test Premium dans la _v2',
         (select bool_and(prosrc not ilike '%premium%') from v2)
  union all select 8, 'limite de 10 photos conservée',
         (select bool_and(prosrc like '%limit 10%') from v2)
  union all select 9, 'liste vide -> ''[]''::jsonb (coalesce)',
         (select bool_and(prosrc like '%coalesce((select jsonb_agg(v)%''[]''::jsonb)%') from v2)
  union all select 10, 'n''utilise ni crypt ni p_password',
         (select bool_and(prosrc not like '%crypt%' and args !~ 'p_password') from v2)
  union all select 11, 'ancienne etablissement_update_photos intacte (test Premium toujours là)',
         (select count(*) = 1 and bool_and(prosrc like '%if not coalesce(v_etab.premium, false) then return false; end if;%') from ancienne)
  union all select 12, 'list_etablissements : masquage photos et logo intact',
         (select count(*) = 1
                 and bool_and(prosrc like '%CASE WHEN premium THEN photos ELSE ''[]''::jsonb END AS photos%'
                          and prosrc like '%CASE WHEN premium THEN logo_url ELSE NULL END AS logo_url%') from liste)
  union all select 13, 'test fonctionnel passé (partie 2)', true
  union all select 14, 'aucune trace : établissements de test',
         (select count(*) = 0 from public.etablissements
           where id like 'test\_etab12\_%' or email like '%-etab12@exemple.invalid')
  union all select 15, 'aucune trace : sessions de test',
         (select count(*) = 0 from public.sessions where user_id like 'test\_etab12\_%')
  union all select 16, 'aucune trace : photos de test dans les fiches réelles',
         (select count(*) = 0 from public.etablissements where photos::text like '%exemple.invalid%')
) t
order by n;
