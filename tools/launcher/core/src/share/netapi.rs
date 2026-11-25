//! Share: the Network section's routes for the browser page (web/netpanel.js; core net.rs), kept apart from
//! server.rs like axapi.rs. Control links only: requests carry cookies, tokens and bodies. Under
//! /api/phones/<id>/net/:
//!   GET  log?after=<ts>&filter=&app=   requests and connections (newest 500), `apps` (bundle ids seen), `captures`,
//!                                      `mocks`; after: only entries newer than that time
//!   GET  request?id=<id>               one request, everything
//!   POST capture {app, on, relaunch}   capture on / off for an app
//!   POST clear {app?}                  empty the log
//!   POST mock {url, method, status, body, fail, latency_ms} | {clear: true} | {remove: id}
use super::server::Req;
use crate::instance::Instance;
use crate::net;
use serde_json::{json, Value};

pub fn handle(req: &Req, inst: &Instance, what: &str, control: bool) -> (u16, Value) {
    if !control {
        return (403, json!({"error": "network traffic needs a control link"}));
    }
    let q = |k: &str| req.query.get(k).cloned().unwrap_or_default();
    let body: Value = serde_json::from_slice(&req.body).unwrap_or_default();
    let r: anyhow::Result<Value> = match (req.method.as_str(), what) {
        ("GET", "log") => {
            let all = net::entries(inst);
            let mut apps: Vec<String> = all.iter().map(|e| e.app.clone()).collect();
            apps.sort();
            apps.dedup();
            let after: f64 = q("after").parse().unwrap_or(0.0);
            let query = net::Query { app: Some(q("app")).filter(|a| !a.is_empty()), filter: q("filter"), since_ts: (after > 0.0).then_some(after + 1e-6) };
            let v: Vec<Value> = all
                .iter()
                .filter(|e| query.matches(e))
                .map(|e| {
                    let mut o = serde_json::to_value(e).unwrap_or_default();
                    o["line"] = json!(e.line());
                    o
                })
                .collect();
            let skip = v.len().saturating_sub(500);
            Ok(json!({"entries": &v[skip..], "apps": apps, "captures": net::captures(inst), "mocks": net::mocks(inst).iter().map(net::mock_line).collect::<Vec<_>>()}))
        }
        ("GET", "request") => net::request(inst, &q("id")).map(|e| e.full()),
        ("POST", "capture") => {
            let app = body["app"].as_str().unwrap_or("");
            net::set_capture(inst, app, body["on"].as_bool().unwrap_or(true), body["body_limit"].as_u64(), body["relaunch"].as_bool().unwrap_or(false))
        }
        ("POST", "clear") => net::clear_log(inst, body["app"].as_str()).map(|n| json!({"cleared": n})),
        ("POST", "mock") => {
            if body["clear"].as_bool() == Some(true) {
                net::remove_mock(inst, None).map(|n| json!({"removed": n}))
            } else if let Some(id) = body["remove"].as_str() {
                net::remove_mock(inst, Some(id)).map(|n| json!({"removed": n}))
            } else {
                // never a file of this machine from a browser (body_file is for the local CLI / MCP)
                let mut b = body.clone();
                if let Value::Object(m) = &mut b {
                    m.remove("body_file");
                }
                net::add_mock(inst, &b)
            }
        }
        _ => return (404, json!({"error": "not found"})),
    };
    match r {
        Ok(v) => (200, v),
        Err(e) => (409, json!({"error": format!("{e:#}")})),
    }
}
