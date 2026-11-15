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

// Chargement unique des tables publiques (universites, universite_filieres, debouches_filieres,
// grandes écoles), partagé entre initSuperieur et les liens filière -> conditions. Un échec
// n'est pas mémorisé : le clic suivant retentera le chargement.
let _esPublicDataPromise = null;
function espSuperieurPublicData(){
  if(!_esPublicDataPromise){
    _esPublicDataPromise = espLoadSuperieurPublicData().catch(e => { _esPublicDataPromise = null; throw e; });
  }
  return _esPublicDataPromise;
}

// ---------------- Panel 3 : détail d'une filière ----------------
// Débouchés (debouches_filieres), puis conditions d'admission telles que recensées dans
// universite_filieres (aucun critère n'est déduit ni recopié ailleurs), puis filières proches.
// codeUniv (optionnel) : université d'où vient le clic, affichée en premier et mise en avant.
function espRenderFiliereDetail(data, nom, codeUniv){
  const { universites, universitesNoms, grandesEcoles, filiereDebouches } = data;
  const container = document.getElementById('results-filiere');
  container.innerHTML = '';
  if (!nom) {
    container.innerHTML = '<div class="empty-state">Sélectionnez une filière pour afficher ses débouchés.</div>';
    return;
  }

  const f = filiereDebouches.find(x => x.nom === nom);
  const card = document.createElement('div');
  card.className = 'card';
  card.innerHTML = f ? `
      <h3>${f.nom}</h3>
      <div class="meta-row"><div class="meta-item"><b>Filière recensée dans</b>${f.source}</div></div>
      <div class="debouches"><b>Débouchés :</b> ${f.debouches}</div>
    ` : `<h3>${escapeHtml(nom)}</h3><div class="es-fp-etab-meta">Débouchés non recensés pour cette filière.</div>`;
  container.appendChild(card);

  const conditions = [];
  Object.keys(universites).forEach(code => {
    universites[code].forEach(u => { if (u.nom === nom) conditions.push({ code, ...u }); });
  });
  if (conditions.length) {
    conditions.sort((a, b) => (b.code === codeUniv) - (a.code === codeUniv));
    const section = document.createElement('div');
    section.className = 'es-fp-section';
    section.innerHTML = '<div class="es-fp-title">Conditions d\'admission (universités publiques)</div>' +
      conditions.map(c => espCarteConditionsHtml(universitesNoms[c.code], c, c.code === codeUniv)).join('');
    container.appendChild(section);
  }

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
}

function espCarteConditionsHtml(nomUniv, f, enAvant){
  return `
    <div class="card${enAvant ? ' es-cond--focus' : ''}">
      <h3>${escapeHtml(nomUniv || '')}</h3>
      <div class="meta-row">
        <div class="meta-item"><b>Série(s) BAC</b>${escapeHtml(f.bac || '—')}</div>
        <div class="meta-item"><b>Âge limite</b>${escapeHtml(f.age || '—')}</div>
      </div>
      <div class="criteres"><b>Critères d'accès :</b> ${escapeHtml(f.criteres || '—')}</div>
    </div>`;
}

// Affiche un onglet (sans toucher au parcours de retour : cf. le clic menu dans initSuperieur).
function espActiverOnglet(tab){
  const panel = document.getElementById('panel-' + tab);
  if (!panel) return;
  document.querySelectorAll('.es-tab-btn').forEach(b => b.classList.toggle('active', b.dataset.tab === tab));
  document.querySelectorAll('.es-panel').forEach(p => p.classList.remove('active'));
  panel.classList.add('active');
  if(tab === 'univ-prive') renderSuperieurPriveTable('universite');
  if(tab === 'ecole-prive') renderSuperieurPriveTable('grande_ecole');
}

// ---------------- Retour vers « Universités publiques » ----------------
// Actif seulement quand on arrive sur l'écran filière par un lien de l'onglet Universités
// publiques (tableau ou fiche détail). Une entrée d'historique est ajoutée à ce moment-là :
// le bouton « Retour », le bouton précédent du navigateur et le geste retour d'Android
// ramènent tous à l'onglet. La recherche et les filtres de l'onglet ne sont jamais
// réinitialisés (l'onglet est seulement masqué) ; la position dans la liste est restaurée.
let _esRetourUniv = null; // { scrollY } tant que le retour est possible

function espEntrerDepuisUnivPublic(){
  if (_esRetourUniv) return; // déjà dans le parcours (ex. clic sur une autre filière proposée)
  _esRetourUniv = { scrollY: window.scrollY };
  try { history.pushState({ esRetourUniv: true }, ''); } catch(e) {}
  const b = document.getElementById('es-retour-univ');
  if (b) b.hidden = false;
}

function espRestaurerUnivPublic(){
  const ctx = _esRetourUniv;
  _esRetourUniv = null;
  const b = document.getElementById('es-retour-univ');
  if (b) b.hidden = true;
  espActiverOnglet('univ');
  requestAnimationFrame(() => window.scrollTo(0, ctx ? ctx.scrollY : 0));
}

// Bouton « Retour » : passe par l'historique pour qu'il reste cohérent avec le bouton
// précédent (popstate fait alors la restauration).
function espRetourUnivPublic(){
  if (!_esRetourUniv) return;
  if (history.state && history.state.esRetourUniv) history.back();
  else espRestaurerUnivPublic();
}

// Départ par le menu alors que le retour était possible : on retire l'entrée d'historique
// ajoutée, pour que le bouton précédent ne « tourne pas à vide ».
function espAbandonnerRetourUniv(){
  if (!_esRetourUniv) return;
  _esRetourUniv = null;
  const b = document.getElementById('es-retour-univ');
  if (b) b.hidden = true;
  if (history.state && history.state.esRetourUniv) history.back();
}

window.addEventListener('popstate', () => {
  if (_esRetourUniv) espRestaurerUnivPublic();
});

// ---------------- Lien filière (fiche MESRS) -> conditions d'admission ----------------
// Fiches etablissements des 9 universités publiques (lot 3, MESRS) -> code universites.
const ES_UNIV_MS_CODE = { ms_439:'UFHB', ms_440:'UNA', ms_441:'UPGC', ms_442:'UJLOG', ms_443:'UMAN', ms_444:'UVCI', ms_445:'UAO', ms_446:'USP', ms_447:'UBOND' };
window.espFiliereLienPossible = e => !!(e && ES_UNIV_MS_CODE[e.id]);
let _esFiliereUI = null;

// Retire les préfixes de forme (« LICENCE (PROFESSIONNELLE) DE/D'/DES/EN », « UVCI/ISN : »,
// « spécialité ») pour ne garder que l'intitulé de la filière.
function espFiliereSansPrefixe(nom){
  let t = (nom || '').trim(), avant;
  do {
    avant = t;
    t = t.replace(/^UVCI\s*\/\s*ISN\s*:\s*/i, '')
         .replace(/^sp[ée]cialit[ée]\s+/i, '')
         .replace(/^licence(\s+professionnelle)?(\s+(de|des|du|en|es)\s+|\s+d['’]\s*|\s+)/i, '')
         .trim();
  } while (t !== avant);
  return t;
}
// Clé de comparaison : sans préfixe, minuscules, sans accents ni ponctuation.
function espFiliereCle(nom){
  return espTexteRecherche(espFiliereSansPrefixe(nom));
}

function espOuvrirFiliereDepuisBouton(btn){
  espOuvrirFiliereCriteres(btn.dataset.etab, btn.dataset.filiere);
}

// 1) Intitulé retrouvé dans universite_filieres de cette université : critères de la filière.
// 2) Sinon : filières de cette université (avec leurs critères), intitulé repris dans la recherche.
async function espOuvrirFiliereCriteres(etabId, nomFiliere){
  espEntrerDepuisUnivPublic(); // mémorise la position dans la liste AVANT de changer d'onglet
  if (typeof closeModal === 'function') closeModal();
  espActiverOnglet('filiere');
  const container = document.getElementById('results-filiere');
  const panel = document.getElementById('panel-filiere');
  if (panel) panel.scrollIntoView({ behavior: 'smooth', block: 'start' });

  let data;
  try {
    data = await espSuperieurPublicData();
  } catch (e) {
    console.error(e);
    container.innerHTML = '<div class="empty-state">Les conditions d\'admission ne sont pas disponibles pour le moment. Vérifiez votre connexion et réessayez.</div>';
    return;
  }

  const codeUniv = ES_UNIV_MS_CODE[etabId] || null;
  const liste = codeUniv ? (data.universites[codeUniv] || []) : [];
  const cle = espFiliereCle(nomFiliere);
  const correspondance = cle ? liste.find(f => espFiliereCle(f.nom) === cle) : null;
  const ui = _esFiliereUI;

  if (correspondance) {
    if (ui) { ui.search.value = ''; ui.populate(''); ui.select.value = correspondance.nom; }
    espRenderFiliereDetail(data, correspondance.nom, codeUniv);
    return;
  }

  const recherche = espFiliereSansPrefixe(nomFiliere);
  if (ui) { ui.search.value = recherche; ui.populate(recherche); ui.select.value = ''; }
  espRenderFiliereUniversite(data, codeUniv, nomFiliere);
}

function espRenderFiliereUniversite(data, codeUniv, nomFiliere){
  const container = document.getElementById('results-filiere');
  container.innerHTML = '';
  const nomUniv = codeUniv ? data.universitesNoms[codeUniv] : '';
  const liste = codeUniv ? (data.universites[codeUniv] || []) : [];
  const intro = document.createElement('div');
  intro.className = 'school-header';
  intro.textContent = liste.length
    ? `« ${nomFiliere} » : pas d'intitulé identique dans les conditions d'admission recensées. Filières recensées pour ${nomUniv} :`
    : `« ${nomFiliere} » : aucune condition d'admission n'est recensée pour cette université. Utilisez la recherche ci-dessus.`;
  container.appendChild(intro);
  liste.forEach(f => {
    const wrap = document.createElement('div');
    wrap.innerHTML = espCarteConditionsHtml(f.nom, f, false);
    const carte = wrap.firstElementChild;
    const voir = document.createElement('button');
    voir.type = 'button';
    voir.className = 'es-filiere-lien';
    voir.textContent = 'Voir les débouchés de cette filière';
    voir.addEventListener('click', () => {
      if (_esFiliereUI) { _esFiliereUI.search.value = ''; _esFiliereUI.populate(''); _esFiliereUI.select.value = f.nom; }
      espRenderFiliereDetail(data, f.nom, codeUniv);
    });
    carte.appendChild(voir);
    container.appendChild(carte);
  });
}

async function initSuperieur(){
  // ---- Tabs ----
  document.querySelectorAll('.es-tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      // Navigation normale par le menu : on quitte le parcours « depuis les universités publiques ».
      espAbandonnerRetourUniv();
      espActiverOnglet(btn.dataset.tab);
    });
  });
  const boutonRetour = document.getElementById('es-retour-univ');
  if(boutonRetour) boutonRetour.addEventListener('click', espRetourUnivPublic);

  // ---- Panel 1 : Universités publiques ----
  // Fiches de la table etablissements (secteur = 'public', données officielles MESRS),
  // affichées comme l'onglet privé. Rendu AVANT le chargement des tables universites/
  // universite_filieres ci-dessous : il n'en dépend pas (onglet actif par défaut).
  const renderUnivPublicDebounced = espDebounce(() => renderSuperieurEtabTable('univ-public', 'universite', 'public'), 180);
  ['f-univ-public-ville','f-univ-public-filiere'].forEach(id => {
    const el = document.getElementById(id);
    if(el) el.addEventListener('input', renderUnivPublicDebounced);
  });
  espBindSearchField(document.getElementById('f-univ-public-nom'), () => renderSuperieurEtabTable('univ-public', 'universite', 'public'));
  renderSuperieurEtabTable('univ-public', 'universite', 'public');

  // ---- Chargement des données publiques (Supabase) ----
  // universites/universite_filieres restent la seule source des conditions d'admission
  // (bac, âge, critères) : panel 3 et liens filière -> conditions (espOuvrirFiliereCriteres).
  const data = await espSuperieurPublicData();
  const { grandesEcoles, filiereDebouches } = data;

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

  searchFiliere.addEventListener('input', espDebounce(() => populateFiliereSelect(searchFiliere.value), 180));

  selectFiliere.addEventListener('change', () => espRenderFiliereDetail(data, selectFiliere.value, null));

  // Accès du lien filière -> conditions (espOuvrirFiliereCriteres) au sélecteur de ce panel.
  _esFiliereUI = { select: selectFiliere, search: searchFiliere, populate: populateFiliereSelect };

  // ---- Panels 4 et 5 : Universités privées / Grandes écoles privées ----
  const renderUnivPriveDebounced = espDebounce(() => renderSuperieurPriveTable('universite'), 180);
  const renderEcolePriveDebounced = espDebounce(() => renderSuperieurPriveTable('grande_ecole'), 180);
  ['f-univ-prive-ville','f-univ-prive-filiere'].forEach(id => {
    const el = document.getElementById(id);
    if(el) el.addEventListener('input', renderUnivPriveDebounced);
  });
  ['f-ecole-prive-ville','f-ecole-prive-filiere'].forEach(id => {
    const el = document.getElementById(id);
    if(el) el.addEventListener('input', renderEcolePriveDebounced);
  });
  espBindSearchField(document.getElementById('f-univ-prive-nom'), () => renderSuperieurPriveTable('universite'));
  espBindSearchField(document.getElementById('f-ecole-prive-nom'), () => renderSuperieurPriveTable('grande_ecole'));
}

function resetSuperieurPriveFilters(sousCategorie){
  const prefix = sousCategorie === 'universite' ? 'univ-prive' : 'ecole-prive';
  resetSuperieurEtabFilters(prefix, sousCategorie, 'prive');
}
function resetSuperieurEtabFilters(prefix, sousCategorie, secteur){
  ['ville','filiere'].forEach(k => {
    const el = document.getElementById('f-' + prefix + '-' + k);
    if(el) el.value = '';
  });
  espClearSearchField(document.getElementById('f-' + prefix + '-nom'));
  renderSuperieurEtabTable(prefix, sousCategorie, secteur);
}
window.pageInit = initSuperieur;

// ---------------- Universités publiques / privées, grandes écoles privées (table etablissements) ----------------
// Tableaux alimentés par la table etablissements (catégorie = 'superieur') : fiches
// officielles MESRS pour le public (secteur = 'public'), établissements inscrits sur la
// plateforme pour le privé (secteur = 'prive') — dans les deux cas une fois validées.
function espEtabSuperieur(sousCategorie, secteur){
  const db = espDB();
  return (db.etablissements || []).filter(e => e.categorie === 'superieur' && e.sousCategorie === sousCategorie && e.secteur === secteur && e.statut === 'valide');
}
function espEtabSuperieurPrive(sousCategorie){
  return espEtabSuperieur(sousCategorie, 'prive');
}

function espFillSupDatalist(id, values){
  const dl = document.getElementById(id);
  if(!dl) return;
  const unique = Array.from(new Set(values.filter(Boolean))).sort((a,b) => a.localeCompare(b, 'fr'));
  dl.innerHTML = unique.map(v => `<option value="${escapeHtml(v)}">`).join('');
}

function renderSuperieurPriveTable(sousCategorie){
  const prefix = sousCategorie === 'universite' ? 'univ-prive' : 'ecole-prive';
  renderSuperieurEtabTable(prefix, sousCategorie, 'prive');
}

function renderSuperieurEtabTable(prefix, sousCategorie, secteur){
  const tbody = document.getElementById(prefix + '-results');
  const countEl = document.getElementById(prefix + '-count');
  const emptyEl = document.getElementById(prefix + '-empty-msg');
  if(!tbody) return;

  const allForSector = espEtabSuperieur(sousCategorie, secteur);
  espFillSupDatalist('dl-' + prefix + '-ville', allForSector.map(e => e.ville));
  const allFilieres = [];
  allForSector.forEach(e => (e.filieresProposees||[]).forEach(f => allFilieres.push(f.nom)));
  espFillSupDatalist('dl-' + prefix + '-filiere', allFilieres);
  espFillDatalist('dl-' + prefix + '-nom', allForSector.map(e => e.nom));

  const villeInput = document.getElementById('f-' + prefix + '-ville');
  const filiereInput = document.getElementById('f-' + prefix + '-filiere');
  const nomInput = document.getElementById('f-' + prefix + '-nom');
  const nVille = normalize((villeInput ? villeInput.value : '').trim());
  const nFiliere = normalize((filiereInput ? filiereInput.value : '').trim());
  // Recherche par nom (ou ville) : comparée via espTexteRecherche, en ET avec les autres filtres.
  const nNom = espTexteRecherche(nomInput ? nomInput.value : '');

  const etabs = allForSector.filter(e => {
    const villeOk = !nVille || normalize(e.ville||'').includes(nVille);
    const filiereOk = !nFiliere || (e.filieresProposees||[]).some(f => normalize(f.nom||'').includes(nFiliere));
    const nomOk = !nNom || espTexteRecherche(e.nom).includes(nNom) || espTexteRecherche(e.ville).includes(nNom);
    return villeOk && filiereOk && nomOk;
  });

  const rows = [];
  etabs.forEach(e => {
    const contact = espEtabContactCellHtml(e);
    const nom = espEtabNomCellHtml(e);
    const filieres = e.filieresProposees || [];
    // Universités publiques MESRS : intitulé cliquable vers les conditions d'admission.
    const lien = secteur === 'public' && window.espFiliereLienPossible(e);
    if(!filieres.length){
      rows.push({ nom, ville: e.ville, filiere: '—', contact });
    } else {
      filieres.forEach(f => {
        if(!nFiliere || normalize(f.nom||'').includes(nFiliere)){
          const nomF = (f.nom || '').trim();
          const filiere = (f.diplome ? `${nomF || '—'} (${f.diplome})` : nomF) || '—';
          const filiereHtml = (lien && nomF)
            ? `<button type="button" class="es-filiere-lien" data-etab="${escapeHtml(e.id)}" data-filiere="${escapeHtml(nomF)}" onclick="espOuvrirFiliereDepuisBouton(this)" title="Voir la série du bac, l'âge et les moyennes">${escapeHtml(filiere)}</button>`
            : escapeHtml(filiere);
          rows.push({ nom, ville: e.ville, filiereHtml, contact });
        }
      });
    }
  });

  tbody.innerHTML = '';
  const frag = document.createDocumentFragment();
  rows.forEach(r => {
    const tr = document.createElement('tr');
    tr.innerHTML =
      `<td data-label="Établissement">${r.nom}</td>` +
      `<td data-label="Ville">${escapeHtml(r.ville||'—')}</td>` +
      `<td data-label="Filière">${r.filiereHtml !== undefined ? r.filiereHtml : escapeHtml(r.filiere)}</td>` +
      `<td data-label="Contact">${r.contact}</td>`;
    frag.appendChild(tr);
  });
  tbody.appendChild(frag);
  const wrap = tbody.closest('.table-wrap');
  if(wrap) wrap.hidden = rows.length === 0;

  if(countEl) countEl.textContent = rows.length + ' résultat' + (rows.length>1?'s':'');

  if(rows.length === 0){
    const filtres = !!(nVille || nFiliere || nNom);
    const label = (sousCategorie === 'universite' ? 'université ' : 'grande école ') + (secteur === 'public' ? 'publique' : 'privée');
    espRenderEmptyState(emptyEl, filtres ? {
      icon: 'search-x',
      title: 'Aucun résultat',
      text: nNom ? 'Aucun établissement ne correspond à votre recherche.' : 'Aucune ' + label + ' ne correspond à ces filtres.',
      actionLabel: 'Réinitialiser',
      actionIcon: 'filter-x',
      onAction: () => resetSuperieurEtabFilters(prefix, sousCategorie, secteur),
    } : {
      icon: 'landmark',
      title: 'Rien pour le moment',
      text: 'Aucune ' + label + " n'est encore référencée sur la plateforme.",
    });
  } else {
    espHideEmptyState(emptyEl);
  }
}
