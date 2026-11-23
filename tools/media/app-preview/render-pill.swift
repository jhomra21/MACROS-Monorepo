import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: render-pill.swift <label> <output.png>")
}

let label = CommandLine.arguments[1]
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let width = 886
let height = 1920
let pillHeight: CGFloat = 60
let top: CGFloat = 20
let padding: CGFloat = 28
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 27, weight: .semibold),
    .foregroundColor: NSColor.white
]
let textSize = (label as NSString).size(withAttributes: attributes)
let pillWidth = ceil(textSize.width + padding * 2)

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Could not allocate the label image")
}

NSGraphicsContext.saveGraphicsState()
guard let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Could not create a graphics context")
}
NSGraphicsContext.current = graphics
graphics.imageInterpolation = .high
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()

let pill = NSRect(
    x: (CGFloat(width) - pillWidth) / 2,
    y: CGFloat(height) - top - pillHeight,
    width: pillWidth,
    height: pillHeight
)
NSColor.black.withAlphaComponent(0.88).setFill()
NSBezierPath(roundedRect: pill, xRadius: pillHeight / 2, yRadius: pillHeight / 2).fill()

let textOrigin = CGPoint(
    x: pill.midX - textSize.width / 2,
    y: pill.minY + (pillHeight - textSize.height) / 2
)
(label as NSString).draw(at: textOrigin, withAttributes: attributes)
NSGraphicsContext.restoreGraphicsState()

guard
    let data = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Could not encode the label image")
}
try data.write(to: outputURL)
