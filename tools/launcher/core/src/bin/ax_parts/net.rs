//! x86sim-ax net: the CLI of the network capture (x86sim_core::net; the MCP tools net_* in mcp_parts/net.rs).
use anyhow::{bail, Result};
use serde_json::{json, Value};
use std::time::Duration;
use x86sim_core::{instance::Instance, net};

pub const USAGE: &str = "  net capture APP on|off [--relaunch] [--limit BYTES] | net capture
                                       record an app's requests (URLSession: headers, bodies, timings; other stacks:
                                       connections); --relaunch: restart it now so its first requests are in
  net log [APP] [--filter WORDS] [--since 30s|ID] [--follow S] [--json]
                                       one line per request: #id METHOD status URL duration size
  net show ID                          one request: headers, bodies, timings, error
  net clear [APP]                      empty the log
  net mock add URL [--method M] [--status N] [--header K:V]... [--body TEXT|--body-file F] [--latency MS]
                   [--fail offline|timeout|dns|refused|reset]
  net mock list | remove ID | clear    answer requests without a server (apps with capture on)";

fn take(args: &mut Vec<String>, name: &str) -> Option<String> {
    let i = args.iter().position(|a| a == name)?;
    if i + 1 >= args.len() {
        return None;
    }
    let v = args.remove(i + 1);
    args.remove(i);
    Some(v)
}

fn flag(args: &mut Vec<String>, name: &str) -> bool {
    match args.iter().position(|a| a == name) {
        Some(i) => {
            args.remove(i);
            true
        }
        None => false,
    }
}

pub fn run(inst: &Instance, mut args: Vec<String>) -> Result<()> {
    let sub = if args.is_empty() { "log".to_string() } else { args.remove(0) };
    match sub.as_str() {
        "capture" => {
            let relaunch = flag(&mut args, "--relaunch");
            let limit = take(&mut args, "--limit").map(|l| l.parse::<u64>()).transpose()?;
            match (args.first(), args.get(1).map(String::as_str)) {
                (None, _) => {
                    let caps = net::captures(inst);
                    if caps.is_empty() {
                        println!("capture is off for every app");
                    }
                    for c in caps {
                        println!("{} (bodies up to {})", c.app, net::fmt_size(c.body_limit));
                    }
                }
                (Some(app), w) => {
                    let on = match w.unwrap_or("on") {
                        "on" => true,
                        "off" => false,
                        x => bail!("net capture APP on|off, not {x}"),
                    };
                    let v = net::set_capture(inst, app, on, limit, relaunch)?;
                    println!("{}", serde_json::to_string_pretty(&v)?);
                }
            }
        }
        "log" | "ls" => {
            let json = flag(&mut args, "--json");
            let filter = take(&mut args, "--filter").unwrap_or_default();
            let since = take(&mut args, "--since").unwrap_or_default();
            let follow = take(&mut args, "--follow").map(|s| s.parse::<f64>()).transpose()?;
            let all = net::entries(inst);
            let mut q = net::Query { app: args.first().cloned(), filter, since_ts: None };
            q.since(&since, &all)?;
            let print = |v: &[net::Entry]| {
                for e in v {
                    if json {
                        println!("{}", e.full());
                    } else {
                        println!("{}", e.line());
                    }
                }
            };
            match follow {
                // like tail -f for S seconds: print what comes
                Some(s) => {
                    let end = std::time::Instant::now() + Duration::from_secs_f64(s);
                    if q.since_ts.is_none() {
                        print(&net::log(inst, &q, None));
                    }
                    let mut seen: std::collections::HashSet<String> = net::log(inst, &q, None).into_iter().filter(|e| !e.pending).map(|e| e.id).collect();
                    while std::time::Instant::now() < end {
                        std::thread::sleep(Duration::from_millis(300));
                        let new: Vec<net::Entry> = net::log(inst, &q, None).into_iter().filter(|e| !e.pending && !seen.contains(&e.id)).collect();
                        for e in &new {
                            seen.insert(e.id.clone());
                        }
                        print(&new);
                    }
                }
                None => print(&net::log(inst, &q, None)),
            }
        }
        "show" | "request" => {
            let id = args.first().ok_or_else(|| anyhow::anyhow!("net show ID"))?;
            println!("{}", serde_json::to_string_pretty(&net::request(inst, id)?.full())?);
        }
        "clear" => {
            let n = net::clear_log(inst, args.first().map(String::as_str))?;
            println!("cleared {n} log file(s)");
        }
        "mock" | "mocks" => {
            let what = if args.is_empty() { "list".to_string() } else { args.remove(0) };
            match what.as_str() {
                "list" => {
                    let r = net::mocks(inst);
                    if r.is_empty() {
                        println!("no mock rules");
                    }
                    for x in r {
                        println!("{}", net::mock_line(&x));
                    }
                }
                "clear" => println!("removed {} rule(s)", net::remove_mock(inst, None)?),
                "remove" | "rm" => {
                    let id = args.first().ok_or_else(|| anyhow::anyhow!("net mock remove ID"))?;
                    net::remove_mock(inst, Some(id))?;
                    println!("removed {id}");
                }
                "add" => {
                    let mut headers = serde_json::Map::new();
                    while let Some(h) = take(&mut args, "--header") {
                        let (k, v) = h.split_once(':').ok_or_else(|| anyhow::anyhow!("--header NAME:VALUE"))?;
                        headers.insert(k.trim().into(), json!(v.trim()));
                    }
                    let mut a = json!({
                        "method": take(&mut args, "--method"),
                        "status": take(&mut args, "--status").map(|s| s.parse::<u64>()).transpose()?,
                        "body_file": take(&mut args, "--body-file"),
                        "latency_ms": take(&mut args, "--latency").map(|s| s.parse::<u64>()).transpose()?,
                        "fail": take(&mut args, "--fail"),
                    });
                    if let Some(b) = take(&mut args, "--body") {
                        a["body"] = Value::String(b);
                    }
                    if !headers.is_empty() {
                        a["headers"] = Value::Object(headers);
                    }
                    a["url"] = json!(args.first().ok_or_else(|| anyhow::anyhow!("net mock add URL ..."))?);
                    println!("added {}", net::mock_line(&net::add_mock(inst, &a)?));
                }
                x => bail!("net mock add|list|remove|clear, not {x}"),
            }
        }
        x => bail!("net {x}: capture, log, show, clear, mock\n{USAGE}"),
    }
    Ok(())
}
