// Renders the Zap app icon to a 1024x1024 PNG.
// Usage: swift contrib/make-icon.swift out.png
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.dropFirst().first ?? "icon.png"

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8,
                    bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

func gradient(_ stops: [(UInt32, CGFloat)]) -> CGGradient {
    CGGradient(colorsSpace: cs, colors: stops.map { rgb($0.0) } as CFArray,
               locations: stops.map { $0.1 })!
}

// Background tile: Apple's icon grid puts an 824pt rounded square in a 1024 canvas.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

// Drop shadow under the tile.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.45))
ctx.addPath(tilePath)
ctx.setFillColor(rgb(0x000000))
ctx.fillPath()
ctx.restoreGState()

// Deep night-sky gradient.
ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()
ctx.drawLinearGradient(gradient([(0x2a1b5e, 0), (0x120c2e, 0.55), (0x05040f, 1)]),
                       start: CGPoint(x: 300, y: 924), end: CGPoint(x: 724, y: 100),
                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
// Purple-blue glow behind the bolt.
ctx.drawRadialGradient(
    CGGradient(colorsSpace: cs, colors: [rgb(0x8a6bff, 0.7), rgb(0x7b5cff, 0)] as CFArray,
               locations: [0, 1])!,
    startCenter: CGPoint(x: 512, y: 520), startRadius: 0,
    endCenter: CGPoint(x: 512, y: 520), endRadius: 420, options: [])
ctx.restoreGState()

// Lightning bolt (y grows upward in CoreGraphics).
let bolt = CGMutablePath()
let pts: [CGPoint] = [
    CGPoint(x: 590, y: 850),  // top
    CGPoint(x: 300, y: 470),
    CGPoint(x: 500, y: 470),
    CGPoint(x: 420, y: 170),  // bottom tip
    CGPoint(x: 730, y: 580),
    CGPoint(x: 530, y: 580),
]
bolt.addLines(between: pts)
bolt.closeSubpath()

// Neon glow, layered from a wide halo to a hot core. Clipped so it stays on the tile.
ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()
for (blur, alpha) in [(140.0, 1.0), (70.0, 1.0), (25.0, 1.0)] {
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: blur, color: rgb(0xffb020, alpha))
    ctx.addPath(bolt)
    ctx.setFillColor(rgb(0xffc83a))
    ctx.fillPath()
    ctx.restoreGState()
}
ctx.restoreGState()

// Bolt fill: pale yellow at the top to hot orange at the tip.
ctx.saveGState()
ctx.addPath(bolt)
ctx.clip()
ctx.drawLinearGradient(gradient([(0xfffbd0, 0), (0xffd83a, 0.45), (0xff8a00, 1)]),
                       start: CGPoint(x: 590, y: 850), end: CGPoint(x: 420, y: 170), options: [])
ctx.restoreGState()

// Thin bright edge.
ctx.addPath(bolt)
ctx.setStrokeColor(rgb(0xffffff, 0.55))
ctx.setLineWidth(6)
ctx.setLineJoin(.round)
ctx.strokePath()

// Soft glass highlight on the top half of the tile.
ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()
ctx.drawLinearGradient(
    CGGradient(colorsSpace: cs, colors: [rgb(0xffffff, 0.12), rgb(0xffffff, 0)] as CFArray,
               locations: [0, 1])!,
    start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 560), options: [])
ctx.restoreGState()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
