// ---------------- Fenêtre modale générique (fiche métier / détail concours) ----------------
// hideHeader (optionnel) : masque l'en-tête générique (titre/tags en dégradé orange-vert) au
// profit d'un bandeau personnalisé inclus dans bodyHtml (cf. utils.js espOpenEtabDetailModal,
// seul appelant à ce jour). Toujours réinitialisé à chaque appel pour que l'en-tête générique
// réapparaisse normalement sur les fiches suivantes (métier, concours...).
function openModal(titre, tagsHtml, bodyHtml, hideHeader){
  document.getElementById('modal-titre').textContent = titre;
  document.getElementById('modal-tags').innerHTML = tagsHtml || '';
  document.getElementById('modal-body').innerHTML = bodyHtml || '';
  const header = document.getElementById('modal-header');
  if(header) header.style.display = hideHeader ? 'none' : '';
  document.getElementById('modal-overlay').classList.add('open');
  document.body.style.overflow = 'hidden';
}
function closeModal(){
  document.getElementById('modal-overlay').classList.remove('open');
  document.body.style.overflow = '';
}
document.addEventListener('keydown', e => {
  if(e.key === 'Escape') closeModal();
});
