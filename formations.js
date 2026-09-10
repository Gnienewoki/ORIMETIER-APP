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

// nQuery : requête déjà normalisée (évite un normalize() par appel dans la boucle de rendu).
function highlight(text, query, nQuery){
  if(!query || !text) return text || '';
  const idx = normalize(text).indexOf(nQuery != null ? nQuery : normalize(query));
  if(idx === -1) return text;
  return text.slice(0,idx) + '<mark>' + text.slice(idx, idx+query.length) + '</mark>' + text.slice(idx+query.length);
}

// ---- Pagination : sur smartphone d'entrée de gamme, rendre 351 <tr> à chaque frappe
// bloque le fil principal. On ne rend que la page courante. ----
const F_PAGE_SIZE = 60;
let _fPage = 1;

function render(){
  const qf = inputs.filiere.value.trim();
  const qd = inputs.diplome.value.trim();
  const qe = inputs.etablissement.value.trim();
  const nqf = normalize(qf), nqd = normalize(qd), nqe = normalize(qe);

  const filtered = DATA.filter(([filiere, diplome, etab]) =>
    normalize(filiere).includes(nqf) &&
    normalize(diplome).includes(nqd) &&
    normalize(etab).includes(nqe)
  );

  const total = filtered.length;
  const pages = Math.max(1, Math.ceil(total / F_PAGE_SIZE));
  if(_fPage > pages) _fPage = pages;
  if(_fPage < 1) _fPage = 1;
  const start = (_fPage - 1) * F_PAGE_SIZE;
  const pageRows = filtered.slice(start, start + F_PAGE_SIZE);

  tbody.innerHTML = '';
  const frag = document.createDocumentFragment();
  pageRows.forEach(([filiere, diplome, etab]) => {
    const tr = document.createElement('tr');
    const hasFiche = !!findFiche(filiere);
    const btn = filiere
      ? `<button class="fiche-btn" ${hasFiche ? '' : 'disabled'} data-filiere="${escapeHtml(filiere)}">${hasFiche ? '📄 Voir' : 'Indisponible'}</button>`
      : '';
    tr.innerHTML =
      `<td data-label="Filière">${highlight(filiere, qf, nqf)}</td>` +
      `<td data-label="Diplôme">${highlight(diplome, qd, nqd)}</td>` +
      `<td data-label="Établissement">${highlight(etab, qe, nqe)}</td>` +
      `<td data-label="Fiche métier">${btn}</td>`;
    frag.appendChild(tr);
  });
  tbody.appendChild(frag);

  const wrap = tbody.closest('.table-wrap');
  if(wrap) wrap.hidden = total === 0;

  countEl.textContent = total + ' résultat' + (total > 1 ? 's' : '') + ' sur ' + DATA.length;
  renderFormationsPager(_fPage, pages);
  renderFormationsEmpty(total === 0);
}

function renderFormationsPager(page, pages){
  const el = document.getElementById('results-pager');
  if(!el) return;
  if(pages <= 1){ el.innerHTML = ''; el.hidden = true; return; }
  el.hidden = false;
  el.innerHTML =
    `<button class="o-pager__btn" type="button" data-nav="prev"${page <= 1 ? ' disabled' : ''} aria-label="Page précédente">${icon('chevron-left')}<span>Précédent</span></button>` +
    `<span class="o-pager__info">Page ${page} / ${pages}</span>` +
    `<button class="o-pager__btn" type="button" data-nav="next"${page >= pages ? ' disabled' : ''} aria-label="Page suivante"><span>Suivant</span>${icon('chevron-right')}</button>`;
  espRefreshIcons();
}

function renderFormationsEmpty(isEmpty){
  if(!emptyMsg) return;
  if(!isEmpty){ emptyMsg.hidden = true; emptyMsg.innerHTML = ''; return; }
  emptyMsg.hidden = false;
  emptyMsg.innerHTML =
    `<div class="o-empty">` +
      `<div class="o-empty__icon">${icon('search-x', { lg: true })}</div>` +
      `<p class="o-empty__title">Aucune filière ne correspond</p>` +
      `<p class="o-empty__text">Aucun résultat pour ces filtres. Essaie une autre orthographe, ou élargis ta recherche.</p>` +
      `<button class="o-empty__action" type="button" onclick="resetFilters()">${icon('filter-x')}<span>Réinitialiser les filtres</span></button>` +
    `</div>`;
  espRefreshIcons();
}

function resetFilters(){
  inputs.filiere.value = '';
  inputs.diplome.value = '';
  inputs.etablissement.value = '';
  _fPage = 1;
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
  const filtrer = espDebounce(() => { _fPage = 1; render(); }, 180);
  Object.values(inputs).forEach(inp => inp.addEventListener('input', filtrer));

  const pager = document.getElementById('results-pager');
  if(pager) pager.addEventListener('click', e => {
    const b = e.target.closest('[data-nav]');
    if(!b || b.disabled) return;
    _fPage += (b.dataset.nav === 'next' ? 1 : -1);
    render();
    const wrap = document.querySelector('#etab-tab-publics .table-wrap');
    if(wrap) wrap.scrollTop = 0;
  });

  const totalCountEl = document.getElementById('total-formations-count');
  if(totalCountEl) totalCountEl.textContent = DATA.length;
  render();
  espFillPublicDatalists();

  const searchVille = document.getElementById('f-etab-prive-ville');
  const searchFiliere = document.getElementById('f-etab-prive-filiere');
  if(searchVille) searchVille.addEventListener('input', renderEtabPrivesList);
  if(searchFiliere) searchFiliere.addEventListener('input', renderEtabPrivesList);

  const techTbody = document.getElementById('etab-technique-results');
  if(techTbody){
    techTbody.addEventListener('click', e => {
      const btn = e.target.closest('.fiche-btn');
      if(!btn) return;
      openTechniqueFiche(Number(btn.dataset.techIndex));
    });
    renderEtabTechniqueList();
  }
}
window.pageInit = initFormations;

// Appelé par bootstrap.js quand les données Supabase sont arrivées (le tableau
// public des 351 filières, lui, est déjà affiché : il ne dépend que de DATA).
// Complète l'onglet "Établissements privés" — datalists + liste si l'onglet est ouvert.
window.pageDataReady = function(){
  if(typeof espFillPriveDatalists === 'function') espFillPriveDatalists();
  const priv = document.getElementById('etab-tab-prive');
  if(priv && priv.style.display !== 'none' && typeof renderEtabPrivesList === 'function'){
    renderEtabPrivesList();
  }
};

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
  const tech = document.getElementById('etab-tab-technique');
  const btnPub = document.getElementById('etab-subtab-btn-publics');
  const btnPriv = document.getElementById('etab-subtab-btn-prive');
  const btnTech = document.getElementById('etab-subtab-btn-technique');
  if(!pub || !priv) return;
  pub.style.display = tab === 'publics' ? '' : 'none';
  priv.style.display = tab === 'prive' ? '' : 'none';
  if(tech) tech.style.display = tab === 'technique' ? '' : 'none';
  if(btnPub) btnPub.classList.toggle('active', tab === 'publics');
  if(btnPriv) btnPriv.classList.toggle('active', tab === 'prive');
  if(btnTech) btnTech.classList.toggle('active', tab === 'technique');
  if(tab === 'prive') renderEtabPrivesList();
}

// ---------------- Sous-onglet "Enseignement technique" : parcours Seconde → débouché (contenu statique, pas de Supabase) ----------------
const ESP_TECH_PARCOURS = [
  { seconde:'G1', premiere:'G1', terminale:'G1', bac:'BAC G1', metier:'Techniques administratives et bureautique', debouche:'Université / Grande école', ageMax:20 },
  { seconde:'G2', premiere:'G2', terminale:'G2', bac:'BAC G2', metier:'Comptabilité', debouche:'Université / Grande école', ageMax:20 },
  { seconde:'AB', premiere:'B', terminale:'B', bac:'BAC B', metier:'Économie et social', debouche:'Université / Grande école', ageMax:19 },
  { seconde:'T1', premiere:'E', terminale:'E', bac:'BAC E', metier:'Mathématique et technologie', debouche:'Université / Grande école', ageMax:19 },
  { seconde:'T1', premiere:'F1', terminale:'F1', bac:'BAC F1', metier:'Construction mécanique', debouche:'Université / Grande école', ageMax:19 },
  { seconde:'T1', premiere:'F2', terminale:'F2', bac:'BAC F2', metier:'Électronique', debouche:'Université / Grande école', ageMax:19 },
  { seconde:'T1', premiere:'F3', terminale:'F3', bac:'BAC F3', metier:'Électrotechnique', debouche:'Université / Grande école', ageMax:19 },
  { seconde:'T2', premiere:'F4', terminale:'F4', bac:'BAC F4', metier:'Génie civil', debouche:'Université / Grande école', ageMax:20 },
  { seconde:'T3', premiere:'F7', terminale:'F7', bac:'BAC F7', metier:'Biochimie', debouche:'Université / Grande école', ageMax:20 },
];

function renderEtabTechniqueList(){
  const tbody = document.getElementById('etab-technique-results');
  if(!tbody) return;
  tbody.innerHTML = '';
  const frag = document.createDocumentFragment();
  ESP_TECH_PARCOURS.forEach((p, i) => {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td>${escapeHtml(p.seconde)}</td><td>${escapeHtml(p.premiere)}</td><td>${escapeHtml(p.terminale)}</td><td>${escapeHtml(p.bac)}</td><td>${escapeHtml(p.metier)}</td><td>${escapeHtml(p.debouche)}</td><td><button class="fiche-btn" data-tech-index="${i}">🔎 Voir</button></td>`;
    frag.appendChild(tr);
  });
  tbody.appendChild(frag);
}

function openTechniqueFiche(index){
  const p = ESP_TECH_PARCOURS[index];
  if(!p) return;
  const tagsHtml = [p.bac, p.debouche].filter(Boolean).map(t => `<span class="tag">${escapeHtml(t)}</span>`).join('');
  const ageLabel = p.ageMax === 19
    ? `19 ans au plus (série ${escapeHtml(p.seconde)}, sans avoir redoublé la classe de 3e)`
    : `20 ans au plus pour l'enseignement technique`;
  const bodyHtml = `
    <h3>Parcours</h3>
    <p>Seconde ${escapeHtml(p.seconde)} → 1ère ${escapeHtml(p.premiere)} → Terminale ${escapeHtml(p.terminale)} → ${escapeHtml(p.bac)} → ${escapeHtml(p.debouche)}</p>
    <h3>Conditions d'accès</h3>
    <div class="ca-variant">
      <div class="ca-row"><b>Nationalité :</b> être de nationalité ivoirienne.</div>
      <div class="ca-row"><b>Scolarité :</b> être régulièrement inscrit(e) en classe de 3e.</div>
      <div class="ca-row"><b>Limite d'âge :</b> ${ageLabel}.</div>
      <div class="ca-row"><b>Diplôme :</b> le BEPC est une condition générale d'accès à l'enseignement technique (exigé notamment pour certaines filières spécifiques, comme les Sciences médico-sociales).</div>
    </div>
  `;
  openModal(p.metier, tagsHtml, bodyHtml);
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
    const contact = espEtabContactCellHtml(e);
    const nom = espEtabNomCellHtml(e);
    const filieres = e.filieresProposees || [];
    if(!filieres.length){
      rows.push({ nom, ville: e.ville, filiere: '—', contact });
    } else {
      filieres.forEach(f => {
        if(!nFiliere || normalize(f.nom||'').includes(nFiliere)){
          rows.push({ nom, ville: e.ville, filiere: f.diplome ? `${f.nom} (${f.diplome})` : f.nom, contact });
        }
      });
    }
  });

  tbodyPrive.innerHTML = '';
  const frag = document.createDocumentFragment();
  rows.forEach(r => {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td>${r.nom}</td><td>${escapeHtml(r.ville||'—')}</td><td>${escapeHtml(r.filiere)}</td><td>${r.contact}</td>`;
    frag.appendChild(tr);
  });
  tbodyPrive.appendChild(frag);

  if(countEl) countEl.textContent = rows.length + ' résultat' + (rows.length>1?'s':'');
  if(emptyEl) emptyEl.style.display = rows.length === 0 ? 'block' : 'none';
}
