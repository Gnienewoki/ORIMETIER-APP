// ---------------- Espaces (page espaces.html) : aiguillage vers le bon tableau de bord ----------------
// Les conteneurs de rôle (#esp-role-select, #esp-admin, ...) vivent dans #gate-content
// (portail, partagé avec toutes les pages) tant qu'on n'est pas connecté. Une fois
// connecté sur CETTE page, on les déplace dans #page-content pour qu'ils redeviennent
// visibles (le portail est alors caché). On fait l'inverse à la déconnexion.
const ESP_ROLE_CONTAINER_IDS = ['esp-role-select','esp-admin','esp-inspecteur','esp-eleve','esp-etablissement'];
window.onBeforeUnlock = function(){
  const mount = document.getElementById('espaces-dashboard-mount');
  ESP_ROLE_CONTAINER_IDS.forEach(id => {
    const el = document.getElementById(id);
    if(el && !mount.contains(el)) mount.appendChild(el);
  });
};
window.onBeforeLock = function(){
  const gateContent = document.getElementById('gate-content');
  ESP_ROLE_CONTAINER_IDS.forEach(id => {
    const el = document.getElementById(id);
    if(el && !gateContent.contains(el)) gateContent.appendChild(el);
  });
};

function espInit(){
  const session = espSession();
  if(session && session.role === 'admin'){ espHideAll(); document.getElementById('esp-admin').style.display=''; espRenderAdminDashboard('overview'); return; }
  if(session && session.role === 'inspecteur'){ espHideAll(); document.getElementById('esp-inspecteur').style.display=''; espRenderInspecteurDashboard(); return; }
  if(session && session.role === 'eleve'){ espHideAll(); document.getElementById('esp-eleve').style.display=''; espRenderEleveDashboard(); return; }
  if(session && session.role === 'etablissement'){ espHideAll(); document.getElementById('esp-etablissement').style.display=''; espRenderEtabDashboard(); return; }
  espShowRoleSelect();
}
window.pageInit = espInit;
window.pageRefresh = espInit;
