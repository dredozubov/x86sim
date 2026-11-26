//! The launcher's Network section (as the browser page's netpanel.js): an app's requests recorded by host/simnet
//! (x86sim_core::net): capture on / off per app, the list with a filter, one request's details (headers, bodies,
//! timings), the mock rules. The records are files in the device's data folder, read on the UI thread at most every
//! second; relaunching an app runs on a thread. State lives in egui's temp data per phone, so the App struct is
//! untouched.
use crate::theme::*;
use eframe::egui;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use x86sim_core::{instance::Instance, net};

#[derive(Default)]
struct NetState {
    entries: Vec<net::Entry>,
    captures: Vec<net::Capture>,
    mocks: Vec<String>,
    read: Option<Instant>,
    filter: String,
    app: String,
    sel: Option<String>,
    detail: Option<serde_json::Value>,
    bundle: String,
    status: String,
    busy: bool,
}

type Shared = Arc<Mutex<NetState>>;

fn state(ctx: &egui::Context, id: &str) -> Shared {
    ctx.data_mut(|d| d.get_temp_mut_or_insert_with(egui::Id::new(("netcap", id)), || Arc::new(Mutex::new(NetState::default()))).clone())
}

fn reload(inst: &Instance, s: &mut NetState) {
    let q = net::Query { app: Some(s.app.clone()).filter(|a| !a.is_empty()), filter: s.filter.clone(), since_ts: None };
    let all = net::entries(inst);
    let skip = all.len().saturating_sub(300);
    s.entries = all.into_iter().skip(skip).filter(|e| q.matches(e)).collect();
    s.captures = net::captures(inst);
    s.mocks = net::mocks(inst).iter().map(net::mock_line).collect();
    s.read = Some(Instant::now());
}

fn capture(ctx: &egui::Context, inst: &Instance, st: &Shared, app: String, on: bool, relaunch: bool) {
    st.lock().unwrap().busy = true;
    let (inst, st, ctx) = (inst.clone(), st.clone(), ctx.clone());
    std::thread::spawn(move || {
        let r = net::set_capture(&inst, &app, on, None, relaunch);
        let mut s = st.lock().unwrap();
        s.busy = false;
        s.status = match r {
            Ok(_) if !on => format!("Capture off for {app}"),
            Ok(v) if v["hooked"] == serde_json::json!(false) => format!("Capture on for {app} · Hook not started"),
            Ok(_) => format!("Capturing {app}"),
            Err(e) => format!("{e:#}"),
        };
        s.read = None;
        ctx.request_repaint();
    });
}

/// The section's body
pub fn section(ui: &mut egui::Ui, inst: &Instance, live: bool) {
    let st = state(ui.ctx(), &inst.id);
    let ctx = ui.ctx().clone();
    {
        let mut s = st.lock().unwrap();
        if s.read.is_none_or(|t| t.elapsed() > Duration::from_secs(1)) {
            reload(inst, &mut s);
        }
    }
    ui.ctx().request_repaint_after(Duration::from_secs(1));
    let mut s = st.lock().unwrap();
    // apps with capture on
    let caps = s.captures.clone();
    for c in &caps {
        ui.horizontal(|ui| {
            ui.add(egui::Label::new(sub(&c.app)).truncate());
            if ui.add_enabled(!s.busy, Btn::ghost("Stop").small()).on_hover_text("Capture off for this app").clicked() {
                capture(&ctx, inst, &st, c.app.clone(), false, false);
            }
        });
    }
    ui.horizontal(|ui| {
        ui.add(egui::TextEdit::singleline(&mut s.bundle).hint_text("Bundle id").desired_width(180.0));
        let ok = live && !s.busy && !s.bundle.trim().is_empty();
        if ui.add_enabled(ok, Btn::secondary(if s.busy { "Working…" } else { "Capture + relaunch" }).small()).on_hover_text("Its requests from a fresh launch, HTTPS in the clear (URLSession; other stacks as connections)").on_disabled_hover_text("Running device and a bundle id").clicked() {
            let b = s.bundle.trim().to_string();
            capture(&ctx, inst, &st, b, true, true);
        }
    });
    if !s.status.is_empty() {
        ui.label(muted(s.status.clone()));
    }
    ui.add_space(S1);
    // filter and app
    let mut changed = false;
    ui.horizontal(|ui| {
        changed |= ui.add(egui::TextEdit::singleline(&mut s.filter).hint_text("Filter").desired_width(200.0)).on_hover_text("Words, status:4xx, method:POST, error").changed();
        let apps: Vec<String> = {
            let mut a: Vec<String> = s.entries.iter().map(|e| e.app.clone()).chain(caps.iter().map(|c| c.app.clone())).collect();
            a.sort();
            a.dedup();
            a
        };
        let cur = if s.app.is_empty() { "All apps".to_string() } else { s.app.clone() };
        egui::ComboBox::from_id_salt(("netapp", &inst.id)).selected_text(cur).show_ui(ui, |ui| {
            changed |= ui.selectable_value(&mut s.app, String::new(), "All apps").changed();
            for a in apps {
                changed |= ui.selectable_value(&mut s.app, a.clone(), a).changed();
            }
        });
        if ui.add(Btn::ghost("Clear").small()).on_hover_text("Empty the recorded requests").clicked() {
            let app = s.app.clone();
            if let Err(e) = net::clear_log(inst, Some(app.as_str()).filter(|a| !a.is_empty())) {
                s.status = format!("{e:#}");
            }
            s.sel = None;
            s.detail = None;
            changed = true;
        }
    });
    if changed {
        reload(inst, &mut s);
    }
    // the list
    let rows = s.entries.clone();
    egui::Frame::new().fill(pal().window).corner_radius(radius_sm()).inner_margin(egui::Margin::same(4)).show(ui, |ui| {
        egui::ScrollArea::vertical().id_salt(("netlist", &inst.id)).max_height(260.0).stick_to_bottom(true).auto_shrink([false, true]).show(ui, |ui| {
            if rows.is_empty() {
                ui.label(muted("No requests"));
            }
            for e in &rows {
                let on = s.sel.as_deref() == Some(e.id.as_str());
                let bad = !e.pending && e.kind != "conn" && e.status.is_none_or(|c| c >= 400);
                let st_txt = if e.pending { "…".into() } else { e.status.map(|c| c.to_string()).unwrap_or_else(|| if e.kind == "conn" { "conn".into() } else { "ERR".into() }) };
                let dur = e.duration_ms.map(|d| format!("{} ms", d.round() as i64)).unwrap_or_default();
                let text = egui::RichText::new(format!("{st_txt:>4} {:<5} {}{}  {dur}", e.method, e.mock.as_ref().map(|m| format!("[{m}] ")).unwrap_or_default(), e.url))
                    .font(egui::FontId::monospace(11.0))
                    .color(if bad { pal().crit_ink } else { pal().ink });
                let r = ui.add(egui::Label::new(text).truncate().sense(egui::Sense::click())).on_hover_text(e.line());
                if on {
                    ui.painter().rect_stroke(r.rect.expand(1.0), egui::CornerRadius::same(2), egui::Stroke::new(1.0_f32, pal().ink_3), egui::StrokeKind::Outside);
                }
                if r.clicked() {
                    s.sel = Some(e.id.clone());
                    s.detail = net::request(inst, &e.id).ok().map(|x| x.full());
                }
            }
        });
    });
    // one request
    if let Some(d) = s.detail.clone() {
        ui.add_space(S1);
        detail(ui, &d);
    }
    if !s.mocks.is_empty() {
        ui.add_space(S1);
        ui.horizontal(|ui| {
            ui.label(sub("Mocks"));
            if ui.add(Btn::ghost("Clear mocks").small()).clicked() {
                let _ = net::remove_mock(inst, None);
                s.read = None;
            }
        });
        for m in s.mocks.clone() {
            ui.label(muted(m));
        }
    }
    ui.add_space(S3);
}

fn detail(ui: &mut egui::Ui, d: &serde_json::Value) {
    let mono = |ui: &mut egui::Ui, t: String| {
        ui.add(egui::Label::new(egui::RichText::new(t).font(egui::FontId::monospace(11.0)).color(pal().ink_2)).wrap());
    };
    let s = |v: &serde_json::Value| v.as_str().unwrap_or("").to_string();
    let head = if d["kind"] == "conn" { format!("TCP {}:{}", s(&d["host"]), d["port"]) } else { format!("{} {}", s(&d["method"]), s(&d["url"])) };
    ui.add(egui::Label::new(strong(head)).wrap());
    let mut facts = vec![];
    if let Some(c) = d["status"].as_u64() {
        facts.push(format!("status {c}"));
    }
    if let Some(e) = d["error"].as_object() {
        facts.push(format!("{} {}: {}", e.get("domain").and_then(|x| x.as_str()).unwrap_or(""), e.get("code").map(|x| x.to_string()).unwrap_or_default(), e.get("text").and_then(|x| x.as_str()).unwrap_or("")));
    }
    for k in ["protocol", "remote", "mock", "redirect_to"] {
        if let Some(v) = d[k].as_str() {
            facts.push(format!("{k} {v}"));
        }
    }
    if !facts.is_empty() {
        ui.label(muted(facts.join(" · ")));
    }
    let t = &d["timing"];
    let timing: Vec<String> = ["dns", "connect", "tls", "send", "wait", "receive", "first_byte", "total"].iter().filter_map(|k| t[*k].as_f64().map(|v| format!("{k} {v}"))).collect();
    if !timing.is_empty() {
        ui.label(sub("Timing (ms)"));
        mono(ui, timing.join("  "));
    }
    if d["kind"] == "conn" {
        mono(ui, format!("out {} B  in {} B  {} ms", d["bytes_out"], d["bytes_in"], d["duration_ms"]));
        return;
    }
    let headers = |v: &serde_json::Value| v.as_object().map(|m| m.iter().map(|(k, v)| format!("{k}: {}", v.as_str().unwrap_or(""))).collect::<Vec<_>>().join("\n")).unwrap_or_default();
    let body = |pre: &str| -> String {
        let size = d[format!("{pre}_size")].as_u64().unwrap_or(0);
        match d[pre].as_str() {
            None if size > 0 => format!("{size} bytes (not kept)"),
            None => "–".into(),
            Some(b) if d[format!("{pre}_b64")] == true => format!("({size} bytes, base64)\n{}", &b[..b.len().min(2000)]),
            Some(b) => b.chars().take(4000).collect(),
        }
    };
    egui::CollapsingHeader::new("Request headers").id_salt("nrqh").show(ui, |ui| mono(ui, headers(&d["req_headers"])));
    egui::CollapsingHeader::new("Request body").id_salt("nrqb").show(ui, |ui| mono(ui, body("req_body")));
    egui::CollapsingHeader::new("Response headers").id_salt("nrsh").show(ui, |ui| mono(ui, headers(&d["resp_headers"])));
    egui::CollapsingHeader::new("Response body").id_salt("nrsb").default_open(true).show(ui, |ui| mono(ui, body("resp_body")));
}
