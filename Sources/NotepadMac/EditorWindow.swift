import AppKit

/// One document = one window: NSTextView + StatusBar, backed by a plain `EditorDocument` model.
final class EditorWindowController: NSWindowController, NSTextViewDelegate {

    /// Model behind this window. Named `doc` because NSResponder already declares an
    /// optional `document` property that a stored `let document` would clash with.
    let doc: EditorDocument

    lazy var textView: NSTextView = makeTextView()
    private(set) var scrollView = NSScrollView(frame: .zero)
    private let statusBar = StatusBar(frame: .zero)
    private var highlightWork: DispatchWorkItem?
    private var wordWrapped = true
    private var programmaticEdit = false

    /// NPP-style default window size (1024x768 content).
    init(document: EditorDocument) {
        self.doc = document
        super.init(window: NSWindow(contentRect: NSRect(x: 300, y: 250, width: 1024, height: 768),
                                   styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                   backing: .buffered, defer: false))
        window?.title = doc.displayName
        window?.contentMinSize = NSSize(width: 360, height: 220)
        window?.delegate = self
        buildContent()
        syncFromDocument()
    }

    required init?(coder: NSCoder) { fatalError("EditorWindowController is not codable") }

    // MARK: - UI construction (programmatic, no nibs)

    private func makeTextView() -> NSTextView {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: scrollView.contentSize == .zero
                                       ? NSSize(width: 1024, height: 768) : scrollView.contentSize)
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        let frame = NSRect(origin: .zero, size: scrollView.contentSize == .zero
                           ? NSSize(width: 1024, height: 768) : scrollView.contentSize)
        let tv = NSTextView(frame: frame, textContainer: container)
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainerInset = NSSize(width: 4, height: 8)
        tv.font = NSFont.userFixedPitchFont(ofSize: 13)   // NPP-like monospace default; Highlighter preserves it per-attribute
        tv.delegate = self
        return tv
    }

    private func buildContent() {
        guard let window = window else { return }
        let contentBounds = NSRect(origin: .zero, size: window.contentMinSize == .zero
                                   ? NSSize(width: 1024, height: 768) : (window.contentView?.frame.size ?? NSSize(width: 1024, height: 768)))
        let sbHeight: CGFloat = 20

        scrollView.frame = NSRect(x: 0, y: sbHeight, width: contentBounds.width, height: max(contentBounds.height - sbHeight, 1))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.documentView = textView

        statusBar.frame = NSRect(x: 0, y: 0, width: contentBounds.width, height: sbHeight)
        statusBar.autoresizingMask = [.width]

        let container = NSView(frame: window.contentView!.bounds)
        container.addSubview(scrollView)
        container.addSubview(statusBar)
        window.contentView = container
    }

    // MARK: - Document sync + highlighting

    private func syncFromDocument() {
        programmaticEdit = true
        defer { programmaticEdit = false }
        textView.string = doc.text
        applyHighlightNow()                    // immediate on load (large files are skipped inside Highlighter)
        updateStatusBarMeta()
        refreshCaretStatus()
    }

    func textDidChange(_ notification: Notification) {
        guard !programmaticEdit else { return }
        doc.markDirty()
        refreshTitle()
        scheduleHighlight()
        refreshCaretStatus()
    }

    private func scheduleHighlight() {
        let work = DispatchWorkItem { [weak self] in self?.applyHighlightNow() }
        highlightWork?.cancel()
        highlightWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)   // debounce bursts of typing (NPP-like responsiveness)
    }

    private func applyHighlightNow() {
        // Real Highlighter API: `apply(_ language:, to storage:)` — nil for "plain" (skips rules, keeps font).
        let language = doc.languageID.isEmpty || doc.languageID == "plain"
            ? nil : Languages.byID(doc.languageID)
        if let storage = textView.textStorage { Highlighter.apply(language, to: storage) }
    }

    // MARK: - NSTextViewDelegate (user edits + caret/selection changes)

    @objc func textViewDidChange(_ notification: Notification) { textDidChange(notification) }

    // MARK: - StatusBar updates (line/col + encoding/EOL/language)

    private func refreshTitle() {
        window?.title = doc.displayName
    }

    private func updateStatusBarMeta() {
        statusBar.update(encoding: doc.encoding.rawValue)
        statusBar.update(eol: eolShort(doc.eolStyle))
        let name = (doc.languageID == "plain" ? nil : Languages.byID(doc.languageID)?.name) ?? "None"
        statusBar.update(language: name)
    }

    private func eolShort(_ style: EOLStyle) -> String {
        switch style {
        case .windows: return "CRLF"
        case .unix: return "LF"
        case .mac: return "CR"
        }
    }

    private func refreshCaretStatus() {
        if textView.string.isEmpty {
            statusBar.update(line: 1, column: 1, selectionLength: 0, percentScroll: 0)
            return
        }
        let nsText = textView.string as NSString
        let range = textView.selectedRange()
        let location = min(range.location, nsText.length)
        let (line, col) = caretLineCol(nsText, at: location)
        statusBar.update(line: line, column: col, selectionLength: range.length, percentScroll: scrollPercent())
    }

    /// 0...1 position of the viewport within the document (NPP status-bar percentage).
    private func scrollPercent() -> CGFloat {
        guard let clip = textView.enclosingScrollView?.contentView else { return 0 }
        let docHeight = textView.layoutManager?.usedRect(for: textView.textContainer!).height ?? 0
        guard docHeight > 0, docHeight > clip.bounds.height else { return 1 }
        let scrolled = textView.bounds.origin.y + clip.bounds.height
        return min(max(scrolled / docHeight, 0), 1)
    }

    private func caretLineCol(_ text: NSString, at location: Int) -> (line: Int, col: Int) {
        var line = 1
        for i in 0..<location where text.character(at: i) == 0x0A { line += 1 }   // fine for typical file sizes
        let lineStart = text.lineRange(for: NSRange(location: location, length: 0)).location
        return (line, location - lineStart + 1)
    }

    func textViewDidChangeSelection(_ notification: Notification) { refreshCaretStatus() }

    // MARK: - Search integration (NPP: Find = Cmd+F, Replace = Cmd+H)

    @objc func find(_ sender: Any?) { presentSearchPanel() }

    /// NPP uses one unified Find/Replace panel, so both menu items open the same view.
    @objc func replace(_ sender: Any?) { presentSearchPanel() }

    private func presentSearchPanel() {
        SearchPanel.shared.present(over: textView, document: doc)
    }

    // MARK: - Save (NPP: keep the same encoding/EOL; BOM only if one was there)

    @objc func saveDocument(_ sender: Any?) {
        guard doc.isDirty else { NSSound.beep(); return }   // NPP disables Save when clean
        do { try writeAndSave() } catch { NSSound.beep() }
    }

    @objc func saveDocumentAs(_ sender: Any?) {
        let panel = NSSavePanel()   // any file type allowed (NPP accepts everything)
        panel.nameFieldStringValue = doc.displayName.hasSuffix(".") ? doc.displayName : doc.displayName + ".txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try writeAndSave(to: url)
            doc.markSaved(at: url)
            refreshTitle()
        } catch {
            NSSound.beep()
        }
    }

    private func writeAndSave() throws {
        guard let url = doc.fileURL else { saveDocumentAs(nil); return }
        try writeAndSave(to: url)
    }

    /// Serialize with the document's EOL style + encoding (BOM included when required).
    private func writeAndSave(to url: URL) throws {
        try doc.saveData.write(to: url, options: .atomic)
    }

    // MARK: - Language / encoding selection (menu items route here via the responder chain)

    @objc func selectLanguage(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        doc.languageID = id
        applyHighlightNow()
        updateStatusBarMeta()
    }

    @objc func selectEncoding(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        switch name {
        case "UTF-8": doc.encoding = .utf8
        case "UTF-8-BOM", "UTF-8 with BOM": doc.encoding = .utf8BOM
        case "UTF-16 LE": doc.encoding = .utf16le
        case "UTF-16 BE": doc.encoding = .utf16be
        default: doc.encoding = .ansi
        }
        updateStatusBarMeta()
    }

    // MARK: - Word wrap (NPP View menu)

    @objc func toggleWordWrap(_ sender: NSMenuItem) {
        wordWrapped.toggle()
        sender.state = wordWrapped ? .on : .off
        textView.isHorizontallyResizable = !wordWrapped
        textView.maxSize = NSSize(width: wordWrapped ? CGFloat.greatestFiniteMagnitude : 1_000_000,
                                  height: CGFloat.greatestFiniteMagnitude)
        scrollView.hasHorizontalScroller = !wordWrapped
    }

    // MARK: - Close (NPP: prompt to save when dirty)

    @objc func closeDocument(_ sender: Any?) {
        guard confirmSaveIfDirty() else { return }
        window?.close()
    }

    @objc func closeAllDocuments(_ sender: Any?) {
        let controllers = NSApp.windows.compactMap { $0.windowController as? EditorWindowController }
        for controller in controllers where !controller.confirmSaveIfDirty() { return }   // Cancel on any one stops the rest
        for controller in controllers { controller.window?.close() }
    }

    private func confirmSaveIfDirty() -> Bool {
        guard doc.isDirty else { return true }
        let alert = NSAlert()
        alert.messageText = "\"\(doc.displayName)\" has unsaved changes."
        alert.informativeText = "Do you want to save your changes?"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")
        // Synchronous modal dialog (NSAlert's sheet API is async-only in this SDK).
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            do { try writeAndSave(); doc.markSaved(at: doc.fileURL); return true } catch { NSSound.beep(); return false }
        case .alertSecondButtonReturn:
            doc.clearDirty(); return true
        default:
            return false
        }
    }
}

extension EditorWindowController: NSWindowDelegate {}
