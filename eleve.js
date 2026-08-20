function espRenderEleveAuth(mode){
  const isLogin = mode === 'login';
  document.getElementById('esp-eleve').innerHTML = `
    <button class="esp-back" onclick="espBackToRoleSelect()">← Retour</button>
    <div class="esp-card" style="max-width:520px;margin:0 auto;">
      <div class="esp-title">🎓 Espace Élève</div>
      <p class="esp-sub">${isLogin ? 'Connectez-vous avec votre numéro de téléphone et votre mot de passe.' : 'Créez votre compte élève pour sauvegarder votre profil RIASEC et suivre vos recommandations.'}</p>
      <div id="esp-eleve-error"></div>
      ${isLogin ? `
        <div class="esp-field" style="margin-bottom:12px;"><label>Téléphone</label><input type="tel" id="esp-eleve-tel" placeholder="Ex : 07 00 00 00 00"></div>
        <div class="esp-field" style="margin-bottom:8px;"><label>Mot de passe</label><input type="password" id="esp-eleve-pass" onkeydown="if(event.key==='Enter')espEleveLogin()"></div>
        <p style="margin:0 0 14px;font-size:12.5px;"><span class="esp-toggle-link" onclick="espRenderForgotPassword('eleve','esp-eleve', () => espRenderEleveAuth('login'))">Mot de passe oublié ?</span></p>
        <button class="esp-btn esp-btn-primary" onclick="espEleveLogin()">Se connecter</button>
        <p style="margin-top:14px;font-size:13px;">Pas encore de compte ? <span class="esp-toggle-link" onclick="espRenderEleveAuth('register')">Créer un compte élève</span></p>
      ` : `
        <div class="esp-field-row">
          <div class="esp-field"><label>Nom</label><input type="text" id="esp-eleve-nom"></div>
          <div class="esp-field"><label>Prénoms</label><input type="text" id="esp-eleve-prenoms"></div>
        </div>
        <div class="esp-field-row">
          <div class="esp-field"><label>Classe</label><input type="text" id="esp-eleve-classe" placeholder="Ex : 3ème, Terminale D"></div>
          <div class="esp-field"><label>Établissement</label><input type="text" id="esp-eleve-etab" placeholder="Nom de l'établissement"></div>
        </div>
        <div class="esp-field-row">
          <div class="esp-field"><label>Téléphone</label><input type="tel" id="esp-eleve-tel2" placeholder="Ex : 07 00 00 00 00"></div>
          <div class="esp-field"><label>Mot de passe</label><input type="password" id="esp-eleve-pass2"></div>
        </div>
        <div class="esp-field" style="margin-bottom:12px;"><label>E-mail</label><input type="email" id="esp-eleve-email2" placeholder="Pour récupérer ton mot de passe en cas d'oubli"></div>
        <button class="esp-btn esp-btn-primary" onclick="espEleveRegister()">Créer mon compte</button>
        <p style="margin-top:14px;font-size:13px;">Déjà inscrit(e) ? <span class="esp-toggle-link" onclick="espRenderEleveAuth('login')">Se connecter</span></p>
      `}
    </div>
  `;
}
async function espEleveRegister(){
  const nom = document.getElementById('esp-eleve-nom').value.trim();
  const prenoms = document.getElementById('esp-eleve-prenoms').value.trim();
  const classe = document.getElementById('esp-eleve-classe').value.trim();
  const etablissement = document.getElementById('esp-eleve-etab').value.trim();
  const tel = document.getElementById('esp-eleve-tel2').value.trim();
  const pass = document.getElementById('esp-eleve-pass2').value;
  const email = document.getElementById('esp-eleve-email2').value.trim();
  if(!nom || !tel || !pass){
    document.getElementById('esp-eleve-error').innerHTML = '<p class="esp-error">Nom, téléphone et mot de passe sont obligatoires.</p>';
    return;
  }
  const db = espDB();
  if(db.eleves.some(e => e.tel === tel)){
    document.getElementById('esp-eleve-error').innerHTML = '<p class="esp-error">Un compte existe déjà avec ce numéro de téléphone.</p>';
    return;
  }
  const id = espUid();
  const nouvelEleve = { id, nom, prenoms, classe, etablissement, tel, email, password:pass, riasec:null, active:true, dateInscription:espDate() };
  try {
    await espInsertEleve(espEleveToRow(nouvelEleve));
  } catch(e){
    document.getElementById('esp-eleve-error').innerHTML = '<p class="esp-error">Erreur lors de la création du compte : ' + escapeHtml(e.message) + '</p>';
    return;
  }
  db.eleves.push(nouvelEleve);
  espSaveDB(db);
  espSetSession('eleve', id, pass);
  platformUnlock();
}
async function espEleveLogin(){
  const tel = document.getElementById('esp-eleve-tel').value.trim();
  const pass = document.getElementById('esp-eleve-pass').value;
  let eleve;
  try {
    eleve = await espEleveLoginRPC(tel, pass);
  } catch(e){
    document.getElementById('esp-eleve-error').innerHTML = '<p class="esp-error">Erreur de connexion : ' + escapeHtml(e.message) + '</p>';
    return;
  }
  if(!eleve){
    document.getElementById('esp-eleve-error').innerHTML = '<p class="esp-error">Téléphone ou mot de passe incorrect.</p>';
    return;
  }
  if(eleve.banni){
    document.getElementById('esp-eleve-error').innerHTML = '<p class="esp-error">Ce compte a été suspendu par l\'administration. Contacte l\'administrateur de la plateforme pour plus d\'informations.</p>';
    return;
  }
  espSetSession('eleve', eleve.id, pass);
  platformUnlock();
}
function espEleveLogout(){ platformLogout(); }

function espRenderEleveDashboard(sub){
  sub = sub || 'profil';
  const session = espSession();
  const db = espDB();
  const eleve = db.eleves.find(e => e.id === session.id);
  if(!eleve){ espEleveLogout(); return; }
  const r = eleve.riasec;
  const notes = db.notes.filter(n => n.eleveId === eleve.id);

  let subHtml = '';
  if(sub === 'profil'){
    subHtml = `
      <div class="esp-card">
        <div class="esp-title" style="font-size:16px;">Mon profil d'orientation RIASEC</div>
        ${r ? `
          <div class="riasec-code-wrap" style="margin:14px 0;">
            <div class="riasec-code-letters">${r.top3.map(l => `<div class="riasec-code-letter" style="background:${RIASEC_COLORS[l]}">${l}</div>`).join('')}</div>
            <p class="riasec-code-names">${r.top3.map(l => RIASEC_DIMENSIONS.find(d=>d.letter===l).name).join(' · ')} — Code ${r.hollandCode}</p>
          </div>
          <p class="esp-sub" style="text-align:center;">Test réalisé le ${new Date(r.date).toLocaleDateString('fr-FR')}</p>
          <div style="margin:10px 0 16px;">${r.scored.map(s => `
            <div class="riasec-bar-row">
              <span class="riasec-bar-label">${s.letter} — ${s.name}</span>
              <span class="riasec-bar-track"><span class="riasec-bar-fill" style="width:${s.pct}%;background:${RIASEC_COLORS[s.letter]}"></span></span>
              <span class="riasec-bar-pct">${s.pct}%</span>
            </div>
          `).join('')}</div>
          <a class="esp-btn" href="test.html">🔁 Repasser le test</a>
        ` : `
          <p class="esp-empty">Vous n'avez pas encore de profil RIASEC sauvegardé.</p>
          <a class="esp-btn esp-btn-primary" href="test.html">🧭 Passer le test d'orientation</a>
        `}
      </div>

      <div class="esp-card">
        <div class="esp-title" style="font-size:15px;">Notes et recommandations de mon inspecteur d'orientation</div>
        ${notes.length ? notes.map(n => `
          <div class="esp-note-item">${escapeHtml(n.texte)}<small>${escapeHtml(n.inspecteurNom)} — ${escapeHtml(n.date)}</small></div>
        `).join('') : `<p class="esp-empty">Aucune note pour le moment.</p>`}
      </div>
    `;
  } else if(sub === 'etablissements'){
    subHtml = `
      <div class="esp-card">
        <div class="esp-title" style="font-size:16px;">🏫 Trouver un établissement</div>
        <p class="esp-sub">Recherche combinable par région, ville, quartier et filière proposée.</p>
        <div class="esp-field-row">
          <div class="esp-field"><label>Région</label>
            <select id="esp-eleve-etab-region" onchange="espEleveSearchEtablissements()">
              <option value="">Toutes les régions</option>
              ${espRegionsListe().map(reg => `<option value="${escapeHtml(reg)}">${escapeHtml(reg)}</option>`).join('')}
            </select>
          </div>
          <div class="esp-field"><label>Ville</label>
            <select id="esp-eleve-etab-ville" onchange="espEleveSearchEtablissements()">
              <option value="">Toutes les villes</option>
            </select>
          </div>
        </div>
        <div class="esp-field-row">
          <div class="esp-field"><label>Quartier</label><input type="text" id="esp-eleve-etab-quartier" placeholder="Ex : Cocody" oninput="espEleveSearchEtablissements()"></div>
          <div class="esp-field"><label>Filière</label><input type="text" id="esp-eleve-etab-filiere" placeholder="Ex : BAC F2" oninput="espEleveSearchEtablissements()"></div>
        </div>
        <div id="esp-eleve-etab-results" style="margin-top:14px;"></div>
      </div>
    `;
  }

  document.getElementById('esp-eleve').innerHTML = `
    <div class="esp-user-header">
      <span class="esp-user-name">🎓 ${escapeHtml(eleve.nom)} ${escapeHtml(eleve.prenoms||'')}</span>
      <button class="esp-btn" onclick="espEleveLogout()">Déconnexion</button>
    </div>
    <div class="esp-card">
      <p class="esp-sub" style="margin-bottom:0;">${escapeHtml(eleve.classe)} · ${escapeHtml(eleve.etablissement)} · ${escapeHtml(eleve.tel)}</p>
    </div>

    <div class="esp-card" id="esp-eleve-email-card">
      ${eleve.email ? `
        <p class="esp-sub" style="margin:0;">📧 E-mail de récupération : <b>${escapeHtml(eleve.email)}</b> &nbsp;<span class="esp-toggle-link" onclick="espShowEmailForm('eleve')">Modifier</span></p>
      ` : `
        <p class="esp-sub" style="margin:0 0 8px;">⚠️ Aucun e-mail enregistré — en cas de mot de passe oublié, tu ne pourras pas le réinitialiser toi-même. <span class="esp-toggle-link" onclick="espShowEmailForm('eleve')">Ajouter mon e-mail</span></p>
      `}
      <div id="esp-eleve-email-form"></div>
    </div>

    <div class="esp-subtabs">
      <button class="esp-subtab-btn ${sub==='profil'?'active':''}" onclick="espRenderEleveDashboard('profil')">🎓 Mon profil</button>
      <button class="esp-subtab-btn ${sub==='etablissements'?'active':''}" onclick="espRenderEleveDashboard('etablissements')">🏫 Trouver un établissement</button>
    </div>
    ${subHtml}
  `;

  if(sub === 'etablissements'){
    espEleveEtabPopulateVilles();
    espEleveSearchEtablissements();
  }
}

// ---------------- Recherche d'établissement (région, ville, quartier, filière combinables) ----------------
function espEleveEtabPopulateVilles(){
  const db = espDB();
  const villeSelect = document.getElementById('esp-eleve-etab-ville');
  if(!villeSelect) return;
  const villes = [...new Set((db.etablissements||[]).filter(e => e.statut === 'valide' && e.ville).map(e => e.ville))].sort((a,b) => a.localeCompare(b,'fr'));
  villeSelect.innerHTML = '<option value="">Toutes les villes</option>' + villes.map(v => `<option value="${escapeHtml(v)}">${escapeHtml(v)}</option>`).join('');
}
function espEleveSearchEtablissements(){
  const db = espDB();
  const resultsEl = document.getElementById('esp-eleve-etab-results');
  if(!resultsEl) return;
  const region = document.getElementById('esp-eleve-etab-region').value;
  const ville = document.getElementById('esp-eleve-etab-ville').value;
  const quartier = document.getElementById('esp-eleve-etab-quartier').value.trim().toLowerCase();
  const filiere = document.getElementById('esp-eleve-etab-filiere').value.trim().toLowerCase();

  const resultats = (db.etablissements||[]).filter(e => e.statut === 'valide').filter(e => {
    if(region && e.region !== region) return false;
    if(ville && e.ville !== ville) return false;
    if(quartier && !(e.quartier||'').toLowerCase().includes(quartier)) return false;
    if(filiere){
      const filieresValidees = (e.filieresProposees||[]).filter(f => f.statut === 'valide');
      if(!filieresValidees.some(f => f.nom.toLowerCase().includes(filiere))) return false;
    }
    return true;
  });

  resultsEl.innerHTML = resultats.length ? resultats.map(e => {
    const filieresValidees = (e.filieresProposees||[]).filter(f => f.statut === 'valide');
    return `
      <div class="esp-note-item" style="border-left-color:var(--green-dark);">
        <b>${espEtabNomCellHtml(e)}</b> — ${[e.ville, e.quartier, e.region].filter(Boolean).map(escapeHtml).join(' · ')}<br>
        <span class="esp-sub">${escapeHtml(e.type)} · ${espEtabContactCellHtml(e)}</span>
        ${filieresValidees.length ? `
          <div style="margin-top:6px;">
            ${filieresValidees.map(f => `<span class="esp-badge valide" style="margin:2px 4px 2px 0;">${escapeHtml(f.nom)} (${escapeHtml(f.diplome)})</span>`).join('')}
          </div>
        ` : ''}
      </div>
    `;
  }).join('') : `<p class="esp-empty">Aucun établissement ne correspond à ces critères.</p>`;
}

// ---------------- ÉTABLISSEMENT ----------------
