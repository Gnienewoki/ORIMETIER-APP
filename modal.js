// ---------------- Fenêtre modale générique (fiche métier / détail concours) ----------------
function openModal(titre, tagsHtml, bodyHtml){
  document.getElementById('modal-titre').textContent = titre;
  document.getElementById('modal-tags').innerHTML = tagsHtml || '';
  document.getElementById('modal-body').innerHTML = bodyHtml || '';
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
