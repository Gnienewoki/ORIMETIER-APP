-- ============================================================
-- ORIMETIER — Phase 5a-0 : table admins (comptes administrateur nominatifs).
--
-- Remplacera à terme admin_config (une seule ligne, mot de passe partagé
-- sans identité). Cette migration est ADDITIVE : aucune fonction admin
-- existante n'est modifiée, admin_config reste en service pour les
-- anciennes RPC (p_admin_password) jusqu'au nettoyage 5c.
--
--   1) public.admins        : id, nom, email, password (bcrypt), actif,
--                              created_at, last_login_at, password_changed_at.
--                              Même modèle de sécurité que sessions : RLS
--                              sans policy, aucun droit anon/authenticated,
--                              accès uniquement via fonctions SECURITY DEFINER.
--                              Hachage par le trigger générique existant
--                              hash_password_trigger() (comme eleves,
--                              inspecteurs, etablissements) + CHECK qui
--                              refuse tout mot de passe non bcrypt.
--                              Aucune valeur par défaut pour password.
--   2) Reprise du compte    : copie du hash bcrypt de admin_config (id = 1)
--                              vers admins -> le mot de passe actuel reste
--                              valable, rien n'est re-haché.
--   3) sessions.role        : ajout de 'admin' au CHECK (diagnostic 5-0 :
--                              la contrainte live n'accepte que eleve,
--                              inspecteur, etablissement).
--   4) admin_config         : suppression du défaut 'admin2024' en clair.
--   5) search_path          : admin_delete_etablissement et
--                              admin_update_etab_classification n'avaient pas
--                              de SET search_path (diagnostic 5-0) -> ajouté
--                              par ALTER FUNCTION, corps inchangé.
--
-- NON inclus (5a-1, après lecture de la définition LIVE de _session_user) :
-- branche 'admin' de _session_user, admin_session_open, trigger de
-- révocation des sessions au changement de mot de passe / désactivation.
-- Tant que 5a-1 n'est pas exécuté, aucune session admin ne peut être créée.
--
-- RÈGLE DE TRANSITION : entre cette migration et le nettoyage 5c, le mot de
-- passe admin existe à DEUX endroits (admin_config pour les anciennes RPC,
-- admins pour les nouvelles). Ne pas le changer pendant cette période, ou
-- le changer dans les deux tables.
--
-- À exécuter en une fois dans l'éditeur SQL de Supabase. En cas d'erreur,
-- la transaction entière est annulée (rien n'est modifié).
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1) Table admins
-- ------------------------------------------------------------
-- CREATE TABLE sans IF NOT EXISTS volontairement : diagnostic 5-0 (4)
-- table_admins = null ; si elle existait, le script échoue sans rien modifier.
CREATE TABLE public.admins (
  id text PRIMARY KEY,
  nom text NOT NULL CHECK (nullif(trim(nom), '') IS NOT NULL),
  email text NOT NULL CHECK (nullif(trim(email), '') IS NOT NULL),
  password text NOT NULL,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  last_login_at timestamptz,
  password_changed_at timestamptz NOT NULL DEFAULT now(),
  -- Les CHECK sont évalués APRÈS les triggers BEFORE : un mot de passe en
  -- clair est d'abord haché par trg_hash_password ; tout ce qui n'est pas un
  -- hash bcrypt (ex. chaîne vide, que le trigger ne hache pas) est refusé.
  CONSTRAINT admins_password_bcrypt CHECK (password ~ '^\$2[aby]\$')
);
COMMENT ON TABLE public.admins IS 'Comptes administrateur nominatifs. Accès uniquement via fonctions SECURITY DEFINER ; jamais de GRANT à anon/authenticated, jamais dans la publication realtime. Ajout/réinitialisation : SQL Editor uniquement';
COMMENT ON COLUMN public.admins.password IS 'Hash bcrypt (trigger trg_hash_password). Réinitialiser : UPDATE admins SET password = ''nouveau'' WHERE id = ... (le trigger hache)';
COMMENT ON COLUMN public.admins.actif IS 'false = compte désactivé : connexion refusée (révocation des sessions en 5a-1)';

-- Unicité de l'e-mail, insensible casse/espaces (même règle que Phase 3).
CREATE UNIQUE INDEX admins_email_unique ON public.admins (lower(trim(email)));

-- Hachage : même trigger générique que eleves / inspecteurs / etablissements.
CREATE TRIGGER trg_hash_password
  BEFORE INSERT OR UPDATE OF password ON public.admins
  FOR EACH ROW EXECUTE FUNCTION hash_password_trigger();

ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.admins FROM public, anon, authenticated;

-- ------------------------------------------------------------
-- 2) Reprise du compte existant depuis admin_config
-- ------------------------------------------------------------
-- >>> À VÉRIFIER AVANT EXÉCUTION : id, nom et e-mail de connexion. <<<
-- Le hash est recopié tel quel (déjà bcrypt : diagnostic 5-0 (3)), le
-- trigger ne le re-hache pas. Échec explicite (migration entière annulée) si
-- aucune ligne n'est reprise, ou si le hash stocké diffère de l'original.
DO $$
declare
  v_source_hash text;
  v_stored_hash text;
begin
  select ac.admin_password into v_source_hash
  from public.admin_config ac
  where ac.id = 1 and ac.admin_password ~ '^\$2[aby]\$';

  if not found then
    raise exception 'Reprise admin_config -> admins : aucune ligne id = 1 avec un hash bcrypt dans admin_config';
  end if;

  -- RETURNING renvoie la valeur réellement stockée, APRÈS les triggers BEFORE
  -- (dont trg_hash_password).
  insert into public.admins(id, nom, email, password)
  values ('adm_gnienewoki',          -- id
          'Gnienewoki',              -- nom
          'gnienewoki@gmail.com',    -- e-mail de connexion
          v_source_hash)
  returning password into v_stored_hash;

  -- Garde-fou : le hash stocké doit être EXACTEMENT celui de admin_config
  -- (aucun re-hachage par trg_hash_password).
  if v_stored_hash is distinct from v_source_hash then
    raise exception 'Reprise admin_config -> admins : le hash stocké diffère de celui de admin_config (re-hachage ?), migration annulée';
  end if;
end $$;

-- ------------------------------------------------------------
-- 3) sessions.role : ajout de 'admin'
-- ------------------------------------------------------------
-- Le nom de la contrainte live n'est pas connu avec certitude : on retrouve
-- l'unique CHECK portant sur role (l'autre CHECK de la table porte sur
-- expires_at) et on échoue si on n'en trouve pas exactement une.
DO $$
declare
  v_names text[];
begin
  select array_agg(c.conname) into v_names
  from pg_constraint c
  where c.conrelid = 'public.sessions'::regclass
    and c.contype = 'c'
    and pg_get_constraintdef(c.oid) ilike '%role%';

  if coalesce(array_length(v_names, 1), 0) <> 1 then
    raise exception 'CHECK sur sessions.role : % contrainte(s) trouvée(s), 1 attendue',
      coalesce(array_length(v_names, 1), 0);
  end if;

  execute format('alter table public.sessions drop constraint %I', v_names[1]);
end $$;

ALTER TABLE public.sessions
  ADD CONSTRAINT sessions_role_check
  CHECK (role IN ('eleve', 'inspecteur', 'etablissement', 'admin'));

COMMENT ON COLUMN public.sessions.user_id IS 'id de eleves / inspecteurs / etablissements / admins selon role';

-- ------------------------------------------------------------
-- 4) admin_config : plus de mot de passe par défaut en clair
-- ------------------------------------------------------------
ALTER TABLE public.admin_config ALTER COLUMN admin_password DROP DEFAULT;

-- ------------------------------------------------------------
-- 5) search_path manquant sur deux anciennes fonctions admin
-- ------------------------------------------------------------
-- Corps inchangé ; elles seront remplacées en 5a-3 et supprimées en 5c.
ALTER FUNCTION public.admin_delete_etablissement(text, text) SET search_path TO 'public';
ALTER FUNCTION public.admin_update_etab_classification(text, text, text, text, text) SET search_path TO 'public';

COMMIT;

-- ============================================================
-- VÉRIFICATIONS (à lancer après exécution, une requête à la fois)
-- ============================================================
--
-- V1. Colonnes de admins (8 lignes ; aucun column_default sur password)
-- select column_name, data_type, is_nullable, column_default
-- from information_schema.columns
-- where table_schema = 'public' and table_name = 'admins'
-- order by ordinal_position;
--
-- V2. RLS activé, aucune policy, aucun droit public (rls = true, nb_policies = 0, droits_publics = null)
-- select c.relrowsecurity as rls,
--        (select count(*) from pg_policies p where p.schemaname = 'public' and p.tablename = 'admins') as nb_policies,
--        (select string_agg(grantee || ':' || privilege_type, ', ')
--           from information_schema.role_table_grants g
--          where g.table_schema = 'public' and g.table_name = 'admins'
--            and g.grantee in ('anon', 'authenticated', 'PUBLIC')) as droits_publics
-- from pg_class c where c.oid = 'public.admins'::regclass;
--
-- V3. Pas dans la publication realtime (0 ligne attendue)
-- select * from pg_publication_tables where schemaname = 'public' and tablename = 'admins';
--
-- V4. Index et trigger (admins_pkey, admins_email_unique ; trg_hash_password)
-- select indexname, indexdef from pg_indexes where schemaname = 'public' and tablename = 'admins';
-- select tgname, pg_get_triggerdef(t.oid) from pg_trigger t
-- where t.tgrelid = 'public.admins'::regclass and not t.tgisinternal;
--
-- V5. Compte repris, hash identique à admin_config (1 ligne, meme_hash = true, actif = true)
-- select a.id, a.nom, a.email, a.actif,
--        a.password ~ '^\$2[aby]\$' as hash_bcrypt,
--        a.password = ac.admin_password as meme_hash
-- from public.admins a cross join public.admin_config ac where ac.id = 1;
--
-- V6. CHECK de sessions.role (doit contenir 'admin')
-- select conname, pg_get_constraintdef(c.oid) from pg_constraint c
-- where c.conrelid = 'public.sessions'::regclass and c.contype = 'c';
--
-- V7. Défaut 'admin2024' supprimé (column_default = null)
-- select column_name, column_default from information_schema.columns
-- where table_schema = 'public' and table_name = 'admin_config' and column_name = 'admin_password';
--
-- V8. search_path des deux fonctions corrigées (config = {search_path=public})
-- select p.oid::regprocedure, p.proconfig as config
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public' and p.proname in ('admin_delete_etablissement', 'admin_update_etab_classification');
--
-- V9. Test SANS trace (ROLLBACK final) : un mot de passe en clair est haché,
--     une chaîne vide est refusée. Sélectionner et exécuter le bloc entier.
-- begin;
-- insert into public.admins(id, nom, email, password) values ('adm_test', 'Test', 'test-5a0@exemple.invalid', 'motdepasse-test');
-- select id, password ~ '^\$2[aby]\$' as hash_bcrypt,
--        password = extensions.crypt('motdepasse-test', password) as verifie
-- from public.admins where id = 'adm_test';                       -- hash_bcrypt = true, verifie = true
-- rollback;
--
-- V10. Chaîne vide refusée (erreur attendue : violation de admins_password_bcrypt ; ROLLBACK implicite)
-- begin;
-- insert into public.admins(id, nom, email, password) values ('adm_test', 'Test', 'test-5a0@exemple.invalid', '');
-- rollback;
--
-- V11. Clé publique sans accès (erreur attendue "permission denied")
-- begin; set local role anon; select * from public.admins; rollback;
