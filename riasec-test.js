let ptCurrentScreen = 0;
const ptAnswers = {};
RIASEC_DIMENSIONS.forEach(d => { ptAnswers[d.letter] = new Set(); });

function ptBuildQuizScreens(){
  const container = document.getElementById('pt-quiz-container');
  RIASEC_DIMENSIONS.forEach((dim, idx) => {
    const div = document.createElement('div');
    div.className = 'pt-screen pt-hidden';
    div.id = 'pt-screen-q' + idx;
    div.innerHTML = `
      <div class="pt-card">
        <h2 class="pt-section-title">${idx+1}. ${dim.name} (${dim.letter})</h2>
        <p class="pt-section-sub">${dim.sub}</p>
        <div class="pt-single-list">
          ${dim.items.map((t,i)=>`
            <label class="pt-item">
              <input type="checkbox" data-letter="${dim.letter}" data-idx="${i}">
              <span>${t}</span>
            </label>`).join('')}
        </div>
        <div class="pt-nav-row">
          <button class="pt-btn" onclick="ptGoTo(${idx})">← Précédent</button>
          <span class="pt-bearing">Dimension ${idx+1} / ${RIASEC_DIMENSIONS.length}</span>
          <button class="pt-btn pt-primary" onclick="ptGoTo(${idx+2})">${idx===RIASEC_DIMENSIONS.length-1 ? 'Voir mon profil →' : 'Suivant →'}</button>
        </div>
      </div>
    `;
    container.appendChild(div);
  });

  container.querySelectorAll('input[type=checkbox]').forEach(cb => {
    cb.addEventListener('change', (e) => {
      const {letter, idx} = e.target.dataset;
      const set = ptAnswers[letter];
      if(e.target.checked) set.add(idx); else set.delete(idx);
    });
  });
}

function ptGoTo(screenIndex){
  document.querySelectorAll('.pt-screen').forEach(s => s.classList.add('pt-hidden'));
  ptCurrentScreen = screenIndex;

  if(screenIndex === 0){
    document.getElementById('pt-screen-intro').classList.remove('pt-hidden');
    ptSetNeedle(0);
    return;
  }
  if(screenIndex >= 1 && screenIndex <= RIASEC_DIMENSIONS.length){
    const idx = screenIndex - 1;
    document.getElementById('pt-screen-q'+idx).classList.remove('pt-hidden');
    ptSetNeedle(RIASEC_DIMENSIONS[idx].bearing);
    return;
  }
  ptRenderResults();
  document.getElementById('pt-screen-results').classList.remove('pt-hidden');
}

function ptSetNeedle(deg){
  const needle = document.getElementById('pt-needle');
  if(needle) needle.style.transform = `rotate(${deg}deg)`;
}

function ptRenderResults(){
  const scored = RIASEC_DIMENSIONS.map(dim => ({
    letter: dim.letter,
    name: dim.name,
    score: ptAnswers[dim.letter].size,
    pct: ptAnswers[dim.letter].size * 10
  })).sort((a,b) => b.score - a.score);

  const top3 = scored.slice(0,3);
  const hollandCode = top3.map(s => s.letter).join('');
  window.__lastRiasecResult = { scored, top3: top3.map(s => s.letter), hollandCode, date: new Date().toISOString() };

  ptSetNeedle(RIASEC_DIMENSIONS.find(d => d.letter === top3[0].letter).bearing);

  const nom = document.getElementById('pt-f-nom').value.trim();
  const classe = document.getElementById('pt-f-classe').value.trim();
  const etab = document.getElementById('pt-f-etab').value.trim();
  const age = document.getElementById('pt-f-age').value.trim();
  const tel = document.getElementById('pt-f-tel').value.trim();
  const lieu = document.getElementById('pt-f-lieu').value.trim();

  const rankLabels = ['Dimension dominante', 'Dimension secondaire', 'Dimension tertiaire'];

  function rankCard(rank, s){
    const info = RIASEC_INFO[s.letter];
    const color = RIASEC_COLORS[s.letter];
    return `
      <div class="pt-card riasec-rank-card" style="border-color:${color}">
        <div class="riasec-rank-head">
          <span class="riasec-rank-num" style="background:${color}">${rank+1}</span>
          <div>
            <div class="riasec-rank-title">${s.letter} — ${s.name}</div>
          </div>
        </div>
        <p class="riasec-rank-sub">${rankLabels[rank]} · ${info.epithete} · Score : ${s.score}/10</p>
        <p class="riasec-rank-desc">${info.description}</p>
        <div class="riasec-rank-grid">
          <div>
            <h5>Vos qualités</h5>
            <ul>${info.qualites.map(q=>`<li>${q}</li>`).join('')}</ul>
          </div>
          <div>
            <h5>Environnement de travail</h5>
            <ul><li>${info.environnement}</li></ul>
          </div>
        </div>
        <div class="riasec-chips">${info.filieres.map(f=>`<span class="riasec-chip">${f}</span>`).join('')}</div>
        <p class="riasec-rank-sub" style="margin-top:2px">Exemples de métiers : ${info.metiers.join(', ')}.</p>
      </div>
    `;
  }

  const barsHtml = scored.map(s => `
    <div class="riasec-bar-row">
      <span class="riasec-bar-label">${s.letter} — ${s.name}</span>
      <span class="riasec-bar-track"><span class="riasec-bar-fill" style="width:${s.pct}%;background:${RIASEC_COLORS[s.letter]}"></span></span>
      <span class="riasec-bar-pct">${s.pct}%</span>
    </div>
  `).join('');

  const html = `
    <div class="pt-card pt-result-header">
      <p class="pt-eyebrow">Votre code RIASEC ${nom ? '— '+nom : ''}</p>
      <div class="riasec-code-wrap">
        <div class="riasec-code-letters">
          ${top3.map(s => `<div class="riasec-code-letter" style="background:${RIASEC_COLORS[s.letter]}">${s.letter}</div>`).join('')}
        </div>
        <p class="riasec-code-names">${top3.map(s=>s.name).join(' · ')}</p>
      </div>
      ${(classe||etab) ? `<p class="pt-score-line" style="text-align:center">${classe}${classe&&etab?' · ':''}${etab}</p>` : ''}
      ${(age||lieu||tel) ? `<p class="pt-score-line" style="text-align:center">${[age?('Âge : '+age+' ans'):'', lieu, tel].filter(Boolean).join(' · ')}</p>` : ''}
      <p class="riasec-intro-note">Le modèle RIASEC, élaboré par le psychologue John L. Holland, part d'une idée simple : nos intérêts professionnels s'organisent autour de six grandes orientations qui, ensemble, dessinent une sorte d'empreinte digitale de notre personnalité au travail. Votre code <strong>${hollandCode}</strong> représente vos trois orientations les plus marquées, classées par ordre d'intensité. Ce n'est pas une étiquette figée mais une boussole : elle indique une direction, pas une destination unique, et elle gagne toujours à être confrontée à vos propres expériences et aux conseils d'un professionnel de l'orientation.</p>
    </div>

    <div class="pt-card" style="border-left:4px solid var(--orange-dark); background:var(--bg);">
      <p style="margin:0 0 8px; font-weight:800; color:var(--green-dark); font-size:14.5px;">🧭 Et maintenant ?</p>
      <p style="margin:0; font-size:13.5px; line-height:1.65; color:var(--text);">
        Ce test donne une première piste, mais un code RIASEC seul ne suffit pas à décider d'une orientation :
        <strong>seul un inspecteur d'orientation peut t'aider à l'interpréter en profondeur</strong> et le relier à ta réalité
        (tes notes, tes contraintes, les filières réellement accessibles près de chez toi...).
        Nous t'encourageons vivement à prendre rendez-vous avec un inspecteur <strong>certifié</strong>
        <span class="esp-badge-certifie" title="Compte certifié par l'administration">✅</span> de la plateforme pour en discuter,
        plutôt que de t'arrêter à ce résultat seul.
      </p>
    </div>

    ${top3.map((s,i) => rankCard(i, s)).join('')}

    <div class="pt-card">
      <div class="pt-section-head"><span class="pt-num">4</span><h2 class="pt-section-title" style="margin:0">Votre profil complet sur les 6 dimensions</h2></div>
      <p class="pt-section-sub" style="margin-left:38px;margin-top:0">Plus une dimension est développée, plus elle influence votre motivation au travail.</p>
      <div style="margin-top:10px">${barsHtml}</div>
      <p class="pt-learning-note">Deux dimensions voisines sur l'hexagone de Holland (par exemple Réaliste et Investigateur, ou Social et Entreprenant) se combinent souvent naturellement dans un même métier. À l'inverse, des dimensions opposées (Réaliste ↔ Social, Investigateur ↔ Entreprenant, Artistique ↔ Conventionnel) demandent généralement des tempéraments plus contrastés — un score élevé sur les deux à la fois signale une personnalité riche et polyvalente, capable de s'épanouir dans des contextes très différents.</p>
    </div>

    <div class="pt-nav-row" style="margin-top:0">
      <button class="pt-btn" onclick="ptGoTo(${RIASEC_DIMENSIONS.length})">← Revoir mes réponses</button>
      <button class="pt-btn" onclick="ptSaveToEleveSpace()">💾 Sauvegarder dans mon espace élève</button>
      <button class="pt-btn pt-primary" id="pt-download-btn" onclick="ptDownloadResults()">⬇ Télécharger mon profil (PDF)</button>
      <button class="pt-btn" onclick="ptRestart()">Recommencer le test</button>
    </div>
  `;
  document.getElementById('pt-screen-results').innerHTML = html;
}

async function ptSaveToEleveSpace(){
  if(typeof espSession !== 'function'){ alert("La fonctionnalité Espaces n'est pas disponible."); return; }
  const session = espSession();
  if(!session || session.role !== 'eleve'){
    alert("Connectez-vous d'abord à votre espace élève (onglet 🔐 Espaces) pour pouvoir sauvegarder ce profil.");
    window.location.href = 'espaces.html?role=eleve';
    return;
  }
  if(!window.__lastRiasecResult){ alert("Aucun résultat à sauvegarder."); return; }
  const db = espDB();
  const eleve = db.eleves.find(e => e.id === session.id);
  if(!eleve){ alert("Compte élève introuvable."); return; }
  let ok;
  try {
    ok = await espSaveRiasecRPC(session.id, session.password, window.__lastRiasecResult);
  } catch(e){
    alert("Erreur lors de la sauvegarde : " + e.message);
    return;
  }
  if(!ok){ alert("Session expirée, merci de te reconnecter."); platformLogout(); return; }
  eleve.riasec = window.__lastRiasecResult;
  espSaveDB(db);
  alert('Votre profil RIASEC (code ' + window.__lastRiasecResult.hollandCode + ') a été sauvegardé dans votre espace élève !');
}

function ptDownloadResults(){
  const el = document.getElementById('pt-screen-results');
  const btn = document.getElementById('pt-download-btn');
  const navRow = btn.closest('.pt-nav-row');
  const originalLabel = btn.textContent;

  if(typeof html2canvas === 'undefined' || !window.jspdf){
    alert("Le générateur de PDF n'a pas pu se charger (connexion internet requise). Réessayez, ou utilisez l'impression du navigateur (Ctrl+P) pour enregistrer en PDF.");
    return;
  }

  btn.textContent = 'Génération en cours…';
  btn.disabled = true;
  navRow.style.display = 'none'; // ne pas inclure les boutons dans le PDF

  html2canvas(el, {scale:2, backgroundColor:'#fffaf3', useCORS:true}).then(canvas => {
    navRow.style.display = '';
    const imgData = canvas.toDataURL('image/png');
    const { jsPDF } = window.jspdf;
    const pdf = new jsPDF('p', 'mm', 'a4');
    const pageWidth = pdf.internal.pageSize.getWidth();
    const pageHeight = pdf.internal.pageSize.getHeight();
    const imgWidth = pageWidth;
    const imgHeight = canvas.height * imgWidth / canvas.width;

    let heightLeft = imgHeight;
    let position = 0;

    pdf.addImage(imgData, 'PNG', 0, position, imgWidth, imgHeight);
    heightLeft -= pageHeight;

    while(heightLeft > 0){
      position = heightLeft - imgHeight;
      pdf.addPage();
      pdf.addImage(imgData, 'PNG', 0, position, imgWidth, imgHeight);
      heightLeft -= pageHeight;
    }

    const nomFichier = (document.getElementById('pt-f-nom').value.trim() || 'profil')
      .replace(/[^a-zA-Z0-9]+/g, '_');
    pdf.save(`Profil-orientation-${nomFichier}.pdf`);

    btn.textContent = originalLabel;
    btn.disabled = false;
  }).catch(err => {
    navRow.style.display = '';
    btn.textContent = originalLabel;
    btn.disabled = false;
    alert("Une erreur est survenue lors de la génération du PDF. Vérifiez votre connexion internet et réessayez.");
    console.error(err);
  });
}

function ptRestart(){
  RIASEC_DIMENSIONS.forEach(d => { ptAnswers[d.letter] = new Set(); });
  document.querySelectorAll('input[type=checkbox]').forEach(cb => cb.checked = false);
  ptGoTo(0);
}

function initRiasecTest(){
  ptBuildQuizScreens();
  ptGoTo(0);
}
window.pageInit = initRiasecTest;
