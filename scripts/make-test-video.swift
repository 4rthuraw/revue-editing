import AVFoundation
import AppKit

// Vidéo de test : timecode et numéro d'image incrustés, pour vérifier l'alignement des marqueurs.
// Usage : swift make-test-video.swift <sortie.mp4> [fps=25] [secondes=60] [tc départ en images=90000]
let args = CommandLine.arguments
let output = URL(fileURLWithPath: args[1])
let fps = Int32(args.count > 2 ? Int(args[2])! : 25)
let seconds = args.count > 3 ? Int(args[3])! : 60
let startFrame = args.count > 4 ? Int(args[4])! : 90000
let width = 1280, height = 720
let total = Int(fps) * seconds

try? FileManager.default.removeItem(at: output)
let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: width,
    kCVPixelBufferHeightKey as String: height,
])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

let base = Int(fps)
func tc(_ f: Int) -> String {
    String(format: "%02d:%02d:%02d:%02d", f / base / 3600, (f / base / 60) % 60, (f / base) % 60, f % base)
}

for frame in 0..<total {
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
    guard let buffer else { fatalError("buffer") }
    CVPixelBufferLockBaseAddress(buffer, [])
    let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height, bitsPerComponent: 8,
                        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
    let hue = CGFloat(frame % (base * 10)) / CGFloat(base * 10)
    ctx.setFillColor(NSColor(hue: hue, saturation: 0.45, brightness: 0.35, alpha: 1).cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    // Barre de progression par seconde
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.8).cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(width) * CGFloat(frame % base + 1) / CGFloat(base), height: 12))

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    let big: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 110, weight: .bold), .foregroundColor: NSColor.white]
    let small: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 48, weight: .semibold), .foregroundColor: NSColor.systemYellow]
    let tcText = NSAttributedString(string: tc(startFrame + frame), attributes: big)
    tcText.draw(at: NSPoint(x: (CGFloat(width) - tcText.size().width) / 2, y: 300))
    let frameText = NSAttributedString(string: "image \(frame) · \(fps) im/s", attributes: small)
    frameText.draw(at: NSPoint(x: (CGFloat(width) - frameText.size().width) / 2, y: 200))
    NSGraphicsContext.restoreGraphicsState()

    CVPixelBufferUnlockBaseAddress(buffer, [])
    adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: fps))
}
input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
print(writer.status == .completed ? "✓ \(output.path)" : "✗ \(String(describing: writer.error))")
