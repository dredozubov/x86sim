//! Agent actions, round 2 (docs/protocols/SIMAX.md `focus`): `type` into the field that was tapped. Kept apart from
//! ax.rs (snapshot, tap, type_text, ...), whose pieces it builds on.
//!
//! A tap moves the focus a moment after the touch (UIKit's first responder change, WebKit's focus in its content
//! process): text typed right away went into the field focused before, or a web field dropped it. `type_into` taps
//! the target, then waits on frames (up to 2 s) until simax says that element, or a text field inside it, is the first
//! responder, types, and checks the text landed there. `fill` does that for several fields; field targets also match
//! a placeholder and the label beside a field.
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
            let (e, _) = ax::resolve(inst, t)?;
            let e = clear_of_keyboard(inst, e)?;
            let o = ax::tap(inst, &format!("@{}", e.r), 80, After::None)?;
            done.push(o.did);
        }
    }
    Ok(ax::outcome(inst, format!("filled {} field(s):\n{}", fields.len(), done.join("\n")), before, after))
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
    fn returns_are_kept() {
        assert_eq!(returns("typed \"x\" into UITextField, Return pressed"), ", Return pressed");
        assert_eq!(returns("typed \"x\" into UITextField"), "");
    }
}
