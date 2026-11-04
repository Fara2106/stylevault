import Foundation

/// Dove l'avatar realistico può girare: serve molta RAM, un dispositivo vero e
/// iOS 18 (i modelli Core ML sono convertiti per iOS 18: su iOS 17 non si compilano).
enum RealisticSupport {
    /// RAM fisica minima (≈ 8 GB di targhetta, i 7,5 GB tengono conto del margine di sistema).
    static let minimumMemory: UInt64 = 7_500_000_000

    /// Testo per chi non può usarla (resta il collage).
    static let requirement = "La versione realistica richiede iPhone 15 Pro o successivo con iOS 18"

    /// Pura, per i test: ≥ 7,5 GB, non simulatore e iOS 18 o successivo.
    static func isSupported(physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory,
                            isSimulator: Bool, hasIOS18: Bool) -> Bool {
        !isSimulator && hasIOS18 && physicalMemory >= minimumMemory
    }

    /// Il dispositivo in uso.
    static var current: Bool {
        #if targetEnvironment(simulator)
        let simulator = true
        #else
        let simulator = false
        #endif
        let ios18: Bool
        if #available(iOS 18, *) { ios18 = true } else { ios18 = false }
        return isSupported(physicalMemory: ProcessInfo.processInfo.physicalMemory,
                           isSimulator: simulator, hasIOS18: ios18)
    }
}
