import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 6 else {
    fputs(
        "Usage: swift tool/recolor_avatar_asset.swift <source.png> <destination.png> <red> <green> <blue>\n",
        stderr
    )
    exit(64)
}

let sourcePath = CommandLine.arguments[1]
let destinationPath = CommandLine.arguments[2]
let tint = (
    r: Double(CommandLine.arguments[3]) ?? 255,
    g: Double(CommandLine.arguments[4]) ?? 255,
    b: Double(CommandLine.arguments[5]) ?? 255
)
let width = 512
let height = 768

guard
    let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: sourcePath) as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    fputs("Unable to read \(sourcePath)\n", stderr)
    exit(1)
}

var data = [UInt8](repeating: 0, count: width * height * 4)
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard
    let context = CGContext(
        data: &data,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
else {
    fputs("Unable to create bitmap context\n", stderr)
    exit(1)
}

context.interpolationQuality = .high
context.clear(CGRect(x: 0, y: 0, width: width, height: height))
context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

for index in 0..<(width * height) {
    let offset = index * 4
    let alpha = Double(data[offset + 3]) / 255.0
    if alpha <= 0.08 {
        data[offset] = 0
        data[offset + 1] = 0
        data[offset + 2] = 0
        data[offset + 3] = 0
        continue
    }

    let r = Double(data[offset])
    let g = Double(data[offset + 1])
    let b = Double(data[offset + 2])
    let maxChannel = max(r, max(g, b))
    let minChannel = min(r, min(g, b))
    let saturation = maxChannel <= 0 ? 0 : (maxChannel - minChannel) / maxChannel
    let brightness = maxChannel / 255.0

    if saturation > 0.12 && brightness > 0.16 {
        let shade = 0.62 + brightness * 0.46
        data[offset] = UInt8(min(255, tint.r * shade))
        data[offset + 1] = UInt8(min(255, tint.g * shade))
        data[offset + 2] = UInt8(min(255, tint.b * shade))
    }
}

guard
    let outputImage = context.makeImage(),
    let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: destinationPath) as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    )
else {
    fputs("Unable to prepare \(destinationPath)\n", stderr)
    exit(1)
}

CGImageDestinationAddImage(destination, outputImage, nil)
if !CGImageDestinationFinalize(destination) {
    fputs("Unable to write \(destinationPath)\n", stderr)
    exit(1)
}

print("Wrote \(destinationPath)")
