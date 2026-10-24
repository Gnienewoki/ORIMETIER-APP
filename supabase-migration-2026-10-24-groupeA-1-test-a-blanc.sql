-- ============================================================
-- ORIMETIER — Reclassement du groupe A en supérieur : ÉTAPE 1 = TEST À BLANC (rien n'est enregistré)
-- (1) supprime 2 doublons « technique » vides : CPC Yamoussoukro (id17864517762731719, double id178637620234718947) et
--     ISTCJF Bonoua (id178646243110935378, double id178637635073895315) ;
-- (2) passe 148 fiches (« Institut Supérieur… », « École Supérieure… », « Business School »…) de général/technique secondaire à
--     supérieur / grande école. Seuls categorie et sous_categorie changent. Le groupe B (17 fiches à vérifier) n'est PAS touché.
-- GARDES (arrêt, rien n'est modifié) : 4 173 fiches ; sauvegarde 20261024 présente ; 135 fiches reclassées du 1er lot encore présentes (137 moins 2 doublons supprimés depuis) ; les 148 fiches existent et sont encore
-- « secondaire privé » ; les 2 doublons sont des coquilles vides et leur fiche jumelle existe en supérieur ; aucune autre table ne les référence.
-- Après : 4 171 fiches. Retour arrière : supabase-migration-2026-10-24-groupeA-retour-arriere.sql
-- Fichier à lancer EN ENTIER, sans rien sélectionner.
-- ============================================================

DO $groupeA$
declare
  v_valider constant boolean := false;   -- false = TEST À BLANC (tout est annulé à la fin) ; true = RÉEL
  v_dup constant text[] := array['id178646243110935378', 'id17864517762731719'];
  v_keep constant text[] := array['id178637635073895315', 'id178637620234718947'];
  v_n integer; v_fk record; v_refs bigint; v_bad integer;
begin
  -- GARDES
  select count(*) into v_n from public.etablissements;
  if v_n is distinct from 4173 then raise exception 'GARDE : % fiches au lieu de 4 173 : rien n''est modifié.', v_n; end if;
  if to_regclass('public.etablissements_sauvegarde_20261024') is null
     or (select count(*) from public.etablissements_sauvegarde_20261024) <> 4188 then
    raise exception 'GARDE : sauvegarde absente ou incomplète : rien n''est modifié.';
  end if;
  select count(*) into v_n from public.etablissements e join public.etablissements_sauvegarde_20261024 s using (id)
   where to_jsonb(e) is distinct from to_jsonb(s);
  if v_n <> 135 then raise exception 'GARDE : % fiches différentes de la sauvegarde au lieu de 135 : rien n''est modifié.', v_n; end if;

  create temp table _r(id text primary key, sc text not null) on commit drop;
  insert into _r(id, sc) values
    ('id178637629314546599','grande_ecole'),
    ('id178637629315610746','grande_ecole'),
    ('id178637629316811486','grande_ecole'),
    ('id17863762932682417','grande_ecole'),
    ('id178637629355567217','grande_ecole'),
    ('id1786376293160862','grande_ecole'),
    ('id1786376293194552750','grande_ecole'),
    ('id1786376293195122573','grande_ecole'),
    ('id1786376293196193817','grande_ecole'),
    ('id1786376293197206507','grande_ecole'),
    ('id1786376293198704914','grande_ecole'),
    ('id17863763501217620','grande_ecole'),
    ('id17863763502959432','grande_ecole'),
    ('id178637635010725880','grande_ecole'),
    ('id178637635011784053','grande_ecole'),
    ('id178637635021883215','grande_ecole'),
    ('id178637635022333453','grande_ecole'),
    ('id178637635025404553','grande_ecole'),
    ('id178637635026908566','grande_ecole'),
    ('id178637635030445864','grande_ecole'),
    ('id178637635032174359','grande_ecole'),
    ('id178637635034756161','grande_ecole'),
    ('id178637635035232698','grande_ecole'),
    ('id178637635037107881','grande_ecole'),
    ('id178637635038992876','grande_ecole'),
    ('id178637635039680822','grande_ecole'),
    ('id178637635042507870','grande_ecole'),
    ('id178637635043732500','grande_ecole'),
    ('id178637635044294287','grande_ecole'),
    ('id178637635045744833','grande_ecole'),
    ('id178637635048823868','grande_ecole'),
    ('id178637635050794527','grande_ecole'),
    ('id178637635052815980','grande_ecole'),
    ('id178637635053602196','grande_ecole'),
    ('id178637635054533314','grande_ecole'),
    ('id178637635059145617','grande_ecole'),
    ('id178637635064860517','grande_ecole'),
    ('id178637635065902589','grande_ecole'),
    ('id178637635067871768','grande_ecole'),
    ('id178637635069160331','grande_ecole'),
    ('id17863763507023635','grande_ecole'),
    ('id178637635071725762','grande_ecole'),
    ('id178637635072302474','grande_ecole'),
    ('id178637635077294527','grande_ecole'),
    ('id17863763507879740','grande_ecole'),
    ('id178637635081140976','grande_ecole'),
    ('id178637635085256921','grande_ecole'),
    ('id178637635086778625','grande_ecole'),
    ('id178637635087116570','grande_ecole'),
    ('id178637635088194919','grande_ecole'),
    ('id178637635090323571','grande_ecole'),
    ('id178637635091761934','grande_ecole'),
    ('id178637635092713125','grande_ecole'),
    ('id178637635093866891','grande_ecole'),
    ('id178637635098893066','grande_ecole'),
    ('id178637635099416138','grande_ecole'),
    ('id1786376350103662024','grande_ecole'),
    ('id1786376350104881630','grande_ecole'),
    ('id1786376350105832027','grande_ecole'),
    ('id178637635010778262','grande_ecole'),
    ('id1786376350108824605','grande_ecole'),
    ('id1786376350110868557','grande_ecole'),
    ('id1786376350111884269','grande_ecole'),
    ('id1786376350114883393','grande_ecole'),
    ('id1786376350116511275','grande_ecole'),
    ('id178637635011741921','grande_ecole'),
    ('id1786376350118869527','grande_ecole'),
    ('id1786376350121814439','grande_ecole'),
    ('id1786376350125121205','grande_ecole'),
    ('id1786376350130240119','grande_ecole'),
    ('id1786376350149676041','grande_ecole'),
    ('id1786376350180531336','grande_ecole'),
    ('id1786376350181607677','grande_ecole'),
    ('id1786376350182793932','grande_ecole'),
    ('id1786376350194480244','grande_ecole'),
    ('id1786376350148963212','grande_ecole'),
    ('id178637635027968554','grande_ecole'),
    ('id178637635094755239','grande_ecole'),
    ('id1786376350145278930','grande_ecole'),
    ('id1786376350161389204','grande_ecole'),
    ('id1786376293159902752','grande_ecole'),
    ('id1786376293109761877','grande_ecole'),
    ('id178637635075280678','grande_ecole'),
    ('id17863763509230137','grande_ecole'),
    ('id178637635033145600','grande_ecole'),
    ('id17863763506111471','grande_ecole'),
    ('id178637629392371242','grande_ecole'),
    ('id178637635046666172','grande_ecole'),
    ('id178637635097322568','grande_ecole'),
    ('id1786376350109373666','grande_ecole'),
    ('id178637635024517753','grande_ecole'),
    ('id17863763506039660','grande_ecole'),
    ('id178637635028292170','grande_ecole'),
    ('id178637635062584130','grande_ecole'),
    ('id178628246893750','grande_ecole'),
    ('id178637635041683836','grande_ecole'),
    ('id1786376350315673','grande_ecole'),
    ('id178637635056587195','grande_ecole'),
    ('id1786376350106340130','grande_ecole'),
    ('id178637635089767632','grande_ecole'),
    ('id17863763502315717','grande_ecole'),
    ('id178637635096761613','grande_ecole'),
    ('id1786376350119974399','grande_ecole'),
    ('id1786376350135587022','grande_ecole'),
    ('id178637635079126224','grande_ecole'),
    ('id1786376350100611305','grande_ecole'),
    ('id1786376350113124543','grande_ecole'),
    ('id178637635012023965','grande_ecole'),
    ('id1786376350158365545','grande_ecole'),
    ('id1786376350127628424','grande_ecole'),
    ('id178637629387302528','grande_ecole'),
    ('id178637635095781096','grande_ecole'),
    ('id1786376350174938330','grande_ecole'),
    ('id178637635017583683','grande_ecole'),
    ('id1786376350101791711','grande_ecole'),
    ('id1786376350102325179','grande_ecole'),
    ('id178637629323534882','grande_ecole'),
    ('id178637635055488622','grande_ecole'),
    ('id1786376350834144','grande_ecole'),
    ('id1786376350172137483','grande_ecole'),
    ('id178646268359212540','grande_ecole'),
    ('id178646243183451902','grande_ecole'),
    ('id178646268362789573','grande_ecole'),
    ('id178646243184424620','grande_ecole'),
    ('id178646268357533701','grande_ecole'),
    ('id178646268363161172','grande_ecole'),
    ('id1786462431107155477','grande_ecole'),
    ('id178646268365296891','grande_ecole'),
    ('id1786462431105893501','grande_ecole'),
    ('id1786462431112427460','grande_ecole'),
    ('id1786462431111495712','grande_ecole'),
    ('id178646243181911366','grande_ecole'),
    ('id178646243182727980','grande_ecole'),
    ('id1786462431115939329','grande_ecole'),
    ('id1786462431104213239','grande_ecole'),
    ('id178646268366772698','grande_ecole'),
    ('id1786462683107946471','grande_ecole'),
    ('id1786462431106838711','grande_ecole'),
    ('id178646268356555918','grande_ecole'),
    ('id178646268358862404','grande_ecole'),
    ('id178646268364446211','grande_ecole'),
    ('id1786462683105180929','grande_ecole'),
    ('id178646243117916312','grande_ecole'),
    ('id17864624311877642','grande_ecole'),
    ('id1786462431108936059','grande_ecole'),
    ('id178646268361972675','grande_ecole'),
    ('id178646243180540029','grande_ecole'),
    ('id1786462431103827139','grande_ecole');
  if (select count(*) from _r) <> 148 then raise exception 'GARDE : liste incomplète : rien n''est modifié.'; end if;
  if (select count(*) from public.etablissements e join _r using (id)) <> 148 then
    raise exception 'GARDE : une fiche de la liste n''existe plus : rien n''est modifié.';
  end if;
  if exists (select 1 from public.etablissements e join _r using (id)
             where not (e.categorie in ('general','technique') and e.sous_categorie = 'secondaire' and e.secteur = 'prive')) then
    raise exception 'GARDE : une fiche de la liste n''est plus « secondaire privé » : rien n''est modifié.';
  end if;
  if exists (select 1 from _r where id = any(v_dup)) then raise exception 'GARDE : un doublon est dans la liste : rien n''est modifié.'; end if;

  if (select count(*) from public.etablissements where id = any(v_dup)) <> 2
     or (select count(*) from public.etablissements where id = any(v_keep) and categorie = 'superieur') <> 2 then
    raise exception 'GARDE : doublons ou fiches jumelles introuvables : rien n''est modifié.';
  end if;
  if exists (select 1 from public.etablissements e where e.id = any(v_dup) and (
        coalesce(e.reclame,false) or e.email is not null or e.password is not null or e.tel is not null or e.tel2 is not null
        or e.tel3 is not null or e.contact_tel is not null or e.site_web is not null or e.responsable is not null
        or jsonb_array_length(coalesce(e.photos,'[]'::jsonb)) > 0 or e.logo_url is not null or coalesce(e.premium,false)
        or coalesce(e.demande_premium,false) or jsonb_array_length(coalesce(e.filieres_proposees,'[]'::jsonb)) > 0)) then
    raise exception 'GARDE : un doublon contient des données à conserver : rien n''est modifié.';
  end if;
  for v_fk in
    select c.conrelid::regclass as tbl, a.attname as col
      from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
     where c.contype = 'f' and c.confrelid = 'public.etablissements'::regclass
  loop
    execute format('select count(*) from %s where %I::text = any($1)', v_fk.tbl, v_fk.col) into v_refs using (v_dup || array(select id from _r));
    if v_refs > 0 then raise exception 'GARDE : % ligne(s) de % référencent ces fiches : rien n''est modifié.', v_refs, v_fk.tbl; end if;
  end loop;

  -- (1) SUPPRESSION DES 2 DOUBLONS
  delete from public.etablissements where id = any(v_dup);
  get diagnostics v_n = row_count;
  if v_n <> 2 then raise exception 'ÉCHEC : % doublons supprimés au lieu de 2 : tout est annulé.', v_n; end if;

  -- (2) RECLASSEMENT : uniquement categorie et sous_categorie
  update public.etablissements e set categorie = 'superieur', sous_categorie = r.sc from _r r where e.id = r.id;
  get diagnostics v_n = row_count;
  if v_n <> 148 then raise exception 'ÉCHEC : % fiches reclassées au lieu de 148 : tout est annulé.', v_n; end if;

  -- CONTRÔLES
  if (select count(*) from public.etablissements) <> 4171 then raise exception 'ÉCHEC : total inattendu : tout est annulé.'; end if;
  if (select count(*) from public.etablissements_sauvegarde_20261024 s
       where not exists (select 1 from public.etablissements e where e.id = s.id)) <> 17 then
    raise exception 'ÉCHEC : écart inattendu avec la sauvegarde : tout est annulé.';
  end if;
  if (select count(*) from public.etablissements e join public.etablissements_sauvegarde_20261024 s using (id)
       where (to_jsonb(e) - 'categorie' - 'sous_categorie') is distinct from (to_jsonb(s) - 'categorie' - 'sous_categorie')) <> 0 then
    raise exception 'ÉCHEC : une autre colonne a changé : tout est annulé.';
  end if;
  if (select count(*) from public.etablissements e join public.etablissements_sauvegarde_20261024 s using (id)
       where to_jsonb(e) is distinct from to_jsonb(s)) <> 135 + 148 then
    raise exception 'ÉCHEC : nombre de fiches reclassées inattendu : tout est annulé.';
  end if;
  select count(*) into v_bad from public.etablissements e join _r using (id)
   where e.categorie <> 'superieur' or e.sous_categorie is distinct from _r.sc or e.secteur <> 'prive';
  if v_bad <> 0 then raise exception 'ÉCHEC : % fiches mal classées : tout est annulé.', v_bad; end if;

  if not v_valider then
    raise exception 'TEST À BLANC RÉUSSI : 2 doublons seraient supprimés, 148 fiches seraient passées en supérieur (4 173 -> 4 171 fiches). RIEN N''A ÉTÉ ENREGISTRÉ.';
  end if;
  raise notice 'TERMINÉ : 2 doublons supprimés, 148 fiches passées en supérieur, 4 171 fiches.';
end;
$groupeA$;
