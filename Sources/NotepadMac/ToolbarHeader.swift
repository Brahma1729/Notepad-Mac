import AppKit

/// Notepad++-style toolbar rendered above the editor (programmatic, no nib).
final class ToolbarHeader: NSView {

    // Callbacks wired by EditorWindow.
    var onNew: (() -> Void)?
    var onOpen: (() -> Void)?
    var onSaveAll: (() -> Void)?
    var onZoomIn: (() -> Void)?
    var onZoomOut: (() -> Void)?
    var onResetFont: (() -> Void)?
    var onToggleWordWrap: ((Bool) -> Void)?      // called with the NEW state
    var onToggleWhitespace: ((Bool) -> Void)?
    var onToggleIndentGuides: ((Bool) -> Void)?

    private(set) var wordWrapBtn = NSButton(title: "Word Wrap", target: nil, action: nil)
    private(set) var whitespaceBtn = NSButton(title: "WS", target: nil, action: nil)
    private(set) var indentGuidesBtn = NSButton(title: "IG", target: nil, action: nil)

    /// gap-before each button (extra space marks group separators).
    private var layoutSpecs: [(NSButton, CGFloat)] = []
    private var actions = [ObjectIdentifier: () -> Void]()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        buildButtons()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func add(_ btn: NSButton, gap: CGFloat, _ handler: @escaping () -> Void) {
        btn.bezelStyle = .rounded
        actions[ObjectIdentifier(btn)] = handler
        layoutSpecs.append((btn, gap))
    }

    private func buildButtons() {
        let newBtn = NSButton(title: "New", target: nil, action: nil)
        let openBtn = NSButton(title: "Open", target: nil, action: nil)
        let saveAllBtn = NSButton(title: "Save All", target: nil, action: nil)
        let zoomInBtn = NSButton(title: "Zoom +", target: nil, action: nil)
        let zoomOutBtn = NSButton(title: "Zoom -", target: nil, action: nil)
        let resetFontBtn = NSButton(title: "Aa", target: nil, action: nil)

        add(newBtn, gap: 10) { [weak self] in self?.onNew?() }
        add(openBtn, gap: 6) { [weak self] in self?.onOpen?() }
        add(saveAllBtn, gap: 6) { [weak self] in self?.onSaveAll?() }
        add(zoomInBtn, gap: 18) { [weak self] in self?.onZoomIn?() }
        add(zoomOutBtn, gap: 6) { [weak self] in self?.onZoomOut?() }
        add(resetFontBtn, gap: 6) { [weak self] in self?.onResetFont?() }

        wordWrapBtn.bezelStyle = .rounded; whitespaceBtn.bezelStyle = .rounded; indentGuidesBtn.bezelStyle = .rounded
        let toggle = #selector(toggleTapped(_:))
        wordWrapBtn.target = self; wordWrapBtn.action = toggle
        whitespaceBtn.target = self; whitespaceBtn.action = toggle
        indentGuidesBtn.target = self; indentGuidesBtn.action = toggle

        add(wordWrapBtn, gap: 18) { [weak self] in self?.fireToggle(self!.wordWrapBtn) }
        add(whitespaceBtn, gap: 6) { [weak self] in self?.fireToggle(self!.whitespaceBtn) }
        add(indentGuidesBtn, gap: 6) { [weak self] in self?.fireToggle(self!.indentGuidesBtn) }

        for (btn, _) in layoutSpecs { addSubview(btn) }
    }

    /// Toggle buttons act like checkmarks; the window applies the change then calls syncToggles.
    @objc private func toggleTapped(_ sender: NSButton) {
        actions[ObjectIdentifier(sender)]?()
    }

    private func fireToggle(_ btn: NSButton) {
        switch btn {
        case wordWrapBtn: onToggleWordWrap?(wordWrapBtn.state != .on)
        case whitespaceBtn: onToggleWhitespace?(whitespaceBtn.state != .on)
        default: onToggleIndentGuides?(indentGuidesBtn.state != .on)
        }
    }

    /// Sync button states from external settings (call after changes).
    func syncToggles(wordWrap: Bool, whitespace: Bool, indentGuides: Bool) {
        wordWrapBtn.state = wordWrap ? .on : .off
        whitespaceBtn.state = whitespace ? .on : .off
        indentGuidesBtn.state = indentGuides ? .on : .off
    }

    override func layout() {
        super.layout()
        var x: CGFloat = 0
        let h: CGFloat = 26
        for (btn, gap) in layoutSpecs {
            btn.frame = NSRect(x: x + gap, y: (bounds.height - h) / 2, width: btn.intrinsicContentSize.width + 14, height: h)
            x += gap + btn.frame.width
        }
    }

    var preferredHeight: CGFloat { 38 }
}
