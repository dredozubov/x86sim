// x86Sim share page: a dashboard of every phone and a live view of one (x86sim serve; protocol in ../server.rs).
"use strict";

const qs = new URLSearchParams(location.search);
let TOKEN = qs.get("t") || (() => { try { return sessionStorage.getItem("x86sim_t"); } catch { return null; } })() || "";
if (qs.get("t")) {
  try { sessionStorage.setItem("x86sim_t", TOKEN); } catch {}
  // the token out of the address bar and the history (this tab keeps it, and the server set its cookie)
  qs.delete("t");
  history.replaceState(null, "", location.pathname + (qs.toString() ? "?" + qs : "") + location.hash);
}
let ME = null;
const $ = (s, el = document) => el.querySelector(s);
const main = $("#main");

function h(tag, attrs = {}, ...kids) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v === undefined || v === null || v === false) continue;
    if (k.startsWith("on")) e.addEventListener(k.slice(2), v);
    else if (k === "class") e.className = v;
    else if (k === "text") e.textContent = v;
    // the page's CSP refuses style attributes; the CSSOM is allowed
    else if (k === "style") e.style.cssText = v;
    else e.setAttribute(k, v === true ? "" : v);
  }
  for (const c of kids.flat()) if (c !== null && c !== undefined && c !== false) e.append(c.nodeType ? c : String(c));
  return e;
}

function withToken(url) {
  return TOKEN ? url + (url.includes("?") ? "&" : "?") + "t=" + encodeURIComponent(TOKEN) : url;
}

async function api(path, body) {
  const opt = { headers: { "X-X86sim": "1" } };
  if (TOKEN) opt.headers.Authorization = "Bearer " + TOKEN;
  if (body !== undefined) {
    opt.method = "POST";
    opt.headers["Content-Type"] = "application/json";
    opt.body = JSON.stringify(body);
  }
  const r = await fetch(path, opt);
  const j = await r.json().catch(() => ({}));
  if (!r.ok) {
    const e = new Error(j.error || r.statusText);
    e.status = r.status;
    throw e;
  }
  return j;
}

// the launcher's units: 1.2 GB / 640 MB, 35%, 13 min
function fmtMem(mb) { return mb >= 1024 ? (mb / 1024).toFixed(1) + " GB" : Math.round(mb) + " MB"; }
function fmtUp(s) {
  if (s == null) return "–";
  if (s < 60) return Math.round(s) + " s";
  if (s < 3600) return Math.round(s / 60) + " min";
  if (s < 86400) return (s / 3600).toFixed(1).replace(/\.0$/, "") + " h";
  return (s / 86400).toFixed(1).replace(/\.0$/, "") + " d";
}
const stateLabel = (s) => ({ running: "Running", starting: "Starting", stopping: "Stopping", off: "Off" })[s] || s || "";
function badge(state) { return h("span", { class: "badge " + state }, h("span", { class: "dot " + state }), stateLabel(state)); }

function toast(msg, ms = 3500) {
  const t = h("div", { class: "toast", text: msg });
  document.body.append(t);
  setTimeout(() => t.remove(), ms);
}

async function copy(text) {
  try {
    await navigator.clipboard.writeText(text);
    toast("Copied");
    return;
  } catch {}
  // no async clipboard (plain HTTP from another machine): a hidden text area and the copy command
  const ta = h("textarea", { class: "offscreen", readonly: "" });
  ta.value = text;
  document.body.append(ta);
  ta.select();
  let ok = false;
  try { ok = document.execCommand("copy"); } catch {}
  ta.remove();
  if (ok) toast("Copied");
  else prompt("Copy this:", text.length > 2000 ? text.slice(-2000) : text);
}

// ---------- the look: Desktop (this machine's Omarchy theme, live), System, Dark or Light ----------
// The server pushes the theme's generation (a WebSocket: once at once, then at every theme switch, no polling);
// theme.css holds its colours and the page applies them only in the Desktop look.
const LOOKS = [["desktop", "\uE560", "Desktop theme (this machine's Omarchy theme, live)"], ["system", "\uE18C", "System light / dark"],
  ["dark", "\uE330", "Dark"], ["light", "\uE472", "Light"]];
let look = (() => { try { return localStorage.getItem("x86sim.look") || "desktop"; } catch { return "desktop"; } })();
let desktopTheme = false;
function applyLook() {
  const root = document.documentElement;
  const useDesktop = look === "desktop" && desktopTheme;
  if (useDesktop) root.dataset.hostTheme = ""; else delete root.dataset.hostTheme;
  if (look === "dark" || look === "light") root.dataset.theme = look; else delete root.dataset.theme;
  const shown = look === "desktop" && !desktopTheme ? LOOKS[1] : LOOKS.find((l) => l[0] === look) || LOOKS[1];
  const b = document.getElementById("lookBtn");
  if (b) {
    b.firstChild.textContent = shown[1];
    b.title = (look === "desktop" && !desktopTheme ? "System light / dark (no Omarchy theme on this machine)" : shown[2]) + " · click for the next look";
    b.setAttribute("aria-label", b.title);
  }
}
document.getElementById("lookBtn").addEventListener("click", () => {
  const order = LOOKS.map((l) => l[0]).filter((l) => l !== "desktop" || desktopTheme);
  const cur = look === "desktop" && !desktopTheme ? "system" : look;
  look = order[(order.indexOf(cur) + 1) % order.length];
  try { localStorage.setItem("x86sim.look", look); } catch {}
  applyLook();
});
applyLook();
// the theme's generation, pushed over a WebSocket (it passes Tailscale and Cloudflare's quick tunnels alike); the
// socket comes back after a drop (a server restart), a second later and then less often
let themeGen = null, themeRetry = 0;
function themeSocket() {
  let ws;
  try { ws = new WebSocket((location.protocol === "https:" ? "wss://" : "ws://") + location.host + "/ws-theme"); } catch { return; }
  ws.onmessage = (m) => {
    themeRetry = 0;
    const t = JSON.parse(m.data);
    desktopTheme = !!t.available;
    if (t.generation !== themeGen) {
      if (themeGen !== null) document.getElementById("themecss").href = "theme.css?g=" + encodeURIComponent(t.generation);
      themeGen = t.generation;
    }
    applyLook();
  };
  ws.onclose = () => setTimeout(themeSocket, Math.min(30000, 1000 * 2 ** themeRetry++));
}
themeSocket();

// ---------- routing ----------
let cleanup = null;
function route() {
  if (cleanup) { cleanup(); cleanup = null; }
  main.replaceChildren();
  const m = location.hash.match(/^#\/phone\/(.+)$/);
  if (m) cleanup = phoneView(decodeURIComponent(m[1]));
  else cleanup = dashboard();
}
window.addEventListener("hashchange", route);

async function boot() {
  try {
    ME = await api("/api/me");
  } catch (e) {
    main.replaceChildren(h("div", { class: "msg" },
      h("h2", { text: e.status === 401 ? "This link needs a valid token" : "Can't reach the server" }),
      h("p", { text: e.status === 401 ? "Expired or revoked" : String(e.message) })));
    return;
  }
  const role = $("#role");
  role.textContent = ME.role === "control" ? "Watch and drive" : "Watch only";
  role.classList.toggle("view", ME.role !== "control");
  if (ME.expires) role.title = "Link expires " + new Date(ME.expires * 1000).toLocaleString();
  // tunnels and links are the server owner's (a link can't make more links)
  if (ME.owner) {
    const b = $("#shareBtn");
    b.hidden = false;
    b.onclick = () => openShare(currentPhone);
  }
  const p = qs.get("phone") || ME.phone;
  if (p && !location.hash) location.hash = "#/phone/" + encodeURIComponent(p);
  route();
}

// ---------- dashboard ----------
let currentPhone = null;
// the side a device type's corner radius is a fraction of: the upright width (a TV's and a Vision Pro's is the long side)
const cornerSide = (platform, w, h) => platform === "tvos" || platform === "xros" ? Math.max(w, h) : Math.min(w, h);
function dashboard() {
  currentPhone = null;
  $("#crumb").replaceChildren();
  $("#acts").replaceChildren();
  document.title = "x86Sim Devices";
  const control = ME.role === "control";
  // what the viewer picked, kept in this browser (a remembered convenience only: the page works without it)
  const PREF = "x86sim.dash";
  let pref = { q: "", kind: "all", sort: "name", view: "grid" };
  try { Object.assign(pref, JSON.parse(localStorage.getItem(PREF) || "{}")); } catch (_) {}
  const save = () => { try { localStorage.setItem(PREF, JSON.stringify(pref)); } catch (_) {} };

  const KINDS = [["all", "All"], ["iphone", "iPhone"], ["ipad", "iPad"], ["tv", "TV"], ["watch", "Watch"], ["vision", "Vision"]];
  const kindOf = (p) => p.platform === "tvos" ? "tv" : p.platform === "watchos" ? "watch" : p.platform === "xros" ? "vision" : p.ipad ? "ipad" : "iphone";
  const KIND_ORDER = { iphone: 0, ipad: 1, tv: 2, watch: 3, vision: 4 };
  const SORTS = [["name", "Name"], ["kind", "Device type"], ["memory", "Memory"], ["cpu", "CPU"], ["uptime", "Recently started"]];
  const byName = (a, b) => a.name.localeCompare(b.name, undefined, { numeric: true, sensitivity: "base" });
  const sorters = {
    name: byName,
    kind: (a, b) => KIND_ORDER[kindOf(a)] - KIND_ORDER[kindOf(b)] || byName(a, b),
    memory: (a, b) => (b.memory_mb || 0) - (a.memory_mb || 0) || byName(a, b),
    cpu: (a, b) => (b.cpu_pct || 0) - (a.cpu_pct || 0) || byName(a, b),
    uptime: (a, b) => (a.uptime_s ?? Infinity) - (b.uptime_s ?? Infinity) || byName(a, b),
  };

  // toolbar: search, device types, sort, grid / list
  const search = h("input", { type: "search", class: "dsearch", placeholder: "Search name or model", value: pref.q, "aria-label": "Search devices" });
  const chips = h("div", { class: "chips", role: "group", "aria-label": "Device type" });
  const sortSel = h("select", { "aria-label": "Sort" }, SORTS.map(([v, t]) => h("option", { value: v, text: t, selected: pref.sort === v })));
  const viewGrid = h("button", { class: "btn small", text: "Grid", title: "Cards" });
  const viewList = h("button", { class: "btn small", text: "List", title: "Rows" });
  const bar = h("div", { class: "dashbar" }, search, chips, h("div", { class: "grow" }), h("label", { class: "meta sortlbl" }, "Sort ", sortSel), h("div", { class: "seg" }, viewGrid, viewList));
  const total = h("span", { class: "meta" });
  const secRun = h("section", { class: "dsec" }, h("h2", {}, "running", h("span", { class: "count" })), h("div"));
  const secOff = h("section", { class: "dsec" }, h("h2", {}, "off", h("span", { class: "count" })), h("div"));
  const empty = h("div", { class: "empty" });
  main.append(h("div", { class: "page" }, h("div", { class: "phead" }, h("h1", { text: "Devices" }), total), bar, secRun, secOff, empty));

  const cards = new Map();  // id -> the element of the current view + its parts
  let phones = [], n = 0, alive = true;
  function setView(v) {
    pref.view = v; save();
    viewGrid.classList.toggle("on", v === "grid"); viewList.classList.toggle("on", v === "list");
    for (const s of [secRun, secOff]) s.lastChild.className = v === "list" ? "dlist" : "dgrid";
    for (const c of cards.values()) c.el.remove();
    cards.clear();
    render();
  }
  viewGrid.onclick = () => setView("grid");
  viewList.onclick = () => setView("list");
  search.oninput = () => { pref.q = search.value; save(); render(); };
  sortSel.onchange = () => { pref.sort = sortSel.value; save(); render(); };

  function make(p) {
    const open = () => location.hash = "#/phone/" + encodeURIComponent(p.id);
    const scr = h("div", { class: "scr" });
    const thumb = h("div", { class: "thumb", title: "Open " + p.name, onclick: open }, scr);
    const title = h("a", { class: "dname", href: "#/phone/" + encodeURIComponent(p.id) });
    const meta = h("div", { class: "meta dmodel" });
    const dot = h("span", { class: "dot" });
    const st = h("div", { class: "meta state" });
    const stats = h("div", { class: "meta dstats" });
    const row = h("div", { class: "row" });
    const list = pref.view === "list";
    // the GUI's card: the screen, then a dot, the name and the one action, then model and load
    const el = list
      ? h("div", { class: "drow" }, thumb, h("div", { class: "dinfo" }, h("div", { class: "cname" }, dot, title), meta), st, stats, row)
      : h("div", { class: "card" }, thumb, h("div", { class: "cfoot" }, h("div", { class: "cname" }, dot, title, row), meta, stats));
    return { el, scr, thumb, title, meta, dot, st, stats, row, img: h("img", { alt: "" }), loading: false, open };
  }

  function update(c, p) {
    c.title.textContent = p.name;
    c.title.title = p.name;
    c.meta.textContent = `${p.model} · ${p.os}`;
    c.meta.title = c.meta.textContent;
    if (Array.isArray(p.screen) && p.screen[0] > 0 && p.screen[1] > 0) {
      c.scr.style.setProperty("--arn", String(p.screen[0] / p.screen[1]));
      // the device type's corner radius (a fraction of the upright width) as a fraction of the drawn width
      if (typeof p.corner === "number") c.scr.style.setProperty("--rr", String(p.corner * cornerSide(p.platform, p.screen[0], p.screen[1]) / p.screen[0]));
    }
    c.scr.className = "scr k-" + kindOf(p);
    const running = p.state === "running" || p.state === "starting";
    c.dot.className = "dot " + p.state;
    c.dot.title = stateLabel(p.state);
    c.st.replaceChildren(h("span", { class: "dot " + p.state }), stateLabel(p.state));
    c.stats.textContent = p.state === "running" && p.memory_mb ? `${fmtMem(p.memory_mb)} · ${Math.round(p.cpu_pct || 0)}% CPU` + (p.gpu ? ` · ${p.gpu.short}` : "") : p.state === "off" ? "" : stateLabel(p.state);
    c.stats.title = p.state !== "off" && p.gpu ? p.gpu.name : "";
    c.stats.hidden = !c.stats.textContent && pref.view !== "list";
    if (running && !c.loading) {
      c.loading = true;
      const im = new Image();
      im.onload = () => { c.img.src = im.src; if (!c.img.isConnected) c.scr.replaceChildren(c.img); c.loading = false; };
      im.onerror = () => { c.loading = false; };
      im.src = withToken(`/api/phones/${encodeURIComponent(p.id)}/thumb.jpg?w=${pref.view === "list" ? 120 : 320}&n=${n}`);
    } else if (!running) {
      c.scr.replaceChildren(h("span", { class: "off", text: p.installed ? "Off" : "No runtime" }));
    }
    const key = p.state + control;
    if (c.row.dataset.k !== key) {
      c.row.dataset.k = key;
      c.row.replaceChildren(...[
        control && p.state === "off" && p.installed ? h("button", { class: "btn small good", text: "Start", onclick: (e) => act(e, p.id, "start") }) : null,
        control && running ? h("button", { class: "btn small danger", text: "Stop", onclick: (e) => act(e, p.id, "stop") }) : null,
        !control ? h("button", { class: "btn small", text: "Open", onclick: c.open }) : null].filter(Boolean));
    }
  }

  function render() {
    const q = pref.q.trim().toLowerCase();
    const counts = { all: phones.length };
    for (const p of phones) counts[kindOf(p)] = (counts[kindOf(p)] || 0) + 1;
    if (!KINDS.some(([k]) => k === pref.kind) || (pref.kind !== "all" && !counts[pref.kind])) pref.kind = "all";
    chips.replaceChildren(...KINDS.filter(([k]) => k === "all" || counts[k]).map(([k, t]) =>
      h("button", { class: "chip" + (pref.kind === k ? " on" : ""), "aria-pressed": pref.kind === k ? "true" : "false",
        onclick: () => { pref.kind = k; save(); render(); } }, t, h("span", { class: "n", text: String(counts[k] || 0) }))));
    const shown = phones.filter((p) => (pref.kind === "all" || kindOf(p) === pref.kind) &&
      (!q || p.name.toLowerCase().includes(q) || p.model.toLowerCase().includes(q)));
    const sort = sorters[pref.sort] || byName;
    const isOn = (p) => p.state !== "off";
    const groups = [[secRun, shown.filter(isOn).sort(sort)], [secOff, shown.filter((p) => !isOn(p)).sort(sorters[pref.sort === "kind" ? "kind" : "name"])]];
    for (const [sec, list] of groups) {
      sec.hidden = !list.length;
      sec.querySelector(".count").textContent = String(list.length);
      const box = sec.lastChild;
      for (const p of list) {
        let c = cards.get(p.id);
        if (!c) { c = make(p); cards.set(p.id, c); }
        update(c, p);
        box.append(c.el);  // moves it into order (and across sections when it starts / stops)
      }
    }
    for (const [id, c] of cards) if (!shown.some((p) => p.id === id)) { c.el.remove(); if (!phones.some((p) => p.id === id)) cards.delete(id); }
    const on = phones.filter((p) => p.state === "running");
    total.textContent = phones.length ? `${phones.length} · ${on.length} running` + (on.length ? ` · ${fmtMem(on.reduce((a, p) => a + (p.memory_mb || 0), 0))}` : "") : "";
    empty.hidden = shown.length > 0;
    empty.textContent = !phones.length ? "No devices" : "Nothing matches";
  }

  async function tick() {
    if (!alive) return;
    try { phones = await api("/api/phones"); } catch (e) { if (e.status === 401) return boot(); return; }
    if (!alive) return;
    n++;
    render();
  }
  async function act(e, id, what) {
    e.target.disabled = true;
    try { await api(`/api/phones/${encodeURIComponent(id)}/${what}`, {}); toast(what === "start" ? "Starting…" : "Stopping…"); }
    catch (err) { toast(err.message); e.target.disabled = false; }
    tick();
  }
  setView(pref.view === "list" ? "list" : "grid");
  tick();
  const iv = setInterval(tick, 2000);
  return () => { alive = false; clearInterval(iv); };
}

// ---------- HID key codes (physical keys, US layout on the phone) ----------
const CODES = { Enter: 0x28, Escape: 0x29, Backspace: 0x2a, Tab: 0x2b, Space: 0x2c, Minus: 0x2d, Equal: 0x2e, BracketLeft: 0x2f, BracketRight: 0x30, Backslash: 0x31,
  Semicolon: 0x33, Quote: 0x34, Backquote: 0x35, Comma: 0x36, Period: 0x37, Slash: 0x38, CapsLock: 0x39, Insert: 0x49, Home: 0x4a, PageUp: 0x4b, Delete: 0x4c, End: 0x4d,
  PageDown: 0x4e, ArrowRight: 0x4f, ArrowLeft: 0x50, ArrowDown: 0x51, ArrowUp: 0x52, IntlBackslash: 0x64 };
function hidUsage(code) {
  let m;
  if ((m = code.match(/^Key([A-Z])$/))) return 4 + m[1].charCodeAt(0) - 65;
  if ((m = code.match(/^Digit([0-9])$/))) return m[1] === "0" ? 0x27 : 0x1e + Number(m[1]) - 1;
  if ((m = code.match(/^Numpad([0-9])$/))) return m[1] === "0" ? 0x27 : 0x1e + Number(m[1]) - 1;
  if (code === "NumpadEnter") return 0x28;
  return CODES[code];
}
const MODS = { ShiftLeft: 1, ShiftRight: 1, ControlLeft: 1, ControlRight: 1, AltLeft: 1, AltRight: 1, MetaLeft: 1, MetaRight: 1, OSLeft: 1, OSRight: 1 };

// ---------- one phone ----------
function phoneView(id) {
  currentPhone = id;
  const control = ME.role === "control";
  let info = null, ws = null, alive = true, retry = 0;
  const canvas = h("canvas", { class: "screen" + (control ? "" : " readonly"), tabindex: control ? "0" : null, width: 390, height: 844 });
  const ctx2d = canvas.getContext("2d", { alpha: false, desynchronized: true });
  const overlay = h("div", { class: "overlay", text: "Connecting…" });
  const dots = h("div", { class: "dots" });
  const wrap = h("div", { class: "screenwrap" }, canvas, dots, overlay);
  // the tool column beside the screen (buildSide fills it)
  const tools = h("div", { class: "tools" });
  const stage = h("div", { class: "stage" }, wrap, tools);
  const side = h("aside", { class: "side" });
  // a narrow screen (a phone's browser): the most used controls right under the screen, the rest below
  const quick = h("div", { class: "quick" });
  // the panels on a narrow screen: the screen takes every touch (it drives the device), so the page can't be scrolled
  // down to them; a button pinned at the strip's end slides them up as a sheet over the screen instead
  const panelsBtn = h("button", { class: "tool panels", type: "button", title: "Panels", "aria-label": "Panels", "aria-expanded": "false" },
    h("span", { class: "ic", text: "\uE434" }));
  const phoneEl = h("div", { class: "phone" }, stage, h("div", { class: "quickbar" }, quick, panelsBtn), side);
  main.append(phoneEl);
  const sheet = (open) => {
    phoneEl.classList.toggle("sheet", open);
    panelsBtn.classList.toggle("on", open);
    panelsBtn.setAttribute("aria-expanded", String(open));
    if (open) side.style.cssText = `bottom:${phoneEl.querySelector(".quickbar").offsetHeight}px`;
  };
  panelsBtn.onclick = () => sheet(!phoneEl.classList.contains("sheet"));
  document.addEventListener("pointerdown", (e) => {
    if (phoneEl.classList.contains("sheet") && !side.contains(e.target) && !panelsBtn.contains(e.target) && !e.target.closest?.(".hingepop, dialog")) sheet(false);
  }, true);
  document.addEventListener("keydown", (e) => { if (e.key === "Escape" && phoneEl.classList.contains("sheet")) sheet(false); });
  // the Accessibility Inspector (axinspect.js): its overlay on the screen, its panel in the side bar
  const axi = window.AXI ? AXI.attach({ id, wrap, side, control, api, h, toast }) : null;
  const stats = h("div", { class: "stats" });
  const prefs = JSON.parse(localStorageGet("x86sim_prefs") || "{}");
  const canH264 = "VideoDecoder" in window && window.isSecureContext;
  let codec = prefs.codec === "jpeg" || !canH264 ? "jpeg" : "h264";
  let quality = prefs.quality ?? 1, fps = prefs.fps ?? 30;
  // a two-screen phone in 3D (duo3d.js) where WebGL2 is there and the server has Apple's model, else the flat stream
  let duoOK = !!(window.Duo3D && Duo3D.supported());
  let duo = null, duoLoading = false;
  // the hinge panel's slider following the hinge as it is (hingePanel sets it)
  // every hinge panel on the page (the fold, the strip's popup) follows the hinge as it moves
  const hingeSyncs = new Set();
  // the stream width the socket asked for
  let connW = 0;

  // --- sizing: the canvas keeps the stream's aspect inside the stage
  let fw = 0, fh = 0;
  function fit() {
    if (duo) {
      // the stage's content box less the tool column and its gap
      const r = stage.getBoundingClientRect(), cs = getComputedStyle(stage), tw = tools.offsetWidth ? tools.offsetWidth + 14 : 0;
      const px = (k) => parseFloat(cs[k]) || 0;
      return duo.resize(r.width - px("paddingLeft") - px("paddingRight") - tw - 2, r.height - px("paddingTop") - px("paddingBottom") - 2);
    }
    // before the first frame: the phone's shape from its screen size
    const scr = info?.screen;
    const w = fw || (scr && scr[0]), hh = fh || (scr && scr[1]);
    if (!w) return;
    // the stage's padding and the bezel drawn around the canvas (app.css) on both sides
    const r = stage.getBoundingClientRect(), m = innerWidth <= 760 ? 28 : 64;
    // the tool column beside the screen takes its width and the gap
    const tw = tools.offsetWidth ? tools.offsetWidth + 14 : 0;
    const s = Math.min((r.width - m - tw) / w, (r.height - m) / hh);
    const cw = Math.max(50, Math.floor(w * s)), ch = Math.max(50, Math.floor(hh * s));
    canvas.style.width = cw + "px";
    canvas.style.height = ch + "px";
    // the device type's corners (app.css's by platform without one)
    canvas.style.borderRadius = typeof info?.corner === "number" ? Math.max(2, info.corner * cornerSide(info.platform, cw, ch)) + "px" : "";
  }
  const ro = new ResizeObserver(fit);
  ro.observe(stage);
  function setSize(w, hh) {
    if (canvas.width !== w || canvas.height !== hh) { canvas.width = w; canvas.height = hh; }
    if (w !== fw || hh !== fh) { fw = w; fh = hh; fit(); }
  }
  function wantWidth() {
    const r = stage.getBoundingClientRect();
    // the picture's shape as it arrives (a turned device is wide), else the screen's
    const scr = info?.screen || [1206, 2622];
    const aspect = fw && fh ? fw / fh : scr[0] / scr[1];
    const css = Math.min(r.width - 24, (r.height - 24) * aspect) * (window.devicePixelRatio || 1);
    const cap = [540, 900, 1400][quality];
    // the 3D phone: the inner screen spans about the area's width
    if (duo) return Math.max(240, Math.min(cap, Math.round(r.width * (window.devicePixelRatio || 1) / 16) * 16));
    return Math.max(240, Math.min(cap, Math.round(css / 16) * 16));
  }

  // --- stats
  let frames = 0, bytes = 0, lat = [], lastStats = performance.now(), statLine = "", curFps = 0;
  const statIv = setInterval(() => {
    const now = performance.now(), dt = (now - lastStats) / 1000;
    lastStats = now;
    const l = lat.length ? lat.reduce((a, b) => a + b, 0) / lat.length : null;
    curFps = Math.round(frames / dt);
    // nothing to say before the first frame (a device that is off)
    statLine = !fw ? "" : `${codec.toUpperCase()} ${fw}×${fh}\n${(frames / dt).toFixed(0)} fps · ${(bytes * 8 / dt / 1e6).toFixed(2)} Mbit/s` + (l !== null && l >= 0 && l < 5000 ? `\nframe age ${l.toFixed(0)} ms` : "");
    if (soundOn && actx && aLat.length) {
      // packet age on arrival + what is queued + the output's own latency
      const net = aLat.reduce((a, b) => a + b, 0) / aLat.length;
      const q = Math.max(0, nextT - actx.currentTime) * 1000, out = ((actx.outputLatency || 0) + (actx.baseLatency || 0)) * 1000;
      statLine += `\nsound ${aCodec} ${(net + q + out).toFixed(0)} ms (net ${net.toFixed(0)}, queue ${q.toFixed(0)}, out ${out.toFixed(0)})` + (aLost || aUnder ? ` · ${aLost} dropped, ${aUnder} gaps` : "");
      window.__x86simSound = { net, queue: q, out, codec: aCodec, lost: aLost, gaps: aUnder };
    }
    stats.textContent = statLine;
    frames = 0; bytes = 0; lat = []; aLat = [];
  }, 1000);

  // --- video
  let dec = null, decCodec = "", needKey = true, jpegBusy = false, pendingJpeg = null;
  function send(o) { if (ws && ws.readyState === 1) ws.send(JSON.stringify(o)); }
  function codecOf(b) {
    // the SPS after an Annex B start code: avc1.PPCCLL
    for (let i = 0; i + 7 < b.length; i++) {
      if (b[i] === 0 && b[i + 1] === 0 && b[i + 2] === 1 && (b[i + 3] & 0x1f) === 7) {
        const x = (v) => v.toString(16).padStart(2, "0");
        return "avc1." + x(b[i + 4]) + x(b[i + 5]) + x(b[i + 6]);
      }
    }
    return null;
  }
  function draw(src, w, hh) {
    setSize(w, hh);
    ctx2d.drawImage(src, 0, 0, w, hh);
    frames++;
    overlay.hidden = true;
  }
  function newDecoder() {
    if (dec && dec.state !== "closed") try { dec.close(); } catch {}
    dec = new VideoDecoder({
      output: (f) => { draw(f, f.displayWidth, f.displayHeight); f.close(); },
      error: (e) => { console.warn("decoder", e); needKey = true; decCodec = ""; send({ t: "key-frame" }); },
    });
    decCodec = "";
  }
  async function onH264(key, w, hh, t, data) {
    if (needKey && !key) return;
    if (key) {
      const c = codecOf(data);
      if (c && (c !== decCodec || !dec || dec.state === "closed")) {
        if (!dec || dec.state === "closed") newDecoder();
        const cfg = { codec: c, optimizeForLatency: true, codedWidth: w, codedHeight: hh };
        const sup = await VideoDecoder.isConfigSupported(cfg).catch(() => ({ supported: false }));
        if (!sup.supported) { toast("This browser can't decode H.264: using JPEG"); codec = "jpeg"; return connect(); }
        dec.configure(cfg);
        decCodec = c;
      }
      needKey = false;
    }
    if (!dec || dec.state !== "configured") { needKey = true; return; }
    if (dec.decodeQueueSize > 4 && !key) { needKey = true; send({ t: "key-frame" }); return; }
    dec.decode(new EncodedVideoChunk({ type: key ? "key" : "delta", timestamp: t, data }));
  }
  function onJpeg(data) {
    if (jpegBusy) { pendingJpeg = data; return; }
    jpegBusy = true;
    createImageBitmap(new Blob([data], { type: "image/jpeg" })).then((bm) => { draw(bm, bm.width, bm.height); bm.close(); })
      .catch(() => {}).finally(() => { jpegBusy = false; if (pendingJpeg) { const d = pendingJpeg; pendingJpeg = null; onJpeg(d); } });
  }

  // --- sound: the phone's mix as Opus (WebCodecs AudioDecoder) or 16-bit PCM, 10 ms packets scheduled ~40 ms ahead on
  // an AudioContext; off until the viewer turns it on (browsers start audio only from a click). The microphone: the
  // viewer's getUserMedia as 16-bit mono 48 kHz frames back to the phone (control links, an explicit toggle, HTTPS).
  const canOpus = "AudioDecoder" in window && window.isSecureContext;
  const canMic = !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia) && window.isSecureContext && "AudioWorkletNode" in window;
  let actx = null, gain = null, adec = null, aCodec = "", nextT = 0, soundOn = false, volume = prefs.volume ?? 0.8;
  let aLat = [], aLost = 0, aUnder = 0, aMin = 1, aN = 0, soundBtns = [], recBtns = [], micBtn = null, mic = null;
  async function soundStart() {
    try {
      actx = new (window.AudioContext || window.webkitAudioContext)({ sampleRate: 48000, latencyHint: "interactive" });
    } catch { actx = new (window.AudioContext || window.webkitAudioContext)({ latencyHint: "interactive" }); }
    actx.resume();
    gain = actx.createGain();
    gain.gain.value = volume;
    gain.connect(actx.destination);
    aCodec = "pcm";
    if (canOpus) {
      const cfg = { codec: "opus", sampleRate: 48000, numberOfChannels: 2 };
      const sup = await AudioDecoder.isConfigSupported(cfg).catch(() => ({ supported: false }));
      if (sup.supported) {
        adec = new AudioDecoder({ output: (d) => { playAudioData(d); d.close(); }, error: (e) => { console.warn("audio", e); adec = null; if (soundOn) { soundStop(); soundStart(); } } });
        adec.configure(cfg);
        aCodec = "opus";
      }
    }
    soundOn = true; nextT = 0;
    send({ t: "audio", on: true, codec: aCodec });
    updateSound();
  }
  function soundStop() {
    soundOn = false;
    send({ t: "audio", on: false });
    if (adec && adec.state !== "closed") try { adec.close(); } catch {}
    adec = null;
    if (actx) actx.close().catch(() => {});
    actx = null; gain = null;
    updateSound();
  }
  function updateSound() {
    for (const b of soundBtns) { setIcon(b, soundOn ? I.soundOn : I.soundOff); b.classList.toggle("on", soundOn); }
    if (micBtn) { micBtn.textContent = mic ? "Mic on" : "Mic off"; micBtn.classList.toggle("on", !!mic); }
  }
  function schedule(planes, n) {
    if (!actx) return;
    const now = actx.currentTime;
    // underrun (or the first packet): start 30 ms ahead; more than 150 ms queued: drop to catch up
    if (nextT < now + 0.005) { if (nextT) aUnder++; nextT = now + 0.03; aMin = 1; aN = 0; }
    else if (nextT > now + 0.15) { aLost++; return; }
    // a second in which the queue never went below 45 ms (a burst after a stall): skip a packet to give 10 ms back
    aMin = Math.min(aMin, nextT - now);
    if (++aN >= 100) { const skip = aMin > 0.045; aMin = 1; aN = 0; if (skip) return; }
    const b = actx.createBuffer(2, n, 48000);
    b.copyToChannel(planes[0], 0);
    b.copyToChannel(planes[1] || planes[0], 1);
    const src = actx.createBufferSource();
    src.buffer = b;
    src.connect(gain);
    src.start(nextT);
    nextT += n / 48000;
  }
  function playAudioData(d) {
    const n = d.numberOfFrames, planes = [];
    for (let c = 0; c < Math.min(2, d.numberOfChannels); c++) {
      const a = new Float32Array(n);
      d.copyTo(a, { planeIndex: c, format: "f32-planar" });
      planes.push(a);
    }
    schedule(planes, n);
  }
  function onAudio(kind, restart, t, data) {
    if (!soundOn || !actx) return;
    aLat.push(Date.now() - t / 1000);
    if (restart) nextT = 0;
    if (kind === 3 && adec && adec.state === "configured") {
      adec.decode(new EncodedAudioChunk({ type: "key", timestamp: t, data }));
    } else if (kind === 4) {
      const n = data.byteLength / 4, dv = new DataView(data.buffer, data.byteOffset, data.byteLength);
      const l = new Float32Array(n), r = new Float32Array(n);
      for (let i = 0; i < n; i++) { l[i] = dv.getInt16(i * 4, true) / 32768; r[i] = dv.getInt16(i * 4 + 2, true) / 32768; }
      schedule([l, r], n);
    }
  }
  function setVolume(v) {
    volume = v;
    if (gain) gain.gain.value = v;
    save();
  }
  async function micStart() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: { channelCount: 1, echoCancellation: true, noiseSuppression: true, autoGainControl: true } });
      const ctx = new AudioContext({ latencyHint: "interactive" });
      await ctx.audioWorklet.addModule("mic.js");
      const node = new AudioWorkletNode(ctx, "x86sim-mic", { numberOfInputs: 1, numberOfOutputs: 0, channelCount: 1, channelCountMode: "explicit" });
      node.port.onmessage = (e) => {
        if (!ws || ws.readyState !== 1) return;
        const f = e.data, b = new ArrayBuffer(1 + f.length * 2), dv = new DataView(b);
        dv.setUint8(0, 5);
        for (let i = 0; i < f.length; i++) dv.setInt16(1 + i * 2, Math.max(-32768, Math.min(32767, Math.round(f[i] * 32767))), true);
        ws.send(b);
      };
      ctx.createMediaStreamSource(stream).connect(node);
      mic = { stream, ctx, node };
    } catch (e) { toast("Microphone: " + (e.message || e.name)); mic = null; }
    updateSound();
  }
  function micStop() {
    if (mic) { mic.stream.getTracks().forEach((t) => t.stop()); mic.ctx.close().catch(() => {}); mic = null; }
    send({ t: "mic", on: false });
    updateSound();
  }

  function connect() {
    if (ws) { ws.onclose = null; ws.close(); }
    if (!alive) return;
    needKey = true;
    const proto = location.protocol === "https:" ? "wss:" : "ws:";
    // duo=1: a two-screen phone sends both screens (the 3D view); a one-screen phone ignores it
    const w = connW = wantWidth();
    if (duo) duo.reset();
    const u = `${proto}//${location.host}/ws/${encodeURIComponent(id)}?codec=${codec}&w=${w}&q=${quality}&fps=${fps}` + (duoOK ? `&duo=1&w2=${Math.round(w * 0.6 / 16) * 16}` : "") + (TOKEN ? "&t=" + encodeURIComponent(TOKEN) : "");
    ws = new WebSocket(u);
    ws.binaryType = "arraybuffer";
    ws.onopen = () => { retry = 0; if (soundOn) { nextT = 0; send({ t: "audio", on: true, codec: aCodec }); } };
    ws.onmessage = (ev) => {
      if (typeof ev.data === "string") return onText(JSON.parse(ev.data));
      const dv = new DataView(ev.data);
      const kind = dv.getUint8(0), key = dv.getUint8(1) === 1, w = dv.getUint16(2, true), hh = dv.getUint16(4, true);
      const t = Number(dv.getBigUint64(6, true));
      const data = new Uint8Array(ev.data, 14);
      bytes += ev.data.byteLength;
      if (kind === 3 || kind === 4) return onAudio(kind, key, t, data);
      lat.push(Date.now() - t / 1000);
      if (duo && (kind & 15) <= 2) return duo.packet(kind, key, w, hh, t, data);
      if (kind === 1) onH264(key, w, hh, t, data);
      else if (kind === 2) onJpeg(data);
    };
    ws.onclose = () => {
      if (!alive) return;
      overlay.hidden = false;
      overlay.textContent = "Reconnecting…";
      setTimeout(connect, Math.min(5000, 500 * 2 ** retry++));
    };
  }
  let lastState = {};
  function onText(m) {
    if (m.t === "hello") {
      // a server restarted on another build: this tab still runs the old scripts, so load the new ones
      if (m.build && window.__x86simBuild && m.build !== window.__x86simBuild) { location.reload(); return; }
      if (m.build) window.__x86simBuild = m.build;
      info = { ...info, ...m };
      head();
      document.title = m.name + " · x86Sim";
      canvas.classList.toggle("watch", m.platform === "watchos");
      canvas.classList.toggle("tv", m.platform === "tvos" || m.platform === "xros");
      if (m.two_screens && duoOK && !duo) startDuo();
      buildSide();
    } else if (m.t === "state") {
      lastState = m;
      if (duo) duo.state(m);
      if (m.hinge != null) for (const f of hingeSyncs) f(Number(m.hinge), m.orientation);
      if (!m.running) { overlay.hidden = false; overlay.textContent = "Off"; }
      updateSide();
    } else if (m.t === "expired") {
      alive = false;
      overlay.hidden = false;
      overlay.textContent = "This link has expired.";
    } else if (m.t === "error") toast(m.error);
  }

  // --- the 3D phone (duo3d.js) in place of the flat canvas
  function startDuo() {
    if (duoLoading) return;
    duoLoading = true;
    Duo3D.load().then((model) => {
      duoLoading = false;
      if (duo || !alive) return;
      // no model on the server: the phone flat, its own stream
      if (!model) { duoOK = false; connect(); return; }
      showDuo(model);
    });
  }
  function showDuo(model) {
    duo = Duo3D.create({
      model, control, send,
      onFrame: (w, hh, s) => { frames++; overlay.hidden = true; if (s === "inner" || !fw) { fw = w; fh = hh; } },
      onNoH264: () => { toast("This browser can't decode H.264: using JPEG"); codec = "jpeg"; connect(); },
      onLost: () => { duo.close(); duo = null; canvas.hidden = false; connect(); },
    });
    if (!duo) return;
    canvas.hidden = true;
    wrap.prepend(duo.el);
    duo.state({ ...info, ...lastState });
    bindKeys(duo.canvas);
    window.__x86simDuo = duo.debug;
    fit();
  }

  // --- side panel
  let fold = null;
  function btn(label, title, down, up) {
    const b = h("button", { class: "btn small", text: label, title, type: "button" });
    if (up) {
      b.addEventListener("pointerdown", (e) => { e.preventDefault(); b.setPointerCapture(e.pointerId); down(); });
      b.addEventListener("pointerup", up);
      b.addEventListener("pointercancel", up);
    } else b.addEventListener("click", down);
    return b;
  }
  const hold = (n, label, title) => btn(label, title || label, () => send({ t: "button", n, d: true }), () => send({ t: "button", n, d: false }));
  const keyHold = (u, label, title) => btn(label, title || label, () => send({ t: "key", u, d: true }), () => send({ t: "key", u, d: false }));
  function group(title, ...kids) { return h("div", {}, h("h4", { text: title }), h("div", { class: "btns" }, ...kids)); }
  // the launcher's Phosphor icons (icons.ttf, the glyphs used here)
  const I = { home: "", lock: "", volup: "", voldown: "", siri: "", action: "", switcher: "",
    rotl: "", rotr: "", shake: "", pointer: "", type: "", soundOn: "", soundOff: "",
    camera: "", marks: "", record: "", stop: "", back: "", up: "", down: "",
    tv: "", playpause: "", tap: "", wave: "", mute: "", press: "", share: "",
    hingeOpen: "\uE0E6", hingeClosed: "\uE1E0", tablet: "\uE1E6", laptop: "\uE586", resetView: "\uE08A" };
  const icon = (c) => h("span", { class: "ic", text: c });
  function setIcon(b, c) { if (b && b.firstChild) b.firstChild.textContent = c; }
  // an icon button of the tool column beside the screen (the launcher's screen toolbar); held down for `up`
  function tool(c, title, down, up) {
    const b = h("button", { class: "tool", type: "button", title, "aria-label": title }, icon(c));
    if (up) {
      b.addEventListener("pointerdown", (e) => { e.preventDefault(); b.setPointerCapture(e.pointerId); down(); });
      b.addEventListener("pointerup", up);
      b.addEventListener("pointercancel", up);
    } else b.addEventListener("click", down);
    return b;
  }
  const holdT = (n, c, title) => tool(c, title, () => send({ t: "button", n, d: true }), () => send({ t: "button", n, d: false }));
  const link = (c, title, href) => h("a", { class: "tool", href, download: "", title, "aria-label": title }, icon(c));
  const gap = () => h("span", { class: "tgap" });
  function buildSide() {
    const p = info.platform;
    // the launcher's panels (panels.js): overview, Features, Logs, Performance, Simulate
    if (!pan && window.PANELS) pan = PANELS.attach({ id, control, platform: p, api, h, toast, copy, name: info.name || id, fmtMem, fmtUp, send, fps: () => curFps, restart,
      onDetail: (d) => { needsRestart = !!d.needs_restart; head(); } });
    const fold = (key, title, body, open) => pan ? pan.fold(key, title, body, null, open) : h("div", {}, h("h4", { text: title }), body);

    // ---- the device's buttons, then capture and share (the launcher's screen toolbar): beside the screen on a wide
    // window, the strip under it on a narrow one (each place its own buttons, built the same way)
    soundBtns = []; recBtns = [];
    // one order on every device, as the launcher's screen toolbar (phone.rs screen_toolbar): the hardware buttons
    // (Home, crown, Lock / side, volume, mute, Siri, Action, Back, Play/Pause, App Switcher), the device actions
    // (rotate, shake, pointer, hand gestures, typing), then the page's own tools (share, sound, record, screenshots).
    // Each device shows only what it has, never in another order.
    const makeTools = () => {
      const t = [];
      if (control) {
        const crown = p === "watchos" || p === "xros";
        if (p === "tvos") {
          t.push(holdT("tv", I.tv, "TV / home (F1)"), holdT("volup", I.volup, "Volume up"), holdT("voldown", I.voldown, "Volume down"),
            holdT("mute", I.mute, "Mute"), holdT("siri", I.siri, "Siri"), holdT("menu", I.back, "Back (Esc)"), holdT("playpause", I.playpause, "Play / Pause"));
        } else if (crown) {
          t.push(holdT("home", I.press, "Digital Crown: press"), tool(I.up, "Digital Crown: turn up", () => send({ t: "crown", d: -120 })),
            tool(I.down, "Digital Crown: turn down", () => send({ t: "crown", d: 120 })), holdT("side", I.lock, p === "xros" ? "Top button" : "Side button"));
        } else {
          t.push(holdT("home", I.home, "Home (F1)"), holdT("lock", I.lock, "Lock: the side button (F2)"), holdT("volup", I.volup, "Volume up (F3)"),
            holdT("voldown", I.voldown, "Volume down (F4)"), holdT("siri", I.siri, "Siri"), holdT("action", I.action, "Action button"),
            tool(I.switcher, "App Switcher", () => send({ t: "sys", a: "app_switcher" })));
        }
        t.push(gap());
        if (p === "ios") {
          t.push(tool(I.rotl, "Rotate left", () => send({ t: "rotate", dir: "left" })), tool(I.rotr, "Rotate right", () => send({ t: "rotate", dir: "right" })));
          // a two-screen phone's hinge, as the launcher's strip: a popup with the slider, the poses and the view's reset
          if (info.two_screens) t.push(hingeTool());
          t.push(tool(I.shake, "Shake", () => send({ t: "shake" })));
          // an iPad's pointer capture, as the launcher and Apple's simulator: the mouse drives the iPad's pointer
          if (info.ipad) {
            const ptr = tool(I.pointer, "Pointer capture: the mouse drives the iPad's pointer", () => {
              pointerMode = !pointerMode;
              if (!pointerMode) send({ t: "pointer", a: "remove" });
              for (const b of document.querySelectorAll(".tool.ptr")) b.classList.toggle("on", pointerMode);
            });
            ptr.classList.add("ptr");
            ptr.classList.toggle("on", pointerMode);
            t.push(ptr);
          }
        }
        if (p === "watchos")
          t.push(tool(I.tap, "Double tap (hand gesture)", () => send({ t: "sys", a: "double_tap" })), tool(I.wave, "Wrist flick (hand gesture)", () => send({ t: "sys", a: "wrist_flick" })));
        t.push(tool(I.type, "Type text into the device (Ctrl+V pastes)", openPaste));
      }
      const sb = tool(I.soundOff, "The device's sound in this browser", () => (soundOn ? soundStop() : soundStart()));
      const rb = tool(I.record, "Record the screen to a video file", toggleRec);
      soundBtns.push(sb); recBtns.push(rb);
      t.push(gap());
      // share this device: links are the server owner's to make (as the header's Share)
      if (ME.owner) t.push(tool(I.share, "Share this device", () => openShare(id)));
      t.push(sb, rb, link(I.camera, "Screenshot (PNG)", withToken(`/api/phones/${encodeURIComponent(id)}/screenshot.png`)),
        link(I.marks, "Screenshot with every element's @ref", withToken(`/api/phones/${encodeURIComponent(id)}/screenshot.png?marks=all`)));
      return t;
    };
    tools.replaceChildren(...makeTools());
    quick.replaceChildren(...makeTools().filter((e) => !e.classList.contains("tgap")));

    // ---- the inspector: the overview, then folds (open ones remembered), as the launcher's right panel
    const parts = [pan ? pan.overview : null];
    if (control && p === "tvos") parts.push(fold("remote", "Siri Remote", h("div", { class: "remote" },
      h("span"), keyHold(0x52, "▲", "Up"), h("span"),
      keyHold(0x50, "◀", "Left"), keyHold(0x28, "●", "Select"), keyHold(0x4f, "▶", "Right"),
      h("span"), keyHold(0x51, "▼", "Down"), h("span")), true));
    if (control && p === "ios" && info.two_screens) parts.push(fold("hinge", "Hinge", hingePanel(), true));
    if (pan) parts.push(pan.features, pan.gpu, pan.logs);
    // the Network section (netpanel.js): an app's requests, control links only
    if (control && p === "ios" && window.NETPANEL) { if (!netp) netp = NETPANEL.attach({ id, api, h, toast, copy, name: info.name || id }); parts.push(netp.panel); }
    // Share, as the launcher's section: this device's links and the tunnels that make them reach other machines
    if (ME.owner) {
      const info2 = h("div", { class: "kvs" });
      const shareFold = fold("share", "Share", [info2, h("div", { class: "btns" }, h("button", { class: "btn small primary", type: "button", text: "Make a link…", onclick: () => openShare(id) }))]);
      const fill = async () => {
        try {
          const [u, l] = await Promise.all([api("/api/urls"), api("/api/links")]);
          const up = u.tunnels.filter((t) => t.state === "up").map((t) => ({ tailscale: "Tailscale", funnel: "Funnel", cloudflared: "Cloudflare" })[t.kind] || t.kind);
          const mine = l.filter((x) => !x.phone || x.phone === id).length;
          info2.replaceChildren(h("div", { class: "kv" }, h("span", { text: "Reachable" }), h("span", { text: up.length ? up.join(", ") : "this machine only" })),
            h("div", { class: "kv" }, h("span", { text: "Links" }), h("span", { text: mine ? `${mine} for this device` : "none yet" })));
          shareFold.sum.textContent = up.length ? up.join(", ") : "";
        } catch {}
      };
      fill();
      shareFold.addEventListener("toggle", () => shareFold.open && fill());
      $("#shareDlg").addEventListener("close", fill);
      parts.push(shareFold);
    }
    if (axi) {
      const ax = axi.panel();
      const h4 = ax.querySelector(":scope > h4");
      if (h4) h4.remove();
      parts.push(fold("ax", "Accessibility", ax));
    }
    if (control && p !== "watchos") parts.push(fold("web", "Web Inspector", webPanel()));
    if (pan && pan.perf) {
      // x86sim profile: 5 s CPU profile of the app in front, downloaded as speedscope JSON (control links only)
      if (control && !pan.perf.querySelector(".profile")) pan.perf.querySelector(".fbody").prepend(h("div", { class: "btns profile" },
        h("a", { class: "btn small", href: withToken(`/api/phones/${encodeURIComponent(id)}/profile.json?secs=5`), download: "",
          title: "5 s CPU profile of the app in front (speedscope JSON)", text: "Profile 5 s" })));
      parts.push(pan.perf);
    }
    if (pan) parts.push(pan.simulate);
    const volIn = h("input", { type: "range", min: 0, max: 1, step: 0.05, value: volume, title: "Volume (this browser only)", class: "vol", oninput: (e) => setVolume(Number(e.target.value)) });
    micBtn = control ? btn("", canMic ? "Your microphone into the device" : "Needs HTTPS or localhost", () => (mic ? micStop() : micStart())) : null;
    if (micBtn && !canMic) micBtn.disabled = true;
    const qSel = h("select", { onchange: (e) => { quality = Number(e.target.value); save(); connect(); } }, ["Low", "Medium", "High"].map((l, i) => h("option", { value: i, selected: i === quality, text: l })));
    const cSel = h("select", { onchange: (e) => { codec = e.target.value; save(); connect(); } },
      h("option", { value: "h264", text: "H.264" + (canH264 ? "" : " (needs HTTPS)"), selected: codec === "h264", disabled: !canH264 }), h("option", { value: "jpeg", text: "JPEG", selected: codec === "jpeg" }));
    const fSel = h("select", { onchange: (e) => { fps = Number(e.target.value); save(); connect(); } }, [15, 30, 60].map((f) => h("option", { value: f, selected: f === fps, text: f + " fps" })));
    parts.push(fold("av", "Sound and stream", [
      h("div", { class: "sfield" }, h("div", { class: "sl", text: "Volume (this browser)" }), h("div", { class: "btns" }, volIn, micBtn)),
      h("div", { class: "sfield" }, h("div", { class: "sl", text: "Picture" }), h("div", { class: "btns" }, qSel, cSel, fSel), stats)]));
    if (control) parts.push(fold("keys", "Keyboard and mouse", h("div", { class: "kbd" }, ...keyHelp(p).slice(1))));
    side.replaceChildren(...parts.filter(Boolean));
    updateSound();
    updateSide();
  }
  // Web Inspector: the phone's inspectable pages (Safari, WKWebViews with isInspectable), each with an Inspect link
  // (share/inspect.rs). Asked for on a click only: the first ask starts the phone's webinspectord.
  function webPanel() {
    const list = h("div", { class: "webpages" });
    const find = async () => {
      list.replaceChildren(h("div", { class: "muted", text: "Looking…" }));
      try {
        const r = await fetch(withToken(`/api/web/${encodeURIComponent(id)}`));
        const j = await r.json();
        if (!r.ok) throw new Error(j.error || r.status);
        const pages = j.apps.flatMap((a) => a.pages.map((pg) => ({ ...pg, app: a.name || a.bundle })));
        if (j.ui_error) list.append(h("div", { class: "muted", text: j.ui_error }));
        if (!pages.length) { list.replaceChildren(h("div", { class: "muted", text: "No inspectable pages", title: "Open one in Safari, or an app whose WKWebView sets isInspectable" })); return; }
        list.replaceChildren(...pages.map((pg) => h("div", { class: "webpage" },
          j.ui_error ? null : h("a", { class: "btn small", href: pg.href, target: "_blank", rel: "noopener", text: "Inspect" }),
          h("span", { text: ` ${pg.title || "(untitled)"} · ${pg.app}`, title: pg.url }))));
      } catch (e) { list.replaceChildren(h("div", { class: "muted", text: "Web Inspector: " + e.message })); }
    };
    return h("div", {}, h("div", { class: "btns" }, btn("Find web pages", "Safari pages and inspectable web views, in Web Inspector", find)), list);
  }
  function keyHelp(p) {
    if (p === "xros") return [h("h4", { text: "Keys" }), ...[["Mouse", "the system pointer: hover, click, drag"], ["Wheel", "scroll where it points"], ["Keys", "the keyboard (click the screen first)"], ["Ctrl+V", "paste"]].flatMap(([a, b]) => [h("b", { text: a }), h("span", { text: b })])];
    const l = [["Click / drag", "touch"], ["Alt + drag", "pinch / rotate"], ["Shift + drag", "two-finger pan"], ["Wheel", p === "watchos" ? "Digital Crown" : p === "tvos" ? "swipe the remote" : "scroll"], ["Keys", "the device's keyboard (click the screen first)"], ["Ctrl+V", "paste"], ["F1 / F2 / F3 / F4", p === "tvos" ? "TV / play / vol" : "home / lock / vol"]];
    if (p === "tvos") l.splice(0, 3, ["Arrows, Enter, Esc", "remote: move, select, back"], ["Click", "select"]);
    return [h("h4", { text: "Keys" }), ...l.flatMap(([a, b]) => [h("b", { text: a }), h("span", { text: b })])];
  }
  // the title bar: Devices / name, model and OS, the state, Start or Stop; the tiles: memory, CPU, uptime (the
  // dashboard's numbers, polled)
  let lastHead = "", pan = null, netp = null, needsRestart = false, pointerMode = false;
  function head() {
    const d = info || {};
    const state = d.state || (lastState.running === false ? "off" : lastState.running ? "running" : "");
    const k = [d.name, d.model, d.os, state, control, needsRestart].join("|");
    if (k === lastHead) return;
    lastHead = k;
    $("#crumb").replaceChildren(h("a", { class: "back", href: "#/", title: "All devices" }, "‹ ", h("span", { class: "lbl", text: "Devices" })), h("span", { class: "sep", text: "/" }),
      h("span", { class: "here", text: d.name || id }), h("span", { class: "sub", text: [d.model, d.os].filter(Boolean).join(" · ") }), ...(state ? [badge(state)] : []));
    const running = state === "running" || state === "starting";
    const acts = [];
    if (control && state === "off" && d.installed !== false) acts.push(h("button", { class: "btn small good", type: "button", text: "Start", onclick: (e) => power(e, "start") }));
    if (control && state === "running") acts.push(h("button", { class: "btn small" + (needsRestart ? " primary" : ""), type: "button", text: needsRestart ? "Restart to apply" : "Restart",
      title: needsRestart ? "Feature or start settings changed since this device started" : "Stop and start again", onclick: restart }));
    if (control && running) acts.push(h("button", { class: "btn small danger", type: "button", text: "Stop", onclick: (e) => power(e, "stop") }));
    $("#acts").replaceChildren(...acts);
  }
  async function power(e, what) {
    e.target.disabled = true;
    try { await api(`/api/phones/${encodeURIComponent(id)}/${what}`, {}); toast(what === "start" ? "Starting…" : "Stopping…"); }
    catch (err) { toast(err.message); e.target.disabled = false; }
    poll();
  }
  async function restart(e) {
    if (e && e.target) e.target.disabled = true;
    try { await api(`/api/phones/${encodeURIComponent(id)}/restart`, {}); toast("Restarting…"); needsRestart = false; }
    catch (err) { toast(err.message); if (e && e.target) e.target.disabled = false; }
    poll();
  }
  // the strip's Hinge button: its icon follows the hinge (open / closed); a click opens the hinge panel beside it
  // (above the strip on a phone), closed by a click outside or Esc
  function hingeTool() {
    const at = Number(lastState.hinge ?? info.hinge ?? 180);
    let pop = null;
    const close = () => { if (pop) { pop.remove(); pop = null; document.removeEventListener("pointerdown", outside, true); document.removeEventListener("keydown", esc); } };
    const outside = (e) => { if (pop && !pop.contains(e.target) && !b.contains(e.target)) close(); };
    const esc = (e) => { if (e.key === "Escape") close(); };
    const b = tool(at >= 10 ? I.hingeOpen : I.hingeClosed, "Hinge: fold, half open, unfold", () => {
      if (pop) return close();
      pop = h("div", { class: "hingepop", role: "dialog", "aria-label": "Hinge" }, hingePanel());
      document.body.append(pop);
      const r = b.getBoundingClientRect();
      if (innerWidth <= 760) pop.style.cssText = `left:8px;right:8px;bottom:${innerHeight - r.top + 8}px`;
      else pop.style.cssText = `left:${Math.max(8, Math.min(r.right + 8, innerWidth - pop.offsetWidth - 8))}px;top:${Math.max(8, Math.min(r.top, innerHeight - pop.offsetHeight - 8))}px`;
      document.addEventListener("pointerdown", outside, true);
      document.addEventListener("keydown", esc);
    });
    hingeSyncs.add((deg) => setIcon(b, deg >= 10 ? I.hingeOpen : I.hingeClosed));
    return b;
  }
  // the hinge of a two-screen phone, as the launcher's panel: a slider from folded to flat over a degree scale (85°:
  // where the inner screen takes over), the poses as icons (the current one lit) and the 3D view's reset
  function hingePanel() {
    const val = h("span", { class: "muted" });
    const show = (v) => { val.textContent = `${Math.round(v)}° · ${v < 10 ? "closed" : v < 85 ? "half open" : v < 170 ? "open" : "flat"}`; };
    let cur = Number(lastState.hinge ?? info.hinge ?? 180), orient = lastState.orientation ?? info.orientation ?? null;
    let sentAt = 0, pend = null;
    const icons = [I.hingeClosed, I.hingeOpen, I.laptop, I.tablet];
    const poseBtns = (info.poses || []).map((ps, k) => {
      const b = tool(icons[k] || I.hingeOpen, ps.label, () => {
        send({ t: "hinge", pose: ps.key });
        if (duo && ps.angle != null) duo.pose(ps.angle, ps.orientation);
        if (ps.angle != null) { slider.value = ps.angle; cur = ps.angle; }
        if (ps.orientation) orient = ps.orientation;
        sentAt = performance.now();
        show(Number(slider.value)); lit();
      });
      b.dataset.k = k;
      return b;
    });
    const lit = () => (info.poses || []).forEach((ps, k) => poseBtns[k].classList.toggle("on", Math.abs(cur - ps.angle) < 1 && (!ps.orientation || !orient || ps.orientation === orient)));
    const slider = h("input", { type: "range", min: 0, max: 180, step: "any", value: cur, class: "vol", "aria-label": "Hinge angle",
      oninput: (e) => {
        const v = Number(e.target.value);
        // an input that only repeats what the device sync just set is no move of the user's (some browsers fire one
        // when the value is set under a finger): never sent back, so a stale angle can't echo to the device
        if (synced && performance.now() - synced[1] < 250 && Math.abs(v - synced[0]) < 0.01) return;
        cur = v; show(v); lit();
        // while dragged: a short move at most every 40 ms, the last value when let go
        clearTimeout(pend);
        const go = () => { sentAt = performance.now(); send({ t: "hinge", deg: v, ms: 40 }); if (duo) duo.command(v); };
        if (performance.now() - sentAt >= 40) go(); else pend = setTimeout(go, 40);
      } });
    // the scale: a tick every 15°, labelled every 45°, the screen swap at 85° in the accent colour
    const scale = h("div", { class: "hscale" });
    for (let d = 0; d <= 180; d += 15) {
      const tk = h("span", { class: "tk" + (d % 45 === 0 ? " big" : "") });
      tk.style.cssText = `left:${(d / 180) * 100}%`;
      scale.append(tk);
      if (d % 45 === 0) { const lb = h("span", { class: "lb", text: d + "°" }); lb.style.cssText = `left:${(d / 180) * 100}%`; scale.append(lb); }
    }
    const swap = h("span", { class: "tk swap", title: "85°: the inner screen takes over above this, the outer one below" });
    swap.style.cssText = `left:${(85 / 180) * 100}%`;
    scale.append(swap);
    show(cur); lit();
    // moved from elsewhere (a pose, the MCP, the CLI): the slider follows unless it was just used here
    // held: a finger or the mouse is on the slider (a touch doesn't focus it); it never follows the device then, and
    // after a move from here only once the device has caught up with the angle sent (or 3 s on)
    let held = false, synced = null;
    // pointer and touch both (a touch on a range can end its pointer events early, as the browser takes the gesture)
    for (const ev of ["pointerdown", "touchstart", "mousedown"]) slider.addEventListener(ev, () => { held = true; }, { passive: true });
    for (const ev of ["pointerup", "touchend", "touchcancel", "mouseup"]) window.addEventListener(ev, () => { held = false; }, { passive: true });
    hingeSyncs.add((deg, o) => {
      if (o) orient = o;
      const since = performance.now() - sentAt;
      if (held || document.activeElement === slider || since < 1000) return;
      if (since < 3000 && Math.abs(deg - Number(slider.value)) > 1.5) return;
      slider.value = deg; synced = [Number(slider.value), performance.now()]; cur = deg; show(deg); lit();
    });
    const reset = tool(I.resetView, "Reset the view", () => duo && duo.resetView && duo.resetView());
    return h("div", { class: "hingepanel" }, h("div", { class: "hingerow" }, slider, val), scale,
      h("div", { class: "hposes" }, ...poseBtns, h("span", { class: "grow" }), reset));
  }
  function updateSide() {
    head();
  }
  async function poll() {
    try {
      const ps = await api("/api/phones");
      const p = ps.find((x) => x.id === id || x.name === id);
      if (p && alive) { info = { ...info, ...p }; updateSide(); }
    } catch {}
  }
  function save() { localStorageSet("x86sim_prefs", JSON.stringify({ codec, quality, fps, volume })); }

  // --- recording (the canvas as the browser shows it)
  let rec = null, chunks = [];
  function toggleRec() {
    if (rec) { rec.stop(); return; }
    const types = ["video/mp4;codecs=avc1", "video/webm;codecs=vp9", "video/webm;codecs=vp8", "video/webm"];
    const type = types.find((t) => window.MediaRecorder && MediaRecorder.isTypeSupported(t));
    if (!type) return toast("This browser can't record");
    const stream = (duo ? duo.canvas : canvas).captureStream(30);
    rec = new MediaRecorder(stream, { mimeType: type, videoBitsPerSecond: 8e6 });
    chunks = [];
    rec.ondataavailable = (e) => e.data.size && chunks.push(e.data);
    rec.onstop = () => {
      const blob = new Blob(chunks, { type: type.split(";")[0] });
      const a = h("a", { href: URL.createObjectURL(blob), download: `${info?.name || "device"}-${new Date().toISOString().replace(/[:.]/g, "-")}.${type.includes("mp4") ? "mp4" : "webm"}` });
      document.body.append(a); a.click(); a.remove();
      setTimeout(() => URL.revokeObjectURL(a.href), 10000);
      rec = null;
      for (const b of recBtns) { setIcon(b, I.record); b.classList.remove("rec"); }
    };
    rec.start(1000);
    for (const b of recBtns) { setIcon(b, I.stop); b.classList.add("rec"); }
  }

  // --- paste / type
  function openPaste() {
    const d = $("#pasteDlg");
    $("#pasteText").value = "";
    d.onclose = () => { if (d.returnValue === "ok") typeText($("#pasteText").value); (duo ? duo.canvas : canvas).focus(); };
    d.showModal();
  }
  function typeText(s) { if (s) { releaseMods(); send({ t: "text", s }); } }

  // --- touches
  const norm = (e) => {
    const r = canvas.getBoundingClientRect();
    return [Math.min(1, Math.max(0, (e.clientX - r.left) / r.width)), Math.min(1, Math.max(0, (e.clientY - r.top) / r.height))];
  };
  const isTv = () => info?.platform === "tvos";
  // Vision Pro: the mouse is the system pointer (hover, click where it points); touches reach nothing there
  const isXr = () => info?.platform === "xros" || pointerMode;
  let xrLast = 0;
  const pts = new Map(); // pointerId -> [x, y]
  let mode = null; // "wait" (a finger, maybe a second coming) | "one" | "two" (real fingers) | "pinch" | "pan" | "tv"
  let anchor = null, cur = null;
  function showDots(list) { dots.replaceChildren(...list.map(([x, y]) => { const i = h("i"); i.style.left = x * 100 + "%"; i.style.top = y * 100 + "%"; return i; })); }
  function synth(p) {
    // mouse: Alt = two fingers mirrored around where the drag began (pinch and rotate), Shift = two fingers side by side
    const [x, y] = cur;
    if (mode === "pinch") {
      const dx = x - anchor[0] + 0.06, dy = y - anchor[1];
      return [anchor[0] + dx, anchor[1] + dy, anchor[0] - dx, anchor[1] - dy];
    }
    return [x - 0.05, y, x + 0.05, y];
  }
  function two(p) {
    const [x1, y1, x2, y2] = synth(p);
    send({ t: "touch2", p, x1, y1, x2, y2 });
    showDots(p === "up" ? [] : [[x1, y1], [x2, y2]]);
  }
  let fingerWait = 0, fingerStart = null;
  function firstFinger() {
    if (mode !== "wait" || pts.size !== 1) return;
    const [p] = pts.values(), [x, y] = fingerStart;
    mode = "one"; send({ t: "touch", p: "down", x, y });
    if (p[0] !== x || p[1] !== y) send({ t: "touch", p: "move", x: p[0], y: p[1] });
  }
  function realTwo(p) {
    const [[x1, y1], [x2, y2]] = [...pts.values()];
    send({ t: "touch2", p, x1, y1, x2, y2 });
  }
  canvas.addEventListener("contextmenu", (e) => e.preventDefault());
  canvas.addEventListener("pointerdown", (e) => {
    if (!control) return;
    canvas.focus({ preventScroll: true });
    e.preventDefault();
    canvas.setPointerCapture(e.pointerId);
    const p = norm(e);
    if (isTv()) { if (!mode) { mode = "tv"; send({ t: "key", u: 0x28, d: true }); } return; }
    if (isXr()) { if (e.button === 0 && !mode) { mode = "xr"; send({ t: "pointer", a: "at", x: p[0], y: p[1] }); send({ t: "pointer", a: "down" }); } return; }
    if (e.pointerType === "touch" || e.pointerType === "pen") {
      pts.set(e.pointerId, p);
      // the first finger waits a moment for a second one: both fingers of a pinch land within a few frames, and a
      // one-finger touch down + up just before the two-finger touch was a tap that Safari took instead of the pinch
      if (pts.size === 1) { mode = "wait"; fingerStart = p; fingerWait = setTimeout(firstFinger, 60); }
      else if (pts.size === 2 && mode === "wait") { clearTimeout(fingerWait); mode = "two"; realTwo("down"); }
      else if (pts.size === 2 && mode === "one") {
        const first = [...pts.values()][0];
        send({ t: "touch", p: "up", x: first[0], y: first[1] });
        mode = "two"; realTwo("down");
      }
      return;
    }
    if (e.button !== 0) return;
    anchor = p; cur = p;
    if (e.altKey) { mode = "pinch"; two("down"); }
    else if (e.shiftKey) { mode = "pan"; two("down"); }
    else { mode = "one"; send({ t: "touch", p: "down", x: p[0], y: p[1] }); }
  });
  canvas.addEventListener("pointermove", (e) => {
    if (control && isXr()) {
      // hover moves the pointer too (at most 60 a second); dragging with the button down drags
      const now = performance.now();
      if (now - xrLast < 16) return;
      xrLast = now;
      const p = norm(e);
      send({ t: "pointer", a: "at", x: p[0], y: p[1] });
      return;
    }
    if (!control || !mode || mode === "tv") return;
    const p = norm(e);
    if (e.pointerType === "touch" || e.pointerType === "pen") {
      if (!pts.has(e.pointerId)) return;
      pts.set(e.pointerId, p);
      if (mode === "wait") return; // the down goes out with the place it has then
      if (mode === "one") send({ t: "touch", p: "move", x: p[0], y: p[1] });
      else if (mode === "two" && pts.size === 2) realTwo("move");
      return;
    }
    if (!(e.buttons & 1)) return;
    cur = p;
    if (mode === "one") send({ t: "touch", p: "move", x: p[0], y: p[1] });
    else two("move");
  });
  function up(e) {
    if (!control || !mode) return;
    if (mode === "tv") { mode = null; send({ t: "key", u: 0x28, d: false }); return; }
    if (mode === "xr") { mode = null; const p = norm(e); send({ t: "pointer", a: "at", x: p[0], y: p[1] }); send({ t: "pointer", a: "up" }); return; }
    const p = norm(e);
    if (e.pointerType === "touch" || e.pointerType === "pen") {
      if (!pts.has(e.pointerId)) return;
      pts.set(e.pointerId, p);
      if (mode === "wait") { clearTimeout(fingerWait); mode = "one"; send({ t: "touch", p: "down", x: fingerStart[0], y: fingerStart[1] }); }
      if (mode === "one") send({ t: "touch", p: "up", x: p[0], y: p[1] });
      else if (mode === "two" && pts.size === 2) realTwo("up");
      pts.delete(e.pointerId);
      if (pts.size === 0) mode = null;
      else if (mode === "one") mode = null;
      else mode = "lifted"; // the other finger's moves are ignored until it lifts
      return;
    }
    cur = p;
    if (mode === "one") send({ t: "touch", p: "up", x: p[0], y: p[1] });
    else two("up");
    mode = null;
  }
  canvas.addEventListener("pointerup", up);
  canvas.addEventListener("pointercancel", up);

  // --- wheel: a finger dragging the content (lifted after a pause), the Digital Crown, or the remote's swipes
  let wheel = null, wheelAcc = [0, 0];
  canvas.addEventListener("wheel", (e) => {
    if (!control) return;
    e.preventDefault();
    const scale = e.deltaMode === 1 ? 40 : e.deltaMode === 2 ? 400 : 1;
    const dx = e.deltaX * scale, dy = e.deltaY * scale;
    const p = info?.platform;
    if (p === "watchos") { send({ t: "crown", d: dy * 1.2 }); return; }
    // Vision Pro: the wheel scrolls where the pointer is (the crown has its buttons)
    if (p === "xros" || pointerMode) { send({ t: "pointer", a: "scroll", dx, dy }); return; }
    if (p === "tvos") {
      wheelAcc[0] += dx; wheelAcc[1] += dy;
      while (Math.abs(wheelAcc[0]) >= 40 || Math.abs(wheelAcc[1]) >= 40) {
        let u;
        if (wheelAcc[1] >= 40) { wheelAcc[1] -= 40; u = 0x51; } else if (wheelAcc[1] <= -40) { wheelAcc[1] += 40; u = 0x52; }
        else if (wheelAcc[0] >= 40) { wheelAcc[0] -= 40; u = 0x4f; } else { wheelAcc[0] += 40; u = 0x50; }
        send({ t: "key", u, d: true }); send({ t: "key", u, d: false });
      }
      return;
    }
    if (mode) return;
    const r = canvas.getBoundingClientRect();
    if (!wheel) {
      const s = norm(e);
      const start = [Math.min(0.9, Math.max(0.1, s[0])), Math.min(0.85, Math.max(0.15, s[1]))];
      wheel = { start, at: [...start], timer: 0 };
      send({ t: "touch", p: "down", x: start[0], y: start[1], edge: false });
    }
    // content follows the wheel: wheel down moves the finger up
    wheel.at[0] -= dx / r.width; wheel.at[1] -= dy / r.height;
    if (wheel.at[0] < 0.05 || wheel.at[0] > 0.95 || wheel.at[1] < 0.08 || wheel.at[1] > 0.92) {
      send({ t: "touch", p: "up", x: Math.min(1, Math.max(0, wheel.at[0])), y: Math.min(1, Math.max(0, wheel.at[1])) });
      wheel.at = [...wheel.start];
      send({ t: "touch", p: "down", x: wheel.at[0], y: wheel.at[1], edge: false });
    } else send({ t: "touch", p: "move", x: wheel.at[0], y: wheel.at[1] });
    clearTimeout(wheel.timer);
    wheel.timer = setTimeout(() => { send({ t: "touch", p: "up", x: wheel.at[0], y: wheel.at[1] }); wheel = null; }, 140);
  }, { passive: false });

  // --- keyboard: physical keys while the screen has focus; Ctrl / Cmd become the phone's Command key
  const held = new Set(); // usages down on the phone (modifiers included)
  function syncMods(e) {
    const want = new Set();
    if (e.ctrlKey || e.metaKey) want.add(0xe3);
    if (e.shiftKey) want.add(0xe1);
    if (e.altKey) want.add(0xe2);
    for (const u of [0xe3, 0xe1, 0xe2]) {
      if (want.has(u) && !held.has(u)) { held.add(u); send({ t: "key", u, d: true }); }
      if (!want.has(u) && held.has(u)) { held.delete(u); send({ t: "key", u, d: false }); }
    }
  }
  function releaseMods() { for (const u of [0xe3, 0xe1, 0xe2]) if (held.has(u)) { held.delete(u); send({ t: "key", u, d: false }); } }
  function releaseAll() { for (const u of held) send({ t: "key", u, d: false }); held.clear(); }
  const FKEYS = { F1: "home", F2: "lock", F3: "volup", F4: "voldown" };
  const FKEYS_TV = { F1: "tv", F2: "playpause", F3: "volup", F4: "voldown" };
  function onKeyDown(e) {
    if (!control) return;
    if ((e.ctrlKey || e.metaKey) && e.code === "KeyV") return; // the paste event types the clipboard
    const fk = (isTv() ? FKEYS_TV : FKEYS)[e.code];
    if (fk) { e.preventDefault(); if (!e.repeat) send({ t: "button", n: fk, d: true }); return; }
    if (MODS[e.code]) return; // modifiers go with the next key (syncMods)
    const u = hidUsage(e.code);
    if (u === undefined) return;
    e.preventDefault();
    if (e.repeat) return; // the phone repeats a held key itself
    syncMods(e);
    held.add(u);
    send({ t: "key", u, d: true });
  }
  function onKeyUp(e) {
    if (!control) return;
    const fk = (isTv() ? FKEYS_TV : FKEYS)[e.code];
    if (fk) { send({ t: "button", n: fk, d: false }); return; }
    const u = hidUsage(e.code);
    if (u !== undefined && held.has(u)) { held.delete(u); send({ t: "key", u, d: false }); }
    if (MODS[e.code]) syncMods(e);
  }
  function bindKeys(el) {
    el.addEventListener("keydown", onKeyDown);
    el.addEventListener("keyup", onKeyUp);
    el.addEventListener("blur", releaseAll);
  }
  bindKeys(canvas);
  function onPaste(e) {
    if (!control || (document.activeElement !== canvas && !(duo && document.activeElement === duo.canvas))) return;
    e.preventDefault();
    typeText(e.clipboardData.getData("text"));
  }
  document.addEventListener("paste", onPaste);

  connect();
  // a bigger window asks for a sharper stream (reconnect when the wanted width changes by a third)
  let lastW = 0;
  // against the width the socket asked for too: the first connect, before the phone's shape (or its 3D view) was known
  const sizeIv = setInterval(() => { const w = wantWidth(); if ((lastW && Math.abs(w - lastW) / lastW > 0.33) || (connW && Math.abs(w - connW) / connW > 0.33)) connect(); lastW = w; }, 2000);
  api("/api/phones").then((ps) => { const p = ps.find((x) => x.id === id || x.name === id); if (p) { info = { ...p, ...info }; lastW = wantWidth(); fit(); updateSide(); } }).catch(() => {});
  const pollIv = setInterval(poll, 3000);
  return () => {
    alive = false;
    if (axi) axi.close();
    if (pan) pan.close();
    if (netp) netp.close();
    if (pointerMode) send({ t: "pointer", a: "remove" });
    releaseAll();
    if (mic) micStop();
    if (soundOn) soundStop();
    if (rec) rec.stop();
    if (ws) { ws.onclose = null; ws.close(); }
    if (dec && dec.state !== "closed") try { dec.close(); } catch {}
    if (duo) duo.close();
    clearInterval(statIv); clearInterval(sizeIv); clearInterval(pollIv); ro.disconnect();
    $("#acts").replaceChildren();
    document.removeEventListener("paste", onPaste);
  };
}

function localStorageGet(k) { try { return localStorage.getItem(k); } catch { return null; } }
function localStorageSet(k, v) { try { localStorage.setItem(k, v); } catch {} }

// ---------- share dialog ----------
// New link first (what the sheet is opened for), then the tunnels that make a link reach other machines, then the links
// already handed out. A bottom sheet on a phone, a centred panel on a wide screen (app.css).
const fmtWhen = (t) => new Date(t * 1000).toLocaleString(undefined, { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" });
const KIND_LABEL = { local: "This machine", lan: "Local network", tailscale: "Tailscale", funnel: "Funnel", cloudflared: "Cloudflare" };
let sharePhones = [];

async function openShare(phone) {
  const d = $("#shareDlg");
  const sel = $("#linkPhone");
  try {
    sharePhones = await api("/api/phones");
    sel.replaceChildren(h("option", { value: "", text: "Every device" }), ...sharePhones.map((p) => h("option", { value: p.id, text: p.name, selected: p.id === phone })));
  } catch {}
  const out = $("#linkOut");
  out.hidden = true;
  out.replaceChildren();
  $("#linkMake").onclick = makeLink;
  if (!d.open) d.showModal();
  // the sheet shows at once; its lists fill in
  refreshTunnels();
  refreshLinks();
  let iv = setInterval(() => { if (d.open) refreshTunnels(true); }, 3000);
  d.addEventListener("close", () => clearInterval(iv), { once: true });
}
// a click on the backdrop closes it
$("#shareDlg").addEventListener("click", (e) => { if (e.target === e.currentTarget) e.currentTarget.close(); });

function lrow(title, sub, subClass, ...trail) {
  return h("div", { class: "lrow" }, h("div", { class: "txt" }, h("div", { class: "t1" }, ...[title].flat()), sub ? h("div", { class: "t2 " + (subClass || ""), text: sub }) : null), ...trail);
}

let tunnelBusy = null;
async function refreshTunnels(quiet) {
  const box = $("#tunnels");
  if (!quiet && !box.childElementCount) box.replaceChildren(h("div", { class: "lrow none", text: "Looking…" }));
  let u;
  try { u = await api("/api/urls"); } catch (e) { box.replaceChildren(h("div", { class: "lrow none", text: e.message })); return; }
  const a = u.available;
  const rows = [
    ["tailscale", "Tailscale", "your tailnet only", a.tailscale_ready, a.tailscale ? a.tailscale_detail : "Not installed"],
    ["funnel", "Funnel", "public", a.tailscale_ready, "Through Tailscale"],
    ["cloudflared", "Cloudflare", "public", a.cloudflared, a.cloudflared ? "trycloudflare.com" : "Not installed"],
  ];
  box.replaceChildren(...rows.map(([kind, label, scope, ok, detail]) => {
    const t = u.tunnels.find((x) => x.kind === kind);
    const on = !!t && (t.state === "up" || t.state === "starting");
    const busy = tunnelBusy === kind || t?.state === "starting";
    const [sub, cls] = t ? (t.state === "up" ? [t.url, "ok"] : t.state === "failed" ? ["Failed: " + (t.error || "unknown error"), "bad"] : [t.state === "starting" ? "Starting…" : t.state, ""]) : [detail, ""];
    const sw = h("button", { type: "button", class: "switch" + (busy ? " busy" : ""), role: "switch", "aria-checked": on ? "true" : "false", "aria-label": label, disabled: (!ok && !on) || busy || !!tunnelBusy });
    sw.onclick = async () => {
      tunnelBusy = kind;
      refreshTunnels(true);
      try { await api("/api/tunnel", { kind, on: !on }); } catch (e) { toast(e.message, 8000); }
      tunnelBusy = null;
      refreshTunnels(true);
    };
    const st = t?.state === "up" ? "running" : t?.state === "failed" ? "failed" : busy ? "starting" : "off";
    return lrow([h("span", { class: "dot " + st }), label, h("span", { class: "meta", text: scope })], sub, cls, sw);
  }));
}

async function makeLink() {
  const out = $("#linkOut");
  const btn = $("#linkMake");
  btn.disabled = true;
  try {
    const role = (document.querySelector('input[name="linkRole"]:checked') || {}).value || "view";
    const r = await api("/api/links", { phone: $("#linkPhone").value || null, role, ttl_s: Number($("#linkTtl").value) });
    const best = r.urls.find((x) => x.kind !== "local") || r.urls[0];
    const name = r.phone ? (sharePhones.find((p) => p.id === r.phone)?.name || r.phone) : "every device";
    out.className = "result";
    out.replaceChildren(
      h("div", { class: "qr", title: "Scan to open " + best.url }, h("img", { src: withToken("/api/qr.svg?text=" + encodeURIComponent(best.url)), alt: "QR code of the link" })),
      h("div", { class: "urls" },
        h("div", { class: "hint" }, h("b", { text: r.role === "control" ? "Watch and drive" : "Watch only", style: "color:var(--ink);font-weight:600" }), ` · ${name} · until ${fmtWhen(r.expires)}`),
        ...r.urls.map((x) => h("div", { class: "url" },
          h("div", { class: "uh" }, h("span", { class: "pill", text: KIND_LABEL[x.kind] || x.kind }),
            navigator.share ? h("button", { type: "button", class: "btn small ghost", text: "Send…", onclick: () => navigator.share({ title: "x86Sim: " + name, url: x.url }).catch(() => {}) }) : null,
            h("button", { type: "button", class: "btn small", text: "Copy", onclick: () => copy(x.url) })),
          h("code", { text: x.url }))),
        r.urls.every((x) => x.kind === "local") ? h("p", { class: "hint", text: "This machine only", title: "Turn on a tunnel under Remote access for others" }) : null));
    out.hidden = false;
    out.scrollIntoView({ block: "nearest" });
  } catch (e) {
    out.className = "result";
    out.replaceChildren(h("div", { class: "hint", text: e.message }));
    out.hidden = false;
  }
  btn.disabled = false;
  refreshLinks();
}

async function refreshLinks() {
  const box = $("#linkList");
  try {
    const l = await api("/api/links");
    box.replaceChildren(...(l.length ? l.map((x) => lrow(
      [h("span", { class: "dot " + (x.role === "control" ? "running" : "off") }), x.role === "control" ? "Watch and drive" : "Watch only"],
      `${x.phone ? (sharePhones.find((p) => p.id === x.phone)?.name || x.phone) : "Every device"} · ${x.expires ? "until " + fmtWhen(x.expires) : "until the server stops"}`, "",
      h("button", { type: "button", class: "btn small danger", text: "Revoke", onclick: async (e) => { e.target.disabled = true; await api("/api/links/revoke", { id: x.id }).catch((er) => toast(er.message)); refreshLinks(); } })))
      : [h("div", { class: "lrow none", text: "No links yet" })]));
  } catch (e) { box.replaceChildren(h("div", { class: "lrow none", text: e.message })); }
}

boot();
