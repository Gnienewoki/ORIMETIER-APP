(function(){
// ============================================================
// Données extraites de "CONDITIONS D'ACCES - DEBOUCHES 2025" (DOB)
// ============================================================

const UNIVERSITES_NOMS = {
  UFHB: "Université Félix Houphouët-Boigny (Abidjan-Cocody)",
  UAO: "Université Alassane Ouattara (Bouaké)",
  UNA: "Université Nangui Abrogoua (Abobo-Adjamé)",
  UJLOG: "Université Jean Lorougnon Guédé (Daloa)",
  UPGC: "Université Péléforo Gon Coulibaly (Korhogo)",
  USP: "Université de San Pédro",
  UBOND: "Université de Bondoukou",
  UMAN: "Université de Man",
  UVCI: "Université Virtuelle de Côte d'Ivoire",
};

// Débouchés par filière (issus du tableau "FILIERES ET DEBOUCHES")
const DEBOUCHES_FILIERES = {
  "Allemand": "Enseignement, recherche, traduction et interprétariat, métiers de l'information, administration publique, agences de voyage et tourisme, emplois autonomes.",
  "Portugais": "Enseignement, recherche, traduction et interprétariat, métiers de l'information, administration publique, agences de voyage et tourisme, emplois autonomes.",
  "Anglais": "Enseignement, recherche, administration territoriale (bibliothèque, maison de la culture), métiers des langues (traduction, interprétariat), attaché commercial, communication et relations publiques.",
  "Espagnol": "Enseignement, recherche, traduction et rédaction, interprétariat, assistanat en communication, information, etc.",
  "Lettres modernes": "Enseignement, recherche, culture, relations publiques, édition, communication.",
  "Sciences du Langage": "Enseignement, recherche, information (presse écrite, audiovisuelle, relations publiques), communication d'entreprise, direction de communication, conception et réalisation de projets IEC/CCC, expertise en évaluation de projets de développement.",
  "Géographie": "Enseignement, recherche, cartographe, climatologue, démographe, météorologue, consultant en aménagement du territoire, responsable de projets, télédétection.",
  "Histoire": "Enseignement, recherche, agent du secteur privé et/ou public, métiers du livre (bibliothèques, centres de documentation, archives), édition, secteur culturel (musées, tourisme, patrimoine).",
  "Philosophie": "Enseignement, recherche, administration publique et/ou privée, secteur tertiaire et communication.",
  "Psychologie": "Cabinets de psychologie, médias, entreprises, psychologue hospitalier, psychologue scolaire (formation complémentaire), chargé de recrutement, consultance en administration publique (éducateur spécialisé).",
  "Sociologie": "Enseignement, recherche, institutions publiques et/ou privées de recherche, organismes nationaux ou internationaux de consultance ou d'intervention.",
  "Anthropologie": "Ministères (Éducation, Immigration, Culture, relations internationales), organismes de développement, médiateur culturel, projets de développement.",
  "Arts Plastiques": "Enseignement, recherche, peinture, sculpture, photographie, muséologie.",
  "Arts du Spectacle": "Enseignement, recherche, communication, documentation, animation socioculturelle, direction des industries artistiques et du spectacle, critique d'arts, journalisme culturel.",
  "Musique et Musicologie": "Enseignement, recherche, écriture et composition, industries musicales, gestion et animation culturelle.",
  "Maths- Informatiques": "Assurances, audit, banque, finance, gestion, biotechnologie, enseignement, télécommunications, technicien en statistique, administrateur de bases de données, programmeur, chargé d'études statistiques, chef de projet, statisticien, webmaster, ingénieur calcul scientifique.",
  "Physique- Chimie (PC)": "Enseignement, recherche, administration publique et/ou privée (cosmétologie, industrie pharmaceutique, chimique).",
  "Maths- Physique- Chimie- Technologie(MPCT)": "Enseignement, recherche, administration publique et/ou privée, responsable en Mathématiques, Physique, Chimie et Technologie informatique ou électronique.",
  "Maths- Physique- Technologie (MPT)": "Enseignement, recherche, administration publique et/ou privée, responsable en Mathématiques, Physique et Technologie informatique ou électronique.",
  "Chimie-Biologie- Géologie (CBG)": "Industrie pharmaceutique et biotechnologies (santé humaine, thérapie cellulaire et génique), industrie cosmétique, agroalimentaire, protection de l'environnement (eau, sols, espèces), recherche industrielle, assurance qualité en centres de recherche.",
  "Sciences de la Terre et des Ressources Minières (STRM)": "Métiers de la géologie, des mines et ressources minières, recherche et enseignement.",
  "Criminologie": "Directeur ou agent de prison, personnel des services de sécurité (police, gendarmerie), toxicologue, victimologue, formateur ou gestionnaire d'établissements pénitentiaires, éducateur spécialisé, administration générale, médiation pénale.",
  "Sciences Économiques": "Enseignement, recherche, administration publique et/ou privée (PME, PMI), organismes internationaux.",
  "Sciences de la nature": "Santé, agriculture, production animale, botanique et phytothérapie, industries pastorales, protection des végétaux, gestion des exploitations agropastorales, enseignement, recherche, naturothérapeute, administration publique ou privée.",
  "Sciences Fondamentales Appliquées": "Organisation et gestion des entreprises, administration publique et/ou privée, domaines informatiques, interfaces de communication homme-machine, cryptographie, automobile, topographie, acoustique, astronomie, électronique.",
  "Écologie et Environnement": "Gestion des déchets, assainissement, hydraulique, ressources en eau, instituts de recherche, collectivités locales et territoriales, sociétés agro-industrielles, administration publique ou privée, aquaculture, développement durable.",
  "Médecine": "Enseignement, recherche, médecin, biochimiste, biologiste...",
  "Odontostomatologie": "Enseignement, recherche, chirurgien-dentiste.",
  "Pharmacie": "Enseignement, recherche, pharmacien, industries pharmaceutique et cosmétique.",
  "Agroforesterie": "Domaine minier, géomatériaux, génie civil et géotechnique, entreprises d'eau potable (SODECI), réseaux d'assainissement, ouvrages hydrauliques, laboratoires nationaux et régionaux, gestion des déchets, biodiversité, projets de développement durable, foresterie, gestion d'aires protégées.",
  "Environnement": "Domaine minier, géomatériaux, génie civil et géotechnique, entreprises d'eau potable (SODECI), réseaux d'assainissement, ouvrages hydrauliques, laboratoires nationaux et régionaux, gestion des déchets, biodiversité, projets de développement durable, foresterie, gestion d'aires protégées.",
  "Biologie Animale": "Enseignement, recherche, entreprises agropastorales, exploitation agropastorale, production animale, consultant ou expert dans le domaine agropastoral.",
  "Biologie Végétale": "Enseignement, recherche, exploitation agricole, agent de développement, recherche ou laboratoire, gestionnaire d'entreprises agricoles, biotechnicien, centres nationaux ou régionaux de recherche, vente de produits phytosanitaires ou issus de la biotechnologie.",
  "Économie et Gestion Agropastorale": "ANADER, collectivités locales et/ou territoriales, coopératives agricoles, enseignement, recherche.",
  "Zootechnie": "Filières liées à la production animale et à l'élevage, transformation et distribution du bétail, conduite d'élevages, offre de services aux éleveurs, CNRA et ANADER.",
  "Sciences de la MER (SDM)": "Ingénieur écologue, conseiller, ingénieur océanographe, technicien en environnement, hydrobiologiste, consultant en environnement, etc.",
  "Agriculture, Ressources Halieutiques et Agro-Industries (ARHAI)": "Ingénieur nutritionniste, ingénieur recherche-développement, responsable de mariculture, horticulteur, etc.",
  "UFR Logistique, Tourisme, Hôtellerie, Restauration (LTHR)": "Agent commercial en transport ou consignataire, agent de manutention, agent aéroportuaire, déclarant en douane, gestionnaire de stock, majordome, etc.",
  "Urbanisme": "Agent de conception, maître d'ouvrage ou d'études techniques, agence d'architecture, conservateur de monuments, carrière d'architecture, chef de projet ou d'études, constructeur de maisons ou d'immeubles.",
  "Architecture": "Agent de conception, maître d'ouvrage ou d'études techniques, agence d'architecture, conservateur de monuments, carrière d'architecture, chef de projet ou d'études, constructeur de maisons ou d'immeubles.",
  "Métrologie et Assurance Qualité (MAQ)": "Ingénieur en métrologie, aéronautique, automobile, laboratoire de métrologie et essais, gestion des déchets, responsable HSE, responsable en gestion des risques naturels et aménagement.",
  "Génie Écologique Et Aménagement du Territoire (GEAT)": "Planification du développement durable des territoires, urbanisme et développement d'habitat, transport urbain et mobilité, énergie renouvelable, gestion de l'eau et des déchets, ingénieur territorial écologique, directeur de projets.",
  "Management des Organisations et des Projets de Durabilité (MOPD)": "Consultant en durabilité, gestionnaire de projet environnemental, responsable d'approvisionnement durable, conseiller en certification et labélisation, gestionnaire de programme de compensation carbone, analyste en évaluation.",
  "Architecture d'Intérieur": "Architecture du design, conception et réalisation de l'aménagement des espaces intérieurs, chef de projet, concepteur d'architecture d'intérieur, directeur artistique, concepteur lumière éclairagiste.",
  "Arts, Design et multimédia": "Infographe, chef de projet jeux vidéo, designer graphique, illustrateur 2D/3D, UI designer, photographe, styliste-modéliste, designer plasticien.",
  "Orthophonie : Discipline Paramédicale": "Cabinets privés, institutions publiques ou privées de rééducation spécialisée, services d'ORL, de pédiatrie, de néonatalogie, de neurologie.",
  "Politique de Sécurité et de Géostratégie": "Organismes de développement, opérations de maintien de la paix, ONG, sécurité internationale.",
  "Géologie et Matériaux": "Métiers de géologue (production, pétrolier, exploitant minier, chantier, géotechnicien), chef d'équipe mines, minérallurgiste, hydraulicien, enseignement, recherche.",
  "Mines et Réservoirs": "Travaux de génie civil (métro, ouvrages hydroélectriques, routes, tunnels), exploitation minière, métiers de géologue, hydraulicien, consultant, enseignement, recherche.",
  "Géophysique": "Métiers de géophysique (superviseur technique, directeur d'équipe minière ou pétrolière), métiers opérationnels ou de contrôle, hydrocarbures.",
  "Mathématique et Informatique": "Administration publique ou privée, enseignement, recherche, domaines informatiques et financiers.",
  "Physique Chimie": "Santé (secteur pharmaceutique, conception de molécules), bâtiment (matériaux haute performance), enseignement, recherche, énergie, agroalimentaire, sport, biotechnologie, électronique.",
  "Ingénierie Agronomique Forestière et Environnementale": "Domaine agro-forestier et environnemental, gestion des ressources naturelles, enseignement, recherche.",
  "Bases de Données (BD)": "Administrateur de base de données, architecte Cloud computing, business intelligence, sécurité des bases de données, entrepreneur numérique.",
  "Développement d'Applications et E-Services (DAS)": "Intégrateur de solutions web, architecte application mobile et web, développeur d'applications.",
  "Sciences et Technologies Géospatiales (STG)": "Technicien en système d'information géographique (SIG), technicien géomaticien, gestionnaire SIG, responsable géodésie et satellites, technicien SIG et télédétection.",
  "Communication Digitale (COM)": "Chargé de communication, chargé de publicité en ligne, gestionnaire de médias sociaux, rédacteur web, responsable e-réputation.",
  "E-Administration et Transformation Digitale (ATD)": "Expert en innovation des services publics, responsable portail numérique, chargé de prospective et veille technologique, consultant en maturité numérique, expert en dématérialisation des services administratifs.",
  "E-Commerce et Marketing Digital (CMD)": "Consultant web analytique, acheteur d'espace publicitaire web, trafic manager, webmarketeur.",
  "MultiMedia et Arts Numériques (MMX)": "Directeur artistique, designer multimédia, infographe, chef de projet multimédia.",
  "Réseaux et Sécurité Informatique (RSI)": "Administrateur réseaux et sécurité informatique, gestionnaire de systèmes d'information.",
  "Biosciences": "Recherche fondamentale et appliquée (biologie, biotechnologies), enseignement, laboratoires d'analyses biomédicales, industries pharmaceutiques et agroalimentaires, organismes de santé publique, poursuite en master/doctorat vers la biotechnologie, la biochimie ou la microbiologie.",
  "Classes Préparatoires aux Grandes Écoles (CPGE)": "Voie de préparation intensive (2 ans) aux concours d'entrée des grandes écoles d'ingénieurs, de commerce et des écoles normales supérieures ; débouché principal : poursuite d'études en école d'ingénieurs, école de commerce ou école normale supérieure via concours, ou réorientation vers une licence universitaire avec équivalences.",
};

// ============================================================
// UNIVERSITES : filières par université (N° = numéro du tableau source)
// ⚠️ Le tableau source encode l'association université ↔ filière par un
// quadrillage de cases colorées (une par université) plutôt que par du texte.
// La correspondance ci-dessous a été relevée visuellement page par page ;
// elle est fiable pour les filières générales (1-31, cases bien contrastées)
// et déduite du contexte pour les filières spécialisées 32-51 (à faire
// reconfirmer si vous avez le fichier source Excel/Word d'origine).
// ============================================================

const FIL = (n, nom, bac, age, criteres) => ({ n, nom, bac, age, criteres });

const FILIERES_BASE = [
  FIL(1, "Allemand", "Toutes séries", "23 ans", "All 12, Franç 10, Anglais 09"),
  FIL(2, "Portugais", "Toutes séries", "23 ans", "Esp 12, Franç 10, Anglais 09"),
  FIL(3, "Anglais", "Toutes séries", "23 ans", "Anglais 12, Franç 10, LV2 09"),
  FIL(4, "Espagnol", "Toutes séries", "23 ans", "Esp 12, Franç 10, Anglais 09"),
  FIL(5, "Lettres modernes", "Toutes séries", "23 ans", "Franç 12, Philo 09, LV2 09"),
  FIL(6, "Sciences du Langage", "Toutes séries", "23 ans", "Franç 12, Philo 10, Maths 09 (D)"),
  FIL(7, "Géographie", "Toutes séries", "23 ans", "Hist. Géo 12, Franç 10, Philo 10, Maths 09 (D)"),
  FIL(8, "Histoire", "Toutes séries", "23 ans", "Hist. Géo 12, Philo 10, Franç 10"),
  FIL(9, "Philosophie", "Toutes séries", "23 ans", "Philo 12, Franç 10, Hist. Géo 10"),
  FIL(10, "Psychologie", "Toutes séries", "23 ans", "Franç 10, Philo 10, SVT 10 (D)"),
  FIL(11, "Sociologie", "Toutes séries", "23 ans", "Philo 10, Franç 10, Hist. Géo 10"),
  FIL(12, "Anthropologie", "Toutes séries", "23 ans", "Philo 10, Franç 10, Hist. Géo 10"),
  FIL(13, "Arts Plastiques", "Toutes séries", "23 ans", "Arts plastiques 12, Franç 10, Angl 10"),
  FIL(14, "Arts du Spectacle", "Toutes séries", "23 ans", "Philo 10, Franç 12, Anglais 10"),
  FIL(15, "Musique et Musicologie", "Toutes séries", "23 ans", "Musique 12, Franç 10, Anglais 10"),
  FIL(16, "Maths- Informatiques", "C, D, E", "23 ans", "Maths C12,D14,E11 ; Physiques C10,D14,E10"),
  FIL(17, "Physique- Chimie (PC)", "C, D, E", "23 ans", "Maths C11,D12,E11 ; Physiques C11,D12,E10"),
  FIL(18, "Maths- Physique- Chimie- Technologie(MPCT)", "C, D, E", "23 ans", "Maths C12,D14,E12 ; Physiques C12,D14,E12"),
  FIL(19, "Maths- Physique- Technologie (MPT)", "C, D, E", "23 ans", "Maths C12,D14,E12 ; Physiques C12,D11,E10 ; Anglais C10,D11,E10"),
  FIL(20, "Chimie-Biologie- Géologie (CBG)", "C, D, E", "23 ans", "Maths C11,D12,E11 ; Physiques C/D12, Svt C/D12"),
  FIL(21, "Sciences de la Terre et des Ressources Minières (STRM)", "C, D, E", "23 ans", "Maths C11,D12,E11 ; Physiques C/D12, Svt C/D12"),
  FIL(22, "Biosciences", "-", "-", "-"),
  FIL(23, "Criminologie", "A, B, C, D, G1", "23 ans", "Philo 12, Franç 10, Hist. Géo 10"),
  FIL(24, "Sciences Économiques", "A1, B, C, D, G2", "23 ans", "Maths A1/B14,C12,D12,G2 15 ; Franc 11, Anglais 11"),
  FIL(25, "Sciences de la nature", "C, D", "22 ans", "Svt 11, Angl 10, Math 12, Phys 11"),
  FIL(26, "Sciences Fondamentales Appliquées", "C, D, E", "22 ans", "Math C,E12,D14 ; Phys 12, Franc 10, Lv1 10"),
  FIL(27, "Écologie et Environnement", "C, D", "23 ans", "Math 12, Phys 12, Svt 12, Lv1 12"),
  FIL(28, "Médecine", "C, D", "22 ans", "Math 11, Phys 11, Svt 11"),
  FIL(28, "Odontostomatologie", "C, D", "22 ans", "Math 11, Phys 11, Svt 12"),
  FIL(28, "Pharmacie", "C, D", "22 ans", "Math 11, Phys 11, Svt 13"),
  FIL(29, "Agroforesterie", "C, D", "23 ans", "Angl 10, Math 11, Phys 11, Svt 11"),
  FIL(29, "Environnement", "C, D", "23 ans", "Angl 10, Math 11, Phys 11, Svt 11"),
  FIL(30, "Biologie Animale", "C, D", "23 ans", "Math 11, Phys 11, Svt 12, Franc 10, Angl 10"),
  FIL(30, "Biologie Végétale", "C, D", "23 ans", "Math 11, Phys 11, Svt 12, Franc 10, Angl 10"),
  FIL(31, "Économie et Gestion Agropastorale", "C, D, E", "23 ans", "Franc 10, Angl 10, Math 11, Phys 12, Svt 11"),
  FIL(31, "Zootechnie", "C, D, E", "23 ans", "Franc 10, Angl 10, Math 11, Phys 12, Svt 11"),
  FIL(32, "Sciences de la MER (SDM)", "C, D, E, B, F1, F4, F7", "22 ans", "C/D/E : Phys-Chim 12, SVT 12, Math 12, Franç 11, Angl 10, Hist-Géo 12 ; B : Économie 12 ; F1/F4/F7 : Physique-Chimie 12"),
  FIL(33, "Agriculture, Ressources Halieutiques et Agro-Industries (ARHAI)", "F7, C, D", "22 ans", "F7 : Phys 12, Math 12, Chimie 12, Franç 12, Angl 12 ; C/D : Phys 12, Math 12, SVT 12, Franç 12, Angl 12"),
  FIL(34, "UFR Logistique, Tourisme, Hôtellerie, Restauration (LTHR)", "A, C, E, D, G, H", "22 ans", "A : Franc 10, Hist-Géo 10, Angl 12, Math 10 ; C/E/D/G/H : Franc 10, Hist-Géo 10, Angl 10, Math 10"),
  FIL(35, "Urbanisme", "C, D, E, F1, F2, F3, A2", "21 ans", "Test + entretien (ENSAU)"),
  FIL(35, "Architecture", "C, D, E, F1, F2, F3, A2", "21 ans", "Test + entretien (ENSAU)"),
  FIL(36, "Métrologie et Assurance Qualité (MAQ)", "A1, C, D, E, F1, F2, F3", "21 ans", "Maths 12, Physique 12, Français/SVT 11"),
  FIL(36, "Génie Écologique Et Aménagement du Territoire (GEAT)", "A1, C, D, E, F1, F2, F3", "21 ans", "Maths 12, Physique 12, Français/SVT 11"),
  FIL(36, "Management des Organisations et des Projets de Durabilité (MOPD)", "A1, A2, B, C, D, E, F, G", "21 ans", "Maths/Phys 11, Français 12, Hist. Géo 12, Philo 12"),
  FIL(37, "Architecture d'Intérieur", "BAC toutes séries", "23 ans", "H/A/BTA : Fran 12, Spécialité 12, Ang 12, Philo 12 ; Autres séries : Fran 12, HG 12, Ang 12, Math 12"),
  FIL(37, "Arts, Design et multimédia", "H, A, BTA, Autres séries", "21 ans", "H/A/BTA : Fran 12, Spécialité 12, Ang 12, Philo 12 ; Autres séries : Fran 12, HG 12, Ang 12, Math 12"),
  FIL(38, "Orthophonie : Discipline Paramédicale", "A1, A2, C, D, E", "23 ans", "-"),
  FIL(39, "Politique de Sécurité et de Géostratégie", "BAC toutes séries", "23 ans", "Franc 10, Angl 10, Philo 10, Hist. Géo 10"),
  FIL(40, "Géologie et Matériaux", "C, D, E", "23 ans", "C/D : Math 12, Phys 12, Angl 10, Svt 12, Franç 11"),
  FIL(40, "Mines et Réservoirs", "C, D, E", "23 ans", "C/D : Math 12, Phys 12, Angl 10, Svt 12, Franç 11"),
  FIL(40, "Géophysique", "C, D, E", "23 ans", "C/D : Math 12, Phys 12, Angl 10, Svt 12, Franç 11"),
  FIL(41, "Mathématique et Informatique", "C, D, E", "23 ans", "C : Math 12, Phys 12, Angl 10, Franç 10 ; D : Math 14, Phys 14 ; E : Math 12, Phys 12, Angl 12"),
  FIL(41, "Physique Chimie", "C, D, E", "23 ans", "C : Math 12, Phys 12, Angl 10, Franç 10 ; D : Math 14, Phys 14 ; E : Math 12, Phys 12, Angl 12"),
  FIL(42, "Ingénierie Agronomique Forestière et Environnementale", "C, D", "22 ans", "Math 12, Phys 12, Angl 10, Svt 12, Franç 11"),
  FIL(43, "Classes Préparatoires aux Grandes Écoles (CPGE)", "C, D, E", "22 ans", "C/D : Math 12, Phys 12, Angl 12, Franç 10 ; E : Math 14, Phys 14, Angl 12"),
  FIL(44, "Bases de Données (BD)", "C, D, E, F1, F2, F3", "23 ans", "C/E : Math 11, Phys 10 ; D : Math 12, Phys 11 ; F1/F2/F3 : Math 11, Phys 11, Angl 10, Franç 10"),
  FIL(45, "Développement d'Applications et E-Services (DAS)", "C, D, E, F1, F2, F3", "23 ans", "C/E : Math 11, Phys 10 ; D : Math 12, Phys 11 ; F1/F2/F3 : Math 11, Phys 11, Angl 10, Franç 10"),
  FIL(46, "Sciences et Technologies Géospatiales (STG)", "C, D, E, F1, F2, F3", "23 ans", "C/E : Math 11, Phys 11 ; D : Math 12, Phys 12 ; F1/F2/F3 : Math 11, Phys 11, Angl 10, Franç 10"),
  FIL(47, "Communication Digitale (COM)", "A1, A2, C, D, E, G1", "23 ans", "A1/A2/G1 : Franç 12, Angl 12 ; C/D/E/Autres : Math 10-11, Angl 10-11, Franç 10-11"),
  FIL(48, "E-Administration et Transformation Digitale (ATD)", "A1, A2, B, C, D, E, G1, G2", "23 ans", "Franç 12, Angl 12, Math 10, Hist-Géo 11"),
  FIL(49, "E-Commerce et Marketing Digital (CMD)", "A1, A2, B, C, D, E, G2", "23 ans", "A1/A2/G2 : Franç 12, Angl 12 ; C/D/E/Autres : Math 10-11, Angl 10-11, Franç 10-11"),
  FIL(50, "MultiMedia et Arts Numériques (MMX)", "C, D, E, F1, F2, F3", "23 ans", "C/E/F1/F2/F3 : Math 11, Phys 11 ; D : Math 12, Phys 11 ; Angl 10, Franç 10"),
  FIL(51, "Réseaux et Sécurité Informatique (RSI)", "C, D, E, F1, F2, F3", "23 ans", "C/E : Math 11, Phys 10 ; D : Math 12, Phys 11 ; F1/F2/F3 : Math 11, Phys 11, Angl 10, Franç 10"),
];

// Association N° -> universités qui proposent la filière (relevé visuel du quadrillage)
const UNIV_PAR_NUMERO = {
  1: ["UFHB", "UAO"],
  2: ["UFHB"],
  3: ["UFHB", "UAO", "UPGC"],
  4: ["UFHB", "UAO"],
  5: ["UFHB", "UPGC"],
  6: ["UFHB", "UAO"],
  7: ["UFHB", "UAO", "UJLOG", "UPGC"],
  8: ["UFHB", "UAO", "UJLOG"],
  9: ["UFHB"],
  10: ["UFHB"],
  11: ["UFHB", "UAO", "UJLOG", "UPGC"],
  12: ["UFHB"],
  13: ["UFHB"],
  14: ["UFHB"],
  15: ["UFHB"],
  16: ["UFHB", "UPGC", "UMAN"],
  17: ["UFHB", "UMAN"],
  18: ["UFHB"],
  19: ["UFHB"],
  20: ["UFHB"],
  21: ["UFHB"],
  22: ["UPGC"],
  23: ["UAO"],
  24: ["UFHB", "UAO", "UPGC", "USP"],
  25: ["UNA"],
  26: ["UNA"],
  27: ["UNA"],
  28: ["UFHB", "UAO"],
  29: ["UPGC"],
  30: ["UMAN"],
  31: ["UMAN"],
  32: ["USP"],
  33: ["USP"],
  34: ["USP"],
  35: ["UNA"],
  36: ["UNA"],
  37: ["UBOND"],
  38: ["UBOND"],
  39: ["UBOND"],
  40: ["UJLOG"],
  41: ["UJLOG"],
  42: ["UJLOG"],
  43: ["UPGC"],
  44: ["UVCI"],
  45: ["UVCI"],
  46: ["UVCI"],
  47: ["UVCI"],
  48: ["UVCI"],
  49: ["UVCI"],
  50: ["UVCI"],
  51: ["UVCI"],
};

// ------------------------------------------------------------
// EXCLUSIONS : filières à retirer de certaines universités
// (source : "FILIERES A RETIRER.docx" fourni par l'utilisateur)
// ------------------------------------------------------------
const EXCLUSIONS = [
  // (UAO) Université Alassane Ouattara
  { n: 23, nom: "Criminologie", univ: "UAO" },
  { n: 28, nom: "Odontostomatologie", univ: "UAO" },
  { n: 28, nom: "Pharmacie", univ: "UAO" },
  // (UNA) Université Nangui Abrogoua
  { n: 35, nom: "Urbanisme", univ: "UNA" },
  { n: 35, nom: "Architecture", univ: "UNA" },
  { n: 36, nom: "Métrologie et Assurance Qualité (MAQ)", univ: "UNA" },
  { n: 36, nom: "Génie Écologique Et Aménagement du Territoire (GEAT)", univ: "UNA" },
  { n: 36, nom: "Management des Organisations et des Projets de Durabilité (MOPD)", univ: "UNA" },
  // (UJLOG) Université Jean Lorougnon Guédé
  { n: 40, nom: "Géologie et Matériaux", univ: "UJLOG" },
  { n: 40, nom: "Mines et Réservoirs", univ: "UJLOG" },
  { n: 40, nom: "Géophysique", univ: "UJLOG" },
  { n: 41, nom: "Mathématique et Informatique", univ: "UJLOG" },
  // (UPGC) Université Péléforo Gon Coulibaly
  { n: 22, nom: "Biosciences", univ: "UPGC" },
  { n: 29, nom: "Agroforesterie", univ: "UPGC" },
  { n: 29, nom: "Environnement", univ: "UPGC" },
  { n: 43, nom: "Classes Préparatoires aux Grandes Écoles (CPGE)", univ: "UPGC" },
  // (USP) Université de San Pédro
  { n: 24, nom: "Sciences Économiques", univ: "USP" },
  // UMAN (Université de Man)
  { n: 30, nom: "Biologie Animale", univ: "UMAN" },
  { n: 30, nom: "Biologie Végétale", univ: "UMAN" },
  { n: 31, nom: "Économie et Gestion Agropastorale", univ: "UMAN" },
  { n: 31, nom: "Zootechnie", univ: "UMAN" },
];

function isExcluded(n, nom, univ) {
  return EXCLUSIONS.some((e) => e.n === n && e.nom === nom && e.univ === univ);
}

// ------------------------------------------------------------
// INCLUSIONS : filières à ajouter à certaines universités
// (source : "FILIERES A AJOUTER AUX UNIVERSITES.docx" fourni par l'utilisateur ;
// critères d'accès, BAC et âge repris du PDF officiel "CONDITIONS D'ACCES
// DEBOUCHES 2025" pour la filière correspondante — voir FILIERES_BASE)
// ------------------------------------------------------------
const INCLUSIONS = [
  // UFHB Université Félix Houphouët-Boigny
  { n: 22, nom: "Biosciences", univ: "UFHB" },
  { n: 23, nom: "Criminologie", univ: "UFHB" },
  // UAO Université Alassane Ouattara
  { n: 5, nom: "Lettres modernes", univ: "UAO" },
  { n: 9, nom: "Philosophie", univ: "UAO" },
  { n: 22, nom: "Biosciences", univ: "UAO" },
  // UJLOG Université Jean Lorougnon Guédé
  { n: 24, nom: "Sciences Économiques", univ: "UJLOG" },
  // UPGC Université Péléforo Gon Coulibaly
  { n: 41, nom: "Physique Chimie", univ: "UPGC" },
  { n: 30, nom: "Biologie Animale", univ: "UPGC" },
  { n: 30, nom: "Biologie Végétale", univ: "UPGC" },
  { n: 31, nom: "Économie et Gestion Agropastorale", univ: "UPGC" },
  { n: 31, nom: "Zootechnie", univ: "UPGC" },
  // Université de Bondoukou
  { n: 36, nom: "Métrologie et Assurance Qualité (MAQ)", univ: "UBOND" },
  { n: 36, nom: "Génie Écologique Et Aménagement du Territoire (GEAT)", univ: "UBOND" },
  { n: 36, nom: "Management des Organisations et des Projets de Durabilité (MOPD)", univ: "UBOND" },
  // Université de Man
  { n: 40, nom: "Géologie et Matériaux", univ: "UMAN" },
  { n: 40, nom: "Mines et Réservoirs", univ: "UMAN" },
  { n: 40, nom: "Géophysique", univ: "UMAN" },
  { n: 42, nom: "Ingénierie Agronomique Forestière et Environnementale", univ: "UMAN" },
  { n: 43, nom: "Classes Préparatoires aux Grandes Écoles (CPGE)", univ: "UMAN" },
];

function additionalUnivs(n, nom) {
  return INCLUSIONS.filter((e) => e.n === n && e.nom === nom).map((e) => e.univ);
}

// Construction de la structure UNIVERSITES : { code: [ {nom,bac,age,criteres}, ... ] }
const UNIVERSITES = {};
Object.keys(UNIVERSITES_NOMS).forEach((code) => (UNIVERSITES[code] = []));
FILIERES_BASE.forEach((f) => {
  const unis = (UNIV_PAR_NUMERO[f.n] || []).filter((code) => !isExcluded(f.n, f.nom, code));
  additionalUnivs(f.n, f.nom).forEach((code) => {
    if (!unis.includes(code)) unis.push(code);
  });
  unis.forEach((code) => {
    if (UNIVERSITES[code]) UNIVERSITES[code].push(f);
  });
});

// ============================================================
// GRANDES ECOLES PUBLIQUES
// ============================================================
const GE = (nom, bac, age, debouches) => ({ nom, bac, age, debouches });

const GRANDES_ECOLES = {
  "ESCAE — École Sup. de Commerce et d'Administration des Entreprises": {
    tutelle: "INP-HB",
    filieres: [
      GE("Gestion et Administration des Entreprises (GAE)", "A1, A2, B, C, D", "24 ans max", "Entreprises de manufacturation, d'assurances, commerces ; promoteur des ventes, chef d'équipe commerciale, etc."),
      GE("Finance, Comptabilité et Assurance", "A1, A2, B, C, D, G2, BTCOMPTA", "24 ans max", "Prestataires de services comptables, établissements financiers, administration publique, organismes nationaux et internationaux ; comptable, assistant de gestion."),
    ],
  },
  "ESI — École Supérieure d'Industrie": {
    tutelle: "INP-HB",
    filieres: [
      GE("Sciences et Technologies de l'Information et de la Communication", "C, D, F2, BTSTIC", "24 ans max", "Secteurs variés : transport, automobile, multimédia, médical ; responsable de maintenance informatique ou technique."),
      GE("Sciences et Technologies du Génie Industriel (STGI)", "C, D, E, F1, F3, BTSTGI", "24 ans max", "Bureaux d'études, de production ; organisation de la production."),
      GE("Sciences et Technologies du Génie des Procédés (STGP)", "D, F7, BTSTGP", "24 ans max", "Chef de produit, études, recherche et développement en industrie, assistant technique."),
    ],
  },
  "ESTP — École Supérieure des Travaux Publics": {
    tutelle: "INP-HB",
    filieres: [
      GE("Génie Civil (GC)", "C, D, E, F4, BTGC", "24 ans max", "Agents d'entreprises du bâtiment, structures chargées d'infrastructures civiles, cabinets d'urbanistes."),
    ],
  },
  "ESMG — École Supérieure des Mines et de Géologie": {
    tutelle: "INP-HB",
    filieres: [
      GE("Mines et Géologie (MP)", "C, D, E, BTMP", "24 ans max", "Technicien d'exploitation minière, laboratoires d'analyse géochimique et pétrographique, cabinets liés à l'environnement."),
    ],
  },
  "ESCPE — École Supérieure de Chimie, Pétrole et de l'Énergie": {
    tutelle: "INP-HB",
    filieres: [
      GE("Chimie, Pétrole et Maintenance des Équipements (PME)", "C, D, E, BTMP", "24 ans max", "Entreprises de fabrication, plateformes pétrolières et énergétiques."),
    ],
  },
  "ESA — École Supérieure d'Agronomie": {
    tutelle: "INP-HB",
    filieres: [
      GE("Techniciens Supérieurs en Agronomie (TSA)", "C, D", "24 ans max", "Instituts de recherche agricole, bureaux d'études, entreprises agroalimentaires, exploitations agricoles."),
    ],
  },
  "CPGE — Classes Préparatoires aux Grandes Écoles (INP-HB)": {
    tutelle: "INP-HB",
    filieres: [
      GE("Biologie, Chimie, Physique et Sciences de la Terre (BCPST)", "C, D", "22 ans max", "Concours d'entrée dans les grandes écoles d'ingénieurs et écoles vétérinaires."),
      GE("Économique et Commerciale option Scientifique (ECS)", "A1, B, C, D", "22 ans max", "Concours d'entrée dans les grandes écoles de commerce et de management."),
      GE("Physique, Chimie et Sciences Industrielles (PCSI)", "C, D, E", "22 ans max", "Concours d'entrée dans les grandes écoles d'ingénieurs."),
      GE("Mathématiques, Physique et Sciences Industrielles (MPSI)", "C, E", "22 ans max", "Concours d'entrée dans les grandes écoles d'ingénieurs."),
    ],
  },
  "ESATIC — École Supérieure Africaine des TIC": {
    tutelle: "Ministère de tutelle des TIC",
    filieres: [
      GE("Développement d'applications et systèmes d'information (DASI)", "C, D, E", "22 ans max", "Développeur d'applications (web, mobile), testeur et intégrateur de solutions, administrateur de bases de données."),
      GE("Réseaux et télécommunications (RTEL)", "C, D, E", "22 ans max", "Technicien en réseaux et systèmes de télécommunications, architecte sécurité réseaux."),
      GE("Technologies du web et images numériques (TWIN)", "C, D, E", "22 ans max", "Développeur d'applications mobiles, solutions web et multimédia, webdesigner, développeur multimédia."),
    ],
  },
  "ISTC Polytechnique — Institut des Sciences et Techniques de la Communication": {
    tutelle: "Ministère de la Communication et de la Francophonie",
    filieres: [
      GE("École des Arts et Images Numériques (EAIN)", "A, B, C, D", "Licence Pro (Bac) / Master Pro (Bac+3)", "Maquettiste PAO, animateur 2D, designer, webdesigner, webmaster, animateur de site web ; en Master : infographie cinéma d'animation, effets spéciaux, web, jeux et applications."),
      GE("École de Journalisme (EJ)", "A, B, C, D", "Licence Pro (Bac+3) / Master (Bac+5)", "Rédacteur, journaliste reporter TV/presse, présentateur du JT, journaliste radio, rédacteur en chef, JRI, correspondant ; en Master : rédacteur en chef, secrétaire de rédaction, directeur régional, éditorialiste."),
      GE("École de production audiovisuelle (EPA)", "A, B, C, D", "Licence Pro (Bac) / Master Pro (Bac+3)", "Télévision/Radio : animateur de programmes, assistant réalisation, monteur, éclairagiste, script ; Master : administrateur de production, producteur TV/Radio/Web, réalisateur cinéma, scénariste, directeur."),
      GE("École de Télécommunications et Technologies de l'Audiovisuel (ETTA)", "A, B, C, D, E", "-", "Télécoms : ingénieur d'étude, ingénieur systèmes, technicien de réseaux, développeur de logiciels ; Audiovisuel : gestionnaire de matériel technique, ingénieur du son et de l'image, technicien de maintenance."),
      GE("École Publicité Marketing (EPM)", "A, B, C, D", "Licence Pro (Bac) / Master Pro (Bac+3)", "Chargé de communication/digital, acheteur d'espaces publicitaires, analyste médias, responsable événementiel ; Master : community manager, directeur marketing, directeur création, chef de produit web/mobile, e-commerce."),
    ],
  },
};

// ============================================================
// Fusion pour le filtre "Filière -> Débouchés"
// ============================================================
const TOUTES_FILIERES_DEBOUCHES = [];
const seen = new Set();

Object.keys(DEBOUCHES_FILIERES).forEach((nom) => {
  if (!seen.has(nom)) {
    seen.add(nom);
    TOUTES_FILIERES_DEBOUCHES.push({ nom, debouches: DEBOUCHES_FILIERES[nom], source: "Universités publiques" });
  }
});

Object.entries(GRANDES_ECOLES).forEach(([ecole, data]) => {
  data.filieres.forEach((f) => {
    const key = f.nom;
    if (!seen.has(key)) {
      seen.add(key);
      TOUTES_FILIERES_DEBOUCHES.push({ nom: f.nom, debouches: f.debouches, source: "Grande école : " + ecole });
    }
  });
});

TOUTES_FILIERES_DEBOUCHES.sort((a, b) => a.nom.localeCompare(b.nom, "fr"));

  // ---- Tabs ----
  document.querySelectorAll('.es-tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.es-tab-btn').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.es-panel').forEach(p => p.classList.remove('active'));
      btn.classList.add('active');
      document.getElementById('panel-' + btn.dataset.tab).classList.add('active');
    });
  });

  // ---- Panel 1 : Universités ----
  const selectUniv = document.getElementById('select-univ');
  Object.keys(UNIVERSITES_NOMS).forEach(code => {
    const opt = document.createElement('option');
    opt.value = code;
    opt.textContent = `${code} — ${UNIVERSITES_NOMS[code]}`;
    selectUniv.appendChild(opt);
  });

  selectUniv.addEventListener('change', () => {
    const code = selectUniv.value;
    const container = document.getElementById('results-univ');
    container.innerHTML = '';
    if (!code) {
      container.innerHTML = '<div class="empty-state">Sélectionnez une université pour afficher ses filières et conditions d\'accès.</div>';
      return;
    }
    const filieres = UNIVERSITES[code] || [];
    if (filieres.length === 0) {
      container.innerHTML = '<div class="empty-state">Aucune filière relevée pour cette université dans le document source.</div>';
      return;
    }
    container.innerHTML = `<div class="school-header">${UNIVERSITES_NOMS[code]} — ${filieres.length} filière(s)</div>`;
    filieres.forEach(f => {
      const card = document.createElement('div');
      card.className = 'card';
      card.innerHTML = `
        <h3>${f.nom}</h3>
        <div class="meta-row">
          <div class="meta-item"><b>Série(s) BAC</b>${f.bac}</div>
          <div class="meta-item"><b>Âge limite</b>${f.age}</div>
        </div>
        <div class="criteres"><b>Critères d'accès :</b> ${f.criteres}</div>
      `;
      container.appendChild(card);
    });
  });

  // ---- Panel 2 : Grandes écoles ----
  const selectEcole = document.getElementById('select-ecole');
  Object.keys(GRANDES_ECOLES).forEach(nom => {
    const opt = document.createElement('option');
    opt.value = nom;
    opt.textContent = nom;
    selectEcole.appendChild(opt);
  });

  selectEcole.addEventListener('change', () => {
    const nom = selectEcole.value;
    const container = document.getElementById('results-ecole');
    container.innerHTML = '';
    if (!nom) {
      container.innerHTML = '<div class="empty-state">Sélectionnez une grande école pour afficher ses filières, conditions d\'accès et débouchés.</div>';
      return;
    }
    const data = GRANDES_ECOLES[nom];
    container.innerHTML = `<div class="school-header">${nom} <span style="opacity:.75">(${data.tutelle})</span></div>`;
    data.filieres.forEach(f => {
      const card = document.createElement('div');
      card.className = 'card';
      card.innerHTML = `
        <h3>${f.nom}</h3>
        <div class="meta-row">
          <div class="meta-item"><b>Série(s) BAC</b>${f.bac}</div>
          <div class="meta-item"><b>Âge limite</b>${f.age}</div>
        </div>
        <div class="debouches"><b>Débouchés :</b> ${f.debouches}</div>
      `;
      container.appendChild(card);
    });
  });

  // ---- Panel 3 : Filière -> Débouchés ----
  const selectFiliere = document.getElementById('select-filiere');
  const searchFiliere = document.getElementById('search-filiere');

  function populateFiliereSelect(filterText = '') {
    const current = selectFiliere.value;
    selectFiliere.innerHTML = '<option value="">— Sélectionner —</option>';
    TOUTES_FILIERES_DEBOUCHES
      .filter(f => normalize(f.nom).includes(normalize(filterText)))
      .forEach(f => {
        const opt = document.createElement('option');
        opt.value = f.nom;
        opt.textContent = f.nom;
        selectFiliere.appendChild(opt);
      });
    if ([...selectFiliere.options].some(o => o.value === current)) {
      selectFiliere.value = current;
    }
  }
  populateFiliereSelect();

  searchFiliere.addEventListener('input', () => populateFiliereSelect(searchFiliere.value));

  selectFiliere.addEventListener('change', () => {
    const nom = selectFiliere.value;
    const container = document.getElementById('results-filiere');
    container.innerHTML = '';
    if (!nom) {
      container.innerHTML = '<div class="empty-state">Sélectionnez une filière pour afficher ses débouchés.</div>';
      return;
    }
    const f = TOUTES_FILIERES_DEBOUCHES.find(x => x.nom === nom);
    const card = document.createElement('div');
    card.className = 'card';
    card.innerHTML = `
      <h3>${f.nom}</h3>
      <div class="meta-row"><div class="meta-item"><b>Filière recensée dans</b>${f.source}</div></div>
      <div class="debouches"><b>Débouchés :</b> ${f.debouches}</div>
    `;
    container.appendChild(card);
  });
})();
