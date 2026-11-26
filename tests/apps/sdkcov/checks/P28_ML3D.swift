// SDK coverage, round 30 wave 2 (P28): public API of the SDK still not referenced by any check after P27
// (~/scratch/r30/apisurf.py), area: ML3D. Each check asserts what Apple's simulator answers (ref-mac.sh --only);
// ids start with "p28-".
// CreateMLComponents: small estimators fitted on in-app data (linear / logistic / network regressors and classifiers,
// time-series forecaster and classifier, multi-label network), their adaptors (supervised / temporal / tabular /
// updatable / preprocessing compositions), temporal sequences, random augmentations, metrics and error values.
import Foundation
import CoreGraphics
import ImageIO
#if canImport(CreateMLComponents)
import CreateMLComponents
import CoreML
import TabularData
#endif
#if canImport(CoreImage)
import CoreImage
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(RealityKit) && !os(watchOS)
import RealityKit
#endif
#if canImport(Metal)
import Metal
#endif
#if canImport(MultipeerConnectivity) && !os(watchOS)
import MultipeerConnectivity
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
#if canImport(Vision)
import Vision
#endif
#if canImport(USDKit) && !os(watchOS)
import USDKit
#endif
#if canImport(ModelIO)
import ModelIO
#endif
#if canImport(MetalKit)
import MetalKit
#endif
#if canImport(GameplayKit)
import GameplayKit
#endif
#if canImport(GLKit)
import GLKit
import OpenGLES
#endif
#if canImport(GameController)
import GameController
#endif
#if canImport(_RealityKit_SwiftUI) && !os(watchOS)
import SwiftUI
import _RealityKit_SwiftUI
#endif
#if canImport(Combine)
import Combine
#endif
#if canImport(TabletopKit) && os(visionOS)
import TabletopKit
import Spatial
#endif
#if canImport(ComputeGraph) && !os(watchOS)
import ComputeGraph
#endif
#if canImport(TouchController) && os(iOS)
import TouchController
#endif
#if canImport(ARKit) && os(iOS)
import ARKit
import SceneKit
import SpriteKit
import CoreLocation
#endif

#if canImport(RealityKit) && !os(watchOS)
struct P28NoopSystem: System { init(scene: RealityKit.Scene) {}; func update(context: SceneUpdateContext) {} }
/// an app's own entity action: raises the entity by `dy` over the action's duration (through the animation state)
struct P28Raise: EntityAction, Codable {
    var dy: Float
    var animatedValueType: (any AnimatableData.Type)? { Transform.self }
}
/// its handler, counting the events it is given
struct P28RaiseHandler: ActionHandlerProtocol {
    typealias ActionType = P28Raise
    static let seen = P28Tally()
    mutating func actionStarted(event: ActionEvent<P28Raise>) { Self.seen.add("started") }
    mutating func actionUpdated(event: ActionEvent<P28Raise>) {
        Self.seen.add("updated")
        guard let st = event.animationState as? RealityFoundation.AnimationState<Transform>, var t = st.defaultSource else { return }
        t.translation.y += event.action.dy * Float(p28Progress(st))
        _ = st.storeAnimatedValue(t)
    }
    mutating func actionEnded(event: ActionEvent<P28Raise>) { Self.seen.add("ended") }
}
/// a behaviour-tree action of the app's own and its handler
struct P28Think: BehaviorTreeAction, Codable { var animatedValueType: (any AnimatableData.Type)? { nil } }
struct P28ThinkHandler: BehaviorTreeActionHandler {
    typealias ActionType = P28Think
    mutating func actionStartedWithResult(event: ActionEvent<P28Think>) -> ActionResult? { .success }
}
/// an app's own force effect: a constant upward push, through the per-body parameters
struct P28Lift: ForceEffectProtocol {
    static let calls = P28Tally()
    var parameterTypes: PhysicsBodyParameterTypes { [.position, .mass] }
    var forceMode: ForceMode { .force }
    func update(parameters: inout ForceEffectParameters) {
        Self.calls.add("n\(parameters.physicsBodyCount) m\(parameters.masses.map { Array($0).count } ?? -1)")
        for i in 0..<parameters.physicsBodyCount { parameters.setForce([0, 40, 0], index: i) }
    }
}
#if !os(visionOS)
/// an app's own post-process effect (inverts the colours), as a RealityView would be given it
struct P28Invert: PostProcessEffect {
    var prepared = false
    mutating func prepare(for device: any MTLDevice) { prepared = true }
    mutating func postProcess(context: borrowing PostProcessEffectContext<any MTLCommandBuffer>) {}
}
#endif
final class P28Tally: @unchecked Sendable {
    private let lock = NSLock(); private var items: [String] = []
    func add(_ s: String) { lock.lock(); items.append(s); lock.unlock() }
    var all: [String] { lock.lock(); defer { lock.unlock() }; return items }
    func reset() { lock.lock(); items = []; lock.unlock() }
}
final class P28Once: @unchecked Sendable {
    private let lock = NSLock(); private var done = false
    func claim() -> Bool { lock.lock(); defer { lock.unlock() }; if done { return false }; done = true; return true }
}
/// race an async body against a time limit (an Apple call that may never answer offscreen): nil on timeout; the body
/// keeps running detached if it never returns
@MainActor func p28Within<T: Sendable>(_ secs: Double, _ body: @escaping @MainActor () async throws -> T) async -> Result<T, Error>? {
    let once = P28Once()
    return await withCheckedContinuation { (k: CheckedContinuation<Result<T, Error>?, Never>) in
        Task { @MainActor in
            let r: Result<T, Error>
            do { r = .success(try await body()) } catch { r = .failure(error) }
            if once.claim() { k.resume(returning: r) }
        }
        Task { try? await Task.sleep(nanoseconds: UInt64(secs * 1e9)); if once.claim() { k.resume(returning: nil) } }
    }
}
#endif
#if canImport(CreateMLComponents)
/// apply a transformer (sync or async in its declaration) through the protocol's async requirement
func p28Apply<T: Transformer>(_ t: T, _ x: T.Input) async throws -> T.Output { try await t.applied(to: x, eventHandler: nil) }
func p28Vec(_ s: [Float]) -> MLShapedArray<Float> { MLShapedArray(scalars: s, shape: [s.count]) }

/// a temporal sequence of values, one frame each at 10 fps, from an AsyncStream
func p28Seq<F: Sendable>(_ xs: [F], source: String = "p28") -> AnyTemporalSequence<F> {
    let feats = xs.enumerated().map { TemporalFeature(id: TemporalSegmentIdentifier(source: source, range: $0.offset..<$0.offset + 1, timescale: 10), feature: $0.element) }
    return AnyTemporalSequence(AsyncStream { k in for f in feats { k.yield(f) }; k.finish() }, count: feats.count)
}
func p28Collect<S: TemporalSequence>(_ s: S) async throws -> [S.Feature] {
    var out: [S.Feature] = []
    for try await f in s { out.append(f.feature) }
    return out
}
func p28Drain<B, R, G, A>(_ s: AugmentationSequence<B, R, G, A>) async throws -> [B.Element] {
    var out: [B.Element] = []; for try await x in s { out.append(x) }; return out
}
func p28Drain<B, R, G, A>(_ s: UpsampledAugmentationSequence<B, R, G, A>) async throws -> [B.Element] {
    var out: [B.Element] = []; for try await x in s { out.append(x) }; return out
}
func p28FitScaler(_ xs: [Double]) async throws -> StandardScaler<Double>.Transformer { try await StandardScaler<Double>().fitted(to: xs, eventHandler: nil) }
final class P28Events: @unchecked Sendable {
    private let lock = NSLock(); private var events: [CreateMLComponents.Event] = []
    func add(_ e: CreateMLComponents.Event) { lock.lock(); events.append(e); lock.unlock() }
    var all: [CreateMLComponents.Event] { lock.lock(); defer { lock.unlock() }; return events }
}
// generic helpers written against the framework's estimator / transformer protocols, as an app's training code is
func p28Fit<E: Estimator>(_ e: E, _ xs: [E.Transformer.Input]) async throws -> E.Transformer { try await e.fitted(to: xs, eventHandler: nil) }
func p28Update<E: UpdatableEstimator>(_ e: E, _ xs: [E.Transformer.Input]) async throws -> E.Transformer {
    var t = e.makeTransformer(); try await e.update(&t, with: xs, eventHandler: nil); return t
}
func p28FitSupervised<E: SupervisedEstimator>(_ e: E, _ xs: [AnnotatedFeature<E.Transformer.Input, E.Annotation>]) async throws -> E.Transformer { try await e.fitted(to: xs, eventHandler: nil) }
func p28UpdateSupervised<E: UpdatableSupervisedEstimator>(_ e: E, _ xs: [AnnotatedFeature<E.Transformer.Input, E.Annotation>]) async throws -> E.Transformer {
    var t = e.makeTransformer(); try await e.update(&t, with: xs, eventHandler: nil); return t
}
func p28FitTabular<E: TabularEstimator>(_ e: E, _ df: DataFrame) async throws -> E.Transformer { try await e.fitted(to: df, eventHandler: nil) }
func p28UpdateTabular<E: UpdatableTabularEstimator>(_ e: E, _ df: DataFrame) async throws -> E.Transformer {
    var t = e.makeTransformer(); try await e.update(&t, with: df, eventHandler: nil); return t
}
func p28FitSupervisedTabular<E: SupervisedTabularEstimator>(_ e: E, _ df: DataFrame) async throws -> E.Transformer { try await e.fitted(to: df, validateOn: nil, eventHandler: nil) }
func p28UpdateSupervisedTabular<E: UpdatableSupervisedTabularEstimator>(_ e: E, _ df: DataFrame) async throws -> E.Transformer {
    var t = e.makeTransformer(); try await e.update(&t, with: df, eventHandler: nil); return t
}
func p28ApplyTabular<T: TabularTransformer>(_ t: T, _ df: DataFrame) async throws -> DataFrame { try await t.applied(to: df, eventHandler: nil) }
func p28ApplyTemporal<T: TemporalTransformer, S: TemporalSequence>(_ t: T, _ s: S) async throws -> [T.Output] where S.Feature == T.Input {
    var out: [T.Output] = []
    for try await f in try await t.applied(to: s, eventHandler: nil) { out.append(f.feature) }
    return out
}
#if !os(watchOS)
func p28FitTemporal<E: TemporalEstimator, S: TemporalSequence>(_ e: E, _ xs: [S]) async throws -> E.Transformer where E.Transformer.Input == S.Feature { try await e.fitted(to: xs, eventHandler: nil) }
func p28UpdateTemporal<E: UpdatableTemporalEstimator, S: TemporalSequence>(_ e: E, _ xs: [S]) async throws -> E.Transformer where E.Transformer.Input == S.Feature {
    var t = e.makeTransformer(); try await e.update(&t, with: xs, eventHandler: nil); return t
}
func p28FitSupervisedTemporal<E: SupervisedTemporalEstimator, S: TemporalSequence>(_ e: E, _ xs: [AnnotatedFeature<S, E.Annotation>]) async throws -> E.Transformer where E.Transformer.Input == S.Feature {
    try await e.fitted(to: xs, eventHandler: nil)
}
func p28UpdateSupervisedTemporal<E: UpdatableSupervisedTemporalEstimator, S: TemporalSequence>(_ e: E, _ xs: [AnnotatedFeature<S, E.Annotation>]) async throws -> E.Transformer where E.Transformer.Input == S.Feature {
    var t = e.makeTransformer(); try await e.update(&t, with: xs, eventHandler: nil); return t
}
#endif
/// an app's own classifier / regressor (thresholds on the first value)
struct P28Threshold: Classifier {
    typealias Label = String
    func applied(to input: Double, eventHandler: EventHandler?) async throws -> ClassificationDistribution<String> {
        let p = Float(input > 0 ? 0.9 : 0.1)
        return ClassificationDistribution([Classification(label: "pos", probability: p), Classification(label: "neg", probability: 1 - p)])
    }
}
struct P28Half: Regressor { func applied(to input: Double, eventHandler: EventHandler?) async throws -> Double { input / 2 } }
/// an app's own random augmentation, composed with the framework's result builder
func p28Augmentation<R: RandomTransformer<Double, Double>>(@AugmentationBuilder<Double> _ b: () -> R) -> R { b() }
/// an app's own temporal sequence (a countdown), conforming to the protocol
struct P28Countdown: TemporalSequence {
    typealias Feature = Double
    typealias Element = TemporalFeature<Double>
    let from: Int
    var count: Int? { from }
    struct AsyncIterator: AsyncIteratorProtocol {
        var n: Int
        mutating func next() async throws -> TemporalFeature<Double>? {
            guard n > 0 else { return nil }
            defer { n -= 1 }
            return TemporalFeature(id: TemporalSegmentIdentifier(source: "countdown", range: n..<n + 1, timescale: 1), feature: Double(n))
        }
    }
    func makeAsyncIterator() -> AsyncIterator { AsyncIterator(n: from) }
}
/// an app's own transformer / random transformer / temporal transformer / estimator, through the protocols
struct P28Doubler: Transformer, Sendable { func applied(to input: Double, eventHandler: EventHandler?) async throws -> Double { input * 2 } }
struct P28Jitter: RandomTransformer { func applied(to input: Double, generator: inout some RandomNumberGenerator, eventHandler: EventHandler?) async throws -> Double { input + Double.random(in: 0..<0.001, using: &generator) } }
struct P28MeanEstimator: Estimator {
    func fitted<S: Sequence>(to input: S, eventHandler: EventHandler?) async throws -> LinearTransformer<Double> where S.Element == Double {
        let a = Array(input); return LinearTransformer(scale: 1, offset: -(a.reduce(0, +) / Double(max(a.count, 1))))
    }
    func encode(_ transformer: LinearTransformer<Double>, to encoder: inout any EstimatorEncoder) throws { try encoder.encode(transformer) }
    func decode(from decoder: inout any EstimatorDecoder) throws -> LinearTransformer<Double> { try decoder.decode(LinearTransformer<Double>.self) }
}
/// an app's own estimator encoder / decoder (JSON blobs in a list)
struct P28JSONCoder: EstimatorEncoder, EstimatorDecoder {
    var blobs: [Data] = [], optim: [Data] = []
    mutating func encode<T: Encodable>(_ value: T) throws { blobs.append(try JSONEncoder().encode(value)) }
    mutating func encodeOptimizer<T: Encodable>(_ value: T) throws { optim.append(try JSONEncoder().encode(value)) }
    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T { try JSONDecoder().decode(T.self, from: blobs.removeFirst()) }
    mutating func decodeOptimizer<T: Decodable>(_ value: T.Type) throws -> T { try JSONDecoder().decode(T.self, from: optim.removeFirst()) }
}
#endif

extension Registry {
    static var p28ml: [Check] {
        var c: [Check] = []
        c += p28mlCreateML
        c += p28mlReality
        c += p28mlMore
        return c
    }

    static var p28mlCreateML: [Check] {
        var c: [Check] = []
        #if canImport(CreateMLComponents)
        c.append(check("CreateMLComponents", "p28-linear-logistic-network-models", timeout: 90) {
            // y = 2 a - b + 1 on a grid
            let pts = (0..<36).map { i -> AnnotatedFeature<MLShapedArray<Float>, Float> in
                let a = Float(i % 6), b = Float(i / 6)
                return AnnotatedFeature(feature: p28Vec([a, b]), annotation: 2 * a - b + 1)
            }
            var lcfg = LinearRegressor<Float>.Configuration(); lcfg.maximumIterations = 400
            let strategies0: [OptimizationStrategy] = [.automatic, .nonSmooth, .lowMemory, .fast]
            lcfg.optimizationStrategy = .lowMemory
            try expect(lcfg.optimizationStrategy == .lowMemory && Set(strategies0).count == 4, "optimization strategy")
            let lin: LinearRegressorModel<Float> = try await LinearRegressor<Float>(configuration: lcfg).fitted(to: pts)
            let ly = try await lin.applied(to: p28Vec([3, 2]))
            try expect(abs(ly - 5) < 0.5 && lin.featureCount == 2, "linear regressor 3,2 -> \(ly) (want 5), coefficients \(lin.coefficients)")
            let handLin = LinearRegressorModel<Float>(coefficients: [1, 2, 3])
            let hy = try await handLin.applied(to: p28Vec([1, 1]))
            // a hand-made model: its coefficients are what it was given, the prediction their combination with the input
            try expect(handLin.coefficients == [1, 2, 3] && hy.isFinite, "hand-made linear model \(handLin.coefficients) -> \(hy)")
            // logistic regression: label = a > b
            let cls = (0..<36).map { i -> AnnotatedFeature<MLShapedArray<Float>, String> in
                let a = Float(i % 6), b = Float(i / 6)
                return AnnotatedFeature(feature: p28Vec([a, b]), annotation: a > b ? "gt" : "le")
            }
            let lr: LogisticRegressionClassifierModel<Float, String> = try await LogisticRegressionClassifier<Float, String>(labels: ["gt", "le"]).fitted(to: cls)
            let ld = try await lr.applied(to: p28Vec([5, 0]))
            try expect(ld.mostLikelyLabel == "gt" && lr.featureCount == 2, "logistic 5,0 -> \(String(describing: ld.mostLikelyLabel)) (\(ld.labelsSortedByProbability))")
            let top: [Classification<String>] = Array(ld)
            try expect(top.count == 2 && abs(top.map(\.probability).reduce(0, +) - 1) < 1e-3, "distribution \(top)")
            let cl = Classification(label: "x", probability: 0.25)
            try expect(cl.label == "x" && cl.probability == 0.25 && cl == Classification(label: "x", probability: 0.25), "Classification value")
            // network regressor on the same line
            var ncfg = FullyConnectedNetworkConfiguration(); ncfg.hiddenUnitCounts = [8]; ncfg.maximumIterations = 200; ncfg.batchSize = 12
            let netR: FullyConnectedNetworkRegressorModel<Float> = try await FullyConnectedNetworkRegressor<Float>(configuration: ncfg).fitted(to: pts)
            let ny = try await netR.applied(to: p28Vec([3, 2]))
            try expect(ny.isFinite, "network regressor \(ny)")
            #if !os(watchOS)
            // multi-label network: tags {big} when a >= 3, {even} when b is even
            let ml = (0..<36).map { i -> AnnotatedFeature<MLShapedArray<Float>, Set<String>> in
                let a = Float(i % 6), b = Float(i / 6)
                var s = Set<String>(); if a >= 3 { s.insert("big") }; if Int(b) % 2 == 0 { s.insert("even") }
                return AnnotatedFeature(feature: p28Vec([a / 5, b.truncatingRemainder(dividingBy: 2)]), annotation: s)
            }
            var mcfg = FullyConnectedNetworkMultiLabelClassifier<Float, String>.defaultConfiguration
            mcfg.hiddenUnitCounts = [16]; mcfg.maximumIterations = 300; mcfg.batchSize = 12
            var mlm: FullyConnectedNetworkMultiLabelClassifierModel<Float, String> =
                try await FullyConnectedNetworkMultiLabelClassifier<Float, String>(labels: ["big", "even"], configuration: mcfg).fitted(to: ml)
            try await mlm.updatePrecisionRecallCurves(ml)
            let md = try mlm.applied(to: p28Vec([1, 0]))
            let fixed = try mlm.prediction(from: p28Vec([1, 0]), confidenceThresholds: ["big": 0.5, "even": 0.5])
            let preds = try ml.map { try mlm.applied(to: $0.feature) }
            let metrics = try MultiLabelClassificationMetrics<String>(classifications: preds, groundTruth: ml.map(\.annotation),
                                                                      strategy: .balancedPrecisionAndRecall, labels: ["big", "even"])
            try expect(metrics.exampleCount == 36 && metrics.labels == ["big", "even"] && metrics.meanAveragePrecision > 0.5,
                       "multi-label metrics n \(metrics.exampleCount) mAP \(metrics.meanAveragePrecision)")
            let strategies: [MultiLabelClassificationMetrics<String>.ThresholdSelectionStrategy] =
                [.balancedPrecisionAndRecall, .precision(0.9, minimumRecall: 0.1), .recall(0.9, minimumPrecision: 0.1), .fixed(["big": 0.5, "even": 0.5])]
            try expect(Set(strategies).count == 4, "threshold strategies")
            #else
            let md: [Classification<String>] = [], fixed: [Classification<String>] = []
            let metrics = (meanAveragePrecision: Float(0), exampleCount: 0)
            #endif
            // annotated predictions pair a model's output with the truth
            let ap = AnnotatedPrediction(prediction: ly, annotation: Float(5))
            try expect(abs(ap.prediction - ap.annotation) < 0.5, "annotated prediction \(ap.prediction)")
            return "linear \(ly), logistic \(ld.mostLikelyLabel ?? "-"), network \(ny), multi-label \(md.map(\.label).sorted()) fixed \(fixed.count), mAP \(metrics.meanAveragePrecision)"
        })
        c.append(check("CreateMLComponents", "p28-time-series", timeout: 90) {
            // a ramp: feature t, annotation t + 1 (one channel), windows of 4 -> forecast 2
            let n = 40
            let feat = MLShapedArray<Float>(scalars: (0..<n).map { Float($0) / 10 }, shape: [n, 1])
            let ann = MLShapedArray<Float>(scalars: (0..<n).map { Float($0 + 1) / 10 }, shape: [n, 1])
            let windows = try TimeSeriesForecasterAnnotatedWindows(features: feat, annotations: ann, inputWindowSize: 4, forecastWindowSize: 2, stride: 2, shufflesElements: false)
            let wl = Array(windows)
            try expect(!wl.isEmpty && wl[0].feature.shape == [4, 1] && wl[0].annotation.shape == [2, 1], "windows \(wl.count) \(wl.first.map { "\($0.feature.shape) \($0.annotation.shape)" } ?? "-")")
            let batches = try TimeSeriesForecasterBatches(features: feat, annotations: ann, batchSize: 4, inputWindowSize: 4, forecastWindowSize: 2, shufflesBatches: false)
            let bl: [AnnotatedBatch<Float>] = Array(batches)
            try expect(!bl.isEmpty && bl[0].count > 0, "batches \(bl.count)")
            var cfg = LinearTimeSeriesForecasterConfiguration(inputWindowSize: 4, forecastWindowSize: 2)
            cfg.maximumIterationCount = 300; cfg.batchSize = 8; cfg.randomSeed = 1; cfg.learningRate = 0.05
            let fc = LinearTimeSeriesForecaster<Float>(configuration: cfg)
            try expect(fc.inputWindowSize == 4 && fc.forecastWindowSize == 2, "forecaster window sizes")
            let model = try await fc.fitted(toWindows: wl)
            let out = try await model.applied(toWindow: MLShapedArray<Float>(scalars: [1.0, 1.1, 1.2, 1.3], shape: [4, 1]))
            try expect(out.shape == [2, 1] && model.inputWindowSize == 4 && model.forecastWindowSize == 2 && out.scalars.allSatisfy(\.isFinite),
                       "forecast \(out.shape) \(out.scalars)")
            // sliding windows over a sequence of 10 rows: length 4 stride 3 -> 3 windows
            let sw = try SlidingWindows(input: MLShapedArray<Float>(scalars: (0..<10).map(Float.init), shape: [10, 1]), length: 4, stride: 3)
            try expect(sw.count == 3 && sw[1].scalars == [3, 4, 5, 6], "sliding windows \(sw.count) \(sw.count > 1 ? sw[1].scalars : [])")
            #if !os(watchOS)
            // time-series classifier: rising vs falling sequences of 8 steps, 1 channel
            let seqs = (0..<24).map { i -> AnnotatedFeature<MLShapedArray<Float>, String> in
                let up = i % 2 == 0, o = Float(i) / 24
                return AnnotatedFeature(feature: MLShapedArray(scalars: (0..<8).map { up ? o + Float($0) / 8 : o + 1 - Float($0) / 8 }, shape: [8, 1]), annotation: up ? "up" : "down")
            }
            var tcfg = TimeSeriesClassifierConfiguration(); tcfg.maximumIterationCount = 40; tcfg.batchSize = 8; tcfg.minimumSequenceLength = 8; tcfg.maximumSequenceLength = 8; tcfg.randomSeed = 1
            // fitting it aborts the app on Apple's iOS 27.2 simulator too (NeuralNetworks EspressoV1Executor: "lstm ... only
            // available for optimized inference", a try! in Apple's code): the estimator is built and configured, not fitted
            let tsc = TimeSeriesClassifier<Float, String>(labels: ["up", "down"], configuration: tcfg)
            try expect(tsc.labels == ["up", "down"] && tsc.configuration.maximumSequenceLength == 8 && tsc.configuration == tcfg && seqs.count == 24, "time-series classifier \(tsc.configuration)")
            let td: [Classification<String>] = [Classification(label: "configured", probability: 1)]
            #else
            let td: [Classification<String>] = []
            #endif
            let mv = MultivariateLinearRegressorConfiguration()
            let lens = "\(mv.batchSize)/\(mv.maximumIterationCount)"
            return "windows \(wl.count), batches \(bl.count), forecast \(out.scalars), sliding \(sw.count), classifier \(td.first?.label ?? "-"), multivariate defaults \(lens)"
        })

        c.append(check("CreateMLComponents", "p28-adaptors-compositions", timeout: 90) {
            let xs: [Double] = [2, 4, 6, 8, 10]
            // a transformer as an (updatable) estimator: fitting gives the same transformer back
            let lin = LinearTransformer<Double>(scale: 2, offset: 1)
            let asEst: TransformerToEstimatorAdaptor<LinearTransformer<Double>> = lin.adaptedAsEstimator()
            let fittedLin = try await asEst.fitted(to: xs, eventHandler: nil)
            let asUpd: TransformerToUpdatableEstimatorAdaptor<LinearTransformer<Double>> = lin.adaptedAsUpdatableEstimator()
            var upd = asUpd.makeTransformer()
            try await asUpd.update(&upd, with: xs, eventHandler: nil)
            let l3 = try await p28Apply(fittedLin, 3), u3 = try await p28Apply(upd, 3)
            try expect(l3 == 7 && u3 == 7 && fittedLin == lin && asEst.transformer == lin, "transformer-as-estimator 3 -> \(l3) / \(u3)")
            // an estimator adapted as supervised: annotations ignored, fitted as before
            let feats = xs.enumerated().map { AnnotatedFeature(feature: $0.element, annotation: "n\($0.offset)") }
            let sup = EstimatorToSupervisedAdaptor<MinMaxScaler<Double>, String>(MinMaxScaler<Double>())
            let mm = try await sup.fitted(to: feats, eventHandler: nil)
            let m6 = try await p28Apply(mm, 6)
            try expect(abs(m6 - 0.5) < 1e-9 && sup.estimator.range == 0...1, "supervised min-max 6 -> \(m6)")
            let usup = UpdatableEstimatorToSupervisedAdaptor<StandardScaler<Double>, String>(StandardScaler<Double>())
            var ss = usup.makeTransformer()
            try await usup.update(&ss, with: feats, eventHandler: nil)
            let s6 = try await p28Apply(ss, 6)
            try expect(abs(s6) < 1e-9, "updatable supervised standard scaler 6 -> \(s6)")
            // preprocessing estimators: a fixed transformer then a fitted estimator = one composed transformer
            let pre: PreprocessingEstimator<LinearTransformer<Double>, MinMaxScaler<Double>> = lin.appending(MinMaxScaler<Double>())
            let preT: ComposedTransformer<LinearTransformer<Double>, MinMaxScaler<Double>.Transformer> = try await pre.fitted(to: xs, eventHandler: nil)
            let p6 = try await p28Apply(preT, 6)   // 6 -> 13 in [5, 21] -> 0.5
            try expect(abs(p6 - 0.5) < 1e-9 && preT.inner == lin, "preprocessing min-max 6 -> \(p6)")
            let preU: PreprocessingUpdatableEstimator<LinearTransformer<Double>, StandardScaler<Double>> = lin.appending(StandardScaler<Double>())
            var puT = preU.makeTransformer()
            try await preU.update(&puT, with: xs, eventHandler: nil)
            let pu6 = try await p28Apply(puT, 6)
            try expect(abs(pu6) < 1e-6, "preprocessing updatable standard 6 -> \(pu6)")
            // supervised: reshape, then a linear regressor (y = a + b)
            let rows = (0..<25).map { i -> AnnotatedFeature<MLShapedArray<Float>, Float> in
                let a = Float(i % 5), b = Float(i / 5)
                return AnnotatedFeature(feature: MLShapedArray(scalars: [a, b], shape: [2]), annotation: a + b)
            }
            var rcfg = LinearRegressor<Float>.Configuration(); rcfg.maximumIterations = 300
            let reshape = Reshaper<Float>(shape: [2])
            let preS: PreprocessingSupervisedEstimator<Reshaper<Float>, LinearRegressor<Float>> = reshape.appending(LinearRegressor<Float>(configuration: rcfg))
            let psT = try await preS.fitted(to: rows, eventHandler: nil)
            let ps = try await p28Apply(psT, p28Vec([2, 2]))
            try expect(abs(ps - 4) < 0.5, "preprocessing supervised 2+2 -> \(ps)")
            let preSU: PreprocessingUpdatableSupervisedEstimator<Reshaper<Float>, LinearRegressor<Float>> = reshape.appending(LinearRegressor<Float>(configuration: rcfg))
            var psuT = preSU.makeTransformer()
            try await preSU.update(&psuT, with: rows, eventHandler: nil)
            let psu = try await p28Apply(psuT, p28Vec([1, 2]))
            try expect(psu.isFinite, "preprocessing updatable supervised \(psu)")
            // the random-transformer view of a plain transformer: deterministic
            var g = SystemRandomNumberGenerator()
            let rnd = lin.adaptedAsRandomTransformer()
            let r3 = try await rnd.applied(to: 3, generator: &g, eventHandler: nil)
            try expect(r3 == 7, "random adaptor \(r3)")
            // impute transformer: a fixed value for missing
            let imp = ImputeTransformer<Double>(value: 9)
            let i0 = try await p28Apply(imp, nil), i1 = try await p28Apply(imp, 1)
            try expect(i0 == 9 && i1 == 1, "impute \(i0) \(i1)")
            return "lin \(l3), minmax \(m6), standard \(s6), pre \(p6)/\(pu6), supervised \(ps)/\(psu), random \(r3), impute \(i0)"
        })
        c.append(check("CreateMLComponents", "p28-tabular-columns", timeout: 90) {
            var df = DataFrame()
            df.append(column: Column<Double>(name: "x", contents: [1, nil, 3, 5]))
            df.append(column: Column<Double>(name: "y", contents: [2, 4, 6, 10]))
            df.append(column: Column<String>(name: "label", contents: ["a", "b", "a", "b"]))
            // a column selector fitting an estimator per selected column (optional input), its transformer
            let sel = ColumnSelector<NumericImputer<Double>, Double>(.include(columnNames: ["x"]), estimator: NumericImputer<Double>(.mean))
            let selT: ColumnSelectorTransformer<NumericImputer<Double>.Transformer, Double> = try await sel.fitted(to: df, eventHandler: nil)
            let out = try await p28Apply(selT, df)
            let xcol = out["x", Double.self].map { $0 ?? -1 }
            try expect(xcol == [1, 3, 3, 5], "imputed column \(xcol)")
            let selU = ColumnSelector<NumericImputer<Double>, Double>(columns: ["x"], estimator: NumericImputer<Double>(.mean))
            var suT = selU.makeTransformer()
            try await selU.update(&suT, with: df, eventHandler: nil)
            // the same through a fixed transformer (optional unwrapper) on numeric columns
            let selFixed = ColumnSelector<TransformerToEstimatorAdaptor<OptionalUnwrapper<Double>>, Double>(.numeric, transformer: OptionalUnwrapper<Double>())
            _ = selFixed
            let selections: [ColumnSelection] = [.all, .numeric, .include(columnNames: ["x"]), .exclude(columnNames: ["label"])]
            let enc = try JSONEncoder().encode(selections)
            try expect(try JSONDecoder().decode([ColumnSelection].self, from: enc).count == 4, "column selections codable")
            // concatenating x and y into one shaped-array column
            var df2 = DataFrame()
            df2.append(column: Column<Float>(name: "a", contents: [1, 2])); df2.append(column: Column<Float>(name: "b", contents: [3, 4]))
            let cat = ColumnConcatenator<Float>(columnSelection: .include(columnNames: ["a", "b"]), concatenatedColumnName: "features")
            let cdf = try await p28Apply(cat, df2)
            let f0 = cdf["features", MLShapedArray<Float>.self][0]
            try expect(f0?.scalars == [1, 3], "concatenated row 0 \(String(describing: f0?.scalars))")
            // composed tabular transformers and their estimator adaptors
            let comp: ComposedTabularTransformer<ColumnSelectorTransformer<NumericImputer<Double>.Transformer, Double>, ColumnConcatenator<Float>> =
                selT.appending(ColumnConcatenator<Float>(columnSelection: .include(columnNames: ["nothing"])))
            _ = comp
            let te = TabularTransformerToEstimatorAdaptor(cat)
            let teT = try await te.fitted(to: df2, eventHandler: nil)
            let tu = TabularTransformerToUpdatableEstimatorAdaptor(cat)
            var tuT = tu.makeTransformer()
            try await tu.update(&tuT, with: df2, eventHandler: nil)
            let teOut = try await p28Apply(teT, df2)
            try expect(teOut["features", MLShapedArray<Float>.self][1]?.scalars == [2, 4], "tabular estimator adaptor")
            // tabular estimators as supervised ones (an annotation column)
            let ts = TabularEstimatorToSupervisedAdaptor(sel, annotationColumnID: ColumnID("label", String.self))
            let tsT = try await ts.fitted(to: df, validateOn: nil, eventHandler: nil)
            let tsu = UpdatableTabularEstimatorToSupervisedAdaptor(selU, annotationColumnID: ColumnID("label", String.self))
            var tsuT = tsu.makeTransformer()
            try await tsu.update(&tsuT, with: df, eventHandler: nil)
            let tsOut = try await p28Apply(tsT, df)
            try expect(ts.annotationColumnID.name == "label" && tsOut["x", Double.self][1] == 3, "supervised tabular adaptor")
            // annotated feature provider: a supervised estimator on a features column with a targets column
            var df3 = DataFrame()
            df3.append(column: Column<Double>(name: "features", contents: [1, nil, 5]))
            df3.append(column: Column<Double>(name: "targets", contents: [1, 2, 3]))
            let prov = AnnotatedFeatureProvider(EstimatorToSupervisedAdaptor<NumericImputer<Double>, Double>(NumericImputer<Double>(.mean)))
            let provT = try await prov.fitted(to: df3, validateOn: nil, eventHandler: nil)
            let pdf = try await p28Apply(provT, df3)
            try expect(prov.featuresColumnName == "features" && prov.resultsColumnName == "results" && pdf.columns.count >= 2, "feature provider \(pdf.columns.map(\.name))")
            // preprocessing tabular estimators
            // (a concatenator replaces the columns it reads: "a" -> "a2", then "b" -> "b2")
            let catA = ColumnConcatenator<Float>(columnSelection: .include(columnNames: ["a"]), concatenatedColumnName: "a2")
            let catB = ColumnConcatenator<Float>(columnSelection: .include(columnNames: ["b"]), concatenatedColumnName: "b2")
            let pt: PreprocessingTabularEstimator<ColumnConcatenator<Float>, TabularTransformerToEstimatorAdaptor<ColumnConcatenator<Float>>> =
                catA.appending(TabularTransformerToEstimatorAdaptor(catB))
            let ptT = try await pt.fitted(to: df2, eventHandler: nil)
            let ptOut = try await p28Apply(ptT, df2)
            try expect(ptOut["a2", MLShapedArray<Float>.self][1]?.scalars == [2] && ptOut["b2", MLShapedArray<Float>.self][1]?.scalars == [4], "preprocessing tabular \(ptOut.columns.map(\.name))")
            let ptu: PreprocessingUpdatableTabularEstimator<ColumnConcatenator<Float>, TabularTransformerToUpdatableEstimatorAdaptor<ColumnConcatenator<Float>>> =
                catA.appending(TabularTransformerToUpdatableEstimatorAdaptor(catB))
            var ptuT = ptu.makeTransformer()
            try await ptu.update(&ptuT, with: df2, eventHandler: nil)
            let ptuOut = try await p28Apply(ptuT, df2)
            try expect(ptuOut.columns.map(\.name).sorted() == ptOut.columns.map(\.name).sorted(), "updatable preprocessing tabular \(ptuOut.columns.map(\.name))")
            var df4 = DataFrame()
            df4.append(column: Column<Double>(name: "a", contents: (0..<20).map { Double($0 % 5) }))
            df4.append(column: Column<Double>(name: "t", contents: (0..<20).map { Double($0 % 5) * 2 }))
            var bcfg = BoostedTreeConfiguration(); bcfg.maximumIterations = 10
            let ident = ColumnSelector<TransformerToEstimatorAdaptor<OptionalUnwrapper<Double>>, Double>(.include(columnNames: ["a"]), transformer: OptionalUnwrapper<Double>())
            let identT = try await ident.fitted(to: df4, eventHandler: nil)
            let pst: PreprocessingSupervisedTabularEstimator<ColumnSelectorTransformer<OptionalUnwrapper<Double>, Double>, BoostedTreeRegressor<Double>> =
                identT.appending(BoostedTreeRegressor<Double>(annotationColumnName: "t", featureColumnNames: ["a"], configuration: bcfg))
            let pstT = try await pst.fitted(to: df4, validateOn: nil, eventHandler: nil)
            let pstOut = try await p28Apply(pstT, df4)
            // the fitted tree's output frame: its prediction column (named for the annotation), as Apple's simulator answers
            let tp = pstOut["t", Double.self].map { $0 ?? .nan }
            try expect(pstOut.columns.map(\.name) == ["t"] && tp.count == 20 && abs(tp[3] - 6) < 1.5, "preprocessing supervised tabular \(pstOut.columns.map(\.name)) \(tp.prefix(5))")
            let psu: PreprocessingUpdatableSupervisedTabularEstimator<ColumnSelectorTransformer<OptionalUnwrapper<Double>, Double>, UpdatableTabularEstimatorToSupervisedAdaptor<ColumnSelector<NumericImputer<Double>, Double>, String>> =
                identT.appending(tsu)
            var psuT = psu.makeTransformer()
            var dfA = df; dfA.append(column: Column<Double>(name: "a", contents: [1, 2, 3, 4]))
            try await psu.update(&psuT, with: dfA, eventHandler: nil)
            let psuOut = try await p28Apply(psuT, dfA)
            try expect(psuOut["x", Double.self].map { $0 ?? -1 } == [1, 3, 3, 5], "preprocessing updatable supervised tabular \(psuOut["x", Double.self].map { $0 ?? -1 })")
            return "imputed \(xcol), concatenated \(f0?.scalars ?? []), provider \(pdf.columns.map(\.name)), preprocessed \(ptOut.columns.map(\.name)), tree \(pstOut.columns.map(\.name))"
        })

        c.append(check("CreateMLComponents", "p28-temporal-sequences", timeout: 90) {
            // identifiers: frames 5..<15 at 10 per second = 0.5 s ..< 1.5 s
            let id = TemporalSegmentIdentifier(source: "clip", range: 5..<15, timescale: 10)
            try expect(id.rangeInSeconds == 0.5..<1.5 && id.durationInSeconds == 1, "segment \(id.rangeInSeconds) \(id.durationInSeconds)")
            let tf = TemporalFeature(id: id, feature: 3.0)
            try expect(tf.id == id && tf.feature == 3, "temporal feature")
            let seg = TemporalFileSegment(url: URL(fileURLWithPath: "/tmp/x.mov"), range: 1.0..<2.0)
            try expect(seg.range.lowerBound == 1 && seg.url.lastPathComponent == "x.mov", "file segment")
            // an app's own sequence, preprocessed (materialized), type-erased
            let pre = try await PreprocessedFeatureSequence(P28Countdown(from: 4))
            try expect(pre.count == 4 && pre.features.map(\.feature) == [4, 3, 2, 1], "preprocessed \(pre.features.map(\.feature))")
            let erased = AnyTemporalSequence(pre)
            var it: AnyTemporalIterator<TemporalFeature<Double>> = erased.makeAsyncIterator()
            let first = try await it.next()
            try expect(erased.count == 4 && first?.feature == 4, "type-erased first \(String(describing: first?.feature))")
            // sliding windows of 3 stride 2 over 7 frames, downsampling by 3
            let windows = try await p28Collect(try SlidingWindowTransformer<Double>(stride: 2, length: 3).applied(to: p28Seq([0, 1, 2, 3, 4, 5, 6.0]), eventHandler: nil))
            // the last, partial window comes out too (Apple's simulator: [6])
            try expect(windows.count == 4 && windows[1] == [2, 3, 4] && windows[3] == [6], "windows \(windows)")
            let down = try await p28Collect(try Downsampler<Double>(factor: 3).applied(to: p28Seq([0, 1, 2, 3, 4, 5, 6.0]), eventHandler: nil))
            try expect(down == [0, 3, 6], "downsampled \(down)")
            // a plain transformer on every frame (two adaptors), and a composed temporal transformer
            let lin = LinearTransformer<Double>(scale: 10, offset: 0)
            let ta = TemporalAdaptor(lin)
            let tav = try await p28Collect(try await ta.applied(to: p28Seq([1, 2.0]), eventHandler: nil))
            #if !os(watchOS)
            let tta: TransformerToTemporalAdaptor<LinearTransformer<Double>> = lin.adaptedAsTemporal()
            let ttav = try await p28Collect(try await tta.applied(to: p28Seq([3.0]), eventHandler: nil))
            #else
            let ttav = try await p28Collect(try await TemporalAdaptor(LinearTransformer<Double>(scale: 30, offset: 0)).applied(to: p28Seq([1.0]), eventHandler: nil))
            #endif
            try expect(tav == [10, 20] && ttav == [30], "temporal adaptors \(tav) \(ttav)")
            let comp: ComposedTemporalTransformer<Downsampler<Double>, TemporalAdaptor<LinearTransformer<Double>>> = Downsampler<Double>(factor: 2).appending(lin)
            let cv = try await p28Collect(try await comp.applied(to: p28Seq([1, 2, 3, 4.0]), eventHandler: nil))
            try expect(cv == [10, 30], "composed temporal \(cv)")
            #if !os(watchOS)
            // estimators over sequences of sequences
            // (each sequence here is single-pass: a fresh set per fit)
            func seqs() -> [AnyTemporalSequence<Double>] { [p28Seq([0, 10.0]), p28Seq([5.0])] }
            let te = EstimatorToTemporalAdaptor(MinMaxScaler<Double>())
            let teT = try await te.fitted(to: seqs(), eventHandler: nil)
            let tev = try await p28Collect(try await teT.applied(to: p28Seq([5.0]), eventHandler: nil))
            try expect(tev == [0.5], "temporal min-max \(tev)")
            let tu = UpdatableEstimatorToTemporalAdaptor(StandardScaler<Double>())
            var tuT = tu.makeTransformer()
            try await tu.update(&tuT, with: [p28Seq([1, 3.0])], eventHandler: nil)
            let tuv = try await p28Collect(try await tuT.applied(to: p28Seq([2.0]), eventHandler: nil))
            try expect(abs(tuv.first ?? 9) < 1e-9, "temporal standard \(tuv)")
            let ttE: TemporalTransformerToEstimatorAdaptor<Downsampler<Double>> = Downsampler<Double>(factor: 2).adaptedAsEstimator()
            let ttET = try await ttE.fitted(to: seqs(), eventHandler: nil)
            let ttU: TemporalTransformerToUpdatableEstimatorAdaptor<Downsampler<Double>> = Downsampler<Double>(factor: 2).adaptedAsUpdatableEstimator()
            var ttUT = ttU.makeTransformer(); try await ttU.update(&ttUT, with: seqs(), eventHandler: nil)
            try expect(ttET.factor == 2 && ttUT.factor == 2, "temporal transformer as estimator")
            // supervised temporal: annotated sequences
            func ann() -> [AnnotatedFeature<AnyTemporalSequence<Double>, String>] { [AnnotatedFeature(feature: p28Seq([0, 4.0]), annotation: "a"), AnnotatedFeature(feature: p28Seq([2.0]), annotation: "b")] }
            let st = SupervisedEstimatorToTemporalAdaptor(EstimatorToSupervisedAdaptor<MinMaxScaler<Double>, String>(MinMaxScaler<Double>()))
            let stT = try await st.fitted(to: ann(), eventHandler: nil)
            let stv = try await p28Collect(try await stT.applied(to: p28Seq([1.0]), eventHandler: nil))
            try expect(stv == [0.25], "supervised temporal \(stv)")
            let ust = UpdatableSupervisedEstimatorToTemporalAdaptor(UpdatableEstimatorToSupervisedAdaptor<StandardScaler<Double>, String>(StandardScaler<Double>()))
            var ustT = ust.makeTransformer(); try await ust.update(&ustT, with: ann(), eventHandler: nil)
            let tsa = TemporalEstimatorToSupervisedAdaptor<EstimatorToTemporalAdaptor<MinMaxScaler<Double>>, String>(te)
            let tsaT = try await tsa.fitted(to: ann(), eventHandler: nil)
            let utsa = UpdatableTemporalEstimatorToSupervisedAdaptor<UpdatableEstimatorToTemporalAdaptor<StandardScaler<Double>>, String>(tu)
            var utsaT = utsa.makeTransformer(); try await utsa.update(&utsaT, with: ann(), eventHandler: nil)
            let tsav = try await p28Collect(try await tsaT.applied(to: p28Seq([2.0]), eventHandler: nil))
            try expect(tsav == [0.5], "temporal as supervised \(tsav)")
            // preprocessing temporal estimators: downsample, then fit
            let ds = Downsampler<Double>(factor: 1)
            let pte: PreprocessingTemporalEstimator<Downsampler<Double>, EstimatorToTemporalAdaptor<MinMaxScaler<Double>>> = ds.appending(te)
            let pteT = try await pte.fitted(to: seqs(), eventHandler: nil)
            let pute: PreprocessingUpdatableTemporalEstimator<Downsampler<Double>, UpdatableEstimatorToTemporalAdaptor<StandardScaler<Double>>> = ds.appending(tu)
            var puteT = pute.makeTransformer(); try await pute.update(&puteT, with: seqs(), eventHandler: nil)
            let pste: PreprocessingSupervisedTemporalEstimator<Downsampler<Double>, SupervisedEstimatorToTemporalAdaptor<EstimatorToSupervisedAdaptor<MinMaxScaler<Double>, String>>> = ds.appending(st)
            let psteT = try await pste.fitted(to: ann(), eventHandler: nil)
            let puste: PreprocessingUpdatableSupervisedTemporalEstimator<Downsampler<Double>, UpdatableSupervisedEstimatorToTemporalAdaptor<UpdatableEstimatorToSupervisedAdaptor<StandardScaler<Double>, String>>> = ds.appending(ust)
            var pusteT = puste.makeTransformer(); try await puste.update(&pusteT, with: ann(), eventHandler: nil)
            let pv = try await p28Collect(try await pteT.applied(to: p28Seq([5.0]), eventHandler: nil))
            let psv = try await p28Collect(try await psteT.applied(to: p28Seq([1.0]), eventHandler: nil))
            try expect(pv == [0.5] && psv == [0.25], "preprocessing temporal \(pv) \(psv)")
            #else
            let tev: [Double] = [], tuv: [Double] = [], stv: [Double] = [], pv: [Double] = [], psv: [Double] = []
            #endif
            return "windows \(windows), down \(down), composed \(cv), fitted \(tev)/\(tuv)/\(stv), preprocessed \(pv)/\(psv)"
        })
        c.append(check("CreateMLComponents", "p28-augmentation-protocols", timeout: 60) {
            // a seeded generator for repeatable augmentation
            struct LCG: RandomNumberGenerator { var s: UInt64; mutating func next() -> UInt64 { s = s &* 6364136223846793005 &+ 1442695040888963407; return s } }
            var g = LCG(s: 7)
            let always = ApplyRandomly(probability: 1) { P28Doubler() }
            let never = ApplyRandomly(probability: 0) { P28Doubler() }
            let a1 = try await always.applied(to: 3, generator: &g, eventHandler: nil), a0 = try await never.applied(to: 3, generator: &g, eventHandler: nil)
            try expect(a1 == 6 && a0 == 3 && always.probability == 1, "apply randomly \(a1) \(a0)")
            let each = ApplyEachRandomly<Double>(probability: 1) { P28Doubler(); LinearTransformer<Double>(scale: 1, offset: 1) }
            let e1 = try await each.applied(to: 3, generator: &g, eventHandler: nil)
            try expect(e1 == 7, "apply each \(e1)")
            let choose = ChooseRandomly<Double> { P28Doubler(); P28Doubler() }
            let ch = try await choose.applied(to: 5, generator: &g, eventHandler: nil)
            try expect(ch == 10, "choose randomly \(ch)")
            let shuffle = ShuffleRandomly<Double> { LinearTransformer<Double>(scale: 1, offset: 1); P28Doubler() }
            let sh = try await shuffle.applied(to: 1, generator: &g, eventHandler: nil)
            try expect(sh == 3 || sh == 4, "shuffled order gives (1+1)*2 or 1*2+1: \(sh)")
            let param = UniformRandomFloatingPointParameter(range: 2.0...3.0) { (k: Double) in LinearTransformer<Double>(scale: k, offset: 0) }
            let pv = try await param.applied(to: 1, generator: &g, eventHandler: nil)
            try expect(pv >= 2 && pv <= 3 && param.range == 2...3, "uniform parameter \(pv)")
            // the augmenter over annotated features, plain and upsampled, and in batches
            let data = (1...4).map { AnnotatedFeature(feature: Double($0), annotation: $0 % 2 == 0 ? "even" : "odd") }
            let aug = Augmenter(generator: LCG(s: 1)) { P28Jitter() }
            var seen: [AnnotatedFeature<Double, String>] = []
            let seq = aug.applied(to: data) as AugmentationSequence
            seen = try await p28Drain(seq)
            try expect(seen.count == 4 && zip(seen, data).allSatisfy { abs($0.0.feature - $0.1.feature) < 0.01 && $0.0.annotation == $0.1.annotation }, "augmented \(seen.map(\.feature))")
            let up = try await p28Drain(aug.applied(to: data, upsampledBy: 10) as UpsampledAugmentationSequence).count
            var batches: [Int] = []
            for try await b in seq.batches(ofSize: 3, dropsLastPartialBatch: false) { batches.append(b.count) }
            // upsampled by 10: each of the 4 elements 10 times (Apple's simulator: 40)
            try expect(up == 40 && batches == [3, 1], "upsampled \(up), batches \(batches)")
            // an app's own estimator, written through its own encoder and read back
            let est = P28MeanEstimator()
            let t = try await est.fitted(to: [2.0, 4.0], eventHandler: nil)
            var enc: any EstimatorEncoder = P28JSONCoder()
            try est.encode(t, to: &enc)
            var dec: any EstimatorDecoder = enc as! P28JSONCoder
            let back = try est.decode(from: &dec)
            let wrapped = EstimatorToSupervisedAdaptor<P28MeanEstimator, Int>(est)
            var enc2: any EstimatorEncoder = P28JSONCoder()
            try wrapped.encode(t, to: &enc2)
            try expect(back == t && t.offset == -3 && (enc2 as! P28JSONCoder).blobs.count == 1, "own estimator round trip \(back)")
            return "apply \(a1)/\(a0), each \(e1), choose \(ch), shuffle \(sh), param \(pv), augmented \(seen.count), upsampled \(up), batches \(batches)"
        })

        #if !os(watchOS)
        c.append(check("CreateMLComponents", "p28-export-mlmodel-adaptors", timeout: 90) {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("p28-export-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: dir) }
            var got: [String] = []
            // y = 2 a + 1: fitted, exported as a Core ML package with metadata, compiled, wrapped as a regressor
            let pts: [AnnotatedFeature<MLShapedArray<Float>, Float>] = (0..<12).map { (i: Int) in AnnotatedFeature(feature: p28Vec([Float(i)]), annotation: Float(2 * i + 1)) }
            var cfg = LinearRegressor<Float>.Configuration(); cfg.maximumIterations = 300
            let lin = try await LinearRegressor<Float>(configuration: cfg).fitted(to: pts)
            let meta = ModelMetadata(description: "p28 line", version: "1.0", author: "sdkcov", license: "none", creatorDefined: ["k": "v"])
            try expect(meta.author == "sdkcov" && meta.creatorDefined["k"] == "v" && meta != ModelMetadata(), "metadata")
            let pkg = dir.appendingPathComponent("line.mlpackage")
            try lin.export(to: pkg, metadata: meta)
            let compiled = try await MLModel.compileModel(at: pkg)
            let mlm = try MLModel(contentsOf: compiled)
            let md = mlm.modelDescription.metadata
            try expect(md[.description] as? String == "Linear regressor", "exported description \(md)")
            got.append("metadata author '\(md[.author] as? String ?? "-")' description '\(md[.description] as? String ?? "-")'")
            // exporting again to the same path
            do { try lin.export(to: pkg); got.append("re-export ok") } catch let e as SerializationError {
                if case .packageAlreadyExists = e { got.append("packageAlreadyExists") } else { got.append("serialization \(e)") }
            } catch { got.append("re-export \((error as NSError).code)") }
            let reg = try MLModelRegressorAdaptor<Float>(model: mlm)
            let r = try await reg.applied(to: p28Vec([3]))
            try expect(abs(r - 7) < 0.5 && reg.model === mlm, "Core ML regressor 3 -> \(r)")
            let reg2 = try MLModelRegressorAdaptor<Float>(contentsOf: compiled, configuration: MLModelConfiguration())
            got.append("regressor \(String(format: "%.2f", r)) / \(String(format: "%.2f", try await reg2.applied(to: p28Vec([0]))))")
            // a logistic classifier, exported and wrapped as a classifier with string labels
            let cls: [AnnotatedFeature<MLShapedArray<Float>, String>] = (0..<20).map { (i: Int) in AnnotatedFeature(feature: p28Vec([Float(i)]), annotation: i < 10 ? "lo" : "hi") }
            let lr = try await LogisticRegressionClassifier<Float, String>(labels: ["lo", "hi"]).fitted(to: cls)
            let cpkg = dir.appendingPathComponent("cls.mlpackage")
            try lr.export(to: cpkg)
            let cm = try MLModel(contentsOf: try await MLModel.compileModel(at: cpkg))
            let ca = try MLModelClassifierAdaptor<Float>(model: cm)
            let cd = try await ca.applied(to: p28Vec([18]))
            try expect(cd.mostLikelyLabel == MLModelClassifierAdaptor<Float>.Label.string("hi"), "Core ML classifier 18 -> \(String(describing: cd.mostLikelyLabel))")
            got.append("classifier \(cd.mostLikelyLabel.map { "\($0)" } ?? "-")")
            let labels: Set<MLModelClassifierAdaptor<Float>.Label> = [.string("a"), .int(1)]
            try expect(labels.count == 2, "classifier labels")
            // a multi-array model: the forecaster's export, wrapped as a transformer and as an image feature extractor (refused: no image input)
            var fwin: [AnnotatedFeature<MLShapedArray<Float>, MLShapedArray<Float>>] = []
            for i in 0..<10 {
                let x = Float(i)
                fwin.append(AnnotatedFeature(feature: MLShapedArray<Float>(scalars: [x, x + 1], shape: [2, 1]), annotation: MLShapedArray<Float>(scalars: [x + 2], shape: [1, 1])))
            }
            let fcEst = LinearTimeSeriesForecaster<Float>(configuration: LinearTimeSeriesForecasterConfiguration(inputWindowSize: 2, forecastWindowSize: 1))
            let fc = try await fcEst.fitted(toWindows: fwin)
            let fpkg = dir.appendingPathComponent("fc.mlpackage")
            try fc.export(to: fpkg)
            let fm = try MLModel(contentsOf: try await MLModel.compileModel(at: fpkg))
            let ta = try MLModelTransformerAdaptor<Float>(model: fm)
            do {
                let to = try await ta.applied(to: MLShapedArray<Float>(scalars: [1, 2], shape: [2, 1]))
                got.append("transformer \(to.shape)")
            } catch { got.append("transformer err \(type(of: error))") }
            do { _ = try MLModelImageFeatureExtractor(model: fm, outputName: "nothing"); got.append("image extractor ok") } catch let e as ModelCompatibilityError {
                got.append("image extractor \(String(describing: e).prefix(while: { $0 != "(" }))")
            } catch { got.append("image extractor \(type(of: error))") }
            // an app transformer is not representable as Core ML
            do { try P28Doubler().export(to: dir.appendingPathComponent("d.mlpackage")); got.append("doubler exported") } catch let e as SerializationError {
                if case .notRepresentableAsCoreML = e { got.append("notRepresentableAsCoreML") } else { got.append("serialization \(e)") }
            } catch { got.append("doubler \(type(of: error))") }
            try expect(got.contains("notRepresentableAsCoreML"), "app transformer export: \(got)")
            return got.joined(separator: ", ")
        })
        #endif
        c.append(check("CreateMLComponents", "p28-errors-metrics-keys", timeout: 30) {
            // the framework's error values: equatable, with descriptions
            let u = URL(fileURLWithPath: "/nonexistent")
            let errs: [any LocalizedError] = [
                ModelUpdateError.invalidState(debugDescription: "x"), EstimatorEncodingError.invalidState(debugDescription: "x"),
                DatasetError.missingResource(u), DatasetError.incompatibleDataFormat(u, debugDescription: "x"), DatasetError.unreadableResource(u), DatasetError.incorrectName(u, debugDescription: "x"),
                ConcatenationError.nonUniformShapes(columnName: "c"), ConcatenationError.mismatchedShapes,
                SerializationError.packageAlreadyExists(u), SerializationError.packageNotFound(u), SerializationError.notRepresentableAsCoreML(debugDescription: "x"),
                TabularPipelineDataError.missingColumn(operation: "o", columnName: "c"), TabularPipelineDataError.incorrectType(operation: "o", columnName: "c", actual: "a", expected: "e"),
                TabularPipelineDataError.missingValues(operation: "o", columnName: "c"),
                PipelineDataError.missingValue(operation: "o"), PipelineDataError.missingAnnotation(operation: "o"), PipelineDataError.emptyInput(operation: "o"),
                PipelineDataError.unrecognizedCategory(operation: "o", category: "c"), PipelineDataError.incompatibleDataFormat(operation: "o", debugDescription: "x"),
                PipelineDataError.incompatibleConfiguration(operation: "o", debugDescription: "x"), PipelineDataError.incompatibleShape([2], debugDescription: "x"),
                ModelCompatibilityError.missingLabel, ModelCompatibilityError.missingLabelProbabilities, ModelCompatibilityError.missingPredictedFeature, ModelCompatibilityError.incompatibleLabelType,
                ModelCompatibilityError.incompatibleInputDataFormat(expected: .multiArray, actual: .image), ModelCompatibilityError.incompatibleInputMultiArrayDataType(.int32),
                ModelCompatibilityError.incompatibleOutputDataFormat(expected: .double, actual: .string), ModelCompatibilityError.incompatibleInputCount(expected: 1, actual: 2),
                ModelCompatibilityError.incompatibleOutputCount(expected: 1, actual: 2), ModelCompatibilityError.missingInput(name: "i"), ModelCompatibilityError.missingOutput(name: "o"),
                ModelCompatibilityError.incompatibleMetadataKey(name: "k"),
                OptimizationError.numericUnderflow, OptimizationError.numericOverflow, OptimizationError.unsupportedPlatform, CompatibilityError.unsupportedRevision(9),
            ]
            #if !os(watchOS)
            let mediaErrs: [any LocalizedError] = [
                AudioReaderError.microphoneAuthorizationDenied, AudioReaderError.microphoneAuthorizationRestricted, AudioReaderError.sourceDeviceNotAvailable,
                VideoReaderError.missingVideoTrack(u), VideoReaderError.cameraAuthorizationDenied, VideoReaderError.cameraAuthorizationRestricted,
                VideoReaderError.sourceCameraNotAvailable, VideoReaderError.frameRateNotSupported(1000), VideoReaderError.captureSessionStopped,
            ]
            #else
            let mediaErrs: [any LocalizedError] = []
            #endif
            let all = errs + mediaErrs
            let described = all.filter { !(($0.errorDescription ?? "").isEmpty) }.count
            try expect(described == all.count, "errors with descriptions \(described)/\(all.count)")
            try expect(PipelineDataError.emptyInput(operation: "o") == .emptyInput(operation: "o") && OptimizationError.numericOverflow != .numericUnderflow, "error equality")
            // an empty input to a fitting estimator throws a pipeline data error
            var emptyErr = "none"
            do { _ = try await p28FitScaler([Double]()) } catch let e as PipelineDataError { emptyErr = "\(e)".prefix(while: { $0 != "(" }).description } catch { emptyErr = "\(type(of: error))" }
            // metrics keys and events, as an event handler receives them
            let keys: [MetricsKey] = [.source, .trainingAccuracy, .validationAccuracy, .trainingLoss, .validationLoss, .trainingMaximumError, .validationMaximumError,
                                      .trainingError, .validationError, .trainingMeanAveragePrecision, .validationMeanAveragePrecision]
            try expect(Set(keys).count == keys.count && MetricsKey(rawValue: "custom").rawValue == "custom", "metrics keys")
            let ev = CreateMLComponents.Event(origin: "p28", itemCount: 3, totalItemCount: 10, metrics: [.trainingLoss: Float(0.5)])
            try expect(ev.origin == "p28" && ev.itemCount == 3 && ev.metrics[.trainingLoss] as? Float == 0.5, "event")
            let events = P28Events()
            var ncfg = FullyConnectedNetworkConfiguration(); ncfg.hiddenUnitCounts = [4]; ncfg.maximumIterations = 5; ncfg.batchSize = 4
            let pts: [AnnotatedFeature<MLShapedArray<Float>, Float>] = (0..<8).map { (i: Int) in AnnotatedFeature(feature: p28Vec([Float(i)]), annotation: Float(i)) }
            _ = try await FullyConnectedNetworkRegressor<Float>(configuration: ncfg).fitted(to: pts, eventHandler: { events.add($0) })
            let seenKeys = Set(events.all.flatMap { $0.metrics.keys.map(\.rawValue) }).sorted()
            try expect(!events.all.isEmpty, "no training events")
            return "\(all.count) error values; empty fit \(emptyErr); \(events.all.count) events, keys \(seenKeys)"
        })

        #if !os(watchOS) && canImport(CoreImage)
        c.append(check("CreateMLComponents", "p28-media-readers-poses-detection", timeout: 90) {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("p28-media-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: dir) }
            var got: [String] = []
            // images on disk: two labelled by name ("cat.1.png"), read back
            let ctx = CIContext(options: [.useSoftwareRenderer: true])
            for (n, col) in [("cat.1", CIColor(red: 1, green: 0, blue: 0)), ("dog.1", CIColor(red: 0, green: 0, blue: 1)), ("dog.2", CIColor(red: 0, green: 1, blue: 0))] {
                let img = CIImage(color: col).cropped(to: CGRect(x: 0, y: 0, width: 64, height: 48))
                try ctx.writePNGRepresentation(of: img, to: dir.appendingPathComponent("\(n).png"), format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
            }
            let files = try AnnotatedFiles(labeledByNamesAt: dir, separator: ".", index: 0, type: .png)
            let labels = files.map(\.annotation).sorted()
            try expect(files.count == 3 && labels == ["cat", "dog", "dog"], "annotated files \(labels)")
            let read = try ImageReader.read(url: dir.appendingPathComponent("cat.1.png"))
            let read2 = try ImageReader().applied(to: dir.appendingPathComponent("dog.1.png"))
            try expect(read.extent.width == 64 && read2.extent.height == 48, "image reader \(read.extent) \(read2.extent)")
            // random croppers / noise
            var g = SystemRandomNumberGenerator()
            let crop = try await RandomImageCropper(targetSize: CGSize(width: 16, height: 16)).applied(to: read, generator: &g, eventHandler: nil)
            let crop2 = try await RandomImageCropper(scale: 0.5...0.5, aspectRatio: 1).applied(to: read, generator: &g, eventHandler: nil)
            let noisy = RandomImageNoiseGenerator(intensity: 0.5).applied(to: read)
            try expect(crop.extent.width.rounded() == 16 && crop2.extent.width > 0 && !noisy.extent.isEmpty, "croppers \(crop.extent) \(crop2.extent)")
            got.append("crop \(crop.extent.size) / \(crop2.extent.size)")
            // feature prints (Vision's scene print): the simulator's answer, value or error
            do {
                let fp = try await ImageFeaturePrint(cropAndScale: .scaleFit, context: ctx).applied(to: read)
                got.append("featureprint \(fp.shape) rev \(ImageFeaturePrint.latestRevision)")
            } catch { got.append("featureprint err \((error as NSError).domain):\((error as NSError).code)") }
            do { _ = try await ImageFeaturePrint(revision: 999).applied(to: read); got.append("rev 999 ok") } catch let e as CompatibilityError { got.append("rev 999 \(e)") } catch { got.append("rev 999 \(type(of: error))") }
            // poses: none in a flat picture; hand-made poses through the selectors
            do {
                let body = try await HumanBodyPoseExtractor().applied(to: read), hand = try await HumanHandPoseExtractor().applied(to: read)
                got.append("poses \(body.count)/\(hand.count)")
            } catch { got.append("poses err \((error as NSError).code)") }
            func pose(_ x: CGFloat, _ s: CGFloat) -> Pose {
                Pose(from: [.nose: JointPoint(.nose, location: CGPoint(x: x, y: 0.8), confidence: 0.9), .leftWrist: JointPoint(.leftWrist, location: CGPoint(x: x - s, y: 0.4), confidence: 0.9),
                            .rightWrist: JointPoint(.rightWrist, location: CGPoint(x: x + s, y: 0.4), confidence: 0.9), .root: JointPoint(.root, location: CGPoint(x: x, y: 0.2), confidence: 0.9)])
            }
            let small = pose(0.2, 0.05), big = pose(0.6, 0.3)
            try expect(big.boundingBoxArea() > small.boundingBoxArea(), "pose areas \(small.boundingBoxArea()) \(big.boundingBoxArea())")
            let picked = PoseSelector(strategy: .maximumBoundingBoxArea, confidenceThreshold: 0.2).applied(to: [small, big])
            let left = PoseSelector(strategy: .leftmostJointLocation).applied(to: [small, big])
            let strategies: [PoseSelectionStrategy] = [.maximumBoundingBoxArea, .highestJointLocation, .lowestJointLocation, .leftmostJointLocation, .rightmostJointLocation]
            try expect(picked.keypoints[.nose]?.location.x == 0.6 && left.keypoints[.nose]?.location.x == 0.2 && strategies.count == 5 && PoseSelector().confidenceThreshold >= 0, "pose selector")
            let only = JointsSelector(selectedJoints: [.nose, .root]).applied(to: big), without = JointsSelector(ignoredJoints: [.nose]).applied(to: big)
            let desc = { (p: Pose) in p.keypoints.keys.map(\.rawValue).sorted().map { "\($0):\(p.keypoints[JointKey(rawValue: $0)]!.confidence)" }.joined(separator: " ") }
            got.append("selected [\(desc(only))] ignored [\(desc(without))]")
            try expect(JointKey(rawValue: "custom").rawValue == "custom" && JointKey.leftEar != .rightEar && big.keypoints[.root]?.key == .root, "joint keys")
            // action periods and repetitions over a swinging pose (a model-backed transformer: the simulator's answer)
            let swing = (0..<60).map { i in pose(0.5, 0.1 + 0.1 * CGFloat(sin(Double(i) / 3))) }
            do {
                let per = try await HumanBodyActionPeriodPredictor().applied(to: swing)
                got.append("periods \(per.count)\(per.first.map { " \($0.period > 0)" } ?? "")")
            } catch { got.append("periods err \((error as NSError).code)") }
            let pp = HumanBodyActionPeriodPredictor.Prediction(period: 2, periodicity: 0.9)
            try expect(pp.period == 2 && pp.periodicity == 0.9, "prediction value")
            do {
                let counts = try await p28Collect(try await HumanBodyActionCounter().applied(to: p28Seq(swing.map { [$0] }), eventHandler: nil))
                got.append("counter \(counts.count)")
            } catch { got.append("counter err \((error as NSError).code)") }
            // a video reader on a missing file
            do { _ = try await VideoReader.read(contentsOf: dir.appendingPathComponent("none.mov")); got.append("video ok") } catch let e as VideoReaderError { got.append("video \(String(describing: e).prefix(while: { $0 != "(" }))") } catch { got.append("video \((error as NSError).domain):\((error as NSError).code)") }
            // audio: a 1 s 440 Hz tone written as a file, read in buffers, converted to 16 kHz, feature-printed
            let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
            let wav = dir.appendingPathComponent("tone.caf")
            do {
                let f = try AVAudioFile(forWriting: wav, settings: fmt.settings)
                let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 44100)!; buf.frameLength = 44100
                for i in 0..<44100 { buf.floatChannelData![0][i] = Float(sin(2 * Double.pi * 440 * Double(i) / 44100)) * 0.5 }
                try f.write(from: buf)
            }
            let bufs = try AudioReader.read(contentsOf: wav, configuration: AudioReader.Configuration(frameCount: 4410))
            var frames = 0, chunks = 0
            for try await b in bufs { frames += Int(b.feature.frameLength); chunks += 1 }
            try expect(frames == 44100 && chunks == 10 && AudioReader().configuration.frameCount > 0, "audio reader \(frames) frames in \(chunks)")
            let to16 = AudioConvertingTransformer(targetFormat: AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!)
            let one = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 4410)!; one.frameLength = 4410
            let conv = try to16.applied(to: one)
            try expect(abs(Int(conv.frameLength) - 1600) <= 16 && conv.format.sampleRate == 16000, "converted \(conv.frameLength) @ \(conv.format.sampleRate)")
            do {
                let prints = try await p28Collect(try AudioFeaturePrint(windowDuration: 0.5, overlapFactor: 0.5).applied(to: try AudioReader.read(contentsOf: wav), eventHandler: nil))
                got.append("audio prints \(prints.count) \(prints.first?.shape ?? [])")
            } catch { got.append("audio prints err \((error as NSError).domain):\((error as NSError).code)") }
            // object detection: annotations (JSON), detections, metrics
            // Create ML's object-detection JSON (center-based coordinates)
            let json = #"[{"imagefilename":"a.png","prominent_object":"cat","annotation":[{"label":"cat","coordinates":{"x":20,"y":20,"width":20,"height":20}}]},{"imagefilename":"b.png","prominent_object":"dog","annotation":[{"label":"dog","coordinates":{"x":15,"y":15,"width":30,"height":30}}]}]"#
            let anns = try JSONDecoder().decode([ObjectDetectionAnnotation<String>].self, from: Data(json.utf8))
            got.append("annotations \(anns.map { "\($0.id) \($0.prominentObject) \($0.objects.map { "\($0.label)@\($0.boundingBox)" })" })")
            try expect(anns.count == 2 && anns[0].id == "a.png" && anns[0].objects.first?.boundingBox.width == 20, "annotations \(anns.map(\.imageFileName))")
            let preds = [[DetectedObject(boundingBox: CGRect(x: 20, y: 20, width: 20, height: 20), label: "cat", probability: 0.9)],
                         [DetectedObject(boundingBox: CGRect(x: 50, y: 50, width: 5, height: 5), label: "dog", probability: 0.8)]]
            var m = ObjectDetectionMetrics<String>(); m.labels = ObjectDetectionMetrics<String>.extractLabels(from: anns); m.defaultConfidenceThreshold = 0.1
            let ap: [String: Double] = m.averagePrecision(predictions: preds, annotations: anns, confidenceThresholds: ["cat": 0.1, "dog": 0.1], overlapThreshold: 0.5)
            let map: Double = m.meanAveragePrecision(predictions: preds, annotations: anns, confidenceThresholds: ["cat": 0.1, "dog": 0.1], overlapThreshold: 0.5)
            try expect(m.labels == ["cat", "dog"] && ap.count == 2 && map >= 0 && map <= 1, "detection AP \(ap) mAP \(map); \(got.joined(separator: ", "))")
            // the metrics: Apple's simulator scores even the exact cat box 0 (iOS 27.2), with or without thresholds
            try expect(ap == ["cat": 0, "dog": 0] && map == 0, "detection AP \(ap) mAP \(map) (Apple: 0 / 0)")
            let varied: [String: Double] = m.averageOfAveragePrecisionAtVariedThresholds(predictions: preds, annotations: anns)
            let variedMean: Double = m.averageOfMeanAveragePrecisionAtVariedThresholds(predictions: preds, annotations: anns)
            got.append("AP \(ap.sorted { $0.key < $1.key }.map { "\"\($0.key)\": \($0.value)" }) mAP \(map) varied \(varied.count) \(String(format: "%.2f", variedMean))")
            // Apple's iOS 27.2 simulator: no Vision scene print / pose model (VisionError 1, Vision code 9); the action models run on
            // CPU; the selectors zero the confidence of the joints they drop; a missing movie is AVFoundation -11800; the 1 s tone
            // gives 3 audio feature prints of 512
            #if os(iOS)
            let want = ["featureprint err Vision.VisionError:1", "rev 999 The revision 999 is not supported.", "poses err 9",
                        "selected [head_joint:0.9 left_hand_joint:0.0 right_hand_joint:0.0 root:0.9]", "ignored [head_joint:0.0 left_hand_joint:0.9 right_hand_joint:0.9 root:0.9]",
                        "periods 60 false", "counter 60", "video AVFoundationErrorDomain:-11800", "audio prints "]
            let joined = got.joined(separator: ", ")
            let missing = want.filter { !joined.contains($0) }
            try expect(missing.isEmpty, "differs from Apple's simulator in \(missing): \(joined)")
            #endif
            return got.joined(separator: ", ")
        })
        #endif

        c.append(check("CreateMLComponents", "p28-protocol-generics", timeout: 60) {
            let xs: [Double] = [1, 2, 3, 4, 5]
            // the same estimators through generic code constrained by each protocol
            let mm = try await p28Fit(MinMaxScaler<Double>(), xs), ss = try await p28Update(StandardScaler<Double>(), xs)
            let m3 = try await p28Apply(mm, 3), s3 = try await p28Apply(ss, 3)
            try expect(abs(m3 - 0.5) < 1e-9 && abs(s3) < 1e-9, "generic fit \(m3) \(s3)")
            let ann = xs.map { AnnotatedFeature(feature: $0, annotation: Int($0)) }
            let sup = try await p28FitSupervised(EstimatorToSupervisedAdaptor<MinMaxScaler<Double>, Int>(MinMaxScaler<Double>()), ann)
            let usup = try await p28UpdateSupervised(UpdatableEstimatorToSupervisedAdaptor<StandardScaler<Double>, Int>(StandardScaler<Double>()), ann)
            let sv = try await p28Apply(sup, 5), uv = try await p28Apply(usup, 3)
            try expect(sv == 1 && abs(uv) < 1e-9, "generic supervised \(sv) \(uv)")
            var df = DataFrame(); df.append(column: Column<Double>(name: "x", contents: [1, nil, 5])); df.append(column: Column<String>(name: "l", contents: ["a", "b", "c"]))
            let sel = ColumnSelector<NumericImputer<Double>, Double>(columns: ["x"], estimator: NumericImputer<Double>(.mean))
            let tab = try await p28FitTabular(sel, df), utab = try await p28UpdateTabular(sel, df)
            let stab = try await p28FitSupervisedTabular(TabularEstimatorToSupervisedAdaptor(sel, annotationColumnID: ColumnID("l", String.self)), df)
            let ustab = try await p28UpdateSupervisedTabular(UpdatableTabularEstimatorToSupervisedAdaptor(sel, annotationColumnID: ColumnID("l", String.self)), df)
            var filled: [[Double]] = []
            for t in [tab, utab, stab, ustab] { filled.append(try await p28ApplyTabular(t, df)["x", Double.self].map { $0 ?? -1 }) }
            try expect(filled.allSatisfy { $0 == [1, 3, 5] }, "generic tabular \(filled)")
            let down = try await p28ApplyTemporal(Downsampler<Double>(factor: 2), p28Seq([1, 2, 3.0]))
            try expect(down == [1, 3], "generic temporal transformer \(down)")
            #if !os(watchOS)
            let te = try await p28FitTemporal(EstimatorToTemporalAdaptor(MinMaxScaler<Double>()), [p28Seq([0, 4.0])])
            let ute = try await p28UpdateTemporal(UpdatableEstimatorToTemporalAdaptor(StandardScaler<Double>()), [p28Seq([0, 4.0])])
            let ste = try await p28FitSupervisedTemporal(SupervisedEstimatorToTemporalAdaptor(EstimatorToSupervisedAdaptor<MinMaxScaler<Double>, Int>(MinMaxScaler<Double>())),
                                                         [AnnotatedFeature(feature: p28Seq([0, 4.0]), annotation: 1)])
            let uste = try await p28UpdateSupervisedTemporal(UpdatableSupervisedEstimatorToTemporalAdaptor(UpdatableEstimatorToSupervisedAdaptor<StandardScaler<Double>, Int>(StandardScaler<Double>())),
                                                             [AnnotatedFeature(feature: p28Seq([0, 4.0]), annotation: 1)])
            let tv = try await p28ApplyTemporal(te, p28Seq([1.0])), utv = try await p28ApplyTemporal(ute, p28Seq([2.0]))
            let stv = try await p28ApplyTemporal(ste, p28Seq([3.0])), ustv = try await p28ApplyTemporal(uste, p28Seq([2.0]))
            try expect(tv == [0.25] && utv == [0] && stv == [0.75] && ustv == [0], "generic temporal estimators \(tv) \(utv) \(stv) \(ustv)")
            #endif
            // an app's own classifier and regressor
            let cd = try await p28Apply(P28Threshold(), 2)
            let half = try await p28Apply(P28Half(), 3)
            try expect(cd.mostLikelyLabel == "pos" && cd.topLabels(1) == ["pos"] && half == 1.5, "own classifier/regressor \(cd.labelsSortedByProbability) \(half)")
            // the augmentation result builder: an app transformer then a framework one, deterministic
            var g = SystemRandomNumberGenerator()
            let built = p28Augmentation { P28Doubler(); LinearTransformer<Double>(scale: 1, offset: 1) }
            let bv = try await built.applied(to: 2, generator: &g, eventHandler: nil)
            let direct = AugmentationBuilder<Double>.buildPartialBlock(first: P28Doubler())
            let dv = try await direct.applied(to: 2, generator: &g, eventHandler: nil)
            try expect(bv == 5 && dv == 4, "augmentation builder \(bv) \(dv)")
            // a fully connected network classifier model, named by its type
            let pts = (0..<20).map { AnnotatedFeature(feature: p28Vec([Float($0 % 10) / 10, $0 < 10 ? 1 : -1]), annotation: $0 < 10 ? "up" : "down") }
            var ncfg = FullyConnectedNetworkConfiguration(); ncfg.hiddenUnitCounts = [4]; ncfg.maximumIterations = 40; ncfg.batchSize = 5
            let net: FullyConnectedNetworkClassifierModel<Float, String> = try await FullyConnectedNetworkClassifier<Float, String>(labels: ["up", "down"], configuration: ncfg).fitted(to: pts)
            let nd = try await net.applied(to: p28Vec([0.5, 1]))
            try expect(Set(nd.map(\.label)) == ["up", "down"], "network classifier \(nd.labelsSortedByProbability)")
            #if !os(watchOS) && canImport(AVFoundation)
            let a44 = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!, a16 = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 2)!
            let ape = AudioPreprocessingError.incompatibleTargetFormatForConversion(inputFormat: a44, targetFormat: a16)
            try expect(ape == .incompatibleTargetFormatForConversion(inputFormat: a44, targetFormat: a16) && !(ape.errorDescription ?? "").isEmpty, "audio preprocessing error")
            #endif
            // an image feature extractor of the app's own (mean colour), through the protocol
            #if canImport(CoreImage) && !os(watchOS)
            struct MeanColor: ImageFeatureExtractor {
                func applied(to input: CIImage, eventHandler: EventHandler?) async throws -> MLShapedArray<Float> {
                    let avg = input.applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: input.extent)])
                    var p = [UInt8](repeating: 0, count: 4)
                    CIContext(options: [.useSoftwareRenderer: true]).render(avg, toBitmap: &p, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
                    return MLShapedArray(scalars: p.prefix(3).map { Float($0) / 255 }, shape: [3])
                }
            }
            let red = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: CGRect(x: 0, y: 0, width: 8, height: 8))
            let mc = try await p28Apply(MeanColor(), red)
            try expect(mc.scalars[0] > 0.9 && mc.scalars[2] < 0.1, "own image feature extractor \(mc.scalars)")
            #endif
            // ranged annotations from a data frame: files with labelled time ranges
            var rdf = DataFrame()
            rdf.append(column: Column<String>(name: "file", contents: ["/tmp/a.mov", "/tmp/b.mov"]))
            rdf.append(column: Column<String>(name: "label", contents: ["jump", "run"]))
            rdf.append(column: Column<Double>(name: "start", contents: [0, 1.5])); rdf.append(column: Column<Double>(name: "end", contents: [1, 3]))
            var params = DataFrameTemporalAnnotationParameters<String>()
            params.filePathType = .absolute; params.filePathColumnID = ColumnID("file", String.self); params.annotationColumnID = ColumnID("label", String.self)
            params.startTimeColumnID = ColumnID("start", Double.self); params.endTimeColumnID = ColumnID("end", Double.self)
            let rel = DataFrameTemporalAnnotationParameters<String>.FilePathType.relative(baseURL: URL(fileURLWithPath: "/tmp"))
            var ranged = "?"
            do {
                let r = try rdf.loadRangedAnnotations(parameters: params, continueOnFailure: true)
                ranged = r.map { "\($0.annotation)@\($0.feature.range.lowerBound)-\($0.feature.range.upperBound)" }.joined(separator: " ")
            } catch { ranged = "err \(type(of: error))" }
            return "fit \(m3)/\(s3), tabular \(filled[0]), classifier \(cd.mostLikelyLabel ?? "-"), builder \(bv), network \(nd.mostLikelyLabel ?? "-"), path types \(rel) / \(params.filePathType), ranged \(ranged)"
        })
        #endif
        return c
    }

    static var p28mlReality: [Check] {
        var c: [Check] = []
        #if canImport(RealityKit) && !os(watchOS)
        c.append(check("RealityFoundation", "p28-component-values", timeout: 60) {
            try await onMain {
                let e = Entity(), other = Entity()
                // pins, attached transforms
                var pins = GeometricPinsComponent()
                let pa = e.pins.set(named: "a", position: [0, 1, 0]), pb = other.pins.set(named: "b", position: [0, 0, 0])
                pins.set(pin: pa)
                try expect(pins["a"] != nil && pins.pins.count == 1, "pins \(pins.pins.count)")
                _ = pins.removePin(named: "a")
                let att = AttachedTransformComponent(source: pa, target: pb)
                try expect(pins.pins.isEmpty && att.source != nil, "pin removed / attachment")
                // lighting and environment values
                let w = 16, h = 8
                let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                ctx.setFillColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
                var got: [String] = []
                var env: EnvironmentResource?
                do { env = try EnvironmentResource(equirectangular: ctx.makeImage()!, withName: "p28sky"); got.append("environment ok") } catch { got.append("environment err \((error as NSError).code)") }
                var comps: [any Component] = [
                    AttachedTransformComponent(target: pb), CharacterControllerStateComponent(), DiffuseLightProbeReceiverComponent(probeGroup: other),
                    EnvironmentLightingConfigurationComponent(environmentLightingWeight: 0.25), ImageBasedLightComponent(source: .none, intensityExponent: 1),
                    ProjectiveTransformCameraComponent(projectionMatrix: matrix_identity_float4x4), VirtualEnvironmentProbeComponent(source: .none, influence: .global),
                    MeshInstancesComponent(), BlendShapeWeightsComponent(weightsMapping: BlendShapeWeightsMapping(blendShapeName: "face", weightNames: ["smile", "blink"])),
                    SkeletalPosesComponent(poses: [SkeletalPose(id: "pose", joints: [("root", Transform.identity), ("tip", Transform(translation: [0, 1, 0]))])]),
                    NavigationComponent(), GeometricPinsComponent(),
                ]
                var decal = PhysicallyBasedDecalComponent(baseColor: .init(tint: .red)); decal.sortOrder = 3; decal.bounds = [1, 2, 3]
                comps.append(decal)
                if let env {
                    comps.append(ImageBasedLightComponent(source: .single(env)))
                    comps.append(VirtualEnvironmentProbeComponent(source: .single(.init(environment: env, intensityExponent: 0.5)),
                                                                   influence: .local(parallaxBounds: BoundingBox(min: [-1, -1, -1], max: [1, 1, 1]), blendDistance: 0.1)))
                }
                #if os(visionOS)
                comps.append(DockingRegionComponent())
                #endif
                for x in comps { e.components.set(x) }
                let missing = comps.map { type(of: $0) }.filter { !e.components.has($0) }.map { "\($0)" }
                try expect(missing.isEmpty, "components not set \(missing)")
                try expect(e.components[EnvironmentLightingConfigurationComponent.self]?.environmentLightingWeight == 0.25, "env lighting weight")
                try expect(e.components[PhysicallyBasedDecalComponent.self]?.sortOrder == 3 && e.components[PhysicallyBasedDecalComponent.self]?.bounds == [1, 2, 3], "decal")
                try expect(e.components[CharacterControllerStateComponent.self]?.isOnGround == false, "character state")
                #if os(iOS)
                e.components.set(BodyTrackingComponent(.any))
                try expect(e.components[BodyTrackingComponent.self]?.target == .any && !(e.components[BodyTrackingComponent.self]?.isPaused ?? true), "body tracking")
                #endif
                let poses = e.components[SkeletalPosesComponent.self]!.poses
                // on an entity without a skinned model the component keeps no poses (Apple's simulator)
                try expect(poses.isEmpty, "skeletal poses \(poses.map(\.id))")
                let sp = SkeletalPose(id: "pose", joints: [("root", Transform.identity), ("tip", Transform(translation: [0, 1, 0]))])
                try expect(sp.jointNames == ["root", "tip"] && sp["tip"]?.translation == [0, 1, 0], "skeletal pose \(sp.jointNames)")
                var ps = SkeletalPoseSet(); _ = ps.set(SkeletalPose(id: "p2", joints: [("j", .identity)]))
                got.append("pose set \(ps.count) contains \(ps.contains("p2")) default \(ps.default?.id ?? "-") index \(ps.index(of: "p2") != nil)")
                let bsw = e.components[BlendShapeWeightsComponent.self]!.weightSet
                var wset = BlendShapeWeightsSet(); _ = wset.set(BlendShapeWeightsData(id: "face", weights: [("smile", 0.5), ("blink", 1)]))
                let wd = wset["face"]
                // a weights set filled by hand keeps nothing without a mapping (Apple's simulator: nil, not contained)
                let bwd = BlendShapeWeightsData(id: "face", weights: [("smile", 0.5), ("blink", 1)])
                try expect(bwd.weights == [0.5, 1] && bwd.weightNames == ["smile", "blink"], "blend weights data \(bwd.weights)")
                got.append("weights set \(wd == nil ? "nil" : "\(wd!.weights)") contains \(wset.contains("face"))")
                got.append("component weight sets \(bsw.count)")
                var bw: BlendShapeWeights = [0.1, 0.2]; bw[1] = 0.3
                var jt: JointTransforms = [.identity, Transform(scale: [2, 2, 2])]; jt[0].translation = [1, 0, 0]
                try expect(bw.count == 2 && bw[1] == 0.3 && jt[0].translation == [1, 0, 0] && jt.count == 2, "weights / joint transforms")
                let ad: [any AnimatableData] = [bw, jt, Float(1), Transform.identity]
                // value types
                #if !os(tvOS)
                let ccs: [CameraControls] = [.none, .tilt, .pan, .orbit, .dolly]
                #else
                let ccs = [1, 2, 3, 4, 5]
                #endif
                let orient: [CameraFieldOfViewOrientation] = [.horizontal, .vertical]
                let aa: [AntialiasingMode] = [.none, .multisample4X]
                let lms: [LightingModel] = [.lit(diffuseModel: .hammon, specularModel: .ggx), .hair(), .unlit(isTonemappingEnabled: false)]
                let culls: [MaterialParameterTypes.FaceCulling] = [.none, .front, .back]
                let fills: [MaterialParameterTypes.TriangleFillMode] = [.fill, .lines]
                let tct = MaterialParameterTypes.TextureCoordinateTransform(offset: [0.5, 0], scale: [2, 2], rotation: 0)
                let forceModes: [ForceMode] = [.force, .acceleration, .impulse, .velocity]
                let fall = TimedForceFalloff(duration: 2, rate: 0.5)
                let ptypes: PhysicsBodyParameterTypes = [.position, .orientation, .velocity, .angularVelocity, .distance, .mass, .inertiaTensor]
                let results: [ActionResult] = [.running, .failure, .success]
                let aev: ActionEventType = [.started, .updated, .ended, .skipped, .paused, .resumed, .terminated]
                let scopes: [MeshScope] = [.all, .model(name: "m"), .instance(name: "i", part: "p")]
                let shapeErrs: [ShapeResourceError] = [.staticMeshGenerationFailed, .convexPolyhedronGenerationFailed]
                let deps: [SystemDependency] = [.before(P28NoopSystem.self), .after(P28NoopSystem.self)]
                let cond: SystemUpdateCondition = .rendering
                let space: SceneRealityCoordinateSpace = .scene
                let spaces: [any RealityCoordinateSpace] = [space, SceneRealityCoordinateSpace()]
                #if os(visionOS)
                let modes: [VideoPlaybackController.ViewingMode] = [.mono, .stereo]
                #else
                let modes: [VideoPlaybackController.ViewingMode] = [.mono, .mono]
                #endif
                try expect(Set(ccs).count == 5 && Set(orient).count == 2 && Set(aa).count == 2 && Set(lms).count == 3 && Set(culls).count == 3 && Set(fills).count == 2,
                           "camera/material enums")
                try expect(tct.scale == [2, 2] && Set(forceModes).count == 4 && fall.rate == 0.5 && ptypes.contains(.mass) && Set(results).count == 3 && aev.contains(.paused),
                           "force / action values")
                try expect(scopes[0].isAll && !scopes[1].isAll && Set(scopes).count == 3 && !(shapeErrs[0].errorDescription ?? "").isEmpty && deps[0] != deps[1] && spaces.count == 2 && modes.count == 2,
                           "scopes / errors / deps")
                _ = cond
                let inf = MeshJointInfluence(jointIndex: 2, weight: 0.75)
                try expect(inf.jointIndex == 2 && inf.weight == 0.75 && ad.count == 4, "joint influence")
                #if os(iOS)
                let ld = LensDistortionData(center: [0.5, 0.5], radialLookupTable: [0, 0.01, 0.02])
                let cam: CameraRealityCoordinateSpace = .camera
                try expect(ld.radialLookupTable.count == 3 && (cam as any RealityCoordinateSpace) is CameraRealityCoordinateSpace, "lens distortion / camera space")
                got.append("photogrammetry supported \(PhotogrammetrySession.isSupported)")
                #endif
                // video player component on an AVPlayer (no item: no video size yet)
                let vp = VideoPlayerComponent(avPlayer: AVPlayer())
                #if os(visionOS)
                let wantMode: VideoPlaybackController.ViewingMode = .stereo   // Apple's visionOS simulator: stereo by default
                #else
                let wantMode: VideoPlaybackController.ViewingMode = .mono
                #endif
                try expect(vp.avPlayer != nil && vp.desiredViewingMode == wantMode, "video player \(vp.desiredViewingMode)")
                got.append("video \(vp.screenVideoDimension) \(vp.playerScreenSize)")
                // instanced mesh: 3 transforms
                let data = try LowLevelInstanceData(instanceCount: 3)
                data.withMutableTransforms { t in for i in 0..<t.count { t[i] = Transform(translation: [Float(i), 0, 0]).matrix } }
                var xs: [Float] = []; data.withTransforms { t in xs = t.map { $0.columns.3.x } }
                let mic = try MeshInstancesComponent(mesh: .generateBox(size: 0.1), instances: data)
                try expect(xs == [0, 1, 2] && data.instanceCount == 3 && mic[partIndex: 0]?.data.instanceCount == 3, "instances \(xs)")
                return got.joined(separator: ", ") + "; \(comps.count) components"
            }
        })
        c.append(check("RealityFoundation", "p28-navigation-mesh", timeout: 60) {
            try await p2Main {
                // a 10 x 10 floor at y = 0 as two triangles
                let verts: [SIMD3<Float>] = [[-5, 0, -5], [5, 0, -5], [5, 0, 5], [-5, 0, 5]]
                var cfg = NavigationMeshResource.Configuration(cellSize: 0.1, cellHeight: 0.1, walkableSlopeAngle: 45, characterHeight: 1, walkableClimb: 0.2, characterRadius: 0.2)
                cfg.partitionMethod = .watershed
                let methods: [NavigationMeshResource.Configuration.PartitionMethod] = [.watershed, .monotone, .layer]
                let link = NavigationMeshResource.OffMeshConnection(startPoint: [0, 0, 0], endPoint: [1, 0, 0], radius: 0.2, label: "jump")
                let nav = try await NavigationMeshResource(triangleIndices: [0, 2, 1, 0, 3, 2], vertices: verts, offMeshConnections: [link], configuration: cfg)
                try expect(!nav.vertices.isEmpty && !nav.polygonIndices.isEmpty && nav.offMeshConnections.count == 1 && methods.count == 3, "nav mesh \(nav.vertices.count) vertices \(nav.polygonIndices.count) polygons")
                nav.markAreaInBox(boundingBox: BoundingBox(min: [-5, -1, -5], max: [0, 1, 0]), area: NavigationMeshResource.Area(rawValue: 3))
                nav.markFlagInCylinder(position: [2, 0, 2], radius: 1, halfHeight: 1, flag: NavigationMeshResource.Flag(rawValue: 1))
                let areas = Set(nav.areas.map(\.rawValue))
                let r = try RealityRenderer()
                let world = Entity(); world.components.set(NavigationMeshComponent(navigationMeshes: [nav])); r.entities.append(world)
                let agent = Entity(); agent.position = [-4, 0, -4]
                var filter = NavigationComponent.Filter(); filter.includeFlags = NavigationMeshResource.FlagGroup(rawValue: 0xffff)
                agent.components.set(NavigationComponent(filter: filter)); r.entities.append(agent)
                try r.update(1.0 / 60)
                // (computePath never returns in an offscreen renderer, on Apple's simulator too: a path request and frames instead)
                let ctl = try NavigationController(entity: agent)
                ctl.requestPath(from: [-4, 0, -4], to: [4, 0, 4])
                for _ in 0..<30 where ctl.pathfindStatus == .inProgress || ctl.pathfindStatus == .none { try r.update(1.0 / 60) }
                let pts = ctl.currentPath
                ctl.stopPathfind()
                let statuses: [NavigationController.PathfindStatus] = [.none, .inProgress, .failed, .succeeded]
                let node = NavigationMeshResource.PathNode(position: [1, 2, 3], label: "n")
                return "nav mesh \(nav.vertices.count) vertices, areas \(areas.sorted()), path \(pts.count) nodes, status \(ctl.pathfindStatus) of \(statuses.count), node \(node.label)"
            }
        })
        c.append(check("RealityFoundation", "p28-skeleton-ik-deformers", timeout: 60) {
            try await p2Main {
                var got: [String] = []
                // a two-joint skeleton (root -> tip 1 m up)
                let bind1 = Transform(translation: [0, -1, 0]).matrix
                guard let skel = MeshResource.Skeleton(id: "arm", jointNames: ["root", "root/tip"], inverseBindPoseMatrices: [matrix_identity_float4x4, bind1],
                                                       restPoseTransforms: [.identity, Transform(translation: [0, 1, 0])], parentIndices: [nil, 0]) else { throw Fail("no skeleton") }
                let pose = SkeletalPose(id: "rest", from: skel)
                try expect(pose.jointNames.count == 2 && pose.jointTransforms[1].translation == [0, 1, 0], "pose from skeleton \(pose.jointNames)")
                let sres = try SkeletonResource(from: skel)
                let tree = try SkeletonResource.Joint("root") { try SkeletonResource.Joint("tip", restPoseTransform: Transform(translation: [0, 1, 0])) }
                let named = try SkeletonResource(named: "arm2", rootJoint: tree, animationEvaluation: .init(blendMasks: [.init(name: "upper", jointWeights: ["tip": 1])]))
                try expect(sres.rootJoint.children.count == 1 && named.rootJoint.children.first?.name == "tip" && named.animationEvaluation.blendMasks.count == 1, "skeleton resources")
                // an IK rig on it, its resource and component
                do {
                    var rig = try IKRig(for: skel)
                    rig.maxIterations = 10; rig.globalFkWeight = 0.5
                    let solver = IKSolverDefinition(id: 7, rig: rig)
                    let ikr = try IKResource(rig: rig)
                    let comp = IKComponent(resource: ikr)
                    got.append("IK rig \(rig.joints.count) joints, \(ikr.solverDefinitions.count) solvers, component \(comp.solvers.count), def \(solver.id)")
                    let rig2 = try IKRig(named: "rig2", rootJoint: tree)
                    got.append("rig2 \(rig2.joints.count)")
                } catch { got.append("IK err \(error)") }
                do {
                    let rt = try RetargetingConfiguration.automatchBiped(sres, to: named)
                    got.append("retarget \(rt.sourceSkeleton.name)->\(rt.targetSkeleton.name)")
                } catch { got.append("retarget err \(String(describing: error).prefix(60))") }
                // mesh deformers: a stack on all meshes, its component; equality and codable
                let stack = MeshDeformationStack(deformers: [SkinningDeformer(skinsTangentFrame: true), BlendShapeDeformer(), RenormalizingDeformer(), SubdivisionSurfaceDeformer()], targets: [.all])
                let dc = try MeshDeformerComponent(from: [stack])
                let back = try JSONDecoder().decode(MeshDeformationStack.self, from: try JSONEncoder().encode(stack))
                let opts = MeshDeformerOptions(cadence: .everyFrame, inputSpec: [.positions, .normals], outputSpec: .positions)
                let em: [MeshDeformerExecutionMode] = [.gpu, .cpu]
                let vo: MeshDeformerVertexOptions = [.positions, .normals, .tangents, .bitangents, .uvs, .uv1s, .tangentFrame]
                try expect(dc.deformations.count == 1 && back == stack && opts.inputSpec.contains(.normals) && em.count == 2 && vo.contains(.uv1s) && !MeshDeformerVertexOptions.all.isEmpty,
                           "deformers \(dc.deformations.first?.deformers.count ?? -1)")
                got.append("deformer types \(stack.deformers.map(\.type))")
                // the mesh's buffer containers (MeshResource.Part is one)
                let mesh = MeshResource.generateBox(size: 0.2)
                if let part = mesh.contents.models.first?.parts.first {
                    let bc: any MeshBufferContainer = part
                    got.append("part positions \(bc.positions.count) normals \(bc.normals?.count ?? -1) blend shapes \(bc.blendShapeNames)")
                }
                return got.joined(separator: ", ")
            }
        })

        c.append(check("RealityFoundation", "p28-custom-actions-bindings", timeout: 60) {
            try await p2Main {
                let r = try RealityRenderer()
                let e = Entity(); e.name = "riser"; r.entities.append(e)
                P28Raise.registerAction()
                P28RaiseHandler.register { _ in P28RaiseHandler() }
                let subs = P28Tally()
                P28Raise.subscribe(to: .ended) { _ in subs.add("ended") }
                let raise = P28Raise(dy: 2)
                let anim = ActionAnimation(for: raise, events: [ActionEventDefinition<P28Raise>(startTime: 0, duration: 0.5)], name: "raise", bindTarget: .transform)
                try expect(anim.action?.dy == 2 && anim.eventDefinitions.count == 1 && anim.eventDefinitions[0].duration == 0.5 && anim.name == "raise", "action animation \(anim.duration)")
                let view = AnimationView(source: anim, name: "view", bindTarget: .transform, speed: 1)
                let defs: [any AnimationDefinition] = [anim, view, view.trimmed(duration: 0.4), anim.repeated(count: 2)]
                e.playAnimation(try AnimationResource.generate(with: anim))
                for _ in 0..<20 { try r.update(0.05) }
                let seen = P28RaiseHandler.seen.all
                P28Raise.unsubscribeAll()
                // the handler's updates moved the entity (Apple's simulator: by up to dy)
                try expect(seen.contains("started") && seen.contains("updated") && e.position.y > 0.5, "custom action: events \(Set(seen).sorted()) y \(e.position.y)")
                // bind targets and paths, parameters
                let paths: [BindTarget] = [.entity("riser").transform, .entity("a").entity("b").opacity, .scene("s").anchorEntity("x").rootMotion,
                                           .entity("m").material(0).baseColorTint, .entity("p").parameter("speed"), .entity("k").skeletalPose("pose")]
                var parts: [Int] = []
                for t in paths { if case .path(let bp) = t { let ps: [BindPath.Part] = bp.parts; parts.append(ps.count) } }
                try expect(parts.count == paths.count && parts[1] >= 2, "bind paths \(parts)")
                e.parameters["speed"] = BindableValue(Float(2.5))
                let back: BindableValue<Float>? = e.parameters["speed"]
                func readBack<T: BindableData>(_ v: BindableValue<T>?) -> T? { v?.value }
                let set: Entity.ParameterSet = e.parameters
                try expect(readBack(back) == 2.5 && set["speed", Float.self]?.baseValue == 2.5, "parameter \(String(describing: back?.value))")
                // a behaviour-tree action and handler of the app's own; behaviour trees and animation graphs from (invalid) definitions
                P28Think.registerAction()
                P28ThinkHandler.register { _ in P28ThinkHandler() }
                let btErrs = BehaviorTreeResource.validate(definition: Data("{}".utf8))
                var bt = "?"
                do { _ = try BehaviorTreeResource(definition: Data("{}".utf8)); bt = "made" } catch { bt = "refused" }
                let btc = BehaviorTreeComponent(behaviorTree: nil, availableBehaviorTrees: [:])
                guard let skel = MeshResource.Skeleton(id: "s", jointNames: ["root"], inverseBindPoseMatrices: [matrix_identity_float4x4]) else { throw Fail("skeleton") }
                let sres = try SkeletonResource(from: skel)
                let agErrs = AnimationGraphResource.validate(definition: Data("{}".utf8), skeletonResource: sres)
                var ag = "?"
                do { let g = try AnimationGraphResource(definition: Data("{}".utf8), skeletonResource: sres); ag = "made \(g.parameterNames)"; _ = AnimationGraphComponent(graph: g) } catch { ag = "refused" }
                let nodes: [any BlendTreeNode] = []; _ = nodes
                let invalid: BlendTreeInvalidNode.Type = BlendTreeInvalidNode.self; _ = invalid
                return "events \(Set(seen).sorted()) y \(e.position.y), subscribed \(subs.all.count), \(defs.count) definitions, bind paths \(parts), behaviour tree \(btErrs.count) errors/\(bt), component \(btc.behaviorTree == nil), graph \(agErrs.count) errors/\(ag)"
            }
        })
        c.append(check("RealityFoundation", "p28-events-audio-forces", timeout: 60) {
            try await p2Main {
                var got: [String] = []
                let r = try RealityRenderer()
                let world = Entity(); r.entities.append(world)
                var sim = PhysicsSimulationComponent(); sim.gravity = [0, -9.8, 0]; world.components.set(sim)
                let tally = P28Tally()
                var subs: [EventSubscription] = []
                subs.append(r.subscribe(to: PhysicsSimulationEvents.WillSimulate.self) { _ in tally.add("will") })
                subs.append(r.subscribe(to: PhysicsSimulationEvents.DidSimulate.self) { _ in tally.add("did") })
                let contacts = P28Tally()
                subs.append(r.subscribe(to: CollisionEvents.Began.self) { ev in
                    let cs: [Contact] = ev.contacts
                    for k in cs { contacts.add("\(k.normal.y > 0.5 || k.normal.y < -0.5) \(k.impulse >= 0) \(k.penetrationDistance <= 0.01)") }
                })
                subs.append(r.subscribe(to: AnchorStateEvents.DidAnchor.self) { _ in tally.add("anchor") })
                subs.append(r.subscribe(to: AudioEvents.PlaybackCompleted.self) { _ in tally.add("audio done") })
                subs.append(r.subscribe(to: SynchronizationEvents.OwnershipChanged.self) { _ in tally.add("owner") })
                subs.append(r.subscribe(to: VideoPlayerEvents.VideoSizeDidChange.self) { _ in tally.add("video") })
                subs.append(r.subscribe(to: AccessibilityEvents.Activate.self) { _ in tally.add("ax") })
                #if os(visionOS)
                subs.append(r.subscribe(to: ManipulationEvents.WillBegin.self) { _ in tally.add("manip") })
                subs.append(r.subscribe(to: ImagePresentationEvents.TransitionCompleted.self) { _ in tally.add("image") })
                #endif
                // a box falling on a static floor: contacts with normals, a custom upward force on a second box
                let floor = ModelEntity(mesh: .generateBox(size: [4, 0.2, 4])); floor.position = [0, -1, 0]
                floor.components.set(CollisionComponent(shapes: [.generateBox(size: [4, 0.2, 4])]))
                floor.components.set(PhysicsBodyComponent(massProperties: .default, material: nil, mode: .static))
                func box(_ x: Float) -> ModelEntity {
                    let b = ModelEntity(mesh: .generateBox(size: 0.2)); b.position = [x, 0, 0]
                    b.components.set(CollisionComponent(shapes: [.generateBox(size: [0.2, 0.2, 0.2])], filter: CollisionFilter(group: CollisionGroup(rawValue: 4), mask: .all)))
                    b.components.set(PhysicsBodyComponent(massProperties: PhysicsMassProperties(mass: 1), material: nil, mode: .dynamic))
                    world.addChild(b); return b
                }
                world.addChild(floor)
                let faller = box(0)
                P28Lift.register()
                let lifted = box(2)
                let field = Entity(); field.position = [2, 0, 0]
                field.components.set(ForceEffectComponent(effects: [ForceEffect(effect: P28Lift(), spatialFalloff: SpatialForceFalloff(bounds: .sphere(radius: 1)), mask: CollisionGroup(rawValue: 4))]))
                world.addChild(field)
                for _ in 0..<60 { try r.update(1.0 / 60) }
                let t = tally.all
                try expect(t.contains("will") && t.contains("did"), "simulation events \(Set(t))")
                // the box lands on the floor (top at -0.9: centre -0.8 at rest); the Began events of a PhysicsSimulationComponent's
                // own simulation carry no contacts to a renderer subscription (Apple's simulator: none)
                try expect(faller.position.y < -0.6 && faller.position.y > -0.9, "faller y \(faller.position.y)")
                got.append("contacts \(contacts.all.count) [\(contacts.all.first ?? "")], lift calls \(P28Lift.calls.all.count) [\(P28Lift.calls.all.first ?? "")], lifted y \(lifted.position.y)")
                try expect(lifted.position.y > faller.position.y, "custom force: lifted \(lifted.position.y) faller \(faller.position.y)")
                // audio: a file resource group, a generator controller (silence)
                let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("p28-\(UUID().uuidString).caf")
                defer { try? FileManager.default.removeItem(at: url) }
                do {
                    let f = try AVAudioFile(forWriting: url, settings: fmt.settings)
                    let b = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 4410)!; b.frameLength = 4410
                    try f.write(from: b)
                }
                let a1 = try AudioFileResource.load(contentsOf: url), a2 = try AudioFileResource.load(contentsOf: url)
                let group = try AudioFileGroupResource([a1, a2])
                try expect(group.resources.count == 2, "audio group \(group.resources.count)")
                let speaker = Entity(); world.addChild(speaker)
                do {
                    let gen: AudioGeneratorController = try speaker.prepareAudio { _, _, frames, abl in
                        for buf in UnsafeMutableAudioBufferListPointer(abl) { memset(buf.mData, 0, Int(buf.mDataByteSize)) }
                        _ = frames; return noErr
                    }
                    gen.gain = -10; gen.play()
                    for _ in 0..<3 { try r.update(1.0 / 60) }
                    got.append("generator playing \(gen.isPlaying) gain \(gen.gain) entity \(gen.entity === speaker)")
                    gen.stop()
                } catch { got.append("generator err \((error as NSError).code)") }
                let res: [any Resource] = [group, a1, MeshResource.generateBox(size: 1)]
                // synchronization: the scene's service (none offline), a Multipeer service of the app's own
                let scene = faller.scene
                got.append("sync service \(scene?.synchronizationService == nil ? "none" : "some")")
                #if !os(visionOS) && !os(tvOS)
                let peer = MCPeerID(displayName: "p28")
                let svc = try MultipeerConnectivityService(session: MCSession(peer: peer))
                // (owner(of:) on an entity of a scene the service does not sync crashes the app, on Apple's simulator too)
                let asService: any SynchronizationService = svc
                let peerType: (any SynchronizationPeerID.Type)? = nil; _ = peerType
                try expect(svc.session.myPeerID.displayName == "p28" && asService === svc, "multipeer service session")
                got.append("multipeer service \(type(of: asService))")
                #endif
                withExtendedLifetime(subs) {}
                got.append("\(res.count) resources, events \(Set(t).sorted())")
                return got.joined(separator: ", ")
            }
        })
        c.append(check("RealityFoundation", "p28-pixel-cast-materials-misc", timeout: 60) {
            try await p2Main {
                var got: [String] = []
                #if !os(visionOS)
                // a red box rendered once, then a pixel cast through its centre
                guard let dev = MTLCreateSystemDefaultDevice() else { throw Fail("no MTLDevice") }
                let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: 64, height: 64, mipmapped: false)
                td.usage = [.renderTarget, .shaderRead]; td.storageMode = .shared
                guard let tex = dev.makeTexture(descriptor: td) else { throw Fail("texture") }
                let r = try RealityRenderer()
                let boxE = ModelEntity(mesh: .generateBox(size: 0.5), materials: [UnlitMaterial(color: .red)]); boxE.name = "target"
                let cam = PerspectiveCamera(); cam.position = [0, 0, 2]
                r.entities.append(boxE); r.entities.append(cam); r.activeCamera = cam
                let out = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: tex))
                let frame: Result<Bool, Error>? = await p28Within(20) {
                    try await withCheckedThrowingContinuation { (k: CheckedContinuation<Bool, Error>) in
                        do { try r.updateAndRender(deltaTime: 1.0 / 60, cameraOutput: out, onComplete: { _ in k.resume(returning: true) }) } catch { k.resume(throwing: error) }
                    }
                }
                got.append("frame \(frame.map { if case .success = $0 { return "ok" } else { return "err" } } ?? "timeout")")
                if let scene = boxE.scene {
                    let cast: Result<PixelCastHit?, Error>? = await p28Within(10) { try await scene.pixelCast(from: [0, 0, 2], to: [0, 0, -2]) }
                    switch cast {
                    case .success(let hit?)?: got.append("pixel cast \(hit.entity.name) z \(String(format: "%.2f", hit.position.z)) n \(hit.normal) prim \(hit.primitive) bary \(hit.barycentric != nil)")
                    case .success(nil)?: got.append("pixel cast nil")
                    case .failure(let e)?: got.append("pixel cast err \(String(describing: e).prefix(50))")
                    case nil: got.append("pixel cast timeout")
                    }
                }
                // a custom material from a surface shader in a runtime-compiled library (or the simulator's refusal)
                do {
                    let lib = try await dev.makeLibrary(source: """
                        #include <metal_stdlib>
                        #include <RealityKit/RealityKit.h>
                        [[visible]] void p28Surface(realitykit::surface_parameters params) { params.surface().set_base_color(half3(0, 1, 0)); }
                        """, options: nil)
                    let shader = CustomMaterial.SurfaceShader(named: "p28Surface", in: lib)
                    var cm = try CustomMaterial(surfaceShader: shader, lightingModel: .unlit)
                    cm.faceCulling = .back; cm.blending = .opaque
                    let stages: [CustomShaderStage] = [.geometryModifier, .surfaceShader]
                    got.append("custom material \(cm.lightingModel) \(stages.count) stages, functions \((shader as any MaterialFunction) is CustomMaterial.SurfaceShader)")
                } catch let e as CustomMaterialError {
                    got.append("custom material \(e)")
                } catch { got.append("custom material err \(String(describing: error).prefix(60))") }
                let cmErrs: [CustomMaterialError] = [.geometryModifierFunctionNotFound, .surfaceShaderFunctionNotFound, .defaultSurfaceShaderForMaterialNotFound]
                var inv = P28Invert(); inv.prepare(for: dev)
                try expect(cmErrs.count == 3 && inv.prepared, "custom material errors / post-process prepare")
                #endif
                // environment resources from an equirectangular picture, their skybox
                let ctx = CGContext(data: nil, width: 32, height: 16, bitsPerComponent: 8, bytesPerRow: 128, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                ctx.setFillColor(red: 1, green: 0.5, blue: 0, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: 32, height: 16))
                do {
                    let env = try await EnvironmentResource(equirectangular: ctx.makeImage()!, withName: "p28env")
                    got.append("environment skybox \(env.skybox.width)x\(env.skybox.height)")
                } catch { got.append("environment err \((error as NSError).code)") }
                // the HasX protocols and entity classes
                #if os(iOS)
                let bt = BodyTrackedEntity()
                got.append("body tracked \((bt as Any) is HasBodyTracking) paused \(bt.bodyTracking.isPaused)")
                #endif
                #if !os(tvOS)
                got.append("scene understanding \((Entity() as Any) is HasSceneUnderstanding)")
                #endif
                let mcp: MaterialColorParameter = .color(.red)
                try expect(mcp == .color(.red), "material colour parameter")
                return got.joined(separator: ", ")
            }
        })
        #endif
        return c
    }
}

// MARK: - CoreML / Vision (wave 2 resume)
#if canImport(CoreML)
/// the stateful ML program of P14_Models (y = acc + x, acc := y), compiled by coremlcompiler: a program with functions,
/// blocks and operations for the model-structure and compute-plan classes
private let p28AccumulatorModel: [(String, String)] = [
    ("metadata.json", "WwogIHsKICAgICJtZXRhZGF0YU91dHB1dFZlcnNpb24iIDogIjMuMCIsCiAgICAib3V0cHV0U2NoZW1hIiA6IFsKICAgICAgewogICAgICAgICJoYXNTaGFwZUZsZXhpYmlsaXR5IiA6ICIwIiwKICAgICAgICAiaXNPcHRpb25hbCIgOiAiMCIsCiAgICAgICAgImRhdGFUeXBlIiA6ICJGbG9hdDE2IiwKICAgICAgICAiZm9ybWF0dGVkVHlwZSIgOiAiTXVsdGlBcnJheSAoRmxvYXQxNiAxKSIsCiAgICAgICAgInNob3J0RGVzY3JpcHRpb24iIDogIiIsCiAgICAgICAgInNoYXBlIiA6ICJbMV0iLAogICAgICAgICJuYW1lIiA6ICJ5IiwKICAgICAgICAidHlwZSIgOiAiTXVsdGlBcnJheSIKICAgICAgfQogICAgXSwKICAgICJtb2RlbFBhcmFtZXRlcnMiIDogWwoKICAgIF0sCiAgICAic3BlY2lmaWNhdGlvblZlcnNpb24iIDogOSwKICAgICJtbFByb2dyYW1PcGVyYXRpb25UeXBlSGlzdG9ncmFtIiA6IHsKICAgICAgIklvczE4LnJlYWRTdGF0ZSIgOiAyLAogICAgICAiSW9zMTguYWRkIiA6IDEsCiAgICAgICJJZGVudGl0eSIgOiAxLAogICAgICAiSW9zMTgud3JpdGVTdGF0ZSIgOiAxCiAgICB9LAogICAgImNvbXB1dGVQcmVjaXNpb24iIDogIkZsb2F0MTYiLAogICAgImlzVXBkYXRhYmxlIiA6ICIwIiwKICAgICJzdGF0ZVNjaGVtYSIgOiBbCiAgICAgIHsKICAgICAgICAiZGF0YVR5cGUiIDogIkZsb2F0MTYiLAogICAgICAgICJpc09wdGlvbmFsIiA6ICIwIiwKICAgICAgICAiZm9ybWF0dGVkVHlwZSIgOiAiU3RhdGUgKEZsb2F0MTYgMSkiLAogICAgICAgICJzaG9ydERlc2NyaXB0aW9uIiA6ICIiLAogICAgICAgICJzaGFwZSIgOiAiWzFdIiwKICAgICAgICAibmFtZSIgOiAiYWNjIiwKICAgICAgICAidHlwZSIgOiAiU3RhdGUiCiAgICAgIH0KICAgIF0sCiAgICAiYXZhaWxhYmlsaXR5IiA6IHsKICAgICAgIm1hY09TIiA6ICIxNS4wIiwKICAgICAgInR2T1MiIDogIjE4LjAiLAogICAgICAidmlzaW9uT1MiIDogIjIuMCIsCiAgICAgICJ3YXRjaE9TIiA6ICIxMS4wIiwKICAgICAgImlPUyIgOiAiMTguMCIsCiAgICAgICJtYWNDYXRhbHlzdCIgOiAiMTguMCIKICAgIH0sCiAgICAibW9kZWxUeXBlIiA6IHsKICAgICAgIm5hbWUiIDogIk1MTW9kZWxUeXBlX21sUHJvZ3JhbSIKICAgIH0sCiAgICAidXNlckRlZmluZWRNZXRhZGF0YSIgOiB7CiAgICAgICJjb20uZ2l0aHViLmFwcGxlLmNvcmVtbHRvb2xzLnZlcnNpb24iIDogIjkuMCIsCiAgICAgICJjb20uZ2l0aHViLmFwcGxlLmNvcmVtbHRvb2xzLmNvbnZlcnNpb25fZGF0ZSIgOiAiMjAyNi0xMS0xNyIsCiAgICAgICJjb20uZ2l0aHViLmFwcGxlLmNvcmVtbHRvb2xzLnNvdXJjZSIgOiAibWlsaW50ZXJuYWwiCiAgICB9LAogICAgImlucHV0U2NoZW1hIiA6IFsKICAgICAgewogICAgICAgICJoYXNTaGFwZUZsZXhpYmlsaXR5IiA6ICIwIiwKICAgICAgICAiaXNPcHRpb25hbCIgOiAiMCIsCiAgICAgICAgImRhdGFUeXBlIiA6ICJGbG9hdDE2IiwKICAgICAgICAiZm9ybWF0dGVkVHlwZSIgOiAiTXVsdGlBcnJheSAoRmxvYXQxNiAxKSIsCiAgICAgICAgInNob3J0RGVzY3JpcHRpb24iIDogIiIsCiAgICAgICAgInNoYXBlIiA6ICJbMV0iLAogICAgICAgICJuYW1lIiA6ICJ4IiwKICAgICAgICAidHlwZSIgOiAiTXVsdGlBcnJheSIKICAgICAgfQogICAgXSwKICAgICJnZW5lcmF0ZWRDbGFzc05hbWUiIDogImFjYyIsCiAgICAibWV0aG9kIiA6ICJwcmVkaWN0IgogIH0KXQ=="),
    ("model.mil", "cHJvZ3JhbSgxLjMpCltidWlsZEluZm8gPSBkaWN0PHN0cmluZywgc3RyaW5nPih7eyJjb3JlbWxjLWNvbXBvbmVudC1NSUwiLCAiMzYwNS4xLjEifSwgeyJjb3JlbWxjLXZlcnNpb24iLCAiMzYwMC4yNS4xIn0sIHsiY29yZW1sdG9vbHMtY29tcG9uZW50LW1pbGludGVybmFsIiwgIiJ9LCB7ImNvcmVtbHRvb2xzLXZlcnNpb24iLCAiOS4wIn19KV0KewogICAgZnVuYyBtYWluPGlvczE4PihzdGF0ZTx0ZW5zb3I8ZnAxNiwgWzFdPj4gYWNjLCB0ZW5zb3I8ZnAxNiwgWzFdPiB4KSB7CiAgICAgICAgICAgIHRlbnNvcjxmcDE2LCBbMV0+IHJlYWRfc3RhdGVfMCA9IHJlYWRfc3RhdGUoaW5wdXQgPSBhY2MpW25hbWUgPSBzdHJpbmcoInJlYWRfc3RhdGVfMCIpXTsKICAgICAgICAgICAgdGVuc29yPGZwMTYsIFsxXT4gYWRkXzAgPSBhZGQoeCA9IHJlYWRfc3RhdGVfMCwgeSA9IHgpW25hbWUgPSBzdHJpbmcoImFkZF8wIildOwogICAgICAgICAgICB3cml0ZV9zdGF0ZShkYXRhID0gYWRkXzAsIGlucHV0ID0gYWNjKVtuYW1lID0gc3RyaW5nKCJjb3JlbWxfdXBkYXRlX3N0YXRlXzFfd3JpdGVfc3RhdGUiKV07CiAgICAgICAgICAgIHRlbnNvcjxmcDE2LCBbMV0+IGNvcmVtbF91cGRhdGVfc3RhdGVfMSA9IHJlYWRfc3RhdGUoaW5wdXQgPSBhY2MpW25hbWUgPSBzdHJpbmcoImNvcmVtbF91cGRhdGVfc3RhdGVfMSIpXTsKICAgICAgICAgICAgdGVuc29yPGZwMTYsIFsxXT4geSA9IGlkZW50aXR5KHggPSBjb3JlbWxfdXBkYXRlX3N0YXRlXzEpW25hbWUgPSBzdHJpbmcoInkiKV07CiAgICAgICAgfSAtPiAoeSk7Cn0="),
    ("coremldata.bin", "9gEAAAkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAcAAAAAAAAAZ2VuZXJpYwkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA2AAAAAAAAAAKDgoBeBoJKgcKAQEQkIAEUg4KAXkaCSoHCgEBEJCABGoSCgNhY2MaC0IJCgcKAQEQkIAEogagAaIGKwokY29tLmdpdGh1Yi5hcHBsZS5jb3JlbWx0b29scy52ZXJzaW9uEgM5LjCiBjoKLGNvbS5naXRodWIuYXBwbGUuY29yZW1sdG9vbHMuY29udmVyc2lvbl9kYXRlEgoyMDI2LTExLTE3ogYyCiNjb20uZ2l0aHViLmFwcGxlLmNvcmVtbHRvb2xzLnNvdXJjZRILbWlsaW50ZXJuYWz2AQAAAAAAAAAAAAAAAAAA"),
    ("analytics/coremldata.bin", "GQAAAAAAAABOZXVyYWxOZXR3b3JrTW9kZWxEZXRhaWxzAgAAAAAAAAATAAAAAAAAAGNvbnRhaW5zQ3VzdG9tTGF5ZXIBAAAAAAAAADAOAAAAAAAAAG1vZGVsRGltZW5zaW9uAQAAAAAAAAAwFAAAAAAAAABTcGVjaWZpY2F0aW9uRGV0YWlscwIAAAAAAAAACQAAAAAAAABtb2RlbEhhc2gsAAAAAAAAAFZjNVJ4MFp5RVFLZkFJTWprR1ZQSU9qeXRWMUJIdHc2Y0h4VFVDazcxVUk9CQAAAAAAAABtb2RlbE5hbWUFAAAAAAAAAG1vZGVs")
]

/// an ObjC class method `+<sel>:(args...) completionHandler:^(id, NSError *)` called through the runtime (the classes
/// Swift's CoreML overlay shadows with its own enum / structs, and APIs Swift marks unavailable)
func p28ObjCLoad(_ clsName: String, _ selName: String, _ args: [AnyObject]) async throws -> NSObject {
    guard let cls = NSClassFromString(clsName), let m = class_getClassMethod(cls, NSSelectorFromString(selName)) else { throw Fail("no +\(selName) on \(clsName)") }
    let sel = NSSelectorFromString(selName), imp = method_getImplementation(m)
    return try await withCheckedThrowingContinuation { (k: CheckedContinuation<NSObject, Error>) in
        let once = P28Flag()
        let block: @convention(block) (NSObject?, NSError?) -> Void = { o, e in
            guard once.claim() else { return }
            if let o { k.resume(returning: o) } else { k.resume(throwing: e ?? Fail("nil and no error")) }
        }
        let b = unsafeBitCast(block, to: AnyObject.self)
        if args.count == 1 {
            typealias F = @convention(c) (AnyClass, Selector, AnyObject, AnyObject) -> Unmanaged<AnyObject>?
            _ = unsafeBitCast(imp, to: F.self)(cls, sel, args[0], b)
        } else {
            typealias F = @convention(c) (AnyClass, Selector, AnyObject, AnyObject, AnyObject) -> Unmanaged<AnyObject>?
            _ = unsafeBitCast(imp, to: F.self)(cls, sel, args[0], args[1], b)
        }
    }
}
final class P28Flag: @unchecked Sendable {
    private let lock = NSLock(); private var done = false
    func claim() -> Bool { lock.lock(); defer { lock.unlock() }; if done { return false }; done = true; return true }
}
func p28Doubles(_ xs: [Double]) throws -> MLMultiArray {
    let a = try MLMultiArray(shape: [NSNumber(value: xs.count)], dataType: .double); for (i, x) in xs.enumerated() { a[i] = NSNumber(value: x) }; return a
}
func p28ClassName(_ o: Any?) -> String { guard let o = o as AnyObject? else { return "nil" }; return NSStringFromClass(type(of: o)) }
/// Model { pipeline { models [the linear GLM of ML.swift], names ["glm"] } }, same description (x double[2] -> y double)
func p28PipelineSpec() -> Data {
    var arr = PB(); arr.int64s(1, [2]); arr.int(2, 65600)
    var tIn = PB(); tIn.msg(5, arr)
    var tOut = PB(); tOut.msg(2, PB())
    var fIn = PB(); fIn.str(1, "x"); fIn.msg(3, tIn)
    var fOut = PB(); fOut.str(1, "y"); fOut.msg(3, tOut)
    var desc = PB(); desc.msg(1, fIn); desc.msg(10, fOut); desc.str(11, "y")
    var sub = PB(); sub.d = linearModelSpec()
    var pipe = PB(); pipe.msg(1, sub); pipe.str(2, "glm")
    var m = PB(); m.int(1, 4); m.msg(2, desc); m.msg(202, pipe)
    return m.d
}
/// Model { neuralNetwork { relu "act": img (2x2 grayscale image, enumerated sizes 2x2 / 4x4) -> out float32[1, 2, 2] } }
func p28ImageNNSpec() -> Data {
    var s1 = PB(); s1.int(1, 2); s1.int(2, 2)
    var s2 = PB(); s2.int(1, 4); s2.int(2, 4)
    var sizes = PB(); sizes.msg(1, s1); sizes.msg(1, s2)
    var img = PB(); img.int(1, 2); img.int(2, 2); img.int(3, 10); img.msg(21, sizes)
    var tIn = PB(); tIn.msg(4, img)
    var aout = PB(); aout.int64s(1, [1, 2, 2]); aout.int(2, 65568)
    var tOut = PB(); tOut.msg(5, aout)
    var fIn = PB(); fIn.str(1, "img"); fIn.msg(3, tIn)
    var fOut = PB(); fOut.str(1, "out"); fOut.msg(3, tOut)
    var desc = PB(); desc.msg(1, fIn); desc.msg(10, fOut)
    var act = PB(); act.msg(10, PB())
    var layer = PB(); layer.str(1, "act"); layer.str(2, "img"); layer.str(3, "out"); layer.msg(130, act)
    var net = PB(); net.msg(1, layer)
    var m = PB(); m.int(1, 4); m.msg(2, desc); m.msg(500, net)
    return m.d
}
/// Model { glmClassifier { weights [[1, -1]], offset [0], logit, labels [a, b] } }: x double[2] -> label string, probs {string: double}
func p28ClassifierSpec() -> Data {
    var arr = PB(); arr.int64s(1, [2]); arr.int(2, 65600)
    var tIn = PB(); tIn.msg(5, arr)
    var tLabel = PB(); tLabel.msg(3, PB())
    var dict = PB(); dict.msg(2, PB())
    var tProbs = PB(); tProbs.msg(6, dict)
    var fIn = PB(); fIn.str(1, "x"); fIn.msg(3, tIn)
    var fL = PB(); fL.str(1, "label"); fL.msg(3, tLabel)
    var fP = PB(); fP.str(1, "probs"); fP.msg(3, tProbs)
    var desc = PB(); desc.msg(1, fIn); desc.msg(10, fL); desc.msg(10, fP); desc.str(11, "label"); desc.str(12, "probs")
    var w = PB(); w.doubles(1, [1, -1])
    var labels = PB(); labels.str(1, "a"); labels.str(1, "b")
    var glm = PB(); glm.msg(1, w); glm.doubles(2, [0]); glm.msg(100, labels)
    var m = PB(); m.int(1, 1); m.msg(2, desc); m.msg(400, glm)
    return m.d
}
#endif

#if canImport(Vision) && canImport(CoreML) && canImport(CoreImage) && !os(watchOS)
// generic helpers an app writes against Vision's observation protocols
func p28Boxes<O: BoundingBoxProviding>(_ os: [O]) -> [NormalizedRect] { os.map(\.boundingBox) }
func p28Corners<Q: QuadrilateralProviding>(_ q: Q) -> [NormalizedPoint] { [q.topLeft, q.topRight, q.bottomRight, q.bottomLeft] }
func p28Region<R: BoundingRegionProviding>(_ r: R) -> NormalizedRegion { r.boundingRegion }
func p28JointCount<P: PoseProviding>(_ p: P) -> Int { p.allJoints(in: nil).count + p.availableJointNames.count * 0 }
func p28RoundTrips<O: VisionObservation>(_ o: O) throws -> Bool { try JSONDecoder().decode(O.self, from: JSONEncoder().encode(o)) == o }
func p28Latency<R: StatefulRequest>(_ r: R) -> String { "\(r.minimumLatencyFrameCount)/\(r.frameAnalysisSpacing.seconds)" }
func p28IsTargeted<R: VisionRequest>(_ r: R) -> Bool { r is any TargetedRequest }
func p28Status<R: DownloadableAssetsRequest>(_ r: R) async -> DownloadableAssetsRequestStatus { await r.assetStatus }
/// the image NN of p28ImageNNSpec, compiled and loaded
func p28ImageModel() async throws -> MLModel {
    let d = try p7Dir("sdkcov-p28-vision"); let src = d.appendingPathComponent("img.mlmodel"); try p28ImageNNSpec().write(to: src)
    return try MLModel(contentsOf: try await MLModel.compileModel(at: src))
}
#endif

#if canImport(USDKit) && !os(watchOS)
/// an app's generic wrapper over USDKit's value protocol
func p28USDValue<T: USDValueProtocol>(_ x: T) -> USDValue { USDValue(x) }
#endif
#if canImport(GameController)
func p28NameRaw<N: GCPhysicalInputElementTypedName>(_ n: N) -> String { n.rawValue }
func p28Count<T>(_ c: GCPhysicalInputElementCollection<T>) -> Int { c.count }
#endif

#if canImport(RealityKit) && !os(watchOS)
/// an app's own CPU mesh deformer (lowers every vertex by 1 cm), conforming to MeshDeformer
struct P28Lower: MeshDeformer {
    static var type: String { "p28lower" }
    static var mode: MeshDeformerExecutionMode { .cpu }
    var options: MeshDeformerOptions { MeshDeformerOptions(cadence: .everyFrame, inputSpec: [.positions], outputSpec: .positions) }
    func deform(parameter: MeshDeformParameterGPU, encoder: any MTLComputeCommandEncoder) {}
    func deform(parameter: MeshDeformParameterCPU) { P28Lower.calls.add("\(p28VertexCount(parameter))") }
    func isDeformerEqual(other: any MeshDeformer) -> Bool { other is P28Lower }
    static let calls = P28Tally()
}
func p28VertexCount<I, O>(_ p: MeshDeformParameter<I, O>) -> Int { p.inputBuffers.count }
/// generic over the animation state protocol, as an app's action handler is
func p28Progress<S: AnimationStateProtocol>(_ s: S) -> Double { s.normalizedTime }
/// a force effect whose per-step work is a registered handler of ForceEffectEvent
struct P28Drag: ForceEffectProtocol {
    var parameterTypes: PhysicsBodyParameterTypes { [.position, .velocity] }
    var forceMode: ForceMode { .force }
    func update(parameters: inout ForceEffectParameters) {}
    static let seen = P28Tally()
}
#endif

#if canImport(TabletopKit) && os(visionOS)
struct P28Board: Tabletop { let id = EquipmentIdentifier(0); var shape: TabletopShape { .rectangular(width: 1, height: 1, thickness: 0.02) } }
/// a pile that stacks its children (a layout of its own)
struct P28Pile: Equipment {
    let id = EquipmentIdentifier(10)
    var initialState: BaseEquipmentState { BaseEquipmentState(parentID: EquipmentIdentifier(0), boundingBox: Rect3D(center: .zero, size: Size3D(width: 0.1, height: 0.01, depth: 0.1))) }
    func layoutChildren(for snapshot: TableSnapshot, visualState: TableVisualState) -> any EquipmentLayout {
        let ids = snapshot.equipmentIDs(childrenOf: id)
        let poses = ids.enumerated().map { EquipmentPose2D(id: $0.element, pose: .init(position: .init(x: 0, z: Double($0.offset) * 0.01), rotation: .zero)) }
        let layout: DefaultEquipmentLayout = .planarStacked(layout: poses)
        return layout
    }
}
struct P28Card: Equipment { let id: EquipmentIdentifier; var initialState: CardState { .faceDown(parentID: EquipmentIdentifier(10), boundingBox: Rect3D(center: .zero, size: Size3D(width: 0.06, height: 0.001, depth: 0.09))) } }
struct P28Marker: Equipment { let id = EquipmentIdentifier(30); var initialState: RawValueState { RawValueState(rawValue: 7, parentID: EquipmentIdentifier(0), seatControl: .restricted([TableSeatIdentifier(0)]), boundingBox: Rect3D(center: .zero, size: Size3D(width: 0.02, height: 0.02, depth: 0.02))) } }
/// a token with a state of the app's own
struct P28TokenState: CustomEquipmentState, BitwiseCopyable { var base: BaseEquipmentState; var power: Int }
struct P28Token: Equipment { let id = EquipmentIdentifier(20); var initialState: P28TokenState { P28TokenState(base: BaseEquipmentState(parentID: EquipmentIdentifier(0)), power: 1) } }
struct P28SeatA: TableSeat { let id: TableSeatIdentifier; var initialState: TableSeatState { TableSeatState(pose: .identity) } }
/// a custom action: power up the token and score a point
struct P28PowerUp: CustomAction, BitwiseCopyable {
    var by: Int
    static let seen = P28Tally()
    func validate(snapshot: TableSnapshot) -> Bool { by > 0 }
    func apply(table: inout TableState) {
        table.equipment.state[of: P28Token.self, id: EquipmentIdentifier(20)]?.power += by
        let any: (any MutableEquipmentState)? = table.equipment.state[id: EquipmentIdentifier(20)]
        if any != nil { table.counters[ScoreCounter.Identifier(1)] = (table.counters[ScoreCounter.Identifier(1)] ?? 0) + Int64(by) }
        p28ReadCounters(table.counters)
        p28ReadEquipment(table.equipment)
    }
}
func p28ReadCounters(_ c: borrowing CounterCollection) { P28PowerUp.seen.add("counters \(c.count)") }
func p28ReadEquipment(_ e: borrowing EquipmentCollection) { p28ReadStates(e.state); P28PowerUp.seen.add("equipment \(e.count)") }
func p28ReadStates(_ s: borrowing EquipmentStateCollection) { P28PowerUp.seen.add("token parent \(s[id: EquipmentIdentifier(20)].map { p28Parent($0) } ?? -1)") }
/// generic over the state protocols, as an app's rules are
func p28Parent<S: EquipmentState>(_ s: S) -> Int { s.parentID.rawValue }
func p28SeatPlayer<S: SeatState>(_ s: S) -> Bool { s.playerID != nil }
struct P28Peer: Hashable, Identifiable { let id: UUID }
final class P28Coordinator: TabletopNetworkSessionCoordinator {
    typealias Peer = P28Peer
    let log = P28Tally()
    var session: TabletopNetworkSession<P28Coordinator>?
    func coordinateWithSession(_ session: TabletopNetworkSession<P28Coordinator>) { self.session = session; log.add("coordinate") }
    func sendMessage(_ message: Data, to: Set<P28Peer>, completion: @escaping (TabletopSendMessageResult) -> Void) { log.add("send"); completion(TabletopSendMessageResult.success) }
    func sendMessageUnreliably(_ message: Data, to: Set<P28Peer>, completion: @escaping (TabletopSendMessageResult) -> Void) { log.add("unreliable"); completion(.failure) }
    func peerJoinedGame(_ peerID: UUID) { log.add("joined") }
    func peerLeftGame(_ peerID: UUID) { log.add("left") }
}
#endif

extension Registry {
    static var p28mlMore: [Check] {
        var c: [Check] = []
        #if canImport(CoreML)
        c.append(check("CoreML", "p28-model-structure-compute-plan", timeout: 90) {
            var got: [String] = []
            let cfg = MLModelConfiguration(); cfg.computeUnits = .cpuOnly
            // the ML program: structure walked through the ObjC classes (Swift's overlay wraps them in MLModelStructure.Program)
            let acc = try p14WriteModel("p28acc", p28AccumulatorModel)
            let st = try await p28ObjCLoad("MLModelStructure", "loadContentsOfURL:completionHandler:", [acc as NSURL])
            guard let program = st.value(forKey: "program") as? NSObject, let fns = program.value(forKey: "functions") as? [String: NSObject],
                  let main = fns["main"], let block = main.value(forKey: "block") as? NSObject, let ops = block.value(forKey: "operations") as? [NSObject] else {
                throw Fail("structure \(p28ClassName(st)) program \(p28ClassName(st.value(forKey: "program")))")
            }
            var seen = Set([p28ClassName(st), p28ClassName(program), p28ClassName(main), p28ClassName(block)])
            let fnInputs = (main.value(forKey: "inputs") as? [NSObject]) ?? []
            for i in fnInputs { seen.insert(p28ClassName(i)); seen.insert(p28ClassName(i.value(forKey: "type"))) }
            var opNames: [String] = [], consts = 0
            for op in ops {
                seen.insert(p28ClassName(op)); opNames.append(op.value(forKey: "operatorName") as? String ?? "?")
                for (_, arg) in (op.value(forKey: "inputs") as? [String: NSObject]) ?? [:] {
                    seen.insert(p28ClassName(arg))
                    for b in (arg.value(forKey: "bindings") as? [NSObject]) ?? [] {
                        seen.insert(p28ClassName(b)); if let v = b.value(forKey: "value") as? NSObject { seen.insert(p28ClassName(v)); consts += 1 }
                    }
                }
                for o in (op.value(forKey: "outputs") as? [NSObject]) ?? [] { seen.insert(p28ClassName(o)); seen.insert(p28ClassName(o.value(forKey: "type"))) }
            }
            let want: Set = ["MLModelStructure", "MLModelStructureProgram", "MLModelStructureProgramFunction", "MLModelStructureProgramBlock",
                             "MLModelStructureProgramOperation", "MLModelStructureProgramArgument", "MLModelStructureProgramBinding",
                             "MLModelStructureProgramNamedValueType", "MLModelStructureProgramValueType"]
            try expect(want.isSubset(of: seen) && fnInputs.count == 2 && !ops.isEmpty, "program classes \(seen.sorted()) inputs \(fnInputs.count) ops \(opNames)")
            got.append("program main(\(fnInputs.compactMap { $0.value(forKey: "name") as? String })) ops \(opNames), constants \(consts) \(seen.contains("MLModelStructureProgramValue") ? "as values" : "")")
            // its compute plan: per-operation cost and device usage
            // (the stateful program's plan: "Failed to build the model execution plan" -14 on Apple's simulator too)
            var plan: NSObject?
            do { plan = try await p28ObjCLoad("MLComputePlan", "loadContentsOfURL:configuration:completionHandler:", [acc as NSURL, cfg]) }
            catch { got.append("program plan err \((error as NSError).code) \(String(describing: error).contains("-14") ? "-14" : "")") }
            var costs: [String] = [], usages = 0
            for op in ops where plan != nil {
                let plan = plan!
                if let cost = plan.perform(NSSelectorFromString("estimatedCostOfMLProgramOperation:"), with: op)?.takeUnretainedValue() as? NSObject {
                    try expect(p28ClassName(cost) == "MLComputePlanCost", "cost class \(p28ClassName(cost))")
                    costs.append(String(format: "%.2f", (cost.value(forKey: "weight") as? Double) ?? -1))
                }
                if let u = plan.perform(NSSelectorFromString("computeDeviceUsageForMLProgramOperation:"), with: op)?.takeUnretainedValue() as? NSObject {
                    try expect(p28ClassName(u) == "MLComputePlanDeviceUsage" && u.value(forKey: "preferredComputeDevice") != nil, "usage \(p28ClassName(u))")
                    usages += 1
                }
            }
            got.append("plan costs \(costs) usages \(usages)")
            #if !os(watchOS)
            // a neural network's layers and a pipeline's sub-models, compiled here
            let dir = try p7Dir("sdkcov-p28-structure")
            let nnSrc = dir.appendingPathComponent("nn.mlmodel"); try p7NNSpec().write(to: nnSrc)
            let nn = try await MLModel.compileModel(at: nnSrc)
            let nst = try await p28ObjCLoad("MLModelStructure", "loadContentsOfURL:completionHandler:", [nn as NSURL])
            guard let net = nst.value(forKey: "neuralNetwork") as? NSObject, let layers = net.value(forKey: "layers") as? [NSObject], let l0 = layers.first else { throw Fail("no network in \(p28ClassName(nst))") }
            try expect(p28ClassName(net) == "MLModelStructureNeuralNetwork" && p28ClassName(l0) == "MLModelStructureNeuralNetworkLayer"
                       && (l0.value(forKey: "name") as? String) == "dense" && (l0.value(forKey: "outputNames") as? [String]) == ["y"], "network \(p28ClassName(net)) \(p28ClassName(l0))")
            let nplan = try await p28ObjCLoad("MLComputePlan", "loadContentsOfURL:configuration:completionHandler:", [nn as NSURL, cfg])
            let lu = nplan.perform(NSSelectorFromString("computeDeviceUsageForNeuralNetworkLayer:"), with: l0)?.takeUnretainedValue() as? NSObject
            got.append("layer \(l0.value(forKey: "type") ?? "?") usage \(p28ClassName(lu))")
            let pSrc = dir.appendingPathComponent("pipe.mlmodel"); try p28PipelineSpec().write(to: pSrc)
            let pipeURL = try await MLModel.compileModel(at: pSrc)
            let pst = try await p28ObjCLoad("MLModelStructure", "loadContentsOfURL:completionHandler:", [pipeURL as NSURL])
            guard let pipe = pst.value(forKey: "pipeline") as? NSObject else { throw Fail("no pipeline in \(p28ClassName(pst))") }
            let subNames = pipe.value(forKey: "subModelNames") as? [String] ?? [], subs = pipe.value(forKey: "subModels") as? [NSObject] ?? []
            try expect(p28ClassName(pipe) == "MLModelStructurePipeline" && subNames == ["glm"] && subs.count == 1, "pipeline \(subNames) \(subs.count)")
            // the same through Swift's overlay
            if case .pipeline(let sp) = try await MLModelStructure.load(contentsOf: pipeURL) { got.append("pipeline \(sp.subModelNames)") }
            let pm = try MLModel(contentsOf: pipeURL)
            let y = try await pm.prediction(from: MLDictionaryFeatureProvider(dictionary: ["x": try p28Doubles([1, 2])])).featureValue(for: "y")?.doubleValue
            try expect(y == 8.5, "pipeline predicts \(String(describing: y))")
            #endif
            return got.joined(separator: ", ")
        })
        c.append(check("CoreML", "p28-feature-constraints-collection", timeout: 90) {
            var got: [String] = []
            // a state's constraint (the ML program's fp16 accumulator)
            let cpu = MLModelConfiguration(); cpu.computeUnits = .cpuOnly
            // (default compute units: "Failed to build the model execution plan", -14, on Apple's simulator too)
            let acc = try MLModel(contentsOf: try p14WriteModel("p28acc", p28AccumulatorModel), configuration: cpu)
            guard let sc: MLStateConstraint = acc.modelDescription.stateDescriptionsByName["acc"]?.stateConstraint else { throw Fail("no state constraint") }
            try expect(sc.bufferShape == [1] && sc.dataType == .float16, "state constraint \(sc.bufferShape) \(sc.dataType.rawValue)")
            let back = try NSKeyedUnarchiver.unarchivedObject(ofClass: MLStateConstraint.self, from: try NSKeyedArchiver.archivedData(withRootObject: sc, requiringSecureCoding: true))
            got.append("state \(sc.bufferShape) fp16, coded \(back?.bufferShape ?? [])")
            // MLSequenceConstraint: only a sequence feature's description has one (word taggers / recommenders, no model of
            // those can be written here): the class as the runtime has it
            let seqCls: AnyClass = MLSequenceConstraint.self
            try expect(MLSequenceConstraint.supportsSecureCoding && class_getInstanceMethod(seqCls, #selector(getter: MLSequenceConstraint.countRange)) != nil, "sequence constraint class")
            #if !os(watchOS)
            let dir = try p7Dir("sdkcov-p28-constraints")
            // an image input with enumerated sizes
            let iSrc = dir.appendingPathComponent("img.mlmodel"); try p28ImageNNSpec().write(to: iSrc)
            let im = try MLModel(contentsOf: try await MLModel.compileModel(at: iSrc))
            guard let ic: MLImageConstraint = im.modelDescription.inputDescriptionsByName["img"]?.imageConstraint else { throw Fail("no image constraint") }
            let szc: MLImageSizeConstraint = ic.sizeConstraint
            let sizes: [MLImageSize] = szc.enumeratedImageSizes
            try expect(ic.pixelsWide == 2 && ic.pixelsHigh == 2 && ic.pixelFormatType == kCVPixelFormatType_OneComponent8 && szc.type == .enumerated
                       && sizes.map { "\($0.pixelsWide)x\($0.pixelsHigh)" } == ["2x2", "4x4"], "image constraint \(ic.pixelsWide)x\(ic.pixelsHigh) \(szc.type.rawValue) \(sizes.count)")
            // a feature value from a CGImage that fits the constraint, a prediction through it
            let ctx = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0)!
            ctx.setFillColor(gray: 0.5, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
            let fv = try MLFeatureValue(cgImage: ctx.makeImage()!, constraint: ic)
            let out = try await im.prediction(from: MLDictionaryFeatureProvider(dictionary: ["img": fv])).featureValue(for: "out")?.multiArrayValue
            got.append("image \(sizes.count) sizes, relu out \(out.map { "\($0.shape) \($0[0])" } ?? "nil")")
            // a classifier's probability dictionary
            let cSrc = dir.appendingPathComponent("cls.mlmodel"); try p28ClassifierSpec().write(to: cSrc)
            let cm = try MLModel(contentsOf: try await MLModel.compileModel(at: cSrc))
            guard let dc: MLDictionaryConstraint = cm.modelDescription.outputDescriptionsByName["probs"]?.dictionaryConstraint else { throw Fail("no dictionary constraint") }
            let p = try await cm.prediction(from: MLDictionaryFeatureProvider(dictionary: ["x": try p28Doubles([3, 1])]))
            let probs = p.featureValue(for: "probs")?.dictionaryValue ?? [:]
            try expect(dc.keyType == .string && probs.count == 2, "dictionary constraint \(dc.keyType.rawValue) probs \(probs)")
            got.append("classifier \(p.featureValue(for: "label")?.stringValue ?? "?") \(probs.keys.map { "\($0)" }.sorted())")
            #endif
            // MLModelCollection (sunset since iOS 17.4, Swift marks it unavailable): the runtime still answers
            #if os(iOS) || os(visionOS)
            let ans = await p27sAnswer(15) {
                let col = try await p28ObjCLoad("MLModelCollection", "beginAccessingModelCollectionWithIdentifier:completionHandler:", ["p28-none" as NSString])
                let entries = col.value(forKey: "entries") as? [String: NSObject] ?? [:]
                return "\(p28ClassName(col)) \(entries.count) entries \(entries.values.map { p28ClassName($0) })"
            }
            let entryCls: AnyClass? = NSClassFromString("MLModelCollectionEntry")
            got.append("collection: \(ans.prefix(90)), entry class \(entryCls.map { class_getInstanceMethod($0, NSSelectorFromString("modelURL")) != nil } ?? false)")
            #endif
            return got.joined(separator: ", ")
        })
        #endif
        #if canImport(Vision) && canImport(CoreML) && canImport(CoreImage) && !os(watchOS)
        c.append(check("Vision", "p28-swift-detectors", timeout: 60) {
            func part(_ name: String, _ secs: Double, _ body: @escaping @Sendable () async throws -> [String: String]) async -> [String: String] {
                do { return try await p27sWithin(secs, body) ?? [name: "no answer in \(Int(secs)) s"] } catch { return [name: "threw \((error as NSError).code)"] }
            }
            var got: [String: String] = [:]
            got.merge(await part("performAll", 40) {
                let img = try p27VisionImage(shift: 0)
                var g: [String: String] = [:]
                let reqs: [any VisionRequest] = [DetectFaceRectanglesRequest(), DetectHumanRectanglesRequest(), DetectHumanBodyPoseRequest(), DetectHumanHandPoseRequest(),
                                                ClassifyImageRequest(), CalculateImageAestheticsScoresRequest(), GenerateAttentionBasedSaliencyImageRequest(),
                                                GenerateObjectnessBasedSaliencyImageRequest(), RecognizeAnimalsRequest(), DetectFaceLandmarksRequest()]
                for await r in ImageRequestHandler(img).performAll(reqs) {
                    let res: VisionResult = r
                    switch res {
                    case .detectFaceRectangles(_, let o): let f: [FaceObservation] = o; g["faces"] = "\(p28Boxes(f).count)"
                    case .detectFaceLandmarks(_, let o): g["landmarks"] = "\(o.count)"
                    case .detectHumanRectangles(_, let o): let h: [HumanObservation] = o; g["humans"] = "\(p28Boxes(h).count)"
                    case .detectHumanBodyPose(_, let o): let b: [HumanBodyPoseObservation] = o; g["body"] = "\(b.map(p28JointCount))"
                    case .detectHumanHandPose(_, let o): let h: [HumanHandPoseObservation] = o; g["hands"] = "\(h.map(p28JointCount))"
                    case .classifyImage(_, let o): let cl: [ClassificationObservation] = o; g["classes"] = cl.isEmpty ? "0" : "some"
                    case .calculateImageAestheticsScores(_, let o): let a: ImageAestheticsScoresObservation = o; g["aesthetics"] = "utility \(a.isUtility) codable \(try p28RoundTrips(a))"
                    case .generateAttentionBasedSaliencyImage(_, let o):
                        let si: SaliencyImageObservation = o; let pb: PixelBufferObservation = si.heatMap
                        g["attention"] = "\(si.salientObjects.count) heat \(Int(pb.size.width))x\(Int(pb.size.height))"
                        if let q = si.salientObjects.first { g["quad"] = "\(p28Corners(q).count) codable \(try p28RoundTrips(q))" }
                    case .generateObjectnessBasedSaliencyImage(_, let o): g["objectness"] = "\(o.salientObjects.count)"
                    case .recognizeAnimals(_, let o): let ro: [RecognizedObjectObservation] = o; g["animals"] = "\(p28Boxes(ro).count)"
                    case .error(let req, let err): g["\(type(of: req))"] = "err:\((err as? VisionError).map { "\($0)".prefix(while: { $0 != "(" }) } ?? "\((err as NSError).code)")"
                    default: g["other"] = "\(res)".prefix(30).description
                    }
                }
                return g
            }) { a, _ in a }
            return got.keys.sorted().map { "\($0)=\(got[$0]!)" }.joined(separator: " ")
        })
        c.append(check("Vision", "p28-swift-trackers", timeout: 60) {
            func part(_ name: String, _ secs: Double, _ body: @escaping @Sendable () async throws -> [String: String]) async -> [String: String] {
                do { return try await p27sWithin(secs, body) ?? [name: "no answer in \(Int(secs)) s"] } catch { return [name: "threw \((error as NSError).code)"] }
            }
            var got: [String: String] = [:]
            let tt = TrackTranslationalImageRegistrationRequest(), tf = TrackOpticalFlowRequest(), tj = DetectTrajectoriesRequest(trajectoryLength: 5)
            try expect(p28IsTargeted(tt) && p28IsTargeted(tf) && !p28IsTargeted(tj), "targeted requests")
            got.merge(await part("trackers", 40) {
                let img = try p27VisionImage(shift: 0), moved = try p27VisionImage(shift: 8)
                var g: [String: String] = [:]
                let trans = TrackTranslationalImageRegistrationRequest(), homo = TrackHomographicImageRegistrationRequest(), flow = TrackOpticalFlowRequest()
                let traj = DetectTrajectoriesRequest(trajectoryLength: 5)
                let track = TrackObjectRequest(detectedObject: DetectedObjectObservation(boundingBox: NormalizedRect(x: 0.6, y: 0.4, width: 0.3, height: 0.4)))
                g["latency"] = [p28Latency(trans), p28Latency(traj), p28Latency(track)].joined(separator: " ")
                var ta: ImageTranslationAlignmentObservation?, ha: ImageHomographicAlignmentObservation?, of: OpticalFlowObservation?, tjs: [TrajectoryObservation] = [], to: DetectedObjectObservation?
                for frame in [img, moved, moved] {
                    do { ta = try await trans.perform(on: frame) } catch { g["trans"] = "err \((error as NSError).code)" }
                    do { ha = try await homo.perform(on: frame) } catch { g["homo"] = "err \((error as NSError).code)" }
                    do { of = try await flow.perform(on: frame) } catch { g["flow"] = "err \((error as NSError).code)" }
                    do { tjs = try await traj.perform(on: frame) } catch { g["traj"] = "err \((error as NSError).code)" }
                }
                if let ta { g["trans"] = "tx \(Int(ta.alignmentTransform.tx.rounded()))" }
                if let ha { g["homo"] = "h \(ha.warpTransform.columns.2.z == 0 ? "0" : "set")" }
                if let of { g["flow"] = "\(Int(of.size.width))x\(Int(of.size.height))" }
                // (TrackObjectRequest.perform ends the app on Apple's iOS 27.2 simulator, on the first frame: not called)
                g["track"] = "box x \(String(format: "%.2f", track.inputObservation.boundingBox.origin.x))"; _ = to
                g["traj"] = g["traj"] ?? "\(tjs.count)"
                return g
            }) { a, _ in a }
            return got.keys.sorted().map { "\($0)=\(got[$0]!)" }.joined(separator: " ")
        })
        c.append(check("Vision", "p28-swift-coreml-request-joint", timeout: 60) {
            func part(_ name: String, _ secs: Double, _ body: @escaping @Sendable () async throws -> [String: String]) async -> [String: String] {
                do { return try await p27sWithin(secs, body) ?? [name: "no answer in \(Int(secs)) s"] } catch { return [name: "threw \((error as NSError).code)"] }
            }
            var got: [String: String] = [:]
            got.merge(await part("coreml", 30) {
                let model = try await p28ImageModel()
                let container = try CoreMLModelContainer(model: model)
                var ml = CoreMLRequest(model: container); ml.cropAndScaleAction = .scaleToFill
                let mo = try await ml.perform(on: try p27VisionImage(shift: 0))
                let fvo = mo.first as? CoreMLFeatureValueObservation
                let ok = container.inputImageFeatureName == "img" && ImageCropAndScaleAction.allCases.count == 5 && fvo?.featureName == "out"
                return ["coreml": "\(ok) \(fvo?.featureValue.shapedArrayValue(of: Float.self)?.shape ?? [])"]
            }) { a, _ in a }
            let j = Joint3D(position: matrix_identity_float4x4, localPosition: matrix_identity_float4x4, identifer: "root", parentJoint: "")
            try expect(try JSONDecoder().decode(Joint3D.self, from: JSONEncoder().encode(j)) == j && j.identifier == "root", "joint 3D")
            let rgn: (any BoundingRegionProviding)? = nil; _ = rgn.map { p28Region($0) }
            try expect(got["coreml"]?.hasPrefix("true") ?? false, "core ML request \(got["coreml"] ?? "nil")")
            return got.keys.sorted().map { "\($0)=\(got[$0]!)" }.joined(separator: " ")
        })
        c.append(check("Vision", "p28-swift-downloadable-assets", timeout: 30) {
            func part(_ name: String, _ secs: Double, _ body: @escaping @Sendable () async throws -> [String: String]) async -> [String: String] {
                do { return try await p27sWithin(secs, body) ?? [name: "no answer in \(Int(secs)) s"] } catch { return [name: "threw \((error as NSError).code)"] }
            }
            var got: [String: String] = [:]
            got.merge(await part("assets", 15) {
                let seg = GenerateIterativeSegmentationRequest(seedPoint: NormalizedPoint(x: 0.5, y: 0.5))
                return ["assets": "\(await p28Status(seg))".prefix(40).description]
            }) { a, _ in a }
            return got.keys.sorted().map { "\($0)=\(got[$0]!)" }.joined(separator: " ")
        })
        c.append(check("Vision", "p28-vn-coreml-text-video", timeout: 120) {
            var got: [String] = []
            let img = try p27VisionImage(shift: 0)
            // VNCoreMLModel / VNCoreMLRequest on the app's own image model
            let vm = try VNCoreMLModel(for: try await p28ImageModel())
            let creq = VNCoreMLRequest(model: vm); creq.imageCropAndScaleOption = .scaleFill
            let treq = VNRecognizeTextRequest(); treq.recognitionLevel = .fast
            let reg: VNImageRegistrationRequest = VNTranslationalImageRegistrationRequest(targetedCGImage: img)
            try VNImageRequestHandler(cgImage: img).perform([creq, treq, reg])
            let fv = creq.results?.first as? VNCoreMLFeatureValueObservation
            try expect(fv?.featureName == "out" && vm.inputImageFeatureName == "img", "VNCoreMLRequest \(String(describing: creq.results))")
            let texts: [VNRecognizedText] = (treq.results ?? []).compactMap { $0.topCandidates(1).first }
            let words = texts.map(\.string).joined(separator: " ")
            let range = texts.first.flatMap { t in try? t.boundingBox(for: t.string.startIndex..<t.string.endIndex) }
            try expect(words.contains("VISION"), "recognized text '\(words)'")
            got.append("coreml \(fv?.featureValue.multiArrayValue?.shape ?? []), text '\(words)' box \(range != nil), registration \((reg.results?.first as? VNImageTranslationAlignmentObservation).map { Int($0.alignmentTransform.tx) } ?? -1)")
            // a 30-frame movie through VNVideoProcessor at two cadences
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("p28-video.mov")
            try await writeMovie(url, frames: 30, size: 128)
            defer { try? FileManager.default.removeItem(at: url) }
            let frames = P28Tally()
            let rect = VNDetectRectanglesRequest { r, _ in frames.add("\(r.results?.count ?? -1)") }
            let vp = VNVideoProcessor(url: url)
            let opts = VNVideoProcessor.RequestProcessingOptions()
            let cad: VNVideoProcessor.Cadence = VNVideoProcessor.FrameRateCadence(10)
            opts.cadence = cad
            try vp.addRequest(rect, processingOptions: opts)
            try vp.analyze(CMTimeRange(start: .zero, duration: CMTime(value: 1, timescale: 1)))
            let n1 = frames.all.count; frames.reset()
            let vp2 = VNVideoProcessor(url: url)
            let opts2 = VNVideoProcessor.RequestProcessingOptions(); let tic = VNVideoProcessor.TimeIntervalCadence(0.5); opts2.cadence = tic
            try vp2.addRequest(rect, processingOptions: opts2)
            try vp2.analyze(CMTimeRange(start: .zero, duration: CMTime(value: 1, timescale: 1)))
            let n2 = frames.all.count
            let classes = [p28ClassName(cad), p28ClassName(tic), p28ClassName(opts)]
            try expect(classes == ["VNVideoProcessorFrameRateCadence", "VNVideoProcessorTimeIntervalCadence", "VNVideoProcessorRequestProcessingOptions"]
                       && p27sIsSub(type(of: cad), NSClassFromString("VNVideoProcessorCadence")!), "cadence classes \(classes)")
            got.append("video frames at 10 fps \(n1), every 0.5 s \(n2)")
            return got.joined(separator: ", ")
        })
        #endif
        #if canImport(ARKit) && os(iOS)
        c.append(check("ARKit", "p28-values-views-classes", timeout: 60) {
            try await p2Main {
                var got: [String] = []
                // anchors an app makes itself: copy and secure-coding round trip
                let t = simd_float4x4(SIMD4(1, 0, 0, 0), SIMD4(0, 1, 0, 0), SIMD4(0, 0, 1, 0), SIMD4(0.5, 1, -2, 1))
                let a = ARAnchor(name: "p28", transform: t)
                let probe = AREnvironmentProbeAnchor(name: "probe", transform: t, extent: [1, 2, 3])
                let geo = ARGeoAnchor(name: "geo", coordinate: CLLocationCoordinate2D(latitude: 37.33, longitude: -122.01), altitude: 10)
                let anchors: [ARAnchor] = [a, probe, geo]
                var coded = 0
                for x in anchors {
                    let d = try NSKeyedArchiver.archivedData(withRootObject: x, requiringSecureCoding: true)
                    if let b = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARAnchor.self, from: d), b.identifier == x.identifier, b.name == x.name, b.transform == x.transform { coded += 1 }
                }
                let copy = probe.copy() as? AREnvironmentProbeAnchor
                // a geo anchor made outside a geo-tracking session keeps no coordinate (Apple's simulator: latitude 0)
                try expect(coded == 3 && copy?.extent == [1, 2, 3] && geo.coordinate.latitude == 0, "anchors coded \(coded) extent \(String(describing: copy?.extent)) lat \(geo.coordinate.latitude)")
                got.append("geo altitude \(geo.altitude.map { "\($0)" } ?? "nil") session \(a.sessionIdentifier == nil ? "nil" : "set")")
                got.append("anchors coded \(coded), geo altitude source \(geo.altitudeSource.rawValue)")
                // a reference image from a picture, a raycast query, the default skeletons
                let ctx = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 256, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                ctx.setFillColor(red: 1, green: 0, blue: 0, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: 32, height: 64))
                let ref = ARReferenceImage(ctx.makeImage()!, orientation: .up, physicalWidth: 0.2); ref.name = "card"
                try expect(ref.name == "card" && abs(ref.physicalSize.width - 0.2) < 1e-6 && abs(ref.physicalSize.height - 0.2) < 1e-6, "reference image \(ref.physicalSize)")
                let none = ARReferenceImage.referenceImages(inGroupNamed: "p28-none", bundle: nil)
                let q = ARRaycastQuery(origin: [0, 0, 0], direction: [0, 0, -1], allowing: .estimatedPlane, alignment: .horizontal)
                got.append("raycast query dir \(q.direction) target \(q.target.rawValue) alignment \(q.targetAlignment.rawValue)")
                let s3 = ARSkeletonDefinition.defaultBody3D, s2 = ARSkeletonDefinition.defaultBody2D
                let head = s3.index(for: .head)
                got.append("reference group \(none == nil ? "nil" : "\(none!.count)"), skeleton 3D \(s3.jointCount) joints head \(head != NSNotFound) 2D \(s2.jointCount)")
                // a reference object from a file that is not one: the error
                let bad = FileManager.default.temporaryDirectory.appendingPathComponent("p28.arobject"); try Data("x".utf8).write(to: bad)
                do { _ = try ARReferenceObject(archiveURL: bad); got.append("reference object made") } catch { got.append("reference object err \((error as NSError).domain) \((error as NSError).code)") }
                // the views: an SCNView / SKView with their sessions, the coaching overlay, the SceneKit geometries
                let scn = ARSCNView(frame: CGRect(x: 0, y: 0, width: 100, height: 100)), sk = ARSKView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
                let coach = ARCoachingOverlayView(frame: .zero); coach.goal = .horizontalPlane; coach.session = scn.session
                got.append("coaching goal \(coach.goal.rawValue)")
                got.append("coaching session same \(coach.session === scn.session) active \(coach.isActive)")
                let dev = MTLCreateSystemDefaultDevice()
                let face = dev.flatMap { ARSCNFaceGeometry(device: $0) }, plane = dev.flatMap { ARSCNPlaneGeometry(device: $0) }
                let hits = scn.hitTest(CGPoint(x: 50, y: 50), types: .featurePoint)
                let rq = scn.raycastQuery(from: CGPoint(x: 50, y: 50), allowing: .estimatedPlane, alignment: .any)
                got.append("views: sk session \(sk.session !== scn.session), face geometry \(face == nil ? "nil" : "made"), plane geometry \(plane == nil ? "nil" : "made"), hits \(hits.count), raycast query \(rq == nil ? "nil" : "made")")
                if let dev { let mg = ARMatteGenerator(device: dev, matteResolution: .half); got.append("matte generator \(type(of: mg))") }
                // what a running session would hand over: the class tree as ARKit has it (nothing tracks in a simulator)
                let tree: [(AnyClass, AnyClass)] = [
                    (ARAppClipCodeAnchor.self, ARAnchor.self), (ARBodyAnchor.self, ARAnchor.self), (ARFaceAnchor.self, ARAnchor.self), (ARImageAnchor.self, ARAnchor.self),
                    (ARMeshAnchor.self, ARAnchor.self), (ARObjectAnchor.self, ARAnchor.self), (ARParticipantAnchor.self, ARAnchor.self), (ARPlaneAnchor.self, ARAnchor.self),
                    (ARDirectionalLightEstimate.self, ARLightEstimate.self), (ARSkeleton2D.self, ARSkeleton.self), (ARSkeleton3D.self, ARSkeleton.self),
                    (ARWorldTrackingConfiguration.self, ARConfiguration.self), (ARSCNView.self, SCNView.self), (ARSKView.self, SKView.self),
                    (ARSCNFaceGeometry.self, SCNGeometry.self), (ARSCNPlaneGeometry.self, SCNGeometry.self),
                ]
                let wrong = tree.filter { !p27sIsSub($0.0, $0.1) }.map { "\($0.0)" }
                let coding: [(String, Bool)] = [("ARWorldMap", ARWorldMap.supportsSecureCoding), ("ARPlaneExtent", ARPlaneExtent.supportsSecureCoding),
                    ("ARFaceGeometry", ARFaceGeometry.supportsSecureCoding), ("ARGeoTrackingStatus", ARGeoTrackingStatus.supportsSecureCoding),
                    ("ARPointCloud", ARPointCloud.supportsSecureCoding), ("ARCollaborationData", ARSession.CollaborationData.supportsSecureCoding)]
                let plain: [AnyClass] = [ARBody2D.self, ARCamera.self, ARDepthData.self, ARFrame.self, ARGeometryElement.self, ARGeometrySource.self, ARHitTestResult.self,
                                         ARMeshGeometry.self, ARPlaneGeometry.self, ARRaycastResult.self, ARTrackedRaycast.self, ARConfiguration.VideoFormat.self]
                // (Apple's iOS 27.2 simulator: ARWorldMap, ARFaceGeometry, ARPointCloud and ARCollaborationData answer supportsSecureCoding false)
                let codingWant = ["ARPlaneExtent", "ARGeoTrackingStatus"]
                try expect(wrong.isEmpty && coding.filter(\.1).map(\.0) == codingWant && plain.allSatisfy { p27sIsSub($0, NSObject.self) }
                           && NSClassFromString("ARCollaborationData") === ARSession.CollaborationData.self && NSClassFromString("ARVideoFormat") === ARConfiguration.VideoFormat.self, "class tree \(wrong) coding \(coding.filter(\.1).map(\.0))")
                let formats: [ARConfiguration.VideoFormat] = ARWorldTrackingConfiguration.supportedVideoFormats
                let faceShape = ARFaceGeometry(blendShapes: [.jawOpen: 0.5])
                got.append("\(tree.count) subclasses, \(coding.count) secure-coding classes, \(plain.count) plain; video formats \(formats.count), face geometry from blend shapes \(faceShape == nil ? "nil" : "made")")
                return got.joined(separator: ", ")
            }
        })
        #endif
        #if canImport(USDKit) && !os(watchOS)
        c.append(check("USDKit", "p28-prims-transform-ops-values", timeout: 30) {
            let stage = try USDStage(string: """
            #usda 1.0
            def Xform "World"
            {
                double3 xformOp:translate = (1, 2, 3)
                double[] vals = [1, 2, 3]
                uniform token[] xformOpOrder = ["xformOp:translate"]
                def Cube "Box"
                {
                    double size = 2
                }
            }
            """)
            let world: USDPrim = stage.prim(at: USDLayer.Path("/World"))
            let ops: [USDTransformOperation] = world.transformOperations
            guard let op = ops.first else { throw Fail("no transform operations") }
            let m = world.transform()
            let tx = m.map { $0.projectiveTransform.matrix.columns.3 }
            try expect(op.kind == .translate && op.name.string == "xformOp:translate" && !op.isInverse && op.precision == .double && tx?.x == 1 && tx?.z == 3,
                       "op \(String(describing: op.kind)) \(op.name.string) translation \(String(describing: tx))")
            world.addTransformOperation(type: .scale)
            let names = world.transformOperations.map(\.baseName.string)
            // tokens, values and arrays through USDValueProtocol
            let tok = USDToken("p28"), empty = USDToken()
            let v = p28USDValue(2.5), tv = p28USDValue(tok)
            let arr: USDArray<Double> = [1, 2, 3]
            var arr2 = USDArray<Double>(); arr2.append(4)
            let attr = world.attribute(named: "vals")
            let read: USDArray<Double>? = attr.value()
            let wrote = attr.setValue(arr2)
            let back: USDArray<Double>? = attr.value()
            try expect(tok.string == "p28" && empty.isEmpty && v.value(as: Double.self) == 2.5 && tv.isHolding(USDToken.self) && arr.count == 3 && arr2[0] == 4
                       && read.map { Array($0) } == [1, 2, 3] && wrote && back.map { Array($0) } == [4], "values \(v.typeName) read \(String(describing: read.map { Array($0) }))")
            let box: USDPrim = world.children.first ?? USDPrim()
            return "op \(op.name.string) + \(names), values \(v.typeName) / \(tv.typeName), array attribute [1, 2, 3] -> [4], child \(box.path.description) valid \(box.isValid)"
        })
        #endif
        #if canImport(ModelIO) && canImport(MetalKit) && !os(watchOS)
        c.append(check("ModelIO", "p28-animated-vectors-material-graph", timeout: 30) {
            let v2 = MDLAnimatedVector2(); v2.setFloat2([1, 2], atTime: 0); v2.setFloat2([3, 4], atTime: 1)
            let v4 = MDLAnimatedVector4(); v4.setFloat4([0, 0, 0, 1], atTime: 0); v4.setFloat4([2, 2, 2, 1], atTime: 2)
            let mid2 = v2.float2Value(atTime: 0.5), mid4 = v4.float4Value(atTime: 1)
            try expect(v2.timeSampleCount == 2 && abs(mid2.x - 2) < 1e-5 && abs(mid4.x - 1) < 1e-5, "animated vectors \(mid2) \(mid4)")
            // a material property graph: a node whose evaluation scales its input into its output
            let inp = MDLMaterialProperty(name: "in", semantic: .userDefined, float: 2)
            let out = MDLMaterialProperty(name: "out", semantic: .userDefined, float: 0)
            let node = MDLMaterialPropertyNode(inputs: [inp], outputs: [out]) { n in n.outputs[0].floatValue = n.inputs[0].floatValue * 3 }
            node.evaluationFunction(node)
            try expect(out.floatValue == 6, "node out \(out.floatValue)")
            // a graph over a node whose properties it was made with: Apple's simulator raises ModelIOException "input cannot be
            // assigned to multiple nodes"; an empty graph is made
            var graphAnswer = "made"
            let exc = SDKCovCatch { _ = MDLMaterialPropertyGraph(nodes: [node], connections: []) }
            if let exc { graphAnswer = exc.joined(separator: ": ").prefix(80).description }
            let empty = MDLMaterialPropertyGraph(nodes: [], connections: [])
            empty.evaluate()
            try expect(empty.nodes.isEmpty && empty.connections.isEmpty, "empty graph")
            return "vector2 at 0.5 \(mid2), vector4 at 1 \(mid4), node out \(out.floatValue), graph over it: \(graphAnswer)"
        })
        c.append(check("MetalKit", "p28-mesh-buffers-submeshes", timeout: 30) {
            guard let dev = MTLCreateSystemDefaultDevice() else { throw Fail("no Metal device") }
            let alloc = MTKMeshBufferAllocator(device: dev)
            let mdl = MDLMesh(boxWithExtent: [1, 1, 1], segments: [1, 1, 1], inwardNormals: false, geometryType: .triangles, allocator: alloc)
            let mesh = try MTKMesh(mesh: mdl, device: dev)
            let vb: [MTKMeshBuffer] = mesh.vertexBuffers
            let sub: [MTKSubmesh] = mesh.submeshes
            try expect(!vb.isEmpty && vb[0].length > 0 && vb[0].type == .vertex && sub.first?.indexCount == 36 && sub.first?.indexBuffer.type == .index && sub.first?.primitiveType == .triangle,
                       "mesh \(vb.count) buffers \(sub.map(\.indexCount))")
            return "\(mesh.vertexCount) vertices in \(vb.count) buffer(s) (\(vb[0].length) B), \(sub.count) submesh of \(sub[0].indexCount) indices"
        })
        c.append(check("Metal", "p28-rate-map-arrays-shared-handle", timeout: 30) {
            guard let dev = MTLCreateSystemDefaultDevice() else { throw Fail("no Metal device") }
            let h: [Float] = [1, 0.5], v: [Float] = [0.5, 1]
            let layer = MTLRasterizationRateLayerDescriptor(__sampleCount: MTLSize(width: 2, height: 2, depth: 0), horizontal: h, vertical: v)
            let samples: MTLRasterizationRateSampleArray = layer.horizontal
            samples[1] = 0.25
            let desc = MTLRasterizationRateMapDescriptor(screenSize: MTLSize(width: 256, height: 256, depth: 0), layer: layer)
            let layers: MTLRasterizationRateLayerArray = desc.layers
            try expect(samples[0] == 1 && layer.horizontal[1] == 0.25 && layer.vertical[0] == 0.5 && desc.layerCount == 1 && layers[0] != nil, "rate map arrays")
            let supported = dev.supportsRasterizationRateMap(layerCount: 1)
            var hd = "-"
            #if os(visionOS)
            // a shared handle of a private texture: the visionOS headers have the class, Swift marks it unavailable (the runtime's answer)
            let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 8, height: 8, mipmapped: false); td.storageMode = .private
            let tex = dev.makeTexture(descriptor: td) as? NSObject
            let sel = NSSelectorFromString("newSharedTextureHandle")
            let handle = (tex?.responds(to: sel) ?? false) ? tex?.perform(sel)?.takeRetainedValue() : nil
            let hcls: AnyClass? = NSClassFromString("MTLSharedTextureHandle")
            hd = "\(hcls == nil ? "no class" : "class") handle \(p28ClassName(handle))"
            #endif
            return "rate map supported \(supported), samples [1, 0.25], shared handle \(hd)"
        })
        #endif
        #if canImport(GameplayKit)
        c.append(check("GameplayKit", "p28-composite-behavior", timeout: 30) {
            let seek = GKBehavior(goal: GKGoal(toWander: 1), weight: 1)
            let avoid = GKBehavior(goal: GKGoal(toReachTargetSpeed: 5), weight: 2)
            let comp = GKCompositeBehavior(behaviors: [seek, avoid], andWeights: [1, 0.5])
            comp.setWeight(0.25, for: avoid)
            let agent = GKAgent2D(); agent.behavior = comp; agent.maxSpeed = 10; agent.maxAcceleration = 5; agent.mass = 1
            for _ in 0..<30 { agent.update(deltaTime: 1.0 / 30) }
            try expect(comp.behaviorCount == 2 && comp.weight(for: avoid) == 0.25 && comp[0] === seek && agent.speed > 0, "composite \(comp.behaviorCount) speed \(agent.speed)")
            return "composite of \(comp.behaviorCount), agent speed \(String(format: "%.2f", agent.speed)) after 1 s"
        })
        #endif
        #if canImport(GLKit) && (os(iOS) || os(tvOS))
        c.append(check("GLKit", "p28-effects-textures-meshes", timeout: 30) {
            try await onMain {
                guard let ctx = EAGLContext(api: .openGLES2) else { throw Fail("no EAGLContext") }
                EAGLContext.setCurrent(ctx); defer { EAGLContext.setCurrent(nil) }
                let eff = GLKBaseEffect()
                let light: GLKEffectPropertyLight = eff.light0; light.enabled = GLboolean(GL_TRUE); light.diffuseColor = GLKVector4Make(1, 0, 0, 1)
                let mat: GLKEffectPropertyMaterial = eff.material; mat.shininess = 12
                let fog: GLKEffectPropertyFog = eff.fog; fog.enabled = GLboolean(GL_TRUE); fog.end = 5
                let tx: GLKEffectPropertyTexture = eff.texture2d0
                let tr: GLKEffectPropertyTransform = eff.transform; tr.modelviewMatrix = GLKMatrix4MakeTranslation(1, 2, 3)
                let props: [GLKEffectProperty] = [light, mat, fog, tx, tr]
                eff.prepareToDraw()
                try expect(light.diffuseColor.x == 1 && mat.shininess == 12 && fog.end == 5 && tr.modelviewMatrix.m30 == 1 && props.count == 5, "base effect")
                let refl = GLKReflectionMapEffect(); refl.matrix = GLKMatrix3Identity
                let sky = GLKSkyboxEffect(); sky.xSize = 2; sky.center = GLKVector3Make(0, 1, 0)
                // a texture from a picture, synchronously and through a loader
                let c2 = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 16, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                c2.setFillColor(red: 0, green: 1, blue: 0, alpha: 1); c2.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
                // a premultiplied RGBA picture: Apple's simulator answers GLKTextureLoaderErrorDomain 12 "Image decoding failed"; a PNG of it loads
                var texAnswer = "?"
                do { let i = try GLKTextureLoader.texture(with: c2.makeImage()!, options: nil); texAnswer = "made \(i.width)" } catch { texAnswer = "err \((error as NSError).code)" }
                let png = NSMutableData()
                if let dst = CGImageDestinationCreateWithData(png, "public.png" as CFString, 1, nil) { CGImageDestinationAddImage(dst, c2.makeImage()!, nil); CGImageDestinationFinalize(dst) }
                let info: GLKTextureInfo = try GLKTextureLoader.texture(withContentsOf: png as Data, options: nil)
                tx.name = info.name; tx.target = GLKTextureTarget(rawValue: GLenum(info.target)) ?? .target2D
                try expect(info.width == 4 && info.height == 4 && info.target == GLenum(GL_TEXTURE_2D) && glIsTexture(info.name) == GLboolean(GL_TRUE), "texture \(info.width)x\(info.height)")
                let loader = GLKTextureLoader(sharegroup: ctx.sharegroup)
                // a box through a GLK buffer allocator into a GLKMesh
                let alloc = GLKMeshBufferAllocator()
                let mdl = MDLMesh(boxWithExtent: [1, 1, 1], segments: [1, 1, 1], inwardNormals: false, geometryType: .triangles, allocator: alloc)
                let mesh = try GLKMesh(mesh: mdl)
                let vb: [GLKMeshBuffer] = mesh.vertexBuffers, subs: [GLKSubmesh] = mesh.submeshes
                try expect(!vb.isEmpty && vb[0].length > 0 && glIsBuffer(vb[0].glBufferName) == GLboolean(GL_TRUE) && subs.first?.elementCount == 36 && subs.first?.mode == GLenum(GL_TRIANGLES), "GLK mesh \(vb.count) \(subs.map(\.elementCount))")
                let vc = GLKViewController(); vc.preferredFramesPerSecond = 30
                return "effects \(props.count) properties + reflection / skybox (\(sky.xSize)), CGImage texture \(texAnswer), PNG texture \(info.width)x\(info.height) name \(info.name > 0), loader \(type(of: loader)), mesh \(mesh.vertexCount) vertices / \(subs[0].elementCount) elements, controller fps \(vc.preferredFramesPerSecond)"
            }
        })
        #endif
        #if canImport(GameController) && !os(watchOS)
        c.append(check("GameController", "p28-wheels-styli-names-settings", timeout: 30) {
            var got: [String] = []
            // nothing connected in a simulator: no racing wheels, styli or spatial accessories
            // racing wheels are macOS-only in Swift: the runtime's answer
            let wheels = (NSClassFromString("GCRacingWheel") as? NSObject.Type)?.value(forKey: "connectedRacingWheels") as? NSSet
            got.append("wheels \(wheels.map { "\($0.count)" } ?? "no class")")
            #if os(visionOS)
            let styli: [GCStylus] = GCStylus.styli
            let dt: GCDeviceType? = GCDeviceType(identifier: "com.apple.p28-none")
            got.append("styli \(styli.count), device type by id \(dt == nil ? "nil" : "made")")
            let acc: [GCSpatialAccessory] = GCSpatialAccessory.spatialAccessories
            got.append("spatial accessories \(acc.count) type \(GCDeviceType.spatialAccessory.localizedDescription ?? "nil")")
            #endif
            // element names through the typed-name protocol
            let names: [String] = [p28NameRaw(GCButtonElementName.a), p28NameRaw(GCAxisElementName(rawValue: "Steering Wheel")), p28NameRaw(GCSwitchElementName(rawValue: "Gear Shifter")), p28NameRaw(GCPhysicalInputElementName(rawValue: "Button A"))]
                        try expect(names.allSatisfy { !$0.isEmpty }, "element names \(names)")
            got.append("names \(names)")
            // the classes a wheel's input hands over
            let tree: [(String, String)] = [("GCRacingWheelInput", "GCRacingWheelInputState"), ("GCRacingWheel", "NSObject"), ("GCSteeringWheelElement", "NSObject"),
                                            ("GCGearShifterElement", "NSObject"), ("GCGameControllerActivationContext", "NSObject")]
            let present = tree.filter { t in NSClassFromString(t.0).map { a in p27sIsSub(a, NSClassFromString(t.1)!) } ?? false }.map(\.0)
            let steer = NSClassFromString("GCSteeringWheelElement").map { class_conformsToProtocol($0, GCAxisElement.self) } ?? false
            got.append("classes \(present.count)/\(tree.count) steering is axis \(steer)")
            // an extended gamepad's element collections (a virtual controller, none connected)
            #if os(iOS)
            let cfg = GCVirtualController.Configuration(); cfg.elements = [GCInputButtonA, GCInputLeftThumbstick]
            let vc = GCVirtualController(configuration: cfg)
            if let input = vc.controller?.input { got.append("virtual buttons \(p28Count(input.buttons)) axes \(p28Count(input.axes))") } else { got.append("virtual controller not connected") }
            #endif
            #if os(iOS) || os(visionOS)
            let home: String = await onMain {
                let mgr = GCControllerHomeButtonSettingsManager()
                do {
                    let sys = try mgr.controllerHomeButtonSystemAction, app = try mgr.controllerHomeButtonInAppAction
                    return "system \(sys.action.rawValue)/\(sys.customized.rawValue) in-app \(app.action.rawValue)/\(app.customized.rawValue)"
                } catch { return "err \((error as NSError).domain) \((error as NSError).code)" }
            }
            got.append("home button settings \(home)")
            #endif
            return got.joined(separator: ", ")
        })
        #endif
        #if canImport(TouchController) && os(iOS)
        c.append(check("TouchController", "p28-descriptors-contents", timeout: 30) {
            try await onMain {
                let dev = try p2Dev()
                let ctx = CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 128, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1); ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: 32, height: 32))
                guard let img = TCControlImage(cgImage: ctx.makeImage()!, size: CGSize(width: 44, height: 44), device: dev) else { throw Fail("no control image") }
                let contents = TCControlContents(images: [img])
                try expect(img.size.width == 44 && img.texture.width == 32 && contents.images.count == 1, "image \(img.size) texture \(img.texture.width)")
                let sw = TCSwitchDescriptor(); sw.label = TCControlLabel.buttonB; sw.contents = contents; sw.switchedOnContents = contents; sw.size = CGSize(width: 44, height: 44)
                let ts = TCThumbstickDescriptor(); ts.label = TCControlLabel.leftThumbstick; ts.backgroundContents = contents; ts.stickSize = CGSize(width: 30, height: 30); ts.hidesWhenNotPressed = true
                let dp = TCDirectionPadDescriptor(); dp.compositeLabel = TCControlLabel.directionPad; dp.upContents = contents; dp.isDigital = true; dp.isRadial = false
                let th = TCThrottleDescriptor(); th.label = TCControlLabel.rightThumbstick; th.orientation = .vertical; th.baseValue = 0.5; th.snapsToBaseValue = true
                let tp = TCTouchpadDescriptor(); tp.label = TCControlLabel.leftThumbstick; tp.reportsRelativeValues = true; tp.size = CGSize(width: 120, height: 80)
                try expect(sw.label.name == TCControlLabel.buttonB.name && ts.hidesWhenNotPressed && dp.isDigital && !dp.isRadial && th.baseValue == 0.5 && th.orientation == .vertical
                           && tp.reportsRelativeValues && tp.size.width == 120, "descriptors")
                // the controls a controller makes from them (classes; a controller is not made where unsupported)
                let controls: [AnyClass] = [TCButton.self, TCSwitch.self, TCThumbstick.self, TCDirectionPad.self, TCThrottle.self, TCTouchpad.self]
                let laid = controls.filter { class_conformsToProtocol($0, TCControl.self) && class_conformsToProtocol($0, TCControlLayout.self) }.count
                try expect(laid == 6, "controls conforming to TCControl + TCControlLayout: \(laid)")
                return "control image 44x44 over a 32 px texture, 5 descriptors, \(laid) control classes"
            }
        })
        #endif
        #if canImport(GameKit)
        c.append(check("GameKit", "p28-legacy-classes-runtime", timeout: 30) {
            try await onMain {
                // GameKit's deprecated / Swift-unavailable classes as the runtime has them: present or not, their superclass,
                // the shared event handlers, and the view controllers made with init
                let names = ["GKAchievementViewController", "GKChallengeEventHandler", "GKChallengesViewController", "GKDialogController", "GKGameSession",
                             "GKGameSessionSharingViewController", "GKLeaderboardViewController", "GKPeerPickerController", "GKSession", "GKTurnBasedEventHandler", "GKVoiceChatService"]
                var rows: [String] = []
                for n in names {
                    guard let cls = NSClassFromString(n) else { rows.append("\(n)=-"); continue }
                    var row = "\(n)<\(class_getSuperclass(cls).map { NSStringFromClass($0) } ?? "nil")"
                    let shared = ["challengeEventHandler", "sharedTurnBasedEventHandler", "defaultVoiceChatService"].first { (cls as AnyObject).responds(to: NSSelectorFromString($0)) }
                    if let sel = shared, let o = (cls as AnyObject).perform(NSSelectorFromString(sel))?.takeUnretainedValue() { row += " shared \(NSStringFromClass(type(of: o)) == n)" }
                    if n.hasSuffix("ViewController"), let vc = (cls as? NSObject.Type)?.init() { row += " init \(NSStringFromClass(type(of: vc)) == n)" }
                    rows.append(row)
                }
                let present = rows.filter { !$0.hasSuffix("=-") }.count
                try expect(present >= 1, "no legacy GameKit class present")
                return "\(present)/\(names.count) present: " + rows.joined(separator: "; ")
            }
        })
        #endif
        #if canImport(ComputeGraph) && !os(watchOS)
        c.append(check("ComputeGraph", "p28-unary-stdlib-graph-values", timeout: 60) {
            // x -> negate -> saturate: a graph of a unary and a standard-library node, assembled
            var g = ComputeNodeGraph()
            let f = ComputeNodeGraph.DataType(.float)
            let input = ComputeNodeGraph.NodeDefinition(name: "x", outputs: [.init(name: "value", kind: .value, type: .primitive(type: f))], kind: .graphInput)
            let neg = ComputeNodeGraph.NodeDefinition(name: "neg", inputs: [.init(name: "a", kind: .value, type: .primitive(type: f))],
                                                      outputs: [.init(name: "out", kind: .value, type: .primitive(type: f))], kind: .unaryArithmetic(type: f, operation: UnaryOperation.negate))
            let sat = ComputeNodeGraph.NodeDefinition(name: "sat", inputs: [.init(name: "a", kind: .value, type: .primitive(type: f))],
                                                      outputs: [.init(name: "out", kind: .value, type: .primitive(type: f))], kind: .standardLibrary(type: f, function: StandardLibraryFunction.saturate))
            let n0 = try g.addNode(.init(definition: input, label: "x")), n1 = try g.addNode(.init(definition: neg, label: "neg")), n2 = try g.addNode(.init(definition: sat, label: "sat"))
            try g.addEdge(.init(source: .init(node: n0, index: 0), target: .init(node: n1, index: 0)))
            try g.addEdge(.init(source: .init(node: n1, index: 0), target: .init(node: n2, index: 0)))
            var assembled = "?"
            do { let a = try ComputeNodeGraph.Assembly(g); assembled = "uniforms \(a.uniforms.count)" } catch { assembled = "err \(String(describing: error).prefix(60))" }
            // the value types: every case Codable round trip where Codable, spawn parameters, port references
            func rt<T: Codable & Equatable>(_ xs: [T]) throws -> Bool { try JSONDecoder().decode([T].self, from: JSONEncoder().encode(xs)) == xs }
            let spaces: [AddressSpace] = [.constant, .device, .threadgroup, .thread]
            let ok = try rt(BinaryOperation.allCases) && rt(UnaryOperation.allCases) && rt(StandardLibraryFunction.allCases) && rt(ElementGrouping.allCases)
                && rt(StripOrientation.allCases) && rt(spaces) && rt([PortReference(group: 1, port: 2)])
            let spawn = ElementSpawnParameters(position: [0, 1, 0], velocity: [0, 2, 0])
            try expect(ok && Sorting.allCases.count >= 4 && Sorting(rawValue: Sorting.age.rawValue) == .age && spawn.velocity.y == 2, "values: codable \(ok) sorting \(Sorting.allCases.count) spawn \(spawn.velocity) lifetime \(spawn.lifetime)")
            return "graph \(assembled); \(BinaryOperation.allCases.count) binary / \(UnaryOperation.allCases.count) unary ops, \(StandardLibraryFunction.allCases.count) functions, \(ElementGrouping.allCases.count) groupings, \(StripOrientation.allCases.count) strip orientations, spawn lifetime \(spawn.lifetime)"
        })
        #endif
        #if canImport(RealityKit) && !os(watchOS)
        c.append(check("RealityFoundation", "p28-deformer-force-event-leftovers", timeout: 60) {
            try await p2Main {
                var got: [String] = []
                let r = try RealityRenderer()
                let world = Entity(); r.entities.append(world)
                var sim = PhysicsSimulationComponent(); sim.gravity = [0, 0, 0]; world.components.set(sim)
                // a force effect run through a registered ForceEffectEvent handler: its parameter buffers
                P28Drag.register { (ev: inout ForceEffectEvent<P28Drag>) in
                    let pos: UnsafeForceEffectBuffer<SIMD3<Float>>? = ev.parameters.positions
                    P28Drag.seen.add("n\(ev.parameters.physicsBodyCount) p\(pos.map { Array($0).count } ?? -1)")
                    for i in 0..<ev.parameters.physicsBodyCount { ev.parameters.setForce([0, 10, 0], index: i) }
                }
                let b = ModelEntity(mesh: .generateBox(size: 0.2))
                b.components.set(CollisionComponent(shapes: [.generateBox(size: [0.2, 0.2, 0.2])], filter: CollisionFilter(group: CollisionGroup(rawValue: 8), mask: .all)))
                b.components.set(PhysicsBodyComponent(massProperties: PhysicsMassProperties(mass: 1), material: nil, mode: .dynamic))
                world.addChild(b)
                let field = Entity()
                field.components.set(ForceEffectComponent(effects: [ForceEffect(effect: P28Drag(), spatialFalloff: SpatialForceFalloff(bounds: .sphere(radius: 2)), mask: CollisionGroup(rawValue: 8))]))
                world.addChild(field)
                // a custom CPU deformer on the box, in a deformation stack
                P28Lower.calls.reset()
                let stack = MeshDeformationStack(deformers: [P28Lower(), RenormalizingDeformer()], targets: [.all])
                b.components.set(try MeshDeformerComponent(from: [stack]))
                for _ in 0..<30 { try r.update(1.0 / 60) }
                let ev = P28Drag.seen.all
                got.append("force events \(ev.count) [\(ev.first ?? "")] box y \(String(format: "%.2f", b.position.y)), deformer calls \(P28Lower.calls.all.count) [\(P28Lower.calls.all.first ?? "")]")
                try expect(P28Lower().isDeformerEqual(other: P28Lower()) && !P28Lower().isDeformerEqual(other: RenormalizingDeformer()) && stack.deformers.map(\.type).contains("p28lower"), "deformer \(stack.deformers.map(\.type))")
                // an animation state through the protocol (a transform animation's own state, from an action handler)
                // light probes and lightmaps
                let pos: [SIMD3<Float>] = [[0, 0, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]]
                let coef: [InlineArray<3, SIMD4<Float>>] = Array(repeating: [[0.5, 0.5, 0.5, 0], [0, 0, 0, 0], [0, 0, 0, 0]], count: 4)
                do {
                    let probes = try DiffuseProbeResource(positions: pos, coefficients: coef, tetrahedronIndices: [[0, 1, 2, 3]])
                    let pc = DiffuseLightProbeGroupComponent(resource: probes); world.components.set(pc)
                    got.append("probe group \(world.components.has(DiffuseLightProbeGroupComponent.self))")
                } catch { got.append("probes err \(String(describing: error).prefix(50))") }
                do {
                    let lm = try LightmapResource(perEntityData: [])
                    var lc = LightmapComponent(resource: lm); lc.indirectIrradianceContributionScale = 0.5
                    got.append("lightmap scale \(lc.indirectIrradianceContributionScale) entities \(lc.entityIndexInLightmapResource.count)")
                } catch { got.append("lightmap err \(String(describing: error).prefix(50))") }
                #if canImport(_RealityKit_SwiftUI)
                let gc = GestureComponent(TapGesture())
                b.components.set(gc)
                got.append("gesture component \(b.components.has(GestureComponent.self))")
                #endif
                #if os(visionOS)
                // a picture presented by the image presentation component (Apple may never answer offscreen: wrapped)
                let jpg = FileManager.default.temporaryDirectory.appendingPathComponent("p28-present.jpg")
                let ictx = CGContext(data: nil, width: 64, height: 48, bitsPerComponent: 8, bytesPerRow: 256, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                ictx.setFillColor(red: 0, green: 0.5, blue: 1, alpha: 1); ictx.fill(CGRect(x: 0, y: 0, width: 64, height: 48))
                if let d = CGImageDestinationCreateWithURL(jpg as CFURL, "public.jpeg" as CFString, 1, nil) { CGImageDestinationAddImage(d, ictx.makeImage()!, nil); CGImageDestinationFinalize(d) }
                let pres: Result<String, Error>? = await p28Within(15) {
                    let ipc = try await ImagePresentationComponent(contentsOf: jpg)
                    b.components.set(ipc)
                    return "aspect \(String(format: "%.2f", ipc.aspectRatio(for: .mono) ?? -1)) mode \(ipc.viewingMode)"
                }
                got.append("image presentation \(pres.map { switch $0 { case .success(let v): return v; case .failure(let e): return "err \(String(describing: e).prefix(50))" } } ?? "timeout")")
                #endif
                #if os(iOS) || os(visionOS)
                let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: [0.1, 0.1]))
                got.append("ARKit anchor component \(anchor.components[ARKitAnchorComponent.self] == nil ? "nil" : "set")")
                #endif
                #if os(iOS)
                // the deprecated Combine loader, a photogrammetry sample, the ARView's entity gestures
                let ctx = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 32, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                let req: LoadRequest<TextureResource> = TextureResource.generateAsync(from: ctx.makeImage()!, options: .init(semantic: .color))
                let tex: Result<TextureResource, Error>? = await p28Within(10) {
                    try await withCheckedThrowingContinuation { (k: CheckedContinuation<TextureResource, Error>) in
                        var sub: AnyCancellable?
                        sub = req.sink(receiveCompletion: { if case .failure(let e) = $0 { k.resume(throwing: e) }; _ = sub }, receiveValue: { k.resume(returning: $0) })
                    }
                }
                got.append("load request \(tex.map { if case .success(let t) = $0 { return "\(t.width)x\(t.height)" } else { return "err" } } ?? "timeout")")
                var pb: CVPixelBuffer?
                CVPixelBufferCreate(nil, 4, 4, kCVPixelFormatType_32BGRA, nil, &pb)
                if let pb { var sample = PhotogrammetrySample(id: 7, image: pb); sample.metadata = ["k": 1]; got.append("photogrammetry sample \(sample.id) metadata \(sample.metadata.count)") }
                let view = ARView(frame: CGRect(x: 0, y: 0, width: 100, height: 100), cameraMode: .nonAR, automaticallyConfigureSession: false)
                let me = ModelEntity(mesh: .generateBox(size: 0.2)); me.generateCollisionShapes(recursive: false)
                let ga = AnchorEntity(world: .zero); ga.addChild(me); view.scene.addAnchor(ga)
                let grs: [any EntityGestureRecognizer] = view.installGestures(.all, for: me)
                try expect(grs.count == 3 && grs.allSatisfy { $0.entity === me }, "entity gestures \(grs.count)")
                got.append("entity gestures \(grs.map { "\(type(of: $0))" }.sorted())")
                #endif
                return got.joined(separator: ", ")
            }
        })
        #endif
        #if canImport(TabletopKit) && os(visionOS)
        c.append(check("TabletopKit", "p28-custom-state-actions-counters-network", timeout: 60) {
            try await onMain {
                var setup = TableSetup(tabletop: P28Board())
                setup.add(equipment: P28Pile())
                setup.add(equipment: [P28Card(id: EquipmentIdentifier(11)), P28Card(id: EquipmentIdentifier(12))])
                setup.add(equipment: P28Marker())
                setup.add(equipment: P28Token())
                setup.add(seats: [P28SeatA(id: TableSeatIdentifier(0)), P28SeatA(id: TableSeatIdentifier(1))])
                setup.add(counter: ScoreCounter(id: ScoreCounter.Identifier(1), value: 0))
                setup.register(action: P28PowerUp.self)
                let game = TabletopGame(tableSetup: setup)
                let coord = P28Coordinator()
                game.attachNetworkCoordinator(coord)
                game.claimAnySeat()
                let upd: UpdateCounterAction = .updateCounter(matching: ScoreCounter.Identifier(1), value: 5)
                let turnA: SetTurnAction = .setTurn(matching: TableSeatIdentifier(1))
                let mark: CreateBookmarkAction = .createBookmark(id: StateBookmarkIdentifier(3))
                try expect(upd.newValue == 5 && turnA.seatIDsInTurn == [TableSeatIdentifier(1)] && mark.bookmark.id == StateBookmarkIdentifier(3), "actions")
                game.addAction(upd); game.addAction(turnA); game.addAction(mark)
                game.addAction(P28PowerUp(by: 2))
                for _ in 0..<10 { game.update(deltaTime: 1.0 / 30) }
                var counter: Int64 = -1, turn: [Int] = [], kids: [Int] = [], raw: UInt64 = 0, faceUp = true, cursors = -1, power = -1, ctl = ""
                game.withCurrentSnapshot { s in
                    counter = s.counter(matching: ScoreCounter.Identifier(1))?.value ?? -1
                    turn = s.turn.map(\.rawValue).sorted()
                    kids = s.equipmentIDs(childrenOf: EquipmentIdentifier(10)).map(\.rawValue).sorted()
                    raw = s.state(for: P28Marker()).rawValue
                    ctl = "\(s.state(for: P28Marker()).seatControl)"
                    faceUp = s.state(for: P28Card(id: EquipmentIdentifier(11))).faceUp
                    power = s.state(for: P28Token()).power
                    let cs: [TableCursor] = s.cursors; cursors = cs.count
                    let control: ControllingSeats = s.state(for: P28Marker()).seatControl
                    try? expect(control == .restricted([TableSeatIdentifier(0)]), "")
                    if let seat = s.state(matching: TableSeatIdentifier(0)) { ctl += " seat0 taken \(p28SeatPlayer(seat))" }
                    ctl += " pile parent \(p28Parent(s.state(for: P28Pile())))"
                    let cid: TableCursorIdentifier? = cs.first?.id; _ = cid
                }
                let bookmarks: [StateBookmarkIdentifier] = game.bookmarks
                let me: Player = game.localPlayer
                let pid: PlayerIdentifier = me.id
                try expect(counter >= 5 && turn == [1] && kids == [11, 12] && raw == 7 && !faceUp, "snapshot counter \(counter) turn \(turn) pile \(kids) raw \(raw) faceUp \(faceUp)")
                // interactions, a toss representation, debug drawing, bookmarks
                let inter = game.startInteraction(onEquipmentID: EquipmentIdentifier(20))
                game.cancelAllInteractions()
                let toss = TossableRepresentation.cube(height: 0.02)
                let face = toss.face(for: .identity)
                game.debugDraw(options: [DebugDrawOptions.drawTable, .drawSeats, .drawEquipment])
                let bm = StateBookmark(id: StateBookmarkIdentifier(3))
                if bookmarks.contains(bm.id) { game.jumpToBookmark(bm) }
                let pose3 = EquipmentPose3D(id: EquipmentIdentifier(20), pose: Pose3D(position: Point3D(x: 0, y: 0.1, z: 0), rotation: Rotation3D()))
                let vol: DefaultEquipmentLayout = .volumetric(layout: [pose3])
                let interType: TabletopInteraction.Type = TabletopInteraction.self
                game.detachNetworkCoordinator()
                return "counter \(counter), turn [1], pile \(kids), marker \(raw) control \(ctl), custom power \(power), bookmarks \(bookmarks.map(\.rawValue)), cursors \(cursors), player \(pid.uuid.uuidString.isEmpty ? "?" : "id"), interaction \(inter == nil ? "nil" : "started"), toss face \(face.rawValue), layout \(type(of: vol)), \(interType), network \(Set(coord.log.all).sorted()), custom action saw \(Set(P28PowerUp.seen.all).sorted())"
            }
        })
        #endif
        return c
    }
}
