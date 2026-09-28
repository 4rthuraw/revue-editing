import AVFoundation
import AppKit
import SwiftUI
import NotesCore

/// Écran de revue : lecteur au centre, notes à droite (disposition Frame.io).
struct ReviewView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var session: ReviewSession

    var body: some View {
        VStack(spacing: 0) {
            TopBar(session: session)
            HStack(spacing: 0) {
                PlayerStage(session: session)
                NotesPanel(session: session)
                    .frame(width: 360)
            }
        }
        .overlay(alignment: .top) {
            if let banner = session.banner {
                BannerView(banner: banner) { session.banner = nil }
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: session.banner)
        .alert(tr("Erreur", "Error"), isPresented: Binding(
            get: { session.errorMessage != nil }, set: { if !$0 { session.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(session.errorMessage ?? "")
        }
    }
}

private struct TopBar: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var session: ReviewSession

    var body: some View {
        HStack(spacing: 10) {
            Button { state.closeSession() } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(GhostButtonStyle())
            .help(tr("Retour à l'accueil", "Back to home"))

            HStack(spacing: 6) {
                Text(tr("Revue ·", "Review ·")).foregroundStyle(Theme.textMuted)
                Text(session.review.videoURL.lastPathComponent)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text("\(session.rate.label) \(tr("im/s", "fps"))")
                    .font(Theme.mono)
                    .foregroundStyle(Theme.textMuted)
                    .padding(.leading, 4)
            }
            .font(.system(size: 12))

            Spacer()

            SettingsLink { Label(tr("Réglages", "Settings"), systemImage: "gearshape") }
                .buttonStyle(GhostButtonStyle())

            Menu {
                Button("DaVinci Resolve (.edl)") { session.export(.resolve) }
                Button("Premiere Pro (.json)") { session.export(.premiere) }
            } label: {
                Text(tr("Exporter les marqueurs", "Export Markers"))
            }
            .menuStyle(.button)
            .buttonStyle(PrimaryButtonStyle())
            .fixedSize()
            .disabled(session.review.notes.isEmpty)
            .help(session.review.notes.isEmpty ? tr("Ajoute au moins une note pour exporter", "Add at least one note to export") : "⌘E Resolve · ⇧⌘E Premiere")
        }
        .padding(.leading, 84)
        .padding(.trailing, 14)
        .frame(height: 48)
        .background(Theme.panel)
        .overlay(alignment: .bottom) { Theme.border.frame(height: 1) }
    }
}

private struct PlayerStage: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var session: ReviewSession

    var body: some View {
        VStack(spacing: 10) {
            PlayerSurface(player: session.player)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
                .onTapGesture { session.togglePlay() }
                .padding(.horizontal, 22)
                .padding(.top, 18)

            VStack(spacing: 8) {
                ScrubBar(session: session)
                    .frame(height: 22)
                controls
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 14)
        }
        .background(Theme.stage)
    }

    private var controls: some View {
        HStack(spacing: 14) {
            HStack(spacing: 4) {
                iconButton("backward.frame.fill", help: tr("Image précédente (←)", "Previous frame (←)")) { session.step(by: -1) }
                iconButton(session.isPlaying ? "pause.fill" : "play.fill", help: tr("Lecture / pause (Espace)", "Play / pause (Space)"), size: 16) { session.togglePlay() }
                iconButton("forward.frame.fill", help: tr("Image suivante (→)", "Next frame (→)")) { session.step(by: 1) }
            }
            HStack(spacing: 6) {
                Text(session.timecode(for: session.currentFrame))
                    .foregroundStyle(Theme.text)
                Text("/ \(session.timecode(for: session.review.durationFrames))")
                    .foregroundStyle(Theme.textMuted)
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))

            Spacer()

            Toggle(isOn: $settings.pauseWhileTyping) {
                Text(tr("Pause auto en écrivant", "Auto-pause while typing"))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(Theme.accent)

            Text(tr("N nouvelle note · J K L · ← →", "N new note · J K L · ← →"))
                .font(.system(size: 10))
                .foregroundStyle(Theme.textMuted)
        }
    }

    private func iconButton(_ name: String, help: String, size: CGFloat = 12, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: size))
                .foregroundStyle(Theme.text)
                .frame(width: 28, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// Couche vidéo AVFoundation sans contrôles natifs.
struct PlayerSurface: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.player = player
        return view
    }

    func updateNSView(_ nsView: PlayerLayerView, context: Context) {
        nsView.playerLayer.player = player
    }

    final class PlayerLayerView: NSView {
        let playerLayer = AVPlayerLayer()

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer = CALayer()
            layer?.backgroundColor = NSColor.black.cgColor
            playerLayer.videoGravity = .resizeAspect
            layer?.addSublayer(playerLayer)
        }

        required init?(coder: NSCoder) { fatalError() }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.frame = bounds
            CATransaction.commit()
        }
    }
}

/// Barre de lecture avec un point coloré par note.
struct ScrubBar: View {
    @ObservedObject var session: ReviewSession
    @State private var wasPlaying = false
    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let total = max(session.review.durationFrames - 1, 1)
            let progress = CGFloat(session.currentFrame) / CGFloat(total)
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: 0x2A2A31)).frame(height: 4)
                Capsule().fill(Color.white).frame(width: max(0, width * progress), height: 4)
                Circle().fill(Color.white).frame(width: 12, height: 12)
                    .offset(x: width * progress - 6)
                    .opacity(dragging ? 1 : 0.9)

                ForEach(session.review.notes) { note in
                    let category = session.category(for: note)
                    Circle()
                        .fill(category.color.swiftUIColor)
                        .overlay(Circle().stroke(Theme.stage, lineWidth: 2))
                        .overlay(Circle().stroke(Color.white, lineWidth: session.selectedNoteID == note.id ? 1.5 : 0).padding(-2))
                        .frame(width: 13, height: 13)
                        .offset(x: width * CGFloat(note.frame) / CGFloat(total) - 6.5, y: -12)
                        .onTapGesture { session.select(note) }
                        .help("\(session.timecode(for: note.frame)) · \(category.name) — \(note.text)")
                }
            }
            .frame(height: geo.size.height)
            .padding(.top, 12)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !dragging {
                            dragging = true
                            wasPlaying = session.isPlaying
                            session.pause()
                        }
                        let ratio = min(max(value.location.x / width, 0), 1)
                        session.seek(toFrame: Int((ratio * CGFloat(total)).rounded()))
                    }
                    .onEnded { _ in
                        dragging = false
                        if wasPlaying { session.togglePlay() }
                    }
            )
        }
        .padding(.top, 8)
    }
}

private struct BannerView: View {
    let banner: ReviewSession.Banner
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: 0x6EE7A0))
            Text(banner.message).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.text)
            if let url = banner.fileURL {
                Button(tr("Afficher dans le Finder", "Show in Finder")) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    .buttonStyle(GhostButtonStyle())
            }
            Button(action: dismiss) { Image(systemName: "xmark") }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.borderStrong))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
        .task(id: banner.id) {
            try? await Task.sleep(for: .seconds(8))
            dismiss()
        }
    }
}
