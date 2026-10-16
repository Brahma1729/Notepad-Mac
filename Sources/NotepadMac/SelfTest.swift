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
        return pass
    }
}
