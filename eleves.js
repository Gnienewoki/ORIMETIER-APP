// ---------------- Élèves inscrits (page eleves.html, réservée aux inspecteurs) ----------------
let _elevesViewingProfile = false;

function initEleves(){
  const session = espSession();
  if(!session || session.role !== 'inspecteur'){
    document.getElementById('page-content').innerHTML = `
      <div class="esp-card" style="max-width:520px;margin:40px auto;text-align:center;">
        <div class="esp-title">🔒 Accès réservé aux inspecteurs</div>
        <p class="esp-sub">Cette page est réservée aux inspecteurs d'orientation connectés.</p>
        <a class="esp-btn esp-btn-primary" href="espaces.html">Aller à mon espace</a>
      </div>
    `;
    return;
  }
  _elevesViewingProfile = false;
  renderElevesListe();
}

function renderElevesListe(){
  _elevesViewingProfile = false;
  const db = espDB();
  document.getElementById('page-content').innerHTML = `
    <div class="esp-user-header">
      <span class="esp-user-name">👥 Élèves inscrits sur la plateforme</span>
      <a class="esp-btn" href="espaces.html">← Mon espace</a>
    </div>
    <div class="esp-card">
      <p class="esp-sub">Retrouvez ici les élèves ayant créé un compte et consultez leur profil d'orientation RIASEC pour les accompagner.</p>
      <table class="esp-table">
        <thead><tr><th>Nom</th><th>Classe</th><th>Établissement</th><th>Test RIASEC</th><th></th></tr></thead>
        <tbody>
        ${db.eleves.length ? db.eleves.map(e => `
          <tr>
            <td><b>${escapeHtml(e.nom)} ${escapeHtml(e.prenoms||'')}</b></td>
            <td>${escapeHtml(e.classe)}</td>
            <td>${escapeHtml(e.etablissement)}</td>
            <td>${e.riasec ? `<span class="esp-badge valide">${e.riasec.hollandCode}</span>` : `<span class="esp-badge en_attente">Non passé</span>`}</td>
            <td><button class="esp-btn" style="padding:5px 12px;font-size:12px;" onclick="espInspecteurViewEleve('${e.id}')">Voir le profil</button></td>
          </tr>
        `).join('') : `<tr><td colspan="5" class="esp-empty">Aucun élève inscrit pour le moment.</td></tr>`}
        </tbody>
      </table>
    </div>
  `;
}

function espInspecteurViewEleve(eleveId){
  _elevesViewingProfile = true;
  const session = espSession();
  const db = espDB();
  const eleve = db.eleves.find(e => e.id === eleveId);
  const insp = db.inspecteurs.find(i => i.id === session.id);
  if(!eleve) return;

  const notes = db.notes.filter(n => n.eleveId === eleveId);
  const r = eleve.riasec;

  document.getElementById('page-content').innerHTML = `
    <div class="esp-user-header">
      <span class="esp-user-name">🧭 ${escapeHtml(insp.nom)} — Profil élève</span>
      <button class="esp-btn" onclick="renderElevesListe()">← Retour à la liste</button>
    </div>
    <div class="esp-card">
      <div class="esp-title" style="font-size:16px;">${escapeHtml(eleve.nom)} ${escapeHtml(eleve.prenoms||'')}</div>
      <p class="esp-sub">${escapeHtml(eleve.classe)} · ${escapeHtml(eleve.etablissement)} · ${escapeHtml(eleve.tel)} · Inscrit(e) le ${escapeHtml(eleve.dateInscription)}</p>

      ${r ? `
        <div class="riasec-code-wrap" style="margin:14px 0;">
          <div class="riasec-code-letters">${r.top3.map(l => `<div class="riasec-code-letter" style="background:${RIASEC_COLORS[l]}">${l}</div>`).join('')}</div>
          <p class="riasec-code-names">${r.top3.map(l => RIASEC_DIMENSIONS.find(d=>d.letter===l).name).join(' · ')} — Code ${r.hollandCode} (réalisé le ${new Date(r.date).toLocaleDateString('fr-FR')})</p>
        </div>
        <div style="margin:10px 0 16px;">${r.scored.map(s => `
          <div class="riasec-bar-row">
            <span class="riasec-bar-label">${s.letter} — ${s.name}</span>
            <span class="riasec-bar-track"><span class="riasec-bar-fill" style="width:${s.pct}%;background:${RIASEC_COLORS[s.letter]}"></span></span>
            <span class="riasec-bar-pct">${s.pct}%</span>
          </div>
        `).join('')}</div>
      ` : `<p class="esp-empty">Cet élève n'a pas encore réalisé (ou sauvegardé) son test d'orientation RIASEC.</p>`}

      <div class="esp-title" style="font-size:15px;margin-top:20px;">Notes et recommandations</div>
      ${notes.length ? notes.map(n => `
        <div class="esp-note-item">${escapeHtml(n.texte)}<small>${escapeHtml(n.inspecteurNom)} — ${escapeHtml(n.date)}</small></div>
      `).join('') : `<p class="esp-empty">Aucune note pour le moment.</p>`}

      <div class="esp-field" style="margin-top:12px;">
        <label>Ajouter une note / recommandation</label>
        <textarea id="esp-insp-note-text" placeholder="Ex : orienter vers la filière Électrotechnique compte tenu du profil Réaliste dominant..."></textarea>
      </div>
      <button class="esp-btn esp-btn-primary" onclick="espInspecteurAddNote('${eleveId}')">Ajouter la note</button>
    </div>
  `;
}
async function espInspecteurAddNote(eleveId){
  const session = espSession();
  const db = espDB();
  const insp = db.inspecteurs.find(i => i.id === session.id);
  const texte = document.getElementById('esp-insp-note-text').value.trim();
  if(!texte) return;
  let ok;
  try {
    ok = await espAddNoteRPC(insp.id, session.password, eleveId, texte);
  } catch(e){
    alert("Erreur lors de l'ajout de la note : " + e.message);
    return;
  }
  if(!ok){ alert("Session expirée, merci de te reconnecter."); platformLogout(); return; }
  db.notes.push({ id:espUid(), eleveId, inspecteurId:insp.id, inspecteurNom: insp.nom + ' ' + (insp.prenoms||''), texte, date:espDate() });
  espSaveDB(db);
  espInspecteurViewEleve(eleveId);
}

window.pageInit = initEleves;
window.pageRefresh = function(){
  const session = espSession();
  if(session && session.role === 'inspecteur' && !_elevesViewingProfile) renderElevesListe();
};
