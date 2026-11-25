//! x86sim-mcp: devices and apps, round 2 (feat/agent-tools-2 D): sim_delete, app_state. Kept apart from mcp.rs's own tools so
//! the two merge easily; mcp.rs adds `tools()` to its list and asks `call()` first.
use serde_json::{json, Value};
use x86sim_core::{appstate, devdelete, instance};

pub fn tools(_phone: &Value) -> Vec<Value> {
    vec![
        json!({"name": "sim_delete", "description": "Delete a device (as simctl delete): its folder, its state and run folders, its Darling prefix and the prefix's overlay work folder, its frame ring. phone is required (by name). A running device is refused unless stop=true (it is stopped first); the default device is never deleted. The overlay's work folder holds a root-owned folder: privileged=true removes it through pkexec (a password dialog on the user's desktop, as the launcher's setup); without it, it is left and the answer says how to remove it.",
               "inputSchema": {"type": "object", "properties": {"phone": {"type": "string"}, "stop": {"type": "boolean"}, "privileged": {"type": "boolean"}}, "required": ["phone"]}}),
        json!({"name": "app_state", "description": "What an app is doing: installed or not, running or not, its process(es): pid (inside the phone, as app_launch answers), state (foreground, background, suspended; running for a process without UI), memory (MB), CPU % now, uptime; and how its last run ended (launchd's exit line: exit(code), a signal, jetsam, and when). Without bundle_id: every app that is running.",
               "inputSchema": {"type": "object", "properties": {"phone": _phone, "bundle_id": {"type": "string"}}}}),
    ]
}

fn is_ours(name: &str) -> bool {
    matches!(name, "sim_delete" | "app_state")
}

/// Some(json) for the tools of this module, None for others.
pub fn call(name: &str, a: &Value, phone: &dyn Fn() -> anyhow::Result<instance::Instance>) -> Option<anyhow::Result<Value>> {
    if !is_ours(name) {
        return None;
    }
    Some((|| -> anyhow::Result<Value> {
        match name {
            "sim_delete" => {
                // destructive: only the device the caller named, never "the only running one"
                anyhow::ensure!(a["phone"].as_str().or(a["device"].as_str()).is_some_and(|s| !s.is_empty()), "sim_delete needs phone: the device's name (phones_list)");
                let inst = phone()?;
                let d = devdelete::delete(&inst, a["stop"].as_bool().unwrap_or(false), a["privileged"].as_bool().unwrap_or(false))?;
                Ok(json!({"deleted": d.name, "stopped": d.stopped, "removed": d.removed, "freed_bytes": d.freed_bytes, "left": d.left, "text": d.text()}))
            }
            "app_state" => {
                let inst = phone()?;
                let b = a["bundle_id"].as_str().filter(|b| !b.is_empty());
                let v = appstate::app_state(&inst, b)?;
                let text = if v.is_empty() { "no app running".to_string() } else { v.iter().map(|x| x.text()).collect::<Vec<_>>().join("\n") };
                Ok(json!({"phone": inst.name, "apps": v, "text": text}))
            }
            _ => unreachable!(),
        }
    })())
}
