import Foundation
import NotesCore

// Vérifications exécutables de NotesCore (XCTest / Swift Testing indisponibles sans Xcode).
// Lancer avec : swift run NotesCoreChecks

var failures = 0
var passed = 0

@MainActor func check<T: Equatable>(_ actual: T, _ expected: T, _ label: String, line: Int = #line) {
    if actual == expected {
        passed += 1
    } else {
        failures += 1
        print("✗ [ligne \(line)] \(label)\n    obtenu  : \(actual)\n    attendu : \(expected)")
    }
}

let r24 = FrameRate(24), r25 = FrameRate(25), r2398 = FrameRate(24000, 1001)
let r2997 = FrameRate(30000, 1001), r5994 = FrameRate(60000, 1001), r50 = FrameRate(50)

// Détection de cadence
check(FrameRate.detect(fromMeasured: 23.976025), r2398, "detect 23.976")
check(FrameRate.detect(fromMeasured: 29.97003), r2997, "detect 29.97")
check(FrameRate.detect(fromMeasured: 59.94006), r5994, "detect 59.94")
check(FrameRate.detect(fromMeasured: 25.0), r25, "detect 25")
check(FrameRate.detect(fromMeasured: 24.0), r24, "detect 24")
check(FrameRate.detect(fromMeasured: 50.0), r50, "detect 50")
check(r2398.label, "23.976", "label 23.976")
check(r2997.label, "29.97", "label 29.97")

// Timecodes non drop-frame
check(Timecode.string(fromFrame: 0, rate: r24, dropFrame: false), "00:00:00:00", "tc 0")
check(Timecode.string(fromFrame: 86400, rate: r24, dropFrame: false), "01:00:00:00", "1h en 24")
check(Timecode.string(fromFrame: 90000 + 7 * 25 + 3, rate: r25, dropFrame: false), "01:00:07:03", "25 im/s")
check(Timecode.string(fromFrame: 50 * 61 + 49, rate: r50, dropFrame: false), "00:01:01:49", "50 im/s")
check(Timecode.string(fromFrame: 1800, rate: r2997, dropFrame: false), "00:01:00:00", "29.97 NDF")
check(Timecode.string(fromFrame: 86400 + 5, rate: r2398, dropFrame: true), "01:00:00:05", "le DF est ignoré en 23.976")

// Timecodes drop-frame
check(Timecode.string(fromFrame: 1799, rate: r2997, dropFrame: true), "00:00:59;29", "DF avant la minute")
check(Timecode.string(fromFrame: 1800, rate: r2997, dropFrame: true), "00:01:00;02", "DF saute ;00 et ;01")
check(Timecode.string(fromFrame: 17982, rate: r2997, dropFrame: true), "00:10:00;00", "DF 10 minutes")
check(Timecode.string(fromFrame: 107892, rate: r2997, dropFrame: true), "01:00:00;00", "DF 1 heure")
check(Timecode.string(fromFrame: 3600, rate: r5994, dropFrame: true), "00:01:00;04", "59.94 DF")

// Lecture de timecodes
check(try Timecode.frame(from: "01:00:00:00", rate: r24, dropFrame: false), 86400, "parse 1h 24")
check(try Timecode.frame(from: "01:00:00;00", rate: r2997, dropFrame: true), 107892, "parse 1h DF")
check(try Timecode.frame(from: "00:01:00;02", rate: r2997, dropFrame: true), 1800, "parse DF minute")
check((try? Timecode.frame(from: "01:00:00", rate: r24, dropFrame: false)) == nil, true, "format incomplet refusé")
check((try? Timecode.frame(from: "00:00:00:25", rate: r25, dropFrame: false)) == nil, true, "image hors cadence refusée")
check(Timecode.isValid("00:00:00:00", rate: r25), true, "isValid")

// Aller-retour sur de nombreuses images
for rate in [r2997, r5994] {
    var ok = true
    for frame in stride(from: 0, to: 300_000, by: 7) {
        let tc = Timecode.string(fromFrame: frame, rate: rate, dropFrame: true)
        if (try? Timecode.frame(from: tc, rate: rate, dropFrame: true)) != frame { ok = false; print("  écart à \(frame) → \(tc)"); break }
    }
    check(ok, true, "aller-retour DF \(rate.label)")
}

// Secondes ↔ images
check(r2398.frame(atSeconds: r2398.seconds(atFrame: 1000)), 1000, "secondes aller-retour 23.976")
check(r25.frame(atSeconds: 2.0), 50, "2 s en 25")
check(r25.frame(atSeconds: 1.999), 49, "juste avant 2 s")
check(r2398.premiereTicks(atFrame: 1), 10_594_584_000, "ticks 23.976")
check(r24.premiereTicks(atFrame: 1), 10_584_000_000, "ticks 24")

// Export EDL Resolve
let rythme = NoteCategory.defaults[0], son = NoteCategory.defaults[1]
var review = Review(videoPath: "/tmp/Court-métrage v3.mp4", frameRate: r25, durationFrames: 5000)
review.notes = [
    Note(frame: 20 * 25 + 5, text: "Ambiance qui saute | ajouter\nun fondu", categoryID: son.id),
    Note(frame: 7 * 25 + 3, text: "Plan trop long, couper avant qu'il se retourne.", categoryID: rythme.id),
    Note(frame: 100, text: "Catégorie supprimée", categoryID: UUID()),
]
let edl = try ResolveEDLExporter.export(review, settings: ExportSettings(startTimecode: "01:00:00:00"))
let expectedEDL = """
TITLE: Court-métrage v3
FCM: NON-DROP FRAME

001  001      V     C        01:00:04:00 01:00:04:01 01:00:04:00 01:00:04:01
 |C:ResolveColorPurple |M:[Général] Catégorie supprimée |D:1

002  001      V     C        01:00:07:03 01:00:07:04 01:00:07:03 01:00:07:04
 |C:ResolveColorRed |M:[Rythme] Plan trop long, couper avant qu'il se retourne. |D:1

003  001      V     C        01:00:20:05 01:00:20:06 01:00:20:05 01:00:20:06
 |C:ResolveColorBlue |M:[Son] Ambiance qui saute / ajouter un fondu |D:1

"""
check(edl, expectedEDL, "EDL Resolve de référence")

let edlZero = try ResolveEDLExporter.export(review, settings: ExportSettings(startTimecode: "00:00:00:00"))
check(edlZero.contains("00:00:07:03 00:00:07:04"), true, "EDL départ 00:00:00:00")

var dfReview = Review(videoPath: "/tmp/df.mov", frameRate: r2997, durationFrames: 5000)
dfReview.notes = [Note(frame: 1800, text: "x", categoryID: rythme.id)]
let dfEDL = try ResolveEDLExporter.export(dfReview, settings: ExportSettings(startTimecode: "01:00:00;00", dropFrame: true))
check(dfEDL.contains("FCM: DROP FRAME"), true, "EDL en-tête DF")
check(dfEDL.contains("01:01:00;02 01:01:00;03"), true, "EDL timecode DF")

var emptyReview = review
emptyReview.notes = []
do { _ = try ResolveEDLExporter.export(emptyReview, settings: ExportSettings()); check(false, true, "revue vide refusée") }
catch { check(error as? ExportError, .noNotes, "revue vide refusée (EDL)") }
do { _ = try ResolveEDLExporter.export(review, settings: ExportSettings(startTimecode: "abc")); check(false, true, "tc invalide") }
catch { check(error as? ExportError, .invalidStartTimecode("abc"), "timecode de départ invalide") }

// Export JSON Premiere
let premiere = try PremiereJSONExporter.makeFile(review, settings: ExportSettings())
check(premiere.markers.count, 3, "Premiere : nombre de marqueurs")
check(premiere.markers[1].name, "Rythme", "Premiere : nom = catégorie")
check(premiere.markers[1].comments, "Plan trop long, couper avant qu'il se retourne.", "Premiere : commentaire")
check(premiere.markers[1].colorIndex, 1, "Premiere : rouge = 1")
check(premiere.markers[1].ticks, String(178 * 10_160_640_000), "Premiere : ticks en 25 im/s")
check(premiere.markers[2].comments, "Ambiance qui saute | ajouter\nun fondu", "Premiere : texte intact")
check(premiere.ticksPerFrame, "10160640000", "Premiere : ticks par image")
let decodedPremiere = try JSONDecoder().decode(PremiereMarkerFile.self, from: PremiereJSONExporter.export(review, settings: ExportSettings()))
check(decodedPremiere, premiere, "Premiere : JSON aller-retour")

// Sauvegarde de la revue
let reloaded = try Review.decode(review.encoded())
check(reloaded.notes.map(\.id), review.notes.map(\.id), "revue aller-retour (notes)")
check(reloaded.frameRate, r25, "revue aller-retour (cadence)")
check(Review.storageURL(forVideo: URL(fileURLWithPath: "/a/b.mp4")).path, "/a/b.mp4.revue.json", "chemin de sauvegarde")

print(failures == 0 ? "✓ \(passed) vérifications OK" : "\n\(failures) échec(s), \(passed) OK")
exit(failures == 0 ? 0 : 1)
