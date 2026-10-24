import SwiftUI

extension RestoreView {
    @ViewBuilder
    var resultSheet: some View {
        switch restoreState {
        case .done(let appName, let date):
            ResultSheetContent(
                success: true,
                appName: appName,
                date: date,
                message: nil
            )
        case .failed(let message):
            ResultSheetContent(
                success: false,
                appName: nil,
                date: nil,
                message: message
            )
        default:

            EmptyView()
        }
    }

    func beginRestore(from url: URL) async {
        restoreState = .restoring(progress: 0)

        do {
            let manifest = try await engine.restore(from: url) { fraction in

                Task { @MainActor in

                    if case .restoring = restoreState {
                        restoreState = .restoring(progress: fraction)
                    }
                }
            }

            restoreState = .done(appName: manifest.appName, date: manifest.backupDate)

        } catch {
            restoreState = .failed(message: error.localizedDescription)
        }

        showResultSheet = true
    }
}
