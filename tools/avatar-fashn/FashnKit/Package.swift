// swift-tools-version: 5.10
import PackageDescription

// FASHN VTON v1.5 sul dispositivo: preparazione delle foto, posa con Apple Vision, campionamento con Core ML.
// Sta fuori dal progetto di Style Vault finché la prova sul telefono non convince.
let package = Package(
    name: "FashnKit",
    platforms: [.iOS("18.0"), .macOS(.v14)],
    products: [
        .library(name: "FashnKit", targets: ["FashnKit"]),
        .executable(name: "fashn-confronto", targets: ["fashn-confronto"]),
    ],
    targets: [
        .target(name: "FashnKit"),
        .executableTarget(name: "fashn-confronto", dependencies: ["FashnKit"]),
        .testTarget(name: "FashnKitTests", dependencies: ["FashnKit"]),
    ]
)
