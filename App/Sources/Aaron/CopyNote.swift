import AppKit
import SwiftUI

extension AppModel {
    /// Tells every window how many windows show its file.
    func refreshCopies() {
        let all = windows
        for window in all {
            guard let url = window.fileURL else {
                window.copyCount = 1
                continue
            }
            window.copyCount = all.filter { $0.fileURL.map { Self.isSameFile($0, url) } == true }.count
        }
    }

    func windowClosed(_ window: DocumentWindowModel) {
        unregister(window)
        refreshCopies()
    }
}

extension DocumentWindowModel {
    /// A file open in several windows is pointed out in each, until closed
    /// there; it comes back when yet another window opens the file.
    var showsCopyNote: Bool { copyCount > 1 && !copyNoteDismissed }

    func dismissCopyNote() { copyNoteDismissed = true }
}

/// The bar at the top of a window whose file is also open in another one.
struct CopyNote: View {
    let model: DocumentWindowModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.on.rectangle")
                .foregroundStyle(.secondary)
            Text("Also open in another window. Edits there appear here after they’re saved.")
                .font(.callout)
            Spacer()
            Button {
                model.dismissCopyNote()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Hide this note in this window")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.bar)
        .accessibilityIdentifier("copyNote")
    }
}
