import AVFoundation
import AppKit
import Combine
import NotesCore

/// État d'une revue ouverte : lecteur, notes, brouillon en cours, sauvegarde et export.
@MainActor
final class ReviewSession: ObservableObject {
    @Published private(set) var review: Review
    @Published private(set) var currentFrame = 0
    @Published private(set) var isPlaying = false
    @Published var selectedNoteID: UUID?
    @Published var categoryFilter: UUID?
    @Published var editingNoteID: UUID?

    // Brouillon de note
    @Published private(set) var draftFrame: Int?
    @Published var draftText = ""
    @Published var draftCategoryID: UUID
    /// Incrémenté pour demander au champ de saisie de prendre le focus.
    @Published private(set) var composerFocusRequest = 0

    @Published var banner: Banner?
    @Published var errorMessage: String?

    let player: AVPlayer
    let settings: AppSettings
    private var timeObserver: Any?
    private var cancellables: Set<AnyCancellable> = []
    private var resumeAfterDraft = false

    struct Banner: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let fileURL: URL?
    }

    var rate: FrameRate { review.frameRate }

    private init(review: Review, settings: AppSettings) {
        self.review = review
        self.settings = settings
        self.player = AVPlayer(url: review.videoURL)
        self.draftCategoryID = review.categories.first?.id ?? NoteCategory.defaults[0].id
        player.actionAtItemEnd = .pause

        let interval = CMTime(value: Int64(rate.denominator), timescale: CMTimeScale(rate.numerator * 2))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated { self?.syncFromPlayer(time) }
        }
        player.publisher(for: \.timeControlStatus)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self else { return }
                self.isPlaying = status != .paused
                // Le dernier rappel périodique peut précéder l'image réellement affichée à l'arrêt.
                if status == .paused { self.syncFromPlayer(self.player.currentTime()) }
            }
            .store(in: &cancellables)
        settings.$categories
            .receive(on: RunLoop.main)
            .sink { [weak self] categories in self?.mergeCategories(categories) }
            .store(in: &cancellables)
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
    }

    // MARK: - Ouverture

    enum OpenError: LocalizedError {
        case noVideoTrack
        case missingVideo(String)
        case unreadableReview

        var errorDescription: String? {
            switch self {
            case .noVideoTrack:
                tr("Ce fichier ne contient pas de piste vidéo.", "This file has no video track.")
            case .missingVideo(let path):
                tr("La vidéo de cette revue est introuvable :\n\(path)", "The video for this review can't be found:\n\(path)")
            case .unreadableReview:
                tr("Ce fichier de revue est illisible.", "This review file can't be read.")
            }
        }
    }

    /// Ouvre une vidéo (ou un fichier .revue.json) et reprend la revue existante si elle a déjà été commencée.
    static func open(_ url: URL, settings: AppSettings) async throws -> ReviewSession {
        var videoURL = url
        var existing: Review?
        if url.lastPathComponent.hasSuffix(".revue.json") {
            guard let data = try? Data(contentsOf: url), let decoded = try? Review.decode(data) else {
                throw OpenError.unreadableReview
            }
            // La revue est rangée à côté de la vidéo : on la cherche là en priorité.
            let sibling = url.deletingPathExtension().deletingPathExtension()
            videoURL = FileManager.default.fileExists(atPath: sibling.path) ? sibling : decoded.videoURL
            existing = decoded
        } else {
            let storage = Review.storageURL(forVideo: url)
            if let data = try? Data(contentsOf: storage) { existing = try? Review.decode(data) }
        }
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            throw OpenError.missingVideo(videoURL.path)
        }

        let asset = AVURLAsset(url: videoURL)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw OpenError.noVideoTrack
        }
        let measured = try await track.load(.nominalFrameRate)
        let duration = try await asset.load(.duration)
        let rate = FrameRate.detect(fromMeasured: Double(measured > 0 ? measured : 25))
        let durationFrames = rate.frame(atSeconds: duration.seconds.isFinite ? duration.seconds : 0)

        var review = existing ?? Review(videoPath: videoURL.path, frameRate: rate, durationFrames: durationFrames,
                                        categories: settings.categories)
        review.videoPath = videoURL.path
        review.frameRate = rate
        review.durationFrames = durationFrames

        let session = ReviewSession(review: review, settings: settings)
        settings.noteRecent(videoURL)
        session.save()
        return session
    }

    func close() {
        player.pause()
        save()
    }

    // MARK: - Lecture

    private func syncFromPlayer(_ time: CMTime) {
        guard time.isNumeric else { return }
        let frame = min(rate.frame(atSeconds: time.seconds), max(review.durationFrames - 1, 0))
        if frame != currentFrame { currentFrame = frame }
    }

    func togglePlay() {
        if isPlaying {
            player.pause()
        } else {
            if currentFrame >= review.durationFrames - 1 { seek(toFrame: 0) }
            player.rate = 1
        }
    }

    func pause() { player.pause() }

    func play(rate playbackRate: Float) {
        if playbackRate < 0, player.currentItem?.canPlayReverse != true {
            player.pause()
            seek(toFrame: currentFrame - self.rate.timecodeBase)
            return
        }
        player.rate = playbackRate
    }

    /// J/K/L : chaque appui sur L (ou J) accélère.
    func shuttle(forward: Bool) {
        let current = player.rate
        if forward {
            play(rate: current >= 1 ? min(current * 2, 8) : 1)
        } else {
            play(rate: current <= -1 ? max(current * 2, -8) : -1)
        }
    }

    func step(by frames: Int) {
        player.pause()
        seek(toFrame: currentFrame + frames)
    }

    func seek(toFrame frame: Int) {
        let clamped = min(max(frame, 0), max(review.durationFrames - 1, 0))
        currentFrame = clamped
        // On vise le milieu de l'image pour éviter d'afficher la précédente à cause des arrondis.
        let time = CMTime(value: Int64(clamped * rate.denominator * 2 + rate.denominator),
                          timescale: CMTimeScale(rate.numerator * 2))
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func timecode(for frame: Int) -> String {
        let dropFrame = settings.dropFrame && rate.supportsDropFrame
        let start = (try? Timecode.frame(from: settings.startTimecode, rate: rate, dropFrame: dropFrame)) ?? 0
        return Timecode.string(fromFrame: start + frame, rate: rate, dropFrame: dropFrame)
    }

    // MARK: - Notes

    var visibleNotes: [Note] {
        let sorted = review.sortedNotes
        guard let categoryFilter else { return sorted }
        return sorted.filter { review.category(for: $0).id == categoryFilter }
    }

    func category(for note: Note) -> NoteCategory { review.category(for: note) }

    var draftCategory: NoteCategory {
        review.categories.first { $0.id == draftCategoryID } ?? review.categories.first ?? NoteCategory.defaults[0]
    }

    /// Démarre une note au timecode actuel (touche N ou clic dans le champ).
    func beginDraft(focusComposer: Bool) {
        if draftFrame == nil {
            syncFromPlayer(player.currentTime())
            draftFrame = currentFrame
            resumeAfterDraft = false
            if settings.pauseWhileTyping && isPlaying {
                resumeAfterDraft = true
                player.pause()
                seek(toFrame: currentFrame)
            }
        }
        if focusComposer { composerFocusRequest += 1 }
    }

    func cycleDraftCategory(backwards: Bool = false) {
        let categories = review.categories
        guard !categories.isEmpty else { return }
        let index = categories.firstIndex { $0.id == draftCategoryID } ?? 0
        let next = (index + (backwards ? categories.count - 1 : 1)) % categories.count
        draftCategoryID = categories[next].id
    }

    func submitDraft() {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { cancelDraft(); return }
        let note = Note(frame: draftFrame ?? currentFrame, text: text, categoryID: draftCategory.id)
        review.notes.append(note)
        selectedNoteID = note.id
        save()
        finishDraft()
    }

    func cancelDraft() {
        finishDraft()
    }

    private func finishDraft() {
        draftText = ""
        draftFrame = nil
        if resumeAfterDraft { player.rate = 1 }
        resumeAfterDraft = false
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    func select(_ note: Note) {
        selectedNoteID = note.id
        player.pause()
        seek(toFrame: note.frame)
    }

    func updateText(of noteID: UUID, to text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = review.notes.firstIndex(where: { $0.id == noteID }) else { return }
        if trimmed.isEmpty { return }
        review.notes[index].text = trimmed
        save()
    }

    func setCategory(of noteID: UUID, to categoryID: UUID) {
        guard let index = review.notes.firstIndex(where: { $0.id == noteID }) else { return }
        review.notes[index].categoryID = categoryID
        save()
    }

    /// Recale une note sur l'image affichée.
    func moveToCurrentFrame(_ noteID: UUID) {
        guard let index = review.notes.firstIndex(where: { $0.id == noteID }) else { return }
        review.notes[index].frame = currentFrame
        save()
    }

    func delete(_ noteID: UUID) {
        review.notes.removeAll { $0.id == noteID }
        if selectedNoteID == noteID { selectedNoteID = nil }
        save()
    }

    /// Répercute les réglages de catégories sur la revue, sans perdre celles encore utilisées.
    private func mergeCategories(_ categories: [NoteCategory]) {
        let usedIDs = Set(review.notes.map(\.categoryID))
        var merged = categories
        for old in review.categories where usedIDs.contains(old.id) && !categories.contains(where: { $0.id == old.id }) {
            merged.append(old)
        }
        guard merged != review.categories else { return }
        review.categories = merged
        if !merged.contains(where: { $0.id == draftCategoryID }) { draftCategoryID = merged.first?.id ?? draftCategoryID }
        if let categoryFilter, !merged.contains(where: { $0.id == categoryFilter }) { self.categoryFilter = nil }
        save()
    }

    // MARK: - Sauvegarde et export

    func save() {
        do {
            try review.encoded().write(to: Review.storageURL(forVideo: review.videoURL), options: .atomic)
        } catch {
            errorMessage = tr("Impossible d'enregistrer la revue à côté de la vidéo : ", "Couldn't save the review next to the video: ")
                + error.localizedDescription
        }
    }

    enum ExportTarget { case resolve, premiere }

    func export(_ target: ExportTarget) {
        let folder = review.videoURL.deletingLastPathComponent()
        do {
            let url: URL
            switch target {
            case .resolve:
                let edl = try ResolveEDLExporter.export(review, settings: settings.exportSettings)
                url = folder.appendingPathComponent("\(review.title) – \(tr("marqueurs Resolve", "Resolve markers")).edl")
                try Data(edl.utf8).write(to: url, options: .atomic)
            case .premiere:
                let data = try PremiereJSONExporter.export(review, settings: settings.exportSettings)
                url = folder.appendingPathComponent("\(review.title) – \(tr("marqueurs Premiere", "Premiere markers")).json")
                try data.write(to: url, options: .atomic)
            }
            let count = review.notes.count
            let app = target == .resolve ? "Resolve" : "Premiere"
            let plural = count > 1 ? "s" : ""
            banner = Banner(message: tr("\(count) marqueur\(plural) exporté\(plural) pour \(app)",
                                        "\(count) marker\(plural) exported for \(app)"), fileURL: url)
        } catch let error as ExportError {
            errorMessage = error.localizedMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
