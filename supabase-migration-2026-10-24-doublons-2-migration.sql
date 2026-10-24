-- ============================================================
-- ORIMETIER — Doublons créés par l'import du ministère : ÉTAPE 2 = MIGRATION RÉELLE
-- Supprime 5 anciennes fiches « coquilles vides » (catégorie général, 0 filière, aucun compte, aucun contact, aucune photo)
-- qui doublonnent 5 fiches créées par l'import (ms_362 ESCOGET Cocody, ms_342 ESCOGET Plateau, ms_145 ISFOTT, ms_143 ISAB,
-- ms_260 IST Saint Jacques Bouaké). On GARDE les fiches ms_ (filières du ministère + code de récupération).
-- GARDES (arrêt, rien n'est supprimé) : 4 188 fiches ; sauvegarde 20261024 présente ; les 5 anciennes fiches sont bien des coquilles vides
-- (non réclamées, sans e-mail, mot de passe, téléphone, contact, site, responsable, photo, logo, filière, premium) ;
-- les 5 fiches ms_ existent, non réclamées ; aucune autre table ne référence ces anciennes fiches.
-- Après : 4 183 fiches. Retour arrière : supabase-migration-2026-10-24-doublons-retour-arriere.sql
-- Fichier à lancer EN ENTIER, sans rien sélectionner.
-- ============================================================

DO $doublons$
declare
  v_valider constant boolean := true;   -- false = TEST À BLANC (tout est annulé à la fin) ; true = RÉEL
  v_old constant text[] := array[
    'id1786376293534210',
    'id17863762935496775',
    'id1786376350137840677',
    'id1786376350154671375',
    'id1786376350163722763'];
  v_new constant text[] := array['ms_362', 'ms_342', 'ms_145', 'ms_143', 'ms_260'];
  v_n integer; v_fk record; v_refs bigint;
begin
  -- GARDES
  select count(*) into v_n from public.etablissements;
  if v_n is distinct from 4188 then raise exception 'GARDE : % fiches au lieu de 4 188 : rien n''est modifié.', v_n; end if;
  if to_regclass('public.etablissements_sauvegarde_20261024') is null
     or (select count(*) from public.etablissements_sauvegarde_20261024) <> 4188 then
    raise exception 'GARDE : sauvegarde absente ou incomplète : rien n''est modifié.';
  end if;
  if (select count(*) from public.etablissements where id = any(v_old)) <> 5 then raise exception 'GARDE : anciennes fiches introuvables : rien n''est modifié.'; end if;
  if (select count(*) from public.etablissements where id = any(v_new) and not coalesce(reclame,false)
        and email is null and password is null) <> 5 then
    raise exception 'GARDE : une fiche ms_ manque ou a été réclamée : rien n''est modifié.';
  end if;
  if exists (select 1 from public.etablissements e where e.id = any(v_old) and (
        coalesce(e.reclame,false) or e.email is not null or e.password is not null or e.tel is not null or e.tel2 is not null
        or e.tel3 is not null or e.contact_tel is not null or e.site_web is not null or e.responsable is not null
        or jsonb_array_length(coalesce(e.photos,'[]'::jsonb)) > 0 or e.logo_url is not null or coalesce(e.premium,false)
        or coalesce(e.demande_premium,false) or jsonb_array_length(coalesce(e.filieres_proposees,'[]'::jsonb)) > 0)) then
    raise exception 'GARDE : une ancienne fiche contient des données à conserver : rien n''est modifié.';
  end if;
  -- aucune autre table ne référence ces fiches (clés étrangères)
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
  if v_n <> 5 then raise exception 'ÉCHEC : % fiches supprimées au lieu de 5 : tout est annulé.', v_n; end if;

  -- CONTRÔLES
  if (select count(*) from public.etablissements) <> 4183 then raise exception 'ÉCHEC : total inattendu : tout est annulé.'; end if;
  if (select count(*) from public.etablissements where id = any(v_new)) <> 5 then raise exception 'ÉCHEC : une fiche ms_ a disparu : tout est annulé.'; end if;
  if (select count(*) from public.etablissements_sauvegarde_20261024 s
       where not exists (select 1 from public.etablissements e where e.id = s.id)) <> 5 then
    raise exception 'ÉCHEC : écart inattendu avec la sauvegarde : tout est annulé.';
  end if;
  -- la sauvegarde date d'AVANT le reclassement : seules categorie / sous_categorie ont pu changer (137 fiches), rien d'autre
  if (select count(*) from public.etablissements e join public.etablissements_sauvegarde_20261024 s using (id)
       where (to_jsonb(e) - 'categorie' - 'sous_categorie') is distinct from (to_jsonb(s) - 'categorie' - 'sous_categorie')) <> 0 then
    raise exception 'ÉCHEC : une fiche restante a changé (autre qu''un reclassement) : tout est annulé.';
  end if;
  if (select count(*) from public.etablissements e join public.etablissements_sauvegarde_20261024 s using (id)
       where to_jsonb(e) is distinct from to_jsonb(s)) <> 137 then
    raise exception 'ÉCHEC : le nombre de fiches reclassées n''est plus 137 : tout est annulé.';
  end if;

  if not v_valider then
    raise exception 'TEST À BLANC RÉUSSI : 5 fiches doublons seraient supprimées (4 188 -> 4 183), les 5 fiches ms_ sont conservées. RIEN N''A ÉTÉ ENREGISTRÉ.';
  end if;
  raise notice 'DOUBLONS SUPPRIMÉS : 5 fiches, il reste 4 183 fiches.';
end;
$doublons$;

-- Vérification : attendu 3 lignes à true
select n, controle, ok from (
  select 1 as n, '4 183 fiches' as controle, (select count(*) = 4183 from public.etablissements) as ok
  union all select 2, 'les 5 fiches ms_ conservées', (select count(*) = 5 from public.etablissements where id in ('ms_362', 'ms_342', 'ms_145', 'ms_143', 'ms_260'))
  union all select 3, 'les 5 anciennes fiches supprimées', (select count(*) = 0 from public.etablissements where id in ('id1786376293534210', 'id17863762935496775', 'id1786376350137840677', 'id1786376350154671375', 'id1786376350163722763'))
) t order by n;
