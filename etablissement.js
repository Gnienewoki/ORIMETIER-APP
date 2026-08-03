function espRenderEtabAuth(mode){
  const isLogin = mode === 'login';
  document.getElementById('esp-etablissement').innerHTML = `
    <button class="esp-back" onclick="espBackToRoleSelect()">← Retour</button>
    <div class="esp-card" style="max-width:560px;margin:0 auto;">
      <div class="esp-title">🏫 Espace Établissement</div>
      <p class="esp-sub">${isLogin ? "Connectez-vous avec l'e-mail et le mot de passe de votre établissement." : "Inscrivez votre établissement. L'inscription sera examinée par l'administrateur de la plateforme."}</p>
      <div id="esp-etab-error"></div>
      ${isLogin ? `
        <div class="esp-field" style="margin-bottom:12px;"><label>E-mail</label><input type="email" id="esp-etab-email" placeholder="contact@etablissement.ci"></div>
        <div class="esp-field" style="margin-bottom:8px;"><label>Mot de passe</label><input type="password" id="esp-etab-pass" onkeydown="if(event.key==='Enter')espEtabLogin()"></div>
        <p style="margin:0 0 14px;font-size:12.5px;"><span class="esp-toggle-link" onclick="espRenderForgotPassword('etablissement','esp-etablissement', () => espRenderEtabAuth('login'))">Mot de passe oublié ?</span></p>
        <button class="esp-btn esp-btn-primary" onclick="espEtabLogin()">Se connecter</button>
        <p style="margin-top:14px;font-size:13px;">Pas encore inscrit ? <span class="esp-toggle-link" onclick="espRenderEtabAuth('register')">Inscrire mon établissement</span></p>
      ` : `
        <div class="esp-field-row">
          <div class="esp-field"><label>Nom de l'établissement</label><input type="text" id="esp-etab-nom"></div>
          <div class="esp-field"><label>Type d'établissement</label>
            <select id="esp-etab-type">
              <option>Secondaire générale</option>
              <option>Secondaire formation professionnelle et technique</option>
              <option>Supérieure</option>
            </select>
          </div>
        </div>
        <div class="esp-field-row">
          <div class="esp-field"><label>Région</label>
            <select id="esp-etab-region" onchange="espEtabUpdateVilleOptions()">
              ${espRegionsListe().map(r => `<option value="${escapeHtml(r)}">${escapeHtml(r)}</option>`).join('')}
            </select>
          </div>
          <div class="esp-field"><label>Ville</label>
            <select id="esp-etab-ville" onchange="espEtabToggleVilleAutre()"></select>
          </div>
        </div>
        <div class="esp-field-row" id="esp-etab-ville-autre-row" style="display:none;">
          <div class="esp-field"><label>Précisez la ville</label><input type="text" id="esp-etab-ville-autre"></div>
        </div>
        <div class="esp-field-row">
          <div class="esp-field"><label>Quartier</label><input type="text" id="esp-etab-quartier" placeholder="Facultatif"></div>
          <div class="esp-field"><label>Nom du responsable</label><input type="text" id="esp-etab-resp"></div>
        </div>
        <div class="esp-field-row">
          <div class="esp-field"><label>Téléphone</label><input type="tel" id="esp-etab-tel"></div>
          <div class="esp-field"><label>E-mail</label><input type="email" id="esp-etab-email2"></div>
        </div>
        <div class="esp-field" style="margin-bottom:14px;"><label>Mot de passe</label><input type="password" id="esp-etab-pass2"></div>
        <div class="esp-field" style="margin-bottom:8px;">
          <label>Filières proposées (jusqu'à 10, avec diplôme préparé)</label>
        </div>
        <div id="esp-etab-filieres-rows"></div>
        <p style="margin:6px 0 14px;">
          <button type="button" class="esp-btn" id="esp-etab-add-filiere-btn" onclick="espEtabAddFiliereRow()">+ Ajouter une filière</button>
        </p>
        <button class="esp-btn esp-btn-primary" onclick="espEtabRegister()">Soumettre l'inscription</button>
        <p style="margin-top:14px;font-size:13px;">Déjà inscrit ? <span class="esp-toggle-link" onclick="espRenderEtabAuth('login')">Se connecter</span></p>
      `}
    </div>
  `;
  if(!isLogin){
    _espEtabFiliereRowCount = 0;
    document.getElementById('esp-etab-filieres-rows').innerHTML = '';
    espEtabAddFiliereRow();
    espEtabAddFiliereRow();
    espEtabAddFiliereRow();
    espEtabUpdateVilleOptions();
  }
}

// ---------------- Région / Ville (Ville dépend de la Région choisie, + option "Autre") ----------------
function espEtabUpdateVilleOptions(){
  const regionSelect = document.getElementById('esp-etab-region');
  const villeSelect = document.getElementById('esp-etab-ville');
  if(!regionSelect || !villeSelect) return;
  const villes = espVillesPourRegion(regionSelect.value);
  villeSelect.innerHTML = villes.map(v => `<option value="${escapeHtml(v)}">${escapeHtml(v)}</option>`).join('')
    + '<option value="__autre__">Autre (préciser)</option>';
  espEtabToggleVilleAutre();
}
function espEtabToggleVilleAutre(){
  const villeSelect = document.getElementById('esp-etab-ville');
  const row = document.getElementById('esp-etab-ville-autre-row');
  if(!villeSelect || !row) return;
  row.style.display = villeSelect.value === '__autre__' ? '' : 'none';
}

// ---------------- Filières proposées dès l'inscription (jusqu'à 10, nom + diplôme préparé) ----------------
let _espEtabFiliereRowCount = 0;
function espEtabAddFiliereRow(){
  if(_espEtabFiliereRowCount >= 10) return;
  _espEtabFiliereRowCount++;
  const idx = _espEtabFiliereRowCount;
  const container = document.getElementById('esp-etab-filieres-rows');
  const row = document.createElement('div');
  row.className = 'esp-field-row esp-etab-filiere-row';
  row.id = 'esp-etab-filiere-row-' + idx;
  row.innerHTML = `
    <div class="esp-field"><input type="text" class="esp-etab-filiere-nom" placeholder="Nom de la filière"></div>
    <div class="esp-field"><input type="text" class="esp-etab-filiere-diplome" placeholder="Diplôme préparé (Ex : CAP, BT, BTS, Licence...)"></div>
    <button type="button" class="esp-btn" style="padding:4px 10px;font-size:12px;align-self:center;" onclick="espEtabRemoveFiliereRow(${idx})" title="Retirer cette filière">✕</button>
  `;
  container.appendChild(row);
  const addBtn = document.getElementById('esp-etab-add-filiere-btn');
  if(addBtn) addBtn.style.display = _espEtabFiliereRowCount >= 10 ? 'none' : '';
}
function espEtabRemoveFiliereRow(idx){
  const row = document.getElementById('esp-etab-filiere-row-' + idx);
  if(row) row.remove();
  const addBtn = document.getElementById('esp-etab-add-filiere-btn');
  if(addBtn) addBtn.style.display = '';
}
async function espEtabRegister(){
  const nom = document.getElementById('esp-etab-nom').value.trim();
  const region = document.getElementById('esp-etab-region').value;
  const villeSelect = document.getElementById('esp-etab-ville');
  const ville = villeSelect.value === '__autre__' ? document.getElementById('esp-etab-ville-autre').value.trim() : villeSelect.value;
  const quartier = document.getElementById('esp-etab-quartier').value.trim();
  const type = document.getElementById('esp-etab-type').value;
  const responsable = document.getElementById('esp-etab-resp').value.trim();
  const tel = document.getElementById('esp-etab-tel').value.trim();
  const email = document.getElementById('esp-etab-email2').value.trim();
  const pass = document.getElementById('esp-etab-pass2').value;
  if(!nom || !ville || !email || !pass){
    document.getElementById('esp-etab-error').innerHTML = "<p class=\"esp-error\">Nom de l'établissement, ville, e-mail et mot de passe sont obligatoires.</p>";
    return;
  }
  const db = espDB();
  if(db.etablissements.some(e => e.email === email)){
    document.getElementById('esp-etab-error').innerHTML = '<p class="esp-error">Un établissement est déjà inscrit avec cet e-mail.</p>';
    return;
  }
  const filieresProposees = [];
  document.querySelectorAll('#esp-etab-filieres-rows .esp-etab-filiere-row').forEach(row => {
    const fnom = row.querySelector('.esp-etab-filiere-nom').value.trim();
    const fdiplome = row.querySelector('.esp-etab-filiere-diplome').value.trim();
    if(fnom && fdiplome){
      filieresProposees.push({ id: espUid(), nom: fnom, diplome: fdiplome, conditions: '', statut: 'en_attente', date: espDate() });
    }
  });
  const id = espUid();
  const nouvelEtab = { id, nom, region, ville, quartier, type, responsable, tel, email, password:pass, statut:'en_attente', active:true, dateInscription:espDate(), filieresProposees };
  try {
    await espInsertEtablissement(espEtabToRow(nouvelEtab));
  } catch(e){
    document.getElementById('esp-etab-error').innerHTML = '<p class="esp-error">Erreur lors de l\'inscription : ' + escapeHtml(e.message) + '</p>';
    return;
  }
  db.etablissements.push(nouvelEtab);
  espSaveDB(db);
  espSetSession('etablissement', id, pass);
  platformUnlock();
}
async function espEtabLogin(){
  const email = document.getElementById('esp-etab-email').value.trim();
  const pass = document.getElementById('esp-etab-pass').value;
  let etab;
  try {
    etab = await espEtabLoginRPC(email, pass);
  } catch(e){
    document.getElementById('esp-etab-error').innerHTML = '<p class="esp-error">Erreur de connexion : ' + escapeHtml(e.message) + '</p>';
    return;
  }
  if(!etab){
    document.getElementById('esp-etab-error').innerHTML = '<p class="esp-error">E-mail ou mot de passe incorrect.</p>';
    return;
  }
  espSetSession('etablissement', etab.id, pass);
  platformUnlock();
}
function espEtabLogout(){ platformLogout(); }

function espRenderEtabDashboard(){
  const session = espSession();
  const db = espDB();
  const etab = db.etablissements.find(e => e.id === session.id);
  if(!etab){ espEtabLogout(); return; }

  const statutLabel = etab.statut === 'en_attente' ? 'En attente de validation' : etab.statut === 'valide' ? 'Validé' : 'Refusé';
  const statutMsg = etab.statut === 'en_attente'
    ? "Votre inscription, ainsi que les filières que vous avez renseignées, sont en cours d'examen par l'administrateur de la plateforme."
    : etab.statut === 'refuse'
    ? "Votre inscription n'a pas été validée. Contactez l'administrateur de la plateforme pour plus d'informations."
    : "Votre établissement est validé.";

  document.getElementById('esp-etablissement').innerHTML = `
    <div class="esp-user-header">
      <span class="esp-user-name">🏫 ${escapeHtml(etab.nom)}</span>
      <button class="esp-btn" onclick="espEtabLogout()">Déconnexion</button>
    </div>
    <div class="esp-card">
      <p><span class="esp-badge ${etab.statut}">${statutLabel}</span></p>
      <p class="esp-sub">${statutMsg}</p>
      <p class="esp-sub" style="margin-top:10px;">${[etab.ville, etab.quartier, etab.region].filter(Boolean).map(escapeHtml).join(' · ')} · ${escapeHtml(etab.type)} · Responsable : ${escapeHtml(etab.responsable)} · ${escapeHtml(etab.tel)} · ${escapeHtml(etab.email)}</p>
    </div>

    <div class="esp-card">
      <div class="esp-title" style="font-size:15px;">Localisation</div>
      <p class="esp-sub" style="margin-bottom:10px;">Utilisée pour permettre aux élèves de vous retrouver dans la recherche d'établissements.${!etab.region ? ' <b>À compléter.</b>' : ''}</p>
      <div class="esp-field-row">
        <div class="esp-field"><label>Région</label>
          <select id="esp-etab-edit-region" onchange="espEtabEditUpdateVilleOptions()">
            ${espRegionsListe().map(r => `<option value="${escapeHtml(r)}">${escapeHtml(r)}</option>`).join('')}
          </select>
        </div>
        <div class="esp-field"><label>Ville</label>
          <select id="esp-etab-edit-ville" onchange="espEtabEditToggleVilleAutre()"></select>
        </div>
      </div>
      <div class="esp-field-row" id="esp-etab-edit-ville-autre-row" style="display:none;">
        <div class="esp-field"><label>Précisez la ville</label><input type="text" id="esp-etab-edit-ville-autre"></div>
      </div>
      <div class="esp-field" style="margin-bottom:10px;"><label>Quartier</label><input type="text" id="esp-etab-edit-quartier" value="${escapeHtml(etab.quartier||'')}" placeholder="Facultatif"></div>
      <button class="esp-btn esp-btn-primary" onclick="espEtabSaveLocalisation()">Enregistrer</button>
      <div id="esp-etab-localisation-msg"></div>
    </div>

    <div class="esp-card">
      <div class="esp-title" style="font-size:15px;">Mes filières</div>
      ${(etab.filieresProposees||[]).length ? etab.filieresProposees.map(f => `
        <div class="esp-note-item" style="border-left-color:var(--green-dark);">
          <b>${escapeHtml(f.nom)}</b> (${escapeHtml(f.diplome)}) <span class="esp-badge ${f.statut}" style="margin-left:6px;">${f.statut === 'en_attente' ? 'En attente' : f.statut === 'valide' ? 'Validée' : 'Refusée'}</span>
        </div>
      `).join('') : `<p class="esp-empty">Aucune filière renseignée.</p>`}
    </div>
  `;

  const initRegion = etab.region && espRegionsListe().includes(etab.region) ? etab.region : espRegionsListe()[0];
  document.getElementById('esp-etab-edit-region').value = initRegion;
  espEtabEditUpdateVilleOptions();
  const villes = espVillesPourRegion(initRegion);
  const villeSelect = document.getElementById('esp-etab-edit-ville');
  if(etab.ville && villes.includes(etab.ville)){
    villeSelect.value = etab.ville;
  } else if(etab.ville){
    villeSelect.value = '__autre__';
    document.getElementById('esp-etab-edit-ville-autre').value = etab.ville;
    espEtabEditToggleVilleAutre();
  }
}

// ---------------- Localisation (modifiable après inscription, pour compléter les fiches existantes) ----------------
function espEtabEditUpdateVilleOptions(){
  const regionSelect = document.getElementById('esp-etab-edit-region');
  const villeSelect = document.getElementById('esp-etab-edit-ville');
  if(!regionSelect || !villeSelect) return;
  const villes = espVillesPourRegion(regionSelect.value);
  villeSelect.innerHTML = villes.map(v => `<option value="${escapeHtml(v)}">${escapeHtml(v)}</option>`).join('')
    + '<option value="__autre__">Autre (préciser)</option>';
  espEtabEditToggleVilleAutre();
}
function espEtabEditToggleVilleAutre(){
  const villeSelect = document.getElementById('esp-etab-edit-ville');
  const row = document.getElementById('esp-etab-edit-ville-autre-row');
  if(!villeSelect || !row) return;
  row.style.display = villeSelect.value === '__autre__' ? '' : 'none';
}
async function espEtabSaveLocalisation(){
  const session = espSession();
  const msgEl = document.getElementById('esp-etab-localisation-msg');
  const region = document.getElementById('esp-etab-edit-region').value;
  const villeSelect = document.getElementById('esp-etab-edit-ville');
  const ville = villeSelect.value === '__autre__' ? document.getElementById('esp-etab-edit-ville-autre').value.trim() : villeSelect.value;
  const quartier = document.getElementById('esp-etab-edit-quartier').value.trim();
  if(!ville){
    msgEl.innerHTML = '<p class="esp-error">La ville est obligatoire.</p>';
    return;
  }
  msgEl.innerHTML = '<p class="esp-sub" style="margin:6px 0 0;">Enregistrement...</p>';
  try {
    const ok = await espEtabUpdateLocalisationRPC(session.id, session.password, region, ville, quartier);
    if(!ok){ msgEl.innerHTML = '<p class="esp-error">Session expirée, merci de te reconnecter.</p>'; return; }
    const db = espDB();
    const etab = db.etablissements.find(e => e.id === session.id);
    if(etab){ etab.region = region; etab.ville = ville; etab.quartier = quartier; }
    espSaveDB(db);
    espRenderEtabDashboard();
  } catch(e){
    msgEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(e.message) + '</p>';
  }
}
