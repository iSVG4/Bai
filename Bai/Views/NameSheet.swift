import SwiftUI

struct NameRequest: Identifiable {
    let id = UUID()
    let title: String
    let message: String?
    let initialName: String
    var onCancel: (() -> Void)? = nil
    let onSave: (String) -> Void
}

struct NameSheet: View {
    let request: NameRequest

    @State private var name: String
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    init(request: NameRequest) {
        self.request = request
        _name = State(initialValue: request.initialName)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(footer: footer) {
                    TextField("Name", text: $name)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(save)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle(request.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        request.onCancel?()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).font(.body.weight(.semibold))
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true }
            }
        }
        .navigationViewStyle(.stack)
        .modifier(SmallSheetStyle())
    }

    @ViewBuilder private var footer: some View {
        if let message = request.message { Text(message) }
    }

    private func save() {
        request.onSave(name)
        dismiss()
    }
}

private struct SmallSheetStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.presentationDetents([.medium])
        } else {
            content
        }
    }
}
