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
    /// the picked request (its details show) and, with Shift, the other end of a picked range
    sel: Option<String>,
    sel_end: Option<String>,
    detail: Option<serde_json::Value>,
    bundle: String,
    status: String,
    busy: bool,
    /// the device's apps (from its files), read on a thread when the section opens and when the picker opens
    apps: Vec<x86sim_core::apps::AppEntry>,
    apps_read: Option<Instant>,
}

/// An app's name for a bundle id (the id when the device doesn't have it)
fn app_name(apps: &[x86sim_core::apps::AppEntry], id: &str) -> String {
    apps.iter().find(|a| a.bundle_id == id).map(|a| a.name.clone()).unwrap_or_else(|| id.to_string())
}

type Shared = Arc<Mutex<NetState>>;

fn state(ctx: &egui::Context, id: &str) -> Shared {
    ctx.data_mut(|d| d.get_temp_mut_or_insert_with(egui::Id::unique(("netcap", id)), || Arc::new(Mutex::new(NetState::default()))).clone())
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

/// Reads the device's apps on a thread (python3 over their Info.plists: off the UI thread)
fn load_apps(ctx: &egui::Context, inst: &Instance, st: &Shared, s: &mut NetState) {
    s.apps_read = Some(Instant::now());
    let (inst, st, ctx) = (inst.clone(), st.clone(), ctx.clone());
    std::thread::spawn(move || {
        let apps = x86sim_core::apps::on_disk(&inst);
        st.lock().unwrap().apps = apps;
        ctx.request_repaint();
    });
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
            Ok(v) if v["hooked"] == serde_json::json!(false) => format!("Capture on for {app}, but its hook did not start"),
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
        if s.apps_read.is_none() {
            load_apps(&ctx, inst, &st, &mut s);
        }
    }
    ui.ctx().request_repaint_after(Duration::from_secs(1));
    let mut s = st.lock().unwrap();
    // apps with capture on
    let caps = s.captures.clone();
    for c in &caps {
        ui.horizontal(|ui| {
            ui.add(egui::Label::new(sub(app_name(&s.apps, &c.app))).truncate()).on_hover_text(&c.app);
            if ui.add_enabled(!s.busy, Btn::ghost("Stop").small()).on_hover_text("Capture off for this app").clicked() {
                capture(&ctx, inst, &st, c.app.clone(), false, false);
            }
        });
    }
    ui.horizontal(|ui| {
        // the device's apps: installed ones first, then Apple's
        let cur = if s.bundle.is_empty() { "Choose an app".to_string() } else { app_name(&s.apps, &s.bundle) };
        let apps = s.apps.clone();
        let picker = egui::ComboBox::from_id_salt(("netcapapp", &inst.id)).icon(caret).width(180.0).selected_text(egui::RichText::new(cur).size(T_SMALL)).show_ui(ui, |ui| {
            let mut last_user = None;
            for a in &apps {
                if last_user == Some(true) && !a.user {
                    ui.separator();
                }
                last_user = Some(a.user);
                ui.selectable_value(&mut s.bundle, a.bundle_id.clone(), &a.name).on_hover_text(&a.bundle_id);
            }
            if apps.is_empty() {
                ui.label(muted("No apps"));
            }
        });
        // a fresh list each time the picker opens (an app installed since shows up)
        if picker.response.clicked() {
            load_apps(&ctx, inst, &st, &mut s);
        }
        let ok = live && !s.busy && !s.bundle.trim().is_empty();
        if ui.add_enabled(ok, Btn::secondary(if s.busy { "Working…" } else { "Capture + relaunch" }).small()).on_hover_text("Its requests from a fresh launch, HTTPS in the clear (URLSession; other stacks as connections)").on_disabled_hover_text("Start the device and pick an app").clicked() {
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
        ui.spacing_mut().item_spacing.x = 6.0;
        // the filter takes what the box, the two tools and Clear leave (as the Logs bar)
        let rest = (ui.available_width() - 116.0 - 2.0 * H_MD - 52.0 - 4.0 * 6.0 - 4.0).max(80.0);
        changed |= search(ui, &mut s.filter, if rest < 190.0 { "Filter" } else { "Filter: words, status:4xx, method:POST" }, rest).on_hover_text("Words, status:4xx, method:POST, error").changed();
        let apps: Vec<String> = {
            let mut a: Vec<String> = s.entries.iter().map(|e| e.app.clone()).chain(caps.iter().map(|c| c.app.clone())).collect();
            a.sort();
            a.dedup();
            a
        };
        let cur = if s.app.is_empty() { "All apps".to_string() } else { app_name(&s.apps, &s.app) };
        egui::ComboBox::from_id_salt(("netapp", &inst.id)).icon(caret).width(116.0).selected_text(egui::RichText::new(cur).size(T_SMALL)).show_ui(ui, |ui| {
            changed |= ui.selectable_value(&mut s.app, String::new(), "All apps").changed();
            for a in apps {
                let name = app_name(&s.apps, &a);
                changed |= ui.selectable_value(&mut s.app, a.clone(), name).on_hover_text(&a).changed();
            }
        });
        if ui.add(Btn::tool(icon::COPY)).on_hover_text("Copy the requests shown (click one to pick it, Shift+click for a range, Ctrl+C copies those)").clicked() {
            ui.ctx().copy_text(s.entries.iter().map(|e| e.line()).collect::<Vec<_>>().join("\n"));
        }
        if ui.add(Btn::tool(icon::DOWNLOAD_SIMPLE)).on_hover_text("Save the requests shown to a text file in Downloads").clicked() {
            let body = s.entries.iter().map(|e| e.line()).collect::<Vec<_>>().join("\n") + "\n";
            let dir = crate::extras::user_dir("DOWNLOAD", "Downloads");
            let f = dir.join(format!("x86Sim requests {} {}.txt", inst.name, crate::extras::stamp()));
            s.status = match std::fs::create_dir_all(&dir).and_then(|_| std::fs::write(&f, body)) {
                Ok(()) => format!("Saved: {}", f.display()),
                Err(e) => format!("Couldn't save: {e}"),
            };
        }
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
    // the list: rows like the Logs list; a click picks a request (its details below), Shift+click a range, Ctrl+C copies
    let rows = s.entries.clone();
    let idx = |id: &Option<String>| id.as_ref().and_then(|i| rows.iter().position(|e| &e.id == i));
    let range = match (idx(&s.sel), idx(&s.sel_end)) {
        (Some(a), Some(b)) => Some((a.min(b), a.max(b))),
        (Some(a), None) => Some((a, a)),
        _ => None,
    };
    let picked = |i: usize| range.is_some_and(|(a, b)| i >= a && i <= b);
    if range.is_some() && ui.memory(|m| m.focused().is_none()) && ui.input(|i| i.events.iter().any(|e| matches!(e, egui::Event::Copy))) {
        ui.ctx().copy_text(rows.iter().enumerate().filter(|(i, _)| picked(*i)).map(|(_, e)| e.line()).collect::<Vec<_>>().join("\n"));
    }
    let mut click: Option<(usize, bool)> = None;
    egui::Frame::new().fill(pal().well).stroke(egui::Stroke::new(1.0_f32, pal().border)).corner_radius(radius()).inner_margin(egui::Margin::symmetric(0, 4)).show(ui, |ui| {
        ui.set_width(ui.available_width());
        ui.spacing_mut().item_spacing.y = 0.0;
        let h = 18.0;
        let mono = egui::FontId::monospace(T_SMALL);
        egui::ScrollArea::vertical().id_salt(("netlist", &inst.id)).max_height(260.0).min_scrolled_height(120.0).stick_to_bottom(true).auto_shrink([false, true]).show_rows(ui, h, rows.len().max(1), |ui, rr| {
            if rows.is_empty() {
                ui.add_space(6.0);
                ui.horizontal(|ui| {
                    ui.add_space(10.0);
                    ui.label(muted(if s.captures.is_empty() { "No requests" } else { "Nothing yet" }));
                });
                return;
            }
            for i in rr.start.min(rows.len())..rr.end.min(rows.len()) {
                let e = &rows[i];
                let (r, resp) = ui.allocate_exact_size(egui::vec2(ui.available_width(), h), egui::Sense::click());
                if picked(i) {
                    ui.painter().rect_filled(r, 0.0, pal().selected);
                } else if resp.hovered() {
                    ui.painter().rect_filled(r, 0.0, pal().hover);
                }
                let bad = !e.pending && e.kind != "conn" && e.status.is_none_or(|c| c >= 400);
                let st_txt = if e.pending { "…".into() } else { e.status.map(|c| c.to_string()).unwrap_or_else(|| if e.kind == "conn" { "conn".into() } else { "ERR".into() }) };
                let dur = e.duration_ms.map(|d| format!("{} ms", d.round() as i64)).unwrap_or_default();
                let p = ui.painter();
                let y = r.center().y;
                let mut x = r.left() + 10.0;
                p.text(egui::pos2(x, y), egui::Align2::LEFT_CENTER, &st_txt, mono.clone(), if bad { pal().crit_ink } else if e.pending { pal().ink_3 } else { pal().good });
                x += 40.0;
                p.text(egui::pos2(x, y), egui::Align2::LEFT_CENTER, &e.method, mono.clone(), pal().cyan);
                x += 52.0;
                p.text(egui::pos2(r.right() - 8.0, y), egui::Align2::RIGHT_CENTER, &dur, mono.clone(), pal().ink_3);
                let url = format!("{}{}", e.mock.as_ref().map(|m| format!("[{m}] ")).unwrap_or_default(), e.url);
                let g = galley_trunc(ui, &url, mono.clone(), if bad { pal().crit_ink } else { pal().ink }, (r.right() - 70.0 - x).max(40.0));
                ui.painter().galley(egui::pos2(x, y - g.size().y / 2.0), g, pal().ink);
                if resp.clicked() {
                    click = Some((i, ui.input(|i| i.modifiers.shift)));
                }
                let resp = resp.on_hover_text(e.line());
                resp.context_menu(|ui| {
                    if ui.button("Copy URL").clicked() {
                        ui.ctx().copy_text(e.url.clone());
                        ui.close();
                    }
                    if e.kind != "conn" && ui.button("Copy as curl").clicked() {
                        if let Ok(full) = net::request(inst, &e.id) {
                            ui.ctx().copy_text(curl(&full.full()));
                        }
                        ui.close();
                    }
                    if ui.button("Copy this line").clicked() {
                        ui.ctx().copy_text(e.line());
                        ui.close();
                    }
                    if range.is_some_and(|(a, b)| b > a) && ui.button("Copy the picked lines").clicked() {
                        ui.ctx().copy_text(rows.iter().enumerate().filter(|(i, _)| picked(*i)).map(|(_, e)| e.line()).collect::<Vec<_>>().join("\n"));
                        ui.close();
                    }
                    if ui.button(format!("Copy all {} shown", rows.len())).clicked() {
                        ui.ctx().copy_text(rows.iter().map(|e| e.line()).collect::<Vec<_>>().join("\n"));
                        ui.close();
                    }
                });
            }
        });
    });
    if let Some((i, shift)) = click {
        let id = rows[i].id.clone();
        if shift && s.sel.is_some() {
            s.sel_end = Some(id);
        } else if s.sel.as_deref() == Some(id.as_str()) && s.sel_end.is_none() {
            s.sel = None;
            s.detail = None;
        } else {
            s.sel = Some(id.clone());
            s.sel_end = None;
            s.detail = net::request(inst, &id).ok().map(|x| x.full());
        }
    }
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
        ui.add(egui::Label::new(egui::RichText::new(t).font(egui::FontId::monospace(11.0)).color(pal().ink_2)).wrap().selectable(true));
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

/// A request as a curl command (method, URL, headers, a text body)
fn curl(d: &serde_json::Value) -> String {
    let q = |t: &str| format!("'{}'", t.replace('\'', "'\\''"));
    let mut c = format!("curl -X {} {}", d["method"].as_str().unwrap_or("GET"), q(d["url"].as_str().unwrap_or("")));
    if let Some(m) = d["req_headers"].as_object() {
        for (k, v) in m {
            c.push_str(&format!(" -H {}", q(&format!("{k}: {}", v.as_str().unwrap_or("")))));
        }
    }
    if let Some(b) = d["req_body"].as_str().filter(|_| d["req_body_b64"] != true) {
        c.push_str(&format!(" --data-raw {}", q(b)));
    }
    c
}
