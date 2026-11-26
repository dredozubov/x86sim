//! x86sim-mcp: the GPU a device renders on (core gpu.rs; BootSettings::gpu): sim_gpu lists the host's GPUs and sets a
//! device's. Kept apart from mcp.rs's own tools so the two merge easily.
use serde_json::{json, Value};
use x86sim_core::{gpu, instance};

pub fn tools(phone: &Value) -> Vec<Value> {
    vec![json!({"name": "sim_gpu", "description": "The GPU a device renders on (Metal runs on Vulkan through the GPU helper, mtlvk). Without gpu: the host's GPUs (name, type discrete / integrated / cpu, driver, id), the device's setting, and the GPU it renders on now while running. With gpu: sets it, applied at the device's next start (sim_restart): auto (the helper's own pick: a discrete GPU first), cpu (no GPU: everything on the CPU through lavapipe, slow; needs lavapipe installed), or a GPU by id, list index or part of its name (\"nvidia\", \"amd\", \"5090\"). Devices on the same GPU share one helper; a device on another GPU gets its own.",
           "inputSchema": {"type": "object", "properties": {"phone": phone, "gpu": {"type": "string", "description": "auto | cpu | a GPU's id, index or part of its name"}}}})]
}

/// Some(json) for sim_gpu, None for other tools
pub fn call(name: &str, a: &Value, phone: &dyn Fn() -> anyhow::Result<instance::Instance>) -> Option<anyhow::Result<Value>> {
    if name != "sim_gpu" {
        return None;
    }
    Some((|| -> anyhow::Result<Value> {
        let inst = phone()?;
        let list = gpu::list()?;
        let mut changed = false;
        if let Some(w) = a["gpu"].as_str().filter(|w| !w.trim().is_empty()) {
            let before = instance::load_settings(&inst.dir).gpu;
            changed = gpu::set(&inst.dir, w)? != before;
        }
        let setting = instance::load_settings(&inst.dir).gpu;
        let sum = instance::summaries_unprobed(0).into_iter().find(|s| s.id == inst.id);
        let running = sum.as_ref().is_some_and(|s| s.state != "off");
        let now = sum.as_ref().and_then(|s| s.gpu_name.clone());
        let label = gpu::setting_label(&setting, &list);
        let mut text = format!("{}: GPU {label}", inst.name);
        if let Some(n) = &now {
            text += &format!("; renders on {n} now");
        }
        if changed && running {
            text += "; restart to apply (sim_restart)";
        } else if changed {
            text += "; applies at the next start";
        }
        Ok(json!({
            "phone": inst.name, "gpu": setting, "gpu_label": label, "renders_on": now, "running": running,
            "changed": changed, "needs_restart": changed && running,
            "gpus": list.iter().filter(|g| g.usable).map(|g| json!({"index": g.index, "id": if g.kind == "cpu" { "cpu".to_string() } else { g.id.clone() }, "name": g.name, "label": g.label(), "type": g.kind, "driver": g.driver, "auto": g.auto})).collect::<Vec<_>>(),
            "text": text,
        }))
    })())
}
