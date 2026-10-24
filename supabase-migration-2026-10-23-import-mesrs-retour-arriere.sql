-- ============================================================
-- ORIMETIER — RETOUR ARRIÈRE de l'import des filières du ministère (à ne lancer qu'en cas de besoin).
--
-- Effet : (1) retire de TOUTES les fiches les filières marquées "src":"mesrs-2026-10-23" ;
--         (2) supprime les 17 fiches créées (id « ms_<n°> »).
-- GARDE : si l'une des fiches créées a été réclamée par un établissement entre-temps (réclamée, e-mail ou mot de passe),
--         arrêt, rien n'est modifié : il faut alors traiter cette fiche à la main.
-- Autre solution (tout remettre comme avant l'import, y compris les modifications faites depuis) : restaurer
-- public.etablissements_sauvegarde_20261023 (table protégée, 4 171 fiches).
-- ============================================================
DO $retour$
declare v_tag constant text := 'mesrs-2026-10-23'; v_n integer;
begin
  if exists (select 1 from public.etablissements where id like 'ms\_%'
             and (coalesce(reclame,false) or email is not null or password is not null)) then
    raise exception 'GARDE : une fiche créée a été réclamée : rien n''est modifié (traiter à la main).';
  end if;
  delete from public.etablissements where id like 'ms\_%';
  update public.etablissements e
     set filieres_proposees = (select coalesce(jsonb_agg(f order by o), '[]'::jsonb)
                               from jsonb_array_elements(e.filieres_proposees) with ordinality as t(f, o)
                               where f->>'src' is distinct from v_tag)
   where exists (select 1 from jsonb_array_elements(e.filieres_proposees) f where f->>'src' = v_tag);
  select count(*) into v_n from public.etablissements;
  if v_n <> 4171 then raise exception 'ÉCHEC : % fiches au lieu de 4 171 : tout est annulé.', v_n; end if;
  if exists (select 1 from public.etablissements e, jsonb_array_elements(e.filieres_proposees) f where f->>'src' = v_tag) then
    raise exception 'ÉCHEC : des filières marquées restent : tout est annulé.';
  end if;
  raise notice 'Retour arrière terminé : 4 171 fiches, plus aucune filière marquée.';
end;
$retour$;

-- Vérification : fiches différentes de la sauvegarde (attendu 0 si personne n'a modifié de fiche depuis l'import)
select count(*) as fiches_differentes_de_la_sauvegarde
from public.etablissements e join public.etablissements_sauvegarde_20261023 s on s.id = e.id
where to_jsonb(e) is distinct from to_jsonb(s);
