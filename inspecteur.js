function espRenderInspecteurAuth(mode){
  const isLogin = mode === 'login';
  document.getElementById('esp-inspecteur').innerHTML = `
    <button class="esp-back" onclick="espBackToRoleSelect()">← Retour</button>
    <div class="esp-card" style="max-width:520px;margin:0 auto;">
      <div class="esp-title">🧭 Espace Inspecteur d'Orientation</div>
      <p class="esp-sub">${isLogin ? 'Connectez-vous avec votre numéro de téléphone et votre mot de passe.' : "Créez votre compte inspecteur pour suivre les profils d'orientation des élèves."}</p>
      <div id="esp-insp-error"></div>
      ${isLogin ? `
        <div class="esp-field" style="margin-bottom:12px;"><label>Téléphone</label><input type="tel" id="esp-insp-tel" placeholder="Ex : 07 00 00 00 00"></div>
        <div class="esp-field" style="margin-bottom:8px;"><label>Mot de passe</label><input type="password" id="esp-insp-pass" onkeydown="if(event.key==='Enter')espInspecteurLogin()"></div>
        <p style="margin:0 0 14px;font-size:12.5px;"><span class="esp-toggle-link" onclick="espRenderForgotPassword('inspecteur','esp-inspecteur', () => espRenderInspecteurAuth('login'))">Mot de passe oublié ?</span></p>
        <button class="esp-btn esp-btn-primary" onclick="espInspecteurLogin()">Se connecter</button>
        <p style="margin-top:14px;font-size:13px;">Pas encore de compte ? <span class="esp-toggle-link" onclick="espRenderInspecteurAuth('register')">Créer un compte inspecteur</span></p>
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
        <button class="esp-btn esp-btn-primary" onclick="espInspecteurRegister()">Créer mon compte</button>
        <p style="margin-top:14px;font-size:13px;">Déjà inscrit(e) ? <span class="esp-toggle-link" onclick="espRenderInspecteurAuth('login')">Se connecter</span></p>
      `}
    </div>
  `;
}
async function espInspecteurRegister(){
  const nom = document.getElementById('esp-insp-nom').value.trim();
  const prenoms = document.getElementById('esp-insp-prenoms').value.trim();
  const fonction = document.getElementById('esp-insp-fonction').value.trim();
  const cio = document.getElementById('esp-insp-cio').value.trim();
  const tel = document.getElementById('esp-insp-tel2').value.trim();
  const pass = document.getElementById('esp-insp-pass2').value;
  const email = document.getElementById('esp-insp-email2').value.trim();
  if(!nom || !tel || !pass){
    document.getElementById('esp-insp-error').innerHTML = '<p class="esp-error">Nom, téléphone et mot de passe sont obligatoires.</p>';
    return;
  }
  const db = espDB();
  if(db.inspecteurs.some(i => i.tel === tel)){
    document.getElementById('esp-insp-error').innerHTML = '<p class="esp-error">Un compte existe déjà avec ce numéro de téléphone.</p>';
    return;
  }
  const id = espUid();
  const nouvelInsp = { id, nom, prenoms, fonction, cio, tel, email, password:pass, active:true, dateInscription:espDate() };
  try {
    await espInsertInspecteur(espInspecteurToRow(nouvelInsp));
  } catch(e){
    document.getElementById('esp-insp-error').innerHTML = '<p class="esp-error">Erreur lors de la création du compte : ' + escapeHtml(e.message) + '</p>';
    return;
  }
  db.inspecteurs.push(nouvelInsp);
  espSaveDB(db);
  espSetSession('inspecteur', id, pass);
  platformUnlock();
}
async function espInspecteurLogin(){
  const tel = document.getElementById('esp-insp-tel').value.trim();
  const pass = document.getElementById('esp-insp-pass').value;
  let insp;
  try {
    insp = await espInspecteurLoginRPC(tel, pass);
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
      <div class="esp-card">
        <div class="esp-title" style="font-size:16px;">💬 Discussion entre inspecteurs</div>
        <p class="esp-sub">Espace d'échange partagé entre tous les inspecteurs d'orientation de la plateforme. Utilise « Important » pour signaler un problème qui nécessite une attention particulière.</p>
        <div id="esp-chat-list" class="esp-chat-list">
          ${messages.length ? messages.map(m => espChatMessageHtml(m, { mine: m.inspecteurId === insp.id, inspecteursCache: db.inspecteurs, allMessages: messages, replyHandler: 'espSetReplyTarget' })).join('') : `<p class="esp-empty">Aucun message pour le moment. Sois le premier à écrire !</p>`}
        </div>
        <div id="esp-chat-reply-preview"></div>
        <div id="esp-chat-error"></div>
        <div class="esp-field-row" style="margin-top:10px;align-items:flex-end;">
          <div class="esp-field" style="flex:2;">
            <label>Message</label>
            <input type="text" id="esp-chat-input" placeholder="Écrire un message..." onkeydown="if(event.key==='Enter')espSendChatMessage()">
          </div>
          <div class="esp-field" style="flex:1;">
            <label>Type</label>
            <select id="esp-chat-type">
              <option value="C">💬 Ordinaire</option>
              <option value="A">📌 Important</option>
            </select>
          </div>
        </div>
        <div style="margin:6px 0 10px;">
          <label style="font-size:12px;font-weight:700;color:var(--green-dark);">📎 Joindre une photo ou un PDF</label><br>
          <input type="file" id="esp-chat-file-input" accept="image/*,application/pdf" onchange="espChatPreviewAttachment(this)">
          <div id="esp-chat-file-preview"></div>
        </div>
        <button class="esp-btn esp-btn-primary" id="esp-chat-send-btn" onclick="espSendChatMessage()">Envoyer</button>
      </div>
    `;
  }

  document.getElementById('esp-inspecteur').innerHTML = `
    <div class="esp-user-header">
      <span class="esp-user-name">🧭 ${escapeHtml(insp.nom)} ${escapeHtml(insp.prenoms||'')} — ${escapeHtml(insp.fonction||'Inspecteur')}</span>
      <button class="esp-btn" onclick="espInspecteurLogout()">Déconnexion</button>
    </div>
    <div class="esp-card" id="esp-insp-email-card">
      ${insp.email ? `
        <p class="esp-sub" style="margin:0;">📧 E-mail de récupération : <b>${escapeHtml(insp.email)}</b> &nbsp;<span class="esp-toggle-link" onclick="espShowEmailForm('inspecteur')">Modifier</span></p>
      ` : `
        <p class="esp-sub" style="margin:0 0 8px;">⚠️ Aucun e-mail enregistré — en cas de mot de passe oublié, tu ne pourras pas le réinitialiser toi-même. <span class="esp-toggle-link" onclick="espShowEmailForm('inspecteur')">Ajouter mon e-mail</span></p>
      `}
      <div id="esp-insp-email-form"></div>
    </div>
    <div class="esp-card">
      <div class="esp-title" style="font-size:15px;">Photo de profil</div>
      <p class="esp-sub" style="margin-bottom:10px;">Visible à côté de ton nom dans la discussion.</p>
      <div style="display:flex;align-items:center;gap:14px;flex-wrap:wrap;">
        ${insp.avatarUrl ? `<img src="${escapeHtml(insp.avatarUrl)}" class="esp-chat-avatar" style="width:56px;height:56px;">` : `<div class="esp-chat-avatar-placeholder" style="width:56px;height:56px;font-size:22px;">${escapeHtml((insp.nom||'?').charAt(0).toUpperCase())}</div>`}
        <div>
          <input type="file" id="esp-insp-avatar-input" accept="image/*" onchange="espInspecteurUploadAvatar(this)">
          <div id="esp-insp-avatar-msg"></div>
        </div>
      </div>
      <div class="esp-field" style="margin-top:14px;">
        <label>Message d'accueil</label>
        <textarea id="esp-insp-message-accueil" rows="2" maxlength="200" placeholder="Ex : Bonjour, je suis à votre écoute pour toute question d'orientation.">${escapeHtml(insp.messageAccueil||'')}</textarea>
      </div>
      <button class="esp-btn esp-btn-primary" style="margin-top:8px;" onclick="espInspecteurSaveMessageAccueil()">Enregistrer</button>
      <div id="esp-insp-message-accueil-msg"></div>
    </div>
    <div class="esp-card">
      <div class="esp-title" style="font-size:15px;">🛡️ Certification</div>
      ${insp.certifie ? `
        <p class="esp-sub" style="margin:0;">Ton compte est certifié <span class="esp-badge-certifie">✅</span></p>
      ` : insp.certificationDemandee ? `
        <p class="esp-sub" style="margin:0;">Demande envoyée, en attente de validation par l'administrateur.</p>
      ` : `
        <p class="esp-sub" style="margin:0 0 10px;">Un compte certifié affiche un badge ✅ visible par tous dans la discussion.</p>
        <button class="esp-btn esp-btn-primary" onclick="espInspecteurRequestCertification()">Demander la certification</button>
      `}
      <div id="esp-insp-certif-msg"></div>
    </div>
    <div class="esp-card">
      <a class="esp-btn esp-btn-primary" href="eleves.html">👥 Voir les élèves inscrits</a>
    </div>
    <div class="esp-subtabs">
      <button class="esp-subtab-btn ${sub==='chat'?'active':''}" onclick="espRenderInspecteurDashboard('chat')">💬 Discussion (${(db.messages||[]).length})</button>
    </div>
    ${subHtml}
  `;

  if(sub === 'chat'){
    const list = document.getElementById('esp-chat-list');
    if(list) list.scrollTop = list.scrollHeight;
    espUpdateReplyPreview();
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
  await espLoadFromSupabase();
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
    msgEl.innerHTML = '<p class="esp-sub" style="margin:6px 0 0;color:var(--green-dark);">Message enregistré ✅</p>';
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
