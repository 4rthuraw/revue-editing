// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "RevueMontage",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "NotesCore"),
        .executableTarget(
            name: "RevueMontage",
            dependencies: ["NotesCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(name: "NotesCoreChecks", dependencies: ["NotesCore"]),
    ]
)
