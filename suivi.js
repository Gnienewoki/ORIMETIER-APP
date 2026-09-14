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
let _espSuiviView = 'list'; // 'list' | 'add' | 'detail'
let _espSuiviEleves = [];
let _espSuiviLoading = false;
let _espSuiviError = '';

/* ---- État de l'écran de détail (fiche élève + notes) ---- */
let _espSuiviCurrentId = null;
let _espSuiviCurrentEleve = null;
let _espSuiviCurrentNotes = [];
let _espSuiviDetailLoading = false;
let _espSuiviDetailError = '';

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
  if(_espSuiviView === 'detail') return espSuiviRenderDetail();
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
                      <button class="esp-btn" style="padding:5px 10px;font-size:11.5px;" onclick="espSuiviOpenDetail('${e.id}')">${icon('eye')}Voir</button>
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

/* ---------------- Écran de détail (fiche élève + notes de remédiation) ---------------- */
async function espSuiviOpenDetail(id){
  _espSuiviView = 'detail';
  _espSuiviCurrentId = id;
  _espSuiviCurrentEleve = null;
  _espSuiviCurrentNotes = [];
  _espSuiviDetailError = '';
  _espSuiviDetailLoading = true;
  espSuiviRefreshContainer();

  const session = espSession();
  try {
    const [eleve, notes] = await Promise.all([
      espSuiviGetEleveRPC(session.id, session.password, id),
      espSuiviListNotesRPC(session.id, session.password, id),
    ]);
    _espSuiviCurrentEleve = eleve;
    _espSuiviCurrentNotes = notes;
  } catch(e){
    _espSuiviDetailError = "Impossible de charger la fiche : " + e.message;
  }
  _espSuiviDetailLoading = false;
  espSuiviRefreshContainer();
}

function espSuiviRenderDetail(){
  if(_espSuiviDetailLoading){
    return `<div class="esp-card"><button class="esp-back" onclick="espSuiviBackToList()">${icon('arrow-left')}Répertoire de suivi</button><p class="esp-empty">Chargement...</p></div>`;
  }
  if(_espSuiviDetailError || !_espSuiviCurrentEleve){
    return `<div class="esp-card"><button class="esp-back" onclick="espSuiviBackToList()">${icon('arrow-left')}Répertoire de suivi</button><p class="esp-error">${escapeHtml(_espSuiviDetailError || "Élève introuvable.")}</p></div>`;
  }

  const e = _espSuiviCurrentEleve;
  return `
    <div class="esp-card">
      <button class="esp-back" onclick="espSuiviBackToList()">${icon('arrow-left')}Répertoire de suivi</button>
      <div class="esp-title" style="font-size:16px;display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:8px;">
        <span>${icon('user-check')}${escapeHtml(e.nom)} ${escapeHtml(e.prenoms||'')}</span>
        <button class="esp-btn" style="font-size:12.5px;" onclick="espSuiviDownloadReport()">${icon('download')}Rapport imprimable</button>
      </div>
      <p class="esp-sub">${escapeHtml(e.classe)} · Suivi depuis le ${escapeHtml(e.dateAjout)}</p>
      <div style="margin-bottom:18px;">
        ${(e.raisons||[]).map(code => `<span class="esp-badge non_reclame" style="margin:2px 4px 2px 0;">${escapeHtml(espSuiviRaisonLabel(code))}</span>`).join('')}
      </div>

      <h3 style="font-size:14px;color:var(--green-dark);margin:0 0 12px;">Notes de remédiation</h3>
      ${_espSuiviCurrentNotes.length ? _espSuiviCurrentNotes.map(n => `
        <div class="esp-note-item"><b>${escapeHtml(n.date)}</b><br>${escapeHtml(n.texte)}</div>
      `).join('') : `<p class="esp-empty">Aucune note pour le moment.</p>`}

      <div class="esp-field-row" style="margin-top:16px;align-items:flex-end;">
        <div class="esp-field" style="flex:0 0 160px;"><label>Date</label><input type="date" id="esp-suivi-note-date"></div>
        <div class="esp-field" style="flex:2;"><label>Note (activité de remédiation, résultats)</label><textarea id="esp-suivi-note-texte" rows="2"></textarea></div>
      </div>
      <div id="esp-suivi-note-error"></div>
      <button class="esp-btn esp-btn-primary" onclick="espSuiviSubmitNote()">${icon('plus')}Ajouter la note</button>

      <h3 style="font-size:14px;color:var(--green-dark);margin:24px 0 12px;">Appréciation finale</h3>
      <div class="esp-field" style="margin-bottom:8px;">
        <textarea id="esp-suivi-appreciation" rows="3" placeholder="Synthèse de l'évolution de l'élève...">${escapeHtml(e.appreciationFinale||'')}</textarea>
      </div>
      <div id="esp-suivi-appreciation-msg"></div>
      <button class="esp-btn" onclick="espSuiviSaveAppreciation()">${icon('save')}Enregistrer l'appréciation</button>
    </div>
  `;
}

// Convertit la valeur ISO (AAAA-MM-JJ) d'un <input type="date"> vers la
// convention JJ/MM/AAAA utilisée par le reste de l'app (et attendue par
// inspecteur_suivi_add_note / triée via to_date(...,'DD/MM/YYYY') côté SQL).
function espSuiviDateInputToFr(iso){
  if(!iso) return '';
  const [y,m,d] = iso.split('-');
  return `${d}/${m}/${y}`;
}

async function espSuiviSubmitNote(){
  const dateInput = document.getElementById('esp-suivi-note-date');
  const texteInput = document.getElementById('esp-suivi-note-texte');
  const errorEl = document.getElementById('esp-suivi-note-error');
  errorEl.innerHTML = '';
  const dateFr = espSuiviDateInputToFr(dateInput.value);
  const texte = texteInput.value.trim();
  if(!dateFr || !texte){ errorEl.innerHTML = '<p class="esp-error">Date et texte sont obligatoires.</p>'; return; }

  const session = espSession();
  try {
    await espSuiviAddNoteRPC(session.id, session.password, _espSuiviCurrentId, dateFr, texte);
  } catch(e){
    errorEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(e.message) + '</p>';
    return;
  }
  _espSuiviCurrentNotes = await espSuiviListNotesRPC(session.id, session.password, _espSuiviCurrentId);
  espSuiviRefreshContainer();
}

async function espSuiviSaveAppreciation(){
  const textarea = document.getElementById('esp-suivi-appreciation');
  const msgEl = document.getElementById('esp-suivi-appreciation-msg');
  msgEl.innerHTML = '';
  const texte = textarea.value.trim();
  const session = espSession();
  try {
    await espSuiviSetAppreciationRPC(session.id, session.password, _espSuiviCurrentId, texte);
  } catch(e){
    msgEl.innerHTML = '<p class="esp-error">Erreur : ' + escapeHtml(e.message) + '</p>';
    return;
  }
  if(_espSuiviCurrentEleve) _espSuiviCurrentEleve.appreciationFinale = texte;
  msgEl.innerHTML = '<p class="esp-success">Appréciation enregistrée.</p>';
}

/* ---------------- Rapport imprimable (document HTML autonome, même
   principe que espLycamDownloadIndividual/espLycamDownloadReport :
   téléchargé puis imprimé depuis le navigateur, plutôt qu'un window.print()
   du tableau de bord — il n'y a pas de CSS d'impression dédiée sur le reste
   de l'app, alors que le document généré ici est déjà propre et isolé). ---------------- */
function espSuiviRaisonsListHtml(raisons){
  return (raisons||[]).map(code =>
    `<span style="display:inline-block;background:#EEF1FC;color:#3B4CCA;font-size:11px;font-weight:800;padding:3px 10px;border-radius:12px;margin:2px 4px 2px 0;">${escapeHtml(espSuiviRaisonLabel(code))}</span>`
  ).join('');
}

function espSuiviDownloadReport(){
  const e = _espSuiviCurrentEleve;
  if(!e) return;
  const notes = _espSuiviCurrentNotes;
  const notesRows = notes.length
    ? notes.map(n => `<tr><td style="white-space:nowrap;">${escapeHtml(n.date)}</td><td>${escapeHtml(n.texte)}</td></tr>`).join('')
    : `<tr><td colspan="2">Aucune note de remédiation enregistrée.</td></tr>`;
  const body = `
    <h1>${escapeHtml((e.nom + ' ' + (e.prenoms||'')).trim())}</h1>
    <p class="sub">${escapeHtml(e.classe)} · Suivi depuis le ${escapeHtml(e.dateAjout)}</p>
    <h2>Raison(s) du suivi</h2>
    <p>${espSuiviRaisonsListHtml(e.raisons)}</p>
    <h2>Notes de remédiation</h2>
    <table><thead><tr><th>Date</th><th>Note</th></tr></thead><tbody>${notesRows}</tbody></table>
    <h2>Appréciation finale de l'inspecteur</h2>
    <p style="font-size:13.5px;line-height:1.6;">${e.appreciationFinale ? escapeHtml(e.appreciationFinale) : '<i>Aucune appréciation renseignée pour le moment.</i>'}</p>
  `;
  const title = 'Suivi — ' + (e.nom + ' ' + (e.prenoms||'')).trim();
  const html = espLycamReportShell(title, body);
  espLycamTriggerDownload(`Suivi_${espLycamSlugify(e.nom)}_${espLycamSlugify(e.prenoms||'')}.html`, html, 'text/html');
}
