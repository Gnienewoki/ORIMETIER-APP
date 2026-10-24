-- ============================================================
-- ORIMETIER — RETOUR ARRIÈRE de la suppression des 8 doublons « technique » (à ne lancer qu'en cas de besoin).
-- Réinsère les 8 fiches telles qu'elles étaient dans etablissements_sauvegarde_20261024 (elles n'avaient pas été reclassées).
-- GARDE : 4 175 fiches, et aucune des 8 n'existe déjà.
-- ============================================================
DO $retour$
declare v_n integer;
begin
  if (select count(*) from public.etablissements) <> 4175 then raise exception 'GARDE : nombre de fiches inattendu : rien n''est modifié.'; end if;
  if exists (select 1 from public.etablissements where id in ('id178646268339127307', 'id178646268368603358', 'id178646268340579101', 'id178646268367363118', 'id178646243145918387', 'id178646243147211885', 'id178646268355758208', 'id178646268360510187')) then raise exception 'GARDE : une fiche existe déjà : rien n''est modifié.'; end if;
  insert into public.etablissements select * from public.etablissements_sauvegarde_20261024 where id in ('id178646268339127307', 'id178646268368603358', 'id178646268340579101', 'id178646268367363118', 'id178646243145918387', 'id178646243147211885', 'id178646268355758208', 'id178646268360510187');
  get diagnostics v_n = row_count;
  if v_n <> 8 then raise exception 'ÉCHEC : % fiches réinsérées au lieu de 8 : tout est annulé.', v_n; end if;
  raise notice 'Retour arrière terminé : 8 fiches réinsérées (4 183 fiches).';
end;
$retour$;
select count(*) as nb_fiches from public.etablissements;
