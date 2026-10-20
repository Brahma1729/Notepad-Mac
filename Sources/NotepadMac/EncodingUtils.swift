import Foundation

// MARK: - Encoding

enum TextEncoding: String, CaseIterable {
    case utf8 = "UTF-8"
    case utf8BOM = "UTF-8-BOM"
    case utf16le = "UTF-16 LE"
    case utf16be = "UTF-16 BE"
    case ansi = "ANSI (Latin-1)"

    var hasBOM: Bool { self == .utf8BOM }

    func decode(_ data: Data) -> String? {
        switch self {
        case .utf8, .utf8BOM: return String(data: data, encoding: .utf8)
        case .utf16le: return String(data: data, encoding: .utf16LittleEndian)
        case .utf16be: return String(data: data, encoding: .utf16BigEndian)
        case .ansi: return String(bytes: data, encodingLatin1: true)
        }
    }

    func encode(_ text: String) -> Data {
        switch self {
        case .utf8:
            return Data(text.utf8)
        case .utf8BOM:
            var d: [UInt8] = [0xEF, 0xBB, 0xBF]
            d.append(contentsOf: Array(text.utf8))
            return Data(d)
        case .utf16le: return text.data(using: .utf16LittleEndian)!
        case .utf16be: return text.data(using: .utf16BigEndian)!
        case .ansi: return Data(text.unicodeScalars.map { UInt8(min($0.value, 255)) })
        }
    }

    /// Detect encoding from raw bytes (BOMs first, then UTF-8 validity).
    static func detect(_ data: Data) -> TextEncoding {
        let b = [UInt8](data.prefix(4))
        if data.count >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF { return .utf8BOM }
        if data.count >= 2 && b[0] == 0xFF && b[1] == 0xFE { return .utf16le }
        if data.count >= 2 && b[0] == 0xFE && b[1] == 0xFF { return .utf16be }
        if String(data: data, encoding: .utf8) != nil { return .utf8 }
        if data.contains(0) { return .utf16le }
        return .ansi
    }

    /// Strip a leading BOM when present for this encoding.
    func strippedBOM(_ data: Data) -> Data {
        let b = [UInt8](data.prefix(4))
        if self == .utf8BOM && data.count >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF {
            return data.dropFirst(3)
        }
        if (self == .utf16le || self == .utf16be) && data.count >= 2 {
            let le = b[0] == 0xFF && b[1] == 0xFE
            let be = b[0] == 0xFE && b[1] == 0xFF
            if (self == .utf16le && le) || (self == .utf16be && be) { return data.dropFirst(2) }
        }
        return data
    }

    static func detectAndDecode(_ data: Data) -> (text: String, encoding: TextEncoding)? {
        let enc = detect(data)
        guard let text = enc.decode(enc.strippedBOM(data)) else { return nil }
        return (text, enc)
    }
}

// MARK: - EOL styles

enum EOLStyle: String, CaseIterable {
    case windows = "Windows"      // CRLF
    case unix = "Unix"            // LF
    case mac = "Mac (classic)"    // CR

    var separator: String {
        switch self {
        case .windows: return "\r\n"
        case .unix: return "\n"
        case .mac: return "\r"
        }
    }

    static func detect(in text: String) -> EOLStyle {
        var crlf = 0, lf = 0, cr = 0
        var i = text.startIndex
        while i < text.endIndex {
            let c = text[i]
            if c == "\r" || c == "\n" {
                let next = text.index(after: i)
                if c == "\r" && next < text.endIndex && text[next] == "\n" { crlf += 1; i = next; continue }
                if c == "\n" { lf += 1 } else { cr += 1 }
            }
            i = text.index(after: i)
        }
        return max(crlf, max(lf, cr)) == 0 ? .windows
             : (crlf >= lf && crlf > cr ? .windows : (cr > lf ? .mac : .unix))
    }

    static func normalize(_ text: String, to style: EOLStyle) -> String {
        var t = text.replacingOccurrences(of: "\r\n", with: "\n")
        t = t.replacingOccurrences(of: "\r", with: "\n")
        if style != .unix { t = t.replacingOccurrences(of: "\n", with: style.separator) }
        return t
    }
}

// MARK: - Latin-1 bridge (ANSI approximation)

extension String {
    init?(bytes: Data, encodingLatin1: Bool) {
        guard encodingLatin1 else { return nil }
        var out = ""
        out.reserveCapacity(bytes.count)
        for b in bytes { out.unicodeScalars.append(Unicode.Scalar(b)) }
        self.init(out)
    }
}
