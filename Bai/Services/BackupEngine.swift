import Foundation
import ZIPFoundation

final class BackupEngine {
    func backup(
        app: InstalledApp,
        destinationDirectory: URL? = nil,
        fileName: String? = nil,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        return try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default

            guard let enumerator = fm.enumerator(
                at: app.containerURL,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                options: []
            ) else { throw BackupError.containerUnreadable }

            var files: [(url: URL, relative: String)] = []
            var totalBytes: Int64 = 0
            for case let fileURL as URL in enumerator {
                let v = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard v?.isRegularFile == true else { continue }
                let rel = PathUtils.relativePath(of: fileURL, in: app.containerURL)
                if PathUtils.skippedRelativePaths.contains(rel) { continue }
                files.append((fileURL, rel))
                totalBytes += Int64(v?.fileSize ?? 0)
            }
            progress(0.05)

            let zipURL = fm.temporaryDirectory
                .appendingPathComponent("Bai_\(app.displayName.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")).zip")

            let archive = try Archive(url: zipURL, accessMode: .create)

            let manifest = BackupManifest.make(for: app, uncompressedSizeBytes: totalBytes)
            let manifestTmp = fm.temporaryDirectory.appendingPathComponent("backup_manifest.json")
            try manifest.encoded().write(to: manifestTmp)
            defer { try? fm.removeItem(at: manifestTmp) }
            try archive.addEntry(with: "backup_manifest.json", fileURL: manifestTmp, compressionMethod: .deflate)

            let total = Double(max(files.count, 1))
            for (i, file) in files.enumerated() {
                try archive.addEntry(with: file.relative, fileURL: file.url, compressionMethod: .deflate)
                progress(0.05 + Double(i + 1) / total * 0.90)
            }
            progress(0.95)

            let destDir = destinationDirectory
                ?? fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
            let dest = destDir.appendingPathComponent(fileName ?? zipURL.lastPathComponent)
            if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
            try fm.moveItem(at: zipURL, to: dest)
            progress(1.0)

            return dest
        }.value
    }
}

enum BackupError: LocalizedError {
    case containerUnreadable
    case archiveCreationFailed

    var errorDescription: String? {
        switch self {
        case .containerUnreadable:   return "Could not read the app's data container."
        case .archiveCreationFailed: return "Could not create the backup archive."
        }
    }
}
