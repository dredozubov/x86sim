//! x86sim-mcp: the agent tools' actions of round 2 (x86sim_core::axact): fill, drag, set_value, expect; wait_for with expect's conditions. Kept apart from mcp.rs's own tools so
//! the two merge easily; mcp.rs adds `tools()` to its list and asks `call()` first.
use serde_json::{json, Value};
use x86sim_core::{ax, axact, instance};

/// wait_for's conditions (the tool itself is mcp.rs's): added to its schema
pub fn extend_wait_for(t: &mut Value) {
    if t["name"] == "wait_for" {
        for (k, ty) in [("value", "string"), ("label", "string"), ("contains", "string"), ("enabled", "boolean"), ("selected", "boolean"), ("focused", "boolean"), ("count", "integer")] {
            t["inputSchema"]["properties"][k] = json!({"type": ty});
        }
        if let Some(d) = t["description"].as_str() {
            t["description"] = json!(format!("{d} Conditions as expect's (value, label, contains, enabled, selected, focused, count): waits until an element meets them all (gone=true: until none does); a timeout is an error saying what was there instead."));
        }
    }
}

pub fn tools(phone: &Value) -> Vec<Value> {
    let after = json!({"type": "string", "enum": ["full", "diff", "none"], "description": "what to answer with after the action settled: the whole screen (default), only what changed, or nothing"});
    vec![
        json!({"name": "fill", "description": "Fill a form in one call: for each field in order, scroll it into view, tap it, wait until it has the focus, type its text (the field is emptied first unless clear=false; secure fields work). A field's target is a ref, id:..., or text: the field's label or placeholder, or a label written beside it (left of it on the same row, or just above it). submit: true presses Return after the last field, a target (e.g. \"Sign Up\") taps it. Answers each field's result (the value it holds now) and the screen after; stops at the first field that fails.",
               "inputSchema": {"type": "object", "properties": {"phone": phone,
                   "fields": {"type": "array", "items": {"type": "object", "properties": {"target": {"type": "string"}, "text": {"type": "string"}, "clear": {"type": "boolean"}}, "required": ["target", "text"]}},
                   "submit": {"description": "true: press Return after the last field; a target (text, @ref, id:...): tap it", "type": ["boolean", "string"]},
                   "after": after}, "required": ["fields"]}}),
        json!({"name": "drag", "description": "Drag from one place to another and drop: press, hold still hold_ms (default 600: long enough to lift a list row for reordering, a drag-and-drop item, a home screen icon), move over ms (default 600), rest, lift. from / to: a target (@ref, id:..., label text: its centre) or \"x,y\" in points. Answers the screen after. (For a precise scroll use scroll; for a slider set_value.)",
               "inputSchema": {"type": "object", "properties": {"phone": phone, "from": {"type": "string"}, "to": {"type": "string"}, "hold_ms": {"type": "integer"}, "ms": {"type": "integer"}, "after": after}, "required": ["from", "to"]}}),
        json!({"name": "set_value", "description": "Set a control to a value, whatever control it is, the way the app hears a touch (its value-changed actions, a picker's delegate): slider (a number in its range or \"50%\"), switch (on / off, true / false), stepper (a number; stepped one step at a time), segmented control (a segment's title), wheel picker (a row's title; several wheels: a list or \"10, 30\", \"\" keeps a wheel), date picker (2026-05-01, 2026-05-01T14:30, or a time 14:30), anything else adjustable (incremented / decremented until its value reads so). An error says what the control is and which values it takes. target: @ref, id:..., label text. info=true only describes the control (range, segments, rows).",
               "inputSchema": {"type": "object", "properties": {"phone": phone, "target": {"type": "string"}, "value": {"type": ["string", "number", "boolean", "array"]}, "info": {"type": "boolean"}, "after": after}, "required": ["target"]}}),
        json!({"name": "expect", "description": "Check the screen: an element matching target (@ref, id:..., label text: exact, id / value, prefix) is there (exists, default true; false: none is) and meets every condition given: label (equals), value (equals), contains (in label or value), enabled, selected, focused, count (exactly that many match). A condition about a field (value, focused) also finds the field beside a matching label. Answers PASS with the element; FAIL (an error) with what was found instead: the matching elements and which condition each misses, or the elements nearest by text. timeout (seconds, default 0) waits on new frames for it to become true.",
               "inputSchema": {"type": "object", "properties": {"phone": phone, "target": {"type": "string"}, "exists": {"type": "boolean"}, "label": {"type": "string"}, "value": {"type": "string"}, "contains": {"type": "string"},
                   "enabled": {"type": "boolean"}, "selected": {"type": "boolean"}, "focused": {"type": "boolean"}, "count": {"type": "integer"}, "timeout": {"type": "number"}}, "required": ["target"]}}),
    ]
}

fn is_ours(name: &str, a: &Value) -> bool {
    matches!(name, "fill" | "drag" | "set_value" | "expect")
        // wait_for with a condition beyond "on screen" / "gone" is expect with a timeout
        || (name == "wait_for" && axact::Expect::of(a).conditions())
}

/// Some(text) for the tools of this module, None for others.
pub fn call(name: &str, a: &Value, phone: &dyn Fn() -> anyhow::Result<instance::Instance>) -> Option<anyhow::Result<String>> {
    if !is_ours(name, a) {
        return None;
    }
    let inst = match phone() {
        Ok(i) => i,
        Err(e) => return Some(Err(e)),
    };
    let after = ax::After::parse(a["after"].as_str());
    Some((|| -> anyhow::Result<String> {
        match name {
            "fill" => {
                let fields: Vec<axact::FillField> = serde_json::from_value(a["fields"].clone()).map_err(|e| anyhow::anyhow!("fields: [{{target, text, clear?}}, ...]: {e}"))?;
                Ok(axact::fill(&inst, &fields, &axact::Submit::of(&a["submit"]), after)?.text())
            }
            "drag" => {
                let (from, to) = (a["from"].as_str().unwrap_or(""), a["to"].as_str().unwrap_or(""));
                anyhow::ensure!(!from.is_empty() && !to.is_empty(), "from and to required (a target or \"x,y\")");
                let o = axact::drag(&inst, from, to, a["hold_ms"].as_u64().unwrap_or(600).min(10_000), a["ms"].as_u64().unwrap_or(600).clamp(50, 10_000), after)?;
                Ok(o.text())
            }
            "set_value" => {
                let t = a["target"].as_str().unwrap_or("");
                if a["info"].as_bool().unwrap_or(false) || a["value"].is_null() {
                    let (e, _) = ax::resolve(&inst, t)?;
                    return Ok(format!("{}\n{}", e.line((0.0, 0.0)), serde_json::to_string_pretty(&axact::control_info(&inst, &e)?)?));
                }
                Ok(axact::set_value(&inst, t, &a["value"], after)?.text())
            }
            "expect" => {
                let t = std::time::Duration::from_secs_f64(a["timeout"].as_f64().unwrap_or(0.0).clamp(0.0, 600.0));
                Ok(axact::expect(&inst, a["target"].as_str().unwrap_or(""), &axact::Expect::of(a), t)?.text())
            }
            "wait_for" => {
                let mut x = axact::Expect::of(a);
                if a["gone"].as_bool().unwrap_or(false) {
                    x.exists = Some(false);
                }
                let t = std::time::Duration::from_secs_f64(a["timeout"].as_f64().unwrap_or(20.0).clamp(0.1, 600.0));
                Ok(axact::expect(&inst, a["target"].as_str().unwrap_or(""), &x, t)?.text())
            }
            _ => unreachable!(),
        }
    })())
}
