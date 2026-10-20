import Foundation

/// Plain document model (no NSDocument): canonical text + editor metadata (encoding, EOL style, language).
/// Text is stored LF-normalized; the original EOL style is re-applied on save.
final class EditorDocument {
    var text = ""
    var encoding: TextEncoding = .utf8
    var eolStyle: EOLStyle = .windows   // editor default for new files (CRLF)
    var languageID = "plain"
    var fileURL: URL?
    private(set) var isDirty = false

    init() {}

    /// Load raw bytes, auto-detecting encoding + EOL style. Returns false if undecodable.
    @discardableResult
    func load(data: Data, url: URL?) -> Bool {
        guard let (raw, enc) = TextEncoding.detectAndDecode(data) else { return false }
        eolStyle = EOLStyle.detect(in: raw)
        text = EOLStyle.normalize(raw, to: .unix)
        encoding = enc
        fileURL = url
        isDirty = false
        return true
    }

    /// Serialize with the document's EOL style + encoding (BOM included when required).
    var saveData: Data {
        encoding.encode(EOLStyle.normalize(text, to: eolStyle))
    }

    func markSaved(at url: URL?) { fileURL = url; isDirty = false }
    func markDirty() { isDirty = true }

    /// Forget unsaved changes without writing (editor "Don't Save").
    func clearDirty() { isDirty = false }

    var displayName: String { fileURL?.lastPathComponent ?? "Untitled" }
}
