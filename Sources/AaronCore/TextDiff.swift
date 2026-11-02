import Foundation

/// The smallest single replacement that turns one text into another, so a
/// reload can be applied as one edit that keeps the selection and undo.
public enum TextDiff {
    public struct Change: Equatable, Sendable {
        /// In UTF-16 units of the old text, as NSString and NSTextView count.
        public var range: NSRange
        public var replacement: String

        public init(range: NSRange, replacement: String) {
            self.range = range
            self.replacement = replacement
        }

        /// Where a range of the old text ends up after the change: before it
        /// stays, after it shifts, and an end inside it moves to its end.
        public func adjust(_ selection: NSRange) -> NSRange {
            let newEnd = range.location + (replacement as NSString).length
            func position(_ old: Int) -> Int {
                if old <= range.location { return old }
                if old >= NSMaxRange(range) { return old - range.length + (newEnd - range.location) }
                return newEnd
            }
            let start = position(selection.location)
            return NSRange(location: start, length: max(0, position(NSMaxRange(selection)) - start))
        }
    }

    public static func change(from old: String, to new: String) -> Change? {
        let a = Array(old.utf16), b = Array(new.utf16)
        if a == b { return nil }
        var prefix = 0
        while prefix < a.count, prefix < b.count, a[prefix] == b[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < a.count - prefix, suffix < b.count - prefix,
              a[a.count - 1 - suffix] == b[b.count - 1 - suffix] { suffix += 1 }
        // Don't split a surrogate pair.
        if prefix > 0, prefix < a.count, UTF16.isTrailSurrogate(a[prefix]) { prefix -= 1 }
        if suffix > 0, a.count - suffix < a.count, UTF16.isTrailSurrogate(a[a.count - suffix]) { suffix -= 1 }
        let replaced = NSRange(location: prefix, length: a.count - prefix - suffix)
        let inserted = String(decoding: b[prefix..<(b.count - suffix)], as: UTF16.self)
        return Change(range: replaced, replacement: inserted)
    }
}
