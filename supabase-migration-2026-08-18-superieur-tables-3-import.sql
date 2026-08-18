-- ============================================================
-- ORIMETIER — Migration data-superieur.js → Supabase
-- PHASE 3 / 5 : import des données actuelles de data-superieur.js dans les
-- 5 tables créées en Phase 1 (universites, universite_filieres,
-- debouches_filieres, grandes_ecoles, grande_ecole_filieres).
--
-- Périmètre : uniquement les universités et grandes écoles PUBLIQUES
-- (aujourd'hui dans data-superieur.js). Les universités/grandes écoles
-- privées sont déjà dans la table etablissements existante et ne sont pas
-- concernées par ce script.
--
-- Ce script n'insère QUE les données déjà présentes dans data-superieur.js
-- (aucune donnée nouvelle) et ne touche à aucun fichier du site
-- (superieur.js / data-superieur.js / superieur.html continuent de servir
-- les données statiques comme avant, ce script n'est pas encore branché au
-- site). La colonne "contact" ajoutée en Phase 2 reste NULL ici — à
-- remplir manuellement plus tard.
--
-- Rejouable sans erreur : universites, debouches_filieres et grandes_ecoles
-- ont déjà une clé primaire naturelle (code / nom / id) utilisée comme
-- cible ON CONFLICT. universite_filieres et grande_ecole_filieres utilisent
-- un id auto-généré (pas de clé métier) : on crée d'abord un index unique
-- sur (université, nom) et (école, nom) — vérifié sans doublon dans les
-- données source — pour pouvoir cibler ON CONFLICT dessus aussi.
--
-- Ordre d'insertion : universites avant universite_filieres (FK), et
-- grandes_ecoles avant grande_ecole_filieres (FK).
--
-- À exécuter en une fois dans l'éditeur SQL de Supabase, après les Phases
-- 1 et 2.
-- ============================================================

-- ------------------------------------------------------------
-- Index uniques nécessaires pour ON CONFLICT (rejouabilité)
-- ------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS ux_universite_filieres_univ_nom
  ON public.universite_filieres (universite_code, nom);

CREATE UNIQUE INDEX IF NOT EXISTS ux_grande_ecole_filieres_ecole_nom
  ON public.grande_ecole_filieres (grande_ecole_id, nom);

-- ============================================================
-- 1) universites (9 lignes) — FK requise par universite_filieres
-- ============================================================
INSERT INTO public.universites (code, nom, ordre) VALUES
  ('UFHB', 'Université Félix Houphouët-Boigny (Abidjan-Cocody)', 0),
  ('UAO', 'Université Alassane Ouattara (Bouaké)', 1),
  ('UNA', 'Université Nangui Abrogoua (Abobo-Adjamé)', 2),
  ('UJLOG', 'Université Jean Lorougnon Guédé (Daloa)', 3),
  ('UPGC', 'Université Péléforo Gon Coulibaly (Korhogo)', 4),
  ('USP', 'Université de San Pédro', 5),
  ('UBOND', 'Université de Bondoukou', 6),
  ('UMAN', 'Université de Man', 7),
  ('UVCI', 'Université Virtuelle de Côte d''Ivoire', 8)
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- 2) universite_filieres (84 lignes)
-- ============================================================
INSERT INTO public.universite_filieres (universite_code, nom, bac, age, criteres, numero_source, ordre) VALUES
  ('UFHB', 'Allemand', 'Toutes séries', '23 ans', 'All 12, Franç 10, Anglais 09', 1, 0),
  ('UFHB', 'Portugais', 'Toutes séries', '23 ans', 'Esp 12, Franç 10, Anglais 09', 2, 1),
  ('UFHB', 'Anglais', 'Toutes séries', '23 ans', 'Anglais 12, Franç 10, LV2 09', 3, 2),
  ('UFHB', 'Espagnol', 'Toutes séries', '23 ans', 'Esp 12, Franç 10, Anglais 09', 4, 3),
  ('UFHB', 'Lettres modernes', 'Toutes séries', '23 ans', 'Franç 12, Philo 09, LV2 09', 5, 4),
  ('UFHB', 'Sciences du Langage', 'Toutes séries', '23 ans', 'Franç 12, Philo 10, Maths 09 (D)', 6, 5),
  ('UFHB', 'Géographie', 'Toutes séries', '23 ans', 'Hist. Géo 12, Franç 10, Philo 10, Maths 09 (D)', 7, 6),
  ('UFHB', 'Histoire', 'Toutes séries', '23 ans', 'Hist. Géo 12, Philo 10, Franç 10', 8, 7),
  ('UFHB', 'Philosophie', 'Toutes séries', '23 ans', 'Philo 12, Franç 10, Hist. Géo 10', 9, 8),
  ('UFHB', 'Psychologie', 'Toutes séries', '23 ans', 'Franç 10, Philo 10, SVT 10 (D)', 10, 9),
  ('UFHB', 'Sociologie', 'Toutes séries', '23 ans', 'Philo 10, Franç 10, Hist. Géo 10', 11, 10),
  ('UFHB', 'Anthropologie', 'Toutes séries', '23 ans', 'Philo 10, Franç 10, Hist. Géo 10', 12, 11),
  ('UFHB', 'Arts Plastiques', 'Toutes séries', '23 ans', 'Arts plastiques 12, Franç 10, Angl 10', 13, 12),
  ('UFHB', 'Arts du Spectacle', 'Toutes séries', '23 ans', 'Philo 10, Franç 12, Anglais 10', 14, 13),
  ('UFHB', 'Musique et Musicologie', 'Toutes séries', '23 ans', 'Musique 12, Franç 10, Anglais 10', 15, 14),
  ('UFHB', 'Maths- Informatiques', 'C, D, E', '23 ans', 'Maths C12,D14,E11 ; Physiques C10,D14,E10', 16, 15),
  ('UFHB', 'Physique- Chimie (PC)', 'C, D, E', '23 ans', 'Maths C11,D12,E11 ; Physiques C11,D12,E10', 17, 16),
  ('UFHB', 'Maths- Physique- Chimie- Technologie(MPCT)', 'C, D, E', '23 ans', 'Maths C12,D14,E12 ; Physiques C12,D14,E12', 18, 17),
  ('UFHB', 'Maths- Physique- Technologie (MPT)', 'C, D, E', '23 ans', 'Maths C12,D14,E12 ; Physiques C12,D11,E10 ; Anglais C10,D11,E10', 19, 18),
  ('UFHB', 'Chimie-Biologie- Géologie (CBG)', 'C, D, E', '23 ans', 'Maths C11,D12,E11 ; Physiques C/D12, Svt C/D12', 20, 19),
  ('UFHB', 'Sciences de la Terre et des Ressources Minières (STRM)', 'C, D, E', '23 ans', 'Maths C11,D12,E11 ; Physiques C/D12, Svt C/D12', 21, 20),
  ('UFHB', 'Biosciences', '-', '-', '-', 22, 21),
  ('UFHB', 'Criminologie', 'A, B, C, D, G1', '23 ans', 'Philo 12, Franç 10, Hist. Géo 10', 23, 22),
  ('UFHB', 'Sciences Économiques', 'A1, B, C, D, G2', '23 ans', 'Maths A1/B14,C12,D12,G2 15 ; Franc 11, Anglais 11', 24, 23),
  ('UFHB', 'Médecine', 'C, D', '22 ans', 'Math 11, Phys 11, Svt 11', 28, 24),
  ('UFHB', 'Odontostomatologie', 'C, D', '22 ans', 'Math 11, Phys 11, Svt 12', 28, 25),
  ('UFHB', 'Pharmacie', 'C, D', '22 ans', 'Math 11, Phys 11, Svt 13', 28, 26),
  ('UAO', 'Allemand', 'Toutes séries', '23 ans', 'All 12, Franç 10, Anglais 09', 1, 0),
  ('UAO', 'Anglais', 'Toutes séries', '23 ans', 'Anglais 12, Franç 10, LV2 09', 3, 1),
  ('UAO', 'Espagnol', 'Toutes séries', '23 ans', 'Esp 12, Franç 10, Anglais 09', 4, 2),
  ('UAO', 'Lettres modernes', 'Toutes séries', '23 ans', 'Franç 12, Philo 09, LV2 09', 5, 3),
  ('UAO', 'Sciences du Langage', 'Toutes séries', '23 ans', 'Franç 12, Philo 10, Maths 09 (D)', 6, 4),
  ('UAO', 'Géographie', 'Toutes séries', '23 ans', 'Hist. Géo 12, Franç 10, Philo 10, Maths 09 (D)', 7, 5),
  ('UAO', 'Histoire', 'Toutes séries', '23 ans', 'Hist. Géo 12, Philo 10, Franç 10', 8, 6),
  ('UAO', 'Philosophie', 'Toutes séries', '23 ans', 'Philo 12, Franç 10, Hist. Géo 10', 9, 7),
  ('UAO', 'Sociologie', 'Toutes séries', '23 ans', 'Philo 10, Franç 10, Hist. Géo 10', 11, 8),
  ('UAO', 'Biosciences', '-', '-', '-', 22, 9),
  ('UAO', 'Sciences Économiques', 'A1, B, C, D, G2', '23 ans', 'Maths A1/B14,C12,D12,G2 15 ; Franc 11, Anglais 11', 24, 10),
  ('UAO', 'Médecine', 'C, D', '22 ans', 'Math 11, Phys 11, Svt 11', 28, 11),
  ('UNA', 'Sciences de la nature', 'C, D', '22 ans', 'Svt 11, Angl 10, Math 12, Phys 11', 25, 0),
  ('UNA', 'Sciences Fondamentales Appliquées', 'C, D, E', '22 ans', 'Math C,E12,D14 ; Phys 12, Franc 10, Lv1 10', 26, 1),
  ('UNA', 'Écologie et Environnement', 'C, D', '23 ans', 'Math 12, Phys 12, Svt 12, Lv1 12', 27, 2),
  ('UJLOG', 'Géographie', 'Toutes séries', '23 ans', 'Hist. Géo 12, Franç 10, Philo 10, Maths 09 (D)', 7, 0),
  ('UJLOG', 'Histoire', 'Toutes séries', '23 ans', 'Hist. Géo 12, Philo 10, Franç 10', 8, 1),
  ('UJLOG', 'Sociologie', 'Toutes séries', '23 ans', 'Philo 10, Franç 10, Hist. Géo 10', 11, 2),
  ('UJLOG', 'Sciences Économiques', 'A1, B, C, D, G2', '23 ans', 'Maths A1/B14,C12,D12,G2 15 ; Franc 11, Anglais 11', 24, 3),
  ('UJLOG', 'Physique Chimie', 'C, D, E', '23 ans', 'C : Math 12, Phys 12, Angl 10, Franç 10 ; D : Math 14, Phys 14 ; E : Math 12, Phys 12, Angl 12', 41, 4),
  ('UJLOG', 'Ingénierie Agronomique Forestière et Environnementale', 'C, D', '22 ans', 'Math 12, Phys 12, Angl 10, Svt 12, Franç 11', 42, 5),
  ('UPGC', 'Anglais', 'Toutes séries', '23 ans', 'Anglais 12, Franç 10, LV2 09', 3, 0),
  ('UPGC', 'Lettres modernes', 'Toutes séries', '23 ans', 'Franç 12, Philo 09, LV2 09', 5, 1),
  ('UPGC', 'Géographie', 'Toutes séries', '23 ans', 'Hist. Géo 12, Franç 10, Philo 10, Maths 09 (D)', 7, 2),
  ('UPGC', 'Sociologie', 'Toutes séries', '23 ans', 'Philo 10, Franç 10, Hist. Géo 10', 11, 3),
  ('UPGC', 'Maths- Informatiques', 'C, D, E', '23 ans', 'Maths C12,D14,E11 ; Physiques C10,D14,E10', 16, 4),
  ('UPGC', 'Sciences Économiques', 'A1, B, C, D, G2', '23 ans', 'Maths A1/B14,C12,D12,G2 15 ; Franc 11, Anglais 11', 24, 5),
  ('UPGC', 'Biologie Animale', 'C, D', '23 ans', 'Math 11, Phys 11, Svt 12, Franc 10, Angl 10', 30, 6),
  ('UPGC', 'Biologie Végétale', 'C, D', '23 ans', 'Math 11, Phys 11, Svt 12, Franc 10, Angl 10', 30, 7),
  ('UPGC', 'Économie et Gestion Agropastorale', 'C, D, E', '23 ans', 'Franc 10, Angl 10, Math 11, Phys 12, Svt 11', 31, 8),
  ('UPGC', 'Zootechnie', 'C, D, E', '23 ans', 'Franc 10, Angl 10, Math 11, Phys 12, Svt 11', 31, 9),
  ('UPGC', 'Physique Chimie', 'C, D, E', '23 ans', 'C : Math 12, Phys 12, Angl 10, Franç 10 ; D : Math 14, Phys 14 ; E : Math 12, Phys 12, Angl 12', 41, 10),
  ('USP', 'Sciences de la MER (SDM)', 'C, D, E, B, F1, F4, F7', '22 ans', 'C/D/E : Phys-Chim 12, SVT 12, Math 12, Franç 11, Angl 10, Hist-Géo 12 ; B : Économie 12 ; F1/F4/F7 : Physique-Chimie 12', 32, 0),
  ('USP', 'Agriculture, Ressources Halieutiques et Agro-Industries (ARHAI)', 'F7, C, D', '22 ans', 'F7 : Phys 12, Math 12, Chimie 12, Franç 12, Angl 12 ; C/D : Phys 12, Math 12, SVT 12, Franç 12, Angl 12', 33, 1),
  ('USP', 'UFR Logistique, Tourisme, Hôtellerie, Restauration (LTHR)', 'A, C, E, D, G, H', '22 ans', 'A : Franc 10, Hist-Géo 10, Angl 12, Math 10 ; C/E/D/G/H : Franc 10, Hist-Géo 10, Angl 10, Math 10', 34, 2),
  ('UBOND', 'Métrologie et Assurance Qualité (MAQ)', 'A1, C, D, E, F1, F2, F3', '21 ans', 'Maths 12, Physique 12, Français/SVT 11', 36, 0),
  ('UBOND', 'Génie Écologique Et Aménagement du Territoire (GEAT)', 'A1, C, D, E, F1, F2, F3', '21 ans', 'Maths 12, Physique 12, Français/SVT 11', 36, 1),
  ('UBOND', 'Management des Organisations et des Projets de Durabilité (MOPD)', 'A1, A2, B, C, D, E, F, G', '21 ans', 'Maths/Phys 11, Français 12, Hist. Géo 12, Philo 12', 36, 2),
  ('UBOND', 'Architecture d''Intérieur', 'BAC toutes séries', '23 ans', 'H/A/BTA : Fran 12, Spécialité 12, Ang 12, Philo 12 ; Autres séries : Fran 12, HG 12, Ang 12, Math 12', 37, 3),
  ('UBOND', 'Arts, Design et multimédia', 'H, A, BTA, Autres séries', '21 ans', 'H/A/BTA : Fran 12, Spécialité 12, Ang 12, Philo 12 ; Autres séries : Fran 12, HG 12, Ang 12, Math 12', 37, 4),
  ('UBOND', 'Orthophonie : Discipline Paramédicale', 'A1, A2, C, D, E', '23 ans', '-', 38, 5),
  ('UBOND', 'Politique de Sécurité et de Géostratégie', 'BAC toutes séries', '23 ans', 'Franc 10, Angl 10, Philo 10, Hist. Géo 10', 39, 6),
  ('UMAN', 'Maths- Informatiques', 'C, D, E', '23 ans', 'Maths C12,D14,E11 ; Physiques C10,D14,E10', 16, 0),
  ('UMAN', 'Physique- Chimie (PC)', 'C, D, E', '23 ans', 'Maths C11,D12,E11 ; Physiques C11,D12,E10', 17, 1),
  ('UMAN', 'Géologie et Matériaux', 'C, D, E', '23 ans', 'C/D : Math 12, Phys 12, Angl 10, Svt 12, Franç 11', 40, 2),
  ('UMAN', 'Mines et Réservoirs', 'C, D, E', '23 ans', 'C/D : Math 12, Phys 12, Angl 10, Svt 12, Franç 11', 40, 3),
  ('UMAN', 'Géophysique', 'C, D, E', '23 ans', 'C/D : Math 12, Phys 12, Angl 10, Svt 12, Franç 11', 40, 4),
  ('UMAN', 'Ingénierie Agronomique Forestière et Environnementale', 'C, D', '22 ans', 'Math 12, Phys 12, Angl 10, Svt 12, Franç 11', 42, 5),
  ('UMAN', 'Classes Préparatoires aux Grandes Écoles (CPGE)', 'C, D, E', '22 ans', 'C/D : Math 12, Phys 12, Angl 12, Franç 10 ; E : Math 14, Phys 14, Angl 12', 43, 6),
  ('UVCI', 'Bases de Données (BD)', 'C, D, E, F1, F2, F3', '23 ans', 'C/E : Math 11, Phys 10 ; D : Math 12, Phys 11 ; F1/F2/F3 : Math 11, Phys 11, Angl 10, Franç 10', 44, 0),
  ('UVCI', 'Développement d''Applications et E-Services (DAS)', 'C, D, E, F1, F2, F3', '23 ans', 'C/E : Math 11, Phys 10 ; D : Math 12, Phys 11 ; F1/F2/F3 : Math 11, Phys 11, Angl 10, Franç 10', 45, 1),
  ('UVCI', 'Sciences et Technologies Géospatiales (STG)', 'C, D, E, F1, F2, F3', '23 ans', 'C/E : Math 11, Phys 11 ; D : Math 12, Phys 12 ; F1/F2/F3 : Math 11, Phys 11, Angl 10, Franç 10', 46, 2),
  ('UVCI', 'Communication Digitale (COM)', 'A1, A2, C, D, E, G1', '23 ans', 'A1/A2/G1 : Franç 12, Angl 12 ; C/D/E/Autres : Math 10-11, Angl 10-11, Franç 10-11', 47, 3),
  ('UVCI', 'E-Administration et Transformation Digitale (ATD)', 'A1, A2, B, C, D, E, G1, G2', '23 ans', 'Franç 12, Angl 12, Math 10, Hist-Géo 11', 48, 4),
  ('UVCI', 'E-Commerce et Marketing Digital (CMD)', 'A1, A2, B, C, D, E, G2', '23 ans', 'A1/A2/G2 : Franç 12, Angl 12 ; C/D/E/Autres : Math 10-11, Angl 10-11, Franç 10-11', 49, 5),
  ('UVCI', 'MultiMedia et Arts Numériques (MMX)', 'C, D, E, F1, F2, F3', '23 ans', 'C/E/F1/F2/F3 : Math 11, Phys 11 ; D : Math 12, Phys 11 ; Angl 10, Franç 10', 50, 6),
  ('UVCI', 'Réseaux et Sécurité Informatique (RSI)', 'C, D, E, F1, F2, F3', '23 ans', 'C/E : Math 11, Phys 10 ; D : Math 12, Phys 11 ; F1/F2/F3 : Math 11, Phys 11, Angl 10, Franç 10', 51, 7)
ON CONFLICT (universite_code, nom) DO NOTHING;

-- ============================================================
-- 3) debouches_filieres (63 lignes)
-- ============================================================
INSERT INTO public.debouches_filieres (nom, debouches) VALUES
  ('Allemand', 'Enseignement, recherche, traduction et interprétariat, métiers de l''information, administration publique, agences de voyage et tourisme, emplois autonomes.'),
  ('Portugais', 'Enseignement, recherche, traduction et interprétariat, métiers de l''information, administration publique, agences de voyage et tourisme, emplois autonomes.'),
  ('Anglais', 'Enseignement, recherche, administration territoriale (bibliothèque, maison de la culture), métiers des langues (traduction, interprétariat), attaché commercial, communication et relations publiques.'),
  ('Espagnol', 'Enseignement, recherche, traduction et rédaction, interprétariat, assistanat en communication, information, etc.'),
  ('Lettres modernes', 'Enseignement, recherche, culture, relations publiques, édition, communication.'),
  ('Sciences du Langage', 'Enseignement, recherche, information (presse écrite, audiovisuelle, relations publiques), communication d''entreprise, direction de communication, conception et réalisation de projets IEC/CCC, expertise en évaluation de projets de développement.'),
  ('Géographie', 'Enseignement, recherche, cartographe, climatologue, démographe, météorologue, consultant en aménagement du territoire, responsable de projets, télédétection.'),
  ('Histoire', 'Enseignement, recherche, agent du secteur privé et/ou public, métiers du livre (bibliothèques, centres de documentation, archives), édition, secteur culturel (musées, tourisme, patrimoine).'),
  ('Philosophie', 'Enseignement, recherche, administration publique et/ou privée, secteur tertiaire et communication.'),
  ('Psychologie', 'Cabinets de psychologie, médias, entreprises, psychologue hospitalier, psychologue scolaire (formation complémentaire), chargé de recrutement, consultance en administration publique (éducateur spécialisé).'),
  ('Sociologie', 'Enseignement, recherche, institutions publiques et/ou privées de recherche, organismes nationaux ou internationaux de consultance ou d''intervention.'),
  ('Anthropologie', 'Ministères (Éducation, Immigration, Culture, relations internationales), organismes de développement, médiateur culturel, projets de développement.'),
  ('Arts Plastiques', 'Enseignement, recherche, peinture, sculpture, photographie, muséologie.'),
  ('Arts du Spectacle', 'Enseignement, recherche, communication, documentation, animation socioculturelle, direction des industries artistiques et du spectacle, critique d''arts, journalisme culturel.'),
  ('Musique et Musicologie', 'Enseignement, recherche, écriture et composition, industries musicales, gestion et animation culturelle.'),
  ('Maths- Informatiques', 'Assurances, audit, banque, finance, gestion, biotechnologie, enseignement, télécommunications, technicien en statistique, administrateur de bases de données, programmeur, chargé d''études statistiques, chef de projet, statisticien, webmaster, ingénieur calcul scientifique.'),
  ('Physique- Chimie (PC)', 'Enseignement, recherche, administration publique et/ou privée (cosmétologie, industrie pharmaceutique, chimique).'),
  ('Maths- Physique- Chimie- Technologie(MPCT)', 'Enseignement, recherche, administration publique et/ou privée, responsable en Mathématiques, Physique, Chimie et Technologie informatique ou électronique.'),
  ('Maths- Physique- Technologie (MPT)', 'Enseignement, recherche, administration publique et/ou privée, responsable en Mathématiques, Physique et Technologie informatique ou électronique.'),
  ('Chimie-Biologie- Géologie (CBG)', 'Industrie pharmaceutique et biotechnologies (santé humaine, thérapie cellulaire et génique), industrie cosmétique, agroalimentaire, protection de l''environnement (eau, sols, espèces), recherche industrielle, assurance qualité en centres de recherche.'),
  ('Sciences de la Terre et des Ressources Minières (STRM)', 'Métiers de la géologie, des mines et ressources minières, recherche et enseignement.'),
  ('Criminologie', 'Directeur ou agent de prison, personnel des services de sécurité (police, gendarmerie), toxicologue, victimologue, formateur ou gestionnaire d''établissements pénitentiaires, éducateur spécialisé, administration générale, médiation pénale.'),
  ('Sciences Économiques', 'Enseignement, recherche, administration publique et/ou privée (PME, PMI), organismes internationaux.'),
  ('Sciences de la nature', 'Santé, agriculture, production animale, botanique et phytothérapie, industries pastorales, protection des végétaux, gestion des exploitations agropastorales, enseignement, recherche, naturothérapeute, administration publique ou privée.'),
  ('Sciences Fondamentales Appliquées', 'Organisation et gestion des entreprises, administration publique et/ou privée, domaines informatiques, interfaces de communication homme-machine, cryptographie, automobile, topographie, acoustique, astronomie, électronique.'),
  ('Écologie et Environnement', 'Gestion des déchets, assainissement, hydraulique, ressources en eau, instituts de recherche, collectivités locales et territoriales, sociétés agro-industrielles, administration publique ou privée, aquaculture, développement durable.'),
  ('Médecine', 'Enseignement, recherche, médecin, biochimiste, biologiste...'),
  ('Odontostomatologie', 'Enseignement, recherche, chirurgien-dentiste.'),
  ('Pharmacie', 'Enseignement, recherche, pharmacien, industries pharmaceutique et cosmétique.'),
  ('Agroforesterie', 'Domaine minier, géomatériaux, génie civil et géotechnique, entreprises d''eau potable (SODECI), réseaux d''assainissement, ouvrages hydrauliques, laboratoires nationaux et régionaux, gestion des déchets, biodiversité, projets de développement durable, foresterie, gestion d''aires protégées.'),
  ('Environnement', 'Domaine minier, géomatériaux, génie civil et géotechnique, entreprises d''eau potable (SODECI), réseaux d''assainissement, ouvrages hydrauliques, laboratoires nationaux et régionaux, gestion des déchets, biodiversité, projets de développement durable, foresterie, gestion d''aires protégées.'),
  ('Biologie Animale', 'Enseignement, recherche, entreprises agropastorales, exploitation agropastorale, production animale, consultant ou expert dans le domaine agropastoral.'),
  ('Biologie Végétale', 'Enseignement, recherche, exploitation agricole, agent de développement, recherche ou laboratoire, gestionnaire d''entreprises agricoles, biotechnicien, centres nationaux ou régionaux de recherche, vente de produits phytosanitaires ou issus de la biotechnologie.'),
  ('Économie et Gestion Agropastorale', 'ANADER, collectivités locales et/ou territoriales, coopératives agricoles, enseignement, recherche.'),
  ('Zootechnie', 'Filières liées à la production animale et à l''élevage, transformation et distribution du bétail, conduite d''élevages, offre de services aux éleveurs, CNRA et ANADER.'),
  ('Sciences de la MER (SDM)', 'Ingénieur écologue, conseiller, ingénieur océanographe, technicien en environnement, hydrobiologiste, consultant en environnement, etc.'),
  ('Agriculture, Ressources Halieutiques et Agro-Industries (ARHAI)', 'Ingénieur nutritionniste, ingénieur recherche-développement, responsable de mariculture, horticulteur, etc.'),
  ('UFR Logistique, Tourisme, Hôtellerie, Restauration (LTHR)', 'Agent commercial en transport ou consignataire, agent de manutention, agent aéroportuaire, déclarant en douane, gestionnaire de stock, majordome, etc.'),
  ('Urbanisme', 'Agent de conception, maître d''ouvrage ou d''études techniques, agence d''architecture, conservateur de monuments, carrière d''architecture, chef de projet ou d''études, constructeur de maisons ou d''immeubles.'),
  ('Architecture', 'Agent de conception, maître d''ouvrage ou d''études techniques, agence d''architecture, conservateur de monuments, carrière d''architecture, chef de projet ou d''études, constructeur de maisons ou d''immeubles.'),
  ('Métrologie et Assurance Qualité (MAQ)', 'Ingénieur en métrologie, aéronautique, automobile, laboratoire de métrologie et essais, gestion des déchets, responsable HSE, responsable en gestion des risques naturels et aménagement.'),
  ('Génie Écologique Et Aménagement du Territoire (GEAT)', 'Planification du développement durable des territoires, urbanisme et développement d''habitat, transport urbain et mobilité, énergie renouvelable, gestion de l''eau et des déchets, ingénieur territorial écologique, directeur de projets.'),
  ('Management des Organisations et des Projets de Durabilité (MOPD)', 'Consultant en durabilité, gestionnaire de projet environnemental, responsable d''approvisionnement durable, conseiller en certification et labélisation, gestionnaire de programme de compensation carbone, analyste en évaluation.'),
  ('Architecture d''Intérieur', 'Architecture du design, conception et réalisation de l''aménagement des espaces intérieurs, chef de projet, concepteur d''architecture d''intérieur, directeur artistique, concepteur lumière éclairagiste.'),
  ('Arts, Design et multimédia', 'Infographe, chef de projet jeux vidéo, designer graphique, illustrateur 2D/3D, UI designer, photographe, styliste-modéliste, designer plasticien.'),
  ('Orthophonie : Discipline Paramédicale', 'Cabinets privés, institutions publiques ou privées de rééducation spécialisée, services d''ORL, de pédiatrie, de néonatalogie, de neurologie.'),
  ('Politique de Sécurité et de Géostratégie', 'Organismes de développement, opérations de maintien de la paix, ONG, sécurité internationale.'),
  ('Géologie et Matériaux', 'Métiers de géologue (production, pétrolier, exploitant minier, chantier, géotechnicien), chef d''équipe mines, minérallurgiste, hydraulicien, enseignement, recherche.'),
  ('Mines et Réservoirs', 'Travaux de génie civil (métro, ouvrages hydroélectriques, routes, tunnels), exploitation minière, métiers de géologue, hydraulicien, consultant, enseignement, recherche.'),
  ('Géophysique', 'Métiers de géophysique (superviseur technique, directeur d''équipe minière ou pétrolière), métiers opérationnels ou de contrôle, hydrocarbures.'),
  ('Mathématique et Informatique', 'Administration publique ou privée, enseignement, recherche, domaines informatiques et financiers.'),
  ('Physique Chimie', 'Santé (secteur pharmaceutique, conception de molécules), bâtiment (matériaux haute performance), enseignement, recherche, énergie, agroalimentaire, sport, biotechnologie, électronique.'),
  ('Ingénierie Agronomique Forestière et Environnementale', 'Domaine agro-forestier et environnemental, gestion des ressources naturelles, enseignement, recherche.'),
  ('Bases de Données (BD)', 'Administrateur de base de données, architecte Cloud computing, business intelligence, sécurité des bases de données, entrepreneur numérique.'),
  ('Développement d''Applications et E-Services (DAS)', 'Intégrateur de solutions web, architecte application mobile et web, développeur d''applications.'),
  ('Sciences et Technologies Géospatiales (STG)', 'Technicien en système d''information géographique (SIG), technicien géomaticien, gestionnaire SIG, responsable géodésie et satellites, technicien SIG et télédétection.'),
  ('Communication Digitale (COM)', 'Chargé de communication, chargé de publicité en ligne, gestionnaire de médias sociaux, rédacteur web, responsable e-réputation.'),
  ('E-Administration et Transformation Digitale (ATD)', 'Expert en innovation des services publics, responsable portail numérique, chargé de prospective et veille technologique, consultant en maturité numérique, expert en dématérialisation des services administratifs.'),
  ('E-Commerce et Marketing Digital (CMD)', 'Consultant web analytique, acheteur d''espace publicitaire web, trafic manager, webmarketeur.'),
  ('MultiMedia et Arts Numériques (MMX)', 'Directeur artistique, designer multimédia, infographe, chef de projet multimédia.'),
  ('Réseaux et Sécurité Informatique (RSI)', 'Administrateur réseaux et sécurité informatique, gestionnaire de systèmes d''information.'),
  ('Biosciences', 'Recherche fondamentale et appliquée (biologie, biotechnologies), enseignement, laboratoires d''analyses biomédicales, industries pharmaceutiques et agroalimentaires, organismes de santé publique, poursuite en master/doctorat vers la biotechnologie, la biochimie ou la microbiologie.'),
  ('Classes Préparatoires aux Grandes Écoles (CPGE)', 'Voie de préparation intensive (2 ans) aux concours d''entrée des grandes écoles d''ingénieurs, de commerce et des écoles normales supérieures ; débouché principal : poursuite d''études en école d''ingénieurs, école de commerce ou école normale supérieure via concours, ou réorientation vers une licence universitaire avec équivalences.')
ON CONFLICT (nom) DO NOTHING;

-- ============================================================
-- 4) grandes_ecoles (9 lignes) — FK requise par grande_ecole_filieres
-- ============================================================
INSERT INTO public.grandes_ecoles (id, nom, tutelle, ordre) VALUES
  ('escae', 'ESCAE — École Sup. de Commerce et d''Administration des Entreprises', 'INP-HB', 0),
  ('esi', 'ESI — École Supérieure d''Industrie', 'INP-HB', 1),
  ('estp', 'ESTP — École Supérieure des Travaux Publics', 'INP-HB', 2),
  ('esmg', 'ESMG — École Supérieure des Mines et de Géologie', 'INP-HB', 3),
  ('escpe', 'ESCPE — École Supérieure de Chimie, Pétrole et de l''Énergie', 'INP-HB', 4),
  ('esa', 'ESA — École Supérieure d''Agronomie', 'INP-HB', 5),
  ('cpge-inphb', 'CPGE — Classes Préparatoires aux Grandes Écoles (INP-HB)', 'INP-HB', 6),
  ('esatic', 'ESATIC — École Supérieure Africaine des TIC', 'Ministère de tutelle des TIC', 7),
  ('istc-polytechnique', 'ISTC Polytechnique — Institut des Sciences et Techniques de la Communication', 'Ministère de la Communication et de la Francophonie', 8)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 5) grande_ecole_filieres (21 lignes)
-- ============================================================
INSERT INTO public.grande_ecole_filieres (grande_ecole_id, nom, bac, age, debouches, ordre) VALUES
  ('escae', 'Gestion et Administration des Entreprises (GAE)', 'A1, A2, B, C, D', '24 ans max', 'Entreprises de manufacturation, d''assurances, commerces ; promoteur des ventes, chef d''équipe commerciale, etc.', 0),
  ('escae', 'Finance, Comptabilité et Assurance', 'A1, A2, B, C, D, G2, BTCOMPTA', '24 ans max', 'Prestataires de services comptables, établissements financiers, administration publique, organismes nationaux et internationaux ; comptable, assistant de gestion.', 1),
  ('esi', 'Sciences et Technologies de l''Information et de la Communication', 'C, D, F2, BTSTIC', '24 ans max', 'Secteurs variés : transport, automobile, multimédia, médical ; responsable de maintenance informatique ou technique.', 0),
  ('esi', 'Sciences et Technologies du Génie Industriel (STGI)', 'C, D, E, F1, F3, BTSTGI', '24 ans max', 'Bureaux d''études, de production ; organisation de la production.', 1),
  ('esi', 'Sciences et Technologies du Génie des Procédés (STGP)', 'D, F7, BTSTGP', '24 ans max', 'Chef de produit, études, recherche et développement en industrie, assistant technique.', 2),
  ('estp', 'Génie Civil (GC)', 'C, D, E, F4, BTGC', '24 ans max', 'Agents d''entreprises du bâtiment, structures chargées d''infrastructures civiles, cabinets d''urbanistes.', 0),
  ('esmg', 'Mines et Géologie (MP)', 'C, D, E, BTMP', '24 ans max', 'Technicien d''exploitation minière, laboratoires d''analyse géochimique et pétrographique, cabinets liés à l''environnement.', 0),
  ('escpe', 'Chimie, Pétrole et Maintenance des Équipements (PME)', 'C, D, E, BTMP', '24 ans max', 'Entreprises de fabrication, plateformes pétrolières et énergétiques.', 0),
  ('esa', 'Techniciens Supérieurs en Agronomie (TSA)', 'C, D', '24 ans max', 'Instituts de recherche agricole, bureaux d''études, entreprises agroalimentaires, exploitations agricoles.', 0),
  ('cpge-inphb', 'Biologie, Chimie, Physique et Sciences de la Terre (BCPST)', 'C, D', '22 ans max', 'Concours d''entrée dans les grandes écoles d''ingénieurs et écoles vétérinaires.', 0),
  ('cpge-inphb', 'Économique et Commerciale option Scientifique (ECS)', 'A1, B, C, D', '22 ans max', 'Concours d''entrée dans les grandes écoles de commerce et de management.', 1),
  ('cpge-inphb', 'Physique, Chimie et Sciences Industrielles (PCSI)', 'C, D, E', '22 ans max', 'Concours d''entrée dans les grandes écoles d''ingénieurs.', 2),
  ('cpge-inphb', 'Mathématiques, Physique et Sciences Industrielles (MPSI)', 'C, E', '22 ans max', 'Concours d''entrée dans les grandes écoles d''ingénieurs.', 3),
  ('esatic', 'Développement d''applications et systèmes d''information (DASI)', 'C, D, E', '22 ans max', 'Développeur d''applications (web, mobile), testeur et intégrateur de solutions, administrateur de bases de données.', 0),
  ('esatic', 'Réseaux et télécommunications (RTEL)', 'C, D, E', '22 ans max', 'Technicien en réseaux et systèmes de télécommunications, architecte sécurité réseaux.', 1),
  ('esatic', 'Technologies du web et images numériques (TWIN)', 'C, D, E', '22 ans max', 'Développeur d''applications mobiles, solutions web et multimédia, webdesigner, développeur multimédia.', 2),
  ('istc-polytechnique', 'École des Arts et Images Numériques (EAIN)', 'A, B, C, D', 'Licence Pro (Bac) / Master Pro (Bac+3)', 'Maquettiste PAO, animateur 2D, designer, webdesigner, webmaster, animateur de site web ; en Master : infographie cinéma d''animation, effets spéciaux, web, jeux et applications.', 0),
  ('istc-polytechnique', 'École de Journalisme (EJ)', 'A, B, C, D', 'Licence Pro (Bac+3) / Master (Bac+5)', 'Rédacteur, journaliste reporter TV/presse, présentateur du JT, journaliste radio, rédacteur en chef, JRI, correspondant ; en Master : rédacteur en chef, secrétaire de rédaction, directeur régional, éditorialiste.', 1),
  ('istc-polytechnique', 'École de production audiovisuelle (EPA)', 'A, B, C, D', 'Licence Pro (Bac) / Master Pro (Bac+3)', 'Télévision/Radio : animateur de programmes, assistant réalisation, monteur, éclairagiste, script ; Master : administrateur de production, producteur TV/Radio/Web, réalisateur cinéma, scénariste, directeur.', 2),
  ('istc-polytechnique', 'École de Télécommunications et Technologies de l''Audiovisuel (ETTA)', 'A, B, C, D, E', '-', 'Télécoms : ingénieur d''étude, ingénieur systèmes, technicien de réseaux, développeur de logiciels ; Audiovisuel : gestionnaire de matériel technique, ingénieur du son et de l''image, technicien de maintenance.', 3),
  ('istc-polytechnique', 'École Publicité Marketing (EPM)', 'A, B, C, D', 'Licence Pro (Bac) / Master Pro (Bac+3)', 'Chargé de communication/digital, acheteur d''espaces publicitaires, analyste médias, responsable événementiel ; Master : community manager, directeur marketing, directeur création, chef de produit web/mobile, e-commerce.', 4)
ON CONFLICT (grande_ecole_id, nom) DO NOTHING;

-- ============================================================
-- Contrôle 1 : comptage par table (attendu : 9 / 84 / 63 / 9 / 21)
-- ============================================================
SELECT 'universites' AS table_name, count(*) AS nb FROM public.universites
UNION ALL
SELECT 'universite_filieres', count(*) FROM public.universite_filieres
UNION ALL
SELECT 'debouches_filieres', count(*) FROM public.debouches_filieres
UNION ALL
SELECT 'grandes_ecoles', count(*) FROM public.grandes_ecoles
UNION ALL
SELECT 'grande_ecole_filieres', count(*) FROM public.grande_ecole_filieres;

-- ============================================================
-- Contrôle 2 : noms de filière (universite_filieres) sans correspondance
-- exacte dans debouches_filieres — attendu : aucune ligne (0 résultat).
-- Une ligne ici signalerait un écart d'orthographe/accent entre les deux
-- dictionnaires source de data-superieur.js.
-- ============================================================
SELECT DISTINCT uf.nom
FROM public.universite_filieres uf
LEFT JOIN public.debouches_filieres df ON df.nom = uf.nom
WHERE df.nom IS NULL
ORDER BY uf.nom;

-- ============================================================
-- Contrôle 3 : nombre de filières par université
-- Attendu : UFHB=27, UAO=12, UNA=3, UJLOG=6, UPGC=11, USP=3, UBOND=7,
-- UMAN=7, UVCI=8
-- ============================================================
SELECT universite_code, count(*) AS nb_filieres
FROM public.universite_filieres
GROUP BY universite_code
ORDER BY universite_code;
