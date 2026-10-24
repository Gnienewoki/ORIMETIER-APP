-- ============================================================
-- ORIMETIER — Import des filières officielles (ministère) : ÉTAPE 2 = MIGRATION RÉELLE (à lancer seulement après un test à blanc réussi)
--
-- Source : plateforme d'orientation des bacheliers du MESRS (pages « details », accès libre), lue le 23/10/2026.
-- Rappel des décisions : (1) remplir les 242 fiches existantes qui correspondent (237 écoles, jumelles incluses),
-- sans limite de 15 filières, filières visibles tout de suite (statut « valide »), catégories INCHANGÉES ;
-- (2) ne pas toucher aux écoles douteuses ; (3) créer 17 fiches pour les écoles privées absentes, avec code de récupération.
-- Rien n'est écrasé : une filière déjà présente (même nom et même diplôme) n'est pas ajoutée deux fois ;
-- une fiche déjà réclamée par son établissement n'est PAS modifiée.
-- Chaque filière ajoutée porte la marque "src":"mesrs-2026-10-23" ; chaque fiche créée a un id « ms_<n° ministère> ».
-- Attendu : 2116 filières ajoutées au plus, 17 fiches créées (142 filières).
-- GARDES (arrêt, rien n'est modifié) : base à 4 171 fiches ; sauvegarde présente et identique en nombre ; import jamais lancé ;
-- fonction des codes présente ; toutes les fiches visées existent.
-- Fichier à lancer EN ENTIER, sans rien sélectionner.
-- ============================================================

DO $migration$
declare
  v_valider constant boolean := true;   -- false = TEST À BLANC (tout est annulé à la fin) ; true = RÉEL
  v_tag     constant text := 'mesrs-2026-10-23';
  v_date    text := to_char(now(), 'DD/MM/YYYY');
  v_avant integer; v_apres integer; v_maj integer := 0; v_ajout integer := 0; v_ignorees integer := 0;
  v_crees integer := 0; v_ecarts integer; v_manquants integer; v_bad integer;
  r record; v_exist jsonb; v_new jsonb;
begin
  -- GARDES
  select count(*) into v_avant from public.etablissements;
  if v_avant is distinct from 4171 then raise exception 'GARDE : % fiches au lieu de 4 171 : rien n''est modifié.', v_avant; end if;
  if to_regclass('public.etablissements_sauvegarde_20261023') is null
     or (select count(*) from public.etablissements_sauvegarde_20261023) <> 4171 then
    raise exception 'GARDE : sauvegarde absente ou incomplète : rien n''est modifié.';
  end if;
  if exists (select 1 from public.etablissements e, jsonb_array_elements(coalesce(e.filieres_proposees,'[]'::jsonb)) f where f->>'src' = v_tag)
     or exists (select 1 from public.etablissements where id like 'ms\_%') then
    raise exception 'GARDE : import déjà exécuté : rien n''est modifié.';
  end if;
  if to_regprocedure('public._etab_generer_code()') is null then
    raise exception 'GARDE : fonction _etab_generer_code absente : rien n''est modifié.';
  end if;

  create temp table _d(idx integer, nom text, diplome text) on commit drop;
  create temp table _c(etab_id text, idxs integer[]) on commit drop;
  create temp table _n(n integer, nom text, ville text, quartier text, sub text, idxs integer[]) on commit drop;

  insert into _d values
  (1, 'Assistanat de direction (AD)', 'BTS'),
  (2, 'Finances, comptabilité et gestion des entreprises (FCGE)', 'BTS'),
  (3, 'Gestion commerciale (GEC)', 'BTS'),
  (4, 'Informatique, développeur d''applications (IDA)', 'BTS'),
  (5, 'Logistique (LOG)', 'BTS'),
  (6, 'Ressources humaines et communication (RHC)', 'BTS'),
  (7, 'Systèmes électroniques et informatiques (SEI)', 'BTS'),
  (8, 'Tourisme hôtellerie (TH)', 'BTS'),
  (9, 'Industries agro-alimentaires et chimiques, option contrôle (IACC)', 'BTS'),
  (10, 'Génie civil, option bâtiment (GBAT)', 'BTS'),
  (11, 'Réseaux informatiques et télécommunications (RIT)', 'BTS'),
  (12, 'Génie civil, option travaux publics (GTP)', 'BTS'),
  (13, 'Agriculture tropicale, option production animale (ATPA)', 'BTS'),
  (14, 'Agriculture tropicale, option production végétale (ATPV)', 'BTS'),
  (15, 'Génie civil, option géomètre topographe (GGT)', 'BTS'),
  (16, 'Sciences de l''information (SIN)', 'BTS'),
  (17, 'Communication visuelle (CV)', 'BTS'),
  (18, 'Électrotechnique (ELT)', 'BTS'),
  (19, 'Électromécanique et mécatronique', 'Licence'),
  (20, 'Mines, géologie et pétrole (MGP)', 'BTS'),
  (21, 'Maintenance des systèmes de production (MSP)', 'BTS'),
  (22, 'Gestion des ressources humaines', 'Licence'),
  (23, 'Marketing management', 'Licence'),
  (24, 'Licence professionnelle en finance et comptabilité (PFC)', 'Licence'),
  (25, 'Anglais', 'Licence'),
  (26, 'Droit', 'Licence'),
  (27, 'Sciences économiques et de gestion', 'Licence'),
  (28, 'Sciences informatiques', 'Licence'),
  (29, 'Science de l''information et de la communication', 'Licence'),
  (30, 'Gestion de l''environnement et des ressources naturelles (GERN)', 'BTS'),
  (31, 'Hygiène et sécurité du travail (HST)', 'BTS'),
  (32, 'Sécurité incendie et prévention (SIP)', 'BTS'),
  (33, 'Électronique', 'Licence'),
  (34, 'Électrotechnique', 'Licence'),
  (35, 'Réseaux informatiques et télécommunications (RIT)', 'Licence'),
  (36, 'Gestion des collectivités territoriales (GCT)', 'BTS'),
  (37, 'Génie énergétique et environnement (GEE)', 'BTS'),
  (38, 'Industries agro-alimentaires et chimiques, option production (IACP)', 'BTS'),
  (39, 'Urbanisme (URBA)', 'BTS'),
  (40, 'Finance banque assurance (FBA)', 'Licence'),
  (41, 'Assistanat de direction', 'Licence'),
  (42, 'Professions immobilières', 'Licence'),
  (43, 'Génie civil', 'Licence'),
  (44, 'Management touristique et hôtelier', 'Licence'),
  (45, 'Arts et aménagement du cadre de vie (AACV)', 'BTS'),
  (46, 'Audit et contrôle de gestion', 'Licence'),
  (47, 'Marketing', 'Licence'),
  (48, 'Transport et logistique', 'Licence'),
  (49, 'Cosmétologie (COS)', 'BTS'),
  (50, 'Communication : communication entreprise, journaliste TV', 'Licence'),
  (51, 'Marketing digital', 'Licence'),
  (52, 'Optique lunetterie (OPL)', 'BTS'),
  (53, 'Moteur et mécanique automobile (2MA)', 'BTS'),
  (54, 'Informatique option génie logiciel', 'Licence'),
  (55, 'Information, communication et ressources humaines', 'Licence'),
  (56, 'Administration des affaires', 'Licence'),
  (57, 'Logistique et transport', 'Licence'),
  (58, 'Génie bâtiment', 'Licence'),
  (59, 'Mines géologie et pétrole', 'Licence'),
  (60, 'STRM', 'Licence'),
  (61, 'Histoire', 'Licence'),
  (62, 'Mathématiques', 'Licence'),
  (63, 'Philosophie', 'Licence'),
  (64, 'Sciences de la vie et de la terre', 'Licence'),
  (65, 'Aménagement parcours gestion foncière', 'Licence'),
  (66, 'Aménagement parcours géomatique', 'Licence'),
  (67, 'Chimie', 'Licence'),
  (68, 'Génie électrique parcours automatismes et systèmes', 'Licence'),
  (69, 'Génie électrique parcours circuits intégrés', 'Licence'),
  (70, 'Gestion des collectivités locales', 'Licence'),
  (71, 'Génie industriel et maintenance', 'Licence'),
  (72, 'Lettre moderne', 'Licence'),
  (73, 'Logistique', 'Licence'),
  (74, 'Management des secteurs de la santé', 'Licence'),
  (75, 'Management des secteurs miniers', 'Licence'),
  (76, 'Physique', 'Licence'),
  (77, 'Sciences de l’éducation', 'Licence'),
  (78, 'Gestion commerciale', 'Licence'),
  (79, 'Industries agro-alimentaires', 'Licence'),
  (80, 'Psychologie', 'Licence'),
  (81, 'Sociologie', 'Licence'),
  (82, 'Sociologie et ethnologie', 'Licence'),
  (83, 'Sciences du langage et de la communication', 'Licence'),
  (84, 'Géographie', 'Licence'),
  (85, 'Sciences Politiques', 'Licence'),
  (86, 'Management du luxe', 'Licence'),
  (87, 'Tourisme du luxe', 'Licence');

  insert into _c values
  ('id1786376350176567486', array[1,2,3,4,5,6]),
  ('id1786376293192672240', array[2,3,4,7]),
  ('id17863762021151964', array[2,3,5,6,8]),
  ('id178637620241100158', array[2,3,9,4,5,6]),
  ('id1786376202171462745', array[1,2,10,3,5,6,11]),
  ('id1786376202185178463', array[2,10,3,12,4,5,6,11]),
  ('id1786376202100265290', array[2,3,4]),
  ('id1786376202101488124', array[13,14,2,10,3,15,4,5]),
  ('id1786376202117134082', array[1,13,14,2,10,3,4,6,11]),
  ('id17863762939851763', array[2,3,6]),
  ('id17863762027939338', array[1,2,3,4,5,6]),
  ('id178637620280966308', array[1,2,3,4,5,6]),
  ('id1786376202168516190', array[2,3,6]),
  ('id178637629350635198', array[1,2,3,4,5,6]),
  ('id178637629398505143', array[1,2,3,6]),
  ('id178637635047435467', array[2,3,5,6]),
  ('id178637635082168585', array[1,2,10,3,4,5,6,16,8]),
  ('id178637635068499924', array[1,2,3,4,5,6,11]),
  ('id1786462431113842214', array[1,2,3,4,5,6,11]),
  ('id178637635015964192', array[2,3,4,6]),
  ('id1786376350162445730', array[2,3,6]),
  ('id178637371315923644', array[1,2,3,4,5,6]),
  ('id1786376202178285013', array[2,3,4,6]),
  ('id178637620216485341', array[13,14,2,10,3,4,6,11,7,8]),
  ('id17863762935691567', array[13,14,17,2,3,12,5,11]),
  ('id17863762936664763', array[13,14,17,2,3,12,5,11]),
  ('id1786376293140513609', array[1,17,2,3,4,6,11,7,16]),
  ('id1786376202113396835', array[1,2,10,3,4,5,6,11,7,8]),
  ('id1786376350123883530', array[1,2,3]),
  ('id178637635017699489', array[2,3,4,6]),
  ('id1786376202182455908', array[2,3,4,5,6,11,7,8]),
  ('id178637620246753615', array[2,3,5]),
  ('id1786376350115356604', array[1,2,3,4,6,7,16,8]),
  ('id178637629321680944', array[2,3,4,6]),
  ('id178637620287412329', array[2,3,4,6,11,7]),
  ('id1786376202186491883', array[2,3,5,8]),
  ('id17863762027321866', array[2,3,4,6]),
  ('id178637620223585298', array[1,18,2,3,4,6,11,7]),
  ('id178637620237570712', array[1,17,2,10,3,4,5,6]),
  ('id178637620233718150', array[1,13,14,17,2,10,3,4,5,6,16,8,19]),
  ('id178637620264465424', array[13,14,18,2,10,3,9,4,20,21,6,11,7]),
  ('id1786376202192278633', array[2,3,4,5,6,11,7,8]),
  ('id1786376202129873686', array[1,2,3,4,20,6,11]),
  ('id178637629324271221', array[1,2,3,4,6,22,23,24]),
  ('id1786376202163820885', array[1,13,14,17,18,2,10,3,4,5,20,21,6,11,7,8]),
  ('id1786376293158849691', array[1,18,2,10,3,12,4,5,20,21,6,11,7,8,25,26,27,28]),
  ('id178637635051813871', array[1,6,16,29]),
  ('id178637635020504891', array[1,2,3,4,5,7]),
  ('id1786376293117149461', array[1,13,14,2,3,4,6,11,7,8]),
  ('id1786376293154673841', array[10,30,31,9,20,6,32]),
  ('id1786376293157727732', array[1,18,2,3,9,4,21,6,11,7,27,28,19,33,34,22,23,35]),
  ('id1786376350190254852', array[2,3,5,6]),
  ('id178637635036156154', array[2,3,4,5,6]),
  ('id1786376293164133258', array[13,14,2,10,36,3,12,4,6,11,16]),
  ('id1786376350124359663', array[2,3,4,5,6]),
  ('id178637635057124128', array[17,18,2,10,3,37,30,12,9,4,5,20,21,6,11,7,32,8]),
  ('id178637371313536460', array[1,13,14,2,10,3,9,38,4,6,11,7,8]),
  ('id1786376202191273033', array[1,17,3,5,6,16,8]),
  ('id178637620261244781', array[1,2,10,3,4,5,6,8]),
  ('id178637620295804223', array[1,13,14,2,10,3,4,5,6]),
  ('id1786376293101389797', array[1,13,14,2,10,3,4,5,6,16]),
  ('id1786376202139369514', array[1,17,18,2,10,3,37,30,4,5,21,6,11,7,16,8]),
  ('id17863762937272344', array[1,13,14,17,18,2,10,3,30,12,4,5,20,21,6,11,8]),
  ('id178637629395872399', array[1,18,2,3,4,5,21,6,11,7]),
  ('id1786376293102179880', array[18,2,10,3,12,4,5,20,6,11,39]),
  ('id1786376350160571090', array[1,2,5]),
  ('id178637629383681780', array[1,13,14,2,10,3,30,12,9,38,6,11,16,8,39]),
  ('id178637635073895315', array[1,13,14,2,10,3,4,5,6,11,7,16,8]),
  ('id1786376202173633931', array[1,2,3,4,5,6,7]),
  ('id178637629343996700', array[2,3,4,5,6,11]),
  ('id178637629314921517', array[1,18,2,10,36,3,9,38,4,5,20,6,7,8]),
  ('id178637629359370476', array[1,13,14,2,10,3,4,5,6]),
  ('id178637620212473615', array[1,13,14,17,2,10,3,30,12,4,20,21,6,7,8]),
  ('id17863762028224208', array[1,13,14,2,10,3,37,30,31,4,5,20,21,6,7,32]),
  ('id178637629396284594', array[1,18,2,3,4,5,6,11,7]),
  ('id1786376350590451', array[2,3,4,6]),
  ('id1786376293106580421', array[2,3,4,6]),
  ('id178637620263469032', array[13,14,18,2,10,3,9,4,20,21,6,11,7]),
  ('id17864626837193673', array[1,2,3,4,6,8]),
  ('id178637620225889446', array[2,3,4,11]),
  ('id178637620219593096', array[1,17,2,3,4,6]),
  ('id178637620248809341', array[1,17,2,3,6]),
  ('id1786376202125716021', array[1,17,18,2,3,4,5,6,11,7]),
  ('id178637629370381171', array[2,3,4,5,6,11,7]),
  ('id1786376350141719818', array[2,3,4,5,6]),
  ('id1786376293144472725', array[1,13,14,17,2,10,3,4,6,11,16]),
  ('id1786376293143589283', array[1,13,14,17,2,10,3,4,6,11,16]),
  ('id178637629338514915', array[1,13,14,2,10,3,12,4,5,20,6,7,8]),
  ('id178637629345181235', array[2,3,4,5,6,11]),
  ('id178637629358346418', array[1,2,3,4,5,6]),
  ('id178637629389281270', array[1,14,2,3,30,4,5,6]),
  ('id178637635084630769', array[2,3,4,5,6,11,7]),
  ('id178637635019720363', array[1,2,3,4,5,6,40]),
  ('id178637620217918552', array[17,2,10,3,4,5,6,11,8]),
  ('id178637620286487632', array[1,17,2,3,4,5,6,11,7,8]),
  ('id178637635074370137', array[1,13,14,2,10,3,15,12,4,5,6,8,39,41,28,42,22,43,44,23,24]),
  ('id1786376202110835373', array[36,3,5,20,6,16]),
  ('id178637629337673145', array[1,2,3,4,6]),
  ('id1786376202183894401', array[1,14,2,10,3,6]),
  ('id178637635049415477', array[1,2,10,3,4,5,6,16,8]),
  ('id178637620222202757', array[2,3]),
  ('id1786376350131690919', array[1,13,14,2,3,4,6]),
  ('id1786376350177638050', array[13,14,2,3,4,5,6]),
  ('id1786376293134644953', array[1,2,3,5,6]),
  ('id1786376350153471707', array[2,3,4,6,11]),
  ('id178637620289696053', array[1,13,14,2,3,4,6]),
  ('id178637620228788793', array[1,17,2,10,3,4,5,6,11,7,8]),
  ('id1786376293163395887', array[1,17,2,3,4,6,11,7,16,8]),
  ('id1786376350164728647', array[1,2,3,6]),
  ('id1786376350134386250', array[45,1,13,14,17,18,2,10,3,37,30,9,38,4,5,20,21,6,11,7,8]),
  ('id1786376350133555975', array[1,13,14,17,18,2,10,3,30,9,38,4,5,20,21,6,11,7,8]),
  ('id1786376202165559990', array[1,13,14,17,18,2,10,3,4,5,20,6,11,7,8]),
  ('id1786376350139105193', array[2,10,3,9,38,4,5,6,11,7,46,43,47,48]),
  ('id1786376350143400537', array[1,14,17,2,36,3,30,4,5,20,6,11,7,8]),
  ('id17863762931799810', array[1,2,3,4,5,6,11]),
  ('id1786376350136454349', array[45,1,13,14,49,17,18,2,10,36,3,30,9,38,4,5,20,21,6,11,7,8]),
  ('id178637620215397649', array[1,13,17,2,36,30,4,5,11,7,16]),
  ('id178637620224038', array[1,2,3,4,5,6,8]),
  ('id178637620257114809', array[17,3,4,6,11,16,50,51]),
  ('id1786376350122631424', array[1,2,3,9,38,4,5,21,6,7,32,8]),
  ('id178637635018480693', array[1,2,3,4,6,8]),
  ('id178637620294479918', array[1,2,3,4,5,6]),
  ('id178637620274825003', array[10,15,12,20]),
  ('id178637629328514314', array[1,17,2,36,3,12,4,5,6,11,7,8]),
  ('id1786376202159953821', array[1,13,14,49,17,18,2,10,36,3,30,9,38,4,5,20,21,6,11,7,8]),
  ('id1786376293135569565', array[1,2,3,4,5,6,11,7]),
  ('id178637620229358146', array[1,17,2,10,3,4,5,6,11,7,8]),
  ('id178637629329898140', array[1,2,10,36,3,4,6,11,16]),
  ('id178637629393269098', array[2,3,5]),
  ('id1786376293128953033', array[1,14,17,2,10,3,4,5,6,11,7,8]),
  ('id1786376202122370780', array[1,18,2,3,9,38,4,5,21,6,11,7]),
  ('id178637635058645005', array[1,17,18,2,10,3,37,30,12,9,4,5,20,21,6,11,7,32,8]),
  ('id178637635015126843', array[2,3,16]),
  ('id178637635040362162', array[1,2,3,4,5,6,11,32]),
  ('id1786376350128763030', array[52]),
  ('id17863737136497232', array[1,2,3,4,5,6]),
  ('id17863762029978297', array[13,14,2,10,3,4,5,20,6]),
  ('id178637620270316341', array[1,2,3,4,5,8]),
  ('id178637620290400587', array[2,3,4,6]),
  ('id178637620288760652', array[1,2,3,4,6]),
  ('id17863762024529401', array[1,2,3,4,5,6,11,7]),
  ('id178637620231647078', array[45,1,17,18,2,10,36,3,37,30,12,31,9,4,5,20,52,6,11,7,16,32,8]),
  ('id178637620219733194', array[1,2,10,3,12,4,5,20,6]),
  ('id1786376202160352594', array[1,13,17,18,2,10,3,12,4,5,20,6,11,8]),
  ('id178637629320224018', array[2,3,4,5,6]),
  ('id178637620239442594', array[1,2,3,4,6]),
  ('id178637629347885195', array[2,3,4,5,6,11]),
  ('id178637629371872449', array[14,2,3,4,6]),
  ('id1786376350659154', array[2,3,4,5,6,8]),
  ('id1786376202181468938', array[2,3,4,5,6,11,7,8]),
  ('id1786376202176484187', array[1,18,2,3,9,38,4,5,20,21,6,11,7]),
  ('id178637629311559669', array[2,3,4,5,6,11,7]),
  ('id178637629391704959', array[1,17,2,10,3,4,6,11,8]),
  ('id178637629361726081', array[1,2,3,4,5,6,11]),
  ('id1786376293176273221', array[1,13,14,17,18,2,10,3,30,12,9,38,4,5,20,21,6,7,8,39]),
  ('id1786376350129380404', array[1,13,14,49,17,18,2,10,3,37,30,9,38,4,5,20,21,6,11,7,8]),
  ('id1786376293186534174', array[13,14,2,10,3,12,4,5,6,16]),
  ('id178637629357325976', array[17,2,3,4,5,6]),
  ('id178637620210880945', array[13,14,2,10,3,4,5,20,6]),
  ('id17863762934890027', array[1,17,18,2,10,3,12,4,5,6,11,7,16,8]),
  ('id178637629332279574', array[2,36,3,37,31,9,4,5,20,6,11,8,22,23]),
  ('id1786376293100443691', array[1,2,3,4,6]),
  ('id1786376293161845066', array[18,2,3,4,11,7]),
  ('id178637635015663542', array[13,14,17,2,10,3,5,16,8]),
  ('id178637635063293545', array[17,2,4,6,11,16]),
  ('id1786376202175688741', array[2,10,3,4,5,20,6,7]),
  ('id178637620283529220', array[1,18,2,10,3,4,5,21,6,11,7,8]),
  ('id178637629344481060', array[2,3,9,4,5,6]),
  ('id178637620211852339', array[13,14,2,10,3,15,12,38,4,5,20,6,11]),
  ('id17863762021227553', array[13,14,2,10,3,4,5,20,6]),
  ('id178637635014456890', array[2,3,12,4,5,6,8]),
  ('id1786376293108638853', array[1,18,2,3,9,38,4,5,21,6,11,7]),
  ('id1786376350112667744', array[1,2,3,6]),
  ('id178637620272547562', array[10,15,12,20,39]),
  ('id1786376202177591072', array[2,3,4,6,11]),
  ('id178637629390717071', array[1,2,3,4,5,21,6,11,7,8]),
  ('id1786376350146606033', array[53,2,3,4,21,6,11]),
  ('id178637620234718947', array[1,2,3,4,5,21,6,11,7,8]),
  ('id178637629394190978', array[1,18,2,3,4,5,6,8]),
  ('id1786376202109293633', array[1,13,14,18,2,10,3,37,30,15,12,9,4,5,20,21,6,11,40,43,54,55]),
  ('id1786376202169922102', array[1,13,14,17,18,2,10,36,3,30,9,38,4,5,20,21,6,11,7,8]),
  ('id1786376202126476578', array[1,2,3,4,5,6,11,7]),
  ('id178637629322972353', array[2,3,4,5,6,8,56,22,54,23,35,48]),
  ('id1786376293123542406', array[1,13,14,2,3,4,5,6]),
  ('id17863763507149596', array[1,2,3,4,5,6]),
  ('id178637620277383587', array[1,2,3,4,5,6,11]),
  ('id1786376202198615953', array[1,2,3,4,5,6]),
  ('id178637629378631518', array[1,13,14,2,10,3,4,5,6,11,7,8]),
  ('id1786376350167425017', array[1,17,2,3,5,6,8]),
  ('id1786376293110802056', array[2,3,4,6]),
  ('id178637635013258845', array[45,1,13,14,49,17,18,2,10,36,3,37,30,9,38,4,5,20,21,6,11,7,8]),
  ('id178637629312211437', array[2,3,4,5,6,11,7]),
  ('id178637620276720577', array[10,15,12,20]),
  ('id178637629356559155', array[2,3,4,6]),
  ('id1786376293188350632', array[13,14,2,10,3,5,6,16]),
  ('id178637620215735337', array[1,13,14,49,17,18,2,10,36,3,37,30,9,38,4,5,20,21,6,11,7,8]),
  ('id1786376202167911312', array[1,13,14,17,18,2,10,3,4,5,6,11,7,8]),
  ('id178637629381885611', array[2,3,4,5,6]),
  ('id1786376202114531890', array[1,17,2,10,3,4,5,6,8]),
  ('id17863762026873155', array[1,13,14,2,10,3,4,5,20,21,6]),
  ('id178637629399255793', array[2,3,5,6]),
  ('id1786376202130468339', array[1,49,2,3,31,9,38,4,5,6,7]),
  ('id17863737133997056', array[2,3,4,5,6]),
  ('id178637629376895258', array[1,13,14,2,10,3,4,5,6,11,8]),
  ('id178637620254616269', array[2,3,4,5,6,11,8]),
  ('id1786376202127442363', array[1,2,3,4,6]),
  ('id1786376293145260089', array[1,17,2,10,3,4,5,6,11,16,8]),
  ('id1786376293137368448', array[1,17,2,3,4,6,11,16]),
  ('id178637620230532098', array[1,17,2,3,4,5,6,11,7,8]),
  ('id1786376350185104088', array[1,2,3,4,6,8]),
  ('id178637620213585', array[1,2,3,4,5,6,11,7,8]),
  ('id178637629310104244', array[2,3,4,6,11,7]),
  ('id17863762025693426', array[1,2,3,4,5,6,11,7]),
  ('id1786376293125677335', array[1,2,3,4,6]),
  ('id1786376202190459112', array[1,17,2,10,3,12,4,5,6,11,7,16,8]),
  ('id178637620240726062', array[2,3,4,5,6,11]),
  ('id1786376202172332223', array[13,14,18,2,10,3,9,4,20,6,11,7]),
  ('id1786376202184820581', array[13,14,18,2,10,3,9,4,20,6,11,7]),
  ('id1786376202187466672', array[2,6,11]),
  ('id1786376293184611761', array[13,14,2,10,3,5,6]),
  ('id178637620259640924', array[17,3,4,6,11,16]),
  ('id178637620266727241', array[1,18,2,10,3,37,30,5,20,21,6]),
  ('id1786376293147573336', array[53,1,13,17,18,2,10,3,4,21,6,11,16,8]),
  ('id178637635076810462', array[1,2,3,4,5,6,22,54,57,47,35,48]),
  ('id178637635080459728', array[1,2,3,4,5,6,22,54,57,47,35,48]),
  ('id1786376293107415574', array[1,14,17,18,2,10,3,12,4,5,20,6,11,8]),
  ('id178637635029786378', array[1,2,10,3,12,4,5,6,11,7,8]),
  ('id178637629317530606', array[1,2,3,4,5,6]),
  ('id17863763501383295', array[1,2,10,3,4,21,6,7]),
  ('id17863763503721906', array[1,14,17,18,2,10,3,37,30,12,9,4,5,20,6,11,7,8]),
  ('id178637371310580710', array[10,15,12,20,58,59]),
  ('id1786376293133290074', array[13,14]),
  ('id17863737134693043', array[45,1,17,18,2,10,3,37,30,12,31,9,38,4,5,20,21,6,11,7,16,32,39]),
  ('id178637620275671359', array[10,15,12,20]),
  ('id17863762938612038', array[1,17,18,2,10,3,12,4,5,6,11,7]),
  ('id178637635066694304', array[2,3,4,6]),
  ('id1786462431110121064', array[2,3,4,6]),
  ('id178637620243638309', array[13,14,2,3,4,6]),
  ('id178637620214952134', array[1,2,3,6]),
  ('id1786376202189732424', array[2,3,4,6,11]),
  ('id1786376350126740109', array[1,2,3,4,5,6]),
  ('id1786376350183395160', array[13,14,2,10,3]);

  insert into _n values
  (17, 'UNIVERSITE NORD SUD ANGRE -(UNS ANGRE)', 'ABIDJAN', 'COCODY', 'universite', array[26,27,60]),
  (143, 'ISAB (Institut Supérieur Africain d’Assurances Banque et Bourses)', 'ABIDJAN', 'COCODY', 'grande_ecole', array[1,17,2,3,4,6,11,7,16,8]),
  (145, 'INSTITUT SUPERIEUR DE FORMATION TECHNIQUE ET TERTIAIRE YOPOUGON -(ISFOTT)', 'ABIDJAN', 'YOPOUGON', 'grande_ecole', array[2,3,4,6]),
  (151, 'UNIVERSITY OF ABIDJAN -(UNI ABIDJAN)', 'ABIDJAN', 'COCODY', 'universite', array[1,2,3,4,6,27,28,54,47]),
  (167, 'UNIVERSITE DES SCIENCES ET TECHNOLOGIE DE COTE D''IVOIRE COCODY -(USTCI COCODY)', 'ABIDJAN', 'COCODY', 'universite', array[46,50,25,26,61,62,63,64,27,28,65,66,67,34,68,69,70,22,71,72,73,74,75,59,76,77,78,43,79,47,80,35,81]),
  (170, 'Université Tahaqa Sarê - UNISS (Université Internationale des Sciences Sociale Hampâté Bâh )', 'ABIDJAN', 'COCODY', 'universite', array[82,80,83,84,85]),
  (174, 'UNIVERSITE MUSULMANE AFRICAINE -(UMA)', 'ABIDJAN', 'COCODY', 'universite', array[25,26,27,85]),
  (176, 'UNIVERSITE NORD SUD PORT-BOUËT -(UNS PORT-BOUËT)', 'ABIDJAN', 'PORT BOUET', 'universite', array[26,27,60]),
  (177, 'UNIVERSITE NORD SUD COCODY -(UNS BONOUMIN)', 'ABIDJAN', 'COCODY', 'universite', array[26,27,86,87,60]),
  (178, 'UNIVERSITE NORD SUD YOPOUGON -(UNS YOPOUGON)', 'ABIDJAN', 'YOPOUGON', 'universite', array[26,27,60]),
  (179, 'UNIVERSITE NORD SUD DIMBOKRO -(UNS DIMBOKRO)', 'DIMBOKRO', null, 'universite', array[26,27,60]),
  (226, 'POLYTECH ABIDJAN', 'ABIDJAN', 'COCODY', 'grande_ecole', array[10,12,5,8,42]),
  (260, 'IST SAINT JACQUES BOUAKE -(ISTSJBKE)', 'BOUAKE', null, 'grande_ecole', array[1,2,3,4,6]),
  (283, 'CENTRE UNIVERSITAIRE PROFESSIONNALISE -(CUP)', 'ABIDJAN', 'COCODY', 'universite', array[1,13,14,2,10,3,37,30,9,38,4,5,6,11,26,27,55,35]),
  (342, 'GROUPE ECOLE SUPERIEURE DE COMMERCE DE GESTION ET DE TECHNOLOGIE PLATEAU -(GROUPE ESCOGET PLATEAU)', 'ABIDJAN', 'PLATEAU', 'grande_ecole', array[2,3,30,4,5,6,11]),
  (360, 'UNIVERSITE INTERNATIONALE PRIVEE D''ABIDJAN -(UIPA)', 'ABIDJAN', 'RIVIERA', 'universite', array[1,13,14,2,10,3,4,5,20,6,11,7,16,26,27]),
  (362, 'GROUPE ECOLE SUPERIEURE DE COMMERCE DE GESTION ET DE TECHNOLOGIE COCODY -(GROUPE ESCOGET COCODY)', 'ABIDJAN', 'COCODY', 'grande_ecole', array[18,2,10,3,30,4,5,6,11,7]);

  if (select count(*) from _c) <> 242 or (select count(*) from _n) <> 17 then
    raise exception 'GARDE : données d''import incomplètes : rien n''est modifié.';
  end if;
  if exists (select 1 from _c c left join public.etablissements e on e.id = c.etab_id where e.id is null) then
    raise exception 'GARDE : une fiche visée n''existe plus : rien n''est modifié.';
  end if;
  if exists (select 1 from _n n join public.etablissements e on e.id = 'ms_' || n.n) then
    raise exception 'GARDE : une fiche à créer existe déjà : rien n''est modifié.';
  end if;

  -- 1) AJOUT DES FILIÈRES sur les fiches existantes (jamais d'écrasement, jamais de doublon, fiches réclamées ignorées)
  for r in select c.etab_id, c.idxs, e.filieres_proposees as fp, coalesce(e.reclame, false) as recl
           from _c c join public.etablissements e on e.id = c.etab_id order by c.etab_id loop
    if r.recl then v_ignorees := v_ignorees + 1; continue; end if;
    v_exist := coalesce(r.fp, '[]'::jsonb);
    select coalesce(jsonb_agg(jsonb_build_object('id', 'ms' || u.ord, 'nom', d.nom, 'diplome', d.diplome, 'conditions', '',
                                                 'statut', 'valide', 'date', v_date, 'src', v_tag) order by u.ord), '[]'::jsonb)
      into v_new
    from unnest(r.idxs) with ordinality as u(ix, ord)
    join _d d on d.idx = u.ix
    where not exists (select 1 from jsonb_array_elements(v_exist) f
                      where lower(f->>'nom') = lower(d.nom) and lower(f->>'diplome') = lower(d.diplome));
    if jsonb_array_length(v_new) > 0 then
      update public.etablissements set filieres_proposees = v_exist || v_new where id = r.etab_id;
      v_maj := v_maj + 1; v_ajout := v_ajout + jsonb_array_length(v_new);
    end if;
  end loop;

  -- 2) CRÉATION des fiches des écoles privées absentes (pré-inscrites, non réclamées, avec code de récupération)
  for r in select * from _n order by n loop
    insert into public.etablissements(
      id, nom, region, ville, quartier, type, responsable, tel, email, password,
      statut, active, date_inscription, filieres_proposees, photos,
      categorie, sous_categorie, secteur, pre_inscrit, reclame, code_recuperation, premium, demande_premium
    ) values (
      'ms_' || r.n, r.nom, null, r.ville, r.quartier, 'Supérieure', null, null, null, null,
      'valide', true, v_date,
      (select coalesce(jsonb_agg(jsonb_build_object('id', 'ms' || u.ord, 'nom', d.nom, 'diplome', d.diplome, 'conditions', '',
                                                    'statut', 'valide', 'date', v_date, 'src', v_tag) order by u.ord), '[]'::jsonb)
         from unnest(r.idxs) with ordinality as u(ix, ord) join _d d on d.idx = u.ix),
      '[]'::jsonb,
      'superieur', r.sub, 'prive', true, false, public._etab_generer_code(), false, false
    );
    v_crees := v_crees + 1;
  end loop;

  -- CONTRÔLES internes (une exception annule tout)
  select count(*) into v_apres from public.etablissements;
  if v_apres <> v_avant + v_crees or v_crees <> 17 then
    raise exception 'ÉCHEC : nombre de fiches incohérent (% -> %, % créées) : tout est annulé.', v_avant, v_apres, v_crees;
  end if;
  select count(*) into v_manquants from public.etablissements_sauvegarde_20261023 s
    where not exists (select 1 from public.etablissements e where e.id = s.id);
  if v_manquants <> 0 then raise exception 'ÉCHEC : % fiches disparues : tout est annulé.', v_manquants; end if;
  select count(*) into v_ecarts from public.etablissements e join public.etablissements_sauvegarde_20261023 s on s.id = e.id
    where to_jsonb(e) is distinct from to_jsonb(s);
  if v_ecarts <> v_maj then raise exception 'ÉCHEC : % fiches modifiées au lieu de % : tout est annulé.', v_ecarts, v_maj; end if;
  select count(*) into v_bad from public.etablissements e join public.etablissements_sauvegarde_20261023 s on s.id = e.id
    where to_jsonb(e) - 'filieres_proposees' is distinct from to_jsonb(s) - 'filieres_proposees';
  if v_bad <> 0 then raise exception 'ÉCHEC : % fiches ont une autre colonne modifiée que les filières : tout est annulé.', v_bad; end if;
  if (select count(*) from public.etablissements e where e.id like 'ms\_%' and e.code_recuperation !~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$') <> 0
     or (select count(distinct code_recuperation) from public.etablissements where id like 'ms\_%') <> 17 then
    raise exception 'ÉCHEC : codes de récupération invalides ou en double : tout est annulé.';
  end if;
  if (select count(*) from public.etablissements e, jsonb_array_elements(e.filieres_proposees) f
        where f->>'src' = v_tag and f->>'statut' <> 'valide') <> 0 then
    raise exception 'ÉCHEC : une filière ajoutée n''est pas « valide » : tout est annulé.';
  end if;
  if (select count(*) from public.etablissements e, jsonb_array_elements(e.filieres_proposees) f where f->>'src' = v_tag) <> v_ajout + 142 then
    raise exception 'ÉCHEC : nombre de filières ajoutées incohérent : tout est annulé.';
  end if;

  raise notice 'IMPORT TERMINÉ : % fiches remplies (% filières), % ignorées (réclamées), % fiches créées.', v_maj, v_ajout, v_ignorees, v_crees;
end;
$migration$;

-- Vérification finale + CODES DE RÉCUPÉRATION des fiches créées (à exporter en CSV et à conserver HORS de l'app)
select n, controle, ok from (
  select 1 as n, '4 171 + 17 = ' || (4171 + 17) || ' fiches' as controle, (select count(*) = 4171 + 17 from public.etablissements) as ok
  union all select 2, '17 fiches créées, pré-inscrites, non réclamées, avec code',
         (select count(*) = 17 and bool_and(pre_inscrit and not coalesce(reclame,false) and code_recuperation is not null) from public.etablissements where id like 'ms\_%')
  union all select 3, 'filières marquées mesrs-2026-10-23 présentes',
         (select count(*) > 0 from public.etablissements e, jsonb_array_elements(e.filieres_proposees) f where f->>'src' = 'mesrs-2026-10-23')
) t order by n;
-- (lancer ensuite, séparément, la requête des codes ci-dessous et exporter le résultat en CSV)
-- select nom, ville, quartier, sous_categorie, code_recuperation from public.etablissements where id like 'ms\_%' order by nom;
