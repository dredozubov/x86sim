// x86Sim share page: the Network section (an app's requests recorded by host/simnet; server share/netapi.rs, core
// net.rs): capture on / off per app, the list (filter, app), a request's details, mock rules. A fold like panels.js's.
"use strict";
window.NETPANEL = (() => {
  const OPEN_KEY = "x86sim.folds";
  const opened = () => { try { return JSON.parse(localStorage.getItem(OPEN_KEY) || "{}"); } catch { return {}; } };
  const setOpen = (k, v) => { try { const o = opened(); o[k] = v; localStorage.setItem(OPEN_KEY, JSON.stringify(o)); } catch {} };
  const CSS = `
.netbar { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; }
.netbar input { flex: 1 1 120px; min-width: 0; }
.netlist { background: var(--well); border: 1px solid var(--line); border-radius: var(--r); height: 300px; overflow: auto; font-size: 11px; overscroll-behavior: contain; }
.nr { display: grid; grid-template-columns: 44px 34px minmax(0, 1fr) 52px; gap: 0 6px; padding: 2px 8px; cursor: pointer; white-space: nowrap; }
.nr:hover, .nr.sel { background: var(--hover); }
.nr span { overflow: hidden; text-overflow: ellipsis; }
.nr .st.bad { color: var(--red, #e06c75); } .nr .st.redir { color: var(--ink-3); } .nr .mk { color: var(--cyan, #56b6c2); }
.nr .du { text-align: right; color: var(--ink-3); }
.netdetail { background: var(--well); border: 1px solid var(--line); border-radius: var(--r); padding: 8px; font-size: 11px; max-height: 360px; overflow: auto; }
.netdetail h5 { margin: 8px 0 2px; font-size: 11px; color: var(--ink-3); font-weight: 600; }
.netdetail pre { margin: 0; white-space: pre-wrap; overflow-wrap: anywhere; font-size: 11px; }
.netcaps .srow { display: flex; align-items: center; gap: 8px; }
.netcaps .srow span { flex: 1; overflow: hidden; text-overflow: ellipsis; }
`;

  function attach(o) {
    const { id, api, h, toast } = o;
    if (!document.getElementById("netpanel-css")) document.head.append(h("style", { id: "netpanel-css", text: CSS }));
    const base = `/api/phones/${encodeURIComponent(id)}/net/`;
    let alive = true, last = 0, busy = false, sel = null, entries = [], filter = "", app = "", gen = 0;

    const sum = h("span", { class: "sum" });
    const caps = h("div", { class: "netcaps" });
    const capIn = h("input", { type: "text", placeholder: "Bundle id to capture", "aria-label": "Bundle id to capture" });
    const capBtn = h("button", { type: "button", class: "btn small", text: "Capture + relaunch", title: "Record this app's requests from a fresh launch" });
    const filterIn = h("input", { type: "search", placeholder: "Filter (words, status:4xx, method:POST, error)", "aria-label": "Filter requests" });
    const appSel = h("select", { "aria-label": "Which app" }, h("option", { value: "", text: "All apps" }));
    const clearBtn = h("button", { type: "button", class: "btn small ghost", text: "Clear", title: "Empty the recorded requests" });
    const list = h("div", { class: "netlist", role: "list" });
    const detail = h("div", { class: "netdetail", hidden: true });
    const mocks = h("div", { class: "muted" });
    const body = h("div", { class: "fbody" },
      h("div", { class: "muted", text: "Requests of apps with capture on, HTTPS in the clear (URLSession; other stacks as connections)." }),
      caps, h("div", { class: "netbar" }, capIn, capBtn),
      h("div", { class: "netbar" }, filterIn, appSel, clearBtn), list, detail, mocks);
    const d = h("details", { class: "fold" }, h("summary", {}, h("span", { class: "ft", text: "Network" }), sum), body);
    d.open = !!opened().network;
    d.addEventListener("toggle", () => { setOpen("network", d.open); if (d.open) { reset(); poll(); } });

    function reset() { last = 0; entries = []; gen++; list.replaceChildren(h("div", { class: "muted", text: "Reading…", style: "padding:6px 8px" })); }
    let ft = 0;
    filterIn.oninput = () => { clearTimeout(ft); ft = setTimeout(() => { filter = filterIn.value.trim(); reset(); poll(); }, 250); };
    appSel.onchange = () => { app = appSel.value; reset(); poll(); };
    clearBtn.onclick = async () => { try { await api(base + "clear", { app: app || undefined }); reset(); poll(); } catch (e) { toast(e.message); } };
    capBtn.onclick = () => capture(capIn.value.trim(), true, true);

    async function capture(bundle, on, relaunch) {
      if (!bundle) return toast("Give a bundle id");
      try {
        const r = await api(base + "capture", { app: bundle, on, relaunch });
        toast(on ? (r.hooked === false ? "Capture on, but the hook did not start" : `Capturing ${bundle}`) : `Capture off for ${bundle}`);
        poll();
      } catch (e) { toast(e.message); }
    }

    function row(e) {
      const st = e.pending ? "…" : e.status != null ? String(e.status) : e.kind === "conn" ? "conn" : "ERR";
      const cls = e.pending ? "" : e.status >= 400 || (e.status == null && e.kind !== "conn") ? " bad" : e.status >= 300 ? " redir" : "";
      const r = h("div", { class: "nr" + (sel === e.id ? " sel" : ""), role: "listitem", title: e.line },
        h("span", { class: "st" + cls, text: st }), h("span", { text: e.method }),
        h("span", { class: e.mock ? "mk" : "", text: (e.mock ? `[${e.mock}] ` : "") + e.url }),
        h("span", { class: "du", text: e.duration_ms != null ? Math.round(e.duration_ms) + " ms" : "" }));
      r.onclick = () => show(e.id);
      return r;
    }
    function draw() {
      const stick = list.scrollHeight - list.scrollTop - list.clientHeight < 40;
      list.replaceChildren(...(entries.length ? entries.map(row) : [h("div", { class: "muted", text: filter || app ? "Nothing matches" : "No requests yet", style: "padding:6px 8px" })]));
      if (stick) list.scrollTop = list.scrollHeight;
      sum.textContent = d.open ? "" : entries.length ? `${entries.length} requests` : "";
    }
    async function show(rid) {
      sel = rid;
      draw();
      try {
        const r = await api(base + "request?id=" + encodeURIComponent(rid));
        const kv = (obj) => h("pre", { text: Object.entries(obj || {}).map(([k, v]) => `${k}: ${v}`).join("\n") || "–" });
        const bodyOf = (b, b64, size, trunc) => h("pre", { text: b == null ? (size ? `${size} bytes (not kept)` : "–") : b64 ? `(${size} bytes, base64${trunc ? ", cut" : ""})\n` + b.slice(0, 4000) : b + (trunc ? "\n… (cut)" : "") });
        const t = r.timing || {};
        detail.replaceChildren(
          h("div", { text: `${r.method || r.proto || ""} ${r.url || r.host + ":" + r.port}`, style: "font-weight:600;overflow-wrap:anywhere" }),
          h("div", { class: "muted", text: [r.status != null ? "status " + r.status : null, r.error ? `${r.error.domain} ${r.error.code}: ${r.error.text}` : null, r.protocol, r.remote, r.mock ? "mock " + r.mock : null, r.redirect_to ? "→ " + r.redirect_to : null].filter(Boolean).join(" · ") }),
          h("h5", { text: "Timing (ms)" }), h("pre", { text: ["dns", "connect", "tls", "send", "wait", "receive", "first_byte", "total"].filter((k) => t[k] != null).map((k) => `${k} ${t[k]}`).join("  ") || (r.duration_ms != null ? `duration ${r.duration_ms}` : "–") }),
          ...(r.kind === "conn" ? [h("h5", { text: "Bytes" }), h("pre", { text: `out ${r.bytes_out}  in ${r.bytes_in}` })] : [
            h("h5", { text: "Request headers" }), kv(r.req_headers),
            h("h5", { text: "Request body" }), bodyOf(r.req_body, r.req_body_b64, r.req_body_size, r.req_body_truncated),
            h("h5", { text: "Response headers" }), kv(r.resp_headers),
            h("h5", { text: "Response body" }), bodyOf(r.resp_body, r.resp_body_b64, r.resp_body_size, r.resp_body_truncated)]));
        detail.hidden = false;
      } catch (e) { toast(e.message); }
    }
    async function poll() {
      if (!d.open || busy || !alive) return;
      busy = true;
      const g = gen;
      try {
        const r = await api(base + "log?" + new URLSearchParams({ after: String(last), filter, app }));
        if (g !== gen) return;
        // in-flight requests come back finished: replace by id
        const byId = new Map(entries.map((e) => [e.id, e]));
        for (const e of r.entries) byId.set(e.id, e);
        entries = [...byId.values()].sort((a, b) => a.ts - b.ts).slice(-500);
        const done = entries.filter((e) => !e.pending);
        // keep asking from before the oldest request still in flight
        const pend = entries.filter((e) => e.pending);
        last = pend.length ? Math.min(...pend.map((e) => e.ts)) - 1e-3 : done.length ? done[done.length - 1].ts : last;
        const cur = appSel.value;
        appSel.replaceChildren(h("option", { value: "", text: "All apps" }), ...r.apps.map((a) => h("option", { value: a, text: a, selected: a === cur })));
        caps.replaceChildren(...r.captures.map((c) => h("div", { class: "srow" }, h("span", { text: c.app }),
          h("button", { type: "button", class: "btn small", text: "Stop", title: "Capture off for this app", onclick: () => capture(c.app, false, false) }))));
        mocks.textContent = r.mocks.length ? "Mocks: " + r.mocks.join(" · ") : "";
        draw();
      } catch (e) {
        if (g === gen) list.replaceChildren(h("div", { class: "muted", text: e.message, style: "padding:6px 8px" }));
      } finally { busy = false; }
    }
    const timer = setInterval(poll, 1500);
    if (d.open) { reset(); poll(); }
    return { panel: d, close() { alive = false; clearInterval(timer); } };
  }
  return { attach };
})();
