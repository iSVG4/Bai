import SwiftUI

struct RestorePointsSection: View {
    let onRestore: (RestorePoint) -> Void

    @EnvironmentObject private var store: RestorePointStore
    @EnvironmentObject private var appEnumerator: AppEnumerator

    private struct AppGroup: Identifiable {
        let bundleID: String
        let appName: String
        let points: [RestorePoint]
        var id: String { bundleID }
    }

    @State private var isOpen = false
    @State private var expanded: Set<String> = []
    @State private var nameRequest: NameRequest?
    @State private var notInstalledPoint: RestorePoint?

    private var groups: [AppGroup] {
        Dictionary(grouping: store.points, by: { $0.bundleID })
            .map { AppGroup(bundleID: $0.key,
                            appName: $0.value.first?.appName ?? $0.key,
                            points: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $isOpen) {
                if groups.isEmpty {
                    Text("No restore points yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                ForEach(groups) { group in
                    DisclosureGroup(isExpanded: expandedBinding(for: group.bundleID)) {
                        ForEach(group.points) { point in
                            pointRow(point)
                        }
                    } label: {
                        header(for: group)
                    }
                }
            } label: {
                HStack {
                    Label("Restore Points", systemImage: "clock.arrow.circlepath")
                    Spacer()
                    if !store.points.isEmpty {
                        Text("\(store.points.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(item: $nameRequest) { request in
                NameSheet(request: request)
            }
            .alert(
                "Not installed",
                isPresented: Binding(
                    get: { notInstalledPoint != nil },
                    set: { if !$0 { notInstalledPoint = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("\u{201C}\(notInstalledPoint?.appName ?? "")\u{201D} isn't installed right now. Install it, then you can roll it back to this point. You can still rename or delete the point.")
            }
        }
        .onAppear { store.reload() }
    }

    private func header(for group: AppGroup) -> some View {
        HStack(spacing: 12) {
            appIcon(for: group.bundleID)
            Text(group.appName)
                .font(.body.weight(.medium))
                .lineLimit(1)
            Spacer()
            Text("\(group.points.count)")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func appIcon(for bundleID: String) -> some View {
        if let icon = appEnumerator.apps.first(where: { $0.bundleID == bundleID })?.icon {
            Image(uiImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.quaternary)
                .frame(width: 34, height: 34)
                .overlay(Image(systemName: "app.dashed").foregroundColor(.secondary))
        }
    }

    private func isInstalled(_ bundleID: String) -> Bool {
        !appEnumerator.hasLoaded || appEnumerator.apps.contains { $0.bundleID == bundleID }
    }

    private func pointRow(_ point: RestorePoint) -> some View {
        let installed = isInstalled(point.bundleID)
        return Button {
            if installed { onRestore(point) } else { notInstalledPoint = point }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(point.displayName)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    let subtitle = installed ? detail(for: point) : "Not installed"
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .opacity(installed ? 1 : 0.45)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { store.delete(point) } label: {
                Label("Delete", systemImage: "trash")
            }
            Button { rename(point) } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button { rename(point) } label: { Label("Rename", systemImage: "pencil") }
            Button(role: .destructive) { store.delete(point) } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func detail(for point: RestorePoint) -> String {
        guard point.name != nil else { return "" }
        return point.date.formatted(date: .abbreviated, time: .shortened)
    }

    private func expandedBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(id) },
            set: { if $0 { expanded.insert(id) } else { expanded.remove(id) } }
        )
    }

    private func rename(_ point: RestorePoint) {
        nameRequest = NameRequest(
            title: "Rename",
            message: "\(point.appName) \u{00B7} leave empty to use the date",
            initialName: point.name ?? ""
        ) { newName in
            store.setName(newName, for: point.url)
        }
    }
}
