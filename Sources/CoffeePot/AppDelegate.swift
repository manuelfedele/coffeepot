import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let caffeine = CaffeineController()

    /// The duration the user last picked, reused when toggling from the icon.
    private var lastDuration: TimeInterval? = 15 * 60

    // Menu items we mutate on state change.
    private var statusMenuItem: NSMenuItem!
    private var item15: NSMenuItem!
    private var item60: NSMenuItem!
    private var itemInfinite: NSMenuItem!
    private var displaySleepItem: NSMenuItem!
    private var loginItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = StatusIcon.image(active: false)
            button.imagePosition = .imageOnly
            button.toolTip = "CoffeePot: keep your Mac awake"
            button.setAccessibilityLabel("CoffeePot")
            // Left-click toggles, right-click opens the menu.
            button.target = self
            button.action = #selector(statusButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Full refresh (icon + menu + labels) on real state changes; a cheaper
        // refresh of just the dynamic text on each countdown tick.
        caffeine.onStateChange = { [weak self] in self?.refreshUI() }
        caffeine.onTick = { [weak self] in self?.refreshDynamicText() }

        // A run-loop timer does not fire while the Mac is asleep, so re-check
        // the deadline on wake to expire a session that ran out mid-sleep.
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemDidWake(_:)),
            name: NSWorkspace.didWakeNotification, object: nil)

        buildMenu()
        refreshUI()
    }

    @objc private func systemDidWake(_ note: Notification) {
        caffeine.checkExpiryNow()
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        statusMenuItem = NSMenuItem(title: "Idle", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(.separator())

        item15 = NSMenuItem(title: "Keep awake for 15 minutes",
                            action: #selector(keepFor15(_:)), keyEquivalent: "")
        item15.target = self
        menu.addItem(item15)

        item60 = NSMenuItem(title: "Keep awake for 60 minutes",
                            action: #selector(keepFor60(_:)), keyEquivalent: "")
        item60.target = self
        menu.addItem(item60)

        itemInfinite = NSMenuItem(title: "Keep awake indefinitely",
                                  action: #selector(keepInfinite(_:)), keyEquivalent: "")
        itemInfinite.target = self
        menu.addItem(itemInfinite)

        menu.addItem(.separator())

        displaySleepItem = NSMenuItem(title: "Allow display to sleep",
                                      action: #selector(toggleDisplaySleep(_:)), keyEquivalent: "")
        displaySleepItem.target = self
        menu.addItem(displaySleepItem)

        loginItem = NSMenuItem(title: "Start at Login",
                               action: #selector(toggleLoginItem(_:)), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let about = NSMenuItem(title: "About CoffeePot",
                               action: #selector(showAbout(_:)), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "Quit CoffeePot",
                              action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        // Keep a strong reference; we attach it on demand for right-click only.
        self.contextMenu = menu
    }

    private var contextMenu: NSMenu!

    // MARK: - Status button click handling

    @objc private func statusButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)

        if isRightClick {
            // Show the menu, then immediately detach so left-click still toggles.
            statusItem.menu = contextMenu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            // Left click: toggle using the last chosen duration.
            caffeine.toggle(duration: lastDuration)
        }
    }

    // MARK: - Actions

    @objc private func keepFor15(_ sender: Any?) {
        lastDuration = 15 * 60
        caffeine.activate(duration: lastDuration)
    }

    @objc private func keepFor60(_ sender: Any?) {
        lastDuration = 60 * 60
        caffeine.activate(duration: lastDuration)
    }

    @objc private func keepInfinite(_ sender: Any?) {
        lastDuration = nil
        caffeine.activate(duration: nil)
    }

    @objc private func toggleDisplaySleep(_ sender: Any?) {
        // The controller re-asserts in place if active, preserving the running
        // deadline, and fires onStateChange so the UI refreshes.
        caffeine.keepDisplayAwake.toggle()
        if !caffeine.isActive {
            refreshUI() // idle: no state-change callback, refresh the checkmark
        }
    }

    @objc private func toggleLoginItem(_ sender: Any?) {
        LoginItem.setEnabled(!LoginItem.isEnabled)
        refreshUI()
    }

    @objc private func showAbout(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "CoffeePot"
        alert.informativeText = """
        Keeps your Mac awake.

        Left-click the coffee pot to start/stop.
        Right-click for durations and options.

        Uses IOKit power assertions, so no background \
        processes are left behind.
        """
        alert.alertStyle = .informational
        if let icon = StatusIcon.appIconImage() {
            alert.icon = icon
        }
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit(_ sender: Any?) {
        caffeine.deactivate()
        NSApp.terminate(nil)
    }

    // MARK: - UI refresh

    /// Full refresh: regenerate the icon and rebuild every menu/checkmark.
    /// Called only on genuine state changes (activate/deactivate/policy/login).
    private func refreshUI() {
        let active = caffeine.isActive
        statusItem.button?.image = StatusIcon.image(active: active)

        refreshDynamicText()

        // Checkmarks reflect which duration is currently active.
        item15.state = (active && lastDuration == 15 * 60) ? .on : .off
        item60.state = (active && lastDuration == 60 * 60) ? .on : .off
        itemInfinite.state = (active && lastDuration == nil) ? .on : .off

        displaySleepItem.state = caffeine.keepDisplayAwake ? .off : .on
        loginItem.state = LoginItem.isEnabled ? .on : .off
    }

    /// Cheap refresh: only the dynamic countdown text (status line, tooltip,
    /// accessibility value). Safe to call once a second without redrawing art.
    private func refreshDynamicText() {
        let status: String
        if caffeine.isActive {
            if let remaining = caffeine.remaining {
                status = "Awake, \(Self.format(remaining)) left"
            } else {
                status = "Awake indefinitely"
            }
        } else {
            status = "Idle (your Mac can sleep)"
        }

        statusMenuItem.title = status
        statusItem.button?.toolTip = "CoffeePot: \(status.lowercased())"
        statusItem.button?.setAccessibilityValue(status)
    }

    private static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
