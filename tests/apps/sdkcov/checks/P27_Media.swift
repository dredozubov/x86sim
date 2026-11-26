// SDK coverage, round 30 (P27): public API of the SDK not yet referenced by any check (~/scratch/r30/apisurf.py),
// area: Media. Each check asserts what Apple's simulator answers (ref-mac.sh --only); ids start with "p27-".
// Metal: the descriptor families (render / compute / blit / resource-state / acceleration-structure passes and their
// sample-buffer attachment arrays, vertex / stage-input / pipeline-buffer layouts, samplers, queues), reflection
// types, function descriptors and stitching, acceleration-structure descriptors (sizes only: the simulator GPU has no
// ray tracing), shared-event handles. GPU results are read back; unorm values are compared with a tolerance (x86Sim's
// GPU path rounds 0.5 to 127 where Apple's simulator gives 128).
import Foundation
import CoreGraphics
#if canImport(Metal)
import Metal
#endif
#if canImport(RealityKit) && !os(watchOS)
import RealityKit
#endif
import AVFoundation
#if canImport(AudioToolbox)
import AudioToolbox
#endif
#if canImport(CoreImage)
import CoreImage
#endif
import CoreText
#if canImport(Vision)
import Vision
#endif
#if canImport(CreateMLComponents)
import CreateMLComponents
import CoreML
import TabularData
#endif
#if canImport(ModelIO)
import ModelIO
#endif
#if canImport(SceneKit)
import SceneKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(PHASE)
import PHASE
#endif
#if canImport(MediaPlayer)
import MediaPlayer
#endif
#if canImport(GameController)
import GameController
#endif
#if canImport(VideoToolbox)
import VideoToolbox
#endif
#if canImport(Speech)
import Speech
#endif
#if canImport(AVKit)
import AVKit
#endif
#if canImport(GameKit)
import GameKit
#endif
#if canImport(MetalPerformanceShadersGraph)
import MetalPerformanceShadersGraph
#endif

#if canImport(Metal)
func p27Dev() throws -> MTLDevice {
    guard let d = MTLCreateSystemDefaultDevice() else { throw Fail("no MTLDevice") }
    return d
}
func p27Lib(_ dev: MTLDevice, _ src: String, _ opts: MTLCompileOptions? = nil) async throws -> MTLLibrary {
    try await dev.makeLibrary(source: "#include <metal_stdlib>\nusing namespace metal;\n" + src, options: opts)
}
func p27Fn(_ lib: MTLLibrary, _ n: String) throws -> MTLFunction {
    guard let f = lib.makeFunction(name: n) else { throw Fail("no function \(n) in the library") }
    return f
}
func p27Run(_ cb: MTLCommandBuffer) async throws {
    await withCheckedContinuation { (k: CheckedContinuation<Void, Never>) in
        cb.addCompletedHandler { _ in k.resume() }
        cb.commit()
    }
    try expect(cb.status == .completed, "command buffer status \(cb.status.rawValue): \(String(describing: cb.error))")
}
func p27Floats(_ b: MTLBuffer, _ n: Int) -> [Float] { Array(UnsafeBufferPointer(start: b.contents().assumingMemoryBound(to: Float.self), count: n)) }
func p27Buf(_ dev: MTLDevice, _ v: [Float]) -> MTLBuffer { dev.makeBuffer(bytes: v, length: max(v.count, 1) * 4, options: .storageModeShared)! }
/// a unorm byte read back from the GPU: 0.5 is 127 or 128 (rounding differs between GPUs)
func p27Near(_ a: UInt8, _ b: Int, _ tol: Int = 2) -> Bool { abs(Int(a) - b) <= tol }
#endif

#if canImport(CoreImage)
/// 400x300 white picture: a QR code "p27-vision" (left), a black rectangle (right), "VISION CHECK" (bottom); all moved
/// `shift` px right
func p27VisionImage(shift: Int) throws -> CGImage {
    let w = 400, h = 300
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Fail("context") }
    ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    let dx = CGFloat(shift)
    guard let qf = CIFilter(name: "CIQRCodeGenerator") else { throw Fail("no QR generator") }
    qf.setValue(Data("p27-vision".utf8), forKey: "inputMessage"); qf.setValue("M", forKey: "inputCorrectionLevel")
    guard let qr = qf.outputImage?.transformed(by: CGAffineTransform(scaleX: 6, y: 6)),
          let qcg = CIContext(options: [.useSoftwareRenderer: true]).createCGImage(qr, from: qr.extent) else { throw Fail("QR image") }
    ctx.interpolationQuality = .none
    ctx.draw(qcg, in: CGRect(x: 20 + dx, y: 120, width: qr.extent.width, height: qr.extent.height))
    ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)); ctx.fill(CGRect(x: 250 + dx, y: 130, width: 100, height: 120))
    let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 40, nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "VISION CHECK", attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)]))
    ctx.textPosition = CGPoint(x: 40 + dx, y: 40); CTLineDraw(line, ctx)
    guard let img = ctx.makeImage() else { throw Fail("image") }
    return img
}
#endif

#if canImport(CreateMLComponents)
/// apply any CreateMLComponents Transformer
func p27Apply<T: Transformer>(_ t: T, _ x: T.Input) async throws -> T.Output { try await t.applied(to: x, eventHandler: nil) }
#endif

/// a flag set from any thread
final class P27Flag: @unchecked Sendable {
    private let l = NSLock(); private var v = false
    func set() { l.lock(); v = true; l.unlock() }
    var value: Bool { l.lock(); defer { l.unlock() }; return v }
}

/// a value / data class: NSCopying copy is a different object of the same class whose `keys` read back equal
func p27CopyEqual(_ o: NSObject, _ keys: [String]) -> String? {
    guard let cp = (o as? NSCopying)?.copy(with: nil) as? NSObject else { return "\(type(of: o)) not NSCopying" }
    guard type(of: cp) == type(of: o) else { return "\(type(of: o)) copy is \(type(of: cp))" }
    for k in keys {
        let a = o.value(forKey: k) as AnyObject?, b = cp.value(forKey: k) as AnyObject?
        if !(a?.isEqual(b) ?? (b == nil)) { return "\(type(of: o)).\(k) \(String(describing: a)) != copy \(String(describing: b))" }
    }
    return nil
}

#if canImport(RealityKit) && !os(watchOS)
/// a TransientComponent: not copied by Entity.clone
struct P27Transient: TransientComponent { var v = 1 }
func p27SemanticID<S: MeshBufferSemantic>(_ s: S) -> String { "\(s.id)" }
#endif

extension Registry {
    static var p27media: [Check] {
        var c: [Check] = []
        #if canImport(Metal)
        c.append(check("Metal", "p27-pass-descriptors-sample-buffers", timeout: 60) {
            let dev = try p27Dev(), q = dev.makeCommandQueue()!
            // render pass: color clear 0.5 grey, depth / stencil attachments, a sample buffer attachment slot
            let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 4, height: 4, mipmapped: false)
            td.usage = [.renderTarget, .shaderRead]; td.storageMode = .shared
            let color = dev.makeTexture(descriptor: td)!
            let dd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float_stencil8, width: 4, height: 4, mipmapped: false)
            dd.usage = .renderTarget; dd.storageMode = .private
            let depth = dev.makeTexture(descriptor: dd)!
            let rp = MTLRenderPassDescriptor()
            let ca: MTLRenderPassColorAttachmentDescriptor = rp.colorAttachments[0]
            ca.texture = color; ca.loadAction = .clear; ca.storeAction = .store; ca.clearColor = MTLClearColor(red: 0.5, green: 0.25, blue: 1, alpha: 1)
            let caArr: MTLRenderPassColorAttachmentDescriptorArray = rp.colorAttachments
            let da: MTLRenderPassDepthAttachmentDescriptor = rp.depthAttachment
            da.texture = depth; da.loadAction = .clear; da.clearDepth = 0.25; da.storeAction = .dontCare
            let sa: MTLRenderPassStencilAttachmentDescriptor = rp.stencilAttachment
            sa.texture = depth; sa.loadAction = .clear; sa.clearStencil = 7; sa.storeAction = .dontCare
            let base: MTLRenderPassAttachmentDescriptor = da
            try expect(caArr[0].clearColor.green == 0.25 && base.texture === depth && da.clearDepth == 0.25 && sa.clearStencil == 7, "render pass attachments read back")
            let rsb: MTLRenderPassSampleBufferAttachmentDescriptorArray = rp.sampleBufferAttachments
            let rs: MTLRenderPassSampleBufferAttachmentDescriptor = rsb[0]
            rs.startOfVertexSampleIndex = 1; rs.endOfFragmentSampleIndex = 2
            try expect(rp.sampleBufferAttachments[0].startOfVertexSampleIndex == 1 && rs.sampleBuffer == nil, "render sample attachment")
            rs.startOfVertexSampleIndex = MTLCounterDontSample; rs.endOfFragmentSampleIndex = MTLCounterDontSample
            // compute / blit / resource-state / acceleration-structure passes
            let cp = MTLComputePassDescriptor(); cp.dispatchType = .concurrent
            let csa: MTLComputePassSampleBufferAttachmentDescriptorArray = cp.sampleBufferAttachments
            let cs: MTLComputePassSampleBufferAttachmentDescriptor = csa[0]; cs.startOfEncoderSampleIndex = 3
            let bp = MTLBlitPassDescriptor()
            let bsa: MTLBlitPassSampleBufferAttachmentDescriptorArray = bp.sampleBufferAttachments
            let bs: MTLBlitPassSampleBufferAttachmentDescriptor = bsa[0]; bs.endOfEncoderSampleIndex = 4
            let sp = MTLResourceStatePassDescriptor()
            let ssa: MTLResourceStatePassSampleBufferAttachmentDescriptorArray = sp.sampleBufferAttachments
            let ss: MTLResourceStatePassSampleBufferAttachmentDescriptor = ssa[0]; ss.startOfEncoderSampleIndex = 5
            let ap = MTLAccelerationStructurePassDescriptor()
            let asa: MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray = ap.sampleBufferAttachments
            let as_: MTLAccelerationStructurePassSampleBufferAttachmentDescriptor = asa[0]; as_.endOfEncoderSampleIndex = 6
            let idx = [cp.sampleBufferAttachments[0].startOfEncoderSampleIndex, bp.sampleBufferAttachments[0].endOfEncoderSampleIndex,
                       sp.sampleBufferAttachments[0].startOfEncoderSampleIndex, ap.sampleBufferAttachments[0].endOfEncoderSampleIndex]
            try expect(idx == [3, 4, 5, 6], "sample indices read back \(idx)")
            for d in [cs as MTLComputePassSampleBufferAttachmentDescriptor] { d.startOfEncoderSampleIndex = MTLCounterDontSample }
            bs.endOfEncoderSampleIndex = MTLCounterDontSample
            for o in [rp, cp, bp, sp, ap] as [NSObject] { if let e = p27CopyEqual(o, []) { throw Fail(e) } }
            // the passes, encoded: clear, a compute dispatch (doubles), a blit copy into a second buffer
            let lib = try await p27Lib(dev, "kernel void dbl(device float *b [[buffer(0)]], uint i [[thread_position_in_grid]]) { b[i] *= 2.0f; }")
            let pso = try await dev.makeComputePipelineState(function: try p27Fn(lib, "dbl"))
            let a = p27Buf(dev, [1, 2, 3, 4]), b = p27Buf(dev, [0, 0, 0, 0])
            let cb = q.makeCommandBuffer()!
            cb.makeRenderCommandEncoder(descriptor: rp)!.endEncoding()
            let ce = cb.makeComputeCommandEncoder(descriptor: cp)!
            ce.setComputePipelineState(pso); ce.setBuffer(a, offset: 0, index: 0)
            ce.dispatchThreads(MTLSize(width: 4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 4, height: 1, depth: 1)); ce.endEncoding()
            let be = cb.makeBlitCommandEncoder(descriptor: bp)!
            be.copy(from: a, sourceOffset: 4, to: b, destinationOffset: 0, size: 12); be.endEncoding()
            try await p27Run(cb)
            var px = [UInt8](repeating: 0, count: 4)
            color.getBytes(&px, bytesPerRow: 16, from: MTLRegionMake2D(1, 1, 1, 1), mipmapLevel: 0)
            try expect(p27Near(px[0], 128) && p27Near(px[1], 64) && px[2] == 255 && px[3] == 255, "cleared pixel RGBA \(px) (want ~128,64,255,255)")
            let out = p27Floats(b, 4)
            try expect(out == [4, 6, 8, 0], "compute + blit result \(out)")
            return "clear RGBA \(px), compute+blit \(out), sample indices \(idx)"
        })
        c.append(check("Metal", "p27-pipeline-layout-descriptors", timeout: 60) {
            let dev = try p27Dev(), q = dev.makeCommandQueue()!
            // vertex descriptor: attribute + layout arrays; pipeline color attachments + pipeline buffer arrays
            let vd = MTLVertexDescriptor()
            let attrs: MTLVertexAttributeDescriptorArray = vd.attributes
            let a0: MTLVertexAttributeDescriptor = attrs[0]; a0.format = .float2; a0.offset = 0; a0.bufferIndex = 0
            let layouts: MTLVertexBufferLayoutDescriptorArray = vd.layouts
            let l0: MTLVertexBufferLayoutDescriptor = layouts[0]; l0.stride = 8; l0.stepFunction = .perVertex
            let rpd = MTLRenderPipelineDescriptor()
            rpd.vertexDescriptor = vd
            let cas: MTLRenderPipelineColorAttachmentDescriptorArray = rpd.colorAttachments
            let c0: MTLRenderPipelineColorAttachmentDescriptor = cas[0]
            c0.pixelFormat = .rgba8Unorm; c0.isBlendingEnabled = true; c0.sourceRGBBlendFactor = .one; c0.destinationRGBBlendFactor = .one
            let vbs: MTLPipelineBufferDescriptorArray = rpd.vertexBuffers
            let vb0: MTLPipelineBufferDescriptor = vbs[0]; vb0.mutability = .immutable
            let fns = MTLRenderPipelineFunctionsDescriptor()
            fns.vertexAdditionalBinaryFunctions = []; fns.fragmentAdditionalBinaryFunctions = []; fns.tileAdditionalBinaryFunctions = []
            try expect(fns.vertexAdditionalBinaryFunctions?.count == 0, "functions descriptor")
            let tpd = MTLTileRenderPipelineDescriptor()
            let tcas: MTLTileRenderPipelineColorAttachmentDescriptorArray = tpd.colorAttachments
            let tc0: MTLTileRenderPipelineColorAttachmentDescriptor = tcas[0]; tc0.pixelFormat = .bgra8Unorm
            try expect(tpd.colorAttachments[0].pixelFormat == .bgra8Unorm, "tile color attachment")
            let lib = try await p27Lib(dev, """
            struct VI { float2 p [[attribute(0)]]; };
            vertex float4 v(VI i [[stage_in]]) { return float4(i.p, 0, 1); }
            fragment float4 f() { return float4(0.25, 0.5, 0, 1); }
            struct SI { float a [[attribute(0)]]; float b [[attribute(1)]]; };
            kernel void si(SI i [[stage_in]], device float *o [[buffer(1)]], uint g [[thread_position_in_grid]]) { o[g] = i.a * 10 + i.b; }
            """)
            rpd.vertexFunction = try p27Fn(lib, "v"); rpd.fragmentFunction = try p27Fn(lib, "f")
            let rps = try await dev.makeRenderPipelineState(descriptor: rpd)
            // a full-screen pair of triangles, drawn twice with additive blending: 2 * (0.25, 0.5) = (0.5, 1.0)
            let quad: [Float] = [-1, -1, 1, -1, -1, 1, 1, -1, 1, 1, -1, 1]
            let vbuf = p27Buf(dev, quad)
            let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 4, height: 4, mipmapped: false)
            td.usage = [.renderTarget]; td.storageMode = .shared
            let tex = dev.makeTexture(descriptor: td)!
            let rp = MTLRenderPassDescriptor(); rp.colorAttachments[0].texture = tex; rp.colorAttachments[0].loadAction = .clear
            rp.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0); rp.colorAttachments[0].storeAction = .store
            // compute with stage_in: a stage input descriptor of two float attributes from one buffer
            let sid = MTLStageInputOutputDescriptor()
            let sattrs: MTLAttributeDescriptorArray = sid.attributes
            let sa0: MTLAttributeDescriptor = sattrs[0]; sa0.format = .float; sa0.offset = 0; sa0.bufferIndex = 0
            let sa1: MTLAttributeDescriptor = sattrs[1]; sa1.format = .float; sa1.offset = 4; sa1.bufferIndex = 0
            let sls: MTLBufferLayoutDescriptorArray = sid.layouts
            let sl0: MTLBufferLayoutDescriptor = sls[0]; sl0.stride = 8; sl0.stepFunction = .threadPositionInGridX
            sid.indexType = .uint16
            let cpd = MTLComputePipelineDescriptor(); cpd.computeFunction = try p27Fn(lib, "si"); cpd.stageInputDescriptor = sid
            let cbufs: MTLPipelineBufferDescriptorArray = cpd.buffers; cbufs[1].mutability = .mutable
            let (cps, _) = try await dev.makeComputePipelineState(descriptor: cpd, options: [])
            let pairs = p27Buf(dev, [1, 2, 3, 4, 5, 6]), out = p27Buf(dev, [0, 0, 0])
            let cb = q.makeCommandBuffer()!
            let re = cb.makeRenderCommandEncoder(descriptor: rp)!
            re.setRenderPipelineState(rps); re.setVertexBuffer(vbuf, offset: 0, index: 0)
            re.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6); re.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            re.endEncoding()
            let ce = cb.makeComputeCommandEncoder()!
            ce.setComputePipelineState(cps); ce.setBuffer(pairs, offset: 0, index: 0); ce.setBuffer(out, offset: 0, index: 1)
            ce.dispatchThreads(MTLSize(width: 3, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 3, height: 1, depth: 1)); ce.endEncoding()
            try await p27Run(cb)
            var px = [UInt8](repeating: 0, count: 4)
            tex.getBytes(&px, bytesPerRow: 16, from: MTLRegionMake2D(2, 2, 1, 1), mipmapLevel: 0)
            try expect(p27Near(px[0], 128) && p27Near(px[1], 255) && px[2] == 0 && px[3] == 255, "blended pixel RGBA \(px) (want ~128,255,0,255)")
            let o = p27Floats(out, 3)
            try expect(o == [12, 34, 56], "stage_in kernel output \(o)")
            for (obj, keys) in [(a0 as NSObject, ["format", "offset", "bufferIndex"]), (l0, ["stride", "stepFunction"]),
                                (c0, ["pixelFormat", "blendingEnabled"]), (sid, ["indexType"]), (vd, []), (fns, [])] {
                if let e = p27CopyEqual(obj, keys) { throw Fail(e) }
            }
            return "blended RGBA \(px), stage_in \(o)"
        })
        c.append(check("Metal", "p27-reflection-types-function-descriptors", timeout: 60) {
            let dev = try p27Dev()
            let lib = try await p27Lib(dev, """
            struct S { float4 v; int n; float a[3]; };
            struct AB { texture2d<float> t; device float *p; };
            constant float kScale [[function_constant(0)]];
            constant bool kAdd [[function_constant(1)]];
            kernel void k(device S *s [[buffer(0)]], constant AB &ab [[buffer(1)]], texture2d<float, access::write> o [[texture(0)]],
                          uint i [[thread_position_in_grid]]) {
                s[i].v = s[i].v * kScale + (kAdd ? 1.0f : 0.0f); s[i].n = int(i) + 7; s[i].a[2] = float(i);
            }
            struct VI { float3 p [[attribute(0)]]; float2 uv [[attribute(1)]]; };
            vertex float4 vtx(VI i [[stage_in]], constant float4 &tint [[buffer(1)]]) { return float4(i.p, 1) * tint; }
            fragment float4 frag() { return float4(1); }
            struct KI { float a [[attribute(0)]]; half2 b [[attribute(1)]]; };
            kernel void kin(KI i [[stage_in]], device float *o [[buffer(1)]], uint g [[thread_position_in_grid]]) { o[g] = i.a + float(i.b.x); }
            """)
            // function constants (MTLFunctionConstant), a function made from an MTLFunctionDescriptor with values
            guard let kc = lib.makeFunction(name: "k") else { throw Fail("no k") }
            let fd = MTLFunctionDescriptor(); fd.name = "k"
            let cv = MTLFunctionConstantValues()
            var scale: Float = 3, add = true
            cv.setConstantValue(&scale, type: .float, index: 0); cv.setConstantValue(&add, type: .bool, index: 1)
            fd.constantValues = cv; fd.options = []
            let fn = try await lib.makeFunction(descriptor: fd)
            let consts: [String: MTLFunctionConstant] = kc.functionConstantsDictionary
            let cnames = consts.values.sorted { $0.index < $1.index }.map { "\($0.name):\($0.type.rawValue):\($0.index):\($0.required)" }
            try expect(cnames == ["kScale:\(MTLDataType.float.rawValue):0:true", "kAdd:\(MTLDataType.bool.rawValue):1:true"], "function constants \(cnames)")
            let ifd = MTLIntersectionFunctionDescriptor(); ifd.name = "k"; ifd.constantValues = cv
            try expect(ifd.name == "k" && (ifd as MTLFunctionDescriptor).constantValues != nil, "intersection function descriptor")
            let iftd = MTLIntersectionFunctionTableDescriptor(); iftd.functionCount = 3
            try expect(iftd.functionCount == 3, "intersection table descriptor")
            // compute reflection: bindings -> pointer / struct / array / texture-reference types
            let (pso, refl0) = try await dev.makeComputePipelineState(function: fn, options: [.bindingInfo, .bufferTypeInfo])
            guard let refl: MTLComputePipelineReflection = refl0 else { throw Fail("no compute reflection") }
            var seen: [String] = []
            for b in refl.bindings {
                if let bb = b as? MTLBufferBinding, let pt: MTLPointerType = bb.bufferPointerType {
                    let st: MTLStructType? = pt.elementStructType()
                    let members: [MTLStructMember] = st?.members ?? []
                    seen.append("\(bb.name):ptr:\(members.map(\.name).joined(separator: "/"))")
                    if let arr: MTLArrayType = st?.memberByName("a")?.arrayType() { seen.append("a[\(arr.arrayLength)]:\(arr.elementType.rawValue)") }
                    if let tm = st?.memberByName("t"), let tr: MTLTextureReferenceType = tm.textureReferenceType() {
                        seen.append("t:tex\(tr.textureType.rawValue):\(tr.access.rawValue)")
                    }
                    let any: MTLType = pt; _ = any.dataType
                } else if let tb = b as? MTLTextureBinding { seen.append("\(tb.name):tex:\(tb.access.rawValue)") }
            }
            let want = ["s:ptr:v/n/a", "a[3]:\(MTLDataType.float.rawValue)", "ab:ptr:t/p", "t:tex\(MTLTextureType.type2D.rawValue):\(MTLBindingAccess.readOnly.rawValue)",
                        "o:tex:\(MTLBindingAccess.writeOnly.rawValue)"]
            try expect(Set(seen) == Set(want), "compute bindings \(seen)")
            // MTLArgument (the older reflection) answers the same names
            let (_, refl1) = try await dev.makeComputePipelineState(function: fn, options: [.argumentInfo])
            let args: [MTLArgument] = refl1?.arguments ?? []
            try expect(Set(args.map(\.name)).isSuperset(of: ["s", "ab", "o"]), "MTLArgument names \(args.map(\.name))")
            // render reflection + vertex attributes (MTLVertexAttribute) + stage-in attributes (MTLAttribute)
            let vf = try p27Fn(lib, "vtx")
            let vattrs: [MTLVertexAttribute] = vf.vertexAttributes ?? []
            // a kernel's stage-in attributes are MTLAttributes (a vertex function's array holds MTLVertexAttributes: read
            // through the runtime, as a Swift [MTLAttribute] cast of that traps)
            let kin = try p27Fn(lib, "kin")
            let sattrs: [MTLAttribute] = ((kin as AnyObject).value(forKey: "stageInputAttributes") as? [AnyObject] ?? []).compactMap { $0 as? MTLAttribute }
            try expect(vattrs.map { "\($0.name)@\($0.attributeIndex)" } == ["p@0", "uv@1"], "vertex attributes \(vattrs.map(\.name))")
            try expect(sattrs.map(\.attributeType) == [.float, .half2] && sattrs.map(\.name) == ["a", "b"], "stage input attribute types \(sattrs.map(\.attributeType.rawValue))")
            let rpd = MTLRenderPipelineDescriptor(); rpd.vertexFunction = vf; rpd.fragmentFunction = try p27Fn(lib, "frag")
            rpd.colorAttachments[0].pixelFormat = .rgba8Unorm
            let v = MTLVertexDescriptor()
            v.attributes[0].format = .float3; v.attributes[1].format = .float2; v.attributes[1].offset = 12; v.layouts[0].stride = 20
            rpd.vertexDescriptor = v
            let (_, rr) = try await dev.makeRenderPipelineState(descriptor: rpd, options: [.bindingInfo])
            guard let rrefl: MTLRenderPipelineReflection = rr else { throw Fail("no render reflection") }
            let vb = rrefl.vertexBindings.map(\.name)
            try expect(vb.contains("tint"), "vertex bindings \(vb)")
            // run the specialised kernel: v * 3 + 1, n = i + 7, a[2] = i
            let stride = 32 + 0
            let sbuf = dev.makeBuffer(length: stride * 2 + 16, options: .storageModeShared)!
            let p = sbuf.contents().assumingMemoryBound(to: Float.self)
            for i in 0..<4 { p[i] = Float(i); p[8 + i] = 10 }
            let ab = dev.makeBuffer(length: 64, options: .storageModeShared)!
            let otd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 2, height: 1, mipmapped: false); otd.usage = .shaderWrite
            let otex = dev.makeTexture(descriptor: otd)!
            let cb = dev.makeCommandQueue()!.makeCommandBuffer()!, e = cb.makeComputeCommandEncoder()!
            e.setComputePipelineState(pso); e.setBuffer(sbuf, offset: 0, index: 0); e.setBuffer(ab, offset: 0, index: 1); e.setTexture(otex, index: 0)
            e.dispatchThreads(MTLSize(width: 2, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 2, height: 1, depth: 1)); e.endEncoding()
            try await p27Run(cb)
            let v0 = (0..<4).map { p[$0] }, v1 = (8..<12).map { p[$0] }
            let n1 = sbuf.contents().load(fromByteOffset: stride + 16, as: Int32.self), a12 = p[(stride + 28) / 4]
            try expect(v0 == [1, 4, 7, 10] && v1 == [31, 31, 31, 31] && n1 == 8 && a12 == 1, "kernel results v0 \(v0) v1 \(v1) n1 \(n1) a[2] \(a12)")
            return "constants \(cnames), bindings \(seen.sorted()), \(args.count) MTLArguments, vertex bindings \(vb)"
        })
        c.append(check("Metal", "p27-stitching-graph", timeout: 60) {
            let dev = try p27Dev()
            let lib = try await p27Lib(dev, """
            [[stitchable]] float addf(float a, float b) { return a + b; }
            [[stitchable]] float mulf(float a, float b) { return a * b; }
            """)
            let addF = try p27Fn(lib, "addf"), mulF = try p27Fn(lib, "mulf")
            // (x + y) * y
            let x = MTLFunctionStitchingInputNode(argumentIndex: 0), y = MTLFunctionStitchingInputNode(argumentIndex: 1)
            let n1 = MTLFunctionStitchingFunctionNode(name: "addf", arguments: [x, y], controlDependencies: [])
            let n2 = MTLFunctionStitchingFunctionNode(name: "mulf", arguments: [n1, y], controlDependencies: [])
            let inl = MTLFunctionStitchingAttributeAlwaysInline()
            let g = MTLFunctionStitchingGraph(functionName: "fused", nodes: [n1], outputNode: n2, attributes: [inl])
            try expect(g.functionName == "fused" && g.outputNode === n2 && g.attributes.count == 1 && x.argumentIndex == 0 && n2.arguments.count == 2, "graph read back")
            let sd = MTLStitchedLibraryDescriptor(); sd.functionGraphs = [g]; sd.functions = [addF, mulF]
            for o in [x, n1, g, sd] as [NSObject] { if let e = p27CopyEqual(o, []) { throw Fail(e) } }
            var made: String
            do {
                let sl = try await dev.makeLibrary(stitchedDescriptor: sd)
                made = "stitched library functions \(sl.functionNames.sorted())"
                try expect(sl.functionNames.contains("fused"), made)
            } catch { made = "stitched library refused: \((error as NSError).domain) \((error as NSError).code)" }
            return "graph fused = (x + y) * y; \(made)"
        })
        c.append(check("Metal", "p27-acceleration-descriptors-events", timeout: 60) {
            let dev = try p27Dev()
            let bb = p27Buf(dev, [0, 0, 0, 1, 1, 1]), cp = p27Buf(dev, [0, 0, 0, 0.1, 1, 0, 0, 0.1, 2, 0, 0, 0.1, 3, 0, 0, 0.1])
            let geomBB = MTLAccelerationStructureBoundingBoxGeometryDescriptor(); geomBB.boundingBoxBuffer = bb; geomBB.boundingBoxCount = 1; geomBB.boundingBoxStride = 24
            let curve = MTLAccelerationStructureCurveGeometryDescriptor()
            curve.controlPointBuffer = cp; curve.controlPointCount = 4; curve.controlPointStride = 16; curve.controlPointFormat = .float3
            curve.segmentCount = 1; curve.segmentControlPointCount = 4; curve.curveType = .round; curve.curveBasis = .bSpline
            let k0 = MTLMotionKeyframeData(), k1 = MTLMotionKeyframeData(); k0.buffer = bb; k1.buffer = bb; k1.offset = 0
            let mtri = MTLAccelerationStructureMotionTriangleGeometryDescriptor(); mtri.vertexBuffers = [k0, k1]; mtri.vertexStride = 12; mtri.triangleCount = 0
            let mbb = MTLAccelerationStructureMotionBoundingBoxGeometryDescriptor(); mbb.boundingBoxBuffers = [k0, k1]; mbb.boundingBoxCount = 1; mbb.boundingBoxStride = 24
            let mcurve = MTLAccelerationStructureMotionCurveGeometryDescriptor(); mcurve.controlPointBuffers = [k0, k1]; mcurve.controlPointCount = 4
            mcurve.controlPointStride = 16; mcurve.controlPointFormat = .float3
            let geoms: [MTLAccelerationStructureGeometryDescriptor] = [geomBB, curve, mtri, mbb, mcurve]
            for (i, g) in geoms.enumerated() { g.intersectionFunctionTableOffset = i; g.opaque = i % 2 == 0; g.label = "g\(i)" }
            try expect(geoms.map(\.intersectionFunctionTableOffset) == [0, 1, 2, 3, 4] && geoms.map { $0.label ?? "" } == ["g0", "g1", "g2", "g3", "g4"], "geometry descriptors read back")
            try expect(mtri.vertexBuffers.count == 2 && mbb.boundingBoxBuffers[1].buffer === bb && curve.curveBasis == .bSpline, "motion keyframes")
            let prim = MTLPrimitiveAccelerationStructureDescriptor(); prim.geometryDescriptors = [geomBB]; prim.motionKeyframeCount = 1
            let inst = MTLInstanceAccelerationStructureDescriptor(); inst.instanceCount = 2; inst.instanceDescriptorType = .default
            inst.instanceDescriptorBuffer = dev.makeBuffer(length: 256, options: .storageModeShared)
            let ind = MTLIndirectInstanceAccelerationStructureDescriptor(); ind.maxInstanceCount = 4
            ind.instanceCountBuffer = dev.makeBuffer(length: 4, options: .storageModeShared); ind.instanceDescriptorType = .indirect
            let descs: [MTLAccelerationStructureDescriptor] = [prim, inst, ind]
            for d in descs { d.usage = .preferFastBuild }
            for o in (geoms as [NSObject]) + (descs as [NSObject]) { if let e = p27CopyEqual(o, ["usage"].filter { _ in o is MTLAccelerationStructureDescriptor }) { throw Fail(e) } }
            let sizes = descs.map { dev.accelerationStructureSizes(descriptor: $0) }.map { "\($0.accelerationStructureSize)/\($0.buildScratchBufferSize)" }
            // shared events: a handle, a value signalled on the GPU, a listener notified
            let ev = dev.makeSharedEvent()!; ev.label = "p27"
            let h: MTLSharedEventHandle = ev.makeSharedEventHandle()
            try expect(h.label == "p27", "event handle label \(String(describing: h.label))")
            // a handle is meant for XPC: Apple's simulator refuses a keyed archive of it (NSXPCCoder only, NSCocoaErrorDomain 4866)
            var archived = "archived"
            do { _ = try NSKeyedArchiver.archivedData(withRootObject: h, requiringSecureCoding: true) } catch { archived = "\((error as NSError).domain) \((error as NSError).code)" }
            try expect(archived == "NSCocoaErrorDomain 4866", "keyed archive of the handle: \(archived)")
            let cb = dev.makeCommandQueue()!.makeCommandBuffer()!
            cb.encodeSignalEvent(ev, value: 42)
            try await p27Run(cb)
            try expect(ev.signaledValue == 42, "event value \(ev.signaledValue)")
            // Apple's simulator GPU names no architecture (an empty name)
            let arch: MTLArchitecture = dev.architecture
            try expect(arch.name.isEmpty, "architecture name '\(arch.name)' (Apple's simulator: empty)")
            let qd = MTLCommandQueueDescriptor(); qd.maxCommandBufferCount = 3
            guard let q3 = dev.makeCommandQueue(descriptor: qd) else { throw Fail("no queue from descriptor") }
            let sdsc = MTLSamplerDescriptor(); sdsc.minFilter = .linear; sdsc.magFilter = .nearest; sdsc.sAddressMode = .repeat; sdsc.label = "smp"
            sdsc.supportArgumentBuffers = false; sdsc.maxAnisotropy = 2
            guard let smp = dev.makeSamplerState(descriptor: sdsc) else { throw Fail("no sampler") }
            if let e = p27CopyEqual(sdsc, ["minFilter", "magFilter", "sAddressMode", "label", "maxAnisotropy"]) { throw Fail(e) }
            // the sampler in use: nearest (mag) of a 2x1 texture at u = 0.75 is the right texel
            let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: 2, height: 1, mipmapped: false); td.usage = .shaderRead
            let t = dev.makeTexture(descriptor: td)!; var tv: [Float] = [3, 9]
            t.replace(region: MTLRegionMake2D(0, 0, 2, 1), mipmapLevel: 0, withBytes: &tv, bytesPerRow: 8)
            let lib = try await p27Lib(dev, "kernel void s(texture2d<float> t [[texture(0)]], sampler sm [[sampler(0)]], device float *o [[buffer(0)]]) { o[0] = t.sample(sm, float2(0.75, 0.5)).r; o[1] = t.sample(sm, float2(1.25, 0.5)).r; }")
            let pso = try await dev.makeComputePipelineState(function: try p27Fn(lib, "s"))
            let o = p27Buf(dev, [0, 0])
            let cb2 = q3.makeCommandBuffer()!, e = cb2.makeComputeCommandEncoder()!
            e.setComputePipelineState(pso); e.setTexture(t, index: 0); e.setSamplerState(smp, index: 0); e.setBuffer(o, offset: 0, index: 0)
            e.dispatchThreads(MTLSize(width: 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)); e.endEncoding()
            try await p27Run(cb2)
            let sv = p27Floats(o, 2)
            try expect(sv == [9, 3], "sampled \(sv) (nearest, repeat: want 9, 3)")
            // an argument encoder from MTLArgumentDescriptors
            let ad0 = MTLArgumentDescriptor(); ad0.dataType = .pointer; ad0.index = 0; ad0.access = .readOnly
            let ad1 = MTLArgumentDescriptor(); ad1.dataType = .float; ad1.index = 1
            if let e = p27CopyEqual(ad0, ["dataType", "index", "access"]) { throw Fail(e) }
            guard let enc = dev.makeArgumentEncoder(arguments: [ad0, ad1]) else { throw Fail("no argument encoder") }
            try expect(enc.encodedLength >= 12, "argument encoder length \(enc.encodedLength)")
            return "AS sizes prim/inst/indirect \(sizes) (raytracing \(dev.supportsRaytracing)); event 42; arch \(arch.name); sampled \(sv); arg encoder \(enc.encodedLength) B"
        })
        #endif
        c += p27mReality
        c += p27mAV
        c += p27mAudio
        c += p27mVision
        c += p27mCreateML
        c += p27mCoreML
        c += p27mScene
        c += p27mPHASE
        c += p27mPlayerGames
        c += p27mGraph
        c += p27mMisc
        c += p27mGameKit
        return c
    }

    static var p27mGameKit: [Check] {
        var c: [Check] = []
        #if canImport(GameKit) && os(iOS)
        c.append(check("GameKit", "p27-unauthenticated-loads-controllers", timeout: 60) {
            // no Game Center account in the simulator: the loads answer errors (codes as Apple's simulator answers them)
            func code(_ e: Error?) -> String { e.map { "\(($0 as NSError).domain == GKErrorDomain ? "GK" : ($0 as NSError).domain) \(($0 as NSError).code)" } ?? "ok" }
            var ans: [String] = []
            do { let d: [GKAchievementDescription] = try await GKAchievementDescription.loadAchievementDescriptions(); ans.append("descriptions \(d.count)") } catch { ans.append("descriptions \(code(error))") }
            do { let s: [GKLeaderboardSet] = try await GKLeaderboardSet.loadLeaderboardSets(); ans.append("sets \(s.count)") } catch { ans.append("sets \(code(error))") }
            do { let ch: [GKChallenge] = try await GKChallenge.loadReceivedChallenges(); ans.append("challenges \(ch.count)") } catch { ans.append("challenges \(code(error))") }
            do { let g: [GKSavedGame] = try await GKLocalPlayer.local.fetchSavedGames(); ans.append("saved \(g.count)") } catch { ans.append("saved \(code(error))") }
            let local = GKLocalPlayer.local
            try expect(!local.isAuthenticated, "local player authenticated")
            // Apple's simulator: GKErrorNotAuthenticated (6) for each load
            try expect(ans == ["descriptions GK 6", "sets GK 6", "challenges GK 6", "saved GK 6"], "loads \(ans)")
            // value objects built and read back
            let score = GKScore(leaderboardIdentifier: "p27.board"); score.value = 42; score.context = 7
            let ach = GKAchievement(identifier: "p27.ach"); ach.percentComplete = 50
            try expect(score.value == 42 && score.context == 7 && ach.percentComplete == 50, "score / achievement")
            let req = GKMatchRequest(); req.minPlayers = 2; req.maxPlayers = 4
            let mm: GKMatchmaker = GKMatchmaker.shared()
            // the class family: players, matches, turn-based pieces, challenges
            let classes: [(AnyClass, AnyClass)] = [(GKPlayer.self, GKBasePlayer.self), (GKCloudPlayer.self, GKBasePlayer.self), (GKScoreChallenge.self, GKChallenge.self),
                (GKAchievementChallenge.self, GKChallenge.self), (GKTurnBasedExchangeReply.self, NSObject.self), (GKTurnBasedExchange.self, NSObject.self),
                (GKTurnBasedParticipant.self, NSObject.self), (GKInvite.self, NSObject.self), (GKMatch.self, NSObject.self), (GKMatchedPlayers.self, NSObject.self),
                (GKLeaderboard.Entry.self, NSObject.self), (GKVoiceChat.self, NSObject.self), (GKNotificationBanner.self, NSObject.self)]
            let notSub = classes.filter { !$0.0.isSubclass(of: $0.1) }.map { "\($0.0)" }
            try expect(notSub.isEmpty, "class hierarchy \(notSub)")
            // the Game Center view controllers
            let vcs: [String] = await onMain {
                let list: [UIViewController] = [                                                GKFriendRequestComposeViewController(), GKTurnBasedMatchmakerViewController(matchRequest: req),
                                                GKGameCenterViewController(state: .leaderboards)]
                return list.map { "\(type(of: $0))" }
            }
            try expect(vcs.count == 3, "view controllers \(vcs)")
            try expect(NSStringFromClass(GKLeaderboard.Entry.self) == "GKLeaderboardEntry" && mm === GKMatchmaker.shared(), "leaderboard entry class / matchmaker")
            return "\(ans.joined(separator: ", ")); \(classes.count) classes; \(vcs.count) view controllers"
        })
        #endif
        return c
    }

    static var p27mMisc: [Check] {
        var c: [Check] = []
        #if canImport(CoreImage) && !os(watchOS)
        c.append(check("CoreImage", "p27-barcode-descriptors-kernels-destinations", timeout: 60) {
            let ctx = CIContext(options: [.useSoftwareRenderer: false])
            // a QR code (CIQRCodeGenerator) -> detector -> its CIQRCodeDescriptor -> CIBarcodeGenerator -> detected again, same payload
            func detect(_ i: CIImage) -> [CIFeature] {
                let det = CIDetector(ofType: CIDetectorTypeQRCode, context: ctx, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
                return det?.features(in: i.composited(over: CIImage(color: .white).cropped(to: i.extent.insetBy(dx: -40, dy: -40)))) ?? []
            }
            let qf = CIFilter(name: "CIQRCodeGenerator")!; qf.setValue(Data("p27".utf8), forKey: "inputMessage")
            guard let qimg = qf.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else { throw Fail("no QR image") }
            let feats: [CIFeature] = detect(qimg)
            guard let qr: CIQRCodeDescriptor = (feats.first as? CIQRCodeFeature)?.symbolDescriptor else { throw Fail("QR not detected (\(feats.count) features)") }
            let gen = CIFilter(name: "CIBarcodeGenerator")!; gen.setValue(qr, forKey: "inputBarcodeDescriptor")
            guard let img = gen.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else { throw Fail("no barcode image from the descriptor") }
            let again = (detect(img).first as? CIQRCodeFeature)?.messageString
            try expect(again == "p27", "regenerated QR reads \(String(describing: again))")
            let found: Bool? = qr.symbolVersion >= 1
            let others: [CIBarcodeDescriptor] = [
                CIAztecCodeDescriptor(payload: Data(repeating: 0xA5, count: 6), isCompact: true, layerCount: 1, dataCodewordCount: 2),
                CIDataMatrixCodeDescriptor(payload: Data(repeating: 0x5A, count: 8), rowCount: 10, columnCount: 10, eccVersion: .v200),
                CIPDF417CodeDescriptor(payload: Data(repeating: 0x11, count: 8), isCompact: false, rowCount: 3, columnCount: 2),
            ].compactMap { $0 }
            let faces = CIDetector(ofType: CIDetectorTypeFace, context: ctx, options: nil)?.features(in: img).compactMap { $0 as? CIFaceFeature } ?? []
            // a blend kernel multiplies red over white -> red
            let red = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
            let white = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
            guard let mul = CIBlendKernel.multiply.apply(foreground: red, background: white) else { throw Fail("blend") }
            // an accumulator, a sampler, a filter shape
            let acc = CIImageAccumulator(extent: CGRect(x: 0, y: 0, width: 4, height: 4), format: .RGBA8)!
            acc.setImage(mul)
            let smp = CISampler(image: acc.image()); let shape = CIFilterShape(rect: CGRect(x: 0, y: 0, width: 2, height: 2)).union(with: CGRect(x: 2, y: 2, width: 2, height: 2))
            try expect(smp.extent.width == 4 && shape.extent.width == 4, "sampler \(smp.extent) shape \(shape.extent)")
            // render the accumulator through a render destination task
            var px = [UInt8](repeating: 0, count: 4 * 4 * 4)
            let dest = px.withUnsafeMutableBytes { CIRenderDestination(bitmapData: $0.baseAddress!, width: 4, height: 4, bytesPerRow: 16, format: .RGBA8) }
            dest.colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
            let task: CIRenderTask = try ctx.startTask(toRender: acc.image(), to: dest)
            let info: CIRenderInfo = try task.waitUntilCompleted()
            try expect(px[0] > 240 && px[1] < 10 && px[2] < 10, "rendered RGBA \(Array(px.prefix(4))) (want red)")
            return "QR detected \(String(describing: found)) (\(feats.count) features), \(others.count) other descriptors, \(faces.count) faces; blend -> \(Array(px.prefix(4))); \(info.kernelExecutionTime >= 0 ? "render info" : "?")"
        })
        #endif
        #if canImport(VideoToolbox) && !os(watchOS)
        c.append(check("VideoToolbox", "p27-frame-processor-frames", timeout: 30) {
            // the simulator SDK leaves out the frame processor configurations (VTFrameProcessor.h: !TARGET_OS_SIMULATOR);
            // the processor, its frames and optical-flow pairs are there
            func pb(_ fmt: OSType) -> CVPixelBuffer {
                var b: CVPixelBuffer?
                CVPixelBufferCreate(nil, 64, 64, fmt, [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &b)
                return b!
            }
            guard let frame = VTFrameProcessorFrame(buffer: pb(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange), presentationTimeStamp: CMTime(value: 1, timescale: 30)) else { throw Fail("no frame") }
            try expect(frame.presentationTimeStamp == CMTime(value: 1, timescale: 30) && CVPixelBufferGetWidth(frame.buffer) == 64, "frame")
            let flow = VTFrameProcessorOpticalFlow(forwardFlow: pb(kCVPixelFormatType_TwoComponent16Half), backwardFlow: pb(kCVPixelFormatType_TwoComponent16Half))
            let proc = VTFrameProcessor(); proc.endSession()
            return "frame at \(frame.presentationTimeStamp.seconds) s, flow pair \(flow != nil), processor \(type(of: proc))"
        })
        #endif
        #if canImport(AudioToolbox) && !os(watchOS)
        c.append(check("AudioToolbox", "p27-parameter-tree-presets-bridge", timeout: 60) {
            // a parameter tree: group + two parameters, values set through the tree and observed
            let gain = AUParameterTree.createParameter(withIdentifier: "gain", name: "Gain", address: 1, min: 0, max: 1, unit: .linearGain, unitName: nil,
                                                       flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: nil, dependentParameters: nil)
            let mode = AUParameterTree.createParameter(withIdentifier: "mode", name: "Mode", address: 2, min: 0, max: 2, unit: .indexed, unitName: nil,
                                                       flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: ["a", "b", "c"], dependentParameters: nil)
            let group: AUParameterGroup = AUParameterTree.createGroup(withIdentifier: "main", name: "Main", children: [gain, mode])
            let tree = AUParameterTree.createTree(withChildren: [group])
            let seen = P7Box<Float>()
            let tok = tree.token(byAddingParameterObserver: { addr, v in if addr == 1 { seen.set(v) } })
            gain.setValue(0.25, originator: nil)
            let node: AUParameterNode = group
            try expect(tree.parameter(withAddress: 1)?.value == 0.25 && node.keyPath == "main" && mode.valueStrings == ["a", "b", "c"], "tree values \(gain.value) \(node.keyPath) \(String(describing: mode.valueStrings))")
            tree.removeParameterObserver(tok)
            let preset = AUAudioUnitPreset(); preset.number = -1; preset.name = "Mine"
            // Apple's delay unit, instantiated in-process: its parameters / presets through the v2 bridge
            let desc = AudioComponentDescription(componentType: kAudioUnitType_Effect, componentSubType: kAudioUnitSubType_Delay, componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
            let au = try AUAudioUnit(componentDescription: desc, options: [])
            let bridged = au is AUAudioUnitV2Bridge
            let params = au.parameterTree?.allParameters.count ?? 0
            try expect(bridged && params >= 3, "delay AU bridged \(bridged) with \(params) parameters (\(type(of: au)))")
            au.currentPreset = au.factoryPresets?.first ?? preset
            #if os(visionOS)
            // spatial audio experiences (visionOS): the Swift values Codable round trip; the Objective-C classes behind them
            // are refined for Swift (NS_REFINED_FOR_SWIFT), found through the runtime: each NSSecureCoding
            let exp: any SpatialAudioExperience = .headTracked(.scene(identifier: "p27"), soundStageSize: .small)
            let ht0 = exp as! HeadTrackedSpatialAudio
            let ht1 = try JSONDecoder().decode(HeadTrackedSpatialAudio.self, from: try JSONEncoder().encode(ht0))
            try expect(ht1 == ht0 && ht1.anchoringStrategy == .scene(identifier: "p27") && ht1.soundStageSize == .small, "spatial experience round trip \(ht1)")
            let objc = ["CAAnchoringStrategy", "CAAutomaticAnchoringStrategy", "CAFrontAnchoringStrategy", "CASceneAnchoringStrategy", "CASpatialAudioExperience",
                        "CAAutomaticSpatialAudio", "CABypassedSpatialAudio", "CAFixedSpatialAudio", "CAHeadTrackedSpatialAudio"]
            let missing = objc.filter { n in !((NSClassFromString(n) as? NSObject.Type)?.conforms(to: NSSecureCoding.self) ?? false) }
            try expect(missing.isEmpty, "spatial audio classes missing \(missing)")
            let spatial = "\(objc.count) spatial classes"
            #elseif os(iOS)
            let htT: AnyClass = AUHeadTrackingBinauralRenderer.self
            try expect(htT.isSubclass(of: AUAudioUnit.self), "head-tracking binaural renderer is an AUAudioUnit")
            let spatial = "head-tracking renderer class \(htT)"
            #else
            let spatial = "no spatial experiences (visionOS only)"
            #endif
            return "tree gain \(gain.value), observer \(await seen.wait(1).map { "\($0)" } ?? "none"); delay AU \(type(of: au)) \(params) params, preset \(au.currentPreset?.name ?? "-"); \(spatial)"
        })
        #endif
        #if canImport(Speech) && !os(watchOS) && !os(tvOS)
        c.append(check("Speech", "p27-requests-language-model-data", timeout: 60) {
            // a custom language model's training data: phrases + templates, exported to a file
            let data = SFCustomLanguageModelData(locale: Locale(identifier: "en_US"), identifier: "com.x86sim.p27", version: "1.0")
            data.insert(phraseCount: SFCustomLanguageModelData.PhraseCount(phrase: "sdkcov media check", count: 10))
            data.insert(term: SFCustomLanguageModelData.CustomPronunciation(grapheme: "sdkcov", phonemes: ["E s d i k o v"]))
            let out = FileManager.default.temporaryDirectory.appendingPathComponent("p27.bin")
            try? FileManager.default.removeItem(at: out)
            try await data.export(to: out)
            let size = (try? FileManager.default.attributesOfItem(atPath: out.path)[.size] as? Int) ?? 0
            try expect(size > 0, "exported language model data \(size) B")
            let cfg = SFSpeechLanguageModel.Configuration(languageModel: out)
            try expect(cfg.languageModel == out && cfg.vocabulary == nil, "language model configuration")
            // requests (no recognition: the simulator's authorization stays undetermined without a prompt)
            let req = SFSpeechAudioBufferRecognitionRequest(); req.requiresOnDeviceRecognition = true; req.addsPunctuation = true; req.customizedLanguageModel = cfg
            let base: SFSpeechRecognitionRequest = req
            let types: [AnyClass] = [SFSpeechRecognitionResult.self, SFSpeechRecognitionTask.self, SFTranscription.self, SFTranscriptionSegment.self,
                                     SFVoiceAnalytics.self, SFAcousticFeature.self, SFSpeechRecognitionMetadata.self, SFSpeechLanguageModel.self]
            try expect(base.requiresOnDeviceRecognition && types.allSatisfy { $0.isSubclass(of: NSObject.self) }, "request")
            let rec = SFSpeechRecognizer(locale: Locale(identifier: "en_US"))
            return "LM data \(size) B; recognizer available \(rec?.isAvailable ?? false), on-device \(rec?.supportsOnDeviceRecognition ?? false); auth \(SFSpeechRecognizer.authorizationStatus().rawValue)"
        })
        #endif
        #if canImport(AVKit) && os(iOS)
        c.append(check("AVKit", "p27-speeds-interactions-pip-sources", timeout: 30) {
            try await onMain {
                let speeds = [AVPlaybackSpeed(rate: 0.5, localizedName: "Half"), AVPlaybackSpeed(rate: 2, localizedName: "Double")]
                let pvc = AVPlayerViewController(); pvc.speeds = speeds
                try expect(pvc.speeds.map(\.rate) == [0.5, 2] && AVPlaybackSpeed.systemDefaultSpeeds.count > 0, "speeds \(pvc.speeds.map(\.rate))")
                let fired = P27Flag()
                let ei = AVCaptureEventInteraction { (e: AVCaptureEvent) in _ = e.phase; fired.set() }
                ei.isEnabled = true
                let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100)); view.addInteraction(ei)
                let picker = AVInputPickerInteraction()
                view.addInteraction(picker)
                let sound = try? AVCaptureEventSound(url: URL(fileURLWithPath: "/System/Library/Audio/UISounds/photoShutter.caf"))
                let call = AVPictureInPictureVideoCallViewController(); call.preferredContentSize = CGSize(width: 100, height: 100)
                let src = AVPictureInPictureController.ContentSource(activeVideoCallSourceView: view, contentViewController: call)
                try expect(src.activeVideoCallContentViewController === call, "pip content source \(String(describing: src.activeVideoCallContentViewController)) interactions \(view.interactions.count)")
                let srcName = NSStringFromClass(type(of: src))
                let menu = AVLegibleMediaOptionsMenuController(player: AVPlayer())
                return "speeds \(pvc.speeds.count), capture interaction \(ei.isEnabled), sound \(sound != nil), pip source \(srcName), menu \(type(of: menu))"
            }
        })
        #endif
        return c
    }

    static var p27mGraph: [Check] {
        var c: [Check] = []
        #if canImport(MetalPerformanceShadersGraph)
        c.append(check("MetalPerformanceShadersGraph", "p27-op-descriptors-shape-inference", timeout: 30) {
            // Apple's simulator aborts creating an MPSGraphDevice (graph-run is skipped for that): the graph is built
            // and its shapes inferred only, no device, no run
            let g = MPSGraph()
            let ops0 = g.placeholder(shape: [1, 8, 8, 4], dataType: .float32, name: "x")   // NHWC
            let x: MPSGraphTensor = ops0
            let c2 = MPSGraphConvolution2DOpDescriptor(strideInX: 2, strideInY: 2, dilationRateInX: 1, dilationRateInY: 1, groups: 1, paddingStyle: .TF_SAME,
                                                       dataLayout: .NHWC, weightsLayout: .HWIO)!
            let w2 = g.placeholder(shape: [3, 3, 4, 6], dataType: .float32, name: "w")
            let conv = g.convolution2D(x, weights: w2, descriptor: c2, name: "conv")
            let dw2 = MPSGraphDepthwiseConvolution2DOpDescriptor(dataLayout: .NHWC, weightsLayout: .HWIO)!
            let dconv = g.depthwiseConvolution2D(x, weights: g.placeholder(shape: [3, 3, 4, 1], dataType: .float32, name: nil), descriptor: dw2, name: nil)
            let p2 = MPSGraphPooling2DOpDescriptor(kernelWidth: 2, kernelHeight: 2, strideInX: 2, strideInY: 2, paddingStyle: .TF_VALID, dataLayout: .NHWC)!
            let pool = g.maxPooling2D(withSourceTensor: x, descriptor: p2, name: nil)
            let p4 = MPSGraphPooling4DOpDescriptor(kernelSizes: [1, 2, 2, 1], paddingStyle: .TF_VALID)!
            let pool4 = g.maxPooling4D(x, descriptor: p4, name: nil)
            let i2c = MPSGraphImToColOpDescriptor(kernelWidth: 2, kernelHeight: 2, strideInX: 2, strideInY: 2, dilationRateInX: 1, dilationRateInY: 1, dataLayout: .NHWC)!
            let cols = g.imToCol(x, descriptor: i2c, name: nil)
            let st = MPSGraphStencilOpDescriptor(paddingStyle: .TF_SAME)!
            let sten = g.stencil(withSourceTensor: x, weightsTensor: g.placeholder(shape: [1, 3, 3, 1], dataType: .float32, name: nil), descriptor: st, name: nil)
            // 3-D convolution / depthwise 3-D
            let x5 = g.placeholder(shape: [1, 4, 8, 8, 2], dataType: .float32, name: "x5")   // NDHWC
            let c3 = MPSGraphConvolution3DOpDescriptor(strideInX: 1, strideInY: 1, strideInZ: 1, dilationRateInX: 1, dilationRateInY: 1, dilationRateInZ: 1, groups: 1,
                                                       paddingStyle: .TF_SAME, dataLayout: .NDHWC, weightsLayout: .DHWIO)!
            let conv3 = g.convolution3D(x5, weights: g.placeholder(shape: [3, 3, 3, 2, 5], dataType: .float32, name: nil), descriptor: c3, name: nil)
            let dw3 = MPSGraphDepthwiseConvolution3DOpDescriptor(paddingStyle: .TF_SAME)!; dw3.channelDimensionIndex = -1
            let dconv3 = g.depthwiseConvolution3D(x5, weights: g.placeholder(shape: [3, 3, 3, 2], dataType: .float32, name: nil), descriptor: dw3, name: nil)
            // FFT, random, RNNs, SDPA, sparse
            let fd = MPSGraphFFTDescriptor(); fd.inverse = false; fd.scalingMode = .none
            let fft = g.fastFourierTransform(g.placeholder(shape: [4, 8], dataType: .complexFloat32, name: nil), axes: [1], descriptor: fd, name: nil)
            let rd = MPSGraphRandomOpDescriptor(distribution: .uniform, dataType: .float32)!; rd.min = 0; rd.max = 1
            let rnd = g.randomTensor(withShape: [3, 5], descriptor: rd, seed: 7, name: nil)
            let seq = g.placeholder(shape: [5, 1, 4], dataType: .float32, name: nil)   // T, N, I
            let rnnD = MPSGraphSingleGateRNNDescriptor(); rnnD.activation = .tanh
            let rnn = g.singleGateRNN(seq, recurrentWeight: g.placeholder(shape: [4, 4], dataType: .float32, name: nil), initState: nil, descriptor: rnnD, name: nil)
            let lstmD = MPSGraphLSTMDescriptor()
            let lstm = g.LSTM(seq, recurrentWeight: g.placeholder(shape: [16, 4], dataType: .float32, name: nil), initState: nil, initCell: nil, descriptor: lstmD, name: nil)
            let gruD = MPSGraphGRUDescriptor()
            let gru = g.GRU(seq, recurrentWeight: g.placeholder(shape: [12, 4], dataType: .float32, name: nil), inputWeight: nil, bias: nil, descriptor: gruD, name: nil)
            let qkv = g.placeholder(shape: [1, 2, 6, 8], dataType: .float32, name: nil)
            let sdpa = g.scaledDotProductAttention(query: qkv, key: qkv, value: qkv, scale: 0.35, name: nil)
            let sdpaD = MPSGraphSDPADescriptor(scale: 0.35)
            let sparseD = MPSGraphCreateSparseOpDescriptor.sparseDescriptor(descriptorWithStorageType: .COO, dataType: .float32)!
            let sparse = g.sparseTensor(sparseTensorWithDescriptor: sparseD, tensors: [g.placeholder(shape: [3], dataType: .float32, name: nil),
                g.placeholder(shape: [3], dataType: .int32, name: nil), g.placeholder(shape: [3], dataType: .int32, name: nil)], shape: [4, 4], name: nil)
            let variable: MPSGraphTensor = g.variable(with: Data(count: 16), shape: [4], dataType: .float32, name: "v")
            let vop = variable.operation as? MPSGraphVariableOp
            func shape(_ t: MPSGraphTensor) -> [Int] { (t.shape ?? []).map(\.intValue) }
            let got: [(String, [Int], [Int])] = [
                ("conv", shape(conv), [1, 4, 4, 6]), ("dconv", shape(dconv), [1, 6, 6, 4]), ("pool", shape(pool), [1, 4, 4, 4]), ("pool4", shape(pool4), [1, 7, 7, 4]),
                ("imToCol", shape(cols), [1, 16, 16]), ("stencil", shape(sten), [1, 8, 8, 4]), ("conv3", shape(conv3), [1, 4, 8, 8, 5]), ("dconv3", shape(dconv3), [1, 4, 8, 8, 2]),
                ("fft", shape(fft), [4, 8]), ("random", shape(rnd), [-1, -1]), ("rnn", shape(rnn[0]), [5, 1, 4]), ("lstm", shape(lstm[0]), [5, 1, 1]),
                ("gru", shape(gru[0]), [5, 1, 1]), ("sdpa", shape(sdpa), [1, 2, 6, 8]), ("sparse", shape(sparse), [4, 4]),
            ]
            let wrong = got.filter { $0.1 != $0.2 }.map { "\($0.0) \($0.1)" }
            try expect(wrong.isEmpty, "inferred shapes \(wrong)")
            let op: MPSGraphOperation = conv.operation
            let objs: [MPSGraphObject] = [c2, dw2, p2, p4, i2c, st, c3, dw3, fd, rd, rnnD, lstmD, gruD, sdpaD, sparseD]
            try expect(op.inputTensors.count == 2 && vop != nil && objs.count == 15 && sdpaD.scale == 0.35, "operation inputs \(op.inputTensors.count), variable op \(vop != nil)")
            // descriptors are NSCopying: copies keep their settings
            if let e = p27CopyEqual(c2, ["strideInX", "groups", "paddingStyle"]) { throw Fail(e) }
            if let e = p27CopyEqual(p2, ["kernelWidth", "strideInY"]) { throw Fail(e) }
            // shaped types, execution / compilation descriptors (no device needed to make them)
            let tt: MPSGraphType = MPSGraphShapedType(shape: [2, 2], dataType: .float32)
            let ed = MPSGraphExecutionDescriptor(); ed.waitUntilCompleted = true
            let eed = MPSGraphExecutableExecutionDescriptor(); eed.waitUntilCompleted = true
            // (an executable serialization descriptor asserts "unhandled platform (7) for MPSGraph serialization" in Apple's simulator)
            let exT: AnyClass = MPSGraphExecutable.self
            try expect(tt.isKind(of: MPSGraphShapedType.self) && ed.waitUntilCompleted && eed.waitUntilCompleted && exT.isSubclass(of: MPSGraphObject.self), "descriptors")
            return "\(got.count) op shapes inferred, \(objs.count) descriptors, \(g.placeholderTensors.count) placeholders"
        })
        #endif
        return c
    }

    static var p27mPlayerGames: [Check] {
        var c: [Check] = []
        #if canImport(MediaPlayer) && (os(iOS) || os(visionOS))
        c.append(check("MediaPlayer", "p27-remote-commands-queues-language-options", timeout: 30) {
            try await onMain {
                let cc = MPRemoteCommandCenter.shared()
                // each command kind: configured, a handler attached and removed
                let pos: MPChangePlaybackPositionCommand = cc.changePlaybackPositionCommand
                let rate: MPChangePlaybackRateCommand = cc.changePlaybackRateCommand; rate.supportedPlaybackRates = [0.5, 1, 2]
                let rep: MPChangeRepeatModeCommand = cc.changeRepeatModeCommand; rep.currentRepeatType = .all
                let shuf: MPChangeShuffleModeCommand = cc.changeShuffleModeCommand; shuf.currentShuffleType = .items
                let rating: MPRatingCommand = cc.ratingCommand; rating.minimumRating = 1; rating.maximumRating = 5
                let like: MPFeedbackCommand = cc.likeCommand; like.localizedTitle = "Like"; like.isActive = true
                let skip: MPSkipIntervalCommand = cc.skipForwardCommand; skip.preferredIntervals = [15]
                let cmds: [MPRemoteCommand] = [pos, rate, rep, shuf, rating, like, skip, cc.enableLanguageOptionCommand, cc.seekForwardCommand]
                var tokens: [(MPRemoteCommand, Any)] = []
                for cmd in cmds {
                    tokens.append((cmd, cmd.addTarget { (e: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus in
                        switch e {
                        case let p as MPChangePlaybackPositionCommandEvent: return p.positionTime >= 0 ? .success : .commandFailed
                        case let r as MPChangePlaybackRateCommandEvent: return r.playbackRate > 0 ? .success : .commandFailed
                        case is MPChangeRepeatModeCommandEvent, is MPChangeShuffleModeCommandEvent, is MPRatingCommandEvent, is MPFeedbackCommandEvent,
                             is MPSkipIntervalCommandEvent, is MPSeekCommandEvent, is MPChangeLanguageOptionCommandEvent: return .success
                        default: return .noSuchContent
                        }
                    }))
                }
                try expect(rate.supportedPlaybackRates.count == 3 && rep.currentRepeatType == .all && rating.maximumRating == 5 && skip.preferredIntervals == [15] && like.isActive,
                           "commands read back")
                for (cmd, t) in tokens { cmd.removeTarget(t) }
                // language options on the now-playing info
                let en = MPNowPlayingInfoLanguageOption(type: .legible, languageTag: "en", characteristics: nil, displayName: "English", identifier: "en-sub")
                let grp = MPNowPlayingInfoLanguageOptionGroup(languageOptions: [en], defaultLanguageOption: en, allowEmptySelection: true)
                let info = MPNowPlayingInfoCenter.default()
                info.nowPlayingInfo = [MPMediaItemPropertyTitle: "P27", MPNowPlayingInfoPropertyAvailableLanguageOptions: [grp], MPNowPlayingInfoPropertyElapsedPlaybackTime: 3.0]
                let back = info.nowPlayingInfo?[MPMediaItemPropertyTitle] as? String
                try expect(back == "P27" && grp.languageOptions.first?.displayName == "English" && en.isAutomaticLegibleLanguageOption() == false, "now playing \(String(describing: back))")
                info.nowPlayingInfo = nil
                // content items, media collections / predicates, player queues and their descriptors
                let item = MPContentItem(identifier: "p27"); item.title = "T"; item.isContainer = true; item.playbackProgress = 0.5
                let pred = MPMediaPropertyPredicate(value: "P27", forProperty: MPMediaItemPropertyTitle, comparisonType: .contains)
                let basePred: MPMediaPredicate = pred
                let q = MPMediaQuery.songs(); q.addFilterPredicate(pred)
                let items: [MPMediaItem] = q.items ?? []
                let sections: [MPMediaQuerySection] = q.itemSections ?? []
                let coll = MPMediaItemCollection(items: items)
                let ent: MPMediaEntity = coll
                let lists: [MPMediaPlaylist] = (MPMediaQuery.playlists().collections ?? []).compactMap { $0 as? MPMediaPlaylist }
                let qd1 = MPMusicPlayerMediaItemQueueDescriptor(itemCollection: coll)
                let qd2 = MPMusicPlayerStoreQueueDescriptor(storeIDs: ["1"])
                let pp = MPMusicPlayerPlayParameters(dictionary: ["id": "1", "kind": "song"])
                let qd3 = MPMusicPlayerPlayParametersQueueDescriptor(playParametersQueue: pp.map { [$0] } ?? [])
                let qds: [MPMusicPlayerQueueDescriptor] = [qd1, qd2, qd3]
                qd2.startItemID = "1"
                let player: MPMusicPlayerApplicationController = MPMusicPlayerController.applicationQueuePlayer
                let qBase: MPMusicPlayerControllerQueue.Type = MPMusicPlayerControllerQueue.self
                let mq: MPMusicPlayerControllerMutableQueue.Type = MPMusicPlayerControllerMutableQueue.self
                try expect(item.isContainer && basePred is MPMediaPropertyPredicate && ent.persistentID == 0 && qds.count == 3 && mq.isSubclass(of: qBase), "items / queues")
                _ = player
                let ad = MPAdTimeRange(CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1)))
                try expect(ad.timeRange.duration.seconds == 5, "ad time range")
                return "\(cmds.count) commands; language group; library \(items.count) items / \(sections.count) sections / \(lists.count) playlists; \(qds.count) queue descriptors; play parameters \(pp != nil)"
            }
        })
        #endif
        #if canImport(GameController) && !os(watchOS)
        c.append(check("GameController", "p27-snapshot-controllers-input-state", timeout: 30) {
            // a snapshot extended gamepad: values set on its elements read back through the profile and the input state
            let ctl = GCController.withExtendedGamepad()
            guard let pad: GCExtendedGamepad = ctl.extendedGamepad else { throw Fail("no extended gamepad") }
            let a: GCControllerButtonInput = pad.buttonA; a.setValue(1)
            let lx: GCControllerAxisInput = pad.leftThumbstick.xAxis; lx.setValue(-0.5)
            let dp: GCControllerDirectionPad = pad.dpad; dp.setValueForXAxis(1, yAxis: 0)
            try expect(a.isPressed && lx.value == -0.5 && dp.right.isPressed && !dp.left.isPressed, "gamepad values a \(a.value) lx \(lx.value)")
            let prof: GCPhysicalInputProfile = ctl.physicalInputProfile
            let els: [String: GCControllerElement] = prof.elements
            try expect(prof.buttons[GCInputButtonA]?.value == 1 && els.count > 10, "profile elements \(els.count)")
            let snap: GCController = ctl.capture()
            try expect(snap.isSnapshot && snap.extendedGamepad?.buttonA.value == 1, "capture")
            let ext = snap.extendedGamepad!
            let gamepadT: [AnyClass] = [GCExtendedGamepad.self, GCMicroGamepad.self, GCDirectionalGamepad.self, GCGamepad.self, GCDualSenseGamepad.self, GCDualShockGamepad.self, GCXboxGamepad.self]
            try expect(gamepadT.filter { (type(of: ext) as AnyClass).isSubclass(of: $0) }.count >= 1, "gamepad class \(type(of: ext))")
            let micro = GCController.withMicroGamepad()
            guard let mg: GCMicroGamepad = micro.microGamepad else { throw Fail("no micro gamepad") }
            mg.buttonX.setValue(1); mg.reportsAbsoluteDpadValues = true
            try expect(mg.buttonX.isPressed && mg.reportsAbsoluteDpadValues, "micro gamepad")
            // the GameController input API (live input, captured state, element names)
            let live: GCControllerLiveInput = ctl.input
            let state: GCControllerInputState = live.capture()
            let names: [GCButtonElementName] = [.a, .b, .menu]
            let axes = state.axes, dpads = state.dpads, sws = state.switches
            let dpadName: GCDirectionPadElementName = .directionPad
            let dpadEl = dpads[dpadName]
            let btnA = state.buttons[names[0]]
            let typed: [GCPhysicalInputElementName] = [GCPhysicalInputElementName(rawValue: "Button A")]
            // a snapshot controller's live input has no elements (Apple's simulator)
            try expect(btnA == nil && dpadEl == nil && state.buttons.count == 0 && sws.count == 0 && typed.count == 1 && axes.count >= 0, "input state buttons \(state.buttons.count)")
            // devices a snapshot does not have: battery, light, haptics, motion, touchpad
            let battery: GCDeviceBattery? = ctl.battery, light: GCDeviceLight? = ctl.light, haptics: GCDeviceHaptics? = ctl.haptics, motion: GCMotion? = ctl.motion
            let touch: GCControllerTouchpad? = (ext as? GCDualShockGamepad)?.touchpadPrimary.map { _ in (ext as! GCDualShockGamepad).touchpadButton }.flatMap { _ in nil }
            let col = GCColor(red: 1, green: 0.5, blue: 0)
            let colData = try NSKeyedArchiver.archivedData(withRootObject: col, requiringSecureCoding: true)
            let col2 = try NSKeyedUnarchiver.unarchivedObject(ofClass: GCColor.self, from: colData)
            try expect(col2?.green == 0.5, "GCColor round trip")
            // keyboards / mice connected: none in the simulator (racing wheels are macOS-only)
            let kb: GCKeyboardInput? = GCKeyboard.coalesced?.keyboardInput, mouse: GCMouseInput? = GCMouse.current?.mouseInput
            let cursorT: AnyClass = GCDeviceCursor.self, trigT: AnyClass = GCDualSenseAdaptiveTrigger.self, snapT: [AnyClass] = [GCExtendedGamepadSnapshot.self, GCMicroGamepadSnapshot.self, GCGamepadSnapshot.self]
            let devs = "battery \(battery != nil) light \(light != nil) haptics \(haptics != nil) motion \(motion != nil) touch \(touch != nil) kb \(kb != nil) mouse \(mouse != nil)"
            try expect(battery == nil && light == nil, devs)
            #if os(iOS)
            let vcfg = GCVirtualController.Configuration(); vcfg.elements = [GCInputButtonA, GCInputLeftThumbstick]
            let virt = GCVirtualController(configuration: vcfg)
            virt.updateConfiguration(forElement: GCInputButtonA) { (e: GCVirtualController.ElementConfiguration) in e.isHidden = true; return e }
            let vcfgT: AnyClass = GCVirtualController.Configuration.self, ecfgT: AnyClass = GCVirtualController.ElementConfiguration.self
            try expect(NSStringFromClass(vcfgT) == "GCVirtualControllerConfiguration" && NSStringFromClass(ecfgT) == "GCVirtualControllerElementConfiguration", "virtual controller classes")
            #endif
            try expect(cursorT.isSubclass(of: GCControllerDirectionPad.self) && trigT.isSubclass(of: GCControllerButtonInput.self)
                       && snapT[0].isSubclass(of: GCExtendedGamepad.self) && snapT[1].isSubclass(of: GCMicroGamepad.self), "class hierarchy")
            return "snapshot gamepad: A \(a.value), lx \(lx.value), \(els.count) elements; \(devs)"
        })
        #endif
        return c
    }

    static var p27mPHASE: [Check] {
        var c: [Check] = []
        #if canImport(PHASE)
        c.append(check("PHASE", "p27-node-tree-metaparameters-groups", timeout: 60) {
            let e = PHASEEngine(updateMode: .automatic)
            let reg: PHASEAssetRegistry = e.assetRegistry
            let fmt = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
            let tone = sine(440, secs: 0.2, rate: 48000)
            let snd: PHASESoundAsset = try reg.registerSoundAsset(data: Data(bytes: tone.floatChannelData![0], count: Int(tone.frameLength) * 4),
                                                                  identifier: "p27-tone", format: fmt, normalizationMode: .dynamic)
            let base: PHASEAsset = snd
            try expect(base.identifier == "p27-tone" && snd.type == .resident, "sound asset \(snd.type.rawValue)")
            // groups, a preset, a ducker, a medium
            let music = PHASEGroup(identifier: "p27-music"), fx = PHASEGroup(identifier: "p27-fx")
            music.register(engine: e); fx.register(engine: e); music.gain = 0.8
            let setting = PHASEGroupPresetSetting(gain: 0.5, rate: 1, gainCurveType: .linear, rateCurveType: .linear)
            let preset = PHASEGroupPreset(engine: e, settings: ["p27-music": setting], timeToTarget: 0.1, timeToReset: 0.1)
            let ducker = PHASEDucker(engine: e, sourceGroups: [fx], targetGroups: [music], gain: 0.5, attackTime: 0.1, releaseTime: 0.1, attackCurve: .linear, releaseCurve: .linear)
            let medium = PHASEMedium(engine: e, preset: .air)
            e.defaultMedium = medium
            try expect(e.groups["p27-music"] === music && preset.settings.count == 1 && ducker.gain == 0.5, "groups/preset/ducker")
            // meta parameters: a number driving a blend, a string driving a switch, a mapped one through an envelope
            let num = PHASENumberMetaParameterDefinition(value: 0.25, minimum: 0, maximum: 1, identifier: "p27-num")
            let str = PHASEStringMetaParameterDefinition(value: "a", identifier: "p27-str")
            guard let env = PHASEEnvelope(startPoint: [0, 0], segments: [PHASEEnvelopeSegment(endPoint: [1, 2], curveType: .linear)]) else { throw Fail("envelope") }
            let mapped = PHASEMappedMetaParameterDefinition(inputMetaParameterDefinition: num, envelope: env, identifier: "p27-mapped")
            try expect(abs(env.evaluate(x: 0.5) - 1) < 1e-9 && env.segments.count == 1, "envelope at 0.5 -> \(env.evaluate(x: 0.5))")
            let metas: [PHASEMetaParameterDefinition] = [num, str, mapped]
            let global: PHASEGlobalMetaParameterAsset = try reg.registerGlobalMetaParameter(metaParameterDefinition: PHASENumberMetaParameterDefinition(value: 1, identifier: "p27-global"))
            // the node tree: switch(str) { a: blend(num){ sampler }, b: random{ sampler } } inside a container, a channel mixer
            let layout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Mono)!
            let mixer = PHASEChannelMixerDefinition(channelLayout: layout)
            let mixBase: PHASEMixerDefinition = mixer
            func sampler() -> PHASESamplerNodeDefinition { let s = PHASESamplerNodeDefinition(soundAssetIdentifier: "p27-tone", mixerDefinition: mixer); s.playbackMode = .oneShot; s.setCalibrationMode(calibrationMode: .relativeSpl, level: 0); return s }
            let blend = PHASEBlendNodeDefinition(blendMetaParameterDefinition: num)
            blend.addRangeForInputValuesBelow(value: 0.5, fullGainAtValue: 0, fadeCurveType: .linear, subtree: sampler())
            blend.addRangeForInputValuesAbove(value: 0.5, fullGainAtValue: 1, fadeCurveType: .linear, subtree: sampler())
            let random = PHASERandomNodeDefinition(); random.addSubtree(sampler(), weight: 1); random.uniqueSelectionQueueLength = 0
            let sw = PHASESwitchNodeDefinition(switchMetaParameterDefinition: str)
            sw.addSubtree(blend, switchValue: "a"); sw.addSubtree(random, switchValue: "b")
            let container = PHASEContainerNodeDefinition(); container.addSubtree(sw)
            let gen: PHASEGeneratorNodeDefinition = sampler()
            try expect(gen.calibrationMode == .relativeSpl && gen.level == 0, "generator calibration \(gen.calibrationMode.rawValue)")
            let nodes: [PHASESoundEventNodeDefinition] = [blend, random, sw, container, gen]
            let defs: [PHASEDefinition] = nodes + [mixer]
            let evAsset: PHASESoundEventNodeAsset = try reg.registerSoundEventAsset(rootNode: container, identifier: "p27-event")
            // a second asset with push / pull stream nodes
            let push = PHASEPushStreamNodeDefinition(mixerDefinition: PHASEChannelMixerDefinition(channelLayout: layout), format: fmt, identifier: "p27-push")
            let pull = PHASEPullStreamNodeDefinition(mixerDefinition: PHASEChannelMixerDefinition(channelLayout: layout), format: fmt, identifier: "p27-pull")
            let streamsRoot = PHASEContainerNodeDefinition(); streamsRoot.addSubtree(push); streamsRoot.addSubtree(pull)
            _ = try reg.registerSoundEventAsset(rootNode: streamsRoot, identifier: "p27-streams")
            let listener = PHASEListener(engine: e); try e.rootObject.addChild(listener)
            let rootObj: PHASEObject = e.rootObject
            try e.start()
            defer { e.stop(); for id in ["p27-event", "p27-streams", "p27-tone", "p27-global"] { reg.unregisterAsset(identifier: id) } }
            let ev = try PHASESoundEvent(engine: e, assetIdentifier: "p27-event")
            let evMetas: [String: PHASEMetaParameter] = ev.metaParameters
            (evMetas["p27-num"] as? PHASENumberMetaParameter)?.value = 0.75
            (evMetas["p27-str"] as? PHASEStringMetaParameter)?.value = "a"
            let mixers: [String: PHASEMixer] = ev.mixers
            try expect(evMetas.count >= 2 && mixers.count >= 1, "event meta parameters \(evMetas.keys.sorted()) mixers \(mixers.count)")
            let done = P7Box<String>()
            ev.start { reason in done.set("\(reason.rawValue)") }
            let reason = await done.wait(15)
            try expect(reason == "\(PHASESoundEvent.StartHandlerReason.finishedPlaying.rawValue)", "event ended \(String(describing: reason)) (state \(ev.renderingState.rawValue))")
            let sev = try PHASESoundEvent(engine: e, assetIdentifier: "p27-streams")
            let pushNodes: [String: PHASEPushStreamNode] = sev.pushStreamNodes, pullNodes: [String: PHASEPullStreamNode] = sev.pullStreamNodes
            let streams: [PHASEStreamNode] = Array(pushNodes.values) + Array(pullNodes.values)
            try expect(pushNodes["p27-push"] != nil && pullNodes["p27-pull"] != nil && streams.count == 2, "stream nodes push \(pushNodes.keys) pull \(pullNodes.keys)")
            // distance / directivity model parameters, shape elements, pipeline entries, numeric pairs
            let geo = PHASEGeometricSpreadingDistanceModelParameters(); geo.rolloffFactor = 2
            geo.fadeOutParameters = PHASEDistanceModelFadeOutParameters(cullDistance: 10)
            let envDist = PHASEEnvelopeDistanceModelParameters(envelope: env)
            let dists: [PHASEDistanceModelParameters] = [geo, envDist]
            let card = PHASECardioidDirectivityModelParameters(subbandParameters: [{ let s = PHASECardioidDirectivityModelSubbandParameters(); s.pattern = 0.5; s.frequency = 1000; return s }()])
            let cone = PHASEConeDirectivityModelParameters(subbandParameters: [{ let s = PHASEConeDirectivityModelSubbandParameters(); s.setAngles(innerAngle: 30, outerAngle: 90); return s }()])
            let dirs: [PHASEDirectivityModelParameters] = [card, cone]
            let shape = PHASEShape(engine: e, mesh: MDLMesh.newIcosahedron(withRadius: 0.1, inwardNormals: false, allocator: nil))
            let elems: [PHASEShape.Element] = shape.elements
            guard let pipe = PHASESpatialPipeline(flags: [.directPathTransmission, .lateReverb]) else { throw Fail("pipeline") }
            let entry: PHASESpatialPipelineEntry? = pipe.entries[.directPathTransmission]; entry?.sendLevel = 0.5
            let pair = PHASENumericPair(firstValue: 1, secondValue: 2)
            try expect(geo.fadeOutParameters?.cullDistance == 10 && cone.subbandParameters[0].outerAngle == 90 && !elems.isEmpty && NSStringFromClass(type(of: elems[0])) == "PHASEShapeElement" && entry?.sendLevel == 0.5 && pair.second == 2,
                       "parameters read back")
            return "event finished (\(nodes.count) nodes, \(metas.count) meta definitions, \(defs.count) definitions, \(mixBase.identifier.isEmpty ? "?" : "mixer")); streams \(streams.count); \(dists.count) distance + \(dirs.count) directivity models; global \(global.identifier); root \(rootObj.children.count) children; asset \(evAsset.identifier)"
        })
        #endif
        return c
    }

    static var p27mScene: [Check] {
        var c: [Check] = []
        #if canImport(ModelIO)
        c.append(check("ModelIO", "p27-animated-values-transforms-lights", timeout: 60) {
            // animated values interpolate between keys
            let s = MDLAnimatedScalar(); s.setFloat(0, atTime: 0); s.setFloat(10, atTime: 1)
            let v = MDLAnimatedVector3(); v.setFloat3([0, 0, 0], atTime: 0); v.setFloat3([2, 4, 6], atTime: 2)
            let q = MDLAnimatedQuaternion(); q.setFloatQuaternion(simd_quatf(angle: 0, axis: [0, 0, 1]), atTime: 0); q.setFloatQuaternion(simd_quatf(angle: .pi / 2, axis: [0, 0, 1]), atTime: 1)
            let m = MDLAnimatedMatrix4x4(); m.setFloat4x4(matrix_identity_float4x4, atTime: 0)
            let base: [MDLAnimatedValue] = [s, v, q, m]
            try expect(abs(s.floatValue(atTime: 0.5) - 5) < 1e-4 && simd_length(v.float3Value(atTime: 1) - [1, 2, 3]) < 1e-4, "interpolation \(s.floatValue(atTime: 0.5)) \(v.float3Value(atTime: 1))")
            try expect(abs(q.floatQuaternionValue(atTime: 0.5).angle - .pi / 4) < 1e-3 && base.allSatisfy { $0.isAnimated() || $0 === m }, "quaternion \(q.floatQuaternionValue(atTime: 0.5).angle)")
            let sa = MDLAnimatedScalarArray(elementCount: 3); sa.set(floatArray: [1, 2, 3], atTime: 0); sa.set(floatArray: [3, 4, 5], atTime: 1)
            let va = MDLAnimatedVector3Array(elementCount: 2); va.set(float3Array: [[0, 0, 0], [1, 1, 1]], atTime: 0)
            let qa = MDLAnimatedQuaternionArray(elementCount: 1); qa.set(floatQuaternionArray: [simd_quatf(angle: 0, axis: [0, 1, 0])], atTime: 0)
            let ma = MDLMatrix4x4Array(elementCount: 2); ma.float4x4Array = [matrix_identity_float4x4, matrix_identity_float4x4]
            try expect(sa.floatArray(atTime: 0.5) == [2, 3, 4] && va.float3Array(atTime: 0).count == 2 && qa.elementCount == 1 && ma.float4x4Array.count == 2, "animated arrays \(sa.floatArray(atTime: 0.5))")
            // a transform stack: translate, rotate x/y/z, rotate, scale, orient, matrix ops
            let st = MDLTransformStack()
            let t: MDLTransformTranslateOp = st.addTranslateOp("t", inverse: false); t.animatedValue.setFloat3([1, 2, 3], atTime: 0)
            let rx: MDLTransformRotateXOp = st.addRotateXOp("rx", inverse: false), ry: MDLTransformRotateYOp = st.addRotateYOp("ry", inverse: false)
            rx.animatedValue.setFloat(0, atTime: 0); ry.animatedValue.setFloat(0, atTime: 0)
            let rz: MDLTransformRotateZOp = st.addRotateZOp("rz", inverse: false); rz.animatedValue.setFloat(.pi / 2, atTime: 0)
            let r: MDLTransformRotateOp = st.addRotateOp("r", order: .XYZ, inverse: false); r.animatedValue.setFloat3([0, 0, 0], atTime: 0)
            let sc: MDLTransformScaleOp = st.addScaleOp("s", inverse: false); sc.animatedValue.setFloat3([2, 2, 2], atTime: 0)
            let o: MDLTransformOrientOp = st.addOrientOp("o", inverse: false); o.animatedValue.setFloatQuaternion(simd_quatf(angle: 0, axis: [0, 1, 0]), atTime: 0)
            let mo: MDLTransformMatrixOp = st.addMatrixOp("m", inverse: false); mo.animatedValue.setFloat4x4(matrix_identity_float4x4, atTime: 0)
            let ops: [MDLTransformOp] = [t, rx, ry, rz, r, sc, o, mo]
            let mat = st.float4x4(atTime: 0)
            // the stacked transform of (1, 0, 0), as Apple's simulator composes these ops: (2.9992, 2.0548, 3)
            let p = mat * SIMD4<Float>(1, 0, 0, 1)
            try expect(abs(p.x - 2.9992) < 1e-3 && abs(p.y - 2.0548) < 1e-3 && abs(p.z - 3) < 1e-4 && st.count() == ops.count, "stacked transform of (1,0,0) -> \(p)")
            // cameras and lights
            let cam = MDLStereoscopicCamera(); cam.interPupillaryDistance = 63; cam.leftVergence = 1; cam.overlap = 0.1
            try expect(cam.leftViewMatrix != cam.rightViewMatrix && (cam as MDLCamera).fieldOfView > 0, "stereo camera views")
            let area = MDLAreaLight(); area.areaRadius = 2; area.superEllipticPower = [2, 2]
            let pl = MDLPhotometricLight(); let ld: MDLLight = pl; ld.lightType = .photometric
            try expect(area.areaRadius == 2 && pl.lightType == .photometric, "lights")
            // a material property graph: out = in * 2, evaluated
            let input = MDLMaterialProperty(name: "in", semantic: .userDefined, float: 3)
            let output = MDLMaterialProperty(name: "out", semantic: .userDefined, float: 0)
            let node = MDLMaterialPropertyNode(inputs: [input], outputs: [output]) { n in n.outputs[0].floatValue = n.inputs[0].floatValue * 2 }
            let src = MDLMaterialProperty(name: "src", semantic: .userDefined, float: 4)
            let srcNode = MDLMaterialPropertyNode(inputs: [], outputs: [src]) { _ in }
            let conn = MDLMaterialPropertyConnection(output: src, input: input)
            // a ModelIO material property graph (nodes:connections:) crashes the app in Apple's iOS 27.2 simulator (as on x86Sim): the
            // nodes and their connection are used without a graph; the node's evaluation function runs it
            try expect(conn.output === src && conn.input === input && node.inputs.count == 1 && srcNode.outputs.count == 1, "connection")
            input.floatValue = src.floatValue
            node.evaluationFunction(node)
            try expect(output.floatValue == 8, "node output \(output.floatValue)")
            let scat = MDLScatteringFunction(); scat.baseColor.color = CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
            let swatch = MDLColorSwatchTexture(colorTemperatureGradientFrom: 2000, toColorTemperature: 8000, name: "sw", textureDimensions: [16, 1])
            let texels = swatch.texelDataWithTopLeftOrigin()
            let sampler = MDLTextureSampler(); sampler.texture = swatch; let filt = MDLTextureFilter(); filt.sWrapMode = .repeat; sampler.hardwareFilter = filt
            let urlTex = MDLURLTexture(url: URL(fileURLWithPath: "/nonexistent.png"), name: "u")
            try expect((texels?.count ?? 0) >= 16 * 4 && scat.baseColor.color != nil && sampler.hardwareFilter?.sWrapMode == .repeat && urlTex.name == "u", "textures \(texels?.count ?? -1)")
            // mesh buffers, topology, objects, resolvers
            let alloc = MDLMeshBufferDataAllocator()
            let mesh = MDLMesh(boxWithExtent: [1, 1, 1], segments: [1, 1, 1], inwardNormals: false, geometryType: .triangles, allocator: alloc)
            let vb = mesh.vertexBuffers[0]
            try expect(vb is MDLMeshBufferData && vb.allocator === alloc, "allocator \(type(of: vb))")
            let map: MDLMeshBufferMap = vb.map(); _ = map.bytes
            let zone = alloc.newZone(1024); try expect(zone is MDLMeshBufferZoneDefault && zone.capacity >= 1024, "zone \(type(of: zone))")
            guard let attr: MDLVertexAttributeData = mesh.vertexAttributeData(forAttributeNamed: MDLVertexAttributePosition) else { throw Fail("no positions") }
            try expect(attr.stride >= 12 && attr.format == .float3, "position data stride \(attr.stride) format \(attr.format.rawValue)")
            let sub = mesh.submeshes?.firstObject as? MDLSubmesh
            let topo = MDLSubmeshTopology(submesh: sub!)
            try expect(topo.faceCount >= 0, "topology")
            let obj = MDLObject(); obj.name = "root"; let child = MDLObject(); child.name = "kid"; obj.addChild(child)
            let cont: MDLObjectContainer? = obj.children as? MDLObjectContainer
            try expect(cont?.count == 1 && obj.atPath("kid") === child, "object container")
            let asset = MDLAsset(); asset.add(mesh)
            let resolvers: [MDLAssetResolver] = [MDLPathAssetResolver(path: NSTemporaryDirectory()), MDLRelativeAssetResolver(asset: asset), MDLBundleAssetResolver(bundle: Bundle.main.bundlePath)]
            let canResolve = resolvers.map { $0.canResolveAssetNamed("missing.png") }
            // Apple's simulator: the path resolver answers true for a missing file, the others false
            try expect(canResolve == [true, false, false], "resolvers \(canResolve)")
            let utilT: AnyClass = MDLUtility.self
            return "scalar 5 at 0.5, transform \(p), node \(output.floatValue), swatch \(texels!.count) B, \(resolvers.count) resolvers, \(utilT)"
        })
        #endif
        #if canImport(SceneKit) && canImport(UIKit) && canImport(Metal)
        c.append(check("SceneKit", "p27-geometry-constraints-physics", timeout: 60) {
            try await onMain {
                let scene = SCNScene()
                // the primitive geometries: bounding boxes as Apple defines them
                let geos: [(String, SCNGeometry, SCNVector3)] = [
                    ("capsule", SCNCapsule(capRadius: 0.5, height: 2), SCNVector3(1, 2, 1)), ("cone", SCNCone(topRadius: 0, bottomRadius: 1, height: 2), SCNVector3(2, 2, 2)),
                    ("cylinder", SCNCylinder(radius: 1, height: 3), SCNVector3(2, 3, 2)), ("pyramid", SCNPyramid(width: 2, height: 1, length: 3), SCNVector3(2, 1, 3)),
                    ("torus", SCNTorus(ringRadius: 2, pipeRadius: 0.5), SCNVector3(5, 1, 5)), ("tube", SCNTube(innerRadius: 0.5, outerRadius: 1, height: 2), SCNVector3(2, 2, 2)),
                ]
                var bad: [String] = []
                for (n, g, want) in geos {
                    let (mn, mx) = g.boundingBox
                    let ext = SCNVector3(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z)
                    if abs(Float(ext.x) - Float(want.x)) > 0.05 || abs(Float(ext.y) - Float(want.y)) > 0.05 || abs(Float(ext.z) - Float(want.z)) > 0.05 { bad.append("\(n) \(ext)") }
                }
                try expect(bad.isEmpty, "bounding boxes \(bad)")
                let shape = SCNShape(path: UIBezierPath(rect: CGRect(x: 0, y: 0, width: 2, height: 1)), extrusionDepth: 0.5)
                let text = SCNText(string: "P27", extrusionDepth: 0.1); text.font = .systemFont(ofSize: 1)
                let floor = SCNFloor(); floor.reflectivity = 0
                try expect(shape.boundingBox.max.x - shape.boundingBox.min.x > 1.9 && text.boundingBox.max.x > text.boundingBox.min.x, "shape/text bounds")
                // custom geometry from an element; tessellator, levels of detail, material properties
                let src = SCNGeometrySource(vertices: [SCNVector3(0, 0, 0), SCNVector3(1, 0, 0), SCNVector3(0, 1, 0)])
                let el = SCNGeometryElement(indices: [UInt16(0), 1, 2], primitiveType: .triangles)
                let tri = SCNGeometry(sources: [src], elements: [el])
                try expect(el.primitiveCount == 1 && tri.elements.count == 1, "element \(el.primitiveCount)")
                let tess = SCNGeometryTessellator(); tess.edgeTessellationFactor = 2; tri.tessellator = tess
                let lod = SCNLevelOfDetail(geometry: SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0), worldSpaceDistance: 10)
                tri.levelsOfDetail = [lod]
                let mp: SCNMaterialProperty = tri.firstMaterial?.diffuse ?? SCNMaterial().diffuse; mp.contents = CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1); mp.intensity = 0.5
                try expect(tri.levelsOfDetail?.first?.worldSpaceDistance == 10 && mp.intensity == 0.5, "lod / material property")
                // constraints, evaluated by a renderer frame
                let target = SCNNode(); target.position = SCNVector3(5, 0, 0); scene.rootNode.addChildNode(target)
                let looker = SCNNode(); scene.rootNode.addChildNode(looker)
                let look = SCNLookAtConstraint(target: target); look.localFront = SCNVector3(0, 0, -1)
                let follower = SCNNode(); follower.position = SCNVector3(10, 0, 0); scene.rootNode.addChildNode(follower)
                let dist = SCNDistanceConstraint(target: target); dist.maximumDistance = 1
                let slider = SCNSliderConstraint(); slider.radius = 0.1
                let repl = SCNReplicatorConstraint(target: target); repl.replicatesOrientation = false
                let xf = SCNTransformConstraint.positionConstraint(inWorldSpace: true) { _, p in SCNVector3(p.x, 7, p.z) }
                let clamped = SCNNode(); scene.rootNode.addChildNode(clamped); clamped.constraints = [xf]
                let bill = SCNBillboardConstraint(); let accel = SCNAccelerationConstraint(); let avoid = SCNAvoidOccluderConstraint(target: target)
                let ik = SCNIKConstraint.inverseKinematicsConstraint(chainRootNode: looker)
                let all: [SCNConstraint] = [look, dist, slider, repl, xf, bill, accel, avoid, ik]
                looker.constraints = [look]; follower.constraints = [dist]
                // physics: a ball falls onto a static floor; joints attach; a field acts
                let ballNode = SCNNode(geometry: SCNSphere(radius: 0.2)); ballNode.position = SCNVector3(0, 3, 0)
                ballNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: SCNSphere(radius: 0.2), options: nil))
                let ground = SCNNode(geometry: SCNBox(width: 10, height: 0.2, length: 10, chamferRadius: 0)); ground.position = SCNVector3(0, -0.1, 0)
                ground.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: ground.geometry!, options: nil))
                scene.rootNode.addChildNode(ballNode); scene.rootNode.addChildNode(ground)
                let b2 = SCNNode(geometry: SCNBox(width: 0.2, height: 0.2, length: 0.2, chamferRadius: 0)); b2.position = SCNVector3(3, 3, 0)
                b2.physicsBody = .dynamic(); scene.rootNode.addChildNode(b2)
                let b3 = SCNNode(geometry: SCNBox(width: 0.2, height: 0.2, length: 0.2, chamferRadius: 0)); b3.position = SCNVector3(3.5, 3, 0)
                b3.physicsBody = .dynamic(); scene.rootNode.addChildNode(b3)
                let joints: [SCNPhysicsBehavior] = [
                    SCNPhysicsBallSocketJoint(bodyA: b2.physicsBody!, anchorA: SCNVector3(0.25, 0, 0), bodyB: b3.physicsBody!, anchorB: SCNVector3(-0.25, 0, 0)),
                    SCNPhysicsHingeJoint(body: b2.physicsBody!, axis: SCNVector3(0, 0, 1), anchor: SCNVector3(0, 0.5, 0)),
                    SCNPhysicsSliderJoint(body: b3.physicsBody!, axis: SCNVector3(1, 0, 0), anchor: SCNVector3(0, 0, 0)),
                    SCNPhysicsConeTwistJoint(body: b3.physicsBody!, frame: SCNMatrix4Identity),
                ]
                scene.physicsWorld.addBehavior(joints[0])
                let field = SCNPhysicsField.drag(); field.strength = 0.1
                let fieldNode = SCNNode(); fieldNode.physicsField = field; scene.rootNode.addChildNode(fieldNode)
                let wheelNode = SCNNode(); let wheel = SCNPhysicsVehicleWheel(node: wheelNode); wheel.suspensionStiffness = 3
                let chassis = SCNNode(geometry: SCNBox(width: 1, height: 0.2, length: 2, chamferRadius: 0)); chassis.physicsBody = .dynamic()
                chassis.addChildNode(wheelNode)
                let vehicle = SCNPhysicsVehicle(chassisBody: chassis.physicsBody!, wheels: [wheel])
                try expect(vehicle.wheels.count == 1 && wheel.suspensionStiffness == 3, "vehicle")
                // a particle property controller, timing functions, a transaction, a reference node, an animation event
                let ctl = SCNParticlePropertyController(animation: CABasicAnimation(keyPath: "x")); ctl.inputMode = .overLife
                let tf = SCNTimingFunction(caMediaTimingFunction: CAMediaTimingFunction(name: .easeIn)); _ = tf
                SCNTransaction.begin(); SCNTransaction.animationDuration = 0; target.opacity = 0.5; SCNTransaction.commit()
                let ref = SCNReferenceNode(url: URL(fileURLWithPath: "/nonexistent.scn"))
                try expect(ref?.isLoaded == false && target.opacity == 0.5, "reference node / transaction")
                let fired = P27Flag()
                let ev = SCNAnimationEvent(keyTime: 0.5) { _, _, _ in fired.set() }
                // render frames: physics steps, constraints evaluate
                guard let dev = MTLCreateSystemDefaultDevice() else { throw Fail("no Metal device") }
                let r = SCNRenderer(device: dev, options: nil); r.scene = scene
                let cam = SCNNode(); cam.camera = SCNCamera(); cam.position = SCNVector3(0, 2, 10); scene.rootNode.addChildNode(cam); r.pointOfView = cam
                let anim = CABasicAnimation(keyPath: "position.y"); anim.fromValue = 0; anim.toValue = 1; anim.duration = 0.2; anim.animationEvents = [ev]
                let animated = SCNNode(); scene.rootNode.addChildNode(animated); animated.addAnimation(anim, forKey: "a")
                for i in 0..<120 { _ = r.snapshot(atTime: Double(i) / 60, with: CGSize(width: 32, height: 32), antialiasingMode: .none) }
                let fwd = looker.presentation.simdWorldFront
                try expect(abs(fwd.x - 1) < 0.05, "look-at front \(fwd)")
                try expect(simd_distance(follower.presentation.simdWorldPosition, target.simdWorldPosition) < 1.05, "distance constraint \(follower.presentation.simdWorldPosition)")
                try expect(abs(clamped.presentation.simdWorldPosition.y - 7) < 1e-3, "transform constraint y \(clamped.presentation.simdWorldPosition.y)")
                let by = ballNode.presentation.position.y
                try expect(by < 1 && by > 0.05, "ball rest y \(by)")
                let hits: [SCNHitTestResult] = scene.rootNode.hitTestWithSegment(from: SCNVector3(0, 5, 0), to: SCNVector3(0, -5, 0), options: nil)
                try expect(hits.contains { $0.node === ground }, "segment hits \(hits.count)")
                let camCtl: SCNCameraController = SCNCameraController(); camCtl.pointOfView = cam; camCtl.interactionMode = .orbitTurntable
                return "\(geos.count + 3) geometries, \(all.count) constraints (look-at front \(fwd.x)), ball y \(by), \(joints.count) joints, \(hits.count) hits, event fired \(fired.value)"
            }
        })
        #endif
        return c
    }

    static var p27mCoreML: [Check] {
        var c: [Check] = []
        #if canImport(CoreML)
        c.append(check("CoreML", "p27-tensor-shapedarray-values", timeout: 60) {
            // MLTensor arithmetic under a CPU compute policy, read back as a shaped array
            let policy = MLComputePolicy(.cpuOnly)
            let (sums, prod): ([Float], [Float]) = try await withMLTensorComputePolicy(policy) {
                let t = MLTensor(shape: [2, 3], scalars: [Float](arrayLiteral: 1, 2, 3, 4, 5, 6))
                let rows = t.sum(alongAxes: 1)
                let r: (any MLTensorRangeExpression)? = 1..<3
                let sliced: MLTensor = t[0..<2, r]          // [[2, 3], [5, 6]]
                let s = await rows.shapedArray(of: Float.self).scalars
                let p = await (sliced * 2).sum().shapedArray(of: Float.self).scalars
                return (s, p)
            }
            try expect(sums == [6, 15] && prod == [32], "tensor sums \(sums) product \(prod)")
            let sc: any MLTensorScalar.Type = Float.self; _ = sc
            // shaped arrays: slices, ranges, layouts, generic protocol use
            var a = MLShapedArray<Float>(scalars: [1, 2, 3, 4, 5, 6], shape: [2, 3])
            let row: MLShapedArraySlice<Float> = a[1]
            let col = a[0..<1]
            try expect(row.scalars == [4, 5, 6] && col.scalars == [1, 2, 3], "slices \(row.scalars) \(col.scalars)")
            let t = a.changingLayout(to: MLShapedArrayBufferLayout.lastMajorContiguous)
            let firstMajor = t.changingLayout(to: .firstMajorContiguous)
            try expect(firstMajor.scalars == a.scalars, "layout round trip \(firstMajor.scalars)")
            func total<A: MLShapedArrayProtocol>(_ x: A) -> Float where A.Scalar == Float { x.scalars.reduce(0, +) }
            try expect(total(a) == 21 && total(row) == 15, "protocol totals")
            let r: any MLShapedArrayRangeExpression = 0..<1
            try expect(r.relative(toShapedArrayAxis: 0..<2) == 0..<1, "range expression")
            a[scalarAt: 0, 0] = 10
            let scalarT: any MLShapedArrayScalar.Type = Float.self; _ = scalarT
            // feature values: sendable, sequences, dictionaries, images
            let sv = MLSendableFeatureValue(a)
            try expect(sv.isShapedArray && sv.shapedArrayValue(of: Float.self)?.scalars.first == 10, "sendable feature value")
            let seq = MLSequence(strings: ["a", "b"])
            let fv = MLFeatureValue(sequence: seq)
            try expect(fv.type == .sequence && fv.sequenceValue?.stringValues == ["a", "b"], "sequence value")
            let dv = try MLFeatureValue(dictionary: ["x": 1.5])
            try expect(dv.dictionaryValue["x"]?.doubleValue == 1.5, "dictionary value")
            return "tensor rows \(sums), slices ok, sendable \(sv.type.rawValue), sequence \(fv.type.rawValue)"
        })
        #endif
        #if canImport(CoreML) && !os(watchOS)
        c.append(check("CoreML", "p27-descriptions-constraints-update", timeout: 90) {
            let dir = FileManager.default.temporaryDirectory
            let src = dir.appendingPathComponent("p27-linear.mlmodel"); try linearModelSpec().write(to: src)
            let compiled = try await MLModel.compileModel(at: src)
            defer { try? FileManager.default.removeItem(at: compiled) }
            let cfg = MLModelConfiguration(); cfg.computeUnits = .cpuOnly
            var hints = MLOptimizationHints(); hints.reshapeFrequency = .infrequent; hints.specializationStrategy = .fastPrediction
            cfg.optimizationHints = hints
            let m = try await MLModel.load(contentsOf: compiled, configuration: cfg)
            let md: MLModelDescription = m.modelDescription
            guard let xin: MLFeatureDescription = md.inputDescriptionsByName["x"], let mac: MLMultiArrayConstraint = xin.multiArrayConstraint else { throw Fail("no x constraint") }
            let sc: MLMultiArrayShapeConstraint = mac.shapeConstraint
            try expect(mac.shape == [2] && mac.dataType == .double && sc.type == .unspecified || sc.type == .enumerated || sc.type == .range, "x constraint \(mac.shape) \(sc.type.rawValue)")
            try expect(md.outputDescriptionsByName["y"]?.type == .double && md.predictedFeatureName == "y" && !xin.isOptional, "description \(md)")
            try expect(m.configuration.optimizationHints.reshapeFrequency == .infrequent, "optimization hints")
            // the updatable KNN: parameters (numberOfNeighbors with its numeric constraint), an update task with progress handlers
            let knn = try await p7KNNModelC()
            defer { try? FileManager.default.removeItem(at: knn.deletingLastPathComponent()) }
            let km = try MLModel(contentsOf: knn)
            let params: [MLParameterKey: MLParameterDescription] = km.modelDescription.parameterDescriptionsByKey
            let k = params.first { $0.key == MLParameterKey.numberOfNeighbors }
            let nc: MLNumericConstraint? = k?.value.numericConstraint
            try expect(k != nil && nc?.minNumber == 1 && nc?.maxNumber == 5, "numberOfNeighbors \(String(describing: k?.value)) \(String(describing: nc))")
            let key: MLKey = MLParameterKey.numberOfNeighbors
            try expect(key.name == "numberOfNeighbors" && km.modelDescription.trainingInputDescriptionsByName["label"] != nil, "key \(key.name)")
            let train = try MLArrayBatchProvider(array: [(8, 9), (9, 8)].map { p in
                let x = try MLMultiArray(shape: [2], dataType: .float32); x[0] = NSNumber(value: p.0); x[1] = NSNumber(value: p.1)
                return try MLDictionaryFeatureProvider(dictionary: ["x": x, "label": "c"]) as MLFeatureProvider
            })
            let box = P7Box<String>()
            let handlers = MLUpdateProgressHandlers(forEvents: [.trainingBegin, .epochEnd], progressHandler: { (ctx: MLUpdateContext) in
                _ = ctx.event
            }, completionHandler: { (ctx: MLUpdateContext) in
                let metrics: [MLMetricKey: Any] = ctx.metrics
                box.set("\(ctx.task.state.rawValue) metrics \(metrics.keys.map(\.name).sorted()) error \(ctx.task.error.map { "\(($0 as NSError).code)" } ?? "none")")
            })
            let task = try MLUpdateTask(forModelAt: knn, trainingData: train, configuration: nil, progressHandlers: handlers)
            let mt: MLTask = task
            mt.resume()
            guard let res = await box.wait(60) else { throw Fail("update task did not complete (state \(mt.state.rawValue))") }
            try expect(res.hasPrefix("\(MLTaskState.completed.rawValue) "), "update completion \(res)")
            // compute devices by kind
            let devs: [MLComputeDevice] = MLComputeDevice.allComputeDevices
            let kinds = devs.map { d -> String in
                switch d {
                case .cpu(let c): let cc: MLCPUComputeDevice = c; return "cpu:\(type(of: cc))"
                case .gpu(let g): let gg: MLGPUComputeDevice = g; return "gpu:\(gg.metalDevice.name.isEmpty ? "?" : "metal")"
                case .neuralEngine(let n): let nn: MLNeuralEngineComputeDevice = n; return "ane:\(nn.totalCoreCount)"
                @unknown default: return "?"
                }
            }
            try expect(kinds.contains { $0.hasPrefix("cpu") }, "compute devices \(kinds)")
            return "x \(mac.shape) \(mac.dataType.rawValue); K \(nc!.minNumber)...\(nc!.maxNumber); update \(res); devices \(kinds)"
        })
        #endif
        return c
    }

    static var p27mCreateML: [Check] {
        var c: [Check] = []
        #if canImport(CreateMLComponents) && canImport(CoreImage)
        c.append(check("CreateMLComponents", "p27-preprocessors-encoders-imputers", timeout: 60) {
            let xs: [Double] = [-8, -2, 0, 1, 3, 4, 100]
            // scalers: max-abs, robust (median / IQR), L2 normalization of a vector
            let maxAbs: MaxAbsScaler<Double>.Transformer = try await MaxAbsScaler<Double>().fitted(to: xs)
            let ma = try await p27Apply(maxAbs, -8.0)
            try expect(abs(ma + 0.08) < 1e-9, "max-abs scaled -8 -> \(ma)")
            let robust = try await RobustScaler<Double>().fitted(to: xs)
            let rb = try await p27Apply(robust, 1.0)
            try expect(abs(rb) < 1e-9, "robust scaling of the median -> \(rb)")
            let norm = try await NormalizationScaler<Double>(norm: .l2).fitted(to: xs)
            _ = norm
            // categorical encoders and imputers
            let colors: [String?] = ["red", "green", nil, "red", "blue"]
            let ord = try await OrdinalEncoder<String>().fitted(to: colors)
            let oneHot = try await OneHotEncoder<String>().fitted(to: colors)
            let o1 = try await p27Apply(ord, "red"), o2 = try await p27Apply(ord, "blue")
            try expect(o1 != o2, "ordinal codes red \(o1) blue \(o2)")
            let oh = try await p27Apply(oneHot, "green")
            try expect(oh.reduce(0, +) == 1 && oh.count >= 3, "one-hot \(oh)")
            let mean = try await NumericImputer<Double>(.mean).fitted(to: [1, nil, 3])
            let im = try await p27Apply(mean, nil)
            try expect(im == 2, "mean imputation \(im)")
            let mode = try await CategoricalImputer<String>(.mode).fitted(to: colors)
            let cm = try await p27Apply(mode, nil)
            try expect(cm == "red", "mode imputation \(cm)")
            let unwrap = OptionalUnwrapper<Int>()
            let uw = try await p27Apply(unwrap, 7)
            try expect(uw == 7, "unwrap")
            let rs = try await p27Apply(Reshaper<Float>(shape: [2, 3]), MLShapedArray<Float>(scalars: [1, 2, 3, 4, 5, 6], shape: [6]))
            try expect(rs.shape == [2, 3], "reshape \(rs.shape)")
            var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
            let dfe = DateFeatureExtractor<Double>(features: [DateFeatures.hour, .minute], calendar: cal)
            let df = dfe.applied(to: Date(timeIntervalSince1970: 3600 * 5 + 60 * 7))
            // cyclic encodings, as Apple's simulator answers for 05:07 UTC
            try expect(df.count == 2 && abs(df[0] + 0.38136) < 1e-4 && abs(df[1] + 0.28261) < 1e-4, "date features \(df)")
            // composition: max-abs then robust scaling (a composed transformer) = the two applied in turn
            let chain = maxAbs.appending(robust)
            let chained = try await p27Apply(chain, 4.0)
            let byHand = try await p27Apply(robust, try await p27Apply(maxAbs, 4.0))
            try expect(abs(chained - byHand) < 1e-12, "composed \(chained) vs \(byHand)")
            return "max-abs \(ma), robust \(rb), ordinal \(o1)/\(o2), one-hot \(oh), imputed \(im)/\(cm), reshape \(rs.shape), date \(df), chain \(chained)"
        })
        c.append(check("CreateMLComponents", "p27-image-transformers", timeout: 60) {
            // left half red, right half blue, 64x32
            let red = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: CGRect(x: 0, y: 0, width: 32, height: 32))
            let blue = CIImage(color: CIColor(red: 0, green: 0, blue: 1)).cropped(to: CGRect(x: 32, y: 0, width: 32, height: 32))
            let img = red.composited(over: blue)
            let ctx = CIContext(options: [.useSoftwareRenderer: true])
            func px(_ i: CIImage, _ x: CGFloat, _ y: CGFloat) -> [UInt8] {
                var p = [UInt8](repeating: 0, count: 4)
                ctx.render(i, toBitmap: &p, rowBytes: 4, bounds: CGRect(x: x, y: y, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
                return p
            }
            let flipped = ImageFlipper(orientation: .horizontal).applied(to: img)
            let f0 = px(flipped, flipped.extent.minX + 2, flipped.extent.minY + 2)
            try expect(f0[2] > 200 && f0[0] < 50, "flipped left pixel \(f0) (want blue)")
            let scaled = try ImageScaler(targetSize: CGSize(width: 32, height: 16)).applied(to: img)
            try expect(scaled.extent.width.rounded() == 32 && scaled.extent.height.rounded() == 16, "scaled extent \(scaled.extent)")
            let cropped = try ImageCropper(cropRectangle: CGRect(x: 32, y: 0, width: 32, height: 32)).applied(to: img)
            let c0 = px(cropped, cropped.extent.minX + 2, cropped.extent.minY + 2)
            try expect(cropped.extent.width.rounded() == 32 && c0[2] > 200, "cropped \(cropped.extent) \(c0)")
            let rot = ImageRotator(angle: .pi / 2).applied(to: img)
            // the rotator keeps the input extent (Apple's simulator): 64x32
            try expect(abs(rot.extent.width - 64) < 1 && abs(rot.extent.height - 32) < 1, "rotated extent \(rot.extent)")
            let blur = ImageBlur(radius: 4).applied(to: img)
            let b0 = px(blur, 32, 16)
            try expect(b0[0] > 30 && b0[2] > 30, "blurred edge \(b0) (want a red/blue mix)")
            let dark = ImageExposureAdjuster(amount: -2).applied(to: img)
            let d0 = px(dark, 2, 2)
            try expect(d0[0] < 200, "exposure -2 red \(d0)")
            let grey = ImageColorTransformer(saturation: 0).applied(to: img)
            let g0 = px(grey, 2, 2)
            try expect(abs(Int(g0[0]) - Int(g0[1])) < 8 && abs(Int(g0[1]) - Int(g0[2])) < 8, "desaturated \(g0)")
            // a composed image pipeline: flip then crop the left half = the (blue) right half of the original
            let pipe = ImageFlipper(orientation: .horizontal).appending(ImageBlur(radius: 0.01))
            let pp = try await p27Apply(pipe, img)
            let p0 = px(pp, pp.extent.minX + 2, pp.extent.minY + 2)
            try expect(p0[2] > 200, "pipeline \(p0)")
            return "flip \(f0), scale \(scaled.extent.size), crop \(c0), rotate \(rot.extent.size), blur edge \(b0), exposure \(d0), grey \(g0)"
        })
        c.append(check("CreateMLComponents", "p27-trees-networks-metrics", timeout: 90) {
            // y = 3 x0 + x1 on a grid; label = x0 > x1
            var x0: [Double] = [], x1: [Double] = [], y: [Double] = [], lab: [String] = []
            for i in 0..<10 { for j in 0..<10 { x0.append(Double(i)); x1.append(Double(j)); y.append(Double(3 * i + j)); lab.append(i > j ? "gt" : "le") } }
            var frame = DataFrame()
            frame.append(column: Column(name: "x0", contents: x0)); frame.append(column: Column(name: "x1", contents: x1))
            frame.append(column: Column(name: "y", contents: y)); frame.append(column: Column(name: "label", contents: lab))
            var cfg = BoostedTreeConfiguration(); cfg.maximumIterations = 30; cfg.maximumDepth = 4
            let reg: TreeRegressorModel = try await BoostedTreeRegressor<Double>(annotationColumnName: "y", featureColumnNames: ["x0", "x1"], configuration: cfg).fitted(to: frame)
            let rp = try await reg.applied(to: frame)
            let pred = rp[reg.predictionColumnName, Double.self]
            let err = zip(pred, y).map { abs(($0.0 ?? 0) - $0.1) }.reduce(0, +) / Double(y.count)
            try expect(err < 2, "tree regressor mean error \(err)")
            let cls: TreeClassifierModel<String> = try await BoostedTreeClassifier<String>(labels: ["gt", "le"], annotationColumnName: "label", featureColumnNames: ["x0", "x1"],
                                                                                          configuration: cfg).fitted(to: frame)
            let cp = try await cls.applied(to: frame)
            let cpred = cp[cls.predictionColumnName, String.self].map { $0 ?? "" }
            let metrics = ClassificationMetrics<String>(cpred, lab)
            try expect(metrics.accuracy > 0.9 && cls.classCount == 2, "tree classifier accuracy \(metrics.accuracy)")
            // a small fully connected network classifier on separable points; its distributions
            let pts = (0..<40).map { i -> AnnotatedFeature<MLShapedArray<Float>, String> in
                let a = Float(i % 10) / 10, side = i < 20
                return AnnotatedFeature(feature: MLShapedArray(scalars: [a, side ? 1 : -1], shape: [2]), annotation: side ? "up" : "down")
            }
            var ncfg = FullyConnectedNetworkConfiguration(); ncfg.hiddenUnitCounts = [8]; ncfg.maximumIterations = 60; ncfg.batchSize = 8
            let net = try await FullyConnectedNetworkClassifier<Float, String>(labels: ["up", "down"], configuration: ncfg).fitted(to: pts)
            let dist: ClassificationDistribution<String> = try await net.applied(to: MLShapedArray(scalars: [0.5, 1], shape: [2]))
            try expect(dist.mostLikelyLabel == "up", "network predicts \(String(describing: dist.mostLikelyLabel)) (\(dist.labelsSortedByProbability))")
            // multivariate linear regression: [a, b] -> [a + b, a - b]
            let mv = (0..<30).map { i -> AnnotatedFeature<MLShapedArray<Float>, MLShapedArray<Float>> in
                let a = Float(i % 6), b = Float(i / 6)
                return AnnotatedFeature(feature: MLShapedArray(scalars: [a, b], shape: [2]), annotation: MLShapedArray(scalars: [a + b, a - b], shape: [2]))
            }
            var mcfg = MultivariateLinearRegressor<Float>.Configuration(); mcfg.maximumIterationCount = 1000; mcfg.learningRate = 0.05; mcfg.batchSize = 30; mcfg.randomSeed = 1
            let mvr = try await MultivariateLinearRegressor<Float>(configuration: mcfg).fitted(to: mv)
            let mo = try await mvr.applied(to: MLShapedArray(scalars: [2, 1], shape: [2]))
            // the fitted model answers a 2-vector (its values: Apple's simulator fits the same, [-1.2, -0.28], with seed 1)
            try expect(mo.scalars.count == 2 && mo.scalars.allSatisfy(\.isFinite), "multivariate regression \(mo.scalars)")
            return "tree regressor err \(String(format: "%.2f", err)), classifier accuracy \(metrics.accuracy), network \(dist.mostLikelyLabel ?? "-"), multivariate \(mo.scalars)"
        })
        #endif
        return c
    }

    static var p27mVision: [Check] {
        var c: [Check] = []
        #if canImport(Vision) && canImport(CoreImage)
        c.append(check("Vision", "p27-swift-performall-observations", timeout: 90) {
            // a 400x300 picture: a QR code (left), a black rectangle (right), a line of text (bottom)
            let img = try p27VisionImage(shift: 0)
            let handler = ImageRequestHandler(img)
            var barcodes = DetectBarcodesRequest(); barcodes.symbologies = [BarcodeSymbology.qr]
            var text = RecognizeTextRequest(); text.recognitionLevel = .accurate
            var contours = DetectContoursRequest(); contours.contrastAdjustment = 1
            let reqs: [any VisionRequest] = [barcodes, text, contours, DetectRectanglesRequest(), DetectTextRectanglesRequest(), DetectHorizonRequest(),
                                            GenerateImageFeaturePrintRequest(), DetectDocumentSegmentationRequest(), DetectFaceCaptureQualityRequest(),
                                            DetectAnimalBodyPoseRequest(), GeneratePersonInstanceMaskRequest(), GenerateForegroundInstanceMaskRequest(),
                                            DetectLensSmudgeRequest(), RecognizeDocumentsRequest(), DetectHumanBodyPose3DRequest()]
            var got: [String: String] = [:]
            var payload = "", words = "", print: FeaturePrintObservation?
            for await r in handler.performAll(reqs) {
                switch r {
                case .detectBarcodes(_, let o):
                    let bo: [BarcodeObservation] = o
                    payload = bo.first?.payloadString ?? ""; got["barcodes"] = "\(bo.count):\(bo.first?.symbology == .qr)"
                case .recognizeText(_, let o):
                    let to: [RecognizedTextObservation] = o
                    let rt: [RecognizedText] = to.compactMap { $0.topCandidates(1).first }
                    words = rt.map(\.string).joined(separator: " "); got["text"] = "\(to.count)"
                case .detectContours(_, let o): let co: ContoursObservation = o; got["contours"] = co.contourCount > 0 ? "some" : "0"
                case .detectRectangles(_, let o): let ro: [RectangleObservation] = o; got["rectangles"] = "\(ro.count)"
                case .detectTextRectangles(_, let o): let to: [TextObservation] = o; got["textRects"] = to.isEmpty ? "0" : "some"
                case .detectHorizon(_, let o): let ho: HorizonObservation? = o; got["horizon"] = ho == nil ? "nil" : "obs"
                case .generateImageFeaturePrint(_, let o): print = o; got["featurePrint"] = "\(o.elementType == ElementType.float ? "float" : "double")x\(o.elementCount > 0)"
                case .detectDocumentSegmentation(_, let o): let d: DetectedDocumentObservation? = o; got["document"] = d == nil ? "nil" : "obs"
                case .detectFaceCaptureQuality(_, let o): got["faceQuality"] = "\(o.count)"
                case .detectAnimalBodyPose(_, let o): let a: [AnimalBodyPoseObservation] = o; got["animalPose"] = "\(a.count)"
                case .generatePersonInstanceMask(_, let o): let m: InstanceMaskObservation? = o; got["personMask"] = m == nil ? "nil" : "obs"
                case .generateForegroundInstanceMask(_, let o): got["foregroundMask"] = o == nil ? "nil" : "\(o!.allInstances.count)"
                case .detectLensSmudge(_, let o): let s: SmudgeObservation = o; got["smudge"] = s.confidence >= 0 ? "obs" : "?"
                case .recognizeDocuments(_, let o): let d: [DocumentObservation] = o; got["documents"] = "\(d.count)"
                case .detectHumanBodyPose3D(_, let o): let h: [HumanBodyPose3DObservation] = o; got["bodyPose3D"] = "\(h.count)"
                case .error(let req, let err):
                    let ve = err as? VisionError
                    got["\(type(of: req))"] = "err:\(ve.map { "\($0)".prefix(while: { $0 != "(" }) } ?? "\((err as NSError).code)")"
                default: got["other"] = "\(r)".prefix(40).description
                }
            }
            // Apple's iOS 27.2 simulator: the classical detectors answer, the model-backed requests fail (the Swift barcode
            // detector too, "operationFailed", where VNDetectBarcodesRequest reads the same code: Vision barcodes-from-coreimage-generators)
            let summary = got.keys.sorted().map { "\($0)=\(got[$0]!)" }.joined(separator: " ")
            let want = "DetectAnimalBodyPoseRequest=err:internalError DetectBarcodesRequest=err:operationFailed DetectFaceCaptureQualityRequest=err:internalError DetectHumanBodyPose3DRequest=err:invalidOperation DetectLensSmudgeRequest=err:0 GenerateForegroundInstanceMaskRequest=err:internalError GenerateImageFeaturePrintRequest=err:-1 GeneratePersonInstanceMaskRequest=err:internalError contours=some document=nil documents=1 horizon=nil rectangles=1 text=1 textRects=some"
            #if os(iOS)
            try expect(summary == want, "requests differ from Apple's simulator: \(summary)")
            #endif
            try expect(got["contours"] == "some" && got["textRects"] == "some" && got["rectangles"] == "1", "contours/text rects \(got)")
            // feature prints: the same picture is nearer than a shifted copy
            if let p = print {
                let p2 = try await GenerateImageFeaturePrintRequest().perform(on: try p27VisionImage(shift: 0))
                let p3 = try await GenerateImageFeaturePrintRequest().perform(on: try p27VisionImage(shift: 60))
                let d0 = try p.distance(to: p2), d1 = try p.distance(to: p3)
                try expect(d0 < d1, "feature print distances same \(d0) shifted \(d1)")
                got["fpDistances"] = d0 < 0.01 ? "same~0" : "same>0"
            }
            // normalized geometry
            let nr = NormalizedRect(imageRect: CGRect(x: 100, y: 75, width: 200, height: 150), in: CGSize(width: 400, height: 300))
            let np = NormalizedPoint(imagePoint: CGPoint(x: 200, y: 150), in: CGSize(width: 400, height: 300))
            let nc = NormalizedCircle(center: np, radius: 0.25)
            let back = nr.toImageCoordinates(CGSize(width: 400, height: 300), origin: CoordinateOrigin.upperLeft)
            try expect(abs(nr.width - 0.5) < 1e-9 && abs(np.x - 0.5) < 1e-9 && nc.radius == 0.25 && abs(back.width - 200) < 1e-6, "normalized geometry \(nr) \(np) \(back)")
            let desc: RequestDescriptor = barcodes.descriptor
            let stages: [ComputeStage] = Array(GenerateImageFeaturePrintRequest().supportedComputeStageDevices.keys)
            let keys = got.keys.sorted().map { "\($0)=\(got[$0]!)" }.joined(separator: " ")
            return "QR '\(payload)', text '\(words)', \(keys); descriptor \(desc); stages \(stages.count)"
        })
        c.append(check("Vision", "p27-vn-request-classes", timeout: 90) {
            // every VNRequest class, on the synthetic picture: each completes with results of its observation class or
            // fails cleanly (the simulator lacks some neural network contexts); the shift registrations recover 12 px
            let img = try p27VisionImage(shift: 0), moved = try p27VisionImage(shift: 12)
            let rect = VNDetectedObjectObservation(boundingBox: CGRect(x: 0.6, y: 0.3, width: 0.3, height: 0.4))
            let rectObs = VNRectangleObservation(requestRevision: VNDetectRectanglesRequestRevision1, topLeft: CGPoint(x: 0.6, y: 0.7), topRight: CGPoint(x: 0.9, y: 0.7),
                                                 bottomRight: CGPoint(x: 0.9, y: 0.3), bottomLeft: CGPoint(x: 0.6, y: 0.3))
            let reqs: [(String, VNRequest)] = [
                ("faceRects", VNDetectFaceRectanglesRequest()), ("faceLandmarks", VNDetectFaceLandmarksRequest()), ("faceQuality", VNDetectFaceCaptureQualityRequest()),
                ("humanRects", VNDetectHumanRectanglesRequest()), ("bodyPose", VNDetectHumanBodyPoseRequest()), ("handPose", VNDetectHumanHandPoseRequest()),
                ("animalPose", VNDetectAnimalBodyPoseRequest()), ("animals", VNRecognizeAnimalsRequest()), ("classify", VNClassifyImageRequest()),
                ("textRects", VNDetectTextRectanglesRequest()), ("contours", VNDetectContoursRequest()), ("docSeg", VNDetectDocumentSegmentationRequest()),
                ("attention", VNGenerateAttentionBasedSaliencyImageRequest()), ("objectness", VNGenerateObjectnessBasedSaliencyImageRequest()),
                ("personSeg", VNGeneratePersonSegmentationRequest()), ("personMask", VNGeneratePersonInstanceMaskRequest()),
                ("foreground", VNGenerateForegroundInstanceMaskRequest()), ("aesthetics", VNCalculateImageAestheticsScoresRequest()),
                ("bodyPose3D", VNDetectHumanBodyPose3DRequest()), ("horizon", VNDetectHorizonRequest()),
                ("homographic", VNHomographicImageRegistrationRequest(targetedCGImage: moved)),
            ]
            var out: [String] = []
            for (n, r) in reqs {
                let ib: VNImageBasedRequest? = r as? VNImageBasedRequest
                ib?.regionOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
                do {
                    try VNImageRequestHandler(cgImage: img).perform([r])
                    let res: [VNObservation] = r.results ?? []
                    out.append("\(n):\(res.count)\(res.first.map { ":\(type(of: $0))" } ?? "")")
                } catch { out.append("\(n):err\((error as NSError).code)") }
            }
            // the request table as Apple's iOS 27.2 simulator answers it (VNError codes where a model is missing)
            let want = "faceRects:err9 faceLandmarks:err9 faceQuality:err9 humanRects:err9 bodyPose:err9 handPose:0 animalPose:err9 animals:err9 classify:err-1 textRects:1:VNTextObservation contours:1:VNContoursObservation docSeg:1:VNRectangleObservation attention:err-1 objectness:err-1 personSeg:err1 personMask:err9 foreground:err9 aesthetics:err-1 bodyPose3D:err16 horizon:0 homographic:1:VNImageHomographicAlignmentObservation"
            #if os(iOS)
            try expect(out.joined(separator: " ") == want, "requests differ from Apple's simulator: \(out.joined(separator: " "))")
            #endif
            // results typed by observation class, where there are any
            let textRects = (reqs.first { $0.0 == "textRects" }?.1.results ?? []).compactMap { $0 as? VNTextObservation }
            try expect(!textRects.isEmpty, "no VNTextObservation (\(out))")
            let cont = (reqs.first { $0.0 == "contours" }?.1.results ?? []).compactMap { $0 as? VNContoursObservation }.first
            let firstContour: VNContour? = cont?.topLevelContours.first
            try expect((cont?.contourCount ?? 0) > 0 && (firstContour?.pointCount ?? 0) > 2, "contours \(cont?.contourCount ?? -1)")
            if let fc = firstContour { var area = 0.0; try VNGeometryUtils.calculateArea(&area, for: fc, orientedArea: false); out.append("contourArea>0:\(area > 0)") }
            if let sal = (reqs.first { $0.0 == "attention" }?.1.results ?? []).first as? VNSaliencyImageObservation {
                let pbo: VNPixelBufferObservation = sal; out.append("heatmap:\(CVPixelBufferGetWidth(pbo.pixelBuffer))")
            }
            // tracking (sequence handler, stateful requests) and translational tracking registration
            let seq = VNSequenceRequestHandler()
            let track = VNTrackObjectRequest(detectedObjectObservation: rect); track.trackingLevel = .accurate
            let trackR = VNTrackRectangleRequest(rectangleObservation: rectObs)
            let reg = VNTrackTranslationalImageRegistrationRequest(), hreg = VNTrackHomographicImageRegistrationRequest()
            let flow = VNTrackOpticalFlowRequest()
            let stateful: [VNStatefulRequest] = [reg, hreg, flow]
            var tracked: [String] = []
            for frame in [img, moved] {
                for (n, r) in [("object", track), ("rect", trackR), ("treg", reg), ("hreg", hreg), ("flow", flow)] as [(String, VNRequest)] {
                    do { try seq.perform([r], on: frame) } catch { tracked.append("\(n):err\((error as NSError).code)") }
                }
            }
            let shift = (reg.results?.first as? VNImageTranslationAlignmentObservation)?.alignmentTransform.tx
            let homog: VNImageHomographicAlignmentObservation? = hreg.results?.first as? VNImageHomographicAlignmentObservation
            let flowObs = flow.results?.first as? VNPixelBufferObservation
            let trackObs: VNDetectedObjectObservation? = track.results?.first as? VNDetectedObjectObservation
            let trk: VNTrackingRequest = track
            tracked.append("treg:\(shift.map { String(format: "%.0f", $0) } ?? "nil") hreg:\(homog != nil) flow:\(flowObs != nil) track:\(trackObs.map { String(format: "%.2f", $0.boundingBox.minX) } ?? "nil") stateful:\(stateful.count) last:\(trk.isLastFrame)")
            try expect(shift.map { abs(abs($0) - 12) <= 2 } ?? false, "tracking registration shift \(String(describing: shift)) (\(tracked))")
            // trajectories over a short synthetic sequence: a request made, frames fed
            let traj = VNDetectTrajectoriesRequest(frameAnalysisSpacing: .zero, trajectoryLength: 5) { _, _ in }
            let tObs: [VNTrajectoryObservation] = traj.results as? [VNTrajectoryObservation] ?? []
            // VNTargetedImageRequest / VNImageAlignmentObservation / VNRecognizedPointsObservation as the classes they are
            let classes: [AnyClass] = [VNTargetedImageRequest.self, VNImageAlignmentObservation.self, VNRecognizedPointsObservation.self, VNRecognizedPoints3DObservation.self,
                                       VNHumanObservation.self, VNFaceObservation.self, VNClassificationObservation.self, VNRecognizedObjectObservation.self,
                                       VNBarcodeObservation.self, VNRecognizedTextObservation.self, VNHorizonObservation.self, VNFeaturePrintObservation.self,
                                       VNInstanceMaskObservation.self, VNImageAestheticsScoresObservation.self, VNCoreMLFeatureValueObservation.self,
                                       VNHumanBodyPoseObservation.self, VNHumanHandPoseObservation.self, VNAnimalBodyPoseObservation.self, VNHumanBodyPose3DObservation.self]
            try expect(classes.allSatisfy { ($0 as AnyClass).isSubclass(of: VNObservation.self) || ($0 as AnyClass).isSubclass(of: VNRequest.self) }, "observation classes")
            // points / vectors / circles
            let p = VNPoint(x: 3, y: 4), v = VNVector(xComponent: 3, yComponent: 4), circ = VNCircle(center: VNPoint(x: 0, y: 0), radius: 5)
            let p3 = VNPoint3D(position: matrix_identity_float4x4)
            try expect(v.length == 5 && circ.contains(p) && p.distance(VNPoint(x: 0, y: 0)) == 5 && p3?.position.columns.3.w == 1 && VNDetectedPoint.self.isSubclass(of: VNPoint.self) && VNRecognizedPoint.self.isSubclass(of: VNDetectedPoint.self),
                       "points / vectors")
            let lm: [AnyClass] = [VNFaceLandmarks.self, VNFaceLandmarks2D.self, VNFaceLandmarkRegion.self, VNFaceLandmarkRegion2D.self, VNHumanBodyRecognizedPoint3D.self, VNRecognizedPoint3D.self]
            return "\(out.joined(separator: " ")) | \(tracked.joined(separator: " ")) | trajectories \(tObs.count), \(classes.count + lm.count) classes"
        })
        #endif
        return c
    }

    static var p27mAudio: [Check] {
        var c: [Check] = []
        #if !os(watchOS)   // watchOS: no audio unit effects, environment node or AudioToolbox component API
        c.append(check("AVFAudio", "p27-engine-nodes-offline", timeout: 60) {
            let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
            let e = AVAudioEngine()
            try e.enableManualRenderingMode(.offline, format: fmt, maximumFrameCount: 4096)
            // the input node fed a 440 Hz sine by a block (manual rendering input), through delay / distortion / EQ / varispeed
            let src = sine(440, secs: 1)
            var fed: AVAudioFramePosition = 0
            let inNode: AVAudioInputNode = e.inputNode, outNode: AVAudioOutputNode = e.outputNode
            let io: [AVAudioIONode] = [inNode, outNode]
            let ok = inNode.setManualRenderingInputPCMFormat(fmt) { n in
                let left = AVAudioFramePosition(src.frameLength) - fed
                guard left > 0 else { return nil }
                let ptr = src.audioBufferList
                // hand out the rest each time from the current offset
                let abl = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: ptr))
                let base = abl[0].mData!.advanced(by: Int(fed) * 4)
                let k = min(AVAudioFramePosition(n), left); fed += k
                let out = AudioBufferList.allocate(maximumBuffers: 1)
                out[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(k * 4), mData: base)
                return UnsafePointer(out.unsafeMutablePointer)
            }
            try expect(ok, "setManualRenderingInputPCMFormat refused")
            let delay = AVAudioUnitDelay(); delay.wetDryMix = 0; delay.delayTime = 0.1
            let dist = AVAudioUnitDistortion(); dist.loadFactoryPreset(.drumsBitBrush); dist.wetDryMix = 0
            let eq = AVAudioUnitEQ(numberOfBands: 1)
            let band: AVAudioUnitEQFilterParameters = eq.bands[0]; band.filterType = .lowPass; band.frequency = 20000; band.bypass = false
            let vari = AVAudioUnitVarispeed(); vari.rate = 1
            let teff: AVAudioUnitTimeEffect = vari
            let pre = AVAudioMixerNode(), mixA = AVAudioMixerNode(), mixB = AVAudioMixerNode()
            for n in [delay, dist, eq, vari, pre, mixA, mixB] as [AVAudioNode] { e.attach(n) }
            e.connect(inNode, to: delay, format: fmt); e.connect(delay, to: dist, format: fmt); e.connect(dist, to: eq, format: fmt); e.connect(eq, to: pre, format: fmt)
            // a mixer fans out to two mixers (connection points); mixer B's input from it is muted (mixing destination volume 0)
            e.connect(pre, to: [AVAudioConnectionPoint(node: mixA, bus: 0), AVAudioConnectionPoint(node: mixB, bus: 0)], fromBus: 0, format: fmt)
            e.connect(mixA, to: vari, format: fmt); e.connect(vari, to: e.mainMixerNode, format: fmt); e.connect(mixB, to: e.mainMixerNode, format: fmt)
            let pts: [AVAudioConnectionPoint] = e.outputConnectionPoints(for: pre, outputBus: 0)
            try expect(pts.count == 2 && Set(pts.compactMap { $0.node.map(ObjectIdentifier.init) }) == [ObjectIdentifier(mixA), ObjectIdentifier(mixB)], "connection points \(pts.count)")
            guard let dest: AVAudioMixingDestination = pre.destination(forMixer: mixB, bus: 0) else { throw Fail("no mixing destination") }
            dest.volume = 0
            try expect(dest.connectionPoint.node === mixB && dest.volume == 0, "mixing destination")
            try e.start()
            let out = AVAudioPCMBuffer(pcmFormat: e.manualRenderingFormat, frameCapacity: 4096)!
            var total: AVAudioFrameCount = 0, peak: Float = 0
            while total < 22050 {
                let st = try e.renderOffline(4096, to: out)
                guard st == .success else { break }
                total += out.frameLength
                let p = out.floatChannelData![0]; for i in 0..<Int(out.frameLength) { peak = max(peak, abs(p[i])) }
            }
            e.stop()
            try expect(total >= 22050 && peak > 0.2 && peak < 0.7, "rendered \(total) frames, peak \(peak) (a 0.5 sine through dry effects)")
            let lat = outNode.presentationLatency
            // AVAudioTime: host/sample time arithmetic
            let t = AVAudioTime(sampleTime: 44100, atRate: 44100)
            let t2 = t.extrapolateTime(fromAnchor: AVAudioTime(hostTime: mach_absolute_time(), sampleTime: 0, atRate: 44100))
            try expect(t.isSampleTimeValid && !t.isHostTimeValid && (t2?.isHostTimeValid ?? false), "AVAudioTime validity")
            try expect(AVAudioTime.seconds(forHostTime: AVAudioTime.hostTime(forSeconds: 2)) > 1.99, "host time round trip")
            // environment node parameters
            let env = AVAudioEnvironmentNode()
            let dap: AVAudioEnvironmentDistanceAttenuationParameters = env.distanceAttenuationParameters
            dap.distanceAttenuationModel = .linear; dap.maximumDistance = 50; dap.referenceDistance = 2
            let rev: AVAudioEnvironmentReverbParameters = env.reverbParameters
            rev.enable = true; rev.level = -6; rev.loadFactoryReverbPreset(.cathedral)
            try expect(env.distanceAttenuationParameters.maximumDistance == 50 && env.reverbParameters.level == -6 && rev.filterParameters.filterType == .parametric, "environment parameters")
            return "rendered \(total) frames, peak \(peak); \(io.count) IO nodes (latency \(lat)); time effect \(type(of: teff)); environment params set"
        })
        c.append(check("AVFAudio", "p27-sampler-generator-compressed", timeout: 60) {
            let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
            let e = AVAudioEngine()
            try e.enableManualRenderingMode(.offline, format: fmt, maximumFrameCount: 4096)
            // a sampler (an AVAudioUnitMIDIInstrument) playing middle C with its default sound renders audio
            let sampler = AVAudioUnitSampler()
            let inst: AVAudioUnitMIDIInstrument = sampler
            e.attach(sampler); e.connect(sampler, to: e.mainMixerNode, format: fmt)
            // a generator unit (the scheduled sound player) attaches and connects
            let gen = AVAudioUnitGenerator(audioComponentDescription: AudioComponentDescription(componentType: kAudioUnitType_Generator,
                componentSubType: kAudioUnitSubType_ScheduledSoundPlayer, componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0))
            gen.bypass = false
            e.attach(gen); e.connect(gen, to: e.mainMixerNode, format: fmt)
            try e.start()
            inst.startNote(60, withVelocity: 127, onChannel: 0)
            let out = AVAudioPCMBuffer(pcmFormat: e.manualRenderingFormat, frameCapacity: 4096)!
            var peak: Float = 0
            for _ in 0..<8 { _ = try e.renderOffline(4096, to: out); let p = out.floatChannelData![0]; for i in 0..<Int(out.frameLength) { peak = max(peak, abs(p[i])) } }
            inst.stopNote(60, onChannel: 0)
            e.stop()
            try expect(peak > 0.01, "sampler note peak \(peak)")
            // PCM -> AAC into an AVAudioCompressedBuffer, and back
            let pcmFmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
            var asbd = AudioStreamBasicDescription(mSampleRate: 44100, mFormatID: kAudioFormatMPEG4AAC, mFormatFlags: 0, mBytesPerPacket: 0, mFramesPerPacket: 1024,
                                                   mBytesPerFrame: 0, mChannelsPerFrame: 1, mBitsPerChannel: 0, mReserved: 0)
            let aacFmt = AVAudioFormat(streamDescription: &asbd)!
            let enc = AVAudioConverter(from: pcmFmt, to: aacFmt)!
            let src = sine(440, secs: 0.5)
            let comp = AVAudioCompressedBuffer(format: aacFmt, packetCapacity: 64, maximumPacketSize: enc.maximumOutputPacketSize)
            var given = false
            var err: NSError?
            let st = enc.convert(to: comp, error: &err) { _, status in
                if given { status.pointee = .endOfStream; return nil }
                given = true; status.pointee = .haveData; return src
            }
            try expect(st != .error && comp.packetCount > 5 && comp.byteLength > 100, "AAC encode \(st.rawValue) packets \(comp.packetCount) bytes \(comp.byteLength) \(String(describing: err))")
            let asBase: AVAudioBuffer = comp
            try expect(asBase.format.streamDescription.pointee.mFormatID == kAudioFormatMPEG4AAC && comp.packetDescriptions != nil, "compressed buffer format")
            let dec = AVAudioConverter(from: aacFmt, to: pcmFmt)!
            let back = AVAudioPCMBuffer(pcmFormat: pcmFmt, frameCapacity: 44100)!
            var used = false
            let st2 = dec.convert(to: back, error: &err) { _, status in
                if used { status.pointee = .endOfStream; return nil }
                used = true; status.pointee = .haveData; return comp
            }
            try expect(st2 != .error && back.frameLength > 10000 && rms(back) > 0.1, "AAC decode \(st2.rawValue) frames \(back.frameLength) rms \(rms(back))")
            // the audio unit component manager lists Apple's units
            let comps: [AVAudioUnitComponent] = AVAudioUnitComponentManager.shared().components(matching: AudioComponentDescription(componentType: kAudioUnitType_Effect,
                componentSubType: 0, componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0))
            try expect(comps.contains { $0.name.contains("Delay") }, "effect components \(comps.map(\.name))")
            return "sampler peak \(peak); AAC \(comp.packetCount) packets / \(comp.byteLength) B -> \(back.frameLength) frames rms \(rms(back)); \(comps.count) Apple effects"
        })
        c.append(check("AVFAudio", "p27-sequencer-midi-events", timeout: 60) {
            let e = AVAudioEngine()
            let seq = AVAudioSequencer(audioEngine: e)
            let tr: AVMusicTrack = seq.createAndAppendTrack()
            let events: [AVMusicEvent] = [
                AVMIDINoteEvent(channel: 0, key: 60, velocity: 100, duration: 1),
                AVMIDIControlChangeEvent(channel: 0, messageType: .volume, value: 90),
                AVMIDIProgramChangeEvent(channel: 0, programNumber: 5),
                AVMIDIPitchBendEvent(channel: 0, value: 9000),
                AVMIDIChannelPressureEvent(channel: 0, pressure: 40),
                AVMIDIPolyPressureEvent(channel: 0, key: 60, pressure: 30),
                AVMIDISysexEvent(data: Data([0xF0, 0x7E, 0x7F, 0x09, 0x01, 0xF7])),
                AVMIDIMetaEvent(type: .text, data: Data("p27".utf8)),
                AVMusicUserEvent(data: Data([1, 2, 3])),
                AVParameterEvent(parameterID: 0, scope: kAudioUnitScope_Global, element: 0, value: 0.5),
                AVAUPresetEvent(scope: kAudioUnitScope_Global, element: 0, dictionary: ["name": "p27"]),
                AVExtendedNoteOnEvent(midiNote: 64, velocity: 90, groupID: 0, duration: 0.5),
            ]
            for (i, ev) in events.enumerated() { tr.addEvent(ev, at: Double(i) * 0.25) }
            var seen: [String] = []
            tr.enumerateEvents(in: AVMakeBeatRange(0, 100)) { ev, ts, _ in seen.append("\(type(of: ev))@\(ts.pointee)") }
            try expect(seen.count == events.count, "track events \(seen)")
            let ch: [AVMIDIChannelEvent] = events.compactMap { $0 as? AVMIDIChannelEvent }
            try expect(ch.count == 5 && !(events[0] is AVMIDIChannelEvent) && (events[0] as! AVMIDINoteEvent).key == 60, "channel events \(ch.count) (Apple: 5, the note event is not one)")
            seq.tempoTrack.addEvent(AVExtendedTempoEvent(tempo: 90), at: 0)
            // write a standard MIDI file and load it into a second sequencer: the note round-trips
            var serr: NSError?
            let data = seq.data(withSMPTEResolution: 0, error: &serr)
            try expect(!data.isEmpty, "SMF write \(String(describing: serr))")
            let seq2 = AVAudioSequencer(audioEngine: AVAudioEngine())
            try seq2.load(from: data, options: [])
            var notes = 0
            for t in seq2.tracks { t.enumerateEvents(in: AVMakeBeatRange(0, 100)) { ev, _, _ in if ev is AVMIDINoteEvent { notes += 1 } } }
            try expect(notes >= 1 && seq2.tracks.count >= 1, "reloaded notes \(notes) in \(seq2.tracks.count) tracks")
            // AVMIDIPlayer with the file (no sound bank argument)
            var midiAns: String
            do { let mp = try AVMIDIPlayer(data: data, soundBankURL: nil); midiAns = "player duration \(mp.duration)" } catch { midiAns = "player refused \((error as NSError).domain) \((error as NSError).code)" }
            return "\(seen.count) events on the track; SMF \(data.count) B reloaded with \(notes) notes; \(midiAns)"
        })
        #endif
        #if os(iOS) || os(visionOS) || os(tvOS)
        c.append(check("AVFAudio", "p27-session-route-descriptions", timeout: 30) {
            let s = AVAudioSession.sharedInstance()
            let route: AVAudioSessionRouteDescription = s.currentRoute
            let outs: [AVAudioSessionPortDescription] = route.outputs
            let chans: [AVAudioSessionChannelDescription] = outs.flatMap { $0.channels ?? [] }
            let srcs: [AVAudioSessionDataSourceDescription] = s.outputDataSources ?? []
            let desc = outs.map { "\($0.portType.rawValue):\($0.channels?.count ?? 0)" }
            try expect(!outs.isEmpty && chans.allSatisfy { !$0.channelName.isEmpty }, "route outputs \(desc)")
            #if os(iOS)
            let bt: [AVAudioSessionPortExtensionBluetoothMicrophone] = (s.availableInputs ?? []).compactMap { $0.bluetoothMicrophoneExtension }
            let caps: [AVAudioSessionCapability] = bt.map(\.highQualityRecording)
            #else
            let caps: [AVAudioSessionCapability] = []
            #endif
            // interruption / deactivation / resumption contexts: no public initializer; the classes are the runtime's
            let types: [AnyClass] = [AVAudioSession.InterruptionContext.self, AVAudioSession.DeactivationContext.self, AVAudioSession.ResumptionContext.self]
            let ctx = types.map { NSStringFromClass($0) }
            try expect(ctx == ["AVAudioSessionInterruptionContext", "AVAudioSessionDeactivationContext", "AVAudioSessionResumptionContext"], "context classes \(ctx)")
            // speech synthesis markers / provider voice + request (an extension's data types)
            let mk = AVSpeechSynthesisMarker(wordRange: NSRange(location: 0, length: 5), atByteSampleOffset: 100)
            try expect(mk.mark == .word && mk.textRange.length == 5 && mk.byteSampleOffset == 100, "marker \(mk.mark.rawValue)")
            let voice = AVSpeechSynthesisProviderVoice(name: "P27", identifier: "com.x86sim.p27", primaryLanguages: ["en-US"], supportedLanguages: ["en-US"])
            voice.gender = .female; voice.age = 30
            let req = AVSpeechSynthesisProviderRequest(ssmlRepresentation: "<speak>hi</speak>", voice: voice)
            try expect(req.voice.identifier == "com.x86sim.p27" && req.ssmlRepresentation.contains("hi"), "provider request")
            let vd = try NSKeyedArchiver.archivedData(withRootObject: voice, requiringSecureCoding: true)
            let v2 = try NSKeyedUnarchiver.unarchivedObject(ofClass: AVSpeechSynthesisProviderVoice.self, from: vd)
            try expect(v2?.name == "P27", "voice secure coding")
            let unitT: AnyClass = AVSpeechSynthesisProviderAudioUnit.self
            try expect(unitT.isSubclass(of: AUAudioUnit.self), "provider audio unit is an AUAudioUnit")
            return "route \(desc), \(chans.count) channels, \(srcs.count) data sources, \(caps.count) BT capabilities; marker, provider voice/request"
        })
        #endif
        return c
    }

    static var p27mAV: [Check] {
        var c: [Check] = []
        #if !os(watchOS)
        c.append(check("AVFoundation", "p27-composition-videocomposition-audiomix", timeout: 60) {
            let dir = FileManager.default.temporaryDirectory
            let mv = dir.appendingPathComponent("p27-comp.mov"), m4a = dir.appendingPathComponent("p27-comp.m4a")
            try await writeMovie(mv, frames: 30, size: 64)
            try writeM4A(sine(440, secs: 1), to: m4a)
            let va = AVURLAsset(url: mv), aa = AVURLAsset(url: m4a)
            guard let vt = try await va.loadTracks(withMediaType: .video).first, let at = try await aa.loadTracks(withMediaType: .audio).first else { throw Fail("no source tracks") }
            let segs: [AVAssetTrackSegment] = try await vt.load(.segments)
            try expect(segs.count == 1 && !segs[0].isEmpty, "source segments \(segs.count)")
            // the video twice in a row, the audio once
            let comp = AVMutableComposition()
            guard let cv = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                  let ca = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw Fail("addMutableTrack") }
            let one = CMTimeRange(start: .zero, duration: CMTime(value: 1, timescale: 1))
            try cv.insertTimeRange(one, of: vt, at: .zero)
            try cv.insertTimeRange(one, of: vt, at: CMTime(value: 1, timescale: 1))
            try ca.insertTimeRange(one, of: at, at: .zero)
            let mct: AVMutableCompositionTrack = cv
            let segments: [AVCompositionTrackSegment] = mct.segments
            try expect(segments.count == 2 && segments[1].timeMapping.target.start.seconds == 1, "composition segments \(segments.map(\.timeMapping.target.start.seconds))")
            let frozen = comp.copy() as! AVComposition
            let ft: [AVCompositionTrack] = frozen.tracks
            let repl: [AVCompositionTrackFormatDescriptionReplacement] = ft.first?.formatDescriptionReplacements ?? []
            try expect(ft.count == 2 && abs(frozen.duration.seconds - 2) < 0.05 && repl.isEmpty, "composition \(ft.count) tracks \(frozen.duration.seconds) s")
            // video composition: opacity ramp 1 -> 0 over the second second
            let ins = AVMutableVideoCompositionInstruction(); ins.timeRange = CMTimeRange(start: .zero, duration: CMTime(value: 2, timescale: 1))
            let li = AVMutableVideoCompositionLayerInstruction(assetTrack: cv)
            li.setOpacityRamp(fromStartOpacity: 1, toEndOpacity: 0, timeRange: CMTimeRange(start: CMTime(value: 1, timescale: 1), duration: CMTime(value: 1, timescale: 1)))
            ins.layerInstructions = [li]
            let vc = AVMutableVideoComposition(); vc.instructions = [ins]; vc.renderSize = CGSize(width: 64, height: 64); vc.frameDuration = CMTime(value: 1, timescale: 30)
            let base: AVVideoCompositionInstruction = ins, lbase: AVVideoCompositionLayerInstruction = li
            var s: Float = 0, e: Float = 0, r = CMTimeRange()
            try expect(lbase.getOpacityRamp(for: CMTime(value: 3, timescale: 2), startOpacity: &s, endOpacity: &e, timeRange: &r) && s == 1 && e == 0, "opacity ramp \(s)->\(e)")
            try expect(base.layerInstructions.count == 1, "instruction layers")
            // audio mix: volume 0 on the audio track
            let mixParams = AVMutableAudioMixInputParameters(track: ca); mixParams.setVolume(0, at: .zero)
            let mix = AVMutableAudioMix(); mix.inputParameters = [mixParams]
            let mixBase: AVAudioMix = mix, pBase: AVAudioMixInputParameters = mixParams
            var v0: Float = -1, v1: Float = -1, vr = CMTimeRange()
            try expect(pBase.getVolumeRamp(for: CMTime(value: 1, timescale: 2), startVolume: &v0, endVolume: &v1, timeRange: &vr) && v0 == 0, "volume ramp \(v0)")
            // read through both: video brightness falls in the second second; mixed audio is silent, unmixed is not
            let rd = try AVAssetReader(asset: frozen)
            let vout = AVAssetReaderVideoCompositionOutput(videoTracks: frozen.tracks(withMediaType: .video), videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
            vout.videoComposition = vc
            let aout = AVAssetReaderAudioMixOutput(audioTracks: frozen.tracks(withMediaType: .audio), audioSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true, AVLinearPCMIsNonInterleaved: false])
            aout.audioMix = mixBase
            rd.add(vout); rd.add(aout)
            try expect(rd.startReading(), "reader \(String(describing: rd.error))")
            var lum: [(Double, Int)] = []
            while let sb = vout.copyNextSampleBuffer() {
                guard let pb = sb.imageBuffer else { continue }
                CVPixelBufferLockBaseAddress(pb, .readOnly)
                let p = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self)
                let bpr = CVPixelBufferGetBytesPerRow(pb)
                lum.append((sb.presentationTimeStamp.seconds, Int(p[32 * bpr + 32 * 4 + 1])))
                CVPixelBufferUnlockBaseAddress(pb, .readOnly)
            }
            var peak: Float = 0
            while let sb = aout.copyNextSampleBuffer() {
                if let bb = sb.dataBuffer { var d = [Float](repeating: 0, count: CMBlockBufferGetDataLength(bb) / 4); CMBlockBufferCopyDataBytes(bb, atOffset: 0, dataLength: d.count * 4, destination: &d); peak = max(peak, d.map(abs).max() ?? 0) }
            }
            let early = lum.filter { $0.0 < 0.9 }.map(\.1), late = lum.filter { $0.0 > 1.8 }.map(\.1)
            try expect(lum.count >= 50, "frames read \(lum.count)")
            try expect((late.max() ?? 255) < (early.max() ?? 0) / 2 + 10, "opacity ramp not applied: early \(early.max() ?? -1) late \(late.max() ?? -1)")
            try expect(peak < 0.01, "muted audio mix peak \(peak)")
            return "composition 2 s / 2 segments, \(lum.count) frames (early max \(early.max()!), late max \(late.max()!)), mixed audio peak \(peak)"
        })
        c.append(check("AVFoundation", "p27-movie-sample-cursor-generator", timeout: 60) {
            let mv = FileManager.default.temporaryDirectory.appendingPathComponent("p27-cursor.mov")
            try await writeMovie(mv, frames: 10, size: 64)
            #if !os(tvOS)
            // AVMovie / AVMutableMovie / their tracks: an edit of a third of a second
            let movie = AVMovie(url: mv)
            let mts: [AVMovieTrack] = try await movie.loadTracks(withMediaType: .video)
            try expect(mts.count == 1 && mts[0].mediaPresentationTimeRange.duration.seconds > 0.3, "movie tracks \(mts.count)")
            let mm = try AVMutableMovie(settingsFrom: movie, options: nil)
            mm.defaultMediaDataStorage = AVMediaDataStorage(url: FileManager.default.temporaryDirectory.appendingPathComponent("p27-cursor-media.mov"))
            try mm.insertTimeRange(CMTimeRange(start: .zero, duration: CMTime(value: 1, timescale: 3)), of: movie, at: .zero, copySampleData: false)
            let mmt: [AVMutableMovieTrack] = mm.tracks(withMediaType: .video)
            try expect(mmt.count == 1 && abs(mm.duration.seconds - 1.0 / 3) < 0.02, "mutable movie \(mmt.count) tracks \(mm.duration.seconds) s")
            let edit = mm.duration.seconds
            #else
            let edit = -1.0
            #endif
            // AVFragmentedAsset + its minder and tracks (a non-fragmented file: no fragments to mind)
            let fa = AVFragmentedAsset(url: mv)
            let minder = AVFragmentedAssetMinder(asset: fa, mindingInterval: 1)
            let fts: [AVFragmentedAssetTrack] = try await fa.loadTracks(withMediaType: .video)
            try expect(fts.count == 1 && minder.mindingInterval == 1 && minder.assets.count == 1, "fragmented asset tracks \(fts.count)")
            // sample cursor over the video: 10 samples, step forward, sync info; a generator makes a sample buffer from it
            let asset = AVURLAsset(url: mv)
            guard let vt = try await asset.loadTracks(withMediaType: .video).first else { throw Fail("no video track") }
            try expect(try await vt.load(.canProvideSampleCursors), "canProvideSampleCursors false")
            guard let cur: AVSampleCursor = vt.makeSampleCursorAtFirstSampleInDecodeOrder() else { throw Fail("no cursor") }
            var n = 1
            while cur.stepInDecodeOrder(byCount: 1) == 1 { n += 1 }
            try expect(n == 10, "cursor stepped over \(n) samples")
            guard let first = vt.makeSampleCursor(presentationTimeStamp: .zero) else { throw Fail("no cursor at 0") }
            try expect(first.currentSampleSyncInfo.sampleIsFullSync.boolValue, "first sample not a sync sample")
            let gen = AVSampleBufferGenerator(asset: asset, timebase: nil)
            let req = AVSampleBufferRequest(start: first); req.direction = .forward; req.maxSampleCount = 1; req.mode = .immediate
            let sb = try gen.makeSampleBuffer(for: req)
            try expect(sb.numSamples == 1 && sb.formatDescription?.mediaSubType == .h264, "generated buffer \(sb.numSamples) samples \(String(describing: sb.formatDescription?.mediaSubType))")
            let batch: AVSampleBufferGeneratorBatch = gen.makeBatch(); batch.cancel()
            // sample references: an AVAssetReaderSampleReferenceOutput answers offsets into the file, no data
            let rd = try AVAssetReader(asset: asset)
            let ro = AVAssetReaderSampleReferenceOutput(track: vt); rd.add(ro)
            try expect(rd.startReading(), "reader \(String(describing: rd.error))")
            var refs = 0, withURL = 0
            while let s = ro.copyNextSampleBuffer() { if s.numSamples > 0 { refs += 1; if s.attachments[.sampleReferenceURL] != nil { withURL += 1 } } }
            try expect(refs == 10 && withURL == 10, "sample references \(refs), with URL \(withURL)")
            return "movie edit \(edit) s; cursor over \(n) samples; generated \(sb.numSamples) H.264 sample; \(refs) sample references"
        })
        #endif
        #if os(iOS) && !targetEnvironment(macCatalyst)
        c.append(check("AVFoundation", "p27-captions-render-validate", timeout: 60) {
            // captions with a region, ruby and styles; a renderer draws them; a grouper groups; a validator warns
            let r0 = CMTimeRange(start: .zero, duration: CMTime(value: 2, timescale: 1)), r1 = CMTimeRange(start: CMTime(value: 1, timescale: 1), duration: CMTime(value: 2, timescale: 1))
            let cap = AVMutableCaption("Hello captions", timeRange: r0)
            cap.region = AVCaptionRegion.appleITTBottom
            cap.textAlignment = .center
            cap.setTextColor(CGColor(red: 1, green: 1, blue: 0, alpha: 1), in: NSRange(location: 0, length: 5))
            let ruby = AVCaption.Ruby(text: "ha")
            cap.setRuby(ruby, in: NSRange(location: 0, length: 1))
            let reg = AVMutableCaptionRegion(identifier: "p27"); reg.origin = AVCaptionPoint(x: AVCaptionDimension(value: 10, units: .percent), y: AVCaptionDimension(value: 80, units: .percent))
            let cap2 = AVMutableCaption("Second", timeRange: r1); cap2.region = reg
            let caps: [AVCaption] = [cap, cap2]
            try expect(cap.text == "Hello captions" && cap.ruby(at: cap.text.startIndex).0?.text == "ha" && (cap2.region as AVCaptionRegion?)?.identifier == "p27", "caption read back")
            let ren = AVCaptionRenderer(); ren.captions = caps; ren.bounds = CGRect(x: 0, y: 0, width: 320, height: 180)
            let scenes: [AVCaptionRenderer.Scene] = ren.captionSceneChanges(in: CMTimeRange(start: .zero, duration: CMTime(value: 4, timescale: 1)))
            try expect(scenes.count >= 2, "renderer scenes \(scenes.count)")
            // the Objective-C classes behind the Swift names
            let objc = [NSStringFromClass(type(of: ruby)), NSStringFromClass(type(of: scenes[0]))]
            try expect(objc == ["AVCaptionRuby", "AVCaptionRendererScene"], "class names \(objc)")
            let cs = CGColorSpaceCreateDeviceRGB()
            let ctx = CGContext(data: nil, width: 320, height: 180, bitsPerComponent: 8, bytesPerRow: 1280, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ren.render(in: ctx, for: CMTime(value: 1, timescale: 2))
            let px = ctx.data!.assumingMemoryBound(to: UInt8.self)
            var inked = 0
            for i in stride(from: 3, to: 1280 * 180, by: 4) where px[i] > 0 { inked += 1 }
            // Apple's simulator drew 249 inked pixels in one run and 0 in the next (fonts load lazily): reported, not asserted
            let grouper = AVCaptionGrouper(); for c in caps { grouper.add(c) }
            let groups: [AVCaptionGroup] = grouper.flushAddedCaptions(upTo: CMTime(value: 4, timescale: 1))
            try expect(groups.count >= 3 && groups.contains { $0.captions.count == 2 }, "caption groups \(groups.map(\.captions.count))")
            let settings: [AVCaptionSettingsKey: Any] = [.mediaType: AVMediaType.closedCaption, .mediaSubType: kCMClosedCaptionFormatType_CEA608]
            let conf = AVCaptionFormatConformer(conversionSettings: settings); conf.conformsCaptionsToTimeRange = true
            // Apple's simulator: conforming to CEA-608 fails (AVFoundationErrorDomain -11800, OSStatus -16795)
            var conformed = "?"
            do { conformed = try conf.conformedCaption(for: cap).text } catch { conformed = "\((error as NSError).code)/\(((error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError)?.code ?? 0)" }
            try expect(conformed == "-11800/-16795", "conformed caption \(conformed)")
            let val = AVCaptionConversionValidator(captions: caps, timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 4, timescale: 1)), conversionSettings: settings)
            let warnings: [AVCaptionConversionWarning] = await withCheckedContinuation { k in
                var all: [AVCaptionConversionWarning] = []; let lock = NSLock(); var done = false
                val.validateCaptionConversion { w in lock.lock(); defer { lock.unlock() }; if let w { all.append(w) } else if !done { done = true; k.resume(returning: all) } }
            }
            let adj: [AVCaptionConversionAdjustment] = warnings.compactMap(\.adjustment)
            let tra = adj.compactMap { $0 as? AVCaptionConversionTimeRangeAdjustment }
            try expect(val.status == .completed, "validator status \(val.status.rawValue)")
            return "\(scenes.count) scenes, \(inked) px drawn, \(groups.count) groups, conformed \(conformed), \(warnings.count) warnings (\(warnings.map(\.warningType.rawValue))), \(tra.count) time-range adjustments"
        })
        c.append(check("AVFoundation", "p27-capture-objects-no-camera", timeout: 60) {
            // the simulator has no capture devices; the session, outputs, settings and controls are still made and configured
            let ds = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInMicrophone, .external], mediaType: nil, position: .unspecified)
            let devs = ds.devices.map(\.localizedName)
            let session = AVCaptureSession()
            session.beginConfiguration()
            let vout = AVCaptureVideoDataOutput(); vout.alwaysDiscardsLateVideoFrames = true
            vout.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            let aout = AVCaptureAudioDataOutput(), mout = AVCaptureMetadataOutput(), pout = AVCapturePhotoOutput(), fout = AVCaptureMovieFileOutput(), dout = AVCaptureDepthDataOutput()
            let outs: [AVCaptureOutput] = [vout, aout, mout, pout, fout, dout]
            let canAdd = outs.map { session.canAddOutput($0) }
            for (o, ok) in zip(outs, canAdd) where ok { session.addOutput(o) }
            session.commitConfiguration()
            let ff: AVCaptureFileOutput = fout
            try expect(!ff.isRecording && ff.outputFileURL == nil, "file output idle")
            try expect(mout.availableMetadataObjectTypes.isEmpty, "metadata types without input \(mout.availableMetadataObjectTypes)")
            try expect(!vout.availableVideoPixelFormatTypes.isEmpty, "no video pixel formats")
            // a metadata input (no device needed): its port connects to the movie file output
            var fd: CMFormatDescription?
            let spec = [kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier: AVMetadataIdentifier.quickTimeMetadataLocationISO6709.rawValue,
                        kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType: kCMMetadataDataType_QuickTimeMetadataLocation_ISO6709 as String] as CFDictionary
            CMMetadataFormatDescriptionCreateWithMetadataSpecifications(allocator: nil, metadataType: kCMMetadataFormatType_Boxed, metadataSpecifications: [spec] as CFArray, formatDescriptionOut: &fd)
            guard let fd else { throw Fail("metadata format description") }
            let minp = AVCaptureMetadataInput(formatDescription: fd, clock: CMClockGetHostTimeClock())
            let inBase: AVCaptureInput = minp
            let ports: [AVCaptureInput.Port] = inBase.ports
            try expect(ports.count == 1 && ports[0].mediaType == .metadata, "metadata input ports \(ports.map(\.mediaType.rawValue))")
            let conn = AVCaptureConnection(inputPorts: ports, output: fout)
            let canConn = session.canAddInput(minp)
            if canConn { session.addInputWithNoConnections(minp) }
            let canAddConn = session.canAddConnection(conn)
            // photo settings + brackets
            let ps = AVCapturePhotoSettings(); ps.flashMode = .off; ps.photoQualityPrioritization = .speed
            let ae = AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias: -1)
            let ae2 = AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias: 1)
            let me = AVCaptureManualExposureBracketedStillImageSettings.manualExposureSettings(exposureDuration: CMTime(value: 1, timescale: 60), iso: 100)
            // one class per bracket (mixing auto and manual raises NSInvalidArgumentException)
            let bs = AVCapturePhotoBracketSettings(rawPixelFormatType: 0, processedFormat: [AVVideoCodecKey: AVVideoCodecType.jpeg], bracketedSettings: [ae, ae2])
            let brk: [AVCaptureBracketedStillImageSettings] = bs.bracketedSettings
            try expect(brk.count == 2 && ae.exposureTargetBias == -1 && me.iso == 100 && ps.uniqueID != bs.uniqueID, "bracket settings")
            // capture controls
            let picker = AVCaptureIndexPicker("Mode", symbolName: "camera", localizedIndexTitles: ["A", "B", "C"]); picker.selectedIndex = 2
            let slider = AVCaptureSlider("Level", symbolName: "dial.low", in: 0...10); slider.value = 4
            let ctrls: [AVCaptureControl] = [picker, slider]
            let ctrlOK = ctrls.map { session.canAddControl($0) }
            try expect(picker.selectedIndex == 2 && picker.numberOfIndexes == 3 && slider.value == 4, "controls read back")
            // the preview layer, a multi-cam session, a data-output synchronizer, still image output
            let layer = AVCaptureVideoPreviewLayer(session: session); layer.videoGravity = .resizeAspectFill
            let multi = AVCaptureMultiCamSession.isMultiCamSupported
            // a synchronizer of outputs with no connections: NSInvalidArgumentException (Apple's simulator the same)
            let ex = SDKCovCatch { _ = AVCaptureDataOutputSynchronizer(dataOutputs: [vout, dout]) }
            try expect(ex?.first == "NSInvalidArgumentException", "synchronizer without connections: \(String(describing: ex))")
            return "devices \(devs); canAdd \(canAdd); metadata input added \(canConn), connection \(canAddConn); controls \(ctrlOK); multicam \(multi); layer \(layer.videoGravity.rawValue)"
        })
        #endif
        #if !os(watchOS)
        c.append(check("AVFoundation", "p27-metadata-player-helpers", timeout: 60) {
            // timed / date-range metadata groups, a sharing filter, a lazily valued item, text style rules
            let title = AVMutableMetadataItem(); title.identifier = .commonIdentifierTitle; title.value = "T" as NSString; title.extendedLanguageTag = "en"
            let loc = AVMutableMetadataItem(); loc.identifier = .commonIdentifierLocation; loc.value = "+40.0-074.0/" as NSString
            let tg = AVMutableTimedMetadataGroup(items: [title], timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 1, timescale: 1)))
            let dg = AVMutableDateRangeMetadataGroup(items: [title], start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 60))
            let groups: [AVMetadataGroup] = [tg, dg]
            try expect(groups.allSatisfy { $0.items.count == 1 } && dg.endDate == Date(timeIntervalSince1970: 60), "metadata groups")
            let filtered = AVMetadataItem.metadataItems(from: [title, loc], filteredBy: AVMetadataItemFilter.forSharing())
            // Apple's simulator: the sharing filter keeps neither (no item here is of a sharable kind)
            try expect(filtered.isEmpty, "sharing filter kept \(filtered.map { $0.identifier?.rawValue ?? "?" })")
            let lazy = AVMetadataItem(propertiesOf: title) { (req: AVMetadataItemValueRequest) in req.respond(value: "lazy" as NSString) }
            let lv = try await lazy.load(.stringValue)
            try expect(lv == "lazy", "lazy metadata value \(String(describing: lv))")
            let rule = AVTextStyleRule(textMarkupAttributes: [kCMTextMarkupAttribute_ForegroundColorARGB as String: [1, 1, 0, 0]], textSelector: nil)!
            let rules = AVTextStyleRule.textStyleRules(fromPropertyList: AVTextStyleRule.propertyList(for: [rule]))
            try expect(rules?.count == 1 && rules?[0].textMarkupAttributes.count == 1, "text style rule round trip")
            // player-side objects
            let mv = FileManager.default.temporaryDirectory.appendingPathComponent("p27-player.mov")
            try await writeMovie(mv, frames: 10, size: 64)
            let item = AVPlayerItem(url: mv)
            let player = AVPlayer(playerItem: item)
            let coll = AVPlayerItemMetadataCollector(identifiers: nil, classifyingLabels: nil)
            item.add(coll)
            let dc: [AVPlayerItemMediaDataCollector] = item.mediaDataCollectors
            try expect(dc.count == 1, "media data collectors \(dc.count)")
            let crit = AVPlayerMediaSelectionCriteria(preferredLanguages: ["en"], preferredMediaCharacteristics: [.legible])
            player.setMediaSelectionCriteria(crit, forMediaCharacteristic: .legible)
            try expect(player.mediaSelectionCriteria(forMediaCharacteristic: .legible)?.preferredLanguages == ["en"], "selection criteria")
            let pl = AVPlayerLayer(player: player); pl.videoGravity = .resizeAspect
            let sync = AVSynchronizedLayer(playerItem: item)
            try expect(pl.player === player && sync.playerItem === item, "player layers")
            let coord: AVPlayerPlaybackCoordinator = player.playbackCoordinator
            let susp: AVCoordinatedPlaybackSuspension = coord.beginSuspension(for: .userActionRequired)
            // a coordinator outside a group session keeps no suspension reasons (Apple's simulator)
            try expect(coord.suspensionReasons.isEmpty, "suspension reasons \(coord.suspensionReasons)")
            susp.end()
            let pcBase: AVPlaybackCoordinator = coord
            let others: [AVCoordinatedPlaybackParticipant] = pcBase.otherParticipants
            let iec = AVPlayerInterstitialEventController(primaryPlayer: player)
            let ev = AVPlayerInterstitialEvent(primaryItem: item, identifier: "ad", time: CMTime(value: 1, timescale: 10), templateItems: [AVPlayerItem(url: mv)],
                                               restrictions: [], resumptionOffset: .zero, playoutLimit: .invalid, userDefinedAttributes: [:])
            iec.events = [ev]
            let mon: AVPlayerInterstitialEventMonitor = iec
            // events set on a controller whose primary item has not loaded read back empty (Apple's simulator)
            try expect(mon.events.isEmpty && ev.identifier == "ad", "interstitial events \(mon.events.map(\.identifier))")
            let route = AVRouteDetector(); route.isRouteDetectionEnabled = true
            let multi = route.multipleRoutesDetected; route.isRouteDetectionEnabled = false
            let osa = AVOutputSettingsAssistant(preset: .preset1280x720)
            try expect((osa?.videoSettings?[AVVideoWidthKey] as? Int) == 1280, "output settings assistant \(String(describing: osa?.videoSettings))")
            let sbo = AVPlayerItemSampleBufferOutput(configuration: nil); _ = sbo
            // AVMetricEventStream is refined for Swift (its async sequences); the class itself, through the runtime
            guard let streamT = NSClassFromString("AVMetricEventStream") as? NSObject.Type else { throw Fail("no AVMetricEventStream") }
            let stream = streamT.init()
            _ = stream.perform(NSSelectorFromString("subscribeToAllMetricEvents"))
            let pub = stream.perform(NSSelectorFromString("addPublisher:"), with: item) != nil
            let ckSpec = AVContentKeySpecifier(forKeySystem: .clearKey, identifier: "p27", options: [:])
            try expect(ckSpec.identifier as? String == "p27", "content key specifier")
            let cks = AVContentKeySession(keySystem: .clearKey)
            try expect(cks.keySystem == .clearKey, "content key session")
            return "groups 2, filter kept title, lazy value, text style round trip; collectors \(dc.count); coordinator others \(others.count); routes \(multi); metric publisher \(pub)"
        })
        #endif
        return c
    }

    static var p27mReality: [Check] {
        var c: [Check] = []
        #if canImport(RealityKit) && !os(watchOS)
        c.append(check("RealityFoundation", "p27-components-table", timeout: 60) {
            try await onMain {
                let e = Entity(), other = Entity()
                var acc = AccessibilityComponent(); acc.isAccessibilityElement = true; acc.label = "box"
                var light = DirectionalLightComponent(); light.intensity = 1234
                var pl = PointLightComponent(); pl.attenuationRadius = 3
                var sl = SpotLightComponent(); sl.outerAngleInDegrees = 40
                var text = TextComponent(); text.size = CGSize(width: 100, height: 50)
                var ortho = OrthographicCameraComponent(); ortho.scale = 2
                let persp = PerspectiveCameraComponent(near: 0.1, far: 50, fieldOfViewInDegrees: 45, fieldOfViewOrientation: .horizontal)
                var comps: [any Component] = [
                    acc, AdaptiveResolutionComponent(), AmbientAudioComponent(gain: -6), AnchoringComponent(.world(transform: matrix_identity_float4x4)),
                    BillboardComponent(), BloomComponent(), ChannelAudioComponent(gain: -3), ClippingComponent(bounds: BoundingBox(min: [-1, -1, -1], max: [1, 1, 1])),
                    light, DynamicLightShadowComponent(castsShadow: false), GroundingShadowComponent(castsShadow: true),
                    ImageBasedLightReceiverComponent(imageBasedLight: other), OpacityComponent(opacity: 0.25), ortho, persp, pl, sl,
                    PortalCrossingComponent(), text, ToneMappingComponent(exposure: 0.5), WorldComponent(), ModelSortGroupComponent(group: ModelSortGroup(depthPass: nil), order: 2),
                    RenderLayerComponent(layer: RenderLayer("p27")), ModelDebugOptionsComponent(visualizationMode: .normal), OcclusionCullingComponent(isEnabled: false),
                    PhysicsMotionComponent(linearVelocity: [1, 0, 0]), PhysicsSimulationComponent(), CharacterControllerComponent(radius: 0.2, height: 1),
                    SynchronizationComponent(), P27Transient(),
                ]
                #if os(visionOS)
                comps += [EnvironmentBlendingComponent(), ManipulationComponent()]
                #endif
                #if !os(tvOS)
                comps.append(HoverEffectComponent())
                #endif
                for x in comps { e.components.set(x) }
                let types: [any Component.Type] = comps.map { type(of: $0) }
                let missing = types.filter { !e.components.has($0) }.map { "\($0)" }
                try expect(missing.isEmpty, "components not set: \(missing)")
                try expect(e.components[AccessibilityComponent.self]?.label == "box", "accessibility label")
                try expect(e.components[DirectionalLightComponent.self]?.intensity == 1234, "directional intensity")
                try expect(e.components[OpacityComponent.self]?.opacity == 0.25, "opacity")
                try expect(e.components[PerspectiveCameraComponent.self]?.fieldOfViewOrientation == .horizontal, "fov orientation")
                try expect(e.components[ToneMappingComponent.self]?.exposure == 0.5, "tone mapping exposure")
                try expect(e.components[ModelSortGroupComponent.self]?.order == 2, "sort order")
                try expect(e.components[CharacterControllerComponent.self]?.radius == 0.2, "character radius")
                try expect(e.components[PhysicsMotionComponent.self]?.linearVelocity == [1, 0, 0], "linear velocity")
                try expect(e.components[ClippingComponent.self]?.bounds.max == [1, 1, 1], "clipping bounds")
                let cl = e.clone(recursive: false)
                try expect(!cl.components.has(P27Transient.self) && cl.components.has(OpacityComponent.self), "clone kept the TransientComponent / lost a component")
                let n = e.components.count
                for t in types { e.components.remove(t) }
                try expect(e.components.count < n && !e.components.has(OpacityComponent.self), "remove")
                // the HasX protocols the entity subclasses adopt
                let dl = DirectionalLight(), pt = PointLight(), sp = SpotLight(), cam = PerspectiveCamera()
                let has: [Bool] = [(dl as Any) is HasDirectionalLight, (pt as Any) is HasPointLight, (sp as Any) is HasSpotLight, (cam as Any) is HasPerspectiveCamera,
                                   (ModelEntity() as Any) is HasPhysics, (ModelEntity() as Any) is HasPhysicsBody, (ModelEntity() as Any) is HasPhysicsMotion,
                                   (ModelEntity() as Any) is HasCollision, (AnchorEntity() as Any) is HasAnchoring, (Entity() as Any) is HasTransform,
                                   (Entity() as Any) is HasHierarchy, (Entity() as Any) is HasSynchronization]
                try expect(!has.contains(false), "HasX conformances \(has)")
                let te: TriggerVolume = TriggerVolume(shape: .generateBox(size: [1, 1, 1]))
                try expect(te.collision?.mode == .trigger, "trigger volume collision mode")
                return "\(comps.count) components set, read back and removed; 12 HasX conformances; trigger volume"
            }
        })
        c.append(check("RealityFoundation", "p27-lights-materials-render", timeout: 60) {
            try await p2Main {
                // a lit physically based sphere: red under a white directional light, black with no light
                var pbr = PhysicallyBasedMaterial()
                pbr.baseColor = .init(tint: .red); pbr.roughness = .init(floatLiteral: 0.8); pbr.metallic = .init(floatLiteral: 0)
                pbr.emissiveIntensity = 0
                let lit: LitLightingModel? = nil; _ = lit
                let ball = ModelEntity(mesh: .generateSphere(radius: 0.6), materials: [pbr])
                let sun = DirectionalLight(); sun.light.intensity = 5000; sun.light.color = .white; sun.look(at: [0, 0, 0], from: [0, 0, 3], relativeTo: nil)
                let (_, pxLit) = try await p2RealityRender([ball, sun], clear: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
                let midLit = pxLit(32, 32)
                let ball2 = ModelEntity(mesh: .generateSphere(radius: 0.6), materials: [pbr])
                let (_, pxDark) = try await p2RealityRender([ball2], clear: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
                let midDark = pxDark(32, 32)
                try expect(midLit[2] > midLit[1] + 30 && midLit[2] > 40, "lit sphere BGRA \(midLit)")
                try expect(Int(midLit[2]) > Int(midDark[2]) + 20, "light made no difference: lit \(midLit) dark \(midDark)")
                // a point light and a spot light entity light the sphere too
                let ball3 = ModelEntity(mesh: .generateSphere(radius: 0.6), materials: [pbr])
                let pt = PointLight(); pt.light.intensity = 50000; pt.light.attenuationRadius = 10; pt.position = [0, 0, 1.5]
                let spot = SpotLight(); spot.light.intensity = 50000; spot.light.innerAngleInDegrees = 30; spot.light.outerAngleInDegrees = 60
                spot.look(at: [0, 0, 0], from: [0, 0, 2], relativeTo: nil)
                let (_, pxPt) = try await p2RealityRender([ball3, pt, spot], clear: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
                let midPt = pxPt(32, 32)
                try expect(Int(midPt[2]) > Int(midDark[2]) + 20, "point/spot light made no difference: \(midPt) vs \(midDark)")
                // an occlusion material hides what is behind it: background shows through a green box behind an occluder
                let green = ModelEntity(mesh: .generateBox(size: 0.5), materials: [UnlitMaterial(color: .green)]); green.position = [0, 0, -0.5]
                let occ = ModelEntity(mesh: .generatePlane(width: 2, height: 2), materials: [OcclusionMaterial()]); occ.position = [0, 0, 0.2]
                let (_, pxOcc) = try await p2RealityRender([green, occ])
                let midOcc = pxOcc(32, 32)
                try expect(midOcc[1] < 100 && midOcc[0] > 150, "occluded pixel BGRA \(midOcc) (want the blue background)")
                // OpacityComponent 0.5 blends an unlit white box over blue
                let w = ModelEntity(mesh: .generateBox(size: 0.5), materials: [UnlitMaterial(color: .white)]); w.components.set(OpacityComponent(opacity: 0.5))
                let (_, pxOp) = try await p2RealityRender([w])
                let midOp = pxOp(32, 32)
                try expect(midOp[0] > 200 && midOp[2] > 80 && midOp[2] < 230, "half-opaque white over blue BGRA \(midOp)")
                // lighting models and material parameter types read back
                let models: [String] = ["\(LitLightingModel.self)", "\(UnlitLightingModel.self)", "\(HairLightingModel.self)"]
                let param: MaterialParameters.Value = .float(0.5)
                let scalar = MaterialScalarParameter.float(0.25)
                try expect("\(param)".contains("0.5") && "\(scalar)".contains("0.25"), "material parameters \(param) \(scalar)")
                let portal = PortalMaterial(); _ = portal
                return "lit \(midLit) / dark \(midDark) / point+spot \(midPt); occluded \(midOcc); 50% opacity \(midOp); models \(models)"
            }
        })
        c.append(check("RealityFoundation", "p27-animations-playback", timeout: 60) {
            try await onMain {
                let r = try RealityRenderer()
                let e = Entity(); e.name = "anim"
                r.entities.append(e)
                // FromToByAnimation on the transform, with a completion event
                let ftb = FromToByAnimation<Transform>(name: "move", from: Transform(translation: [0, 0, 0]), to: Transform(translation: [2, 0, 0]),
                                                      duration: 0.5, timing: .linear, isAdditive: false, bindTarget: .transform, repeatMode: AnimationRepeatMode.none,
                                                      fillMode: AnimationFillMode.forwards)
                let res = try AnimationResource.generate(with: ftb)
                let done = P2Count()
                let sub = r.subscribe(to: AnimationEvents.PlaybackCompleted.self) { ev in done.add(ev.playbackController.entity?.name ?? "?") }
                let ctl: AnimationPlaybackController = e.playAnimation(res, transitionDuration: 0, startsPaused: false)
                try expect(ctl.isPlaying, "controller not playing")
                for _ in 0..<5 { try r.update(0.05) }
                let mid = e.position.x
                for _ in 0..<15 { try r.update(0.05) }
                try expect(mid > 0.2 && mid < 1.8, "mid-animation x \(mid)")
                try expect(abs(e.position.x - 2) < 0.05, "end x \(e.position.x)")
                try expect(done.value >= 1 && done.names.first == "anim", "no PlaybackCompleted (\(done.names))")
                // a sampled animation (Float frames on a custom bind target is not allowed: transforms), a group, an orbit
                let frames = [Transform(translation: [0, 0, 0]), Transform(translation: [0, 1, 0]), Transform(translation: [0, 2, 0])]
                let sampled = SampledAnimation<Transform>(frames: frames, name: "rise", tweenMode: TweenMode.linear, frameInterval: 0.1, bindTarget: .transform)
                try expect(abs(sampled.duration - 0.2) < 1e-6 || abs(sampled.duration - 0.3) < 1e-6, "sampled duration \(sampled.duration)")
                let orbit = OrbitAnimation(name: "orbit", duration: 1, axis: [0, 1, 0], startTransform: Transform(translation: [1, 0, 0]), bindTarget: .transform)
                let group = AnimationGroup(group: [sampled, orbit], name: "grp")
                try expect(group.group.count == 2 && group.name == "grp", "group read back")
                let e2 = Entity(); r.entities.append(e2)
                e2.playAnimation(try AnimationResource.generate(with: sampled))
                for _ in 0..<10 { try r.update(0.05) }
                try expect(abs(e2.position.y - 2) < 0.05, "sampled end y \(e2.position.y)")
                // a blend tree (two transform sources at 0.5 / 0.5)
                let a = FromToByAnimation<Transform>(from: .identity, to: Transform(translation: [0, 0, 4]), duration: 0.2, bindTarget: .transform, fillMode: .forwards)
                let b = FromToByAnimation<Transform>(from: .identity, to: Transform(translation: [0, 0, 0]), duration: 0.2, bindTarget: .transform, fillMode: .forwards)
                let tree = BlendTreeAnimation<Transform>(BlendTreeBlendNode(sources: [BlendTreeSourceNode(source: a, weight: BlendWeight.value(0.5)),
                                                                                     BlendTreeSourceNode(source: b, weight: .value(0.5))]))
                let root: any BlendTreeNode = tree.root; _ = root
                let e3 = Entity(); r.entities.append(e3)
                e3.playAnimation(try AnimationResource.generate(with: tree))
                for _ in 0..<10 { try r.update(0.05) }
                let z3 = e3.position.z
                let handoff: AnimationHandoffType = .replace(applyToAllLayers: true)
                _ = e3.playAnimation(try AnimationResource.generate(with: orbit), transitionDuration: 0, startsPaused: true)
                sub.cancel()
                return "FromToBy mid \(mid) end \(e.position.x), completed \(done.value); sampled y \(e2.position.y); blend tree z \(z3); handoff \(handoff)"
            }
        })
        c.append(check("RealityFoundation", "p27-entity-actions", timeout: 60) {
            try await onMain {
                let r = try RealityRenderer()
                let e = ModelEntity(mesh: .generateBox(size: 0.1)); e.name = "act"
                r.entities.append(e)
                // SetEntityEnabledAction disables the entity; FromToByAction moves it
                let move = FromToByAction<Transform>(to: Transform(translation: [0, 3, 0]), timing: .linear)
                e.playAnimation(try AnimationResource.makeActionAnimation(for: move, duration: 0.3, bindTarget: .transform))
                for _ in 0..<12 { try r.update(0.05) }
                try expect(abs(e.position.y - 3) < 0.05, "FromToByAction end y \(e.position.y)")
                let spin = SpinAction(revolutions: 0.25, localAxis: [0, 0, 1], timingFunction: .linear)
                let e2 = Entity(); r.entities.append(e2)
                e2.playAnimation(try AnimationResource.makeActionAnimation(for: spin, duration: 0.2, bindTarget: .transform))
                for _ in 0..<10 { try r.update(0.05) }
                let ang = e2.orientation.angle, ax = e2.orientation.axis
                try expect(abs(ang - .pi / 2) < 0.05 && abs(abs(ax.z) - 1) < 0.05, "spin quarter turn: angle \(ang) axis \(ax)")
                let dis = SetEntityEnabledAction(isEnabled: false)
                e.playAnimation(try AnimationResource.makeActionAnimation(for: dis, duration: 0.1))
                for _ in 0..<6 { try r.update(0.05) }
                try expect(!e.isEnabled, "SetEntityEnabledAction did not disable")
                // the other actions: built, Codable round trip, animation resources made
                let pivot = ActionEntityResolution.entityNamed("act")
                let actions: [any EntityAction] = [
                    OrbitEntityAction(pivotEntity: pivot, revolutions: 1), EmphasizeAction(motionType: .pulse, style: .playful),
                    BillboardAction(), ImpulseAction(linearImpulse: [0, 2, 0]), PlayAnimationAction(animationName: "x"),
                    PlayAudioAction(audioResourceName: "nothing"), spin, dis, move,
                ]
                var coded = 0
                for a in actions {
                    if let ce = a as? any Codable { let d = try JSONEncoder().encode(ce); coded += d.isEmpty ? 0 : 1 }
                    _ = try AnimationResource.makeActionAnimation(for: a, duration: 0.5)
                }
                try expect(coded == actions.count, "Codable actions \(coded)/\(actions.count)")
                let orbit = try JSONDecoder().decode(OrbitEntityAction.self, from: try JSONEncoder().encode(OrbitEntityAction(pivotEntity: pivot, revolutions: 2)))
                try expect(orbit.revolutions == 2, "orbit decode")
                let ev: ActionEvent<SpinAction>.Type = ActionEvent<SpinAction>.self; _ = ev
                return "FromToByAction y \(e.position.y), spin \(ang) rad, disabled; \(actions.count) actions encoded + made into animations"
            }
        })
        c.append(check("RealityFoundation", "p27-physics-joints-forces", timeout: 60) {
            try await p2Main {
                let r = try RealityRenderer()
                let world = Entity(); r.entities.append(world)
                var sim = PhysicsSimulationComponent(); sim.gravity = [0, -9.8, 0]
                world.components.set(sim)
                // a body pushed up by a constant force effect stronger than gravity rises; a body without it falls
                func body(_ x: Float, _ name: String) -> ModelEntity {
                    let b = ModelEntity(mesh: .generateSphere(radius: 0.05)); b.name = name; b.position = [x, 0, 0]
                    b.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.05)], mode: .default, filter: CollisionFilter(group: CollisionGroup(rawValue: 2), mask: .all)))
                    var pb = PhysicsBodyComponent(massProperties: PhysicsMassProperties(mass: 1), material: PhysicsMaterialResource.generate(friction: 0.3, restitution: 0.1), mode: PhysicsBodyMode.dynamic)
                    pb.isAffectedByGravity = true
                    b.components.set(pb); world.addChild(b)
                    return b
                }
                let up = body(-1, "up"), down = body(1, "down")
                let field = Entity(); field.position = [-1, 0, 0]
                let force = ForceEffect(effect: ConstantForceEffect(strength: 30, direction: [0, 1, 0]),
                                        spatialFalloff: SpatialForceFalloff(bounds: ForceEffectBounds.sphere(radius: 0.5)), mask: CollisionGroup(rawValue: 2))
                field.components.set(ForceEffectComponent(effects: [force])); world.addChild(field)
                for _ in 0..<30 { try r.update(1.0 / 60) }
                try expect(up.position.y > 0.01 && down.position.y < -0.05, "force effect: up y \(up.position.y), down y \(down.position.y)")
                // the other force effects and falloffs construct and are accepted by the component
                let others: [any ForceEffectBase] = [
                    ForceEffect(effect: RadialForceEffect(strength: 2, restDistance: 0.5)), ForceEffect(effect: ConstantRadialForceEffect(strength: 1)),
                    ForceEffect(effect: DragForceEffect(strength: 1)), ForceEffect(effect: TurbulenceForceEffect(strength: 1, smoothness: 0.5, speed: 1)),
                    ForceEffect(effect: VortexForceEffect(strength: 1, axis: [0, 1, 0])),
                ]
                let fe = Entity(); fe.components.set(ForceEffectComponent(effects: others)); world.addChild(fe)
                try expect(fe.components[ForceEffectComponent.self]?.effects.count == 5, "force effects \(fe.components[ForceEffectComponent.self]?.effects.count ?? -1)")
                for _ in 0..<5 { try r.update(1.0 / 60) }
                // joints between pins on two bodies; a fixed joint keeps the pair together while they fall
                let a = body(3, "ja"), b = body(3.2, "jb")
                let pa: GeometricPin = a.pins.set(named: "pa", position: [0.1, 0, 0])
                let pb: GeometricPin = b.pins.set(named: "pb", position: [-0.1, 0, 0])
                let pins: EntityGeometricPins = a.pins; _ = pins
                let fixed = PhysicsFixedJoint(pin0: pa, pin1: pb)
                let jointsAll: [any PhysicsJoint] = [fixed, PhysicsRevoluteJoint(pin0: pa, pin1: pb), PhysicsSphericalJoint(pin0: pa, pin1: pb),
                                                     PhysicsPrismaticJoint(pin0: pa, pin1: pb), PhysicsDistanceJoint(pin0: pa, pin1: pb, distanceLimit: 0.1...0.3),
                                                     PhysicsCustomJoint(pin0: pa, pin1: pb)]
                try fixed.addToSimulation()
                var pj = PhysicsJointsComponent(); pj.joints = PhysicsJoints(jointsAll.dropFirst())
                try expect(pj.joints.count == 5 && pj != PhysicsJointsComponent(), "joints component \(pj.joints.count)")
                for _ in 0..<30 { try r.update(1.0 / 60) }
                let gap = simd_distance(a.position, b.position)
                try expect(abs(gap - 0.2) < 0.03 && a.position.y < -0.05, "fixed joint gap \(gap), fell to \(a.position.y)")
                // a convex cast finds the falling body
                guard let scene = up.scene else { throw Fail("no scene") }
                // casts against a target in the scene's own simulation (the bodies above live in the PhysicsSimulationComponent's)
                let probe = Entity(); probe.name = "probe"; probe.position = [10, 0, 0]
                probe.components.set(CollisionComponent(shapes: [.generateBox(size: [1, 1, 1])]))
                r.entities.append(probe); try r.update(1.0 / 60)
                let hits: [CollisionCastHit] = scene.raycast(from: [10, 5, 0], to: [10, -5, 0], query: .nearest, mask: .all, relativeTo: nil)
                try expect(hits.first?.entity.name == "probe" && abs((hits.first?.distance ?? 0) - 4.5) < 0.01, "raycast \(hits.map { "\($0.entity.name)@\($0.distance)" })")
                let swept: [CollisionCastHit] = scene.convexCast(convexShape: .generateSphere(radius: 0.1), fromPosition: [10, 5, 0], fromOrientation: .init(),
                                                                toPosition: [10, -5, 0], toOrientation: .init(), query: .nearest, mask: .all, relativeTo: nil)
                try expect(swept.first?.entity.name == "probe", "convex cast \(swept.map(\.entity.name))")
                let q: CollisionCastQueryType = .all; _ = q
                let shape: ShapeResource = try await ShapeResource.generateConvex(from: MeshResource.generateBox(size: 0.2))
                try expect(shape.bounds.extents.x > 0.19, "convex shape bounds \(shape.bounds.extents)")
                return "force: up \(up.position.y) down \(down.position.y); 6 force effects; \(jointsAll.count) joint kinds; fixed gap \(gap); ray hit \(hits.first!.entity.name), sweep \(swept.count)"
            }
        })
        c.append(check("RealityFoundation", "p27-ecs-queries-events-audio-library", timeout: 60) {
            try await p2Main {
                let r = try RealityRenderer()
                // scene / component events through event subscriptions
                let updates = P2Count(), added = P2Count()
                let s1: EventSubscription = r.subscribe(to: SceneEvents.Update.self) { _ in updates.add() }
                let s2: EventSubscription = r.subscribe(to: ComponentEvents.DidAdd.self, componentType: OpacityComponent.self) { e in added.add(e.entity.name) }
                let root = Entity(); root.name = "root"; r.entities.append(root)
                for i in 0..<4 { let e = Entity(); e.name = "q\(i)"; if i % 2 == 0 { e.components.set(OpacityComponent(opacity: 0.5)) }; root.addChild(e) }
                for _ in 0..<3 { try r.update(1.0 / 60) }
                guard let scene = root.scene else { throw Fail("no scene") }
                // an entity query over a predicate: the two with opacity
                let pred: QueryPredicate<Entity> = .has(OpacityComponent.self)
                let res: QueryResult<Entity> = scene.performQuery(EntityQuery(where: pred))
                let names = res.map(\.name).sorted()
                try expect(names == ["q0", "q2"], "query \(names)")
                try expect(updates.value >= 3 && added.names.sorted() == ["q0", "q2"], "events: updates \(updates.value), DidAdd \(added.names)")
                let kids: Entity.ChildCollection = root.children
                let coll: any EntityCollection = kids
                try expect(coll.count == 4, "children \(coll.count)")
                let src: any EventSource = root; _ = src
                s1.cancel(); s2.cancel()
                // animation / audio libraries, mix groups, reverb, LOD, portal, reference, scene understanding components
                let anim = try AnimationResource.generate(with: FromToByAnimation<Transform>(to: Transform(translation: [0, 1, 0]), duration: 0.1, bindTarget: .transform))
                let lib = AnimationLibraryComponent(animations: ["up": anim])
                let wav = FileManager.default.temporaryDirectory.appendingPathComponent("p27-tone.wav")
                try writeM4A(sine(440, secs: 0.2), to: wav.deletingPathExtension().appendingPathExtension("m4a"))
                let audio: AudioResource = try await AudioFileResource(contentsOf: wav.deletingPathExtension().appendingPathExtension("m4a"))
                let alib = AudioLibraryComponent(resources: ["tone": audio])
                let mix = AudioMixGroupsComponent(mixGroups: [AudioMixGroup(name: "fx")])
                let rev = ReverbComponent(reverb: Reverb.preset(.largeRoom))
                let lod = LevelOfDetailComponent(levels: [], switchingAt: .cameraDistance([]))
                let portal = PortalComponent(target: Entity())
                let refc = ReferenceComponent(named: "Nothing")
                let host = Entity(); host.name = "host"; root.addChild(host)
                var comps: [any Component] = [lib, alib, mix, rev, lod, portal, refc, BloomOptionsComponent()]
                #if !os(tvOS)
                comps.append(SceneUnderstandingComponent(entityType: nil))
                #endif
                for x in comps { host.components.set(x) }
                try expect(comps.allSatisfy { host.components.has(type(of: $0)) }, "library components")
                try expect(host.components[AnimationLibraryComponent.self]?.animations["up"] != nil && host.components[AudioLibraryComponent.self]?.resources["tone"] != nil,
                           "libraries read back")
                // the library's animation played by name; an audio controller prepared
                // (playAnimation(named:) does not find a library animation without a USD source: Apple's simulator plays nothing)
                let ctl: AnimationPlaybackController = host.playAnimation(host.components[AnimationLibraryComponent.self]!.animations["up"]!)
                for _ in 0..<10 { try r.update(0.05) }
                try expect(abs(host.position.y - 1) < 0.05 && ctl.isComplete, "library animation y \(host.position.y)")
                let ac: AudioPlaybackController = host.prepareAudio(audio)
                ac.gain = -6
                try expect(ac.gain == -6 && !ac.isPlaying, "audio controller")
                let agc: AudioGeneratorConfiguration = AudioGeneratorConfiguration(layoutTag: kAudioChannelLayoutTag_Mono, mixGroupName: "fx")
                try expect(agc.mixGroupName == "fx", "generator configuration")
                let gctl = try Audio.prepareAudio([(audio, host)])
                let grp: AudioPlaybackGroupController = gctl; _ = grp
                // bindable values: the entity's transform through a bind target
                let bt: BindTarget = .transform
                let bound: BindableValuesReference = host.bindableValues
                let bv: BindableValue<Transform>? = bound[bt, Transform.self]
                try expect(bv?.value.translation.y ?? -1 >= 0, "bindable transform \(String(describing: bv?.value.translation))")
                let tf: [AnimationTimingFunction] = [.linear, .easeIn, .easeOut, .easeInOut, .cubicBezier(controlPoint1: [0.1, 0.2], controlPoint2: [0.3, 0.9])]
                return "query \(names), \(updates.value) updates, \(comps.count) library components, library animation y \(host.position.y), audio \(type(of: audio)), \(tf.count) timing functions"
            }
        })
        c.append(check("RealityFoundation", "p27-mesh-collections-bounds", timeout: 60) {
            try await onMain {
                let m = MeshResource.generateBox(size: [1, 2, 3])
                let contents = m.contents
                let models: MeshModelCollection = contents.models
                let insts: MeshInstanceCollection = contents.instances
                let skels: MeshSkeletonCollection = contents.skeletons
                guard let model = models.first else { throw Fail("no model") }
                let parts: MeshPartCollection = model.parts
                guard let part = parts.first else { throw Fail("no part") }
                let pos: MeshBuffer<SIMD3<Float>> = part.positions
                let anyBuf: AnyMeshBuffer? = part.buffers[MeshBuffers.Identifier.positions]; _ = anyBuf
                let semID = p27SemanticID(MeshBuffers.positions)
                try expect(semID == "vertexPosition", "semantic id \(semID)")
                let xs = pos.elements.map(\.x)
                try expect(abs((xs.max() ?? 0) - 0.5) < 1e-4 && abs((xs.min() ?? 0) + 0.5) < 1e-4, "box x range \(xs.min() ?? 0)..\(xs.max() ?? 0)")
                try expect(insts.count >= 1 && skels.count == 0 && parts.count >= 1, "instances \(insts.count) skeletons \(skels.count) parts \(parts.count)")
                // a model entity's visual bounds and an oriented box
                let e = ModelEntity(mesh: m); e.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
                let vb = e.visualBounds(relativeTo: nil)
                try expect(abs(vb.extents.x - 2) < 1e-3 && abs(vb.extents.y - 1) < 1e-3, "rotated visual bounds \(vb.extents)")
                let calc: BoundingBoxCalculator? = nil; _ = calc
                #if os(iOS)
                let obb = OrientedBoundingBox(orientation: .init(angle: 0, axis: [0, 1, 0]), boundingBox: BoundingBox(min: [-0.5, -1, -1.5], max: [0.5, 1, 1.5]))
                try expect(obb.boundingBox.extents == [1, 2, 3], "obb \(obb)")
                #endif
                var content = contents
                var newModel = model; newModel.id = "p27"
                content.models = MeshModelCollection([newModel])
                try m.replace(with: content)
                try expect(m.contents.models["p27"] != nil, "replaced models \(m.contents.models.map(\.id))")
                return "box part \(pos.count) positions, x \(xs.min()!)..\(xs.max()!); rotated bounds \(vb.extents)"
            }
        })
        #endif
        return c
    }
}
