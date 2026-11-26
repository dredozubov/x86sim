//! Models 2: the iPhone Duo in 3D, as Xcode's DeviceHub shows its foldable (CoreDevicePopDeviceKitExtension draws
//! Apple's V68.usdz; that model is Apple's, so this one is built here, mesh.rs): two rounded halves on a hinge spine,
//! the inner screen one panel across both fronts and the outer screen on the back of the right half, each the
//! phone's live picture. The left half faces the viewer; the right half turns about the hinge by 180 - angle, so
//! closed it lies on the left half with the outer screen up. The device orientation turns the whole phone
//! (landscape: the left half becomes the base of a laptop pose). Drawn with OpenGL (gpu.rs) with a depth buffer.
mod gpu;
mod mesh;

use crate::viewer::{convert, Hit, Img, ScreenMap};
use eframe::egui;
use egui::{Rect, TextureId};
use mesh::{rot_x, rot_y, rot_z, v3, V3};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU32, AtomicU64, Ordering};
use std::sync::{Arc, Mutex, Weak};
use std::time::{Duration, Instant};
use x86sim_core::{instance::Instance, ring::Ring};

/// at most this many degrees a second the shown hinge moves towards the commanded angle (simhid moves it over 600 ms)
const SPEED: f64 = 300.0;
/// how fast the shown hinge closes on its target (per second): an eased follow, so a slider that sends a step every
/// 40 ms draws one smooth sweep instead of a dash and a stop per step
const HINGE_RATE: f64 = 14.0;
/// how fast the camera and the framing settle on where they should be (per second): both follow the hinge with
/// the same lag, so a hinge moved a degree at a time reads as one smooth move instead of a twitch per step
const SETTLE: f32 = 7.0;

fn epoch() -> Instant {
    static E: std::sync::OnceLock<Instant> = std::sync::OnceLock::new();
    *E.get_or_init(Instant::now)
}
fn now_ms() -> u64 {
    epoch().elapsed().as_millis() as u64
}

/// A screen's frames for a texture: a thread follows the ring while the picture was drawn in the last second.
struct Feed {
    ring: Mutex<PathBuf>,
    rot: u32,
    target_w: AtomicU32,
    seen_ms: AtomicU64,
    frame: Mutex<Option<Img>>,
    dirty: AtomicBool,
}

struct Screen {
    feed: Arc<Feed>,
    tex: Option<egui::TextureHandle>,
    name: String,
}

impl Screen {
    fn new(ring: &Path, rot: u32, name: String, ctx: egui::Context) -> Screen {
        let feed = Arc::new(Feed { ring: Mutex::new(ring.to_path_buf()), rot, target_w: AtomicU32::new(800), seen_ms: AtomicU64::new(now_ms()), frame: Mutex::new(None), dirty: AtomicBool::new(false) });
        let weak: Weak<Feed> = Arc::downgrade(&feed);
        let _ = std::thread::Builder::new().name(format!("duo3d {name}")).spawn(move || {
            let mut path = PathBuf::new();
            let mut ring: Option<Ring> = None;
            let mut last = (0u64, 0usize);
            loop {
                let Some(f) = weak.upgrade() else { return };
                if now_ms().saturating_sub(f.seen_ms.load(Ordering::Relaxed)) > 1000 {
                    drop(f);
                    std::thread::sleep(Duration::from_millis(300));
                    continue;
                }
                let want = f.ring.lock().unwrap().clone();
                if want != path || ring.is_none() {
                    ring = Some(Ring::new(&want));
                    path = want;
                    last = (0, 0);
                }
                let r = ring.as_mut().unwrap();
                let seq = r.seq();
                if seq != 0 {
                    if let Some(fr) = r.latest() {
                        let src_w = if f.rot % 180 == 90 { fr.h } else { fr.w } as usize;
                        let step = (src_w / f.target_w.load(Ordering::Relaxed).max(8) as usize).max(1);
                        if (fr.seq, step) != last {
                            let img = convert(&fr, step, f.rot, true);
                            *f.frame.lock().unwrap() = Some(img);
                            f.dirty.store(true, Ordering::Release);
                            ctx.request_repaint();
                            last = (fr.seq, step);
                        }
                    }
                }
                drop(f);
                if seq == 0 {
                    std::thread::sleep(Duration::from_millis(500));
                } else {
                    r.wait(seq, Duration::from_millis(500));
                }
            }
        });
        Screen { feed, tex: None, name }
    }

    /// The texture of the latest frame, uploaded if new; `w`: the width it is drawn at (physical pixels)
    fn texture(&mut self, ctx: &egui::Context, ring: &Path, w: f32) -> Option<TextureId> {
        let f = &self.feed;
        f.seen_ms.store(now_ms(), Ordering::Relaxed);
        f.target_w.store(w.max(64.0) as u32, Ordering::Relaxed);
        {
            let mut r = f.ring.lock().unwrap();
            if r.as_path() != ring {
                *r = ring.to_path_buf();
                self.tex = None;
            }
        }
        if f.dirty.swap(false, Ordering::AcqRel) {
            if let Some(img) = f.frame.lock().unwrap().take() {
                let ci = egui::ColorImage { size: [img.w, img.h], source_size: egui::vec2(img.w as f32, img.h as f32), pixels: img.pixels };
                match &mut self.tex {
                    Some(t) => t.set(ci, egui::TextureOptions::LINEAR),
                    None => self.tex = Some(ctx.load_texture(format!("duo3d-{}", self.name), ci, egui::TextureOptions::LINEAR)),
                }
            }
        }
        self.tex.as_ref().map(|t| t.id())
    }
}

/// The phone's poses and camera; one per two-screen phone
pub struct Duo3d {
    inner: Screen,
    outer: Screen,
    /// the hinge angle drawn (degrees), moving towards the commanded one
    shown: f64,
    last_t: f64,
    /// the angle the hinge panel last sent and when (the hinge file only changes at a move's start and end)
    pub commanded: Option<(f64, f64)>,
    /// the orientation a pose chosen here holds the phone in, and when: drawn at once, before simhid reports it
    commanded_orient: Option<(String, f64)>,
    /// the device orientation the phone is placed in (portrait / landscape / upside down; a face up or down report
    /// keeps the last one, as the screens' pictures do)
    orient: String,
    /// how far the drawn placement (roll, tilt) still is from the orientation's: it eases to nothing after a turn,
    /// so the phone turns into a new orientation instead of jumping there
    place_off: (f32, f32),
    /// the camera (yaw, pitch; radians) drawn, easing towards the default view of the pose
    cam: Option<(f32, f32)>,
    /// the framing (scale before zoom, picture centre, view-space centre) drawn, easing towards the phone's
    /// outline at the shown angle at the camera's pace, and when it was last moved
    fit: Option<(f32, egui::Pos2, V3)>,
    fit_t: f64,
    /// what a drag turned the view by on top of the default view (radians); a double click resets it
    orbit: (f32, f32),
    /// the scroll wheel's zoom (1: the phone fits the area), and the one drawn: the wheel moves both, a reset only the
    /// first (the drawn one eases back)
    zoom: f32,
    zoom_shown: f32,
    gl: gpu::Target,
    /// the main view's projection, as last drawn (touches are traced back through it)
    proj: Option<Proj>,
}

/// How the main view was drawn: enough to trace a pointer position back into the model
#[derive(Clone, Copy)]
struct Proj {
    yaw: f32,
    pitch: f32,
    roll: f32,
    tilt: f32,
    phi: f32,
    c: V3,
    dist: f32,
    s: f32,
    off: egui::Pos2,
}

impl Proj {
    /// The ray under the pointer at `p`, in model space: origin and direction
    fn ray(&self, p: egui::Pos2) -> (V3, V3) {
        let q = ((p.x - self.off.x) / self.s, -(p.y - self.off.y) / self.s);
        let unview = |v: V3| rot_z(rot_x(rot_y(rot_x(v, -self.pitch), -self.yaw), -self.tilt), -self.roll);
        let o = unview(v3(0.0, 0.0, self.dist).add(self.c));
        let d = unview(v3(q.0, q.1, -self.dist));
        (o, d)
    }
}

impl Duo3d {
    pub fn new(inst: &Instance, ctx: egui::Context) -> Option<Duo3d> {
        let d = inst.inner.as_ref()?;
        Some(Duo3d {
            inner: Screen::new(&d.ring, d.rotation, format!("{}-inner", inst.id), ctx.clone()),
            outer: Screen::new(&inst.ring, 0, format!("{}-outer", inst.id), ctx),
            shown: inst.hinge().unwrap_or(0.0),
            last_t: f64::NAN,
            commanded: None,
            commanded_orient: None,
            orient: String::new(),
            place_off: (0.0, 0.0),
            cam: None,
            fit: None,
            fit_t: f64::NAN,
            orbit: (0.0, 0.0),
            zoom: 1.0,
            zoom_shown: 1.0,
            gl: Default::default(),
            proj: None,
        })
    }

    /// Moves the drawn hinge towards the commanded angle (the panel's while it moves the hinge, else simhid's file)
    /// and the camera towards the pose's view; once a frame (a second call in the same frame moves nothing).
    /// Returns whether it is bent: not closed, not flat.
    pub fn update(&mut self, inst: &Instance, now: f64, ctx: &egui::Context) -> bool {
        let file = pose_override().map(|p| p.0).unwrap_or_else(|| inst.hinge().unwrap_or(0.0));
        // the panel's angle while it moves the hinge and until simhid's file has caught up with it (the file is
        // whole degrees and is written as a move ends: switching to it early drew the hinge back, then on again)
        let target = match self.commanded {
            Some((v, t)) if now - t < 1.0 || ((file - v).abs() > 1.5 && now - t < 3.0) => v,
            _ => file,
        };
        let dt = if self.last_t.is_nan() { 0.0 } else { (now - self.last_t).clamp(0.0, 0.1) };
        if self.last_t.is_nan() {
            self.shown = target;
        }
        self.last_t = now;
        let d = target - self.shown;
        let step = (d * (1.0 - (-dt * HINGE_RATE).exp())).clamp(-SPEED * dt, SPEED * dt);
        self.shown = if d.abs() < 0.05 { target } else { self.shown + step };
        if self.shown != target {
            ctx.request_repaint();
        }
        let phi = ((180.0 - self.shown) as f32).to_radians();
        // the orientation: a pose's from here at once, else simhid's. A new one turns the phone over from where it is
        // drawn and drops a view turned or zoomed by hand (it was relative to how the phone was held).
        let o = match &self.commanded_orient {
            Some((o, t)) if now - t < 1.5 => o.clone(),
            _ => orientation(inst),
        };
        if roll_known(&o) && o != self.orient {
            if !self.orient.is_empty() {
                let (a, b) = (placement(&self.orient, phi), placement(&o, phi));
                self.place_off = (wrap(self.place_off.0 + a.0 - b.0), self.place_off.1 + a.1 - b.1);
                self.reset_view();
            }
            self.orient = o;
        }
        if self.place_off != (0.0, 0.0) {
            let k = (-(dt as f32) * SETTLE).exp();
            self.place_off = (self.place_off.0 * k, self.place_off.1 * k);
            if self.place_off.0.abs() + self.place_off.1.abs() < 0.001 {
                self.place_off = (0.0, 0.0);
            }
            ctx.request_repaint();
        }
        // the camera eases to the pose's view (the screen swap turns it from the inner to the outer screen)
        let want = Self::default_view(&self.orient, self.shown, phi);
        let cam = match self.cam {
            Some((y, p)) if dt > 0.0 => {
                let k = 1.0 - (-(dt as f32) * SETTLE).exp();
                let (dy, dp) = (wrap(want.0 - y), want.1 - p);
                if dy.abs() + dp.abs() > 0.002 {
                    ctx.request_repaint();
                }
                (y + dy * k, p + dp * k)
            }
            Some(c) => c,
            None => want,
        };
        self.cam = Some(cam);
        if self.zoom_shown != self.zoom {
            let k = 1.0 - (-(dt as f32) * SETTLE).exp();
            self.zoom_shown += (self.zoom - self.zoom_shown) * k;
            if (self.zoom_shown - self.zoom).abs() < self.zoom * 0.001 {
                self.zoom_shown = self.zoom;
            }
            ctx.request_repaint();
        }
        self.bent()
    }

    /// A pose chosen in the hinge panel (`HINGE_POSES`): drawn moving there at once, its orientation too, and the
    /// view settles on the pose's default (a turn or zoom by hand is dropped)
    pub fn pose(&mut self, angle: f64, orientation: Option<&str>, now: f64) {
        self.commanded = Some((angle, now));
        if let Some(o) = orientation {
            self.commanded_orient = Some((o.to_string(), now));
        }
        self.reset_view();
    }

    /// Back to the pose's default view: no turn or zoom by hand. The turn is handed to the camera, which eases from
    /// where it is drawn to the default view, and the zoom eases back: no jump.
    pub fn reset_view(&mut self) {
        if let Some((y, p)) = self.cam {
            self.cam = Some((wrap(y + self.orbit.0), (p + self.orbit.1).clamp(-1.5, 1.5)));
        }
        self.orbit = (0.0, 0.0);
        self.zoom = 1.0;
    }

    pub fn bent(&self) -> bool {
        self.shown > 0.5 && self.shown < 179.5
    }

    /// The default camera (turntable yaw about the vertical, then elevation) at hinge angle `deg` (the right half
    /// turned by `phi`): a function of the angle alone, so a hinge moved by the slider or a pose is followed in one
    /// smooth move (it once turned to whichever screen was lit, and SpringBoard lights the other one a couple of
    /// seconds after the hinge passes its swap angle: the view ended facing the shut inner side, then swung round).
    /// It faces the inner screen when open and the outer one when folded, blended up to SpringBoard's swap angle
    /// (85 degrees; `inner_weight`). Held in portrait, the inner screen is seen along the bisector of the two halves
    /// (an open book; straight on when flat), the outer one on the right half's back straight on, then from a little
    /// to the right and above so the fold reads as 3D. In landscape the phone sits on the table on its lower half
    /// (`placement`), seen from the front and above as a laptop is: low for the inner screen, high for the outer
    /// one lying face up.
    fn default_view(orient: &str, deg: f64, phi: f32) -> (f32, f32) {
        let w = inner_weight(deg);
        let k = phi.sin().max(0.0);
        if matches!(orient, "landscapeLeft" | "landscapeRight") {
            let elev = 70.0 + (28.0 - 70.0) * w;
            // a positive pitch tips the top of the scene towards the camera: seen from above
            return ((-12f32 * k).to_radians(), elev.to_radians());
        }
        // the inner screen's bisector turns by -phi/2, the outer screen's normal by pi - phi: the way between them
        // goes round the right half's edge (never through the phone)
        let yaw_in = -phi / 2.0;
        let y = yaw_in + (1.0 - w) * (std::f32::consts::PI - phi / 2.0);
        let n = rot_z(v3(y.sin(), 0.0, y.cos()), roll_of(orient));
        let yaw = n.x.atan2(n.z);
        let r = (n.x * n.x + n.z * n.z).sqrt();
        let pitch = n.y.atan2(r);
        let (dy, dp) = (-14f32, 10f32);
        // flat or closed it faces the screen straight on, as the flat view did (touches land true); the more it is
        // bent, the more it turns to show the fold
        (yaw + (dy * k).to_radians(), (pitch + (dp * k).to_radians()).clamp(-1.5, 1.5))
    }

    /// Paints the phone into `rect`. Turning it: a drag with the right or middle button, or with Alt held; zooming:
    /// the scroll wheel (or a pinch) with the right or middle button down, or Alt; a double right click (or an Alt
    /// double click) resets both. Otherwise the left button and the wheel are the phone's (the caller passes the
    /// response to the viewer with `screen_map`). Returns the response of the area.
    pub fn paint(&mut self, ui: &mut egui::Ui, rect: Rect, inst: &Instance) -> egui::Response {
        let resp = ui.interact(rect, ui.id().with("duo3d"), egui::Sense::click_and_drag());
        let orient = if self.orient.is_empty() { orientation(inst) } else { self.orient.clone() };
        let phi = ((180.0 - self.shown) as f32).to_radians();
        let moving = ui.input(|i| i.modifiers.alt || i.pointer.secondary_down() || i.pointer.middle_down());
        {
            let other = resp.dragged_by(egui::PointerButton::Secondary) || resp.dragged_by(egui::PointerButton::Middle);
            // a double right click resets the view in either mode (a double left click is the phone's while it is used)
            if resp.double_clicked_by(egui::PointerButton::Secondary) || (moving && resp.double_clicked()) {
                self.reset_view();
            } else if other || (moving && resp.dragged_by(egui::PointerButton::Primary)) {
                // the phone turns the way it is dragged, as if held by the pointer
                let d = resp.drag_delta();
                self.orbit = (self.orbit.0 - d.x * 0.008, self.orbit.1 + d.y * 0.008);
            }
            if moving && resp.hovered() {
                let (scroll, pinch) = ui.input(|i| (i.smooth_scroll_delta.y, i.zoom_delta()));
                let z = self.zoom * (scroll * 0.002).exp() * pinch;
                if z != self.zoom {
                    self.zoom = z.clamp(0.4, 5.0);
                    self.zoom_shown = self.zoom;
                }
            }
        }
        let (cy, cp) = self.cam.unwrap_or_else(|| Self::default_view(&orient, self.shown, phi));
        let (yaw, pitch) = (cy + self.orbit.0, (cp + self.orbit.1).clamp(-1.5, 1.5));
        let (roll, tilt) = placement(&orient, phi);
        let (roll, tilt) = (roll + self.place_off.0, tilt + self.place_off.1);
        let view = |p: V3| rot_x(rot_y(rot_x(rot_z(p, roll), tilt), yaw), pitch);
        let ppp = ui.ctx().pixels_per_point();
        let inner_ring = inst.inner.as_ref().map(|d| d.ring.clone()).unwrap_or_default();
        let inner = self.inner.texture(ui.ctx(), &inner_ring, rect.width() * ppp * 2.0 * self.zoom_shown);
        let outer = self.outer.texture(ui.ctx(), &inst.ring, rect.width() * ppp * 1.2 * self.zoom_shown);
        let m = mesh::build(self.shown as f32);
        let size = 2.0 * mesh::half_w() + mesh::half_h();
        // a longer lens than a wide one, as products are photographed
        let dist = 2.4 * size;
        // the view-space box's centre is the middle of the picture; the projected box fits the area
        let mut lo = v3(f32::MAX, f32::MAX, f32::MAX);
        let mut hi = v3(f32::MIN, f32::MIN, f32::MIN);
        for v in &m.v {
            let p = view(v3(v.p[0], v.p[1], v.p[2]));
            lo = v3(lo.x.min(p.x), lo.y.min(p.y), lo.z.min(p.z));
            hi = v3(hi.x.max(p.x), hi.y.max(p.y), hi.z.max(p.z));
        }
        let c = lo.add(hi).scale(0.5);
        let mut bb = Rect::NOTHING;
        for v in &m.v {
            let q = view(v3(v.p[0], v.p[1], v.p[2])).sub(c);
            let k = dist / (dist - q.z).max(1.0);
            bb.extend_with(egui::pos2(q.x * k, -q.y * k));
        }
        let s0 = (rect.width() / bb.width().max(1.0)).min(rect.height() / bb.height().max(1.0)) * 0.9;
        // the framing eases there at the camera's pace (snapping to it while the camera eased was the twitch)
        let now = ui.input(|i| i.time);
        let want = (s0, bb.center(), c);
        let fit = match self.fit {
            Some((fs, fb, fc)) if now > self.fit_t => {
                let k = 1.0 - (-((now - self.fit_t).min(0.1) as f32) * SETTLE).exp();
                let l = |a: f32, b: f32| a + (b - a) * k;
                let next = (l(fs, want.0), egui::pos2(l(fb.x, want.1.x), l(fb.y, want.1.y)), v3(l(fc.x, want.2.x), l(fc.y, want.2.y), l(fc.z, want.2.z)));
                if (next.0 - want.0).abs() > want.0 * 0.001 || (next.1 - want.1).length() > 0.5 {
                    ui.ctx().request_repaint();
                }
                next
            }
            Some(f) => f,
            None => want,
        };
        self.fit = Some(fit);
        self.fit_t = now;
        let (s0, bbc, c) = fit;
        let s = s0 * self.zoom_shown;
        let off = rect.center() - bbc.to_vec2() * s;
        let bb = Rect::from_center_size(bbc, bb.size());
        let (hw, hh) = (rect.width() / 2.0, rect.height() / 2.0);
        let col = |e: V3| view(e);
        let (ex, ey, ez) = (col(v3(1.0, 0.0, 0.0)), col(v3(0.0, 1.0, 0.0)), col(v3(0.0, 0.0, 1.0)));
        let frame = gpu::Frame {
            mesh: m,
            rot: [ex.x, ex.y, ex.z, ey.x, ey.y, ey.z, ez.x, ez.y, ez.z],
            centre: [c.x, c.y, c.z],
            fit: [s / hw, s / hh, (off.x - rect.center().x) / hw, -(off.y - rect.center().y) / hh],
            dnf: [dist, (dist - size).max(1.0), dist + size],
            inner,
            outer,
        };
        // a soft shadow on the floor under the phone: stacked ellipses, faint at the rim and denser in the middle
        let base = egui::pos2(off.x + bb.center().x * s, off.y + bb.max.y * s);
        let w = bb.width() * s * 0.46;
        let painter = ui.painter_at(rect);
        for i in 0..10 {
            let k = 1.0 - i as f32 / 10.0;
            painter.add(egui::Shape::ellipse_filled(base + egui::vec2(0.0, 6.0), egui::vec2(w * (0.55 + 0.5 * k), w * 0.07 * (0.6 + 0.6 * k)), egui::Color32::from_black_alpha(14)));
        }
        ui.painter().add(egui::PaintCallback { rect, callback: Arc::new(self.gl.callback(frame)) });
        self.proj = Some(Proj { yaw, pitch, roll, tilt, phi, c, dist, s, off });
        resp.on_hover_cursor(if moving { egui::CursorIcon::Grab } else { egui::CursorIcon::PointingHand })
    }

    /// The main view's screens for touches (viewer::ScreenMap), as last drawn
    pub fn screen_map(&self, inst: &Instance) -> Option<DuoMap> {
        let d = inst.inner.as_ref()?;
        Some(DuoMap { proj: self.proj?, inner: (d.upright(), (d.id, d.rotation)), outer: inst.screen })
    }
}

/// The 3D model's screens: a pointer position is traced into the model and onto the nearest screen facing it that
/// the other half does not hide. Surfaces: 1 the inner screen's left half, 2 its right half, 3 the outer screen.
pub struct DuoMap {
    proj: Proj,
    /// the inner screen's upright size and its display (SFB id, panel turn); the outer screen's size
    inner: ((u32, u32), (u32, u32)),
    outer: (u32, u32),
}

/// Where a ray meets the plane z = `z` of a half's own space: (t, x, y)
fn plane(o: V3, d: V3, z: f32) -> Option<(f32, f32, f32)> {
    if d.z.abs() < 1e-6 {
        return None;
    }
    let t = (z - o.z) / d.z;
    Some((t, o.x + d.x * t, o.y + d.y * t))
}

/// Where a ray enters a box (a half's own space: [0, w] x [-h/2, h/2] x [-THICK, 0])
fn enters_box(o: V3, d: V3) -> Option<f32> {
    let (w, h) = (mesh::half_w(), mesh::half_h());
    let (mut t0, mut t1) = (f32::MIN, f32::MAX);
    for (oo, dd, lo, hi) in [(o.x, d.x, 0.0, w), (o.y, d.y, -h / 2.0, h / 2.0), (o.z, d.z, -mesh::THICK, 0.0)] {
        if dd.abs() < 1e-9 {
            if oo < lo || oo > hi {
                return None;
            }
            continue;
        }
        let (a, b) = ((lo - oo) / dd, (hi - oo) / dd);
        t0 = t0.max(a.min(b));
        t1 = t1.min(a.max(b));
    }
    (t0 <= t1 && t1 > 0.0).then_some(t0)
}

impl DuoMap {
    /// The ray in each half's own space: the left half mirrored, the right half turned back
    fn rays(&self, p: egui::Pos2) -> [(V3, V3); 2] {
        let (o, d) = self.proj.ray(p);
        let mirror = |v: V3| v3(-v.x, v.y, v.z);
        let back = |v: V3| rot_y(v, -self.proj.phi);
        [(mirror(o), mirror(d)), (back(o), back(d))]
    }

    /// Surface `surface`'s plane under `p`: (t, normalised x, y on its picture), unclamped
    fn on(&self, p: egui::Pos2, surface: u8) -> Option<(f32, f32, f32)> {
        let rays = self.rays(p);
        let (sw, sh) = mesh::INNER;
        let (ow, oh) = mesh::OUTER;
        match surface {
            1 => plane(rays[0].0, rays[0].1, 0.0).map(|(t, x, y)| (t, (sw / 2.0 - x) / sw, (sh / 2.0 - y) / sh)),
            2 => plane(rays[1].0, rays[1].1, 0.0).map(|(t, x, y)| (t, (x + sw / 2.0) / sw, (sh / 2.0 - y) / sh)),
            _ => {
                let ox1 = mesh::half_w() / 2.0 + ow / 2.0;
                plane(rays[1].0, rays[1].1, -mesh::THICK).map(|(t, x, y)| (t, (ox1 - x) / ow, (oh / 2.0 - y) / oh))
            }
        }
    }

    fn hit_of(&self, surface: u8, x: f32, y: f32) -> Hit {
        let (size, target) = if surface == 3 { (self.outer, (None, 0)) } else { (self.inner.0, (Some(self.inner.1), 0)) };
        Hit { x, y, size, target: Some(target), surface }
    }
}

impl ScreenMap for DuoMap {
    fn hit(&self, p: egui::Pos2) -> Option<Hit> {
        let rays = self.rays(p);
        let mut best: Option<(f32, Hit)> = None;
        for surface in 1..=3u8 {
            let half = if surface == 1 { 0 } else { 1 };
            let (_, d) = rays[half];
            // the screen faces the ray: the inner screen +z, the outer -z (each half's own space)
            let facing = if surface == 3 { d.z > 0.0 } else { d.z < 0.0 };
            let Some((t, x, y)) = self.on(p, surface).filter(|_| facing) else { continue };
            let inside = match surface {
                1 => (0.0..=0.5).contains(&x),
                2 => (0.5..=1.0).contains(&x),
                _ => (0.0..=1.0).contains(&x),
            } && (0.0..=1.0).contains(&y);
            if !inside || t <= 0.0 {
                continue;
            }
            // the other half in front of it hides it
            let (oo, od) = rays[1 - half];
            if enters_box(oo, od).is_some_and(|t2| t2 < t - 1.0) {
                continue;
            }
            if best.as_ref().is_none_or(|(bt, _)| t < *bt) {
                best = Some((t, self.hit_of(surface, x, y)));
            }
        }
        best.map(|(_, h)| h)
    }

    fn follow(&self, p: egui::Pos2, of: &Hit) -> (f32, f32) {
        // across the crease a drag on the inner screen carries on on the other half
        if of.surface != 3 {
            for s in [of.surface, 3 - of.surface] {
                if let Some((t, x, y)) = self.on(p, s) {
                    let mine = if s == 1 { x <= 0.5 } else { x >= 0.5 };
                    if t > 0.0 && mine {
                        return (x, y);
                    }
                }
            }
        }
        self.on(p, of.surface).map(|(_, x, y)| (x, y)).unwrap_or((of.x, of.y))
    }

    fn span(&self, of: &Hit) -> (f32, f32) {
        let (w, h) = if of.surface == 3 { mesh::OUTER } else { mesh::INNER };
        (w * self.proj.s, h * self.proj.s)
    }
}

/// Scripted screenshots: X86SIM_DUO3D_POSE="<degrees>[,<orientation>]" draws the model in that pose whatever the
/// phone's (its screens stay live; touches still go to the phone as it really is)
fn pose_override() -> Option<(f64, Option<String>)> {
    static P: std::sync::OnceLock<Option<(f64, Option<String>)>> = std::sync::OnceLock::new();
    P.get_or_init(|| {
        let v = std::env::var("X86SIM_DUO3D_POSE").ok()?;
        let mut it = v.split(',');
        let deg = it.next()?.trim().parse().ok()?;
        Some((deg, it.next().map(|o| o.trim().to_string())))
    })
    .clone()
}

/// The device orientation the model is drawn in (simhid's, or the screenshot override's)
fn orientation(inst: &Instance) -> String {
    pose_override().and_then(|p| p.1).or_else(|| inst.orientation()).unwrap_or_default()
}

/// How the phone sits in the scene: turned by the device orientation about the view axis (roll), then, in
/// landscape, tipped about the horizontal (tilt) so its lower half lies flat on the table (its front up), the other
/// half standing at the hinge's angle as a laptop's lid. Landscape left puts the left half at the bottom, landscape
/// right the right half (which turns with the hinge: phi).
fn placement(orient: &str, phi: f32) -> (f32, f32) {
    let roll = roll_of(orient);
    let tilt = match orient {
        "landscapeLeft" => -std::f32::consts::FRAC_PI_2,
        "landscapeRight" => phi - std::f32::consts::FRAC_PI_2,
        _ => 0.0,
    };
    (roll, tilt)
}

/// How much the default view faces the inner screen at hinge angle `deg`: 0 folded, 1 open. It eases over from 55
/// up to SpringBoard's swap angle (85 degrees), so the inner screen is faced straight from where it is in use (a
/// half open book at 90 is seen as one)
fn inner_weight(deg: f64) -> f32 {
    let t = ((deg as f32 - 55.0) / 30.0).clamp(0.0, 1.0);
    t * t * (3.0 - 2.0 * t)
}

/// An angle brought into -pi..pi (the short way round)
fn wrap(a: f32) -> f32 {
    (a + std::f32::consts::PI).rem_euclid(std::f32::consts::TAU) - std::f32::consts::PI
}

/// Whether the orientation says how the phone is held upright (face up / down and unknown do not)
fn roll_known(orient: &str) -> bool {
    matches!(orient, "portrait" | "portraitUpsideDown" | "landscapeLeft" | "landscapeRight")
}

/// How far the device orientation turns the phone about the view axis
fn roll_of(orient: &str) -> f32 {
    match orient {
        "landscapeLeft" => 90f32.to_radians(),
        "landscapeRight" => -90f32.to_radians(),
        "portraitUpsideDown" => std::f32::consts::PI,
        _ => 0.0,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The default view follows the hinge without a jump anywhere from flat to closed (a degree of hinge never turns
    /// it by more than a few degrees), facing the inner screen straight on when flat and the outer one when closed
    #[test]
    fn default_view_is_smooth() {
        for orient in ["portrait", "portraitUpsideDown", "landscapeLeft", "landscapeRight"] {
            let view = |deg: f64| Duo3d::default_view(orient, deg, ((180.0 - deg) as f32).to_radians());
            let mut last = view(180.0);
            for i in (0..1800).rev() {
                let v = view(i as f64 / 10.0);
                let d = wrap(v.0 - last.0).abs() + (v.1 - last.1).abs();
                assert!(d < 1f32.to_radians(), "{orient} at {}: {last:?} -> {v:?}", i as f64 / 10.0);
                last = v;
            }
        }
        for deg in [0.0, 180.0] {
            let (yaw, pitch) = Duo3d::default_view("portrait", deg, ((180.0 - deg) as f32).to_radians());
            assert!(yaw.abs() < 1e-4 && pitch.abs() < 1e-4, "{deg}: {yaw} {pitch}");
        }
    }

    /// A turn between any two held orientations eases the short way round (never more than half a turn of roll), and
    /// face up / down reports do not count as one (the phone stays as it was placed)
    #[test]
    fn orientation_turns_short_way() {
        let all = ["portrait", "landscapeLeft", "portraitUpsideDown", "landscapeRight"];
        for a in all {
            for b in all {
                let phi = 90f32.to_radians();
                let (pa, pb) = (placement(a, phi), placement(b, phi));
                let off = wrap(pa.0 - pb.0);
                assert!(off.abs() <= std::f32::consts::PI + 1e-4, "{a} -> {b}: {off}");
                // eased to nothing, the drawn roll is the new orientation's
                let r = pb.0 + off;
                assert!((r.sin() - pa.0.sin()).abs() < 1e-4 && (r.cos() - pa.0.cos()).abs() < 1e-4, "{a} -> {b}");
            }
        }
        assert!(!roll_known("faceUp") && !roll_known("faceDown") && !roll_known("unknown") && !roll_known(""));
    }

    /// In landscape the lower half's front faces straight up, whatever the hinge angle (a laptop's base on the table)
    #[test]
    fn landscape_base_lies_flat() {
        for deg in [30.0f32, 90.0, 120.0, 170.0] {
            let phi = (180.0 - deg).to_radians();
            for (orient, base) in [("landscapeLeft", v3(0.0, 0.0, 1.0)), ("landscapeRight", rot_y(v3(0.0, 0.0, 1.0), phi))] {
                let (roll, tilt) = placement(orient, phi);
                let n = rot_x(rot_z(base, roll), tilt);
                assert!((n.y - 1.0).abs() < 1e-4, "{orient} at {deg}: {n:?}");
                // and it is the lower half: its far edge is below the hinge
                let far = if orient == "landscapeLeft" { v3(-1000.0, 0.0, 0.0) } else { rot_y(v3(1000.0, 0.0, 0.0), phi) };
                let f = rot_x(rot_z(far, roll), tilt);
                assert!(f.y.abs() < 1e-2 && f.z > 900.0, "{orient} at {deg}: far edge {f:?}");
                // the default camera sees its top: the face turned towards the viewer (+z), from above; low as a
                // laptop is seen once the inner screen is in use, from high above while folded
                let (yaw, pitch) = Duo3d::default_view(orient, deg as f64, phi);
                let seen = rot_x(rot_y(n, yaw), pitch);
                let up = if deg >= 85.0 { 0.5 } else { 0.3 };
                assert!(seen.z > 0.3 && seen.y > up, "{orient} at {deg}: base top seen as {seen:?}");
            }
        }
    }
}
