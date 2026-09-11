// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Misete",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Misete", targets: ["MiseteApp"])],
    targets: [
        .target(name: "MiseteCore"),
        .target(name: "MiseteReceiver", dependencies: ["MiseteCore"]),
        .executableTarget(name: "MiseteApp", dependencies: ["MiseteCore", "MiseteReceiver"]),
        .testTarget(name: "MiseteCoreTests", dependencies: ["MiseteCore"]),
        .testTarget(name: "MiseteReceiverTests", dependencies: ["MiseteReceiver", "MiseteCore"])
    ],
    swiftLanguageModes: [.v5]
)
