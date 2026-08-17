// ---------------- Page Enseignement Général (page general.html) ----------------
// Contrairement à la page technique/pro, il n'existe aucun contenu statique existant :
// les deux onglets sont entièrement alimentés par les comptes établissements inscrits
// sur la plateforme (catégorie = 'general'), une fois validés par l'administrateur.

function espEtabGeneral(secteur){
  const db = espDB();
  return (db.etablissements || []).filter(e => e.categorie === 'general' && e.secteur === secteur && e.statut === 'valide');
}

// Chaque filière stocke son Cycle dans "nom" et son Diplôme dans "diplome" (cf.
// etablissement.js, saisie via menus déroulants Cycle -> Diplôme + "Autre" texte libre).
// Un "Autre" personnalisé reste affiché ici (l'établissement l'a bien renseigné) mais ne
// pourra jamais correspondre à un filtre Cycle/Diplôme (listes fermées, cf. utils.js).
function espGeneralRows(secteur){
  const rows = [];
  espEtabGeneral(secteur).forEach(e => {
    const contact = espEtabContactCellHtml(e);
    const nom = espEtabNomCellHtml(e);
    const filieres = e.filieresProposees || [];
    if(!filieres.length){
      rows.push({ nom, ville: e.ville, cycle: '—', diplome: '—', contact });
    } else {
      filieres.forEach(f => {
        rows.push({ nom, ville: e.ville, cycle: f.nom || '—', diplome: f.diplome || '—', contact });
      });
    }
  });
  return rows;
}

// ---------------- Assistant de saisie (suggestions natives du navigateur) ----------------
function espFillGeneralDatalist(id, values){
  const dl = document.getElementById(id);
  if(!dl) return;
  const unique = Array.from(new Set(values.filter(Boolean))).sort((a,b) => a.localeCompare(b, 'fr'));
  dl.innerHTML = unique.map(v => `<option value="${escapeHtml(v)}">`).join('');
}

// ---------------- Filtre Diplôme dépendant du Cycle choisi (listes fermées, cf. utils.js) ----------------
function espGeneralFilterCycleChange(secteur){
  const prefix = 'general-' + secteur;
  const cycleSelect = document.getElementById('f-' + prefix + '-cycle');
  const diplomeSelect = document.getElementById('f-' + prefix + '-diplome');
  if(!cycleSelect || !diplomeSelect) return;
  const diplomes = espGeneralDiplomesPourCycle(cycleSelect.value);
  diplomeSelect.innerHTML = '<option value="">Tous</option>'
    + diplomes.map(d => `<option value="${escapeHtml(d)}">${escapeHtml(d)}</option>`).join('');
  renderGeneralTable(secteur);
}

// ---------------- Rendu d'un des deux tableaux (public ou privé) ----------------
function renderGeneralTable(secteur){
  const prefix = 'general-' + secteur;
  const tbody = document.getElementById(prefix + '-results');
  const countEl = document.getElementById(prefix + '-count');
  const emptyEl = document.getElementById(prefix + '-empty-msg');
  if(!tbody) return;

  // Suggestions de ville à jour à chaque rendu (les établissements inscrits peuvent évoluer)
  const allForSector = espEtabGeneral(secteur);
  espFillGeneralDatalist('dl-' + prefix + '-ville', allForSector.map(e => e.ville));

  const villeInput = document.getElementById('f-' + prefix + '-ville');
  const cycleSelect = document.getElementById('f-' + prefix + '-cycle');
  const diplomeSelect = document.getElementById('f-' + prefix + '-diplome');
  const qVille = (villeInput ? villeInput.value : '').trim();
  const qCycle = cycleSelect ? cycleSelect.value : '';
  const qDiplome = diplomeSelect ? diplomeSelect.value : '';
  const nVille = normalize(qVille);

  // Comparaison exacte sur Cycle/Diplôme (listes fermées) : un "Autre" personnalisé ne
  // correspond jamais à ces valeurs prédéfinies et n'apparaît donc que quand aucun filtre
  // Cycle/Diplôme n'est actif, jamais comme résultat d'un filtre.
  const rows = espGeneralRows(secteur).filter(r =>
    (!nVille || normalize(r.ville||'').includes(nVille)) &&
    (!qCycle || r.cycle === qCycle) &&
    (!qDiplome || r.diplome === qDiplome)
  );

  tbody.innerHTML = '';
  const frag = document.createDocumentFragment();
  rows.forEach(r => {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td>${r.nom}</td><td>${escapeHtml(r.ville||'—')}</td><td>${escapeHtml(r.cycle)}</td><td>${escapeHtml(r.diplome)}</td><td>${r.contact}</td>`;
    frag.appendChild(tr);
  });
  tbody.appendChild(frag);

  if(countEl) countEl.textContent = rows.length + ' résultat' + (rows.length>1?'s':'');
  if(emptyEl) emptyEl.style.display = rows.length === 0 ? 'block' : 'none';
}

// ---------------- Sous-onglets Public / Privé ----------------
function espShowGeneralSubTab(tab){
  const pub = document.getElementById('general-tab-public');
  const priv = document.getElementById('general-tab-prive');
  const btnPub = document.getElementById('general-subtab-btn-public');
  const btnPriv = document.getElementById('general-subtab-btn-prive');
  if(!pub || !priv) return;
  pub.style.display = tab === 'public' ? '' : 'none';
  priv.style.display = tab === 'prive' ? '' : 'none';
  if(btnPub) btnPub.classList.toggle('active', tab === 'public');
  if(btnPriv) btnPriv.classList.toggle('active', tab === 'prive');
  renderGeneralTable(tab === 'prive' ? 'prive' : 'public');
}

function initGeneral(){
  const searchPubVille = document.getElementById('f-general-public-ville');
  const searchPubCycle = document.getElementById('f-general-public-cycle');
  const searchPubDiplome = document.getElementById('f-general-public-diplome');
  const searchPrivVille = document.getElementById('f-general-prive-ville');
  const searchPrivCycle = document.getElementById('f-general-prive-cycle');
  const searchPrivDiplome = document.getElementById('f-general-prive-diplome');
  if(searchPubVille) searchPubVille.addEventListener('input', () => renderGeneralTable('public'));
  if(searchPubCycle) searchPubCycle.addEventListener('change', () => espGeneralFilterCycleChange('public'));
  if(searchPubDiplome) searchPubDiplome.addEventListener('change', () => renderGeneralTable('public'));
  if(searchPrivVille) searchPrivVille.addEventListener('input', () => renderGeneralTable('prive'));
  if(searchPrivCycle) searchPrivCycle.addEventListener('change', () => espGeneralFilterCycleChange('prive'));
  if(searchPrivDiplome) searchPrivDiplome.addEventListener('change', () => renderGeneralTable('prive'));

  renderGeneralTable('public'); // onglet actif par défaut
}
window.pageInit = initGeneral;
