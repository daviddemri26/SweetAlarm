import SwiftUI
import UIKit

struct SpotifyConnectionView: View {
    @EnvironmentObject private var appState: AppState
    @State private var copiedRedirect = false

    var body: some View {
        List {
            Section {
                LabeledContent("State", value: appState.authSummary)
                LabeledContent("Client ID", value: AppConfig.spotifyClientId)
                LabeledContent("Redirect URI", value: AppConfig.spotifyRedirectUri)
                Button {
                    UIPasteboard.general.string = AppConfig.spotifyRedirectUri
                    copiedRedirect = true
                } label: {
                    Label(copiedRedirect ? "Redirect URI Copied" : "Copy Redirect URI", systemImage: "doc.on.doc")
                }
            } header: {
                Text("Spotify")
            } footer: {
                Text("In Spotify Developer Dashboard, the redirect URI must match exactly: morningspotifyalarm://callback. No trailing slash, no localhost URL.")
            }

            Section {
                Button {
                    appState.connectSpotify(prefersEphemeralSession: false)
                } label: {
                    Label(appState.isBusy ? "Connecting..." : "Connect Spotify", systemImage: "person.crop.circle.badge.checkmark")
                }
                .disabled(appState.isBusy)

                Button {
                    appState.disconnectSpotify()
                    appState.connectSpotify(prefersEphemeralSession: true)
                } label: {
                    Label("Reconnect / Switch Account", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(appState.isBusy)

                Button(role: .destructive) {
                    appState.disconnectSpotify()
                } label: {
                    Label("Clear Local Spotify Tokens", systemImage: "xmark.circle")
                }
                .disabled(appState.isBusy)
            } footer: {
                Text("Reconnect / Switch Account uses a private authentication session so iOS does not reuse the wrong Safari Spotify login.")
            }

            if let message = appState.latestMessage {
                Section("Latest Message") {
                    Text(message)
                        .font(.callout)
                }
            }

            Section("Fix redirect_uri error") {
                Text("1. Open Spotify Developer Dashboard.")
                Text("2. Select the app with Client ID \(AppConfig.spotifyClientId).")
                Text("3. Add exactly \(AppConfig.spotifyRedirectUri) to Redirect URIs.")
                Text("4. Save changes, then use Reconnect / Switch Account.")
            }

            Section("Required Scopes") {
                ForEach(AppConfig.spotifyScopes, id: \.self) { scope in
                    Text(scope)
                }
            }
        }
        .navigationTitle("Spotify Connection")
        .task {
            await appState.refreshAuthSummary()
        }
    }
}
