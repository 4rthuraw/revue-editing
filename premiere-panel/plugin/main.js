const ppro = require("premierepro");
const uxp = require("uxp");
const { storage } = uxp;

// Langue du panneau : celle de l'interface de Premiere (français ou anglais).
function detectLanguage() {
  let locale = "";
  try { locale = uxp.host.uiLocale || ""; } catch (e) { /* hôte sans uiLocale */ }
  if (!locale && typeof navigator !== "undefined") locale = navigator.language || "";
  return String(locale).toLowerCase().startsWith("fr") ? "fr" : "en";
}

const STRINGS = {
  fr: {
    title: "Importer les notes de revue",
    hint: "Fichier « … marqueurs Premiere.json » exporté par Revue Montage.",
    choose: "Choisir un fichier de notes…",
    import: "Ajouter à la séquence active",
    notAnExport: "Ce fichier n'est pas un export « Premiere » de Revue Montage.",
    noMarkers: "Ce fichier ne contient aucun marqueur.",
    invalidMarker: "Marqueur invalide dans le fichier.",
    noProject: "Aucun projet ouvert dans Premiere Pro.",
    noSequence: "Aucune séquence active : ouvre la séquence concernée dans la timeline.",
    rateMismatch: (fileFps, name, seqFps) => `Attention : l'export est en ${fileFps} im/s mais la séquence « ${name} » est en ${seqFps} im/s. Les marqueurs risquent d'être décalés.`,
    allPresent: "Tous ces marqueurs sont déjà dans la séquence.",
    someDuplicates: (n) => `${n} marqueur(s) déjà présent(s) seront ignorés.`,
    activeSequence: (name) => `Séquence active : ${name}`,
    summary: (n, file) => `${n} note(s) · ${file}`,
    nothingToAdd: "Rien à ajouter : tous ces marqueurs sont déjà dans la séquence.",
    refused: "Premiere a refusé la création des marqueurs.",
    undoMarkers: "Importer les notes de revue",
    undoColors: "Couleurs des notes de revue",
    added: (n, name) => `✓ ${n} marqueur(s) ajouté(s) à « ${name} ».`,
    skipped: (n) => ` ${n} déjà présent(s) ignoré(s).`,
    howToUndo: " Pour annuler : ⌘Z (deux fois : couleurs puis marqueurs).",
    colorError: (msg) => `\nLes couleurs n'ont pas pu être appliquées : ${msg}`,
  },
  en: {
    title: "Import review notes",
    hint: "“… Premiere markers.json” file exported by Revue Montage.",
    choose: "Choose a notes file…",
    import: "Add to active sequence",
    notAnExport: "This file is not a Revue Montage “Premiere” export.",
    noMarkers: "This file has no markers.",
    invalidMarker: "Invalid marker in the file.",
    noProject: "No project is open in Premiere Pro.",
    noSequence: "No active sequence: open the matching sequence in the timeline.",
    rateMismatch: (fileFps, name, seqFps) => `Warning: the export is ${fileFps} fps but the sequence “${name}” is ${seqFps} fps. Markers may be offset.`,
    allPresent: "All these markers are already in the sequence.",
    someDuplicates: (n) => `${n} marker(s) already present will be skipped.`,
    activeSequence: (name) => `Active sequence: ${name}`,
    summary: (n, file) => `${n} note(s) · ${file}`,
    nothingToAdd: "Nothing to add: all these markers are already in the sequence.",
    refused: "Premiere refused to create the markers.",
    undoMarkers: "Import review notes",
    undoColors: "Review note colors",
    added: (n, name) => `✓ ${n} marker(s) added to “${name}”.`,
    skipped: (n) => ` ${n} already present, skipped.`,
    howToUndo: " To undo: ⌘Z (twice: colors, then markers).",
    colorError: (msg) => `\nColors could not be applied: ${msg}`,
  },
};
const LANG = detectLanguage();
const T = STRINGS[LANG];

const FORMAT_ID = "revue-montage-premiere";
const SWATCH = { red: "#ff5d5d", green: "#6ee7a0", blue: "#4d8dff", cyan: "#5ec2ff", yellow: "#ffc94d", purple: "#b07cff" };
// Index de secours si ppro.Constants.MarkerColor n'expose pas le nom attendu.
const FALLBACK_INDEX = { green: 0, red: 1, purple: 2, yellow: 4, blue: 6, cyan: 7 };

let loaded = null; // { file, name }

const $ = (id) => document.getElementById(id);

function setStatus(kind, message) {
  const el = $("status");
  el.className = kind || "";
  el.textContent = message || "";
}

function escapeHTML(text) {
  return String(text).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
}

function colorIndexFor(marker) {
  const constants = ppro.Constants && ppro.Constants.MarkerColor;
  const key = String(marker.color || "").toUpperCase();
  if (constants) {
    if (constants[key] !== undefined) return constants[key];
    if (key === "PURPLE" && constants.MAGENTA !== undefined) return constants.MAGENTA;
    if (key === "PURPLE" && constants.VIOLET !== undefined) return constants.VIOLET;
  }
  if (FALLBACK_INDEX[marker.color] !== undefined) return FALLBACK_INDEX[marker.color];
  return marker.colorIndex;
}

function validate(data) {
  if (!data || data.format !== FORMAT_ID || !Array.isArray(data.markers)) {
    throw new Error(T.notAnExport);
  }
  if (data.markers.length === 0) throw new Error(T.noMarkers);
  for (const m of data.markers) {
    if (typeof m.ticks !== "string" || !/^\d+$/.test(m.ticks)) throw new Error(T.invalidMarker);
  }
  return data;
}

async function chooseFile() {
  try {
    const file = await storage.localFileSystem.getFileForOpening({ types: ["json"] });
    if (!file) return;
    const text = await file.read();
    const data = validate(JSON.parse(text));
    loaded = { file: data, name: file.name };
    await render();
  } catch (err) {
    loaded = null;
    $("import").disabled = true;
    $("summary").style.display = "none";
    $("list").innerHTML = "";
    setStatus("error", err.message || String(err));
  }
}

async function getContext() {
  const project = await ppro.Project.getActiveProject();
  if (!project) return { error: T.noProject };
  const sequence = await project.getActiveSequence();
  if (!sequence) return { error: T.noSequence };
  return { project, sequence };
}

async function existingKeys(sequence) {
  const owner = await ppro.Markers.getMarkers(sequence);
  const keys = new Set();
  for (const marker of owner.getMarkers()) {
    keys.add(`${marker.getStart().ticks}|${marker.getComments()}`);
  }
  return { owner, keys };
}

async function render() {
  if (!loaded) return;
  const data = loaded.file;
  const ctx = await getContext();
  let duplicates = new Set();
  const warnings = [];

  if (ctx.error) {
    setStatus("warn", ctx.error);
  } else {
    const { keys } = await existingKeys(ctx.sequence);
    data.markers.forEach((m, i) => { if (keys.has(`${m.ticks}|${m.comments}`)) duplicates.add(i); });
    const timebase = await ctx.sequence.getTimebase();
    if (data.ticksPerFrame && String(timebase) !== String(data.ticksPerFrame)) {
      const seqFps = (254016000000 / Number(timebase)).toFixed(3).replace(/\.?0+$/, "");
      const fileFps = (254016000000 / Number(data.ticksPerFrame)).toFixed(3).replace(/\.?0+$/, "");
      warnings.push(T.rateMismatch(fileFps, ctx.sequence.name, seqFps));
    }
    if (duplicates.size === data.markers.length) {
      warnings.push(T.allPresent);
    } else if (duplicates.size > 0) {
      warnings.push(T.someDuplicates(duplicates.size));
    }
    if (warnings.length) setStatus("warn", warnings.join("\n")); else setStatus("info", T.activeSequence(ctx.sequence.name));
  }

  const summary = $("summary");
  summary.style.display = "block";
  summary.innerHTML = `<div><b>${escapeHTML(data.reviewName)}</b></div>
    <div class="muted">${escapeHTML(T.summary(data.markers.length, loaded.name))}</div>`;

  $("list").innerHTML = data.markers.map((m, i) => `
    <div class="marker ${duplicates.has(i) ? "dup" : ""}">
      <div class="dot" style="background:${SWATCH[m.color] || "#888"}"></div>
      <div>
        <div><span class="tc">${escapeHTML(m.timecode)}</span><span class="name">${escapeHTML(m.name)}</span></div>
        <div class="text">${escapeHTML(m.comments)}</div>
      </div>
    </div>`).join("");

  $("import").disabled = !!ctx.error || duplicates.size === data.markers.length;
}

async function importMarkers() {
  if (!loaded) return;
  $("import").disabled = true;
  try {
    const ctx = await getContext();
    if (ctx.error) throw new Error(ctx.error);
    const { project, sequence } = ctx;
    const { owner, keys } = await existingKeys(sequence);
    const toAdd = loaded.file.markers.filter((m) => !keys.has(`${m.ticks}|${m.comments}`));
    if (toAdd.length === 0) {
      setStatus("warn", T.nothingToAdd);
      return;
    }

    // 1) Création de tous les marqueurs en une seule opération annulable.
    let added = false;
    project.lockedAccess(() => {
      added = project.executeTransaction((compound) => {
        for (const m of toAdd) {
          const start = ppro.TickTime.createWithTicks(m.ticks);
          compound.addAction(owner.createAddMarkerAction(m.name, ppro.Marker.MARKER_TYPE_COMMENT, start, ppro.TickTime.TIME_ZERO, m.comments));
        }
      }, T.undoMarkers);
    });
    if (!added) throw new Error(T.refused);

    // 2) Couleurs : les marqueurs doivent exister pour pouvoir être colorés.
    let colorError = null;
    try {
      const fresh = await ppro.Markers.getMarkers(sequence);
      const byKey = new Map();
      for (const marker of fresh.getMarkers()) byKey.set(`${marker.getStart().ticks}|${marker.getComments()}`, marker);
      project.lockedAccess(() => {
        project.executeTransaction((compound) => {
          for (const m of toAdd) {
            const marker = byKey.get(`${m.ticks}|${m.comments}`);
            if (marker) compound.addAction(marker.createSetColorByIndexAction(colorIndexFor(m)));
          }
        }, T.undoColors);
      });
    } catch (err) {
      colorError = err;
    }

    const skipped = loaded.file.markers.length - toAdd.length;
    let message = T.added(toAdd.length, sequence.name);
    if (skipped) message += T.skipped(skipped);
    message += T.howToUndo;
    if (colorError) message += T.colorError(colorError.message || colorError);
    setStatus(colorError ? "warn" : "ok", message);
    await render();
    setStatus(colorError ? "warn" : "ok", message);
  } catch (err) {
    setStatus("error", err.message || String(err));
    $("import").disabled = false;
  }
}

// Textes statiques du panneau.
document.documentElement.lang = LANG;
$("title").textContent = T.title;
$("hint").textContent = T.hint;
$("choose").textContent = T.choose;
$("import").textContent = T.import;

$("choose").addEventListener("click", chooseFile);
$("import").addEventListener("click", importMarkers);
