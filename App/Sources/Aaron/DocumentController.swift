import AppKit
import ObjectiveC
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Aaron", category: "copies")

/// Lets a file that is already open open again, instead of bringing its
/// window to the front: the same file may be open in several windows, e.g.
/// to read one part while editing another.
///
/// SwiftUI's document group installs its own `NSDocumentController`
/// subclass, so Aaron can't install one; instead it overrides
/// `document(for:)` (`documentForURL:`) on that class to report no open
/// document for any URL. After saving, NSDocument closes any other document
/// open on the same file, in the private `_closeOtherDocumentWithURL:`;
/// that is made to do nothing.
///
/// Both are replaced or neither: copies that saving closes could lose
/// their window and edits. When a macOS update removes or changes either
/// method, Aaron leaves both alone and works as AppKit does, with a file
/// open in one window only (see `AppModel.turnOffCopies(because:)`).
enum DocumentReopening {
    /// A replaced method, and its type encoding without frame offsets.
    private struct Hook {
        var selector: String
        var shape: String
    }

    private static let lookup = Hook(selector: "documentForURL:", shape: "@@:@")
    private static var closeOther: Hook {
        #if DEBUG
        // Smoke tests: as if a macOS update renamed the private method.
        if ProcessInfo.processInfo.environment["AARON_SIMULATE_API_CHANGE"] != nil {
            return Hook(selector: "_closeOtherDocumentWithURL:renamed:", shape: "v@:@")
        }
        #endif
        return Hook(selector: "_closeOtherDocumentWithURL:", shape: "v@:@")
    }

    private struct Patch {
        var owner: AnyClass
        var original: IMP
        var replacement: IMP
    }

    @MainActor private static var patches: [String: Patch] = [:]

    /// Why the methods can't be replaced on these classes, or nil.
    static func problem(controllerClass: AnyClass, documentClass: AnyClass) -> String? {
        mismatch(controllerClass, lookup) ?? mismatch(documentClass, closeOther)
    }

    private static func mismatch(_ owner: AnyClass, _ hook: Hook) -> String? {
        guard let method = class_getInstanceMethod(owner, NSSelectorFromString(hook.selector)) else {
            return "\(owner) has no method \(hook.selector)"
        }
        let encoding = method_getTypeEncoding(method).map { String(cString: $0) } ?? ""
        guard encoding.filter({ !$0.isNumber }) == hook.shape else {
            return "\(owner) \(hook.selector) has the type \(encoding) instead of \(hook.shape)"
        }
        return nil
    }

    /// Replaces both methods; returns why it didn't, leaving both alone.
    @MainActor @discardableResult
    static func enable() -> String? {
        guard patches.isEmpty else { return nil }
        let controllerClass: AnyClass = type(of: NSDocumentController.shared)
        if let problem = problem(controllerClass: controllerClass, documentClass: NSDocument.self) {
            return problem
        }
        let noDocument: @convention(block) (AnyObject, URL?) -> NSDocument? = { _, _ in nil }
        let keepOthers: @convention(block) (AnyObject, URL?) -> Void = { _, _ in }
        replace(lookup, in: controllerClass, with: imp_implementationWithBlock(noDocument))
        replace(closeOther, in: NSDocument.self, with: imp_implementationWithBlock(keepOthers))
        return nil
    }

    @MainActor private static func replace(_ hook: Hook, in owner: AnyClass, with replacement: IMP) {
        let selector = NSSelectorFromString(hook.selector)
        guard let method = class_getInstanceMethod(owner, selector),
              let original = class_getMethodImplementation(owner, selector) else { return }
        // Adds an override to a subclass, or replaces the class's own one.
        class_replaceMethod(owner, selector, replacement, method_getTypeEncoding(method))
        patches[hook.selector] = Patch(owner: owner, original: original, replacement: replacement)
    }

    /// Why the replaced methods are not the ones these classes run, e.g. a
    /// document class that overrides one; nil when they are.
    @MainActor static func check(controllerClass: AnyClass, documentClass: AnyClass) -> String? {
        let hooks: [(AnyClass, Hook)] = [(controllerClass, lookup), (documentClass, closeOther)]
        for (owner, hook): (AnyClass, Hook) in hooks {
            guard let patch = patches[hook.selector] else { continue }
            if class_getMethodImplementation(owner, NSSelectorFromString(hook.selector)) != patch.replacement {
                return "\(owner) has its own \(hook.selector)"
            }
        }
        return nil
    }

    /// Puts back the original methods.
    @MainActor static func disable() {
        for (selector, patch) in patches {
            let sel = NSSelectorFromString(selector)
            guard let method = class_getInstanceMethod(patch.owner, sel) else { continue }
            class_replaceMethod(patch.owner, sel, patch.original, method_getTypeEncoding(method))
        }
        patches = [:]
    }
}

extension AppModel {
    /// Stops opening files in several windows, for a reason found at runtime.
    func turnOffCopies(because problem: String) {
        logger.error("Opening a file in several windows is off: \(problem, privacy: .public)")
        canOpenCopies = false
        copiesProblem = problem
    }

    /// Checks that the replaced methods are the ones a document window
    /// runs; if not, turns copies off and tells the user. Before any other
    /// copy exists: the first window checks.
    func checkCopies(in window: NSWindow) {
        guard canOpenCopies, let document = window.windowController?.document else { return }
        let controllerClass: AnyClass = type(of: NSDocumentController.shared)
        guard let problem = DocumentReopening.check(controllerClass: controllerClass,
                                                    documentClass: type(of: document)) else { return }
        DocumentReopening.disable()
        turnOffCopies(because: problem)
        reportCopiesProblem()
    }

    static let copiesProblemReportedKey = "copiesProblemReportedFor"

    /// This Aaron build on this macOS version: the problem is reported
    /// once for each.
    static var buildAndSystem: String {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(build) on \(ProcessInfo.processInfo.operatingSystemVersionString)"
    }

    /// Tells the user, once per Aaron build and macOS version, that files
    /// open in one window only.
    func reportCopiesProblem(defaults: UserDefaults = .standard, version: String = AppModel.buildAndSystem) {
        let key = Self.copiesProblemReportedKey
        guard let problem = copiesProblem, defaults.string(forKey: key) != version else { return }
        defaults.set(version, forKey: key)
        showAlert("A file can only be open in one window",
                  """
                  This version of macOS changed a part of macOS that Aaron uses to open the same file in \
                  several windows. So that saving doesn’t close those windows or lose their edits, Aaron \
                  turned the feature off: opening a file that is already open brings its window to the front.

                  Everything else works as before. A newer build of Aaron is needed to get the feature back.

                  Details: \(problem).
                  """)
    }
}
