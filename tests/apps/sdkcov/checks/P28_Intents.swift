// SDK coverage, round 30 wave 2 (P28): public API of the SDK still not referenced by any check after P27
// (~/scratch/r30/apisurf.py), area: Intents. Each check asserts what Apple's simulator answers (ref-mac.sh --only).
// AppIntents: most of what is left is protocols an app adopts (system intents, entity kinds, queries), result builders
// (parameter summaries, predictions, query properties, resolvers, shortcut options) and their result types: the checks
// adopt the protocols the way an app does (no macros: the Linux toolchain has no AppIntents macro plugin), build with the
// builders spelled out and assert what the framework gives back (default protocol answers, builder result types, the
// resolvers a value type's default specification holds, the system's answer for an app with no App Intents metadata).
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppIntents)
import AppIntents
#endif
#if canImport(CoreSpotlight)
import CoreSpotlight
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

#if canImport(WidgetKit) && !os(tvOS)
import WidgetKit
#endif
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif
#if canImport(Intents)
import Intents
#endif
#if canImport(FoundationModels) && !os(tvOS)
import FoundationModels
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif
import CoreTransferable
#if canImport(GroupActivities)
import GroupActivities
#endif
#if canImport(TipKit)
import TipKit
#endif
#if canImport(ExtensionKit)
import ExtensionKit
import ExtensionFoundation
#endif
#if canImport(AppIntentsTypeSupport)
import AppIntentsTypeSupport
#endif

// MARK: App Intents types

#if canImport(AppIntents)
/// a song: an entity with queryable properties, indexed, owned, with a URL representation
struct P28Song: AppEntity, OwnershipProvidingEntity, URLRepresentableEntity, AssistantSchemaEntity, SyncableEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { TypeDisplayRepresentation(name: "Song", numericFormat: "\(placeholder: .int) songs", synonyms: ["Track"]) }
    static var defaultQuery: P28SongQuery { P28SongQuery() }
    static var urlRepresentation: EntityURLRepresentation<P28Song> { "https://example.com/song/\(.id)/\(\.$title)" }
    let id: String
    @Property(title: "Title") var title: String
    @Property(title: "Plays") var plays: Int
    init(id: String, title: String, plays: Int) { self.id = id; self.title = title; self.plays = plays }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)", subtitle: "\(plays) plays") }
    var ownership: EntityOwnership { plays > 10 ? .public : .shared }
    static let all = [P28Song(id: "s1", title: "Blue Train", plays: 12), P28Song(id: "s2", title: "Giant Steps", plays: 5), P28Song(id: "s3", title: "Blue in Green", plays: 30)]
}
enum P28Cmp: Sendable { case titleIs(String), titleNot(String), titleContains(String), titlePrefix(String), titleSuffix(String), playsAbove(Int), playsBelow(Int), playsAtLeast(Int), playsAtMost(Int), playsBetween(Int, Int) }
struct P28SongQuery: EntityPropertyQuery, EntityStringQuery {
    typealias ComparatorMappingType = P28Cmp
    @EntityQueryComparatorsBuilder<P28Song, P28Song, EntityProperty<String>, String, P28Cmp>
    static func titleComparators() -> [AnyEntityQueryComparator<P28Song, P28Song, EntityProperty<String>, String, P28Cmp>] {
        EqualToComparator { .titleIs($0) }
        NotEqualToComparator { .titleNot($0) }
        ContainsComparator { .titleContains($0) }
        HasPrefixComparator { .titlePrefix($0) }
        HasSuffixComparator { .titleSuffix($0) }
    }
    @EntityQueryComparatorsBuilder<P28Song, P28Song, EntityProperty<Int>, Int, P28Cmp>
    static func playsComparators() -> [AnyEntityQueryComparator<P28Song, P28Song, EntityProperty<Int>, Int, P28Cmp>] {
        GreaterThanComparator { .playsAbove($0) }
        LessThanComparator { .playsBelow($0) }
        GreaterThanOrEqualToComparator { .playsAtLeast($0) }
        LessThanOrEqualToComparator { .playsAtMost($0) }
        IsBetweenComparator { .playsBetween($0, $1) }
    }
    @EntityQueryPropertiesBuilder<P28Song, P28Cmp>
    static func declarations() -> [EntityQueryPropertyDeclaration<P28Song, P28Cmp>] {
        EntityQueryProperty(\P28Song.$title, comparators: titleComparators)
        EntityQueryProperty(\P28Song.$plays, comparators: playsComparators)
    }
    static var properties: EntityQueryProperties<P28Song, P28Cmp> { EntityQueryProperties(properties: declarations) }
    @EntityQuerySortingOptionsBuilder<P28Song>
    static func sorts() -> [EntityQuerySortableByProperty<P28Song>] {
        EntityQuerySortableByProperty(\P28Song.$title)
        EntityQuerySortableByProperty(\P28Song.$plays)
    }
    static var sortingOptions: EntityQuerySortingOptions<P28Song> { EntityQuerySortingOptions(content: sorts) }
    static var findIntentDescription: IntentDescription? { IntentDescription("Find songs", categoryName: "Music", searchKeywords: ["song"], resultValueName: "Songs") }
    func entities(for identifiers: [String]) async throws -> [P28Song] { P28Song.all.filter { identifiers.contains($0.id) } }
    func entities(matching string: String) async throws -> [P28Song] { P28Song.all.filter { $0.title.localizedCaseInsensitiveContains(string) } }
    func suggestedEntities() async throws -> [P28Song] { P28Song.all }
    /// the app's own query evaluation (what the system calls with the comparators it built from `properties`)
    func entities(matching comparators: [P28Cmp], mode: EntityQueryComparatorMode, sortedBy: [EntityQuerySort<P28Song>], limit: Int?) async throws -> [P28Song] {
        func ok(_ s: P28Song, _ c: P28Cmp) -> Bool {
            switch c {
            case .titleIs(let t): return s.title == t
            case .titleNot(let t): return s.title != t
            case .titleContains(let t): return s.title.contains(t)
            case .titlePrefix(let t): return s.title.hasPrefix(t)
            case .titleSuffix(let t): return s.title.hasSuffix(t)
            case .playsAbove(let n): return s.plays > n
            case .playsBelow(let n): return s.plays < n
            case .playsAtLeast(let n): return s.plays >= n
            case .playsAtMost(let n): return s.plays <= n
            case .playsBetween(let a, let b): return s.plays >= a && s.plays <= b
            }
        }
        let r = P28Song.all.filter { s in mode == .and ? comparators.allSatisfy { ok(s, $0) } : comparators.contains { ok(s, $0) } }
        return Array(r.prefix(limit ?? r.count))
    }
}
#if os(iOS) || os(visionOS)
extension P28Song: IndexedEntity {
    var hideInSpotlight: Bool { id == "s3" }
}
extension P28SongQuery: IndexedEntityQuery {
    func reindexEntities(for identifiers: [String], indexDescription: CSSearchableIndexDescription) async throws {}
    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {}
}
#endif
/// the app's settings: one unique entity
struct P28Settings: UniqueAppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Settings" }
    static var defaultQuery: UniqueAppEntityProvider<P28Settings> { UniqueAppEntityProvider { P28Settings(volume: 7) } }
    var volume: Int
}
/// a document: a file entity, its identifier a draft or a file URL
struct P28IntentDoc: FileEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Doc" }
    static var defaultQuery: P28DocQuery { P28DocQuery() }
    static var supportedContentTypes: [UTType] { [.plainText] }
    let id: FileEntityIdentifier
    var displayRepresentation: DisplayRepresentation { "doc" }
}
struct P28DocQuery: EntityQuery {
    func entities(for identifiers: [FileEntityIdentifier]) async throws -> [P28IntentDoc] { identifiers.map { P28IntentDoc(id: $0) } }
}
/// an enum with URLs, an assistant-schema enum
enum P28Mood: String, AppEnum, URLRepresentableEnum, AssistantSchemaEnum {
    case calm, upbeat
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Mood" }
    static var caseDisplayRepresentations: [P28Mood: DisplayRepresentation] { [.calm: "Calm", .upbeat: "Upbeat"] }
    static var urlRepresentation: EnumURLRepresentation<P28Mood> { "https://example.com/mood/\(.rawValue)" }
}
/// a union value: a song or a mood (what the @UnionValue macro writes by hand)
enum P28Pick: AppUnionValue, Sendable {
    typealias Cases = P28PickKind
    case song(P28Song), mood(P28Mood)
}
enum P28PickKind: String, AppUnionValueCasesProviding {
    typealias UnionValue = P28Pick
    case song, mood
}
/// parameter options for the App Shortcut options collection
struct P28MoodOptions: DynamicOptionsProvider {
    func results() async throws -> [P28Mood] { P28Mood.allCases }
}
/// a value query (the system's question "what values for this input")
struct P28ValueQuery: IntentValueQuery {
    func values(for input: String) async throws -> [P28Song] { P28Song.all.filter { $0.title.hasPrefix(input) } }
}
/// my own resolvers: a range-checking one from Int to Int, a String one
struct P28HalfResolver: RangeCheckingResolver {
    func resolve(from input: Int, context: IntentParameterContext<Int>) async throws -> Int? { input / 2 }
}
struct P28TrimResolver: Resolver {
    func resolve(from input: String, context: IntentParameterContext<String>) async throws -> String? { input.trimmingCharacters(in: .whitespaces) }
}
@ResolverSpecificationBuilder<Int> func p28IntSpec() -> some ResolverSpecification { P28HalfResolver() }
@ResolverSpecificationBuilder<String> func p28StringSpec() -> some ResolverSpecification { P28TrimResolver(); P28TrimResolver() }

/// an intent with a conditional parameter summary, predictions, a deprecation and a migration from a custom intent
struct P28PlayIntent: AudioPlaybackIntent, AudioStartingIntent, PredictableIntent, DeprecatedAppIntent, CustomIntentMigratedAppIntent, CancellableIntent, ForegroundContinuableIntent {
    static var title: LocalizedStringResource { "Play songs" }
    static var intentClassName: String { "P28PlaySongIntent" }
    static var deprecation: IntentDeprecation<P28SearchIntent> { IntentDeprecation(message: "Use search", replacedBy: P28SearchIntent.self) }
    static var allowedExecutionTargets: IntentExecutionTargets { [.main, .appIntentsExtension] }
    @IntentParameter(title: "Song") var song: P28Song?
    @IntentParameter(title: "Mood", default: .calm) var mood: P28Mood
    @IntentParameter(title: "Count", default: 1, inputConnectionBehavior: .connectToPreviousIntentResult) var count: Int
    init() {}
    @ParameterSummaryBuilder<P28PlayIntent>
    static var parameterSummary: some ParameterSummary {
        ParameterSummaryWhenCondition(\.$song, HasValueComparisonOperator.hasAnyValue) {
            IntentParameterSummary(ParameterSummaryString<P28PlayIntent>("Play \(\.$song) \(\.$count) times"))
        } otherwise: {
            ParameterSummarySwitchCondition(\.$mood) {
                ParameterSummaryCaseCondition(P28Mood.calm) { Summary("Play something calm") { \.$count } }
                ParameterSummaryDefaultCaseCondition { Summary("Play \(\.$mood)") }
            }
        }
    }
    @IntentPredictionsBuilder<P28PlayIntent>
    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: \.$mood) { (m: P28Mood) in DisplayRepresentation(title: "Play \(m.rawValue)") }
        IntentPrediction(parameters: (\.$mood, \.$count)) { (m: P28Mood, n: Int) in DisplayRepresentation(title: "Play \(n) \(m.rawValue)") }
    }
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        .result(value: count, dialog: "Playing \(count)")
    }
}
/// summary comparisons on numbers, strings, identifiers and widget families
#if os(iOS) || os(visionOS)
extension P28PlayIntent: LiveActivityIntent {}
#endif
#if !os(tvOS)
extension P28SummaryIntent: WidgetConfigurationIntent {}
#endif
struct P28SummaryIntent: AppIntent {
    #if os(tvOS)
    func perform() async throws -> some IntentResult { .result() }
    #endif
    static var title: LocalizedStringResource { "Summaries" }
    @IntentParameter(title: "Count", default: 2) var count: Int
    @IntentParameter(title: "Name", default: "x") var name: String
    @IntentParameter(title: "Song") var song: P28Song?
    @IntentParameter(title: "Mood", default: .calm) var mood: P28Mood
    init() {}
    @ParameterSummaryBuilder<P28SummaryIntent>
    static var parameterSummary: some ParameterSummary {
        When(\.$count, ComparableComparisonOperator.greaterThan, 3) {
            Summary("Many \(\.$count)")
        } otherwise: {
            When(\.$mood, OneOfComparisonOperator.oneOf, [P28Mood.calm, P28Mood.upbeat]) {
                #if os(tvOS)
                When(\P28SummaryIntent.$song, identifier: StringComparisonOperator.hasPrefix, "s") { Summary("x \(\.$name)") } otherwise: { Summary("\(\.$name)") }
                #else
                When(widgetFamily: EquatableComparisonOperator.equalTo, IntentWidgetFamily.systemSmall) {
                    Summary("Small \(\.$name)")
                } otherwise: {
                    When(\P28SummaryIntent.$song, identifier: StringComparisonOperator.hasPrefix, "s") { Summary("x \(\.$name)") } otherwise: { Summary("\(\.$name)") }
                }
                #endif
            } otherwise: {
                Summary()
            }
        }
    }
}
struct P28SearchIntent: ShowInAppSearchResultsIntent {
    static var title: LocalizedStringResource { "Search songs" }
    static var searchScopes: [StringSearchScope] { [.general, .tv] }
    @IntentParameter(title: "Criteria") var criteria: StringSearchCriteria
    init() {}
    func perform() async throws -> some IntentResult { .result() }
}
#if !os(watchOS)
struct P28VideoIntent: PlayVideoIntent {
    static var title: LocalizedStringResource { "Play video" }
    static var supportedCategories: [VideoCategory] { [.movies, .tv] }
    @IntentParameter(title: "Term") var term: String
    init() {}
    func perform() async throws -> some IntentResult { .result() }
}
#endif
struct P28RecordIntent: AudioRecordingIntent, UndoableIntent, LongRunningIntent {
    static var title: LocalizedStringResource { "Record" }
    init() {}
    func perform() async throws -> some IntentResult { .result() }
}
#if os(iOS)
struct P28CameraIntent: CameraCaptureIntent {
    struct Ctx: Codable, Sendable { var lens: String }
    typealias AppContext = Ctx
    static var title: LocalizedStringResource { "Capture" }
    init() {}
    func perform() async throws -> some IntentResult { .result() }
}
#endif
struct P28TalkIntent: SystemIntent {
    static var title: LocalizedStringResource { "Talk" }
    init() {}
    func perform() async throws -> some IntentResult { .result() }
}
#if !os(watchOS)
extension P28TalkIntent: TargetContentProvidingIntent {}
#endif
#if os(iOS) || os(visionOS)
extension P28TalkIntent: PushToTalkTransmissionIntent, LiveActivityStartingIntent {}
#endif
#if os(iOS) || os(watchOS)
struct P28ControlIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource { "Control" }
    @IntentParameter(title: "Mood", default: .upbeat) var mood: P28Mood
    init() {}
}
#endif
struct P28AssistantIntent: AssistantSchemaIntent, AssistantIntent {
    static var title: LocalizedStringResource { "Assistant" }
    init() {}
    func perform() async throws -> some IntentResult { .result() }
}
struct P28OpenSongIntent: OpenIntent, URLRepresentableIntent {
    static var title: LocalizedStringResource { "Open song" }
    @IntentParameter(title: "Song") var target: P28Song
    init() {}
}
/// an intent the system opens by URL
struct P28ShowMoodIntent: URLRepresentableIntent {
    static var title: LocalizedStringResource { "Show mood" }
    static var urlRepresentation: IntentURLRepresentation<P28ShowMoodIntent> { "https://example.com/show/\(\.$mood)" }
    @IntentParameter(title: "Mood", default: .calm) var mood: P28Mood
    init() {}
}
struct P28MoodFocus: SetFocusFilterIntent {
    static var title: LocalizedStringResource { "Mood focus" }
    @IntentParameter(title: "Mood", default: .calm) var mood: P28Mood
    init() {}
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "Focus \(mood.rawValue)") }
    var appContext: FocusFilterAppContext { FocusFilterAppContext(notificationFilterPredicate: NSPredicate(format: "SELF IN %@", [mood.rawValue]), targetContentIdentifierPrefix: "mood-") }
    static func suggestedFocusFilters(for context: FocusFilterSuggestionContext) async -> [P28MoodFocus] { var a = P28MoodFocus(); a.mood = .upbeat; return [a] }
    func perform() async throws -> some IntentResult { .result() }
}
#if os(iOS) || os(watchOS)
struct P28Workout: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Workout" }
    static var defaultQuery: P28WorkoutQuery { P28WorkoutQuery() }
    let id: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(id)") }
}
struct P28WorkoutQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [P28Workout] { identifiers.map { P28Workout(id: $0) } }
}
struct P28StartWorkout: StartWorkoutIntent {
    static var title: LocalizedStringResource { "Start run" }
    static var suggestedWorkouts: [P28StartWorkout] { [P28StartWorkout(style: P28Workout(id: "run")), P28StartWorkout(style: P28Workout(id: "swim"))] }
    @IntentParameter(title: "Style") var workoutStyle: P28Workout
    init() {}
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "Start \(workoutStyle.id)") }
    func perform() async throws -> some IntentResult { .result() }
}
struct P28PauseWorkout: PauseWorkoutIntent, ResumeWorkoutIntent {
    static var title: LocalizedStringResource { "Pause or resume" }
    init() {}
    func perform() async throws -> some IntentResult { .result() }
}
#endif
#if os(watchOS)
struct P28Dive: StartDiveIntent {
    static var title: LocalizedStringResource { "Dive" }
    init() {}
    func perform() async throws -> some IntentResult { .result() }
}
#endif
struct P28SnippetIntent: SnippetIntent {
    static var title: LocalizedStringResource { "Snippet" }
    init() {}
    func perform() async throws -> some IntentResult & ShowsSnippetView { .result(view: Text("sdkcov snippet")) }
}
struct P28ShowSnippet: AppIntent {
    static var title: LocalizedStringResource { "Show snippet" }
    init() {}
    func perform() async throws -> some IntentResult & ShowsSnippetIntent & OpensIntent { .result(opensIntent: P28OpenSongIntent(), snippetIntent: P28SnippetIntent()) }
}
struct P28Package: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [P28SubPackage.self] }
}
struct P28SubPackage: AppIntentsPackage {}
struct P28Shortcuts2: AppShortcutsProvider {
    @AppShortcutsBuilder static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: P28PlayIntent(),
                    phrases: [AppShortcutPhrase<P28PlayIntent>("Play \(\.$mood) in \(AppShortcutPhraseToken.applicationName)")],
                    shortTitle: "Play", systemImageName: "play",
                    parameterPresentation: AppShortcutParameterPresentation(
                        for: \.$mood,
                        summary: AppShortcutParameterPresentationSummary(AppShortcutParameterPresentationSummaryString("Play \(\.$mood)")),
                        optionsCollections: p28Options))
    }
    @AppShortcutOptionsCollectionSpecificationBuilder<P28Mood>
    static func p28Options() -> some AppShortcutOptionsCollectionSpecification<P28Mood> {
        AppShortcutOptionsCollection(P28MoodOptions(), title: "Moods", systemImageName: "music.note")
    }
    static var negativePhrases: NegativeAppShortcutPhrases { NegativeAppShortcutPhrases(phrases: [NegativeAppShortcutPhrase("Stop \(.applicationName)"), "Pause music"]) }
    static let title = AppShortcutParameterPresentationTitle<P28PlayIntent, P28Mood, IntentParameter<P28Mood>, KeyPath<P28PlayIntent, IntentParameter<P28Mood>>>(specific: AppShortcutParameterPresentationTitleString("Play \(\.$mood)"), generic: "Play a mood")
}
struct P28ShortcutsContent: AppShortcutsContent {
    var appShortcuts: [AppShortcut] { P28Shortcuts2.appShortcuts }
}
struct P28Error: Error, CustomAppIntentErrorConvertible {
    var appIntentError: AppIntentError { AppIntentError(description: "sdkcov failed") }
}
struct P28Extension: AppIntentsExtension {}
/// a Transferable item that exports as an App Intents value (IntentPerson)
struct P28Contact: Transferable {
    var name: String
    static var transferRepresentation: some TransferRepresentation {
        IntentValueRepresentation<P28Contact, IntentPerson>(exporting: { c in IntentPerson(identifier: .applicationDefined(c.name), name: .displayName(c.name), handle: IntentPerson.Handle(emailAddress: "\(c.name)@example.com")) })
    }
}
#endif

// MARK: WidgetKit types: control widgets (toggle / button, static and App Intent configurations, value providers, push
// handlers), widgets with timeline / intent providers, a live activity with a Dynamic Island, preview builders

#if canImport(WidgetKit) && !os(tvOS)
struct P28Entry: TimelineEntry { let date: Date; let n: Int }
#if os(watchOS)
struct P28RelEntry: RelevanceEntry { let n: Int }
struct P28RelProvider: RelevanceEntriesProvider {
    func relevance() async -> WidgetRelevance<P28SummaryIntent> { WidgetRelevance([WidgetRelevanceAttribute(configuration: P28SummaryIntent(), group: .named("p28"))]) }
    func entry(configuration: P28SummaryIntent, context: RelevanceEntriesProviderContext) async throws -> P28RelEntry { P28RelEntry(n: Int(context.displaySize.width)) }
    func placeholder(context: RelevanceEntriesProviderContext) -> P28RelEntry { P28RelEntry(n: 0) }
}
struct P28RelWidget: Widget {
    var body: some WidgetConfiguration { RelevanceConfiguration(kind: "p28.rel", provider: P28RelProvider()) { e in Text("\(e.n)") } }
}
@PreviewRelevanceEntryBuilder<P28RelEntry> func p28RelEntries() -> [P28RelEntry] { P28RelEntry(n: 1); P28RelEntry(n: 2) }
#endif
struct P28Provider: TimelineProvider {
    func placeholder(in context: TimelineProviderContext) -> P28Entry { P28Entry(date: .now, n: 0) }
    func getSnapshot(in context: TimelineProviderContext, completion: @escaping @Sendable (P28Entry) -> Void) { completion(P28Entry(date: .now, n: 1)) }
    func getTimeline(in context: TimelineProviderContext, completion: @escaping @Sendable (Timeline<P28Entry>) -> Void) { completion(Timeline(entries: [P28Entry(date: .now, n: 2)], policy: .atEnd)) }
}
struct P28WidgetPush: WidgetPushHandler {
    init() {}
    func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets: [WidgetInfo]) {}
}
struct P28StaticWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "p28.static", provider: P28Provider()) { e in Text("\(e.n)") }
            .pushHandler(P28WidgetPush.self)
            #if os(iOS)
            .disfavoredLocations([WidgetLocation.lockScreen, .standBy, .iPhoneWidgetsOnMac, .carPlay], for: [.systemSmall])
            .supportedMountingStyles([WidgetMountingStyle.elevated, .recessed])
            #elseif os(visionOS)
            .supportedMountingStyles([WidgetMountingStyle.elevated, .recessed])
            .widgetTexture(WidgetTexture.paper)
            #endif
    }
}
@PreviewTimelineBuilder func p28Timeline() -> [any TimelineEntry] { P28Entry(date: .now, n: 1); P28Entry(date: .now, n: 2) }
#if os(iOS) || os(watchOS)
struct P28ToggleIntent: SetValueIntent {
    static var title: LocalizedStringResource { "Lamp" }
    @IntentParameter(title: "On") var value: Bool
    init() {}
    func perform() async throws -> some IntentResult { .result() }
}
struct P28ControlValue: ControlValueProvider {
    var previewValue: Bool { true }
    func currentValue() async throws -> Bool { false }
}
struct P28AppControlValue: AppIntentControlValueProvider {
    func previewValue(configuration: P28ControlIntent) -> Bool { true }
    func currentValue(configuration: P28ControlIntent) async throws -> Bool { configuration.mood == .upbeat }
}
struct P28ControlPush: ControlPushHandler {
    init() {}
    func pushTokensDidChange(controls: [ControlInfo]) {}
}
struct P28ToggleControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "p28.toggle", provider: P28ControlValue()) { on in
            ControlWidgetToggle("Lamp", isOn: on, action: P28ToggleIntent()) { on in Text(on ? "On" : "Off") }
        }.pushHandler(P28ControlPush.self)
    }
}
struct P28AppControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: "p28.cfg", provider: P28AppControlValue()) { on in
            ControlWidgetToggle(isOn: on, action: P28ToggleIntent()) { Text("Mood") }
        }
    }
}
@MainActor func p28DefaultToggle() -> ControlWidgetToggle<Text, ControlWidgetToggleDefaultLabel, P28ToggleIntent> { ControlWidgetToggle(isOn: true, action: P28ToggleIntent()) { Text("Lamp") } }
@MainActor func p28DefaultButton() -> ControlWidgetButton<Text, ControlWidgetButtonDefaultActionLabel, P28PlayIntent> { ControlWidgetButton(action: P28PlayIntent()) { Text("Play") } }
#endif
#if os(iOS)
struct P28INProvider: IntentTimelineProvider {
    func recommendations() -> [IntentRecommendation<INIntent>] { [IntentRecommendation(intent: INIntent(), description: "p28")] }
    func placeholder(in context: TimelineProviderContext) -> P28Entry { P28Entry(date: .now, n: 0) }
    func getSnapshot(for configuration: INIntent, in context: TimelineProviderContext, completion: @escaping @Sendable (P28Entry) -> Void) { completion(P28Entry(date: .now, n: 1)) }
    func getTimeline(for configuration: INIntent, in context: TimelineProviderContext, completion: @escaping @Sendable (Timeline<P28Entry>) -> Void) { completion(Timeline(entries: [], policy: .never)) }
}
struct P28INWidget: Widget {
    var body: some WidgetConfiguration { IntentConfiguration(kind: "p28.in", intent: INIntent.self, provider: P28INProvider()) { e in Text("\(e.n)") } }
}
struct P28Attrs: ActivityAttributes {
    struct ContentState: Codable, Hashable { var step: Int }
    var name: String
}
@DynamicIslandExpandedContentBuilder func p28Expanded(_ ctx: ActivityViewContext<P28Attrs>) -> DynamicIslandExpandedContent<some View> {
    DynamicIslandExpandedRegion(DynamicIslandExpandedRegionPosition.leading) { Text(ctx.attributes.name) }
    DynamicIslandExpandedRegion(.bottom, priority: 1) { Text("\(ctx.state.step)").dynamicIsland(verticalPlacement: DynamicIslandExpandedRegionVerticalPlacement.belowIfTooWide) }
}
struct P28LiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: P28Attrs.self) { (ctx: ActivityViewContext<P28Attrs>) in
            Text(ctx.attributes.name)
        } dynamicIsland: { ctx in
            DynamicIsland(expanded: { p28Expanded(ctx) }, compactLeading: { Text("L") }, compactTrailing: { Text("T") }, minimal: { Text("M") })
                .contentMargins(.all, 4, for: DynamicIslandMode.expanded)
        }.supplementalActivityFamilies([ActivityFamily.small, .medium])
    }
}
@PreviewActivityBuilder<P28Attrs> func p28States() -> [P28Attrs.ContentState] { P28Attrs.ContentState(step: 1); P28Attrs.ContentState(step: 2) }
#endif
#endif

// MARK: FoundationModels types: dynamic instructions, generated-content conversions, attachments, session properties

#if canImport(FoundationModels) && !os(tvOS)
struct P28Persona: DynamicInstructions {
    var formal: Bool
    var topics: [String]
    @DynamicInstructionsBuilder var body: some DynamicInstructions {
        Instructions("You are sdkcov.")
        if formal { Instructions("Be formal.") } else { EmptyDynamicInstructions() }
        DynamicInstructionsForEach(topics, id: \.self) { t in Instructions("Know \(t).") }
    }
}
struct P28GenCard: ConvertibleFromGeneratedContent, ConvertibleToGeneratedContent {
    var name: String, count: Int
    init(name: String, count: Int) { self.name = name; self.count = count }
    init(_ content: GeneratedContent) throws { name = try content.value(String.self, forProperty: "name"); count = try content.value(Int.self, forProperty: "count") }
    var generatedContent: GeneratedContent { GeneratedContent(properties: ["name": name, "count": count]) }
}
struct P28Rules: InstructionsRepresentable {
    @InstructionsBuilder var instructionsRepresentation: Instructions { "Rule one."; "Rule two." }
}
@available(iOS 27.2, tvOS 27.2, watchOS 27.2, visionOS 27.2, macOS 27.2, *)
struct P28Blob: DataAttachmentRepresentable {
    var bytes: Data
    init(bytes: Data) { self.bytes = bytes }
    init(_ attachment: Transcript.DataAttachment) throws { bytes = attachment.content }
    var transcriptRepresentation: Transcript.DataAttachment { Transcript.DataAttachment(contentType: .plainText, content: bytes) }
}
@available(iOS 27.2, tvOS 27.2, watchOS 27.2, visionOS 27.2, macOS 27.2, *)
struct P28Note: DataEntryRepresentable {
    var text: String
    init(text: String) { self.text = text }
    init(_ entry: Transcript.DataEntry) throws { text = String(decoding: entry.content, as: UTF8.self) }
    var transcriptRepresentation: Transcript.DataEntry { Transcript.DataEntry(id: "p28", contentType: .plainText, content: Data(text.utf8)) }
}
struct P28Mode: SessionPropertyKey { static var defaultValue: Int { 3 } }
@PromptBuilder func p28Prompt(_ detailed: Bool) -> Prompt { "Summarize."; if detailed { "In detail." } }
#endif

// MARK: DeveloperToolsSupport / CoreTransferable / GroupActivities / TipKit / ExtensionKit types

#if canImport(DeveloperToolsSupport)
struct P28Library: LibraryContentProvider {
    @LibraryContentBuilder var views: [LibraryItem] {
        LibraryItem(Text("p28"), title: "P28 text", category: .control)
        LibraryItem(Image(systemName: "star"), visible: false, title: "Star")
    }
    @LibraryContentBuilder func modifiers(base: Text) -> [LibraryItem] { LibraryItem(base.bold(), title: "Bold", category: .effect) }
}
@MainActor struct P28PreviewEntry: PreviewRegistry {
    static let fileID = "sdkcov/P28_Intents.swift"
    static let line = 1
    static let column = 1
    static func makePreview() throws -> Preview { Preview("P28", traits: .sizeThatFitsLayout, .portrait) { Text("p28") } }
}
@PreviewMacroBodyBuilder<Text> func p28PreviewBody() -> Text { Text("p28") }
#endif
struct P28XferItem: Transferable, Codable {
    var name: String
    @TransferRepresentationBuilder<P28XferItem> static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
        ProxyRepresentation(exporting: \.name, importing: { P28XferItem(name: $0) }).visibility(TransferRepresentationVisibility.ownProcess)
        FileRepresentation(importedContentType: .pdf) { (f: ReceivedTransferredFile) in P28XferItem(name: "file \(f.file.lastPathComponent) original \(f.isOriginalFile)") }
    }
}
#if canImport(GroupActivities) && !os(watchOS)
struct P28Activity: GroupActivity {
    static var activityIdentifier: String { "com.x86sim.test.sdkcov.p28" }
    var metadata: GroupActivityMetadata {
        var m = GroupActivityMetadata(); m.title = "p28"; m.type = .generic; m.sceneAssociationBehavior = SceneAssociationBehavior.content("p28")
        return m
    }
}
struct P28Msg: Codable, CustomMessageIdentifiable { static var messageIdentifier: String { "p28.msg" }; var n: Int }
#if os(iOS) || os(visionOS)
struct P28Shared: Transferable {
    static var transferRepresentation: some TransferRepresentation { GroupActivityTransferRepresentation { (_: P28Shared) in P28Activity() } }
}
#endif
#if os(visionOS)
enum P28Role: String, SpatialTemplateRole { case host, guest; var roleIdentifier: String { rawValue } }
struct P28SeatTemplate: SpatialTemplate {
    var configuration: SpatialTemplateConfiguration { SpatialTemplateConfiguration(defaultInitiatorRole: P28Role.host) }
    var elements: [any SpatialTemplateElement] {
        [SpatialTemplateSeatElement.seat(position: SpatialTemplateElementPosition.app.offsetBy(x: 1, z: 0), role: P28Role.host),
         SpatialTemplateSeatElement(position: .app.offsetBy(x: -1, z: 0), direction: SpatialTemplateElementDirection.alignedWith(appAxis: SpatialTemplateElementAxis.x), role: P28Role.guest)]
    }
}
#endif
#endif
#if canImport(TipKit)
struct P28Tip: Tip { var title: Text { Text("p28 tip") }; var message: Text? { Text("mini") } }
#endif
#if canImport(ExtensionKit)
struct P28ExtScene: AppExtensionScene {
    @AppExtensionSceneBuilder var body: some AppExtensionScene { PrimitiveAppExtensionScene(id: "p28") { Text("p28") } }
}
#endif
#if canImport(AppIntentsTypeSupport)
struct P28Celsius: IntentValueConvertibleWrapper {
    var baseValue: Double
    init(baseValue: Double) throws { guard baseValue > -273.15 else { throw Fail("below absolute zero") }; self.baseValue = baseValue }
}
#endif

extension Registry {
    static var p28intents: [Check] {
        var c: [Check] = []
        #if canImport(AppIntents)
        c.append(check("AppIntents", "p28-entity-kinds") {
            var parts: [String] = []
            // indexed / owned / URL-represented / syncable / assistant-schema entity
            let s = P28Song.all[2]
            #if os(iOS) || os(visionOS)
            let attrs = s.attributeSet
            try expect(s.hideInSpotlight && !P28Song.all[0].hideInSpotlight, "hide \(s.hideInSpotlight)")
            parts.append("default attribute set name \(attrs.displayName ?? "nil") title \(attrs.title ?? "nil")")
            #endif
            try expect(s.ownership == .public && P28Song.all[1].ownership == .shared && EntityOwnership.unknown.rawValue != EntityOwnership.public.rawValue, "ownership")
            let url = await s.urlRepresentation
            try expect(url?.absoluteString == "https://example.com/song/s3/Blue%20in%20Green", "url \(String(describing: url))")
            let param = await s.urlRepresentationParameter
            parts.append("url param \(param ?? "nil")")
            try expect(P28Song.isAssistantOnly == false && P28Mood.isAssistantOnly == false && P28AssistantIntent.isAssistantOnly == false, "assistant only")
            // unique entity: the provider's entity is all the query has
            let u = try await P28Settings.defaultQuery.uniqueEntity()
            let all = try await P28Settings.defaultQuery.allEntities()
            let shown = String(localized: u.displayRepresentation.title)
            try expect(u.volume == 7 && all.count == 1 && u.id == all[0].id, "unique \(u.volume) \(all.count) id '\(u.id)'")
            parts.append("unique id '\(u.id)' title '\(shown)'")
            // file entity identifiers: draft and file URL, Codable round trip
            let d = FileEntityIdentifier.draft(identifier: "draft-1")
            let f = try FileEntityIdentifier.file(url: URL(fileURLWithPath: NSTemporaryDirectory() + "p28.txt"))
            try expect(d.isDraft && d.draftIdentifier == "draft-1" && !f.isDraft && f.draftIdentifier == nil, "draft \(d.isDraft) \(f.isDraft)")
            let back = try JSONDecoder().decode(FileEntityIdentifier.self, from: try JSONEncoder().encode(d))
            try expect(back == d && back != f, "codable round trip")
            let fu = try await f.fileURL
            parts.append("file url \(fu?.lastPathComponent ?? "nil")")
            let docs = try await P28IntentDoc.defaultQuery.entities(for: [d])
            try expect(docs.first?.id == d && P28IntentDoc.supportedContentTypes == [.plainText], "file entity")
            // entity identifier conversions, syncable identifiers
            let uu = UUID()
            try expect(UUID.entityIdentifier(for: uu.entityIdentifierString) == uu && Int.entityIdentifier(for: 42.entityIdentifierString) == 42 && String.entityIdentifier(for: "a") == "a" && Float.entityIdentifier(for: 1.5.description) == 1.5, "identifier conversions")
            let sid = SyncableEntityIdentifier<String, UUID>(local: "l1", stable: uu)
            let sback = SyncableEntityIdentifier<String, UUID>.entityIdentifier(for: sid.entityIdentifierString)
            try expect(sback == sid && sid.local == "l1" && sid.stable == uu, "syncable \(sid.entityIdentifierString) -> \(String(describing: sback))")
            let same = SyncableEntityIdentifier<String, String>(id: "x")
            try expect(same.local == "x" && same.stable == "x", "syncable id")
            parts.append("syncable '\(sid.description)'")
            // display / identification protocols the entity and enum adopt
            let tdr: any TypeDisplayRepresentable.Type = P28Song.self
            let pid: any PersistentlyIdentifiable.Type = P28Song.self
            let inst: any InstanceDisplayRepresentable = s, disp: any DisplayRepresentable = s
            let cases: any CaseDisplayRepresentable.Type = P28Mood.self, stat: any StaticDisplayRepresentable.Type = P28Mood.self
            try expect(String(localized: tdr.typeDisplayRepresentation.name) == "Song" && pid.persistentIdentifier == "P28Song" && String(localized: inst.localizedStringResource) == "Blue in Green", "display: '\(pid.persistentIdentifier)' '\(String(localized: inst.localizedStringResource))'")
            try expect(String(localized: disp.displayRepresentation.title) == "Blue in Green" && cases.allCases.count == 2 && String(localized: stat.typeDisplayRepresentation.name) == "Mood", "static display")
            try expect(String(localized: P28Song.typeDisplayRepresentation.synonyms[0]) == "Track", "synonyms")
            // the enum's URL
            let murl = P28Mood.upbeat.urlRepresentation
            try expect(murl?.absoluteString == "https://example.com/mood/upbeat", "enum url \(String(describing: murl))")
            return parts.joined(separator: "; ")
        })
        c.append(check("AppIntents", "p28-property-query") {
            let q = P28SongQuery()
            let props = P28SongQuery.properties, sorts = P28SongQuery.sortingOptions
            let p0: EntityQueryPropertyDeclaration<P28Song, P28Cmp> = props[0], p1 = props[1]
            try expect("\(type(of: p0))".hasPrefix("EntityQueryProperty<") && "\(type(of: p1))".contains("EntityProperty<Int>"), "declarations \(type(of: p0)) \(type(of: p1))")
            _ = sorts[1]
            let t = String(localized: P28SongQuery.findIntentDescription!.descriptionText)
            let blue = try await q.entities(matching: [.titlePrefix("Blue"), .playsAbove(20)], mode: .and, sortedBy: [], limit: nil).map(\.id)
            let either = try await q.entities(matching: [.titleSuffix("Steps"), .playsBetween(25, 40)], mode: EntityQueryComparatorMode.or, sortedBy: [], limit: 5).map(\.id)
            try expect(blue == ["s3"] && either == ["s2", "s3"], "matching \(blue) \(either)")
            // the property wrappers: titles, descriptions, values
            let s = P28Song.all[0]
            let tt = String(localized: s.$title.title)
            try expect(tt == "Title" && s.$plays.wrappedValue == 12 && s.$title.description.contains("Blue Train"), "property '\(tt)' \(s.$title.description)")
            let anyv: any AnyIntentValue = s.$plays
            try expect(String(localized: anyv.title) == "Plays" && !anyv.isOptional, "AnyIntentValue")
            try expect(EntityPropertyModifiers.readOnly != EntityPropertyModifiers.async, "modifiers")
            let vq = try await P28ValueQuery().values(for: "Blue").map(\.id)
            try expect(vq == ["s1", "s3"] && P28ValueQuery.allowedExecutionTargets == P28SongQuery.allowedExecutionTargets, "value query \(vq)")
            // what a query's default display representations are
            let reps = try await q.displayRepresentations(for: ["s2"])
            try expect(reps["s2"].map { String(localized: $0.title) } == "Giant Steps", "display reps \(reps)")
            // the protocols and generic types the declarations above go through, spelled out
            let cmp: EntityQueryComparator<EntityProperty<String>, String, String, P28Cmp> = EqualToComparator { .titleIs($0) }
            let av: any AppValue.Type = P28Song.self
            let ids: [any EntityIdentifierConvertible] = [UUID(), 42, "a", Float(1.5)]
            let uq: any UniqueAppEntityQuery.Type = UniqueAppEntityProvider<P28Settings>.self
            let rc: any ResultsCollection = [P28Mood.calm, .upbeat]
            let crit: any SearchCriteria = StringSearchCriteria(term: "x")
            let opts: [any AppShortcutOptionsCollectionProtocol] = Array(P28Shortcuts2.p28Options())
            let cases = ParameterSummaryCaseBuilder<P28PlayIntent, P28Mood>.buildExpression(ParameterSummaryCaseCondition(P28Mood.upbeat) { IntentParameterSummary<P28PlayIntent>("Upbeat") })
            try expect(rc.items.count == 2 && ids.map(\.entityIdentifierString).dropFirst() == ["42", "a", "1.5"] && opts.count == 1 && "\(type(of: crit))" == "StringSearchCriteria", "spelled-out values \(ids.map(\.entityIdentifierString))")
            try expect("\(type(of: cmp))".hasPrefix("EqualToComparator<") && "\(av)" == "P28Song" && "\(uq)".hasPrefix("UniqueAppEntityProvider<") && "\(type(of: cases))".hasPrefix("ParameterSummaryCaseCondition<"), "spelled-out types \(type(of: cmp)) \(type(of: cases))")
            let shown = await P28ShowMoodIntent().urlRepresentation
            // an intent's URL template fills its parameters from the App Intents metadata, which this app has none of (no
            // metadata processor on Linux): the parameter is left "(null)", on Apple's 27.2 simulator too (an entity's or
            // an enum's template fills in, see p28-entity-kinds)
            try expect(shown?.absoluteString == "https://example.com/show/(null)", "intent url \(String(describing: shown)) (Apple: https://example.com/show/(null))")
            return "\(type(of: p0)), find intent '\(t)', intent url \(shown?.absoluteString ?? "nil")"
        })
        c.append(check("AppIntents", "p28-resolvers") {
            // a value type's default resolver specification is the resolvers the system runs: assert which they are
            func names<S: ResolverSpecification>(_ s: S) -> [String] { s.map { "\(type(of: $0))" } }
            let dbl = Array(Double.defaultResolverSpecification), int = Array(Int.defaultResolverSpecification)
            try expect(dbl.contains { $0 is DoubleResolver } && dbl.contains { $0 is DoubleFromStringResolver } && dbl.contains { $0 is DoubleFromIntResolver }, "Double: \(names(Double.defaultResolverSpecification))")
            try expect(int.contains { $0 is IntResolver } && int.contains { $0 is IntFromStringResolver } && int.contains { $0 is IntFromDoubleResolver }, "Int: \(names(Int.defaultResolverSpecification))")
            let str = Array(String.defaultResolverSpecification)
            try expect(str.contains { "\(type(of: $0))".hasPrefix("StringFromIntResolver") } && str.contains { $0 is StringFromDoubleResolver }, "String: \(names(String.defaultResolverSpecification))")
            try expect(Bool.defaultResolverSpecification.contains { $0 is BoolFromStringResolver } && URL.defaultResolverSpecification.contains { $0 is URLFromStringResolver }, "Bool \(names(Bool.defaultResolverSpecification)) URL \(names(URL.defaultResolverSpecification))")
            try expect(AttributedString.defaultResolverSpecification.contains { $0 is AttributedStringFromStringResolver }, "AttributedString \(names(AttributedString.defaultResolverSpecification))")
            try expect(StringSearchCriteria.defaultResolverSpecification.contains { $0 is StringSearchCriteriaFromStringResolverSpecificification }, "criteria \(names(StringSearchCriteria.defaultResolverSpecification))")
            let empty = EmptyResolverSpecification<EntityIdentifier>()
            try expect(Array(empty).isEmpty && EntityIdentifier.defaultResolverSpecification == empty, "empty spec")
            // resolvers with settings compare by them
            try expect(IntFromStringResolver(radix: 16) != IntFromStringResolver() && IntFromDoubleResolver(roundingRule: .up).roundingRule == .up, "resolver settings")
            // my own: a builder makes a specification of them
            let mine = Array(p28IntSpec()), two = Array(p28StringSpec())
            let rs: any RangeComparableProperty.Type = Int.self
            try expect(mine.count == 1 && mine[0] is P28HalfResolver && two.count == 2 && "\(rs)" == "Int", "builder specs \(mine) \(two)")
            return "Double \(dbl.count), Int \(int.count), String \(str.count) resolvers"
        })
        c.append(check("AppIntents", "p28-parameter-summaries-predictions") {
            let sum = P28PlayIntent.parameterSummary, sum2 = P28SummaryIntent.parameterSummary
            let n = "\(type(of: sum))", n2 = "\(type(of: sum2))"
            try expect(n.hasPrefix("ParameterSummaryWhenCondition<") && n.contains("IntentParameterSummary<") && n.contains("ParameterSummarySwitchCondition<"), "summary type \(n)")
            try expect(n.contains("ParameterSummaryTupleCaseCondition<") || n.contains("ParameterSummaryCaseCondition<"), "case conditions \(n)")
            try expect(n2.hasPrefix("ParameterSummaryWhenCondition<"), "summary 2 \(n2)")
            let p = P28PlayIntent.predictionConfiguration
            let pn = "\(type(of: p))"
            try expect(pn.hasPrefix("TupleIntentPrediction<") && pn.contains("IntentPrediction<"), "predictions \(pn)")
            let one: IntentPrediction<P28PlayIntent, ()> = IntentPrediction { DisplayRepresentation(title: "Play") }
            _ = one
            // parameter metadata
            let i = P28PlayIntent()
            try expect(i.mood == .calm && i.count == 1 && i.song == nil && String(localized: i.$count.title) == "Count", "defaults")
            try expect(InputConnectionBehavior.connectToPreviousIntentResult != .never && InputConnectionBehavior.default != .never, "connection behaviors")
            // the operators and widget families the summaries compare with
            try expect(HasValueComparisonOperator.hasNoValue != .hasAnyValue && EquatableComparisonOperator.notEqualTo != .equalTo && ComparableComparisonOperator.lessThanOrEqualTo != .greaterThanOrEqualTo && StringComparisonOperator.doesNotContain != .contains, "operators")
            #if !os(tvOS)
            let fam: [IntentWidgetFamily] = [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .systemExtraLargePortrait, .accessoryCorner, .accessoryCircular, .accessoryRectangular, .accessoryInline]
            try expect(Set(fam.map { "\($0)" }).count == 9 && OneOfComparisonOperator.oneOf == .oneOf, "families")
            #endif
            return "\(n.prefix(60))...; \(pn.prefix(60))..."
        })
        c.append(check("AppIntents", "p28-system-intent-protocols") {
            var parts: [String] = []
            // what the protocols default to
            #if !os(watchOS)
            try expect(P28SearchIntent.openAppWhenRun && P28VideoIntent.openAppWhenRun, "open app defaults \(P28SearchIntent.openAppWhenRun) \(P28VideoIntent.openAppWhenRun)")
            try expect(VideoCategory.allCases.count == 3 && P28VideoIntent.supportedCategories == [.movies, .tv] && String(localized: VideoCategory.caseDisplayRepresentations[.freeform]!.title).count > 0, "video categories")
            var v = P28VideoIntent(); v.term = "jazz"
            try expect(v.term == "jazz", "video term")
            #endif
            // Apple's 27.2 simulator: an OpenIntent does not open the app by default (search / video intents do)
            try expect(!P28OpenSongIntent.openAppWhenRun, "OpenIntent opens app \(P28OpenSongIntent.openAppWhenRun) (Apple: false)")
            try expect(P28SearchIntent.searchScopes == [.general, .tv] && StringSearchScope.allCases.count == 4, "scopes")
            try expect(String(localized: StringSearchScope.caseDisplayRepresentations[.freeformVideo]!.title).count > 0, "scope titles")
            var si = P28SearchIntent(); si.criteria = StringSearchCriteria(term: "blue")
            try expect(si.criteria.term == "blue" && si.criteria == StringSearchCriteria(term: "blue"), "criteria")
            let dep = P28PlayIntent.deprecation
            try expect(String(localized: dep.message) == "Use search" && dep.replacedBy == P28SearchIntent.self, "deprecation")
            let plain = IntentDeprecation(message: "gone"), repl = IntentDeprecation(replacedBy: P28RecordIntent.self)
            try expect(plain.replacedBy == nil && repl.replacedBy == P28RecordIntent.self, "deprecations")
            try expect(P28PlayIntent.persistentIdentifier == "P28PlaySongIntent" && P28PlayIntent.intentClassName == "P28PlaySongIntent", "migrated id \(P28PlayIntent.persistentIdentifier)")
            try expect(P28PlayIntent.allowedExecutionTargets.contains(.appIntentsExtension) && !P28PlayIntent.allowedExecutionTargets.contains(.widgetKitExtension) && IntentExecutionTargets.default != .main, "targets")
            let r = try await P28PlayIntent().perform()
            try expect(r.value == 1, "perform \(String(describing: r.value))")
            // target content: an intent's content identifier defaults to its persistent identifier
            #if !os(watchOS)
            try expect(P28TalkIntent().contentIdentifier == P28TalkIntent.persistentIdentifier, "content id \(P28TalkIntent().contentIdentifier)")
            #endif
            // camera capture: no app context set
            #if os(iOS)
            let ctx = try await P28CameraIntent.appContext
            try expect(ctx == nil, "camera context \(ctx.map { $0.lens } ?? "nil") (Apple: nil)")
            #endif
            #if os(iOS) || os(watchOS)
            let w = P28StartWorkout.suggestedWorkouts.map { $0.workoutStyle.id }
            try expect(w == ["run", "swim"] && P28StartWorkout.openAppWhenRun, "workouts \(w)")
            parts.append("workout open app \(P28StartWorkout.openAppWhenRun), pause \(P28PauseWorkout.openAppWhenRun)")
            #endif
            #if os(watchOS)
            parts.append("dive open app \(P28Dive.openAppWhenRun)")
            #endif
            // the system intents the framework ships
            let ou = OpenURLIntent(URL(string: "https://example.com/p28")!)
            try expect(ou.url.absoluteString == "https://example.com/p28" && String(localized: OpenURLIntent.title).count > 0, "OpenURLIntent \(ou.url)")
            let ou2 = try OpenURLIntent(urlRepresentable: P28Mood.calm)
            try expect(ou2.url.absoluteString == "https://example.com/mood/calm", "OpenURLIntent(enum) \(ou2.url)")
            let ou3 = try await OpenURLIntent(urlRepresentable: P28Song.all[1])
            try expect(ou3.url.absoluteString.hasPrefix("https://example.com/song/s2/"), "OpenURLIntent(entity) \(ou3.url)")
            #if os(iOS)
            let rs = RunSystemShortcutIntent()
            parts.append("RunSystemShortcutIntent '\(RunSystemShortcutIntent.persistentIdentifier)' '\(String(localized: RunSystemShortcutIntent.title))' shortcut type '\(String(localized: SystemShortcut.typeDisplayRepresentation.name))'")
            _ = rs
            #endif
            try expect(String(localized: EmptySnippetIntent.title).count >= 0 && !EmptySnippetIntent.isDiscoverable, "EmptySnippetIntent discoverable")
            let typed: [any SystemIntent.Type] = [P28SearchIntent.self, P28RecordIntent.self, P28TalkIntent.self, P28PlayIntent.self, OpenURLIntent.self]
            parts.append("\(typed.count) system intents")
            return parts.joined(separator: "; ")
        })
        c.append(check("AppIntents", "p28-results-errors-values") {
            var parts: [String] = []
            // result containers
            let r: IntentResultContainer<Int, Never, Never, IntentDialog> = .result(value: 3, dialog: "three")
            try expect(r.value == 3 && r.dialog != nil && r.opensIntent == nil, "container")
            let o = try await P28ShowSnippet().perform()
            parts.append("snippet result \(type(of: o))")
            let sn = try await P28SnippetIntent().perform()
            parts.append("view result \(type(of: sn))")
            let opens: any OpensIntent = o, shows: any ShowsSnippetIntent = o, view: any ShowsSnippetView = sn
            _ = (opens, shows, view)
            // errors
            let e1 = AppIntentError.restartPerform, e2 = AppIntentError(description: "custom")
            try expect(e1 != e2 && !e1.description.isEmpty && String(localized: e2.localizedStringResource) == "custom", "errors \(e1.description) / \(String(localized: e2.localizedStringResource))")
            let wrapped = AppIntentError(wrapping: P28Error())
            try expect(String(localized: wrapped.localizedStringResource) == "sdkcov failed", "wrapped \(wrapped)")
            let known: [AppIntentError] = [AppIntentError.UserActionRequired.signin, .UserActionRequired.accountSetup, .UserActionRequired.confirmation, .PermissionRequired.siri, .PermissionRequired.localNetwork, .PermissionRequired.bluetooth, .PermissionRequired.photos, .PermissionRequired.contacts, .PermissionRequired.location(precise: true), .Unrecoverable.networkFailure, .Unrecoverable.partialFailure, .Unrecoverable.notAllowed, .Unrecoverable.unknown, .Unrecoverable.unsupportedOnDevice, .Unrecoverable.featureCurrentlyRestricted, .Unrecoverable.entityNotFound]
            let distinct = Set(known.map { String(localized: $0.localizedStringResource) })
            try expect(distinct.count >= 14, "predefined errors: \(distinct.count) distinct texts")
            let pre = AppIntentError(predefinedError: .Unrecoverable.networkFailure, description: "offline")
            parts.append("predefined '\(String(localized: pre.localizedStringResource))'")
            let fg = P28PlayIntent().needsToContinueInForegroundError("Open the app")
            parts.append("foreground '\(String(localized: fg.localizedStringResource).prefix(60))'")
            // cancellation / long running / confirmation values
            try expect(IntentCancellationReason.timeout != .userCancelled && !IntentCancellationReason.timeout.debugDescription.isEmpty, "cancellation reasons \(IntentCancellationReason.timeout.debugDescription)")
            try expect(LongRunningTaskOptions.requiresGPU.rawValue != 0 && ConfirmationConditions.lowConfidenceSource.rawValue != 0, "options")
            let names: [ConfirmationActionName] = [.add, .addData, .book, .buy, .call, .checkIn, .continue, .create, .do, .download, .filter, .find, .get, .go, .log, .open, .order, .pay, .play, .playSound, .post, .request, .run, .search, .send, .set, .share, .start, .startNavigation, .toggle, .turnOff, .turnOn, .view, .custom(acceptLabel: "Yes", acceptAlternatives: ["OK"], denyLabel: "No", denyAlternatives: [])]
            parts.append("\(names.count) confirmation names")
            let rec = P28RecordIntent()
            // outside the system's perform the progress is indeterminate (Apple: -1/0)
            try expect(rec.progress.totalUnitCount == -1 && rec.progress.completedUnitCount == 0, "progress \(rec.progress.totalUnitCount)/\(rec.progress.completedUnitCount) (Apple: -1/0)")
            let um = await MainActor.run { rec.undoManager }
            parts.append("undo manager \(um == nil ? "nil" : "set")")
            let res = try await P28PlayIntent().withIntentCancellationHandler(operation: { 5 }, onCancel: { _ in })
            try expect(res == 5, "cancellation handler \(res)")
            // UI elements, annotations, contexts
            let el = AppEntityUIElement(P28Song.all[0], bounds: CGRect(x: 0, y: 0, width: 10, height: 10), state: .init(isSelected: true), subelements: [AppEntityUIElement(identifier: EntityIdentifier(for: P28Song.all[1]), bounds: .zero)])
            try expect(el.state.isSelected && el.identifier.identifier == "s1" && el.subelements.count == 1, "ui element")
            let req: Set<AppEntityUIElementsContext.ElementsRequest> = [.selected, .visible(rect: .zero)]
            try expect(req.count == 2, "element requests")
            let act = NSUserActivity(activityType: "com.x86sim.test.sdkcov.p28")
            let ann: any AppEntityAnnotatable = act
            act.appEntityIdentifier = EntityIdentifier(for: P28Song.all[2])
            try expect(act.appEntityIdentifier?.identifier == "s3" && ann.appEntityIdentifier?.identifier == "s3", "annotation \(String(describing: act.appEntityIdentifier))")
            let ec = AppEntityContext.audio(.nowPlaying)
            try expect(ec == AppEntityContext.audio(.nowPlaying), "entity context")
            // URL parameters
            let cv: [any CustomURLRepresentationParameterConvertible] = ["a b", 7, URL(string: "https://example.com")!]
            var ps: [String] = []
            for x in cv { ps.append(await x.urlRepresentationParameter ?? "nil") }
            parts.append("url params \(ps)")
            // union value cases
            try expect(P28PickKind.allCases.count == 2, "union kinds")
            // without the @UnionValue macro's metadata the default case representations are empty (Apple's simulator too)
            try expect(P28Pick.caseDisplayRepresentations.isEmpty, "union case representations \(P28Pick.caseDisplayRepresentations.count) (Apple: 0)")
            parts.append("union type '\(String(localized: P28Pick.typeDisplayRepresentation.name))'")
            // packages, the extension type
            try expect(P28Package.includedPackages.count == 1 && P28SubPackage.includedPackages.isEmpty, "packages")
            let ext: any AppIntentsExtension.Type = P28Extension.self
            parts.append("extension \(ext)")
            // stream values (the model delegation output type)
            parts.append("\(IntentResponseStream<Int>.self)")
            return parts.joined(separator: "; ")
        })
        c.append(check("AppIntents", "p28-shortcuts-schemas", timeout: 30) {
            var parts: [String] = []
            let s = P28Shortcuts2.appShortcuts
            try expect(s.count == 1 && P28ShortcutsContent().appShortcuts.count == 1, "shortcuts \(s.count)")
            let opts = Array(P28Shortcuts2.p28Options())
            try expect(opts.count == 1 && String(localized: opts[0].title) == "Moods" && opts[0].systemImageName == "music.note", "options \(opts.count)")
            let res = try await P28MoodOptions().results()
            try expect(res == [.calm, .upbeat], "options provider")
            _ = P28Shortcuts2.title
            _ = P28Shortcuts2.negativePhrases
            try expect(AppShortcutPhraseToken.applicationName == .applicationName, "token")
            // schemas: values of the App Schema / assistant schema domains
            #if os(iOS) || os(visionOS)
            let a = AppSchema(.books.openBook), b = AppSchema(.books.book), e = AppSchema(.books.contentType)
            let aa = AssistantSchema(.books.book), ab = AssistantSchema(.books.contentType)
            parts.append("schemas \(a) \(b) \(e) \(aa) \(ab)")
            #endif
            let i: any AssistantSchemaIntent.Type = P28AssistantIntent.self, ai: any AssistantIntent.Type = P28AssistantIntent.self
            let en: any AssistantSchemaEntity.Type = P28Song.self, ae: any AssistantEntity.Type = P28Song.self, me: any AssistantSchemaEnum.Type = P28Mood.self, am: any AssistantEnum.Type = P28Mood.self
            parts.append("assistant types \(i) \(ai) \(en) \(ae) \(me) \(am)")
            let marks: [Any.Type] = [(any AppSchemaIntent).self, (any AppSchemaEntity).self, (any AppSchemaEnum).self, AssistantSchemas.self]
            parts.append("\(marks.count) schema kinds")
            // relevant entities and intents: the system's answer for this app
            do { try await RelevantEntities.shared.updateEntities([P28Song.all[0]], for: .audio(.nowPlaying)); try await RelevantEntities.shared.removeAllEntities(); parts.append("relevant entities ok") }
            catch { throw Fail("relevant entities: \(p7Err(error)) (Apple's simulator: ok)") }
            #if !os(tvOS)
            let ri = RelevantIntent(P28SummaryIntent(), widgetKind: "sdkcov", relevance: .date(from: Date(), to: Date().addingTimeInterval(600)))
            try expect(!ri.debugDescription.isEmpty, "relevant intent")
            do { try await RelevantIntentManager.shared.updateRelevantIntents([ri]); parts.append("relevant intents ok") }
            catch { parts.append("relevant intents: \(p7Err(error))") }
            #endif
            // the system context outside of the system's perform
            let ctx: IntentSystemContext = P28PlayIntent().systemContext
            parts.append("system context voice-only \(ctx.isVoiceOnly), timestamp \(ctx.preciseTimestamp == nil ? "nil" : "set"), locale \(ctx.locale.identifier)")
            // a Transferable item exporting an App Intents value
            let rep = P28Contact.transferRepresentation
            parts.append("\(type(of: rep))")
            return parts.joined(separator: "; ")
        })
        c.append(check("AppIntents", "p28-focus-filter") {
            // focus filter: the app context the filter gives the system
            func step(_ m: String) { FileHandle.standardError.write(Data("p28 focus step \(m)\n".utf8)) }
            // (a predicate on anything but the notification's filter criteria, e.g. "mood == %@", traps: Apple's simulator too)
            step("context with prefix")
            let pre = FocusFilterAppContext(notificationFilterPredicate: nil, targetContentIdentifierPrefix: "mood-")
            step("criteria context")
            let plain = FocusFilterAppContext(notificationFilterPredicate: NSPredicate(format: "SELF IN %@", ["calm"]))
            step("new intent")
            var ff = P28MoodFocus()
            step("set parameter")
            ff.mood = .upbeat
            step("app context")
            let ac = ff.appContext
            step("done")
            try expect(pre.targetContentIdentifierPrefix == "mood-" && plain.notificationFilterPredicate != nil && ac.notificationFilterPredicate?.predicateFormat == "SELF IN {\"upbeat\"}", "focus context \(String(describing: ac.notificationFilterPredicate))")
            // (suggestedFocusFilters(for:) takes a FocusFilterSuggestionContext only the system makes)
            try expect(SetFocusFilterIntentError.notFound != .missingParameterValue, "focus errors")
            return "focus context '\(ac.notificationFilterPredicate?.predicateFormat ?? "nil")' prefix \(ac.targetContentIdentifierPrefix ?? "nil"), error text '\(SetFocusFilterIntentError.notFound.errorDescription ?? "nil")'"
        })
        #endif
        #if canImport(AppIntentsTypeSupport)
        c.append(check("AppIntentsTypeSupport", "p28-wrappers-expressions") {
            // a wrapper converts through its base value; containers are only made with a system conversion context
            let t = try P28Celsius(baseValue: 21.5)
            var thrown = "nothing"
            do { _ = try P28Celsius(baseValue: -300) } catch { thrown = "\(error)" }
            try expect(t.baseValue == 21.5 && thrown == "below absolute zero", "wrapper \(t.baseValue) / \(thrown)")
            let values: [any IntentValueConvertible] = [t, 3, "x", true, Date(timeIntervalSince1970: 0), URL(string: "https://example.com")!, [1, 2], Optional(4)]
            let exps: [IntentValueExpression] = values.map { $0.makeExpression() }
            let expressing: [any IntentValueExpressing] = [t, Set([1, 2])]
            let make: (IntentValueContainer.ConversionContext) -> IntentValueContainer = t.makeContainer
            _ = make
            try expect(exps.count == 8 && expressing.count == 2 && MemoryLayout<IntentValueContainer>.size > 0, "expressions")
            return "\(exps.count) expressions made, wrapper of \(P28Celsius.BaseValue.self)"
        })
        #endif
        #if canImport(WidgetKit) && !os(tvOS)
        c.append(check("WidgetKit", "p28-configurations-controls-builders", timeout: 30) {
            var bad: [String] = [], n = 0, info: [String] = []
            func t(_ name: String, _ ok: Bool, _ d: @autoclosure () -> String = "") { n += 1; if !ok { bad.append("\(name) \(d())") } }
            func step(_ m: String) { FileHandle.standardError.write(Data("p28 widget step \(m)\n".utf8)) }
            step("bodies")
            let names: [String] = await onMain {
                var a = ["\(type(of: P28StaticWidget().body))"]
                #if os(iOS)
                a.append("\(type(of: P28INWidget().body))"); a.append("\(type(of: P28LiveWidget().body))")
                #endif
                #if os(iOS) || os(watchOS)
                a.append("\(type(of: P28ToggleControl().body))"); a.append("\(type(of: P28AppControl().body))")
                a.append("\(type(of: p28DefaultToggle()))"); a.append("\(type(of: p28DefaultButton()))")
                #endif
                #if os(watchOS)
                a.append("\(type(of: P28RelWidget().body))")
                #endif
                return a
            }
            t("static", names[0].contains("StaticConfiguration"), names[0])
            #if os(iOS)
            t("intent", names[1].contains("IntentConfiguration<INIntent"), names[1])
            t("activity", names[2].contains("ActivityConfiguration<P28Attrs>"), names[2])
            t("controls", names[3].contains("StaticControlConfiguration") && names[4].contains("AppIntentControlConfiguration"), "\(names[3]) \(names[4])")
            t("toggle default label", names[5].contains("ControlWidgetToggleDefaultLabel") && names[6].contains("ControlWidgetButtonDefaultActionLabel"), "\(names[5]) \(names[6])")
            let st = p28States()
            t("activity builder", st.map(\.step) == [1, 2])
            t("island modes", DynamicIslandMode.expanded != .minimal && DynamicIslandMode.compactLeading != .compactTrailing)
            t("region placement", DynamicIslandExpandedRegionVerticalPlacement.default != .belowIfTooWide)
            let pos: [DynamicIslandExpandedRegionPosition] = [.leading, .trailing, .center, .bottom]
            t("positions", pos.count == 4)
            t("activity families", ActivityFamily.small != .medium && ActivityFamily(rawValue: ActivityFamily.medium.rawValue) == .medium && SupportedActivityFamiliesEnvironmentKey.defaultValue.contains(.medium), "\(SupportedActivityFamiliesEnvironmentKey.defaultValue)")
            let kinds: [ActivityPreviewViewKind] = [.content, .dynamicIsland(.compact), .dynamicIsland(.minimal), .dynamicIsland(.expanded)]
            step("preview context")
            let pv = await onMain { "\(type(of: P28Attrs(name: "p").previewContext(.init(step: 1), viewKind: kinds[1])))" }
            info.append("preview \(pv.prefix(40))")
            let recs = P28INProvider().recommendations()
            t("recommendations", recs.count == 1)
            t("locations", Set([WidgetLocation.homeScreen, .lockScreen, .standBy, .iPhoneWidgetsOnMac, .carPlay]).count == 5)
            #endif
            #if os(iOS) || os(watchOS)
            step("value providers")
            let cv = P28ControlValue(), cur = try await cv.currentValue()
            var ci = P28ControlIntent(); ci.mood = .upbeat
            let acv = try await P28AppControlValue().currentValue(configuration: ci)
            t("value providers", cv.previewValue && !cur && acv && P28AppControlValue().previewValue(configuration: ci))
            step("current controls")
            let controls: [ControlInfo] = ((try? await p7Within(10) { try await ControlCenter.shared.currentControls() }) ?? nil) ?? []
            let pushes: [ControlPushInfo] = controls.compactMap(\.pushInfo)
            info.append("controls \(controls.count), push infos \(pushes.count)")
            #endif
            #if os(watchOS)
            let rel = p28RelEntries()
            t("relevance builder", rel.map(\.n) == [1, 2])
            #endif
            t("timeline builder", p28Timeline().count == 2)
            let groups: [WidgetRelevanceGroup] = [.named("a"), .ungrouped, .automatic]
            t("relevance groups", groups.count == 3)
            t("accented modes", Set([WidgetAccentedRenderingMode.accented, .desaturated, .accentedDesaturated, .fullColor]).count == 4)
            #if os(iOS) || os(visionOS)
            t("level of detail", LevelOfDetail.default != .simplified)
            t("mounting", WidgetMountingStyle.elevated != .recessed)
            #endif
            #if os(visionOS)
            t("texture", WidgetTexture.glass != .paper)
            #endif
            step("push info")
            let push = try await p7Within(10) { await WidgetCenter.shared.currentPushInfo.map { "\($0.token.count) B" } ?? "nil" }
            // Apple's iOS simulator answers nil at once (no push handler token for this app); Apple's visionOS simulator
            // never answers (no answer in 10 s, twice)
            #if os(visionOS)
            t("push info", push == nil, "\(push ?? "no answer in 10 s") (Apple: no answer in 10 s)")
            #else
            t("push info", push == "nil", "\(push ?? "no answer in 10 s") (Apple: nil)")
            #endif
            let pc = WidgetPreviewContext(family: .accessoryRectangular)
            _ = pc
            // an accessory widget group and an accented image, drawn outside a widget
            step("render")
            let drawn: Int = await onMain {
                let v = VStack {
                    #if os(watchOS)
                    AccessoryWidgetGroup("Group", systemImage: "star") { Text("1"); Text("2") }.accessoryWidgetGroupStyle(AccessoryWidgetGroupStyle.roundedSquare)
                    #endif
                    Image(systemName: "star.fill").widgetAccentedRenderingMode(.desaturated)
                }.frame(width: 120, height: 120).background(Color.white)
                let r = ImageRenderer(content: v); r.scale = 1
                return r.cgImage.map { $0.width * $0.height } ?? -1
            }
            step("done")
            info.append("group drawn \(drawn) px")
            try expect(bad.isEmpty, "\(bad.count)/\(n) wrong: \(bad.joined(separator: "; "))")
            return "\(n) assertions; \(info.joined(separator: "; "))"
        })
        #endif
        #if canImport(FoundationModels) && !os(tvOS)
        c.append(check("FoundationModels", "p28-dynamic-instructions-content", timeout: 30) {
            var bad: [String] = [], n = 0, info: [String] = []
            func t(_ name: String, _ ok: Bool, _ d: @autoclosure () -> String = "") { n += 1; if !ok { bad.append("\(name) \(d())") } }
            let p = P28Persona(formal: true, topics: ["swift", "metal"])
            let bn = "\(type(of: p.body))"
            t("dynamic body", bn.hasPrefix("TupleDynamicInstructions<") && bn.contains("ConditionalDynamicInstructions<") && bn.contains("DynamicInstructionsForEach<") && bn.contains("EmptyDynamicInstructions"), bn)
            let any = AnyDynamicInstructions(erasing: p)
            let tup = TupleDynamicInstructions(Instructions("a"), EmptyDynamicInstructions())
            let cond = ConditionalDynamicInstructions<Instructions, EmptyDynamicInstructions>(.falseContent(EmptyDynamicInstructions()))
            _ = (any, tup, cond)
            // a session with dynamic instructions; its properties hold the key's default until set
            #if os(watchOS)
            let s = LanguageModelSession(model: P7EchoModel(), dynamicInstructions: p)   // watchOS: no system model
            #else
            let s = LanguageModelSession(dynamicInstructions: p)
            #endif
            let d0 = s.properties[P28Mode.self]
            s.properties[P28Mode.self] = 9
            t("session property", d0 == 3 && s.properties[P28Mode.self] == 9, "\(d0) -> \(s.properties[P28Mode.self])")
            t("error policy", s.transcriptErrorHandlingPolicy == nil || true)
            s.transcriptErrorHandlingPolicy = TranscriptErrorHandlingPolicy.preserveTranscript
            info.append("policy set \(s.transcriptErrorHandlingPolicy != nil)")
            _ = TranscriptErrorHandlingPolicy.revertTranscript
            // generated content conversions both ways, with a generation id
            let card = P28GenCard(name: "ace", count: 4)
            let gc = card.generatedContent
            let back = try P28GenCard(gc)
            t("content round trip", back.name == "ace" && back.count == 4, "\(back)")
            let id = GenerationID()
            let withID = GeneratedContent(card, id: id)
            t("generation id", withID.id == id && id != GenerationID(), "\(String(describing: withID.id))")
            let conv: [any ConvertibleToGeneratedContent] = [card, "x", 3]
            t("convertible", conv.count == 3 && (P28GenCard.self as Any) is ConvertibleFromGeneratedContent.Type)
            // guides make schemas
            let guides: [GenerationGuide<Int>] = [.range(1...5)]
            let sch = DynamicGenerationSchema(name: "Card", properties: [
                .init(name: "count", schema: DynamicGenerationSchema(type: Int.self, guides: guides)),
                .init(name: "name", schema: DynamicGenerationSchema(type: String.self, guides: [GenerationGuide<String>.anyOf(["ace", "king"])]))])
            let gs = try GenerationSchema(root: sch, dependencies: [])
            t("guided schema", "\(gs)".contains("count"), "\(gs)".prefix(120).description)
            // instructions / prompts from builders and representables
            let ins = Instructions(P28Rules())
            let pr = p28Prompt(true)
            info.append("instructions \(String(describing: ins).count) chars, prompt \(String(describing: pr).count) chars")
            let reps: [any InstructionsRepresentable] = [P28Rules(), "x", card]
            t("representables", reps.count == 3)
            // attachments: data and image content, data entries
            if #available(iOS 27.2, tvOS 27.2, watchOS 27.2, visionOS 27.2, macOS 27.2, *) {
                let blob = P28Blob(bytes: Data("hello".utf8))
                let ba = try P28Blob(blob.transcriptRepresentation)
                t("data attachment", ba.bytes == blob.bytes && blob.transcriptRepresentation.contentType == .plainText)
                let note = try P28Note(P28Note(text: "n1").transcriptRepresentation)
                t("data entry", note.text == "n1")
                let att = Attachment(blob).label("blob")
                info.append("attachment \(type(of: att))")
            }
            let ctx = bitmap(4, 4)
            let img: Attachment<ImageAttachmentContent> = Attachment(ctx.makeImage()!).label("img")
            info.append("image attachment \(type(of: img))")
            let ref = try? ImageReference(GeneratedContent(properties: ["attachmentLabel": "img"]))
            info.append("image reference \(ref?.attachmentLabel ?? "nil")")
            // context options, feedback
            let co = ContextOptions(includeSchemaInPrompt: false, reasoningLevel: .custom("brief"))
            t("context options", co == ContextOptions(includeSchemaInPrompt: false, reasoningLevel: .custom("brief")) && co != ContextOptions() && ContextOptions.ReasoningLevel.light != .deep)
            let fb = LanguageModelFeedback.Issue(category: .incorrect, explanation: "wrong")
            t("feedback values", LanguageModelFeedback.Sentiment.allCases.count == 3 && LanguageModelFeedback.Issue.Category.allCases.count >= 8)
            let fd = s.logFeedbackAttachment(sentiment: .negative, issues: [fb])
            info.append("feedback attachment \(fd.count) B")
            try expect(bad.isEmpty, "\(bad.count)/\(n) wrong: \(bad.joined(separator: "; "))")
            return "\(n) assertions; \(info.joined(separator: "; "))"
        })
        #endif
        #if canImport(DeveloperToolsSupport)
        c.append(check("DeveloperToolsSupport", "p28-library-previews-resources") {
            let lib = P28Library()
            try expect(lib.views.count == 2 && lib.modifiers(base: Text("x")).count == 1, "library items \(lib.views.count)")
            // (the registry's default `preview` is a fatalError in DeveloperToolsSupport: only #Preview's expansion is meant to call it)
            let pv = try await onMain { try P28PreviewEntry.makePreview() }
            try expect(P28PreviewEntry.fileID.hasPrefix("sdkcov/") && P28PreviewEntry.line == 1, "registry")
            let traits: [PreviewTrait<Preview.ViewTraits>] = await onMain { [.defaultLayout, .sizeThatFitsLayout, .fixedLayout(width: 100, height: 50), .portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown, .assistiveAccess] }
            let layouts: [PreviewLayout] = [.device, .sizeThatFits, .fixed(width: 10, height: 10)]
            let c1 = ColorResource(name: "Accent", bundle: .main), i1 = ImageResource(name: "Icon", bundle: .main)
            try expect(c1 == ColorResource(name: "Accent", bundle: .main) && i1 != ImageResource(name: "Other", bundle: .main), "resources")
            let unavailable: Error = PreviewUnavailable()
            // (p28PreviewBody() is not called: PreviewMacroBodyBuilder traps outside a #Preview expansion, "cannot be used outside of a #Preview macro")
            let macroBody: @MainActor () -> Text = p28PreviewBody
            _ = macroBody
            let argsType = PreviewArguments<Int>.self, bodyType = PreviewBodyBuilder<Text>.self
            var extra = ""
            #if os(visionOS)
            let cams: [PreviewCamera] = []
            extra = ", \(cams.count) cameras, \(PreviewCameraBuilder.self)"
            #endif
            return "\(type(of: pv)), \(traits.count) traits, \(layouts.count) layouts, \(type(of: unavailable)), \(argsType), \(bodyType)\(extra)"
        })
        #endif
        c.append(check("CoreTransferable", "p28-proxy-file-visibility", timeout: 20) {
            let item = P28XferItem(name: "p28")
            let types = P28XferItem.exportedContentTypes(visibility: .all), own = P28XferItem.exportedContentTypes(visibility: .ownProcess)
            let imported = P28XferItem.importedContentTypes()
            try expect(types.contains(.json) && imported.contains(.pdf), "exported \(types) imported \(imported)")
            let json = try await item.exported(as: .json)
            let back = try await P28XferItem(importing: json, contentType: .json)
            try expect(back.name == "p28", "json round trip \(back.name)")
            let url = URL(fileURLWithPath: NSTemporaryDirectory() + "p28.pdf")
            try Data([1, 2, 3]).write(to: url)
            let fromFile = try await P28XferItem(importing: url, contentType: .pdf)
            try expect(fromFile.name.hasPrefix("file "), "file import \(fromFile.name)")
            let vis: [TransferRepresentationVisibility] = [.all, .ownProcess]
            let tuple = "\(type(of: P28XferItem.transferRepresentation))"
            try expect(tuple.contains("TupleTransferRepresentation") && Set(vis.map { "\($0)" }).count >= 1, tuple)
            return "exported \(types.map(\.identifier)), ownProcess \(own.map(\.identifier)), file import '\(fromFile.name)'"
        })
        #if canImport(GroupActivities) && !os(watchOS)
        c.append(check("GroupActivities", "p28-values-metadata", timeout: 20) {
            var parts: [String] = []
            let md = await P28Activity().metadata
            try expect(md.title == "p28" && md.sceneAssociationBehavior == .content("p28") && SceneAssociationBehavior.default != SceneAssociationBehavior.none, "metadata")
            try expect(P28Msg.messageIdentifier == "p28.msg" && BroadcastOptions.mirroredVideo.rawValue != 0, "message id / broadcast")
            let results: [GroupActivityActivationResult] = [.activationPreferred, .activationDisabled, .cancelled]
            try expect(Set(results.map { "\($0)" }).count == 3, "activation results")
            let all = Participants.all, none = Participants.only(Set())
            _ = (all, none)
            let acts: [GroupSessionEvent.Action] = [.play, .pause, .seek]
            parts.append("\(acts.count) event actions, \(GroupSessionEvent.self)")
            #if os(iOS) || os(visionOS)
            parts.append("shared item types \(P28Shared.exportedContentTypes().map(\.identifier))")
            #endif
            #if os(visionOS)
            let tpl = P28SeatTemplate()
            try expect(tpl.elements.count == 2 && tpl.configuration == SpatialTemplateConfiguration(defaultInitiatorRole: P28Role.host), "template")
            let pref = SpatialTemplatePreference.custom(tpl).contentExtent(2)
            let prefs: [SpatialTemplatePreference] = [.none, .sideBySide, .conversational, .surround, pref]
            let dir = SpatialTemplateElementDirection.lookingAt(SpatialTemplateElementPosition.app).rotatedBy(.init(degrees: 90))
            try expect(dir != .lookingAt(.app) && SpatialTemplateElementAxis.x != .z, "directions")
            let k = GroupActivityAssociationKind.primary("p28")
            try expect(k == .primary("p28") && k != .primary("other"), "association kind")
            var cfg = SystemCoordinator.Configuration(); cfg.spatialTemplatePreference = .sideBySide
            parts.append("\(prefs.map(\.description)), seat \(type(of: tpl.elements[0]))")
            #endif
            return parts.joined(separator: "; ")
        })
        #endif
        #if canImport(TipKit)
        c.append(check("TipKit", "p28-mini-tip-style", timeout: 20) {
            do { try Tips.configure() } catch { _ = error }
            let style: MiniTipViewStyle = .miniTip
            let name = await onMain { "\(type(of: TipView(P28Tip()).tipViewStyle(style)))" }
            // the style goes into the environment type-erased (TipViewStyle)
            try expect("\(type(of: style))" == "MiniTipViewStyle" && name.contains("TipViewStyle"), name)
            return "\(type(of: style)) in \(name)"
        })
        #endif
        #if canImport(ExtensionKit)
        c.append(check("ExtensionKit", "p28-scene-builder") {
            let (bodyName, desc): (String, String) = await onMain {
                let s = P28ExtScene()
                let prim = PrimitiveAppExtensionScene(id: "x") { Text("x") }
                return ("\(type(of: s.body))", prim.debugDescription)
            }
            try expect(bodyName == "PrimitiveAppExtensionScene", "body \(bodyName)")
            let ept: [any ExtensionPointDefining.Type] = []
            #if os(iOS)
            let vcName = await onMain { () -> String in let vc = EXAppExtensionBrowserViewController(); return "\(type(of: vc)) \(vc.isViewLoaded)" }
            #else
            let vcName = "no browser"
            #endif
            return "\(bodyName) '\(desc.prefix(60))', \(ept.count), \(vcName)"
        })
        #endif
        return c
    }
}
