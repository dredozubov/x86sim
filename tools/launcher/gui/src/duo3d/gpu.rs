//! Draws Apple's iPhone Duo model (x86sim_core::devicemodel, from the user's own Xcode.xip) with OpenGL inside egui
//! (an egui_glow paint callback): into a framebuffer of its own at twice the area's pixels with a depth buffer, then
//! that image shrunk into the area (2x2 supersampling: smooth edges and steady screen pictures), over egui's own
//! drawing with premultiplied alpha. It is skinned on the GPU along its hinge, its UsdPreviewSurface materials and
//! textures lit by a photo studio.
use x86sim_core::devicemodel::{self, Model};
use eframe::{egui, egui_glow};
use eframe::glow::{self, HasContext};
use std::sync::{Arc, Mutex};

/// What a frame draws: the model and its joint matrices at the drawn angle, the camera (view rotation, centre,
/// projection fit) and the screens' textures
pub struct Frame {
    pub model: Arc<Model>,
    pub bones: Vec<[f32; 16]>,
    /// column-major view rotation
    pub rot: [f32; 9],
    pub centre: [f32; 3],
    /// x and y scale of the projected point to NDC, x and y offset in NDC
    pub fit: [f32; 4],
    /// camera distance, near, far (depth range)
    pub dnf: [f32; 3],
    pub inner: Option<egui::TextureId>,
    pub outer: Option<egui::TextureId>,
}

struct Gl {
    quad: glow::Program,
    quad_vao: glow::VertexArray,
    quad_vbo: glow::Buffer,
    fbo: glow::Framebuffer,
    color: glow::Texture,
    depth: glow::Renderbuffer,
    size: (i32, i32),
    black: glow::Texture,
    /// the model's GL objects, made on its first frame (None: not made, Some(Err): failed)
    model: Option<Result<ModelGl, ()>>,
}

/// The model on the GPU: its program, static vertex and index buffers, and its images as textures
struct ModelGl {
    prog: glow::Program,
    vao: glow::VertexArray,
    textures: Vec<glow::Texture>,
    /// the model it was made for (its address)
    of: usize,
}

/// One drawing area's GL objects, made on first use
#[derive(Default, Clone)]
pub struct Target(Arc<Mutex<Option<Result<Gl, ()>>>>);

/// Skinned in the vertex shader (four joints a vertex)
const AVS: &str = r#"
uniform mat3 u_rot; uniform vec3 u_c; uniform vec4 u_fit; uniform vec3 u_dnf;
uniform mat4 u_bones[32];
IN vec3 a_p; IN vec3 a_n; IN vec2 a_uv; IN vec2 a_uv1; IN vec4 a_j; IN vec4 a_w;
OUT vec3 v_n; OUT vec3 v_p; OUT vec2 v_uv; OUT vec2 v_uv1;
void main() {
    mat4 sk = u_bones[int(a_j.x)] * a_w.x + u_bones[int(a_j.y)] * a_w.y + u_bones[int(a_j.z)] * a_w.z + u_bones[int(a_j.w)] * a_w.w;
    vec3 p = u_rot * (sk * vec4(a_p, 1.0)).xyz - u_c;
    float w = u_dnf.x - p.z;
    gl_Position = vec4(p.x * u_dnf.x * u_fit.x + u_fit.z * w, p.y * u_dnf.x * u_fit.y + u_fit.w * w,
        ((w - u_dnf.y) / (u_dnf.z - u_dnf.y) * 2.0 - 1.0) * w, w);
    v_n = u_rot * (mat3(sk) * a_n); v_p = p; v_uv = a_uv; v_uv1 = a_uv1;
}
"#;

/// UsdPreviewSurface (base colour, metallic, roughness, occlusion, a normal map, opacity, clearcoat) lit by a photo
/// studio around the camera, in view space (a dark floor, a softbox overhead, a strip light at each side, a faint card
/// behind the camera), its reflections blurred with the roughness; the screens show the phone's pictures
const AFS: &str = r#"
uniform sampler2D u_t0; uniform sampler2D u_t1; uniform sampler2D u_t2; uniform sampler2D u_t3; uniform sampler2D u_t4;
uniform sampler2D u_t5; uniform sampler2D u_pic;
// per texture slot (base, metallic, roughness, occlusion, normal, opacity): has, uv set, channel
uniform vec3 u_ts[6];
uniform vec4 u_nscale; uniform vec4 u_nbias;
uniform vec3 u_base; uniform vec4 u_mat; uniform vec2 u_coat; uniform vec3 u_dnf;
IN vec3 v_n; IN vec3 v_p; IN vec2 v_uv; IN vec2 v_uv1;

float box(float x, float a, float b, float soft) { return smoothstep(a - soft, a + soft, x) * (1.0 - smoothstep(b - soft, b + soft, x)); }
// the photo studio, its lights spread and dimmed as the surface gets rougher (r 0 sharp .. 1 diffuse)
vec3 studio(vec3 d, float r) {
    float s = r * r, k = 1.0 / (1.0 + 5.0 * s), e = 0.9 * s;
    float up = d.y * 0.5 + 0.5;
    vec3 c = mix(vec3(0.008, 0.008, 0.009), vec3(0.07, 0.071, 0.075), smoothstep(0.2 - e, 0.9 + e, up));
    c += vec3(2.0) * k * smoothstep(0.6 - e, 0.8 + e * 0.5, d.y) * box(d.x, -0.55, 0.55, 0.12 + e) * box(d.z, -0.2, 0.9, 0.15 + e);
    c += vec3(1.05, 1.03, 1.0) * k * smoothstep(0.78 - e, 0.9 + e * 0.2, -d.x) * box(d.y, -0.3, 0.65, 0.12 + e);
    c += vec3(0.38, 0.40, 0.45) * k * smoothstep(0.8 - e, 0.92 + e * 0.2, d.x) * box(d.y, -0.2, 0.6, 0.15 + e);
    c += vec3(0.05) * smoothstep(0.8 - e, 0.97, d.z);
    return c + vec3(0.12) * s;
}
vec3 lin(vec3 g) { return pow(g, vec3(2.2)); }
vec3 srgb(vec3 l) { return pow(clamp(l, 0.0, 1.0), vec3(1.0 / 2.2)); }
vec3 tone(vec3 c) { return c * (2.51 * c + 0.03) / (c * (2.43 * c + 0.59) + 0.14); }
vec2 uvOf(int i) { vec2 uv = u_ts[i].y > 0.5 ? v_uv1 : v_uv; return vec2(uv.x, 1.0 - uv.y); }
float chan(vec4 t, float c) { return c < 0.5 ? t.r : c < 1.5 ? t.g : c < 2.5 ? t.b : t.a; }

void main() {
    vec3 n = normalize(v_n);
    vec3 v = normalize(vec3(0.0, 0.0, u_dnf.x) - v_p);
    if (dot(n, v) < 0.0) n = -n;
    if (u_coat.y > 0.5) {
        // a screen: its picture as emitted light under cover glass
        vec3 pic = lin(TEX(u_pic, vec2(v_uv.x, 1.0 - v_uv.y)).rgb);
        float fr = pow(1.0 - max(dot(n, v), 0.0), 5.0);
        FRAG = vec4(srgb(pic + studio(reflect(-v, n), 0.0) * (0.04 + 0.96 * fr) * 0.3), 1.0);
        return;
    }
    if (u_ts[4].x > 0.5) {
        // the normal map, in a tangent frame from the uv set's derivatives
        vec2 uv = u_ts[4].y > 0.5 ? v_uv1 : v_uv;
        vec3 dp1 = dFdx(v_p), dp2 = dFdy(v_p);
        vec2 du1 = dFdx(uv), du2 = dFdy(uv);
        vec3 p2 = cross(dp2, n), p1 = cross(n, dp1);
        vec3 t = p2 * du1.x + p1 * du2.x, b = p2 * du1.y + p1 * du2.y;
        float m = max(dot(t, t), dot(b, b));
        if (m > 1e-20) {
            vec3 tn = TEX(u_t4, uvOf(4)).rgb * u_nscale.xyz + u_nbias.xyz;
            n = normalize(mat3(t * inversesqrt(m), b * inversesqrt(m), n) * tn);
        }
    }
    vec3 base = u_base * (u_ts[0].x > 0.5 ? lin(TEX(u_t0, uvOf(0)).rgb) : vec3(1.0));
    float metal = u_ts[1].x > 0.5 ? chan(TEX(u_t1, uvOf(1)), u_ts[1].z) : u_mat.x;
    float rough = clamp(u_ts[2].x > 0.5 ? chan(TEX(u_t2, uvOf(2)), u_ts[2].z) : u_mat.y, 0.02, 1.0);
    float occ = u_ts[3].x > 0.5 ? chan(TEX(u_t3, uvOf(3)), u_ts[3].z) : 1.0;
    float opac = u_ts[5].x > 0.5 ? chan(TEX(u_t5, uvOf(5)), u_ts[5].z) : u_mat.z;
    vec3 r = reflect(-v, n);
    float fr = pow(1.0 - max(dot(n, v), 0.0), 5.0);
    vec3 f0 = mix(vec3(0.04), base, metal);
    vec3 f = f0 + (max(vec3(1.0 - rough), f0) - f0) * fr;
    vec3 col = (base * (1.0 - metal) * studio(n, 1.0) * 1.6 + f * studio(r, rough)) * mix(0.35, 1.0, occ);
    // the clear coat: a second, smooth reflection over it
    float fc = (0.04 + 0.96 * fr) * u_mat.w;
    vec3 coat = studio(r, u_coat.x) * fc;
    col = col * (1.0 - fc) + coat;
    float a = clamp(opac, 0.0, 1.0);
    // premultiplied: a see-through surface still shows its reflections
    vec3 pm = col * a + coat * (1.0 - a);
    FRAG = vec4(srgb(tone(pm)), clamp(a + fc * 0.5, 0.0, 1.0));
}
"#;

const QVS: &str = r#"
IN vec2 a_p; OUT vec2 v_uv;
void main() { v_uv = a_p * 0.5 + 0.5; gl_Position = vec4(a_p, 0.0, 1.0); }
"#;
const QFS: &str = r#"
uniform sampler2D u_img; IN vec2 v_uv;
void main() { FRAG = TEX(u_img, v_uv); }
"#;

unsafe fn program(gl: &glow::Context, vs: &str, fs: &str, attrs: &[&str]) -> Result<glow::Program, String> {
    unsafe {
        let ver = egui_glow::ShaderVersion::get(gl);
        let new = ver.is_new_shader_interface();
        let prec = if ver.is_embedded() { "precision highp float;\n" } else { "" };
        let head_v = format!("{}{prec}#define IN {}\n#define OUT {}\n", ver.version_declaration(), if new { "in" } else { "attribute" }, if new { "out" } else { "varying" });
        let head_f = format!(
            "{}{prec}#define IN {}\n#define TEX {}\n{}",
            ver.version_declaration(),
            if new { "in" } else { "varying" },
            if new { "texture" } else { "texture2D" },
            if new { "out vec4 f_color;\n#define FRAG f_color\n" } else { "#define FRAG gl_FragColor\n" }
        );
        let p = gl.create_program()?;
        let mut shaders = vec![];
        for (kind, src) in [(glow::VERTEX_SHADER, head_v + vs), (glow::FRAGMENT_SHADER, head_f + fs)] {
            let s = gl.create_shader(kind)?;
            gl.shader_source(s, &src);
            gl.compile_shader(s);
            if !gl.get_shader_compile_status(s) {
                return Err(gl.get_shader_info_log(s));
            }
            gl.attach_shader(p, s);
            shaders.push(s);
        }
        for (i, a) in attrs.iter().enumerate() {
            gl.bind_attrib_location(p, i as u32, a);
        }
        gl.link_program(p);
        if !gl.get_program_link_status(p) {
            return Err(gl.get_program_info_log(p));
        }
        for s in shaders {
            gl.detach_shader(p, s);
            gl.delete_shader(s);
        }
        Ok(p)
    }
}

unsafe fn make(gl: &glow::Context) -> Result<Gl, String> {
    unsafe {
        let quad = program(gl, QVS, QFS, &["a_p"])?;
        let quad_vao = gl.create_vertex_array()?;
        let quad_vbo = gl.create_buffer()?;
        gl.bind_vertex_array(Some(quad_vao));
        gl.bind_buffer(glow::ARRAY_BUFFER, Some(quad_vbo));
        let q: [f32; 8] = [-1.0, -1.0, 1.0, -1.0, -1.0, 1.0, 1.0, 1.0];
        gl.buffer_data_u8_slice(glow::ARRAY_BUFFER, std::slice::from_raw_parts(q.as_ptr() as *const u8, 32), glow::STATIC_DRAW);
        gl.enable_vertex_attrib_array(0);
        gl.vertex_attrib_pointer_f32(0, 2, glow::FLOAT, false, 8, 0);
        gl.bind_vertex_array(None);
        let fbo = gl.create_framebuffer()?;
        let color = gl.create_texture()?;
        let depth = gl.create_renderbuffer()?;
        let black = gl.create_texture()?;
        gl.bind_texture(glow::TEXTURE_2D, Some(black));
        gl.tex_image_2d(glow::TEXTURE_2D, 0, glow::RGBA as i32, 1, 1, 0, glow::RGBA, glow::UNSIGNED_BYTE, glow::PixelUnpackData::Slice(Some(&[0, 0, 0, 255])));
        gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_MIN_FILTER, glow::NEAREST as i32);
        gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_MAG_FILTER, glow::NEAREST as i32);
        Ok(Gl { quad, quad_vao, quad_vbo, fbo, color, depth, size: (0, 0), black, model: None })
    }
}

/// The model's program, buffers and textures
unsafe fn make_model(gl: &glow::Context, m: &Model) -> Result<ModelGl, String> {
    unsafe {
        let prog = program(gl, AVS, AFS, &["a_p", "a_n", "a_uv", "a_uv1", "a_j", "a_w"])?;
        let vao = gl.create_vertex_array()?;
        let vbo = gl.create_buffer()?;
        let ibo = gl.create_buffer()?;
        gl.bind_vertex_array(Some(vao));
        gl.bind_buffer(glow::ARRAY_BUFFER, Some(vbo));
        let vb = std::slice::from_raw_parts(m.v.as_ptr() as *const u8, m.v.len() * std::mem::size_of::<devicemodel::Vtx>());
        gl.buffer_data_u8_slice(glow::ARRAY_BUFFER, vb, glow::STATIC_DRAW);
        let stride = std::mem::size_of::<devicemodel::Vtx>() as i32;
        gl.enable_vertex_attrib_array(0);
        gl.vertex_attrib_pointer_f32(0, 3, glow::FLOAT, false, stride, 0);
        gl.enable_vertex_attrib_array(1);
        gl.vertex_attrib_pointer_f32(1, 3, glow::SHORT, true, stride, 12);
        gl.enable_vertex_attrib_array(2);
        gl.vertex_attrib_pointer_f32(2, 2, glow::FLOAT, false, stride, 20);
        gl.enable_vertex_attrib_array(3);
        gl.vertex_attrib_pointer_f32(3, 2, glow::FLOAT, false, stride, 28);
        gl.enable_vertex_attrib_array(4);
        gl.vertex_attrib_pointer_f32(4, 4, glow::UNSIGNED_BYTE, false, stride, 36);
        gl.enable_vertex_attrib_array(5);
        gl.vertex_attrib_pointer_f32(5, 4, glow::UNSIGNED_BYTE, true, stride, 40);
        gl.bind_buffer(glow::ELEMENT_ARRAY_BUFFER, Some(ibo));
        let ib = std::slice::from_raw_parts(m.i.as_ptr() as *const u8, m.i.len() * 4);
        gl.buffer_data_u8_slice(glow::ELEMENT_ARRAY_BUFFER, ib, glow::STATIC_DRAW);
        gl.bind_vertex_array(None);
        let mut textures = vec![];
        for im in &m.images {
            let t = gl.create_texture()?;
            gl.bind_texture(glow::TEXTURE_2D, Some(t));
            let (w, h, px) = im.rgba().unwrap_or((1, 1, vec![255; 4]));
            gl.tex_image_2d(glow::TEXTURE_2D, 0, glow::RGBA8 as i32, w as i32, h as i32, 0, glow::RGBA, glow::UNSIGNED_BYTE, glow::PixelUnpackData::Slice(Some(&px)));
            gl.generate_mipmap(glow::TEXTURE_2D);
            gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_MIN_FILTER, glow::LINEAR_MIPMAP_LINEAR as i32);
            gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_MAG_FILTER, glow::LINEAR as i32);
            gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_WRAP_S, glow::REPEAT as i32);
            gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_WRAP_T, glow::REPEAT as i32);
            textures.push(t);
        }
        gl.bind_texture(glow::TEXTURE_2D, None);
        Ok(ModelGl { prog, vao, textures, of: m as *const Model as usize })
    }
}

/// Draws the model: the opaque groups, the screens a little nearer (their glass lies on the frame's), then the
/// see-through ones blended without depth writes
#[allow(clippy::too_many_arguments)]
unsafe fn draw(gl: &glow::Context, a: &ModelGl, m: &Model, bones: &[[f32; 16]], f: &Frame, black: glow::Texture, inner: glow::Texture, outer: glow::Texture) {
    unsafe {
        gl.use_program(Some(a.prog));
        let u = |n: &str| gl.get_uniform_location(a.prog, n);
        gl.uniform_matrix_3_f32_slice(u("u_rot").as_ref(), false, &f.rot);
        gl.uniform_3_f32(u("u_c").as_ref(), f.centre[0], f.centre[1], f.centre[2]);
        gl.uniform_4_f32(u("u_fit").as_ref(), f.fit[0], f.fit[1], f.fit[2], f.fit[3]);
        gl.uniform_3_f32(u("u_dnf").as_ref(), f.dnf[0], f.dnf[1], f.dnf[2]);
        let flat: Vec<f32> = bones.iter().take(32).flatten().copied().collect();
        gl.uniform_matrix_4_f32_slice(u("u_bones").as_ref(), false, &flat);
        for k in 0..6 {
            gl.uniform_1_i32(u(&format!("u_t{k}")).as_ref(), k);
        }
        gl.uniform_1_i32(u("u_pic").as_ref(), 6);
        let (l_ts, l_ns, l_nb, l_base, l_mat, l_coat) = (u("u_ts"), u("u_nscale"), u("u_nbias"), u("u_base"), u("u_mat"), u("u_coat"));
        gl.bind_vertex_array(Some(a.vao));
        for (gi, g) in m.groups.iter().enumerate() {
            let mt = &m.mats[g.mat];
            let slots = [&mt.base_tex, &mt.metallic_tex, &mt.roughness_tex, &mt.occlusion_tex, &mt.normal_tex, &mt.opacity_tex];
            let mut ts = [0f32; 18];
            for (k, t) in slots.iter().enumerate() {
                gl.active_texture(glow::TEXTURE0 + k as u32);
                match t {
                    Some(t) => {
                        gl.bind_texture(glow::TEXTURE_2D, a.textures.get(t.image).copied().or(Some(black)));
                        ts[k * 3] = 1.0;
                        ts[k * 3 + 1] = t.uv as f32;
                        ts[k * 3 + 2] = t.channel as f32;
                    }
                    None => gl.bind_texture(glow::TEXTURE_2D, Some(black)),
                }
            }
            gl.active_texture(glow::TEXTURE6);
            gl.bind_texture(glow::TEXTURE_2D, Some(if mt.screen == 1 { inner } else { outer }));
            gl.uniform_3_f32_slice(l_ts.as_ref(), &ts);
            let nt = mt.normal_tex.clone().unwrap_or_default();
            gl.uniform_4_f32_slice(l_ns.as_ref(), &nt.scale);
            gl.uniform_4_f32_slice(l_nb.as_ref(), &nt.bias);
            gl.uniform_3_f32_slice(l_base.as_ref(), &mt.base);
            gl.uniform_4_f32(l_mat.as_ref(), mt.metallic, mt.roughness, mt.opacity, mt.clearcoat);
            gl.uniform_2_f32(l_coat.as_ref(), mt.clearcoat_roughness, if mt.screen > 0 { 1.0 } else { 0.0 });
            let blended = gi >= m.opaque;
            if blended {
                gl.enable(glow::BLEND);
                gl.blend_func(glow::ONE, glow::ONE_MINUS_SRC_ALPHA);
                gl.depth_mask(false);
            }
            if mt.screen > 0 {
                gl.enable(glow::POLYGON_OFFSET_FILL);
                gl.polygon_offset(-1.0, -4.0);
            }
            gl.draw_elements(glow::TRIANGLES, g.count as i32, glow::UNSIGNED_INT, (g.start * 4) as i32);
            gl.disable(glow::POLYGON_OFFSET_FILL);
            if blended {
                gl.disable(glow::BLEND);
                gl.depth_mask(true);
            }
        }
        gl.bind_vertex_array(None);
        for k in (0..7).rev() {
            gl.active_texture(glow::TEXTURE0 + k);
            gl.bind_texture(glow::TEXTURE_2D, None);
        }
    }
}

unsafe fn resize(gl: &glow::Context, g: &mut Gl, w: i32, h: i32) {
    unsafe {
        if g.size == (w, h) {
            return;
        }
        g.size = (w, h);
        gl.bind_texture(glow::TEXTURE_2D, Some(g.color));
        gl.tex_image_2d(glow::TEXTURE_2D, 0, glow::RGBA8 as i32, w, h, 0, glow::RGBA, glow::UNSIGNED_BYTE, glow::PixelUnpackData::Slice(None));
        gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_MIN_FILTER, glow::LINEAR as i32);
        gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_MAG_FILTER, glow::LINEAR as i32);
        gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_WRAP_S, glow::CLAMP_TO_EDGE as i32);
        gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_WRAP_T, glow::CLAMP_TO_EDGE as i32);
        gl.bind_renderbuffer(glow::RENDERBUFFER, Some(g.depth));
        gl.renderbuffer_storage(glow::RENDERBUFFER, glow::DEPTH_COMPONENT24, w, h);
        gl.bind_framebuffer(glow::FRAMEBUFFER, Some(g.fbo));
        gl.framebuffer_texture_2d(glow::FRAMEBUFFER, glow::COLOR_ATTACHMENT0, glow::TEXTURE_2D, Some(g.color), 0);
        gl.framebuffer_renderbuffer(glow::FRAMEBUFFER, glow::DEPTH_ATTACHMENT, glow::RENDERBUFFER, Some(g.depth));
    }
}

impl Target {
    /// The paint callback drawing `frame` into the callback's rect
    pub fn callback(&self, frame: Frame) -> egui_glow::CallbackFn {
        let target = self.clone();
        let frame = Arc::new(frame);
        egui_glow::CallbackFn::new(move |info, painter| {
            let gl = painter.gl();
            let mut st = target.0.lock().unwrap();
            if st.is_none() {
                *st = Some(unsafe { make(gl) }.map_err(|e| eprintln!("duo3d: OpenGL setup failed: {e}")));
            }
            let Some(Ok(g)) = st.as_mut() else { return };
            let vp = info.viewport_in_pixels();
            let (w, h) = ((vp.width_px * 2).clamp(1, 8192), (vp.height_px * 2).clamp(1, 8192));
            let f = &frame;
            let black = g.black;
            let tex = |id: Option<egui::TextureId>| id.and_then(|i| painter.texture(i)).unwrap_or(black);
            unsafe {
                let prev_fbo = gl.get_parameter_i32(glow::DRAW_FRAMEBUFFER_BINDING);
                resize(gl, g, w, h);
                gl.bind_framebuffer(glow::FRAMEBUFFER, Some(g.fbo));
                gl.viewport(0, 0, w, h);
                gl.disable(glow::SCISSOR_TEST);
                gl.disable(glow::BLEND);
                gl.disable(glow::CULL_FACE);
                gl.enable(glow::DEPTH_TEST);
                gl.depth_func(glow::LEQUAL);
                gl.depth_mask(true);
                gl.clear_color(0.0, 0.0, 0.0, 0.0);
                gl.clear_depth_f32(1.0);
                gl.clear(glow::COLOR_BUFFER_BIT | glow::DEPTH_BUFFER_BIT);
                let ptr = Arc::as_ptr(&f.model) as usize;
                if !matches!(&g.model, Some(Ok(a)) if a.of == ptr) && !matches!(&g.model, Some(Err(()))) {
                    g.model = Some(make_model(gl, &f.model).map_err(|e| eprintln!("duo3d: OpenGL setup for the model failed: {e}")));
                }
                if let Some(Ok(a)) = &g.model {
                    draw(gl, a, &f.model, &f.bones, f, black, tex(f.inner), tex(f.outer));
                }
                // the picture, shrunk into the area over egui's drawing
                let prev = (prev_fbo > 0).then(|| glow::NativeFramebuffer(std::num::NonZeroU32::new(prev_fbo as u32).unwrap()));
                gl.bind_framebuffer(glow::FRAMEBUFFER, prev);
                gl.viewport(vp.left_px, vp.from_bottom_px, vp.width_px, vp.height_px);
                let clip = info.clip_rect_in_pixels();
                gl.enable(glow::SCISSOR_TEST);
                gl.scissor(clip.left_px, clip.from_bottom_px, clip.width_px, clip.height_px);
                gl.disable(glow::DEPTH_TEST);
                gl.enable(glow::BLEND);
                gl.blend_func(glow::ONE, glow::ONE_MINUS_SRC_ALPHA);
                gl.use_program(Some(g.quad));
                gl.uniform_1_i32(gl.get_uniform_location(g.quad, "u_img").as_ref(), 0);
                gl.bind_texture(glow::TEXTURE_2D, Some(g.color));
                gl.bind_vertex_array(Some(g.quad_vao));
                gl.draw_arrays(glow::TRIANGLE_STRIP, 0, 4);
                gl.bind_vertex_array(None);
                let _ = g.quad_vbo;
            }
        })
    }
}
