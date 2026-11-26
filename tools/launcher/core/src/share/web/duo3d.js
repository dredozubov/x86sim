"use strict";
// The iPhone Duo in 3D on the web page, as the launcher draws it (gui/src/duo3d.rs, duo3d/gpu.rs, ported here):
// Apple's own model (/devicemodel/duo: Xcode's, from the user's own Xcode.xip, never public; core devicemodel.rs),
// skinned on the GPU with its materials. Without it the page shows the phone flat (app.js). The inner screen is one
// panel across both fronts, the outer screen on the back of the left half, each the phone's live picture (the
// socket's two streams: kind 1 / 2 the inner screen, 17 / 18 the outer one). The right half turns about the hinge by 180 - angle; the device orientation turns the whole
// phone. Touches on the drawn screens are traced back through the camera onto the screen under them (DuoMap) and go
// to the phone as {s: "inner" | "outer", x, y} on that screen's picture. WebGL2, no library.
//
// The view: a drag with the right or middle button (or Alt, or anywhere off the screens) turns it, the wheel with the
// right button / Alt (or off the screens, or a touchpad pinch) zooms, a double right click resets. Fingers: a gesture
// that starts off the screens turns (one finger) or zooms (two); a double tap with two fingers there resets.
(function () {
  // ---- the phone's space (duo3d/geom.rs): sizes in inner-screen pixels
  const INNER = [2853, 2007], OUTER = [1398, 2034], BEZEL = 46;
  const HALF_W = INNER[0] / 2 + BEZEL, HALF_H = OUTER[1] + 2 * BEZEL;
  // SPEED: at most this many degrees a second; HINGE_RATE: how fast the drawn hinge closes on its target (an eased
  // follow, so a slider's step every 40 ms draws one smooth sweep, not a dash and a stop per step)
  const SPEED = 300, SETTLE = 7, HINGE_RATE = 14;
  const rad = (d) => d * Math.PI / 180;
  const add = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
  function rotX(p, a) { const s = Math.sin(a), c = Math.cos(a); return [p[0], p[1] * c - p[2] * s, p[1] * s + p[2] * c]; }
  function rotY(p, a) { const s = Math.sin(a), c = Math.cos(a); return [p[0] * c - p[2] * s, p[1], p[0] * s + p[2] * c]; }
  function rotZ(p, a) { const s = Math.sin(a), c = Math.cos(a); return [p[0] * c - p[1] * s, p[0] * s + p[1] * c, p[2]]; }

  // ---- the model (devicemodel.rs Model::web): "X86M", a u32 header length, the JSON header, then the vertices
  // (48 bytes: position f32x3, normal i16x4, st f32x2, st1 f32x2, joints u8x4, weights u8x4, material u16, pad), the
  // u32 indices, the joint matrices (frames x joints x 16 f32, column-major; 1.5 degrees of bend a frame from flat)
  // and the images
  function parseModel(buf) {
    const dv = new DataView(buf);
    if (buf.byteLength < 8 || dv.getUint32(0, true) !== 0x4d363858) return null;
    const hl = dv.getUint32(4, true), head = JSON.parse(new TextDecoder().decode(new Uint8Array(buf, 8, hl))), base = 8 + hl;
    const [va, vn] = head.verts, [ia, iN] = head.indices, [fa, fN] = head.frames, J = head.joints;
    return { head, J, nv: vn, vbytes: new Uint8Array(buf, base + va, vn * 48), vf: new Float32Array(buf, base + va, vn * 12),
      vu8: new Uint8Array(buf, base + va, vn * 48), idx: new Uint32Array(buf, base + ia, iN), frames: new Float32Array(buf, base + fa, fN * J * 16),
      nFrames: fN, images: head.images.map((im) => new Blob([new Uint8Array(buf, base + im.at, im.len)], { type: im.mime })) };
  }
  // the joint matrices at hinge angle deg: the frames either side blended
  function poseOf(M, deg) {
    const f = Math.min(M.nFrames - 1, Math.max(0, (180 - Math.min(180, Math.max(0, deg))) / M.head.degPerFrame));
    const a = Math.floor(f), b = Math.min(a + 1, M.nFrames - 1), t = f - a, n = M.J * 16, out = new Float32Array(n);
    for (let k = 0; k < n; k++) out[k] = M.frames[a * n + k] + (M.frames[b * n + k] - M.frames[a * n + k]) * t;
    return out;
  }
  // vertex k posed (into out at o)
  function skin(M, bones, k, out, o) {
    const f = M.vf, u = M.vu8, x = f[k * 12], y = f[k * 12 + 1], z = f[k * 12 + 2];
    let px = 0, py = 0, pz = 0;
    for (let s = 0; s < 4; s++) {
      const w = u[k * 48 + 40 + s] / 255;
      if (!w) continue;
      const b = u[k * 48 + 36 + s] * 16;
      px += w * (x * bones[b] + y * bones[b + 4] + z * bones[b + 8] + bones[b + 12]);
      py += w * (x * bones[b + 1] + y * bones[b + 5] + z * bones[b + 9] + bones[b + 13]);
      pz += w * (x * bones[b + 2] + y * bones[b + 6] + z * bones[b + 10] + bones[b + 14]);
    }
    out[o] = px; out[o + 1] = py; out[o + 2] = pz;
  }
  function appleHitMesh(M, bones) {
    const p = new Float32Array(M.nv * 3), uv = new Float32Array(M.nv * 2);
    for (let k = 0; k < M.nv; k++) { skin(M, bones, k, p, k * 3); uv[k * 2] = M.vf[k * 12 + 5]; uv[k * 2 + 1] = M.vf[k * 12 + 6]; }
    const tris = [], kinds = [];
    for (const [mi, start, count] of M.head.groups) {
      const mt = M.head.mats[mi];
      if (!mt.occludes) continue;
      for (let t = start; t < start + count; t += 3) { tris.push(M.idx[t], M.idx[t + 1], M.idx[t + 2]); kinds.push(mt.screen); }
    }
    return { p, uv, i: new Uint32Array(tris), kind: new Uint8Array(kinds) };
  }
  // the nearest triangle the ray meets in front of it (with `only`, that screen's alone): {screen, t, x, y} on a
  // screen's picture (y down), null when the body is in front
  function trace(H, o, d, only) {
    let best = -1, bt = Infinity, bu = 0, bw = 0;
    const P = H.p, I = H.i;
    for (let t = 0, n = H.kind.length; t < n; t++) {
      if (only && H.kind[t] !== only) continue;
      const a = I[t * 3] * 3, b = I[t * 3 + 1] * 3, c = I[t * 3 + 2] * 3;
      const e1x = P[b] - P[a], e1y = P[b + 1] - P[a + 1], e1z = P[b + 2] - P[a + 2];
      const e2x = P[c] - P[a], e2y = P[c + 1] - P[a + 1], e2z = P[c + 2] - P[a + 2];
      const hx = d[1] * e2z - d[2] * e2y, hy = d[2] * e2x - d[0] * e2z, hz = d[0] * e2y - d[1] * e2x;
      const det = e1x * hx + e1y * hy + e1z * hz;
      if (Math.abs(det) < 1e-12) continue;
      const f = 1 / det, sx = o[0] - P[a], sy = o[1] - P[a + 1], sz = o[2] - P[a + 2];
      const u = f * (sx * hx + sy * hy + sz * hz);
      if (u < -1e-4 || u > 1.0001) continue;
      const qx = sy * e1z - sz * e1y, qy = sz * e1x - sx * e1z, qz = sx * e1y - sy * e1x;
      const w = f * (d[0] * qx + d[1] * qy + d[2] * qz);
      if (w < -1e-4 || u + w > 1.0001) continue;
      const tt = f * (e2x * qx + e2y * qy + e2z * qz);
      if (tt > 0 && tt < bt) { bt = tt; best = t; bu = u; bw = w; }
    }
    if (best < 0 || !H.kind[best]) return null;
    const U = H.uv, a = I[best * 3] * 2, b = I[best * 3 + 1] * 2, c = I[best * 3 + 2] * 2;
    const x = U[a] + (U[b] - U[a]) * bu + (U[c] - U[a]) * bw, v = U[a + 1] + (U[b + 1] - U[a + 1]) * bu + (U[c + 1] - U[a + 1]) * bw;
    return { screen: H.kind[best], t: bt, x, y: 1 - v };
  }

  // ---- pose and camera (duo3d.rs)
  const rollKnown = (o) => o === "portrait" || o === "portraitUpsideDown" || o === "landscapeLeft" || o === "landscapeRight";
  const wrap = (a) => ((a + Math.PI) % (2 * Math.PI) + 2 * Math.PI) % (2 * Math.PI) - Math.PI;
  function rollOf(o) { return o === "landscapeLeft" ? rad(90) : o === "landscapeRight" ? rad(-90) : o === "portraitUpsideDown" ? Math.PI : 0; }
  function placement(o, phi) {
    return [rollOf(o), o === "landscapeLeft" ? -Math.PI / 2 : o === "landscapeRight" ? phi - Math.PI / 2 : 0];
  }
  // how much the default view faces the inner screen: 0 folded, 1 open, eased over from 55° up to SpringBoard's swap
  // angle (85°), so the inner screen is faced straight from where it is in use (half open at 90° is a book)
  function innerWeight(deg) { const t = Math.max(0, Math.min(1, (deg - 55) / 30)); return t * t * (3 - 2 * t); }
  // the default camera: a function of the hinge angle alone, so a slide or a pose is followed in one smooth move
  function defaultView(o, deg, phi) {
    const w = innerWeight(deg), k = Math.max(Math.sin(phi), 0);
    // landscape: the outer screen (the left half's back) faces up in landscape right, down in landscape left
    if (o === "landscapeLeft" || o === "landscapeRight") { const out = o === "landscapeLeft" ? -70 : 70; return [rad(-12 * k), rad(out + (28 - out) * w)]; }
    // the inner screen's bisector turns by -phi/2, the outer screen faces -z: round the left half's edge
    const y = -phi / 2 + (1 - w) * (-Math.PI + phi / 2);
    const n = rotZ([Math.sin(y), 0, Math.cos(y)], rollOf(o));
    const yaw = Math.atan2(n[0], n[2]), pitch = Math.atan2(n[1], Math.hypot(n[0], n[2]));
    return [yaw + rad(-14 * k), Math.max(-1.5, Math.min(1.5, pitch + rad(10 * k)))];
  }


  // ---- drawing (gpu.rs), GLSL ES 3.00
  // skinned, UsdPreviewSurface lit by a photo studio around the camera (gpu.rs AVS / AFS, the same source)
  const AVS = `#version 300 es
precision highp float;
uniform mat3 u_rot; uniform vec3 u_c; uniform vec4 u_fit; uniform vec3 u_dnf;
uniform mat4 u_bones[32]; uniform float u_lift;
in vec3 a_p; in vec3 a_n; in vec2 a_uv; in vec2 a_uv1; in vec4 a_j; in vec4 a_w;
out vec3 v_n; out vec3 v_p; out vec2 v_uv; out vec2 v_uv1;
void main() {
    mat4 sk = u_bones[int(a_j.x)] * a_w.x + u_bones[int(a_j.y)] * a_w.y + u_bones[int(a_j.z)] * a_w.z + u_bones[int(a_j.w)] * a_w.w;
    vec3 p = u_rot * (sk * vec4(a_p, 1.0)).xyz - u_c;
    // the screens lie on a black panel in the same plane (other triangles): lifted toward the camera by u_lift (half
    // a panel pixel) so the panel never shows through, whatever the depth buffer's precision or polygon offset
    p.z += u_lift;
    float w = u_dnf.x - p.z;
    // depth as a perspective projection's: an affine function of 1/w, so it interpolates exactly across a triangle
    // (one linear in w drifted by tens of units inside large tilted triangles: the panel came through in patches)
    float n = u_dnf.y, f = u_dnf.z;
    gl_Position = vec4(p.x * u_dnf.x * u_fit.x + u_fit.z * w, p.y * u_dnf.x * u_fit.y + u_fit.w * w,
        ((f + n) * w - 2.0 * f * n) / (f - n), w);
    v_n = u_rot * (mat3(sk) * a_n); v_p = p; v_uv = a_uv; v_uv1 = a_uv1;
}
`;
  const AFS = `#version 300 es
precision highp float;
out vec4 frag;
uniform sampler2D u_t0; uniform sampler2D u_t1; uniform sampler2D u_t2; uniform sampler2D u_t3; uniform sampler2D u_t4;
uniform sampler2D u_t5; uniform sampler2D u_pic;
// per texture slot (base, metallic, roughness, occlusion, normal, opacity): has, uv set, channel
uniform vec3 u_ts[6];
uniform vec4 u_nscale; uniform vec4 u_nbias;
uniform vec3 u_base; uniform vec4 u_mat; uniform vec2 u_coat; uniform vec3 u_dnf;
in vec3 v_n; in vec3 v_p; in vec2 v_uv; in vec2 v_uv1;

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
        vec3 pic = lin(texture(u_pic, vec2(v_uv.x, 1.0 - v_uv.y)).rgb);
        float fr = pow(1.0 - max(dot(n, v), 0.0), 5.0);
        frag = vec4(srgb(pic + studio(reflect(-v, n), 0.0) * (0.04 + 0.96 * fr) * 0.3), 1.0);
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
            vec3 tn = texture(u_t4, uvOf(4)).rgb * u_nscale.xyz + u_nbias.xyz;
            n = normalize(mat3(t * inversesqrt(m), b * inversesqrt(m), n) * tn);
        }
    }
    vec3 base = u_base * (u_ts[0].x > 0.5 ? lin(texture(u_t0, uvOf(0)).rgb) : vec3(1.0));
    float metal = u_ts[1].x > 0.5 ? chan(texture(u_t1, uvOf(1)), u_ts[1].z) : u_mat.x;
    float rough = clamp(u_ts[2].x > 0.5 ? chan(texture(u_t2, uvOf(2)), u_ts[2].z) : u_mat.y, 0.02, 1.0);
    float occ = u_ts[3].x > 0.5 ? chan(texture(u_t3, uvOf(3)), u_ts[3].z) : 1.0;
    float opac = u_ts[5].x > 0.5 ? chan(texture(u_t5, uvOf(5)), u_ts[5].z) : u_mat.z;
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
    frag = vec4(srgb(tone(pm)), clamp(a + fc * 0.5, 0.0, 1.0));
}
`;

  function glOf(canvas) {
    try { return canvas.getContext("webgl2", { antialias: true, alpha: true, premultipliedAlpha: true, preserveDrawingBuffer: false, powerPreference: "default" }); } catch { return null; }
  }
  function supported() {
    if (/[?&]flat=1/.test(location.search)) return false;
    const gl = glOf(document.createElement("canvas"));
    if (!gl) return false;
    const lose = gl.getExtension("WEBGL_lose_context");
    if (lose) lose.loseContext();
    return true;
  }

  function program(gl, vs, fs, attrs) {
    const p = gl.createProgram();
    for (const [kind, src] of [[gl.VERTEX_SHADER, vs], [gl.FRAGMENT_SHADER, fs]]) {
      const s = gl.createShader(kind);
      gl.shaderSource(s, src);
      gl.compileShader(s);
      if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s));
      gl.attachShader(p, s);
    }
    attrs.forEach((a, i) => gl.bindAttribLocation(p, i, a));
    gl.linkProgram(p);
    if (!gl.getProgramParameter(p, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(p));
    return p;
  }

  // the model, fetched once per page: null when the server has none (the page then shows the phone flat)
  let loading = null;
  function load() {
    if (!loading) loading = fetch("/devicemodel/duo", { credentials: "same-origin" }).then((r) => (r.ok ? r.arrayBuffer() : null))
      .then((buf) => buf && parseModel(buf)).catch(() => null);
    return loading;
  }

  // ---- one phone's view
  // opts: model (load()'s), control (touches go to the phone), send(obj), codec ("h264" | "jpeg"), onFrame(w, h) (an
  // inner or outer picture shown), onNoH264() (this browser can't decode the stream)
  function create(opts) {
    const canvas = document.createElement("canvas");
    canvas.className = "duo3d";
    canvas.tabIndex = opts.control ? 0 : -1;
    const shadow = document.createElement("div");
    shadow.className = "duoshadow";
    const el = document.createElement("div");
    el.className = "duo3dwrap";
    el.append(shadow, canvas);
    const gl = glOf(canvas);
    if (!gl) return null;
    const M = opts.model;
    const aniso = gl.getExtension("EXT_texture_filter_anisotropic");

    // the model's GL objects, once its textures are decoded (nothing is drawn until then)
    let apple = null;
    async function appleGL(M) {
      const p = program(gl, AVS, AFS, ["a_p", "a_n", "a_uv", "a_uv1", "a_j", "a_w"]);
      const U = {};
      for (const n of ["u_rot", "u_c", "u_fit", "u_dnf", "u_bones", "u_ts", "u_nscale", "u_nbias", "u_base", "u_mat", "u_coat", "u_lift", "u_pic", "u_t0", "u_t1", "u_t2", "u_t3", "u_t4", "u_t5"]) U[n] = gl.getUniformLocation(p, n);
      const vao = gl.createVertexArray(), vb = gl.createBuffer(), ib = gl.createBuffer();
      gl.bindVertexArray(vao);
      gl.bindBuffer(gl.ARRAY_BUFFER, vb);
      gl.bufferData(gl.ARRAY_BUFFER, M.vbytes, gl.STATIC_DRAW);
      [[3, gl.FLOAT, false, 0], [3, gl.SHORT, true, 12], [2, gl.FLOAT, false, 20], [2, gl.FLOAT, false, 28], [4, gl.UNSIGNED_BYTE, false, 36], [4, gl.UNSIGNED_BYTE, true, 40]]
        .forEach(([n, t, norm, off], i) => { gl.enableVertexAttribArray(i); gl.vertexAttribPointer(i, n, t, norm, 48, off); });
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ib);
      gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, M.idx, gl.STATIC_DRAW);
      gl.bindVertexArray(null);
      const bitmaps = await Promise.all(M.images.map((b) => createImageBitmap(b, { imageOrientation: "none", premultiplyAlpha: "none", colorSpaceConversion: "none" }).catch(() => null)));
      const tex = bitmaps.map((bm) => {
        const t = gl.createTexture();
        gl.bindTexture(gl.TEXTURE_2D, t);
        if (bm) gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, bm);
        else gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array([255, 255, 255, 255]));
        gl.generateMipmap(gl.TEXTURE_2D);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
        if (bm) bm.close();
        return t;
      });
      const black = gl.createTexture();
      gl.bindTexture(gl.TEXTURE_2D, black);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array([0, 0, 0, 255]));
      return { M, p, U, vao, tex, black };
    }
    appleGL(M).then((a) => { if (alive) { apple = a; dirty = true; } }).catch((e) => console.warn("duo3d:", e));
    // the model drawn: the opaque groups, the screens a little nearer, then the see-through ones blended
    function drawApple(a) {
      const { M, U } = a;
      gl.useProgram(a.p);
      gl.uniformMatrix4fv(U.u_bones, false, bones.subarray(0, 32 * 16));
      for (let k = 0; k < 6; k++) gl.uniform1i(U["u_t" + k], k);
      gl.uniform1i(U.u_pic, 6);
      gl.bindVertexArray(a.vao);
      M.head.groups.forEach(([mi, start, count], gi) => {
        const mt = M.head.mats[mi], ts = new Float32Array(18);
        [mt.baseTex, mt.metallicTex, mt.roughnessTex, mt.occlusionTex, mt.normalTex, mt.opacityTex].forEach((t, k) => {
          gl.activeTexture(gl.TEXTURE0 + k);
          gl.bindTexture(gl.TEXTURE_2D, t ? a.tex[t.image] || a.black : a.black);
          if (t) { ts[k * 3] = 1; ts[k * 3 + 1] = t.uv; ts[k * 3 + 2] = t.channel; }
        });
        gl.activeTexture(gl.TEXTURE6);
        gl.bindTexture(gl.TEXTURE_2D, mt.screen === 1 ? scr.inner.tex : scr.outer.tex);
        gl.uniform3fv(U.u_ts, ts);
        const nt = mt.normalTex || { scale: [1, 1, 1, 1], bias: [0, 0, 0, 0] };
        gl.uniform4fv(U.u_nscale, nt.scale);
        gl.uniform4fv(U.u_nbias, nt.bias);
        gl.uniform3fv(U.u_base, mt.base);
        gl.uniform4f(U.u_mat, mt.metallic, mt.roughness, mt.opacity, mt.clearcoat);
        gl.uniform2f(U.u_coat, mt.clearcoatRoughness, mt.screen ? 1 : 0);
        // the screens a half pixel in front of the black panel they lie on (gpu.rs SCREEN_LIFT)
        gl.uniform1f(U.u_lift, mt.screen ? 0.5 : 0);
        const blended = gi >= M.head.opaque;
        if (blended) { gl.enable(gl.BLEND); gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA); gl.depthMask(false); }
        if (mt.screen) { gl.enable(gl.POLYGON_OFFSET_FILL); gl.polygonOffset(-1, -4); }
        gl.drawElements(gl.TRIANGLES, count, gl.UNSIGNED_INT, start * 4);
        gl.disable(gl.POLYGON_OFFSET_FILL);
        if (blended) { gl.disable(gl.BLEND); gl.depthMask(true); }
      });
      gl.bindVertexArray(null);
      gl.activeTexture(gl.TEXTURE0);
    }

    // a screen's picture: its texture, its decoder, whether it shows anything (an unused screen is black)
    function newScreen(name) {
      const tex = gl.createTexture();
      gl.bindTexture(gl.TEXTURE_2D, tex);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array([0, 0, 0, 255]));
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
      if (aniso) gl.texParameterf(gl.TEXTURE_2D, aniso.TEXTURE_MAX_ANISOTROPY_EXT, Math.min(8, gl.getParameter(aniso.MAX_TEXTURE_MAX_ANISOTROPY_EXT)));
      gl.generateMipmap(gl.TEXTURE_2D);
      return { name, tex, dec: null, decCodec: "", needKey: true, jpegBusy: false, pendingJpeg: null, w: 0, h: 0 };
    }
    const scr = { inner: newScreen("inner"), outer: newScreen("outer") };
    let staging = null;

    function upload(s, src, w, h) {
      gl.bindTexture(gl.TEXTURE_2D, s.tex);
      try {
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, src);
      } catch {
        // a browser that takes no VideoFrame here: through a 2D canvas
        staging = staging || document.createElement("canvas");
        if (staging.width !== w || staging.height !== h) { staging.width = w; staging.height = h; }
        staging.getContext("2d").drawImage(src, 0, 0, w, h);
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, staging);
      }
      gl.generateMipmap(gl.TEXTURE_2D);
      s.w = w; s.h = h;
      dirty = true;
      opts.onFrame && opts.onFrame(w, h, s.name);
    }

    function codecOf(b) {
      for (let i = 0; i + 7 < b.length; i++) {
        if (b[i] === 0 && b[i + 1] === 0 && b[i + 2] === 1 && (b[i + 3] & 0x1f) === 7) {
          const x = (v) => v.toString(16).padStart(2, "0");
          return "avc1." + x(b[i + 4]) + x(b[i + 5]) + x(b[i + 6]);
        }
      }
      return null;
    }
    const keyFrame = (s) => opts.send({ t: "key-frame", s: s.name });
    async function onH264(s, key, w, h, t, data) {
      if (s.needKey && !key) return;
      if (key) {
        const c = codecOf(data);
        if (c && (c !== s.decCodec || !s.dec || s.dec.state === "closed")) {
          if (!s.dec || s.dec.state === "closed") {
            s.dec = new VideoDecoder({
              output: (f) => { if (alive) upload(s, f, f.displayWidth, f.displayHeight); f.close(); },
              error: () => { s.needKey = true; s.decCodec = ""; s.dec = null; keyFrame(s); },
            });
          }
          const cfg = { codec: c, optimizeForLatency: true, codedWidth: w, codedHeight: h };
          const sup = await VideoDecoder.isConfigSupported(cfg).catch(() => ({ supported: false }));
          if (!sup.supported) { opts.onNoH264 && opts.onNoH264(); return; }
          s.dec.configure(cfg);
          s.decCodec = c;
        }
        s.needKey = false;
      }
      if (!s.dec || s.dec.state !== "configured") { s.needKey = true; return; }
      if (s.dec.decodeQueueSize > 4 && !key) { s.needKey = true; keyFrame(s); return; }
      s.dec.decode(new EncodedVideoChunk({ type: key ? "key" : "delta", timestamp: t, data }));
    }
    function onJpeg(s, data) {
      if (s.jpegBusy) { s.pendingJpeg = data; return; }
      s.jpegBusy = true;
      createImageBitmap(new Blob([data], { type: "image/jpeg" })).then((bm) => { if (alive) upload(s, bm, bm.width, bm.height); bm.close(); })
        .catch(() => {}).finally(() => { s.jpegBusy = false; if (s.pendingJpeg) { const d = s.pendingJpeg; s.pendingJpeg = null; onJpeg(s, d); } });
    }
    // a video packet of the socket: kind 1 / 2 the inner screen, 17 / 18 the outer one (H.264 / JPEG)
    function packet(kind, key, w, h, t, data) {
      const s = kind & 16 ? scr.outer : scr.inner;
      if ((kind & 15) === 1) onH264(s, key, w, h, t, data); else onJpeg(s, data);
    }
    function reset() {
      for (const s of Object.values(scr)) { s.needKey = true; s.decCodec = ""; if (s.dec && s.dec.state !== "closed") try { s.dec.close(); } catch {} s.dec = null; }
    }

    // ---- state
    let alive = true, dirty = true, raf = 0;
    // reported: the device's orientation (simhid's); orient: the one the phone is placed in (a pose's from here at
    // once; face up / down keep the last); placeOff: how far the drawn placement still is from it (eases to nothing)
    let hinge = 180, reported = "", orient = "", commanded = null, commandedOrient = null, placeOff = [0, 0];
    let shown = NaN, lastT = NaN, cam = null, fit = null, fitT = NaN;
    // the hinge angle the camera's default view is aimed for: set by a pose, a reset, or a move from elsewhere (the
    // MCP, the CLI) once done, never while the slider is dragged, so the view holds still under a sliding hinge
    let viewDeg = NaN;
    // zoom: the wheel's (1: the phone fits); zoomShown: the one drawn (the wheel moves both, a reset only the first)
    let orbit = [0, 0], zoom = 1, zoomShown = 1, proj = null;
    let cssW = 300, cssH = 300, bones = null, bonesDeg = NaN;

    function state(m) {
      if (m.hinge != null) hinge = Number(m.hinge);
      if (m.orientation) reported = m.orientation;
      dirty = true;
    }
    // the angle the page's hinge panel sent (the hinge file only changes at a move's start and end)
    function command(deg) { commanded = [Number(deg), performance.now() / 1000]; dirty = true; }
    // a pose chosen on the page: drawn moving there at once, its orientation too, and the view settles on the
    // pose's default (a turn or zoom by hand is dropped)
    function pose(deg, o) {
      command(deg);
      viewDeg = Number(deg);
      if (o) commandedOrient = [o, performance.now() / 1000];
      resetView();
    }

    function resize(w, h) {
      w = Math.max(50, Math.floor(w)); h = Math.max(50, Math.floor(h));
      if (w === cssW && h === cssH && canvas.width) return;
      cssW = w; cssH = h;
      canvas.style.width = w + "px"; canvas.style.height = h + "px";
      el.style.width = w + "px"; el.style.height = h + "px";
      // device pixels, at most ~4.5 million (60 fps on a laptop's GPU with 4x MSAA)
      let dpr = window.devicePixelRatio || 1;
      dpr = Math.min(dpr, Math.sqrt(4.5e6 / (w * h)));
      canvas.width = Math.round(w * dpr); canvas.height = Math.round(h * dpr);
      dirty = true;
    }

    // moves the drawn hinge and the camera on; true while either still moves
    function step(now) {
      // the page's angle while it moves the hinge and until simhid's has caught up with it (whole degrees, written as
      // a move ends: switching to it early drew the hinge back, then on again)
      const target = commanded && (now - commanded[1] < 1 || (Math.abs(hinge - commanded[0]) > 1.5 && now - commanded[1] < 3)) ? commanded[0] : hinge;
      const dt = isNaN(lastT) ? 0 : Math.min(0.1, Math.max(0, now - lastT));
      if (isNaN(lastT)) shown = target;
      lastT = now;
      const d = target - shown, cap = SPEED * dt;
      const st = Math.max(-cap, Math.min(cap, d * (1 - Math.exp(-dt * HINGE_RATE))));
      shown = Math.abs(d) < 0.05 ? target : shown + st;
      // the panel's angle gives way to simhid's a second after it was sent: drawn on until then
      let moving = shown !== target || (commanded && now - commanded[1] < 3);
      const phi = rad(180 - shown);
      // the orientation: a pose's from here at once, else simhid's. A new one turns the phone over from where it is
      // drawn and drops a view turned or zoomed by hand (it was relative to how the phone was held).
      const o = commandedOrient && now - commandedOrient[1] < 1.5 ? commandedOrient[0] : reported;
      if (rollKnown(o) && o !== orient) {
        if (orient) {
          const a = placement(orient, phi), b = placement(o, phi);
          placeOff = [wrap(placeOff[0] + a[0] - b[0]), placeOff[1] + a[1] - b[1]];
          resetView();
        }
        orient = o;
      }
      if (placeOff[0] || placeOff[1]) {
        const k = Math.exp(-dt * SETTLE);
        placeOff = [placeOff[0] * k, placeOff[1] * k];
        if (Math.abs(placeOff[0]) + Math.abs(placeOff[1]) < 0.001) placeOff = [0, 0];
        moving = true;
      }
      // quiet: nothing sent from here for 3 s, and the hinge is not where this page last sent it (moved elsewhere)
      const quiet = !commanded || (now - commanded[1] > 3 && Math.abs(hinge - commanded[0]) > 1.5);
      if (isNaN(viewDeg) || (quiet && Math.abs(hinge - viewDeg) > 1 && Math.abs(shown - hinge) < 0.5)) viewDeg = shown;
      const want = defaultView(orient, viewDeg, rad(180 - viewDeg));
      if (cam && dt > 0) {
        const k = 1 - Math.exp(-dt * SETTLE);
        const dy = wrap(want[0] - cam[0]), dp = want[1] - cam[1];
        if (Math.abs(dy) + Math.abs(dp) > 0.002) moving = true;
        cam = [cam[0] + dy * k, cam[1] + dp * k];
      } else if (!cam) cam = want;
      if (zoomShown !== zoom) {
        zoomShown += (zoom - zoomShown) * (1 - Math.exp(-dt * SETTLE));
        if (Math.abs(zoomShown - zoom) < zoom * 0.001) zoomShown = zoom;
        moving = true;
      }
      return moving;
    }

    function render(now) {
      let moving = step(now);
      const phi = rad(180 - shown);
      const yaw = cam[0] + orbit[0], pitch = Math.max(-1.5, Math.min(1.5, cam[1] + orbit[1]));
      const [r0, t0] = placement(orient || "portrait", phi);
      const roll = r0 + placeOff[0], tilt = t0 + placeOff[1];
      const view = (p) => rotX(rotY(rotX(rotZ(p, roll), tilt), yaw), pitch);
      if (bonesDeg !== shown) { bones = poseOf(M, shown); bonesDeg = shown; }
      const size = 2 * HALF_W + HALF_H, dist = 2.4 * size;
      // the view-space box's centre is the picture's middle; the projected box fits the area
      const lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
      const pts = [];
      // the points the framing fits: every 8th vertex of the model, posed
      const q = new Float32Array(3);
      for (let k = 0; k < M.nv; k += 8) {
        skin(M, bones, k, q, 0);
        const p = view([q[0], q[1], q[2]]);
        pts.push(p);
        for (let k = 0; k < 3; k++) { lo[k] = Math.min(lo[k], p[k]); hi[k] = Math.max(hi[k], p[k]); }
      }
      const c = [(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2];
      let bx0 = Infinity, bx1 = -Infinity, by0 = Infinity, by1 = -Infinity;
      for (const p of pts) {
        const qz = p[2] - c[2], k = dist / Math.max(dist - qz, 1);
        const x = (p[0] - c[0]) * k, y = -(p[1] - c[1]) * k;
        bx0 = Math.min(bx0, x); bx1 = Math.max(bx1, x); by0 = Math.min(by0, y); by1 = Math.max(by1, y);
      }
      const bw = bx1 - bx0, bh = by1 - by0;
      const s0w = Math.min(cssW / Math.max(bw, 1), cssH / Math.max(bh, 1)) * 0.9;
      const want = [s0w, (bx0 + bx1) / 2, (by0 + by1) / 2, c];
      if (fit && now > fitT) {
        const k = 1 - Math.exp(-Math.min(0.1, now - fitT) * SETTLE), l = (a, b) => a + (b - a) * k;
        const next = [l(fit[0], want[0]), l(fit[1], want[1]), l(fit[2], want[2]), [0, 1, 2].map((i) => l(fit[3][i], want[3][i]))];
        if (Math.abs(next[0] - want[0]) > want[0] * 0.001 || Math.hypot(next[1] - want[1], next[2] - want[2]) * next[0] > 0.5) moving = true;
        fit = next;
      } else if (!fit) fit = want;
      fitT = now;
      const [fs0, bcx, bcy, fc] = fit;
      const s = fs0 * zoomShown;
      const hw = cssW / 2, hh = cssH / 2;
      const off = [hw - bcx * s, hh - bcy * s];
      const ex = view([1, 0, 0]), ey = view([0, 1, 0]), ez = view([0, 0, 1]);

      gl.viewport(0, 0, canvas.width, canvas.height);
      gl.clearColor(0, 0, 0, 0);
      gl.clearDepth(1);
      gl.enable(gl.DEPTH_TEST);
      gl.depthFunc(gl.LEQUAL);
      gl.disable(gl.CULL_FACE);
      gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
      if (apple) {
        const UU = apple.U;
        gl.useProgram(apple.p);
        gl.uniformMatrix3fv(UU.u_rot, false, [ex[0], ex[1], ex[2], ey[0], ey[1], ey[2], ez[0], ez[1], ez[2]]);
        gl.uniform3f(UU.u_c, fc[0], fc[1], fc[2]);
        gl.uniform4f(UU.u_fit, s / hw, s / hh, (off[0] - hw) / hw, -(off[1] - hh) / hh);
        gl.uniform3f(UU.u_dnf, dist, Math.max(dist - size, 1), dist + size);
        drawApple(apple);
      }

      // a soft shadow on the floor under the phone
      const sw = bw * s * 0.46;
      shadow.style.left = (off[0] + bcx * s - sw) + "px";
      shadow.style.top = (off[1] + by1 * s + 6 - sw * 0.07) + "px";
      shadow.style.width = 2 * sw + "px";
      shadow.style.height = sw * 0.14 * 1.2 + "px";

      proj = { yaw, pitch, roll, tilt, deg: shown, c: fc, dist, s, off };
      return moving;
    }

    function frame() {
      raf = 0;
      if (!alive) return;
      const now = performance.now() / 1000;
      if (dirty || anim) {
        dirty = false;
        anim = render(now);
      } else { lastT = now; fitT = now; }
      raf = requestAnimationFrame(frame);
    }
    let anim = true;
    raf = requestAnimationFrame(frame);

    // ---- pointer to screen (DuoMap)
    function ray(px, py) {
      const p = proj, q = [(px - p.off[0]) / p.s, -(py - p.off[1]) / p.s];
      const unview = (v) => rotZ(rotX(rotY(rotX(v, -p.pitch), -p.yaw), -p.tilt), -p.roll);
      return [unview(add([0, 0, p.dist], p.c)), unview([q[0], q[1], -p.dist])];
    }
    // the posed surfaces at the drawn angle (made once per angle)
    let hits = null;
    function surfaces() {
      if (!hits || hits.deg !== proj.deg) hits = { deg: proj.deg, H: appleHitMesh(M, poseOf(M, proj.deg)) };
      return hits.H;
    }
    // the nearest surface under the pointer; a screen there is touched: surface 1 the inner screen's left half, 2 its
    // right half, 3 the outer screen
    function hit(px, py) {
      if (!proj) return null;
      const [o, d] = ray(px, py), h = trace(surfaces(), o, d, 0);
      if (!h) return null;
      const surface = h.screen === 2 ? 3 : h.x < 0.5 ? 1 : 2;
      return { t: h.t, x: clamp01(h.x), y: clamp01(h.y), surface, s: surface === 3 ? "outer" : "inner" };
    }
    // where (px, py) is on the screen `of` began on, whatever is in front (across the crease a drag carries on)
    function follow(px, py, of) {
      if (!proj) return [of.x, of.y];
      const [o, d] = ray(px, py), h = trace(surfaces(), o, d, of.surface === 3 ? 2 : 1);
      return h ? [h.x, h.y] : [of.x, of.y];
    }
    const clamp01 = (v) => Math.min(1, Math.max(0, v));

    // ---- input
    const local = (e) => { const r = canvas.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
    const pts = new Map(); // pointerId -> [px, py]
    let g = null; // the gesture: {kind: "view" | "touch" | "touch2" | "wait", ...}
    let lastRight = 0, twoTaps = [];
    function turn(dx, dy) { orbit = [orbit[0] - dx * 0.008, orbit[1] + dy * 0.008]; dirty = true; }
    function zoomBy(k) { zoom = zoomShown = Math.max(0.4, Math.min(5, zoom * k)); dirty = true; }
    // back to the pose's default view: the turn is handed to the camera, which eases from where it is drawn to the
    // default view, and the zoom eases back (no jump)
    function resetView() {
      if (cam) cam = [wrap(cam[0] + orbit[0]), Math.max(-1.5, Math.min(1.5, cam[1] + orbit[1]))];
      orbit = [0, 0]; zoom = 1; dirty = true;
      // aimed for the angle just sent from here (a pose moving there), else where the hinge is drawn
      const recent = commanded && performance.now() / 1000 - commanded[1] < 3;
      if (recent) viewDeg = commanded[0]; else if (!isNaN(shown)) viewDeg = shown;
    }
    function touchAt(h, p, px, py) {
      const [x, y] = follow(px, py, h);
      opts.send({ t: "touch", p, x: clamp01(x), y: clamp01(y), s: h.s });
    }
    function two(p) {
      const [a, b] = [...pts.values()], h = g.hit;
      const [x1, y1] = follow(a[0], a[1], h), [x2, y2] = follow(b[0], b[1], h);
      opts.send({ t: "touch2", p, x1: clamp01(x1), y1: clamp01(y1), x2: clamp01(x2), y2: clamp01(y2), s: h.s });
    }
    // mouse Ctrl / Shift drags: two fingers around where it began (pinch and rotate) or side by side (pan)
    function synth(p) {
      const h = g.hit, a = g.anchor, c = g.cur;
      let q;
      if (g.pinch) { const dx = c[0] - a[0] + 0.06, dy = c[1] - a[1]; q = [a[0] + dx, a[1] + dy, a[0] - dx, a[1] - dy]; }
      else q = [c[0] - 0.05, c[1], c[0] + 0.05, c[1]];
      opts.send({ t: "touch2", p, x1: clamp01(q[0]), y1: clamp01(q[1]), x2: clamp01(q[2]), y2: clamp01(q[3]), s: h.s });
    }

    canvas.addEventListener("contextmenu", (e) => e.preventDefault());
    canvas.addEventListener("pointerdown", (e) => {
      e.preventDefault();
      canvas.focus({ preventScroll: true });
      try { canvas.setPointerCapture(e.pointerId); } catch {}
      const [px, py] = local(e);
      if (e.pointerType === "touch" || e.pointerType === "pen") {
        pts.set(e.pointerId, [px, py]);
        if (pts.size === 1) {
          const h = opts.control ? hit(px, py) : null;
          if (h) {
            // the first finger waits a moment for a second one (both fingers of a pinch land within a few frames)
            g = { kind: "wait", hit: h, start: [px, py], timer: setTimeout(() => { if (g && g.kind === "wait" && pts.size === 1) { g.kind = "touch"; touchAt(h, "down", ...g.start); const [p] = pts.values(); if (p[0] !== g.start[0] || p[1] !== g.start[1]) touchAt(h, "move", p[0], p[1]); } }, 60) };
          } else g = { kind: "view", last: [px, py], t0: performance.now(), moved: 0 };
        } else if (pts.size === 2 && g) {
          if (g.kind === "wait") { clearTimeout(g.timer); g.kind = "touch2"; two("down"); }
          else if (g.kind === "touch") { const [a] = pts.values(); touchAt(g.hit, "up", a[0], a[1]); g.kind = "touch2"; two("down"); }
          else if (g.kind === "view") { const [a, b] = [...pts.values()]; g.dist = Math.hypot(a[0] - b[0], a[1] - b[1]); g.mid = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2]; g.two = true; }
        }
        return;
      }
      // mouse
      const viewBtn = e.button === 2 || e.button === 1 || (e.button === 0 && e.altKey);
      if (viewBtn) {
        const now = performance.now();
        if ((e.button === 2 || e.altKey) && now - lastRight < 350) { resetView(); lastRight = 0; g = null; return; }
        lastRight = now;
        g = { kind: "view", last: [px, py], mouse: true };
        return;
      }
      if (e.button !== 0) return;
      const h = opts.control ? hit(px, py) : null;
      if (!h) { g = { kind: "view", last: [px, py], mouse: true }; return; }
      const at = follow(px, py, h);
      if (e.ctrlKey || e.metaKey || e.shiftKey) { g = { kind: "synth", hit: h, anchor: at, cur: at, pinch: e.ctrlKey || e.metaKey }; synth("down"); }
      else { g = { kind: "touch", hit: h }; touchAt(h, "down", px, py); }
    });
    canvas.addEventListener("pointermove", (e) => {
      if (!g) return;
      const [px, py] = local(e);
      if (e.pointerType === "touch" || e.pointerType === "pen") {
        if (!pts.has(e.pointerId)) return;
        const prev = pts.get(e.pointerId);
        pts.set(e.pointerId, [px, py]);
        if (g.kind === "touch") touchAt(g.hit, "move", px, py);
        else if (g.kind === "touch2" && pts.size === 2) two("move");
        else if (g.kind === "view") {
          if (g.two && pts.size === 2) {
            const [a, b] = [...pts.values()], d = Math.hypot(a[0] - b[0], a[1] - b[1]), mid = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];
            if (g.dist > 10) zoomBy(d / g.dist);
            turn(mid[0] - g.mid[0], mid[1] - g.mid[1]);
            g.moved += Math.abs(d - g.dist) + Math.hypot(mid[0] - g.mid[0], mid[1] - g.mid[1]);
            g.dist = d; g.mid = mid;
          } else if (!g.two) { turn(px - prev[0], py - prev[1]); g.moved += Math.hypot(px - prev[0], py - prev[1]); }
        }
        return;
      }
      if (g.kind === "view") { turn(px - g.last[0], py - g.last[1]); g.last = [px, py]; }
      else if (g.kind === "touch" && e.buttons & 1) touchAt(g.hit, "move", px, py);
      else if (g.kind === "synth" && e.buttons & 1) { g.cur = follow(px, py, g.hit); synth("move"); }
    });
    function up(e) {
      if (!g) return;
      const [px, py] = local(e);
      if (e.pointerType === "touch" || e.pointerType === "pen") {
        if (!pts.has(e.pointerId)) return;
        pts.set(e.pointerId, [px, py]);
        if (g.kind === "wait") { clearTimeout(g.timer); g.kind = "touch"; touchAt(g.hit, "down", ...g.start); }
        if (g.kind === "touch") touchAt(g.hit, "up", px, py);
        else if (g.kind === "touch2" && pts.size === 2) two("up");
        else if (g.kind === "view" && g.two && pts.size === 2) {
          // a quick two-finger tap; two of them in a row reset the view
          const now = performance.now();
          if (now - g.t0 < 300 && g.moved < 20) {
            twoTaps = twoTaps.filter((t) => now - t < 450);
            twoTaps.push(now);
            if (twoTaps.length >= 2) { resetView(); twoTaps = []; }
          }
        }
        pts.delete(e.pointerId);
        if (pts.size === 0) g = null;
        else if (g.kind === "touch" || g.kind === "touch2") g = { kind: "lifted" }; // the other finger is ignored until it lifts
        return;
      }
      if (g.kind === "touch") touchAt(g.hit, "up", px, py);
      else if (g.kind === "synth") { g.cur = follow(px, py, g.hit); synth("up"); }
      g = null;
    }
    canvas.addEventListener("pointerup", up);
    canvas.addEventListener("pointercancel", up);

    // the wheel: zoom with the right button / Alt, a touchpad pinch (ctrl + wheel) or off the screens; else a finger
    // dragging the content of the screen under the pointer (lifted after a pause)
    let wheel = null;
    canvas.addEventListener("wheel", (e) => {
      e.preventDefault();
      const scale = e.deltaMode === 1 ? 40 : e.deltaMode === 2 ? 400 : 1;
      const dx = e.deltaX * scale, dy = e.deltaY * scale;
      const [px, py] = local(e);
      const h = !wheel && opts.control && !(e.altKey || e.ctrlKey || e.buttons & 6) ? hit(px, py) : null;
      if (!wheel && !h) { zoomBy(Math.exp(-dy * (e.ctrlKey ? 0.01 : 0.002))); return; }
      if (g) return;
      if (!wheel) {
        const start = [Math.min(0.9, Math.max(0.1, h.x)), Math.min(0.85, Math.max(0.15, h.y))];
        wheel = { start, at: [...start], s: h.s, timer: 0 };
        opts.send({ t: "touch", p: "down", x: start[0], y: start[1], edge: false, s: h.s });
      }
      // a screen's size on the page now, for moving the finger by the wheel's pixels
      const [w, hh] = wheel.s === "outer" ? OUTER : INNER;
      wheel.at[0] -= dx / (w * proj.s); wheel.at[1] -= dy / (hh * proj.s);
      if (wheel.at[0] < 0.05 || wheel.at[0] > 0.95 || wheel.at[1] < 0.08 || wheel.at[1] > 0.92) {
        opts.send({ t: "touch", p: "up", x: clamp01(wheel.at[0]), y: clamp01(wheel.at[1]), s: wheel.s });
        wheel.at = [...wheel.start];
        opts.send({ t: "touch", p: "down", x: wheel.at[0], y: wheel.at[1], edge: false, s: wheel.s });
      } else opts.send({ t: "touch", p: "move", x: wheel.at[0], y: wheel.at[1], s: wheel.s });
      clearTimeout(wheel.timer);
      wheel.timer = setTimeout(() => { opts.send({ t: "touch", p: "up", x: wheel.at[0], y: wheel.at[1], s: wheel.s }); wheel = null; }, 140);
    }, { passive: false });

    canvas.addEventListener("webglcontextlost", (e) => { e.preventDefault(); opts.onLost && opts.onLost(); });

    function close() {
      alive = false;
      if (raf) cancelAnimationFrame(raf);
      reset();
      el.remove();
    }
    // for scripted checks: the drawn hinge and where a screen point is on the page
    const debug = { get shown() { return shown; }, get proj() { return proj; }, get orbit() { return orbit; }, get zoom() { return zoom; }, get orient() { return orient; }, hit,
      // n frames drawn back to back, GPU included: ms per frame (the hinge swept so the model is posed each time)
      bench(n = 60, sweep = true) {
        const t0 = performance.now(), keep = hinge;
        for (let i = 0; i < n; i++) { if (sweep) { shown = 30 + (i * 2.5) % 140; } render(performance.now() / 1000); }
        gl.finish();
        hinge = keep; dirty = true;
        return (performance.now() - t0) / n;
      }, project(s, x, y) {
      // the page point of picture point (x, y) on screen s ("inner" | "outer"), by search along the ray map
      let best = null;
      for (let py = 0; py < cssH; py += 3) for (let px = 0; px < cssW; px += 3) {
        const h = hit(px, py);
        if (h && h.s === s) { const d = Math.hypot(h.x - x, h.y - y); if (!best || d < best[2]) best = [px, py, d]; }
      }
      return best;
    } };
    return { el, canvas, packet, state, command, pose, resize, reset, resetView, close, debug };
  }

  window.Duo3D = { supported, load, create };
})();
