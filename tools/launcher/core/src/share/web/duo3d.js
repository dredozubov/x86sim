"use strict";
// The iPhone Duo in 3D on the web page, as the launcher draws it (gui/src/duo3d.rs, duo3d/mesh.rs, duo3d/gpu.rs, ported
// here): two rounded halves on a hinge spine, the inner screen one panel across both fronts, the outer screen on the
// back of the right half, each the phone's live picture (the socket's two streams: kind 1 / 2 the inner screen,
// 17 / 18 the outer one). The right half turns about the hinge by 180 - angle; the device orientation turns the whole
// phone. Touches on the drawn screens are traced back through the camera onto the screen under them (DuoMap) and go
// to the phone as {s: "inner" | "outer", x, y} on that screen's picture. WebGL2, no library.
//
// The view: a drag with the right or middle button (or Alt, or anywhere off the screens) turns it, the wheel with the
// right button / Alt (or off the screens, or a touchpad pinch) zooms, a double right click resets. Fingers: a gesture
// that starts off the screens turns (one finger) or zooms (two); a double tap with two fingers there resets.
(function () {
  // ---- geometry (mesh.rs): sizes in inner-screen pixels
  const INNER = [2853, 2007], OUTER = [1398, 2034];
  const BEZEL = 46, THICK = 105, CORNER = 200, FILLET = 13, HINGE_CORNER = 0.5;
  const HALF_W = INNER[0] / 2 + BEZEL, HALF_H = OUTER[1] + 2 * BEZEL;
  const ALU = 0, BACK = 1, FRONT = 2, INNER_SCREEN = 3, OUTER_SCREEN = 4, HINGE = 5, DARK = 6;
  const SPEED = 300, SETTLE = 7;
  const rad = (d) => d * Math.PI / 180;
  const v3 = (x, y, z) => [x, y, z];
  const add = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
  const norm = (a) => { const l = Math.max(Math.hypot(a[0], a[1], a[2]), 1e-9); return [a[0] / l, a[1] / l, a[2] / l]; };
  function rotX(p, a) { const s = Math.sin(a), c = Math.cos(a); return [p[0], p[1] * c - p[2] * s, p[1] * s + p[2] * c]; }
  function rotY(p, a) { const s = Math.sin(a), c = Math.cos(a); return [p[0] * c - p[2] * s, p[1], p[0] * s + p[2] * c]; }
  function rotZ(p, a) { const s = Math.sin(a), c = Math.cos(a); return [p[0] * c - p[1] * s, p[0] * s + p[1] * c, p[2]]; }

  // vertices: position, normal, uv, material (9 floats); the screens come after `body` indices
  class Mesh {
    constructor() { this.v = []; this.i = []; this.n = 0; this.body = 0; }
    vert(p, n, uv, m) { this.v.push(p[0], p[1], p[2], n[0], n[1], n[2], uv[0], uv[1], m); return this.n++; }
    quad(a, b, c, d) { this.i.push(a, b, c, a, c, d); }
  }
  const LEFT = (p) => [-p[0], p[1], p[2]];
  const RIGHT = (phi) => (p) => rotY(p, phi);

  // a rounded rectangle's outline with outward normals, counter-clockwise; radii: bottom right, top right, top left, bottom left
  function outline(x0, x1, y0, y1, r, seg) {
    const corners = [[x1 - r[0], y0 + r[0], -90], [x1 - r[1], y1 - r[1], 0], [x0 + r[2], y1 - r[2], 90], [x0 + r[3], y0 + r[3], 180]];
    const pts = [];
    corners.forEach(([cx, cy, a0], i) => {
      for (let k = 0; k <= seg; k++) {
        const a = rad(a0 + 90 * k / seg);
        pts.push([cx + r[i] * Math.cos(a), cy + r[i] * Math.sin(a), Math.cos(a), Math.sin(a)]);
      }
    });
    return pts;
  }

  // a slab with filleted edges: side, front cap and back cap materials
  function slab(m, at, [x0, x1, y0, y1], r, [zf, zb], e, mats, seg) {
    const line = outline(x0, x1, y0, y1, r, seg);
    const prof = [];
    const k = 5;
    for (let j = 0; j <= k; j++) prof.push([rad(90 - 90 * j / k), zf - e]);
    for (let j = 0; j <= k; j++) prof.push([rad(-90 * j / k), zb + e]);
    const base = m.n, np = prof.length;
    for (const [px, py, nx, ny] of line) {
      for (const [t, cz] of prof) {
        const ct = Math.cos(t), st = Math.sin(t), d = e * (ct - 1);
        m.vert(at([px + nx * d, py + ny * d, cz + e * st]), at([nx * ct, ny * ct, st]), [0, 0], mats[0]);
      }
    }
    const nl = line.length;
    for (let i = 0; i < nl; i++) {
      const i2 = (i + 1) % nl;
      for (let j = 0; j < np - 1; j++) m.quad(base + i * np + j, base + i2 * np + j, base + i2 * np + j + 1, base + i * np + j + 1);
    }
    for (const [z, nz, mat] of [[zf, 1, mats[1]], [zb, -1, mats[2]]]) {
      const n = at([0, 0, nz]);
      const c = m.vert(at([(x0 + x1) / 2, (y0 + y1) / 2, z]), n, [0, 0], mat);
      const first = m.n;
      for (const [px, py, nx, ny] of line) m.vert(at([px - nx * e, py - ny * e, z]), n, [0, 0], mat);
      for (let i = 0; i < nl; i++) m.i.push(c, first + i, first + (i + 1) % nl);
    }
  }

  function roundIn(x, y, x0, x1, y0, y1, r) {
    let cx, cy;
    if (x < x0 + r) cx = x0 + r; else if (x > x1 - r) cx = x1 - r; else return [x, y];
    if (y < y0 + r) cy = y0 + r; else if (y > y1 - r) cy = y1 - r; else return [x, y];
    const dx = x - cx, dy = y - cy, d = Math.hypot(dx, dy);
    return d > r ? [cx + dx / d * r, cy + dy / d * r] : [x, y];
  }

  function screen(m, [x0, x1, y0, y1], r, [nx, ny], mat, at, uv) {
    const base = m.n;
    for (let j = 0; j <= ny; j++) {
      for (let i = 0; i <= nx; i++) {
        const [x, y] = roundIn(x0 + (x1 - x0) * i / nx, y0 + (y1 - y0) * j / ny, x0, x1, y0, y1, r);
        const [p, n] = at(x, y);
        m.vert(p, n, uv(x, y), mat);
      }
    }
    const a = (i, j) => base + j * (nx + 1) + i;
    for (let j = 0; j < ny; j++) for (let i = 0; i < nx; i++) m.quad(a(i, j), a(i + 1, j), a(i + 1, j + 1), a(i, j + 1));
  }

  function spine(m, phi) {
    if (phi < rad(0.5)) return;
    const r = THICK + 0.8, y1 = HALF_H / 2 - HINGE_CORNER;
    const segs = Math.max(2, Math.ceil(phi * 180 / Math.PI / 6));
    const ring = (r, ya, yb, mat) => {
      const base = m.n;
      for (let s = 0; s <= segs; s++) {
        const t = -Math.PI / 2 + phi * s / segs, n = [Math.cos(t), 0, Math.sin(t)];
        m.vert([r * Math.cos(t), ya, r * Math.sin(t)], n, [0, 0], mat);
        m.vert([r * Math.cos(t), yb, r * Math.sin(t)], n, [0, 0], mat);
      }
      for (let s = 0; s < segs; s++) m.quad(base + 2 * s, base + 2 * s + 2, base + 2 * s + 3, base + 2 * s + 1);
    };
    ring(r, -y1, y1, HINGE);
    for (const [y, ny] of [[-y1, -1], [y1, 1]]) {
      const n = [0, ny, 0], c = m.vert([0, y, 0], n, [0, 0], HINGE), first = m.n;
      for (let s = 0; s <= segs; s++) { const t = -Math.PI / 2 + phi * s / segs; m.vert([r * Math.cos(t), y, r * Math.sin(t)], n, [0, 0], HINGE); }
      for (let s = 0; s < segs; s++) m.i.push(c, first + s, first + s + 1);
    }
    for (const y of [-y1 + 70, y1 - 70]) ring(r + 0.6, y - 2, y + 2, DARK);
  }

  // the phone at hinge angle `deg` (0 closed .. 180 flat)
  function build(deg) {
    const phi = rad(180 - deg), w = HALF_W, hh = HALF_H, m = new Mesh();
    const radii = [CORNER, CORNER, HINGE_CORNER, HINGE_CORNER];
    for (const [at, back] of [[LEFT, BACK], [RIGHT(phi), FRONT]]) slab(m, at, [0, w, -hh / 2, hh / 2], radii, [0, -THICK], FILLET, [ALU, FRONT, back], 10);
    spine(m, phi);
    m.body = m.i.length;
    const [sw, sh] = INNER, r = CORNER - BEZEL, z = [0, 0, 1], zr = rotY(z, phi);
    screen(m, [-sw / 2, sw / 2, -sh / 2, sh / 2], r, [40, 28], INNER_SCREEN, (x, y) =>
      x < -0.01 ? [[x, y, 0], z] : x > 0.01 ? [rotY([x, y, 0], phi), zr] : [[0, y, 0], norm(add(z, zr))],
    (x, y) => [(x + sw / 2) / sw, (sh / 2 - y) / sh]);
    const [ow, oh] = OUTER, cx = w / 2, ox0 = cx - ow / 2, ox1 = cx + ow / 2, back = rotY([0, 0, -1], phi);
    screen(m, [ox0, ox1, -oh / 2, oh / 2], r, [20, 28], OUTER_SCREEN, (x, y) => [rotY([x, y, -THICK], phi), back], (x, y) => [(ox1 - x) / ow, (oh / 2 - y) / oh]);
    return { v: new Float32Array(m.v), i: new Uint32Array(m.i), body: m.body, n: m.n };
  }

  // ---- pose and camera (duo3d.rs)
  function rollOf(o) { return o === "landscapeLeft" ? rad(90) : o === "landscapeRight" ? rad(-90) : o === "portraitUpsideDown" ? Math.PI : 0; }
  function placement(o, phi) {
    return [rollOf(o), o === "landscapeLeft" ? -Math.PI / 2 : o === "landscapeRight" ? phi - Math.PI / 2 : 0];
  }
  function defaultView(o, deg, phi, inner) {
    if (inner == null) inner = deg >= 85;
    const k = Math.max(Math.sin(phi), 0);
    if (o === "landscapeLeft" || o === "landscapeRight") return [rad(-12 * k), rad(inner ? 28 : 70)];
    let n = inner ? [-Math.sin(phi), 0, 1 + Math.cos(phi)] : [Math.sin(phi), 0, -Math.cos(phi)];
    n = rotZ(n, rollOf(o));
    const yaw = Math.atan2(n[0], n[2]), pitch = Math.atan2(n[1], Math.hypot(n[0], n[2]));
    return [yaw + rad(-14 * k), Math.max(-1.5, Math.min(1.5, pitch + rad(10 * k)))];
  }

  // where a ray meets the plane z of a half's own space: [t, x, y]
  function plane(o, d, z) {
    if (Math.abs(d[2]) < 1e-6) return null;
    const t = (z - o[2]) / d[2];
    return [t, o[0] + d[0] * t, o[1] + d[1] * t];
  }
  function entersBox(o, d) {
    let t0 = -Infinity, t1 = Infinity;
    for (const [oo, dd, lo, hi] of [[o[0], d[0], 0, HALF_W], [o[1], d[1], -HALF_H / 2, HALF_H / 2], [o[2], d[2], -THICK, 0]]) {
      if (Math.abs(dd) < 1e-9) { if (oo < lo || oo > hi) return null; continue; }
      const a = (lo - oo) / dd, b = (hi - oo) / dd;
      t0 = Math.max(t0, Math.min(a, b)); t1 = Math.min(t1, Math.max(a, b));
    }
    return t0 <= t1 && t1 > 0 ? t0 : null;
  }

  // ---- drawing (gpu.rs), GLSL ES 3.00
  const VS = `#version 300 es
precision highp float;
uniform mat3 u_rot; uniform vec3 u_c; uniform vec4 u_fit; uniform vec3 u_dnf;
in vec3 a_p; in vec3 a_n; in vec2 a_uv; in float a_m;
out vec3 v_n; out vec3 v_p; out vec2 v_uv; out float v_m;
void main() {
  vec3 p = u_rot * a_p - u_c;
  float w = u_dnf.x - p.z;
  gl_Position = vec4(p.x * u_dnf.x * u_fit.x + u_fit.z * w, p.y * u_dnf.x * u_fit.y + u_fit.w * w,
    ((w - u_dnf.y) / (u_dnf.z - u_dnf.y) * 2.0 - 1.0) * w, w);
  v_n = u_rot * a_n; v_p = p; v_uv = a_uv; v_m = a_m;
}`;
  const FS = `#version 300 es
precision highp float;
uniform sampler2D u_inner; uniform sampler2D u_outer; uniform vec3 u_dnf;
in vec3 v_n; in vec3 v_p; in vec2 v_uv; in float v_m;
out vec4 frag;
float box(float x, float a, float b, float soft) { return smoothstep(a - soft, a + soft, x) * (1.0 - smoothstep(b - soft, b + soft, x)); }
vec3 studio(vec3 d) {
  float up = d.y * 0.5 + 0.5;
  vec3 c = mix(vec3(0.008, 0.008, 0.009), vec3(0.07, 0.071, 0.075), smoothstep(0.2, 0.9, up));
  c += vec3(2.0) * smoothstep(0.6, 0.8, d.y) * box(d.x, -0.55, 0.55, 0.12) * box(d.z, -0.2, 0.9, 0.15);
  c += vec3(1.05, 1.03, 1.0) * smoothstep(0.78, 0.9, -d.x) * box(d.y, -0.3, 0.65, 0.12);
  c += vec3(0.38, 0.40, 0.45) * smoothstep(0.8, 0.92, d.x) * box(d.y, -0.2, 0.6, 0.15);
  c += vec3(0.05) * smoothstep(0.8, 0.97, d.z);
  return c;
}
vec3 lin(vec3 g) { return pow(g, vec3(2.2)); }
vec3 srgb(vec3 l) { return pow(clamp(l, 0.0, 1.0), vec3(1.0 / 2.2)); }
vec3 tone(vec3 c) { return c * (2.51 * c + 0.03) / (c * (2.43 * c + 0.59) + 0.14); }
void main() {
  vec3 n = normalize(v_n);
  vec3 v = normalize(vec3(0.0, 0.0, u_dnf.x) - v_p);
  if (dot(n, v) < 0.0) n = -n;
  vec3 r = reflect(-v, n);
  float cosv = max(dot(n, v), 0.0);
  float fres = pow(1.0 - cosv, 5.0);
  vec3 col;
  if (v_m > 2.5 && v_m < 4.5) {
    vec3 pic = lin(v_m < 3.5 ? texture(u_inner, v_uv).rgb : texture(u_outer, v_uv).rgb);
    vec3 refl = studio(r) * (0.04 + 0.96 * fres);
    frag = vec4(srgb(pic + refl * 0.3), 1.0);
    return;
  }
  if (v_m < 0.5 || (v_m > 4.5 && v_m < 5.5)) {
    vec3 f0 = v_m < 0.5 ? vec3(0.56, 0.54, 0.51) : vec3(0.30, 0.30, 0.29);
    vec3 f = f0 + (vec3(1.0) - f0) * fres;
    col = f * studio(r) + f0 * 0.05;
  } else if (v_m < 1.5) {
    vec3 base = vec3(0.028, 0.029, 0.032);
    vec3 rr = normalize(mix(r, n, 0.35));
    col = base * (0.3 + 0.7 * max(dot(n, normalize(vec3(-0.4, 0.7, 0.6))), 0.0)) + studio(rr) * (0.04 + 0.96 * fres) * 0.45;
  } else if (v_m < 2.5) {
    col = vec3(0.003) + studio(r) * (0.04 + 0.96 * fres) * 0.45;
  } else {
    col = vec3(0.01) + studio(r) * 0.02;
  }
  frag = vec4(srgb(tone(col)), 1.0);
}`;

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

  function program(gl) {
    const p = gl.createProgram();
    for (const [kind, src] of [[gl.VERTEX_SHADER, VS], [gl.FRAGMENT_SHADER, FS]]) {
      const s = gl.createShader(kind);
      gl.shaderSource(s, src);
      gl.compileShader(s);
      if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s));
      gl.attachShader(p, s);
    }
    ["a_p", "a_n", "a_uv", "a_m"].forEach((a, i) => gl.bindAttribLocation(p, i, a));
    gl.linkProgram(p);
    if (!gl.getProgramParameter(p, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(p));
    return p;
  }

  // ---- one phone's view
  // opts: control (touches go to the phone), send(obj), codec ("h264" | "jpeg"), onFrame(w, h) (an inner or outer
  // picture shown), onNoH264() (this browser can't decode the stream)
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
    const prog = program(gl);
    const U = {};
    for (const n of ["u_rot", "u_c", "u_fit", "u_dnf", "u_inner", "u_outer"]) U[n] = gl.getUniformLocation(prog, n);
    const vao = gl.createVertexArray(), vbo = gl.createBuffer(), ibo = gl.createBuffer();
    gl.bindVertexArray(vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    [[3, 0], [3, 12], [2, 24], [1, 32]].forEach(([n, off], i) => { gl.enableVertexAttribArray(i); gl.vertexAttribPointer(i, n, gl.FLOAT, false, 36, off); });
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo);
    gl.bindVertexArray(null);
    const aniso = gl.getExtension("EXT_texture_filter_anisotropic");

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
      return { name, tex, dec: null, decCodec: "", needKey: true, lit: false, litAt: 0, jpegBusy: false, pendingJpeg: null, w: 0, h: 0 };
    }
    const scr = { inner: newScreen("inner"), outer: newScreen("outer") };
    const probe = document.createElement("canvas");
    probe.width = probe.height = 12;
    const pctx = probe.getContext("2d", { willReadFrequently: true });
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
      // lit or black, twice a second
      const now = performance.now();
      if (now - s.litAt > 500) {
        s.litAt = now;
        try {
          pctx.drawImage(src, 0, 0, 12, 12);
          const d = pctx.getImageData(0, 0, 12, 12).data;
          let lit = false;
          for (let i = 0; i < d.length; i += 4) if (d[i] > 12 || d[i + 1] > 12 || d[i + 2] > 12) { lit = true; break; }
          s.lit = lit;
        } catch {}
      }
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
    let hinge = 180, orient = "portrait", commanded = null;
    let shown = NaN, lastT = NaN, cam = null, fit = null, fitT = NaN;
    let orbit = [0, 0], zoom = 1, proj = null;
    let cssW = 300, cssH = 300, mesh = null, meshDeg = NaN;

    function state(m) {
      if (m.hinge != null) hinge = Number(m.hinge);
      if (m.orientation) orient = m.orientation;
      dirty = true;
    }
    // the angle the page's hinge panel sent (the hinge file only changes at a move's start and end)
    function command(deg) { commanded = [Number(deg), performance.now() / 1000]; dirty = true; }
    function facing() { const i = scr.inner.lit, o = scr.outer.lit; return i !== o ? i : null; }

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
      const target = commanded && now - commanded[1] < 1 ? commanded[0] : hinge;
      const dt = isNaN(lastT) ? 0 : Math.min(0.1, Math.max(0, now - lastT));
      if (isNaN(lastT)) shown = target;
      lastT = now;
      const d = target - shown, st = SPEED * dt;
      shown = Math.abs(d) <= st ? target : shown + st * Math.sign(d);
      // the panel's angle gives way to simhid's a second after it was sent: drawn on until then
      let moving = shown !== target || (commanded && now - commanded[1] < 1.2);
      const phi = rad(180 - shown);
      const want = defaultView(orient, shown, phi, facing());
      if (cam && dt > 0) {
        const k = 1 - Math.exp(-dt * SETTLE);
        const wrap = (a) => ((a + Math.PI) % (2 * Math.PI) + 2 * Math.PI) % (2 * Math.PI) - Math.PI;
        const dy = wrap(want[0] - cam[0]), dp = want[1] - cam[1];
        if (Math.abs(dy) + Math.abs(dp) > 0.002) moving = true;
        cam = [cam[0] + dy * k, cam[1] + dp * k];
      } else if (!cam) cam = want;
      return moving;
    }

    function render(now) {
      let moving = step(now);
      const phi = rad(180 - shown);
      const yaw = cam[0] + orbit[0], pitch = Math.max(-1.5, Math.min(1.5, cam[1] + orbit[1]));
      const [roll, tilt] = placement(orient, phi);
      const view = (p) => rotX(rotY(rotX(rotZ(p, roll), tilt), yaw), pitch);
      if (shown !== meshDeg || !mesh) {
        mesh = build(shown);
        meshDeg = shown;
        gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
        gl.bufferData(gl.ARRAY_BUFFER, mesh.v, gl.DYNAMIC_DRAW);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo);
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, mesh.i, gl.DYNAMIC_DRAW);
      }
      const size = 2 * HALF_W + HALF_H, dist = 2.4 * size;
      // the view-space box's centre is the picture's middle; the projected box fits the area
      const lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
      const pts = [];
      const V = mesh.v;
      for (let i = 0; i < V.length; i += 9) {
        const p = view([V[i], V[i + 1], V[i + 2]]);
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
      const s = fs0 * zoom;
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
      gl.useProgram(prog);
      gl.uniformMatrix3fv(U.u_rot, false, [ex[0], ex[1], ex[2], ey[0], ey[1], ey[2], ez[0], ez[1], ez[2]]);
      gl.uniform3f(U.u_c, fc[0], fc[1], fc[2]);
      gl.uniform4f(U.u_fit, s / hw, s / hh, (off[0] - hw) / hw, -(off[1] - hh) / hh);
      gl.uniform3f(U.u_dnf, dist, Math.max(dist - size, 1), dist + size);
      gl.uniform1i(U.u_inner, 0);
      gl.uniform1i(U.u_outer, 1);
      gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, scr.inner.tex);
      gl.activeTexture(gl.TEXTURE1); gl.bindTexture(gl.TEXTURE_2D, scr.outer.tex);
      gl.bindVertexArray(vao);
      gl.drawElements(gl.TRIANGLES, mesh.body, gl.UNSIGNED_INT, 0);
      // the screens lie on the glass: drawn nearer by a depth offset
      gl.enable(gl.POLYGON_OFFSET_FILL);
      gl.polygonOffset(-1, -4);
      gl.drawElements(gl.TRIANGLES, mesh.i.length - mesh.body, gl.UNSIGNED_INT, mesh.body * 4);
      gl.disable(gl.POLYGON_OFFSET_FILL);
      gl.bindVertexArray(null);
      gl.activeTexture(gl.TEXTURE0);

      // a soft shadow on the floor under the phone
      const sw = bw * s * 0.46;
      shadow.style.left = (off[0] + bcx * s - sw) + "px";
      shadow.style.top = (off[1] + by1 * s + 6 - sw * 0.07) + "px";
      shadow.style.width = 2 * sw + "px";
      shadow.style.height = sw * 0.14 * 1.2 + "px";

      proj = { yaw, pitch, roll, tilt, phi, c: fc, dist, s, off };
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
    function rays(px, py) {
      const [o, d] = ray(px, py), m = (v) => [-v[0], v[1], v[2]], b = (v) => rotY(v, -proj.phi);
      return [[m(o), m(d)], [b(o), b(d)]];
    }
    // surface 1 the inner screen's left half, 2 its right half, 3 the outer screen: [t, x, y] on its picture
    function on(px, py, surface) {
      const r = rays(px, py), [sw, sh] = INNER, [ow, oh] = OUTER;
      if (surface === 1) { const h = plane(r[0][0], r[0][1], 0); return h && [h[0], (sw / 2 - h[1]) / sw, (sh / 2 - h[2]) / sh]; }
      if (surface === 2) { const h = plane(r[1][0], r[1][1], 0); return h && [h[0], (h[1] + sw / 2) / sw, (sh / 2 - h[2]) / sh]; }
      const ox1 = HALF_W / 2 + ow / 2, h = plane(r[1][0], r[1][1], -THICK);
      return h && [h[0], (ox1 - h[1]) / ow, (oh / 2 - h[2]) / oh];
    }
    function hit(px, py) {
      if (!proj) return null;
      const r = rays(px, py);
      let best = null;
      for (const surface of [1, 2, 3]) {
        const half = surface === 1 ? 0 : 1, d = r[half][1];
        if (surface === 3 ? !(d[2] > 0) : !(d[2] < 0)) continue;
        const h = on(px, py, surface);
        if (!h) continue;
        const [t, x, y] = h;
        const inside = (surface === 1 ? x >= 0 && x <= 0.5 : surface === 2 ? x >= 0.5 && x <= 1 : x >= 0 && x <= 1) && y >= 0 && y <= 1;
        if (!inside || t <= 0) continue;
        const t2 = entersBox(r[1 - half][0], r[1 - half][1]);
        if (t2 != null && t2 < t - 1) continue;
        if (!best || t < best.t) best = { t, x, y, surface, s: surface === 3 ? "outer" : "inner" };
      }
      return best;
    }
    // where (px, py) is on the surface `of` began on (across the crease a drag on the inner screen carries on)
    function follow(px, py, of) {
      if (of.surface !== 3) {
        for (const s of [of.surface, 3 - of.surface]) {
          const h = on(px, py, s);
          if (h && h[0] > 0 && (s === 1 ? h[1] <= 0.5 : h[1] >= 0.5)) return [h[1], h[2]];
        }
      }
      const h = proj && on(px, py, of.surface);
      return h ? [h[1], h[2]] : [of.x, of.y];
    }
    const clamp01 = (v) => Math.min(1, Math.max(0, v));

    // ---- input
    const local = (e) => { const r = canvas.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
    const pts = new Map(); // pointerId -> [px, py]
    let g = null; // the gesture: {kind: "view" | "touch" | "touch2" | "wait", ...}
    let lastRight = 0, twoTaps = [];
    function turn(dx, dy) { orbit = [orbit[0] - dx * 0.008, orbit[1] + dy * 0.008]; dirty = true; }
    function zoomBy(k) { zoom = Math.max(0.4, Math.min(5, zoom * k)); dirty = true; }
    function resetView() { orbit = [0, 0]; zoom = 1; dirty = true; }
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
    const debug = { get shown() { return shown; }, get proj() { return proj; }, get orbit() { return orbit; }, get zoom() { return zoom; }, hit,
      // n frames drawn back to back, GPU included: ms per frame (the hinge swept so the mesh is rebuilt each time)
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
    return { el, canvas, packet, state, command, resize, reset, resetView, close, debug };
  }

  window.Duo3D = { supported, create };
})();
