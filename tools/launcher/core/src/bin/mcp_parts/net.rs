//! x86sim-mcp: net_capture / net_log / net_request, the network traffic of native apps
//! (x86sim_core::net, host/simnet). Kept apart from mcp.rs like mcp_parts/profile.rs.
use serde_json::{json, Value};
use std::time::Duration;
use x86sim_core::{instance, net};

pub fn tools(phone: &Value) -> Vec<Value> {
    vec![
        json!({"name": "net_capture", "description": "Record an app's network traffic (as a proxy would, without one: HTTPS is seen in the clear). action on: every URLSession request of the app (also Alamofire, React Native fetch, most SDKs) is recorded with method, URL, headers both ways, status, timings (DNS, connect, TLS, first byte, total), sizes and bodies up to body_limit (text as is, binary as base64); other stacks (Flutter dart:io, gRPC, raw sockets) as connections (host, port, bytes in / out, duration). The hook loads at the app's launch: relaunch=true restarts the app now so its first requests are in. action off: stops at once. action status (or no app): which apps capture. Third-party apps only. Read with net_log / net_request.",
            "inputSchema": {"type": "object", "properties": {"phone": phone,
                "app": {"type": "string", "description": "bundle id"},
                "action": {"type": "string", "enum": ["on", "off", "status"], "description": "default on when app is given, else status"},
                "relaunch": {"type": "boolean", "description": "restart the app now (default false: applies at its next launch)"},
                "body_limit": {"type": "integer", "description": "bytes of each body kept (default 262144; 0: none)"}}}}),
        json!({"name": "net_log", "description": "Recorded network requests, one line each: #id METHOD status URL duration size (ERR and the error for failures, … while in flight; connections: TCP host:port with bytes out / in). filter: words that must all be in the line, or status:4xx / status:404 / method:POST / kind:conn / error / mock; -word excludes. since: seconds (30, 5m) or an id (only newer ones). follow_s: wait up to that long for new requests (with since, or from now). clear=true empties the log.",
            "inputSchema": {"type": "object", "properties": {"phone": phone,
                "app": {"type": "string", "description": "only this bundle id"},
                "filter": {"type": "string"},
                "since": {"type": "string"},
                "follow_s": {"type": "number"},
                "limit": {"type": "integer", "description": "newest N lines (default 200)"},
                "json": {"type": "boolean", "description": "records instead of lines"},
                "clear": {"type": "boolean"}}}}),
        json!({"name": "net_request", "description": "Everything about one recorded request (id from net_log): method, URL, final URL, request and response headers, status, MIME type, request and response bodies (text, or base64 with *_b64; *_truncated past the body limit), sizes, timings in ms (dns, connect, tls, send, wait, receive, first_byte, total), protocol (h2, http/1.1), remote address, TLS version, reused connection, error, redirect_to, the mock that answered.",
            "inputSchema": {"type": "object", "properties": {"phone": phone, "id": {"type": "string"}}, "required": ["id"]}}),
    ]
}

/// Some(result) for the net_* tools, None for other tools.
pub fn call(name: &str, a: &Value, phone: &dyn Fn() -> anyhow::Result<instance::Instance>) -> Option<anyhow::Result<(String, Option<Value>)>> {
    if !name.starts_with("net_") {
        return None;
    }
    Some((|| {
        let inst = phone()?;
        let app = a["app"].as_str().filter(|s| !s.is_empty());
        match name {
            "net_capture" => {
                let action = a["action"].as_str().unwrap_or(if app.is_some() { "on" } else { "status" });
                if action == "status" {
                    let caps = net::captures(&inst);
                    let t = if caps.is_empty() { "capture is off for every app".to_string() } else { caps.iter().map(|c| format!("{} (bodies up to {})", c.app, net::fmt_size(c.body_limit))).collect::<Vec<_>>().join("\n") };
                    return Ok((t, Some(json!({"captures": caps}))));
                }
                let app = app.ok_or_else(|| anyhow::anyhow!("app: a bundle id"))?;
                let on = match action {
                    "on" => true,
                    "off" => false,
                    _ => anyhow::bail!("action: on, off or status"),
                };
                let v = net::set_capture(&inst, app, on, a["body_limit"].as_u64(), a["relaunch"].as_bool().unwrap_or(false))?;
                let t = if !on {
                    format!("capture off for {app}")
                } else if v["hooked"] == json!(false) {
                    format!("capture on for {app}, relaunched, but the hook did not start within 15 s (a third-party app? the device's guest libraries up to date?)")
                } else {
                    format!("capture on for {app}: {}", v["note"].as_str().unwrap_or(""))
                };
                Ok((t, Some(v)))
            }
            "net_log" => {
                if a["clear"].as_bool().unwrap_or(false) {
                    let n = net::clear_log(&inst, app)?;
                    return Ok((format!("cleared {n} log file(s)"), Some(json!({"cleared": n}))));
                }
                let all = net::entries(&inst);
                let mut q = net::Query { app: app.map(String::from), filter: a["filter"].as_str().unwrap_or("").into(), since_ts: None };
                q.since(a["since"].as_str().map(String::from).or_else(|| a["since"].as_f64().map(|f| f.to_string())).as_deref().unwrap_or(""), &all)?;
                let follow = a["follow_s"].as_f64().filter(|f| *f > 0.0).map(|f| Duration::from_secs_f64(f.min(120.0)));
                if follow.is_some() && q.since_ts.is_none() {
                    // from now: only what comes
                    q.since_ts = Some(std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs_f64()).unwrap_or(0.0));
                }
                drop(all);
                let v = net::log(&inst, &q, follow);
                let limit = a["limit"].as_u64().unwrap_or(200).max(1) as usize;
                let shown = &v[v.len().saturating_sub(limit)..];
                if a["json"].as_bool().unwrap_or(false) {
                    return Ok((format!("{} of {} requests", shown.len(), v.len()), Some(json!({"requests": shown, "total": v.len()}))));
                }
                let mut t: String = shown.iter().map(|e| e.line() + "\n").collect();
                if v.len() > shown.len() {
                    t = format!("({} older not shown)\n{t}", v.len() - shown.len());
                }
                if t.is_empty() {
                    let caps = net::captures(&inst);
                    t = if caps.is_empty() { "no requests (capture is off: net_capture app=... relaunch=true)".into() } else { "no requests".into() };
                }
                Ok((t, None))
            }
            "net_request" => {
                let e = net::request(&inst, a["id"].as_str().unwrap_or(""))?;
                let v = e.full();
                Ok((serde_json::to_string_pretty(&v)?, None))
            }
            _ => anyhow::bail!("unknown tool {name}"),
        }
    })())
}
