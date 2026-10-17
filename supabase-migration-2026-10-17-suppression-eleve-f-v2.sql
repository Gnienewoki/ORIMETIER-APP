-- ============================================================
-- ORIMETIER — Suppression du compte élève : ÉTAPE f (IRRÉVERSIBLE) — version 2
-- v2 : le garde-fou e) n'est plus bloqué par les valeurs par défaut de colonnes
-- (pg_attrdef), l'appartenance à supabase_realtime (pg_publication_rel) ni les
-- statistiques étendues (pg_statistic_ext). Tout le reste est identique à la v1.
-- Supprime les tables eleves et notes. AUCUNE archive (décision prise : les comptes
-- existants et le résultat RIASEC partent sans sauvegarde).
-- Une seule transaction : si le bloc de garde ou une instruction échoue, rien n'est supprimé.
--
-- Pré-requis : étapes d et e exécutées et contrôlées (le bloc de garde le vérifie).
--
-- Partent avec chaque table (DROP TABLE, sans CASCADE) : ses index, ses contraintes,
-- ses triggers (dont trg_hash_password sur eleves), ses policies, ses droits.
-- RESTENT : la fonction hash_password_trigger() (partagée par inspecteurs,
-- etablissements et demandes_inscription_etablissements), les tables sessions,
-- password_resets, suivi_eleves, suivi_eleves_notes (suivi privé de l'inspecteur).
--
-- Publication realtime : eleves et notes en sont retirées explicitement avant le DROP
-- (le DROP le ferait de toute façon ; le retrait explicite rend l'opération visible).
--
-- Pas de CASCADE : si un objet imprévu dépend encore d'une table, le DROP échoue
-- plutôt que de le supprimer en silence. Le bloc de garde en donne la liste avant.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 0) Bloc de garde : échoue si l'étape e n'est pas faite ou si une dépendance imprévue existe
-- ------------------------------------------------------------
DO $$
declare
  v_eleves oid := to_regclass('public.eleves');
  v_notes  oid := to_regclass('public.notes');
  v_liste  text;
begin
  if v_eleves is null and v_notes is null then
    raise exception 'Tables eleves et notes déjà absentes : étape f déjà faite';
  end if;

  -- a) Étape e faite : fonctions élève supprimées, plus de rôle 'eleve' en base.
  if to_regprocedure('public.list_eleves()') is not null
     or to_regprocedure('public.eleve_session_open(text,text)') is not null
     or to_regprocedure('public.eleve_save_riasec(text,jsonb)') is not null
     or to_regprocedure('public.eleve_update_email(text,text)') is not null
     or to_regprocedure('public.admin_set_eleve_banni_v2(text,text,boolean)') is not null then
    raise exception 'Étape e non exécutée : des fonctions élève existent encore';
  end if;
  if exists (select 1 from public.sessions where role = 'eleve')
     or exists (select 1 from public.password_resets where role = 'eleve') then
    raise exception 'Étape e incomplète : il reste des lignes de rôle eleve dans sessions ou password_resets';
  end if;

  -- b) Clés étrangères imprévues : vers eleves (autre que depuis notes), ou vers notes.
  select string_agg(con.conrelid::regclass::text || '.' || con.conname || ' -> ' || con.confrelid::regclass::text, ', ')
    into v_liste
  from pg_constraint con
  where con.contype = 'f'
    and (   (v_eleves is not null and con.confrelid = v_eleves and con.conrelid is distinct from v_notes)
         or (v_notes  is not null and con.confrelid = v_notes  and con.conrelid <> v_notes));
  if v_liste is not null then
    raise exception 'Clés étrangères imprévues : % — me les envoyer, rien n''est supprimé', v_liste;
  end if;

  -- c) Vues (règles de réécriture) qui dépendent de eleves ou notes.
  select string_agg(distinct r.ev_class::regclass::text, ', ') into v_liste
  from pg_depend d
  join pg_rewrite r on d.classid = 'pg_rewrite'::regclass and d.objid = r.oid
  where d.refclassid = 'pg_class'::regclass
    and d.refobjid in (coalesce(v_eleves, 0::oid), coalesce(v_notes, 0::oid))
    and r.ev_class not in (coalesce(v_eleves, 0::oid), coalesce(v_notes, 0::oid));
  if v_liste is not null then
    raise exception 'Vues qui dépendent de eleves/notes : % — me les envoyer, rien n''est supprimé', v_liste;
  end if;

  -- d) Fonctions dont le corps lit/écrit encore eleves ou notes.
  select string_agg(p.oid::regprocedure::text, ', ') into v_liste
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prosrc ~* '(from|join|into|update|table)\s+(public\.)?(eleves|notes)\M';
  if v_liste is not null then
    raise exception 'Fonctions qui utilisent encore eleves/notes : % — me les envoyer, rien n''est supprimé', v_liste;
  end if;

  -- e) Toute autre dépendance (pg_depend) que les composants propres des tables
  --    (contraintes, triggers, policies, type ligne, index, séquences, TOAST, règles,
  --    valeurs par défaut des colonnes, statistiques étendues) et que l'appartenance à
  --    une publication (pg_publication_rel : retirée à l'étape 1 ci-dessous).
  select string_agg(pg_describe_object(d.classid, d.objid, d.objsubid) || ' (deptype ' || d.deptype::text || ')', ', ')
    into v_liste
  from pg_depend d
  where d.refclassid = 'pg_class'::regclass
    and d.refobjid in (coalesce(v_eleves, 0::oid), coalesce(v_notes, 0::oid))
    and d.classid not in ('pg_constraint'::regclass, 'pg_trigger'::regclass, 'pg_policy'::regclass,
                          'pg_type'::regclass, 'pg_rewrite'::regclass,
                          'pg_attrdef'::regclass, 'pg_publication_rel'::regclass,
                          'pg_statistic_ext'::regclass)
    and not (d.classid = 'pg_class'::regclass
             and (d.objid in (coalesce(v_eleves, 0::oid), coalesce(v_notes, 0::oid))
                  or exists (select 1 from pg_class c where c.oid = d.objid and c.relkind in ('i', 'S', 't'))));
  if v_liste is not null then
    raise exception 'Dépendances imprévues : % — me les envoyer, rien n''est supprimé', v_liste;
  end if;
end $$;

-- ------------------------------------------------------------
-- 1) Retrait des publications (realtime), si présentes
-- ------------------------------------------------------------
DO $$
declare
  r record;
begin
  for r in
    select pt.pubname, pt.tablename
    from pg_publication_tables pt
    where pt.schemaname = 'public' and pt.tablename in ('eleves', 'notes')
  loop
    execute format('ALTER PUBLICATION %I DROP TABLE public.%I', r.pubname, r.tablename);
  end loop;
end $$;

-- ------------------------------------------------------------
-- 2) Suppression des tables (notes d'abord : elle peut référencer eleves)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS public.notes;
DROP TABLE public.eleves;

-- ------------------------------------------------------------
-- 3) Vérification avant COMMIT
-- ------------------------------------------------------------
DO $$
begin
  if to_regclass('public.eleves') is not null or to_regclass('public.notes') is not null then
    raise exception 'Une table élève existe encore après DROP';
  end if;
  if to_regprocedure('public.hash_password_trigger()') is null then
    raise exception 'hash_password_trigger a disparu : elle doit rester (inspecteurs, établissements, demandes)';
  end if;
end $$;

COMMIT;

-- Contrôle : voir supabase-migration-2026-10-17-suppression-eleve-controle.sql, requête « APRÈS f ».
