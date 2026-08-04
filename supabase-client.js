// ============================================================
// ---- Connexion Supabase / EmailJS + accès aux données ----
// ============================================================

// ---------------- Connexion Supabase (base de données partagée) ----------------
// ⚠️ Remplace ces deux valeurs par celles de TON projet Supabase
// (Supabase > Project Settings > API > Project URL / anon public key)
const SUPABASE_URL = 'https://ltfxaxzkuyejcluoaimq.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_h7s1eQ5VX8iBU2KYTpnZ3w_xRB9Mbl7';
const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ---------------- Connexion EmailJS (envoi d'e-mails depuis le navigateur, sans serveur) ----------------
// ⚠️ Remplace ces trois valeurs par celles de TON compte EmailJS (emailjs.com)
const EMAILJS_PUBLIC_KEY = 'mqDopJTLtKzHrGnmn';
const EMAILJS_SERVICE_ID = 'service_ng3gj85';
const EMAILJS_TEMPLATE_ID = 'ffteslj';
if(window.emailjs) window.emailjs.init({ publicKey: EMAILJS_PUBLIC_KEY });

// Cache local synchronisé avec Supabase (rempli par espLoadFromSupabase())
let _espCache = null;
// Cache local des messages privés de l'inspecteur connecté (rempli par espLoadPrivateMessages())
let _espPrivateCache = [];

// ---------------- Conversion snake_case (Supabase) <-> camelCase (app) ----------------
function espRowToEleve(r){ return { id:r.id, nom:r.nom, prenoms:r.prenoms, classe:r.classe, etablissement:r.etablissement, tel:r.tel, email:r.email, password:r.password, riasec:r.riasec, active:r.active, dateInscription:r.date_inscription, banni:!!r.banni }; }
function espEleveToRow(e){ return { id:e.id, nom:e.nom, prenoms:e.prenoms, classe:e.classe, etablissement:e.etablissement, tel:e.tel, email:e.email, password:e.password, riasec:e.riasec, active:!!e.active, date_inscription:e.dateInscription, banni:!!e.banni }; }
function espRowToInspecteur(r){ return { id:r.id, nom:r.nom, prenoms:r.prenoms, fonction:r.fonction, cio:r.cio, tel:r.tel, email:r.email, password:r.password, active:r.active, dateInscription:r.date_inscription, certifie:!!r.certifie, banni:!!r.banni, avatarUrl:r.avatar_url||null, certificationDemandee:!!r.certification_demandee, messageAccueil:r.message_accueil||'' }; }
function espInspecteurToRow(i){ return { id:i.id, nom:i.nom, prenoms:i.prenoms, fonction:i.fonction, cio:i.cio, tel:i.tel, email:i.email, password:i.password, active:!!i.active, date_inscription:i.dateInscription }; }
function espRowToEtab(r){ return { id:r.id, nom:r.nom, region:r.region||'', ville:r.ville, quartier:r.quartier||'', type:r.type, responsable:r.responsable, tel:r.tel, email:r.email, password:r.password, statut:r.statut, active:r.active, dateInscription:r.date_inscription, filieresProposees:r.filieres_proposees||[] }; }
function espEtabToRow(e){ return { id:e.id, nom:e.nom, region:e.region||'', ville:e.ville, quartier:e.quartier||'', type:e.type, responsable:e.responsable, tel:e.tel, email:e.email, password:e.password, statut:e.statut, active:!!e.active, date_inscription:e.dateInscription, filieres_proposees:e.filieresProposees||[] }; }
function espRowToNote(r){ return { id:r.id, eleveId:r.eleve_id, inspecteurId:r.inspecteur_id, inspecteurNom:r.inspecteur_nom, texte:r.texte, date:r.date }; }
function espNoteToRow(n){ return { id:n.id, eleve_id:n.eleveId, inspecteur_id:n.inspecteurId, inspecteur_nom:n.inspecteurNom, texte:n.texte, date:n.date }; }
function espRowToMessage(r){ return { id:r.id, inspecteurId:r.inspecteur_id, inspecteurNom:r.inspecteur_nom, texte:r.texte, date:r.date, type:r.type||'C', auteurRole:r.auteur_role||'inspecteur', replyTo:r.reply_to||null, attachmentUrl:r.attachment_url||null, attachmentType:r.attachment_type||null, attachmentName:r.attachment_name||null }; }
function espRowToPrivateMessage(r){ return { id:r.id, expediteurId:r.expediteur_id, destinataireId:r.destinataire_id, texte:r.texte, date:r.date, lu:!!r.lu, attachmentUrl:r.attachment_url||null, attachmentType:r.attachment_type||null, attachmentName:r.attachment_name||null }; }

// ---------------- Chargement initial depuis Supabase (jamais les mots de passe) ----------------
async function espLoadFromSupabase(){
  // eleves/inspecteurs/etablissements n'accordent pas de SELECT direct à la clé
  // publique (pas de grant anon) : on passe par des fonctions RPC dédiées qui ne
  // renvoient jamais la colonne "password", plutôt que par une lecture de table.
  const [elevesRes, inspecteursRes, etabRes, notesRes, messagesRes] = await Promise.all([
    supabaseClient.rpc('list_eleves'),
    supabaseClient.rpc('list_inspecteurs'),
    supabaseClient.rpc('list_etablissements'),
    supabaseClient.from('notes').select('*'),
    supabaseClient.from('messages_inspecteurs').select('*').order('created_at', { ascending: true }),
  ]);
  [elevesRes, inspecteursRes, etabRes, notesRes, messagesRes].forEach(r => { if(r.error) throw r.error; });

  _espCache = {
    eleves: (elevesRes.data||[]).map(espRowToEleve),
    inspecteurs: (inspecteursRes.data||[]).map(espRowToInspecteur),
    etablissements: (etabRes.data||[]).map(espRowToEtab),
    notes: (notesRes.data||[]).map(espRowToNote),
    messages: (messagesRes.data||[]).map(espRowToMessage),
  };
}

// ---------------- Messagerie privée (1-à-1 entre inspecteurs) ----------------
// Contrairement au chat de groupe, ces messages ne sont jamais lisibles publiquement :
// la fonction RPC ne renvoie que les messages où l'inspecteur connecté est expéditeur
// ou destinataire — jamais les conversations des autres inspecteurs.
async function espLoadPrivateMessages(){
  const session = espSession();
  if(!session || session.role !== 'inspecteur'){ _espPrivateCache = []; return; }
  const { data, error } = await supabaseClient.rpc('inspecteur_list_private_messages', { p_inspecteur_id: session.id, p_password: session.password });
  if(error) throw error;
  _espPrivateCache = (data||[]).map(espRowToPrivateMessage);
}
function espPrivateMessages(){
  return _espPrivateCache || [];
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
      await espLoadFromSupabase();
      const session = espSession();
      if(session && session.role === 'inspecteur') await espLoadPrivateMessages();
      // Ne rafraîchit l'écran que si la page courante déclare un rafraîchissement
      // (pour ne pas perturber un formulaire de connexion en cours de saisie).
      if(espSession() && window.pageRefresh) window.pageRefresh();
    } catch(e){ console.error('[esp] échec du rafraîchissement temps réel', e); }
  }, 600);
}

function espDB(){
  return _espCache || { eleves:[], inspecteurs:[], etablissements:[], notes:[], messages:[] };
}
// Reflète un changement dans le cache local (affichage immédiat), sans jamais envoyer
// le tableau complet au serveur : chaque écriture réelle passe par une fonction dédiée ci-dessous.
function espSaveDB(db){
  _espCache = db;
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
    p_date_inscription: row.date_inscription, p_filieres_proposees: row.filieres_proposees,
  });
  if(error){ throw error; }
  if(!data){ throw new Error("Inscription refusée (e-mail déjà utilisé, ou champ obligatoire manquant)."); }
}

// ---------------- Connexion (vérifiée côté serveur, mot de passe jamais renvoyé) ----------------
async function espEleveLoginRPC(tel, password){
  const { data, error } = await supabaseClient.rpc('eleve_login', { p_tel: tel, p_password: password });
  if(error) throw error;
  return (data && data[0]) || null;
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
async function espAdminLoginRPC(password){
  const { data, error } = await supabaseClient.rpc('admin_login', { p_password: password });
  if(error) throw error;
  return !!data;
}

// ---------------- Actions d'écriture sécurisées (vérifient l'identité côté serveur) ----------------
async function espSaveRiasecRPC(eleveId, password, riasec){
  const { data, error } = await supabaseClient.rpc('eleve_save_riasec', { p_id: eleveId, p_password: password, p_riasec: riasec });
  if(error) throw error;
  return !!data;
}
async function espAddNoteRPC(inspecteurId, password, eleveId, texte){
  const { data, error } = await supabaseClient.rpc('inspecteur_add_note', { p_inspecteur_id: inspecteurId, p_password: password, p_eleve_id: eleveId, p_texte: texte });
  if(error) throw error;
  return !!data;
}
async function espPostMessageRPC(inspecteurId, password, texte, type, replyTo, attachment){
  const { data, error } = await supabaseClient.rpc('inspecteur_post_message', {
    p_inspecteur_id: inspecteurId, p_password: password, p_texte: texte, p_type: type || 'C', p_reply_to: replyTo || null,
    p_attachment_url: (attachment && attachment.url) || null, p_attachment_type: (attachment && attachment.type) || null, p_attachment_name: (attachment && attachment.name) || null,
  });
  if(error) throw error;
  return !!data;
}
async function espAdminPostMessageRPC(adminPassword, texte, type, replyTo, attachment){
  const { data, error } = await supabaseClient.rpc('admin_post_message', {
    p_admin_password: adminPassword, p_texte: texte, p_type: type || 'O', p_reply_to: replyTo || null,
    p_attachment_url: (attachment && attachment.url) || null, p_attachment_type: (attachment && attachment.type) || null, p_attachment_name: (attachment && attachment.name) || null,
  });
  if(error) throw error;
  return !!data;
}
// ---------------- Messagerie privée : envoyer / marquer comme lu ----------------
async function espPostPrivateMessageRPC(expediteurId, password, destinataireId, texte, attachment){
  const { data, error } = await supabaseClient.rpc('inspecteur_post_private_message', {
    p_expediteur_id: expediteurId, p_password: password, p_destinataire_id: destinataireId, p_texte: texte,
    p_attachment_url: (attachment && attachment.url) || null, p_attachment_type: (attachment && attachment.type) || null, p_attachment_name: (attachment && attachment.name) || null,
  });
  if(error) throw error;
  return !!data;
}
async function espMarkPrivateReadRPC(inspecteurId, password, autreId){
  const { data, error } = await supabaseClient.rpc('inspecteur_mark_private_read', { p_inspecteur_id: inspecteurId, p_password: password, p_autre_id: autreId });
  if(error) throw error;
  return !!data;
}
async function espInspecteurRequestCertificationRPC(inspecteurId, password){
  const { data, error } = await supabaseClient.rpc('inspecteur_request_certification', { p_inspecteur_id: inspecteurId, p_password: password });
  if(error) throw error;
  return !!data;
}
async function espInspecteurUpdateAvatarRPC(inspecteurId, password, avatarUrl){
  const { data, error } = await supabaseClient.rpc('inspecteur_update_avatar', { p_inspecteur_id: inspecteurId, p_password: password, p_avatar_url: avatarUrl });
  if(error) throw error;
  return !!data;
}
async function espInspecteurUpdateMessageAccueilRPC(inspecteurId, password, messageAccueil){
  const { data, error } = await supabaseClient.rpc('inspecteur_update_message_accueil', { p_inspecteur_id: inspecteurId, p_password: password, p_message_accueil: messageAccueil });
  if(error) throw error;
  return !!data;
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
async function espAdminDeleteMessageRPC(adminPassword, messageId){
  const { data, error } = await supabaseClient.rpc('admin_delete_message', { p_admin_password: adminPassword, p_message_id: messageId });
  if(error) throw error;
  return !!data;
}
async function espAdminSetInspecteurBanniRPC(adminPassword, inspecteurId, banni){
  const { data, error } = await supabaseClient.rpc('admin_set_inspecteur_banni', { p_admin_password: adminPassword, p_inspecteur_id: inspecteurId, p_banni: banni });
  if(error) throw error;
  return !!data;
}
async function espAdminSetInspecteurCertifieRPC(adminPassword, inspecteurId, certifie){
  const { data, error } = await supabaseClient.rpc('admin_set_inspecteur_certifie', { p_admin_password: adminPassword, p_inspecteur_id: inspecteurId, p_certifie: certifie });
  if(error) throw error;
  return !!data;
}
async function espAdminSetEleveBanniRPC(adminPassword, eleveId, banni){
  const { data, error } = await supabaseClient.rpc('admin_set_eleve_banni', { p_admin_password: adminPassword, p_eleve_id: eleveId, p_banni: banni });
  if(error) throw error;
  return !!data;
}
async function espSetEtabStatutRPC(adminPassword, etabId, statut){
  const { data, error } = await supabaseClient.rpc('admin_set_etab_statut', { p_admin_password: adminPassword, p_etab_id: etabId, p_statut: statut });
  if(error) throw error;
  return !!data;
}
async function espEtabUpdateLocalisationRPC(etabId, password, region, ville, quartier){
  const { data, error } = await supabaseClient.rpc('etablissement_update_localisation', { p_etab_id: etabId, p_password: password, p_region: region, p_ville: ville, p_quartier: quartier });
  if(error) throw error;
  return !!data;
}
async function espSetFiliereStatutRPC(adminPassword, etabId, filiereId, statut){
  const { data, error } = await supabaseClient.rpc('admin_set_filiere_statut', { p_admin_password: adminPassword, p_etab_id: etabId, p_filiere_id: filiereId, p_statut: statut });
  if(error) throw error;
  return !!data;
}
async function espRestoreBackupRPC(adminPassword, payload){
  const { data, error } = await supabaseClient.rpc('admin_restore_backup', { p_admin_password: adminPassword, p_payload: payload });
  if(error) throw error;
  return !!data;
}
async function espUpdateEleveEmailRPC(id, password, email){
  const { data, error } = await supabaseClient.rpc('eleve_update_email', { p_id: id, p_password: password, p_email: email });
  if(error) throw error;
  return !!data;
}
async function espUpdateInspecteurEmailRPC(id, password, email){
  const { data, error } = await supabaseClient.rpc('inspecteur_update_email', { p_id: id, p_password: password, p_email: email });
  if(error) throw error;
  return !!data;
}
async function espRequestPasswordResetRPC(role, email){
  const { data, error } = await supabaseClient.rpc('request_password_reset', { p_role: role, p_email: email });
  if(error) throw error;
  return (data && data[0]) || null;
}
async function espResetPasswordWithTokenRPC(token, newPassword){
  const { data, error } = await supabaseClient.rpc('reset_password_with_token', { p_token: token, p_new_password: newPassword });
  if(error) throw error;
  return !!data;
}
async function espSendResetEmail(toEmail, resetLink){
  if(!window.emailjs){ throw new Error("Le service d'envoi d'e-mail n'est pas disponible."); }
  await window.emailjs.send(EMAILJS_SERVICE_ID, EMAILJS_TEMPLATE_ID, {
    to_email: toEmail,
    reset_link: resetLink,
  });
}

function espUid(){ return 'id' + Date.now().toString(36) + Math.random().toString(36).slice(2,8); }
function espDate(){ return new Date().toLocaleDateString('fr-FR', {day:'2-digit', month:'2-digit', year:'numeric'}); }
