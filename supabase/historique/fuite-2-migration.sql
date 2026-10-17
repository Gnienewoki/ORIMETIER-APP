-- ============================================================
-- ORIMETIER — Fuite etablissements (avant le courrier) : plus aucun accès DIRECT de la clé publique.
-- FICHIER 2 : MIGRATION
--
-- ORDRE DE DÉPLOIEMENT :
--   0. front poussé et vérifié EN PREMIER (supabase-client.js n'écoute plus etablissements en temps
--      réel, service worker v22) : il marche avant ET après ce SQL ;
--   1. fuite-1-test.sql       test à blanc : DOIT finir sur l'erreur « TEST À BLANC RÉUSSI : tout a
--                             été annulé automatiquement (aucune donnée modifiée) ». Toute autre
--                             erreur (GARDE ..., ÉCHEC ...) = vrai échec : ne pas lancer le 2.
--   2. fuite-2-migration.sql  installation pour de bon, puis le tableau (n, controle, ok) : TOUTES
--                             les lignes à true.
-- PAS DE BEGIN / COMMIT / ROLLBACK : chaque fichier tient dans UN bloc DO, atomique à lui seul.
-- Les blocs GARDES et INSTALLATION sont identiques, mot pour mot, dans les deux fichiers.
-- Audit avant / après : fuite-0-audit-lecture.sql (lecture seule).
--
-- ÉTAT ACTUEL : après B1, anon / authenticated ont encore, colonne par colonne, les droits de lecture
--   (email, tel, tel2, tel3, responsable, contact_tel, site_web, logo_url, photos, password...) et
--   d'écriture (INSERT, UPDATE) sur etablissements, voire DELETE / TRUNCATE sur la table, sans le
--   masquage Premium de list_etablissements.
-- AUDIT DU DÉPÔT : le front ne lit ni n'écrit JAMAIS etablissements directement : tout passe par
--   des fonctions SECURITY DEFINER (list_etablissements, etablissement_register, etablissement_claim_v2,
--   etablissement_session_open, etablissement_get_own_v2, etablissement_update_*_v2, admin_*_v2...).
--   Seul accès direct : l'écoute temps réel (postgres_changes) de la table, retirée du front.
-- CE QUE CE SQL FAIT : REVOKE ALL (table + toutes les colonnes) sur etablissements à PUBLIC, anon,
--   authenticated. Aucune colonne n'est gardée en lecture directe : le front n'en a besoin d'aucune.
--   Rien d'autre n'est modifié (RLS, policies, fonctions, données inchangées).
-- GARDES : 4 171 fiches ; exactement 1 fiche réclamée ; les RPC du front présentes ; aucune fonction
--   SECURITY INVOKER appelable par la clé publique ne lit etablissements ; correction pas encore
--   installée. Sinon arrêt, rien n'est modifié.
-- ============================================================

-- Ce fichier : un bloc DO (gardes + installation), validé s'il va au bout ; puis la requête
-- finale (n, controle, ok). Relancé après une installation réussie, il s'arrête sur la garde
-- « correction déjà installée » sans rien modifier.

DO $migration$
declare
  v_n integer; v_txt text; v_cols text;
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
     or to_regprocedure('public.etablissement_claim_v2(text,text,text,text,text,text,text,text,text,text)') is null
     or to_regprocedure('public.etablissement_register(text,text,text,text,text,text,text,text,text,text,text,jsonb,jsonb,text,text,text,text,text,text,text,text)') is null
     or to_regprocedure('public.etablissement_session_open(text,text)') is null
     or to_regprocedure('public.etablissement_get_own_v2(text)') is null
     or to_regprocedure('public.admin_session_open(text,text)') is null then
    raise exception 'GARDE : une fonction attendue est absente (list_etablissements, admin_lister_codes_v2, etablissement_claim_v2, etablissement_register, etablissement_session_open, etablissement_get_own_v2, admin_session_open) : rien n''est modifié.';
  end if;
  -- Toute fonction appelable par la clé publique qui lit ou écrit etablissements doit être
  -- SECURITY DEFINER : une fonction SECURITY INVOKER serait cassée par le retrait des droits.
  select string_agg(p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')', ', ' order by p.proname) into v_txt
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and not p.prosecdef and p.prosrc ~ '\metablissements\M'
    and (has_function_privilege('anon', p.oid, 'EXECUTE') or has_function_privilege('authenticated', p.oid, 'EXECUTE'));
  if v_txt is not null then
    raise exception 'GARDE : fonction(s) SECURITY INVOKER appelable(s) par la clé publique qui lisent etablissements, elles seraient cassées : % : rien n''est modifié.', v_txt;
  end if;
  if not exists (select 1 from unnest(array['anon', 'authenticated']) as r(role),
                               unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER']) as p(p)
                 where has_table_privilege(r.role, 'public.etablissements', p.p))
     and not exists (select 1 from unnest(array['anon', 'authenticated']) as r(role)
                     where has_any_column_privilege(r.role, 'public.etablissements', 'SELECT, INSERT, UPDATE, REFERENCES')) then
    raise exception 'GARDE : la clé publique n''a déjà plus aucun droit direct sur etablissements (correction déjà installée) : rien n''est modifié.';
  end if;

  -- État avant correction (affiché, rien n'est modifié ici)
  select string_agg(r.role || ':' || p.p, ', ' order by r.role, p.p) into v_txt
  from unnest(array['anon', 'authenticated']) as r(role),
       unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER']) as p(p)
  where has_table_privilege(r.role, 'public.etablissements', p.p);
  raise notice 'Avant : droits sur TOUTE la table pour la clé publique : %', coalesce(v_txt, 'aucun');
  select string_agg(x.role || ':' || x.p || ' sur ' || x.n || ' colonne(s)', ', ' order by x.role, x.p) into v_txt
  from (select r.role, p.p, count(*) as n
        from unnest(array['anon', 'authenticated']) as r(role),
             unnest(array['SELECT', 'INSERT', 'UPDATE', 'REFERENCES']) as p(p),
             pg_attribute a
        where a.attrelid = 'public.etablissements'::regclass and a.attnum > 0 and not a.attisdropped
          and has_column_privilege(r.role, 'public.etablissements', a.attname, p.p)
        group by r.role, p.p) x;
  raise notice 'Avant : droits colonne par colonne pour la clé publique : %', coalesce(v_txt, 'aucun');
  select case when c.relrowsecurity then 'activée' else 'DÉSACTIVÉE' end
         || ', ' || (select count(*) from pg_policies pp where pp.schemaname = 'public' and pp.tablename = 'etablissements') || ' policy(ies)'
    into v_txt from pg_class c where c.oid = 'public.etablissements'::regclass;
  raise notice 'RLS sur etablissements (inchangée ici) : %', v_txt;
  select string_agg(pt.pubname, ', ') into v_txt from pg_publication_tables pt
  where pt.schemaname = 'public' and pt.tablename = 'etablissements';
  raise notice 'Publication(s) temps réel contenant etablissements : % (le front n''écoute plus cette table)', coalesce(v_txt, 'aucune');
  select string_agg(distinct v.oid::regclass::text, ', ') into v_txt
  from pg_depend d join pg_rewrite rw on rw.oid = d.objid join pg_class v on v.oid = rw.ev_class
  where d.classid = 'pg_rewrite'::regclass and d.refobjid = 'public.etablissements'::regclass
    and v.oid <> 'public.etablissements'::regclass
    and (has_table_privilege('anon', v.oid, 'SELECT') or has_table_privilege('authenticated', v.oid, 'SELECT'));
  if v_txt is not null then
    raise notice 'ATTENTION (non corrigé ici) : vue(s) lisible(s) par la clé publique construite(s) sur etablissements : %', v_txt;
  end if;

  -- ================= INSTALLATION : plus AUCUN droit direct de la clé publique sur etablissements
  -- (ni lecture, ni INSERT, ni UPDATE, ni DELETE, ni TRUNCATE...). Le front n'y accède que par
  -- des fonctions SECURITY DEFINER (list_etablissements masque les contacts hors Premium).
  -- Les droits colonne par colonne (posés par B1) sont retirés en plus des droits de table.
  select string_agg(quote_ident(a.attname), ', ' order by a.attnum) into v_cols
  from pg_attribute a
  where a.attrelid = 'public.etablissements'::regclass and a.attnum > 0 and not a.attisdropped;
  execute 'REVOKE ALL ON TABLE public.etablissements FROM PUBLIC, anon, authenticated';
  execute format('REVOKE ALL (%s) ON TABLE public.etablissements FROM PUBLIC, anon, authenticated', v_cols);

  if exists (select 1 from unnest(array['anon', 'authenticated']) as r(role),
                           unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER']) as p(p)
             where has_table_privilege(r.role, 'public.etablissements', p.p))
     or exists (select 1 from unnest(array['anon', 'authenticated']) as r(role)
                where has_any_column_privilege(r.role, 'public.etablissements', 'SELECT, INSERT, UPDATE, REFERENCES')) then
    raise exception 'ÉCHEC droits : la clé publique garde un droit sur etablissements (accordé par un autre rôle ?) : rien n''est modifié.';
  end if;
  raise notice 'Installation : plus aucun droit direct de anon / authenticated / PUBLIC sur etablissements';
end $migration$;


-- ############################################################
-- CONTRÔLE FINAL (dernière instruction : toutes les lignes = true)
-- ############################################################
with roles as (select unnest(array['anon', 'authenticated']) as role),
cols as (select a.attname from pg_attribute a
         where a.attrelid = 'public.etablissements'::regclass and a.attnum > 0 and not a.attisdropped),
f as (select p.oid, p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.oid in (to_regprocedure('public.list_etablissements()'),
                      to_regprocedure('public.admin_lister_codes_v2(text)'),
                      to_regprocedure('public.etablissement_claim_v2(text,text,text,text,text,text,text,text,text,text)'),
                      to_regprocedure('public.etablissement_register(text,text,text,text,text,text,text,text,text,text,text,jsonb,jsonb,text,text,text,text,text,text,text,text)'),
                      to_regprocedure('public.etablissement_verifier_doublon(text)'),
                      to_regprocedure('public.etablissement_session_open(text,text)'),
                      to_regprocedure('public.etablissement_get_own_v2(text)')))
select n, controle, ok from (
  select 1 as n, 'aucun droit de TABLE (SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER) pour anon / authenticated' as controle,
         not exists (select 1 from roles, unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER']) as p(p)
                     where has_table_privilege(roles.role, 'public.etablissements', p.p)) as ok
  union all select 2, 'aucun droit de COLONNE (email, tel, password, code_recuperation... compris) pour anon / authenticated',
         not exists (select 1 from roles, cols, unnest(array['SELECT', 'INSERT', 'UPDATE', 'REFERENCES']) as p(p)
                     where has_column_privilege(roles.role, 'public.etablissements', cols.attname, p.p))
  union all select 3, 'aucun droit accordé à PUBLIC (table ou colonne)',
         not exists (select 1 from pg_class c, aclexplode(c.relacl) a where c.oid = 'public.etablissements'::regclass and a.grantee = 0)
         and not exists (select 1 from pg_attribute att, aclexplode(att.attacl) a
                         where att.attrelid = 'public.etablissements'::regclass and att.attnum > 0 and a.grantee = 0)
  union all select 4, 'les 7 RPC du front (liste, codes admin, inscription, doublon, réclamation, connexion, fiche perso) : présentes, SECURITY DEFINER, exécutables par anon',
         (select count(*) = 7 and bool_and(p.prosecdef and has_function_privilege('anon', f.oid, 'EXECUTE'))
            from f join pg_proc p on p.oid = f.oid)
  union all select 5, 'aucune fonction SECURITY INVOKER appelable par la clé publique ne lit etablissements',
         not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                     where n.nspname = 'public' and not p.prosecdef and p.prosrc ~ '\metablissements\M'
                       and (has_function_privilege('anon', p.oid, 'EXECUTE') or has_function_privilege('authenticated', p.oid, 'EXECUTE')))
  union all select 6, 'données inchangées : 4 171 fiches, 1 réclamée, aucune trace de test',
         (select count(*) = 4171 from public.etablissements)
         and (select count(*) = 1 from public.etablissements e where coalesce(e.reclame, false))
         and not exists (select 1 from public.etablissements e where e.id like 'test\_fuite\_%')
         and not exists (select 1 from public.admins a where a.id = 'test_fuite_adm')
         and not exists (select 1 from public.demandes_inscription_etablissements d where lower(d.email) = 'insc-fuite@exemple.invalid')
) t
order by n;
