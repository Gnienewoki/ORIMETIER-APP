// ============================================================
// ---- Test LYCAM (repérage préventif du décrochage) ----
// ---- Intégré à l'espace inspecteur, données rattachées à Supabase ----
// ============================================================

/* ---- Données du questionnaire (41 questions, grille de dépouillement vérifiée) ---- */
const DIMENSIONS = {
  IE:{name:"Intérêt pour l'école", seuil:2},
  AF:{name:"Attitude de la famille", seuil:2},
  RS:{name:"Rendement scolaire", seuil:2},
  CS:{name:"Confiance en soi", seuil:3},
  AB:{name:"Absentéisme", seuil:2},
  BS:{name:"Besoin de soutien de l'équipe éducative", seuil:3},
  PS:{name:"Projet scolaire", seuil:4},
};

const QUESTIONS = [
{n:1,dim:'IE',prompt:"D'une façon générale, est-ce que tu aimes ou non aller au lycée ?",risk:['D','E'],opts:[
  ['A',"Oui, j'aime ça"],['B',"J'aime ça plus ou moins"],['C',"Ça m'est égal"],['D',"Je n'aime pas ça"],['E',"J'en ai marre du lycée"]]},
{n:2,dim:'AF',prompt:"Tes parents rencontrent-ils les professeurs :",risk:['C','D','E'],opts:[
  ['A',"À l'occasion de réunions parents-professeurs"],['B',"En prenant rendez-vous avec un professeur"],['C',"S'ils sont convoqués"],['D',"Rarement parce qu'ils n'ont pas le temps"],['E',"Rarement parce qu'ils n'aiment pas venir au lycée"]]},
{n:3,dim:'IE',prompt:"Pourquoi fréquentes-tu le lycée ? (choisis une seule raison, la plus vraie dans ton cas)",risk:['C','F'],opts:[
  ['A',"Parce que j'aime ça"],['B',"Pour avoir un bon métier"],['C',"Comme ça, sans me poser de question"],['D',"Pour rencontrer des copains, des copines"],['E',"Parce que j'ai des projets précis"],['F',"Parce que j'y suis obligé(e)"]]},
{n:4,dim:'RS',prompt:"Depuis les trois dernières années, tes résultats scolaires sont-ils satisfaisants ?",risk:['C','D'],opts:[
  ['A',"Oui, très satisfaisants"],['B',"Satisfaisants"],['C',"Peu satisfaisants"],['D',"Pas du tout satisfaisants"]]},
{n:5,dim:'RS',prompt:"Pendant les cours écoutes-tu attentivement :",risk:['A','D'],opts:[
  ['A',"Cela dépend des jours"],['B',"Cela dépend des cours, de mon intérêt"],['C',"Oui, toujours"],['D',"Non, je me laisse facilement distraire"]]},
{n:6,dim:'AB',prompt:"Parmi les phrases suivantes, quelle est celle qui te représente le mieux ?",risk:['C','D'],opts:[
  ['A',"Je supporte très bien les règlements et les façons de faire du lycée"],['B',"Je supporte assez bien les règlements et le travail imposé par le lycée"],['C',"Je supporte difficilement les règlements et le travail imposé par le lycée"],['D',"Je ne supporte pas du tout les règlements et le travail imposé"]]},
{n:7,dim:'BS',prompt:"Avec le personnel du lycée (enseignants, surveillants, direction, infirmière, conseiller d'éducation, documentaliste...) tu penses que tes relations sont :",risk:['C','D'],opts:[
  ['A',"Très bonnes"],['B',"Bonnes"],['C',"Plus ou moins bonnes"],['D',"Mauvaises"]]},
{n:8,dim:'RS',prompt:"D'après les premières évaluations ou notes, tu penses que :",risk:['B','D'],opts:[
  ['A',"Ton année scolaire va bien se dérouler"],['B',"Ce sera trop difficile pour toi"],['C',"Tu y arriveras avec beaucoup de travail"],['D',"Quels que soient les résultats, cela t'est égal"]]},
{n:9,dim:'IE',prompt:"Quelle attitude as-tu devant un mauvais résultat ?",risk:['A','C'],opts:[
  ['A',"Ça m'est égal"],['B',"Ça me décourage un peu et j'ai du mal à m'en remettre"],['C',"Ça me décourage beaucoup et j'ai envie d'abandonner"],['D',"Je travaille plus pour me rattraper"]]},
{n:10,dim:'AF',prompt:"Le soir tes parents parlent-ils avec toi du lycée :",risk:['C','D'],opts:[
  ['A',"Souvent"],['B',"Quand il y a un évènement particulier"],['C',"Uniquement si c'est nécessaire (papiers administratifs, carnet de correspondance...)"],['D',"Très rarement"]]},
{n:11,dim:'BS',prompt:"Selon toi, tes relations avec les professeurs sont :",risk:['C','D'],opts:[
  ['A',"Très bonnes"],['B',"Bonnes"],['C',"Plus ou moins bonnes"],['D',"Mauvaises"]]},
{n:12,dim:'IE',prompt:"Cette année, les cours :",risk:['C','D'],opts:[
  ['A',"T'intéressent tous"],['B',"T'intéressent pour la plupart"],['C',"Ne t'intéressent généralement pas"],['D',"Ne t'intéressent pas du tout"]]},
{n:13,dim:'PS',prompt:"Te sens-tu prêt(e) actuellement à quitter l'école pour aller travailler ?",risk:['C','D'],opts:[
  ['A',"Sûrement pas"],['B',"Pas encore"],['C',"Presque"],['D',"Tout à fait"]]},
{n:14,dim:'RS',prompt:"As-tu des résultats corrects ?",risk:['A','C'],opts:[
  ['A',"Non, je n'y arrive pas, même en travaillant"],['B',"Oui, en travaillant régulièrement"],['C',"Non, je n'ai pas envie de faire des efforts"],['D',"Oui, en étant attentif(ve) en classe"]]},
{n:15,dim:'RS',prompt:"Après le lycée combien d'heures par semaine passes-tu à tes devoirs ou leçons ?",risk:['D','E'],opts:[
  ['A',"Plus de 10 heures / semaine"],['B',"De 6 à 10 heures / semaine"],['C',"De 2 à 5 heures / semaine"],['D',"Moins de 2 heures / semaine"],['E',"Aucune"]]},
{n:16,dim:'AB',prompt:"Je m'absente, mais je m'absenterais moins souvent si on me payait pour venir au lycée. Es-tu d'accord avec cette idée ?",risk:['C','E'],opts:[
  ['A',"Absolument pas d'accord"],['B',"Pas tout à fait d'accord"],['C',"Assez d'accord"],['D',"Je suis rarement absent(e)"],['E',"Tout à fait d'accord"]]},
{n:17,dim:'PS',prompt:"Jusqu'où penses-tu poursuivre tes études ?",risk:['C','D'],opts:[
  ['A',"Jusqu'à un diplôme (CAP-BAC...)"],['B',"Le plus loin possible"],['C',"Je pense que je n'irai pas plus loin que cette année"],['D',"Si j'avais eu le choix, j'aurais déjà quitté"]]},
{n:18,dim:'AF',prompt:"Ta famille souhaite que :",risk:['C','D'],opts:[
  ['A',"Tu obtiennes un diplôme (CAP-BAC...)"],['B',"Tu continues tes études le plus loin possible"],['C',"Tu gagnes ta vie le plus vite possible"],['D',"Je ne sais pas"]]},
{n:19,dim:'AB',prompt:"Est-ce que tu as déjà manqué des cours pour des raisons que le lycée ne trouve pas valables ? (cette année ou l'année dernière)",risk:['C','D'],opts:[
  ['A',"Jamais"],['B',"Une ou deux fois"],['C',"Plusieurs fois"],['D',"Très souvent"]]},
{n:20,dim:'PS',prompt:"Si on te permettait d'abandonner le lycée dès maintenant, que ferais-tu ?",risk:['B','C'],opts:[
  ['A',"Je ne quitterais pas"],['B',"Je ne sais pas"],['C',"Je quitterais le lycée"]]},
{n:21,dim:'AF',prompt:"Pour ton travail scolaire, est-ce que ta famille (parents, sœurs, frères aînés...)",risk:['D','E'],opts:[
  ['A',"T'apporte une aide"],['B',"Contrôle ce que tu as fait"],['C',"Te fait confiance"],['D',"N'a pas le temps de s'en occuper"],['E',"Ne s'y intéresse pas"]]},
{n:22,dim:'PS',prompt:"As-tu l'intention de terminer les études que tu as commencées ?",risk:['B'],opts:[['A',"Certainement"],['B',"Peut-être"]]},
{n:23,dim:'PS',prompt:"Dès que possible j'accepte n'importe quoi comme travail plutôt que de continuer à aller au lycée.",risk:['A'],opts:[['A',"Oui"],['B',"Non"]]},
{n:24,dim:'CS',prompt:"Cette année, je pense que ça va aller pour moi à l'école.",risk:['B'],opts:[['A',"Oui"],['B',"Non"]]},
{n:25,dim:'CS',prompt:"En général, je suis à peu près sûr(e) de réussir ce que je fais.",risk:['B'],opts:[['A',"Oui"],['B',"Non"]]},
{n:26,dim:'PS',prompt:"J'ai obtenu l'orientation que je souhaitais.",risk:['B'],opts:[['A',"Oui"],['B',"Non"]]},
{n:27,dim:'IE',prompt:"En général, j'aime le lycée.",risk:['B'],opts:[['A',"Oui"],['B',"Non"]]},
{n:28,dim:'CS',prompt:"J'ai confiance en mes possibilités de réussite à l'école.",risk:['B'],opts:[['A',"Oui"],['B',"Non"]]},
{n:29,dim:'AF',prompt:"Mes parents savent dans quelle classe je suis.",risk:['B'],opts:[['A',"Oui"],['B',"Non"]]},
{n:30,dim:'BS',prompt:"Quand j'ai des problèmes, la plupart de mes professeurs font des efforts pour me comprendre.",risk:['B'],opts:[['A',"Oui"],['B',"Non"]]},
{n:31,dim:'AB',prompt:'Souvent, j\'ai envie de "sécher" les cours.',risk:['A'],opts:[['A',"Oui"],['B',"Non"]]},
{n:32,dim:'PS',prompt:"Si j'échoue cette année, je vais peut-être abandonner le lycée.",risk:['A'],opts:[['A',"Oui"],['B',"Non"]]},
{n:33,dim:'BS',prompt:"La plupart de mes professeurs me donnent envie d'apprendre.",risk:['B'],opts:[['A',"Oui"],['B',"Non"]]},
{n:34,dim:'BS',prompt:"En général, j'aime bien la façon dont mes professeurs font cours.",risk:['B'],opts:[['A',"Oui"],['B',"Non"]]},
{n:35,dim:'AB',prompt:"J'aime m'absenter du lycée.",risk:['A'],opts:[['A',"Oui"],['B',"Non"]]},
{n:36,dim:'IE',prompt:"Je préfèrerais avoir d'autres cours que ceux de cette année.",risk:['A'],opts:[['A',"Oui"],['B',"Non"]]},
{n:37,dim:'CS',prompt:"Je risque d'échouer cette année au lycée.",risk:['A'],opts:[['A',"Oui"],['B',"Non"]]},
{n:38,dim:'BS',prompt:"En général, mes professeurs essaient de me comprendre.",risk:['B'],opts:[['A',"Oui"],['B',"Non"]]},
{n:39,dim:'AB',prompt:"Quand je suis absent(e) du lycée, j'ai une raison valable.",risk:['B'],opts:[['A',"Oui"],['B',"Non"]]},
{n:40,dim:'CS',prompt:"Je réussis mieux dans ce que je fais en dehors du lycée que dans les matières scolaires.",risk:['A'],opts:[['A',"Oui"],['B',"Non"]]},
{n:41,dim:'IE',prompt:"Je trouve désagréable d'aller en classe, que ce soit ici ou dans un autre lycée.",risk:['A'],opts:[['A',"Oui"],['B',"Non"]]},
];

/* ---- État de l'onglet LYCAM ---- */
let _espLycamView = 'list'; // 'list' | 'identity' | 'quiz' | 'result' | 'report'
let _espLycamSessions = [];
let _espLycamCurrentSession = null; // {id, nom}
let _espLycamCurrentResults = [];   // résultats connus de la session en cours (serveur + en attente)
let _espLycamCurrentQ = 0;
let _espLycamAnswers = {};
let _espLycamIdentity = {};
let _espLycamLastResult = null;
let _espLycamLoading = false;
let _espLycamError = '';

const LYCAM_PENDING_KEY = 'lycam_pending_results_v1';

/* ---------------- File d'attente locale (résilience réseau) ---------------- */
function espLycamLoadPending(){
  try { return JSON.parse(localStorage.getItem(LYCAM_PENDING_KEY) || '[]'); } catch(e){ return []; }
}
function espLycamSavePending(list){
  try { localStorage.setItem(LYCAM_PENDING_KEY, JSON.stringify(list)); } catch(e){}
}
function espLycamPendingForSession(sessionId){
  return espLycamLoadPending().filter(p => p.sessionId === sessionId);
}
async function espLycamRetrySync(){
  const session = espSession();
  const pending = espLycamLoadPending();
  if(!pending.length) return;
  const stillPending = [];
  for(const p of pending){
    try {
      const ok = await espLycamSaveResultRPC(session.id, session.password, p.sessionId, p.eleve, p.scoreTotal, p.band, p.scores);
      if(!ok) stillPending.push(p);
    } catch(e){ stillPending.push(p); }
  }
  espLycamSavePending(stillPending);
}

/* ---------------- Initialisation de l'onglet ---------------- */
async function espLycamInitTab(){
  _espLycamView = 'list';
  _espLycamError = '';
  _espLycamLoading = true;
  espLycamRefreshContainer();
  const session = espSession();
  try {
    await espLycamRetrySync();
    _espLycamSessions = await espLycamListSessionsRPC(session.id, session.password);
  } catch(e){
    _espLycamError = "Impossible de charger les sessions LYCAM : " + e.message;
    _espLycamSessions = [];
  }
  _espLycamLoading = false;
  espLycamRefreshContainer();
}

function espLycamRefreshContainer(){
  const container = document.getElementById('esp-lycam-tab-container');
  if(container) container.innerHTML = espRenderLycamTab();
}

/* ---------------- Rendu principal ---------------- */
function espRenderLycamTab(){
  if(_espLycamView === 'identity') return espLycamRenderIdentity();
  if(_espLycamView === 'quiz') return espLycamRenderQuiz();
  if(_espLycamView === 'result') return espLycamRenderResult();
  if(_espLycamView === 'report') return espLycamRenderReport();
  return espLycamRenderList();
}

function espLycamRenderList(){
  const pendingTotal = espLycamLoadPending().length;
  return `
    <div class="esp-card">
      <div class="esp-title" style="font-size:16px;">🧪 Test LYCAM — repérage préventif</div>
      <p class="esp-sub">Une session correspond à une classe (ou un groupe) testé un jour donné. Tu peux tester 1 à 150 élèves par session.</p>
      ${_espLycamError ? `<p class="esp-error">${escapeHtml(_espLycamError)}</p>` : ''}
      ${pendingTotal ? `<p class="esp-sub" style="color:var(--orange-dark);">⚠️ ${pendingTotal} résultat(s) pas encore synchronisé(s) avec le serveur. <span class="esp-toggle-link" onclick="espLycamManualRetrySync()">Réessayer maintenant</span></p>` : ''}
      ${_espLycamLoading ? `<p class="esp-empty">Chargement...</p>` : `
        <div class="esp-field-row" style="align-items:flex-end;">
          <div class="esp-field" style="flex:2;">
            <label>Nom de la session</label>
            <input type="text" id="esp-lycam-new-name" placeholder="Ex : 2nde B — 05/08/2026">
          </div>
        </div>
        <button class="esp-btn esp-btn-primary" onclick="espLycamCreateSession()">+ Nouvelle session</button>
        <div style="margin-top:20px;">
          ${_espLycamSessions.length ? _espLycamSessions.map(s => `
            <div class="esp-lycam-session-item" onclick="espLycamOpenSession('${s.id}')">
              <div class="esp-lycam-session-name">${escapeHtml(s.nom)}</div>
              <div class="esp-lycam-session-date">${new Date(s.createdAt).toLocaleDateString('fr-FR', {day:'2-digit',month:'2-digit',year:'numeric'})}</div>
            </div>
          `).join('') : `<p class="esp-empty">Aucune session pour l'instant. Crée-en une pour commencer.</p>`}
        </div>
      `}
    </div>
  `;
}

async function espLycamCreateSession(){
  const input = document.getElementById('esp-lycam-new-name');
  const nom = input.value.trim();
  if(!nom){ _espLycamError = "Merci de donner un nom à la session."; espLycamRefreshContainer(); return; }
  const session = espSession();
  try {
    const id = await espLycamCreateSessionRPC(session.id, session.password, nom);
    if(!id){ _espLycamError = "Impossible de créer la session (session expirée ?)."; espLycamRefreshContainer(); return; }
    _espLycamCurrentSession = { id, nom };
    _espLycamCurrentResults = [];
    _espLycamError = '';
    espLycamGoToIdentity();
  } catch(e){
    _espLycamError = "Erreur : " + e.message;
    espLycamRefreshContainer();
  }
}

async function espLycamOpenSession(sessionId){
  const s = _espLycamSessions.find(x => x.id === sessionId);
  if(!s) return;
  _espLycamCurrentSession = { id: s.id, nom: s.nom };
  _espLycamLoading = true;
  espLycamRefreshContainer();
  const session = espSession();
  try {
    const serverResults = await espLycamListResultsRPC(session.id, session.password, sessionId);
    const pending = espLycamPendingForSession(sessionId).map(p => ({
      id: 'pending-' + p.tempId, sessionId, nom:p.eleve.nom, prenom:p.eleve.prenom, naissance:p.eleve.naissance,
      classe:p.eleve.classe, scoreTotal:p.scoreTotal, band:p.band, scores:p.scores, pending:true,
    }));
    _espLycamCurrentResults = [...serverResults, ...pending];
  } catch(e){
    _espLycamError = "Impossible de charger les résultats : " + e.message;
    _espLycamCurrentResults = espLycamPendingForSession(sessionId).map(p => ({
      id:'pending-'+p.tempId, sessionId, nom:p.eleve.nom, prenom:p.eleve.prenom, naissance:p.eleve.naissance,
      classe:p.eleve.classe, scoreTotal:p.scoreTotal, band:p.band, scores:p.scores, pending:true,
    }));
  }
  _espLycamLoading = false;
  _espLycamView = 'report';
  espLycamRefreshContainer();
}

function espLycamGoToIdentity(){
  _espLycamCurrentQ = 0;
  _espLycamAnswers = {};
  _espLycamIdentity = {};
  _espLycamView = 'identity';
  espLycamRefreshContainer();
}

function espLycamBackToList(){
  _espLycamView = 'list';
  _espLycamCurrentSession = null;
  _espLycamCurrentResults = [];
  espLycamInitTab();
}

/* ---------------- Écran identité ---------------- */
function espLycamRenderIdentity(){
  const count = _espLycamCurrentResults.length;
  return `
    <div class="esp-card">
      <button class="esp-back" onclick="espLycamBackToList()">← Toutes les sessions</button>
      <div class="esp-title" style="font-size:16px;">🧪 ${escapeHtml(_espLycamCurrentSession.nom)}</div>
      <p class="esp-sub">Élève n°${count + 1} (jusqu'à 150 par session). Saisis son identité avant de commencer.</p>
      <div class="esp-field-row">
        <div class="esp-field"><label>Nom</label><input type="text" id="lyc-nom"></div>
        <div class="esp-field"><label>Prénom</label><input type="text" id="lyc-prenom"></div>
      </div>
      <div class="esp-field-row">
        <div class="esp-field"><label>Année de naissance</label><input type="number" id="lyc-naissance" placeholder="Ex : 2009"></div>
        <div class="esp-field"><label>Classe</label><input type="text" id="lyc-classe"></div>
      </div>
      <div id="esp-lycam-identity-error"></div>
      <div style="display:flex; justify-content:space-between; margin-top:10px;">
        <button class="esp-btn" onclick="espLycamShowReport()">📊 Voir le rapport de session</button>
        <button class="esp-btn esp-btn-primary" onclick="espLycamStartQuiz()">Commencer le questionnaire →</button>
      </div>
    </div>
  `;
}

function espLycamStartQuiz(){
  const nom = document.getElementById('lyc-nom').value.trim();
  const prenom = document.getElementById('lyc-prenom').value.trim();
  const naissance = document.getElementById('lyc-naissance').value.trim();
  const classe = document.getElementById('lyc-classe').value.trim();
  if(!nom || !prenom){
    document.getElementById('esp-lycam-identity-error').innerHTML = '<p class="esp-error">Merci de renseigner au moins le nom et le prénom.</p>';
    return;
  }
  _espLycamIdentity = { nom, prenom, naissance, classe };
  _espLycamCurrentQ = 0;
  _espLycamAnswers = {};
  _espLycamView = 'quiz';
  espLycamRefreshContainer();
}

/* ---------------- Écran quiz ---------------- */
function espLycamRenderQuiz(){
  const q = QUESTIONS[_espLycamCurrentQ];
  const pct = Math.round((_espLycamCurrentQ / QUESTIONS.length) * 100);
  const isLast = _espLycamCurrentQ === QUESTIONS.length - 1;
  return `
    <div class="esp-card">
      <div class="esp-lycam-ribbon"><div class="esp-lycam-ribbon-fill" style="width:${pct}%;"></div></div>
      <div style="display:flex; justify-content:space-between; margin:10px 0 18px;">
        <span class="esp-sub" style="margin:0;">Question ${_espLycamCurrentQ+1} sur ${QUESTIONS.length}</span>
        <span class="esp-lycam-dim-chip">${q.dim}</span>
      </div>
      <p class="esp-lycam-prompt">${escapeHtml(q.prompt)}</p>
      <div class="esp-lycam-options">
        ${q.opts.map(([letter, text]) => `
          <div class="esp-lycam-opt ${_espLycamAnswers[_espLycamCurrentQ] === letter ? 'selected' : ''}" onclick="espLycamSelectOption('${letter}')">
            <span class="esp-lycam-opt-letter">${letter}</span><span>${escapeHtml(text)}</span>
          </div>
        `).join('')}
      </div>
      <div id="esp-lycam-quiz-error"></div>
      <div style="display:flex; justify-content:space-between; margin-top:20px;">
        <button class="esp-btn" onclick="espLycamPrevQuestion()" ${_espLycamCurrentQ === 0 ? 'style="visibility:hidden;"' : ''}>← Précédent</button>
        <button class="esp-btn esp-btn-primary" onclick="espLycamNextQuestion()">${isLast ? 'Voir le résultat →' : 'Suivant →'}</button>
      </div>
    </div>
  `;
}

function espLycamSelectOption(letter){
  _espLycamAnswers[_espLycamCurrentQ] = letter;
  espLycamRefreshContainer();
}
function espLycamPrevQuestion(){
  if(_espLycamCurrentQ === 0) return;
  _espLycamCurrentQ--;
  espLycamRefreshContainer();
}
async function espLycamNextQuestion(){
  if(!_espLycamAnswers[_espLycamCurrentQ]){
    document.getElementById('esp-lycam-quiz-error').innerHTML = '<p class="esp-error">Choisis une réponse pour continuer.</p>';
    return;
  }
  if(_espLycamCurrentQ === QUESTIONS.length - 1){
    await espLycamComputeAndSave();
    return;
  }
  _espLycamCurrentQ++;
  espLycamRefreshContainer();
}

/* ---------------- Dépouillement + sauvegarde ---------------- */
function espLycamScore(){
  const scores = {}; Object.keys(DIMENSIONS).forEach(d => scores[d] = 0);
  QUESTIONS.forEach((q, idx) => {
    const given = _espLycamAnswers[idx];
    if(given && q.risk.includes(given)) scores[q.dim]++;
  });
  const total = Object.values(scores).reduce((a,b)=>a+b,0);
  let band = total >= 18 ? 'high' : (total >= 10 ? 'mid' : 'low');
  return { scores, total, band };
}
function espLycamBandInfo(band){
  if(band === 'high') return { label:'Risque élevé', desc:"Plusieurs signaux se cumulent. Un temps d'échange avec l'élève ou l'équipe éducative est recommandé rapidement." };
  if(band === 'mid') return { label:'Risque modéré', desc:"Quelques signaux méritent attention." };
  return { label:'Risque faible', desc:"Peu de signaux ressortent de ce questionnaire aujourd'hui." };
}

async function espLycamComputeAndSave(){
  const r = espLycamScore();
  const info = espLycamBandInfo(r.band);
  _espLycamLastResult = { identity: {..._espLycamIdentity}, ...r, bandLabel: info.label, bandDesc: info.desc };

  const session = espSession();
  let synced = true;
  try {
    const ok = await espLycamSaveResultRPC(session.id, session.password, _espLycamCurrentSession.id, _espLycamIdentity, r.total, r.band, r.scores);
    if(!ok) synced = false;
  } catch(e){ synced = false; }

  if(!synced){
    const pending = espLycamLoadPending();
    const tempId = Date.now().toString(36) + Math.random().toString(36).slice(2,6);
    pending.push({ tempId, sessionId: _espLycamCurrentSession.id, eleve: {..._espLycamIdentity}, scoreTotal:r.total, band:r.band, scores:r.scores });
    espLycamSavePending(pending);
  }
  _espLycamLastResult.synced = synced;

  _espLycamCurrentResults.push({
    id: synced ? 'srv-' + Date.now() : 'pending-local', sessionId: _espLycamCurrentSession.id,
    nom:_espLycamIdentity.nom, prenom:_espLycamIdentity.prenom, naissance:_espLycamIdentity.naissance, classe:_espLycamIdentity.classe,
    scoreTotal:r.total, band:r.band, scores:r.scores, pending: !synced,
  });

  _espLycamView = 'result';
  espLycamRefreshContainer();
}

/* ---------------- Écran résultat individuel ---------------- */
function espLycamDimRowsHtml(scores){
  return Object.keys(DIMENSIONS).map(code => {
    const meta = DIMENSIONS[code];
    const score = scores[code];
    const max = QUESTIONS.filter(q => q.dim === code).length;
    const flagged = score >= meta.seuil;
    return `
      <div class="esp-lycam-dim-row">
        <div class="esp-lycam-dim-name">${code}<small>${escapeHtml(meta.name)}</small></div>
        <div class="esp-lycam-dim-track"><div class="esp-lycam-dim-fill ${flagged?'flag':'ok'}" style="width:${Math.round((score/max)*100)}%;"></div></div>
        <div class="esp-lycam-dim-score">${score}/${max}${flagged ? ' <span style="color:var(--orange-dark);">●</span>' : ''}</div>
      </div>`;
  }).join('');
}

function espLycamRenderResult(){
  const r = _espLycamLastResult;
  const count = _espLycamCurrentResults.length;
  const remaining = 150 - count;
  return `
    <div class="esp-card">
      <div class="esp-title" style="font-size:16px;">${escapeHtml((r.identity.prenom + ' ' + r.identity.nom).trim())}</div>
      <p class="esp-sub">${[r.identity.classe, r.identity.naissance ? 'né(e) en ' + r.identity.naissance : ''].filter(Boolean).join(' · ')}</p>
      ${!r.synced ? `<p class="esp-sub" style="color:var(--orange-dark);">⚠️ Résultat enregistré localement, en attente de synchronisation (connexion instable).</p>` : ''}
      <div class="esp-lycam-hero esp-lycam-hero-${r.band}">
        <div class="esp-lycam-hero-num">${r.total}<small>/41</small></div>
        <div>
          <div class="esp-lycam-hero-title">${escapeHtml(r.bandLabel)}</div>
          <div class="esp-lycam-hero-desc">${escapeHtml(r.bandDesc)}</div>
        </div>
      </div>
      <div style="margin:20px 0;">${espLycamDimRowsHtml(r.scores)}</div>
      <p class="esp-sub">${count} élève(s) testé(s) dans cette session${remaining > 0 ? ' · ' + remaining + ' place(s) restante(s)' : ' · limite de 150 atteinte'}.</p>
      <div style="display:flex; gap:10px; flex-wrap:wrap; justify-content:flex-end;">
        <button class="esp-btn" onclick="espLycamDownloadIndividual()">⬇ Télécharger la fiche</button>
        <button class="esp-btn" onclick="espLycamShowReport()">📊 Rapport de session</button>
        ${count < 150 ? `<button class="esp-btn esp-btn-primary" onclick="espLycamGoToIdentity()">Élève suivant →</button>` : ''}
      </div>
    </div>
  `;
}

/* ---------------- Rapport de session ---------------- */
function espLycamShowReport(){
  _espLycamView = 'report';
  espLycamRefreshContainer();
}

function espLycamRenderReport(){
  const results = _espLycamCurrentResults;
  const bandCounts = { low:0, mid:0, high:0 };
  results.forEach(s => bandCounts[s.band]++);
  const pendingCount = results.filter(s => s.pending).length;

  const dimRows = Object.keys(DIMENSIONS).map(code => {
    const meta = DIMENSIONS[code];
    const flaggedCount = results.filter(s => s.scores[code] >= meta.seuil).length;
    const pct = results.length ? Math.round((flaggedCount/results.length)*100) : 0;
    return `
      <div class="esp-lycam-dim-row">
        <div class="esp-lycam-dim-name">${code}<small>${escapeHtml(meta.name)}</small></div>
        <div class="esp-lycam-dim-track"><div class="esp-lycam-dim-fill ${flaggedCount>0?'flag':'ok'}" style="width:${pct}%;"></div></div>
        <div class="esp-lycam-dim-score">${flaggedCount}/${results.length} <small>(${pct}%)</small></div>
      </div>`;
  }).join('');

  return `
    <div class="esp-card">
      <button class="esp-back" onclick="espLycamBackToList()">← Toutes les sessions</button>
      <div class="esp-title" style="font-size:16px;">📊 ${escapeHtml(_espLycamCurrentSession.nom)}</div>
      <p class="esp-sub">${results.length} élève(s) testé(s)${pendingCount ? ' · ' + pendingCount + ' en attente de synchronisation' : ''}.</p>
      <div class="esp-stat-grid">
        <div class="esp-stat-box"><div class="esp-stat-num">${results.length}</div><div class="esp-stat-label">Élèves testés</div></div>
        <div class="esp-stat-box"><div class="esp-stat-num" style="color:var(--green-dark);">${bandCounts.low}</div><div class="esp-stat-label">Risque faible</div></div>
        <div class="esp-stat-box"><div class="esp-stat-num" style="color:var(--orange-dark);">${bandCounts.mid}</div><div class="esp-stat-label">Risque modéré</div></div>
        <div class="esp-stat-box"><div class="esp-stat-num" style="color:#c0392b;">${bandCounts.high}</div><div class="esp-stat-label">Risque élevé</div></div>
      </div>
      <h3 style="font-size:14px; color:var(--green-dark); margin:20px 0 12px;">Élèves en seuil critique, par dimension</h3>
      ${results.length ? dimRows : `<p class="esp-empty">Aucun élève testé pour l'instant dans cette session.</p>`}
      <div style="display:flex; gap:10px; flex-wrap:wrap; justify-content:flex-end; margin-top:22px;">
        <button class="esp-btn" onclick="window.print()">🖨 Imprimer</button>
        <button class="esp-btn" onclick="espLycamDownloadCsv()">⬇ Données (CSV)</button>
        <button class="esp-btn" onclick="espLycamDownloadReport()">⬇ Rapport (HTML)</button>
        <button class="esp-btn esp-btn-primary" onclick="espLycamGoToIdentity()">+ Ajouter un élève</button>
      </div>
    </div>
  `;
}

async function espLycamManualRetrySync(){
  await espLycamRetrySync();
  espLycamInitTab();
}

/* ============================================================
   Téléchargements (fiche individuelle, rapport de session, CSV)
   ============================================================ */
function espLycamTriggerDownload(filename, content, mime){
  const blob = new Blob([content], { type: mime + ';charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = filename;
  document.body.appendChild(a); a.click(); document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
function espLycamSlugify(s){
  return (s||'sans-nom').toString().normalize('NFD').replace(/[\u0300-\u036f]/g,'')
    .replace(/[^a-zA-Z0-9]+/g,'-').replace(/^-+|-+$/g,'') || 'sans-nom';
}
function espLycamReportShell(title, bodyHtml){
  return `<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><title>${escapeHtml(title)}</title>
<style>
  body{font-family:'Segoe UI',Roboto,Arial,sans-serif; background:#fffaf3; color:#1f2b22; margin:0; padding:28px 16px;}
  .wrap{max-width:680px; margin:0 auto; background:#fff; border:1px solid #f0d9b5; border-radius:16px; padding:32px clamp(20px,5vw,40px);}
  h1{font-size:22px; margin:0 0 4px;} h2{font-size:16px; color:#157a40; margin:26px 0 10px;}
  p.sub{color:#6b7d70; font-size:13.5px; margin:0 0 22px;}
  table{width:100%; border-collapse:collapse; font-size:12.5px; margin-bottom:10px;}
  th,td{border:1px solid #f0d9b5; padding:8px 9px; text-align:left;}
  th{background:#fffaf3; font-size:11px; text-transform:uppercase; color:#6b7d70;}
  .badge{display:inline-block; font-weight:800; font-size:13px; padding:6px 14px; border-radius:99px; margin-bottom:16px;}
  .badge.low{background:#e9f7ee; color:#157a40;} .badge.mid{background:#fff1e2; color:#e8650a;} .badge.high{background:#fbe9e7; color:#c0392b;}
  .stat-grid{display:flex; gap:12px; flex-wrap:wrap; margin:18px 0 24px;}
  .stat-box{flex:1; min-width:110px; background:#fffaf3; border:1px solid #f0d9b5; border-radius:12px; padding:12px; text-align:center;}
  .stat-num{font-size:22px; font-weight:800; color:#e8650a;} .stat-label{font-size:11px; color:#6b7d70; margin-top:2px;}
  footer{text-align:center; font-size:11px; color:#8c99a6; margin-top:24px;}
</style></head><body><div class="wrap">${bodyHtml}
<footer>Généré depuis ORIMETIER — le ${new Date().toLocaleDateString('fr-FR')}</footer></div></body></html>`;
}
function espLycamDimTableRows(scores){
  return Object.keys(DIMENSIONS).map(code => {
    const meta = DIMENSIONS[code]; const score = scores[code];
    const max = QUESTIONS.filter(q => q.dim === code).length; const flagged = score >= meta.seuil;
    return `<tr><td>${code} — ${escapeHtml(meta.name)}</td><td style="text-align:center;">${score}/${max}</td><td style="text-align:center;">${meta.seuil}</td><td style="text-align:center;">${flagged?'Oui':'—'}</td></tr>`;
  }).join('');
}
function espLycamDownloadIndividual(){
  const r = _espLycamLastResult; if(!r) return;
  const body = `<h1>${escapeHtml((r.identity.prenom+' '+r.identity.nom).trim())}</h1>
    <p class="sub">${[r.identity.classe, r.identity.naissance?'né(e) en '+r.identity.naissance:''].filter(Boolean).map(escapeHtml).join(' · ')}</p>
    <span class="badge ${r.band}">${escapeHtml(r.bandLabel)} — ${r.total}/41</span>
    <p style="font-size:13.5px; color:#4a5568; line-height:1.6;">${escapeHtml(r.bandDesc)}</p>
    <h2>Détail par dimension</h2>
    <table><thead><tr><th>Dimension</th><th>Score</th><th>Seuil</th><th>Point de vigilance</th></tr></thead><tbody>${espLycamDimTableRows(r.scores)}</tbody></table>`;
  const html = espLycamReportShell('LYCAM — ' + (r.identity.prenom+' '+r.identity.nom).trim(), body);
  espLycamTriggerDownload(`LYCAM_${espLycamSlugify(r.identity.nom)}_${espLycamSlugify(r.identity.prenom)}.html`, html, 'text/html');
}
function espLycamDownloadReport(){
  const results = _espLycamCurrentResults;
  const bandCounts = { low:0, mid:0, high:0 }; results.forEach(s => bandCounts[s.band]++);
  const dimRows = Object.keys(DIMENSIONS).map(code => {
    const meta = DIMENSIONS[code];
    const flaggedCount = results.filter(s => s.scores[code] >= meta.seuil).length;
    const pct = results.length ? Math.round((flaggedCount/results.length)*100) : 0;
    return `<tr><td>${code} — ${escapeHtml(meta.name)}</td><td style="text-align:center;">${flaggedCount} / ${results.length}</td><td style="text-align:center;">${pct}%</td></tr>`;
  }).join('');
  const body = `<h1>Rapport de session — ${escapeHtml(_espLycamCurrentSession.nom)}</h1>
    <p class="sub">${results.length} élève(s) testé(s).</p>
    <div class="stat-grid">
      <div class="stat-box"><div class="stat-num">${results.length}</div><div class="stat-label">Élèves testés</div></div>
      <div class="stat-box"><div class="stat-num" style="color:#157a40;">${bandCounts.low}</div><div class="stat-label">Risque faible</div></div>
      <div class="stat-box"><div class="stat-num" style="color:#e8650a;">${bandCounts.mid}</div><div class="stat-label">Risque modéré</div></div>
      <div class="stat-box"><div class="stat-num" style="color:#c0392b;">${bandCounts.high}</div><div class="stat-label">Risque élevé</div></div>
    </div>
    <h2>Élèves en seuil critique, par dimension</h2>
    <table><thead><tr><th>Dimension</th><th>Élèves concernés</th><th>%</th></tr></thead><tbody>${dimRows}</tbody></table>`;
  const html = espLycamReportShell('LYCAM — ' + _espLycamCurrentSession.nom, body);
  espLycamTriggerDownload(`LYCAM_rapport_${espLycamSlugify(_espLycamCurrentSession.nom)}.html`, html, 'text/html');
}
function espLycamDownloadCsv(){
  const results = _espLycamCurrentResults;
  const dimCodes = Object.keys(DIMENSIONS);
  const bandLabelFr = { low:'Faible', mid:'Modere', high:'Eleve' };
  function esc(v){ v = (v===undefined||v===null)?'':String(v); return /[",;\n]/.test(v) ? '"'+v.replace(/"/g,'""')+'"' : v; }
  const header = ['Nom','Prenom','Annee naissance','Classe','Score total','Niveau de risque', ...dimCodes.map(c=>c+'_score'), ...dimCodes.map(c=>c+'_seuil_atteint')];
  const rows = results.map(s => {
    const base = [s.nom, s.prenom, s.naissance, s.classe, s.scoreTotal, bandLabelFr[s.band]];
    const scoreVals = dimCodes.map(c => s.scores[c]);
    const flagVals = dimCodes.map(c => s.scores[c] >= DIMENSIONS[c].seuil ? 'Oui' : 'Non');
    return [...base, ...scoreVals, ...flagVals].map(esc).join(';');
  });
  const csv = '\uFEFF' + header.map(esc).join(';') + '\n' + rows.join('\n');
  espLycamTriggerDownload(`LYCAM_donnees_${espLycamSlugify(_espLycamCurrentSession.nom)}.csv`, csv, 'text/csv');
}
