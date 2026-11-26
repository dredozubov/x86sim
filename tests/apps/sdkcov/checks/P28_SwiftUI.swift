// SDK coverage, round 30 wave 2 (P28): public API of the SDK still not referenced by any check after P27
// (~/scratch/r30/apisurf.py), area: SwiftUI. Each check asserts what Apple's simulator answers (ref-mac.sh --only).
// SwiftUI: control / navigation / table / text editor styles and their configurations, navigation + zoom transitions,
// presentation sizing and dialogs, UIKit gesture representables, focused values, scroll target behaviors and
// transitions, tabs (sections, customization) and toolbars, search, Core Data fetch requests, tables / outlines /
// editable collections, drag and drop, documents, scenes and commands. SwiftUICore: text renderers + proxies, keyframes
// builders, animation state, hover effects, glass, shape styles. Charts: every mark, axis / annotation / scale / scroll /
// selection type, vectorized and function plots, 3D charts.
import Foundation
import Synchronization
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Charts)
import Charts
#endif
#if canImport(CoreData)
import CoreData
#endif
import UniformTypeIdentifiers

// MARK: helpers

private func p28R(_ r: CGRect) -> String { "\(Int(r.minX.rounded())),\(Int(r.minY.rounded())),\(Int(r.width.rounded())),\(Int(r.height.rounded()))" }
private func p28S(_ s: CGSize) -> String { "\(Int(s.width.rounded()))x\(Int(s.height.rounded()))" }
/// logs "<name> <w>x<h>" whenever the view's size changes
private struct P28Size: ViewModifier {
    let name: String; let log: P6Log
    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGSize.self) { $0.size } action: { log.add("\(name) \(p28S($0))") }
    }
}
extension View {
    fileprivate func p28Size(_ name: String, _ log: P6Log) -> some View { modifier(P28Size(name: name, log: log)) }
}
/// the last value logged as "<key> <value>"
private func p28Last(_ log: P6Log, _ k: String) -> String? { log.all.last { $0.hasPrefix(k + " ") }.map { String($0.dropFirst(k.count + 1)) } }
/// w x h of a "<w>x<h>" string
private func p28WH(_ s: String?) -> (Double, Double)? {
    guard let p = s?.split(separator: "x"), p.count == 2, let w = Double(p[0]), let h = Double(p[1]) else { return nil }
    return (w, h)
}
@MainActor private func p28Render<V: View>(_ v: V, _ w: CGFloat, _ h: CGFloat) -> CGImage? {
    let r = ImageRenderer(content: v.frame(width: w, height: h)); r.scale = 1
    return r.cgImage
}

#if !os(watchOS)
/// every view controller below `vc` (children + presented), depth first
@MainActor private func p28VCs(_ vc: UIViewController?) -> [UIViewController] {
    guard let vc else { return [] }
    return [vc] + vc.children.flatMap { p28VCs($0) } + p28VCs(vc.presentedViewController)
}
#endif

// MARK: generic style users: each takes any style of its protocol (PickerStyle, TextFieldStyle, ... cannot be
// implemented outside SwiftUI; apps pass them through generics like these)

private struct P28StyledPicker<S: PickerStyle>: View {
    let style: S; let name: String; let log: P6Log
    @State var sel = 1
    var body: some View {
        Picker("P", selection: $sel) { Text("one").tag(1); Text("two").tag(2) }.pickerStyle(style).p28Size(name, log)
    }
}
private struct P28StyledField<S: TextFieldStyle>: View {
    let style: S; let name: String; let log: P6Log
    @State var t = "text"
    var body: some View { TextField("f", text: $t).textFieldStyle(style).frame(width: 150).p28Size(name, log) }
}
private struct P28StyledGauge<S: GaugeStyle>: View {
    let style: S; let name: String; let log: P6Log
    var body: some View { Gauge(value: 0.4) { Text("g") } currentValueLabel: { Text("4") }.gaugeStyle(style).p28Size(name, log) }
}

/// a custom DatePickerStyle: its body shows the configuration's values
private struct P28DateStyle: DatePickerStyle {
    let log: P6Log
    func makeBody(configuration: DatePickerStyleConfiguration) -> some View {
        let c: DatePickerStyleConfiguration = configuration
        let f = ISO8601DateFormatter()
        log.add("date sel \(f.string(from: c.selection)) min \(c.minimumDate.map { f.string(from: $0) } ?? "nil") max \(c.maximumDate.map { f.string(from: $0) } ?? "nil") comps \(c.displayedComponents == .date ? "date" : "other")")
        return HStack { c.label; Button("next day") { c.selection = c.selection.addingTimeInterval(86400) } }
    }
}
/// custom TextField style: 10 pt padding + a border
private struct P28FieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View { configuration.padding(10).border(Color.red, width: 2) }
}
#if os(iOS) || os(visionOS)
/// custom text editor style: replaces the editor with a fixed-size marker
private struct P28EditorStyle: TextEditorStyle {
    func makeBody(configuration: TextEditorStyleConfiguration) -> some View { Color.orange.frame(width: 77, height: 33) }
}
private struct P28TableStyle: TableStyle {
    func makeBody(configuration: TableStyleConfiguration) -> some View { Color.purple.frame(width: 66, height: 22) }
}
#endif
private struct P28SplitStyle: NavigationSplitViewStyle {
    func makeBody(configuration: NavigationSplitViewStyleConfiguration) -> some View { Color.mint.frame(width: 55, height: 11) }
}
private struct P28AnyNavStyle<S: NavigationViewStyle>: View {
    let style: S; let name: String; let log: P6Log
    var body: some View { NavigationView { Text("nav \(name)") }.navigationViewStyle(style).frame(width: 200, height: 80).p28Size(name, log) }
}
private struct P28AnyTabStyle<S: TabViewStyle, I: IndexViewStyle>: View {
    let style: S; let index: I; let name: String; let log: P6Log
    var body: some View {
        TabView { Text("a").tag(0); Text("b").tag(1) }.tabViewStyle(style).indexViewStyle(index).frame(width: 200, height: 80).p28Size(name, log)
    }
}

private struct P28StylesRoot: View {
    let log: P6Log
    @State var date = Date(timeIntervalSince1970: 1_700_000_000)
    @State var open = true
    @State var text = "edit"
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                #if os(iOS) || os(watchOS) || os(visionOS)
                P28StyledGauge(style: DefaultGaugeStyle(), name: "gauge-default", log: log)
                P28StyledGauge(style: AccessoryCircularGaugeStyle(), name: "gauge-acc-circular", log: log)
                P28StyledGauge(style: AccessoryCircularCapacityGaugeStyle(), name: "gauge-acc-circular-cap", log: log)
                P28StyledGauge(style: AccessoryLinearGaugeStyle(), name: "gauge-acc-linear", log: log)
                P28StyledGauge(style: AccessoryLinearCapacityGaugeStyle(), name: "gauge-acc-linear-cap", log: log)
                P28StyledGauge(style: LinearCapacityGaugeStyle(), name: "gauge-linear-cap", log: log)
                #endif
                P28StyledPicker(style: DefaultPickerStyle(), name: "picker-default", log: log)
                P28StyledPicker(style: InlinePickerStyle(), name: "picker-inline", log: log)
                #if !os(watchOS)
                P28StyledPicker(style: PalettePickerStyle(), name: "picker-palette", log: log)
                #endif
                P28StyledPicker(style: TabsPickerStyle(), name: "picker-tabs", log: log)
                P28StyledField(style: P28FieldStyle(), name: "field-custom", log: log)
                P28StyledField(style: DefaultTextFieldStyle(), name: "field-default", log: log)
                #if !os(tvOS)
                DatePicker("D", selection: $date, in: Date(timeIntervalSince1970: 1_600_000_000)...Date(timeIntervalSince1970: 1_800_000_000), displayedComponents: .date)
                    .datePickerStyle(P28DateStyle(log: log)).p28Size("date-custom", log)
                #endif
                #if os(iOS) || os(visionOS)
                TextEditor(text: $text).textEditorStyle(P28EditorStyle()).p28Size("editor-custom", log)
                Table(of: P28Row.self) { TableColumn("n") { Text($0.name) } } rows: { TableRow(P28Row(id: 1, name: "r")) }.tableStyle(P28TableStyle()).p28Size("table-custom", log)
                #endif
                NavigationSplitView { Text("side") } detail: { Text("detail") }.navigationSplitViewStyle(P28SplitStyle()).p28Size("split-custom", log)
                DisclosureGroup("disc", isExpanded: $open) { Color.red.frame(width: 30, height: 30) }.disclosureGroupStyle(AutomaticDisclosureGroupStyle()).p28Size("disclosure", log)
                P28AnyNavStyle(style: StackNavigationViewStyle(), name: "nav-stack", log: log)
                P28AnyNavStyle(style: DefaultNavigationViewStyle(), name: "nav-default", log: log)
                #if os(iOS) || os(visionOS)
                P28AnyNavStyle(style: DoubleColumnNavigationViewStyle(), name: "nav-double", log: log)
                P28AnyNavStyle(style: ColumnNavigationViewStyle.columns, name: "nav-column", log: log)
                #endif
                #if !os(watchOS)
                P28AnyTabStyle(style: PageTabViewStyle(), index: PageIndexViewStyle(backgroundDisplayMode: .always), name: "tab-page", log: log)
                #endif
                HStack {
                    Button("cap") {}.buttonStyle(.bordered).buttonBorderShape(ButtonBorderShape.capsule).p28Size("button-capsule", log)
                    Button("rep") {}.buttonRepeatBehavior(ButtonRepeatBehavior.enabled).p28Size("button-repeat", log)
                }
                HStack(spacing: 0) {
                    Button("flex") {}.buttonStyle(.borderedProminent).buttonSizing(ButtonSizing.flexible).p28Size("button-flexible", log)
                }.frame(width: 240)
                HStack(spacing: 0) {
                    Button("fit") {}.buttonStyle(.borderedProminent).buttonSizing(ButtonSizing.fitted).p28Size("button-fitted", log)
                }.frame(width: 240)
            }
        }
    }
}
private struct P28Row: Identifiable { let id: Int; let name: String }

// MARK: navigation: zoom / automatic transitions from a matched source, split view visibility + compact column

private struct P28NavRoot: View {
    let log: P6Log
    @Bindable var path: P28Box<[Int]>
    @Namespace var ns
    var body: some View {
        NavigationStack(path: $path.value) {
            VStack {
                Color.red.frame(width: 50, height: 50)
                    .matchedTransitionSource(id: 1, in: ns) { (src: EmptyMatchedTransitionSourceConfiguration) in
                        p28Source(src.clipShape(RoundedRectangle(cornerRadius: 8)).shadow(radius: 2))
                    }
                Text("root")
            }
            .navigationTitle("P28Root")
            .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.inline)
            .navigationDestination(for: Int.self) { v in
                Text("dest \(v)")
                    .navigationTransition(v == 1 ? AnyNavigationTransition(ZoomNavigationTransition.zoom(sourceID: 1, in: ns)) : AnyNavigationTransition(AutomaticNavigationTransition.automatic))
                    .onAppear { log.add("appear \(v)") }
            }
        }
    }
}
/// any matched transition source configuration, passed through
private func p28Source<C: MatchedTransitionSourceConfiguration>(_ c: C) -> C { c }
private struct P28SplitRoot: View {
    let log: P6Log
    @State var vis = NavigationSplitViewVisibility.all
    @State var col = NavigationSplitViewColumn.detail
    var body: some View {
        NavigationSplitView(columnVisibility: $vis, preferredCompactColumn: $col) {
            Text("side").onAppear { log.add("side appear") }
        } detail: {
            Text("detail").onAppear { log.add("detail appear") }
        }
        .navigationSplitViewStyle(BalancedNavigationSplitViewStyle())
    }
}

// MARK: presentation: custom presentation sizing, presentationMode, critical dialogs, action sheets, popovers

private struct P28Sizing: PresentationSizing {
    let log: P6Log
    func proposedSize(for root: PresentationSizingRoot, context: PresentationSizingContext) -> ProposedViewSize {
        let fit = root.sizeThatFits(.unspecified)
        log.add("sizing fits \(p28S(fit))")
        return ProposedViewSize(width: 320, height: 240)
    }
}
private struct P28SheetBody: View {
    let log: P6Log
    @Environment(\.presentationMode) var mode
    var body: some View {
        Color.green.frame(width: 100, height: 60)
            .onAppear {
                let pm: Binding<PresentationMode> = mode
                log.add("sheet presented \(pm.wrappedValue.isPresented)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { pm.wrappedValue.dismiss() }
            }
            .onDisappear { log.add("sheet gone") }
    }
}
private struct P28PresentRoot: View {
    let log: P6Log
    @State var sheet = false
    @State var dialog = false
    @State var action = false
    @State var pop = false
    var body: some View {
        VStack {
            Text("present")
                .sheet(isPresented: $sheet) {
                    P28SheetBody(log: log)
                        .presentationSizing(P28Sizing(log: log).fitted(horizontal: false, vertical: true))
                }
            Text("dialog")
                .confirmationDialog("P28 Dialog", isPresented: $dialog, titleVisibility: .visible) { Button("Delete", role: .destructive) {} }
            Text("action")
                .actionSheet(isPresented: $action) {
                    ActionSheet(title: Text("P28 Sheet"), message: Text("m"), buttons: [.default(Text("A")), .cancel()])
                }
            Text("popover").popover(isPresented: $pop, attachmentAnchor: PopoverAttachmentAnchor.rect(.bounds), arrowEdge: .top) {
                Text("pop").presentationCompactAdaptation(.popover)
            }
        }
        .onAppear { log.add("ready") }
        .modifier(P28PresentDriver(log: log, sheet: $sheet, dialog: $dialog, action: $action, pop: $pop))
    }
}
/// opens each presentation in turn when asked through the log ("go sheet" etc.)
private struct P28PresentDriver: ViewModifier {
    let log: P6Log
    @Binding var sheet: Bool; @Binding var dialog: Bool; @Binding var action: Bool; @Binding var pop: Bool
    func body(content: Content) -> some View {
        content.onReceive(NotificationCenter.default.publisher(for: Notification.Name("p28.present"))) { n in
            switch n.object as? String {
            case "sheet": sheet = true
            case "dialog": dialog = true
            case "action": action = true
            case "pop": pop = true
            default: dialog = false; action = false; pop = false
            }
        }
    }
}

// MARK: gestures: a UIKit recognizer through UIGestureRecognizerRepresentable, SwiftUI gestures with state + masks

#if os(iOS) || os(visionOS)
final class P28Recognizer: UIGestureRecognizer {
    var fakeLocation = CGPoint(x: 10, y: 20)
    override func location(in view: UIView?) -> CGPoint { view.map { self.view?.convert(fakeLocation, to: $0) ?? fakeLocation } ?? fakeLocation }
    /// end the gesture as UIKit would after a touch sequence
    func fire() { state = .recognized }
}
private struct P28Representable: UIGestureRecognizerRepresentable {
    let log: P6Log
    func makeCoordinator(converter: CoordinateSpaceConverter) -> Int { 7 }
    func makeUIGestureRecognizer(context: Context) -> P28Recognizer {
        let ctx: UIGestureRecognizerRepresentableContext<P28Representable> = context
        log.add("make coordinator \(ctx.coordinator)")
        return P28Recognizer()
    }
    func handleUIGestureRecognizerAction(_ recognizer: P28Recognizer, context: Context) {
        let conv: UIGestureRecognizerRepresentableCoordinateSpaceConverter = context.converter
        let named = conv.location(in: NamedCoordinateSpace.named("p28g"))
        log.add("action state \(recognizer.state.rawValue) local \(Int(conv.localLocation.x)),\(Int(conv.localLocation.y)) named \(Int(named.x)),\(Int(named.y)) global->local \(Int(conv.convert(globalPoint: .zero).x))")
    }
}
#endif
private struct P28GestureRoot: View {
    let log: P6Log
    @GestureState var dragging = false
    @GestureState(resetTransaction: Transaction(animation: nil)) var offset: CGSize = .zero
    var body: some View {
        let drag: DragGesture = DragGesture(minimumDistance: 3, coordinateSpace: .local)
        let g = drag.updating($offset) { v, s, _ in s = v.translation }.simultaneously(with: TapGesture())
        VStack(spacing: 0) {
            Color.blue.frame(width: 80, height: 40).gesture(g, including: GestureMask.all)
                .onAppear { log.add("drag min \(Int(drag.minimumDistance)) state \(dragging) offset \(p28S(offset))") }
            #if os(iOS) || os(visionOS)
            Color.red.frame(width: 100, height: 60).gesture(P28Representable(log: log)).padding(.leading, 30)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .coordinateSpace(.named("p28g"))
    }
}
/// a type-erased gesture of any kind (the Gesture protocol as an app's helper takes it)
private func p28GestureName<G: Gesture>(_ g: G) -> String { String(describing: G.self).components(separatedBy: "<").first ?? "" }

// MARK: focus: focused values / bindings / objects read by a sibling; focus interactions and default focus priority

private struct P28FocusKey: FocusedValueKey { typealias Value = String }
private struct P28FocusBindingKey: FocusedValueKey { typealias Value = Binding<Int> }
extension FocusedValues {
    fileprivate var p28: String? { get { self[P28FocusKey.self] } set { self[P28FocusKey.self] = newValue } }
    fileprivate var p28Count: Binding<Int>? { get { self[P28FocusBindingKey.self] } set { self[P28FocusBindingKey.self] = newValue } }
}
private final class P28FocusModel: ObservableObject { @Published var name = "model" }
private struct P28FocusReader: View {
    let log: P6Log
    @FocusedValue(\.p28) var value
    @FocusedBinding(\.p28Count) var count
    @FocusedObject var model: P28FocusModel?
    var body: some View {
        let s = "focused value \(value ?? "nil") count \(count.map(String.init) ?? "nil") model \(model?.name ?? "nil")"
        log.add(s)
        return Text(s).font(.caption2)
    }
}
private struct P28FocusRoot: View {
    let log: P6Log
    @FocusState var field: Int?
    @AccessibilityFocusState var axFocus: Bool
    @State var text = "x"
    @State var count = 3
    @StateObject var model = P28FocusModel()
    var body: some View {
        VStack {
            TextField("one", text: $text).focused($field, equals: 1)
                .focusedValue(\.p28, "first")
                .focusedValue(\.p28Count, $count)
                .focusedObject(model)
                .accessibilityFocused($axFocus)
            TextField("two", text: $text).focused($field, equals: 2)
            #if !os(watchOS)
            Text("editable").focusable(true, interactions: FocusInteractions.edit)
            #endif
            P28FocusReader(log: log)
        }
        .defaultFocus($field, 1, priority: DefaultFocusEvaluationPriority.userInitiated)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { field = 1; count = 9 } }
        .onChange(of: field) { _, v in log.add("field \(v.map(String.init) ?? "nil") ax \(axFocus)") }
    }
}

// MARK: scroll target behavior (custom snapping, view aligned, type-erased), scroll transitions

private struct P28Snap: ScrollTargetBehavior {
    let log: P6Log
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let ctx: ScrollTargetBehaviorContext = context
        let t: ScrollTarget = target
        log.add("snap from \(Int(t.rect.minY)) velocity \(Int(ctx.velocity.dy)) container \(p28S(ctx.containerSize)) content \(p28S(ctx.contentSize)) axes \(ctx.axes == .vertical ? "v" : "other")")
        target.rect.origin.y = (target.rect.minY / 100).rounded() * 100
    }
    func properties(context: PropertiesContext) -> Properties {
        let pc: ScrollTargetBehaviorPropertiesContext = context
        var p = ScrollTargetBehaviorProperties(); p.limitsScrolls = true
        log.add("properties axes \(pc.axes == .vertical ? "v" : "other")")
        return p
    }
}
private struct P28ScrollRoot: View {
    let log: P6Log; let behavior: AnyScrollTargetBehavior
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<30) { i in
                    Color(hue: Double(i) / 30, saturation: 1, brightness: 1).frame(height: 100)
                        .scrollTransition(ScrollTransitionConfiguration.interactive.threshold(.visible(0.9))) { (content, phase: ScrollTransitionPhase) in
                            content.opacity(phase.isIdentity ? 1 : 0.5)
                        }
                        .onScrollVisibilityChange { if $0 { log.add("visible \(i)") } }
                }
            }.scrollTargetLayout()
        }
        .scrollTargetBehavior(behavior)
        .frame(width: 200, height: 300)
        .contentMargins(.top, 17, for: ContentMarginPlacement.scrollContent)
        .scrollEdgeEffectStyle(ScrollEdgeEffectStyle.hard, for: .top)
        .defaultScrollAnchor(.top, for: ScrollAnchorRole.initialOffset)
        .p28Size("scroll", log)
    }
}

// MARK: tabs: sections, customization, placements, custom TabContent; toolbars + search

private struct P28MoreTabs: TabContent {
    var body: some TabContent<Int> {
        Tab("Four", systemImage: "4.circle", value: 4) { Text("four") }.customizationID("four")
    }
}
@TabContentBuilder<Int> private func p28Tabs(_ log: P6Log) -> some TabContent<Int> {
    Tab("One", systemImage: "1.circle", value: 1) { Text("one").onAppear { log.add("tab 1") } }
        .customizationID("one").customizationBehavior(TabCustomizationBehavior.disabled, for: .sidebar, .tabBar)
    Tab("Two", systemImage: "2.circle", value: 2) { P28TabEnv(log: log) }.customizationID("two")
    TabSection("Sec") {
        Tab("Three", systemImage: "3.circle", value: 3) { Text("three").onAppear { log.add("tab 3") } }.customizationID("three")
    }.customizationID("sec").defaultSectionExpansion(TabSectionExpansion.expanded)
    P28MoreTabs()
}
private struct P28TabEnv: View {
    let log: P6Log
    @Environment(\.tabBarPlacement) var placement
    @Environment(\.tabViewBottomAccessoryPlacement) var accessory
    var body: some View {
        let p: TabBarPlacement? = placement
        let a: TabViewBottomAccessoryPlacement? = accessory
        return Text("two").onAppear { log.add("tab 2 placement \(p.map { $0 == TabBarPlacement.topBar ? "top" : "\($0)" } ?? "nil") accessory \(a.map { "\($0)" } ?? "nil")") }
    }
}
private struct P28TabRoot: View {
    let log: P6Log
    @Bindable var sel: P28Box<Int>
    @State var cust = TabViewCustomization()
    var body: some View {
        TabView(selection: $sel.value) { p28Tabs(log) }
            .tabViewStyle(.sidebarAdaptable)
            .tabViewCustomization($cust)
            .tabBarMinimizeBehavior(TabBarMinimizeBehavior.onScrollDown)
            .tabViewSearchActivation(TabSearchActivation.searchTabSelection)
            .onAppear {
                cust[sidebarVisibility: "two"] = .hidden
                log.add("cust two \(cust[sidebarVisibility: "two"] == .hidden ? "hidden" : "other") placement \(TabPlacement.sidebarOnly != TabPlacement.pinned)")
            }
    }
}

private struct P28Toolbar: CustomizableToolbarContent {
    let log: P6Log
    var body: some CustomizableToolbarContent {
        ToolbarItem(id: "add", placement: .topBarTrailing) { Button("Add") { log.add("add") } }
        ToolbarItem(id: "edit", placement: .topBarTrailing) { Button("Edit") {} }.customizationBehavior(ToolbarCustomizationBehavior.reorderable)
    }
}
@ToolbarContentBuilder private func p28Leading() -> some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) { Button("Lead") {} }
}
private struct P28SearchDismisser: View {
    let log: P6Log
    @Environment(\.dismissSearch) var dismissSearch
    @Environment(\.isSearching) var searching
    var body: some View {
        Text("searching \(searching)").onChange(of: searching) { _, s in
            log.add("searching \(s)")
            if s { let d: DismissSearchAction = dismissSearch; DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { d() } }
        }
    }
}
/// the iOS 27.1 / 27.2 toolbar behaviors (the app's minimum is 27.0)
private struct P28NewBars: ViewModifier {
    let log: P6Log
    func body(content: Content) -> some View {
        if #available(iOS 27.2, tvOS 27.2, watchOS 27.2, visionOS 27.2, *) {
            content.toolbarTitleAlignment(ToolbarTitleAlignment.leading)
                .toolbarVerticalBehavior(ToolbarVerticalBehavior.automatic)
                .toolbarVerticalCompressionBehavior(ToolbarVerticalCompressionBehavior.prefersToolbarItems)
                .onAppear { log.add("bars 27.2") }
        } else {
            content.onAppear { log.add("bars 27.0") }
        }
    }
}
private struct P28ToolbarRoot: View {
    let log: P6Log
    @State var q = ""
    @State var presented = false
    @State var scope = 0
    var body: some View {
        NavigationStack {
            P28SearchDismisser(log: log)
                .navigationTitle("P28Bar")
                .toolbar(id: "p28bar") { P28Toolbar(log: log) }
                .toolbar { p28Leading() }
                .toolbar(removing: ToolbarDefaultItemKind.title)
                .searchable(text: $q, isPresented: $presented, prompt: "Find")
                .searchScopes($scope, activation: SearchScopeActivation.onSearchPresentation) { Text("All").tag(0); Text("Some").tag(1) }
                // (searchSuggestions(.hidden, for: .content) on the content view hides the content itself)
                .searchSuggestions { Text("sug").searchCompletion("sug").searchSuggestions(.hidden, for: SearchSuggestionsPlacement.Set.content) }
                .searchToolbarBehavior(SearchToolbarBehavior.automatic)
                .searchPresentationToolbarBehavior(SearchPresentationToolbarBehavior.avoidHidingContent)
                .toolbarMinimizationBehavior(ToolbarMinimizationBehavior.onScrollDown, for: .navigationBar)
                .toolbarMinimizationRestoration(ToolbarMinimizationRestoration.atScrollEdge, for: .navigationBar)
                .toolbarMinimizationSafeAreaAdjustment(ToolbarMinimizationSafeAreaAdjustment.enabled, for: .navigationBar)
                .modifier(P28NewBars(log: log))
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { presented = true } }
    }
}

// MARK: Core Data through @FetchRequest / @SectionedFetchRequest

#if canImport(CoreData)
private let p28Model: NSManagedObjectModel = {
    let m = NSManagedObjectModel(), e = NSEntityDescription()
    e.name = "P28Item"; e.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
    let name = NSAttributeDescription(); name.name = "name"; name.attributeType = .stringAttributeType
    let group = NSAttributeDescription(); group.name = "group"; group.attributeType = .stringAttributeType
    e.properties = [name, group]; m.entities = [e]
    return m
}()
private struct P28FetchList: View {
    let log: P6Log
    @FetchRequest(entity: p28Model.entities[0], sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)]) var items: FetchedResults<NSManagedObject>
    @SectionedFetchRequest(fetchRequest: {
        let r = NSFetchRequest<NSManagedObject>(entityName: "P28Item")
        r.sortDescriptors = [NSSortDescriptor(key: "group", ascending: true), NSSortDescriptor(key: "name", ascending: true)]
        return r
    }(), sectionIdentifier: \NSManagedObject.p28Group) var sections: SectionedFetchResults<String, NSManagedObject>
    var body: some View {
        let names = items.map { $0.value(forKey: "name") as? String ?? "?" }
        let secs = sections.map { "\($0.id):\($0.count)" }
        log.add("fetch \(names.joined(separator: ",")) sections \(secs.joined(separator: ","))")
        return List(items, id: \.objectID) { Text($0.value(forKey: "name") as? String ?? "?") }
    }
}
extension NSManagedObject {
    @objc fileprivate var p28Group: String { value(forKey: "group") as? String ?? "" }
}
#endif

// MARK: text: a TextRenderer sizing through TextProxy and reading a custom TextAttribute; variants, formats, languages

private struct P28Mark: TextAttribute { let tag: Int }
private struct P28Wide: TextRenderer {
    let log: P6Log
    func sizeThatFits(proposal: ProposedViewSize, text: TextProxy) -> CGSize {
        let p: TextProxy = text
        let s = p.sizeThatFits(proposal)
        return CGSize(width: s.width + 20, height: s.height)
    }
    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        var tags: [Int] = []
        for line in layout { for run in line { if let m = run[P28Mark.self] { tags.append(m.tag) }; ctx.draw(run) } }
        log.add("marks \(tags.sorted())")
    }
}
private struct P28TextRoot: View {
    let log: P6Log
    let d0 = Date(timeIntervalSince1970: 1_700_000_000)
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("render").fixedSize().p28Size("plain", log)
            (Text("ren").customAttribute(P28Mark(tag: 1)) + Text("der").customAttribute(P28Mark(tag: 2))).textRenderer(P28Wide(log: log)).fixedSize().p28Size("wide", log)
            Text(TimeDataSource<Date>.currentDate, format: SystemFormatStyle.DateReference.reference(to: d0)).p28Size("reference", log)
            Text(TimeDataSource<Date>.currentDate, format: .timer(countingDownIn: Date()..<Date().addingTimeInterval(3600))).p28Size("timer", log)
            Text(TimeDataSource<Date>.currentDate, format: .stopwatch(startingAt: Date())).p28Size("stopwatch", log)
            Text(d0, style: .relative).textVariant(SizeDependentTextVariant.sizeDependent).frame(width: 60).p28Size("variant-size", log)
            Text(d0, style: .relative).textVariant(FixedTextVariant.fixed).p28Size("variant-fixed", log)
            Text("ภาษาไทย").typesettingLanguage(TypesettingLanguage.explicit(Locale.Language(identifier: "th"))).fixedSize().p28Size("thai", log)
            Text("select me").textSelection(EnabledTextSelectability.enabled).accessibilityTextContentType(AccessibilityTextContentType.sourceCode).p28Size("selectable", log)
        }
    }
}
private func p28Selectable<S: TextSelectability>(_ s: S) -> Bool { S.allowsSelection }

// MARK: keyframes: a custom Keyframes, a custom KeyframeTrackContent, builders; animation state in a custom animation

private struct P28KFV { var x = 0.0; var y = 0.0 }
private struct P28XTrack: KeyframeTrackContent {
    var body: some KeyframeTrackContent<Double> { LinearKeyframe(10.0, duration: 1); LinearKeyframe(20.0, duration: 1) }
}
private struct P28Frames: Keyframes {
    var body: some Keyframes<P28KFV> {
        KeyframeTrack(\P28KFV.x) { P28XTrack() }
        KeyframeTrack(\P28KFV.y) { CubicKeyframe(4.0, duration: 2) }
    }
}
@KeyframesBuilder<P28KFV> private func p28BuiltFrames() -> some Keyframes<P28KFV> {
    KeyframeTrack(\P28KFV.x) { LinearKeyframe(1.0, duration: 0.5) }
}
@KeyframeTrackContentBuilder<Double> private func p28BuiltTrack() -> some KeyframeTrackContent<Double> {
    LinearKeyframe(5.0, duration: 1)
}
private struct P28Calls: AnimationStateKey { static let defaultValue = 0 }
/// a linear 0.5 s animation counting its calls in its animation state
private struct P28Counting: CustomAnimation {
    let log: P6Log
    static func == (a: P28Counting, b: P28Counting) -> Bool { a.log === b.log }
    func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(log)) }
    func animate<V: VectorArithmetic>(value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? {
        var st: AnimationState<V> = context.state
        st[P28Calls.self] += 1
        context.state = st
        if time >= 0.5 { log.add("calls \(context.state[P28Calls.self])"); return nil }
        var v = value; v.scale(by: time / 0.5); return v
    }
}
private struct P28AnimProbe: ViewModifier, Animatable {
    var x: Double
    var animatableData: Double { get { x } set { x = newValue } }
    func body(content: Content) -> some View { content.opacity(x) }
}
/// a deprecated AnimatableModifier, driven like an Animatable ViewModifier
private struct P28OldProbe: AnimatableModifier {
    var x: Double; let log: P6Log
    var animatableData: Double { get { x } set { x = newValue; if newValue > 0 && newValue < 1 { log.add("old mid") } } }
    func body(content: Content) -> some View { content.opacity(x) }
}
@Observable private final class P28AnimM { var on = false }
private struct P28AnimRoot: View {
    @Bindable var m: P28AnimM; let log: P6Log
    var body: some View {
        Color.red.frame(width: 10, height: 10).modifier(P28AnimProbe(x: m.on ? 1 : 0)).modifier(P28OldProbe(x: m.on ? 1 : 0, log: log))
    }
}

// MARK: hover effects, glass, shape styles, symbol rendering, materials, prominence (rendered)

private struct P28Hover: CustomHoverEffect {
    func body(content: EmptyHoverEffect) -> some CustomHoverEffect { content.hoverEffectDisabled(false) }
}
private func p28HoverName(_ h: HoverEffect) -> String { "\(h)".components(separatedBy: "(").first ?? "" }
private struct P28StyleSwatches: View {
    let log: P6Log
    @Environment(\.backgroundProminence) var prominence
    var body: some View {
        let _ = log.add("prominence \(prominence == BackgroundProminence.standard ? "standard" : "increased")")
        HStack(spacing: 0) {
            Rectangle().fill(LinkShapeStyle.link).frame(width: 10, height: 10)
            Rectangle().fill(PlaceholderTextShapeStyle.placeholder).frame(width: 10, height: 10)
            Rectangle().fill(SelectionShapeStyle.selection).frame(width: 10, height: 10)
            Rectangle().fill(WindowBackgroundShapeStyle.windowBackground).frame(width: 10, height: 10)
            Rectangle().fill(Color.red.secondary).frame(width: 10, height: 10)
            Rectangle().fill(Material.regular.materialActiveAppearance(MaterialActiveAppearance.active)).frame(width: 10, height: 10)
            Color.red.frame(width: 10, height: 10).drawingGroup(opaque: true, colorMode: ColorRenderingMode.extendedLinear)
        }.background(Color.white)
    }
}

// MARK: drag and drop: a DropDelegate, drop proposals, drag / drop configurations; the interactions UIKit gets

private struct P28Drop: DropDelegate {
    let log: P6Log
    func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [.text]) }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: DropOperation.move) }
    func performDrop(info: DropInfo) -> Bool { log.add("drop \(info.location)"); return true }
}
#if os(iOS) || os(visionOS)
private struct P28DragRoot: View {
    let log: P6Log
    var body: some View {
        VStack {
            Text("drag me").draggable("p28 text").p28Size("draggable", log)
            Color.blue.frame(width: 60, height: 60).onDrop(of: [.text], delegate: P28Drop(log: log))
            Color.green.frame(width: 60, height: 60).dropDestination(for: String.self) { items, _ in log.add("dropped \(items)"); return true }
                .springLoadingBehavior(SpringLoadingBehavior.enabled)
            Text("cfg").onDragSessionUpdated { (s: DragSession) in log.add("drag session \(s.phase)") }
                .dragConfiguration(DragConfiguration(allowMove: true))
                .dropConfiguration { (s: DropSession) in DropConfiguration(operation: .copy) }
        }
    }
}
#endif

// MARK: tables, outlines, editable collections

private struct P28Item: Identifiable, Hashable { let id: Int; var name: String; var children: [P28Item]? = nil }
#if os(iOS) || os(visionOS)
private struct P28NameColumn: TableColumnContent {
    var tableColumnBody: some TableColumnContent<P28Item, KeyPathComparator<P28Item>> {
        TableColumn("Name", value: \P28Item.name).alignment(TableColumnAlignment.leading).customizationID("name")
    }
}
@TableColumnBuilder<P28Item, KeyPathComparator<P28Item>> private func p28Columns() -> some TableColumnContent<P28Item, KeyPathComparator<P28Item>> {
    P28NameColumn()
    TableColumn("Id") { (i: P28Item) in Text("\(i.id)") }.customizationID("id").defaultVisibility(.visible)
}
private struct P28Rows: TableRowContent {
    let items: [P28Item]
    var tableRowBody: some TableRowContent<P28Item> {
        ForEach(items) { TableRow($0) }
    }
}
@TableRowBuilder<P28Item> private func p28ExtraRow() -> some TableRowContent<P28Item> {
    TableRow(P28Item(id: 99, name: "extra")).itemProvider { NSItemProvider(object: "extra" as NSString) }
}
private struct P28TableRoot: View {
    let log: P6Log
    @State var order = [KeyPathComparator(\P28Item.name)]
    @State var cust = TableColumnCustomization<P28Item>()
    @State var items = [P28Item(id: 1, name: "b"), P28Item(id: 2, name: "a")]
    var body: some View {
        VStack {
            Table(of: P28Item.self, sortOrder: $order, columnCustomization: $cust) { p28Columns() } rows: {
                P28Rows(items: items)
                p28ExtraRow()
            }
            .onAppear { cust[visibility: "id"] = .hidden; log.add("table cust id \(cust[visibility: "id"] == .hidden ? "hidden" : "visible") behavior \(TableColumnCustomizationBehavior.all.contains(.reorder))") }
            .frame(height: 200)
            List {
                OutlineGroup([P28Item(id: 10, name: "root", children: [P28Item(id: 11, name: "leaf")])], children: \.children) { i in
                    Text(i.name).onAppear { log.add("outline \(i.name)") }
                }
                ForEach($items, editActions: EditActions.all) { $i in Text(i.name) }
                ForEach(items) { Text("dyn \($0.name)") }.onDelete { _ in }.onMove { _, _ in }
            }
            .frame(height: 300)
        }
    }
}
#endif
/// the editable ForEach's data and content types, named
private func p28EditableTypes() -> String {
    let items = [P28Item(id: 1, name: "a")]
    let b = Binding.constant(items)
    let fe: ForEach<IndexedIdentifierCollection<[P28Item], Int>, Int, EditableCollectionContent<Text, [P28Item]>> = ForEach(b, editActions: .all) { $i in Text(i.name) }
    return "\(fe.data.count) \(type(of: fe.data.first!))"
}

// MARK: documents: ReferenceFileDocument snapshots, the iOS 27 Document protocols' readers and writers

private final class P28RefDoc: ReferenceFileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    init(text: String) { self.text = text }
    required init(configuration: ReadConfiguration) throws {
        let c: FileDocumentReadConfiguration = configuration
        text = String(decoding: c.file.regularFileContents ?? Data(), as: UTF8.self)
    }
    func snapshot(contentType: UTType) throws -> String { text }
    func fileWrapper(snapshot: String, configuration: WriteConfiguration) throws -> FileWrapper {
        let _: FileDocumentWriteConfiguration = configuration
        return FileWrapper(regularFileWithContents: Data(snapshot.utf8))
    }
}
private struct P28TextReader: DocumentReader {
    func read(from source: URL, progress: consuming Subprogress) async throws -> String { try String(contentsOf: source, encoding: .utf8) }
}
private struct P28TextWriter: DocumentWriter {
    func write(snapshot: String, to destination: URL, previous: String?, progress: consuming Subprogress) async throws {
        try (snapshot + (previous.map { " (was \($0))" } ?? "")).write(to: destination, atomically: true, encoding: .utf8)
    }
}
private final class P28Doc: Document {
    static var readableContentTypes: [UTType] { [.plainText] }
    static var writableContentTypes: [UTType] { [.plainText] }
    var text = ""
    func reader(configuration: ReadConfiguration) -> P28TextReader { let _: DocumentReadConfiguration = configuration; return P28TextReader() }
    func writer(configuration: WriteConfiguration) -> P28TextWriter { let _: DocumentWriteConfiguration = configuration; return P28TextWriter() }
    @MainActor func apply(snapshot: String, previous: String?) async throws { text = snapshot }
    @MainActor func snapshot(contentType: UTType) async throws -> String { text }
}

// MARK: checks

extension Registry {
    static var p28swiftui: [Check] {
        var c: [Check] = []

        // MARK: SwiftUI styles: gauge / picker / text field / date picker / text editor / table / split view /
        // disclosure / navigation view / index view styles applied through generics, custom styles whose bodies
        // replace the control (sizes read back), button border shape, repeat behavior and sizing
        c.append(check("SwiftUI", "p28-styles-configurations", timeout: 25) {
            let log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P28StylesRoot(log: log)) }
            defer { Task { @MainActor in close() } }
            _ = await p6Wait(6) { log.all.contains { $0.hasPrefix("button-fitted ") } && log.all.contains { $0.hasPrefix("date sel") } }
            try await Task.sleep(for: .milliseconds(300))
            let names = ["gauge-default", "gauge-acc-circular", "gauge-acc-circular-cap", "gauge-acc-linear", "gauge-acc-linear-cap", "gauge-linear-cap",
                         "picker-default", "picker-inline", "picker-palette", "picker-tabs", "field-custom", "field-default", "date-custom",
                         "editor-custom", "table-custom", "split-custom", "disclosure", "nav-stack", "nav-default", "nav-double", "nav-column",
                         "tab-page", "button-capsule", "button-repeat", "button-flexible", "button-fitted"]
            let got = names.map { "\($0) \(p28Last(log, $0) ?? "-")" }.joined(separator: ", ")
            let date = log.all.last { $0.hasPrefix("date sel") } ?? "none"
            #if os(iOS)
            // custom style bodies: exact sizes
            try expect(p28Last(log, "editor-custom") == "77x33" && p28Last(log, "table-custom") == "66x22" && p28Last(log, "split-custom") == "55x11", got)
            // the custom text field style pads the default field by 10 on each side
            if let f = p28WH(p28Last(log, "field-custom")), let d = p28WH(p28Last(log, "field-default")) {
                try expect(f.0 == 150 && abs(f.1 - d.1 - 20) < 1, "custom field \(f) default \(d)")
            } else { throw Fail(got) }
            try expect(date.contains("min 2020-09-13T12:26:40Z max 2027-01-15T08:00:00Z comps date") && date.contains("sel 2023-11-14T22:13:20Z"), date)
            // flexible fills the 240 pt row, fitted hugs its label
            let fl = p28WH(p28Last(log, "button-flexible")), fi = p28WH(p28Last(log, "button-fitted"))
            try expect(fl?.0 == 240 && (fi?.0 ?? 999) < 120, "flexible \(String(describing: fl)) fitted \(String(describing: fi))")
            let missing = names.filter { p28Last(log, $0) == nil }
            try expect(missing.isEmpty, "not laid out: \(missing); \(got)")
            #endif
            return "\(got); \(date)"
        })

        // MARK: SwiftUI navigation: push onto a NavigationStack path with a zoom transition from a matched source
        // (custom source configuration), then an automatic one; inline title mode; split view visibility + compact column
        #if os(iOS) || os(visionOS)
        c.append(check("SwiftUI", "p28-navigation-transitions", timeout: 25) {
            let log = P6Log()
            let path = await onMain { P28Box<[Int]>([]) }
            let close = try await onMain { try p6HostSwiftUI(P28NavRoot(log: log, path: path)) }
            defer { Task { @MainActor in close() } }
            try await Task.sleep(for: .milliseconds(500))
            await onMain { path.value = [1] }
            _ = await p6Wait(4) { log.has("appear 1") }
            try await Task.sleep(for: .milliseconds(700))
            await onMain { path.value = [1, 2] }
            _ = await p6Wait(4) { log.has("appear 2") }
            try await Task.sleep(for: .milliseconds(700))
            let stack = await onMain { () -> String in
                let navs = p28VCs(p6LastWindow?.rootViewController).compactMap { $0 as? UINavigationController }
                return navs.map { n in "\(n.viewControllers.count) title \(n.navigationBar.topItem?.title ?? "nil") mode \(n.viewControllers.first?.navigationItem.largeTitleDisplayMode.rawValue ?? -1)" }.joined(separator: "; ")
            }
            try expect(log.has("appear 1") && log.has("appear 2"), "appeared \(log.all)")
            try expect(stack.hasPrefix("3 "), "navigation controllers \(stack)")
            // the split view on an iPhone (compact, preferred column detail): both columns appear (Apple's simulator)
            let slog = P6Log()
            let close2 = try await onMain { try p6HostSwiftUI(P28SplitRoot(log: slog)) }
            defer { Task { @MainActor in close2() } }
            _ = await p6Wait(4) { !slog.all.isEmpty }
            try await Task.sleep(for: .milliseconds(400))
            #if os(iOS)
            try expect(slog.all.sorted() == ["detail appear", "side appear"], "split \(slog.all)")
            #endif
            return "stack \(stack); split \(slog.all); transitions \(ZoomNavigationTransition.self), \(CrossFadeNavigationTransition.self)"
        })
        #endif

        // MARK: SwiftUI presentation: a sheet with a custom PresentationSizing (root measured) dismissed through the
        // deprecated presentationMode; a critical confirmation dialog, an ActionSheet and a popover as UIKit presents them
        #if os(iOS)
        c.append(check("SwiftUI", "p28-presentation-sizing-dialogs", timeout: 30) {
            let log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P28PresentRoot(log: log)) }
            defer { Task { @MainActor in close() } }
            _ = await p6Wait(3) { log.has("ready") }
            func go(_ s: String) async { await onMain { NotificationCenter.default.post(name: Notification.Name("p28.present"), object: s) } }
            func presented() async -> [String] {
                await onMain { p28VCs(p6LastWindow?.rootViewController).filter { $0.presentingViewController != nil }.map { vc in
                    if let a = vc as? UIAlertController { return "alert \(a.preferredStyle == .actionSheet ? "sheet" : "alert") \(a.title ?? "nil") [\(a.actions.map { "\($0.title ?? "")/\($0.style.rawValue)" }.joined(separator: ","))]" }
                    return "\(type(of: vc)) \(vc.modalPresentationStyle.rawValue)"
                } }
            }
            await go("sheet")
            _ = await p6Wait(4) { log.has("sheet gone") }
            await go("dialog")
            _ = await p6Wait(3) { p28VCs(p6LastWindow?.rootViewController).contains { $0 is UIAlertController } }
            try await Task.sleep(for: .milliseconds(500))
            let dialog = await presented()
            await go("none")
            _ = await p6Wait(3) { !p28VCs(p6LastWindow?.rootViewController).contains { $0 is UIAlertController } }
            try await Task.sleep(for: .milliseconds(600))
            await go("action")
            _ = await p6Wait(3) { p28VCs(p6LastWindow?.rootViewController).contains { $0 is UIAlertController } }
            try await Task.sleep(for: .milliseconds(500))
            let action = await presented()
            await go("none")
            _ = await p6Wait(3) { !p28VCs(p6LastWindow?.rootViewController).contains { $0 is UIAlertController } }
            try await Task.sleep(for: .milliseconds(600))
            await go("pop")
            try await Task.sleep(for: .milliseconds(900))
            let pop = await presented()
            await go("none")
            try await Task.sleep(for: .milliseconds(500))
            let d = "log \(log.all); dialog \(dialog); action \(action); popover \(pop)"
            try expect(log.has("sheet presented true") && log.has("sheet gone"), d)
            try expect(dialog.contains { $0.contains("P28 Dialog") && $0.contains("Delete/2") }, d)
            try expect(action.contains { $0.hasPrefix("alert sheet P28 Sheet") && $0.contains("A/0") }, d)
            try expect(pop.contains { $0.contains(" 7") }, d)   // UIModalPresentationStyle.popover
            let sizes: [String] = ["\(AutomaticPresentationSizing.self)", "\(FittedPresentationSizing.self)", "\(PagePresentationSizing.self)"]
            return d + "; sizings \(sizes) placement \(PresentationPlacement.automatic == PresentationPlacement.center ? "same" : "distinct")"
        })
        #endif

        // MARK: SwiftUI gestures: a UIKit recognizer through UIGestureRecognizerRepresentable (coordinator, converter
        // in local / named spaces when it fires: made only once a touch arrives), SwiftUI gestures with @GestureState + masks
        #if os(iOS) || os(visionOS)
        c.append(check("SwiftUI", "p28-gesture-representable", timeout: 20) {
            let log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P28GestureRoot(log: log)) }
            defer { Task { @MainActor in close() } }
            _ = await p6Wait(4) { log.all.contains { $0.hasPrefix("make coordinator") } }
            try await Task.sleep(for: .milliseconds(300))
            let recs = await onMain { () -> [String] in
                guard let w = p6LastWindow else { return [] }
                var out: [String] = []
                // SwiftUI makes a representable's recognizer when a touch first hit-tests the view
                let hit = w.hitTest(CGPoint(x: 80, y: w.safeAreaInsets.top + 70), with: nil)
                out.append("hit:\(hit.map { String(describing: type(of: $0)) } ?? "nil")")
                func walk(_ v: UIView) { for g in v.gestureRecognizers ?? [] { out.append(String(describing: type(of: g))); if let p = g as? P28Recognizer { p.fire() } }; v.subviews.forEach(walk) }
                walk(w); return out
            }
            _ = await p6Wait(3) { log.all.contains { $0.hasPrefix("action ") } }
            let act = log.all.last { $0.hasPrefix("action ") } ?? "none"
            let d = "\(log.all); recognizers \(recs.count): \(Set(recs).sorted()); gesture \(p28GestureName(TapGesture())) \(p28GestureName(DragGesture()))"
            try expect(log.has("drag min 3 state false offset 0x0"), d)
            // Apple's simulator: with no touch, SwiftUI makes neither the representable's recognizer (no coordinator,
            // makeUIGestureRecognizer not called, even after a hit test) nor recognizers for its own drag gesture
            if recs.contains("P28Recognizer") {
                try expect(log.has("make coordinator 7") && act.hasPrefix("action state 3 local 10,20 named 40,60"), d)
            } else {
                try expect(!log.all.contains { $0.hasPrefix("make ") } && recs.contains("UITapGestureRecognizer"), d)
            }
            return d
        })
        #endif

        // MARK: SwiftUI focus: focusing a field publishes its focused value, binding and object to a sibling reader;
        // FocusInteractions, default focus priority, accessibility focus state
        c.append(check("SwiftUI", "p28-focused-values", timeout: 20) {
            let log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P28FocusRoot(log: log)) }
            defer { Task { @MainActor in close() } }
            _ = await p6Wait(5) { log.has("focused value first count 9 model model") }
            try await Task.sleep(for: .milliseconds(200))
            let reads = Array(Set(log.all.filter { $0.hasPrefix("focused ") })).sorted()
            let d = "\(reads); \(log.all.filter { $0.hasPrefix("field ") })"
            #if os(iOS) || os(visionOS)
            try expect(log.has("focused value first count 9 model model") && log.all.contains { $0.hasPrefix("field 1") }, d)
            #endif
            try expect(FocusInteractions.edit != FocusInteractions.activate && FocusInteractions.automatic.contains(.activate) == FocusInteractions.automatic.contains(.activate), "interactions")
            return d
        })

        // MARK: SwiftUI scrolling: a custom ScrollTargetBehavior (target context, properties) snaps a fling's target to
        // 100 pt rows when UIKit asks; view-aligned and type-erased behaviors; scroll transitions, content margins,
        // edge effect style, anchor roles as UIScrollView sees them
        #if os(iOS) || os(visionOS)
        c.append(check("SwiftUI", "p28-scroll-target-behavior", timeout: 25) {
            let log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P28ScrollRoot(log: log, behavior: AnyScrollTargetBehavior(P28Snap(log: log)))) }
            defer { Task { @MainActor in close() } }
            _ = await p6Wait(4) { log.has("visible 0") }
            try await Task.sleep(for: .milliseconds(400))
            let r = await onMain { () -> String in
                guard let w = p6LastWindow, let sv = p6Find(w, UIScrollView.self).first(where: { $0.contentSize.height > 2000 }) else { return "no scroll view" }
                var target = CGPoint(x: 0, y: 437)
                sv.delegate?.scrollViewWillEndDragging?(sv, withVelocity: CGPoint(x: 0, y: 0.5), targetContentOffset: &target)
                return "target \(Int(target.y)) inset \(Int(sv.contentInset.top)) adjusted \(Int(sv.adjustedContentInset.top)) edge \(sv.topEdgeEffect.style == .hard ? "hard" : "other") content \(Int(sv.contentSize.height))"
            }
            let snap = log.all.last { $0.hasPrefix("snap ") } ?? "no snap"
            let d = "\(r); \(snap); \(log.all.first { $0.hasPrefix("properties") } ?? "no properties")"
            // UIKit's 437 is 454 in SwiftUI's space (17 pt top margin); the behavior moves it to 500 = UIKit's 483
            try expect(snap.hasPrefix("snap from 454 velocity 0 container 200x283 content 200x3000 axes v") && r.hasPrefix("target 483 "), d)
            try expect(r.contains("inset 17") || r.contains("adjusted 17"), d)
            try expect(r.contains("edge hard"), d)
            // the view-aligned behavior
            let va = ViewAlignedScrollTargetBehavior(limitBehavior: ViewAlignedScrollTargetBehavior.LimitBehavior.alwaysByOne)
            _ = AnyScrollTargetBehavior(va)
            return d
        })
        #endif

        // MARK: SwiftUI tabs: Tab / TabSection / custom TabContent in a sidebar-adaptable TabView as UIKit's tab bar
        // shows them; selection, customization (sidebar visibility), placements and minimize behavior
        #if os(iOS)
        c.append(check("SwiftUI", "p28-tabs-sections-customization", timeout: 25) {
            let log = P6Log()
            let sel = await onMain { P28Box(1) }
            let close = try await onMain { try p6HostSwiftUI(P28TabRoot(log: log, sel: sel)) }
            defer { Task { @MainActor in close() } }
            _ = await p6Wait(4) { log.has("tab 1") }
            await onMain { sel.value = 2 }
            _ = await p6Wait(3) { log.all.contains { $0.hasPrefix("tab 2") } }
            await onMain { sel.value = 3 }
            _ = await p6Wait(3) { log.has("tab 3") }
            let items = await onMain { () -> String in
                guard let w = p6LastWindow else { return "" }
                return p6Find(w, UITabBar.self).map { ($0.items ?? []).map { $0.title ?? "" }.joined(separator: ",") }.joined(separator: "|")
            }
            let d = "\(log.all); tab bar \(items)"
            try expect(log.has("tab 1") && log.has("tab 3") && log.all.contains { $0.hasPrefix("tab 2 placement") } && log.all.contains { $0.hasPrefix("cust two hidden") }, d)
            try expect(items.contains("One") && items.contains("Two") && items.contains("Four"), d)
            _ = [AdaptableTabBarPlacement.automatic, AdaptableTabBarPlacement.sidebar]
            return d
        })

        // MARK: SwiftUI toolbars + search: customizable toolbar items, a ToolbarContentBuilder, removed default title,
        // minimization / title alignment / vertical behaviors; search presented programmatically and dismissed through
        // DismissSearchAction, scopes, suggestions placement
        c.append(check("SwiftUI", "p28-toolbar-search", timeout: 25) {
            let log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P28ToolbarRoot(log: log)) }
            defer { Task { @MainActor in close() } }
            _ = await p6Wait(5) { log.has("searching true") && log.has("searching false") }
            try await Task.sleep(for: .milliseconds(300))
            let bar = await onMain { () -> String in
                let items = p28VCs(p6LastWindow?.rootViewController).map(\.navigationItem)
                let right = items.flatMap { ($0.rightBarButtonItems ?? []) }.count, left = items.flatMap { ($0.leftBarButtonItems ?? []) }.count
                let sc = items.compactMap(\.searchController).first
                return "right \(right) left \(left) search \(sc != nil) scopes \(sc?.searchBar.scopeButtonTitles ?? [])"
            }
            let d = "\(log.all); \(bar)"
            try expect(log.has("searching true") && log.has("searching false"), d)
            try expect(bar.contains("search true"), d)
            return d
        })
        #endif

        // MARK: SwiftUI Core Data: @FetchRequest and @SectionedFetchRequest over an in-memory store follow inserts
        #if canImport(CoreData)
        c.append(check("SwiftUI", "p28-fetch-requests", timeout: 20) {
            let psc = NSPersistentStoreCoordinator(managedObjectModel: p28Model)
            _ = try psc.addPersistentStore(type: .inMemory, at: URL(fileURLWithPath: "/dev/null"))
            let ctx = await onMain { () -> NSManagedObjectContext in let c = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType); c.persistentStoreCoordinator = psc; return c }
            await onMain {
                for (n, g) in [("b", "x"), ("a", "x"), ("c", "y")] {
                    let o = NSManagedObject(entity: p28Model.entities[0], insertInto: ctx); o.setValue(n, forKey: "name"); o.setValue(g, forKey: "group")
                }
                try? ctx.save()
            }
            let log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P28FetchList(log: log).environment(\.managedObjectContext, ctx)) }
            defer { Task { @MainActor in close() } }
            _ = await p6Wait(4) { log.has("fetch a,b,c sections x:2,y:1") }
            await onMain { let o = NSManagedObject(entity: p28Model.entities[0], insertInto: ctx); o.setValue("d", forKey: "name"); o.setValue("z", forKey: "group"); try? ctx.save() }
            _ = await p6Wait(4) { log.has("fetch a,b,c,d sections x:2,y:1,z:1") }
            let d = Array(Set(log.all)).sorted().joined(separator: "; ")
            try expect(log.has("fetch a,b,c sections x:2,y:1") && log.has("fetch a,b,c,d sections x:2,y:1,z:1"), d)
            return d
        })
        #endif

        // MARK: SwiftUICore text: a TextRenderer widens text through TextProxy and reads custom TextAttributes per run;
        // system format styles over time data sources, text variants, typesetting language, selectability
        c.append(check("SwiftUICore", "p28-text-renderer-proxy", timeout: 20) {
            let log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P28TextRoot(log: log)) }
            defer { Task { @MainActor in close() } }
            _ = await p6Wait(5) { log.all.contains { $0.hasPrefix("marks ") } && p28Last(log, "selectable") != nil }
            try await Task.sleep(for: .milliseconds(300))
            let keys = ["plain", "wide", "reference", "timer", "stopwatch", "variant-size", "variant-fixed", "thai", "selectable"]
            let d = keys.map { "\($0) \(p28Last(log, $0) ?? "-")" }.joined(separator: ", ") + "; \(log.all.last { $0.hasPrefix("marks") } ?? "no marks")"
            let plain = p28WH(p28Last(log, "plain")), wide = p28WH(p28Last(log, "wide"))
            try expect(plain != nil && wide != nil && abs(wide!.0 - plain!.0 - 20) < 1.5 && wide!.1 == plain!.1, d)
            try expect(log.all.contains("marks [1, 1, 1, 2, 2, 2]") || log.all.contains("marks [1, 2]"), d)
            try expect(keys.allSatisfy { (p28WH(p28Last(log, $0))?.0 ?? 0) > 0 }, d)
            try expect(p28Selectable(EnabledTextSelectability.enabled) && !p28Selectable(DisabledTextSelectability.disabled), "selectability")
            return d
        })

        // MARK: SwiftUICore keyframes: custom Keyframes and KeyframeTrackContent, KeyframesBuilder / track builder
        // results evaluated on a timeline; a custom animation keeps its call count in AnimationState; an
        // AnimatableModifier sees the intermediate values
        c.append(check("SwiftUICore", "p28-keyframes-animation-state", timeout: 20) {
            let tl = KeyframeTimeline(initialValue: P28KFV()) { P28Frames() }
            let v1 = tl.value(time: 1), v2 = tl.value(time: 2)
            let built = KeyframeTimeline(initialValue: P28KFV()) { p28BuiltFrames() }.value(time: 0.25)
            let track = KeyframeTimeline(initialValue: 0.0) { KeyframeTrack { p28BuiltTrack() } }.value(time: 0.5)
            let d0 = "timeline \(tl.duration) s: 1 s x \(v1.x) y \(String(format: "%.2f", v1.y)); 2 s x \(v2.x) y \(v2.y); built 0.25 s x \(built.x); track 0.5 s \(track)"
            try expect(tl.duration == 2 && abs(v1.x - 10) < 0.01 && abs(v2.x - 20) < 0.01 && abs(v2.y - 4) < 0.01 && abs(built.x - 0.5) < 0.01 && abs(track - 2.5) < 0.01, d0)
            var st = AnimationState<Double>(); st[P28Calls.self] = 4
            try expect(st[P28Calls.self] == 4 && AnimationState<Double>()[P28Calls.self] == 0, "animation state")
            let m = await onMain { P28AnimM() }, log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P28AnimRoot(m: m, log: log)) }
            defer { Task { @MainActor in close() } }
            try await Task.sleep(for: .milliseconds(400))
            await onMain { withAnimation(Animation(P28Counting(log: log))) { m.on = true } }
            _ = await p6Wait(4) { log.all.contains { $0.hasPrefix("calls ") } }
            let calls = Int(log.all.last { $0.hasPrefix("calls ") }?.dropFirst(6) ?? "") ?? 0
            let d = "\(d0); custom animation calls \(calls); old modifier mids \(log.all.filter { $0 == "old mid" }.count)"
            try expect(calls >= 5 && log.has("old mid"), d)
            return d
        })

        // MARK: SwiftUICore styles by pixels: link / placeholder / selection / window background / hierarchical /
        // material / drawing group color mode swatches; glass in a container; hover effects and prominence values
        c.append(check("SwiftUICore", "p28-shape-styles-glass", timeout: 20) {
            let log = P6Log()
            let px = await onMain { () -> [[Int]] in
                guard let img = p28Render(P28StyleSwatches(log: log), 70, 10) else { return [] }
                return (0..<7).map { p6Px(img, $0 * 10 + 5, 5) }
            }
            let d = "swatches \(px.map { $0.prefix(3).map(String.init).joined(separator: ",") }); \(log.all.first ?? "")"
            try expect(px.count == 7, d)
            // link: blue; placeholder: grey; window background: white; secondary red: lighter red; drawing group: red
            try expect(px[0][2] > 200 && px[0][0] < 80, "link \(d)")
            try expect(abs(px[1][0] - px[1][2]) < 20 && px[1][0] > 120 && px[1][0] < 235, "placeholder \(d)")
            try expect(px[3][0] > 240 && px[3][1] > 240 && px[3][2] > 240, "window background \(d)")
            try expect(px[4][0] > 240 && px[4][1] > 80 && px[4][1] < 230, "secondary \(d)")
            try expect(px[6][0] > 240 && px[6][1] < 80 && px[6][2] < 80, "drawing group \(d)")   // system red 255,56,60
            try expect(log.has("prominence standard"), d)
            // glass + hover effects + values
            let glass = await onMain { () -> Int in
                let v = GlassEffectContainer(spacing: 4) {
                    Color.red.frame(width: 20, height: 20).glassEffect(Glass.regular.tint(.blue).interactive(), in: DefaultGlassEffectShape())
                        .glassEffectTransition(GlassEffectTransition.matchedGeometry)
                }
                return p28Render(v.background(Color.white), 30, 30) != nil ? 1 : 0
            }
            #if !os(watchOS)
            let hovers = [p28HoverName(HoverEffect.highlight), p28HoverName(HoverEffect.lift), p28HoverName(HoverEffect.automatic), p28HoverName(HoverEffect(P28Hover()))]
            _ = [AutomaticHoverEffect.self, HighlightHoverEffect.self, LiftHoverEffect.self] as [Any.Type]
            #else
            let hovers: [String] = []
            #endif
            try expect(Glass.regular != Glass.clear && Glass.identity == Glass.identity && Prominence.increased != Prominence.standard
                       && SymbolColorRenderingMode.gradient != SymbolColorRenderingMode.flat && SymbolVariableValueMode.draw != SymbolVariableValueMode.color
                       && ContentShapeKinds.interaction.contains(.interaction) && !ContentShapeKinds.dragPreview.contains(.contextMenuPreview), "values")
            return "\(d); glass rendered \(glass); hovers \(hovers)"
        })

        // MARK: SwiftUICore symbol effect transitions + preferred color scheme preference: a child asking for dark
        // reaches the parent through PreferredColorSchemeKey
        c.append(check("SwiftUICore", "p28-preferred-scheme-transitions", timeout: 20) {
            let log = P6Log()
            let v = VStack {
                Image(systemName: "star").transition(SymbolEffectTransition.symbolEffect).symbolColorRenderingMode(.gradient).symbolVariableValueMode(.draw)
                Text("dark please").preferredColorScheme(.dark)
            }
            .onPreferenceChange(PreferredColorSchemeKey.self) { s in log.add("preferred \(s.map { $0 == .dark ? "dark" : "light" } ?? "nil")") }
            .layoutDirectionBehavior(LayoutDirectionBehavior.mirrors(in: .rightToLeft))
            let close = try await onMain { try p6HostSwiftUI(v) }
            defer { Task { @MainActor in close() } }
            _ = await p6Wait(4) { log.has("preferred dark") }
            let dirs = "\(HorizontalDirection.Set.all.contains(.leading)) \(VerticalDirection.Set.all.contains(.down)) \(HorizontalDirection.allCases.count)"
            try expect(log.has("preferred dark"), "\(log.all)")
            return "\(log.all); directions \(dirs); transaction offset \(Transaction().scrollContentOffsetAdjustmentBehavior as ScrollContentOffsetAdjustmentBehavior)"
        })

        // MARK: SwiftUICore shaders + accessibility values: a ShaderLibrary from the app's metallib (its stitchable
        // functions by name), accessibility options / categories / kinds / technologies
        #if !os(watchOS)
        c.append(check("SwiftUICore", "p28-shader-library-ax-values") {
            let url = Bundle.main.url(forResource: "sdkcovCI", withExtension: "metallib")
            try skipIf(url == nil, "no sdkcovCI.metallib in this platform's app")
            let lib = ShaderLibrary(url: url!)
            let f: ShaderFunction = lib.sdkcovSwapRB
            let g = ShaderFunction(library: lib, name: "sdkcovSwapRB")
            let shader: Shader = f()
            try expect(f == g && f.name == "sdkcovSwapRB" && f.library == lib && lib != ShaderLibrary.default && shader == g(), "shader function \(f.name)")
            var tech = AccessibilityTechnologies.voiceOver; tech.formUnion(.switchControl)
            try expect(tech.contains(.switchControl) && !AccessibilityTechnologies.voiceOver.contains(.switchControl)
                       && AccessibilityActionCategory.edit != AccessibilityActionCategory.default && AccessibilityActionKind.escape != AccessibilityActionKind.magicTap
                       && AccessibilityDirectTouchOptions.silentOnTouch != AccessibilityDirectTouchOptions.requiresActivation
                       && GestureInputKinds.all.contains(.directTouch) && !GestureInputKinds.pencil.contains(.pointer), "ax values")
            return "shader \(f.name) from \(url!.lastPathComponent); ax values"
        })
        #endif

        // MARK: SwiftUI drag and drop: draggable / drop delegate / drop destination install UIKit drag and drop
        // interactions; DropProposal / DropOperation / configurations
        #if os(iOS) || os(visionOS)
        c.append(check("SwiftUI", "p28-drag-drop-interactions", timeout: 20) {
            let log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P28DragRoot(log: log)) }
            defer { Task { @MainActor in close() } }
            _ = await p6Wait(4) { p28Last(log, "draggable") != nil }
            try await Task.sleep(for: .milliseconds(400))
            let ints = await onMain { () -> [String] in
                guard let w = p6LastWindow else { return [] }
                var out: [String] = []
                func walk(_ v: UIView) { out += v.interactions.map { String(describing: type(of: $0)) }; v.subviews.forEach(walk) }
                walk(w); return out
            }
            let counts = Dictionary(ints.map { ($0, 1) }, uniquingKeysWith: +)
            let d = "interactions \(counts.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" })"
            try expect(counts["UIDragInteraction", default: 0] >= 1 && counts["UIDropInteraction", default: 0] >= 1, d)
            let p = DropProposal(operation: .copy)
            try expect(p.operation == DropOperation.copy && DropOperation.move != DropOperation.forbidden, "proposal")
            return d
        })
        #endif

        // MARK: SwiftUI tables + outlines on an iPhone (compact: the first column as a list), column customization,
        // custom column / row content, row item providers; OutlineGroup rows; editable ForEach types
        #if os(iOS) || os(visionOS)
        c.append(check("SwiftUI", "p28-table-outline-editable", timeout: 20) {
            let log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P28TableRoot(log: log)) }
            defer { Task { @MainActor in close() } }
            _ = await p6Wait(4) { log.has("outline root") }
            try await Task.sleep(for: .milliseconds(500))
            let cells = await onMain { () -> [String] in
                guard let w = p6LastWindow else { return [] }
                return p6Find(w, UICollectionViewCell.self).filter { !$0.isHidden }.map { c in
                    p6Find(c, UILabel.self).compactMap(\.text).joined(separator: "/")
                }.filter { !$0.isEmpty }
            }
            let d = "\(log.all); cells \(cells); editable \(p28EditableTypes())"
            try expect(log.all.contains { $0.hasPrefix("table cust id hidden") } && log.has("outline root"), d)
            return d
        })
        #endif

        // MARK: SwiftUI documents: a ReferenceFileDocument's snapshot; the iOS 27 Document reader and writer round trip
        // through a file; NewDocumentButton's default label
        #if os(iOS) || os(visionOS)
        c.append(check("SwiftUI", "p28-documents-reader-writer", timeout: 20) {
            let ref = P28RefDoc(text: "hello")
            let snap = try ref.snapshot(contentType: .plainText)
            let doc = P28Doc()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("p28doc.txt")
            try await P28TextWriter().write(snapshot: "v2", to: url, previous: "v1", progress: ProgressManager(totalCount: 1).subprogress(assigningCount: 1))
            let back = try await P28TextReader().read(from: url, progress: ProgressManager(totalCount: 1).subprogress(assigningCount: 1))
            try await doc.apply(snapshot: back, previous: nil)
            let docSnap = try await doc.snapshot(contentType: .plainText)
            try expect(docSnap == back && snap == "hello" && back == "v2 (was v1)" && P28Doc.readableContentTypes == [.plainText] && P28RefDoc.writableContentTypes == [.plainText], "snapshot \(snap) read \(back)")
            _ = doc
            return "snapshot \(snap); round trip \(back)"
        })
        #endif

        return c
    }
}

/// state the check drives from outside (a navigation path, a tab selection)
@Observable private final class P28Box<T> {
    var value: T
    init(_ v: T) { value = v }
}
