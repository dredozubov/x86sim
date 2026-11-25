//! x86sim-mcp: the device services simctl offers besides apps and the screen: simulated location, app permissions
//! (privacy), remote notifications (push) and the Photos library (addmedia). Kept apart from mcp.rs's own tools so
//! the two merge easily; mcp.rs adds `tools()` to its list and asks `call()` first.
//! Each runs cli/x86sim (cli/libexec/simctl.py) with the phone's dir, as the CLI's commands of the same names.
use serde_json::{json, Value};
use std::process::{Command, Stdio};
use x86sim_core::{aot::repo_root, instance};

/// simctl privacy's services (cli/libexec/simctl.py PRIVACY_SERVICES)
pub const PRIVACY_SERVICES: &[&str] = &[
    "all", "location", "location-always", "calendar", "contacts", "contacts-limited", "photos", "photos-add", "media-library", "microphone", "motion", "reminders", "siri",
    "camera", "homekit",
];

pub fn tools(phone: &Value) -> Vec<Value> {
    vec![
        json!({"name": "sim_location", "description": "The device's simulated location (as simctl location; Core Location apps such as Maps see it): set (lat, lon), clear (back to none), list (the built-in scenarios), scenario (run one by name, e.g. \"City Run\", \"Freeway Drive\"), route (move along waypoints [[lat, lon], ...] at speed m/s, default 20, updating every interval s or every distance m).",
               "inputSchema": {"type": "object", "properties": {"phone": phone, "action": {"type": "string", "enum": ["set", "clear", "list", "scenario", "route"]},
                   "lat": {"type": "number", "minimum": -90, "maximum": 90}, "lon": {"type": "number", "minimum": -180, "maximum": 180}, "name": {"type": "string", "description": "scenario name (action scenario)"},
                   "points": {"type": "array", "items": {"type": "array", "items": {"type": "number"}, "minItems": 2, "maxItems": 2}, "description": "waypoints [[lat, lon], ...] (action route, at least two)"},
                   "speed": {"type": "number"}, "interval": {"type": "number"}, "distance": {"type": "number"}}, "required": ["action"]}}),
        json!({"name": "sim_privacy", "description": "Grant, revoke or reset an app's permission without the system prompt (as simctl privacy): grant before the app asks and it never shows the alert. reset without bundle_id resets the service for every app.",
               "inputSchema": {"type": "object", "properties": {"phone": phone, "action": {"type": "string", "enum": ["grant", "revoke", "reset"]}, "service": {"type": "string", "enum": PRIVACY_SERVICES},
                   "bundle_id": {"type": "string"}}, "required": ["action", "service"]}}),
        json!({"name": "sim_push", "description": "Send a simulated remote notification to an app (as simctl push): payload is the APNs JSON object with an \"aps\" dictionary, e.g. {\"aps\": {\"alert\": {\"title\": \"Hi\", \"body\": \"Text\"}, \"badge\": 1}}. The banner shows when the app allows notifications (it asked and was allowed: sim_privacy cannot grant this one). bundle_id defaults to the payload's \"Simulator Target Bundle\".",
               "inputSchema": {"type": "object", "properties": {"phone": phone, "bundle_id": {"type": "string"}, "payload": {"type": "object"}}, "required": ["payload"]}}),
        json!({"name": "sim_addmedia", "description": "Add photos and videos (files on this machine: jpg, png, heic, gif, mov, mp4, ...) to the device's Photos library (as simctl addmedia).",
               "inputSchema": {"type": "object", "properties": {"phone": phone, "paths": {"type": "array", "items": {"type": "string"}, "minItems": 1}}, "required": ["paths"]}}),
    ]
}

/// cli/x86sim CMD DEV ARGS with `input` on stdin, bounded as mcp_simctl's commands
fn x86sim(dev: &std::path::Path, cmd: &str, args: &[String], input: Option<&[u8]>) -> anyhow::Result<String> {
    let mut child = Command::new(repo_root().join("cli/x86sim"))
        .arg(cmd)
        .arg(dev)
        .args(args)
        .current_dir(repo_root())
        .stdin(if input.is_some() { Stdio::piped() } else { Stdio::null() })
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;
    if let (Some(data), Some(mut si)) = (input, child.stdin.take()) {
        use std::io::Write;
        si.write_all(data)?;
    }
    let out = crate::mcp_simctl::wait_bounded(child, std::time::Duration::from_secs(180)).map_err(|e| anyhow::anyhow!("x86sim {cmd}: {e}"))?;
    let text = String::from_utf8_lossy(&out.stdout).trim_end().to_string();
    let err = String::from_utf8_lossy(&out.stderr).trim().to_string();
    anyhow::ensure!(out.status.success(), "x86sim {cmd}: {}", if err.is_empty() { text } else { err });
    Ok(text)
}

fn latlon(lat: Option<f64>, lon: Option<f64>) -> anyhow::Result<String> {
    let (Some(lat), Some(lon)) = (lat, lon) else { anyhow::bail!("lat and lon required") };
    anyhow::ensure!(lat.is_finite() && (-90.0..=90.0).contains(&lat), "lat {lat}: -90 .. 90");
    anyhow::ensure!(lon.is_finite() && (-180.0..=180.0).contains(&lon), "lon {lon}: -180 .. 180");
    Ok(format!("{lat},{lon}"))
}

/// cli/x86sim location's arguments for a call
pub fn location_args(a: &Value) -> anyhow::Result<Vec<String>> {
    Ok(match a["action"].as_str().unwrap_or("") {
        "set" => vec!["set".into(), latlon(a["lat"].as_f64(), a["lon"].as_f64())?],
        "clear" => vec!["clear".into()],
        "list" => vec!["list".into()],
        "scenario" => {
            let n = a["name"].as_str().unwrap_or("").trim();
            anyhow::ensure!(!n.is_empty() && !n.starts_with('-') && !n.contains(','), "name: a scenario (action list shows them)");
            vec!["run".into(), n.into()]
        }
        "route" => {
            let pts = a["points"].as_array().cloned().unwrap_or_default();
            anyhow::ensure!(pts.len() >= 2, "points: at least two [lat, lon] waypoints");
            let mut v = vec!["start".to_string()];
            for k in ["speed", "interval", "distance"] {
                if let Some(x) = a[k].as_f64() {
                    anyhow::ensure!(x.is_finite() && x > 0.0, "{k} {x}: a positive number");
                    v.push(format!("--{k}={x}"));
                }
            }
            for p in pts {
                v.push(latlon(p[0].as_f64(), p[1].as_f64())?);
            }
            v
        }
        o => anyhow::bail!("action {o:?}: set, clear, list, scenario or route"),
    })
}

/// cli/x86sim privacy's arguments for a call
pub fn privacy_args(a: &Value) -> anyhow::Result<Vec<String>> {
    let act = a["action"].as_str().unwrap_or("");
    anyhow::ensure!(matches!(act, "grant" | "revoke" | "reset"), "action {act:?}: grant, revoke or reset");
    let svc = a["service"].as_str().unwrap_or("");
    anyhow::ensure!(PRIVACY_SERVICES.contains(&svc), "service {svc:?}: one of {}", PRIVACY_SERVICES.join(", "));
    let bid = a["bundle_id"].as_str().map(str::trim).filter(|b| !b.is_empty());
    anyhow::ensure!(act == "reset" || bid.is_some(), "{act} needs bundle_id");
    if let Some(b) = bid {
        anyhow::ensure!(crate::mcp_simctl::valid_bundle_id(b), "bundle_id {b:?} is not a bundle id (com.example.App)");
    }
    let mut v = vec![act.to_string(), svc.to_string()];
    v.extend(bid.map(String::from));
    Ok(v)
}

/// The target app and the payload's bytes of a push
pub fn push_args(a: &Value) -> anyhow::Result<(String, Vec<u8>)> {
    let p = &a["payload"];
    let p = match p.as_str() {
        // a client that sends the object as a JSON string
        Some(s) => serde_json::from_str::<Value>(s).map_err(|e| anyhow::anyhow!("payload: not JSON: {e}"))?,
        None => p.clone(),
    };
    anyhow::ensure!(p.is_object(), "payload: a JSON object with an \"aps\" dictionary");
    anyhow::ensure!(p["aps"].is_object(), "payload: no \"aps\" dictionary (e.g. {{\"aps\": {{\"alert\": \"Hello\"}}}})");
    let bid = a["bundle_id"].as_str().or(p["Simulator Target Bundle"].as_str()).map(str::trim).unwrap_or("");
    anyhow::ensure!(!bid.is_empty(), "bundle_id required (or \"Simulator Target Bundle\" in the payload)");
    anyhow::ensure!(crate::mcp_simctl::valid_bundle_id(bid), "bundle_id {bid:?} is not a bundle id (com.example.App)");
    Ok((bid.to_string(), serde_json::to_vec(&p)?))
}

fn is_ours(name: &str) -> bool {
    matches!(name, "sim_location" | "sim_privacy" | "sim_push" | "sim_addmedia")
}

/// Some(result) for the tools of this module, None for others.
pub fn call(name: &str, a: &Value, phone: &dyn Fn() -> anyhow::Result<instance::Instance>) -> Option<anyhow::Result<Value>> {
    if !is_ours(name) {
        return None;
    }
    Some((|| {
        let inst = phone()?;
        let d = inst.dir.clone();
        Ok(match name {
            "sim_location" => {
                let v = location_args(a)?;
                let out = x86sim(&d, "location", &v, None)?;
                match v[0].as_str() {
                    "list" => json!({"phone": inst.name, "scenarios": out.lines().map(str::trim).filter(|l| !l.is_empty()).collect::<Vec<_>>()}),
                    "set" => json!({"phone": inst.name, "location": {"lat": a["lat"], "lon": a["lon"]}}),
                    "clear" => json!({"phone": inst.name, "location": null}),
                    _ => json!({"phone": inst.name, "moving": true, "answer": out}),
                }
            }
            "sim_privacy" => {
                let v = privacy_args(a)?;
                x86sim(&d, "privacy", &v, None)?;
                json!({"phone": inst.name, "action": v[0], "service": v[1], "bundle_id": v.get(2)})
            }
            "sim_push" => {
                let (bid, bytes) = push_args(a)?;
                let out = x86sim(&d, "push", &[bid.clone(), "-".into()], Some(&bytes))?;
                json!({"phone": inst.name, "bundle_id": bid, "sent": true, "answer": out})
            }
            "sim_addmedia" => {
                let paths: Vec<String> = a["paths"].as_array().map(|v| v.iter().filter_map(|x| x.as_str().map(String::from)).collect()).unwrap_or_default();
                anyhow::ensure!(!paths.is_empty(), "paths: at least one image or video file");
                let mut abs = vec![];
                for p in &paths {
                    let pb = std::path::Path::new(p);
                    anyhow::ensure!(pb.is_absolute(), "{p}: an absolute path on this machine");
                    anyhow::ensure!(pb.is_file(), "{p}: no such file");
                    abs.push(p.clone());
                }
                let out = x86sim(&d, "addmedia", &abs, None)?;
                json!({"phone": inst.name, "added": paths, "answer": out})
            }
            _ => unreachable!(),
        })
    })())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn location() {
        assert_eq!(location_args(&json!({"action": "set", "lat": 48.8584, "lon": 2.2945})).unwrap(), ["set", "48.8584,2.2945"]);
        assert!(location_args(&json!({"action": "set", "lat": 91, "lon": 0})).is_err());
        assert!(location_args(&json!({"action": "set", "lat": 1})).is_err());
        assert_eq!(location_args(&json!({"action": "clear"})).unwrap(), ["clear"]);
        assert_eq!(location_args(&json!({"action": "scenario", "name": "City Run"})).unwrap(), ["run", "City Run"]);
        assert!(location_args(&json!({"action": "scenario", "name": "--x"})).is_err());
        assert_eq!(location_args(&json!({"action": "route", "points": [[1, 2], [3, 4]], "speed": 5})).unwrap(), ["start", "--speed=5", "1,2", "3,4"]);
        assert!(location_args(&json!({"action": "route", "points": [[1, 2]]})).is_err());
        assert!(location_args(&json!({"action": "go"})).is_err());
    }

    #[test]
    fn privacy() {
        assert_eq!(privacy_args(&json!({"action": "grant", "service": "photos", "bundle_id": "com.a.b"})).unwrap(), ["grant", "photos", "com.a.b"]);
        assert_eq!(privacy_args(&json!({"action": "reset", "service": "all"})).unwrap(), ["reset", "all"]);
        assert!(privacy_args(&json!({"action": "grant", "service": "photos"})).is_err());
        assert!(privacy_args(&json!({"action": "grant", "service": "teleport", "bundle_id": "com.a.b"})).is_err());
        assert!(privacy_args(&json!({"action": "grant", "service": "photos", "bundle_id": "--x"})).is_err());
    }

    #[test]
    fn push() {
        let (b, p) = push_args(&json!({"bundle_id": "com.a.b", "payload": {"aps": {"alert": "hi"}}})).unwrap();
        assert_eq!(b, "com.a.b");
        assert_eq!(serde_json::from_slice::<Value>(&p).unwrap()["aps"]["alert"], "hi");
        assert_eq!(push_args(&json!({"payload": {"aps": {}, "Simulator Target Bundle": "com.x.y"}})).unwrap().0, "com.x.y");
        assert_eq!(push_args(&json!({"bundle_id": "com.a.b", "payload": "{\"aps\": {}}"})).unwrap().0, "com.a.b");
        assert!(push_args(&json!({"bundle_id": "com.a.b", "payload": {"alert": "hi"}})).is_err());
        assert!(push_args(&json!({"payload": {"aps": {}}})).is_err());
    }
}
