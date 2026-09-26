import AppKit

// Génère AppIcon.iconset (puis iconutil le convertit en .icns). Usage : swift make-icon.swift <dossier.iconset>
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func render(size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let inset = s * 0.09
    let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let background = NSBezierPath(roundedRect: rect, xRadius: s * 0.19, yRadius: s * 0.19)
    NSGradient(colors: [NSColor(red: 0.17, green: 0.16, blue: 0.30, alpha: 1),
                        NSColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1)])!.draw(in: background, angle: -90)

    // Fenêtre vidéo
    let screen = NSRect(x: rect.minX + s * 0.12, y: rect.minY + s * 0.36, width: rect.width - s * 0.24, height: s * 0.34)
    NSColor(white: 1, alpha: 0.10).setFill()
    NSBezierPath(roundedRect: screen, xRadius: s * 0.03, yRadius: s * 0.03).fill()
    let play = NSBezierPath()
    play.move(to: NSPoint(x: screen.midX - s * 0.05, y: screen.midY - s * 0.07))
    play.line(to: NSPoint(x: screen.midX - s * 0.05, y: screen.midY + s * 0.07))
    play.line(to: NSPoint(x: screen.midX + s * 0.075, y: screen.midY))
    play.close()
    NSColor.white.setFill()
    play.fill()

    // Timeline avec marqueurs colorés
    let lineY = rect.minY + s * 0.22
    NSColor(white: 1, alpha: 0.25).setFill()
    NSBezierPath(roundedRect: NSRect(x: screen.minX, y: lineY - s * 0.012, width: screen.width, height: s * 0.024),
                 xRadius: s * 0.012, yRadius: s * 0.012).fill()
    let markers: [(CGFloat, NSColor)] = [
        (0.15, NSColor(red: 1, green: 0.36, blue: 0.36, alpha: 1)),
        (0.42, NSColor(red: 0.30, green: 0.55, blue: 1, alpha: 1)),
        (0.63, NSColor(red: 1, green: 0.79, blue: 0.30, alpha: 1)),
        (0.86, NSColor(red: 0.43, green: 0.91, blue: 0.63, alpha: 1)),
    ]
    for (position, color) in markers {
        color.setFill()
        let r = s * 0.045
        NSBezierPath(ovalIn: NSRect(x: screen.minX + screen.width * position - r, y: lineY - r, width: r * 2, height: r * 2)).fill()
    }
    NSColor(red: 0.36, green: 0.33, blue: 1, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: screen.minX + screen.width * 0.52, y: lineY - s * 0.08, width: s * 0.018, height: s * 0.16),
                 xRadius: s * 0.009, yRadius: s * 0.009).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try render(size: base).write(to: output.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(size: base * 2).write(to: output.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
