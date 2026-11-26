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
