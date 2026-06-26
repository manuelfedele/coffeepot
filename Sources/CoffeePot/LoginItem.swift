import AppKit
import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` for the "Start at Login" toggle.
/// Available on macOS 13+. Registration only sticks when the app runs from a
/// stable location such as /Applications.
enum LoginItem {

    /// True when the login item is actively registered. Note that macOS may
    /// also report `.requiresApproval` (user must enable it in System Settings);
    /// that is treated as "not enabled" here but surfaced to the user on toggle.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Toggle registration. Returns true on success. On failure (or when macOS
    /// requires the user to approve the item in System Settings), shows an
    /// explanatory alert so the menu checkmark never silently lies.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
                // Registration can land in "requires approval" rather than
                // "enabled"; tell the user where to flip the switch.
                if SMAppService.mainApp.status == .requiresApproval {
                    presentApprovalNeeded()
                    return false
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            return true
        } catch {
            NSLog("CoffeePot: failed to toggle login item: \(error)")
            presentError(error, enabling: enabled)
            return false
        }
    }

    // MARK: - Alerts

    private static func presentApprovalNeeded() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Approval needed"
        alert.informativeText = "Enable CoffeePot under System Settings ▸ "
            + "General ▸ Login Items to have it start automatically at login."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Login Items")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    private static func presentError(_ error: Error, enabling: Bool) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = enabling
            ? "Couldn’t enable Start at Login"
            : "Couldn’t disable Start at Login"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
