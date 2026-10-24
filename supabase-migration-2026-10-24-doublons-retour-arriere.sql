-- ============================================================
-- ORIMETIER — RETOUR ARRIÈRE de la suppression des 5 doublons (à ne lancer qu'en cas de besoin).
-- Réinsère les 5 anciennes fiches telles qu'elles étaient dans etablissements_sauvegarde_20261024.
-- GARDE : 4 183 fiches, et aucune des 5 n'existe déjà.
-- ============================================================
DO $retour$
declare v_n integer;
begin
  if (select count(*) from public.etablissements) <> 4183 then raise exception 'GARDE : nombre de fiches inattendu : rien n''est modifié.'; end if;
  if exists (select 1 from public.etablissements where id in ('id1786376293534210', 'id17863762935496775', 'id1786376350137840677', 'id1786376350154671375', 'id1786376350163722763')) then raise exception 'GARDE : une fiche existe déjà : rien n''est modifié.'; end if;
  insert into public.etablissements select * from public.etablissements_sauvegarde_20261024 where id in ('id1786376293534210', 'id17863762935496775', 'id1786376350137840677', 'id1786376350154671375', 'id1786376350163722763');
  get diagnostics v_n = row_count;
  if v_n <> 5 then raise exception 'ÉCHEC : % fiches réinsérées au lieu de 5 : tout est annulé.', v_n; end if;
  raise notice 'Retour arrière terminé : 5 fiches réinsérées (4 188 fiches).';
end;
$retour$;
select count(*) as nb_fiches from public.etablissements;
