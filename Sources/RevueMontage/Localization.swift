import Foundation
import NotesCore

/// Langues de l'interface.
enum AppLanguage: String, CaseIterable, Identifiable {
    case french = "fr"
    case english = "en"

    var id: String { rawValue }

    /// Nom affiché dans le sélecteur, toujours dans sa propre langue.
    var displayName: String {
        switch self {
        case .french: "Français"
        case .english: "English"
        }
    }

    /// Au premier lancement : français si le Mac est en français, anglais sinon.
    static var systemDefault: AppLanguage {
        Locale.preferredLanguages.first?.hasPrefix("fr") == true ? .french : .english
    }
}

/// Langue courante, tenue à jour par AppSettings.
enum L10n {
    static var language: AppLanguage = .french
}

/// Texte de l'interface dans la langue choisie : `tr("Ouvrir", "Open")`.
func tr(_ french: String, _ english: String) -> String {
    L10n.language == .english ? english : french
}

extension NoteCategory {
    /// Catégories par défaut (mêmes identifiants), avec leurs noms traduits.
    static func defaults(for language: AppLanguage) -> [NoteCategory] {
        let english = ["Rhythm", "Sound", "Grading", "Text", "General"]
        return defaults.enumerated().map { index, category in
            var localized = category
            if language == .english { localized.name = english[index] }
            return localized
        }
    }
}

extension MarkerColor {
    var localizedName: String {
        switch self {
        case .red: tr("Rouge", "Red")
        case .green: tr("Vert", "Green")
        case .blue: tr("Bleu", "Blue")
        case .cyan: tr("Cyan", "Cyan")
        case .yellow: tr("Jaune", "Yellow")
        case .purple: tr("Violet", "Purple")
        }
    }
}

extension ExportError {
    var localizedMessage: String {
        switch self {
        case .noNotes:
            tr("Cette revue ne contient aucune note : rien à exporter.",
               "This review has no notes: nothing to export.")
        case .invalidStartTimecode(let tc):
            tr("Le timecode de départ « \(tc) » n'est pas valide (format HH:MM:SS:FF).",
               "The start timecode \"\(tc)\" is not valid (format HH:MM:SS:FF).")
        }
    }
}
