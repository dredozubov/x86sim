//! Settings > Apple Account: one Apple ID sign-in for Xcode downloads and the dev toolchain's signing
//! (x86sim_core::account, shared with `x86sim account`). The password is typed here, handed to the sign-in thread and
//! wiped; the two-factor code (trusted device, or an SMS) is asked for in the same card.
use crate::global::{list_row, note};
use crate::theme::*;
use crate::App;
use eframe::egui;
use std::sync::mpsc::{channel, Receiver, Sender};
use std::sync::{Arc, Mutex};
use x86sim_core::account::{self, CodeAnswer, CodePrompt};

/// What the sign-in thread is waiting for
#[derive(Clone, Default)]
enum Waiting {
    #[default]
    Nothing,
    Code(CodePrompt),
    Choice(String, Vec<String>),
}

#[derive(Default)]
struct Shared {
    lines: Vec<String>,
    waiting: Waiting,
    /// Some once finished: Ok, or the error
    done: Option<Result<(), String>>,
}

#[derive(Default)]
pub struct AccountUi {
    apple_id: String,
    password: String,
    signing: bool,
    code: String,
    status: Arc<Mutex<Option<Result<account::Status, String>>>>,
    checking: Arc<Mutex<bool>>,
    loaded: bool,
    run: Option<Arc<Mutex<Shared>>>,
    code_tx: Option<Sender<CodeAnswer>>,
    choice_tx: Option<Sender<usize>>,
}

struct GuiAsk {
    shared: Arc<Mutex<Shared>>,
    code_rx: Receiver<CodeAnswer>,
    choice_rx: Receiver<usize>,
    ctx: egui::Context,
}

impl account::Ask for GuiAsk {
    fn say(&mut self, line: &str) {
        self.shared.lock().unwrap().lines.push(line.to_string());
        self.ctx.request_repaint();
    }
    fn code(&mut self, p: &CodePrompt) -> anyhow::Result<CodeAnswer> {
        self.shared.lock().unwrap().waiting = Waiting::Code(p.clone());
        self.ctx.request_repaint();
        let r = account::wait_code(&self.code_rx);
        self.shared.lock().unwrap().waiting = Waiting::Nothing;
        r
    }
    fn choose(&mut self, title: &str, options: &[String]) -> anyhow::Result<usize> {
        self.shared.lock().unwrap().waiting = Waiting::Choice(title.to_string(), options.to_vec());
        self.ctx.request_repaint();
        let r = self.choice_rx.recv_timeout(account::CODE_TIMEOUT).map_err(|_| anyhow::anyhow!("no choice made: sign in again"));
        self.shared.lock().unwrap().waiting = Waiting::Nothing;
        r
    }
}

impl AccountUi {
    /// Status, asking Apple whether the session still works (`live`), on a thread
    fn refresh(&self, ctx: &egui::Context, live: bool) {
        let mut c = self.checking.lock().unwrap();
        if *c {
            return;
        }
        *c = true;
        let (st, chk, ctx) = (self.status.clone(), self.checking.clone(), ctx.clone());
        std::thread::spawn(move || {
            let s = account::status(live).map_err(|e| format!("{e:#}"));
            *st.lock().unwrap() = Some(s);
            *chk.lock().unwrap() = false;
            ctx.request_repaint();
        });
    }

    fn start_login(&mut self, ctx: &egui::Context, signing_only: bool) {
        let shared = Arc::new(Mutex::new(Shared::default()));
        let (ctx_tx, code_rx) = channel();
        let (ch_tx, choice_rx) = channel();
        self.code_tx = Some(ctx_tx);
        self.choice_tx = Some(ch_tx);
        self.run = Some(shared.clone());
        let id = self.apple_id.trim().to_string();
        // the password moves to the thread; the field is cleared at once
        let mut pw = std::mem::take(&mut self.password);
        let signing = self.signing;
        let mut ask = GuiAsk { shared: shared.clone(), code_rx, choice_rx, ctx: ctx.clone() };
        let (st, ctx2) = (self.status.clone(), ctx.clone());
        std::thread::spawn(move || {
            let r = if signing_only { account::login_signing(&id, &mut pw, &mut ask).map(|_| None) } else { account::login(&id, &mut pw, signing, &mut ask).map(Some) };
            let mut g = shared.lock().unwrap();
            g.done = Some(match r {
                Ok(s) => {
                    if let Some(s) = s {
                        *st.lock().unwrap() = Some(Ok(s));
                    }
                    Ok(())
                }
                Err(e) => Err(format!("{e:#}")),
            });
            ctx2.request_repaint();
        });
    }
}

impl App {
    pub fn account_section(&mut self, ui: &mut egui::Ui) {
        let ctx = ui.ctx().clone();
        if !self.account.loaded {
            self.account.loaded = true;
            if let Some(m) = account::load_meta() {
                self.account.apple_id = m.apple_id;
            }
            self.account.refresh(&ctx, true);
        }
        let mut check = false;
        section(ui, "Apple Account", |ui| {
            check = ui.add(Btn::ghost("Check").icon(icon::ARROW_CLOCKWISE).small()).on_hover_text("Ask Apple whether the session still works").clicked();
        });
        if check {
            self.account.refresh(&ctx, true);
        }
        let st = self.account.status.lock().unwrap().clone();
        let run = self.account.run.clone();
        let mut sign_out = false;
        let mut start: Option<bool> = None;
        list_card(ui, |ui| {
            // a sign-in in progress: its lines, the code or choice it waits for
            if let Some(run) = &run {
                let (lines, waiting, done) = {
                    let g = run.lock().unwrap();
                    (g.lines.clone(), g.waiting.clone(), g.done.clone())
                };
                let last = lines.last().cloned().unwrap_or_else(|| "Contacting Apple…".into());
                list_row(ui, icon::SIGN_IN, "Signing in", &last, |ui| {
                    if done.is_some() && ui.add(Btn::ghost("Close").small()).clicked() {
                        self.account.run = None;
                    }
                });
                match &waiting {
                    Waiting::Code(p) => {
                        egui::Frame::new().inner_margin(egui::Margin { left: 60, right: 16, top: 0, bottom: 12 }).show(ui, |ui| {
                            let what = match p.sent.as_str() {
                                "sms" => format!("Enter the {}-digit code texted to {}.", p.length, p.sms_to),
                                "xtool" => "xtool's sign-in for signing: enter the code shown on your trusted Apple devices.".to_string(),
                                _ => format!("Enter the {}-digit code shown on your trusted Apple devices.", p.length),
                            };
                            if p.retry {
                                ui.label(egui::RichText::new("Apple didn't take that code: try again.").color(pal().crit));
                            }
                            ui.label(muted(what));
                            ui.horizontal(|ui| {
                                let r = ui.add(egui::TextEdit::singleline(&mut self.account.code).hint_text("123456").desired_width(120.0));
                                let enter = r.lost_focus() && ui.input(|i| i.key_pressed(egui::Key::Enter));
                                if (ui.add_enabled(!self.account.code.trim().is_empty(), Btn::primary("Verify")).clicked() || enter) && !self.account.code.trim().is_empty() {
                                    if let Some(tx) = &self.account.code_tx {
                                        let _ = tx.send(CodeAnswer::Code(std::mem::take(&mut self.account.code)));
                                    }
                                }
                            });
                            if p.sent != "xtool" && !p.phones.is_empty() {
                                ui.horizontal_wrapped(|ui| {
                                    ui.label(muted("No device nearby? Text it to"));
                                    for ph in &p.phones {
                                        if ui.add(Btn::ghost(&ph.number).small()).clicked() {
                                            if let Some(tx) = &self.account.code_tx {
                                                let _ = tx.send(CodeAnswer::Sms(ph.id));
                                            }
                                        }
                                    }
                                });
                            }
                        });
                    }
                    Waiting::Choice(title, opts) => {
                        egui::Frame::new().inner_margin(egui::Margin { left: 60, right: 16, top: 0, bottom: 12 }).show(ui, |ui| {
                            ui.label(muted(title));
                            ui.horizontal_wrapped(|ui| {
                                for (i, o) in opts.iter().enumerate() {
                                    if ui.add(Btn::secondary(o)).clicked() {
                                        if let Some(tx) = &self.account.choice_tx {
                                            let _ = tx.send(i);
                                        }
                                    }
                                }
                            });
                        });
                    }
                    Waiting::Nothing => {
                        if done.is_none() {
                            egui::Frame::new().inner_margin(egui::Margin { left: 60, right: 16, top: 0, bottom: 10 }).show(ui, |ui| progress(ui, None, pal().accent));
                        }
                    }
                }
                if let Some(Err(e)) = &done {
                    note(ui, e);
                }
                hline(ui);
            }
            let signed_in = matches!(&st, Some(Ok(s)) if s.signed_in);
            match &st {
                None => busy(ui, "Checking the Apple Account…"),
                Some(Err(e)) => note(ui, e),
                Some(Ok(s)) if s.signed_in => {
                    let who = if s.name.is_empty() { s.apple_id.clone() } else { format!("{} ({})", s.apple_id, s.name) };
                    let detail = format!(
                        "Signed in {}; the session is in the {}{}",
                        s.signed_in_on,
                        if s.store == "keyring" { "Secret Service keyring" } else { "0600 file in ~/.config/x86sim" },
                        match s.session_ok {
                            Some(true) => ", works",
                            Some(false) => ", expired: sign in again",
                            None => "",
                        }
                    );
                    list_row(ui, icon::USER_CIRCLE_CHECK, &who, &detail, |ui| {
                        sign_out = ui.add(Btn::secondary("Sign out")).on_hover_text("Forget the session (xtool's sign-in stays: x86sim account logout signs it out too)").clicked();
                    });
                    hline(ui);
                    list_row(ui, icon::DOWNLOAD_SIMPLE, "Developer downloads", &s.downloads, |ui| {
                        badge(ui, if s.downloads == "ok" { "Ready" } else { "Check" }, if s.downloads == "ok" { pal().good } else { pal().warn });
                    });
                    hline(ui);
                    let sign_ok = s.signing.starts_with("ok");
                    list_row(ui, icon::HAMMER, "Signing (xtool)", &s.signing, |ui| {
                        badge(ui, if sign_ok { "Ready" } else { "Off" }, if sign_ok { pal().good } else { pal().warn });
                    });
                    hline(ui);
                    list_row(ui, icon::CLOCK, "Renewal", &s.renew, |_| {});
                }
                Some(Ok(_)) => {}
            }
            // the sign-in form: when signed out, when the session expired, or for xtool alone
            let expired = matches!(&st, Some(Ok(s)) if s.session_ok == Some(false));
            let signing_off = matches!(&st, Some(Ok(s)) if !s.signing.starts_with("ok"));
            let busy_run = run.as_ref().is_some_and(|r| r.lock().unwrap().done.is_none());
            if (!signed_in || expired || signing_off) && !busy_run {
                if signed_in {
                    hline(ui);
                }
                form_row(ui, "Apple ID", "Any Apple ID (free) works for Xcode downloads; signing for devices needs it too.", false, |ui| {
                    ui.add(egui::TextEdit::singleline(&mut self.account.apple_id).hint_text("you@example.com").desired_width(260.0));
                });
                form_row(ui, "Password", "Sent only as Apple's SRP proof, never stored. Apple then asks for a two-factor code.", false, |ui| {
                    let r = ui.add(egui::TextEdit::singleline(&mut self.account.password).password(true).desired_width(260.0));
                    if r.lost_focus() && ui.input(|i| i.key_pressed(egui::Key::Enter)) {
                        start = Some(false);
                    }
                });
                form_row(ui, "Also sign in for signing", "xtool (device builds, installs, x86sim dev ship) gets the same password once, for its own sign-in with Apple; it uses a third-party anisette service for its device identity.", false, |ui| {
                    toggle(ui, &mut self.account.signing);
                });
                form_row(ui, "", "", true, |ui| {
                    let ok = !self.account.apple_id.trim().is_empty() && !self.account.password.is_empty();
                    if signed_in && !expired && ui.add_enabled(ok, Btn::secondary("Sign in xtool only")).clicked() {
                        start = Some(true);
                    }
                    if ui.add_enabled(ok, Btn::primary("Sign in").icon(icon::SIGN_IN)).clicked() {
                        start = Some(false);
                    }
                });
            }
        });
        if let Some(only) = start {
            if !self.account.apple_id.trim().is_empty() && !self.account.password.is_empty() {
                self.account.start_login(&ctx, only);
            }
        }
        // a finished sign-in: the status again
        if let Some(r) = &self.account.run {
            let fin = r.lock().unwrap().done.as_ref().map(|d| d.is_ok());
            if fin == Some(true) && !*self.account.checking.lock().unwrap() {
                self.account.run = None;
                self.account.refresh(&ctx, false);
                self.say("Signed in to the Apple Account");
            }
        }
        if sign_out {
            match account::logout() {
                Ok(_) => self.say("Signed out of the Apple Account"),
                Err(e) => self.say(format!("Sign-out failed: {e:#}")),
            }
            *self.account.status.lock().unwrap() = None;
            self.account.refresh(&ctx, false);
        }
    }
}
