// ============================================================
// ---- Connexion Supabase + accès aux données ----
// ============================================================

// ---------------- Connexion Supabase (base de données partagée) ----------------
// ⚠️ Remplace ces deux valeurs par celles de TON projet Supabase
// (Supabase > Project Settings > API > Project URL / anon public key)
const SUPABASE_URL = 'https://ltfxaxzkuyejcluoaimq.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_h7s1eQ5VX8iBU2KYTpnZ3w_xRB9Mbl7';
const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
// Les e-mails (lien "mot de passe oublié") partent de l'Edge Function request-password-reset :
// plus aucune clé EmailJS côté navigateur.

// Cache local synchronisé avec Supabase (rempli par espLoadFromSupabase())
let _espCache = null;
// Vrai quand _espCache vient d'un chargement réseau de CETTE page, faux quand il vient du cache
// sessionStorage (potentiellement antérieur à un compte créé ailleurs ou depuis).
let _espCacheFromServer = false;
// Vrai dès que des données sont disponibles (chargées ou lues dans le cache) : sert à distinguer
// "compte introuvable" de "rien n'a pu être chargé" (cf. espSessionVerdict dans auth.js).
function espDataLoaded(){ return _espCache !== null; }
function espDataFromServer(){ return _espCache !== null && _espCacheFromServer; }
// Cache local des messages privés de l'inspecteur connecté (rempli par espLoadPrivateMessages())
let _espPrivateCache = [];

// ---------------- Conversion snake_case (Supabase) <-> camelCase (app) ----------------
function espRowToEleve(r){ return { id:r.id, nom:r.nom, prenoms:r.prenoms, classe:r.classe, etablissement:r.etablissement, tel:r.tel, email:r.email, password:r.password, riasec:r.riasec, active:r.active, dateInscription:r.date_inscription, banni:!!r.banni }; }
function espEleveToRow(e){ return { id:e.id, nom:e.nom, prenoms:e.prenoms, classe:e.classe, etablissement:e.etablissement, tel:e.tel, email:e.email, password:e.password, riasec:e.riasec, active:!!e.active, date_inscription:e.dateInscription, banni:!!e.banni }; }
function espRowToInspecteur(r){ return { id:r.id, nom:r.nom, prenoms:r.prenoms, fonction:r.fonction, cio:r.cio, tel:r.tel, email:r.email, password:r.password, active:r.active, dateInscription:r.date_inscription, certifie:!!r.certifie, banni:!!r.banni, avatarUrl:r.avatar_url||null, certificationDemandee:!!r.certification_demandee, messageAccueil:r.message_accueil||'' }; }
function espInspecteurToRow(i){ return { id:i.id, nom:i.nom, prenoms:i.prenoms, fonction:i.fonction, cio:i.cio, tel:i.tel, email:i.email, password:i.password, active:!!i.active, date_inscription:i.dateInscription }; }
// responsable/contactTel : réservés (admin_list_etablissements_full / etablissement_get_own
// uniquement) — absents des lignes renvoyées par list_etablissements() (publique), donc
// undefined -> '' ici pour ces appels, ce qui est le comportement voulu.
function espRowToEtab(r){ return { id:r.id, nom:r.nom, region:r.region||'', ville:r.ville, quartier:r.quartier||'', type:r.type, responsable:r.responsable||'', contactTel:r.contact_tel||'', tel:r.tel, tel2:r.tel2||'', tel3:r.tel3||'', email:r.email, siteWeb:r.site_web||'', statut:r.statut, active:r.active, dateInscription:r.date_inscription, filieresProposees:r.filieres_proposees||[], photos:r.photos||[], logoUrl:r.logo_url||'', categorie:r.categorie||'', sousCategorie:r.sous_categorie||'', secteur:r.secteur||'', preInscrit:!!r.pre_inscrit, reclame:r.reclame === undefined ? true : !!r.reclame, premium:!!r.premium, demandePremium:!!r.demande_premium, demandePremiumDate:r.demande_premium_date||'' }; }
// ---------------- Suivi d'élèves par l'inspecteur (répertoire privé, saisie libre) ----------------
function espRowToSuiviEleve(r){ return { id:r.id, nom:r.nom, prenoms:r.prenoms||'', classe:r.classe, raisons:r.raisons||[], appreciationFinale:r.appreciation_finale||'', dateAjout:r.date_ajout }; }
function espRowToSuiviNote(r){ return { id:r.id, date:r.date_note, texte:r.texte }; }
function espEtabToRow(e){ return { id:e.id, nom:e.nom, region:e.region||'', ville:e.ville, quartier:e.quartier||'', type:e.type, responsable:e.responsable, contact_tel:e.contactTel||null, tel:e.tel, tel2:e.tel2||null, tel3:e.tel3||null, site_web:e.siteWeb||null, email:e.email, password:e.password, statut:e.statut, active:!!e.active, date_inscription:e.dateInscription, filieres_proposees:e.filieresProposees||[], photos:e.photos||[], logo_url:e.logoUrl||null, categorie:e.categorie||null, sous_categorie:e.sousCategorie||null, secteur:e.secteur||null }; }
function espRowToNote(r){ return { id:r.id, eleveId:r.eleve_id, inspecteurId:r.inspecteur_id, inspecteurNom:r.inspecteur_nom, texte:r.texte, date:r.date }; }
function espNoteToRow(n){ return { id:n.id, eleve_id:n.eleveId, inspecteur_id:n.inspecteurId, inspecteur_nom:n.inspecteurNom, texte:n.texte, date:n.date }; }
function espRowToMessage(r){ return { id:r.id, inspecteurId:r.inspecteur_id, inspecteurNom:r.inspecteur_nom, texte:r.texte, date:r.date, type:r.type||'C', auteurRole:r.auteur_role||'inspecteur', replyTo:r.reply_to||null, attachmentUrl:r.attachment_url||null, attachmentType:r.attachment_type||null, attachmentName:r.attachment_name||null }; }
function espRowToAnnonce(r){ return { id:r.id, type:r.type, texte:r.texte||'', imageUrl:r.image_url||'', active:!!r.active, updatedAt:r.updated_at }; }
function espRowToPrivateMessage(r){ return { id:r.id, expediteurId:r.expediteur_id, destinataireId:r.destinataire_id, texte:r.texte, date:r.date, lu:!!r.lu, attachmentUrl:r.attachment_url||null, attachmentType:r.attachment_type||null, attachmentName:r.attachment_name||null }; }

// ---------------- Pagination des RPC de listage (list_eleves / list_inspecteurs / list_etablissements) ----------------
// PostgREST applique un plafond de lignes par requête (réglage "Max Rows" du projet
// Supabase, ou LIMIT en base) — invisible dans ce fichier, et jamais garanti stable dans
// le temps. Un simple .rpc(nom) tronque donc silencieusement le résultat dès que la table
// dépasse ce plafond (constaté à 200 lignes sur etablissements le 2026-08-17, cause du
// filtre Ville de general.html qui ne remontait que les établissements les plus anciens).
// Le plafond serveur ("Max Rows", réglage du projet Supabase) est configuré à 10000 :
// on demande donc des lots de 5000 pour couvrir les ~4200 établissements actuels en une
// seule requête (au lieu de 5-6 lots de 1000 auparavant, source de lenteur au chargement).
// On récupère par lots via .range(), triés par id pour une pagination stable (sans
// ORDER BY, Postgres ne garantit pas le même ordre entre deux requêtes séparées). On
// avance à chaque tour du nombre de lignes RÉELLEMENT reçu (pas de ESP_PAGE_SIZE) : si
// le plafond serveur devient un jour plus bas que ce qu'on demande, chaque requête ne
// renverra jamais plus que ce plafond, quelle que soit la plage demandée — se fier à
// "moins que demandé" pour arrêter reproduirait alors un troncage silencieux. On ne
// s'arrête que sur un lot réellement vide : correct quel que soit le plafond serveur,
// sans avoir besoin de le connaître à l'avance.
const ESP_PAGE_SIZE = 5000;
async function espFetchAllRows(rpcName){
  let all = [];
  let from = 0;
  while(true){
    const { data, error } = await supabaseClient.rpc(rpcName).order('id', { ascending: true }).range(from, from + ESP_PAGE_SIZE - 1);
    if(error) throw error;
    const rows = data || [];
    if(rows.length === 0) break;
    all = all.concat(rows);
    from += rows.length;
  }
  return all;
}

// ---------------- Chargement initial depuis Supabase (jamais les mots de passe) ----------------
// Mise en cache sessionStorage : la navigation entre les 7 pages du site est un rechargement
// complet du navigateur (pas de single-page app), donc sans cache chaque page relance
// intégralement ce chargement, même quand rien n'a changé depuis la page précédente — source
// de lenteur constatée en navigation. sessionStorage est propre à l'onglet et vidé à sa
// fermeture (contrairement à localStorage) : le cache dure "le temps de la session", jamais
// au-delà. forceRefresh=true (utilisé après toute mutation : envoi de message, publication
// d'annonce, réclamation d'établissement...) contourne le cache et le régénère avec les
// données fraîches, pour que l'auteur d'une action voie immédiatement son propre effet.
const ESP_CACHE_KEY = 'esp_data_cache_v1';

async function espLoadFromSupabase(forceRefresh){
  if(!forceRefresh){
    try {
      const cached = sessionStorage.getItem(ESP_CACHE_KEY);
      if(cached){ _espCache = JSON.parse(cached); _espCacheFromServer = false; return; }
    } catch(e){
      // sessionStorage indisponible, quota dépassé, ou JSON corrompu : on ignore le cache
      // et on retombe simplement sur un chargement réseau normal, sans jamais bloquer l'utilisateur.
    }
  }

  // eleves/inspecteurs/etablissements n'accordent pas de SELECT direct à la clé
  // publique (pas de grant anon) : on passe par des fonctions RPC dédiées qui ne
  // renvoient jamais la colonne "password", plutôt que par une lecture de table.
  const [elevesRows, inspecteursRows, etabRows, notesRes, messagesRes, annonceRes] = await Promise.all([
    espFetchAllRows('list_eleves'),
    espFetchAllRows('list_inspecteurs'),
    espFetchAllRows('list_etablissements'),
    supabaseClient.from('notes').select('*'),
    supabaseClient.from('messages_inspecteurs').select('*').order('created_at', { ascending: true }),
    supabaseClient.from('annonce').select('*').eq('active', true).order('created_at', { ascending: true }),
  ]);
  [notesRes, messagesRes, annonceRes].forEach(r => { if(r.error) throw r.error; });

  _espCache = {
    eleves: elevesRows.map(espRowToEleve),
    inspecteurs: inspecteursRows.map(espRowToInspecteur),
    etablissements: etabRows.map(espRowToEtab),
    notes: (notesRes.data||[]).map(espRowToNote),
    messages: (messagesRes.data||[]).map(espRowToMessage),
    annonces: (annonceRes.data||[]).map(espRowToAnnonce),
  };
  _espCacheFromServer = true;

  try { sessionStorage.setItem(ESP_CACHE_KEY, JSON.stringify(_espCache)); } catch(e){
    // Quota sessionStorage dépassé ou stockage indisponible (navigation privée stricte, etc.) :
    // pas grave, l'app continue de fonctionner, simplement sans bénéficier du cache.
  }
}

// ---------------- Messagerie privée (1-à-1 entre inspecteurs) ----------------
// Contrairement au chat de groupe, ces messages ne sont jamais lisibles publiquement :
// la fonction RPC ne renvoie que les messages où l'inspecteur connecté est expéditeur
// ou destinataire — jamais les conversations des autres inspecteurs.
// Inspecteur : authentifié par le jeton de session (espAuthRpc, auth.js).
async function espLoadPrivateMessages(){
  const session = espSession();
  if(!session || session.role !== 'inspecteur'){ _espPrivateCache = []; return; }
  const data = await espAuthRpc('inspecteur_list_private_messages_v2');
  _espPrivateCache = (data||[]).map(espRowToPrivateMessage);
}
function espPrivateMessages(){
  return _espPrivateCache || [];
}
// Session invalide (auth.js, espHandleSessionInvalid) : rien ne doit rester en mémoire.
function espResetPrivateMessages(){
  _espPrivateCache = [];
}

// ---------------- Écoute en temps réel (mises à jour reçues par tous les utilisateurs) ----------------
function espSetupRealtime(){
  ['eleves','inspecteurs','etablissements','notes','messages_inspecteurs','messages_prives'].forEach(table => {
    supabaseClient
      .channel('esp-' + table)
      .on('postgres_changes', { event: '*', schema: 'public', table }, () => espScheduleRefresh())
      .subscribe();
  });
}
let _espRefreshTimer = null;
function espScheduleRefresh(){
  clearTimeout(_espRefreshTimer);
  _espRefreshTimer = setTimeout(async () => {
    try {
      // forceRefresh=true impératif ici : ce rafraîchissement est déclenché par un changement
      // RÉEL détecté en base (postgres_changes). Sans le forcer, on relirait le cache
      // sessionStorage (potentiellement antérieur à ce changement), ce qui annulerait
      // silencieusement l'effet du temps réel — au pire faisant "disparaître" un compte
      // fraîchement créé si le cache local ne le contenait pas encore.
      await espLoadFromSupabase(true);
      const session = espSession();
      if(session && session.role === 'inspecteur'){
        try { await espLoadPrivateMessages(); }
        catch(e){ if(!e.espSessionInvalid) throw e; }
      }
      // Écran/bandeau "connexion instable" affiché : les données viennent d'être rechargées avec
      // succès, on relance la résolution de session plutôt que de dessiner un tableau de bord
      // dans le portail.
      if(document.getElementById('esp-conn-unstable') || document.getElementById('esp-conn-notice')){
        espRetryConnection();
        return;
      }
      // Ne rafraîchit l'écran que si la page courante déclare un rafraîchissement
      // (pour ne pas perturber un formulaire de connexion en cours de saisie).
      if(espSession() && window.pageRefresh) window.pageRefresh();
    } catch(e){ console.error('[esp] échec du rafraîchissement temps réel', e); }
  }, 600);
}

function espDB(){
  return _espCache || { eleves:[], inspecteurs:[], etablissements:[], notes:[], messages:[], annonces:[] };
}
// Reflète un changement dans le cache local (affichage immédiat), sans jamais envoyer
// le tableau complet au serveur : chaque écriture réelle passe par une fonction dédiée ci-dessous.
function espSaveDB(db){
  _espCache = db;
  // Persiste aussi dans le cache d'onglet : sans cela, un compte créé (inscription) ou modifié
  // (avatar, e-mail...) reste absent du cache lu à la page suivante ou après F5. La clé "password"
  // est retirée de la copie : l'inscription y a mis le mot de passe saisi, qui ne doit pas être
  // écrit dans le cache (les listes serveur, elles, ne le contiennent jamais).
  try {
    sessionStorage.setItem(ESP_CACHE_KEY, JSON.stringify(db, (k, v) => k === 'password' ? undefined : v));
  } catch(e){
    // Écriture impossible (quota, stockage bloqué) : mieux vaut aucun cache qu'un cache
    // antérieur à ce changement, la page suivante rechargera depuis le serveur.
    try { sessionStorage.removeItem(ESP_CACHE_KEY); } catch(e2){}
  }
}

// ---------------- Inscription (création de compte) ----------------
// Autorisée directement : chaque personne ne crée que SON PROPRE compte.
async function espInsertEleve(row){
  const { error } = await supabaseClient.from('eleves').insert([row]);
  if(error){ throw error; }
}
async function espInsertInspecteur(row){
  const { error } = await supabaseClient.from('inspecteurs').insert([row]);
  if(error){ throw error; }
}
async function espInsertEtablissement(row){
  const { data, error } = await supabaseClient.rpc('etablissement_register', {
    p_id: row.id, p_nom: row.nom, p_region: row.region, p_ville: row.ville, p_quartier: row.quartier,
    p_type: row.type, p_responsable: row.responsable, p_tel: row.tel, p_email: row.email, p_password: row.password,
    p_date_inscription: row.date_inscription, p_filieres_proposees: row.filieres_proposees, p_photos: row.photos || [],
    p_categorie: row.categorie || null, p_sous_categorie: row.sous_categorie || null, p_secteur: row.secteur || null,
    p_tel2: row.tel2 || null, p_tel3: row.tel3 || null, p_site_web: row.site_web || null,
    p_contact_tel: row.contact_tel || null, p_logo_url: row.logo_url || null,
  });
  if(error){ throw error; }
  if(!data){ throw new Error("Inscription refusée (e-mail déjà utilisé, ou champ obligatoire manquant)."); }
}
// Vérification en temps réel (non bloquante) : un établissement existe-t-il déjà avec ce nom ?
// Comparaison insensible à la casse et aux espaces, faite côté serveur (lower(trim(nom))),
// contre etablissements ET les demandes d'inscription en attente.
async function espEtabVerifierDoublonRPC(nom){
  const { data, error } = await supabaseClient.rpc('etablissement_verifier_doublon', { p_nom: nom });
  if(error) throw error;
  return !!data;
}

// ---------------- Demandes d'inscription en attente (admin) ----------------
// Les inscriptions directes n'insèrent plus dans etablissements : elles créent une
// demande que l'admin examine (doublons non détectés automatiquement) avant de
// l'importer lui-même via le circuit d'import en masse existant.
function espRowToDemandeInscription(r){
  return {
    id: r.id, nom: r.nom, region: r.region||'', ville: r.ville, quartier: r.quartier||'', type: r.type,
    responsable: r.responsable||'', tel: r.tel||'', tel2: r.tel2||'', tel3: r.tel3||'', email: r.email,
    siteWeb: r.site_web||'', contactTel: r.contact_tel||'', dateInscription: r.date_inscription,
    filieresProposees: r.filieres_proposees||[], photos: r.photos||[], logoUrl: r.logo_url||'',
    categorie: r.categorie||'', sousCategorie: r.sous_categorie||'', secteur: r.secteur||'',
    dateDemande: r.date_demande, statutDemande: r.statut_demande,
  };
}
// Admin : authentifié par le jeton de session (espAuthRpc, auth.js), comme les élèves.
async function espAdminListDemandesInscriptionRPC(){
  return ((await espAuthRpc('admin_list_demandes_inscription_etablissements_v2')) || []).map(espRowToDemandeInscription);
}
async function espAdminMarquerDemandeTraiteeRPC(demandeId){
  return !!(await espAuthRpc('admin_marquer_demande_traitee_v2', { p_demande_id: demandeId }));
}
// Recopie photos/logo_url d'une demande vers l'établissement fraîchement importé (import
// texte, cf. admin_bulk_import_etablissements) et marque la demande traitée en une seule
// opération — cf. supabase-migration-2026-08-22-lien-demande-etablissement.sql.
async function espAdminLierPhotosLogoDemandeRPC(demandeId, etablissementId){
  return !!(await espAuthRpc('admin_lier_photos_logo_demande_v2', { p_demande_id: demandeId, p_etablissement_id: etablissementId }));
}

// ---------------- Connexion (vérifiée côté serveur, mot de passe jamais renvoyé) ----------------
// Ouverture de session élève par jeton : null (identifiants incorrects), {banni:true}
// (compte suspendu, aucune session créée) ou {token, expires_at, id, ...fiche}.
async function espEleveSessionOpenRPC(tel, password){
  const { data, error } = await supabaseClient.rpc('eleve_session_open', { p_tel: tel, p_password: password });
  if(error) throw error;
  return data || null;
}
// Ouverture de session inspecteur par jeton : null (téléphone ou mot de passe incorrects),
// {banni:true} (compte suspendu, aucune session créée) ou {token, expires_at, id, nom, prenoms}.
// Téléphone comparé tel quel côté serveur. Session serveur de 30 jours.
async function espInspecteurSessionOpenRPC(tel, password){
  const { data, error } = await supabaseClient.rpc('inspecteur_session_open', { p_tel: tel, p_password: password });
  if(error) throw error;
  return data || null;
}
async function espInspecteurLoginRPC(tel, password){
  const { data, error } = await supabaseClient.rpc('inspecteur_login', { p_tel: tel, p_password: password });
  if(error) throw error;
  return (data && data[0]) || null;
}
async function espEtabLoginRPC(email, password){
  const { data, error } = await supabaseClient.rpc('etablissement_login', { p_email: email, p_password: password });
  if(error) throw error;
  return (data && data[0]) || null;
}
// Récupération d'un compte établissement pré-inscrit (import en masse) via le
// code unique remis hors-plateforme. L'établissement choisit à ce moment-là
// son propre e-mail et mot de passe.
async function espEtabClaimRPC(code, email, password, responsable, tel, tel2, tel3, siteWeb, contactTel){
  const { data, error } = await supabaseClient.rpc('etablissement_claim_by_code', {
    p_code: code, p_email: email, p_password: password,
    p_responsable: responsable || null, p_tel: tel || null, p_tel2: tel2 || null, p_tel3: tel3 || null,
    p_site_web: siteWeb || null, p_contact_tel: contactTel || null,
  });
  if(error) throw error;
  return !!data;
}
// Ouverture de session établissement par jeton : null (e-mail inconnu, mauvais mot de passe ou
// fiche non réclamée, indistinguables) ou {token, expires_at, id, nom}. Session serveur de 30 jours.
async function espEtabSessionOpenRPC(email, password){
  const { data, error } = await supabaseClient.rpc('etablissement_session_open', { p_email: email, p_password: password });
  if(error) throw error;
  return data || null;
}
// Fiche complète, non masquée, de l'établissement connecté (responsable/contact_tel inclus,
// tel/tel2/tel3/email/site_web/photos jamais masqués par le premium) — alimente son tableau de bord.
// Établissement : authentifié par le jeton de session (espAuthRpc, auth.js) ; la fiche est celle du jeton.
async function espEtabGetOwnRPC(){
  const data = await espAuthRpc('etablissement_get_own_v2');
  return (data && data[0]) ? espRowToEtab(data[0]) : null;
}
// Ouverture de session admin par jeton : null (e-mail inconnu, mauvais mot de passe ou compte
// désactivé, indistinguables) ou {token, expires_at, id, nom}. Session serveur de 24 h.
async function espAdminSessionOpenRPC(email, password){
  const { data, error } = await supabaseClient.rpc('admin_session_open', { p_email: email, p_password: password });
  if(error) throw error;
  return data || null;
}

// ---------------- Statistiques de visites (log brut, écriture publique) ----------------
// Callable sans mot de passe (simple compteur de passage) : log_visite() côté base valide
// p_page contre la liste fermée des 7 vraies pages du site et rejette silencieusement
// (retourne false) toute autre valeur, donc pas besoin de revalider ici.
async function espLogVisiteRPC(page){
  const { data, error } = await supabaseClient.rpc('log_visite', { p_page: page });
  if(error) throw error;
  return !!data;
}
// Statistiques agrégées (jour/page/nombre de visites), réservées à l'admin. Jeton refusé :
// P0401, géré par espAuthRpc (admin_get_visite_stats_v2 agrège déjà côté base, on ne fait
// que renvoyer les lignes telles quelles).
async function espAdminGetVisiteStatsRPC(){
  return (await espAuthRpc('admin_get_visite_stats_v2')) || [];
}

// ---------------- Actions d'écriture sécurisées (vérifient l'identité côté serveur) ----------------
// Élève : authentifié par le jeton de session (espAuthRpc, auth.js).
async function espSaveRiasecRPC(riasec){
  return !!(await espAuthRpc('eleve_save_riasec', { p_riasec: riasec }));
}
// Inspecteur : authentifié par le jeton de session (espAuthRpc, auth.js) ; la fiche est celle du jeton.
async function espPostMessageRPC(texte, type, replyTo, attachment){
  return !!(await espAuthRpc('inspecteur_post_message_v2', {
    p_texte: texte, p_type: type || 'C', p_reply_to: replyTo || null,
    p_attachment_url: (attachment && attachment.url) || null, p_attachment_type: (attachment && attachment.type) || null, p_attachment_name: (attachment && attachment.name) || null,
  }));
}
async function espAdminPostMessageRPC(texte, type, replyTo, attachment){
  return !!(await espAuthRpc('admin_post_message_v2', {
    p_texte: texte, p_type: type || 'O', p_reply_to: replyTo || null,
    p_attachment_url: (attachment && attachment.url) || null, p_attachment_type: (attachment && attachment.type) || null, p_attachment_name: (attachment && attachment.name) || null,
  }));
}
// ---------------- Messagerie privée : envoyer / marquer comme lu ----------------
async function espPostPrivateMessageRPC(destinataireId, texte, attachment){
  return !!(await espAuthRpc('inspecteur_post_private_message_v2', {
    p_destinataire_id: destinataireId, p_texte: texte,
    p_attachment_url: (attachment && attachment.url) || null, p_attachment_type: (attachment && attachment.type) || null, p_attachment_name: (attachment && attachment.name) || null,
  }));
}
async function espMarkPrivateReadRPC(autreId){
  return !!(await espAuthRpc('inspecteur_mark_private_read_v2', { p_autre_id: autreId }));
}
async function espInspecteurRequestCertificationRPC(){
  return !!(await espAuthRpc('inspecteur_request_certification_v2'));
}
async function espInspecteurUpdateAvatarRPC(avatarUrl){
  return !!(await espAuthRpc('inspecteur_update_avatar_v2', { p_avatar_url: avatarUrl }));
}
async function espInspecteurUpdateMessageAccueilRPC(messageAccueil){
  return !!(await espAuthRpc('inspecteur_update_message_accueil_v2', { p_message_accueil: messageAccueil }));
}
// ---------------- Suivi d'élèves par l'inspecteur (répertoire privé, saisie libre) ----------------
// Inspecteur : par jeton (espAuthRpc) ; seules les fiches de l'inspecteur du jeton sont accessibles.
async function espSuiviAddEleveRPC(nom, prenoms, classe, raisons){
  return await espAuthRpc('inspecteur_suivi_add_eleve_v2', {
    p_nom: nom, p_prenoms: prenoms || null, p_classe: classe, p_raisons: raisons,
  });
}
async function espSuiviListElevesRPC(){
  return ((await espAuthRpc('inspecteur_suivi_list_eleves_v2')) || []).map(espRowToSuiviEleve);
}
async function espSuiviGetEleveRPC(suiviId){
  const data = await espAuthRpc('inspecteur_suivi_get_eleve_v2', { p_suivi_id: suiviId });
  return (data && data[0]) ? espRowToSuiviEleve(data[0]) : null;
}
async function espSuiviDeleteEleveRPC(suiviId){
  return !!(await espAuthRpc('inspecteur_suivi_delete_eleve_v2', { p_suivi_id: suiviId }));
}
async function espSuiviSetAppreciationRPC(suiviId, appreciation){
  return !!(await espAuthRpc('inspecteur_suivi_set_appreciation_v2', { p_suivi_id: suiviId, p_appreciation: appreciation }));
}
async function espSuiviAddNoteRPC(suiviId, dateNote, texte){
  return !!(await espAuthRpc('inspecteur_suivi_add_note_v2', { p_suivi_id: suiviId, p_date_note: dateNote, p_texte: texte }));
}
async function espSuiviListNotesRPC(suiviId){
  return ((await espAuthRpc('inspecteur_suivi_list_notes_v2', { p_suivi_id: suiviId })) || []).map(espRowToSuiviNote);
}
async function espUploadChatFile(file){
  const ext = (file.name.split('.').pop() || 'bin').toLowerCase();
  const path = 'chat/' + Date.now().toString(36) + Math.random().toString(36).slice(2,8) + '.' + ext;
  const { error } = await supabaseClient.storage.from('orimetier-chat').upload(path, file);
  if(error) throw error;
  const { data } = supabaseClient.storage.from('orimetier-chat').getPublicUrl(path);
  return data.publicUrl;
}
async function espUploadAvatarFile(file){
  const ext = (file.name.split('.').pop() || 'jpg').toLowerCase();
  const path = 'avatars/' + Date.now().toString(36) + Math.random().toString(36).slice(2,8) + '.' + ext;
  const { error } = await supabaseClient.storage.from('orimetier-chat').upload(path, file);
  if(error) throw error;
  const { data } = supabaseClient.storage.from('orimetier-chat').getPublicUrl(path);
  return data.publicUrl;
}
async function espAdminDeleteMessageRPC(messageId){
  return !!(await espAuthRpc('admin_delete_message_v2', { p_message_id: messageId }));
}
// p_id null = création, sinon mise à jour. Retourne l'id de la ligne (ou null si refusé).
async function espAdminUpsertLienFormationRPC(id, titre, description, url, audience){
  return await espAuthRpc('admin_upsert_lien_formation_v2', {
    p_id: id || null, p_titre: titre, p_description: description,
    p_url: url, p_audience: audience,
  });
}
async function espAdminDeleteLienFormationRPC(id){
  return !!(await espAuthRpc('admin_delete_lien_formation_v2', { p_id: id }));
}
// ---------------- Bandeau d'annonce admin (site-wide) ----------------
async function espUploadAnnonceImage(file){
  const ext = (file.name.split('.').pop() || 'jpg').toLowerCase();
  const path = 'annonces/' + Date.now().toString(36) + Math.random().toString(36).slice(2,8) + '.' + ext;
  const { error } = await supabaseClient.storage.from('orimetier-chat').upload(path, file);
  if(error) throw error;
  const { data } = supabaseClient.storage.from('orimetier-chat').getPublicUrl(path);
  return data.publicUrl;
}
// p_id null = création (publiée immédiatement), sinon modification du contenu d'une
// annonce précise (son statut actif/inactif n'est pas touché). Retourne l'id de la ligne
// créée/modifiée, ou null si refusé (contenu manquant, annonce introuvable, ou déjà 5
// annonces actives lors d'une création).
async function espAdminUpsertAnnonceRPC(id, type, texte, imageUrl){
  return await espAuthRpc('admin_upsert_annonce_v2', {
    p_id: id || null, p_type: type, p_texte: texte || null, p_image_url: imageUrl || null,
  });
}
async function espAdminSetAnnonceActiveRPC(id, active){
  return !!(await espAuthRpc('admin_set_annonce_active_v2', { p_id: id, p_active: active }));
}
async function espAdminSupprimerAnnonceRPC(id){
  return !!(await espAuthRpc('admin_supprimer_annonce_v2', { p_id: id }));
}
async function espAdminSetInspecteurBanniRPC(inspecteurId, banni){
  return !!(await espAuthRpc('admin_set_inspecteur_banni_v2', { p_inspecteur_id: inspecteurId, p_banni: banni }));
}
async function espAdminSetInspecteurCertifieRPC(inspecteurId, certifie){
  return !!(await espAuthRpc('admin_set_inspecteur_certifie_v2', { p_inspecteur_id: inspecteurId, p_certifie: certifie }));
}
async function espAdminSetEleveBanniRPC(eleveId, banni){
  return !!(await espAuthRpc('admin_set_eleve_banni_v2', { p_eleve_id: eleveId, p_banni: banni }));
}
async function espSetEtabStatutRPC(etabId, statut){
  return !!(await espAuthRpc('admin_set_etab_statut_v2', { p_etab_id: etabId, p_statut: statut }));
}
async function espEtabUpdateLocalisationRPC(region, ville, quartier){
  return !!(await espAuthRpc('etablissement_update_localisation_v2', { p_region: region, p_ville: ville, p_quartier: quartier }));
}
async function espSetFiliereStatutRPC(etabId, filiereId, statut){
  return !!(await espAuthRpc('admin_set_filiere_statut_v2', { p_etab_id: etabId, p_filiere_id: filiereId, p_statut: statut }));
}
// Élève : par jeton. Lève EMAIL_DEJA_UTILISE si un autre élève porte déjà cet e-mail.
async function espUpdateEleveEmailRPC(email){
  return !!(await espAuthRpc('eleve_update_email', { p_email: email }));
}
// Inspecteur : par jeton. Lève EMAIL_DEJA_UTILISE si un autre inspecteur porte déjà cet e-mail.
async function espUpdateInspecteurEmailRPC(email){
  return !!(await espAuthRpc('inspecteur_update_email_v2', { p_email: email }));
}
// Mot de passe oublié : le jeton est généré et envoyé par e-mail côté serveur (Edge Function).
// Réponse toujours { ok: true } si la requête est bien formée, que le compte existe ou non.
async function espRequestPasswordReset(role, email){
  const { error } = await supabaseClient.functions.invoke('request-password-reset', { body: { role, email } });
  if(error) throw error;
}
async function espResetPasswordWithTokenRPC(token, newPassword){
  const { data, error } = await supabaseClient.rpc('reset_password_with_token', { p_token: token, p_new_password: newPassword });
  if(error) throw error;
  return !!data;
}

function espUid(){ return 'id' + Date.now().toString(36) + Math.random().toString(36).slice(2,8); }
function espDate(){ return new Date().toLocaleDateString('fr-FR', {day:'2-digit', month:'2-digit', year:'numeric'}); }

// ---------------- Conversion des lignes LYCAM (snake_case) <-> camelCase ----------------
function espRowToLycamSession(r){ return { id:r.id, inspecteurId:r.inspecteur_id, nom:r.nom, createdAt:r.created_at }; }
function espRowToLycamResultat(r){ return { id:r.id, sessionId:r.session_id, inspecteurId:r.inspecteur_id, nom:r.nom, prenom:r.prenom, naissance:r.naissance, classe:r.classe, scoreTotal:r.score_total, band:r.band, scores:r.scores, createdAt:r.created_at }; }

// ---------------- Test LYCAM : sessions et résultats (espace inspecteur) ----------------
// Inspecteur : par jeton (espAuthRpc) ; seules les sessions de l'inspecteur du jeton sont accessibles.
async function espLycamCreateSessionRPC(nom){
  return (await espAuthRpc('inspecteur_lycam_create_session_v2', { p_nom: nom })) || null; // id de la session créée, ou null si échec
}
async function espLycamSaveResultRPC(sessionId, eleve, scoreTotal, band, scores){
  return !!(await espAuthRpc('inspecteur_lycam_save_result_v2', {
    p_session_id: sessionId,
    p_nom: eleve.nom, p_prenom: eleve.prenom, p_naissance: eleve.naissance, p_classe: eleve.classe,
    p_score_total: scoreTotal, p_band: band, p_scores: scores,
  }));
}
async function espLycamListSessionsRPC(){
  return ((await espAuthRpc('inspecteur_lycam_list_sessions_v2')) || []).map(espRowToLycamSession);
}
async function espLycamListResultsRPC(sessionId){
  return ((await espAuthRpc('inspecteur_lycam_list_results_v2', { p_session_id: sessionId })) || []).map(espRowToLycamResultat);
}

// ---------------- Conversion des lignes MBTI (snake_case) <-> camelCase ----------------
function espRowToMbtiSession(r){ return { id:r.id, inspecteurId:r.inspecteur_id, nom:r.nom, createdAt:r.created_at }; }
function espRowToMbtiResultat(r){ return { id:r.id, sessionId:r.session_id, inspecteurId:r.inspecteur_id, nom:r.nom, prenom:r.prenom, naissance:r.naissance, classe:r.classe, scores:r.scores, typeLetters:r.type_letters, hierarchie:r.hierarchie, egalites:r.egalites, createdAt:r.created_at }; }

// ---------------- Test MBTI : sessions et résultats (espace inspecteur) ----------------
// Inspecteur : par jeton (espAuthRpc) ; seules les sessions de l'inspecteur du jeton sont accessibles.
async function espMbtiCreateSessionRPC(nom){
  return (await espAuthRpc('inspecteur_mbti_create_session_v2', { p_nom: nom })) || null; // id de la session créée, ou null si échec
}
async function espMbtiSaveResultRPC(sessionId, eleve, scores, typeLetters, hierarchie, egalites){
  return !!(await espAuthRpc('inspecteur_mbti_save_result_v2', {
    p_session_id: sessionId,
    p_nom: eleve.nom, p_prenom: eleve.prenom, p_naissance: eleve.naissance, p_classe: eleve.classe,
    p_scores: scores, p_type_letters: typeLetters, p_hierarchie: hierarchie, p_egalites: egalites,
  }));
}
async function espMbtiListSessionsRPC(){
  return ((await espAuthRpc('inspecteur_mbti_list_sessions_v2')) || []).map(espRowToMbtiSession);
}
async function espMbtiListResultsRPC(sessionId){
  return ((await espAuthRpc('inspecteur_mbti_list_results_v2', { p_session_id: sessionId })) || []).map(espRowToMbtiResultat);
}

// ---------------- Établissement : photos et modification des informations générales ----------------
async function espUploadEtabPhoto(file){
  const ext = (file.name.split('.').pop() || 'jpg').toLowerCase();
  const path = 'etablissements/' + Date.now().toString(36) + Math.random().toString(36).slice(2,8) + '.' + ext;
  const { error } = await supabaseClient.storage.from('orimetier-chat').upload(path, file);
  if(error) throw error;
  const { data } = supabaseClient.storage.from('orimetier-chat').getPublicUrl(path);
  return data.publicUrl;
}
// Lève EMAIL_DEJA_UTILISE si un autre établissement porte déjà cet e-mail.
async function espEtabUpdateInfoRPC(nom, type, responsable, tel, email, contactTel){
  return !!(await espAuthRpc('etablissement_update_info_v2', {
    p_nom: nom, p_type: type, p_responsable: responsable, p_tel: tel, p_email: email,
    p_contact_tel: contactTel || null,
  }));
}
async function espEtabUpdatePhotosRPC(photos){
  return !!(await espAuthRpc('etablissement_update_photos_v2', { p_photos: photos }));
}
// Logo (un seul fichier, contrairement aux photos) : même bucket/dossier que les photos
// d'établissement, même mécanisme d'upload.
async function espUploadEtabLogo(file){
  const ext = (file.name.split('.').pop() || 'jpg').toLowerCase();
  const path = 'etablissements/logo-' + Date.now().toString(36) + Math.random().toString(36).slice(2,8) + '.' + ext;
  const { error } = await supabaseClient.storage.from('orimetier-chat').upload(path, file);
  if(error) throw error;
  const { data } = supabaseClient.storage.from('orimetier-chat').getPublicUrl(path);
  return data.publicUrl;
}
async function espEtabUpdateLogoRPC(logoUrl){
  return !!(await espAuthRpc('etablissement_update_logo_v2', { p_logo_url: logoUrl || null }));
}
// ---------------- Établissement Premium : contact direct, site web, filières libres ----------------
async function espEtabUpdateContactExtrasRPC(tel2, tel3, siteWeb){
  return !!(await espAuthRpc('etablissement_update_contact_extras_v2', {
    p_tel2: tel2 || null, p_tel3: tel3 || null, p_site_web: siteWeb || null,
  }));
}
async function espEtabAddFiliereRPC(nom, diplome){
  return !!(await espAuthRpc('etablissement_add_filiere_v2', { p_nom: nom, p_diplome: diplome }));
}
async function espEtabDeleteFiliereRPC(filiereId){
  return !!(await espAuthRpc('etablissement_delete_filiere_v2', { p_filiere_id: filiereId }));
}
async function espEtabDemanderPremiumRPC(){
  return !!(await espAuthRpc('etablissement_demander_premium_v2'));
}
async function espAdminSetEtabPremiumRPC(etabId, premium){
  return !!(await espAuthRpc('admin_set_etab_premium_v2', { p_etab_id: etabId, p_premium: premium }));
}
async function espAdminValiderPremiumRPC(etabId){
  return !!(await espAuthRpc('admin_valider_premium_v2', { p_etab_id: etabId }));
}
// Version complète (responsable, contact_tel, email/tel non masqués) réservée à l'espace
// admin : contrairement à list_etablissements() (publique, masquée), jamais mise dans le
// cache partagé espDB() — consommée séparément par la vue "Établissements" de admin.js.
async function espAdminListEtablissementsFullRPC(){
  return (await espAuthRpc('admin_list_etablissements_full_v2')) || [];
}

// ---------------- Admin : suppression et classification d'un établissement ----------------
async function espAdminDeleteEtabRPC(etabId){
  return !!(await espAuthRpc('admin_delete_etablissement_v2', { p_etab_id: etabId }));
}
async function espAdminUpdateEtabClassificationRPC(etabId, categorie, sousCategorie, secteur){
  return !!(await espAuthRpc('admin_update_etab_classification_v2', {
    p_etab_id: etabId, p_categorie: categorie, p_sous_categorie: sousCategorie, p_secteur: secteur,
  }));
}
// Import en masse d'établissements (Général ou Supérieur privé) pré-inscrits par
// l'administrateur. categorie : 'general' | 'superieur'. sousCategorie : requis
// seulement si categorie='superieur' ('universite' | 'grande_ecole'), sinon null.
// items : tableau de { nom, region, ville, quartier, secteur, responsable, tel }.
// Retourne, pour chaque ligne importée, le code de récupération à transmettre
// hors-plateforme à l'établissement concerné.
async function espAdminBulkImportEtabRPC(categorie, sousCategorie, items){
  return (await espAuthRpc('admin_bulk_import_etablissements_v2', {
    p_categorie: categorie, p_sous_categorie: sousCategorie || null, p_items: items,
  })) || [];
}
// Liste permanente des établissements pré-inscrits pas encore réclamés, avec leur code
// (contrairement au résultat affiché juste après un import, disponible à tout moment).
async function espAdminListUnclaimedCodesRPC(){
  return (await espAuthRpc('admin_list_unclaimed_codes_v2')) || [];
}
// Liste permanente de TOUS les établissements pré-inscrits avec leur code de
// récupération, réclamé ou non (contrairement à admin_list_unclaimed_codes qui
// ne renvoie que les codes pas encore réclamés) — utilisée pour l'export CSV/Excel.
async function espAdminListAllEtabCodesRPC(){
  return (await espAuthRpc('admin_list_all_etablissement_codes_v2')) || [];
}

// ---------------- Admin : comptes admin (5 actifs au maximum, au moins 1 ; un seul principal) ----------------
// Liste, sans aucun mot de passe : [{id, nom, email, actif, est_principal, created_at, last_login_at}].
async function espAdminListAdminsRPC(){
  return (await espAuthRpc('admin_list_admins_v2')) || [];
}
// Nouveau compte, actif, jamais principal : renvoie {id, nom, email}. Réservée au principal.
// Erreurs métier (e.message) : ADMIN_PRINCIPAL_REQUIS, CHAMPS_OBLIGATOIRES, EMAIL_INVALIDE,
// EMAIL_DEJA_UTILISE, MOT_DE_PASSE_TROP_COURT, ADMINS_LIMITE_ATTEINTE.
async function espAdminCreateAdminRPC(nom, email, password){
  return await espAuthRpc('admin_create_admin_v2', { p_nom: nom, p_email: email, p_password: password });
}
// true : fait ; false : admin introuvable. Réservée au principal. Erreurs métier (e.message) :
// ADMIN_PRINCIPAL_REQUIS, ADMIN_AUTO_DESACTIVATION, ADMIN_PRINCIPAL_PROTEGE, DERNIER_ADMIN_ACTIF,
// ADMINS_LIMITE_ATTEINTE. Une désactivation ferme les sessions de l'admin visé.
async function espAdminSetAdminActifRPC(adminId, actif){
  return !!(await espAuthRpc('admin_set_admin_actif_v2', { p_admin_id: adminId, p_actif: actif }));
}
// Transfère le rôle d'admin principal à un autre admin actif. true : fait ; false : admin
// introuvable. Réservée au principal, qui perd ce rôle (ses sessions restent ouvertes).
// Erreurs métier (e.message) : ADMIN_PRINCIPAL_REQUIS, TRANSFERT_VERS_SOI, CIBLE_INACTIVE,
// ADMIN_PRINCIPAL_INVARIANT.
async function espAdminTransferPrincipalRPC(adminId){
  return !!(await espAuthRpc('admin_transfer_principal_v2', { p_admin_id: adminId }));
}
