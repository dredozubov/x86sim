//! x86sim-mcp: devices and apps, round 2 (feat/agent-tools-2 D): sim_delete. Kept apart from mcp.rs's own tools so
//! the two merge easily; mcp.rs adds `tools()` to its list and asks `call()` first.
use serde_json::{json, Value};
use x86sim_core::{devdelete, instance};

pub fn tools(_phone: &Value) -> Vec<Value> {
    vec![
        json!({"name": "sim_delete", "description": "Delete a device (as simctl delete): its folder, its state and run folders, its Darling prefix and the prefix's overlay work folder, its frame ring. phone is required (by name). A running device is refused unless stop=true (it is stopped first); the default device is never deleted. The overlay's work folder holds a root-owned folder: privileged=true removes it through pkexec (a password dialog on the user's desktop, as the launcher's setup); without it, it is left and the answer says how to remove it.",
               "inputSchema": {"type": "object", "properties": {"phone": {"type": "string"}, "stop": {"type": "boolean"}, "privileged": {"type": "boolean"}}, "required": ["phone"]}}),
    ]
}

fn is_ours(name: &str) -> bool {
    matches!(name, "sim_delete")
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
            _ => unreachable!(),
        }
    })())
}
