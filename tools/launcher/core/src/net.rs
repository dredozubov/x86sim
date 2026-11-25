//! Network capture of native apps (docs/protocols/NET.md): what host/simnet (a recording NSURLProtocol in the app's
//! process) and libsimshim's connection records write under the device's `data/x86sim-net/`, read back as requests;
//! turning capture on and off per app; mock rules. Used by the MCP tools net_capture / net_log / net_request /
//! net_mock (bin/mcp_parts/net.rs), `x86sim net` (x86sim-ax net), the browser page (share/device.rs) and the launcher.
use crate::instance::Instance;
use anyhow::{bail, Context, Result};
use serde::Serialize;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

/// Bodies kept per request unless net_capture says otherwise (bytes)
pub const DEFAULT_BODY_LIMIT: u64 = 256 * 1024;
/// Records read back at most (the newest)
const MAX_ENTRIES: usize = 5000;

pub fn dir(inst: &Instance) -> PathBuf {
    inst.dir.join("data/x86sim-net")
}

fn cap_dir(inst: &Instance) -> PathBuf {
    dir(inst).join("capture")
}

fn log_dir(inst: &Instance) -> PathBuf {
    dir(inst).join("log")
}

fn mocks_path(inst: &Instance) -> PathBuf {
    dir(inst).join("mocks.json")
}

fn valid_bundle(b: &str) -> Result<()> {
    if b.is_empty() || b.contains('/') || b.starts_with('.') || b.contains('\0') {
        bail!("app: a bundle id (com.example.app)");
    }
    Ok(())
}

fn now() -> f64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs_f64()).unwrap_or(0.0)
}

/// Writes a file whole (a temporary file renamed over it: the app never reads half of it)
fn write_atomic(p: &Path, data: &[u8]) -> Result<()> {
    if let Some(d) = p.parent() {
        std::fs::create_dir_all(d)?;
    }
    let tmp = p.with_extension(format!("tmp{}", std::process::id()));
    std::fs::write(&tmp, data)?;
    std::fs::rename(&tmp, p)?;
    Ok(())
}

// ---- capture on / off

#[derive(Serialize, Clone, Debug)]
pub struct Capture {
    pub app: String,
    pub body_limit: u64,
    pub since: f64,
}

/// Apps with capture on
pub fn captures(inst: &Instance) -> Vec<Capture> {
    let mut v: Vec<Capture> = std::fs::read_dir(cap_dir(inst))
        .into_iter()
        .flatten()
        .flatten()
        .filter_map(|e| {
            let app = e.file_name().to_string_lossy().to_string();
            if app.contains(".tmp") {
                return None;
            }
            let o: Value = std::fs::read(e.path()).ok().and_then(|b| serde_json::from_slice(&b).ok()).unwrap_or_default();
            Some(Capture { app, body_limit: o["body_limit"].as_u64().unwrap_or(DEFAULT_BODY_LIMIT), since: o["since"].as_f64().unwrap_or(0.0) })
        })
        .collect();
    v.sort_by(|a, b| a.app.cmp(&b.app));
    v
}

pub fn capture_on(inst: &Instance, app: &str) -> bool {
    cap_dir(inst).join(app).exists()
}

/// Turns capture on (with a body limit) or off for an app. On: the hook is loaded at the app's next launch, so
/// `relaunch` restarts it now (its first requests are then in the log). Off: at once (requests go to the system's
/// loader again; the loaded hook stays inert).
pub fn set_capture(inst: &Instance, app: &str, on: bool, body_limit: Option<u64>, relaunch: bool) -> Result<Value> {
    valid_bundle(app)?;
    let f = cap_dir(inst).join(app);
    let mut hooked = Value::Null;
    if on {
        let limit = body_limit.unwrap_or(DEFAULT_BODY_LIMIT);
        write_atomic(&f, json!({"body_limit": limit, "since": now()}).to_string().as_bytes())?;
        std::fs::create_dir_all(log_dir(inst))?;
        if relaunch {
            let t0 = now();
            let _ = crate::apps::terminate(inst, app);
            crate::apps::launch(inst, app, &[]).with_context(|| format!("relaunch {app}"))?;
            // the hook says hello when it starts
            let until = Instant::now() + Duration::from_secs(15);
            hooked = json!(false);
            while Instant::now() < until {
                if hellos(inst).iter().any(|h| h.app == app && h.ts >= t0 - 1.0) {
                    hooked = json!(true);
                    break;
                }
                std::thread::sleep(Duration::from_millis(200));
            }
        }
        let note = if relaunch { "relaunched" } else { "applies from the app's next launch (relaunch=true restarts it now)" };
        Ok(json!({"app": app, "capture": true, "body_limit": limit, "hooked": hooked, "note": note}))
    } else {
        match std::fs::remove_file(&f) {
            Ok(()) => {}
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
            Err(e) => return Err(e.into()),
        }
        Ok(json!({"app": app, "capture": false}))
    }
}

// ---- records

#[derive(Serialize, Clone, Debug)]
pub struct Hello {
    pub app: String,
    pub pid: u32,
    pub ts: f64,
}

/// One request (URLSession) or connection (other stacks)
#[derive(Serialize, Clone, Debug)]
pub struct Entry {
    /// <pid>.<n> for a request, <pid>.c<n> for a connection
    pub id: String,
    pub kind: &'static str,
    pub app: String,
    pub pid: u32,
    pub ts: f64,
    pub method: String,
    pub url: String,
    /// HTTP status; None while in flight or on a failure before a response
    pub status: Option<u64>,
    pub duration_ms: Option<f64>,
    /// response body size (connections: bytes in)
    pub size: Option<u64>,
    pub error: Option<String>,
    pub mock: Option<String>,
    pub pending: bool,
    #[serde(skip)]
    pub raw: Value,
}

impl Entry {
    /// One line: id, method, status, URL, duration, size
    pub fn line(&self) -> String {
        let st = if self.pending {
            "…".to_string()
        } else if let Some(s) = self.status {
            s.to_string()
        } else if self.kind == "conn" {
            "conn".into()
        } else {
            "ERR".into()
        };
        let dur = self.duration_ms.map(|d| format!(" {}ms", d.round() as i64)).unwrap_or_default();
        let size = match (self.kind, self.size) {
            ("conn", _) => format!(" out {} in {}", fmt_size(self.raw["bytes_out"].as_u64().unwrap_or(0)), fmt_size(self.raw["bytes_in"].as_u64().unwrap_or(0))),
            (_, Some(s)) => format!(" {}", fmt_size(s)),
            _ => String::new(),
        };
        let err = self.error.as_ref().map(|e| format!(" ({e})")).unwrap_or_default();
        let mock = self.mock.as_ref().map(|m| format!(" [mock {m}]")).unwrap_or_default();
        format!("#{} {} {} {}{}{}{}{}", self.id, self.method, st, self.url, dur, size, err, mock)
    }

    /// Everything about it, bodies included
    pub fn full(&self) -> Value {
        let mut v = self.raw.clone();
        if let Value::Object(m) = &mut v {
            m.remove("k");
            m.insert("id".into(), json!(self.id));
            m.insert("kind".into(), json!(self.kind));
            m.insert("app".into(), json!(self.app));
            m.insert("pid".into(), json!(self.pid));
            if self.pending {
                m.insert("pending".into(), json!(true));
            }
        }
        v
    }
}

pub fn fmt_size(n: u64) -> String {
    if n < 1024 {
        format!("{n} B")
    } else if n < 1024 * 1024 {
        format!("{:.1} KB", n as f64 / 1024.0)
    } else {
        format!("{:.1} MB", n as f64 / 1048576.0)
    }
}

/// <bundle>-<pid>.jsonl / <bundle>-<pid>.conn.jsonl -> (bundle, pid, connections?)
fn parse_name(name: &str) -> Option<(String, u32, bool)> {
    let (stem, conn) = if let Some(s) = name.strip_suffix(".conn.jsonl") {
        (s, true)
    } else {
        (name.strip_suffix(".jsonl")?, false)
    };
    let (app, pid) = stem.rsplit_once('-')?;
    Some((app.to_string(), pid.parse().ok()?, conn))
}

fn log_files(inst: &Instance) -> Vec<(PathBuf, String, u32, bool)> {
    std::fs::read_dir(log_dir(inst))
        .into_iter()
        .flatten()
        .flatten()
        .filter_map(|e| {
            let n = e.file_name().to_string_lossy().to_string();
            let (app, pid, conn) = parse_name(&n)?;
            Some((e.path(), app, pid, conn))
        })
        .collect()
}

fn read_lines(p: &Path) -> Vec<Value> {
    let Ok(b) = std::fs::read(p) else { return vec![] };
    b.split(|c| *c == b'\n').filter(|l| !l.is_empty()).filter_map(|l| serde_json::from_slice(l).ok()).collect()
}

/// Processes whose hook started (one per launch with capture on)
pub fn hellos(inst: &Instance) -> Vec<Hello> {
    let mut v = vec![];
    for (p, app, pid, conn) in log_files(inst) {
        if conn {
            continue;
        }
        // the hello is the first line
        let first = std::fs::File::open(&p).ok().and_then(|f| {
            use std::io::BufRead;
            std::io::BufReader::new(f).lines().next()?.ok()
        });
        if let Some(h) = first.and_then(|l| serde_json::from_str::<Value>(&l).ok()).filter(|h| h["k"] == "hello") {
            v.push(Hello { app, pid, ts: h["ts"].as_f64().unwrap_or(0.0) });
        }
    }
    v
}

fn s(v: &Value) -> String {
    v.as_str().unwrap_or("").to_string()
}

/// Every request and connection recorded on the device, oldest first (the newest MAX_ENTRIES)
pub fn entries(inst: &Instance) -> Vec<Entry> {
    let mut out = vec![];
    for (p, app, pid, conn) in log_files(inst) {
        let lines = read_lines(&p);
        if conn {
            for r in lines.into_iter().filter(|r| r["k"] == "conn") {
                let host = r["host"].as_str().filter(|h| !h.is_empty()).unwrap_or(r["addr"].as_str().unwrap_or("?"));
                out.push(Entry {
                    id: format!("{pid}.c{}", r["n"].as_u64().unwrap_or(0)),
                    kind: "conn",
                    app: app.clone(),
                    pid,
                    ts: r["ts"].as_f64().unwrap_or(0.0),
                    method: r["proto"].as_str().unwrap_or("tcp").to_uppercase(),
                    url: format!("{host}:{}", r["port"].as_u64().unwrap_or(0)),
                    status: None,
                    duration_ms: r["duration_ms"].as_f64(),
                    size: r["bytes_in"].as_u64(),
                    error: None,
                    mock: None,
                    pending: false,
                    raw: r,
                });
            }
            continue;
        }
        let mut started: HashMap<u64, Value> = HashMap::new();
        for r in lines {
            let n = r["n"].as_u64().unwrap_or(0);
            match r["k"].as_str() {
                Some("start") => {
                    started.insert(n, r);
                }
                Some("req") => {
                    started.remove(&n);
                    let error = r["error"].as_object().map(|e| {
                        let t = e.get("text").and_then(|t| t.as_str()).unwrap_or("");
                        format!("{} {}{}", e.get("domain").and_then(|d| d.as_str()).unwrap_or(""), e.get("code").map(|c| c.to_string()).unwrap_or_default(), if t.is_empty() { String::new() } else { format!(": {t}") })
                    });
                    out.push(Entry {
                        id: format!("{pid}.{n}"),
                        kind: "request",
                        app: app.clone(),
                        pid,
                        ts: r["ts"].as_f64().unwrap_or(0.0),
                        method: s(&r["method"]),
                        url: s(&r["url"]),
                        status: r["status"].as_u64(),
                        duration_ms: r["timing"]["total"].as_f64(),
                        size: r["resp_body_size"].as_u64(),
                        error,
                        mock: r["mock"].as_str().map(String::from),
                        pending: false,
                        raw: r,
                    });
                }
                _ => {}
            }
        }
        for (n, r) in started {
            out.push(Entry {
                id: format!("{pid}.{n}"),
                kind: "request",
                app: app.clone(),
                pid,
                ts: r["ts"].as_f64().unwrap_or(0.0),
                method: s(&r["method"]),
                url: s(&r["url"]),
                status: None,
                duration_ms: None,
                size: None,
                error: None,
                mock: None,
                pending: true,
                raw: r,
            });
        }
    }
    out.sort_by(|a, b| a.ts.total_cmp(&b.ts).then_with(|| a.id.cmp(&b.id)));
    let skip = out.len().saturating_sub(MAX_ENTRIES);
    out.drain(..skip);
    out
}

/// What net_log keeps: an app, a filter, a start
#[derive(Default, Clone, Debug)]
pub struct Query {
    pub app: Option<String>,
    /// words that must all be in the line (case-insensitive); `status:4xx` / `status:404`, `method:POST`,
    /// `kind:conn`, `kind:request`, `error`, `mock` match those fields; `-word` excludes
    pub filter: String,
    /// unix seconds; entries at or after it
    pub since_ts: Option<f64>,
}

impl Query {
    /// since: seconds ago ("30", "30s", "5m"), an entry id (only those after it), or empty
    pub fn since(&mut self, since: &str, all: &[Entry]) -> Result<()> {
        let since = since.trim();
        if since.is_empty() {
            return Ok(());
        }
        if let Some(e) = all.iter().find(|e| e.id == since || e.id == since.trim_start_matches('#')) {
            self.since_ts = Some(e.ts + 1e-6);
            return Ok(());
        }
        let (num, mul) = match since.chars().last() {
            Some('s') => (&since[..since.len() - 1], 1.0),
            Some('m') => (&since[..since.len() - 1], 60.0),
            Some('h') => (&since[..since.len() - 1], 3600.0),
            _ => (since, 1.0),
        };
        let secs: f64 = num.parse().map_err(|_| anyhow::anyhow!("since: seconds (30, 5m) or a request id"))?;
        self.since_ts = Some(now() - secs * mul);
        Ok(())
    }

    pub fn matches(&self, e: &Entry) -> bool {
        if self.app.as_deref().is_some_and(|a| !a.is_empty() && a != e.app) {
            return false;
        }
        if self.since_ts.is_some_and(|t| e.ts < t) {
            return false;
        }
        let line = e.line().to_lowercase();
        self.filter.split_whitespace().all(|w| {
            let w = w.to_lowercase();
            let (neg, w) = match w.strip_prefix('-') {
                Some(r) if !r.is_empty() => (true, r.to_string()),
                _ => (false, w),
            };
            let hit = if let Some(st) = w.strip_prefix("status:") {
                let code = e.status.map(|c| c.to_string()).unwrap_or_else(|| if e.pending { "pending".into() } else { "err".into() });
                if let Some(p) = st.strip_suffix("xx") { code.starts_with(p) } else { code == st }
            } else if let Some(m) = w.strip_prefix("method:") {
                e.method.to_lowercase() == m
            } else if let Some(k) = w.strip_prefix("kind:") {
                e.kind.starts_with(k)
            } else if w == "error" {
                e.error.is_some()
            } else if w == "mock" {
                e.mock.is_some()
            } else {
                line.contains(&w)
            };
            hit != neg
        })
    }
}

/// The entries a query matches; with `follow`, waits up to that long for at least one new one (`since_ts` should
/// then be set, else everything already there answers at once)
pub fn log(inst: &Instance, q: &Query, follow: Option<Duration>) -> Vec<Entry> {
    let until = follow.map(|d| Instant::now() + d);
    loop {
        let v: Vec<Entry> = entries(inst).into_iter().filter(|e| q.matches(e)).collect();
        match until {
            Some(t) if v.is_empty() && Instant::now() < t => std::thread::sleep(Duration::from_millis(250)),
            _ => return v,
        }
    }
}

pub fn request(inst: &Instance, id: &str) -> Result<Entry> {
    let id = id.trim().trim_start_matches('#');
    entries(inst).into_iter().find(|e| e.id == id).ok_or_else(|| anyhow::anyhow!("no request {id} (net_log lists them)"))
}

/// Removes the recorded requests (of one app, or all)
pub fn clear_log(inst: &Instance, app: Option<&str>) -> Result<usize> {
    let mut n = 0;
    for (p, a, _, _) in log_files(inst) {
        if app.is_none_or(|x| x.is_empty() || x == a) {
            // truncate, not unlink: a running app keeps its file open and would write into a removed file
            std::fs::OpenOptions::new().write(true).truncate(true).open(&p)?;
            n += 1;
        }
    }
    Ok(n)
}

// ---- mocks

/// A mock rule as the hook reads it (docs/protocols/NET.md)
pub fn mocks(inst: &Instance) -> Vec<Value> {
    std::fs::read(mocks_path(inst)).ok().and_then(|b| serde_json::from_slice::<Value>(&b).ok()).and_then(|v| v["rules"].as_array().cloned()).unwrap_or_default()
}

fn save_mocks(inst: &Instance, rules: &[Value]) -> Result<()> {
    if rules.is_empty() {
        match std::fs::remove_file(mocks_path(inst)) {
            Err(e) if e.kind() != std::io::ErrorKind::NotFound => return Err(e.into()),
            _ => return Ok(()),
        }
    }
    write_atomic(&mocks_path(inst), serde_json::to_vec_pretty(&json!({"rules": rules}))?.as_slice())
}

pub const FAILS: [&str; 5] = ["offline", "timeout", "dns", "refused", "reset"];

/// Adds a rule from a tool's arguments: url (pattern), method, status, headers, body (text or JSON) | body_file,
/// latency_ms, fail. The newest rule wins over older ones that match the same request.
pub fn add_mock(inst: &Instance, a: &Value) -> Result<Value> {
    let url = a["url"].as_str().unwrap_or("").trim().to_string();
    if url.is_empty() {
        bail!("url: a pattern (part of the URL; with * a glob over the whole URL; re:<regex>)");
    }
    if let Some(r) = url.strip_prefix("re:") {
        // the guest uses NSRegularExpression; reject what is clearly broken here
        if r.is_empty() {
            bail!("url: re: needs a regular expression");
        }
    }
    let mut r = serde_json::Map::new();
    r.insert("url".into(), json!(url));
    if let Some(m) = a["method"].as_str().filter(|m| !m.is_empty()) {
        r.insert("method".into(), json!(m.to_uppercase()));
    }
    if let Some(f) = a["fail"].as_str().filter(|f| !f.is_empty()) {
        if !FAILS.contains(&f) {
            bail!("fail: one of {}", FAILS.join(", "));
        }
        r.insert("fail".into(), json!(f));
    }
    let has_body = !a["body"].is_null() || a["body_file"].as_str().is_some_and(|f| !f.is_empty());
    if let Some(st) = a["status"].as_u64() {
        if !(100..=599).contains(&st) {
            bail!("status: 100..599");
        }
        r.insert("status".into(), json!(st));
    } else if has_body || a["headers"].is_object() {
        r.insert("status".into(), json!(200));
    }
    if let Some(h) = a["headers"].as_object() {
        r.insert("headers".into(), Value::Object(h.iter().map(|(k, v)| (k.clone(), json!(v.as_str().map(String::from).unwrap_or_else(|| v.to_string())))).collect()));
    }
    if let Some(f) = a["body_file"].as_str().filter(|f| !f.is_empty()) {
        let b = std::fs::read(f).with_context(|| format!("body_file {f}"))?;
        r.insert("body_b64".into(), json!(crate::ax::base64(&b)));
        if !r.contains_key("headers") || !r["headers"].as_object().is_some_and(|h| h.keys().any(|k| k.eq_ignore_ascii_case("content-type"))) {
            let ct = content_type_for(f);
            let mut h = r.get("headers").and_then(|h| h.as_object().cloned()).unwrap_or_default();
            h.insert("Content-Type".into(), json!(ct));
            r.insert("headers".into(), Value::Object(h));
        }
    } else if !a["body"].is_null() {
        r.insert("body".into(), a["body"].clone());
    }
    if let Some(l) = a["latency_ms"].as_u64() {
        r.insert("latency_ms".into(), json!(l.min(600_000)));
    }
    if !r.contains_key("status") && !r.contains_key("fail") && !r.contains_key("latency_ms") {
        bail!("say what the rule does: status / body / headers (an answer), fail, or latency_ms");
    }
    let mut rules = mocks(inst);
    let next = rules.iter().filter_map(|r| r["id"].as_str()?.strip_prefix('m')?.parse::<u64>().ok()).max().unwrap_or(0) + 1;
    r.insert("id".into(), json!(format!("m{next}")));
    let rule = Value::Object(r);
    // newest first: the hook takes the first rule that matches
    rules.insert(0, rule.clone());
    save_mocks(inst, &rules)?;
    Ok(rule)
}

fn content_type_for(f: &str) -> &'static str {
    match f.rsplit('.').next().unwrap_or("").to_lowercase().as_str() {
        "json" => "application/json",
        "html" | "htm" => "text/html; charset=utf-8",
        "txt" => "text/plain; charset=utf-8",
        "xml" => "application/xml",
        "png" => "image/png",
        "jpg" | "jpeg" => "image/jpeg",
        "gif" => "image/gif",
        "webp" => "image/webp",
        "svg" => "image/svg+xml",
        "js" => "text/javascript",
        "css" => "text/css",
        _ => "application/octet-stream",
    }
}

/// Removes one rule (its id) or, with None, all of them; answers how many went
pub fn remove_mock(inst: &Instance, id: Option<&str>) -> Result<usize> {
    let rules = mocks(inst);
    let keep: Vec<Value> = match id {
        Some(id) => rules.iter().filter(|r| r["id"].as_str() != Some(id)).cloned().collect(),
        None => vec![],
    };
    let n = rules.len() - keep.len();
    if id.is_some() && n == 0 {
        bail!("no mock rule {}", id.unwrap_or(""));
    }
    save_mocks(inst, &keep)?;
    Ok(n)
}

/// A rule as one line
pub fn mock_line(r: &Value) -> String {
    let mut s = format!("{} {} {}", r["id"].as_str().unwrap_or("?"), r["method"].as_str().unwrap_or("*"), r["url"].as_str().unwrap_or(""));
    if let Some(f) = r["fail"].as_str() {
        s += &format!(" -> fail {f}");
    } else if let Some(st) = r["status"].as_u64() {
        let len = r["body_b64"].as_str().map(|b| b.len() * 3 / 4).or_else(|| r["body"].as_str().map(|b| b.len())).or_else(|| (!r["body"].is_null()).then(|| r["body"].to_string().len())).unwrap_or(0);
        s += &format!(" -> {st} ({})", fmt_size(len as u64));
    }
    if let Some(l) = r["latency_ms"].as_u64() {
        s += &format!(" +{l}ms");
    }
    s
}

#[cfg(test)]
mod tests {
    use super::*;

    fn e(id: &str, method: &str, status: Option<u64>, url: &str) -> Entry {
        Entry { id: id.into(), kind: "request", app: "com.a".into(), pid: 1, ts: 1.0, method: method.into(), url: url.into(), status, duration_ms: Some(12.4), size: Some(2048), error: None, mock: None, pending: false, raw: json!({}) }
    }

    #[test]
    fn names() {
        assert_eq!(parse_name("com.x.y-123.jsonl"), Some(("com.x.y".into(), 123, false)));
        assert_eq!(parse_name("com.x-y-9.conn.jsonl"), Some(("com.x-y".into(), 9, true)));
        assert_eq!(parse_name("junk"), None);
    }

    #[test]
    fn lines_and_filters() {
        let a = e("1.1", "GET", Some(200), "https://h/x");
        assert_eq!(a.line(), "#1.1 GET 200 https://h/x 12ms 2.0 KB");
        let b = e("1.2", "POST", Some(404), "http://h/y");
        let q = |f: &str| Query { filter: f.into(), ..Default::default() };
        assert!(q("status:4xx").matches(&b) && !q("status:4xx").matches(&a));
        assert!(q("method:post").matches(&b) && !q("method:post").matches(&a));
        assert!(q("-https").matches(&b) && !q("-https").matches(&a));
        assert!(q("h/x 200").matches(&a));
    }
}
