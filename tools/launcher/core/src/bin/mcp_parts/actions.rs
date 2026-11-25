//! x86sim-mcp: the agent tools' actions of round 2 (x86sim_core::axact): fill. Kept apart from mcp.rs's own tools so
//! the two merge easily; mcp.rs adds `tools()` to its list and asks `call()` first.
use serde_json::{json, Value};
use x86sim_core::{ax, axact, instance};

pub fn tools(phone: &Value) -> Vec<Value> {
    let after = json!({"type": "string", "enum": ["full", "diff", "none"], "description": "what to answer with after the action settled: the whole screen (default), only what changed, or nothing"});
    vec![
        json!({"name": "fill", "description": "Fill a form in one call: for each field in order, scroll it into view, tap it, wait until it has the focus, type its text (the field is emptied first unless clear=false; secure fields work). A field's target is a ref, id:..., or text: the field's label or placeholder, or a label written beside it (left of it on the same row, or just above it). submit: true presses Return after the last field, a target (e.g. \"Sign Up\") taps it. Answers each field's result (the value it holds now) and the screen after; stops at the first field that fails.",
               "inputSchema": {"type": "object", "properties": {"phone": phone,
                   "fields": {"type": "array", "items": {"type": "object", "properties": {"target": {"type": "string"}, "text": {"type": "string"}, "clear": {"type": "boolean"}}, "required": ["target", "text"]}},
                   "submit": {"description": "true: press Return after the last field; a target (text, @ref, id:...): tap it", "type": ["boolean", "string"]},
                   "after": after}, "required": ["fields"]}}),
    ]
}

fn is_ours(name: &str) -> bool {
    matches!(name, "fill")
}

/// Some(text) for the tools of this module, None for others.
pub fn call(name: &str, a: &Value, phone: &dyn Fn() -> anyhow::Result<instance::Instance>) -> Option<anyhow::Result<String>> {
    if !is_ours(name) {
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
            _ => unreachable!(),
        }
    })())
}
