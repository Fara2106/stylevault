import SwiftUI
import UIKit

/// Banco di prova: carica FASHN VTON, genera un'immagine sugli ingressi catturati sul Mac e misura tempi e memoria.
/// Argomenti: `--units gpu|all|ne|cpu` (di base gpu), `--steps N` (di base 30), `--manuale` per non partire da solo,
/// `--esci` per chiudersi alla fine.
@main
struct FashnBenchApp: App {
    var body: some Scene {
        WindowGroup { BenchView() }
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
