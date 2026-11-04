import Foundation

/// Dove l'avatar realistico può girare: serve molta RAM e un dispositivo vero.
enum RealisticSupport {
    /// RAM fisica minima (≈ 8 GB di targhetta, i 7,5 GB tengono conto del margine di sistema).
    static let minimumMemory: UInt64 = 7_500_000_000

    /// Pura, per i test: ≥ 7,5 GB e non simulatore.
    static func isSupported(physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory,
                            isSimulator: Bool) -> Bool {
        !isSimulator && physicalMemory >= minimumMemory
    }

    /// Il dispositivo in uso.
    static var current: Bool {
        #if targetEnvironment(simulator)
        isSupported(physicalMemory: ProcessInfo.processInfo.physicalMemory, isSimulator: true)
        #else
        isSupported(physicalMemory: ProcessInfo.processInfo.physicalMemory, isSimulator: false)
        #endif
    }
}
