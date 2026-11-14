-- ============================================================
-- ORIMETIER — Reclassement de 126 fiches en supérieur (liste officielle du ministère) : ÉTAPE 1 = TEST À BLANC (rien n'est enregistré)
-- 126 fiches « général privé » confirmées par le ministère passent en supérieur :
-- 123 en grande_ecole, 3 en universite (Le Campus Cocody, Man, Yopougon). Seuls categorie et sous_categorie changent.
-- Le bloc technique / formation professionnelle n'est pas touché (garde : categorie = 'general' uniquement).
-- GARDES (arrêt, rien n'est modifié) : sauvegarde 20261114 présente et identique à la base ; liste = 123 grande_ecole
-- + 3 universite ; les 126 fiches existent, sont privées, en général, et sans aucune filière.
-- Retour arrière : lot131-retour-arriere.sql. Fichier à lancer EN ENTIER, sans rien sélectionner.
-- ============================================================

DO $lot131$
declare
  v_valider constant boolean := false;   -- false = TEST À BLANC ; true = RÉEL
  v_n integer; v_bad integer;
begin
  if to_regclass('public.etablissements_sauvegarde_20261114') is null then
    raise exception 'GARDE : sauvegarde absente : rien n''est modifié.';
  end if;
  if (select count(*) from public.etablissements) <> (select count(*) from public.etablissements_sauvegarde_20261114) then
    raise exception 'GARDE : le nombre de fiches a changé depuis la sauvegarde : rien n''est modifié.';
  end if;
  select count(*) into v_n from public.etablissements e join public.etablissements_sauvegarde_20261114 s using (id)
   where to_jsonb(e) is distinct from to_jsonb(s);
  if v_n <> 0 then raise exception 'GARDE : % fiches différentes de la sauvegarde : rien n''est modifié.', v_n; end if;

  create temp table _r(id text primary key, sc text not null) on commit drop;
  insert into _r(id, sc) values
    ('id17863762932957184','grande_ecole'),
    ('id178637629313115569','grande_ecole'),
    ('id178637629318968749','grande_ecole'),
    ('id17863762931956029','grande_ecole'),
    ('id178637629325275768','grande_ecole'),
    ('id178637629327799952','grande_ecole'),
    ('id17863762933039225','grande_ecole'),
    ('id178637629331354679','grande_ecole'),
    ('id178637629333413026','grande_ecole'),
    ('id178637629334125055','grande_ecole'),
    ('id178637629336748963','grande_ecole'),
    ('id17863762933966657','grande_ecole'),
    ('id178637629341332791','grande_ecole'),
    ('id178637629342802273','grande_ecole'),
    ('id178637629346385723','grande_ecole'),
    ('id178637629348485418','grande_ecole'),
    ('id178637629349348574','grande_ecole'),
    ('id178637629351815879','grande_ecole'),
    ('id178637629352112338','grande_ecole'),
    ('id178637629360637964','grande_ecole'),
    ('id178637629362178498','grande_ecole'),
    ('id178637629363404973','grande_ecole'),
    ('id178637629364492917','grande_ecole'),
    ('id178637629365393845','grande_ecole'),
    ('id178637629366431949','grande_ecole'),
    ('id178637629367530326','grande_ecole'),
    ('id17863762936876116','grande_ecole'),
    ('id17863762936977015','grande_ecole'),
    ('id178637629373539182','grande_ecole'),
    ('id178637629374168197','grande_ecole'),
    ('id17863762937568713','grande_ecole'),
    ('id178637629377549979','grande_ecole'),
    ('id17863762937925044','grande_ecole'),
    ('id178637629380982325','grande_ecole'),
    ('id178637629382188241','grande_ecole'),
    ('id178637629384502191','grande_ecole'),
    ('id178637629385167185','grande_ecole'),
    ('id178637629386866505','grande_ecole'),
    ('id178637629388724537','grande_ecole'),
    ('id178637629397791273','grande_ecole'),
    ('id1786376293103980936','grande_ecole'),
    ('id1786376293111943732','grande_ecole'),
    ('id1786376293112968421','grande_ecole'),
    ('id1786376293113930192','grande_ecole'),
    ('id1786376293114244304','grande_ecole'),
    ('id1786376293115388200','grande_ecole'),
    ('id1786376293116321360','grande_ecole'),
    ('id1786376293118215521','grande_ecole'),
    ('id1786376293119472824','grande_ecole'),
    ('id1786376293120313434','universite'),
    ('id1786376293121514721','universite'),
    ('id1786376293122742052','universite'),
    ('id1786376293124672566','grande_ecole'),
    ('id1786376293126567806','grande_ecole'),
    ('id1786376293129965765','grande_ecole'),
    ('id178637629313036143','grande_ecole'),
    ('id1786376293131255480','grande_ecole'),
    ('id1786376293132592400','grande_ecole'),
    ('id1786376293136699836','grande_ecole'),
    ('id178637629313846564','grande_ecole'),
    ('id1786376293139784692','grande_ecole'),
    ('id1786376293141496942','grande_ecole'),
    ('id1786376293142861628','grande_ecole'),
    ('id1786376293146231117','grande_ecole'),
    ('id1786376293148610899','grande_ecole'),
    ('id1786376293150400840','grande_ecole'),
    ('id17863762931513852','grande_ecole'),
    ('id1786376293152616463','grande_ecole'),
    ('id178637629315383533','grande_ecole'),
    ('id1786376293155952464','grande_ecole'),
    ('id1786376293156764355','grande_ecole'),
    ('id1786376293162105845','grande_ecole'),
    ('id1786376293165447398','grande_ecole'),
    ('id1786376293166138751','grande_ecole'),
    ('id1786376293167806418','grande_ecole'),
    ('id1786376293168695674','grande_ecole'),
    ('id1786376293169700714','grande_ecole'),
    ('id1786376293170292702','grande_ecole'),
    ('id1786376293171113449','grande_ecole'),
    ('id1786376293172864856','grande_ecole'),
    ('id1786376293173131562','grande_ecole'),
    ('id1786376293174587402','grande_ecole'),
    ('id1786376293175813459','grande_ecole'),
    ('id178637629317797749','grande_ecole'),
    ('id1786376293178303352','grande_ecole'),
    ('id1786376293179338208','grande_ecole'),
    ('id1786376293181609782','grande_ecole'),
    ('id1786376293182711077','grande_ecole'),
    ('id1786376293183521457','grande_ecole'),
    ('id1786376293185543505','grande_ecole'),
    ('id178637629318798842','grande_ecole'),
    ('id178637629318964446','grande_ecole'),
    ('id1786376293190956704','grande_ecole'),
    ('id1786376293191446245','grande_ecole'),
    ('id1786376293193933455','grande_ecole'),
    ('id17863763504990621','grande_ecole'),
    ('id17863763508800814','grande_ecole'),
    ('id178637635012354856','grande_ecole'),
    ('id178637635013584637','grande_ecole'),
    ('id17863763501473481','grande_ecole'),
    ('id178637635015554260','grande_ecole'),
    ('id178637635016828224','grande_ecole'),
    ('id178637635018658266','grande_ecole'),
    ('id1786376350140828887','grande_ecole'),
    ('id178637635014270524','grande_ecole'),
    ('id1786376350147258803','grande_ecole'),
    ('id1786376350150469395','grande_ecole'),
    ('id1786376350155677779','grande_ecole'),
    ('id1786376350157304463','grande_ecole'),
    ('id1786376350165535960','grande_ecole'),
    ('id1786376350166491978','grande_ecole'),
    ('id1786376350168523963','grande_ecole'),
    ('id1786376350170359600','grande_ecole'),
    ('id1786376350171256027','grande_ecole'),
    ('id1786376350173775425','grande_ecole'),
    ('id1786376350178493159','grande_ecole'),
    ('id1786376350179311752','grande_ecole'),
    ('id1786376350186469028','grande_ecole'),
    ('id1786376350187234993','grande_ecole'),
    ('id1786376350188681133','grande_ecole'),
    ('id1786376350189991308','grande_ecole'),
    ('id1786376350191341066','grande_ecole'),
    ('id1786376350192795248','grande_ecole'),
    ('id1786376350193490600','grande_ecole'),
    ('id1786376350195338784','grande_ecole'),
    ('id1786376350196235602','grande_ecole');
  if (select count(*) from _r) <> 126 then raise exception 'GARDE : liste incomplète : rien n''est modifié.'; end if;
  if (select count(*) from _r where sc = 'grande_ecole') <> 123 or (select count(*) from _r where sc = 'universite') <> 3 then
    raise exception 'GARDE : répartition inattendue (attendu 123 grande_ecole + 3 universite) : rien n''est modifié.';
  end if;
  if (select count(*) from public.etablissements e join _r using (id)) <> 126 then
    raise exception 'GARDE : une fiche de la liste n''existe plus : rien n''est modifié.';
  end if;
  if exists (select 1 from public.etablissements e join _r using (id)
             where not (e.categorie = 'general' and e.secteur = 'prive')) then
    raise exception 'GARDE : une fiche de la liste n''est plus « général privé » : rien n''est modifié.';
  end if;
  if exists (select 1 from public.etablissements e join _r using (id)
             where jsonb_array_length(coalesce(e.filieres_proposees,'[]'::jsonb)) > 0) then
    raise exception 'GARDE : une fiche de la liste a déjà des filières : rien n''est modifié.';
  end if;

  update public.etablissements e set categorie = 'superieur', sous_categorie = r.sc from _r r where e.id = r.id;
  get diagnostics v_n = row_count;
  if v_n <> 126 then raise exception 'ÉCHEC : % fiches reclassées au lieu de 126 : tout est annulé.', v_n; end if;

  if (select count(*) from public.etablissements) <> (select count(*) from public.etablissements_sauvegarde_20261114) then
    raise exception 'ÉCHEC : total inattendu : tout est annulé.';
  end if;
  if (select count(*) from public.etablissements e join public.etablissements_sauvegarde_20261114 s using (id)
       where (to_jsonb(e) - 'categorie' - 'sous_categorie') is distinct from (to_jsonb(s) - 'categorie' - 'sous_categorie')) <> 0 then
    raise exception 'ÉCHEC : une autre colonne a changé : tout est annulé.';
  end if;
  if (select count(*) from public.etablissements e join public.etablissements_sauvegarde_20261114 s using (id)
       where to_jsonb(e) is distinct from to_jsonb(s)) <> 126 then
    raise exception 'ÉCHEC : nombre de fiches modifiées inattendu : tout est annulé.';
  end if;
  select count(*) into v_bad from public.etablissements e join _r using (id)
   where e.categorie <> 'superieur' or e.sous_categorie is distinct from _r.sc or e.secteur <> 'prive';
  if v_bad <> 0 then raise exception 'ÉCHEC : % fiches mal classées : tout est annulé.', v_bad; end if;

  if not v_valider then
    raise exception 'TEST À BLANC RÉUSSI : 126 fiches seraient passées en supérieur (123 grandes écoles, 3 universités). RIEN N''A ÉTÉ ENREGISTRÉ.';
  end if;
  raise notice 'TERMINÉ : 126 fiches passées en supérieur.';
end;
$lot131$;
