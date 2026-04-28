import SwiftUI

struct SpotifyConnectionView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section {
                LabeledContent("State", value: appState.authSummary)
                LabeledContent("Client ID", value: AppConfig.spotifyClientId)
                LabeledContent("Redirect URI", value: AppConfig.spotifyRedirectUri)
            } header: {
                Text("Spotify")
            } footer: {
                Text("The app uses Authorization Code with PKCE. No client secret is embedded, and refresh tokens are stored in Keychain.")
            }

            Section {
                Button {
                    appState.connectSpotify()
                } label: {
                    Label("Connect Spotify", systemImage: "person.crop.circle.badge.checkmark")
                }

                Button(role: .destructive) {
                    appState.disconnectSpotify()
                } label: {
                    Label("Disconnect Spotify", systemImage: "xmark.circle")
                }
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
