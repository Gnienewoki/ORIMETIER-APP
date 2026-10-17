-- ============================================================
-- ORIMETIER — A4 partie 2 : filières d'un établissement, maximum 10 -> 15.
-- FICHIER 2 : MIGRATION
--
-- ORDRE DE DÉPLOIEMENT :
--   1. a4b-1-test.sql       test à blanc : DOIT finir sur l'erreur « TEST À BLANC RÉUSSI : tout a
--                           été annulé automatiquement (aucune donnée modifiée) ». Toute autre
--                           erreur (GARDE ..., ÉCHEC ...) = vrai échec : ne pas lancer le 2.
--   2. a4b-2-migration.sql  installation pour de bon, puis le tableau (n, controle, ok) : TOUTES
--                           les lignes à true.
--   3. ENSUITE seulement, front poussé (etablissement.js ESP_ETAB_FILIERES_MAX = 15, service worker
--      v25). Dans l'autre sens, le tableau de bord proposerait une 11e filière que la base refuse ;
--      l'ancien front, lui, marche avec la base à 15 (il s'arrête toujours à 10).
-- PAS DE BEGIN / COMMIT / ROLLBACK : chaque fichier tient dans UN bloc DO, atomique à lui seul.
-- Les blocs GARDES et INSTALLATION sont identiques, mot pour mot, dans les deux fichiers.
--
-- OÙ EST LA LIMITE (recherche dans le dépôt, la référence live et Téléchargements) :
--   SEULE fonction en service : etablissement_add_filiere_v2(p_token text, p_nom text, p_diplome text)
--     (6a-2-etablissement-rpc-v2.sql, l. 275) :
--     if jsonb_array_length(coalesce(v_etab.filieres_proposees, '[]'::jsonb)) >= 10 then return false; end if;
--     La fonction ne renvoie aucun message : seulement false (le front affiche « limite atteinte »).
--   NON TOUCHÉE : l'ancienne etablissement_add_filiere(p_etab_id, p_password, ...) (live-2026-09-26.sql,
--     l. 604, même ligne) : plus appelée par le front, à supprimer au nettoyage 6c ; signalée si présente.
--   AUCUNE limite : etablissement_register, admin_valider_demande_v2, contraintes CHECK, triggers
--     (seuls triggers : hachage du mot de passe).
-- CE QUE CE SQL FAIT : lit la définition ACTUELLE (pg_get_functiondef) de etablissement_add_filiere_v2,
--   y remplace UNIQUEMENT « >= 10 then return false; » par « >= 15 then return false; » sur la ligne de
--   la limite, et la réinstalle (CREATE OR REPLACE : même fonction, mêmes droits, même propriétaire,
--   SECURITY DEFINER et search_path inchangés, vérifiés). Aucune donnée modifiée.
-- GARDES : 4 171 fiches ; exactement 1 fiche réclamée ; fonction présente, une seule signature,
--   SECURITY DEFINER, version par jeton ; le texte de la limite à 10 présent exactement UNE fois ;
--   limite à 15 pas encore installée. Sinon arrêt, rien n'est modifié.
-- ============================================================

-- Ce fichier : un bloc DO (gardes + installation), validé s'il va au bout ; puis la requête
-- finale (n, controle, ok). Relancé après une installation réussie, il s'arrête sur la garde
-- « limite à 15 déjà installée » sans rien modifier.

DO $migration$
declare
  v_n integer; v_txt text;
  v_oid oid := to_regprocedure('public.etablissement_add_filiere_v2(text,text,text)');
  v_ancien constant text := 'jsonb_array_length(coalesce(v_etab.filieres_proposees, ''[]''::jsonb)) >= 10 then return false;';
  v_nouveau constant text := 'jsonb_array_length(coalesce(v_etab.filieres_proposees, ''[]''::jsonb)) >= 15 then return false;';
  v_def text; v_src_avant text; v_acl_avant text; v_owner_avant oid; v_config_avant text[]; v_secdef boolean;
begin
  -- ================= GARDES : arrêt sans rien modifier si la base n'est pas dans l'état attendu
  select count(*) into v_n from public.etablissements;
  if v_n is distinct from 4171 then
    raise exception 'GARDE : % fiches dans etablissements au lieu de 4 171 : rien n''est modifié.', v_n;
  end if;
  select count(*) into v_n from public.etablissements e where coalesce(e.reclame, false);
  if v_n is distinct from 1 then
    raise exception 'GARDE : % fiche(s) réclamée(s) au lieu de 1 : rien n''est modifié.', v_n;
  end if;
  if v_oid is null then
    raise exception 'GARDE : etablissement_add_filiere_v2(text, text, text) est absente : rien n''est modifié.';
  end if;
  select count(*) into v_n from pg_proc p where p.proname = 'etablissement_add_filiere_v2';
  if v_n <> 1 then
    raise exception 'GARDE : % fonction(s) nommée(s) etablissement_add_filiere_v2 au lieu d''une seule : rien n''est modifié.', v_n;
  end if;
  select p.prosrc, p.proacl::text, p.proowner, p.proconfig, p.prosecdef
    into v_src_avant, v_acl_avant, v_owner_avant, v_config_avant, v_secdef
  from pg_proc p where p.oid = v_oid;
  if not v_secdef then
    raise exception 'GARDE : etablissement_add_filiere_v2 n''est pas SECURITY DEFINER : rien n''est modifié.';
  end if;
  if strpos(v_src_avant, '_session_user(p_token, ''etablissement'')') = 0 then
    raise exception 'GARDE : etablissement_add_filiere_v2 n''est pas la version par jeton attendue : rien n''est modifié.';
  end if;
  if strpos(v_src_avant, v_nouveau) > 0 then
    raise exception 'GARDE : la limite à 15 est déjà installée : rien n''est modifié.';
  end if;
  v_n := (length(v_src_avant) - length(replace(v_src_avant, v_ancien, ''))) / length(v_ancien);
  if v_n <> 1 then
    raise exception 'GARDE : le texte de la limite à 10 (« % ») figure % fois au lieu d''une : rien n''est modifié.', v_ancien, v_n;
  end if;
  v_def := pg_get_functiondef(v_oid);
  v_n := (length(v_def) - length(replace(v_def, v_ancien, ''))) / length(v_ancien);
  if v_n <> 1 then
    raise exception 'GARDE : le texte de la limite à 10 figure % fois dans pg_get_functiondef au lieu d''une : rien n''est modifié.', v_n;
  end if;
  raise notice 'Avant : etablissement_add_filiere_v2, SECURITY DEFINER, config %, droits %', v_config_avant, v_acl_avant;
  if to_regprocedure('public.etablissement_add_filiere(text,text,text,text)') is not null then
    raise notice 'Ancienne etablissement_add_filiere(text, text, text, text) encore présente (limite 10, NON modifiée : plus appelée, à supprimer en 6c)';
  end if;

  -- ================= INSTALLATION : même définition, limite 10 -> 15, rien d'autre
  execute replace(v_def, v_ancien, v_nouveau);

  if to_regprocedure('public.etablissement_add_filiere_v2(text,text,text)') is distinct from v_oid::regprocedure then
    raise exception 'ÉCHEC installation : la fonction a changé d''identité : rien n''est modifié.';
  end if;
  select count(*) into v_n from pg_proc p
  where p.oid = v_oid
    and p.prosrc = replace(v_src_avant, v_ancien, v_nouveau)
    and p.prosecdef
    and p.proacl::text is not distinct from v_acl_avant
    and p.proowner = v_owner_avant
    and p.proconfig is not distinct from v_config_avant;
  if v_n <> 1 then
    raise exception 'ÉCHEC installation : corps, droits, propriétaire, SECURITY DEFINER ou search_path différents de l''attendu : rien n''est modifié.';
  end if;
  raise notice 'Installation : etablissement_add_filiere_v2 limitée à 15 filières (le reste de la définition et les droits sont inchangés)';
end $migration$;


-- ############################################################
-- CONTRÔLE FINAL (dernière instruction : toutes les lignes = true)
-- ############################################################
with f as (select p.* from pg_proc p where p.oid = to_regprocedure('public.etablissement_add_filiere_v2(text,text,text)')),
lim as (select 'jsonb_array_length(coalesce(v_etab.filieres_proposees, ''[]''::jsonb)) >= 15 then return false;' as l15,
               'jsonb_array_length(coalesce(v_etab.filieres_proposees, ''[]''::jsonb)) >= 10 then return false;' as l10)
select n, controle, ok from (
  select 1 as n, 'etablissement_add_filiere_v2(text, text, text) : limite à 15 installée, une seule fois ; plus aucune limite à 10' as controle,
         coalesce((select (length(f.prosrc) - length(replace(f.prosrc, lim.l15, ''))) / length(lim.l15) = 1
                          and strpos(f.prosrc, lim.l10) = 0
                     from f, lim), false) as ok
  union all select 2, 'une seule fonction etablissement_add_filiere_v2 (aucune autre signature créée)',
         (select count(*) = 1 from pg_proc p where p.proname = 'etablissement_add_filiere_v2')
  union all select 3, 'toujours SECURITY DEFINER, search_path = public, version par jeton (_session_user)',
         coalesce((select f.prosecdef and 'search_path=public' = any(f.proconfig)
                          and strpos(f.prosrc, '_session_user(p_token, ''etablissement'')') > 0 from f), false)
  union all select 4, 'droits inchangés : EXECUTE pour anon et authenticated, aucun droit pour PUBLIC',
         coalesce((select has_function_privilege('anon', f.oid, 'EXECUTE')
                          and has_function_privilege('authenticated', f.oid, 'EXECUTE')
                          and not exists (select 1 from aclexplode(f.proacl) a where a.grantee = 0)
                          and f.proacl is not null from f), false)
  union all select 5, 'données inchangées : 4 171 fiches, 1 réclamée, aucune trace de test',
         (select count(*) = 4171 from public.etablissements)
         and (select count(*) = 1 from public.etablissements e where coalesce(e.reclame, false))
         and not exists (select 1 from public.etablissements e where e.id like 'test\_a4b\_%')
         and not exists (select 1 from public.demandes_inscription_etablissements d where lower(d.email) = 'insc-a4b@exemple.invalid')
) t
order by n;
