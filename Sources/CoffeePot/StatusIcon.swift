import AppKit

/// Provides the CoffeePot menu-bar icon (a moka pot) and the About-panel icon.
///
/// The menu-bar artwork is a single hand-authored, black-only SVG (`moka.svg`)
/// shipped in the app bundle. macOS loads SVGs natively, so we render it as a
/// *template* image: the system re-tints it to match light/dark menu bars. The
/// active vs. idle distinction is purely alpha (full strength when keeping the
/// Mac awake, faded when idle), which avoids needing a second piece of art.
enum StatusIcon {

    /// Point size of the menu-bar image. macOS renders @2x automatically.
    private static let menuBarPointSize: CGFloat = 18

    /// Opacity of the menu-bar glyph while idle (the Mac may sleep).
    private static let idleAlpha: CGFloat = 0.5

    /// The moka SVG, loaded once from the bundle and reused as a template image.
    private static let mokaTemplate: NSImage? = {
        guard let image = loadMoka() else { return nil }
        image.isTemplate = true
        return image
    }()

    // MARK: - Public

    /// The status-bar image for the given state: the moka at full strength when
    /// active, faded when idle. Always a template image so the system tints it
    /// for light/dark menu bars.
    static func image(active: Bool) -> NSImage {
        let side = menuBarPointSize
        let fraction = active ? 1.0 : idleAlpha
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            if let moka = mokaTemplate {
                moka.draw(in: rect, from: .zero, operation: .sourceOver, fraction: fraction)
            } else {
                drawFallback(in: rect, alpha: fraction)
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// The icon for the About panel. Prefer the real, full-colour app icon so
    /// it is legible in both light and dark appearances; fall back to the moka
    /// artwork if the app icon is somehow unavailable.
    static func appIconImage() -> NSImage? {
        let appIcon = NSApp.applicationIconImage
        if let appIcon, appIcon.size.width > 0 {
            return appIcon
        }
        return loadMoka()
    }

    // MARK: - Internals

    /// Loads a fresh, untinted `NSImage` from the bundled `moka.svg`.
    private static func loadMoka() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "moka", withExtension: "svg") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    /// Drawn only if the bundled SVG is somehow missing, so the status item is
    /// never blank. A plain black blob keeps the app usable.
    private static func drawFallback(in rect: CGRect, alpha: CGFloat) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.setAlpha(alpha)
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fillEllipse(in: rect.insetBy(dx: rect.width * 0.28, dy: rect.height * 0.18))
        ctx.restoreGState()
    }
}
