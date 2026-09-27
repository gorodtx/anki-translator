// Draws the app icon: two overlapping speech bubbles on a calm blue body, on the macOS
// icon grid. Everything is drawn with CoreGraphics paths — no SF Symbols and no font
// glyphs, which their licences keep out of app icons.
//
//   swift scripts/make_icon.swift OUT.png [size]     (size defaults to 1024)
//
// scripts/make_icon.sh turns the 1024 px image into Resources/AppIcon.icns.
import AppKit
import CoreGraphics

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write(Data("usage: make_icon.swift OUT.png [size]\n".utf8))
    exit(2)
}
let output = URL(fileURLWithPath: arguments[1])
let pixels = arguments.count >= 3 ? Int(arguments[2]) ?? 1024 : 1024

/// All geometry is on the 1024 pt template and scaled once.
let canvas: CGFloat = 1024
let scale = CGFloat(pixels) / canvas

let space = CGColorSpace(name: CGColorSpace.displayP3)!
guard let context = CGContext(
    data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }
context.scaleBy(x: scale, y: scale)
context.interpolationQuality = .high
context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: space,
        components: [
            CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255,
            CGFloat(hex & 0xFF) / 255, alpha,
        ]
    )!
}

/// A rounded rectangle with continuous (curvature-matched) corners, as the system draws
/// its icon body: each corner is a superellipse quadrant rather than a circular arc, so
/// the straight edge flows into the bend without a visible kink.
func continuousRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    // The superellipse corner reaches further along the edges than a circle of the same
    // radius; 1.28 is the extent Apple's corners use relative to their nominal radius.
    let extent = min(radius * 1.28, min(rect.width, rect.height) / 2)
    let exponent: CGFloat = 4.2
    let steps = 48
    let corners: [(CGPoint, CGFloat, CGFloat)] = [
        (CGPoint(x: rect.maxX - extent, y: rect.maxY - extent), 0, 1),   // top right
        (CGPoint(x: rect.minX + extent, y: rect.maxY - extent), 1, 1),   // top left
        (CGPoint(x: rect.minX + extent, y: rect.minY + extent), 1, 0),   // bottom left
        (CGPoint(x: rect.maxX - extent, y: rect.minY + extent), 0, 0),   // bottom right
    ]
    for (index, corner) in corners.enumerated() {
        let (centre, _, _) = corner
        let start = CGFloat(index) * .pi / 2
        for step in 0...steps {
            let angle = start + CGFloat(step) / CGFloat(steps) * .pi / 2
            let c = cos(angle), s = sin(angle)
            let x = centre.x + extent * copysign(pow(abs(c), 2 / exponent), c)
            let y = centre.y + extent * copysign(pow(abs(s), 2 / exponent), s)
            if index == 0, step == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
    }
    path.closeSubpath()
    return path
}

/// A speech bubble: a rounded body and a tail leaving its bottom edge.
func bubble(_ rect: CGRect, radius: CGFloat, tailBase: ClosedRange<CGFloat>, tailTip: CGPoint) -> CGPath {
    let path = CGMutablePath()
    path.addPath(continuousRect(rect, radius: radius))
    // Counter-clockwise like the body, so the non-zero fill joins the two instead of
    // cutting the overlap out: from the left end of the base down to the tip and back up
    // to the right end. The side nearer the tip is almost straight; the far side sweeps
    // in a concave curve, as a hand-drawn tail does.
    let top = rect.minY + 40
    let left = CGPoint(x: tailBase.lowerBound, y: top)
    let right = CGPoint(x: tailBase.upperBound, y: top)
    let tipOnLeft = tailTip.x < (left.x + right.x) / 2
    let tail = CGMutablePath()
    tail.move(to: left)
    tail.addQuadCurve(
        to: tailTip,
        control: tipOnLeft
            ? CGPoint(x: left.x - 4, y: (top + tailTip.y) / 2)
            : CGPoint(x: left.x + (tailTip.x - left.x) * 0.45, y: rect.minY - 6)
    )
    tail.addQuadCurve(
        to: right,
        control: tipOnLeft
            ? CGPoint(x: right.x - (right.x - tailTip.x) * 0.45, y: rect.minY - 6)
            : CGPoint(x: right.x + 4, y: (top + tailTip.y) / 2)
    )
    tail.closeSubpath()
    path.addPath(tail)
    return path
}

/// Strokes a drawn letterform with round ends and joins, like a marker.
func stroke(_ path: CGPath, width: CGFloat, color: CGColor) {
    context.saveGState()
    context.setStrokeColor(color)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.addPath(path)
    context.strokePath()
    context.restoreGState()
}

/// A Latin A, drawn as three strokes: the language looked up.
func letterA(centre: CGPoint, height: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let half = height * 0.46
    let apex = CGPoint(x: centre.x, y: centre.y + height / 2)
    path.move(to: CGPoint(x: centre.x - half, y: centre.y - height / 2))
    path.addLine(to: apex)
    path.addLine(to: CGPoint(x: centre.x + half, y: centre.y - height / 2))
    let bar = centre.y - height * 0.14
    let inset = half * (0.5 + 0.14)
    path.move(to: CGPoint(x: centre.x - inset, y: bar))
    path.addLine(to: CGPoint(x: centre.x + inset, y: bar))
    return path
}

/// A Cyrillic Я, drawn as a stem, a bowl and a leg: the language it is translated into.
func letterYa(centre: CGPoint, height: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let top = centre.y + height / 2
    let bottom = centre.y - height / 2
    let stem = centre.x + height * 0.3
    let waist = centre.y - height * 0.04
    let bowlLeft = centre.x - height * 0.42
    let bowlJoin = centre.x - height * 0.02
    path.move(to: CGPoint(x: stem, y: bottom))
    path.addLine(to: CGPoint(x: stem, y: top))
    path.addLine(to: CGPoint(x: bowlJoin, y: top))
    path.addCurve(
        to: CGPoint(x: bowlJoin, y: waist),
        control1: CGPoint(x: bowlLeft, y: top),
        control2: CGPoint(x: bowlLeft, y: waist)
    )
    path.addLine(to: CGPoint(x: stem, y: waist))
    path.move(to: CGPoint(x: bowlJoin + height * 0.08, y: waist))
    path.addLine(to: CGPoint(x: centre.x - height * 0.3, y: bottom))
    return path
}

// MARK: - Body

// The macOS grid: an 824 pt body centred on the 1024 pt canvas, with the system's soft
// drop shadow under it.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = continuousRect(body, radius: 185)

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.30))
context.addPath(bodyPath)
context.setFillColor(color(0x3A78E0))
context.fillPath()
context.restoreGState()

context.saveGState()
context.addPath(bodyPath)
context.clip()
let gradient = CGGradient(
    colorsSpace: space,
    colors: [color(0x6CC0F8), color(0x3F86EA), color(0x2E5CCB)] as CFArray,
    locations: [0, 0.55, 1]
)!
context.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
// A faint light from the top edge, as the system icons have.
let sheen = CGGradient(
    colorsSpace: space,
    colors: [color(0xFFFFFF, 0.18), color(0xFFFFFF, 0)] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(sheen, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 640), options: [])
context.restoreGState()

// MARK: - Bubbles

// The source language: behind, to the upper left, translucent.
let back = CGRect(x: 196, y: 470, width: 430, height: 316)
let backPath = bubble(back, radius: 92, tailBase: 244...330, tailTip: CGPoint(x: 222, y: 400))
// The translation: in front, to the lower right, solid.
let front = CGRect(x: 398, y: 250, width: 430, height: 316)
let frontPath = bubble(front, radius: 92, tailBase: 696...782, tailTip: CGPoint(x: 804, y: 180))

context.beginTransparencyLayer(auxiliaryInfo: nil)
context.addPath(backPath)
context.setFillColor(color(0xFFFFFF, 0.42))
context.fillPath()
// Above the front bubble's gap (its top edge plus the cut is at y 584).
stroke(letterA(centre: CGPoint(x: 362, y: 674), height: 132), width: 38, color: color(0xFFFFFF, 0.95))
// A gap around the front bubble, cut out of the back one, so the two read as separate.
context.setBlendMode(.destinationOut)
context.addPath(frontPath)
context.setLineWidth(36)
context.setLineJoin(.round)
context.setStrokeColor(color(0x000000))
context.strokePath()
context.addPath(frontPath)
context.setFillColor(color(0x000000))
context.fillPath()
context.endTransparencyLayer()

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: color(0x10275E, 0.28))
context.addPath(frontPath)
context.setFillColor(color(0xFFFFFF))
context.fillPath()
context.restoreGState()

stroke(letterYa(centre: CGPoint(x: 613, y: 408), height: 164), width: 38, color: color(0x2F63D2))

// MARK: - Output

guard let image = context.makeImage() else { exit(1) }
let bitmap = NSBitmapImageRep(cgImage: image)
guard let data = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
do {
    try data.write(to: output)
} catch {
    FileHandle.standardError.write(Data("could not write \(output.path): \(error)\n".utf8))
    exit(1)
}
