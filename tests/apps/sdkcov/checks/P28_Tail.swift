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
#if canImport(EnergyKit) && os(iOS)
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

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if canImport(ContactProvider) && os(iOS)
import ContactProvider
import Contacts
#endif
#if canImport(HomeExtensions) && os(iOS)
import HomeExtensions
import HomeKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(AccessoryTransportExtension) && os(iOS)
import AccessoryTransportExtension
#endif
#if canImport(AccessoryLiveActivities) && os(iOS)
import AccessoryLiveActivities
#endif
#if canImport(LiveCommunicationKit) && !os(tvOS)
import LiveCommunicationKit
#endif
#if canImport(FinanceKitUI) && os(iOS)
import FinanceKitUI
#endif
#if canImport(IdentityDocumentServices) && os(iOS)
import IdentityDocumentServices
#endif
#if canImport(IdentityDocumentServicesUI) && os(iOS)
import IdentityDocumentServicesUI
#endif
#if canImport(ManagedApp) && (os(iOS) || os(visionOS))
import ManagedApp
#endif
#if canImport(MarketplaceKit) && os(iOS)
import MarketplaceKit
#endif
#if canImport(PermissionKit) && (os(iOS) || os(visionOS))
import PermissionKit
#endif
#if canImport(TabularData)
import TabularData
#endif
#if canImport(AppMigrationKit) && os(iOS)
import AppMigrationKit
#endif
#if canImport(AccessoryNotifications) && os(iOS)
import AccessoryNotifications
#endif
#if canImport(CarKey) && (os(iOS) || os(watchOS))
import CarKey
#endif
#if canImport(AlarmKit) && os(iOS)
import AlarmKit
#endif
#if canImport(SensorKit) && os(iOS)
import SensorKit
#endif
#if canImport(DeclaredAgeRange) && os(iOS)
import DeclaredAgeRange
#endif
#if canImport(DeviceDiscoveryUI) && os(iOS)
import DeviceDiscoveryUI
import DeviceDiscoveryExtension
#endif
#if canImport(TranslationUIProvider) && os(iOS)
import TranslationUIProvider
#endif
#if canImport(CloudKit)
import CloudKit
import CoreTransferable
#endif
#if canImport(HealthKit) && !os(tvOS)
import HealthKit
#endif
#if canImport(ImagePlayground)
import ImagePlayground
#endif
#if canImport(LockedCameraCapture) && (os(iOS) || os(visionOS))
import LockedCameraCapture
#endif
#if canImport(TrustInsights) && os(iOS)
import TrustInsights
#endif
#if canImport(VisionKit) && (os(iOS) || os(visionOS))
import VisionKit
#endif
#if canImport(MusicKit)
import MusicKit
#endif
#if canImport(Combine)
import Combine
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(JavaScriptCore)
import JavaScriptCore
#endif
#if canImport(MultipeerConnectivity)
import MultipeerConnectivity
#endif
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif
#if canImport(Social) && os(iOS)
import Social
#endif
#if canImport(Accounts) && os(iOS)
import Accounts
#endif
#if canImport(AddressBookUI) && os(iOS)
import AddressBookUI
#endif
#if canImport(CoreBluetooth)
import CoreBluetooth
#endif
#if canImport(SharedWithYou)
import SharedWithYou
#endif
#if canImport(PencilKit)
import PencilKit
#endif
#if canImport(PushToTalk) && os(iOS)
import PushToTalk
#endif
#if canImport(ScreenTime) && os(iOS)
import ScreenTime
#endif
#if canImport(SecurityUI)
import SecurityUI
#endif
#if canImport(StateReporting)
import StateReporting
#endif
#if canImport(OpenGLES)
import OpenGLES
#endif
#if canImport(MetalPerformanceShadersGraph)
import MetalPerformanceShadersGraph
#endif
#if canImport(ClockKit)
import ClockKit
#endif
#if canImport(ClockKit) && os(watchOS)
import AppIntents
#endif
#if canImport(TVMLKit) && os(tvOS)
import TVMLKit
import AVFoundation
#endif
#if canImport(TVUIKit) && os(tvOS)
import TVUIKit
#endif
#if canImport(TVServices) && os(tvOS)
import TVServices
#endif
#if canImport(WatchKit) && os(watchOS)
import WatchKit
#endif
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif
#if canImport(QuickLook) && os(visionOS)
import QuickLook
#endif
#if canImport(WebKit) && os(visionOS)
import WebKit
#endif
#if canImport(CompositorServices) && os(visionOS)
import CompositorServices
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
        c += p28tAuthServices + p28tContactProvider + p28tHomeExtensions + p28tAccessoryTransport + p28tLiveComm + p28tFinanceUI + p28tIdentityDocs + p28tManagedApp
        c += p28tMarketplace + p28tPermissionKit + p28tTabular + p28tSmallIOS + p28tLeftovers + p28tObjCLeftovers
        c += p28tTV + p28tWatch + p28tVision
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
#if canImport(EnergyKit) && os(iOS)
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
#if canImport(CallKit) && os(iOS)
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
#if canImport(NearbyInteraction) && os(iOS)
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
            var vsRows = [("VSAccountProviderResponse", "NSObject"), ("VSAutoSignInToken", "NSObject"), ("VSAppleSubscription", "NSObject")]
#if !os(visionOS)
            vsRows.append(("VSAutoSignInTokenUpdateContext", "NSObject"))   // not in Apple's visionOS runtime
#endif
            let hier = p28tClasses(vsRows)
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
            #if os(iOS)
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
#if canImport(SafariServices) && os(iOS)
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
                // identifier comes back nil although Swift imports it non-optional: read through KVC (touching it in Swift faults)
                let mid = menu.value(forKey: "identifier") as? NSString
                let box = UIView(); he.accessibilityContainer = box
                let parts = [drag.delegate === d, NSStringFromClass(type(of: host)) == "BELayerHierarchyHostingView", NSStringFromClass(type(of: re)) == "BEAccessibilityRemoteElement"]
                let seen = "menu identifier \(mid.map { "\($0)" } ?? "nil"), host container kept \(he.accessibilityContainer != nil)"
                try expect(!parts.contains(false), "objects \(parts)")
                return "remote elements, document context, context menu (\(seen)), drag interaction, hosting view"
            }
            // BEAccessibilityTextMarker(Range) are abstract: a browser subclasses them; constructing the base class faults
            // the app (x86Sim and Apple's simulator alike)
            final class P28TMarker: BEAccessibilityTextMarker {}
            let markerOK = NSStringFromClass(BEAccessibilityTextMarker.Range.self) == "BEAccessibilityTextMarkerRange" && P28TMarker.superclass() == BEAccessibilityTextMarker.self
            try expect(markerOK, "marker classes")
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
            return "\(r); marker classes; download monitor, token \(tok == nil ? "nil" : "\(tok!.count) B"); media environment XPC round trip; \(revs.count) sandbox revisions; filter evaluates \(shouldEval), \(fAns)"
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

// MARK: - P28 tail, part 2: the remaining 1-12-type frameworks (apisurf.py after wave 1 + the earlier tail checks)

/// classes that exist only on other platforms (macOS / another OS): present in this runtime's binaries or not, as on Apple
func p28tPresent(_ names: [String]) -> (present: [String], missing: [String]) {
    (names.filter { NSClassFromString($0) != nil }, names.filter { NSClassFromString($0) == nil })
}

// MARK: AuthenticationServices: passkey extension outputs, large blob / PRF inputs, the web browser providers,
// account creation requests, settings helper; macOS-only web authentication session classes

#if canImport(AuthenticationServices) && os(iOS)
final class P28TWebBrowserProviders {
    /// the web browser protocols, used as a browser app does: through the platform / security key providers
    func make(_ cd: ASPublicKeyCredentialClientData) -> (ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest, ASAuthorizationSecurityKeyPublicKeyCredentialAssertionRequest) {
        let p: any ASAuthorizationWebBrowserPlatformPublicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: "example.com")
        let s: any ASAuthorizationWebBrowserSecurityKeyPublicKeyCredentialProvider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: "example.com")
        return (p.createCredentialRegistrationRequest(clientData: cd, name: "p28", userID: Data("u".utf8)), s.createCredentialAssertionRequest(clientData: cd))
    }
}
#endif

extension Registry {
    static var p28tAuthServices: [Check] {
        var c: [Check] = []
#if canImport(AuthenticationServices) && (os(iOS) || os(visionOS))
        c.append(check("AuthenticationServices", "p28-passkey-outputs-browser", timeout: 30) {
            let chal = Data(repeating: 3, count: 32), uid = Data("p28".utf8), cid = Data([5, 6, 7])
            // large blob / PRF inputs on an assertion request
            let rd = ASAuthorizationPublicKeyCredentialLargeBlobAssertionInput.read, wr = ASAuthorizationPublicKeyCredentialLargeBlobAssertionInput.write(Data("blob".utf8))
            var ops = 0
            if case .read = rd.operation { ops += 1 }
            if case .write(let d) = wr.operation, d.count == 4 { ops += 1 }
            let salts = ASAuthorizationPublicKeyCredentialPRFAssertionInput.InputValues.saltInput1(Data(repeating: 1, count: 32), saltInput2: Data(repeating: 2, count: 32))
            let prf = ASAuthorizationPublicKeyCredentialPRFAssertionInput.inputValues(salts, perCredentialInputValues: [cid: salts])
            try expect(ops == 2 && prf.inputValues != nil && NSClassFromString("ASAuthorizationPublicKeyCredentialPRFAssertionInputValues") != nil
                       && NSClassFromString("ASAuthorizationPublicKeyCredentialLargeBlobAssertionInput") != nil, "inputs ops \(ops)")
            // what a passkey provider extension returns: credentials with extension outputs
            let aOut = ASPasskeyAssertionCredentialExtensionOutput(largeBlob: .read(data: Data("blob".utf8)), prf: nil)
            let rOut = ASPasskeyRegistrationCredentialExtensionOutput(largeBlob: .supported, prf: nil)
            let ac = ASPasskeyAssertionCredential(userHandle: uid, relyingParty: "example.com", signature: Data([1]), clientDataHash: Data(count: 32), authenticatorData: Data([2]), credentialID: cid, extensionOutput: aOut)
            let rc = ASPasskeyRegistrationCredential(relyingParty: "example.com", clientDataHash: Data(count: 32), credentialID: cid, attestationObject: Data([0xa0]), extensionOutput: rOut)
            let acb = try p28tArchive(ac) as? ASPasskeyAssertionCredential, rcb = try p28tArchive(rc) as? ASPasskeyRegistrationCredential
            var largeRead = "none"
            if case .read(let d)? = acb?.extensionOutput?.largeBlob?.result { largeRead = "\(d?.count ?? -1) B" }
            try expect(ac.extensionOutput?.largeBlob != nil && rc.extensionOutput?.largeBlob != nil && acb != nil && rcb != nil
                       && NSClassFromString("ASPasskeyAssertionCredentialExtensionOutput") != nil && NSClassFromString("ASPasskeyRegistrationCredentialExtensionOutput") != nil,
                       "extension outputs \(largeRead)")
            // account creation request (iOS 26): Codable, an ASAuthorizationRequest
            let acct: ASAuthorizationAccountCreationPlatformPublicKeyCredentialRequest = ASAuthorizationAccountCreationProvider().createPlatformPublicKeyCredentialRegistrationRequest(
                acceptedContactIdentifiers: [.email], shouldRequestName: false, relyingPartyIdentifier: "example.com", challenge: chal, userID: uid)
            // its Decodable init raises "-[... init]: unrecognized selector" (Apple's own conformance calls the unavailable
            // -[ASAuthorizationRequest init]): only the encoding is used
            let acctJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(acct)) as? [String: Any] ?? [:]
            try expect(acct.relyingPartyIdentifier == "example.com" && acct.challenge == chal && acct.userID == uid && !acct.shouldRequestName && acctJSON["relyingPartyIdentifier"] as? String == "example.com",
                       "account creation JSON keys \(acctJSON.keys.sorted())")
            var browser = "visionOS: no web browser providers"
#if os(iOS)
            let cd = ASPublicKeyCredentialClientData(challenge: chal, origin: "https://example.com", crossOrigin: .sameOriginWithAncestors)
            let (preg, sast) = P28TWebBrowserProviders().make(cd)
            try expect(preg.name == "p28" && preg.relyingPartyIdentifier == "example.com" && sast.relyingPartyIdentifier == "example.com", "web browser providers")
            let mgr = ASAuthorizationWebBrowserPublicKeyCredentialManager()
            let creds = await p27sAnswer(10) { () async throws -> String in
                let l: [ASAuthorizationWebBrowserPlatformPublicKeyCredential] = await ASAuthorizationWebBrowserPublicKeyCredentialManager().platformCredentials(forRelyingParty: "example.com")
                return "\(l.count) platform credentials"
            }
            browser = "browser manager state \(mgr.authorizationStateForPlatformCredentials.rawValue), configured for passkeys \(ASAuthorizationWebBrowserPublicKeyCredentialManager.isDeviceConfiguredForPasskeys), \(creds)"
#endif
            // settings helper: no AutoFill provider extension in this app -> an error
            let sh = P28TBox<String>()
            ASSettingsHelper.openCredentialProviderAppSettings { e in sh.set(e.map { "\(($0 as NSError).domain) \(($0 as NSError).code)" } ?? "ok") }
            let shAns = await sh.wait(10) ?? "no answer"
            let mac = p28tPresent(["ASWebAuthenticationSessionRequest", "ASWebAuthenticationSessionWebBrowserSessionManager"])
            return "large blob / PRF inputs; extension outputs round trip (read \(largeRead)); account creation JSON keys \(acctJSON.keys.sorted()); \(browser); settings helper: \(shAns); macOS-only classes present \(mac.present.count)/2"
        })
#elseif canImport(AuthenticationServices) && (os(tvOS) || os(watchOS))
        c.append(check("AuthenticationServices", "p28-unavailable-classes") {
            // passkey / browser / web authentication session classes are API_UNAVAILABLE here: which ship in the runtime
            let names = ["ASAuthorizationPublicKeyCredentialLargeBlobAssertionInput", "ASAuthorizationWebBrowserPlatformPublicKeyCredential", "ASAuthorizationWebBrowserPublicKeyCredentialManager",
                         "ASWebAuthenticationSessionRequest", "ASWebAuthenticationSessionWebBrowserSessionManager"]
            let r = p28tPresent(names)
            return "present \(r.present.count)/\(names.count)\(p28tFirst(r.present))"
        })
#endif
        return c
    }
}

// MARK: ContactProvider: an extension's enumerator driven the way the system drives it (content pages, change
// batches into observers), pages / sync anchors, the default domain, errors

#if canImport(ContactProvider) && os(iOS)
final class P28TContactObserver: ContactItemContentObserver, ContactItemChangeObserver, @unchecked Sendable {
    var items: [ContactItem] = [], deleted: [ContactItem.Identifier] = [], next: ContactItemPage?, marker: Data?, anchor: ContactItemSyncAnchor?, more = true, errors = 0
    func didEnumerate(_ i: [ContactItem]) { items += i }
    func didFinishEnumeratingPage(upTo nextPage: ContactItemPage) { next = nextPage }
    func didFinishEnumeratingContent(upTo generationMarker: Data) { marker = generationMarker }
    func didFinishEnumeratingContentWithError(_: any Error) { errors += 1 }
    var suggestedPageSize: Int { 2 }
    func didUpdate(_ i: [ContactItem]) { items += i }
    func didDelete(_ ids: [ContactItem.Identifier]) { deleted += ids }
    func didFinishEnumeratingChanges(upTo syncAnchor: ContactItemSyncAnchor, moreComing: Bool) { anchor = syncAnchor; more = moreComing }
    func didFinishEnumeratingChangesWithError(_: any Error) { errors += 1 }
    var suggestedBatchSize: Int { 10 }
}
final class P28TContactEnumerator: ContactItemEnumerator, @unchecked Sendable {
    let all: [ContactItem]
    init(_ names: [String]) {
        all = names.map { n in let c = CNMutableContact(); c.givenName = n; return .contact(c, ContactItem.Identifier("p28-" + n)) }
    }
    func enumerateContent(in page: ContactItemPage, for observer: any ContactItemContentObserver) async {
        let end = min(page.offset + observer.suggestedPageSize, all.count)
        observer.didEnumerate(Array(all[page.offset..<end]))
        if end < all.count { observer.didFinishEnumeratingPage(upTo: ContactItemPage(generationMarker: page.generationMarker, offset: end)) }
        else { observer.didFinishEnumeratingContent(upTo: Data("gen-1".utf8)) }
    }
    func enumerateChanges(startingAt syncAnchor: ContactItemSyncAnchor, for observer: any ContactItemChangeObserver) async {
        observer.didUpdate([all[0]]); observer.didDelete([ContactItem.Identifier("p28-gone")])
        observer.didFinishEnumeratingChanges(upTo: ContactItemSyncAnchor(generationMarker: Data("gen-2".utf8), offset: syncAnchor.offset + 1), moreComing: false)
    }
    func invalidate() async {}
}
struct P28TContactExtension: ContactProviderExtension {
    func configure(for domain: any ContactProviderDomain) {}
    func invalidate() async throws {}
    func enumerator(for collection: ContactItem.Identifier) -> any ContactItemEnumerator { P28TContactEnumerator(["Ann", "Bob", "Cy"]) }
}
#endif

extension Registry {
    static var p28tContactProvider: [Check] {
        var c: [Check] = []
#if canImport(ContactProvider) && os(iOS)
        c.append(check("ContactProvider", "p28-enumeration-model") {
            let ext: any ContactItemEnumerating = P28TContactExtension()
            let en = ext.enumerator(for: .rootContainer)
            let obs = P28TContactObserver()
            var page = ContactItemPage.initialPage, pages = 0
            while pages < 5 {
                obs.next = nil
                await en.enumerateContent(in: page, for: obs); pages += 1
                guard let n = obs.next else { break }
                page = n
            }
            await en.enumerateChanges(startingAt: ContactItemSyncAnchor(generationMarker: Data("gen-1".utf8), offset: 0), for: obs)
            await en.invalidate()
            let names = obs.items.compactMap { if case .contact(let c, _) = $0 { return c.givenName } else { return nil } }
            try expect(pages == 2 && names == ["Ann", "Bob", "Cy", "Ann"] && obs.marker == Data("gen-1".utf8) && obs.deleted == [ContactItem.Identifier("p28-gone")]
                       && obs.anchor?.offset == 1 && !obs.more && obs.errors == 0, "pages \(pages) \(names) anchor \(String(describing: obs.anchor))")
            let pb = try p28tRoundTrip(ContactItemPage(generationMarker: Data([1]), offset: 7)), ab = try p28tRoundTrip(ContactItemSyncAnchor(generationMarker: Data([2]), offset: 3))
            try expect(pb.offset == 7 && ab.offset == 3 && Set(obs.items).count == 3, "page / anchor JSON")
            let dom = DefaultContactProviderDomain()
            let errs: [ContactProviderError] = [.extensionNotFound, .itemsLimitReached, .pageExpired, .domainNotRegistered, .deniedByUser]
            let codes = errs.map { ($0 as NSError).code }
            var mgr = "no manager"
            do { let m = try ContactProviderManager(domainIdentifier: DefaultContactProviderDomain.identifier); mgr = "manager domain \(m.domain.identifier), enabled \(m.isEnabled)" }
            catch { mgr = "manager: \(error)" }
            try expect(dom.identifier == DefaultContactProviderDomain.identifier && Set(codes).count == errs.count && errs.allSatisfy { $0.errorDescription != nil }, "domain \(dom.identifier) codes \(codes)")
            return "\(pages) pages, \(obs.items.count) items, 1 change batch; page / anchor JSON; default domain \(dom.identifier) '\(dom.displayName)'; error codes \(codes); \(mgr)"
        })
#endif
        return c
    }
}

// MARK: HomeExtensions: a settings provider with its container / context, enum and range settings, the content
// scenes (configuration, help guide, settings)

#if canImport(HomeExtensions) && os(iOS)
enum P28THomeMode: String, HomeAccessoryEnumSettingConstant {
    case eco, comfort
    var value: HomeAccessorySettingLabel { HomeAccessorySettingLabel(stringLiteral: rawValue.capitalized) }
}
struct P28THomeContext: HomeAccessorySettingsContext { let room: String }
@MainActor struct P28THomeContainer: HomeAccessorySettingsContainer {
    let mode = HomeAccessoryEnumSetting<P28THomeMode>(id: "mode", label: "Mode", defaultValue: .eco, currentValue: .comfort, style: .navigation)
    let level = HomeAccessoryRangeSetting<Double>(id: "level", label: "Level", range: 0.0...10.0, currentValue: 4, step: 0.5)
    var availableSettings: [any HomeAccessorySetting] { [mode, level] }
}
@MainActor struct P28THomeProvider: HomeAccessorySettingsProvider {
    func settings(context: P28THomeContext, for accessory: HMAccessory) async throws -> AnyHomeAccessorySettingsContainer { AnyHomeAccessorySettingsContainer(erasing: P28THomeContainer()) }
    func settingsDidChange(changes: [String: Any], context: P28THomeContext, for accessory: HMAccessory) async throws {}
}
#endif

extension Registry {
    static var p28tHomeExtensions: [Check] {
        var c: [Check] = []
#if canImport(HomeExtensions) && os(iOS)
        c.append(check("HomeExtensions", "p28-settings-provider-scenes") {
            try await onMain { () throws -> String in
                let any = AnyHomeAccessorySettingsContainer(erasing: P28THomeContainer())
                let ids = any.availableSettings.map(\.id)
                let raw = P28THomeContainer()
                let range: any HomeAccessoryRangeSettingDescriptor<Double> = 0.0...10.0
                try expect(ids == ["mode", "level"] && raw.mode.wrappedValue == .comfort && raw.level.wrappedValue == 4 && range.rangeUpperBound == 10 && range.rangeLowerBound == 0
                           && P28THomeMode.allCases.map(\.value.label.key) == ["Eco", "Comfort"], "settings \(ids)")
                let ctx = P28THomeContext(room: "p28")
                let settings = HomeAccessorySettings(context: { ctx }, provider: { P28THomeProvider() })
                let conf = HomeAccessoryConfiguration(id: "p28.config", content: { Text("config") }).hidesNavigationTitleInLandscape()
                let guide = HomeAccessoryHelpGuide(id: "p28.help", content: { Text("help") }).contactAccessoryManufacturerLink()
                let contents: [any HomeContent] = [settings, conf, guide]
                return "provider container \(ids), enum + range settings; \(contents.count) content scenes"
            }
        })
#endif
        return c
    }
}

// MARK: AccessoryTransportExtension: security messages through an event handler, transports, session errors; the
// security extension / feature session protocols conformed as an extension does

#if canImport(AccessoryTransportExtension) && os(iOS)
final class P28TSecurityHandler: AccessorySecuritySession.EventHandler, @unchecked Sendable {
    var got: [String] = [], invalidated: AccessorySecuritySession.Error?
    func messageReceived(_ message: SecurityMessage, completion: @escaping @Sendable (AccessoryMessage.Result) -> Void) {
        got.append("\(message.keyType.rawValue)/\(message.cipherSuite)/\(message.key.count)")
        completion(message.key.isEmpty ? .failure(.transportFailed) : .success)
    }
    func sessionInvalidated(error: AccessorySecuritySession.Error?) { invalidated = error }
}
struct P28TTransportSecurity: AccessoryTransportSecurity {
    func accept(sessionRequest: AccessorySecuritySession.Request) -> AccessorySecuritySession.Request.Decision {
        sessionRequest.accept { P28TSecurityHandler() }
    }
}
struct P28TFeatureSession: AccessoryFeatureSession {
    let sessionID = UUID()
    func send(message: AccessoryMessage) async throws {}
}
#endif

extension Registry {
    static var p28tAccessoryTransport: [Check] {
        var c: [Check] = []
#if canImport(AccessoryTransportExtension) && os(iOS)
        c.append(check("AccessoryTransportExtension", "p28-security-messages") {
            let transports: [AccessoryTransport] = [.bluetooth, .internet, .localNetwork]
            let m1 = SecurityMessage(keyType: .publicKey, cipherSuite: .p256, version: .version1, key: Data(repeating: 4, count: 65), supportedTransports: transports, identifier: "p28")
            let m2 = SecurityMessage(keyType: .encapsulatedKey, cipherSuite: .xWing, version: .version1, key: Data())
            let h = P28TSecurityHandler()
            let results = P28TBox<[String]>(); var r: [String] = []
            for m in [m1, m2] {
                let b = P28TBox<String>()
                h.messageReceived(m) { res in if case .success = res { b.set("ok") } else { b.set("failed") } }
                r.append(await b.wait(2) ?? "none")
            }
            results.set(r)
            h.sessionInvalidated(error: .invalidated)
            let errs: [AccessorySecuritySession.Error] = [.unknown, .invalidated, .unsupported]
            let fs = P28TFeatureSession()
            try await fs.send(message: AccessoryMessage { AccessoryMessage.Payload(transport: .internet, data: Data([1])) })
            let meta = [p28tName(P28TTransportSecurity.self), p28tName((any AccessoryFeature).self), p28tName((any AccessoryTransportSecurityConfiguration).self),
                        p28tName((any AccessoryTransportExtensionConfiguration).self), p28tName((any AccessoryDataProviderConfiguration).self), p28tName(AccessorySecuritySession.self)]
            try expect(r == ["ok", "failed"] && h.got.map { $0.lowercased() } == ["publickey/p256/65", "encapsulatedkey/xwing/0"] && h.invalidated == .invalidated && m1.supportedTransports.count == 3
                       && m2.supportedTransports == [.bluetooth] && m1.identifier == "p28" && !m1.description.isEmpty && Set(errs.map(\.description)).count == 3
                       && meta.allSatisfy { $0.contains("AccessoryTransportExtension.") || $0.contains("sdkcov.") }, "\(r) \(h.got) \(meta)")
            return "messages \(h.got) -> \(r); invalidated \(h.invalidated!); errors \(errs.map(\.description)); feature session send ok; \(meta.count) protocol types"
        })
#endif
        return c
    }
}

// MARK: LiveCommunicationKit: cellular conversation actions / services (Codable), Live Assistance values and the
// extension protocol

#if canImport(LiveCommunicationKit) && (os(iOS) || os(visionOS))
@available(iOS 27.2, visionOS 27.2, *)
@MainActor struct P28TLiveAssistance: LiveAssistanceExtension {
    func prepareAssistanceRequest(_ request: LiveAssistanceRequest) async throws -> LiveAssistanceRequest.Response { request.url.scheme == "https" ? .proceed : .requiresUserInput(reason: .signIn) }
    func resumeRequest(_ request: LiveAssistanceRequest) async throws -> LiveAssistanceRequest.Response { .proceed }
}
#endif

extension Registry {
    static var p28tLiveComm: [Check] {
        var c: [Check] = []
#if canImport(LiveCommunicationKit) && os(iOS)
        c.append(check("LiveCommunicationKit", "p28-cellular-assistance") {
            let svcID = UUID()
            let svcJSON = "{\"id\":\"\(svcID.uuidString)\",\"label\":\"Primary\"}"
            let svc = try JSONDecoder().decode(CellularService.self, from: Data(svcJSON.utf8))
            let act = StartCellularConversationAction(Handle(type: .phoneNumber, value: "+15555550123", displayName: "P28"), cellularService: svc)
            let back = try p28tRoundTrip(act)
            let plain = StartCellularConversationAction(Handle(type: .phoneNumber, value: "+15555550123"))
            try expect(svc.id == svcID && svc.label == "Primary" && back == act && plain != act && (try p28tRoundTrip(svc)) == svc, "cellular action / service")
            var extra = ""
#if os(iOS) || os(visionOS)
            if #available(iOS 27.2, visionOS 27.2, *) {
                let reasons: [LiveAssistanceLaunchReason] = [.signIn, .additionalInfo]
                let errs: [LiveAssistanceRequestError] = [.cannotFulfill(message: nil), .unknown(message: "p28")]
                let keys = [LiveAssistance.extensionPointName, LiveAssistance.containerAppLaunchActivityType, LiveAssistance.containerAppLaunchRequestIDKey, LiveAssistance.containerAppLaunchReasonKey]
                let meta = [p28tName(LiveAssistanceRequest.self), p28tName((any LiveAssistanceExtensionConfiguration).self), p28tName(P28TLiveAssistance.self)]
                try expect(reasons.map(\.rawValue) == ["signIn", "additionalInfo"] && errs.count == 2 && keys.allSatisfy { !$0.isEmpty } && meta[0].hasPrefix("LiveCommunicationKit."), "\(keys) \(meta)")
                extra = "; assistance keys \(keys); reasons \(reasons.map(\.rawValue))"
            } else { extra = "; Live Assistance needs 27.2" }
#endif
            return "service '\(svc.label)', conversation action JSON round trip\(extra)"
        })
#endif
        return c
    }
}

// MARK: FinanceKitUI: wallet order button styles, the financial connection extension (provider, scene, results)

#if canImport(FinanceKitUI) && os(iOS)
final class P28TFinanceProvider: FinancialConnectionUIExtensionProviding {
    var calls = 0
    func authorize(_ request: FinancialConnectionExtensionAuthorizationRequest) { calls += 1; request.complete(authorizationResult: FinancialConnectionExtensionAuthorizationResult(params: request.params)) }
}
#endif

extension Registry {
    static var p28tFinanceUI: [Check] {
        var c: [Check] = []
#if canImport(FinanceKitUI) && os(iOS)
        c.append(check("FinanceKitUI", "p28-connection-extension-values") {
            let res = FinancialConnectionExtensionAuthorizationResult(params: ["token": "p28", "state": "ok"])
            let back = try p28tRoundTrip(res)
            let styles: [AddOrderToWalletButtonStyle] = [.black, .blackOutline]
            let scene = await MainActor.run { FinancialConnectionUIExtensionAuthorizationScene { Text("authorize") } }
            let sceneName = p28tName(type(of: scene))
            let meta = [p28tName(FinancialConnectionExtensionAuthorizationRequest.self), p28tName((any FinancialConnectionUIExtension).self), p28tName((any FinancialConnectionUIExtensionScene).self)]
            _ = P28TFinanceProvider()
            try expect(back.params == ["token": "p28", "state": "ok"] && styles.count == 2 && sceneName.contains("FinancialConnectionUIExtensionAuthorizationScene") && meta.allSatisfy { $0.hasPrefix("FinanceKitUI.") }, "\(back.params) \(sceneName)")
            return "authorization result JSON \(back.params.count) params; 2 button styles; \(sceneName.components(separatedBy: "<").first!) scene"
        })
#endif
        return c
    }
}

// MARK: IdentityDocumentServices(UI): web presentment raw requests / mobile document responses, presentment error
// codes, the registration protocol; the document provider scene builder and presentment controller delegate

#if canImport(IdentityDocumentServices) && os(iOS)
struct P28TDocRegistration: IdentityDocumentRegistration { let documentIdentifier: String }
#endif
#if canImport(IdentityDocumentServicesUI) && os(iOS)
@MainActor final class P28TDocDelegate: IdentityDocumentWebPresentmentControllerDelegate {
    func rawRequestsForWebPresentmentController(_ webPresentmentController: IdentityDocumentWebPresentmentController) async -> [IdentityDocumentWebPresentmentRawRequest] {
        [IdentityDocumentWebPresentmentRawRequest(requestType: .iso18013MobileDocument, requestData: Data([0xa0]))]
    }
}
#endif

extension Registry {
    static var p28tIdentityDocs: [Check] {
        var c: [Check] = []
#if canImport(IdentityDocumentServices) && os(iOS)
        c.append(check("IdentityDocumentServices", "p28-web-presentment-values") {
            let raw = IdentityDocumentWebPresentmentRawRequest(requestType: .iso18013MobileDocument, requestData: Data([0xa1, 0x01]))
            let resp: any IdentityDocumentWebPresentmentResponse = ISO18013MobileDocumentResponse(responseData: Data([0xa0]))
            let req: any IdentityDocumentWebPresentmentRequest = ISO18013MobileDocumentRequest(presentmentRequests: [], requestAuthentications: [])
            let reg: any IdentityDocumentRegistration = P28TDocRegistration(documentIdentifier: "p28-doc")
            let codes: [IdentityDocumentPresentmentError.Code] = [.unknown, .invalidRequest, .requestInProgress, .cancelled, .notEntitled]
            let statics = [IdentityDocumentPresentmentError.unknown, .invalidRequest, .requestInProgress, .cancelled, .notEntitled]
            try expect(raw.requestType == .iso18013MobileDocument && raw.requestData.count == 2 && (resp as? ISO18013MobileDocumentResponse)?.responseData == Data([0xa0])
                       && req is ISO18013MobileDocumentRequest && reg.documentIdentifier == "p28-doc" && codes == statics && codes.map(\.rawValue) == [0, 1, 2, 3, 4]
                       && !(IdentityDocumentPresentmentError.Code.cancelled ~= Fail("x")), "values")
            var ui = ""
#if canImport(IdentityDocumentServicesUI)
            ui = try await onMain { () throws -> String in
                let ctl = IdentityDocumentWebPresentmentController()
                let d = P28TDocDelegate(); ctl.delegate = d
                let scene = IdentityDocumentRequestSceneBuilder.buildBlock(ISO18013MobileDocumentRequestScene { (ctx: ISO18013MobileDocumentRequestContext) in Text(ctx.requestingWebsiteOrigin?.host ?? "app") })
                let meta = [p28tName((any IdentityDocumentProvider).self), p28tName((any IdentityDocumentRequestScene).self), p28tName(type(of: scene))]
                try expect(ctl.delegate === d && meta[0].hasPrefix("IdentityDocumentServicesUI."), "\(meta)")
                return "; presentment controller with delegate, request scene built (\(meta[2].prefix(40)))"
            }
#endif
            return "raw request, mobile document response / request, registration, error codes \(codes.map(\.rawValue))\(ui)"
        })
#endif
        return c
    }
}

// MARK: ManagedApp: passwords / certificates / identities providers of an unmanaged app, error values,
// configuration decoding error codes

#if canImport(ManagedApp) && (os(iOS) || os(visionOS))
struct P28TManagedDecodingError: ManagedAppConfigurationDecodingError {
    var code: ManagedAppConfigurationDecodingErrorCode
    var message: String
}
#endif

extension Registry {
    static var p28tManagedApp: [Check] {
        var c: [Check] = []
#if canImport(ManagedApp) && (os(iOS) || os(visionOS))
        c.append(check("ManagedApp", "p28-providers-unmanaged", timeout: 40) {
            // the passwords / certificates / identities providers are not called: on Apple's simulator the app stalls in
            // them (no answer and the check never ends; x86Sim: no answer in 5 s each), so only their types
            let provs = [p28tName(ManagedAppPasswordsProvider.self), p28tName(ManagedAppCertificatesProvider.self), p28tName(ManagedAppIdentitiesProvider.self)]
            let lookups = provs
            // which raw values the code type accepts: the reserved range vs app-defined codes
            typealias Code = ManagedAppConfigurationDecodingErrorCode
            let raws = [Code.generic, Code.dataCorrupted, Code.keyNotFound, Code.typeMismatch, Code.valueNotFound, Code.timeout, Code.firstReserved, Code.firstReserved + 1, 7]
            let accepted = raws.filter { Code(rawValue: $0) != nil }
            guard let code = accepted.last.flatMap({ Code(rawValue: $0) }) else { throw Fail("no raw value accepted of \(raws)") }
            let err = P28TManagedDecodingError(code: code, message: "missing key")
            let eb = try p28tRoundTrip(err.code)
            let errs: [ManagedAppError] = [.invalidIdentifier, .serverError, .internalError]
            try expect(eb == code && Set(errs).count == 3 && lookups.count == 3 && accepted == [7], "accepted \(accepted) (Apple's simulator: only the app-defined 7)")
            return "providers \(provs.map { $0.replacingOccurrences(of: "ManagedApp.", with: "") }); codes accepted \(accepted) of \(raws)"
        })
#endif
        return c
    }
}

// MARK: MarketplaceKit: automatic updates, errors (Codable), transaction reporting tokens; the marketplace extension
// protocols as an alternative marketplace implements them

#if canImport(MarketplaceKit) && os(iOS)
struct P28TMarketplace: MarketplaceExtension {
    func additionalHeaders(for request: URLRequest, account: String) -> [String: String]? { ["X-P28-Account": account] }
    func availableAppVersions(forAppleItemIDs ids: [AppleItemID]) -> [AppVersion]? { ids.map { AppVersion(appleItemID: $0, appleVersionID: 7) } }
    func requestFailed(with response: HTTPURLResponse) -> Bool { response.statusCode == 401 }
    func automaticUpdates(for installedAppVersions: [AppVersion]) async throws -> [AutomaticUpdate] {
        installedAppVersions.map { AutomaticUpdate(appleItemID: $0.appleItemID, alternativeDistributionPackage: URL(string: "https://x86sim.test/adp/\($0.appleItemID)")!, account: "p28", installVerificationToken: "tok") }
    }
}
struct P28TMarketplaceApp: MarketplaceAppExtension {
    func additionalHeaders(for request: URLRequest, account: String) async -> [String: String] { [:] }
    func automaticUpdates(for installedAppVersions: [AppVersion]) async throws -> [AutomaticUpdate] { [] }
    func requestFailed(response: HTTPURLResponse) async -> Bool { false }
    func availableAppVersions(forAppleItemIDs ids: [AppleItemID]) async -> [AppVersion] { [] }
}
#endif

extension Registry {
    static var p28tMarketplace: [Check] {
        var c: [Check] = []
#if canImport(MarketplaceKit) && os(iOS)
        c.append(check("MarketplaceKit", "p28-extension-updates-errors", timeout: 30) {
            let m = P28TMarketplace()
            let req = URLRequest(url: URL(string: "https://x86sim.test/")!)
            let versions = m.availableAppVersions(forAppleItemIDs: [1001, 1002]) ?? []
            var ups = try await m.automaticUpdates(for: versions)
            ups[0].appShareURL = URL(string: "https://x86sim.test/share")
            let failed = m.requestFailed(with: HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!)
            let appExt = P28TMarketplaceApp()
            let appVers = await appExt.availableAppVersions(forAppleItemIDs: [1])
            let errs: [MarketplaceKitError] = [.missingCapabilities(["nfc"]), .insufficientStorageSpace(Measurement(value: 2, unit: .gigabytes)), .networkError, .invalidLicense]
            let back = try errs.map { try p28tRoundTrip($0).description }
            let tokType = TransactionReporting.TokenType.coreTechnology
            let tok = await p27sAnswer(10) { "token \(try await TransactionReporting.token(for: .coreTechnology).count) chars" }
            try expect(m.additionalHeaders(for: req, account: "a")?["X-P28-Account"] == "a" && versions.map(\.appleVersionID) == [7, 7] && ups.count == 2 && ups[0].appShareURL != nil
                       && ups[1].alternativeDistributionPackage.lastPathComponent == "1002" && failed && appVers.isEmpty && back == errs.map(\.description) && !tokType.rawValue.isEmpty,
                       "\(back) \(tokType.rawValue)")
            let meta = p28tName((any MarketplaceExtensionConfiguration).self)
            return "\(versions.count) versions -> \(ups.count) automatic updates; errors JSON \(back.count); \(tokType.rawValue) \(tok); \(meta)"
        })
#endif
        return c
    }
}

// MARK: PermissionKit: choices (Codable), flows, results, ask errors, a question topic conformance

#if canImport(PermissionKit) && (os(iOS) || os(visionOS))
struct P28TTopic: QuestionTopic { static var id: String { "com.x86sim.p28.topic" }; let note: String }
#endif

extension Registry {
    static var p28tPermissionKit: [Check] {
        var c: [Check] = []
#if canImport(PermissionKit) && (os(iOS) || os(visionOS))
        c.append(check("PermissionKit", "p28-choices-flows-results") {
            var choice = PermissionChoice.approve
            let decline = try p28tRoundTrip(PermissionChoice.decline)
            choice.title = "Allow p28"
            let back = try p28tRoundTrip(choice)
            let flows: [PermissionFlow] = [.acknowledgmentAlert, .askToApprove, .approveInPerson]
            let results: [PermissionResult] = [.askToApprove(didSend: true), .approveInPerson(approved: false), .cancel]
            let errs: [AskError] = [.unknown, .invalidQuestion, .contactSyncNotSetup, .communicationLimitsNotEnabled, .notAvailable]
            let topic = try p28tRoundTrip(P28TTopic(note: "n"))
            let respType = p28tName(PermissionResponse<CommunicationTopic>.self)
            try expect(back.title == "Allow p28" && back.answer == .approval && decline.answer == .denial && decline == PermissionChoice.decline && Set(flows).count == 3
                       && results.count == 3 && errs.allSatisfy { $0.errorDescription != nil } && topic.note == "n" && P28TTopic.id.hasPrefix("com.") && respType.hasPrefix("PermissionKit.PermissionResponse"),
                       "\(back.title) \(errs.map { $0.errorDescription ?? "nil" })")
            return "choices \(back.id)/\(decline.id) round trip, 3 flows, 3 results, \(errs.count) ask errors (\(errs[0].errorDescription!.prefix(30))), topic \(P28TTopic.id)"
        })
#endif
        return c
    }
}

// MARK: TabularData: column slices, summaries' column ids, CSV / SFrame / column coding errors

extension Registry {
    static var p28tTabular: [Check] {
        var c: [Check] = []
#if canImport(TabularData)
        c.append(check("TabularData", "p28-slices-summary-errors") {
            var df = DataFrame()
            df.append(column: Column(name: "n", contents: [3.0, 1.0, 4.0, 1.0, 5.0]))
            df.append(column: Column<String>(name: "s", contents: ["a", "b", nil, "b", "c"]))
            let slice: AnyColumnSlice = df[1..<5]["s"]
            let distinct = slice.distinct()
            let typed = slice.assumingType(String.self)
            let summ = df.summary(of: "n")
            let mean = summ[SummaryColumnIDs.mean][0], maxV = summ[SummaryColumnIDs.maximum][0], nm = summ[SummaryColumnIDs.columnName][0]
            try expect(slice.count == 4 && slice.missingCount == 1 && slice.isNil(at: 2) && distinct.count == 3 && typed.count == 4 && abs((mean ?? 0) - 2.8) < 1e-9 && maxV == 5 && nm == "n",
                       "slice \(slice.count) missing \(slice.missingCount) distinct \(distinct.count) mean \(String(describing: mean))")
            // decoding a column into a mismatched type: the column decoding error
            struct Row: Decodable { let n: Int }
            var decErr = "none"
            let json = Column<Data>(name: "j", contents: [Data("{\"n\":1}".utf8), Data("{}".utf8)])
            do { _ = try json.decoded(Row.self, using: JSONDecoder()) } catch let e as ColumnDecodingError { decErr = "column \(e.columnName) row \(e.rowIndex)" } catch { decErr = "other \(type(of: error))" }
            let enc = ColumnEncodingError(columnName: "x", rowIndex: 2, encodingError: .invalidValue(1, .init(codingPath: [], debugDescription: "p28")))
            let csv = CSVWritingError.badEncoding(row: 3, column: "s", Data([0xff]))
            let sframe: [SFrameReadingError] = [.missingArchive, .badArchive("p28"), .unsupportedType(9), .missingColumn("q")]
            var sfAns = "read"
            do { _ = try DataFrame(contentsOfSFrameDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("p28-none.sframe")) } catch let e as SFrameReadingError { sfAns = e.description } catch { sfAns = "\(type(of: error))" }
            try expect(enc.rowIndex == 2 && !enc.debugDescription.isEmpty && csv.row == 3 && csv.column == "s" && sframe.allSatisfy { !$0.description.isEmpty }, "errors")
            return "slice 4 rows (1 nil, 3 distinct), summary mean \(mean!) max \(maxV!); decode: \(decErr); CSV / encoding errors; SFrame of nothing: \(sfAns.prefix(60))"
        })
#endif
        return c
    }
}

// MARK: iOS single-type leftovers: AppMigrationKit, AccessoryNotifications, CarKey, AccessoryLiveActivities, AlarmKit,
// ManagedAppDistribution, PaperKit, SensorKit, DeclaredAgeRange, DeviceDiscoveryUI / Extension, TranslationUIProvider,
// CloudKit share transfer, HealthKit category predicates

#if canImport(AppMigrationKit) && os(iOS)
enum P28TMigrationOption: String, CaseIterable, Hashable, Sendable { case photos, settings }
struct P28TMigrationExport: ResourcesExportingWithOptions {
    typealias OptionsType = P28TMigrationOption
    func exportResources(to archiver: sending ResourcesArchiver, request: MigrationRequestWithOptions<P28TMigrationOption>) async throws {}
    var resourcesSizeEstimate: Int { get async { 4096 } }
    var resourcesVersion: String { "1" }
    var resourcesCompressible: Bool { true }
}
#endif
#if canImport(AccessoryLiveActivities) && os(iOS)
struct P28TLiveActivityHandler: LiveActivityForwarding.AccessoryLiveActivitiesHandler {
    func activate(for session: LiveActivityForwarding.Session) {}
    func sessionInvalidated() {}
    func messageReceived(_ message: TransportMessage) {}
    func activityUpdatedForAlert(_ activity: AccessoryLiveActivity) -> Bool { activity.content?.alert != nil }
    func activityUpdated(_ activity: AccessoryLiveActivity) {}
}
#endif
#if canImport(HealthKit) && !os(tvOS)
func p28tCategoryPredicate<V: HKCategoryValuePredicateProviding>(_ v: V) -> NSPredicate where V.RawValue == Int { V.predicateForSamples(.equalTo, value: v) }
#endif

extension Registry {
    static var p28tSmallIOS: [Check] {
        var c: [Check] = []
#if canImport(AppMigrationKit) && os(iOS)
        c.append(check("AppMigrationKit", "p28-export-with-options") {
            let req = MigrationRequestWithOptions<P28TMigrationOption>(destinationPlatform: .android, options: [.photos: Data([1])])
            let defReq = MigrationRequestWithOptions<MigrationDefaultSupportedOptions>(destinationPlatform: .android)
            let ex = P28TMigrationExport()
            let size = await ex.resourcesSizeEstimate
            let defaults = MigrationDefaultSupportedOptions.allCases.map(\.rawValue)
            let cont = p28tName(MigrationDataContainer.self), proto = p28tName((any AppMigrationExtension).self)
            try expect(req.options[.photos] == Data([1]) && defReq.options.isEmpty && req.destinationPlatform == .android && size == 4096 && ex.resourcesCompressible
                       && cont.hasPrefix("AppMigrationKit.") && proto.hasPrefix("AppMigrationKit."), "\(defaults)")
            return "request with options to \(req.destinationPlatform.rawValue); default options \(defaults); export estimate \(size) B"
        })
#endif
#if canImport(AccessoryNotifications) && os(iOS)
        c.append(check("AccessoryNotifications", "p28-forwarding-values") {
            let ds: [ForwardingDecision] = [.allow, .limited, .deny, .undetermined]
            let back = try ds.map { try p28tRoundTrip($0) }
            let r = NotificationResponse(sourceIdentifier: "com.x86sim.p28", notificationIdentifier: "n1", actionIdentifier: "reply", userText: "hi")
            let errs: [AccessoryError] = [.accessoryNotificationsUnavailable, .unsupportedPlatform, .unsupportedAccessory, .invalidNotificationResponse, .coordinationTimeout, .internalInconsistency]
            let eb = try errs.map { try p28tRoundTrip($0) }
            _ = AccessoryNotificationCenter()
            try expect(back == ds && (try p28tRoundTrip(r)) == r && eb == errs && Set(ds.map(\.description)).count == 4, "\(ds.map(\.description))")
            return "decisions \(ds.map(\.description)), response + \(errs.count) errors round trip; notification center made"
        })
#endif
#if canImport(CarKey) && (os(iOS) || os(watchOS))
        c.append(check("CarKey", "p28-enduring-actions-statuses") {
            let f = FunctionIdentifier(0x10), a = ActionIdentifier(2)
            let e1 = RemoteKeylessEntryEnduringAction(functionID: f, actionID: a, vehicleID: "p28-car")
            let e2 = RemoteKeylessEntryConfigurableEnduringAction(functionID: f, actionID: ActionIdentifier(rawValue: 3), vehicleID: "p28-car")
            let st = [ExecutionStatus(0), ExecutionStatus(rawValue: 1)], fs = Set([FunctionStatus(5), FunctionStatus(rawValue: 5), FunctionStatus(6)])
            let req = p28tName(RemoteKeylessEntryConfigurableEnduringAction.EnduringExecutionRequest.self)
            try expect(e1.recipientVehicleID == "p28-car" && e1.functionID == f && e2.actionID.rawValue == 3 && st.map(\.rawValue) == [0, 1] && fs.count == 2 && req.hasPrefix("CarKey."), "\(req)")
            return "enduring + configurable enduring actions for p28-car, statuses \(st.map(\.rawValue)), \(fs.count) function statuses"
        })
#endif
#if canImport(AccessoryLiveActivities) && os(iOS)
        c.append(check("AccessoryLiveActivities", "p28-forwarding-handler") {
            let h: any LiveActivityForwarding.AccessoryLiveActivitiesHandler = P28TLiveActivityHandler()
            h.sessionInvalidated()
            let names = [p28tName(AccessoryLiveActivity.self), p28tName(AccessoryLiveActivity.Content.AlertMessage.self), p28tName(AccessoryLiveActivity.IconFile.self)]
            try expect(names.allSatisfy { $0.hasPrefix("AccessoryLiveActivities.AccessoryLiveActivity") }, "\(names)")
            return "handler conformance; activity types \(names.map { $0.replacingOccurrences(of: "AccessoryLiveActivities.", with: "") })"
        })
#endif
#if canImport(AlarmKit) && os(iOS)
        c.append(check("AlarmKit", "p28-presentation-states") {
            let id = UUID()
            let modes: [AlarmPresentationState.Mode] = [
                .alert(.init(time: .init(hour: 7, minute: 30))),
                .countdown(.init(totalCountdownDuration: 300, previouslyElapsedDuration: 10, startDate: Date(timeIntervalSince1970: 100), fireDate: Date(timeIntervalSince1970: 390))),
                .paused(.init(totalCountdownDuration: 300, previouslyElapsedDuration: 120))]
            let states = modes.map { AlarmPresentationState(alarmID: id, mode: $0) }
            let back = try states.map { try p28tRoundTrip($0) }
            try expect(back == states && Set(states).count == 3 && back.allSatisfy { $0.alarmID == id }, "states")
            return "alert / countdown / paused presentation states round trip"
        })
#endif
#if canImport(PaperKit) && (os(iOS) || os(visionOS))
        c.append(check("PaperKit", "p28-markup-interactions") {
            var i: MarkupInteractions = [.move, .resize]
            i.insert(.rotate); i.remove(.resize)
            let all = MarkupInteractions.all
            try expect(i.contains(.move) && !i.contains(.resize) && all.contains([.rotate, .resize, .delete, .move, .style, .select]) && !MarkupInteractions.readOnly.contains(.delete),
                       "raw \(i.rawValue) all \(all.rawValue) readOnly \(MarkupInteractions.readOnly.rawValue)")
            return "interactions raw \(i.rawValue), all \(all.rawValue), read only \(MarkupInteractions.readOnly.rawValue)"
        })
#endif
#if canImport(SensorKit) && os(iOS)
        c.append(check("SensorKit", "p28-fetch-responses", timeout: 30) {
            let r = try SRReader(sensor: SRAmbientLightSensor())
            let b = P28TBox<String>()
            let t = Task {
                do {
                    for try await resp: SRFetchResponse<SRAmbientLightSample> in r.samples(matching: SRFetchRequest()) {
                        if case .success = resp.sample { b.set("sample at \(resp.timestamp)") } else { b.set("failed sample") }
                        break
                    }
                    b.set("finished")
                } catch { b.set("\((error as NSError).domain) \((error as NSError).code)") }
            }
            let ans = await b.wait(15) ?? "nothing in 15 s"; t.cancel()
            try expect(ans == "SRErrorDomain 3", "fetch: \(ans) (Apple's simulator: SRErrorDomain 3, not authorized)")
            return "ambient light fetch (no SensorKit entitlement): \(ans)"
        })
#endif
#if canImport(DeclaredAgeRange) && os(iOS)
        c.append(check("DeclaredAgeRange", "p28-environment-actions") {
            try await onMain { () throws -> String in
                let env = EnvironmentValues()
                let a: DeclaredAgeRangeAction = env.requestAgeRange
                let s: SignificantUpdateAction = env.showSignificantUpdateAcknowledgment
                return "environment actions \(p28tName(type(of: a))), \(p28tName(type(of: s)))"
            }
        })
#endif
#if canImport(DeviceDiscoveryUI) && os(iOS)
        c.append(check("DeviceDiscoveryUI", "p28-pairing-access") {
            let a = [DDDevicePairingAccess.default, .permanent]
            let proto = p28tName((any DDDiscoveryExtensionConfigurationProtocol).self)
            try expect(a.count == 2 && proto == "DeviceDiscoveryExtension.DDDiscoveryExtensionConfigurationProtocol", proto)
            return "pairing access default / permanent; \(proto)"
        })
#endif
#if canImport(TranslationUIProvider) && os(iOS)
        c.append(check("TranslationUIProvider", "p28-extension-configuration") {
            let n = p28tName(TranslationProviderUIExtensionConfiguration.self)
            try expect(n.hasPrefix("TranslationUIProvider."), n)
            return n
        })
#endif
#if canImport(CloudKit) && os(iOS)
        c.append(check("CloudKit", "p28-share-transfer-representation") {
            struct Doc: Transferable {
                let share: CKShare
                static var transferRepresentation: some TransferRepresentation {
                    CKShareTransferRepresentation<Doc> { d in .existing(d.share, container: CKContainer(identifier: "iCloud.com.x86sim.p28")) }
                }
            }
            let rep = Doc.transferRepresentation
            let n = p28tName(type(of: rep))
            try expect(n.contains("CKShareTransferRepresentation"), n)
            return "Transferable with \(n.components(separatedBy: "<").first!)"
        })
#endif
#if canImport(HealthKit) && !os(tvOS)
        c.append(check("HealthKit", "p28-category-value-predicates") {
            let p1 = p28tCategoryPredicate(HKCategoryValueAppleStandHour.stood)
            let p2 = HKCategoryValueSleepAnalysis.predicateForSamples(equalTo: [.awake, .asleepREM])
            try expect(p1.predicateFormat.contains("value") && p2.predicateFormat.contains("value"), "\(p1) \(p2)")
            return "\(p1.predicateFormat); \(p2.predicateFormat)"
        })
#endif
        return c
    }
}

// MARK: leftovers across platforms: ImagePlayground, LockedCameraCapture, TrustInsights, VisionKit, MusicKit, Combine,
// CryptoKit, UIKit badges / traits, and one-class ObjC types (constructed where they have an initializer, else the
// class the system hands out, by name)

let p28tCertB64 = "MIIBkjCCATegAwIBAgIUbtQ1SHWjekvH559fcAl7evKve4IwCgYIKoZIzj0EAwIwHTEbMBkGA1UEAwwSc2RrY292Lng4NnNpbS50ZXN0MCAXDTI2MTExNDA5MDgxOVoYDzIxMjYxMDIxMDkwODE5WjAdMRswGQYDVQQDDBJzZGtjb3YueDg2c2ltLnRlc3QwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAAQOJfkuFPd1F3AV2iKLjzgepMckyeKaC20JwA5V6rVb4EkeI+VoiNM2ornLpK/sP046XLke8x+R1ZNtYhjl1QZVo1MwUTAdBgNVHQ4EFgQUBcbx9mwi8a14lX6VX2j6qFPMVNowHwYDVR0jBBgwFoAUBcbx9mwi8a14lX6VX2j6qFPMVNowDwYDVR0TAQH/BAUwAwEB/zAKBggqhkjOPQQDAgNJADBGAiEAgnMF6lrC3kpppHOkwEr2DsbrfbE6SRPJRKzEUFNp74QCIQDzKlEPktpfRF/EjqLTpa5/sY92FYMUaoq38ntGwE6iBQ=="

#if canImport(VisionKit) && os(iOS)
@MainActor final class P28TImageAnalysisDelegate: ImageAnalysisInteractionDelegate, DataScannerViewControllerDelegate {
    var asked = 0
    func contentsRect(for interaction: ImageAnalysisInteraction) -> CGRect { asked += 1; return CGRect(x: 0, y: 0, width: 1, height: 1) }
    func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {}
}
#endif
#if canImport(UIKit) && (os(iOS) || os(tvOS))
struct P28TBridgedKey: UITraitBridgedEnvironmentKey {
    static let defaultValue = 0
    static func read(from traitCollection: UITraitCollection) -> Int { traitCollection.userInterfaceStyle == .dark ? 2 : 1 }
    static func write(to mutableTraits: inout any UIMutableTraits, value: Int) { mutableTraits.userInterfaceStyle = value == 2 ? .dark : .light }
}
#endif
#if canImport(Combine)
/// a connectable publisher used through the protocol: connect, then count what arrives
func p28tConnect<P: ConnectablePublisher>(_ p: P, _ got: @escaping (P.Output) -> Void) -> [AnyCancellable] where P.Failure == Never {
    [p.sink(receiveValue: got), AnyCancellable(p.connect())]
}
final class P28TPublished { @Published var v = 0 }
#endif

extension Registry {
    static var p28tLeftovers: [Check] {
        var c: [Check] = []
#if canImport(ImagePlayground) && (os(iOS) || os(visionOS))
        c.append(check("ImagePlayground", "p28-options-styles") {
            var o = ImagePlaygroundOptions()
            o.personalization = .disabled; o.creationVariety = .high; o.creationStrategy = .generateNew
            o.sizeSpecification = .closest(to: CGSize(width: 512, height: 512))
            let styles = ImagePlaygroundStyle.all
            let back = try styles.map { try p28tRoundTrip($0) }
            let pol: [ImagePlaygroundPersonalizationPolicy] = [.automatic, .enabled, .disabled]
            try expect(o != ImagePlaygroundOptions() && back == styles && Set(styles.map(\.id)).count == styles.count && pol.map(\.rawValue) == [0, 1, 2]
                       && ImagePlaygroundPersonalizationPolicy(rawValue: 2) == .disabled, "styles \(styles.map(\.id))")
            return "options set; styles \(styles.map(\.id)) round trip; personalization policies \(pol.map(\.rawValue))"
        })
#endif
#if canImport(LockedCameraCapture) && os(iOS)
        c.append(check("LockedCameraCapture", "p28-extension-scene") {
            try await onMain { () throws -> String in
                let scene = LockedCameraCaptureUIScene { (session: LockedCameraCaptureSession) in Text("\(session.sessionContentURL.lastPathComponent)") }
                let n = p28tName(type(of: scene)), meta = [p28tName((any LockedCameraCaptureExtension).self), p28tName((any LockedCameraCaptureExtensionScene).self)]
                try expect(n.hasPrefix("LockedCameraCapture.LockedCameraCaptureUIScene") && meta.allSatisfy { $0.hasPrefix("LockedCameraCapture.") }, "\(n) \(meta)")
                return "UI scene \(n.components(separatedBy: "<").first!); extension protocols"
            }
        })
#endif
#if canImport(TrustInsights) && os(iOS)
        c.append(check("TrustInsights", "p28-consumption-errors") {
            let st: [InsightEvaluationConsumptionStatus] = [.notUsedNotNeeded, .usedUnchangedFriction, .usedReducedFriction, .usedIncreasedFriction, .notUsedError, .usedEvaluationOnly]
            let back = try st.map { try p28tRoundTrip($0) }
            let errs: [InsightError] = [.rateLimitError, .insightVersionUnavailable, .insightVersionIncompatible, .insightEvaluationFailed, .insightUnavailable]
            let insight: any TrustInsight.Type = IsLikelyBeingCoachedInsight.self
            try expect(back == st && Set(errs).count == 5 && errs.allSatisfy { $0.errorDescription != nil } && insight.typeIdentifier == IsLikelyBeingCoachedInsight.typeIdentifier, "\(st.map(\.rawValue))")
            return "statuses \(st.map(\.rawValue)) round trip; \(errs.count) errors (\(errs[0].errorDescription!.prefix(30))); insight \(insight.typeIdentifier)"
        })
#endif
#if canImport(VisionKit) && os(iOS)
        c.append(check("VisionKit", "p28-delegates-items") {
            try await onMain { () throws -> String in
                let d = P28TImageAnalysisDelegate()
                let ia = ImageAnalysisInteraction(); ia.delegate = d
                let v = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50)); v.addInteraction(ia)
                let dsc = DataScannerViewController(recognizedDataTypes: [.text()]); dsc.delegate = d
                let names = [p28tName(RecognizedItem.self), p28tName(RecognizedItem.Bounds.self)]
                let scan: AnyClass? = NSClassFromString("VNDocumentCameraScan")
                try expect(ia.delegate === d && dsc.delegate === d && names[0] == "VisionKit.RecognizedItem" && scan != nil, "\(names)")
                return "interaction + data scanner delegates set; \(names[0]); scanner supported \(DataScannerViewController.isSupported), available \(DataScannerViewController.isAvailable); VNDocumentCameraScan class present"
            }
        })
#elseif canImport(VisionKit) && os(visionOS)
        c.append(check("VisionKit", "p28-camera-region-view") {
            try await onMain { () throws -> String in
                let v = CameraRegionView(isContrastAndVibrancyEnhancementEnabled: true)
                let host = UIHostingController(rootView: v)
                host.view.frame = CGRect(x: 0, y: 0, width: 200, height: 200); host.view.layoutIfNeeded()
                let names = [p28tName(RecognizedItem.self), NSClassFromString("VNDocumentCameraScan").map { NSStringFromClass($0) } ?? "no VNDocumentCameraScan"]
                return "camera region view hosted; \(names)"
            }
        })
#endif
#if canImport(MusicKit) && !os(watchOS)
        c.append(check("MusicKit", "p28-property-types") {
            let n = [p28tName(MusicAttributeProperty<Album, String>.self), p28tName((any LibraryPlaylistEntrySortProperties).self)]
            try expect(n[0].hasPrefix("MusicKit.MusicAttributeProperty<") && n[1] == "MusicKit.LibraryPlaylistEntrySortProperties", "\(n)")
            return "\(n)"
        })
#endif
#if canImport(Combine)
        c.append(check("Combine", "p28-connectable-published") {
            let src = [1, 2, 3].publisher.makeConnectable()
            var got: [Int] = []
            let cs = p28tConnect(src) { got.append($0) }
            let model = P28TPublished()
            var seen: [Int] = []
            let pub: Published<Int>.Publisher = model.$v
            let s2 = pub.sink { seen.append($0) }
            model.v = 5; model.v = 6
            let auto = PassthroughSubject<Int, Never>().makeConnectable().autoconnect()
            _ = (cs, s2, auto)
            try expect(got == [1, 2, 3] && seen == [0, 5, 6], "connectable \(got), published \(seen)")
            return "connectable publisher \(got); Published.Publisher \(seen); autoconnect"
        })
#endif
#if canImport(CryptoKit)
        c.append(check("CryptoKit", "p28-sha3-digests") {
            let hex = { (d: any Sequence<UInt8>) in d.map { String(format: "%02x", $0) }.joined() }
            let abc = Data("abc".utf8)
            let h256 = hex(SHA3_256.hash(data: abc)), h384 = hex(SHA3_384.hash(data: abc)), h512 = hex(SHA3_512.hash(data: abc))
            var inc = SHA3_256(); inc.update(data: Data("a".utf8)); inc.update(data: Data("bc".utf8))
            let curve = p28tName(CorecryptoCurveType.self)
            try expect(h256 == "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532" && hex(inc.finalize()) == h256
                       && h384.hasPrefix("ec01498288516fc926459f58e2c6ad8df9b473cb0fc08c25") && h512.hasPrefix("b751850b1a57168a5693cd924b6b096e08f621827444f70d"), "SHA3 \(h256) \(h384.prefix(16)) \(h512.prefix(16))")
            return "SHA3 digests (256 / 384 / 512, incremental) match FIPS 202; \(curve)"
        })
#endif
#if canImport(UIKit) && os(iOS)
        c.append(check("UIKit", "p28-badges-traits") {
            try await onMain { () throws -> String in
                let item = UIBarButtonItem(title: "p28", style: .plain, target: nil, action: nil)
                var b = UIBarButtonItem.Badge.count(3); b.backgroundColor = .systemRed
                item.badge = b
                let s = UIBarButtonItem.Badge.string("new"), ind = UIBarButtonItem.Badge.indicator()
                let objc: AnyClass? = NSClassFromString("UIBarButtonItemBadge")
                let tc = UITraitCollection(traitsFrom: [UITraitCollection(userInterfaceStyle: .dark)])
                let tab = UITraitTabAccessoryEnvironment.defaultValue
                var nav = "needs 27.2"
                if #available(iOS 27.2, *) { nav = "\(UITraitNavigationTitleAlignment.name) = \(UITraitNavigationTitleAlignment.defaultValue.rawValue) (\(UITraitNavigationTitleAlignment.identifier))" }
                let bridged = P28TBridgedKey.read(from: tc)
                try expect(item.badge?.stringValue == "3" && s.stringValue == "new" && ind.stringValue == nil && objc != nil && bridged == 2
                           && !UITraitTabAccessoryEnvironment.identifier.isEmpty,
                           "badge \(String(describing: item.badge?.stringValue)) \(String(describing: s.stringValue)) bridged \(bridged)")
                return "bar button badge '3' / 'new' / indicator; traits \(UITraitTabAccessoryEnvironment.name) = \(tab.rawValue), \(nav); bridged key reads \(bridged)"
            }
        })
#endif
        return c
    }
}

// MARK: one-class ObjC leftovers

extension Registry {
    static var p28tObjCLeftovers: [Check] {
        var c: [Check] = []
#if canImport(JavaScriptCore)
        c.append(check("JavaScriptCore", "p28-values-managed") {
            let ctx = JSContext()!
            let v: JSValue = ctx.evaluateScript("({a: 41, f: function(x) { return x + 1 }})")
            let r: JSValue = v.objectForKeyedSubscript("f").call(withArguments: [v.objectForKeyedSubscript("a")!])
            let owner = NSObject()
            let m = JSManagedValue(value: v, andOwner: owner)!
            ctx.virtualMachine.addManagedReference(m, withOwner: owner)
            let back = m.value?.objectForKeyedSubscript("a").toInt32()
            ctx.virtualMachine.removeManagedReference(m, withOwner: owner)
            try expect(r.toInt32() == 42 && back == 41 && v.isObject, "call \(r) managed \(String(describing: back))")
            return "JSValue call -> \(r.toInt32()); JSManagedValue keeps the object (a = \(back!))"
        })
#endif
#if canImport(MultipeerConnectivity) && !os(watchOS)
        c.append(check("MultipeerConnectivity", "p28-assistant-browser-vc") {
            try await onMain { () throws -> String in
                let peer = MCPeerID(displayName: "p28")
                let s = MCSession(peer: peer)
                let a = MCAdvertiserAssistant(serviceType: "p28-svc", discoveryInfo: ["k": "v"], session: s)
                let b = MCBrowserViewController(serviceType: "p28-svc", session: s)
                b.minimumNumberOfPeers = 2; b.maximumNumberOfPeers = 4
                try expect(a.serviceType == "p28-svc" && a.discoveryInfo?["k"] == "v" && a.session === s && b.session === s && b.browser?.serviceType == "p28-svc"
                           && b.minimumNumberOfPeers == 2 && b.maximumNumberOfPeers == 4, "assistant / browser")
                return "advertiser assistant + browser view controller for p28-svc (not started)"
            }
        })
#endif
#if canImport(NaturalLanguage)
        c.append(check("NaturalLanguage", "p28-model-config-embedding-result", timeout: 30) {
            let revs = NLModelConfiguration.supportedRevisions(for: .classifier), cur = NLModelConfiguration.currentRevision(for: .sequence)
            var emb = "no contextual embedding"
            if let e = NLContextualEmbedding(language: .english) {
                if e.hasAvailableAssets {
                    try e.load()
                    let r: NLContextualEmbeddingResult = try e.embeddingResult(for: "x86 sim", language: .english)
                    var n = 0
                    r.enumerateTokenVectors(in: r.string.startIndex..<r.string.endIndex) { _, _ in n += 1; return true }
                    emb = "result \(r.sequenceLength) tokens, \(n) vectors"
                    e.unload()
                } else { emb = "assets not available" }
            }
            try expect(revs.count >= 1 && cur >= 1, "revisions \(revs) current \(cur)")
            return "classifier revisions \(Array(revs)), tagger current \(cur); embedding: \(emb)"
        })
#endif
#if canImport(Social) && os(iOS)
        c.append(check("Social", "p28-compose-service") {
            try await onMain { () throws -> String in
                let item = SLComposeSheetConfigurationItem()!
                item.title = "Audience"; item.value = "Friends"; item.valuePending = true
                var tapped = false; item.tapHandler = { tapped = true }; item.tapHandler()
                let vc = SLComposeServiceViewController()
                vc.placeholder = "p28"
                try expect(item.title == "Audience" && item.valuePending && tapped && vc.placeholder == "p28", "compose")
                return "configuration item tapped; compose service controller placeholder set"
            }
        })
#endif
#if canImport(Accounts) && os(iOS)
        c.append(check("Accounts", "p28-credential-type") {
            let cr = ACAccountCredential(oAuth2Token: "tok", refreshToken: "ref", expiryDate: Date(timeIntervalSinceNow: 60))!
            let t: ACAccountType? = ACAccountStore().accountType(withAccountTypeIdentifier: "com.apple.twitter")
            try expect(cr.oauthToken == "tok", "credential")
            return "OAuth2 credential; twitter account type \(t.map { "\($0.identifier ?? "?") granted \($0.accessGranted)" } ?? "nil")"
        })
#endif
#if canImport(AddressBookUI) && os(iOS)
        c.append(check("AddressBookUI", "p28-person-controllers") {
            try await onMain { () throws -> String in
                let p = ABPersonViewController(); p.allowsEditing = true; p.allowsActions = false
                let u = ABUnknownPersonViewController(); u.alternateName = "P28"; u.message = "unknown"
                try expect(p.allowsEditing && !p.allowsActions && u.alternateName == "P28", "controllers")
                return "person / unknown person controllers configured"
            }
        })
#endif
#if canImport(CoreBluetooth) && os(iOS)
        c.append(check("CoreBluetooth", "p28-channel-sounding") {
            let cfg = CBChannelSoundingSessionConfiguration(role: .initiator)
            // procedure results only come from a channel sounding session (no public initializer)
            let res = p28tName(CBChannelSoundingProcedureResults.self)
            try expect(cfg.role == .initiator && res == "CBChannelSoundingProcedureResults", "role \(cfg.role.rawValue) \(res)")
            return "session configuration initiator; \(res) from a session"
        })
#endif
#if canImport(SharedWithYou) && (os(iOS) || os(visionOS))
        c.append(check("SharedWithYou", "p28-collaboration-view") {
            try await onMain { () throws -> String in
                let v = SWCollaborationView(itemProvider: NSItemProvider(object: "p28" as NSString))
                v.headerTitle = "Shared"; v.headerSubtitle = "p28"
                let hosted = UIView(); v.setContent(hosted)
                return "collaboration view with an item provider; header title reads '\((v.value(forKey: "headerTitle") as? String) ?? "nil")' after set"
            }
        })
#endif
#if canImport(PencilKit) && (os(iOS) || os(visionOS))
        c.append(check("PencilKit", "p28-custom-tool-item") {
            try await onMain { () throws -> String in
                var cfg = PKToolPickerCustomItem.Configuration(identifier: "com.x86sim.p28.tool", name: "P28 tool")
                cfg.defaultWidth = 6; cfg.allowsColorSelection = true; cfg.defaultColor = .systemBlue
                let item = PKToolPickerCustomItem(configuration: cfg)
                try expect(item.configuration.identifier == "com.x86sim.p28.tool" && item.configuration.defaultWidth == 6 && cfg.name == "P28 tool"
                           && NSClassFromString("PKToolPickerCustomItemConfiguration") != nil, "custom item")
                return "custom tool item '\(item.configuration.name)' width \(item.configuration.defaultWidth)"
            }
        })
#endif
#if canImport(PushToTalk) && os(iOS)
        c.append(check("PushToTalk", "p28-participant") {
            let p = PTParticipant(name: "P28", image: nil)
            try expect(p.name == "P28" && p.image == nil, "participant")
            return "participant \(p.name)"
        })
#endif
#if canImport(ScreenTime) && os(iOS)
        c.append(check("ScreenTime", "p28-configuration-observer") {
            let o = STScreenTimeConfigurationObserver(updateQueue: .main)
            o.startObserving()
            try await Task.sleep(for: .milliseconds(500))
            let cfg: STScreenTimeConfiguration? = o.configuration
            o.stopObserving()
            return "configuration \(cfg.map { "enforces child restrictions \($0.enforcesChildRestrictions)" } ?? "nil")"
        })
#endif
#if canImport(SecurityUI) && !os(watchOS)
        c.append(check("SecurityUI", "p28-certificate-presentation") {
            guard let der = Data(base64Encoded: p28tCertB64), let cert = SecCertificateCreateWithData(nil, der as CFData) else { throw Fail("certificate") }
            var trust: SecTrust?
            SecTrustCreateWithCertificates(cert, SecPolicyCreateBasicX509(), &trust)
            let p = await MainActor.run { () -> SFCertificatePresentation in
                let p = SFCertificatePresentation(trust: trust!); p.title = "P28"; p.message = "test certificate"; p.helpURL = URL(string: "https://x86sim.test/help"); return p
            }
            let back = await MainActor.run { (p.title, SecTrustGetCertificateCount(p.trust)) }
            try expect(back.0 == "P28" && back.1 == 1, "\(back)")
            return "presentation title \(back.0), \(back.1) certificate"
        })
#endif
#if canImport(StateReporting)
        c.append(check("StateReporting", "p28-reporter") {
            // Swift's StateReporter wraps the ObjC SRStateReporter (NS_REFINED_FOR_SWIFT)
            let r = StateReporter<Never, Never>.reporter(for: "com.x86sim.p28")
            r.reportTransition(to: "checkout"); r.reportVolatileMetadataUpdate(nil); r.reportTransition(to: nil)
            let objc: AnyClass? = NSClassFromString("SRStateReporter")
            try expect(objc != nil && class_getClassMethod(objc, NSSelectorFromString("reporterForDomain:")) != nil, "SRStateReporter")
            return "reporter for com.x86sim.p28: transitions; SRStateReporter underneath"
        })
#endif
#if os(iOS)
        c.append(check("AssetsLibrary", "p28-filters-types") {
            // unavailable to Swift on iOS 27 (see More_iOS): the filters and object classes through the runtime
            guard dlopen("/System/Library/Frameworks/AssetsLibrary.framework/AssetsLibrary", RTLD_NOW) != nil, let fc = NSClassFromString("ALAssetsFilter") else { throw Fail("no ALAssetsFilter") }
            typealias F = @convention(c) (AnyClass, Selector) -> Unmanaged<NSObject>
            let filters = ["allPhotos", "allVideos", "allAssets"].map { n -> String in
                let sel = NSSelectorFromString(n)
                let o = unsafeBitCast(class_getMethodImplementation(object_getClass(fc), sel), to: F.self)(fc, sel).takeUnretainedValue()
                return NSStringFromClass(type(of: o))
            }
            let rows = p28tClasses([("ALAsset", "NSObject"), ("ALAssetRepresentation", "NSObject"), ("ALAssetsGroup", "NSObject")])
            try expect(filters.allSatisfy { $0.contains("ALAssetsFilter") } && rows.isEmpty, "\(filters) \(rows)")
            return "filters \(filters); asset / representation / group classes"
        })
#endif
#if os(iOS)
        c.append(check("Twitter", "p28-request-class") {
            // Twitter's module map says `requires !swift`: the framework through the ObjC runtime
            let path = "/System/Library/Frameworks/Twitter.framework/Twitter"
            let h = dlopen(path, RTLD_NOW)
            let cls: AnyClass? = NSClassFromString("TWRequest")
            let sels = ["initWithURL:parameters:requestMethod:", "signedURLRequest", "performRequestWithHandler:", "addMultiPartData:withName:type:"]
            let have = sels.filter { sel in cls.map { class_getInstanceMethod($0, NSSelectorFromString(sel)) != nil } ?? false }
            try expect(h != nil && cls != nil && have.count == sels.count, "dlopen \(h != nil) TWRequest \(cls != nil) \(have)")
            return "TWRequest (\(NSStringFromClass(class_getSuperclass(cls!)!)) subclass) with \(have.count) methods"
        })
#endif
#if canImport(OpenGLES) && !os(watchOS) && !os(visionOS)
        c.append(check("OpenGLES", "p28-sharegroup") {
            guard let ctx = EAGLContext(api: .openGLES2) else { return "no ES2 context" }
            let g: EAGLSharegroup = ctx.sharegroup
            g.debugLabel = "p28"
            let ctx2 = EAGLContext(api: .openGLES2, sharegroup: g)
            try expect(g.debugLabel == "p28" && ctx2?.sharegroup === g, "sharegroup")
            return "two contexts share group '\(g.debugLabel ?? "")'"
        })
#endif
#if canImport(MetalPerformanceShadersGraph) && !os(watchOS)
        c.append(check("MetalPerformanceShadersGraph", "p28-serialization-descriptor") {
            // MPSGraphExecutableSerializationDescriptor() asserts "unhandled platform" (MPSGraphExecutable.mm:327) in a
            // simulator process: the class, its properties and superclass only
            let cls: AnyClass = MPSGraphExecutableSerializationDescriptor.self
            let props = ["append", "deploymentPlatform", "minimumDeploymentTarget"].filter { class_getProperty(cls, $0) != nil || class_getInstanceMethod(cls, NSSelectorFromString($0)) != nil }
            try expect(class_getSuperclass(cls) == MPSGraphObject.self && props.count == 3, "\(props)")
            return "MPSGraphObject subclass with \(props)"
        })
#endif
#if canImport(ClockKit) && os(watchOS)
        c.append(check("ClockKit", "p28-gauge-provider") {
            let g: CLKGaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: .red, fillFraction: 0.25)
            g.accessibilityLabel = "p28"
            let cp = g.copy() as? CLKGaugeProvider
            try expect(g.style == .fill && cp?.accessibilityLabel == "p28", "gauge")
            return "simple gauge as CLKGaugeProvider, copy keeps its label"
        })
#endif
#if canImport(Foundation)
        c.append(check("Foundation", "p28-file-security") {
            let f = FileManager.default.temporaryDirectory.appendingPathComponent("p28-sec.txt")
            try Data("x".utf8).write(to: f)
            let sec = try (f as NSURL).resourceValues(forKeys: [.fileSecurityKey])[.fileSecurityKey] as? NSFileSecurity
            let back = try sec.flatMap { try p28tArchive($0) }
            try? FileManager.default.removeItem(at: f)
            try expect(sec != nil && back is NSFileSecurity && (sec!.copy() as? NSFileSecurity) != nil, "file security \(String(describing: sec))")
            return "NSFileSecurity of a file: copy + secure coding round trip"
        })
#endif
        // types the system hands out (no public initializer) or that exist only on other platforms: present in this
        // runtime with the right superclass, as on Apple's simulator
        c.append(check("Foundation", "p28-system-only-classes") {
            var rows: [(String, String)] = []
#if os(iOS) || os(visionOS)
            rows += [("FPUIActionExtensionContext", "NSExtensionContext"), ("ILClassificationUIExtensionContext", "NSExtensionContext")]
#endif
#if os(iOS)
            rows += [("APActivationPayload", "NSObject"), ("MKLookAroundSnapshot", "NSObject")]   // App Clips: iOS only
#endif
#if !os(tvOS)
            rows += [("PKVoIPPushMetadata", "NSObject")]
#endif
            let wrong = p28tClasses(rows)
            let other = p28tPresent(["CIFilterGenerator", "CIPlugIn", "OSSystemExtensionManager", "OSSystemExtensionRequest", "OSSystemExtensionProperties", "OSSystemExtensionInfo",
                                     "AEAssessmentBinaryExecutable", "AEAssessmentBinaryExecutableConfiguration", "HMAddAccessoryRequest", "GSSyncedDirectory", "GSSyncedDirectoryState",
                                     "GSSyncedDirectoryVersion", "WCSessionFile", "WCSessionFileTransfer", "WCSessionUserInfoTransfer", "SCSensitivityAnalysis", "WKImmersiveEnvironment"])
            // Apple's simulator: the macOS-only CoreImage plug-in / filter generator and OSSystemExtension manager / request / info classes are absent
            var expAbsent: [String]? = nil
#if os(iOS)
            expAbsent = ["CIFilterGenerator", "CIPlugIn", "OSSystemExtensionManager", "OSSystemExtensionRequest", "OSSystemExtensionInfo"]
#endif
            try expect(wrong.isEmpty && (expAbsent == nil || other.missing == expAbsent!), "\(wrong) absent \(other.missing)")
            return "\(rows.count) system-made classes ok; other-platform / system classes present: \(other.present.joined(separator: " ")); absent: \(other.missing.joined(separator: " "))"
        })
        return c
    }
}

// MARK: tvOS: TVMLKit objects (player, playback events, factories, controllers), TVUIKit content views /
// configurations, TVServices top shelf / content items, UIKit traits

extension Registry {
    static var p28tTV: [Check] {
        var c: [Check] = []
#if canImport(TVMLKit) && os(tvOS)
        c.append(check("TVMLKit", "p28-player-factories-controllers") {
            try await onMain { () throws -> String in
                let p = TVPlayer(player: AVPlayer())
                let ev = TVPlaybackCustomEventUserInfo(properties: nil, expectsReturnValue: true)
                ev.expectsReturnValue = false
                TVElementFactory.registerViewElementClass(TVViewElement.self, elementName: "p28Element")
                TVStyleFactory.registerStyleName("p28-style", type: .integer, inherited: false)
                let f = TVInterfaceFactory.shared()
                // the browser / document controllers are made by TVMLKit for a document (init unavailable)
                let vcs: [AnyClass] = [TVBrowserViewController.self, TVDocumentViewController.self]
                let rows = p28tClasses([("TVBrowserTransitionAnimator", "NSObject"), ("TVColor", "NSObject"), ("TVMediaItem", "NSObject"), ("TVPlaylist", "NSObject"),
                                        ("TVImageElement", "TVViewElement"), ("TVTextElement", "TVViewElement"), ("TVViewElementStyle", "NSObject")])
                let types: [AnyClass] = [TVColor.self, TVMediaItem.self, TVPlaylist.self, TVImageElement.self, TVTextElement.self, TVViewElementStyle.self, TVBrowserTransitionAnimator.self]
                try expect(p.playlist == nil && p.currentMediaItem == nil && !ev.expectsReturnValue && ev.returnValue == nil && f === TVInterfaceFactory.shared() && rows.isEmpty
                           && vcs.allSatisfy { class_getSuperclass($0) == UIViewController.self } && types.count == 7, "\(rows)")
                return "player state \(p.state.rawValue), no playlist; custom event; element / style registered; shared interface factory; browser + document controller classes; \(types.count) element / media classes"
            }
        })
#endif
#if canImport(TVUIKit) && os(tvOS)
        c.append(check("TVUIKit", "p28-content-views") {
            try await onMain { () throws -> String in
                var mc = TVMediaItemContentConfiguration.wideCell()
                mc.text = "P28"; mc.secondaryText = "sdkcov"; mc.playbackProgress = 0.4; mc.badgeText = "LIVE"
                mc.badgeProperties = .liveContent()
                let tp = mc.textProperties, bp = mc.badgeProperties
                let mv = TVMediaItemContentView(configuration: mc)
                var gc = TVMonogramContentConfiguration.cell()
                var pn = PersonNameComponents(); pn.givenName = "Pat"; pn.familyName = "Doe"
                gc.text = "Pat"; gc.personNameComponents = pn
                let mtp = gc.textProperties
                // the ObjC classes under the Swift value types (NS_REFINED_FOR_SWIFT)
                let objc = p28tClasses([("TVMediaItemContentTextProperties", "NSObject"), ("TVMediaItemContentBadgeProperties", "NSObject"), ("TVMonogramContentTextProperties", "NSObject"),
                                        ("TVMediaItemContentView", "UIView"), ("TVMonogramContentView", "UIView")])
                let gv = TVMonogramContentView(configuration: gc)
                let att = TVCollectionViewFullScreenLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
                att.cornerRadius = 12; att.maskAmount = 0.5; att.normalizedPosition = -0.25
                mv.frame = CGRect(x: 0, y: 0, width: 400, height: 225); mv.layoutIfNeeded()
                let mvc = mv.configuration as? TVMediaItemContentConfiguration, gvc = gv.configuration as? TVMonogramContentConfiguration
                try expect(mvc?.text == "P28" && mvc?.playbackProgress == 0.4 && gvc?.text == "Pat" && att.maskAmount == 0.5
                           && objc.isEmpty && "\(tp)".count > 0 && "\(bp)".count > 0 && "\(mtp)".count > 0, "views \(objc)")
                return "media item view '\(mvc?.text ?? "")' progress 0.4 badge LIVE; monogram view; full-screen layout attributes; text / badge properties, 5 ObjC classes underneath"
            }
        })
#endif
#if canImport(TVServices) && os(tvOS)
        c.append(check("TVServices", "p28-content-items-profiles") {
            let parent = TVContentIdentifier(identifier: "p28-shelf", container: nil)
            let id = TVContentIdentifier(identifier: "p28-item", container: parent)
            let item = TVContentItem(contentIdentifier: id)
            item.title = "P28"; item.imageShape = .poster
            let ib = try p28tArchive(item) as? TVContentItem
            let prof = TVAppProfileDescriptor(name: "P28 profile")
            let pb = try p28tArchive(prof) as? TVAppProfileDescriptor
            let top: TVTopShelfObject = TVTopShelfItem(identifier: "p28-top")
            top.title = "Top"
            try expect(ib?.contentIdentifier.identifier == "p28-item" && ib?.contentIdentifier.container?.identifier == "p28-shelf" && pb?.name == "P28 profile" && top.title == "Top", "items")
            return "content item in a container round trip; app profile descriptor; top shelf object '\(top.title ?? "")'"
        })
#endif
#if canImport(UIKit) && os(tvOS)
        c.append(check("UIKit", "p28-tv-traits") {
            try await onMain { () throws -> String in
                let tc = UITraitCollection(userInterfaceStyle: .dark)
                var nav = "needs 27.2"
                if #available(tvOS 27.2, *) { nav = "\(UITraitNavigationTitleAlignment.name) = \(UITraitNavigationTitleAlignment.defaultValue.rawValue)" }
                let bridged = P28TBridgedKey.read(from: tc)
                let mac = p28tPresent(["UIBarButtonItemBadge"])
                try expect(bridged == 2, "bridged \(bridged)")
                return "bridged key reads \(bridged); \(nav); iOS-only badge class present \(mac.present.count)/1"
            }
        })
#endif
        return c
    }
}

// MARK: watchOS: WatchKit (alerts, picker items, images, audio file players, interface / background task classes),
// WatchConnectivity transfers, ClockKit gauge / widget migration

#if canImport(ClockKit) && os(watchOS)
struct P28TClockIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "P28"
    init() {}
}
#endif

extension Registry {
    static var p28tWatch: [Check] {
        var c: [Check] = []
#if canImport(WatchKit) && os(watchOS)
        c.append(check("WatchKit", "p28-objects-classes") {
            try await onMain { () throws -> String in
                var hit = 0
                let a = WKAlertAction(title: "OK", style: .default) { hit += 1 }
                let img = WKImage(imageData: Data())
                let pi = WKPickerItem(); pi.title = "P28"; pi.caption = "cap"; pi.contentImage = WKImage(imageName: "p28")
                let pib = try p28tArchive(pi) as? WKPickerItem
                let reg = WKAccessibilityImageRegion(); reg.frame = CGRect(x: 1, y: 2, width: 3, height: 4); reg.label = "face"
                // the audio file asset / player item / players are not made: on Apple's simulator the app hangs in
                // WKAudioFileAsset(url:title:albumTitle:artist:) (deprecated API, AVPlayer replaces it); their classes only
                let audio: [AnyClass] = [WKAudioFileAsset.self, WKAudioFilePlayerItem.self, WKAudioFilePlayer.self, WKAudioFileQueuePlayer.self]
                let ext: AnyClass = WKExtension.self
                let rows = p28tClasses([
                    ("WKInterfaceObject", "NSObject"), ("WKInterfaceButton", "WKInterfaceObject"), ("WKInterfaceDate", "WKInterfaceObject"), ("WKInterfaceGroup", "WKInterfaceObject"),
                    ("WKInterfaceImage", "WKInterfaceObject"), ("WKInterfaceInlineMovie", "WKInterfaceObject"), ("WKInterfaceLabel", "WKInterfaceObject"), ("WKInterfaceMovie", "WKInterfaceObject"),
                    ("WKInterfacePicker", "WKInterfaceObject"), ("WKInterfaceSeparator", "WKInterfaceObject"), ("WKInterfaceSlider", "WKInterfaceObject"), ("WKInterfaceSwitch", "WKInterfaceObject"),
                    ("WKInterfaceTable", "WKInterfaceObject"), ("WKInterfaceTextField", "WKInterfaceObject"), ("WKInterfaceTimer", "WKInterfaceObject"), ("WKInterfaceVolumeControl", "WKInterfaceObject"),
                    ("WKInterfaceActivityRing", "WKInterfaceObject"), ("WKInterfaceAuthorizationAppleIDButton", "WKInterfaceObject"), ("WKInterfaceHMCamera", "WKInterfaceObject"),
                    ("WKInterfacePaymentButton", "WKInterfaceObject"), ("WKInterfaceSCNScene", "WKInterfaceObject"), ("WKInterfaceSKScene", "WKInterfaceObject"),
                    ("WKInterfaceController", "NSObject"), ("WKUserNotificationInterfaceController", "WKInterfaceController"),
                    ("WKGestureRecognizer", "NSObject"), ("WKTapGestureRecognizer", "WKGestureRecognizer"), ("WKLongPressGestureRecognizer", "WKGestureRecognizer"),
                    ("WKSwipeGestureRecognizer", "WKGestureRecognizer"), ("WKPanGestureRecognizer", "WKGestureRecognizer"),
                    ("WKRefreshBackgroundTask", "NSObject"), ("WKApplicationRefreshBackgroundTask", "WKRefreshBackgroundTask"), ("WKSnapshotRefreshBackgroundTask", "WKRefreshBackgroundTask"),
                    ("WKURLSessionRefreshBackgroundTask", "WKRefreshBackgroundTask"), ("WKWatchConnectivityRefreshBackgroundTask", "WKRefreshBackgroundTask"),
                    ("WKBluetoothAlertRefreshBackgroundTask", "WKRefreshBackgroundTask"), ("WKIntentDidRunRefreshBackgroundTask", "WKRefreshBackgroundTask"),
                    ("WKRelevantShortcutRefreshBackgroundTask", "WKRefreshBackgroundTask")])
                // typed references to the same classes (the storyboard / system makes their instances)
                let typed: [AnyClass] = [WKInterfaceButton.self, WKInterfaceDate.self, WKInterfaceGroup.self, WKInterfaceImage.self, WKInterfaceInlineMovie.self, WKInterfaceLabel.self,
                    WKInterfaceMovie.self, WKInterfacePicker.self, WKInterfaceSeparator.self, WKInterfaceSlider.self, WKInterfaceSwitch.self, WKInterfaceTable.self, WKInterfaceTextField.self,
                    WKInterfaceTimer.self, WKInterfaceVolumeControl.self, WKInterfaceActivityRing.self, WKInterfaceAuthorizationAppleIDButton.self, WKInterfaceHMCamera.self,
                    WKInterfacePaymentButton.self, WKInterfaceSCNScene.self, WKInterfaceSKScene.self, WKInterfaceObject.self, WKInterfaceController.self, WKUserNotificationInterfaceController.self,
                    WKGestureRecognizer.self, WKTapGestureRecognizer.self, WKLongPressGestureRecognizer.self, WKSwipeGestureRecognizer.self, WKPanGestureRecognizer.self,
                    WKRefreshBackgroundTask.self, WKApplicationRefreshBackgroundTask.self, WKSnapshotRefreshBackgroundTask.self, WKURLSessionRefreshBackgroundTask.self,
                    WKWatchConnectivityRefreshBackgroundTask.self, WKBluetoothAlertRefreshBackgroundTask.self, WKIntentDidRunRefreshBackgroundTask.self, WKRelevantShortcutRefreshBackgroundTask.self]
                let flags = ["rows": rows.isEmpty, "typed": typed.count == 37, "picker": pib?.title == "P28" && pib?.caption == "cap", "region": reg.label == "face",
                              "audio": class_getSuperclass(audio[3]) == audio[2],
                             "alert": a.isKind(of: WKAlertAction.self), "ext": NSStringFromClass(ext) == "WKExtension"]
                try expect(!flags.values.contains(false), "\(rows) false: \(flags.filter { !$0.value }.keys.sorted())")
                return "alert action, image (\(img.imageData?.count ?? -1) B), picker item round trip, image region; audio asset / player item / player / queue player classes; \(typed.count) interface / gesture / background task classes"
            }
        })
#endif
#if canImport(WatchConnectivity) && (os(watchOS) || os(iOS))
        c.append(check("WatchConnectivity", "p28-transfer-classes") {
            let types: [AnyClass] = [WCSessionFile.self, WCSessionFileTransfer.self, WCSessionUserInfoTransfer.self]
            var transfers = "session not supported"
            if WCSession.isSupported() {
                let s = WCSession.default
                transfers = "state \(s.activationState.rawValue), \(s.outstandingFileTransfers.count) file / \(s.outstandingUserInfoTransfers.count) user info transfers"
            }
            try expect(types.map { NSStringFromClass($0) } == ["WCSessionFile", "WCSessionFileTransfer", "WCSessionUserInfoTransfer"], "\(types)")
            return "file / file transfer / user info transfer classes; \(transfers)"
        })
#endif
#if canImport(ClockKit) && os(watchOS)
        c.append(check("ClockKit", "p28-widget-migration") {
            let m = CLKComplicationAppIntentWidgetMigrationConfiguration(kind: "p28.widget", extensionBundleIdentifier: "com.x86sim.test.sdkcov.widget", intent: P28TClockIntent(), localizedDisplayName: "P28")
            let base: CLKComplicationWidgetMigrationConfiguration = m
            try expect(m.kind == "p28.widget" && m.localizedDisplayName == "P28" && m.extensionBundleIdentifier.hasSuffix(".widget") && base === m, "migration")
            return "app intent widget migration for kind \(m.kind) (\(NSStringFromClass(type(of: base))))"
        })
#endif
        return c
    }
}

// MARK: visionOS: QuickLook preview items, WebKit immersive environments, CompositorServices configuration errors

extension Registry {
    static var p28tVision: [Check] {
        var c: [Check] = []
#if canImport(QuickLook) && os(visionOS)
        c.append(check("QuickLook", "p28-preview-items") {
            let u = FileManager.default.temporaryDirectory.appendingPathComponent("p28.txt")
            let a = PreviewItem(url: u, displayName: "P28", editingMode: .createCopy), b = PreviewItem(url: u)
            let s = p28tName(PreviewSession.self)
            try expect(a != b && a.displayName == "P28" && b.displayName == nil && Set([a, b, a]).count == 2 && s == "QuickLook.PreviewSession", s)
            return "preview items (copy / default editing), \(s) (not opened: a window)"
        })
#endif
#if canImport(WebKit) && os(visionOS)
        c.append(check("WebKit", "p28-immersive-environment") {
            let cls: AnyClass = WKImmersiveEnvironment.self
            let has = class_getInstanceMethod(cls, NSSelectorFromString("sourceFrame")) != nil
            try expect(has, "sourceFrame")
            return "WKImmersiveEnvironment (made by WebKit for a page's immersive request) with sourceFrame"
        })
#endif
#if canImport(CompositorServices) && os(visionOS)
        c.append(check("CompositorServices", "p28-configuration-errors") {
            let all: [LayerRendererConfigurationError] = [.missingConfiguration, .unsupportedColorFormat, .unsupportedColorUsage, .unsupportedDepthFormat, .unsupportedDepthUsage,
                                                          .variableRasterizationRateIsNotSupported, .temporalAntiAliasingNotSupported, .notEnoughFramesRequested]
            try expect(all.map(\.rawValue) == Array(all.first!.rawValue..<all.first!.rawValue + all.count) || Set(all.map(\.rawValue)).count == all.count, "\(all.map(\.rawValue))")
            return "\(all.count) errors, raw \(all.map(\.rawValue)), first: \(all[0].errorDescription ?? "nil")"
        })
#endif
        return c
    }
}
