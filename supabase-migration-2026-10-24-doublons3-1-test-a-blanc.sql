-- ============================================================
-- ORIMETIER — Doublons « supérieur » remplis : ÉTAPE 1 = TEST À BLANC (rien n'est enregistré)
-- Supprime 2 fiches doublons, identiques à une autre fiche supérieur (mêmes filières, toutes issues de l'import du ministère) :
--   ISCC Treichville : supprime id1786462431113842214, garde id178637635068499924
--   INSTAC Yopougon  : supprime id1786462431110121064, garde id178637635066694304
-- GARDES (arrêt, rien n'est supprimé) : 4 175 fiches ; sauvegarde 20261024 présente ; chaque fiche supprimée n'a ni compte, ni contact, ni photo,
-- et TOUTES ses filières (marque mesrs-2026-10-23) se retrouvent déjà sur la fiche conservée ; aucune autre table ne les référence.
-- Après : 4 173 fiches. Retour arrière : supabase-migration-2026-10-24-doublons3-retour-arriere.sql
-- Fichier à lancer EN ENTIER, sans rien sélectionner.
-- ============================================================

DO $doublons3$
declare
  v_valider constant boolean := false;   -- false = TEST À BLANC (tout est annulé à la fin) ; true = RÉEL
  v_old constant text[] := array['id1786462431113842214', 'id1786462431110121064'];
  v_keep constant text[] := array['id178637635068499924', 'id178637635066694304'];
  v_n integer; v_fk record; v_refs bigint; v_d0 integer; v_dd integer; v_apres integer;
begin
  -- GARDES
  select count(*) into v_n from public.etablissements;
  if v_n is distinct from 4175 then raise exception 'GARDE : % fiches au lieu de 4 175 : rien n''est modifié.', v_n; end if;
  if to_regclass('public.etablissements_sauvegarde_20261024') is null
     or (select count(*) from public.etablissements_sauvegarde_20261024) <> 4188 then
    raise exception 'GARDE : sauvegarde absente ou incomplète : rien n''est modifié.';
  end if;
  if (select count(*) from public.etablissements where id = any(v_old)) <> 2
     or (select count(*) from public.etablissements where id = any(v_keep) and categorie = 'superieur') <> 2 then
    raise exception 'GARDE : fiches introuvables : rien n''est modifié.';
  end if;
  if exists (select 1 from public.etablissements e where e.id = any(v_old) and (
        coalesce(e.reclame,false) or e.email is not null or e.password is not null or e.tel is not null or e.tel2 is not null
        or e.tel3 is not null or e.contact_tel is not null or e.site_web is not null or e.responsable is not null
        or jsonb_array_length(coalesce(e.photos,'[]'::jsonb)) > 0 or e.logo_url is not null or coalesce(e.premium,false)
        or coalesce(e.demande_premium,false))) then
    raise exception 'GARDE : une fiche à supprimer contient des données à conserver : rien n''est modifié.';
  end if;
  -- toutes les filières de la fiche supprimée sont de l'import ET déjà présentes sur la fiche conservée
  if exists (
    select 1
      from (values ('id1786462431113842214','id178637635068499924'), ('id1786462431110121064','id178637635066694304')) p(o,k)
      join public.etablissements eo on eo.id = p.o
      join public.etablissements ek on ek.id = p.k
      cross join lateral jsonb_array_elements(coalesce(eo.filieres_proposees,'[]'::jsonb)) f
     where f->>'src' is distinct from 'mesrs-2026-10-23'
        or not exists (select 1 from jsonb_array_elements(coalesce(ek.filieres_proposees,'[]'::jsonb)) g
                        where lower(g->>'nom') = lower(f->>'nom') and lower(coalesce(g->>'diplome','')) = lower(coalesce(f->>'diplome','')))
  ) then
    raise exception 'GARDE : une filière de la fiche à supprimer manque sur la fiche conservée : rien n''est modifié.';
  end if;
  for v_fk in
    select c.conrelid::regclass as tbl, a.attname as col
      from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
     where c.contype = 'f' and c.confrelid = 'public.etablissements'::regclass
  loop
    execute format('select count(*) from %s where %I::text = any($1)', v_fk.tbl, v_fk.col) into v_refs using v_old;
    if v_refs > 0 then raise exception 'GARDE : % ligne(s) de % référencent ces fiches : rien n''est modifié.', v_refs, v_fk.tbl; end if;
  end loop;
  select count(*) into v_d0 from public.etablissements e join public.etablissements_sauvegarde_20261024 s using (id)
   where to_jsonb(e) is distinct from to_jsonb(s);
  if v_d0 <> 137 then raise exception 'GARDE : % fiches différentes de la sauvegarde au lieu de 137 : rien n''est modifié.', v_d0; end if;
  select count(*) into v_dd from public.etablissements e join public.etablissements_sauvegarde_20261024 s using (id)
   where e.id = any(v_old) and to_jsonb(e) is distinct from to_jsonb(s);

  -- SUPPRESSION
  delete from public.etablissements where id = any(v_old);
  get diagnostics v_n = row_count;
  if v_n <> 2 then raise exception 'ÉCHEC : % fiches supprimées au lieu de 2 : tout est annulé.', v_n; end if;

  -- CONTRÔLES
  if (select count(*) from public.etablissements) <> 4173 then raise exception 'ÉCHEC : total inattendu : tout est annulé.'; end if;
  if (select count(*) from public.etablissements where id = any(v_keep)) <> 2 then raise exception 'ÉCHEC : une fiche à conserver a disparu : tout est annulé.'; end if;
  if (select count(*) from public.etablissements_sauvegarde_20261024 s
       where not exists (select 1 from public.etablissements e where e.id = s.id)) <> 15 then
    raise exception 'ÉCHEC : écart inattendu avec la sauvegarde : tout est annulé.';
  end if;
  if (select count(*) from public.etablissements e join public.etablissements_sauvegarde_20261024 s using (id)
       where (to_jsonb(e) - 'categorie' - 'sous_categorie') is distinct from (to_jsonb(s) - 'categorie' - 'sous_categorie')) <> 0 then
    raise exception 'ÉCHEC : une fiche restante a changé (autre qu''un reclassement) : tout est annulé.';
  end if;
  select count(*) into v_apres from public.etablissements e join public.etablissements_sauvegarde_20261024 s using (id)
   where to_jsonb(e) is distinct from to_jsonb(s);
  if v_apres <> v_d0 - v_dd then raise exception 'ÉCHEC : nombre de fiches différentes inattendu : tout est annulé.'; end if;

  if not v_valider then
    raise exception 'TEST À BLANC RÉUSSI : 2 fiches doublons seraient supprimées (4 175 -> 4 173), les 2 fiches conservées gardent toutes les filières. RIEN N''A ÉTÉ ENREGISTRÉ.';
  end if;
  raise notice 'DOUBLONS SUPPRIMÉS : 2 fiches, il reste 4 173 fiches.';
end;
$doublons3$;
