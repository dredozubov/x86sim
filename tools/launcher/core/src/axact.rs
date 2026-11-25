//! Agent actions, round 2 (docs/protocols/SIMAX.md `focus`): `type` into the field that was tapped. Kept apart from
//! ax.rs (snapshot, tap, type_text, ...), whose pieces it builds on.
//!
//! A tap moves the focus a moment after the touch (UIKit's first responder change, WebKit's focus in its content
//! process): text typed right away went into the field focused before, or a web field dropped it. `type_into` taps
//! the target, then waits on frames (up to 2 s) until simax says that element, or a text field inside it, is the first
//! responder, types, and checks the text landed there. `fill` does that for several fields; field targets also match
//! a placeholder and the label beside a field. `drag` presses, holds to lift, moves and drops; `set_value` sets a
//! control (slider, switch, stepper, segmented control, picker wheels, date picker, anything adjustable) in the app.
//! `expect` checks the screen (an element there or not, its label / value / states, how many), waiting on frames.
use crate::ax::{self, After, El, Outcome, SnapOpts, Snapshot, Target};
use serde::Deserialize;
use crate::instance::Instance;
use crate::ring::Ring;
use anyhow::{bail, Result};
use serde_json::{json, Value};
use std::time::{Duration, Instant};

/// How long `type` waits for the tapped field to take the focus
pub const FOCUS_WAIT: Duration = Duration::from_secs(2);
/// ... and, while nothing has the focus yet, for a first one: the keyboard's first appearance in a process (its
/// input system loading under the translator) can take several seconds before the field becomes first responder
pub const FIRST_FOCUS_WAIT: Duration = Duration::from_secs(8);

/// The first responder of one process (simax `focus`), when it has one
pub fn focus_of(inst: &Instance, pid: u32) -> Option<Value> {
    let v = ax::ask_pid(inst, pid, &json!({"op": "focus"}), Duration::from_millis(1500)).ok()?;
    (v["focused"].as_bool() == Some(true)).then(|| with_pid(v, pid))
}

fn with_pid(mut v: Value, pid: u32) -> Value {
    v["pid"] = json!(pid);
    v
}

/// The focused text input on screen: apps first, SpringBoard (Spotlight, alerts' fields) last
pub fn focus_any(inst: &Instance) -> Option<Value> {
    let mut found: Vec<Value> = vec![];
    for ep in ax::endpoints(inst).into_iter().filter(|e| e.fg) {
        let pid = ax::pid_of_sock(&ep.sock);
        if let Ok(Some(v)) = ax::ask(&ep.sock, &json!({"op": "focus"}), Duration::from_millis(1500)) {
            if v["focused"].as_bool() == Some(true) && v["text_input"].as_bool() == Some(true) {
                found.push(with_pid(v, pid));
            }
        }
    }
    let sb = ax::last(inst).and_then(|s| s.elements.iter().find(|e| e.app == "com.apple.springboard").map(|e| e.pid));
    found.sort_by_key(|v| v["pid"].as_u64().map(|p| p as u32) == sb);
    found.into_iter().next()
}

/// One line naming a focused field: `UITextField "Email" (now "a@b.c")`
pub fn describe_focus(f: &Value) -> String {
    let mut s = f["class"].as_str().unwrap_or("?").to_string();
    if let Some(l) = f["label"].as_str().or(f["placeholder"].as_str()).or(f["id"].as_str()) {
        s += &format!(" {}", ax::quote(l));
    }
    if let Some(v) = f["value"].as_str() {
        s += &format!(" (now {})", ax::quote(v));
    }
    s
}

fn frame_of(f: &Value) -> String {
    match f["frame"].as_array() {
        Some(r) if r.len() == 4 => format!(" at ({:.0},{:.0} {:.0}x{:.0})", r[0].as_f64().unwrap_or(0.0), r[1].as_f64().unwrap_or(0.0), r[2].as_f64().unwrap_or(0.0), r[3].as_f64().unwrap_or(0.0)),
        _ => String::new(),
    }
}

fn center(f: &[f64; 4]) -> (f64, f64) {
    (f[0] + f[2] / 2.0, f[1] + f[3] / 2.0)
}

/// Does `f` (simax `focus` of e's process) say e, or a text field inside it, has the focus?
fn holds_focus(e: &El, f: &Value) -> bool {
    if f["text_input"].as_bool() != Some(true) {
        return false;
    }
    let oid = f["oid"].as_str().unwrap_or("");
    if e.oid == oid || f["inside"].as_array().is_some_and(|a| a.iter().any(|x| x.as_str() == Some(&e.oid))) {
        return true;
    }
    // an accessibility element standing for the field (a SwiftUI node over its UITextField): the field's center in it
    if let Some(r) = f["frame"].as_array().filter(|r| r.len() == 4) {
        let r: Vec<f64> = r.iter().map(|x| x.as_f64().unwrap_or(0.0)).collect();
        let (cx, cy) = center(&[r[0], r[1], r[2], r[3]]);
        let [x, y, w, h] = e.frame;
        return f["kind"] != "web" && cx >= x - 2.0 && cx <= x + w + 2.0 && cy >= y - 2.0 && cy <= y + h + 2.0;
    }
    false
}

/// Taps a target (ref, id:, text) and waits on frames until it has the focus. Answers the element and simax's
/// `focus`. A web field: WebKit's content view is the first responder, the DOM's activeElement is the field.
pub fn tap_focus(inst: &Instance, target: &str) -> Result<(El, Value)> {
    let e0 = field_el(inst, target)?;
    // already focused (a second `type` into the same field): no tap, which would move the caret
    if let Some(f) = focus_of(inst, e0.pid).filter(|f| !e0.web && holds_focus(&e0, f)) {
        return Ok((e0, f));
    }
    let e0 = clear_of_keyboard(inst, e0)?;
    ax::tap(inst, &format!("@{}", e0.r), 80, After::None)?;
    // a field that was scrolled into view by the tap is somewhere else now
    let mut e = if e0.offscreen { ax::snapshot(inst, SnapOpts::default()).ok().and_then(|s| s.get(&e0.r).cloned()).unwrap_or(e0) } else { e0 };
    let t0 = Instant::now();
    let mut ring = Ring::new(&ax::screen_ring(inst));
    let mut last: Option<Value> = None;
    let mut n = 0;
    loop {
        let seq = ring.seq();
        if let Some(f) = focus_of(inst, e.pid) {
            if e.web {
                if f["kind"] == "web" {
                    // the DOM's focus: the element (by its ref) is focused in a fresh snapshot
                    if let Ok(s) = ax::snapshot(inst, SnapOpts::default()) {
                        if let Some(x) = s.get(&e.r) {
                            if x.focused {
                                return Ok((x.clone(), f));
                            }
                            e = x.clone();
                        }
                    }
                }
            } else if holds_focus(&e, &f) {
                return Ok((e, f));
            }
            last = Some(f);
        }
        n += 1;
        if n % 4 == 0 && !e.web {
            // it may have moved (a keyboard coming up scrolls a form)
            if let Some(x) = ax::snapshot(inst, SnapOpts::default()).ok().and_then(|s| s.get(&e.r).cloned()) {
                e = x;
            }
        }
        let limit = if last.as_ref().is_some_and(|f| f["text_input"].as_bool() == Some(true)) { FOCUS_WAIT } else { FIRST_FOCUS_WAIT };
        let left = limit.saturating_sub(t0.elapsed());
        if left.is_zero() {
            break;
        }
        ring.wait(seq, left.min(Duration::from_millis(250)));
    }
    // once more against where the element is now
    if let (Some(f), Some(x)) = (focus_of(inst, e.pid), ax::snapshot(inst, SnapOpts::default()).ok().and_then(|s| s.get(&e.r).cloned())) {
        if (x.web && x.focused) || (!x.web && holds_focus(&x, &f)) {
            return Ok((x, f));
        }
    }
    let what = format!("@{} {} {}", e.r, e.role, e.label.as_deref().map(ax::quote).unwrap_or_default());
    let waited = t0.elapsed().as_secs_f64();
    match last.or_else(|| focus_any(inst)) {
        Some(f) if f["text_input"].as_bool() == Some(true) => {
            bail!("tapped {what}, but after {waited:.1} s the focus is on {}{} in pid {}: the text would land there", describe_focus(&f), frame_of(&f), f["pid"])
        }
        _ => bail!("tapped {what}, but no text field took the focus within {waited:.1} s (is it a text field? disabled?)"),
    }
}

/// `type` with an optional target: the target is tapped and must take the focus first; without one a field must
/// already have it. The text goes in as ax::type_text sends it; the answer names the field that got it and its value.
/// The focus moving elsewhere while typing (an app moving it on its own) is an error, not silent.
pub fn type_into(inst: &Instance, target: Option<&str>, text: &str, clear: bool, submit: bool, keys: bool, after: After) -> Result<Outcome> {
    let (el, f) = match target.filter(|t| !t.trim().is_empty()) {
        Some(t) => {
            let (e, f) = tap_focus(inst, t)?;
            (Some(e), f)
        }
        None => match focus_any(inst) {
            Some(f) => (None, f),
            None => bail!("cannot type: no focused text field (tap one first, or pass target)"),
        },
    };
    let pid = f["pid"].as_u64().unwrap_or(0) as u32;
    let mut o = ax::type_text(inst, text, clear, submit, keys, After::None)?;
    // where it went: the same object still focused, and its value now (a submit may end editing: then the field as it
    // was is all there is to say)
    let now = focus_of(inst, pid);
    let field = match (&el, &now) {
        (Some(e), _) => format!("@{} {} {}", e.r, e.role, e.label.as_deref().map(ax::quote).unwrap_or_default()),
        (None, _) => describe_focus(&f),
    };
    match &now {
        Some(n) if n["oid"] != f["oid"] && !submit && !text.contains('\n') => {
            bail!("typed, but the focus moved from {} to {} while typing: check where the text went", describe_focus(&f), describe_focus(n))
        }
        Some(n) if n["oid"] == f["oid"] && f["kind"] != "web" => {
            o.did = format!("typed {} into {}{}{}", shown(text, &f), field.trim_end(), n["value"].as_str().map(|v| format!(" (now {})", ax::quote(v))).unwrap_or_default(), returns(&o.did));
        }
        _ if el.is_some() => {
            o.did = format!("typed {} into {}{}", shown(text, &f), field.trim_end(), returns(&o.did));
        }
        _ => {}
    }
    Ok(ax::outcome(inst, o.did, ax::last(inst), after))
}

/// The typed text as the answer repeats it: a secure field's as dots
fn shown(text: &str, f: &Value) -> String {
    if f["kind"] == "securefield" {
        format!("{} characters", text.chars().filter(|c| *c != '\n').count())
    } else {
        ax::quote(text)
    }
}

/// ", Return pressed..." of type_text's line
fn returns(did: &str) -> String {
    did.find(", Return pressed").map(|i| did[i..].to_string()).unwrap_or_default()
}

// ---------------------------------------------------------------------------------------------------------------------
// Fields by what is written next to them, and `fill`

fn is_field(e: &El) -> bool {
    matches!(e.role.as_str(), "textfield" | "searchfield")
}

/// How far a field is from a label beside it: to its right on the same row (closest first), else below it in the same
/// column (after every field on the row); None: not beside it
fn beside(l: &El, f: &El) -> Option<f64> {
    let [lx, ly, lw, lh] = l.frame;
    let [fx, fy, fw, fh] = f.frame;
    let (lc, fc) = (ly + lh / 2.0, fy + fh / 2.0);
    if fx >= lx + lw - 4.0 && (lc - fc).abs() < fh.max(lh) / 2.0 + 4.0 {
        return Some(fx - (lx + lw));
    }
    // above it: left-aligned with it and close (a title over a row that starts with its own label is not one)
    if fy >= ly + lh - 4.0 && fy - (ly + lh) < 30.0 && (fx - lx).abs() < 12.0 && fw > 0.0 {
        return Some(1000.0 + fy - (ly + lh));
    }
    None
}

/// The text field a target means: a ref / id: / point as everywhere; text: a field whose label, placeholder (simax
/// gives an unlabelled field its placeholder as label), identifier or value matches, else the field beside a label
/// that matches ("Email" written left of, or above, a field with nothing in it), else whatever matches
pub fn find_field(snap: &Snapshot, target: &str) -> Result<El> {
    let t = ax::parse_target(target);
    if !matches!(t, Target::Text(_)) {
        return ax::find(snap, target).cloned();
    }
    let usable = |e: &&El| !e.covered;
    // a field whose own text matches well (exact, id / value, prefix), then the field beside a label that does, then a
    // field whose text only contains it ("Name" in "Username" comes after the field next to "Name")
    if let Some(e) = ax::find_all_q(snap, &t, 2).into_iter().filter(usable).find(|e| is_field(e)) {
        return Ok(e.clone());
    }
    for l in ax::find_all_q(snap, &t, 2).into_iter().filter(usable).filter(|e| !is_field(e)) {
        let near = snap
            .elements
            .iter()
            .filter(|f| is_field(f) && f.pid == l.pid && !f.covered && f.offscreen == l.offscreen)
            .filter_map(|f| beside(l, f).map(|d| (d, f)))
            .min_by(|a, b| a.0.total_cmp(&b.0));
        if let Some((_, f)) = near {
            return Ok(f.clone());
        }
    }
    if let Some(e) = ax::find_all_q(snap, &t, 3).into_iter().filter(usable).find(|e| is_field(e)) {
        return Ok(e.clone());
    }
    ax::find(snap, target).cloned()
}

/// The field for a target on screen now; one scrolled out of view (`snapshot all`) is scrolled into view first
pub fn field_el(inst: &Instance, target: &str) -> Result<El> {
    let snap = ax::snapshot(inst, SnapOpts::default())?;
    let here = find_field(&snap, target);
    if here.as_ref().is_ok_and(is_field) || !matches!(ax::parse_target(target), Target::Text(_)) {
        return here;
    }
    // no field on screen matches: a field scrolled out of view does (also over a text on screen that only contains
    // the words, as a form's summary line does)
    let all = ax::snapshot(inst, SnapOpts { all: true, ..Default::default() })?;
    let e = match find_field(&all, target) {
        Ok(e) if is_field(&e) => e,
        _ => return here,
    };
    if !e.offscreen {
        return Ok(e);
    }
    ax::scroll_into_view(inst, &e)?;
    let now = ax::snapshot(inst, SnapOpts::default())?;
    now.get(&e.r).cloned().or_else(|| find_field(&now, target).ok()).ok_or_else(|| anyhow::anyhow!("{target:?} scrolled into view, then not found"))
}

fn is_control(e: &El) -> bool {
    !matches!(e.role.as_str(), "text" | "heading" | "image" | "element" | "webview")
}

/// A control a target means (a submit button): the best match on screen when it is one; else a control that matches
/// as well and is scrolled out of view (a form's button far down, below a title with the same words), scrolled in
pub fn control_el(inst: &Instance, target: &str) -> Result<El> {
    let snap = ax::snapshot(inst, SnapOpts::default())?;
    let here = ax::find(&snap, target).cloned();
    if here.as_ref().is_ok_and(is_control) || !matches!(ax::parse_target(target), Target::Text(_)) {
        return here;
    }
    let all = ax::snapshot(inst, SnapOpts { all: true, ..Default::default() })?;
    let Some(e) = ax::find_all_q(&all, &ax::parse_target(target), 2).into_iter().find(|e| is_control(e) && !e.covered).cloned() else { return here };
    if !e.offscreen {
        return Ok(e);
    }
    let t = ax::parse_target(target);
    // in view and away from the screen's edges (a touch in the bottom strip is the home indicator's)
    let inside = |s: &Snapshot, x: &El| !x.offscreen && {
        let cy = x.frame[1] + x.frame[3] / 2.0;
        cy > 50.0 && cy < s.screen.1 - 50.0
    };
    let found = |s: &Snapshot| s.get(&e.r).filter(|x| inside(s, x)).cloned().or_else(|| ax::find_all_q(s, &t, 2).into_iter().find(|x| is_control(x) && inside(s, x)).cloned());
    let _ = ax::scroll_into_view(inst, &e);
    let now = ax::snapshot(inst, SnapOpts::default())?;
    if let Some(x) = found(&now) {
        return Ok(x);
    }
    // the app said it scrolled and did not (a SwiftUI button's accessibilityScrollToVisible): scroll toward it
    let dir = if e.frame[1] > now.screen.1 / 2.0 { "down" } else { "up" };
    for i in 0..10 {
        ax::scroll(inst, dir, if i == 0 { 0.6 } else { 0.3 }, None, After::None)?;
        ax::settle(inst, Duration::from_millis(200), Duration::from_millis(1500));
        let now = ax::snapshot(inst, SnapOpts::default())?;
        if let Some(x) = found(&now) {
            return Ok(x);
        }
    }
    bail!("{target:?} is out of view and scrolling {dir} did not bring it in")
}

/// The top of the software keyboard on screen (its keys' and suggestion bar's), when it is up
fn keyboard_top(s: &Snapshot) -> Option<f64> {
    if !ax::software_keyboard_up(s) {
        return None;
    }
    let keys = s.elements.iter().filter(|e| e.role == "key").map(|e| e.frame[1]).fold(f64::MAX, f64::min);
    let win = s.elements.iter().filter(|e| e.window.contains("Keyboard")).map(|e| e.frame[1]).fold(f64::MAX, f64::min);
    // the suggestion bar above the keys is not always listed: count it in
    Some(win.min(keys - 50.0))
}

/// An element under the software keyboard (a button below a form, a field low on the page) is scrolled up clear of
/// it before a tap: a touch there would hit the keyboard (its suggestion bar typed a word into the field). Answers the
/// element where it is now.
pub fn clear_of_keyboard(inst: &Instance, e: El) -> Result<El> {
    for _ in 0..3 {
        let s = ax::snapshot(inst, SnapOpts::default())?;
        let cur = s.get(&e.r).cloned().unwrap_or_else(|| e.clone());
        let Some(top) = keyboard_top(&s) else { return Ok(cur) };
        if cur.window.contains("Keyboard") || cur.role == "key" {
            return Ok(cur);
        }
        let cy = cur.frame[1] + cur.frame[3] / 2.0;
        if cy < top - 8.0 {
            return Ok(cur);
        }
        // drag the content up from the middle of the visible part above the keyboard
        let room = (top - 120.0).max(80.0);
        let amount = ((cy - (top - 60.0)) / s.screen.1.max(1.0)).clamp(0.08, 0.6);
        let _ = room;
        ax::scroll(inst, "down", amount, None, After::None)?;
        ax::settle(inst, Duration::from_millis(200), Duration::from_millis(1500));
    }
    let s = ax::snapshot(inst, SnapOpts::default())?;
    let cur = s.get(&e.r).cloned().unwrap_or(e);
    match keyboard_top(&s) {
        Some(top) if cur.frame[1] + cur.frame[3] / 2.0 >= top - 8.0 => bail!("@{} {} is under the keyboard and the content does not scroll it up", cur.r, cur.label.as_deref().map(ax::quote).unwrap_or_default()),
        _ => Ok(cur),
    }
}

/// One field of `fill`
#[derive(Debug, Clone, Deserialize)]
pub struct FillField {
    pub target: String,
    pub text: String,
    /// empty it first (default: yes; false appends)
    #[serde(default)]
    pub clear: Option<bool>,
}

/// After the last field: nothing, the Return key, or a tap on a button
#[derive(Debug, Clone)]
pub enum Submit {
    None,
    Return,
    Tap(String),
}

impl Submit {
    /// MCP `submit`: true (Return), a target (a tap), false / absent
    pub fn of(v: &Value) -> Submit {
        match v {
            Value::Bool(true) => Submit::Return,
            Value::String(s) if s == "return" || s == "true" => Submit::Return,
            Value::String(s) if !s.is_empty() && s != "false" => Submit::Tap(s.clone()),
            _ => Submit::None,
        }
    }
}

/// Fills a form: per field, in order, tap it (scrolled into view first), wait for its focus, type (clearing it first
/// unless clear=false); then submit. Stops at the first field that fails, saying which ones were filled.
pub fn fill(inst: &Instance, fields: &[FillField], submit: &Submit, after: After) -> Result<Outcome> {
    anyhow::ensure!(!fields.is_empty(), "fill: fields required ([{{target, text}}, ...])");
    let before = ax::last(inst);
    let mut done: Vec<String> = vec![];
    for (i, fl) in fields.iter().enumerate() {
        let r = type_into(inst, Some(&fl.target), &fl.text, fl.clear.unwrap_or(true), false, false, After::None);
        match r {
            Ok(o) => done.push(format!("{}. {}: {}", i + 1, fl.target, o.did)),
            Err(e) => {
                let so_far = if done.is_empty() { String::new() } else { format!("\nfilled before it:\n{}", done.join("\n")) };
                bail!("fill: field {} ({:?}): {e:#}{so_far}", i + 1, fl.target);
            }
        }
    }
    match submit {
        Submit::None => {}
        Submit::Return => {
            ax::type_text(inst, "", false, true, false, After::None)?;
            done.push("Return pressed".into());
        }
        Submit::Tap(t) => {
            let e = control_el(inst, t)?;
            let e = clear_of_keyboard(inst, e)?;
            let o = ax::tap(inst, &format!("@{}", e.r), 80, After::None)?;
            done.push(o.did);
        }
    }
    Ok(ax::outcome(inst, format!("filled {} field(s):\n{}", fields.len(), done.join("\n")), before, after))
}

// ---------------------------------------------------------------------------------------------------------------------
// drag and set_value

/// A point a target stands for: "x,y" / "x y" in points, or an element's centre (scrolled into view first). Answers
/// the point, the touch space it is in and how to name it.
fn point_of(inst: &Instance, target: &str) -> Result<((f64, f64), ax::Space, String)> {
    if let Target::Point(x, y) = ax::parse_target(target) {
        return Ok(((x, y), ax::front_space(inst), format!("({x:.0},{y:.0})")));
    }
    let (mut e, mut snap) = ax::resolve(inst, target)?;
    if e.offscreen {
        ax::scroll_into_view(inst, &e)?;
        snap = ax::snapshot(inst, SnapOpts::default())?;
        e = snap.get(&e.r).cloned().ok_or_else(|| anyhow::anyhow!("{target:?} scrolled into view, then not found"))?;
    }
    anyhow::ensure!(!e.covered, "@{} is under another app's window", e.r);
    let sp = snap.space_of(&e);
    let c = e.center(sp.size);
    Ok((c, sp, format!("@{} {} {}", e.r, e.role, e.label.as_deref().map(ax::quote).unwrap_or_default()).trim_end().to_string()))
}

/// Drag from one place to another (an element or a point each): press, hold `hold_ms` still (600 by default: long
/// enough to lift a list row, a drag-and-drop item or a home screen icon), move there over `ms`, rest a moment
/// (so the target sees the item over it), lift.
pub fn drag(inst: &Instance, from: &str, to: &str, hold_ms: u64, ms: u64, after: After) -> Result<Outcome> {
    anyhow::ensure!(!matches!(inst.platform.as_str(), "tvos" | "xros"), "drag needs a touchscreen (an Apple TV and a Vision Pro have none)");
    let before = ax::last(inst);
    let (a, sp, wa) = point_of(inst, from)?;
    let (b, _, wb) = point_of(inst, to)?;
    let (na, nb) = (sp.norm(a.0, a.1), sp.norm(b.0, b.1));
    let mut h = ax::hid_for(inst, sp);
    let still = |h: &mut crate::hid::Hid, p: (f32, f32), d: u64| {
        // a still finger keeps reporting (a digitizer does at its scan rate)
        let end = Instant::now() + Duration::from_millis(d);
        while Instant::now() < end {
            std::thread::sleep(Duration::from_millis(30));
            h.touch("move", p.0, p.1, None);
        }
    };
    h.touch("down", na.0, na.1, None);
    still(&mut h, na, hold_ms);
    let n = (ms / 16).max(4);
    for i in 1..=n {
        std::thread::sleep(Duration::from_millis(ms / n));
        // ease in and out: a lifted item follows a finger that starts and stops gently
        let t = i as f32 / n as f32;
        let f = t * t * (3.0 - 2.0 * t);
        h.touch("move", na.0 + (nb.0 - na.0) * f, na.1 + (nb.1 - na.1) * f, None);
    }
    // rest over the target: a drop target sees the item hover (a drop session's proposal) before the lift
    still(&mut h, nb, 600);
    h.touch("up", nb.0, nb.1, None);
    Ok(ax::outcome(inst, format!("dragged {wa} to {wb} ({hold_ms} ms hold, {ms} ms move)"), before, after))
}

/// What a control is and the values it takes (simax `control`)
pub fn control_info(inst: &Instance, e: &El) -> Result<Value> {
    anyhow::ensure!(!e.web, "@{} is web content: tap it or type into it", e.r);
    let v = ax::ask_pid(inst, e.pid, &json!({"op": "control", "oid": e.oid}), Duration::from_secs(4))?;
    if let Some(err) = v["error"].as_str() {
        bail!("@{}: {err}", e.r);
    }
    Ok(v)
}

/// Sets a control to a value in the app (simax `setvalue`): a slider (a number in its range, or "50%"), a switch
/// (on / off), a stepper (a number: one step at a time), a segmented control (a segment's title), a wheel picker (a
/// row's title per wheel: "Apple" or ["10", "30"] / "10, 30"), a date picker (2026-05-01, 2026-05-01T14:30, 14:30), or
/// any adjustable element (increment / decrement until its value reads so). The app hears it as from a touch: the
/// control's value-changed actions, the picker delegate's didSelectRow.
pub fn set_value(inst: &Instance, target: &str, value: &Value, after: After) -> Result<Outcome> {
    let before = ax::last(inst);
    let (e, _) = ax::resolve(inst, target)?;
    anyhow::ensure!(!e.web, "@{} is web content: set_value works on the app's own controls (tap / type into web forms)", e.r);
    let v = match value {
        Value::String(_) | Value::Array(_) => value.clone(),
        Value::Bool(b) => json!(if *b { "on" } else { "off" }),
        Value::Number(n) => json!(n.to_string()),
        _ => bail!("value: a string, number, bool or a list (one per picker wheel)"),
    };
    let r = ax::ask_pid(inst, e.pid, &json!({"op": "setvalue", "oid": e.oid, "value": v}), Duration::from_secs(6))?;
    let what = format!("@{} {} {}", e.r, e.role, e.label.as_deref().map(ax::quote).unwrap_or_default());
    if r["kind"] == "picker" && r["titles"] == false && r["error"].is_string() {
        if let Some(want) = v.as_str() {
            return untitled_wheel(inst, &e, want, &r, before, after);
        }
    }
    if r["kind"] == "stepper" && r["swiftui"] == true && r["error"].is_string() {
        if let Some(want) = v.as_str().and_then(|x| x.trim().parse::<f64>().ok()) {
            return swiftui_stepper(inst, &e, want, before, after);
        }
    }
    if let Some(err) = r["error"].as_str() {
        bail!("set_value {}: {err}", what.trim_end());
    }
    let kind = r["kind"].as_str().unwrap_or("control");
    let shown = |x: &Value| match x {
        Value::String(s) => ax::quote(s),
        Value::Null => "?".into(),
        o => o.to_string(),
    };
    let mut did = match r["steps"].as_i64() {
        Some(n) => format!("stepped {} ({kind}) {n:+} time(s){}", what.trim_end(), r["value"].as_f64().map(|v| format!(", now {v}")).unwrap_or_default()),
        None => format!("set {} ({kind}) from {} to {}", what.trim_end(), shown(&r["was"]), shown(&r["value"])),
    };
    if let Some(n) = r["note"].as_str() {
        did += &format!(" ({n})");
    }
    Ok(ax::outcome(inst, did, before, after))
}

/// A wheel whose rows have no titles (SwiftUI's): each row selected quietly (the app's delegate not told) and read
/// back from the wheel's accessibility value until one reads `want`; then that row selected for real (the delegate
/// hears it, as at the end of a scroll). Starts after the current row and goes round.
fn untitled_wheel(inst: &Instance, e: &El, want: &str, info: &Value, before: Option<Snapshot>, after: After) -> Result<Outcome> {
    let n = info["rows"].as_u64().unwrap_or(0) as usize;
    let cur = info["row"].as_u64().unwrap_or(0) as usize;
    anyhow::ensure!(n > 0, "set_value @{}: the wheel has no rows", e.r);
    let w = want.trim().to_lowercase();
    let read = || ax::snapshot(inst, SnapOpts::default()).ok().and_then(|s| s.get(&e.r).cloned()).and_then(|x| x.value.or(x.label)).unwrap_or_default();
    let was = read();
    let mut seen = vec![];
    let ask = |row: usize, quiet: bool| -> Result<Value> {
        let r = ax::ask_pid(inst, e.pid, &json!({"op": "setvalue", "oid": e.oid, "value": format!("#{row}"), "quiet": quiet}), Duration::from_secs(4))?;
        if let Some(err) = r["error"].as_str() {
            bail!("set_value @{}: {err}", e.r);
        }
        Ok(r)
    };
    for k in 0..n.min(400) {
        let row = (cur + k) % n;
        if k > 0 {
            ask(row, true)?;
            ax::settle(inst, Duration::from_millis(100), Duration::from_millis(800));
        }
        let v = if k == 0 { was.clone() } else { read() };
        let l = v.trim().to_lowercase();
        if !l.is_empty() && (l == w || l.starts_with(&format!("{w},")) || l.starts_with(&w)) {
            ask(row, false)?;
            let did = format!("set @{} (picker wheel, row {row} of {n}) from {} to {}", e.r, ax::quote(&was), ax::quote(&v));
            return Ok(ax::outcome(inst, did, before, after));
        }
        seen.push(v);
    }
    // not there: back where it was, quietly
    let _ = ask(cur, true);
    bail!("set_value @{}: picker wheel: no row {want:?} (rows: {})", e.r, seen.iter().map(|x| ax::quote(x)).collect::<Vec<_>>().join(", "))
}

/// The count a SwiftUI stepper shows in its label ("Count: 4, Increment" -> 4): its first number
fn shown_number(e: &El) -> Option<f64> {
    let t = format!("{} {}", e.label.as_deref().unwrap_or(""), e.value.as_deref().unwrap_or(""));
    let mut num = String::new();
    for c in t.chars() {
        if c.is_ascii_digit() || (c == '.' && !num.is_empty()) || (c == '-' && num.is_empty()) {
            num.push(c);
        } else if !num.is_empty() && num != "-" {
            break;
        } else {
            num.clear();
        }
    }
    num.trim_end_matches('.').parse().ok()
}

/// A SwiftUI Stepper to an absolute count: its UIStepper only says + or -, the count lives in the app. Steps toward
/// the count its label shows (re-read after each round; the step size is learnt from the first round).
fn swiftui_stepper(inst: &Instance, e: &El, want: f64, before: Option<Snapshot>, after: After) -> Result<Outcome> {
    let read = || ax::snapshot(inst, SnapOpts::default()).ok().and_then(|s| s.get(&e.r).cloned()).and_then(|x| shown_number(&x));
    let Some(start) = read().or_else(|| shown_number(e)) else {
        bail!("set_value @{}: a SwiftUI stepper whose label shows no number: its count is the app's; step it with value \"+N\" / \"-N\"", e.r)
    };
    let mut cur = start;
    let mut step = 1.0;
    for _ in 0..6 {
        if (cur - want).abs() < step / 2.0 {
            let did = format!("set @{} (SwiftUI stepper) from {start} to {cur}", e.r);
            return Ok(ax::outcome(inst, did, before, after));
        }
        let n = ((want - cur) / step).round() as i64;
        let r = ax::ask_pid(inst, e.pid, &json!({"op": "setvalue", "oid": e.oid, "value": format!("{n:+}")}), Duration::from_secs(10))?;
        if let Some(err) = r["error"].as_str() {
            bail!("set_value @{}: {err}", e.r);
        }
        ax::settle(inst, Duration::from_millis(150), Duration::from_millis(1500));
        let Some(now) = read() else { bail!("set_value @{}: its label lost its number after stepping", e.r) };
        if now == cur {
            bail!("set_value @{}: the stepper is at {now} and does not go further toward {want} (its range ends there?)", e.r);
        }
        step = ((now - cur) / n as f64).abs().max(f64::EPSILON);
        cur = now;
    }
    bail!("set_value @{}: reached {cur}, not {want}", e.r)
}

// ---------------------------------------------------------------------------------------------------------------------
// expect

/// What `expect` (and `wait_for` with conditions) checks of the elements a target matches
#[derive(Debug, Clone, Default, Deserialize)]
pub struct Expect {
    /// false: no element matches (with other conditions: none matches them all)
    #[serde(default)]
    pub exists: Option<bool>,
    /// the label is this (case and space blind)
    #[serde(default)]
    pub label: Option<String>,
    /// the value is this
    #[serde(default)]
    pub value: Option<String>,
    /// the label or the value contains this
    #[serde(default)]
    pub contains: Option<String>,
    #[serde(default)]
    pub enabled: Option<bool>,
    #[serde(default)]
    pub selected: Option<bool>,
    #[serde(default)]
    pub focused: Option<bool>,
    /// exactly this many elements match (and meet the other conditions)
    #[serde(default)]
    pub count: Option<usize>,
}

fn norm(s: &str) -> String {
    s.chars().map(|c| if c.is_whitespace() { ' ' } else { c }).collect::<String>().trim().to_lowercase()
}

impl Expect {
    /// Read from a tool's arguments (strings "true" / "false" taken for booleans)
    pub fn of(a: &Value) -> Expect {
        let b = |k: &str| a[k].as_bool().or_else(|| a[k].as_str().and_then(|s| s.parse().ok()));
        let t = |k: &str| a[k].as_str().map(String::from).or_else(|| a[k].as_f64().map(|n| n.to_string()));
        Expect { exists: b("exists"), label: t("label"), value: t("value"), contains: t("contains"), enabled: b("enabled"), selected: b("selected"), focused: b("focused"), count: a["count"].as_u64().map(|n| n as usize) }
    }

    /// Any condition beyond "it is there"
    pub fn conditions(&self) -> bool {
        self.label.is_some() || self.value.is_some() || self.contains.is_some() || self.enabled.is_some() || self.selected.is_some() || self.focused.is_some() || self.count.is_some()
    }

    /// Why `e` does not meet the conditions (None: it does)
    fn miss(&self, e: &El) -> Option<String> {
        let l = e.label.as_deref().unwrap_or("");
        let v = e.value.as_deref().unwrap_or("");
        if let Some(x) = &self.label {
            if norm(l) != norm(x) {
                return Some(format!("label is {}, not {}", ax::quote(l), ax::quote(x)));
            }
        }
        if let Some(x) = &self.value {
            if norm(v) != norm(x) {
                return Some(format!("value is {}, not {}", ax::quote(v), ax::quote(x)));
            }
        }
        if let Some(x) = &self.contains {
            if !norm(l).contains(&norm(x)) && !norm(v).contains(&norm(x)) {
                return Some(format!("neither label {} nor value {} contains {}", ax::quote(l), ax::quote(v), ax::quote(x)));
            }
        }
        for (want, have, name) in [(self.enabled, e.enabled, "enabled"), (self.selected, e.selected, "selected"), (self.focused, e.focused, "focused")] {
            if let Some(w) = want {
                if w != have {
                    return Some(format!("{}{name}", if have { "" } else { "not " }));
                }
            }
        }
        None
    }

    fn describe(&self, target: &str) -> String {
        let mut v = vec![];
        if self.exists == Some(false) {
            v.push("gone".to_string());
        }
        if let Some(x) = &self.label {
            v.push(format!("label {}", ax::quote(x)));
        }
        if let Some(x) = &self.value {
            v.push(format!("value {}", ax::quote(x)));
        }
        if let Some(x) = &self.contains {
            v.push(format!("contains {}", ax::quote(x)));
        }
        for (w, n) in [(self.enabled, "enabled"), (self.selected, "selected"), (self.focused, "focused")] {
            if let Some(w) = w {
                v.push(format!("{}{n}", if w { "" } else { "not " }));
            }
        }
        if let Some(n) = self.count {
            v.push(format!("count {n}"));
        }
        format!("{target:?}{}", if v.is_empty() { String::new() } else { format!(" {}", v.join(", ")) })
    }
}

/// The elements on screen a target matches for `expect`: as `find` / tap (text: exact, id / value, prefix, then a part
/// of the label or value), plus, when the
/// conditions are about a field, the field beside a label that matches (`expect "Email" value=...`)
fn expect_matches(snap: &Snapshot, target: &str, x: &Expect) -> Vec<El> {
    let t = ax::parse_target(target);
    // as tap matches: exact, then prefix, then a part of the label (or value), best first
    let mut v: Vec<El> = ax::find_all(snap, &t).into_iter().filter(|e| !e.offscreen && !e.covered).cloned().collect();
    if (x.value.is_some() || x.focused.is_some()) && !v.iter().any(is_field) {
        if let Ok(f) = find_field(snap, target) {
            if is_field(&f) && !f.offscreen && !v.iter().any(|e| e.r == f.r) {
                v.insert(0, f);
            }
        }
    }
    v
}

/// Levenshtein distance over chars, for "nearest by text"
fn distance(a: &str, b: &str) -> usize {
    let (a, b): (Vec<char>, Vec<char>) = (a.chars().collect(), b.chars().collect());
    let mut prev: Vec<usize> = (0..=b.len()).collect();
    for (i, ca) in a.iter().enumerate() {
        let mut cur = vec![i + 1];
        for (j, cb) in b.iter().enumerate() {
            cur.push((prev[j] + (ca != cb) as usize).min(prev[j + 1] + 1).min(cur[j] + 1));
        }
        prev = cur;
    }
    prev[b.len()]
}

/// The elements whose label reads most like `text` (a typo, other words around it)
fn nearest<'a>(snap: &'a Snapshot, text: &str, n: usize) -> Vec<&'a El> {
    let t = norm(text);
    let mut v: Vec<(f64, &El)> = snap
        .elements
        .iter()
        .filter(|e| !e.offscreen && e.layer != "status")
        .filter_map(|e| {
            let l = norm(e.label.as_deref().or(e.value.as_deref()).unwrap_or(""));
            if l.is_empty() {
                return None;
            }
            // the best part of the label of the target's length (a word in a sentence), or the whole
            let words: Vec<&str> = l.split(' ').collect();
            let k = t.split(' ').count().max(1);
            let mut best = distance(&l, &t) as f64 / l.len().max(t.len()) as f64;
            for w in words.windows(k.min(words.len())) {
                let p = w.join(" ");
                best = best.min(distance(&p, &t) as f64 / p.len().max(t.len()) as f64);
            }
            (best < 0.6).then_some((best, e))
        })
        .collect();
    v.sort_by(|a, b| a.0.total_cmp(&b.0));
    v.into_iter().take(n).map(|x| x.1).collect()
}

/// Checks the screen once: pass, and one line saying what was seen
fn expect_once(snap: &Snapshot, target: &str, x: &Expect) -> (bool, String) {
    let m = expect_matches(snap, target, x);
    let meets: Vec<&El> = m.iter().filter(|e| x.miss(e).is_none()).collect();
    let line = |e: &El| e.line(snap.screen);
    if x.exists == Some(false) {
        let left: Vec<&El> = if x.conditions() { meets.clone() } else { m.iter().collect() };
        return (left.is_empty(), if left.is_empty() { "none on screen".into() } else { format!("still there: {}", left.iter().map(|e| line(e)).collect::<Vec<_>>().join("; ")) });
    }
    if let Some(n) = x.count {
        return (meets.len() == n, format!("{} match{}", meets.len(), if meets.is_empty() { String::new() } else { format!(": {}", meets.iter().take(8).map(|e| line(e)).collect::<Vec<_>>().join("; ")) }));
    }
    if let Some(e) = meets.first() {
        return (true, line(e));
    }
    if !m.is_empty() {
        let why: Vec<String> = m.iter().take(5).map(|e| format!("{} ({})", line(e), x.miss(e).unwrap_or_default())).collect();
        return (false, format!("found, but: {}", why.join("; ")));
    }
    let near = match ax::parse_target(target) {
        Target::Text(t) => nearest(snap, &t, 3),
        _ => vec![],
    };
    (false, if near.is_empty() { "nothing matches".into() } else { format!("nothing matches; nearest by text: {}", near.iter().map(|e| line(e)).collect::<Vec<_>>().join("; ")) })
}

/// `expect`: checks the screen; with a timeout, waits (on new frames) for it to become true. Ok: it passed (the answer
/// says what matched); Err: it failed, saying what was found instead (or the nearest by text).
pub fn expect(inst: &Instance, target: &str, x: &Expect, timeout: Duration) -> Result<Outcome> {
    anyhow::ensure!(!target.trim().is_empty(), "expect: target required");
    let t0 = Instant::now();
    let mut ring = Ring::new(&ax::screen_ring(inst));
    loop {
        let seq = ring.seq();
        let snap = ax::snapshot(inst, SnapOpts::default());
        if let Ok(s) = &snap {
            let (ok, what) = expect_once(s, target, x);
            if ok {
                let ms = t0.elapsed().as_millis();
                return Ok(Outcome { did: format!("PASS {} after {ms} ms: {what}", x.describe(target)), screen: Some(s.clone()), diff: None });
            }
            let left = timeout.saturating_sub(t0.elapsed());
            if left.is_zero() {
                bail!("FAIL {}{}: {what}", x.describe(target), if timeout.is_zero() { String::new() } else { format!(" (waited {:.1} s)", timeout.as_secs_f64()) });
            }
        } else if timeout.saturating_sub(t0.elapsed()).is_zero() {
            bail!("FAIL {}: no snapshot: {:#}", x.describe(target), snap.err().map(|e| e.to_string()).unwrap_or_default());
        }
        let left = timeout.saturating_sub(t0.elapsed());
        ring.wait(seq, left.min(Duration::from_secs(1)));
        std::thread::sleep(Duration::from_millis(60).min(left));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn el(oid: &str, frame: [f64; 4]) -> El {
        El { r: "e1".into(), role: "textfield".into(), oid: oid.into(), frame, ..Default::default() }
    }

    #[test]
    fn focus_matches_the_element_or_a_field_inside_it() {
        let f = json!({"focused": true, "text_input": true, "oid": "a1", "inside": ["b2", "c3"], "frame": [10.0, 100.0, 200.0, 30.0], "kind": "textfield"});
        assert!(holds_focus(&el("a1", [0.0, 0.0, 1.0, 1.0]), &f));
        assert!(holds_focus(&el("c3", [0.0, 0.0, 1.0, 1.0]), &f));
        // a SwiftUI node over the field: same place
        assert!(holds_focus(&el("zz", [8.0, 98.0, 204.0, 34.0]), &f));
        // another field below
        assert!(!holds_focus(&el("zz", [8.0, 160.0, 204.0, 34.0]), &f));
        // a button is first responder: no text input
        let b = json!({"focused": true, "text_input": false, "oid": "a1"});
        assert!(!holds_focus(&el("a1", [0.0, 0.0, 1.0, 1.0]), &b));
    }

    fn lab(r: &str, role: &str, label: &str, frame: [f64; 4]) -> El {
        El { r: r.into(), role: role.into(), label: (!label.is_empty()).then(|| label.to_string()), frame, oid: r.into(), app: "a".into(), pid: 1, layer: "app".into(), ..Default::default() }
    }

    #[test]
    fn fields_by_placeholder_or_the_label_beside_them() {
        let s = Snapshot {
            screen: (400.0, 800.0),
            elements: vec![
                lab("e1", "text", "Name", [16.0, 100.0, 60.0, 20.0]),
                lab("e2", "textfield", "", [90.0, 95.0, 290.0, 34.0]),
                lab("e3", "textfield", "Email", [16.0, 140.0, 370.0, 34.0]),
                lab("e4", "text", "City", [16.0, 200.0, 60.0, 20.0]),
                lab("e5", "textfield", "", [90.0, 195.0, 290.0, 34.0]),
                lab("e6", "text", "Phone", [16.0, 250.0, 100.0, 20.0]),
                lab("e7", "textfield", "", [16.0, 276.0, 370.0, 34.0]),
                lab("e8", "text", "Sign up", [16.0, 60.0, 100.0, 30.0]),
            ],
            ..Default::default()
        };
        assert_eq!(find_field(&s, "Email").unwrap().r, "e3");
        assert_eq!(find_field(&s, "Name").unwrap().r, "e2");
        assert_eq!(find_field(&s, "city").unwrap().r, "e5");
        // a label above its field
        assert_eq!(find_field(&s, "Phone").unwrap().r, "e7");
        assert_eq!(find_field(&s, "@e5").unwrap().r, "e5");
        // a title above a row that has its own label is no field's label
        assert_eq!(find_field(&s, "Sign up").unwrap().r, "e8");
        assert!(matches!(Submit::of(&json!(true)), Submit::Return));
        assert!(matches!(Submit::of(&json!("Sign Up")), Submit::Tap(_)));
        assert!(matches!(Submit::of(&json!(false)), Submit::None));
    }

    #[test]
    fn numbers_in_stepper_labels() {
        let mut e = lab("e1", "button", "Count: 4, Increment", [0.0; 4]);
        assert_eq!(shown_number(&e), Some(4.0));
        e.label = Some("Temperature -3.5 degrees".into());
        assert_eq!(shown_number(&e), Some(-3.5));
        e.label = Some("Count, Decrement".into());
        assert_eq!(shown_number(&e), None);
    }

    #[test]
    fn expectations() {
        let mut f = lab("e2", "textfield", "", [90.0, 95.0, 290.0, 34.0]);
        f.value = Some("Ann".into());
        f.focused = true;
        let mut b = lab("e9", "button", "Sign Up", [16.0, 400.0, 100.0, 40.0]);
        b.enabled = false;
        let s = Snapshot {
            screen: (400.0, 800.0),
            elements: vec![lab("e1", "text", "Name", [16.0, 100.0, 60.0, 20.0]), f, b, lab("e3", "text", "Item", [0.0, 500.0, 50.0, 20.0]), lab("e4", "text", "Item", [0.0, 530.0, 50.0, 20.0])],
            ..Default::default()
        };
        let x = |v: Value| Expect::of(&v);
        assert!(expect_once(&s, "Name", &x(json!({"value": "ann"}))).0);
        assert!(expect_once(&s, "Name", &x(json!({"focused": true}))).0);
        assert!(!expect_once(&s, "Name", &x(json!({"value": "Bob"}))).0);
        assert!(expect_once(&s, "Sign Up", &x(json!({"enabled": false}))).0);
        let (ok, why) = expect_once(&s, "Sign Up", &x(json!({"enabled": "true"})));
        assert!(!ok && why.contains("not enabled"), "{why}");
        assert!(expect_once(&s, "Item", &x(json!({"count": 2}))).0);
        assert!(!expect_once(&s, "Item", &x(json!({"count": 3}))).0);
        assert!(expect_once(&s, "Nothing here", &x(json!({"exists": false}))).0);
        let (ok, why) = expect_once(&s, "Sign Upp", &x(json!({})));
        assert!(!ok && why.contains("nearest") && why.contains("Sign Up"), "{why}");
        assert!(expect_once(&s, "Sign", &x(json!({"contains": "up"}))).0);
        // a part of a label, as tap finds it
        assert!(expect_once(&s, "ign U", &x(json!({"enabled": false}))).0);
    }

    #[test]
    fn returns_are_kept() {
        assert_eq!(returns("typed \"x\" into UITextField, Return pressed"), ", Return pressed");
        assert_eq!(returns("typed \"x\" into UITextField"), "");
    }
}
