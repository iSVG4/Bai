import Foundation
import ZIPFoundation

enum RestoreError: LocalizedError {
    case noManifest
    case unsafeArchive(path: String)
    case appleAppNotSupported
    case appNotInstalled(bundleID: String)
    case containerNotFound(bundleID: String)
    case unzipFailed(underlying: Error)
    case writeFailed(path: String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .noManifest:
            return "No backup_manifest.json found — this doesn't look like a Bai archive."
        case .unsafeArchive(let path):
            return "This zip contains an unsafe entry (\"\(path)\") and was not restored."
        case .appleAppNotSupported:
            return "Apple system apps aren't supported."
        case .appNotInstalled(let id):
            return "\(id) is not currently installed. Install the app first, then restore."
        case .containerNotFound(let id):
            return "Could not find a data container for \(id). Try launching the app once, then restore."
        case .unzipFailed(let err):
            return "Failed to unzip the backup: \(err.localizedDescription)"
        case .writeFailed(let path, let err):
            return "Could not write to \(path): \(err.localizedDescription)"
        }
    }
}

final class RestoreEngine {
    func restore(
        from zipURL: URL,
        replaceExisting: Bool = false,
        progress: @escaping (Double) -> Void
    ) async throws -> BackupManifest {
        let stagingDir = try await unzip(zipURL, progress: { p in
            progress(p * 0.40)
        })
        defer { try? FileManager.default.removeItem(at: stagingDir) }

        progress(0.40)
        let manifest = try readManifest(from: stagingDir)
        if PathUtils.isExcludedBundleID(manifest.bundleID) {
            throw RestoreError.appleAppNotSupported
        }

        progress(0.45)
        let currentContainerURL = try resolveContainer(for: manifest.bundleID)

        if replaceExisting {
            try await wipeContents(of: currentContainerURL)
        }

        try await copyFiles(
            from: stagingDir,
            to: currentContainerURL,
            progress: { p in progress(0.45 + p * 0.55) }
        )

        progress(1.0)
        return manifest
    }

    private func unzip(
        _ zipURL: URL,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        return try await Task.detached(priority: .userInitiated) {
            let staging = FileManager.default.temporaryDirectory
                .appendingPathComponent("Bai_restore_\(UUID().uuidString)", isDirectory: true)

            try FileManager.default.createDirectory(
                at: staging,
                withIntermediateDirectories: true
            )

            do {
                let archive = try Archive(url: zipURL, accessMode: .read)
                var entryCount = 0.0
                for _ in archive { entryCount += 1 }
                let totalEntries = entryCount
                var completed = 0.0

                for entry in archive {
                    if entry.type == .symlink { throw RestoreError.unsafeArchive(path: entry.path) }
                    let destination = try RestoreEngine.safeDestination(for: entry.path, in: staging)
                    _ = try archive.extract(entry, to: destination)
                    completed += 1
                    progress(completed / max(totalEntries, 1))
                }
            } catch let error as RestoreError {
                try? FileManager.default.removeItem(at: staging)
                throw error
            } catch {
                try? FileManager.default.removeItem(at: staging)
                throw RestoreError.unzipFailed(underlying: error)
            }

            return staging
        }.value
    }

    private static func safeDestination(for entryPath: String, in root: URL) throws -> URL {
        let parts = entryPath.split(separator: "/", omittingEmptySubsequences: true)
        guard !entryPath.hasPrefix("/"),
              !entryPath.contains("\0"),
              !parts.contains("..") else {
            throw RestoreError.unsafeArchive(path: entryPath)
        }

        return root.appendingPathComponent(entryPath)
    }

    private func readManifest(from stagingDir: URL) throws -> BackupManifest {
        do {
            return try BackupManifest.read(fromUnzippedDirectory: stagingDir)
        } catch {
            throw RestoreError.noManifest
        }
    }

    private func resolveContainer(for bundleID: String) throws -> URL {
        if let proxy = LSApplicationWorkspace.default()?
            .applicationProxy(forBundleID: bundleID),
           let containerURL = proxy.dataContainerURL {
            return containerURL
        }

        let containerRoot = URL(fileURLWithPath: "/var/mobile/Containers/Data/Application")
        guard let uuids = try? FileManager.default.contentsOfDirectory(
            at: containerRoot,
            includingPropertiesForKeys: nil
        ) else {
            throw RestoreError.appNotInstalled(bundleID: bundleID)
        }

        for uuidDir in uuids {
            let metadataPlist = uuidDir
                .appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
            guard let plist = NSDictionary(contentsOf: metadataPlist),
                  let id = plist["MCMMetadataIdentifier"] as? String,
                  id == bundleID else { continue }
            return uuidDir
        }

        throw RestoreError.containerNotFound(bundleID: bundleID)
    }

    private func wipeContents(of container: URL) async throws {
        try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let top = try fm.contentsOfDirectory(at: container, includingPropertiesForKeys: [.isDirectoryKey], options: [])
            for item in top {
                if PathUtils.skippedRelativePaths.contains(item.lastPathComponent) { continue }
                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                do {
                    if isDir {
                        for child in try fm.contentsOfDirectory(at: item, includingPropertiesForKeys: nil, options: []) {
                            try fm.removeItem(at: child)
                        }
                    } else {
                        try fm.removeItem(at: item)
                    }
                } catch {
                    throw RestoreError.writeFailed(path: item.path, underlying: error)
                }
            }
        }.value
    }

    private func copyFiles(
        from source: URL,
        to destination: URL,
        progress: @escaping (Double) -> Void
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default

            guard let enumerator = fm.enumerator(
                at: source,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: []
            ) else { return }

            var allFiles: [URL] = []
            for case let fileURL as URL in enumerator {
                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if values?.isRegularFile == true {
                    allFiles.append(fileURL)
                }
            }

            let total = Double(max(allFiles.count, 1))

            for (index, sourceFile) in allFiles.enumerated() {
                let relative = PathUtils.relativePath(of: sourceFile, in: source)

                if relative == "backup_manifest.json" || PathUtils.skippedRelativePaths.contains(relative) {
                    progress(Double(index + 1) / total)
                    continue
                }

                let destFile = destination.appendingPathComponent(relative)
                let destDir  = destFile.deletingLastPathComponent()

                do {
                    try fm.createDirectory(
                        at: destDir,
                        withIntermediateDirectories: true
                    )
                    if fm.fileExists(atPath: destFile.path) {
                        try fm.removeItem(at: destFile)
                    }
                    try fm.copyItem(at: sourceFile, to: destFile)
                } catch {
                    throw RestoreError.writeFailed(path: destFile.path, underlying: error)
                }

                progress(Double(index + 1) / total)
            }
        }.value
    }
}
