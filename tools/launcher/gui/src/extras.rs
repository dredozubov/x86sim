//! What the browser page (core/src/share/web) had before the launcher: recording the screen to a video, a CPU profile
//! of the app in front, the Web Inspector's page list, and share links made per device (who can drive, how long, a
//! QR code, revoke). Slow work runs on threads; finished work leaves a message for the status line (`extras_poll`).
use crate::theme::*;
use crate::App;
use eframe::egui;
use serde_json::{json, Value};
use std::collections::{HashMap, HashSet};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use x86sim_core::instance::Instance;
use x86sim_core::share;

/// A recording in progress: `x86sim io <device> recordVideo` (simctl.py), stopped with SIGTERM, which finishes the file
struct Rec {
    child: std::process::Child,
    path: PathBuf,
    started: Instant,
}

#[derive(Clone)]
enum Web {
    Looking,
    /// (page id, title, app, url)
    Pages(Vec<(String, String, String, String)>),
    Failed(String),
}

/// The share section's "new link" form and what the server says about links
pub struct Links {
    control: bool,
    ttl: usize,
    /// the last link made here: device id, the server's answer (role, expires, urls)
    made: Option<(String, Value)>,
    list: Option<Vec<Value>>,
    polled: Option<Instant>,
}

impl Default for Links {
    fn default() -> Links {
        Links { control: false, ttl: 1, made: None, list: None, polled: None }
    }
}

const TTLS: [(u64, &str); 5] = [(900, "15 min"), (3600, "1 hour"), (28800, "8 hours"), (86400, "1 day"), (604800, "1 week")];

#[derive(Default)]
pub struct Extras {
    recs: HashMap<String, Rec>,
    profiling: Arc<Mutex<HashSet<String>>>,
    web: Arc<Mutex<HashMap<String, Web>>>,
    links: Arc<Mutex<Links>>,
    busy: Arc<Mutex<Option<String>>>,
    said: Arc<Mutex<Vec<String>>>,
    qr: Option<(String, usize, Vec<bool>)>,
}

/// An XDG user folder (Videos, Downloads), else ~/<fallback>
pub(crate) fn user_dir(kind: &str, fallback: &str) -> PathBuf {
    let home = std::env::var_os("HOME").map(PathBuf::from).unwrap_or_default();
    std::process::Command::new("xdg-user-dir")
        .arg(kind)
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| PathBuf::from(String::from_utf8_lossy(&o.stdout).trim()))
        .filter(|d| !d.as_os_str().is_empty() && d != &home)
        .unwrap_or_else(|| home.join(fallback))
}

pub(crate) fn stamp() -> String {
    std::process::Command::new("date").arg("+%Y-%m-%d at %H.%M.%S").output().ok().map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string()).unwrap_or_default()
}

fn open_url(u: &str) {
    let _ = std::process::Command::new("xdg-open").arg(u).stdout(std::process::Stdio::null()).stderr(std::process::Stdio::null()).spawn();
}

impl App {
    /// Saves text to Downloads (`<name> <date at time>.txt`) and says where, in the window's message line
    pub fn save_to_downloads(&self, name: &str, body: &str) {
        let dir = user_dir("DOWNLOAD", "Downloads");
        let f = dir.join(format!("{name} {}.txt", stamp()));
        let msg = match std::fs::create_dir_all(&dir).and_then(|_| std::fs::write(&f, body)) {
            Ok(()) => format!("Saved: {}", f.display()),
            Err(e) => format!("Couldn't save {}: {e}", f.display()),
        };
        self.extras.said.lock().unwrap().push(msg);
    }
    /// Each frame: messages of finished work, recordings whose recorder ended on its own
    pub fn extras_poll(&mut self) {
        let msgs: Vec<String> = std::mem::take(&mut *self.extras.said.lock().unwrap());
        for m in msgs {
            self.say(m);
        }
        let mut ended = vec![];
        for (k, r) in self.extras.recs.iter_mut() {
            if matches!(r.child.try_wait(), Ok(Some(_))) {
                ended.push(k.clone());
            }
        }
        for id in ended {
            if let Some(r) = self.extras.recs.remove(&id) {
                self.say(format!("Recording saved: {}", r.path.display()));
            }
        }
    }

    // ---------------------------------------------------------------- recording

    pub fn is_recording(&self, id: &str) -> bool {
        self.extras.recs.contains_key(id)
    }

    /// The record tool beside the screen: starts a recording into Videos, or stops it (the file is finished then)
    pub fn record_tool(&mut self, ui: &mut egui::Ui, inst: &Instance, live: bool) {
        let on = self.is_recording(&inst.id);
        let tip = match self.extras.recs.get(&inst.id) {
            Some(r) => format!("Recording ({} s): click to stop and save it to {}", r.started.elapsed().as_secs(), r.path.parent().map(|p| p.display().to_string()).unwrap_or_default()),
            None => "Record the screen to a video in Videos (click again to stop)".to_string(),
        };
        let b = if on { Btn::tinted("", pal().crit_ink) } else { Btn::ghost("") }.icon(icon::RECORD);
        if on {
            ui.ctx().request_repaint_after(Duration::from_secs(1));
        }
        if ui.add_enabled(live || on, b).on_hover_text(tip).on_disabled_hover_text("Not running").clicked() {
            if on {
                self.stop_recording(&inst.id);
            } else {
                self.start_recording(inst);
            }
        }
    }

    fn start_recording(&mut self, inst: &Instance) {
        let dir = user_dir("VIDEOS", "Videos");
        if let Err(e) = std::fs::create_dir_all(&dir) {
            self.say(format!("Couldn't record: {}: {e}", dir.display()));
            return;
        }
        let path = dir.join(format!("{} {}.mp4", inst.name.replace('/', "-"), stamp()));
        let child = std::process::Command::new(x86sim_core::aot::repo_root().join("cli/x86sim"))
            .arg("io")
            .arg(&inst.dir)
            .args(["recordVideo", "--codec", "h264"])
            .arg(&path)
            .stdin(std::process::Stdio::null())
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .spawn();
        match child {
            Ok(child) => {
                self.extras.recs.insert(inst.id.clone(), Rec { child, path, started: Instant::now() });
                self.say(format!("Recording {}", inst.name));
            }
            Err(e) => self.say(format!("Couldn't record: {e}")),
        }
    }

    /// SIGTERM ends the recorder as Ctrl-C does: it closes ffmpeg's input and waits for the file (a kill would leave an
    /// unplayable mp4). Waited for on a thread; extras_poll says when it's saved.
    pub fn stop_recording(&mut self, id: &str) {
        let Some(mut r) = self.extras.recs.remove(id) else { return };
        unsafe {
            libc::kill(r.child.id() as i32, libc::SIGTERM);
        }
        let said = self.extras.said.clone();
        std::thread::spawn(move || {
            let _ = r.child.wait();
            said.lock().unwrap().push(format!("Recording saved: {}", r.path.display()));
        });
        self.say("Saving the recording…");
    }

    // ---------------------------------------------------------------- CPU profile

    /// Performance: a 5 s CPU profile of the app in front, saved as speedscope JSON in Downloads
    pub fn profile_button(&mut self, ui: &mut egui::Ui, inst: &Instance) {
        let running = self.extras.profiling.lock().unwrap().contains(&inst.id);
        let r = ui.add_enabled(!running, Btn::secondary(if running { "Profiling…" } else { "Profile 5 s" }).icon(icon::CPU).small())
            .on_hover_text("A CPU profile of the app in front for 5 seconds, saved to Downloads as speedscope JSON (open it at speedscope.app)");
        if running {
            ui.ctx().request_repaint_after(Duration::from_millis(500));
        }
        if r.clicked() {
            self.extras.profiling.lock().unwrap().insert(inst.id.clone());
            let (inst, prof, said, ctx) = (inst.clone(), self.extras.profiling.clone(), self.extras.said.clone(), ui.ctx().clone());
            std::thread::spawn(move || {
                let msg = match x86sim_core::profile::take(&inst, None, 5.0, x86sim_core::profile::Format::Speedscope) {
                    Ok((name, body)) => {
                        let dir = user_dir("DOWNLOAD", "Downloads");
                        let f = dir.join(&name);
                        match std::fs::create_dir_all(&dir).and_then(|_| std::fs::write(&f, body)) {
                            Ok(()) => format!("Profile saved: {}", f.display()),
                            Err(e) => format!("Couldn't save the profile: {e}"),
                        }
                    }
                    Err(e) => format!("Couldn't profile: {e:#}"),
                };
                prof.lock().unwrap().remove(&inst.id);
                said.lock().unwrap().push(msg);
                ctx.request_repaint();
            });
        }
    }

    // ---------------------------------------------------------------- Web Inspector

    /// The device's inspectable pages (Safari's tabs, web views with isInspectable), each opening WebKit's Web
    /// Inspector in the browser (x86sim serve, started if needed). Asked for on a click: the first ask starts the
    /// device's webinspectord.
    pub fn web_section(&mut self, ui: &mut egui::Ui, inst: &Instance, live: bool) {
        let st = self.extras.web.lock().unwrap().get(&inst.id).cloned();
        ui.label(muted("Safari's pages and apps' web views (isInspectable), in WebKit's Web Inspector in your browser."));
        ui.add_space(S1);
        let looking = matches!(st, Some(Web::Looking));
        ui.horizontal(|ui| {
            if ui.add_enabled(live && !looking, Btn::secondary(if looking { "Looking…" } else { "Find web pages" }).icon(icon::CODE).small()).on_disabled_hover_text("Not running").clicked() {
                self.extras.web.lock().unwrap().insert(inst.id.clone(), Web::Looking);
                let (inst, web, ctx) = (inst.clone(), self.extras.web.clone(), ui.ctx().clone());
                std::thread::spawn(move || {
                    let r = match x86sim_core::rwi::targets(&inst, Duration::from_secs(3)) {
                        Ok(apps) => Web::Pages(apps.iter().flat_map(|a| a.pages.iter().map(move |p| (p.id.clone(), p.title.clone(), if a.name.is_empty() { a.bundle.clone() } else { a.name.clone() }, p.url.clone()))).collect()),
                        Err(e) => Web::Failed(format!("{e:#}")),
                    };
                    web.lock().unwrap().insert(inst.id.clone(), r);
                    ctx.request_repaint();
                });
            }
            if ui.add_enabled(live, Btn::ghost("All pages").icon(icon::BROWSER).small()).on_hover_text("The inspector's own page list in your browser").clicked() {
                self.open_inspector(inst, None);
            }
        });
        match st {
            Some(Web::Pages(p)) if p.is_empty() => {
                ui.label(muted("No inspectable pages: open one in Safari, or an app whose WKWebView sets isInspectable."));
            }
            Some(Web::Pages(pages)) => {
                ui.add_space(S1);
                for (pid, title, app, url) in pages {
                    ui.horizontal(|ui| {
                        if ui.add(Btn::secondary("Inspect").small()).on_hover_text(&url).clicked() {
                            self.open_inspector(inst, Some(&pid));
                        }
                        ui.add(egui::Label::new(sub(format!("{} · {app}", if title.is_empty() { "(untitled)" } else { &title }))).truncate()).on_hover_text(&url);
                    });
                }
            }
            Some(Web::Failed(e)) => {
                ui.label(muted(format!("Web Inspector: {e}")));
            }
            _ => {}
        }
        ui.add_space(S3);
    }

    fn open_inspector(&mut self, inst: &Instance, page: Option<&str>) {
        let (inst, page, said) = (inst.clone(), page.map(String::from), self.extras.said.clone());
        std::thread::spawn(move || match share::inspect::inspector_url(&inst, page.as_deref()) {
            Ok(u) => open_url(&u),
            Err(e) => said.lock().unwrap().push(format!("Web Inspector: {e:#}")),
        });
    }

    // ---------------------------------------------------------------- share links

    /// Share: links for this device, as the browser's Share dialog makes them: watch only or watch and drive, an
    /// expiry, a QR code to open it on a phone, and the links made so far, each revocable
    pub fn links_section(&mut self, ui: &mut egui::Ui, inst: &Instance) {
        let ctx = ui.ctx().clone();
        // the list, every 3 s while shown (only while the server runs)
        {
            let mut l = self.extras.links.lock().unwrap();
            if l.polled.is_none_or(|t| t.elapsed() > Duration::from_secs(3)) {
                l.polled = Some(Instant::now());
                let (links, ctx) = (self.extras.links.clone(), ctx.clone());
                std::thread::spawn(move || {
                    let v = share::status().and_then(|st| share::api(&st, "GET", "/api/links", None).ok()).and_then(|v| v.as_array().cloned());
                    links.lock().unwrap().list = v;
                    ctx.request_repaint();
                });
            }
        }
        let busy = self.extras.busy.lock().unwrap().clone();
        ui.add_space(S2);
        ui.label(overline("new link"));
        ui.add_space(2.0);
        let (mut control, mut ttl) = {
            let l = self.extras.links.lock().unwrap();
            (l.control, l.ttl)
        };
        ui.horizontal_wrapped(|ui| {
            if let Some(i) = segmented(ui, &["Watch only", "Watch and drive"], Some(control as usize), true) {
                control = i == 1;
            }
            egui::ComboBox::from_id_salt(("link-ttl", &inst.id))
                .icon(caret)
                .width(96.0)
                .selected_text(egui::RichText::new(TTLS[ttl].1).size(T_SMALL))
                .show_ui(ui, |ui| {
                    for (i, (_, l)) in TTLS.iter().enumerate() {
                        ui.selectable_value(&mut ttl, i, *l);
                    }
                })
                .response
                .on_hover_text("When the link stops working");
        });
        {
            let mut l = self.extras.links.lock().unwrap();
            l.control = control;
            l.ttl = ttl;
        }
        ui.add_space(S1);
        if ui.add_enabled(busy.is_none(), Btn::primary("Make link").icon(icon::LINK).small()).clicked() {
            *self.extras.busy.lock().unwrap() = Some("Making a link…".into());
            let (id, links, busy_m, said, ctx) = (inst.id.clone(), self.extras.links.clone(), self.extras.busy.clone(), self.extras.said.clone(), ctx.clone());
            let ttl_s = TTLS[ttl].0;
            std::thread::spawn(move || {
                let r = share::status().map(Ok).unwrap_or_else(|| share::start(&share::Options::default())).and_then(|st| {
                    share::api(&st, "POST", "/api/links", Some(json!({"phone": id, "role": if control { "control" } else { "view" }, "ttl_s": ttl_s})))
                });
                match r {
                    Ok(v) => {
                        let mut l = links.lock().unwrap();
                        l.made = Some((id, v));
                        l.polled = None;
                    }
                    Err(e) => said.lock().unwrap().push(format!("Couldn't make a link: {e:#}")),
                }
                *busy_m.lock().unwrap() = None;
                ctx.request_repaint();
            });
        }
        // the link just made: a QR code of the best address, each address with Copy
        let made = self.extras.links.lock().unwrap().made.clone().filter(|(id, _)| *id == inst.id).map(|(_, v)| v);
        if let Some(v) = made {
            let urls: Vec<(String, String)> = v["urls"].as_array().into_iter().flatten().map(|u| (u["kind"].as_str().unwrap_or("").to_string(), u["url"].as_str().unwrap_or("").to_string())).collect();
            ui.add_space(S2);
            card_frame().inner_margin(S3 as i8).show(ui, |ui| {
                ui.set_width(ui.available_width());
                let best = urls.iter().find(|(k, _)| k != "local").or(urls.first()).map(|(_, u)| u.clone()).unwrap_or_default();
                ui.horizontal_top(|ui| {
                    self.draw_qr(ui, &best, 132.0);
                    ui.vertical(|ui| {
                        let role = if v["role"].as_str() == Some("control") { "Watch and drive" } else { "Watch only" };
                        let until = v["expires"].as_u64().map(|e| format!(" · {} min left", e.saturating_sub(share::now_s()) / 60)).unwrap_or_default();
                        ui.label(strong(format!("{role}{until}")));
                        for (kind, u) in &urls {
                            ui.horizontal(|ui| {
                                if ui.add(Btn::secondary("Copy").icon(icon::COPY).small()).on_hover_text(u).clicked() {
                                    ui.ctx().copy_text(u.clone());
                                    self.say(format!("Copied the {} link", kind));
                                }
                                ui.add(egui::Label::new(muted(kind.as_str())).truncate()).on_hover_text(u);
                            });
                        }
                        if urls.iter().all(|(k, _)| k == "local") {
                            ui.label(muted("Only this machine can open it: turn on a tunnel above for others."));
                        }
                    });
                });
            });
        }
        // the links made so far (this device's and every device's)
        let list = self.extras.links.lock().unwrap().list.clone();
        if let Some(list) = list {
            let mine: Vec<&Value> = list.iter().filter(|x| x["phone"].as_str().is_none_or(|p| p == inst.id)).collect();
            ui.add_space(S2);
            ui.label(overline("links made"));
            ui.add_space(2.0);
            if mine.is_empty() {
                ui.label(muted("None yet"));
            }
            for x in mine {
                ui.horizontal(|ui| {
                    let role = if x["role"].as_str() == Some("control") { "drive" } else { "watch" };
                    let whom = if x["phone"].is_null() { "every device" } else { "this device" };
                    let until = x["expires"].as_u64().map(|e| format!("{} min left", e.saturating_sub(share::now_s()) / 60)).unwrap_or_else(|| "until the server stops".into());
                    let rid = x["id"].as_str().unwrap_or("").to_string();
                    if ui.add_enabled(busy.is_none(), Btn::danger("Revoke").small()).clicked() {
                        let (links, said, ctx) = (self.extras.links.clone(), self.extras.said.clone(), ctx.clone());
                        std::thread::spawn(move || {
                            if let Some(st) = share::status() {
                                if let Err(e) = share::api(&st, "POST", "/api/links/revoke", Some(json!({"id": rid}))) {
                                    said.lock().unwrap().push(format!("Couldn't revoke it: {e:#}"));
                                }
                            }
                            links.lock().unwrap().polled = None;
                            ctx.request_repaint();
                        });
                    }
                    ui.label(sub(format!("{role} · {whom} · {until}")));
                });
            }
        }
    }

    /// A QR code drawn with the painter (dark on white, a 2-module quiet zone)
    fn draw_qr(&mut self, ui: &mut egui::Ui, text: &str, size: f32) {
        if self.extras.qr.as_ref().is_none_or(|q| q.0 != text) {
            self.extras.qr = share::qr_matrix(text).map(|(w, m)| (text.to_string(), w, m));
        }
        let (rect, _) = ui.allocate_exact_size(egui::vec2(size, size), egui::Sense::hover());
        let p = ui.painter();
        p.rect_filled(rect, radius_sm(), egui::Color32::WHITE);
        if let Some((_, w, m)) = &self.extras.qr {
            let n = *w as f32 + 4.0;
            let px = size / n;
            for (i, dark) in m.iter().enumerate() {
                if *dark {
                    let (x, y) = ((i % w) as f32 + 2.0, (i / w) as f32 + 2.0);
                    p.rect_filled(egui::Rect::from_min_size(rect.min + egui::vec2(x * px, y * px), egui::vec2(px + 0.3, px + 0.3)), 0.0, egui::Color32::BLACK);
                }
            }
        }
    }
}
