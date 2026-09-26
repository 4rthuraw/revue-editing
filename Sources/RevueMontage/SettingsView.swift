import SwiftUI
import NotesCore

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("Général", systemImage: "gearshape") }
            CategorySettings()
                .tabItem { Label("Catégories", systemImage: "tag") }
        }
        .frame(width: 520, height: 400)
    }
}

private struct GeneralSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var startText = ""

    private var startIsValid: Bool { Timecode.isValid(startText, rate: FrameRate(60)) }

    var body: some View {
        Form {
            Section("Prise de notes") {
                Toggle("Mettre la vidéo en pause quand j'écris une note", isOn: $settings.pauseWhileTyping)
                Text("Désactivé : la lecture continue et la note garde le timecode du moment où tu as commencé à écrire.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Timeline") {
                LabeledContent("Timecode de départ de la séquence") {
                    HStack {
                        TextField("", text: $startText)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 120)
                            .onSubmit(commitStart)
                        Menu("Préréglages") {
                            Button("01:00:00:00 (Resolve, souvent Premiere)") { startText = "01:00:00:00"; commitStart() }
                            Button("00:00:00:00") { startText = "00:00:00:00"; commitStart() }
                        }
                        .fixedSize()
                    }
                }
                if !startIsValid {
                    Text("Format attendu : HH:MM:SS:FF").font(.caption).foregroundStyle(.red)
                }
                Toggle("Timecode drop-frame (29.97 / 59.94 uniquement)", isOn: $settings.dropFrame)
                Text("À activer seulement si ta timeline est réglée en drop-frame. Sans effet pour 23.976, 24, 25, 50…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { startText = settings.startTimecode }
        .onChange(of: startText) { _, _ in if startIsValid { commitStart() } }
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
            Text("Couleurs limitées à celles qui existent dans Premiere Pro et DaVinci Resolve.")
                .font(.caption)
                .foregroundStyle(.secondary)
            List {
                ForEach($settings.categories) { $category in
                    HStack(spacing: 10) {
                        Circle().fill(category.color.swiftUIColor).frame(width: 10, height: 10)
                        TextField("Nom", text: $category.name)
                            .textFieldStyle(.roundedBorder)
                        Picker("", selection: $category.color) {
                            ForEach(MarkerColor.allCases, id: \.self) { color in
                                Text(color.displayName).tag(color)
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
                        .help("Supprimer la catégorie")
                    }
                }
                .onMove { settings.categories.move(fromOffsets: $0, toOffset: $1) }
            }
            HStack {
                Button {
                    let used = Set(settings.categories.map(\.color))
                    let color = MarkerColor.allCases.first { !used.contains($0) } ?? .cyan
                    settings.categories.append(NoteCategory(name: "Nouvelle catégorie", color: color))
                } label: {
                    Label("Ajouter", systemImage: "plus")
                }
                Spacer()
                Button("Rétablir les catégories par défaut") { settings.resetCategories() }
            }
        }
        .padding(20)
    }
}
