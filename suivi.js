// ============================================================
// ---- Suivi facultatif d'élèves par l'inspecteur ----
// ---- Répertoire privé, saisie libre (aucun lien avec un compte élève) ----
// ============================================================

// Les 7 raisons du suivi reprennent les mêmes codes/libellés que les 7
// dimensions du test LYCAM (cf. DIMENSIONS dans lycam.js) — simple
// réutilisation à titre de catégorisation, aucun lien de calcul avec un
// résultat LYCAM réel.
const SUIVI_RAISONS = [
  { code:'IE', label:"Intérêt pour l'école" },
  { code:'AF', label:"Attitude de la famille" },
  { code:'RS', label:"Rendement scolaire" },
  { code:'CS', label:"Confiance en soi" },
  { code:'AB', label:"Absentéisme" },
  { code:'BS', label:"Besoin de soutien de l'équipe éducative" },
  { code:'PS', label:"Projet scolaire" },
];
function espSuiviRaisonLabel(code){
  const r = SUIVI_RAISONS.find(x => x.code === code);
  return r ? r.label : code;
}

/* ---- État de l'onglet Suivi ---- */
let _espSuiviView = 'list'; // 'list' | 'add'
let _espSuiviEleves = [];
let _espSuiviLoading = false;
let _espSuiviError = '';

async function espSuiviInitTab(){
  _espSuiviView = 'list';
  _espSuiviError = '';
  _espSuiviLoading = true;
  espSuiviRefreshContainer();
  const session = espSession();
  try {
    _espSuiviEleves = await espSuiviListElevesRPC(session.id, session.password);
  } catch(e){
    _espSuiviError = "Impossible de charger le répertoire : " + e.message;
    _espSuiviEleves = [];
  }
  _espSuiviLoading = false;
  espSuiviRefreshContainer();
}

function espSuiviRefreshContainer(){
  const container = document.getElementById('esp-suivi-tab-container');
  if(container) container.innerHTML = espRenderSuiviTab();
  espRefreshIcons();
}

/* ---------------- Rendu principal ---------------- */
function espRenderSuiviTab(){
  if(_espSuiviView === 'add') return espSuiviRenderAddForm();
  return espSuiviRenderList();
}

function espSuiviRaisonsBadgesHtml(raisons){
  return (raisons||[]).map(code =>
    `<span class="esp-badge non_reclame" style="margin:2px 4px 2px 0;" title="${escapeHtml(espSuiviRaisonLabel(code))}">${escapeHtml(code)}</span>`
  ).join('');
}

function espSuiviRenderList(){
  return `
    <div class="esp-card">
      <div class="esp-title" style="font-size:16px;">${icon('user-check')}Suivi d'élèves</div>
      <p class="esp-sub">Répertoire privé, en saisie libre : ces élèves ne sont pas liés à un compte élève de la plateforme, et ce suivi n'est visible que par toi.</p>
      ${_espSuiviError ? `<p class="esp-error">${escapeHtml(_espSuiviError)}</p>` : ''}
      ${_espSuiviLoading ? `<p class="esp-empty">Chargement...</p>` : `
        <button class="esp-btn esp-btn-primary" onclick="espSuiviGoToAdd()">${icon('plus')}Ajouter un élève à suivre</button>
        <div style="margin-top:16px;">
          ${_espSuiviEleves.length ? `
            <table class="esp-table">
              <thead><tr><th>Nom</th><th>Classe</th><th>Raisons du suivi</th><th>Ajouté le</th><th></th></tr></thead>
              <tbody>
                ${_espSuiviEleves.map(e => `
                  <tr>
                    <td><b>${escapeHtml(e.nom)} ${escapeHtml(e.prenoms||'')}</b></td>
                    <td>${escapeHtml(e.classe)}</td>
                    <td>${espSuiviRaisonsBadgesHtml(e.raisons)}</td>
                    <td>${escapeHtml(e.dateAjout)}</td>
                    <td>
                      <button class="esp-btn esp-btn-danger" style="padding:5px 10px;font-size:11.5px;" onclick="espSuiviDeleteEleve('${e.id}')">${icon('trash-2')}Retirer</button>
                    </td>
                  </tr>
                `).join('')}
              </tbody>
            </table>
          ` : `<p class="esp-empty">Aucun élève suivi pour le moment.</p>`}
        </div>
      `}
    </div>
  `;
}

function espSuiviGoToAdd(){
  _espSuiviView = 'add';
  espSuiviRefreshContainer();
}
function espSuiviBackToList(){
  _espSuiviView = 'list';
  espSuiviRefreshContainer();
}

function espSuiviRenderAddForm(){
  return `
    <div class="esp-card">
      <button class="esp-back" onclick="espSuiviBackToList()">${icon('arrow-left')}Répertoire de suivi</button>
      <div class="esp-title" style="font-size:16px;">${icon('user-check')}Ajouter un élève à suivre</div>
      <p class="esp-sub">Saisie libre : cet élève n'a pas besoin d'avoir de compte sur la plateforme.</p>
      <div class="esp-field-row">
        <div class="esp-field"><label>Nom</label><input type="text" id="esp-suivi-nom"></div>
        <div class="esp-field"><label>Prénoms</label><input type="text" id="esp-suivi-prenoms"></div>
      </div>
      <div class="esp-field" style="margin-bottom:12px;"><label>Classe</label><input type="text" id="esp-suivi-classe" placeholder="Ex : 2nde B"></div>
      <div class="esp-field" style="margin-bottom:12px;">
        <label>Raison(s) du suivi</label>
        <select id="esp-suivi-raisons" multiple size="7">
          ${SUIVI_RAISONS.map(r => `<option value="${escapeHtml(r.code)}">${escapeHtml(r.code)} — ${escapeHtml(r.label)}</option>`).join('')}
        </select>
        <p class="esp-sub" style="margin:4px 0 0;font-size:11.5px;">Maintiens Ctrl (ou Cmd sur Mac) pour sélectionner plusieurs raisons.</p>
      </div>
      <div id="esp-suivi-add-error"></div>
      <button class="esp-btn esp-btn-primary" onclick="espSuiviSubmitAdd()">Ajouter au répertoire</button>
    </div>
  `;
}

async function espSuiviSubmitAdd(){
  const nom = document.getElementById('esp-suivi-nom').value.trim();
  const prenoms = document.getElementById('esp-suivi-prenoms').value.trim();
  const classe = document.getElementById('esp-suivi-classe').value.trim();
  const select = document.getElementById('esp-suivi-raisons');
  const raisons = Array.from(select.selectedOptions).map(o => o.value);
  const errorEl = document.getElementById('esp-suivi-add-error');
  errorEl.innerHTML = '';
  if(!nom || !classe){ errorEl.innerHTML = '<p class="esp-error">Nom et classe sont obligatoires.</p>'; return; }
  if(!raisons.length){ errorEl.innerHTML = '<p class="esp-error">Sélectionne au moins une raison de suivi.</p>'; return; }

  const session = espSession();
  try {
    await espSuiviAddEleveRPC(session.id, session.password, nom, prenoms, classe, raisons);
  } catch(e){
    errorEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(e.message) + '</p>';
    return;
  }
  await espSuiviInitTab();
}

async function espSuiviDeleteEleve(id){
  const e = _espSuiviEleves.find(x => x.id === id);
  if(!e) return;
  if(!confirm(`Retirer ${e.nom} ${e.prenoms||''} du répertoire de suivi ? Toutes ses notes de remédiation seront supprimées définitivement.`)) return;
  const session = espSession();
  try {
    await espSuiviDeleteEleveRPC(session.id, session.password, id);
  } catch(err){
    alert('Erreur : ' + err.message);
    return;
  }
  await espSuiviInitTab();
}
