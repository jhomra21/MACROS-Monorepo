#!/usr/bin/swift
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

private let colors: [(red: CGFloat, green: CGFloat, blue: CGFloat)] = [
    (36.0 / 255, 102.0 / 255, 230.0 / 255),
    (235.0 / 255, 128.0 / 255, 5.0 / 255),
    (230.0 / 255, 46.0 / 255, 112.0 / 255),
]
private let progress: [CGFloat] = [0.78, 0.64, 0.50]
private let outerDiameter: CGFloat = 1024 * 0.62
private let lineWidth = outerDiameter * 0.08
private let overlap = 1024 * 0.004
private let outputColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

private enum Appearance: Equatable {
    case light, dark, tinted

    var background: (CGFloat, CGFloat, CGFloat) {
        switch self {
        case .light: (0.96, 0.96, 0.97)
        case .dark: (0.055, 0.055, 0.06)
        case .tinted: (0, 0, 0)
        }
    }

    var trackRingOpacity: CGFloat {
        switch self {
        case .light: 0.20
        case .dark: 0.275
        case .tinted: 0.75
        }
    }
}

private func rgb(_ color: (CGFloat, CGFloat, CGFloat), alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: outputColorSpace, components: [color.0, color.1, color.2, alpha])!
}

private func drawIcon(size: Int, appearance: Appearance) -> CGImage {
    let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue))
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
        space: outputColorSpace, bitmapInfo: bitmapInfo.rawValue
    )!
    let scale = CGFloat(size) / 1024
    context.scaleBy(x: scale, y: scale)
    let background = appearance.background
    context.setFillColor(rgb(background))
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

    let center = CGPoint(x: 512, y: 512)
    for index in 0..<3 {
        let width = lineWidth
        let radius = (outerDiameter - CGFloat(index) * (lineWidth * 2 - overlap)) / 2
        let ringColor: (CGFloat, CGFloat, CGFloat)
        if appearance == .tinted {
            let levels: [CGFloat] = [0.95, 0.72, 0.49]
            ringColor = (levels[index], levels[index], levels[index])
        } else {
            ringColor = colors[index]
        }
        let trackColor: (CGFloat, CGFloat, CGFloat)
        if appearance == .tinted {
            trackColor = (0.25, 0.25, 0.25)
        } else {
            trackColor = (
                ringColor.0 * appearance.trackRingOpacity + background.0 * (1 - appearance.trackRingOpacity),
                ringColor.1 * appearance.trackRingOpacity + background.1 * (1 - appearance.trackRingOpacity),
                ringColor.2 * appearance.trackRingOpacity + background.2 * (1 - appearance.trackRingOpacity)
            )
        }
        let bounds = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.setStrokeColor(rgb(trackColor))
        context.strokeEllipse(in: bounds)
        context.setStrokeColor(rgb(ringColor))
        let startAngle = CGFloat.pi * 0.5
        let endAngle = startAngle - CGFloat.pi * 2 * progress[index]
        context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        context.strokePath()
    }
    return context.makeImage()!
}

private func writePNG(_ image: CGImage, to url: URL, opaque: Bool) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not create PNG at \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, [
        kCGImagePropertyPNGDictionary: [kCGImagePropertyPNGGamma: 0.45455],
        kCGImagePropertyHasAlpha: !opaque,
    ] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { fatalError("Could not write \(url.path)") }
}

private func makePreview(to url: URL) throws {
    let sheet = NSImage(size: NSSize(width: 1400, height: 700))
    sheet.lockFocus()
    NSColor(calibratedWhite: 0.88, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1400, height: 700)).fill()
    for (column, appearance) in [Appearance.light, .dark].enumerated() {
        let xBase = CGFloat(column) * 700 + 20
        let title = column == 0 ? "LIGHT" : "DARK"
        (title as NSString).draw(at: CGPoint(x: xBase + 275, y: 650), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 25)])
        var xOffset: CGFloat = 0
        for size in [180, 120, 87, 60, 40] {
            let displaySize = CGFloat(size) * 1.25
            let x = xBase + xOffset
            let y: CGFloat = 230
            let rect = CGRect(x: x, y: y, width: displaySize, height: displaySize)
            let mask = NSBezierPath(roundedRect: rect, xRadius: displaySize * 0.225, yRadius: displaySize * 0.225)
            let background = appearance.background
            NSColor(calibratedRed: background.0, green: background.1, blue: background.2, alpha: 1).setFill()
            NSBezierPath(rect: CGRect(x: x - 8, y: y - 8, width: displaySize + 16, height: displaySize + 16)).fill()
            mask.addClip()
            NSGraphicsContext.current?.cgContext.interpolationQuality = .high
            NSImage(cgImage: drawIcon(size: size, appearance: appearance), size: rect.size).draw(in: rect)
            NSColor.black.set()
            let label = "\(size) px"
            (label as NSString).draw(at: CGPoint(x: x + displaySize / 2 - 20, y: y - 36), withAttributes: [.font: NSFont.systemFont(ofSize: 16)])
            NSGraphicsContext.current?.cgContext.resetClip()
            xOffset += displaySize + 8
        }
    }
    sheet.unlockFocus()
    guard let tiff = sheet.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not render preview sheet")
    }
    try data.write(to: url)
}

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let catalog = root.appendingPathComponent("cal-macro-tracker/Assets.xcassets/AppIcon.appiconset")
for (name, appearance, opaque) in [
    ("icon-ios.png", Appearance.light, true),
    ("icon-ios-dark.png", Appearance.dark, true),
    ("icon-ios-tinted.png", Appearance.tinted, false),
] {
    try writePNG(drawIcon(size: 1024, appearance: appearance), to: catalog.appendingPathComponent(name), opaque: opaque)
}
for (filename, size) in [
    ("icon-mac-16.png", 16), ("icon-mac-16@2x.png", 32),
    ("icon-mac-32.png", 32), ("icon-mac-32@2x.png", 64),
    ("icon-mac-128.png", 128), ("icon-mac-128@2x.png", 256),
    ("icon-mac-256.png", 256), ("icon-mac-256@2x.png", 512),
    ("icon-mac-512.png", 512), ("icon-mac-512@2x.png", 1024),
] {
    try writePNG(drawIcon(size: size, appearance: .light), to: catalog.appendingPathComponent(filename), opaque: true)
}
let preview = root.appendingPathComponent("build/evidence/2026-11-23-app-icon/preview-v2.png")
try FileManager.default.createDirectory(at: preview.deletingLastPathComponent(), withIntermediateDirectories: true)
try makePreview(to: preview)
print("Generated iOS and macOS icon assets plus \(preview.path)")
