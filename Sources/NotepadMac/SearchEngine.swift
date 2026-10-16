import AppKit
import Foundation

struct FindOptions {
    var caseSensitive = false
    var wholeWord = false
    var useRegex = false
    var wrapAround = true
}

enum SearchError: Error, LocalizedError {
    case invalidPattern
    var errorDescription: String? { "Invalid search pattern" }
}

/// Directional, optional wrap-around search over an NSString.
struct SearchEngine {
    enum Direction { case forward, backward }

    static func matches(_ query: String, options: FindOptions) throws -> NSRegularExpression {
        let body = options.useRegex ? query : NSRegularExpression.escapedPattern(for: query)
        let pattern = options.wholeWord && !options.useRegex ? "\\b\(body)\\b" : body
        guard (try? NSRegularExpression(pattern: pattern)) != nil else { throw SearchError.invalidPattern }
        var opts: NSRegularExpression.Options = []
        if !options.caseSensitive { opts.insert(.caseInsensitive) }
        return try NSRegularExpression(pattern: pattern, options: opts)
    }

    /// Find the next match relative to `anchor` (a selection range).
    static func find(_ query: String, in text: NSString, options: FindOptions, direction: Direction, anchor: NSRange) throws -> NSRange? {
        guard !query.isEmpty else { return nil }
        let regex = try matches(query, options: options)
        let all = regex.matches(in: text as String, range: NSRange(location: 0, length: text.length))

        switch direction {
        case .forward:
            let start = anchor.length > 0 ? NSMaxRange(anchor) : anchor.location + (anchor.location == 0 && anchor.length == 0 ? 0 : 1)
            if let hit = all.first(where: { $0.range.location >= min(start, text.length) }) { return hit.range }
            guard options.wrapAround else { return nil }
            return all.first?.range  // wrap to beginning (skip match already covered by anchor start..?)

        case .backward:
            let before = anchor.length > 0 ? anchor.location : max(anchor.location - 1, 0)
            if let hit = all.last(where: { $0.range.location < min(before + 1, text.length) && ($0.range.location < (anchor.length > 0 ? anchor.location : anchor.location)) }) { return hit.range }
            guard options.wrapAround else { return nil }
            return all.last?.range
        }
    }

    /// Replace every occurrence; returns count. Caller must be inside `NSTextStorage.replaceCharacters` transaction or begin/endEditing.
    static func replaceAll(_ query: String, replacement: String, in storage: NSTextStorage, options: FindOptions) throws -> Int {
        guard !query.isEmpty else { return 0 }
        let regex = try matches(query, options: options)
        let text = (storage.string as NSString)
        let all = regex.matches(in: text as String, range: NSRange(location: 0, length: text.length))
        storage.beginEditing()
        for m in all.reversed() {
            var replaced = replacement
            if options.useRegex { // honor $1 backreferences (best effort)
                let captureGroups = 0...m.numberOfRanges - 1
                var out = ""
                var i = replacement.startIndex
                while i < replacement.endIndex {
                    if replacement[i] == "$" {
                        let next = replacement.index(after: i)
                        if next != replacement.endIndex,
                           let d = Int(String(replacement[next])),
                           d >= 1, d <= m.numberOfRanges - 1 {
                            out += (text.substring(with: m.range(at: d)))
                            i = next
                            continue
                        }
                    }
                    out.append(replacement[i])
                    i = replacement.index(after: i)
                }
                _ = captureGroups
                replaced = out
            }
            storage.replaceCharacters(in: m.range, with: replaced)
        }
        storage.endEditing()
        return all.count
    }

    /// Replace one occurrence (the range found by `find`).
    static func replaceOne(_ query: String, replacement: String, in storage: NSTextStorage, options: FindOptions, at range: NSRange) throws {
        _ = try matches(query, options: options) // validate pattern
        storage.replaceCharacters(in: range, with: replacement)
    }
}
