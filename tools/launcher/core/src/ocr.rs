//! Text in pixels: OCR of the phone's frames for content with no accessibility (Metal / OpenGL / SpriteKit views, game
//! engines, a canvas in a web page, images with text).
//!
//! The engine is pure Rust (ocrs on the rten runtime: no system library, nothing extra in the AppImage). Its two models
//! (text detection and line recognition, ~12 MB) are downloaded once into ~/.cache/x86sim/ocr and checked against
//! their SHA-256; without them (offline) OCR fails with a message that says what to fetch where.
//!
//! `read` takes an RGB picture and answers phrases: runs of words of one text line, split where a gap is wider than
//! the line is tall (two buttons side by side are two phrases), with their boxes in the picture's pixels.
use anyhow::{anyhow, bail, Context, Result};
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use std::sync::{Mutex, OnceLock};
use std::time::Instant;

/// (file, URL, SHA-256). X86SIM_OCR_MODELS_URL replaces the URLs' base (a mirror, a local server).
const MODELS: [(&str, &str, &str); 2] = [
    ("text-detection.onnx", "https://ocrs-models.s3-accelerate.amazonaws.com/text-detection.onnx", "a917b23dbd9524b465df7e922641b3ff2981623df4ded5a0234004ef2fee7cfe"),
    ("text-recognition.onnx", "https://ocrs-models.s3-accelerate.amazonaws.com/text-recognition.onnx", "86c145c2edb96c8caed5b1ebb8f44d706408922211451c309c625157dd6061c5"),
];

/// A run of words on one line, its box in the picture's pixels (x, y, width, height)
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Phrase {
    pub text: String,
    pub rect: [f64; 4],
}

/// Where the models live: $XDG_CACHE_HOME/x86sim/ocr, else ~/.cache/x86sim/ocr
pub fn models_dir() -> PathBuf {
    let base = std::env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .filter(|p| p.is_absolute())
        .unwrap_or_else(|| PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(".cache"));
    base.join("x86sim/ocr")
}

fn sha256_file(p: &Path) -> Result<String> {
    use sha2::Digest;
    let mut f = std::fs::File::open(p)?;
    let mut h = sha2::Sha256::new();
    std::io::copy(&mut f, &mut h)?;
    Ok(h.finalize().iter().map(|b| format!("{b:02x}")).collect())
}

/// The models on disk, downloaded (curl, as setup fetches everything else) and checked the first time
pub fn ensure_models() -> Result<Vec<PathBuf>> {
    let dir = models_dir();
    std::fs::create_dir_all(&dir).with_context(|| format!("creating {}", dir.display()))?;
    let base = std::env::var("X86SIM_OCR_MODELS_URL").ok().filter(|s| !s.is_empty());
    let mut out = Vec::new();
    for (name, url, sum) in MODELS {
        let p = dir.join(name);
        // checked once: a .ok marker next to it says this file had the right sum
        let ok = p.with_extension("onnx.ok");
        if p.exists() && ok.exists() {
            out.push(p);
            continue;
        }
        if !p.exists() || sha256_file(&p)? != sum {
            let url = match &base {
                Some(b) => format!("{}/{name}", b.trim_end_matches('/')),
                None => url.to_string(),
            };
            let part = p.with_extension("onnx.part");
            let st = std::process::Command::new("curl")
                .args(["-sSfL", "--retry", "2", "--connect-timeout", "10", "-o"])
                .arg(&part)
                .arg(&url)
                .status();
            if !matches!(st, Ok(s) if s.success()) {
                let _ = std::fs::remove_file(&part);
                bail!(
                    "OCR: could not download its model {name} from {url} (offline?). Fetch it once by hand into {} (SHA-256 {sum}), or set X86SIM_OCR_MODELS_URL to a mirror",
                    dir.display()
                );
            }
            let got = sha256_file(&part)?;
            if got != sum {
                let _ = std::fs::remove_file(&part);
                bail!("OCR: {name} from {url} has SHA-256 {got}, expected {sum}");
            }
            std::fs::rename(&part, &p)?;
        }
        let _ = std::fs::write(&ok, sum);
        out.push(p);
    }
    Ok(out)
}

struct Engine {
    eng: ocrs::OcrEngine,
    /// the detection model's input (height, width): larger pictures are read in tiles of that size
    tile: (usize, usize),
}

fn engine() -> Result<&'static Engine> {
    static E: OnceLock<std::result::Result<Engine, String>> = OnceLock::new();
    static INIT: Mutex<()> = Mutex::new(());
    if let Some(e) = E.get() {
        return e.as_ref().map_err(|s| anyhow!("{s}"));
    }
    let _g = INIT.lock().unwrap_or_else(|e| e.into_inner());
    let e = E.get_or_init(|| {
        let load = || -> Result<Engine> {
            let m = ensure_models()?;
            let det = rten::Model::load_file(&m[0]).with_context(|| format!("loading {}", m[0].display()))?;
            let rec = rten::Model::load_file(&m[1]).with_context(|| format!("loading {}", m[1].display()))?;
            let shape = det.input_ids().first().and_then(|&id| det.node_info(id)).and_then(|i| i.shape()).unwrap_or_default();
            let dim = |i: usize| match shape.get(i) {
                Some(rten::Dimension::Fixed(n)) => *n,
                _ => 0,
            };
            let tile = (dim(2), dim(3));
            let eng = ocrs::OcrEngine::new(ocrs::OcrEngineParams { detection_model: Some(det), recognition_model: Some(rec), ..Default::default() })?;
            Ok(Engine { eng, tile: if tile.0 >= 128 && tile.1 >= 128 { tile } else { (800, 600) } })
        };
        load().map_err(|e| format!("{e:#}"))
    });
    e.as_ref().map_err(|s| anyhow!("{s}"))
}

/// Loads the models now (a download the first time), so the first snapshot that needs OCR is not the slow one
pub fn warm() -> Result<()> {
    engine().map(|_| ())
}

fn crop(rgb: &[u8], w: usize, x0: usize, y0: usize, cw: usize, ch: usize) -> Vec<u8> {
    let mut out = Vec::with_capacity(cw * ch * 3);
    for y in y0..y0 + ch {
        out.extend_from_slice(&rgb[(y * w + x0) * 3..(y * w + x0 + cw) * 3]);
    }
    out
}

/// The detector's input width in pixels: a picture no wider is read in one column of tiles (no word cut sideways)
pub fn tile_width() -> usize {
    engine().map(|e| e.tile.1).unwrap_or(600)
}

/// Word boxes of the whole picture. The detector scales its input to a fixed size, which would shrink a phone's
/// 1206 x 2622 frame past reading small text: a larger picture is cut into tiles of that size, overlapping by a third.
/// A word touching a tile's inner edge is cut and left to the neighbour that holds it whole; of two boxes that overlap
/// (the same word seen by two tiles) the larger stays.
fn detect(e: &Engine, rgb: &[u8], w: usize, h: usize) -> Result<Vec<rten_imageproc::RotatedRect>> {
    let (th, tw) = e.tile;
    let input = |b: &[u8], w: usize, h: usize| -> Result<ocrs::OcrInput> {
        let src = ocrs::ImageSource::from_bytes(b, (w as u32, h as u32)).map_err(|e| anyhow!("OCR input: {e:?}"))?;
        Ok(e.eng.prepare_input(src)?)
    };
    if w <= tw && h <= th {
        return Ok(e.eng.detect_words(&input(rgb, w, h)?)?);
    }
    let starts = |n: usize, t: usize| -> Vec<usize> {
        if n <= t {
            return vec![0];
        }
        let step = t - t / 3;
        let mut v = Vec::new();
        let mut x = 0;
        while x + t < n {
            v.push(x);
            x += step;
        }
        v.push(n - t);
        v
    };
    let (xs, ys) = (starts(w, tw), starts(h, th));
    let (cw, ch) = (tw.min(w), th.min(h));
    let mut out: Vec<(rten_imageproc::RotatedRect, [f32; 4])> = Vec::new();
    for &y0 in &ys {
        for &x0 in &xs {
            for r in e.eng.detect_words(&input(&crop(rgb, w, x0, y0, cw, ch), cw, ch)?)? {
                let c = r.corners();
                let (mut bx0, mut by0, mut bx1, mut by1) = (f32::MAX, f32::MAX, f32::MIN, f32::MIN);
                for p in c {
                    bx0 = bx0.min(p.x);
                    by0 = by0.min(p.y);
                    bx1 = bx1.max(p.x);
                    by1 = by1.max(p.y);
                }
                // cut by an inner edge of the tile
                let m = 3.0;
                if (x0 > 0 && bx0 <= m) || (y0 > 0 && by0 <= m) || (x0 + cw < w && bx1 >= cw as f32 - m) || (y0 + ch < h && by1 >= ch as f32 - m) {
                    continue;
                }
                let (dx, dy) = (x0 as f32, y0 as f32);
                let bb = [bx0 + dx, by0 + dy, bx1 + dx, by1 + dy];
                let a = (bb[2] - bb[0]) * (bb[3] - bb[1]);
                let ov = |o: &[f32; 4]| {
                    let iw = (bb[2].min(o[2]) - bb[0].max(o[0])).max(0.0);
                    let ih = (bb[3].min(o[3]) - bb[1].max(o[1])).max(0.0);
                    iw * ih / a.min((o[2] - o[0]) * (o[3] - o[1])).max(1.0)
                };
                if let Some(i) = out.iter().position(|(_, o)| ov(o) > 0.3) {
                    let oa = (out[i].1[2] - out[i].1[0]) * (out[i].1[3] - out[i].1[1]);
                    if oa >= a {
                        continue;
                    }
                    out.remove(i);
                }
                let ctr = r.center();
                out.push((rten_imageproc::RotatedRect::new(rten_imageproc::PointF::from_yx(ctr.y + dy, ctr.x + dx), r.up_axis(), r.width(), r.height()), bb));
            }
        }
    }
    Ok(out.into_iter().map(|x| x.0).collect())
}

/// Reads the text of an RGB picture (w x h, 3 bytes a pixel). Answers phrases in reading order and the time it took.
pub fn read(rgb: &[u8], w: u32, h: u32) -> Result<(Vec<Phrase>, u64)> {
    use ocrs::TextItem;
    let t0 = Instant::now();
    let e = engine()?;
    let (wu, hu) = (w as usize, h as usize);
    anyhow::ensure!(rgb.len() >= wu * hu * 3 && wu > 0 && hu > 0, "OCR: picture size");
    let words = detect(e, rgb, wu, hu)?;
    let src = ocrs::ImageSource::from_bytes(rgb, (w, h)).map_err(|e| anyhow!("OCR input: {e:?}"))?;
    let input = e.eng.prepare_input(src)?;
    let lines = e.eng.find_text_lines(&input, &words);
    let rec = e.eng.recognize_text(&input, &lines)?;
    let mut out = Vec::new();
    for line in rec.into_iter().flatten() {
        let ws: Vec<(String, [f64; 4])> = line
            .words()
            .map(|wd| {
                let r = wd.bounding_rect();
                (wd.to_string(), [r.left() as f64, r.top() as f64, (r.right() - r.left()) as f64, (r.bottom() - r.top()) as f64])
            })
            .filter(|(t, _)| !t.trim().is_empty())
            .collect();
        out.extend(phrases(&ws));
    }
    Ok((out, t0.elapsed().as_millis() as u64))
}

/// Groups a line's words into phrases: a gap wider than the line's height (from the median word) starts a new one
pub fn phrases(ws: &[(String, [f64; 4])]) -> Vec<Phrase> {
    let mut out: Vec<Phrase> = Vec::new();
    if ws.is_empty() {
        return out;
    }
    let mut hs: Vec<f64> = ws.iter().map(|w| w.1[3]).collect();
    hs.sort_by(f64::total_cmp);
    let lh = hs[hs.len() / 2].max(1.0);
    let mut cur: Option<Phrase> = None;
    for (t, r) in ws {
        match cur.as_mut() {
            Some(p) if r[0] - (p.rect[0] + p.rect[2]) <= lh * 1.2 => {
                p.text.push(' ');
                p.text += t;
                let (x0, y0) = (p.rect[0].min(r[0]), p.rect[1].min(r[1]));
                let (x1, y1) = ((p.rect[0] + p.rect[2]).max(r[0] + r[2]), (p.rect[1] + p.rect[3]).max(r[1] + r[3]));
                p.rect = [x0, y0, x1 - x0, y1 - y0];
            }
            _ => {
                if let Some(p) = cur.take() {
                    out.push(p);
                }
                cur = Some(Phrase { text: t.clone(), rect: *r });
            }
        }
    }
    out.extend(cur);
    // noise: stray marks, and one letter alone (an icon's shape read as "S", "T"); a lone digit stays (a score)
    out.retain(|p| {
        let an: Vec<char> = p.text.chars().filter(|c| c.is_alphanumeric()).collect();
        an.len() > 1 || an.first().is_some_and(|c| c.is_ascii_digit())
    });
    out
}

// ---------------------------------------------------------------------------------------------------------------------
// In the snapshot

/// A view that draws its own pixels (simax `pixels`, or a web page's canvas), in screen points
#[derive(Debug, Clone)]
pub struct Region {
    pub frame: [f64; 4],
    pub layer: String,
    /// metal, opengl, spritekit, scenekit, canvas
    pub kind: String,
    pub class: String,
    pub app: String,
    pub pid: u32,
    pub window: String,
    pub rot: u32,
}

/// What OCR did for a snapshot
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct OcrInfo {
    /// the frame read (the frame ring's sequence number)
    pub frame: u64,
    /// how long reading the frame took (also when the answer came from the cache of that frame)
    pub ms: u64,
    /// the frame had been read already (an earlier snapshot of the same frame): nothing was read now
    #[serde(skip_serializing_if = "std::ops::Not::not", default)]
    pub cached: bool,
    /// the whole screen was read (snapshot ocr=true), else only views with no elements
    #[serde(skip_serializing_if = "std::ops::Not::not", default)]
    pub screen: bool,
    /// the views read: class and frame
    #[serde(skip_serializing_if = "Vec::is_empty", default)]
    pub views: Vec<String>,
    /// text elements added
    pub added: usize,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub error: Option<String>,
}

impl OcrInfo {
    pub fn line(&self) -> String {
        let what = if self.screen {
            "the whole screen".to_string()
        } else {
            format!("views with no elements ({})", self.views.join(", "))
        };
        let t = format!("{} ms{}", self.ms, if self.cached { ", cached" } else { "" });
        match &self.error {
            Some(e) => format!("ocr: could not read {what}: {e}\n"),
            None => format!("ocr: {} text(s) [ocr] read from the pixels of {what} (frame {}, {t})\n", self.added, self.frame),
        }
    }
}

/// OCR is on (X86SIM_OCR=0 turns it off; a Vision Pro has no flat screen to read)
pub fn enabled(inst: &crate::instance::Instance) -> bool {
    inst.platform != "xros" && std::env::var("X86SIM_OCR").map(|v| v != "0").unwrap_or(true)
}

/// A target worth reading the screen's pixels for when no element matches: text, or a ref a whole-screen OCR gave
pub fn worth_a_look(inst: &crate::instance::Instance, t: &crate::ax::Target) -> bool {
    enabled(inst)
        && match t {
            crate::ax::Target::Text(_) => true,
            crate::ax::Target::Ref(r) => crate::ax::ocr_refs(inst).contains(r),
            _ => false,
        }
}

/// Close enough for text read from pixels: the same after dropping what is not a letter or digit, or at most one
/// edit per six characters
pub fn near(label: &str, want: &str) -> bool {
    let a: Vec<char> = label.chars().filter(|c| c.is_alphanumeric()).flat_map(char::to_lowercase).collect();
    let b: Vec<char> = want.chars().filter(|c| c.is_alphanumeric()).flat_map(char::to_lowercase).collect();
    if b.len() < 3 {
        return !b.is_empty() && a == b;
    }
    let max = (b.len() / 6).max(1);
    if a.len().abs_diff(b.len()) > max {
        return false;
    }
    // Levenshtein
    let mut prev: Vec<usize> = (0..=b.len()).collect();
    for (i, ca) in a.iter().enumerate() {
        let mut cur = vec![i + 1; b.len() + 1];
        for (j, cb) in b.iter().enumerate() {
            cur[j + 1] = (prev[j] + (ca != cb) as usize).min(prev[j + 1] + 1).min(cur[j] + 1);
        }
        prev = cur;
    }
    prev[b.len()] <= max
}

fn area(f: &[f64; 4]) -> f64 {
    f[2].max(0.0) * f[3].max(0.0)
}

fn inside(f: &[f64; 4], p: (f64, f64)) -> bool {
    p.0 >= f[0] && p.0 < f[0] + f[2] && p.1 >= f[1] && p.1 < f[1] + f[3]
}

fn center(f: &[f64; 4]) -> (f64, f64) {
    (f[0] + f[2] / 2.0, f[1] + f[3] / 2.0)
}

/// Pixels per point the text is read at (X86SIM_OCR_PPP, default 1). Measured on phone screens (tests/ax/pixels_e2e.py):
/// one pixel a point reads menus, buttons and 11 pt status text best and fastest; 1.5 to 3 read icon shapes as letters
/// and take 2 to 6 times as long.
fn ppp(_width: f64) -> f64 {
    std::env::var("X86SIM_OCR_PPP").ok().and_then(|v| v.parse::<f64>().ok()).filter(|v| *v >= 0.5 && *v <= 4.0).unwrap_or(1.0)
}

/// A part of an RGB picture (x, y, w, h in its pixels) scaled by `k` (area average when shrinking)
pub fn resample(rgb: &[u8], w: usize, h: usize, r: [usize; 4], k: f64) -> (Vec<u8>, usize, usize) {
    let [x0, y0, cw, ch] = [r[0].min(w), r[1].min(h), r[2], r[3]];
    let (cw, ch) = (cw.min(w - x0), ch.min(h - y0));
    let (ow, oh) = (((cw as f64 * k).round() as usize).max(1), ((ch as f64 * k).round() as usize).max(1));
    let mut out = vec![0u8; ow * oh * 3];
    let (sx, sy) = (cw as f64 / ow as f64, ch as f64 / oh as f64);
    for yo in 0..oh {
        let (ya, yb) = ((yo as f64 * sy) as usize, (((yo + 1) as f64 * sy).ceil() as usize).min(ch).max((yo as f64 * sy) as usize + 1));
        for xo in 0..ow {
            let (xa, xb) = ((xo as f64 * sx) as usize, (((xo + 1) as f64 * sx).ceil() as usize).min(cw).max((xo as f64 * sx) as usize + 1));
            let mut acc = [0u32; 3];
            let mut n = 0u32;
            for y in ya..yb {
                let row = ((y0 + y) * w + x0) * 3;
                for x in xa..xb {
                    let o = row + x * 3;
                    acc[0] += rgb[o] as u32;
                    acc[1] += rgb[o + 1] as u32;
                    acc[2] += rgb[o + 2] as u32;
                    n += 1;
                }
            }
            let o = (yo * ow + xo) * 3;
            for c in 0..3 {
                out[o + c] = (acc[c] / n.max(1)) as u8;
            }
        }
    }
    (out, ow, oh)
}

/// Read results per frame: in memory (the MCP server) and in the device's state folder (one-shot CLI calls), only for
/// the newest frame read
#[derive(Serialize, Deserialize, Default)]
struct Cache {
    frame: String,
    /// part, its phrases, how long reading it took
    parts: Vec<(String, Vec<Phrase>, u64)>,
}

fn cache_path(inst: &crate::instance::Instance) -> PathBuf {
    inst.state_dir.join("ocr-cache.json")
}

/// A part's phrases, from the cache when that frame's part was read before: (phrases, from the cache, read ms)
fn cached(inst: &crate::instance::Instance, frame: &str, part: &str, read: impl FnOnce() -> Result<Vec<Phrase>>) -> Result<(Vec<Phrase>, bool, u64)> {
    static MEM: Mutex<Option<(PathBuf, Cache)>> = Mutex::new(None);
    let path = cache_path(inst);
    let look = |c: &Cache| (c.frame == frame).then(|| c.parts.iter().find(|p| p.0 == part).map(|p| (p.1.clone(), p.2))).flatten();
    if let Some((p, c)) = MEM.lock().unwrap_or_else(|e| e.into_inner()).as_ref() {
        if *p == path {
            if let Some((v, ms)) = look(c) {
                return Ok((v, true, ms));
            }
        }
    }
    let mut disk: Cache = std::fs::read(&path).ok().and_then(|b| serde_json::from_slice(&b).ok()).unwrap_or_default();
    if let Some((v, ms)) = look(&disk) {
        return Ok((v, true, ms));
    }
    let t0 = Instant::now();
    let v = read()?;
    let ms = t0.elapsed().as_millis() as u64;
    if disk.frame != frame {
        disk = Cache { frame: frame.to_string(), parts: Vec::new() };
    }
    disk.parts.push((part.to_string(), v.clone(), ms));
    let tmp = path.with_extension(format!("tmp.{}", std::process::id()));
    if std::fs::write(&tmp, serde_json::to_vec(&disk).unwrap_or_default()).is_ok() {
        let _ = std::fs::rename(&tmp, &path);
    }
    *MEM.lock().unwrap_or_else(|e| e.into_inner()) = Some((path, disk));
    Ok((v, false, ms))
}

/// Adds text read from the pixels to a snapshot: in each large view (a quarter of the screen or more) that draws its own
/// pixels and has no elements inside, and, with `whole`, the text of the whole screen that no element says already.
/// A web page's canvas elements (simax role `canvas`) become such views (one with an accessible name stays, as an
/// image). Errors (no models, offline) are reported in `snap.ocr`, never fail the snapshot.
pub fn augment(inst: &crate::instance::Instance, snap: &mut crate::ax::Snapshot, mut regions: Vec<Region>, whole: bool) {
    // canvases: views to read, not elements
    let mut i = 0;
    while i < snap.elements.len() {
        let e = &mut snap.elements[i];
        if e.role == "canvas" {
            if e.label.is_some() {
                e.role = "image".into();
            } else {
                let e = snap.elements.remove(i);
                regions.push(Region { frame: e.frame, layer: e.layer, kind: "canvas".into(), class: "canvas".into(), app: e.app, pid: e.pid, window: e.window, rot: e.rot });
                continue;
            }
        }
        i += 1;
    }
    if !enabled(inst) || snap.screen.0 <= 0.0 {
        return;
    }
    let scr = [0.0, 0.0, snap.screen.0, snap.screen.1];
    let clip = |f: &[f64; 4]| {
        let (x0, y0) = (f[0].max(0.0), f[1].max(0.0));
        let (x1, y1) = ((f[0] + f[2]).min(scr[2]), (f[1] + f[3]).min(scr[3]));
        [x0, y0, (x1 - x0).max(0.0), (y1 - y0).max(0.0)]
    };
    // large and empty: no element of its app has its center inside, but for ones covering it all (the view itself)
    let mut targets: Vec<Region> = Vec::new();
    for mut r in regions {
        r.frame = clip(&r.frame);
        if r.rot != snap.rot || area(&r.frame) < area(&scr) / 4.0 {
            continue;
        }
        let holds = snap.elements.iter().any(|e| e.app == r.app && e.layer != "status" && !e.offscreen && inside(&r.frame, center(&e.frame)) && area(&e.frame) < 0.8 * area(&r.frame));
        // nested views (an SKView in a Metal-backed container): the inner one
        if !holds && !targets.iter().any(|t| t.app == r.app && inside(&t.frame, center(&r.frame)) && area(&t.frame) <= area(&r.frame)) {
            targets.retain(|t| !(t.app == r.app && inside(&r.frame, center(&t.frame))));
            targets.push(r);
        }
    }
    if targets.is_empty() && !whole {
        return;
    }
    let mut info = OcrInfo { screen: whole, views: targets.iter().map(|t| format!("{} {:.0},{:.0} {:.0}x{:.0}", t.class, t.frame[0], t.frame[1], t.frame[2], t.frame[3])).collect(), ..Default::default() };
    let r = (|| -> Result<Vec<crate::ax::El>> {
        // the full-resolution picture, upright as the snapshot's points
        let (rgb, w, h, seq) = crate::ax::upright_frame(inst, snap.rot, 1)?;
        info.frame = seq;
        let (fx, fy) = (w as f64 / snap.screen.0, h as f64 / snap.screen.1);
        // a frame's number starts again at every boot: the boot is part of its name
        let frame = format!("{}#{}#{seq}", crate::ax::screen_ring(inst).display(), crate::ax::boot_id(inst));
        let (mut all_hit, mut read_ms) = (true, 0u64);
        // reads a part (screen points) and answers its phrases in screen points
        let mut part = |f: &[f64; 4]| -> Result<Vec<Phrase>> {
            let px = [(f[0] * fx) as usize, (f[1] * fy) as usize, (f[2] * fx).round() as usize, (f[3] * fy).round() as usize];
            let k = (ppp(f[2]) / fx).min(1.0);
            let key = format!("{},{},{},{}@{k:.3}", px[0], px[1], px[2], px[3]);
            let (ph, hit, ms) = cached(inst, &frame, &key, || {
                let (sub, sw, sh) = resample(&rgb, w, h, px, k);
                read(&sub, sw as u32, sh as u32).map(|r| r.0)
            })?;
            all_hit &= hit;
            read_ms += ms;
            let (sx, sy) = (px[2] as f64 / (px[2] as f64 * k).round().max(1.0) / fx, px[3] as f64 / (px[3] as f64 * k).round().max(1.0) / fy);
            Ok(ph
                .into_iter()
                .map(|p| Phrase { text: p.text, rect: [f[0] + p.rect[0] * sx, f[1] + p.rect[1] * sy, p.rect[2] * sx, p.rect[3] * sy] })
                .collect())
        };
        let mut out = Vec::new();
        // the status bar's text and icons are its elements already (an icon read as text is noise)
        let status: Vec<[f64; 4]> = snap.elements.iter().filter(|e| e.layer == "status").map(|e| e.frame).collect();
        let in_status = |p: &Phrase| status.iter().any(|f| inside(&[f[0] - 4.0, f[1] - 4.0, f[2] + 8.0, f[3] + 8.0], center(&p.rect)));
        let el = |p: &Phrase, app: &str, pid: u32, layer: &str, window: &str, rot: u32| {
            let (cx, cy) = center(&p.rect);
            let key = format!("ocr:{}@{},{}", p.text, (cx / 32.0) as i64, (cy / 32.0) as i64);
            // the boxes sit tight on the glyphs (descenders cut): a little room around them
            let (px, py) = (2.0, (p.rect[3] * 0.2).max(1.5));
            let rect = [p.rect[0] - px, p.rect[1] - py, p.rect[2] + 2.0 * px, p.rect[3] + 2.0 * py];
            crate::ax::El {
                role: "text".into(),
                label: Some(p.text.clone()),
                frame: rect.map(|v| (v * 10.0).round() / 10.0),
                enabled: true,
                app: app.into(),
                pid,
                layer: layer.into(),
                window: window.into(),
                oid: key.clone(),
                key: Some(key),
                rot,
                ocr: true,
                ..Default::default()
            }
        };
        if whole {
            for p in part(&scr)?.into_iter().filter(|p| !in_status(p)) {
                let c = center(&p.rect);
                if let Some(t) = targets.iter().find(|t| inside(&t.frame, c)) {
                    out.push(el(&p, &t.app, t.pid, &t.layer, &t.window, t.rot));
                    continue;
                }
                // already an element's text: inside a labelled element that is not a big container, or the label of
                // one near it
                let n = |s: &str| s.chars().filter(|c| c.is_alphanumeric()).flat_map(char::to_lowercase).collect::<String>();
                let pn = n(&p.text);
                let said = snap.elements.iter().any(|e| {
                    let l = n(e.label.as_deref().unwrap_or("")) + &n(e.value.as_deref().unwrap_or(""));
                    (inside(&e.frame, c) && !l.is_empty() && area(&e.frame) < area(&scr) / 4.0)
                        || (!pn.is_empty() && l.contains(&pn) && (center(&e.frame).0 - c.0).abs() < 60.0 && (center(&e.frame).1 - c.1).abs() < 40.0)
                });
                if said {
                    continue;
                }
                // whose it is: the smallest element around it, else the front app
                let owner = snap.elements.iter().filter(|e| !e.ocr && inside(&e.frame, c)).min_by(|a, b| area(&a.frame).total_cmp(&area(&b.frame)));
                match owner {
                    Some(o) => out.push(el(&p, &o.app.clone(), o.pid, &o.layer.clone(), &o.window.clone(), o.rot)),
                    None => {
                        let front = snap.front.first().cloned().unwrap_or_default();
                        let any = snap.elements.iter().find(|e| e.app == front);
                        let layer = any.map(|e| e.layer.clone()).unwrap_or_else(|| if front == "com.apple.springboard" { "home".into() } else { "app".into() });
                        out.push(el(&p, &front, any.map(|e| e.pid).unwrap_or(0), &layer, &any.map(|e| e.window.clone()).unwrap_or_default(), snap.rot));
                    }
                }
            }
        } else {
            for t in &targets {
                for p in part(&t.frame)?.into_iter().filter(|p| !in_status(p)) {
                    out.push(el(&p, &t.app, t.pid, &t.layer, &t.window, t.rot));
                }
            }
        }
        info.ms = read_ms;
        info.cached = all_hit;
        Ok(out)
    })();
    match r {
        Ok(els) => {
            info.added = els.len();
            snap.elements.extend(els);
        }
        Err(e) => info.error = Some(format!("{e:#}")),
    }
    snap.ocr = Some(info);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn splits_on_wide_gaps() {
        let w = |t: &str, x: f64| (t.to_string(), [x, 10.0, 40.0, 20.0]);
        let p = phrases(&[w("Start", 0.0), w("Game", 50.0), w("Quit", 200.0), w("·", 400.0), w("S", 500.0)]);
        assert_eq!(p.len(), 2);
        assert_eq!(p[0].text, "Start Game");
        assert_eq!(p[0].rect, [0.0, 10.0, 90.0, 20.0]);
        assert_eq!(p[1].text, "Quit");
    }

    #[test]
    fn near_text() {
        assert!(near("Start Gane", "start game"));
        assert!(near("Settings", "Settings!"));
        assert!(!near("Start", "Stop"));
        assert!(!near("ab", "ac"));
    }

    #[test]
    fn resample_halves() {
        let rgb: Vec<u8> = (0..4 * 4 * 3).map(|i| if (i / 3) % 2 == 0 { 0 } else { 200 }).collect();
        let (o, w, h) = resample(&rgb, 4, 4, [0, 0, 4, 4], 0.5);
        assert_eq!((w, h), (2, 2));
        assert_eq!(o[0], 100);
    }
}
