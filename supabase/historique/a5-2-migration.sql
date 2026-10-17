-- ============================================================
-- ORIMETIER — A5 : suppression de l'import en masse des établissements (fonctions SQL mortes).
-- FICHIER 2 : MIGRATION
--
-- ORDRE DE DÉPLOIEMENT :
--   0. front poussé et vérifié EN PREMIER (admin.js sans la zone Import, supabase-client.js sans
--      espAdminBulkImportEtabRPC, service worker v23) : il n'appelle plus aucune des fonctions
--      ci-dessous, il marche donc avant ET après ce SQL ;
--   1. a5-1-test.sql       test à blanc : DOIT finir sur l'erreur « TEST À BLANC RÉUSSI : tout a
--                          été annulé automatiquement (aucune donnée modifiée) ». Toute autre
--                          erreur (GARDE ..., ÉCHEC ...) = vrai échec : ne pas lancer le 2.
--   2. a5-2-migration.sql  installation pour de bon, puis le tableau (n, controle, ok) : TOUTES
--                          les lignes à true.
-- PAS DE BEGIN / COMMIT / ROLLBACK : chaque fichier tient dans UN bloc DO, atomique à lui seul.
-- Les blocs GARDES et INSTALLATION sont identiques, mot pour mot, dans les deux fichiers.
--
-- AUDIT DU DÉPÔT (2026-10-08) : après le retrait de la zone Import, plus aucun fichier du front
--   (admin.js, supabase-client.js, sw.js, HTML) n'appelle ces fonctions ; aucune fonction SQL connue
--   (référence live 2026-09-26 + migrations du dépôt et de Téléchargements) ne les appelle.
--   La carte « Codes de récupération » passe par admin_lister_codes_v2 / admin_regenerer_code_v2 /
--   admin_annuler_code_v2, NON touchées.
-- CE QUE CE SQL FAIT : DROP FUNCTION (sans CASCADE) des 6 fonctions suivantes, celles présentes :
--   admin_bulk_import_etablissements(text, text, text, jsonb)       (p_admin_password, ancienne)
--   admin_bulk_import_etablissements_v2(text, text, text, jsonb)    (p_token, appelée par l'ancien front)
--   admin_list_unclaimed_codes(text)                                (p_admin_password, ancienne)
--   admin_list_unclaimed_codes_v2(text)                             (p_token, remplacée par admin_lister_codes_v2)
--   admin_list_all_etablissement_codes(text)                        (p_admin_password, ancienne)
--   admin_list_all_etablissement_codes_v2(text)                     (p_token, remplacée par admin_lister_codes_v2)
--   Rien d'autre n'est modifié (tables, données, droits, autres fonctions inchangés).
-- HORS PÉRIMÈTRE (non touchées ici) : admin_marquer_demande_traitee(_v2),
--   admin_lier_photos_logo_demande(_v2).
-- GARDES : 4 171 fiches ; exactement 1 fiche réclamée ; les RPC du front présentes ; au moins une
--   des 6 fonctions encore présente ; aucune autre version (surcharge) de ces noms ; AUCUNE autre
--   fonction, vue, trigger, policy, valeur par défaut ou tâche pg_cron qui y fait référence.
--   Sinon arrêt, rien n'est modifié.
-- CORRECTIF 2026-10-08 : la recherche des fonctions qui citent encore ces noms ignore désormais les
--   commentaires de ligne : regexp_replace(p.prosrc, '--[^\n]*', '', 'g') au lieu de p.prosrc, dans la
--   garde « aucune AUTRE fonction ne les cite » et dans le contrôle final n°2. Raison :
--   admin_valider_demande_v2(text, uuid, boolean) contient seulement le COMMENTAIRE « -- Même format
--   d'id que admin_bulk_import_etablissements (compteur = 1). », pas un appel : la garde s'arrêtait à tort.
-- ============================================================

-- Ce fichier : un bloc DO (gardes + installation), validé s'il va au bout ; puis la requête
-- finale (n, controle, ok). Relancé après une installation réussie, il s'arrête sur la garde
-- « suppression déjà faite » sans rien modifier.

DO $migration$
declare
  v_n integer; v_txt text; v_oid oid;
  v_cibles text[] := array[
    'public.admin_bulk_import_etablissements(text,text,text,jsonb)',
    'public.admin_bulk_import_etablissements_v2(text,text,text,jsonb)',
    'public.admin_list_unclaimed_codes(text)',
    'public.admin_list_unclaimed_codes_v2(text)',
    'public.admin_list_all_etablissement_codes(text)',
    'public.admin_list_all_etablissement_codes_v2(text)'];
  v_noms text[] := array[
    'admin_bulk_import_etablissements', 'admin_bulk_import_etablissements_v2',
    'admin_list_unclaimed_codes', 'admin_list_unclaimed_codes_v2',
    'admin_list_all_etablissement_codes', 'admin_list_all_etablissement_codes_v2'];
  v_motif text := '(admin_bulk_import_etablissements|admin_list_unclaimed_codes|admin_list_all_etablissement_codes)';
  v_oids oid[];
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
  if to_regprocedure('public.list_etablissements()') is null
     or to_regprocedure('public.admin_lister_codes_v2(text)') is null
     or to_regprocedure('public.admin_regenerer_code_v2(text,text)') is null
     or to_regprocedure('public.admin_annuler_code_v2(text,text)') is null
     or to_regprocedure('public.etablissement_claim_v2(text,text,text,text,text,text,text,text,text,text)') is null
     or to_regprocedure('public.etablissement_register(text,text,text,text,text,text,text,text,text,text,text,jsonb,jsonb,text,text,text,text,text,text,text,text)') is null
     or to_regprocedure('public.etablissement_verifier_doublon(text)') is null
     or to_regprocedure('public.etablissement_session_open(text,text)') is null
     or to_regprocedure('public.etablissement_get_own_v2(text)') is null
     or to_regprocedure('public.admin_session_open(text,text)') is null then
    raise exception 'GARDE : une fonction attendue est absente (list_etablissements, admin_lister_codes_v2, admin_regenerer_code_v2, admin_annuler_code_v2, etablissement_claim_v2, etablissement_register, etablissement_verifier_doublon, etablissement_session_open, etablissement_get_own_v2, admin_session_open) : rien n''est modifié.';
  end if;

  -- Fonctions à supprimer, celles présentes
  select array_agg(to_regprocedure(c)::oid) into v_oids
  from unnest(v_cibles) as c where to_regprocedure(c) is not null;
  if v_oids is null then
    raise exception 'GARDE : aucune des 6 fonctions n''existe encore (suppression déjà faite) : rien n''est modifié.';
  end if;
  select string_agg(p.oid::regprocedure::text, ', ' order by p.proname) into v_txt
  from pg_proc p where p.oid = any(v_oids);
  raise notice 'Présentes, à supprimer (% sur 6) : %', cardinality(v_oids), v_txt;

  -- Aucune autre version (autre signature) de ces noms, dans aucun schéma
  select string_agg(p.oid::regprocedure::text, ', ') into v_txt
  from pg_proc p where p.proname = any(v_noms) and not (p.oid = any(v_oids));
  if v_txt is not null then
    raise exception 'GARDE : autre(s) version(s) inattendue(s) de ces fonctions : % : rien n''est modifié.', v_txt;
  end if;

  -- Aucune AUTRE fonction (tout schéma utilisateur) ne les cite dans son code
  select string_agg(p.oid::regprocedure::text, ', ' order by p.oid::regprocedure::text) into v_txt
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname not in ('pg_catalog', 'information_schema')
    and not (p.oid = any(v_oids))
    and regexp_replace(p.prosrc, '--[^\n]*', '', 'g') ~ v_motif;
  if v_txt is not null then
    raise exception 'GARDE : fonction(s) qui appellent encore l''import ou les anciennes listes de codes : % : rien n''est modifié.', v_txt;
  end if;

  -- Aucun autre objet (vue, trigger, policy, valeur par défaut...) n'en dépend
  select string_agg(pg_describe_object(d.classid, d.objid, d.objsubid), ', ') into v_txt
  from pg_depend d
  where d.refclassid = 'pg_proc'::regclass and d.refobjid = any(v_oids) and d.deptype <> 'i';
  if v_txt is not null then
    raise exception 'GARDE : objet(s) qui dépendent de ces fonctions : % : rien n''est modifié.', v_txt;
  end if;

  -- Aucune tâche planifiée (pg_cron, si installé) ne les appelle
  if to_regclass('cron.job') is not null then
    execute 'select count(*) from cron.job where command ~ $1' into v_n using v_motif;
    if v_n > 0 then
      raise exception 'GARDE : % tâche(s) pg_cron appellent ces fonctions : rien n''est modifié.', v_n;
    end if;
  end if;

  -- ================= INSTALLATION : DROP des fonctions mortes, sans CASCADE
  for v_oid in select unnest(v_oids) loop
    v_txt := v_oid::regprocedure::text;
    execute format('DROP FUNCTION %s', v_txt);
    raise notice 'Supprimée : %', v_txt;
  end loop;

  if exists (select 1 from pg_proc p where p.proname = any(v_noms)) then
    raise exception 'ÉCHEC suppression : une fonction à ces noms existe encore : rien n''est modifié.';
  end if;
  raise notice 'Installation : plus aucune fonction d''import en masse ni ancienne liste de codes';
end $migration$;


-- ############################################################
-- CONTRÔLE FINAL (dernière instruction : toutes les lignes = true)
-- ############################################################
with noms as (select unnest(array[
       'admin_bulk_import_etablissements', 'admin_bulk_import_etablissements_v2',
       'admin_list_unclaimed_codes', 'admin_list_unclaimed_codes_v2',
       'admin_list_all_etablissement_codes', 'admin_list_all_etablissement_codes_v2']) as nom),
f as (select p.oid from pg_proc p
      where p.oid in (to_regprocedure('public.list_etablissements()'),
                      to_regprocedure('public.admin_lister_codes_v2(text)'),
                      to_regprocedure('public.admin_regenerer_code_v2(text,text)'),
                      to_regprocedure('public.admin_annuler_code_v2(text,text)'),
                      to_regprocedure('public.etablissement_claim_v2(text,text,text,text,text,text,text,text,text,text)'),
                      to_regprocedure('public.etablissement_register(text,text,text,text,text,text,text,text,text,text,text,jsonb,jsonb,text,text,text,text,text,text,text,text)'),
                      to_regprocedure('public.etablissement_verifier_doublon(text)'),
                      to_regprocedure('public.etablissement_session_open(text,text)'),
                      to_regprocedure('public.etablissement_get_own_v2(text)'),
                      to_regprocedure('public.admin_session_open(text,text)')))
select n, controle, ok from (
  select 1 as n, 'les 6 fonctions (admin_bulk_import_etablissements, admin_list_unclaimed_codes, admin_list_all_etablissement_codes, avec et sans _v2) n''existent plus, sous aucune signature' as controle,
         not exists (select 1 from pg_proc p join noms on noms.nom = p.proname) as ok
  union all select 2, 'aucune fonction restante ne cite ces noms dans son code',
         not exists (select 1 from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
                     where ns.nspname not in ('pg_catalog', 'information_schema')
                       and regexp_replace(p.prosrc, '--[^\n]*', '', 'g') ~ '(admin_bulk_import_etablissements|admin_list_unclaimed_codes|admin_list_all_etablissement_codes)')
  union all select 3, 'les 10 RPC encore utilisées (liste, carte des codes + régénérer + annuler, inscription, doublon, réclamation, connexions établissement et admin, fiche perso) : présentes, SECURITY DEFINER, exécutables par anon',
         (select count(*) = 10 and bool_and(p.prosecdef and has_function_privilege('anon', f.oid, 'EXECUTE'))
            from f join pg_proc p on p.oid = f.oid)
  union all select 4, 'données inchangées : 4 171 fiches, 1 réclamée, aucune trace de test',
         (select count(*) = 4171 from public.etablissements)
         and (select count(*) = 1 from public.etablissements e where coalesce(e.reclame, false))
         and not exists (select 1 from public.etablissements e where e.id like 'test\_a5\_%')
         and not exists (select 1 from public.admins a where a.id = 'test_a5_adm')
         and not exists (select 1 from public.demandes_inscription_etablissements d where lower(d.email) = 'insc-a5@exemple.invalid')
) t
order by n;
