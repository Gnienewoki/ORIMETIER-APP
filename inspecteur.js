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
  sub = sub || 'eleves';
  const session = espSession();
  const db = espDB();
  const insp = db.inspecteurs.find(i => i.id === session.id);
  if(!insp){ espInspecteurLogout(); return; }

  let subHtml = '';
  if(sub === 'eleves'){
    subHtml = `
      <div class="esp-card">
        <div class="esp-title" style="font-size:16px;">Élèves inscrits sur la plateforme</div>
        <p class="esp-sub">Retrouvez ici les élèves ayant créé un compte et consultez leur profil d'orientation RIASEC pour les accompagner.</p>
        <table class="esp-table">
          <thead><tr><th>Nom</th><th>Classe</th><th>Établissement</th><th>Test RIASEC</th><th></th></tr></thead>
          <tbody>
          ${db.eleves.length ? db.eleves.map(e => `
            <tr>
              <td><b>${escapeHtml(e.nom)} ${escapeHtml(e.prenoms||'')}</b></td>
              <td>${escapeHtml(e.classe)}</td>
              <td>${escapeHtml(e.etablissement)}</td>
              <td>${e.riasec ? `<span class="esp-badge valide">${e.riasec.hollandCode}</span>` : `<span class="esp-badge en_attente">Non passé</span>`}</td>
              <td><button class="esp-btn" style="padding:5px 12px;font-size:12px;" onclick="espInspecteurViewEleve('${e.id}')">Voir le profil</button></td>
            </tr>
          `).join('') : `<tr><td colspan="5" class="esp-empty">Aucun élève inscrit pour le moment.</td></tr>`}
          </tbody>
        </table>
      </div>
    `;
  } else if(sub === 'chat'){
    const messages = db.messages || [];
    subHtml = `
      <div class="esp-card">
        <div class="esp-title" style="font-size:16px;">💬 Discussion entre inspecteurs</div>
        <p class="esp-sub">Espace d'échange partagé entre tous les inspecteurs d'orientation de la plateforme. Utilise « Important » pour signaler un problème qui nécessite une attention particulière.</p>
        <div id="esp-chat-list" class="esp-chat-list">
          ${messages.length ? messages.map(m => espChatMessageHtml(m, { mine: m.inspecteurId === insp.id, inspecteursCache: db.inspecteurs })).join('') : `<p class="esp-empty">Aucun message pour le moment. Sois le premier à écrire !</p>`}
        </div>
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
        <button class="esp-btn esp-btn-primary" onclick="espSendChatMessage()">Envoyer</button>
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
    <div class="esp-subtabs">
      <button class="esp-subtab-btn ${sub==='eleves'?'active':''}" onclick="espRenderInspecteurDashboard('eleves')">👥 Élèves</button>
      <button class="esp-subtab-btn ${sub==='chat'?'active':''}" onclick="espRenderInspecteurDashboard('chat')">💬 Discussion (${(db.messages||[]).length})</button>
    </div>
    ${subHtml}
  `;

  if(sub === 'chat'){
    const list = document.getElementById('esp-chat-list');
    if(list) list.scrollTop = list.scrollHeight;
  }
}

async function espSendChatMessage(){
  const session = espSession();
  const input = document.getElementById('esp-chat-input');
  const typeSelect = document.getElementById('esp-chat-type');
  const texte = input.value.trim();
  const type = typeSelect ? typeSelect.value : 'C';
  const errEl = document.getElementById('esp-chat-error');
  if(!texte) return;
  try {
    const ok = await espPostMessageRPC(session.id, session.password, texte, type);
    if(!ok){ errEl.innerHTML = '<p class="esp-error">Impossible d\'envoyer le message (session expirée, ou compte suspendu). Merci de te reconnecter.</p>'; return; }
  } catch(e){
    errEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(e.message) + '</p>';
    return;
  }
  input.value = '';
  await espLoadFromSupabase();
  espRenderInspecteurDashboard('chat');
}

function espInspecteurViewEleve(eleveId){
  const session = espSession();
  const db = espDB();
  const eleve = db.eleves.find(e => e.id === eleveId);
  const insp = db.inspecteurs.find(i => i.id === session.id);
  if(!eleve) return;

  const notes = db.notes.filter(n => n.eleveId === eleveId);
  const r = eleve.riasec;

  document.getElementById('esp-inspecteur').innerHTML = `
    <div class="esp-user-header">
      <span class="esp-user-name">🧭 ${escapeHtml(insp.nom)} — Profil élève</span>
      <button class="esp-btn" onclick="espRenderInspecteurDashboard()">← Retour à la liste</button>
    </div>
    <div class="esp-card">
      <div class="esp-title" style="font-size:16px;">${escapeHtml(eleve.nom)} ${escapeHtml(eleve.prenoms||'')}</div>
      <p class="esp-sub">${escapeHtml(eleve.classe)} · ${escapeHtml(eleve.etablissement)} · ${escapeHtml(eleve.tel)} · Inscrit(e) le ${escapeHtml(eleve.dateInscription)}</p>

      ${r ? `
        <div class="riasec-code-wrap" style="margin:14px 0;">
          <div class="riasec-code-letters">${r.top3.map(l => `<div class="riasec-code-letter" style="background:${RIASEC_COLORS[l]}">${l}</div>`).join('')}</div>
          <p class="riasec-code-names">${r.top3.map(l => RIASEC_DIMENSIONS.find(d=>d.letter===l).name).join(' · ')} — Code ${r.hollandCode} (réalisé le ${new Date(r.date).toLocaleDateString('fr-FR')})</p>
        </div>
        <div style="margin:10px 0 16px;">${r.scored.map(s => `
          <div class="riasec-bar-row">
            <span class="riasec-bar-label">${s.letter} — ${s.name}</span>
            <span class="riasec-bar-track"><span class="riasec-bar-fill" style="width:${s.pct}%;background:${RIASEC_COLORS[s.letter]}"></span></span>
            <span class="riasec-bar-pct">${s.pct}%</span>
          </div>
        `).join('')}</div>
      ` : `<p class="esp-empty">Cet élève n'a pas encore réalisé (ou sauvegardé) son test d'orientation RIASEC.</p>`}

      <div class="esp-title" style="font-size:15px;margin-top:20px;">Notes et recommandations</div>
      ${notes.length ? notes.map(n => `
        <div class="esp-note-item">${escapeHtml(n.texte)}<small>${escapeHtml(n.inspecteurNom)} — ${escapeHtml(n.date)}</small></div>
      `).join('') : `<p class="esp-empty">Aucune note pour le moment.</p>`}

      <div class="esp-field" style="margin-top:12px;">
        <label>Ajouter une note / recommandation</label>
        <textarea id="esp-insp-note-text" placeholder="Ex : orienter vers la filière Électrotechnique compte tenu du profil Réaliste dominant..."></textarea>
      </div>
      <button class="esp-btn esp-btn-primary" onclick="espInspecteurAddNote('${eleveId}')">Ajouter la note</button>
    </div>
  `;
}
async function espInspecteurAddNote(eleveId){
  const session = espSession();
  const db = espDB();
  const insp = db.inspecteurs.find(i => i.id === session.id);
  const texte = document.getElementById('esp-insp-note-text').value.trim();
  if(!texte) return;
  let ok;
  try {
    ok = await espAddNoteRPC(insp.id, session.password, eleveId, texte);
  } catch(e){
    alert("Erreur lors de l'ajout de la note : " + e.message);
    return;
  }
  if(!ok){ alert("Session expirée, merci de te reconnecter."); platformLogout(); return; }
  db.notes.push({ id:espUid(), eleveId, inspecteurId:insp.id, inspecteurNom: insp.nom + ' ' + (insp.prenoms||''), texte, date:espDate() });
  espSaveDB(db);
  espInspecteurViewEleve(eleveId);
}

// ---------------- ÉLÈVE ----------------
