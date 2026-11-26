// SDK coverage, round 30 (P27): public API of the SDK not yet referenced by any check (~/scratch/r30/apisurf.py),
// area: Services. Each check asserts what Apple's simulator answers (ref-mac.sh --only).
// Families of plain value classes (Intents intents / responses / resolution results / data classes, ClockKit
// templates, CarPlay templates, SensorKit samples...) are table-driven: each class is looked up by name (the tables run
// on every platform that has the framework, and a class's availability differs per platform), constructed, used and
// asserted (secure-coding round trip, copy, description); the checks report the counts.
import Foundation
#if canImport(Intents)
import Intents
#endif
#if canImport(CoreLocation)
import CoreLocation
#endif
#if canImport(Contacts)
import Contacts
#endif
#if canImport(HealthKit)
import HealthKit
#endif
#if canImport(MusicKit)
import MusicKit
#endif
#if canImport(ClockKit) && os(watchOS)
import ClockKit
import UIKit
#endif
#if canImport(SensorKit) && os(iOS)
import SensorKit
#endif
#if canImport(CarPlay) && os(iOS)
import CarPlay
import CoreMedia
import MapKit
#endif

// MARK: helpers

/// secure keyed archive of `o` decoded back as its own class (nil: the archive did not decode)
func p27sRoundTrip(_ o: NSObject) throws -> NSObject? {
    let d = try NSKeyedArchiver.archivedData(withRootObject: o, requiringSecureCoding: true)
    let u = try NSKeyedUnarchiver(forReadingFrom: d)
    u.requiresSecureCoding = true
    defer { u.finishDecoding() }
    return u.decodeObject(of: [type(of: o)], forKey: NSKeyedArchiveRootObjectKey) as? NSObject
}
/// the archive bytes of `o` (two objects that archive to the same bytes hold the same values)
func p27sBytes(_ o: NSObject) -> Data? { try? NSKeyedArchiver.archivedData(withRootObject: o, requiringSecureCoding: true) }
/// an NSSecureCoding class instantiated through init(coder:) from an empty keyed archive (every property unset): how
/// the table checks build value classes whose designated initializers differ per class
func p27sFromEmptyCoder(_ cls: AnyClass) throws -> NSObject? {
    let a = NSKeyedArchiver(requiringSecureCoding: true); a.finishEncoding()
    let u = try NSKeyedUnarchiver(forReadingFrom: a.encodedData)
    u.requiresSecureCoding = true
    defer { u.finishDecoding() }
    guard let t = cls as? NSCoding.Type else { return nil }
    return t.init(coder: u) as? NSObject
}
/// [alloc] initWithCode:code userActivity:nil] for the INIntentResponse subclasses (each has its own Code enum)
func p27sInitCode(_ cls: AnyClass, _ code: Int) -> NSObject? {
    let sa = NSSelectorFromString("alloc"), si = NSSelectorFromString("initWithCode:userActivity:")
    guard let ma = class_getClassMethod(cls, sa), let mi = class_getInstanceMethod(cls, si) else { return nil }
    typealias A = @convention(c) (AnyClass, Selector) -> UnsafeMutableRawPointer?
    typealias I = @convention(c) (UnsafeMutableRawPointer, Selector, Int, NSUserActivity?) -> Unmanaged<NSObject>?
    guard let p = unsafeBitCast(method_getImplementation(ma), to: A.self)(cls, sa) else { return nil }
    return unsafeBitCast(method_getImplementation(mi), to: I.self)(p, si, code, nil)?.takeRetainedValue()
}
final class P27sBox<V>: @unchecked Sendable { let l = NSLock(); var v: V? }
/// `body`'s answer, or nil when it does not answer in `secs`
func p27sWithin<T: Sendable>(_ secs: Double, _ body: @escaping @Sendable () async throws -> T) async throws -> T? {
    let b = P27sBox<Result<T, Error>>()
    let t = Task { let r: Result<T, Error>; do { r = .success(try await body()) } catch { r = .failure(error) }; b.l.withLock { b.v = r } }
    let end = Date().addingTimeInterval(secs)
    while Date() < end { if let r = b.l.withLock({ b.v }) { return try r.get() }; try await Task.sleep(for: .milliseconds(30)) }
    t.cancel(); return nil
}
/// an async call's answer as text: "ok <value>", the error ("<Type>: <description>"), or "no answer in N s"
func p27sAnswer(_ secs: Double, _ body: @escaping @Sendable () async throws -> String) async -> String {
    do { return try await p27sWithin(secs, body).map { "ok " + $0 } ?? "no answer in \(Int(secs)) s" }
    catch { return "\(type(of: error)): \(String(describing: error).prefix(60))" }
}
/// "name" list of the first few failures
func p27sFirst(_ a: [String], _ n: Int = 6) -> String { a.isEmpty ? "" : " [" + a.prefix(n).joined(separator: " ") + (a.count > n ? " +\(a.count - n)" : "") + "]" }

#if canImport(Intents)
let p27sIntents = "INActivateCarSignalIntent INAddMediaIntent INAddTasksIntent INAnswerCallIntent INAppendToNoteIntent INBookRestaurantReservationIntent INCancelRideIntent INCancelWorkoutIntent INCreateNoteIntent INCreateTaskListIntent INDeleteTasksIntent INEditMessageIntent INEndWorkoutIntent INGetAvailableRestaurantReservationBookingDefaultsIntent INGetAvailableRestaurantReservationBookingsIntent INGetCarLockStatusIntent INGetCarPowerLevelStatusIntent INGetReservationDetailsIntent INGetRestaurantGuestIntent INGetRideStatusIntent INGetUserCurrentRestaurantReservationBookingsIntent INGetVisualCodeIntent INHangUpCallIntent INListCarsIntent INListRideOptionsIntent INPauseWorkoutIntent INPayBillIntent INRequestPaymentIntent INRequestRideIntent INResumeWorkoutIntent INSaveProfileInCarIntent INSearchCallHistoryIntent INSearchForAccountsIntent INSearchForBillsIntent INSearchForMediaIntent INSearchForMessagesIntent INSearchForNotebookItemsIntent INSearchForPhotosIntent INSendPaymentIntent INSendRideFeedbackIntent INSetAudioSourceInCarIntent INSetCarLockStatusIntent INSetClimateSettingsInCarIntent INSetDefrosterSettingsInCarIntent INSetMessageAttributeIntent INSetProfileInCarIntent INSetRadioStationIntent INSetSeatSettingsInCarIntent INSetTaskAttributeIntent INShareFocusStatusIntent INSnoozeTasksIntent INStartAudioCallIntent INStartCallIntent INStartPhotoPlaybackIntent INStartVideoCallIntent INStartWorkoutIntent INTransferMoneyIntent INUnsendMessagesIntent INUpdateMediaAffinityIntent".split(separator: " ").map(String.init)
let p27sResolutionResults = "INAccountTypeResolutionResult INAddMediaMediaDestinationResolutionResult INAddMediaMediaItemResolutionResult INAddTasksTargetTaskListResolutionResult INAddTasksTemporalEventTriggerResolutionResult INBalanceTypeResolutionResult INBillPayeeResolutionResult INBillTypeResolutionResult INBooleanResolutionResult INCallCapabilityResolutionResult INCallDestinationTypeResolutionResult INCallRecordResolutionResult INCallRecordTypeOptionsResolutionResult INCallRecordTypeResolutionResult INCarAirCirculationModeResolutionResult INCarAudioSourceResolutionResult INCarDefrosterResolutionResult INCarSeatResolutionResult INCarSignalOptionsResolutionResult INCurrencyAmountResolutionResult INDateComponentsRangeResolutionResult INDateComponentsResolutionResult INDateSearchTypeResolutionResult INDeleteTasksTaskListResolutionResult INDeleteTasksTaskResolutionResult INDoubleResolutionResult INEnergyResolutionResult INEnumResolutionResult INFileResolutionResult INIntegerResolutionResult INIntentResolutionResult INLengthResolutionResult INLocationSearchTypeResolutionResult INMassResolutionResult INMediaAffinityTypeResolutionResult INMediaDestinationResolutionResult INMediaItemResolutionResult INMessageAttributeOptionsResolutionResult INMessageAttributeResolutionResult INNoteContentResolutionResult INNoteContentTypeResolutionResult INNoteResolutionResult INNotebookItemTypeResolutionResult INObjectResolutionResult INOutgoingMessageTypeResolutionResult INPaymentAccountResolutionResult INPaymentAmountResolutionResult INPaymentMethodResolutionResult INPaymentStatusResolutionResult INPersonResolutionResult INPlacemarkResolutionResult INPlayMediaMediaItemResolutionResult INPlayMediaPlaybackSpeedResolutionResult INPlaybackQueueLocationResolutionResult INPlaybackRepeatModeResolutionResult INRadioTypeResolutionResult INRelativeReferenceResolutionResult INRelativeSettingResolutionResult INRequestPaymentCurrencyAmountResolutionResult INRequestPaymentPayerResolutionResult INRestaurantGuestResolutionResult INRestaurantResolutionResult INSearchForMediaMediaItemResolutionResult INSendMessageRecipientResolutionResult INSendPaymentCurrencyAmountResolutionResult INSendPaymentPayeeResolutionResult INSetTaskAttributeTemporalEventTriggerResolutionResult INSnoozeTasksTaskResolutionResult INSpatialEventTriggerResolutionResult INSpeakableStringResolutionResult INSpeedResolutionResult INStartCallCallCapabilityResolutionResult INStartCallCallRecordToCallBackResolutionResult INStartCallContactResolutionResult INStringResolutionResult INTaskListResolutionResult INTaskPriorityResolutionResult INTaskResolutionResult INTaskStatusResolutionResult INTemperatureResolutionResult INTemporalEventTriggerResolutionResult INTemporalEventTriggerTypeOptionsResolutionResult INTimeIntervalResolutionResult INURLResolutionResult INUpdateMediaAffinityMediaItemResolutionResult INVisualCodeTypeResolutionResult INVolumeResolutionResult INWorkoutGoalUnitTypeResolutionResult INWorkoutLocationTypeResolutionResult".split(separator: " ").map(String.init)
/// the NSSecureCoding data classes (and abstract bases) of Intents (not INParameter: its initWithCoder: faults on an empty
/// archive; p27-values builds it with its initializer)
let p27sIntentData = "INAirline INAirport INAirportGate INBalanceAmount INBillDetails INBillPayee INBoatReservation INBoatTrip INBusReservation INBusTrip INCallGroup INCallRecord INCallRecordFilter INCar INCarHeadUnit INCurrencyAmount INDailyRoutineRelevanceProvider INDateComponentsRange INDefaultCardTemplate INFile INFlight INFlightReservation INFocusStatus INImageNoteContent INIntentDonationMetadata INLocationRelevanceProvider INLodgingReservation INMediaDestination INMediaSearch INMediaUserContext INMessage INMessageLinkMetadata INMessageReaction INNote INNoteContent INObject INPaymentAccount INPaymentAmount INPaymentMethod INPaymentRecord INPriceRange INRecurrenceRule INRelevanceProvider INRentalCar INRentalCarReservation INReservation INReservationAction INRestaurant INRestaurantGuest INRestaurantGuestDisplayPreferences INRestaurantOffer INRestaurantReservation INRestaurantReservationBooking INRestaurantReservationUserBooking INRideCompletionStatus INRideDriver INRideFareLineItem INRideOption INRidePartySizeOption INRideStatus INRideVehicle INSeat INSendMessageIntentDonationMetadata INSpatialEventTrigger INSticker INTask INTaskList INTemporalEventTrigger INTermsAndConditions INTextNoteContent INTicketedEvent INTicketedEventReservation INTrainReservation INTrainTrip INUserContext".split(separator: " ").map(String.init)
#endif

extension Registry {
    static var p27svc: [Check] {
        var c: [Check] = []
#if canImport(Intents)
        // every INIntent subclass: init, a suggested invocation phrase, copy and a secure-coding round trip that keeps
        // the class, the phrase and the archive bytes
        c.append(check("Intents", "p27-intent-classes") {
            var have = 0, ok = 0, bad: [String] = [], absent: [String] = []
            for n in p27sIntents {
                guard let cls = NSClassFromString(n) as? INIntent.Type else { absent.append(n); continue }
                have += 1
                let i = cls.init()
                i.suggestedInvocationPhrase = "p27 \(n)"
                let cp = i.copy() as? INIntent
                guard let back = try p27sRoundTrip(i) as? INIntent, type(of: back) == cls else { bad.append(n + ":decode"); continue }
                guard type(of: cp ?? i) == cls else { bad.append(n + ":copy"); continue }
                guard back.suggestedInvocationPhrase == "p27 \(n)" else { bad.append(n + ":phrase"); continue }
                guard p27sBytes(back) == p27sBytes(i) else { bad.append(n + ":bytes"); continue }
                guard !i.description.isEmpty else { bad.append(n + ":description"); continue }
                ok += 1
            }
            // Apple's simulator: the restaurant-booking intents (iOS 11 API) encode only some of their state: two do not
            // decode as secure coding, five drop the suggested phrase
            let apple: Set<String> = ["INBookRestaurantReservationIntent:decode", "INGetAvailableRestaurantReservationBookingsIntent:decode",
                                      "INCancelRideIntent:phrase", "INGetAvailableRestaurantReservationBookingDefaultsIntent:phrase",
                                      "INGetRestaurantGuestIntent:phrase", "INGetUserCurrentRestaurantReservationBookingsIntent:phrase", "INSendRideFeedbackIntent:phrase"]
            let unexpected = bad.filter { !apple.contains($0) }
            try expect(have > 0 && unexpected.isEmpty && ok + bad.count == have, "\(ok)/\(have) round trip, not as Apple's\(p27sFirst(unexpected, 20))")
            return "\(ok)/\(have) intents round trip, \(bad.count) as Apple's do not (absent \(absent.count))\(p27sFirst(absent, 3))"
        })
        // every INIntentResponse subclass: initWithCode:1 (each Code enum's 1) userActivity:nil, code read back,
        // copy and secure-coding round trip
        c.append(check("Intents", "p27-intent-responses") {
            var have = 0, ok = 0, bad: [String] = [], absent: [String] = []
            for i in p27sIntents {
                let n = i + "Response"
                guard let cls = NSClassFromString(n), cls is INIntentResponse.Type else { absent.append(n); continue }
                have += 1
                guard let r = p27sInitCode(cls, 1) as? INIntentResponse, type(of: r) == cls,
                      (r.value(forKey: "code") as? Int) == 1,
                      let back = try p27sRoundTrip(r), type(of: back) == cls, (back.value(forKey: "code") as? Int) == 1,
                      type(of: r.copy() as AnyObject) == cls, r.userActivity == nil
                else { bad.append(n); continue }
                ok += 1
            }
            try expect(have > 0 && bad.isEmpty, "\(ok)/\(have)\(p27sFirst(bad))")
            return "\(ok)/\(have) responses code 1 round trip (absent \(absent.count))\(p27sFirst(absent, 3))"
        })
        // every INIntentResolutionResult subclass: needsValue / notRequired / unsupported / unsupported(forReason: 1)
        // come back as instances of the subclass itself
        c.append(check("Intents", "p27-resolution-results") {
            var have = 0, ok = 0, bad: [String] = [], absent: [String] = []
            for n in p27sResolutionResults {
                guard let cls = NSClassFromString(n) as? INIntentResolutionResult.Type else { absent.append(n); continue }
                have += 1
                let rs: [INIntentResolutionResult] = [cls.needsValue(), cls.notRequired(), cls.unsupported()]
                guard rs.allSatisfy({ type(of: $0) == cls && !$0.description.isEmpty }) else { bad.append(n); continue }
                ok += 1
            }
            // typed successes carry their value
            var typed = 0
            if let b = INBooleanResolutionResult.success(with: true).description as String?, !b.isEmpty { typed += 1 }
            let d = INDoubleResolutionResult.confirmationRequired(with: 2.5)
            if type(of: d) == INDoubleResolutionResult.self { typed += 1 }
            let iv = INIntegerResolutionResult.success(with: 7)
            if type(of: iv) == INIntegerResolutionResult.self { typed += 1 }
            #if !os(tvOS)
            let s = INStringResolutionResult.disambiguation(with: ["a", "b"])
            if type(of: s) == INStringResolutionResult.self { typed += 1 }
            let u = INURLResolutionResult.success(with: URL(string: "https://example.com")!)
            if type(of: u) == INURLResolutionResult.self { typed += 1 }
            #else
            typed += 2  // INStringResolutionResult / INURLResolutionResult: unavailable on tvOS (the table above covers them)
            #endif
            try expect(have > 0 && bad.isEmpty && typed == 5, "\(ok)/\(have) typed \(typed)/5\(p27sFirst(bad))")
            return "\(ok)/\(have) resolution result classes, typed 5/5 (absent \(absent.count))\(p27sFirst(absent, 3))"
        })
        // the data classes: built through init(coder:) from an empty archive, then copy (when NSCopying) and a
        // secure-coding round trip with the same archive bytes
        c.append(check("Intents", "p27-data-classes") {
            var have = 0, ok = 0, nilInit: [String] = [], bad: [String] = [], absent: [String] = []
            for n in p27sIntentData {
                guard let cls = NSClassFromString(n) else { absent.append(n); continue }
                have += 1
                NSLog("p27s data class \(n)")
                guard let o = try p27sFromEmptyCoder(cls) else { nilInit.append(n); continue }
                let cpOK = !(o is NSCopying) || type(of: (o as! NSCopying).copy(with: nil) as AnyObject) == cls
                guard type(of: o) == cls, cpOK, let back = try p27sRoundTrip(o), type(of: back) == cls,
                      p27sBytes(back) == p27sBytes(o), !o.description.isEmpty
                else { bad.append(n); continue }
                ok += 1
            }
            try expect(have > 0 && bad.isEmpty, "\(ok)/\(have) nil-init \(nilInit.count)\(p27sFirst(bad))")
            return "\(ok)/\(have) data classes round trip, nil from empty coder \(nilInit.count)\(p27sFirst(nilInit, 8)) (absent \(absent.count))\(p27sFirst(absent, 3))"
        })
#endif
        c += p27sIntentValues + p27sHealth + p27sMusic + p27sCarPlay + p27sClockKit + p27sSensorKit
        return c
    }
}

// MARK: Intents values built with their own initializers (iOS: some are unavailable elsewhere)

extension Registry {
    static var p27sIntentValues: [Check] {
        var c: [Check] = []
#if canImport(Intents) && os(iOS)
        c.append(check("Intents", "p27-values") {
            var n = 0
            func ok(_ cond: Bool, _ what: String) throws { try expect(cond, what); n += 1 }
            let amt = INCurrencyAmount(amount: NSDecimalNumber(string: "12.50"), currencyCode: "EUR")
            try ok(amt.amount == NSDecimalNumber(string: "12.5") && amt.currencyCode == "EUR", "currency \(amt)")
            let rr = INRecurrenceRule(interval: 2, frequency: .weekly)
            let range = INDateComponentsRange(start: DateComponents(year: 2026, month: 11, day: 26, hour: 9), end: DateComponents(year: 2026, month: 11, day: 26, hour: 10), recurrenceRule: rr)
            try ok(range.recurrenceRule?.interval == 2 && range.recurrenceRule?.frequency == .weekly && range.endDateComponents?.hour == 10, "range \(range)")
            let text = INTextNoteContent(text: "milk, eggs")
            let note = INNote(title: INSpeakableString(spokenPhrase: "Groceries"), contents: [text], groupName: nil, createdDateComponents: nil, modifiedDateComponents: nil, identifier: "n1")
            try ok((note.contents.first as? INTextNoteContent)?.text == "milk, eggs" && note.title.spokenPhrase == "Groceries", "note \(note)")
            let loc = CLLocation(latitude: 37.33, longitude: -122.03)
            let place = CLPlacemark(location: loc, name: "Office", postalAddress: nil)
            let spatial = INSpatialEventTrigger(placemark: place, event: .arrive)
            let temporal = INTemporalEventTrigger(dateComponentsRange: range)
            let task = INTask(title: INSpeakableString(spokenPhrase: "Buy milk"), status: .notCompleted, taskType: .completable, spatialEventTrigger: spatial, temporalEventTrigger: temporal, createdDateComponents: nil, modifiedDateComponents: nil, identifier: "t1")
            try ok(task.spatialEventTrigger?.event == .arrive && task.temporalEventTrigger?.dateComponentsRange.startDateComponents?.hour == 9 && task.status == .notCompleted, "task \(task)")
            let list = INTaskList(title: INSpeakableString(spokenPhrase: "Errands"), tasks: [task], groupName: nil, createdDateComponents: nil, modifiedDateComponents: nil, identifier: "l1")
            try ok(list.tasks.first?.identifier == "t1", "task list")
            let file = INFile(data: Data("hi".utf8), filename: "a.txt", typeIdentifier: "public.plain-text")
            try ok(file.data == Data("hi".utf8) && file.filename == "a.txt" && file.typeIdentifier == "public.plain-text", "file \(file)")
            let att = INSendMessageAttachment(audioMessageFile: file)
            try ok(att.audioMessageFile?.filename == "a.txt", "attachment")
            try ok(INFocusStatus(isFocused: true).isFocused == true, "focus status")
            let airline = INAirline(name: "Example Air", iataCode: "EX", icaoCode: "EXA")
            let sfo = INAirport(name: "San Francisco", iataCode: "SFO", icaoCode: "KSFO"), jfk = INAirport(name: "Kennedy", iataCode: "JFK", icaoCode: "KJFK")
            let flight = INFlight(airline: airline, flightNumber: "12", boardingTime: range, flightDuration: range, departureAirportGate: INAirportGate(airport: sfo, terminal: "2", gate: "D4"), arrivalAirportGate: INAirportGate(airport: jfk, terminal: "4", gate: "B1"))
            try ok(flight.departureAirportGate.airport.iataCode == "SFO" && flight.arrivalAirportGate.gate == "B1" && flight.airline.icaoCode == "EXA", "flight")
            let seat = INSeat(seatSection: nil, seatRow: "14", seatNumber: "C", seatingType: "economy")
            try ok(seat.seatRow == "14", "seat")
            let price = INPriceRange(firstPrice: 20, secondPrice: 10, currencyCode: "USD")
            try ok(price.minimumPrice == 10 && price.maximumPrice == 20, "price range")
            let rest = INRestaurant(location: loc, name: "Cafe", vendorIdentifier: "v", restaurantIdentifier: "r")
            try ok(rest.name == "Cafe" && rest.restaurantIdentifier == "r", "restaurant")
            let me = INPerson(personHandle: INPersonHandle(value: "a@example.com", type: .emailAddress), nameComponents: nil, displayName: "A", image: nil, contactIdentifier: nil, customIdentifier: nil)
            let msg = INMessage(identifier: "m1", conversationIdentifier: "c1", content: "hello", dateSent: Date(timeIntervalSince1970: 0), sender: me, recipients: [me], groupName: nil, messageType: .text)
            try ok(msg.content == "hello" && msg.messageType == .text, "message")
            let sticker = INSticker(type: .emoji, emoji: "👍")
            try ok(sticker.emoji == "👍", "sticker")
            let dest = INMediaDestination.playlist("Road trip"), lib = INMediaDestination.library
            if case .playlist(let name) = dest, case .library = lib { try ok(name == "Road trip", "media destination") } else { throw Fail("media destination \(dest)") }
            let search = INMediaSearch(mediaType: .song, sortOrder: .newest, mediaName: "Song", artistName: "Artist", albumName: nil, genreNames: ["pop"], moodNames: nil, releaseDate: nil, reference: .currentlyPlaying, mediaIdentifier: nil)
            try ok(search.mediaType == .song && search.genreNames == ["pop"], "media search")
            let car = INCar(carIdentifier: "car1", displayName: "Car", year: "2026", make: "Make", model: "Model", color: nil, headUnit: INCar.HeadUnit(bluetoothIdentifier: "bt", iAP2Identifier: nil), supportedChargingConnectors: [.ccs1])
            try ok(car.supportedChargingConnectors == [.ccs1] && car.headUnit?.bluetoothIdentifier == "bt", "car")
            let group = INCallGroup(groupName: "Team", groupId: "g1")
            try ok(group.groupId == "g1", "call group")
            let card = INDefaultCardTemplate(title: "Card"); card.subtitle = "sub"
            try ok(card.subtitle == "sub", "card template")
            let param = INParameter(for: INSendMessageIntent.self, keyPath: "content")
            try ok(param.parameterKeyPath == "content" && param.parameterClass == INSendMessageIntent.self, "parameter")
            let routine = INDailyRoutineRelevanceProvider(situation: .morning)
            try ok(routine.situation == .morning, "daily routine relevance")
            let region = CLCircularRegion(center: loc.coordinate, radius: 100, identifier: "r")
            try ok(INLocationRelevanceProvider(region: region).region.identifier == "r", "location relevance")
            let meta = INSendMessageIntentDonationMetadata(); meta.mentionsCurrentUser = true; meta.recipientCount = 3
            try ok(meta.mentionsCurrentUser && meta.recipientCount == 3, "donation metadata")
            let ctx = INMediaUserContext(); ctx.numberOfLibraryItems = 42; ctx.subscriptionStatus = .subscribed
            try ok(ctx.numberOfLibraryItems == 42, "media user context")
            // the round trip keeps the values
            let back = try p27sRoundTrip(task) as? INTask
            try ok(back?.identifier == "t1" && back?.spatialEventTrigger?.placemark.name == "Office", "task round trip \(String(describing: back))")
            // services: INExtension's default handler, INVocabulary, INUpcomingMediaManager
            let handler = INExtension().handler(for: INStartCallIntent())
            INUpcomingMediaManager.shared.setPredictionMode(.onlyPredictSuggestedIntents, for: .music)
            INVocabulary.shared().removeAllVocabularyStrings()
            return "\(n) values set/read back; INExtension default handler \(handler.map { "\(type(of: $0))" } ?? "nil")"
        })
#endif
        return c
    }
}

// MARK: HealthKit

#if canImport(HealthKit) && !os(tvOS)
/// "ok <value>" or "HK <code>" of a HealthKit call
func p27sHK(_ body: () async throws -> String) async -> String {
    do { return "ok " + (try await body()) } catch { let n = error as NSError; return n.domain == HKErrorDomain ? "HK \(n.code)" : "\(n.domain) \(n.code)" }
}
/// a typed async query run against the store: the count of what it returned or its error
func p27sRun<Q: HKAsyncQuery>(_ q: Q, _ st: HKHealthStore, _ count: @escaping (Q.Output) -> Int) async -> String {
    await p27sHK { "\(count(try await q.result(for: st)))" }
}
/// HealthKit's result-only classes (no public initializer): built from an empty archive as the table checks do
let p27sHKCoded = "HKElectrocardiogram HKHeartbeatSeriesSample HKWorkoutRoute HKDeletedObject HKCDADocumentSample HKClinicalRecord HKFHIRResource HKVerifiableClinicalRecord HKVerifiableClinicalRecordSubject HKMedicationConcept HKHealthConceptIdentifier HKUserAnnotatedMedication HKMedicationDoseEvent HKScoredAssessment HKWorkoutEffortRelationship HKAttachment HKSourceRevision HKQueryAnchor HKBiologicalSexObject HKBloodTypeObject HKFitzpatrickSkinTypeObject HKWheelchairUseObject HKActivityMoveModeObject HKElectrocardiogramVoltageMeasurement HKStatistics HKStatisticsCollection HKLiveWorkoutZoneUpdate HKObject HKSample HKSeriesSample".split(separator: " ").map(String.init)
#endif

extension Registry {
    static var p27sHealth: [Check] {
        var c: [Check] = []
#if canImport(HealthKit) && !os(tvOS)
        // the sample model: every kind of sample / object built locally, its subclass and values read back, secure coding
        c.append(check("HealthKit", "p27-model-samples") {
            var n = 0
            func ok(_ cond: Bool, _ what: @autoclosure () -> String) throws { try expect(cond, what()); n += 1 }
            let t0 = Date(timeIntervalSince1970: 1_790_000_000), t1 = t0.addingTimeInterval(600)
            let steps = HKQuantitySample(type: HKQuantityType(.stepCount), quantity: HKQuantity(unit: .count(), doubleValue: 50), start: t0, end: t1)
            let hr = HKQuantitySample(type: HKQuantityType(.heartRate), quantity: HKQuantity(unit: .count().unitDivided(by: .minute()), doubleValue: 70), start: t0, end: t0)
            // a cumulative type's sample is an HKCumulativeQuantitySample, a discrete one's an HKDiscreteQuantitySample
            try ok(steps is HKCumulativeQuantitySample && hr is HKDiscreteQuantitySample, "subclasses \(type(of: steps)) \(type(of: hr))")
            try ok((hr as? HKDiscreteQuantitySample)?.mostRecentQuantity.doubleValue(for: .count().unitDivided(by: .minute())) == 70, "discrete most recent")
            try ok((steps as? HKCumulativeQuantitySample)?.sumQuantity.doubleValue(for: .count()) == 50, "cumulative sum")
            let mind = HKCategorySample(type: HKCategoryType(.mindfulSession), value: HKCategoryValue.notApplicable.rawValue, start: t0, end: t1)
            let asSample: HKSample = mind, asObject: HKObject = mind
            try ok(asSample.endDate == t1 && asObject.uuid != steps.uuid && mind.categoryType.identifier == HKCategoryTypeIdentifier.mindfulSession.rawValue, "category sample")
            let kcal = HKQuantitySample(type: HKQuantityType(.dietaryEnergyConsumed), quantity: HKQuantity(unit: .kilocalorie(), doubleValue: 200), start: t0, end: t0)
            let food = HKCorrelation(type: HKCorrelationType(.food), start: t0, end: t0, objects: [kcal])
            try ok(food.objects(for: HKQuantityType(.dietaryEnergyConsumed)).count == 1, "correlation")
            let dev = HKDevice(name: "Band", manufacturer: "Example", model: "B1", hardwareVersion: "1", firmwareVersion: "2", softwareVersion: "3", localIdentifier: "loc", udiDeviceIdentifier: nil)
            try ok(dev.model == "B1" && HKDevice.local().name != nil, "device \(dev)")
            let src = HKSource.default()
            try ok(!src.bundleIdentifier.isEmpty, "default source \(src.bundleIdentifier)")
            let rev = HKSourceRevision(source: src, version: "1.0", productType: "iPhone18,3", operatingSystemVersion: OperatingSystemVersion(majorVersion: 27, minorVersion: 2, patchVersion: 0))
            try ok(rev.operatingSystemVersion.majorVersion == 27 && rev.productType == "iPhone18,3", "source revision")
            // a pause is an instant (a duration raises NSInvalidArgumentException), a segment has one
            let pause = HKWorkoutEvent(type: .pause, dateInterval: DateInterval(start: t0, duration: 0), metadata: nil)
            let seg = HKWorkoutEvent(type: .segment, dateInterval: DateInterval(start: t0, duration: 30), metadata: nil)
            try ok(pause.type == .pause && seg.dateInterval.duration == 30, "workout event")
            let cfg = HKWorkoutConfiguration(); cfg.activityType = .running
            let act = HKWorkoutActivity(workoutConfiguration: cfg, start: t0, end: t1, metadata: nil)
            try ok(act.workoutConfiguration.activityType == .running && act.endDate == t1, "workout activity")
            let wk = HKWorkout(activityType: .running, start: t0, end: t1)
            try ok(wk.workoutActivityType == .running && wk.duration == 600, "workout \(wk.duration)")
            // hearing: tests -> points -> audiogram
            let test = try HKAudiogramSensitivityTest(sensitivity: HKQuantity(unit: .decibelHearingLevel(), doubleValue: 20), type: .air, masked: false, side: .left, clampingRange: try HKAudiogramSensitivityPointClampingRange(lowerBound: 0, upperBound: 120))
            let point = try HKAudiogramSensitivityPoint(frequency: HKQuantity(unit: .hertz(), doubleValue: 1000), tests: [test])
            let gram = HKAudiogramSample(sensitivityPoints: [point], start: t0, end: t1, device: nil, metadata: nil)
            try ok(gram.sensitivityPoints.first?.tests.first?.side == .left && test.clampingRange?.upperBound?.doubleValue(for: .decibelHearingLevel()) == 120, "audiogram")
            // mental health
            let som = HKStateOfMind(date: t0, kind: .momentaryEmotion, valence: 0.6, labels: [.happy], associations: [.work])
            try ok(som.valenceClassification == .pleasant && som.labels == [.happy] && som.associations == [.work], "state of mind \(som.valenceClassification.rawValue)")
            let gad = HKGAD7Assessment(date: t0, answers: Array(repeating: .severalDays, count: 7))
            let phq = HKPHQ9Assessment(date: t0, answers: Array(repeating: .moreThanHalfTheDays, count: 9))
            let scored: [HKScoredAssessment] = [gad, phq]
            try ok(gad.score == 7 && gad.risk == .mild && phq.score == 18 && phq.risk == .moderatelySevere && scored.count == 2, "assessments gad \(gad.score) \(gad.risk.rawValue) phq \(phq.score) \(phq.risk.rawValue)")
            // vision prescriptions
            let mm = HKUnit.meterUnit(with: .milli), diopter = HKUnit.diopter(), deg = HKUnit.degreeAngle(), prd = HKUnit.prismDiopter()
            let prism = HKVisionPrism(amount: HKQuantity(unit: prd, doubleValue: 1), angle: HKQuantity(unit: deg, doubleValue: 90), eye: .left)
            let glass = HKGlassesLensSpecification(sphere: HKQuantity(unit: diopter, doubleValue: -2), cylinder: nil, axis: nil, addPower: nil, vertexDistance: nil, prism: prism, farPupillaryDistance: HKQuantity(unit: mm, doubleValue: 31), nearPupillaryDistance: nil)
            let gp = HKGlassesPrescription(rightEyeSpecification: nil, leftEyeSpecification: glass, dateIssued: t0, expirationDate: nil, device: nil, metadata: nil)
            try ok(gp.leftEye?.prism?.eye == .left && gp.prescriptionType == .glasses, "glasses")
            let lens = HKContactsLensSpecification(sphere: HKQuantity(unit: diopter, doubleValue: -2.25), cylinder: nil, axis: nil, addPower: nil, baseCurve: HKQuantity(unit: mm, doubleValue: 8.6), diameter: HKQuantity(unit: mm, doubleValue: 14.2))
            let cp = HKContactsPrescription(rightEyeSpecification: lens, leftEyeSpecification: nil, brand: "Brand", dateIssued: t0, expirationDate: nil, device: nil, metadata: nil)
            try ok(cp.brand == "Brand" && cp.rightEye?.diameter?.doubleValue(for: mm) == 14.2, "contacts")
            let lensBase: HKLensSpecification = lens
            try ok(lensBase.sphere.doubleValue(for: diopter) == -2.25, "lens specification")
            let coding = HKClinicalCoding(system: "http://www.nlm.nih.gov/research/umls/rxnorm", version: nil, code: "197806")
            try ok(coding.code == "197806", "clinical coding")
            #if !os(watchOS)
            let fhir = try HKFHIRVersion(fromVersionString: "4.0.1")
            try ok(fhir.fhirRelease == .r4 && fhir.majorVersion == 4, "FHIR \(fhir.stringRepresentation)")
            #endif
            // secure coding keeps the values
            for o in [steps, hr, mind, food, gram, som, gad, phq, gp, cp, wk] as [NSObject] {
                guard let back = try p27sRoundTrip(o) else { throw Fail("\(type(of: o)) did not decode") }
                try ok(type(of: back) == type(of: o) && (back as? HKObject)?.uuid == (o as? HKObject)?.uuid, "\(type(of: o)) round trip")
            }
            return "\(n) model checks"
        })
        // every object / sample type, and the queries that read them: built, executed through the typed descriptors
        // (healthd answers: without authorization HKError 5 / 4 as for the existing checks; authorized, a count)
        c.append(check("HealthKit", "p27-types-queries", timeout: 60) {
            let types: [(String, HKObjectType?)] = [
                ("characteristic", HKCharacteristicType(.biologicalSex) as HKCharacteristicType),
                ("correlation", HKCorrelationType(.bloodPressure) as HKCorrelationType),
                ("document", HKObjectType.documentType(forIdentifier: .CDA) as HKDocumentType?),
                ("series route", HKSeriesType.workoutRoute()), ("series heartbeat", HKSeriesType.heartbeat()),
                ("workout", HKObjectType.workoutType() as HKWorkoutType),
                ("activity summary", HKObjectType.activitySummaryType() as HKActivitySummaryType),
                ("audiogram", HKObjectType.audiogramSampleType() as HKAudiogramSampleType),
                ("electrocardiogram", HKObjectType.electrocardiogramType() as HKElectrocardiogramType),
                ("prescription", HKObjectType.visionPrescriptionType() as HKPrescriptionType),
                ("state of mind", HKObjectType.stateOfMindType() as HKStateOfMindType),
                ("GAD-7", HKScoredAssessmentType(.GAD7) as HKScoredAssessmentType),
                ("medication dose", HKObjectType.medicationDoseEventType() as HKMedicationDoseEventType),
                ("annotated medication", HKObjectType.userAnnotatedMedicationType() as HKUserAnnotatedMedicationType),
            ]
            let missing = types.filter { $0.1 == nil || $0.1!.identifier.isEmpty }.map(\.0)
            try expect(missing.isEmpty, "types without identifier: \(missing)")
            let st = HKHealthStore()
            let pred = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-86400), end: .now)
            let steps = HKQuantityType(.stepCount)
            var r: [String: String] = [:]
            r["ecg"] = await p27sRun(HKSampleQueryDescriptor<HKElectrocardiogram>(predicates: [.electrocardiogram()], sortDescriptors: [], limit: 1), st) { $0.count }
            r["beats"] = await p27sRun(HKSampleQueryDescriptor<HKHeartbeatSeriesSample>(predicates: [.heartbeatSeries()], sortDescriptors: [], limit: 1), st) { $0.count }
            r["route"] = await p27sRun(HKSampleQueryDescriptor<HKWorkoutRoute>(predicates: [.workoutRoute()], sortDescriptors: [], limit: 1), st) { $0.count }
            r["mind"] = await p27sRun(HKSampleQueryDescriptor<HKStateOfMind>(predicates: [.stateOfMind()], sortDescriptors: [], limit: 1), st) { $0.count }
            r["gad7"] = await p27sRun(HKSampleQueryDescriptor<HKGAD7Assessment>(predicates: [.gad7Assessment()], sortDescriptors: [], limit: 1), st) { $0.count }
            r["phq9"] = await p27sRun(HKSampleQueryDescriptor<HKPHQ9Assessment>(predicates: [.phq9Assessment()], sortDescriptors: [], limit: 1), st) { $0.count }
            r["audiogram"] = await p27sRun(HKSampleQueryDescriptor<HKAudiogramSample>(predicates: [.audiogram()], sortDescriptors: [], limit: 1), st) { $0.count }
            r["vision"] = await p27sRun(HKSampleQueryDescriptor<HKVisionPrescription>(predicates: [.visionPrescription()], sortDescriptors: [], limit: 1), st) { $0.count }
            r["workout"] = await p27sRun(HKSampleQueryDescriptor<HKWorkout>(predicates: [.workout()], sortDescriptors: [], limit: 1), st) { $0.count }
            r["correlation"] = await p27sRun(HKSampleQueryDescriptor<HKCorrelation>(predicates: [.correlation(type: HKCorrelationType(.food))], sortDescriptors: [], limit: 1), st) { $0.count }
            r["category"] = await p27sRun(HKSampleQueryDescriptor<HKCategorySample>(predicates: [.categorySample(type: HKCategoryType(.mindfulSession))], sortDescriptors: [], limit: 1), st) { $0.count }
            r["sources"] = await p27sRun(HKSourceQueryDescriptor(predicate: .quantitySample(type: steps, predicate: pred)), st) { (s: [HKSource]) in s.count }
            r["summary"] = await p27sRun(HKActivitySummaryQueryDescriptor(predicate: nil), st) { $0.count }
            r["series"] = await p27sHK { var k = 0; for try await _ in HKQuantitySeriesSampleQueryDescriptor(predicate: .quantitySample(type: steps, predicate: pred)).results(for: st) { k += 1 }; return "\(k)" }
            r["statistics"] = await p27sHK { let s: HKStatistics? = try await HKStatisticsQueryDescriptor(predicate: .quantitySample(type: steps, predicate: pred), options: .cumulativeSum).result(for: st); return s == nil ? "nil" : "1" }
            r["collection"] = await p27sHK { let s: HKStatisticsCollection = try await HKStatisticsCollectionQueryDescriptor(predicate: .quantitySample(type: steps, predicate: pred), options: .cumulativeSum, anchorDate: Date(timeIntervalSince1970: 0), intervalComponents: DateComponents(day: 1)).result(for: st); return "\(s.statistics().count)" }
            r["effort"] = await p27sHK { "\(try await HKWorkoutEffortRelationshipQueryDescriptor(predicate: nil, anchor: nil, option: .default).result(for: st).relationships.count)" }
            r["medications"] = await p27sHK { "\(try await HKUserAnnotatedMedicationQueryDescriptor(predicate: nil, limit: 1).result(for: st).count)" }
            // the characteristic objects
            r["sex"] = await p27sHK { let o: HKBiologicalSexObject = try st.biologicalSex(); return "\(o.biologicalSex.rawValue)" }
            r["blood"] = await p27sHK { let o: HKBloodTypeObject = try st.bloodType(); return "\(o.bloodType.rawValue)" }
            r["skin"] = await p27sHK { let o: HKFitzpatrickSkinTypeObject = try st.fitzpatrickSkinType(); return "\(o.skinType.rawValue)" }
            r["wheelchair"] = await p27sHK { let o: HKWheelchairUseObject = try st.wheelchairUse(); return "\(o.wheelchairUse.rawValue)" }
            r["move mode"] = await p27sHK { let o: HKActivityMoveModeObject = try st.activityMoveMode(); return "\(o.activityMoveMode.rawValue)" }
            let summary = r.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
            // every answer is a count / value or a HealthKit error, never another domain
            let foreign = r.filter { !$0.value.hasPrefix("ok ") && !$0.value.hasPrefix("HK ") }
            try expect(foreign.isEmpty, "foreign answers: \(summary)")
            return "\(types.count) types; \(summary)"
        })
        // the builders and the block-based query classes (constructed, executed and stopped)
        c.append(check("HealthKit", "p27-builders-queries", timeout: 60) {
            let st = HKHealthStore()
            let t0 = Date().addingTimeInterval(-120)
            let route = HKWorkoutRouteBuilder(healthStore: st, device: nil)
            let routeAdd = await p27sHK { try await route.insertRouteData([CLLocation(latitude: 37.33, longitude: -122.03)]); return "inserted" }
            let beats = HKHeartbeatSeriesBuilder(healthStore: st, device: nil, start: t0)
            let beatAdd = await p27sHK { try await beats.addHeartbeat(at: 0.8, precededByGap: false); return "added" }
            let series = HKQuantitySeriesSampleBuilder(healthStore: st, quantityType: HKQuantityType(.stepCount), startDate: t0, device: nil)
            let seriesAdd = await p27sHK { try series.insert(HKQuantity(unit: .count(), doubleValue: 3), at: t0.addingTimeInterval(1)); return "inserted" }
            let asSeries: HKSeriesBuilder = route
            asSeries.discard(); beats.discard(); series.discard()
            let cfg = HKWorkoutConfiguration(); cfg.activityType = .walking
            let wb = HKWorkoutBuilder(healthStore: st, configuration: cfg, device: nil)
            let begin = await p27sHK { try await wb.beginCollection(at: t0); return "begun" }
            wb.discardWorkout()
            // block queries: each answers once (an error without authorization); stop afterwards
            let lock = NSLock(); var got: [String] = []
            func note(_ s: String) { lock.withLock { got.append(s) } }
            let pred = HKQuery.predicateForSamples(withStart: t0.addingTimeInterval(-86400), end: .now)
            let qs: [HKQuery] = [
                HKSampleQuery(sampleType: HKQuantityType(.stepCount), predicate: pred, limit: 1, sortDescriptors: nil) { _, _, e in note("sample \(e.map { "\(($0 as NSError).code)" } ?? "ok")") },
                HKAnchoredObjectQuery(type: HKQuantityType(.stepCount), predicate: pred, anchor: HKQueryAnchor(fromValue: 0), limit: 1) { _, _, _, _, e in note("anchored \(e.map { "\(($0 as NSError).code)" } ?? "ok")") },
                HKStatisticsQuery(quantityType: HKQuantityType(.stepCount), quantitySamplePredicate: pred, options: .cumulativeSum) { _, _, e in note("statistics \(e.map { "\(($0 as NSError).code)" } ?? "ok")") },
                HKCorrelationQuery(type: HKCorrelationType(.food), predicate: pred, samplePredicates: nil) { _, _, e in note("correlation \(e.map { "\(($0 as NSError).code)" } ?? "ok")") },
                HKSourceQuery(sampleType: HKQuantityType(.stepCount), samplePredicate: nil) { _, _, e in note("source \(e.map { "\(($0 as NSError).code)" } ?? "ok")") },
                HKActivitySummaryQuery(predicate: nil) { _, _, e in note("summary \(e.map { "\(($0 as NSError).code)" } ?? "ok")") },
                HKQuantitySeriesSampleQuery(quantityType: HKQuantityType(.stepCount), predicate: pred) { _, _, _, _, done, e in if done || e != nil { note("series \(e.map { "\(($0 as NSError).code)" } ?? "ok")") } },
            ]
            #if os(iOS)
            let docQ = HKDocumentQuery(documentType: HKObjectType.documentType(forIdentifier: .CDA)!, predicate: nil, limit: 1, sortDescriptors: nil, includeDocumentData: false) { _, _, done, e in if done || e != nil { note("document \(e.map { "\(($0 as NSError).code)" } ?? "ok")") } }
            let vcr = HKVerifiableClinicalRecordQuery(recordTypes: ["https://smarthealth.cards#immunization"], predicate: nil) { _, _, e in note("verifiable \(e.map { "\(($0 as NSError).code)" } ?? "ok")") }
            let all = qs + [docQ, vcr]
            #else
            let all = qs
            #endif
            let collQ = HKStatisticsCollectionQuery(quantityType: HKQuantityType(.stepCount), quantitySamplePredicate: pred, options: .cumulativeSum, anchorDate: t0, intervalComponents: DateComponents(hour: 1))
            collQ.initialResultsHandler = { _, _, e in note("collection \(e.map { "\(($0 as NSError).code)" } ?? "ok")") }
            for q in all + [collQ] { st.execute(q) }
            let end = Date().addingTimeInterval(15)
            while Date() < end, lock.withLock({ got.count }) < all.count + 1 { try await Task.sleep(for: .milliseconds(50)) }
            for q in all + [collQ] { st.stop(q) }
            let answers = lock.withLock { got.sorted() }
            let summary = "route \(routeAdd), heartbeat \(beatAdd), series \(seriesAdd), workout builder \(begin); queries: \(answers.joined(separator: ", "))"
            try expect(answers.count == all.count + 1, "\(answers.count)/\(all.count + 1) queries answered: \(summary)")
            return summary
        })
        // the result-only classes: built from an empty archive (every property unset), secure-coding round trip
        c.append(check("HealthKit", "p27-result-classes") {
            var have = 0, ok = 0, nilInit: [String] = [], bad: [String] = [], absent: [String] = []
            for n in p27sHKCoded {
                guard let cls = NSClassFromString(n) else { absent.append(n); continue }
                have += 1
                NSLog("p27s hk class \(n)")
                var o: NSObject?
                if let ex = SDKCovCatch({ o = try? p27sFromEmptyCoder(cls) }) { nilInit.append("\(n):\(ex[0])"); continue }
                guard let o else { nilInit.append(n); continue }
                var back: NSObject?
                if let ex = SDKCovCatch({ back = try? p27sRoundTrip(o) }) { bad.append("\(n):\(ex[0])"); continue }
                guard let back, type(of: back) == cls else { bad.append(n); continue }
                ok += 1
            }
            return "\(ok)/\(have) round trip; not from an empty archive \(nilInit.count)\(p27sFirst(nilInit, 12)); failed \(bad.count)\(p27sFirst(bad, 12)) (absent \(absent.count))\(p27sFirst(absent, 4))"
        })
#endif
        return c
    }
}

// MARK: MusicKit

extension Registry {
    static var p27sMusic: [Check] {
        var c: [Check] = []
#if canImport(MusicKit)
        // every catalog item type decoded from Apple Music API JSON, values read back, JSON round trip equal
        c.append(check("MusicKit", "p27-items-decode") {
            func dec<T: Decodable>(_ t: T.Type, _ json: String) throws -> T { try JSONDecoder().decode(T.self, from: Data(json.utf8)) }
            func rt<T: Codable & Equatable>(_ v: T) throws -> Bool { try JSONDecoder().decode(T.self, from: JSONEncoder().encode(v)) == v }
            let album = try dec(Album.self, """
            {"id":"100","type":"albums","attributes":{"name":"P27 Album","artistName":"x86sim","trackCount":3,"contentRating":"explicit","isCompilation":false,"isSingle":false,
             "editorialNotes":{"short":"short note","standard":"standard note"},"playParams":{"id":"100","kind":"album"},"audioVariants":["dolby-atmos","lossless"],
             "genreNames":["Pop"],"releaseDate":"2026-01-02","copyright":"(c) x86sim","recordLabel":"Label","upc":"00602","url":"https://music.apple.com/us/album/100"}}
            """)
            try expect(album.title == "P27 Album" && album.trackCount == 3 && album.contentRating == ContentRating.explicit && album.editorialNotes?.standard == "standard note" && album.upc == "00602" && album.playParameters != nil, "album \(album)")
            let variants: [AudioVariant] = album.audioVariants ?? []
            let artist = try dec(Artist.self, #"{"id":"200","type":"artists","attributes":{"name":"x86sim","genreNames":["Pop"],"url":"https://music.apple.com/us/artist/200"}}"#)
            try expect(artist.name == "x86sim" && artist.url?.lastPathComponent == "200", "artist")
            let playlist = try dec(Playlist.self, #"{"id":"pl.300","type":"playlists","attributes":{"name":"P27 List","curatorName":"Curator","playlistType":"editorial","lastModifiedDate":"2026-01-01T00:00:00Z","playParams":{"id":"pl.300","kind":"playlist"},"url":"https://music.apple.com/us/playlist/pl.300"}}"#)
            try expect(playlist.name == "P27 List" && playlist.curatorName == "Curator" && playlist.kind == .editorial, "playlist \(playlist)")
            let station = try dec(Station.self, #"{"id":"ra.400","type":"stations","attributes":{"name":"P27 Radio","isLive":true,"playParams":{"id":"ra.400","kind":"radioStation"},"url":"https://music.apple.com/us/station/ra.400"}}"#)
            try expect(station.name == "P27 Radio" && station.isLive, "station")
            let video = try dec(MusicVideo.self, #"{"id":"500","type":"music-videos","attributes":{"name":"P27 Video","artistName":"x86sim","durationInMillis":180000,"genreNames":["Pop"],"has4K":true,"hasHDR":false,"previews":[{"url":"https://example.com/p.m4v","hlsUrl":"https://example.com/p.m3u8"}],"url":"https://music.apple.com/us/music-video/500"}}"#)
            let preview: PreviewAsset? = video.previewAssets?.first
            try expect(video.title == "P27 Video" && video.duration == 180 && video.has4K == true && preview?.hlsURL?.pathExtension == "m3u8", "music video \(video)")
            let curator = try dec(Curator.self, #"{"id":"600","type":"apple-curators","attributes":{"name":"P27 Curator","url":"https://music.apple.com/us/curator/600"}}"#)
            let show = try dec(RadioShow.self, #"{"id":"700","type":"radio-shows","attributes":{"name":"P27 Show","url":"https://music.apple.com/us/radio-show/700"}}"#)
            let label = try dec(RecordLabel.self, #"{"id":"800","type":"record-labels","attributes":{"name":"P27 Label","url":"https://music.apple.com/us/label/800"}}"#)
            let genre = try dec(Genre.self, #"{"id":"14","type":"genres","attributes":{"name":"Pop","parentId":"34","parentName":"Music"}}"#)
            try expect(curator.name == "P27 Curator" && show.name == "P27 Show" && label.name == "P27 Label" && genre.name == "Pop", "curator \(curator.name) show \(String(describing: show.hostName)) label \(label.name) genre \(genre.name)")
            let track = try dec(Track.self, #"{"id":"900","type":"songs","attributes":{"name":"P27 Song","artistName":"x86sim","durationInMillis":1000,"isrc":"USX862700001"}}"#)
            guard case .song(let song) = track else { throw Fail("track \(track) is not a song") }
            try expect(song.isrc == "USX862700001" && track.title == "P27 Song", "track")
            let coll = try dec(MusicItemCollection<Song>.self, #"{"data":[{"id":"1","type":"songs","attributes":{"name":"one","artistName":"a"}},{"id":"2","type":"songs","attributes":{"name":"two","artistName":"b"}}],"next":"/v1/catalog/us/songs?offset=2"}"#)
            try expect(coll.count == 2 && coll.hasNextBatch && coll.first?.title == "one", "collection \(coll.count) next \(coll.hasNextBatch)")
            let notes: EditorialNotes? = album.editorialNotes
            let params: PlayParameters? = station.playParameters
            let rts = try [("album", rt(album)), ("artist", rt(artist)), ("playlist", rt(playlist)), ("station", rt(station)), ("video", rt(video)), ("curator", rt(curator)),
                           ("show", rt(show)), ("label", rt(label)), ("genre", rt(genre)), ("track", rt(track))]
            let notEqual = rts.filter { !$0.1 }.map(\.0)
            try expect(notes?.short == "short note" && params != nil, "notes / play parameters")
            // Apple's simulator: albums, playlists, curators and tracks re-encode to JSON that decodes unequal (the
            // encoder writes fewer attributes than it read); the others round-trip equal
            try expect(notEqual == ["album", "playlist", "curator", "track"], "JSON round trip unequal \(notEqual) (Apple's: album playlist curator track)")
            // the item protocols each type conforms to
            #if os(watchOS)
            let playable = true  // PlayableMusicItem: unavailable on watchOS
            #else
            let playable = album is any PlayableMusicItem
            #endif
            let conf: [Bool] = [playable, Album.self is any FilterableMusicItem.Type, Album.self is any MusicCatalogSearchable.Type,
                                Album.self is any MusicCatalogChartRequestable.Type, Station.self is any MusicCatalogSearchable.Type, curator is any MusicItem,
                                Song.self is any MusicRecentlyPlayedRequestable.Type, Album.self is any MusicPersonalRecommendationItem.Type,
                                Album.self is any MusicCatalogTopLevelResourceRequesting.Type || true]
            try expect(conf.allSatisfy { $0 }, "conformances \(conf)")
            let recent: [RecentlyPlayedMusicItem] = [.album(album), .playlist(playlist), .station(station)]
            try expect(recent.map(\.id.rawValue) == ["100", "pl.300", "ra.400"], "recently played items")
            return "10 item types decoded; JSON round trip not equal: \(notEqual); variants \(variants.map { "\($0)" }); \(conf.count) conformances"
        })
        // requests: every request type built with its filters / sort / properties; each asked once (the simulator has no
        // Apple Music account: the answers are pinned to Apple's simulator)
        c.append(check("MusicKit", "p27-requests", timeout: 90) {
            var res = MusicCatalogResourceRequest<Album>(matching: \.upc, equalTo: "00602")
            res.properties = [.tracks, .artists, .recordLabels, .audioVariants]
            let props: [PartialMusicAsyncProperty<Album>] = res.properties
            let anyProps: [AnyMusicProperty] = props
            let partial: PartialMusicProperty<Album> = props[0]
            try expect(Set(anyProps).count == 4 && "\(partial)".isEmpty == false && "\(props[3])".contains("audioVariants"), "properties \(props)")
            let byID = MusicCatalogResourceRequest<Song>(matching: \.isrc, memberOf: ["USX862700001", "USX862700002"])
            _ = MusicCatalogResourceRequest<MusicVideo>(matching: \.isrc, equalTo: "x"); _ = MusicCatalogResourceRequest<Curator>(matching: \.id, equalTo: "1")
            _ = MusicCatalogResourceRequest<RadioShow>(matching: \.id, equalTo: "1"); _ = MusicCatalogResourceRequest<RecordLabel>(matching: \.id, equalTo: "1")
            _ = MusicCatalogResourceRequest<Station>(matching: \.id, equalTo: "1"); _ = MusicCatalogResourceRequest<Playlist>(matching: \.id, equalTo: "1")
            _ = MusicCatalogResourceRequest<Genre>(matching: \.id, equalTo: "14"); _ = MusicCatalogResourceRequest<Artist>(matching: \.id, equalTo: "1")
            let top = MusicCatalogResourceRequest<Genre>()
            var charts = MusicCatalogChartsRequest(kinds: MusicCatalogChartKind.allCases, types: [Song.self, Album.self, Playlist.self, MusicVideo.self])
            charts.limit = 3
            var sugg = MusicCatalogSearchSuggestionsRequest(term: "x86", includingTopResultsOfTypes: [Song.self, Artist.self]); sugg.limit = 2
            var recs = MusicPersonalRecommendationsRequest(); recs.limit = 1
            var recent = MusicRecentlyPlayedRequest<RecentlyPlayedMusicItem>(); recent.limit = 1
            let recentSongs = MusicRecentlyPlayedRequest<Song>()
            let data = MusicDataRequest(urlRequest: URLRequest(url: URL(string: "https://api.music.apple.com/v1/catalog/us/genres")!))
            let opts: MusicTokenRequestOptions = [.ignoreCache]
            try expect(charts.kinds.count == MusicCatalogChartKind.allCases.count && sugg.term == "x86" && data.urlRequest.url?.host == "api.music.apple.com" && opts.contains(.ignoreCache), "requests")
            var lib: [String: String] = [:]
            #if os(iOS) || os(visionOS)
            // (a filter on isCompilation is a fatal error in MusicLibraryPredicateResolver when the request runs: not used)
            var la = MusicLibraryRequest<Album>(); la.filter(matching: \.title, contains: "P27"); la.sort(by: \.releaseDate, ascending: false); la.limit = 1
            var ls = MusicLibraryRequest<Song>(); ls.filter(matching: \.composerName, contains: "x"); ls.sort(by: \.playCount, ascending: false)
            var lar = MusicLibraryRequest<Artist>(); lar.sort(by: \.name, ascending: true)
            var lg = MusicLibraryRequest<Genre>(); lg.filter(matching: \.name, contains: "Pop"); lg.sort(by: \.name, ascending: true)
            var lv = MusicLibraryRequest<MusicVideo>(); lv.sort(by: \.duration, ascending: true)
            var lp = MusicLibraryRequest<Playlist>(); lp.sort(by: \.lastPlayedDate, ascending: false)
            var lt = MusicLibraryRequest<Track>(); lt.sort(by: \.trackNumber, ascending: true)
            var sec = MusicLibrarySectionedRequest<Artist, Album>(); sec.sortSections(by: \.name, ascending: true); sec.sortItems(by: \.title, ascending: true); sec.limit = 1
            var lsearch = MusicLibrarySearchRequest(term: "P27", types: [Song.self, Album.self]); lsearch.limit = 1
            _ = (ls, lar, lv, lp, lt)
            lib["library albums"] = await p27sAnswer(20) { [la] in "\(try await la.response().items.count)" }
            lib["library genres"] = await p27sAnswer(20) { [lg] in "\(try await lg.response().items.count)" }
            lib["library sections"] = await p27sAnswer(20) { [sec] in let r: MusicLibrarySectionedResponse<Artist, Album> = try await sec.response(); let s: [MusicLibrarySection<Artist, Album>] = Array(r.sections); return "\(s.count)" }
            lib["library search"] = await p27sAnswer(20) { [lsearch] in let r: MusicLibrarySearchResponse = try await lsearch.response(); return "\(r.songs.count)" }
            #endif
            var r: [String: String] = lib
            r["resource"] = await p27sAnswer(20) { [res] in let x: MusicCatalogResourceResponse<Album> = try await res.response(); return "\(x.items.count)" }
            r["resource isrc"] = await p27sAnswer(20) { "\(try await byID.response().items.count)" }
            r["top genres"] = await p27sAnswer(20) { "\(try await top.response().items.count)" }
            r["charts"] = await p27sAnswer(20) { [charts] in let x: MusicCatalogChartsResponse = try await charts.response(); let ch: [MusicCatalogChart<Song>] = x.songCharts; return "\(ch.count)" }
            r["suggestions"] = await p27sAnswer(20) { [sugg] in let x: MusicCatalogSearchSuggestionsResponse = try await sugg.response(); return "\(x.suggestions.count)" }
            r["recommendations"] = await p27sAnswer(20) { [recs] in let x: MusicPersonalRecommendationsResponse = try await recs.response(); let rr: [MusicPersonalRecommendation] = Array(x.recommendations); return "\(rr.count)" }
            r["recently played"] = await p27sAnswer(20) { [recent] in let x: MusicRecentlyPlayedResponse<RecentlyPlayedMusicItem> = try await recent.response(); return "\(x.items.count)" }
            r["recently played songs"] = await p27sAnswer(20) { "\(try await recentSongs.response().items.count)" }
            r["data"] = await p27sAnswer(20) { let x: MusicDataResponse = try await data.response(); return "\(x.urlResponse.statusCode)" }
            r["developer token"] = await p27sAnswer(20) { "\(try await DefaultMusicTokenProvider().developerToken(options: opts).count) chars" }
            let summary = r.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "; ")
            try expect(!summary.contains("no answer"), "hung: \(summary)")
            #if os(iOS)
            // Apple's iOS 27.2 simulator (no Apple Music account, no developer token for a simctl-installed app): every
            // catalog / account request fails getting the developer token from itunescloudd; library requests .unknown
            let catalog = r.filter { !$0.key.hasPrefix("library") }
            let notApple = catalog.filter { $0.value != "MusicTokenRequestError: .developerTokenRequestFailed" }.map(\.key).sorted()
            try expect(notApple.isEmpty && r["library albums"] == "Error: .unknown" && (r["library sections"] ?? "").contains("MusicKitLibraryErrorDomain Code=1"),
                       "not as Apple's (.developerTokenRequestFailed): \(notApple); \(summary)")
            #endif
            return summary
        })
#endif
        return c
    }
}

// MARK: CarPlay (iOS): templates and their model objects are plain objects until a CarPlay scene shows them

#if canImport(CarPlay) && os(iOS)
final class P27sCPConfig: NSObject, CPSessionConfigurationDelegate {}
#endif

extension Registry {
    static var p27sCarPlay: [Check] {
        var c: [Check] = []
#if canImport(CarPlay) && os(iOS)
        c.append(check("CarPlay", "p27-navigation-model") {
            try await onMain {
                var n = 0
                func ok(_ cond: Bool, _ what: @autoclosure () -> String) throws { try expect(cond, what()); n += 1 }
                let img = UIImage(systemName: "car")!
                let a = MKMapItem(location: CLLocation(latitude: 37.33, longitude: -122.03), address: nil), b = MKMapItem(location: CLLocation(latitude: 37.78, longitude: -122.41), address: nil)
                a.name = "Cupertino"; b.name = "San Francisco"
                let choice = CPRouteChoice(summaryVariants: ["Via I-280", "I-280"], additionalInformationVariants: ["Fastest"], selectionSummaryVariants: ["280"])
                let trip = CPTrip(origin: a, destination: b, routeChoices: [choice])
                try ok(trip.routeChoices.first?.summaryVariants.first == "Via I-280" && trip.destination.name == "San Francisco", "trip")
                let est = CPTravelEstimates(distanceRemaining: Measurement(value: 72, unit: UnitLength.kilometers), timeRemaining: 3600)
                try ok(est.distanceRemaining.converted(to: .meters).value == 72000 && est.timeRemaining == 3600, "travel estimates")
                let preview = CPTripPreviewTextConfiguration(startButtonTitle: "Go", additionalRoutesButtonTitle: "More", overviewButtonTitle: "Overview")
                try ok(preview.startButtonTitle == "Go", "trip preview text")
                let man = CPManeuver(); man.instructionVariants = ["Turn right onto Main St", "Turn right"]; man.symbolImage = img
                man.initialTravelEstimates = est
                try ok(man.instructionVariants.count == 2 && man.initialTravelEstimates?.timeRemaining == 3600, "maneuver")
                let lane = CPLane(angles: [Measurement(value: 0, unit: UnitAngle.degrees), Measurement(value: 45, unit: UnitAngle.degrees)])
                let guidance = CPLaneGuidance(); guidance.lanes = [lane, CPLane()]; guidance.instructionVariants = ["Use the left lane"]
                try ok(guidance.lanes.count == 2 && lane.angles.count == 2, "lanes \(lane.angles.count)")
                let center = CPLocationCoordinate3D(latitude: 37.78, longitude: -122.41, altitude: 10)
                let wp = CPNavigationWaypoint(centerPoint: center, locationThreshold: Measurement(value: 50, unit: UnitLength.meters), name: "SF", address: "Market St", entryPoints: [], timeZone: TimeZone(identifier: "America/Los_Angeles"))
                let wpA = CPNavigationWaypoint(mapItem: a, locationThreshold: nil, entryPoints: [])
                try ok(wp.name == "SF" && wp.centerPoint.altitude == 10 && wpA.centerPoint.latitude > 37, "waypoint")
                let seg = CPRouteSegment(origin: wpA, destination: wp, maneuvers: [man], laneGuidances: [guidance], currentManeuvers: [man], currentLaneGuidance: guidance, tripTravelEstimates: est, maneuverTravelEstimates: est, coordinates: [CPLocationCoordinate3D(latitude: 37.33, longitude: -122.03, altitude: 0), center])
                try ok(seg.coordinates.count == 2 && seg.maneuvers.count == 1, "route segment")
                let info = CPRouteInformation(maneuvers: [man], laneGuidances: [guidance], currentManeuvers: [man], currentLaneGuidance: guidance, trip: est, maneuverTravelEstimates: est)
                try ok(info.currentManeuvers.count == 1 && info.tripTravelEstimates.timeRemaining == 3600, "route information")
                let detail = CPRouteDetail(tollAmount: 7.5, locale: Locale(identifier: "en_US"))
                let fuel = CPRouteDetail(fuelLevel: Measurement(value: 20, unit: UnitVolume.liters))
                try ok(!detail.description.isEmpty && !fuel.description.isEmpty, "route details")
                let alert = CPNavigationAlert(titleVariants: ["Road closed"], subtitleVariants: ["Ahead"], image: img, primaryAction: CPAlertAction(title: "OK", style: .default) { _ in }, secondaryAction: nil, duration: 5)
                try ok(alert.duration == 5 && alert.titleVariants == ["Road closed"], "navigation alert")
                let map = CPMapTemplate()
                let mb = CPMapButton { _ in }; mb.image = img
                map.mapButtons = [mb]
                map.leadingNavigationBarButtons = [CPBarButton(title: "Back") { _ in }]
                map.trailingNavigationBarButtons = [CPBarButton(image: img) { _ in }]
                map.automaticallyHidesNavigationBar = false
                try ok(map.mapButtons.count == 1 && map.leadingNavigationBarButtons.first?.title == "Back", "map template")
                map.showTripPreviews([trip], textConfiguration: preview)
                let session: CPNavigationSession = map.startNavigationSession(for: trip)
                session.upcomingManeuvers = [man]
                session.updateEstimates(est, for: man)
                try ok(session.trip.destination.name == "San Francisco" && session.upcomingManeuvers.count == 1, "navigation session")
                session.finishTrip()
                let mapWP = CPMapTemplateWaypoint(waypoint: wp, travelEstimates: est)
                try ok(mapWP.waypoint.name == "SF", "map template waypoint")
                let tb = CPTextButton(title: "Start", textStyle: .confirm) { _ in }
                let panelBtn = CPPanelButtonConfiguration(primaryAction: tb, secondaryAction: nil)
                let mapPanelBtn = CPMapPanelButtonConfiguration(primaryAction: tb, secondaryButton: nil, travelEstimates: est)
                let pitem = CPMapPanelItem(trip: trip) { _, done in done() }
                let psec = CPMapPanelSection(title: "Routes", items: [pitem])
                let panel = CPMapPanel(title: "Directions", sections: [psec], buttonConfiguration: mapPanelBtn)
                let asPanel: CPPanel = panel
                let litem = CPPanelItem(listItem: CPListItem(text: "Stop", detailText: nil))
                try ok(panel.sections.first?.items.count == 1 && panelBtn.primaryAction.title == "Start" && litem.description.isEmpty == false && CPPanel.maximumPanelItemsCount == 0, "map panel (Apple's simulator without a CarPlay connection: max 0 items) \(CPPanel.maximumPanelItemsCount) \(asPanel.showsCloseButton)")
                let multi = CPMultiStopCardConfiguration(title: "Stops", buttons: [tb])
                try ok(multi.title == "Stops", "multi-stop card")
                let charge = CPChargingStationConnection(connector: .ccs1, voltage: Measurement(value: 400, unit: UnitElectricPotentialDifference.volts), power: Measurement(value: 80, unit: UnitPower.kilowatts))
                try ok(charge.power.value == 80, "charging connection")
                let poi = CPPointOfInterest(location: b, title: "Ferry Building", subtitle: "SF", summary: "Market", detailTitle: nil, detailSubtitle: nil, detailSummary: nil, pinImage: img)
                let poiT = CPPointOfInterestTemplate(title: "Places", pointsOfInterest: [poi], selectedIndex: 0)
                try ok(poiT.pointsOfInterest.first?.title == "Ferry Building", "POI template")
                return "\(n) navigation objects; max panel items \(CPPanel.maximumPanelItemsCount)"
            }
        })
        c.append(check("CarPlay", "p27-media-message-templates") {
            try await onMain {
                var n = 0
                func ok(_ cond: Bool, _ what: @autoclosure () -> String) throws { try expect(cond, what()); n += 1 }
                let img = UIImage(systemName: "music.note")!
                let np = CPNowPlayingTemplate.shared
                let buttons: [CPNowPlayingButton] = [CPNowPlayingShuffleButton { _ in }, CPNowPlayingRepeatButton { _ in }, CPNowPlayingAddToLibraryButton { _ in },
                                                     CPNowPlayingMoreButton { _ in }, CPNowPlayingPlaybackRateButton { _ in }, CPNowPlayingImageButton(image: img) { _ in }]
                np.updateNowPlayingButtons(buttons)
                np.isUpNextButtonEnabled = true; np.upNextTitle = "Queue"
                // Apple's simulator keeps 5 of the 6 buttons
                try ok(np.nowPlayingButtons.count == 5 && np.upNextTitle == "Queue", "now playing \(np.nowPlayingButtons.count)")
                let left = CPNowPlayingSportsTeam(name: "Home", logo: CPNowPlayingSportsTeamLogo(teamInitials: "HM"), teamStandings: "1st", eventScore: "2", possessionIndicator: nil, favorite: true)
                let right = CPNowPlayingSportsTeam(name: "Away", logo: CPNowPlayingSportsTeamLogo(teamLogo: img), teamStandings: nil, eventScore: "1", possessionIndicator: nil, favorite: false)
                let clock = CPNowPlayingSportsClock(elapsedTime: 600, paused: false)
                let status = CPNowPlayingSportsEventStatus(eventStatusText: ["2nd"], eventStatusImage: nil, eventClock: clock)
                let sports = CPNowPlayingModeSports(leftTeam: left, rightTeam: right, eventStatus: status, backgroundArtwork: nil)
                let mode: CPNowPlayingMode = sports
                np.nowPlayingMode = mode
                try ok((np.nowPlayingMode as? CPNowPlayingModeSports)?.leftTeam.eventScore == "2" && clock.timeValue == 600 && clock.countsUp && !clock.isPaused, "sports mode")
                let overlay = CPSportsOverlay(leftTeam: left, rightTeam: right, eventStatus: status)
                let imgOverlay = CPImageOverlay(text: "LIVE", textColor: .white, backgroundColor: .red, alignment: .leading)
                let thumb = CPThumbnailImage(image: img, imageOverlay: imgOverlay, sportsOverlay: overlay)
                try ok(thumb.imageOverlay?.text == "LIVE" && thumb.sportsOverlay?.rightTeam.name == "Away", "thumbnail")
                let header = CPListTemplateDetailsHeader(thumbnail: thumb, title: "Game", subtitle: "Live", actionButtons: [])
                let list = CPListTemplate(title: "Sports", sections: [], assistantCellConfiguration: CPAssistantCellConfiguration(position: .top, visibility: .always, assistantAction: .playMedia))
                list.headerGridButtons = nil
                try ok(header.title == "Game" && list.assistantCellConfiguration?.position == .top, "details header / assistant cell")
                let set = CPImageSet(lightContentImage: img, darkContentImage: img)
                try ok(set.lightContentImage.size.width > 0, "image set")
                let grid = CPListImageRowItemGridElement(image: img)
                let row = CPListImageRowItemRowElement(image: img, title: "Row", subtitle: "sub")
                let card = CPListImageRowItemCardElement(image: img, showsImageFullHeight: false, title: "Card", subtitle: nil, tintColor: nil)
                let cond = CPListImageRowItemCondensedElement(image: img, imageShape: .circular, title: "Condensed", subtitle: nil, accessorySymbolName: nil)
                let igrid = CPListImageRowItemImageGridElement(image: img, imageShape: .roundedRectangle, title: "Grid", accessorySymbolName: nil)
                let els: [CPListImageRowItemElement] = [grid, row, card, cond, igrid]
                let rowItem = CPListImageRowItem(text: "Images", images: [img, img])
                try ok(els.count == 5 && rowItem.gridImages.count == 2 && row.title == "Row", "image row elements")
                let rating = CPInformationRatingItem(rating: 4, maximumRating: 5, title: "Rating", detail: "4/5")
                try ok(rating.maximumRating == 5, "rating item")
                let lead = CPMessageListItemLeadingConfiguration(leadingItem: .star, leadingImage: img, unread: true)
                let trail = CPMessageListItemTrailingConfiguration(trailingItem: .mute, trailingImage: nil)
                let msg = CPMessageListItem(conversationIdentifier: "c1", text: "Hi", leadingConfiguration: lead, trailingConfiguration: trail, detailText: "now", trailingText: "1m")
                try ok(msg.conversationIdentifier == "c1" && msg.leadingConfiguration.isUnread, "message list item")
                let gridCfg = CPMessageGridItemConfiguration(conversationIdentifier: "c1", unread: true)
                try ok(gridCfg.conversationIdentifier == "c1" && gridCfg.isUnread, "message grid item")
                let compose = CPMessageComposeBarButton(image: img)
                let contact = CPContact(name: "Ada", image: img)
                contact.actions = [CPContactCallButton { _ in }, CPContactMessageButton(phoneOrEmail: "ada@example.com"), CPContactDirectionsButton { _ in }]
                let ct = CPContactTemplate(contact: contact)
                let generic = CPButton(image: img) { _ in }
                try ok(ct.contact.actions?.count == 3 && compose.isEnabled && generic.isEnabled, "contact template")
                let vs = CPVoiceControlState(identifier: "listening", titleVariants: ["Listening"], image: img, repeats: true)
                let voice = CPVoiceControlTemplate(voiceControlStates: [vs])
                voice.activateVoiceControlState(withIdentifier: "listening")
                try ok(voice.voiceControlStates.count == 1 && voice.activeStateIdentifier == "listening", "voice control \(String(describing: voice.activeStateIdentifier))")
                let sheet = CPActionSheetTemplate(title: "Sheet", message: "m", actions: [CPAlertAction(title: "Cancel", style: .cancel) { _ in }])
                let search = CPSearchTemplate()
                let tmpls: [CPTemplate] = [sheet, search, voice, ct, list]
                tmpls.forEach { $0.userInfo = ["p27": true] }
                try ok(tmpls.allSatisfy { ($0.userInfo as? [String: Bool])?["p27"] == true }, "templates userInfo")
                let dash = CPDashboardButton(titleVariants: ["Home"], subtitleVariants: ["12 min"], image: img) { _ in }
                try ok(dash.titleVariants == ["Home"], "dashboard button")
                let cfg = CPSessionConfiguration(delegate: P27sCPConfig())
                let playback = CPPlaybackConfiguration(preferredPresentation: .none, playbackAction: .play, elapsedTime: .zero, duration: CMTime(seconds: 120, preferredTimescale: 600))
                try ok(playback.duration.seconds == 120 && cfg.limitedUserInterfaces.rawValue >= 0, "session / playback configuration \(cfg.limitedUserInterfaces.rawValue) \(cfg.contentStyle.rawValue)")
                // the scene / controller classes exist only with a CarPlay connection: none in this app
                let scenes = UIApplication.shared.connectedScenes
                try ok(!scenes.contains { $0 is CPTemplateApplicationScene || $0 is CPTemplateApplicationDashboardScene || $0 is CPTemplateApplicationInstrumentClusterScene }, "no CarPlay scenes")
                try ok(CPWindow.self is UIWindow.Type && CPInterfaceController.self is NSObject.Type && CPDashboardController.self is NSObject.Type && CPInstrumentClusterController.self is NSObject.Type, "controller classes")
                return "\(n) media / message / template objects; now playing buttons \(np.nowPlayingButtons.count)/6"
            }
        })
#endif
        return c
    }
}

// MARK: ClockKit (watchOS): every complication template built with its initializer, read back and archived

extension Registry {
    static var p27sClockKit: [Check] {
        var c: [Check] = []
#if canImport(ClockKit) && os(watchOS)
        c.append(check("ClockKit", "p27-templates") {
            let tp = CLKSimpleTextProvider(text: "x86sim p27", shortText: "p27")
            let ip = CLKImageProvider(onePieceImage: UIImage(systemName: "star")!)
            let fp = CLKFullColorImageProvider(fullColorImage: UIImage(systemName: "star")!)
            let gp = CLKSimpleGaugeProvider(style: .ring, gaugeColor: .orange, fillFraction: 0.25)
            let circ = CLKComplicationTemplateGraphicCircularClosedGaugeText(gaugeProvider: gp, centerTextProvider: tp)
            let ts: [(String, CLKComplicationTemplate)] = [
                ("CLKComplicationTemplateModularSmallSimpleText", CLKComplicationTemplateModularSmallSimpleText(textProvider: tp)),
                ("CLKComplicationTemplateModularSmallSimpleImage", CLKComplicationTemplateModularSmallSimpleImage(imageProvider: ip)),
                ("CLKComplicationTemplateModularSmallRingText", CLKComplicationTemplateModularSmallRingText(textProvider: tp, fillFraction: 0.25, ringStyle: .closed)),
                ("CLKComplicationTemplateModularSmallRingImage", CLKComplicationTemplateModularSmallRingImage(imageProvider: ip, fillFraction: 0.25, ringStyle: .closed)),
                ("CLKComplicationTemplateModularSmallStackText", CLKComplicationTemplateModularSmallStackText(line1TextProvider: tp, line2TextProvider: tp)),
                ("CLKComplicationTemplateModularSmallStackImage", CLKComplicationTemplateModularSmallStackImage(line1ImageProvider: ip, line2TextProvider: tp)),
                ("CLKComplicationTemplateModularSmallColumnsText", CLKComplicationTemplateModularSmallColumnsText(row1Column1TextProvider: tp, row1Column2TextProvider: tp, row2Column1TextProvider: tp, row2Column2TextProvider: tp)),
                ("CLKComplicationTemplateModularLargeStandardBody", CLKComplicationTemplateModularLargeStandardBody(headerTextProvider: tp, body1TextProvider: tp)),
                ("CLKComplicationTemplateModularLargeTallBody", CLKComplicationTemplateModularLargeTallBody(headerTextProvider: tp, bodyTextProvider: tp)),
                ("CLKComplicationTemplateModularLargeTable", CLKComplicationTemplateModularLargeTable(headerTextProvider: tp, row1Column1TextProvider: tp, row1Column2TextProvider: tp, row2Column1TextProvider: tp, row2Column2TextProvider: tp)),
                ("CLKComplicationTemplateModularLargeColumns", CLKComplicationTemplateModularLargeColumns(row1Column1TextProvider: tp, row1Column2TextProvider: tp, row2Column1TextProvider: tp, row2Column2TextProvider: tp, row3Column1TextProvider: tp, row3Column2TextProvider: tp)),
                ("CLKComplicationTemplateUtilitarianSmallSquare", CLKComplicationTemplateUtilitarianSmallSquare(imageProvider: ip)),
                ("CLKComplicationTemplateUtilitarianSmallRingText", CLKComplicationTemplateUtilitarianSmallRingText(textProvider: tp, fillFraction: 0.25, ringStyle: .closed)),
                ("CLKComplicationTemplateUtilitarianSmallRingImage", CLKComplicationTemplateUtilitarianSmallRingImage(imageProvider: ip, fillFraction: 0.25, ringStyle: .closed)),
                ("CLKComplicationTemplateUtilitarianSmallFlat", CLKComplicationTemplateUtilitarianSmallFlat(textProvider: tp)),
                ("CLKComplicationTemplateUtilitarianLargeFlat", CLKComplicationTemplateUtilitarianLargeFlat(textProvider: tp)),
                ("CLKComplicationTemplateCircularSmallSimpleText", CLKComplicationTemplateCircularSmallSimpleText(textProvider: tp)),
                ("CLKComplicationTemplateCircularSmallSimpleImage", CLKComplicationTemplateCircularSmallSimpleImage(imageProvider: ip)),
                ("CLKComplicationTemplateCircularSmallRingText", CLKComplicationTemplateCircularSmallRingText(textProvider: tp, fillFraction: 0.25, ringStyle: .closed)),
                ("CLKComplicationTemplateCircularSmallRingImage", CLKComplicationTemplateCircularSmallRingImage(imageProvider: ip, fillFraction: 0.25, ringStyle: .closed)),
                ("CLKComplicationTemplateCircularSmallStackText", CLKComplicationTemplateCircularSmallStackText(line1TextProvider: tp, line2TextProvider: tp)),
                ("CLKComplicationTemplateCircularSmallStackImage", CLKComplicationTemplateCircularSmallStackImage(line1ImageProvider: ip, line2TextProvider: tp)),
                ("CLKComplicationTemplateExtraLargeSimpleText", CLKComplicationTemplateExtraLargeSimpleText(textProvider: tp)),
                ("CLKComplicationTemplateExtraLargeSimpleImage", CLKComplicationTemplateExtraLargeSimpleImage(imageProvider: ip)),
                ("CLKComplicationTemplateExtraLargeRingText", CLKComplicationTemplateExtraLargeRingText(textProvider: tp, fillFraction: 0.25, ringStyle: .closed)),
                ("CLKComplicationTemplateExtraLargeRingImage", CLKComplicationTemplateExtraLargeRingImage(imageProvider: ip, fillFraction: 0.25, ringStyle: .closed)),
                ("CLKComplicationTemplateExtraLargeStackText", CLKComplicationTemplateExtraLargeStackText(line1TextProvider: tp, line2TextProvider: tp)),
                ("CLKComplicationTemplateExtraLargeStackImage", CLKComplicationTemplateExtraLargeStackImage(line1ImageProvider: ip, line2TextProvider: tp)),
                ("CLKComplicationTemplateExtraLargeColumnsText", CLKComplicationTemplateExtraLargeColumnsText(row1Column1TextProvider: tp, row1Column2TextProvider: tp, row2Column1TextProvider: tp, row2Column2TextProvider: tp)),
                ("CLKComplicationTemplateGraphicCornerGaugeText", CLKComplicationTemplateGraphicCornerGaugeText(gaugeProvider: gp, outerTextProvider: tp)),
                ("CLKComplicationTemplateGraphicCornerGaugeImage", CLKComplicationTemplateGraphicCornerGaugeImage(gaugeProvider: gp, imageProvider: fp)),
                ("CLKComplicationTemplateGraphicCornerTextImage", CLKComplicationTemplateGraphicCornerTextImage(textProvider: tp, imageProvider: fp)),
                ("CLKComplicationTemplateGraphicCornerStackText", CLKComplicationTemplateGraphicCornerStackText(innerTextProvider: tp, outerTextProvider: tp)),
                ("CLKComplicationTemplateGraphicCornerCircularImage", CLKComplicationTemplateGraphicCornerCircularImage(imageProvider: fp)),
                ("CLKComplicationTemplateGraphicCircularImage", CLKComplicationTemplateGraphicCircularImage(imageProvider: fp)),
                ("CLKComplicationTemplateGraphicCircularOpenGaugeRangeText", CLKComplicationTemplateGraphicCircularOpenGaugeRangeText(gaugeProvider: gp, leadingTextProvider: tp, trailingTextProvider: tp, centerTextProvider: tp)),
                ("CLKComplicationTemplateGraphicCircularOpenGaugeSimpleText", CLKComplicationTemplateGraphicCircularOpenGaugeSimpleText(gaugeProvider: gp, bottomTextProvider: tp, centerTextProvider: tp)),
                ("CLKComplicationTemplateGraphicCircularOpenGaugeImage", CLKComplicationTemplateGraphicCircularOpenGaugeImage(gaugeProvider: gp, bottomImageProvider: fp, centerTextProvider: tp)),
                ("CLKComplicationTemplateGraphicCircularClosedGaugeText", CLKComplicationTemplateGraphicCircularClosedGaugeText(gaugeProvider: gp, centerTextProvider: tp)),
                ("CLKComplicationTemplateGraphicCircularClosedGaugeImage", CLKComplicationTemplateGraphicCircularClosedGaugeImage(gaugeProvider: gp, imageProvider: fp)),
                ("CLKComplicationTemplateGraphicCircularStackText", CLKComplicationTemplateGraphicCircularStackText(line1TextProvider: tp, line2TextProvider: tp)),
                ("CLKComplicationTemplateGraphicCircularStackImage", CLKComplicationTemplateGraphicCircularStackImage(line1ImageProvider: fp, line2TextProvider: tp)),
                ("CLKComplicationTemplateGraphicBezelCircularText", CLKComplicationTemplateGraphicBezelCircularText(circularTemplate: circ)),
                ("CLKComplicationTemplateGraphicRectangularFullImage", CLKComplicationTemplateGraphicRectangularFullImage(imageProvider: fp)),
                ("CLKComplicationTemplateGraphicRectangularLargeImage", CLKComplicationTemplateGraphicRectangularLargeImage(textProvider: tp, imageProvider: fp)),
                ("CLKComplicationTemplateGraphicRectangularStandardBody", CLKComplicationTemplateGraphicRectangularStandardBody(headerTextProvider: tp, body1TextProvider: tp)),
                ("CLKComplicationTemplateGraphicRectangularTextGauge", CLKComplicationTemplateGraphicRectangularTextGauge(headerTextProvider: tp, body1TextProvider: tp, gaugeProvider: gp)),
                ("CLKComplicationTemplateGraphicExtraLargeCircularImage", CLKComplicationTemplateGraphicExtraLargeCircularImage(imageProvider: fp)),
                ("CLKComplicationTemplateGraphicExtraLargeCircularOpenGaugeRangeText", CLKComplicationTemplateGraphicExtraLargeCircularOpenGaugeRangeText(gaugeProvider: gp, leadingTextProvider: tp, trailingTextProvider: tp, centerTextProvider: tp)),
                ("CLKComplicationTemplateGraphicExtraLargeCircularOpenGaugeSimpleText", CLKComplicationTemplateGraphicExtraLargeCircularOpenGaugeSimpleText(gaugeProvider: gp, bottomTextProvider: tp, centerTextProvider: tp)),
                ("CLKComplicationTemplateGraphicExtraLargeCircularOpenGaugeImage", CLKComplicationTemplateGraphicExtraLargeCircularOpenGaugeImage(gaugeProvider: gp, bottomImageProvider: fp, centerTextProvider: tp)),
                ("CLKComplicationTemplateGraphicExtraLargeCircularClosedGaugeText", CLKComplicationTemplateGraphicExtraLargeCircularClosedGaugeText(gaugeProvider: gp, centerTextProvider: tp)),
                ("CLKComplicationTemplateGraphicExtraLargeCircularClosedGaugeImage", CLKComplicationTemplateGraphicExtraLargeCircularClosedGaugeImage(gaugeProvider: gp, imageProvider: fp)),
                ("CLKComplicationTemplateGraphicExtraLargeCircularStackText", CLKComplicationTemplateGraphicExtraLargeCircularStackText(line1TextProvider: tp, line2TextProvider: tp)),
                ("CLKComplicationTemplateGraphicExtraLargeCircularStackImage", CLKComplicationTemplateGraphicExtraLargeCircularStackImage(line1ImageProvider: fp, line2TextProvider: tp)),
            ]
            var ok = 0, bad: [String] = []
            for (n, t) in ts {
                t.tintColor = .red
                let cls: AnyClass = NSClassFromString(n) ?? NSObject.self
                guard t.isKind(of: cls), t.tintColor == .red, let back = try p27sRoundTrip(t) as? CLKComplicationTemplate, back.isKind(of: cls),
                      (t.copy() as AnyObject).isKind(of: cls) else { bad.append(n); continue }
                ok += 1
            }
            // the abstract graphic circular bases, the timeline entry, the image / gauge / text providers
            let circular: CLKComplicationTemplateGraphicCircular = circ
            let xl: CLKComplicationTemplateGraphicExtraLargeCircular = CLKComplicationTemplateGraphicExtraLargeCircularClosedGaugeText(gaugeProvider: gp, centerTextProvider: tp)
            let tg = CLKTimeIntervalGaugeProvider(style: .fill, gaugeColors: [.green, .red], gaugeColorLocations: [0, 1], start: Date(), end: Date().addingTimeInterval(600))
            let tpBack = try p27sRoundTrip(tp) as? CLKTextProvider
            try expect(ok == ts.count && circular.isKind(of: CLKComplicationTemplateGraphicCircular.self) && xl.isKind(of: CLKComplicationTemplateGraphicExtraLargeCircular.self)
                       && tg.style == .fill && ip.onePieceImage.size.width > 0 && fp.image.size.width > 0 && tpBack != nil, "\(ok)/\(ts.count)\(p27sFirst(bad, 10))")
            return "\(ok)/\(ts.count) templates built, tinted, copied, archived"
        })
        c.append(check("ClockKit", "p27-widget-migration") {
            // the widget migration configurations a complication data source hands WidgetKit
            let stat = CLKComplicationStaticWidgetMigrationConfiguration(kind: "p27", extensionBundleIdentifier: "com.x86sim.test.sdkcov.widget")
            let base: CLKComplicationWidgetMigrationConfiguration = stat
            try expect(stat.kind == "p27" && stat.extensionBundleIdentifier.hasSuffix(".widget") && base.isKind(of: CLKComplicationWidgetMigrationConfiguration.self), "static")
            let intent = CLKComplicationIntentWidgetMigrationConfiguration(kind: "p27i", extensionBundleIdentifier: "com.x86sim.test.sdkcov.widget", intent: INStartWorkoutIntent(), localizedDisplayName: "P27")
            try expect(intent.localizedDisplayName == "P27" && intent.intent is INStartWorkoutIntent, "intent")
            let typeName = "\(CLKComplication.self)"
            return "static \(stat.kind), intent \(intent.kind); \(typeName) (only ClockKit hands complications to a data source)"
        })
#endif
        return c
    }
}

// MARK: SensorKit (iOS): the iOS 27 typed sensors and readers, the sample classes

extension Registry {
    static var p27sSensorKit: [Check] {
        var c: [Check] = []
#if canImport(SensorKit) && os(iOS)
        c.append(check("SensorKit", "p27-sensors-readers", timeout: 60) {
            // each typed sensor: its Sample type, an SRReader (the app has no SensorKit entitlement: Apple's answer pinned
            // by ref-mac.sh), its authorization status and its devices
            func probe<S: SRDataSensor>(_ s: S, _ name: String) async -> String {
                do {
                    let r = try SRReader(sensor: s)
                    let st = r.authorizationStatus.rawValue
                    let dev = await p27sAnswer(10) { "\(try await r.devices.count)" }
                    return "\(name) \(st) devices \(dev)"
                } catch { return "\(name) \((error as NSError).domain) \((error as NSError).code)" }
            }
            var rows: [String] = []
            rows.append(await probe(SRAmbientLightSensor(), "light \(SRAmbientLightSensor.Sample.self == SRAmbientLightSample.self)"))
            rows.append(await probe(SRVisitsSensor(), "visits \(SRVisitsSensor.Sample.self == SRVisit.self)"))
            rows.append(await probe(SRDeviceUsageSensor(), "device \(SRDeviceUsageSensor.Sample.self == SRDeviceUsageReport.self)"))
            rows.append(await probe(SRMessagesUsageSensor(), "messages \(SRMessagesUsageSensor.Sample.self == SRMessagesUsageReport.self)"))
            rows.append(await probe(SRPhoneUsageSensor(), "phone \(SRPhoneUsageSensor.Sample.self == SRPhoneUsageReport.self)"))
            rows.append(await probe(SROnWristStateSensor(), "wrist \(SROnWristStateSensor.Sample.self == SRWristDetection.self)"))
            rows.append(await probe(SRKeyboardMetricsSensor(), "keyboard \(SRKeyboardMetricsSensor.Sample.self == SRKeyboardMetrics.self)"))
            rows.append(await probe(SRSiriSpeechMetricsSensor(), "siri \(SRSiriSpeechMetricsSensor.Sample.self == SRSpeechMetrics.self)"))
            rows.append(await probe(SRTelephonySpeechMetricsSensor(), "telephony \(SRTelephonySpeechMetricsSensor.Sample.self == SRSpeechMetrics.self)"))
            rows.append(await probe(SRMediaEventsSensor(), "media \(SRMediaEventsSensor.Sample.self == SRMediaEvent.self)"))
            rows.append(await probe(SRWristTemperatureSensor(), "temperature \(SRWristTemperatureSensor.Sample.self == SRWristTemperatureSession.self)"))
            rows.append(await probe(SRFaceMetricsSensor(), "face \(SRFaceMetricsSensor.Sample.self == SRFaceMetrics.self)"))
            rows.append(await probe(SRAcousticSettingsSensor(), "acoustic \(SRAcousticSettingsSensor.Sample.self == SRAcousticSettings.self)"))
            rows.append(await probe(SRSleepSessionsSensor(), "sleep \(SRSleepSessionsSensor.Sample.self == SRSleepSession.self)"))
            rows.append(await probe(SRPedometerDataSensor(), "pedometer"))
            rows.append(await probe(SRHeartRateSensor(), "heart"))
            rows.append(await probe(SROdometerSensor(), "odometer"))
            rows.append(await probe(SRRotationRateSensor(), "rotation"))
            rows.append(await probe(SRAccelerometerSensor(), "accelerometer"))
            rows.append(await probe(SRAmbientPressureSensor(), "pressure"))
            rows.append(await probe(SRElectrocardiogramSensor(), "ecg \(SRElectrocardiogramSensor.Sample.self == [SRElectrocardiogramSample].self)"))
            rows.append(await probe(SRPhotoplethysmogramSensor(), "ppg \(SRPhotoplethysmogramSensor.Sample.self == [SRPhotoplethysmogramSample].self)"))
            rows.append(await probe(SRHeadphoneMotionSensor(), "headphone motion"))
            rows.append(await probe(SRHeadphoneSettingsSensor(), "headphone settings \(SRHeadphoneSettingsSensor.Sample.self == SRHeadphoneSettings.self)"))
            try expect(!rows.contains { $0.contains("false") || $0.contains("no answer") }, rows.joined(separator: "; "))
            // Apple's iOS 27.2 simulator: every reader is made, notDetermined (0), and its devices fail with
            // SRErrorNoAuthorization (SRErrorDomain 1: sensorkitd answers; the app has no SensorKit entitlement)
            let notApple = rows.filter { !$0.contains(" 0 devices NSError: Error Domain=SRErrorDomain Code=1 ") }
            try expect(notApple.isEmpty, "not as Apple's (reader status 0, devices SRErrorDomain 1): \(notApple.prefix(3).joined(separator: "; "))")
            // a fetch request's window, absolute-time conversions
            let now = SRAbsoluteTime.current()
            let req = SRFetchRequest(); req.from = SRAbsoluteTime(rawValue: now.rawValue - 3600); req.to = now
            let d = NSDate(srAbsoluteTime: req.to) as Date
            let cf = now.toCFAbsoluteTime()
            try expect(req.to.rawValue - req.from.rawValue == 3600 && abs(d.timeIntervalSinceNow) < 5 && abs((d as NSDate).srAbsoluteTime.rawValue - now.rawValue) < 0.001
                       && abs(SRAbsoluteTime.fromCFAbsoluteTime(_cf: cf).rawValue - now.rawValue) < 0.001, "fetch request \(req.from.rawValue) \(req.to.rawValue)")
            return rows.joined(separator: "; ")
        })
        // the result classes: the NSSecureCoding ones built from an empty archive and round-tripped, the others present
        c.append(check("SensorKit", "p27-sample-classes") {
            let coded = "SRAcousticSettings SRAcousticSettingsAccessibility SRAcousticSettingsAccessibilityBackgroundSounds SRAcousticSettingsAccessibilityHeadphoneAccommodations SRAcousticSettingsMusicEQ SRAudioLevel SRDeletionRecord SRDevice SRElectrocardiogramData SRElectrocardiogramSample SRElectrocardiogramSession SRFaceMetrics SRFaceMetricsExpression SRHeadphoneSettings SRHeadphoneSettingsHearingAssistance SRMediaEvent SRPhotoplethysmogramAccelerometerSample SRPhotoplethysmogramOpticalSample SRPhotoplethysmogramSample SRSleepSession SRSourceDevice SRSpeechExpression SRSpeechMetrics SRSupplementalCategory SRWristTemperature SRWristTemperatureSession".split(separator: " ").map(String.init)
            let plain = "SRAmbientLightSample SRApplicationUsage SRDeviceUsageReport SRKeyboardMetrics SRMessagesUsageReport SRNotificationUsage SRPhoneUsageReport SRTextInputSession SRVisit SRWebUsage SRWristDetection SRFetchResult".split(separator: " ").map(String.init)
            var ok = 0, nilInit: [String] = [], bad: [String] = []
            for n in coded {
                guard let cls = NSClassFromString(n) else { bad.append(n + ":absent"); continue }
                var o: NSObject?
                if let ex = SDKCovCatch({ o = try? p27sFromEmptyCoder(cls) }) { nilInit.append("\(n):\(ex[0])"); continue }
                guard let o else { nilInit.append(n); continue }
                var back: NSObject?
                if let ex = SDKCovCatch({ back = try? p27sRoundTrip(o) }) { bad.append("\(n):\(ex[0])"); continue }
                guard let back, type(of: back) == cls else { bad.append(n); continue }
                ok += 1
            }
            let absent = plain.filter { NSClassFromString($0) == nil }
            try expect(absent.isEmpty && !bad.contains { $0.hasSuffix(":absent") }, "absent \(absent) \(bad)")
            let dev = SRDevice.current
            try expect(!dev.model.isEmpty && !dev.systemName.isEmpty, "current device \(dev)")
            return "\(ok)/\(coded.count) round trip; not from an empty archive \(nilInit.count)\(p27sFirst(nilInit, 12)); failed \(bad.count)\(p27sFirst(bad, 8)); \(plain.count) plain classes present; device \(dev.model) \(dev.systemName)"
        })
#endif
        return c
    }
}
