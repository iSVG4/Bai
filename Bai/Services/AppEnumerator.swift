import Foundation
import UIKit

final class LSApplicationWorkspace {
    private let impl: AnyObject

    private init(_ impl: AnyObject) { self.impl = impl }

    static func `default`() -> LSApplicationWorkspace? {
        let sel = NSSelectorFromString("defaultWorkspace")
        guard let cls = NSClassFromString("LSApplicationWorkspace"),
              (cls as AnyObject).responds(to: sel),
              let obj = (cls as AnyObject).perform(sel)?.takeUnretainedValue()
        else { return nil }
        return LSApplicationWorkspace(obj)
    }

    func allInstalledApplications() -> [LSApplicationProxy] {
        let sel = NSSelectorFromString("allInstalledApplications")
        guard impl.responds(to: sel),
              let list = impl.perform(sel)?.takeUnretainedValue() as? [AnyObject]
        else { return [] }
        return list.map { LSApplicationProxy($0) }
    }

    func applicationProxy(forBundleID id: String) -> LSApplicationProxy? {
        let sel = NSSelectorFromString("applicationProxyForIdentifier:")

        if let cls = NSClassFromString("LSApplicationProxy") as AnyObject?,
           cls.responds(to: sel),
           let obj = cls.perform(sel, with: id)?.takeUnretainedValue() {
            return LSApplicationProxy(obj)
        }
        return allInstalledApplications().first { $0.bundleIdentifier == id }
    }
}

final class LSApplicationProxy {
    private let impl: AnyObject
    init(_ impl: AnyObject) { self.impl = impl }

    private func str(_ name: String) -> String? {
        let s = NSSelectorFromString(name)
        guard impl.responds(to: s) else { return nil }
        return impl.perform(s)?.takeUnretainedValue() as? String
    }
    private func url(_ name: String) -> URL? {
        let s = NSSelectorFromString(name)
        guard impl.responds(to: s) else { return nil }
        return impl.perform(s)?.takeUnretainedValue() as? URL
    }

    var bundleIdentifier:   String? { str("bundleIdentifier") }
    var localizedName:      String? { str("localizedName") }
    var dataContainerURL:   URL?    { url("dataContainerURL") }
    var bundleURL:          URL?    { url("bundleURL") }
    var shortVersionString: String? { str("shortVersionString") }
    var bundleVersion:      String? { str("bundleVersion") }
}

@MainActor
final class AppEnumerator: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var isLoading: Bool = false

    @Published var hasLoaded: Bool = false

    func loadInstalledApps() {
        guard !isLoading else { return }
        isLoading = true
        Task.detached(priority: .userInitiated) { [weak self] in
            let loaded = Self.enumerate()
            await MainActor.run {
                self?.apps = loaded
                self?.isLoading = false
                self?.hasLoaded = true
            }
        }
    }

    private nonisolated static func enumerate() -> [InstalledApp] {
        var raw: [InstalledApp] = []
        if let ws = LSApplicationWorkspace.default() {
            raw = enumerateViaWorkspace(ws)
        }
        if raw.isEmpty { raw = enumerateViaPlist() }
        return raw.filter { !PathUtils.isExcludedBundleID($0.bundleID) }.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private nonisolated static func enumerateViaWorkspace(_ ws: LSApplicationWorkspace) -> [InstalledApp] {
        ws.allInstalledApplications().compactMap { proxy in
            guard let bundleID = proxy.bundleIdentifier,
                  !bundleID.isEmpty,
                  let containerURL = proxy.dataContainerURL
            else { return nil }

            let uuid = containerURL.lastPathComponent
            let name = proxy.localizedName
                    ?? displayName(fromBundleURL: proxy.bundleURL)
                    ?? bundleID
            let icon = loadIcon(from: proxy.bundleURL)
            return InstalledApp(bundleID: bundleID, displayName: name, containerUUID: uuid, icon: icon)
        }
    }

    private nonisolated static var mapPlistPath: String {
        "/var/mobile/Library/MobileInstallation/LastLaunchServicesMap.plist"
    }

    private nonisolated static func enumerateViaPlist() -> [InstalledApp] {
        guard let map = NSDictionary(contentsOfFile: mapPlistPath) else { return [] }

        var result: [InstalledApp] = []
        for section in ["User", "System", "Internal"] {
            guard let dict = map[section] as? [String: Any] else { continue }
            for (bundleID, value) in dict {
                guard let info = value as? [String: Any],
                      let containerPath = info["Container"] as? String
                else { continue }

                let uuid = URL(fileURLWithPath: containerPath).lastPathComponent
                let bundleURL = (info["Path"] as? String).map { URL(fileURLWithPath: $0) }
                let name = displayName(fromBundleURL: bundleURL) ?? bundleID
                let icon = loadIcon(from: bundleURL)
                result.append(InstalledApp(bundleID: bundleID, displayName: name,
                                           containerUUID: uuid, icon: icon))
            }
        }
        return result
    }

    private nonisolated static func displayName(fromBundleURL url: URL?) -> String? {
        guard let url else { return nil }
        guard let dict = NSDictionary(contentsOf: url.appendingPathComponent("Info.plist"))
        else { return nil }
        return (dict["CFBundleDisplayName"] as? String) ?? (dict["CFBundleName"] as? String)
    }

    private nonisolated static func loadIcon(from bundleURL: URL?) -> UIImage? {
        guard let bundleURL,
              let dict = NSDictionary(contentsOf: bundleURL.appendingPathComponent("Info.plist"))
        else { return nil }

        var baseNames: [String] = []
        if let icons   = dict["CFBundleIcons"]   as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files   = primary["CFBundleIconFiles"] as? [String] {
            baseNames = files
        } else if let files = dict["CFBundleIconFiles"] as? [String] {
            baseNames = files
        }

        for base in baseNames.reversed() {
            for suffix in ["@3x.png", "@2x.png", ".png", ""] {
                let candidate = bundleURL.appendingPathComponent(base + suffix)
                if let img = UIImage(contentsOfFile: candidate.path) { return img }
            }
        }
        return nil
    }
}
