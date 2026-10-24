-- ============================================================
-- ORIMETIER — Reclassement en supérieur (137 fiches confirmées par le ministère) : ÉTAPE 2 = MIGRATION RÉELLE
-- Passe categorie -> 'superieur' et sous_categorie -> grande_ecole (126) / universite (11). RIEN d'autre n'est modifié
-- (les filières, contacts, codes, secteur restent identiques ; contrôlé contre la sauvegarde 20261024).
-- GARDES : 4 188 fiches ; sauvegarde présente ; les 137 fiches existent et sont encore « secondaire privé ».
-- Retour arrière : supabase-migration-2026-10-24-reclassement-retour-arriere.sql
-- Fichier à lancer EN ENTIER, sans rien sélectionner.
-- ============================================================

DO $reclass$
declare
  v_valider constant boolean := true;   -- false = TEST À BLANC (tout est annulé à la fin) ; true = RÉEL
  v_avant integer; v_maj integer; v_diff integer; v_autres integer; v_bad integer;
begin
  -- GARDES
  select count(*) into v_avant from public.etablissements;
  if v_avant is distinct from 4188 then raise exception 'GARDE : % fiches au lieu de 4 188 : rien n''est modifié.', v_avant; end if;
  if to_regclass('public.etablissements_sauvegarde_20261024') is null
     or (select count(*) from public.etablissements_sauvegarde_20261024) <> 4188 then
    raise exception 'GARDE : sauvegarde absente ou incomplète : rien n''est modifié.';
  end if;

  create temp table _r(id text primary key, sc text not null) on commit drop;
  insert into _r(id, sc) values
    ('id1786376293101389797','grande_ecole'),
    ('id17863762931799810','grande_ecole'),
    ('id17863762934890027','grande_ecole'),
    ('id17863762936664763','grande_ecole'),
    ('id17863762937272344','grande_ecole'),
    ('id17863762938612038','grande_ecole'),
    ('id178637629310104244','grande_ecole'),
    ('id178637629311559669','grande_ecole'),
    ('id178637629312211437','grande_ecole'),
    ('id178637629317530606','grande_ecole'),
    ('id178637629320224018','grande_ecole'),
    ('id178637629321680944','grande_ecole'),
    ('id178637629322972353','universite'),
    ('id178637629324271221','universite'),
    ('id178637629328514314','grande_ecole'),
    ('id178637629329898140','grande_ecole'),
    ('id178637629332279574','universite'),
    ('id178637629338514915','grande_ecole'),
    ('id178637629345181235','grande_ecole'),
    ('id178637629347885195','grande_ecole'),
    ('id178637629350635198','grande_ecole'),
    ('id178637629356559155','grande_ecole'),
    ('id178637629357325976','grande_ecole'),
    ('id178637629358346418','grande_ecole'),
    ('id178637629361726081','grande_ecole'),
    ('id178637629370381171','grande_ecole'),
    ('id178637629376895258','grande_ecole'),
    ('id178637629378631518','grande_ecole'),
    ('id178637629381885611','grande_ecole'),
    ('id178637629389281270','grande_ecole'),
    ('id178637629391704959','grande_ecole'),
    ('id178637629393269098','grande_ecole'),
    ('id178637629395872399','grande_ecole'),
    ('id178637629398505143','grande_ecole'),
    ('id178637629399255793','grande_ecole'),
    ('id1786376293100443691','grande_ecole'),
    ('id1786376293102179880','grande_ecole'),
    ('id1786376293107415574','grande_ecole'),
    ('id1786376293108638853','grande_ecole'),
    ('id1786376293110802056','grande_ecole'),
    ('id1786376293117149461','grande_ecole'),
    ('id1786376293123542406','grande_ecole'),
    ('id1786376293125677335','grande_ecole'),
    ('id1786376293128953033','grande_ecole'),
    ('id1786376293135569565','grande_ecole'),
    ('id1786376293137368448','grande_ecole'),
    ('id1786376293140513609','grande_ecole'),
    ('id1786376293143589283','grande_ecole'),
    ('id1786376293144472725','grande_ecole'),
    ('id1786376293145260089','grande_ecole'),
    ('id1786376293147573336','grande_ecole'),
    ('id1786376293154673841','grande_ecole'),
    ('id1786376293157727732','universite'),
    ('id1786376293158849691','universite'),
    ('id1786376293161845066','grande_ecole'),
    ('id1786376293163395887','grande_ecole'),
    ('id1786376293164133258','grande_ecole'),
    ('id1786376293176273221','grande_ecole'),
    ('id1786376293186534174','grande_ecole'),
    ('id1786376293188350632','grande_ecole'),
    ('id1786376293192672240','grande_ecole'),
    ('id17863763503721906','grande_ecole'),
    ('id1786376350659154','grande_ecole'),
    ('id17863763507149596','grande_ecole'),
    ('id178637635017699489','grande_ecole'),
    ('id178637635019720363','universite'),
    ('id178637635036156154','grande_ecole'),
    ('id178637635040362162','grande_ecole'),
    ('id178637635047435467','grande_ecole'),
    ('id178637635051813871','universite'),
    ('id178637635057124128','grande_ecole'),
    ('id178637635058645005','grande_ecole'),
    ('id178637635063293545','grande_ecole'),
    ('id178637635066694304','grande_ecole'),
    ('id178637635068499924','grande_ecole'),
    ('id178637635020504891','grande_ecole'),
    ('id178637635074370137','universite'),
    ('id178637635076810462','universite'),
    ('id178637635080459728','universite'),
    ('id178637635084630769','grande_ecole'),
    ('id1786376350112667744','grande_ecole'),
    ('id1786376350115356604','grande_ecole'),
    ('id1786376350122631424','grande_ecole'),
    ('id1786376350124359663','grande_ecole'),
    ('id1786376350126740109','grande_ecole'),
    ('id1786376350128763030','grande_ecole'),
    ('id1786376350129380404','grande_ecole'),
    ('id178637635013258845','grande_ecole'),
    ('id1786376350133555975','grande_ecole'),
    ('id1786376350134386250','grande_ecole'),
    ('id1786376350136454349','grande_ecole'),
    ('id17863763501383295','grande_ecole'),
    ('id1786376350139105193','universite'),
    ('id1786376350141719818','grande_ecole'),
    ('id1786376350143400537','grande_ecole'),
    ('id178637635014456890','grande_ecole'),
    ('id178637635015126843','grande_ecole'),
    ('id178637635015663542','grande_ecole'),
    ('id1786376350160571090','grande_ecole'),
    ('id1786376350162445730','grande_ecole'),
    ('id1786376350164728647','grande_ecole'),
    ('id1786376350167425017','grande_ecole'),
    ('id1786376350176567486','grande_ecole'),
    ('id178637635018480693','grande_ecole'),
    ('id1786376350190254852','grande_ecole'),
    ('id1786376350123883530','grande_ecole'),
    ('id1786376293133290074','grande_ecole'),
    ('id178637629383681780','grande_ecole'),
    ('id1786376293184611761','grande_ecole'),
    ('id178637635029786378','grande_ecole'),
    ('id178637635082168585','grande_ecole'),
    ('id178637635073895315','grande_ecole'),
    ('id178637629343996700','grande_ecole'),
    ('id178637629359370476','grande_ecole'),
    ('id178637629396284594','grande_ecole'),
    ('id1786376293106580421','grande_ecole'),
    ('id178637629314921517','grande_ecole'),
    ('id1786376350590451','grande_ecole'),
    ('id178637629337673145','grande_ecole'),
    ('id178637635049415477','grande_ecole'),
    ('id1786376350131690919','grande_ecole'),
    ('id178637629371872449','grande_ecole'),
    ('id1786376350183395160','grande_ecole'),
    ('id1786376293134644953','grande_ecole'),
    ('id1786376350153471707','grande_ecole'),
    ('id1786376350177638050','grande_ecole'),
    ('id17863762935691567','grande_ecole'),
    ('id178637629344481060','grande_ecole'),
    ('id178637635015964192','grande_ecole'),
    ('id17863762939851763','grande_ecole'),
    ('id178637629390717071','grande_ecole'),
    ('id178637629394190978','grande_ecole'),
    ('id1786376350146606033','grande_ecole'),
    ('id1786376350185104088','grande_ecole'),
    ('id17864626837193673','grande_ecole'),
    ('id1786462431113842214','grande_ecole'),
    ('id1786462431110121064','grande_ecole');

  if (select count(*) from _r) <> 137 then raise exception 'GARDE : liste incomplète : rien n''est modifié.'; end if;
  if (select count(*) from public.etablissements e join _r using (id)) <> 137 then
    raise exception 'GARDE : une fiche de la liste n''existe plus : rien n''est modifié.';
  end if;
  if exists (select 1 from public.etablissements e join _r using (id)
             where not (e.categorie in ('general','technique') and e.sous_categorie = 'secondaire' and e.secteur = 'prive')) then
    raise exception 'GARDE : une fiche de la liste n''est plus « secondaire privé » (déjà modifiée ?) : rien n''est modifié.';
  end if;

  -- RECLASSEMENT : uniquement categorie et sous_categorie
  update public.etablissements e
     set categorie = 'superieur', sous_categorie = r.sc
    from _r r
   where e.id = r.id;
  get diagnostics v_maj = row_count;
  if v_maj <> 137 then raise exception 'ÉCHEC : % fiches modifiées au lieu de 137 : tout est annulé.', v_maj; end if;

  -- CONTRÔLES
  if (select count(*) from public.etablissements) <> 4188 then raise exception 'ÉCHEC : nombre de fiches changé : tout est annulé.'; end if;
  select count(*) into v_diff from public.etablissements e join public.etablissements_sauvegarde_20261024 s using (id)
   where to_jsonb(e) is distinct from to_jsonb(s);
  if v_diff <> 137 then raise exception 'ÉCHEC : % fiches différentes de la sauvegarde au lieu de 137 : tout est annulé.', v_diff; end if;
  select count(*) into v_autres from public.etablissements e join public.etablissements_sauvegarde_20261024 s using (id)
   where (to_jsonb(e) - 'categorie' - 'sous_categorie') is distinct from (to_jsonb(s) - 'categorie' - 'sous_categorie');
  if v_autres <> 0 then raise exception 'ÉCHEC : une autre colonne a changé (% fiches) : tout est annulé.', v_autres; end if;
  select count(*) into v_bad from public.etablissements e join _r using (id)
   where e.categorie <> 'superieur' or e.sous_categorie is distinct from _r.sc or e.secteur <> 'prive';
  if v_bad <> 0 then raise exception 'ÉCHEC : % fiches mal classées : tout est annulé.', v_bad; end if;
  if (select count(*) from public.etablissements where categorie = 'superieur') <> 215 + 17 + 137 then
    raise exception 'ÉCHEC : total supérieur inattendu : tout est annulé.';
  end if;

  if not v_valider then
    raise exception 'TEST À BLANC RÉUSSI : % fiches seraient reclassées en supérieur (126 grandes écoles, 11 universités), aucune autre modification. RIEN N''A ÉTÉ ENREGISTRÉ.', v_maj;
  end if;
  raise notice 'RECLASSEMENT TERMINÉ : % fiches passées en supérieur.', v_maj;
end;
$reclass$;

-- Vérification : attendu 3 lignes à true
select n, controle, ok from (
  select 1 as n, '137 fiches reclassées en supérieur' as controle,
    (select count(*) = 137 from public.etablissements e join public.etablissements_sauvegarde_20261024 s using (id)
      where e.categorie = 'superieur' and s.categorie <> 'superieur') as ok
  union all select 2, '4 188 fiches au total', (select count(*) = 4188 from public.etablissements)
  union all select 3, 'seules ces 137 fiches diffèrent de la sauvegarde',
    (select count(*) = 137 from public.etablissements e join public.etablissements_sauvegarde_20261024 s using (id)
      where to_jsonb(e) is distinct from to_jsonb(s))
) t order by n;
