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

const CACHE_NAME = 'orimetier-shell-v3';
const APP_SHELL = [
  './',
  './index.html',
  './superieur.html',
  './concours.html',
  './test.html',
  './espaces.html',
  './eleves.html',
  './style.css',
  './utils.js',
  './modal.js',
  './data-formations.js',
  './data-concours.js',
  './data-riasec.js',
  './data-superieur.js',
  './supabase-client.js',
  './auth.js',
  './formations.js',
  './concours.js',
  './superieur.js',
  './riasec-test.js',
  './eleves.js',
  './espaces.js',
  './admin.js',
  './inspecteur.js',
  './eleve.js',
  './etablissement.js',
  './bootstrap.js',
  './manifest.json',
  './icons/icon-192.png',
  './icons/icon-512.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL)).catch(() => {})
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
