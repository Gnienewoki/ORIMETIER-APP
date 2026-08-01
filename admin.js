
// ---------------- ADMINISTRATEUR ----------------
function espRenderAdminLogin(){
  document.getElementById('esp-admin').innerHTML = `
    <button class="esp-back" onclick="espBackToRoleSelect()">← Retour</button>
    <div class="esp-card" style="max-width:420px;margin:0 auto;">
      <div class="esp-title">🛠️ Espace Administrateur</div>
      <p class="esp-sub">Mot de passe par défaut : <b>admin2024</b> (à modifier après connexion, ou directement dans le code).</p>
      <div id="esp-admin-error"></div>
      <div class="esp-field" style="margin-bottom:14px;">
        <label>Mot de passe administrateur</label>
        <input type="password" id="esp-admin-pass" placeholder="••••••••" onkeydown="if(event.key==='Enter')espAdminLogin()">
      </div>
      <button class="esp-btn esp-btn-primary" onclick="espAdminLogin()">Se connecter</button>
    </div>
  `;
}
async function espAdminLogin(){
  const pass = document.getElementById('esp-admin-pass').value;
  let ok;
  try {
    ok = await espAdminLoginRPC(pass);
  } catch(e){
    document.getElementById('esp-admin-error').innerHTML = '<p class="esp-error">Erreur de connexion : ' + escapeHtml(e.message) + '</p>';
    return;
  }
  if(!ok){
    document.getElementById('esp-admin-error').innerHTML = '<p class="esp-error">Mot de passe incorrect.</p>';
    return;
  }
  espSetSession('admin', null, pass);
  platformUnlock();
}
function espAdminLogout(){ platformLogout(); }

function espExportBackup(){
  const db = espDB();
  const blob = new Blob([JSON.stringify({ db }, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  const stamp = new Date().toISOString().slice(0,10);
  a.download = `ORIMETIER-sauvegarde-${stamp}.json`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}

function espImportBackup(input){
  const file = input.files && input.files[0];
  if(!file) return;
  const reader = new FileReader();
  reader.onload = async (e) => {
    try {
      const parsed = JSON.parse(e.target.result);
      const imported = parsed.db ? parsed.db : parsed; // compatibilité avec anciennes sauvegardes
      if(!imported || !Array.isArray(imported.eleves) || !Array.isArray(imported.inspecteurs) || !Array.isArray(imported.etablissements)){
        alert("Ce fichier ne semble pas être une sauvegarde ORIMETIER valide.");
        return;
      }
      if(!confirm("Importer cette sauvegarde va remplacer toutes les données actuelles (comptes élèves, inspecteurs, établissements, notes). Continuer ?")) return;
      const session = espSession();
      const payload = {
        eleves: (imported.eleves||[]).map(espEleveToRow),
        inspecteurs: (imported.inspecteurs||[]).map(espInspecteurToRow),
        etablissements: (imported.etablissements||[]).map(espEtabToRow),
        notes: (imported.notes||[]).map(espNoteToRow),
      };
      const ok = await espRestoreBackupRPC(session.password, payload);
      if(!ok){ alert("Mot de passe administrateur invalide ou session expirée."); return; }
      await espLoadFromSupabase();
      alert("Sauvegarde importée avec succès.");
      espRenderAdminDashboard('overview');
    } catch(err){
      alert("Impossible de lire ce fichier : " + err.message);
    }
  };
  reader.readAsText(file);
  input.value = '';
}

function espRenderAdminDashboard(sub){
  const db = espDB();
  const enAttente = db.etablissements.filter(e => e.statut === 'en_attente').length;
  const propositionsEnAttente = db.etablissements.reduce((n,e) => n + (e.filieresProposees||[]).filter(f=>f.statut==='en_attente').length, 0);
  const eleveAvecTest = db.eleves.filter(e => e.riasec).length;

  let subHtml = '';
  if(sub === 'overview'){
    subHtml = `
      <div class="esp-stat-grid">
        <div class="esp-stat-box"><div class="esp-stat-num">${db.eleves.length}</div><div class="esp-stat-label">Comptes élèves</div></div>
        <div class="esp-stat-box"><div class="esp-stat-num">${eleveAvecTest}</div><div class="esp-stat-label">Tests RIASEC réalisés</div></div>
        <div class="esp-stat-box"><div class="esp-stat-num">${db.inspecteurs.length}</div><div class="esp-stat-label">Inspecteurs inscrits</div></div>
        <div class="esp-stat-box"><div class="esp-stat-num">${db.etablissements.length}</div><div class="esp-stat-label">Établissements inscrits</div></div>
        <div class="esp-stat-box"><div class="esp-stat-num">${enAttente}</div><div class="esp-stat-label">Inscriptions en attente</div></div>
        <div class="esp-stat-box"><div class="esp-stat-num">${propositionsEnAttente}</div><div class="esp-stat-label">Propositions de filières en attente</div></div>
      </div>
      <p class="esp-sub">Rappel des données de référence intégrées à la plateforme : <b>${DATA.length}</b> filières (Enseignement Technique et Formation Professionnelle), <b>${FICHES.length}</b> fiches métiers/filières détaillées, <b>${Object.keys(CONDITIONS_ACCES).length}</b> fiches de conditions d'accès, <b>${ccAllItems().length}</b> concours référencés (Sans BEPC / BEPC / Bac). La mise à jour de ces données de référence se fait actuellement dans le code source de la plateforme ; ce tableau de bord gère les comptes et les inscriptions créés par les utilisateurs.</p>
    `;
  } else if(sub === 'etablissements'){
    subHtml = `
      <table class="esp-table">
        <thead><tr><th>Établissement</th><th>Ville</th><th>Type</th><th>Responsable</th><th>Contact</th><th>Statut</th><th>Actions</th></tr></thead>
        <tbody>
        ${db.etablissements.length ? db.etablissements.map(e => `
          <tr>
            <td><b>${escapeHtml(e.nom)}</b></td>
            <td>${escapeHtml(e.ville)}</td>
            <td>${escapeHtml(e.type)}</td>
            <td>${escapeHtml(e.responsable)}</td>
            <td>${escapeHtml(e.tel)}<br>${escapeHtml(e.email)}</td>
            <td><span class="esp-badge ${e.statut}">${e.statut === 'en_attente' ? 'En attente' : e.statut === 'valide' ? 'Validé' : 'Refusé'}</span></td>
            <td>
              ${e.statut !== 'valide' ? `<button class="esp-btn" style="padding:5px 10px;font-size:12px;margin-bottom:4px;" onclick="espAdminSetEtabStatut('${e.id}','valide')">✔ Valider</button>` : ''}
              ${e.statut !== 'refuse' ? `<button class="esp-btn esp-btn-danger" style="padding:5px 10px;font-size:12px;" onclick="espAdminSetEtabStatut('${e.id}','refuse')">✕ Refuser</button>` : ''}
            </td>
          </tr>
          ${(e.filieresProposees||[]).length ? `<tr><td colspan="7" style="background:#fffaf3;">
            <b style="font-size:12px;">Filières proposées par cet établissement :</b>
            ${e.filieresProposees.map(f => `
              <div style="margin:6px 0;padding:8px 10px;background:#fff;border-radius:6px;border:1px solid var(--border);font-size:12.5px;">
                <b>${escapeHtml(f.nom)}</b> (${escapeHtml(f.diplome)}) — ${escapeHtml(f.conditions)}
                <span class="esp-badge ${f.statut}" style="margin-left:8px;">${f.statut === 'en_attente' ? 'En attente' : f.statut === 'valide' ? 'Validée' : 'Refusée'}</span>
                ${f.statut === 'en_attente' ? `
                  <button class="esp-btn" style="padding:3px 8px;font-size:11px;margin-left:8px;" onclick="espAdminSetPropositionStatut('${e.id}','${f.id}','valide')">✔ Valider</button>
                  <button class="esp-btn esp-btn-danger" style="padding:3px 8px;font-size:11px;" onclick="espAdminSetPropositionStatut('${e.id}','${f.id}','refuse')">✕ Refuser</button>
                ` : ''}
              </div>
            `).join('')}
          </td></tr>` : ''}
        `).join('') : `<tr><td colspan="7" class="esp-empty">Aucun établissement inscrit pour le moment.</td></tr>`}
        </tbody>
      </table>
    `;
  } else if(sub === 'eleves'){
    subHtml = `
      <table class="esp-table">
        <thead><tr><th>Nom</th><th>Classe</th><th>Établissement</th><th>Contact</th><th>Test RIASEC</th><th>Inscrit le</th></tr></thead>
        <tbody>
        ${db.eleves.length ? db.eleves.map(e => `
          <tr>
            <td><b>${escapeHtml(e.nom)} ${escapeHtml(e.prenoms||'')}</b></td>
            <td>${escapeHtml(e.classe)}</td>
            <td>${escapeHtml(e.etablissement)}</td>
            <td>${escapeHtml(e.tel)}</td>
            <td>${e.riasec ? `<span class="esp-badge valide">${e.riasec.hollandCode}</span>` : `<span class="esp-badge en_attente">Non passé</span>`}</td>
            <td>${escapeHtml(e.dateInscription)}</td>
          </tr>
        `).join('') : `<tr><td colspan="6" class="esp-empty">Aucun élève inscrit pour le moment.</td></tr>`}
        </tbody>
      </table>
    `;
  } else if(sub === 'inspecteurs'){
    subHtml = `
      <table class="esp-table">
        <thead><tr><th>Nom</th><th>Fonction</th><th>CIO / Zone</th><th>Contact</th><th>Inscrit le</th><th>Statut</th><th></th></tr></thead>
        <tbody>
        ${db.inspecteurs.length ? db.inspecteurs.map(i => `
          <tr>
            <td><b>${escapeHtml(i.nom)} ${escapeHtml(i.prenoms||'')}</b>${i.certifie ? ' <span class="esp-badge-certifie" title="Compte certifié">✅</span>' : ''}</td>
            <td>${escapeHtml(i.fonction)}</td>
            <td>${escapeHtml(i.cio)}</td>
            <td>${escapeHtml(i.tel)}</td>
            <td>${escapeHtml(i.dateInscription)}</td>
            <td>${i.banni ? '<span class="esp-badge refuse">Banni</span>' : '<span class="esp-badge valide">Actif</span>'}</td>
            <td>
              <button class="esp-btn" style="padding:5px 10px;font-size:11.5px;" onclick="espAdminToggleCertifie('${i.id}', ${!i.certifie})">${i.certifie ? 'Retirer le badge' : '🛡️ Certifier'}</button>
              <button class="esp-btn" style="padding:5px 10px;font-size:11.5px;" onclick="espAdminToggleBanni('${i.id}', ${!i.banni})">${i.banni ? '✅ Réactiver' : '🚫 Bannir'}</button>
            </td>
          </tr>
        `).join('') : `<tr><td colspan="7" class="esp-empty">Aucun inspecteur inscrit pour le moment.</td></tr>`}
        </tbody>
      </table>
    `;
  } else if(sub === 'chat'){
    const messages = db.messages || [];
    subHtml = `
      <div class="esp-card">
        <div class="esp-title" style="font-size:16px;">💬 Discussion & 📣 Actualités</div>
        <p class="esp-sub">Ce fil est partagé avec tous les inspecteurs. Utilise « Officiel » pour une annonce administrative, ou « Ordinaire » pour participer aux échanges. Tu peux supprimer n'importe quel message.</p>
        <div id="esp-chat-list" class="esp-chat-list">
          ${messages.length ? messages.map(m => espChatMessageHtml(m, { inspecteursCache: db.inspecteurs, canDelete: true, deleteHandler: 'espAdminDeleteMessage' })).join('') : `<p class="esp-empty">Aucun message pour le moment.</p>`}
        </div>
        <div id="esp-chat-error"></div>
        <div class="esp-field-row" style="margin-top:10px;align-items:flex-end;">
          <div class="esp-field" style="flex:2;">
            <label>Message</label>
            <input type="text" id="esp-chat-input" placeholder="Écrire un message..." onkeydown="if(event.key==='Enter')espAdminSendChatMessage()">
          </div>
          <div class="esp-field" style="flex:1;">
            <label>Type</label>
            <select id="esp-chat-type">
              <option value="O">📣 Officiel</option>
              <option value="C">💬 Ordinaire</option>
            </select>
          </div>
        </div>
        <button class="esp-btn esp-btn-primary" onclick="espAdminSendChatMessage()">Publier</button>
      </div>
    `;
  }

  document.getElementById('esp-admin').innerHTML = `
    <div class="esp-user-header">
      <span class="esp-user-name">🛠️ Espace Administrateur</span>
      <span>
        <button class="esp-btn" onclick="espExportBackup()">📥 Exporter une sauvegarde</button>
        <button class="esp-btn" onclick="document.getElementById('esp-import-file').click()">📤 Importer une sauvegarde</button>
        <input type="file" id="esp-import-file" accept=".json" style="display:none" onchange="espImportBackup(this)">
        <button class="esp-btn" onclick="espAdminLogout()">Déconnexion</button>
      </span>
    </div>
    <div class="esp-subtabs">
      <button class="esp-subtab-btn ${sub==='overview'?'active':''}" onclick="espRenderAdminDashboard('overview')">Vue d'ensemble</button>
      <button class="esp-subtab-btn ${sub==='etablissements'?'active':''}" onclick="espRenderAdminDashboard('etablissements')">Établissements${enAttente ? ' ('+enAttente+')' : ''}</button>
      <button class="esp-subtab-btn ${sub==='eleves'?'active':''}" onclick="espRenderAdminDashboard('eleves')">Comptes élèves</button>
      <button class="esp-subtab-btn ${sub==='inspecteurs'?'active':''}" onclick="espRenderAdminDashboard('inspecteurs')">Comptes inspecteurs</button>
      <button class="esp-subtab-btn ${sub==='chat'?'active':''}" onclick="espRenderAdminDashboard('chat')">💬 Chat & Actualités${(db.messages||[]).length ? ' ('+db.messages.length+')' : ''}</button>
    </div>
    <div class="esp-card">${subHtml}</div>
  `;
}
async function espAdminToggleCertifie(inspecteurId, nouvelEtat){
  const session = espSession();
  const db = espDB();
  const i = db.inspecteurs.find(x => x.id === inspecteurId);
  if(!i) return;
  let ok;
  try { ok = await espAdminSetInspecteurCertifieRPC(session.password, inspecteurId, nouvelEtat); }
  catch(e){ alert('Erreur : ' + e.message); return; }
  if(!ok){ alert("Session expirée, merci de te reconnecter."); platformLogout(); return; }
  i.certifie = nouvelEtat; espSaveDB(db); espRenderAdminDashboard('inspecteurs');
}
async function espAdminToggleBanni(inspecteurId, nouvelEtat){
  const session = espSession();
  const db = espDB();
  const i = db.inspecteurs.find(x => x.id === inspecteurId);
  if(!i) return;
  if(nouvelEtat && !confirm(`Bannir ${i.nom} ${i.prenoms||''} ? Cette personne ne pourra plus se connecter ni publier de messages.`)) return;
  let ok;
  try { ok = await espAdminSetInspecteurBanniRPC(session.password, inspecteurId, nouvelEtat); }
  catch(e){ alert('Erreur : ' + e.message); return; }
  if(!ok){ alert("Session expirée, merci de te reconnecter."); platformLogout(); return; }
  i.banni = nouvelEtat; espSaveDB(db); espRenderAdminDashboard('inspecteurs');
}
async function espAdminSendChatMessage(){
  const session = espSession();
  const input = document.getElementById('esp-chat-input');
  const typeSelect = document.getElementById('esp-chat-type');
  const texte = input.value.trim();
  const type = typeSelect ? typeSelect.value : 'O';
  const errEl = document.getElementById('esp-chat-error');
  if(!texte) return;
  try {
    const ok = await espAdminPostMessageRPC(session.password, texte, type);
    if(!ok){ errEl.innerHTML = '<p class="esp-error">Impossible de publier le message. Session expirée ?</p>'; return; }
  } catch(e){
    errEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(e.message) + '</p>';
    return;
  }
  input.value = '';
  await espLoadFromSupabase();
  espRenderAdminDashboard('chat');
}
async function espAdminDeleteMessage(messageId){
  if(!confirm('Supprimer définitivement ce message ?')) return;
  const session = espSession();
  try {
    const ok = await espAdminDeleteMessageRPC(session.password, messageId);
    if(!ok){ alert("Impossible de supprimer ce message."); return; }
  } catch(e){
    alert('Erreur : ' + e.message);
    return;
  }
  await espLoadFromSupabase();
  espRenderAdminDashboard('chat');
}

async function espAdminSetEtabStatut(id, statut){
  const session = espSession();
  const db = espDB();
  const e = db.etablissements.find(x => x.id === id);
  if(!e) return;
  let ok;
  try { ok = await espSetEtabStatutRPC(session.password, id, statut); }
  catch(err){ alert('Erreur : ' + err.message); return; }
  if(!ok){ alert("Session expirée, merci de te reconnecter."); platformLogout(); return; }
  e.statut = statut; espSaveDB(db); espRenderAdminDashboard('etablissements');
}
async function espAdminSetPropositionStatut(etabId, filiereId, statut){
  const session = espSession();
  const db = espDB();
  const e = db.etablissements.find(x => x.id === etabId);
  if(!e) return;
  const f = (e.filieresProposees||[]).find(x => x.id === filiereId);
  if(!f) return;
  let ok;
  try { ok = await espSetFiliereStatutRPC(session.password, etabId, filiereId, statut); }
  catch(err){ alert('Erreur : ' + err.message); return; }
  if(!ok){ alert("Session expirée, merci de te reconnecter."); platformLogout(); return; }
  f.statut = statut; espSaveDB(db); espRenderAdminDashboard('etablissements');
}

// ---------------- INSPECTEUR D'ORIENTATION ----------------
