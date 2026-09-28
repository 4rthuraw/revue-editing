import SwiftUI
import NotesCore

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label(tr("Général", "General"), systemImage: "gearshape") }
            CategorySettings()
                .tabItem { Label(tr("Catégories", "Categories"), systemImage: "tag") }
        }
        .frame(width: 520, height: 560)
        // Reconstruit les onglets quand la langue change.
        .id(settings.language)
    }
}

private struct GeneralSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var startText = ""
    @State private var installingPanel = false
    @State private var panelMessage: String?

    private var startIsValid: Bool { Timecode.isValid(startText, rate: FrameRate(60)) }

    var body: some View {
        Form {
            Section(tr("Langue", "Language")) {
                Picker(tr("Langue de l'interface", "Interface language"), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
            }
            Section(tr("Prise de notes", "Note taking")) {
                Toggle(tr("Mettre la vidéo en pause quand j'écris une note", "Pause the video while I write a note"),
                       isOn: $settings.pauseWhileTyping)
                Text(tr("Désactivé : la lecture continue et la note garde le timecode du moment où tu as commencé à écrire.",
                        "Off: playback continues and the note keeps the timecode from when you started typing."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(tr("Timeline", "Timeline")) {
                LabeledContent(tr("Timecode de départ de la séquence", "Sequence start timecode")) {
                    HStack {
                        TextField("", text: $startText)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 120)
                            .onSubmit(commitStart)
                        Menu(tr("Préréglages", "Presets")) {
                            Button(tr("01:00:00:00 (Resolve, souvent Premiere)", "01:00:00:00 (Resolve, often Premiere)")) { startText = "01:00:00:00"; commitStart() }
                            Button("00:00:00:00") { startText = "00:00:00:00"; commitStart() }
                        }
                        .fixedSize()
                    }
                }
                if !startIsValid {
                    Text(tr("Format attendu : HH:MM:SS:FF", "Expected format: HH:MM:SS:FF")).font(.caption).foregroundStyle(.red)
                }
                Toggle(tr("Timecode drop-frame (29.97 / 59.94 uniquement)", "Drop-frame timecode (29.97 / 59.94 only)"), isOn: $settings.dropFrame)
                Text(tr("À activer seulement si ta timeline est réglée en drop-frame. Sans effet pour 23.976, 24, 25, 50…",
                        "Only turn on if your timeline uses drop-frame. No effect at 23.976, 24, 25, 50…"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Premiere Pro") {
                LabeledContent(tr("Panneau « Importer les notes »", "“Import Notes” panel")) {
                    Button(installingPanel ? tr("Installation…", "Installing…") : tr("Installer", "Install")) {
                        installPanel()
                    }
                    .disabled(installingPanel)
                }
                Text(panelMessage ?? tr("Nécessaire pour importer les notes dans Premiere Pro (version 25.6 ou plus récente). À refaire après une mise à jour de Revue Montage.",
                                        "Needed to import notes into Premiere Pro (version 25.6 or later). Run it again after updating Revue Montage."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .onAppear { startText = settings.startTimecode }
        .onChange(of: startText) { _, _ in if startIsValid { commitStart() } }
    }

    private func installPanel() {
        installingPanel = true
        Task {
            let outcome = await PremierePanelInstaller.install()
            installingPanel = false
            switch outcome {
            case .installed:
                panelMessage = tr("✓ Panneau installé. Redémarre Premiere Pro, puis ouvre-le depuis Fenêtre → UXP Plugins.",
                                  "✓ Panel installed. Restart Premiere Pro, then open it from Window → UXP Plugins.")
            case .handedToCreativeCloud:
                panelMessage = tr("Creative Cloud a pris le relais : suis ses instructions, puis redémarre Premiere Pro.",
                                  "Creative Cloud took over: follow its steps, then restart Premiere Pro.")
            case .failed(let reason):
                panelMessage = reason
            }
        }
    }

    private func commitStart() {
        guard startIsValid else { return }
        settings.startTimecode = startText.replacingOccurrences(of: ";", with: ":")
    }
}

private struct CategorySettings: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("Couleurs limitées à celles qui existent dans Premiere Pro et DaVinci Resolve.",
                     "Colors are limited to those available in both Premiere Pro and DaVinci Resolve."))
                .font(.caption)
                .foregroundStyle(.secondary)
            List {
                ForEach($settings.categories) { $category in
                    HStack(spacing: 10) {
                        Circle().fill(category.color.swiftUIColor).frame(width: 10, height: 10)
                        TextField(tr("Nom", "Name"), text: $category.name)
                            .textFieldStyle(.roundedBorder)
                        Picker("", selection: $category.color) {
                            ForEach(MarkerColor.allCases, id: \.self) { color in
                                Text(color.localizedName).tag(color)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 100)
                        Button {
                            settings.categories.removeAll { $0.id == category.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(settings.categories.count <= 1)
                        .help(tr("Supprimer la catégorie", "Delete category"))
                    }
                }
                .onMove { settings.categories.move(fromOffsets: $0, toOffset: $1) }
            }
            HStack {
                Button {
                    let used = Set(settings.categories.map(\.color))
                    let color = MarkerColor.allCases.first { !used.contains($0) } ?? .cyan
                    settings.categories.append(NoteCategory(name: tr("Nouvelle catégorie", "New category"), color: color))
                } label: {
                    Label(tr("Ajouter", "Add"), systemImage: "plus")
                }
                Spacer()
                Button(tr("Rétablir les catégories par défaut", "Restore default categories")) { settings.resetCategories() }
            }
        }
        .padding(20)
    }
}
