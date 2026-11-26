//! The Develop page: build apps on Linux with omarchy-apple-dev (external/omarchy-apple-dev) and run them on a device.
//! The toolchain's pieces (Swift, xtool, the iOS SDK, device tools) with install / update / repair buttons and the
//! background setup job's progress.
//! The logic is x86sim_core::dev (shared with `x86sim dev` and the MCP server's dev_* tools).
use crate::global::list_row;
use crate::theme::*;
use crate::App;
use eframe::egui;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use x86sim_core::dev;

#[derive(Default)]
pub struct Develop {
    pub status: Arc<Mutex<Option<dev::Status>>>,
    checking: Arc<Mutex<bool>>,
    last_poll: Option<Instant>,
    pub xip: String,
    pub show_job_log: bool,
    /// Download Xcode: keep the .xip afterwards
    pub keep_xip: bool,
    loaded: bool,
}

impl Develop {
    pub fn refresh(&self, ctx: &egui::Context) {
        let mut c = self.checking.lock().unwrap();
        if *c {
            return;
        }
        *c = true;
        let (st, chk, ctx) = (self.status.clone(), self.checking.clone(), ctx.clone());
        std::thread::spawn(move || {
            let s = dev::status();
            *st.lock().unwrap() = Some(s);
            *chk.lock().unwrap() = false;
            ctx.request_repaint();
        });
    }
}

fn piece_icon(id: &str) -> &'static str {
    match id {
        "fork" => icon::PACKAGE,
        "packages" => icon::TERMINAL_WINDOW,
        "swift" => icon::CODE,
        "xtool" => icon::HAMMER,
        "sdk" => icon::APPLE_LOGO,
        "cocoapods" => icon::PACKAGE,
        "swiftbuild" => icon::HAMMER,
        _ => icon::DEVICE_MOBILE,
    }
}

/// A toolchain piece's status line, terse: the detail up to its first explanation, a size kept as a fact ("not
/// installed (… about 70 MB, no root)" -> "Not installed · 70 MB"). The whole detail is the row's tooltip.
fn terse(d: &str) -> String {
    let d = d.trim();
    let mut head = match d.find("missing ") {
        Some(i) if d[..i].contains(": ") => d[i..].to_string(),
        _ => {
            let cut = [" (", "; ", ": "].iter().filter_map(|sep| d.find(sep)).min().unwrap_or(d.len());
            d[..cut].trim().to_string()
        }
    };
    if let Some(i) = d.find("about ") {
        let size = d[i + 6..].split([',', ')', ';']).next().unwrap_or("").trim();
        if (size.ends_with(" MB") || size.ends_with(" GB")) && !head.contains(size) {
            head = format!("{head} · {size}");
        }
    }
    // a status word starts with a capital; a tool's name ("pymobiledevice3 …", "cargo …") stays as it is spelt
    let word = head.split(' ').next().unwrap_or("");
    if !["not", "missing", "installed", "built", "only", "no", "commit"].contains(&word) {
        return head;
    }
    let mut c = head.chars();
    match c.next() {
        Some(f) => f.to_uppercase().collect::<String>() + c.as_str(),
        None => head,
    }
}

fn state_badge(ui: &mut egui::Ui, s: &str) {
    let (t, c) = match s {
        "ok" => ("Ready", pal().good),
        "warn" => ("Optional", pal().warn),
        "stale" => ("Update", pal().warn),
        _ => ("Needed", pal().crit),
    };
    badge(ui, t, c);
}

fn log_box(ui: &mut egui::Ui, id: &str, lines: &[String], h: f32) {
    egui::Frame::new().fill(pal().raised).corner_radius(radius_sm()).inner_margin(egui::Margin::symmetric(10, 8)).show(ui, |ui| {
        ui.set_width(ui.available_width());
        egui::ScrollArea::vertical().id_salt(id).max_height(h).stick_to_bottom(true).auto_shrink([false, true]).show(ui, |ui| {
            let start = lines.len().saturating_sub(400);
            for l in &lines[start..] {
                // a download's \r progress: its last state
                let l = l.rsplit('\r').find(|s| !s.trim().is_empty()).unwrap_or("");
                ui.add(egui::Label::new(egui::RichText::new(l).font(egui::FontId::monospace(11.5)).color(pal().ink_2)).wrap());
            }
        });
    });
}

impl App {
    pub fn develop_page(&mut self, ui: &mut egui::Ui) {
        let ctx = ui.ctx().clone();
        if !self.develop.loaded {
            self.develop.loaded = true;
            let s = dev::load_settings();
            self.develop.xip = s.xip;
            self.develop.keep_xip = true;
        }
        // status: at once, then every 1.5 s while a setup job runs (else every 20 s)
        let job_running = self.develop.status.lock().unwrap().as_ref().and_then(|s| s.job.as_ref()).is_some_and(|j| j.running);
        let every = if job_running { Duration::from_millis(1500) } else { Duration::from_secs(20) };
        if self.develop.last_poll.is_none_or(|t| t.elapsed() > every) {
            self.develop.last_poll = Some(Instant::now());
            self.develop.refresh(&ctx);
        }
        ctx.request_repaint_after(every);

        let mut recheck = false;
        page_header(ui, "Develop", |ui| {
            recheck = ui.add(Btn::secondary("Check again").icon(icon::ARROW_CLOCKWISE)).clicked();
        });
        if recheck {
            self.develop.refresh(&ctx);
        }
        let st = self.develop.status.lock().unwrap().clone();
        let Some(st) = st else {
            busy(ui, "Checking the toolchain…");
            return;
        };
        if st.pieces.iter().any(|p| p.id == "fork" && p.state != "ok") {
            empty_state(ui, icon::PACKAGE, "omarchy-apple-dev is missing", &st.fork.display().to_string(), |_| {});
            return;
        }

        // ---- the toolchain
        let job = st.job.clone();
        let busy_job = job.as_ref().is_some_and(|j| j.running);
        let mut start: Option<(&'static str, Vec<String>)> = None;
        let mut go_settings = false;
        // Download Xcode with the Apple Account (Settings > Apple Account): the .xip, then the SDK from it
        let signed_in = x86sim_core::account::load_meta().is_some();
        section(ui, "Toolchain", |ui| {
            let tip = if signed_in {
                format!("Xcode {} from Apple, then its SDK", x86sim_core::account::pinned_xcode_major())
            } else {
                "Needs a sign-in: Settings > Apple Account".to_string()
            };
            if ui.add_enabled(!busy_job && signed_in, Btn::ghost("Download Xcode").icon(icon::DOWNLOAD_SIMPLE).small()).on_hover_text(&tip).on_disabled_hover_text(&tip).clicked() {
                let mut a = vec![];
                if !self.develop.keep_xip {
                    a.push("--delete-xip".to_string());
                }
                start = Some(("xcode", a));
            }
            ui.checkbox(&mut self.develop.keep_xip, muted("keep the .xip"));
            if ui.add_enabled(!busy_job && st.ready_sim, Btn::ghost("Verify").icon(icon::CHECK_CIRCLE).small()).on_hover_text("Build a new app end to end").clicked() {
                start = Some(("verify", vec![]));
            }
            if ui.add_enabled(!busy_job, Btn::ghost("Repair").icon(icon::WRENCH).small()).on_hover_text("Re-register the SDK and its tools (after a Swift update)").clicked() {
                start = Some(("repair", vec![]));
            }
        });
        list_card(ui, |ui| {
            let pieces: Vec<_> = st.pieces.iter().filter(|p| p.id != "fork").collect();
            for (k, p) in pieces.iter().enumerate() {
                if k > 0 {
                    hline(ui);
                }
                let line = terse(&p.detail);
                let tip = if line == p.detail { String::new() } else { p.detail.clone() };
                let row = list_row(ui, piece_icon(p.id), p.title, &line, |ui| {
                    state_badge(ui, p.state);
                    if busy_job {
                        return;
                    }
                    match (p.id, p.state) {
                        ("swift", "missing" | "stale") => {
                            if ui.add(Btn::primary("Install").icon(icon::DOWNLOAD_SIMPLE)).on_hover_text(format!("Swift {} from swift.org · 1.1 GB", dev::SWIFT_VERSION)).clicked() {
                                start = Some(("swift", vec![]));
                            }
                        }
                        ("xtool", s) if s != "ok" => {
                            if ui.add(Btn::primary(if s == "missing" { "Install" } else { "Update" }).icon(icon::DOWNLOAD_SIMPLE)).on_hover_text("xtool, rcodesign, ipsw, pymobiledevice3 · about 7 min").clicked() {
                                start = Some(("toolchain", vec![]));
                            }
                        }
                        ("cocoapods", s) if s != "ok" => {
                            if ui.add(Btn::primary(if s == "stale" { "Update" } else { "Install" }).icon(icon::DOWNLOAD_SIMPLE)).on_hover_text("Ruby and CocoaPods · 70 MB").clicked() {
                                start = Some(("cocoapods", vec![]));
                            }
                        }
                        ("swiftbuild", s) if s != "ok" => {
                            if ui.add(Btn::primary("Install").icon(icon::DOWNLOAD_SIMPLE)).on_hover_text("Swift Build for Xcode projects · 220 MB").clicked() {
                                start = Some(("swiftbuild", vec![]));
                            }
                        }
                        (id, s) if s != "ok" && (id == "lldb" || x86sim_core::devgen::is_tool(id)) => {
                            if ui.add(Btn::primary("Install").icon(icon::DOWNLOAD_SIMPLE)).clicked() {
                                start = Some((id, vec![]));
                            }
                        }
                        ("device", s) if s != "ok" && p.fix.contains("account login") => {
                            if ui.add(Btn::secondary("Sign in").icon(icon::SIGN_IN)).on_hover_text("Settings > Apple Account").clicked() {
                                go_settings = true;
                            }
                        }
                        ("packages", "missing") => {
                            if ui.add(Btn::secondary("Copy command").icon(icon::COPY)).on_hover_text(&p.fix).clicked() {
                                ui.ctx().copy_text(p.fix.clone());
                            }
                        }
                        _ => {}
                    }
                });
                if !tip.is_empty() {
                    row.on_hover_text(&tip);
                }
                if p.id == "sdk" && p.state != "ok" {
                    egui::Frame::new().inner_margin(egui::Margin { left: 60, right: 16, top: 0, bottom: 12 }).show(ui, |ui| {
                        ui.horizontal(|ui| {
                            ui.add(egui::TextEdit::singleline(&mut self.develop.xip).hint_text("/path/to/Xcode_27.xip").desired_width(420.0));
                            let ok = std::path::Path::new(self.develop.xip.trim()).is_file();
                            if ui.add_enabled(ok && !busy_job, Btn::primary("Build SDK")).on_hover_text("From Xcode 27's .xip · about 3 GB").clicked() {
                                start = Some(("sdk", vec!["--xip".into(), self.develop.xip.trim().into()]));
                            }
                        });
                    });
                }
            }
        });
        if go_settings {
            self.view = crate::View::Settings;
        }
        if let Some((kind, args)) = start {
            match dev::start_job(kind, &args) {
                Ok(_) => {
                    self.develop.show_job_log = true;
                    self.say(format!("Setup started: {kind}"));
                }
                Err(e) => self.say(format!("Couldn't start: {e:#}")),
            }
            self.develop.last_poll = None;
        }
        // the setup job
        if let Some(j) = &job {
            ui.add_space(S3);
            let mut cancel = false;
            let mut go_account = false;
            list_card(ui, |ui| {
                let title = match (j.running, j.rc) {
                    (true, _) => format!("Installing: {}", j.kind),
                    (false, Some(0)) => format!("Finished: {}", j.kind),
                    (false, rc) => format!("Stopped: {} · exit {}", j.kind, rc.unwrap_or(-1)),
                };
                let last = j.last.trim_matches(|c| c == '=' || c == ' ').to_string();
                let detail = if j.step.is_empty() || j.step == last { last } else { format!("{} · {last}", j.step) };
                // Download Xcode stopped on an expired Apple sign-in: the way back is Settings > Apple Account
                let expired = !j.running && j.last.contains(x86sim_core::account::SIGN_IN_EXPIRED);
                list_row(ui, if j.running { icon::HOURGLASS } else { icon::TERMINAL_WINDOW }, &title, &detail, |ui| {
                    if j.running {
                        cancel = ui.add(Btn::secondary("Cancel")).clicked();
                    }
                    if expired && ui.add(Btn::primary("Sign in again").icon(icon::SIGN_IN)).on_hover_text("Settings > Apple Account").clicked() {
                        go_account = true;
                    }
                    let t = if self.develop.show_job_log { "Hide log" } else { "Show log" };
                    if ui.add(Btn::ghost(t).small()).clicked() {
                        self.develop.show_job_log = !self.develop.show_job_log;
                    }
                });
                if j.running {
                    egui::Frame::new().inner_margin(egui::Margin { left: 60, right: 16, top: 0, bottom: 10 }).show(ui, |ui| {
                        progress(ui, Some(j.progress.max(0.03)), pal().accent);
                    });
                }
                if self.develop.show_job_log {
                    egui::Frame::new().inner_margin(egui::Margin { left: 14, right: 14, top: 0, bottom: 12 }).show(ui, |ui| {
                        let text = dev::tail_bytes(&j.log, 64 * 1024);
                        let lines: Vec<String> = text.lines().map(String::from).collect();
                        log_box(ui, "dev-job-log", &lines, 220.0);
                    });
                }
            });
            if go_account {
                self.view = crate::View::Settings;
            }
            if cancel {
                if let Err(e) = dev::cancel_job() {
                    self.say(format!("{e:#}"));
                }
                self.develop.last_poll = None;
            }
        }

        ui.add_space(S4);
    }
}
