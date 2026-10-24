-- ============================================================
-- ORIMETIER — Import des filières (ministère) : ÉTAPE 0 = SAUVEGARDE de la table etablissements.
--
-- Copie complète (toutes les colonnes, toutes les fiches) dans public.etablissements_sauvegarde_20261023.
-- La copie contient des mots de passe (hachés), e-mails, téléphones : elle est PROTÉGÉE
-- (RLS active, aucun droit pour public / anon / authenticated). Seuls les rôles d'administration
-- de la base (SQL Editor) peuvent la lire.
--
-- GARDES (arrêt, rien n'est créé) : la sauvegarde existe déjà ; la base n'a pas 4 171 fiches.
-- Fichier à lancer EN ENTIER, sans rien sélectionner. Puis la requête de vérification (tout true).
--
-- RETOUR ARRIÈRE de cette étape : drop table public.etablissements_sauvegarde_20261023;
-- (ne le faire qu'une fois l'import terminé et contrôlé : la sauvegarde sert au retour arrière de l'import).
-- ============================================================

DO $sauvegarde$
declare
  v_n integer; v_c integer;
begin
  if to_regclass('public.etablissements_sauvegarde_20261023') is not null then
    raise exception 'GARDE : la sauvegarde existe déjà : rien n''est modifié.';
  end if;
  select count(*) into v_n from public.etablissements;
  if v_n is distinct from 4171 then
    raise exception 'GARDE : % fiches au lieu de 4 171 : rien n''est modifié.', v_n;
  end if;

  create table public.etablissements_sauvegarde_20261023 as table public.etablissements;
  alter table public.etablissements_sauvegarde_20261023 enable row level security;
  revoke all on table public.etablissements_sauvegarde_20261023 from public, anon, authenticated;

  select count(*) into v_c from public.etablissements_sauvegarde_20261023;
  if v_c is distinct from v_n then
    raise exception 'ÉCHEC : % fiches copiées au lieu de % : tout est annulé.', v_c, v_n;
  end if;
  if has_table_privilege('anon', 'public.etablissements_sauvegarde_20261023', 'SELECT')
     or has_table_privilege('authenticated', 'public.etablissements_sauvegarde_20261023', 'SELECT') then
    raise exception 'ÉCHEC : la sauvegarde est lisible par l''API publique : tout est annulé.';
  end if;
  raise notice 'Sauvegarde créée : % fiches.', v_c;
end;
$sauvegarde$;

-- Vérification : attendu 4 lignes, ok = true partout
select n, controle, ok from (
  select 1 as n, '4 171 fiches copiées' as controle,
         (select count(*) = 4171 from public.etablissements_sauvegarde_20261023) as ok
  union all select 2, 'copie identique à l''original (aucune différence)',
         (select count(*) = 0 from (select * from public.etablissements except select * from public.etablissements_sauvegarde_20261023) d)
         and (select count(*) = 0 from (select * from public.etablissements_sauvegarde_20261023 except select * from public.etablissements) d)
  union all select 3, 'RLS active sur la sauvegarde',
         (select relrowsecurity from pg_class where oid = 'public.etablissements_sauvegarde_20261023'::regclass)
  union all select 4, 'aucun accès pour anon / authenticated',
         not has_table_privilege('anon', 'public.etablissements_sauvegarde_20261023', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
         and not has_table_privilege('authenticated', 'public.etablissements_sauvegarde_20261023', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
) t
order by n;
