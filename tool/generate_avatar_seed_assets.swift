import AppKit
import CoreGraphics
import Foundation

let canvasWidth = 512
let canvasHeight = 768
let roots = ["assets/avatar", "assets/avatar_parts"]

let skinTones = [0xF7D6BF, 0xE9BC9A, 0xD79B74, 0x9C643D, 0x6F472F, 0xFFC6A7]
let hairColors = [0x1F2937, 0x4B3621, 0x7C5A3B, 0xD4A017, 0x94A3B8, 0x1E3A5F, 0x8B5CF6, 0xF472B6]
let outfitColors = [0x7C6AE6, 0x4F8CFF, 0x10B981, 0xF59E0B, 0xEC4899, 0x64748B, 0xEF4444, 0x111827]
let backgroundColors = [0xEDE9FE, 0xDBEAFE, 0xD1FAE5, 0xFFEDD5, 0xFCE7F3, 0xE5E7EB, 0xFFF7ED, 0xE0F2FE]

func cgColor(_ hex: Int, alpha: CGFloat = 1) -> CGColor {
    let red = CGFloat((hex >> 16) & 0xff) / 255
    let green = CGFloat((hex >> 8) & 0xff) / 255
    let blue = CGFloat(hex & 0xff) / 255
    return CGColor(red: red, green: green, blue: blue, alpha: alpha)
}

func ensureFolder(_ path: String) {
    let folder = URL(fileURLWithPath: path).deletingLastPathComponent().path
    try? FileManager.default.createDirectory(
        atPath: folder,
        withIntermediateDirectories: true
    )
}

func writeLayer(_ relativePath: String, draw: (CGContext) -> Void) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: canvasWidth,
        pixelsHigh: canvasHeight,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: canvasWidth, height: canvasHeight)

    let graphics = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics

    let ctx = graphics.cgContext
    ctx.clear(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
    ctx.translateBy(x: 0, y: CGFloat(canvasHeight))
    ctx.scaleBy(x: 1, y: -1)
    draw(ctx)

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(relativePath)")
    }

    for root in roots {
        let path = "\(root)/\(relativePath)"
        ensureFolder(path)
        try! data.write(to: URL(fileURLWithPath: path))
    }
}

func fillEllipse(_ ctx: CGContext, _ rect: CGRect, _ color: CGColor) {
    ctx.setFillColor(color)
    ctx.fillEllipse(in: rect)
}

func fillRounded(_ ctx: CGContext, _ rect: CGRect, _ radius: CGFloat, _ color: CGColor) {
    let path = CGPath(
        roundedRect: rect,
        cornerWidth: radius,
        cornerHeight: radius,
        transform: nil
    )
    ctx.setFillColor(color)
    ctx.addPath(path)
    ctx.fillPath()
}

func strokeRounded(
    _ ctx: CGContext,
    _ rect: CGRect,
    _ radius: CGFloat,
    _ color: CGColor,
    width: CGFloat
) {
    let path = CGPath(
        roundedRect: rect,
        cornerWidth: radius,
        cornerHeight: radius,
        transform: nil
    )
    ctx.setStrokeColor(color)
    ctx.setLineWidth(width)
    ctx.addPath(path)
    ctx.strokePath()
}

func fillPath(_ ctx: CGContext, _ color: CGColor, _ build: (CGMutablePath) -> Void) {
    let path = CGMutablePath()
    build(path)
    ctx.setFillColor(color)
    ctx.addPath(path)
    ctx.fillPath()
}

func strokePath(
    _ ctx: CGContext,
    _ color: CGColor,
    width: CGFloat,
    _ build: (CGMutablePath) -> Void
) {
    let path = CGMutablePath()
    build(path)
    ctx.setStrokeColor(color)
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(path)
    ctx.strokePath()
}

func drawBackground(index: Int, base: Int) {
    writeLayer("backgrounds/background_\(index).png") { ctx in
        let colors = [
            cgColor(base, alpha: 0.95),
            cgColor(0xFFFFFF, alpha: 0.88),
            cgColor(index % 2 == 0 ? 0xBFFAF0 : 0xE8D5FF, alpha: 0.72)
        ] as CFArray
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 0.55, 1]
        )!
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 80, y: 80),
            end: CGPoint(x: 450, y: 720),
            options: []
        )
        fillEllipse(ctx, CGRect(x: 330, y: 86, width: 190, height: 190), cgColor(0xFFFFFF, alpha: 0.18))
        fillEllipse(ctx, CGRect(x: -36, y: 560, width: 220, height: 220), cgColor(0x22D3EE, alpha: 0.10))
        fillEllipse(ctx, CGRect(x: 88, y: 116, width: 18, height: 18), cgColor(0xFFFFFF, alpha: 0.48))
        fillEllipse(ctx, CGRect(x: 410, y: 240, width: 12, height: 12), cgColor(0xFFFFFF, alpha: 0.42))
    }
}

func drawBase(index: Int, skin: Int) {
    writeLayer("base/body_skin_\(index).png") { ctx in
        fillEllipse(ctx, CGRect(x: 168, y: 672, width: 176, height: 28), cgColor(0x000000, alpha: 0.12))
        fillRounded(ctx, CGRect(x: 210, y: 596, width: 44, height: 96), 18, cgColor(0x4A3F88, alpha: 0.95))
        fillRounded(ctx, CGRect(x: 262, y: 596, width: 44, height: 96), 18, cgColor(0x4A3F88, alpha: 0.95))
        fillRounded(ctx, CGRect(x: 192, y: 682, width: 70, height: 24), 12, cgColor(0x1C2435, alpha: 0.96))
        fillRounded(ctx, CGRect(x: 254, y: 682, width: 70, height: 24), 12, cgColor(0x1C2435, alpha: 0.96))
        fillRounded(ctx, CGRect(x: 226, y: 300, width: 62, height: 98), 28, cgColor(skin))
        fillRounded(ctx, CGRect(x: 126, y: 365, width: 72, height: 220), 34, cgColor(skin))
        fillRounded(ctx, CGRect(x: 314, y: 365, width: 72, height: 220), 34, cgColor(skin))
        fillEllipse(ctx, CGRect(x: 126, y: 552, width: 62, height: 62), cgColor(skin))
        fillEllipse(ctx, CGRect(x: 324, y: 552, width: 62, height: 62), cgColor(skin))
    }
}

func drawFace(skinIndex: Int, skin: Int) {
    writeLayer("faces/face_0_skin_\(skinIndex).png") { ctx in
        fillEllipse(ctx, CGRect(x: 132, y: 130, width: 248, height: 266), cgColor(skin))
        fillEllipse(ctx, CGRect(x: 112, y: 235, width: 48, height: 62), cgColor(skin))
        fillEllipse(ctx, CGRect(x: 352, y: 235, width: 48, height: 62), cgColor(skin))
        fillEllipse(ctx, CGRect(x: 160, y: 152, width: 74, height: 42), cgColor(0xFFFFFF, alpha: 0.18))
    }
}

func drawHair(colorIndex: Int, hair: Int) {
    writeLayer("hair_back/hair_0_color_\(colorIndex).png") { ctx in
        fillPath(ctx, cgColor(hair)) { path in
            path.move(to: CGPoint(x: 128, y: 244))
            path.addCurve(to: CGPoint(x: 158, y: 116), control1: CGPoint(x: 124, y: 178), control2: CGPoint(x: 138, y: 134))
            path.addCurve(to: CGPoint(x: 352, y: 118), control1: CGPoint(x: 204, y: 78), control2: CGPoint(x: 314, y: 80))
            path.addCurve(to: CGPoint(x: 384, y: 248), control1: CGPoint(x: 376, y: 140), control2: CGPoint(x: 392, y: 184))
            path.addCurve(to: CGPoint(x: 350, y: 354), control1: CGPoint(x: 384, y: 294), control2: CGPoint(x: 374, y: 330))
            path.addCurve(to: CGPoint(x: 140, y: 354), control1: CGPoint(x: 292, y: 390), control2: CGPoint(x: 192, y: 388))
            path.addCurve(to: CGPoint(x: 128, y: 244), control1: CGPoint(x: 124, y: 318), control2: CGPoint(x: 122, y: 282))
            path.closeSubpath()
        }
    }
    writeLayer("hair_front/hair_0_color_\(colorIndex).png") { ctx in
        fillPath(ctx, cgColor(hair)) { path in
            path.move(to: CGPoint(x: 134, y: 210))
            path.addCurve(to: CGPoint(x: 184, y: 112), control1: CGPoint(x: 138, y: 158), control2: CGPoint(x: 158, y: 126))
            path.addCurve(to: CGPoint(x: 340, y: 112), control1: CGPoint(x: 230, y: 92), control2: CGPoint(x: 306, y: 92))
            path.addCurve(to: CGPoint(x: 382, y: 210), control1: CGPoint(x: 366, y: 132), control2: CGPoint(x: 382, y: 168))
            path.addCurve(to: CGPoint(x: 310, y: 190), control1: CGPoint(x: 352, y: 196), control2: CGPoint(x: 332, y: 188))
            path.addCurve(to: CGPoint(x: 244, y: 250), control1: CGPoint(x: 296, y: 222), control2: CGPoint(x: 278, y: 244))
            path.addCurve(to: CGPoint(x: 206, y: 190), control1: CGPoint(x: 226, y: 230), control2: CGPoint(x: 214, y: 210))
            path.addCurve(to: CGPoint(x: 134, y: 210), control1: CGPoint(x: 182, y: 200), control2: CGPoint(x: 158, y: 205))
            path.closeSubpath()
        }
        strokePath(ctx, cgColor(0xFFFFFF, alpha: 0.16), width: 8) { path in
            path.move(to: CGPoint(x: 206, y: 128))
            path.addCurve(to: CGPoint(x: 282, y: 120), control1: CGPoint(x: 230, y: 114), control2: CGPoint(x: 260, y: 112))
        }
    }
}

func drawFaceFeatures() {
    writeLayer("eyes/eyes_0.png") { ctx in
        fillEllipse(ctx, CGRect(x: 194, y: 270, width: 34, height: 44), cgColor(0x101827))
        fillEllipse(ctx, CGRect(x: 284, y: 270, width: 34, height: 44), cgColor(0x101827))
        fillEllipse(ctx, CGRect(x: 206, y: 280, width: 8, height: 10), cgColor(0xFFFFFF, alpha: 0.78))
        fillEllipse(ctx, CGRect(x: 296, y: 280, width: 8, height: 10), cgColor(0xFFFFFF, alpha: 0.78))
    }
    writeLayer("eyebrows/eyebrows_0.png") { ctx in
        strokePath(ctx, cgColor(0x101827), width: 10) { path in
            path.move(to: CGPoint(x: 184, y: 248))
            path.addCurve(to: CGPoint(x: 232, y: 244), control1: CGPoint(x: 198, y: 238), control2: CGPoint(x: 218, y: 238))
            path.move(to: CGPoint(x: 280, y: 244))
            path.addCurve(to: CGPoint(x: 328, y: 248), control1: CGPoint(x: 294, y: 238), control2: CGPoint(x: 314, y: 238))
        }
    }
    writeLayer("mouths/mouth_0.png") { ctx in
        strokePath(ctx, cgColor(0xB45353), width: 8) { path in
            path.move(to: CGPoint(x: 218, y: 346))
            path.addCurve(to: CGPoint(x: 294, y: 346), control1: CGPoint(x: 236, y: 370), control2: CGPoint(x: 276, y: 370))
        }
    }
}

func drawOutfit(colorIndex: Int, outfit: Int) {
    writeLayer("outfits/outfit_0_color_\(colorIndex).png") { ctx in
        let darker = colorShift(outfit, amount: -0.22)
        fillRounded(ctx, CGRect(x: 160, y: 374, width: 192, height: 220), 42, cgColor(outfit))
        fillRounded(ctx, CGRect(x: 118, y: 374, width: 80, height: 176), 34, cgColor(outfit))
        fillRounded(ctx, CGRect(x: 314, y: 374, width: 80, height: 176), 34, cgColor(outfit))
        fillEllipse(ctx, CGRect(x: 214, y: 392, width: 84, height: 58), cgColor(0xFFFFFF, alpha: 0.12))
        fillRounded(ctx, CGRect(x: 210, y: 596, width: 44, height: 96), 18, cgColor(darker))
        fillRounded(ctx, CGRect(x: 262, y: 596, width: 44, height: 96), 18, cgColor(darker))
        strokeRounded(ctx, CGRect(x: 170, y: 384, width: 172, height: 198), 38, cgColor(0xFFFFFF, alpha: 0.18), width: 5)
        strokePath(ctx, cgColor(0xFFFFFF, alpha: 0.38), width: 5) { path in
            path.move(to: CGPoint(x: 206, y: 386))
            path.addLine(to: CGPoint(x: 256, y: 430))
            path.addLine(to: CGPoint(x: 306, y: 386))
        }
    }
}

func colorShift(_ hex: Int, amount: CGFloat) -> Int {
    func shift(_ channel: Int) -> Int {
        let value = CGFloat(channel)
        let adjusted = amount >= 0 ? value + (255 - value) * amount : value * (1 + amount)
        return max(0, min(255, Int(adjusted.rounded())))
    }
    let red = shift((hex >> 16) & 0xff)
    let green = shift((hex >> 8) & 0xff)
    let blue = shift(hex & 0xff)
    return (red << 16) + (green << 8) + blue
}

func drawAccessories() {
    writeLayer("accessories/accessory_1.png") { ctx in
        fillPath(ctx, cgColor(0xFACC15)) { path in
            path.move(to: CGPoint(x: 390, y: 120))
            path.addLine(to: CGPoint(x: 408, y: 156))
            path.addLine(to: CGPoint(x: 444, y: 174))
            path.addLine(to: CGPoint(x: 408, y: 192))
            path.addLine(to: CGPoint(x: 390, y: 228))
            path.addLine(to: CGPoint(x: 372, y: 192))
            path.addLine(to: CGPoint(x: 336, y: 174))
            path.addLine(to: CGPoint(x: 372, y: 156))
            path.closeSubpath()
        }
    }
    writeLayer("accessories/accessory_2.png") { ctx in
        strokePath(ctx, cgColor(0x4F46E5), width: 12) { path in
            path.move(to: CGPoint(x: 150, y: 280))
            path.addCurve(to: CGPoint(x: 362, y: 280), control1: CGPoint(x: 168, y: 146), control2: CGPoint(x: 344, y: 146))
        }
        fillRounded(ctx, CGRect(x: 124, y: 270, width: 34, height: 72), 14, cgColor(0x4F46E5))
        fillRounded(ctx, CGRect(x: 354, y: 270, width: 34, height: 72), 14, cgColor(0x4F46E5))
    }
    writeLayer("accessories/accessory_3.png") { ctx in
        fillRounded(ctx, CGRect(x: 340, y: 430, width: 72, height: 92), 10, cgColor(0x60A5FA))
        fillRounded(ctx, CGRect(x: 350, y: 440, width: 52, height: 72), 7, cgColor(0xFFFFFF, alpha: 0.86))
        strokePath(ctx, cgColor(0x2563EB), width: 4) { path in
            path.move(to: CGPoint(x: 360, y: 462))
            path.addLine(to: CGPoint(x: 392, y: 462))
            path.move(to: CGPoint(x: 360, y: 482))
            path.addLine(to: CGPoint(x: 392, y: 482))
        }
    }
}

for (index, color) in backgroundColors.enumerated() {
    drawBackground(index: index, base: color)
}

for (index, skin) in skinTones.enumerated() {
    drawBase(index: index, skin: skin)
    drawFace(skinIndex: index, skin: skin)
}

for (index, hair) in hairColors.enumerated() {
    drawHair(colorIndex: index, hair: hair)
}

drawFaceFeatures()

for (index, outfit) in outfitColors.enumerated() {
    drawOutfit(colorIndex: index, outfit: outfit)
}

drawAccessories()

print("Generated Nudge avatar seed assets.")
