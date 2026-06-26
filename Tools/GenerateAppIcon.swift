// Generates AppIcon.icns from the production coffee-pot geometry.
// Run via the build script; not part of the app itself.
//
//   swiftc -O -framework AppKit -framework CoreGraphics -framework ImageIO \
//          -framework UniformTypeIdentifiers Tools/GenerateAppIcon.swift \
//          Sources/CoffeePot/StatusIcon.swift -o /tmp/genicon
//   /tmp/genicon <output-iconset-dir>
//
// Then: iconutil -c icns <iconset-dir> -o build/AppIcon.icns

import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Draw a macOS "squircle"-ish rounded-rect app icon tile with a warm coffee
// gradient and the coffee pot in white, with the standard ~10% transparent
// margin Apple uses around app icons.
func renderAppIcon(size: Int, to url: URL) -> Bool {
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                              bytesPerRow: 0, space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }

    let dim = CGFloat(size)
    // Apple icons have a transparent gutter; the rounded tile fills ~82%.
    let margin = dim * 0.09
    let tile = CGRect(x: margin, y: margin, width: dim - 2 * margin, height: dim - 2 * margin)
    let radius = tile.width * 0.225 // continuous-corner-ish radius

    ctx.saveGState()
    let rounded = CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(rounded)
    ctx.clip()

    // Warm espresso gradient background.
    let colors = [
        CGColor(red: 0.42, green: 0.26, blue: 0.15, alpha: 1.0), // top: latte brown
        CGColor(red: 0.20, green: 0.11, blue: 0.06, alpha: 1.0), // bottom: dark roast
    ] as CFArray
    if let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1]) {
        ctx.drawLinearGradient(grad,
                               start: CGPoint(x: tile.midX, y: tile.maxY),
                               end: CGPoint(x: tile.midX, y: tile.minY),
                               options: [])
    }
    ctx.restoreGState()

    // White coffee pot, inset within the tile.
    let potRect = tile.insetBy(dx: tile.width * 0.16, dy: tile.height * 0.16)
    ctx.saveGState()
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    StatusIcon.drawCoffeePot(in: potRect, context: ctx, filled: true)
    ctx.setBlendMode(.sourceIn)
    // Slightly warm white so it doesn't look clinical.
    ctx.setFillColor(CGColor(red: 0.98, green: 0.96, blue: 0.93, alpha: 1.0))
    ctx.fill(potRect)
    ctx.endTransparencyLayer()
    ctx.restoreGState()

    guard let img = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                     UTType.png.identifier as CFString, 1, nil) else { return false }
    CGImageDestinationAddImage(dest, img, nil)
    return CGImageDestinationFinalize(dest)
}

@main
struct Generator {
    static func main() {
        let args = CommandLine.arguments
        guard args.count >= 2 else {
            FileHandle.standardError.write("usage: genicon <output.iconset dir>\n".data(using: .utf8)!)
            exit(2)
        }
        let outDir = URL(fileURLWithPath: args[1], isDirectory: true)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        // Standard macOS iconset entries: (pixelSize, filename)
        let entries: [(Int, String)] = [
            (16, "icon_16x16.png"),
            (32, "icon_16x16@2x.png"),
            (32, "icon_32x32.png"),
            (64, "icon_32x32@2x.png"),
            (128, "icon_128x128.png"),
            (256, "icon_128x128@2x.png"),
            (256, "icon_256x256.png"),
            (512, "icon_256x256@2x.png"),
            (512, "icon_512x512.png"),
            (1024, "icon_512x512@2x.png"),
        ]

        var ok = true
        for (px, name) in entries {
            let url = outDir.appendingPathComponent(name)
            if !renderAppIcon(size: px, to: url) {
                FileHandle.standardError.write("failed: \(name)\n".data(using: .utf8)!)
                ok = false
            }
        }
        print(ok ? "iconset written to \(outDir.path)" : "iconset had errors")
        exit(ok ? 0 : 1)
    }
}
