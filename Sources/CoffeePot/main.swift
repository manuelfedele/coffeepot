import AppKit

// CoffeePot: a tiny macOS menu bar app that keeps your Mac awake.
//
// Runs as an accessory (no Dock icon, no main window). The whole UI lives in
// the status bar item managed by AppDelegate.

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
