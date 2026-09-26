import Foundation

/// Couleurs disponibles à la fois dans Premiere Pro et DaVinci Resolve.
public enum MarkerColor: String, Codable, CaseIterable, Sendable {
    case red, green, blue, cyan, yellow, purple

    public var displayName: String {
        switch self {
        case .red: "Rouge"
        case .green: "Vert"
        case .blue: "Bleu"
        case .cyan: "Cyan"
        case .yellow: "Jaune"
        case .purple: "Violet"
        }
    }

    public var resolveName: String {
        switch self {
        case .red: "ResolveColorRed"
        case .green: "ResolveColorGreen"
        case .blue: "ResolveColorBlue"
        case .cyan: "ResolveColorCyan"
        case .yellow: "ResolveColorYellow"
        case .purple: "ResolveColorPurple"
        }
    }

    /// Index de couleur des marqueurs Premiere (0 vert, 1 rouge, 2 violet, 3 orange, 4 jaune, 5 blanc, 6 bleu, 7 cyan).
    public var premiereIndex: Int {
        switch self {
        case .green: 0
        case .red: 1
        case .purple: 2
        case .yellow: 4
        case .blue: 6
        case .cyan: 7
        }
    }
}

public struct NoteCategory: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var color: MarkerColor

    public init(id: UUID = UUID(), name: String, color: MarkerColor) {
        self.id = id
        self.name = name
        self.color = color
    }

    /// Identifiants fixes pour que les catégories par défaut restent reconnues d'une revue à l'autre.
    public static let defaults: [NoteCategory] = [
        NoteCategory(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Rythme", color: .red),
        NoteCategory(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Son", color: .blue),
        NoteCategory(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "Étalo", color: .yellow),
        NoteCategory(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, name: "Texte", color: .green),
        NoteCategory(id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!, name: "Général", color: .purple),
    ]
}

public struct Note: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    /// Position en images depuis le début de la vidéo.
    public var frame: Int
    public var text: String
    public var categoryID: UUID
    public var createdAt: Date

    public init(id: UUID = UUID(), frame: Int, text: String, categoryID: UUID, createdAt: Date = Date()) {
        self.id = id
        self.frame = frame
        self.text = text
        self.categoryID = categoryID
        self.createdAt = createdAt
    }
}

public struct Review: Codable, Hashable, Sendable {
    public var formatVersion: Int
    public var videoPath: String
    public var frameRate: FrameRate
    public var durationFrames: Int
    public var categories: [NoteCategory]
    public var notes: [Note]

    public init(videoPath: String, frameRate: FrameRate, durationFrames: Int,
                categories: [NoteCategory] = NoteCategory.defaults, notes: [Note] = []) {
        self.formatVersion = 1
        self.videoPath = videoPath
        self.frameRate = frameRate
        self.durationFrames = durationFrames
        self.categories = categories
        self.notes = notes
    }

    public var videoURL: URL { URL(fileURLWithPath: videoPath) }
    public var title: String { videoURL.deletingPathExtension().lastPathComponent }

    public var sortedNotes: [Note] {
        notes.sorted { ($0.frame, $0.createdAt) < ($1.frame, $1.createdAt) }
    }

    /// Catégorie d'une note ; si elle a disparu, on retombe sur la dernière (Général par défaut).
    public func category(for note: Note) -> NoteCategory {
        categories.first { $0.id == note.categoryID }
            ?? categories.last
            ?? NoteCategory.defaults[4]
    }

    /// Fichier de sauvegarde placé à côté de la vidéo.
    public static func storageURL(forVideo video: URL) -> URL {
        video.appendingPathExtension("revue.json")
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> Review {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Review.self, from: data)
    }
}
