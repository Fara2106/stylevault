// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StyleVaultCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "StyleVaultCore", targets: ["StyleVaultCore"]),
    ],
    targets: [
        .target(name: "StyleVaultCore"),
        .testTarget(
            name: "StyleVaultCoreTests",
            dependencies: ["StyleVaultCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
