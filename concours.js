// ---------------- Concours & Grandes Écoles (page concours.html) ----------------
let ccLevel = 'tous';

function renderConcours(){
  const all = ccAllItems();
  const q = normalize(document.getElementById('cc-search').value.trim());
  const filtered = all.filter(it => {
    if(ccLevel !== 'tous' && it.niveau !== ccLevel) return false;
    if(!q) return true;
    const hay = normalize([it.nom, it.filiere, it.etablissements, it.categorie].join(' '));
    return hay.includes(q);
  });

  const results = document.getElementById('cc-results');
  const emptyMsg = document.getElementById('cc-empty-msg');
  const countEl = document.getElementById('cc-count');
  countEl.textContent = filtered.length + ' résultat' + (filtered.length > 1 ? 's' : '');
  emptyMsg.style.display = filtered.length ? 'none' : '';

  results.innerHTML = filtered.map((it, i) => `
    <div class="cc-card" data-idx="${all.indexOf(it)}">
      <div class="cc-card-badges">
        <span class="cc-badge-level ${it.niveau}">${CC_LEVEL_LABELS[it.niveau]}</span>
        <span class="cc-badge-cat">${escapeHtml(it.categorie)}</span>
      </div>
      <div class="cc-card-title">${escapeHtml(it.nom)}</div>
      <div class="cc-card-filiere">${escapeHtml(it.filiere)}</div>
    </div>
  `).join('');
}

function openConcoursDetail(idx){
  const all = ccAllItems();
  const it = all[idx];
  if(!it) return;
  const tagsHtml = [CC_LEVEL_LABELS[it.niveau], it.categorie].filter(Boolean)
    .map(t => `<span class="tag">${escapeHtml(t)}</span>`).join('');
  const bodyHtml = `
    <h3>Filière(s) / spécialité(s)</h3>
    <p>${escapeHtml(it.filiere)}</p>
    <h3>Conditions d'accès</h3>
    <p>${escapeHtml(it.conditions)}</p>
    <h3>Établissement(s)</h3>
    <p>${escapeHtml(it.etablissements)}</p>
    ${it.debouches ? `<h3>Débouchés</h3><p>${escapeHtml(it.debouches)}</p>` : ''}
  `;
  openModal(it.nom, tagsHtml, bodyHtml);
}

function initConcours(){
  document.getElementById('concours-total-count').textContent = ccAllItems().length;
  document.getElementById('cc-search').addEventListener('input', renderConcours);
  document.querySelectorAll('.cc-level-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.cc-level-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      ccLevel = btn.dataset.level;
      renderConcours();
    });
  });
  document.getElementById('cc-results').addEventListener('click', e => {
    const card = e.target.closest('.cc-card');
    if(!card) return;
    openConcoursDetail(parseInt(card.dataset.idx, 10));
  });
  renderConcours();
}
window.pageInit = initConcours;
