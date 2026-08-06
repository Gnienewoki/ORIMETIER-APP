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

  const searchPrive = document.getElementById('f-etab-prive-search');
  if(searchPrive) searchPrive.addEventListener('input', renderEtabPrivesList);
}
window.pageInit = initFormations;

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
  const container = document.getElementById('etab-prive-list');
  if(!container) return;
  const searchInput = document.getElementById('f-etab-prive-search');
  const query = (searchInput ? searchInput.value : '').trim();
  const nq = normalize(query);
  const list = espEtabPrivesTechnique().filter(e => !nq || normalize((e.nom||'') + ' ' + (e.ville||'')).includes(nq));

  if(!list.length){
    container.innerHTML = `<p class="empty" style="padding:30px;">Aucun établissement privé référencé pour le moment${query ? ' pour « ' + escapeHtml(query) + ' »' : ''}.</p>`;
    return;
  }

  container.innerHTML = list.map(e => `
    <div class="esp-card" style="margin-bottom:14px;">
      <div class="esp-title" style="font-size:16px;">🏢 ${escapeHtml(e.nom)}</div>
      <p class="esp-sub">${[e.ville, e.quartier, e.region].filter(Boolean).map(escapeHtml).join(' · ')}</p>
      ${(e.photos||[]).length ? `<div class="esp-etab-photos-grid" style="margin-bottom:12px;">${e.photos.map(u => `<div class="esp-etab-photo-thumb"><img src="${escapeHtml(u)}" alt="Photo établissement"></div>`).join('')}</div>` : ''}
      ${(e.filieresProposees||[]).length ? `
        <p style="font-size:12.5px;font-weight:700;color:var(--green-dark);margin:10px 0 6px;">Filières proposées :</p>
        <div>${e.filieresProposees.map(f => `<span class="riasec-chip" style="margin:0 6px 6px 0;display:inline-block;">${escapeHtml(f.nom)} (${escapeHtml(f.diplome)})</span>`).join('')}</div>
      ` : `<p class="esp-empty">Aucune filière renseignée pour le moment.</p>`}
      <p class="esp-sub" style="margin-top:10px;">📞 ${escapeHtml(e.tel||'—')} · ✉️ ${escapeHtml(e.email||'—')}</p>
    </div>
  `).join('');
}
