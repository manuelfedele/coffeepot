import Foundation
import IOKit.pwr_mgt

/// Holds an IOKit power-management assertion that prevents the system (and,
/// optionally, the display) from sleeping. The assertion is released
/// automatically if the process dies, so we never leave a stale `caffeinate`
/// process lingering the way spawning the CLI tool would.
final class CaffeineController {

    /// Called on the main thread whenever the active/inactive state changes,
    /// so the UI can refresh.
    var onStateChange: (() -> Void)?

    private(set) var isActive = false
    private(set) var endDate: Date?

    private var assertionID: IOPMAssertionID = IOPMAssertionID(0)
    private var timer: Timer?

    /// Whether to also keep the *display* awake. When false we only prevent
    /// system idle sleep (screen may still dim/sleep).
    var keepDisplayAwake = true

    var remaining: TimeInterval? {
        guard let endDate else { return nil }
        return max(0, endDate.timeIntervalSinceNow)
    }

    // MARK: - Public control

    /// Activate for `duration` seconds, or indefinitely when `duration` is nil.
    func activate(duration: TimeInterval?) {
        // Re-assert cleanly so toggling between durations always works.
        releaseAssertion()
        invalidateTimer()

        let assertionType = keepDisplayAwake
            ? kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString
            : kIOPMAssertionTypePreventUserIdleSystemSleep as CFString

        var id = IOPMAssertionID(0)
        let reason = "CoffeePot is keeping your Mac awake" as CFString
        let result = IOPMAssertionCreateWithName(
            assertionType,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &id
        )

        guard result == kIOReturnSuccess else {
            isActive = false
            endDate = nil
            notify()
            return
        }

        assertionID = id
        isActive = true

        if let duration, duration > 0 {
            let end = Date().addingTimeInterval(duration)
            endDate = end
            scheduleExpiry(at: end)
        } else {
            endDate = nil // indefinite
        }

        notify()
    }

    func deactivate() {
        releaseAssertion()
        invalidateTimer()
        isActive = false
        endDate = nil
        notify()
    }

    /// Toggle: if already running, stop; otherwise start with `duration`.
    func toggle(duration: TimeInterval?) {
        if isActive {
            deactivate()
        } else {
            activate(duration: duration)
        }
    }

    // MARK: - Internals

    private func scheduleExpiry(at end: Date) {
        // Fire every second so the menu can show a live countdown, and stop
        // when we pass the end date.
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if Date() >= end {
                self.deactivate()
            } else {
                self.notify()
            }
        }
        // Common run loop mode so it keeps firing while menus are open.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func releaseAssertion() {
        if assertionID != IOPMAssertionID(0) {
            IOPMAssertionRelease(assertionID)
            assertionID = IOPMAssertionID(0)
        }
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func notify() {
        if Thread.isMainThread {
            onStateChange?()
        } else {
            DispatchQueue.main.async { [weak self] in self?.onStateChange?() }
        }
    }

    deinit {
        releaseAssertion()
        invalidateTimer()
    }
}
