-- ============================================================
-- ORIMETIER — Lot ministère : ÉTAPE 0 = SAUVEGARDE de la table etablissements.
-- Copie complète dans public.etablissements_sauvegarde_20261114 (protégée : RLS active, aucun droit anon/authenticated).
-- GARDE : la sauvegarde existe déjà -> arrêt, rien n'est créé.
-- Fichier à lancer EN ENTIER, sans rien sélectionner. Puis la requête de vérification (tout true).
-- ============================================================

DO $sauvegarde$
declare v_n integer; v_c integer;
begin
  if to_regclass('public.etablissements_sauvegarde_20261114') is not null then
    raise exception 'GARDE : la sauvegarde existe déjà : rien n''est modifié.';
  end if;
  select count(*) into v_n from public.etablissements;
  create table public.etablissements_sauvegarde_20261114 as table public.etablissements;
  alter table public.etablissements_sauvegarde_20261114 enable row level security;
  revoke all on table public.etablissements_sauvegarde_20261114 from public, anon, authenticated;
  select count(*) into v_c from public.etablissements_sauvegarde_20261114;
  if v_c is distinct from v_n then raise exception 'ÉCHEC : % fiches copiées au lieu de % : tout est annulé.', v_c, v_n; end if;
  if has_table_privilege('anon','public.etablissements_sauvegarde_20261114','SELECT') or has_table_privilege('authenticated','public.etablissements_sauvegarde_20261114','SELECT') then
    raise exception 'ÉCHEC : la sauvegarde est lisible par l''API publique : tout est annulé.';
  end if;
  raise notice 'Sauvegarde créée : % fiches.', v_c;
end;
$sauvegarde$;

select n, controle, ok from (
  select 1 as n, 'copie = original, même nombre de fiches' as controle,
    (select count(*) from public.etablissements_sauvegarde_20261114) = (select count(*) from public.etablissements) as ok
  union all select 2, 'copie identique à l''original',
    (select count(*) = 0 from (select * from public.etablissements except select * from public.etablissements_sauvegarde_20261114) d)
    and (select count(*) = 0 from (select * from public.etablissements_sauvegarde_20261114 except select * from public.etablissements) d)
  union all select 3, 'RLS active', (select relrowsecurity from pg_class where oid='public.etablissements_sauvegarde_20261114'::regclass)
  union all select 4, 'aucun accès anon / authenticated',
    not has_table_privilege('anon','public.etablissements_sauvegarde_20261114','SELECT, INSERT, UPDATE, DELETE')
    and not has_table_privilege('authenticated','public.etablissements_sauvegarde_20261114','SELECT, INSERT, UPDATE, DELETE')
) t order by n;
