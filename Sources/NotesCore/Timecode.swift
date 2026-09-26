import Foundation

/// Cadence d'images exprimée en fraction exacte (ex. 24000/1001 pour 23.976).
public struct FrameRate: Codable, Hashable, Sendable {
    public var numerator: Int
    public var denominator: Int

    public init(_ numerator: Int, _ denominator: Int = 1) {
        self.numerator = numerator
        self.denominator = denominator
    }

    /// Premiere Pro compte le temps en « ticks » : 254 016 000 000 par seconde.
    public static let premiereTicksPerSecond = 254_016_000_000

    public var fps: Double { Double(numerator) / Double(denominator) }

    /// Images par seconde « nominales » utilisées pour compter les timecodes (24, 25, 30, 60…).
    public var timecodeBase: Int { Int((fps).rounded()) }

    /// Le drop-frame n'existe que pour 29.97 et 59.94.
    public var supportsDropFrame: Bool { denominator == 1001 && timecodeBase % 30 == 0 }

    public var label: String {
        if denominator == 1 { return "\(numerator)" }
        return String(format: "%.3f", fps).replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
    }

    /// Convertit une cadence mesurée (ex. 23.976025) en fraction exacte.
    public static func detect(fromMeasured value: Double) -> FrameRate {
        let ntsc: [Int] = [24, 30, 48, 60, 120]
        for base in ntsc {
            let candidate = Double(base) * 1000.0 / 1001.0
            if abs(value - candidate) < 0.01 { return FrameRate(base * 1000, 1001) }
        }
        let rounded = Int(value.rounded())
        return FrameRate(max(rounded, 1))
    }

    /// Position (en images depuis le début) du temps donné en secondes.
    public func frame(atSeconds seconds: Double) -> Int {
        max(0, Int((seconds * fps + 0.001).rounded(.down)))
    }

    public func seconds(atFrame frame: Int) -> Double {
        Double(frame) * Double(denominator) / Double(numerator)
    }

    public func premiereTicks(atFrame frame: Int) -> Int {
        frame * FrameRate.premiereTicksPerSecond * denominator / numerator
    }
}

public enum TimecodeError: Error, Equatable {
    case invalidFormat(String)
}

public enum Timecode {
    /// Formate un numéro d'image absolu en HH:MM:SS:FF (ou HH:MM:SS;FF en drop-frame).
    public static func string(fromFrame totalFrame: Int, rate: FrameRate, dropFrame: Bool) -> String {
        let base = rate.timecodeBase
        var frameNumber = max(0, totalFrame)
        let useDrop = dropFrame && rate.supportsDropFrame
        if useDrop {
            let dropPerMinute = base / 15 // 2 pour 29.97, 4 pour 59.94
            let framesPer10Min = base * 600 - dropPerMinute * 9
            let framesPerMin = base * 60 - dropPerMinute
            let tens = frameNumber / framesPer10Min
            let rest = frameNumber % framesPer10Min
            frameNumber += dropPerMinute * 9 * tens
            if rest > dropPerMinute {
                frameNumber += dropPerMinute * ((rest - dropPerMinute) / framesPerMin)
            }
        }
        let ff = frameNumber % base
        let totalSeconds = frameNumber / base
        let ss = totalSeconds % 60
        let mm = (totalSeconds / 60) % 60
        let hh = (totalSeconds / 3600) % 24
        let sep = useDrop ? ";" : ":"
        return String(format: "%02d:%02d:%02d%@%02d", hh, mm, ss, sep, ff)
    }

    /// Lit un timecode « HH:MM:SS:FF » (séparateurs : ou ;) et renvoie le numéro d'image absolu.
    public static func frame(from text: String, rate: FrameRate, dropFrame: Bool) throws -> Int {
        let parts = text.trimmingCharacters(in: .whitespaces)
            .split(whereSeparator: { $0 == ":" || $0 == ";" || $0 == "." })
            .map { Int($0) }
        guard parts.count == 4, parts.allSatisfy({ $0 != nil }) else {
            throw TimecodeError.invalidFormat(text)
        }
        let hh = parts[0]!, mm = parts[1]!, ss = parts[2]!, ff = parts[3]!
        let base = rate.timecodeBase
        guard mm < 60, ss < 60, ff < base, hh < 24 else { throw TimecodeError.invalidFormat(text) }
        let totalMinutes = hh * 60 + mm
        var frames = ((hh * 3600) + (mm * 60) + ss) * base + ff
        if dropFrame && rate.supportsDropFrame {
            let dropPerMinute = base / 15
            frames -= dropPerMinute * (totalMinutes - totalMinutes / 10)
        }
        return frames
    }

    public static func isValid(_ text: String, rate: FrameRate) -> Bool {
        (try? frame(from: text, rate: rate, dropFrame: false)) != nil
    }
}
