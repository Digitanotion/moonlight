// vk — video helper for gift animations (no ffmpeg on this Mac).
//   vk info  <mp4>
//   vk grab  <mp4> <out.png> <seconds>            one raw frame
//   vk key   <mp4> <outdir> <width> <fps> <lo> <hi> [trimStart] [trimEnd]
//            every frame → keyed RGBA PNG (blue background removed)
//   vk audio <mp4> <out.m4a>
import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ s: String) -> Never { FileHandle.standardError.write((s + "\n").data(using: .utf8)!); exit(1) }

let args = CommandLine.arguments
guard args.count >= 3 else { fail("usage: see header") }
let asset = AVURLAsset(url: URL(fileURLWithPath: args[2]))

func sync<T>(_ f: @escaping () async throws -> T) -> T {
    let sem = DispatchSemaphore(value: 0)
    var out: T!
    var err: Error?
    Task { do { out = try await f() } catch { err = error }; sem.signal() }
    sem.wait()
    if let e = err { fail("error: \(e)") }
    return out
}

func writePNG(_ img: CGImage, _ path: String) {
    let url = URL(fileURLWithPath: path) as CFURL
    guard let d = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else { fail("png") }
    CGImageDestinationAddImage(d, img, nil)
    CGImageDestinationFinalize(d)
}

switch args[1] {
case "info":
    let (dur, tracks) = sync { (try await asset.load(.duration), try await asset.load(.tracks)) }
    print("duration", CMTimeGetSeconds(dur))
    for t in tracks {
        let (size, fps, tf) = sync { (try await t.load(.naturalSize), try await t.load(.nominalFrameRate), try await t.load(.preferredTransform)) }
        print(t.mediaType.rawValue, "size", size, "fps", fps, "transform", tf)
    }

case "grab":
    let gen = AVAssetImageGenerator(asset: asset)
    gen.appliesPreferredTrackTransform = true
    gen.requestedTimeToleranceBefore = .zero
    gen.requestedTimeToleranceAfter = .zero
    let t = CMTime(seconds: Double(args[4])!, preferredTimescale: 600)
    let img = sync { try await gen.image(at: t).image }
    writePNG(img, args[3])

case "audio":
    let out = URL(fileURLWithPath: args[3])
    try? FileManager.default.removeItem(at: out)
    guard let ex = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else { fail("no export") }
    ex.outputURL = out
    ex.outputFileType = .m4a
    let sem = DispatchSemaphore(value: 0)
    ex.exportAsynchronously { sem.signal() }
    sem.wait()
    print("audio", ex.status.rawValue, ex.error?.localizedDescription ?? "ok")

case "key":
    let outDir = args[3]
    let width = Int(args[4])!
    let fps = Double(args[5])!
    let lo = Float(args[6])!, hi = Float(args[7])!
    let trimStart = args.count > 8 ? Double(args[8])! : 0
    let trimEnd = args.count > 9 ? Double(args[9])! : 1e9
    let env = ProcessInfo.processInfo.environment
    let warm = env["WARM"] == "1" || env["WARM"] == "2"
    let warmGlow = env["WARM"] == "2" // also turn purple glow (semi-transparent) gold
    let fade = Float(env["FADE"] ?? "0") ?? 0 // fade out the bottom fraction
    try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
    let track = sync { try await asset.loadTracks(withMediaType: .video).first! }
    let reader = try! AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    reader.add(output)
    reader.startReading()
    let ctx = CIContext()
    var n = 0
    var nextT = trimStart
    var bg: (Float, Float)? = nil // background chroma (Cb, Cr)
    var bgRGB: (Float, Float, Float) = (0, 0, 0)
    var mode = 0
    while let sb = output.copyNextSampleBuffer() {
        let t = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sb))
        if t + 1e-6 < nextT { continue }
        if t > trimEnd { break }
        nextT += 1.0 / fps
        guard let pb = CMSampleBufferGetImageBuffer(sb) else { continue }
        var ci = CIImage(cvPixelBuffer: pb)
        let scale = CGFloat(width) / ci.extent.width
        ci = ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let w = Int(ci.extent.width.rounded()), h = Int(ci.extent.height.rounded())
        var px = [UInt8](repeating: 0, count: w * h * 4)
        ctx.render(ci, toBitmap: &px, rowBytes: w * 4, bounds: CGRect(x: 0, y: 0, width: w, height: h), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        // Background chroma from the first frame's border.
        func chroma(_ i: Int) -> (Float, Float) {
            let r = Float(px[i]), g = Float(px[i + 1]), b = Float(px[i + 2])
            return (-0.1687 * r - 0.3313 * g + 0.5 * b, 0.5 * r - 0.4187 * g - 0.0813 * b)
        }
        if bg == nil {
            // Median of the border (robust when the subject touches an edge,
            // e.g. a road running off the bottom).
            var cbs: [Float] = [], crs: [Float] = [], rs: [Float] = [], gs: [Float] = [], bs: [Float] = []
            func add(_ i: Int) {
                let c = chroma(i); cbs.append(c.0); crs.append(c.1)
                rs.append(Float(px[i])); gs.append(Float(px[i + 1])); bs.append(Float(px[i + 2]))
            }
            for x in stride(from: 0, to: w, by: 4) { for y in [2, h - 3] { add((y * w + x) * 4) } }
            for y in stride(from: 0, to: h, by: 4) { for x in [2, w - 3] { add((y * w + x) * 4) } }
            func med(_ v: [Float]) -> Float { let s = v.sorted(); return s[s.count / 2] }
            bg = (med(cbs), med(crs))
            bgRGB = (med(rs), med(gs), med(bs))
            let (R, G, B) = bgRGB
            mode = (B >= R && B >= G) ? 0 : (G >= R && G >= B) ? 1 : 2 // blue / green / magenta
            print("mode", mode)
            print("bg rgb", bgRGB)
            print("bg chroma", bg!)
        }
        let (bcb, bcr) = bg!
        let blen = sqrtf(bcb * bcb + bcr * bcr)
        for p in 0..<(w * h) {
            let i = p * 4
            let c = chroma(i)
            let d = sqrtf((c.0 - bcb) * (c.0 - bcb) + (c.1 - bcr) * (c.1 - bcr))
            var a = (d - lo) / (hi - lo)
            a = max(0, min(1, a))
            a = a * a * (3 - 2 * a)
            var r = Float(px[i]), g = Float(px[i + 1]), b = Float(px[i + 2])
            // Un-mix: a glow or edge pixel is fg·a + blue·(1−a); take the
            // blue back out so sparkles keep their real gold/white colour.
            if a > 0.02 && a < 0.98 {
                let ia = 1 / a
                r = (r - (1 - a) * bgRGB.0) * ia
                g = (g - (1 - a) * bgRGB.1) * ia
                b = (b - (1 - a) * bgRGB.2) * ia
                r = max(0, r); g = max(0, g); b = max(0, b)
            }
            // Despill: remove the part of the colour that points toward the
            // background chroma (kills blue fringes and blue glow tint).
            let proj = (c.0 * bcb + c.1 * bcr) / max(blen, 1)
            let m = max(r, g)
            if mode == 1 {
                // Green screen: clamp green to the brighter of red/blue.
                let mg = max(r, b)
                if g > mg { g = mg + (g - mg) * 0.15 }
            } else if mode == 2 {
                // Magenta screen: spill is red+blue above green.
                let sp = min(r, b) - g
                if proj > 0 && sp > 0 { r -= sp * 0.85; b -= sp * 0.85 }
            } else if warmGlow && a < 0.9 && b > g {
                let lum = 0.299 * r + 0.587 * g + 0.114 * b
                r = min(255, lum * 1.08); g = min(255, lum * 0.98); b = lum * 0.72
            } else if warm && b > m {
                // Gifts have no blue: a bluish glow/streak is light that
                // picked up the backdrop. Recolour it warm gold-white at
                // the same brightness.
                let lum = 0.299 * r + 0.587 * g + 0.114 * b
                let k = min(1, (b - m) / 40) // only fully for clearly blue
                r = r + (min(255, lum * 1.08) - r) * k
                g = g + (min(255, lum * 0.98) - g) * k
                b = b + (lum * 0.72 - b) * k
            } else if proj > 0 && b > m {
                b = m + (b - m) * 0.15
            }
            // Un-premultiply nothing (straight alpha); just clamp.
            r = min(255, r); g = min(255, g); b = min(255, b)
            px[i] = UInt8(r); px[i + 1] = UInt8(g); px[i + 2] = UInt8(b)
            if fade > 0 {
                let y = Float(p / w) / Float(h)
                let f0 = 1 - fade
                if y > f0 { let t = (y - f0) / fade; a *= 1 - t * t * (3 - 2 * t) }
            }
            px[i + 3] = UInt8(a * 255)
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        let prov = CGDataProvider(data: Data(px) as CFData)!
        let img = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: cs, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: prov, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        writePNG(img, String(format: "%@/f%04d.png", outDir, n))
        n += 1
    }
    print("frames", n)

default:
    fail("unknown mode")
}
