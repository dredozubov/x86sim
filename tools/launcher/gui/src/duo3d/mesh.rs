//! The phone's geometry, in inner-screen pixels, shaped after Apple's model (x86sim_core::devicemodel, drawn instead
//! when this machine has it; the sizes here were measured from it): two rounded halves (filleted edges, smooth
//! normals) of different thickness, the left one thin with the outer screen on its back (a camera hole in it), the
//! right one thicker with frosted back glass, a camera plateau with two round lens towers and a flash, and two side buttons on its far
//! edge; speaker and microphone holes on the bottom and top edges. The inner screen is one panel across both halves
//! that creases at the hinge. Between the halves a brushed metal spine bar, hidden inside the body when flat, turns
//! out by half the fold and closes the gap at the fold edge.
//!
//! A half's own space: x from the hinge (0) out, y up, the front (inner screen) at z = 0, the back at -THICK_L /
//! -THICK_R. The left half is that space mirrored (x -> -x); the right half is turned by phi = 180 - the hinge angle
//! about the hinge axis (parallel to y, AXIS_Z in front of the screen: closed, the two screens lie 2 AXIS_Z apart).

/// Sizes in inner-screen pixels (the inner panel is 2007 x 2853, mounted turned: 2853 wide when open in portrait)
pub const INNER: (f32, f32) = (2853.0, 2007.0);
pub const OUTER: (f32, f32) = (1398.0, 2034.0);
/// the case around the screens, the halves' thicknesses (left: the outer screen's; right: the cameras'), the case's
/// outer corner radius, the edges' fillet, where the hinge axis is (in front of the screen plane)
pub const BEZEL: f32 = 46.0;
pub const THICK_L: f32 = 95.0;
pub const THICK_R: f32 = 158.0;
pub const CORNER: f32 = 200.0;
pub const FILLET: f32 = 13.0;
pub const AXIS_Z: f32 = 4.7;
/// the spine bar: its cross-section (across the hinge, through the body) and half length; where its middle is (x, z)
/// at hinge angles 0, 22.5, .. 180 degrees (it turns by half the fold)
const SPINE: (f32, f32, f32) = (148.0, 53.0, 1043.0);
const SPINE_AT: [(f32, f32); 9] = [(20.6, 4.7), (20.3, 0.7), (19.1, -3.2), (17.2, -6.8), (14.7, -9.9), (15.0, -18.1), (14.1, -29.4), (8.9, -39.8), (0.0, -44.3)];
/// the right half's camera plateau (x from, to; y from, to; its top), the towers on it (centre x, y; radius; lens
/// radius) and their top, and the flash and microphone on it
const PLATEAU: (f32, f32, f32, f32, f32) = (520.0, 1440.0, 600.0, 990.0, 182.0);
const CAMS: [(f32, f32, f32, f32); 2] = [(893.0, 788.0, 147.0, 70.0), (1214.0, 788.0, 147.0, 95.0)];
const CAM_TOP: f32 = 197.0;
const FLASH: (f32, f32, f32) = (592.0, 708.0, 36.0);
const MIC: (f32, f32, f32) = (591.0, 866.0, 14.0);
/// the outer screen's camera hole (the left half's own x, y; radius)
const HOLE: (f32, f32, f32) = (1297.0, 871.0, 32.0);
/// the right half's side buttons on its far edge (y from, to), their middle's depth and half height, how far they stand
const BUTTONS: [(f32, f32); 2] = [(-623.0, -322.0), (124.0, 454.0)];
const BUTTON_Z: (f32, f32, f32) = (-45.0, 20.0, 8.0);
/// the speaker holes on the right half's bottom edge and the microphone holes on the left half's top edge (own x),
/// at depth -46
const SPEAKER: [f32; 8] = [290.0, 330.0, 371.0, 412.0, 1070.0, 1111.0, 1152.0, 1192.0];
const MICS: [f32; 4] = [620.0, 717.0, 766.0, 861.0];
/// the corner radius of a half on the hinge side (the spine covers it)
const HINGE_CORNER: f32 = 0.5;

pub fn half_w() -> f32 {
    INNER.0 / 2.0 + BEZEL
}
pub fn half_h() -> f32 {
    OUTER.1 + 2.0 * BEZEL
}

/// Materials (the shader's): the frame (polished warm titanium), the right half's frosted white back glass, black
/// glass (the fronts, the outer screen's cover, the camera caps), inner screen, outer screen, brushed metal (the spine
/// bar, the camera rings), dark (lenses and holes)
pub const ALU: f32 = 0.0;
pub const BACK: f32 = 1.0;
pub const FRONT: f32 = 2.0;
pub const INNER_SCREEN: f32 = 3.0;
pub const OUTER_SCREEN: f32 = 4.0;
pub const HINGE: f32 = 5.0;
pub const DARK: f32 = 6.0;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct V3 {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}
pub fn v3(x: f32, y: f32, z: f32) -> V3 {
    V3 { x, y, z }
}
impl V3 {
    pub fn dot(self, o: V3) -> f32 {
        self.x * o.x + self.y * o.y + self.z * o.z
    }
    pub fn sub(self, o: V3) -> V3 {
        v3(self.x - o.x, self.y - o.y, self.z - o.z)
    }
    pub fn add(self, o: V3) -> V3 {
        v3(self.x + o.x, self.y + o.y, self.z + o.z)
    }
    pub fn scale(self, k: f32) -> V3 {
        v3(self.x * k, self.y * k, self.z * k)
    }
    pub fn norm(self) -> V3 {
        let l = self.dot(self).sqrt().max(1e-9);
        self.scale(1.0 / l)
    }
}
pub fn rot_x(p: V3, a: f32) -> V3 {
    let (s, c) = a.sin_cos();
    v3(p.x, p.y * c - p.z * s, p.y * s + p.z * c)
}
pub fn rot_y(p: V3, a: f32) -> V3 {
    let (s, c) = a.sin_cos();
    v3(p.x * c - p.z * s, p.y, p.x * s + p.z * c)
}
pub fn rot_z(p: V3, a: f32) -> V3 {
    let (s, c) = a.sin_cos();
    v3(p.x * c - p.y * s, p.x * s + p.y * c, p.z)
}

#[derive(Clone, Copy, Debug)]
#[repr(C)]
pub struct Vtx {
    pub p: [f32; 3],
    pub n: [f32; 3],
    pub uv: [f32; 2],
    pub m: f32,
}

/// Vertices and triangles; the screens come after `body` indices (drawn with a depth offset over the glass)
#[derive(Default)]
pub struct Mesh {
    pub v: Vec<Vtx>,
    pub i: Vec<u32>,
    pub body: usize,
}

impl Mesh {
    fn vert(&mut self, p: V3, n: V3, uv: (f32, f32), m: f32) -> u32 {
        self.v.push(Vtx { p: [p.x, p.y, p.z], n: [n.x, n.y, n.z], uv: [uv.0, uv.1], m });
        (self.v.len() - 1) as u32
    }
    fn quad(&mut self, a: u32, b: u32, c: u32, d: u32) {
        self.i.extend_from_slice(&[a, b, c, a, c, d]);
    }
}

/// A part's placement: an affine map (columns, then a translation); normals take the columns alone
#[derive(Clone, Copy)]
struct Place {
    c: [V3; 3],
    t: V3,
}
impl Place {
    fn n(self, n: V3) -> V3 {
        self.c[0].scale(n.x).add(self.c[1].scale(n.y)).add(self.c[2].scale(n.z))
    }
    fn p(self, p: V3) -> V3 {
        self.n(p).add(self.t)
    }
    /// this placement after `inner` (a part placed in a half's own space)
    fn of(self, inner: Place) -> Place {
        Place { c: [self.n(inner.c[0]), self.n(inner.c[1]), self.n(inner.c[2])], t: self.p(inner.t) }
    }
    /// the left half: mirrored
    fn left() -> Place {
        Place { c: [v3(-1.0, 0.0, 0.0), v3(0.0, 1.0, 0.0), v3(0.0, 0.0, 1.0)], t: v3(0.0, 0.0, 0.0) }
    }
    /// the right half: turned by phi about the hinge axis (x = 0, z = AXIS_Z)
    fn right(phi: f32) -> Place {
        let a = v3(0.0, 0.0, AXIS_Z);
        let (cx, cz) = (rot_y(v3(1.0, 0.0, 0.0), phi), rot_y(v3(0.0, 0.0, 1.0), phi));
        Place { c: [cx, v3(0.0, 1.0, 0.0), cz], t: a.sub(rot_y(a, phi)) }
    }
    /// local x, y, z -> the given axes, at `t`
    fn axes(x: V3, y: V3, z: V3, t: V3) -> Place {
        Place { c: [x, y, z], t }
    }
}

/// A rounded rectangle's outline with each point's outward normal, counter-clockwise; radii: bottom right, top right,
/// top left, bottom left
fn outline(x0: f32, x1: f32, y0: f32, y1: f32, r: [f32; 4], seg: usize) -> Vec<((f32, f32), (f32, f32))> {
    let corners = [(x1 - r[0], y0 + r[0], -90.0f32), (x1 - r[1], y1 - r[1], 0.0), (x0 + r[2], y1 - r[2], 90.0), (x0 + r[3], y0 + r[3], 180.0)];
    let mut pts = vec![];
    for (i, (cx, cy, a0)) in corners.iter().enumerate() {
        for k in 0..=seg {
            let a = (a0 + 90.0 * k as f32 / seg as f32).to_radians();
            pts.push(((cx + r[i] * a.cos(), cy + r[i] * a.sin()), (a.cos(), a.sin())));
        }
    }
    pts
}

/// A slab with filleted edges: the rounded rectangle extruded from z_front down to z_back, its edges rounded by
/// `e`; side, front cap and back cap materials
#[allow(clippy::too_many_arguments)]
fn slab(m: &mut Mesh, at: Place, (x0, x1, y0, y1): (f32, f32, f32, f32), r: [f32; 4], (z_front, z_back): (f32, f32), e: f32, mats: (f32, f32, f32), seg: usize) {
    let line = outline(x0, x1, y0, y1, r, seg);
    // the profile around an edge: the front fillet (90 -> 0 degrees), then the back one (0 -> -90)
    let k = 5;
    let mut prof = vec![];
    for j in 0..=k {
        let t = (90.0 - 90.0 * j as f32 / k as f32).to_radians();
        prof.push((t, z_front - e));
    }
    for j in 0..=k {
        let t = (-90.0 * j as f32 / k as f32).to_radians();
        prof.push((t, z_back + e));
    }
    let base = m.v.len() as u32;
    let np = prof.len() as u32;
    for &((px, py), (nx, ny)) in &line {
        for &(t, cz) in &prof {
            let d = e * (t.cos() - 1.0);
            let p = v3(px + nx * d, py + ny * d, cz + e * t.sin());
            let n = v3(nx * t.cos(), ny * t.cos(), t.sin());
            m.vert(at.p(p), at.n(n), (0.0, 0.0), mats.0);
        }
    }
    let nl = line.len() as u32;
    for i in 0..nl {
        let i2 = (i + 1) % nl;
        for j in 0..np - 1 {
            m.quad(base + i * np + j, base + i2 * np + j, base + i2 * np + j + 1, base + i * np + j + 1);
        }
    }
    // the caps: the outline inset by the fillet, fanned from the centre
    for (z, nz, mat) in [(z_front, 1.0f32, mats.1), (z_back, -1.0, mats.2)] {
        let n = at.n(v3(0.0, 0.0, nz));
        let c = m.vert(at.p(v3((x0 + x1) / 2.0, (y0 + y1) / 2.0, z)), n, (0.0, 0.0), mat);
        let first = m.v.len() as u32;
        for &((px, py), (nx, ny)) in &line {
            m.vert(at.p(v3(px - nx * e, py - ny * e, z)), n, (0.0, 0.0), mat);
        }
        for i in 0..nl {
            m.i.extend_from_slice(&[c, first + i, first + (i + 1) % nl]);
        }
    }
}

/// A point of a rectangle's grid pulled onto its corner arcs (radius r at every corner)
fn round_in(x: f32, y: f32, x0: f32, x1: f32, y0: f32, y1: f32, r: f32) -> (f32, f32) {
    let cx = if x < x0 + r { x0 + r } else if x > x1 - r { x1 - r } else { return (x, y) };
    let cy = if y < y0 + r { y0 + r } else if y > y1 - r { y1 - r } else { return (x, y) };
    let (dx, dy) = (x - cx, y - cy);
    let d = (dx * dx + dy * dy).sqrt();
    if d > r { (cx + dx / d * r, cy + dy / d * r) } else { (x, y) }
}

/// A screen: a grid over a rounded rectangle in its own flat coordinates, each point placed by `at` (position,
/// normal) with texture coordinate `uv`
#[allow(clippy::too_many_arguments)]
fn screen(m: &mut Mesh, (x0, x1, y0, y1): (f32, f32, f32, f32), r: f32, (nx, ny): (usize, usize), mat: f32, at: impl Fn(f32, f32) -> (V3, V3), uv: impl Fn(f32, f32) -> (f32, f32)) {
    let base = m.v.len() as u32;
    for j in 0..=ny {
        for i in 0..=nx {
            let x = x0 + (x1 - x0) * i as f32 / nx as f32;
            let y = y0 + (y1 - y0) * j as f32 / ny as f32;
            let (x, y) = round_in(x, y, x0, x1, y0, y1, r);
            let (p, n) = at(x, y);
            m.vert(p, n, uv(x, y), mat);
        }
    }
    let at_ = |i: usize, j: usize| base + (j * (nx + 1) + i) as u32;
    for j in 0..ny {
        for i in 0..nx {
            m.quad(at_(i, j), at_(i + 1, j), at_(i + 1, j + 1), at_(i, j + 1));
        }
    }
}

/// A flat disc in a placement's local z = 0 plane, facing +z
fn disc(m: &mut Mesh, at: Place, (cx, cy, r): (f32, f32, f32), mat: f32, seg: usize) {
    let n = at.n(v3(0.0, 0.0, 1.0));
    let c = m.vert(at.p(v3(cx, cy, 0.0)), n, (0.0, 0.0), mat);
    let first = m.v.len() as u32;
    for k in 0..=seg {
        let a = std::f32::consts::TAU * k as f32 / seg as f32;
        m.vert(at.p(v3(cx + r * a.cos(), cy + r * a.sin(), 0.0)), n, (0.0, 0.0), mat);
    }
    for k in 0..seg as u32 {
        m.i.extend_from_slice(&[c, first + k, first + k + 1]);
    }
}

/// A round tower standing on a half's back (its own space, the back at z = `z0`) out to `z1` (further back): its side
/// and a cap of black glass with a darker lens in it
#[allow(clippy::too_many_arguments)]
fn tower(m: &mut Mesh, at: Place, (cx, cy, r, lens): (f32, f32, f32, f32), z0: f32, z1: f32, seg: usize) {
    let base = m.v.len() as u32;
    for k in 0..=seg {
        let a = std::f32::consts::TAU * k as f32 / seg as f32;
        let n = at.n(v3(a.cos(), a.sin(), 0.0));
        for z in [z0, z1] {
            m.vert(at.p(v3(cx + r * a.cos(), cy + r * a.sin(), z)), n, (0.0, 0.0), HINGE);
        }
    }
    for k in 0..seg as u32 {
        m.quad(base + 2 * k, base + 2 * k + 2, base + 2 * k + 3, base + 2 * k + 1);
    }
    // the caps face the back (-z)
    let back = at.of(Place::axes(v3(1.0, 0.0, 0.0), v3(0.0, -1.0, 0.0), v3(0.0, 0.0, -1.0), v3(0.0, 0.0, z1)));
    disc(m, back, (cx, -cy, r - 10.0), FRONT, seg);
    let back2 = at.of(Place::axes(v3(1.0, 0.0, 0.0), v3(0.0, -1.0, 0.0), v3(0.0, 0.0, -1.0), v3(0.0, 0.0, z1 - 0.8)));
    disc(m, back2, (cx, -cy, lens), DARK, seg);
}

/// The spine bar at hinge turn `phi`: a stadium of SPINE's section along the hinge, turned by phi / 2, its middle on
/// the measured path; ends closed
fn spine(m: &mut Mesh, phi: f32) {
    let deg = (180.0 - phi.to_degrees()).clamp(0.0, 180.0);
    let f = deg / 22.5;
    let (i, t) = ((f.floor() as usize).min(7), f - f.floor().min(7.0));
    let (a, b) = (SPINE_AT[i], SPINE_AT[(i + 1).min(8)]);
    let mut c = v3(a.0 + (b.0 - a.0) * t, 0.0, a.1 + (b.1 - a.1) * t);
    // local x: across the hinge, local y: through the body, local z: along the hinge
    let (u, v) = (rot_y(v3(1.0, 0.0, 0.0), phi / 2.0), rot_y(v3(0.0, 0.0, 1.0), phi / 2.0));
    let (w, h, len) = SPINE;
    // kept behind the crease (Apple's bent panel covers it; the crease here is sharp): `inside` points into the fold
    let inside = v3(-(phi / 2.0).sin(), 0.0, (phi / 2.0).cos());
    let crease = Place::right(phi).p(v3(0.0, 0.0, 0.0)).scale(0.5);
    let reach = c.dot(inside) + w / 2.0 * u.dot(inside).abs() + h / 2.0 * v.dot(inside).abs();
    c = c.sub(inside.scale((reach - crease.dot(inside) + 2.0).max(0.0)));
    let at = Place::axes(u, v, v3(0.0, -1.0, 0.0), c);
    slab(m, at, (-w / 2.0, w / 2.0, -h / 2.0, h / 2.0), [h / 2.0 - 0.01; 4], (len, -len), 1.5, (HINGE, HINGE, HINGE), 6);
}

/// The phone at hinge angle `deg` (0 closed .. 180 flat)
pub fn build(deg: f32) -> Mesh {
    let phi = (180.0 - deg).to_radians();
    let (w, h) = (half_w(), half_h());
    let mut m = Mesh::default();
    let radii = [CORNER, CORNER, HINGE_CORNER, HINGE_CORNER];
    let (left, right) = (Place::left(), Place::right(phi));
    slab(&mut m, left, (0.0, w, -h / 2.0, h / 2.0), radii, (0.0, -THICK_L), FILLET, (ALU, FRONT, FRONT), 10);
    slab(&mut m, right, (0.0, w, -h / 2.0, h / 2.0), radii, (0.0, -THICK_R), FILLET, (ALU, FRONT, BACK), 10);
    spine(&mut m, phi);
    // the right half's back: the camera plateau, the towers on it, the flash and the microphone
    let (px0, px1, py0, py1, ptop) = PLATEAU;
    let pr = (py1 - py0) / 2.0 - 0.01;
    slab(&mut m, right, (px0, px1, py0, py1), [pr; 4], (-THICK_R + 1.0, -ptop), 8.0, (BACK, BACK, BACK), 12);
    for cam in CAMS {
        tower(&mut m, right, cam, -ptop + 1.0, -CAM_TOP, 40);
    }
    let back_r = right.of(Place::axes(v3(1.0, 0.0, 0.0), v3(0.0, -1.0, 0.0), v3(0.0, 0.0, -1.0), v3(0.0, 0.0, -ptop - 0.6)));
    disc(&mut m, back_r, (FLASH.0, -FLASH.1, FLASH.2), ALU, 20);
    disc(&mut m, back_r, (MIC.0, -MIC.1, MIC.2), DARK, 12);
    // the side buttons: pills standing out of the right half's far edge (local x along y, y along z, z outwards)
    for (y0, y1) in BUTTONS {
        let at = right.of(Place::axes(v3(0.0, 1.0, 0.0), v3(0.0, 0.0, 1.0), v3(1.0, 0.0, 0.0), v3(w - 2.0, 0.0, 0.0)));
        let (zc, hz, out) = BUTTON_Z;
        slab(&mut m, at, (y0, y1, zc - hz, zc + hz), [hz - 0.01; 4], (out + 2.0, 0.0), 2.0, (ALU, ALU, ALU), 6);
    }
    // speaker holes (the right half's bottom edge) and microphone holes (the left half's top edge)
    let bottom = right.of(Place::axes(v3(1.0, 0.0, 0.0), v3(0.0, 0.0, 1.0), v3(0.0, -1.0, 0.0), v3(0.0, -h / 2.0 - 0.6, 0.0)));
    for x in SPEAKER {
        disc(&mut m, bottom, (x, -46.0, 11.0), DARK, 10);
    }
    let top = left.of(Place::axes(v3(1.0, 0.0, 0.0), v3(0.0, 0.0, -1.0), v3(0.0, 1.0, 0.0), v3(0.0, h / 2.0 + 0.6, 0.0)));
    for x in MICS {
        disc(&mut m, top, (x, 46.0, 9.0), DARK, 10);
    }
    // the outer screen's camera hole, just off its glass
    let back_l = left.of(Place::axes(v3(1.0, 0.0, 0.0), v3(0.0, -1.0, 0.0), v3(0.0, 0.0, -1.0), v3(0.0, 0.0, -THICK_L - 1.2)));
    disc(&mut m, back_l, (HOLE.0, -HOLE.1, HOLE.2), DARK, 24);
    m.body = m.i.len();
    // the inner screen, one panel across both fronts: x < 0 on the left half, x > 0 turned with the right one; the
    // grid has a column at x = 0, the crease, between the two
    let (sw, sh) = INNER;
    let r = CORNER - BEZEL;
    let z = v3(0.0, 0.0, 1.0);
    screen(&mut m, (-sw / 2.0, sw / 2.0, -sh / 2.0, sh / 2.0), r, (40, 28), INNER_SCREEN, |x, y| {
        if x < -0.01 {
            (v3(x, y, 0.0), z)
        } else if x > 0.01 {
            (right.p(v3(x, y, 0.0)), right.n(z))
        } else {
            // closed, the two fronts face each other: the crease faces out of the fold
            let n = z.add(right.n(z));
            (v3(0.0, y, 0.0).add(right.p(v3(0.0, y, 0.0))).scale(0.5), if n.dot(n) < 1e-6 { v3(1.0, 0.0, 0.0) } else { n.norm() })
        }
    }, |x, y| ((x + sw / 2.0) / sw, (sh / 2.0 - y) / sh));
    // the outer screen on the left half's back (its own x runs out from the hinge: seen from behind, left to right)
    let (ow, oh) = OUTER;
    let cx = w / 2.0;
    let ox0 = cx - ow / 2.0;
    screen(&mut m, (ox0, ox0 + ow, -oh / 2.0, oh / 2.0), r, (20, 28), OUTER_SCREEN, |x, y| (left.p(v3(x, y, -THICK_L)), v3(0.0, 0.0, -1.0)), |x, y| ((x - ox0) / ow, (oh / 2.0 - y) / oh));
    m
}

impl Mesh {
    /// The touch surfaces (x86sim_core::devicemodel::HitMesh): the body hides, the screens are touched; a screen
    /// vertex's uv is its picture point with y up, as a model's st
    pub fn hit_mesh(&self) -> x86sim_core::devicemodel::HitMesh {
        let kind = |m: f32| if m == INNER_SCREEN { 1 } else if m == OUTER_SCREEN { 2 } else { 0 };
        let tris = self.i.chunks(3).map(|t| ([t[0], t[1], t[2]], kind(self.v[t[0] as usize].m))).collect();
        x86sim_core::devicemodel::HitMesh { p: self.v.iter().map(|v| v.p).collect(), uv: self.v.iter().map(|v| [v.uv[0], 1.0 - v.uv[1]]).collect(), tris }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn closed_right_half_lies_on_the_left_with_its_back_up() {
        let p = Place::right(std::f32::consts::PI).p(v3(half_w(), 0.0, -THICK_R));
        assert!((p.x + half_w()).abs() < 0.01 && (p.z - THICK_R - 2.0 * AXIS_Z).abs() < 0.01, "{p:?}");
    }

    #[test]
    fn half_open_right_half_stands_towards_the_viewer() {
        let p = Place::right(90f32.to_radians()).p(v3(half_w(), 0.0, 0.0));
        assert!((p.x - AXIS_Z).abs() < 0.01 && (p.z - half_w() - AXIS_Z).abs() < 0.01, "{p:?}");
    }

    #[test]
    fn grid_stays_inside_rounded_corners() {
        let (x, y) = round_in(100.0, 100.0, 0.0, 100.0, 0.0, 100.0, 40.0);
        let d = ((x - 60.0).powi(2) + (y - 60.0).powi(2)).sqrt();
        assert!((d - 40.0).abs() < 0.01);
    }

    #[test]
    fn inner_screen_has_no_seam_at_the_crease() {
        // the crease column is one row of vertices shared by both halves' quads, between them at the hinge
        let m = build(100.0);
        let crease = m.v.iter().filter(|v| v.m == INNER_SCREEN && v.p[0].abs() < AXIS_Z && v.p[2].abs() < AXIS_Z).count();
        assert!(crease >= 25, "{crease}");
    }

    /// Flat, the spine bar is inside the body (hidden); closed, it stands across the fold edge
    #[test]
    fn spine_hides_when_flat_and_closes_the_fold() {
        let spine = |deg: f32| build(deg).v.into_iter().filter(|v| v.m == HINGE && v.p[0].abs() < 150.0).collect::<Vec<_>>();
        for v in spine(180.0) {
            assert!(v.p[2] < -1.0 && v.p[2] > -THICK_L + 1.0, "{:?}", v.p);
        }
        let closed = spine(0.0);
        let (lo, hi) = closed.iter().fold((f32::MAX, f32::MIN), |(lo, hi), v| (lo.min(v.p[2]), hi.max(v.p[2])));
        assert!(lo < -60.0 && hi > 70.0, "{lo} {hi}");
    }
}
