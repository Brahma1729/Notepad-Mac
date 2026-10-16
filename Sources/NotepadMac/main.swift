import AppKit

if CommandLine.arguments.contains("--selftest") {
    let ok = SelfTest.run()
    print(ok ? "SELFTEST PASSED" : "SELFTEST FAILED")
    exit(ok ? 0 : 1)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
