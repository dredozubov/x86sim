//! The 3D phone's space: vectors and turns, and the screens' sizes in inner-screen pixels (Apple's model,
//! x86sim_core::devicemodel, is read into the same units).

/// Sizes in inner-screen pixels (the inner panel is 2007 x 2853, mounted turned: 2853 wide when open in portrait)
pub const INNER: (f32, f32) = (2853.0, 2007.0);
pub const OUTER: (f32, f32) = (1398.0, 2034.0);
/// the case around the screens
const BEZEL: f32 = 46.0;

/// A half's width (from the hinge out) and height
pub fn half_w() -> f32 {
    INNER.0 / 2.0 + BEZEL
}
pub fn half_h() -> f32 {
    OUTER.1 + 2.0 * BEZEL
}

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
    pub fn sub(self, o: V3) -> V3 {
        v3(self.x - o.x, self.y - o.y, self.z - o.z)
    }
    pub fn add(self, o: V3) -> V3 {
        v3(self.x + o.x, self.y + o.y, self.z + o.z)
    }
    pub fn scale(self, k: f32) -> V3 {
        v3(self.x * k, self.y * k, self.z * k)
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
