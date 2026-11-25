//! Agent actions, round 2 (docs/protocols/SIMAX.md `focus`): `type` into the field that was tapped. Kept apart from
//! ax.rs (snapshot, tap, type_text, ...), whose pieces it builds on.
//!
//! A tap moves the focus a moment after the touch (UIKit's first responder change, WebKit's focus in its content
//! process): text typed right away went into the field focused before, or a web field dropped it. `type_into` taps
//! the target, then waits on frames (up to 2 s) until simax says that element, or a text field inside it, is the first
//! responder, types, and checks the text landed there.
use crate::ax::{self, After, El, Outcome, SnapOpts};
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
    let (e0, _) = ax::resolve(inst, target)?;
    // already focused (a second `type` into the same field): no tap, which would move the caret
    if let Some(f) = focus_of(inst, e0.pid).filter(|f| !e0.web && holds_focus(&e0, f)) {
        return Ok((e0, f));
    }
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

    #[test]
    fn returns_are_kept() {
        assert_eq!(returns("typed \"x\" into UITextField, Return pressed"), ", Return pressed");
        assert_eq!(returns("typed \"x\" into UITextField"), "");
    }
}
