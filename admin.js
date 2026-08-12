
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
            <select id="esp-admin-import-categorie" onchange="espAdminImportOnCategorieChange()">
              <option value="general" ${_espImportCategorie === 'general' ? 'selected' : ''}>Enseignement Général</option>
              <option value="technique" ${_espImportCategorie === 'technique' ? 'selected' : ''}>Enseignement Technique privé</option>
              <option value="superieur" ${_espImportCategorie === 'superieur' ? 'selected' : ''}>Enseignement Supérieur privé</option>
            </select>
          </div>
          <div class="esp-field" id="esp-admin-import-souscat-field" style="display:${_espImportCategorie === 'superieur' ? '' : 'none'};">
            <label>Sous-catégorie</label>
            <select id="esp-admin-import-sous-categorie" onchange="espAdminImportOnSousCategorieChange()">
              <option value="universite" ${_espImportSousCategorie === 'universite' ? 'selected' : ''}>Université</option>
              <option value="grande_ecole" ${_espImportSousCategorie === 'grande_ecole' ? 'selected' : ''}>Grande école</option>
            </select>
          </div>
        </div>
        <textarea id="esp-admin-import-etab-textarea" rows="6" style="width:100%;font-family:monospace;font-size:12.5px;padding:8px;border-radius:6px;border:1px solid var(--border);" placeholder="Lycée Moderne 1 Bouaké;Vallée du Bandama;Bouaké;;public;;
Collège Sainte-Marie;Lagunes;Abidjan;Cocody;prive;;"></textarea>
        <p style="margin:10px 0;"><button class="esp-btn esp-btn-primary" onclick="espAdminImportEtab()">Importer</button> <button class="esp-btn" onclick="espAdminShowUnclaimedCodes()">🔑 Voir tous les codes non réclamés</button> <button class="esp-btn" onclick="espAdminShowAllEtabCodes()">📋 Codes établissements</button></p>
        <div id="esp-admin-unclaimed-codes">${_espUnclaimedCodesResult ? espAdminUnclaimedCodesHtml(_espUnclaimedCodesResult) : ''}</div>
        <div id="esp-admin-all-etab-codes">${_espAllEtabCodesResult ? espAdminAllEtabCodesHtml(_espAllEtabCodesResult) : ''}</div>
        <div id="esp-admin-import-etab-result">${_espLastEtabImportWarning ? `<p class="esp-error">⚠️ ${escapeHtml(_espLastEtabImportWarning)}</p>` : ''}${_espLastEtabSkipped && _espLastEtabSkipped.length ? `
          <p class="esp-error">⚠️ <b>${_espLastEtabSkipped.length}</b> ligne(s) ignorée(s) :</p>
          <div class="table-wrap"><table>
            <thead><tr><th>Nom</th><th>Ville</th><th>Secteur</th><th>Raison</th></tr></thead>
            <tbody>${_espLastEtabSkipped.map(r => `<tr><td>${escapeHtml(r.nom||'')}</td><td>${escapeHtml(r.ville||'')}</td><td>${escapeHtml(r.secteur||'')}</td><td>${escapeHtml(r.raison||'')}</td></tr>`).join('')}</tbody>
          </table></div>
        ` : ''}${_espLastEtabImportResult ? `
          <p class="sub"><b>${_espLastEtabImportResult.length}</b> établissement(s) importé(s). Transmets à chacun son code ci-dessous (courrier officiel) — il servira une seule fois à récupérer le compte. <span class="esp-toggle-link" onclick="_espLastEtabImportResult=null;_espLastEtabSkipped=null;_espLastEtabImportWarning=null;espRenderAdminDashboard('etablissements')">Fermer</span></p>
          <div class="table-wrap"><table>
            <thead><tr><th>Établissement</th><th>Ville</th><th>Secteur</th><th>Code de récupération</th></tr></thead>
            <tbody>${_espLastEtabImportResult.map(r => `<tr><td>${escapeHtml(r.nom)}</td><td>${escapeHtml(r.ville)}</td><td>${r.secteur === 'public' ? 'Public' : 'Privé'}</td><td><code>${escapeHtml(r.code_recuperation)}</code></td></tr>`).join('')}</tbody>
          </table></div>
        ` : ''}</div>
      </div>
      <div id="esp-admin-etab-section">${espAdminEtabSectionHtml(db)}</div>
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

// ---------------- Établissements : liste paginée/filtrée (évite d'injecter des milliers de lignes d'un coup) ----------------
const ESP_ETAB_PAGE_SIZE = 50;
let _espEtabPage = 1;
let _espEtabSearch = '';
let _espEtabFilterCategorie = '';
let _espEtabFilterStatut = '';
let _espEtabSearchDebounceTimer = null;

function espAdminEtabFilteredList(db){
  const nq = (_espEtabSearch||'').trim().toLowerCase();
  return db.etablissements.filter(e => {
    if(_espEtabFilterCategorie && e.categorie !== _espEtabFilterCategorie) return false;
    if(_espEtabFilterStatut && e.statut !== _espEtabFilterStatut) return false;
    if(nq){
      const hay = [e.nom, e.ville, e.quartier, e.region].filter(Boolean).join(' ').toLowerCase();
      if(!hay.includes(nq)) return false;
    }
    return true;
  });
}

function espAdminEtabRowHtml(e){
  return `
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
  `;
}

function espAdminEtabSectionHtml(db){
  const filtered = espAdminEtabFilteredList(db);
  const total = db.etablissements.length;
  const totalPages = Math.max(1, Math.ceil(filtered.length / ESP_ETAB_PAGE_SIZE));
  if(_espEtabPage > totalPages) _espEtabPage = totalPages;
  if(_espEtabPage < 1) _espEtabPage = 1;
  const startIdx = (_espEtabPage - 1) * ESP_ETAB_PAGE_SIZE;
  const pageItems = filtered.slice(startIdx, startIdx + ESP_ETAB_PAGE_SIZE);

  return `
    <div class="esp-field-row" style="margin-bottom:10px;align-items:flex-end;">
      <div class="esp-field" style="flex:2;min-width:220px;">
        <label>Rechercher</label>
        <input type="text" id="esp-admin-etab-search" placeholder="Nom, ville, quartier, région..." value="${escapeHtml(_espEtabSearch)}" oninput="espAdminEtabOnSearchInput(this.value)">
      </div>
      <div class="esp-field">
        <label>Catégorie</label>
        <select id="esp-admin-etab-filter-cat" onchange="espAdminEtabOnFilterChange()">
          <option value="">Toutes</option>
          <option value="general" ${_espEtabFilterCategorie==='general'?'selected':''}>Général</option>
          <option value="technique" ${_espEtabFilterCategorie==='technique'?'selected':''}>Technique</option>
          <option value="superieur" ${_espEtabFilterCategorie==='superieur'?'selected':''}>Supérieur</option>
        </select>
      </div>
      <div class="esp-field">
        <label>Statut</label>
        <select id="esp-admin-etab-filter-statut" onchange="espAdminEtabOnFilterChange()">
          <option value="">Tous</option>
          <option value="en_attente" ${_espEtabFilterStatut==='en_attente'?'selected':''}>En attente</option>
          <option value="valide" ${_espEtabFilterStatut==='valide'?'selected':''}>Validé</option>
          <option value="refuse" ${_espEtabFilterStatut==='refuse'?'selected':''}>Refusé</option>
        </select>
      </div>
    </div>
    <p class="esp-sub"><b>${filtered.length}</b> établissement(s) trouvé(s) sur <b>${total}</b> au total.</p>
    <table class="esp-table">
      <thead><tr><th>Établissement</th><th>Ville</th><th>Type</th><th>Catégorie</th><th>Responsable</th><th>Contact</th><th>Statut</th><th>Actions</th></tr></thead>
      <tbody>
      ${pageItems.length ? pageItems.map(espAdminEtabRowHtml).join('') : `<tr><td colspan="8" class="esp-empty">Aucun établissement ne correspond à cette recherche.</td></tr>`}
      </tbody>
    </table>
    <div class="esp-field-row" style="justify-content:center;align-items:center;gap:14px;margin-top:12px;">
      <button class="esp-btn" ${_espEtabPage<=1?'disabled':''} onclick="espAdminEtabGoToPage(${_espEtabPage-1})">← Précédent</button>
      <span class="esp-sub" style="margin:0;">Page ${_espEtabPage} / ${totalPages}</span>
      <button class="esp-btn" ${_espEtabPage>=totalPages?'disabled':''} onclick="espAdminEtabGoToPage(${_espEtabPage+1})">Suivant →</button>
    </div>
  `;
}

function espAdminRefreshEtabSection(){
  const container = document.getElementById('esp-admin-etab-section');
  if(!container) return;
  const searchInput = document.getElementById('esp-admin-etab-search');
  const hadFocus = !!(searchInput && document.activeElement === searchInput);
  const selStart = hadFocus ? searchInput.selectionStart : null;
  const selEnd = hadFocus ? searchInput.selectionEnd : null;
  const db = espDB();
  container.innerHTML = espAdminEtabSectionHtml(db);
  if(hadFocus){
    const newInput = document.getElementById('esp-admin-etab-search');
    if(newInput){
      newInput.focus();
      try { newInput.setSelectionRange(selStart, selEnd); } catch(err){}
    }
  }
}

function espAdminEtabOnSearchInput(value){
  _espEtabSearch = value;
  _espEtabPage = 1;
  if(_espEtabSearchDebounceTimer) clearTimeout(_espEtabSearchDebounceTimer);
  _espEtabSearchDebounceTimer = setTimeout(() => {
    _espEtabSearchDebounceTimer = null;
    espAdminRefreshEtabSection();
  }, 200);
}

function espAdminEtabOnFilterChange(){
  _espEtabFilterCategorie = document.getElementById('esp-admin-etab-filter-cat').value;
  _espEtabFilterStatut = document.getElementById('esp-admin-etab-filter-statut').value;
  _espEtabPage = 1;
  espAdminRefreshEtabSection();
}

function espAdminEtabGoToPage(page){
  _espEtabPage = page;
  espAdminRefreshEtabSection();
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
let _espLastEtabSkipped = null;
let _espLastEtabImportWarning = null;
let _espUnclaimedCodesResult = null;
let _espAllEtabCodesResult = null;
let _espImportCategorie = 'general';
let _espImportSousCategorie = 'universite';

function espAdminUnclaimedCodesHtml(rows){
  if(!rows.length){
    return '<p class="esp-sub" style="margin-top:10px;">Aucun code en attente pour le moment. <span class="esp-toggle-link" onclick="_espUnclaimedCodesResult=null;espRenderAdminDashboard(\'etablissements\')">Fermer</span></p>';
  }
  const catLabel = (categorie, sousCategorie) => {
    if(categorie === 'general') return 'Général';
    if(categorie === 'superieur') return sousCategorie === 'universite' ? 'Supérieur — Université' : 'Supérieur — Grande école';
    return categorie || '—';
  };
  return `
    <p class="esp-sub" style="margin-top:10px;"><b>${rows.length}</b> établissement(s) en attente de récupération. <span class="esp-toggle-link" onclick="_espUnclaimedCodesResult=null;espRenderAdminDashboard('etablissements')">Fermer</span></p>
    <div class="table-wrap"><table>
      <thead><tr><th>Établissement</th><th>Catégorie</th><th>Ville</th><th>Secteur</th><th>Inscrit le</th><th>Code</th></tr></thead>
      <tbody>${rows.map(r => `<tr><td>${escapeHtml(r.nom)}</td><td>${escapeHtml(catLabel(r.categorie, r.sous_categorie))}</td><td>${escapeHtml(r.ville)}</td><td>${r.secteur === 'public' ? 'Public' : 'Privé'}</td><td>${escapeHtml(r.date_inscription||'')}</td><td><code>${escapeHtml(r.code_recuperation)}</code></td></tr>`).join('')}</tbody>
    </table></div>
  `;
}
async function espAdminShowUnclaimedCodes(){
  const session = espSession();
  const container = document.getElementById('esp-admin-unclaimed-codes');
  container.innerHTML = '<p class="sub" style="margin-top:10px;">⏳ Chargement…</p>';
  try {
    const rows = await espAdminListUnclaimedCodesRPC(session.password);
    _espUnclaimedCodesResult = rows;
    container.innerHTML = espAdminUnclaimedCodesHtml(rows);
  } catch(err){
    container.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(err.message) + '</p>';
  }
}

// ---------------- Codes établissements (tous, réclamés ou non) + export CSV/Excel ----------------
function espAdminEtabCodesCatLabel(categorie, sousCategorie){
  if(categorie === 'general') return 'Général';
  if(categorie === 'technique') return 'Technique';
  if(categorie === 'superieur') return sousCategorie === 'universite' ? 'Supérieur — Université' : sousCategorie === 'grande_ecole' ? 'Supérieur — Grande école' : 'Supérieur';
  return categorie || '—';
}
function espAdminAllEtabCodesHtml(rows){
  if(!rows.length){
    return '<p class="esp-sub" style="margin-top:10px;">Aucun établissement pré-inscrit pour le moment. <span class="esp-toggle-link" onclick="_espAllEtabCodesResult=null;espRenderAdminDashboard(\'etablissements\')">Fermer</span></p>';
  }
  return `
    <p class="esp-sub" style="margin-top:10px;"><b>${rows.length}</b> établissement(s) pré-inscrit(s) au total. <span class="esp-toggle-link" onclick="_espAllEtabCodesResult=null;espRenderAdminDashboard('etablissements')">Fermer</span></p>
    <p style="margin:8px 0;"><button class="esp-btn" onclick="espAdminExportEtabCodesCSV()">⬇️ Exporter en CSV</button> <button class="esp-btn" onclick="espAdminExportEtabCodesExcel()">⬇️ Exporter en Excel</button></p>
    <div class="table-wrap"><table>
      <thead><tr><th>Établissement</th><th>Catégorie</th><th>Sous-catégorie</th><th>Ville</th><th>Secteur</th><th>Code</th><th>Statut</th></tr></thead>
      <tbody>${rows.map(r => `<tr><td>${escapeHtml(r.nom)}</td><td>${escapeHtml(espAdminEtabCodesCatLabel(r.categorie, r.sous_categorie))}</td><td>${escapeHtml(r.sous_categorie||'—')}</td><td>${escapeHtml(r.ville)}</td><td>${r.secteur === 'public' ? 'Public' : r.secteur === 'prive' ? 'Privé' : '—'}</td><td><code>${escapeHtml(r.code_recuperation)}</code></td><td><span class="esp-badge ${r.reclame ? 'valide' : 'non_reclame'}">${r.reclame ? 'Réclamé' : 'Non réclamé'}</span></td></tr>`).join('')}</tbody>
    </table></div>
  `;
}
async function espAdminShowAllEtabCodes(){
  const session = espSession();
  const container = document.getElementById('esp-admin-all-etab-codes');
  container.innerHTML = '<p class="sub" style="margin-top:10px;">⏳ Chargement…</p>';
  try {
    const rows = await espAdminListAllEtabCodesRPC(session.password);
    _espAllEtabCodesResult = rows;
    container.innerHTML = espAdminAllEtabCodesHtml(rows);
  } catch(err){
    container.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(err.message) + '</p>';
  }
}
// Transforme les lignes brutes RPC en objets { "En-tête FR": valeur }, utilisés
// à la fois par l'export CSV (colonnes = clés) et par l'export Excel (SheetJS
// json_to_sheet lit directement ce format).
function espAdminEtabCodesRowsForExport(rows){
  return rows.map(r => ({
    'Nom': r.nom || '',
    'Catégorie': espAdminEtabCodesCatLabel(r.categorie, r.sous_categorie),
    'Sous-catégorie': r.sous_categorie || '',
    'Ville': r.ville || '',
    'Secteur': r.secteur === 'public' ? 'Public' : r.secteur === 'prive' ? 'Privé' : '',
    'Code de récupération': r.code_recuperation || '',
    'Réclamé': r.reclame ? 'Oui' : 'Non',
    "Date d'inscription": r.date_inscription || '',
  }));
}
function espAdminEtabCodesCsvContent(rows){
  const data = espAdminEtabCodesRowsForExport(rows);
  const header = ['Nom','Catégorie','Sous-catégorie','Ville','Secteur','Code de récupération','Réclamé',"Date d'inscription"];
  const esc = v => '"' + String(v==null?'':v).replace(/"/g,'""') + '"';
  const lines = [header.map(esc).join(';')];
  data.forEach(row => lines.push(header.map(h => esc(row[h])).join(';')));
  return lines.join('\r\n');
}
function espAdminDownloadBlob(blob, filename){
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}
function espAdminExportEtabCodesCSV(){
  if(!_espAllEtabCodesResult || !_espAllEtabCodesResult.length){ alert("Aucune donnée à exporter — clique d'abord sur « 📋 Codes établissements »."); return; }
  const stamp = new Date().toISOString().slice(0,10);
  const csv = espAdminEtabCodesCsvContent(_espAllEtabCodesResult);
  // BOM UTF-8 en tête pour qu'Excel affiche correctement les accents à l'ouverture du .csv.
  espAdminDownloadBlob(new Blob([String.fromCharCode(0xFEFF) + csv], { type: 'text/csv;charset=utf-8;' }), `ORIMETIER-codes-etablissements-${stamp}.csv`);
}
// Charge SheetJS depuis le même CDN que les autres scripts tiers du projet
// (cdnjs.cloudflare.com, déjà utilisé par html2canvas/jsPDF dans test.html),
// une seule fois, pour générer un vrai .xlsx sans dépendance locale.
function espLoadScriptOnce(src){
  return new Promise((resolve, reject) => {
    if(document.querySelector(`script[src="${src}"]`)){ resolve(); return; }
    const s = document.createElement('script');
    s.src = src;
    s.onload = () => resolve();
    s.onerror = () => reject(new Error('Impossible de charger ' + src));
    document.head.appendChild(s);
  });
}
async function espAdminExportEtabCodesExcel(){
  if(!_espAllEtabCodesResult || !_espAllEtabCodesResult.length){ alert("Aucune donnée à exporter — clique d'abord sur « 📋 Codes établissements »."); return; }
  const stamp = new Date().toISOString().slice(0,10);
  try {
    if(!window.XLSX){
      await espLoadScriptOnce('https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js');
    }
    if(!window.XLSX) throw new Error('Bibliothèque Excel indisponible');
    const ws = XLSX.utils.json_to_sheet(espAdminEtabCodesRowsForExport(_espAllEtabCodesResult));
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Codes établissements');
    XLSX.writeFile(wb, `ORIMETIER-codes-etablissements-${stamp}.xlsx`);
  } catch(err){
    console.error('[esp] export Excel indisponible, repli en CSV renommé .xls', err);
    const csv = espAdminEtabCodesCsvContent(_espAllEtabCodesResult);
    espAdminDownloadBlob(new Blob([String.fromCharCode(0xFEFF) + csv], { type: 'application/vnd.ms-excel' }), `ORIMETIER-codes-etablissements-${stamp}.xls`);
  }
}

function espAdminImportOnCategorieChange(){
  _espImportCategorie = document.getElementById('esp-admin-import-categorie').value;
  const field = document.getElementById('esp-admin-import-souscat-field');
  if(field) field.style.display = _espImportCategorie === 'superieur' ? '' : 'none';
}
function espAdminImportOnSousCategorieChange(){
  _espImportSousCategorie = document.getElementById('esp-admin-import-sous-categorie').value;
}
async function espAdminImportEtab(){
  const session = espSession();
  const categorie = document.getElementById('esp-admin-import-categorie').value;
  const sousCategorie = categorie === 'superieur' ? document.getElementById('esp-admin-import-sous-categorie').value : null;
  _espImportCategorie = categorie;
  if(sousCategorie) _espImportSousCategorie = sousCategorie;
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
  if((categorie === 'superieur' || categorie === 'technique') && items.some(it => it.secteur !== 'prive')){
    resultEl.innerHTML = '<p class="esp-error">Le Supérieur et le Technique n\'ont pas d\'onglet "public" basé sur les comptes établissement (uniquement des données statiques) : toutes les lignes doivent avoir secteur = prive.</p>';
    return;
  }
  resultEl.innerHTML = '<p class="sub">⏳ Import en cours…</p>';
  const countBefore = espDB().etablissements.length;
  let rows;
  try {
    rows = await espAdminBulkImportEtabRPC(session.password, categorie, sousCategorie, items);
  } catch(err){
    resultEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(err.message) + '</p>';
    return;
  }
  await espLoadFromSupabase();
  const importedRows = rows.filter(r => r.resultat === 'importe');
  const skippedRows = rows.filter(r => r.resultat === 'ignore');
  const actuallyInserted = espDB().etablissements.length - countBefore;
  _espLastEtabImportResult = importedRows.length ? importedRows : null;
  _espLastEtabSkipped = skippedRows.length ? skippedRows : null;
  _espLastEtabImportWarning = (actuallyInserted !== importedRows.length)
    ? `Écart détecté : le serveur annonce ${importedRows.length} établissement(s) importé(s), mais ${actuallyInserted} seulement sont réellement présents en base après vérification. Ne transmets aucun code avant d'avoir compris l'écart.`
    : null;
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
