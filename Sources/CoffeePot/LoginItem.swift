import Foundation
import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` for the "Start at Login" toggle.
/// Available on macOS 13+. Registration only sticks when the app runs from a
/// stable location such as /Applications.
enum LoginItem {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("CoffeePot: failed to toggle login item: \(error)")
        }
    }
}
