import AppKit

/// Bottom status strip (Notepad++-like): Ln/Col/Sel, percent scrolled, EOL, encoding, language.
final class StatusBar: NSView {
    static let height: CGFloat = 20   // fixed NPP-style strip height (used by the Auto Layout in EditorWindow)
    private let lnLabel = NSTextField(labelWithString: "Ln 1")
    private let colLabel = NSTextField(labelWithString: "Col 1")
    private let selLabel = NSTextField(labelWithString: "")
    private let percentLabel = NSTextField(labelWithString: "100%")
    private let eolLabel = NSTextField(labelWithString: "LF")
    private let encodingLabel = NSTextField(labelWithString: "UTF-8")
    private let languageLabel = NSTextField(labelWithString: "None")
    private let sepLayer = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func buildUI() {
        for l in [lnLabel, colLabel, selLabel, percentLabel, eolLabel, encodingLabel, languageLabel] {
            l.font = NSFont.systemFont(ofSize: 11)
            l.textColor = .secondaryLabelColor
            l.translatesAutoresizingMaskIntoConstraints = false
            addSubview(l)
        }

        let leftStack = NSStackView(views: [lnLabel, colLabel, selLabel])
        leftStack.orientation = .horizontal
        leftStack.spacing = 14
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(leftStack)

        let rightStack = NSStackView(views: [languageLabel, encodingLabel, eolLabel, percentLabel])
        rightStack.orientation = .horizontal
        rightStack.spacing = 14
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rightStack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 20),
            leftStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            leftStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            rightStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            rightStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        // Hairline separator along the top edge.
        sepLayer.backgroundColor = NSColor.separatorColor.cgColor
        layer?.addSublayer(sepLayer)
    }

    override func layout() {
        super.layout()
        sepLayer.frame = CGRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1)
    }

    func update(line: Int, column: Int, selectionLength: Int, percentScroll: CGFloat) {
        lnLabel.stringValue = "Ln \(line)"
        colLabel.stringValue = "Col \(column)"
        selLabel.stringValue = selectionLength > 0 ? "Sel \(selectionLength)" : ""
    }

    func update(percentScroll: CGFloat) {
        percentLabel.stringValue = "\(Int((percentScroll * 100).rounded()))%"
    }

    func update(eol: String) { eolLabel.stringValue = eol }

    func update(encoding name: String) { encodingLabel.stringValue = name }

    func update(language name: String) { languageLabel.stringValue = name }
}