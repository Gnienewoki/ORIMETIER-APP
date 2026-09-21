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
          <div class="esp-field"><label>Mot de passe</label><input type="password" id="esp-insp-pass2"></div>
        </div>
        <div class="esp-field" style="margin-bottom:12px;"><label>E-mail</label><input type="email" id="esp-insp-email2" placeholder="Pour récupérer ton mot de passe en cas d'oubli"></div>
        <button class="esp-btn esp-btn-primary" id="esp-insp-register-btn" onclick="espInspecteurRegister()">Créer mon compte</button>
        <p style="margin-top:14px;font-size:13px;">Déjà inscrit(e) ? <span class="esp-toggle-link" onclick="espRenderInspecteurAuth('login')" role="button" tabindex="0" onkeydown="espActivateOnKeydown(event)">Se connecter</span></p>
      `}
    </div>
  `;
  espRefreshIcons();
}
// Verrou anti double envoi : l'insert est asynchrone et le contrôle de doublon lit une liste
// distante, donc deux clics rapprochés passeraient tous les deux avant que le premier compte
// n'existe. Le drapeau bloque le second appel même si le bouton n'a pas encore été grisé.
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
  const btn = document.getElementById('esp-insp-register-btn');
  _espInspRegisterBusy = true;
  if(btn){ btn.disabled = true; btn.textContent = 'Création en cours...'; }
  errEl.innerHTML = '';
  try {
    // Liste fraîche (pas le cache, potentiellement antérieur à un compte créé ailleurs) ;
    // comparaison sur le numéro normalisé pour aussi rattraper les anciens comptes saisis
    // avec espaces ou +225.
    try {
      const rows = await espFetchAllRows('list_inspecteurs');
      if(rows.some(r => normalizeTel(r.tel) === tel)){
        errEl.innerHTML = '<p class="esp-error">Un compte existe déjà avec ce numéro de téléphone.</p>';
        return;
      }
    } catch(e){
      errEl.innerHTML = '<p class="esp-error">Impossible de vérifier ce numéro pour le moment. Vérifie ta connexion et réessaie.</p>';
      return;
    }
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
    espSaveDB(db);
    espSetSession('inspecteur', id, pass);
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
  let insp;
  try {
    insp = await espInspecteurLoginRPC(tel, pass);
    // Repli pour les comptes créés avant la normalisation, dont le numéro stocké garde ses
    // espaces ou son indicatif : on retente avec la saisie brute.
    if(!insp && telSaisi && telSaisi !== tel) insp = await espInspecteurLoginRPC(telSaisi, pass);
  } catch(e){
    document.getElementById('esp-insp-error').innerHTML = '<p class="esp-error">Erreur de connexion : ' + escapeHtml(e.message) + '</p>';
    return;
  }
  if(!insp){
    document.getElementById('esp-insp-error').innerHTML = '<p class="esp-error">Téléphone ou mot de passe incorrect.</p>';
    return;
  }
  if(insp.banni){
    document.getElementById('esp-insp-error').innerHTML = '<p class="esp-error">Ce compte a été suspendu par l\'administration. Contacte l\'administrateur de la plateforme pour plus d\'informations.</p>';
    return;
  }
  espSetSession('inspecteur', insp.id, pass);
  platformUnlock();
}
function espInspecteurLogout(){ platformLogout(); }

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
        <p class="esp-insp-profile-msg">${insp.messageAccueil ? escapeHtml(insp.messageAccueil) : '<i>Aucun message d\'accueil défini.</i>'}</p>
        <span class="esp-toggle-link" onclick="espInspecteurToggleProfileEdit()" role="button" tabindex="0" onkeydown="espActivateOnKeydown(event)">${icon('pencil')}Modifier</span>
        <div id="esp-insp-profile-edit" style="display:none;margin-top:12px;border-top:1px dashed var(--border);padding-top:12px;">
          <div class="esp-field">
            <label>Photo de profil</label>
            <input type="file" id="esp-insp-avatar-input" accept="image/*" onchange="espInspecteurUploadAvatar(this)">
            <div id="esp-insp-avatar-msg"></div>
          </div>
          <div class="esp-field" style="margin-top:10px;">
            <label>Message d'accueil</label>
            <textarea id="esp-insp-message-accueil" rows="2" maxlength="200" placeholder="Ex : Bonjour, je suis à votre écoute pour toute question d'orientation.">${escapeHtml(insp.messageAccueil||'')}</textarea>
          </div>
          <button class="esp-btn esp-btn-primary" style="margin-top:8px;" onclick="espInspecteurSaveMessageAccueil()">Enregistrer le message</button>
          <div id="esp-insp-message-accueil-msg"></div>
          <div class="esp-field" style="margin-top:14px;" id="esp-insp-email-card">
            <label>E-mail de récupération</label>
            ${insp.email ? `<p class="esp-sub" style="margin:0;">${icon('mail')}<b>${escapeHtml(insp.email)}</b> &nbsp;<span class="esp-toggle-link" onclick="espShowEmailForm('inspecteur')" role="button" tabindex="0" onkeydown="espActivateOnKeydown(event)">Modifier</span></p>` : `<p class="esp-sub" style="margin:0;">${icon('triangle-alert')}Aucun e-mail enregistré. <span class="esp-toggle-link" onclick="espShowEmailForm('inspecteur')" role="button" tabindex="0" onkeydown="espActivateOnKeydown(event)">Ajouter</span></p>`}
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
  const session = espSession();
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
    const ok = await espPostMessageRPC(session.id, session.password, texte, type, replyTo, attachment);
    if(!ok){ errEl.innerHTML = '<p class="esp-error">Impossible d\'envoyer le message (session expirée, ou compte suspendu). Merci de te reconnecter.</p>'; return; }
  } catch(e){
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
    const ok = await espInspecteurUpdateAvatarRPC(session.id, session.password, url);
    if(!ok){ msgEl.innerHTML = '<p class="esp-error">Session expirée, merci de te reconnecter.</p>'; return; }
    const db = espDB();
    const insp = db.inspecteurs.find(i => i.id === session.id);
    if(insp) insp.avatarUrl = url;
    espSaveDB(db);
    espRenderInspecteurDashboard('chat');
  } catch(e){
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
    const ok = await espInspecteurUpdateMessageAccueilRPC(session.id, session.password, message);
    if(!ok){ msgEl.innerHTML = '<p class="esp-error">Session expirée, merci de te reconnecter.</p>'; return; }
    const db = espDB();
    const insp = db.inspecteurs.find(i => i.id === session.id);
    if(insp) insp.messageAccueil = message;
    espSaveDB(db);
    msgEl.innerHTML = `<p class="esp-sub" style="margin:6px 0 0;color:var(--green-dark);">Message enregistré ${icon('badge-check')}</p>`;
    espRefreshIcons();
  } catch(e){
    msgEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(e.message) + '</p>';
  }
}

async function espInspecteurRequestCertification(){
  const session = espSession();
  const msgEl = document.getElementById('esp-insp-certif-msg');
  try {
    const ok = await espInspecteurRequestCertificationRPC(session.id, session.password);
    if(!ok){ msgEl.innerHTML = '<p class="esp-error">Session expirée, merci de te reconnecter.</p>'; return; }
    const db = espDB();
    const insp = db.inspecteurs.find(i => i.id === session.id);
    if(insp) insp.certificationDemandee = true;
    espSaveDB(db);
    espRenderInspecteurDashboard('chat');
  } catch(e){
    msgEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(e.message) + '</p>';
  }
}

// ---------------- ÉLÈVE ----------------
