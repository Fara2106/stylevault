// swift-tools-version: 5.10
import PackageDescription

// FASHN VTON v1.5 sul dispositivo: preparazione delle foto, posa con Apple Vision, campionamento con Core ML.
// Lo usano Style Vault («Vedilo addosso», versione realistica) e l'app di prova in tools/avatar-fashn/bench.
let package = Package(
    name: "FashnKit",
    // Il modello chiede iOS 18: su iOS 17 il pacchetto si compila e la funzione resta spenta
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FashnKit", targets: ["FashnKit"]),
        .library(name: "FashnWorn", targets: ["FashnWorn"]),
        .executable(name: "fashn-confronto", targets: ["fashn-confronto"]),
    ],
    dependencies: [
        // Lo scontorno del capo indossato è quello di Style Vault: qui si usa, non si copia
        .package(path: "../StyleVaultCore"),
    ],
    targets: [
        .target(name: "FashnKit"),
        .target(name: "FashnWorn", dependencies: ["FashnKit", .product(name: "StyleVaultCore", package: "StyleVaultCore")]),
        .executableTarget(name: "fashn-confronto", dependencies: ["FashnKit", "FashnWorn", .product(name: "StyleVaultCore", package: "StyleVaultCore")]),
        .testTarget(name: "FashnKitTests", dependencies: ["FashnKit", "FashnWorn"]),
    ]
)
