import Foundation

// Run with `swift run NotepadMac --selftest`
enum SelfTest {
    static func run() -> Bool {
        var pass = true
        func check(_ name: String, _ cond: Bool) {
            print((cond ? "  ok   " : " FAIL ") + name)
            if !cond { pass = false }
        }

        let utf8 = Data("héllo\n".utf8)
        check("utf8 roundtrip", NPPEncoding.detect(utf8) == .utf8 && NPPEncoding.utf8.decode(utf8) == "héllo\n")

        let bom = Data([0xEF, 0xBB, 0xBF]) + Data("x".utf8)
        check("utf8-bom detect", NPPEncoding.detect(bom) == .utf8BOM && NPPEncoding.utf8BOM.strippedBOM(bom).count == 1)

        let u16 = "ab".data(using: .utf16LittleEndian)!
        check("utf16le detect", NPPEncoding.detect(Data([0xFF, 0xFE]) + u16) == .utf16le
              && NPPEncoding.utf16le.decode(NPPEncoding.utf16le.strippedBOM(Data([0xFF, 0xFE]) + u16)) == "ab")

        let be = Data([0xFE, 0xFF]) + ("ab".data(using: .utf16BigEndian)!)
        check("utf16be detect", NPPEncoding.detect(be) == .utf16be
              && NPPEncoding.utf16be.decode(NPPEncoding.utf16be.strippedBOM(be)) == "ab")

        let ansi = Data([0x48, 0xE9]) // H + é in Latin-1
        check("ansi decode", NPPEncoding.detect(ansi) == .ansi && NPPEncoding.ansi.decode(ansi) == "H\u{E9}")

        check("eol windows", EOLStyle.detect(in: "a\r\nb\r\nc") == .windows)
        check("eol unix", EOLStyle.detect(in: "a\nb\nc") == .unix)
        check("eol mac", EOLStyle.detect(in: "a\rb\rc") == .mac)

        let mixed = "a\r\nb\nc\rd"
        check("normalize->crlf", EOLStyle.normalize(mixed, to: .windows) == "a\r\nb\r\nc\r\nd")
        check("normalize->lf", EOLStyle.normalize(mixed, to: .unix) == "a\nb\nc\nd")

        let encoded = [UInt8](NPPEncoding.utf8BOM.encode("z"))
        check("bom write", Array(encoded.prefix(3)) == [0xEF, 0xBB, 0xBF])

        // MARK: SearchEngine — Find All line numbers across EOL styles + context preview
        var opts = FindOptions()
        opts.caseSensitive = true
        opts.wrapAround = false
        do {
            let lf = "foo bar foo\nbaz foo" as NSString
            let found = try SearchEngine.findAll("foo", in: lf, options: opts)
            check("findall count (lf)", found.count == 3)
            check("findall lines (lf)", found.map(\.line) == [1, 1, 2])

            let crlf = "one\r\ntwo two\r\nthree" as NSString
            let f2 = try SearchEngine.findAll("two", in: crlf, options: opts)
            check("findall line (crlf)", f2.count == 2 && f2.first?.line == 2)

            // Lone `\r` EOLs must count as breaks (old code only counted `\n`).
            let cr = "alpha\rbeta\rgamma" as NSString
            let f3 = try SearchEngine.findAll("gamma", in: cr, options: opts)
            check("findall line (cr-only)", f3.count == 1 && f3.first?.line == 3)

            // A CRLF pair counts once, not twice.
            let afterCrlf = "a\r\nb" as NSString
            let f4 = try SearchEngine.findAll("b", in: afterCrlf, options: opts)
            check("crlf boundary counted once", f4.first?.line == 2)

            // Long line: preview elides both ends but keeps the match.
            let padL = String(repeating: "x", count: 60), padR = String(repeating: "y", count: 60)
            let longLine = (padL + " needle " + padR) as NSString
            let f5 = try SearchEngine.findAll("needle", in: longLine, options: opts)
            let snippet = SearchEngine.contextSnippet(for: f5[0].range, in: longLine)
            check("snippet elides both ends", snippet.hasPrefix("…") && snippet.hasSuffix("…"))
            check("snippet keeps match", snippet.contains("needle"))

            // Short line: shown intact, no ellipsis.
            let short = "hello world" as NSString
            let f6 = try SearchEngine.findAll("world", in: short, options: opts)
            check("snippet short line intact", SearchEngine.contextSnippet(for: f6[0].range, in: short) == "hello world")

            // Case-insensitive by default (NPP parity): every case variant of the query matches.
            var wordOpts = FindOptions()   // defaults: ignoreCase on, whole-word off
            let ciText = "a cat and a CAT cAt" as NSString
            let f7 = try SearchEngine.findAll("cat", in: ciText, options: wordOpts)
            check("case-insensitive default", f7.count == 3)

            // …and case-sensitive matching honors the flag (only exact-case hit).
            var csOpts = FindOptions()
            csOpts.caseSensitive = true
            let f7b = try SearchEngine.findAll("cat", in: ciText, options: csOpts)
            check("case-sensitive honors flag", f7b.count == 1)

            // Whole-word matching excludes substring hits ("category").
            wordOpts.wholeWord = true
            let f8 = try SearchEngine.findAll("cat", in: ("a cat and a category" as NSString), options: wordOpts)
            check("whole-word excludes substring", f8.count == 1 && (f8.first?.range.location ?? -1) == 2)
        } catch {
            check("search engine no-throw", false)
        }
        return pass
    }
}
