import SwiftUI

private enum BackupState: Equatable {
    case idle
    case backingUp(appName: String, progress: Double)
    case done(url: URL, appName: String)
    case failed(message: String)
}

struct BackupListView: View {
    @EnvironmentObject private var appEnumerator: AppEnumerator
    @EnvironmentObject private var restorePoints: RestorePointStore
    private let engine = BackupEngine()

    @State private var backupState: BackupState = .idle
    @State private var showShare    = false
    @State private var showSaved    = false
    @State private var savedAppName = ""
    @State private var nameRequest: NameRequest?
    @State private var shareURL: URL?
    @State private var searchText = ""

    @State private var sizesCache: [String: String] = [:]

    var body: some View {
        Group {
            switch backupState {
            case .idle, .done, .failed:
                appList
            case .backingUp(let appName, let progress):
                backingUpView(appName: appName, progress: progress)
            }
        }

        .sheet(isPresented: $showShare, onDismiss: { backupState = .idle }) {
            if let url = shareURL {
                ShareSheet(url: url)
            }
        }

        .sheet(item: $nameRequest) { request in
            NameSheet(request: request)
        }

        .alert("Restore Point Saved", isPresented: $showSaved) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\u{201C}\(savedAppName)\u{201D} can now be rolled back from the Restore tab.")
        }

        .alert("Backup Failed", isPresented: failedBinding) {
            Button("OK", role: .cancel) { backupState = .idle }
        } message: {
            if case .failed(let msg) = backupState { Text(msg) }
        }
    }

    private var filteredApps: [InstalledApp] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return appEnumerator.apps }
        return appEnumerator.apps.filter {
            $0.displayName.localizedCaseInsensitiveContains(q) ||
            $0.bundleID.localizedCaseInsensitiveContains(q)
        }
    }

    private var appList: some View {
        List(filteredApps) { app in
            AppRowView(app: app, sizeText: sizesCache[app.bundleID])
                .contentShape(Rectangle())
                .onTapGesture {
                    Task { await beginBackup(app: app, asRestorePoint: false) }
                }

                .contextMenu {
                    Button {
                        askRestorePointName(for: app)
                    } label: {
                        Label("Save as Restore Point\u{2026}", systemImage: "clock.arrow.circlepath")
                    }
                }
                .onAppear { loadSize(for: app) }
        }
        .listStyle(.plain)
        .searchable(text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search apps")
        .disableAutocorrection(true)
        .textInputAutocapitalization(.never)
        .overlay {
            if !appEnumerator.apps.isEmpty && filteredApps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 44)).foregroundColor(.secondary)
                    Text("No Results").font(.headline)
                    Text("No apps match \u{201C}\(searchText)\u{201D}.")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .padding()
            }
            if appEnumerator.apps.isEmpty && !appEnumerator.isLoading {
                VStack(spacing: 8) {
                    Image(systemName: "app.dashed").font(.system(size: 44)).foregroundColor(.secondary)
                    Text("No Apps Found").font(.headline)
                    Text("Make sure TrollStore is installed and the app has the required entitlements.")
                        .font(.subheadline).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }

    private func backingUpView(appName: String, progress: Double) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView(value: progress)
                .progressViewStyle(.circular)
                .scaleEffect(2)
                .tint(.accentColor)

            VStack(spacing: 6) {
                Text("Backing up \u{201C}\(appName)\u{201D}…")
                    .font(.headline)
                Text("\(Int(progress * 100)) %")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    private func askRestorePointName(for app: InstalledApp) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            nameRequest = NameRequest(
                title: "Name this restore point",
                message: app.displayName,
                initialName: "Restore Point \(restorePoints.manualCount(for: app.bundleID) + 1)"
            ) { name in
                Task { await beginBackup(app: app, asRestorePoint: true, name: name) }
            }
        }
    }

    private var failedBinding: Binding<Bool> {
        Binding(
            get: { if case .failed = backupState { return true }; return false },
            set: { if !$0 { backupState = .idle } }
        )
    }

    private func loadSize(for app: InstalledApp) {
        guard sizesCache[app.bundleID] == nil else { return }
        Task.detached(priority: .background) {
            let text = app.dataSizeFormatted()
            await MainActor.run { sizesCache[app.bundleID] = text }
        }
    }

    private func beginBackup(app: InstalledApp, asRestorePoint: Bool, name: String? = nil) async {
        backupState = .backingUp(appName: app.displayName, progress: 0)

        do {
            let url = try await engine.backup(
                app: app,
                destinationDirectory: asRestorePoint ? restorePoints.directory(for: app.bundleID) : nil,
                fileName: asRestorePoint ? restorePoints.newFileName() : nil
            ) { fraction in
                Task { @MainActor in

                    if case .backingUp(let name, _) = backupState {
                        backupState = .backingUp(appName: name, progress: fraction)
                    }
                }
            }

            if asRestorePoint {
                restorePoints.setName(name, for: url)
                backupState  = .idle
                savedAppName = app.displayName
                showSaved    = true
            } else {
                backupState = .done(url: url, appName: app.displayName)
                shareURL    = url
                showShare   = true
            }

        } catch {
            backupState = .failed(message: error.localizedDescription)
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
