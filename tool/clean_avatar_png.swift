import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Job {
    let source: String
    let destination: String
}

let arguments = Array(CommandLine.arguments.dropFirst())

guard arguments.count >= 2, arguments.count % 2 == 0 else {
    fputs(
        "Usage: swift tool/clean_avatar_png.swift <source.png> <destination.png> [<source.png> <destination.png> ...]\n",
        stderr,
    )
    exit(64)
}

let jobs = stride(from: 0, to: arguments.count, by: 2).map {
    Job(source: arguments[$0], destination: arguments[$0 + 1])
}

let width = 512
let height = 768
let alphaThreshold = 20

func clean(job: Job) throws {
    let sourceURL = URL(fileURLWithPath: job.source)
    let destinationURL = URL(fileURLWithPath: job.destination)

    guard
        let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw NSError(
            domain: "clean_avatar_png",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Unable to read \(job.source)"],
        )
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
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
        )
    else {
        throw NSError(
            domain: "clean_avatar_png",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Unable to create context"],
        )
    }

    context.interpolationQuality = .high
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    var kept = 0
    var cleared = 0
    for index in 0..<(width * height) {
        let offset = index * 4
        if Int(data[offset + 3]) <= alphaThreshold {
            data[offset] = 0
            data[offset + 1] = 0
            data[offset + 2] = 0
            data[offset + 3] = 0
            cleared += 1
        } else {
            kept += 1
        }
    }

    guard
        let outputImage = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil,
        )
    else {
        throw NSError(
            domain: "clean_avatar_png",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Unable to create output image"],
        )
    }

    CGImageDestinationAddImage(destination, outputImage, nil)
    if !CGImageDestinationFinalize(destination) {
        throw NSError(
            domain: "clean_avatar_png",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Unable to write \(job.destination)"],
        )
    }

    print("\(job.destination) kept=\(kept) cleared=\(cleared)")
}

do {
    for job in jobs {
        try clean(job: job)
    }
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
