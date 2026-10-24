import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appEnumerator: AppEnumerator

    @State private var selectedTab: Tab = .backup

    private enum Tab: Hashable {
        case backup
        case restore
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                BackupListView()
                    .navigationTitle("Backup")
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Backup", systemImage: "arrow.up.doc.fill")
            }
            .tag(Tab.backup)

            NavigationView {
                RestoreView()
                    .navigationTitle("Restore")
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Restore", systemImage: "arrow.down.doc.fill")
            }
            .tag(Tab.restore)
        }
        .overlay {
            if appEnumerator.isLoading && appEnumerator.apps.isEmpty {
                loadingOverlay
            }
        }
        .onboardingCover()
    }

    private var loadingOverlay: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                Text("Reading installed apps…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
