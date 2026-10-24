import SwiftUI

enum RestoreState: Equatable {
    case idle
    case restoring(progress: Double)
    case done(appName: String, date: Date)
    case failed(message: String)
}

struct RestoreView: View {
    let engine = RestoreEngine()
    private let backupEngine = BackupEngine()

    @EnvironmentObject private var store: RestorePointStore
    @EnvironmentObject private var appEnumerator: AppEnumerator

    @State var restoreState: RestoreState = .idle
    @State private var showFilePicker  = false
    @State var showResultSheet = false

    @State private var statusText = "Restoring\u{2026}"

    private enum ImportSheet: Identifiable {
        case picker
        case name(NameRequest)

        var id: String {
            switch self {
            case .picker:      return "picker"
            case .name(let r): return r.id.uuidString
            }
        }
    }

    private enum ImportAlert {
        case error(String)
        case duplicate(url: URL, manifest: BackupManifest)
    }

    @State private var importSheet: ImportSheet?
    @State private var importAlert: ImportAlert?

    @State private var pointToRestore: RestorePoint?
    @State private var showPointConfirm = false

    var body: some View {
        Group {
            VStack(spacing: 0) {
                switch restoreState {
                case .idle:
                    idleContent
                case .restoring(let progress):
                    restoringContent(progress: progress)
                case .done, .failed:

                    idleContent
                }
            }
            .navigationTitle("Restore")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showFilePicker) {
                ZipPicker { url in
                    showFilePicker = false
                    Task { await beginRestore(from: url) }
                }
            }
            .sheet(isPresented: $showResultSheet, onDismiss: {
                restoreState = .idle
            }) {
                resultSheet
            }
            .confirmationDialog(
                "Restore \u{201C}\(pointToRestore?.appName ?? "")\u{201D}?",
                isPresented: $showPointConfirm,
                titleVisibility: .visible
            ) {
                Button("Restore", role: .destructive) {
                    guard let point = pointToRestore else { return }
                    Task { await beginRestorePointRestore(point) }
                }
                Button("Cancel", role: .cancel) { pointToRestore = nil }
            } message: {
                if let p = pointToRestore {
                    Text("The app's current data will be replaced with \u{201C}\(p.displayName)\u{201D} (\(p.date.formatted(date: .abbreviated, time: .shortened))). Close the app before restoring.")
                }
            }
        }
    }

    private var idleContent: some View {
        List {
            Section {
                VStack(spacing: 24) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)

                    VStack(spacing: 8) {
                        Text("Restore a Backup")
                            .font(.title2.bold())
                        Text("Pick a .zip created by Bai.\nThe app must already be installed.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: { showFilePicker = true }) {
                        Label("Choose Backup File", systemImage: "folder")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            .listRowBackground(Color.clear)

            RestorePointsSection(
                onRestore: { point in
                    pointToRestore = point
                    showPointConfirm = true
                }
            )
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { importSheet = .picker } label: {
                        Label("Make Restore Point from Zip\u{2026}", systemImage: "clock.arrow.circlepath")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $importSheet) { sheet in
            switch sheet {
            case .picker:

                ZipPicker(
                    onPick: { url in
                        importSheet = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { handlePicked(url) }
                    },
                    startingDirectory: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                )
            case .name(let request):
                NameSheet(request: request)
            }
        }
        .alert(importAlertTitle, isPresented: importAlertBinding) {
            importAlertButtons
        } message: {
            Text(importAlertMessage)
        }
    }

    private var importAlertBinding: Binding<Bool> {
        Binding(
            get: { importAlert != nil },
            set: { if !$0 { importAlert = nil } }
        )
    }

    private var importAlertTitle: String {
        switch importAlert {
        case .error:     return "Can\u{2019}t Add Restore Point"
        case .duplicate: return "Already a Restore Point"
        case nil:        return ""
        }
    }

    private var importAlertMessage: String {
        switch importAlert {
        case .error(let message):
            return message
        case .duplicate(_, let manifest):
            return "\u{201C}\(manifest.appName)\u{201D} already has a restore point from \(manifest.backupDate.formatted(date: .abbreviated, time: .shortened)). Add it again anyway?"
        case nil:
            return ""
        }
    }

    @ViewBuilder
    private var importAlertButtons: some View {
        switch importAlert {
        case .duplicate(let url, let manifest):
            Button("Add Anyway") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { askName(for: url, manifest: manifest) }
            }
            Button("Cancel", role: .cancel) { try? FileManager.default.removeItem(at: url) }
        default:
            Button("OK", role: .cancel) {}
        }
    }

    private func handlePicked(_ url: URL) {
        guard let manifest = store.manifest(of: url) else {
            try? FileManager.default.removeItem(at: url)
            importAlert = .error(RestoreError.noManifest.localizedDescription)
            return
        }
        if PathUtils.isExcludedBundleID(manifest.bundleID) {
            try? FileManager.default.removeItem(at: url)
            importAlert = .error(RestoreError.appleAppNotSupported.localizedDescription)
            return
        }
        if store.duplicate(of: manifest) != nil {
            importAlert = .duplicate(url: url, manifest: manifest)
            return
        }
        askName(for: url, manifest: manifest)
    }

    private func askName(for url: URL, manifest: BackupManifest) {
        importSheet = .name(NameRequest(
            title: "Name this restore point",
            message: manifest.appName,
            initialName: "Restore Point \(store.manualCount(for: manifest.bundleID) + 1)",
            onCancel: { try? FileManager.default.removeItem(at: url) }
        ) { name in
            do {
                try store.importFile(at: url, manifest: manifest, name: name)
            } catch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    importAlert = .error(error.localizedDescription)
                }
            }
        })
    }

    private func restoringContent(progress: Double) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView(value: progress)
                .progressViewStyle(.circular)
                .scaleEffect(2)
                .tint(.accentColor)

            VStack(spacing: 6) {
                Text(statusText)
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

    private func setProgress(_ value: Double) {
        Task { @MainActor in
            if case .restoring = restoreState { restoreState = .restoring(progress: value) }
        }
    }

    private func beginRestorePointRestore(_ point: RestorePoint) async {
        guard appEnumerator.apps.contains(where: { $0.bundleID == point.bundleID }) else {
            restoreState = .failed(message: RestoreError.appNotInstalled(bundleID: point.bundleID).localizedDescription)
            showResultSheet = true
            return
        }

        restoreState = .restoring(progress: 0)
        statusText = "Restoring\u{2026}"

        do {
            let manifest = try await engine.restore(
                from: point.url,
                replaceExisting: true
            ) { f in setProgress(f) }

            restoreState = .done(appName: manifest.appName, date: manifest.backupDate)
        } catch {
            restoreState = .failed(message: error.localizedDescription)
        }

        showResultSheet = true
    }
}
