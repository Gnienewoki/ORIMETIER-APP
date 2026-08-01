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
          <div class="esp-field"><label>Ville / Commune</label><input type="text" id="esp-etab-ville"></div>
        </div>
        <div class="esp-field-row">
          <div class="esp-field"><label>Type d'établissement</label>
            <select id="esp-etab-type">
              <option>Lycée Technique</option>
              <option>Lycée Professionnel</option>
              <option>Centre de Métiers</option>
              <option>Collège d'Enseignement Technique</option>
              <option>Centre d'Information et d'Orientation (CIO)</option>
              <option>Université / Grande École</option>
              <option>Autre</option>
            </select>
          </div>
          <div class="esp-field"><label>Nom du responsable</label><input type="text" id="esp-etab-resp"></div>
        </div>
        <div class="esp-field-row">
          <div class="esp-field"><label>Téléphone</label><input type="tel" id="esp-etab-tel"></div>
          <div class="esp-field"><label>E-mail</label><input type="email" id="esp-etab-email2"></div>
        </div>
        <div class="esp-field" style="margin-bottom:14px;"><label>Mot de passe</label><input type="password" id="esp-etab-pass2"></div>
        <button class="esp-btn esp-btn-primary" onclick="espEtabRegister()">Soumettre l'inscription</button>
        <p style="margin-top:14px;font-size:13px;">Déjà inscrit ? <span class="esp-toggle-link" onclick="espRenderEtabAuth('login')">Se connecter</span></p>
      `}
    </div>
  `;
}
async function espEtabRegister(){
  const nom = document.getElementById('esp-etab-nom').value.trim();
  const ville = document.getElementById('esp-etab-ville').value.trim();
  const type = document.getElementById('esp-etab-type').value;
  const responsable = document.getElementById('esp-etab-resp').value.trim();
  const tel = document.getElementById('esp-etab-tel').value.trim();
  const email = document.getElementById('esp-etab-email2').value.trim();
  const pass = document.getElementById('esp-etab-pass2').value;
  if(!nom || !email || !pass){
    document.getElementById('esp-etab-error').innerHTML = "<p class=\"esp-error\">Nom de l'établissement, e-mail et mot de passe sont obligatoires.</p>";
    return;
  }
  const db = espDB();
  if(db.etablissements.some(e => e.email === email)){
    document.getElementById('esp-etab-error').innerHTML = '<p class="esp-error">Un établissement est déjà inscrit avec cet e-mail.</p>';
    return;
  }
  const id = espUid();
  const nouvelEtab = { id, nom, ville, type, responsable, tel, email, password:pass, statut:'en_attente', active:true, dateInscription:espDate(), filieresProposees:[] };
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
    ? "Votre inscription est en cours d'examen par l'administrateur de la plateforme. Vous pourrez proposer des filières une fois votre établissement validé."
    : etab.statut === 'refuse'
    ? "Votre inscription n'a pas été validée. Contactez l'administrateur de la plateforme pour plus d'informations."
    : "Votre établissement est validé. Vous pouvez proposer de nouvelles filières à intégrer à l'annuaire.";

  document.getElementById('esp-etablissement').innerHTML = `
    <div class="esp-user-header">
      <span class="esp-user-name">🏫 ${escapeHtml(etab.nom)}</span>
      <button class="esp-btn" onclick="espEtabLogout()">Déconnexion</button>
    </div>
    <div class="esp-card">
      <p><span class="esp-badge ${etab.statut}">${statutLabel}</span></p>
      <p class="esp-sub">${statutMsg}</p>
      <p class="esp-sub" style="margin-top:10px;">${escapeHtml(etab.ville)} · ${escapeHtml(etab.type)} · Responsable : ${escapeHtml(etab.responsable)} · ${escapeHtml(etab.tel)} · ${escapeHtml(etab.email)}</p>
    </div>

    ${etab.statut === 'valide' ? `
      <div class="esp-card">
        <div class="esp-title" style="font-size:16px;">Proposer une nouvelle filière</div>
        <p class="esp-sub">Votre proposition sera soumise à l'administrateur avant intégration à l'annuaire.</p>
        <div class="esp-field-row">
          <div class="esp-field"><label>Nom de la filière</label><input type="text" id="esp-etab-fil-nom" placeholder="Ex : Maintenance Informatique"></div>
          <div class="esp-field"><label>Diplôme</label><input type="text" id="esp-etab-fil-diplome" placeholder="Ex : CAP, BT, BTS"></div>
        </div>
        <div class="esp-field" style="margin-bottom:14px;">
          <label>Conditions d'accès</label>
          <textarea id="esp-etab-fil-conditions" placeholder="Niveau requis, âge, moyennes minimales, etc."></textarea>
        </div>
        <button class="esp-btn esp-btn-primary" onclick="espEtabProposeFiliere()">Soumettre la proposition</button>
      </div>
      <div class="esp-card">
        <div class="esp-title" style="font-size:15px;">Mes propositions</div>
        ${(etab.filieresProposees||[]).length ? etab.filieresProposees.map(f => `
          <div class="esp-note-item" style="border-left-color:var(--green-dark);">
            <b>${escapeHtml(f.nom)}</b> (${escapeHtml(f.diplome)}) <span class="esp-badge ${f.statut}" style="margin-left:6px;">${f.statut === 'en_attente' ? 'En attente' : f.statut === 'valide' ? 'Validée' : 'Refusée'}</span>
            <br>${escapeHtml(f.conditions)}
            <small>Proposée le ${escapeHtml(f.date)}</small>
          </div>
        `).join('') : `<p class="esp-empty">Aucune proposition pour le moment.</p>`}
      </div>
    ` : ''}
  `;
}
async function espEtabProposeFiliere(){
  const session = espSession();
  const db = espDB();
  const etab = db.etablissements.find(e => e.id === session.id);
  const nom = document.getElementById('esp-etab-fil-nom').value.trim();
  const diplome = document.getElementById('esp-etab-fil-diplome').value.trim();
  const conditions = document.getElementById('esp-etab-fil-conditions').value.trim();
  if(!nom || !diplome) return;
  let ok;
  try {
    ok = await espProposeFiliereRPC(etab.id, session.password, nom, diplome, conditions);
  } catch(e){
    alert('Erreur lors de la soumission : ' + e.message);
    return;
  }
  if(!ok){ alert("Session expirée, merci de te reconnecter."); platformLogout(); return; }
  if(!etab.filieresProposees) etab.filieresProposees = [];
  etab.filieresProposees.push({ id:espUid(), nom, diplome, conditions, statut:'en_attente', date:espDate() });
  espSaveDB(db);
  espRenderEtabDashboard();
}
