//! The phone's geometry, in inner-screen pixels: two rounded halves (filleted edges, smooth normals) on a hinge
//! spine, the inner screen as one panel across both halves that creases at the hinge, the outer screen on the left
//! half's back (as on Apple's model, x86sim_core::devicemodel, drawn instead when this machine has it).
//!
//! A half's own space: x from the hinge (0) out, y up, the front (inner screen) at z = 0, the back at -THICK. The
//! left half is that space mirrored (x -> -x); the right half is turned about the hinge axis (the y axis) by phi =
//! 180 - the hinge angle, so closed it lies on the left half with its back (the outer screen) towards +z. The spine
//! is the part of a cylinder of the halves' thickness about the axis that lies between the two backs: nothing when
//! flat, the closed phone's rounded edge when closed.

/// Sizes in inner-screen pixels (the inner panel is 2007 x 2853, mounted turned: 2853 wide when open in portrait)
pub const INNER: (f32, f32) = (2853.0, 2007.0);
pub const OUTER: (f32, f32) = (1398.0, 2034.0);
/// the case around the screens, a half's thickness, the case's outer corner radius, the edges' fillet
pub const BEZEL: f32 = 46.0;
pub const THICK: f32 = 105.0;
pub const CORNER: f32 = 200.0;
pub const FILLET: f32 = 13.0;
/// the corner radius of a half on the hinge side (the spine covers it)
const HINGE_CORNER: f32 = 0.5;

pub fn half_w() -> f32 {
    INNER.0 / 2.0 + BEZEL
}
pub fn half_h() -> f32 {
    OUTER.1 + 2.0 * BEZEL
}

/// Materials (the shader's): aluminium, back glass, front glass, inner screen, outer screen, hinge, dark (the
/// spine's joint lines)
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

/// A part's placement: the left half (mirrored) or the right half (turned by phi)
#[derive(Clone, Copy)]
enum Place {
    Left,
    Right(f32),
}
impl Place {
    fn p(self, p: V3) -> V3 {
        match self {
            Place::Left => v3(-p.x, p.y, p.z),
            Place::Right(phi) => rot_y(p, phi),
        }
    }
    fn n(self, n: V3) -> V3 {
        self.p(n)
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

/// The spine: the arc of a cylinder about the hinge axis between the two halves' backs (from the left half's back,
/// -90 degrees, through the outside to the right half's, -90 + phi), its ends closed, a fine seam near each end
fn spine(m: &mut Mesh, phi: f32) {
    if phi < 0.5f32.to_radians() {
        return;
    }
    let r = THICK + 0.8;
    let y1 = half_h() / 2.0 - HINGE_CORNER;
    let segs = ((phi.to_degrees() / 6.0).ceil() as usize).max(2);
    let ring = |m: &mut Mesh, r: f32, ya: f32, yb: f32, mat: f32| {
        let base = m.v.len() as u32;
        for s in 0..=segs {
            let t = -std::f32::consts::FRAC_PI_2 + phi * s as f32 / segs as f32;
            let n = v3(t.cos(), 0.0, t.sin());
            m.vert(v3(r * t.cos(), ya, r * t.sin()), n, (0.0, 0.0), mat);
            m.vert(v3(r * t.cos(), yb, r * t.sin()), n, (0.0, 0.0), mat);
        }
        for s in 0..segs as u32 {
            m.quad(base + 2 * s, base + 2 * s + 2, base + 2 * s + 3, base + 2 * s + 1);
        }
    };
    ring(m, r, -y1, y1, HINGE);
    // the ends: pie wedges about the axis
    for (y, ny) in [(-y1, -1.0f32), (y1, 1.0)] {
        let n = v3(0.0, ny, 0.0);
        let c = m.vert(v3(0.0, y, 0.0), n, (0.0, 0.0), HINGE);
        let first = m.v.len() as u32;
        for s in 0..=segs {
            let t = -std::f32::consts::FRAC_PI_2 + phi * s as f32 / segs as f32;
            m.vert(v3(r * t.cos(), y, r * t.sin()), n, (0.0, 0.0), HINGE);
        }
        for s in 0..segs as u32 {
            m.i.extend_from_slice(&[c, first + s, first + s + 1]);
        }
    }
    // the end caps' seams: a fine groove near each end, as on a hinge cover
    for y in [-y1 + 70.0, y1 - 70.0] {
        ring(m, r + 0.6, y - 2.0, y + 2.0, DARK);
    }
}

/// The phone at hinge angle `deg` (0 closed .. 180 flat)
pub fn build(deg: f32) -> Mesh {
    let phi = (180.0 - deg).to_radians();
    let (w, h) = (half_w(), half_h());
    let mut m = Mesh::default();
    let radii = [CORNER, CORNER, HINGE_CORNER, HINGE_CORNER];
    for (at, back) in [(Place::Left, FRONT), (Place::Right(phi), BACK)] {
        slab(&mut m, at, (0.0, w, -h / 2.0, h / 2.0), radii, (0.0, -THICK), FILLET, (ALU, FRONT, back), 10);
    }
    spine(&mut m, phi);
    m.body = m.i.len();
    // the inner screen, one panel across both fronts: x < 0 on the left half, x > 0 turned with the right one; the
    // grid has a column at x = 0, the crease, whose normal is between the two
    let (sw, sh) = INNER;
    let r = CORNER - BEZEL;
    screen(&mut m, (-sw / 2.0, sw / 2.0, -sh / 2.0, sh / 2.0), r, (40, 28), INNER_SCREEN, |x, y| {
        if x < -0.01 {
            (v3(x, y, 0.0), v3(0.0, 0.0, 1.0))
        } else if x > 0.01 {
            (rot_y(v3(x, y, 0.0), phi), rot_y(v3(0.0, 0.0, 1.0), phi))
        } else {
            (v3(0.0, y, 0.0), v3(0.0, 0.0, 1.0).add(rot_y(v3(0.0, 0.0, 1.0), phi)).norm())
        }
    }, |x, y| ((x + sw / 2.0) / sw, (sh / 2.0 - y) / sh));
    // the outer screen on the left half's back (its own x runs out from the hinge: seen from behind, left to right)
    let (ow, oh) = OUTER;
    let cx = w / 2.0;
    let (ox0, ox1) = (cx - ow / 2.0, cx + ow / 2.0);
    screen(&mut m, (ox0, ox1, -oh / 2.0, oh / 2.0), r, (20, 28), OUTER_SCREEN, |x, y| (v3(-x, y, -THICK), v3(0.0, 0.0, -1.0)), |x, y| ((x - ox0) / ow, (oh / 2.0 - y) / oh));
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
        let p = rot_y(v3(half_w(), 0.0, -THICK), 180f32.to_radians());
        assert!((p.x + half_w()).abs() < 0.01 && (p.z - THICK).abs() < 0.01, "{p:?}");
    }

    #[test]
    fn half_open_right_half_stands_towards_the_viewer() {
        let p = rot_y(v3(half_w(), 0.0, 0.0), 90f32.to_radians());
        assert!(p.x.abs() < 0.01 && (p.z - half_w()).abs() < 0.01, "{p:?}");
    }

    #[test]
    fn grid_stays_inside_rounded_corners() {
        let (x, y) = round_in(100.0, 100.0, 0.0, 100.0, 0.0, 100.0, 40.0);
        let d = ((x - 60.0).powi(2) + (y - 60.0).powi(2)).sqrt();
        assert!((d - 40.0).abs() < 0.01);
    }

    #[test]
    fn inner_screen_has_no_seam_at_the_crease() {
        // the crease column is one row of vertices shared by both halves' quads, at x = 0, z = 0
        let m = build(100.0);
        let crease = m.v.iter().filter(|v| v.m == INNER_SCREEN && v.p[0].abs() < 1e-3 && v.p[2].abs() < 1e-3).count();
        assert!(crease >= 25, "{crease}");
    }

    #[test]
    fn spine_only_when_bent() {
        let hinge = |deg: f32| build(deg).v.iter().filter(|v| v.m == HINGE).count();
        assert_eq!(hinge(180.0), 0);
        assert_eq!(hinge(179.9), 0);
        assert!(hinge(0.0) > 0 && hinge(90.0) > 0);
    }
}
