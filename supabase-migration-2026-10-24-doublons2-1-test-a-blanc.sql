-- ============================================================
-- ORIMETIER — Doublons « technique » vides : ÉTAPE 1 = TEST À BLANC (rien n'est enregistré)
-- Supprime 8 fiches « technique » vides (0 filière, aucun compte, aucun contact, aucune photo) qui doublonnent 7 fiches
-- « supérieur » déjà présentes : ETIC Cocody (2 fiches), ETIC Marcory, ETIC Yopougon, IFPG/ISFPT Korhogo, IFPG/ISFPT Plateau,
-- ESETP Yopougon, ESCAM Cocody. Les 7 fiches supérieur sont conservées.
-- GARDES (arrêt, rien n'est supprimé) : 4 183 fiches ; sauvegarde 20261024 présente ; les 8 fiches sont des coquilles vides ;
-- les 7 fiches à garder existent en supérieur ; aucune autre table ne référence les 8 fiches.
-- Après : 4 175 fiches. Retour arrière : supabase-migration-2026-10-24-doublons2-retour-arriere.sql
-- Fichier à lancer EN ENTIER, sans rien sélectionner.
-- ============================================================

DO $doublons2$
declare
  v_valider constant boolean := false;   -- false = TEST À BLANC (tout est annulé à la fin) ; true = RÉEL
  v_old constant text[] := array[
    'id178646268339127307',
    'id178646268368603358',
    'id178646268340579101',
    'id178646268367363118',
    'id178646243145918387',
    'id178646243147211885',
    'id178646268355758208',
    'id178646268360510187'];
  v_keep constant text[] := array[
    'id1786376202163820885',
    'id1786376202165559990',
    'id1786376202167911312',
    'id1786376293134644953',
    'id1786376293135569565',
    'id178637620285873859',
    'id178637620297673836'];
  v_n integer; v_fk record; v_refs bigint;
begin
  -- GARDES
  select count(*) into v_n from public.etablissements;
  if v_n is distinct from 4183 then raise exception 'GARDE : % fiches au lieu de 4 183 : rien n''est modifié.', v_n; end if;
  if to_regclass('public.etablissements_sauvegarde_20261024') is null
     or (select count(*) from public.etablissements_sauvegarde_20261024) <> 4188 then
    raise exception 'GARDE : sauvegarde absente ou incomplète : rien n''est modifié.';
  end if;
  if (select count(*) from public.etablissements where id = any(v_old)) <> 8 then raise exception 'GARDE : fiches à supprimer introuvables : rien n''est modifié.'; end if;
  if (select count(*) from public.etablissements where id = any(v_keep) and categorie = 'superieur') <> 7 then
    raise exception 'GARDE : une fiche supérieur à conserver manque : rien n''est modifié.';
  end if;
  if exists (select 1 from public.etablissements e where e.id = any(v_old) and (
        coalesce(e.reclame,false) or e.email is not null or e.password is not null or e.tel is not null or e.tel2 is not null
        or e.tel3 is not null or e.contact_tel is not null or e.site_web is not null or e.responsable is not null
        or jsonb_array_length(coalesce(e.photos,'[]'::jsonb)) > 0 or e.logo_url is not null or coalesce(e.premium,false)
        or coalesce(e.demande_premium,false) or jsonb_array_length(coalesce(e.filieres_proposees,'[]'::jsonb)) > 0)) then
    raise exception 'GARDE : une fiche contient des données à conserver : rien n''est modifié.';
  end if;
  for v_fk in
    select c.conrelid::regclass as tbl, a.attname as col
      from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
     where c.contype = 'f' and c.confrelid = 'public.etablissements'::regclass
  loop
    execute format('select count(*) from %s where %I::text = any($1)', v_fk.tbl, v_fk.col) into v_refs using v_old;
    if v_refs > 0 then raise exception 'GARDE : % ligne(s) de % référencent ces fiches : rien n''est modifié.', v_refs, v_fk.tbl; end if;
  end loop;

  -- SUPPRESSION
  delete from public.etablissements where id = any(v_old);
  get diagnostics v_n = row_count;
  if v_n <> 8 then raise exception 'ÉCHEC : % fiches supprimées au lieu de 8 : tout est annulé.', v_n; end if;

  -- CONTRÔLES
  if (select count(*) from public.etablissements) <> 4175 then raise exception 'ÉCHEC : total inattendu : tout est annulé.'; end if;
  if (select count(*) from public.etablissements where id = any(v_keep)) <> 7 then raise exception 'ÉCHEC : une fiche à conserver a disparu : tout est annulé.'; end if;
  -- écart avec la sauvegarde (antérieure au reclassement et à la 1re suppression) : 5 + 8 fiches absentes
  if (select count(*) from public.etablissements_sauvegarde_20261024 s
       where not exists (select 1 from public.etablissements e where e.id = s.id)) <> 13 then
    raise exception 'ÉCHEC : écart inattendu avec la sauvegarde : tout est annulé.';
  end if;
  if (select count(*) from public.etablissements e join public.etablissements_sauvegarde_20261024 s using (id)
       where (to_jsonb(e) - 'categorie' - 'sous_categorie') is distinct from (to_jsonb(s) - 'categorie' - 'sous_categorie')) <> 0 then
    raise exception 'ÉCHEC : une fiche restante a changé (autre qu''un reclassement) : tout est annulé.';
  end if;
  if (select count(*) from public.etablissements e join public.etablissements_sauvegarde_20261024 s using (id)
       where to_jsonb(e) is distinct from to_jsonb(s)) <> 137 then
    raise exception 'ÉCHEC : le nombre de fiches reclassées n''est plus 137 : tout est annulé.';
  end if;

  if not v_valider then
    raise exception 'TEST À BLANC RÉUSSI : 8 fiches doublons seraient supprimées (4 183 -> 4 175), les 7 fiches supérieur sont conservées. RIEN N''A ÉTÉ ENREGISTRÉ.';
  end if;
  raise notice 'DOUBLONS SUPPRIMÉS : 8 fiches, il reste 4 175 fiches.';
end;
$doublons2$;
