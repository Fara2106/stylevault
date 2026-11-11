import SwiftUI
import UIKit

/// App di prova di FASHN VTON. Di base: scegli una foto della persona e una del capo e genera (`TryOnView`).
/// Con `--misura`: genera sugli ingressi catturati sul Mac e misura tempi e memoria. Altri argomenti della misura: `--units gpu|all|ne|cpu` (di base gpu), `--steps N` (di base 30), `--manuale` per non partire da solo,
/// `--esci` per chiudersi alla fine.
@main
struct FashnBenchApp: App {
    var body: some Scene {
        // Con `--misura` resta il banco che misura tempi e memoria sugli ingressi catturati sul Mac
        WindowGroup {
            if CommandLine.arguments.contains("--misura") { BenchView() } else { TryOnView() }
        }
    }
}

struct BenchView: View {
    @State private var runner = BenchRunner()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FASHN VTON v1.5").font(.headline)
            Text(runner.status).font(.subheadline)
            if let image = runner.result {
                Image(uiImage: UIImage(cgImage: image)).resizable().scaledToFit().frame(maxHeight: 360)
            }
            ScrollView { Text(runner.log).font(.system(.caption, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading) }
            Button("Genera") { runner.start() }.buttonStyle(.borderedProminent).disabled(runner.running)
        }
        .padding()
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            if !CommandLine.arguments.contains("--manuale") { runner.start() }
        }
    }
}
