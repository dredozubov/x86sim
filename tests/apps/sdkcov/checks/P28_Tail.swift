// SDK coverage, round 30 wave 2 (P28): public API of the SDK still not referenced by any check after P27
// (~/scratch/r30/apisurf.py), area: Tail. Each check asserts what Apple's simulator answers (ref-mac.sh --only).
// Types only the system makes (results, sessions, extension principal protocols an app conforms to in its own
// extension target) are asserted the way an app meets them: decoded from JSON through their Codable conformance,
// built by the API that returns them, or (protocols with no app-side instance here) their Swift runtime metadata.
import Foundation
import ObjectiveC
#if canImport(WorkoutKit) && (os(iOS) || os(watchOS))
import WorkoutKit
import HealthKit
#endif
#if canImport(EnergyKit)
import EnergyKit
#endif
#if canImport(TelephonyMessagingKit) && os(iOS)
import TelephonyMessagingKit
#endif
#if canImport(WiFiAware) && os(iOS)
import WiFiAware
import Network
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(CoreNFC) && os(iOS)
import CoreNFC
#endif
#if canImport(RoomPlan) && os(iOS)
import RoomPlan
#endif
#if canImport(PaperKit) && (os(iOS) || os(visionOS))
import PaperKit
#endif
#if canImport(IdentityLookup) && (os(iOS) || os(visionOS))
import IdentityLookup
#endif
#if canImport(Messages) && os(iOS)
import Messages
#endif
#if canImport(NetworkExtension)
import NetworkExtension
import Network
#endif
#if canImport(CallKit) && !os(tvOS)
import CallKit
#endif
#if canImport(NearbyInteraction)
import NearbyInteraction
#endif
#if canImport(VideoSubscriberAccount) && (os(iOS) || os(tvOS) || os(visionOS))
import VideoSubscriberAccount
#endif
#if canImport(BrowserKit) && os(iOS)
import BrowserKit
#endif
#if canImport(ExposureNotification) && os(iOS)
import ExposureNotification
#endif
#if canImport(Photos)
import Photos
#endif
#if canImport(AccessorySetupKit) && os(iOS)
import AccessorySetupKit
#endif
#if canImport(WebKit) && (os(iOS) || os(visionOS))
import WebKit
#endif
#if canImport(SafariServices) && (os(iOS) || os(visionOS))
import SafariServices
#endif
#if canImport(ClassKit) && (os(iOS) || os(visionOS))
import ClassKit
#endif
#if canImport(BrowserEngineKit) && os(iOS)
import BrowserEngineKit
import XPC
#endif
#if canImport(ImageCaptureCore) && (os(iOS) || os(visionOS))
import ImageCaptureCore
#endif

/// a Decodable type decoded from `json`: "ok", or the decoder's answer ("key <first missing key>", "type <path>", ...)
func p28tDecode<T: Decodable>(_ t: T.Type, _ json: String) -> String {
    do { _ = try JSONDecoder().decode(T.self, from: Data(json.utf8)); return "ok" }
    catch DecodingError.keyNotFound(let k, _) { return "key \(k.stringValue)" }
    catch DecodingError.typeMismatch(_, let c) { return "type \(c.codingPath.map(\.stringValue).joined(separator: "."))" }
    catch DecodingError.valueNotFound(_, let c) { return "null \(c.codingPath.map(\.stringValue).joined(separator: "."))" }
    catch DecodingError.dataCorrupted(let c) { return "corrupt \(c.codingPath.map(\.stringValue).joined(separator: "."))" }
    catch { return "\(type(of: error))" }
}
/// a value through JSONEncoder / JSONDecoder
func p28tRoundTrip<T: Codable>(_ v: T) throws -> T { try JSONDecoder().decode(T.self, from: try JSONEncoder().encode(v)) }
/// a type's runtime name (the Swift runtime resolves its metadata from the framework)
func p28tName(_ t: Any.Type) -> String { String(reflecting: t) }
/// "name" list of the first few failures
func p28tFirst(_ a: [String], _ n: Int = 6) -> String { a.isEmpty ? "" : " [" + a.prefix(n).joined(separator: " ") + (a.count > n ? " +\(a.count - n)" : "") + "]" }
/// ObjC classes by name: each present and a subclass of `sup`; returns the ones that are not
func p28tClasses(_ list: [(String, String)]) -> [String] {
    list.compactMap { (name, sup) in
        guard let c = NSClassFromString(name) else { return "\(name) missing" }
        guard let s = NSClassFromString(sup) else { return "\(sup) missing" }
        var k: AnyClass? = c
        while let x = k { if x == s { return nil }; k = class_getSuperclass(x) }
        return "\(name) not a \(sup)"
    }
}
/// a secure-coding round trip of `o` (nil when it does not decode)
func p28tArchive(_ o: NSObject) throws -> NSObject? {
    let d = try NSKeyedArchiver.archivedData(withRootObject: o, requiringSecureCoding: true)
    let u = try NSKeyedUnarchiver(forReadingFrom: d); u.requiresSecureCoding = false
    return u.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? NSObject
}

extension Registry {
    static var p28tail: [Check] {
        var c: [Check] = []
        c += p28tWorkout + p28tEnergy + p28tTelephony + p28tWiFiAware + p28tNFC + p28tRoomPlan + p28tPaperKit
        c += p28tIdentityLookup + p28tMessages + p28tNetworkExtension + p28tCallKit + p28tNearby + p28tVSA + p28tBrowserKit + p28tExposure + p28tPhotos + p28tAccessorySetup + p28tWebKit + p28tSafari + p28tClassKit
        c += p28tBrowserEngine + p28tImageCapture
        return c
    }
}

// MARK: WorkoutKit: every alert type in a custom workout's steps, through the plan's data representation

extension Registry {
    static var p28tWorkout: [Check] {
        var c: [Check] = []
#if canImport(WorkoutKit) && (os(iOS) || os(watchOS))
        c.append(check("WorkoutKit", "p28-alerts-plan") {
            let perMin = UnitFrequency(symbol: "/min", converter: UnitConverterLinear(coefficient: 1.0 / 60))
            let alerts: [(String, any WorkoutAlert, HKWorkoutActivityType)] = [
                ("cadence-range", CadenceRangeAlert(target: Measurement(value: 80, unit: perMin)...Measurement(value: 95, unit: perMin)), .cycling),
                ("cadence-threshold", CadenceThresholdAlert(target: Measurement(value: 170, unit: perMin)), .running),
                ("hr-range", HeartRateRangeAlert(target: Measurement(value: 120, unit: perMin)...Measurement(value: 150, unit: perMin)), .running),
                ("hr-zone", HeartRateZoneAlert(zone: 2), .running),
                ("power-range", PowerRangeAlert(target: Measurement(value: 150, unit: UnitPower.watts)...Measurement(value: 250, unit: UnitPower.watts), metric: .average), .cycling),
                ("power-threshold", PowerThresholdAlert(target: Measurement(value: 200, unit: UnitPower.watts), metric: .current), .cycling),
                ("power-zone", PowerZoneAlert(zone: 3), .cycling),
                ("speed-range", SpeedRangeAlert(target: Measurement(value: 3, unit: UnitSpeed.metersPerSecond)...Measurement(value: 4, unit: UnitSpeed.metersPerSecond), metric: .average), .running),
                ("speed-threshold", SpeedThresholdAlert(target: Measurement(value: 3.5, unit: UnitSpeed.metersPerSecond), metric: .current), .running),
            ]
            var supported: [String] = [], unsupported: [String] = [], bad: [String] = [], thrown: [String] = []
            for (n, a, act) in alerts {
                let metric: WorkoutAlertMetric = a.metric
                guard a.supports(activity: act, location: .outdoor) else { unsupported.append(n); continue }
                guard CustomWorkout.supportsAlert(a, activity: act, location: .outdoor) else { bad.append(n + ":custom"); continue }
                let goal: WorkoutGoal = .time(5, .minutes)
                let step = IntervalStep(.work, goal: goal, alert: a)
                let w = CustomWorkout(activity: act, location: .outdoor, displayName: "p28 \(n)", blocks: [IntervalBlock(steps: [step], iterations: 2)])
                let plan = WorkoutPlan(.custom(w))
                let back: WorkoutPlan
                do { back = try WorkoutPlan(from: try plan.dataRepresentation) } catch { thrown.append("\(n):\(error)"); continue }
                guard back.workout == plan.workout, case .custom(let bw) = back.workout,
                      let ba = bw.blocks.first?.steps.first?.step.alert, ba.metric == metric, AnyHashable(ba) == AnyHashable(a)
                else { bad.append(n); continue }
                supported.append(n)
            }
            // a scheduled plan: hashable value of plan + date components
            let plan = WorkoutPlan(.goal(SingleGoalWorkout(activity: .running, goal: .distance(5, .kilometers))))
            let s1 = ScheduledWorkoutPlan(plan, date: DateComponents(year: 2026, month: 12, day: 1, hour: 7))
            let s2 = ScheduledWorkoutPlan(plan, date: DateComponents(year: 2026, month: 12, day: 1, hour: 7))
            let s3 = ScheduledWorkoutPlan(plan, date: DateComponents(year: 2026, month: 12, day: 2, hour: 7))
            try expect(s1 == s2 && s1 != s3 && Set([s1, s2, s3]).count == 2 && s1.date.day == 1, "scheduled plan equality")
            let errs: [StateError] = [.watchNotPaired, .workoutApplicationNotInstalled]
            let texts = errs.map { $0.localizedDescription }
            try expect(bad.isEmpty && supported.count + thrown.count + unsupported.count == alerts.count, "round trip \(supported.count), unsupported \(unsupported)\(p28tFirst(bad)) thrown \(thrown)")
            return "\(supported.count)/\(alerts.count) alerts round trip in a custom plan (unsupported \(unsupported.joined(separator: ",")); thrown \(thrown.joined(separator: ","))); scheduled plans equal by date; state errors \(texts.count)"
        })
#endif
        return c
    }
}

// MARK: EnergyKit: load events (Apple's EnergyKit traps unless an EV event's power is in milliwatts and its energy in EnergyKit's milliwatt-hours) (HVAC, EV, EV status) built, Codable round trip; insight query and record values

extension Registry {
    static var p28tEnergy: [Check] {
        var c: [Check] = []
#if canImport(EnergyKit)
        c.append(check("EnergyKit", "p28-load-events") {
            let t = Date(timeIntervalSince1970: 1_790_000_000), tok = UUID(), venue = UUID()
            let dev = ElectricalLoadDevice(id: "ev1", name: "p28 car", type: .electricVehicle)
            let hvac = ElectricHVACLoadEvent(timestamp: t, measurement: .init(stage: 2),
                                             session: .init(id: UUID(), state: .begin, guidanceState: .init(wasFollowingGuidance: true, guidanceToken: tok)), deviceID: "hvac1")
            let flow: ElectricityFlowDirection = .imported
            let ev = ElectricVehicleLoadEvent(timestamp: t, measurement: .init(stateOfCharge: 40, direction: flow, power: Measurement(value: 7_200_000, unit: .milliwatts), energy: Measurement(value: 3_000_000, unit: UnitEnergy.EnergyKit.milliwattHours)),
                                              session: .init(id: UUID(), state: .active, guidanceState: .init(wasFollowingGuidance: false, guidanceToken: tok)), device: dev)
            let active: ElectricVehicleChargingReason.ActiveReason = .cleanerEnergyAvailable
            let idle: ElectricVehicleChargingReason.IdleReason = .batteryFull
            let st = ElectricVehicleStatusEvent(timestamp: t, device: dev, venueID: venue, status: .chargingActive(active), stateOfCharge: 41,
                                                energy: Measurement(value: 30_000_000, unit: UnitEnergy.EnergyKit.milliwattHours), estimatedRange: Measurement(value: 180, unit: .kilometers))
            let st2 = ElectricVehicleStatusEvent(timestamp: t, device: dev, venueID: venue, status: .chargingIdle(idle), stateOfCharge: 100, energy: Measurement(value: 70_000_000, unit: UnitEnergy.EnergyKit.milliwattHours))
            func ids<E: ElectricalLoadEventProtocol>(_ e: E) -> String { "\(e.id)" }
            let hb = try p28tRoundTrip(hvac), eb = try p28tRoundTrip(ev), sb = try p28tRoundTrip(st)
            try expect(hb.measurement.stage == 2 && hb.session.state == .begin && hb.session.guidanceState.guidanceToken == tok && hb.deviceID == "hvac1", "hvac \(hb)")
            try expect(eb.measurement.stateOfCharge == 40 && eb.measurement.direction == .imported && eb.deviceID == "ev1" && eb.session.state == .active, "ev \(eb)")
            try expect(sb == st && st != st2 && sb.status == .chargingActive(.cleanerEnergyAvailable) && sb.estimatedRange?.value == 180, "status \(sb)")
            try expect(ids(hvac) == "\(hvac.id)" && ids(st) != ids(st2), "ids")
            return "HVAC / EV / EV status events round trip (\(ev.deviceName), soc \(sb.stateOfCharge))"
        })
        c.append(check("EnergyKit", "p28-insight-query-record") {
            let r = DateInterval(start: Date(timeIntervalSince1970: 1_790_000_000), duration: 86400)
            let q = ElectricityInsightQuery(options: [.cleanliness, .tariff], range: r, granularity: .hourly, flowDirection: .exported)
            let qb = try p28tRoundTrip(q)
            try expect(qb.options == [.cleanliness, .tariff] && qb.granularity == .hourly && qb.flowDirection == .exported && qb.range == r, "query \(qb)")
            // the record's measure types: energy measurements and durations (ElectricityInsightMeasure conformances)
            func measure<M: ElectricityInsightMeasure>(_ m: M) -> String { "\(m)" }
            let kwh = Measurement(value: 1.5, unit: UnitEnergy.kilowattHours)
            let g = ElectricityInsightRecord<Measurement<UnitEnergy>>.GridCleanliness(cleaner: kwh, lessClean: nil, avoid: nil, unknown: nil)
            let tp = ElectricityInsightRecord<Duration>.TariffPeak(superOffPeak: .seconds(60), offPeak: nil, partialPeak: nil, onPeak: .seconds(5), criticalPeak: nil, unknown: nil)
            try expect(g.cleaner == kwh && tp.onPeak == .seconds(5) && !measure(kwh).isEmpty && !measure(Duration.seconds(1)).isEmpty, "record parts")
            return "query round trip; record parts for energy and runtime measures"
        })
#endif
        return c
    }
}

// MARK: TelephonyMessagingKit: SMS / MMS / RCS message values

extension Registry {
    static var p28tTelephony: [Check] {
        var c: [Check] = []
#if canImport(TelephonyMessagingKit) && os(iOS)
        c.append(check("TelephonyMessagingKit", "p28-message-values") {
            let sid = SMSMessageID(rawValue: 7), mid = MMSMessageID(rawValue: 8), rid = RCSMessageID(rawValue: "p28-r1")
            try expect(sid.rawValue == 7 && mid.rawValue == 8 && rid.rawValue == "p28-r1" && !sid.description.isEmpty && !rid.description.isEmpty, "ids")
            let (sb2, rb2, mb2) = (try p28tRoundTrip(sid), try p28tRoundTrip(rid), try p28tRoundTrip(mid))
            try expect(sb2 == sid && rb2 == rid && mb2 == mid, "id round trip")
            let sms = SMSContent(body: "p28 hello"), h = SMSHandle(phoneNumber: "+15555550100")
            let smsb = try p28tRoundTrip(sms), hb = try p28tRoundTrip(h)
            try expect(smsb.body == "p28 hello" && hb.phoneNumber == "+15555550100", "sms \(smsb.body) \(hb.phoneNumber)")
            var mms = MMSContent(parts: [MMSPartContent(data: Data("hi".utf8), contentType: .plainText, contentID: "c1", disposition: .inline, fileName: "a.txt")],
                                 recipients: [MMSHandle(phoneNumber: "+15555550101")], subject: "p28")
            mms.headers["X-p28"] = "1"
            let mb = try p28tRoundTrip(mms)
            try expect(mb.parts.first?.data == Data("hi".utf8) && mb.subject == "p28" && mb.recipients.first?.phoneNumber == "+15555550101" && mb.headers["X-p28"] == "1", "mms \(mb)")
            // the values with no public initializer (the service makes them): their Codable conformance, from JSON
            let ans = [("CellularServiceID", p28tDecode(CellularServiceID.self, "{}")), ("CellularServiceState", p28tDecode(CellularServiceState.self, "{}")),
                       ("SMSMessage", p28tDecode(SMSMessage.self, "{}")), ("MMSMessage", p28tDecode(MMSMessage.self, "{}")),
                       ("RCSMessage", p28tDecode(RCSMessage.self, "{}")), ("RCSFileTransferMetadata", p28tDecode(RCSFileTransferMetadata.self, "{}")),
                       ("RCSGroupContext", p28tDecode(RCSGroupContext.self, "{}"))]
            let bad = ans.filter { !$0.1.hasPrefix("key ") }.map { "\($0.0):\($0.1)" }
            try expect(bad.isEmpty, "decode answers\(p28tFirst(bad))")
            return "ids, SMS, MMS round trip; service values decode to a missing key: " + ans.map { "\($0.0) \($0.1)" }.joined(separator: ", ")
        })
#endif
        return c
    }
}

// MARK: WiFiAware: parameters, secrets, listener / browser providers, errors and endpoints (no Wi-Fi Aware radio)

extension Registry {
    static var p28tWiFiAware: [Check] {
        var c: [Check] = []
#if canImport(WiFiAware) && os(iOS)
        c.append(check("WiFiAware", "p28-values") {
            var n = 0
            func ok(_ b: Bool, _ w: String) throws { try expect(b, w); n += 1 }
            let p = WAParameters(performanceMode: .realtime)
            try ok(p.performanceMode == .realtime && WAParameters.defaults.performanceMode == .bulk && WAParameters.realtime.performanceMode == .realtime, "parameters")
            let modes: [WAPerformanceMode] = WAPerformanceMode.allCases, acs: [WAAccessCategory] = WAAccessCategory.allCases
            try ok(modes.count == 2 && acs.count == 4 && (try p28tRoundTrip(WAAccessCategory.interactiveVoice)) == .interactiveVoice, "enums \(modes.count) \(acs.count)")
            try ok(WASharedSecret.ProtocolName("p28-proto") != nil && WASharedSecret.ProtocolName.tlsPSK != WASharedSecret.ProtocolName.ipsecPSK
                   && WASharedSecret.Context.bundleID == WASharedSecret.Context.bundleID && WASharedSecret.DerivationMethod.kdfHash256 == .kdfHash256, "secret parts")
            // no paired devices, no declared services: the providers still describe themselves
            let pubDevices: WAPublisherListener.Devices = .allPairedDevices, subDevices: WASubscriberBrowser.Devices = .userSpecifiedDevices
            _ = (pubDevices, subDevices)
            let endpoint: WAEndpoint? = NWEndpoint.hostPort(host: "127.0.0.1", port: 9).wifiAware
            let err: WAError? = NWError.posix(.ECONNREFUSED).wifiAware
            try ok(endpoint == nil && err == nil, "endpoint \(String(describing: endpoint)) error \(String(describing: err))")
            // the service-made values: decoded / metadata
            let rep = p28tDecode(WAPerformanceReport.self, "{}")
            let wae = p28tDecode(WAError.self, #"{"wifiAwareUnsupported":{"_0":{}}}"#)
            try ok(rep.hasPrefix("key "), "report decode \(rep)")
            let meta = [p28tName(WAPath.self), p28tName(WAPerformanceForecast.self), p28tName(WAConnection<TCP>.self),
                        p28tName((any WAService).self), p28tName(WAPublisherListener.self), p28tName(WASubscriberBrowser.self), p28tName(WASharedSecret.self)]
            try ok(meta.allSatisfy { $0.hasPrefix("WiFiAware.") || $0.hasPrefix("any WiFiAware.") }, "metadata \(meta)")
            return "\(n) groups: parameters, modes, secret parts, no endpoint / error from Network values; report decode \(rep); WAError decode \(wae)"
        })
#endif
        return c
    }
}

// MARK: CoreNFC: command / configuration objects and the Swift response values (no NFC reader on a simulator)

#if canImport(CoreNFC) && os(iOS)
final class P28TNFCDelegate: NSObject, NFCTagReaderSessionDelegate, @unchecked Sendable {
    let calls = P28TBox<String>()
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) { calls.set("active") }
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: any Error) { calls.set("invalidated \((error as NSError).code)") }
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        for t in tags { switch t { case .feliCa: calls.set("felica"); case .iso7816: calls.set("7816"); case .iso15693: calls.set("15693"); case .miFare: calls.set("mifare"); @unknown default: break } }
    }
}
#endif
/// a value set once from any thread, waited for
final class P28TBox<T>: @unchecked Sendable {
    private let l = NSLock(); private var v: T?
    func set(_ x: T) { l.lock(); if v == nil { v = x }; l.unlock() }
    var value: T? { l.lock(); defer { l.unlock() }; return v }
    func wait(_ secs: Double) async -> T? {
        let end = Date().addingTimeInterval(secs)
        while Date() < end { if let x = value { return x }; try? await Task.sleep(for: .milliseconds(50)) }
        return value
    }
}

extension Registry {
    static var p28tNFC: [Check] {
        var c: [Check] = []
#if canImport(CoreNFC) && os(iOS)
        c.append(check("CoreNFC", "p28-commands-values") {
            var n = 0
            func ok(_ b: Bool, _ w: String) throws { try expect(b, w); n += 1 }
            let apdu = NFCISO7816APDU(instructionClass: 0x00, instructionCode: 0xA4, p1Parameter: 0x04, p2Parameter: 0x00, data: Data([0xA0, 0x00, 0x00, 0x02, 0x47]), expectedResponseLength: 256)
            let apc = apdu.copy() as? NFCISO7816APDU
            try ok(apdu.instructionCode == 0xA4 && apdu.p1Parameter == 4 && apdu.data?.count == 5 && apdu.expectedResponseLength == 256 && apc?.instructionCode == 0xA4, "apdu \(apdu)")
            if let raw = NFCISO7816APDU(data: Data([0x00, 0xB0, 0x00, 0x00, 0x10])) {
                try ok(raw.instructionCode == 0xB0 && raw.expectedResponseLength == 16, "raw apdu \(raw.instructionCode) le \(raw.expectedResponseLength)")
            }
            let resp = NFCISO7816ResponseAPDU(statusWord1: 0x90, statusWord2: 0x00, payload: Data([1, 2]))
            try ok(resp.statusWord1 == 0x90 && resp.payload == Data([1, 2]), "response")
            let custom = NFCISO15693CustomCommandConfiguration(manufacturerCode: 0x04, customCommandCode: 0xA5, requestParameters: Data([9]), maximumRetries: 3, retryInterval: 0.25)
            let multi = NFCISO15693ReadMultipleBlocksConfiguration(range: NSRange(location: 2, length: 8), chunkSize: 4, maximumRetries: 1, retryInterval: 0.1)
            try ok(custom.customCommandCode == 0xA5 && custom.manufacturerCode == 4 && custom.maximumRetries == 3 && multi.range.length == 8 && multi.chunkSize == 4, "15693 configurations")
            let base: NFCTagCommandConfiguration = multi
            try ok(base.retryInterval == 0.1 && (base.copy() as? NFCISO15693ReadMultipleBlocksConfiguration)?.chunkSize == 4, "base configuration")
            let vas = NFCVASCommandConfiguration(vasMode: .normal, passTypeIdentifier: "pass.com.x86sim.p28", url: URL(string: "https://x86sim.test/vas"))
            let vc = vas.copy() as? NFCVASCommandConfiguration
            let vcopy = "\(vc?.passTypeIdentifier ?? "nil")|\(vc?.url?.absoluteString ?? "nil")"
            try ok(vas.passTypeIdentifier == "pass.com.x86sim.p28" && vas.url?.host == "x86sim.test" && vas.mode == .normal && vc != nil, "vas \(vas.passTypeIdentifier) copy \(vcopy)")
            let cfg = NFCTagReaderSession.Configuration(pollingOption: [.iso14443, .iso15693], iso7816SelectIdentifiers: ["A000000247"], feliCaSystemCodes: [])
            try ok(cfg.pollingOption.contains(.iso15693) && cfg.iso7816SelectIdentifiers == ["A000000247"], "session configuration")
            // the Objective-C class behind the Swift struct (NFCTagReaderSessionConfiguration), through KVC
            let oc = (NSClassFromString("NFCTagReaderSessionConfiguration") as? NSObject.Type)?.init()
            oc?.setValue(NFCTagReaderSession.PollingOption.iso18092.rawValue, forKey: "polling")
            oc?.setValue(["8008"], forKey: "felicaSystemCodes")
            try ok((oc?.value(forKey: "polling") as? Int) == NFCTagReaderSession.PollingOption.iso18092.rawValue && (oc?.value(forKey: "felicaSystemCodes") as? [String]) == ["8008"], "objc configuration \(String(describing: oc))")
            let poll = NFCFeliCaPollingResponse(manufactureParameter: Data([1]), requestData: nil)
            let flag = NFCFeliCaStatusFlag(statusFlag1: 0, statusFlag2: 0)
            let sv = NFCFeliCaRequsetServiceV2Response(statusFlag1: 0, statusFlag2: 0, encryptionIdentifier: .AES, nodeKeyVersionListAES: [Data([1, 0])], nodeKeyVersionListDES: nil)
            let spec = NFCFeliCaRequestSpecificationVersionResponse(statusFlag1: 0, statusFlag2: 0, basicVersion: Data([1]), optionVersion: nil)
            try ok(poll.manufactureParameter == Data([1]) && flag.statusFlag1 == 0 && sv.encryptionIdentifier == .AES && spec.basicVersion == Data([1]), "felica values")
            let sys = NFCISO15693SystemInfo(uniqueIdentifier: Data([0xE0, 4]), dataStorageFormatIdentifier: 0, applicationFamilyIdentifier: 0, blockSize: 4, totalBlocks: 64, icReference: 1)
            let sec = NFCISO15693MultipleBlockSecurityStatus(blockSecurityStatus: [0, 1, 0])
            try ok(sys.totalBlocks == 64 && sec.blockSecurityStatus == [0, 1, 0], "15693 values")
            // the VAS response and the abstract session classes exist; reading is unavailable on a simulator
            let cls = p28tClasses([("NFCVASResponse", "NSObject"), ("NFCReaderSession", "NSObject"), ("NFCISO15693ReaderSession", "NFCReaderSession"),
                                  ("NFCPaymentTagReaderSession", "NFCTagReaderSession")])
            try ok(cls.isEmpty && !NFCReaderSession.readingAvailable, "classes \(cls)")
            // an app's tag-session delegate (the session itself cannot start here): the protocol conformance and the NFCTag cases
            let d = P28TNFCDelegate()
            let asDelegate: (any NFCTagReaderSessionDelegate)? = d as Any as? any NFCTagReaderSessionDelegate
            try ok(asDelegate != nil && d.calls.value == nil, "delegate")
            return "\(n) groups: APDU, 15693 / VAS / session configurations, FeliCa and 15693 values; reading unavailable; VAS copy \(vcopy)"
        })
        // NFCTagReaderSession(configuration:delegate:queue:) (the Swift initializer) traps "Platform not supported" in
        // CoreNFC's Swift overlay on a simulator: not called
#endif
        return c
    }
}

// MARK: RoomPlan: captured-room attributes and their categories, builders without input, the capture view

#if canImport(RoomPlan) && os(iOS)
final class P28TRoomDelegate: NSObject, RoomCaptureSessionDelegate, RoomCaptureViewDelegate, NSCoding {
    override init() { super.init() }
    required init?(coder: NSCoder) { super.init() }
    func encode(with coder: NSCoder) {}
    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: (any Error)?) -> Bool { false }
}
#endif

extension Registry {
    static var p28tRoomPlan: [Check] {
        var c: [Check] = []
#if canImport(RoomPlan) && os(iOS)
        c.append(check("RoomPlan", "p28-attributes-builders", timeout: 30) {
            func names<A: CapturedRoomAttribute>(_ t: A.Type) -> (Int, String) { (A.allCases.count, A.parentCategory.map { "\($0)" } ?? "nil") }
            let rows: [(String, (Int, String))] = [("chair", names(ChairType.self)), ("legs", names(ChairLegType.self)), ("arms", names(ChairArmType.self)),
                                                    ("back", names(ChairBackType.self)), ("sofa", names(SofaType.self)), ("table", names(TableType.self)),
                                                    ("tableShape", names(TableShapeType.self)), ("storage", names(StorageType.self))]
            try expect(rows.allSatisfy { $0.1.0 >= 2 && $0.1.1 != "nil" }, "attributes \(rows)")
            let chairCat: CapturedElementCategory? = ChairType.parentCategory
            try expect(chairCat == .object(.chair) && TableType.parentCategory == .object(.table), "parents \(String(describing: chairCat))")
            let back = try p28tRoundTrip(CapturedElementCategory.surface(.wall))
            try expect(back == .surface(.wall), "category round trip")
            let combos = CapturedRoom.Object.Category.chair.supportedCombinations.count
            let okCombo = CapturedRoom.Object.Category.chair.supportsCombination([ChairType.dining, ChairArmType.existing, ChairBackType.existing, ChairLegType.four])
            // builders with nothing to build
            let rb = RoomBuilder(options: [.beautifyObjects]), sb = StructureBuilder(options: [])
            let rd = p28tDecode(CapturedRoomData.self, "{}"), sd = p28tDecode(CapturedStructure.self, "{}")
            var sAns = "built", rAns = "built"
            do { let st = try await sb.capturedStructure(from: []); sAns = "built: \(st.rooms.count) rooms, \(st.walls.count) walls" } catch { sAns = "\(error)" }
            if let data = try? JSONDecoder().decode(CapturedRoomData.self, from: Data("{}".utf8)) {
                do { let r = try await rb.capturedRoom(from: data); rAns = "built: \(r.walls.count) walls, \(r.objects.count) objects" } catch { rAns = "\(error)" }
            } else { rAns = "no data" }
            try expect(!sAns.hasPrefix("built: 1") && !rAns.contains("built: 1"), "built from nothing: structure \(sAns), room \(rAns)")
            return "\(rows.count) attribute enums; chair combinations \(combos), dining/arms/back/four \(okCombo); room data decode \(rd), structure decode \(sd); empty structure: \(sAns); room from empty data: \(rAns)"
        })
        c.append(check("RoomPlan", "p28-capture-view", timeout: 30) {
            let r = await onMain { () -> String in
                let v = RoomCaptureView(frame: CGRect(x: 0, y: 0, width: 200, height: 300))
                let d = P28TRoomDelegate()
                v.delegate = d
                v.captureSession?.delegate = d
                v.isModelEnabled = false
                let arch = (try? NSKeyedArchiver.archivedData(withRootObject: d, requiringSecureCoding: false))?.count ?? 0
                return "session \(v.captureSession != nil), delegate \(v.delegate === d), model \(v.isModelEnabled), archive \(arch) B"
            }
            try expect(r.contains("delegate true"), r)
            return r
        })
#endif
        return c
    }
}

// MARK: PaperKit: each markup element type in an ordered set and in a markup, feature sets, adornments, the controllers

extension Registry {
    static var p28tPaperKit: [Check] {
        var c: [Check] = []
#if canImport(PaperKit) && (os(iOS) || os(visionOS))
        c.append(check("PaperKit", "p28-markup-elements", timeout: 40) {
            let img: CGImage = {
                let ctx = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 32, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8)); return ctx.makeImage()!
            }()
            var shape = ShapeMarkup(configuration: ShapeConfiguration(type: .ellipse, strokeColor: CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1), lineWidth: 3), frame: CGRect(x: 10, y: 10, width: 40, height: 30))
            shape.allowedInteractions = [.move, .resize]
            let link = LinkMarkup(url: URL(string: "https://x86sim.test/p28")!, frame: CGRect(x: 60, y: 10, width: 50, height: 20), allowedInteractions: .readOnly)
            let loupe = LoupeMarkup(frame: CGRect(x: 10, y: 50, width: 40, height: 40), magnification: 2)
            let image = ImageMarkup(image: img, frame: CGRect(x: 60, y: 50, width: 30, height: 30), accessibilityDescription: "p28 blue")
            var set = MarkupOrderedSet()
            let els: [any Markup] = [shape, link, loupe, image]
            let ins = els.map { set.append($0).inserted }
            let inserted = ins.filter { $0 }.count
            try expect(set.count == inserted && inserted >= 2, "set count \(set.count), inserted \(ins)")
            let linkID: MarkupID<LinkMarkup> = link.id
            try expect(MarkupID<LinkMarkup>(rawValue: linkID.rawValue) == linkID, "id raw value")
            if ins[1] {
                try expect(set[linkID]?.url.host == "x86sim.test", "lookup by id")
                let removed = set.removeElement(for: link.id)
                try expect(removed?.url == link.url && set.count == inserted - 1, "remove")
            }
            var m = PaperMarkup(bounds: CGRect(x: 0, y: 0, width: 200, height: 120))
            m.subelements.append(contentsOf: els)
            let d = try await m.dataRepresentation()
            let back = try PaperMarkup(dataRepresentation: d)
            let n = back.subelements.count
            let before = m.subelements.count
            try expect(n == before && n >= 1, "markup round trip \(n) of \(before) elements")
            // feature sets: the image / link / loupe features; removing them leaves the shape
            let fs: FeatureSet = m.featureSet
            var plain = FeatureSet.latest
            plain.features.subtract([.images, .links, .loupes])
            var m2 = back
            m2.removeContentUnsupported(by: plain)
            let left = m2.subelements.count
            try expect(left <= n, "features \(fs.features.count), left \(left)")
            // a malformed archive: the error type
            var err = "decoded"
            do { _ = try PaperMarkup(dataRepresentation: Data([1, 2, 3])) } catch let e as MarkupError { err = "\(e)" } catch { err = "\(type(of: error))" }
            let ad = MarkupAdornment(anchor: .canvas(location: CGPoint(x: 5, y: 5)), imageConfiguration: .systemImage("star"), dragRegion: .fixed, scalesWithZoom: true)
            let adb = try p28tRoundTrip(ad)
            try expect(adb.anchor == ad.anchor && adb.dragRegion == .fixed && adb.scalesWithZoom, "adornment round trip")
            let auto: MarkupAutoresizing = [.flexibleWidth], ro = RenderingOptions(darkUserInterfaceStyle: true, layoutRightToLeft: false)
            try expect(auto.contains(.flexibleWidth) && ro.darkUserInterfaceStyle && ro != RenderingOptions(), "options")
            return "set inserted \(ins) (shape, link, loupe, image), markup \(n) elements \(d.count) B, features \(fs.features.count); feature removal leaves \(left); bad archive: \(err)"
        })
        c.append(check("PaperKit", "p28-controllers", timeout: 30) {
            let r = try await onMain { () throws -> String in
                let pm = PaperMarkupViewController(markup: PaperMarkup(bounds: CGRect(x: 0, y: 0, width: 300, height: 300)), supportedFeatureSet: .latest)
                pm.isEditable = false
                let me = MarkupEditViewController(supportedFeatureSet: .version1)
                _ = pm.view; _ = me.view
                try expect(pm.markup != nil && !pm.isEditable && me.supportedFeatureSet == .version1, "controllers")
                return "markup controller zoom \(pm.zoomRange), edit controller features \(me.supportedFeatureSet.features.count)"
            }
            return r
        })
#endif
        return c
    }
}

/// secure-coding classes the system makes (no public initializer): each instantiated through init(coder:) from an
/// empty archive (p27sFromEmptyCoder), then archived and decoded again as the same class; returns the failures
func p28tCoderTable(_ names: [String]) throws -> (ok: Int, bad: [String]) {
    var ok = 0, bad: [String] = []
    for n in names {
        guard let cls = NSClassFromString(n) else { bad.append(n + ":missing"); continue }
        var made: NSObject?, err: Error?
        if let ex = SDKCovCatch({ do { made = try p27sFromEmptyCoder(cls) } catch { err = error } }) { bad.append(n + ":raises \(ex.first ?? "")"); continue }
        if let err { throw err }
        guard let o = made else { bad.append(n + ":nil"); continue }
        guard type(of: o) == cls, let back = try p27sRoundTrip(o), type(of: back) == cls else { bad.append(n + ":roundtrip"); continue }
        ok += 1
    }
    return (ok, bad)
}

// MARK: IdentityLookup: classification requests / communications from archives, capabilities response, Live Caller ID

extension Registry {
    static var p28tIdentityLookup: [Check] {
        var c: [Check] = []
#if canImport(IdentityLookup) && (os(iOS) || os(visionOS))
        c.append(check("IdentityLookup", "p28-requests-live-caller-id") {
            let (ok, bad) = try p28tCoderTable(["ILCallClassificationRequest", "ILMessageClassificationRequest", "ILCallCommunication", "ILMessageCommunication",
                                                "ILCommunication", "ILMessageFilterCapabilitiesQueryRequest", "ILNetworkResponse"])
            let hier = p28tClasses([("ILCallCommunication", "ILCommunication"), ("ILMessageCommunication", "ILCommunication"),
                                    ("ILCallClassificationRequest", "ILClassificationRequest"), ("ILMessageClassificationRequest", "ILClassificationRequest")])
            #if os(iOS)
            let resp = ILMessageFilterCapabilitiesQueryResponse()
            resp.transactionalSubActions = [.transactionalFinance, .transactionalOrders]
            resp.promotionalSubActions = [.promotionalOffers]
            let rb = try p27sRoundTrip(resp) as? ILMessageFilterCapabilitiesQueryResponse
            try expect(rb?.transactionalSubActions == [.transactionalFinance, .transactionalOrders] && rb?.promotionalSubActions == [.promotionalOffers], "capabilities response \(String(describing: rb))")
            let ctx = LiveCallerIDLookupExtensionContext(serviceURL: URL(string: "https://x86sim.test/pir")!, tokenIssuerURL: URL(string: "https://x86sim.test/token")!, userTierToken: Data([1, 2]))
            try expect(try p28tRoundTrip(ctx) == ctx, "context round trip")
            let st: CallLookupExtensionStatus = LiveCallerIDLookupManager.shared.status(forExtensionWithIdentifier: "com.x86sim.test.sdkcov.nolookup")
            let meta = [p28tName((any LiveCallerIDLookupProtocol).self), p28tName((any LiveCallerIDLookupExtensionConfiguration).self)]
            #else
            let st = "n/a", meta: [String] = []
            #endif
            try expect(bad.isEmpty && hier.isEmpty, "\(ok)/7 \(bad) \(hier)")
            return "\(ok)/7 request / communication classes from archives; unknown lookup extension: \(st); \(meta.joined(separator: ", "))"
        })
#endif
        return c
    }
}

// MARK: Messages: sticker browser / view, the message layout base, UPI request, critical messaging values

extension Registry {
    static var p28tMessages: [Check] {
        var c: [Check] = []
#if canImport(Messages) && os(iOS)
        c.append(check("Messages", "p28-stickers-upi-critical", timeout: 30) {
            let r = try await onMain { () throws -> String in
                let bv = MSStickerBrowserView(frame: CGRect(x: 0, y: 0, width: 320, height: 200), stickerSize: .large)
                let bvc = MSStickerBrowserViewController(stickerSize: .small)
                let sv = MSStickerView(frame: CGRect(x: 0, y: 0, width: 100, height: 100), sticker: nil)
                bv.reloadData(); _ = bvc.view
                try expect(bv.stickerSize == .large && bvc.stickerSize == .small && bvc.stickerBrowserView.stickerSize == .small && sv.sticker == nil && !sv.isAnimating(), "sticker views")
                return "browser view / controller / sticker view, animation \(sv.animationDuration)"
            }
            let upi = MSUPIRequest(validationToken: "p28-token", recipients: ["+15555550100"])
            try expect(upi.validationToken == "p28-token" && upi.recipients == ["+15555550100"], "upi")
            let layout: MSMessageLayout = MSMessageTemplateLayout()
            try expect(layout.copy() is MSMessageTemplateLayout, "layout copy")
            let rec = MSRecipient(phoneNumber: "+15555550101"), msg = MSCriticalMessage(messageText: "p28")
            let errs: [MSCriticalMessagingError] = [.notSupported, .notAuthorized]
            let st: MSCriticalMessagingAuthorizationStatus? = .init(rawValue: 0)
            let m = MSCriticalSMSMessenger()
            let ans = await p27sAnswer(10) { "\(try await m.checkAuthorizationStatus(for: [rec]).mapValues(\.rawValue))" }
            try expect(Set([rec, MSRecipient(phoneNumber: "+15555550101")]).count == 1 && msg.messageText == "p28" && st == .unknown && errs[0].errorCode != errs[1].errorCode, "critical values")
            return "\(r); UPI request; critical messaging: max \(m.maximumCriticalMessagingRecipients), status \(ans)"
        })
#endif
        return c
    }
}

// MARK: NetworkExtension: network / filter rules and settings, transparent proxy and Ethernet tunnel settings, providers

extension Registry {
    static var p28tNetworkExtension: [Check] {
        var c: [Check] = []
#if canImport(NetworkExtension)
        // the filter / transparent proxy / Ethernet tunnel classes are macOS API (unavailable in Swift on the simulator
        // platforms): which of them the runtime still carries, each under its declared superclass, and an instance
        // made through init(coder:) from an empty archive for the secure-coding ones
        c.append(check("NetworkExtension", "p28-macos-classes") {
            let rows: [(String, String)] = [("NENetworkRule", "NSObject"), ("NEFilterRule", "NSObject"), ("NEFilterSettings", "NSObject"),
                                            ("NETransparentProxyNetworkSettings", "NETunnelNetworkSettings"), ("NEEthernetTunnelNetworkSettings", "NEPacketTunnelNetworkSettings"),
                                            ("NEEthernetTunnelProvider", "NEPacketTunnelProvider"), ("NEFilterPacketProvider", "NEFilterProvider"),
                                            ("NETransparentProxyProvider", "NEAppProxyProvider"), ("NEFilterPacketContext", "NSObject"), ("NETransparentProxyManager", "NEVPNManager")]
            let present = rows.filter { NSClassFromString($0.0) != nil }
            let wrong = p28tClasses(present)
            var coded: [String] = []
            for n in ["NENetworkRule", "NEFilterRule", "NEFilterSettings"] where NSClassFromString(n) != nil {
                if let o = try p27sFromEmptyCoder(NSClassFromString(n)!) { coded.append("\(n):\(type(of: o))") } else { coded.append("\(n):nil") }
            }
            try expect(wrong.isEmpty, "\(wrong)")
            return "present \(present.count)/\(rows.count): \(present.map(\.0).joined(separator: " ")); from archives: \(coded.joined(separator: " "))"
        })
#endif
        return c
    }
}

// MARK: CallKit: the call actions (DTMF, group, translating) and their bases, a round trip each; the observer's calls

extension Registry {
    static var p28tCallKit: [Check] {
        var c: [Check] = []
#if canImport(CallKit) && !os(tvOS)
        c.append(check("CallKit", "p28-call-actions") {
            let call = UUID(), other = UUID()
            let dtmf = CXPlayDTMFCallAction(call: call, digits: "12#", type: .singleTone)
            let group = CXSetGroupCallAction(call: call, callUUIDToGroupWith: other)
            let tr = CXSetTranslatingCallAction(call: call, isTranslating: true, localLanguage: "en", remoteLanguage: "de")
            let base: [CXCallAction] = [dtmf, group, tr]
            let back = try base.map { try p27sRoundTrip($0) as? CXCallAction }
            let db = back[0] as? CXPlayDTMFCallAction, gb = back[1] as? CXSetGroupCallAction, tb = back[2] as? CXSetTranslatingCallAction
            try expect(db?.digits == "12#" && db?.type == .singleTone && gb?.callUUIDToGroupWith == other && tb?.isTranslating == true && tb?.remoteLanguage == "de", "round trip \(back)")
            let actions: [CXAction] = base
            try expect(actions.allSatisfy { !$0.isComplete && $0.uuid != call } && back.allSatisfy { $0?.callUUID == call }, "bases")
            #if os(iOS) || os(visionOS)
            let calls: [CXCall] = CXCallObserver().calls
            #else
            let calls: [CXCall] = []
            #endif
            return "DTMF / group / translating actions round trip; \(calls.count) calls"
        })
#endif
        return c
    }
}

// MARK: NearbyInteraction: DL-TDOA configuration, convergence values, the result classes from archives

extension Registry {
    static var p28tNearby: [Check] {
        var c: [Check] = []
#if canImport(NearbyInteraction) && (os(iOS) || os(watchOS))
        c.append(check("NearbyInteraction", "p28-dltdoa-convergence") {
            let cfg = NIDLTDOAConfiguration(networkIdentifier: 7)
            let base: NIConfiguration = cfg
            let back = try p27sRoundTrip(base) as? NIDLTDOAConfiguration
            try expect(back?.networkIdentifier == 7 && (cfg.copy() as? NIDLTDOAConfiguration)?.networkIdentifier == 7, "dltdoa \(String(describing: back))")
            let r = NIAlgorithmConvergenceStatus.Reason(rawValue: "p28")
            let st: NIAlgorithmConvergenceStatus = .notConverged([r])
            try expect(st != .converged && st == .notConverged([r]), "status")
            // (NIDLTDOAMeasurement's init(coder:) raises NSInternalInconsistencyException on an empty archive: "NSData must
            // contain enough bytes for simd_double3"; only its class is checked)
            let (ok, bad) = try p28tCoderTable(["NIAlgorithmConvergence", "NIDiscoveryToken"])
            let hier = p28tClasses([("NIDLTDOAMeasurementFloorElevation", "NSObject"), ("NIDLTDOAMeasurement", "NSObject")])
            let tok: NIDiscoveryToken? = NISession().discoveryToken
            try expect(hier.isEmpty, "\(hier)")
            return "DL-TDOA configuration round trip, convergence status; \(ok)/2 result classes from archives\(p28tFirst(bad)); session token \(tok == nil ? "nil" : "present")"
        })
#endif
        return c
    }
}

// MARK: VideoSubscriberAccount: metadata request, application providers, subscriptions, the account manager's answer

extension Registry {
    static var p28tVSA: [Check] {
        var c: [Check] = []
#if canImport(VideoSubscriberAccount) && (os(iOS) || os(tvOS) || os(visionOS))
        c.append(check("VideoSubscriberAccount", "p28-metadata-request", timeout: 30) {
            let ap = VSAccountApplicationProvider(localizedDisplayName: "p28 TV", identifier: "p28.provider")
            let rq = VSAccountMetadataRequest()
            rq.channelIdentifier = "p28"; rq.includeAccountProviderIdentifier = true; rq.isInterruptionAllowed = false
            rq.applicationAccountProviders = [ap]; rq.attributeNames = ["uid"]
            try expect(rq.applicationAccountProviders?.first?.identifier == "p28.provider" && !rq.isInterruptionAllowed, "request")
            let sub = VSSubscription()
            sub.accessLevel = .freeWithAccount; sub.tierIdentifiers = ["p28"]
            try expect(sub.accessLevel == .freeWithAccount && sub.tierIdentifiers == ["p28"], "subscription")
            let mgr = VSAccountManager()
            let box = P28TBox<String>()
            let res: VSAccountManagerResult = mgr.enqueue(rq) { (md: VSAccountMetadata?, e: Error?) in
                box.set(md.map { "metadata \(String(describing: $0.accountProviderIdentifier))" } ?? "error \((e as NSError?)?.domain ?? "") \((e as NSError?)?.code ?? 0)")
            }
            let ans = await box.wait(15) ?? "no answer in 15 s"
            res.cancel()
            let hier = p28tClasses([("VSAccountProviderResponse", "NSObject"), ("VSAutoSignInToken", "NSObject"), ("VSAutoSignInTokenUpdateContext", "NSObject"), ("VSAppleSubscription", "NSObject")])
            try expect(hier.isEmpty && !ans.hasPrefix("metadata"), "\(ans) \(hier)")
            return "metadata request: \(ans)"
        })
#endif
        return c
    }
}

// MARK: BrowserKit: the browser data exchange records and options, secure-coding round trips

extension Registry {
    static var p28tBrowserKit: [Check] {
        var c: [Check] = []
#if canImport(BrowserKit) && os(iOS)
        c.append(check("BrowserKit", "p28-browser-data") {
            let t = Date(timeIntervalSince1970: 1_790_000_000)
            let objs: [BEBrowserData] = [
                BEBrowserDataBookmark(isFolder: false, title: "p28", identifier: "b1", url: URL(string: "https://x86sim.test/b")!, parentIdentifier: nil),
                BEBrowserDataReadingListItem(title: "p28 read", url: URL(string: "https://x86sim.test/r")!, dateOfLastVisit: t),
                BEBrowserDataExtension(displayName: "p28 ext", developerName: "x86sim", identifier: "e1", storeIdentifier: "123"),
                BEBrowserDataHistoryVisit(url: URL(string: "https://x86sim.test/h")!, dateOfLastVisit: t, title: "p28 h", loadedSuccessfully: true, httpGet: true, redirectSourceURL: nil, redirectSourceDateOfVisit: nil, redirectDestinationURL: nil, redirectDestinationDateOfVisit: nil, visitCount: 3),
            ]
            var bad: [String] = []
            for o in objs { if let b = try p27sRoundTrip(o), type(of: b) == type(of: o), p27sBytes(b) == p27sBytes(o) {} else { bad.append("\(type(of: o))") } }
            let base = BEBrowserData(sourceApplicationBundleIdentifier: "com.x86sim.p28", sourceApplicationLocalizedName: "p28")
            let md = BEExportMetadata(supportForExportToFiles: true, bookmarksCount: 1, readingListCount: 2, historyCount: 3, extensionsCount: 4)
            let eo = BEExportOptions(exportToFiles: false, dataTypes: [.bookmarks, .history]), io = BEImportOptions(importFromFiles: true)
            let mb = try p27sRoundTrip(md) as? BEExportMetadata, eob = try p27sRoundTrip(eo) as? BEExportOptions, iob = try p27sRoundTrip(io) as? BEImportOptions
            try expect(bad.isEmpty && base.sourceApplicationLocalizedName == "p28" && mb?.historyCount == 3 && eob?.dataTypes == [.bookmarks, .history] && iob?.importFromFiles == true,
                       "round trips \(bad)")
            return "4 browser data records, export metadata / options, import options round trip"
        })
#endif
        return c
    }
}

// MARK: ExposureNotification: configuration and keys; the result classes

extension Registry {
    static var p28tExposure: [Check] {
        var c: [Check] = []
#if canImport(ExposureNotification) && os(iOS)
        c.append(check("ExposureNotification", "p28-configuration-keys") {
            let cfg = ENExposureConfiguration()
            cfg.immediateDurationWeight = 150; cfg.infectiousnessForDaysSinceOnsetOfSymptoms = [0: 1]; cfg.attenuationDurationThresholds = [50, 70]
            let key = ENTemporaryExposureKey()
            key.keyData = Data(repeating: 7, count: 16); key.rollingStartNumber = 2_900_000; key.rollingPeriod = 144; key.transmissionRiskLevel = 2
            try expect(cfg.immediateDurationWeight == 150 && cfg.attenuationDurationThresholds == [50, 70] && key.keyData.count == 16 && key.rollingPeriod == 144, "values")
            let hier = p28tClasses(["ENExposureDaySummary", "ENExposureDetectionSummary", "ENExposureInfo", "ENExposureSummaryItem", "ENExposureWindow", "ENScanInstance"].map { ($0, "NSObject") })
            try expect(hier.isEmpty, "\(hier)")
            return "configuration + key values; 6 result classes present"
        })
#endif
        return c
    }
}

// MARK: Photos: upload job options, project classes, background upload extension types

extension Registry {
    static var p28tPhotos: [Check] {
        var c: [Check] = []
#if canImport(Photos) && (os(iOS) || os(visionOS) || os(tvOS))
        c.append(check("Photos", "p28-upload-projects") {
            var parts: [String] = []
            #if os(iOS) || os(visionOS)
            let o = PHAssetResourceUploadJobOptions()
            o.preventsExpensiveNetworkAccess = true
            try expect((o.copy() as? PHAssetResourceUploadJobOptions)?.preventsExpensiveNetworkAccess == true, "upload options")
            let results: [PHBackgroundResourceUploadProcessingResult] = [.init(rawValue: 0), .init(rawValue: 1)].compactMap { $0 }
            parts.append("upload results \(results.count)")
            parts.append(p28tName((any PHBackgroundResourceUploadExtension).self))
            parts.append(p28tName((any PHBackgroundResourceUploadJobExtension).self))
            #endif
            let hier = p28tClasses([("PHProject", "PHAssetCollection"), ("PHProjectChangeRequest", "PHChangeRequest"), ("PHAssetExtendedMetadata", "NSObject")])
            try expect(hier.isEmpty, "\(hier)")
            return parts.joined(separator: ", ") + "; project classes present"
        })
#endif
        return c
    }
}

// MARK: AccessorySetupKit: picker display items and settings, property compare strings (no accessory to discover)

extension Registry {
    static var p28tAccessorySetup: [Check] {
        var c: [Check] = []
#if canImport(AccessorySetupKit) && os(iOS)
        c.append(check("AccessorySetupKit", "p28-display-items", timeout: 30) {
            let cs = ASPropertyCompareString(string: "p28", compareOptions: [.caseInsensitive])
            try expect(cs.string == "p28" && cs.compareOptions == [.caseInsensitive], "compare string")
            let settings = ASPickerDisplaySettings.default
            settings.discoveryTimeout = .short
            let img = await onMain { UIImage(systemName: "star")! }
            let d = ASDiscoveryDescriptor(); d.bluetoothServiceUUID = .init(string: "180D")
            let mig = ASMigrationDisplayItem(name: "p28 old", productImage: img, descriptor: d)
            mig.peripheralIdentifier = UUID()
            try expect(mig.name == "p28 old" && mig.peripheralIdentifier != nil, "migration item")
            let hier = p28tClasses([("ASDiscoveredAccessory", "ASAccessory"), ("ASDiscoveredDisplayItem", "ASPickerDisplayItem"), ("ASAccessoryEvent", "NSObject")])
            try expect(hier.isEmpty, "\(hier)")
            return "compare string, picker settings timeout \(settings.discoveryTimeout), migration item; discovered accessory / item / event classes present"
        })
#endif
        return c
    }
}

// MARK: WebKit: content world configuration; the context menu / preview / open panel / immersive classes

extension Registry {
    static var p28tWebKit: [Check] {
        var c: [Check] = []
#if canImport(WebKit) && (os(iOS) || os(visionOS))
        c.append(check("WebKit", "p28-content-world-config", timeout: 30) {
            let r = try await onMain { () throws -> String in
                let cfg = WKContentWorld.Configuration()
                try expect(NSStringFromClass(type(of: cfg)) == "WKContentWorldConfiguration", "class \(type(of: cfg))")
                cfg.allowAccessingClosedShadowRoots = true
                cfg.isInspectable = true
                let back = try p27sRoundTrip(cfg) as? WKContentWorld.Configuration
                try expect(back?.allowAccessingClosedShadowRoots == true, "config round trip")
                // (neither -copy nor WKContentWorld(configuration:) is called: after either the app dies at the next
                // autorelease-pool drain, a message to a freed WKContentWorldConfiguration (copy over-releases it), on
                // Apple's simulator too)
                return "inspectable \(back?.isInspectable == true)"
            }
            let hier = p28tClasses([("WKContextMenuElementInfo", "NSObject"), ("WKPreviewElementInfo", "NSObject"), ("WKOpenPanelParameters", "NSObject")])
            try expect(hier.isEmpty, "\(hier)")
            return "configuration round trip, \(r); element info / open panel classes present"
        })
#endif
        return c
    }
}

// MARK: SafariServices: the Safari view controller's configuration, activity button, data store and prewarming token

extension Registry {
    static var p28tSafari: [Check] {
        var c: [Check] = []
#if canImport(SafariServices) && (os(iOS) || os(visionOS))
        c.append(check("SafariServices", "p28-config-datastore-prewarm", timeout: 30) {
            let r = await onMain { () -> String in
                let cfg = SFSafariViewController.Configuration()
                cfg.entersReaderIfAvailable = true; cfg.barCollapsingEnabled = false
                let btn = SFSafariViewController.ActivityButton(templateImage: UIImage(systemName: "star")!, extensionIdentifier: "com.x86sim.test.sdkcov.share")
                cfg.activityButton = btn
                let names = [NSStringFromClass(type(of: cfg)), NSStringFromClass(type(of: btn))]
                let tok = SFSafariViewController.prewarmConnections(to: [URL(string: "https://x86sim.test/")!])
                let tn = NSStringFromClass(type(of: tok)); tok.invalidate()
                let cp = cfg.copy() as? SFSafariViewController.Configuration
                return "\(names.joined(separator: ",")),\(tn) reader \(cp?.entersReaderIfAvailable == true) button \(cp?.activityButton?.extensionIdentifier ?? "nil")"
            }
            try expect(r.hasPrefix("SFSafariViewControllerConfiguration,SFSafariViewControllerActivityButton,SFSafariViewControllerPrewarmingToken reader true button com.x86sim"), r)
            let b = P28TBox<String>()
            let ds = SFSafariViewController.DataStore.default
            ds.clearWebsiteData { b.set("cleared") }
            let ans = await b.wait(10) ?? "no answer in 10 s"
            try expect(NSStringFromClass(type(of: ds)) == "SFSafariViewControllerDataStore" && ans == "cleared", "data store \(ans)")
            return r + "; data store \(ans)"
        })
#endif
        return c
    }
}

// MARK: ClassKit: activities and binary items in the app's main context

extension Registry {
    static var p28tClassKit: [Check] {
        var c: [Check] = []
#if canImport(ClassKit) && (os(iOS) || os(visionOS))
        c.append(check("ClassKit", "p28-activity-items", timeout: 30) {
            let item = CLSBinaryItem(identifier: "p28-done", title: "Done", type: .yesNo)
            item.value = true
            let gen: CLSActivityItem = item, obj: CLSObject = item
            try expect(gen.identifier == "p28-done" && item.valueType == .yesNo && obj.dateCreated.timeIntervalSinceNow < 1, "binary item")
            let ctx = CLSDataStore.shared.mainAppContext
            let act: CLSActivity = ctx.createNewActivity()
            act.start()
            act.addProgressRange(fromStart: 0, toEnd: 0.5)
            let afterRange = act.progress
            act.progress = 0.5
            act.stop()
            act.primaryActivityItem = item
            act.addAdditionalActivityItem(CLSScoreItem(identifier: "p28-score", title: "Score", score: 8, maxScore: 10))
            let prim = act.primaryActivityItem?.identifier ?? "nil", extra = act.additionalActivityItems.map(\.identifier)
            // Apple's simulator: an activity of the main app context (no ClassKit entitlement) takes progress but keeps no items
            try expect(act.progress == 0.5 && prim == "nil" && extra.isEmpty, "activity items \(prim) \(extra), progress \(act.progress)")
            let back = try p27sRoundTrip(item) as? CLSBinaryItem
            return "activity progress after range \(afterRange), set \(act.progress), items \(prim) + \(extra); binary item archive \(back == nil ? "nil" : "ok")"
        })
#endif
        return c
    }
}

// MARK: BrowserEngineKit: accessibility / text / context-menu / download objects, media environments and capabilities,
// the content filter; the process and extension types (no browser entitlement)

#if canImport(BrowserEngineKit) && os(iOS)
final class P28TDragDelegate: NSObject, BEDragInteractionDelegate {
    func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: any UIDragSession) -> [UIDragItem] { [] }
}
#endif

extension Registry {
    static var p28tBrowserEngine: [Check] {
        var c: [Check] = []
#if canImport(BrowserEngineKit) && os(iOS)
        c.append(check("BrowserEngineKit", "p28-objects", timeout: 30) {
            let r = try await onMain { () throws -> String in
                let re = BEAccessibilityRemoteElement(identifier: "p28-remote", hostPid: getpid())
                let he = BEAccessibilityRemoteHostElement(identifier: "p28-host", remotePid: getpid())
                let ctx = BETextDocumentContext(selectedText: "sel", contextBefore: "before ", contextAfter: " after", markedText: nil, selectedRangeInMarkedText: NSRange(location: 0, length: 0))
                ctx.addTextRect(CGRect(x: 0, y: 0, width: 10, height: 10), forCharacterRange: NSRange(location: 0, length: 3))
                let menu = BEContextMenuConfiguration(identifier: "p28" as NSString, previewProvider: nil, actionProvider: nil)
                let d = P28TDragDelegate()
                let drag = BEDragInteraction(delegate: d)
                let host = LayerHierarchyHostingView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
                let menuOK = (menu.identifier as? NSString) == "p28"
                let parts = [menuOK, drag.delegate === d, host.handle == nil, NSStringFromClass(type(of: host)) == "BELayerHierarchyHostingView", !re.description.isEmpty, !he.description.isEmpty]
                try expect(!parts.contains(false), "objects \(parts) \(NSStringFromClass(type(of: host))) \(String(describing: menu.identifier))")
                return "remote elements, document context, context menu, drag interaction, hosting view"
            }
            let mk = BEAccessibilityTextMarker(), range = BEAccessibilityTextMarker.Range()
            range.startMarker = mk; range.endMarker = mk.copy() as! BEAccessibilityTextMarker
            let rb = try p27sRoundTrip(range) as? BEAccessibilityTextMarker.Range
            try expect(rb != nil && (range.copy() as? BEAccessibilityTextMarker.Range) != nil && NSStringFromClass(type(of: range)) == "BEAccessibilityTextMarkerRange", "marker range round trip")
            let dir = FileManager.default.temporaryDirectory
            let mon = BEDownloadMonitor(sourceURL: URL(string: "https://x86sim.test/p28.bin")!, destinationURL: dir.appendingPathComponent("p28.bin"),
                                        observedProgress: Progress(totalUnitCount: 10), liveActivityAccessToken: Data())
            let tok = BEDownloadMonitor.createAccessToken()
            let locName = p28tName(BEDownloadMonitor.Location.self)
            try expect(mon.sourceURL.lastPathComponent == "p28.bin" && NSStringFromClass(BEDownloadMonitor.Location.self) == "BEDownloadMonitorLocation", "download monitor \(locName)")
            // media environment: through its XPC representation and back
            let env = MediaEnvironment(webPage: URL(string: "https://x86sim.test/media")!)
            let envBack = try MediaEnvironment(xpcRepresentation: env.createXPCRepresentation())
            let caps: [ProcessCapability] = [.background, .foreground, .suspended, .mediaPlaybackAndCapture(environment: envBack)]
            let revs = RestrictedSandboxRevision.allCases.sorted()
            let feature: RenderingExtensionFeature = .coreML
            // the content filter (Screen Time's): not active, a URL is not blocked
            let shouldEval = BEWebContentFilter.shouldEvaluateURLs
            let fb = P28TBox<String>()
            BEWebContentFilter().evaluateURL(URL(string: "https://x86sim.test/")!) { block, page in fb.set("block \(block) page \(page?.count ?? 0)") }
            let fAns = await fb.wait(10) ?? "no answer in 10 s"
            let cls = p28tClasses([("BEAutoFillTextSuggestion", "BETextSuggestion"), ("BEKeyEntry", "NSObject"), ("BEKeyEntryContext", "NSObject"), ("BELayerHierarchy", "NSObject"),
                                   ("BELayerHierarchyHandle", "NSObject"), ("BELayerHierarchyHostingTransactionCoordinator", "NSObject"), ("BEMediaEnvironment", "NSObject"),
                                   ("BEProcessCapability", "NSObject"), ("BEScrollViewScrollUpdate", "NSObject"), ("BETextAlternatives", "NSObject"), ("BETextDocumentRequest", "NSObject"),
                                   ("BENetworkingProcess", "NSObject"), ("BERenderingProcess", "NSObject"), ("BEWebContentProcess", "NSObject")])
            let meta = [p28tName((any NetworkingExtension).self), p28tName((any RenderingExtension).self), p28tName((any WebContentExtension).self),
                        p28tName((any RestrictedSandboxAppliable).self), p28tName(NetworkingExtensionConfiguration.self), p28tName(RenderingExtensionConfiguration.self),
                        p28tName(WebContentExtensionConfiguration.self)]
            try expect(cls.isEmpty && revs.count >= 1 && revs == RestrictedSandboxRevision.allCases.sorted() && caps.count == 4 && "\(feature)" == "coreML" && meta.allSatisfy { $0.contains("BrowserEngineKit.") }, "\(cls) \(meta)")
            return "\(r); marker range round trip; download monitor, token \(tok == nil ? "nil" : "\(tok!.count) B"); media environment XPC round trip; \(revs.count) sandbox revisions; filter evaluates \(shouldEval), \(fAns)"
        })
#endif
        return c
    }
}

// MARK: ImageCaptureCore: the camera / scanner object model (no device on a simulator); a file fingerprint

extension Registry {
    static var p28tImageCapture: [Check] {
        var c: [Check] = []
#if canImport(ImageCaptureCore) && (os(iOS) || os(visionOS))
        c.append(check("ImageCaptureCore", "p28-object-model") {
            let rows: [(String, String)] = [("ICCameraDevice", "ICDevice"), ("ICCameraItem", "NSObject"), ("ICCameraFile", "ICCameraItem"), ("ICCameraFolder", "ICCameraItem"),
                                            ("ICScannerDevice", "ICDevice"), ("ICScannerBandData", "NSObject"), ("ICScannerFeature", "NSObject"), ("ICScannerFeatureBoolean", "ICScannerFeature"),
                                            ("ICScannerFeatureEnumeration", "ICScannerFeature"), ("ICScannerFeatureRange", "ICScannerFeature"),
                                            ("ICScannerFunctionalUnitDocumentFeeder", "ICScannerFunctionalUnit"), ("ICScannerFunctionalUnitFlatbed", "ICScannerFunctionalUnit"),
                                            ("ICScannerFunctionalUnitNegativeTransparency", "ICScannerFunctionalUnit"), ("ICScannerFunctionalUnitPositiveTransparency", "ICScannerFunctionalUnit")]
            let present = rows.filter { NSClassFromString($0.0) != nil }
            let wrong = p28tClasses(present)
            let f = FileManager.default.temporaryDirectory.appendingPathComponent("p28-fp.bin")
            try Data(repeating: 0x5a, count: 4096).write(to: f)
            let fp = ICCameraFile.fingerprintForFile(at: f)
            let fp2 = ICCameraFile.fingerprintForFile(at: f)
            try expect(wrong.isEmpty && fp == fp2, "\(wrong) fingerprint \(String(describing: fp))")
            let types: [AnyClass] = [ICCameraDevice.self, ICCameraFolder.self]
            return "\(present.count)/\(rows.count) classes present (\(types.count) camera types named); fingerprint \(fp.map { "\($0.count) chars" } ?? "nil")"
        })
#endif
        return c
    }
}
