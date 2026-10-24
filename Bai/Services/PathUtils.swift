import Foundation

enum PathUtils {
    static let skippedRelativePaths: Set<String> = [
        ".com.apple.mobile_container_manager.metadata.plist"
    ]

    static func isExcludedBundleID(_ bundleID: String) -> Bool {
        bundleID.lowercased().hasPrefix("com.apple.")
    }

    static func relativePath(of file: URL, in base: URL) -> String {
        func strip(_ p: String) -> String { p.hasPrefix("/private/") ? String(p.dropFirst(8)) : p }
        let b = strip(base.standardizedFileURL.path)
        let f = strip(file.standardizedFileURL.path)
        if f.hasPrefix(b + "/") { return String(f.dropFirst(b.count + 1)) }
        return file.lastPathComponent
    }
}
