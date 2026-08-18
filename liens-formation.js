// ---------------- Formations (page liens-formation.html) ----------------
// Liens externes de formation, classés par audience (inspecteur / élève / étudiant / tous).
// Gérés par l'admin (voir admin.js) dans la table Supabase liens_formation, lecture publique
// directe (comme universites/grandes_ecoles) — pas de repli local, cette page n'a pas de
// données statiques préexistantes.
async function initLiensFormation(){
  document.querySelectorAll('.es-tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.es-tab-btn').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.es-panel').forEach(p => p.classList.remove('active'));
      btn.classList.add('active');
      document.getElementById('panel-' + btn.dataset.tab).classList.add('active');
    });
  });

  const AUDIENCES = ['lf-inspecteur', 'lf-eleve', 'lf-etudiant', 'lf-tous'];

  let liens = [];
  try {
    const { data, error } = await supabaseClient.from('liens_formation').select('*').order('ordre', { ascending: true });
    if(error) throw error;
    liens = data || [];
  } catch(e){
    console.error('[liens-formation] échec du chargement Supabase', e);
    AUDIENCES.forEach(tab => {
      const container = document.getElementById('results-' + tab);
      if(container) container.innerHTML = '<div class="empty-state">Impossible de charger les liens de formation pour le moment. Réessayez plus tard.</div>';
    });
    return;
  }

  AUDIENCES.forEach(tab => {
    const container = document.getElementById('results-' + tab);
    if(!container) return;
    const audience = tab.replace('lf-', '');
    const items = liens.filter(l => l.audience === audience);
    if(items.length === 0){
      container.innerHTML = '<div class="empty-state">Aucun lien de formation pour le moment.</div>';
      return;
    }
    container.innerHTML = '';
    items.forEach(l => {
      const card = document.createElement('div');
      card.className = 'card';
      card.innerHTML = `
        <h3><a href="${l.url}" target="_blank" rel="noopener">${l.titre}</a></h3>
        <p style="margin:6px 0 10px;color:var(--es-muted);font-size:.9rem;line-height:1.5;">${l.description || ''}</p>
        <a href="${l.url}" target="_blank" rel="noopener" style="color:var(--es-orange);font-weight:700;font-size:.85rem;">Ouvrir le lien ↗</a>
      `;
      container.appendChild(card);
    });
  });
}
window.pageInit = initLiensFormation;
