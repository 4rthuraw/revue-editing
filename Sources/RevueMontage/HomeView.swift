import SwiftUI

/// Écran d'accueil : zone de dépôt et revues récentes.
struct HomeView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settings: AppSettings
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Revue Montage")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                SettingsLink { Label(tr("Réglages", "Settings"), systemImage: "gearshape") }
                    .buttonStyle(GhostButtonStyle())
            }
            .padding(.leading, 84)
            .padding(.trailing, 16)
            .frame(height: 48)
            .background(Theme.panel)
            .overlay(alignment: .bottom) { Theme.border.frame(height: 1) }

            HStack(alignment: .top, spacing: 32) {
                dropZone
                recents
            }
            .padding(40)
            .frame(maxWidth: 1100, maxHeight: .infinity)
        }
    }

    private var dropZone: some View {
        Button { state.presentOpenPanel() } label: {
            VStack(spacing: 14) {
                Image(systemName: "film.stack")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(Theme.accentText)
                Text(tr("Glisse ton export ici", "Drop your export here"))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(tr("ou clique pour choisir une vidéo (.mp4, .mov)\nLes notes déjà prises sur cette vidéo seront rechargées.",
                         "or click to choose a video (.mp4, .mov)\nNotes already taken on this video will be reloaded."))
                    .multilineTextAlignment(.center)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
                Text("⌘O")
                    .font(Theme.mono)
                    .foregroundStyle(Theme.textMuted)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isHovering ? Theme.selected : Theme.panel, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isHovering ? Theme.accent : Theme.borderStrong, style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var recents: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("RÉCENTS", "RECENT"))
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.8)
                .foregroundStyle(Theme.textMuted)
            if settings.recentVideos.isEmpty {
                Text(tr("Aucune revue pour l'instant.", "No reviews yet."))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
            }
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(settings.recentVideos, id: \.self) { path in
                        RecentRow(path: path)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(width: 320)
    }
}

private struct RecentRow: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settings: AppSettings
    let path: String
    @State private var hovering = false

    private var url: URL { URL(fileURLWithPath: path) }
    private var exists: Bool { FileManager.default.fileExists(atPath: path) }

    var body: some View {
        Button { state.open(url) } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.rectangle.fill")
                    .foregroundStyle(exists ? Theme.accentText : Theme.textMuted)
                VStack(alignment: .leading, spacing: 2) {
                    Text(url.deletingPathExtension().lastPathComponent)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(exists ? Theme.text : Theme.textMuted)
                        .lineLimit(1)
                    Text(exists ? url.deletingLastPathComponent().path : tr("Fichier introuvable", "File not found"))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                Spacer()
                if hovering {
                    Button { settings.forgetRecent(path) } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.textMuted)
                        .help(tr("Retirer de la liste", "Remove from list"))
                }
            }
            .padding(10)
            .background(hovering ? Theme.raised : Theme.panel, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
