import AppKit

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: 800, pixelsHigh: 1150, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.white.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 800, height: 1150)).fill()
let rows = [
    "NORTH STREET COFFEE", "SAMPLE RECEIPT", "2026-09-20", "", "Coffee             4.50",
    "Sandwich           8.00", "", "SUBTOTAL          12.50", "TAX                1.00",
    "TOTAL USD         13.50", "", "Thank you",
]
for (index, line) in rows.enumerated() {
    (line as NSString).draw(
        at: NSPoint(x: 75, y: 1020 - index * 70),
        withAttributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 30, weight: index == 0 ? .bold : .regular),
            .foregroundColor: NSColor.black,
        ])
}
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(
    to: URL(fileURLWithPath: "Resources/sample-receipt.png"))
