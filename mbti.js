// ============================================================
// ---- Test MBTI (typologie de personnalité) ----
// ---- Intégré à l'espace inspecteur, données rattachées à Supabase ----
// ---- Architecture identique à LYCAM (lycam.js) ----
// ============================================================

/* ---- Données du questionnaire (80 affirmations, 10 par pôle) ---- */
const MBTI_DIMENSIONS = {
  E: { name: "Extraversion" }, I: { name: "Introversion" },
  S: { name: "Sensation" },     N: { name: "Intuition" },
  T: { name: "Pensée" },        F: { name: "Sentiment" },
  J: { name: "Jugement" },      P: { name: "Perception" },
};

const MBTI_QUESTIONS = [
  // ---- E (1-10) ----
  {n:1,dim:'E',prompt:"Vous êtes dynamique",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:2,dim:'E',prompt:"Vous aimez parler",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:3,dim:'E',prompt:"Vous pensez à voix haute",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:4,dim:'E',prompt:"Vous agissez, puis pensez",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:5,dim:'E',prompt:"Vous n'aimez pas être seul",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:6,dim:'E',prompt:"Vous aimez établir de nouveaux contacts",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:7,dim:'E',prompt:"Vous préférez parler plutôt qu'écrire",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:8,dim:'E',prompt:"Vous pouvez facilement être distrait",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:9,dim:'E',prompt:"Vous préférez faire plusieurs choses à la fois",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:10,dim:'E',prompt:"Vous avez parfois un discours changeant",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  // ---- I (11-20) ----
  {n:11,dim:'I',prompt:"Vous êtes calme",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:12,dim:'I',prompt:"Vous aimez écouter",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:13,dim:'I',prompt:"Vous réfléchissez posément",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:14,dim:'I',prompt:"Vous pensez, puis agissez",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:15,dim:'I',prompt:"Vous vous sentez bien quand vous êtes seul",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:16,dim:'I',prompt:"Vous aimez approfondir vos contacts",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:17,dim:'I',prompt:"Vous êtes considéré comme plutôt secret et réservé",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:18,dim:'I',prompt:"Vous possédez une bonne capacité de concentration",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:19,dim:'I',prompt:"Vous préférez vous concentrer sur une seule chose à la fois",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:20,dim:'I',prompt:"Vous êtes indépendant",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  // ---- S (21-30) ----
  {n:21,dim:'S',prompt:"Vous vous attachez aux faits et aux détails",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:22,dim:'S',prompt:"Vous aimez les choses utiles",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:23,dim:'S',prompt:"Vous vivez dans l'instant présent",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:24,dim:'S',prompt:"Vous faites confiance à l'expérience",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:25,dim:'S',prompt:"Vous aimez approfondir vos compétences",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:26,dim:'S',prompt:"Vous restez fidèle aux méthodes qui ont fait leurs preuves",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:27,dim:'S',prompt:"Vous préférez les instructions étape par étape",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:28,dim:'S',prompt:"Vous êtes pratique",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:29,dim:'S',prompt:"Vous aimez ce qui est concret, réel, directement observable",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:30,dim:'S',prompt:"Vous êtes réaliste : vous voyez ce qui existe",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  // ---- N (31-40) ----
  {n:31,dim:'N',prompt:"Vous vous intéressez aux idées",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:32,dim:'N',prompt:"Vous remarquez tout ce qui est nouveau et différent",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:33,dim:'N',prompt:"Vous pensez aux implications futures",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:34,dim:'N',prompt:"Vous suivez votre instinct",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:35,dim:'N',prompt:"Vous aimez apprendre de nouvelles compétences",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:36,dim:'N',prompt:"Vous n'aimez pas la routine",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:37,dim:'N',prompt:"Vous cherchez à comprendre",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:38,dim:'N',prompt:"Vous êtes théorique",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:39,dim:'N',prompt:"Vous êtes attiré par les idées originales",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:40,dim:'N',prompt:"Vous êtes imaginatif : vous voyez les possibilités",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  // ---- T (41-50) ----
  {n:41,dim:'T',prompt:"Vous vous efforcez d'être objectif dans vos décisions",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:42,dim:'T',prompt:"Vous apparaissez calme et réservé",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:43,dim:'T',prompt:"Vous avez un sens aigu de la justice",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:44,dim:'T',prompt:"Vous vous impliquez peu, vous prenez de la distance",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:45,dim:'T',prompt:"Vous êtes critique (vous remarquez vite les failles et les défauts)",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:46,dim:'T',prompt:"Vous adorez argumenter pour le plaisir",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:47,dim:'T',prompt:"Vous êtes franc et direct",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:48,dim:'T',prompt:"Vous êtes motivé par vos projets",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:49,dim:'T',prompt:"Vous aimez vous placer en observateur",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:50,dim:'T',prompt:"Vous êtes sensible à la logique",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  // ---- F (51-60) ----
  {n:51,dim:'F',prompt:"Vous fondez vos décisions sur vos valeurs et vos sentiments",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:52,dim:'F',prompt:"Vous êtes sociable et amical",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:53,dim:'F',prompt:"Vous avez tendance à la clémence",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:54,dim:'F',prompt:"Vous prenez les choses à cœur",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:55,dim:'F',prompt:"Vous tentez de faire plaisir (prompt à faire des compliments)",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:56,dim:'F',prompt:"Vous évitez la discussion et le conflit",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:57,dim:'F',prompt:"Vous êtes diplomate et faites preuve de tact",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:58,dim:'F',prompt:"Vous êtes motivé par l'estime des autres",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:59,dim:'F',prompt:"Vous êtes sensible (facilement blessé)",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:60,dim:'F',prompt:"Vous faites confiance à vos impressions",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  // ---- J (61-70) ----
  {n:61,dim:'J',prompt:"Vous aimez organiser et planifier",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:62,dim:'J',prompt:"Vous êtes sérieux et conventionnel",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:63,dim:'J',prompt:"Vous suivez votre calendrier et êtes parfaitement ponctuel",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:64,dim:'J',prompt:"Vous aimez terminer vos projets",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:65,dim:'J',prompt:"Vous travaillez d'abord, vous vous amusez ensuite",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:66,dim:'J',prompt:"Vous n'aimez pas le stress de dernière minute",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:67,dim:'J',prompt:"Vous préférez les règles bien définies",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:68,dim:'J',prompt:"Vous ne discutez pas les règles",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:69,dim:'J',prompt:"Vous cherchez à maîtriser",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:70,dim:'J',prompt:"Vous êtes à l'aise au sein de structures bien définies",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  // ---- P (71-80) ----
  {n:71,dim:'P',prompt:"Vous aimez vivre de façon flexible",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:72,dim:'P',prompt:"Vous êtes ludique et non-conventionnel",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:73,dim:'P',prompt:"Vous n'avez ni heure ni délais",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:74,dim:'P',prompt:"Vous aimez démarrer des projets",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:75,dim:'P',prompt:"Vous vous amusez d'abord et travaillez ensuite",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:76,dim:'P',prompt:"Vous rechignez à vous engager",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:77,dim:'P',prompt:"Vous discutez les règles",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:78,dim:'P',prompt:"Vous cherchez à comprendre",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:79,dim:'P',prompt:"Vous aimez conserver votre liberté d'action",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
  {n:80,dim:'P',prompt:"Vous restez ouvert, aimez vivre des expériences, vous adapter",risk:['A'],opts:[['A',"Oui, cela me correspond"],['B',"Non, cela ne me correspond pas"]]},
];

// Paires d'axes opposés, dans l'ordre du questionnaire papier
const MBTI_AXES = [['E','I'], ['S','N'], ['T','F'], ['J','P']];

// Descriptions courtes des 8 fonctions cognitives (affichage résultat)
const MBTI_FONCTIONS = {
  Se: "Sensation extravertie — vit dans le moment présent, perçoit le monde sensoriel, attentif aux détails de l'environnement.",
  Si: "Sensation introvertie — se réfère à ses expériences passées et impressions internes pour interpréter le présent.",
  Ne: "Intuition extravertie — explore de nouvelles idées, perçoit les possibilités et connexions entre événements externes.",
  Ni: "Intuition introvertie — a une vision intérieure, anticipe l'avenir, recherche des significations profondes.",
  Te: "Pensée extravertie — organise et structure le monde extérieur de façon logique et efficace.",
  Ti: "Pensée introvertie — analyse en profondeur, cherche la cohérence interne des idées.",
  Fe: "Sentiment extraverti — harmonise avec les autres, prend en compte les valeurs sociales, chaleureux et expressif.",
  Fi: "Sentiment introverti — suit ses valeurs personnelles, ressent profondément, prise de décision basée sur une boussole interne.",
};

// Description courte des 16 types + pistes de filières/métiers (support de formation)
const MBTI_TYPES = {
  ISTJ: { nom: "L'Inspecteur", desc: "Organisé(e) et fiable.", filieres: "Droit, comptabilité, gestion." },
  ISFJ: { nom: "Le Protecteur", desc: "Attentionné(e) et dévoué(e).", filieres: "Santé, éducation, services sociaux." },
  INFJ: { nom: "Le Conseiller", desc: "Créatif/ve et idéaliste.", filieres: "Psychologie, conseil, arts." },
  INTJ: { nom: "L'Architecte", desc: "Stratégique et analytique.", filieres: "Ingénierie, recherche, gestion de projets." },
  ISTP: { nom: "L'Artisan", desc: "Pratique et adaptable.", filieres: "Carrières techniques, ingénierie, métiers manuels." },
  ISFP: { nom: "Le Compositeur", desc: "Sensible et artistique.", filieres: "Arts, design, métiers liés à la nature." },
  INFP: { nom: "L'Idéaliste", desc: "Créatif/ve et empathique.", filieres: "Écriture, travail social, enseignement." },
  INTP: { nom: "Le Logicien", desc: "Curieux/se et analytique.", filieres: "Sciences, philosophie, informatique." },
  ESTP: { nom: "L'Entrepreneur", desc: "Dynamique et pragmatique.", filieres: "Commerce, marketing, métiers de terrain." },
  ESFP: { nom: "L'Animateur", desc: "Sociable et enthousiaste.", filieres: "Arts du spectacle, événementiel, tourisme." },
  ENFP: { nom: "L'Inspirateur", desc: "Créatif/ve et motivé(e).", filieres: "Marketing, communication, coaching." },
  ENTP: { nom: "L'Innovateur", desc: "Inventif/ve et débrouillard(e).", filieres: "Entrepreneuriat, technologie, droit." },
  ESTJ: { nom: "Le Directeur", desc: "Organisé(e) et efficace.", filieres: "Gestion, administration, droit." },
  ESFJ: { nom: "Le Consul", desc: "Chaleureux/se et sociable.", filieres: "Éducation, santé, ressources humaines." },
  ENFJ: { nom: "Le Protagoniste", desc: "Charismatique et empathique.", filieres: "Coaching, éducation, travail social." },
  ENTJ: { nom: "Le Commandant", desc: "Leader naturel(le).", filieres: "Gestion, droit, entrepreneuriat." },
};

// Filières par fonction cognitive dominante (table du support de formation)
const MBTI_FILIERES_PAR_FONCTION = {
  Fi: { categorie: "Disciplines qui valorisent la réflexion personnelle, l'éthique, la psychologie, l'art", exemples: "Philosophie, Psychologie, Arts, Travail social, Théologie, Counselling" },
  Se: { categorie: "Disciplines concrètes, pratiques, artistiques ou sportives", exemples: "Arts plastiques, Médecine, Cuisine, Mécanique, Sport" },
  Ni: { categorie: "Disciplines théoriques, recherche, sciences sociales ou humaines", exemples: "Philosophie, Sciences, Recherche, Psychologie, Littérature, Sociologie" },
  Te: { categorie: "Disciplines structurées : gestion, administration, ingénierie, économie", exemples: "Gestion, Administration, Ingénierie, Informatique, Droit, Sciences exactes" },
  Fe: { categorie: "Disciplines relationnelles, sociales, éducatives ou communautaires", exemples: "Travail social, Éducation, Communication, Psychologie sociale" },
  Si: { categorie: "Disciplines basées sur la mémoire, l'histoire, la tradition", exemples: "Histoire, Archivistique, Muséologie, Littérature classique, Sciences humaines" },
  Ne: { categorie: "Disciplines innovantes, créatives ou de recherche", exemples: "Arts, Design, Marketing, Entrepreneuriat, Sciences expérimentales" },
  Ti: { categorie: "Disciplines analytiques, techniques ou théoriques", exemples: "Mathématiques, Informatique, Philosophie, Sciences exactes, Ingénierie" },
};

// Mode d'apprentissage par lettre (une par pôle)
const MBTI_MODE_APPRENTISSAGE = {
  E: "apprend en interagissant avec les autres, en participant à des discussions, en expérimentant activement.",
  I: "apprend mieux seul, en réfléchissant profondément ou en lisant.",
  S: "apprend par des faits concrets, des détails pratiques et des expériences sensorielles.",
  N: "apprend en voyant le tableau d'ensemble, en faisant des liens abstraits et en explorant des concepts théoriques.",
  T: "apprend par une approche analytique, logique et structurée.",
  F: "apprend mieux en reliant l'information à ses valeurs, ses émotions ou son impact humain.",
  J: "apprend mieux dans un cadre organisé, planifié, avec des échéances claires.",
  P: "apprend mieux avec une approche flexible, ouverte et une exploration libre.",
};

// Rôle général de chaque niveau de la hiérarchie (indépendant du type)
const MBTI_ROLE_HIERARCHIE = {
  dominante: "La fonction cognitive principale : la plus consciente, celle qui influence le plus la façon de percevoir le monde et de prendre des décisions. Présente dès la naissance.",
  auxiliaire: "La deuxième fonction la plus utilisée : elle se développe un peu après la dominante et vient l'équilibrer. Moins forte que la dominante, mais bien développée.",
  tertiaire: "Une fonction moins développée que les deux précédentes, qui joue un rôle dans la maturité et l'équilibre psychologique. Se développe souvent à l'âge adulte, parfois vers la trentaine — peut être utilisée de façon immature au début.",
  inferieure: "La fonction la moins développée, souvent inconsciente : le « talon d'Achille ». Opposée à la fonction dominante, elle est souvent source de stress.",
};

/* ---- État de l'onglet MBTI ---- */
let _espMbtiView = 'list'; // 'list' | 'identity' | 'quiz' | 'egalite' | 'result' | 'report'
let _espMbtiSessions = [];
let _espMbtiCurrentSession = null; // {id, nom}
let _espMbtiCurrentResults = [];   // résultats connus de la session en cours (serveur + en attente)
let _espMbtiCurrentQ = 0;
let _espMbtiAnswers = {};
let _espMbtiIdentity = {};
let _espMbtiLastResult = null;
let _espMbtiLoading = false;
let _espMbtiError = '';
let _espMbtiEgalites = [];       // ex: [{axe:['E','I'], scoreA:5, scoreB:5}] — à trancher
let _espMbtiEgaliteChoix = {};   // ex: {"E/I": "E"} — réponses de l'inspecteur

const MBTI_PENDING_KEY = 'mbti_pending_results_v1';

/* ---------------- File d'attente locale (résilience réseau) ---------------- */
function espMbtiLoadPending(){
  try { return JSON.parse(localStorage.getItem(MBTI_PENDING_KEY) || '[]'); } catch(e){ return []; }
}
function espMbtiSavePending(list){
  try { localStorage.setItem(MBTI_PENDING_KEY, JSON.stringify(list)); } catch(e){}
}
function espMbtiPendingForSession(sessionId){
  return espMbtiLoadPending().filter(p => p.sessionId === sessionId);
}
async function espMbtiRetrySync(){
  const session = espSession();
  const pending = espMbtiLoadPending();
  if(!pending.length) return;
  const stillPending = [];
  for(const p of pending){
    try {
      const ok = await espMbtiSaveResultRPC(session.id, session.password, p.sessionId, p.eleve, p.scores, p.typeLetters, p.hierarchie, p.egalites);
      if(!ok) stillPending.push(p);
    } catch(e){ stillPending.push(p); }
  }
  espMbtiSavePending(stillPending);
}

/* ---------------- Initialisation de l'onglet ---------------- */
async function espMbtiInitTab(){
  _espMbtiView = 'list';
  _espMbtiError = '';
  _espMbtiLoading = true;
  espMbtiRefreshContainer();
  const session = espSession();
  try {
    await espMbtiRetrySync();
    _espMbtiSessions = await espMbtiListSessionsRPC(session.id, session.password);
  } catch(e){
    _espMbtiError = "Impossible de charger les sessions MBTI : " + e.message;
    _espMbtiSessions = [];
  }
  _espMbtiLoading = false;
  espMbtiRefreshContainer();
}

function espMbtiRefreshContainer(){
  const container = document.getElementById('esp-mbti-tab-container');
  if(container) container.innerHTML = espRenderMbtiTab();
}

/* ---------------- Rendu principal ---------------- */
function espRenderMbtiTab(){
  if(_espMbtiView === 'identity') return espMbtiRenderIdentity();
  if(_espMbtiView === 'quiz') return espMbtiRenderQuiz();
  if(_espMbtiView === 'egalite') return espMbtiRenderEgalite();
  if(_espMbtiView === 'result') return espMbtiRenderResult();
  if(_espMbtiView === 'report') return espMbtiRenderReport();
  return espMbtiRenderList();
}

function espMbtiRenderList(){
  const pendingTotal = espMbtiLoadPending().length;
  return `
    <div class="esp-card">
      <div class="esp-title" style="font-size:16px;">🧭 Test MBTI — typologie de personnalité</div>
      <p class="esp-sub">Une session correspond à une classe (ou un groupe) testé un jour donné. Tu peux tester 1 à 150 élèves par session.</p>
      ${_espMbtiError ? `<p class="esp-error">${escapeHtml(_espMbtiError)}</p>` : ''}
      ${pendingTotal ? `<p class="esp-sub" style="color:var(--orange-dark);">⚠️ ${pendingTotal} résultat(s) pas encore synchronisé(s) avec le serveur. <span class="esp-toggle-link" onclick="espMbtiManualRetrySync()">Réessayer maintenant</span></p>` : ''}
      ${_espMbtiLoading ? `<p class="esp-empty">Chargement...</p>` : `
        <div class="esp-field-row" style="align-items:flex-end;">
          <div class="esp-field" style="flex:2;">
            <label>Nom de la session</label>
            <input type="text" id="esp-mbti-new-name" placeholder="Ex : 2nde B — 05/08/2026">
          </div>
        </div>
        <button class="esp-btn esp-btn-primary" onclick="espMbtiCreateSession()">+ Nouvelle session</button>
        <div style="margin-top:20px;">
          ${_espMbtiSessions.length ? _espMbtiSessions.map(s => `
            <div class="esp-lycam-session-item" onclick="espMbtiOpenSession('${s.id}')">
              <div class="esp-lycam-session-name">${escapeHtml(s.nom)}</div>
              <div class="esp-lycam-session-date">${new Date(s.createdAt).toLocaleDateString('fr-FR', {day:'2-digit',month:'2-digit',year:'numeric'})}</div>
            </div>
          `).join('') : `<p class="esp-empty">Aucune session pour l'instant. Crée-en une pour commencer.</p>`}
        </div>
      `}
    </div>
  `;
}

async function espMbtiCreateSession(){
  const input = document.getElementById('esp-mbti-new-name');
  const nom = input.value.trim();
  if(!nom){ _espMbtiError = "Merci de donner un nom à la session."; espMbtiRefreshContainer(); return; }
  const session = espSession();
  try {
    const id = await espMbtiCreateSessionRPC(session.id, session.password, nom);
    if(!id){ _espMbtiError = "Impossible de créer la session (session expirée ?)."; espMbtiRefreshContainer(); return; }
    _espMbtiCurrentSession = { id, nom };
    _espMbtiCurrentResults = [];
    _espMbtiError = '';
    espMbtiGoToIdentity();
  } catch(e){
    _espMbtiError = "Erreur : " + e.message;
    espMbtiRefreshContainer();
  }
}

async function espMbtiOpenSession(sessionId){
  const s = _espMbtiSessions.find(x => x.id === sessionId);
  if(!s) return;
  _espMbtiCurrentSession = { id: s.id, nom: s.nom };
  _espMbtiLoading = true;
  espMbtiRefreshContainer();
  const session = espSession();
  try {
    const serverResults = await espMbtiListResultsRPC(session.id, session.password, sessionId);
    const pending = espMbtiPendingForSession(sessionId).map(p => ({
      id: 'pending-' + p.tempId, sessionId, nom:p.eleve.nom, prenom:p.eleve.prenom, naissance:p.eleve.naissance,
      classe:p.eleve.classe, scores:p.scores, typeLetters:p.typeLetters, hierarchie:p.hierarchie, egalites:p.egalites, pending:true,
    }));
    _espMbtiCurrentResults = [...serverResults, ...pending];
  } catch(e){
    _espMbtiError = "Impossible de charger les résultats : " + e.message;
    _espMbtiCurrentResults = espMbtiPendingForSession(sessionId).map(p => ({
      id:'pending-'+p.tempId, sessionId, nom:p.eleve.nom, prenom:p.eleve.prenom, naissance:p.eleve.naissance,
      classe:p.eleve.classe, scores:p.scores, typeLetters:p.typeLetters, hierarchie:p.hierarchie, egalites:p.egalites, pending:true,
    }));
  }
  _espMbtiLoading = false;
  _espMbtiView = 'report';
  espMbtiRefreshContainer();
}

function espMbtiGoToIdentity(){
  _espMbtiCurrentQ = 0;
  _espMbtiAnswers = {};
  _espMbtiIdentity = {};
  _espMbtiEgalites = [];
  _espMbtiEgaliteChoix = {};
  _espMbtiView = 'identity';
  espMbtiRefreshContainer();
}

function espMbtiBackToList(){
  _espMbtiView = 'list';
  _espMbtiCurrentSession = null;
  _espMbtiCurrentResults = [];
  espMbtiInitTab();
}

/* ---------------- Écran identité ---------------- */
function espMbtiRenderIdentity(){
  const count = _espMbtiCurrentResults.length;
  return `
    <div class="esp-card">
      <button class="esp-back" onclick="espMbtiBackToList()">← Toutes les sessions</button>
      <div class="esp-title" style="font-size:16px;">🧭 ${escapeHtml(_espMbtiCurrentSession.nom)}</div>
      <p class="esp-sub">Élève n°${count + 1} (jusqu'à 150 par session). Saisis son identité avant de commencer.</p>
      <div class="esp-field-row">
        <div class="esp-field"><label>Nom</label><input type="text" id="mbti-nom"></div>
        <div class="esp-field"><label>Prénom</label><input type="text" id="mbti-prenom"></div>
      </div>
      <div class="esp-field-row">
        <div class="esp-field"><label>Année de naissance</label><input type="number" id="mbti-naissance" placeholder="Ex : 2009"></div>
        <div class="esp-field"><label>Classe</label><input type="text" id="mbti-classe"></div>
      </div>
      <div id="esp-mbti-identity-error"></div>
      <div style="display:flex; justify-content:space-between; margin-top:10px;">
        <button class="esp-btn" onclick="espMbtiShowReport()">📊 Voir le rapport de session</button>
        <button class="esp-btn esp-btn-primary" onclick="espMbtiStartQuiz()">Commencer le questionnaire →</button>
      </div>
    </div>
  `;
}

function espMbtiStartQuiz(){
  const nom = document.getElementById('mbti-nom').value.trim();
  const prenom = document.getElementById('mbti-prenom').value.trim();
  const naissance = document.getElementById('mbti-naissance').value.trim();
  const classe = document.getElementById('mbti-classe').value.trim();
  if(!nom || !prenom){
    document.getElementById('esp-mbti-identity-error').innerHTML = '<p class="esp-error">Merci de renseigner au moins le nom et le prénom.</p>';
    return;
  }
  _espMbtiIdentity = { nom, prenom, naissance, classe };
  _espMbtiCurrentQ = 0;
  _espMbtiAnswers = {};
  _espMbtiEgalites = [];
  _espMbtiEgaliteChoix = {};
  _espMbtiView = 'quiz';
  espMbtiRefreshContainer();
}

/* ---------------- Écran quiz ---------------- */
function espMbtiRenderQuiz(){
  const q = MBTI_QUESTIONS[_espMbtiCurrentQ];
  const pct = Math.round((_espMbtiCurrentQ / MBTI_QUESTIONS.length) * 100);
  const isLast = _espMbtiCurrentQ === MBTI_QUESTIONS.length - 1;
  return `
    <div class="esp-card">
      <div class="esp-lycam-ribbon"><div class="esp-lycam-ribbon-fill" style="width:${pct}%;"></div></div>
      <div style="display:flex; justify-content:space-between; margin:10px 0 18px;">
        <span class="esp-sub" style="margin:0;">Question ${_espMbtiCurrentQ+1} sur ${MBTI_QUESTIONS.length}</span>
        <span class="esp-lycam-dim-chip">${q.dim}</span>
      </div>
      <p class="esp-lycam-prompt">${escapeHtml(q.prompt)}</p>
      <div class="esp-lycam-options">
        ${q.opts.map(([letter, text]) => `
          <div class="esp-lycam-opt ${_espMbtiAnswers[_espMbtiCurrentQ] === letter ? 'selected' : ''}" onclick="espMbtiSelectOption('${letter}')">
            <span class="esp-lycam-opt-letter">${letter}</span><span>${escapeHtml(text)}</span>
          </div>
        `).join('')}
      </div>
      <div id="esp-mbti-quiz-error"></div>
      <div style="display:flex; justify-content:space-between; margin-top:20px;">
        <button class="esp-btn" onclick="espMbtiPrevQuestion()" ${_espMbtiCurrentQ === 0 ? 'style="visibility:hidden;"' : ''}>← Précédent</button>
        <button class="esp-btn esp-btn-primary" onclick="espMbtiNextQuestion()">${isLast ? 'Voir le résultat →' : 'Suivant →'}</button>
      </div>
    </div>
  `;
}

function espMbtiSelectOption(letter){
  _espMbtiAnswers[_espMbtiCurrentQ] = letter;
  espMbtiRefreshContainer();
}
function espMbtiPrevQuestion(){
  if(_espMbtiCurrentQ === 0) return;
  _espMbtiCurrentQ--;
  espMbtiRefreshContainer();
}
async function espMbtiNextQuestion(){
  if(!_espMbtiAnswers[_espMbtiCurrentQ]){
    document.getElementById('esp-mbti-quiz-error').innerHTML = '<p class="esp-error">Choisis une réponse pour continuer.</p>';
    return;
  }
  if(_espMbtiCurrentQ === MBTI_QUESTIONS.length - 1){
    await espMbtiComputeAndSave();
    return;
  }
  _espMbtiCurrentQ++;
  espMbtiRefreshContainer();
}

/* ---------------- Dépouillement + gestion des égalités ---------------- */
function espMbtiScore(){
  const scores = {}; Object.keys(MBTI_DIMENSIONS).forEach(d => scores[d] = 0);
  MBTI_QUESTIONS.forEach((q, idx) => {
    const given = _espMbtiAnswers[idx];
    if(given && q.risk.includes(given)) scores[q.dim]++;
  });
  return scores; // ex: {E:7,I:3,S:4,N:6,T:8,F:2,J:3,P:7}
}

function espMbtiDetectEgalites(scores){
  return MBTI_AXES
    .filter(([a,b]) => scores[a] === scores[b])
    .map(([a,b]) => ({ axe:[a,b], scoreA:scores[a], scoreB:scores[b] }));
}

function espMbtiLettreAxe(scores, a, b){
  if(_espMbtiEgaliteChoix[a+'/'+b]) return _espMbtiEgaliteChoix[a+'/'+b];
  return scores[a] > scores[b] ? a : b;
}

/* ---------------- Calcul de la hiérarchie des fonctions cognitives ---------------- */
// Vérifié sur les deux exemples du support de formation :
// espMbtiComputeHierarchy("ENTP") -> {dominante:"Ne", auxiliaire:"Ti", tertiaire:"Fe", inferieure:"Si"}
// espMbtiComputeHierarchy("INTP") -> {dominante:"Ti", auxiliaire:"Ne", tertiaire:"Si", inferieure:"Fe"}
function espMbtiComputeHierarchy(typeLetters){
  const EI = typeLetters[0], SN = typeLetters[1], TF = typeLetters[2], JP = typeLetters[3];
  const percLetter = SN, judgLetter = TF;
  const shadowPerc = percLetter === 'S' ? 'N' : 'S';
  const shadowJudg = judgLetter === 'T' ? 'F' : 'T';

  let percPolarity, judgPolarity;
  if (JP === 'J') { judgPolarity = 'e'; percPolarity = 'i'; }
  else { percPolarity = 'e'; judgPolarity = 'i'; }

  const funcPerc = percLetter + percPolarity;
  const funcJudg = judgLetter + judgPolarity;

  let dominante, auxiliaire;
  if (EI === 'E') {
    if (percPolarity === 'e') { dominante = funcPerc; auxiliaire = funcJudg; }
    else { dominante = funcJudg; auxiliaire = funcPerc; }
  } else {
    if (percPolarity === 'i') { dominante = funcPerc; auxiliaire = funcJudg; }
    else { dominante = funcJudg; auxiliaire = funcPerc; }
  }

  const auxLetter = auxiliaire[0], auxPolarity = auxiliaire[1];
  const auxIsPerc = (auxLetter === 'S' || auxLetter === 'N');
  const tertLetter = auxIsPerc ? shadowPerc : shadowJudg;
  const tertPolarity = auxPolarity === 'e' ? 'i' : 'e';
  const tertiaire = tertLetter + tertPolarity;

  const domLetter = dominante[0], domPolarity = dominante[1];
  const domIsPerc = (domLetter === 'S' || domLetter === 'N');
  const infLetter = domIsPerc ? shadowPerc : shadowJudg;
  const infPolarity = domPolarity === 'e' ? 'i' : 'e';
  const inferieure = infLetter + infPolarity;

  return { dominante, auxiliaire, tertiaire, inferieure };
}

async function espMbtiComputeAndSave(){
  const scores = espMbtiScore();
  _espMbtiEgalites = espMbtiDetectEgalites(scores);
  const unresolved = _espMbtiEgalites.some(eg => !_espMbtiEgaliteChoix[eg.axe.join('/')]);
  if(_espMbtiEgalites.length > 0 && unresolved){
    _espMbtiView = 'egalite';
    espMbtiRefreshContainer();
    return;
  }

  const typeLetters = MBTI_AXES.map(([a,b]) => espMbtiLettreAxe(scores, a, b)).join('');
  const hierarchie = espMbtiComputeHierarchy(typeLetters);
  const egalitesResolues = _espMbtiEgalites.map(eg => eg.axe.join('/'));

  _espMbtiLastResult = { identity: {..._espMbtiIdentity}, scores, typeLetters, hierarchie, egalites: egalitesResolues };

  const session = espSession();
  let synced = true;
  try {
    const ok = await espMbtiSaveResultRPC(session.id, session.password, _espMbtiCurrentSession.id, _espMbtiIdentity, scores, typeLetters, hierarchie, egalitesResolues);
    if(!ok) synced = false;
  } catch(e){ synced = false; }

  if(!synced){
    const pending = espMbtiLoadPending();
    const tempId = Date.now().toString(36) + Math.random().toString(36).slice(2,6);
    pending.push({ tempId, sessionId: _espMbtiCurrentSession.id, eleve: {..._espMbtiIdentity}, scores, typeLetters, hierarchie, egalites: egalitesResolues });
    espMbtiSavePending(pending);
  }
  _espMbtiLastResult.synced = synced;

  _espMbtiCurrentResults.push({
    id: synced ? 'srv-' + Date.now() : 'pending-local', sessionId: _espMbtiCurrentSession.id,
    nom:_espMbtiIdentity.nom, prenom:_espMbtiIdentity.prenom, naissance:_espMbtiIdentity.naissance, classe:_espMbtiIdentity.classe,
    scores, typeLetters, hierarchie, egalites: egalitesResolues, pending: !synced,
  });

  _espMbtiView = 'result';
  espMbtiRefreshContainer();
}

/* ---------------- Écran "egalite" (arbitrage manuel) ---------------- */
function espMbtiRenderEgalite(){
  return `
    <div class="esp-card">
      <div class="esp-title" style="font-size:16px;">⚖️ Égalité(s) à trancher</div>
      <p class="esp-sub">Le score est à égalité sur ${_espMbtiEgalites.length > 1 ? 'ces axes' : 'cet axe'}. Choisis la lettre qui correspond le mieux à l'élève.</p>
      ${_espMbtiEgalites.map(eg => `
        <div class="esp-field" style="margin-bottom:16px;">
          <label>${MBTI_DIMENSIONS[eg.axe[0]].name} (${eg.axe[0]}) vs ${MBTI_DIMENSIONS[eg.axe[1]].name} (${eg.axe[1]}) — ${eg.scoreA}/10 chacun</label>
          <div style="display:flex; gap:10px; margin-top:6px;">
            <button class="esp-btn ${_espMbtiEgaliteChoix[eg.axe.join('/')] === eg.axe[0] ? 'esp-btn-primary' : ''}" onclick="espMbtiChoisirEgalite('${eg.axe[0]}','${eg.axe[1]}','${eg.axe[0]}')">${eg.axe[0]} — ${MBTI_DIMENSIONS[eg.axe[0]].name}</button>
            <button class="esp-btn ${_espMbtiEgaliteChoix[eg.axe.join('/')] === eg.axe[1] ? 'esp-btn-primary' : ''}" onclick="espMbtiChoisirEgalite('${eg.axe[0]}','${eg.axe[1]}','${eg.axe[1]}')">${eg.axe[1]} — ${MBTI_DIMENSIONS[eg.axe[1]].name}</button>
          </div>
        </div>
      `).join('')}
      <button class="esp-btn esp-btn-primary" onclick="espMbtiConfirmerEgalites()" ${_espMbtiEgalites.some(eg => !_espMbtiEgaliteChoix[eg.axe.join('/')]) ? 'disabled' : ''}>Valider et voir le résultat →</button>
    </div>
  `;
}
function espMbtiChoisirEgalite(a, b, choix){
  _espMbtiEgaliteChoix[a+'/'+b] = choix;
  espMbtiRefreshContainer();
}
async function espMbtiConfirmerEgalites(){
  await espMbtiComputeAndSave(); // relance le calcul, cette fois toutes les égalités sont résolues
}

/* ---------------- Écran résultat individuel ---------------- */
function espMbtiDimRowsHtml(scores){
  return MBTI_AXES.map(([a,b]) => {
    const scoreA = scores[a], scoreB = scores[b];
    const pctA = Math.round((scoreA / 10) * 100);
    return `
      <div class="esp-lycam-dim-row">
        <div class="esp-lycam-dim-name">${a}/${b}<small>${escapeHtml(MBTI_DIMENSIONS[a].name)} vs ${escapeHtml(MBTI_DIMENSIONS[b].name)}</small></div>
        <div class="esp-lycam-dim-track"><div class="esp-lycam-dim-fill ok" style="width:${pctA}%;"></div></div>
        <div class="esp-lycam-dim-score">${a} ${scoreA}/10 — ${b} ${scoreB}/10</div>
      </div>`;
  }).join('');
}

function espMbtiHierarchieRowHtml(niveau, label, code){
  return `
    <div class="esp-lycam-dim-row" style="flex-direction:column; align-items:flex-start; gap:4px;">
      <div style="font-weight:700;">${label} — <span style="color:var(--orange-dark);">${code}</span></div>
      <div class="esp-sub" style="margin:0;"><i>${escapeHtml(MBTI_ROLE_HIERARCHIE[niveau])}</i></div>
      <div style="font-size:13.5px;">${escapeHtml(MBTI_FONCTIONS[code] || '')}</div>
    </div>`;
}

function espMbtiHierarchyHtml(hierarchie){
  return [
    espMbtiHierarchieRowHtml('dominante', 'Fonction dominante', hierarchie.dominante),
    espMbtiHierarchieRowHtml('auxiliaire', 'Fonction auxiliaire', hierarchie.auxiliaire),
    espMbtiHierarchieRowHtml('tertiaire', 'Fonction tertiaire', hierarchie.tertiaire),
    espMbtiHierarchieRowHtml('inferieure', 'Fonction inférieure', hierarchie.inferieure),
  ].join('');
}

function espMbtiApprentissageHtml(typeLetters, prenom){
  const lignes = typeLetters.split('').map(l => `<li>${escapeHtml(MBTI_MODE_APPRENTISSAGE[l])}</li>`).join('');
  return `
    <h3 style="font-size:14px; color:var(--green-dark); margin:20px 0 10px;">📚 Comment ${escapeHtml(prenom || "l'élève")} apprend le mieux</h3>
    <ul style="margin:0 0 4px; padding-left:20px; font-size:13.5px; line-height:1.6;">${lignes}</ul>
    <p class="esp-sub" style="margin-top:6px;">Ce n'est pas un jugement de capacité : une matière ou une méthode qui ne correspond pas à ces préférences demandera simplement plus d'efforts, sans que ce soit un manque d'intelligence.</p>
  `;
}

function espMbtiOrientationHtml(typeLetters, dominanteCode){
  const dom = MBTI_FILIERES_PAR_FONCTION[dominanteCode] || { categorie:'', exemples:'' };
  const type = MBTI_TYPES[typeLetters] || { nom:'', desc:'', filieres:'' };
  return `
    <h3 style="font-size:14px; color:var(--green-dark); margin:20px 0 10px;">🎯 Pistes d'orientation</h3>
    <p style="font-size:13.5px; line-height:1.6; margin:0 0 8px;">
      Grâce à sa fonction dominante (<b>${dominanteCode}</b>), cet élève est naturellement attiré par des
      <b>${escapeHtml((dom.categorie||'').toLowerCase())}</b>. Quelques exemples concrets de filières :
      ${escapeHtml(dom.exemples||'')}.
    </p>
    <p style="font-size:13.5px; line-height:1.6; margin:0;">
      Plus largement, le profil <b>${typeLetters}</b> (${escapeHtml(type.nom)}) — ${escapeHtml(type.desc)} —
      s'épanouit souvent dans : ${escapeHtml(type.filieres)}
    </p>
    <p class="esp-sub" style="margin-top:8px;">Ces pistes sont des points de départ pour la discussion d'orientation, pas une prescription : à croiser avec les résultats scolaires, les envies et le contexte familial de l'élève.</p>
  `;
}

function espMbtiRenderResult(){
  const r = _espMbtiLastResult;
  const count = _espMbtiCurrentResults.length;
  const remaining = 150 - count;
  const typeInfo = MBTI_TYPES[r.typeLetters] || { nom:'', desc:'', filieres:'' };
  return `
    <div class="esp-card">
      <div class="esp-title" style="font-size:16px;">${escapeHtml((r.identity.prenom + ' ' + r.identity.nom).trim())}</div>
      <p class="esp-sub">${[r.identity.classe, r.identity.naissance ? 'né(e) en ' + r.identity.naissance : ''].filter(Boolean).join(' · ')}</p>
      ${!r.synced ? `<p class="esp-sub" style="color:var(--orange-dark);">⚠️ Résultat enregistré localement, en attente de synchronisation (connexion instable).</p>` : ''}
      <div class="esp-lycam-hero esp-lycam-hero-low">
        <div class="esp-lycam-hero-num" style="font-size:22px;">${r.typeLetters}</div>
        <div>
          <div class="esp-lycam-hero-title">${escapeHtml(typeInfo.nom)}</div>
          <div class="esp-lycam-hero-desc">${escapeHtml(typeInfo.desc)}</div>
        </div>
      </div>
      <div style="margin:20px 0;">${espMbtiDimRowsHtml(r.scores)}</div>
      <h3 style="font-size:14px; color:var(--green-dark); margin:20px 0 12px;">Hiérarchie des fonctions cognitives</h3>
      <div style="margin-bottom:6px;">${espMbtiHierarchyHtml(r.hierarchie)}</div>
      ${espMbtiApprentissageHtml(r.typeLetters, r.identity.prenom)}
      ${espMbtiOrientationHtml(r.typeLetters, r.hierarchie.dominante)}
      <p class="esp-sub" style="margin-top:16px;">${count} élève(s) testé(s) dans cette session${remaining > 0 ? ' · ' + remaining + ' place(s) restante(s)' : ' · limite de 150 atteinte'}.</p>
      <div style="display:flex; gap:10px; flex-wrap:wrap; justify-content:flex-end;">
        <button class="esp-btn" onclick="espMbtiDownloadIndividual()">⬇ Télécharger la fiche</button>
        <button class="esp-btn" onclick="espMbtiShowReport()">📊 Rapport de session</button>
        ${count < 150 ? `<button class="esp-btn esp-btn-primary" onclick="espMbtiGoToIdentity()">Élève suivant →</button>` : ''}
      </div>
    </div>
  `;
}

/* ---------------- Rapport de session ---------------- */
function espMbtiShowReport(){
  _espMbtiView = 'report';
  espMbtiRefreshContainer();
}

function espMbtiRenderReport(){
  const results = _espMbtiCurrentResults;
  const typeCounts = {};
  results.forEach(s => { typeCounts[s.typeLetters] = (typeCounts[s.typeLetters]||0) + 1; });
  const pendingCount = results.filter(s => s.pending).length;

  // Répartition par lettre dominante de chaque axe (proportion dans le groupe)
  const axeDistribHtml = MBTI_AXES.map(([a,b]) => {
    const idx = MBTI_AXES.findIndex(ax => ax[0]===a);
    const nbA = results.filter(s => s.typeLetters && s.typeLetters[idx] === a).length;
    const nbB = results.length - nbA;
    const pctA = results.length ? Math.round((nbA/results.length)*100) : 0;
    return `
      <div class="esp-lycam-dim-row">
        <div class="esp-lycam-dim-name">${a}/${b}<small>${escapeHtml(MBTI_DIMENSIONS[a].name)} vs ${escapeHtml(MBTI_DIMENSIONS[b].name)}</small></div>
        <div class="esp-lycam-dim-track"><div class="esp-lycam-dim-fill ok" style="width:${pctA}%;"></div></div>
        <div class="esp-lycam-dim-score">${a} ${nbA} — ${b} ${nbB} <small>(${pctA}% ${a})</small></div>
      </div>`;
  }).join('');

  const typeRows = Object.keys(typeCounts).sort((x,y) => typeCounts[y]-typeCounts[x]).map(t => `
    <tr><td>${t} — ${escapeHtml((MBTI_TYPES[t]||{}).nom||'')}</td><td style="text-align:center;">${typeCounts[t]}</td></tr>
  `).join('');

  const domCounts = {};
  results.forEach(s => { if(s.hierarchie && s.hierarchie.dominante) domCounts[s.hierarchie.dominante] = (domCounts[s.hierarchie.dominante]||0) + 1; });
  const domRows = Object.keys(domCounts).sort((x,y) => domCounts[y]-domCounts[x]).map(code => `
    <tr><td>${code}</td><td style="text-align:center;">${domCounts[code]} élève(s)</td></tr>
  `).join('');

  return `
    <div class="esp-card">
      <button class="esp-back" onclick="espMbtiBackToList()">← Toutes les sessions</button>
      <div class="esp-title" style="font-size:16px;">📊 ${escapeHtml(_espMbtiCurrentSession.nom)}</div>
      <p class="esp-sub">${results.length} élève(s) testé(s)${pendingCount ? ' · ' + pendingCount + ' en attente de synchronisation' : ''}.</p>
      <div class="esp-stat-grid">
        <div class="esp-stat-box"><div class="esp-stat-num">${results.length}</div><div class="esp-stat-label">Élèves testés</div></div>
        <div class="esp-stat-box"><div class="esp-stat-num">${Object.keys(typeCounts).length}</div><div class="esp-stat-label">Types différents</div></div>
      </div>
      <h3 style="font-size:14px; color:var(--green-dark); margin:20px 0 12px;">Répartition par type</h3>
      ${results.length ? `<table style="width:100%; border-collapse:collapse; font-size:13px;"><thead><tr><th style="text-align:left; padding:6px;">Type</th><th style="padding:6px;">Élèves</th></tr></thead><tbody>${typeRows}</tbody></table>` : `<p class="esp-empty">Aucun élève testé pour l'instant dans cette session.</p>`}
      <h3 style="font-size:14px; color:var(--green-dark); margin:20px 0 12px;">Répartition par axe</h3>
      ${results.length ? axeDistribHtml : ''}
      <h3 style="font-size:14px; color:var(--green-dark); margin:20px 0 12px;">Diversité cognitive (fonction dominante)</h3>
      ${results.length ? `<table style="width:100%; border-collapse:collapse; font-size:13px;"><thead><tr><th style="text-align:left; padding:6px;">Fonction dominante</th><th style="padding:6px;">Élèves</th></tr></thead><tbody>${domRows}</tbody></table>` : ''}
      <div style="display:flex; gap:10px; flex-wrap:wrap; justify-content:flex-end; margin-top:22px;">
        <button class="esp-btn" onclick="window.print()">🖨 Imprimer</button>
        <button class="esp-btn" onclick="espMbtiDownloadCsv()">⬇ Données (CSV)</button>
        <button class="esp-btn" onclick="espMbtiDownloadReport()">⬇ Rapport (HTML)</button>
        <button class="esp-btn esp-btn-primary" onclick="espMbtiGoToIdentity()">+ Ajouter un élève</button>
      </div>
    </div>
  `;
}

async function espMbtiManualRetrySync(){
  await espMbtiRetrySync();
  espMbtiInitTab();
}

/* ============================================================
   Téléchargements (fiche individuelle, rapport de session, CSV)
   ============================================================ */
function espMbtiTriggerDownload(filename, content, mime){
  const blob = new Blob([content], { type: mime + ';charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = filename;
  document.body.appendChild(a); a.click(); document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
function espMbtiSlugify(s){
  return (s||'sans-nom').toString().normalize('NFD').replace(/[\u0300-\u036f]/g,'')
    .replace(/[^a-zA-Z0-9]+/g,'-').replace(/^-+|-+$/g,'') || 'sans-nom';
}
function espMbtiReportShell(title, bodyHtml){
  return `<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><title>${escapeHtml(title)}</title>
<style>
  body{font-family:'Segoe UI',Roboto,Arial,sans-serif; background:#fffaf3; color:#1f2b22; margin:0; padding:28px 16px;}
  .wrap{max-width:680px; margin:0 auto; background:#fff; border:1px solid #f0d9b5; border-radius:16px; padding:32px clamp(20px,5vw,40px);}
  h1{font-size:22px; margin:0 0 4px;} h2{font-size:16px; color:#157a40; margin:26px 0 10px;}
  p.sub{color:#6b7d70; font-size:13.5px; margin:0 0 22px;}
  table{width:100%; border-collapse:collapse; font-size:12.5px; margin-bottom:10px;}
  th,td{border:1px solid #f0d9b5; padding:8px 9px; text-align:left;}
  th{background:#fffaf3; font-size:11px; text-transform:uppercase; color:#6b7d70;}
  .badge{display:inline-block; font-weight:800; font-size:13px; padding:6px 14px; border-radius:99px; margin-bottom:16px; background:#e9f7ee; color:#157a40;}
  .stat-grid{display:flex; gap:12px; flex-wrap:wrap; margin:18px 0 24px;}
  .stat-box{flex:1; min-width:110px; background:#fffaf3; border:1px solid #f0d9b5; border-radius:12px; padding:12px; text-align:center;}
  .stat-num{font-size:22px; font-weight:800; color:#e8650a;} .stat-label{font-size:11px; color:#6b7d70; margin-top:2px;}
  footer{text-align:center; font-size:11px; color:#8c99a6; margin-top:24px;}
</style></head><body><div class="wrap">${bodyHtml}
<footer>Généré depuis ORIMETIER — le ${new Date().toLocaleDateString('fr-FR')}</footer></div></body></html>`;
}
function espMbtiDimTableRows(scores){
  return MBTI_AXES.map(([a,b]) => {
    return `<tr><td>${a} — ${escapeHtml(MBTI_DIMENSIONS[a].name)}</td><td style="text-align:center;">${scores[a]}/10</td><td>${b} — ${escapeHtml(MBTI_DIMENSIONS[b].name)}</td><td style="text-align:center;">${scores[b]}/10</td></tr>`;
  }).join('');
}
function espMbtiDownloadIndividual(){
  const r = _espMbtiLastResult; if(!r) return;
  const typeInfo = MBTI_TYPES[r.typeLetters] || { nom:'', desc:'', filieres:'' };
  const body = `<h1>${escapeHtml((r.identity.prenom+' '+r.identity.nom).trim())}</h1>
    <p class="sub">${[r.identity.classe, r.identity.naissance?'né(e) en '+r.identity.naissance:''].filter(Boolean).map(escapeHtml).join(' · ')}</p>
    <span class="badge">${escapeHtml(r.typeLetters)} — ${escapeHtml(typeInfo.nom)}</span>
    <p style="font-size:13.5px; color:#4a5568; line-height:1.6;">${escapeHtml(typeInfo.desc)}</p>
    <h2>Scores par axe</h2>
    <table><thead><tr><th>Pôle A</th><th>Score</th><th>Pôle B</th><th>Score</th></tr></thead><tbody>${espMbtiDimTableRows(r.scores)}</tbody></table>
    <h2>Hiérarchie des fonctions cognitives</h2>
    <table><thead><tr><th>Rang</th><th>Fonction</th><th>Description</th></tr></thead><tbody>
      <tr><td>Dominante</td><td>${r.hierarchie.dominante}</td><td>${escapeHtml(MBTI_FONCTIONS[r.hierarchie.dominante]||'')}</td></tr>
      <tr><td>Auxiliaire</td><td>${r.hierarchie.auxiliaire}</td><td>${escapeHtml(MBTI_FONCTIONS[r.hierarchie.auxiliaire]||'')}</td></tr>
      <tr><td>Tertiaire</td><td>${r.hierarchie.tertiaire}</td><td>${escapeHtml(MBTI_FONCTIONS[r.hierarchie.tertiaire]||'')}</td></tr>
      <tr><td>Inférieure</td><td>${r.hierarchie.inferieure}</td><td>${escapeHtml(MBTI_FONCTIONS[r.hierarchie.inferieure]||'')}</td></tr>
    </tbody></table>
    <h2>Comment ${escapeHtml(r.identity.prenom || "l'élève")} apprend le mieux</h2>
    <ul style="font-size:13px; line-height:1.6;">${r.typeLetters.split('').map(l => `<li>${escapeHtml(MBTI_MODE_APPRENTISSAGE[l]||'')}</li>`).join('')}</ul>
    <p style="font-size:12.5px; color:#6b7d70;">Ce n'est pas un jugement de capacité : une matière ou une méthode qui ne correspond pas à ces préférences demandera simplement plus d'efforts, sans que ce soit un manque d'intelligence.</p>
    <h2>Pistes d'orientation</h2>
    <p style="font-size:13px; line-height:1.6;">Grâce à sa fonction dominante (${r.hierarchie.dominante}), cet élève est naturellement attiré par des <b>${escapeHtml(((MBTI_FILIERES_PAR_FONCTION[r.hierarchie.dominante]||{}).categorie||'').toLowerCase())}</b>. Exemples concrets de filières : ${escapeHtml((MBTI_FILIERES_PAR_FONCTION[r.hierarchie.dominante]||{}).exemples||'')}.</p>
    <p style="font-size:13px; line-height:1.6;">Plus largement, le profil ${r.typeLetters} (${escapeHtml(typeInfo.nom)}) — ${escapeHtml(typeInfo.desc)} — s'épanouit souvent dans : ${escapeHtml(typeInfo.filieres)}</p>
    <p style="font-size:12.5px; color:#6b7d70;">Ces pistes sont des points de départ pour la discussion d'orientation, pas une prescription : à croiser avec les résultats scolaires, les envies et le contexte familial de l'élève.</p>`;
  const html = espMbtiReportShell('MBTI — ' + (r.identity.prenom+' '+r.identity.nom).trim(), body);
  espMbtiTriggerDownload(`MBTI_${espMbtiSlugify(r.identity.nom)}_${espMbtiSlugify(r.identity.prenom)}.html`, html, 'text/html');
}
function espMbtiDownloadReport(){
  const results = _espMbtiCurrentResults;
  const typeCounts = {};
  results.forEach(s => { typeCounts[s.typeLetters] = (typeCounts[s.typeLetters]||0) + 1; });
  const typeRows = Object.keys(typeCounts).sort((x,y) => typeCounts[y]-typeCounts[x]).map(t => {
    const pct = results.length ? Math.round((typeCounts[t]/results.length)*100) : 0;
    return `<tr><td>${t} — ${escapeHtml((MBTI_TYPES[t]||{}).nom||'')}</td><td style="text-align:center;">${typeCounts[t]}</td><td style="text-align:center;">${pct}%</td></tr>`;
  }).join('');
  const body = `<h1>Rapport de session — ${escapeHtml(_espMbtiCurrentSession.nom)}</h1>
    <p class="sub">${results.length} élève(s) testé(s).</p>
    <div class="stat-grid">
      <div class="stat-box"><div class="stat-num">${results.length}</div><div class="stat-label">Élèves testés</div></div>
      <div class="stat-box"><div class="stat-num">${Object.keys(typeCounts).length}</div><div class="stat-label">Types différents</div></div>
    </div>
    <h2>Répartition par type</h2>
    <table><thead><tr><th>Type</th><th>Élèves</th><th>%</th></tr></thead><tbody>${typeRows}</tbody></table>`;
  const html = espMbtiReportShell('MBTI — ' + _espMbtiCurrentSession.nom, body);
  espMbtiTriggerDownload(`MBTI_rapport_${espMbtiSlugify(_espMbtiCurrentSession.nom)}.html`, html, 'text/html');
}
function espMbtiDownloadCsv(){
  const results = _espMbtiCurrentResults;
  const dimCodes = Object.keys(MBTI_DIMENSIONS);
  function esc(v){ v = (v===undefined||v===null)?'':String(v); return /[",;\n]/.test(v) ? '"'+v.replace(/"/g,'""')+'"' : v; }
  const header = ['Nom','Prenom','Annee naissance','Classe','Type', ...dimCodes.map(c=>c+'_score'), 'Dominante','Auxiliaire','Tertiaire','Inferieure','Categorie_Filieres_Dominante','Egalites tranchees'];
  const rows = results.map(s => {
    const base = [s.nom, s.prenom, s.naissance, s.classe, s.typeLetters];
    const scoreVals = dimCodes.map(c => s.scores[c]);
    const hier = s.hierarchie || {};
    const categorieDom = (MBTI_FILIERES_PAR_FONCTION[hier.dominante] || {}).categorie || '';
    const egal = (s.egalites||[]).join(' | ');
    return [...base, ...scoreVals, hier.dominante, hier.auxiliaire, hier.tertiaire, hier.inferieure, categorieDom, egal].map(esc).join(';');
  });
  const csv = '\uFEFF' + header.map(esc).join(';') + '\n' + rows.join('\n');
  espMbtiTriggerDownload(`MBTI_donnees_${espMbtiSlugify(_espMbtiCurrentSession.nom)}.csv`, csv, 'text/csv');
}
