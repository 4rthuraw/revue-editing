<h1 align="center">🎬 Revue Montage</h1>

<p align="center">
  <b>Prends des notes horodatées pendant une revue de montage,<br>
  puis retrouve-les en marqueurs colorés dans DaVinci Resolve ou Premiere Pro.</b>
</p>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white">
  <a href="LICENSE"><img alt="Licence MIT" src="https://img.shields.io/badge/licence-MIT-5B53FF"></a>
  <a href="https://ko-fi.com/arthuraw_"><img alt="Soutenir sur Ko-fi" src="https://img.shields.io/badge/soutenir-Ko--fi-FF5E5B?logo=ko-fi&logoColor=white"></a>
</p>

<p align="center">🇫🇷 Français · <a href="README.en.md">🇬🇧 English</a></p>

<p align="center"><img src="docs/images/revue.webp" alt="Revue Montage : lecteur vidéo à gauche, notes colorées à droite" width="900"></p>

## Pourquoi ce logiciel ?

Je l'ai créé pour deux raisons :

1. **C'est plus fluide.** Relire un montage un peu long directement dans la timeline, ça fait vite ramer mon Mac.
   Avec un export rapide de la séquence lu dans Revue Montage, la lecture reste fluide et je peux me concentrer
   sur les corrections au lieu d'attendre que la timeline suive.
2. **C'est agréable.** J'aime avoir une interface jolie et pratique pour faire mes revues de montage :
   un lecteur, une liste de notes, des raccourcis clavier, et c'est tout.

À la fin de la revue, les notes partent dans ton logiciel de montage sous forme de **marqueurs colorés,
placés à l'image près** : il n'y a plus qu'à les traiter un par un.

## Fonctionnalités

- 🎞️ Glisser-déposer d'un export `.mp4` / `.mov` : la cadence est détectée automatiquement (23.976, 24, 25, 29.97, 50, 59.94…).
- ⌨️ Raccourcis de monteur : **Espace**, **J K L**, **← →** image par image.
- 📝 **N** pour noter au timecode exact, avec des catégories colorées (Rythme, Son, Étalo, Texte, Général — modifiables).
- 💾 Sauvegarde automatique à côté de la vidéo : tu retrouves tes notes en rouvrant le fichier.
- 📤 Export en marqueurs pour **DaVinci Resolve** (`.edl`) et **Premiere Pro** (`.json` + panneau d'import).
- ⏱️ Timecode de départ de la séquence et drop-frame réglables.
- 🌍 Interface en français ou en anglais.

## Installation

**Il te faut :** un Mac sous **macOS 14 Sonoma** ou plus récent, et les outils de développement d'Apple
(`xcode-select --install` dans le Terminal si tu ne les as pas).

```bash
git clone https://github.com/4rthuraw/revue-editing.git
cd revue-editing
./scripts/build-app.sh          # construit dist/Revue Montage.app → à glisser dans Applications
```

**Pour Premiere Pro** (25.6 ou plus récent) : dans l'app, ouvre **Réglages (⌘,) → Général → Premiere Pro → Installer**.
Le panneau « Importer les notes » est inclus dans l'app ; il suffit de redémarrer Premiere ensuite.
(Pour les développeurs : `./premiere-panel/install.sh` fait la même chose depuis le code source.)

## Pendant la revue

1. Exporte rapidement **toute la séquence** et glisse le fichier dans Revue Montage.
2. **Espace** lecture/pause · **← →** image par image (⇧ = 10 images) · **J K L**.
3. **N** (ou Entrée) : nouvelle note au timecode actuel. **Tab** change la catégorie, **Entrée** valide,
   **⌥Entrée** retour à la ligne, **Échap** annule.
4. Clic sur une note = aller à ce moment. Double-clic = modifier. Clic droit = catégorie, recaler, supprimer.

Les notes sont sauvegardées automatiquement dans `<vidéo>.revue.json`, à côté de la vidéo.
Réglages (⌘,) : langue, pause auto en écrivant, timecode de départ de la séquence, drop-frame, catégories.

<p align="center"><img src="docs/images/reglages.png" alt="Réglages : pause auto, timecode de départ, drop-frame" width="420"></p>

## Export vers ton logiciel de montage

**Exporter les marqueurs ▾** (ou ⌘E / ⇧⌘E) écrit le fichier à côté de la vidéo.

<p align="center"><img src="docs/images/export.webp" alt="Bandeau de confirmation : 6 marqueurs exportés pour Resolve" width="700"></p>

### DaVinci Resolve

Dans le Media Pool, clic droit sur la timeline →
*Timelines → Import → Timeline Markers from EDL…* → choisir `… marqueurs Resolve.edl`.
Le texte de la note devient le nom du marqueur (« [Catégorie] remarque »).
Vérifie que le **timecode de départ** dans les réglages correspond à ta timeline (01:00:00:00 par défaut).

### Premiere Pro

Ouvre la séquence, puis *Fenêtre → UXP Plugins → Importer les notes* (panneau installé depuis les Réglages de l'app),
choisis `… marqueurs Premiere.json`, puis **Ajouter à la séquence active**.
Catégorie = nom du marqueur, remarque = commentaire. Les doublons sont ignorés ;
⌘Z deux fois annule l'import (couleurs puis marqueurs).

> Astuce : dans le panneau Marqueurs de Premiere, les filtres de couleur peuvent masquer certains marqueurs.

## 🤖 Transparence : un projet « vibe codé »

Ce logiciel a été **vibe codé** : le code a été écrit par une IA (Claude, d'Anthropic), à partir de mes idées,
de mes essais et de mes retours.

Le cœur du logiciel (calcul des timecodes, exports Resolve et Premiere) est couvert par des vérifications
automatiques, et je l'ai testé dans Resolve et Premiere. Mais il peut rester des bugs : si tu en trouves un,
[ouvre une issue](https://github.com/4rthuraw/revue-editing/issues), ça m'aide beaucoup.

## ☕ Soutenir le projet

Revue Montage est **gratuit et open source**. S'il te fait gagner du temps et que tu as envie de me remercier,
tu peux me laisser un petit tip :

<a href="https://ko-fi.com/arthuraw_"><img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Soutenir sur Ko-fi"></a>

Mettre une ⭐ au dépôt ou parler du logiciel à d'autres monteurs, ça aide aussi !

## Contribuer

Les idées, les signalements de bugs et les pull requests sont les bienvenus.
Pour une grosse modification, ouvre d'abord une issue pour qu'on en discute.

### Développement

```bash
swift run NotesCoreChecks                                   # vérifications (timecodes, EDL, JSON)
swift scripts/make-test-video.swift test.mp4 25 60 90000    # vidéo de test avec timecode incrusté
```

- `Sources/NotesCore` : logique pure (timecodes, modèles, exports).
- `Sources/RevueMontage` : app SwiftUI.
- `premiere-panel/plugin` : panneau UXP pour Premiere Pro (JavaScript), en français ou en anglais selon la langue de Premiere.
- Conception : [`docs/superpowers/specs/2026-09-17-revue-montage-design.md`](docs/superpowers/specs/2026-09-17-revue-montage-design.md).

## Licence

[MIT](LICENSE) : tu peux utiliser, modifier et partager ce logiciel librement, y compris pour un usage pro,
à condition de conserver la mention de licence.
