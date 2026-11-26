// SDK coverage, round 30 wave 2 (P28): public API of the SDK still not referenced by any check after P27
// (~/scratch/r30/apisurf.py), area: AV. Each check asserts what Apple's simulator answers (ref-mac.sh --only); ids
// start with "p28av-".
// AVFoundation: HLS from a loopback server (two variants, WebVTT subtitles, a date range): variants and qualifiers,
// media selections, metric events, access / error logs, the integrated timeline, video output; asset download
// sessions and configurations, the storage manager; resource-loader requests; the writing planner and resumable
// export; writer input groups, multi-pass and segment reports; fragmented movies; playback coordination media and the
// delegating coordinator; depth / matte objects from auxiliary dictionaries; the camera-only capture objects as the
// simulator answers them (no devices).
import Foundation
import Synchronization
import AVFoundation
import CoreMedia
import CoreVideo
#if canImport(UIKit)
import UIKit
#endif
#if canImport(CoreImage)
import CoreImage
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
#if canImport(ImageIO)
import ImageIO
#endif
#if canImport(QuartzCore)
import QuartzCore
#endif
#if canImport(VideoToolbox)
import VideoToolbox
#endif

/// a fresh file URL in tmp (any previous file removed)
func p28Tmp(_ name: String) -> URL {
    let u = FileManager.default.temporaryDirectory.appendingPathComponent("sdkcov-p28-\(name)")
    try? FileManager.default.removeItem(at: u)
    return u
}
/// `x` is an instance of the Objective-C class `name` (for classes Swift imports under another name)
func p28ObjC(_ x: AnyObject?, _ name: String) throws {
    guard let x else { throw Fail("no \(name) object") }
    guard let cls = NSClassFromString(name), x.isKind(of: cls) else { throw Fail("\(NSStringFromClass(type(of: x))) is not a \(name)") }
}
/// the names of the Objective-C classes of `xs`, counted ("AVMetricX": 2, ...)
func p28Classes(_ xs: [AnyObject]) -> [String: Int] {
    var d: [String: Int] = [:]
    for x in xs { d[NSStringFromClass(type(of: x)), default: 0] += 1 }
    return d
}

#if !os(watchOS)
/// P1HLS's segments behind a master playlist with two variants (200 / 400 kb/s, the same media), subtitles, and a
/// media playlist with a program date and an EXT-X-DATERANGE
final class P28HLS: @unchecked Sendable {
    let h = P1HLS()
    func make() async throws { try await h.make() }
    static let master = "#EXTM3U\n#EXT-X-VERSION:7\n#EXT-X-INDEPENDENT-SEGMENTS\n" +
        "#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID=\"subs\",NAME=\"English\",LANGUAGE=\"en\",DEFAULT=YES,AUTOSELECT=YES,URI=\"subs.m3u8\"\n" +
        "#EXT-X-STREAM-INF:BANDWIDTH=200000,AVERAGE-BANDWIDTH=150000,RESOLUTION=128x128,FRAME-RATE=30.000,SUBTITLES=\"subs\"\nvideo.m3u8\n" +
        "#EXT-X-STREAM-INF:BANDWIDTH=400000,AVERAGE-BANDWIDTH=300000,RESOLUTION=128x128,FRAME-RATE=30.000,SUBTITLES=\"subs\"\nvideo2.m3u8\n"
    var video: String {
        var s = h.video
        s = s.replacingOccurrences(of: "#EXT-X-MAP:", with: "#EXT-X-PROGRAM-DATE-TIME:2026-01-01T00:00:00.000Z\n" +
            "#EXT-X-DATERANGE:ID=\"p28\",CLASS=\"com.x86sim.sdkcov\",START-DATE=\"2026-01-01T00:00:00.500Z\",DURATION=1.0,X-COM-SDKCOV=\"hello\"\n#EXT-X-MAP:")
        return s
    }
    func respond(_ r: More2Req) -> More2Resp {
        let path = r.path.split(separator: "?").first.map(String.init) ?? r.path
        switch path {
        case "/master.m3u8": return .text(P28HLS.master, type: "application/vnd.apple.mpegurl")
        case "/video.m3u8", "/video2.m3u8": return .text(video, type: "application/vnd.apple.mpegurl")
        default: return h.respond(More2Req(method: r.method, path: path, headers: r.headers, body: r.body))
        }
    }
}

/// collects date-range metadata groups pushed by an AVPlayerItemMetadataCollector
final class P28Collector: NSObject, AVPlayerItemMetadataCollectorPushDelegate, @unchecked Sendable {
    let groups = P1Box<[AVDateRangeMetadataGroup]>([])
    func metadataCollector(_ c: AVPlayerItemMetadataCollector, didCollect g: [AVDateRangeMetadataGroup], indexesOfNewGroups n: IndexSet, indexesOfModifiedGroups m: IndexSet) {
        groups.mutate { $0 += g }
    }
}

/// a resource loader that keeps the requests it saw: content information, data, requestor
final class P28Loader: NSObject, AVAssetResourceLoaderDelegate, @unchecked Sendable {
    let data: Data, type: String
    let infos = P1Box<[String]>([]), ranges = P1Box<[String]>([]), requestors = P1Box<[String]>([])
    init(_ d: Data, type: String) { data = d; self.type = type }
    func resourceLoader(_ l: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource r: AVAssetResourceLoadingRequest) -> Bool {
        if let ci: AVAssetResourceLoadingContentInformationRequest = r.contentInformationRequest {
            ci.contentType = type; ci.contentLength = Int64(data.count); ci.isByteRangeAccessSupported = true
            infos.mutate { $0.append("\(ci.allowedContentTypes?.count ?? -1) types") }
        }
        let who: AVAssetResourceLoadingRequestor = r.requestor
        requestors.mutate { $0.append("\(who.providesExpiredSessionReports)") }
        if let dr: AVAssetResourceLoadingDataRequest = r.dataRequest {
            let start = Int(dr.currentOffset != 0 ? dr.currentOffset : dr.requestedOffset)
            let end = dr.requestsAllDataToEndOfResource ? data.count : min(data.count, Int(dr.requestedOffset) + dr.requestedLength)
            ranges.mutate { $0.append("\(dr.requestedOffset)+\(dr.requestedLength)") }
            if start < end { dr.respond(with: data.subdata(in: start..<end)) }
        }
        r.finishLoading()
        return true
    }
    func resourceLoader(_ l: AVAssetResourceLoader, shouldWaitForRenewalOfRequestedResource r: AVAssetResourceRenewalRequest) -> Bool { false }
}

/// a playback control delegate for AVDelegatingPlaybackCoordinator: records the commands it is issued
final class P28Control: NSObject, AVPlaybackCoordinatorPlaybackControlDelegate, @unchecked Sendable {
    let cmds = P1Box<[String]>([])
    func playbackCoordinator(_ c: AVDelegatingPlaybackCoordinator, didIssue cmd: AVDelegatingPlaybackCoordinatorPlayCommand, completionHandler: @escaping @Sendable () -> Void) {
        let base: AVDelegatingPlaybackCoordinatorPlaybackControlCommand = cmd
        cmds.mutate { $0.append("play \(cmd.rate) item \(base.expectedCurrentItemIdentifier)") }; completionHandler()
    }
    func playbackCoordinator(_ c: AVDelegatingPlaybackCoordinator, didIssue cmd: AVDelegatingPlaybackCoordinatorPauseCommand, completionHandler: @escaping @Sendable () -> Void) {
        cmds.mutate { $0.append("pause \(cmd.shouldBufferInAnticipationOfPlayback)") }; completionHandler()
    }
    func playbackCoordinator(_ c: AVDelegatingPlaybackCoordinator, didIssue cmd: AVDelegatingPlaybackCoordinatorSeekCommand, completionHandler: @escaping @Sendable () -> Void) {
        cmds.mutate { $0.append("seek \(cmd.itemTime.seconds)") }; completionHandler()
    }
    func playbackCoordinator(_ c: AVDelegatingPlaybackCoordinator, didIssue cmd: AVDelegatingPlaybackCoordinatorBufferingCommand, completionHandler: @escaping @Sendable () -> Void) {
        cmds.mutate { $0.append("buffer \(cmd.anticipatedPlaybackRate)") }; completionHandler()
    }
}
#endif

#if !os(watchOS)
/// segment reports of an HLS-profile writer
final class P28Segments: NSObject, AVAssetWriterDelegate, @unchecked Sendable {
    let reports = P1Box<[AVAssetSegmentTrackReport]>([])
    func assetWriter(_ w: AVAssetWriter, didOutputSegmentData d: Data, segmentType t: AVAssetSegmentType, segmentReport r: AVAssetSegmentReport?) {
        if let r { reports.mutate { $0 += r.trackReports } }
    }
}
/// a compositor that passes the source frame through and counts render hints and requests
final class P28HintCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    static let hints = Atomic<Int>(0), prerolls = Atomic<Int>(0), requests = Atomic<Int>(0)
    var sourcePixelBufferAttributes: [String: any Sendable]? { [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA] }
    var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] { [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA] }
    func renderContextChanged(_ c: AVVideoCompositionRenderContext) {}
    func anticipateRendering(using h: AVVideoCompositionRenderHint) { P28HintCompositor.hints.add(1, ordering: .relaxed); _ = h.startCompositionTime }
    func prerollForRendering(using h: AVVideoCompositionRenderHint) { P28HintCompositor.prerolls.add(1, ordering: .relaxed); _ = h.endCompositionTime }
    func startRequest(_ r: AVAsynchronousVideoCompositionRequest) {
        P28HintCompositor.requests.add(1, ordering: .relaxed)
        if let id = r.sourceTrackIDs.first?.int32Value, let f = r.sourceFrame(byTrackID: id) { r.finish(withComposedVideoFrame: f) } else { r.finish(with: NSError(domain: "sdkcov", code: 2)) }
    }
}
/// a content key session delegate: key requests, persistable requests, content keys
final class P28Keys: NSObject, AVContentKeySessionDelegate, @unchecked Sendable {
    let log = P1Box<[String]>([]), keys = P1Box<[AVContentKey]>([])
    func contentKeySession(_ s: AVContentKeySession, didProvide r: AVContentKeyRequest) {
        log.mutate { $0.append("request \(String(describing: r.identifier))") }
        r.processContentKeyResponse(AVContentKeyResponse(clearKeyData: Data(repeating: 7, count: 16), initializationVector: nil))
    }
    func contentKeySession(_ s: AVContentKeySession, didProvide r: AVPersistableContentKeyRequest) { log.mutate { $0.append("persistable") } }
    func contentKeySession(_ s: AVContentKeySession, didProvide k: AVContentKey) { keys.mutate { $0.append(k) }; log.mutate { $0.append("key") } }
    func contentKeySession(_ s: AVContentKeySession, contentKeyRequest r: AVContentKeyRequest, didFailWithError e: Error) { log.mutate { $0.append("failed \(p8Err(e))") } }
    func contentKeySession(_ s: AVContentKeySession, contentKeyRequestDidSucceed r: AVContentKeyRequest) { log.mutate { $0.append("succeeded") } }
}
#endif

#if os(iOS) || os(visionOS)
/// AVAssetDownloadDelegate: where the asset goes, variants, metric events, completion
final class P28Download: NSObject, AVAssetDownloadDelegate, @unchecked Sendable {
    let events = P1Box<[String]>([]), metrics = P1Box<[AVMetricEvent]>([])
    let location = P1Box<URL?>(nil), done = P1Box<String?>(nil)
    func urlSession(_ s: URLSession, assetDownloadTask t: AVAssetDownloadTask, willDownloadTo u: URL) { location.value = u; events.mutate { $0.append("will \(u.lastPathComponent)") } }
    func urlSession(_ s: URLSession, assetDownloadTask t: AVAssetDownloadTask, willDownloadVariants v: [AVAssetVariant]) { events.mutate { $0.append("variants \(v.count)") } }
    func urlSession(_ s: URLSession, assetDownloadTask t: AVAssetDownloadTask, didReceive e: AVMetricEvent) { metrics.mutate { $0.append(e) } }
    func urlSession(_ s: URLSession, task: URLSessionTask, didCompleteWithError e: Error?) { done.value = e.map { "\(($0 as NSError).domain) \(($0 as NSError).code)" } ?? "ok" }
}
#endif

extension Registry {
    static var p28av: [Check] {
        var c: [Check] = []
        #if !os(watchOS)
        c.append(check("AVFoundation", "p28av-hls-variants-selection-metrics", timeout: 90) {
            let hls = P28HLS(); try await hls.make()
            let srv = try More2HTTP { hls.respond($0) }; _ = try await srv.start()
            defer { srv.stop() }
            let asset = AVURLAsset(url: srv.url("/master.m3u8"))
            // variants of the multivariant playlist, their video attributes, qualifiers
            let variants: [AVAssetVariant] = try await asset.load(.variants)
            try expect(variants.count == 2, "variants \(variants.count)")
            let peaks = variants.compactMap(\.peakBitRate).sorted(), avgs = variants.compactMap(\.averageBitRate).sorted()
            try expect(peaks == [200000, 400000] && avgs == [150000, 300000], "bit rates \(peaks) \(avgs)")
            guard let va: AVAssetVariant.VideoAttributes = variants[0].videoAttributes else { throw Fail("no video attributes") }
            try p28ObjC(va, "AVAssetVariantVideoAttributes")
            try expect(va.presentationSize == CGSize(width: 128, height: 128) && abs((va.nominalFrameRate ?? 0) - 30) < 0.01, "video attributes \(va.presentationSize) \(String(describing: va.nominalFrameRate))")
            let layouts: [AVAssetVariant.VideoAttributes.LayoutAttributes] = va.videoLayoutAttributes
            for l in layouts { try p28ObjC(l, "AVAssetVariantVideoLayoutAttributes") }
                        let audio: AVAssetVariant.AudioAttributes? = variants[0].audioAttributes
            // Apple: attributes with no formats on a video-only variant
            if let audio { try p28ObjC(audio, "AVAssetVariantAudioAttributes") }
            try expect(audio?.formatIDs.isEmpty ?? true, "audio formats on a video-only variant: \(String(describing: audio?.formatIDs))")
            let q1 = AVAssetVariantQualifier(predicate: AVAssetVariantQualifier.predicate(forPresentationHeight: 128, operatorType: .equalTo))
            let q2 = AVAssetVariantQualifier(variant: variants[1])
            try expect((q1.copy() as AnyObject) is AVAssetVariantQualifier && variants[1].url.lastPathComponent == "video2.m3u8", "qualifier copy / variant URL \(variants[1].url)")
            // media selection: the subtitle group, its options, a mutable selection
            guard let group: AVMediaSelectionGroup = try await asset.loadMediaSelectionGroup(for: .legible) else { throw Fail("no legible group") }
            let opts: [AVMediaSelectionOption] = group.options
            guard let en = opts.first(where: { $0.extendedLanguageTag == "en" }) else { throw Fail("no English option in \(opts.map(\.displayName))") }
            try expect(en.mediaType == .subtitle && en.hasMediaCharacteristic(.legible) && group.allowsEmptySelection, "option \(en.mediaType.rawValue)")
            let sel: AVMediaSelection = try await asset.load(.preferredMediaSelection)
            guard let msel = sel.mutableCopy() as? AVMutableMediaSelection else { throw Fail("mutableCopy is not AVMutableMediaSelection") }
            msel.select(nil, in: group)
            let cleared = msel.selectedMediaOption(in: group) == nil
            msel.select(en, in: group)
            try expect(cleared && msel.selectedMediaOption(in: group) == en && sel.asset === asset, "mutable selection")
            let scheme: AVCustomMediaSelectionScheme? = group.customMediaSelectionScheme
            let selectors: [AVMediaPresentationSelector] = scheme?.selectors ?? []
            let settings: [AVMediaPresentationSetting] = selectors.flatMap(\.settings)
            try expect(scheme == nil && settings.isEmpty, "custom selection scheme on plain HLS subtitles: \(String(describing: scheme))")
            // Apple: a streamed asset has an asset cache, not playable offline, with nothing cached yet
            let cache: AVAssetCache? = asset.assetCache
            let cachedOpts = cache.map { $0.mediaSelectionOptions(in: group).count } ?? -1
            try expect(cache != nil && cache?.isPlayableOffline == false, "asset cache \(String(describing: cache)) offline \(String(describing: cache?.isPlayableOffline))")
            let track: [AVAssetTrackGroup] = try await asset.load(.trackGroups)
            // playback: metric events, logs, the integrated timeline, date-range metadata
            let item = AVPlayerItem(asset: asset)
            let coll = AVPlayerItemMetadataCollector(identifiers: nil, classifyingLabels: nil)
            let cd = P28Collector(); coll.setDelegate(cd, queue: .main); item.add(coll)
            let got = P1Box<[AVMetricEvent]>([])
            let mt = Task { do { for try await e in item.allMetrics() { got.mutate { $0.append(e) } } } catch {} }
            let player = AVPlayer(playerItem: item); player.isMuted = true
            guard await more2Wait(20, { item.status != .unknown }) else { mt.cancel(); throw Fail("item status unknown") }
            try expect(item.status == .readyToPlay, "item: \(String(describing: item.error))")
            // the video output API on the same player: a monoscopic specification, a sample while playing
            let spec = AVVideoOutputSpecification(tagCollections: [.monoscopicForVideoOutput()])
            spec.defaultPixelBufferAttributes = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            let vout = AVPlayerVideoOutput(specification: spec)
            player.videoOutput = vout
            let base: AVPlayerItemOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: nil)
            try expect(spec.preferredTagCollections.count == 1 && player.videoOutput === vout, "video output spec \(spec.preferredTagCollections.count)")
            player.play()
            let moved = await more2Wait(10) { player.currentTime().seconds > 1.0 }
            let sample = vout.sample(forHostTime: CMClockGetTime(CMClockGetHostTimeClock()))
            if let sample {
                let cfg: AVPlayerVideoOutput.Configuration = sample.activeConfiguration
                try p28ObjC(cfg, "AVPlayerVideoOutputConfiguration")
                try expect(cfg.sourcePlayerItem === item && !sample.taggedBuffers.isEmpty, "video output sample: \(sample.taggedBuffers.count) buffers")
            }
            await player.seek(to: CMTime(value: 1, timescale: 2))
            player.pause()
            _ = await more2Wait(3) { got.value.contains { $0 is AVMetricPlayerItemSeekDidCompleteEvent } }
            try expect(moved, "playback did not advance: \(player.currentTime().seconds)")
            let tl: AVPlayerItemIntegratedTimeline = item.integratedTimeline
            let snap: AVPlayerItemIntegratedTimelineSnapshot = tl.currentSnapshot
            let segs: [AVPlayerItemSegment] = snap.segments
            // Apple's simulator: a plain VOD item (no interstitials) has no timeline segments and an indefinite duration
            try expect(segs.allSatisfy { $0.segmentType == .primary } && (segs.isEmpty || abs(snap.duration.seconds - 2) < 0.2), "timeline segments \(segs.map(\.segmentType.rawValue)) duration \(snap.duration.seconds)")
            let alog: AVPlayerItemAccessLog? = item.accessLog()
            let aev: [AVPlayerItemAccessLogEvent] = alog?.events ?? []
            try expect(!aev.isEmpty && aev.contains { ($0.uri ?? "").contains("video") } && aev.reduce(0, { $0 + $1.numberOfBytesTransferred }) > 0, "access log \(aev.map { $0.uri ?? "-" })")
            let elog: AVPlayerItemErrorLog? = item.errorLog()
            let eev: [AVPlayerItemErrorLogEvent] = elog?.events ?? []
            let dr = await more2Wait(3) { !cd.groups.value.isEmpty }
            let drg = cd.groups.value
            try expect(dr && drg.contains { $0.startDate == ISO8601DateFormatter().date(from: "2026-01-01T00:00:00Z")!.addingTimeInterval(0.5) }, "date range groups \(drg.map(\.startDate))")
            player.replaceCurrentItem(with: nil)
            _ = await more2Wait(3) { got.value.contains { $0 is AVMetricPlayerItemPlaybackSummaryEvent } }
            mt.cancel()
            let evs = got.value
            // each metric event family, read through its own class
            var seen: [String] = []
            for e in evs {
                let base: AVMetricEvent = e
                _ = base.date; _ = base.mediaTime
                switch e {
                case let x as AVMetricPlayerItemInitialLikelyToKeepUpEvent:
                    seen.append("initial(\(x.playlistRequestEvents.count) playlists, \(x.mediaSegmentRequestEvents.count) segments, \(x.contentKeyRequestEvents.count) keys)")
                    let pl: [AVMetricHLSPlaylistRequestEvent] = x.playlistRequestEvents
                    let ms: [AVMetricHLSMediaSegmentRequestEvent] = x.mediaSegmentRequestEvents
                    let ks: [AVMetricContentKeyRequestEvent] = x.contentKeyRequestEvents
                    let rr: AVMetricMediaResourceRequestEvent? = pl.first?.mediaResourceRequestEvent
                    try expect(!pl.isEmpty && pl.contains { $0.isMultivariantPlaylist } && ks.isEmpty && (ms.isEmpty || ms.allSatisfy { $0.indexFileURL.path.contains("video") }), "initial event playlists \(pl.map { $0.url?.lastPathComponent ?? "-" })")
                    _ = rr?.wasReadFromCache
                case let x as AVMetricPlayerItemLikelyToKeepUpEvent: seen.append("likely \(x.loadedTimeRanges.count)")
                case let x as AVMetricPlayerItemSeekDidCompleteEvent: seen.append("seekDone \(x.didSeekInBuffer)")
                case let x as AVMetricPlayerItemSeekEvent: seen.append("seek \(x.rate)")
                case let x as AVMetricPlayerItemStallEvent: seen.append("stall \(x.rate)")
                case let x as AVMetricPlayerItemRateChangeEvent: seen.append("rate \(x.previousRate)->\(x.rate)")
                case let x as AVMetricPlayerItemVariantSwitchStartEvent: seen.append("switchStart \(x.toVariant.peakBitRate)")
                case let x as AVMetricPlayerItemVariantSwitchEvent:
                    let vr: AVMetricMediaRendition = x.videoRendition
                    seen.append("switch \(x.didSucceed) \(vr.url?.lastPathComponent ?? "-")")
                case let x as AVMetricPlayerItemPlaybackSummaryEvent: seen.append("summary \(x.mediaResourceRequestCount)")
                case let x as AVMetricHLSPlaylistRequestEvent: seen.append("playlist \(x.isMultivariantPlaylist)")
                case let x as AVMetricHLSMediaSegmentRequestEvent: seen.append("segment \(x.isMapSegment)")
                case let x as AVMetricMediaResourceRequestEvent: seen.append("resource \(x.url?.lastPathComponent ?? "-")")
                case let x as AVMetricErrorEvent: seen.append("error \(x.didRecover)")
                case let x as AVMetricPlaybackModeSwitchEvent: seen.append("mode \(x.mode.rawValue)")
                default: seen.append(NSStringFromClass(type(of: e)))
                }
            }
            // Apple's simulator streams the request events and a variant switch start for this item (no likely-to-keep-up /
            // rate events through allMetrics())
            try expect(evs.contains { ($0 as? AVMetricHLSPlaylistRequestEvent)?.isMultivariantPlaylist == true } && evs.contains { $0 is AVMetricHLSMediaSegmentRequestEvent }, "metric events \(p28Classes(evs))")
            return "\(variants.count) variants, \(layouts.count) layouts, qualifiers \([q1, q2].count), \(opts.count) subtitle options, \(track.count) track groups, \(aev.count) access / \(eev.count) error log events, \(drg.count) date ranges; cache options \(cachedOpts); metrics \(seen); item output \(type(of: base)), video output sample \(sample != nil)"
        })
        c.append(check("AVFoundation", "p28av-resource-loader-requests", timeout: 60) {
            let src = p28Tmp("rl.mp4")
            try await p1Movie(src, frames: 30, type: .mp4, color: { _ in [0, 255, 0] })
            let ld = P28Loader(try Data(contentsOf: src), type: UTType.mpeg4Movie.identifier)
            let asset = AVURLAsset(url: URL(string: "sdkcovp28://media/movie.mp4")!)
            asset.resourceLoader.setDelegate(ld, queue: DispatchQueue(label: "p28.loader"))
            let (dur, tracks) = try await asset.load(.duration, .tracks)
            try expect(abs(dur.seconds - 1) < 0.1 && tracks.count == 1, "asset \(dur.seconds) s, \(tracks.count) tracks")
            try expect(!ld.infos.value.isEmpty && !ld.ranges.value.isEmpty && !ld.requestors.value.isEmpty, "loader requests: info \(ld.infos.value) data \(ld.ranges.value)")
            // a renewal request is a loading request (it reaches the renewal callback only for expiring keys)
            let renewalIsLoading = AVAssetResourceRenewalRequest.self is AVAssetResourceLoadingRequest.Type
            try expect(renewalIsLoading, "AVAssetResourceRenewalRequest is not an AVAssetResourceLoadingRequest")
            return "\(ld.infos.value.count) content-info requests (\(ld.infos.value.first ?? "-")), \(ld.ranges.value.count) data requests \(ld.ranges.value.prefix(3)), requestor reports \(ld.requestors.value.first ?? "-")"
        })
        c.append(check("AVFoundation", "p28av-planner-resumable-export", timeout: 90) {
            // the incremental writing planner: a 2-segment H.264 track plan, each segment written by an asset writer
            // through the request's resumable writer input, assembled into a composition
            let dir = p28Tmp("planner"); try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let segCfg: [AVPlannedVideoSegmentConfiguration] = [AVPlannedVideoSegmentConfiguration(numberOfFrames: 15, duration: CMTime(value: 15, timescale: 30)),
                                                               AVPlannedVideoSegmentConfiguration(numberOfFrames: 15, duration: CMTime(value: 15, timescale: 30))]
            let baseCfg: AVPlannedSegmentConfiguration = segCfg[0]
            try expect(baseCfg.duration == CMTime(value: 15, timescale: 30) && segCfg[1].frameCount == 15, "segment configurations")
            // a video track plan: the simulator's encoders do not support segmented (resumable) encoding, so the
            // plan's initializer raises (NSInvalidArgumentException)
            var vplan: AVAssetVideoTrackPlan?
            let vex = SDKCovCatch { vplan = AVAssetVideoTrackPlan(videoCodecType: .hevc, mediaType: .video, segmentConfigurations: segCfg, assemblyTrackID: 1) }
            if let vplan { try expect(vplan.videoCodecType == .hevc, "video plan codec") }
            // an audio track plan (no encoder state): two 0.5 s LPCM segments, each written by an asset writer
            let acfg = [AVPlannedSegmentConfiguration(duration: CMTime(value: 1, timescale: 2)), AVPlannedSegmentConfiguration(duration: CMTime(value: 1, timescale: 2))]
            let plan = AVAssetTrackPlan(mediaType: .audio, segmentConfigurations: acfg, assemblyTrackID: 2)
            try expect(plan.segmentConfigurations.count == 2 && plan.assemblyTrackID == 2 && plan.mediaType == .audio, "track plan")
            let planner = try AVAssetWritingPlanner(directoryForTemporaryFiles: dir)
            let prog: AVAssetWritingPlannerProgress = planner.progress
            let reqs = P1Box<[String]>([])
            let lpcm: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16,
                                       AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false]
            let pex = SDKCovCatch { planner.plan(plan) { (req: AVPlannedSegmentWritingRequest) in
                if req is AVPlannedVideoSegmentWritingRequest { return .cancelled }
                try? FileManager.default.removeItem(at: req.segmentFileOutputURL)
                let w = try AVAssetWriter(outputURL: req.segmentFileOutputURL, fileType: .mov)
                let input = AVAssetWriterInput(mediaType: .audio, outputSettings: lpcm)
                w.add(input)
                guard w.startWriting() else { throw w.error ?? Fail("segment writer") }
                w.startSession(atSourceTime: .zero)
                let b = p1Tones([440], secs: req.timeRange.duration.seconds)
                while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
                _ = input.append(try p1AudioSampleBuffer(b, pts: .zero))
                input.markAsFinished(); await w.finishWriting()
                reqs.mutate { $0.append("\(req.timeRange.start.seconds)+\(req.timeRange.duration.seconds) \(w.status.rawValue)") }
                return w.status == .completed ? .success : .cancelled
            } }
            var planned = "?"
            if pex == nil {
                do {
                    let comp = try await planner.executePlan()
                    let d = try await comp.load(.duration)
                    planned = "composition \(String(format: "%.2f", d.seconds)) s"
                } catch { planned = "executePlan \(p8Err(error))" }
            } else { planned = "plan raised \(pex!)" }
            // a resumable export session: its configuration state (through the Objective-C state object)
            let mv = p28Tmp("resume.mov"); try await p1Movie(mv, frames: 15, size: 64)
            guard let es = AVAssetExportSession(asset: AVURLAsset(url: mv), presetName: AVAssetExportPresetHighestQuality) else { throw Fail("no export session") }
            es.outputURL = p28Tmp("resume-out.mov"); es.outputFileType = .mov
            es.directoryForTemporaryFiles = dir
            // the Objective-C state object (refined for Swift into ResumptionState)
            let st: __AVAssetExportSessionResumptionState = await withCheckedContinuation { k in es.__configureForResumableExport { k.resume(returning: $0) } }
            try expect(NSStringFromClass(type(of: st)) == "AVAssetExportSessionResumptionState", "resumption state class \(type(of: st))")
            let state = st.isResumptionConfigured ? "resumable (from previous \(st.isResumingFromPreviousState))" : "not resumable: \(st.configurationFailureReason?.rawValue ?? "-")"
            return "video plan \(vex?.first ?? "made"); audio segments \(reqs.value); \(planned); progress \(prog.overallProgress); export \(state)"
        })
        c.append(check("AVFoundation", "p28av-coordination-medium-delegating", timeout: 60) {
            // two players on one coordination medium: both coordinators connect
            let medium = AVPlaybackCoordinationMedium()
            let mv = p28Tmp("coord.mov"); try await p1Movie(mv, frames: 30, size: 64)
            let p1 = AVPlayer(url: mv), p2 = AVPlayer(url: mv)
            try p1.playbackCoordinator.coordinate(using: medium)
            try p2.playbackCoordinator.coordinate(using: medium)
            try expect(medium.connectedPlaybackCoordinators.count == 2 && p1.playbackCoordinator.playbackCoordinationMedium === medium, "medium coordinators \(medium.connectedPlaybackCoordinators.count)")
            try p1.playbackCoordinator.coordinate(using: nil)
            let after = medium.connectedPlaybackCoordinators.count
            // a delegating coordinator alone: an item transition and a rate change reach its control delegate
            let ctl = P28Control()
            let dc = AVDelegatingPlaybackCoordinator(playbackControlDelegate: ctl)
            dc.transitionToItem(withIdentifier: "item-1", proposingInitialTimingBasedOn: nil)
            dc.coordinateRateChange(to: 1, options: [])
            dc.coordinateSeek(to: CMTime(value: 1, timescale: 2), options: [])
            _ = await more2Wait(3) { ctl.cmds.value.count >= 2 }
            try expect(dc.currentItemIdentifier == "item-1" && ctl.cmds.value.contains { $0.hasPrefix("play") || $0.hasPrefix("buffer") }, "delegate commands \(ctl.cmds.value)")
            return "medium had 2, \(after) after disconnect; delegate commands \(ctl.cmds.value)"
        })
        #endif
        #if !os(watchOS)
        c.append(check("AVFoundation", "p28av-writer-groups-passes-segments", timeout: 90) {
            // two alternate audio tracks in one input group (English default, French), a multi-pass video input
            let out = p28Tmp("groups.mov")
            let w = try AVAssetWriter(outputURL: out, fileType: .mov)
            let vin = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64])
            vin.performsMultiPassEncodingIfSupported = true; vin.expectsMediaDataInRealTime = false
            let ad = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vin, sourcePixelBufferAttributes: nil)
            let aEN = AVAssetWriterInput(mediaType: .audio, outputSettings: p1AAC), aFR = AVAssetWriterInput(mediaType: .audio, outputSettings: p1AAC)
            aEN.languageCode = "eng"; aFR.languageCode = "fra"; aEN.marksOutputTrackAsEnabled = true; aFR.marksOutputTrackAsEnabled = false
            for i in [vin, aEN, aFR] { w.add(i) }
            let grp = AVAssetWriterInputGroup(inputs: [aEN, aFR], defaultInput: aEN)
            let asSel: AVMediaSelectionGroup = grp
            let canAddGroup = w.canAdd(grp)
            try expect(canAddGroup && grp.inputs.count == 2 && grp.defaultInput === aEN, "input group: canAdd \(canAddGroup), \(grp.inputs.count) inputs, options \(asSel.options.count)")
            w.add(grp)
            try expect(w.startWriting(), "startWriting \(String(describing: w.error))")
            w.startSession(atSourceTime: .zero)
            // the passes: each pass description says which source ranges to append; nil when the input is done
            var passes: [String] = []
            let passDone = P1Box<Bool>(false), passLog = P1Box<[String]>([])
            vin.respondToEachPassDescription(on: DispatchQueue(label: "p28.passes")) {
                guard let pd: AVAssetWriterInputPassDescription = vin.currentPassDescription else { vin.markAsFinished(); passDone.value = true; return }
                passLog.mutate { $0.append("\(pd.sourceTimeRanges.count) ranges") }
                for i in 0..<30 {
                    while !vin.isReadyForMoreMediaData { usleep(5000) }
                    _ = ad.append(p1Solid(64, 64, [UInt8(i * 8), 0, 0]), withPresentationTime: CMTime(value: CMTimeValue(i), timescale: 30))
                }
                vin.markCurrentPassAsFinished()
            }
            _ = await more2Wait(30) { passDone.value }
            passes = passLog.value
            try expect(passDone.value && !passes.isEmpty, "passes \(passes)")
            for (k, a) in [aEN, aFR].enumerated() {
                let b = p1Tones([440 * Double(k + 1)], secs: 1)
                while !a.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
                _ = a.append(try p1AudioSampleBuffer(b, pts: .zero)); a.markAsFinished()
            }
            await w.finishWriting()
            try expect(w.status == .completed, "groups writer \(String(describing: w.error))")
            let asset = AVURLAsset(url: out)
            let tg: [AVAssetTrackGroup] = try await asset.load(.trackGroups)
            try expect(tg.count == 1 && tg[0].trackIDs.count == 2, "track groups \(tg.map(\.trackIDs))")
            let ag = try await asset.loadMediaSelectionGroup(for: .audible)
            let langs = ag?.options.compactMap(\.extendedLanguageTag).sorted() ?? []
            // an HLS-profile writer: its segment reports per track, the first video sample's information
            let seg = P28Segments()
            let hw = AVAssetWriter(contentType: UTType(AVFileType.mp4.rawValue)!)
            hw.outputFileTypeProfile = .mpeg4AppleHLS; hw.preferredOutputSegmentInterval = CMTime(value: 1, timescale: 2); hw.initialSegmentStartTime = .zero; hw.delegate = seg
            let hin = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64,
                AVVideoCompressionPropertiesKey: [AVVideoMaxKeyFrameIntervalKey: 15, AVVideoAllowFrameReorderingKey: false]])
            let had = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: hin, sourcePixelBufferAttributes: nil)
            hw.add(hin); try expect(hw.startWriting(), "HLS writer"); hw.startSession(atSourceTime: .zero)
            for i in 0..<30 {
                while !hin.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
                _ = had.append(p1Solid(64, 64, [0, 255, 0]), withPresentationTime: CMTime(value: CMTimeValue(i), timescale: 30))
            }
            hin.markAsFinished(); await hw.finishWriting()
            let reps = seg.reports.value
            let firsts: [AVAssetSegmentReportSampleInformation] = reps.compactMap(\.firstVideoSampleInformation)
            try expect(reps.count >= 2 && reps.allSatisfy { $0.mediaType == .video } && firsts.allSatisfy { $0.isSyncSample && $0.length > 0 }, "segment reports \(reps.count), firsts \(firsts.map(\.isSyncSample))")
            return "multi-pass \(vin.canPerformMultiplePasses) \(passes); \(tg.count) track group of \(tg.first?.trackIDs.count ?? 0), audible languages \(langs); \(reps.count) segment track reports, first sample offsets \(firsts.map(\.offset))"
        })
        c.append(check("AVFoundation", "p28av-composition-ci-filtering", timeout: 90) {
            let mv = p28Tmp("tools.mov"); try await p1Movie(mv, frames: 30, size: 64, color: { _ in [255, 0, 0] })
            let asset = AVURLAsset(url: mv)
            // Core Image filtering through the request object
            let seen = Atomic<Int>(0)
            let ci = try await AVMutableVideoComposition.videoComposition(with: asset) { (r: AVAsynchronousCIImageFilteringRequest) in
                seen.add(1, ordering: .relaxed)
                r.finish(with: r.sourceImage.applyingFilter("CIColorInvert"), context: nil)
            }
            let px = p1BGRA(try await p1Frame(asset, at: 0.2, composition: ci), 32, 32)
            try expect(seen.load(ordering: .relaxed) > 0 && px[0] < 128 && px[1] > 128, "CI filtered frame \(px) after \(seen.load(ordering: .relaxed)) requests")
            return "CI \(px.prefix(3)) after \(seen.load(ordering: .relaxed)) requests"
        })
        c.append(check("AVFoundation", "p28av-composition-animation-tool", timeout: 90) {
            let mv = p28Tmp("tools2.mov"); try await p1Movie(mv, frames: 30, size: 64, color: { _ in [255, 0, 0] })
            let asset = AVURLAsset(url: mv)
            // a Core Animation layer tree over the video in an export
            let vc = try await AVMutableVideoComposition.videoComposition(withPropertiesOf: asset)
            let parent = CALayer(), video = CALayer(), over = CALayer()
            parent.frame = CGRect(x: 0, y: 0, width: 64, height: 64); video.frame = parent.frame
            over.frame = CGRect(x: 0, y: 0, width: 32, height: 64); over.backgroundColor = CGColor(red: 0, green: 1, blue: 0, alpha: 1)
            parent.addSublayer(video); parent.addSublayer(over)
            let tool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: video, in: parent)
            vc.animationTool = tool
            // exporting through the tool aborts the app in the simulator (Apple's too: "unrecognised property key", then
            // a trap), so the composition is validated, not rendered
            let valid = try await vc.isValid(for: asset, timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 1, timescale: 1)), validationDelegate: nil)
            let extra = AVVideoCompositionCoreAnimationTool(additionalLayer: CALayer(), asTrackID: 99)
            try expect(vc.animationTool === tool && valid, "composition with animation tool valid \(valid)")
            let exported = "valid", halves: [[Int]] = []
            _ = extra
            return "export with animation tool \(exported) halves \(halves.map { Array($0.prefix(3)) })"
        })
        c.append(check("AVFoundation", "p28av-compositor-render-hints", timeout: 60) {
            let mv = p28Tmp("tools3.mov"); try await p1Movie(mv, frames: 30, size: 64)
            let asset = AVURLAsset(url: mv)
            // render hints reach a custom compositor during playback
            let hv = try await AVMutableVideoComposition.videoComposition(withPropertiesOf: asset)
            hv.customVideoCompositorClass = P28HintCompositor.self
            let item = AVPlayerItem(asset: asset); item.videoComposition = hv
            let vout = AVPlayerItemVideoOutput(pixelBufferAttributes: nil); item.add(vout)
            let player = AVPlayer(playerItem: item); player.isMuted = true
            _ = await more2Wait(10) { item.status == .readyToPlay }
            player.play(); _ = await more2Wait(5) { player.currentTime().seconds > 0.5 }; player.pause()
            let hints = P28HintCompositor.hints.load(ordering: .relaxed) + P28HintCompositor.prerolls.load(ordering: .relaxed)
            return "compositor requests \(P28HintCompositor.requests.load(ordering: .relaxed)), hints \(hints)"
        })
        c.append(check("AVFoundation", "p28av-clear-key-content-keys", timeout: 30) {
            // clear-key content key session: a key request answered with key data
            let keys = P28Keys()
            let ks = AVContentKeySession(keySystem: .clearKey)
            ks.setDelegate(keys, queue: DispatchQueue(label: "p28.keys"))
            ks.processContentKeyRequest(withIdentifier: "p28-key", initializationData: nil, options: nil)
            _ = await more2Wait(5) { keys.log.value.contains { $0.hasPrefix("succeeded") || $0.hasPrefix("failed") || $0 == "key" } }
            let ck: [AVContentKey] = keys.keys.value
            ks.expire()
            return "keys \(keys.log.value), \(ck.count) content keys"
        })
        c.append(check("AVFoundation", "p28av-depth-mattes-spatial", timeout: 30) {
            // auxiliary-image dictionaries (what Image I/O hands over for a photo's depth / matte): disparity, portrait
            // effects matte, a skin segmentation matte
            func aux(_ fmt: OSType, _ bpp: Int, _ fill: UInt8) -> [String: Any] {
                let w = 8, h = 8
                return [kCGImageAuxiliaryDataInfoData as String: Data(repeating: fill, count: w * h * bpp),
                        kCGImageAuxiliaryDataInfoDataDescription as String: ["Width": w, "Height": h, "BytesPerRow": w * bpp, "PixelFormat": fmt] as [String: Any],
                        kCGImageAuxiliaryDataInfoMetadata as String: CGImageMetadataCreateMutable()]
            }
            var notes: [String] = []
            var depthOK = false
            do {
                let d = try AVDepthData(fromDictionaryRepresentation: aux(kCVPixelFormatType_DisparityFloat16, 2, 0x3c))
                let conv = d.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
                let cal: AVCameraCalibrationData? = d.cameraCalibrationData
                var t: NSString?
                let back = d.dictionaryRepresentation(forAuxiliaryDataType: &t)
                depthOK = CVPixelBufferGetWidth(d.depthDataMap) == 8 && conv.depthDataType == kCVPixelFormatType_DepthFloat32 && back != nil
                notes.append("depth \(d.depthDataType) -> \(conv.depthDataType), calibration \(cal != nil), aux type \(t ?? "-")")
            } catch { notes.append("depth \(p8Err(error))") }
            do {
                let m = try AVPortraitEffectsMatte(fromDictionaryRepresentation: aux(kCVPixelFormatType_OneComponent8, 1, 200))
                notes.append("portrait \(CVPixelBufferGetWidth(m.mattingImage))x\(CVPixelBufferGetHeight(m.mattingImage))")
            } catch { notes.append("portrait \(p8Err(error))") }
            do {
                let sm = try AVSemanticSegmentationMatte(fromImageSourceAuxiliaryDataType: kCGImageAuxiliaryDataTypeSemanticSegmentationSkinMatte, dictionaryRepresentation: aux(kCVPixelFormatType_OneComponent8, 1, 100))
                notes.append("segmentation \(sm.matteType.rawValue)")
            } catch { notes.append("segmentation \(p8Err(error))") }
            // spatial video configuration, video performance metrics of a sample buffer renderer, Pro video storage
            var sv = AVSpatialVideoConfiguration(); sv.horizontalFieldOfView = 63500; sv.cameraSystemBaseline = 19240
            let ns = AVSpatialVideoConfiguration.nonSpatial
            try expect(sv.horizontalFieldOfView == 63500 && sv.cameraSystemBaseline == 19240 && ns.horizontalFieldOfView == nil, "spatial configuration \(ns)")
            let ren = AVSampleBufferVideoRenderer()
            let pm: AVVideoPerformanceMetrics? = await withCheckedContinuation { k in ren.loadVideoPerformanceMetrics { m in k.resume(returning: m) } }
            notes.append("perf \(pm.map { "\($0.totalNumberOfFrames) frames, \($0.numberOfDroppedFrames) dropped" } ?? "nil")")
            #if !os(visionOS)
            notes.append("pro storage supported \(AVProVideoStorage.isSupported) shared \(AVProVideoStorage.shared != nil)")
            #endif
            try expect(depthOK, "depth data: \(notes)")
            return notes.joined(separator: "; ")
        })
        #endif
        #if os(iOS)
        c.append(check("AVFoundation", "p28av-captions-itt-adaptors", timeout: 60) {
            // captions written to an iTT file through the caption adaptor, read back through the reader's caption adaptor
            let out = p28Tmp("caps.itt")
            let w = try AVAssetWriter(outputURL: out, fileType: .appleiTT)
            // passthrough to iTT needs a text format hint (an input without one raises NSInvalidArgumentException in addInput)
            var input: AVAssetWriterInput?, tried: [String] = []
            for sub in ["itt9", "text", "tx3g", "wvtt"] {
                var fd: CMFormatDescription?
                let st = CMFormatDescriptionCreate(allocator: nil, mediaType: kCMMediaType_Text, mediaSubType: p1FourCC(sub), extensions: nil, formatDescriptionOut: &fd)
                guard st == noErr, let fd else { tried.append("\(sub) \(st)"); continue }
                let i = AVAssetWriterInput(mediaType: .text, outputSettings: nil, sourceFormatHint: fd)
                var ok = false
                let ex = SDKCovCatch { if w.canAdd(i) { w.add(i); ok = true } }
                tried.append("\(sub) \(ex?.first ?? (ok ? "added" : "refused"))")
                if ok { input = i; break }
            }
            guard let input else { return "iTT: no text input accepted (\(tried))" }
            let cad = AVAssetWriterInputCaptionAdaptor(assetWriterInput: input)
            try expect(w.startWriting(), "iTT writer: \(String(describing: w.error))")
            w.startSession(atSourceTime: .zero)
            let caps = [AVCaption("first line", timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 1, timescale: 1))),
                        AVCaption("second line", timeRange: CMTimeRange(start: CMTime(value: 1, timescale: 1), duration: CMTime(value: 1, timescale: 1)))]
            var appended = 0
            for cap in caps { while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }; if cad.append(cap) { appended += 1 } }
            input.markAsFinished(); await w.finishWriting()
            try expect(w.status == .completed && appended == 2, "iTT write: status \(w.status.rawValue) appended \(appended) \(String(describing: w.error))")
            let asset = AVURLAsset(url: out)
            guard let t = try await asset.loadTracks(withMediaType: .text).first else { throw Fail("no text track in the iTT file") }
            let r = try AVAssetReader(asset: asset)
            let to = AVAssetReaderTrackOutput(track: t, outputSettings: nil)
            r.add(to)
            let rad = AVAssetReaderOutputCaptionAdaptor(assetReaderTrackOutput: to)
            try expect(r.startReading(), "reader \(String(describing: r.error))")
            var texts: [String] = []
            while let g = rad.nextCaptionGroup() { texts += rad.captionsNotPresentInPreviousGroups(in: g).map(\.text) }
            try expect(texts == ["first line", "second line"], "captions read back \(texts)")
            // a tagged pixel-buffer group adaptor on an MV-HEVC input
            let mvw = try AVAssetWriter(outputURL: p28Tmp("mv.mov"), fileType: .mov)
            let mvin = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.hevc, AVVideoWidthKey: 64, AVVideoHeightKey: 64])
            let tad = AVAssetWriterInputTaggedPixelBufferGroupAdaptor(assetWriterInput: mvin, sourcePixelBufferAttributes: nil)
            mvw.add(mvin)
            try expect(tad.assetWriterInput === mvin && tad.pixelBufferPool == nil, "tagged adaptor before writing")
            mvw.cancelWriting()
            return "iTT (\(tried.last ?? "-")): \(appended) captions written, read back \(texts)"
        })
        #endif
        #if os(iOS) || os(tvOS)
        c.append(check("AVFoundation", "p28av-capture-objects-sim", timeout: 30) {
            // the simulator has no cameras: discovery finds nothing, so the per-device objects (formats, frame-rate /
            // zoom / exposure-bias ranges, rotation coordinators, pressure states, system sliders, photos, synchronized
            // data, metadata objects, smart framing) are never handed out. Their classes are in the runtime with the
            // superclasses the SDK declares; the device-free objects are made and configured.
            let ds = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInTripleCamera, .builtInLiDARDepthCamera, .external, .continuityCamera],
                                                      mediaType: nil, position: .unspecified)
            try expect(ds.devices.isEmpty && AVCaptureDevice.default(for: .video) == nil, "capture devices on the simulator: \(ds.devices.map(\.localizedName))")
            let table: [(String, String)] = [
                ("AVCaptureDeviceDiscoverySession", "NSObject"), ("AVCaptureDeviceFormat", "NSObject"), ("AVCaptureDeviceInput", "AVCaptureInput"),
                ("AVCaptureInputPort", "NSObject"), ("AVFrameRateRange", "NSObject"), ("AVZoomRange", "NSObject"), ("AVExposureBiasRange", "NSObject"),
                ("AVCaptureDeviceRotationCoordinator", "NSObject"), ("AVCaptureSystemPressureState", "NSObject"), ("AVCaptureSystemZoomSlider", "AVCaptureControl"),
                ("AVCaptureSystemExposureBiasSlider", "AVCaptureControl"), ("AVCaptureReactionEffectState", "NSObject"), ("AVCaptureAudioChannel", "NSObject"),
                ("AVCapturePhoto", "NSObject"), ("AVCaptureResolvedPhotoSettings", "NSObject"), ("AVCameraCalibrationData", "NSObject"),
                ("AVMetadataObject", "NSObject"), ("AVMetadataFaceObject", "AVMetadataObject"), ("AVMetadataMachineReadableCodeObject", "AVMetadataObject"),
                ("AVMetadataBodyObject", "AVMetadataObject"), ("AVMetadataHumanBodyObject", "AVMetadataBodyObject"), ("AVMetadataHumanFullBodyObject", "AVMetadataBodyObject"),
                ("AVMetadataCatBodyObject", "AVMetadataBodyObject"), ("AVMetadataDogBodyObject", "AVMetadataBodyObject"), ("AVMetadataCatHeadObject", "AVMetadataObject"),
                ("AVMetadataDogHeadObject", "AVMetadataObject"), ("AVMetadataSalientObject", "AVMetadataObject"), ("AVMetadataFocusTrackedObject", "AVMetadataObject"),
                ("AVMetadataCinematicVideoMetadataObject", "AVMetadataObject"), ("AVExternalStorageDevice", "NSObject"), ("AVExternalSyncDevice", "NSObject"),
                ("AVCaptureTimecodeSource", "NSObject"), ("AVCaptureAncillaryDataEncoder", "NSObject"), ("AVCaptureExternalDisplayConfigurator", "NSObject"),
                ("AVCaptureBroadcastVideoOutput", "AVCaptureOutput"),
            ] + {
                #if os(iOS)
                return [("AVCaptureDeferredPhotoProxy", "AVCapturePhoto"), ("AVCaptureSynchronizedData", "NSObject"), ("AVCaptureSynchronizedDataCollection", "NSObject"),
                        ("AVCaptureSynchronizedSampleBufferData", "AVCaptureSynchronizedData"), ("AVCaptureSynchronizedDepthData", "AVCaptureSynchronizedData"),
                        ("AVCaptureSynchronizedMetadataObjectData", "AVCaptureSynchronizedData"), ("AVCaptureFraming", "NSObject"), ("AVCaptureSmartFramingMonitor", "NSObject"),
                        ("AVCaptureSpatialAudioMetadataSampleGenerator", "NSObject"), ("AVCaptureStillImageOutput", "AVCaptureOutput")]
                #else
                return [("AVContinuityDevice", "NSObject")]
                #endif
            }()
            var bad: [String] = []
            for (n, sup) in table {
                guard let cls = NSClassFromString(n) else { bad.append("\(n) missing"); continue }
                guard let sc = NSClassFromString(sup), cls.isSubclass(of: sc) else { bad.append("\(n) not a \(sup)"); continue }
            }
            try expect(bad.isEmpty, "capture classes: \(bad)")
            // the macOS-only capture / extension classes are declared unavailable here: Apple's simulator runtime answers
            let macOnly = ["AVCaptureAudioFileOutput", "AVCaptureAudioPreviewOutput", "AVCaptureScreenInput", "AVCaptureDeviceInputSource", "AVCaptureDeskViewApplication",
                           "AVCaptureDeskViewApplicationLaunchConfiguration", "AVMediaExtensionProperties", "AVAudioRoutingArbiter", "CAOpenGLLayer", "CARemoteLayerClient", "CARemoteLayerServer",
                           "CAConstraint", "CAConstraintLayoutManager", "RPBroadcastActivityController"]
            let present = macOnly.filter { NSClassFromString($0) != nil }
            // device-free objects
            let photo = AVCapturePhotoOutput()
            #if os(iOS)
            let rc = AVCapturePhotoOutputReadinessCoordinator(photoOutput: photo)
            try expect(rc.captureReadiness == .sessionNotRunning, "readiness \(rc.captureReadiness.rawValue)")
            let still = AVCaptureStillImageOutput()
            try expect(!still.isCapturingStillImage, "still image output")
            #endif
            let session = AVCaptureSession()
            let canPhoto = session.canAddOutput(photo)
            return "no devices; \(table.count) device-only classes present with their superclasses; macOS-only present in the runtime: \(present); photo output addable \(canPhoto)"
        })
        #endif
        #if os(iOS) || os(visionOS)
        c.append(check("AVFoundation", "p28av-asset-download-session", timeout: 90) {
            let hls = P28HLS(); try await hls.make()
            let srv = try More2HTTP { hls.respond($0) }; _ = try await srv.start()
            defer { srv.stop() }
            let asset = AVURLAsset(url: srv.url("/master.m3u8"))
            let variants = try await asset.load(.variants)
            let cfg = AVAssetDownloadConfiguration(asset: asset, title: "p28 download")
            let primary: AVAssetDownloadContentConfiguration = cfg.primaryContentConfiguration
            primary.variantQualifiers = [AVAssetVariantQualifier(variant: variants.min { ($0.peakBitRate ?? 0) < ($1.peakBitRate ?? 0) }!)]
            cfg.optimizesAuxiliaryContentConfigurations = false
            try expect(primary.variantQualifiers.count == 1, "content configuration: \(primary.variantQualifiers.count) qualifiers")
            let aux: [AVAssetDownloadContentConfiguration] = cfg.auxiliaryContentConfigurations
            let dl = P28Download()
            let sc = URLSessionConfiguration.background(withIdentifier: "com.x86sim.sdkcov.p28.\(UUID().uuidString)")
            let session = AVAssetDownloadURLSession(configuration: sc, assetDownloadDelegate: dl, delegateQueue: .main)
            let task: AVAssetDownloadTask = session.makeAssetDownloadTask(downloadConfiguration: cfg)
            try expect(task.urlAsset === asset || task.urlAsset.url == asset.url, "task asset")
            task.resume()
            let finished = await more2Wait(60) { dl.done.value != nil }
            // a deprecated aggregate task (media selections): made, then cancelled
            let sel = try await asset.load(.preferredMediaSelection)
            let agg: AVAggregateAssetDownloadTask? = session.aggregateAssetDownloadTask(with: asset, mediaSelections: [sel], assetTitle: "agg", assetArtworkData: nil, options: nil)
            agg?.cancel()
            session.finishTasksAndInvalidate()
            let sum = dl.metrics.value.compactMap { $0 as? AVMetricDownloadSummaryEvent }
            // the downloaded asset: its cache, playable offline
            var cacheNote = "no location"
            if let loc = dl.location.value {
                let local = AVURLAsset(url: loc)
                if let cache: AVAssetCache = local.assetCache {
                    let g = try await local.loadMediaSelectionGroup(for: .legible)
                    cacheNote = "cache offline \(cache.isPlayableOffline), \(g.map { cache.mediaSelectionOptions(in: $0).count } ?? -1) cached legible options"
                } else { cacheNote = "no asset cache at \(loc.lastPathComponent)" }
                let mgr = AVAssetDownloadStorageManager.shared()
                let pol = AVMutableAssetDownloadStorageManagementPolicy()
                pol.priority = .important; pol.expirationDate = Date(timeIntervalSinceNow: 3600)
                mgr.setStorageManagementPolicy(pol, for: loc)
                let back: AVAssetDownloadStorageManagementPolicy? = mgr.storageManagementPolicy(for: loc)
                cacheNote += "; policy \(back?.priority.rawValue ?? "nil")"
                try? FileManager.default.removeItem(at: loc)
            }
            return "\(aux.count) auxiliary configurations; finished \(finished): \(dl.done.value ?? "-"); events \(dl.events.value); \(dl.metrics.value.count) metric events (\(sum.count) summaries, \(sum.first?.bytesDownloadedCount ?? 0) B); aggregate \(agg != nil); \(cacheNote)"
        })
        #endif
        c += p28avFrameworks()
        c += p28avFrameworks2()
        c += p28avRest()
        return c
    }
}

// MARK: the other AV frameworks: CoreMIDI (UMP endpoints, function blocks, MIDI-CI), NowPlaying content and remote
// sessions, MusicUnderstanding results, MediaIntelligence assets, ImmersiveMediaSupport venues / masks / commands,
// CoreVideo attachment keys, AVFAudio read-only buffers and the sink node
#if canImport(CoreMIDI)
import CoreMIDI
#endif
#if canImport(NowPlaying)
import NowPlaying
#endif
#if canImport(ExtensionFoundation)
import ExtensionFoundation
#endif
#if canImport(MusicUnderstanding)
import MusicUnderstanding
#endif
#if canImport(MediaIntelligence)
import MediaIntelligence
#endif
#if canImport(ImmersiveMediaSupport)
import ImmersiveMediaSupport
import Metal
import Spatial
#endif

#if canImport(NowPlaying)
@MainActor final class P28NowPlayingRep: MediaSessionRepresentable {
    let id = "sdkcov-p28-session"
    var content: (any MediaContentRepresentable)? { TVShowContent(id: "p28-ep", episodeTitle: "Pilot", showName: "p28", duration: .finite(60), artwork: nil) }
    var playbackSnapshot: MediaPlaybackSnapshot? { MediaPlaybackSnapshot(state: .playing(rate: 1), elapsedTime: 1, timestamp: Date()) }
    var commands: [MediaCommand] { [.play {}, .pause {}] }
}
#endif
#if canImport(NowPlaying) && os(iOS)
/// a remote media session: its attributes, its representable (a radio stream on a TV), the extension that makes it
struct P28RemoteAttrs: RemoteMediaSessionAttributes { var id = "p28-attrs"; var station = "p28 radio" }
@MainActor final class P28RemoteRep: RemoteMediaSessionRepresentable {
    typealias Attributes = P28RemoteAttrs
    let id = "p28-remote"
    var station = ""
    var content: (any MediaContentRepresentable)? { RadioContent(id: "p28-radio", stationName: station, artwork: nil) }
    var playbackSnapshot: MediaPlaybackSnapshot? { MediaPlaybackSnapshot(state: .paused) }
    var commands: [MediaCommand] { [.togglePlayPause {}] }
    func update(_ a: P28RemoteAttrs) { station = a.station }
    var devices: [MediaDevice] { [MediaDevice(id: "p28-tv", name: "Living Room", type: .tv, capabilities: [.absoluteVolume(0.5) { _ in }])] }
}
struct P28RemoteExt: RemoteMediaSessionExtension {
    typealias Attributes = P28RemoteAttrs
    init() {}
    var configuration: RemoteMediaSessionExtensionConfiguration<P28RemoteExt> { RemoteMediaSessionExtensionConfiguration(extension: self) }
    func session(_ a: P28RemoteAttrs) async throws -> P28RemoteRep { let r = P28RemoteRep(); r.update(a); return r }
}
#endif

extension Registry {
    static func p28avFrameworks() -> [Check] {
        var c: [Check] = []
        #if canImport(CoreMIDI) && (os(iOS) || os(visionOS))
        c.append(check("CoreMIDI", "p28av-ump-endpoint-function-blocks", timeout: 30) {
            // a MIDI 2.0 UMP endpoint made by the app with two function blocks; the system caches it once enabled; MIDI-CI
            // devices, profiles and the 1.0 CI objects (responder, discovered nodes, profile states)
            let info = MIDI2DeviceInfo(manufacturerID: MIDI2DeviceManufacturer(sysExIDByte: (0x7D, 0, 0)), family: 1, modelNumber: 2,
                                       revisionLevel: MIDI2DeviceRevisionLevel(revisionLevel: (1, 0, 0, 0)))
            try expect(info.family == 1 && info.modelNumber == 2 && info.manufacturerID.sysExIDByte.0 == 0x7D, "device info")
            let got = Atomic<Int>(0)
            // virtual UMP endpoints need the audio background mode (sdkcov has none): nil, as on Apple's simulator
            guard let ep = MIDIUMPMutableEndpoint(name: "p28 UMP", deviceInfo: info, productInstanceID: "p28-1", midiProtocol: ._2_0, destinationCallback: { _, _ in got.add(1, ordering: .relaxed) }) else {
                let fb = MIDIUMPMutableFunctionBlock(name: "Keys", direction: .bidirectional, firstGroup: 0, totalGroupsSpanned: 1, maxSysEx8Streams: 0, midi1Info: .notMIDI1, uiHint: .senderReceiver, isEnabled: true)
                let ciDevs: [MIDICIDevice] = MIDICIDeviceManager.shared.discoveredCIDevices
                let profiles: [MIDIUMPCIProfile] = ciDevs.flatMap(\.profiles)
                let eps: [MIDIUMPEndpoint] = MIDIUMPEndpointManager.shared.umpEndpoints
                let ps = MIDICIProfileState(enabledProfiles: [MIDICIProfile(data: Data([0x7E, 0, 0, 1, 1]), name: "p28")], disabledProfiles: [])
                let blocks: [MIDIUMPFunctionBlock] = eps.flatMap(\.functionBlocks)
                // profile states made by both initializers (Apple's simulator answers no enabled profile from the 1.1 one)
                let ps0 = MIDICIProfileState(channel: 0, enabledProfiles: [MIDICIProfile(data: Data([0x7E, 0, 0, 1, 1]), name: "p28")], disabledProfiles: [])
                let states = "profile states \(ps.enabledProfiles.count)/\(ps0.enabledProfiles.count) channel \(ps0.midiChannel)"
                let conns: Set<MIDINetworkConnection> = MIDINetworkSession.default().connections()
                let r: MIDICIResponder? = nil, sess: MIDICISession? = nil, node: MIDICIDiscoveredNode? = nil
                _ = (r, sess, node)
                return "no virtual UMP endpoint (no audio background mode); function block \(fb != nil); \(states); \(eps.count) system endpoints (\(blocks.count) blocks), \(ciDevs.count) CI devices (\(profiles.count) profiles), \(conns.count) network connections"
            }
            guard let fb1 = MIDIUMPMutableFunctionBlock(name: "Keys", direction: .bidirectional, firstGroup: 0, totalGroupsSpanned: 1, maxSysEx8Streams: 0,
                                                        midi1Info: .notMIDI1, uiHint: .senderReceiver, isEnabled: true),
                  let fb2 = MIDIUMPMutableFunctionBlock(name: "Pads", direction: .output, firstGroup: 1, totalGroupsSpanned: 1, maxSysEx8Streams: 0,
                                                        midi1Info: .unrestrictedBandwidth, uiHint: .sender, isEnabled: true) else { throw Fail("no function blocks") }
            try ep.registerFunctionBlocks([fb1, fb2], markAsStatic: false)
            let base: MIDIUMPEndpoint = ep
            let fbs: [MIDIUMPFunctionBlock] = base.functionBlocks
            try expect(fbs.count == 2 && fbs[1].direction == .output && fb1.umpEndpoint === ep && ep.mutableFunctionBlocks.count == 2, "function blocks \(fbs.map(\.name))")
            try ep.setName("p28 UMP renamed")
            try fb2.reconfigure(firstGroup: 2, direction: .output, MIDI1Info: .restrictedBandwidth, UIHint: .sender)
            try ep.setEnabled(true)
            let mgr = MIDIUMPEndpointManager.shared
            let cached = await more2Wait(3) { mgr.umpEndpoints.contains { $0.name == "p28 UMP renamed" } }
            let ciMgr = MIDICIDeviceManager.shared
            let ciDevs: [MIDICIDevice] = ciMgr.discoveredCIDevices
            let profiles: [MIDIUMPCIProfile] = ciDevs.flatMap(\.profiles)
            try ep.setEnabled(false)
            // MIDI-CI 1.x objects: device info, a profile state, a responder (started / stopped), discovery
            let ciInfo = MIDICIDeviceInfo(destination: MIDIEntityRef(0), manufacturer: Data([0x7D, 0, 0]), family: Data([1, 0]), model: Data([2, 0]), revision: Data([1, 0, 0, 0]))
            let prof = MIDICIProfile(data: Data([0x7E, 0x00, 0x00, 0x01, 0x01]), name: "p28 profile")
            let ps = MIDICIProfileState(enabledProfiles: [prof], disabledProfiles: [])
            try expect(ciInfo.family == Data([1, 0]), "CI device info")
            let nodes = P1Box<[MIDICIDiscoveredNode]>([])
            MIDICIDiscoveryManager.sharedInstance().discover { n in nodes.value = n }
            _ = await more2Wait(2) { !nodes.value.isEmpty }
            let sessions = nodes.value.map { MIDICISession(discoveredNode: $0, dataReadyHandler: {}, disconnectHandler: { _, _ in }) }
            let responder: MIDICIResponder? = nil
            _ = responder
            let net = MIDINetworkSession.default()
            let conns: Set<MIDINetworkConnection> = net.connections()
            return "profile state \(ps.enabledProfiles.count); endpoint cached \(cached), \(fbs.count) blocks, \(ciDevs.count) CI devices (\(profiles.count) profiles), \(nodes.value.count) discovered nodes, \(sessions.count) sessions, \(conns.count) network connections"
        })
        #endif
        #if canImport(NowPlaying)
        c.append(check("NowPlaying", "p28av-content-types-artwork", timeout: 30) {
            try await p1Main { () async throws -> String in
                let cs = CGColorSpace(name: CGColorSpace.sRGB)!
                let ctx = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 32, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                ctx.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
                var repNote = "ok"
                var rep0: ArtworkRepresentation?
                do { rep0 = try ArtworkRepresentation(cgImage: ctx.makeImage()!) } catch { repNote = "\(error)" }
                let pngData = UIImage(cgImage: ctx.makeImage()!).pngData() ?? Data()
                if rep0 == nil { do { rep0 = try ArtworkRepresentation(data: pngData) } catch { repNote += ", png \(error)" } }
                let rep = rep0
                var emptyErr = "none"
                do { _ = try ArtworkRepresentation(data: Data()) } catch let e as ArtworkRepresentation.ArtworkRepresentationError { emptyErr = "\(e)" } catch { emptyErr = "other \(error)" }
                let art = Artwork(id: "p28-art") { _ in guard let rep else { throw ArtworkRepresentation.ArtworkRepresentationError.noRepresentationAvailable }; return rep }
                let anim = AnimatedArtwork(id: "p28-anim", supportedAspectRatios: [.square, .tall], preview: { _, _ in guard let rep else { throw ArtworkRepresentation.ArtworkRepresentationError.noRepresentationAvailable }; return rep }, video: { _, _ in URL(fileURLWithPath: "/dev/null") })
                var music = MusicContent(id: "m", songTitle: "Song", artistName: "Artist", albumName: "Album", type: .audio, duration: .finite(180), artwork: art, animatedArtwork: anim)
                music.composer = "Composer"; music.genre = "Jazz"
                let items: [any MediaContentRepresentable] = [
                    music,
                    PodcastContent(id: "p", episodeTitle: "Ep 1", showName: "Show", releaseDate: Date(timeIntervalSince1970: 0), type: .audio, duration: .finite(1200), artwork: nil),
                    RadioContent(id: "r", stationName: "Station", artwork: nil),
                    TVShowContent(id: "t", episodeTitle: "Pilot", showName: "Series", duration: .finite(2400), artwork: nil),
                    BookContent(id: "b", title: "Book", authorName: "Author", duration: .continuous, artwork: nil),
                    HomeMediaContent(id: "h", sourceName: "Camera", contentDescription: "Front door", type: .video, duration: .live, artwork: nil),
                ]
                let types: [MediaType] = items.map(\.type)
                let durs: [String] = items.map { d -> String in
                    let md: MediaDuration? = d.duration
                    switch md { case .finite(let s)?: return "\(Int(s))"; case .live?: return "live"; case .continuous?: return "continuous"; default: return "nil" }
                }
                try expect(types == [.audio, .audio, .audio, .video, .audio, .video] && durs == ["180", "1200", "live", "2400", "continuous", "live"], "types \(types) durations \(durs)")
                try expect(music.artwork?.id == "p28-art" && music.animatedArtwork?.supportedAspectRatios == [.square, .tall] && music.composer == "Composer", "music content")
                // a media session: becoming application primary (MediaSessionError if refused)
                let s = MediaSession(P28NowPlayingRep())
                var err = "none"
                do { try await s.requestToBecomeApplicationPrimary() } catch let e as MediaSessionError { err = "\(e)" } catch { err = "other \(error)" }
                var remote = ""
                #if os(iOS)
                // a remote media session: the extension makes the representable; starting one needs the system's remote
                // media service (RemoteMediaSessionError when it refuses)
                let ext = P28RemoteExt()
                let rr = try await ext.session(P28RemoteAttrs(station: "Jazz FM"))
                try expect((rr.content as? RadioContent)?.stationName == "Jazz FM" && rr.devices.first?.type == .tv && rr.devices[0].capabilities.count == 1, "remote representable")
                do { let rs = try await RemoteMediaSession<P28RemoteAttrs>.start(attributes: P28RemoteAttrs()); remote = "started \(rs.id)"; try await rs.end() }
                catch let e as RemoteMediaSessionError { remote = "start: \(e)" } catch { remote = "start: other \(error)" }
                #endif
                return "\(items.count) content types; artwork representation \(repNote); empty artwork data: \(emptyErr); session primary error \(err); \(remote)"
            }
        })
        #endif
        #if canImport(MusicUnderstanding)
        c.append(check("MusicUnderstanding", "p28av-key-pace-structure", timeout: 240) {
            let url = try p1ClickTrack(4)
            let s = try await MusicUnderstandingSession(asset: AVURLAsset(url: url))
            var empty = "no error"
            do { _ = try await s.analyze(for: []) } catch let e as MusicUnderstandingError { empty = "\(e)" }
            try expect(empty == "emptyAnalysisSet", "empty analysis set: \(empty)")
            let types: Set<AnalysisType> = [.key, .pace, .structure, .instrumentActivity, .loudness]
            let r = try await s.analyze(for: types)
            let key: KeyResult? = r.key, pace: PaceResult? = r.pace, st: StructureResult? = r.structure
            let inst: InstrumentActivityResult? = r.instrumentActivity, loud: LoudnessResult? = r.loudness
            let rhythm: RhythmResult? = r.rhythm
            try expect(loud != nil && rhythm == nil, "loudness \(loud != nil), rhythm not requested \(rhythm == nil)")
            let back = try JSONDecoder().decode(MusicUnderstandingSession.SessionResult.self, from: JSONEncoder().encode(r))
            try expect(back.loudness?.integrated.value == loud?.integrated.value, "session result Codable round trip")
            return "key \(key?.ranges.first.map { "\($0.value.tonic.rawValue) \($0.value.mode.rawValue)" } ?? "nil"), pace \(pace?.ranges.count ?? -1) ranges, structure \(st?.sections.count ?? -1) sections, instruments \(inst != nil), loudness \(loud.map { String(format: "%.1f", $0.integrated.value) } ?? "nil")"
        })
        #endif
        #if canImport(MediaIntelligence) && !os(watchOS)
        c.append(check("MediaIntelligence", "p28av-video-analyzer-assets", timeout: 120) {
            let mv = p28Tmp("mi.mov"); try await p1Movie(mv, frames: 30, size: 128)
            let va = MediaIntelligenceVideoAsset(id: .init("p28-video"), kind: .url(mv))
            let ia = MediaIntelligenceImageAsset(id: MediaIntelligenceImageAsset.ID(rawValue: "p28-image"), kind: .url(mv))
            try expect(va.id.rawValue == "p28-video" && ia.id.rawValue == "p28-image", "asset ids")
            var kf = "?"
            do {
                let r = try await VideoAnalyzer.shared.analyze(va, for: KeyFrameAnalysisRequest())
                switch r { case .success(let k): kf = "key frame at \(k.timestamp.seconds)"; case .failure(let e): kf = "failed \(e)" }
            } catch let e as MediaIntelligenceError { kf = "MediaIntelligenceError \(e)" } catch { kf = "threw \(p8Err(error))" }
            // a working directory that is a regular file
            let file = p28Tmp("mi-file"); try Data([1]).write(to: file)
            var wd = "made"
            do { _ = try FaceGroupAnalyzer(workingDirectory: file) } catch let e as MediaIntelligenceError { wd = "\(e) (\(e.errorDescription ?? "-"))" } catch { wd = "other \(p8Err(error))" }
            return "\(kf); analyzer on a file: \(wd)"
        })
        #endif
        #if canImport(ImmersiveMediaSupport) && (os(iOS) || os(visionOS))
        c.append(check("ImmersiveMediaSupport", "p28av-venue-cameras-masks", timeout: 60) {
            let dev = MTLCreateSystemDefaultDevice()
            let dyn = ImmersiveDynamicMask(name: "oval", stereoRelation: .mirror, edgeTreatment: .easeInOut, controlPointInterpolation: .cubicHermite,
                                           leftControlPoints: [Point3DFloat(x: 0, y: 1, z: 0), Point3DFloat(x: 1, y: 0, z: 0), Point3DFloat(x: 0, y: -1, z: 0)], rightControlPoints: [], edgeWidthInDegrees: 2)
            let mask: ImmersiveCameraMask = .dynamic(dyn)
            let img = ImmersiveImageMask(name: "img", maskData: Data([0, 1, 2]))
            let cal = ImmersiveCameraCalibration(name: "cal", type: .usdzMesh(ImmersiveCameraMeshCalibration(name: "mesh", usdzData: Data())), mask: mask)
            let cam = ImmersiveCamera(id: "cam-1", calibration: cal)
            let venue = VenueDescriptor(device: dev)
            var added = "added"
            do { try await venue.addCamera(cam) } catch { added = "addCamera: \(error)" }
            let cams = await venue.cameras
            let vm: ImmersiveCameraViewModel? = await venue.cameraViewModel(for: "cam-1")
            var coded = "?"
            var lens: ImmersiveCameraLensDefinition?
            do {
                let calBack = try JSONDecoder().decode(ImmersiveCameraCalibration.self, from: try JSONEncoder().encode(cal))
                coded = "round trip \(calBack.name)"
                // a lens definition only comes from authored data: absent from a calibration made of a mesh
                if case .immersiveCameraLensDefinition(let l) = calBack.type { lens = l }
            } catch { coded = "\(error)" }
            do { _ = try ImmersiveCameraLensDefinition(from: Data("{}".utf8)) } catch { coded += ", lens from {}: \(error)" }
            try expect(img.maskData == Data([0, 1, 2]), "image mask")
            // presentation commands: environment fade and shot flip
            let cmds: [PresentationCommand] = [.fadeEnvironment(FadeEnvironmentCommand(id: 1, time: .zero, duration: CMTime(value: 1, timescale: 1), direction: .out, opacity: 0.25)),
                                               .shotFlip(ShotFlipCommand(id: 2, time: CMTime(value: 1, timescale: 1), duration: CMTime(value: 1, timescale: 1)))]
            let rd = PresentationDescriptorReader(presentationDescriptor: PresentationDescriptor(duration: CMTime(value: 3, timescale: 1), commands: cmds))
            rd.processPresentationCommands(for: CMTime(value: 3, timescale: 2))
            let flipped = rd.isShotFlipped, envOp = rd.environmentFadeOpacity
            // a video mask on a Metal texture
            var vmask = "no Metal"
            if let dev, let tex = dev.makeTexture(descriptor: MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: 8, height: 8, mipmapped: false)) {
                let m = ImmersiveVideoMask(layout: .sideBySide, isInEquirectangularProjection: true, texture: tex)
                vmask = "mask \(m.layout) \(m.texture.width)"
            }
            // an ordinary movie: not AIVU, not parametric immersive
            let mv = p28Tmp("ims.mov"); try await p1Movie(mv, frames: 10, size: 64)
            var aivu = "?"
            do { aivu = "\(try await AIVUValidator.validate(url: mv))" } catch { aivu = "threw \(p8Err(error))" }
            let par = await ParametricImmersiveAssetInfo.isParametricImmersive(asset: AVURLAsset(url: mv))
            var info = "?"
            do { let pi = try await ParametricImmersiveAssetInfo(asset: AVURLAsset(url: mv)); info = "convertible \(pi.isAssetConvertible)" }
            catch let e as ParametricImmersiveAssetInfo.Error { info = "\(e.errorType)" } catch { info = "threw \(p8Err(error))" }
            try expect(!par, "a plain movie is parametric immersive")
            return "calibration \(coded); venue \(added): \(cams.count) cameras, view model \(vm?.cameraID ?? "nil"); lens \(lens != nil); flipped \(flipped), env opacity \(envOp); \(vmask); AIVU \(aivu); parametric info \(info)"
        })
        #endif
        c.append(check("CoreVideo", "p28av-attachment-key-definitions", timeout: 30) {
            // typed attachments on a mutable pixel buffer, read back through the generic key-definition protocols
            var mb = try CVMutablePixelBuffer(CVPixelBufferCreationAttributes(pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA), size: CVImageSize(width: 8, height: 8)))
            let fd: CVImageFieldDetail = .spatialFirstLineEarly, ycc: CVImageYCbCrMatrix = .itu_R_601_4, tf: CVImageTransferFunction = .itu_R_2100_HLG, am: CVImageAlphaChannelMode = .straightAlpha
            mb.attachments.fieldDetail = fd; mb.attachments.yCbCrMatrix = ycc; mb.attachments.transferFunction = tf; mb.attachments.alphaChannelMode = am
            func read<K: CVImageBufferAttachmentKeyDefinitions>(_ a: borrowing CVAttachmentAccess<K>) -> (CVImageFieldDetail?, CVImageYCbCrMatrix?, CVImageTransferFunction?, CVImageAlphaChannelMode?) {
                (a.fieldDetail, a.yCbCrMatrix, a.transferFunction, a.alphaChannelMode)
            }
            func keyCount<K: CVAttachmentKeyDefinitions>(_ a: borrowing CVAttachmentAccess<K>) -> Bool { a.attachedMode(of: kCVImageBufferFieldDetailKey as String) != nil }
            func raw<V: CVAttachmentValueRepresentable>(_ v: V) -> CVAttachmentRawValue { v.rawAttachmentValueRepresentation }
            func isBuffer<B: CVBufferRepresentable & ~Copyable>(_ b: borrowing B) -> Bool { b.withUnsafeBuffer { CFGetTypeID($0) == CVPixelBufferGetTypeID() } }
            let (f, y, t, a) = read(mb.attachments)
            try expect(f == fd && y == ycc && t == tf && a == am && keyCount(mb.attachments) && isBuffer(mb), "attachments \(String(describing: f)) \(String(describing: y)) \(String(describing: t)) \(String(describing: a))")
            let rv = raw(tf)
            try expect(CVImageTransferFunction.makeFromRawAttachmentValue(rv) == tf, "raw value round trip")
            return "4 typed attachments; transfer function raw \(rv)"
        })
        c.append(check("AVFAudio", "p28av-read-only-buffer-sink-node", timeout: 30) {
            // a read-only PCM buffer copied from a mutable one: format, frames, its float channel span
            let src = p1Tones([440], secs: 0.1)
            let ro = AVReadOnlyAudioPCMBuffer(copying: src)
            var first: Float = -9
            switch ro.channelData(0) { case .float(let sp): first = sp[100]; default: break }
            try expect(ro.frameLength == Int(src.frameLength) && ro.format == src.format && first == src.floatChannelData![0][100], "read-only buffer \(ro.frameLength) \(first)")
            let back = AVAudioPCMBuffer(copying: ro)
            try expect(back.frameLength == src.frameLength, "copy back")
            // the file API that takes and gives read-only buffers
            let u = p28Tmp("ro.caf")
            let f = try AVAudioFile(forWriting: u, settings: src.format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
            try f.write(from: ro)
            let rf = try AVAudioFile(forReading: u)
            let rb = try rf.read(frameCount: AVAudioFrameCount(rf.length))
            try expect(rb.frameLength == ro.frameLength, "file round trip \(rb.frameLength)")
            // a sink node pulling a player in a running engine
            let eng = AVAudioEngine(), player = AVAudioPlayerNode()
            let pulls = Atomic<Int>(0)
            let sink = AVAudioSinkNode { _, frames, _ in pulls.add(Int(frames), ordering: .relaxed); return noErr }
            eng.attach(player); eng.attach(sink)
            eng.connect(player, to: sink, format: src.format)
            _ = eng.outputNode
            var started = "started"
            let ex = SDKCovCatch { do { try eng.start() } catch { started = "start \(p8Err(error))" } }
            if let ex { started = "raised \(ex[0])" }
            // a player whose only output is a sink node is "disconnected": Apple's play() raises (caught here)
            var played = "not running"
            if eng.isRunning {
                player.scheduleBuffer(src, completionHandler: nil)
                played = "played"
                if let ex = SDKCovCatch({ player.play() }) { played = "play raised \(ex[1])" }
                _ = await more2Wait(1) { pulls.load(ordering: .relaxed) > 0 }
                eng.stop()
            }
            return "\(ro.frameLength) frames read-only; file round trip; sink engine \(started), \(played), \(pulls.load(ordering: .relaxed) > 0 ? "pulled" : "no") frames"
        })
        return c
    }
}

#if canImport(ShazamKit)
import ShazamKit
#endif
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(CoreHaptics)
import CoreHaptics
#endif
#if canImport(SoundAnalysis)
import SoundAnalysis
#endif
#if canImport(MediaPlayer)
import MediaPlayer
#endif
#if canImport(ReplayKit)
import ReplayKit
#endif
#if canImport(CoreAudioKit)
import CoreAudioKit
#endif
#if canImport(Speech)
import Speech
#endif
#if canImport(AVKit)
import AVKit
#endif
#if canImport(AudioToolbox)
import AudioToolbox
#endif
#if canImport(Observation)
import Observation
#endif

#if canImport(SoundAnalysis)
/// collects sound classification results
final class P28SoundObserver: NSObject, SNResultsObserving, @unchecked Sendable {
    let results = P1Box<[SNClassification]>([]), done = P1Box<Bool>(false)
    func request(_ r: SNRequest, didProduce res: SNResult) { if let c = res as? SNClassificationResult { results.mutate { $0 += c.classifications.prefix(3) } } }
    func requestDidComplete(_ r: SNRequest) { done.value = true }
}
#endif
#if canImport(Speech) && !os(watchOS)
/// a custom language-model data source and template
struct P28Phrases: DataInsertable { func insert(data: SFCustomLanguageModelData) { data.insert(phraseCount: .init(phrase: "play the x86sim playlist", count: 20)) } }
struct P28Template: TemplateInsertable { func insert(generator: SFCustomLanguageModelData.TemplatePhraseCountGenerator) { generator.insert(template: "play <name>", count: 5) } }
func p28ModuleLocales<M: LocaleDependentSpeechModule>(_ m: M) -> [Locale] { m.selectedLocales }
func p28ModuleFormats<M: SpeechModule>(_ m: M) async -> Int { await m.availableCompatibleAudioFormats.count }
func p28ResultRange<R: SpeechModuleResult>(_ r: R) -> CMTimeRange { r.range }
#endif
#if canImport(AVKit) && os(iOS)
/// a custom playback source for AVKit's playback user interface protocols
@MainActor final class P28Playback: Observable, AVPlaybackUserInterfaceControllable, AVPlaybackUserInterfaceVolumeControllable {
    var isReady = true, isPlaying = false, isBuffering = false, playbackSpeed: Float = 1, scanSpeed: Float = 0
    var state: AVPlaybackUserInterfacePlaybackState = .normal
    var supportedSeekCapabilities: AVPlaybackUserInterfaceSeekCapabilities = [.scanForward]
    var containsLiveStreamingContent = false
    var error: (any Error)? = nil
    var timeRange = CMTimeRange(start: .zero, duration: CMTime(value: 60, timescale: 1))
    var position = CMTime.zero
    var playbackPosition: AVPlaybackUserInterfacePlaybackPosition { AVPlaybackUserInterfacePlaybackPosition(position: position, hostTime: .zero, rate: isPlaying ? playbackSpeed : 0) }
    func seek(to p: CMTime, tolerance: CMTime) { position = p }
    var segments: [AVPlaybackUserInterfaceTimelineSegment] = [
        AVPlaybackUserInterfaceTimelineSegment(timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 10, timescale: 1)), segmentType: .advertisement, marked: true, requiresLinearPlayback: true, identifier: "ad"),
        AVPlaybackUserInterfaceTimelineSegment(timeRange: CMTimeRange(start: CMTime(value: 10, timescale: 1), duration: CMTime(value: 50, timescale: 1)), segmentType: .primary, marked: false, requiresLinearPlayback: false, identifier: "main")]
    var currentSegment: AVPlaybackUserInterfaceTimelineSegment { segments.first { $0.timeRange.containsTime(position) } ?? segments[1] }
    var seekableTimeRanges: [CMTimeRange]? { [timeRange] }
    var currentAudioOption: AVPlaybackUserInterfaceMediaSelectionOption?
    var currentAudioDescriptionOption: AVPlaybackUserInterfaceMediaSelectionOption?
    var currentLegibleOption: AVPlaybackUserInterfaceMediaSelectionOption?
    var audioOptions = [AVPlaybackUserInterfaceMediaSelectionOption(displayName: "English", identifier: "en", language: Locale.Language(identifier: "en"), mediaCharacteristics: [.audible])]
    var audioDescriptionOptions: [AVPlaybackUserInterfaceMediaSelectionOption] = []
    var legibleOptions = [AVPlaybackUserInterfaceMediaSelectionOption(displayName: "Deutsch", identifier: "de", language: Locale.Language(identifier: "de"), mediaCharacteristics: [.legible])]
    var metadata = AVPlaybackUserInterfaceContentMetadata(videoProperties: .init(presentationSize: CGSize(width: 1920, height: 1080)), title: "p28", subtitle: "custom source",
                                                          artworkRepresentations: [AVPlaybackUserInterfaceContentArtwork.artwork(url: URL(string: "https://example.com/a.png")!, contentType: .png, size: CGSize(width: 64, height: 64))])
    var hasAudio = true, isMuted = false, volume: Float = 1
}
#endif

extension Registry {
    static func p28avFrameworks2() -> [Check] {
        var c: [Check] = []
        #if canImport(ShazamKit)
        c.append(check("ShazamKit", "p28av-signature-catalog-match-objects", timeout: 90) {
            let song = p1Song(secs: 10)
            let g = SHSignatureGenerator(); try g.append(song, at: nil)
            let ref: SHSignature = g.signature()
            let back = try SHSignature(dataRepresentation: ref.dataRepresentation)
            try expect(abs(back.duration - ref.duration) < 0.01 && ref.duration > 8, "signature round trip \(ref.duration) -> \(back.duration)")
            // SHRange is refined for Swift (Range<TimeInterval>): the Objective-C object, then the item's Swift ranges
            let range = __SHRange(lowerBound: 0, upperBound: 10)
            try expect(NSStringFromClass(type(of: range)) == "SHRange" && range.upperBound == 10, "SHRange object")
            let item = SHMediaItem(properties: [.title: "p28 song", .timeRanges: [0.0..<10.0], .shazamID: "p28-1"])
            let cat = SHCustomCatalog()
            try cat.addReferenceSignature(ref, representing: [item])
            let base: SHCatalog = cat
            try expect(base.minimumQuerySignatureDuration > 0 && base.maximumQuerySignatureDuration >= base.minimumQuerySignatureDuration, "catalog query durations")
            let qb = AVAudioPCMBuffer(pcmFormat: song.format, frameCapacity: 5 * 48000)!; qb.frameLength = 5 * 48000
            memcpy(qb.floatChannelData![0], song.floatChannelData![0] + 3 * 48000, 5 * 48000 * 4)
            let qg = SHSignatureGenerator(); try qg.append(qb, at: nil)
            let r = await SHSession(catalog: cat).result(from: qg.signature())
            guard case .match(let m) = r else { throw Fail("no match: \(r)") }
            let match: SHMatch = m
            let mi: SHMatchedMediaItem? = match.mediaItems.first
            let ranges: [Range<TimeInterval>] = mi?.timeRanges ?? []
            try expect(mi?.title == "p28 song" && abs((mi?.matchOffset ?? -1) - 3) < 1 && ranges.first?.upperBound == 10 && match.querySignature.duration > 4, "match \(String(describing: mi?.title)) offset \(mi?.matchOffset ?? -1) ranges \(ranges.map(\.upperBound))")
            // the (deprecated) Shazam library: adding an item in the simulator
            var lib = "ok"
            do { try await SHMediaLibrary.default.add([item]) } catch { lib = p8Err(error) }
            return "matched at \(String(format: "%.2f", mi?.matchOffset ?? -1)) s (skew \(mi?.frequencySkew ?? 0)); library add \(lib)"
        })
        #endif
        #if canImport(PDFKit) && !os(watchOS)
        c.append(check("PDFKit", "p28av-actions-border-appearance", timeout: 30) {
            // a two-page PDF: link annotations carrying each action type, a widget with appearance characteristics and a
            // border; written out and read back; a text selection
            let data = NSMutableData()
            let attrs = [NSAttributedString.Key.font: CTFontCreateWithName("Helvetica" as CFString, 24, nil)] as [NSAttributedString.Key: Any]
            UIGraphicsBeginPDFContextToData(data, CGRect(x: 0, y: 0, width: 300, height: 300), nil)
            for t in ["first page hello", "second page world"] { UIGraphicsBeginPDFPage(); NSAttributedString(string: t, attributes: attrs).draw(at: CGPoint(x: 20, y: 40)) }
            UIGraphicsEndPDFContext()
            guard let doc = PDFDocument(data: data as Data), let p0 = doc.page(at: 0), let p1 = doc.page(at: 1) else { throw Fail("no PDF") }
            let acts: [PDFAction] = [
                PDFActionGoTo(destination: PDFDestination(page: p1, at: CGPoint(x: 0, y: 300))),
                PDFActionNamed(name: .nextPage),
                PDFActionRemoteGoTo(pageIndex: 2, at: CGPoint(x: 10, y: 20), fileURL: URL(fileURLWithPath: "/tmp/other.pdf")),
                { let r = PDFActionResetForm(); r.fields = ["name"]; r.fieldsIncludedAreCleared = true; return r }(),
                PDFActionURL(url: URL(string: "https://example.com/p28")!),
            ]
            for (i, a) in acts.enumerated() {
                let link = PDFAnnotation(bounds: CGRect(x: 10, y: 10 + 30 * i, width: 100, height: 20), forType: .link, withProperties: nil)
                link.action = a; p0.addAnnotation(link)
            }
            let w = PDFAnnotation(bounds: CGRect(x: 150, y: 150, width: 100, height: 30), forType: .widget, withProperties: nil)
            w.widgetFieldType = .button; w.widgetControlType = .checkBoxControl; w.fieldName = "agree"
            let ac = PDFAppearanceCharacteristics(); ac.controlType = .checkBoxControl; ac.caption = "Agree"; ac.rotation = 90
            ac.backgroundColor = .yellow; ac.borderColor = .red
            let b = PDFBorder(); b.style = .dashed; b.lineWidth = 2; b.dashPattern = [3, 1]
            w.border = b
            p0.addAnnotation(w)
            try expect(ac.appearanceCharacteristicsKeyValues.count >= 3 && b.borderKeyValues.count >= 2, "appearance \(ac.appearanceCharacteristicsKeyValues.keys) border \(b.borderKeyValues.keys)")
            guard let out = doc.dataRepresentation(), let doc2 = PDFDocument(data: out), let q0 = doc2.page(at: 0) else { throw Fail("PDF round trip") }
            let types = q0.annotations.compactMap { $0.action.map { NSStringFromClass(type(of: $0)) } }.sorted()
            let anyAct: PDFAction? = q0.annotations.first?.action
            let sel: PDFSelection? = doc2.findString("world", withOptions: .caseInsensitive).first
            try expect(sel?.string == "world" && sel?.pages.first == doc2.page(at: 1), "selection \(String(describing: sel?.string))")
            let wide = doc2.selection(from: doc2.page(at: 0)!, at: CGPoint(x: 0, y: 300), to: doc2.page(at: 1)!, at: CGPoint(x: 300, y: 0))
            return "\(acts.map(\.type)); after round trip \(types) (first \(anyAct?.type ?? "-")); selection '\(sel?.string ?? "-")', two-page selection \(wide?.string?.count ?? 0) chars"
        })
        #endif
        #if canImport(CoreHaptics) && !os(watchOS)
        c.append(check("CoreHaptics", "p28av-dynamic-parameters-curves", timeout: 30) {
            let pts = [CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: 0.2), CHHapticParameterCurve.ControlPoint(relativeTime: 0.5, value: 1)]
            let curve = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: pts, relativeTime: 0)
            let dyn = CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: 0.7, relativeTime: 0.1)
            try p28ObjC(pts[0], "CHHapticParameterCurveControlPoint")
            let ev = CHHapticEvent(eventType: .hapticContinuous, parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)], relativeTime: 0, duration: 1)
            let pat = try CHHapticPattern(events: [ev], parameterCurves: [curve])
            let pat2 = try CHHapticPattern(events: [ev], parameters: [dyn])
            try expect(curve.controlPoints.count == 2 && curve.controlPoints[1].value == 1 && dyn.value == 0.7 && pat.duration >= 1 && pat2.duration >= 1, "curve / dynamic parameter")
            // the simulator has no haptics engine (Apple: hardware capabilities report no haptics)
            let caps = CHHapticEngine.capabilitiesForHardware()
            var send = "no engine"
            if caps.supportsHaptics, let eng = try? CHHapticEngine() {
                try eng.start(); let pl = try eng.makeAdvancedPlayer(with: pat)
                do { try pl.sendParameters([dyn], atTime: CHHapticTimeImmediate); send = "sent" } catch { send = p8Err(error) }
                eng.stop()
            }
            return "curve 2 points, dynamic sharpness 0.7, haptics \(caps.supportsHaptics): \(send)"
        })
        #endif
        #if canImport(SoundAnalysis)
        c.append(check("SoundAnalysis", "p28av-classify-window-constraint", timeout: 120) {
            let req = try SNClassifySoundRequest(classifierIdentifier: .version1)
            let con: SNTimeDurationConstraint = req.windowDurationConstraint
            var kind = "?"
            switch con { case .enumeratedDurations(let d): kind = "enumerated \(d.map(\.seconds))"; case .durationRange(let r): kind = "range \(r.start.seconds)+\(r.duration.seconds)" }
            try expect(kind != "?", "window constraint")
            // a file of tones: classifications come back with identifiers and confidences
            let u = p28Tmp("sa.caf"); try p1WriteAudio(p1Tones([440, 880], secs: 3), u, [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1])
            let an = try SNAudioFileAnalyzer(url: u)
            let obs = P28SoundObserver()
            try an.add(req, withObserver: obs)
            await an.analyze()
            let cls: [SNClassification] = obs.results.value
            try expect(!cls.isEmpty && cls.allSatisfy { !$0.identifier.isEmpty && $0.confidence >= 0 && $0.confidence <= 1 }, "classifications \(cls.count)")
            return "window constraint \(kind); \(cls.count) classifications, top \(cls.first.map { "\($0.identifier) \(String(format: "%.2f", $0.confidence))" } ?? "-")"
        })
        #endif
        #if canImport(UIKit) && canImport(Metal) && !os(watchOS)
        c.append(check("QuartzCore", "p28av-renderer-metal-display-link", timeout: 30) {
            // CARenderer draws a layer tree into a Metal texture: a red layer over a blue background
            guard let dev = MTLCreateSystemDefaultDevice() else { throw Fail("no Metal device") }
            let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 32, height: 32, mipmapped: false)
            td.usage = [.renderTarget, .shaderRead]; td.storageMode = .shared
            let tex = dev.makeTexture(descriptor: td)!
            let root = CALayer(); root.frame = CGRect(x: 0, y: 0, width: 32, height: 32); root.backgroundColor = CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)
            let red = CALayer(); red.frame = CGRect(x: 0, y: 0, width: 16, height: 32); red.backgroundColor = CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
            root.addSublayer(red)
            // the renderer encodes on our queue; a command buffer committed after it on the same queue completes after its work
            guard let q = dev.makeCommandQueue() else { throw Fail("no command queue") }
            let r = CARenderer(mtlTexture: tex, options: [kCARendererMetalCommandQueue: q])
            r.layer = root; r.bounds = root.frame
            CATransaction.flush()
            r.beginFrame(atTime: CACurrentMediaTime(), timeStamp: nil); r.addUpdate(r.bounds); r.render(); r.endFrame()
            let fence = q.makeCommandBuffer()!; fence.commit(); fence.waitUntilCompleted()
            var px = [UInt8](repeating: 0, count: 32 * 32 * 4)
            tex.getBytes(&px, bytesPerRow: 128, from: MTLRegionMake2D(0, 0, 32, 32), mipmapLevel: 0)
            let left = Array(px[(16 * 32 + 4) * 4..<(16 * 32 + 4) * 4 + 3]), right = Array(px[(16 * 32 + 28) * 4..<(16 * 32 + 28) * 4 + 3])
            // a Metal display link on a layer that is not on screen: its updates (if any) carry drawables
            let ml = CAMetalLayer(); ml.device = dev; ml.drawableSize = CGSize(width: 16, height: 16)
            final class D: NSObject, CAMetalDisplayLinkDelegate, @unchecked Sendable {
                let n = Atomic<Int>(0)
                func metalDisplayLink(_ link: CAMetalDisplayLink, needsUpdate u: CAMetalDisplayLink.Update) { n.add(1, ordering: .relaxed); _ = u.drawable; _ = u.targetPresentationTimestamp }
            }
            let d = D()
            let link = CAMetalDisplayLink(metalLayer: ml); link.delegate = d
            link.add(to: .main, forMode: .common)
            _ = await more2Wait(1) { d.n.load(ordering: .relaxed) > 0 }
            link.invalidate()
            try expect(NSClassFromString("CAMetalDisplayLinkUpdate") != nil, "no CAMetalDisplayLinkUpdate class")
            let drawn = left[2] > 200 && left[0] < 50 && right[0] > 200 && right[2] < 50
            try expect(drawn, "rendered BGRA left \(left) right \(right)")
            return "CARenderer drawn \(drawn) left \(left) right \(right); display link updates offscreen \(d.n.load(ordering: .relaxed))"
        })
        #endif
        #if canImport(MediaPlayer) && os(iOS)
        c.append(check("MediaPlayer", "p28av-legacy-movie-player-picker", timeout: 40) {
            try await p1Main { () async throws -> String in
                let mv = p28Tmp("mp.mov"); try await p1Movie(mv, frames: 30, size: 64)
                let mpc = MPMoviePlayerController(contentURL: mv)!
                mpc.shouldAutoplay = false; mpc.prepareToPlay()
                _ = await p1WaitMain(5) { mpc.loadState.contains(.playable) }
                let alog: MPMovieAccessLog? = mpc.accessLog, elog: MPMovieErrorLog? = mpc.errorLog
                let aev: [MPMovieAccessLogEvent] = alog?.events as? [MPMovieAccessLogEvent] ?? []
                let eev: [MPMovieErrorLogEvent] = elog?.events as? [MPMovieErrorLogEvent] ?? []
                let tm: [MPTimedMetadata] = mpc.timedMetadata as? [MPTimedMetadata] ?? []
                let st = mpc.loadState.rawValue
                mpc.stop()
                let vc = MPMoviePlayerViewController(contentURL: mv)!
                try expect(vc.moviePlayer.contentURL == mv, "movie player view controller")
                let picker = MPMediaPickerController(mediaTypes: .music)
                picker.allowsPickingMultipleItems = true
                try expect(picker.mediaTypes == .music && picker.allowsPickingMultipleItems, "media picker")
                let pcm = MPPlayableContentManager.shared()
                let ctx: MPPlayableContentManagerContext = pcm.context
                let anim = MPMediaItemAnimatedArtwork(artworkID: "p28", previewImageRequestHandler: { _, h in h(nil) }, videoAssetFileURLRequestHandler: { _, h in h(nil) })
                return "movie load state \(st), \(aev.count) access / \(eev.count) error events, \(tm.count) timed metadata; content limits \(ctx.contentLimitsEnforced) endpoint \(ctx.endpointAvailable); animated artwork \(type(of: anim))"
            }
        })
        #endif
        #if canImport(ReplayKit) && (os(iOS) || os(tvOS))
        c.append(check("ReplayKit", "p28av-broadcast-objects", timeout: 30) {
            try await p1Main { () async throws -> String in
                let cfg = RPBroadcastConfiguration(); cfg.clipDuration = 5
                cfg.videoCompressionProperties = [AVVideoAverageBitRateKey: NSNumber(value: 1_000_000)]
                let arch = try NSKeyedArchiver.archivedData(withRootObject: cfg, requiringSecureCoding: true)
                let back = try NSKeyedUnarchiver.unarchivedObject(ofClass: RPBroadcastConfiguration.self, from: arch)
                try expect(back?.clipDuration == 5, "configuration round trip")
                let sh = RPBroadcastSampleHandler()
                let base: RPBroadcastHandler = sh
                base.updateServiceInfo(["k": "v" as NSString])
                let preview = RPPreviewViewController()
                let ctl = RPBroadcastController()
                try expect(!ctl.isBroadcasting && !ctl.isPaused, "broadcast controller idle")
                #if os(iOS)
                let clip = RPBroadcastMP4ClipHandler()
                _ = clip
                #endif
                return "configuration archived \(arch.count) B; sample handler \(type(of: base)); preview \(type(of: preview)); controller broadcasting \(ctl.isBroadcasting)"
            }
        })
        #endif
        #if canImport(CoreAudioKit) && os(iOS)
        c.append(check("CoreAudioKit", "p28av-au-view-controllers", timeout: 30) {
            try await p1Main { () async throws -> String in
                let cfg = AUAudioUnitViewConfiguration(width: 400, height: 300, hostHasController: true)
                try expect(cfg.width == 400 && cfg.height == 300 && cfg.hostHasController, "view configuration")
                let vc = AUViewController(); vc.view.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
                // the Swift classes AUGenericViewInternal / AUAppleCustomViewLoader: the SDK's .tbd lists Swift entry points
                // (e.g. customViewController(for:audioUnit:v3AU:)'s dispatch thunk) that the 27.2 runtime does not export, so
                // an app linking them directly does not launch (dyld "Symbol not found", Apple's simulator too); both are
                // reached through the Objective-C runtime
                guard let gvT = NSClassFromString("CoreAudioKit.AUGenericViewInternal") as? UIView.Type else { throw Fail("no AUGenericViewInternal class") }
                let gv = gvT.init(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
                let sw = CAInterAppAudioSwitcherView(frame: CGRect(x: 0, y: 0, width: 200, height: 40)); sw.isShowingAppNames = true
                let tv = CAInterAppAudioTransportView(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
                // Apple's delay unit: the custom view loader's answer for it
                let desc = AudioComponentDescription(componentType: kAudioUnitType_Effect, componentSubType: kAudioUnitSubType_Delay, componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
                let au = try AUAudioUnit(componentDescription: desc, options: [])
                var unit: AudioUnit?
                if let comp = AudioComponentFindNext(nil, [desc]) { AudioComponentInstanceNew(comp, &unit) }
                var custom = "no v2 unit"
                guard let ldT = NSClassFromString("CoreAudioKit.AUAppleCustomViewLoader") as? NSObject.Type else { throw Fail("no AUAppleCustomViewLoader class") }
                let loader = ldT.init()
                let sel = NSSelectorFromString("customViewControllerFor:audioUnit:v3AU:")
                if let unit, let m = class_getInstanceMethod(ldT, sel) {
                    typealias F = @convention(c) (AnyObject, Selector, AudioComponentDescription, AudioUnit, AUAudioUnit?) -> AnyObject?
                    let vc = unsafeBitCast(method_getImplementation(m), to: F.self)(loader, sel, desc, unit, au)
                    custom = vc.map { "\(type(of: $0))" } ?? "nil"
                } else if unit != nil { custom = "no customViewControllerFor:audioUnit:v3AU:" }
                if let unit { AudioComponentInstanceDispose(unit) }
                return "AUViewController \(vc.view.bounds.size), generic view \(gv.bounds.size), switcher names \(sw.isShowingAppNames), transport \(tv.isPlaying); custom view \(custom)"
            }
        })
        #endif
        #if canImport(Speech) && !os(watchOS)
        c.append(check("Speech", "p28av-modules-insertables-input", timeout: 60) {
            let data = SFCustomLanguageModelData(locale: Locale(identifier: "en_US"), identifier: "com.x86sim.p28", version: "1.0")
            P28Phrases().insert(data: data)
            let gen = SFCustomLanguageModelData.TemplatePhraseCountGenerator()
            gen.define(className: "name", values: ["jazz", "rock"])
            P28Template().insert(generator: gen)
            data.insert(phraseCountGenerator: gen)
            let out = p28Tmp("lm.bin")
            try await data.export(to: out)
            let size = (try? FileManager.default.attributesOfItem(atPath: out.path)[.size] as? Int) ?? 0
            try expect(size > 0, "exported custom language model data")
            #if !os(tvOS)
            let lmc = SFSpeechLanguageModel.Configuration(languageModel: p28Tmp("lm.out"))
            try p28ObjC(lmc, "SFSpeechLanguageModelConfiguration")
            #endif
            // speech modules through their protocols; a detector fed analyzer inputs
            let det = SpeechDetector(detectionOptions: .init(sensitivityLevel: .medium), reportResults: true)
            let tr = SpeechTranscriber(locale: Locale(identifier: "en-US"), preset: .transcription)
            let fmts = await p28ModuleFormats(det)
            let locs = p28ModuleLocales(tr)
            // the input in the modules' best format (the simulator answers an empty format: then 16 kHz Int16 mono)
            let tones = p1Tones([300], secs: 0.5)
            let best0 = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [det])
            let bestDesc = best0.map { "\($0.channelCount) ch \($0.sampleRate) Hz" } ?? "nil"
            let best = best0.flatMap { $0.channelCount > 0 ? $0 : nil } ?? AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
            guard let conv = AVAudioConverter(from: tones.format, to: best),
                  let inBuf = AVAudioPCMBuffer(pcmFormat: best, frameCapacity: AVAudioFrameCount(Double(tones.frameLength) * best.sampleRate / tones.format.sampleRate) + 16) else { throw Fail("no converter to \(best)") }
            var fed = false, cerr: NSError?
            conv.convert(to: inBuf, error: &cerr) { _, st in if fed { st.pointee = .endOfStream; return nil }; fed = true; st.pointee = .haveData; return tones }
            let input = AnalyzerInput(buffer: inBuf)
            let ranges = P1Box<[CMTimeRange]>([])
            let rt = Task { do { for try await r in det.results { ranges.mutate { $0.append(p28ResultRange(r)) } } } catch {} }
            // a detector alone is a fatal error in Speech ("Cannot create SpeechDetector-only worker"): pair it with the transcriber
            let an = SpeechAnalyzer(modules: [tr, det])
            var analyzed = "?"
            do {
                let end = try await more2Stage("analyze", 30) { try await an.analyzeSequence(AsyncStream { k in k.yield(input); k.finish() }) }
                try await an.finalizeAndFinishThroughEndOfInput()
                analyzed = "to \(end?.seconds ?? -1) s"
            } catch { analyzed = "\(error)" }
            rt.cancel()
            await SpeechModels.endRetention()
            return "LM data \(size) B; detector formats \(fmts), best \(bestDesc), transcriber locales \(locs.map(\.identifier)); analyzed \(analyzed), \(ranges.value.count) detector results"
        })
        #endif
        #if canImport(AVKit) && os(iOS)
        c.append(check("AVKit", "p28av-playback-ui-source-pip", timeout: 30) {
            try await p1Main { () async throws -> String in
                let src = P28Playback()
                let ctl: any AVPlaybackUserInterfaceControllable = src
                let vol: any AVPlaybackUserInterfaceVolumeControllable = src
                let tc: any AVPlaybackUserInterfaceTimeControllable = src, pc: any AVPlaybackUserInterfacePlaybackControllable = src
                let ms: any AVPlaybackUserInterfaceMediaSelectionControllable = src, mp: any AVPlaybackUserInterfaceMetadataProviding = src
                tc.seek(to: CMTime(value: 30, timescale: 1), tolerance: .zero); pc.isPlaying = true; vol.volume = 0.5
                ms.currentLegibleOption = ms.legibleOptions.first
                let pos: AVPlaybackUserInterfacePlaybackPosition = tc.playbackPosition
                let seg: AVPlaybackUserInterfaceTimelineSegment = tc.currentSegment
                let opt: AVPlaybackUserInterfaceMediaSelectionOption? = ms.currentLegibleOption
                let md = mp.metadata
                let art = md.artworkRepresentations.first as? AVPlaybackUserInterfaceContentURLArtwork
                try expect(pos.position.seconds == 30 && pos.rate == 1 && seg.identifier == "main" && opt?.identifier == "de" && vol.volume == 0.5 && ctl.isReady, "source state")
                try expect(md.videoProperties?.presentationSize.width == 1920 && art?.contentType == .png && art?.size.width == 64, "metadata")
                // the Objective-C classes behind the Swift value types
                let objc = ["AVPlaybackUserInterfaceContentMetadata", "AVPlaybackUserInterfaceContentMetadataTemplate", "AVPlaybackUserInterfaceContentVideoProperties", "AVPlaybackUserInterfaceContentArtwork"].filter { NSClassFromString($0) == nil }
                try expect(objc.isEmpty, "missing classes \(objc)")
                // a picture-in-picture content source over a sample-buffer display layer
                final class PB: NSObject, AVPictureInPictureSampleBufferPlaybackDelegate {
                    func pictureInPictureController(_ c: AVPictureInPictureController, setPlaying p: Bool) {}
                    func pictureInPictureControllerTimeRangeForPlayback(_ c: AVPictureInPictureController) -> CMTimeRange { CMTimeRange(start: .zero, duration: CMTime(value: 10, timescale: 1)) }
                    func pictureInPictureControllerIsPlaybackPaused(_ c: AVPictureInPictureController) -> Bool { true }
                    func pictureInPictureController(_ c: AVPictureInPictureController, didTransitionToRenderSize s: CMVideoDimensions) {}
                    func pictureInPictureController(_ c: AVPictureInPictureController, skipByInterval i: CMTime) async {}
                }
                let pb = PB()
                let cs = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: AVSampleBufferDisplayLayer(), playbackDelegate: pb)
                try p28ObjC(cs, "AVPictureInPictureControllerContentSource")
                let pip = AVPictureInPictureController(contentSource: cs)
                // the 27.1 direction coordinator (the app targets 27.0: reached through the runtime): no cameras, empty maps
                var dirs = "no AVCaptureDeviceDirectionCoordinator"
                if let cls = NSClassFromString("AVCaptureDeviceDirectionCoordinator") as? NSObject.Type {
                    typealias Init = @convention(c) (AnyObject, Selector, UIView, NSArray, AnyObject?) -> AnyObject
                    let sel = NSSelectorFromString("initWithView:deviceTypes:changeHandler:")
                    guard let m = class_getInstanceMethod(cls, sel) else { throw Fail("no initWithView:deviceTypes:changeHandler:") }
                    let obj = unsafeBitCast(method_getImplementation(m), to: Init.self)(cls.perform(NSSelectorFromString("alloc")).takeUnretainedValue(), sel,
                        UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100)), [AVCaptureDevice.DeviceType.builtInWideAngleCamera.rawValue] as NSArray, nil)
                    guard let map = (obj as? NSObject)?.value(forKey: "deviceDirections") as? NSObject else { throw Fail("no deviceDirections") }
                    try p28ObjC(map, "AVCaptureDeviceDirectionMap")
                    let fw = map.value(forKey: "forwardFacingDeviceDescriptors") as? [NSObject] ?? [], bw = map.value(forKey: "backwardFacingDeviceDescriptors") as? [NSObject] ?? []
                    try expect(fw.isEmpty && bw.isEmpty && NSClassFromString("AVCaptureDeviceDescriptor") != nil, "direction descriptors on the simulator \(fw.count + bw.count)")
                    dirs = "0 camera descriptors"
                }
                return "custom source at \(pos.position.seconds) s in '\(seg.identifier ?? "-")', legible \(opt?.displayName ?? "-"); PiP possible \(AVPictureInPictureController.isPictureInPictureSupported()) \(pip.isPictureInPicturePossible); \(dirs)"
            }
        })
        #endif
        #if canImport(VideoToolbox) && !os(watchOS)
        c.append(check("VideoToolbox", "p28av-frame-processor-configs-runtime", timeout: 30) {
            // the simulator SDK leaves the frame-processor configurations and parameters out of the headers
            // (VTFrameProcessor_*.h: !TARGET_OS_SIMULATOR); the classes are in the runtime, each configuration answers
            // +isSupported
            let names = ["VTFrameRateConversionConfiguration", "VTFrameRateConversionParameters", "VTLowLatencyFrameInterpolationConfiguration",
                         "VTLowLatencyFrameInterpolationParameters", "VTLowLatencySuperResolutionScalerConfiguration", "VTLowLatencySuperResolutionScalerParameters",
                         "VTMotionBlurConfiguration", "VTMotionBlurParameters", "VTOpticalFlowConfiguration", "VTOpticalFlowParameters",
                         "VTSuperResolutionScalerConfiguration", "VTSuperResolutionScalerParameters"]
            var present: [String] = [], supported: [String: Bool] = [:]
            for n in names {
                guard let cls = NSClassFromString(n) as? NSObject.Type else { continue }
                present.append(n)
                if n.hasSuffix("Configuration"), cls.responds(to: NSSelectorFromString("isSupported")) {
                    supported[n] = (cls.value(forKey: "supported") as? Bool) ?? false
                }
            }
            return "\(present.count)/\(names.count) classes in the runtime; supported \(supported.sorted { $0.key < $1.key }.map { "\($0.key.replacingOccurrences(of: "Configuration", with: "")) \($0.value)" })"
        })
        #endif
        #if canImport(AudioToolbox) && !os(watchOS)
        c.append(check("AudioToolbox", "p28av-au-parameter-values", timeout: 30) {
            let p: AUParameter = AUParameterTree.createParameter(withIdentifier: "cutoff", name: "Cutoff", address: 7, min: 20, max: 20000, unit: .hertz, unitName: nil,
                                                                  flags: [.flag_IsReadable, .flag_IsWritable, .flag_DisplayLogarithmic], valueStrings: nil, dependentParameters: nil)
            let tree = AUParameterTree.createTree(withChildren: [p])
            p.value = 440
            let s = p.string(fromValue: nil)
            // a parameter without value strings parses no string: Apple answers 0
            let v = p.value(from: "1000")
            let seen = P1Box<[AUValue]>([])
            let tok = p.token(byAddingParameterObserver: { _, val in seen.mutate { $0.append(val) } })
            p.setValue(880, originator: nil)
            _ = await more2Wait(1) { !seen.value.isEmpty }
            p.removeParameterObserver(tok)
            try expect(tree.parameter(withAddress: 7)?.value == 880 && p.unit == .hertz && p.minValue == 20 && v == 0, "parameter value \(p.value) string \(s) parsed \(v)")
            return "value \(p.value), string '\(s)', observed \(seen.value)"
        })
        #endif
        return c
    }
}

// MARK: the rest: HLS audio renditions, sample-buffer output configurations, the playback assistant, rendered
// captions, fragmented movies, timecode / storage / sync / external display capture objects; tvOS's content proposal,
// continuity picker and display manager; visionOS viewports, group experience coordinator and spatial audio experiences
#if os(iOS)
final class P28Rendered: NSObject, AVPlayerItemRenderedLegibleOutputPushDelegate, @unchecked Sendable {
    let images = P1Box<[String]>([])
    func renderedLegibleOutput(_ o: AVPlayerItemRenderedLegibleOutput, didOutputRenderedCaptionImages imgs: [AVRenderedCaptionImage], forItemTime t: CMTime) {
        images.mutate { $0 += imgs.map { "\(CVPixelBufferGetWidth($0.pixelBuffer))x\(CVPixelBufferGetHeight($0.pixelBuffer))@\(Int($0.position.x)),\(Int($0.position.y))" } }
    }
}
#endif

extension Registry {
    static func p28avRest() -> [Check] {
        var c: [Check] = []
        #if !os(watchOS)
        c.append(check("AVFoundation", "p28av-audio-rendition-assistant-sample-output", timeout: 90) {
            // a multivariant playlist with a stereo English audio rendition: the variant's audio attributes per option
            let master = "#EXTM3U\n#EXT-X-VERSION:7\n#EXT-X-INDEPENDENT-SEGMENTS\n" +
                "#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=\"aud\",NAME=\"English\",LANGUAGE=\"en\",DEFAULT=YES,AUTOSELECT=YES,CHANNELS=\"2\",URI=\"audio.m3u8\"\n" +
                "#EXT-X-STREAM-INF:BANDWIDTH=300000,RESOLUTION=128x128,CODECS=\"avc1.64000a,mp4a.40.2\",AUDIO=\"aud\"\nvideo.m3u8\n"
            // media playlists: P1HLS's segments (video only: the variant's attributes come from the multivariant playlist)
            let h = P1HLS(); try await h.make()
            let srv = try More2HTTP { r in
                let path = r.path.split(separator: "?").first.map(String.init) ?? r.path
                switch path {
                case "/master.m3u8": return .text(master, type: "application/vnd.apple.mpegurl")
                case "/video.m3u8", "/audio.m3u8": return .text(h.video, type: "application/vnd.apple.mpegurl")
                default: return h.respond(More2Req(method: r.method, path: path, headers: r.headers, body: r.body))
                }
            }
            _ = try await srv.start(); defer { srv.stop() }
            let asset = AVURLAsset(url: srv.url("/master.m3u8"))
            let variants = try await more2Stage("variants", 20) { try await asset.load(.variants) }
            let audGroup = try await more2Stage("audible group", 20) { try await asset.loadMediaSelectionGroup(for: .audible) }
            guard let aud = audGroup, let en = aud.options.first else { throw Fail("no audible group") }
            guard let aa = variants.first?.audioAttributes else { throw Fail("no audio attributes") }
            try p28ObjC(aa, "AVAssetVariantAudioAttributes")
            let rs = aa.renditionSpecificAttributes(for: en)
            try p28ObjC(rs, "AVAssetVariantAudioRenditionSpecificAttributes")
            try expect(rs?.channelCount == 2 && rs?.isBinaural == false, "rendition channels \(String(describing: rs?.channelCount))")
            // the playback assistant of a local movie with audio
            let mv = p28Tmp("assist.mov"); try await p1Movie(mv, frames: 30, size: 64, audio: true)
            let local = AVURLAsset(url: mv)
            let pa = AVAssetPlaybackAssistant(asset: local)
            let opts = try await more2Stage("playback assistant", 20) { await pa.playbackConfigurationOptions }
            // a sample-buffer output asking for 16-bit integer PCM, attached to a playing item
            let cfg = AVPlayerItemSampleBufferOutputAudioConfiguration()
            var asbd = AudioStreamBasicDescription(mSampleRate: 44100, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
                                                   mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
            var fd: CMAudioFormatDescription?
            CMAudioFormatDescriptionCreate(allocator: nil, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &fd)
            cfg.requestedAudioFormat = fd
            let base: AVPlayerItemSampleBufferOutputConfiguration = cfg
            let out = AVPlayerItemSampleBufferOutput(configuration: base)
            let item = AVPlayerItem(asset: local); item.add(out)
            let player = AVPlayer(playerItem: item); player.isMuted = true
            _ = await more2Wait(10) { item.status == .readyToPlay }
            player.play(); _ = await more2Wait(5) { player.currentTime().seconds > 0.5 }; player.pause()
            try expect(cfg.requestedAudioFormat != nil && item.outputs.contains { $0 === out }, "sample buffer output attached")
            return "rendition \(rs?.channelCount ?? -1) ch; assistant options \(opts.map(\.rawValue)); sample output with Int16 request attached"
        })
        #endif
        #if os(iOS)
        c.append(check("AVFoundation", "p28av-rendered-legible-output", timeout: 90) {
            let hls = P28HLS(); try await hls.make()
            let srv = try More2HTTP { hls.respond($0) }; _ = try await srv.start(); defer { srv.stop() }
            let item = AVPlayerItem(url: srv.url("/master.m3u8"))
            let ro = AVPlayerItemRenderedLegibleOutput(videoDisplay: CGSize(width: 640, height: 360))
            let d = P28Rendered(); ro.setDelegate(d, queue: .main)
            item.add(ro)
            let player = AVPlayer(playerItem: item); player.isMuted = true
            _ = await more2Wait(20) { item.status != .unknown }
            if let g = try await item.asset.loadMediaSelectionGroup(for: .legible), let en = g.options.first { item.select(en, in: g) }
            player.play()
            _ = await more2Wait(6) { !d.images.value.isEmpty }
            player.pause()
            try expect(ro.videoDisplaySize == CGSize(width: 640, height: 360), "display size")
            return "rendered caption images \(d.images.value.prefix(3))"
        })
        #endif
        #if os(iOS) || os(visionOS)
        c.append(check("AVFoundation", "p28av-fragmented-movie-minder", timeout: 60) {
            // a movie written with fragments every 0.5 s: read as a fragmented movie, its track, a minder over it
            let out = p28Tmp("frag.mov")
            let w = try AVAssetWriter(outputURL: out, fileType: .mov)
            w.movieFragmentInterval = CMTime(value: 1, timescale: 2)
            let vin = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64])
            let ad = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vin, sourcePixelBufferAttributes: nil)
            w.add(vin); try expect(w.startWriting(), "writer"); w.startSession(atSourceTime: .zero)
            for i in 0..<45 {
                while !vin.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
                _ = ad.append(p1Solid(64, 64, [0, 128, 255]), withPresentationTime: CMTime(value: CMTimeValue(i), timescale: 30))
            }
            vin.markAsFinished(); await w.finishWriting()
            try expect(w.status == .completed, "fragmented writer \(String(describing: w.error))")
            let fm = AVFragmentedMovie(url: out, options: nil)
            let tracks: [AVFragmentedMovieTrack] = try await fm.load(.tracks)
            let minder = AVFragmentedMovieMinder(movie: fm, mindingInterval: 1)
            let contains = fm.containsMovieFragments
            let loaded = try await fm.load(.containsFragments), can = try await fm.load(.canContainFragments)
            try expect(tracks.count == 1 && minder.movies.count == 1, "tracks \(tracks.count), minder \(minder.movies.count)")
            minder.remove(fm)
            return "\(tracks.count) fragmented track, fragments \(contains) loaded \(loaded) can \(can), minder interval \(minder.mindingInterval)"
        })
        #endif
        #if os(iOS) || os(tvOS)
        c.append(check("AVFoundation", "p28av-timecode-storage-sync-display", timeout: 30) {
            let tg = AVCaptureTimecodeGenerator()
            let src: [AVCaptureTimecode.Source] = tg.availableSources
            tg.timecodeFrameDuration = CMTime(value: 1, timescale: 30)
            let fc = AVCaptureTimecodeGenerator.frameCountSource
            let first = tg.generateInitialTimecode()
            let storage = AVExternalStorageDeviceDiscoverySession.isSupported
            let devs = AVExternalStorageDeviceDiscoverySession.shared?.externalStorageDevices.count ?? -1
            let sync = AVExternalSyncDevice.DiscoverySession.isSupported
            // AVExternalSyncDeviceDiscoverySession: its singleton raises where sync devices are unsupported ("use -isSupported")
            let syncSession = sync ? AVExternalSyncDevice.DiscoverySession.shared : nil
            try expect(NSClassFromString("AVExternalSyncDeviceDiscoverySession") == AVExternalSyncDevice.DiscoverySession.self && (!sync || syncSession != nil), "sync session \(String(describing: syncSession)) supported \(sync)")
            let edc = AVCaptureExternalDisplayConfiguration(); edc.shouldMatchFrameRate = true; edc.bypassColorSpaceConversion = false
            try expect(edc.shouldMatchFrameRate && tg.timecodeFrameDuration == CMTime(value: 1, timescale: 30), "configuration read back")
            try p28ObjC(fc, "AVCaptureTimecodeSource")
            return "timecode sources \(src.map(\.displayName)), frame-count source \(fc.displayName), initial \(first.hours):\(first.minutes):\(first.seconds):\(first.frames); storage supported \(storage) (\(devs) devices); sync supported \(sync); display matching \(AVCaptureExternalDisplayConfigurator.isMatchingFrameRateSupported)"
        })
        #endif
        #if os(visionOS)
        c.append(check("AVKit", "p28av-vision-viewport-spatial-audio-preview", timeout: 30) {
            try await p1Main { () async throws -> String in
                // a portal viewport on a player view controller
                let pvc = AVPlayerViewController()
                let vp: AVViewport = pvc.viewport
                let portal = AVPortalViewport(); portal.aspectRatio = 2.39
                vp.portal = portal
                try expect(vp.portal?.aspectRatio == 2.39, "portal aspect ratio \(String(describing: vp.portal?.aspectRatio))")
                try expect(NSClassFromString("AVGroupExperienceCoordinator") != nil, "no AVGroupExperienceCoordinator class")
                let gec: AVGroupExperienceCoordinator? = nil
                _ = gec
                // the audio session's spatial experience, and an output node's (AudioToolbox's experience types)
                let ses = AVAudioSession.sharedInstance()
                let want: any AVAudioSessionSpatialExperience = AVAudioSession.FixedSpatialExperience.fixed(soundStageSize: .small)
                var set = "set"
                do { try ses.setIntendedSpatialExperience(want) } catch { set = p8Err(error) }
                let got = ses.intendedSpatialExperience
                let eng = AVAudioEngine()
                let auto: AutomaticSpatialAudio = .automatic, byp: BypassedSpatialAudio = .bypassed
                let size: SpatialAudioExperiences.SoundStageSize = .large
                eng.outputNode.intendedSpatialExperience = FixedSpatialAudio.fixed(soundStageSize: size)
                let nodeExp = eng.outputNode.intendedSpatialExperience
                eng.outputNode.intendedSpatialExperience = byp
                _ = auto
                // remote preview pieces of ImmersiveMediaSupport: the framer definition, a renderer, a receiver
                let def = ImmersiveMediaPreviewMessagingProtocol.definition
                let ren = ImmersivePreviewRenderer(device: MTLCreateSystemDefaultDevice())
                var recv = "made"
                do { let r = try await ImmersiveMediaRemotePreviewReceiver(); recv = "made, frame \(r.frame != nil)"; r.stop() } catch { recv = "\(error)" }
                return "portal 2.39; session spatial \(set) -> \(type(of: got)); output node \(type(of: nodeExp)); framer \(type(of: def)), renderer venue \(ren.venueDescriptor != nil), receiver \(recv)"
            }
        })
        #endif
        #if os(tvOS)
        c.append(check("AVKit", "p28av-tv-proposal-picker-display", timeout: 30) {
            try await p1Main { () async throws -> String in
                let pvc = AVPlayerViewController()
                let prop = AVContentProposalViewController()
                pvc.contentProposalViewController = prop
                try expect(pvc.contentProposalViewController === prop && prop.contentProposal == nil, "content proposal view controller")
                let picker = AVContinuityDevicePickerViewController()
                let sup = AVContinuityDevicePickerViewController.isSupported
                let win = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.windows.first }.first ?? UIWindow()
                let dm: AVDisplayManager = win.avDisplayManager
                let dev: AVContinuityDevice? = nil
                _ = dev
                return "proposal \(type(of: prop)), continuity picker supported \(sup) \(type(of: picker)); display criteria matching \(dm.isDisplayCriteriaMatchingEnabled), switching \(dm.isDisplayModeSwitchInProgress)"
            }
        })
        #endif
        return c
    }
}
