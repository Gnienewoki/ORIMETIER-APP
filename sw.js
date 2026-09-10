// ============================================================
// ORIMETIER — Service Worker
// Rôle actuel : rendre l'application installable (PWA) et mettre
// en cache les fichiers de l'application (HTML/CSS/JS/icônes) pour
// un chargement plus rapide et une meilleure résilience.
// ⚠️ Ceci NE fait PAS fonctionner l'application sans connexion :
// les données (élèves, inspecteurs, notes...) viennent toujours de
// Supabase et nécessitent Internet. Le vrai mode hors-ligne avec
// synchronisation est une étape ultérieure de la feuille de route.
// ============================================================
// Incrémenter ce numéro à chaque déploiement qui modifie un fichier de
// APP_SHELL : ça force la purge de l'ancien cache chez les visiteurs déjà
// venus, et déclenche le rechargement automatique (voir "controllerchange"
// dans bootstrap.js) pour qu'ils récupèrent la nouvelle version sans rien
// avoir à faire.
const CACHE_NAME = 'orimetier-shell-v6';

// Liste exhaustive et vérifiée des fichiers réellement servis par le site
// (aucune entrée fantôme : un seul 404 dans un cache.addAll classique fait
// échouer TOUT le pré-cache, cf. le pré-cache pré-v5 qui listait
// data-superieur.js / eleves.js inexistants et ne mettait donc rien en cache).
const APP_SHELL = [
  './',
  // Pages
  './index.html',
  './superieur.html',
  './concours.html',
  './general.html',
  './liens-formation.html',
  './test.html',
  './espaces.html',
  './eleves.html',
  // Style
  './style.css',
  // Socle JS commun
  './utils.js',
  './modal.js',
  './supabase-client.js',
  './auth.js',
  './bootstrap.js',
  // Données statiques
  './data-formations.js',
  './data-concours.js',
  './data-riasec.js',
  './data-regions.js',
  // Logique par page
  './formations.js',
  './superieur.js',
  './concours.js',
  './general.js',
  './liens-formation.js',
  './riasec-test.js',
  './espaces.js',
  // Espaces
  './admin.js',
  './inspecteur.js',
  './eleve.js',
  './etablissement.js',
  './lycam.js',
  './mbti.js',
  // PWA
  './manifest.json',
  './icons/icon-192.png',
  './icons/icon-512.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) =>
      // Mise en cache fichier par fichier plutôt que cache.addAll() : si l'un
      // d'eux échoue (404, réseau), les autres sont quand même mis en cache et
      // l'installation du service worker n'est jamais bloquée.
      Promise.all(
        APP_SHELL.map((url) =>
          cache.add(url).catch((e) => {
            console.warn('[PWA] pré-cache ignoré pour', url, e);
          })
        )
      )
    ).catch(() => {})
  );
  self.skipWaiting();
});
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});
self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return; // ne jamais mettre en cache les requêtes d'écriture
  const url = new URL(req.url);
  // Ne jamais intercepter les appels vers Supabase : ils doivent toujours aller au réseau.
  if (url.hostname.includes('supabase.co')) return;
  // Uniquement les fichiers de l'app (même origine) : réseau d'abord, secours par le cache.
  if (url.origin === self.location.origin) {
    event.respondWith(
      fetch(req)
        .then((res) => {
          const resClone = res.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(req, resClone)).catch(() => {});
          return res;
        })
        .catch(() => caches.match(req))
    );
  }
});
