// sbs <keyedPngDir> <source.mp4 (for audio)> <out.mp4> <fps> <bitrate>
// Packs keyed RGBA frames into a "side-by-side alpha" H.264 MP4:
// left half = colour, right half = alpha as grey. The app's native player
// recombines them. The source's audio track is copied in unchanged.
import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

func fail(_ s: String) -> Never { FileHandle.standardError.write((s + "\n").data(using: .utf8)!); exit(1) }
let a = CommandLine.arguments
guard a.count == 6 else { fail("usage: sbs dir src.mp4 out.mp4 fps bitrate") }
let dir = a[1], src = a[2], out = a[3]
let fps = Int32(a[4])!, bitrate = Int(a[5])!

let files = try! FileManager.default.contentsOfDirectory(atPath: dir).filter { $0.hasSuffix(".png") }.sorted()
guard !files.isEmpty else { fail("no frames") }

func load(_ f: String) -> (Int, Int, [UInt8]) {
    let s = CGImageSourceCreateWithURL(URL(fileURLWithPath: dir + "/" + f) as CFURL, nil)!
    let img = CGImageSourceCreateImageAtIndex(s, 0, nil)!
    let w = img.width, h = img.height
    var px = [UInt8](repeating: 0, count: w * h * 4)
    // Straight (un-premultiplied) RGBA: draw into a context that keeps it.
    // CGContext can't hold straight alpha, so read the provider data.
    let data = img.dataProvider!.data! as Data
    let bpr = img.bytesPerRow
    data.withUnsafeBytes { (p: UnsafeRawBufferPointer) in
        for y in 0..<h {
            for x in 0..<w {
                let si = y * bpr + x * 4, di = (y * w + x) * 4
                px[di] = p[si]; px[di + 1] = p[si + 1]; px[di + 2] = p[si + 2]; px[di + 3] = p[si + 3]
            }
        }
    }
    return (w, h, px)
}

let (w0, h0, _) = load(files[0])
let W = w0 * 2, H = h0
let outURL = URL(fileURLWithPath: out)
try? FileManager.default.removeItem(at: outURL)
let writer = try! AVAssetWriter(outputURL: outURL, fileType: .mp4)
let vIn = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: W, AVVideoHeightKey: H,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: bitrate,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoMaxKeyFrameIntervalKey: Int(fps) * 2,
    ],
])
vIn.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vIn, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H,
])
writer.add(vIn)

// Audio passthrough from the source.
let asset = AVURLAsset(url: URL(fileURLWithPath: src))
var aIn: AVAssetWriterInput?
var aReader: AVAssetReader?
var aOut: AVAssetReaderTrackOutput?
let sem = DispatchSemaphore(value: 0)
var audioTrack: AVAssetTrack?
Task { audioTrack = try? await asset.loadTracks(withMediaType: .audio).first; sem.signal() }
sem.wait()
if let t = audioTrack {
    let fmt = sem // silence unused warning
    _ = fmt
    var hint: CMFormatDescription?
    let s2 = DispatchSemaphore(value: 0)
    Task { hint = try? await t.load(.formatDescriptions).first; s2.signal() }
    s2.wait()
    let input = AVAssetWriterInput(mediaType: .audio, outputSettings: nil, sourceFormatHint: hint)
    input.expectsMediaDataInRealTime = false
    writer.add(input)
    aIn = input
    aReader = try! AVAssetReader(asset: asset)
    aOut = AVAssetReaderTrackOutput(track: t, outputSettings: nil)
    aReader!.add(aOut!)
    aReader!.startReading()
}

var pendingAudio: CMSampleBuffer?
var audioDone = aIn == nil
/// Appends audio samples up to time [t]. True when something was appended.
func pumpAudio(upTo t: Double) -> Bool {
    guard let input = aIn, let o = aOut, !audioDone else { return false }
    var any = false
    while input.isReadyForMoreMediaData {
        if pendingAudio == nil { pendingAudio = o.copyNextSampleBuffer() }
        guard let sb = pendingAudio else {
            input.markAsFinished(); audioDone = true; return any
        }
        if CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sb)) > t { return any }
        input.append(sb); pendingAudio = nil; any = true
    }
    return any
}

writer.startWriting()
writer.startSession(atSourceTime: .zero)

for (n, f) in files.enumerated() {
    let (w, h, px) = load(f)
    var pbo: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pbo)
    let pb = pbo!
    CVPixelBufferLockBaseAddress(pb, [])
    let base = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self)
    let bpr = CVPixelBufferGetBytesPerRow(pb)
    for y in 0..<h {
        for x in 0..<w {
            let i = (y * w + x) * 4
            let al = px[i + 3]
            // Colour where visible; black where fully clear (smaller file).
            let r = al == 0 ? 0 : px[i], g = al == 0 ? 0 : px[i + 1], b = al == 0 ? 0 : px[i + 2]
            let li = y * bpr + x * 4
            base[li] = b; base[li + 1] = g; base[li + 2] = r; base[li + 3] = 255
            let ri = y * bpr + (x + w) * 4
            base[ri] = al; base[ri + 1] = al; base[ri + 2] = al; base[ri + 3] = 255
        }
    }
    CVPixelBufferUnlockBaseAddress(pb, [])
    // The writer interleaves audio and video: while video is blocked, feed
    // it audio (otherwise it waits on audio forever).
    while !vIn.isReadyForMoreMediaData {
        if !pumpAudio(upTo: Double(n + 24) / Double(fps)) { usleep(2000) }
    }
    adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(n), timescale: fps))
    _ = pumpAudio(upTo: Double(n + 24) / Double(fps))
}
vIn.markAsFinished()

while !audioDone {
    if !pumpAudio(upTo: 1e9) { usleep(2000) }
}

let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
if writer.status != .completed { fail("write failed: \(String(describing: writer.error))") }
let size = (try? FileManager.default.attributesOfItem(atPath: out)[.size] as? Int) ?? 0
print("ok \(W)x\(H) frames=\(files.count) bytes=\(size)")
