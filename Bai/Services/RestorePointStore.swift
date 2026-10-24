import Foundation
import ZIPFoundation

struct RestorePoint: Identifiable, Hashable {
    let url: URL
    let bundleID: String
    let appName: String
    let appVersion: String?
    let date: Date
    let sizeBytes: Int64

    let name: String?

    var id: String { url.path }

    var displayName: String {
        if let name, !name.isEmpty { return name }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

final class RestorePointStore: ObservableObject {
    @Published private(set) var points: [RestorePoint] = []

    private let scanQueue = DispatchQueue(label: "RestorePointStore.scan", qos: .userInitiated)

    static var rootURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RestorePoints", isDirectory: true)
    }

    func directory(for bundleID: String) -> URL {
        Self.rootURL.appendingPathComponent(bundleID, isDirectory: true)
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }

    func newFileName() -> String {
        "\(Self.timestamp())_manual.zip"
    }

    func reload() {
        scanQueue.async {
            let found = Self.scan()
            DispatchQueue.main.async {
                self.points = found
            }
        }
    }

    private static func scan() -> [RestorePoint] {
        let fm = FileManager.default
        guard let appDirs = try? fm.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)
        else { return [] }

        let names = loadNames()
        var result: [RestorePoint] = []
        for dir in appDirs {
            guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey])
            else { continue }

            for file in files where file.pathExtension.lowercased() == "zip" {
                if file.deletingPathExtension().lastPathComponent.hasSuffix("_auto") { continue }

                guard let manifest = readManifest(in: file) else { continue }
                let size = Int64((try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
                result.append(RestorePoint(
                    url: file,
                    bundleID: manifest.bundleID,
                    appName: manifest.appName,
                    appVersion: manifest.appVersion,
                    date: manifest.backupDate,
                    sizeBytes: size,
                    name: names[key(for: file)]
                ))
            }
        }
        return result.sorted { $0.date > $1.date }
    }

    private static func readManifest(in zipURL: URL) -> BackupManifest? {
        guard let archive = try? Archive(url: zipURL, accessMode: .read),
              let entry = archive["backup_manifest.json"] else { return nil }
        var data = Data()
        do {
            _ = try archive.extract(entry) { data.append($0) }
            return try BackupManifest.decode(from: data)
        } catch {
            return nil
        }
    }

    func manifest(of zipURL: URL) -> BackupManifest? {
        Self.readManifest(in: zipURL)
    }

    private static var namesURL: URL { rootURL.appendingPathComponent("names.json") }

    private static func key(for url: URL) -> String {
        url.deletingLastPathComponent().lastPathComponent + "/" + url.lastPathComponent
    }

    private static func loadNames() -> [String: String] {
        guard let data = try? Data(contentsOf: namesURL),
              let map = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return map
    }

    private static func saveNames(_ map: [String: String]) {
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(map) {
            try? data.write(to: namesURL, options: .atomic)
        }
    }

    func setName(_ name: String?, for url: URL) {
        var map = Self.loadNames()
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty { map.removeValue(forKey: Self.key(for: url)) }
        else               { map[Self.key(for: url)] = trimmed }
        Self.saveNames(map)
        reload()
    }

    func manualCount(for bundleID: String) -> Int {
        points.filter { $0.bundleID == bundleID }.count
    }

    func duplicate(of manifest: BackupManifest) -> RestorePoint? {
        points.first {
            $0.bundleID == manifest.bundleID && abs($0.date.timeIntervalSince(manifest.backupDate)) < 1
        }
    }

    @discardableResult
    func importFile(at url: URL, manifest: BackupManifest, name: String?) throws -> URL {
        let fm = FileManager.default
        let dir = directory(for: manifest.bundleID)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        var dest = dir.appendingPathComponent(newFileName())
        var n = 2
        while fm.fileExists(atPath: dest.path) {
            let base = dest.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: #"-\d+_manual$"#, with: "", options: .regularExpression)
            dest = dir.appendingPathComponent("\(base)-\(n)_manual.zip")
            n += 1
        }

        do { try fm.moveItem(at: url, to: dest) }
        catch { try fm.copyItem(at: url, to: dest) }

        setName(name, for: dest)
        return dest
    }

    func delete(_ point: RestorePoint) {
        try? FileManager.default.removeItem(at: point.url)
        var map = Self.loadNames()
        map.removeValue(forKey: Self.key(for: point.url))
        Self.saveNames(map)
        points.removeAll { $0.id == point.id }
    }
}
