// ---------------- Icônes Lucide (chargées en <defer>, prêtes après le parsing) ----------------
// Transforme les <i data-lucide="..."> présents au chargement. Les rendus
// dynamiques (listes, modales) rappellent espRefreshIcons() après injection.
if(document.readyState === 'loading'){
  document.addEventListener('DOMContentLoaded', () => espRefreshIcons());
} else {
  espRefreshIcons();
}

// ---------------- PWA : bouton "Partager l'application" ----------------
async function espTriggerShare(){
  const shareData = {
    title: 'ORIMETIER',
    text: "ORIMETIER — Choisissez votre avenir. Test d'orientation RIASEC, annuaire des formations et accompagnement scolaire.",
    url: window.location.origin + window.location.pathname,
  };
  if(navigator.share){
    try {
      await navigator.share(shareData);
    } catch(e){
      // L'utilisateur a annulé le partage, ou une erreur est survenue : rien à faire.
    }
    return;
  }
  // Repli si le partage natif n'est pas disponible (ex : ordinateur) : copier le lien.
  try {
    await navigator.clipboard.writeText(shareData.url);
    alert("Lien copié ! Tu peux maintenant le coller dans WhatsApp, SMS, ou l'application de ton choix.\n\n" + shareData.url);
  } catch(e){
    prompt("Copie ce lien pour le partager :", shareData.url);
  }
}

// ---------------- PWA : bouton "Installer l'application" ----------------
let _espDeferredInstallPrompt = null;
window.addEventListener('beforeinstallprompt', (e) => {
  e.preventDefault();
  _espDeferredInstallPrompt = e;
  const btn = document.getElementById('pwa-install-btn');
  if(btn) btn.style.display = '';
});
function espTriggerInstall(){
  if(_espDeferredInstallPrompt){
    _espDeferredInstallPrompt.prompt();
    _espDeferredInstallPrompt.userChoice.finally(() => {
      _espDeferredInstallPrompt = null;
      const btn = document.getElementById('pwa-install-btn');
      if(btn) btn.style.display = 'none';
    });
    return;
  }
  const ua = navigator.userAgent || '';
  const isIOS = /iPhone|iPad|iPod/.test(ua);
  const isAndroid = /Android/.test(ua);
  let msg;
  if(isIOS){
    msg = "Pour installer ORIMETIER sur iPhone/iPad :\n\n1. Appuie sur le bouton Partager (le carré avec une flèche vers le haut, en bas de Safari)\n2. Fais défiler et choisis « Sur l'écran d'accueil »\n3. Confirme avec « Ajouter »";
  } else if(isAndroid){
    msg = "L'application est peut-être déjà installée sur cet appareil !\n\nSinon, ouvre le menu ⋮ de Chrome (en haut à droite) et choisis « Installer l'application » ou « Ajouter à l'écran d'accueil ».";
  } else {
    msg = "L'application est peut-être déjà installée sur cet appareil !\n\nSinon, cherche une icône d'installation ⊕ dans la barre d'adresse de ton navigateur, à droite.";
  }
  alert(msg);
}
window.addEventListener('appinstalled', () => {
  const btn = document.getElementById('pwa-install-btn');
  if(btn) btn.style.display = 'none';
});

// ---------------- PWA : enregistrement du service worker ----------------
if('serviceWorker' in navigator){
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch((e) => {
      console.warn('[PWA] Enregistrement du service worker échoué (non bloquant) :', e);
    });
  });
  // Quand une nouvelle version de l'app est déployée, le nouveau service
  // worker prend le contrôle de la page (self.skipWaiting()/clients.claim()
  // dans sw.js) : "controllerchange" se déclenche à ce moment précis. On
  // recharge alors la page une seule fois, pour que le visiteur récupère
  // automatiquement le JS/CSS/HTML à jour, sans jamais avoir à vider son
  // cache manuellement.
  let _espSwReloaded = false;
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if(_espSwReloaded) return;
    _espSwReloaded = true;
    window.location.reload();
  });
}

// ---------------- Écran d'ouverture animé ----------------
function finishSplash(){
  const splash = document.getElementById('splash-screen');
  if(splash) splash.style.display = 'none';
}

function splashSkip(){
  if(window.__splashTimers) window.__splashTimers.forEach(t => clearTimeout(t));
  finishSplash();
}

function runSplashSequence(){
  const logoContent = document.getElementById('splash-logo-content');
  const sloganContent = document.getElementById('splash-slogan-content');
  const skipBtn = document.getElementById('splash-skip-btn');
  if(!logoContent || !sloganContent) return;

  const timers = [];
  timers.push(setTimeout(() => { if(skipBtn) skipBtn.classList.add('visible'); }, 700));
  timers.push(setTimeout(() => { logoContent.classList.add('fade-out'); }, 2200));
  timers.push(setTimeout(() => {
    logoContent.classList.add('splash-hidden');
    sloganContent.classList.remove('splash-hidden');
  }, 2750));
  timers.push(setTimeout(() => { sloganContent.classList.add('fade-out'); }, 4750));
  timers.push(setTimeout(() => { finishSplash(); }, 5350));
  window.__splashTimers = timers;
}

// ---------------- Décision immédiate : faut-il jouer l'animation ? ----------------
// Cette vérification se fait AVANT tout appel réseau (Supabase), pour que
// l'écran de démarrage soit masqué instantanément sur les pages qui n'en
// ont pas besoin — sans ce court flash du logo pendant le chargement.
const _espResetToken = new URLSearchParams(window.location.search).get('reset');
const _espPath = window.location.pathname;
const _espEstPageAccueil = _espPath === '/' || _espPath === '' || /\/index\.html$/.test(_espPath);
const _espDejaLancee = sessionStorage.getItem('orimetier_splash_shown');
const _espDoitJouerAnimation = !_espResetToken && _espEstPageAccueil && !_espDejaLancee;

if(!_espDoitJouerAnimation && !_espResetToken){
  // Pas la page d'accueil, ou animation déjà jouée dans cette session :
  // on masque l'écran de démarrage tout de suite, sans attendre Supabase.
  finishSplash();
}
if(_espDoitJouerAnimation){
  sessionStorage.setItem('orimetier_splash_shown', '1');
}

// ---------------- Compteur de visites (statistiques admin, 1 log par chargement de page) ----------------
// Liste fermée des 7 vraies pages du site (menu latéral) — test.html en est exclu
// volontairement, ce n'est pas une page consultée en tant que telle. Doit rester
// synchronisée avec la liste acceptée par log_visite() côté Supabase.
const ESP_VISITE_PAGES = ['index.html', 'general.html', 'superieur.html', 'concours.html', 'eleves.html', 'espaces.html', 'liens-formation.html'];

// Fire-and-forget : jamais attendu, ne doit jamais retarder ni bloquer le chargement de
// la page, et un échec (réseau, RLS, etc.) ne doit jamais remonter à l'utilisateur — au
// pire un avertissement en console (même convention que l'enregistrement du service
// worker plus haut dans ce fichier), rien de visible sur la page.
function espLogVisiteCourante(){
  let page = _espEstPageAccueil ? 'index.html' : (_espPath.split('/').pop() || '');
  // Réaligne les "clean URLs" (/concours) sur le nom de fichier attendu par
  // log_visite() côté Supabase (concours.html), sinon aucune visite n'est comptée.
  if(page && !/\.html$/.test(page)) page += '.html';
  if(!ESP_VISITE_PAGES.includes(page)) return;
  espLogVisiteRPC(page).catch(e => console.warn('[esp] échec de l\'enregistrement de la visite (non bloquant) :', e));
}

(async function espBootstrap(){
  espLogVisiteCourante();

  // Message de patience : n'apparaît que si le chargement traîne (cold start
  // Render) ET que l'écran de chargement est encore affiché à l'écran.
  setTimeout(() => {
    const loader = document.getElementById('esp-loading');
    const hint = document.getElementById('esp-loading-hint');
    if(loader && hint && loader.offsetParent !== null) hint.hidden = false;
  }, 4000);

  // Chargement Supabase lancé tout de suite mais jamais "throw" : l'erreur
  // éventuelle est renvoyée comme valeur, pour décider ensuite quoi en faire.
  const chargement = espLoadFromSupabase().then(() => null, (e) => { console.error(e); return e; });

  const finaliserDonnees = () => {
    const loader = document.getElementById('esp-loading');
    if(loader) loader.style.display = 'none';
    // Le bandeau d'annonce dépend de espDB() : quand on a affiché la page avant
    // le chargement (cf. afficherSansAttendre), il faut le (re)rendre ici. Sans
    // effet si la plateforme n'est pas déverrouillée ou s'il n'y a aucune annonce.
    if(typeof espRenderAnnonceBar === 'function' &&
       document.getElementById('platform-wrap') &&
       document.getElementById('platform-wrap').style.display !== 'none'){
      espRenderAnnonceBar();
    }
    // Hook optionnel : une page qui a du contenu dépendant de Supabase (ex :
    // annuaire des établissements privés sur index.html) s'y abonne pour se
    // rafraîchir dès que les données en ligne sont disponibles.
    if(typeof window.pageDataReady === 'function'){
      try { window.pageDataReady(); } catch(err){ console.error('[esp] pageDataReady a échoué', err); }
    }
  };

  // Cold start Render : le serveur peut mettre 30 à 50 s à se réveiller. Un
  // visiteur non connecté sur une page en libre accès n'a pas à attendre ça —
  // son contenu principal est statique (DATA des 351 filières, concours, test).
  // On l'affiche immédiatement ; les données Supabase se greffent après coup.
  // Condition volontairement restrictive : la page doit explicitement fournir
  // window.pageDataReady (seul index.html le fait pour l'instant). Toutes les
  // autres situations — connecté, page privée, lien ?reset= — attendent, comme avant.
  const afficherSansAttendre =
    !_espResetToken &&
    !espSession() &&
    espCurrentPageIsPublic() &&
    typeof window.pageDataReady === 'function';

  if(afficherSansAttendre){
    platformInit();
    if(_espDoitJouerAnimation) runSplashSequence();
    chargement.then(finaliserDonnees);
  } else {
    const err = await chargement;
    finaliserDonnees();
    if(err){
      alert("Impossible de se connecter à la base de données en ligne.\n\nVérifie ta connexion internet, ainsi que les identifiants Supabase (SUPABASE_URL / SUPABASE_ANON_KEY) renseignés dans le fichier, puis recharge la page.\n\nDétail : " + err.message);
    }
    if(_espResetToken){
      espRenderResetPasswordScreen(_espResetToken);
      finishSplash();
    } else if(_espDoitJouerAnimation){
      platformInit();
      runSplashSequence();
    } else {
      platformInit();
    }
  }
  espSetupRealtime();
})();
