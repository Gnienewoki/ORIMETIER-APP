-- ============================================================
-- ORIMETIER — Longueur minimale des mots de passe (phase 8) : FICHIER A.
--
-- RÈGLE : tout NOUVEAU mot de passe fait au moins 8 caractères (length(), en caractères).
-- La CONNEXION n'est jamais touchée : inspecteur_session_open, etablissement_session_open,
-- admin_session_open ne sont pas modifiées ; un ancien mot de passe plus court marche toujours.
--
-- ORDRE : 0 (test à blanc, résultat validé) -> déploiement du front v37 -> A (ce fichier)
-- -> contrôle (requêtes 1 et 2). Fichier À LANCER EN ENTIER.
-- PAS DE BEGIN / COMMIT : un bloc DO, atomique à lui seul (validé s'il va au bout, annulé
-- entièrement à la moindre exception, gardes comprises), puis une requête de vérification.
--
-- MÉTHODE : aucun corps n'est recopié ni deviné. Pour chaque fonction, le bloc lit la
-- définition EN PRODUCTION (pg_get_functiondef), vérifie qu'un passage repère y figure UNE
-- fois exactement, insère le contrôle à cet endroit, puis réinstalle la définition
-- (CREATE OR REPLACE : propriétaire, droits EXECUTE, SECURITY DEFINER et search_path
-- conservés, et revérifiés après coup). Tout le reste du corps est inchangé, au caractère près.
--
-- FONCTIONS MODIFIÉES (erreur MOT_DE_PASSE_TROP_COURT ajoutée, dans la convention de chacune) :
--   1. inspecteur_register        -> {ok:false, erreur:'MOT_DE_PASSE_TROP_COURT'}
--      juste après CHAMPS_OBLIGATOIRES, avant CHAMP_TROP_LONG et MOT_DE_PASSE_INVALIDE.
--   2. etablissement_claim_v2     -> {ok:false, erreur:'MOT_DE_PASSE_TROP_COURT'}
--      juste après CHAMPS_OBLIGATOIRES, AVANT la lecture de la fiche et le contrôle du code :
--      un mot de passe trop court ne compte pas comme un essai raté et ne consomme pas le code.
--   3. etablissement_register     -> raise exception 'MOT_DE_PASSE_TROP_COURT'
--      (même mécanisme que DOUBLON : la fonction renvoie un booléen sans code d'erreur),
--      après les contrôles « obligatoire », avant les contrôles de doublon.
--   4. reset_password_with_token  -> raise exception 'MOT_DE_PASSE_TROP_COURT'
--      le seuil passe de 4 à 8 ; MOT_DE_PASSE_INVALIDE reste pour un texte qui ressemble
--      déjà à un hash bcrypt. Contrôle toujours AVANT la lecture du jeton : un mot de passe
--      refusé ne consomme pas le lien. Convient à la version de l'étape e (suppression élève)
--      comme à la version précédente (même ligne repère).
--
-- NON MODIFIÉES (déjà conformes) : admin_create_admin_v2 et admin_change_password_v2
-- refusent déjà moins de 8 caractères (MOT_DE_PASSE_TROP_COURT) ; la requête finale le revérifie.
-- Relançable : une fonction qui cite déjà MOT_DE_PASSE_TROP_COURT est laissée telle quelle.
-- Retour arrière : bloc commenté en fin de fichier.
-- ============================================================

DO $migration$
declare
  v_sig text[] := array[
    'public.inspecteur_register(text,text,text,text,text,text,text,text,text)',
    'public.etablissement_claim_v2(text,text,text,text,text,text,text,text,text,text)',
    'public.etablissement_register(text,text,text,text,text,text,text,text,text,text,text,jsonb,jsonb,text,text,text,text,text,text,text,text)',
    'public.reset_password_with_token(text,text)'];
  v_retour text[] := array['jsonb', 'jsonb', 'boolean', 'boolean'];
  -- regex_apres : insertion après le passage (expression régulière, tolère LF / CRLF)
  -- apres       : insertion après le passage (texte exact, sur une seule ligne)
  -- remplace    : le passage (texte exact, sur une seule ligne) est remplacé
  v_mode text[] := array['regex_apres', 'regex_apres', 'apres', 'remplace'];
  v_ancre text[] := array[
$r$'erreur', 'CHAMPS_OBLIGATOIRES'\);\s*end if;$r$,
$r$'erreur', 'CHAMPS_OBLIGATOIRES'\);\s*end if;$r$,
$a$if p_password is null or length(trim(p_password)) = 0 then return false; end if;$a$,
$a$if p_new_password is null or length(p_new_password) < 4 or p_new_password ~ '^\$2[aby]\$' then$a$];
  v_ajout text[] := array[
$i$

  -- Longueur minimale d'un NOUVEAU mot de passe (phase 8 : 8 caractères, comme les comptes admin)
  if length(p_password) < 8 then
    return jsonb_build_object('ok', false, 'erreur', 'MOT_DE_PASSE_TROP_COURT');
  end if;$i$,
$i$

  -- Longueur minimale d'un NOUVEAU mot de passe (phase 8), avant tout contrôle du code :
  -- un mot de passe trop court ne compte pas comme un essai raté.
  if length(p_password) < 8 then
    return jsonb_build_object('ok', false, 'erreur', 'MOT_DE_PASSE_TROP_COURT');
  end if;$i$,
$i$
  if length(p_password) < 8 then raise exception 'MOT_DE_PASSE_TROP_COURT'; end if;  -- phase 8 : NOUVEAU mot de passe, 8 caractères minimum$i$,
$i$if p_new_password is null or length(p_new_password) < 8 then
    raise exception 'MOT_DE_PASSE_TROP_COURT';  -- phase 8 : 8 caractères minimum
  end if;
  if p_new_password ~ '^\$2[aby]\$' then$i$];
  v_oid regprocedure;
  v_def text;
  v_nouveau text;
  v_n integer;
  v_acl text;
  v_secdef boolean;
  v_config text;
  v_owner oid;
  v_faites integer := 0;
begin
  -- ================= GARDES : arrêt sans rien modifier si la base n'est pas dans l'état attendu
  for i in 1..4 loop
    v_oid := to_regprocedure(v_sig[i]);
    if v_oid is null then
      raise exception 'GARDE : % absente : rien n''est modifié.', v_sig[i];
    end if;
    if pg_get_function_result(v_oid) <> v_retour[i] then
      raise exception 'GARDE : % renvoie % au lieu de % : rien n''est modifié.', v_sig[i], pg_get_function_result(v_oid), v_retour[i];
    end if;
    if not exists (select 1 from pg_proc p where p.oid = v_oid and p.prosecdef and p.prolang = (select l.oid from pg_language l where l.lanname = 'plpgsql')) then
      raise exception 'GARDE : % n''est pas une fonction plpgsql SECURITY DEFINER : rien n''est modifié.', v_sig[i];
    end if;
    if not pg_has_role(current_user, (select p.proowner from pg_proc p where p.oid = v_oid), 'MEMBER') then
      raise exception 'GARDE : % appartient à un autre rôle que % (remplacement impossible) : rien n''est modifié.', v_sig[i], current_user;
    end if;
    v_def := pg_get_functiondef(v_oid);
    if position('MOT_DE_PASSE_TROP_COURT' in v_def) > 0 then
      continue;  -- déjà corrigée : laissée telle quelle
    end if;
    v_n := case when v_mode[i] = 'regex_apres'
                then (select count(*) from regexp_matches(v_def, v_ancre[i], 'g'))
                else (length(v_def) - length(replace(v_def, v_ancre[i], ''))) / length(v_ancre[i]) end;
    if v_n <> 1 then
      raise exception 'GARDE : % : passage repère trouvé % fois au lieu de 1 (définition différente du dépôt) : rien n''est modifié.', v_sig[i], v_n;
    end if;
  end loop;

  -- ================= INSTALLATION (puis contrôle immédiat de chaque fonction)
  for i in 1..4 loop
    v_oid := to_regprocedure(v_sig[i]);
    v_def := pg_get_functiondef(v_oid);
    if position('MOT_DE_PASSE_TROP_COURT' in v_def) > 0 then
      raise notice '% : déjà corrigée, laissée telle quelle.', v_sig[i];
      continue;
    end if;
    select p.proacl::text, p.prosecdef, p.proconfig::text, p.proowner
      into v_acl, v_secdef, v_config, v_owner
    from pg_proc p where p.oid = v_oid;

    v_nouveau := case v_mode[i]
      when 'regex_apres' then regexp_replace(v_def, '(' || v_ancre[i] || ')', '\1' || v_ajout[i])
      when 'apres'       then replace(v_def, v_ancre[i], v_ancre[i] || v_ajout[i])
      else                    replace(v_def, v_ancre[i], v_ajout[i])
    end;
    if v_nouveau = v_def or position(v_ajout[i] in v_nouveau) = 0 then
      raise exception 'ÉCHEC : % : insertion impossible : tout est annulé.', v_sig[i];
    end if;

    execute v_nouveau;

    -- Contrôles (une exception annule tout, fonctions déjà remplacées comprises)
    if position(v_ajout[i] in pg_get_functiondef(to_regprocedure(v_sig[i]))) = 0 then
      raise exception 'ÉCHEC : % : contrôle absent après remplacement : tout est annulé.', v_sig[i];
    end if;
    if v_mode[i] = 'remplace' and position(v_ancre[i] in pg_get_functiondef(to_regprocedure(v_sig[i]))) > 0 then
      raise exception 'ÉCHEC : % : ancien seuil encore présent : tout est annulé.', v_sig[i];
    end if;
    if exists (select 1 from pg_proc p where p.oid = to_regprocedure(v_sig[i])
               and (p.proacl::text is distinct from v_acl or p.prosecdef is distinct from v_secdef
                    or p.proconfig::text is distinct from v_config or p.proowner <> v_owner)) then
      raise exception 'ÉCHEC : % : droits, SECURITY DEFINER, search_path ou propriétaire modifiés : tout est annulé.', v_sig[i];
    end if;
    v_faites := v_faites + 1;
  end loop;

  raise notice 'A appliquée : % fonction(s) corrigée(s) sur 4 (les autres l''étaient déjà).', v_faites;
end;
$migration$;

-- Vérification finale (attendu : 6 lignes, ok = true partout ; détail complet : fichier de contrôle)
select n, controle, ok from (
  select 1 as n, 'inspecteur_register : MOT_DE_PASSE_TROP_COURT à 8' as controle,
         coalesce((select position('MOT_DE_PASSE_TROP_COURT' in d) > 0 and position('length(p_password) < 8' in d) > 0
                   from pg_get_functiondef(to_regprocedure('public.inspecteur_register(text,text,text,text,text,text,text,text,text)')) d), false) as ok
  union all select 2, 'etablissement_claim_v2 : MOT_DE_PASSE_TROP_COURT à 8',
         coalesce((select position('MOT_DE_PASSE_TROP_COURT' in d) > 0 and position('length(p_password) < 8' in d) > 0
                   from pg_get_functiondef(to_regprocedure('public.etablissement_claim_v2(text,text,text,text,text,text,text,text,text,text)')) d), false)
  union all select 3, 'etablissement_register : MOT_DE_PASSE_TROP_COURT à 8',
         coalesce((select position('MOT_DE_PASSE_TROP_COURT' in d) > 0 and position('length(p_password) < 8' in d) > 0
                   from pg_get_functiondef(to_regprocedure('public.etablissement_register(text,text,text,text,text,text,text,text,text,text,text,jsonb,jsonb,text,text,text,text,text,text,text,text)')) d), false)
  union all select 4, 'reset_password_with_token : MOT_DE_PASSE_TROP_COURT à 8, plus de seuil à 4',
         coalesce((select position('MOT_DE_PASSE_TROP_COURT' in d) > 0 and position('length(p_new_password) < 8' in d) > 0
                          and position('length(p_new_password) < 4' in d) = 0
                   from pg_get_functiondef(to_regprocedure('public.reset_password_with_token(text,text)')) d), false)
  union all select 5, 'les 4 : EXECUTE anon toujours accordé',
         has_function_privilege('anon', 'public.inspecteur_register(text,text,text,text,text,text,text,text,text)', 'EXECUTE')
         and has_function_privilege('anon', 'public.etablissement_claim_v2(text,text,text,text,text,text,text,text,text,text)', 'EXECUTE')
         and has_function_privilege('anon', 'public.etablissement_register(text,text,text,text,text,text,text,text,text,text,text,jsonb,jsonb,text,text,text,text,text,text,text,text)', 'EXECUTE')
         and has_function_privilege('anon', 'public.reset_password_with_token(text,text)', 'EXECUTE')
  union all select 6, 'admin_create_admin_v2 et admin_change_password_v2 : déjà à 8 (inchangées)',
         coalesce((select bool_and(position('< 8' in pg_get_functiondef(p.oid)) > 0
                                   and position('MOT_DE_PASSE_TROP_COURT' in pg_get_functiondef(p.oid)) > 0) and count(*) = 2
                   from pg_proc p
                   where p.oid in (to_regprocedure('public.admin_create_admin_v2(text,text,text,text)'),
                                   to_regprocedure('public.admin_change_password_v2(text,text,text)'))), false)
) t order by n;

-- ============================================================
-- RETOUR ARRIÈRE (NE PAS LANCER sauf besoin) : retire les 4 contrôles ajoutés par A et remet
-- le seuil de 4 caractères de reset_password_with_token. Même méthode : chaque définition en
-- production est relue, le passage ajouté est retiré, droits et propriétaire sont conservés.
-- Les expressions tolèrent les espaces et fins de ligne : retirer simplement les « -- »
-- de début de ligne, puis coller seul dans le SQL Editor. Le front v37 reste compatible
-- (il refuse lui-même moins de 8 caractères ; seul le filet côté serveur disparaît).
-- ============================================================
-- DO $retour$
-- declare
--   v_sig text[] := array[
--     'public.inspecteur_register(text,text,text,text,text,text,text,text,text)',
--     'public.etablissement_claim_v2(text,text,text,text,text,text,text,text,text,text)',
--     'public.etablissement_register(text,text,text,text,text,text,text,text,text,text,text,jsonb,jsonb,text,text,text,text,text,text,text,text)',
--     'public.reset_password_with_token(text,text)'];
--   v_motif text[] := array[
--     $r$\s*-- Longueur minimale d'un NOUVEAU mot de passe[^\r\n]*(\s*--[^\r\n]*)?\s*if length\(p_password\) < 8 then\s*return jsonb_build_object\('ok', false, 'erreur', 'MOT_DE_PASSE_TROP_COURT'\);\s*end if;$r$,
--     $r$\s*-- Longueur minimale d'un NOUVEAU mot de passe[^\r\n]*(\s*--[^\r\n]*)?\s*if length\(p_password\) < 8 then\s*return jsonb_build_object\('ok', false, 'erreur', 'MOT_DE_PASSE_TROP_COURT'\);\s*end if;$r$,
--     $r$\s*if length\(p_password\) < 8 then raise exception 'MOT_DE_PASSE_TROP_COURT'; end if;[^\r\n]*$r$,
--     $r$if p_new_password is null or length\(p_new_password\) < 8 then\s*raise exception 'MOT_DE_PASSE_TROP_COURT';[^\r\n]*\s*end if;\s*if p_new_password ~ $r$];
--   v_remplacement text[] := array['', '', '', 'if p_new_password is null or length(p_new_password) < 4 or p_new_password ~ '];
--   v_def text;
--   v_acl text;
-- begin
--   for i in 1..4 loop
--     v_def := pg_get_functiondef(to_regprocedure(v_sig[i]));
--     if position('MOT_DE_PASSE_TROP_COURT' in v_def) = 0 then
--       raise notice '% : rien à retirer.', v_sig[i];
--       continue;
--     end if;
--     if (select count(*) from regexp_matches(v_def, v_motif[i], 'g')) <> 1 then
--       raise exception 'GARDE : % : passage ajouté introuvable ou en double : rien n''est modifié.', v_sig[i];
--     end if;
--     select p.proacl::text into v_acl from pg_proc p where p.oid = to_regprocedure(v_sig[i]);
--     execute regexp_replace(v_def, v_motif[i], v_remplacement[i]);
--     if position('MOT_DE_PASSE_TROP_COURT' in pg_get_functiondef(to_regprocedure(v_sig[i]))) > 0
--        or (select p.proacl::text from pg_proc p where p.oid = to_regprocedure(v_sig[i])) is distinct from v_acl then
--       raise exception 'ÉCHEC : % : retour arrière incomplet : tout est annulé.', v_sig[i];
--     end if;
--   end loop;
--   raise notice 'Retour arrière fait : les 4 fonctions sont revenues à leur version d''avant A.';
-- end;
-- $retour$;
