// ============================================================
// ---- Test de personnalité (orientation scolaire) ----
// ============================================================
const RIASEC_DIMENSIONS = [
  { letter:'R', name:'Réaliste', bearing:0, sub:"Cochez les activités concrètes et manuelles qui vous attirent.",
    items:["Réparer ou construire des objets avec mes mains","Travailler avec des outils, des machines ou des engins","Faire du bricolage, de la mécanique ou de l'électricité","Travailler en extérieur ou sur un chantier","Manipuler des matériaux (bois, métal, tissu, terre)","Cultiver la terre ou m'occuper d'animaux","Démonter un appareil pour comprendre son fonctionnement","Exercer une activité physique et concrète plutôt que rester assis à un bureau","Conduire ou entretenir un véhicule ou un engin","Suivre des instructions techniques précises pour fabriquer quelque chose"] },
  { letter:'I', name:'Investigateur', bearing:60, sub:"Cochez les activités d'analyse et de recherche qui vous attirent.",
    items:["Résoudre des problèmes complexes ou des énigmes","Faire des expériences scientifiques","Comprendre pourquoi les choses fonctionnent comme elles fonctionnent","Lire des articles scientifiques ou techniques","Analyser des données, des statistiques ou des chiffres","Mener une enquête ou une recherche approfondie","Travailler seul(e) de façon autonome sur un sujet précis","Poser beaucoup de questions et chercher des réponses rigoureuses","Étudier les mathématiques, la physique, la biologie ou l'informatique","Élaborer des hypothèses puis les vérifier"] },
  { letter:'A', name:'Artistique', bearing:120, sub:"Cochez les activités créatives et expressives qui vous attirent.",
    items:["Dessiner, peindre ou créer des objets originaux","Écrire des textes, des poèmes ou des histoires","Jouer de la musique, chanter ou danser","Imaginer des idées nouvelles et originales","M'exprimer librement sans contrainte de règles strictes","Décorer un espace ou créer une mise en scène","Photographier, filmer ou monter des vidéos","Inventer des histoires ou des univers imaginaires","Travailler dans un cadre où la créativité est valorisée","Créer de la mode, des bijoux ou des objets d'art"] },
  { letter:'S', name:'Social', bearing:180, sub:"Cochez les activités tournées vers les autres qui vous attirent.",
    items:["Aider, écouter ou conseiller les autres","Enseigner ou expliquer quelque chose à quelqu'un","Travailler en équipe et coopérer avec d'autres personnes","Prendre soin des enfants, des malades ou des personnes âgées","Organiser des activités pour un groupe","Aider à résoudre les conflits entre les personnes","Accueillir et orienter les visiteurs ou les clients","Participer à des actions bénévoles ou communautaires","Comprendre les émotions et les besoins des autres","Encourager et motiver les autres à progresser"] },
  { letter:'E', name:'Entreprenant', bearing:240, sub:"Cochez les activités de leadership et de persuasion qui vous attirent.",
    items:["Convaincre ou persuader les autres","Diriger un groupe ou une équipe","Vendre un produit ou un service","Prendre des décisions rapidement et prendre des risques","Négocier ou débattre pour défendre mes idées","Monter mon propre projet ou ma propre entreprise","Fixer des objectifs ambitieux et chercher à les atteindre","Parler en public ou animer une réunion","Chercher à obtenir des responsabilités et de l'influence","Motiver les autres à me suivre dans un projet"] },
  { letter:'C', name:'Conventionnel', bearing:300, sub:"Cochez les activités d'organisation et de rigueur qui vous attirent.",
    items:["Classer, organiser et archiver des documents","Suivre des règles et des procédures précises","Tenir des comptes ou gérer un budget","Travailler avec des chiffres de façon rigoureuse et méthodique","Utiliser des logiciels de bureautique (Word, Excel...)","Planifier et respecter un emploi du temps","Vérifier l'exactitude et la conformité d'un travail","Rédiger des rapports, des courriers ou des comptes rendus","Travailler dans un cadre stable et bien structuré","Assurer le suivi administratif d'un dossier"] }
];

const RIASEC_COLORS = { R:'#8B5E34', I:'#2F6FAD', A:'#B23A82', S:'#2F9E5C', E:'#D97A1E', C:'#4A4A6A' };

const RIASEC_INFO = {
  R:{ epithete:"Le Bâtisseur / la Bâtisseuse",
      description:"Vous vous sentez pleinement vous-même lorsque vos mains sont à l'ouvrage et que le résultat de votre travail est concret, visible, palpable. Le monde réaliste est celui de la matière : le bois qui prend forme sous la scie, le moteur qui redémarre après réparation, la terre qui produit après avoir été travaillée. Vous préférez l'action à la théorie, l'atelier au bureau, et vous trouvez une vraie satisfaction dans les tâches qui exigent précision technique et habileté manuelle.",
      qualites:["Sens pratique et habileté manuelle","Endurance et robustesse face à l'effort physique","Goût du concret et de l'utile","Autonomie dans l'exécution des tâches"],
      environnement:"Ateliers, chantiers, exploitations agricoles, garages, usines — des lieux où l'on voit le fruit de son travail prendre forme sous ses yeux.",
      filieres:["Mécanique Automobile","Électrotechnique","Menuiserie Ébénisterie","Maçonnerie","Agriculture","Élevage","Construction Métallique","Chaudronnerie Soudure"],
      metiers:["Mécanicien automobile","Électrotechnicien","Menuisier-ébéniste","Agriculteur","Conducteur d'engins de travaux publics","Chaudronnier-soudeur"] },
  I:{ epithete:"Le Chercheur / la Chercheuse",
      description:"Vous êtes habité(e) par une curiosité qui ne se satisfait jamais de la première explication venue. Ce qui vous anime, c'est comprendre : pourquoi les choses se produisent, comment un système fonctionne, ce qui se cache derrière un phénomène. Vous appréciez le raisonnement rigoureux, l'analyse méthodique et le plaisir presque solitaire de résoudre une énigme intellectuelle jusqu'au bout.",
      qualites:["Esprit d'analyse et de synthèse","Rigueur scientifique et méthodique","Curiosité intellectuelle","Capacité de concentration prolongée"],
      environnement:"Laboratoires, bureaux d'études, centres de recherche, salles informatiques — des environnements calmes qui favorisent la réflexion approfondie.",
      filieres:["Système Électronique et Informatique","Électronique","Industrie Agroalimentaire et Chimie - Contrôle","Sciences Médico-Sociales"],
      metiers:["Technicien en électronique","Ingénieur en informatique","Chercheur","Technicien de laboratoire de contrôle qualité"] },
  A:{ epithete:"Le Créateur / la Créatrice",
      description:"Vous respirez mieux lorsque vous pouvez créer, imaginer, inventer sans que des règles rigides ne viennent brider votre élan. L'univers artistique est celui de l'expression : une toile, une mélodie, un texte, un vêtement qui n'existaient pas avant que vous ne les fassiez naître. Vous valorisez l'originalité, la sensibilité esthétique et la liberté de vous exprimer à votre manière, unique.",
      qualites:["Créativité et sensibilité esthétique","Originalité et goût du non-conformisme","Expressivité et sens artistique","Capacité d'improvisation"],
      environnement:"Ateliers de création, studios, espaces culturels — des lieux qui laissent place à l'imagination et à l'expérimentation.",
      filieres:["Art mural","Décoration Textile","Céramique","Coupe Couture","Bijouterie","Tapisserie"],
      metiers:["Artiste peintre muraliste","Décorateur textile","Céramiste","Couturier","Bijoutier","Tapissier d'ameublement"] },
  S:{ epithete:"L'Accompagnateur / l'Accompagnatrice",
      description:"Ce qui vous fait vibrer, c'est le lien avec les autres : écouter, comprendre, accompagner, transmettre. Vous êtes attentif ou attentive aux besoins d'autrui et vous tirez une profonde satisfaction du sentiment d'avoir été utile à quelqu'un — que ce soit en enseignant, en soignant, en conseillant ou simplement en étant présent(e). Le travail en équipe et le contact humain sont pour vous des sources d'énergie plutôt que des contraintes.",
      qualites:["Empathie et sens de l'écoute","Patience et bienveillance","Esprit d'équipe et de coopération","Sens du service et de l'engagement"],
      environnement:"Écoles, centres de santé, structures sociales, hôtels — des environnements centrés sur la relation humaine.",
      filieres:["Sciences Médico-Sociales","Sanitaire et Social","Employé d'Hôtel","Cuisine Professionnelle"],
      metiers:["Auxiliaire sanitaire et social","Éducateur préscolaire","Technicien en sciences médico-sociales","Employé d'hôtel"] },
  E:{ epithete:"Le Meneur / la Meneuse",
      description:"Vous êtes à votre meilleur lorsque vous pouvez convaincre, entraîner, décider et prendre des initiatives. L'univers entreprenant est celui de l'action stratégique : identifier une opportunité, mobiliser une équipe, négocier un accord, porter un projet du début à la fin. Vous aimez les responsabilités, la prise de risque calculée et le plaisir de voir vos idées se concrétiser grâce à votre capacité à entraîner les autres.",
      qualites:["Leadership et esprit d'initiative","Aisance relationnelle et sens de la persuasion","Ambition et goût du challenge","Capacité de décision rapide"],
      environnement:"Entreprises commerciales, points de vente, organisations en développement — des environnements dynamiques, tournés vers les résultats.",
      filieres:["Gestion Commerciale","Assistant de direction","Tourisme et Hôtellerie","Logistique"],
      metiers:["Gestionnaire commercial","Assistant de direction","Conseiller en tourisme","Responsable logistique"] },
  C:{ epithete:"L'Organisateur / l'Organisatrice",
      description:"Vous trouvez votre équilibre dans l'ordre, la précision et la rigueur méthodique. Ce qui vous satisfait profondément, c'est un dossier bien classé, un budget parfaitement équilibré, une procédure suivie à la lettre. Vous êtes à l'aise dans un cadre structuré où les règles sont claires, et vous excellez dans les tâches qui demandent fiabilité, exactitude et sens du détail.",
      qualites:["Rigueur et sens de l'organisation","Fiabilité et discrétion","Précision dans le traitement des données","Respect des procédures et des délais"],
      environnement:"Bureaux, services administratifs et comptables, secrétariats — des cadres de travail stables et bien structurés.",
      filieres:["Comptabilité","Secrétariat Bureautique","Finance Comptabilité Gestion des Entreprises","Gestion de Production"],
      metiers:["Comptable","Secrétaire bureautique","Gestionnaire administratif et financier","Assistant de gestion"] }
};
