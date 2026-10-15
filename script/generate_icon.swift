import AppKit
let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let tile = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 204, yRadius: 204)
let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.32); shadow.shadowBlurRadius = 24; shadow.shadowOffset = NSSize(width: 0, height: -12)
NSGraphicsContext.saveGraphicsState(); shadow.set()
NSColor(calibratedRed: 0.04, green: 0.10, blue: 0.23, alpha: 1).setFill(); tile.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(colors: [NSColor(calibratedRed: 0.04, green: 0.11, blue: 0.27, alpha: 1), NSColor(calibratedRed: 0.08, green: 0.25, blue: 0.48, alpha: 1)])!.draw(in: tile, angle: 90)
NSColor.white.withAlphaComponent(0.12).setStroke(); tile.lineWidth = 2; tile.stroke()
func polygon(_ points: [(CGFloat, CGFloat)]) -> NSBezierPath {
 let p = NSBezierPath(); p.move(to: NSPoint(x: points[0].0, y: points[0].1))
 for point in points.dropFirst() { p.line(to: NSPoint(x: point.0, y: point.1)) }; p.close(); p.lineJoinStyle = .round; return p
}
func layer(_ y: CGFloat, top: NSColor, bottom: NSColor) {
 let p = polygon([(512,y+142),(790,y),(512,y-142),(234,y)])
 NSGradient(starting: bottom, ending: top)!.draw(in: p, angle: 90)
}
NSGraphicsContext.saveGraphicsState()
let markShadow = NSShadow(); markShadow.shadowColor = NSColor.black.withAlphaComponent(0.24); markShadow.shadowBlurRadius = 18; markShadow.shadowOffset = NSSize(width: 0, height: -14); markShadow.set()
layer(371, top: NSColor(calibratedRed: 0.16, green: 0.60, blue: 1, alpha: 1), bottom: NSColor(calibratedRed: 0.08, green: 0.32, blue: 0.94, alpha: 1))
layer(490, top: NSColor(calibratedRed: 0.20, green: 0.91, blue: 1, alpha: 1), bottom: NSColor(calibratedRed: 0.06, green: 0.56, blue: 1, alpha: 1))
layer(609, top: .white, bottom: NSColor(calibratedRed: 0.70, green: 0.91, blue: 1, alpha: 1))
NSGraphicsContext.restoreGraphicsState()
let hole = polygon([(512,661),(604,609),(512,557),(420,609)])
NSGradient(starting: NSColor(calibratedRed: 0.04, green: 0.14, blue: 0.31, alpha: 1), ending: NSColor(calibratedRed: 0.08, green: 0.28, blue: 0.52, alpha: 1))!.draw(in: hole, angle: 90)
NSGraphicsContext.restoreGraphicsState()
let output = CommandLine.arguments[1]
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
