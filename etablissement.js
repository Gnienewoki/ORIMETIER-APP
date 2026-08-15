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
        <p style="margin-top:6px;font-size:13px;">Votre établissement a reçu un code de récupération ? <span class="esp-toggle-link" onclick="espRenderEtabClaim()">Récupérer mon compte</span></p>
      ` : `
        <div class="esp-field-row">
          <div class="esp-field"><label>Nom de l'établissement</label><input type="text" id="esp-etab-nom"></div>
          <div class="esp-field"><label>Catégorie d'enseignement</label>
            <select id="esp-etab-categorie" onchange="espEtabToggleSousCategorie()">
              <option value="technique">Enseignement technique et formation professionnelle</option>
              <option value="superieur">Enseignement supérieur</option>
              <option value="general">Enseignement général</option>
            </select>
          </div>
        </div>
        <div class="esp-field-row">
          <div class="esp-field" id="esp-etab-souscategorie-field" style="display:none;">
            <label>Sous-catégorie</label>
            <select id="esp-etab-sous-categorie">
              <option value="universite">Université</option>
              <option value="grande_ecole">Grande école</option>
            </select>
          </div>
          <div class="esp-field"><label>Secteur</label>
            <select id="esp-etab-secteur">
              <option value="public">Public</option>
              <option value="prive">Privé</option>
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
        <div class="esp-field"><label>Téléphone du responsable</label><input type="tel" id="esp-etab-resp-tel" placeholder="Optionnel — usage interne, jamais public"></div>
        <div class="esp-field-row">
          <div class="esp-field"><label>Téléphone</label><input type="tel" id="esp-etab-tel"></div>
          <div class="esp-field"><label>E-mail</label><input type="email" id="esp-etab-email2"></div>
        </div>
        <div class="esp-field-row">
          <div class="esp-field"><label>Téléphone 2</label><input type="tel" id="esp-etab-tel2" placeholder="Optionnel"></div>
          <div class="esp-field"><label>Téléphone 3</label><input type="tel" id="esp-etab-tel3" placeholder="Optionnel"></div>
        </div>
        <div class="esp-field"><label>Site web</label><input type="text" id="esp-etab-siteweb" placeholder="Optionnel"></div>
        <div class="esp-field" style="margin-bottom:14px;"><label>Mot de passe</label><input type="password" id="esp-etab-pass2"></div>
        <div class="esp-field" style="margin-bottom:8px;">
          <label>Filières proposées (jusqu'à 10, avec diplôme préparé)</label>
        </div>
        <div id="esp-etab-filieres-rows"></div>
        <p style="margin:6px 0 14px;">
          <button type="button" class="esp-btn" id="esp-etab-add-filiere-btn" onclick="espEtabAddFiliereRow()">+ Ajouter une filière</button>
        </p>
        <div class="esp-field" style="margin-bottom:8px;">
          <label id="esp-etab-photos-label">Photos de l'établissement (0/10)</label>
        </div>
        <div id="esp-etab-photos-preview" class="esp-etab-photos-grid"></div>
        <input type="file" id="esp-etab-photos-input" accept="image/*" multiple onchange="espEtabRegisterPhotosChange(this)">
        <div id="esp-etab-photos-msg"></div>
        <p style="margin:14px 0 14px;"></p>
        <button class="esp-btn esp-btn-primary" onclick="espEtabRegister()">Soumettre l'inscription</button>
        <p style="margin-top:14px;font-size:13px;">Déjà inscrit ? <span class="esp-toggle-link" onclick="espRenderEtabAuth('login')">Se connecter</span></p>
      `}
    </div>
  `;
  if(!isLogin){
    _espEtabFiliereRowCount = 0;
    _espEtabRegisterPhotos = [];
    document.getElementById('esp-etab-filieres-rows').innerHTML = '';
    espEtabAddFiliereRow();
    espEtabAddFiliereRow();
    espEtabAddFiliereRow();
    espEtabUpdateVilleOptions();
    espEtabToggleSousCategorie();
  }
}

// ---------------- Catégorie / Sous-catégorie (Sous-catégorie visible seulement si Enseignement supérieur) ----------------
function espEtabToggleSousCategorie(){
  const catSelect = document.getElementById('esp-etab-categorie');
  const field = document.getElementById('esp-etab-souscategorie-field');
  if(!catSelect || !field) return;
  field.style.display = catSelect.value === 'superieur' ? '' : 'none';
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

// ---------------- Photos de l'établissement (jusqu'à 10, à l'inscription) ----------------
let _espEtabRegisterPhotos = [];
async function espEtabRegisterPhotosChange(input){
  const files = Array.from(input.files || []);
  const remaining = 10 - _espEtabRegisterPhotos.length;
  if(remaining <= 0){ input.value = ''; return; }
  const toUpload = files.slice(0, remaining);
  const msgEl = document.getElementById('esp-etab-photos-msg');
  if(msgEl) msgEl.innerHTML = '<p class="esp-sub" style="margin:4px 0;">Envoi en cours...</p>';
  for(const file of toUpload){
    try {
      const url = await espUploadEtabPhoto(file);
      _espEtabRegisterPhotos.push(url);
    } catch(e){
      if(msgEl) msgEl.innerHTML = '<p class="esp-error">Erreur lors de l\'envoi d\'une photo : ' + escapeHtml(e.message) + '</p>';
    }
  }
  if(msgEl && !msgEl.querySelector('.esp-error')) msgEl.innerHTML = '';
  input.value = '';
  espEtabRenderRegisterPhotos();
}
function espEtabRemoveRegisterPhoto(idx){
  _espEtabRegisterPhotos.splice(idx, 1);
  espEtabRenderRegisterPhotos();
}
function espEtabRenderRegisterPhotos(){
  const el = document.getElementById('esp-etab-photos-preview');
  if(!el) return;
  el.innerHTML = _espEtabRegisterPhotos.map((u,i) => `
    <div class="esp-etab-photo-thumb">
      <img src="${escapeHtml(u)}" alt="Photo établissement">
      <span class="esp-etab-photo-remove" onclick="espEtabRemoveRegisterPhoto(${i})" title="Retirer">✕</span>
    </div>
  `).join('');
  const label = document.getElementById('esp-etab-photos-label');
  if(label) label.textContent = `Photos de l'établissement (${_espEtabRegisterPhotos.length}/10)`;
  const input = document.getElementById('esp-etab-photos-input');
  if(input) input.style.display = _espEtabRegisterPhotos.length >= 10 ? 'none' : '';
}
async function espEtabRegister(){
  const nom = document.getElementById('esp-etab-nom').value.trim();
  const region = document.getElementById('esp-etab-region').value;
  const villeSelect = document.getElementById('esp-etab-ville');
  const ville = villeSelect.value === '__autre__' ? document.getElementById('esp-etab-ville-autre').value.trim() : villeSelect.value;
  const quartier = document.getElementById('esp-etab-quartier').value.trim();
  const categorie = document.getElementById('esp-etab-categorie').value;
  const souscategorieField = document.getElementById('esp-etab-souscategorie-field');
  // Pour l'enseignement supérieur, l'établissement choisit Université ou Grande école.
  // Pour les autres catégories (technique, général), la sous-catégorie "Secondaire" est
  // attribuée automatiquement : un seul choix logique, inutile de le demander.
  const sousCategorie = (souscategorieField && souscategorieField.style.display !== 'none')
    ? document.getElementById('esp-etab-sous-categorie').value
    : 'secondaire';
  const secteur = document.getElementById('esp-etab-secteur').value;
  // "Type" reste rempli automatiquement pour la compatibilité avec le reste de l'application
  // (tableau de bord établissement, vue admin) tant que ces écrans n'ont pas été mis à jour.
  const typeParCategorie = { technique: 'Secondaire formation professionnelle et technique', general: 'Secondaire générale', superieur: 'Supérieure' };
  const type = typeParCategorie[categorie] || '';
  const responsable = document.getElementById('esp-etab-resp').value.trim();
  const contactTel = document.getElementById('esp-etab-resp-tel').value.trim();
  const tel = document.getElementById('esp-etab-tel').value.trim();
  const tel2 = document.getElementById('esp-etab-tel2').value.trim();
  const tel3 = document.getElementById('esp-etab-tel3').value.trim();
  const siteWeb = document.getElementById('esp-etab-siteweb').value.trim();
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
  const nouvelEtab = { id, nom, region, ville, quartier, type, responsable, contactTel, tel, tel2, tel3, siteWeb, email, password:pass, statut:'en_attente', active:true, dateInscription:espDate(), filieresProposees, photos: _espEtabRegisterPhotos.slice(0,10), categorie, sousCategorie, secteur };
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
function espEtabLogout(){ _espEtabOwn = null; platformLogout(); }

// ---------------- Récupération d'un compte pré-inscrit (import en masse) via code ----------------
// Cas des établissements d'Enseignement Général inscrits d'office par l'administration :
// ils apparaissent tout de suite dans l'annuaire, mais n'ont ni e-mail ni mot de passe tant
// que l'établissement n'a pas utilisé le code reçu hors-plateforme (courrier officiel) pour
// définir ses propres identifiants et prendre le contrôle de son compte.
function espRenderEtabClaim(){
  document.getElementById('esp-etablissement').innerHTML = `
    <button class="esp-back" onclick="espRenderEtabAuth('login')">← Retour</button>
    <div class="esp-card" style="max-width:560px;margin:0 auto;">
      <div class="esp-title">🏫 Récupérer mon établissement</div>
      <p class="esp-sub">Votre établissement a été inscrit d'office par l'administration et apparaît déjà dans l'annuaire. Saisissez le code de récupération reçu (courrier officiel) et choisissez votre e-mail et mot de passe pour prendre le contrôle du compte.</p>
      <div id="esp-etab-claim-error"></div>
      <div class="esp-field" style="margin-bottom:12px;"><label>Code de récupération</label><input type="text" id="esp-etab-claim-code" placeholder="Ex : A7K9QPX2" style="text-transform:uppercase;"></div>
      <div class="esp-field" style="margin-bottom:12px;"><label>E-mail de l'établissement</label><input type="email" id="esp-etab-claim-email" placeholder="contact@etablissement.ci"></div>
      <div class="esp-field" style="margin-bottom:12px;"><label>Nom du responsable</label><input type="text" id="esp-etab-claim-resp" placeholder="Optionnel si déjà renseigné par l'administration"></div>
      <div class="esp-field" style="margin-bottom:12px;"><label>Téléphone du responsable</label><input type="tel" id="esp-etab-claim-resp-tel" placeholder="Optionnel — usage interne, jamais public"></div>
      <div class="esp-field-row" style="margin-bottom:12px;">
        <div class="esp-field"><label>Téléphone</label><input type="tel" id="esp-etab-claim-tel" placeholder="Optionnel"></div>
        <div class="esp-field"><label>Téléphone 2</label><input type="tel" id="esp-etab-claim-tel2" placeholder="Optionnel"></div>
      </div>
      <div class="esp-field" style="margin-bottom:12px;"><label>Téléphone 3</label><input type="tel" id="esp-etab-claim-tel3" placeholder="Optionnel"></div>
      <div class="esp-field" style="margin-bottom:12px;"><label>Site web</label><input type="text" id="esp-etab-claim-siteweb" placeholder="Optionnel"></div>
      <div class="esp-field" style="margin-bottom:8px;"><label>Choisir un mot de passe</label><input type="password" id="esp-etab-claim-pass"></div>
      <div class="esp-field" style="margin-bottom:14px;"><label>Confirmer le mot de passe</label><input type="password" id="esp-etab-claim-pass2" onkeydown="if(event.key==='Enter')espEtabClaim()"></div>
      <button class="esp-btn esp-btn-primary" onclick="espEtabClaim()">Récupérer mon compte</button>
    </div>
  `;
}
async function espEtabClaim(){
  const code = document.getElementById('esp-etab-claim-code').value.trim().toUpperCase();
  const email = document.getElementById('esp-etab-claim-email').value.trim();
  const responsable = document.getElementById('esp-etab-claim-resp').value.trim();
  const contactTel = document.getElementById('esp-etab-claim-resp-tel').value.trim();
  const tel = document.getElementById('esp-etab-claim-tel').value.trim();
  const tel2 = document.getElementById('esp-etab-claim-tel2').value.trim();
  const tel3 = document.getElementById('esp-etab-claim-tel3').value.trim();
  const siteWeb = document.getElementById('esp-etab-claim-siteweb').value.trim();
  const pass = document.getElementById('esp-etab-claim-pass').value;
  const pass2 = document.getElementById('esp-etab-claim-pass2').value;
  const errEl = document.getElementById('esp-etab-claim-error');
  if(!code || !email || !pass){
    errEl.innerHTML = '<p class="esp-error">Code, e-mail et mot de passe sont obligatoires.</p>';
    return;
  }
  if(pass !== pass2){
    errEl.innerHTML = '<p class="esp-error">Les mots de passe ne correspondent pas.</p>';
    return;
  }
  let ok;
  try {
    ok = await espEtabClaimRPC(code, email, pass, responsable, tel, tel2, tel3, siteWeb, contactTel);
  } catch(e){
    errEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(e.message) + '</p>';
    return;
  }
  if(!ok){
    errEl.innerHTML = '<p class="esp-error">Code invalide, déjà utilisé, ou e-mail déjà associé à un autre établissement.</p>';
    return;
  }
  try { await espLoadFromSupabase(); } catch(e){}
  // Le compte vient d'être réclamé : on retrouve son id fraîchement mis à jour dans le cache.
  const db = espDB();
  const etab = (db.etablissements || []).find(e => e.email === email);
  if(etab){ espSetSession('etablissement', etab.id, pass); platformUnlock(); }
  else { espRenderEtabAuth('login'); }
}

// ---------------- Cache non masqué de l'établissement connecté (sa propre fiche) ----------------
// Alimenté par etablissement_get_own(), jamais par list_etablissements() : cette dernière masque
// tel/tel2/tel3/email/site_web tant que non premium, et ne renvoie jamais responsable/contact_tel.
// null = pas encore chargé.
let _espEtabOwn = null;
let _espEtabOwnLoading = false;
async function espEtabEnsureOwnLoaded(){
  const session = espSession();
  if(!session || session.role !== 'etablissement') return;
  if((_espEtabOwn && _espEtabOwn.id === session.id) || _espEtabOwnLoading) return;
  _espEtabOwnLoading = true;
  let own;
  try {
    own = await espEtabGetOwnRPC(session.id, session.password);
  } catch(e){
    _espEtabOwnLoading = false;
    alert("Erreur lors du chargement de votre fiche établissement : " + e.message);
    return;
  }
  _espEtabOwnLoading = false;
  if(!own){ espEtabLogout(); return; }
  _espEtabOwn = own;
  espRenderEtabDashboard();
}
// Invalide le cache et relance le rendu après toute mutation depuis le tableau de bord :
// garantit que la fiche affichée reste alignée avec la base plutôt que des patchs locaux
// dispersés qui finissent par diverger.
async function espEtabRefreshOwnAndDashboard(){
  _espEtabOwn = null;
  try { await espLoadFromSupabase(); } catch(e){}
  espRenderEtabDashboard();
}

function espRenderEtabDashboard(){
  const session = espSession();
  if(!_espEtabOwn || _espEtabOwn.id !== session.id){
    document.getElementById('esp-etablissement').innerHTML = '<p class="esp-empty">Chargement de votre fiche…</p>';
    espEtabEnsureOwnLoaded();
    return;
  }
  const etab = _espEtabOwn;

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
      <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:10px;flex-wrap:wrap;">
        <div>
          <p><span class="esp-badge ${etab.statut}">${statutLabel}</span></p>
          <p class="esp-sub">${statutMsg}</p>
          <p class="esp-sub" style="margin-top:10px;">${[etab.ville, etab.quartier, etab.region].filter(Boolean).map(escapeHtml).join(' · ')} · ${escapeHtml(etab.type)} · Responsable : ${escapeHtml(etab.responsable)} · ${escapeHtml(etab.tel)} · ${escapeHtml(etab.email)}</p>
        </div>
        <button class="esp-btn" onclick="espEtabToggleEditInfo()">✏️ Modifier</button>
      </div>
      <div id="esp-etab-info-form" style="display:none;margin-top:16px;border-top:1px dashed var(--border);padding-top:16px;">
        <div class="esp-field-row">
          <div class="esp-field"><label>Nom de l'établissement</label><input type="text" id="esp-etab-edit-nom" value="${escapeHtml(etab.nom)}"></div>
          <div class="esp-field"><label>Type d'établissement</label>
            <select id="esp-etab-edit-type">
              <option>Secondaire générale</option>
              <option>Secondaire formation professionnelle et technique</option>
              <option>Supérieure</option>
            </select>
          </div>
        </div>
        <div class="esp-field-row">
          <div class="esp-field"><label>Nom du responsable</label><input type="text" id="esp-etab-edit-resp" value="${escapeHtml(etab.responsable||'')}"></div>
          <div class="esp-field"><label>Téléphone du responsable</label><input type="tel" id="esp-etab-edit-resp-tel" value="${escapeHtml(etab.contactTel||'')}" placeholder="Usage interne, jamais public"></div>
        </div>
        <div class="esp-field-row">
          <div class="esp-field"><label>Téléphone</label><input type="tel" id="esp-etab-edit-tel" value="${escapeHtml(etab.tel||'')}"></div>
          <div class="esp-field"><label>E-mail</label><input type="email" id="esp-etab-edit-email" value="${escapeHtml(etab.email||'')}"></div>
        </div>
        <button class="esp-btn esp-btn-primary" onclick="espEtabSaveInfo()">Enregistrer</button>
        <div id="esp-etab-info-msg"></div>
      </div>
    </div>

    <div class="esp-card">
      <div class="esp-title" style="font-size:15px;">📞 Contact & site web</div>
      <p class="esp-sub" style="margin-bottom:10px;">Numéros supplémentaires et site web — visibles publiquement une fois le Premium actif, mais modifiables dès maintenant.</p>
      <div class="esp-field-row">
        <div class="esp-field"><label>Téléphone 2</label><input type="tel" id="esp-etab-extra-tel2" value="${escapeHtml(etab.tel2||'')}" placeholder="Optionnel"></div>
        <div class="esp-field"><label>Téléphone 3</label><input type="tel" id="esp-etab-extra-tel3" value="${escapeHtml(etab.tel3||'')}" placeholder="Optionnel"></div>
      </div>
      <div class="esp-field" style="margin-bottom:10px;"><label>Site web</label><input type="url" id="esp-etab-extra-site-web" value="${escapeHtml(etab.siteWeb||'')}" placeholder="https://..."></div>
      <button class="esp-btn esp-btn-primary" onclick="espEtabSaveContactExtras()">Enregistrer</button>
      <div id="esp-etab-extras-msg"></div>
    </div>

    <div class="esp-card">
      <div class="esp-title" style="font-size:15px;">📷 Photos <span class="esp-badge ${etab.premium ? 'valide' : 'non_reclame'}" style="margin-left:6px;">${etab.premium ? 'Premium actif' : 'Premium requis'}</span></div>
      ${!etab.premium ? `
        <p class="esp-sub">Fonctionnalité réservée aux établissements ayant souscrit à l'offre Premium. Contactez l'administration de la plateforme pour l'activer sur votre compte.</p>
        ${etab.demandePremium ? `
          <p class="esp-sub"><span class="esp-badge en_attente">⏳ Demande en attente de validation</span>${etab.demandePremiumDate ? ' — envoyée le ' + escapeHtml(etab.demandePremiumDate) : ''}</p>
        ` : `
          <button class="esp-btn esp-btn-primary" onclick="espEtabDemanderPremium()">Demander le mode Premium</button>
          <div id="esp-etab-premium-msg"></div>
        `}
      ` : `
        <div class="esp-title" style="font-size:14px;">Mes photos (${(etab.photos||[]).length}/10)</div>
        <p class="esp-sub" style="margin-bottom:10px;">Visibles par les visiteurs qui consultent votre établissement dans la recherche.</p>
        <div id="esp-etab-photos-dash-grid" class="esp-etab-photos-grid">
          ${(etab.photos||[]).map((u,i) => `
            <div class="esp-etab-photo-thumb">
              <img src="${escapeHtml(u)}" alt="Photo établissement">
              <span class="esp-etab-photo-remove" onclick="espEtabRemovePhoto(${i})" title="Retirer">✕</span>
            </div>
          `).join('')}
        </div>
        ${(etab.photos||[]).length < 10 ? `<input type="file" id="esp-etab-photos-dash-input" accept="image/*" multiple onchange="espEtabDashboardPhotosChange(this)">` : `<p class="esp-sub">Maximum de 10 photos atteint.</p>`}
        <div id="esp-etab-photos-dash-msg"></div>
      `}
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
      <div class="esp-title" style="font-size:15px;">Mes filières (${(etab.filieresProposees||[]).length}/10)</div>
      ${(etab.filieresProposees||[]).length ? etab.filieresProposees.map(f => `
        <div class="esp-note-item" style="border-left-color:var(--green-dark);display:flex;justify-content:space-between;align-items:center;gap:8px;">
          <span><b>${escapeHtml(f.nom)}</b> (${escapeHtml(f.diplome)}) <span class="esp-badge ${f.statut}" style="margin-left:6px;">${f.statut === 'en_attente' ? 'En attente' : f.statut === 'valide' ? 'Validée' : 'Refusée'}</span></span>
          <button class="esp-btn esp-btn-danger" style="padding:4px 9px;font-size:12px;flex-shrink:0;" title="Supprimer cette filière" onclick="espEtabDeleteFiliereDashboard('${f.id}')">🗑️</button>
        </div>
      `).join('') : `<p class="esp-empty">Aucune filière renseignée.</p>`}
      ${(etab.filieresProposees||[]).length < 10 ? `
        <div id="esp-etab-add-filiere-form" style="margin-top:14px;border-top:1px dashed var(--border);padding-top:14px;">
          <div class="esp-field-row">
            <div class="esp-field"><input type="text" id="esp-etab-new-filiere-nom" placeholder="Nom de la filière"></div>
            <div class="esp-field"><input type="text" id="esp-etab-new-filiere-diplome" placeholder="Diplôme préparé (Ex : CAP, BT, BTS, Licence...)"></div>
          </div>
          <button class="esp-btn esp-btn-primary" onclick="espEtabAddFiliereDashboard()">+ Ajouter cette filière</button>
          <div id="esp-etab-add-filiere-msg"></div>
        </div>
      ` : `<p class="esp-sub" style="margin-top:10px;">Maximum de 10 filières atteint.</p>`}
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
  const typeSelect = document.getElementById('esp-etab-edit-type');
  if(typeSelect) typeSelect.value = etab.type;
}

// ---------------- Modifier les informations générales ----------------
function espEtabToggleEditInfo(){
  const form = document.getElementById('esp-etab-info-form');
  if(!form) return;
  form.style.display = form.style.display === 'none' ? '' : 'none';
}
async function espEtabSaveInfo(){
  const session = espSession();
  const msgEl = document.getElementById('esp-etab-info-msg');
  const nom = document.getElementById('esp-etab-edit-nom').value.trim();
  const type = document.getElementById('esp-etab-edit-type').value;
  const responsable = document.getElementById('esp-etab-edit-resp').value.trim();
  const contactTel = document.getElementById('esp-etab-edit-resp-tel').value.trim();
  const tel = document.getElementById('esp-etab-edit-tel').value.trim();
  const email = document.getElementById('esp-etab-edit-email').value.trim();
  if(!nom || !email){
    msgEl.innerHTML = '<p class="esp-error">Le nom et l\'e-mail sont obligatoires.</p>';
    return;
  }
  msgEl.innerHTML = '<p class="esp-sub" style="margin:6px 0 0;">Enregistrement...</p>';
  try {
    const ok = await espEtabUpdateInfoRPC(session.id, session.password, nom, type, responsable, tel, email, contactTel);
    if(!ok){ msgEl.innerHTML = '<p class="esp-error">Session expirée, merci de te reconnecter.</p>'; return; }
    await espEtabRefreshOwnAndDashboard();
  } catch(e){
    msgEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(e.message) + '</p>';
  }
}

// ---------------- Premium : contact direct + site web ----------------
async function espEtabSaveContactExtras(){
  const session = espSession();
  const msgEl = document.getElementById('esp-etab-extras-msg');
  const tel2 = document.getElementById('esp-etab-extra-tel2').value.trim();
  const tel3 = document.getElementById('esp-etab-extra-tel3').value.trim();
  const siteWeb = document.getElementById('esp-etab-extra-site-web').value.trim();
  msgEl.innerHTML = '<p class="esp-sub" style="margin:6px 0 0;">Enregistrement...</p>';
  try {
    const ok = await espEtabUpdateContactExtrasRPC(session.id, session.password, tel2, tel3, siteWeb);
    if(!ok){ msgEl.innerHTML = '<p class="esp-error">Session expirée, merci de te reconnecter.</p>'; return; }
    await espEtabRefreshOwnAndDashboard();
  } catch(e){
    msgEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(e.message) + '</p>';
  }
}

// ---------------- Ajout libre d'une filière (sans validation admin, jusqu'à 10) ----------------
async function espEtabAddFiliereDashboard(){
  const session = espSession();
  const msgEl = document.getElementById('esp-etab-add-filiere-msg');
  const nomEl = document.getElementById('esp-etab-new-filiere-nom');
  const diplomeEl = document.getElementById('esp-etab-new-filiere-diplome');
  const nom = nomEl.value.trim();
  const diplome = diplomeEl.value.trim();
  if(!nom || !diplome){
    msgEl.innerHTML = '<p class="esp-error">Nom de la filière et diplôme préparé sont obligatoires.</p>';
    return;
  }
  msgEl.innerHTML = '<p class="esp-sub" style="margin:6px 0 0;">Ajout en cours...</p>';
  try {
    const ok = await espEtabAddFiliereRPC(session.id, session.password, nom, diplome);
    if(!ok){ msgEl.innerHTML = '<p class="esp-error">Échec de l\'ajout (limite de 10 filières atteinte, ou session expirée).</p>'; return; }
  } catch(e){
    msgEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(e.message) + '</p>';
    return;
  }
  await espEtabRefreshOwnAndDashboard();
}

// ---------------- Suppression d'une filière déjà ajoutée ----------------
async function espEtabDeleteFiliereDashboard(filiereId){
  if(!confirm('Supprimer définitivement cette filière ? Cette action est irréversible.')) return;
  const session = espSession();
  try {
    const ok = await espEtabDeleteFiliereRPC(session.id, session.password, filiereId);
    if(!ok){ alert("Échec de la suppression (session expirée, merci de te reconnecter)."); return; }
  } catch(e){
    alert('Erreur : ' + e.message);
    return;
  }
  await espEtabRefreshOwnAndDashboard();
}

// ---------------- Demande d'activation du mode Premium ----------------
async function espEtabDemanderPremium(){
  const session = espSession();
  const msgEl = document.getElementById('esp-etab-premium-msg');
  if(msgEl) msgEl.innerHTML = '<p class="esp-sub" style="margin:6px 0 0;">Envoi de la demande...</p>';
  try {
    const ok = await espEtabDemanderPremiumRPC(session.id, session.password);
    if(!ok){ if(msgEl) msgEl.innerHTML = '<p class="esp-error">Échec de la demande (session expirée, ou compte déjà Premium).</p>'; return; }
  } catch(e){
    if(msgEl) msgEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(e.message) + '</p>';
    return;
  }
  await espEtabRefreshOwnAndDashboard();
}

// ---------------- Photos (modifiables après inscription) ----------------
async function espEtabDashboardPhotosChange(input){
  const session = espSession();
  if(!_espEtabOwn) return;
  const current = _espEtabOwn.photos || [];
  const files = Array.from(input.files || []);
  const remaining = 10 - current.length;
  if(remaining <= 0){ input.value = ''; return; }
  const toUpload = files.slice(0, remaining);
  const msgEl = document.getElementById('esp-etab-photos-dash-msg');
  if(msgEl) msgEl.innerHTML = '<p class="esp-sub" style="margin:4px 0;">Envoi en cours...</p>';
  const newUrls = [];
  for(const file of toUpload){
    try { newUrls.push(await espUploadEtabPhoto(file)); }
    catch(e){ if(msgEl) msgEl.innerHTML = '<p class="esp-error">Erreur lors de l\'envoi : ' + escapeHtml(e.message) + '</p>'; }
  }
  const updated = [...current, ...newUrls];
  try {
    const ok = await espEtabUpdatePhotosRPC(session.id, session.password, updated);
    if(!ok){ if(msgEl) msgEl.innerHTML = '<p class="esp-error">Session expirée, merci de te reconnecter.</p>'; return; }
    await espEtabRefreshOwnAndDashboard();
  } catch(e){
    if(msgEl) msgEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(e.message) + '</p>';
  }
}
async function espEtabRemovePhoto(idx){
  const session = espSession();
  if(!_espEtabOwn) return;
  const updated = (_espEtabOwn.photos || []).slice();
  updated.splice(idx, 1);
  try {
    const ok = await espEtabUpdatePhotosRPC(session.id, session.password, updated);
    if(!ok) return;
    await espEtabRefreshOwnAndDashboard();
  } catch(e){}
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
    await espEtabRefreshOwnAndDashboard();
  } catch(e){
    msgEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(e.message) + '</p>';
  }
}
