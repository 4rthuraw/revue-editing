# Revue Montage — conception

Date : 2026-09-17 · Statut : validé

## But

Pendant une revue avec le prof de montage : ouvrir un export rapide de la séquence entière,
noter des remarques à des timecodes précis, puis importer ces remarques comme marqueurs
colorés dans la timeline de **Premiere Pro** et de **DaVinci Resolve**.

## Hypothèses

- L'export couvre toute la séquence : image 0 de la vidéo = début de la timeline.
- Timecode de départ de la séquence réglable (00:00:00:00 ou 01:00:00:00…), drop-frame réglable.

## App Mac (SwiftUI, style Frame.io, disposition « panneau à droite »)

- Glisser un .mp4/.mov → revue. La cadence est lue dans le fichier.
- Lecteur : Espace, ←/→ image par image, J/K/L. Barre de lecture avec points colorés.
- N (ou clic dans le champ) = nouvelle note au timecode courant.
  Réglage « pause auto en écrivant » ; sinon la note garde le timecode du moment où on a commencé.
  Tab = catégorie suivante, Entrée = valider (la lecture reprend si elle tournait).
- Liste triée par timecode, clic = aller au moment, édition / suppression, filtre par catégorie.
- Catégories par défaut : Rythme (rouge), Son (bleu), Étalo (jaune), Texte (vert), Général (violet).
  Couleurs limitées à celles communes à Premiere et Resolve : rouge, vert, bleu, cyan, jaune, violet.
- Sauvegarde automatique dans `<vidéo>.revue.json` à côté de la vidéo ; revues récentes.
- Export : `<vidéo> – marqueurs Resolve.edl` et `<vidéo> – marqueurs Premiere.json`. Refus si aucune note.

## Formats

- Revue : positions en **images** depuis le début (pas de secondes), cadence rationnelle (ex. 24000/1001).
- EDL Resolve : une entrée par note, `|C:ResolveColorX |M:[Catégorie] texte |D:1`,
  `FCM: DROP FRAME` si activé. Retours à la ligne → espaces, `|` → `/`.
- JSON Premiere : pour chaque marqueur image, ticks, timecode, nom (catégorie), commentaires (texte), index couleur.

## Panneau Premiere (UXP)

- Choisir le JSON → aperçu → « Ajouter à la séquence active ».
- Avertit si la cadence diffère de celle de la séquence. Ignore les marqueurs déjà présents (même temps + même texte).
- Ajout dans une transaction (puis une transaction de couleurs), message clair si pas de séquence.
- Installé en .ccx via l'installateur Adobe (UPIA). Plan B : extension CEP si l'API UXP échoue.

## Construction et tests

- Swift Package : `NotesCore` (logique pure), `RevueMontage` (app), `NotesCoreChecks` (vérifications
  exécutables — XCTest/Testing indisponibles sans Xcode). `scripts/build-app.sh` produit la .app signée localement.
- Vérifications : timecodes 23.976/24/25/29.97 DF+NDF/50, départ 00/01h, EDL de référence, aller-retour JSON.
- Vérification réelle : import dans Resolve et Premiere sur une vidéo test à timecode incrusté.

## Hors périmètre

Partage en ligne, dessin sur l'image, envoi direct dans le logiciel ouvert, comparaison de versions, distribution.
