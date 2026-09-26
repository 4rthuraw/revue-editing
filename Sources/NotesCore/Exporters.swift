import Foundation

public struct ExportSettings: Sendable {
    public var startTimecode: String
    public var dropFrame: Bool

    public init(startTimecode: String = "01:00:00:00", dropFrame: Bool = false) {
        self.startTimecode = startTimecode
        self.dropFrame = dropFrame
    }
}

public enum ExportError: Error, Equatable, LocalizedError {
    case noNotes
    case invalidStartTimecode(String)

    public var errorDescription: String? {
        switch self {
        case .noNotes: "Cette revue ne contient aucune note : rien à exporter."
        case .invalidStartTimecode(let tc): "Le timecode de départ « \(tc) » n'est pas valide (format HH:MM:SS:FF)."
        }
    }
}

public enum ResolveEDLExporter {
    public static func export(_ review: Review, settings: ExportSettings) throws -> String {
        guard !review.notes.isEmpty else { throw ExportError.noNotes }
        let rate = review.frameRate
        let dropFrame = settings.dropFrame && rate.supportsDropFrame
        let start: Int
        do {
            start = try Timecode.frame(from: settings.startTimecode, rate: rate, dropFrame: dropFrame)
        } catch {
            throw ExportError.invalidStartTimecode(settings.startTimecode)
        }

        var lines = [
            "TITLE: \(singleLine(review.title))",
            "FCM: \(dropFrame ? "DROP FRAME" : "NON-DROP FRAME")",
            "",
        ]
        for (index, note) in review.sortedNotes.enumerated() {
            let category = review.category(for: note)
            let tcIn = Timecode.string(fromFrame: start + note.frame, rate: rate, dropFrame: dropFrame)
            let tcOut = Timecode.string(fromFrame: start + note.frame + 1, rate: rate, dropFrame: dropFrame)
            let number = String(format: "%03d", index + 1)
            lines.append("\(number)  001      V     C        \(tcIn) \(tcOut) \(tcIn) \(tcOut)")
            let text = "[\(category.name)] \(note.text)"
            lines.append(" |C:\(category.color.resolveName) |M:\(markerText(text)) |D:1")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    /// Le texte doit tenir sur une ligne et ne pas contenir le séparateur « | » de l'EDL.
    static func markerText(_ text: String) -> String {
        singleLine(text).replacingOccurrences(of: "|", with: "/")
    }

    static func singleLine(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

/// Fichier lu par le panneau Premiere Pro (premiere-panel/).
public struct PremiereMarkerFile: Codable, Equatable, Sendable {
    public struct Marker: Codable, Equatable, Sendable {
        public var frame: Int
        public var ticks: String
        public var timecode: String
        public var name: String
        public var comments: String
        public var color: String
        public var colorIndex: Int
    }

    public var format: String
    public var version: Int
    public var reviewName: String
    public var frameRate: FrameRate
    public var ticksPerFrame: String
    public var markers: [Marker]
}

public enum PremiereJSONExporter {
    public static let formatID = "revue-montage-premiere"

    public static func makeFile(_ review: Review, settings: ExportSettings) throws -> PremiereMarkerFile {
        guard !review.notes.isEmpty else { throw ExportError.noNotes }
        let rate = review.frameRate
        let dropFrame = settings.dropFrame && rate.supportsDropFrame
        let start = (try? Timecode.frame(from: settings.startTimecode, rate: rate, dropFrame: dropFrame)) ?? 0
        let markers = review.sortedNotes.map { note -> PremiereMarkerFile.Marker in
            let category = review.category(for: note)
            return .init(
                frame: note.frame,
                ticks: String(rate.premiereTicks(atFrame: note.frame)),
                timecode: Timecode.string(fromFrame: start + note.frame, rate: rate, dropFrame: dropFrame),
                name: category.name,
                comments: note.text,
                color: category.color.rawValue,
                colorIndex: category.color.premiereIndex
            )
        }
        return PremiereMarkerFile(
            format: formatID,
            version: 1,
            reviewName: review.title,
            frameRate: rate,
            ticksPerFrame: String(rate.premiereTicks(atFrame: 1)),
            markers: markers
        )
    }

    public static func export(_ review: Review, settings: ExportSettings) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(makeFile(review, settings: settings))
    }
}
