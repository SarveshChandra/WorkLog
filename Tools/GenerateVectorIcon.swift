import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let imagesDirectory = root.appendingPathComponent("Resources/Images", isDirectory: true)
let iconsetDirectory = root.appendingPathComponent("Resources/AppIcon.iconset", isDirectory: true)
let pdfURL = imagesDirectory.appendingPathComponent("work-log-icon.pdf")
let pngURL = imagesDirectory.appendingPathComponent("work-log-icon.png")
let icnsURL = root.appendingPathComponent("Resources/WorkLogIcon.icns")

try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)

let variants: [(name: String, size: Int, type: String)] = [
    ("icon_16x16.png", 16, "icp4"),
    ("icon_16x16@2x.png", 32, "icp5"),
    ("icon_32x32.png", 32, "icp5"),
    ("icon_32x32@2x.png", 64, "icp6"),
    ("icon_128x128.png", 128, "ic07"),
    ("icon_128x128@2x.png", 256, "ic08"),
    ("icon_256x256.png", 256, "ic08"),
    ("icon_256x256@2x.png", 512, "ic09"),
    ("icon_512x512.png", 512, "ic09"),
    ("icon_512x512@2x.png", 1024, "ic10")
]

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: alpha)
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawIcon(in context: CGContext, side: CGFloat) {
    context.saveGState()
    defer { context.restoreGState() }

    let bounds = CGRect(x: 0, y: 0, width: side, height: side)
    context.clear(bounds)

    let artSide = side * 0.84
    let artInset = (side - artSide) / 2
    context.translateBy(x: artInset, y: artInset)
    drawIconArtwork(in: context, side: artSide)
}

func drawIconArtwork(in context: CGContext, side: CGFloat) {
    context.saveGState()
    defer { context.restoreGState() }

    let bounds = CGRect(x: 0, y: 0, width: side, height: side)

    let background = roundedRect(bounds.insetBy(dx: side * 0.03, dy: side * 0.03), side * 0.22)
    context.addPath(background)
    context.clip()

    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            color(0.07, 0.55, 0.55),
            color(0.08, 0.22, 0.24),
            color(0.08, 0.13, 0.18)
        ] as CFArray,
        locations: [0, 0.48, 1]
    )
    if let gradient {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: side * 0.12, y: side * 0.92),
            end: CGPoint(x: side * 0.92, y: side * 0.10),
            options: []
        )
    }

    context.addPath(roundedRect(bounds.insetBy(dx: side * 0.035, dy: side * 0.035), side * 0.20))
    context.setStrokeColor(color(1, 1, 1, 0.18))
    context.setLineWidth(side * 0.018)
    context.strokePath()

    let sheetRect = CGRect(x: side * 0.23, y: side * 0.25, width: side * 0.52, height: side * 0.56)
    context.setFillColor(color(0.96, 0.97, 0.94))
    context.addPath(roundedRect(sheetRect, side * 0.07))
    context.fillPath()

    context.setStrokeColor(color(0.12, 0.22, 0.22, 0.18))
    context.setLineWidth(side * 0.012)
    context.addPath(roundedRect(sheetRect, side * 0.07))
    context.strokePath()

    let lineHeight = side * 0.04
    for index in 0..<4 {
        let y = sheetRect.maxY - side * 0.12 - CGFloat(index) * side * 0.105
        let leftLine = CGRect(x: sheetRect.minX + side * 0.08, y: y, width: side * 0.14, height: lineHeight)
        let rightLine = CGRect(x: sheetRect.minX + side * 0.27, y: y, width: side * 0.26, height: lineHeight)
        context.setFillColor(index == 0 ? color(0.07, 0.54, 0.66) : color(0.68, 0.75, 0.73))
        context.addPath(roundedRect(leftLine, lineHeight / 2))
        context.fillPath()
        context.setFillColor(color(0.79, 0.84, 0.82))
        context.addPath(roundedRect(rightLine, lineHeight / 2))
        context.fillPath()
    }

    let checkCircle = CGRect(x: side * 0.58, y: side * 0.20, width: side * 0.29, height: side * 0.29)
    context.setFillColor(color(0.05, 0.57, 0.49))
    context.fillEllipse(in: checkCircle)
    context.setStrokeColor(color(1, 1, 1, 0.26))
    context.setLineWidth(side * 0.014)
    context.strokeEllipse(in: checkCircle.insetBy(dx: side * 0.008, dy: side * 0.008))

    let check = CGMutablePath()
    check.move(to: CGPoint(x: side * 0.655, y: side * 0.335))
    check.addLine(to: CGPoint(x: side * 0.715, y: side * 0.275))
    check.addLine(to: CGPoint(x: side * 0.815, y: side * 0.405))
    context.addPath(check)
    context.setStrokeColor(color(1, 1, 1))
    context.setLineWidth(side * 0.045)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.strokePath()
}

func pngData(side: Int) throws -> Data {
    guard let context = CGContext(
        data: nil,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }
    drawIcon(in: context, side: CGFloat(side))
    guard let image = context.makeImage(),
          let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return data
}

func writePDF() throws {
    var mediaBox = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    guard let consumer = CGDataConsumer(url: pdfURL as CFURL),
          let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    context.beginPDFPage(nil)
    drawIcon(in: context, side: 1024)
    context.endPDFPage()
    context.closePDF()
}

func appendUInt32(_ value: UInt32, to data: inout Data) {
    var bigEndian = value.bigEndian
    withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
}

func writeICNS(chunks: [(type: String, data: Data)]) throws {
    var totalLength = 8
    for chunk in chunks {
        totalLength += 8 + chunk.data.count
    }

    var data = Data("icns".utf8)
    appendUInt32(UInt32(totalLength), to: &data)

    for chunk in chunks {
        data.append(Data(chunk.type.utf8))
        appendUInt32(UInt32(8 + chunk.data.count), to: &data)
        data.append(chunk.data)
    }

    try data.write(to: icnsURL, options: [.atomic])
}

var icnsChunks: [(type: String, data: Data)] = []
var seenChunkTypes = Set<String>()

for variant in variants {
    let data = try pngData(side: variant.size)
    try data.write(to: iconsetDirectory.appendingPathComponent(variant.name), options: [.atomic])

    if !seenChunkTypes.contains(variant.type) {
        icnsChunks.append((variant.type, data))
        seenChunkTypes.insert(variant.type)
    }
}

try pngData(side: 1024).write(to: pngURL, options: [.atomic])
try writePDF()
try writeICNS(chunks: icnsChunks)
