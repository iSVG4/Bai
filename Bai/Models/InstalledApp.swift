import Foundation
import UIKit

struct InstalledApp: Identifiable, Hashable {
    let bundleID: String

    let displayName: String

    let containerUUID: String

    var icon: UIImage?

    var id: String { bundleID }

    var containerURL: URL {
        URL(fileURLWithPath: "/var/mobile/Containers/Data/Application/\(containerUUID)")
    }

    func dataSizeBytes() -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: containerURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            total += Int64(size)
        }
        return total
    }

    func dataSizeFormatted() -> String {
        let bytes = dataSizeBytes()
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleID)
    }

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.bundleID == rhs.bundleID
    }
}
