// swift-tools-version: 5.10
import PackageDescription

// FASHN VTON v1.5 sul dispositivo: preparazione delle foto, posa con Apple Vision, campionamento con Core ML.
// Sta fuori dal progetto di Style Vault finché la prova sul telefono non convince.
let package = Package(
    name: "FashnKit",
    platforms: [.iOS("18.0"), .macOS(.v14)],
    products: [
        .library(name: "FashnKit", targets: ["FashnKit"]),
        .library(name: "FashnWorn", targets: ["FashnWorn"]),
        .executable(name: "fashn-confronto", targets: ["fashn-confronto"]),
    ],
    dependencies: [
        // Lo scontorno del capo indossato è quello di Style Vault: qui si usa, non si copia
        .package(path: "../../../ios/StyleVaultCore"),
    ],
    targets: [
        .target(name: "FashnKit"),
        .target(name: "FashnWorn", dependencies: ["FashnKit", .product(name: "StyleVaultCore", package: "StyleVaultCore")]),
        .executableTarget(name: "fashn-confronto", dependencies: ["FashnKit", "FashnWorn"]),
        .testTarget(name: "FashnKitTests", dependencies: ["FashnKit"]),
    ]
)
