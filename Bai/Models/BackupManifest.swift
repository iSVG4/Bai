import Foundation

struct BackupManifest: Codable {
    let bundleID: String
    let appName: String
    let backupDate: Date
    let sourceContainerUUID: String
    let iOSVersion: String

    let appVersion: String?

    let uncompressedSizeBytes: Int64

    private enum CodingKeys: String, CodingKey {
        case bundleID = "bundleId"
        case appName
        case backupDate
        case sourceContainerUUID
        case iOSVersion
        case appVersion
        case uncompressedSizeBytes
    }

    static func make(for app: InstalledApp, uncompressedSizeBytes: Int64) -> BackupManifest {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return BackupManifest(
            bundleID: app.bundleID,
            appName: app.displayName,
            backupDate: Date(),
            sourceContainerUUID: app.containerUUID,
            iOSVersion: "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)",
            appVersion: Bundle.appVersionString(forBundleID: app.bundleID),
            uncompressedSizeBytes: uncompressedSizeBytes
        )
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decode(from data: Data) throws -> BackupManifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupManifest.self, from: data)
    }

    static func read(fromUnzippedDirectory directoryURL: URL) throws -> BackupManifest {
        let manifestURL = directoryURL.appendingPathComponent("backup_manifest.json")
        let data = try Data(contentsOf: manifestURL)
        return try decode(from: data)
    }
}

private extension Bundle {
    static func appVersionString(forBundleID bundleID: String) -> String? {
        guard let proxy = LSApplicationWorkspace.default()?
            .applicationProxy(forBundleID: bundleID) else { return nil }

        guard let shortVersion = proxy.shortVersionString else { return nil }
        if let buildVersion = proxy.bundleVersion {
            return "\(shortVersion) (\(buildVersion))"
        }
        return shortVersion
    }
}
