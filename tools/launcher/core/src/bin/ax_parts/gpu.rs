//! x86sim gpu: the GPU a device renders on (core gpu.rs; BootSettings::gpu, applied at the device's next start).
use anyhow::{bail, Result};
use x86sim_core::{gpu, instance};

pub const USAGE: &str = "  gpu [list] [--json]                  the host's GPUs (name, type, driver, id) and the device's GPU
  gpu set auto|cpu|NAME|ID|INDEX       the device's GPU, at its next start: auto (the GPU helper's pick), cpu (no
                                       GPU: lavapipe, everything on the CPU), or a GPU by part of its name (nvidia,
                                       amd, 5090), id or list index; devices on the same GPU share one helper";

/// `args`: what follows `gpu`; `phone`: the device (a list works without one)
pub fn run(phone: Option<instance::Instance>, mut args: Vec<String>) -> Result<()> {
    let json = args.iter().any(|a| a == "--json");
    args.retain(|a| a != "--json");
    let l = gpu::list()?;
    match args.first().map(String::as_str) {
        None | Some("list" | "ls") => {
            let setting = phone.as_ref().map(|i| instance::load_settings(&i.dir).gpu);
            let now = phone.as_ref().and_then(|i| instance::summaries_unprobed(0).into_iter().find(|s| s.id == i.id)).and_then(|s| s.gpu_name);
            if json {
                println!("{}", serde_json::to_string_pretty(&serde_json::json!({"gpus": l, "device": phone.as_ref().map(|i| &i.name), "gpu": setting, "renders_on": now}))?);
                return Ok(());
            }
            let chosen = setting.as_deref().map(|s| gpu::resolve(s, &l).map(|g| g.index));
            println!("   #  type        name");
            for g in l.iter().filter(|g| g.usable) {
                let mark = if chosen == Some(Some(g.index)) { "*" } else { " " };
                let id = if g.kind == "cpu" { "cpu".to_string() } else { g.id.clone() };
                println!(" {mark} {}  {:<10}  {}{}\n      {}  ({})", g.index, g.kind, gpu::short_name(&g.name), if g.auto { "  [auto]" } else { "" }, id, g.driver);
            }
            if !l.iter().any(|g| g.usable && g.kind == "cpu") {
                println!("   (cpu: install lavapipe for a device with no GPU)");
            }
            if let (Some(i), Some(s)) = (&phone, &setting) {
                println!("{}: {}{}", i.name, gpu::setting_label(s, &l), now.map(|n| format!(", renders on {n} now")).unwrap_or_default());
            }
            Ok(())
        }
        Some("set") => {
            if args.len() < 2 {
                bail!("gpu set auto|cpu|NAME|ID|INDEX");
            }
            let Some(inst) = phone else { bail!("say which device (--phone NAME)") };
            let before = instance::load_settings(&inst.dir).gpu;
            let v = gpu::set(&inst.dir, &args[1..].join(" "))?;
            let running = instance::summaries_unprobed(0).into_iter().find(|s| s.id == inst.id).is_some_and(|s| s.state != "off");
            let tail = if v == before { "" } else if running { " (restart to apply)" } else { " (at its next start)" };
            println!("{}: GPU {}{tail}", inst.name, gpu::setting_label(&v, &l));
            Ok(())
        }
        Some(c) => bail!("gpu {c}: list or set\n{USAGE}"),
    }
}
