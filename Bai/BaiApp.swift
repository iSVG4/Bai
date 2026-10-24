import SwiftUI

@main
struct BaiApp: App {
    @StateObject private var appEnumerator = AppEnumerator()
    @StateObject private var restorePoints = RestorePointStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appEnumerator)
                .environmentObject(restorePoints)
                .onAppear {
                    appEnumerator.loadInstalledApps()
                    restorePoints.reload()
                }
        }
    }
}
