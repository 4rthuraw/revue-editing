import AppKit

/// Installe dans Premiere Pro le panneau « Importer les notes », embarqué dans l'app
/// (Contents/Resources/ImporterLesNotes.ccx, ajouté par scripts/build-app.sh).
enum PremierePanelInstaller {
    enum Outcome {
        case installed
        case handedToCreativeCloud
        case failed(String)
    }

    /// Installateur d'Adobe fourni avec Creative Cloud (même outil que premiere-panel/install.sh).
    private static let upiaPath = "/Library/Application Support/Adobe/Adobe Desktop Common/RemoteComponents/UPI/UnifiedPluginInstallerAgent/UnifiedPluginInstallerAgent.app/Contents/MacOS/UnifiedPluginInstallerAgent"

    static var packageURL: URL? {
        Bundle.main.url(forResource: "ImporterLesNotes", withExtension: "ccx")
    }

    static func install() async -> Outcome {
        guard let package = packageURL else {
            return .failed(tr("Le panneau n'est pas inclus dans cette version de l'app : construis-la avec scripts/build-app.sh, ou lance premiere-panel/install.sh.",
                              "The panel isn't bundled with this build of the app: build it with scripts/build-app.sh, or run premiere-panel/install.sh."))
        }
        var installerOutput = ""
        if FileManager.default.isExecutableFile(atPath: upiaPath) {
            let result = await run(upiaPath, arguments: ["--install", package.path])
            if result.status == 0 { return .installed }
            installerOutput = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Plan B : ouvrir le .ccx, comme un double-clic ; Creative Cloud prend le relais.
        if NSWorkspace.shared.open(package) { return .handedToCreativeCloud }
        let reason = tr("Impossible d'installer le panneau. Creative Cloud est-il installé ?",
                        "Couldn't install the panel. Is Creative Cloud installed?")
        return .failed(installerOutput.isEmpty ? reason : "\(reason)\n\(installerOutput)")
    }

    private static func run(_ path: String, arguments: [String]) async -> (status: Int32, output: String) {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            process.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: (process.terminationStatus, String(decoding: data, as: UTF8.self)))
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: (-1, error.localizedDescription))
            }
        }
    }
}
