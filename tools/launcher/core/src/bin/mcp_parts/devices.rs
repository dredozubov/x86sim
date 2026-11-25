//! x86sim-mcp: devices and apps, round 2 (feat/agent-tools-2 D): sim_delete, app_state;
//! app_terminate signal=kill. Kept apart from mcp.rs's own tools so
//! the two merge easily; mcp.rs adds `tools()` to its list and asks `call()` first.
use serde_json::{json, Value};
use x86sim_core::{appstate, ax, devdelete, instance};

/// app_terminate's signal (the tool itself is mcp.rs's): added to its schema
pub fn extend_terminate(t: &mut Value) {
    if t["name"] == "app_terminate" {
        t["inputSchema"]["properties"]["signal"] = json!({"type": "string", "enum": ["term", "kill"], "description": "term (default): ask the app to quit, as simctl terminate; kill: SIGKILL its process, as a crash would end it (no state saved, its scene is gone)"});
        if let Some(d) = t["description"].as_str() {
            t["description"] = json!(format!("{d} signal=kill ends its process with SIGKILL instead, as a crash would."));
        }
    }
}

pub fn tools(_phone: &Value) -> Vec<Value> {
    vec![
        json!({"name": "sim_delete", "description": "Delete a device (as simctl delete): its folder, its state and run folders, its Darling prefix and the prefix's overlay work folder, its frame ring. phone is required (by name). A running device is refused unless stop=true (it is stopped first); the default device is never deleted. The overlay's work folder holds a root-owned folder: privileged=true removes it through pkexec (a password dialog on the user's desktop, as the launcher's setup); without it, it is left and the answer says how to remove it.",
               "inputSchema": {"type": "object", "properties": {"phone": {"type": "string"}, "stop": {"type": "boolean"}, "privileged": {"type": "boolean"}}, "required": ["phone"]}}),
        json!({"name": "app_state", "description": "What an app is doing: installed or not, running or not, its process(es): pid (inside the phone, as app_launch answers), state (foreground, background, suspended; running for a process without UI), memory (MB), CPU % now, uptime; and how its last run ended (launchd's exit line: exit(code), a signal, jetsam, and when). Without bundle_id: every app that is running.",
               "inputSchema": {"type": "object", "properties": {"phone": _phone, "bundle_id": {"type": "string"}}}}),
    ]
}

fn is_ours(name: &str, a: &Value) -> bool {
    matches!(name, "sim_delete" | "app_state") || (name == "app_terminate" && a["signal"].as_str() == Some("kill"))
}

/// Some(json) for the tools of this module, None for others.
pub fn call(name: &str, a: &Value, phone: &dyn Fn() -> anyhow::Result<instance::Instance>) -> Option<anyhow::Result<Value>> {
    if !is_ours(name, a) {
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
            "app_terminate" => {
                let inst = phone()?;
                let b = a["bundle_id"].as_str().unwrap_or("");
                let before = ax::last(&inst);
                let pids = appstate::kill_app(&inst, b)?;
                let o = ax::outcome(&inst, format!("killed {b} (SIGKILL, pid {})", pids.iter().map(|p| p.to_string()).collect::<Vec<_>>().join(", ")), before, ax::After::parse(a["after"].as_str()));
                Ok(json!({"phone": inst.name, "killed": pids, "text": o.text()}))
            }
            _ => unreachable!(),
        }
    })())
}
