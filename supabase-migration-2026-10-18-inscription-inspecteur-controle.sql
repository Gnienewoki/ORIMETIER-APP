-- ============================================================
-- ORIMETIER — Inscription inspecteur durcie : CONTRÔLES (LECTURE SEULE).
-- Deux requêtes indépendantes : lancer la 1 après A, la 2 après B (sélectionner la requête
-- voulue dans le SQL Editor, ou lancer le fichier entier : seul le dernier résultat s'affiche).
-- Format de date_inscription supposé : JJ/MM/AAAA (espDate, fr-FR) ; les autres formats sont
-- ignorés dans le comptage, jamais convertis de force.
-- ============================================================

-- ------------------------------------------------------------
-- 1) APRÈS A — attendu (toutes les lignes) : ok = true
-- ------------------------------------------------------------
with f as (select to_regprocedure('public.inspecteur_register(text,text,text,text,text,text,text,text,text)') as oid)
select n, controle, ok from (
  select 1 as n, 'inspecteur_register présente' as controle, (select oid from f) is not null as ok
  union all select 2, 'SECURITY DEFINER', coalesce((select p.prosecdef from pg_proc p where p.oid = (select oid from f)), false)
  union all select 3, 'search_path = public', coalesce((select 'search_path=public' = any(p.proconfig) from pg_proc p where p.oid = (select oid from f)), false)
  union all select 4, 'retour jsonb', coalesce((select pg_get_function_result(p.oid) = 'jsonb' from pg_proc p where p.oid = (select oid from f)), false)
  union all select 5, 'EXECUTE anon', (select oid from f) is not null and has_function_privilege('anon', (select oid from f), 'EXECUTE')
  union all select 6, 'EXECUTE authenticated', (select oid from f) is not null and has_function_privilege('authenticated', (select oid from f), 'EXECUTE')
  union all select 7, 'aucun EXECUTE pour PUBLIC', (select oid from f) is not null and not exists (
      select 1 from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
      where p.oid = (select oid from f) and a.grantee = 0 and a.privilege_type = 'EXECUTE')
  union all select 8, 'une seule surcharge inspecteur_register', (select count(*) = 1 from pg_proc p join pg_namespace s on s.oid = p.pronamespace
      where s.nspname = 'public' and p.proname = 'inspecteur_register')
  union all select 9, 'corps : impose certifie/banni/certification_demandee = false',
      coalesce((select position('true, false, false, false' in pg_get_functiondef(p.oid)) > 0 from pg_proc p where p.oid = (select oid from f)), false)
  union all select 10, 'corps : refuse ^\$2[aby]\$',
      coalesce((select position('^\$2[aby]\$' in pg_get_functiondef(p.oid)) > 0 from pg_proc p where p.oid = (select oid from f)), false)
  -- A est additive : le trou est TOUJOURS ouvert à ce stade (attendu true ici, false après B)
  union all select 11, 'INSERT direct anon encore ouvert (normal avant B)', has_any_column_privilege('anon', 'public.inspecteurs', 'INSERT')
  union all select 12, 'policy « insertion inscription inspecteur » encore là (normal avant B)',
      exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = 'inspecteurs' and p.policyname = 'insertion inscription inspecteur')
) t order by n;

-- ------------------------------------------------------------
-- 2) APRÈS B — attendu (toutes les lignes) : ok = true
-- ------------------------------------------------------------
with f as (select to_regprocedure('public.inspecteur_register(text,text,text,text,text,text,text,text,text)') as oid)
select n, controle, ok from (
  select 1 as n, 'inspecteur_register toujours présente' as controle, (select oid from f) is not null as ok
  union all select 2, 'EXECUTE anon toujours accordé', (select oid from f) is not null and has_function_privilege('anon', (select oid from f), 'EXECUTE')
  union all select 3, 'plus d''INSERT pour anon', not has_any_column_privilege('anon', 'public.inspecteurs', 'INSERT')
  union all select 4, 'plus d''INSERT pour authenticated', not has_any_column_privilege('authenticated', 'public.inspecteurs', 'INSERT')
  union all select 5, 'aucun INSERT pour PUBLIC', not exists (
      select 1 from pg_class c, aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
      where c.oid = 'public.inspecteurs'::regclass and a.grantee = 0 and a.privilege_type = 'INSERT')
  union all select 6, 'policy « insertion inscription inspecteur » supprimée',
      not exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = 'inspecteurs' and p.policyname = 'insertion inscription inspecteur')
  union all select 7, 'aucune autre policy INSERT / ALL sur inspecteurs',
      not exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = 'inspecteurs' and p.cmd in ('INSERT', 'ALL'))
  union all select 8, 'RLS toujours activée', (select c.relrowsecurity from pg_class c where c.oid = 'public.inspecteurs'::regclass)
  union all select 9, 'trg_hash_password toujours là', exists (select 1 from pg_trigger t where t.tgrelid = 'public.inspecteurs'::regclass and t.tgname = 'trg_hash_password')
  union all select 10, 'aucun mot de passe inspecteur en clair', not exists (
      select 1 from public.inspecteurs i where coalesce(i.password, '') <> '' and i.password !~ '^\$2[aby]\$')
  -- Comptes inscrits depuis le 18/10/2026 : aucun ne doit être certifié / banni / en demande
  -- dès l'inscription (un compte certifié depuis par l'admin rendrait cette ligne false :
  -- vérifier alors à la main qu'il s'agit bien d'une certification admin).
  union all select 11, 'inscrits depuis le 18/10/2026 : ni certifiés, ni bannis, ni en demande', not exists (
      select 1 from public.inspecteurs i
      -- CASE : to_date n'est jamais appelé sur une date d'un autre format (pas d'ordre garanti dans un AND)
      where (case when i.date_inscription ~ '^\d{2}/\d{2}/\d{4}$' then to_date(i.date_inscription, 'DD/MM/YYYY') end) >= date '2026-10-18'
        and (i.certifie is true or i.banni is true or i.certification_demandee is true))
) t order by n;
