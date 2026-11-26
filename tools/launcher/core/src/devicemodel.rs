//! Xcode's 3D device models, as its DeviceHub draws them: V68.usdz is the iPhone Duo (iPhone19,4). They are Apple's:
//! never committed or shipped with x86Sim. `tools/devicemodels/extract-devicemodels.py` copies them out of the user's
//! own Xcode.xip (`x86sim account download-xcode`, `x86sim dev setup sdk --xip` do it) into `dir()`, and the launcher's
//! 3D phone (gui duo3d) and the web page's (share/web/duo3d.js, served by `x86sim-serve`) draw them when they are
//! there, else their own procedural model.
//!
//! The model is read with a pure Rust USD reader (openusd) and turned into one skinned mesh in the 3D phone's space
//! (`Model`): inner-screen pixels, x from the hinge (the left half at x < 0), y up, the inner screen at z = 0 facing +z.
//! Its materials are UsdPreviewSurface's inputs (colours, factors, textures and the uv set each reads), its skeleton a
//! chain of links along the hinge. The animation has three clips of 1.5 degrees a frame from flat (bend 0) to closed
//! (bend 180): frames 0..120 the right half folds (the left one holds still, as the 3D phone draws it), 130..250 the
//! left one, 260..380 both; `pose` blends the first clip's frames for a hinge angle. Apple's model puts the outer
//! screen on the left half's back and the cameras on the right half's.
use anyhow::{Context, Result};
use openusd::{sdf, usd, vt};
use std::collections::HashMap;
use std::path::{Path, PathBuf};

/// The iPhone Duo's model file name in `dir()`
pub const DUO: &str = "V68.usdz";
/// Degrees of bend per animation frame, and the first clip's last frame (closed)
const DEG_PER_FRAME: f64 = 1.5;
const CLIP_END: usize = 120;
/// Inner-screen pixels per centimetre of the model: the inner panel is 2853 x 2007 pixels over 15.797 x 11.082 cm
/// (measured from the model's own screen, `load` checks it)
const PX_PER_CM: f64 = 180.75;

/// Where the device models are: $X86SIM_DEVICEMODELS, else $XDG_DATA_HOME/x86sim/devicemodels
pub fn dir() -> PathBuf {
    if let Some(d) = std::env::var_os("X86SIM_DEVICEMODELS") {
        return PathBuf::from(d);
    }
    let data = std::env::var_os("XDG_DATA_HOME").map(PathBuf::from).unwrap_or_else(|| std::env::var_os("HOME").map(PathBuf::from).unwrap_or_default().join(".local/share"));
    data.join("x86sim/devicemodels")
}

/// The iPhone Duo's model when this machine has it (extracted from Xcode.xip), loaded once per process
pub fn duo() -> Option<std::sync::Arc<Model>> {
    static M: std::sync::Mutex<Option<(std::time::SystemTime, Option<std::sync::Arc<Model>>)>> = std::sync::Mutex::new(None);
    let p = dir().join(DUO);
    let mtime = std::fs::metadata(&p).and_then(|m| m.modified()).ok()?;
    let mut g = M.lock().unwrap();
    if let Some((t, m)) = g.as_ref() {
        if *t == mtime {
            return m.clone();
        }
    }
    let m = match load(&p) {
        Ok(m) => Some(std::sync::Arc::new(m)),
        Err(e) => {
            eprintln!("devicemodel: {}: {e:#}", p.display());
            None
        }
    };
    *g = Some((mtime, m.clone()));
    m
}

/// The web page's copy of the iPhone Duo's model (`Model::web`), made once per model
pub fn duo_web() -> Option<std::sync::Arc<Vec<u8>>> {
    static W: std::sync::Mutex<Option<(usize, std::sync::Arc<Vec<u8>>)>> = std::sync::Mutex::new(None);
    let m = duo()?;
    let key = std::sync::Arc::as_ptr(&m) as usize;
    let mut g = W.lock().unwrap();
    if let Some((k, b)) = g.as_ref() {
        if *k == key {
            return Some(b.clone());
        }
    }
    let b = std::sync::Arc::new(m.web());
    *g = Some((key, b.clone()));
    Some(b)
}

/// Runs the extractor on an Xcode.xip (or Xcode.app) into `dir()`
pub fn extract(xip: &Path, say: &mut dyn FnMut(&str)) -> Result<()> {
    let script = crate::aot::repo_root().join("tools/devicemodels/extract-devicemodels.py");
    anyhow::ensure!(script.exists(), "{} is missing", script.display());
    let mut c = std::process::Command::new("python3");
    c.arg("-I").arg(&script).arg(xip).arg("--out").arg(dir());
    let rc = crate::dev::stream(c, say)?;
    anyhow::ensure!(rc == 0, "extract-devicemodels.py failed (exit {rc})");
    Ok(())
}

/// A vertex: position, normal (i16 normalised), the two uv sets (st: colour / screens, st1: detail maps), four joints
/// and their weights (u8, normalised), the material. 48 bytes, the layout both renderers bind.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
#[repr(C)]
pub struct Vtx {
    pub p: [f32; 3],
    pub n: [i16; 4],
    pub uv: [f32; 2],
    pub uv1: [f32; 2],
    pub j: [u8; 4],
    pub w: [u8; 4],
    pub m: u16,
    pub _pad: u16,
}

/// A texture slot of a material: which image, which uv set (0 st, 1 st1), which channel (0..3, 4 rgb), and the
/// UsdUVTexture's scale and bias (a normal map's 2, -1)
#[derive(Clone, Debug, PartialEq, Default)]
pub struct Tex {
    pub image: usize,
    pub uv: u8,
    pub channel: u8,
    pub scale: [f32; 4],
    pub bias: [f32; 4],
}

/// UsdPreviewSurface's inputs; `screen` 1 the inner screen, 2 the outer one (their emissive placeholder becomes the
/// phone's picture)
#[derive(Clone, Debug, Default)]
pub struct Mat {
    pub name: String,
    pub base: [f32; 3],
    pub base_tex: Option<Tex>,
    pub metallic: f32,
    pub metallic_tex: Option<Tex>,
    pub roughness: f32,
    pub roughness_tex: Option<Tex>,
    pub occlusion_tex: Option<Tex>,
    pub normal_tex: Option<Tex>,
    pub opacity: f32,
    pub opacity_tex: Option<Tex>,
    pub clearcoat: f32,
    pub clearcoat_roughness: f32,
    pub screen: u8,
}

impl Mat {
    /// drawn blended (after the opaque ones, no depth writes)
    pub fn blended(&self) -> bool {
        self.opacity < 0.999 || self.opacity_tex.is_some()
    }
    /// hides what is behind it for a touch
    fn occludes(&self) -> bool {
        self.screen > 0 || (self.opacity > 0.5 && self.opacity_tex.is_none())
    }
}

/// An image of the package: its file name and bytes (JPEG / PNG as stored)
#[derive(Clone, Debug)]
pub struct Image {
    pub name: String,
    pub bytes: Vec<u8>,
}

impl Image {
    pub fn mime(&self) -> &'static str {
        if self.bytes.starts_with(b"\x89PNG") { "image/png" } else { "image/jpeg" }
    }
    /// Decoded to RGBA8: (width, height, pixels)
    pub fn rgba(&self) -> Result<(u32, u32, Vec<u8>)> {
        if self.bytes.starts_with(b"\x89PNG") {
            let mut d = png::Decoder::new(std::io::Cursor::new(&self.bytes));
            d.set_transformations(png::Transformations::EXPAND | png::Transformations::STRIP_16);
            let mut r = d.read_info()?;
            let mut buf = vec![0; r.output_buffer_size().context("png size")?];
            let info = r.next_frame(&mut buf)?;
            let (w, h) = (info.width, info.height);
            let ch = match info.color_type {
                png::ColorType::Grayscale => 1,
                png::ColorType::GrayscaleAlpha => 2,
                png::ColorType::Rgb => 3,
                _ => 4,
            };
            let mut out = Vec::with_capacity((w * h * 4) as usize);
            for p in buf[..(w * h) as usize * ch].chunks(ch) {
                out.extend_from_slice(&match ch {
                    1 => [p[0], p[0], p[0], 255],
                    2 => [p[0], p[0], p[0], p[1]],
                    3 => [p[0], p[1], p[2], 255],
                    _ => [p[0], p[1], p[2], p[3]],
                });
            }
            Ok((w, h, out))
        } else {
            let opts = zune_core::options::DecoderOptions::default().jpeg_set_out_colorspace(zune_core::colorspace::ColorSpace::RGBA);
            let mut d = zune_jpeg::JpegDecoder::new_with_options(std::io::Cursor::new(&self.bytes), opts);
            let px = d.decode().map_err(|e| anyhow::anyhow!("{}: {e:?}", self.name))?;
            let info = d.info().context("jpeg info")?;
            Ok((info.width as u32, info.height as u32, px))
        }
    }
}

/// A run of indices drawn with one material
#[derive(Clone, Debug)]
pub struct Group {
    pub mat: usize,
    pub start: usize,
    pub count: usize,
}

/// The whole phone, ready to draw: vertices in the 3D phone's space at rest (flat), indices grouped by material (the
/// opaque ones first, then the blended ones, the screens last of the opaque), and each animation frame's joint
/// matrices (column-major, the same space)
pub struct Model {
    pub v: Vec<Vtx>,
    pub i: Vec<u32>,
    pub groups: Vec<Group>,
    /// groups [..opaque] are opaque
    pub opaque: usize,
    pub mats: Vec<Mat>,
    pub images: Vec<Image>,
    pub joints: usize,
    /// frames[f][j]: joint j's matrix at frame f (bend f * 1.5 degrees), column-major
    pub frames: Vec<Vec<[f32; 16]>>,
}

// ---- small matrix helpers: USD's row-vector convention (p' = p * M), row-major [f64; 16]
type M4 = [f64; 16];
const ID: M4 = [1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0];
fn mul(a: &M4, b: &M4) -> M4 {
    let mut o = [0.0; 16];
    for r in 0..4 {
        for c in 0..4 {
            o[r * 4 + c] = (0..4).map(|k| a[r * 4 + k] * b[k * 4 + c]).sum();
        }
    }
    o
}
fn xform(p: [f64; 3], m: &M4) -> [f64; 3] {
    let mut o = [0.0; 3];
    for c in 0..3 {
        o[c] = p[0] * m[c] + p[1] * m[4 + c] + p[2] * m[8 + c] + m[12 + c];
    }
    o
}
fn xdir(p: [f64; 3], m: &M4) -> [f64; 3] {
    let mut o = [0.0; 3];
    for c in 0..3 {
        o[c] = p[0] * m[c] + p[1] * m[4 + c] + p[2] * m[8 + c];
    }
    o
}
/// the inverse of a rigid transform with a uniform scale (rotation * s, translation)
fn inv_rigid(m: &M4) -> M4 {
    let s2 = m[0] * m[0] + m[1] * m[1] + m[2] * m[2];
    let mut o = ID;
    for r in 0..3 {
        for c in 0..3 {
            o[r * 4 + c] = m[c * 4 + r] / s2;
        }
    }
    let t = [m[12], m[13], m[14]];
    for c in 0..3 {
        o[12 + c] = -(t[0] * o[c] + t[1] * o[4 + c] + t[2] * o[8 + c]);
    }
    o
}
/// translation * rotation (quaternion w, x, y, z) * scale, row-vector form (scale first)
fn trs(t: [f64; 3], q: [f64; 4], s: [f64; 3]) -> M4 {
    let [w, x, y, z] = q;
    // the column-vector rotation matrix, transposed for row vectors
    let r = [
        [1.0 - 2.0 * (y * y + z * z), 2.0 * (x * y - w * z), 2.0 * (x * z + w * y)],
        [2.0 * (x * y + w * z), 1.0 - 2.0 * (x * x + z * z), 2.0 * (y * z - w * x)],
        [2.0 * (x * z - w * y), 2.0 * (y * z + w * x), 1.0 - 2.0 * (x * x + y * y)],
    ];
    let mut m = ID;
    for row in 0..3 {
        for col in 0..3 {
            m[row * 4 + col] = r[col][row] * s[row];
        }
    }
    m[12] = t[0];
    m[13] = t[1];
    m[14] = t[2];
    m
}

// ---- reading values
fn val(p: &usd::Prim, name: &str) -> Option<vt::Value> {
    p.attribute(name).get::<vt::Value>().ok().flatten()
}
fn val_at(p: &usd::Prim, name: &str, t: f64) -> Option<vt::Value> {
    p.attribute(name).get_at::<vt::Value>(usd::TimeCode::new(t)).ok().flatten()
}
fn f3s(v: Option<vt::Value>) -> Vec<[f64; 3]> {
    match v {
        Some(vt::Value::Vec3fVec(a)) => a.iter().map(|q| [q.x as f64, q.y as f64, q.z as f64]).collect(),
        Some(vt::Value::Vec3dVec(a)) => a.iter().map(|q| [q.x, q.y, q.z]).collect(),
        Some(vt::Value::Vec3hVec(a)) => a.iter().map(|q| [q.x.to_f64(), q.y.to_f64(), q.z.to_f64()]).collect(),
        _ => vec![],
    }
}
fn f2s(v: Option<vt::Value>) -> Vec<[f32; 2]> {
    match v {
        Some(vt::Value::Vec2fVec(a)) => a.iter().map(|q| [q.x, q.y]).collect(),
        Some(vt::Value::Vec2dVec(a)) => a.iter().map(|q| [q.x as f32, q.y as f32]).collect(),
        _ => vec![],
    }
}
fn ints(v: Option<vt::Value>) -> Vec<i32> {
    match v {
        Some(vt::Value::IntVec(a)) => a,
        _ => vec![],
    }
}
fn floats(v: Option<vt::Value>) -> Vec<f32> {
    match v {
        Some(vt::Value::FloatVec(a)) => a,
        Some(vt::Value::DoubleVec(a)) => a.iter().map(|x| *x as f32).collect(),
        _ => vec![],
    }
}
fn toks(v: Option<vt::Value>) -> Vec<String> {
    match v {
        Some(vt::Value::TokenVec(a)) => a.iter().map(|t| t.as_str().to_string()).collect(),
        Some(vt::Value::StringVec(a)) => a,
        _ => vec![],
    }
}
fn mats(v: Option<vt::Value>) -> Vec<M4> {
    match v {
        Some(vt::Value::Matrix4dVec(a)) => a.iter().map(|m| m.0).collect(),
        _ => vec![],
    }
}
fn mat4(v: Option<vt::Value>) -> Option<M4> {
    match v {
        Some(vt::Value::Matrix4d(m)) => Some(m.0),
        _ => None,
    }
}
fn quats(v: Option<vt::Value>) -> Vec<[f64; 4]> {
    match v {
        Some(vt::Value::QuatfVec(a)) => a.iter().map(|q| [q.w as f64, q.x as f64, q.y as f64, q.z as f64]).collect(),
        Some(vt::Value::QuathVec(a)) => a.iter().map(|q| [q.w.to_f64(), q.x.to_f64(), q.y.to_f64(), q.z.to_f64()]).collect(),
        Some(vt::Value::QuatdVec(a)) => a.iter().map(|q| [q.w, q.x, q.y, q.z]).collect(),
        _ => vec![],
    }
}
fn scalar(v: &vt::Value) -> Option<f32> {
    match v {
        vt::Value::Float(x) => Some(*x),
        vt::Value::Double(x) => Some(*x as f32),
        vt::Value::Int(x) => Some(*x as f32),
        _ => None,
    }
}
fn vec3(v: &vt::Value) -> Option<[f32; 3]> {
    match v {
        vt::Value::Vec3f(q) => Some([q.x, q.y, q.z]),
        vt::Value::Vec3d(q) => Some([q.x as f32, q.y as f32, q.z as f32]),
        _ => None,
    }
}
fn vec4(v: Option<vt::Value>) -> Option<[f32; 4]> {
    match v {
        Some(vt::Value::Vec4f(q)) => Some([q.x, q.y, q.z, q.w]),
        Some(vt::Value::Vec4d(q)) => Some([q.x as f32, q.y as f32, q.z as f32, q.w as f32]),
        _ => None,
    }
}
fn interp(p: &usd::Prim, name: &str) -> String {
    p.attribute(name).metadata::<openusd::tf::Token>("interpolation").ok().flatten().map(|t| t.as_str().to_string()).unwrap_or_default()
}
fn element_size(p: &usd::Prim, name: &str) -> usize {
    p.attribute(name).metadata::<i32>("elementSize").ok().flatten().unwrap_or(1).max(1) as usize
}
/// the last element of a joint path ("/a/b" -> "b"): joints are matched by their whole path
fn joint_key(s: &str) -> String {
    s.trim_start_matches('/').to_string()
}

/// A primvar read per face corner: values and, per corner, the value's index
fn primvar(p: &usd::Prim, name: &str, fvi: &[i32]) -> (Vec<[f32; 2]>, Vec<usize>) {
    let vals = f2s(val(p, &format!("primvars:{name}")));
    if vals.is_empty() {
        return (vec![[0.0, 0.0]], vec![0; fvi.len()]);
    }
    let idx = ints(val(p, &format!("primvars:{name}:indices")));
    let fv = interp(p, &format!("primvars:{name}")) != "vertex" && (vals.len() != fvi.iter().map(|&i| i as usize + 1).max().unwrap_or(0) || !idx.is_empty() || vals.len() == fvi.len());
    let per: Vec<usize> = if !idx.is_empty() {
        if idx.len() == fvi.len() { idx.iter().map(|&i| i as usize).collect() } else { fvi.iter().map(|&v| idx.get(v as usize).copied().unwrap_or(0) as usize).collect() }
    } else if fv {
        (0..fvi.len()).collect()
    } else {
        fvi.iter().map(|&v| v as usize).collect()
    };
    let per = per.into_iter().map(|i| i.min(vals.len() - 1)).collect();
    (vals, per)
}

/// The texture a shader input is connected to (a UsdUVTexture), with its uv set and channel
fn texture(stage: &usd::Stage, input: &usd::Attribute, images: &mut Vec<Image>, pkg: &mut Package) -> Option<Tex> {
    let src = input.connections().ok()?.into_iter().next()?;
    let (prim_path, prop) = src.split_property()?;
    let channel = match prop.trim_start_matches("outputs:") {
        "r" => 0,
        "g" => 1,
        "b" => 2,
        "a" => 3,
        _ => 4,
    };
    let sh = stage.prim(prim_path).ok()?;
    // the path inside the package: the resolved one's "pkg.usdz[inner/path]", else the authored one (relative to the
    // layer that holds it, so matched by its end)
    let (authored, resolved) = match val(&sh, "inputs:file") {
        Some(vt::Value::AssetPath(a)) => (a.authored_path.clone(), a.resolved_path().map(str::to_string)),
        _ => return None,
    };
    let inner = |s: &str| s.rsplit_once('[').map(|(_, r)| r.trim_end_matches(']').to_string());
    let name = resolved.as_deref().and_then(inner).or_else(|| inner(&authored)).or_else(|| pkg.find(authored.trim_start_matches("./"))).unwrap_or(authored);
    let image = match images.iter().position(|i| i.name == name) {
        Some(i) => i,
        None => {
            let bytes = pkg.read(&name)?;
            images.push(Image { name, bytes });
            images.len() - 1
        }
    };
    // the uv set: the st input's primvar reader's varname
    let mut uv = 0;
    if let Some(st) = sh.attribute("inputs:st").connections().ok().and_then(|c| c.into_iter().next()) {
        if let Ok(reader) = stage.prim(st.prim_path()) {
            let v = match val(&reader, "inputs:varname") {
                Some(vt::Value::String(s)) => s,
                Some(vt::Value::Token(t)) => t.as_str().to_string(),
                _ => String::new(),
            };
            uv = u8::from(v == "st1");
        }
    }
    Some(Tex { image, uv, channel, scale: vec4(val(&sh, "inputs:scale")).unwrap_or([1.0; 4]), bias: vec4(val(&sh, "inputs:bias")).unwrap_or([0.0; 4]) })
}

/// The .usdz's files (a zip, stored)
struct Package(zip::ZipArchive<std::io::Cursor<Vec<u8>>>);
impl Package {
    /// the package's file whose path ends with `tail`
    fn find(&mut self, tail: &str) -> Option<String> {
        (0..self.0.len()).filter_map(|i| self.0.by_index(i).ok().and_then(|f| f.name().ok().map(|n| n.to_string()))).find(|n| n.ends_with(&format!("/{tail}")) || n == tail)
    }
    fn read(&mut self, name: &str) -> Option<Vec<u8>> {
        use std::io::Read;
        let mut f = self.0.by_name(name).ok()?;
        let mut b = vec![];
        f.read_to_end(&mut b).ok()?;
        Some(b)
    }
}

/// A material prim's UsdPreviewSurface
fn material(stage: &usd::Stage, path: &sdf::Path, images: &mut Vec<Image>, pkg: &mut Package) -> Mat {
    let mut m = Mat { name: path.name().unwrap_or_default().to_string(), base: [0.18; 3], metallic: 0.0, roughness: 0.5, opacity: 1.0, clearcoat_roughness: 0.01, ..Default::default() };
    let Ok(prim) = stage.prim(path.clone()) else { return m };
    let Ok(children) = prim.children() else { return m };
    let Some(surf) = children.into_iter().find(|c| matches!(val(c, "info:id"), Some(vt::Value::Token(t)) if t.as_str() == "UsdPreviewSurface")) else { return m };
    let mut emissive = false;
    for (name, slot) in [("diffuseColor", 0), ("metallic", 1), ("roughness", 2), ("occlusion", 3), ("normal", 4), ("opacity", 5), ("clearcoat", 6), ("clearcoatRoughness", 7), ("emissiveColor", 8)] {
        let a = surf.attribute(format!("inputs:{name}"));
        let tex = texture(stage, &a, images, pkg);
        let v = a.get::<vt::Value>().ok().flatten();
        match slot {
            0 => {
                if let Some(c) = v.as_ref().and_then(vec3) {
                    m.base = c;
                }
                if tex.is_some() {
                    m.base = [1.0; 3];
                }
                m.base_tex = tex;
            }
            1 => {
                m.metallic = v.as_ref().and_then(scalar).unwrap_or(0.0);
                m.metallic_tex = tex;
            }
            2 => {
                m.roughness = v.as_ref().and_then(scalar).unwrap_or(0.5);
                m.roughness_tex = tex;
            }
            3 => m.occlusion_tex = tex,
            4 => m.normal_tex = tex,
            5 => {
                m.opacity = v.as_ref().and_then(scalar).unwrap_or(1.0);
                m.opacity_tex = tex;
            }
            6 => m.clearcoat = v.as_ref().and_then(scalar).unwrap_or(0.0),
            7 => m.clearcoat_roughness = v.as_ref().and_then(scalar).unwrap_or(0.01),
            _ => emissive = tex.is_some(),
        }
    }
    // the screens: the only emissive materials (a placeholder picture), told apart by `load`
    if emissive {
        m.screen = 255;
    }
    m
}

/// Reads a .usdz into a `Model`
pub fn load(path: &Path) -> Result<Model> {
    let bytes = std::fs::read(path)?;
    let mut pkg = Package(zip::ZipArchive::new(std::io::Cursor::new(bytes)).context("not a usdz (zip) package")?);
    let stage = usd::Stage::open(path.to_string_lossy().as_ref()).map_err(|e| anyhow::anyhow!("{e}"))?;
    let mut paths = vec![];
    stage.traverse(usd::PrimPredicate::ALL, |p| paths.push(p.clone())).map_err(|e| anyhow::anyhow!("{e}"))?;
    let kind = |p: &sdf::Path| stage.prim(p.clone()).ok().and_then(|q| q.type_name().ok().flatten()).map(|t| t.as_str().to_string()).unwrap_or_default();

    // the skeleton and its animation
    let skel_path = paths.iter().find(|p| kind(p) == "Skeleton").context("no Skeleton")?.clone();
    let skel = stage.prim(skel_path.clone())?;
    let joints: Vec<String> = toks(val(&skel, "joints")).iter().map(|j| joint_key(j)).collect();
    // the shaders hold 32 joint matrices (WebGL 2 promises 256 vertex uniform vectors)
    anyhow::ensure!(!joints.is_empty() && joints.len() <= 32, "{} joints", joints.len());
    let bind = mats(val(&skel, "bindTransforms"));
    let rest = mats(val(&skel, "restTransforms"));
    anyhow::ensure!(bind.len() == joints.len(), "bindTransforms");
    let parent: Vec<Option<usize>> = joints.iter().map(|j| j.rsplit_once('/').and_then(|(par, _)| joints.iter().position(|k| k == par))).collect();
    let anim_path = paths.iter().find(|p| kind(p) == "SkelAnimation").context("no SkelAnimation")?.clone();
    let anim = stage.prim(anim_path)?;
    let anim_joints: Vec<Option<usize>> = toks(val(&anim, "joints")).iter().map(|j| joints.iter().position(|k| *k == joint_key(j))).collect();

    // the 3D phone's space from the model's: the model has the thickness along +y (the inner screen's side), the height
    // along z (its top at -z) and the width along x; ours is (x, -z, y - screen) in pixels. Found from the inner screen.
    let mut meshes = vec![];
    for p in &paths {
        if kind(p) == "Mesh" {
            meshes.push(stage.prim(p.clone())?);
        }
    }
    // materials, in order of first use
    let mut mat_list: Vec<Mat> = vec![];
    let mut mat_of: HashMap<String, usize> = HashMap::new();
    let mut images = vec![];
    struct Raw {
        mat: usize,
        corners: Vec<(usize, [f64; 3], usize, usize)>, // point, normal, st index, st1 index
        tris: Vec<[usize; 3]>,
        points: Vec<[f64; 3]>,
        st: Vec<[f32; 2]>,
        st1: Vec<[f32; 2]>,
        infl: Vec<Vec<(usize, f32)>>,
        gbind: M4,
    }
    let mut raws = vec![];
    for m in &meshes {
        let points = f3s(val(m, "points"));
        let fvc = ints(val(m, "faceVertexCounts"));
        let fvi = ints(val(m, "faceVertexIndices"));
        if points.is_empty() || fvi.is_empty() {
            continue;
        }
        let mpath = m.relationship("material:binding").targets().ok().and_then(|t| t.into_iter().next());
        let key = mpath.as_ref().map(|p| p.as_str().to_string()).unwrap_or_default();
        let mat = match mat_of.get(&key) {
            Some(&i) => i,
            None => {
                let mm = match &mpath {
                    Some(p) => material(&stage, p, &mut images, &mut pkg),
                    None => Mat { name: "none".into(), base: [0.1; 3], roughness: 0.5, opacity: 1.0, ..Default::default() },
                };
                mat_list.push(mm);
                mat_of.insert(key, mat_list.len() - 1);
                mat_list.len() - 1
            }
        };
        let normals = f3s(val(m, "normals"));
        let n_fv = normals.len() == fvi.len() && interp(m, "normals") != "vertex";
        let (st, st_i) = primvar(m, "st", &fvi);
        let (st1, st1_i) = primvar(m, "st1", &fvi);
        // the skin: per point, its joints in the skeleton's order and weights
        let mj: Vec<Option<usize>> = toks(val(m, "skel:joints")).iter().map(|j| joints.iter().position(|k| *k == joint_key(j))).collect();
        let ji = ints(val(m, "primvars:skel:jointIndices"));
        let jw = floats(val(m, "primvars:skel:jointWeights"));
        let es = element_size(m, "primvars:skel:jointIndices");
        let constant = interp(m, "primvars:skel:jointIndices") == "constant";
        let mut infl = vec![];
        for pi in 0..points.len() {
            let base = if constant { 0 } else { pi * es };
            let mut v = vec![];
            for k in 0..es {
                let (Some(&j), Some(&w)) = (ji.get(base + k), jw.get(base + k)) else { break };
                if w <= 0.0 {
                    continue;
                }
                let sj = if mj.is_empty() { Some(j as usize) } else { mj.get(j as usize).copied().flatten() };
                if let Some(sj) = sj {
                    v.push((sj, w));
                }
            }
            if v.is_empty() {
                v.push((0, 1.0));
            }
            infl.push(v);
        }
        // corners and the fan triangles of each face
        let mut corners = vec![];
        let mut tris = vec![];
        let mut at = 0usize;
        for &c in &fvc {
            let c = c as usize;
            if at + c > fvi.len() {
                break;
            }
            for k in 0..c {
                let ci = at + k;
                let pi = fvi[ci] as usize;
                let n = if n_fv { normals[ci] } else { normals.get(pi).copied().unwrap_or([0.0, 1.0, 0.0]) };
                corners.push((pi.min(points.len() - 1), n, st_i[ci], st1_i[ci]));
            }
            for k in 1..c.saturating_sub(1) {
                tris.push([at, at + k, at + k + 1]);
            }
            at += c;
        }
        let gbind = mat4(val(m, "primvars:skel:geomBindTransform")).unwrap_or(ID);
        raws.push(Raw { mat, corners, tris, points, st, st1, infl, gbind });
    }
    anyhow::ensure!(!raws.is_empty(), "no meshes");

    // which emissive material is which screen: the inner screen spans both halves (x < 0 and x > 0)
    for (mi, m) in mat_list.iter_mut().enumerate() {
        if m.screen == 255 {
            let (mut lo, mut hi) = (f64::MAX, f64::MIN);
            for r in raws.iter().filter(|r| r.mat == mi) {
                for c in &r.corners {
                    let p = r.points[c.0];
                    lo = lo.min(p[0]);
                    hi = hi.max(p[0]);
                }
            }
            m.screen = if lo < -0.5 && hi > 0.5 { 1 } else { 2 };
        }
    }
    let inner = mat_list.iter().position(|m| m.screen == 1).context("no inner screen")?;
    // its plane (the model's y) and size give the mapping
    let (mut y, mut n, mut w) = (0.0, 0.0, (f64::MAX, f64::MIN));
    for r in raws.iter().filter(|r| r.mat == inner) {
        for c in &r.corners {
            let p = xform(r.points[c.0], &r.gbind);
            y += p[1];
            n += 1.0;
            w = (w.0.min(p[0]), w.1.max(p[0]));
        }
    }
    let screen_y = y / n;
    let k = PX_PER_CM;
    let scale_check = 2853.0 / (w.1 - w.0);
    anyhow::ensure!((scale_check / k - 1.0).abs() < 0.03, "the inner screen is {:.3} cm wide: not the iPhone Duo's model", w.1 - w.0);
    // C: model -> ours (row-vector): x' = k x, y' = -k z, z' = k (y - screen_y)
    let c: M4 = [k, 0.0, 0.0, 0.0, 0.0, 0.0, k, 0.0, 0.0, -k, 0.0, 0.0, 0.0, 0.0, -k * screen_y, 1.0];
    let c_inv = inv_rigid(&c);

    // vertices (deduplicated per mesh), indices per material
    let mut v: Vec<Vtx> = vec![];
    let mut per_mat: Vec<Vec<u32>> = vec![vec![]; mat_list.len()];
    for r in &raws {
        let mut seen: HashMap<(usize, [i64; 3], usize, usize), u32> = HashMap::new();
        let ids: Vec<u32> = r
            .corners
            .iter()
            .map(|&(pi, nrm, si, s1)| {
                let qn = [(nrm[0] * 1e4) as i64, (nrm[1] * 1e4) as i64, (nrm[2] * 1e4) as i64];
                *seen.entry((pi, qn, si, s1)).or_insert_with(|| {
                    let p = xform(xform(r.points[pi], &r.gbind), &c);
                    let nn = xdir(xdir(nrm, &r.gbind), &c);
                    let l = (nn[0] * nn[0] + nn[1] * nn[1] + nn[2] * nn[2]).sqrt().max(1e-12);
                    let q = |x: f64| (x / l * 32767.0).round().clamp(-32767.0, 32767.0) as i16;
                    // the four strongest influences, weights summing to 255
                    let mut inf = r.infl[pi].clone();
                    inf.sort_by(|a, b| b.1.total_cmp(&a.1));
                    inf.truncate(4);
                    let tot: f32 = inf.iter().map(|x| x.1).sum::<f32>().max(1e-9);
                    let mut j = [0u8; 4];
                    let mut wt = [0u8; 4];
                    let mut left = 255i32;
                    for (s, (jj, ww)) in inf.iter().enumerate() {
                        j[s] = *jj as u8;
                        let b = if s + 1 == inf.len() { left } else { ((ww / tot) * 255.0).round() as i32 };
                        let b = b.clamp(0, left);
                        wt[s] = b as u8;
                        left -= b;
                    }
                    let stv = r.st[si.min(r.st.len() - 1)];
                    let st1v = r.st1[s1.min(r.st1.len() - 1)];
                    v.push(Vtx { p: [p[0] as f32, p[1] as f32, p[2] as f32], n: [q(nn[0]), q(nn[1]), q(nn[2]), 0], uv: stv, uv1: st1v, j, w: wt, m: r.mat as u16, _pad: 0 });
                    (v.len() - 1) as u32
                })
            })
            .collect();
        for t in &r.tris {
            per_mat[r.mat].extend_from_slice(&[ids[t[0]], ids[t[1]], ids[t[2]]]);
        }
    }
    anyhow::ensure!(v.len() < u32::MAX as usize, "too many vertices");
    // groups: opaque non-screens, the screens, then the blended ones
    let mut order: Vec<usize> = (0..mat_list.len()).filter(|&m| !per_mat[m].is_empty()).collect();
    let rank = |m: &Mat| if m.blended() && m.screen == 0 { 2 } else if m.screen > 0 { 1 } else { 0 };
    order.sort_by_key(|&m| rank(&mat_list[m]));
    let mut i = vec![];
    let mut groups = vec![];
    let mut opaque = 0;
    for m in order {
        if mat_list[m].opacity <= 0.001 && mat_list[m].opacity_tex.is_none() && mat_list[m].clearcoat <= 0.0 {
            continue;
        }
        groups.push(Group { mat: m, start: i.len(), count: per_mat[m].len() });
        i.extend_from_slice(&per_mat[m]);
        if rank(&mat_list[m]) < 2 {
            opaque = groups.len();
        }
    }

    // joint matrices per frame of the first clip, in our space: C^-1 * inverse(bind) * world * C
    let bind_inv: Vec<M4> = bind.iter().map(inv_rigid).collect();
    let mut frames = vec![];
    for f in 0..=CLIP_END {
        let t = f as f64;
        let tr = f3s(val_at(&anim, "translations", t));
        let ro = quats(val_at(&anim, "rotations", t));
        let sc = f3s(val_at(&anim, "scales", t));
        let mut local: Vec<M4> = rest.iter().copied().chain(std::iter::repeat(ID)).take(joints.len()).collect();
        for (ai, j) in anim_joints.iter().enumerate() {
            let Some(j) = *j else { continue };
            let (Some(tt), Some(qq)) = (tr.get(ai), ro.get(ai)) else { continue };
            local[j] = trs(*tt, *qq, sc.get(ai).copied().unwrap_or([1.0; 3]));
        }
        let mut world = vec![ID; joints.len()];
        for j in 0..joints.len() {
            // joints are listed parents first
            world[j] = match parent[j] {
                Some(p) => mul(&local[j], &world[p]),
                None => local[j],
            };
        }
        frames.push(
            (0..joints.len())
                .map(|j| {
                    let m = mul(&mul(&c_inv, &mul(&bind_inv[j], &world[j])), &c);
                    // row-major row-vector == column-major column-vector
                    let mut o = [0f32; 16];
                    for (x, y) in o.iter_mut().zip(m.iter()) {
                        *x = *y as f32;
                    }
                    o
                })
                .collect(),
        );
    }
    Ok(Model { v, i, groups, opaque, mats: mat_list, images, joints: joints.len(), frames })
}

impl Model {
    /// The joint matrices at hinge angle `deg` (0 closed .. 180 flat): the first clip's frames blended
    pub fn pose(&self, deg: f64) -> Vec<[f32; 16]> {
        let f = ((180.0 - deg.clamp(0.0, 180.0)) / DEG_PER_FRAME).clamp(0.0, CLIP_END as f64);
        let (a, t) = (f.floor() as usize, (f - f.floor()) as f32);
        let b = (a + 1).min(CLIP_END);
        self.frames[a].iter().zip(&self.frames[b]).map(|(x, y)| std::array::from_fn(|k| x[k] + (y[k] - x[k]) * t)).collect()
    }

    /// Vertex `vi`'s position under the joint matrices `bones`
    pub fn skin(&self, vi: usize, bones: &[[f32; 16]]) -> [f32; 3] {
        let v = &self.v[vi];
        let mut o = [0f32; 3];
        for s in 0..4 {
            let w = v.w[s] as f32 / 255.0;
            if w == 0.0 {
                continue;
            }
            let m = &bones[v.j[s] as usize];
            for c in 0..3 {
                o[c] += w * (v.p[0] * m[c] + v.p[1] * m[4 + c] + v.p[2] * m[8 + c] + m[12 + c]);
            }
        }
        o
    }

    /// Every vertex posed (for touches and framing)
    pub fn posed(&self, bones: &[[f32; 16]]) -> Vec<[f32; 3]> {
        (0..self.v.len()).map(|i| self.skin(i, bones)).collect()
    }

    /// The touch surfaces: triangles that hide what is behind them, tagged 0 (body) or the screen (1 inner, 2 outer)
    pub fn hit_mesh(&self, posed: Vec<[f32; 3]>) -> HitMesh {
        let mut tris = vec![];
        for g in &self.groups {
            let m = &self.mats[g.mat];
            if !m.occludes() {
                continue;
            }
            for t in self.i[g.start..g.start + g.count].chunks(3) {
                tris.push(([t[0], t[1], t[2]], m.screen));
            }
        }
        HitMesh { p: posed, uv: self.v.iter().map(|v| v.uv).collect(), tris }
    }

    /// The web page's copy (`/devicemodel/<name>`): "X86M", a u32 header length, the JSON header, then the vertex
    /// bytes, the u32 indices, the joint matrices (f32, frames x joints x 16) and the images, each at a 4-byte aligned
    /// offset the header gives
    pub fn web(&self) -> Vec<u8> {
        let mut body: Vec<u8> = vec![];
        let mut put = |b: &[u8]| {
            while body.len() % 4 != 0 {
                body.push(0);
            }
            let at = body.len();
            body.extend_from_slice(b);
            (at, b.len())
        };
        let mut vb = Vec::with_capacity(self.v.len() * 48);
        for v in &self.v {
            for x in v.p {
                vb.extend_from_slice(&x.to_le_bytes());
            }
            for x in v.n {
                vb.extend_from_slice(&x.to_le_bytes());
            }
            for x in v.uv.iter().chain(&v.uv1) {
                vb.extend_from_slice(&x.to_le_bytes());
            }
            vb.extend_from_slice(&v.j);
            vb.extend_from_slice(&v.w);
            vb.extend_from_slice(&v.m.to_le_bytes());
            vb.extend_from_slice(&[0, 0]);
        }
        let verts = put(&vb);
        let ib: Vec<u8> = self.i.iter().flat_map(|x| x.to_le_bytes()).collect();
        let idx = put(&ib);
        let fb: Vec<u8> = self.frames.iter().flatten().flatten().flat_map(|x| x.to_le_bytes()).collect();
        let frames = put(&fb);
        let images: Vec<serde_json::Value> = self.images.iter().map(|im| {
            let (at, len) = put(&im.bytes);
            serde_json::json!({"at": at, "len": len, "mime": im.mime()})
        }).collect();
        let tex = |t: &Option<Tex>| t.as_ref().map(|t| serde_json::json!({"image": t.image, "uv": t.uv, "channel": t.channel, "scale": t.scale, "bias": t.bias}));
        let mats: Vec<serde_json::Value> = self.mats.iter().map(|m| serde_json::json!({
            "base": m.base, "baseTex": tex(&m.base_tex), "metallic": m.metallic, "metallicTex": tex(&m.metallic_tex),
            "roughness": m.roughness, "roughnessTex": tex(&m.roughness_tex), "occlusionTex": tex(&m.occlusion_tex),
            "normalTex": tex(&m.normal_tex), "opacity": m.opacity, "opacityTex": tex(&m.opacity_tex), "clearcoat": m.clearcoat,
            "clearcoatRoughness": m.clearcoat_roughness, "screen": m.screen, "blended": m.blended(), "occludes": m.occludes(),
        })).collect();
        let groups: Vec<serde_json::Value> = self.groups.iter().map(|g| serde_json::json!([g.mat, g.start, g.count])).collect();
        let head = serde_json::json!({
            "verts": [verts.0, self.v.len()], "indices": [idx.0, self.i.len()], "frames": [frames.0, self.frames.len()],
            "joints": self.joints, "degPerFrame": DEG_PER_FRAME, "groups": groups, "opaque": self.opaque, "mats": mats, "images": images,
        })
        .to_string();
        let mut out = b"X86M".to_vec();
        let mut h = head.into_bytes();
        while (8 + h.len()) % 4 != 0 {
            h.push(b' ');
        }
        out.extend_from_slice(&(h.len() as u32).to_le_bytes());
        out.extend_from_slice(&h);
        out.extend_from_slice(&body);
        out
    }
}

/// Posed triangles for tracing a pointer onto the screens
pub struct HitMesh {
    pub p: Vec<[f32; 3]>,
    pub uv: Vec<[f32; 2]>,
    pub tris: Vec<([u32; 3], u8)>,
}

/// Where a ray met a screen: the screen (1 inner, 2 outer), the ray's t and the picture point (0..1, y down)
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ScreenHit {
    pub screen: u8,
    pub t: f32,
    pub x: f32,
    pub y: f32,
}

impl HitMesh {
    /// The nearest triangle the ray (origin, direction) meets in front of it; with `only`, just that screen's (no
    /// occlusion). None when the nearest is the body.
    pub fn trace(&self, o: [f32; 3], d: [f32; 3], only: Option<u8>) -> Option<ScreenHit> {
        let sub = |a: [f32; 3], b: [f32; 3]| [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
        let cross = |a: [f32; 3], b: [f32; 3]| [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
        let dot = |a: [f32; 3], b: [f32; 3]| a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
        let mut best: Option<(f32, usize, f32, f32)> = None;
        for (ti, (t, kind)) in self.tris.iter().enumerate() {
            if only.is_some_and(|s| s != *kind) {
                continue;
            }
            let (a, b, c) = (self.p[t[0] as usize], self.p[t[1] as usize], self.p[t[2] as usize]);
            let (e1, e2) = (sub(b, a), sub(c, a));
            let h = cross(d, e2);
            let det = dot(e1, h);
            if det.abs() < 1e-12 {
                continue;
            }
            let f = 1.0 / det;
            let s = sub(o, a);
            let u = f * dot(s, h);
            if !(-1e-4..=1.0001).contains(&u) {
                continue;
            }
            let q = cross(s, e1);
            let w = f * dot(d, q);
            if w < -1e-4 || u + w > 1.0001 {
                continue;
            }
            let tt = f * dot(e2, q);
            if tt > 0.0 && best.is_none_or(|b| tt < b.0) {
                best = Some((tt, ti, u, w));
            }
        }
        let (t, ti, u, w) = best?;
        let (tri, kind) = self.tris[ti];
        if kind == 0 {
            return None;
        }
        let (a, b, c) = (self.uv[tri[0] as usize], self.uv[tri[1] as usize], self.uv[tri[2] as usize]);
        let s = a[0] + (b[0] - a[0]) * u + (c[0] - a[0]) * w;
        let tv = a[1] + (b[1] - a[1]) * u + (c[1] - a[1]) * w;
        Some(ScreenHit { screen: kind, t, x: s, y: 1.0 - tv })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rigid_inverse_and_trs() {
        let m = trs([1.0, 2.0, 3.0], [0.9238795, 0.0, 0.3826834, 0.0], [1.0; 3]);
        let p = xform(xform([0.3, -0.2, 5.0], &m), &inv_rigid(&m));
        assert!((p[0] - 0.3).abs() < 1e-6 && (p[1] + 0.2).abs() < 1e-6 && (p[2] - 5.0).abs() < 1e-6, "{p:?}");
        // a quarter turn about z takes x to y (column-vector sense)
        let r = trs([0.0; 3], [std::f64::consts::FRAC_1_SQRT_2, 0.0, 0.0, std::f64::consts::FRAC_1_SQRT_2], [1.0; 3]);
        let q = xform([1.0, 0.0, 0.0], &r);
        assert!(q[0].abs() < 1e-9 && (q[1] - 1.0).abs() < 1e-9, "{q:?}");
    }

    #[test]
    fn trace_finds_screen_points() {
        // one inner-screen quad at z = 0 over [-1, 1]^2, a body triangle in front of its left part
        let hm = HitMesh {
            p: vec![[-1.0, -1.0, 0.0], [1.0, -1.0, 0.0], [1.0, 1.0, 0.0], [-1.0, 1.0, 0.0], [-1.0, -1.0, 1.0], [-0.5, -1.0, 1.0], [-1.0, 1.0, 1.0]],
            uv: vec![[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0], [0.0; 2], [0.0; 2], [0.0; 2]],
            tris: vec![([0, 1, 2], 1), ([0, 2, 3], 1), ([4, 5, 6], 0)],
        };
        let h = hm.trace([0.5, 0.5, 5.0], [0.0, 0.0, -1.0], None).unwrap();
        assert_eq!(h.screen, 1);
        assert!((h.x - 0.75).abs() < 1e-5 && (h.y - 0.25).abs() < 1e-5, "{h:?}");
        assert!(hm.trace([-0.9, 0.0, 5.0], [0.0, 0.0, -1.0], None).is_none());
        assert!(hm.trace([-0.9, 0.0, 5.0], [0.0, 0.0, -1.0], Some(1)).is_some());
    }

    /// The real model when this machine has it (extracted from Xcode.xip): screens found, the inner screen on z = 0
    /// when flat, the right half folded onto the left when closed, the outer screen on the left half's back
    #[test]
    fn duo_model_when_present() {
        let p = dir().join(DUO);
        if !p.exists() {
            eprintln!("no {}: skipped", p.display());
            return;
        }
        let m = load(&p).unwrap();
        assert!(m.mats.iter().any(|x| x.screen == 1) && m.mats.iter().any(|x| x.screen == 2));
        let flat = m.posed(&m.pose(180.0));
        let closed = m.posed(&m.pose(0.0));
        let inner: Vec<usize> = (0..m.v.len()).filter(|&i| m.mats[m.v[i].m as usize].screen == 1).collect();
        for &i in &inner {
            assert!(flat[i][2].abs() < 3.0, "inner screen off z = 0 when flat: {:?}", flat[i]);
        }
        // closed: the right half's inner-screen points lie over the left half (x < 0), above the screen plane
        let right: Vec<usize> = inner.iter().copied().filter(|&i| m.v[i].p[0] > 400.0).collect();
        assert!(!right.is_empty());
        for &i in &right {
            assert!(closed[i][0] < 0.0 && closed[i][2] > 0.0, "{:?} -> {:?}", m.v[i].p, closed[i]);
        }
        let outer: Vec<usize> = (0..m.v.len()).filter(|&i| m.mats[m.v[i].m as usize].screen == 2).collect();
        assert!(outer.iter().all(|&i| flat[i][0] < 0.0 && flat[i][2] < -50.0));
        // a ray straight at the flat inner screen's middle of the right half lands at x = 0.75
        let hm = m.hit_mesh(flat);
        let h = hm.trace([2853.0 / 4.0, 0.0, 5000.0], [0.0, 0.0, -1.0], None).unwrap();
        assert_eq!(h.screen, 1);
        assert!((h.x - 0.75).abs() < 0.01 && (h.y - 0.5).abs() < 0.01, "{h:?}");
        let web = m.web();
        assert_eq!(&web[..4], b"X86M");
        eprintln!("{} vertices, {} triangles, {} groups ({} opaque), {} materials, {} images, web {} bytes", m.v.len(), m.i.len() / 3, m.groups.len(), m.opaque, m.mats.len(), m.images.len(), web.len());
    }
}
