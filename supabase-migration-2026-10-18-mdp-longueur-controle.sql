-- ============================================================
-- ORIMETIER — Longueur minimale des mots de passe (phase 8) : CONTRÔLES, APRÈS A.
-- Deux requêtes indépendantes : sélectionner celle voulue dans le SQL Editor et la lancer.
--   1) lecture seule : 16 lignes, ok = true partout ;
--   2) tests réels des fonctions, dans un bloc qui se termine TOUJOURS par une erreur
--      volontaire : tout est annulé, rien n'est enregistré (aucun compte, aucune demande,
--      aucune session, aucun essai de code). Le résultat est dans le message d'erreur, attendu :
--        « RÉSULTAT DES TESTS : 9 / 9 OK (tout est annulé, rien n'est enregistré) | T1 ok | … »
-- Données de test inventées : « Testeur Fictif », 0100000099, test-mdp@example.invalid.
-- ============================================================

-- ------------------------------------------------------------
-- 1) APRÈS A — attendu : 16 lignes, ok = true
-- ------------------------------------------------------------
with f(cle, oid) as (values
  ('insp',  to_regprocedure('public.inspecteur_register(text,text,text,text,text,text,text,text,text)')),
  ('claim', to_regprocedure('public.etablissement_claim_v2(text,text,text,text,text,text,text,text,text,text)')),
  ('reg',   to_regprocedure('public.etablissement_register(text,text,text,text,text,text,text,text,text,text,text,jsonb,jsonb,text,text,text,text,text,text,text,text)')),
  ('reset', to_regprocedure('public.reset_password_with_token(text,text)'))
),
d as (select f.cle, f.oid, case when f.oid is not null then pg_get_functiondef(f.oid) end as def from f)
select n, controle, ok from (
  select 1 as n, 'les 4 fonctions corrigées sont présentes' as controle, (select count(*) = 4 from d where d.oid is not null) as ok
  union all select 2, 'les 4 citent MOT_DE_PASSE_TROP_COURT',
      (select count(*) = 4 from d where position('MOT_DE_PASSE_TROP_COURT' in d.def) > 0)
  union all select 3, 'inspecteur_register : length(p_password) < 8',
      coalesce((select position('length(p_password) < 8' in d.def) > 0 from d where d.cle = 'insp'), false)
  union all select 4, 'inspecteur_register : contrôle placé après CHAMPS_OBLIGATOIRES et avant l''INSERT',
      coalesce((select position('CHAMPS_OBLIGATOIRES' in d.def) < position('MOT_DE_PASSE_TROP_COURT' in d.def)
                   and position('MOT_DE_PASSE_TROP_COURT' in d.def) < position('insert into inspecteurs' in d.def)
                from d where d.cle = 'insp'), false)
  union all select 5, 'inspecteur_register : refuse toujours un hash bcrypt (MOT_DE_PASSE_INVALIDE)',
      coalesce((select position('MOT_DE_PASSE_INVALIDE' in d.def) > 0 from d where d.cle = 'insp'), false)
  union all select 6, 'etablissement_claim_v2 : length(p_password) < 8',
      coalesce((select position('length(p_password) < 8' in d.def) > 0 from d where d.cle = 'claim'), false)
  union all select 7, 'etablissement_claim_v2 : contrôle placé AVANT la lecture de la fiche et le code (CODE_INVALIDE)',
      coalesce((select position('MOT_DE_PASSE_TROP_COURT' in d.def) < position('for update' in d.def)
                   and position('MOT_DE_PASSE_TROP_COURT' in d.def) < position('CODE_INVALIDE' in d.def)
                from d where d.cle = 'claim'), false)
  union all select 8, 'etablissement_register : length(p_password) < 8, avant le contrôle de doublon',
      coalesce((select position('length(p_password) < 8' in d.def) > 0
                   and position('MOT_DE_PASSE_TROP_COURT' in d.def) < position('DOUBLON' in d.def)
                from d where d.cle = 'reg'), false)
  union all select 9, 'reset_password_with_token : seuil 8, plus de seuil 4',
      coalesce((select position('length(p_new_password) < 8' in d.def) > 0
                   and position('length(p_new_password) < 4' in d.def) = 0
                from d where d.cle = 'reset'), false)
  union all select 10, 'reset_password_with_token : contrôles AVANT la lecture du jeton, bcrypt toujours refusé',
      coalesce((select position('MOT_DE_PASSE_TROP_COURT' in d.def) < position('from password_resets' in d.def)
                   and position('MOT_DE_PASSE_INVALIDE' in d.def) > 0
                from d where d.cle = 'reset'), false)
  union all select 11, 'les 4 : SECURITY DEFINER et search_path = public',
      (select count(*) = 4 from d join pg_proc p on p.oid = d.oid
       where p.prosecdef and 'search_path=public' = any(p.proconfig))
  union all select 12, 'les 4 : EXECUTE anon et authenticated',
      (select count(*) = 4 from d where d.oid is not null
         and has_function_privilege('anon', d.oid, 'EXECUTE') and has_function_privilege('authenticated', d.oid, 'EXECUTE'))
  union all select 13, 'les 4 : aucun EXECUTE pour PUBLIC',
      not exists (select 1 from d join pg_proc p on p.oid = d.oid, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                  where a.grantee = 0 and a.privilege_type = 'EXECUTE')
  union all select 14, 'admin_create_admin_v2 et admin_change_password_v2 : déjà à 8 (inchangées)',
      coalesce((select bool_and(position('< 8' in pg_get_functiondef(p.oid)) > 0
                                and position('MOT_DE_PASSE_TROP_COURT' in pg_get_functiondef(p.oid)) > 0) and count(*) = 2
                from pg_proc p
                where p.oid in (to_regprocedure('public.admin_create_admin_v2(text,text,text,text)'),
                                to_regprocedure('public.admin_change_password_v2(text,text,text)'))), false)
  union all select 15, 'connexion : aucune fonction *_session_open ne cite MOT_DE_PASSE_TROP_COURT ni une longueur',
      not exists (select 1 from pg_proc p join pg_namespace s on s.oid = p.pronamespace
                  where s.nspname = 'public' and p.proname like '%session_open%'
                    and (position('MOT_DE_PASSE_TROP_COURT' in p.prosrc) > 0
                         or p.prosrc ~* 'length\s*\(\s*(coalesce\s*\()?\s*p_password'))
  union all select 16, 'aucune autre surcharge des 4 fonctions',
      (select count(*) = 4 from pg_proc p join pg_namespace s on s.oid = p.pronamespace
       where s.nspname = 'public'
         and p.proname in ('inspecteur_register', 'etablissement_claim_v2', 'etablissement_register', 'reset_password_with_token'))
) t order by n;

-- ------------------------------------------------------------
-- 2) TESTS RÉELS, TOUJOURS ANNULÉS — attendu : une erreur dont le message commence par
--    « RÉSULTAT DES TESTS : 9 / 9 OK ». Toute mention « ÉCHEC » : me renvoyer le message entier.
-- ------------------------------------------------------------
DO $tests$
declare
  v_ok integer := 0;
  v_res text := '';
  v_j jsonb;
  v_b boolean;
begin
  -- T1 : inscription inspecteur, 7 caractères -> {ok:false, erreur:MOT_DE_PASSE_TROP_COURT}
  begin
    v_j := public.inspecteur_register('test-mdp-8', 'Testeur Fictif', '', '', '', '0100000099', 'test-mdp@example.invalid', '1234567', '');
    if v_j->>'erreur' = 'MOT_DE_PASSE_TROP_COURT' then v_ok := v_ok + 1; v_res := v_res || ' | T1 ok';
    else v_res := v_res || ' | T1 ÉCHEC : ' || coalesce(v_j::text, 'null'); end if;
  exception when others then v_res := v_res || ' | T1 ÉCHEC : ' || sqlerrm;
  end;

  -- T2 : récupération de fiche, 7 caractères -> MOT_DE_PASSE_TROP_COURT (avant même la fiche)
  begin
    v_j := public.etablissement_claim_v2('fiche-inexistante-test', 'AAAAAAAA', 'test-mdp@example.invalid', '1234567');
    if v_j->>'erreur' = 'MOT_DE_PASSE_TROP_COURT' then v_ok := v_ok + 1; v_res := v_res || ' | T2 ok';
    else v_res := v_res || ' | T2 ÉCHEC : ' || coalesce(v_j::text, 'null'); end if;
  exception when others then v_res := v_res || ' | T2 ÉCHEC : ' || sqlerrm;
  end;

  -- T3 : récupération de fiche, 8 caractères -> le contrôle laisse passer (FICHE_INTROUVABLE)
  begin
    v_j := public.etablissement_claim_v2('fiche-inexistante-test', 'AAAAAAAA', 'test-mdp@example.invalid', '12345678');
    if v_j->>'erreur' = 'FICHE_INTROUVABLE' then v_ok := v_ok + 1; v_res := v_res || ' | T3 ok';
    else v_res := v_res || ' | T3 ÉCHEC : ' || coalesce(v_j::text, 'null'); end if;
  exception when others then v_res := v_res || ' | T3 ÉCHEC : ' || sqlerrm;
  end;

  -- T4 : demande d'inscription établissement, 7 caractères -> exception MOT_DE_PASSE_TROP_COURT
  begin
    v_b := public.etablissement_register(p_id => 'test-mdp-8', p_nom => 'Établissement Fictif Test MDP', p_region => '',
             p_ville => 'Ville Fictive', p_quartier => '', p_type => '', p_responsable => '', p_tel => '',
             p_email => 'test-mdp@example.invalid', p_password => '1234567', p_date_inscription => '',
             p_filieres_proposees => '[]'::jsonb);
    v_res := v_res || ' | T4 ÉCHEC : aucune erreur (retour ' || coalesce(v_b::text, 'null') || ')';
  exception when others then
    if sqlerrm = 'MOT_DE_PASSE_TROP_COURT' then v_ok := v_ok + 1; v_res := v_res || ' | T4 ok';
    else v_res := v_res || ' | T4 ÉCHEC : ' || sqlerrm; end if;
  end;

  -- T5 : réinitialisation, 7 caractères -> exception MOT_DE_PASSE_TROP_COURT (jeton jamais lu)
  begin
    v_b := public.reset_password_with_token('jeton-invente-test', '1234567');
    v_res := v_res || ' | T5 ÉCHEC : aucune erreur (retour ' || coalesce(v_b::text, 'null') || ')';
  exception when others then
    if sqlerrm = 'MOT_DE_PASSE_TROP_COURT' then v_ok := v_ok + 1; v_res := v_res || ' | T5 ok';
    else v_res := v_res || ' | T5 ÉCHEC : ' || sqlerrm; end if;
  end;

  -- T6 : réinitialisation, 8 caractères, jeton inventé -> false (mot de passe accepté, lien invalide)
  begin
    v_b := public.reset_password_with_token('jeton-invente-test', '12345678');
    if v_b is false then v_ok := v_ok + 1; v_res := v_res || ' | T6 ok';
    else v_res := v_res || ' | T6 ÉCHEC : retour ' || coalesce(v_b::text, 'null'); end if;
  exception when others then v_res := v_res || ' | T6 ÉCHEC : ' || sqlerrm;
  end;

  -- T7 : réinitialisation, texte en forme de hash bcrypt (plus de 8 caractères) -> MOT_DE_PASSE_INVALIDE
  begin
    v_b := public.reset_password_with_token('jeton-invente-test', '$2a$10$abcdefghijklmnopqrstuv');
    v_res := v_res || ' | T7 ÉCHEC : aucune erreur (retour ' || coalesce(v_b::text, 'null') || ')';
  exception when others then
    if sqlerrm = 'MOT_DE_PASSE_INVALIDE' then v_ok := v_ok + 1; v_res := v_res || ' | T7 ok';
    else v_res := v_res || ' | T7 ÉCHEC : ' || sqlerrm; end if;
  end;

  -- T8 : connexion inspecteur avec un mot de passe COURT -> aucune erreur (compte inconnu : pas de session)
  begin
    perform public.inspecteur_session_open('0100000099', '123');
    v_ok := v_ok + 1; v_res := v_res || ' | T8 ok';
  exception when others then v_res := v_res || ' | T8 ÉCHEC : ' || sqlerrm;
  end;

  -- T9 : connexion établissement avec un mot de passe COURT -> aucune erreur
  begin
    perform public.etablissement_session_open('test-mdp@example.invalid', '123');
    v_ok := v_ok + 1; v_res := v_res || ' | T9 ok';
  exception when others then v_res := v_res || ' | T9 ÉCHEC : ' || sqlerrm;
  end;

  -- Erreur volontaire : annule TOUT ce que les tests auraient pu écrire.
  raise exception 'RÉSULTAT DES TESTS : % / 9 OK (tout est annulé, rien n''est enregistré)%', v_ok, v_res;
end;
$tests$;
