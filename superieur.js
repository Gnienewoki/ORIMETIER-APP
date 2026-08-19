// ---------------- Enseignement supérieur (page superieur.html) ----------------
// Onglets "Universités publiques", "Grandes écoles publiques" et "Filière -> Débouchés" :
// chargés depuis Supabase (tables universites/universite_filieres/debouches_filieres/
// grandes_ecoles/grande_ecole_filieres), éditables sans toucher au code ni redéployer.
// Un échec de chargement ici n'est pas rattrapé (comme le reste du bootstrap) : ces
// onglets restent vides et silencieux plutôt que d'afficher un message d'erreur dédié.
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
        universites[f.universite_code].push({ nom: f.nom, bac: f.bac, age: f.age, criteres: f.criteres, n: f.numero_source });
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

// ---------------- Panel 3 : "Filières proches" (onglet Filière -> Débouchés) ----------------
// Rapprochement en deux niveaux, calculé "à la demande" (au changement de filière
// sélectionnée, jamais à chaque frappe) sur les données déjà chargées par
// espLoadSuperieurPublicData() ou par le repli data-superieur.js — aucun nouvel appel Supabase.
// Niveau 1 (prioritaire) : filières partageant le même numero_source (le "n" du tableau PDF
// d'origine) qu'une université propose ensemble — signal fiable car il vient du document
// source, pas d'une heuristique de texte.
// Niveau 2 (repli) : ressemblance lexicale entre les noms, via un score de Jaccard sur les
// mots significatifs normalisés (accents/casse retirés avec normalize() de utils.js, mots-
// outils français filtrés, léger essuyage de suffixe pour absorber les accords singulier/
// pluriel et masculin/féminin).
const ES_STOPWORDS = new Set(['de','du','des','la','le','les','l','d','et','en','au','aux','un','une','a','ou','pour']);

function espFiliereStem(tok){
  if(tok.length > 4 && tok.endsWith('es')) return tok.slice(0, -2);
  if(tok.length > 4 && (tok.endsWith('e') || tok.endsWith('s'))) return tok.slice(0, -1);
  return tok;
}

function espFiliereTokens(nom){
  return normalize(nom).split(/[^a-z0-9]+/).filter(t => t.length > 1 && !ES_STOPWORDS.has(t)).map(espFiliereStem);
}

function espFiliereJaccard(nomA, nomB){
  const a = new Set(espFiliereTokens(nomA));
  const b = new Set(espFiliereTokens(nomB));
  const inter = [...a].filter(t => b.has(t));
  const union = new Set([...a, ...b]);
  return union.size ? inter.length / union.size : 0;
}

// Regroupe les noms de filières d'université par numero_source ("n"), et retient le n de
// chaque filière pour retrouver ses éventuelles "sœurs" de niveau 1.
function espFiliereSourceMap(universites){
  const byN = {};
  const nOfNom = {};
  Object.values(universites).forEach(liste => {
    liste.forEach(f => {
      if(f.n == null) return;
      nOfNom[f.nom] = f.n;
      (byN[f.n] = byN[f.n] || new Set()).add(f.nom);
    });
  });
  return { byN, nOfNom };
}

function espFilieresProches(nomCible, universites, grandesEcoles, max = 4){
  const { byN, nOfNom } = espFiliereSourceMap(universites);
  const n = nOfNom[nomCible];
  const level1 = n != null
    ? [...(byN[n] || [])].filter(nom => nom !== nomCible).sort((a, b) => a.localeCompare(b, 'fr'))
    : [];

  const toutesLesFilieres = new Set();
  Object.values(universites).forEach(liste => liste.forEach(f => toutesLesFilieres.add(f.nom)));
  Object.values(grandesEcoles).forEach(d => d.filieres.forEach(f => toutesLesFilieres.add(f.nom)));

  const dejaRetenues = new Set([nomCible, ...level1]);
  const level2 = [...toutesLesFilieres]
    .filter(nom => !dejaRetenues.has(nom))
    .map(nom => ({ nom, score: espFiliereJaccard(nomCible, nom) }))
    .filter(r => r.score > 0)
    .sort((a, b) => b.score - a.score || a.nom.localeCompare(b.nom, 'fr'))
    .map(r => r.nom);

  return [...level1, ...level2].slice(0, max);
}

// Mini-aperçu d'une filière proche : établissements publics qui la proposent, avec bac/âge
// (et critères d'accès pour les universités, qui les recensent — les grandes écoles
// recensent des débouchés, pas de critères d'accès détaillés).
function espFiliereEtablissements(nom, universites, universitesNoms, grandesEcoles){
  const rows = [];
  Object.keys(universites).forEach(code => {
    universites[code].forEach(f => {
      if(f.nom === nom) rows.push({ etablissement: universitesNoms[code], bac: f.bac, age: f.age, criteres: f.criteres });
    });
  });
  Object.entries(grandesEcoles).forEach(([ecoleNom, data]) => {
    data.filieres.forEach(f => {
      if(f.nom === nom) rows.push({ etablissement: ecoleNom, bac: f.bac, age: f.age, criteres: null });
    });
  });
  return rows;
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

  // ---- Chargement des données publiques (Supabase) ----
  const { universitesNoms, universites, grandesEcoles, filiereDebouches } = await espLoadSuperieurPublicData();

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

    const proches = espFilieresProches(nom, universites, grandesEcoles);
    if (proches.length) {
      const section = document.createElement('div');
      section.className = 'es-fp-section';
      const grid = document.createElement('div');
      grid.className = 'es-fp-grid';
      proches.forEach(pNom => {
        const etabs = espFiliereEtablissements(pNom, universites, universitesNoms, grandesEcoles);
        const etabsHtml = etabs.length
          ? etabs.map(e => `
              <div class="es-fp-etab">
                <div class="es-fp-etab-nom">${e.etablissement}</div>
                <div class="es-fp-etab-meta">Bac ${e.bac} · Âge limite ${e.age}${e.criteres ? ' · ' + e.criteres : ''}</div>
              </div>
            `).join('')
          : '<div class="es-fp-etab-meta">Aucun établissement public relevé pour cette filière.</div>';
        const pCard = document.createElement('div');
        pCard.className = 'es-fp-card';
        pCard.innerHTML = `<div class="es-fp-nom">${pNom}</div>${etabsHtml}`;
        grid.appendChild(pCard);
      });
      section.innerHTML = '<div class="es-fp-title">Filières proches</div>';
      section.appendChild(grid);
      container.appendChild(section);
    }
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
