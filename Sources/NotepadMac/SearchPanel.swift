import AppKit

/// Notepad++-style Find / Replace panel (single reusable instance, like NPP).
final class SearchPanel: NSPanel {
    static let shared = SearchPanel()

    private let queryField = NSSearchField()
    private let replaceField = NSTextField()
    private let caseCheckbox = NSButton(checkboxWithTitle: "Match Case", target: nil, action: nil)
    private let wordCheckbox = NSButton(checkboxWithTitle: "Whole Word", target: nil, action: nil)
    private let regexCheckbox = NSButton(checkboxWithTitle: "Regex", target: nil, action: nil)
    private var statusLabel: NSTextField!

    weak var textView: NSTextView?
    weak var document: EditorDocument?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 460, height: 132),
                   styleMask: [.titled, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        title = "Find"
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        level = .floating
        buildUI()
    }

    override var canBecomeKey: Bool { true }

    // MARK: - UI construction (programmatic, no nib)

    private func buildUI() {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 132))
        contentView = content

        queryField.placeholderString = "Find what"
        replaceField.placeholderString = "Replace with"
        [queryField, replaceField].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        let findNextBtn = NSButton(title: "Find Next", target: self, action: #selector(findNext))
        findNextBtn.bezelStyle = .rounded
        findNextBtn.keyEquivalent = "\r" // Return anywhere in panel = next match
        let findPrevBtn = NSButton(title: "Find Prev", target: self, action: #selector(findPrevious))
        findPrevBtn.bezelStyle = .rounded
        let findAllBtn = NSButton(title: "Find All", target: self, action: #selector(findAllAction))
        findAllBtn.bezelStyle = .rounded
        let replaceOneBtn = NSButton(title: "Replace", target: self, action: #selector(replaceCurrent))
        replaceOneBtn.bezelStyle = .rounded
        let replaceAllBtn = NSButton(title: "Replace All", target: self, action: #selector(replaceAllAction))
        replaceAllBtn.bezelStyle = .rounded
        let closeBtn = NSButton(title: "Close", target: self, action: #selector(closePanel))
        closeBtn.bezelStyle = .rounded
        closeBtn.keyEquivalent = "\u{1b}" // Escape

        [findNextBtn, findPrevBtn, findAllBtn, replaceOneBtn, replaceAllBtn, closeBtn].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false; content.addSubview($0)
        }

        caseCheckbox.state = .off; wordCheckbox.state = .off; regexCheckbox.state = .off
        let optionsStack = NSStackView(views: [caseCheckbox, wordCheckbox, regexCheckbox])
        optionsStack.orientation = .horizontal
        optionsStack.translatesAutoresizingMaskIntoConstraints = false

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        let findLbl = NSTextField(labelWithString: "Find:")
        let repLbl = NSTextField(labelWithString: "Replace:")
        [findLbl, repLbl].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; content.addSubview($0) }

        [queryField, replaceField, optionsStack, statusLabel].forEach { content.addSubview($0) }

        NSLayoutConstraint.activate([
            findLbl.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            findLbl.centerYAnchor.constraint(equalTo: queryField.centerYAnchor),
            queryField.leadingAnchor.constraint(equalTo: findLbl.trailingAnchor, constant: 8),
            queryField.trailingAnchor.constraint(equalTo: findNextBtn.leadingAnchor, constant: -8),
            queryField.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            findNextBtn.trailingAnchor.constraint(equalTo: findPrevBtn.leadingAnchor, constant: -6),
            findPrevBtn.trailingAnchor.constraint(equalTo: findAllBtn.leadingAnchor, constant: -6),
            findAllBtn.trailingAnchor.constraint(equalTo: closeBtn.leadingAnchor, constant: -6),
            closeBtn.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            findNextBtn.centerYAnchor.constraint(equalTo: queryField.centerYAnchor),
            repLbl.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            repLbl.centerYAnchor.constraint(equalTo: replaceField.centerYAnchor),
            replaceField.leadingAnchor.constraint(equalTo: repLbl.trailingAnchor, constant: 8),
            replaceField.topAnchor.constraint(equalTo: queryField.bottomAnchor, constant: 10),
            replaceOneBtn.leadingAnchor.constraint(equalTo: findNextBtn.leadingAnchor),
            replaceOneBtn.topAnchor.constraint(equalTo: replaceField.topAnchor),
            replaceAllBtn.leadingAnchor.constraint(equalTo: findPrevBtn.leadingAnchor),
            replaceAllBtn.topAnchor.constraint(equalTo: replaceField.topAnchor),
            optionsStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            optionsStack.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -8),
            optionsStack.topAnchor.constraint(equalTo: replaceField.bottomAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: closeBtn.trailingAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: optionsStack.centerYAnchor)
        ])
    }

    // MARK: - lifecycle

    func present(over textView: NSTextView, document: EditorDocument?) {
        self.textView = textView
        self.document = document
        statusLabel.stringValue = ""
        if let window = textView.window {
            setFrameOrigin(NSPoint(x: window.frame.minX + 60, y: window.frame.maxY - 170))
        }
        makeKeyAndOrderFront(nil)
        // Pre-fill with current selection (NPP behavior).
        let sel = textView.selectedRange()
        if sel.length > 0 { queryField.stringValue = (textView.string as NSString).substring(with: sel) }
        selectAllInQuery()
    }

    private func selectAllInQuery() {
        DispatchQueue.main.async { [weak self] in
            guard let field = self?.queryField else { return }
            field.selectText(NSRange(location: 0, length: (field.stringValue as NSString).length))
        }
    }

    // MARK: - actions

    private var options: FindOptions {
        FindOptions(caseSensitive: caseCheckbox.state == .on,
                    wholeWord: wordCheckbox.state == .on,
                    useRegex: regexCheckbox.state == .on)
    }

    @objc func findNext() { _ = perform(.forward) }
    @objc func findPrevious() { _ = perform(.backward) }

    /// NPP "Find All": report how many occurrences exist in the whole document.
    @objc func findAllAction() {
        guard let tv = textView, !queryField.stringValue.isEmpty else { return }
        do {
            let n = try SearchEngine.countAll(queryField.stringValue, in: tv.string as NSString, options: options)
            statusLabel.stringValue = "\(n) occurrence\(n == 1 ? "" : "s") found"
        } catch {
            statusLabel.stringValue = error.localizedDescription
        }
    }

    private func perform(_ direction: SearchEngine.Direction) -> Bool {
        guard let tv = textView, !queryField.stringValue.isEmpty else { return false }
        do {
            if let range = try SearchEngine.find(queryField.stringValue, in: tv.string as NSString, options: options, direction: direction, anchor: tv.selectedRange()) {
                tv.setSelectedRange(range)
                tv.scrollRangeToVisible(range)
                statusLabel.stringValue = "Found"
                return true
            } else {
                NSSound.beep()
                statusLabel.stringValue = "Nothing found"
                return false
            }
        } catch {
            statusLabel.stringValue = error.localizedDescription
            NSSound.beep()
            return false
        }
    }

    @objc func replaceCurrent() {
        guard let tv = textView else { return }
        do {
            try SearchEngine.replaceOne(queryField.stringValue, replacement: replaceField.stringValue, in: tv.textStorage!, options: options, at: tv.selectedRange())
            document?.markDirty()
            _ = perform(.forward) // continue searching after replace (NPP behavior)
        } catch { statusLabel.stringValue = error.localizedDescription; NSSound.beep() }
    }

    @objc func replaceAllAction() {
        guard let tv = textView else { return }
        do {
            let count = try SearchEngine.replaceAll(queryField.stringValue, replacement: replaceField.stringValue, in: tv.textStorage!, options: options)
            document?.markDirty()
            statusLabel.stringValue = "Replaced \(count) occurrence(s)"
        } catch { statusLabel.stringValue = error.localizedDescription; NSSound.beep() }
    }

    @objc func closePanel() { orderOut(nil) }
}
