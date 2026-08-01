
// ============================================================
// ---- Espaces (Administrateur / Inspecteur / Élève / Établissement) ----
// ============================================================
const ESP_SESSION_KEY = 'GNK_ESPACES_SESSION'; // reste local : juste "qui est connecté sur CET appareil"

// ---------------- Connexion Supabase (base de données partagée) ----------------
// ⚠️ Remplace ces deux valeurs par celles de TON projet Supabase
// (Supabase > Project Settings > API > Project URL / anon public key)
const SUPABASE_URL = 'https://ltfxaxzkuyejcluoaimq.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_h7s1eQ5VX8iBU2KYTpnZ3w_xRB9Mbl7';
const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ---------------- Connexion EmailJS (envoi d'e-mails depuis le navigateur, sans serveur) ----------------
// ⚠️ Remplace ces trois valeurs par celles de TON compte EmailJS (emailjs.com)
const EMAILJS_PUBLIC_KEY = 'mqDopJTLtKzHrGnmn';
const EMAILJS_SERVICE_ID = 'service_ng3gj85';
const EMAILJS_TEMPLATE_ID = 'ffteslj';
if(window.emailjs) window.emailjs.init({ publicKey: EMAILJS_PUBLIC_KEY });

// Cache local synchronisé avec Supabase (rempli par espLoadFromSupabase())
let _espCache = null;

// ---------------- Conversion snake_case (Supabase) <-> camelCase (app) ----------------
function espRowToEleve(r){ return { id:r.id, nom:r.nom, prenoms:r.prenoms, classe:r.classe, etablissement:r.etablissement, tel:r.tel, email:r.email, password:r.password, riasec:r.riasec, active:r.active, dateInscription:r.date_inscription }; }
function espEleveToRow(e){ return { id:e.id, nom:e.nom, prenoms:e.prenoms, classe:e.classe, etablissement:e.etablissement, tel:e.tel, email:e.email, password:e.password, riasec:e.riasec, active:!!e.active, date_inscription:e.dateInscription }; }
function espRowToInspecteur(r){ return { id:r.id, nom:r.nom, prenoms:r.prenoms, fonction:r.fonction, cio:r.cio, tel:r.tel, email:r.email, password:r.password, active:r.active, dateInscription:r.date_inscription, certifie:!!r.certifie, banni:!!r.banni }; }
function espInspecteurToRow(i){ return { id:i.id, nom:i.nom, prenoms:i.prenoms, fonction:i.fonction, cio:i.cio, tel:i.tel, email:i.email, password:i.password, active:!!i.active, date_inscription:i.dateInscription }; }
function espRowToEtab(r){ return { id:r.id, nom:r.nom, ville:r.ville, type:r.type, responsable:r.responsable, tel:r.tel, email:r.email, password:r.password, statut:r.statut, active:r.active, dateInscription:r.date_inscription, filieresProposees:r.filieres_proposees||[] }; }
function espEtabToRow(e){ return { id:e.id, nom:e.nom, ville:e.ville, type:e.type, responsable:e.responsable, tel:e.tel, email:e.email, password:e.password, statut:e.statut, active:!!e.active, date_inscription:e.dateInscription, filieres_proposees:e.filieresProposees||[] }; }
function espRowToNote(r){ return { id:r.id, eleveId:r.eleve_id, inspecteurId:r.inspecteur_id, inspecteurNom:r.inspecteur_nom, texte:r.texte, date:r.date }; }
function espNoteToRow(n){ return { id:n.id, eleve_id:n.eleveId, inspecteur_id:n.inspecteurId, inspecteur_nom:n.inspecteurNom, texte:n.texte, date:n.date }; }
function espRowToMessage(r){ return { id:r.id, inspecteurId:r.inspecteur_id, inspecteurNom:r.inspecteur_nom, texte:r.texte, date:r.date, type:r.type||'C', auteurRole:r.auteur_role||'inspecteur', replyTo:r.reply_to||null }; }

// ---------------- Chargement initial depuis Supabase (jamais les mots de passe) ----------------
async function espLoadFromSupabase(){
  const [elevesRes, inspecteursRes, etabRes, notesRes, messagesRes] = await Promise.all([
    supabaseClient.from('eleves').select('id,nom,prenoms,classe,etablissement,tel,email,riasec,active,date_inscription'),
    supabaseClient.from('inspecteurs').select('id,nom,prenoms,fonction,cio,tel,email,active,date_inscription,certifie,banni'),
    supabaseClient.from('etablissements').select('id,nom,ville,type,responsable,tel,email,statut,active,date_inscription,filieres_proposees'),
    supabaseClient.from('notes').select('*'),
    supabaseClient.from('messages_inspecteurs').select('*').order('created_at', { ascending: true }),
  ]);
  [elevesRes, inspecteursRes, etabRes, notesRes, messagesRes].forEach(r => { if(r.error) throw r.error; });

  _espCache = {
    eleves: (elevesRes.data||[]).map(espRowToEleve),
    inspecteurs: (inspecteursRes.data||[]).map(espRowToInspecteur),
    etablissements: (etabRes.data||[]).map(espRowToEtab),
    notes: (notesRes.data||[]).map(espRowToNote),
    messages: (messagesRes.data||[]).map(espRowToMessage),
  };
}

// ---------------- Écoute en temps réel (mises à jour reçues par tous les utilisateurs) ----------------
function espSetupRealtime(){
  ['eleves','inspecteurs','etablissements','notes','messages_inspecteurs'].forEach(table => {
    supabaseClient
      .channel('esp-' + table)
      .on('postgres_changes', { event: '*', schema: 'public', table }, () => espScheduleRefresh())
      .subscribe();
  });
}
let _espRefreshTimer = null;
function espScheduleRefresh(){
  clearTimeout(_espRefreshTimer);
  _espRefreshTimer = setTimeout(async () => {
    try {
      await espLoadFromSupabase();
      // Ne rafraîchit l'écran que si l'utilisateur est déjà dans son espace
      // (pour ne pas perturber un formulaire de connexion en cours de saisie).
      if(espSession() && window.__espInitDone) espInit();
    } catch(e){ console.error('[esp] échec du rafraîchissement temps réel', e); }
  }, 600);
}


function espDB(){
  return _espCache || { eleves:[], inspecteurs:[], etablissements:[], notes:[], messages:[] };
}
// Reflète un changement dans le cache local (affichage immédiat), sans jamais envoyer
// le tableau complet au serveur : chaque écriture réelle passe par une fonction dédiée ci-dessous.
function espSaveDB(db){
  _espCache = db;
}

// ---------------- Inscription (création de compte) ----------------
// Autorisée directement : chaque personne ne crée que SON PROPRE compte.
async function espInsertEleve(row){
  const { error } = await supabaseClient.from('eleves').insert([row]);
  if(error){ throw error; }
}
async function espInsertInspecteur(row){
  const { error } = await supabaseClient.from('inspecteurs').insert([row]);
  if(error){ throw error; }
}
async function espInsertEtablissement(row){
  const { error } = await supabaseClient.from('etablissements').insert([row]);
  if(error){ throw error; }
}

// ---------------- Connexion (vérifiée côté serveur, mot de passe jamais renvoyé) ----------------
async function espEleveLoginRPC(tel, password){
  const { data, error } = await supabaseClient.rpc('eleve_login', { p_tel: tel, p_password: password });
  if(error) throw error;
  return (data && data[0]) || null;
}
async function espInspecteurLoginRPC(tel, password){
  const { data, error } = await supabaseClient.rpc('inspecteur_login', { p_tel: tel, p_password: password });
  if(error) throw error;
  return (data && data[0]) || null;
}
async function espEtabLoginRPC(email, password){
  const { data, error } = await supabaseClient.rpc('etablissement_login', { p_email: email, p_password: password });
  if(error) throw error;
  return (data && data[0]) || null;
}
async function espAdminLoginRPC(password){
  const { data, error } = await supabaseClient.rpc('admin_login', { p_password: password });
  if(error) throw error;
  return !!data;
}

// ---------------- Actions d'écriture sécurisées (vérifient l'identité côté serveur) ----------------
async function espSaveRiasecRPC(eleveId, password, riasec){
  const { data, error } = await supabaseClient.rpc('eleve_save_riasec', { p_id: eleveId, p_password: password, p_riasec: riasec });
  if(error) throw error;
  return !!data;
}
async function espAddNoteRPC(inspecteurId, password, eleveId, texte){
  const { data, error } = await supabaseClient.rpc('inspecteur_add_note', { p_inspecteur_id: inspecteurId, p_password: password, p_eleve_id: eleveId, p_texte: texte });
  if(error) throw error;
  return !!data;
}
async function espPostMessageRPC(inspecteurId, password, texte, type, replyTo){
  const { data, error } = await supabaseClient.rpc('inspecteur_post_message', { p_inspecteur_id: inspecteurId, p_password: password, p_texte: texte, p_type: type || 'C', p_reply_to: replyTo || null });
  if(error) throw error;
  return !!data;
}
async function espAdminPostMessageRPC(adminPassword, texte, type, replyTo){
  const { data, error } = await supabaseClient.rpc('admin_post_message', { p_admin_password: adminPassword, p_texte: texte, p_type: type || 'O', p_reply_to: replyTo || null });
  if(error) throw error;
  return !!data;
}
async function espAdminDeleteMessageRPC(adminPassword, messageId){
  const { data, error } = await supabaseClient.rpc('admin_delete_message', { p_admin_password: adminPassword, p_message_id: messageId });
  if(error) throw error;
  return !!data;
}
async function espAdminSetInspecteurBanniRPC(adminPassword, inspecteurId, banni){
  const { data, error } = await supabaseClient.rpc('admin_set_inspecteur_banni', { p_admin_password: adminPassword, p_inspecteur_id: inspecteurId, p_banni: banni });
  if(error) throw error;
  return !!data;
}
async function espAdminSetInspecteurCertifieRPC(adminPassword, inspecteurId, certifie){
  const { data, error } = await supabaseClient.rpc('admin_set_inspecteur_certifie', { p_admin_password: adminPassword, p_inspecteur_id: inspecteurId, p_certifie: certifie });
  if(error) throw error;
  return !!data;
}

// Génère le HTML d'une bulle de message (réutilisé par l'espace Inspecteur et l'espace Admin)
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
  return `
    <div class="esp-chat-msg ${opts.mine ? 'esp-chat-msg-mine' : ''} ${isAdminMsg ? 'esp-chat-msg-admin' : ''} ${typeClass}">
      <div class="esp-chat-msg-author">
        ${isAdminMsg ? '🛠️ ' : ''}${escapeHtml(m.inspecteurNom)}${certifie ? ' <span class="esp-badge-certifie" title="Compte certifié par l\'administration">✅</span>' : ''}
        ${typeLabel ? `<span class="esp-chat-type-label">${typeLabel}</span>` : ''}
        <span class="esp-chat-msg-date">${escapeHtml(m.date)}</span>
        ${opts.canDelete ? `<span class="esp-chat-delete" onclick="${opts.deleteHandler}('${m.id}')" title="Supprimer ce message">🗑️</span>` : ''}
      </div>
      ${citedHtml}
      <div class="esp-chat-msg-text">${escapeHtml(m.texte)}</div>
      ${opts.replyHandler ? `<div class="esp-chat-reply-link" onclick="${opts.replyHandler}('${m.id}')">↩️ Répondre</div>` : ''}
    </div>
  `;
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
async function espProposeFiliereRPC(etabId, password, nom, diplome, conditions){
  const { data, error } = await supabaseClient.rpc('etablissement_propose_filiere', { p_etab_id: etabId, p_password: password, p_nom: nom, p_diplome: diplome, p_conditions: conditions });
  if(error) throw error;
  return !!data;
}
async function espSetEtabStatutRPC(adminPassword, etabId, statut){
  const { data, error } = await supabaseClient.rpc('admin_set_etab_statut', { p_admin_password: adminPassword, p_etab_id: etabId, p_statut: statut });
  if(error) throw error;
  return !!data;
}
async function espSetFiliereStatutRPC(adminPassword, etabId, filiereId, statut){
  const { data, error } = await supabaseClient.rpc('admin_set_filiere_statut', { p_admin_password: adminPassword, p_etab_id: etabId, p_filiere_id: filiereId, p_statut: statut });
  if(error) throw error;
  return !!data;
}
async function espRestoreBackupRPC(adminPassword, payload){
  const { data, error } = await supabaseClient.rpc('admin_restore_backup', { p_admin_password: adminPassword, p_payload: payload });
  if(error) throw error;
  return !!data;
}

async function espUpdateEleveEmailRPC(id, password, email){
  const { data, error } = await supabaseClient.rpc('eleve_update_email', { p_id: id, p_password: password, p_email: email });
  if(error) throw error;
  return !!data;
}
async function espUpdateInspecteurEmailRPC(id, password, email){
  const { data, error } = await supabaseClient.rpc('inspecteur_update_email', { p_id: id, p_password: password, p_email: email });
  if(error) throw error;
  return !!data;
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
async function espRequestPasswordResetRPC(role, email){
  const { data, error } = await supabaseClient.rpc('request_password_reset', { p_role: role, p_email: email });
  if(error) throw error;
  return (data && data[0]) || null;
}
async function espResetPasswordWithTokenRPC(token, newPassword){
  const { data, error } = await supabaseClient.rpc('reset_password_with_token', { p_token: token, p_new_password: newPassword });
  if(error) throw error;
  return !!data;
}
async function espSendResetEmail(toEmail, resetLink){
  if(!window.emailjs){ throw new Error("Le service d'envoi d'e-mail n'est pas disponible."); }
  await window.emailjs.send(EMAILJS_SERVICE_ID, EMAILJS_TEMPLATE_ID, {
    to_email: toEmail,
    reset_link: resetLink,
  });
}

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

function espUid(){ return 'id' + Date.now().toString(36) + Math.random().toString(36).slice(2,8); }

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
function espDate(){ return new Date().toLocaleDateString('fr-FR', {day:'2-digit', month:'2-digit', year:'numeric'}); }

function espSession(){
  try { return JSON.parse(localStorage.getItem(ESP_SESSION_KEY) || 'null'); } catch(e){ return null; }
}
function espSetSession(role, id, password){
  try { localStorage.setItem(ESP_SESSION_KEY, JSON.stringify({role, id, password: password || null})); } catch(e){}
}
function espClearSession(){
  try { localStorage.removeItem(ESP_SESSION_KEY); } catch(e){}
}

function espHideAll(){
  ['esp-role-select','esp-admin','esp-inspecteur','esp-eleve','esp-etablissement'].forEach(id => {
    document.getElementById(id).style.display = 'none';
  });
}

// ---------------- Verrou d'accès à la plateforme (inscription/connexion obligatoire) ----------------
function espAccountStillExists(session){
  if(!session) return false;
  if(session.role === 'admin') return true;
  const db = espDB();
  if(session.role === 'inspecteur') return db.inspecteurs.some(i => i.id === session.id);
  if(session.role === 'eleve') return db.eleves.some(e => e.id === session.id);
  if(session.role === 'etablissement') return db.etablissements.some(e => e.id === session.id);
  return false;
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
  if(!bar || !session){ if(bar) bar.innerHTML = ''; return; }
  const u = espCurrentUserLabel(session);
  bar.innerHTML = `
    <span>Connecté(e) : <span class="auth-bar-name">${escapeHtml(u.nom || u.role)}</span> · ${escapeHtml(u.role)}</span>
    <button class="auth-bar-logout" onclick="platformLogout()">Déconnexion</button>
  `;
  const tabEsp = document.getElementById('tab-espaces');
  if(tabEsp) tabEsp.textContent = '👤 Mon espace';
}

function platformUnlock(){
  const gate = document.getElementById('auth-gate');
  const wrap = document.getElementById('platform-wrap');
  const viewEspaces = document.getElementById('view-espaces');
  if(!wrap.contains(viewEspaces)) wrap.appendChild(viewEspaces);
  gate.style.display = 'none';
  wrap.style.display = '';
  updateAuthBar();
  showView('espaces');
  espInit();
  window.__espInitDone = true;
}

function platformLock(){
  const gate = document.getElementById('auth-gate');
  const wrap = document.getElementById('platform-wrap');
  const gateContent = document.getElementById('gate-content');
  const viewEspaces = document.getElementById('view-espaces');
  if(!gateContent.contains(viewEspaces)) gateContent.appendChild(viewEspaces);
  viewEspaces.style.display = '';
  wrap.style.display = 'none';
  gate.style.display = 'flex';
  const bar = document.getElementById('auth-bar');
  if(bar) bar.innerHTML = '';
  espShowRoleSelect();
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
  } else {
    espClearSession();
    platformLock();
  }
}

function espInit(){
  const session = espSession();
  if(session && session.role === 'admin'){ espHideAll(); document.getElementById('esp-admin').style.display=''; espRenderAdminDashboard('overview'); return; }
  if(session && session.role === 'inspecteur'){ espHideAll(); document.getElementById('esp-inspecteur').style.display=''; espRenderInspecteurDashboard(); return; }
  if(session && session.role === 'eleve'){ espHideAll(); document.getElementById('esp-eleve').style.display=''; espRenderEleveDashboard(); return; }
  if(session && session.role === 'etablissement'){ espHideAll(); document.getElementById('esp-etablissement').style.display=''; espRenderEtabDashboard(); return; }
  espShowRoleSelect();
}

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
        <div class="esp-role-title">Élève</div>
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

function espSelectRole(role){
  espHideAll();
  document.getElementById('esp-' + role).style.display = '';
  if(role === 'admin') espRenderAdminLogin();
  if(role === 'inspecteur') espRenderInspecteurAuth('login');
  if(role === 'eleve') espRenderEleveAuth('login');
  if(role === 'etablissement') espRenderEtabAuth('login');
}

function espBackToRoleSelect(){ espShowRoleSelect(); }
