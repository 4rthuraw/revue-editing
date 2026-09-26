# Revue Montage

Prendre des notes horodatées pendant une revue de montage, puis les retrouver en **marqueurs colorés**
dans la timeline de **DaVinci Resolve** ou **Premiere Pro**.

## Installation (une fois)

```bash
./scripts/build-app.sh          # construit dist/Revue Montage.app → à glisser dans Applications
./premiere-panel/install.sh     # installe le panneau « Importer les notes » dans Premiere Pro
```

## Pendant la revue

1. Exporte rapidement **toute la séquence** et glisse le fichier dans Revue Montage.
2. **Espace** lecture/pause · **← →** image par image (⇧ = 10 images) · **J K L**.
3. **N** (ou Entrée) : nouvelle note au timecode actuel. **Tab** change la catégorie, **Entrée** valide,
   **⌥Entrée** retour à la ligne, **Échap** annule.
4. Clic sur une note = aller à ce moment. Double-clic = modifier. Clic droit = catégorie, recaler, supprimer.

Les notes sont sauvegardées automatiquement dans `<vidéo>.revue.json`, à côté de la vidéo.
Réglages (⌘,) : pause auto en écrivant, timecode de départ de la séquence, drop-frame, catégories.

## Export

**Exporter les marqueurs ▾** (ou ⌘E / ⇧⌘E) écrit le fichier à côté de la vidéo.

- **DaVinci Resolve** : dans le Media Pool, clic droit sur la timeline →
  *Timelines → Import → Timeline Markers from EDL…* → choisir `… marqueurs Resolve.edl`.
  Le texte de la note devient le nom du marqueur (« [Catégorie] remarque »).
  Vérifie que le **timecode de départ** dans les réglages correspond à ta timeline (01:00:00:00 par défaut).
- **Premiere Pro** : ouvrir la séquence, puis *Fenêtre → UXP Plugins → Importer les notes*,
  choisir `… marqueurs Premiere.json`, **Ajouter à la séquence active**.
  Catégorie = nom du marqueur, remarque = commentaire. Les doublons sont ignorés ;
  ⌘Z deux fois annule l'import (couleurs puis marqueurs).
  Astuce : dans le panneau Marqueurs de Premiere, les filtres de couleur peuvent masquer certains marqueurs.

## Développement

```bash
swift run NotesCoreChecks                                   # vérifications (timecodes, EDL, JSON)
swift scripts/make-test-video.swift test-media/test.mp4 25 60 90000   # vidéo avec timecode incrusté
```

- `Sources/NotesCore` : logique pure (timecodes, modèles, exports).
- `Sources/RevueMontage` : app SwiftUI.
- `premiere-panel/plugin` : panneau UXP (JavaScript).
- Conception : `docs/superpowers/specs/2026-09-17-revue-montage-design.md`.
