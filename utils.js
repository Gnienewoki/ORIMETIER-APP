function normalize(s){
  return (s||'').toString().toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g,'');
}

function escapeHtml(s){
  return (s||'').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}

// ---------------- Établissement Premium : contact direct, site web, photos (visibles publiquement) ----------------
// Ces informations ne sont visibles des visiteurs que si l'établissement a le
// Premium activé par l'admin (etab.premium === true) — cf. tableau de bord établissement.
function espEtabHasPremiumExtras(e){
  return !!(e && e.premium && ((e.contactEmail || e.contactTel || e.siteWeb) || (e.photos && e.photos.length)));
}
// Nom de l'établissement, cliquable (ouvre la fiche détaillée) uniquement s'il y a du contenu Premium à montrer.
function espEtabNomCellHtml(e){
  const nom = escapeHtml(e.nom);
  return espEtabHasPremiumExtras(e)
    ? `<span class="esp-etab-nom-link" onclick="espOpenEtabDetailModal('${e.id}')" title="Voir la fiche complète">${nom} 🔎</span>`
    : nom;
}
// Colonne "Contact" : contact institutionnel (tel/email de connexion) toujours affiché,
// complété par le contact direct de l'établissement si Premium et renseigné.
function espEtabContactCellHtml(e){
  const base = [e.tel, e.email].filter(Boolean).join(' · ') || '—';
  if(!e.premium || (!e.contactEmail && !e.contactTel)) return escapeHtml(base);
  const direct = [e.contactTel, e.contactEmail].filter(Boolean).join(' · ');
  return `${escapeHtml(base)}<br><span class="esp-badge valide" style="margin-top:2px;">Contact direct</span> ${escapeHtml(direct)}`;
}
// Fiche détaillée (photos + contact direct + site web) dans la fenêtre modale générique
// (cf. modal.js). Nécessite le markup #modal-overlay présent sur la page.
function espOpenEtabDetailModal(etabId){
  const db = espDB();
  const e = (db.etablissements || []).find(x => x.id === etabId);
  if(!e || typeof openModal !== 'function') return;
  const photos = e.premium ? (e.photos || []) : [];
  const photosHtml = photos.length ? `
    <div class="esp-etab-photos-grid" style="margin-bottom:14px;">
      ${photos.map(u => `<div class="esp-etab-photo-thumb"><img src="${escapeHtml(u)}" alt="Photo de ${escapeHtml(e.nom)}"></div>`).join('')}
    </div>
  ` : '';
  const contactLines = [];
  if(e.premium && e.contactEmail) contactLines.push(`✉️ <a href="mailto:${escapeHtml(e.contactEmail)}">${escapeHtml(e.contactEmail)}</a>`);
  if(e.premium && e.contactTel) contactLines.push(`📞 <a href="tel:${escapeHtml(e.contactTel)}">${escapeHtml(e.contactTel)}</a>`);
  if(e.premium && e.siteWeb) contactLines.push(`🌐 <a href="${escapeHtml(e.siteWeb)}" target="_blank" rel="noopener">${escapeHtml(e.siteWeb)}</a>`);
  const contactHtml = contactLines.length ? `<p class="esp-sub" style="line-height:1.9;">${contactLines.join('<br>')}</p>` : '';
  const tagsHtml = [e.ville, e.quartier, e.region].filter(Boolean).map(v => `<span class="esp-badge valide">${escapeHtml(v)}</span>`).join(' ');
  openModal(e.nom, tagsHtml, (photosHtml + contactHtml) || '<p class="esp-empty">Aucune information supplémentaire.</p>');
}
