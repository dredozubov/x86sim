// SDK coverage, round 30 (P27): public API of the SDK not yet referenced by any check (~/scratch/r30/apisurf.py),
// area: Data. Each check asserts what Apple's simulator answers (ref-mac.sh --only).
import Foundation
import ObjectiveC
#if canImport(Matter)
import Matter
#endif
#if canImport(CloudKit)
import CloudKit
import CoreLocation
#endif
#if canImport(CoreData)
import CoreData
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if canImport(NetworkExtension)
import NetworkExtension
#endif
#if canImport(MetricKit) && os(iOS)
import MetricKit
#endif
#if canImport(Network)
import Network
#endif
#if canImport(CryptoTokenKit)
import CryptoTokenKit
#endif
#if canImport(StoreKit)
import StoreKit
#endif
#if canImport(PassKit)
import PassKit
#endif
#if canImport(FinanceKit) && os(iOS)
import FinanceKit
#endif
#if canImport(ProximityReader) && os(iOS)
import ProximityReader
#endif
#if canImport(CoreSpotlight)
import CoreSpotlight
#endif
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif
#if canImport(BackgroundAssets)
import BackgroundAssets
#endif
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif
#if canImport(FileProvider) && (os(iOS) || os(visionOS))
import FileProvider
#endif
#if canImport(SwiftData)
import SwiftData
import Observation
#endif

/// o is an instance of the Objective-C class named cls (the name Swift renames or refines away)
func p27Is(_ o: Any, _ cls: String) -> Bool {
    guard let c = NSClassFromString(cls) else { return false }
    return (o as AnyObject).isKind(of: c)
}
/// classes only a framework makes (results, events, extension principal classes): each present at run time and a
/// subclass of the given class; returns the ones that are not
func p27Hierarchy(_ list: [(String, String)]) -> [String] {
    list.compactMap { (name, sup) in
        guard let c = NSClassFromString(name) else { return "\(name) missing" }
        guard let s = NSClassFromString(sup) else { return "\(sup) missing" }
        var k: AnyClass? = c
        while let x = k { if x == s { return nil }; k = class_getSuperclass(x) }
        return "\(name) not a \(sup)"
    }
}

// MARK: Matter helpers: the generated value / cluster classes driven through the Objective-C runtime (their
// properties set and read back through the declared getter / setter, NSCopying, description)
#if canImport(Matter)
private struct P27Prop { let name: String, type: String, readonly: Bool, getter: String, setter: String }
private func p27Props(_ cls: AnyClass) -> [P27Prop] {
    var out: [P27Prop] = [], seen = Set<String>()
    var k: AnyClass? = cls
    while let c = k, c != NSObject.self {
        var n: UInt32 = 0
        if let l = class_copyPropertyList(c, &n) {
            for i in 0..<Int(n) {
                let name = String(cString: property_getName(l[i]))
                guard seen.insert(name).inserted, let a = property_getAttributes(l[i]) else { continue }
                var type = "", ro = false, g = name, s = "set" + name.prefix(1).uppercased() + name.dropFirst() + ":"
                for part in String(cString: a).split(separator: ",") {
                    switch part.first {
                    case "T": type = String(part.dropFirst())
                    case "R": ro = true
                    case "G": g = String(part.dropFirst())
                    case "S": s = String(part.dropFirst())
                    default: break
                    }
                }
                out.append(P27Prop(name: name, type: type, readonly: ro, getter: g, setter: s))
            }
            free(l)
        }
        k = class_getSuperclass(c)
    }
    return out
}
/// a value for an object property of type `t` (T@"NSNumber" ...), nil for scalars / ids / blocks
private func p27Value(_ t: String, _ i: Int) -> AnyObject? {
    guard t.hasPrefix("@\""), t.count > 3 else { return nil }
    let cn = String(t.dropFirst(2).dropLast())
    switch cn {
    case "NSNumber": return NSNumber(value: 40 + i)
    case "NSString": return "sdkcov\(i)" as NSString
    case "NSData": return Data([UInt8(i & 0xff), 0x86]) as NSData
    case "NSArray": return [NSNumber(value: i)] as NSArray
    case "NSDictionary": return ["k": NSNumber(value: i)] as NSDictionary
    default:
        guard cn.hasPrefix("MTR"), let c = NSClassFromString(cn) as? NSObject.Type else { return nil }
        return c.init()
    }
}
private func p27Same(_ a: AnyObject?, _ b: AnyObject?) -> Bool {
    if a == nil || b == nil { return a == nil && b == nil }
    if let x = a as? NSObject, let y = b as? NSObject, x.isEqual(y) { return true }
    // nested Matter structs are copied (copy properties) and have no -isEqual:: the same class
    // (or a deprecated alias of a struct class, read back as its replacement: one a subclass of the other)
    let ta: AnyClass = type(of: a!), tb: AnyClass = type(of: b!)
    return NSStringFromClass(ta).hasPrefix("MTR") && (ta == tb || ta.isSubclass(of: tb) || tb.isSubclass(of: ta))
}
private func p27Get(_ o: NSObject, _ p: P27Prop) -> AnyObject? {
    o.perform(NSSelectorFromString(p.getter))?.takeUnretainedValue()
}
private struct P27MatterTally {
    var classes = 0, missing: [String] = [], built = 0, props = 0, propsSet = 0, scalars = 0, copies = 0, copyDiff: [String] = []
    var described = 0, named = 0, bad: [String] = [], copyReplacement = 0
}
private func p27MatterValues(_ names: [String]) -> P27MatterTally {
    var t = P27MatterTally()
    for name in names {
        t.classes += 1
        guard let cls = NSClassFromString(name) as? NSObject.Type else { t.missing.append(name); continue }
        var obj: NSObject?
        if let e = SDKCovCatch({ obj = cls.init() }) { t.bad.append("\(name) init \(e)"); continue }
        guard let o = obj else { t.bad.append("\(name) init nil"); continue }
        t.built += 1
        let props = p27Props(cls)
        var vals: [String: AnyObject] = [:]
        for (i, p) in props.enumerated() {
            t.props += 1
            guard !p.readonly, let v = p27Value(p.type, i) else { t.scalars += 1; continue }
            guard o.responds(to: NSSelectorFromString(p.setter)), o.responds(to: NSSelectorFromString(p.getter)) else { t.bad.append("\(name).\(p.name) no accessors"); continue }
            var got: AnyObject?
            if let e = SDKCovCatch({ o.perform(NSSelectorFromString(p.setter), with: v); got = p27Get(o, p) }) { t.bad.append("\(name).\(p.name) \(e)"); continue }
            if p27Same(got, v) { t.propsSet += 1; vals[p.name] = v } else { t.bad.append("\(name).\(p.name) set \(v) read \(String(describing: got))") }
        }
        if o.conforms(to: NSCopying.self) {
            var cp: NSObject?
            if let e = SDKCovCatch({ cp = o.copy() as? NSObject }) { t.bad.append("\(name) copy \(e)"); continue }
            // a deprecated alias class (MTRBackwardsCompatShims.h, a subclass of its replacement) copies to the replacement
            let replacement = cp.map { type(of: $0) != cls && cls.isSubclass(of: type(of: $0)) } ?? false
            if replacement { t.copyReplacement += 1 }
            if let cp, type(of: cp) == cls || replacement {
                // every readable property of the copy equals the original's (aliases of deprecated names included)
                let diff = props.filter { p in p27Value(p.type, 0) != nil && !p27Same(p27Get(cp, p), p27Get(o, p)) }.map(\.name)
                if diff.isEmpty { t.copies += 1 } else { t.copyDiff.append("\(name): \(diff)") }
            } else { t.bad.append("\(name) copy is \(String(describing: cp.map { type(of: $0) }))") }
        }
        let d = o.description
        if !d.isEmpty { t.described += 1 }
        if d.contains(name) { t.named += 1 }
    }
    return t
}
/// a running storage-based controller (as P10's device-controller-start-shutdown) for the cluster objects' devices
private func p27MatterController() throws -> MTRDeviceController {
    let root = P5MatterKey(), node = P5MatterKey()
    let validity = DateInterval(start: Date(timeIntervalSinceNow: -60), duration: 365 * 86400)
    let rootDER = try MTRCertificates.createRootCertificate(root, issuerID: 1, fabricID: 0xFAB2, validityPeriod: validity)
    let opDER = try MTRCertificates.createOperationalCertificate(root, signingCertificate: rootDER, operationalPublicKey: node.pub, fabricID: 0xFAB2, nodeID: 0x2727,
                                                                  caseAuthenticatedTags: nil, validityPeriod: validity)
    let p = MTRDeviceControllerExternalCertificateParameters(storageDelegate: P10MatterStore(), storageDelegateQueue: DispatchQueue(label: "sdkcov.p27.matter.store"),
                                                             uniqueIdentifier: UUID(), ipk: Data(repeating: 9, count: 16), vendorID: 0xFFF1, operationalKeypair: node,
                                                             operationalCertificate: opDER, intermediateCertificate: nil, rootCertificate: rootDER)
    return try MTRDeviceController(parameters: p)
}
#endif

// MARK: CoreData helpers: a model built in code, an atomic store and an incremental store (both in memory), a
// migration policy that counts the instances it makes
#if canImport(CoreData)
func p27Model(extra: Bool = false, unique: Bool = false) -> NSManagedObjectModel {
    let e = NSEntityDescription(); e.name = "Item"; e.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
    let name = NSAttributeDescription(); name.name = "name"; name.attributeType = .stringAttributeType; name.isOptional = true
    let n = NSAttributeDescription(); n.name = "n"; n.attributeType = .integer64AttributeType; n.defaultValue = 0
    var props: [NSPropertyDescription] = [name, n]
    if extra { let x = NSAttributeDescription(); x.name = "note"; x.attributeType = .stringAttributeType; x.isOptional = true; props.append(x) }
    // a fetched property: the other items with the same n
    let fp = NSFetchedPropertyDescription(); fp.name = "peers"
    let fr = NSFetchRequest<NSFetchRequestResult>(); fr.entity = e; fr.predicate = NSPredicate(format: "n == $FETCH_SOURCE.n")
    fp.fetchRequest = fr; props.append(fp)
    e.properties = props
    let idx = NSFetchIndexDescription(name: "byName", elements: [NSFetchIndexElementDescription(property: name, collationType: .binary)])
    e.indexes = [idx]
    if unique { e.uniquenessConstraints = [["name"]] }
    let m = NSManagedObjectModel(); m.entities = [e]
    return m
}
final class P27AtomicStore: NSAtomicStore {
    static let type = NSStringFromClass(P27AtomicStore.self)
    nonisolated(unsafe) static var saves = 0
    override func load() throws {}
    override func save() throws { P27AtomicStore.saves += 1 }
    override func newReferenceObject(for managedObject: NSManagedObject) -> Any { UUID().uuidString }
    override func newCacheNode(for managedObject: NSManagedObject) -> NSAtomicStoreCacheNode {
        let node = NSAtomicStoreCacheNode(objectID: managedObject.objectID)
        updateCacheNode(node, from: managedObject); return node
    }
    override func updateCacheNode(_ node: NSAtomicStoreCacheNode, from managedObject: NSManagedObject) {
        let vals = NSMutableDictionary()
        for k in managedObject.entity.attributesByName.keys { if let v = managedObject.value(forKey: k) { vals[k] = v } }
        node.propertyCache = vals
    }
    override var type: String { P27AtomicStore.type }
    override var metadata: [String: Any]! {
        get { [NSStoreTypeKey: P27AtomicStore.type, NSStoreUUIDKey: "p27-atomic"] }
        set {}
    }
}
/// a dictionary-backed incremental store: saves arrive as NSSaveChangesRequest, values go out as NSIncrementalStoreNode
final class P27IncStore: NSIncrementalStore {
    static let type = NSStringFromClass(P27IncStore.self)
    nonisolated(unsafe) static var saveRequests = 0, nodes = 0
    private var rows: [String: [String: Any]] = [:]
    override func loadMetadata() throws { metadata = [NSStoreTypeKey: P27IncStore.type, NSStoreUUIDKey: "p27-inc"] }
    override func execute(_ request: NSPersistentStoreRequest, with context: NSManagedObjectContext?) throws -> Any {
        if let save = request as? NSSaveChangesRequest {
            P27IncStore.saveRequests += 1
            for o in (save.insertedObjects ?? []).union(save.updatedObjects ?? []) {
                rows[referenceObject(for: o.objectID) as! String] = o.dictionaryWithValues(forKeys: Array(o.entity.attributesByName.keys))
            }
            for o in save.deletedObjects ?? [] { rows[referenceObject(for: o.objectID) as! String] = nil }
            return [Any]()
        }
        if let fetch = request as? NSFetchRequest<NSFetchRequestResult>, let e = fetch.entity, let ctx = context {
            let ids = rows.keys.sorted().map { newObjectID(for: e, referenceObject: $0) }
            if fetch.resultType == .countResultType { return [ids.count] }
            return ids.map { ctx.object(with: $0) }
        }
        throw NSError(domain: "p27", code: 1)
    }
    override func newValuesForObject(with objectID: NSManagedObjectID, with context: NSManagedObjectContext) throws -> NSIncrementalStoreNode {
        P27IncStore.nodes += 1
        return NSIncrementalStoreNode(objectID: objectID, withValues: rows[referenceObject(for: objectID) as! String] ?? [:], version: 1)
    }
    override func obtainPermanentIDs(for array: [NSManagedObject]) throws -> [NSManagedObjectID] {
        array.map { newObjectID(for: $0.entity, referenceObject: UUID().uuidString) }
    }
}
final class P27Policy: NSEntityMigrationPolicy {
    nonisolated(unsafe) static var made = 0
    override func createDestinationInstances(forSource sInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)
        P27Policy.made += 1
        for d in manager.destinationInstances(forEntityMappingName: mapping.name, sourceInstances: [sInstance]) { d.setValue("migrated", forKey: "note") }
    }
}
#endif

#if canImport(Matter)
final class P27CommissioningDelegate: NSObject, MTRCommissioningDelegate {
    func commissioning(_ commissioning: MTRCommissioningOperation, completedDeviceAttestation attestationDeviceInfo: MTRDeviceAttestationDeviceInfo, error: (any Error)?, completion: @escaping () -> Void) { completion() }
}
#endif

#if canImport(Network)
/// a pass-through framer for Network's Framer<T> (FramerProtocol)
final class P27FramerImpl: NWProtocolFramerImplementation {
    static let label = "p27"
    static let definition = NWProtocolFramer.Definition(implementation: P27FramerImpl.self)
    required init(framer: NWProtocolFramer.Instance) {}
    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult { .ready }
    func handleInput(framer: NWProtocolFramer.Instance) -> Int { 0 }
    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {}
    func wakeup(framer: NWProtocolFramer.Instance) {}
    func stop(framer: NWProtocolFramer.Instance) -> Bool { true }
    func cleanup(framer: NWProtocolFramer.Instance) {}
}
struct P27Framer: FramerProtocol {
    static var definition: NWProtocolFramer.Definition { P27FramerImpl.definition }
}
#endif

#if canImport(SwiftData)
/// @Model written out (Data.swift's SDNote shape) with a title preserved on deletion: history tombstones carry it
final class P27Doc: PersistentModel {
    private var _$backingData: any SwiftData.BackingData<P27Doc> = P27Doc.createBackingData()
    private let _$observationRegistrar = Observation.ObservationRegistrar()
    var persistentBackingData: any SwiftData.BackingData<P27Doc> { get { _$backingData } set { _$backingData = newValue } }
    static var schemaMetadata: [SwiftData.Schema.PropertyMetadata] {
        [.init(name: "title", keypath: \P27Doc.title, defaultValue: nil, metadata: Schema.Attribute(.preserveValueOnDeletion)), .init(name: "n", keypath: \P27Doc.n)]
    }
    required init(backingData: any SwiftData.BackingData<P27Doc>) { _$backingData = backingData }
    init(title: String, n: Int) { self.title = title; self.n = n }
    var title: String {
        get { _$observationRegistrar.access(self, keyPath: \.title); return getValue(forKey: \.title) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.title) { setValue(forKey: \.title, to: newValue) } }
    }
    var n: Int {
        get { _$observationRegistrar.access(self, keyPath: \.n); return getValue(forKey: \.n) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.n) { setValue(forKey: \.n, to: newValue) } }
    }
}
extension P27Doc: Observation.Observable {}
#endif

extension Registry {
    static var p27data: [Check] {
        var c: [Check] = []
        // MARK: Matter: every cluster struct / command payload / event class: built, each object property set and read
        // back through its declared accessors, copied (NSCopying: the copy's properties equal), described
        #if canImport(Matter)
        c.append(check("Matter", "p27-value-classes", timeout: 60) {
            let names = p27MatterValueClasses.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init)
            let t = p27MatterValues(names)
            let d = "\(t.classes) classes, \(t.missing.count) missing \(t.missing.prefix(4)), \(t.built) built; \(t.propsSet)/\(t.props) properties set+read (\(t.scalars) scalar/read-only); " +
                    "\(t.copies) copies equal (\(t.copyReplacement) to the replacement class), \(t.copyDiff.count) differ \(t.copyDiff.prefix(3)); \(t.described) described (\(t.named) name the class); \(t.bad.count) bad \(t.bad.prefix(12))"
            // Apple's simulator: two -copyWithZone:s leave a property out (KeySetReadAllIndicesParams.groupKeySetIDs,
            // AttestationResponseParams.attestationChallenge): the copies differ there, as on x86Sim
            let knownDiff = ["MTRGroupKeyManagementClusterKeySetReadAllIndicesParams: [\"groupKeySetIDs\"]", "MTROperationalCredentialsClusterAttestationResponseParams: [\"attestationChallenge\"]"]
            try expect(t.missing.isEmpty && t.built == t.classes && t.bad.isEmpty && t.copyDiff == knownDiff && t.described == t.built, d)
            return d
        })
        // every cluster class (MTRBaseCluster* on an MTRBaseDevice, MTRCluster* on an MTRDevice) made with
        // -initWithDevice:endpointID:queue: for node 0x55 of a running controller: endpoint and device read back
        c.append(check("Matter", "p27-cluster-classes", timeout: 60) {
            let ctl = try p27MatterController()
            defer { ctl.shutdown() }
            let base = MTRBaseDevice(nodeID: 0x55, controller: ctl), dev = MTRDevice(nodeID: 0x55, controller: ctl)
            let q = DispatchQueue(label: "sdkcov.p27.matter.clusters")
            typealias Init = @convention(c) (AnyObject, Selector, AnyObject, NSNumber, DispatchQueue) -> Unmanaged<AnyObject>?
            let sel = NSSelectorFromString("initWithDevice:endpointID:queue:")
            var n = 0, made = 0, ep = 0, devOK = 0, missing: [String] = [], bad: [String] = []
            for name in p27MatterClusterClasses.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init) {
                n += 1
                guard let cls = NSClassFromString(name), let m = class_getInstanceMethod(cls, sel) else { missing.append(name); continue }
                let f = unsafeBitCast(method_getImplementation(m), to: Init.self)
                let isBase = name.hasPrefix("MTRBaseCluster")
                var obj: AnyObject?
                let e = SDKCovCatch {
                    guard let raw = (cls as AnyObject).perform(NSSelectorFromString("alloc"))?.takeUnretainedValue() else { return }
                    obj = f(raw, sel, isBase ? base : dev, 2, q)?.takeRetainedValue()
                }
                guard e == nil, let o = obj as? MTRCluster else { bad.append("\(name) \(e ?? ["nil"])"); continue }
                made += 1
                if (o.perform(NSSelectorFromString("endpointID"))?.takeUnretainedValue() as? NSNumber) == 2 { ep += 1 }
                if isBase ? o.isKind(of: MTRGenericBaseCluster.self) : ((o as? MTRGenericCluster)?.device === dev) { devOK += 1 }
            }
            let d = "\(n) cluster classes, \(missing.count) missing \(missing.prefix(4)), \(made) made, endpoint 2 \(ep), device / generic base \(devOK); bad \(bad.prefix(4))"
            try expect(missing.isEmpty && made == n && ep == n && devOK == n, d)
            return d
        })
        #endif
        // MARK: Matter: the model objects around the clusters: request / cluster / command / event paths, a server endpoint
        // with clusters, attributes and access grants, device types, setup payload parsers round-tripping codes, a Thread
        // operational dataset through its TLV, OTA header parsing, attribute / event reports from response values,
        // certificate chain / CSR info, storage behavior and commissioning parameters, controller parameter classes
        #if canImport(Matter)
        c.append(check("Matter", "p27-model-objects", timeout: 30) {
            var n = 0
            func objc(_ o: AnyObject?, _ cls: String) throws { n += 1; try expect(o != nil && p27Is(o!, cls), "\(String(describing: o.map { type(of: $0) })) is not \(cls)") }
            let arp = MTRAttributeRequestPath(endpointID: 1, clusterID: 6, attributeID: nil)
            let erp = MTREventRequestPath(endpointID: nil, clusterID: 0x28, eventID: 0)
            let cp = MTRClusterPath(endpointID: 1, clusterID: 6), cmd = MTRCommandPath(endpointID: 1, clusterID: 6, commandID: 2), ev = MTREventPath(endpointID: 0, clusterID: 0x28, eventID: 0)
            try objc(arp, "MTRAttributeRequestPath"); try objc(erp, "MTREventRequestPath"); try objc(cp, "MTRClusterPath"); try objc(cmd, "MTRCommandPath"); try objc(ev, "MTREventPath")
            try expect(arp.attribute == nil && erp.endpoint == nil && cmd.command == 2 && cmd.cluster == 6 && ev.event == 0 && cp.isEqual(MTRClusterPath(endpointID: 1, clusterID: 6)), "paths")
            let req = MTRCommandWithRequiredResponse(path: cmd, commandFields: nil, requiredResponse: nil)
            try objc(req, "MTRCommandWithRequiredResponse"); try expect(req.path == cmd, "command with required response")
            // a server endpoint: a cluster with an attribute and grants
            let grant = MTRAccessGrant(forNodeID: 0x1234, privilege: .operate), all = MTRAccessGrant(forAllNodesWith: .view)
            try objc(grant, "MTRAccessGrant"); try expect(grant?.subjectID == 0x1234 && grant?.authenticationMode == .CASE && all.grantedPrivilege == .view, "grants")
            let attr = MTRServerAttribute(readonlyAttributeWithID: 0x0000, initialValue: [MTRTypeKey: MTRUnsignedIntegerValueType, MTRValueKey: 7], requiredPrivilege: .view)
            try objc(attr, "MTRServerAttribute")
            let cluster = MTRServerCluster(clusterID: 0xFFF1_FC01, revision: 1)
            try objc(cluster, "MTRServerCluster")
            let added = cluster.map { c in attr.map { c.addAttribute($0) } ?? false } ?? false
            if let grant { cluster?.addAccessGrant(grant) }
            let dtr = MTRDeviceTypeRevision(deviceTypeID: 0x0100, revision: 3)
            try objc(dtr, "MTRDeviceTypeRevision")
            let ep = MTRServerEndpoint(endpointID: 2, deviceTypes: dtr.map { [$0] } ?? [])
            try objc(ep, "MTRServerEndpoint")
            let epAdded = cluster.map { ep?.addServerCluster($0) ?? false } ?? false
            try expect(added && epAdded && ep?.serverClusters.count == 1 && cluster?.accessGrants.count == 1 && cluster?.attributes.count == 1, "server endpoint")
            let dt = MTRDeviceType(forID: 0x0100)
            try objc(dt, "MTRDeviceType"); try expect(dt?.name == "On/Off Light" && dtr?.typeInformation?.name == dt?.name, "device type \(String(describing: dt?.name))")
            let pid = MTRProductIdentity(vendorID: 0xFFF1, productID: 0x8000)
            try objc(pid, "MTRProductIdentity")
            // setup payload parsers
            let payload = MTRSetupPayload(setupPasscode: 20202021, discriminator: 3840)
            let manual = payload.manualEntryCode() ?? ""
            let parsedManual = try MTRManualSetupPayloadParser(decimalStringRepresentation: manual).populatePayload()
            let qr = payload.qrCodeString() ?? ""
            let parsedQR = try MTRQRCodeSetupPayloadParser(base38Representation: qr).populatePayload()
            let onboarding = try MTROnboardingPayloadParser.setupPayload(forOnboardingPayload: qr)
            try expect(parsedManual.setupPasscode == 20202021 && parsedQR.discriminator == 3840 && onboarding.setupPasscode == 20202021, "parsers: manual \(manual), QR \(qr)")
            let opt = MTROptionalQRCodeInfo(tag: 0x80, stringValue: "p27")
            try objc(opt, "MTROptionalQRCodeInfo"); try expect(opt.stringValue == "p27" && opt.type == .string, "optional QR info")
            // Thread dataset through its TLV
            let ds = MTRThreadOperationalDataset(networkName: "p27", extendedPANID: Data(repeating: 0x11, count: 8), masterKey: Data(repeating: 0x22, count: 16),
                                                 psKc: Data(repeating: 0x33, count: 16), channelNumber: 15, panID: Data([0x12, 0x34]))
            let ds2 = ds.flatMap { MTRThreadOperationalDataset(data: $0.data()) }
            try objc(ds2, "MTRThreadOperationalDataset"); try expect(ds2?.networkName == "p27" && ds2?.channelNumber == 15 && ds2?.panID == Data([0x12, 0x34]), "Thread dataset")
            // OTA header: junk is rejected
            var ota = ""
            do { let h: MTROTAHeader = try MTROTAHeaderParser.header(from: Data([1, 2, 3])); ota = "parsed \(h.vendorID)" } catch { ota = "threw \(p3Err(error))" }
            try expect(ota.hasPrefix("threw"), "OTA header \(ota)")
            // reports from response values
            let ap = MTRAttributePath(endpointID: 1, clusterID: 6, attributeID: 0)
            let rep = try MTRAttributeReport(responseValue: [MTRAttributePathKey: ap, MTRDataKey: [MTRTypeKey: MTRBooleanValueType, MTRValueKey: true]])
            try objc(rep, "MTRAttributeReport"); try expect(rep.path == ap && (rep.value as? NSNumber) == true && rep.error == nil, "attribute report \(String(describing: rep.value))")
            var evRep = ""
            do { let r = try MTREventReport(responseValue: [MTREventPathKey: ev, MTREventNumberKey: 9, MTREventPriorityKey: 1, MTREventTimeTypeKey: 1, MTREventSystemUpTimeKey: 2.0,
                                                           MTRDataKey: [MTRTypeKey: MTRStructureValueType, MTRValueKey: [Any]()]]); evRep = "event \(r.eventNumber)" } catch { evRep = "threw \(p3Err(error))" }
            // certificate chain / CSR / attestation info
            let chain = MTROperationalCertificateChain(operationalCertificate: Data([1]), intermediateCertificate: nil, rootCertificate: Data([2]), adminSubject: 0x55)
            try objc(chain, "MTROperationalCertificateChain"); try expect(chain.adminSubject == 0x55, "chain")
            let csrOld = CSRInfo(nonce: Data([1]), elements: Data([2]), elementsSignature: Data([3]), csr: Data([4]))
            let attOld = AttestationInfo(challenge: Data([1]), nonce: Data([2]), elements: Data([3]), elementsSignature: Data([4]), dac: Data([5]), pai: Data([6]), certificationDeclaration: Data([7]), firmwareInfo: Data())
            try objc(csrOld, "CSRInfo"); try objc(attOld, "AttestationInfo")
            let csrNew = MTROperationalCSRInfo(csrElementsTLV: Data([0x15, 0x18]), attestationSignature: Data(repeating: 0, count: 64))
            // storage behavior, commissioning parameters, controller parameters
            let sb = MTRDeviceStorageBehaviorConfiguration(); sb.disableStorageBehaviorOptimization = true
            try objc(sb, "MTRDeviceStorageBehaviorConfiguration"); try expect(sb.disableStorageBehaviorOptimization, "storage behavior")
            let cpar = MTRCommissioningParameters(); cpar.failSafeTimeout = 60; cpar.countryCode = "US"; cpar.extraAttributesToRead = [arp]
            try objc(cpar, "MTRCommissioningParameters"); try expect(cpar.failSafeTimeout == 60 && cpar.extraAttributesToRead?.count == 1, "commissioning parameters")
            let op = MTRCommissioningOperation(parameters: cpar, setupPayload: qr, delegate: P27CommissioningDelegate(), queue: .main)
            try objc(op, "MTRCommissioningOperation")
            let xpc = MTRXPCDeviceControllerParameters(xpcConnectionBlock: { NSXPCConnection(listenerEndpoint: NSXPCListener.anonymous().endpoint) }, uniqueIdentifier: UUID())
            try objc(xpc, "MTRXPCDeviceControllerParameters"); try objc(xpc, "MTRDeviceControllerAbstractParameters")
            let rp = MTRReadParams(); rp.shouldFilterByFabric = false
            let sp = MTRSubscribeParams(minInterval: 1, maxInterval: 10); sp.shouldResubscribeAutomatically = false
            let wp = MTRWriteParams(); wp.timedWriteTimeout = 100
            try objc(rp, "MTRReadParams"); try objc(sp, "MTRSubscribeParams"); try objc(wp, "MTRWriteParams")
            try expect(sp.maxInterval == 10 && !sp.shouldResubscribeAutomatically && wp.timedWriteTimeout == 100, "interaction params")
            let factory = MTRDeviceControllerFactory.sharedInstance()
            try objc(factory, "MTRDeviceControllerFactory")   // running once any controller started (the cluster check's)
            // classes the stack hands out
            let made: [(String, String)] = [("MTRAsyncCallbackWorkQueue", "NSObject"), ("MTRAsyncCallbackQueueWorkItem", "NSObject"), ("MTRAttributeCacheContainer", "NSObject"),
                ("MTRClusterStateCacheContainer", "NSObject"), ("MTRAttributeValueWaiter", "NSObject"), ("MTRCommissionableBrowserResult", "NSObject"), ("MTRCommissioneeInfo", "NSObject"),
                ("MTRDeviceAttestationDeviceInfo", "NSObject"), ("MTRDeviceAttestationInfo", "NSObject"), ("MTRDistinguishedNameInfo", "NSObject"), ("MTREndpointInfo", "NSObject"),
                ("MTRFabricInfo", "NSObject"), ("MTRNetworkInterfaceInfo", "NSObject"), ("MTRMetrics", "NSObject"), ("MTRMetricData", "NSObject"), ("MTRControllerFactory", "NSObject"),
                ("MTRControllerFactoryParams", "MTRDeviceControllerFactoryParams"), ("MTRDeviceControllerFactoryParams", "NSObject"), ("MTRDeviceControllerStartupParams", "NSObject"),
                ("MTRDeviceControllerParameters", "MTRDeviceControllerAbstractParameters")]
            let wrong = p27Hierarchy(made)
            try expect(wrong.isEmpty, "classes \(wrong)")
            return "\(n) objects of their class; manual \(manual), QR \(qr); OTA \(ota); event report \(evRep); CSR info \(csrNew == nil ? "rejected" : "made"); \(made.count) classes"
        })
        #endif
        // MARK: CloudKit: the identifiers, references, subscriptions, notification info, operation configuration and
        // every operation class configured offline (their Objective-C classes asserted, their properties read back), the
        // sync engine's value types, and the classes only CloudKit hands out (asserted to exist with their superclass)
        #if canImport(CloudKit)
        c.append(check("CloudKit", "p27-objects-operations", timeout: 30) {
            var n = 0
            func objc(_ o: AnyObject, _ cls: String) throws { n += 1; try expect(p27Is(o, cls), "\(type(of: o)) is not \(cls)") }
            let zid = CKRecordZone.ID(zoneName: "p27", ownerName: CKCurrentUserDefaultName)
            try objc(zid, "CKRecordZoneID")
            let rid = CKRecord.ID(recordName: "r1", zoneID: zid)
            try objc(rid, "CKRecordID")
            try expect(rid.zoneID == zid && rid.recordName == "r1", "record id")
            let ref = CKRecord.Reference(recordID: rid, action: .deleteSelf)
            try objc(ref, "CKReference")
            let rec = CKRecord(recordType: "Doc", recordID: rid)
            // CKRecordValueProtocol: the value types a record field takes, read back through the protocol
            let fields: [(String, any CKRecordValueProtocol)] = [("s", "x" as NSString), ("n", NSNumber(value: 7)), ("d", Date(timeIntervalSince1970: 9) as NSDate), ("b", Data([1]) as NSData)]
            for (k, v) in fields { rec[k] = v }
            try expect((rec["n"] as? NSNumber)?.intValue == 7 && rec.allKeys().count == 4, "record values")
            // CKRecordKeyValueIterator: the record's key-value pairs through the Swift sequence
            var it: CKRecordKeyValueIterator = rec.makeIterator()
            var keys: [String] = []
            while let (k, _) = it.next() { keys.append(k) }
            try expect(Set(keys) == ["s", "n", "d", "b"], "iterated \(keys)")
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("p27-asset.bin")
            try Data(repeating: 1, count: 64).write(to: file)
            let asset = CKAsset(fileURL: file)
            try objc(asset, "CKAsset"); try expect(asset.fileURL == file, "asset url")
            let loc = CKLocationSortDescriptor(key: "where", relativeLocation: CLLocation(latitude: 48.85, longitude: 2.35))
            try objc(loc, "CKLocationSortDescriptor"); try expect(loc.relativeLocation.coordinate.latitude == 48.85 && loc.key == "where", "location sort")
            let info = CKSubscription.NotificationInfo(); info.alertBody = "a"; info.shouldSendContentAvailable = true; info.desiredKeys = ["s"]
            try objc(info, "CKNotificationInfo")
            let dbSub = CKDatabaseSubscription(subscriptionID: "db"); dbSub.notificationInfo = info
            try objc(dbSub, "CKDatabaseSubscription")
            let zSub = CKRecordZoneSubscription(zoneID: zid, subscriptionID: "zone"); zSub.recordType = "Doc"
            try objc(zSub, "CKRecordZoneSubscription")
            let arch = try NSKeyedArchiver.archivedData(withRootObject: zSub, requiringSecureCoding: true)
            let zBack = try NSKeyedUnarchiver.unarchivedObject(ofClass: CKRecordZoneSubscription.self, from: arch)
            try expect(zBack?.zoneID == zid && zBack?.recordType == "Doc" && dbSub.notificationInfo?.alertBody == "a", "subscriptions")
            let cfg = CKOperation.Configuration(); cfg.timeoutIntervalForRequest = 5; cfg.qualityOfService = .utility; cfg.allowsCellularAccess = false
            try objc(cfg, "CKOperationConfiguration")
            let grp = CKOperationGroup(); grp.name = "p27"; grp.expectedSendSize = .kilobytes; grp.defaultConfiguration = cfg
            try objc(grp, "CKOperationGroup")
            try expect(grp.defaultConfiguration.timeoutIntervalForRequest == 5 && !grp.operationGroupID.isEmpty, "group")
            let zcfg = CKFetchRecordZoneChangesOperation.ZoneConfiguration(previousServerChangeToken: nil, resultsLimit: 10, desiredKeys: ["s"])
            try objc(zcfg, "CKFetchRecordZoneChangesConfiguration")
            let lookup = CKUserIdentity.LookupInfo(emailAddress: "p27@example.com")
            try objc(lookup, "CKUserIdentityLookupInfo"); try expect(lookup.emailAddress == "p27@example.com", "lookup")
            let share = CKShare(rootRecord: rec)
            #if !os(watchOS)
            let opts = CKAllowedSharingOptions(allowedParticipantPermissionOptions: .readOnly, allowedParticipantAccessOptions: .specifiedRecipientsOnly)
            try objc(opts, "CKAllowedSharingOptions"); try expect(opts.allowedParticipantPermissionOptions == .readOnly, "sharing options")
            #endif
            // the operations, configured but never added to a database
            let url = URL(string: "https://www.icloud.com/share/0p27")!
            let ops: [(CKOperation, String)] = [
                (CKFetchRecordsOperation(recordIDs: [rid]), "CKFetchRecordsOperation"),
                (CKModifyRecordZonesOperation(recordZonesToSave: [CKRecordZone(zoneID: zid)], recordZoneIDsToDelete: nil), "CKModifyRecordZonesOperation"),
                (CKModifySubscriptionsOperation(subscriptionsToSave: [dbSub, zSub], subscriptionIDsToDelete: ["old"]), "CKModifySubscriptionsOperation"),
                (CKFetchSubscriptionsOperation(subscriptionIDs: ["db"]), "CKFetchSubscriptionsOperation"),
                (CKFetchRecordZonesOperation(recordZoneIDs: [zid]), "CKFetchRecordZonesOperation"),
                (CKFetchDatabaseChangesOperation(previousServerChangeToken: nil), "CKFetchDatabaseChangesOperation"),
                (CKFetchRecordZoneChangesOperation(recordZoneIDs: [zid], configurationsByRecordZoneID: [zid: zcfg]), "CKFetchRecordZoneChangesOperation"),
                (CKFetchShareMetadataOperation(shareURLs: [url]), "CKFetchShareMetadataOperation"),
                (CKFetchShareParticipantsOperation(userIdentityLookupInfos: [lookup]), "CKFetchShareParticipantsOperation"),
                (CKAcceptSharesOperation(), "CKAcceptSharesOperation"),
                (CKFetchWebAuthTokenOperation(apiToken: "p27"), "CKFetchWebAuthTokenOperation"),
                (CKShareRequestAccessOperation(shareURLs: [url]), "CKShareRequestAccessOperation"),
            ]
            for (op, name) in ops {
                try objc(op, name)
                op.configuration = cfg; op.group = grp
                try expect(op.configuration.timeoutIntervalForRequest == 5 && op.group === grp && !op.isFinished && !op.operationID.isEmpty, "\(name) configuration")
                try expect(op is CKDatabaseOperation || name == "CKAcceptSharesOperation" || name == "CKFetchShareMetadataOperation" || name == "CKFetchShareParticipantsOperation" || name == "CKShareRequestAccessOperation" || name == "CKFetchWebAuthTokenOperation", "\(name) database operation")
            }
            try expect((ops[0].0 as! CKFetchRecordsOperation).recordIDs == [rid] && (ops[2].0 as! CKModifySubscriptionsOperation).subscriptionIDsToDelete == ["old"], "operation inputs")
            // sync engine value types (Swift) and their Objective-C classes
            let fetchOpts = CKSyncEngine.FetchChangesOptions(scope: .zoneIDs([zid]))
            let sendOpts = CKSyncEngine.SendChangesOptions(scope: .recordIDs([rid]))
            try expect(fetchOpts.scope.contains(zid) && sendOpts.scope.contains(rid) && !sendOpts.scope.contains(CKRecord.ID(recordName: "other", zoneID: zid)), "sync engine scopes")
            let batch = await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: [.saveRecord(rid), .deleteRecord(CKRecord.ID(recordName: "gone", zoneID: zid))]) { $0 == rid ? rec : nil }
            try expect(batch?.recordsToSave.map(\.recordID) == [rid] && batch?.recordIDsToDelete.count == 1, "change batch \(String(describing: batch))")
            // classes CloudKit alone makes (results, events, server tokens): present, with their superclass
            let made: [(String, String)] = [("CKDatabase", "NSObject"), ("CKNotification", "NSObject"), ("CKDatabaseNotification", "CKNotification"), ("CKQueryNotification", "CKNotification"),
                ("CKRecordZoneNotification", "CKNotification"), ("CKNotificationID", "NSObject"), ("CKQueryCursor", "NSObject"), ("CKServerChangeToken", "NSObject"),
                ("CKShareMetadata", "NSObject"), ("CKShareParticipant", "NSObject"), ("CKUserIdentity", "NSObject"), ("CKShareAccessRequester", "NSObject"), ("CKShareBlockedIdentity", "NSObject"),
                ("CKDatabaseOperation", "CKOperation"), ("CKDiscoverAllUserIdentitiesOperation", "CKOperation"), ("CKDiscoverUserIdentitiesOperation", "CKOperation"),
                ("CKFetchNotificationChangesOperation", "CKOperation"), ("CKFetchRecordChangesOperation", "CKDatabaseOperation"), ("CKMarkNotificationsReadOperation", "CKOperation"),
                ("CKModifyBadgeOperation", "CKOperation"), ("CKFetchRecordZoneChangesOptions", "NSObject"),
                ("CKSyncEngineConfiguration", "NSObject"), ("CKSyncEngineState", "NSObject"), ("CKSyncEngineStateSerialization", "NSObject"), ("CKSyncEngineFetchChangesOptions", "NSObject"),
                ("CKSyncEngineFetchChangesScope", "NSObject"), ("CKSyncEngineSendChangesOptions", "NSObject"), ("CKSyncEngineSendChangesScope", "NSObject"),
                ("CKSyncEngineFetchChangesContext", "NSObject"), ("CKSyncEngineSendChangesContext", "NSObject"), ("CKSyncEnginePendingRecordZoneChange", "NSObject"),
                ("CKSyncEnginePendingDatabaseChange", "NSObject"), ("CKSyncEnginePendingZoneSave", "CKSyncEnginePendingDatabaseChange"), ("CKSyncEnginePendingZoneDelete", "CKSyncEnginePendingDatabaseChange"),
                ("CKSyncEngineRecordZoneChangeBatch", "NSObject"), ("CKSyncEngineFailedRecordSave", "NSObject"), ("CKSyncEngineFailedZoneSave", "NSObject"),
                ("CKSyncEngineFetchedRecordDeletion", "NSObject"), ("CKSyncEngineFetchedZoneDeletion", "NSObject"), ("CKSyncEngineEvent", "NSObject"),
                ("CKSyncEngineStateUpdateEvent", "CKSyncEngineEvent"), ("CKSyncEngineAccountChangeEvent", "CKSyncEngineEvent"), ("CKSyncEngineFetchedDatabaseChangesEvent", "CKSyncEngineEvent"),
                ("CKSyncEngineFetchedRecordZoneChangesEvent", "CKSyncEngineEvent"), ("CKSyncEngineSentDatabaseChangesEvent", "CKSyncEngineEvent"), ("CKSyncEngineSentRecordZoneChangesEvent", "CKSyncEngineEvent"),
                ("CKSyncEngineWillFetchChangesEvent", "CKSyncEngineEvent"), ("CKSyncEngineWillFetchRecordZoneChangesEvent", "CKSyncEngineEvent"), ("CKSyncEngineDidFetchRecordZoneChangesEvent", "CKSyncEngineEvent"),
                ("CKSyncEngineDidFetchChangesEvent", "CKSyncEngineEvent"), ("CKSyncEngineWillSendChangesEvent", "CKSyncEngineEvent"), ("CKSyncEngineDidSendChangesEvent", "CKSyncEngineEvent")]
            let wrong = p27Hierarchy(made)
            try expect(wrong.isEmpty, "classes: \(wrong)")
            // the share's owner participant (a CKShareParticipant with a CKUserIdentity) and the system sharing observer
            try objc(share.owner, "CKShareParticipant"); try objc(share.owner.userIdentity, "CKUserIdentity")
            #if !os(tvOS) && !os(watchOS)
            let obs = CKSystemSharingUIObserver(container: CKContainer(identifier: "iCloud.com.x86sim.test.sdkcov"))
            try objc(obs, "CKSystemSharingUIObserver")
            #endif
            return "\(n) objects of their Objective-C class; \(ops.count) operations configured; \(made.count) CloudKit-made classes present"
        })
        #endif
        // MARK: CoreData: a coordinator on SQLite with history tracking (history changes and tokens, query generations,
        // asynchronous fetch results), merge and constraint conflicts, custom atomic and incremental stores, a migration
        // with an inferred mapping model and a custom entity migration policy, staged-migration stages, the Spotlight
        // delegate and the CloudKit event request on a store without CloudKit
        #if canImport(CoreData)
        c.append(check("CoreData", "p27-stores-history-conflicts", timeout: 40) {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("p27-cd-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: dir) }
            let model = p27Model(unique: true)
            let psc = NSPersistentStoreCoordinator(managedObjectModel: model)
            let url = dir.appendingPathComponent("a.sqlite")
            let store: NSPersistentStore = try psc.addPersistentStore(type: .sqlite, at: url, options: [NSPersistentHistoryTrackingKey: true])
            try expect(store.type == NSSQLiteStoreType && store.url == url && psc.persistentStores.count == 1 && psc.persistentStore(for: url) === store, "store \(store.type)")
            let ctx = NSManagedObjectContext(.privateQueue); ctx.persistentStoreCoordinator = psc
            let out = try await ctx.perform { () throws -> String in
                for i in 0..<3 { let o = NSEntityDescription.insertNewObject(forEntityName: "Item", into: ctx); o.setValue("i\(i)", forKey: "name"); o.setValue(i % 2, forKey: "n") }
                try ctx.save()
                // the fetched property: i0's peers are the items with the same n (i0, i2)
                let f = NSFetchRequest<NSManagedObject>(entityName: "Item"); f.predicate = NSPredicate(format: "name == 'i0'")
                guard let i0 = try ctx.fetch(f).first else { throw Fail("no i0") }
                let peers = (i0.value(forKey: "peers") as? [NSManagedObject])?.compactMap { $0.value(forKey: "name") as? String }.sorted() ?? []
                try expect(peers == ["i0", "i2"], "fetched property peers \(peers)")
                // history: one transaction of 3 inserts, with a token
                guard let res = try ctx.execute(NSPersistentHistoryChangeRequest.fetchHistory(after: nil as NSPersistentHistoryToken?)) as? NSPersistentHistoryResult,
                      let tx = res.result as? [NSPersistentHistoryTransaction] else { throw Fail("history result") }
                try expect(res is NSPersistentStoreResult, "history result class")
                let changes: [NSPersistentHistoryChange] = tx.flatMap { $0.changes ?? [] }
                try expect(changes.count == 3 && changes.allSatisfy { $0.changeType == .insert }, "changes \(changes.map(\.changeType.rawValue))")
                let token: NSPersistentHistoryToken = tx.last!.token
                let after = try ctx.execute(NSPersistentHistoryChangeRequest.fetchHistory(after: token)) as? NSPersistentHistoryResult
                try expect((after?.result as? [Any])?.isEmpty == true, "history after the last token")
                // a query generation pinned
                try ctx.setQueryGenerationFrom(NSQueryGenerationToken.current)
                let gen: NSQueryGenerationToken? = ctx.queryGenerationToken
                try expect(gen != nil, "query generation")
                // NSFetchRequestExpression: a count-only fetch as an expression
                let fe = NSFetchRequestExpression.expression(forFetch: NSExpression(forConstantValue: { let r = NSFetchRequest<NSFetchRequestResult>(); r.entity = model.entitiesByName["Item"]; return r }()),
                                                             context: NSExpression(forConstantValue: ctx), countOnly: true) as! NSFetchRequestExpression
                try expect(fe.isCountOnlyRequest && fe.expressionType.rawValue == 50, "fetch request expression")
                // a constraint conflict: a second "i1" under the error policy, then resolved by the object-trump policy
                ctx.mergePolicy = NSMergePolicy(merge: .errorMergePolicyType)
                let dup = NSEntityDescription.insertNewObject(forEntityName: "Item", into: ctx); dup.setValue("i1", forKey: "name"); dup.setValue(9, forKey: "n")
                var conflicts: [NSConstraintConflict] = []
                do { try ctx.save() } catch let e as NSError { conflicts = (e.userInfo[NSPersistentStoreSaveConflictsErrorKey] as? [NSConstraintConflict]) ?? [] }
                try expect(conflicts.count == 1 && conflicts[0].constraint == ["name"] && conflicts[0].databaseObject != nil, "constraint conflicts \(conflicts)")
                ctx.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
                try ctx.save()
                let cnt = try ctx.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "Item"))
                try expect(cnt == 3, "after the trump merge \(cnt) items")
                return "peers \(peers), \(changes.count) history inserts, constraint conflict resolved"
            }
            // an optimistic-locking conflict: two contexts change the same row; the second save fails with NSMergeConflict
            let c1 = NSManagedObjectContext(.privateQueue); c1.persistentStoreCoordinator = psc
            let c2 = NSManagedObjectContext(.privateQueue); c2.persistentStoreCoordinator = psc; c2.retainsRegisteredObjects = true
            let f0 = NSFetchRequest<NSManagedObject>(entityName: "Item"); f0.predicate = NSPredicate(format: "name == 'i0'")
            // c2 holds i0 (its snapshot taken) before c1 saves a change to it; c2 then changes the same object and saves
            guard let oid = try await c2.perform({ () throws -> NSManagedObjectID? in let o = try c2.fetch(f0).first; _ = o?.value(forKey: "n"); return o?.objectID }) else { throw Fail("no i0 in c2") }
            try await c1.perform { try c1.fetch(f0).first?.setValue(5, forKey: "n"); try c1.save() }
            let (merge, saveErr) = await c2.perform { () -> ([NSMergeConflict], String) in
                c2.object(with: oid).setValue(6, forKey: "n")
                do { try c2.save(); return ([], "saved") } catch let e as NSError { return ((e.userInfo[NSPersistentStoreSaveConflictsErrorKey] as? [NSMergeConflict]) ?? [], "\(e.domain) \(e.code)") }
            }
            try expect(merge.count == 1 && merge[0].newVersionNumber > merge[0].oldVersionNumber && merge[0].sourceObject.objectID == oid, "merge conflicts \(merge), save \(saveErr)")
            // an asynchronous fetch: its result is an NSPersistentStoreAsynchronousResult
            let box = P5Box<Int>()
            let isStoreResult = try await ctx.perform { () throws -> Bool in
                let af = NSAsynchronousFetchRequest(fetchRequest: NSFetchRequest<NSManagedObject>(entityName: "Item")) { box.set($0.finalResult?.count ?? -1) }
                return try ctx.execute(af) is NSPersistentStoreAsynchronousResult
            }
            let ares = isStoreResult ? (await box.wait(10) ?? -2) : -3
            try expect(ares == 3, "async fetch \(ares)")
            // the CloudKit event request on a store without CloudKit
            let ev = NSPersistentCloudKitContainerEventRequest.fetchEvents(after: Date.distantPast)
            try expect(ev is NSPersistentStoreRequest && ev.requestType.rawValue > 0, "event request type")
            let evAnswer = await ctx.perform { () -> String in
                do { let r = try ctx.execute(ev); return "\(type(of: r)) \(((r as? NSPersistentCloudKitContainerEventResult)?.result as? [NSPersistentCloudKitContainer.Event])?.count ?? -1)" }
                catch { return "threw \(p3Err(error))" }
            }
            let evClasses = p27Hierarchy([("NSPersistentCloudKitContainerEvent", "NSObject"), ("NSPersistentCloudKitContainerEventResult", "NSPersistentStoreResult")])
            try expect(evClasses.isEmpty, "event classes \(evClasses)")
            return "\(out); version conflict; async 3; CloudKit events: \(evAnswer)"
        })
        c.append(check("CoreData", "p27-custom-stores-migration", timeout: 40) {
            // the atomic store: inserts become cache nodes, a save calls -save:
            NSPersistentStoreCoordinator.registerStoreClass(P27AtomicStore.self, type: NSPersistentStore.StoreType(rawValue: P27AtomicStore.type))
            NSPersistentStoreCoordinator.registerStoreClass(P27IncStore.self, type: NSPersistentStore.StoreType(rawValue: P27IncStore.type))
            let tmp = FileManager.default.temporaryDirectory
            let apsc = NSPersistentStoreCoordinator(managedObjectModel: p27Model())
            let astore = try apsc.addPersistentStore(type: NSPersistentStore.StoreType(rawValue: P27AtomicStore.type), at: tmp.appendingPathComponent("p27.atomic"))
            guard let atomic = astore as? P27AtomicStore else { throw Fail("atomic store is \(type(of: astore))") }
            let actx = NSManagedObjectContext(.mainQueue); actx.persistentStoreCoordinator = apsc
            let saves0 = P27AtomicStore.saves
            let (nodes, val) = try await onMain { () throws -> (Int, String?) in
                for i in 0..<2 { NSEntityDescription.insertNewObject(forEntityName: "Item", into: actx).setValue("a\(i)", forKey: "name") }
                try actx.save()
                let ns = atomic.cacheNodes()
                return (ns.count, ns.compactMap { $0.propertyCache?["name"] as? String }.sorted().first)
            }
            try expect(nodes == 2 && val == "a0" && P27AtomicStore.saves == saves0 + 1, "atomic: \(nodes) cache nodes, first \(String(describing: val)), saves \(P27AtomicStore.saves - saves0)")
            // the incremental store: a save request, then a fresh context faults the rows in through store nodes
            let ipsc = NSPersistentStoreCoordinator(managedObjectModel: p27Model())
            _ = try ipsc.addPersistentStore(type: NSPersistentStore.StoreType(rawValue: P27IncStore.type), at: tmp.appendingPathComponent("p27.inc"))
            let r0 = P27IncStore.saveRequests, n0 = P27IncStore.nodes
            let inc = try await onMain { () throws -> [String] in
                let w = NSManagedObjectContext(.mainQueue); w.persistentStoreCoordinator = ipsc
                for i in 0..<3 { NSEntityDescription.insertNewObject(forEntityName: "Item", into: w).setValue("x\(i)", forKey: "name") }
                try w.save()
                let r = NSManagedObjectContext(.mainQueue); r.persistentStoreCoordinator = ipsc
                return try r.fetch(NSFetchRequest<NSManagedObject>(entityName: "Item")).compactMap { $0.value(forKey: "name") as? String }.sorted()
            }
            try expect(inc == ["x0", "x1", "x2"] && P27IncStore.saveRequests == r0 + 1 && P27IncStore.nodes - n0 == 3, "incremental: \(inc), \(P27IncStore.saveRequests - r0) save requests, \(P27IncStore.nodes - n0) nodes")
            // migration v1 -> v2 (adds "note"): the inferred mapping, run by NSMigrationManager with a custom policy
            let dir = tmp.appendingPathComponent("p27-mig-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: dir) }
            let v1 = p27Model(), v2 = p27Model(extra: true)
            let src = dir.appendingPathComponent("v1.sqlite"), dst = dir.appendingPathComponent("v2.sqlite")
            let p1 = NSPersistentStoreCoordinator(managedObjectModel: v1)
            let s1 = try p1.addPersistentStore(type: .sqlite, at: src)
            let c1 = NSManagedObjectContext(.privateQueue); c1.persistentStoreCoordinator = p1
            try await c1.perform { for i in 0..<4 { NSEntityDescription.insertNewObject(forEntityName: "Item", into: c1).setValue("m\(i)", forKey: "name") }; try c1.save() }
            try p1.remove(s1)
            let mapping = try NSMappingModel.inferredMappingModel(forSourceModel: v1, destinationModel: v2)
            guard let em: NSEntityMapping = mapping.entityMappings.first else { throw Fail("no entity mapping") }
            let pm: [NSPropertyMapping] = em.attributeMappings ?? []
            try expect(mapping.entityMappings.count == 1 && pm.contains { $0.name == "note" } && pm.contains { $0.name == "name" }, "mapping \(pm.compactMap(\.name))")
            em.entityMigrationPolicyClassName = NSStringFromClass(P27Policy.self)
            P27Policy.made = 0
            let mgr = NSMigrationManager(sourceModel: v1, destinationModel: v2)
            mgr.usesStoreSpecificMigrationManager = false   // else SQLite migrates in the store, without entity policies
            try mgr.migrateStore(from: src, type: .sqlite, mapping: mapping, to: dst, type: .sqlite)
            let p2 = NSPersistentStoreCoordinator(managedObjectModel: v2)
            _ = try p2.addPersistentStore(type: .sqlite, at: dst)
            let c2 = NSManagedObjectContext(.privateQueue); c2.persistentStoreCoordinator = p2
            let notes = try await c2.perform { try c2.fetch(NSFetchRequest<NSManagedObject>(entityName: "Item")).compactMap { $0.value(forKey: "note") as? String } }
            try expect(P27Policy.made == 4 && notes == Array(repeating: "migrated", count: 4), "migration: policy made \(P27Policy.made), notes \(notes)")
            // staged migration stages
            let stage = NSLightweightMigrationStage([v1.versionChecksum, v2.versionChecksum]); stage.label = "p27"
            let asStage: NSMigrationStage = stage
            try expect(stage.versionChecksums.count == 2 && asStage.label == "p27", "stage")
            // the Spotlight delegate for a history-tracked SQLite store
            #if os(iOS) || os(visionOS)
            let desc = NSPersistentStoreDescription(url: dir.appendingPathComponent("s.sqlite")); desc.type = NSSQLiteStoreType
            desc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            let sp = NSPersistentStoreCoordinator(managedObjectModel: v2)
            sp.addPersistentStore(with: desc) { _, _ in }
            let spot = NSCoreDataCoreSpotlightDelegate(forStoreWith: desc, coordinator: sp)
            let spotInfo = "Spotlight delegate domain \(spot.domainIdentifier()), indexing \(spot.isIndexingEnabled)"
            try expect(!spot.isIndexingEnabled, spotInfo)
            #else
            let spotInfo = "no Spotlight delegate"
            #endif
            return "atomic 2 nodes; incremental 3 rows via \(P27IncStore.nodes - n0) nodes; migrated 4 with the policy; \(spotInfo)"
        })
        #endif
        // MARK: CryptoKit: the protocols (HashFunction / Digest, MessageAuthenticationCode, DiffieHellmanKeyAgreement,
        // KEM keys, HPKE key protocols) driven generically over P-384, P-521, SHA-2/3, ML-KEM-1024 and X-Wing; ML-DSA-87;
        // the errors CryptoKit throws
        #if canImport(CryptoKit)
        c.append(check("CryptoKit", "p27-protocols-pq-errors", timeout: 30) {
            let msg = Data("abc".utf8)
            func hex<H: HashFunction>(_: H.Type) -> String { H.hash(data: msg).map { String(format: "%02x", $0) }.joined() }
            // FIPS 180-4 / 202 "abc" vectors, typed digests
            let d256: SHA256Digest = SHA256.hash(data: msg), d384: SHA384Digest = SHA384.hash(data: msg), d512: SHA512Digest = SHA512.hash(data: msg)
            func asDigest<D: Digest>(_ d: D) -> Int { D.byteCount }
            try expect(asDigest(d256) == 32 && asDigest(d384) == 48 && asDigest(d512) == 64, "digest sizes")
            try expect(hex(SHA384.self).hasPrefix("cb00753f45a35e8b") && hex(SHA512.self).hasPrefix("ddaf35a193617aba") && hex(SHA3_256.self).hasPrefix("3a985da74fe225b2"), "vectors")
            // HMAC through the MessageAuthenticationCode protocol (RFC 4231 case 2, SHA-384)
            let mac: HashedAuthenticationCode<SHA384> = HMAC<SHA384>.authenticationCode(for: Data("what do ya want for nothing?".utf8), using: SymmetricKey(data: Data("Jefe".utf8)))
            func macHex<M: MessageAuthenticationCode>(_ m: M) -> String { m.map { String(format: "%02x", $0) }.joined() }
            try expect(macHex(mac).hasPrefix("af45d2e376484031") && mac.byteCount == 48, "HMAC-SHA384 \(macHex(mac).prefix(16))")
            try expect(SymmetricKey(size: SymmetricKeySize(bitCount: 192)).bitCount == 192 && SymmetricKeySize.bits256.bitCount == 256, "key sizes")
            // ECDH over the protocol, P-384 and P-521: both sides derive the same SharedSecret
            func agree<K: DiffieHellmanKeyAgreement>(_ a: K, _ b: K) throws -> Bool {
                let s1: SharedSecret = try a.sharedSecretFromKeyAgreement(with: b.publicKey), s2 = try b.sharedSecretFromKeyAgreement(with: a.publicKey)
                return s1 == s2 && s1.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data(), sharedInfo: Data(), outputByteCount: 32) == s2.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data(), sharedInfo: Data(), outputByteCount: 32)
            }
            try expect(try agree(P384.KeyAgreement.PrivateKey(), P384.KeyAgreement.PrivateKey()) && (try agree(P521.KeyAgreement.PrivateKey(), P521.KeyAgreement.PrivateKey())), "ECDH")
            let s384 = P384.Signing.PrivateKey(), s521 = P521.Signing.PrivateKey()
            try expect(s384.publicKey.isValidSignature(try s384.signature(for: msg), for: msg) && s521.publicKey.isValidSignature(try s521.signature(for: msg), for: msg), "P-384 / P-521 signatures")
            // HPKE: a DH suite generic over HPKEDiffieHellmanPrivateKeyGeneration (P-384), a KEM suite over HPKEKEMPrivateKeyGeneration (X-Wing)
            func hpkeDH<K: HPKEDiffieHellmanPrivateKeyGeneration>(_: K.Type, _ suite: HPKE.Ciphersuite) throws -> Bool {
                let rk = K()
                let pubBytes = try rk.publicKey.hpkeRepresentation(kem: suite.kem)
                let pub = try K.PublicKey(pubBytes, kem: suite.kem)
                var s = try HPKE.Sender(recipientKey: pub, ciphersuite: suite, info: Data("p27".utf8))
                let ct = try s.seal(msg)
                var r = try HPKE.Recipient(privateKey: rk, ciphersuite: suite, info: Data("p27".utf8), encapsulatedKey: s.encapsulatedKey)
                return try r.open(ct) == msg
            }
            func hpkeKEM<K: HPKEKEMPrivateKeyGeneration>(_: K.Type, _ suite: HPKE.Ciphersuite) throws -> Bool {
                let rk = try K()
                let pub = try K.PublicKey(try rk.publicKey.hpkeRepresentation(kem: suite.kem), kem: suite.kem)
                func ser<P: HPKEPublicKeySerialization>(_ p: P) throws -> Int { try p.hpkeRepresentation(kem: suite.kem).count }
                var s = try HPKE.Sender(recipientKey: pub, ciphersuite: suite, info: Data())
                let ct = try s.seal(msg)
                var r = try HPKE.Recipient(privateKey: rk, ciphersuite: suite, info: Data(), encapsulatedKey: s.encapsulatedKey)
                return try r.open(ct) == msg && (try ser(pub)) > 1000
            }
            func dhPub<P: HPKEDiffieHellmanPublicKey>(_ p: P) -> Bool { true }
            func kemPub<P: HPKEKEMPublicKey>(_ p: P) -> Bool { true }
            func dhPriv<P: HPKEDiffieHellmanPrivateKey>(_ p: P) -> Bool { dhPub(p.publicKey) }
            func kemPriv<P: HPKEKEMPrivateKey>(_ p: P) -> Bool { kemPub(p.publicKey) }
            try expect(try hpkeDH(P384.KeyAgreement.PrivateKey.self, .P384_SHA384_AES_GCM_256) && dhPriv(P521.KeyAgreement.PrivateKey()), "HPKE P-384")
            try expect(try hpkeKEM(XWingMLKEM768X25519.PrivateKey.self, .XWingMLKEM768X25519_SHA256_AES_GCM_256) && kemPriv(try XWingMLKEM768X25519.PrivateKey()), "HPKE X-Wing")
            // KEM protocols with ML-KEM-1024, and its one-time (non-copyable, consumed by decapsulation) private key
            func kem<K: KEMPrivateKey>(_ k: K) throws -> Bool {
                func pub<P: KEMPublicKey>(_ p: P) throws -> KEM.EncapsulationResult { try p.encapsulate() }
                let e = try pub(k.publicKey)
                return try k.decapsulate(e.encapsulated) == e.sharedSecret
            }
            try expect(try kem(MLKEM1024.PrivateKey()), "ML-KEM-1024")
            func oneTime<K: KEMOneTimePrivateKey & ~Copyable>(_: K.Type) throws -> Bool {
                let k = try K.generate()
                let e = try k.publicKey.encapsulate()
                return try k.decapsulate(e.encapsulated) == e.sharedSecret
            }
            try expect(try oneTime(MLKEM1024.OneTimePrivateKey.self), "one-time key")
            let dsa = try MLDSA87.PrivateKey()
            let sig = try dsa.signature(for: msg)
            try expect(dsa.publicKey.isValidSignature(sig, for: msg) && !dsa.publicKey.isValidSignature(sig, for: Data("abd".utf8)) && sig.count == 4627, "ML-DSA-87 \(sig.count) B")
            // errors: a wrong key is CryptoKitError.authenticationFailure; garbage DER a CryptoKitASN1Error
            let box = try AES.GCM.seal(msg, using: SymmetricKey(size: .bits128))
            var e1 = "none", e2 = "none"
            do { _ = try AES.GCM.open(box, using: SymmetricKey(size: .bits128)) } catch let e as CryptoKitError { e1 = "\(e)" }
            do { _ = try P384.Signing.PublicKey(derRepresentation: Data([0x30, 0x03, 0x02, 0x01])) } catch let e as CryptoKitASN1Error { e2 = "\(e)" } catch { e2 = "other \(type(of: error))" }
            try expect(e1 == "authenticationFailure" && e2 != "none" && !e2.hasPrefix("other"), "errors \(e1) / \(e2)")
            return "SHA-2/3 vectors, HMAC-SHA384, P-384/521 ECDH+ECDSA, HPKE P-384 + X-Wing, ML-KEM-1024 (+ one-time), ML-DSA-87; errors \(e1) / \(e2)"
        })
        #endif
        // MARK: AuthenticationServices: every provider's requests built and configured (Apple ID / OpenID, password,
        // platform and security-key passkeys with large-blob and PRF inputs, single sign-on, account creation), the
        // credential provider extension's value types, the Credential Exchange data model through JSON, web
        // authentication callbacks; classes only the system makes asserted present with their superclass
        #if canImport(AuthenticationServices)
        c.append(check("AuthenticationServices", "p27-requests-credentials", timeout: 30) {
            var n = 0
            func objc(_ o: AnyObject, _ cls: String) throws { n += 1; try expect(p27Is(o, cls), "\(type(of: o)) is not \(cls)") }
            let apple = ASAuthorizationAppleIDProvider().createRequest()
            apple.requestedScopes = [.fullName, .email]; apple.nonce = "n0"; apple.state = "s0"; apple.requestedOperation = .operationLogin
            let openID: ASAuthorizationOpenIDRequest = apple
            try objc(apple, "ASAuthorizationAppleIDRequest"); try objc(openID, "ASAuthorizationOpenIDRequest")
            try expect(openID.requestedScopes == [.fullName, .email] && openID.nonce == "n0" && openID.state == "s0", "Apple ID request")
            let pw = ASAuthorizationPasswordProvider().createRequest()
            try objc(pw, "ASAuthorizationPasswordRequest")
            let chal = Data(repeating: 7, count: 32), uid = Data("user-1".utf8), cid = Data([1, 2, 3, 4])
            #if !os(watchOS)
            let plat = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: "example.com")
            let preg = plat.createCredentialRegistrationRequest(challenge: chal, name: "p27", userID: uid)
            preg.userVerificationPreference = .required
            try objc(preg, "ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest")
            let passt = plat.createCredentialAssertionRequest(challenge: chal)
            passt.allowedCredentials = [ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: cid)]
            try objc(passt, "ASAuthorizationPlatformPublicKeyCredentialAssertionRequest")
            try expect(preg.relyingPartyIdentifier == "example.com" && preg.userID == uid && preg.challenge == chal && passt.allowedCredentials.first?.credentialID == cid, "platform requests")
            let skp = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: "example.com")
            let sreg = skp.createCredentialRegistrationRequest(challenge: chal, displayName: "P27", name: "p27", userID: uid)
            sreg.credentialParameters = [ASAuthorizationPublicKeyCredentialParameters(algorithm: .ES256)]
            sreg.residentKeyPreference = .preferred
            try objc(sreg, "ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequest")
            let sast = skp.createCredentialAssertionRequest(challenge: chal)
            let desc = ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor(credentialID: cid, transports: [.usb, .nfc])
            sast.allowedCredentials = [desc]
            try objc(sast, "ASAuthorizationSecurityKeyPublicKeyCredentialAssertionRequest"); try objc(desc, "ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor")
            try expect(sreg.credentialParameters.first?.algorithm == .ES256 && sast.allowedCredentials.first?.transports.count == 2, "security key requests")
            #endif
            // results only the system makes: present, with their superclass
            var made: [(String, String)] = [("ASAuthorizationAppleIDCredential", "NSObject"), ("ASAuthorizationPlatformPublicKeyCredentialAssertion", "NSObject"),
                ("ASAuthorizationPlatformPublicKeyCredentialRegistration", "NSObject")]
            #if os(iOS) || os(visionOS)
            let ext = ASPasskeyRegistrationCredentialExtensionInput.self, ext2 = ASPasskeyAssertionCredentialExtensionInput.self
            _ = (ext, ext2)
            preg.largeBlob = .supportRequired
            preg.prf = .checkForSupport
            passt.largeBlob = .write(Data("blob".utf8))
            let salts = ASAuthorizationPublicKeyCredentialPRFAssertionInput.InputValues(saltInput1: Data(repeating: 1, count: 32))
            passt.prf = .inputValues(salts)
            try expect(preg.prf?.shouldCheckForSupport == true && passt.prf?.inputValues?.saltInput1.count == 32, "PRF inputs")
            if case .write(let d)? = passt.largeBlob?.operation { try expect(d.count == 4, "large blob") } else { throw Fail("large blob operation") }
            let largeIn: [ASAuthorizationPublicKeyCredentialLargeBlobRegistrationInput] = [.supportRequired, .supportPreferred]
            let prfOut = ASAuthorizationPublicKeyCredentialPRFRegistrationOutput.supported, prfA = ASAuthorizationPublicKeyCredentialPRFAssertionOutput(first: SymmetricKey(size: .bits256), second: nil)
            let regOut = ASAuthorizationPublicKeyCredentialPRFRegistrationInput.inputValues(salts)
            try expect(largeIn.count == 2 && prfOut.isSupported && prfA.second == nil && regOut.inputValues != nil, "PRF / large blob values")
            made += [("ASAuthorizationPublicKeyCredentialLargeBlobAssertionOutput", "NSObject"), ("ASAuthorizationPublicKeyCredentialLargeBlobRegistrationOutput", "NSObject"),
                     ("ASAuthorizationSecurityKeyPublicKeyCredentialAssertion", "NSObject"), ("ASAuthorizationSecurityKeyPublicKeyCredentialRegistration", "NSObject"),
                     ("ASAuthorizationSingleSignOnCredential", "NSObject"), ("ASCredentialIdentityStoreState", "NSObject"), ("ASCredentialProviderExtensionContext", "NSExtensionContext"),
                     ("ASAccountAuthenticationModificationExtensionContext", "NSExtensionContext"), ("ASAccountAuthenticationModificationRequest", "NSObject"),
                     ("ASAccountAuthenticationModificationReplacePasswordWithSignInWithAppleRequest", "ASAccountAuthenticationModificationRequest"),
                     ("ASAccountAuthenticationModificationUpgradePasswordToStrongPasswordRequest", "ASAccountAuthenticationModificationRequest"),
                     ("ASAccountAuthenticationModificationViewController", "UIViewController"), ("ASAccountAuthenticationModificationController", "NSObject"),
                     ("ASAuthorizationProviderExtensionAuthorizationRequest", "NSObject"), ("ASAuthorizationProviderExtensionAuthorizationResult", "NSObject"),
                     ("ASPasskeyCredentialRequestParameters", "NSObject")]
            // single sign-on and account creation requests
            let sso = ASAuthorizationSingleSignOnProvider(identityProvider: URL(string: "https://sso.example.com")!).createRequest()
            sso.requestedOperation = .operationLogin; sso.isUserInterfaceEnabled = false
            try objc(sso, "ASAuthorizationSingleSignOnRequest"); try expect(!sso.isUserInterfaceEnabled, "SSO request")
            let acct = ASAuthorizationAccountCreationProvider().createPlatformPublicKeyCredentialRegistrationRequest(acceptedContactIdentifiers: [ASContactIdentifierRequest.email, .phoneNumber],
                shouldRequestName: true, relyingPartyIdentifier: "example.com", challenge: chal, userID: uid)
            try expect(acct.isKind(of: ASAuthorizationRequest.self), "account creation request")
            let credType: AnyClass = ASAuthorizationAccountCreationPlatformPublicKeyCredential.self
            try expect(credType is ASAuthorizationCredential.Type, "account creation credential type")
            // the contact identifiers come back in the credential (no public initializers)
            let idTypes: [Any.Type] = [ASContactIdentifier.self, ASEmailIdentifier.self, ASPhoneNumberIdentifier.self]
            try expect(idTypes.count == 3 && acct.relyingPartyIdentifier == "example.com", "account creation request")
            // credential provider extension value types
            let sid = ASCredentialServiceIdentifier(identifier: "example.com", type: .domain)
            let pki = ASPasskeyCredentialIdentity(relyingPartyIdentifier: "example.com", userName: "p27", credentialID: cid, userHandle: uid, recordIdentifier: "r1")
            let oti = ASOneTimeCodeCredentialIdentity(serviceIdentifier: sid, label: "p27 code", recordIdentifier: nil)
            let pwi = ASPasswordCredentialIdentity(serviceIdentifier: sid, user: "p27", recordIdentifier: nil)
            let reqs: [(AnyObject, String)] = [
                (ASPasskeyCredentialRequest(credentialIdentity: pki, clientDataHash: Data(repeating: 2, count: 32), userVerificationPreference: .preferred, supportedAlgorithms: [.ES256]), "ASPasskeyCredentialRequest"),
                (ASPasswordCredentialRequest(credentialIdentity: pwi), "ASPasswordCredentialRequest"), (ASOneTimeCodeCredentialRequest(credentialIdentity: oti), "ASOneTimeCodeCredentialRequest"),
                (pki, "ASPasskeyCredentialIdentity"), (oti, "ASOneTimeCodeCredentialIdentity"), (ASOneTimeCodeCredential(code: "123456"), "ASOneTimeCodeCredential"),
                (ASPasskeyRegistrationCredential(relyingParty: "example.com", clientDataHash: Data(count: 32), credentialID: cid, attestationObject: Data([0xa0])), "ASPasskeyRegistrationCredential"),
                (ASPasskeyAssertionCredential(userHandle: uid, relyingParty: "example.com", signature: Data([1]), clientDataHash: Data(count: 32), authenticatorData: Data([2]), credentialID: cid), "ASPasskeyAssertionCredential"),
                (ASGeneratePasswordsRequest(serviceIdentifier: sid, passwordFieldPasswordRules: "minlength: 20;", confirmPasswordFieldPasswordRules: nil, passwordRulesFromQuirks: nil), "ASGeneratePasswordsRequest"),
                (ASGeneratedPassword(kind: .strong, value: "abc-def-ghi"), "ASGeneratedPassword"),
                (ASSavePasswordRequest(serviceIdentifier: sid, credential: ASPasswordCredential(user: "p27", password: "pw"), sessionID: "s1", event: .userInitiated), "ASSavePasswordRequest")]
            for (o, cls) in reqs { try objc(o, cls) }
            try expect((reqs[0].0 as! ASPasskeyCredentialRequest).supportedAlgorithms == [.ES256] && (reqs[5].0 as! ASOneTimeCodeCredential).code == "123456"
                       && (reqs[9].0 as! ASGeneratedPassword).value == "abc-def-ghi" && (reqs[10].0 as! ASSavePasswordRequest).credential.password == "pw", "provider values")
            let inputs: [ASPasskeyCredentialExtensionInput] = [.none]
            let cd = ASPublicKeyCredentialClientData(challenge: chal, origin: "https://example.com", crossOrigin: .sameOriginWithAncestors)
            try expect(inputs.count == 1 && cd.origin == "https://example.com", "client data")
            let scope = ASAutoFillURLScope(host: "example.com", path: "/login")
            try expect(scope.url?.absoluteString == "https://example.com/login" && ASAutoFillURLScope(url: URL(string: "http://example.com:8080/a")!)?.port == 8080, "url scope \(String(describing: scope.url))")
            let code = ASVerificationCode(code: "424242", timestamp: Date(timeIntervalSince1970: 1), domain: "example.com")
            try expect(try JSONDecoder().decode(ASVerificationCode.self, from: JSONEncoder().encode(code)) == code, "verification code")
            _ = ASDeliveredVerificationCodesManager()
            // the Credential Exchange data model, through JSON
            let field = ASImportableEditableField(id: nil, fieldType: .string, value: "p27")
            let pass = ASImportableEditableField(id: nil, fieldType: .concealedString, value: "pw")
            let item = ASImportableItem(id: Data([9]), created: Date(timeIntervalSince1970: 0), lastModified: Date(timeIntervalSince1970: 0), title: "Example",
                                        scope: ASImportableCredentialScope(urls: [URL(string: "https://example.com")!]),
                                        credentials: [ASImportableCredential.basicAuthentication(.init(userName: field, password: pass)), .note(.init(content: field))])
            let coll = ASImportableCollection(id: Data([8]), created: nil, lastModified: nil, title: "Work", items: [ASImportableLinkedItem(item: Data([9]))], subcollections: [])
            let account = ASImportableAccount(id: Data([7]), userName: "p27", email: "p27@example.com", collections: [coll], items: [item])
            let export = ASExportedCredentialData(accounts: [account], formatVersion: .v1, exporterRelyingPartyIdentifier: "com.x86sim", exporterDisplayName: "sdkcov", timestamp: Date(timeIntervalSince1970: 5))
            let back = try JSONDecoder().decode(ASExportedCredentialData.self, from: JSONEncoder().encode(export))
            try expect(back == export && back.accounts.first?.items.first?.credentials.count == 2, "exported credential data")
            let fido = ASImportableFIDO2Extensions(hmacCredentials: ASImportableFIDO2HMACCredential(algorithm: .sha256, credentialWithUV: Data([1]), credentialWithoutUV: Data([2])),
                                                   largeBlob: ASImportableFIDO2LargeBlob(uncompressedSize: 4, data: Data([3])))
            let share = ASImportableExtension.shared(.init(accessors: [.init(type: .user, accountID: Data([7]), name: "p27", permissions: [.read])]))
            try expect(try JSONDecoder().decode(ASImportableFIDO2Extensions.self, from: JSONEncoder().encode(fido)) == fido
                       && (try JSONDecoder().decode(ASImportableExtension.self, from: JSONEncoder().encode(share))) == share, "FIDO2 / shared extensions")
            _ = (ASCredentialImportManager(), ASCredentialExportManager.self)
            // web authentication callbacks
            let cb1 = ASWebAuthenticationSession.Callback.customScheme("p27cb"), cb2 = ASWebAuthenticationSession.Callback.https(host: "example.com", path: "/done")
            try expect(cb1.matchesURL(URL(string: "p27cb://x")!) && !cb1.matchesURL(URL(string: "other://x")!) && cb2.matchesURL(URL(string: "https://example.com/done?c=1")!), "callbacks")
            try objc(cb1, "ASWebAuthenticationSessionCallback")
            #endif
            let wrong = p27Hierarchy(made)
            try expect(wrong.isEmpty, "classes: \(wrong)")
            return "\(n) requests / credentials of their class; \(made.count) system-made classes present"
        })
        #endif
        // MARK: NetworkExtension: a VPN configuration built from its parts (IKEv2 / IPSec protocols, SA parameters, PPK,
        // on-demand rules with connection rules, proxy settings, DNS over HTTPS / TLS, IPv6 routes, tunnel settings),
        // filter verdicts, hotspot settings, packets, the URL filter manager's parsing configuration, the DNS proxy
        // manager's answer, and the provider / flow classes only an extension gets (present with their superclass)
        #if canImport(NetworkExtension) && os(iOS)
        c.append(check("NetworkExtension", "p27-config-verdicts-providers", timeout: 30) {
            var n = 0
            func objc(_ o: AnyObject, _ cls: String) throws { n += 1; try expect(p27Is(o, cls), "\(type(of: o)) is not \(cls)") }
            let ike = NEVPNProtocolIKEv2()
            ike.serverAddress = "vpn.example.com"; ike.remoteIdentifier = "vpn.example.com"; ike.localIdentifier = "p27"; ike.authenticationMethod = .none
            ike.useExtendedAuthentication = true; ike.username = "p27"
            let sa: NEVPNIKEv2SecurityAssociationParameters = ike.ikeSecurityAssociationParameters
            sa.encryptionAlgorithm = .algorithmAES256GCM; sa.integrityAlgorithm = .SHA384; sa.diffieHellmanGroup = .group20; sa.lifetimeMinutes = 60
            ike.ppkConfiguration = NEVPNIKEv2PPKConfiguration(identifier: "ppk", keychainReference: Data([1, 2]))
            let ipsec = NEVPNProtocolIPSec(); ipsec.serverAddress = "ipsec.example.com"; ipsec.authenticationMethod = .sharedSecret
            let asProto: NEVPNProtocol = ipsec
            try objc(ike, "NEVPNProtocolIKEv2"); try objc(ipsec, "NEVPNProtocolIPSec"); try objc(sa, "NEVPNIKEv2SecurityAssociationParameters"); try objc(ike.ppkConfiguration!, "NEVPNIKEv2PPKConfiguration")
            let tpp = NETunnelProviderProtocol(); tpp.providerBundleIdentifier = "com.x86sim.test.sdkcov.tunnel"; tpp.providerConfiguration = ["k": "v"]; tpp.serverAddress = "t"
            try objc(tpp, "NETunnelProviderProtocol")
            // proxy settings on the protocol
            let px = NEProxySettings(); px.httpEnabled = true; px.httpServer = NEProxyServer(address: "proxy.example.com", port: 3128); px.exceptionList = ["*.local"]
            ike.proxySettings = px
            try objc(px, "NEProxySettings"); try objc(px.httpServer!, "NEProxyServer")
            // NSSecureCoding round trip of the IKEv2 protocol
            let ikeBack = try NSKeyedUnarchiver.unarchivedObject(ofClass: NEVPNProtocolIKEv2.self, from: NSKeyedArchiver.archivedData(withRootObject: ike, requiringSecureCoding: true))
            try expect(ikeBack?.serverAddress == "vpn.example.com" && ikeBack?.ikeSecurityAssociationParameters.diffieHellmanGroup == .group20 && ikeBack?.proxySettings?.httpServer?.port == 3128
                       && ikeBack?.ppkConfiguration?.identifier == "ppk" && asProto.serverAddress == "ipsec.example.com", "IKEv2 round trip")
            // on-demand rules
            let ecr = NEEvaluateConnectionRule(matchDomains: ["corp.example.com"], andAction: .connectIfNeeded); ecr.useDNSServers = ["10.0.0.53"]
            let eval = NEOnDemandRuleEvaluateConnection(); eval.connectionRules = [ecr]; eval.interfaceTypeMatch = .wiFi
            let rules: [NEOnDemandRule] = [eval, NEOnDemandRuleDisconnect(), NEOnDemandRuleIgnore(), NEOnDemandRuleConnect()]
            try objc(ecr, "NEEvaluateConnectionRule"); try objc(eval, "NEOnDemandRuleEvaluateConnection"); try objc(rules[1], "NEOnDemandRuleDisconnect"); try objc(rules[2], "NEOnDemandRuleIgnore")
            try expect(rules.map(\.action.rawValue) == [NEOnDemandRuleAction.evaluateConnection.rawValue, NEOnDemandRuleAction.disconnect.rawValue, NEOnDemandRuleAction.ignore.rawValue, NEOnDemandRuleAction.connect.rawValue], "rule actions")
            // tunnel network settings with encrypted DNS and an IPv6 route
            let ts = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "192.0.2.1")
            let doh = NEDNSOverHTTPSSettings(servers: ["1.1.1.1"]); doh.serverURL = URL(string: "https://dns.example.com/dns-query")
            let dot = NEDNSOverTLSSettings(servers: ["9.9.9.9"]); dot.serverName = "dns.quad9.net"
            ts.dnsSettings = doh
            let v6 = NEIPv6Settings(addresses: ["fd00::2"], networkPrefixLengths: [64])
            v6.includedRoutes = [NEIPv6Route.default(), NEIPv6Route(destinationAddress: "fd00:1::", networkPrefixLength: 48)]
            ts.ipv6Settings = v6; ts.proxySettings = px
            let base: NETunnelNetworkSettings = ts
            try objc(doh, "NEDNSOverHTTPSSettings"); try objc(dot, "NEDNSOverTLSSettings"); try objc(v6.includedRoutes![1], "NEIPv6Route"); try objc(base, "NETunnelNetworkSettings")
            try expect(base.tunnelRemoteAddress == "192.0.2.1" && (ts.dnsSettings as? NEDNSOverHTTPSSettings)?.serverURL?.host == "dns.example.com" && v6.includedRoutes?[1].destinationNetworkPrefixLength == 48, "tunnel settings")
            // filter verdicts
            let verdicts: [(NEFilterVerdict, String)] = [(NEFilterNewFlowVerdict.allow(), "NEFilterNewFlowVerdict"), (NEFilterNewFlowVerdict.needRules(), "NEFilterNewFlowVerdict"),
                (NEFilterDataVerdict.drop(), "NEFilterDataVerdict"), (NEFilterDataVerdict(passBytes: 10, peekBytes: 20), "NEFilterDataVerdict"),
                (NEFilterControlVerdict.allow(withUpdateRules: true), "NEFilterControlVerdict"), (NEFilterRemediationVerdict.needRules(), "NEFilterRemediationVerdict")]
            for (v, cls) in verdicts { try objc(v, cls); try objc(v, "NEFilterVerdict") }
            verdicts[0].0.shouldReport = true
            try expect(verdicts[0].0.shouldReport, "verdict report flag")
            let fpc = NEFilterProviderConfiguration(); fpc.filterBrowsers = true; fpc.filterSockets = true; fpc.organization = "p27"
            try objc(fpc, "NEFilterProviderConfiguration")
            // hotspot settings, private LTE, app rules, packets
            let eap = NEHotspotEAPSettings(); eap.supportedEAPTypes = [NEHotspotEAPSettings.EAPType.EAPTLS.rawValue as NSNumber]; eap.username = "p27"
            let hs20 = NEHotspotHS20Settings(domainName: "hotspot.example.com", roamingEnabled: true); hs20.naiRealmNames = ["example.com"]
            try objc(eap, "NEHotspotEAPSettings"); try objc(hs20, "NEHotspotHS20Settings")
            let lte = NEPrivateLTENetwork(); lte.mobileCountryCode = "315"; lte.mobileNetworkCode = "010"; lte.trackingAreaCode = "1"
            try objc(lte, "NEPrivateLTENetwork")
            let rule = NEAppRule(signingIdentifier: "com.apple.mobilesafari"); rule.matchDomains = ["example.com"]
            try objc(rule, "NEAppRule")
            let pkt = NEPacket(data: Data([0x45, 0, 0, 20]), protocolFamily: sa_family_t(AF_INET))
            try objc(pkt, "NEPacket"); try expect(pkt.data.count == 4 && pkt.protocolFamily == sa_family_t(AF_INET) && pkt.metadata == nil, "packet")
            let he = NWHostEndpoint(hostname: "example.com", port: "443"), be = NWBonjourServiceEndpoint(name: "p27", type: "_http._tcp", domain: "local")
            try objc(he, "NWHostEndpoint"); try objc(be, "NWBonjourServiceEndpoint"); try objc(NWTLSParameters(), "NWTLSParameters")
            try expect(he.port == "443" && be.type == "_http._tcp", "endpoints")
            // the URL filter manager's parsing configuration, the DNS proxy manager's preferences
            var pc = NEURLFilterManager.ParsingConfiguration(); pc.excludeFragment = true; pc.domain = .init(stripWWW: true, levels: 2)
            try expect(pc.domain.levels == 2 && pc.excludeFragment, "URL parsing configuration")
            let pre = NEURLFilterPrefilter.self; _ = pre
            let dns = NEDNSProxyManager.shared()
            let dnsAns: String
            do { try await dns.loadFromPreferences(); dnsAns = "loaded, enabled \(dns.isEnabled)" } catch { dnsAns = "threw \(p3Err(error))" }
            // what only an extension gets
            let made: [(String, String)] = [("NEProvider", "NSObject"), ("NETunnelProvider", "NEProvider"), ("NEPacketTunnelProvider", "NETunnelProvider"), ("NEAppProxyProvider", "NETunnelProvider"),
                ("NEDNSProxyProvider", "NEProvider"), ("NEFilterProvider", "NEProvider"), ("NEFilterDataProvider", "NEFilterProvider"), ("NEFilterControlProvider", "NEFilterProvider"),
                ("NEAppPushProvider", "NEProvider"), ("NEPacketTunnelFlow", "NSObject"), ("NEAppProxyFlow", "NSObject"), ("NEAppProxyTCPFlow", "NEAppProxyFlow"), ("NEAppProxyUDPFlow", "NEAppProxyFlow"),
                ("NEFilterFlow", "NSObject"), ("NEFilterBrowserFlow", "NEFilterFlow"), ("NEFilterSocketFlow", "NEFilterFlow"), ("NEFilterReport", "NSObject"), ("NEFlowMetaData", "NSObject"),
                ("NEVPNConnection", "NSObject"), ("NETunnelProviderSession", "NEVPNConnection"), ("NEAppProxyProviderManager", "NETunnelProviderManager"), ("NEDNSProxyProviderProtocol", "NEVPNProtocol"),
                ("NEHotspotHelper", "NSObject"), ("NEHotspotHelperCommand", "NSObject"), ("NEHotspotHelperResponse", "NSObject"), ("NWTCPConnection", "NSObject"), ("NWUDPSession", "NSObject"),
                ("NEURLFilter", "NSObject")]
            let wrong = p27Hierarchy(made)
            try expect(wrong.isEmpty, "classes: \(wrong)")
            // Swift-only extension configuration types
            let cfgTypes: [Any.Type] = [NEAppExtensionConfiguration.self, NEURLFilterControlProviderConfiguration.self, NEHotspotEvaluationProviderConfiguration.self, NEHotspotAuthenticationProviderConfiguration.self]
            let protos: [Any.Type] = [(any NEURLFilterControlProvider).self, (any NEHotspotEvaluationProvider).self, (any NEHotspotAuthenticationProvider).self, (any NEAppProxyUDPFlowHandling).self]
            try expect(cfgTypes.count == 4 && protos.count == 4, "types")
            return "\(n) configuration objects of their class; \(verdicts.count) verdicts; DNS proxy manager \(dnsAns); \(made.count) extension classes present"
        })
        #endif
        // MARK: MetricKit (iOS 27 Swift API): a MetricManager tracking a launch task, the metric groups / launch task ids /
        // state reporting domains, every report / metric / diagnostic type decoded from JSON missing its keys (each
        // throws keyNotFound: all are Codable with required fields), the MX units converted, and the MX payload classes
        #if canImport(MetricKit) && os(iOS)
        c.append(check("MetricKit", "p27-swift-api-units-classes", timeout: 30) {
            let mgr = MetricManager(enabledStateReportingDomains: ["com.x86sim.p27"])
            let domains: Set<StateReportingDomain> = mgr.enabledStateReportingDomains
            let (tracked, reasons) = try await onMain { () throws -> (Int, [String]) in
                var errs: [MetricManager.LaunchTaskError] = []
                let v = try mgr.trackLaunchTask(id: LaunchTaskID("p27.load"), onTrackingError: { errs.append($0) }) { () throws -> Int in 42 }
                return (v, errs.map { "\($0.taskID) \($0.reason)" })
            }
            // Apple's simulator: the operation runs (its value comes back) and the tracking error says the launch is
            // past its deadline (a check runs long after launch)
            try expect(tracked == 42 && reasons == ["p27.load pastDeadline"] && domains.map(\.rawValue) == ["com.x86sim.p27"], "launch task \(tracked) \(reasons), domains \(domains)")
            let groups: [MetricGroup] = [.cpu, .memory, .diskIO, .networkTransfer, .display, .animation, .applicationResponsiveness, .cellularCondition, .locationActivity, .gpu,
                                         .signpost, .appLaunch, .appRuntime, .appTermination, .diskSpaceUsage, .frameStatistics]
            try expect(Set(groups.map(\.rawValue)).count == 16 && LaunchTaskID(rawValue: "x").description == "x" && StateReportingDomain(rawValue: "d").description == "d", "groups \(groups.map(\.rawValue))")
            // decoding {} : keyNotFound for every type with required fields
            let empty = Data("{}".utf8)
            let types: [(String, (Data) throws -> Any)] = [
                ("AppLaunchDiagnostic", { try JSONDecoder().decode(AppLaunchDiagnostic.self, from: $0) }), ("CPUExceptionDiagnostic", { try JSONDecoder().decode(CPUExceptionDiagnostic.self, from: $0) }),
                ("CrashDiagnostic", { try JSONDecoder().decode(CrashDiagnostic.self, from: $0) }), ("DiskWriteExceptionDiagnostic", { try JSONDecoder().decode(DiskWriteExceptionDiagnostic.self, from: $0) }),
                ("HangDiagnostic", { try JSONDecoder().decode(HangDiagnostic.self, from: $0) }), ("MemoryExceptionDiagnostic", { try JSONDecoder().decode(MemoryExceptionDiagnostic.self, from: $0) }),
                ("CallStackTree", { try JSONDecoder().decode(CallStackTree.self, from: $0) }), ("CallStackThread", { try JSONDecoder().decode(CallStackThread.self, from: $0) }),
                ("CallStackFrame", { try JSONDecoder().decode(CallStackFrame.self, from: $0) }), ("DiagnosticReport", { try JSONDecoder().decode(DiagnosticReport.self, from: $0) }),
                ("DiagnosticResult", { try JSONDecoder().decode(DiagnosticResult.self, from: $0) }), ("SignpostRecord", { try JSONDecoder().decode(SignpostRecord.self, from: $0) }),
                ("AverageStatistics", { try JSONDecoder().decode(AverageStatistics<UnitDuration>.self, from: $0) }), ("Histogram", { try JSONDecoder().decode(Histogram<UnitDuration>.self, from: $0) }),
                ("HitchTimeMetric", { try JSONDecoder().decode(HitchTimeMetric.self, from: $0) }), ("CPUInstructionsCountMetric", { try JSONDecoder().decode(CPUInstructionsCountMetric.self, from: $0) }),
                ("CPUTimeMetric", { try JSONDecoder().decode(CPUTimeMetric.self, from: $0) }), ("TotalDiskSpaceCapacityMetric", { try JSONDecoder().decode(TotalDiskSpaceCapacityMetric.self, from: $0) }),
                ("TotalFileCountMetric", { try JSONDecoder().decode(TotalFileCountMetric.self, from: $0) }), ("TotalFileSizeMetric", { try JSONDecoder().decode(TotalFileSizeMetric.self, from: $0) }),
                ("MetalFrameRateMetric", { try JSONDecoder().decode(MetalFrameRateMetric.self, from: $0) }), ("ApplicationResumeTimeMetric", { try JSONDecoder().decode(ApplicationResumeTimeMetric.self, from: $0) }),
                ("ExtendedLaunchMetric", { try JSONDecoder().decode(ExtendedLaunchMetric.self, from: $0) }), ("OptimizedTimeToFirstDrawMetric", { try JSONDecoder().decode(OptimizedTimeToFirstDrawMetric.self, from: $0) }),
                ("TimeToFirstDrawMetric", { try JSONDecoder().decode(TimeToFirstDrawMetric.self, from: $0) }), ("PeakMemoryMetric", { try JSONDecoder().decode(PeakMemoryMetric.self, from: $0) }),
                ("SuspendedMemoryMetric", { try JSONDecoder().decode(SuspendedMemoryMetric.self, from: $0) }), ("TotalCellularDownloadMetric", { try JSONDecoder().decode(TotalCellularDownloadMetric.self, from: $0) }),
                ("TotalCellularUploadMetric", { try JSONDecoder().decode(TotalCellularUploadMetric.self, from: $0) }), ("TotalWiFiDownloadMetric", { try JSONDecoder().decode(TotalWiFiDownloadMetric.self, from: $0) }),
                ("TotalWiFiUploadMetric", { try JSONDecoder().decode(TotalWiFiUploadMetric.self, from: $0) }), ("TotalBackgroundAudioTimeMetric", { try JSONDecoder().decode(TotalBackgroundAudioTimeMetric.self, from: $0) }),
                ("TotalBackgroundLocationTimeMetric", { try JSONDecoder().decode(TotalBackgroundLocationTimeMetric.self, from: $0) }), ("TotalBackgroundTimeMetric", { try JSONDecoder().decode(TotalBackgroundTimeMetric.self, from: $0) }),
                ("TotalForegroundTimeMetric", { try JSONDecoder().decode(TotalForegroundTimeMetric.self, from: $0) }), ("BackgroundTerminationMetric", { try JSONDecoder().decode(BackgroundTerminationMetric.self, from: $0) }),
                ("ForegroundTerminationMetric", { try JSONDecoder().decode(ForegroundTerminationMetric.self, from: $0) }), ("CellularConditionTimeMetric", { try JSONDecoder().decode(CellularConditionTimeMetric.self, from: $0) }),
                ("GPUTimeMetric", { try JSONDecoder().decode(GPUTimeMetric.self, from: $0) }), ("HangTimeMetric", { try JSONDecoder().decode(HangTimeMetric.self, from: $0) }),
                ("LocationActivityTimeMetric", { try JSONDecoder().decode(LocationActivityTimeMetric.self, from: $0) }), ("LogicalDiskWritesMetric", { try JSONDecoder().decode(LogicalDiskWritesMetric.self, from: $0) }),
                ("PixelLuminanceMetric", { try JSONDecoder().decode(PixelLuminanceMetric.self, from: $0) }), ("SignpostIntervalMetric", { try JSONDecoder().decode(SignpostIntervalMetric.self, from: $0) }),
                ("MetricReport", { try JSONDecoder().decode(MetricReport.self, from: $0) }), ("MetricResult", { try JSONDecoder().decode(MetricResult.self, from: $0) }),
                ("OSVersion", { try JSONDecoder().decode(OSVersion.self, from: $0) }), ("ReportedState", { try JSONDecoder().decode(MetricManager.ReportedState.self, from: $0) })]
            var notThrown: [String] = [], kinds: [String: Int] = [:]
            for (name, dec) in types {
                do { _ = try dec(empty); notThrown.append(name) }
                catch let e as DecodingError {
                    switch e { case .keyNotFound: kinds["keyNotFound", default: 0] += 1; case .typeMismatch: kinds["typeMismatch", default: 0] += 1; case .dataCorrupted: kinds["dataCorrupted", default: 0] += 1; default: kinds["other", default: 0] += 1 }
                } catch { kinds["\(type(of: error))", default: 0] += 1 }
            }
            try expect(notThrown.isEmpty, "decoded from {}: \(notThrown)")
            // the MX units
            let bars = Measurement(value: 3, unit: MXUnitSignalBars.bars)
            let apl = Measurement(value: 120, unit: MXUnitAveragePixelLuminance.apl)
            try expect(bars.value == 3 && apl.unit.symbol == "apl" && MXUnitSignalBars.baseUnit() == MXUnitSignalBars.bars, "units \(bars) \(apl)")
            // the MX payload / metric / diagnostic classes (MetricKit alone makes them): present, NSSecureCoding
            let mx: [(String, String)] = [("MXMetric", "NSObject"), ("MXAnimationMetric", "MXMetric"), ("MXAppExitMetric", "MXMetric"), ("MXAppLaunchMetric", "MXMetric"),
                ("MXAppResponsivenessMetric", "MXMetric"), ("MXAppRunTimeMetric", "MXMetric"), ("MXCPUMetric", "MXMetric"), ("MXCellularConditionMetric", "MXMetric"), ("MXDiskIOMetric", "MXMetric"),
                ("MXDiskSpaceUsageMetric", "MXMetric"), ("MXDisplayMetric", "MXMetric"), ("MXGPUMetric", "MXMetric"), ("MXLocationActivityMetric", "MXMetric"), ("MXMemoryMetric", "MXMetric"),
                ("MXNetworkTransferMetric", "MXMetric"), ("MXSignpostMetric", "MXMetric"), ("MXSignpostIntervalData", "NSObject"), ("MXSignpostRecord", "NSObject"),
                ("MXBackgroundExitData", "NSObject"), ("MXForegroundExitData", "NSObject"), ("MXMetaData", "NSObject"), ("MXMetricPayload", "NSObject"), ("MXDiagnosticPayload", "NSObject"),
                ("MXDiagnostic", "NSObject"), ("MXAppLaunchDiagnostic", "MXDiagnostic"), ("MXCPUExceptionDiagnostic", "MXDiagnostic"), ("MXCrashDiagnostic", "MXDiagnostic"),
                ("MXDiskWriteExceptionDiagnostic", "MXDiagnostic"), ("MXHangDiagnostic", "MXDiagnostic"), ("MXCrashDiagnosticObjectiveCExceptionReason", "NSObject"), ("MXCallStackTree", "NSObject"),
                ("MXUnitSignalBars", "NSDimension"), ("MXUnitAveragePixelLuminance", "NSDimension")]
            let wrong = p27Hierarchy(mx)
            let notCoding = mx.filter { !(NSClassFromString($0.0)?.conforms(to: NSSecureCoding.self) ?? false) && $0.1 != "NSDimension" }.map(\.0)
            try expect(wrong.isEmpty && notCoding.isEmpty, "classes \(wrong), not NSSecureCoding \(notCoding)")
            return "launch task ran, tracking error \(reasons), 16 groups; \(types.count) Codable types throw on {} \(kinds); units; \(mx.count) MX classes"
        })
        #endif
        // MARK: Network: addresses (IPAddress protocol), interfaces, errors, the protocol option / definition / metadata
        // classes, the iOS 26 protocol-stack types (DTLS / QUIC / Framer values, parameter builder, coders, TXT record
        // decoder, Bonjour listener provider, proxy configuration, multiplex group)
        #if canImport(Network)
        c.append(check("Network", "p27-types-stacks-coders", timeout: 30) {
            func addr<A: IPAddress>(_ a: A) -> (Int, Bool) { (a.rawValue.count, a.isLoopback) }
            guard let v4 = IPv4Address("127.0.0.1"), let v6 = IPv6Address("::1"), let lan = IPv4Address("192.168.1.20") else { throw Fail("address parse") }
            try expect(addr(v4) == (4, true) && addr(v6) == (16, true) && !lan.isLoopback && lan.debugDescription == "192.168.1.20" && IPv4Address("300.1.1.1") == nil, "addresses")
            let types: [NWInterface.InterfaceType] = [.wifi, .cellular, .wiredEthernet, .loopback, .other]
            let monitor = NWPathMonitor(requiredInterfaceType: .loopback)
            let ifaces: [NWInterface] = monitor.currentPath.availableInterfaces
            try expect(types.count == 5, "interface types \(ifaces.map(\.name))")
            let errs: [NWError] = [.posix(.ECONNREFUSED), .dns(DNSServiceErrorType(kDNSServiceErr_NoSuchRecord)), .tls(errSSLClosedAbort)]
            try expect(errs[0] == .posix(.ECONNREFUSED) && errs[0] != errs[1] && !errs[2].debugDescription.isEmpty, "errors \(errs.map(\.debugDescription))")
            // protocol options / definitions / metadata classes
            let tcp = NWProtocolTCP.Options(); tcp.noDelay = true; tcp.connectionTimeout = 5
            let udp = NWProtocolUDP.Options(); udp.preferNoChecksum = true
            guard let ip = NWParameters.udp.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options else { throw Fail("no IP options in the UDP stack") }
            ip.version = .v6; ip.hopLimit = 9
            let opts: [NWProtocolOptions] = [tcp, udp, ip]
            let defs: [NWProtocolDefinition] = [NWProtocolTCP.definition, NWProtocolUDP.definition, NWProtocolIP.definition, NWProtocolTLS.definition]
            try expect(opts.count == 3 && Set(defs.map(\.name)).count == 4 && defs[0].name == "tcp" && defs[1] == NWProtocolUDP.definition, "definitions \(defs.map(\.name))")
            let ipMeta = NWProtocolIP.Metadata().ecn(.ect0).serviceClass(.interactiveVoice)
            let metas: [NWProtocolMetadata] = [ipMeta, NWProtocolUDP.Metadata()]
            try expect(ipMeta.ecn == .ect0 && ipMeta.serviceClass == .interactiveVoice && metas.count == 2, "IP metadata")
            let protoTypes: [NWProtocol.Type] = [NWProtocolTCP.self, NWProtocolUDP.self, NWProtocolIP.self]
            try expect(protoTypes.count == 3, "protocol classes")
            // iOS 26 protocol stack values
            let dtls = DTLS { UDP() }
            let builder = NWParametersBuilder.parameters { DTLS() }.expensivePathsProhibited(true).prohibitedInterfaceTypes([.cellular])
            func provider<P: NWParametersProvider>(_ p: P) -> NWParameters { p.parameters }
            let params = provider(builder)
            try expect(params.prohibitExpensivePaths && params.prohibitedInterfaceTypes == [.cellular], "parameter builder")
            func dg<P: DatagramProtocol>(_: P) -> Bool { true }
            func msg<P: MessageProtocol>(_: P.Type) -> Bool { true }
            func stream<P: StreamProtocol>(_: P.Type) -> Bool { true }
            func oneToOne<P: OneToOneProtocol>(_: P.Type) -> Bool { true }
            func opt<P: NetworkProtocolOptions>(_: P.Type) -> Bool { true }
            try expect(dg(dtls) && msg(QUICDatagram.self) && stream(QUICStream.self) && oneToOne(DTLS.self) && opt(QUICStream.self), "protocol conformances")
            let storage: any ConnectionStorage.Type = DefaultProtocolStorage.self
            let metaTypes: [any NetworkMetadataProtocol.Type] = [DTLS.Metadata.self, QUICDatagram.Metadata.self, QUICStream.Metadata.self]
            try expect(storage == DTLS.ProtocolStorage.self && metaTypes.count == 3, "storage / metadata")
            let more: [Any.Type] = [(any MultiplexProtocol).self, (any FramerProtocol).self, Framer<P27Framer>.self, (any Connectable).self, (any BrowserProvider).self, (any ListenerProvider).self,
                                    (any NWGroupDescriptor).self, (any NetworkFixedWidthInteger).self, NetworkChannel<QUICStream>.self, ProtocolStackBuilder<UDP>.self, ProtocolMetadataBuilder.self]
            try expect(more.count == 11 && P27Framer.definition === P27FramerImpl.definition, "framer definition")
            // coders
            struct Msg: Codable, Equatable { let name: String; let n: Int }
            func roundTrip<C: NetworkCoder>(_ c: C) throws -> Bool {
                let enc: C.Encoder = c.makeEncoder(), dec: C.Decoder = c.makeDecoder()
                func e<E: NetworkEncoder>(_ x: E) throws -> Data { try x.encode(Msg(name: "p27", n: 5)) }
                func d<D: NetworkDecoder>(_ x: D, _ data: Data) throws -> Msg { try x.decode(Msg.self, from: data) }
                return try d(dec, try e(enc)) == Msg(name: "p27", n: 5)
            }
            try expect(try roundTrip(NetworkJSONCoder()) && (try roundTrip(NetworkPropertyListCoder())) && (try roundTrip(.json)), "coders")
            struct TXT: Decodable { let name: String; let n: String }
            let txt = try TXTRecordDecoder().decode(TXT.self, from: NWTXTRecord(["name": "p27", "n": "5"]))
            try expect(txt.name == "p27" && txt.n == "5", "TXT decoder")
            let bonjour = BonjourListenerProvider(name: "p27", type: "_p27._tcp")
            try expect(bonjour.service.type == "_p27._tcp" && bonjour.service.name == "p27", "Bonjour listener provider")
            var proxy = ProxyConfiguration(socksv5Proxy: .hostPort(host: "127.0.0.1", port: 1080)); proxy.matchDomains = ["example.com"]; proxy.allowFailover = true
            try expect(proxy.matchDomains == ["example.com"] && proxy.allowFailover && !proxy.debugDescription.isEmpty, "proxy configuration")
            let group = NWMultiplexGroup(to: .hostPort(host: "example.com", port: 443))
            try expect(group.members.count == 1, "multiplex group")
            let unexpected = UnexpectedEndpointType(endpoint: .hostPort(host: "h", port: 1))
            if case .hostPort(let h, _) = unexpected.endpoint { try expect("\(h)" == "h", "unexpected endpoint") }
            return "addresses, \(ifaces.count) loopback-path interfaces, errors, \(defs.count) definitions, stack builder, coders, TXT, Bonjour provider, proxy, multiplex group"
        })
        #endif
        // MARK: PassKit: the payment request kinds (recurring, deferred, automatic reload, disbursement) with their
        // summary items, the request updates and authorization results, payment token context / order details / merchant
        // session, the identity request descriptors and elements, the add-pass configurations and buttons, the issuer
        // provisioning extension values, and the classes only Wallet hands out (present with their superclass)
        #if canImport(PassKit)
        c.append(check("PassKit", "p27-requests-updates-identity", timeout: 30) {
            var n = 0
            func objc(_ o: AnyObject, _ cls: String) throws { n += 1; try expect(p27Is(o, cls), "\(type(of: o)) is not \(cls)") }
            let amount = NSDecimalNumber(string: "9.99")
            let range = PKDateComponentsRange(start: DateComponents(calendar: .current, year: 2026, month: 1, day: 1), end: DateComponents(calendar: .current, year: 2027, month: 1, day: 1))
            try expect(range != nil && range!.endDateComponents.year == 2027, "date range"); try objc(range!, "PKDateComponentsRange")
            let contact = PKContact(); contact.emailAddress = "p27@example.com"; contact.name = PersonNameComponents(givenName: "P", familyName: "27")
            try objc(contact, "PKContact")
            let lv = PKLabeledValue(label: "Seat", value: "12A"); try objc(lv, "PKLabeledValue")
            let auth = PKPaymentAuthorizationResult(status: .failure, errors: [PKPaymentRequest.paymentContactInvalidError(withContactField: .emailAddress, localizedDescription: "bad")])
            try objc(auth, "PKPaymentAuthorizationResult"); try expect(auth.status == .failure && auth.errors.count == 1, "authorization result")
            let item = PKPaymentSummaryItem(label: "P27", amount: amount)
            let upd = PKPaymentRequestUpdate(paymentSummaryItems: [item]); upd.status = .success
            let updates: [(PKPaymentRequestUpdate, String)] = [(upd, "PKPaymentRequestUpdate"), (PKPaymentRequestShippingContactUpdate(errors: nil, paymentSummaryItems: [item], shippingMethods: []), "PKPaymentRequestShippingContactUpdate"),
                (PKPaymentRequestShippingMethodUpdate(paymentSummaryItems: [item]), "PKPaymentRequestShippingMethodUpdate"), (PKPaymentRequestPaymentMethodUpdate(errors: nil, paymentSummaryItems: [item]), "PKPaymentRequestPaymentMethodUpdate")]
            for (u, cls) in updates { try objc(u, cls); try expect(u.paymentSummaryItems.first?.amount == amount, "\(cls) items") }
            let session = PKPaymentMerchantSession(dictionary: ["merchantIdentifier": "p27"])
            try objc(session, "PKPaymentMerchantSession"); try objc(PKPaymentRequestMerchantSessionUpdate(status: .success, merchantSession: session), "PKPaymentRequestMerchantSessionUpdate")
            try objc(PKPaymentMethod(), "PKPaymentMethod")
            let deferredItem = PKDeferredPaymentSummaryItem(label: "Later", amount: amount); deferredItem.deferredDate = Date(timeIntervalSince1970: 1_800_000_000)
            let recurItem = PKRecurringPaymentSummaryItem(label: "Monthly", amount: amount); recurItem.intervalUnit = .month; recurItem.intervalCount = 1
            try objc(deferredItem, "PKDeferredPaymentSummaryItem"); try objc(recurItem, "PKRecurringPaymentSummaryItem")
            try expect(recurItem.intervalUnit == .month && deferredItem.deferredDate.timeIntervalSince1970 == 1_800_000_000, "summary items")
            var made: [(String, String)] = [("PKObject", "NSObject"), ("PKPayment", "NSObject"), ("PKPaymentToken", "NSObject"), ("PKPaymentPass", "PKSecureElementPass"), ("PKSecureElementPass", "PKPass"),
                ("PKStoredValuePassBalance", "NSObject"), ("PKStoredValuePassProperties", "NSObject"), ("PKTransitPassProperties", "PKStoredValuePassProperties"), ("PKSuicaPassProperties", "PKTransitPassProperties"),
                ("PKPassRelevantDate", "NSObject"), ("PKAddPassButton", "UIButton"), ("PKPaymentButton", "UIButton"), ("PKPaymentAuthorizationViewController", "UIViewController"),
                ("PKAddPaymentPassViewController", "UIViewController"), ("PKAddSecureElementPassViewController", "UIViewController"), ("PKShareSecureElementPassViewController", "UIViewController"),
                ("PKBarcodeEventMetadataRequest", "NSObject"), ("PKBarcodeEventSignatureRequest", "NSObject"), ("PKBarcodeEventConfigurationRequest", "NSObject"),
                ("PKPaymentInformationEventExtension", "NSObject"), ("PKVehicleConnectionSession", "NSObject")]
            #if os(watchOS)
            made = made.filter { !["PKAddPassButton", "PKPaymentButton", "PKPaymentAuthorizationViewController", "PKAddPaymentPassViewController", "PKAddSecureElementPassViewController", "PKShareSecureElementPassViewController"].contains($0.0) }
            #endif
            try objc(PKBarcodeEventMetadataResponse(paymentInformation: Data([1])), "PKBarcodeEventMetadataResponse"); try objc(PKBarcodeEventSignatureResponse(signedData: Data([2])), "PKBarcodeEventSignatureResponse")
            #if os(iOS)
            let reload = PKAutomaticReloadPaymentSummaryItem(label: "Top up", amount: amount); reload.thresholdAmount = NSDecimalNumber(string: "5")
            let recurring = PKRecurringPaymentRequest(paymentDescription: "P27 plan", regularBilling: recurItem, managementURL: URL(string: "https://example.com/m")!)
            let deferred = PKDeferredPaymentRequest(paymentDescription: "P27 later", deferredBilling: deferredItem, managementURL: URL(string: "https://example.com/d")!)
            let auto = PKAutomaticReloadPaymentRequest(paymentDescription: "P27 reload", automaticReloadBilling: reload, managementURL: URL(string: "https://example.com/r")!)
            try objc(reload, "PKAutomaticReloadPaymentSummaryItem"); try objc(recurring, "PKRecurringPaymentRequest"); try objc(deferred, "PKDeferredPaymentRequest"); try objc(auto, "PKAutomaticReloadPaymentRequest")
            let req = PKPaymentRequest(); req.merchantIdentifier = "merchant.com.x86sim"; req.countryCode = "US"; req.currencyCode = "USD"; req.supportedNetworks = [.visa]; req.merchantCapabilities = .threeDSecure
            req.paymentSummaryItems = [item]; req.recurringPaymentRequest = recurring; req.deferredPaymentRequest = deferred; req.automaticReloadPaymentRequest = auto
            let tokenCtx = PKPaymentTokenContext(merchantIdentifier: "merchant.com.x86sim", externalIdentifier: "ext", merchantName: "P27", merchantDomain: "example.com", amount: amount)
            req.multiTokenContexts = [tokenCtx]
            try objc(tokenCtx, "PKPaymentTokenContext")
            try expect(req.recurringPaymentRequest?.regularBilling.intervalUnit == .month && req.automaticReloadPaymentRequest?.automaticReloadBilling.thresholdAmount == 5, "request kinds")
            let order = PKPaymentOrderDetails(orderTypeIdentifier: "com.x86sim.order", orderIdentifier: "o1", webServiceURL: URL(string: "https://example.com/o")!, authenticationToken: "t")
            try objc(order, "PKPaymentOrderDetails"); try objc(PKPaymentRequestCouponCodeUpdate(errors: nil, paymentSummaryItems: [item], shippingMethods: []), "PKPaymentRequestCouponCodeUpdate")
            let fee = PKInstantFundsOutFeeSummaryItem(label: "Fee", amount: NSDecimalNumber(string: "0.5")), payout = PKDisbursementSummaryItem(label: "Payout", amount: amount)
            let disb = PKDisbursementRequest(merchantIdentifier: "merchant.com.x86sim", currency: "USD", region: .unitedStates, supportedNetworks: [.visa], merchantCapabilities: .instantFundsOut, summaryItems: [fee, payout])
            try objc(fee, "PKInstantFundsOutFeeSummaryItem"); try objc(payout, "PKDisbursementSummaryItem"); try objc(disb, "PKDisbursementRequest")
            // a view controller for a request the simulator can't pay with: nil without cards
            let pvc = PKPaymentAuthorizationViewController(paymentRequest: req)
            let canPay = PKPaymentAuthorizationViewController.canMakePayments(usingNetworks: [.visa])
            let ui = try await onMain { () -> [String] in
                var out: [String] = []
                for (v, cls) in [(PKAddPassButton(addPassButtonStyle: .black) as UIView, "PKAddPassButton"), (PKPaymentButton(paymentButtonType: .buy, paymentButtonStyle: .black), "PKPaymentButton"),
                                 (PKIdentityButton(label: .verifyIdentity, style: .black), "PKIdentityButton")] {
                    if p27Is(v, cls) && v.intrinsicContentSize.width > 0 { out.append(cls) }
                }
                return out
            }
            // Apple's simulator: the add-pass and payment buttons have an intrinsic width, the identity button none
            try expect(ui == ["PKAddPassButton", "PKPaymentButton"], "buttons with an intrinsic width \(ui)")
            // add-pass configurations / metadata
            let car = PKAddCarKeyPassConfiguration(); car.password = "1234"; car.supportedRadioTechnologies = [.NFC]
            try objc(car, "PKAddCarKeyPassConfiguration"); try objc(car, "PKAddSecureElementPassConfiguration")
            let preview = PKShareablePassMetadata.Preview(templateIdentifier: "tmpl"); preview.ownerDisplayName = "P27"
            let share = PKShareablePassMetadata(provisioningCredentialIdentifier: "cred", sharingInstanceIdentifier: "inst", cardTemplateIdentifier: "tmpl", preview: preview)
            try objc(preview, "PKShareablePassMetadataPreview"); try objc(share, "PKShareablePassMetadata")
            try objc(PKAddPaymentPassRequest(), "PKAddPaymentPassRequest")
            if let ppc = PKAddPaymentPassRequestConfiguration(encryptionScheme: .ECC_V2) { ppc.cardholderName = "P 27"; ppc.primaryAccountSuffix = "1234"; try objc(ppc, "PKAddPaymentPassRequestConfiguration") } else { throw Fail("payment pass configuration nil") }
            let status = PKIssuerProvisioningExtensionStatus(); status.requiresAuthentication = true; status.passEntriesAvailable = true
            try objc(status, "PKIssuerProvisioningExtensionStatus")
            made += [("PKAddShareablePassConfiguration", "PKAddSecureElementPassConfiguration"), ("PKAddIdentityDocumentConfiguration", "PKAddSecureElementPassConfiguration"),
                     ("PKAddIdentityDocumentMetadata", "PKIdentityDocumentMetadata"), ("PKIdentityDocumentMetadata", "NSObject"), ("PKJapanIndividualNumberCardMetadata", "PKIdentityDocumentMetadata"),
                     ("PKAddPassMetadataPreview", "NSObject"), ("PKIssuerProvisioningExtensionHandler", "NSObject"), ("PKIssuerProvisioningExtensionPassEntry", "NSObject"),
                     ("PKIssuerProvisioningExtensionPaymentPassEntry", "PKIssuerProvisioningExtensionPassEntry"), ("PKIdentityDocument", "NSObject"), ("PKPayLaterView", "UIView")]
            // identity requests
            let dl = PKIdentityDriversLicenseDescriptor()
            dl.addElements([.givenName, .familyName, .age(atLeast: 21)], intentToStore: .willNotStore)
            let nid = PKIdentityNationalIDCardDescriptor(); nid.addElements([.portrait], intentToStore: .mayStore(days: 30))
            let photo = PKIdentityPhotoIDDescriptor(); photo.addElements([.documentNumber], intentToStore: .willNotStore)
            let any = PKIdentityAnyOfDescriptor(descriptors: [dl, nid, photo])
            let ireq = PKIdentityRequest(); ireq.descriptor = any; ireq.merchantIdentifier = "merchant.com.x86sim"; ireq.nonce = Data([1, 2])
            try objc(dl, "PKIdentityDriversLicenseDescriptor"); try objc(nid, "PKIdentityNationalIDCardDescriptor"); try objc(photo, "PKIdentityPhotoIDDescriptor"); try objc(any, "PKIdentityAnyOfDescriptor"); try objc(ireq, "PKIdentityRequest")
            try objc(PKIdentityElement.age(atLeast: 18), "PKIdentityElement"); try objc(PKIdentityIntentToStore.mayStore(days: 30), "PKIdentityIntentToStore")
            let intent = dl.intentToStore(element: .givenName)
            try expect(dl.elements.count == 3 && intent != nil && any.descriptors.count == 3, "identity descriptors: \(dl.elements.count) elements, intent \(String(describing: intent)), any of \(any.descriptors.count)")
            let canPayInfo = "payment controller \(pvc == nil ? "nil" : "made"), canMakePayments(visa) \(canPay)"
            #else
            let canPayInfo = "watchOS"
            #endif
            let wrong = p27Hierarchy(made)
            try expect(wrong.isEmpty, "classes: \(wrong)")
            return "\(n) objects of their class; \(made.count) Wallet-made classes present; \(canPayInfo)"
        })
        #endif
        // MARK: ProximityReader: the mobile document requests (data / raw data / display / any-of, every document kind),
        // payment card transaction and verification requests, VAS requests and read results, store-and-forward tokens;
        // the simulator's answers for support, the reader store and preparing a store-and-forward session
        #if canImport(ProximityReader) && os(iOS)
        c.append(check("ProximityReader", "p27-requests-reader-answers", timeout: 50) {
            let jp = Locale.Region("JP")
            func req<R: MobileDocumentRequest>(_ r: R) -> Int { r.hashValue == r.hashValue ? 1 : 0 }
            func data<R: MobileDocumentDataRequest>(_ r: R) -> Int { req(r) }
            func raw<R: MobileDocumentRawDataRequest>(_ r: R) -> Int { req(r) }
            let count = data(MobilePhotoIDDataRequest()) + raw(MobilePhotoIDRawDataRequest()) + req(MobileDriversLicenseDataRequest()) + req(MobileDriversLicenseRawDataRequest())
                + req(MobileNationalIDCardDataRequest(region: jp)) + req(MobileNationalIDCardRawDataRequest(region: jp)) + req(MobileNationalIDCardDisplayRequest(region: jp))
                + req(MobileDocumentDisplayRequest()) + req(MobileDriversLicenseDisplayRequest()) + req(MobileDocumentAnyOfDataRequest()) + req(MobileDocumentAnyOfRawDataRequest())
            let regions = ["JP", "US", "GB"].map { MobileNationalIDCardDataRequest.isSupportedRegion(Locale.Region($0)) }
            let respTypes: [Any.Type] = [(any MobileDocumentDataResponse).self, MobileDocumentHolderName.self, MobileDocumentReaderError.self]
            try expect(count == 11 && respTypes.count == 3, "document requests \(count)")
            let txn = PaymentCardTransactionRequest(amount: Decimal(string: "12.34")!, currencyCode: "USD", for: .purchase)
            let ver = PaymentCardVerificationRequest(currencyCode: "USD", for: .other)
            let vas = VASRequest(vasMerchants: [], localizedVASType: "loyalty")
            let vres = VASReadResult(id: "r1", entries: [])
            let tok = StoreAndForwardBatchDeletionToken(rawValue: "t1")
            try expect(txn.amount == Decimal(string: "12.34")! && ver.currencyCode == "USD" && vres.id == "r1" && vres.entries.isEmpty && tok.rawValue == "t1", "payment values")
            let more: [Any.Type] = [PaymentCardReadResult.self, StoreAndForwardBatch.self, StoreAndForwardStatus.self, StoreAndForwardPaymentCardReaderSession.self, PaymentCardReaderSession.self,
                                    PaymentCardReaderStore.self, PaymentCardReaderError.self, CustomerEngagement.self, type(of: vas)]
            // the simulator's answers
            let supported = PaymentCardReader.isSupported, docSupported = MobileDocumentReader.isSupported
            let reader = PaymentCardReader()
            var store = "", sf = ""
            do { let s: PaymentCardReaderStore = try reader.fetchPaymentCardReaderStore(); store = "store, \(try await s.fetchStoredPaymentCardReadResultCount()) results" } catch let e as PaymentCardReaderError { store = "PaymentCardReaderError \(e)" } catch { store = "threw \(p3Err(error))" }
            sf = await p5Within(30) { () async throws -> String in
                do { _ = try await reader.prepareStoreAndForward(); return "session" } catch let e as PaymentCardReaderError { return "PaymentCardReaderError \(e)" } catch { return "threw \(p3Err(error))" }
            } ?? "no answer in 20 s"
            let d = "card reader supported \(supported), documents \(docSupported); NID regions JP/US/GB \(regions); reader store: \(store); store-and-forward: \(sf); \(more.count) types"
            // Apple's simulator: the card reader supported, documents not; the reader store throws StoreError 1; preparing a
            // store-and-forward session throws PaymentCardReaderError.notAllowed (after ~15 s)
            try expect(supported && !docSupported && store.hasSuffix("StoreError 1") && sf == "ok: PaymentCardReaderError notAllowed", d)
            return d
        })
        #endif
        // MARK: FinanceKit: queries with their predicates, merchant category codes, transaction status / type / credit-debit
        // enums, order identifiers, the Codable balance model decoded from JSON, errors and authorization statuses
        #if canImport(FinanceKit) && os(iOS)
        c.append(check("FinanceKit", "p27-queries-models", timeout: 20) {
            let mcc = MerchantCategoryCode(rawValue: 5812)
            let byMCC: Predicate<FinanceKit.Transaction> = TransactionQuery.predicate(forMerchantCategoryCodes: [mcc])
            let tq = TransactionQuery(sortDescriptors: [SortDescriptor(\FinanceKit.Transaction.transactionDate, order: .reverse)], predicate: byMCC, limit: 10)
            let sq = TransactionQuery(predicate: TransactionQuery.predicate(forStatuses: [TransactionStatus.booked, .pending]))
            let ty = TransactionQuery(predicate: TransactionQuery.predicate(forTransactionTypes: [TransactionType.pointOfSale, .refund]))
            let aq = AccountQuery(limit: 5), bq = AccountBalanceQuery(predicate: AccountBalanceQuery.predicate(bookedSince: Date(timeIntervalSince1970: 0)), limit: 1)
            let queries: [Any] = [tq, sq, ty, aq, bq]
            try expect(queries.count == 5, "queries")
            try expect(TransactionStatus.allCases.count == 5 && TransactionType.allCases.count == 17 && CreditDebitIndicator.allCases == [.credit, .debit] && TransactionType(rawValue: 10) != nil, "enums")
            let oid = FullyQualifiedOrderIdentifier(orderTypeIdentifier: "com.x86sim.order", orderIdentifier: "o1")
            let oBack = try JSONDecoder().decode(FullyQualifiedOrderIdentifier.self, from: JSONEncoder().encode(oid))
            try expect(oBack == oid && mcc.rawValue == 5812, "order identifier")
            // the Codable models through JSON
            let bal = Data(#"{"amount":{"amount":12.5,"currencyCode":"USD"},"asOfDate":0,"creditDebitIndicator":0}"#.utf8)
            var model = ""
            do {
                let b = try JSONDecoder().decode(Balance.self, from: bal)
                let cur = CurrentBalance.available(b)
                let amt: CurrencyAmount = b.amount
                model = "balance \(amt.amount) \(amt.currencyCode) \(b.creditDebitIndicator)"
                if case .available(let x) = cur { try expect(x == b, "current balance") }
            } catch { model = "Balance decode threw \(type(of: error))" }
            let credit = try? JSONDecoder().decode(AccountCreditInformation.self, from: Data("{}".utf8))
            let types: [Any.Type] = [AssetAccount.self, LiabilityAccount.self, AccountBalance.self, AccountCreditInformation.self, (any BackgroundDeliveryExtensionProviding).self,
                                     (any BackgroundDeliveryExtension).self]
            let auth: [AuthorizationStatus] = [.notDetermined, .denied, .authorized]
            let errs: [FinanceError] = [.dataRestricted(.financialData), .unknown, .historyTokenInvalid]
            try expect(types.count == 6 && auth.count == 3 && errs[0] != errs[1] && !errs[0].localizedDescription.isEmpty, "types / errors")
            return "queries + predicates, enums, order id; \(model); credit info from {} \(credit == nil ? "rejected" : "decoded"); \(errs.map { "\($0.errorCode)" })"
        })
        #endif
        // MARK: CryptoTokenKit: BER / COMPACT / SIMPLE TLV records built, encoded and parsed back, an ATR parsed (protocols,
        // interface groups, historical bytes), PIN format and auth operations, the token driver configurations of the
        // app's token extension, the token watcher, and the smart card classes a reader hands out
        #if canImport(CryptoTokenKit)
        c.append(check("CryptoTokenKit", "p27-tlv-atr-pin-config", timeout: 30) {
            let inner = TKBERTLVRecord(tag: 0x80, value: Data([1, 2, 3]))
            let outer = TKBERTLVRecord(tag: 0x7F49, records: [inner, TKBERTLVRecord(tag: 0x81, value: Data())])
            try expect(TKBERTLVRecord.data(forTag: 0x7F49) == Data([0x7F, 0x49]) && outer.data.prefix(2) == Data([0x7F, 0x49]), "BER tag encoding \(outer.data as NSData)")
            guard let parsed = TKBERTLVRecord(from: outer.data), let kids = TKBERTLVRecord.sequenceOfRecords(from: parsed.value) else { throw Fail("BER parse") }
            try expect(parsed.tag == 0x7F49 && kids.count == 2 && kids[0].tag == 0x80 && kids[0].value == Data([1, 2, 3]), "BER round trip")
            let compact = TKCompactTLVRecord(tag: 0x4, value: Data([0xAB])), simple = TKSimpleTLVRecord(tag: 0x10, value: Data([9, 9]))
            try expect(compact.data == Data([0x41, 0xAB]) && simple.data == Data([0x10, 0x02, 9, 9]), "COMPACT \(compact.data as NSData) SIMPLE \(simple.data as NSData)")
            let base: [TKTLVRecord] = [inner, compact, simple]
            try expect(base.map(\.tag) == [0x80, 0x4, 0x10], "TLV tags")
            // a YubiKey's ATR: T=1, historical bytes "Yubikey4"
            let atrBytes = Data([0x3B, 0xF8, 0x13, 0x00, 0x00, 0x81, 0x31, 0xFE, 0x15, 0x59, 0x75, 0x62, 0x69, 0x6B, 0x65, 0x79, 0x34, 0xD4])
            guard let atr = TKSmartCardATR(bytes: atrBytes) else { throw Fail("ATR parse") }
            let g1: TKSmartCardATR.InterfaceGroup? = atr.interfaceGroup(at: 1)
            let hist = String(data: atr.historicalBytes, encoding: .ascii) ?? "?"
            try expect(hist == "Yubikey4" && atr.protocols.contains(NSNumber(value: TKSmartCardProtocol.t1.rawValue)) && g1?.ta == 0x13, "ATR: historical \(hist), protocols \(atr.protocols), group 1 TA \(String(describing: g1?.ta))")
            try expect(p27Is(atr, "TKSmartCardATR") && p27Is(g1 as Any, "TKSmartCardATRInterfaceGroup"), "ATR classes")
            // PIN format and auth operations
            let fmt = TKSmartCardPINFormat(); fmt.charset = .numeric; fmt.encoding = .bcd; fmt.minPINLength = 4; fmt.maxPINLength = 8; fmt.pinJustification = .left
            let pinOp = TKTokenSmartCardPINAuthOperation(); pinOp.pinFormat = fmt; pinOp.pin = "1234"; pinOp.apduTemplate = Data([0x00, 0x20, 0x00, 0x81])
            let pwOp = TKTokenPasswordAuthOperation(); pwOp.password = "pw"
            let ops: [TKTokenAuthOperation] = [pinOp, pwOp]
            try expect(ops.count == 2 && pinOp.pinFormat.maxPINLength == 8 && pwOp.password == "pw", "auth operations")
            try expect(p27Is(fmt, "TKSmartCardPINFormat") && p27Is(pinOp, "TKTokenSmartCardPINAuthOperation") && p27Is(pwOp, "TKTokenPasswordAuthOperation"), "PIN classes")
            // the app's token extension (P22): its driver configuration, a token configuration added and removed
            let drivers: [TKTokenDriver.ClassID: TKTokenDriver.Configuration] = TKTokenDriver.Configuration.driverConfigurations
            var cfgInfo = "\(drivers.count) driver configurations"
            if let drv = drivers.values.first {
                let tc: TKToken.Configuration = drv.addTokenConfiguration(for: "p27")
                tc.configurationData = Data([7])
                let has = drv.tokenConfigurations["p27"]?.configurationData == Data([7])
                drv.removeTokenConfiguration(for: "p27")
                cfgInfo += ", \(drv.classID): token configuration added \(has), removed \(drv.tokenConfigurations["p27"] == nil)"
                try expect(has && p27Is(drv, "TKTokenDriverConfiguration") && p27Is(tc, "TKTokenConfiguration"), cfgInfo)
            }
            let watcher = TKTokenWatcher()
            let infos = watcher.tokenIDs.compactMap { watcher.tokenInfo(forTokenID: $0) }
            let made: [(String, String)] = [("TKTokenWatcherTokenInfo", "NSObject"), ("TKSmartCard", "NSObject"), ("TKSmartCardSlot", "NSObject"), ("TKSmartCardUserInteraction", "NSObject"),
                ("TKSmartCardUserInteractionForPINOperation", "TKSmartCardUserInteraction"), ("TKSmartCardUserInteractionForSecurePINVerification", "TKSmartCardUserInteractionForPINOperation"),
                ("TKSmartCardUserInteractionForSecurePINChange", "TKSmartCardUserInteractionForPINOperation"), ("TKSmartCardToken", "TKToken"), ("TKSmartCardTokenDriver", "TKTokenDriver"),
                ("TKSmartCardTokenSession", "TKTokenSession"), ("TKTokenKeychainItem", "NSObject"), ("TKTokenKeyExchangeParameters", "NSObject")]
            let wrong = p27Hierarchy(made)
            try expect(wrong.isEmpty, "classes \(wrong)")
            #if os(iOS)
            let reg = TKSmartCardTokenRegistrationManager.default.registeredSmartCardTokens
            let nfc: AnyClass? = NSClassFromString("TKSmartCardSlotNFCSession")
            try expect(nfc != nil, "TKSmartCardSlotNFCSession missing")
            cfgInfo += "; registered smart card tokens \(reg.count)"
            #endif
            return "BER/COMPACT/SIMPLE TLV, ATR T=1 \"\(hist)\", PIN ops; \(cfgInfo); \(infos.count) watched tokens"
        })
        #endif
        // MARK: SwiftData: history of insert / update / delete through the typed change protocols (DefaultHistoryInsert /
        // Update / Delete, the tombstone of a preserved attribute, tokens), batched fetches (FetchResultsCollection), the
        // schema's property protocol, the default store's snapshot / batching protocols, the serial executor, errors
        #if canImport(SwiftData)
        c.append(check("SwiftData", "p27-history-batches-protocols", timeout: 40) {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("p27-sd-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: dir) }
            let mc = try ModelContainer(for: P27Doc.self, configurations: ModelConfiguration(url: dir.appendingPathComponent("p27.store"), cloudKitDatabase: .none))
            let ctx = ModelContext(mc)
            for i in 0..<5 { ctx.insert(P27Doc(title: "d\(i)", n: i)) }
            try ctx.save()
            let all = try ctx.fetch(FetchDescriptor<P27Doc>(sortBy: [SortDescriptor(\.n)]))
            all[1].n = 10; try ctx.save()
            ctx.delete(all[2]); try ctx.save()
            // batched fetch
            var bd = FetchDescriptor<P27Doc>(sortBy: [SortDescriptor(\.n)]); bd.includePendingChanges = false
            let batched: FetchResultsCollection<P27Doc> = try ctx.fetch(bd, batchSize: 2)
            try expect(batched.count == 4 && batched.map(\.n) == [0, 3, 4, 10], "batched \(batched.map(\.n))")
            // history: 3 transactions; the changes through the protocols
            let tx = try ctx.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
            func kinds<T: HistoryTransaction>(_ ts: [T]) -> Int { ts.count }
            var ins = 0, upd = 0, del = 0, tomb: [String] = [], updKeys: [String] = []
            for t in tx {
                for ch in t.changes {
                    switch ch {
                    case .insert(let i as DefaultHistoryInsert<P27Doc>): func f<I: HistoryInsert>(_ x: I) -> Bool { x.changedPersistentIdentifier.entityName == "P27Doc" }; if f(i) { ins += 1 }
                    case .update(let u as DefaultHistoryUpdate<P27Doc>): func f<U: HistoryUpdate>(_ x: U) -> Int { x.updatedAttributes.count }; upd += 1; updKeys.append("\(f(u))")
                    case .delete(let d as DefaultHistoryDelete<P27Doc>):
                        func f<D: HistoryDelete>(_ x: D) -> D.Model.Type { D.Model.self }
                        del += 1
                        let ts: HistoryTombstone<P27Doc> = d.tombstone
                        if let t = ts[\.title] as? String { tomb.append(t) }
                        _ = f(d)
                    default: break
                    }
                }
            }
            let tokens: [DefaultHistoryToken] = tx.map(\.token)
            func tokOK<T: HistoryToken>(_ t: [T]) -> Bool { t == t.sorted() }
            let changeKinds: [HistoryChange] = tx.flatMap(\.changes)
            try expect(kinds(tx) == 3 && ins == 5 && upd == 1 && del == 1 && tomb == ["d2"] && tokOK(tokens) && changeKinds.count == 7, "history: \(tx.count) tx, inserts \(ins), updates \(upd) \(updKeys), deletes \(del), tombstone \(tomb)")
            let tokJSON = try JSONDecoder().decode(DefaultHistoryToken.self, from: JSONEncoder().encode(tokens[0]))
            try expect(tokJSON == tokens[0], "token Codable")
            // schema properties
            let schema = Schema([P27Doc.self])
            let props: [any SchemaProperty] = schema.entities.first?.properties ?? []
            let preserved = (schema.entities.first?.attributes.first { $0.name == "title" })?.options.contains(.preserveValueOnDeletion) ?? false
            try expect(props.count == 2 && preserved, "schema properties \(props.map(\.name)), preserved \(preserved)")
            // protocols of the default store and executor
            let types: [Any.Type] = [(any DataStoreBatching).self, (any DataStoreSnapshot).self, DataStoreSnapshotCodingKey.self, DataStoreBatchDeleteRequest<P27Doc>.self,
                                     (any HistoryProviding).self, (any RelationshipCollection).self, (any SerialModelExecutor).self, ResultsSection<P27Doc, Int>.self,
                                     SectionedResults<P27Doc, Int>.self, EditingState.self]
            func batching<S: DataStoreBatching>(_: S.Type) -> Bool { true }
            func snapshot<S: DataStoreSnapshot>(_: S.Type) -> Bool { true }
            func serial<E: SerialModelExecutor>(_: E.Type) -> Bool { true }
            try expect(batching(DefaultStore.self) && snapshot(DefaultSnapshot.self) && serial(DefaultSerialModelExecutor.self) && types.count == 10, "conformances")
            let es: EditingState = ctx.editingState
            try expect(es.id == ctx.editingState.id, "editing state")
            // errors
            let errs: [SwiftDataError] = [.loadIssueModelContainer, .unsupportedPredicate, .includePendingChangesWithBatchSize]
            try expect(Set(errs).count == 3, "errors")
            var thrown = "none"
            do { _ = try ctx.fetch(FetchDescriptor<P27Doc>(), batchSize: 2) } catch let e as SwiftDataError { thrown = "\(e)" } catch { thrown = "\(type(of: error))" }
            return "batched 4; history 3 tx (5 ins, 1 upd, 1 del, tombstone d2); schema \(props.count) properties; batched with pending changes included: \(thrown)"
        })
        #endif
        // MARK: StoreKit: the original API's payments (mutable payment with a discount), receipt refresh request, overlay
        // configurations, cloud service authorization, the promotion controller; the StoreKit 2 values (merchandising kind,
        // external purchase custom link eligibility, advanced commerce product / payment method binding answers without
        // App Store products), and the classes the store hands out (present with their superclass)
        #if canImport(StoreKit)
        c.append(check("StoreKit", "p27-payments-overlay-answers", timeout: 40) {
            var n = 0
            func objc(_ o: AnyObject, _ cls: String) throws { n += 1; try expect(p27Is(o, cls), "\(type(of: o)) is not \(cls)") }
            let disc = SKPaymentDiscount(identifier: "promo", keyIdentifier: "key", nonce: UUID(), signature: "sig", timestamp: 1_700_000_000_000)
            let pay = SKMutablePayment(); pay.productIdentifier = "com.x86sim.p27"; pay.quantity = 2; pay.applicationUsername = "u"; pay.paymentDiscount = disc; pay.simulatesAskToBuyInSandbox = true
            let frozen = pay.copy() as! SKPayment
            try objc(pay, "SKMutablePayment"); try objc(frozen, "SKPayment"); try objc(disc, "SKPaymentDiscount")
            try expect(frozen.productIdentifier == "com.x86sim.p27" && frozen.quantity == 2 && frozen.paymentDiscount?.identifier == "promo" && !(frozen is SKMutablePayment), "payment copy")
            let refresh = SKReceiptRefreshRequest(receiptProperties: [SKReceiptPropertyIsExpired: 0])
            try objc(refresh, "SKReceiptRefreshRequest"); try expect((refresh.receiptProperties?[SKReceiptPropertyIsExpired] as? Int) == 0, "receipt properties")
            let product = SKProduct()
            try objc(product, "SKProduct")
            let allMade: [(String, String)] = [("SKPaymentTransaction", "NSObject"), ("SKProductDiscount", "NSObject"), ("SKProductSubscriptionPeriod", "NSObject"), ("SKStorefront", "NSObject"),
                                            ("SKStoreReviewController", "NSObject"), ("SKOverlayTransitionContext", "NSObject"), ("SKCloudServiceSetupViewController", "UIViewController"),
                                            ("SKOverlayConfiguration", "NSObject")]
            #if os(watchOS)
            // watchOS's StoreKit has no review controller, overlays or cloud service setup view controller
            let notOnWatch: Set<String> = ["SKStoreReviewController", "SKOverlayTransitionContext", "SKCloudServiceSetupViewController", "SKOverlayConfiguration"]
            let made = allMade.filter { !notOnWatch.contains($0.0) }
            try expect(notOnWatch.allSatisfy { NSClassFromString($0) == nil }, "watchOS StoreKit classes")
            #else
            let made = allMade
            #endif
            #if os(iOS)
            let ov = SKOverlay.AppConfiguration(appIdentifier: "1234567890", position: .bottomRaised); ov.userDismissible = false; ov.campaignToken = "c"
            let clip = SKOverlay.AppClipConfiguration(position: .bottom)
            try objc(ov, "SKOverlayAppConfiguration"); try objc(clip, "SKOverlayAppClipConfiguration"); try objc(ov, "SKOverlayConfiguration")
            try expect(ov.appIdentifier == "1234567890" && !ov.userDismissible && clip.position == .bottom, "overlay configurations")
            let cloud = SKCloudServiceController(); try objc(cloud, "SKCloudServiceController")
            let promo = SKProductStorePromotionController.default(); try objc(promo, "SKProductStorePromotionController")
            let promoOrder = await p5Within(15) { () async throws -> String in
                do { return "order \(try await promo.promotionOrder().count)" } catch { return "threw \(p3Err(error))" }
            } ?? "no answer in 15 s"
            #else
            let promoOrder = "n/a"
            #endif
            let cloudStatus = SKCloudServiceController.authorizationStatus()
            let wrong = p27Hierarchy(made)
            try expect(wrong.isEmpty, "classes \(wrong)")
            // StoreKit 2 values and the simulator's answers without App Store products
            #if !os(watchOS)
            let kind = AppStoreMerchandisingKind.subscriptionBundle("group.p27")
            let types: [Any.Type] = [type(of: kind), RedeemOption.self, PurchaseIntent.self, InvalidRequestError.self, VerificationResult<StoreKit.Transaction>.self, ExternalPurchaseCustomLink.NoticeType.self,
                                     PaymentMethodBinding.self, AdvancedCommerceProduct.self]
            let dl: [Any.Type] = [(any StoreDownloaderExtension).self]
            try expect(dl.count == 1, "downloader protocol")
            let eligible = await ExternalPurchaseCustomLink.isEligible
            let acp = await p5Within(20) { () async throws -> String in
                do { let p = try await AdvancedCommerceProduct(id: "com.x86sim.p27.acp"); return "product \(p.id)" } catch { return "threw \(type(of: error)) \(p3Err(error))" }
            } ?? "no answer in 20 s"
            let pmb = await p5Within(20) { () async throws -> String in
                do { let b = try await PaymentMethodBinding(id: "p27"); return "binding \(b.id)" } catch { return "threw \(type(of: error))" }
            } ?? "no answer in 20 s"
            #else
            let types: [Any.Type] = [InvalidRequestError.self, VerificationResult<StoreKit.Transaction>.self]
            let eligible = false, acp = "n/a", pmb = "n/a"
            #endif
            let d = "\(n) SK1 objects; cloud authorization \(cloudStatus.rawValue); promotion \(promoOrder); custom link eligible \(eligible); advanced commerce: \(acp); payment method binding: \(pmb); \(types.count) types"
            try expect(!eligible && !acp.contains("ok: product") && !pmb.contains("ok: binding"), d)
            return d
        })
        #endif
        // MARK: LocalAuthentication: the environment's state and mechanisms (biometry, user password, companions), a
        // context's domain state, authentication requirements, and a persisted right with its key pair and secret
        // (LARightStore): the key signs and the public key verifies; the right removed again
        #if canImport(LocalAuthentication) && (os(iOS) || os(visionOS))
        c.append(check("LocalAuthentication", "p27-environment-domain-right", timeout: 40) {
            let env = LAEnvironment.currentUser
            let st: LAEnvironment.State = env.state
            let mechs: [LAEnvironment.Mechanism] = st.allMechanisms
            let bio: LAEnvironment.MechanismBiometry? = st.biometry, pw: LAEnvironment.MechanismUserPassword? = st.userPassword
            try expect(p27Is(st, "LAEnvironmentState") && mechs.allSatisfy { p27Is($0, "LAEnvironmentMechanism") && !$0.localizedName.isEmpty }, "environment \(mechs.map(\.localizedName))")
            var envInfo = "mechanisms \(mechs.map { "\(type(of: $0)) usable \($0.isUsable)" }), biometry \(bio.map { "\($0.biometryType.rawValue) enrolled \($0.isEnrolled)" } ?? "none"), password set \(pw?.isSet ?? false)"
            if let bio { try expect(p27Is(bio, "LAEnvironmentMechanismBiometry"), "biometry class") }
            if let pw { try expect(p27Is(pw, "LAEnvironmentMechanismUserPassword"), "password class") }
            #if os(iOS)
            let comps: [LAEnvironment.MechanismCompanion] = st.companions
            envInfo += ", companions \(comps.count)"
            try expect(NSClassFromString("LAEnvironmentMechanismCompanion") != nil && NSClassFromString("LADomainStateCompanion") != nil, "companion classes")
            #endif
            let ctx = LAContext()
            let ds: LADomainState = ctx.domainState
            let dsb: LADomainStateBiometry = ds.biometry
            try expect(p27Is(ds, "LADomainState") && p27Is(dsb, "LADomainStateBiometry"), "domain state classes")
            // requirements
            let reqs: [LAAuthenticationRequirement] = [.default, .biometry, .biometryCurrentSet, .biometry(fallback: LABiometryFallbackRequirement.devicePasscode)]
            try expect(reqs.allSatisfy { p27Is($0, "LAAuthenticationRequirement") } && p27Is(LABiometryFallbackRequirement.default, "LABiometryFallbackRequirement"), "requirements")
            // a persisted right: key pair + secret
            let id = "com.x86sim.p27.right"
            try? await LARightStore.shared.removeRight(forIdentifier: id)
            var rightInfo = ""
            do {
                let right: LAPersistedRight = try await LARightStore.shared.saveRight(LARight(), identifier: id, secret: Data("p27-secret".utf8))
                let priv: LAPrivateKey = right.key, pub: LAPublicKey = priv.publicKey
                let secret: LASecret = right.secret
                let alg = SecKeyAlgorithm.ecdsaSignatureMessageX962SHA256
                let canSign = priv.canSign(using: alg), canVerify = pub.canVerify(using: alg)
                let pubBytes = try await pub.bytes
                rightInfo = "right saved; can sign \(canSign), verify \(canVerify), public key \(pubBytes.count) B"
                // signing / reading the secret need the right authorized (a biometry / passcode prompt): its answer
                let sig = await p5Within(10) { () async throws -> String in
                    do { let s = try await priv.sign(Data("m".utf8), algorithm: alg); return "signed \(s.count) B" } catch { return "sign threw \(p3Err(error))" }
                } ?? "sign: no answer in 10 s"
                let sec = await p5Within(10) { () async throws -> String in
                    do { let d = try await secret.rawData; return "secret \(d.count) B" } catch { return "secret threw \(p3Err(error))" }
                } ?? "secret: no answer in 10 s"
                rightInfo += "; \(sig); \(sec)"
                try expect(p27Is(right, "LAPersistedRight") && p27Is(priv, "LAPrivateKey") && p27Is(pub, "LAPublicKey") && p27Is(secret, "LASecret") && canSign && canVerify && pubBytes.count == 65, rightInfo)
                try await LARightStore.shared.removeRight(right)
            } catch let f as Fail { throw f } catch { rightInfo = "saveRight threw \(p3Err(error))" }
            return "\(envInfo); domain biometry \(dsb.biometryType.rawValue); \(rightInfo)"
        })
        #endif
        // MARK: CoreSpotlight: custom attribute keys, localized strings and people on an attribute set (read back), the
        // Swift attribute names, the extension / suggestion classes
        #if canImport(CoreSpotlight) && (os(iOS) || os(visionOS))
        c.append(check("CoreSpotlight", "p27-custom-keys-people", timeout: 20) {
            guard let key = CSCustomAttributeKey(keyName: "p27Rating", searchable: true, searchableByDefault: false, unique: false, multiValued: false) else { throw Fail("custom key nil") }
            let set = CSSearchableItemAttributeSet(contentType: .text)
            set.setValue(NSNumber(value: 5), forCustomKey: key)
            let loc = CSLocalizedString(localizedStrings: ["en": "Hello", "fr": "Bonjour"])
            set.title = loc as String
            let who = CSPerson(displayName: "P 27", handles: ["p27@example.com"], handleIdentifier: "emailAddresses")
            set.authors = [who]
            try expect((set.value(forCustomKey: key) as? NSNumber) == 5 && key.isSearchable && !key.isSearchableByDefault && key.keyName == "p27Rating", "custom key")
            try expect(!loc.localizedString().isEmpty && set.authors?.first?.handles == ["p27@example.com"] && who.displayName == "P 27", "people / localized string \(loc.localizedString())")
            let names: [SearchableItemAttribute] = [.displayName, .alternateNames, .path, .contentURL, .thumbnailURL]
            try expect(Set(names.map(\.rawValue)).count == 5, "attribute names \(names.map(\.rawValue))")
            let types: [Any.Type] = [SearchableItem.self]
            let wrong = p27Hierarchy([("CSImportExtension", "NSObject"), ("CSIndexExtensionRequestHandler", "NSObject"), ("CSSuggestion", "NSObject"), ("CSSearchableIndexDescription", "NSObject")])
            try expect(wrong.isEmpty && types.count == 1, "classes \(wrong)")
            return "custom key, localized string \"\(loc.localizedString())\", person; \(names.count) Swift attribute names"
        })
        #endif
        // MARK: BackgroundTasks: request kinds configured, submitting identifiers the app's Info.plist does not permit
        // (BGTaskScheduler's error), and the task classes the scheduler hands to a launch handler
        #if canImport(BackgroundTasks) && !os(watchOS)
        c.append(check("BackgroundTasks", "p27-requests-submit-classes", timeout: 20) {
            let proc = BGProcessingTaskRequest(identifier: "com.x86sim.p27.proc"); proc.requiresNetworkConnectivity = true; proc.requiresExternalPower = true
            proc.earliestBeginDate = Date(timeIntervalSinceNow: 3600)
            let base: BGTaskRequest = proc
            try expect(base.identifier == "com.x86sim.p27.proc" && proc.requiresExternalPower && base.earliestBeginDate != nil, "processing request")
            var made: [(String, String)] = [("BGTask", "NSObject"), ("BGAppRefreshTask", "BGTask"), ("BGProcessingTask", "BGTask")]
            var submitted: [String] = []
            func submit(_ r: BGTaskRequest) -> String {
                do { try BGTaskScheduler.shared.submit(r); return "accepted" } catch { return "\((error as NSError).domain) \((error as NSError).code)" }
            }
            submitted.append(submit(proc))
            #if os(iOS)
            let health = BGHealthResearchTaskRequest(identifier: "com.x86sim.p27.health"); health.protectionTypeOfRequiredData = FileProtectionType.complete.rawValue as NSString
            try expect(health.protectionTypeOfRequiredData as String == FileProtectionType.complete.rawValue, "health research request")
            submitted.append(submit(health))
            made += [("BGHealthResearchTask", "BGProcessingTask"), ("BGContinuedProcessingTask", "BGTask")]
            #endif
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "com.x86sim.p27.proc")
            let wrong = p27Hierarchy(made)
            try expect(wrong.isEmpty && submitted.allSatisfy { $0 == "BGTaskSchedulerErrorDomain 3" }, "submits \(submitted); classes \(wrong)")
            return "submits \(submitted) (not permitted); \(made.count) task classes"
        })
        #endif
        // MARK: BackgroundAssets: the asset pack manager's manifest answer, manifest parsing of a file that is not one,
        // the managed errors, the extension protocols and the asset pack classes
        #if canImport(BackgroundAssets) && os(iOS)
        c.append(check("BackgroundAssets", "p27-asset-packs-errors", timeout: 30) {
            let bad = FileManager.default.temporaryDirectory.appendingPathComponent("p27-manifest.json")
            try Data("{\"not\":\"a manifest\"}".utf8).write(to: bad)
            var swiftManifest = ""
            do { let m = try AssetPackManifest(contentsOf: bad, appGroupID: "group.com.x86sim.test.sdkcov"); swiftManifest = "parsed \(m.localizedAssetPacks.count)" } catch { swiftManifest = "threw \(type(of: error))" }
            let errs: [ManagedBackgroundAssetsError] = [.assetPackNotFound(withID: "p27"), .fileNotFound(at: "/x")]
            try expect(errs.allSatisfy { !$0.description.isEmpty && $0.errorDescription != nil } && errs[0].description.contains("p27"), "errors \(errs.map(\.description))")
            let types: [Any.Type] = [(any BADownloaderExtension).self, (any BADownloaderExtensionConfiguration).self]
            let wrong = p27Hierarchy([("BAAppExtensionInfo", "NSObject"), ("BAAssetPack", "NSObject"), ("BAAssetPackManifest", "NSObject"), ("BAAssetPackManager", "NSObject")])
            let d = "AssetPackManifest of junk \(swiftManifest); \(types.count) protocols; BA classes present"
            try expect(wrong.isEmpty && swiftManifest.hasPrefix("threw"), "\(d); classes \(wrong)")
            return d
        })
        #endif
        // MARK: FileProvider: domain versions ordered, known folder locations, the string search request and extension
        // classes
        #if canImport(FileProvider) && (os(iOS) || os(visionOS))
        c.append(check("FileProvider", "p27-versions-known-folders", timeout: 20) {
            let v1 = NSFileProviderDomainVersion(), v2 = v1.next(), v3 = v2.next()
            try expect(v1 < v2 && v2 < v3 && !(v3 < v1) && p27Is(v1, "NSFileProviderDomainVersion"), "domain versions")
            // NSFileProviderKnownFolderLocation(s) are macOS-only API: the classes exist in iOS's FileProvider too
            let wrong = p27Hierarchy([("NSFileProviderStringSearchRequest", "NSObject"), ("NSFileProviderExtension", "NSObject"), ("NSFileProviderKnownFolderLocation", "NSObject"),
                                      ("NSFileProviderKnownFolderLocations", "NSObject")])
            try expect(wrong.isEmpty, "classes \(wrong)")
            return "3 ordered domain versions, 4 classes"
        })
        #endif
        return c
    }
}

#if canImport(Matter)
// the Matter value classes (MTRStructsObjc.h, MTRCommandPayloadsObjc.h, MTRBackwardsCompatShims.h) and cluster classes
// (MTRBaseClusters.h, MTRClusters.h and the shims), from the 27.2 SDK headers; provisional ones are unavailable to Swift
private let p27MatterValueClasses = """
MTRAVAnalysisClusterActivateAnalysisStreamParams MTRAVAnalysisClusterAnalysisSessionEndEvent
MTRAVAnalysisClusterAnalysisSessionStartEvent MTRAVAnalysisClusterAnalysisStreamStruct
MTRAVAnalysisClusterContextTriggerStruct MTRAVAnalysisClusterDeactivateAnalysisStreamParams
MTRAVAnalysisClusterDisableContextTriggersParams MTRAVAnalysisClusterEnableContextTriggersParams
MTRAVAnalysisClusterEstablishAnalysisStreamParams MTRAVAnalysisClusterEstablishAnalysisStreamResponseParams
MTRAVAnalysisClusterPerceivedContextEvent MTRAVAnalysisClusterRemoveAnalysisStreamParams
MTRAVAnalysisClusterTrackedContext MTRAccessControlClusterAccessControlEntry
MTRAccessControlClusterAccessControlEntryChangedEvent MTRAccessControlClusterAccessControlEntryStruct
MTRAccessControlClusterAccessControlExtensionChangedEvent MTRAccessControlClusterAccessControlExtensionStruct
MTRAccessControlClusterAccessControlTargetStruct MTRAccessControlClusterAccessRestrictionEntryStruct
MTRAccessControlClusterAccessRestrictionStruct MTRAccessControlClusterAuxiliaryAccessUpdatedEvent
MTRAccessControlClusterCommissioningAccessRestrictionEntryStruct MTRAccessControlClusterExtensionEntry
MTRAccessControlClusterFabricRestrictionReviewUpdateEvent MTRAccessControlClusterReviewFabricRestrictionsParams
MTRAccessControlClusterReviewFabricRestrictionsResponseParams MTRAccessControlClusterTarget
MTRAccountLoginClusterGetDeviceAuthURIParams MTRAccountLoginClusterGetDeviceAuthURIResponseParams
MTRAccountLoginClusterGetSetupPINParams MTRAccountLoginClusterGetSetupPINResponseParams
MTRAccountLoginClusterLoggedOutEvent MTRAccountLoginClusterLoginParams MTRAccountLoginClusterLogoutParams
MTRActionsClusterActionFailedEvent MTRActionsClusterActionStruct MTRActionsClusterDisableActionParams
MTRActionsClusterDisableActionWithDurationParams MTRActionsClusterEnableActionParams
MTRActionsClusterEnableActionWithDurationParams MTRActionsClusterEndpointListStruct
MTRActionsClusterInstantActionParams MTRActionsClusterInstantActionWithTransitionParams
MTRActionsClusterPauseActionParams MTRActionsClusterPauseActionWithDurationParams MTRActionsClusterResumeActionParams
MTRActionsClusterStartActionParams MTRActionsClusterStartActionWithDurationParams MTRActionsClusterStateChangedEvent
MTRActionsClusterStopActionParams MTRActivatedCarbonFilterMonitoringClusterReplacementProductStruct
MTRActivatedCarbonFilterMonitoringClusterResetConditionParams
MTRAdministratorCommissioningClusterOpenBasicCommissioningWindowParams
MTRAdministratorCommissioningClusterOpenCommissioningWindowParams
MTRAdministratorCommissioningClusterRevokeCommissioningParams
MTRAmbientContextSensingClusterAmbientContextDetectEndedEvent
MTRAmbientContextSensingClusterAmbientContextDetectStartedEvent
MTRAmbientContextSensingClusterAmbientContextTypeStruct MTRAmbientContextSensingClusterHoldTimeLimitsStruct
MTRAmbientContextSensingClusterObjectCountConfigStruct MTRAmbientContextSensingClusterPredictedActivityStruct
MTRAmbientSensingUnionClusterContributorStatusChangeStruct MTRAmbientSensingUnionClusterUnionContributorAddedEvent
MTRAmbientSensingUnionClusterUnionContributorRemovedEvent
MTRAmbientSensingUnionClusterUnionContributorStatusChangedEvent MTRAmbientSensingUnionClusterUnionContributorStruct
MTRApplicationBasicClusterApplicationBasicApplication MTRApplicationBasicClusterApplicationStruct
MTRApplicationLauncherClusterApplication MTRApplicationLauncherClusterApplicationEP
MTRApplicationLauncherClusterApplicationEPStruct MTRApplicationLauncherClusterApplicationStruct
MTRApplicationLauncherClusterHideAppParams MTRApplicationLauncherClusterLaunchAppParams
MTRApplicationLauncherClusterLauncherResponseParams MTRApplicationLauncherClusterStopAppParams
MTRAudioControlClusterDecreaseVolumeParams MTRAudioControlClusterIncreaseVolumeParams MTRAudioControlClusterMuteParams
MTRAudioControlClusterSetVolumeParams MTRAudioControlClusterToggleMutedParams MTRAudioControlClusterUnmuteParams
MTRAudioOutputClusterOutputInfo MTRAudioOutputClusterOutputInfoStruct MTRAudioOutputClusterRenameOutputParams
MTRAudioOutputClusterSelectOutputParams MTRBarrierControlClusterBarrierControlGoToPercentParams
MTRBarrierControlClusterBarrierControlStopParams MTRBasicClusterCapabilityMinimaStruct MTRBasicClusterLeaveEvent
MTRBasicClusterMfgSpecificPingParams MTRBasicClusterReachableChangedEvent MTRBasicClusterShutDownEvent
MTRBasicClusterStartUpEvent MTRBasicInformationClusterCapabilityMinimaStruct MTRBasicInformationClusterLeaveEvent
MTRBasicInformationClusterProductAppearanceStruct MTRBasicInformationClusterReachableChangedEvent
MTRBasicInformationClusterShutDownEvent MTRBasicInformationClusterStartUpEvent MTRBindingClusterTargetStruct
MTRBooleanStateClusterStateChangeEvent MTRBooleanStateConfigurationClusterAlarmsStateChangedEvent
MTRBooleanStateConfigurationClusterEnableDisableAlarmParams MTRBooleanStateConfigurationClusterSensorFaultEvent
MTRBooleanStateConfigurationClusterSuppressAlarmParams MTRBridgedDeviceBasicClusterLeaveEvent
MTRBridgedDeviceBasicClusterReachableChangedEvent MTRBridgedDeviceBasicClusterShutDownEvent
MTRBridgedDeviceBasicClusterStartUpEvent MTRBridgedDeviceBasicInformationClusterActiveChangedEvent
MTRBridgedDeviceBasicInformationClusterKeepActiveParams MTRBridgedDeviceBasicInformationClusterLeaveEvent
MTRBridgedDeviceBasicInformationClusterProductAppearanceStruct
MTRBridgedDeviceBasicInformationClusterReachableChangedEvent MTRBridgedDeviceBasicInformationClusterShutDownEvent
MTRBridgedDeviceBasicInformationClusterStartUpEvent
MTRCameraAVSettingsUserLevelManagementClusterDPTZRelativeMoveParams
MTRCameraAVSettingsUserLevelManagementClusterDPTZSetViewportParams
MTRCameraAVSettingsUserLevelManagementClusterDPTZStruct
MTRCameraAVSettingsUserLevelManagementClusterMPTZMoveToPresetParams
MTRCameraAVSettingsUserLevelManagementClusterMPTZPresetStruct
MTRCameraAVSettingsUserLevelManagementClusterMPTZRelativeMoveParams
MTRCameraAVSettingsUserLevelManagementClusterMPTZRemovePresetParams
MTRCameraAVSettingsUserLevelManagementClusterMPTZSavePresetParams
MTRCameraAVSettingsUserLevelManagementClusterMPTZSetPositionParams
MTRCameraAVSettingsUserLevelManagementClusterMPTZStruct MTRCameraAVStreamManagementClusterAudioCapabilitiesStruct
MTRCameraAVStreamManagementClusterAudioStreamAllocateParams
MTRCameraAVStreamManagementClusterAudioStreamAllocateResponseParams
MTRCameraAVStreamManagementClusterAudioStreamDeallocateParams MTRCameraAVStreamManagementClusterAudioStreamStruct
MTRCameraAVStreamManagementClusterCaptureSnapshotParams
MTRCameraAVStreamManagementClusterCaptureSnapshotResponseParams
MTRCameraAVStreamManagementClusterRateDistortionTradeOffPointsStruct
MTRCameraAVStreamManagementClusterSetStreamPrioritiesParams
MTRCameraAVStreamManagementClusterSnapshotCapabilitiesStruct
MTRCameraAVStreamManagementClusterSnapshotStreamAllocateParams
MTRCameraAVStreamManagementClusterSnapshotStreamAllocateResponseParams
MTRCameraAVStreamManagementClusterSnapshotStreamDeallocateParams
MTRCameraAVStreamManagementClusterSnapshotStreamModifyParams MTRCameraAVStreamManagementClusterSnapshotStreamStruct
MTRCameraAVStreamManagementClusterVideoResolutionStruct MTRCameraAVStreamManagementClusterVideoSensorParamsStruct
MTRCameraAVStreamManagementClusterVideoStreamAllocateParams
MTRCameraAVStreamManagementClusterVideoStreamAllocateResponseParams
MTRCameraAVStreamManagementClusterVideoStreamDeallocateParams
MTRCameraAVStreamManagementClusterVideoStreamModifyParams MTRCameraAVStreamManagementClusterVideoStreamStruct
MTRChannelClusterAdditionalInfoStruct MTRChannelClusterCancelRecordProgramParams
MTRChannelClusterChangeChannelByNumberParams MTRChannelClusterChangeChannelParams
MTRChannelClusterChangeChannelResponseParams MTRChannelClusterChannelInfo MTRChannelClusterChannelInfoStruct
MTRChannelClusterChannelPagingStruct MTRChannelClusterGetProgramGuideParams MTRChannelClusterLineupInfo
MTRChannelClusterLineupInfoStruct MTRChannelClusterPageTokenStruct MTRChannelClusterProgramCastStruct
MTRChannelClusterProgramCategoryStruct MTRChannelClusterProgramGuideResponseParams MTRChannelClusterProgramStruct
MTRChannelClusterRecordProgramParams MTRChannelClusterSeriesInfoStruct MTRChannelClusterSkipChannelParams
MTRChimeClusterChimeSoundStruct MTRChimeClusterChimeStartedPlayingEvent MTRChimeClusterPlayChimeSoundParams
MTRClosureControlClusterCalibrateParams MTRClosureControlClusterEngageStateChangedEvent
MTRClosureControlClusterGroupedMoveToParams MTRClosureControlClusterMoveToParams
MTRClosureControlClusterMovementCompletedEvent MTRClosureControlClusterOperationalErrorEvent
MTRClosureControlClusterOverallCurrentStateStruct MTRClosureControlClusterOverallTargetStateStruct
MTRClosureControlClusterSecureStateChangedEvent MTRClosureControlClusterStopParams
MTRClosureDimensionClusterDimensionStateStruct MTRClosureDimensionClusterGroupedSetTargetParams
MTRClosureDimensionClusterGroupedStepParams MTRClosureDimensionClusterRangePercent100thsStruct
MTRClosureDimensionClusterSetTargetParams MTRClosureDimensionClusterStepParams
MTRClosureDimensionClusterUnitRangeStruct MTRColorControlClusterColorLoopSetParams
MTRColorControlClusterEnhancedMoveHueParams MTRColorControlClusterEnhancedMoveToHueAndSaturationParams
MTRColorControlClusterEnhancedMoveToHueParams MTRColorControlClusterEnhancedStepHueParams
MTRColorControlClusterMoveColorParams MTRColorControlClusterMoveColorTemperatureParams
MTRColorControlClusterMoveHueParams MTRColorControlClusterMoveSaturationParams MTRColorControlClusterMoveToColorParams
MTRColorControlClusterMoveToColorTemperatureParams MTRColorControlClusterMoveToHueAndSaturationParams
MTRColorControlClusterMoveToHueParams MTRColorControlClusterMoveToSaturationParams
MTRColorControlClusterStepColorParams MTRColorControlClusterStepColorTemperatureParams
MTRColorControlClusterStepHueParams MTRColorControlClusterStepSaturationParams
MTRColorControlClusterStopMoveStepParams MTRCommissionerControlClusterCommissionNodeParams
MTRCommissionerControlClusterCommissioningRequestResultEvent
MTRCommissionerControlClusterRequestCommissioningApprovalParams
MTRCommissionerControlClusterReverseOpenCommissioningWindowParams
MTRCommissioningProxyClusterProxyBackGroundScanStartRequestParams
MTRCommissioningProxyClusterProxyBackGroundScanStopRequestParams MTRCommissioningProxyClusterProxyConnectRequestParams
MTRCommissioningProxyClusterProxyConnectResponseParams MTRCommissioningProxyClusterProxyDisconnectRequestParams
MTRCommissioningProxyClusterProxyMessageRequestParams MTRCommissioningProxyClusterProxyMessageResponseParams
MTRCommissioningProxyClusterProxyScanRequestParams MTRCommissioningProxyClusterProxyScanResponseParams
MTRCommissioningProxyClusterScanResultStruct MTRCommodityMeteringClusterMeteredQuantityStruct
MTRCommodityPriceClusterCommodityPriceComponentStruct MTRCommodityPriceClusterCommodityPriceStruct
MTRCommodityPriceClusterGetDetailedForecastRequestParams MTRCommodityPriceClusterGetDetailedForecastResponseParams
MTRCommodityPriceClusterGetDetailedPriceRequestParams MTRCommodityPriceClusterGetDetailedPriceResponseParams
MTRCommodityPriceClusterPriceChangeEvent MTRCommodityTariffClusterAuxiliaryLoadSwitchSettingsStruct
MTRCommodityTariffClusterCalendarPeriodStruct MTRCommodityTariffClusterDayEntryStruct
MTRCommodityTariffClusterDayPatternStruct MTRCommodityTariffClusterDayStruct
MTRCommodityTariffClusterGetDayEntryParams MTRCommodityTariffClusterGetDayEntryResponseParams
MTRCommodityTariffClusterGetTariffComponentParams MTRCommodityTariffClusterGetTariffComponentResponseParams
MTRCommodityTariffClusterPeakPeriodStruct MTRCommodityTariffClusterTariffComponentStruct
MTRCommodityTariffClusterTariffInformationStruct MTRCommodityTariffClusterTariffPeriodStruct
MTRCommodityTariffClusterTariffPriceStruct MTRContentAppObserverClusterContentAppMessageParams
MTRContentAppObserverClusterContentAppMessageResponseParams MTRContentControlClusterAddBlockApplicationsParams
MTRContentControlClusterAddBlockChannelsParams MTRContentControlClusterAddBonusTimeParams
MTRContentControlClusterAppInfoStruct MTRContentControlClusterBlockChannelStruct
MTRContentControlClusterBlockUnratedContentParams MTRContentControlClusterDisableParams
MTRContentControlClusterEnableParams MTRContentControlClusterEnteringBlockContentTimeWindowEvent
MTRContentControlClusterRatingNameStruct MTRContentControlClusterRemainingScreenTimeExpiredEvent
MTRContentControlClusterRemoveBlockApplicationsParams MTRContentControlClusterRemoveBlockChannelsParams
MTRContentControlClusterRemoveBlockContentTimeWindowParams MTRContentControlClusterResetPINParams
MTRContentControlClusterResetPINResponseParams MTRContentControlClusterSetBlockContentTimeWindowParams
MTRContentControlClusterSetOnDemandRatingThresholdParams
MTRContentControlClusterSetScheduledContentRatingThresholdParams MTRContentControlClusterSetScreenDailyTimeParams
MTRContentControlClusterTimePeriodStruct MTRContentControlClusterTimeWindowStruct
MTRContentControlClusterUnblockUnratedContentParams MTRContentControlClusterUpdatePINParams
MTRContentLauncherClusterAdditionalInfo MTRContentLauncherClusterAdditionalInfoStruct
MTRContentLauncherClusterBrandingInformation MTRContentLauncherClusterBrandingInformationStruct
MTRContentLauncherClusterContentAppInfo MTRContentLauncherClusterContentPresetStruct
MTRContentLauncherClusterContentReplicationEvent MTRContentLauncherClusterContentReplicationRequestParams
MTRContentLauncherClusterContentReplicationResponseParams MTRContentLauncherClusterContentSearch
MTRContentLauncherClusterContentSearchStruct MTRContentLauncherClusterDimension
MTRContentLauncherClusterDimensionStruct MTRContentLauncherClusterLaunchContentParams
MTRContentLauncherClusterLaunchResponseParams MTRContentLauncherClusterLaunchURLParams
MTRContentLauncherClusterLaunchUrlInfo MTRContentLauncherClusterLauncherResponseParams
MTRContentLauncherClusterParameter MTRContentLauncherClusterParameterStruct MTRContentLauncherClusterPlayPresetParams
MTRContentLauncherClusterPlaybackPreferencesStruct MTRContentLauncherClusterReplicationInfo
MTRContentLauncherClusterStyleInformation MTRContentLauncherClusterStyleInformationStruct
MTRContentLauncherClusterTrackPreferenceStruct MTRDataTypeAtomicAttributeStatusStruct MTRDataTypeCurrencyStruct
MTRDataTypeICECandidateStruct MTRDataTypeICEServerStruct MTRDataTypeLocationDescriptorStruct
MTRDataTypeMeasurementAccuracyRangeStruct MTRDataTypeMeasurementAccuracyStruct MTRDataTypePowerThresholdStruct
MTRDataTypePriceStruct MTRDataTypeSemanticTagStruct MTRDataTypeTestGlobalStruct MTRDataTypeViewportStruct
MTRDataTypeWebRTCSessionStruct MTRDescriptorClusterDeviceType MTRDescriptorClusterDeviceTypeStruct
MTRDeviceEnergyManagementClusterCancelPowerAdjustRequestParams
MTRDeviceEnergyManagementClusterCancelPowerRangeAdjustRequestParams
MTRDeviceEnergyManagementClusterCancelRequestParams MTRDeviceEnergyManagementClusterConstraintsStruct
MTRDeviceEnergyManagementClusterCostStruct MTRDeviceEnergyManagementClusterForecastStruct
MTRDeviceEnergyManagementClusterModifyForecastRequestParams MTRDeviceEnergyManagementClusterPauseRequestParams
MTRDeviceEnergyManagementClusterPausedEvent MTRDeviceEnergyManagementClusterPowerAdjustCapabilityStruct
MTRDeviceEnergyManagementClusterPowerAdjustEndEvent MTRDeviceEnergyManagementClusterPowerAdjustRequestParams
MTRDeviceEnergyManagementClusterPowerAdjustStartEvent MTRDeviceEnergyManagementClusterPowerAdjustStruct
MTRDeviceEnergyManagementClusterPowerRangeAdjustEndEvent MTRDeviceEnergyManagementClusterPowerRangeAdjustRequestParams
MTRDeviceEnergyManagementClusterPowerRangeAdjustStartEvent MTRDeviceEnergyManagementClusterPowerRangeAdjustStruct
MTRDeviceEnergyManagementClusterRequestConstraintBasedForecastParams
MTRDeviceEnergyManagementClusterResumeRequestParams MTRDeviceEnergyManagementClusterResumedEvent
MTRDeviceEnergyManagementClusterSlotAdjustmentStruct MTRDeviceEnergyManagementClusterSlotStruct
MTRDeviceEnergyManagementClusterStartTimeAdjustRequestParams MTRDeviceEnergyManagementModeClusterChangeToModeParams
MTRDeviceEnergyManagementModeClusterChangeToModeResponseParams MTRDeviceEnergyManagementModeClusterModeOptionStruct
MTRDeviceEnergyManagementModeClusterModeTagStruct MTRDiagnosticLogsClusterRetrieveLogsRequestParams
MTRDiagnosticLogsClusterRetrieveLogsResponseParams MTRDishwasherAlarmClusterModifyEnabledAlarmsParams
MTRDishwasherAlarmClusterNotifyEvent MTRDishwasherAlarmClusterResetParams MTRDishwasherModeClusterChangeToModeParams
MTRDishwasherModeClusterChangeToModeResponseParams MTRDishwasherModeClusterModeOptionStruct
MTRDishwasherModeClusterModeTagStruct MTRDoorLockClusterAppleAliroCredentialStruct
MTRDoorLockClusterAppleAliroLockOperationErrorEvent MTRDoorLockClusterAppleAliroLockOperationEvent
MTRDoorLockClusterAppleAliroLockUserChangeEvent MTRDoorLockClusterAppleClearAliroCredentialParams
MTRDoorLockClusterAppleClearAliroReaderConfigParams MTRDoorLockClusterAppleGetAliroCredentialStatusParams
MTRDoorLockClusterAppleSetAliroCredentialParams MTRDoorLockClusterAppleSetAliroReaderConfigParams
MTRDoorLockClusterClearAliroReaderConfigParams MTRDoorLockClusterClearCredentialParams
MTRDoorLockClusterClearHolidayScheduleParams MTRDoorLockClusterClearUserParams
MTRDoorLockClusterClearWeekDayScheduleParams MTRDoorLockClusterClearYearDayScheduleParams
MTRDoorLockClusterCredentialStruct MTRDoorLockClusterDlCredential MTRDoorLockClusterDoorLockAlarmEvent
MTRDoorLockClusterDoorStateChangeEvent MTRDoorLockClusterGetCredentialStatusParams
MTRDoorLockClusterGetCredentialStatusResponseParams MTRDoorLockClusterGetHolidayScheduleParams
MTRDoorLockClusterGetHolidayScheduleResponseParams MTRDoorLockClusterGetUserParams
MTRDoorLockClusterGetUserResponseParams MTRDoorLockClusterGetWeekDayScheduleParams
MTRDoorLockClusterGetWeekDayScheduleResponseParams MTRDoorLockClusterGetYearDayScheduleParams
MTRDoorLockClusterGetYearDayScheduleResponseParams MTRDoorLockClusterLockDoorParams
MTRDoorLockClusterLockOperationErrorEvent MTRDoorLockClusterLockOperationEvent MTRDoorLockClusterLockUserChangeEvent
MTRDoorLockClusterSetAliroReaderConfigParams MTRDoorLockClusterSetCredentialParams
MTRDoorLockClusterSetCredentialResponseParams MTRDoorLockClusterSetHolidayScheduleParams
MTRDoorLockClusterSetUserParams MTRDoorLockClusterSetWeekDayScheduleParams MTRDoorLockClusterSetYearDayScheduleParams
MTRDoorLockClusterUnboltDoorParams MTRDoorLockClusterUnlockDoorParams MTRDoorLockClusterUnlockWithTimeoutParams
MTRDynamicLightingClusterEffectColorStruct MTRDynamicLightingClusterEffectStruct
MTRDynamicLightingClusterStartEffectParams MTRDynamicLightingClusterStopEffectParams
MTREcosystemInformationClusterDeviceTypeStruct MTREcosystemInformationClusterEcosystemDeviceStruct
MTREcosystemInformationClusterEcosystemLocationStruct MTRElectricalAlarmClusterModifyEnabledAlarmsParams
MTRElectricalAlarmClusterNotifyEvent MTRElectricalAlarmClusterResetParams
MTRElectricalAlarmClusterSetElectricalAlarmThresholdsParams
MTRElectricalEnergyMeasurementClusterCumulativeEnergyMeasuredEvent
MTRElectricalEnergyMeasurementClusterCumulativeEnergyResetStruct
MTRElectricalEnergyMeasurementClusterEnergyMeasurementStruct
MTRElectricalEnergyMeasurementClusterMeasurementAccuracyRangeStruct
MTRElectricalEnergyMeasurementClusterMeasurementAccuracyStruct
MTRElectricalEnergyMeasurementClusterPeriodicEnergyMeasuredEvent
MTRElectricalGridConditionsClusterCurrentConditionsChangedEvent
MTRElectricalGridConditionsClusterElectricalGridConditionsStruct
MTRElectricalMeasurementClusterGetMeasurementProfileCommandParams
MTRElectricalMeasurementClusterGetMeasurementProfileResponseCommandParams
MTRElectricalMeasurementClusterGetProfileInfoCommandParams
MTRElectricalMeasurementClusterGetProfileInfoResponseCommandParams
MTRElectricalPowerMeasurementClusterHarmonicMeasurementStruct
MTRElectricalPowerMeasurementClusterMeasurementAccuracyRangeStruct
MTRElectricalPowerMeasurementClusterMeasurementAccuracyStruct
MTRElectricalPowerMeasurementClusterMeasurementPeriodRangesEvent
MTRElectricalPowerMeasurementClusterMeasurementRangeStruct MTRElectricalProtectionAlarmClusterArcFaultRatingsStruct
MTRElectricalProtectionAlarmClusterModifyEnabledAlarmsParams MTRElectricalProtectionAlarmClusterNotifyEvent
MTRElectricalProtectionAlarmClusterOverLoadRatingsStruct MTRElectricalProtectionAlarmClusterOverVoltageRatingsStruct
MTRElectricalProtectionAlarmClusterResidualCurrentFaultRatingsStruct
MTRElectricalProtectionAlarmClusterShortCircuitRatingsStruct
MTRElectricalProtectionAlarmClusterSurgeProtectionRatingsStruct MTREnergyEVSEClusterChargingTargetScheduleStruct
MTREnergyEVSEClusterChargingTargetStruct MTREnergyEVSEClusterClearTargetsParams MTREnergyEVSEClusterDisableParams
MTREnergyEVSEClusterEVConnectedEvent MTREnergyEVSEClusterEVNotDetectedEvent MTREnergyEVSEClusterEnableChargingParams
MTREnergyEVSEClusterEnableDischargingParams MTREnergyEVSEClusterEnergyTransferStartedEvent
MTREnergyEVSEClusterEnergyTransferStoppedEvent MTREnergyEVSEClusterFaultEvent MTREnergyEVSEClusterGetTargetsParams
MTREnergyEVSEClusterGetTargetsResponseParams MTREnergyEVSEClusterRFIDEvent MTREnergyEVSEClusterSetTargetsParams
MTREnergyEVSEClusterStartDiagnosticsParams MTREnergyEVSEModeClusterChangeToModeParams
MTREnergyEVSEModeClusterChangeToModeResponseParams MTREnergyEVSEModeClusterModeOptionStruct
MTREnergyEVSEModeClusterModeTagStruct MTREnergyPreferenceClusterBalanceStruct
MTREthernetNetworkDiagnosticsClusterResetCountsParams MTRFanControlClusterStepParams MTRFixedLabelClusterLabelStruct
MTRGeneralCommissioningClusterArmFailSafeParams MTRGeneralCommissioningClusterArmFailSafeResponseParams
MTRGeneralCommissioningClusterBasicCommissioningInfo MTRGeneralCommissioningClusterCommissioningCompleteParams
MTRGeneralCommissioningClusterCommissioningCompleteResponseParams
MTRGeneralCommissioningClusterSetRegulatoryConfigParams
MTRGeneralCommissioningClusterSetRegulatoryConfigResponseParams
MTRGeneralCommissioningClusterSetTCAcknowledgementsParams
MTRGeneralCommissioningClusterSetTCAcknowledgementsResponseParams MTRGeneralDiagnosticsClusterBootReasonEvent
MTRGeneralDiagnosticsClusterDeviceLoadStruct MTRGeneralDiagnosticsClusterHardwareFaultChangeEvent
MTRGeneralDiagnosticsClusterNetworkFaultChangeEvent MTRGeneralDiagnosticsClusterNetworkInterface
MTRGeneralDiagnosticsClusterNetworkInterfaceType MTRGeneralDiagnosticsClusterPayloadTestRequestParams
MTRGeneralDiagnosticsClusterPayloadTestResponseParams MTRGeneralDiagnosticsClusterRadioFaultChangeEvent
MTRGeneralDiagnosticsClusterTestEventTriggerParams MTRGeneralDiagnosticsClusterTimeSnapshotParams
MTRGeneralDiagnosticsClusterTimeSnapshotResponseParams MTRGroupKeyManagementClusterGroupInfoMapStruct
MTRGroupKeyManagementClusterGroupKeyMapStruct MTRGroupKeyManagementClusterGroupKeySetStruct
MTRGroupKeyManagementClusterGroupcastAdoptionStruct MTRGroupKeyManagementClusterKeySetReadAllIndicesParams
MTRGroupKeyManagementClusterKeySetReadAllIndicesResponseParams MTRGroupKeyManagementClusterKeySetReadParams
MTRGroupKeyManagementClusterKeySetReadResponseParams MTRGroupKeyManagementClusterKeySetRemoveParams
MTRGroupKeyManagementClusterKeySetWriteParams MTRGroupcastClusterConfigureAuxiliaryACLParams
MTRGroupcastClusterGroupcastTestingEvent MTRGroupcastClusterGroupcastTestingParams MTRGroupcastClusterJoinGroupParams
MTRGroupcastClusterLeaveGroupParams MTRGroupcastClusterLeaveGroupResponseParams MTRGroupcastClusterMembershipStruct
MTRGroupcastClusterUpdateGroupKeyParams MTRGroupsClusterAddGroupIfIdentifyingParams MTRGroupsClusterAddGroupParams
MTRGroupsClusterAddGroupResponseParams MTRGroupsClusterGetGroupMembershipParams
MTRGroupsClusterGetGroupMembershipResponseParams MTRGroupsClusterRemoveAllGroupsParams
MTRGroupsClusterRemoveGroupParams MTRGroupsClusterRemoveGroupResponseParams MTRGroupsClusterViewGroupParams
MTRGroupsClusterViewGroupResponseParams MTRHEPAFilterMonitoringClusterReplacementProductStruct
MTRHEPAFilterMonitoringClusterResetConditionParams MTRHumidistatClusterSetSettingsParams
MTRICDManagementClusterMonitoringRegistrationStruct MTRICDManagementClusterRegisterClientParams
MTRICDManagementClusterRegisterClientResponseParams MTRICDManagementClusterStayActiveRequestParams
MTRICDManagementClusterStayActiveResponseParams MTRICDManagementClusterUnregisterClientParams
MTRIdentifyClusterIdentifyParams MTRIdentifyClusterTriggerEffectParams MTRJointFabricAdministratorClusterAddICACParams
MTRJointFabricAdministratorClusterAnnounceJointFabricAdministratorParams
MTRJointFabricAdministratorClusterICACCSRRequestParams MTRJointFabricAdministratorClusterICACCSRResponseParams
MTRJointFabricAdministratorClusterICACResponseParams
MTRJointFabricAdministratorClusterOpenJointCommissioningWindowParams
MTRJointFabricAdministratorClusterTransferAnchorCompleteParams
MTRJointFabricAdministratorClusterTransferAnchorRequestParams
MTRJointFabricAdministratorClusterTransferAnchorResponseParams MTRJointFabricDatastoreClusterAddACLToNodeParams
MTRJointFabricDatastoreClusterAddAdminParams MTRJointFabricDatastoreClusterAddBindingToEndpointForNodeParams
MTRJointFabricDatastoreClusterAddGroupIDToEndpointForNodeParams MTRJointFabricDatastoreClusterAddGroupParams
MTRJointFabricDatastoreClusterAddKeySetParams MTRJointFabricDatastoreClusterAddPendingNodeParams
MTRJointFabricDatastoreClusterDatastoreACLEntryStruct MTRJointFabricDatastoreClusterDatastoreAccessControlEntryStruct
MTRJointFabricDatastoreClusterDatastoreAccessControlTargetStruct
MTRJointFabricDatastoreClusterDatastoreAdministratorInformationEntryStruct
MTRJointFabricDatastoreClusterDatastoreBindingTargetStruct
MTRJointFabricDatastoreClusterDatastoreEndpointBindingEntryStruct
MTRJointFabricDatastoreClusterDatastoreEndpointEntryStruct
MTRJointFabricDatastoreClusterDatastoreEndpointGroupIDEntryStruct
MTRJointFabricDatastoreClusterDatastoreGroupInformationEntryStruct
MTRJointFabricDatastoreClusterDatastoreGroupKeySetStruct
MTRJointFabricDatastoreClusterDatastoreNodeInformationEntryStruct
MTRJointFabricDatastoreClusterDatastoreNodeKeySetEntryStruct MTRJointFabricDatastoreClusterDatastoreStatusEntryStruct
MTRJointFabricDatastoreClusterRefreshNodeParams MTRJointFabricDatastoreClusterRemoveACLFromNodeParams
MTRJointFabricDatastoreClusterRemoveAdminParams MTRJointFabricDatastoreClusterRemoveBindingFromEndpointForNodeParams
MTRJointFabricDatastoreClusterRemoveGroupIDFromEndpointForNodeParams MTRJointFabricDatastoreClusterRemoveGroupParams
MTRJointFabricDatastoreClusterRemoveKeySetParams MTRJointFabricDatastoreClusterRemoveNodeParams
MTRJointFabricDatastoreClusterUpdateAdminParams MTRJointFabricDatastoreClusterUpdateEndpointForNodeParams
MTRJointFabricDatastoreClusterUpdateGroupParams MTRJointFabricDatastoreClusterUpdateKeySetParams
MTRJointFabricDatastoreClusterUpdateNodeParams MTRKeypadInputClusterSendKeyParams
MTRKeypadInputClusterSendKeyResponseParams MTRLaundryWasherModeClusterChangeToModeParams
MTRLaundryWasherModeClusterChangeToModeResponseParams MTRLaundryWasherModeClusterModeOptionStruct
MTRLaundryWasherModeClusterModeTagStruct MTRLevelControlClusterMoveParams
MTRLevelControlClusterMoveToClosestFrequencyParams MTRLevelControlClusterMoveToLevelParams
MTRLevelControlClusterMoveToLevelWithOnOffParams MTRLevelControlClusterMoveWithOnOffParams
MTRLevelControlClusterStepParams MTRLevelControlClusterStepWithOnOffParams MTRLevelControlClusterStopParams
MTRLevelControlClusterStopWithOnOffParams MTRLowPowerClusterSleepParams MTRMediaFileManagementClusterAddFileParams
MTRMediaFileManagementClusterAddFileResponseParams MTRMediaFileManagementClusterDeleteFileParams
MTRMediaFileManagementClusterFileDescriptionStruct MTRMediaFileManagementClusterGetSharedFileParams
MTRMediaFileManagementClusterGetSharedFileResponseParams MTRMediaFileManagementClusterOfferFileParams
MTRMediaFileManagementClusterRequestSharedFilesParams MTRMediaFileManagementClusterSharedFilesAddedEvent
MTRMediaInputClusterHideInputStatusParams MTRMediaInputClusterInputInfo MTRMediaInputClusterInputInfoStruct
MTRMediaInputClusterRenameInputParams MTRMediaInputClusterSelectInputParams MTRMediaInputClusterShowInputStatusParams
MTRMediaPlaybackClusterActivateAudioTrackParams MTRMediaPlaybackClusterActivateTextTrackParams
MTRMediaPlaybackClusterContentInfoStruct MTRMediaPlaybackClusterDeactivateTextTrackParams
MTRMediaPlaybackClusterFastForwardParams MTRMediaPlaybackClusterNextParams MTRMediaPlaybackClusterPauseParams
MTRMediaPlaybackClusterPlayParams MTRMediaPlaybackClusterPlaybackPosition
MTRMediaPlaybackClusterPlaybackPositionStruct MTRMediaPlaybackClusterPlaybackResponseParams
MTRMediaPlaybackClusterPreviousParams MTRMediaPlaybackClusterRewindParams MTRMediaPlaybackClusterSeekParams
MTRMediaPlaybackClusterSkipBackwardParams MTRMediaPlaybackClusterSkipForwardParams
MTRMediaPlaybackClusterStartOverParams MTRMediaPlaybackClusterStateChangedEvent MTRMediaPlaybackClusterStopParams
MTRMediaPlaybackClusterStopPlaybackParams MTRMediaPlaybackClusterTrackAttributesStruct
MTRMediaPlaybackClusterTrackStruct MTRMessagesClusterCancelMessagesRequestParams
MTRMessagesClusterMessageCompleteEvent MTRMessagesClusterMessageNotPresentedEvent
MTRMessagesClusterMessagePresentedEvent MTRMessagesClusterMessageQueuedEvent
MTRMessagesClusterMessageResponseOptionStruct MTRMessagesClusterMessageStruct
MTRMessagesClusterPresentMessagesRequestParams MTRMicrowaveOvenControlClusterAddMoreTimeParams
MTRMicrowaveOvenControlClusterSetCookingParametersParams MTRMicrowaveOvenModeClusterModeOptionStruct
MTRMicrowaveOvenModeClusterModeTagStruct MTRModeSelectClusterChangeToModeParams MTRModeSelectClusterModeOptionStruct
MTRModeSelectClusterSemanticTag MTRModeSelectClusterSemanticTagStruct
MTRNetworkCommissioningClusterAddOrUpdateThreadNetworkParams
MTRNetworkCommissioningClusterAddOrUpdateWiFiNetworkParams MTRNetworkCommissioningClusterConnectNetworkParams
MTRNetworkCommissioningClusterConnectNetworkResponseParams MTRNetworkCommissioningClusterNetworkConfigResponseParams
MTRNetworkCommissioningClusterNetworkInfo MTRNetworkCommissioningClusterNetworkInfoStruct
MTRNetworkCommissioningClusterQueryIdentityParams MTRNetworkCommissioningClusterQueryIdentityResponseParams
MTRNetworkCommissioningClusterRemoveNetworkParams MTRNetworkCommissioningClusterReorderNetworkParams
MTRNetworkCommissioningClusterScanNetworksParams MTRNetworkCommissioningClusterScanNetworksResponseParams
MTRNetworkCommissioningClusterThreadInterfaceScanResult MTRNetworkCommissioningClusterThreadInterfaceScanResultStruct
MTRNetworkCommissioningClusterWiFiInterfaceScanResult MTRNetworkCommissioningClusterWiFiInterfaceScanResultStruct
MTRNetworkIdentityManagementClusterActiveNetworkIdentityStruct MTRNetworkIdentityManagementClusterAddClientParams
MTRNetworkIdentityManagementClusterAddClientResponseParams MTRNetworkIdentityManagementClusterClientStruct
MTRNetworkIdentityManagementClusterExportAdminSecretParams
MTRNetworkIdentityManagementClusterExportAdminSecretResponseParams
MTRNetworkIdentityManagementClusterImportAdminSecretParams MTRNetworkIdentityManagementClusterQueryIdentityParams
MTRNetworkIdentityManagementClusterQueryIdentityResponseParams MTRNetworkIdentityManagementClusterRemoveClientParams
MTROTASoftwareUpdateProviderClusterApplyUpdateRequestParams
MTROTASoftwareUpdateProviderClusterApplyUpdateResponseParams
MTROTASoftwareUpdateProviderClusterNotifyUpdateAppliedParams MTROTASoftwareUpdateProviderClusterQueryImageParams
MTROTASoftwareUpdateProviderClusterQueryImageResponseParams
MTROTASoftwareUpdateRequestorClusterAnnounceOTAProviderParams MTROTASoftwareUpdateRequestorClusterDownloadErrorEvent
MTROTASoftwareUpdateRequestorClusterProviderLocation MTROTASoftwareUpdateRequestorClusterStateTransitionEvent
MTROTASoftwareUpdateRequestorClusterVersionAppliedEvent MTROccupancySensingClusterHoldTimeLimitsStruct
MTROccupancySensingClusterOccupancyChangedEvent MTROccupancySensingClusterPredictedOccupancyStruct
MTROnOffClusterOffParams MTROnOffClusterOffWithEffectParams MTROnOffClusterOnParams
MTROnOffClusterOnWithRecallGlobalSceneParams MTROnOffClusterOnWithTimedOffParams MTROnOffClusterToggleParams
MTROperationalCredentialsClusterAddNOCParams MTROperationalCredentialsClusterAddTrustedRootCertificateParams
MTROperationalCredentialsClusterAttestationRequestParams MTROperationalCredentialsClusterAttestationResponseParams
MTROperationalCredentialsClusterCSRRequestParams MTROperationalCredentialsClusterCSRResponseParams
MTROperationalCredentialsClusterCertificateChainRequestParams
MTROperationalCredentialsClusterCertificateChainResponseParams MTROperationalCredentialsClusterFabricDescriptor
MTROperationalCredentialsClusterFabricDescriptorStruct MTROperationalCredentialsClusterNOCResponseParams
MTROperationalCredentialsClusterNOCStruct MTROperationalCredentialsClusterRemoveFabricParams
MTROperationalCredentialsClusterSetVIDVerificationStatementParams
MTROperationalCredentialsClusterSignVIDVerificationRequestParams
MTROperationalCredentialsClusterSignVIDVerificationResponseParams
MTROperationalCredentialsClusterUpdateFabricLabelParams MTROperationalCredentialsClusterUpdateNOCParams
MTROperationalStateClusterErrorStateStruct MTROperationalStateClusterOperationCompletionEvent
MTROperationalStateClusterOperationalCommandResponseParams MTROperationalStateClusterOperationalErrorEvent
MTROperationalStateClusterOperationalStateStruct MTROperationalStateClusterPauseParams
MTROperationalStateClusterResumeParams MTROperationalStateClusterStartParams MTROperationalStateClusterStopParams
MTROtaSoftwareUpdateProviderClusterApplyUpdateRequestParams
MTROtaSoftwareUpdateProviderClusterApplyUpdateResponseParams
MTROtaSoftwareUpdateProviderClusterNotifyUpdateAppliedParams MTROtaSoftwareUpdateProviderClusterQueryImageParams
MTROtaSoftwareUpdateProviderClusterQueryImageResponseParams
MTROtaSoftwareUpdateRequestorClusterAnnounceOtaProviderParams MTROtaSoftwareUpdateRequestorClusterDownloadErrorEvent
MTROtaSoftwareUpdateRequestorClusterProviderLocation MTROtaSoftwareUpdateRequestorClusterStateTransitionEvent
MTROtaSoftwareUpdateRequestorClusterVersionAppliedEvent MTROvenCavityOperationalStateClusterErrorStateStruct
MTROvenCavityOperationalStateClusterOperationCompletionEvent
MTROvenCavityOperationalStateClusterOperationalCommandResponseParams
MTROvenCavityOperationalStateClusterOperationalErrorEvent MTROvenCavityOperationalStateClusterOperationalStateStruct
MTROvenCavityOperationalStateClusterStartParams MTROvenCavityOperationalStateClusterStopParams
MTROvenModeClusterChangeToModeParams MTROvenModeClusterChangeToModeResponseParams MTROvenModeClusterModeOptionStruct
MTROvenModeClusterModeTagStruct MTRPowerSourceClusterBatChargeFaultChangeEvent
MTRPowerSourceClusterBatChargeFaultChangeType MTRPowerSourceClusterBatFaultChangeEvent
MTRPowerSourceClusterBatFaultChangeType MTRPowerSourceClusterWiredFaultChangeEvent
MTRPowerSourceClusterWiredFaultChangeType MTRPowerTopologyClusterCircuitNodeStruct
MTRProximityRangingClusterBLERangingDeviceRoleConfigStruct
MTRProximityRangingClusterBLTChannelSoundingDeviceRoleConfigStruct MTRProximityRangingClusterRDRStruct
MTRProximityRangingClusterRangingCapabilitiesStruct MTRProximityRangingClusterRangingConstraintStruct
MTRProximityRangingClusterRangingMeasurementDataStruct MTRProximityRangingClusterRangingResultEvent
MTRProximityRangingClusterRangingSessionStatusEvent MTRProximityRangingClusterRangingTriggerConditionStruct
MTRProximityRangingClusterReportingConditionStruct MTRProximityRangingClusterStartRangingRequestParams
MTRProximityRangingClusterStartRangingResponseParams MTRProximityRangingClusterStopRangingRequestParams
MTRProximityRangingClusterWiFiRangingDeviceRoleConfigStruct MTRPumpConfigurationAndControlClusterAirDetectionEvent
MTRPumpConfigurationAndControlClusterDryRunningEvent MTRPumpConfigurationAndControlClusterElectronicFatalFailureEvent
MTRPumpConfigurationAndControlClusterElectronicNonFatalFailureEvent
MTRPumpConfigurationAndControlClusterElectronicTemperatureHighEvent
MTRPumpConfigurationAndControlClusterGeneralFaultEvent MTRPumpConfigurationAndControlClusterLeakageEvent
MTRPumpConfigurationAndControlClusterMotorTemperatureHighEvent
MTRPumpConfigurationAndControlClusterPowerMissingPhaseEvent MTRPumpConfigurationAndControlClusterPumpBlockedEvent
MTRPumpConfigurationAndControlClusterPumpMotorFatalFailureEvent
MTRPumpConfigurationAndControlClusterSensorFailureEvent MTRPumpConfigurationAndControlClusterSupplyVoltageHighEvent
MTRPumpConfigurationAndControlClusterSupplyVoltageLowEvent
MTRPumpConfigurationAndControlClusterSystemPressureHighEvent
MTRPumpConfigurationAndControlClusterSystemPressureLowEvent MTRPumpConfigurationAndControlClusterTurbineOperationEvent
MTRPushAVStreamTransportClusterAllocatePushTransportParams
MTRPushAVStreamTransportClusterAllocatePushTransportResponseParams MTRPushAVStreamTransportClusterAudioStreamStruct
MTRPushAVStreamTransportClusterCMAFContainerOptionsStruct MTRPushAVStreamTransportClusterContainerOptionsStruct
MTRPushAVStreamTransportClusterDeallocatePushTransportParams MTRPushAVStreamTransportClusterFindTransportParams
MTRPushAVStreamTransportClusterFindTransportResponseParams
MTRPushAVStreamTransportClusterManuallyTriggerTransportParams MTRPushAVStreamTransportClusterModifyPushTransportParams
MTRPushAVStreamTransportClusterPushTransportBeginEvent MTRPushAVStreamTransportClusterPushTransportEndEvent
MTRPushAVStreamTransportClusterSetTransportStatusParams MTRPushAVStreamTransportClusterSupportedFormatStruct
MTRPushAVStreamTransportClusterTransportConfigurationStruct
MTRPushAVStreamTransportClusterTransportMotionTriggerTimeControlStruct
MTRPushAVStreamTransportClusterTransportOptionsStruct MTRPushAVStreamTransportClusterTransportTriggerOptionsStruct
MTRPushAVStreamTransportClusterTransportZoneOptionsStruct MTRPushAVStreamTransportClusterUpdateMotionZoneOptionsParams
MTRPushAVStreamTransportClusterVideoStreamStruct MTRRVCCleanModeClusterChangeToModeParams
MTRRVCCleanModeClusterChangeToModeResponseParams MTRRVCCleanModeClusterModeOptionStruct
MTRRVCCleanModeClusterModeTagStruct MTRRVCOperationalStateClusterErrorStateStruct
MTRRVCOperationalStateClusterGoHomeParams MTRRVCOperationalStateClusterOperationCompletionEvent
MTRRVCOperationalStateClusterOperationalCommandResponseParams MTRRVCOperationalStateClusterOperationalErrorEvent
MTRRVCOperationalStateClusterOperationalStateStruct MTRRVCOperationalStateClusterPauseParams
MTRRVCOperationalStateClusterResumeParams MTRRVCRunModeClusterChangeToModeParams
MTRRVCRunModeClusterChangeToModeResponseParams MTRRVCRunModeClusterModeOptionStruct MTRRVCRunModeClusterModeTagStruct
MTRRefrigeratorAlarmClusterNotifyEvent MTRRefrigeratorAndTemperatureControlledCabinetModeClusterChangeToModeParams
MTRRefrigeratorAndTemperatureControlledCabinetModeClusterChangeToModeResponseParams
MTRRefrigeratorAndTemperatureControlledCabinetModeClusterModeOptionStruct
MTRRefrigeratorAndTemperatureControlledCabinetModeClusterModeTagStruct MTRSampleMEIClusterAddArgumentsParams
MTRSampleMEIClusterAddArgumentsResponseParams MTRSampleMEIClusterPingCountEventEvent MTRSampleMEIClusterPingParams
MTRScenesManagementClusterAddSceneParams MTRScenesManagementClusterAddSceneResponseParams
MTRScenesManagementClusterAttributeValuePairStruct MTRScenesManagementClusterCopySceneParams
MTRScenesManagementClusterCopySceneResponseParams MTRScenesManagementClusterExtensionFieldSetStruct
MTRScenesManagementClusterGetSceneMembershipParams MTRScenesManagementClusterGetSceneMembershipResponseParams
MTRScenesManagementClusterRecallSceneParams MTRScenesManagementClusterRemoveAllScenesParams
MTRScenesManagementClusterRemoveAllScenesResponseParams MTRScenesManagementClusterRemoveSceneParams
MTRScenesManagementClusterRemoveSceneResponseParams MTRScenesManagementClusterSceneInfoStruct
MTRScenesManagementClusterStoreSceneParams MTRScenesManagementClusterStoreSceneResponseParams
MTRScenesManagementClusterViewSceneParams MTRScenesManagementClusterViewSceneResponseParams
MTRServiceAreaClusterAreaInfoStruct MTRServiceAreaClusterAreaStruct MTRServiceAreaClusterLandmarkInfoStruct
MTRServiceAreaClusterMapStruct MTRServiceAreaClusterProgressStruct MTRServiceAreaClusterSelectAreasParams
MTRServiceAreaClusterSelectAreasResponseParams MTRServiceAreaClusterSkipAreaParams
MTRServiceAreaClusterSkipAreaResponseParams MTRSmokeCOAlarmClusterAlarmMutedEvent MTRSmokeCOAlarmClusterAllClearEvent
MTRSmokeCOAlarmClusterCOAlarmEvent MTRSmokeCOAlarmClusterEndOfServiceEvent MTRSmokeCOAlarmClusterHardwareFaultEvent
MTRSmokeCOAlarmClusterInterconnectCOAlarmEvent MTRSmokeCOAlarmClusterInterconnectSmokeAlarmEvent
MTRSmokeCOAlarmClusterLowBatteryEvent MTRSmokeCOAlarmClusterMuteEndedEvent MTRSmokeCOAlarmClusterSelfTestCompleteEvent
MTRSmokeCOAlarmClusterSelfTestRequestParams MTRSmokeCOAlarmClusterSmokeAlarmEvent
MTRSoftwareDiagnosticsClusterResetWatermarksParams MTRSoftwareDiagnosticsClusterSoftwareFaultEvent
MTRSoftwareDiagnosticsClusterThreadMetrics MTRSoftwareDiagnosticsClusterThreadMetricsStruct
MTRSwitchClusterInitialPressEvent MTRSwitchClusterLongPressEvent MTRSwitchClusterLongReleaseEvent
MTRSwitchClusterMultiPressCompleteEvent MTRSwitchClusterMultiPressOngoingEvent MTRSwitchClusterShortReleaseEvent
MTRSwitchClusterSwitchLatchedEvent MTRTLSCertificateManagementClusterClientCSRParams
MTRTLSCertificateManagementClusterClientCSRResponseParams
MTRTLSCertificateManagementClusterFindClientCertificateParams
MTRTLSCertificateManagementClusterFindClientCertificateResponseParams
MTRTLSCertificateManagementClusterFindRootCertificateParams
MTRTLSCertificateManagementClusterFindRootCertificateResponseParams
MTRTLSCertificateManagementClusterLookupClientCertificateParams
MTRTLSCertificateManagementClusterLookupClientCertificateResponseParams
MTRTLSCertificateManagementClusterLookupRootCertificateParams
MTRTLSCertificateManagementClusterLookupRootCertificateResponseParams
MTRTLSCertificateManagementClusterProvisionClientCertificateParams
MTRTLSCertificateManagementClusterProvisionRootCertificateParams
MTRTLSCertificateManagementClusterProvisionRootCertificateResponseParams
MTRTLSCertificateManagementClusterRemoveClientCertificateParams
MTRTLSCertificateManagementClusterRemoveRootCertificateParams MTRTLSCertificateManagementClusterTLSCertStruct
MTRTLSCertificateManagementClusterTLSClientCertificateDetailStruct MTRTLSClientManagementClusterFindEndpointParams
MTRTLSClientManagementClusterFindEndpointResponseParams MTRTLSClientManagementClusterProvisionEndpointParams
MTRTLSClientManagementClusterProvisionEndpointResponseParams MTRTLSClientManagementClusterRemoveEndpointParams
MTRTLSClientManagementClusterTLSEndpointStruct MTRTargetNavigatorClusterNavigateTargetParams
MTRTargetNavigatorClusterNavigateTargetResponseParams MTRTargetNavigatorClusterTargetInfo
MTRTargetNavigatorClusterTargetInfoStruct MTRTargetNavigatorClusterTargetUpdatedEvent
MTRTemperatureControlClusterSetTemperatureParams MTRTestClusterClusterBooleanResponseParams
MTRTestClusterClusterDoubleNestedStructList MTRTestClusterClusterNestedStruct MTRTestClusterClusterNestedStructList
MTRTestClusterClusterNullablesAndOptionalsStruct MTRTestClusterClusterSimpleStruct
MTRTestClusterClusterSimpleStructEchoRequestParams MTRTestClusterClusterSimpleStructResponseParams
MTRTestClusterClusterTestAddArgumentsParams MTRTestClusterClusterTestAddArgumentsResponseParams
MTRTestClusterClusterTestComplexNullableOptionalRequestParams
MTRTestClusterClusterTestComplexNullableOptionalResponseParams MTRTestClusterClusterTestEmitTestEventRequestParams
MTRTestClusterClusterTestEmitTestEventResponseParams MTRTestClusterClusterTestEmitTestFabricScopedEventRequestParams
MTRTestClusterClusterTestEmitTestFabricScopedEventResponseParams MTRTestClusterClusterTestEnumsRequestParams
MTRTestClusterClusterTestEnumsResponseParams MTRTestClusterClusterTestEventEvent MTRTestClusterClusterTestFabricScoped
MTRTestClusterClusterTestFabricScopedEventEvent MTRTestClusterClusterTestListInt8UArgumentRequestParams
MTRTestClusterClusterTestListInt8UReverseRequestParams MTRTestClusterClusterTestListInt8UReverseResponseParams
MTRTestClusterClusterTestListNestedStructListArgumentRequestParams
MTRTestClusterClusterTestListStructArgumentRequestParams MTRTestClusterClusterTestListStructOctet
MTRTestClusterClusterTestNestedStructArgumentRequestParams
MTRTestClusterClusterTestNestedStructListArgumentRequestParams MTRTestClusterClusterTestNotHandledParams
MTRTestClusterClusterTestNullableOptionalRequestParams MTRTestClusterClusterTestNullableOptionalResponseParams
MTRTestClusterClusterTestParams MTRTestClusterClusterTestSimpleArgumentRequestParams
MTRTestClusterClusterTestSimpleArgumentResponseParams MTRTestClusterClusterTestSimpleOptionalArgumentRequestParams
MTRTestClusterClusterTestSpecificParams MTRTestClusterClusterTestSpecificResponseParams
MTRTestClusterClusterTestStructArgumentRequestParams MTRTestClusterClusterTestStructArrayArgumentRequestParams
MTRTestClusterClusterTestStructArrayArgumentResponseParams MTRTestClusterClusterTestUnknownCommandParams
MTRTestClusterClusterTimedInvokeRequestParams MTRThermostatClusterActivePresetChangeEvent
MTRThermostatClusterActiveScheduleChangeEvent MTRThermostatClusterAddThermostatSuggestionParams
MTRThermostatClusterAddThermostatSuggestionResponseParams MTRThermostatClusterAtomicRequestParams
MTRThermostatClusterAtomicResponseParams MTRThermostatClusterClearWeeklyScheduleParams
MTRThermostatClusterGetWeeklyScheduleParams MTRThermostatClusterGetWeeklyScheduleResponseParams
MTRThermostatClusterLocalTemperatureChangeEvent MTRThermostatClusterOccupancyChangeEvent
MTRThermostatClusterPresetStruct MTRThermostatClusterPresetTypeStruct
MTRThermostatClusterRemoveThermostatSuggestionParams MTRThermostatClusterRunningModeChangeEvent
MTRThermostatClusterRunningStateChangeEvent MTRThermostatClusterScheduleStruct
MTRThermostatClusterScheduleTransitionStruct MTRThermostatClusterScheduleTypeStruct
MTRThermostatClusterSetActivePresetRequestParams MTRThermostatClusterSetActiveScheduleRequestParams
MTRThermostatClusterSetWeeklyScheduleParams MTRThermostatClusterSetpointChangeEvent
MTRThermostatClusterSetpointRaiseLowerParams MTRThermostatClusterSystemModeChangeEvent
MTRThermostatClusterThermostatScheduleTransition MTRThermostatClusterThermostatSuggestionStruct
MTRThermostatClusterWeeklyScheduleTransitionStruct MTRThreadBorderRouterManagementClusterDatasetResponseParams
MTRThreadBorderRouterManagementClusterGetActiveDatasetRequestParams
MTRThreadBorderRouterManagementClusterGetPendingDatasetRequestParams
MTRThreadBorderRouterManagementClusterSetActiveDatasetRequestParams
MTRThreadBorderRouterManagementClusterSetPendingDatasetRequestParams
MTRThreadNetworkDiagnosticsClusterConnectionStatusEvent MTRThreadNetworkDiagnosticsClusterNeighborTable
MTRThreadNetworkDiagnosticsClusterNeighborTableStruct MTRThreadNetworkDiagnosticsClusterNetworkFaultChangeEvent
MTRThreadNetworkDiagnosticsClusterOperationalDatasetComponents MTRThreadNetworkDiagnosticsClusterResetCountsParams
MTRThreadNetworkDiagnosticsClusterRouteTable MTRThreadNetworkDiagnosticsClusterRouteTableStruct
MTRThreadNetworkDiagnosticsClusterSecurityPolicy MTRThreadNetworkDirectoryClusterAddNetworkParams
MTRThreadNetworkDirectoryClusterGetOperationalDatasetParams
MTRThreadNetworkDirectoryClusterOperationalDatasetResponseParams MTRThreadNetworkDirectoryClusterRemoveNetworkParams
MTRThreadNetworkDirectoryClusterThreadNetworkStruct MTRTimeSynchronizationClusterDSTOffsetStruct
MTRTimeSynchronizationClusterDSTStatusEvent MTRTimeSynchronizationClusterDSTTableEmptyEvent
MTRTimeSynchronizationClusterDstOffsetType MTRTimeSynchronizationClusterFabricScopedTrustedTimeSourceStruct
MTRTimeSynchronizationClusterMissingTrustedTimeSourceEvent MTRTimeSynchronizationClusterSetDSTOffsetParams
MTRTimeSynchronizationClusterSetDefaultNTPParams MTRTimeSynchronizationClusterSetTimeZoneParams
MTRTimeSynchronizationClusterSetTimeZoneResponseParams MTRTimeSynchronizationClusterSetTrustedTimeSourceParams
MTRTimeSynchronizationClusterSetUTCTimeParams MTRTimeSynchronizationClusterSetUtcTimeParams
MTRTimeSynchronizationClusterTimeFailureEvent MTRTimeSynchronizationClusterTimeZoneStatusEvent
MTRTimeSynchronizationClusterTimeZoneStruct MTRTimeSynchronizationClusterTimeZoneType
MTRTimeSynchronizationClusterTrustedTimeSourceStruct MTRUnitTestingClusterBooleanResponseParams
MTRUnitTestingClusterDoubleNestedStructList MTRUnitTestingClusterGlobalEchoRequestParams
MTRUnitTestingClusterGlobalEchoResponseParams MTRUnitTestingClusterNestedStruct MTRUnitTestingClusterNestedStructList
MTRUnitTestingClusterNullablesAndOptionalsStruct MTRUnitTestingClusterSimpleStruct
MTRUnitTestingClusterSimpleStructEchoRequestParams MTRUnitTestingClusterSimpleStructResponseParams
MTRUnitTestingClusterStringEchoRequestParams MTRUnitTestingClusterStringEchoResponseParams
MTRUnitTestingClusterTestAddArgumentsParams MTRUnitTestingClusterTestAddArgumentsResponseParams
MTRUnitTestingClusterTestBatchHelperRequestParams MTRUnitTestingClusterTestBatchHelperResponseParams
MTRUnitTestingClusterTestCheckCommandFlagsParams MTRUnitTestingClusterTestComplexNullableOptionalRequestParams
MTRUnitTestingClusterTestComplexNullableOptionalResponseParams MTRUnitTestingClusterTestDifferentVendorMeiEventEvent
MTRUnitTestingClusterTestDifferentVendorMeiRequestParams MTRUnitTestingClusterTestDifferentVendorMeiResponseParams
MTRUnitTestingClusterTestEmitTestEventRequestParams MTRUnitTestingClusterTestEmitTestEventResponseParams
MTRUnitTestingClusterTestEmitTestFabricScopedEventRequestParams
MTRUnitTestingClusterTestEmitTestFabricScopedEventResponseParams MTRUnitTestingClusterTestEnumsRequestParams
MTRUnitTestingClusterTestEnumsResponseParams MTRUnitTestingClusterTestEventEvent MTRUnitTestingClusterTestFabricScoped
MTRUnitTestingClusterTestFabricScopedEventEvent MTRUnitTestingClusterTestListInt8UArgumentRequestParams
MTRUnitTestingClusterTestListInt8UReverseRequestParams MTRUnitTestingClusterTestListInt8UReverseResponseParams
MTRUnitTestingClusterTestListNestedStructListArgumentRequestParams
MTRUnitTestingClusterTestListStructArgumentRequestParams MTRUnitTestingClusterTestListStructOctet
MTRUnitTestingClusterTestNestedStructArgumentRequestParams
MTRUnitTestingClusterTestNestedStructListArgumentRequestParams MTRUnitTestingClusterTestNotHandledParams
MTRUnitTestingClusterTestNullableOptionalRequestParams MTRUnitTestingClusterTestNullableOptionalResponseParams
MTRUnitTestingClusterTestParams MTRUnitTestingClusterTestSecondBatchHelperRequestParams
MTRUnitTestingClusterTestSimpleArgumentRequestParams MTRUnitTestingClusterTestSimpleArgumentResponseParams
MTRUnitTestingClusterTestSimpleOptionalArgumentRequestParams MTRUnitTestingClusterTestSpecificParams
MTRUnitTestingClusterTestSpecificResponseParams MTRUnitTestingClusterTestStructArgumentRequestParams
MTRUnitTestingClusterTestStructArrayArgumentRequestParams MTRUnitTestingClusterTestStructArrayArgumentResponseParams
MTRUnitTestingClusterTestUnknownCommandParams MTRUnitTestingClusterTimedInvokeRequestParams
MTRUserLabelClusterLabelStruct MTRValveConfigurationAndControlClusterCloseParams
MTRValveConfigurationAndControlClusterOpenParams MTRValveConfigurationAndControlClusterValveFaultEvent
MTRValveConfigurationAndControlClusterValveStateChangedEvent MTRWaterHeaterManagementClusterBoostEndedEvent
MTRWaterHeaterManagementClusterBoostParams MTRWaterHeaterManagementClusterBoostStartedEvent
MTRWaterHeaterManagementClusterCancelBoostParams MTRWaterHeaterManagementClusterWaterHeaterBoostInfoStruct
MTRWaterHeaterModeClusterChangeToModeParams MTRWaterHeaterModeClusterChangeToModeResponseParams
MTRWaterHeaterModeClusterModeOptionStruct MTRWaterHeaterModeClusterModeTagStruct
MTRWaterTankLevelMonitoringClusterReplacementProductStruct MTRWaterTankLevelMonitoringClusterResetConditionParams
MTRWebRTCTransportProviderClusterEndSessionParams MTRWebRTCTransportProviderClusterProvideAnswerParams
MTRWebRTCTransportProviderClusterProvideICECandidatesParams MTRWebRTCTransportProviderClusterProvideOfferParams
MTRWebRTCTransportProviderClusterProvideOfferResponseParams MTRWebRTCTransportProviderClusterSFrameStruct
MTRWebRTCTransportProviderClusterSolicitOfferParams MTRWebRTCTransportProviderClusterSolicitOfferResponseParams
MTRWebRTCTransportRequestorClusterAnswerParams MTRWebRTCTransportRequestorClusterEndParams
MTRWebRTCTransportRequestorClusterICECandidatesParams MTRWebRTCTransportRequestorClusterOfferParams
MTRWiFiNetworkDiagnosticsClusterAssociationFailureEvent MTRWiFiNetworkDiagnosticsClusterConnectionStatusEvent
MTRWiFiNetworkDiagnosticsClusterDisconnectionEvent MTRWiFiNetworkDiagnosticsClusterResetCountsParams
MTRWiFiNetworkManagementClusterNetworkPassphraseRequestParams
MTRWiFiNetworkManagementClusterNetworkPassphraseResponseParams MTRWindowCoveringClusterDownOrCloseParams
MTRWindowCoveringClusterGoToLiftPercentageParams MTRWindowCoveringClusterGoToLiftValueParams
MTRWindowCoveringClusterGoToTiltPercentageParams MTRWindowCoveringClusterGoToTiltValueParams
MTRWindowCoveringClusterStopMotionParams MTRWindowCoveringClusterUpOrOpenParams
MTRZoneManagementClusterCreateOrUpdateTriggerParams MTRZoneManagementClusterCreateTwoDCartesianZoneParams
MTRZoneManagementClusterCreateTwoDCartesianZoneResponseParams MTRZoneManagementClusterRemoveTriggerParams
MTRZoneManagementClusterRemoveZoneParams MTRZoneManagementClusterTwoDCartesianVertexStruct
MTRZoneManagementClusterTwoDCartesianZoneStruct MTRZoneManagementClusterUpdateTwoDCartesianZoneParams
MTRZoneManagementClusterZoneInformationStruct MTRZoneManagementClusterZoneStoppedEvent
MTRZoneManagementClusterZoneTriggerControlStruct MTRZoneManagementClusterZoneTriggeredEvent
"""
private let p27MatterClusterClasses = """
MTRBaseClusterAVAnalysis MTRBaseClusterAccessControl MTRBaseClusterAccountLogin MTRBaseClusterActions
MTRBaseClusterActivatedCarbonFilterMonitoring MTRBaseClusterAdministratorCommissioning MTRBaseClusterAirQuality
MTRBaseClusterAmbientContextSensing MTRBaseClusterAmbientSensingUnion MTRBaseClusterAppleDeviceInformation
MTRBaseClusterAppleLockCluster MTRBaseClusterApplicationBasic MTRBaseClusterApplicationLauncher
MTRBaseClusterAudioControl MTRBaseClusterAudioOutput MTRBaseClusterBallastConfiguration MTRBaseClusterBarrierControl
MTRBaseClusterBasic MTRBaseClusterBasicInformation MTRBaseClusterBinaryInputBasic MTRBaseClusterBinding
MTRBaseClusterBooleanState MTRBaseClusterBooleanStateConfiguration MTRBaseClusterBridgedDeviceBasic
MTRBaseClusterBridgedDeviceBasicInformation MTRBaseClusterCameraAVSettingsUserLevelManagement
MTRBaseClusterCameraAVStreamManagement MTRBaseClusterCarbonDioxideConcentrationMeasurement
MTRBaseClusterCarbonMonoxideConcentrationMeasurement MTRBaseClusterChannel MTRBaseClusterChime
MTRBaseClusterClosureControl MTRBaseClusterClosureDimension MTRBaseClusterColorControl
MTRBaseClusterCommissionerControl MTRBaseClusterCommissioningProxy MTRBaseClusterCommodityMetering
MTRBaseClusterCommodityPrice MTRBaseClusterCommodityTariff MTRBaseClusterContentAppObserver
MTRBaseClusterContentControl MTRBaseClusterContentLauncher MTRBaseClusterDescriptor
MTRBaseClusterDeviceEnergyManagement MTRBaseClusterDeviceEnergyManagementMode MTRBaseClusterDiagnosticLogs
MTRBaseClusterDishwasherAlarm MTRBaseClusterDishwasherMode MTRBaseClusterDoorLock MTRBaseClusterDynamicLighting
MTRBaseClusterEcosystemInformation MTRBaseClusterElectricalAlarm MTRBaseClusterElectricalDistribution
MTRBaseClusterElectricalEnergyMeasurement MTRBaseClusterElectricalGridConditions MTRBaseClusterElectricalMeasurement
MTRBaseClusterElectricalPowerMeasurement MTRBaseClusterElectricalProtectionAlarm MTRBaseClusterEnergyEVSE
MTRBaseClusterEnergyEVSEMode MTRBaseClusterEnergyPreference MTRBaseClusterEthernetNetworkDiagnostics
MTRBaseClusterFanControl MTRBaseClusterFixedLabel MTRBaseClusterFlowMeasurement
MTRBaseClusterFormaldehydeConcentrationMeasurement MTRBaseClusterGeneralCommissioning MTRBaseClusterGeneralDiagnostics
MTRBaseClusterGroupKeyManagement MTRBaseClusterGroupcast MTRBaseClusterGroups MTRBaseClusterHEPAFilterMonitoring
MTRBaseClusterHumidistat MTRBaseClusterICDManagement MTRBaseClusterIdentify MTRBaseClusterIlluminanceMeasurement
MTRBaseClusterJointFabricAdministrator MTRBaseClusterJointFabricDatastore MTRBaseClusterKeypadInput
MTRBaseClusterLaundryDryerControls MTRBaseClusterLaundryWasherControls MTRBaseClusterLaundryWasherMode
MTRBaseClusterLevelControl MTRBaseClusterLocalizationConfiguration MTRBaseClusterLowPower
MTRBaseClusterMediaFileManagement MTRBaseClusterMediaInput MTRBaseClusterMediaPlayback MTRBaseClusterMessages
MTRBaseClusterMeterIdentification MTRBaseClusterMicrowaveOvenControl MTRBaseClusterMicrowaveOvenMode
MTRBaseClusterModeSelect MTRBaseClusterNetworkCommissioning MTRBaseClusterNetworkIdentityManagement
MTRBaseClusterNitrogenDioxideConcentrationMeasurement MTRBaseClusterOTASoftwareUpdateProvider
MTRBaseClusterOTASoftwareUpdateRequestor MTRBaseClusterOccupancySensing MTRBaseClusterOnOff
MTRBaseClusterOnOffSwitchConfiguration MTRBaseClusterOperationalCredentials MTRBaseClusterOperationalState
MTRBaseClusterOtaSoftwareUpdateProvider MTRBaseClusterOtaSoftwareUpdateRequestor
MTRBaseClusterOvenCavityOperationalState MTRBaseClusterOvenMode MTRBaseClusterOzoneConcentrationMeasurement
MTRBaseClusterPM10ConcentrationMeasurement MTRBaseClusterPM1ConcentrationMeasurement
MTRBaseClusterPM25ConcentrationMeasurement MTRBaseClusterPowerSource MTRBaseClusterPowerSourceConfiguration
MTRBaseClusterPowerTopology MTRBaseClusterPressureMeasurement MTRBaseClusterProximityRanging
MTRBaseClusterPulseWidthModulation MTRBaseClusterPumpConfigurationAndControl MTRBaseClusterPushAVStreamTransport
MTRBaseClusterRVCCleanMode MTRBaseClusterRVCOperationalState MTRBaseClusterRVCRunMode
MTRBaseClusterRadonConcentrationMeasurement MTRBaseClusterRefrigeratorAlarm
MTRBaseClusterRefrigeratorAndTemperatureControlledCabinetMode MTRBaseClusterRelativeHumidityMeasurement
MTRBaseClusterSampleMEI MTRBaseClusterScenesManagement MTRBaseClusterServiceArea MTRBaseClusterSmokeCOAlarm
MTRBaseClusterSmokeConcentrationMeasurement MTRBaseClusterSoftwareDiagnostics MTRBaseClusterSoilMeasurement
MTRBaseClusterSwitch MTRBaseClusterTLSCertificateManagement MTRBaseClusterTLSClientManagement
MTRBaseClusterTargetNavigator MTRBaseClusterTemperatureControl MTRBaseClusterTemperatureControlledCabinetTopology
MTRBaseClusterTemperatureMeasurement MTRBaseClusterTestCluster MTRBaseClusterTestHiddenManufacturerSpecific
MTRBaseClusterThermostat MTRBaseClusterThermostatUserInterfaceConfiguration MTRBaseClusterThreadBorderRouterManagement
MTRBaseClusterThreadNetworkDiagnostics MTRBaseClusterThreadNetworkDirectory MTRBaseClusterTimeFormatLocalization
MTRBaseClusterTimeSynchronization MTRBaseClusterTotalVolatileOrganicCompoundsConcentrationMeasurement
MTRBaseClusterUnitLocalization MTRBaseClusterUnitTesting MTRBaseClusterUserLabel
MTRBaseClusterValveConfigurationAndControl MTRBaseClusterWakeOnLAN MTRBaseClusterWakeOnLan
MTRBaseClusterWaterHeaterManagement MTRBaseClusterWaterHeaterMode MTRBaseClusterWaterTankLevelMonitoring
MTRBaseClusterWebRTCTransportProvider MTRBaseClusterWebRTCTransportRequestor MTRBaseClusterWiFiNetworkDiagnostics
MTRBaseClusterWiFiNetworkManagement MTRBaseClusterWindowCovering MTRBaseClusterZoneManagement MTRClusterAVAnalysis
MTRClusterAccessControl MTRClusterAccountLogin MTRClusterActions MTRClusterActivatedCarbonFilterMonitoring
MTRClusterAdministratorCommissioning MTRClusterAirQuality MTRClusterAmbientContextSensing
MTRClusterAmbientSensingUnion MTRClusterAppleDeviceInformation MTRClusterAppleLockCluster MTRClusterApplicationBasic
MTRClusterApplicationLauncher MTRClusterAudioControl MTRClusterAudioOutput MTRClusterBallastConfiguration
MTRClusterBarrierControl MTRClusterBasic MTRClusterBasicInformation MTRClusterBinaryInputBasic MTRClusterBinding
MTRClusterBooleanState MTRClusterBooleanStateConfiguration MTRClusterBridgedDeviceBasic
MTRClusterBridgedDeviceBasicInformation MTRClusterCameraAVSettingsUserLevelManagement
MTRClusterCameraAVStreamManagement MTRClusterCarbonDioxideConcentrationMeasurement
MTRClusterCarbonMonoxideConcentrationMeasurement MTRClusterChannel MTRClusterChime MTRClusterClosureControl
MTRClusterClosureDimension MTRClusterColorControl MTRClusterCommissionerControl MTRClusterCommissioningProxy
MTRClusterCommodityMetering MTRClusterCommodityPrice MTRClusterCommodityTariff MTRClusterContentAppObserver
MTRClusterContentControl MTRClusterContentLauncher MTRClusterDescriptor MTRClusterDeviceEnergyManagement
MTRClusterDeviceEnergyManagementMode MTRClusterDiagnosticLogs MTRClusterDishwasherAlarm MTRClusterDishwasherMode
MTRClusterDoorLock MTRClusterDynamicLighting MTRClusterEcosystemInformation MTRClusterElectricalAlarm
MTRClusterElectricalDistribution MTRClusterElectricalEnergyMeasurement MTRClusterElectricalGridConditions
MTRClusterElectricalMeasurement MTRClusterElectricalPowerMeasurement MTRClusterElectricalProtectionAlarm
MTRClusterEnergyEVSE MTRClusterEnergyEVSEMode MTRClusterEnergyPreference MTRClusterEthernetNetworkDiagnostics
MTRClusterFanControl MTRClusterFixedLabel MTRClusterFlowMeasurement MTRClusterFormaldehydeConcentrationMeasurement
MTRClusterGeneralCommissioning MTRClusterGeneralDiagnostics MTRClusterGroupKeyManagement MTRClusterGroupcast
MTRClusterGroups MTRClusterHEPAFilterMonitoring MTRClusterHumidistat MTRClusterICDManagement MTRClusterIdentify
MTRClusterIlluminanceMeasurement MTRClusterJointFabricAdministrator MTRClusterJointFabricDatastore
MTRClusterKeypadInput MTRClusterLaundryDryerControls MTRClusterLaundryWasherControls MTRClusterLaundryWasherMode
MTRClusterLevelControl MTRClusterLocalizationConfiguration MTRClusterLowPower MTRClusterMediaFileManagement
MTRClusterMediaInput MTRClusterMediaPlayback MTRClusterMessages MTRClusterMeterIdentification
MTRClusterMicrowaveOvenControl MTRClusterMicrowaveOvenMode MTRClusterModeSelect MTRClusterNetworkCommissioning
MTRClusterNetworkIdentityManagement MTRClusterNitrogenDioxideConcentrationMeasurement
MTRClusterOTASoftwareUpdateProvider MTRClusterOTASoftwareUpdateRequestor MTRClusterOccupancySensing MTRClusterOnOff
MTRClusterOnOffSwitchConfiguration MTRClusterOperationalCredentials MTRClusterOperationalState
MTRClusterOtaSoftwareUpdateProvider MTRClusterOtaSoftwareUpdateRequestor MTRClusterOvenCavityOperationalState
MTRClusterOvenMode MTRClusterOzoneConcentrationMeasurement MTRClusterPM10ConcentrationMeasurement
MTRClusterPM1ConcentrationMeasurement MTRClusterPM25ConcentrationMeasurement MTRClusterPowerSource
MTRClusterPowerSourceConfiguration MTRClusterPowerTopology MTRClusterPressureMeasurement MTRClusterProximityRanging
MTRClusterPulseWidthModulation MTRClusterPumpConfigurationAndControl MTRClusterPushAVStreamTransport
MTRClusterRVCCleanMode MTRClusterRVCOperationalState MTRClusterRVCRunMode MTRClusterRadonConcentrationMeasurement
MTRClusterRefrigeratorAlarm MTRClusterRefrigeratorAndTemperatureControlledCabinetMode
MTRClusterRelativeHumidityMeasurement MTRClusterSampleMEI MTRClusterScenesManagement MTRClusterServiceArea
MTRClusterSmokeCOAlarm MTRClusterSmokeConcentrationMeasurement MTRClusterSoftwareDiagnostics MTRClusterSoilMeasurement
MTRClusterSwitch MTRClusterTLSCertificateManagement MTRClusterTLSClientManagement MTRClusterTargetNavigator
MTRClusterTemperatureControl MTRClusterTemperatureControlledCabinetTopology MTRClusterTemperatureMeasurement
MTRClusterTestCluster MTRClusterTestHiddenManufacturerSpecific MTRClusterThermostat
MTRClusterThermostatUserInterfaceConfiguration MTRClusterThreadBorderRouterManagement
MTRClusterThreadNetworkDiagnostics MTRClusterThreadNetworkDirectory MTRClusterTimeFormatLocalization
MTRClusterTimeSynchronization MTRClusterTotalVolatileOrganicCompoundsConcentrationMeasurement
MTRClusterUnitLocalization MTRClusterUnitTesting MTRClusterUserLabel MTRClusterValveConfigurationAndControl
MTRClusterWakeOnLAN MTRClusterWakeOnLan MTRClusterWaterHeaterManagement MTRClusterWaterHeaterMode
MTRClusterWaterTankLevelMonitoring MTRClusterWebRTCTransportProvider MTRClusterWebRTCTransportRequestor
MTRClusterWiFiNetworkDiagnostics MTRClusterWiFiNetworkManagement MTRClusterWindowCovering MTRClusterZoneManagement
"""

#endif
