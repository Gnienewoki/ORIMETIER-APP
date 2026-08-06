// ---------------- Annuaire des formations (page index.html) ----------------
let tbody, countEl, emptyMsg, inputs;

// --- Fiches métiers : index par formation associée ---
const ficheByFormation = {};
FICHES.forEach((f, i) => { ficheByFormation[normalize(f.formation)] = i; });

function findFiche(filiere){
  const n = normalize(filiere);
  if(n in ficheByFormation) return FICHES[ficheByFormation[n]];
  if(filiere in ALIASES){
    const aliasNorm = normalize(ALIASES[filiere]);
    if(aliasNorm in ficheByFormation) return FICHES[ficheByFormation[aliasNorm]];
  }
  return null;
}

function listBlock(items){
  if(!items || !items.length) return '';
  return '<ul>' + items.map(it => `<li>${escapeHtml(it)}</li>`).join('') + '</ul>';
}

function conditionsAccesBlock(formation){
  const cond = CONDITIONS_ACCES[formation];
  if(!cond || !cond.variants || !cond.variants.length){
    return `<p class="ca-indispo">Fiche des conditions d'accès non disponible pour cette filière pour le moment.</p>`;
  }
  const variantsHtml = cond.variants.map(v => `
    <div class="ca-variant">
      <div class="ca-variant-head">
        <span class="ca-diplome">${escapeHtml(v.diplome)}</span>
        ${cond.approx ? `<span class="ca-proche" title="Filière la plus proche dans le référentiel officiel">≈ ${escapeHtml(v.specialite)}</span>` : ''}
      </div>
      <div class="ca-row"><b>Niveau &amp; âge requis :</b> ${escapeHtml(v.niveau_age).replace(/\n/g,'<br>')}</div>
      <div class="ca-row"><b>Moyennes minimales exigées :</b> ${escapeHtml(v.moyennes)}</div>
      <div class="ca-row"><b>Établissements d'accueil :</b> ${escapeHtml(v.etablissements)}</div>
    </div>
  `).join('');
  return `
    <div class="ca-commun">${escapeHtml(CONDITIONS_COMMUNES)}</div>
    ${variantsHtml}
  `;
}

function openFiche(filiere){
  const fiche = findFiche(filiere);
  if(!fiche){
    openModal(filiere || 'Filière', '', `<p class="modal-no-fiche">Aucune fiche métier détaillée n'est disponible pour cette filière pour le moment.</p>`);
    return;
  }
  const tagsHtml = [fiche.secteur, fiche.niveau].filter(Boolean)
    .map(t => `<span class="tag">${escapeHtml(t)}</span>`).join('');
  const isFiliere = fiche.type === 'filiere';
  const bodyHtml = `
    <h3>${isFiliere ? 'Présentation de la filière' : 'Description du métier'}</h3>
    <p>${escapeHtml(fiche.description)}</p>
    <h3>${isFiliere ? 'Programme et matières clés' : 'Missions principales'}</h3>
    ${listBlock(fiche.missions)}
    <h3>${isFiliere ? 'Compétences développées' : 'Compétences requises'}</h3>
    ${listBlock(fiche.competences)}
    <h3>${isFiliere ? 'Profil recommandé' : 'Qualités personnelles'}</h3>
    ${listBlock(fiche.qualites)}
    <h3>${isFiliere ? 'Cadre de formation' : 'Environnement de travail'}</h3>
    <p>${escapeHtml(fiche.environnement)}</p>
    <h3>${isFiliere ? 'Débouchés après le Bac' : 'Débouchés et employeurs potentiels'}</h3>
    ${listBlock(fiche.debouches)}
    <h3>${isFiliere ? 'Poursuite d\'études' : 'Évolution de carrière'}</h3>
    <p>${escapeHtml(fiche.evolution)}</p>
    <h3>Conditions d'accès à la filière</h3>
    ${conditionsAccesBlock(fiche.formation)}
  `;
  openModal(fiche.titre, tagsHtml, bodyHtml);
}

function highlight(text, query){
  if(!query || !text) return text || '';
  const idx = normalize(text).indexOf(normalize(query));
  if(idx === -1) return text;
  return text.slice(0,idx) + '<mark>' + text.slice(idx, idx+query.length) + '</mark>' + text.slice(idx+query.length);
}

function render(){
  const qf = inputs.filiere.value.trim();
  const qd = inputs.diplome.value.trim();
  const qe = inputs.etablissement.value.trim();

  const filtered = DATA.filter(([filiere, diplome, etab]) =>
    normalize(filiere).includes(normalize(qf)) &&
    normalize(diplome).includes(normalize(qd)) &&
    normalize(etab).includes(normalize(qe))
  );

  tbody.innerHTML = '';
  const frag = document.createDocumentFragment();
  filtered.forEach(([filiere, diplome, etab]) => {
    const tr = document.createElement('tr');
    const hasFiche = !!findFiche(filiere);
    const btn = filiere
      ? `<button class="fiche-btn" ${hasFiche ? '' : 'disabled'} data-filiere="${escapeHtml(filiere)}">${hasFiche ? '📄 Voir' : 'Indisponible'}</button>`
      : '';
    tr.innerHTML = `<td>${highlight(filiere, qf)}</td><td>${highlight(diplome, qd)}</td><td>${highlight(etab, qe)}</td><td>${btn}</td>`;
    frag.appendChild(tr);
  });
  tbody.appendChild(frag);

  countEl.textContent = filtered.length + ' résultat' + (filtered.length>1?'s':'') + ' sur ' + DATA.length;
  emptyMsg.style.display = filtered.length === 0 ? 'block' : 'none';
}

function resetFilters(){
  inputs.filiere.value = '';
  inputs.diplome.value = '';
  inputs.etablissement.value = '';
  render();
}

function initFormations(){
  tbody = document.getElementById('results');
  countEl = document.getElementById('count');
  emptyMsg = document.getElementById('empty-msg');
  inputs = {
    filiere: document.getElementById('f-filiere'),
    diplome: document.getElementById('f-diplome'),
    etablissement: document.getElementById('f-etablissement'),
  };
  tbody.addEventListener('click', e => {
    const btn = e.target.closest('.fiche-btn');
    if(!btn || btn.disabled) return;
    openFiche(btn.dataset.filiere);
  });
  Object.values(inputs).forEach(inp => inp.addEventListener('input', render));
  const totalCountEl = document.getElementById('total-formations-count');
  if(totalCountEl) totalCountEl.textContent = DATA.length;
  render();
  espFillPublicDatalists();

  const searchVille = document.getElementById('f-etab-prive-ville');
  const searchFiliere = document.getElementById('f-etab-prive-filiere');
  if(searchVille) searchVille.addEventListener('input', renderEtabPrivesList);
  if(searchFiliere) searchFiliere.addEventListener('input', renderEtabPrivesList);
}
window.pageInit = initFormations;

// ---------------- Assistant de saisie (suggestions natives du navigateur) ----------------
function espFillDatalist(id, values){
  const dl = document.getElementById(id);
  if(!dl) return;
  const unique = Array.from(new Set(values.filter(Boolean))).sort((a,b) => a.localeCompare(b, 'fr'));
  dl.innerHTML = unique.map(v => `<option value="${escapeHtml(v)}">`).join('');
}
function espFillPublicDatalists(){
  espFillDatalist('dl-filiere-publique', DATA.map(d => d[0]));
  espFillDatalist('dl-diplome-publique', DATA.map(d => d[1]));
  espFillDatalist('dl-etablissement-publique', DATA.map(d => d[2]));
}
function espFillPriveDatalists(){
  const list = espEtabPrivesTechnique();
  espFillDatalist('dl-ville-privee', list.map(e => e.ville));
  const filieres = [];
  list.forEach(e => (e.filieresProposees||[]).forEach(f => filieres.push(f.nom)));
  espFillDatalist('dl-filiere-privee', filieres);
}

// ---------------- Sous-onglets Établissements publics / privés ----------------
function espShowEtabSubTab(tab){
  const pub = document.getElementById('etab-tab-publics');
  const priv = document.getElementById('etab-tab-prive');
  const btnPub = document.getElementById('etab-subtab-btn-publics');
  const btnPriv = document.getElementById('etab-subtab-btn-prive');
  if(!pub || !priv) return;
  pub.style.display = tab === 'publics' ? '' : 'none';
  priv.style.display = tab === 'prive' ? '' : 'none';
  if(btnPub) btnPub.classList.toggle('active', tab === 'publics');
  if(btnPriv) btnPriv.classList.toggle('active', tab === 'prive');
  if(tab === 'prive') renderEtabPrivesList();
}

// Établissements privés d'enseignement technique et de formation professionnelle,
// validés par l'administration : seuls ceux-là sont visibles des visiteurs.
function espEtabPrivesTechnique(){
  const db = espDB();
  return (db.etablissements || []).filter(e => e.categorie === 'technique' && e.secteur === 'prive' && e.statut === 'valide');
}

function renderEtabPrivesList(){
  const tbodyPrive = document.getElementById('etab-prive-results');
  const countEl = document.getElementById('etab-prive-count');
  const emptyEl = document.getElementById('etab-prive-empty-msg');
  if(!tbodyPrive) return;
  espFillPriveDatalists();
  const villeInput = document.getElementById('f-etab-prive-ville');
  const filiereInput = document.getElementById('f-etab-prive-filiere');
  const qVille = (villeInput ? villeInput.value : '').trim();
  const qFiliere = (filiereInput ? filiereInput.value : '').trim();
  const nVille = normalize(qVille);
  const nFiliere = normalize(qFiliere);

  const etabs = espEtabPrivesTechnique().filter(e => {
    const villeOk = !nVille || normalize(e.ville||'').includes(nVille);
    const filiereOk = !nFiliere || (e.filieresProposees||[]).some(f => normalize(f.nom||'').includes(nFiliere));
    return villeOk && filiereOk;
  });

  // Une ligne par filière proposée, comme pour le tableau public (une ligne par filière/diplôme/établissement).
  // Se remplit automatiquement dès qu'un établissement est validé par l'admin — aucune saisie manuelle.
  const rows = [];
  etabs.forEach(e => {
    const contact = [e.tel, e.email].filter(Boolean).join(' · ') || '—';
    const filieres = e.filieresProposees || [];
    if(!filieres.length){
      rows.push({ nom: e.nom, ville: e.ville, filiere: '—', contact });
    } else {
      filieres.forEach(f => {
        if(!nFiliere || normalize(f.nom||'').includes(nFiliere)){
          rows.push({ nom: e.nom, ville: e.ville, filiere: f.diplome ? `${f.nom} (${f.diplome})` : f.nom, contact });
        }
      });
    }
  });

  tbodyPrive.innerHTML = '';
  const frag = document.createDocumentFragment();
  rows.forEach(r => {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td>${escapeHtml(r.nom)}</td><td>${escapeHtml(r.ville||'—')}</td><td>${escapeHtml(r.filiere)}</td><td>${escapeHtml(r.contact)}</td>`;
    frag.appendChild(tr);
  });
  tbodyPrive.appendChild(frag);

  if(countEl) countEl.textContent = rows.length + ' résultat' + (rows.length>1?'s':'');
  if(emptyEl) emptyEl.style.display = rows.length === 0 ? 'block' : 'none';
}
