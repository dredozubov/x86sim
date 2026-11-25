// SDK coverage, round 26: checks for [a] gaps (COVERAGE-GAPS.md). Each asserts what Apple's simulator answers
// (ref-mac.sh).
import Foundation
import Synchronization
import CoreMedia
#if canImport(AVFoundation)
import AVFoundation
#endif
#if os(iOS) || os(visionOS) || os(tvOS)
import UIKit
#endif
#if canImport(CryptoTokenKit)
import CryptoTokenKit
#endif
#if canImport(CoreImage) && !os(watchOS)
import CoreImage
#endif
#if canImport(ImmersiveMediaSupport) && (os(iOS) || os(visionOS))
import ImmersiveMediaSupport
#endif
#if canImport(BackgroundAssets) && (os(iOS) || os(visionOS))
import BackgroundAssets

/// BADownloadManager's delegate: what happened to each download
final class P22BADelegate: NSObject, BADownloadManagerDelegate, @unchecked Sendable {
    let ev = Mutex<[String]>([]), file = Mutex<String?>(nil)
    func downloadDidBegin(_ d: BADownload) { ev.withLock { $0.append("begin") } }
    func download(_ d: BADownload, didWriteBytes w: Int64, totalBytesWritten t: Int64, totalBytesExpectedToWrite e: Int64) {
        ev.withLock { if !$0.contains("progress") { $0.append("progress") } }
    }
    /// the loopback server's certificate (More2TLS, a test CA) accepted
    func download(_ d: BADownload, didReceive ch: URLAuthenticationChallenge, completionHandler done: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        ev.withLock { $0.append("challenge \(ch.protectionSpace.authenticationMethod.replacingOccurrences(of: "NSURLAuthenticationMethod", with: ""))") }
        if let t = ch.protectionSpace.serverTrust { done(.useCredential, URLCredential(trust: t)) } else { done(.performDefaultHandling, nil) }
    }
    func download(_ d: BADownload, failedWithError e: Error) { ev.withLock { $0.append("failed \(p8Err(e))") } }
    func download(_ d: BADownload, finishedWithFileURL u: URL) {
        let s = (try? String(contentsOf: u, encoding: .utf8)) ?? "unreadable"
        file.withLock { $0 = s }
        ev.withLock { $0.append("finished") }
    }
}
#endif

/// sdkcov's bundled movies (res/sdkcovMovies.swift, run on a phone by res/sdkcovRes.sh; build.sh copies res/*.mov into the bundle): sdkcovChapters.mov
/// (p21ChapterMovie's chapters "Opening" / "Middle" / "Credits") and sdkcovStall.mov (p21AVMovie's 6 s video + AAC)
func p22Movie(_ name: String) throws -> URL {
    guard let u = Bundle.main.url(forResource: name, withExtension: "mov") else { throw Fail("\(name).mov not in the bundle") }
    return u
}

/// the [start, end) byte range of the top-level atom `type` in a QuickTime file
func p22Atom(_ d: Data, _ type: String) -> (Int, Int)? {
    var off = 0
    while off + 8 <= d.count {
        var size = Int(d[off]) << 24 | Int(d[off + 1]) << 16 | Int(d[off + 2]) << 8 | Int(d[off + 3])
        if size == 1, off + 16 <= d.count { size = d[off + 8 ..< off + 16].reduce(0) { $0 << 8 | Int($1) } }
        if String(decoding: d[off + 4 ..< off + 8], as: UTF8.self) == type { return (off, off + size) }
        if size < 8 { break }; off += size
    }
    return nil
}

#if os(visionOS)
import SwiftUI
import CompositorServices
import _CompositorServices_SwiftUI
import Metal

/// the immersive space "sdkcov-compositor-config" (Harness.swift): a CompositorLayer whose configuration asks for a
/// depth buffer, foveation when supported and the layered layout; the first frames' drawables described
enum P22Compositor {
    static let caps = Mutex("no configuration asked"), frames = SDKCovFlag(), ended = SDKCovFlag(), state = Mutex("not started")
    struct Config: CompositorLayerConfiguration {
        func makeConfiguration(capabilities c: LayerRenderer.Capabilities, configuration cfg: inout LayerRenderer.Configuration) {
            let fov = c.supportsFoveation
            let layouts = c.supportedLayouts(options: fov ? [.foveationEnabled] : [])
            caps.withLock { $0 = "foveation \(fov), layouts \(layouts.map { "\($0)" }), depth formats \(c.supportedDepthFormats.map(\.rawValue)), near \(c.supportedMinimumNearPlaneDistance)" }
            cfg.depthFormat = .depth32Float
            cfg.colorFormat = .bgra8Unorm_srgb
            cfg.isFoveationEnabled = fov
            cfg.layout = layouts.contains(.layered) ? .layered : (layouts.first ?? .dedicated)
        }
    }
    @MainActor static func space() -> some ImmersiveSpaceContent {
        CompositorLayer(configuration: Config()) { lr in
            let t = Thread { loop(lr) }; t.name = "sdkcov compositor config"; t.start()
        }
    }
    static func loop(_ lr: LayerRenderer) {
        lr.waitUntilRunning()
        guard let q = lr.device.makeCommandQueue() else { state.withLock { $0 = "no command queue" }; return }
        var n = 0, info = ""
        while true {
            switch lr.state {
            case .invalidated: ended.set("invalidated after \(n) frames"); return
            case .paused: lr.waitUntilRunning(); continue
            default: break
            }
            guard let f = lr.queryNextFrame() else { continue }
            f.startUpdate(); f.endUpdate()
            if let t = f.predictTiming() { LayerRenderer.Clock().wait(until: t.optimalInputTime) }
            f.startSubmission()
            guard let d = f.queryDrawable() else { continue }
            let cb = q.makeCommandBuffer()!
            let rp = MTLRenderPassDescriptor(), ct = d.colorTextures[0]
            rp.colorAttachments[0].texture = ct; rp.colorAttachments[0].loadAction = .clear; rp.colorAttachments[0].storeAction = .store
            if let dt = d.depthTextures.first { rp.depthAttachment.texture = dt; rp.depthAttachment.loadAction = .clear; rp.depthAttachment.clearDepth = 0; rp.depthAttachment.storeAction = .store }
            if ct.textureType == .type2DArray { rp.renderTargetArrayLength = ct.arrayLength }
            rp.rasterizationRateMap = d.rasterizationRateMaps.first
            cb.makeRenderCommandEncoder(descriptor: rp)?.endEncoding()
            if n == 0 {
                let c = lr.configuration, dt = d.depthTextures.first
                let vs = d.views.enumerated().map { i, v in "slice \(v.textureMap.sliceIndex) \(Int(v.textureMap.viewport.width))x\(Int(v.textureMap.viewport.height))" }
                info = "config layout \(c.layout) foveation \(c.isFoveationEnabled) depth \(c.depthFormat.rawValue); color \(ct.pixelFormat.rawValue) type \(ct.textureType.rawValue) x\(ct.arrayLength); depth texture \(dt.map { "\($0.pixelFormat.rawValue) type \($0.textureType.rawValue) x\($0.arrayLength)" } ?? "none"); \(d.views.count) views \(vs); \(d.rasterizationRateMaps.count) rate maps; projection 0 finite \(d.computeProjection(viewIndex: 0).columns.0.x.isFinite)"
            }
            d.encodePresent(commandBuffer: cb); cb.commit(); f.endSubmission()
            n += 1
            if n == 10 { cb.waitUntilCompleted(); frames.set(info) }
        }
    }
}
#endif

#if canImport(AVKit) && (os(iOS) || os(visionOS))
import AVKit
/// AVPlayerViewController's full-screen delegate calls, with the transitions' completions
final class P22PVCDelegate: NSObject, AVPlayerViewControllerDelegate, @unchecked Sendable {
    let ev = Mutex<[String]>([])
    func note(_ s: String) { ev.withLock { $0.append(s) } }
    func playerViewController(_ p: AVPlayerViewController, willBeginFullScreenPresentationWithAnimationCoordinator c: UIViewControllerTransitionCoordinator) {
        note("willBegin"); c.animate(alongsideTransition: nil) { ctx in self.note(ctx.isCancelled ? "beginCancelled" : "didBegin") }
    }
    func playerViewController(_ p: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator c: UIViewControllerTransitionCoordinator) {
        note("willEnd"); c.animate(alongsideTransition: nil) { ctx in self.note(ctx.isCancelled ? "endCancelled" : "didEnd") }
    }
}
#endif

#if os(iOS) || os(visionOS) || os(tvOS)
/// an NSUserActivity delegate noting UIKit's save of the scene's activity
final class P22ActivityDelegate: NSObject, NSUserActivityDelegate, @unchecked Sendable {
    let saves = Atomic<Int>(0)
    func userActivityWillSave(_ a: NSUserActivity) { saves.add(1, ordering: .relaxed) }
}
/// a mark from the app (ext/Marks.swift's format), read by the companion app sdkcovDoc
func p22Mark(_ name: String, _ text: String) {
    guard let g = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: p3Group) else { return }
    let dir = g.appendingPathComponent("p3marks", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let f = dir.appendingPathComponent(name)
    let line = Data("\(Date().timeIntervalSince1970) \(text)\n".utf8)
    if let h = try? FileHandle(forWritingTo: f) { _ = try? h.seekToEnd(); try? h.write(contentsOf: line); try? h.close() } else { try? line.write(to: f) }
}
#endif

extension Registry {
    static var p22: [Check] {
        var c: [Check] = []

        // MARK: AVFoundation: QuickTime chapters read from a bundled movie (watchOS has no AVAssetWriter: the iOS check
        // P21 chapters-text-track writes its own; run on iOS and watchOS)
        #if canImport(AVFoundation) && (os(iOS) || os(watchOS))
        c.append(check("AVFoundation", "chapters-bundled-movie", timeout: 60) {
            let asset = AVURLAsset(url: try p22Movie("sdkcovChapters"))
            let text = try await asset.loadTracks(withMediaType: .text)
            let locales = try await asset.load(.availableChapterLocales)
            let groups = try await asset.loadChapterMetadataGroups(bestMatchingPreferredLanguages: ["en", "und"])
            var ch: [String] = []
            for g in groups {
                let title = try await AVMetadataItem.metadataItems(from: g.items, filteredByIdentifier: .commonIdentifierTitle).first?.load(.stringValue)
                ch.append("\(String(format: "%.0f", g.timeRange.start.seconds))+\(String(format: "%.0f", g.timeRange.duration.seconds)):\(title ?? "nil")")
            }
            try expect(ch == ["0+1:Opening", "1+1:Middle", "2+1:Credits"], "\(text.count) text tracks, locales \(locales.map(\.identifier)), chapters \(ch)")
            return "\(text.count) text track, locales \(locales.map(\.identifier)), chapters \(ch)"
        })

        // MARK: AVFoundation: AVPlayerItem playback stalled over HTTP: a loopback server (More2HTTP) answers byte ranges
        // of a bundled movie but holds back everything past a third of its media data (the rest of the chunked body
        // would come 10 minutes later) (watchOS has no AVAssetResourceLoader: P21 player-stalled-notification uses one)
        #if canImport(Network)
        c.append(check("AVFoundation", "player-stalled-http-loopback", timeout: 90) {
            let d = try Data(contentsOf: try p22Movie("sdkcovStall"))
            guard let mdat = p22Atom(d, "mdat") else { throw Fail("no mdat in sdkcovStall.mov") }
            let cutoff = mdat.0 + (mdat.1 - mdat.0) / 3
            let held = Atomic<Int>(0)
            let srv = try More2HTTP { req in
                var a = 0, b = d.count - 1
                let ranged = req.headers["range"].map { r -> Bool in
                    let p = r.replacingOccurrences(of: "bytes=", with: "").split(separator: "-", omittingEmptySubsequences: false)
                    if let x = Int(p.first ?? "") { a = x }
                    if p.count > 1, let y = Int(p[1]) { b = min(y, d.count - 1) }
                    return true
                } ?? false
                var r = More2Resp(ranged ? "206 Partial Content" : "200 OK", [("Content-Type", "video/quicktime"), ("Accept-Ranges", "bytes")])
                if ranged { r.headers.append(("Content-Range", "bytes \(a)-\(b)/\(d.count)")) }
                let body = d.subdata(in: a ..< b + 1)
                if a < mdat.1 && b + 1 > cutoff {
                    // the held-back media data: what is before the cutoff now (at least one byte: chunk 0 goes at
                    // once, an empty one would end the body), the rest 10 minutes later
                    let now = max(1, cutoff - a)
                    r.chunks = [Data(body.prefix(now)), Data(body.dropFirst(now))].filter { !$0.isEmpty }
                    r.gap = 600
                    held.add(1, ordering: .relaxed)
                } else { r.body = body }
                return r
            }
            let port = try await srv.start()
            defer { srv.stop() }
            let item = AVPlayerItem(url: srv.url("/stall.mov"))
            let notes = Mutex<[String]>([])
            let nc = NotificationCenter.default
            var obs: [NSObjectProtocol] = []
            for (n, tag) in [(AVPlayerItem.playbackStalledNotification, "stalled"), (AVPlayerItem.failedToPlayToEndTimeNotification, "failedToPlayToEnd"),
                             (AVPlayerItem.didPlayToEndTimeNotification, "playedToEnd")] {
                obs.append(nc.addObserver(forName: n, object: item, queue: nil) { _ in notes.withLock { if !$0.contains(tag) { $0.append(tag) } } })
            }
            defer { obs.forEach { nc.removeObserver($0) } }
            let p = AVPlayer(playerItem: item)
            p.isMuted = true
            p.automaticallyWaitsToMinimizeStalling = false
            p.play()
            let end = Date().addingTimeInterval(40)
            while Date() < end && notes.withLock({ $0.isEmpty }) { try await Task.sleep(for: .milliseconds(200)) }
            try await Task.sleep(for: .seconds(1))
            let t = p.currentTime().seconds, st = item.status.rawValue, err = p8Err(item.error)
            p.pause(); p.replaceCurrentItem(with: nil)
            let n = notes.withLock { $0 }
            let detail = "notifications \(n); played to \(String(format: "%.1f", t)) s of 6, item status \(st), error \(err); port \(port), \(srv.requests.withLock { $0.count }) requests, \(held.load(ordering: .relaxed)) held back"
            try expect(n.contains("stalled") && !n.contains("playedToEnd"), detail)
            return detail
        })
        #endif
        #endif

        // MARK: BackgroundAssets: a BAURLDownload (HTTPS only: an http: URL raises) from a loopback TLS server in the app (More2HTTP, the
        // delegate accepts its test certificate), started in the
        // foreground (BADownloadManager.startForegroundDownload): the manager's delegate sees it begin and finish and
        // reads the file it hands over
        #if canImport(BackgroundAssets) && (os(iOS) || os(visionOS))
        c.append(check("BackgroundAssets", "foreground-download-loopback", timeout: 90) {
            let body = String(repeating: "sdkcov background asset\n", count: 400)
            let srv = try More2HTTP(tls: true) { req in req.path == "/asset.txt" ? More2Resp.text(body) : More2Resp("404 Not Found") }
            _ = try await srv.start()
            defer { srv.stop() }
            let m = BADownloadManager.shared
            let d = P22BADelegate()
            m.delegate = d
            defer { m.delegate = nil }
            let dl = BAURLDownload(identifier: "sdkcov-p22-\(Int(Date().timeIntervalSince1970))", request: URLRequest(url: srv.url("/asset.txt", tls: true)), essential: false,
                                   fileSize: body.utf8.count, applicationGroupIdentifier: "group.com.x86sim.test.sdkcov", priority: .default)
            var started = "started"
            do { try m.startForegroundDownload(dl) } catch { started = "start: \(p8Err(error))" }
            _ = await more2Wait(60) { d.ev.withLock { $0.contains("finished") || $0.contains { $0.hasPrefix("failed") } } }
            let ev = d.ev.withLock { $0 }, f = d.file.withLock { $0 }
            let r = "\(started); delegate \(ev); file \(f.map { "\($0.utf8.count) B" } ?? "none"); server \(srv.requests.withLock { $0 })"
            // Apple: begin, the server trust challenge, progress, finished, in that order
            try expect(started == "started" && ev == ["begin", "challenge ServerTrust", "progress", "finished"] && f == body, r)
            return r
        })
        #endif

        // MARK: CoreImage: kernels from a compiled Metal library (res/sdkcovCI.metal, stitchable, built per platform with the
        // Metal Toolchain: sdkcovCI.metallib in the bundle): a color kernel swapping red and blue, a warp kernel
        // sampling 10 px to the right, read back by pixels
        #if canImport(CoreImage) && !os(watchOS)
        c.append(check("CoreImage", "cikernel-metal-library", timeout: 60) {
            guard let u = Bundle.main.url(forResource: "sdkcovCI", withExtension: "metallib") else { throw Fail("sdkcovCI.metallib not in the bundle") }
            let lib = try Data(contentsOf: u)
            let names = CIKernel.kernelNames(fromMetalLibraryData: lib)
            let swap = try CIColorKernel(functionName: "sdkcovSwapRB", fromMetalLibraryData: lib)
            let shift = try CIWarpKernel(functionName: "sdkcovShift", fromMetalLibraryData: lib)
            let ctx = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
            func px(_ img: CIImage, _ x: Int, _ y: Int) -> [UInt8] {
                var p = [UInt8](repeating: 0, count: 4)
                ctx.render(img, toBitmap: &p, rowBytes: 4, bounds: CGRect(x: x, y: y, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
                return p
            }
            let r = CGRect(x: 0, y: 0, width: 40, height: 20)
            let red = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: CGRect(x: 0, y: 0, width: 20, height: 20))
            let green = CIImage(color: CIColor(red: 0, green: 1, blue: 0)).cropped(to: CGRect(x: 20, y: 0, width: 20, height: 20))
            let src = green.composited(over: red)
            guard let swapped = swap.apply(extent: r, arguments: [src]),
                  let moved = shift.apply(extent: r, roiCallback: { _, rr in rr.offsetBy(dx: 10, dy: 0) }, image: src, arguments: []) else { throw Fail("apply gave nil") }
            let a = px(swapped, 5, 10), b = px(swapped, 30, 10), m1 = px(moved, 5, 10), m2 = px(moved, 12, 10)
            let d = "kernels \(names.sorted()); swapped red \(a) green \(b); shifted x5 \(m1) x12 \(m2)"
            try expect(names.contains("sdkcovSwapRB") && names.contains("sdkcovShift"), d)
            try expect(a == [0, 0, 255, 255] && b == [0, 255, 0, 255], d)
            try expect(m1 == [255, 0, 0, 255] && m2 == [0, 255, 0, 255], d)
            return d
        })
        #endif

        // MARK: ImmersiveMediaSupport: a VenueDescriptor (an Apple Immersive venue, .aime) with a stereo camera whose
        // calibration is a USDZ mesh: added, saved, read back, removed
        #if canImport(ImmersiveMediaSupport) && (os(iOS) || os(visionOS))
        c.append(check("ImmersiveMediaSupport", "venue-descriptor-cameras", timeout: 60) {
            func e(_ x: Error) -> String { "\(type(of: x)) \(x)".prefix(160).description }
            var out: [String] = []
            let v = VenueDescriptor()
            let cal = ImmersiveCameraCalibration(name: "sdkcov-cal", type: .usdzMesh(ImmersiveCameraMeshCalibration(name: "sdkcov-mesh", usdzData: Data("sdkcov".utf8))))
            let cam = ImmersiveCamera(id: "sdkcov-cam", calibration: cal, presentationFrameRate: 90)
            do { try await v.addCamera(cam); out.append("added: \(await v.cameras.map(\.id))") } catch { out.append("add: \(e(error))") }
            out.append("view model \(await v.cameraViewModel(for: "sdkcov-cam") != nil)")
            let u = p1Tmp("venue.aime")
            try? FileManager.default.removeItem(at: u)
            do { try await v.save(to: u); out.append("saved \((try? Data(contentsOf: u).count) ?? -1) B") } catch { out.append("save: \(e(error))") }
            do { let b = try await VenueDescriptor(aimeURL: u); out.append("read back \(await b.cameras.map { "\($0.id) \($0.presentationFrameRate) fps" })") } catch { out.append("read: \(e(error))") }
            do { try await v.removeCamera(id: "sdkcov-cam"); out.append("removed: \(await v.cameras.count) left") } catch { out.append("remove: \(e(error))") }
            do { try await v.removeCamera(id: "nope"); out.append("removed unknown") } catch { out.append("remove unknown: \(e(error))") }
            let r = out.joined(separator: "; ")
            // Apple: the junk USDZ makes addCamera throw invalidData, yet the camera is kept: saved, read back, removed
            try expect(out.count == 6 && out[0] == "add: VenueDescriptorErrors invalidData" && out[1] == "view model false" && out[2].hasPrefix("saved ")
                       && out[3] == "read back [\"sdkcov-cam 90 fps\"]" && out[4] == "removed: 0 left" && out[5] == "remove unknown: VenueDescriptorErrors invalidParameters", r)
            return r
        })
        #endif

        // MARK: CryptoTokenKit: a persistent token (the app's token extension, ext/Token.swift) configured from the app
        // (TKTokenDriver.Configuration) with a certificate: TKTokenWatcher sees the token, the keychain lists the
        // certificate under its token id (TKTokenKeychainContents), and removing the configuration takes both away
        #if canImport(CryptoTokenKit)
        c.append(check("CryptoTokenKit", "persistent-token-keychain", timeout: 90) {
            let cls = "com.x86sim.test.sdkcov.token", inst = "sdkcov-p22", tid = "\(cls):\(inst)"
            let t0 = Date()
            var dcs: [String: TKTokenDriver.Configuration] = [:]
            for _ in 0..<20 { dcs = TKTokenDriver.Configuration.driverConfigurations; if dcs[cls] != nil { break }; try await Task.sleep(for: .milliseconds(500)) }
            #if os(tvOS) || os(watchOS)
            // Apple's tvOS / watchOS simulators: the bundled ctk-tokens extension gives the app no driver configuration
            // (installd takes the appex; CryptoTokenKit lists no class for it)
            try expect(dcs.isEmpty, "driver configurations \(dcs.keys.sorted())")
            return "no driver configuration for the bundled token extension"
            #else
            guard let dc = dcs[cls] else { throw Fail("driver configurations \(dcs.keys.sorted())") }
            dc.removeTokenConfiguration(for: inst)
            let tc = dc.addTokenConfiguration(for: inst)
            guard let cert = SecCertificateCreateWithData(nil, More2TLS.leafDER as CFData),
                  let item = TKTokenKeychainCertificate(certificate: cert, objectID: "sdkcov-cert") else { throw Fail("certificate item") }
            item.label = "sdkcov token cert"
            // a signing key next to it (the certificate's public key): a signature through it goes to the extension's
            // token session (which supports no operation)
            guard let key = TKTokenKeychainKey(certificate: cert, objectID: "sdkcov-key") else { throw Fail("key item") }
            key.label = "sdkcov token key"; key.canSign = true; key.isSuitableForLogin = false
            tc.keychainItems = [item, key]
            tc.configurationData = Data("sdkcov".utf8)
            let w = TKTokenWatcher()
            let seen = await more2Wait(20) { w.tokenIDs.contains(tid) }
            func certs() -> (OSStatus, [String]) {
                var out: CFTypeRef?
                let st = SecItemCopyMatching([kSecClass as String: kSecClassCertificate, kSecAttrTokenID as String: tid, kSecReturnAttributes as String: true,
                                              kSecMatchLimit as String: kSecMatchLimitAll] as CFDictionary, &out)
                return (st, ((out as? [[String: Any]]) ?? []).map { "\($0[kSecAttrLabel as String] ?? "-")" })
            }
            var kc = certs()
            for _ in 0..<20 where kc.0 != errSecSuccess { try await Task.sleep(for: .milliseconds(500)); kc = certs() }
            let info = w.tokenInfo(forTokenID: tid)
            var kref: CFTypeRef?
            let kst = SecItemCopyMatching([kSecClass as String: kSecClassKey, kSecAttrTokenID as String: tid, kSecReturnRef as String: true] as CFDictionary, &kref)
            var sign = "no key"
            if kst == errSecSuccess, let k = kref, CFGetTypeID(k) == SecKeyGetTypeID() {
                var e: Unmanaged<CFError>?
                let sig = SecKeyCreateSignature(k as! SecKey, .ecdsaSignatureMessageX962SHA256, Data("sdkcov".utf8) as CFData, &e)
                sign = sig != nil ? "signed" : "error \(p8Err(e?.takeRetainedValue()))"
            }
            dc.removeTokenConfiguration(for: inst)
            let gone = await more2Wait(20) { !w.tokenIDs.contains(tid) }
            let after = certs()
            let d = "configs \(dc.tokenConfigurations.keys.sorted()); watcher \(seen) (driver \(info?.driverName ?? "-")); keychain \(kc.0) \(kc.1); key \(kst), sign: \(sign); removed: watcher gone \(gone), keychain \(after.0) \(after.1); extension \(p3Marks("token-create", since: t0)) sessions \(p3Marks("token-session", since: t0).count)"
            try expect(seen && kc.0 == errSecSuccess && kc.1 == ["sdkcov token cert"], d)
            try expect(gone && after.0 == errSecItemNotFound, d)
            // the key's reference needs the extension's token: Apple's simulator never gets one from it (-26276, the
            // extension not launched; no session)
            try expect(kst == -26276, d)
            return d
            #endif
        })
        #endif

        // MARK: CompositorServices: a configured LayerRenderer (depth, foveation if supported, layered layout) in an
        // immersive space: capabilities, the drawables' color / depth textures, views and rasterization rate maps
        #if os(visionOS)
        c.append(check("CompositorServices", "layer-configuration-drawables", timeout: 90) {
            try skipIf(!sdkcovMultiScene, "the app declares one scene")
            let a = try await sdkcovSceneActions()
            let r = await a.openImmersiveSpace(id: "sdkcov-compositor-config")
            guard case .opened = r else { throw Fail("openImmersiveSpace: \(r)") }
            let got = await P22Compositor.frames.wait(seconds: 30)
            await a.dismissImmersiveSpace()
            let ended = await P22Compositor.ended.wait(seconds: 15)
            let caps = P22Compositor.caps.withLock { $0 }
            guard let got else { throw Fail("no frames (\(P22Compositor.state.withLock { $0 })); capabilities \(caps)") }
            let d = "capabilities \(caps); \(got); after dismiss \(ended ?? "not invalidated")"
            try expect(ended != nil, d)
            // Apple's simulator: no foveation, layouts dedicated / shared / layered, depth32Float or depth32Float_stencil8;
            // one view in a single-slice 2D array (its size is the device type's screen: 4K / 1080p)
            for k in ["foveation false, layouts [\"cp_layer_renderer_layout(rawValue: 0)\", \"cp_layer_renderer_layout(rawValue: 1)\", \"cp_layer_renderer_layout(rawValue: 2)\"], depth formats [252, 260]",
                      "config layout cp_layer_renderer_layout(rawValue: 2) foveation false depth 252; color 81 type 3 x1; depth texture 252 type 3 x1; 1 views [\"slice 0 ",
                      "0 rate maps; projection 0 finite true"] {
                try expect(d.contains(k), "missing '\(k)': \(d)")
            }
            return d
        })
        #endif

        // MARK: AVKit: full screen entered and left by playback (entersFullScreenWhenPlaybackBegins /
        // exitsFullScreenWhenPlaybackEnds) of an inline AVPlayerViewController playing the bundled 6 s movie: the delegate's
        // will-begin / will-end calls and their transitions' completions
        #if canImport(AVKit) && (os(iOS) || os(visionOS))
        c.append(check("AVKit", "fullscreen-enter-exit-delegate", timeout: 60) {
            let u = try p22Movie("sdkcovStall")
            let d = P22PVCDelegate()
            let (pvc, hide, player) = try await onMain { () throws -> (AVPlayerViewController, () -> Void, AVPlayer) in
                let host = UIViewController(), pvc = AVPlayerViewController(), player = AVPlayer(url: u)
                player.isMuted = true
                pvc.player = player; pvc.delegate = d
                pvc.entersFullScreenWhenPlaybackBegins = true; pvc.exitsFullScreenWhenPlaybackEnds = true
                host.addChild(pvc); host.view.addSubview(pvc.view); pvc.view.frame = CGRect(x: 20, y: 80, width: 320, height: 180); pvc.didMove(toParent: host)
                let (_, hide) = try p6Show(host)
                return (pvc, hide, player)
            }
            defer { Task { @MainActor in player.pause(); hide() } }
            try await Task.sleep(for: .seconds(1))
            await onMain { player.play() }
            let begun = await more2Wait(8) { d.ev.withLock { $0.contains("didBegin") } }
            let full = await onMain { pvc.presentedViewController.map { "\(type(of: $0))" } ?? "none" }
            _ = await more2Wait(20) { d.ev.withLock { $0.contains("didEnd") } }
            try await Task.sleep(for: .milliseconds(500))
            let ev = d.ev.withLock { $0 }, t = await onMain { player.currentTime().seconds }
            let r = "delegate \(ev); begun \(begun), presented \(full); played to \(String(format: "%.1f", t)) s"
            // Apple's simulators (iOS, visionOS): playback started by the app (player.play()) never takes the controller
            // full screen (entersFullScreenWhenPlaybackBegins is for playback the user starts): no delegate call, the
            // movie plays to its end inline
            try expect(ev.isEmpty && full == "none" && t > 5.5, r)
            return r
        })
        #endif

        // MARK: UIKit: the scene lifecycle when the app goes to the background and comes back: sdkcov opens the companion
        // app sdkcovDoc (ext/DocApp.swift) by URL after marking a lifecycle request; sdkcovDoc opens sdkcov: again at once.
        // The window scene's and the application's notifications in order, the activation states, and UIKit saving the
        // scene's NSUserActivity (needsSave) when it leaves the foreground. Last in the run (Registry.all ends with p22).
        #if os(iOS) || os(visionOS) || os(tvOS)
        c.append(check("UIKit", "scene-lifecycle-round-trip", timeout: 120) {
            let t0 = Date()
            let bg = await onMain { UIApplication.shared.beginBackgroundTask(withName: "sdkcov-lifecycle") {} }
            defer { Task { @MainActor in UIApplication.shared.endBackgroundTask(bg) } }
            // with --only the check can start before the scene is up: wait for it (20 s)
            _ = await p3Wait(20) { await onMain { UIApplication.shared.connectedScenes.contains { $0.activationState == .foregroundActive } } }
            guard let scene = await onMain({ UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene }) else {
                throw Fail("no foreground-active window scene")
            }
            let ev = Mutex<[String]>([])
            let nc = NotificationCenter.default
            var obs: [NSObjectProtocol] = []
            let state = { @MainActor in "\(scene.activationState.rawValue)/\(UIApplication.shared.applicationState.rawValue)" }
            for (n, tag) in [(UIScene.willDeactivateNotification, "scene.willDeactivate"), (UIScene.didEnterBackgroundNotification, "scene.didEnterBackground"),
                             (UIScene.willEnterForegroundNotification, "scene.willEnterForeground"), (UIScene.didActivateNotification, "scene.didActivate")] {
                obs.append(nc.addObserver(forName: n, object: scene, queue: .main) { _ in
                    let s = MainActor.assumeIsolated { state() }
                    ev.withLock { $0.append("\(tag)[\(s)]") }
                })
            }
            for (n, tag) in [(UIApplication.willResignActiveNotification, "app.willResignActive"), (UIApplication.didEnterBackgroundNotification, "app.didEnterBackground"),
                             (UIApplication.willEnterForegroundNotification, "app.willEnterForeground"), (UIApplication.didBecomeActiveNotification, "app.didBecomeActive")] {
                obs.append(nc.addObserver(forName: n, object: nil, queue: .main) { _ in ev.withLock { $0.append(tag) } })
            }
            defer { obs.forEach { nc.removeObserver($0) } }
            let ad = P22ActivityDelegate()
            let act = NSUserActivity(activityType: "com.x86sim.test.sdkcov.lifecycle")
            act.title = "sdkcov lifecycle"; act.userInfo = ["step": 1]; act.delegate = ad
            let session = await onMain { () -> String in scene.userActivity = act; act.needsSave = true; return scene.session.persistentIdentifier }
            let token = "\(Int(t0.timeIntervalSince1970 * 1000))"
            p22Mark("lifecycle-request", token)
            let ob = P7Box<Bool>()
            await onMain { UIApplication.shared.open(URL(string: "sdkcovdoc://lifecycle")!) { ob.set($0) } }
            let opened = await ob.wait(20) ?? false
            try expect(opened, "sdkcovdoc: not opened (sdkcovDoc installed?)")
            let names = { ev.withLock { $0.map { String($0.prefix { $0 != "[" }) } } }
            #if os(visionOS)
            // visionOS: the apps' windows share the space; Apple's simulator leaves sdkcov's scene foreground-active,
            // with no notification at all, while sdkcovDoc comes up (10 s)
            try await Task.sleep(for: .seconds(10))
            let ve = ev.withLock { $0 }
            let vsame = await onMain { scene.session.persistentIdentifier == session && scene.activationState == .foregroundActive && UIApplication.shared.applicationState == .active }
            let vd = "events \(ve); still foreground-active \(vsame), saves \(ad.saves.load(ordering: .relaxed))"
            try expect(ve.isEmpty && vsame, vd)
            return vd
            #else
            var answered: Date?
            let back = await more2Wait(60) {
                if answered == nil && !p3Marks("docapp-lifecycle", since: t0).isEmpty { answered = Date() }
                if let a = answered, Date().timeIntervalSince(a) > 5 { return true }
                return names().contains("scene.didEnterBackground") && names().last == "scene.didActivate" || names().last == "app.didBecomeActive" && names().contains("app.didEnterBackground")
            }
            try await Task.sleep(for: .milliseconds(500))
            let e = ev.withLock { $0 }
            let same = await onMain { scene.session.persistentIdentifier == session && scene.activationState == .foregroundActive }
            let docMark = p3Marks("docapp-lifecycle", since: t0).last ?? "-"
            let detail = "\(e); saves \(ad.saves.load(ordering: .relaxed)), same session + active \(same), sdkcovDoc \(docMark)"
            try expect(back, "not back in front in 60 s: \(detail)")
            // Apple's order: each scene notification before the application's, the activation states as below; UIKit
            // does not save the scene's activity on the way out (userActivityWillSave never called)
            try expect(e == ["scene.willDeactivate[0/0]", "app.willResignActive", "scene.didEnterBackground[2/2]", "app.didEnterBackground",
                             "scene.willEnterForeground[2/2]", "app.willEnterForeground", "scene.didActivate[0/1]", "app.didBecomeActive"], "sequence: \(detail)")
            try expect(ad.saves.load(ordering: .relaxed) == 0, "activity saved: \(detail)")
            try expect(same, detail)
            return detail
            #endif
        })
        #endif
        return c
    }
}
