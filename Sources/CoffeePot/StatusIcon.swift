import AppKit
import CoreGraphics

/// Draws the CoffeePot menu-bar icon (a tall percolator coffee pot) and the
/// app/about icon. The status image is a *template* image: macOS ignores its
/// colour and re-tints it to match the menu bar, so we always draw in black
/// and vary only the alpha / fill style between states.
enum StatusIcon {

    /// Point size of the menu-bar image. macOS renders @2x automatically.
    private static let menuBarPointSize: CGFloat = 18

    // MARK: - Public

    /// The status-bar image for the given state. A solid, full-strength coffee
    /// pot when active (your Mac is being kept awake); the same silhouette
    /// faded to ~50% when idle. Both are template images so the system tints
    /// them for light/dark menu bars. The alpha we bake in becomes the mask
    /// strength, so the idle pot reads as a faded "off" version.
    static func image(active: Bool) -> NSImage {
        let size = NSSize(width: menuBarPointSize, height: menuBarPointSize)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setAlpha(active ? 1.0 : 0.5)
            drawCoffeePot(in: rect, context: ctx, filled: true)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// A larger, non-template icon for the About panel.
    static func appIconImage() -> NSImage? {
        let size = NSSize(width: 128, height: 128)
        return NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setFillColor(NSColor.black.cgColor)
            drawCoffeePot(in: rect, context: ctx, filled: true)
            return true
        }
    }

    // MARK: - Drawing
    //
    // Geometry adapted from the rendered percolator candidate: a tall,
    // slightly-tapered cylindrical body, a domed lid with a glass knob, a long
    // curved spout rising on the right, and a chunky C-handle on the left.
    // The icon is always drawn as a solid silhouette; the active/idle
    // distinction is done by the caller via alpha. `filled == false` keeps a
    // simple stroked fallback for completeness but is unused by the status bar.

    static func drawCoffeePot(in rect: CGRect, context ctx: CGContext, filled: Bool) {
        let inset = rect.width * 0.08
        let avail = min(rect.width, rect.height) - inset * 2
        let s = avail / 100.0
        // Centre the 100x100 design space inside rect.
        let ox = rect.minX + (rect.width - avail) / 2
        let oy = rect.minY + (rect.height - avail) / 2
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }

        ctx.saveGState()
        ctx.setShouldAntialias(true)

        let cx: CGFloat = 40

        // Body vertical extents.
        let footY: CGFloat = 6
        let baseY: CGFloat = 11
        let shoulderY: CGFloat = 70
        let baseHalf: CGFloat = 22
        let topHalf: CGFloat = 17

        // Lid / dome.
        let rimY: CGFloat = 70
        let rimHalf: CGFloat = 19
        let domeTopY: CGFloat = 80

        // Knob.
        let knobBottomY: CGFloat = 79
        let knobTopY: CGFloat = 90
        let knobHalf: CGFloat = 5.5

        // ---- Body + lid + knob: one closed contour ----
        let body = CGMutablePath()
        body.move(to: P(cx + baseHalf, baseY))
        body.addLine(to: P(cx + baseHalf + 2, footY))
        body.addLine(to: P(cx - baseHalf - 2, footY))
        body.addLine(to: P(cx - baseHalf, baseY))
        body.addCurve(to: P(cx - topHalf, shoulderY),
                      control1: P(cx - baseHalf + 1, baseY + 24),
                      control2: P(cx - topHalf - 1, shoulderY - 26))
        body.addLine(to: P(cx - rimHalf, rimY))
        body.addCurve(to: P(cx - knobHalf, knobBottomY),
                      control1: P(cx - rimHalf, domeTopY),
                      control2: P(cx - knobHalf - 7, domeTopY + 1))
        body.addLine(to: P(cx - knobHalf, knobTopY - 3))
        body.addCurve(to: P(cx + knobHalf, knobTopY - 3),
                      control1: P(cx - knobHalf, knobTopY + 3),
                      control2: P(cx + knobHalf, knobTopY + 3))
        body.addLine(to: P(cx + knobHalf, knobBottomY))
        body.addCurve(to: P(cx + rimHalf, rimY),
                      control1: P(cx + knobHalf + 7, domeTopY + 1),
                      control2: P(cx + rimHalf, domeTopY))
        body.addLine(to: P(cx + topHalf, shoulderY))
        body.addCurve(to: P(cx + baseHalf, baseY),
                      control1: P(cx + topHalf + 1, shoulderY - 26),
                      control2: P(cx + baseHalf - 1, baseY + 24))
        body.closeSubpath()

        // ---- Spout: chunky, curved, rising up-and-out on the right ----
        let spout = CGMutablePath()
        let aOutX = cx + topHalf - 2
        let aOutY: CGFloat = 52
        let aInX = cx + baseHalf - 2
        let aInY: CGFloat = 34
        let tipX: CGFloat = cx + baseHalf + 28
        let tipHiY: CGFloat = 74
        let tipLoY: CGFloat = 66
        spout.move(to: P(aInX, aInY))
        spout.addCurve(to: P(tipX, tipLoY),
                       control1: P(aInX + 20, aInY + 4),
                       control2: P(tipX - 3, tipLoY - 12))
        spout.addLine(to: P(tipX + 3, tipHiY))
        spout.addCurve(to: P(aOutX, aOutY),
                       control1: P(tipX - 9, tipHiY - 6),
                       control2: P(aOutX + 16, aOutY + 8))
        spout.closeSubpath()

        // ---- Handle: chunky C-band on the left, with a real grip hole ----
        let handle = CGMutablePath()
        let hTopAttX = cx - topHalf + 1
        let hTopAttY: CGFloat = 62
        let hBotAttX = cx - baseHalf + 4
        let hBotAttY: CGFloat = 30
        let hOutX: CGFloat = cx - baseHalf - 20
        let band: CGFloat = 8
        handle.move(to: P(hTopAttX, hTopAttY))
        handle.addCurve(to: P(hOutX, (hTopAttY + hBotAttY) / 2 + 2),
                        control1: P(hTopAttX - 12, hTopAttY + 4),
                        control2: P(hOutX, hTopAttY - 2))
        handle.addCurve(to: P(hBotAttX, hBotAttY),
                        control1: P(hOutX, hBotAttY + 2),
                        control2: P(hBotAttX - 12, hBotAttY - 4))
        handle.addLine(to: P(hBotAttX + 2, hBotAttY + band))
        handle.addCurve(to: P(hOutX + band, (hTopAttY + hBotAttY) / 2 + 2),
                        control1: P(hBotAttX - 12 + band + 1, hBotAttY - 4 + band),
                        control2: P(hOutX + band, hBotAttY + 2 + band - 2))
        handle.addCurve(to: P(hTopAttX + 2, hTopAttY - band),
                        control1: P(hOutX + band, hTopAttY - 2 - band + 2),
                        control2: P(hTopAttX - 12 + band + 1, hTopAttY + 4 - band))
        handle.closeSubpath()

        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))

        if filled {
            // Solid silhouette. Body+spout union via winding; handle added with
            // even-odd so the grip hole stays open.
            let solid = CGMutablePath()
            solid.addPath(body)
            solid.addPath(spout)
            ctx.addPath(solid)
            ctx.fillPath(using: .winding)
            ctx.addPath(handle)
            ctx.fillPath(using: .evenOdd)
        } else {
            // Unused stroked fallback (status bar uses alpha-dimmed fill).
            let lw = max(1.0, rect.width * 0.085)
            ctx.setLineWidth(lw)
            ctx.setLineJoin(.round)
            ctx.setLineCap(.round)
            ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            ctx.addPath(body)
            ctx.addPath(spout)
            ctx.addPath(handle)
            ctx.strokePath()
        }

        ctx.restoreGState()
    }
}
