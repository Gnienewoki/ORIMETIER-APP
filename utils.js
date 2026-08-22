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
// Fiche détaillée dans la fenêtre modale générique (cf. modal.js), avec un bandeau
// personnalisé (logo + nom + catégorie) qui remplace l'en-tête générique en dégradé
// orange-vert (openModal(...,true) masque cet en-tête — cf. modal.js). Toujours visibles :
// nom, catégorie, filières proposées (validées), secteur, région/ville/quartier. Réservés
// au Premium : logo, photos, tel/tel2/tel3, email, site web — ces champs sont déjà renvoyés
// à null/vide par la RPC list_etablissements quand premium=false, donc rien à filtrer côté
// client au-delà du test e.premium (ceinture et bretelles).
function espOpenEtabDetailModal(etabId){
  const db = espDB();
  const e = (db.etablissements || []).find(x => x.id === etabId);
  if(!e || typeof openModal !== 'function') return;

  const categorieParts = [];
  if(e.categorie) categorieParts.push(ESP_ETAB_CATEGORIE_LABELS[e.categorie] || e.categorie);
  if(e.sousCategorie) categorieParts.push(ESP_ETAB_SOUS_CATEGORIE_LABELS[e.sousCategorie] || e.sousCategorie);
  const categorieLabel = categorieParts.join(' · ');
  const secteurLabel = e.secteur ? (ESP_ETAB_SECTEUR_LABELS[e.secteur] || e.secteur) : '';
  const localisationLabel = [e.ville, e.quartier, e.region].filter(Boolean).join(' · ');

  // ---------------- Bandeau : logo (Premium uniquement, jamais de médaillon vide) + nom + catégorie ----------------
  const logoHtml = (e.premium && e.logoUrl)
    ? `<img class="esp-fiche-logo" src="${escapeHtml(e.logoUrl)}" alt="Logo de ${escapeHtml(e.nom)}">`
    : '';
  const bandeauHtml = `
    <div class="esp-fiche-bandeau">
      <button type="button" class="modal-close" onclick="closeModal()" aria-label="Fermer">✕</button>
      <div class="esp-fiche-bandeau-top">
        ${logoHtml}
        <div>
          <h2 class="esp-fiche-nom">${escapeHtml(e.nom)}</h2>
          ${categorieLabel ? `<p class="esp-fiche-categorie">${escapeHtml(categorieLabel)}</p>` : ''}
        </div>
      </div>
    </div>
  `;

  // ---------------- Pastilles : localisation (toujours), secteur (toujours), site web (Premium) ----------------
  const pastilles = [];
  if(localisationLabel){
    pastilles.push(`<div class="esp-fiche-pastille esp-fiche-pastille--blue"><span class="esp-fiche-pastille-icon">📍</span><span class="esp-fiche-pastille-body"><b>Localisation</b><span>${escapeHtml(localisationLabel)}</span></span></div>`);
  }
  if(secteurLabel){
    pastilles.push(`<div class="esp-fiche-pastille esp-fiche-pastille--amber"><span class="esp-fiche-pastille-icon">🏢</span><span class="esp-fiche-pastille-body"><b>Secteur</b><span>${escapeHtml(secteurLabel)}</span></span></div>`);
  }
  if(e.premium && e.siteWeb){
    pastilles.push(`<div class="esp-fiche-pastille esp-fiche-pastille--pink"><span class="esp-fiche-pastille-icon">🌐</span><span class="esp-fiche-pastille-body"><b>Site web</b><a href="${escapeHtml(e.siteWeb)}" target="_blank" rel="noopener">${escapeHtml(e.siteWeb)}</a></span></div>`);
  }
  const pastillesHtml = pastilles.length ? `<div class="esp-fiche-pastilles">${pastilles.join('')}</div>` : '';

  const typeHtml = e.type ? `<p class="esp-sub" style="margin-bottom:18px;">Type : ${escapeHtml(e.type)}</p>` : '';

  // ---------------- Filières proposées (validées) : pills pleines, couleurs en alternance ----------------
  const filieresValidees = (e.filieresProposees || []).filter(f => f.statut === 'valide');
  const filiereCouleurs = ['esp-fiche-filiere-pill--red', 'esp-fiche-filiere-pill--orange', 'esp-fiche-filiere-pill--blue'];
  const filieresHtml = filieresValidees.length ? `
    <h3>Filières proposées</h3>
    <div class="esp-fiche-filieres">
      ${filieresValidees.map((f,i) => `<span class="esp-fiche-filiere-pill ${filiereCouleurs[i % filiereCouleurs.length]}">${escapeHtml(f.nom)}${f.diplome ? ` <b>${escapeHtml(f.diplome)}</b>` : ''}</span>`).join('')}
    </div>
  ` : '';

  // ---------------- Photos (Premium) : grille de vignettes, pastille "+N" sur la dernière si troncature ----------------
  const photos = e.premium ? (e.photos || []) : [];
  _espFichePhotos = photos;
  _espFichePhotosNom = e.nom;
  _espLightboxIndex = -1;
  const ESP_FICHE_PHOTOS_MAX_VISIBLE = 6;
  const photosRestantes = photos.length - ESP_FICHE_PHOTOS_MAX_VISIBLE;
  const photosHtml = photos.length ? `
    <h3>Photos</h3>
    <div class="esp-fiche-photos">
      ${photos.slice(0, ESP_FICHE_PHOTOS_MAX_VISIBLE).map((u,i) => {
        const dernier = i === ESP_FICHE_PHOTOS_MAX_VISIBLE - 1;
        const overlay = (dernier && photosRestantes > 0) ? `<span class="esp-fiche-photo-more">+${photosRestantes}</span>` : '';
        return `<button type="button" class="esp-fiche-photo" onclick="espEtabLightboxOpen(${i})" aria-label="Agrandir la photo ${i+1} de ${escapeHtml(e.nom)}"><img src="${escapeHtml(u)}" alt="Photo de ${escapeHtml(e.nom)}" loading="lazy">${overlay}</button>`;
      }).join('')}
    </div>
  ` : '';

  // ---------------- Contact (Premium) : fond gris, badge Premium, 3 blocs colorés tel/tel2/tel3 ----------------
  const contactCouleurs = ['red', 'green', 'blue'];
  const contactBlocs = [e.tel, e.tel2, e.tel3]
    .map((num, i) => (e.premium && num) ? `<div class="esp-fiche-contact-bloc esp-fiche-contact-bloc--${contactCouleurs[i]}"><span class="esp-fiche-contact-icon">📞</span><a href="tel:${escapeHtml(num)}">${escapeHtml(num)}</a></div>` : '')
    .filter(Boolean);
  const emailHtml = (e.premium && e.email) ? `<p class="esp-fiche-contact-email">✉️ <a href="mailto:${escapeHtml(e.email)}">${escapeHtml(e.email)}</a></p>` : '';
  const contactHtml = (contactBlocs.length || emailHtml) ? `
    <div class="esp-fiche-contact-section">
      <div class="esp-fiche-contact-header">
        <h3>Contact</h3>
        <span class="esp-badge-premium">Premium</span>
      </div>
      ${emailHtml}
      ${contactBlocs.length ? `<div class="esp-fiche-contact-grid">${contactBlocs.join('')}</div>` : ''}
    </div>
  ` : '';

  const contenuHtml = pastillesHtml + typeHtml + filieresHtml + photosHtml + contactHtml;
  const bodyHtml = bandeauHtml + `<div class="esp-fiche-contenu">${contenuHtml || '<p class="esp-empty">Aucune information supplémentaire.</p>'}</div>`;
  openModal('', '', bodyHtml, true);
}

// ---------------- Lightbox photos (fiche établissement) : vanilla JS, sans dépendance ----------------
// DOM créée à la volée et ajoutée une seule fois à document.body (pas de markup statique à
// dupliquer dans chaque page HTML qui inclut ce script). État courant : _espFichePhotos
// (tableau d'URLs de la fiche ouverte) + _espLightboxIndex (-1 = fermée).
let _espFichePhotos = [];
let _espFichePhotosNom = '';
let _espLightboxIndex = -1;

function espEtabLightboxEnsureDom(){
  if(document.getElementById('esp-lightbox-overlay')) return;
  const div = document.createElement('div');
  div.id = 'esp-lightbox-overlay';
  div.className = 'esp-lightbox-overlay';
  div.innerHTML = `
    <button type="button" class="esp-lightbox-close" aria-label="Fermer">✕</button>
    <button type="button" class="esp-lightbox-nav esp-lightbox-prev" aria-label="Photo précédente">‹</button>
    <img class="esp-lightbox-img" id="esp-lightbox-img" alt="">
    <button type="button" class="esp-lightbox-nav esp-lightbox-next" aria-label="Photo suivante">›</button>
    <div class="esp-lightbox-counter" id="esp-lightbox-counter"></div>
  `;
  div.addEventListener('click', ev => { if(ev.target === div) espEtabLightboxClose(); });
  div.querySelector('.esp-lightbox-close').addEventListener('click', espEtabLightboxClose);
  div.querySelector('.esp-lightbox-prev').addEventListener('click', () => espEtabLightboxNav(-1));
  div.querySelector('.esp-lightbox-next').addEventListener('click', () => espEtabLightboxNav(1));
  document.body.appendChild(div);
}
function espEtabLightboxRender(){
  const img = document.getElementById('esp-lightbox-img');
  const counter = document.getElementById('esp-lightbox-counter');
  const overlay = document.getElementById('esp-lightbox-overlay');
  if(!img || _espLightboxIndex < 0) return;
  img.src = _espFichePhotos[_espLightboxIndex];
  img.alt = `Photo de ${_espFichePhotosNom}`;
  const multi = _espFichePhotos.length > 1;
  overlay.classList.toggle('single', !multi);
  counter.textContent = multi ? `${_espLightboxIndex + 1} / ${_espFichePhotos.length}` : '';
}
function espEtabLightboxOpen(index){
  if(!_espFichePhotos.length) return;
  espEtabLightboxEnsureDom();
  _espLightboxIndex = index;
  espEtabLightboxRender();
  document.getElementById('esp-lightbox-overlay').classList.add('open');
  document.body.style.overflow = 'hidden';
}
function espEtabLightboxNav(delta){
  if(_espLightboxIndex < 0) return;
  const n = _espFichePhotos.length;
  _espLightboxIndex = (_espLightboxIndex + delta + n) % n;
  espEtabLightboxRender();
}
function espEtabLightboxClose(){
  const overlay = document.getElementById('esp-lightbox-overlay');
  if(overlay) overlay.classList.remove('open');
  _espLightboxIndex = -1;
  const modalOverlay = document.getElementById('modal-overlay');
  document.body.style.overflow = (modalOverlay && modalOverlay.classList.contains('open')) ? 'hidden' : '';
}
// Enregistré avant modal.js (utils.js est chargé en premier dans toutes les pages) : quand
// la lightbox est ouverte, stopImmediatePropagation() empêche l'écouteur Échap de modal.js
// de fermer la fiche en même temps — une première pression ferme seulement la lightbox.
document.addEventListener('keydown', ev => {
  if(_espLightboxIndex < 0) return;
  if(ev.key === 'Escape'){ espEtabLightboxClose(); ev.stopImmediatePropagation(); }
  else if(ev.key === 'ArrowLeft') espEtabLightboxNav(-1);
  else if(ev.key === 'ArrowRight') espEtabLightboxNav(1);
});

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
