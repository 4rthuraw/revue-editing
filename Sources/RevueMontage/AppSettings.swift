import Foundation
import NotesCore

/// Réglages globaux, persistés dans UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

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
        pauseWhileTyping = defaults.object(forKey: "pauseWhileTyping") as? Bool ?? true
        startTimecode = defaults.string(forKey: "startTimecode") ?? "01:00:00:00"
        dropFrame = defaults.bool(forKey: "dropFrame")
        recentVideos = defaults.stringArray(forKey: "recentVideos") ?? []
        if let data = defaults.data(forKey: "categories"),
           let saved = try? JSONDecoder().decode([NoteCategory].self, from: data), !saved.isEmpty {
            categories = saved
        } else {
            categories = NoteCategory.defaults
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
        categories = NoteCategory.defaults
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}
