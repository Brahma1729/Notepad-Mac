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

    private var buttons: [NSButton] = []
    private var handlers: [() -> Void] = []
    private var toggleIndices = Set<Int>()
    private let stack = NSStackView()
    private let more = NSButton(title: "More", target: nil, action: nil)
    private var visibleCount = 0
    private let buttonWidth: CGFloat = 28
    private let gap: CGFloat = 4

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = gap
        stack.detachesHiddenViews = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        add("New", "doc.badge.plus") { [weak self] in self?.onNew?() }
        add("Open", "folder") { [weak self] in self?.onOpen?() }
        add("Save All", "square.and.arrow.down") { [weak self] in self?.onSaveAll?() }
        add("Zoom In", "plus.magnifyingglass") { [weak self] in self?.onZoomIn?() }
        add("Zoom Out", "minus.magnifyingglass") { [weak self] in self?.onZoomOut?() }
        add("Reset Font Size", "textformat.size") { [weak self] in self?.onResetFont?() }
        add("Word Wrap", "return", button: wordWrapBtn) { [weak self] in
            guard let self = self else { return }; self.fireToggle(self.wordWrapBtn)
        }
        add("Show Whitespace", "paragraphsign", button: whitespaceBtn) { [weak self] in
            guard let self = self else { return }; self.fireToggle(self.whitespaceBtn)
        }
        add("Indent Guides", "line.3.horizontal.decrease", button: indentGuidesBtn) { [weak self] in
            guard let self = self else { return }; self.fireToggle(self.indentGuidesBtn)
        }
        more.target = self
        more.action = #selector(showMore(_:))
        more.bezelStyle = .rounded
        more.toolTip = "More actions"
        more.setAccessibilityLabel("More actions")
        more.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(more)
        more.widthAnchor.constraint(equalToConstant: 56).isActive = true
        more.heightAnchor.constraint(equalToConstant: 26).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func add(_ title: String, _ symbol: String, button: NSButton? = nil,
                     handler: @escaping () -> Void) {
        let btn = button ?? NSButton()
        btn.title = ""
        btn.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        if btn.image == nil { btn.title = title }
        btn.imagePosition = .imageOnly
        btn.toolTip = title
        btn.setAccessibilityLabel(title)
        btn.bezelStyle = .rounded
        btn.tag = buttons.count
        btn.target = self
        btn.action = #selector(tapped(_:))
        if button != nil { toggleIndices.insert(btn.tag) }
        buttons.append(btn)
        handlers.append(handler)
        btn.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(btn)
        btn.widthAnchor.constraint(equalToConstant: buttonWidth).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 26).isActive = true
    }

    @objc private func tapped(_ sender: NSButton) { handlers[sender.tag]() }
    @objc private func menuTapped(_ sender: NSMenuItem) { handlers[sender.tag]() }

    @objc private func showMore(_ sender: NSButton) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for i in visibleCount..<buttons.count {
            let item = NSMenuItem(title: buttons[i].toolTip ?? "Action",
                                  action: #selector(menuTapped(_:)), keyEquivalent: "")
            item.target = self
            item.tag = i
            item.image = buttons[i].image
            if toggleIndices.contains(i) { item.state = buttons[i].state }
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.minY - 2), in: sender)
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
        let available = max(0, bounds.width - 6)
        let fullWidth = CGFloat(buttons.count) * (buttonWidth + gap) - gap
        let overflow = available < fullWidth
        let count = overflow ? max(0, min(buttons.count, Int((available - 56) / (buttonWidth + gap)))) : buttons.count
        visibleCount = count
        for (i, button) in buttons.enumerated() { button.isHidden = i >= count }
        more.isHidden = !overflow
        super.layout()
    }

    var preferredHeight: CGFloat { 34 }
}
