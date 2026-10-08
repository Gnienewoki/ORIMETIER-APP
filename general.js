// ---------------- Page Enseignement Général (page general.html) ----------------
// Contrairement à la page technique/pro, il n'existe aucun contenu statique existant :
// les deux onglets sont entièrement alimentés par les comptes établissements inscrits
// sur la plateforme (catégorie = 'general'), une fois validés par l'administrateur.

function espEtabGeneral(secteur){
  const db = espDB();
  return (db.etablissements || []).filter(e => e.categorie === 'general' && e.secteur === secteur && e.statut === 'valide');
}

// Chaque filière stocke son Cycle dans "nom" et son Diplôme dans "diplome" (cf.
// etablissement.js) : une ligne du tableau par filière, colonnes affichées telles quelles.
// nomTexte : nom brut de l'établissement (nom = cellule HTML), utilisé par le filtre.
function espGeneralRows(secteur){
  const rows = [];
  espEtabGeneral(secteur).forEach(e => {
    const contact = espEtabContactCellHtml(e);
    const nom = espEtabNomCellHtml(e);
    const filieres = e.filieresProposees || [];
    if(!filieres.length){
      rows.push({ nom, nomTexte: e.nom, ville: e.ville, cycle: '—', diplome: '—', contact });
    } else {
      filieres.forEach(f => {
        rows.push({ nom, nomTexte: e.nom, ville: e.ville, cycle: f.nom || '—', diplome: f.diplome || '—', contact });
      });
    }
  });
  return rows;
}

// ---------------- Rendu d'un des deux tableaux (public ou privé) ----------------
// Filtres Ville et Établissement (combinés en ET) : recherche d'un morceau du texte, sans
// tenir compte de la casse, des accents ni de la ponctuation (espTexteRecherche).
function renderGeneralTable(secteur){
  const prefix = 'general-' + secteur;
  const tbody = document.getElementById(prefix + '-results');
  const countEl = document.getElementById(prefix + '-count');
  const emptyEl = document.getElementById(prefix + '-empty-msg');
  if(!tbody) return;

  const villeInput = document.getElementById('f-' + prefix + '-ville');
  const nomInput = document.getElementById('f-' + prefix + '-nom');
  const nVille = espTexteRecherche(villeInput ? villeInput.value : '');
  const nNom = espTexteRecherche(nomInput ? nomInput.value : '');
  const villeCorrespond = v => !nVille || espTexteRecherche(v).includes(nVille);

  // Suggestions reconstruites à chaque rendu (les établissements inscrits peuvent évoluer) :
  // villes de l'onglet ; noms des établissements de l'onglet, restreints à la ville saisie.
  const allForSector = espEtabGeneral(secteur);
  espFillDatalist('dl-' + prefix + '-ville', allForSector.map(e => e.ville));
  espFillDatalist('dl-' + prefix + '-nom', allForSector.filter(e => villeCorrespond(e.ville)).map(e => e.nom));

  const rows = espGeneralRows(secteur).filter(r => {
    if(!villeCorrespond(r.ville)) return false;
    if(nNom && !espTexteRecherche(r.nomTexte).includes(nNom) && !espTexteRecherche(r.ville).includes(nNom)) return false;
    return true;
  });

  tbody.innerHTML = '';
  const frag = document.createDocumentFragment();
  rows.forEach(r => {
    const tr = document.createElement('tr');
    tr.innerHTML =
      `<td data-label="Établissement">${r.nom}</td>` +
      `<td data-label="Ville">${escapeHtml(r.ville||'—')}</td>` +
      `<td data-label="Cycle">${escapeHtml(r.cycle)}</td>` +
      `<td data-label="Diplôme">${escapeHtml(r.diplome)}</td>` +
      `<td data-label="Contact">${r.contact}</td>`;
    frag.appendChild(tr);
  });
  tbody.appendChild(frag);
  const wrap = tbody.closest('.table-wrap');
  if(wrap) wrap.hidden = rows.length === 0;

  if(countEl) countEl.textContent = rows.length + ' résultat' + (rows.length>1?'s':'');

  if(rows.length === 0){
    const filtres = !!(nVille || nNom);
    const label = secteur === 'prive' ? 'privé' : 'public';
    espRenderEmptyState(emptyEl, filtres ? {
      icon: 'search-x',
      title: 'Aucun résultat',
      text: nNom ? 'Aucun établissement ne correspond à votre recherche.' : 'Aucun établissement ' + label + " d'enseignement général ne correspond à ces filtres.",
      actionLabel: 'Réinitialiser',
      actionIcon: 'filter-x',
      onAction: () => resetGeneralFilters(secteur),
    } : {
      icon: 'school',
      title: 'Rien pour le moment',
      text: 'Aucun établissement ' + label + " d'enseignement général n'est encore référencé sur la plateforme.",
    });
  } else {
    espHideEmptyState(emptyEl);
  }
}

function resetGeneralFilters(secteur){
  const prefix = 'general-' + secteur;
  const ville = document.getElementById('f-' + prefix + '-ville');
  const nom = document.getElementById('f-' + prefix + '-nom');
  if(ville) ville.value = '';
  espClearSearchField(nom);
  renderGeneralTable(secteur);
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
  const searchPubNom = document.getElementById('f-general-public-nom');
  const searchPrivVille = document.getElementById('f-general-prive-ville');
  const searchPrivNom = document.getElementById('f-general-prive-nom');
  const renderPublicDebounced = espDebounce(() => renderGeneralTable('public'), 180);
  const renderPriveDebounced = espDebounce(() => renderGeneralTable('prive'), 180);
  if(searchPubVille) searchPubVille.addEventListener('input', renderPublicDebounced);
  if(searchPrivVille) searchPrivVille.addEventListener('input', renderPriveDebounced);
  espBindSearchField(searchPubNom, () => renderGeneralTable('public'));
  espBindSearchField(searchPrivNom, () => renderGeneralTable('prive'));

  renderGeneralTable('public'); // onglet actif par défaut
}
window.pageInit = initGeneral;
