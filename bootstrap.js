
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
  // Pas d'invite automatique disponible (déjà installée, iPhone/Safari, ou navigateur qui ne la supporte pas) :
  // on affiche les instructions manuelles adaptées.
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

(async function espBootstrap(){
  try {
    await espLoadFromSupabase();
  } catch(e){
    console.error(e);
    alert("Impossible de se connecter à la base de données en ligne.\n\nVérifie ta connexion internet, ainsi que les identifiants Supabase (SUPABASE_URL / SUPABASE_ANON_KEY) renseignés dans le fichier, puis recharge la page.\n\nDétail : " + e.message);
  }
  const loader = document.getElementById('esp-loading');
  if(loader) loader.style.display = 'none';

  const resetToken = new URLSearchParams(window.location.search).get('reset');
  // L'animation d'ouverture ne doit se jouer qu'au lancement de l'application
  // (premier chargement de l'onglet), pas à chaque passage d'une page à une
  // autre : on ne la rejoue pas si elle a déjà tourné dans cette session.
  const dejaLancee = sessionStorage.getItem('orimetier_splash_shown');
  if(resetToken){
    espRenderResetPasswordScreen(resetToken);
    finishSplash();
  } else if(dejaLancee){
    platformInit();
    finishSplash();
  } else {
    platformInit();
    runSplashSequence();
    sessionStorage.setItem('orimetier_splash_shown', '1');
  }
  espSetupRealtime();
})();
