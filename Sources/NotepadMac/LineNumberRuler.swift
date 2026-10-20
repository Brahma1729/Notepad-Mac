import AppKit

/// Numbers logical lines once, including the final empty line after a newline.
final class LineNumberRuler: NSRulerView {
    override var isFlipped: Bool { true }
    override var wantsDefaultClipping: Bool { true }

    private weak var editor: NSTextView?
    private var starts = [0]
    private var numberedText = ""
    private var numberedFontSize: CGFloat = 0

    init(scrollView: NSScrollView, textView: NSTextView) {
        editor = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(textChanged), name: NSText.didChangeNotification, object: textView)
        NotificationCenter.default.addObserver(self, selector: #selector(redraw), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        NotificationCenter.default.addObserver(self, selector: #selector(redraw), name: NSView.frameDidChangeNotification, object: textView)
        textView.postsFrameChangedNotifications = true
        rebuild()
    }

    required init(coder: NSCoder) { fatalError("LineNumberRuler is programmatic") }
    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func textChanged() { rebuild() }
    @objc private func redraw() { needsDisplay = true }

    private func rebuild() {
        guard let editor else { return }
        numberedText = editor.string
        numberedFontSize = editor.font?.pointSize ?? 13
        let text = numberedText as NSString
        starts = [0]
        var offset = 0
        while offset < text.length {
            offset = NSMaxRange(text.lineRange(for: NSRange(location: offset, length: 0)))
            if offset < text.length { starts.append(offset) }
        }
        if text.length > 0, let scalar = UnicodeScalar(text.character(at: text.length - 1)), CharacterSet.newlines.contains(scalar) {
            starts.append(text.length)
        }
        let font = editor.font ?? .monospacedSystemFont(ofSize: 13, weight: .regular)
        ruleThickness = max(40, (String(starts.count) as NSString).size(withAttributes: [.font: font]).width + 20)
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let editor, let manager = editor.layoutManager, editor.textContainer != nil else { return }
        // Programmatic document loads do not send text-change notifications.
        let text = editor.string as NSString
        if numberedText != editor.string || numberedFontSize != (editor.font?.pointSize ?? 13) { rebuild() }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        bounds.intersection(rect).clip()
        NSColor.windowBackgroundColor.setFill()
        bounds.intersection(rect).fill()
        let font = editor.font ?? .monospacedSystemFont(ofSize: 13, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.secondaryLabelColor]
        if let container = editor.textContainer { manager.ensureLayout(for: container) }
        let visible = editor.visibleRect
        for (index, start) in starts.enumerated() {
            let fragment: NSRect
            if start < text.length {
                let glyph = manager.glyphIndexForCharacter(at: start)
                fragment = manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            } else {
                let extra = manager.extraLineFragmentRect
                if extra.height > 0 {
                    fragment = extra
                } else if manager.numberOfGlyphs > 0 {
                    let previous = manager.lineFragmentRect(forGlyphAt: manager.numberOfGlyphs - 1, effectiveRange: nil)
                    fragment = NSRect(x: previous.minX, y: previous.maxY, width: previous.width, height: previous.height)
                } else {
                    fragment = NSRect(x: 0, y: 0, width: 1, height: font.pointSize + 4)
                }
            }
            guard fragment.height > 0 else { continue }
            let y = fragment.minY + editor.textContainerOrigin.y
            guard y + max(fragment.height, font.pointSize + 4) >= visible.minY, y <= visible.maxY else { continue }
            let label = String(index + 1) as NSString
            let point = convert(NSPoint(x: 0, y: y), from: editor)
            label.draw(at: NSPoint(x: ruleThickness - label.size(withAttributes: attributes).width - 8, y: point.y), withAttributes: attributes)
        }
    }
}
