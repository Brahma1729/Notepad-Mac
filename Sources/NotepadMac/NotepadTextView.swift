import AppKit

/// NSTextView subclass that draws  overlays:
/// whitespace markers (dots) and indent guides (vertical rules per leading space).
final class NotepadTextView: NSTextView {

    /// Default view options: whitespace dots + indent guides both visible (toggle from toolbar or View menu).
    var showWhitespace = true   { didSet { if oldValue != showWhitespace { needsDisplay = true } } }
    var showIndentGuides = true { didSet { if oldValue != showIndentGuides { needsDisplay = true } } }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard showWhitespace || showIndentGuides, let lm = layoutManager else { return }
        let nsText = string as NSString
        guard nsText.length > 0 else { return }

        let font = self.font ?? NSFont.userFixedPitchFont(ofSize: 13) ?? NSFont.systemFont(ofSize: 13)
        let spaceWidth = (" " as NSString).size(withAttributes: [.font: font]).width
        let origin = textContainerOrigin

        var lines: [(range: NSRange, rect: NSRect)] = []
        lm.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: lm.numberOfGlyphs)) {
            lineFragmentRect, _, _, glyphRange, _ in
            guard glyphRange.length > 0 else { return }
            let charRange = lm.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            if charRange.location != NSNotFound { lines.append((charRange, lineFragmentRect)) }
        }

        for (range, fragRect) in lines where fragRect.intersects(dirtyRect) {
            let line = nsText.substring(with: range) as NSString

            // Indent guides: one vertical rule per leading space/tab ().
            if showIndentGuides {
                var indent = 0
                while indent < line.length,
                      line.character(at: indent) == UInt16(32) || line.character(at: indent) == UInt16(9) {
                    indent += 1
                }
                if indent > 0 {
                    let guideColor = NSColor.secondaryLabelColor.withAlphaComponent(0.4)   // gridColor is near-invisible on windowBackground
                    for i in 1...indent {
                        let x = origin.x + fragRect.minX + CGFloat(i) * spaceWidth
                        guideColor.setFill()
                        NSRect(x: x - 0.5, y: fragRect.minY, width: 1, height: max(fragRect.height - 2, 1)).fill()
                    }
                }
            }

            // Whitespace markers: a dot at every space/tab in the line.
            if showWhitespace {
                let markColor = NSColor.secondaryLabelColor.withAlphaComponent(0.6)
                let baselineY = fragRect.minY + max(-font.ascender, 8) * 0.5
                for i in 0..<line.length {
                    let c = line.character(at: i)
                    guard c == UInt16(32) || c == UInt16(9) else { continue }
                    let charIdx = range.location + i
                    let glyph = lm.glyphIndexForCharacter(at: charIdx)
                    if glyph != NSNotFound {
                        let loc = lm.location(forGlyphAt: glyph)
                        markColor.setFill()
                        NSRect(x: origin.x + loc.x + spaceWidth / 2 - 1.5, y: baselineY - 1.5, width: 3, height: 3).fill()
                    }
                }
            }
        }
    }
}
