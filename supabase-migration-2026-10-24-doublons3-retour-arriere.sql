-- ============================================================
-- ORIMETIER — RETOUR ARRIÈRE de la suppression des 2 doublons (ISCC Treichville, INSTAC Yopougon) (en cas de besoin seulement).
-- Réinsère les 2 fiches depuis etablissements_sauvegarde_20261024 puis les remet en supérieur / grande école (état au moment de la suppression).
-- GARDE : 4 173 fiches, et aucune des 2 n'existe déjà.
-- ============================================================
DO $retour$
declare v_n integer;
begin
  if (select count(*) from public.etablissements) <> 4173 then raise exception 'GARDE : nombre de fiches inattendu : rien n''est modifié.'; end if;
  if exists (select 1 from public.etablissements where id in ('id1786462431113842214', 'id1786462431110121064')) then raise exception 'GARDE : une fiche existe déjà : rien n''est modifié.'; end if;
  insert into public.etablissements select * from public.etablissements_sauvegarde_20261024 where id in ('id1786462431113842214', 'id1786462431110121064');
  get diagnostics v_n = row_count;
  if v_n <> 2 then raise exception 'ÉCHEC : % fiches réinsérées au lieu de 2 : tout est annulé.', v_n; end if;
  update public.etablissements set categorie = 'superieur', sous_categorie = 'grande_ecole' where id in ('id1786462431113842214', 'id1786462431110121064');
  raise notice 'Retour arrière terminé : 2 fiches réinsérées (4 175 fiches).';
end;
$retour$;
select count(*) as nb_fiches from public.etablissements;
