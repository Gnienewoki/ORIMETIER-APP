// ---------------- Page Enseignement Général (page general.html) ----------------
// Contrairement à la page technique/pro, il n'existe aucun contenu statique existant :
// les deux onglets sont entièrement alimentés par les comptes établissements inscrits
// sur la plateforme (catégorie = 'general'), une fois validés par l'administrateur.

function espEtabGeneral(secteur){
  const db = espDB();
  return (db.etablissements || []).filter(e => e.categorie === 'general' && e.secteur === secteur && e.statut === 'valide');
}

function espGeneralRows(secteur){
  const rows = [];
  espEtabGeneral(secteur).forEach(e => {
    const contact = espEtabContactCellHtml(e);
    const nom = espEtabNomCellHtml(e);
    const filieres = e.filieresProposees || [];
    if(!filieres.length){
      rows.push({ nom, ville: e.ville, filiere: '—', contact });
    } else {
      filieres.forEach(f => {
        rows.push({ nom, ville: e.ville, filiere: f.diplome ? `${f.nom} (${f.diplome})` : f.nom, contact });
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

// ---------------- Rendu d'un des deux tableaux (public ou privé) ----------------
function renderGeneralTable(secteur){
  const prefix = 'general-' + secteur;
  const tbody = document.getElementById(prefix + '-results');
  const countEl = document.getElementById(prefix + '-count');
  const emptyEl = document.getElementById(prefix + '-empty-msg');
  if(!tbody) return;

  // Suggestions à jour à chaque rendu (les établissements inscrits peuvent évoluer)
  const allForSector = espEtabGeneral(secteur);
  espFillGeneralDatalist('dl-' + prefix + '-ville', allForSector.map(e => e.ville));
  const allFilieres = [];
  allForSector.forEach(e => (e.filieresProposees||[]).forEach(f => allFilieres.push(f.nom)));
  espFillGeneralDatalist('dl-' + prefix + '-filiere', allFilieres);

  const villeInput = document.getElementById('f-' + prefix + '-ville');
  const filiereInput = document.getElementById('f-' + prefix + '-filiere');
  const qVille = (villeInput ? villeInput.value : '').trim();
  const qFiliere = (filiereInput ? filiereInput.value : '').trim();
  const nVille = normalize(qVille);
  const nFiliere = normalize(qFiliere);

  const rows = espGeneralRows(secteur).filter(r =>
    (!nVille || normalize(r.ville||'').includes(nVille)) &&
    (!nFiliere || normalize(r.filiere||'').includes(nFiliere))
  );

  tbody.innerHTML = '';
  const frag = document.createDocumentFragment();
  rows.forEach(r => {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td>${r.nom}</td><td>${escapeHtml(r.ville||'—')}</td><td>${escapeHtml(r.filiere)}</td><td>${r.contact}</td>`;
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
  const searchPubFiliere = document.getElementById('f-general-public-filiere');
  const searchPrivVille = document.getElementById('f-general-prive-ville');
  const searchPrivFiliere = document.getElementById('f-general-prive-filiere');
  if(searchPubVille) searchPubVille.addEventListener('input', () => renderGeneralTable('public'));
  if(searchPubFiliere) searchPubFiliere.addEventListener('input', () => renderGeneralTable('public'));
  if(searchPrivVille) searchPrivVille.addEventListener('input', () => renderGeneralTable('prive'));
  if(searchPrivFiliere) searchPrivFiliere.addEventListener('input', () => renderGeneralTable('prive'));

  renderGeneralTable('public'); // onglet actif par défaut
}
window.pageInit = initGeneral;
