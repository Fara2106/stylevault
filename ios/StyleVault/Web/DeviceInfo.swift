import Foundation
import UIKit

/// Info tecniche che il sito allega alle segnalazioni del Feedback
/// (window.svDeviceInfo, letta da src/services/feedback.js): versione
/// dell'app, di iOS e modello. Nessun dato personale.
struct DeviceInfo: Encodable, Equatable {
    let appVersion: String
    let osVersion: String
    let model: String

    @MainActor static var current: DeviceInfo {
        var system = utsname()
        uname(&system)
        let machine = withUnsafeBytes(of: system.machine) { raw in
            String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
        return DeviceInfo(
            appVersion: appVersion(from: Bundle.main.infoDictionary),
            osVersion: "iOS \(UIDevice.current.systemVersion)",
            model: model(machine: machine, environment: ProcessInfo.processInfo.environment)
        )
    }

    /// "0.1.0 (1)": versione di marketing e numero di build.
    static func appVersion(from info: [String: Any]?) -> String {
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    /// Identificativo del modello ("iPhone18,2"). Nel simulatore uname dice
    /// solo "arm64": il modello simulato sta nell'ambiente.
    static func model(machine: String, environment: [String: String]) -> String {
        if let simulated = environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return "\(simulated) (simulatore)"
        }
        return machine
    }

    /// Script da iniettare prima che parta il sito.
    var script: String {
        let json = (try? JSONEncoder().encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return "window.svDeviceInfo = \(json);"
    }
}
