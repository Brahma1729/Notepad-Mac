import AppKit

/// In-window NPP-style menu strip: a horizontal row of clickable menus
/// (File / Edit / Search / View / Language / Encoding / Window) that mirrors the app's
/// main-menu bar. Each button pops up a real `NSMenu`; items use type-checked
/// selectors and route through the responder chain to `EditorWindowController`
/// or `AppDelegate`, exactly like the native menu-bar items do.
final class MenuHeader: NSView {

    static let height: CGFloat = 24
    private let spacing: CGFloat = 8
    private let sidePadding: CGFloat = 6

    private var buttons: [NSButton] = []
    /// Parallel to `buttons`: the menu each button pops up.
    private var menus: [String: NSMenu] = [:]

    // MARK: - Sizing (NSSize is non-optional; guard empty state explicitly)

    override var intrinsicContentSize: NSSize {
        guard !buttons.isEmpty else { return NSSize(width: 40, height: Self.height) }
        let widths = buttons.reduce(CGFloat(0)) { $0 + max($1.intrinsicContentSize.width, 36) }
        let total = widths + spacing * CGFloat(buttons.count - 1) + sidePadding * 2
        return NSSize(width: ceil(total), height: Self.height)
    }

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        buildMenusAndButtons()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Construction

    private func buildMenusAndButtons() {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = spacing
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: sidePadding),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -sidePadding),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        let specs: [(title: String, menu: NSMenu)] = [
            ("File", fileMenu()),
            ("Edit", editMenu()),
            ("Search", searchMenu()),
            ("View", viewMenu()),
            ("Language", languageMenu()),
            ("Encoding", encodingMenu()),
            ("Window", windowMenu()),
        ]

        for spec in specs {
            let button = NSButton(title: " \(spec.title) ▾", target: self, action: #selector(popUpMenu(_:)))
            button.bezelStyle = .regularSquare          // subtle bezel + press highlight (NPP-like affordance)
            button.font = NSFont.systemFont(ofSize: 12)
            button.setButtonType(.onOff)               // stays highlighted while its menu is open
            button.setContentHuggingPriority(.required, for: .horizontal)
            stack.addArrangedSubview(button)

            buttons.append(button)
            menus[spec.title] = spec.menu
        }
    }

    /// Pop the button's menu just below it. `popUp(positioning:at:in:)` is
    /// available on macOS 10.15+; coordinates are in the container view's space.
    @objc private func popUpMenu(_ sender: NSButton) {
        // Button titles are decorated (" File ▾") — match by prefix of the menu name.
        let label = sender.title.trimmingCharacters(in: .whitespaces)
        guard let menu = menus.first(where: { label.hasPrefix($0.key) })?.value else { return }
        // AppKit coordinate system is bottom-up: just below the button's frame.
        let point = NSPoint(x: sender.frame.minX, y: -sender.frame.maxY - 2)
        menu.popUp(positioning: nil, at: point, in: self)
    }

    /// Syncs checkmarks for the View toggles (called when state changes elsewhere).
    func syncViewStates(wordWrap: Bool, whitespace: Bool, indentGuides: Bool) {
        guard let view = menus["View"] else { return }
        setState(view, "Word Wrap", wordWrap)
        setState(view, "Show Whitespace", whitespace)
        setState(view, "Indent Guides", indentGuides)
    }

    private func setState(_ menu: NSMenu, _ title: String, _ on: Bool) {
        if let item = menu.items.first(where: { $0.title == title }) {
            item.state = on ? .on : .off
        }
    }

    /// Menu items with `target == nil` route through the responder chain
    /// (EditorWindowController → EditorDocument → NSTextView), exactly like
    /// standard main-menu items. Unavailable targets auto-disable (gray out).
    private func makeItem(_ title: String, _ action: Selector?, _ key: String = "",
                          mask: NSEvent.ModifierFlags? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        if let mask { item.keyEquivalentModifierMask = mask }
        return item
    }

    // MARK: - Menu specs (mirror AppDelegate.buildMainMenu)

    private func fileMenu() -> NSMenu {
        let menu = NSMenu(title: "File")
        // `target == nil` → routed through the responder chain to AppDelegate.
        menu.addItem(makeItem("New…", #selector(AppDelegate.newDocument(_:)), "n"))
        menu.addItem(makeItem("Open…", #selector(AppDelegate.openDocument(_:)), "o"))
        menu.addItem(.separator())
        // The controller owns its own dirty-check flow (closeDocument), so use
        // that instead of performClose: to keep the save prompt consistent.
        menu.addItem(makeItem("Close Document", #selector(EditorWindowController.closeDocument(_:)), "w"))
        return menu
    }

    private func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        // Standard editing selectors land on the first-responder NSTextView.
        menu.addItem(makeItem("Undo", Selector(("undo:")), "z"))
        menu.addItem(makeItem("Redo", Selector(("redo:")), "Z", mask: [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(makeItem("Cut", Selector(("cut:")), "x"))
        menu.addItem(makeItem("Copy", Selector(("copy:")), "c"))
        menu.addItem(makeItem("Paste", Selector(("paste:")), "v"))
        menu.addItem(makeItem("Select All", Selector(("selectAll:")), "a"))
        return menu
    }

    private func searchMenu() -> NSMenu {
        let menu = NSMenu(title: "Search")
        // Find and Replace share one Notepad++-style panel (same as the app menu).
        menu.addItem(makeItem("Find…", #selector(EditorWindowController.find(_:)), "f"))
        menu.addItem(makeItem("Replace…", #selector(EditorWindowController.replace(_:)), "h"))
        return menu
    }

    private func viewMenu() -> NSMenu {
        let menu = NSMenu(title: "View")
        // Same actions and initial state as the app's View menu; buildContent re-syncs from live state.
        for item in [makeItem("Word Wrap", #selector(EditorWindowController.toggleWordWrap(_:))),
                     makeItem("Show Whitespace", #selector(EditorWindowController.toggleWhitespace(_:))),
                     makeItem("Indent Guides", #selector(EditorWindowController.toggleIndentGuides(_:)))] {
            item.state = .on
            menu.addItem(item)
        }
        return menu
    }

    private func languageMenu() -> NSMenu {
        let menu = NSMenu(title: "Language")
        // Mirror the app menu's Core/Web groups; "None" resets to plain text.
        var firstGroup = true
        for group in Languages.groups {
            if !firstGroup { menu.addItem(.separator()) }
            firstGroup = false
            let groupItem = NSMenuItem()
            let submenu = NSMenu(title: group.name)
            groupItem.submenu = submenu
            let none = makeItem("None", #selector(EditorWindowController.selectLanguage(_:)))
            none.representedObject = "plain"
            submenu.addItem(none)
            for lang in group.languages {
                let item = makeItem(lang.name, #selector(EditorWindowController.selectLanguage(_:)))
                item.representedObject = lang.id
                submenu.addItem(item)
            }
            menu.addItem(groupItem)
        }
        return menu
    }

    private func encodingMenu() -> NSMenu {
        let menu = NSMenu(title: "Encoding")
        // Same list as the app's Status menu; names map to EditorDocument.encoding.
        for encName in ["UTF-8", "UTF-16 LE", "ANSI"] {
            let item = makeItem(encName, #selector(EditorWindowController.selectEncoding(_:)))
            item.representedObject = encName
            menu.addItem(item)
        }
        return menu
    }

    private func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem(makeItem("Close", #selector(EditorWindowController.closeDocument(_:)), "w"))
        menu.addItem(.separator())
        menu.addItem(makeItem("Close All", #selector(EditorWindowController.closeAllDocuments(_:))))
        return menu
    }
}
