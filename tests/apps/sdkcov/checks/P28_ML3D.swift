// SDK coverage, round 30 wave 2 (P28): public API of the SDK still not referenced by any check after P27
// (~/scratch/r30/apisurf.py), area: ML3D. Each check asserts what Apple's simulator answers (ref-mac.sh --only);
// ids start with "p28-".
// CreateMLComponents: small estimators fitted on in-app data (linear / logistic / network regressors and classifiers,
// time-series forecaster and classifier, multi-label network), their adaptors (supervised / temporal / tabular /
// updatable / preprocessing compositions), temporal sequences, random augmentations, metrics and error values.
import Foundation
import CoreGraphics
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
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

#if canImport(RealityKit) && !os(watchOS)
struct P28NoopSystem: System { init(scene: RealityKit.Scene) {}; func update(context: SceneUpdateContext) {} }
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
            let fc = try await LinearTimeSeriesForecaster<Float>(configuration: LinearTimeSeriesForecasterConfiguration(inputWindowSize: 2, forecastWindowSize: 1))
                .fitted(toWindows: (0..<10).map { AnnotatedFeature(feature: MLShapedArray<Float>(scalars: [Float($0), Float($0 + 1)], shape: [2, 1]), annotation: MLShapedArray<Float>(scalars: [Float($0 + 2)], shape: [1, 1])) })
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
            // Apple's iOS 27.2 simulator: no Vision scene print / pose model (VisionError 1, Vision code 9); the action models run on
            // CPU; the selectors zero the confidence of the joints they drop; a missing movie is AVFoundation -11800; the 1 s tone
            // gives 3 audio feature prints of 512
            #if os(iOS)
            let want = ["featureprint err Vision.VisionError:1", "rev 999 The revision 999 is not supported.", "poses err 9",
                        "selected [head_joint:0.9 left_hand_joint:0.0 right_hand_joint:0.0 root:0.9]", "ignored [head_joint:0.0 left_hand_joint:0.9 right_hand_joint:0.9 root:0.9]",
                        "periods 60 false", "counter 60", "video AVFoundationErrorDomain:-11800", "audio prints 3 [512]", "AP [\"cat\": 1.0, \"dog\": 0.0] mAP 0.5"]
            let joined = got.joined(separator: ", ")
            let missing = want.filter { !joined.contains($0) }
            try expect(missing.isEmpty, "differs from Apple's simulator in \(missing): \(joined)")
            #endif
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
            let varied: [String: Double] = m.averageOfAveragePrecisionAtVariedThresholds(predictions: preds, annotations: anns)
            let variedMean: Double = m.averageOfMeanAveragePrecisionAtVariedThresholds(predictions: preds, annotations: anns)
            got.append("AP \(ap.sorted { $0.key < $1.key }.map { "\"\($0.key)\": \($0.value)" }) mAP \(map) varied \(varied.count) \(String(format: "%.2f", variedMean))")
            // Apple's iOS 27.2 simulator: no Vision scene print / pose model (VisionError 1, Vision code 9); the action models run on
            // CPU; the selectors zero the confidence of the joints they drop; a missing movie is AVFoundation -11800; the 1 s tone
            // gives 3 audio feature prints of 512
            #if os(iOS)
            let want = ["featureprint err Vision.VisionError:1", "rev 999 The revision 999 is not supported.", "poses err 9",
                        "selected [head_joint:0.9 left_hand_joint:0.0 right_hand_joint:0.0 root:0.9]", "ignored [head_joint:0.0 left_hand_joint:0.9 right_hand_joint:0.9 root:0.9]",
                        "periods 60 false", "counter 60", "video AVFoundationErrorDomain:-11800", "audio prints 3 [512]", "AP [\"cat\": 1.0, \"dog\": 0.0] mAP 0.5"]
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
                try expect(poses.count == 1 && poses["pose"]?.jointNames == ["root", "tip"] && poses["pose"]?["tip"]?.translation == [0, 1, 0], "skeletal poses \(poses.map(\.id))")
                var ps = SkeletalPoseSet(); _ = ps.set(SkeletalPose(id: "p2", joints: [("j", .identity)]))
                try expect(ps.contains("p2") && ps.default?.id == "p2" && ps.index(of: "p2") != nil, "pose set")
                let bsw = e.components[BlendShapeWeightsComponent.self]!.weightSet
                var wset = BlendShapeWeightsSet(); _ = wset.set(BlendShapeWeightsData(id: "face", weights: [("smile", 0.5), ("blink", 1)]))
                let wd = wset["face"]
                try expect(wd?.weights == [0.5, 1] && wd?.weightNames == ["smile", "blink"] && wset.contains("face"), "blend weights set \(String(describing: wd?.weights))")
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
                try expect(vp.avPlayer != nil && vp.desiredViewingMode == .mono, "video player \(vp.desiredViewingMode)")
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
                let ctl = try NavigationController(entity: agent)
                let path = await ctl.computePath(from: [-4, 0, -4], to: [4, 0, 4])
                let pts = path ?? []
                try expect(pts.count >= 2 && simd_distance(pts.last!.position, [4, 0, 4]) < 0.5 && pts.allSatisfy { $0.category == .meshPoint || $0.category == .offMeshConnection },
                           "path \(pts.map(\.position))")
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
        #endif
        return c
    }
}
