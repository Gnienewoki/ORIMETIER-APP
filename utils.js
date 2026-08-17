function normalize(s){
  return (s||'').toString().toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g,'');
}

function escapeHtml(s){
  return (s||'').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}

// ---------------- Filières Enseignement Général : Cycle -> Diplôme (listes fermées + "Autre") ----------------
// Valeurs prédéfinies uniquement : un "Autre" saisi en texte libre est stocké (nom/diplôme
// de la filière restent des colonnes texte libres, cf. etablissement_add_filiere) mais ne
// figure dans aucune de ces deux listes, donc n'apparaît jamais comme option de filtre
// public (seules les valeurs prédéfinies ci-dessous sont proposées dans les filtres).
const ESP_GENERAL_AUTRE = '__autre__';
const ESP_GENERAL_CYCLES = ['1er cycle', '2nd cycle'];
const ESP_GENERAL_DIPLOMES_PAR_CYCLE = {
  '1er cycle': ['BEPC'],
  '2nd cycle': ['BAC A1', 'BAC A2', 'BAC D', 'BAC C'],
};
function espGeneralDiplomesPourCycle(cycle){
  return ESP_GENERAL_DIPLOMES_PAR_CYCLE[cycle] || [];
}

// ---------------- Établissement Premium : contact direct, site web, photos (visibles publiquement) ----------------
// Ces informations ne sont visibles des visiteurs que si l'établissement a le
// Premium activé par l'admin (etab.premium === true) — cf. tableau de bord établissement.
// Nom de l'établissement, cliquable (ouvre la fiche détaillée) : toujours affiché, pour
// tout établissement. La fiche elle-même se charge de n'afficher les infos Premium
// (contact direct, site web, photos) que si l'établissement est Premium.
function espEtabNomCellHtml(e){
  const nom = escapeHtml(e.nom);
  return `<span class="esp-etab-nom-link" onclick="espOpenEtabDetailModal('${e.id}')" title="Voir la fiche complète">${nom} 🔎</span>`;
}
// Colonne "Contact" : contact institutionnel (tel/email de connexion) toujours affiché,
// complété par le contact direct de l'établissement si Premium et renseigné.
function espEtabContactCellHtml(e){
  const base = [e.tel, e.email].filter(Boolean).join(' · ') || '—';
  if(!e.premium) return escapeHtml(base);
  const direct = [e.tel2, e.tel3, e.siteWeb].filter(Boolean).join(' · ');
  if(!direct) return escapeHtml(base);
  return `${escapeHtml(base)}<br><span class="esp-badge valide" style="margin-top:2px;">Contact direct</span> ${escapeHtml(direct)}`;
}
// Fiche détaillée dans la fenêtre modale générique (cf. modal.js). Nécessite le markup
// #modal-overlay présent sur la page. Toujours visibles : nom, ville, quartier, région,
// type, catégorie, filières proposées (validées). Réservés au Premium : contact direct,
// site web, photos — ces champs sont déjà renvoyés à null par la RPC list_etablissements
// quand premium=false, donc rien à filtrer côté client au-delà du test e.premium.
function espOpenEtabDetailModal(etabId){
  const db = espDB();
  const e = (db.etablissements || []).find(x => x.id === etabId);
  if(!e || typeof openModal !== 'function') return;

  const infoLines = [];
  if(e.type) infoLines.push(`<b>Type :</b> ${escapeHtml(e.type)}`);
  const categorieLabel = typeof espEtabCategorieLabel === 'function' ? espEtabCategorieLabel(e) : '—';
  if(categorieLabel && categorieLabel !== '—') infoLines.push(`<b>Catégorie :</b> ${categorieLabel}`);
  const infoHtml = infoLines.length ? `<p class="esp-sub" style="line-height:1.9;">${infoLines.join('<br>')}</p>` : '';

  const filieresValidees = (e.filieresProposees || []).filter(f => f.statut === 'valide');
  const filieresHtml = filieresValidees.length ? `
    <div style="margin-bottom:14px;">
      <b style="font-size:13px;">Filières proposées :</b>
      <ul style="margin:6px 0 0;padding-left:18px;">
        ${filieresValidees.map(f => `<li>${escapeHtml(f.nom)}${f.diplome ? ` (${escapeHtml(f.diplome)})` : ''}</li>`).join('')}
      </ul>
    </div>
  ` : '';

  const photos = e.premium ? (e.photos || []) : [];
  const photosHtml = photos.length ? `
    <div class="esp-etab-photos-grid" style="margin-bottom:14px;">
      ${photos.map(u => `<div class="esp-etab-photo-thumb"><img src="${escapeHtml(u)}" alt="Photo de ${escapeHtml(e.nom)}"></div>`).join('')}
    </div>
  ` : '';
  const contactLines = [];
  if(e.premium && e.email) contactLines.push(`✉️ <a href="mailto:${escapeHtml(e.email)}">${escapeHtml(e.email)}</a>`);
  if(e.premium && e.tel) contactLines.push(`📞 <a href="tel:${escapeHtml(e.tel)}">${escapeHtml(e.tel)}</a>`);
  if(e.premium && e.tel2) contactLines.push(`📞 <a href="tel:${escapeHtml(e.tel2)}">${escapeHtml(e.tel2)}</a>`);
  if(e.premium && e.tel3) contactLines.push(`📞 <a href="tel:${escapeHtml(e.tel3)}">${escapeHtml(e.tel3)}</a>`);
  if(e.premium && e.siteWeb) contactLines.push(`🌐 <a href="${escapeHtml(e.siteWeb)}" target="_blank" rel="noopener">${escapeHtml(e.siteWeb)}</a>`);
  const contactHtml = contactLines.length ? `<p class="esp-sub" style="line-height:1.9;">${contactLines.join('<br>')}</p>` : '';

  const tagsHtml = [e.ville, e.quartier, e.region].filter(Boolean).map(v => `<span class="esp-badge valide">${escapeHtml(v)}</span>`).join(' ');
  openModal(e.nom, tagsHtml, (infoHtml + filieresHtml + photosHtml + contactHtml) || '<p class="esp-empty">Aucune information supplémentaire.</p>');
}
