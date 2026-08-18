// ---------------- Enseignement supérieur (page superieur.html) ----------------
// Onglets "Universités publiques", "Grandes écoles publiques" et "Filière -> Débouchés" :
// chargés depuis Supabase (tables universites/universite_filieres/debouches_filieres/
// grandes_ecoles/grande_ecole_filieres), éditables sans toucher au code ni redéployer.
// Repli automatique sur les dictionnaires statiques de data-superieur.js si Supabase est
// indisponible (hors ligne, erreur réseau, table absente...), pour que ces onglets
// continuent de fonctionner sans interruption visible. data-superieur.js reste chargé en
// <script> dans superieur.html à cet effet.
// N'affecte pas les onglets "Universités privées" / "Grandes écoles privées", qui
// continuent de lire espDB().etablissements comme avant (table etablissements existante).
async function espLoadSuperieurPublicData(){
  const [univRes, univFilRes, debRes, geRes, geFilRes] = await Promise.all([
    supabaseClient.from('universites').select('*'),
    supabaseClient.from('universite_filieres').select('*'),
    supabaseClient.from('debouches_filieres').select('*'),
    supabaseClient.from('grandes_ecoles').select('*'),
    supabaseClient.from('grande_ecole_filieres').select('*'),
  ]);
  [univRes, univFilRes, debRes, geRes, geFilRes].forEach(r => { if(r.error) throw r.error; });

  const universitesRows = univRes.data || [];
  const grandesEcolesRows = geRes.data || [];
  if(universitesRows.length === 0 || grandesEcolesRows.length === 0){
    throw new Error('Tables Supabase universites/grandes_ecoles vides ou introuvables');
  }

  const universitesNoms = {};
  universitesRows.slice().sort((a, b) => (a.ordre ?? 0) - (b.ordre ?? 0))
    .forEach(u => { universitesNoms[u.code] = u.nom; });

  const universites = {};
  Object.keys(universitesNoms).forEach(code => (universites[code] = []));
  (univFilRes.data || []).slice().sort((a, b) => (a.ordre ?? 0) - (b.ordre ?? 0))
    .forEach(f => {
      if(universites[f.universite_code]){
        universites[f.universite_code].push({ nom: f.nom, bac: f.bac, age: f.age, criteres: f.criteres });
      }
    });

  const debouchesFilieres = {};
  (debRes.data || []).forEach(d => { debouchesFilieres[d.nom] = d.debouches; });

  const grandesEcoles = {};
  grandesEcolesRows.slice().sort((a, b) => (a.ordre ?? 0) - (b.ordre ?? 0))
    .forEach(e => { grandesEcoles[e.nom] = { tutelle: e.tutelle, filieres: [] }; });
  (geFilRes.data || []).slice().sort((a, b) => (a.ordre ?? 0) - (b.ordre ?? 0))
    .forEach(f => {
      const ecole = grandesEcolesRows.find(e => e.id === f.grande_ecole_id);
      if(ecole && grandesEcoles[ecole.nom]){
        grandesEcoles[ecole.nom].filieres.push({ nom: f.nom, bac: f.bac, age: f.age, debouches: f.debouches });
      }
    });

  const filiereDebouches = [];
  const seen = new Set();
  Object.keys(debouchesFilieres).forEach(nom => {
    if(!seen.has(nom)){
      seen.add(nom);
      filiereDebouches.push({ nom, debouches: debouchesFilieres[nom], source: 'Universités publiques' });
    }
  });
  Object.entries(grandesEcoles).forEach(([ecole, data]) => {
    data.filieres.forEach(f => {
      if(!seen.has(f.nom)){
        seen.add(f.nom);
        filiereDebouches.push({ nom: f.nom, debouches: f.debouches, source: 'Grande école : ' + ecole });
      }
    });
  });
  filiereDebouches.sort((a, b) => a.nom.localeCompare(b.nom, 'fr'));

  return { universitesNoms, universites, debouchesFilieres, grandesEcoles, filiereDebouches };
}

async function initSuperieur(){
  // ---- Tabs ----
  document.querySelectorAll('.es-tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.es-tab-btn').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.es-panel').forEach(p => p.classList.remove('active'));
      btn.classList.add('active');
      document.getElementById('panel-' + btn.dataset.tab).classList.add('active');
      if(btn.dataset.tab === 'univ-prive') renderSuperieurPriveTable('universite');
      if(btn.dataset.tab === 'ecole-prive') renderSuperieurPriveTable('grande_ecole');
    });
  });

  // ---- Chargement des données publiques (Supabase, repli sur data-superieur.js) ----
  let universitesNoms = UNIVERSITES_NOMS;
  let universites = UNIVERSITES;
  let grandesEcoles = GRANDES_ECOLES;
  let filiereDebouches = TOUTES_FILIERES_DEBOUCHES;
  try {
    const supData = await espLoadSuperieurPublicData();
    universitesNoms = supData.universitesNoms;
    universites = supData.universites;
    grandesEcoles = supData.grandesEcoles;
    filiereDebouches = supData.filiereDebouches;
  } catch(e){
    console.error('[superieur] échec du chargement Supabase, repli sur data-superieur.js', e);
  }

  // ---- Panel 1 : Universités ----
  const selectUniv = document.getElementById('select-univ');
  Object.keys(universitesNoms).forEach(code => {
    const opt = document.createElement('option');
    opt.value = code;
    opt.textContent = `${code} — ${universitesNoms[code]}`;
    selectUniv.appendChild(opt);
  });

  selectUniv.addEventListener('change', () => {
    const code = selectUniv.value;
    const container = document.getElementById('results-univ');
    container.innerHTML = '';
    if (!code) {
      container.innerHTML = '<div class="empty-state">Sélectionnez une université pour afficher ses filières et conditions d\'accès.</div>';
      return;
    }
    const filieres = universites[code] || [];
    if (filieres.length === 0) {
      container.innerHTML = '<div class="empty-state">Aucune filière relevée pour cette université dans le document source.</div>';
      return;
    }
    container.innerHTML = `<div class="school-header">${universitesNoms[code]} — ${filieres.length} filière(s)</div>`;
    filieres.forEach(f => {
      const card = document.createElement('div');
      card.className = 'card';
      card.innerHTML = `
        <h3>${f.nom}</h3>
        <div class="meta-row">
          <div class="meta-item"><b>Série(s) BAC</b>${f.bac}</div>
          <div class="meta-item"><b>Âge limite</b>${f.age}</div>
        </div>
        <div class="criteres"><b>Critères d'accès :</b> ${f.criteres}</div>
      `;
      container.appendChild(card);
    });
  });

  // ---- Panel 2 : Grandes écoles ----
  const selectEcole = document.getElementById('select-ecole');
  Object.keys(grandesEcoles).forEach(nom => {
    const opt = document.createElement('option');
    opt.value = nom;
    opt.textContent = nom;
    selectEcole.appendChild(opt);
  });

  selectEcole.addEventListener('change', () => {
    const nom = selectEcole.value;
    const container = document.getElementById('results-ecole');
    container.innerHTML = '';
    if (!nom) {
      container.innerHTML = '<div class="empty-state">Sélectionnez une grande école pour afficher ses filières, conditions d\'accès et débouchés.</div>';
      return;
    }
    const data = grandesEcoles[nom];
    container.innerHTML = `<div class="school-header">${nom} <span style="opacity:.75">(${data.tutelle})</span></div>`;
    data.filieres.forEach(f => {
      const card = document.createElement('div');
      card.className = 'card';
      card.innerHTML = `
        <h3>${f.nom}</h3>
        <div class="meta-row">
          <div class="meta-item"><b>Série(s) BAC</b>${f.bac}</div>
          <div class="meta-item"><b>Âge limite</b>${f.age}</div>
        </div>
        <div class="debouches"><b>Débouchés :</b> ${f.debouches}</div>
      `;
      container.appendChild(card);
    });
  });

  // ---- Panel 3 : Filière -> Débouchés ----
  const selectFiliere = document.getElementById('select-filiere');
  const searchFiliere = document.getElementById('search-filiere');

  function populateFiliereSelect(filterText = '') {
    const current = selectFiliere.value;
    selectFiliere.innerHTML = '<option value="">— Sélectionner —</option>';
    filiereDebouches
      .filter(f => normalize(f.nom).includes(normalize(filterText)))
      .forEach(f => {
        const opt = document.createElement('option');
        opt.value = f.nom;
        opt.textContent = f.nom;
        selectFiliere.appendChild(opt);
      });
    if ([...selectFiliere.options].some(o => o.value === current)) {
      selectFiliere.value = current;
    }
  }
  populateFiliereSelect();

  searchFiliere.addEventListener('input', () => populateFiliereSelect(searchFiliere.value));

  selectFiliere.addEventListener('change', () => {
    const nom = selectFiliere.value;
    const container = document.getElementById('results-filiere');
    container.innerHTML = '';
    if (!nom) {
      container.innerHTML = '<div class="empty-state">Sélectionnez une filière pour afficher ses débouchés.</div>';
      return;
    }
    const f = filiereDebouches.find(x => x.nom === nom);
    const card = document.createElement('div');
    card.className = 'card';
    card.innerHTML = `
      <h3>${f.nom}</h3>
      <div class="meta-row"><div class="meta-item"><b>Filière recensée dans</b>${f.source}</div></div>
      <div class="debouches"><b>Débouchés :</b> ${f.debouches}</div>
    `;
    container.appendChild(card);
  });

  // ---- Panels 4 et 5 : Universités privées / Grandes écoles privées ----
  ['f-univ-prive-ville','f-univ-prive-filiere'].forEach(id => {
    const el = document.getElementById(id);
    if(el) el.addEventListener('input', () => renderSuperieurPriveTable('universite'));
  });
  ['f-ecole-prive-ville','f-ecole-prive-filiere'].forEach(id => {
    const el = document.getElementById(id);
    if(el) el.addEventListener('input', () => renderSuperieurPriveTable('grande_ecole'));
  });
}
window.pageInit = initSuperieur;

// ---------------- Universités / Grandes écoles privées (comptes établissements inscrits) ----------------
// Contrairement aux panels 1-3 (données statiques du document officiel), ces deux
// tableaux sont entièrement alimentés par les établissements inscrits sur la
// plateforme (catégorie = 'superieur', secteur = 'prive'), une fois validés par l'admin.
function espEtabSuperieurPrive(sousCategorie){
  const db = espDB();
  return (db.etablissements || []).filter(e => e.categorie === 'superieur' && e.sousCategorie === sousCategorie && e.secteur === 'prive' && e.statut === 'valide');
}

function espFillSupDatalist(id, values){
  const dl = document.getElementById(id);
  if(!dl) return;
  const unique = Array.from(new Set(values.filter(Boolean))).sort((a,b) => a.localeCompare(b, 'fr'));
  dl.innerHTML = unique.map(v => `<option value="${escapeHtml(v)}">`).join('');
}

function renderSuperieurPriveTable(sousCategorie){
  const prefix = sousCategorie === 'universite' ? 'univ-prive' : 'ecole-prive';
  const tbody = document.getElementById(prefix + '-results');
  const countEl = document.getElementById(prefix + '-count');
  const emptyEl = document.getElementById(prefix + '-empty-msg');
  if(!tbody) return;

  const allForSector = espEtabSuperieurPrive(sousCategorie);
  espFillSupDatalist('dl-' + prefix + '-ville', allForSector.map(e => e.ville));
  const allFilieres = [];
  allForSector.forEach(e => (e.filieresProposees||[]).forEach(f => allFilieres.push(f.nom)));
  espFillSupDatalist('dl-' + prefix + '-filiere', allFilieres);

  const villeInput = document.getElementById('f-' + prefix + '-ville');
  const filiereInput = document.getElementById('f-' + prefix + '-filiere');
  const nVille = normalize((villeInput ? villeInput.value : '').trim());
  const nFiliere = normalize((filiereInput ? filiereInput.value : '').trim());

  const etabs = allForSector.filter(e => {
    const villeOk = !nVille || normalize(e.ville||'').includes(nVille);
    const filiereOk = !nFiliere || (e.filieresProposees||[]).some(f => normalize(f.nom||'').includes(nFiliere));
    return villeOk && filiereOk;
  });

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
