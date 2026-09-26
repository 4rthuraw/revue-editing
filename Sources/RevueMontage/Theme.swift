import SwiftUI
import NotesCore

/// Palette sombre inspirée de Frame.io.
enum Theme {
    static let background = Color(hex: 0x0E0E11)
    static let stage = Color(hex: 0x0A0A0C)
    static let panel = Color(hex: 0x121216)
    static let raised = Color(hex: 0x1D1D23)
    static let selected = Color(hex: 0x1B1A2E)
    static let border = Color(hex: 0x222228)
    static let borderStrong = Color(hex: 0x2C2C34)
    static let accent = Color(hex: 0x5B53FF)
    static let accentSoft = Color(hex: 0x27244D)
    static let accentText = Color(hex: 0xB3AEFF)
    static let text = Color(hex: 0xE8E8EC)
    static let textSecondary = Color(hex: 0xA0A0AA)
    static let textMuted = Color(hex: 0x8B8B95)

    static let mono = Font.system(size: 11, weight: .medium, design: .monospaced)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension MarkerColor {
    var swiftUIColor: Color {
        switch self {
        case .red: Color(hex: 0xFF5D5D)
        case .green: Color(hex: 0x6EE7A0)
        case .blue: Color(hex: 0x4D8DFF)
        case .cyan: Color(hex: 0x5EC2FF)
        case .yellow: Color(hex: 0xFFC94D)
        case .purple: Color(hex: 0xB07CFF)
        }
    }
}

/// Pastille de timecode violette.
struct TimecodeChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.mono)
            .foregroundStyle(Theme.accentText)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 4))
    }
}

/// Étiquette de catégorie colorée.
struct CategoryTag: View {
    let category: NoteCategory
    var showsDot = false
    var body: some View {
        HStack(spacing: 4) {
            if showsDot { Circle().fill(category.color.swiftUIColor).frame(width: 6, height: 6) }
            Text(category.name)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(category.color.swiftUIColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(category.color.swiftUIColor.opacity(0.14), in: Capsule())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.accent.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.raised.opacity(configuration.isPressed ? 0.6 : 1), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.borderStrong))
    }
}
