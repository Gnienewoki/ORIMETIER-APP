// ============================================================
// ---- Authentification, portail d'accès et session ----
// ============================================================
const ESP_SESSION_KEY = 'GNK_ESPACES_SESSION'; // reste local : juste "qui est connecté sur CET appareil"

function espSession(){
  try { return JSON.parse(localStorage.getItem(ESP_SESSION_KEY) || 'null'); } catch(e){ return null; }
}
function espSetSession(role, id, password){
  try { localStorage.setItem(ESP_SESSION_KEY, JSON.stringify({role, id, password: password || null})); } catch(e){}
}
function espClearSession(){
  try { localStorage.removeItem(ESP_SESSION_KEY); } catch(e){}
}

function espStorageAvailable(){
  try {
    const testKey = '__esp_storage_test__';
    localStorage.setItem(testKey, '1');
    const readBack = localStorage.getItem(testKey);
    localStorage.removeItem(testKey);
    return readBack === '1';
  } catch(e){
    return false;
  }
}

function espCheckStoragePersistence(){
  const warningEl = document.getElementById('gate-storage-warning');
  if(!warningEl) return;
  if(!espStorageAvailable()){
    warningEl.style.display = '';
    warningEl.innerHTML = `<b>⚠️ Stockage local indisponible sur cet appareil/navigateur</b>
      Tes comptes et données restent en sécurité sur le serveur (Supabase), mais ta connexion ne sera pas mémorisée sur cet appareil : il faudra te reconnecter à chaque visite. Cela arrive souvent en navigation privée ou selon les réglages de confidentialité du navigateur.
      Essaie d'ouvrir ce fichier avec <b>Google Chrome</b>, en dehors de la navigation privée, pour rester connecté(e) automatiquement.`;
    return;
  }
  // Marqueur persistant : si présent après un rechargement, le stockage survit bien aux fermetures/réouvertures.
  const marker = localStorage.getItem('__esp_first_visit_marker__');
  if(!marker){
    try { localStorage.setItem('__esp_first_visit_marker__', new Date().toISOString()); } catch(e){}
  }
}

function espHideAll(){
  ['esp-role-select','esp-admin','esp-inspecteur','esp-eleve','esp-etablissement'].forEach(id => {
    const el = document.getElementById(id);
    if(el) el.style.display = 'none';
  });
}

// ---------------- Pages en libre accès (aucun compte requis) ----------------
// Annuaire des métiers, enseignement supérieur, concours & grandes écoles, test RIASEC :
// consultables par n'importe quel visiteur. Tout le reste (espaces.html, eleves.html)
// continue d'exiger une connexion, comme avant.
const ESP_PUBLIC_PAGES = ['index.html', 'superieur.html', 'concours.html', 'test.html', ''];
function espCurrentPageIsPublic(){
  const path = window.location.pathname;
  const file = path.substring(path.lastIndexOf('/') + 1);
  return ESP_PUBLIC_PAGES.includes(file);
}

// ---------------- Verrou d'accès à la plateforme (inscription/connexion obligatoire) ----------------
function espAccountStillExists(session){
  if(!session) return false;
  if(session.role === 'admin') return true;
  const db = espDB();
  // Un compte banni est traité comme inexistant : il repasse par le portail au prochain chargement.
  if(session.role === 'inspecteur'){ const i = db.inspecteurs.find(x => x.id === session.id); return !!i && !i.banni; }
  if(session.role === 'eleve'){ const e = db.eleves.find(x => x.id === session.id); return !!e && !e.banni; }
  if(session.role === 'etablissement') return db.etablissements.some(e => e.id === session.id);
  return false;
}

// ---------------- Libellé lisible de la classification établissement (catégorie / sous-catégorie / secteur) ----------------
// Utilisé par l'espace admin et, plus tard, par les pages publiques de consultation par catégorie.
// Renvoie "—" pour les établissements inscrits avant l'ajout de cette classification.
const ESP_ETAB_CATEGORIE_LABELS = { technique: "Enseignement technique et formation professionnelle", superieur: "Enseignement supérieur", general: "Enseignement général" };
const ESP_ETAB_SOUS_CATEGORIE_LABELS = { universite: "Université", grande_ecole: "Grande école", secondaire: "Secondaire" };
const ESP_ETAB_SECTEUR_LABELS = { public: "Public", prive: "Privé" };
function espEtabCategorieLabel(etab){
  if(!etab || !etab.categorie) return '—';
  const parts = [ESP_ETAB_CATEGORIE_LABELS[etab.categorie] || etab.categorie];
  if(etab.sousCategorie) parts.push(ESP_ETAB_SOUS_CATEGORIE_LABELS[etab.sousCategorie] || etab.sousCategorie);
  if(etab.secteur) parts.push(ESP_ETAB_SECTEUR_LABELS[etab.secteur] || etab.secteur);
  return escapeHtml(parts.join(' · '));
}

function espCurrentUserLabel(session){
  const db = espDB();
  if(session.role === 'admin') return { nom:'Administrateur', role:'Administrateur' };
  if(session.role === 'inspecteur'){ const i = db.inspecteurs.find(x=>x.id===session.id); return { nom: i ? (i.nom+' '+(i.prenoms||'')).trim() : '', role:"Inspecteur d'orientation" }; }
  if(session.role === 'eleve'){ const e = db.eleves.find(x=>x.id===session.id); return { nom: e ? (e.nom+' '+(e.prenoms||'')).trim() : '', role:'Élève' }; }
  if(session.role === 'etablissement'){ const e = db.etablissements.find(x=>x.id===session.id); return { nom: e ? e.nom : '', role:'Établissement' }; }
  return { nom:'', role:'' };
}

function updateAuthBar(){
  const bar = document.getElementById('auth-bar');
  const session = espSession();
  const tabEleves = document.getElementById('tab-eleves');
  if(tabEleves) tabEleves.style.display = (session && session.role === 'inspecteur') ? '' : 'none';
  if(!bar) return;
  if(!session){
    bar.innerHTML = `
      <div class="esp-guest-bar">
        <div class="esp-guest-dropdown">
          <button class="esp-btn esp-btn-primary" onclick="espToggleGuestMenu(event)">➕ Ouvrir un compte</button>
          <div class="esp-guest-menu" id="esp-guest-menu">
            <a href="espaces.html?role=inspecteur&amp;action=register">🧭 Inspecteur d'orientation</a>
            <a href="espaces.html?role=eleve&amp;action=register">🎓 Élève / Étudiant</a>
            <a href="espaces.html?role=etablissement&amp;action=register">🏫 Établissement</a>
          </div>
        </div>
        <a href="espaces.html" class="esp-btn">🔐 Déjà inscrit ? Se connecter</a>
      </div>
    `;
    return;
  }
  const u = espCurrentUserLabel(session);
  bar.innerHTML = `
    <span>Connecté(e) : <span class="auth-bar-name">${escapeHtml(u.nom || u.role)}</span> · ${escapeHtml(u.role)}</span>
    <button class="auth-bar-logout" onclick="platformLogout()">Déconnexion</button>
  `;
}

function espToggleGuestMenu(e){
  if(e) e.stopPropagation();
  const menu = document.getElementById('esp-guest-menu');
  if(!menu) return;
  const isOpen = menu.classList.contains('open');
  menu.classList.toggle('open', !isOpen);
}
document.addEventListener('click', (e) => {
  const menu = document.getElementById('esp-guest-menu');
  if(menu && menu.classList.contains('open') && !menu.contains(e.target) && e.target.id !== 'esp-guest-menu'){
    menu.classList.remove('open');
  }
});

// ---------------- Portail (déverrouillage / verrouillage de la page courante) ----------------
// window.onBeforeUnlock / window.onBeforeLock : points d'extension optionnels utilisés
// uniquement par espaces.html (voir espaces.js), qui doit déplacer les conteneurs de
// rôle (#esp-admin, #esp-inspecteur, ...) entre le portail et le contenu de la page.
function platformUnlock(){
  const gate = document.getElementById('auth-gate');
  const wrap = document.getElementById('platform-wrap');
  if(typeof window.onBeforeUnlock === 'function') window.onBeforeUnlock();
  gate.style.display = 'none';
  wrap.style.display = '';
  updateAuthBar();
  const session = espSession();
  if(session && session.role === 'inspecteur'){
    // Charge les messages privés de l'inspecteur avant d'initialiser la page,
    // pour que le compteur de messages non-lus soit correct dès l'affichage.
    espLoadPrivateMessages().catch(e => console.error('[esp] échec du chargement des messages privés', e)).finally(() => {
      if(typeof window.pageInit === 'function') window.pageInit();
    });
  } else {
    if(typeof window.pageInit === 'function') window.pageInit();
  }
}

// ---------------- Déverrouillage "visiteur" (pages en libre accès, sans compte) ----------------
// Même comportement que platformUnlock(), mais sans session : pas de chargement des
// messages privés (réservés aux inspecteurs connectés). Les fonctionnalités qui exigent
// un compte (ex : sauvegarder son profil RIASEC) continuent de demander une connexion
// au moment où le visiteur clique dessus, comme c'est déjà le cas ailleurs dans l'app.
function platformUnlockGuest(){
  const gate = document.getElementById('auth-gate');
  const wrap = document.getElementById('platform-wrap');
  if(typeof window.onBeforeUnlock === 'function') window.onBeforeUnlock();
  gate.style.display = 'none';
  wrap.style.display = '';
  updateAuthBar();
  if(typeof window.pageInit === 'function') window.pageInit();
}

function platformLock(){
  const gate = document.getElementById('auth-gate');
  const wrap = document.getElementById('platform-wrap');
  wrap.style.display = 'none';
  gate.style.display = 'flex';
  const bar = document.getElementById('auth-bar');
  if(bar) bar.innerHTML = '';
  if(typeof window.onBeforeLock === 'function') window.onBeforeLock();
  espShowRoleSelect();
  // Lien direct vers un rôle précis (ex : espaces.html?role=eleve&action=register depuis les boutons "Ouvrir un compte").
  const role = new URLSearchParams(window.location.search).get('role');
  const action = new URLSearchParams(window.location.search).get('action');
  if(role && ['admin','inspecteur','eleve','etablissement'].includes(role)) espSelectRole(role, action);
}

function platformLogout(){
  espClearSession();
  platformLock();
}

function platformInit(){
  espCheckStoragePersistence();
  const session = espSession();
  if(session && espAccountStillExists(session)){
    platformUnlock(); // accès libre, sans code d'activation (à réactiver plus tard si besoin)
  } else if(espCurrentPageIsPublic()){
    espClearSession();
    platformUnlockGuest();
  } else {
    espClearSession();
    platformLock();
  }
}

// ---------------- Sélection de rôle (portail, sur toutes les pages) ----------------
function espShowRoleSelect(){
  espHideAll();
  const el = document.getElementById('esp-role-select');
  el.style.display = '';
  el.innerHTML = `
    <div class="esp-role-grid">
      <div class="esp-role-card" onclick="espSelectRole('admin')">
        <div class="esp-role-icon">🛠️</div>
        <div class="esp-role-title">Administrateur</div>
        <div class="esp-role-desc">Mise à jour des données et validation des inscriptions établissement</div>
      </div>
      <div class="esp-role-card" onclick="espSelectRole('inspecteur')">
        <div class="esp-role-icon">🧭</div>
        <div class="esp-role-title">Inspecteur d'orientation</div>
        <div class="esp-role-desc">Suivi des élèves et de leurs profils d'orientation</div>
      </div>
      <div class="esp-role-card" onclick="espSelectRole('eleve')">
        <div class="esp-role-icon">🎓</div>
        <div class="esp-role-title">Élève / Étudiant</div>
        <div class="esp-role-desc">Mon compte, mon test d'orientation, mes recommandations</div>
      </div>
      <div class="esp-role-card" onclick="espSelectRole('etablissement')">
        <div class="esp-role-icon">🏫</div>
        <div class="esp-role-title">Établissement</div>
        <div class="esp-role-desc">Inscription de l'établissement et propositions de filières</div>
      </div>
    </div>
  `;
}

function espSelectRole(role, mode){
  mode = mode === 'register' ? 'register' : 'login';
  espHideAll();
  document.getElementById('esp-' + role).style.display = '';
  if(role === 'admin') espRenderAdminLogin();
  if(role === 'inspecteur') espRenderInspecteurAuth(mode);
  if(role === 'eleve') espRenderEleveAuth(mode);
  if(role === 'etablissement') espRenderEtabAuth(mode);
}

function espBackToRoleSelect(){ espShowRoleSelect(); }

// ---------------- Bulle de message de discussion (réutilisée par Inspecteur et Admin) ----------------
function espChatMessageHtml(m, opts){
  opts = opts || {};
  const auteurInsp = opts.inspecteursCache ? opts.inspecteursCache.find(i => i.id === m.inspecteurId) : null;
  const certifie = m.auteurRole === 'admin' ? false : (auteurInsp && auteurInsp.certifie);
  const isAdminMsg = m.auteurRole === 'admin';
  const typeLabel = m.type === 'A' ? '📌 Important' : (m.type === 'O' ? '📣 Officiel' : '');
  const typeClass = m.type === 'A' ? 'esp-chat-type-a' : (m.type === 'O' ? 'esp-chat-type-o' : '');
  const cited = m.replyTo && opts.allMessages ? opts.allMessages.find(x => x.id === m.replyTo) : null;
  const citedHtml = cited ? `
    <div class="esp-chat-cited">
      ↩️ <b>${escapeHtml(cited.inspecteurNom)}</b> : ${escapeHtml(cited.texte.length > 80 ? cited.texte.slice(0,80) + '…' : cited.texte)}
    </div>
  ` : (m.replyTo ? `<div class="esp-chat-cited esp-chat-cited-deleted">↩️ Message d'origine supprimé</div>` : '');
  const avatarHtml = isAdminMsg ? '🛠️ ' : (auteurInsp && auteurInsp.avatarUrl
    ? `<img src="${escapeHtml(auteurInsp.avatarUrl)}" class="esp-chat-avatar">`
    : `<span class="esp-chat-avatar-placeholder">${escapeHtml((m.inspecteurNom||'?').charAt(0).toUpperCase())}</span>`);
  const attachmentHtml = !m.attachmentUrl ? '' : m.attachmentType === 'pdf'
    ? `<div class="esp-chat-attachment"><a class="esp-chat-attachment-pdf" href="${escapeHtml(m.attachmentUrl)}" target="_blank" rel="noopener">📄 ${escapeHtml(m.attachmentName || 'Document PDF')}</a></div>`
    : `<div class="esp-chat-attachment"><img src="${escapeHtml(m.attachmentUrl)}" onclick="window.open('${escapeHtml(m.attachmentUrl)}','_blank')" alt="Pièce jointe"></div>`;
  return `
    <div class="esp-chat-msg ${opts.mine ? 'esp-chat-msg-mine' : ''} ${isAdminMsg ? 'esp-chat-msg-admin' : ''} ${typeClass}">
      <div class="esp-chat-msg-author">
        ${avatarHtml}
        ${escapeHtml(m.inspecteurNom)}${certifie ? ' <span class="esp-badge-certifie" title="Compte certifié par l\'administration">✅</span>' : ''}
        ${typeLabel ? `<span class="esp-chat-type-label">${typeLabel}</span>` : ''}
        <span class="esp-chat-msg-date">${escapeHtml(m.date)}</span>
        ${opts.canDelete ? `<span class="esp-chat-delete" onclick="${opts.deleteHandler}('${m.id}')" title="Supprimer ce message">🗑️</span>` : ''}
      </div>
      ${citedHtml}
      ${m.texte ? `<div class="esp-chat-msg-text">${escapeHtml(m.texte)}</div>` : ''}
      ${attachmentHtml}
      ${opts.replyHandler ? `<div class="esp-chat-reply-link" onclick="${opts.replyHandler}('${m.id}')">↩️ Répondre</div>` : ''}
    </div>
  `;
}

// ---------------- Pièce jointe du chat (photo ou PDF, réutilisée par Inspecteur, Admin et messagerie privée) ----------------
let _espChatPendingFile = null;
function espChatPreviewAttachment(input){
  const file = input.files && input.files[0];
  const previewEl = document.getElementById(input.id.replace('-input','-preview'));
  _espChatPendingFile = file || null;
  if(!previewEl) return;
  if(!file){ previewEl.innerHTML = ''; return; }
  const isPdf = file.type === 'application/pdf';
  const isImage = file.type.startsWith('image/');
  if(!isPdf && !isImage){
    previewEl.innerHTML = '<p class="esp-error">Seules les images et les PDF sont acceptés.</p>';
    _espChatPendingFile = null;
    input.value = '';
    return;
  }
  previewEl.innerHTML = `<p class="esp-sub" style="margin:4px 0;">📎 ${escapeHtml(file.name)} <span class="esp-toggle-link" onclick="espChatClearAttachment('${input.id}')">Retirer</span></p>`;
}
function espChatClearAttachment(inputId){
  _espChatPendingFile = null;
  const input = document.getElementById(inputId);
  if(input) input.value = '';
  const previewEl = document.getElementById(inputId.replace('-input','-preview'));
  if(previewEl) previewEl.innerHTML = '';
}
async function espChatUploadPendingAttachment(){
  if(!_espChatPendingFile) return null;
  const file = _espChatPendingFile;
  const url = await espUploadChatFile(file);
  const type = file.type === 'application/pdf' ? 'pdf' : 'image';
  _espChatPendingFile = null;
  return { url, type, name: file.name };
}

// ---------------- Répondre à un message précis (état partagé entre Inspecteur et Admin) ----------------
let _espReplyTarget = null;
function espSetReplyTarget(messageId){
  const db = espDB();
  const m = (db.messages || []).find(x => x.id === messageId);
  if(!m) return;
  _espReplyTarget = { id: m.id, nom: m.inspecteurNom, texte: m.texte };
  espUpdateReplyPreview();
}
function espCancelReply(){
  _espReplyTarget = null;
  espUpdateReplyPreview();
}
function espUpdateReplyPreview(){
  const el = document.getElementById('esp-chat-reply-preview');
  if(!el) return;
  if(!_espReplyTarget){ el.innerHTML = ''; return; }
  const snippet = _espReplyTarget.texte.length > 60 ? _espReplyTarget.texte.slice(0,60) + '…' : _espReplyTarget.texte;
  el.innerHTML = `
    <div class="esp-chat-reply-preview">
      ↩️ Réponse à <b>${escapeHtml(_espReplyTarget.nom)}</b> : ${escapeHtml(snippet)}
      <span class="esp-chat-cancel-reply" onclick="espCancelReply()" title="Annuler">✕</span>
    </div>
  `;
}

// ============================================================
// ---- Messagerie privée entre inspecteurs (façon WhatsApp) ----
// ============================================================
let _espPrivateActiveContact = null; // id de l'inspecteur avec qui la conversation est ouverte
let _espPrivateSearchQuery = '';

// Nombre total de messages privés non lus, pour le badge sur l'onglet.
function espPrivateUnreadTotal(){
  const session = espSession();
  if(!session) return 0;
  return espPrivateMessages().filter(m => m.destinataireId === session.id && !m.lu).length;
}

// Regroupe tous les messages privés par contact, pour la liste de conversations.
function espPrivateConversationsList(){
  const session = espSession();
  const db = espDB();
  const all = espPrivateMessages(); // déjà trié par date croissante (created_at) via la RPC
  const byContact = {};
  all.forEach((m, idx) => {
    const contactId = m.expediteurId === session.id ? m.destinataireId : m.expediteurId;
    if(!byContact[contactId]) byContact[contactId] = { contactId, messages: [], lastIndex: 0 };
    byContact[contactId].messages.push(m);
    byContact[contactId].lastIndex = idx; // position dans l'ordre chronologique global
  });
  return Object.values(byContact).map(c => {
    const insp = db.inspecteurs.find(i => i.id === c.contactId);
    const last = c.messages[c.messages.length - 1];
    const unread = c.messages.filter(m => m.destinataireId === session.id && !m.lu).length;
    return { contact: insp, contactId: c.contactId, lastMessage: last, unread, lastIndex: c.lastIndex };
  }).filter(c => c.contact).sort((a,b) => b.lastIndex - a.lastIndex);
}

// Bulle de message privé (plus simple que celle du chat de groupe : pas de nom répété,
// pas de badge de certification puisqu'on sait déjà avec qui on parle).
function espPrivateMessageHtml(m, opts){
  opts = opts || {};
  const attachmentHtml = !m.attachmentUrl ? '' : m.attachmentType === 'pdf'
    ? `<div class="esp-chat-attachment"><a class="esp-chat-attachment-pdf" href="${escapeHtml(m.attachmentUrl)}" target="_blank" rel="noopener">📄 ${escapeHtml(m.attachmentName || 'Document PDF')}</a></div>`
    : `<div class="esp-chat-attachment"><img src="${escapeHtml(m.attachmentUrl)}" onclick="window.open('${escapeHtml(m.attachmentUrl)}','_blank')" alt="Pièce jointe"></div>`;
  return `
    <div class="esp-chat-msg ${opts.mine ? 'esp-chat-msg-mine' : ''}">
      ${m.texte ? `<div class="esp-chat-msg-text">${escapeHtml(m.texte)}</div>` : ''}
      ${attachmentHtml}
      <div class="esp-chat-msg-date" style="margin-top:4px;">${escapeHtml(m.date)}</div>
    </div>
  `;
}

// ---------------- Pièce jointe de la messagerie privée (état séparé du chat de groupe, ----------------
// pour éviter qu'un fichier sélectionné dans un onglet ne s'attache par erreur à l'autre)
let _espPrivPendingFile = null;
function espPrivPreviewAttachment(input){
  const file = input.files && input.files[0];
  const previewEl = document.getElementById(input.id.replace('-input','-preview'));
  _espPrivPendingFile = file || null;
  if(!previewEl) return;
  if(!file){ previewEl.innerHTML = ''; return; }
  const isPdf = file.type === 'application/pdf';
  const isImage = file.type.startsWith('image/');
  if(!isPdf && !isImage){
    previewEl.innerHTML = '<p class="esp-error">Seules les images et les PDF sont acceptés.</p>';
    _espPrivPendingFile = null;
    input.value = '';
    return;
  }
  previewEl.innerHTML = `<p class="esp-sub" style="margin:4px 0;">📎 ${escapeHtml(file.name)} <span class="esp-toggle-link" onclick="espPrivClearAttachment('${input.id}')">Retirer</span></p>`;
}
function espPrivClearAttachment(inputId){
  _espPrivPendingFile = null;
  const input = document.getElementById(inputId);
  if(input) input.value = '';
  const previewEl = document.getElementById(inputId.replace('-input','-preview'));
  if(previewEl) previewEl.innerHTML = '';
}
async function espPrivUploadPendingAttachment(){
  if(!_espPrivPendingFile) return null;
  const file = _espPrivPendingFile;
  const url = await espUploadChatFile(file);
  const type = file.type === 'application/pdf' ? 'pdf' : 'image';
  _espPrivPendingFile = null;
  return { url, type, name: file.name };
}

// Rendu principal de l'onglet "Messages privés" : recherche + liste de conversations,
// ou fenêtre de discussion si une conversation est ouverte.
function espRenderPrivateTab(){
  const session = espSession();
  const db = espDB();

  if(_espPrivateActiveContact){
    const contact = db.inspecteurs.find(i => i.id === _espPrivateActiveContact);
    if(!contact){ _espPrivateActiveContact = null; return espRenderPrivateTab(); }
    const messages = espPrivateMessages().filter(m => m.expediteurId === _espPrivateActiveContact || m.destinataireId === _espPrivateActiveContact);
    return `
      <div class="esp-card">
        <button class="esp-back" onclick="espCloseConversationPrivee()">← Toutes les conversations</button>
        <div class="esp-title" style="font-size:16px;">💬 ${escapeHtml(contact.nom)} ${escapeHtml(contact.prenoms||'')}</div>
        <p class="esp-sub">${escapeHtml(contact.fonction||'Inspecteur')} — ${escapeHtml(contact.cio||'')}</p>
        <div id="esp-priv-list" class="esp-chat-list">
          ${messages.length ? messages.map(m => espPrivateMessageHtml(m, { mine: m.expediteurId === session.id })).join('') : `<p class="esp-empty">Aucun message. Écris le premier !</p>`}
        </div>
        <div id="esp-priv-error"></div>
        <div class="esp-field-row" style="margin-top:10px;align-items:flex-end;">
          <div class="esp-field" style="flex:1;">
            <label>Message</label>
            <input type="text" id="esp-priv-input" placeholder="Écrire un message..." onkeydown="if(event.key==='Enter')espSendPrivateMessage()">
          </div>
        </div>
        <div style="margin:6px 0 10px;">
          <label style="font-size:12px;font-weight:700;color:var(--green-dark);">📎 Joindre une photo ou un PDF</label><br>
          <input type="file" id="esp-priv-file-input" accept="image/*,application/pdf" onchange="espPrivPreviewAttachment(this)">
          <div id="esp-priv-file-preview"></div>
        </div>
        <button class="esp-btn esp-btn-primary" id="esp-priv-send-btn" onclick="espSendPrivateMessage()">Envoyer</button>
      </div>
    `;
  }

  const query = _espPrivateSearchQuery;
  const results = query ? db.inspecteurs.filter(i => i.id !== session.id && !i.banni && normalize(i.nom + ' ' + (i.prenoms||'')).includes(normalize(query))) : [];
  const conversations = espPrivateConversationsList();

  return `
    <div class="esp-card">
      <div class="esp-title" style="font-size:16px;">✉️ Messages privés</div>
      <p class="esp-sub">Recherche un inspecteur pour lui écrire directement, comme sur WhatsApp.</p>
      <div class="esp-field" style="margin-bottom:10px;">
        <input type="text" id="esp-priv-search" placeholder="🔎 Rechercher un inspecteur par son nom..." value="${escapeHtml(query)}" oninput="espPrivateSearchInput(this.value)">
      </div>
      ${query ? `
        <div class="esp-priv-search-results">
          ${results.length ? results.map(i => `
            <div class="esp-priv-conv-item" onclick="espOpenConversationPrivee('${i.id}')">
              ${i.avatarUrl ? `<img src="${escapeHtml(i.avatarUrl)}" class="esp-chat-avatar" style="width:34px;height:34px;">` : `<span class="esp-chat-avatar-placeholder" style="width:34px;height:34px;font-size:14px;">${escapeHtml((i.nom||'?').charAt(0).toUpperCase())}</span>`}
              <div class="esp-priv-conv-info">
                <div class="esp-priv-conv-name">${escapeHtml(i.nom)} ${escapeHtml(i.prenoms||'')}${i.certifie ? ' <span class="esp-badge-certifie">✅</span>' : ''}</div>
                <div class="esp-priv-conv-preview">${escapeHtml(i.fonction||'Inspecteur')} — ${escapeHtml(i.cio||'')}</div>
              </div>
            </div>
          `).join('') : `<p class="esp-empty">Aucun inspecteur trouvé pour « ${escapeHtml(query)} ».</p>`}
        </div>
      ` : `
        <div class="esp-priv-conv-list">
          ${conversations.length ? conversations.map(c => `
            <div class="esp-priv-conv-item" onclick="espOpenConversationPrivee('${c.contactId}')">
              ${c.contact.avatarUrl ? `<img src="${escapeHtml(c.contact.avatarUrl)}" class="esp-chat-avatar" style="width:34px;height:34px;">` : `<span class="esp-chat-avatar-placeholder" style="width:34px;height:34px;font-size:14px;">${escapeHtml((c.contact.nom||'?').charAt(0).toUpperCase())}</span>`}
              <div class="esp-priv-conv-info">
                <div class="esp-priv-conv-name">${escapeHtml(c.contact.nom)} ${escapeHtml(c.contact.prenoms||'')}</div>
                <div class="esp-priv-conv-preview">${escapeHtml((c.lastMessage.texte||'📎 Pièce jointe').slice(0,40))}</div>
              </div>
              ${c.unread ? `<span class="esp-priv-conv-unread">${c.unread}</span>` : ''}
            </div>
          `).join('') : `<p class="esp-empty">Aucune conversation pour le moment. Utilise la recherche ci-dessus pour écrire à un inspecteur.</p>`}
        </div>
      `}
    </div>
  `;
}

function espPrivateSearchInput(value){
  _espPrivateSearchQuery = value;
  const container = document.getElementById('esp-priv-tab-container');
  if(container) container.innerHTML = espRenderPrivateTab();
  // Remet le focus dans le champ après le rafraîchissement du HTML.
  const input = document.getElementById('esp-priv-search');
  if(input){ input.focus(); const v = input.value; input.value = ''; input.value = v; }
}

async function espOpenConversationPrivee(contactId){
  _espPrivateActiveContact = contactId;
  _espPrivateSearchQuery = '';
  const session = espSession();
  try { await espMarkPrivateReadRPC(session.id, session.password, contactId); await espLoadPrivateMessages(); } catch(e){}
  espRenderInspecteurDashboard('prive');
}

function espCloseConversationPrivee(){
  _espPrivateActiveContact = null;
  espRenderInspecteurDashboard('prive');
}

async function espSendPrivateMessage(){
  const session = espSession();
  const input = document.getElementById('esp-priv-input');
  const texte = input.value.trim();
  const errEl = document.getElementById('esp-priv-error');
  const sendBtn = document.getElementById('esp-priv-send-btn');
  if(!texte && !_espPrivPendingFile) return;
  if(sendBtn){ sendBtn.disabled = true; sendBtn.textContent = 'Envoi en cours...'; }
  try {
    const attachment = await espPrivUploadPendingAttachment();
    const ok = await espPostPrivateMessageRPC(session.id, session.password, _espPrivateActiveContact, texte, attachment);
    if(!ok){ errEl.innerHTML = '<p class="esp-error">Impossible d\'envoyer le message (session expirée). Merci de te reconnecter.</p>'; return; }
  } catch(e){
    errEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(e.message) + '</p>';
    return;
  } finally {
    if(sendBtn){ sendBtn.disabled = false; sendBtn.textContent = 'Envoyer'; }
  }
  input.value = '';
  espPrivClearAttachment('esp-priv-file-input');
  await espLoadPrivateMessages();
  espRenderInspecteurDashboard('prive');
}

// ---------------- Renseigner/modifier son e-mail (comptes créés avant l'ajout de cette fonctionnalité) ----------------
function espShowEmailForm(role){
  const formId = role === 'eleve' ? 'esp-eleve-email-form' : 'esp-insp-email-form';
  const container = document.getElementById(formId);
  container.innerHTML = `
    <div class="esp-field-row" style="margin-top:8px;">
      <div class="esp-field"><input type="email" id="esp-email-input-${role}" placeholder="ton-email@exemple.com"></div>
    </div>
    <div id="esp-email-msg-${role}"></div>
    <button class="esp-btn esp-btn-primary" onclick="espSubmitEmailForm('${role}')">Enregistrer</button>
  `;
}
async function espSubmitEmailForm(role){
  const session = espSession();
  const email = document.getElementById('esp-email-input-' + role).value.trim();
  const msgEl = document.getElementById('esp-email-msg-' + role);
  if(!email){ msgEl.innerHTML = '<p class="esp-error">Merci de saisir un e-mail.</p>'; return; }
  try {
    let ok;
    if(role === 'eleve') ok = await espUpdateEleveEmailRPC(session.id, session.password, email);
    else if(role === 'inspecteur') ok = await espUpdateInspecteurEmailRPC(session.id, session.password, email);
    if(!ok){ msgEl.innerHTML = '<p class="esp-error">Session expirée, merci de te reconnecter.</p>'; return; }
    const db = espDB();
    if(role === 'eleve'){
      const e = db.eleves.find(x => x.id === session.id);
      if(e) e.email = email;
      espSaveDB(db);
      espRenderEleveDashboard();
    } else {
      const i = db.inspecteurs.find(x => x.id === session.id);
      if(i) i.email = email;
      espSaveDB(db);
      espRenderInspecteurDashboard();
    }
  } catch(e){
    msgEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(e.message) + '</p>';
  }
}

// ---------------- Mot de passe oublié ----------------
// Affiche un petit formulaire "mot de passe oublié" à l'intérieur du conteneur d'un espace
// (ex : 'esp-eleve', 'esp-inspecteur', 'esp-etablissement').
function espRenderForgotPassword(role, containerId, backToLoginFn){
  const container = document.getElementById(containerId);
  container.innerHTML = `
    <button class="esp-back" onclick="(${backToLoginFn})()">← Retour à la connexion</button>
    <div class="esp-card" style="max-width:520px;margin:0 auto;">
      <div class="esp-title">🔑 Mot de passe oublié</div>
      <p class="esp-sub">Saisis l'adresse e-mail associée à ton compte. Si elle correspond à un compte existant, tu recevras un lien pour définir un nouveau mot de passe.</p>
      <div id="esp-forgot-msg"></div>
      <div class="esp-field" style="margin-bottom:14px;">
        <label>E-mail</label>
        <input type="email" id="esp-forgot-email" placeholder="ton-email@exemple.com">
      </div>
      <button class="esp-btn esp-btn-primary" id="esp-forgot-submit-btn" onclick="espSubmitForgotPassword('${role}')">Envoyer le lien de réinitialisation</button>
    </div>
  `;
}
async function espSubmitForgotPassword(role){
  const email = document.getElementById('esp-forgot-email').value.trim();
  const msgEl = document.getElementById('esp-forgot-msg');
  const btn = document.getElementById('esp-forgot-submit-btn');
  if(!email){ msgEl.innerHTML = '<p class="esp-error">Merci de saisir un e-mail.</p>'; return; }
  btn.disabled = true; btn.textContent = 'Envoi en cours...';
  try {
    const result = await espRequestPasswordResetRPC(role, email);
    if(result){
      const resetLink = window.location.origin + window.location.pathname + '?reset=' + encodeURIComponent(result.token);
      await espSendResetEmail(result.email, resetLink);
    }
    // Message volontairement identique, que le compte existe ou non (protège la confidentialité des comptes).
    msgEl.innerHTML = '<p class="esp-success">Si un compte existe avec cet e-mail, un lien de réinitialisation vient d\'être envoyé. Vérifie ta boîte de réception (et tes courriers indésirables).</p>';
    btn.style.display = 'none';
  } catch(e){
    msgEl.innerHTML = '<p class="esp-error">Erreur lors de l\'envoi : ' + escapeHtml(e.message) + '</p>';
    btn.disabled = false; btn.textContent = 'Envoyer le lien de réinitialisation';
  }
}

// Écran affiché quand l'utilisateur arrive depuis le lien reçu par e-mail (?reset=TOKEN)
function espRenderResetPasswordScreen(token){
  const gate = document.getElementById('auth-gate');
  const wrap = document.getElementById('platform-wrap');
  const gateContent = document.getElementById('gate-content');
  wrap.style.display = 'none';
  gate.style.display = 'flex';
  gateContent.innerHTML = `
    <div class="esp-card" style="max-width:480px;margin:40px auto;">
      <div class="esp-title">🔑 Nouveau mot de passe</div>
      <p class="esp-sub">Choisis un nouveau mot de passe pour ton compte.</p>
      <div id="esp-reset-msg"></div>
      <div class="esp-field" style="margin-bottom:12px;"><label>Nouveau mot de passe</label><input type="password" id="esp-reset-pass1"></div>
      <div class="esp-field" style="margin-bottom:14px;"><label>Confirme le mot de passe</label><input type="password" id="esp-reset-pass2"></div>
      <button class="esp-btn esp-btn-primary" id="esp-reset-submit-btn" onclick="espSubmitResetPassword('${token}')">Valider le nouveau mot de passe</button>
    </div>
  `;
}
async function espSubmitResetPassword(token){
  const pass1 = document.getElementById('esp-reset-pass1').value;
  const pass2 = document.getElementById('esp-reset-pass2').value;
  const msgEl = document.getElementById('esp-reset-msg');
  const btn = document.getElementById('esp-reset-submit-btn');
  if(!pass1 || pass1.length < 4){ msgEl.innerHTML = '<p class="esp-error">Le mot de passe doit contenir au moins 4 caractères.</p>'; return; }
  if(pass1 !== pass2){ msgEl.innerHTML = '<p class="esp-error">Les deux mots de passe ne correspondent pas.</p>'; return; }
  btn.disabled = true; btn.textContent = 'Validation en cours...';
  try {
    const ok = await espResetPasswordWithTokenRPC(token, pass1);
    if(!ok){
      msgEl.innerHTML = '<p class="esp-error">Ce lien est invalide ou a expiré (valable 1 heure). Merci de refaire une demande de réinitialisation.</p>';
      btn.disabled = false; btn.textContent = 'Valider le nouveau mot de passe';
      return;
    }
    msgEl.innerHTML = '<p class="esp-success">Mot de passe mis à jour ! Tu peux maintenant te connecter avec ton nouveau mot de passe.</p>';
    btn.style.display = 'none';
    setTimeout(() => {
      window.location.href = window.location.origin + window.location.pathname; // retire ?reset=... de l'URL
    }, 2500);
  } catch(e){
    msgEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(e.message) + '</p>';
    btn.disabled = false; btn.textContent = 'Valider le nouveau mot de passe';
  }
}
