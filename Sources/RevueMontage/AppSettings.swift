import Foundation
import NotesCore

/// Réglages globaux, persistés dans UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var language: AppLanguage {
        didSet {
            guard language != oldValue else { return }
            defaults.set(language.rawValue, forKey: "language")
            // Les menus fournis par macOS (Édition, Fenêtre…) suivront au prochain lancement.
            defaults.set([language.rawValue], forKey: "AppleLanguages")
            L10n.language = language
            renameDefaultCategories(from: oldValue, to: language)
        }
    }
    @Published var pauseWhileTyping: Bool {
        didSet { defaults.set(pauseWhileTyping, forKey: "pauseWhileTyping") }
    }
    @Published var startTimecode: String {
        didSet { defaults.set(startTimecode, forKey: "startTimecode") }
    }
    @Published var dropFrame: Bool {
        didSet { defaults.set(dropFrame, forKey: "dropFrame") }
    }
    @Published var categories: [NoteCategory] {
        didSet { save(categories, forKey: "categories") }
    }
    @Published private(set) var recentVideos: [String] {
        didSet { defaults.set(recentVideos, forKey: "recentVideos") }
    }

    private init() {
        let language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .systemDefault
        L10n.language = language
        self.language = language
        pauseWhileTyping = defaults.object(forKey: "pauseWhileTyping") as? Bool ?? true
        startTimecode = defaults.string(forKey: "startTimecode") ?? "01:00:00:00"
        dropFrame = defaults.bool(forKey: "dropFrame")
        recentVideos = defaults.stringArray(forKey: "recentVideos") ?? []
        if let data = defaults.data(forKey: "categories"),
           let saved = try? JSONDecoder().decode([NoteCategory].self, from: data), !saved.isEmpty {
            categories = saved
        } else {
            categories = NoteCategory.defaults(for: language)
        }
    }

    var exportSettings: ExportSettings {
        ExportSettings(startTimecode: startTimecode, dropFrame: dropFrame)
    }

    func noteRecent(_ video: URL) {
        var list = recentVideos.filter { $0 != video.path }
        list.insert(video.path, at: 0)
        recentVideos = Array(list.prefix(12))
    }

    func forgetRecent(_ path: String) {
        recentVideos.removeAll { $0 == path }
    }

    func resetCategories() {
        categories = NoteCategory.defaults(for: language)
    }

    /// Traduit les catégories par défaut, sauf celles que l'utilisateur a renommées.
    private func renameDefaultCategories(from old: AppLanguage, to new: AppLanguage) {
        let oldDefaults = NoteCategory.defaults(for: old)
        let newDefaults = NoteCategory.defaults(for: new)
        categories = categories.map { category in
            guard let index = oldDefaults.firstIndex(where: { $0.id == category.id }),
                  oldDefaults[index].name == category.name else { return category }
            var renamed = category
            renamed.name = newDefaults[index].name
            return renamed
        }
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}
