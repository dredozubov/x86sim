// makes res/sdkcovChapters.mov and res/sdkcovStall.mov: an iOS simulator program, built on Linux and run on a phone by
// res/sdkcovRes.sh (`sdkcovMovies [DIR]` writes both into DIR, default the program's own directory):
// the movie checks/P21_Gaps.swift's p21ChapterMovie writes (64x64 video, 3 s, a QuickTime text track "Opening",
// "Middle", "Credits" associated as its chapter list), for watchOS, which has no AVAssetWriter
// (func:AVFoundation.chapters-bundled-movie in checks/P22_Gaps.swift), and the 6 s video + AAC movie p21AVMovie writes
// (header first) for func:AVFoundation.player-stalled-http-loopback
import AVFoundation
import CoreMedia
struct E: Error { let s: String }
func expect(_ c: Bool, _ s: @autoclosure () -> String) throws { if !c { throw E(s: s()) } }
func p1Solid(_ w: Int, _ h: Int, _ bgr: [UInt8]) -> CVPixelBuffer {
    var pb: CVPixelBuffer?
    CVPixelBufferCreate(nil, w, h, kCVPixelFormatType_32BGRA, [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &pb)
    CVPixelBufferLockBaseAddress(pb!, [])
    let base = CVPixelBufferGetBaseAddress(pb!)!.assumingMemoryBound(to: UInt8.self), bpr = CVPixelBufferGetBytesPerRow(pb!)
    for y in 0..<h { for x in 0..<w { let p = base + y * bpr + x * 4; p[0] = bgr[0]; p[1] = bgr[1]; p[2] = bgr[2]; p[3] = 255 } }
    CVPixelBufferUnlockBaseAddress(pb!, [])
    return pb!
}
func p21ChapterMovie(_ url: URL, titles: [String]) async throws {
    try? FileManager.default.removeItem(at: url)
    let w = try AVAssetWriter(outputURL: url, fileType: .mov)
    let vin = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64])
    let ad = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vin, sourcePixelBufferAttributes: nil)
    w.add(vin)
    var fd: CMFormatDescription?
    // a QuickTime text sample description: display flags, justification, colors, text box, default style, font table
    // the keys a QuickTime ('text') sample description has (the 3GPP ones, alpha / end char / font table, left out)
    func color(_ v: Int) -> [String: Int] { [kCMTextFormatDescriptionColor_Red as String: v, kCMTextFormatDescriptionColor_Green as String: v,
                                             kCMTextFormatDescriptionColor_Blue as String: v] }
    let ext: [String: Any] = [
        kCMTextFormatDescriptionExtension_DisplayFlags as String: 0,
        kCMTextFormatDescriptionExtension_TextJustification as String: 0,
        kCMTextFormatDescriptionExtension_BackgroundColor as String: color(0),
        kCMTextFormatDescriptionExtension_DefaultTextBox as String: [kCMTextFormatDescriptionRect_Top as String: 0, kCMTextFormatDescriptionRect_Left as String: 0,
                                                                     kCMTextFormatDescriptionRect_Bottom as String: 0, kCMTextFormatDescriptionRect_Right as String: 0],
        kCMTextFormatDescriptionExtension_DefaultStyle as String: [kCMTextFormatDescriptionStyle_StartChar as String: 0, kCMTextFormatDescriptionStyle_Font as String: 0,
                                                                   kCMTextFormatDescriptionStyle_FontFace as String: 0, kCMTextFormatDescriptionStyle_ForegroundColor as String: color(65535),
                                                                   kCMTextFormatDescriptionStyle_FontSize as String: 12, kCMTextFormatDescriptionStyle_Height as String: 14,
                                                                   kCMTextFormatDescriptionStyle_Ascent as String: 11],
        kCMTextFormatDescriptionExtension_DefaultFontName as String: "Helvetica",
    ]
    try expect(CMFormatDescriptionCreate(allocator: nil, mediaType: kCMMediaType_Text, mediaSubType: kCMTextFormatType_QTText,
                                         extensions: ext as CFDictionary, formatDescriptionOut: &fd) == noErr, "text format description")
    let tin = AVAssetWriterInput(mediaType: .text, outputSettings: nil, sourceFormatHint: fd)
    tin.marksOutputTrackAsEnabled = false
    tin.mediaDataLocation = .beforeMainMediaDataNotInterleaved   // the header's advice for chapter name tracks
    try expect(w.canAdd(tin), "writer refuses a text input")
    w.add(tin)
    vin.addTrackAssociation(withTrackOf: tin, type: AVAssetTrack.AssociationType.chapterList.rawValue)
    try expect(w.startWriting(), "startWriting: \(String(describing: w.error))")
    w.startSession(atSourceTime: .zero)
    for (n, t) in titles.enumerated() {
        // a QuickTime text sample: 16-bit big-endian length, then the UTF-8 text
        // + an 'encd' atom: UTF-8 (0x100)
        let u = Array(t.utf8), bytes = [UInt8(u.count >> 8), UInt8(u.count & 0xff)] + u + [0, 0, 0, 12, 0x65, 0x6e, 0x63, 0x64, 0, 0, 1, 0]
        var bb: CMBlockBuffer?
        try expect(CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: bytes.count, blockAllocator: nil, customBlockSource: nil,
                                                      offsetToData: 0, dataLength: bytes.count, flags: kCMBlockBufferAssureMemoryNowFlag, blockBufferOut: &bb) == noErr, "block buffer")
        _ = bytes.withUnsafeBytes { CMBlockBufferReplaceDataBytes(with: $0.baseAddress!, blockBuffer: bb!, offsetIntoDestination: 0, dataLength: bytes.count) }
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 1), presentationTimeStamp: CMTime(value: CMTimeValue(n), timescale: 1), decodeTimeStamp: .invalid)
        var size = bytes.count, sb: CMSampleBuffer?
        try expect(CMSampleBufferCreateReady(allocator: nil, dataBuffer: bb, formatDescription: fd, sampleCount: 1, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
                                             sampleSizeEntryCount: 1, sampleSizeArray: &size, sampleBufferOut: &sb) == noErr, "text sample buffer")
        while !tin.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
        try expect(tin.append(sb!), "append text sample \(n): \(String(describing: w.error))")
    }
    tin.markAsFinished()
    let frames = 30 * titles.count
    for i in 0..<frames {
        while !vin.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
        try expect(ad.append(p1Solid(64, 64, [UInt8(i * 7 % 256), 80, 160]), withPresentationTime: CMTime(value: CMTimeValue(i), timescale: 30)),
                   "append frame \(i): \(String(describing: w.error))")
    }
    vin.markAsFinished()
    await w.finishWriting()
    try expect(w.status == .completed, "finishWriting: \(String(describing: w.error))")
}
func p1Tones(_ hz: [Double], secs: Double, rate: Double = 44100) -> AVAudioPCMBuffer {
    let f = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
    let n = AVAudioFrameCount(secs * rate)
    let b = AVAudioPCMBuffer(pcmFormat: f, frameCapacity: n)!; b.frameLength = n
    let p = b.floatChannelData![0]
    for i in 0..<Int(n) { var s = 0.0; for h in hz { s += sin(2 * .pi * h * Double(i) / rate) }; p[i] = Float(0.5 * s / Double(hz.count)) }
    return b
}
let p1AAC: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 64000]
func p1AudioSampleBuffer(_ b: AVAudioPCMBuffer, pts: CMTime) throws -> CMSampleBuffer {
    var fd: CMAudioFormatDescription?
    try expect(CMAudioFormatDescriptionCreate(allocator: nil, asbd: b.format.streamDescription, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &fd) == noErr, "audio format description")
    var sb: CMSampleBuffer?
    var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: CMTimeScale(b.format.sampleRate)), presentationTimeStamp: pts, decodeTimeStamp: .invalid)
    try expect(CMSampleBufferCreate(allocator: nil, dataBuffer: nil, dataReady: false, makeDataReadyCallback: nil, refcon: nil, formatDescription: fd, sampleCount: CMItemCount(b.frameLength), sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sb) == noErr, "CMSampleBufferCreate")
    try expect(CMSampleBufferSetDataBufferFromAudioBufferList(sb!, blockBufferAllocator: nil, blockBufferMemoryAllocator: nil, flags: 0, bufferList: b.audioBufferList) == noErr, "set audio data")
    return sb!
}
func p21AVMovie(_ url: URL) async throws {
    try? FileManager.default.removeItem(at: url)
    let w = try AVAssetWriter(outputURL: url, fileType: .mov)
    w.shouldOptimizeForNetworkUse = true
    let vin = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 160, AVVideoHeightKey: 160])
    let ad = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vin, sourcePixelBufferAttributes: nil)
    let ain = AVAssetWriterInput(mediaType: .audio, outputSettings: p1AAC)
    w.add(vin); w.add(ain)
    try expect(w.startWriting(), "startWriting: \(String(describing: w.error))")
    w.startSession(atSourceTime: .zero)
    let tone = p1Tones([440], secs: 6)
    // whichever input is ready takes its next piece (the AAC encoder's delay keeps video waiting for audio ahead of it)
    var i = 0, off = 0
    while i < 180 || off < 180 * 1470 {
        if i < 180, vin.isReadyForMoreMediaData {
            try expect(ad.append(p1Solid(160, 160, [UInt8(i * 37 % 256), UInt8(i * 11 % 256), UInt8(255 - i % 256)]), withPresentationTime: CMTime(value: CMTimeValue(i), timescale: 30)),
                       "append frame \(i): \(String(describing: w.error))")
            i += 1
        } else if off < 180 * 1470, ain.isReadyForMoreMediaData {
            let part = AVAudioPCMBuffer(pcmFormat: tone.format, frameCapacity: 1470)!; part.frameLength = 1470
            memcpy(part.floatChannelData![0], tone.floatChannelData![0] + off, 1470 * 4)
            try expect(ain.append(try p1AudioSampleBuffer(part, pts: CMTime(value: CMTimeValue(off), timescale: 44100))), "append audio: \(String(describing: w.error))")
            off += 1470
            if off >= 180 * 1470 { ain.markAsFinished() }   // the video encoder's last frames wait for this
        } else { try await Task.sleep(for: .milliseconds(5)) }
    }
    vin.markAsFinished()
    await w.finishWriting()
    try expect(w.status == .completed, "finishWriting: \(String(describing: w.error))")
}
@main struct Main { static func main() async throws {
    let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().path
    let u = URL(fileURLWithPath: dir).appendingPathComponent("sdkcovChapters.mov")
    try await p21ChapterMovie(u, titles: ["Opening", "Middle", "Credits"])
    let g = try await AVURLAsset(url: u).loadChapterMetadataGroups(bestMatchingPreferredLanguages: ["en", "und"])
    print("chapters", g.count)
    try await p21AVMovie(URL(fileURLWithPath: dir).appendingPathComponent("sdkcovStall.mov"))
    print("stall", (try? FileManager.default.attributesOfItem(atPath: URL(fileURLWithPath: dir).appendingPathComponent("sdkcovStall.mov").path)[.size]).map { "\($0)" } ?? "?")
} }
