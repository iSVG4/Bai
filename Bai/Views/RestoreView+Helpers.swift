import SwiftUI
import UniformTypeIdentifiers

struct ZipPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    var startingDirectory: URL? = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [UTType.zip],
            asCopy: true
        )
        picker.allowsMultipleSelection = false
        if let startingDirectory { picker.directoryURL = startingDirectory }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController,
                                context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

struct ResultSheetContent: View {
    let success: Bool
    let appName: String?
    let date: Date?
    let message: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(success ? .green : .red)
                .padding(.top, 32)

            VStack(spacing: 8) {
                Text(success ? "Restore Complete" : "Restore Failed")
                    .font(.title2.bold())

                if success, let appName {
                    Text(appName)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                if success, let date {
                    Text("Backed up \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !success, let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
            }

            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(success ? Color.green : Color.red)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .modifier(MediumSheetStyle())
    }
}

private struct MediumSheetStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.presentationDetents([.medium]).presentationDragIndicator(.visible)
        } else {
            content
        }
    }
}
