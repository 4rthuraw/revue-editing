import AppKit
import SwiftUI
import UniformTypeIdentifiers
import NotesCore

@main
struct RevueMontageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        Window("Revue Montage", id: "main") {
            RootView()
                .environmentObject(state)
                .environmentObject(settings)
                .frame(minWidth: 1000, minHeight: 640)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1360, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(tr("Ouvrir une vidéo…", "Open Video…")) { state.presentOpenPanel() }
                    .keyboardShortcut("o")
                Button(tr("Fermer la revue", "Close Review")) { state.closeSession() }
                    .keyboardShortcut("w", modifiers: [.command, .shift])
                    .disabled(state.session == nil)
            }
            CommandMenu(tr("Marqueurs", "Markers")) {
                Button(tr("Exporter pour DaVinci Resolve (.edl)", "Export for DaVinci Resolve (.edl)")) { state.session?.export(.resolve) }
                    .keyboardShortcut("e")
                    .disabled(state.session == nil)
                Button(tr("Exporter pour Premiere Pro (.json)", "Export for Premiere Pro (.json)")) { state.session?.export(.premiere) }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(state.session == nil)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(settings)
                .preferredColorScheme(.dark)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Nécessaire quand l'exécutable est lancé hors d'un paquet .app (swift run).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// « Ouvrir avec Revue Montage » depuis le Finder, ou `open -a`.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        NotificationCenter.default.post(name: .openReviewFile, object: url)
    }
}

extension Notification.Name {
    static let openReviewFile = Notification.Name("RevueMontage.openReviewFile")
}

@MainActor
final class AppState: ObservableObject {
    @Published var session: ReviewSession?
    @Published var isOpening = false
    @Published var openError: String?
    private var keyMonitor: Any?

    private var openObserver: Any?

    init() {
        openObserver = NotificationCenter.default.addObserver(forName: .openReviewFile, object: nil, queue: .main) { [weak self] note in
            guard let url = note.object as? URL else { return }
            MainActor.assumeIsolated { self?.open(url) }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated { self?.handleKey(event) == true ? nil : event }
        }
    }

    static let videoTypes: [UTType] = [.movie, .mpeg4Movie, .quickTimeMovie, .json]

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = Self.videoTypes
        panel.message = tr("Choisis ton export vidéo (ou un fichier .revue.json)", "Choose your video export (or a .revue.json file)")
        panel.prompt = tr("Ouvrir", "Open")
        if panel.runModal() == .OK, let url = panel.url { open(url) }
    }

    func open(_ url: URL) {
        isOpening = true
        Task {
            defer { isOpening = false }
            do {
                let newSession = try await ReviewSession.open(url, settings: AppSettings.shared)
                session?.close()
                session = newSession
            } catch {
                openError = error.localizedDescription
            }
        }
    }

    func closeSession() {
        session?.close()
        session = nil
    }

    /// Raccourcis du lecteur, ignorés pendant la saisie de texte.
    private func handleKey(_ event: NSEvent) -> Bool {
        guard let session, event.window?.isKeyWindow == true, !(event.window is NSPanel) else { return false }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option])
        guard modifiers.isEmpty else { return false }
        if event.window?.firstResponder is NSText {
            if event.keyCode == 53 { // Échap
                session.cancelDraft()
                session.editingNoteID = nil
                return true
            }
            return false
        }
        switch event.keyCode {
        case 49: session.togglePlay()                                   // Espace
        case 123: session.step(by: event.modifierFlags.contains(.shift) ? -10 : -1) // ←
        case 124: session.step(by: event.modifierFlags.contains(.shift) ? 10 : 1)   // →
        case 36, 76: session.beginDraft(focusComposer: true)           // Entrée
        default:
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "n": session.beginDraft(focusComposer: true)
            case "j": session.shuttle(forward: false)
            case "k": session.pause()
            case "l": session.shuttle(forward: true)
            default: return false
            }
        }
        return true
    }
}

struct RootView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let session = state.session {
                ReviewView(session: session)
                    .id(ObjectIdentifier(session))
            } else {
                HomeView()
            }
            if state.isOpening {
                ProgressView().controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black.opacity(0.4))
            }
        }
        // Reconstruit toute l'interface quand la langue change.
        .id(settings.language)
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            state.open(url)
            return true
        }
        .alert(tr("Impossible d'ouvrir", "Can't Open"), isPresented: Binding(
            get: { state.openError != nil }, set: { if !$0 { state.openError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(state.openError ?? "")
        }
    }
}
