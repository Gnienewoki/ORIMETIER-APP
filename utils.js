function normalize(s){
  return (s||'').toString().toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g,'');
}

function escapeHtml(s){
  return (s||'').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}

// ---------------- Filières Enseignement Général : Cycle -> Diplôme (listes fermées + "Autre") ----------------
// Un "Autre" saisi en texte libre à la saisie (nom/diplôme de la filière restent des
// colonnes texte libres, cf. etablissement_add_filiere) est stocké tel quel, jamais
// littéralement "Autre" — donc les filtres ci-dessous détectent un "Autre" par exclusion
// (valeur absente des listes prédéfinies), pas par correspondance texte sur ce mot.
const ESP_GENERAL_AUTRE = '__autre__';
const ESP_GENERAL_CYCLES = ['1er cycle', '2nd cycle'];
const ESP_GENERAL_DIPLOMES_PAR_CYCLE = {
  '1er cycle': ['BEPC'],
  '2nd cycle': ['BAC A1', 'BAC A2', 'BAC D', 'BAC C'],
};
function espGeneralDiplomesPourCycle(cycle){
  return ESP_GENERAL_DIPLOMES_PAR_CYCLE[cycle] || [];
}
// Tous les diplômes prédéfinis, tous cycles confondus — sert à détecter un diplôme
// "Autre" quand aucun Cycle précis n'est sélectionné dans le filtre (cf. general.js).
function espGeneralTousDiplomesPredefinis(){
  return Object.values(ESP_GENERAL_DIPLOMES_PAR_CYCLE).flat();
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

// ---------------- Bandeau d'annonce admin (site-wide, toutes les pages) ----------------
// Alimenté par la table Supabase "annonce" (jusqu'à 5 lignes actives, gérées depuis
// l'espace admin) : une seule annonce affichée à la fois, en rotation tant que plusieurs
// sont actives (pas de rotation s'il n'y en a qu'une). Appelée depuis auth.js
// (platformUnlock / platformUnlockGuest), une fois #platform-wrap visible — jamais
// affichée sur l'écran de connexion. Pas de bouton fermer côté utilisateur : elle reste
// tant que l'admin n'a pas désactivé toutes les annonces.
//
// Timing de la rotation : les annonces image restent ESP_ANNONCE_ROTATION_MS (délai fixe,
// une image se regarde d'un coup, pas besoin de plus). Les annonces texte, elles,
// défilent en marquee CSS — leur temps d'affichage doit correspondre au temps réel que
// met le défilement à faire sortir tout le texte par la gauche, sinon un texte long est
// coupé en cours de route. On ne peut pas se fier à un setInterval à durée fixe pour ça
// (un texte plus long parcourt une plus grande distance dans le même temps, donc défile
// plus vite ET n'a pas le temps de finir) : à la place, on mesure la largeur réelle du
// texte rendu (span.scrollWidth, qui inclut le padding-left:100% de départ hors écran),
// on en déduit sa durée à vitesse de défilement constante (ESP_ANNONCE_SCROLL_SPEED_PX_S),
// on applique cette durée à l'animation CSS elle-même (animation-duration en ligne, pour
// que la vitesse reste identique quelle que soit la longueur), et on programme le passage
// à l'annonce suivante avec un setTimeout (auto-reprogrammé à chaque annonce, plutôt qu'un
// setInterval à cadence unique) réglé sur cette même durée.
const ESP_ANNONCE_ROTATION_MS = 7000; // délai fixe pour les annonces image
const ESP_ANNONCE_SCROLL_SPEED_PX_S = 60; // vitesse de défilement du texte (px/s) — plus petit = plus lent
let _espAnnonceRotationTimer = null;

// Coupe la rotation en cours, s'il y en a une : appelé avant chaque (re)rendu de la barre
// (pour ne jamais empiler plusieurs timers) et au déchargement de la page, pour ne pas
// laisser tourner un timer inutilement.
function espStopAnnonceRotation(){
  if(_espAnnonceRotationTimer){ clearTimeout(_espAnnonceRotationTimer); _espAnnonceRotationTimer = null; }
}
window.addEventListener('pagehide', espStopAnnonceRotation);

function espAnnonceBarHtml(annonce){
  return annonce.type === 'image'
    ? `<img src="${escapeHtml(annonce.imageUrl)}" alt="Annonce">`
    : `<div class="esp-annonce-marquee"><span>📣 ${escapeHtml(annonce.texte)}</span></div>`;
}

// À appeler une fois le HTML de l'annonce texte injecté dans `bar` (span déjà dans le
// DOM, donc scrollWidth mesurable). Fixe la durée de l'animation CSS et retourne combien
// de temps garder cette annonce à l'écran avant de passer à la suivante (durée du
// défilement + petite marge, avec un plancher à ESP_ANNONCE_ROTATION_MS pour qu'un texte
// très court ne soit pas remplacé plus vite qu'une image).
function espAnnonceTexteDurationMs(bar){
  const span = bar.querySelector('.esp-annonce-marquee span');
  if(!span) return ESP_ANNONCE_ROTATION_MS;
  const distancePx = span.scrollWidth;
  const scrollMs = (distancePx / ESP_ANNONCE_SCROLL_SPEED_PX_S) * 1000;
  span.style.animationDuration = (scrollMs / 1000) + 's';
  return Math.max(ESP_ANNONCE_ROTATION_MS, scrollMs + 400);
}

function espRenderAnnonceBar(){
  espStopAnnonceRotation();
  const wrap = document.getElementById('platform-wrap');
  if(!wrap) return;
  const existing = document.getElementById('esp-annonce-bar');
  if(existing) existing.remove();

  const annonces = (espDB().annonces || []).filter(a =>
    a.active && ((a.type === 'image' && a.imageUrl) || (a.type === 'texte' && a.texte))
  );
  if(!annonces.length) return;

  const bar = document.createElement('div');
  bar.id = 'esp-annonce-bar';
  wrap.insertBefore(bar, wrap.firstChild);

  let index = 0;
  function showCurrent(){
    const annonce = annonces[index];
    bar.className = 'esp-annonce-bar esp-annonce-bar--' + annonce.type;
    bar.innerHTML = espAnnonceBarHtml(annonce);
    // Toujours recalculée pour une annonce texte (même sans rotation, s'il n'y en a
    // qu'une seule active) : c'est elle qui fixe la vitesse de défilement CSS, pour
    // qu'elle reste la même quelle que soit la longueur du texte.
    const texteDurationMs = annonce.type === 'texte' ? espAnnonceTexteDurationMs(bar) : null;
    if(annonces.length > 1){
      const delay = annonce.type === 'texte' ? texteDurationMs : ESP_ANNONCE_ROTATION_MS;
      _espAnnonceRotationTimer = setTimeout(() => {
        index = (index + 1) % annonces.length;
        showCurrent();
      }, delay);
    }
  }
  showCurrent();
}
