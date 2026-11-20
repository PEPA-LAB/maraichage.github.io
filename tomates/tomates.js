// Catalogue du conservatoire de tomates : lit varietes.csv et photos.csv,
// construit les filtres à partir des valeurs présentes, les cartes et la fiche détail.
(function () {
  "use strict";

  // ---------- lecture CSV (RFC 4180 : guillemets, virgules et retours à la ligne dans les champs)
  function parseCSV(texte) {
    const lignes = []; let ligne = []; let champ = ""; let guill = false;
    for (let i = 0; i < texte.length; i++) {
      const c = texte[i];
      if (guill) {
        if (c === '"') { if (texte[i + 1] === '"') { champ += '"'; i++; } else guill = false; }
        else champ += c;
      } else if (c === '"') guill = true;
      else if (c === ",") { ligne.push(champ); champ = ""; }
      else if (c === "\n" || c === "\r") {
        if (c === "\r" && texte[i + 1] === "\n") i++;
        ligne.push(champ); champ = "";
        if (ligne.some(x => x !== "")) lignes.push(ligne);
        ligne = [];
      } else champ += c;
    }
    if (champ !== "" || ligne.length) { ligne.push(champ); lignes.push(ligne); }
    const entete = lignes.shift();
    return lignes.map(l => Object.fromEntries(entete.map((h, j) => [h.trim(), (l[j] || "").trim()])));
  }

  const esc = s => String(s ?? "").replace(/[&<>"]/g, m => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[m]));
  const majuscule = s => s ? s.charAt(0).toUpperCase() + s.slice(1) : s;
  // Les champs forme et couleur contiennent des listes : « ronde, aplatie », « jaune, rouge »
  const jetons = s => (s || "").split(/[,\/]/).map(x => x.trim().toLowerCase()).filter(Boolean);

  // ---------- filtres : [libellé, colonne, liste ?]
  const FILTRES = [
    ["Type", "type", false], ["Couleur", "couleur", true], ["Forme", "forme", true],
    ["Maturité", "maturite", false], ["Croissance", "croissance", false],
    ["Origine", "origine", false], ["Plein champ", "plein_champs", false]
  ];
  const etat = { q: "", sel: {} };
  FILTRES.forEach(([, col]) => etat.sel[col] = new Set());

  let VARIETES = [], PHOTOS = {};

  const valeurs = (v, col, liste) => {
    const x = v[col] || "";
    if (col === "plein_champs") return [x ? majuscule(x) : "Non renseigné"];
    return liste ? jetons(x) : (x ? [x] : []);
  };

  function correspond(v, sauf) {
    if (etat.q && !v.cultivar.toLowerCase().includes(etat.q)) return false;
    for (const [, col, liste] of FILTRES) {
      if (col === sauf) continue;
      const s = etat.sel[col];
      if (s.size && !valeurs(v, col, liste).some(x => s.has(x))) return false;
    }
    return true;
  }

  // ---------- couleur du dessin de remplacement (pas de photo)
  const TEINTES = [["noire", "#3b1f2b"], ["pourpre", "#5b2333"], ["bordeaux", "#6d1a36"], ["framboise", "#b0284a"],
    ["rose", "#e58fa0"], ["orange", "#e67e22"], ["jaune", "#f1c40f"], ["olive", "#7d8c3a"], ["vert", "#6ab04c"],
    ["blanc", "#f3eac2"], ["rouge", "#c0392b"]];
  function teintes(couleur) {
    const t = jetons(couleur).map(j => (TEINTES.find(([k]) => j.includes(k)) || [, null])[1]).filter(Boolean);
    return t.length ? t : ["#c0392b"];
  }
  function dessin(v) {
    const t = teintes(v.couleur), a = t[0], b = t[1] || t[0];
    const id = "g" + v.id;
    return `<svg viewBox="0 0 100 100" class="tom-dessin" role="img" aria-label="Pas encore de photo">
      <defs><linearGradient id="${id}" x1="0" x2="1"><stop offset="0.5" stop-color="${a}"/><stop offset="0.5" stop-color="${b}"/></linearGradient></defs>
      <ellipse cx="50" cy="56" rx="34" ry="30" fill="url(#${id})"/>
      <path d="M50 28 l-14 -6 l10 10 l-12 2 l14 2 l2 10 l2 -10 l14 -2 l-12 -2 l10 -10z" fill="#3e7d32"/>
      <ellipse cx="38" cy="46" rx="7" ry="4" fill="#fff" opacity=".25"/></svg>`;
  }

  const photosDe = v => PHOTOS[v.id] || [];
  const photoPrincipale = v => {
    const p = photosDe(v);
    return p.find(x => /tomate|fruit/i.test(x.type_photo)) || p[0];
  };

  // ---------- rendu
  function kpis() {
    const n = VARIETES.length;
    const avecPhoto = VARIETES.filter(v => photosDe(v).length).length;
    const m25 = VARIETES.filter(v => v.multiplication_2025 === "oui").length;
    const m26 = VARIETES.filter(v => v.multiplication_2026 === "oui").length;
    document.getElementById("tom-kpis").innerHTML = [
      [n, "variétés"], [avecPhoto, "avec photos"], [m25, "multipliées en 2025"], [m26, "multipliées en 2026"]
    ].map(([x, l]) => `<div class="tom-kpi"><b>${x}</b><span>${l}</span></div>`).join("");
  }

  function groupes() {
    const html = FILTRES.map(([lib, col, liste], i) => {
      const compte = {};
      VARIETES.filter(v => correspond(v, col)).forEach(v => valeurs(v, col, liste).forEach(x => compte[x] = (compte[x] || 0) + 1));
      etat.sel[col].forEach(x => { if (!(x in compte)) compte[x] = 0; });
      const vals = Object.keys(compte).sort((a, b) => a.localeCompare(b, "fr"));
      const ouvert = i < 2 || etat.sel[col].size ? " open" : "";
      return `<details class="tom-groupe"${ouvert}><summary class="tom-filtre-titre">${lib}${etat.sel[col].size ? ` <span class="tom-nsel">${etat.sel[col].size}</span>` : ""}</summary>
        <div class="tom-chips">${vals.map(x => `<button type="button" class="tom-chip" data-col="${col}" data-v="${esc(x)}" aria-pressed="${etat.sel[col].has(x)}"${compte[x] === 0 && !etat.sel[col].has(x) ? " disabled" : ""}>${esc(majuscule(x))} <span>${compte[x]}</span></button>`).join("")}</div></details>`;
    }).join("");
    const conteneur = document.getElementById("tom-groupes");
    const ouverts = [...conteneur.querySelectorAll("details")].map(d => d.open);
    conteneur.innerHTML = html;
    if (ouverts.length) conteneur.querySelectorAll("details").forEach((d, i) => d.open = ouverts[i] || d.open);
    conteneur.querySelectorAll(".tom-chip").forEach(b => b.addEventListener("click", () => {
      const s = etat.sel[b.dataset.col], v = b.dataset.v;
      s.has(v) ? s.delete(v) : s.add(v);
      rendre();
    }));
  }

  function carte(v) {
    const p = photoPrincipale(v);
    const visuel = p ? `<img src="${esc(p.fichier)}" alt="${esc(v.cultivar)}" loading="lazy">` : dessin(v);
    const badges = [v.maturite, v.croissance, jetons(v.forme)[0]].filter(Boolean)
      .map(b => `<span class="pill th">${esc(majuscule(b))}</span>`).join("");
    const sous = [v.type, v.couleur].filter(Boolean).map(majuscule).join(" · ");
    return `<button type="button" class="tom-carte" data-id="${v.id}">
      <div class="tom-visuel${p ? "" : " sans-photo"}">${visuel}</div>
      <div class="fiche-body"><h3>${esc(v.cultivar)}</h3><div class="fiche-meta">${esc(sous)}</div>
      <div class="fiche-pills">${badges}</div><span class="tom-voir">Voir la fiche</span></div></button>`;
  }

  function rendre() {
    const liste = VARIETES.filter(v => correspond(v)).sort((a, b) => a.cultivar.localeCompare(b.cultivar, "fr"));
    document.getElementById("tom-grille").innerHTML = liste.length ? liste.map(carte).join("")
      : `<p class="tom-vide">Aucune variété ne correspond. Cliquez sur « Tout afficher ».</p>`;
    document.getElementById("tom-compte").textContent = `${liste.length} variété${liste.length > 1 ? "s" : ""} sur ${VARIETES.length}`;
    document.querySelectorAll(".tom-carte").forEach(b => b.addEventListener("click", () => { location.hash = "v" + b.dataset.id; }));
    groupes();
  }

  // ---------- fiche détail
  const ligne = (lib, val) => val ? `<tr><th>${lib}</th><td>${esc(majuscule(val))}</td></tr>` : "";
  const oui = (lib, val) => `<span class="tom-badge ${val === "oui" ? "ok" : "non"}">${val === "oui" ? "✓" : "✗"} ${lib}</span>`;

  function fiche(id) {
    const v = VARIETES.find(x => String(x.id) === String(id));
    if (!v) return;
    const ph = photosDe(v), p = photoPrincipale(v);
    const autres = ph.filter(x => x !== p);
    const visuel = p ? `<img class="tom-grande" src="${esc(p.fichier)}" alt="${esc(v.cultivar)}">` : `<div class="tom-grande sans-photo">${dessin(v)}<p>Pas encore de photo</p></div>`;
    const galerie = autres.length ? `<div class="tom-galerie">${autres.map(x =>
      `<figure><img src="${esc(x.fichier)}" alt="${esc(x.legende || x.type_photo || v.cultivar)}" loading="lazy"><figcaption>${esc(majuscule(x.legende || x.type_photo))}</figcaption></figure>`).join("")}</div>` : "";
    const pc = v.plein_champs ? `<span class="tom-badge ${v.plein_champs === "oui" ? "ok" : "non"}">Plein champ : ${esc(v.plein_champs)}</span>` : "";
    document.getElementById("tom-modal-titre").textContent = v.cultivar;
    document.getElementById("tom-modal-corps").innerHTML = `
      <div class="tom-fiche">
        <div>${visuel}${galerie}</div>
        <div>
          <div class="tom-badges">${oui("Multipliée en 2025", v.multiplication_2025)} ${oui("Multipliée en 2026", v.multiplication_2026)} ${pc}</div>
          <h3>Descripteurs</h3><table class="table table-sm">
            ${ligne("Type", v.type)}${ligne("Forme", v.forme)}${ligne("Couleur", v.couleur)}${ligne("Calibre", v.calibre ? v.calibre.replace(".", ",") : "")}
            ${ligne("Maturité", v.maturite)}${ligne("Croissance", v.croissance)}</table>
          <h3>Culture</h3><table class="table table-sm">
            ${ligne("Rendement", v.rendement)}${ligne("Sensibilité aux maladies", v.sensibilite)}${ligne("Origine", v.origine)}${ligne("Graines obtenues en", v.date_graines)}</table>
          ${v.bouche || v.utilisation ? `<h3>Dégustation</h3><table class="table table-sm">${ligne("En bouche", v.bouche)}${ligne("Utilisation", v.utilisation)}</table>` : ""}
          ${v.remarque ? `<h3>Remarques</h3><p>${esc(v.remarque)}</p>` : ""}
        </div>
      </div>`;
    bootstrap.Modal.getOrCreateInstance(document.getElementById("tom-modal")).show();
  }

  function routeur() {
    const m = location.hash.match(/^#v(\d+)$/);
    if (m) fiche(m[1]);
  }

  // ---------- démarrage
  // La fenêtre de détail doit être un enfant direct de <body>, sinon le fond grisé passe au-dessus
  document.body.appendChild(document.getElementById("tom-modal"));

  Promise.all([fetch("varietes.csv").then(r => r.text()), fetch("photos.csv").then(r => r.text())])
    .then(([tv, tp]) => {
      VARIETES = parseCSV(tv).filter(v => v.cultivar);
      parseCSV(tp).forEach(p => (PHOTOS[p.variete_id] = PHOTOS[p.variete_id] || []).push(p));
      kpis(); rendre(); routeur();
    })
    .catch(() => { document.getElementById("tom-grille").innerHTML = `<p class="tom-vide">Impossible de charger le catalogue.</p>`; });

  document.getElementById("tom-recherche").addEventListener("input", e => { etat.q = e.target.value.trim().toLowerCase(); rendre(); });
  document.getElementById("tom-reset").addEventListener("click", () => {
    etat.q = ""; document.getElementById("tom-recherche").value = "";
    Object.values(etat.sel).forEach(s => s.clear()); rendre();
  });
  window.addEventListener("hashchange", routeur);
  document.getElementById("tom-modal").addEventListener("hidden.bs.modal", () => {
    if (location.hash) history.replaceState(null, "", location.pathname + location.search);
  });
})();
