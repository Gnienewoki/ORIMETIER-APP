// ---------------- Enseignement supérieur (page superieur.html) ----------------
function initSuperieur(){
  // ---- Tabs ----
  document.querySelectorAll('.es-tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.es-tab-btn').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.es-panel').forEach(p => p.classList.remove('active'));
      btn.classList.add('active');
      document.getElementById('panel-' + btn.dataset.tab).classList.add('active');
    });
  });

  // ---- Panel 1 : Universités ----
  const selectUniv = document.getElementById('select-univ');
  Object.keys(UNIVERSITES_NOMS).forEach(code => {
    const opt = document.createElement('option');
    opt.value = code;
    opt.textContent = `${code} — ${UNIVERSITES_NOMS[code]}`;
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
    const filieres = UNIVERSITES[code] || [];
    if (filieres.length === 0) {
      container.innerHTML = '<div class="empty-state">Aucune filière relevée pour cette université dans le document source.</div>';
      return;
    }
    container.innerHTML = `<div class="school-header">${UNIVERSITES_NOMS[code]} — ${filieres.length} filière(s)</div>`;
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
  Object.keys(GRANDES_ECOLES).forEach(nom => {
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
    const data = GRANDES_ECOLES[nom];
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
    TOUTES_FILIERES_DEBOUCHES
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
    const f = TOUTES_FILIERES_DEBOUCHES.find(x => x.nom === nom);
    const card = document.createElement('div');
    card.className = 'card';
    card.innerHTML = `
      <h3>${f.nom}</h3>
      <div class="meta-row"><div class="meta-item"><b>Filière recensée dans</b>${f.source}</div></div>
      <div class="debouches"><b>Débouchés :</b> ${f.debouches}</div>
    `;
    container.appendChild(card);
  });
}
window.pageInit = initSuperieur;
