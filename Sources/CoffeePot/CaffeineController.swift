import Foundation
import IOKit.pwr_mgt

/// Holds an IOKit power-management assertion that prevents the system (and,
/// optionally, the display) from sleeping. The assertion is released
/// automatically if the process dies, so we never leave a stale `caffeinate`
/// process lingering the way spawning the CLI tool would.
final class CaffeineController {

    /// Fired on the main thread when the active/idle state changes (activate or
    /// deactivate). The UI uses this to redraw the icon and rebuild menu state.
    var onStateChange: (() -> Void)?

    /// Fired roughly once a second *while a timed session is running*, so the
    /// menu can show a live countdown. Cheaper than `onStateChange`: it should
    /// only refresh dynamic text, not regenerate the icon.
    var onTick: (() -> Void)?

    private(set) var isActive = false
    private(set) var endDate: Date?

    private var assertionID = IOPMAssertionID(0)
    private var timer: Timer?

    /// Whether to also keep the *display* awake. When false we only prevent
    /// system idle sleep (the screen may still dim/sleep). Flipping this while a
    /// session is active re-asserts in place, preserving the existing deadline.
    var keepDisplayAwake = true {
        didSet {
            guard isActive, keepDisplayAwake != oldValue else { return }
            createAssertion() // keeps endDate and the running timer untouched
            notifyStateChange()
        }
    }

    var remaining: TimeInterval? {
        guard let endDate else { return nil }
        return max(0, endDate.timeIntervalSinceNow)
    }

    // MARK: - Public control

    /// Activate for `duration` seconds, or indefinitely when `duration` is nil
    /// or non-positive.
    func activate(duration: TimeInterval?) {
        if let duration, duration > 0 {
            endDate = Date().addingTimeInterval(duration)
        } else {
            endDate = nil // indefinite
        }

        createAssertion()

        if isActive {
            startTimerIfNeeded()
        } else {
            endDate = nil // assertion failed; createAssertion already reset state
        }

        notifyStateChange()
    }

    func deactivate() {
        releaseAssertion()
        invalidateTimer()
        isActive = false
        endDate = nil
        notifyStateChange()
    }

    /// Toggle: if already running, stop; otherwise start with `duration`.
    func toggle(duration: TimeInterval?) {
        if isActive {
            deactivate()
        } else {
            activate(duration: duration)
        }
    }

    /// Re-evaluate expiry immediately. Called on system wake, since a run-loop
    /// timer does not fire while the machine is asleep even though wall-clock
    /// time (and thus `endDate`) keeps advancing.
    func checkExpiryNow() {
        guard isActive, let endDate else { return }
        if Date() >= endDate {
            deactivate()
        }
    }

    // MARK: - Internals

    /// Create (or re-create) the assertion using the current `keepDisplayAwake`
    /// policy. Releases any existing assertion first so switching policy or
    /// duration never leaks. On failure, resets to the inactive state.
    private func createAssertion() {
        releaseAssertion()

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
            assertionID = IOPMAssertionID(0)
            isActive = false
            endDate = nil
            invalidateTimer()
            return
        }

        assertionID = id
        isActive = true
    }

    /// Start the 1 Hz countdown/expiry timer, but only for a *timed* session.
    /// Indefinite sessions need no timer at all, which avoids waking the CPU
    /// every second for nothing.
    private func startTimerIfNeeded() {
        invalidateTimer()
        guard let end = endDate else { return }

        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if Date() >= end {
                self.deactivate()
            } else {
                self.onTick?()
            }
        }
        // Common run-loop mode so it keeps firing while menus are open.
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

    private func notifyStateChange() {
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
