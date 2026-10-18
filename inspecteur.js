function espRenderInspecteurAuth(mode){
  const isLogin = mode === 'login';
  document.getElementById('esp-inspecteur').innerHTML = `
    <button class="esp-back" onclick="espBackToRoleSelect()">${icon('arrow-left')}Retour</button>
    <div class="esp-card" style="max-width:520px;margin:0 auto;">
      <div class="esp-title">${icon('compass')}Espace Inspecteur d'Orientation</div>
      <p class="esp-sub">${isLogin ? 'Connectez-vous avec votre numéro de téléphone et votre mot de passe.' : "Créez votre compte inspecteur pour suivre les profils d'orientation des élèves."}</p>
      <div id="esp-insp-error"></div>
      ${isLogin ? `
        <div class="esp-field" style="margin-bottom:12px;"><label>Téléphone</label><input type="tel" id="esp-insp-tel" placeholder="Ex : 07 00 00 00 00"></div>
        <div class="esp-field" style="margin-bottom:8px;"><label>Mot de passe</label><input type="password" id="esp-insp-pass" onkeydown="if(event.key==='Enter')espInspecteurLogin()"></div>
        <p style="margin:0 0 14px;font-size:12.5px;"><span class="esp-toggle-link" onclick="espRenderForgotPassword('inspecteur','esp-inspecteur', () => espRenderInspecteurAuth('login'))" role="button" tabindex="0" onkeydown="espActivateOnKeydown(event)">Mot de passe oublié ?</span></p>
        <button class="esp-btn esp-btn-primary" onclick="espInspecteurLogin()">Se connecter</button>
        <p style="margin-top:14px;font-size:13px;">Pas encore de compte ? <span class="esp-toggle-link" onclick="espRenderInspecteurAuth('register')" role="button" tabindex="0" onkeydown="espActivateOnKeydown(event)">Créer un compte inspecteur</span></p>
      ` : `
        <div class="esp-field-row">
          <div class="esp-field"><label>Nom</label><input type="text" id="esp-insp-nom"></div>
          <div class="esp-field"><label>Prénoms</label><input type="text" id="esp-insp-prenoms"></div>
        </div>
        <div class="esp-field-row">
          <div class="esp-field"><label>Fonction</label><input type="text" id="esp-insp-fonction" placeholder="Ex : Inspecteur d'orientation"></div>
          <div class="esp-field"><label>CIO / Zone de rattachement</label><input type="text" id="esp-insp-cio" placeholder="Ex : CIO Daloa"></div>
        </div>
        <div class="esp-field-row">
          <div class="esp-field"><label>Téléphone</label><input type="tel" id="esp-insp-tel2" placeholder="Ex : 07 00 00 00 00"></div>
          <div class="esp-field"><label>Mot de passe</label><input type="password" id="esp-insp-pass2" oninput="espMdpIndicateurMaj(this)" aria-describedby="esp-insp-pass2-longueur">${espMdpIndicateurHtml('esp-insp-pass2')}</div>
        </div>
        <div class="esp-field" style="margin-bottom:12px;"><label>E-mail</label><input type="email" id="esp-insp-email2" placeholder="Pour récupérer ton mot de passe en cas d'oubli"></div>
        <button class="esp-btn esp-btn-primary" id="esp-insp-register-btn" onclick="espInspecteurRegister()">Créer mon compte</button>
        <p style="margin-top:14px;font-size:13px;">Déjà inscrit(e) ? <span class="esp-toggle-link" onclick="espRenderInspecteurAuth('login')" role="button" tabindex="0" onkeydown="espActivateOnKeydown(event)">Se connecter</span></p>
      `}
    </div>
  `;
  espRefreshIcons();
}
// Verrou anti double envoi : l'inscription est asynchrone, deux clics rapprochés enverraient
// deux demandes. Le drapeau bloque le second appel même si le bouton n'a pas encore été grisé.
// Téléphone ou e-mail déjà utilisé : tranché par inspecteur_register (numéro normalisé côté
// serveur), plus par une liste lue ici (list_inspecteurs ne renvoie plus tel ni email).
let _espInspRegisterBusy = false;
async function espInspecteurRegister(){
  if(_espInspRegisterBusy) return;
  const nom = document.getElementById('esp-insp-nom').value.trim();
  const prenoms = document.getElementById('esp-insp-prenoms').value.trim();
  const fonction = document.getElementById('esp-insp-fonction').value.trim();
  const cio = document.getElementById('esp-insp-cio').value.trim();
  const tel = normalizeTel(document.getElementById('esp-insp-tel2').value);
  const pass = document.getElementById('esp-insp-pass2').value;
  const email = document.getElementById('esp-insp-email2').value.trim();
  const errEl = document.getElementById('esp-insp-error');
  if(!nom || !tel || !pass){
    errEl.innerHTML = '<p class="esp-error">Nom, téléphone et mot de passe sont obligatoires.</p>';
    return;
  }
  if(espMdpTropCourt(pass)){
    errEl.innerHTML = '<p class="esp-error">' + ESP_MDP_TROP_COURT_MSG + '</p>';
    return;
  }
  const btn = document.getElementById('esp-insp-register-btn');
  _espInspRegisterBusy = true;
  if(btn){ btn.disabled = true; btn.textContent = 'Création en cours...'; }
  errEl.innerHTML = '';
  try {
    const id = espUid();
    const nouvelInsp = { id, nom, prenoms, fonction, cio, tel, email, password:pass, active:true, dateInscription:espDate() };
    try {
      await espInsertInspecteur(espInspecteurToRow(nouvelInsp));
    } catch(e){
      errEl.innerHTML = '<p class="esp-error">Erreur lors de la création du compte : ' + escapeHtml(e.message) + '</p>';
      return;
    }
    // espDB() relu après les attendus : un rafraîchissement temps réel a pu remplacer le cache.
    const db = espDB();
    db.inspecteurs.push(nouvelInsp);
    espSaveDB(db); // le cache d'onglet n'enregistre jamais la clé "password"
    // Ouverture de session par jeton, comme une connexion : aucun mot de passe en session.
    let ouverture = null;
    try { ouverture = await espInspecteurSessionOpenRPC(tel, pass); } catch(e){ console.error('[esp] ouverture de session après inscription impossible', e); }
    if(!ouverture || !ouverture.token){
      espRenderInspecteurAuth('login');
      document.getElementById('esp-insp-error').innerHTML = '<p class="esp-success">Compte créé. Connecte-toi avec ton téléphone et ton mot de passe.</p>';
      return;
    }
    espSetTokenSession('inspecteur', ouverture.id, ouverture.token, ouverture.expires_at);
    platformUnlock();
  } finally {
    _espInspRegisterBusy = false;
    if(btn){ btn.disabled = false; btn.textContent = 'Créer mon compte'; }
  }
}
async function espInspecteurLogin(){
  const telSaisi = document.getElementById('esp-insp-tel').value.trim();
  const tel = normalizeTel(telSaisi);
  const pass = document.getElementById('esp-insp-pass').value;
  // Ouverture de session par jeton : null (identifiants incorrects), {banni:true} (compte
  // suspendu, aucune session créée) ou {token, expires_at, id, ...}.
  let ouverture;
  try {
    ouverture = await espInspecteurSessionOpenRPC(tel, pass);
    // Repli pour les comptes créés avant la normalisation, dont le numéro stocké garde ses
    // espaces ou son indicatif : on retente avec la saisie brute.
    if(!ouverture && telSaisi && telSaisi !== tel) ouverture = await espInspecteurSessionOpenRPC(telSaisi, pass);
  } catch(e){
    document.getElementById('esp-insp-error').innerHTML = '<p class="esp-error">Erreur de connexion : ' + escapeHtml(e.message) + '</p>';
    return;
  }
  if(!ouverture){
    document.getElementById('esp-insp-error').innerHTML = '<p class="esp-error">Téléphone ou mot de passe incorrect.</p>';
    return;
  }
  if(ouverture.banni){
    document.getElementById('esp-insp-error').innerHTML = '<p class="esp-error">Ce compte a été suspendu par l\'administration. Contacte l\'administrateur de la plateforme pour plus d\'informations.</p>';
    return;
  }
  if(!ouverture.token){
    document.getElementById('esp-insp-error').innerHTML = '<p class="esp-error">Erreur de connexion : réponse inattendue du serveur.</p>';
    return;
  }
  espSetTokenSession('inspecteur', ouverture.id, ouverture.token, ouverture.expires_at);
  platformUnlock();
}
function espInspecteurLogout(){ _espInspOwnContact = null; platformLogout(); }
// Appelée par espHandleSessionInvalid (auth.js) et après un changement d'e-mail : oublie les
// coordonnées en mémoire, relues au prochain rendu du tableau de bord.
function espInspecteurResetOwn(){ _espInspOwnContact = null; _espInspOwnContactErreur = false; }

// Coordonnées (tel, e-mail) et message d'accueil de l'inspecteur connecté : alimentés par
// inspecteur_get_own_v2, jamais par list_inspecteurs (qui ne les renvoie pas). En mémoire
// seulement, jamais dans espDB() ni dans sessionStorage. null = pas encore chargé.
let _espInspOwnContact = null;
let _espInspOwnContactLoading = false;
let _espInspOwnContactErreur = false;
async function espInspecteurEnsureOwnContactLoaded(){
  const session = espSession();
  if(!session || session.role !== 'inspecteur') return;
  if((_espInspOwnContact && _espInspOwnContact.id === session.id) || _espInspOwnContactLoading) return;
  _espInspOwnContactLoading = true;
  let own;
  try {
    own = await espInspecteurGetOwnRPC();
  } catch(e){
    _espInspOwnContactLoading = false;
    if(e.espSessionInvalid) return;
    console.error('[esp] lecture des coordonnées impossible', e);
    _espInspOwnContactErreur = true;
    espInspecteurRefreshOwnLignes();
    return;
  }
  _espInspOwnContactLoading = false;
  _espInspOwnContact = own;
  _espInspOwnContactErreur = !own;
  espInspecteurRefreshOwnLignes();
}
// Ligne « E-mail de récupération » du profil (seule la ligne est redessinée après chargement).
function espInspecteurEmailStatutHtml(){
  const session = espSession();
  const own = (_espInspOwnContact && session && _espInspOwnContact.id === session.id) ? _espInspOwnContact : null;
  if(!own) return _espInspOwnContactErreur ? `${icon('triangle-alert')}E-mail indisponible pour le moment.` : 'Chargement…';
  return own.email ? `${icon('mail')}<b>${escapeHtml(own.email)}</b> &nbsp;<span class="esp-toggle-link" onclick="espShowEmailForm('inspecteur')" role="button" tabindex="0" onkeydown="espActivateOnKeydown(event)">Modifier</span>` : `${icon('triangle-alert')}Aucun e-mail enregistré. <span class="esp-toggle-link" onclick="espShowEmailForm('inspecteur')" role="button" tabindex="0" onkeydown="espActivateOnKeydown(event)">Ajouter</span>`;
}
// Coordonnées chargées pour la session courante, sinon null.
function espInspecteurOwnCharge(){
  const session = espSession();
  return (_espInspOwnContact && session && _espInspOwnContact.id === session.id) ? _espInspOwnContact : null;
}
// Message d'accueil : valeur de espDB() si renseignée (enregistrée dans cet onglet), sinon celle
// lue par inspecteur_get_own_v2 (list_inspecteurs ne le renvoie pas).
function espInspecteurMessageAccueil(insp){
  const own = espInspecteurOwnCharge();
  return (insp && insp.messageAccueil) || (own && own.messageAccueil) || '';
}
function espInspecteurMessageAccueilHtml(insp){
  const message = espInspecteurMessageAccueil(insp);
  if(message) return escapeHtml(message);
  if(!espInspecteurOwnCharge() && !_espInspOwnContactErreur) return '<i>Chargement…</i>';
  return '<i>Aucun message d\'accueil défini.</i>';
}
// Redessine les lignes du profil qui dépendent de inspecteur_get_own_v2 (e-mail, message
// d'accueil), sans redessiner le tableau de bord.
function espInspecteurRefreshOwnLignes(){
  const el = document.getElementById('esp-insp-email-statut');
  if(el) el.innerHTML = espInspecteurEmailStatutHtml();
  const session = espSession();
  const insp = session ? espDB().inspecteurs.find(i => i.id === session.id) : null;
  const affiche = document.getElementById('esp-insp-message-accueil-affiche');
  if(affiche) affiche.innerHTML = espInspecteurMessageAccueilHtml(insp);
  // Champ de saisie : pré-rempli seulement s'il est vide et pas en cours d'édition.
  const champ = document.getElementById('esp-insp-message-accueil');
  if(champ && !champ.value && document.activeElement !== champ) champ.value = espInspecteurMessageAccueil(insp);
  espRefreshIcons();
}

function espInspecteurToggleProfileEdit(){
  const panel = document.getElementById('esp-insp-profile-edit');
  if(!panel) return;
  panel.style.display = panel.style.display === 'none' ? '' : 'none';
}

function espRenderInspecteurDashboard(sub){
  sub = sub || 'chat';
  const session = espSession();
  const db = espDB();
  const insp = db.inspecteurs.find(i => i.id === session.id);
  if(!insp){ espInspecteurLogout(); return; }

  let subHtml = '';
  if(sub === 'chat'){
    const messages = db.messages || [];
    subHtml = `
      <div class="esp-card esp-chat-card">
        <div class="esp-chat-intro">${icon('message-circle')}Échange libre entre inspecteurs d'orientation de toute la Côte d'Ivoire. Utilise « Important » pour signaler un point qui mérite une attention particulière.</div>
        <div id="esp-chat-list" class="esp-chat-list">
          ${messages.length ? espChatListWithDaySeparators(messages, m => espChatMessageHtml(m, { mine: m.inspecteurId === insp.id, inspecteursCache: db.inspecteurs, allMessages: messages, replyHandler: 'espSetReplyTarget', hideDate: true })) : `<p class="esp-empty">Aucun message pour le moment. Sois le premier à écrire !</p>`}
        </div>
        <div id="esp-chat-reply-preview"></div>
        <div id="esp-chat-error"></div>
        <div class="esp-chat-compose">
          <div class="esp-field-row" style="align-items:flex-end;">
            <div class="esp-field" style="flex:2;">
              <label>Message</label>
              <input type="text" id="esp-chat-input" placeholder="Écrire un message..." onkeydown="if(event.key==='Enter')espSendChatMessage()">
            </div>
            <div class="esp-field" style="flex:1;">
              <label>Type</label>
              <select id="esp-chat-type">
                <option value="C">Ordinaire</option>
                <option value="A">Important</option>
              </select>
            </div>
          </div>
          <div class="esp-chat-compose-actions">
            <label class="esp-chat-attach-label" for="esp-chat-file-input">${icon('paperclip')}Joindre une photo ou un PDF</label>
            <input type="file" id="esp-chat-file-input" accept="image/*,application/pdf" onchange="espChatPreviewAttachment(this)" style="display:none;">
            <div id="esp-chat-file-preview"></div>
            <button class="esp-btn esp-btn-primary" id="esp-chat-send-btn" onclick="espSendChatMessage()">Envoyer</button>
          </div>
        </div>
      </div>
    `;
  } else if(sub === 'prive'){
    subHtml = `<div id="esp-priv-tab-container">${espRenderPrivateTab()}</div>`;
  } else if(sub === 'lycam'){
    subHtml = `<div id="esp-lycam-tab-container"><p class="esp-empty">Chargement...</p></div>`;
  } else if(sub === 'mbti'){
    subHtml = `<div id="esp-mbti-tab-container"><p class="esp-empty">Chargement...</p></div>`;
  } else if(sub === 'suivi'){
    subHtml = `<div id="esp-suivi-tab-container"><p class="esp-empty">Chargement...</p></div>`;
  }

  document.getElementById('esp-inspecteur').innerHTML = `
    <div class="esp-user-header">
      <span class="esp-user-name">${icon('compass')}${escapeHtml(insp.nom)} ${escapeHtml(insp.prenoms||'')} — ${escapeHtml(insp.fonction||'Inspecteur')}</span>
      <button class="esp-btn" onclick="espInspecteurLogout()">Déconnexion</button>
    </div>

    <div class="esp-insp-top-row">
      <div class="esp-insp-profile-card">
        <div class="esp-insp-profile-head">
          ${insp.avatarUrl ? `<img src="${escapeHtml(insp.avatarUrl)}" class="esp-chat-avatar" style="width:52px;height:52px;" alt="">` : `<div class="esp-chat-avatar-placeholder" style="width:52px;height:52px;font-size:20px;">${escapeHtml((insp.nom||'?').charAt(0).toUpperCase())}</div>`}
          <div class="esp-insp-profile-info">
            <div class="esp-insp-profile-name">${escapeHtml(insp.nom)} ${escapeHtml(insp.prenoms||'')}${insp.certifie ? ' <span class="esp-badge-certifie" title="Compte certifié">' + icon('badge-check') + '</span>' : ''}</div>
            <div class="esp-insp-profile-fonction">${escapeHtml(insp.fonction||'Inspecteur')}${insp.cio ? ' · ' + escapeHtml(insp.cio) : ''}</div>
          </div>
        </div>
        <p class="esp-insp-profile-msg" id="esp-insp-message-accueil-affiche">${espInspecteurMessageAccueilHtml(insp)}</p>
        <span class="esp-toggle-link" onclick="espInspecteurToggleProfileEdit()" role="button" tabindex="0" onkeydown="espActivateOnKeydown(event)">${icon('pencil')}Modifier</span>
        <div id="esp-insp-profile-edit" style="display:none;margin-top:12px;border-top:1px dashed var(--border);padding-top:12px;">
          <div class="esp-field">
            <label>Photo de profil</label>
            <input type="file" id="esp-insp-avatar-input" accept="image/*" onchange="espInspecteurUploadAvatar(this)">
            <div id="esp-insp-avatar-msg"></div>
          </div>
          <div class="esp-field" style="margin-top:10px;">
            <label>Message d'accueil</label>
            <textarea id="esp-insp-message-accueil" rows="2" maxlength="200" placeholder="Ex : Bonjour, je suis à votre écoute pour toute question d'orientation.">${escapeHtml(espInspecteurMessageAccueil(insp))}</textarea>
          </div>
          <button class="esp-btn esp-btn-primary" style="margin-top:8px;" onclick="espInspecteurSaveMessageAccueil()">Enregistrer le message</button>
          <div id="esp-insp-message-accueil-msg"></div>
          <div class="esp-field" style="margin-top:14px;" id="esp-insp-email-card">
            <label>E-mail de récupération</label>
            <p id="esp-insp-email-statut" class="esp-sub" style="margin:0;">${espInspecteurEmailStatutHtml()}</p>
            <div id="esp-insp-email-form"></div>
          </div>
          <div style="margin-top:14px;">
            ${insp.certifie ? `<p class="esp-sub" style="margin:0;">${icon('shield-check')}Compte certifié <span class="esp-badge-certifie">${icon('badge-check')}</span></p>`
              : insp.certificationDemandee ? `<p class="esp-sub" style="margin:0;">${icon('shield-check')}Demande de certification en attente.</p>`
              : `<button class="esp-btn" onclick="espInspecteurRequestCertification()">${icon('shield-check')}Demander la certification</button>`}
            <div id="esp-insp-certif-msg"></div>
          </div>
        </div>
      </div>
      <div class="esp-insp-future-btns">
        <button class="esp-btn" onclick="espRenderInspecteurDashboard('lycam')">${icon('flask-conical')}Test LYCAM</button>
        <button class="esp-btn" onclick="espRenderInspecteurDashboard('mbti')">${icon('brain')}MBTI</button>
        <button class="esp-btn" onclick="espRenderInspecteurDashboard('suivi')">${icon('user-check')}Suivi d'élèves</button>
        <button class="esp-btn" disabled title="Bientôt disponible">${icon('book-open')}Formations</button>
      </div>
    </div>

    <div class="esp-subtabs">
      <button class="esp-subtab-btn ${sub==='chat'?'active':''}" onclick="espRenderInspecteurDashboard('chat')">${icon('message-circle')}Discussion (${(db.messages||[]).length})</button>
      <button class="esp-subtab-btn ${sub==='prive'?'active':''}" onclick="espRenderInspecteurDashboard('prive')">${icon('send')}Messages privés${espPrivateUnreadTotal() ? ' (' + espPrivateUnreadTotal() + ')' : ''}</button>
    </div>
    ${subHtml}
  `;
  espRefreshIcons();
  // E-mail de récupération : lu par inspecteur_get_own_v2 (une fois par session).
  espInspecteurEnsureOwnContactLoaded();

  if(sub === 'chat'){
    const list = document.getElementById('esp-chat-list');
    if(list) list.scrollTop = list.scrollHeight;
    espUpdateReplyPreview();
  }
  if(sub === 'prive'){
    const list = document.getElementById('esp-priv-list');
    if(list) list.scrollTop = list.scrollHeight;
  }
  if(sub === 'lycam'){
    espLycamInitTab();
  }
  if(sub === 'mbti'){
    espMbtiInitTab();
  }
  if(sub === 'suivi'){
    espSuiviInitTab();
  }
}

async function espSendChatMessage(){
  const input = document.getElementById('esp-chat-input');
  const typeSelect = document.getElementById('esp-chat-type');
  const texte = input.value.trim();
  const type = typeSelect ? typeSelect.value : 'C';
  const replyTo = _espReplyTarget ? _espReplyTarget.id : null;
  const errEl = document.getElementById('esp-chat-error');
  const sendBtn = document.getElementById('esp-chat-send-btn');
  if(!texte && !_espChatPendingFile) return;
  if(sendBtn){ sendBtn.disabled = true; sendBtn.textContent = 'Envoi en cours...'; }
  try {
    const attachment = await espChatUploadPendingAttachment();
    const ok = await espPostMessageRPC(texte, type, replyTo, attachment);
    if(!ok){ errEl.innerHTML = '<p class="esp-error">Action impossible (limite atteinte ou accès refusé).</p>'; return; }
  } catch(e){
    if(e.espSessionInvalid) return;
    errEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(e.message) + '</p>';
    return;
  } finally {
    if(sendBtn){ sendBtn.disabled = false; sendBtn.textContent = 'Envoyer'; }
  }
  input.value = '';
  espChatClearAttachment('esp-chat-file-input');
  _espReplyTarget = null;
  await espLoadFromSupabase(true);
  espRenderInspecteurDashboard('chat');
}

async function espInspecteurUploadAvatar(input){
  const file = input.files && input.files[0];
  if(!file) return;
  const msgEl = document.getElementById('esp-insp-avatar-msg');
  const session = espSession();
  msgEl.innerHTML = '<p class="esp-sub" style="margin:6px 0 0;">Envoi en cours...</p>';
  try {
    const url = await espUploadAvatarFile(file);
    const ok = await espInspecteurUpdateAvatarRPC(url);
    if(!ok){ msgEl.innerHTML = '<p class="esp-error">Action impossible (limite atteinte ou accès refusé).</p>'; return; }
    const db = espDB();
    const insp = db.inspecteurs.find(i => i.id === session.id);
    if(insp) insp.avatarUrl = url;
    espSaveDB(db);
    espRenderInspecteurDashboard('chat');
  } catch(e){
    if(e.espSessionInvalid) return;
    msgEl.innerHTML = '<p class="esp-error">Erreur lors de l\'envoi : ' + escapeHtml(e.message) + '</p>';
  }
}

async function espInspecteurSaveMessageAccueil(){
  const textarea = document.getElementById('esp-insp-message-accueil');
  const msgEl = document.getElementById('esp-insp-message-accueil-msg');
  const message = textarea.value.trim();
  const session = espSession();
  msgEl.innerHTML = '<p class="esp-sub" style="margin:6px 0 0;">Enregistrement...</p>';
  try {
    const ok = await espInspecteurUpdateMessageAccueilRPC(message);
    if(!ok){ msgEl.innerHTML = '<p class="esp-error">Action impossible (limite atteinte ou accès refusé).</p>'; return; }
    const db = espDB();
    const insp = db.inspecteurs.find(i => i.id === session.id);
    if(insp) insp.messageAccueil = message;
    espSaveDB(db);
    // Cache de inspecteur_get_own_v2 aligné : sinon l'ancien message y reviendrait (ex. message vidé).
    const own = espInspecteurOwnCharge();
    if(own) own.messageAccueil = message;
    espInspecteurRefreshOwnLignes();
    msgEl.innerHTML = `<p class="esp-sub" style="margin:6px 0 0;color:var(--green-dark);">Message enregistré ${icon('badge-check')}</p>`;
    espRefreshIcons();
  } catch(e){
    if(e.espSessionInvalid) return;
    msgEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(e.message) + '</p>';
  }
}

async function espInspecteurRequestCertification(){
  const session = espSession();
  const msgEl = document.getElementById('esp-insp-certif-msg');
  try {
    const ok = await espInspecteurRequestCertificationRPC();
    if(!ok){ msgEl.innerHTML = '<p class="esp-error">Action impossible (limite atteinte ou accès refusé).</p>'; return; }
    const db = espDB();
    const insp = db.inspecteurs.find(i => i.id === session.id);
    if(insp) insp.certificationDemandee = true;
    espSaveDB(db);
    espRenderInspecteurDashboard('chat');
  } catch(e){
    if(e.espSessionInvalid) return;
    msgEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(e.message) + '</p>';
  }
}

// ---------------- ÉLÈVE ----------------
