import SwiftUI

struct PlaylistSetupView: View {
    @EnvironmentObject private var appState: AppState
    @State private var input = ""
    @State private var message: String?
    @State private var isFetching = false

    var body: some View {
        List {
            Section {
                TextField("Spotify playlist URL or URI", text: $input, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    savePlaylist(fetchMetadata: false)
                } label: {
                    Label("Save Playlist", systemImage: "square.and.arrow.down")
                }
                Button {
                    savePlaylist(fetchMetadata: true)
                } label: {
                    Label(isFetching ? "Fetching..." : "Save and Fetch Metadata", systemImage: "text.badge.checkmark")
                }
                .disabled(isFetching)
            } header: {
                Text("Playlist")
            } footer: {
                Text("Supported inputs include Spotify playlist URLs, spotify:playlist URIs, and raw playlist IDs. The saved form is spotify:playlist:{id}.")
            }

            Section("Current") {
                LabeledContent("URI", value: appState.configuration.playlistUri)
                if let name = appState.configuration.playlistName {
                    LabeledContent("Name", value: name)
                }
                if let owner = appState.configuration.playlistOwner {
                    LabeledContent("Owner", value: owner)
                }
                if let image = appState.configuration.playlistImageUrl, let url = URL(string: image) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        case .failure:
                            Image(systemName: "photo").font(.largeTitle)
                        case .empty:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(maxHeight: 220)
                }
            }

            if let message {
                Section {
                    Text(message)
                }
            }
        }
        .navigationTitle("Choose Playlist")
        .onAppear {
            input = appState.configuration.playlistUri
        }
    }

    private func savePlaylist(fetchMetadata: Bool) {
        guard let normalized = SpotifyURIParser.normalizePlaylistURI(input) else {
            message = "Playlist URI invalid."
            return
        }

        var configuration = appState.configuration
        configuration.playlistUri = normalized
        message = "Saved \(normalized)."
        appState.save(configuration)

        guard fetchMetadata, let playlistID = SpotifyURIParser.playlistID(from: normalized) else { return }
        isFetching = true
        Task {
            do {
                let token = try await SpotifyAuthService().validAccessToken()
                let metadata = try await SpotifyAPIClient(accessToken: token).playlistMetadata(playlistID: playlistID)
                await MainActor.run {
                    var updated = appState.configuration
                    updated.playlistName = metadata.name
                    updated.playlistOwner = metadata.owner.displayName
                    updated.playlistImageUrl = metadata.images.first?.url
                    appState.save(updated)
                    message = "Playlist metadata saved."
                    isFetching = false
                }
            } catch {
                await MainActor.run {
                    message = error.localizedDescription
                    isFetching = false
                }
            }
        }
    }
}
