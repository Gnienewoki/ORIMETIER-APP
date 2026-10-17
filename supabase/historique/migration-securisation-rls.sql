-- Migration : sécurisation des policies RLS trop permissives
-- Contexte : 6 tables avaient une policy "ALL / true / true" ouverte à tout
-- le rôle public, permettant lecture/écriture/suppression libres via l'API
-- REST Supabase, sans passer par le site ni les fonctions RPC.
--
-- Diagnostic Claude Code (2026-09-16) : seuls 3 accès directs .from() existent
-- dans le frontend : eleves (insert), inspecteurs (insert), notes (select).
-- etablissements, admin_config et activation_codes ne sont jamais accédés
-- directement côté JS (tout passe par des fonctions RPC SECURITY DEFINER,
-- qui continueront de fonctionner après cette migration).
--
-- À REVOIR PUIS EXÉCUTER MANUELLEMENT dans le SQL Editor Supabase.

-- 1. etablissements : aucun accès direct nécessaire (tout passe par RPC)
drop policy if exists "public access etablissements" on public.etablissements;

-- 2. eleves : seul l'insert (inscription élève) est utilisé en direct
drop policy if exists "public access eleves" on public.eleves;
create policy "insertion inscription eleve"
  on public.eleves
  for insert
  to public
  with check (true);

-- 3. inspecteurs : seul l'insert (inscription inspecteur) est utilisé en direct
drop policy if exists "public access inspecteurs" on public.inspecteurs;
create policy "insertion inscription inspecteur"
  on public.inspecteurs
  for insert
  to public
  with check (true);

-- 4. admin_config : jamais référencé côté JS, tout passe par RPC/SQL admin
drop policy if exists "public access admin_config" on public.admin_config;

-- 5. activation_codes : jamais référencé côté JS, tout passe par RPC/SQL admin
drop policy if exists "public access activation_codes" on public.activation_codes;

-- 6. notes : seul le select (chargement) est utilisé en direct
drop policy if exists "public access notes" on public.notes;
create policy "lecture notes"
  on public.notes
  for select
  to public
  using (true);

-- Vérification après exécution : relancer la requête de policies
-- (select * from pg_policies where schemaname = 'public') et confirmer
-- qu'aucune des 6 tables n'a plus de policy "ALL / true / true".
