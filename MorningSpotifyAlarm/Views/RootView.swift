import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "alarm")
            }

            NavigationStack {
                ReliabilityChecklistView()
            }
            .tabItem {
                Label("Checklist", systemImage: "checklist")
            }

            NavigationStack {
                LogsView()
            }
            .tabItem {
                Label("Logs", systemImage: "list.bullet.rectangle")
            }
        }
        .tint(.green)
    }
}
