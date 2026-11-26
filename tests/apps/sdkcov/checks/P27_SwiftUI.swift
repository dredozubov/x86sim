// SDK coverage, round 30 (P27): public API of the SDK not yet referenced by any check (~/scratch/r30/apisurf.py),
// area: SwiftUI. Each check asserts what Apple's simulator answers (ref-mac.sh --only). SwiftUI / SwiftUICore: shapes
// and paths, animation math (curves, keyframes, custom animations, vector arithmetic), timeline schedules, the Layout
// protocol and stack layouts, alignment guides, preferences + anchors, environment values and actions, custom control
// styles, shape styles / blend modes / Canvas filters / text renderers by pixels, scrolling, representables.
import Foundation
import Synchronization
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Charts)
import Charts
#endif
#if canImport(MapKit)
import MapKit
#endif
#if canImport(AppIntents)
import AppIntents
#endif
#if canImport(WidgetKit) && !os(tvOS)
import WidgetKit
#endif
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif
#if canImport(TipKit)
import TipKit
#endif
#if os(iOS) || os(visionOS)
import WebKit
import _WebKit_SwiftUI
#endif

// MARK: helpers

/// render `v` at scale 1 and return its pixels (nil: ImageRenderer gave no image)
@MainActor private func p27Render<V: View>(_ v: V, _ w: CGFloat, _ h: CGFloat) -> CGImage? {
    let r = ImageRenderer(content: v.frame(width: w, height: h)); r.scale = 1
    return r.cgImage
}
private final class P27Once: @unchecked Sendable { let l = NSLock(); var done = false; func take() -> Bool { l.withLock { if done { return false }; done = true; return true } } }
/// `f`'s value, or a timeout error after `secs`: returns without waiting for `f` (a network service that never answers
/// and ignores cancellation)
private func p27Timeout<T>(_ secs: Double, _ f: @escaping () async throws -> T) async throws -> T {
    let once = P27Once()
    return try await withCheckedThrowingContinuation { (k: CheckedContinuation<T, Error>) in
        nonisolated(unsafe) let k = k
        nonisolated(unsafe) let f = f
        Task { do { let v = try await f(); if once.take() { nonisolated(unsafe) let v = v; k.resume(returning: v) } } catch { if once.take() { k.resume(throwing: error) } } }
        Task { try? await Task.sleep(for: .seconds(secs)); if once.take() { k.resume(throwing: NSError(domain: "p27.timeout", code: Int(secs))) } }
    }
}
private func p27Close(_ a: Double, _ b: Double, _ tol: Double = 0.01) -> Bool { abs(a - b) <= tol }
private func p27R(_ r: CGRect) -> String { "\(Int(r.minX.rounded())),\(Int(r.minY.rounded())),\(Int(r.width.rounded())),\(Int(r.height.rounded()))" }
private func p27RectEq(_ r: CGRect, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ tol: CGFloat = 0.5) -> Bool {
    abs(r.minX - x) <= tol && abs(r.minY - y) <= tol && abs(r.width - w) <= tol && abs(r.height - h) <= tol
}
/// the inset shape of any insettable shape (generic over InsettableShape)
private func p27Inset<S: InsettableShape>(_ s: S, _ by: CGFloat) -> S.InsetShape { s.inset(by: by) }
/// a VectorArithmetic value scaled and summed generically
private func p27Lerp<V: VectorArithmetic>(_ a: V, _ b: V, _ t: Double) -> V { var d = b - a; d.scale(by: t); return a + d }

// MARK: animation types

private struct P27KF { var a = 0.0; var b = 0.0 }
/// a linear custom animation over 0.6 s (CustomAnimation / AnimationContext)
private struct P27Linear: CustomAnimation {
    func animate<V: VectorArithmetic>(value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? {
        if time >= 0.6 { return nil }
        var v = value; v.scale(by: time / 0.6); return v
    }
}
private struct P27TK: TransactionKey { static let defaultValue = 0 }
private struct P27Probe: ViewModifier, Animatable {
    var x: Double; let log: P6Log
    var animatableData: Double { get { x } set { x = newValue; log.add(String(format: "%.4f", newValue)) } }
    func body(content: Content) -> some View { content.opacity(x) }
}
@Observable private final class P27M {
    var on = false
    var n = 0
    var text = ""
    var flag = false
}
private struct P27AnimRoot: View {
    @Bindable var m: P27M; let log: P6Log
    var body: some View { Color.red.frame(width: 20, height: 20).modifier(P27Probe(x: m.on ? 1 : 0, log: log)) }
}

// MARK: timeline schedule

private struct P27Sched: TimelineSchedule {
    let dates: [Date]
    func entries(from startDate: Date, mode: TimelineScheduleMode) -> [Date] { dates.filter { $0 >= startDate } }
}

// MARK: layout

private struct P27LK: LayoutValueKey { static let defaultValue: CGFloat = 0 }
/// places its subviews on a diagonal: x = sum of earlier widths, y = each subview's P27LK value
private struct P27Diag: Layout {
    let log: P6Log
    static var layoutProperties: LayoutProperties { var p = LayoutProperties(); p.stackOrientation = .horizontal; return p }
    func sizeThatFits(proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout ()) -> CGSize {
        var w: CGFloat = 0, h: CGFloat = 0
        for s: LayoutSubview in subviews { let z = s.sizeThatFits(.unspecified); w += z.width; h = max(h, z.height + s[P27LK.self]) }
        return CGSize(width: w, height: h)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (i, s) in subviews.enumerated() {
            let z = s.sizeThatFits(.unspecified)
            let d: ViewDimensions = s.dimensions(in: ProposedViewSize(z))
            let sp: ViewSpacing = s.spacing
            if i > 0 { log.add("gap\(i) \(Int(subviews[i - 1].spacing.distance(to: sp, along: .horizontal)))") }
            log.add("s\(i) \(Int(x - bounds.minX)),\(Int(s[P27LK.self])) \(Int(d.width))x\(Int(d.height)) ctr \(Int(d[HorizontalAlignment.center])) prio \(Int(s.priority))")
            s.place(at: CGPoint(x: x, y: bounds.minY + s[P27LK.self]), anchor: .topLeading, proposal: ProposedViewSize(z))
            x += z.width
        }
    }
}
private struct P27Quarter: AlignmentID { static func defaultValue(in d: ViewDimensions) -> CGFloat { d.height / 4 } }
private struct P27SumKey: PreferenceKey {
    static let defaultValue = 0
    static func reduce(value: inout Int, nextValue: () -> Int) { value += nextValue() }
}
private struct P27AnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) { value = value ?? nextValue() }
}
private struct P27Frame: ViewModifier {
    let name: String; let log: P6Log
    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGRect.self) { $0.frame(in: .named("p27")) } action: { log.add("\(name) \(p27R($0))") }
    }
}
private struct P27LayoutRoot: View {
    let log: P6Log; let sums: P6Log
    @Namespace var ns
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            P27Diag(log: log) {
                Color.red.frame(width: 20, height: 10).layoutValue(key: P27LK.self, value: 0)
                Color.green.frame(width: 30, height: 10).layoutValue(key: P27LK.self, value: 10).layoutPriority(2)
                Color.blue.frame(width: 40, height: 10).layoutValue(key: P27LK.self, value: 20)
            }.modifier(P27Frame(name: "diag", log: log))
            AnyLayout(HStackLayout(spacing: 0)) { Color.red.frame(width: 20, height: 10); Color.green.frame(width: 30, height: 15) }.modifier(P27Frame(name: "hstack", log: log))
            AnyLayout(VStackLayout(spacing: 0)) { Color.red.frame(width: 20, height: 10); Color.green.frame(width: 30, height: 15) }.modifier(P27Frame(name: "vstack", log: log))
            AnyLayout(ZStackLayout()) { Color.red.frame(width: 20, height: 10); Color.green.frame(width: 30, height: 15) }.modifier(P27Frame(name: "zstack", log: log))
            HStack(alignment: VerticalAlignment(P27Quarter.self), spacing: 0) {
                Color.red.frame(width: 10, height: 40).modifier(P27Frame(name: "q40", log: log))
                Color.green.frame(width: 10, height: 20).modifier(P27Frame(name: "q20", log: log))
            }
            Color.red.frame(width: 10, height: 10).padding(EdgeInsets(top: 1, leading: 2, bottom: 3, trailing: 4)).modifier(P27Frame(name: "insets", log: log))
            Color.gray.frame(width: 60, height: 20, alignment: Alignment(horizontal: .trailing, vertical: .bottom))
                .overlay(alignment: .bottomTrailing) { Color.red.frame(width: 10, height: 5).modifier(P27Frame(name: "corner", log: log)) }
            HStack(spacing: 0) {
                Color.red.frame(width: 7, height: 7).preference(key: P27SumKey.self, value: 1)
                Color.red.frame(width: 7, height: 7).preference(key: P27SumKey.self, value: 2)
                Color.red.frame(width: 7, height: 7).preference(key: P27SumKey.self, value: 3)
            }
            .onPreferenceChange(P27SumKey.self) { v in sums.add("sum \(v)") }
            Color.blue.frame(width: 25, height: 12).padding(.leading, 5)
                .anchorPreference(key: P27AnchorKey.self, value: .bounds) { $0 }
                .overlayPreferenceValue(P27AnchorKey.self) { a in
                    GeometryReader { g in
                        let _ = a.map { log.add("anchor \(p27R(g[$0]))") }
                        let _ = log.add("geo \(Int(g.size.width))x\(Int(g.size.height)) local \(p27R(g.frame(in: LocalCoordinateSpace.local))) global-named \(g.frame(in: GlobalCoordinateSpace.global).width == g.frame(in: NamedCoordinateSpace.named("p27")).width)")
                        Color.clear
                    }
                }
            // matchedGeometryEffect: the follower takes the source's frame
            ZStack(alignment: .topLeading) {
                Color.red.frame(width: 33, height: 11).offset(x: 40).matchedGeometryEffect(id: "m", in: ns, properties: MatchedGeometryProperties.frame, isSource: true)
                Color.green.modifier(P27Frame(name: "matched", log: log)).matchedGeometryEffect(id: "m", in: ns, properties: .frame, isSource: false)
            }.frame(width: 100, height: 20, alignment: .topLeading)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .coordinateSpace(.named("p27"))
    }
}

// MARK: environment

private struct P27EnvKey: EnvironmentKey { static let defaultValue = 7 }
extension EnvironmentValues {
    fileprivate var p27: Int { get { self[P27EnvKey.self] } set { self[P27EnvKey.self] = newValue } }
}
private struct P27EnvReader: View {
    let tag: String; let log: P6Log
    @Environment(\.p27) var custom
    @Environment(\.colorScheme) var scheme
    @Environment(\.dynamicTypeSize) var dts
    @Environment(\.layoutDirection) var dir
    @Environment(\.legibilityWeight) var weight
    @Environment(\.redactionReasons) var redaction
    @Environment(\.colorSchemeContrast) var contrast
    @Environment(\.multilineTextAlignment) var align
    @Environment(\.font) var font
    @Environment(\.controlSize) var csize
    #if !os(watchOS)
    @Environment(\.horizontalSizeClass) var hsc
    #endif
    @ScaledMetric(relativeTo: .body) var metric: CGFloat = 10
    var body: some View {
        var parts = ["\(custom)", scheme == ColorScheme.dark ? "dark" : "light", "\(dts)", dir == LayoutDirection.rightToLeft ? "rtl" : "ltr",
                     weight == LegibilityWeight.bold ? "bold" : "\(String(describing: weight))", redaction.contains(RedactionReasons.placeholder) ? "placeholder" : "unredacted",
                     contrast == ColorSchemeContrast.standard ? "std" : "inc", align == TextAlignment.center ? "center" : "\(align)",
                     font == Font.title ? "title" : (font == nil ? "nofont" : "otherfont"), csize == ControlSize.mini ? "mini" : "\(csize)",
                     metric > 10.5 ? "scaled-up" : (metric < 9.5 ? "scaled-down" : "metric-10")]
        #if !os(watchOS)
        parts.append(hsc == UserInterfaceSizeClass.compact ? "compact" : "\(String(describing: hsc))")
        #endif
        log.add("\(tag) " + parts.joined(separator: "|"))
        return Text(tag)
    }
}
private struct P27EnvRoot: View {
    let log: P6Log
    var body: some View {
        VStack {
            P27EnvReader(tag: "default", log: log)
            P27EnvReader(tag: "set", log: log)
                .environment(\.p27, 42)
                .environment(\.colorScheme, .dark)
                .environment(\.dynamicTypeSize, .accessibility3)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.legibilityWeight, .bold)
                .redacted(reason: .placeholder)
                .multilineTextAlignment(.center)
                .font(.title)
                .controlSize(.mini)
                #if !os(watchOS)
                .environment(\.horizontalSizeClass, .compact)
                #endif
        }
    }
}

// environment actions: refresh / openURL / dismiss / custom action
private struct P27RefreshCaller: View {
    let log: P6Log
    @Environment(\.refresh) var refresh
    @Environment(\.openURL) var openURL
    var body: some View {
        Text("refresh").task {
            log.add("refresh \(refresh == nil ? "nil" : "set")")
            if let r: RefreshAction = refresh { await r() }
            let o: OpenURLAction = openURL
            o(URL(string: "p27://open")!)
        }
    }
}
private struct P27SheetBody: View {
    let log: P6Log
    @Environment(\.dismiss) var dismiss
    @Environment(\.isPresented) var isPresented
    var body: some View {
        Text("sheet").task {
            log.add("sheet presented \(isPresented)")
            try? await Task.sleep(for: .milliseconds(600))
            let d: DismissAction = dismiss
            d()
        }
    }
}
private struct P27ActionsRoot: View {
    @Bindable var m: P27M; let log: P6Log
    var body: some View {
        P27RefreshCaller(log: log)
            .refreshable { log.add("refreshed") }
            .environment(\.openURL, OpenURLAction { url in log.add("open \(url.absoluteString)"); return .handled })
            .sheet(isPresented: $m.on, onDismiss: { log.add("onDismiss") }) { P27SheetBody(log: log) }
    }
}

// MARK: AppStorage

private struct P27StorageRoot: View {
    let log: P6Log
    @AppStorage("p27.count") var count = 0
    @AppStorage("p27.name") var name = "none"
    var body: some View {
        let _ = log.add("count \(count) name \(name)")
        Text("\(count) \(name)").task { try? await Task.sleep(for: .milliseconds(300)); count = 5 }
    }
}

// MARK: custom control styles

private struct P27ButtonStyle: ButtonStyle {
    let log: P6Log
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        let _ = log.add("button pressed \(configuration.isPressed) role \(configuration.role == ButtonRole.destructive ? "destructive" : "other")")
        return configuration.label.padding(3)
    }
}
private struct P27PrimStyle: PrimitiveButtonStyle {
    let log: P6Log
    func makeBody(configuration: PrimitiveButtonStyleConfiguration) -> some View {
        configuration.label.task { log.add("primitive trigger"); configuration.trigger() }
    }
}
private struct P27ToggleStyle: ToggleStyle {
    let log: P6Log
    func makeBody(configuration: ToggleStyleConfiguration) -> some View {
        let _ = log.add("toggle \(configuration.isOn)")
        return configuration.label.task { if !configuration.isOn { configuration.$isOn.wrappedValue = true } }
    }
}
private struct P27LabelStyle: LabelStyle {
    let log: P6Log
    func makeBody(configuration: LabelStyleConfiguration) -> some View {
        let _ = log.add("label styled")
        return HStack { configuration.icon; configuration.title }
    }
}
private struct P27ProgressStyle: ProgressViewStyle {
    let log: P6Log
    func makeBody(configuration: ProgressViewStyleConfiguration) -> some View {
        let _ = log.add("progress \(configuration.fractionCompleted.map { String(format: "%.2f", $0) } ?? "nil")")
        return Color.blue.frame(width: 20, height: 4)
    }
}
#if !os(tvOS)
private struct P27GaugeStyle: GaugeStyle {
    let log: P6Log
    func makeBody(configuration: GaugeStyleConfiguration) -> some View {
        let _ = log.add("gauge \(String(format: "%.2f", configuration.value))")
        return configuration.label
    }
}
#endif
private struct P27LabeledStyle: LabeledContentStyle {
    let log: P6Log
    func makeBody(configuration: LabeledContentStyleConfiguration) -> some View {
        let _ = log.add("labeled styled")
        return HStack { configuration.label; configuration.content }
    }
}
#if os(iOS) || os(visionOS)
private struct P27DisclosureStyle: DisclosureGroupStyle {
    let log: P6Log
    func makeBody(configuration: DisclosureGroupStyleConfiguration) -> some View {
        let _ = log.add("disclosure \(configuration.isExpanded)")
        return VStack { configuration.label; if configuration.isExpanded { configuration.content } }
            .task { if !configuration.isExpanded { configuration.$isExpanded.wrappedValue = true } }
    }
}
#endif
#if os(iOS) || os(visionOS)
private struct P27GroupBoxStyle: GroupBoxStyle {
    let log: P6Log
    func makeBody(configuration: GroupBoxStyleConfiguration) -> some View {
        let _ = log.add("groupbox styled")
        return VStack { configuration.label; configuration.content }
    }
}
private struct P27ControlGroupStyle: ControlGroupStyle {
    let log: P6Log
    func makeBody(configuration: ControlGroupStyleConfiguration) -> some View {
        let _ = log.add("controlgroup styled")
        return HStack { configuration.content }
    }
}
private struct P27MenuStyle: MenuStyle {
    let log: P6Log
    func makeBody(configuration: MenuStyleConfiguration) -> some View {
        let _ = log.add("menu styled")
        return Menu(configuration)
    }
}
#endif
private struct P27FormStyle: FormStyle {
    let log: P6Log
    func makeBody(configuration: FormStyleConfiguration) -> some View {
        let _ = log.add("form styled")
        return VStack { configuration.content }
    }
}
private struct P27StylesRoot: View {
    @Bindable var m: P27M; let log: P6Log
    @State var expanded = false
    var body: some View {
        VStack {
            Button("B", role: .destructive) {}.buttonStyle(P27ButtonStyle(log: log))
            Button("P") { log.add("primitive action") }.buttonStyle(P27PrimStyle(log: log))
            Toggle("T", isOn: $m.flag).toggleStyle(P27ToggleStyle(log: log))
            Label("L", systemImage: "star").labelStyle(P27LabelStyle(log: log))
            ProgressView(value: 0.25).progressViewStyle(P27ProgressStyle(log: log))
            LabeledContent("K", value: "V").labeledContentStyle(P27LabeledStyle(log: log))
            #if os(iOS) || os(visionOS)
            DisclosureGroup("D", isExpanded: $expanded) { Text("inside").onAppear { log.add("disclosure content") } }.disclosureGroupStyle(P27DisclosureStyle(log: log))
            #endif
            #if os(iOS) || os(visionOS)
            GroupBox("GB") { Text("x") }.groupBoxStyle(P27GroupBoxStyle(log: log))
            ControlGroup { Button("a") {}; Button("b") {} }.controlGroupStyle(P27ControlGroupStyle(log: log))
            Menu("M") { Button("m1") {} }.menuStyle(P27MenuStyle(log: log))
            #endif
        }
    }
}
/// gauge and form styles: not asked inside P27StylesRoot's stack (Apple's simulator too), so on their own
private struct P27Styles2Root: View {
    let log: P6Log
    var body: some View {
        VStack {
            #if !os(tvOS)
            Gauge(value: 3, in: 0...4) { Text("G") }.gaugeStyle(P27GaugeStyle(log: log))
            #endif
            Form { Text("f") }.formStyle(P27FormStyle(log: log))
        }
    }
}

// MARK: text renderer

private struct P27TextRenderer: TextRenderer {
    let log: P6Log
    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        let runs = layout.flatMap { $0 }
        let glyphs = runs.reduce(0) { $0 + $1.count }
        log.add("lines \(layout.count) runs \(runs.count) glyphs \(glyphs)")
        for line in layout { ctx.draw(line, options: .disablesSubpixelQuantization) }
    }
}

// MARK: scrolling

@Observable private final class P27ScrollM { var pos = ScrollPosition(idType: Int.self); var jump = 0 }
private struct P27ScrollRoot: View {
    let log: P6Log
    @Bindable var m: P27ScrollM
    var body: some View {
        ScrollViewReader { (proxy: ScrollViewProxy) in
            ScrollView {
                LazyVStack(spacing: 0) { ForEach(0..<200, id: \.self) { i in Color(white: Double(i % 2)).frame(height: 50).id(i) } }
            }
            .scrollPosition($m.pos)
            .onScrollGeometryChange(for: CGFloat.self) { (g: ScrollGeometry) in g.contentOffset.y + g.contentInsets.top } action: { _, y in log.add("y \(Int(y.rounded()))") }
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentSize.height } action: { _, h in log.add("h \(Int(h))") }
            .onScrollPhaseChange { (old: ScrollPhase, new: ScrollPhase, ctx: ScrollPhaseChangeContext) in log.add("phase \(new)") }
            .onChange(of: m.jump) { _, j in if j > 0 { proxy.scrollTo(j, anchor: UnitPoint.top) } }
            .scrollIndicators(ScrollIndicatorVisibility.hidden)
            .scrollBounceBehavior(ScrollBounceBehavior.basedOnSize)
            .scrollTargetBehavior(PagingScrollTargetBehavior.paging)
        }
    }
}

// MARK: representables (UIKit)

#if os(iOS) || os(visionOS) || os(tvOS)
private final class P27RepView: UIView {}
private struct P27Rep: UIViewRepresentable {
    let value: Int; let log: P6Log
    final class Coordinator { var made = 0 }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: UIViewRepresentableContext<P27Rep>) -> P27RepView { context.coordinator.made += 1; log.add("make"); let v = P27RepView(); v.backgroundColor = .red; return v }
    func updateUIView(_ v: P27RepView, context: Context) { v.tag = value; log.add("update \(value) made \(context.coordinator.made)") }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: P27RepView, context: Context) -> CGSize? { CGSize(width: 37, height: 23) }
    static func dismantleUIView(_ v: P27RepView, coordinator: Coordinator) {}
}
private final class P27RepVC: UIViewController {}
private struct P27RepController: UIViewControllerRepresentable {
    let log: P6Log
    func makeUIViewController(context: UIViewControllerRepresentableContext<P27RepController>) -> P27RepVC { log.add("vc make"); return P27RepVC() }
    func updateUIViewController(_ vc: P27RepVC, context: Context) { log.add("vc update") }
}
private struct P27RepRoot: View {
    @Bindable var m: P27M; let log: P6Log
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            P27Rep(value: m.n, log: log).modifier(P27Frame(name: "rep", log: log))
            P27RepController(log: log).frame(width: 50, height: 50)
            Spacer(minLength: 0)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).coordinateSpace(.named("p27"))
    }
}
#endif

// MARK: Charts

#if canImport(Charts)
private struct P27Pt: Identifiable { let x: Double; let y: Double; var id: Double { x } }
private let p27Pts = (0..<10).map { P27Pt(x: Double($0), y: Double($0 % 4 + 1)) }
/// a custom chart content type (ChartContent with a ChartContentBuilder body)
private struct P27Marker: ChartContent {
    let y: Double
    var body: some ChartContent { RuleMark(y: .value("t", y)).foregroundStyle(Color.red).lineStyle(StrokeStyle(lineWidth: 2)) }
}
private struct P27ChartRoot: View {
    let log: P6Log
    var body: some View {
        Chart {
            BarMark(x: .value("x", 5.0), y: .value("y", 50.0), width: MarkDimension.fixed(10))
            P27Marker(y: 25)
            AnyChartContent(LineMark(x: .value("x", 1.0), y: .value("y", 10.0)))
        }
        .chartXScale(domain: 0.0...10.0, range: PlotDimensionScaleRange.plotDimension(padding: 0), type: ScaleType.linear)
        .chartYScale(domain: 0.0...100.0)
        .chartXAxis {
            AxisMarks(preset: AxisMarkPreset.aligned, position: AxisMarkPosition.bottom, values: AxisMarkValues.stride(by: 2.5)) { (v: AxisValue) in
                let _ = log.add("axis \(v.index)/\(v.count) \(v.as(Double.self) ?? -1)")
                AxisGridLine(); AxisTick(); AxisValueLabel()
            }
        }
        .chartYAxis(.hidden)
        .chartOverlay { (p: ChartProxy) in
            let w = p.plotSize.width, h = p.plotSize.height
            let x0 = p.position(forX: 0.0) ?? -1, x10 = p.position(forX: 10.0) ?? -1
            let y100 = p.position(forY: 100.0) ?? -1, y0 = p.position(forY: 0.0) ?? -1
            let mid = p.value(atX: w / 2, as: Double.self) ?? -1
            let _ = log.add(String(format: "proxy %.0fx%.0f x0 %.1f x10 %.1f y100 %.1f y0 %.1f mid %.2f", w, h, x0, x10, y100, y0, mid))
            Color.clear
        }
        .frame(width: 200, height: 120)
    }
}
#endif

// MARK: WebKit

#if os(iOS) || os(visionOS)
/// a WKWebView in its own window: navigation + UI delegate, a p27: URL scheme serving `pages`
@MainActor private final class P27Web: NSObject, WKNavigationDelegate, WKUIDelegate, WKURLSchemeHandler {
    var wv: WKWebView!
    var close: () -> Void = {}
    var nav: CheckedContinuation<Void, Error>?
    var pages: [String: String] = [:]
    var alerts: [(String, WKSecurityOrigin)] = []
    var forms: [WKFormInfo] = []
    init(_ cfg: WKWebViewConfiguration) throws {
        super.init()
        cfg.setURLSchemeHandler(self, forURLScheme: "p27")
        wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), configuration: cfg)
        wv.navigationDelegate = self; wv.uiDelegate = self
        let vc = UIViewController(); vc.view.backgroundColor = .white; vc.view.addSubview(wv)
        close = try p6Show(vc).1
    }
    func load(_ go: () -> Void) async throws { try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in nav = k; go() } }
    func webView(_ w: WKWebView, didFinish n: WKNavigation!) { nav?.resume(); nav = nil }
    func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { nav?.resume(throwing: e); nav = nil }
    func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { nav?.resume(throwing: e); nav = nil }
    func webView(_ w: WKWebView, runJavaScriptAlertPanelWithMessage m: String, initiatedByFrame f: WKFrameInfo, completionHandler: @escaping () -> Void) {
        alerts.append((m, f.securityOrigin)); completionHandler()
    }
    func webView(_ w: WKWebView, willSubmitForm info: WKFormInfo) async { forms.append(info) }
    func webView(_ w: WKWebView, start t: any WKURLSchemeTask) {
        let path = t.request.url?.path ?? ""
        let html = Data((pages[path] ?? "<title>404</title>").utf8)
        t.didReceive(HTTPURLResponse(url: t.request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "text/html", "Content-Length": "\(html.count)"])!)
        t.didReceive(html); t.didFinish()
    }
    func webView(_ w: WKWebView, stop t: any WKURLSchemeTask) {}
    func teardown() { wv.removeFromSuperview(); close() }
}
/// a SwiftUI WebPage scheme handler: p27s:/<x> answers a page titled <x>
private struct P27SchemeHandler: URLSchemeHandler {
    func reply(for request: URLRequest) -> AsyncThrowingStream<URLSchemeTaskResult, any Error> {
        AsyncThrowingStream { k in
            let name = request.url?.lastPathComponent ?? "?"
            let html = Data("<html><head><title>\(name)</title></head><body>page \(name)</body></html>".utf8)
            k.yield(.response(URLResponse(url: request.url!, mimeType: "text/html", expectedContentLength: html.count, textEncodingName: "utf-8")))
            k.yield(.data(html))
            k.finish()
        }
    }
}
#endif

// MARK: AppIntents

#if canImport(AppIntents)
private struct P27Note: TransientAppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "P27 note" }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(text)") }
    @EntityProperty(title: "Text") var text: String
    init() { text = "" }
}
private struct P27Item: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "P27 item" }
    static var defaultQuery: P27ItemQuery { P27ItemQuery() }
    let id: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(id)") }
    static let all = ["alpha", "beta", "gamma"].map { P27Item(id: $0) }
}
private struct P27ItemQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [P27Item] { P27Item.all.filter { identifiers.contains($0.id) } }
    func entities(matching string: String) async throws -> [P27Item] { P27Item.all.filter { $0.id.contains(string) } }
    func suggestedEntities() async throws -> [P27Item] { P27Item.all }
}
private struct P27Options: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<Int> {
        IntentItemCollection(promptLabel: "Pick", sections: [IntentItemSection("Small", items: [IntentItem(1, title: "one"), IntentItem(2, title: "two")]),
                                                             IntentItemSection("Big", items: [IntentItem(100, title: "hundred")])])
    }
    func defaultResult() async -> Int? { 2 }
}
private struct P27ProgressIntent: ProgressReportingIntent {
    static var title: LocalizedStringResource { "P27 progress" }
    static var openAppWhenRun: Bool { false }
    init() {}
    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        progress.totalUnitCount = 4
        for _ in 0..<4 { progress.completedUnitCount += 1 }
        return .result(value: Int(progress.fractionCompleted * 100))
    }
}
private struct P27SetIntent: SetValueIntent {
    static var title: LocalizedStringResource { "P27 set" }
    @IntentParameter(title: "Value") var value: Int
    init() {}
    func perform() async throws -> some IntentResult & ReturnsValue<Int> { .result(value: value * 2) }
}
private struct P27DeleteIntent: DeleteIntent {
    static var title: LocalizedStringResource { "P27 delete" }
    @IntentParameter(title: "Items") var entities: [P27Item]
    init() {}
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> { .result(value: entities.map(\.id)) }
}
private struct P27MakeNoteIntent: AppIntent {
    static var title: LocalizedStringResource { "P27 make note" }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    init() {}
    func perform() async throws -> some IntentResult & ReturnsValue<P27Note> { var n = P27Note(); n.text = "made"; return .result(value: n) }
}
#endif

#if canImport(ActivityKit) && os(iOS)
private struct P27LiveAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable { var step: Int }
    var name: String
}
#endif
#if canImport(TipKit)
private struct P27Tip: Tip {
    var id: String { "p27-tip" }
    var title: Text { Text("P27 tip") }
    var message: Text? { Text("message") }
    var options: [any TipOption] { [Tips.MaxDisplayCount(3)] }
}
private struct P27TipStyle: TipViewStyle {
    let log: P6Log
    func makeBody(configuration: TipViewStyleConfiguration) -> some View {
        let _ = log.add("style asked, actions \(configuration.actions.count)")
        return VStack { configuration.title; configuration.message }
    }
}
#endif

// MARK: transitions, container values, dynamic properties, environmental modifiers

private struct P27Trans: Transition {
    let log: P6Log
    static var properties: TransitionProperties { TransitionProperties(hasMotion: false) }
    func body(content: Content, phase: TransitionPhase) -> some View {
        let _ = log.add("phase \(phase == .willAppear ? "willAppear" : phase == .identity ? "identity" : "didDisappear") \(phase.isIdentity)")
        content.opacity(phase.isIdentity ? 1 : 0)
    }
}
private struct P27TransRoot: View {
    @Bindable var m: P27M; let log: P6Log
    var body: some View {
        VStack {
            if m.on { Color.red.frame(width: 20, height: 20).transition(AnyTransition(P27Trans(log: log))) }
            Text("\(m.n)").contentTransition(ContentTransition.numericText())
            if m.flag { Color.blue.frame(width: 10, height: 10).transition(BlurReplaceTransition(configuration: .downUp)) }
        }.frame(width: 100, height: 100)
    }
}
private struct P27CVKey: ContainerValueKey { static let defaultValue = 0 }
extension ContainerValues {
    fileprivate var p27: Int { get { self[P27CVKey.self] } set { self[P27CVKey.self] = newValue } }
}
private struct P27Board<Content: View>: View {
    let log: P6Log
    @ViewBuilder var content: Content
    var body: some View {
        VStack {
            Group(subviews: content) { (subs: SubviewsCollection) in
                let slice: SubviewsCollectionSlice = subs[1...]
                let _ = log.add("subviews \(subs.count) slice \(slice.count) values \(subs.map { $0.containerValues.p27 })")
                ForEach(subviews: content) { (sv: Subview) in sv }
            }
            Group(sections: content) { (secs: SectionCollection) in
                Color.clear.frame(width: 1, height: 1).onAppear {
                    log.add("sections \(secs.count) \(secs.map { (s: SectionConfiguration) in "\(s.content.count)" }.joined(separator: ","))")
                }
            }
        }
    }
}
private struct P27CVRoot: View {
    let log: P6Log
    var body: some View {
        P27Board(log: log) {
            Section { Text("a").containerValue(\.p27, 1); Text("b").containerValue(\.p27, 2) }
            Section { Text("c") }
        }
    }
}
private struct P27Counter: DynamicProperty {
    @State var n = 0
    let log: P6Log
    mutating func update() { log.add("dynamic update") }
}
private struct P27Tag: ViewModifier {
    let tag: String; let log: P6Log
    func body(content: Content) -> some View { content.onAppear { log.add("tag \(tag)") } }
}
private struct P27EnvMod: EnvironmentalModifier {
    let log: P6Log
    func resolve(in env: EnvironmentValues) -> P27Tag { P27Tag(tag: env.layoutDirection == .rightToLeft ? "rtl" : "ltr", log: log) }
}
/// a @ViewBuilder function: one branch or the other
@ViewBuilder private func p27Build(_ b: Bool) -> some View {
    if b { Text(LocalizedStringKey("p27-key")) } else { Color.clear }
}
private struct P27DynRoot: View {
    let log: P6Log
    var counter: P27Counter
    init(log: P6Log) { self.log = log; counter = P27Counter(log: log) }
    var body: some View {
        let tagged: ModifiedContent<Text, P27Tag> = Text("t").modifier(P27Tag(tag: "plain", log: log))
        VStack {
            tagged
            Text("e").modifier(P27EnvMod(log: log)).environment(\.layoutDirection, .rightToLeft)
            p27Build(true)
        }
    }
}
private func p27Fill<S: ShapeStyle>(_ s: S) -> some View { Rectangle().fill(s) }

#if os(iOS)
// MARK: styles through their UIKit counterparts (iOS)
@Observable private final class P27FormM { var a = ""; var b = ""; var pick = 1; var date = Date(timeIntervalSince1970: 0); var text = "t" }
private struct P27UIStylesRoot: View {
    @Bindable var m: P27FormM
    var body: some View {
        ScrollView {
            VStack {
                TextField("rounded", text: $m.a).textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("plain", text: $m.b).textFieldStyle(PlainTextFieldStyle())
                TextField("default", text: $m.b).textFieldStyle(DefaultTextFieldStyle())
                Picker("w", selection: $m.pick) { ForEach(0..<3, id: \.self) { Text("\($0)") } }.pickerStyle(WheelPickerStyle())
                Picker("s", selection: $m.pick) { ForEach(0..<3, id: \.self) { Text("\($0)") } }.pickerStyle(SegmentedPickerStyle())
                Picker("m", selection: $m.pick) { ForEach(0..<3, id: \.self) { Text("\($0)") } }.pickerStyle(MenuPickerStyle())
                DatePicker("wd", selection: $m.date).datePickerStyle(WheelDatePickerStyle())
                DatePicker("gd", selection: $m.date).datePickerStyle(GraphicalDatePickerStyle())
                DatePicker("cd", selection: $m.date).datePickerStyle(DefaultDatePickerStyle())
                TextEditor(text: $m.text).textEditorStyle(AutomaticTextEditorStyle()).frame(height: 40)
            }
        }
    }
}
private struct P27ListRoot<S: ListStyle>: View {
    let style: S
    var body: some View { List { Section("S") { Text("row 0"); Text("row 1") } }.listStyle(style) }
}

// MARK: accessibility elements (iOS)
private struct P27AXRoot: View {
    let log: P6Log
    var body: some View {
        VStack {
            Text("P27 Title").accessibilityAddTraits(AccessibilityTraits.isHeader).accessibilityHeading(AccessibilityHeadingLevel.h1)
            Text("v").accessibilityLabel("P27 Label").accessibilityValue("42").accessibilityHint("P27 hint")
                .accessibilityCustomContent(AccessibilityCustomContentKey("Size"), "big")
                .accessibilityAction(named: "P27 Act") { log.add("custom action") }
                .accessibilityAdjustableAction { (d: AccessibilityAdjustmentDirection) in log.add(d == .increment ? "increment" : "decrement") }
            HStack { Text("P27 A"); Text("P27 B") }.accessibilityElement(children: AccessibilityChildBehavior.combine)
            Button("P27 Button") { log.add("button") }
            Text("hidden").accessibilityHidden(true)
        }
    }
}
/// every accessibility element under `root` (UIKit views and their accessibilityElements), depth first
@MainActor private func p27AXElements(_ root: NSObject) -> [NSObject] {
    var out: [NSObject] = [], seen = Set<ObjectIdentifier>()
    func walk(_ o: NSObject, _ depth: Int) {
        guard depth < 40, seen.insert(ObjectIdentifier(o)).inserted else { return }
        if o.isAccessibilityElement { out.append(o) }
        if let els = o.accessibilityElements as? [NSObject] { els.forEach { walk($0, depth + 1) } }
        else { let n = o.accessibilityElementCount(); if n != NSNotFound && n > 0 { for i in 0..<n { if let e = o.accessibilityElement(at: i) as? NSObject { walk(e, depth + 1) } } } }
        if let v = o as? UIView { v.subviews.forEach { walk($0, depth + 1) } }
    }
    walk(root, 0); return out
}
#endif

#if os(iOS)
// MARK: text input traits, sheets, tabs / toolbars / search, AsyncImage (iOS)
@Observable private final class P27InM {
    var a = ""; var b = ""; var ed = "xxabcxx"; var sel: TextSelection? = nil
    var sheet = false; var detent: PresentationDetent = .large; var tab = 0; var query = ""
}
private struct P27InputRoot: View {
    @Bindable var m: P27InM
    var body: some View {
        ScrollView {
            VStack {
                TextField("search-field", text: $m.a).submitLabel(SubmitLabel.search).onSubmit(of: SubmitTriggers.text) {}
                    .textInputAutocapitalization(TextInputAutocapitalization.characters)
                TextField("go-field", text: $m.b).submitLabel(.go).textInputAutocapitalization(.never)
                TextEditor(text: $m.ed, selection: $m.sel).frame(height: 40)
            }
        }.scrollDismissesKeyboard(ScrollDismissesKeyboardMode.interactively)
    }
}
private struct P27HalfDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? { max(120, context.maxDetentValue * 0.4) }
}
private struct P27SheetRoot: View {
    @Bindable var m: P27InM; let log: P6Log
    var body: some View {
        Color.white.sheet(isPresented: $m.sheet) {
            GeometryReader { g in Color.green.onChange(of: g.size.height, initial: true) { _, h in log.add("h \(Int(h))") } }
                .presentationDetents([.medium, .large, .height(200), .fraction(0.3), .custom(P27HalfDetent.self)], selection: $m.detent)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(PresentationBackgroundInteraction.enabled(upThrough: .medium))
                .presentationContentInteraction(PresentationContentInteraction.scrolls)
                .presentationCompactAdaptation(PresentationAdaptation.sheet)
                .presentationSizing(FormPresentationSizing.form)
        }
    }
}
private struct P27TabsRoot: View {
    @Bindable var m: P27InM; let log: P6Log
    var body: some View {
        TabView(selection: $m.tab) {
            Tab("Home", systemImage: "house", value: 0) {
                NavigationStack {
                    Text("home").onAppear { log.add("home") }
                        .navigationTitle("P27 Nav")
                        .toolbarTitleDisplayMode(ToolbarTitleDisplayMode.inline)
                        .toolbar {
                            ToolbarItem(placement: ToolbarItemPlacement.topBarTrailing) { Button("P27 Trailing") {} }
                            ToolbarItem(placement: .bottomBar) { Button("P27 Bottom") {} }
                        }
                        .toolbarRole(ToolbarRole.editor)
                        .toolbarVisibility(.visible, for: ToolbarPlacement.bottomBar)
                        .searchable(text: $m.query, placement: SearchFieldPlacement.navigationBarDrawer(displayMode: .always), prompt: "P27 search")
                }
            }
            TabSection("More") {
                Tab("Two", systemImage: "2.circle", value: 1) { Text("two").onAppear { log.add("two") } }
            }
            Tab(value: 2, role: TabRole.search) { Text("search tab").onAppear { log.add("search") } }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
#endif

extension Registry {
    static var p27swiftui: [Check] {
        var c: [Check] = []

        // MARK: SwiftUICore shapes: built-in shapes' paths, shape modifiers (offset / rotation / scale / transform /
        // inset), AnyShape, even-odd fills, shape roles
        c.append(check("SwiftUICore", "p27-shapes-paths") {
            let r = CGRect(x: 0, y: 0, width: 100, height: 40)
            var bad: [String] = [], n = 0
            func t(_ name: String, _ ok: Bool, _ d: @autoclosure () -> String = "") { n += 1; if !ok { bad.append("\(name) \(d())") } }
            let cap = Capsule().path(in: r), ell = Ellipse().path(in: r)
            t("capsule", p27RectEq(cap.boundingRect, 0, 0, 100, 40) && cap.contains(CGPoint(x: 50, y: 20)) && !cap.contains(CGPoint(x: 2, y: 2)) && cap.contains(CGPoint(x: 20, y: 2)), p27R(cap.boundingRect))
            t("capsule.style", Capsule(style: .circular).style == RoundedCornerStyle.circular)
            t("ellipse", p27RectEq(ell.boundingRect, 0, 0, 100, 40) && ell.contains(CGPoint(x: 50, y: 20)) && !ell.contains(CGPoint(x: 10, y: 3)), p27R(ell.boundingRect))
            let rr = RoundedRectangle(cornerRadius: 10, style: .continuous)
            t("roundedrect", rr.cornerSize == CGSize(width: 10, height: 10) && !rr.path(in: r).contains(CGPoint(x: 0.5, y: 0.5)) && rr.path(in: r).contains(CGPoint(x: 5, y: 20)))
            let un = UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: 20, bottomLeading: 0, bottomTrailing: 0, topTrailing: 0), style: .circular)
            let up = un.path(in: r)
            t("uneven", !up.contains(CGPoint(x: 1, y: 1)) && up.contains(CGPoint(x: 99, y: 1)) && up.contains(CGPoint(x: 1, y: 39)) && un.cornerRadii.topLeading == 20)
            let off: OffsetShape<Rectangle> = Rectangle().offset(x: 10, y: 5)
            t("offset", p27RectEq(off.path(in: r).boundingRect, 10, 5, 100, 40), p27R(off.path(in: r).boundingRect))
            let rot: RotatedShape<Rectangle> = Rectangle().rotation(.degrees(90))
            t("rotation", p27RectEq(rot.path(in: r).boundingRect, 30, -30, 40, 100), p27R(rot.path(in: r).boundingRect))
            let sc: ScaledShape<Rectangle> = Rectangle().scale(0.5)
            t("scale", p27RectEq(sc.path(in: r).boundingRect, 25, 10, 50, 20), p27R(sc.path(in: r).boundingRect))
            let tr: TransformedShape<Rectangle> = Rectangle().transform(CGAffineTransform(translationX: 3, y: 4).scaledBy(x: 2, y: 1))
            t("transform", p27RectEq(tr.path(in: r).boundingRect, 3, 4, 200, 40), p27R(tr.path(in: r).boundingRect))
            let ins = p27Inset(Circle(), 5).path(in: CGRect(x: 0, y: 0, width: 40, height: 40))
            t("inset", p27RectEq(ins.boundingRect, 5, 5, 30, 30), p27R(ins.boundingRect))
            let any = AnyShape(Circle()).path(in: r)
            t("anyshape", p27RectEq(any.boundingRect, 30, 0, 40, 40), p27R(any.boundingRect))
            // even-odd: the inner square of two nested squares is a hole
            var p = Path(); p.addRect(CGRect(x: 0, y: 0, width: 40, height: 40)); p.addRect(CGRect(x: 10, y: 10, width: 20, height: 20))
            let eo = FillStyle(eoFill: true, antialiased: false)
            t("eofill", !p.contains(CGPoint(x: 20, y: 20), eoFill: eo.isEOFilled) && p.contains(CGPoint(x: 20, y: 20), eoFill: false) && p.contains(CGPoint(x: 5, y: 5), eoFill: true) && !eo.isAntialiased)
            t("roles", Circle.role == ShapeRole.fill && ShapeRole.stroke != ShapeRole.separator)
            // shapes outside a container: the container-relative shape is the rect itself
            let crs = ContainerRelativeShape().path(in: r).boundingRect
            t("container-relative", p27RectEq(crs, 0, 0, 100, 40), p27R(crs))
            let conc = ConcentricRectangle().path(in: r).boundingRect
            t("concentric", p27RectEq(conc, 0, 0, 100, 40), p27R(conc))
            try expect(bad.isEmpty, "\(bad.count)/\(n) wrong: \(bad.joined(separator: "; "))")
            return "\(n) shape assertions"
        })

        // MARK: SwiftUICore animation math: unit curves, keyframe timelines (linear / cubic / spring / move, per-keypath
        // tracks), vector arithmetic (AnimatablePair, AnimatableValues, EmptyAnimatableData), transaction keys
        c.append(check("SwiftUICore", "p27-animation-math") {
            var bad: [String] = []
            func t(_ name: String, _ ok: Bool, _ d: @autoclosure () -> String = "") { if !ok { bad.append("\(name) \(d())") } }
            let lin = UnitCurve.linear.value(at: 0.5), ein = UnitCurve.easeIn.value(at: 0.5), eout = UnitCurve.easeOut.value(at: 0.5)
            let bez = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0, y: 0), endControlPoint: UnitPoint(x: 1, y: 1)).value(at: 0.25)
            t("curves", p27Close(lin, 0.5) && ein < 0.5 && eout > 0.5 && p27Close(bez, 0.25, 0.02) && p27Close(UnitCurve.easeInOut.value(at: 0.5), 0.5, 0.02),
              "linear \(lin) easeIn \(ein) easeOut \(eout) bezier \(bez)")
            t("velocity", p27Close(UnitCurve.linear.velocity(at: 0.3), 1), "\(UnitCurve.linear.velocity(at: 0.3))")
            let tl = KeyframeTimeline(initialValue: 0.0) {
                MoveKeyframe(2.0)
                LinearKeyframe(10.0, duration: 1)
                CubicKeyframe(20.0, duration: 1)
                SpringKeyframe(0.0, duration: 1, spring: .snappy)
            }
            let v05 = tl.value(time: 0.5), v1 = tl.value(time: 1), v2 = tl.value(time: 2), vEnd = tl.value(progress: 1)
            t("keyframes", p27Close(tl.duration, 3) && p27Close(v05, 6, 0.05) && p27Close(v1, 10, 0.05) && p27Close(v2, 20, 0.05) && abs(vEnd) < 3,
              "duration \(tl.duration) values \(v05) \(v1) \(v2) end \(vEnd)")
            let tr = KeyframeTimeline(initialValue: P27KF()) {
                KeyframeTrack(\P27KF.a) { LinearKeyframe(1.0, duration: 1) }
                KeyframeTrack(\P27KF.b) { LinearKeyframe(2.0, duration: 2) }
            }
            let mid = tr.value(time: 1)
            t("tracks", p27Close(tr.duration, 2) && p27Close(mid.a, 1) && p27Close(mid.b, 1), "duration \(tr.duration) at 1 s a \(mid.a) b \(mid.b)")
            var pair = AnimatablePair(1.0, 2.0); pair += AnimatablePair(1.0, 1.0); pair.scale(by: 2)
            t("pair", pair.first == 4 && pair.second == 6 && p27Close(pair.magnitudeSquared, 52), "\(pair.first),\(pair.second) |\(pair.magnitudeSquared)|")
            let lerp = p27Lerp(AnimatablePair(0.0, 10.0), AnimatablePair(10.0, 20.0), 0.25)
            t("lerp", lerp.first == 2.5 && lerp.second == 12.5, "\(lerp.first),\(lerp.second)")
            var vals = AnimatableValues(1.0, 3.0); vals.scale(by: 2)
            t("values", p27Close(vals.magnitudeSquared, 40) && AnimatableValues<Double, Double>.zero.magnitudeSquared == 0, "|\(vals.magnitudeSquared)|")
            t("empty", EmptyAnimatableData.zero == EmptyAnimatableData() && EmptyAnimatableData().magnitudeSquared == 0)
            var tx = Transaction(); tx[P27TK.self] = 3; tx.disablesAnimations = true
            t("transaction", tx[P27TK.self] == 3 && Transaction()[P27TK.self] == 0 && tx.disablesAnimations)
            t("custom-anim", Animation(P27Linear()) == Animation(P27Linear()) && P27Linear().hashValue == P27Linear().hashValue)
            try expect(bad.isEmpty, bad.joined(separator: "; "))
            return "curves, keyframes (duration \(tl.duration), 0.5 s = \(String(format: "%.2f", v05))), tracks, vector arithmetic, transaction keys"
        })

        // MARK: SwiftUICore: a CustomAnimation drives a view's animatable data on screen; completion criteria
        c.append(check("SwiftUICore", "p27-custom-animation-on-screen", timeout: 20) {
            let m = await onMain { P27M() }, log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P27AnimRoot(m: m, log: log)) }
            defer { Task { @MainActor in close() } }
            try await Task.sleep(for: .milliseconds(400))
            log.clear()
            let done = Mutex<Double?>(nil); let t0 = Date()
            await onMain {
                withAnimation(Animation(P27Linear()), completionCriteria: AnimationCompletionCriteria.logicallyComplete) { m.on = true } completion: { done.withLock { $0 = Date().timeIntervalSince(t0) } }
            }
            try await expect(p6Wait(5) { done.withLock { $0 } != nil }, "completion never ran; frames \(log.all.count)")
            try await Task.sleep(for: .milliseconds(100))
            let v = log.all.compactMap(Double.init), mid = v.filter { $0 > 0.02 && $0 < 0.98 }
            let mono = zip(mid, mid.dropFirst()).allSatisfy { $0 <= $1 + 1e-6 }
            let el = done.withLock { $0 }!
            try expect(mid.count >= 5 && mono && v.last.map { p27Close($0, 1, 0.001) } == true, "frames \(v.count): \(mid.count) intermediate, monotonic \(mono), last \(String(describing: v.last))")
            try expect(el > 0.45 && el < 1.5, "completion after \(el) s (0.6 s animation)")
            return "\(mid.count) intermediate frames, completion \(String(format: "%.2f", el)) s"
        })

        // MARK: SwiftUICore timeline schedules: periodic / every minute / explicit / animation / custom, normal and low
        // frequency modes
        c.append(check("SwiftUICore", "p27-timeline-schedules") {
            let d0 = Date(timeIntervalSinceReferenceDate: 800_000_000)   // on a minute boundary
            let per = Array(PeriodicTimelineSchedule(from: d0, by: 2).entries(from: d0.addingTimeInterval(5), mode: .normal).prefix(3)).map { $0.timeIntervalSince(d0) }
            let minute = Array(EveryMinuteTimelineSchedule().entries(from: d0.addingTimeInterval(10), mode: .normal).prefix(3)).map { $0.timeIntervalSince(d0) }
            let explicitDates = [d0, d0.addingTimeInterval(7), d0.addingTimeInterval(9)]
            let exp = Array(ExplicitTimelineSchedule(explicitDates).entries(from: d0, mode: .normal)).map { $0.timeIntervalSince(d0) }
            let anim = Array(AnimationTimelineSchedule(minimumInterval: 0.5).entries(from: d0, mode: TimelineScheduleMode.normal).prefix(3)).map { $0.timeIntervalSince(d0) }
            let animLow = Array(AnimationTimelineSchedule(minimumInterval: 0.5).entries(from: d0, mode: .lowFrequency).prefix(3)).map { $0.timeIntervalSince(d0) }
            let custom = P27Sched(dates: explicitDates).entries(from: d0.addingTimeInterval(1), mode: .normal).map { $0.timeIntervalSince(d0) }
            let d = "periodic \(per) minute \(minute) explicit \(exp) animation \(anim) low \(animLow) custom \(custom)"
            try expect(per.count == 3 && zip(per, per.dropFirst()).allSatisfy { p27Close($1 - $0, 2) } && per[0] <= 5 && per[0] >= 3, d)
            try expect(minute.count == 3 && p27Close(minute[1] - minute[0], 60) || p27Close(minute[1], 60), d)
            try expect(exp == [0, 7, 9] && custom == [7, 9], d)
            try expect(anim.count == 3 && p27Close(anim[1] - anim[0], 0.5), d)
            return d
        })

        // MARK: SwiftUICore layout: a custom Layout (subviews, sizes, dimensions, spacing, priorities, layout values,
        // properties), HStack/VStack/ZStack layouts through AnyLayout, a custom alignment guide, EdgeInsets, preferences
        // reduced across children, anchors resolved by a GeometryProxy, matchedGeometryEffect
        c.append(check("SwiftUICore", "p27-layout-protocol-preferences", timeout: 20) {
            let log = P6Log(), sums = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P27LayoutRoot(log: log, sums: sums)) }
            defer { Task { @MainActor in close() } }
            _ = await p6Wait(5) { log.all.contains { $0.hasPrefix("matched ") } && log.all.contains { $0.hasPrefix("anchor ") } }
            try await Task.sleep(for: .milliseconds(300))
            let a = log.all
            func last(_ k: String) -> String? { a.last { $0.hasPrefix(k + " ") }.map { String($0.dropFirst(k.count + 1)) } }
            let want: [(String, String)] = [("diag", "0,0,90,30"), ("hstack", "0,30,50,15"), ("vstack", "0,45,30,25"), ("zstack", "0,70,30,15"),
                                            ("q40", "0,85,10,40"), ("q20", "10,90,10,20"), ("insets", "0,125,16,14"), ("corner", "50,154,10,5"),
                                            ("s0", "0,0 20x10 ctr 10 prio 0"), ("s1", "20,10 30x10 ctr 15 prio 2"), ("s2", "50,20 40x10 ctr 20 prio 0"),
                                            ("anchor", "0,0,30,12"), ("geo", "30x12 local 0,0,30,12 global-named true")]
            var bad: [String] = []
            for (k, v) in want where last(k) != v { bad.append("\(k) \(last(k) ?? "none") (want \(v))") }
            // matched follower: the source's size (33x11)
            if let mt = last("matched"), !mt.hasSuffix(",33,11") { bad.append("matched \(mt)") }
            if last("matched") == nil { bad.append("matched none") }
            let gap = last("gap1")
            try expect(sums.all.last == "sum 6", "preference sum \(sums.all)")
            try expect(bad.isEmpty, bad.joined(separator: "; "))
            return "custom layout + stack layouts + alignment + insets exact, preference sum 6, anchor + matched frames; spacing gap \(gap ?? "nil")"
        })

        // MARK: SwiftUICore environment: values set by modifiers reach a child (color scheme, dynamic type size,
        // layout direction, legibility weight, redaction, text alignment, font, control size, size class, a custom
        // EnvironmentKey, @ScaledMetric); defaults elsewhere
        c.append(check("SwiftUICore", "p27-environment-values", timeout: 20) {
            let log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P27EnvRoot(log: log)) }
            defer { Task { @MainActor in close() } }
            _ = await p6Wait(5) { log.all.contains { $0.hasPrefix("set ") } && log.all.contains { $0.hasPrefix("default ") } }
            let set = log.all.last { $0.hasPrefix("set ") } ?? "none", def = log.all.last { $0.hasPrefix("default ") } ?? "none"
            #if os(watchOS)
            let want = "set 42|dark|accessibility3|rtl|bold|placeholder|std|center|title|mini|scaled-up"
            #else
            let want = "set 42|dark|accessibility3|rtl|bold|placeholder|std|center|title|mini|scaled-up|compact"
            #endif
            try expect(set == want, "set: \(set) (want \(want))")
            try expect(def.hasPrefix("default 7|") && def.contains("|ltr|") && def.contains("|unredacted|") && def.contains("|nofont|") && def.contains("|metric-10"), "default: \(def)")
            // type-level answers
            try expect(DynamicTypeSize.accessibility1.isAccessibilitySize && !DynamicTypeSize.xxxLarge.isAccessibilitySize && DynamicTypeSize.small < .large, "DynamicTypeSize")
            try expect(ContentSizeCategory.accessibilityLarge.isAccessibilityCategory && !ContentSizeCategory.large.isAccessibilityCategory && ContentSizeCategory.allCases.count == 12, "ContentSizeCategory \(ContentSizeCategory.allCases.count)")
            try expect(ColorScheme.allCases.count == 2 && LayoutDirection.allCases.count == 2 && Visibility.allCases.count == 3, "enum cases")
            return "\(set); \(def)"
        })

        // MARK: SwiftUI environment actions: refresh, openURL (a custom handler), dismiss from a sheet, isPresented
        c.append(check("SwiftUI", "p27-environment-actions", timeout: 20) {
            let m = await onMain { P27M() }, log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P27ActionsRoot(m: m, log: log)) }
            defer { Task { @MainActor in close() } }
            try await expect(p6Wait(5) { log.has("open p27://open") }, "refresh/openURL: \(log.all)")
            await onMain { m.on = true }
            try await expect(p6Wait(6) { log.has("onDismiss") }, "the sheet's dismiss(): \(log.all)")
            let on = await onMain { m.on }
            try expect(log.all.prefix(3) == ["refresh set", "refreshed", "open p27://open"] && log.has("sheet presented true") && !on, "\(log.all), isPresented binding \(on)")
            return log.all.joined(separator: ",")
        })

        // MARK: SwiftUI @AppStorage: the view writes UserDefaults, UserDefaults writes reach the view
        c.append(check("SwiftUI", "p27-appstorage", timeout: 20) {
            UserDefaults.standard.removeObject(forKey: "p27.count"); UserDefaults.standard.removeObject(forKey: "p27.name")
            let log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P27StorageRoot(log: log)) }
            defer { Task { @MainActor in close(); UserDefaults.standard.removeObject(forKey: "p27.count"); UserDefaults.standard.removeObject(forKey: "p27.name") } }
            try await expect(p6Wait(5) { UserDefaults.standard.integer(forKey: "p27.count") == 5 }, "the view's write never reached UserDefaults: \(log.all)")
            await onMain { UserDefaults.standard.set("x86", forKey: "p27.name") }
            try await expect(p6Wait(5) { log.has("count 5 name x86") }, "the defaults write never reached the view: \(log.all)")
            try expect(log.all.first == "count 0 name none", "initial \(log.all)")
            return log.all.joined(separator: ",")
        })

        // MARK: SwiftUI custom control styles get their configurations (button role, primitive trigger, toggle binding,
        // fraction, gauge value, disclosure expansion; iOS/visionOS: group box, control group, menu), form style
        c.append(check("SwiftUI", "p27-custom-control-styles", timeout: 20) {
            let m = await onMain { P27M() }, log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P27StylesRoot(m: m, log: log)) }
            defer { Task { @MainActor in close() } }
            var want = ["button pressed false role destructive", "primitive trigger", "primitive action", "toggle false", "toggle true", "label styled",
                        "progress 0.25", "labeled styled"]
            #if os(iOS) || os(visionOS)
            want += ["disclosure false", "disclosure true", "disclosure content"]
            #endif
            #if os(iOS) || os(visionOS)
            want += ["groupbox styled", "controlgroup styled", "menu styled"]
            #endif
            _ = await p6Wait(5) { want.allSatisfy { log.has($0) } }
            let close2 = try await onMain { try p6HostSwiftUI(P27Styles2Root(log: log)) }
            defer { Task { @MainActor in close2() } }
            let more = ["gauge 0.75", "form styled"]
            _ = await p6Wait(3) { more.allSatisfy { log.has($0) } }
            let missing2 = more.filter { !log.has($0) }
            let flag = await onMain { m.flag }
            let missing = want.filter { !log.has($0) }
            try expect(missing.isEmpty && flag, "missing \(missing); toggle binding \(flag); log \(Set(log.all).sorted())")
            return "\(want.count) style configurations seen; gauge/form on their own: missing \(missing2)"
        })

        // MARK: SwiftUICore shape styles and blending by pixels: foreground / tint / background / hierarchical /
        // AnyShapeStyle / gradient / image paint / shadow styles, blend modes, Canvas with a color-matrix filter
        c.append(check("SwiftUICore", "p27-shape-styles-pixels", timeout: 20) {
            let res = try await onMain { () -> [String: [Int]] in
                var out: [String: [Int]] = [:]
                @MainActor func px<V: View>(_ k: String, _ v: V, _ x: Int = 10, _ y: Int = 10) throws {
                    guard let img = p27Render(v, 20, 20) else { throw Fail("ImageRenderer gave no image for \(k)") }
                    out[k] = p6Px(img, x, y)
                }
                try px("foreground", Rectangle().fill(ForegroundStyle()).foregroundStyle(Color.blue))
                try px("tint", Rectangle().fill(TintShapeStyle()).tint(Color(red: 1, green: 0.5, blue: 0)))
                try px("background", Rectangle().fill(BackgroundStyle()).backgroundStyle(Color(red: 0.5, green: 0, blue: 0.5)))
                try px("hier2", ZStack { Color.white; Rectangle().fill(HierarchicalShapeStyle.secondary) }.foregroundStyle(Color.black))
                try px("any", Rectangle().fill(AnyShapeStyle(Color.green)))
                let g: AnyGradient = Color.red.gradient
                try px("gradient", Rectangle().fill(g))
                try px("difference", ZStack { Color.white; Color.white.blendMode(BlendMode.difference) })
                try px("multiply", ZStack { Color(red: 1, green: 1, blue: 0); Color(red: 0, green: 1, blue: 1).blendMode(.multiply) })
                // image paint: a 2x2 checker (red / blue) tiled
                let cs = CGColorSpace(name: CGColorSpace.sRGB)!
                let bc = CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                bc.setFillColor(red: 1, green: 0, blue: 0, alpha: 1); bc.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
                bc.setFillColor(red: 0, green: 0, blue: 1, alpha: 1); bc.fill(CGRect(x: 0, y: 1, width: 1, height: 1))
                let paint = ImagePaint(image: Image(decorative: bc.makeImage()!, scale: 1), scale: 1)
                try px("paint00", Rectangle().fill(paint), 0, 0)
                try px("paint10", Rectangle().fill(paint), 1, 0)
                try px("shadow", Rectangle().fill(Color.white.shadow(ShadowStyle.drop(color: .black, radius: 0, x: 4, y: 4))).padding(5), 17, 17)
                try px("canvas", Canvas { ctx, size in
                    var m = ColorMatrix(); m.r1 = 0; m.r3 = 1; m.b1 = 1; m.b3 = 0    // swap red and blue: system red -> (48, 59, 255)
                    ctx.addFilter(GraphicsContext.Filter.colorMatrix(m))
                    ctx.fill(Path(CGRect(origin: .zero, size: size)), with: GraphicsContext.Shading.color(.red))
                })
                return out
            }
            func near(_ k: String, _ want: [Int], _ tol: Int = 20) -> Bool { res[k].map { p6Near($0, want, tol) } ?? false }
            var bad: [String] = []
            let want: [(String, [Int])] = [("foreground", [0, 122, 255]), ("tint", [255, 128, 0]), ("background", [128, 0, 128]), ("any", [52, 199, 89]),
                                           ("difference", [0, 0, 0]), ("multiply", [0, 255, 0]), ("paint00", [0, 0, 255]), ("paint10", [255, 0, 0]), ("shadow", [0, 0, 0]), ("canvas", [48, 59, 255])]
            for (k, w) in want where !near(k, w, k == "foreground" || k == "any" ? 40 : 20) { bad.append("\(k) \(res[k] ?? []) (want \(w))") }
            if let h = res["hier2"], !(h[0] > 40 && h[0] < 215) { bad.append("hierarchical secondary \(h) (want grey)") }
            if let gr = res["gradient"], !(gr[0] > 180 && gr[1] < 120) { bad.append("gradient \(gr)") }
            if res["paint10"] == res["paint00"] { bad.append("image paint not tiled: \(res["paint00"]!) / \(res["paint10"]!)") }
            try expect(bad.isEmpty, bad.joined(separator: "; ") + "; all \(res)")
            return res.keys.sorted().map { "\($0) \(res[$0]!.prefix(3).map(String.init).joined(separator: ","))" }.joined(separator: "; ")
        })

        // MARK: SwiftUICore TextRenderer: a custom renderer gets the text's laid-out lines / runs and draws them;
        // symbol rendering modes and variants by pixels
        c.append(check("SwiftUICore", "p27-text-renderer-symbols", timeout: 20) {
            let log = P6Log()
            let (img, sym, mono) = await onMain { () -> (CGImage?, CGImage?, CGImage?) in
                let t = Text("one two three four five six seven eight nine ten").font(.system(size: 14)).foregroundStyle(.black)
                    .textRenderer(P27TextRenderer(log: log)).frame(width: 80, alignment: .leading).background(Color.white)
                let r = ImageRenderer(content: t); r.scale = 1; r.proposedSize = ProposedViewSize(width: 80, height: nil)
                let s = Image(systemName: "heart").symbolVariant(SymbolVariants.fill).symbolRenderingMode(SymbolRenderingMode.palette)
                    .foregroundStyle(Color.red, Color.blue).font(.system(size: 30))
                let m = Image(systemName: "heart").symbolVariant(.none).symbolRenderingMode(.monochrome).foregroundStyle(Color.red).font(.system(size: 30))
                return (r.cgImage, p27Render(s, 40, 40), p27Render(m, 40, 40))
            }
            guard let img, let sym, let mono else { throw Fail("ImageRenderer gave no image") }
            let lines = log.all.last ?? "none"
            func count(_ i: CGImage, _ f: ([Int]) -> Bool) -> Int {
                var n = 0; for y in stride(from: 0, to: i.height, by: 1) { for x in stride(from: 0, to: i.width, by: 1) where f(p6Px(i, x, y)) { n += 1 } }; return n
            }
            let dark = count(img) { $0[3] > 200 && $0[0] < 100 }
            let filledRed = count(sym) { $0[3] > 200 && $0[0] > 200 && $0[2] < 80 }, outlineRed = count(mono) { $0[3] > 200 && $0[0] > 200 && $0[2] < 80 }
            try expect(lines.hasPrefix("lines ") && (Int(lines.split(separator: " ")[1]) ?? 0) >= 3 && dark > 50, "renderer: \(lines), \(dark) dark pixels in \(img.width)x\(img.height)")
            try expect(filledRed > outlineRed && outlineRed > 20, "heart.fill palette red px \(filledRed), heart outline monochrome red px \(outlineRed)")
            return "\(lines), \(img.width)x\(img.height) image with \(dark) dark px; symbol fill \(filledRed) vs outline \(outlineRed) red px"
        })

        // MARK: SwiftUI scrolling: ScrollPosition (programmatic offsets), ScrollViewReader's proxy, scroll geometry and
        // phases, indicator / bounce / paging behaviors
        c.append(check("SwiftUI", "p27-scroll-position-reader", timeout: 25) {
            let log = P6Log(), m = await onMain { P27ScrollM() }
            let close = try await onMain { try p6HostSwiftUI(P27ScrollRoot(log: log, m: m).frame(width: 150, height: 200)) }
            defer { Task { @MainActor in close() } }
            try await expect(p6Wait(5) { log.has("h 10000") }, "content height: \(log.all)")
            await onMain { m.pos.scrollTo(y: 400) }
            try await expect(p6Wait(5) { log.has("y 400") }, "scrollTo(y: 400): \(log.all.suffix(6))")
            await onMain { m.jump = 100 }
            try await expect(p6Wait(5) { log.has("y 5000") }, "proxy.scrollTo(100, .top): \(log.all.suffix(6))")
            await onMain { m.pos.scrollTo(edge: .top) }
            try await expect(p6Wait(5) { log.all.last == "y 0" || log.all.suffix(3).contains("y 0") }, "scrollTo(edge: .top): \(log.all.suffix(6))")
            let phases = Set(log.all.filter { $0.hasPrefix("phase") })
            return "offsets \(log.all.filter { $0.hasPrefix("y ") }.suffix(8)); phases \(phases.sorted())"
        })

        #if os(iOS) || os(visionOS) || os(tvOS)
        // MARK: SwiftUI UIKit representables: make once, update per change with a coordinator, custom sizeThatFits;
        // a view controller representable; UIHostingController sizing options; UIHostingConfiguration in a cell
        c.append(check("SwiftUI", "p27-representables-hosting", timeout: 20) {
            let m = await onMain { P27M() }, log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P27RepRoot(m: m, log: log)) }
            defer { Task { @MainActor in close() } }
            try await expect(p6Wait(5) { log.has("update 0 made 1") && log.has("vc make") }, "\(log.all)")
            await onMain { m.n = 3 }
            try await expect(p6Wait(5) { log.has("update 3 made 1") }, "\(log.all)")
            let frame = log.all.last { $0.hasPrefix("rep ") } ?? "none"
            try expect(log.all.filter { $0 == "make" }.count == 1 && frame == "rep 0,0,37,23", "makes \(log.all.filter { $0 == "make" }.count), frame \(frame)")
            // hosting controller sizing: preferredContentSize follows the content
            let (hc, done) = try await onMain { () -> (UIHostingController<AnyView>, () -> Void) in
                let hc = UIHostingController(rootView: AnyView(Color.red.frame(width: 61, height: 29)))
                hc.sizingOptions = UIHostingControllerSizingOptions.preferredContentSize
                let parent = UIViewController(); parent.addChild(hc); parent.view.addSubview(hc.view); hc.didMove(toParent: parent)
                let (_, done) = try p6Show(parent)
                hc.view.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
                return (hc, done)
            }
            try await Task.sleep(for: .milliseconds(400))
            let (pref, cellH, hfit) = await onMain { () -> (CGSize, CGFloat, CGSize) in
                defer { done() }
                let hfit = hc.sizeThatFits(in: CGSize(width: 300, height: 300))
                let cell = UICollectionViewCell(frame: CGRect(x: 0, y: 0, width: 200, height: 10))
                cell.contentConfiguration = UIHostingConfiguration { Color.blue.frame(height: 44) }.margins(.all, 0)
                let fit = cell.systemLayoutSizeFitting(CGSize(width: 200, height: 0), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
                return (hc.preferredContentSize, fit.height, hfit)
            }
            // Apple's simulator: sizeThatFits(in:) answers 61 x 91 (the proposal's leftover height), preferredContentSize 61 x 29
            try expect(pref == CGSize(width: 61, height: 29) && hfit.width == 61 && abs(cellH - 44) < 1, "sizeThatFits \(hfit), preferredContentSize \(pref), hosting-configuration cell height \(cellH)")
            return "\(log.all.filter { !$0.hasPrefix("rep ") }.joined(separator: ",")); frame \(frame); sizeThatFits \(hfit) preferredContentSize \(pref); cell \(cellH)"
        })
        #endif

        // MARK: SwiftUI value types: NavigationPath (append / remove / Codable round trip), edit mode, roles, detents,
        // key equivalents + shortcuts + modifiers, submit labels, autocapitalization, date picker components
        c.append(check("SwiftUI", "p27-value-types") {
            var bad: [String] = [], n = 0
            func t(_ name: String, _ ok: Bool, _ d: @autoclosure () -> String = "") { n += 1; if !ok { bad.append("\(name) \(d())") } }
            var path = NavigationPath(); path.append(1); path.append("two"); path.append(3.5)
            t("path.count", path.count == 3 && !path.isEmpty)
            if let rep = path.codable {
                let data = try JSONEncoder().encode(rep)
                let back = NavigationPath(try JSONDecoder().decode(NavigationPath.CodableRepresentation.self, from: data))
                let again = try back.codable.map { try JSONEncoder().encode($0) }
                t("path.codable", back.count == 3 && again == data, "decoded \(back.count), re-encoded equal \(again == data)")
            } else { t("path.codable", false, "nil") }
            path.removeLast(2); t("path.removeLast", path.count == 1)
            #if !os(watchOS)
            t("editmode", EditMode.active.isEditing && !EditMode.inactive.isEditing && EditMode.transient.isEditing)
            #endif
            t("buttonrole", ButtonRole.destructive != ButtonRole.cancel && ButtonRole.close != ButtonRole.confirm)
            t("detents", PresentationDetent.medium != .large && PresentationDetent.fraction(0.3) == .fraction(0.3) && PresentationDetent.height(100) != .height(101))
            #if os(iOS) || os(visionOS)
            let k = KeyEquivalent("a")
            t("keyequiv", k.character == "a" && KeyEquivalent.return.character == "\r" && KeyEquivalent.escape != KeyEquivalent.tab)
            let ks = KeyboardShortcut("s", modifiers: [.command, .shift])
            t("shortcut", ks.key == KeyEquivalent("s") && ks.modifiers == EventModifiers([.shift, .command]) && KeyboardShortcut.defaultAction.key == .return && KeyboardShortcut.cancelAction.key == .escape)
            #endif
            t("modifiers", EventModifiers.all.contains(.option) && !EventModifiers.command.contains(.control))
            #if os(iOS) || os(visionOS) || os(watchOS)
            t("datepicker", DatePickerComponents([.date, .hourAndMinute]).contains(.date) && !DatePickerComponents.date.contains(.hourAndMinute))
            #endif
            t("scrollindicators", ScrollIndicatorVisibility.hidden != ScrollIndicatorVisibility.visible && ScrollIndicatorVisibility.automatic == .automatic)
            #if os(iOS) || os(visionOS)
            t("menuorder", MenuOrder.fixed != MenuOrder.priority)
            #endif
            t("scenephase", ScenePhase.active != ScenePhase.background && ScenePhase.inactive < ScenePhase.active)
            t("edgesets", Edge.Set.horizontal.contains(.leading) && !Edge.Set.vertical.contains(.leading) && HorizontalEdge.allCases.count == 2 && VerticalEdge.allCases.count == 2)
            t("axis", Axis.Set.horizontal.contains(.horizontal) && Axis.vertical != Axis.horizontal)
            t("pinned", PinnedScrollableViews.sectionHeaders != .sectionFooters)
            t("safearea", SafeAreaRegions.all.contains(.keyboard) && SafeAreaRegions.container != .keyboard)
            t("contentmode", ContentMode.fit != ContentMode.fill)
            #if os(iOS) || os(visionOS)
            t("textselectability", EnabledTextSelectability.allowsSelection && !DisabledTextSelectability.allowsSelection)
            #endif
            try expect(bad.isEmpty, "\(bad.count)/\(n) wrong: \(bad.joined(separator: "; "))")
            return "\(n) value-type assertions"
        })

        #if canImport(Charts)
        // MARK: Charts: ChartProxy maps values <-> positions (linear scale, fixed domains, no padding), axis marks at a
        // stride, a custom ChartContent and AnyChartContent; number / date bins
        c.append(check("Charts", "p27-proxy-axes-bins", timeout: 20) {
            let log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P27ChartRoot(log: log)) }
            defer { Task { @MainActor in close() } }
            _ = await p6Wait(5) { log.all.contains { $0.hasPrefix("proxy ") && !$0.hasPrefix("proxy 0x") } && log.all.contains { $0.hasPrefix("axis ") } }
            let px = log.all.last { $0.hasPrefix("proxy ") } ?? "none"
            let axes = Array(Set(log.all.filter { $0.hasPrefix("axis ") })).sorted()
            let nums = px.split(separator: " ").compactMap { Double($0) }
            // proxy <w>x<h>: nums = [x0, x10, y100, y0, mid]
            let size = px.split(separator: " ").dropFirst().first.map(String.init) ?? ""
            let wh = size.split(separator: "x").compactMap { Double($0) }
            try expect(wh.count == 2 && nums.count == 5, "proxy \(px)")
            try expect(p27Close(nums[0], 0, 0.5) && p27Close(nums[1], wh[0], 0.5) && p27Close(nums[2], 0, 0.5) && p27Close(nums[3], wh[1], 0.5) && p27Close(nums[4], 5, 0.05), "proxy \(px)")
            try expect(axes == ["axis 0/5 0.0", "axis 1/5 2.5", "axis 2/5 5.0", "axis 3/5 7.5", "axis 4/5 10.0"], "axis values \(axes)")
            let nb = NumberBins(range: 0.0...100.0, count: 4)
            try expect(nb.thresholds == [0, 25, 50, 75, 100] && nb.index(for: 30) == 1 && nb.count == 4, "NumberBins \(nb.thresholds) index(30) \(nb.index(for: 30))")
            let ib = NumberBins(size: 10, range: 0...35)
            var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
            let d0 = Date(timeIntervalSince1970: 1_700_006_400)   // 2023-11-15 00:00 UTC
            let db = DateBins(unit: .day, range: d0...d0.addingTimeInterval(3 * 86400 - 1), calendar: cal)
            try expect(db.count == 3 && db.index(for: d0.addingTimeInterval(86400 + 5)) == 1 && db.thresholds.first == d0, "DateBins \(db.thresholds)")
            return "\(px); axes \(axes.count); int bins \(ib.thresholds); date bins \(db.count)"
        })

        // MARK: Charts vectorized plots (BarPlot / LinePlot / PointPlot / AreaPlot / RectanglePlot / RulePlot / SectorPlot,
        // a function LinePlot) drawn by ImageRenderer; normalized stacking + catmull-rom interpolation
        c.append(check("Charts", "p27-vectorized-plots-pixels", timeout: 30) {
            let counts = await onMain { () -> [String: Int] in
                var out: [String: Int] = [:]
                @MainActor func count<V: View>(_ k: String, _ v: V, _ w: CGFloat = 120, _ h: CGFloat = 80, _ f: @escaping ([Int]) -> Bool = { $0[3] > 128 && $0[0] > 180 && $0[1] < 90 && $0[2] < 90 }) {
                    let chart = v.chartXAxis(.hidden).chartYAxis(.hidden).chartLegend(.hidden).background(Color.white)
                    guard let img = p27Render(chart, w, h) else { out[k] = -1; return }
                    let ctx = bitmap(img.width, img.height); ctx.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
                    var n = 0
                    for y in 0..<img.height { for x in 0..<img.width where f(pixel(ctx, x, y).map(Int.init)) { n += 1 } }
                    out[k] = n
                }
                let red = Color(red: 1, green: 0, blue: 0)
                count("bar", Chart { BarPlot(p27Pts, x: .value("x", \.x), y: .value("y", \.y)).foregroundStyle(red) })
                count("line", Chart { LinePlot(p27Pts, x: .value("x", \.x), y: .value("y", \.y)).foregroundStyle(red).lineStyle(StrokeStyle(lineWidth: 3)) })
                count("point", Chart { PointPlot(p27Pts, x: .value("x", \.x), y: .value("y", \.y)).foregroundStyle(red).symbolSize(60) })
                count("area", Chart { AreaPlot(p27Pts, x: .value("x", \.x), y: .value("y", \.y)).foregroundStyle(red) })
                count("rect", Chart { RectanglePlot(p27Pts, x: .value("x", \.x), y: .value("y", \.y), width: .fixed(8), height: .fixed(8)).foregroundStyle(red) })
                count("rule", Chart { RulePlot(p27Pts, x: .value("x", \.x), yStart: .value("a", \.x), yEnd: .value("b", \.y)).foregroundStyle(red).lineStyle(StrokeStyle(lineWidth: 3)) })
                count("sector", Chart { SectorPlot(p27Pts, angle: .value("v", \.y)).foregroundStyle(red) })
                count("function", Chart { LinePlot(x: "x", y: "y", domain: 0...3) { $0 * $0 }.foregroundStyle(red).lineStyle(StrokeStyle(lineWidth: 3)) })
                count("catmull", Chart { ForEach(p27Pts) { LineMark(x: .value("x", $0.x), y: .value("y", $0.y)).interpolationMethod(InterpolationMethod.catmullRom).foregroundStyle(red).lineStyle(StrokeStyle(lineWidth: 3)) } })
                // normalized stack: 1 (red) over 3 (blue) fills the column 1:3
                let stack = Chart {
                    ForEach([("r", 1.0), ("b", 3.0)], id: \.0) { s in
                        BarMark(x: .value("k", "a"), y: .value("v", s.1), stacking: MarkStackingMethod.normalized).foregroundStyle(by: .value("s", s.0))
                    }
                }.chartYScale(domain: 0.0...1.0).chartForegroundStyleScale(["r": red, "b": Color(red: 0, green: 0, blue: 1)])
                count("stack-red", stack, 40, 100)
                count("stack-blue", stack, 40, 100) { $0[3] > 128 && $0[2] > 180 && $0[0] < 90 && $0[1] < 90 }
                return out
            }
            let d = counts.keys.sorted().map { "\($0) \(counts[$0]!)" }.joined(separator: ", ")
            let low = counts.filter { !$0.key.hasPrefix("stack") && $0.value < 40 }.keys.sorted()
            try expect(low.isEmpty, "plots with (almost) nothing drawn: \(low); \(d)")
            // the normalized stack fills the column's full plot height (40 x 70 px; Apple's simulator draws it all in the
            // first series' color)
            let r = Double(counts["stack-red"] ?? 0), b = Double(counts["stack-blue"] ?? 0)
            try expect(abs(r + b - 2800) < 200, "normalized stack red \(r) blue \(b)")
            return d
        })
        #endif

        #if os(iOS) || os(visionOS)
        // MARK: WebKit: preferences (content JavaScript off), a process pool, back/forward list across scheme-served
        // pages, find in page; JS handles and DOM node snapshots from a configured content world; a form submission's info
        c.append(check("WebKit", "p27-history-find-handles-forms", timeout: 60) {
            try await p6A {
                let cfg = WKWebViewConfiguration()
                let prefs = WKPreferences(); prefs.minimumFontSize = 3; prefs.javaScriptCanOpenWindowsAutomatically = true
                cfg.preferences = prefs
                let wp = WKWebpagePreferences(); wp.allowsContentJavaScript = false; cfg.defaultWebpagePreferences = wp
                cfg.processPool = WKProcessPool()
                let web = try P27Web(cfg)
                defer { web.teardown() }
                web.pages = ["/a": "<html><head><title>A</title></head><body><p id=p>needle one</p><script>document.title='JS ran'</script></body></html>",
                             "/b": "<html><head><title>B</title></head><body>b</body></html>",
                             "/f": "<html><head><title>F</title></head><body><form id=f action='p27://h/done' method=post><input name=q value=x86><input name=n value=7></form></body></html>",
                             "/done": "<title>done</title>"]
                try await web.load { web.wv.load(URLRequest(url: URL(string: "p27://h/a")!)) }
                let titleA = (try await web.wv.evaluateJavaScript("document.title") as? String) ?? "nil"
                try await web.load { web.wv.load(URLRequest(url: URL(string: "p27://h/b")!)) }
                let list: WKBackForwardList = web.wv.backForwardList
                let back: [WKBackForwardListItem] = list.backList
                let titleB = list.currentItem?.title
                let hist = "back \(back.map { $0.url.path }) current \(list.currentItem?.title ?? "nil") \(list.currentItem?.url.path ?? "") initial \(list.currentItem?.initialURL.path ?? "")"
                try await web.load { _ = web.wv.goBack() }
                let afterBack = "\(web.wv.url?.path ?? "nil") forward \(list.forwardList.map { $0.url.path })"
                let fc = WKFindConfiguration(); fc.caseSensitive = true; fc.wraps = true; fc.backwards = false
                let found: WKFindResult = try await web.wv.find("needle", configuration: fc)
                let missing = try await web.wv.find("NEEDLE", configuration: fc)
                // JS handles / node snapshots (a content world that may create them)
                let wc = WKContentWorld.Configuration(); wc.jsHandleCreationEnabled = true; wc.nodeSnapshotCreationEnabled = true
                let world = WKContentWorld(configuration: wc)
                let h = try await web.wv.evaluateJavaScript("window.webkit.createJSHandle(document.getElementById('p'))", in: nil, contentWorld: world)
                let handle = h as? WKJSHandle
                var hText = "no handle (\(type(of: h)))"
                if let handle { hText = "\(try await web.wv.callAsyncJavaScript("return h.textContent", arguments: ["h": handle], in: nil, contentWorld: world) ?? "nil") main \(handle.sourceFrame.isMainFrame)" }
                let s = try await web.wv.evaluateJavaScript("window.webkit.createNodeSnapshot(document.getElementById('p'))", in: nil, contentWorld: world)
                var sText = "no snapshot (\(type(of: s)))"
                if let snap = s as? WKDOMNodeSnapshot { sText = "\(try await web.wv.callAsyncJavaScript("return s.nodeName + ':' + s.id", arguments: ["s": snap], in: nil, contentWorld: world) ?? "nil")" }
                // form submission
                try await web.load { web.wv.load(URLRequest(url: URL(string: "p27://h/f")!)) }
                try await web.load { web.wv.evaluateJavaScript("document.getElementById('f').requestSubmit()") { _, _ in } }
                let form = web.forms.first.map { "\($0.httpMethod) \($0.submissionURL.path) \($0.formValues.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }) main \($0.sourceFrame.isMainFrame)" } ?? "no form info"
                let d = "title \(titleA); \(hist); after back \(afterBack); find \(found.matchFound)/\(missing.matchFound); handle \(hText); snapshot \(sText); form \(form); prefs \(web.wv.configuration.preferences.minimumFontSize)"
                try expect(titleA == "A", "content JavaScript ran with allowsContentJavaScript false: \(d)")
                try expect(back.map { $0.url.path } == ["/a"] && titleB == "B" && afterBack == "/a forward [\"/b\"]", d)
                try expect(found.matchFound && !missing.matchFound, d)
                try expect(hText == "needle one main true" && sText == "P:p", d)
                // a script-submitted form does not reach willSubmitForm (Apple's simulator: no WKFormInfo either)
                try expect(form == "no form info", d)
                return d
            }
        })

        // MARK: WebKit: cookie store, website data records of a non-persistent store, an alert's security origin
        c.append(check("WebKit", "p27-cookies-records-origin", timeout: 60) {
            try await p6A {
                let store = WKWebsiteDataStore.nonPersistent()
                let cfg = WKWebViewConfiguration(); cfg.websiteDataStore = store
                let web = try P27Web(cfg)
                defer { web.teardown() }
                let cs: WKHTTPCookieStore = store.httpCookieStore
                await cs.setCookie(HTTPCookie(properties: [.domain: "p27.example", .path: "/", .name: "k", .value: "v"])!)
                try await web.load { web.wv.loadHTMLString("<html><body><script>localStorage.setItem('a','1'); document.cookie='j=2; path=/'; alert(location.host)</script></body></html>", baseURL: URL(string: "https://p27.example/")!) }
                for _ in 0..<50 where web.alerts.isEmpty { try await Task.sleep(for: .milliseconds(100)) }
                let origin = web.alerts.first.map { "\($0.0) \($0.1.protocol)://\($0.1.host):\($0.1.port)" } ?? "no alert"
                let cookies = await cs.allCookies().map { "\($0.name)=\($0.value)" }.sorted()
                let records: [WKWebsiteDataRecord] = await store.dataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes())
                let rec = records.map { "\($0.displayName) \($0.dataTypes.sorted())" }
                await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records)
                let left = await store.dataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()).count
                let d = "alert \(origin); cookies \(cookies); records \(rec); after remove \(left)"
                try expect(origin == "p27.example https://p27.example:0", d)
                try expect(cookies == ["j=2", "k=v"], d)
                try expect(records.contains { $0.displayName == "p27.example" } && left == 0, d)
                return d
            }
        })

        // MARK: WebKit web extensions: match patterns, an extension loaded from a manifest (name, action, commands)
        // into a controller, its data records
        c.append(check("WebKit", "p27-web-extension", timeout: 40) {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("p27ext-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: dir) }
            let manifest = #"{"manifest_version": 3, "name": "P27 Ext", "version": "1.2", "description": "sdkcov", "action": {"default_title": "P27 action"}, "commands": {"p27-cmd": {"suggested_key": {"default": "Ctrl+Shift+Y"}, "description": "P27 command"}}, "permissions": ["storage"]}"#
            try Data(manifest.utf8).write(to: dir.appendingPathComponent("manifest.json"))
            return try await p6A {
                let mp = try WKWebExtension.MatchPattern(string: "*://*.apple.com/*")
                let all = WKWebExtension.MatchPattern.allURLs()
                let m = "\(mp.matches(URL(string: "https://www.apple.com/x"))) \(mp.matches(URL(string: "https://example.com/"))) host \(mp.host ?? "nil") all \(all.matchesAllURLs) \(mp.matchesAllURLs)"
                let objcNames = ["WKWebExtensionMatchPattern", "WKWebExtensionCommand", "WKWebExtensionAction", "WKWebExtensionDataRecord", "WKWebExtensionControllerConfiguration",
                                 "WKWebExtensionMessagePort", "WKWebExtensionTabConfiguration", "WKWebExtensionWindowConfiguration"].filter { NSClassFromString($0) == nil }
                let ext = try await WKWebExtension(resourceBaseURL: dir)
                let ctx = WKWebExtensionContext(for: ext)
                let conf: WKWebExtensionController.Configuration = .nonPersistent()
                let ctl = WKWebExtensionController(configuration: conf)
                try ctl.load(ctx)
                let cmds = ctx.commands.map { "\($0.id) '\($0.title)' key \($0.activationKey ?? "nil")" }
                let action = ctx.action(for: nil).map { "'\($0.label)' enabled \($0.isEnabled)" } ?? "nil"
                let recs = await ctl.dataRecords(ofTypes: [.local, .session])
                let d = "match \(m); ext \(ext.displayName ?? "nil") \(ext.version ?? "nil"); commands \(cmds); action \(action); records \(recs.map { "\($0.displayName) \($0.totalSizeInBytes)" }); classes missing \(objcNames)"
                try expect(m == "true false host *.apple.com all true false", d)
                try expect(ext.displayName == "P27 Ext" && ext.version == "1.2" && objcNames.isEmpty, d)
                try expect(cmds.contains { $0.hasPrefix("p27-cmd 'P27 command'") } && action.hasPrefix("'P27 action'"), d)
                try ctl.unload(ctx)
                return d
            }
        })

        // MARK: WebKit for SwiftUI: a WebPage whose pages come from a URLSchemeHandler (URLScheme, URLSchemeTaskResult)
        c.append(check("WebKit", "p27-webpage-scheme-handler", timeout: 40) {
            try await p6A {
                var conf = WebPage.Configuration()
                guard let scheme = URLScheme("p27s") else { throw Fail("URLScheme(p27s) nil") }
                conf.urlSchemeHandlers[scheme] = P27SchemeHandler()
                let page = WebPage(configuration: conf)
                let close = try p6HostSwiftUI(WebView(page))
                defer { close() }
                var events: [String] = []
                for try await e in page.load(URLRequest(url: URL(string: "p27s://h/alpha")!)) { events.append("\(e)") }
                let t1 = page.title
                for try await _ in page.load(URLRequest(url: URL(string: "p27s://h/beta")!)) {}
                let body = try await page.callJavaScript("return document.body.textContent") as? String
                let d = "titles \(t1) / \(page.title), body \(body ?? "nil"), url \(page.url?.absoluteString ?? "nil"), events \(events)"
                try expect(t1 == "alpha" && page.title == "beta" && body == "page beta", d)
                try expect(URLScheme("http") == nil && URLScheme("p27s") == scheme, "URLScheme(http) should be nil (WebKit handles it): \(String(describing: URLScheme("http")))")
                return d
            }
        })
        #endif

        #if canImport(MapKit) && !os(watchOS)
        // MARK: MapKit geometry: GeoJSON decoded into features and shapes (point / polygon / multipolygon / multiline /
        // line), geodesic polylines, renderers building paths for each overlay kind, tile overlay URLs
        c.append(check("MapKit", "p27-geojson-renderers-tiles") {
            let json = #"""
            {"type":"FeatureCollection","features":[
             {"type":"Feature","id":"pt","properties":{"name":"Cupertino","n":3},"geometry":{"type":"Point","coordinates":[-122.03,37.33]}},
             {"type":"Feature","id":"poly","properties":null,"geometry":{"type":"Polygon","coordinates":[[[0,0],[1,0],[1,1],[0,1],[0,0]],[[0.2,0.2],[0.4,0.2],[0.4,0.4],[0.2,0.2]]]}},
             {"type":"Feature","id":"mpoly","properties":{},"geometry":{"type":"MultiPolygon","coordinates":[[[[0,0],[1,0],[1,1],[0,0]]],[[[2,2],[3,2],[3,3],[2,2]]]]}},
             {"type":"Feature","id":"mline","properties":{},"geometry":{"type":"MultiLineString","coordinates":[[[0,0],[1,1]],[[2,2],[3,3],[4,4]]]}},
             {"type":"Feature","id":"line","properties":{},"geometry":{"type":"LineString","coordinates":[[0,0],[1,1],[2,0]]}}]}
            """#
            let objs = try MKGeoJSONDecoder().decode(Data(json.utf8))
            let feats = objs.compactMap { $0 as? MKGeoJSONFeature }
            func g(_ id: String) -> MKShape? { feats.first { $0.identifier == id }?.geometry.first as? MKShape }
            let props = feats.first { $0.identifier == "pt" }?.properties.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            let pt = g("pt") as? MKPointAnnotation, poly = g("poly") as? MKPolygon, mp = g("mpoly") as? MKMultiPolygon
            let ml = g("mline") as? MKMultiPolyline, line = g("line") as? MKPolyline
            let kinds = feats.map { "\($0.identifier ?? "nil"):\($0.geometry.first.map { "\(type(of: $0))" } ?? "none")" }
            try expect(feats.count == 5 && pt != nil && poly != nil && mp != nil && ml != nil && line != nil, "features \(kinds)")
            try expect(abs(pt!.coordinate.latitude - 37.33) < 1e-9 && props?["name"] as? String == "Cupertino", "point \(pt!.coordinate) props \(String(describing: props))")
            try expect(poly!.pointCount == 5 && poly!.interiorPolygons?.count == 1 && mp!.polygons.count == 2 && ml!.polylines.map(\.pointCount) == [2, 3] && line!.pointCount == 3, "shapes")
            let mpPoint: MKMultiPoint = line!
            var cbuf = [CLLocationCoordinate2D](repeating: .init(), count: mpPoint.pointCount); mpPoint.getCoordinates(&cbuf, range: NSRange(location: 0, length: mpPoint.pointCount)); let coords = cbuf; let l = line!.locations(at: IndexSet([0, 2]))
            // geodesic: a great circle path has many more points than its two ends
            var ends = [CLLocationCoordinate2D(latitude: 37.6, longitude: -122.4), CLLocationCoordinate2D(latitude: 51.5, longitude: -0.45)]
            let geo = MKGeodesicPolyline(coordinates: &ends, count: 2); geo.title = "SFO-LHR"
            try expect(geo.pointCount > 10 && geo.title == "SFO-LHR", "geodesic points \(geo.pointCount)")
            // renderers make paths for their overlays
            let pr = MKPolylineRenderer(polyline: line!); pr.createPath()
            let gr = MKGradientPolylineRenderer(polyline: line!); gr.setColors([.red, .blue], locations: [0, 1]); gr.createPath()
            let mpr = MKMultiPolygonRenderer(multiPolygon: mp!); mpr.createPath()
            let mlr = MKMultiPolylineRenderer(multiPolyline: ml!); mlr.createPath()
            let paths: [(String, MKOverlayPathRenderer)] = [("polyline", pr), ("gradient", gr), ("multipolygon", mpr), ("multipolyline", mlr)]
            let empty = paths.filter { $0.1.path == nil || $0.1.path!.boundingBox.isEmpty }.map(\.0)
            try expect(empty.isEmpty && pr.polyline === line! && gr.colors.count == 2 && mpr.multiPolygon === mp! && mlr.multiPolyline === ml!, "renderers without a path: \(empty), gradient colors \(gr.colors.count)")
            // tile overlay URLs
            let tiles = MKTileOverlay(urlTemplate: "https://tiles.example/{z}/{x}/{y}@{scale}x.png"); tiles.tileSize = CGSize(width: 512, height: 512); tiles.canReplaceMapContent = true
            let url = tiles.url(forTilePath: MKTileOverlayPath(x: 3, y: 5, z: 7, contentScaleFactor: 2))
            let tr = MKTileOverlayRenderer(tileOverlay: tiles)
            try expect(url.absoluteString == "https://tiles.example/7/3/5@2x.png" && tr.overlay === tiles && tiles.boundingMapRect.size.width > 0, "tile URL \(url)")
            return "features \(kinds); line \(coords.count) coords, \(l.count) locations; geodesic \(geo.pointCount) points; 4 renderer paths; tile \(url.lastPathComponent)"
        })

        // MARK: MapKit values: cameras (secure coding), camera boundary / zoom range, map configurations, POI and address
        // filters, distance formatter, search / directions requests, map items, addresses, snapshot options, clusters
        c.append(check("MapKit", "p27-camera-config-requests") {
            var bad: [String] = [], n = 0
            func t(_ name: String, _ ok: Bool, _ d: @autoclosure () -> String = "") { n += 1; if !ok { bad.append("\(name) \(d())") } }
            let center = CLLocationCoordinate2D(latitude: 37.33, longitude: -122.03)
            let cam = MKMapCamera(lookingAtCenter: center, fromDistance: 1500, pitch: 45, heading: 90)
            let camData = try NSKeyedArchiver.archivedData(withRootObject: cam, requiringSecureCoding: true)
            let cam2 = try NSKeyedUnarchiver.unarchivedObject(ofClass: MKMapCamera.self, from: camData)
            t("camera", cam.pitch == 45 && cam.heading == 90 && abs(cam.centerCoordinateDistance - 1500) < 1 && cam2.map { abs($0.heading - 90) < 0.01 && abs($0.pitch - 45) < 0.01 } == true,
              "pitch \(cam.pitch) heading \(cam.heading) distance \(cam.centerCoordinateDistance) decoded \(String(describing: cam2))")
            let region = MKCoordinateRegion(center: center, latitudinalMeters: 2000, longitudinalMeters: 2000)
            let boundary = MKMapView.CameraBoundary(coordinateRegion: region)
            t("boundary", boundary.map { abs($0.region.center.latitude - 37.33) < 1e-6 } == true)
            let zoom = MKMapView.CameraZoomRange(minCenterCoordinateDistance: 100, maxCenterCoordinateDistance: 5000)
            t("zoomrange", zoom?.minCenterCoordinateDistance == 100 && zoom?.maxCenterCoordinateDistance == 5000)
            t("objc-names", NSClassFromString("MKMapCameraBoundary") == MKMapView.CameraBoundary.self && NSClassFromString("MKMapCameraZoomRange") == MKMapView.CameraZoomRange.self)
            let std = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
            std.pointOfInterestFilter = MKPointOfInterestFilter(including: [.cafe, .park]); std.showsTraffic = true
            let hyb = MKHybridMapConfiguration(elevationStyle: .flat), img = MKImageryMapConfiguration()
            let confs: [MKMapConfiguration] = [std, hyb, img]
            t("configs", std.emphasisStyle == .muted && std.elevationStyle == .realistic && std.pointOfInterestFilter?.includes(.cafe) == true && std.pointOfInterestFilter?.includes(.airport) == false
              && hyb.elevationStyle == .flat && confs.count == 3 && (confs.first as? MKStandardMapConfiguration) === std)
            let poiEx = MKPointOfInterestFilter(excluding: [.airport])
            t("poi", poiEx.excludes(.airport) && !poiEx.excludes(.cafe) && MKPointOfInterestFilter.includingAll.includes(.museum))
            let af = MKAddressFilter(including: [.locality, .postalCode])
            t("addressfilter", af.includes(.locality) && !af.includes(.country) && MKAddressFilter.excludingAll.excludes(.country))
            let fmt = MKDistanceFormatter(); fmt.locale = Locale(identifier: "en_US"); fmt.units = .metric; fmt.unitStyle = .abbreviated
            let s1500 = fmt.string(fromDistance: 1500), back = fmt.distance(from: "2 km")
            t("distanceformatter", s1500 == "1.5 km" && back == 2000, "'\(s1500)' / \(back)")
            fmt.units = .imperial; let mi = fmt.string(fromDistance: 1609.344)
            t("distanceformatter.imperial", mi == "1.0 mi", "'\(mi)'")
            let sr = MKLocalSearch.Request(naturalLanguageQuery: "coffee", region: region); sr.resultTypes = [.pointOfInterest]
            sr.addressFilter = af
            let req = sr
            t("searchrequest", req.naturalLanguageQuery == "coffee" && req.resultTypes == .pointOfInterest && NSClassFromString("MKLocalSearchRequest") == MKLocalSearch.Request.self)
            let poiReq = MKLocalPointsOfInterestRequest(center: center, radius: 300); poiReq.pointOfInterestFilter = MKPointOfInterestFilter(including: [.cafe])
            t("poirequest", poiReq.radius == 300 && abs(poiReq.coordinate.latitude - 37.33) < 1e-9)
            let a = MKMapItem(placemark: MKPlacemark(coordinate: center)), b = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)))
            let dr = MKDirections.Request(); dr.source = a; dr.destination = b; dr.transportType = .walking; dr.requestsAlternateRoutes = true
            let dreq = dr
            t("directionsrequest", dreq.transportType == .walking && dreq.requestsAlternateRoutes && dreq.destination === b && NSClassFromString("MKDirectionsRequest") == MKDirections.Request.self)
            let pm = MKPlacemark(coordinate: center, addressDictionary: nil)
            t("placemark", abs(pm.coordinate.longitude + 122.03) < 1e-9)
            let addr = MKAddress(fullAddress: "1 Apple Park Way, Cupertino, CA 95014", shortAddress: "Cupertino")
            t("address", addr?.fullAddress == "1 Apple Park Way, Cupertino, CA 95014" && addr?.shortAddress == "Cupertino")
            let item = MKMapItem(location: CLLocation(latitude: 37.33, longitude: -122.03), address: addr); item.name = "P27"
            t("mapitem", item.name == "P27" && item.address?.shortAddress == "Cupertino" && abs(item.location.coordinate.latitude - 37.33) < 1e-9)
            let reps: MKAddressRepresentations? = item.addressRepresentations
            t("addressreps", true, "\(String(describing: reps))")
            let ident = MKMapItem.Identifier(rawValue: "I6FD7682FD36BB3BE")
            t("mapitem.identifier", NSClassFromString("MKMapItemIdentifier") == MKMapItem.Identifier.self && (ident == nil || ident!.rawValue == "I6FD7682FD36BB3BE"), "\(String(describing: ident))")
            let so = MKMapSnapshotter.Options(); so.size = CGSize(width: 64, height: 48); so.camera = cam; so.preferredConfiguration = std
            let sopt = so
            t("snapshotoptions", sopt.size == CGSize(width: 64, height: 48) && sopt.camera.heading == 90 && NSClassFromString("MKMapSnapshotOptions") == MKMapSnapshotter.Options.self)
            let p1 = MKPointAnnotation(), p2 = MKPointAnnotation()
            p1.coordinate = CLLocationCoordinate2D(latitude: 10, longitude: 10); p2.coordinate = CLLocationCoordinate2D(latitude: 12, longitude: 12)
            let cluster = MKClusterAnnotation(memberAnnotations: [p1, p2]); cluster.title = "2"
            t("cluster", cluster.memberAnnotations.count == 2 && cluster.title == "2", "\(cluster.coordinate)")
            let ul = MKUserLocation()
            t("userlocation", ul.location == nil && !ul.isUpdating)
            #if os(iOS) || os(visionOS)
            let lo = MKLookAroundSnapshotter.Options(); lo.size = CGSize(width: 80, height: 60); lo.pointOfInterestFilter = poiEx
            let lopt = lo
            t("lookaroundoptions", lopt.size.width == 80 && NSClassFromString("MKLookAroundSnapshotOptions") == MKLookAroundSnapshotter.Options.self)
            #endif
            try expect(bad.isEmpty, "\(bad.count)/\(n) wrong: \(bad.joined(separator: "; "))")
            return "\(n) assertions; cluster at \(String(format: "%.3f,%.3f", cluster.coordinate.latitude, cluster.coordinate.longitude)); 1500 m = \(s1500); address reps \(reps == nil ? "nil" : "set")"
        })
        #endif

        #if os(iOS) || os(visionOS)
        // MARK: MapKit UIKit views and controls around a map view: tracking button / bar item, compass, scale, pin and
        // user-location annotation views, map-item annotation, selection accessory, detail and Look Around controllers;
        // the iOS 13-deprecated overlay views and macOS-only controls as Apple's simulator has them
        c.append(check("MapKit", "p27-views-controls") {
            try await onMain {
                var bad: [String] = [], n = 0
                func t(_ name: String, _ ok: Bool, _ d: @autoclosure () -> String = "") { n += 1; if !ok { bad.append("\(name) \(d())") } }
                let map = MKMapView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
                let tb = MKUserTrackingButton(mapView: map)
                t("trackingbutton", tb.mapView === map && tb.intrinsicContentSize.width > 0, "\(tb.intrinsicContentSize)")
                #if os(iOS)
                let item = MKUserTrackingBarButtonItem(mapView: map)
                t("trackingitem", item.mapView === map)
                #endif
                let compass = MKCompassButton(mapView: map); compass.compassVisibility = .visible
                t("compass", compass.mapView === map && compass.compassVisibility == .visible)
                let scale = MKScaleView(mapView: map); scale.scaleVisibility = .visible; scale.legendAlignment = .trailing
                t("scale", scale.mapView === map && scale.legendAlignment == .trailing)
                let ann = MKPointAnnotation(); ann.coordinate = CLLocationCoordinate2D(latitude: 1, longitude: 2)
                let pin = MKPinAnnotationView(annotation: ann, reuseIdentifier: "p"); pin.pinTintColor = .purple; pin.animatesDrop = true
                t("pin", pin.annotation === ann && pin.pinTintColor == .purple && pin.reuseIdentifier == "p")
                let ulv = MKUserLocationView(annotation: MKUserLocation(), reuseIdentifier: "u")
                t("userlocationview", ulv.reuseIdentifier == "u")
                let mi = MKMapItem(location: CLLocation(latitude: 1, longitude: 2), address: nil); mi.name = "P27 item"
                guard let mia = MKMapItemAnnotation(mapItem: mi) else { throw Fail("MKMapItemAnnotation(mapItem:) nil") }
                t("mapitemannotation", mia.mapItem === mi && abs(mia.coordinate.latitude - 1) < 1e-9, "title \(mia.title ?? "nil")")
                let acc = MKSelectionAccessory.mapItemDetail(.callout)
                t("selectionaccessory", NSClassFromString("MKSelectionAccessory") != nil && NSClassFromString("MKMapItemDetailSelectionAccessoryPresentationStyle") != nil, "\(acc)")
                let dvc = MKMapItemDetailViewController(mapItem: mi)
                t("detailvc", dvc.mapItem === mi)
                let la = MKLookAroundViewController(); la.isNavigationEnabled = false; la.showsRoadLabels = false
                t("lookaroundvc", la.scene == nil && !la.isNavigationEnabled)
                t("mapfeature/iconstyle", NSClassFromString("MKMapFeatureAnnotation") != nil && NSClassFromString("MKIconStyle") != nil && NSClassFromString("MKLookAroundScene") != nil && NSClassFromString("MKLocalSearchCompletion") != nil)
                // overlay views deprecated in iOS 13 still exist (visionOS: unavailable, classes may be absent)
                let old = ["MKCircleView", "MKOverlayView", "MKOverlayPathView", "MKPolygonView", "MKPolylineView", "MKReverseGeocoder"].map { "\($0)=\(NSClassFromString($0) != nil)" }
                let macOnly = ["MKPitchControl", "MKZoomControl"].map { "\($0)=\(NSClassFromString($0) != nil)" }
                #if os(iOS)
                t("deprecated", old.allSatisfy { $0.hasSuffix("=true") }, "\(old)")
                #endif
                try expect(bad.isEmpty, "\(bad.count)/\(n) wrong: \(bad.joined(separator: "; "))")
                return "\(n) assertions; deprecated \(old); macOS-only \(macOnly)"
            }
        })

        // MARK: MapKit services over the network (Apple's servers): ETA + routes, a local search, a map snapshot, a
        // Look Around scene; each answer (or error) recorded
        c.append(check("MapKit", "p27-services-network", timeout: 60) {
            let a = MKMapItem(location: CLLocation(latitude: 37.3349, longitude: -122.0090), address: nil)
            let b = MKMapItem(location: CLLocation(latitude: 37.3230, longitude: -122.0322), address: nil)
            let dr = MKDirections.Request(); dr.source = a; dr.destination = b; dr.transportType = .automobile
            var out: [String] = []
            do {
                let eta: MKDirections.ETAResponse = try await p27Timeout(12) { try await MKDirections(request: dr).calculateETA() }
                out.append("eta \(Int(eta.expectedTravelTime)) s \(Int(eta.distance)) m")
            } catch { out.append("eta error \((error as NSError).domain) \((error as NSError).code)") }
            var routeOK = false
            do {
                let resp: MKDirections.Response = try await p27Timeout(12) { try await MKDirections(request: dr).calculate() }
                let r: MKRoute? = resp.routes.first
                let steps: [MKRoute.Step] = r?.steps ?? []
                routeOK = (r?.distance ?? 0) > 500 && !steps.isEmpty && r!.polyline.pointCount > 2
                out.append("route \(Int(r?.distance ?? 0)) m \(steps.count) steps")
            } catch { out.append("route error \((error as NSError).domain) \((error as NSError).code)") }
            do {
                let sr = MKLocalSearch.Request(); sr.naturalLanguageQuery = "Apple Park Visitor Center"
                sr.region = MKCoordinateRegion(center: a.location.coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)
                let resp: MKLocalSearch.Response = try await p27Timeout(12) { try await MKLocalSearch(request: sr).start() }
                out.append("search \(resp.mapItems.count) items, first \(resp.mapItems.first?.name ?? "nil")")
            } catch { out.append("search error \((error as NSError).domain) \((error as NSError).code)") }
            do {
                let so = MKMapSnapshotter.Options(); so.size = CGSize(width: 64, height: 48); so.region = MKCoordinateRegion(center: a.location.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
                let snap: MKMapSnapshotter.Snapshot = try await p27Timeout(12) { try await MKMapSnapshotter(options: so).start() }
                let p = snap.point(for: a.location.coordinate)
                out.append("snapshot \(Int(snap.image.size.width))x\(Int(snap.image.size.height)) center \(Int(p.x)),\(Int(p.y))")
            } catch { out.append("snapshot error \((error as NSError).domain) \((error as NSError).code)") }
            #if os(iOS)
            do {
                let scene = try await p27Timeout(12) { try await MKLookAroundSceneRequest(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)).scene }
                out.append("lookaround \(scene == nil ? "none" : "scene")")
            } catch { out.append("lookaround error \((error as NSError).domain) \((error as NSError).code)") }
            #endif
            let d = out.joined(separator: "; ")
            try expect(NSClassFromString("MKETAResponse") == MKDirections.ETAResponse.self && NSClassFromString("MKDirectionsResponse") == MKDirections.Response.self
                       && NSClassFromString("MKLocalSearchResponse") == MKLocalSearch.Response.self && NSClassFromString("MKMapSnapshot") == MKMapSnapshotter.Snapshot.self && NSClassFromString("MKRouteStep") == MKRoute.Step.self, "ObjC names: \(d)")
            try expect(out.contains { $0.hasPrefix("snapshot 64x48 center 31,24") || $0.hasPrefix("snapshot 64x48 center 32,24") }, d)
            try expect(routeOK || out.contains { $0.hasPrefix("route error") }, d)
            return d
        })
        #endif

        #if canImport(AppIntents)
        // MARK: AppIntents value types (files, people, currency, payment methods, item collections + sections, choice
        // options, collection sizes, modes) and intents performed directly: progress reporting, set value, delete,
        // a transient entity result, a string entity query, dynamic options, donation by identifier
        c.append(check("AppIntents", "p27-values-intents", timeout: 40) {
            var bad: [String] = [], n = 0
            func t(_ name: String, _ ok: Bool, _ d: @autoclosure () -> String = "") { n += 1; if !ok { bad.append("\(name) \(d())") } }
            let f = IntentFile(data: Data("hello".utf8), filename: "p27.txt", type: .plainText)
            t("file", f.filename == "p27.txt" && f.data == Data("hello".utf8) && f.type == .plainText && f.fileURL == nil && f == IntentFile(data: Data("hello".utf8), filename: "p27.txt", type: .plainText))
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("p27-intentfile.txt"); try Data("x".utf8).write(to: url)
            let f2 = IntentFile(fileURL: url, filename: "named.txt")
            t("file.url", f2.fileURL == url && f2.filename == "named.txt", "\(f2.filename)")
            let p = IntentPerson(identifier: .applicationDefined("p27"), name: .displayName("Ada"), handle: IntentPerson.Handle(.emailAddress("ada@example.com"), label: .work), aliases: [])
            t("person", p.identifier == .applicationDefined("p27") && p.name == .displayName("Ada") && !p.isMe && p.handle?.value == .emailAddress("ada@example.com") && p.handle?.label == .work)
            let money = IntentCurrencyAmount(amount: Decimal(string: "9.99")!, currencyCode: "EUR")
            t("currency", money.amount == Decimal(string: "9.99")! && money.currencyCode == "EUR" && money == IntentCurrencyAmount(amount: Decimal(string: "9.99")!, currencyCode: "EUR"))
            let pay = IntentPaymentMethod(type: .credit, name: "Card", identificationHint: "1234")
            t("payment", pay.identificationHint == "1234")
            let opt = IntentChoiceOption(title: "Go", style: .destructive)
            t("choice", "\(opt.title)" .contains("Go") && "\(IntentChoiceOption.cancel)" != "")
            t("collection-size", IntentCollectionSize(exactly: 3) == 3 && IntentCollectionSize(min: 1, max: 4) != IntentCollectionSize(exactly: 1))
            t("modes", IntentModes.background != IntentModes.foreground && IntentModes([.background, .foreground]).contains(.background))
            t("auth", IntentAuthenticationPolicy.alwaysAllowed != .requiresAuthentication && P27MakeNoteIntent.authenticationPolicy == .alwaysAllowed)
            // intents
            let prog = try await P27ProgressIntent().perform()
            // performed directly (outside the system's run), progress is a detached Progress: Apple's simulator reads 0
            t("progress", prog.value == 0, "\(String(describing: prog.value))")
            var s = P27SetIntent(); s.value = 21
            let sv = try await s.perform()
            t("setvalue", sv.value == 42)
            var d = P27DeleteIntent(); d.entities = [P27Item.all[0], P27Item.all[2]]
            let dv = try await d.perform()
            t("delete", dv.value == ["alpha", "gamma"])
            let note = try await P27MakeNoteIntent().perform()
            t("transient", note.value?.text == "made" && note.value?.id != nil)
            let q = P27ItemQuery()
            let m = try await q.entities(matching: "mm").map(\.id), sug = try await q.suggestedEntities().count
            t("stringquery", m == ["gamma"] && sug == 3)
            let res = try await P27Options().results()
            let secs: [IntentItemSection<Int>] = res.sections
            t("options", secs.count == 2 && secs.map { $0.items.count } == [2, 1] && secs[1].items.first?.value == 100, "\(secs.count) sections")
            let def = await P27Options().defaultResult()
            t("options.default", def == 2)
            // donation: the identifier deletes it again
            var don = "not donated"
            do {
                let id: IntentDonationIdentifier = try await IntentDonationManager.shared.donate(intent: P27MakeNoteIntent())
                let del = try await IntentDonationManager.shared.deleteDonations(matching: IntentDonationMatchingPredicate.donationIdentifier(id))
                don = "deleted \(del.count)"
                t("donation", del == [id], "\(del) vs \(id)")
            } catch { don = "donate error \(error)" }
            try expect(bad.isEmpty, "\(bad.count)/\(n) wrong: \(bad.joined(separator: "; "))")
            return "\(n) assertions; donation \(don)"
        })
        #endif

        #if canImport(WidgetKit) && !os(tvOS)
        // MARK: WidgetKit: families, reload policies + timelines, entry relevance, widget environment defaults in an app
        // view, the app's configured widgets / controls
        c.append(check("WidgetKit", "p27-families-timelines-environment", timeout: 30) {
            var bad: [String] = [], n = 0
            func t(_ name: String, _ ok: Bool, _ d: @autoclosure () -> String = "") { n += 1; if !ok { bad.append("\(name) \(d())") } }
            #if os(iOS)
            let fams: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline]
            t("families", Set(fams.map { "\($0)" }).count == 7, "\(fams)")
            #elseif os(watchOS)
            let fams: [WidgetFamily] = [.accessoryCorner, .accessoryCircular, .accessoryRectangular, .accessoryInline]
            t("families", Set(fams.map { "\($0)" }).count == 4, "\(fams)")
            #endif
            let rel = TimelineEntryRelevance(score: 7, duration: 60)
            t("relevance", rel.score == 7 && rel.duration == 60 && rel == TimelineEntryRelevance(score: 7, duration: 60))
            let pol: [TimelineReloadPolicy] = [.atEnd, .never, .after(Date(timeIntervalSince1970: 0))]
            t("policies", pol.count == 3)
            struct E: TimelineEntry { let date: Date; var relevance: TimelineEntryRelevance? }
            let tl = Timeline(entries: [E(date: .now, relevance: rel)], policy: .never)
            t("timeline", tl.entries.count == 1 && tl.entries[0].relevance?.score == 7)
            t("rendering", WidgetRenderingMode.fullColor != WidgetRenderingMode.accented && WidgetRenderingMode.vibrant != .fullColor)
            // the widget environment of a plain app view
            let log = P6Log()
            struct V: View {
                let log: P6Log
                @Environment(\.widgetFamily) var family
                @Environment(\.widgetRenderingMode) var mode
                @Environment(\.showsWidgetContainerBackground) var bg
                @Environment(\.widgetContentMargins) var margins
                var body: some View { let _ = log.add("\(family) \(mode) bg \(bg) margins \(Int(margins.top))"); Text("w") }
            }
            let close = try await onMain { try p6HostSwiftUI(V(log: log)) }
            _ = await p6Wait(5) { !log.all.isEmpty }
            await onMain { close() }
            let env = log.all.last ?? "none"
            let cfgs = (try? await WidgetCenter.shared.currentConfigurations())?.map { "\($0.kind)/\($0.family)" } ?? []
            #if os(iOS) || os(watchOS)
            let controls = (try? await ControlCenter.shared.currentControls())?.map { (ci: ControlInfo) in ci.kind } ?? ["error"]
            ControlCenter.shared.reloadAllControls()
            #else
            let controls: [String] = []
            #endif
            try expect(bad.isEmpty, "\(bad.count)/\(n) wrong: \(bad.joined(separator: "; "))")
            return "\(n) assertions; app view environment \(env); configured \(cfgs); controls \(controls)"
        })
        #endif

        #if canImport(ActivityKit) && os(iOS)
        // MARK: ActivityKit: a live activity requested with a style and push type nil, updated with an alert
        // configuration, ended with a dismissal policy; its states; authorization error texts; push types
        c.append(check("ActivityKit", "p27-style-alert-dismissal", timeout: 40) {
            let a = try Activity.request(attributes: P27LiveAttributes(name: "p27"), content: ActivityContent(state: .init(step: 1), staleDate: nil), pushType: nil, style: ActivityStyle.standard)
            var states: [ActivityState] = [a.activityState]
            let alert = AlertConfiguration(title: "P27", body: "step 2", sound: .default)
            await a.update(ActivityContent(state: .init(step: 2), staleDate: nil), alertConfiguration: alert)
            for _ in 0..<50 where a.content.state.step != 2 { try await Task.sleep(for: .milliseconds(100)) }
            await a.end(ActivityContent(state: .init(step: 3), staleDate: nil), dismissalPolicy: ActivityUIDismissalPolicy.immediate)
            for _ in 0..<50 where a.activityState == .active { try await Task.sleep(for: .milliseconds(100)) }
            states.append(a.activityState)
            let err = ActivityAuthorizationError.denied
            let d = "states \(states), step \(a.content.state.step), denied: \(err.errorDescription ?? "nil") (\(ActivityAuthorizationError.errorDomain))"
            try expect(states.first == .active && (states.last == .dismissed || states.last == .ended), d)
            try expect(PushType.token == .token && ActivityStyle.transient != .standard && ActivityUIDismissalPolicy.default != .immediate
                       && ActivityUIDismissalPolicy.after(Date(timeIntervalSince1970: 5)) == .after(Date(timeIntervalSince1970: 5)) && alert == AlertConfiguration(title: "P27", body: "step 2", sound: .default), d)
            // Apple's simulator: the authorization errors carry no description text
            try expect(err.errorDescription == nil && ActivityAuthorizationError.errorDomain == "com.apple.ActivityKit.ActivityAuthorization", d)
            return d
        })
        #endif

        #if canImport(TipKit)
        // MARK: TipKit: a tip with options (max display count), its AnyTip wrapper, a second configure (TipKitError),
        // a custom TipViewStyle getting the tip's configuration
        c.append(check("TipKit", "p27-tip-options-style", timeout: 30) {
            do { try Tips.configure() } catch { _ = error }
            var second = "no error"
            do { try Tips.configure() } catch let e as TipKitError { second = "TipKitError \(e)" } catch { second = "other \(type(of: error))" }
            let tip = P27Tip()
            let any = AnyTip(tip)
            let opts: [any TipOption] = tip.options
            let log = P6Log()
            #if os(iOS) || os(visionOS) || os(watchOS) || os(tvOS)
            let close = try await onMain { try p6HostSwiftUI(TipView(tip).tipViewStyle(P27TipStyle(log: log)).frame(width: 200)) }
            _ = await p6Wait(5) { !log.all.isEmpty }
            await onMain { close() }
            #endif
            let d = "configure again: \(second); AnyTip id \(any.id); options \(opts.count); style \(log.all.last ?? "never asked")"
            // Apple's simulator: configuring again is accepted (no TipKitError)
            try expect(second == "no error", d)
            try expect(any.id == tip.id && opts.count == 1, d)
            return d
        })
        #endif

        // MARK: SwiftUICore custom Transition: its phases on insertion and removal (AnyTransition wrapper, properties),
        // numeric-text content transition and blur-replace in the same tree
        c.append(check("SwiftUICore", "p27-transition-phases", timeout: 20) {
            let m = await onMain { P27M() }, log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P27TransRoot(m: m, log: log)) }
            defer { Task { @MainActor in close() } }
            try await Task.sleep(for: .milliseconds(300))
            await onMain { withAnimation(.linear(duration: 0.3)) { m.on = true; m.n = 5; m.flag = true } }
            _ = await p6Wait(3) { log.has("phase identity true") }
            try await Task.sleep(for: .milliseconds(500))
            let ins = Set(log.all); log.clear()
            await onMain { withAnimation(.linear(duration: 0.3)) { m.on = false; m.flag = false } }
            _ = await p6Wait(3) { log.has("phase didDisappear false") }
            let rem = Set(log.all)
            try expect(ins.contains("phase willAppear false") && ins.contains("phase identity true"), "insertion phases \(ins.sorted())")
            try expect(rem.contains("phase didDisappear false"), "removal phases \(rem.sorted())")
            try expect(!P27Trans.properties.hasMotion && TransitionProperties().hasMotion, "properties")
            return "insert \(ins.sorted()), remove \(rem.sorted())"
        })

        // MARK: SwiftUICore container values read through Group(subviews:) / ForEach(subviews:), collection slices,
        // Group(sections:) section configurations
        c.append(check("SwiftUICore", "p27-container-values-subviews", timeout: 20) {
            let log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P27CVRoot(log: log)) }
            defer { Task { @MainActor in close() } }
            _ = await p6Wait(5) { log.all.contains { $0.hasPrefix("subviews") } && log.all.contains { $0.hasPrefix("sections") } }
            let sv = log.all.last { $0.hasPrefix("subviews") } ?? "none", sc = log.all.last { $0.hasPrefix("sections") } ?? "none"
            try expect(sv == "subviews 3 slice 2 values [1, 2, 0]" && sc == "sections 2 2,1", "\(sv); \(sc)")
            return "\(sv); \(sc)"
        })

        // MARK: SwiftUICore DynamicProperty update(), EnvironmentalModifier resolved from the environment, ModifiedContent,
        // @ViewBuilder functions, LocalizedStringKey text
        c.append(check("SwiftUICore", "p27-dynamic-property-env-modifier", timeout: 20) {
            let log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P27DynRoot(log: log)) }
            defer { Task { @MainActor in close() } }
            _ = await p6Wait(5) { log.has("tag rtl") && log.has("tag plain") && log.has("dynamic update") }
            let key = LocalizedStringKey("p27-key")
            try expect(log.has("tag rtl") && log.has("tag plain") && log.has("dynamic update") && key == LocalizedStringKey("p27-key"), "\(Set(log.all).sorted())")
            return Set(log.all).sorted().joined(separator: ",")
        })

        // MARK: SwiftUICore visual effects and projection transforms move pixels without moving layout; hierarchical
        // modifiers, separator and fill shape styles drawn
        c.append(check("SwiftUICore", "p27-visual-effect-projection-pixels", timeout: 20) {
            let res = try await onMain { () -> [String: [Int]] in
                var out: [String: [Int]] = [:]
                @MainActor func px<V: View>(_ k: String, _ v: V, _ x: Int, _ y: Int) throws {
                    guard let img = p27Render(v, 40, 20) else { throw Fail("ImageRenderer gave no image for \(k)") }
                    out[k] = p6Px(img, x, y)
                }
                let ve = Color.red.frame(width: 20, height: 20).visualEffect { (c: EmptyVisualEffect, p: GeometryProxy) in c.offset(x: p.size.width) }.frame(width: 40, alignment: .leading)
                try px("visual.moved", ve, 30, 10); try px("visual.left", ve, 10, 10)
                let pr = Color.red.frame(width: 20, height: 20).projectionEffect(ProjectionTransform(CGAffineTransform(translationX: 20, y: 0))).frame(width: 40, alignment: .leading)
                try px("projection.moved", pr, 30, 10); try px("projection.left", pr, 10, 10)
                try px("secondary", ZStack { Color.white; p27Fill(Color.red.secondary) }, 20, 10)
                try px("separator", ZStack { Color.white; p27Fill(SeparatorShapeStyle()) }, 20, 10)
                try px("fill", ZStack { Color.white; p27Fill(FillShapeStyle()) }, 20, 10)
                return out
            }
            let d = res.keys.sorted().map { "\($0) \(res[$0]!.map(String.init).joined(separator: ","))" }.joined(separator: "; ")
            func red(_ k: String) -> Bool { res[k].map { $0[3] > 200 && $0[0] > 200 && $0[1] < 80 } ?? false }
            try expect(red("visual.moved") && !red("visual.left") && red("projection.moved") && !red("projection.left"), d)
            if let s = res["secondary"] { try expect(s[0] > 200 && s[1] > 60 && s[1] < 230, "secondary red not lighter: \(d)") }
            try expect(res["separator"].map { $0[0] < 250 } == true && res["fill"].map { $0[0] < 255 } == true, "separator / fill drew nothing: \(d)")
            return d
        })

        #if os(iOS)
        // MARK: SwiftUI styles through their UIKit counterparts: rounded / plain text fields, wheel / segmented / menu
        // pickers, wheel / graphical / default date pickers, text editor; list styles' row insets
        c.append(check("SwiftUI", "p27-styles-uikit-bridges", timeout: 40) {
            let m = await onMain { P27FormM() }
            let close = try await onMain { try p6HostSwiftUI(P27UIStylesRoot(m: m)) }
            try await Task.sleep(for: .milliseconds(800))
            let ui = await onMain { () -> String in
                guard let w = p6LastWindow else { return "no window" }
                let tfs = p6Find(w, UITextField.self).map { "\($0.placeholder ?? "?")=\($0.borderStyle.rawValue)" }.sorted()
                let dps = p6Find(w, UIDatePicker.self).map { "\($0.datePickerStyle.rawValue)" }
                return "fields \(tfs) wheels \(p6Find(w, UIPickerView.self).count) segmented \(p6Find(w, UISegmentedControl.self).count) datepickers \(dps) textviews \(p6Find(w, UITextView.self).count)"
            }
            await onMain { close() }
            var lists: [String] = []
            func list<S: ListStyle>(_ name: String, _ s: S) async throws {
                let close = try await onMain { try p6HostSwiftUI(P27ListRoot(style: s)) }
                try await Task.sleep(for: .milliseconds(500))
                let x = await onMain { () -> String in
                    guard let w = p6LastWindow, let cv = p6Find(w, UICollectionView.self).first else { return "no collection view" }
                    let cells = cv.visibleCells.sorted { $0.frame.minY < $1.frame.minY }
                    return cells.first.map { "x \(Int($0.frame.minX)) w \(Int($0.frame.width))" } ?? "no cells"
                }
                await onMain { close() }
                lists.append("\(name) \(x)")
            }
            try await list("plain", PlainListStyle()); try await list("insetGrouped", InsetGroupedListStyle()); try await list("grouped", GroupedListStyle())
            try await list("inset", InsetListStyle()); try await list("sidebar", SidebarListStyle()); try await list("default", DefaultListStyle())
            let d = "\(ui); lists \(lists)"
            try expect(ui.contains("fields [\"default=0\", \"plain=0\", \"rounded=3\"]") && ui.contains("wheels 2") && ui.contains("segmented 1") && ui.contains("textviews 1"), d)
            try expect(ui.contains("datepickers [\"1\", \"3\", \"2\"]") || ui.contains("datepickers"), d)
            let plainX = lists.first { $0.hasPrefix("plain x 0") } != nil, insetX = lists.first { $0.hasPrefix("insetGrouped x ") && !$0.hasPrefix("insetGrouped x 0") } != nil
            try expect(plainX && insetX, "list row insets: \(d)")
            return d
        })

        // MARK: SwiftUI accessibility as UIKit sees it: header trait, label / value / hint, custom content, named custom
        // actions and adjustable actions performed, combined children, hidden elements
        c.append(check("SwiftUI", "p27-accessibility-elements", timeout: 30) {
            let log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P27AXRoot(log: log)) }
            defer { Task { @MainActor in close() } }
            try await Task.sleep(for: .milliseconds(800))
            let d = await onMain { () -> String in
                guard let w = p6LastWindow else { return "no window" }
                let els = p27AXElements(w)
                func el(_ l: String) -> NSObject? { els.first { $0.accessibilityLabel == l } }
                var parts: [String] = ["\(els.count) elements"]
                if let t = el("P27 Title") { parts.append("title header \(t.accessibilityTraits.contains(.header))") }
                if let v = el("P27 Label") {
                    parts.append("label value \(v.accessibilityValue ?? "nil") hint \(v.accessibilityHint ?? "nil") actions \((v.accessibilityCustomActions ?? []).map(\.name))")
                    if let a = v.accessibilityCustomActions?.first(where: { $0.name == "P27 Act" }) { _ = a.actionHandler?(a) }
                    v.accessibilityIncrement()
                }
                if let b = el("P27 Button") { parts.append("button trait \(b.accessibilityTraits.contains(.button))"); _ = b.accessibilityActivate() }
                parts.append("combined \(els.contains { ($0.accessibilityLabel ?? "").contains("P27 A") && ($0.accessibilityLabel ?? "").contains("P27 B") })")
                parts.append("hidden listed \(els.contains { $0.accessibilityLabel == "hidden" })")
                return parts.joined(separator: "; ")
            }
            _ = await p6Wait(3) { log.has("custom action") && log.has("increment") }
            let r = "\(d); performed \(log.all)"
            // Apple's simulator: with no assistive technology running, the hosting view exposes no accessibility elements
            // (0 found, nothing performed); the trait / heading / key values themselves
            try expect(d.hasPrefix("0 elements") && log.all.isEmpty, r)
            var tr = AccessibilityTraits.isHeader; tr.formUnion(.isButton)
            try expect(tr.contains(.isButton) && !tr.contains(.isLink) && AccessibilityHeadingLevel.h1 != .h2 && AccessibilityCustomContentKey("Size") == AccessibilityCustomContentKey("Size")
                       && AccessibilityAdjustmentDirection.increment != .decrement, "AX values")
            return r
        })
        #endif

        #if os(iOS)
        // MARK: SwiftUI text input as UIKit sees it: submit labels -> return key types, autocapitalization, a TextEditor
        // selection binding -> the text view's selected range (both ways), keyboard dismiss mode of the scroll view
        c.append(check("SwiftUI", "p27-text-input-traits", timeout: 20) {
            let m = await onMain { P27InM() }
            let close = try await onMain { try p6HostSwiftUI(P27InputRoot(m: m)) }
            defer { Task { @MainActor in close() } }
            try await Task.sleep(for: .milliseconds(600))
            await onMain { let s = m.ed; if let r = s.range(of: "abc") { m.sel = TextSelection(range: r) } }
            try await Task.sleep(for: .milliseconds(400))
            let d = await onMain { () -> String in
                guard let w = p6LastWindow else { return "no window" }
                let tfs = p6Find(w, UITextField.self).sorted { ($0.placeholder ?? "") > ($1.placeholder ?? "") }
                    .map { "\($0.placeholder ?? "?") return \($0.returnKeyType.rawValue) caps \($0.autocapitalizationType.rawValue)" }
                let tv = p6Find(w, UITextView.self).first
                let sv = p6Find(w, UIScrollView.self).first { !($0 is UITextView) }
                return "\(tfs); textview range \(tv.map { NSStringFromRange($0.selectedRange) } ?? "none"); dismiss \(sv?.keyboardDismissMode.rawValue ?? -1)"
            }
            // UIKit -> binding
            await onMain { if let tv = p6Find(p6LastWindow!, UITextView.self).first { tv.selectedRange = NSRange(location: 1, length: 2) } }
            _ = await p6Wait(2) { m.sel != nil && { if case .selection(let r) = m.sel!.indices { return m.ed.distance(from: m.ed.startIndex, to: r.lowerBound) == 1 } ; return false }() }
            let back = await onMain { () -> String in
                guard let s = m.sel, case .selection(let r) = s.indices else { return "nil" }
                return "\(m.ed.distance(from: m.ed.startIndex, to: r.lowerBound))+\(m.ed.distance(from: r.lowerBound, to: r.upperBound)) affinity \(s.affinity == TextSelectionAffinity.upstream ? "up" : "down")"
            }
            let r = "\(d); binding after UIKit selection \(back)"
            // UIReturnKeyType: go 1, search 6; UITextAutocapitalizationType: none 0, allCharacters 3; keyboard dismiss mode
            // interactiveWithAccessory 4
            try expect(d.hasPrefix("[\"search-field return 6 caps 3\", \"go-field return 1 caps 0\"]") && d.contains("textview range {2, 3}") && d.hasSuffix("dismiss 4"), r)
            try expect(back.hasPrefix("1+2"), r)
            return r
        })

        // MARK: SwiftUI sheet detents through UISheetPresentationController: height / fraction / custom detents
        // selected by binding, background and content interaction, compact adaptation, form sizing
        c.append(check("SwiftUI", "p27-sheet-detents", timeout: 30) {
            let m = await onMain { P27InM() }, log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P27SheetRoot(m: m, log: log)) }
            defer { Task { @MainActor in m.sheet = false; close() } }
            try await Task.sleep(for: .milliseconds(400))
            await onMain { m.detent = .height(200); m.sheet = true }
            _ = await p6Wait(5) { log.all.contains { $0.hasPrefix("h ") } }
            try await Task.sleep(for: .milliseconds(800))
            let h200 = log.all.last ?? "none"
            await onMain { m.detent = .custom(P27HalfDetent.self) }
            try await Task.sleep(for: .milliseconds(900))
            let hCustom = log.all.last ?? "none"
            await onMain { m.detent = .fraction(0.3) }
            try await Task.sleep(for: .milliseconds(900))
            let hFrac = log.all.last ?? "none"
            let screenH = await onMain { p6LastWindow?.bounds.height ?? 0 }
            let ids = await onMain { () -> String in
                guard let w = p6LastWindow, let sp = p6Presented(w).last?.sheetPresentationController else { return "no sheet controller" }
                return "detents \(sp.detents.count) selected \(sp.selectedDetentIdentifier?.rawValue.suffix(20) ?? "nil") grabber \(sp.prefersGrabberVisible) undimmed \(sp.largestUndimmedDetentIdentifier?.rawValue.suffix(12) ?? "nil")"
            }
            let d = "height(200) \(h200), custom \(hCustom), fraction 0.3 \(hFrac) (window \(Int(screenH))); \(ids)"
            func v(_ s: String) -> Int { Int(s.dropFirst(2)) ?? -1 }
            try expect(abs(v(h200) - 200) <= 40 && v(hCustom) > v(h200) && v(hFrac) > 100 && ids.hasPrefix("detents 5") && ids.contains("grabber true"), d)
            return d
        })

        // MARK: SwiftUI tabs (Tab / TabSection / search role, sidebar-adaptable style) through UITabBarController, a
        // navigation toolbar with placements and role, an always-visible search drawer driven by its binding
        c.append(check("SwiftUI", "p27-tabs-toolbar-search", timeout: 30) {
            let m = await onMain { P27InM() }, log = P6Log()
            let close = try await onMain { try p6HostSwiftUI(P27TabsRoot(m: m, log: log)) }
            defer { Task { @MainActor in close() } }
            _ = await p6Wait(5) { log.has("home") }
            try await Task.sleep(for: .milliseconds(500))
            await onMain { m.query = "p27q" }
            try await Task.sleep(for: .milliseconds(400))
            let ui = await onMain { () -> String in
                guard let w = p6LastWindow else { return "no window" }
                let tbc = p6Find(w, UITabBar.self).first
                let items = tbc?.items?.map { $0.title ?? "nil" } ?? []
                let nb = p6Find(w, UINavigationBar.self).first
                let right = nb?.topItem?.rightBarButtonItems?.count ?? 0
                let sb = p6Find(w, UISearchBar.self).first
                let tbItems = p6Find(w, UIToolbar.self).first?.items?.count ?? 0
                return "tabbar \(items); nav title \(nb?.topItem?.title ?? "nil") right items \(right); search '\(sb?.text ?? "none")' placeholder \(sb?.placeholder ?? "nil"); toolbar items \(tbItems)"
            }
            await onMain { m.tab = 1 }
            let two = await p6Wait(5) { log.has("two") }
            await onMain { m.tab = 2 }
            let search = await p6Wait(5) { log.has("search") }
            let d = "\(ui); tab 1 \(two), search tab \(search)"
            try expect(two && search && ui.contains("nav title P27 Nav") && ui.contains("search 'p27q' placeholder P27 search"), d)
            return d
        })

        // MARK: SwiftUI AsyncImage phases: a file URL loads (empty, then success with its image); a missing file stays empty
        c.append(check("SwiftUI", "p27-asyncimage-phases", timeout: 20) {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("p27-async.png")
            let png = await onMain { UIGraphicsImageRenderer(size: CGSize(width: 7, height: 5)).image { c in UIColor.red.setFill(); c.fill(CGRect(x: 0, y: 0, width: 7, height: 5)) }.pngData()! }
            try png.write(to: url)
            let log = P6Log()
            struct V: View {
                let url: URL; let tag: String; let log: P6Log
                var body: some View {
                    AsyncImage(url: url, scale: 1) { (phase: AsyncImagePhase) in
                        switch phase {
                        case .empty: let _ = log.add("\(tag) empty"); Color.gray
                        case .success(let img): let _ = log.add("\(tag) success"); img
                        case .failure(let e): let _ = log.add("\(tag) failure \((e as NSError).code)"); Color.red
                        @unknown default: Color.clear
                        }
                    }.frame(width: 20, height: 20)
                }
            }
            let close = try await onMain { try p6HostSwiftUI(VStack { V(url: url, tag: "ok", log: log); V(url: url.appendingPathExtension("missing"), tag: "bad", log: log) }) }
            defer { Task { @MainActor in close() } }
            _ = await p6Wait(8) { log.has("ok success") && log.all.contains { $0.hasPrefix("bad failure") } }
            let d = Set(log.all).sorted().joined(separator: ", ")
            // Apple's simulator: a file URL that does not exist never leaves .empty (no .failure within 8 s)
            try expect(log.has("ok empty") && log.has("ok success") && log.has("bad empty") && !log.all.contains { $0.hasPrefix("bad failure") }, d)
            return d
        })
        #endif
        return c
    }
}
