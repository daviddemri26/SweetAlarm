import SwiftUI
import UIKit

struct DiagnosticReportView: View {
    @State private var reportText = "Run the diagnostic to generate a copyable report."
    @State private var isRunning = false
    @State private var copied = false

    var body: some View {
        List {
            Section {
                Button {
                    runDiagnostic()
                } label: {
                    Label(isRunning ? "Running Diagnostic..." : "Run Full Diagnostic", systemImage: "stethoscope")
                }
                .disabled(isRunning)

                Button {
                    openSpotify()
                } label: {
                    Label("Open Spotify to Prepare iPhone", systemImage: "music.note")
                }

                Button {
                    UIPasteboard.general.string = reportText
                    copied = true
                } label: {
                    Label(copied ? "Report Copied" : "Copy Diagnostic Report", systemImage: "doc.on.doc")
                }
                .disabled(reportText.isEmpty || isRunning)
            } footer: {
                Text("This diagnostic may start Spotify playback. It does not include access tokens, refresh tokens, or Authorization headers.")
            }

            Section("Report") {
                Text(reportText)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("Diagnostic Report")
    }

    private func runDiagnostic() {
        isRunning = true
        copied = false
        reportText = "Running diagnostic..."

        Task {
            let result = await DiagnosticReportService().runFullPlaybackDiagnostic()
            await MainActor.run {
                reportText = result.reportText
                isRunning = false
            }
        }
    }

    private func openSpotify() {
        guard let url = URL(string: "spotify://") else { return }
        UIApplication.shared.open(url)
    }
}
