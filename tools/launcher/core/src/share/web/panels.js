// x86Sim share page: the device page's panels the launcher has (gui/src/phone.rs, devctl_ui.rs): the overview tiles,
// Features, Logs, Performance and Simulate, as folds that remember whether they are open. Server: share/device.rs.
"use strict";
window.PANELS = (() => {
  const OPEN_KEY = "x86sim.folds";
  const opened = () => { try { return JSON.parse(localStorage.getItem(OPEN_KEY) || "{}"); } catch { return {}; } };
  const setOpen = (k, v) => { try { const o = opened(); o[k] = v; localStorage.setItem(OPEN_KEY, JSON.stringify(o)); } catch {} };
  const GROUPS = ["System", "Translator", "Boot", "Graphics", "Memory"];
  const SIZES = [["extra-small", "XS"], ["small", "S"], ["medium", "M"], ["large", "L"], ["extra-large", "XL"], ["extra-extra-large", "XXL"], ["extra-extra-extra-large", "XXXL"]];

  function attach(o) {
    const { id, control, api, h, toast, fmtMem, fmtUp } = o;
    const base = `/api/phones/${encodeURIComponent(id)}/`;
    let alive = true, detail = null;
    const timers = [];

    // ---- pieces (theme.rs's fold, segmented, toggle, kv)
    function fold(key, title, body, onToggle) {
      const sum = h("span", { class: "sum" });
      const d = h("details", { class: "fold" }, h("summary", {}, h("span", { class: "ft", text: title }), sum), h("div", { class: "fbody" }, body));
      d.open = !!opened()[key];
      d.addEventListener("toggle", () => { setOpen(key, d.open); if (onToggle) onToggle(d.open); });
      d.sum = sum;
      return d;
    }
    function seg(items, cur, enabled, pick) {
      return h("div", { class: "seg", role: "group" }, ...items.map(([v, label]) =>
        h("button", { type: "button", class: "btn small" + (v === cur ? " on" : ""), "aria-pressed": v === cur ? "true" : "false", disabled: !enabled, text: label, onclick: () => pick(v) })));
    }
    function sw(on, enabled, label, change) {
      return h("button", { type: "button", class: "switch", role: "switch", "aria-checked": on ? "true" : "false", "aria-label": label, disabled: !enabled, onclick: () => change(!on) });
    }
    const kv = (k, v) => h("div", { class: "kv" }, h("span", { text: k }), h("span", { text: v }));
    const field = (label, tip, ...ctl) => h("div", { class: "sfield" }, h("div", { class: "sl", text: label, title: tip || "" }), ...ctl);
    const swrow = (label, tip, s) => h("div", { class: "srow" }, h("span", { class: "sl", text: label, title: tip || "" }), s);

    // ---- overview: memory, CPU, uptime; the GPU helper apart; screen and processes
    const tiles = h("div", { class: "tiles" });
    const gpuLine = h("div", { class: "muted gpu" });
    const facts = h("div", { class: "kvs" });
    const overview = h("div", { class: "overview" }, tiles, gpuLine, facts);
    function drawOverview() {
      const d = detail || {};
      const on = d.phase && d.phase !== "Off";
      const tile = (l, v) => h("div", { class: "tile" }, h("div", { class: "l", text: l }), h("div", { class: "v", text: v }));
      tiles.replaceChildren(tile("Memory", on && d.memory_mb ? fmtMem(d.memory_mb) : "–"), tile("CPU", on && d.cpu_pct != null ? Math.round(d.cpu_pct) + "%" : "–"), tile("Up for", on ? fmtUp(d.uptime_s) : "–"));
      const g = on && d.gpu;
      gpuLine.hidden = !g;
      if (g) {
        gpuLine.textContent = `+ ${fmtMem(g.memory_mb)} for the GPU helper` + (g.users > 1 ? `, shared by ${g.users} devices` : "");
        gpuLine.title = "mtlvk runs every Metal call on Vulkan. It is not in this device's memory.";
      }
      facts.replaceChildren(...[d.screen ? kv("Screen", `${d.screen[0]} × ${d.screen[1]} pixels`) : null, on && d.processes != null ? kv("Processes", String(d.processes)) : null].filter(Boolean));
    }

    // ---- Performance: the screen's rate, who uses what
    const perfBody = h("div", { class: "perf" });
    const perf = fold("perf", "Performance", perfBody, (open) => open && drawPerf());
    function drawPerf() {
      if (!perf.open) return;
      const d = detail || {};
      if (!d.phase || d.phase === "Off") { perfBody.replaceChildren(h("div", { class: "muted", text: "Start the device to see what it uses." })); return; }
      const f = o.fps();
      const max = Math.max(1, ...(d.procs || []).map((p) => p.memory_mb));
      const rows = (d.procs || []).map((p) => h("div", { class: "pr", title: `${p.name} · pid ${p.pid}` },
        h("span", { class: "pn", text: p.name }),
        h("span", { class: "pb" }, h("i", { style: `width:${Math.max(3, (p.memory_mb / max) * 100)}%` })),
        h("span", { class: "pm", text: Math.round(p.memory_mb) + " MB" }),
        h("span", { class: "pc" + (p.cpu_pct > 50 ? " hot" : ""), text: Math.round(p.cpu_pct) + "%" })));
      const more = d.processes > rows.length ? h("div", { class: "muted pmore", text: `and ${d.processes - rows.length} smaller ones` }) : null;
      const g = d.gpu ? h("div", { class: "pr gpu", title: `Runs every Metal call on Vulkan for the devices that share it (pid ${d.gpu.pid}). Not part of this device's memory.` },
        h("span", { class: "pn", text: "GPU helper (mtlvk)" + (d.gpu.users > 1 ? ` · shared by ${d.gpu.users}` : "") }), h("span"),
        h("span", { class: "pm", text: Math.round(d.gpu.memory_mb) + " MB" }), h("span", { class: "pc", text: Math.round(d.gpu.cpu_pct) + "%" })) : null;
      perfBody.replaceChildren(kv("Screen updates", f > 0 ? f + " fps" : "Idle"),
        h("div", { class: "ptable" }, h("div", { class: "pr ph" }, h("span", { text: "process" }), h("span"), h("span", { class: "pm", text: "memory" }), h("span", { class: "pc", text: "cpu" })), ...rows, more, g));
    }

    async function pollDetail() {
      try {
        detail = await api(base + "detail");
        if (!alive) return;
        drawOverview();
        drawPerf();
        if (o.onDetail) o.onDetail(detail);
      } catch {}
    }

    // ---- Features (iPhone, iPad): the set, each switch, what it saves; restart to apply
    let features = null;
    const featBody = h("div", { class: "feats" });
    const feat = control && o.platform === "ios" ? fold("features", "Features", featBody, (open) => { if (open) loadFeatures(); drawFeatSummary(); }) : null;
    async function loadFeatures() {
      if (!features) featBody.replaceChildren(h("div", { class: "muted", text: "Reading…" }));
      try { features = await api(base + "features"); drawFeatures(); } catch (e) { featBody.replaceChildren(h("div", { class: "muted", text: e.message })); }
    }
    async function setFeature(b) {
      try { features = await api(base + "features", b); drawFeatures(); pollDetail(); } catch (e) { toast(e.message); }
    }
    function drawFeatSummary() {
      if (!feat || !features) return;
      const off = features.features.filter((f) => !f.enabled);
      const p = { full: "Full set", lean: "Lean set", minimal: "Minimal set" }[features.preset] || (off.length ? "Custom" : "Everything on");
      feat.sum.textContent = feat.open ? "" : off.length ? `${p} · ${off.length} off` : p;
      feat.sum.title = off.length ? "Off: " + off.map((f) => f.title).join(", ") : "";
    }
    function drawFeatures() {
      const f = features;
      const saving = f.features.filter((x) => !x.enabled && x.default).reduce((a, x) => a + x.cost_mb, 0);
      featBody.replaceChildren(...[
        h("div", { class: "muted", text: "Turn off what you don't use to save memory." }),
        seg([["full", "Full"], ["lean", "Lean"], ["minimal", "Minimal"]], f.preset, true, (v) => setFeature({ preset: v })),
        h("div", { class: "frows" }, ...f.features.map((x) => {
          // "What it is. Off: what you lose." -> what it is while on, what you lose while off
          const i = x.desc.indexOf("Off:");
          const what = i >= 0 ? x.desc.slice(0, i).trim() : x.desc, lose = i >= 0 ? x.desc.slice(i + 4).trim() : "";
          const text = !x.enabled && lose ? "Off: " + lose : what || (lose ? "When off: " + lose : "");
          return h("div", { class: "frow", title: x.tech || "" },
            h("div", { class: "txt" }, h("div", { class: "t1", text: x.title }), h("div", { class: "t2", text: text })),
            x.cost_mb > 0 ? h("span", { class: "muted", text: x.cost_mb + " MB" }) : null,
            sw(x.enabled, true, x.title, (on) => setFeature({ id: x.id, on })));
        })),
        saving > 0 ? h("div", { class: "state muted" }, h("span", { class: "dot running" }), `Saving about ${saving} MB`) : null,
        f.needs_restart && f.running ? restartBanner() : null].filter(Boolean));
      drawFeatSummary();
    }
    function restartBanner() {
      return h("div", { class: "banner" }, h("span", { class: "warnmark", text: "!" }), h("span", { class: "grow", text: "Restart to apply" }),
        h("button", { type: "button", class: "btn small", text: "Restart now", onclick: (e) => o.restart(e) }));
    }

    // ---- Logs: a live tail, filtered by text or process and by group
    let logLast = 0, logPaused = false, logGroup = "", logQ = "", logBusy = false, logGen = 0;
    const logBox = h("div", { class: "logbox", role: "log" });
    const logFilter = h("input", { type: "search", placeholder: "Filter text or process", "aria-label": "Filter logs" });
    const logSel = h("select", { "aria-label": "Which logs" }, h("option", { value: "", text: "All logs" }), ...GROUPS.map((g) => h("option", { value: g, text: g })));
    const pauseBtn = h("button", { type: "button", class: "btn small", text: "Pause", title: "Stop following new lines" });
    const clearBtn = h("button", { type: "button", class: "btn small ghost", text: "Clear", title: "Clear the lines shown here (the log files stay)" });
    const logs = control ? fold("logs", "Logs", [h("div", { class: "logbar" }, logFilter, logSel, pauseBtn, clearBtn), logBox], (open) => { if (open) { resetLogs(); pollLogs(); } else logBox.replaceChildren(); logs.sum.textContent = ""; }) : null;
    function resetLogs() { logLast = 0; logGen++; logBox.replaceChildren(h("div", { class: "muted lempty", text: "Reading…" })); }
    let filterT = 0;
    logFilter.oninput = () => { clearTimeout(filterT); filterT = setTimeout(() => { logQ = logFilter.value.trim(); resetLogs(); pollLogs(); }, 250); };
    logSel.onchange = () => { logGroup = logSel.value; resetLogs(); pollLogs(); };
    pauseBtn.onclick = () => { logPaused = !logPaused; pauseBtn.textContent = logPaused ? "Follow" : "Pause"; pauseBtn.classList.toggle("on", logPaused); if (!logPaused) pollLogs(); };
    clearBtn.onclick = () => logBox.replaceChildren(h("div", { class: "muted lempty", text: "Nothing new yet" }));
    async function pollLogs() {
      if (!logs || !logs.open || logPaused || logBusy || !alive) return;
      logBusy = true;
      const gen = logGen;
      try {
        const q = new URLSearchParams({ after: String(logLast), group: logGroup, q: logQ });
        const r = await api(base + "logs?" + q);
        if (gen !== logGen) return;
        // a restart numbers its lines from 1 again
        if (r.last < logLast) { resetLogs(); logBusy = false; return pollLogs(); }
        logLast = r.last;
        for (const opt of logSel.options) if (opt.value) opt.disabled = !r.groups.includes(opt.value) && opt.value !== logGroup;
        if (r.lines.length) {
          const stick = logBox.scrollHeight - logBox.scrollTop - logBox.clientHeight < 40;
          const empty = logBox.querySelector(".lempty");
          if (empty) empty.remove();
          logBox.append(...r.lines.map((l) => {
            const low = l.text.toLowerCase();
            const cls = /error|fail|crash/.test(low) ? " err" : low.includes("warn") ? " warn" : "";
            return h("div", { class: "ll", title: `${l.source} · ${l.group}` }, h("span", { class: "lt", text: l.time || "" }), h("span", { class: "ls", text: l.source }), h("span", { class: "lm" + cls, text: l.text }));
          }));
          while (logBox.childElementCount > 2000) logBox.firstElementChild.remove();
          if (stick) logBox.scrollTop = logBox.scrollHeight;
        } else if (logBox.querySelector(".lempty")) {
          logBox.querySelector(".lempty").textContent = logQ || logGroup ? "Nothing matches" : "Nothing yet";
        }
        logs.sum.textContent = `${logBox.querySelectorAll(".ll").length} lines`;
      } catch (e) {
        if (gen === logGen) logBox.replaceChildren(h("div", { class: "muted lempty", text: e.message }));
      } finally { logBusy = false; }
    }

    // ---- Simulate: appearance, text size, contrast, fidelity, the keyboard
    let sim = null, simBusy = false;
    const simBody = h("div", { class: "sim" });
    const simulate = control ? fold("simulate", "Simulate", simBody, (open) => open && loadSim()) : null;
    async function loadSim() {
      if (!sim) simBody.replaceChildren(h("div", { class: "muted", text: "Reading…" }));
      try { sim = await api(base + "simulate"); drawSim(); } catch (e) { simBody.replaceChildren(h("div", { class: "muted", text: e.message })); }
    }
    async function setSim(b, said) {
      simBusy = true; drawSim();
      try { sim = await api(base + "simulate", b); toast(said); } catch (e) { toast("Couldn't do it: " + e.message); }
      simBusy = false; drawSim();
    }
    function drawSim() {
      const s = sim;
      const running = s.phase === "Running", off = s.phase === "Off";
      const idle = !simBusy && (running || off);
      const sizeSel = SIZES.some(([v]) => v === s.content_size);
      simBody.replaceChildren(
        h("div", { class: "muted", text: simBusy ? "Working…" : running ? "Changes apply at once." : off ? "The device is off: changes apply at its next start." : "Wait until it has started or stopped." }),
        field("Appearance", "Light or Dark (Features > Toggle Appearance)", seg([["light", "Light"], ["dark", "Dark"]], s.appearance, idle, (v) => setSim({ appearance: v }, `${v === "dark" ? "Dark" : "Light"} appearance`))),
        field("Text size", "Dynamic Type (Settings > Display & Brightness > Text Size)", h("div", { class: "segscroll" }, seg(SIZES, s.content_size, idle, (v) => setSim({ content_size: v }, "Text size " + SIZES.find((x) => x[0] === v)[1]))),
          !sizeSel && s.content_size.startsWith("accessibility") ? h("div", { class: "muted", text: "Now " + s.content_size }) : null),
        swrow("Increase Contrast", "Settings > Accessibility > Display & Text Size", sw(s.increase_contrast, idle, "Increase Contrast", (on) => setSim({ increase_contrast: on }, "Increase Contrast " + (on ? "on" : "off")))),
        field("Fidelity", "Fast: a 3x iPhone drawn at 2x with Reduce Transparency and Reduce Motion on: smoother. High: the model's own scale and every effect. The scale changes at the next start.",
          seg([["fast", "Fast"], ["high", "High"]], s.fidelity, idle, (v) => setSim({ fidelity: v }, `Fidelity ${v} (the scale at the next start)`))),
        swrow("Connect Hardware Keyboard", "I/O > Keyboard > Connect Hardware Keyboard. Off: the software keyboard comes up on every text field.", sw(s.hw_keyboard, idle, "Connect Hardware Keyboard", (on) => setSim({ hw_keyboard: on }, "Hardware keyboard " + (on ? "connected" : "disconnected")))),
        h("div", { class: "btns" }, h("button", { type: "button", class: "btn small", text: "Toggle Software Keyboard", disabled: !running, title: "I/O > Keyboard > Toggle Software Keyboard (Cmd-K): while a text field is focused", onclick: () => o.send({ t: "sys", a: "soft_keyboard" }) })));
    }

    pollDetail();
    timers.push(setInterval(pollDetail, 3000), setInterval(pollLogs, 1000));
    // a fold open from last time fires its own toggle, which loads it; a folded Features still shows its summary
    if (feat && !feat.open) api(base + "features").then((f) => { features = f; drawFeatSummary(); }).catch(() => {});
    drawOverview();
    return {
      overview, features: feat, logs, perf, simulate,
      refresh: pollDetail,
      close() { alive = false; timers.forEach(clearInterval); },
    };
  }
  return { attach };
})();
