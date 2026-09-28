import SwiftUI
import NotesCore

/// Colonne de droite : filtres, liste des notes et champ de saisie.
struct NotesPanel: View {
    @ObservedObject var session: ReviewSession

    var body: some View {
        VStack(spacing: 0) {
            filterTabs
            Theme.border.frame(height: 1)
            notesList
            Composer(session: session)
        }
        .background(Theme.panel)
        .overlay(alignment: .leading) { Theme.border.frame(width: 1) }
    }

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 13) {
                tab(title: "Notes (\(session.review.notes.count))", isSelected: session.categoryFilter == nil) {
                    session.categoryFilter = nil
                }
                ForEach(session.review.categories) { category in
                    let count = session.review.notes.filter { session.category(for: $0).id == category.id }.count
                    tab(title: count > 0 ? "\(category.name) \(count)" : category.name,
                        isSelected: session.categoryFilter == category.id,
                        dot: category.color.swiftUIColor) {
                        session.categoryFilter = session.categoryFilter == category.id ? nil : category.id
                    }
                }
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 42)
    }

    private func tab(title: String, isSelected: Bool, dot: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let dot { Circle().fill(dot).frame(width: 6, height: 6) }
                Text(title)
            }
            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Theme.text : Theme.textMuted)
            .frame(height: 42)
            .overlay(alignment: .bottom) {
                if isSelected { Theme.accent.frame(height: 2) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var notesList: some View {
        let notes = session.visibleNotes
        if notes.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Theme.textMuted)
                Text(session.review.notes.isEmpty ? tr("Aucune note pour l'instant", "No notes yet")
                                                   : tr("Aucune note dans cette catégorie", "No notes in this category"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                if session.review.notes.isEmpty {
                    Text(tr("Appuie sur N pendant la lecture\npour noter une remarque.", "Press N during playback\nto write a note."))
                        .multilineTextAlignment(.center)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                            NoteRow(session: session, note: note, number: number(of: note))
                                .id(note.id)
                        }
                    }
                }
                .onChange(of: session.selectedNoteID) { _, id in
                    guard let id else { return }
                    withAnimation { proxy.scrollTo(id, anchor: .center) }
                }
            }
        }
    }

    /// Numéro dans l'ordre chronologique de toutes les notes, même filtrées.
    private func number(of note: Note) -> Int {
        (session.review.sortedNotes.firstIndex { $0.id == note.id } ?? 0) + 1
    }
}

private struct NoteRow: View {
    @ObservedObject var session: ReviewSession
    let note: Note
    let number: Int
    @State private var hovering = false
    @State private var editText = ""
    @FocusState private var editFocused: Bool

    private var isSelected: Bool { session.selectedNoteID == note.id }
    private var isEditing: Bool { session.editingNoteID == note.id }

    var body: some View {
        let category = session.category(for: note)
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.background)
                .frame(width: 22, height: 22)
                .background(category.color.swiftUIColor, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    TimecodeChip(text: session.timecode(for: note.frame))
                    CategoryTag(category: category)
                    Spacer()
                    if hovering && !isEditing { actions }
                }
                if isEditing {
                    TextField(tr("Remarque", "Note"), text: $editText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.text)
                        .padding(6)
                        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accent))
                        .focused($editFocused)
                        .onSubmit(commitEdit)
                        .onAppear {
                            editText = note.text
                            editFocused = true
                        }
                        .onChange(of: editFocused) { _, focused in if !focused { commitEdit() } }
                } else {
                    Text(note.text)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: 0xD6D6DC))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.disabled)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(isSelected ? Theme.selected : (hovering ? Color(hex: 0x17171C) : .clear))
        .overlay(alignment: .bottom) { Color(hex: 0x1C1C21).frame(height: 1) }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { session.editingNoteID = note.id }
        .simultaneousGesture(TapGesture().onEnded { if !isEditing { session.select(note) } })
        .onHover { hovering = $0 }
        .contextMenu { menu }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button { session.editingNoteID = note.id } label: { Image(systemName: "pencil") }
                .help(tr("Modifier (double-clic)", "Edit (double-click)"))
            Menu {
                menu
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .buttonStyle(.plain)
        .font(.system(size: 11))
        .foregroundStyle(Theme.textSecondary)
    }

    @ViewBuilder
    private var menu: some View {
        Button(tr("Modifier le texte", "Edit Text")) { session.editingNoteID = note.id }
        Menu(tr("Catégorie", "Category")) {
            ForEach(session.review.categories) { category in
                Button(category.name) { session.setCategory(of: note.id, to: category.id) }
            }
        }
        Button(tr("Caler sur l'image affichée", "Move to Current Frame")) { session.moveToCurrentFrame(note.id) }
        Divider()
        Button(tr("Supprimer", "Delete"), role: .destructive) { session.delete(note.id) }
    }

    private func commitEdit() {
        guard isEditing else { return }
        session.updateText(of: note.id, to: editText)
        session.editingNoteID = nil
    }
}

/// Champ de saisie d'une nouvelle note.
struct Composer: View {
    @ObservedObject var session: ReviewSession
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                TimecodeChip(text: session.timecode(for: session.draftFrame ?? session.currentFrame))
                    .opacity(session.draftFrame == nil ? 0.7 : 1)
                Menu {
                    ForEach(session.review.categories) { category in
                        Button {
                            session.draftCategoryID = category.id
                        } label: {
                            Text(category.name)
                        }
                    }
                } label: {
                    CategoryTag(category: session.draftCategory, showsDot: true)
                }
                .menuStyle(.button)
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
                .fixedSize()
                .help(tr("Tab pour changer de catégorie", "Tab to change category"))
                Spacer()
                if session.draftFrame != nil {
                    Button(tr("Annuler", "Cancel")) { session.cancelDraft() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textMuted)
                }
            }

            inputField

            HStack {
                Text(tr("↵ valider · ⇥ catégorie · ⎋ annuler", "↵ add · ⇥ category · ⎋ cancel"))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textMuted)
                Spacer()
                Button(tr("Ajouter", "Add")) { session.submitDraft() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(session.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(10)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(focused ? Theme.accent : Theme.borderStrong))
        .padding(14)
        .background(Color(hex: 0x141419))
        .overlay(alignment: .top) { Theme.border.frame(height: 1) }
        .onChange(of: focused) { _, isFocused in
            if isFocused { session.beginDraft(focusComposer: false) }
        }
        .onChange(of: session.composerFocusRequest) { _, _ in focused = true }
        .onChange(of: session.draftFrame) { _, frame in if frame == nil { focused = false } }
    }

    private var inputField: some View {
        TextField(tr("Écris une remarque…", "Write a note…"), text: $session.draftText, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(Theme.text)
            .lineLimit(1...6)
            .focused($focused)
            .onSubmit { session.submitDraft() }
            .onKeyPress(keys: [.return, .tab], phases: .down, action: handleKey)
    }

    /// ↵ valide (⌥↵ / ⇧↵ = retour à la ligne), ⇥ / ⇧⇥ change de catégorie.
    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let shift = press.modifiers.contains(.shift)
        if press.key == .tab {
            session.cycleDraftCategory(backwards: shift)
            return .handled
        }
        if shift || press.modifiers.contains(.option) { return .ignored }
        session.submitDraft()
        return .handled
    }
}
