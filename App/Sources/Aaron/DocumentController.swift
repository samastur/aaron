import AppKit
import ObjectiveC

/// Lets a file that is already open open again, instead of bringing its
/// window to the front: the same file may be open in several windows, e.g.
/// to read one part while editing another.
///
/// SwiftUI's document group installs its own `NSDocumentController`
/// subclass, so Aaron can't install one; instead it overrides
/// `document(for:)` on that class to report no open document for any URL.
enum DocumentReopening {
    static func enable() {
        let controllerClass: AnyClass = type(of: NSDocumentController.shared)
        let selector = NSSelectorFromString("documentForURL:")
        guard let method = class_getInstanceMethod(controllerClass, selector) else { return }
        let block: @convention(block) (AnyObject, URL) -> NSDocument? = { _, _ in nil }
        // Adds an override to SwiftUI's subclass, or replaces its own one.
        class_replaceMethod(controllerClass, selector, imp_implementationWithBlock(block),
                            method_getTypeEncoding(method))
    }
}
