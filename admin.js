
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
      <div class="esp-card" style="margin-bottom:18px;">
        <div class="esp-title" style="font-size:16px;">📥 Pré-inscrire des établissements</div>
        <p class="esp-sub">Choisis la catégorie cible, puis colle une ligne par établissement au format <code>nom;region;ville;quartier;secteur;responsable;tel</code>. Seuls nom, ville et secteur sont obligatoires — mais laisse quand même le point-virgule à la place d'un champ facultatif vide (ex. <code>quartier</code> ou <code>tel</code> non connus), sinon les colonnes suivantes se décalent. secteur = <code>public</code> ou <code>prive</code>.</p>
        <div class="esp-field-row" style="margin-bottom:10px;">
          <div class="esp-field"><label>Catégorie</label>
            <select id="esp-admin-import-categorie" onchange="espAdminImportToggleSousCategorie()">
              <option value="general">Enseignement Général</option>
              <option value="superieur">Enseignement Supérieur privé</option>
            </select>
          </div>
          <div class="esp-field" id="esp-admin-import-souscat-field" style="display:none;">
            <label>Sous-catégorie</label>
            <select id="esp-admin-import-sous-categorie">
              <option value="universite">Université</option>
              <option value="grande_ecole">Grande école</option>
            </select>
          </div>
        </div>
        <textarea id="esp-admin-import-etab-textarea" rows="6" style="width:100%;font-family:monospace;font-size:12.5px;padding:8px;border-radius:6px;border:1px solid var(--border);" placeholder="Lycée Moderne 1 Bouaké;Vallée du Bandama;Bouaké;;public;;
Collège Sainte-Marie;Lagunes;Abidjan;Cocody;prive;;"></textarea>
        <p style="margin:10px 0;"><button class="esp-btn esp-btn-primary" onclick="espAdminImportEtab()">Importer</button></p>
        <div id="esp-admin-import-etab-result">${_espLastEtabImportResult ? `
          <p class="sub"><b>${_espLastEtabImportResult.length}</b> établissement(s) importé(s). Transmets à chacun son code ci-dessous (courrier officiel) — il servira une seule fois à récupérer le compte. <span class="esp-toggle-link" onclick="_espLastEtabImportResult=null;espRenderAdminDashboard('etablissements')">Fermer</span></p>
          <div class="table-wrap"><table>
            <thead><tr><th>Établissement</th><th>Ville</th><th>Secteur</th><th>Code de récupération</th></tr></thead>
            <tbody>${_espLastEtabImportResult.map(r => `<tr><td>${escapeHtml(r.nom)}</td><td>${escapeHtml(r.ville)}</td><td>${r.secteur === 'public' ? 'Public' : 'Privé'}</td><td><code>${escapeHtml(r.code_recuperation)}</code></td></tr>`).join('')}</tbody>
          </table></div>
        ` : ''}</div>
      </div>
      <table class="esp-table">
        <thead><tr><th>Établissement</th><th>Ville</th><th>Type</th><th>Catégorie</th><th>Responsable</th><th>Contact</th><th>Statut</th><th>Actions</th></tr></thead>
        <tbody>
        ${db.etablissements.length ? db.etablissements.map(e => `
          <tr>
            <td><b>${escapeHtml(e.nom)}</b></td>
            <td>${[e.ville, e.quartier, e.region].filter(Boolean).map(escapeHtml).join(' · ')}</td>
            <td>${escapeHtml(e.type)}</td>
            <td>
              <div style="font-size:11px;color:var(--muted);margin-bottom:4px;">${espEtabCategorieLabel(e)}</div>
              <select id="esp-admin-etab-cat-${e.id}" style="font-size:11px;padding:2px 4px;width:100%;margin-bottom:2px;">
                <option value="">— Catégorie —</option>
                <option value="technique" ${e.categorie==='technique'?'selected':''}>Technique</option>
                <option value="superieur" ${e.categorie==='superieur'?'selected':''}>Supérieur</option>
                <option value="general" ${e.categorie==='general'?'selected':''}>Général</option>
              </select>
              <select id="esp-admin-etab-sous-${e.id}" style="font-size:11px;padding:2px 4px;width:100%;margin-bottom:2px;">
                <option value="">— Sous-cat. —</option>
                <option value="universite" ${e.sousCategorie==='universite'?'selected':''}>Université</option>
                <option value="grande_ecole" ${e.sousCategorie==='grande_ecole'?'selected':''}>Grande école</option>
                <option value="secondaire" ${e.sousCategorie==='secondaire'?'selected':''}>Secondaire</option>
              </select>
              <select id="esp-admin-etab-sect-${e.id}" style="font-size:11px;padding:2px 4px;width:100%;margin-bottom:4px;">
                <option value="">— Secteur —</option>
                <option value="public" ${e.secteur==='public'?'selected':''}>Public</option>
                <option value="prive" ${e.secteur==='prive'?'selected':''}>Privé</option>
              </select>
              <button class="esp-btn" style="padding:3px 8px;font-size:11px;width:100%;" onclick="espAdminSaveEtabClassification('${e.id}')">✔ Enregistrer</button>
            </td>
            <td>${escapeHtml(e.responsable)}</td>
            <td>${escapeHtml(e.tel)}<br>${escapeHtml(e.email)}</td>
            <td><span class="esp-badge ${e.statut}">${e.statut === 'en_attente' ? 'En attente' : e.statut === 'valide' ? 'Validé' : 'Refusé'}</span>${e.preInscrit && !e.reclame ? '<br><span class="esp-badge non_reclame" style="margin-top:4px;">Non réclamé</span>' : ''}${e.premium ? '<br><span class="esp-badge valide" style="margin-top:4px;">⭐ Premium</span>' : ''}</td>
            <td>
              <button class="esp-btn" style="padding:5px 10px;font-size:12px;margin-bottom:4px;" onclick="espAdminToggleEtabPremium('${e.id}')">${e.premium ? '☆ Retirer Premium' : '⭐ Activer Premium'}</button><br>
              ${e.statut !== 'valide' ? `<button class="esp-btn" style="padding:5px 10px;font-size:12px;margin-bottom:4px;" onclick="espAdminSetEtabStatut('${e.id}','valide')">✔ Valider</button>` : ''}
              ${e.statut !== 'refuse' ? `<button class="esp-btn esp-btn-danger" style="padding:5px 10px;font-size:12px;margin-bottom:4px;" onclick="espAdminSetEtabStatut('${e.id}','refuse')">✕ Refuser</button>` : ''}
              <button class="esp-btn esp-btn-danger" style="padding:5px 10px;font-size:12px;" onclick="espAdminDeleteEtab('${e.id}')">🗑 Supprimer</button>
            </td>
          </tr>
          ${(e.filieresProposees||[]).length ? `<tr><td colspan="8" style="background:#fffaf3;">
            <b style="font-size:12px;">Filières proposées par cet établissement :</b>
            ${e.filieresProposees.map(f => `
              <div style="margin:6px 0;padding:8px 10px;background:#fff;border-radius:6px;border:1px solid var(--border);font-size:12.5px;">
                <b>${escapeHtml(f.nom)}</b> (${escapeHtml(f.diplome)})${f.conditions ? ' — ' + escapeHtml(f.conditions) : ''}
                <span class="esp-badge ${f.statut}" style="margin-left:8px;">${f.statut === 'en_attente' ? 'En attente' : f.statut === 'valide' ? 'Validée' : 'Refusée'}</span>
                ${f.statut === 'en_attente' ? `
                  <button class="esp-btn" style="padding:3px 8px;font-size:11px;margin-left:8px;" onclick="espAdminSetPropositionStatut('${e.id}','${f.id}','valide')">✔ Valider</button>
                  <button class="esp-btn esp-btn-danger" style="padding:3px 8px;font-size:11px;" onclick="espAdminSetPropositionStatut('${e.id}','${f.id}','refuse')">✕ Refuser</button>
                ` : ''}
              </div>
            `).join('')}
          </td></tr>` : ''}
        `).join('') : `<tr><td colspan="8" class="esp-empty">Aucun établissement inscrit pour le moment.</td></tr>`}
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
            <td><b>${escapeHtml(i.nom)} ${escapeHtml(i.prenoms||'')}</b>${i.certifie ? ' <span class="esp-badge-certifie" title="Compte certifié">✅</span>' : ''}${(!i.certifie && i.certificationDemandee) ? ' <span class="esp-badge en_attente" title="A demandé la certification">🎓 Demande</span>' : ''}</td>
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
  } else if(sub === 'ban-eleve'){
    subHtml = `
      <div class="esp-card">
        <div class="esp-title" style="font-size:16px;">🔍 Rechercher un élève à bannir</div>
        <p class="esp-sub">Recherche par nom ou numéro de téléphone. Les résultats ne s'affichent qu'après une recherche.</p>
        <div class="esp-field" style="max-width:420px;">
          <input type="text" id="esp-ban-eleve-search" placeholder="Nom ou téléphone..." oninput="espAdminSearchEleve(this.value)">
        </div>
        <div id="esp-ban-eleve-results" style="margin-top:14px;"></div>
      </div>
    `;
  } else if(sub === 'chat'){
    const messages = db.messages || [];
    subHtml = `
      <div class="esp-card">
        <div class="esp-title" style="font-size:16px;">💬 Discussion & 📣 Actualités</div>
        <p class="esp-sub">Ce fil est partagé avec tous les inspecteurs. Utilise « Officiel » pour une annonce administrative, ou « Ordinaire » pour participer aux échanges. Tu peux supprimer n'importe quel message.</p>
        <div id="esp-chat-list" class="esp-chat-list">
          ${messages.length ? messages.map(m => espChatMessageHtml(m, { inspecteursCache: db.inspecteurs, canDelete: true, deleteHandler: 'espAdminDeleteMessage', allMessages: messages, replyHandler: 'espSetReplyTarget' })).join('') : `<p class="esp-empty">Aucun message pour le moment.</p>`}
        </div>
        <div id="esp-chat-reply-preview"></div>
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
        <div style="margin:6px 0 10px;">
          <label style="font-size:12px;font-weight:700;color:var(--green-dark);">📎 Joindre une photo ou un PDF</label><br>
          <input type="file" id="esp-chat-file-input" accept="image/*,application/pdf" onchange="espChatPreviewAttachment(this)">
          <div id="esp-chat-file-preview"></div>
        </div>
        <button class="esp-btn esp-btn-primary" id="esp-chat-send-btn" onclick="espAdminSendChatMessage()">Publier</button>
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
      <button class="esp-subtab-btn ${sub==='inspecteurs'?'active':''}" onclick="espRenderAdminDashboard('inspecteurs')">Comptes inspecteurs</button>
      <button class="esp-subtab-btn ${sub==='ban-eleve'?'active':''}" onclick="espRenderAdminDashboard('ban-eleve')">🔍 Bannir un élève</button>
      <button class="esp-subtab-btn ${sub==='chat'?'active':''}" onclick="espRenderAdminDashboard('chat')">💬 Chat & Actualités${(db.messages||[]).length ? ' ('+db.messages.length+')' : ''}</button>
    </div>
    <div class="esp-card">${subHtml}</div>
  `;
  espUpdateReplyPreview();
  if(sub === 'ban-eleve') document.getElementById('esp-ban-eleve-search').focus();
}
function espAdminSearchEleve(query){
  const resultsEl = document.getElementById('esp-ban-eleve-results');
  const q = (query||'').trim();
  if(!q){ resultsEl.innerHTML = ''; return; }
  const db = espDB();
  const norm = s => (s||'').toString().toLowerCase();
  const nq = norm(q);
  const matches = db.eleves.filter(e => norm(e.nom + ' ' + (e.prenoms||'')).includes(nq) || (e.tel||'').includes(q));
  if(!matches.length){ resultsEl.innerHTML = '<p class="esp-empty">Aucun élève trouvé.</p>'; return; }
  resultsEl.innerHTML = matches.map(e => `
    <div class="esp-note-item" style="display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap;">
      <span><b>${escapeHtml(e.nom)} ${escapeHtml(e.prenoms||'')}</b> — ${escapeHtml(e.classe)} · ${escapeHtml(e.etablissement)} · ${escapeHtml(e.tel)} ${e.banni ? '<span class="esp-badge refuse">Banni</span>' : '<span class="esp-badge valide">Actif</span>'}</span>
      <button class="esp-btn" style="padding:5px 10px;font-size:11.5px;" onclick="espAdminToggleEleveBanni('${e.id}', ${!e.banni})">${e.banni ? '✅ Réactiver' : '🚫 Bannir'}</button>
    </div>
  `).join('');
}
async function espAdminToggleEleveBanni(eleveId, nouvelEtat){
  const session = espSession();
  const db = espDB();
  const e = db.eleves.find(x => x.id === eleveId);
  if(!e) return;
  if(nouvelEtat && !confirm(`Bannir ${e.nom} ${e.prenoms||''} ? Cette personne ne pourra plus se connecter.`)) return;
  let ok;
  try { ok = await espAdminSetEleveBanniRPC(session.password, eleveId, nouvelEtat); }
  catch(err){ alert('Erreur : ' + err.message); return; }
  if(!ok){ alert("Session expirée, merci de te reconnecter."); platformLogout(); return; }
  e.banni = nouvelEtat; espSaveDB(db);
  const searchInput = document.getElementById('esp-ban-eleve-search');
  if(searchInput) espAdminSearchEleve(searchInput.value);
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
  i.certifie = nouvelEtat;
  if(nouvelEtat) i.certificationDemandee = false;
  espSaveDB(db); espRenderAdminDashboard('inspecteurs');
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
  const replyTo = _espReplyTarget ? _espReplyTarget.id : null;
  const errEl = document.getElementById('esp-chat-error');
  const sendBtn = document.getElementById('esp-chat-send-btn');
  if(!texte && !_espChatPendingFile) return;
  if(sendBtn){ sendBtn.disabled = true; sendBtn.textContent = 'Envoi en cours...'; }
  try {
    const attachment = await espChatUploadPendingAttachment();
    const ok = await espAdminPostMessageRPC(session.password, texte, type, replyTo, attachment);
    if(!ok){ errEl.innerHTML = '<p class="esp-error">Impossible de publier le message. Session expirée ?</p>'; return; }
  } catch(e){
    errEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(e.message) + '</p>';
    return;
  } finally {
    if(sendBtn){ sendBtn.disabled = false; sendBtn.textContent = 'Publier'; }
  }
  input.value = '';
  espChatClearAttachment('esp-chat-file-input');
  _espReplyTarget = null;
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

async function espAdminToggleEtabPremium(id){
  const session = espSession();
  const db = espDB();
  const e = db.etablissements.find(x => x.id === id);
  if(!e) return;
  const nextPremium = !e.premium;
  if(nextPremium && !confirm(`Confirmer que "${e.nom}" a bien souscrit à l'offre premium avant d'activer cette fonctionnalité ?`)) return;
  let ok;
  try { ok = await espAdminSetEtabPremiumRPC(session.password, id, nextPremium); }
  catch(err){ alert('Erreur : ' + err.message); return; }
  if(!ok){ alert("Session expirée, merci de te reconnecter."); platformLogout(); return; }
  e.premium = nextPremium; espSaveDB(db); espRenderAdminDashboard('etablissements');
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

async function espAdminDeleteEtab(etabId){
  const session = espSession();
  const db = espDB();
  const e = db.etablissements.find(x => x.id === etabId);
  if(!e) return;
  if(!confirm(`Supprimer définitivement "${e.nom}" ? Cette action est irréversible et supprimera aussi ses filières et photos. Continuer ?`)) return;
  let ok;
  try { ok = await espAdminDeleteEtabRPC(session.password, etabId); }
  catch(err){ alert('Erreur : ' + err.message); return; }
  if(!ok){ alert("Session expirée, merci de te reconnecter."); platformLogout(); return; }
  db.etablissements = db.etablissements.filter(x => x.id !== etabId);
  espSaveDB(db);
  espRenderAdminDashboard('etablissements');
}

let _espLastEtabImportResult = null;
function espAdminImportToggleSousCategorie(){
  const cat = document.getElementById('esp-admin-import-categorie').value;
  const field = document.getElementById('esp-admin-import-souscat-field');
  if(field) field.style.display = cat === 'superieur' ? '' : 'none';
}
async function espAdminImportEtab(){
  const session = espSession();
  const categorie = document.getElementById('esp-admin-import-categorie').value;
  const sousCategorie = categorie === 'superieur' ? document.getElementById('esp-admin-import-sous-categorie').value : null;
  const textarea = document.getElementById('esp-admin-import-etab-textarea');
  const resultEl = document.getElementById('esp-admin-import-etab-result');
  const lines = (textarea.value || '').split('\n').map(l => l.trim()).filter(Boolean);
  if(!lines.length){
    resultEl.innerHTML = '<p class="esp-error">Colle au moins une ligne à importer.</p>';
    return;
  }
  const items = lines.map(line => {
    const [nom, region, ville, quartier, secteur, responsable, tel] = line.split(';').map(v => (v||'').trim());
    return { nom, region, ville, quartier, secteur, responsable, tel };
  });
  const invalides = items.filter(it => !it.nom || !it.ville || (it.secteur !== 'public' && it.secteur !== 'prive'));
  if(invalides.length){
    resultEl.innerHTML = `<p class="esp-error">${invalides.length} ligne(s) invalide(s) (nom, ville et secteur "public"/"prive" obligatoires). Corrige-les avant d'importer.</p>`;
    return;
  }
  if(categorie === 'superieur' && items.some(it => it.secteur !== 'prive')){
    resultEl.innerHTML = '<p class="esp-error">Le Supérieur n\'a pas d\'onglet "public" basé sur les comptes établissement (uniquement des données statiques) : toutes les lignes doivent avoir secteur = prive.</p>';
    return;
  }
  resultEl.innerHTML = '<p class="sub">⏳ Import en cours…</p>';
  let rows;
  try {
    rows = await espAdminBulkImportEtabRPC(session.password, categorie, sousCategorie, items);
  } catch(err){
    resultEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(err.message) + '</p>';
    return;
  }
  await espLoadFromSupabase();
  _espLastEtabImportResult = rows;
  espRenderAdminDashboard('etablissements');
}

async function espAdminSaveEtabClassification(etabId){
  const session = espSession();
  const catSelect = document.getElementById('esp-admin-etab-cat-' + etabId);
  const sousSelect = document.getElementById('esp-admin-etab-sous-' + etabId);
  const sectSelect = document.getElementById('esp-admin-etab-sect-' + etabId);
  const categorie = catSelect.value || null;
  const sousCategorie = sousSelect.value || null;
  const secteur = sectSelect.value || null;
  let ok;
  try { ok = await espAdminUpdateEtabClassificationRPC(session.password, etabId, categorie, sousCategorie, secteur); }
  catch(err){ alert('Erreur : ' + err.message); return; }
  if(!ok){ alert("Session expirée, merci de te reconnecter."); platformLogout(); return; }
  const db = espDB();
  const e = db.etablissements.find(x => x.id === etabId);
  if(e){ e.categorie = categorie; e.sousCategorie = sousCategorie; e.secteur = secteur; }
  espSaveDB(db);
  espRenderAdminDashboard('etablissements');
}

// ---------------- INSPECTEUR D'ORIENTATION ----------------
