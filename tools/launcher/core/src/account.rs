//! Apple Account: one sign-in for Xcode downloads and the dev toolchain's signing.
//!
//! The sign-in is Apple's web sign-in for developer.apple.com (idmsa.apple.com, the one Xcode download tools use):
//! SRP-6a over the 2048-bit group with SHA-256, the password stretched with PBKDF2-SHA256 (protocol "s2k", or "s2k_fo"
//! with the hex of the password's hash), the same math as Apple's GrandSlam sign-in in Xcode and xtool. The password
//! never leaves this process and is never stored: Apple only gets the SRP proof. Two-factor: the code Apple pushes to
//! the account's trusted devices, or an SMS to a trusted number. The session (cookies, including the "trust this
//! browser" one that skips two-factor for a while) goes into the Secret Service keyring (secret-tool, libsecret's CLI,
//! org.freedesktop.secrets), else a 0600 file under ~/.config/x86sim. HTTP goes through curl, as everywhere in the
//! launcher (no HTTP or TLS crates); cookies live in a 0600 jar in the runtime dir only while a request runs.
use anyhow::{anyhow, bail, Context, Result};
use base64::Engine as _;
use num_bigint::BigUint;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

const B64: base64::engine::GeneralPurpose = base64::engine::general_purpose::STANDARD;
const IDMSA: &str = "https://idmsa.apple.com/appleauth/auth";
const OLYMPUS: &str = "https://appstoreconnect.apple.com/olympus/v1";
const LIST_DOWNLOADS: &str = "https://developer.apple.com/services-account/QH65B2/downloadws/listDownloads.action";
const UA: &str = "Mozilla/5.0 (X11; Linux x86_64) x86Sim";
/// the keyring item's attributes (secret-tool)
const SECRET_ATTRS: [&str; 2] = ["service", "x86sim-apple-account"];
/// How long a two-factor prompt waits for the code
pub const CODE_TIMEOUT: Duration = Duration::from_secs(600);

// ---------------------------------------------------------------------------------------------------------------
// the session and where it is kept

/// What a sign-in leaves: the cookies (the secret part) and what status shows
#[derive(Serialize, Deserialize, Clone, Default, Debug)]
pub struct Session {
    pub apple_id: String,
    /// curl's cookie jar (Netscape format)
    pub cookies: String,
    /// seconds since the epoch
    pub signed_in: u64,
    pub name: String,
    pub provider: String,
}

/// The non-secret part of the session, kept beside it so status needs no keyring unlock
#[derive(Serialize, Deserialize, Clone, Default, Debug)]
pub struct Meta {
    pub apple_id: String,
    pub name: String,
    /// "keyring" or "file"
    pub store: String,
    pub signed_in: u64,
    /// until when Apple skips two-factor for this computer (the trust cookie's expiry), seconds since the epoch
    pub trusted_until: u64,
}

fn config_dir() -> PathBuf {
    std::env::var_os("XDG_CONFIG_HOME").filter(|v| !v.is_empty()).map(PathBuf::from).unwrap_or_else(|| home().join(".config")).join("x86sim")
}
fn meta_path() -> PathBuf {
    config_dir().join("apple-account.json")
}
fn file_store_path() -> PathBuf {
    config_dir().join("apple-account.session")
}

fn home() -> PathBuf {
    std::env::var_os("HOME").map(PathBuf::from).unwrap_or_else(|| PathBuf::from("/"))
}

fn now() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0)
}

fn write_private(p: &Path, data: &[u8]) -> Result<()> {
    use std::os::unix::fs::OpenOptionsExt;
    if let Some(d) = p.parent() {
        std::fs::create_dir_all(d)?;
    }
    let tmp = p.with_extension("tmp");
    let _ = std::fs::remove_file(&tmp);
    let mut f = std::fs::OpenOptions::new().write(true).create_new(true).mode(0o600).open(&tmp).with_context(|| format!("writing {}", tmp.display()))?;
    f.write_all(data)?;
    drop(f);
    std::fs::rename(&tmp, p)?;
    Ok(())
}

fn secret_tool() -> Option<PathBuf> {
    crate::dev::which("secret-tool")
}

/// Keeps the session: the keyring when there is one, else a 0600 file. Returns where it went.
fn store_session(s: &Session) -> Result<&'static str> {
    // base64: secret-tool's round trip turns the JSON's \n / \t escapes into the characters themselves
    let data = B64.encode(serde_json::to_vec(s)?).into_bytes();
    let _ = std::fs::remove_file(file_store_path());
    if let Some(st) = secret_tool() {
        let mut c = Command::new(st);
        c.args(["store", "--label", "x86Sim Apple Account"]).args(SECRET_ATTRS).stdin(Stdio::piped()).stdout(Stdio::null()).stderr(Stdio::piped());
        if let Ok(mut ch) = c.spawn() {
            if let Some(mut i) = ch.stdin.take() {
                let _ = i.write_all(&data);
            }
            if let Ok(o) = ch.wait_with_output() {
                if o.status.success() {
                    return Ok("keyring");
                }
            }
        }
    }
    write_private(&file_store_path(), &data)?;
    Ok("file")
}

/// The kept session, if any (the keyring first)
pub fn load_session() -> Option<Session> {
    if let Some(st) = secret_tool() {
        if let Ok(o) = Command::new(st).arg("lookup").args(SECRET_ATTRS).stdin(Stdio::null()).stderr(Stdio::null()).output() {
            if o.status.success() && !o.stdout.is_empty() {
                if let Some(s) = parse_stored(&o.stdout) {
                    return Some(s);
                }
            }
        }
    }
    std::fs::read(file_store_path()).ok().and_then(|b| parse_stored(&b))
}

/// A stored session: base64 of its JSON, or the JSON itself (with control characters a keyring round trip unescaped)
fn parse_stored(b: &[u8]) -> Option<Session> {
    let t = String::from_utf8_lossy(b);
    if let Ok(j) = B64.decode(t.trim()) {
        if let Ok(s) = serde_json::from_slice(&j) {
            return Some(s);
        }
    }
    let fixed: String = t.trim_end_matches('\n').chars().map(|c| match c { '\n' => "\\n".to_string(), '\t' => "\\t".to_string(), '\r' => "\\r".to_string(), c => c.to_string() }).collect();
    serde_json::from_str(&fixed).ok()
}

pub fn load_meta() -> Option<Meta> {
    std::fs::read(meta_path()).ok().and_then(|b| serde_json::from_slice(&b).ok())
}

fn save(s: &Session) -> Result<Meta> {
    let store = store_session(s)?;
    let m = Meta { apple_id: s.apple_id.clone(), name: s.name.clone(), store: store.into(), signed_in: s.signed_in, trusted_until: trust_expiry(&s.cookies) };
    write_private(&meta_path(), &serde_json::to_vec_pretty(&m)?)?;
    Ok(m)
}

/// Forgets the session (keyring item, file and the status file)
pub fn logout() -> Result<bool> {
    let had = load_meta().is_some() || load_session().is_some();
    if let Some(st) = secret_tool() {
        let _ = Command::new(st).arg("clear").args(SECRET_ATTRS).stdin(Stdio::null()).stderr(Stdio::null()).status();
    }
    let _ = std::fs::remove_file(file_store_path());
    let _ = std::fs::remove_file(meta_path());
    Ok(had)
}

/// The "trust this browser" cookie's expiry: idmsa's DES<hash> cookie (two-factor is skipped while it lasts)
fn trust_expiry(jar: &str) -> u64 {
    jar.lines()
        .filter_map(|l| {
            let l = l.strip_prefix("#HttpOnly_").unwrap_or(l);
            let f: Vec<&str> = l.split('\t').collect();
            (f.len() >= 7 && f[0].contains("apple.com") && f[5].starts_with("DES")).then(|| f[4].parse::<u64>().ok()).flatten()
        })
        .max()
        .unwrap_or(0)
}

// ---------------------------------------------------------------------------------------------------------------
// HTTP through curl, with a private cookie jar

struct Resp {
    status: u16,
    headers: Vec<(String, String)>,
    body: Vec<u8>,
}

impl Resp {
    fn header(&self, name: &str) -> Option<&str> {
        self.headers.iter().rev().find(|(k, _)| k.eq_ignore_ascii_case(name)).map(|(_, v)| v.as_str())
    }
    fn json(&self) -> Value {
        serde_json::from_slice(&self.body).unwrap_or(Value::Null)
    }
    /// Apple's own words for an error (idmsa's serviceErrors / validationErrors, the download service's userString)
    fn apple_message(&self) -> String {
        let v = self.json();
        for k in ["serviceErrors", "validationErrors"] {
            if let Some(e) = v.get(k).and_then(|e| e.as_array()).and_then(|a| a.first()) {
                let m = e.get("message").and_then(|m| m.as_str()).unwrap_or("");
                let c = e.get("code").and_then(|m| m.as_str()).unwrap_or("");
                if !m.is_empty() {
                    return if c.is_empty() { m.to_string() } else { format!("{m} ({c})") };
                }
            }
        }
        v.get("userString").and_then(|m| m.as_str()).map(String::from).unwrap_or_default()
    }
    fn apple_code(&self) -> String {
        let v = self.json();
        v.get("serviceErrors").and_then(|e| e.as_array()).and_then(|a| a.first()).and_then(|e| e.get("code")).and_then(|c| c.as_str()).unwrap_or("").to_string()
    }
}

/// A private directory for the cookie jar and curl's scratch files: in the runtime dir (memory, user-only), removed on drop
struct Http {
    dir: PathBuf,
}

impl Http {
    fn new(cookies: &str) -> Result<Http> {
        use std::os::unix::fs::DirBuilderExt;
        let base = std::env::var_os("XDG_RUNTIME_DIR").filter(|v| !v.is_empty()).map(PathBuf::from).unwrap_or_else(|| config_dir().join("run"));
        std::fs::create_dir_all(&base)?;
        let dir = base.join(format!("x86sim-account-{}-{}", std::process::id(), now()));
        std::fs::DirBuilder::new().mode(0o700).create(&dir).with_context(|| format!("creating {}", dir.display()))?;
        let h = Http { dir };
        write_private(&h.jar(), cookies.as_bytes())?;
        Ok(h)
    }
    fn jar(&self) -> PathBuf {
        self.dir.join("cookies")
    }
    fn cookies(&self) -> String {
        std::fs::read_to_string(self.jar()).unwrap_or_default()
    }
    /// A GET that follows redirects (a web page)
    fn req_follow(&self, url: &str) -> Result<Resp> {
        self.req_opts("GET", url, &[("Accept", "text/html")], None, true)
    }
    fn req(&self, method: &str, url: &str, headers: &[(&str, &str)], body: Option<&[u8]>) -> Result<Resp> {
        self.req_opts(method, url, headers, body, false)
    }
    fn req_opts(&self, method: &str, url: &str, headers: &[(&str, &str)], body: Option<&[u8]>, follow: bool) -> Result<Resp> {
        let hfile = self.dir.join("req-headers");
        let mut hs = format!("User-Agent: {UA}\n");
        for (k, v) in headers {
            hs.push_str(&format!("{k}: {v}\n"));
        }
        write_private(&hfile, hs.as_bytes())?;
        let (dout, bout) = (self.dir.join("resp-headers"), self.dir.join("resp-body"));
        let _ = std::fs::remove_file(&dout);
        let _ = std::fs::remove_file(&bout);
        let mut c = Command::new("curl");
        c.args(["-sS", "--compressed", "--max-time", "90", "-X", method, "-H"])
            .arg(format!("@{}", hfile.display()))
            .arg("-b")
            .arg(self.jar())
            .arg("-c")
            .arg(self.jar())
            .arg("-D")
            .arg(&dout)
            .arg("-o")
            .arg(&bout);
        if body.is_some() {
            c.args(["--data-binary", "@-"]);
        }
        if follow {
            c.args(["-L", "--max-redirs", "8"]);
        }
        c.arg(url).stdin(if body.is_some() { Stdio::piped() } else { Stdio::null() }).stdout(Stdio::null()).stderr(Stdio::piped());
        let mut ch = c.spawn().context("running curl")?;
        if let (Some(b), Some(mut i)) = (body, ch.stdin.take()) {
            i.write_all(b)?;
        }
        let o = ch.wait_with_output()?;
        let _ = std::fs::remove_file(&hfile);
        if !o.status.success() {
            bail!("{} {}: {}", method, url.split('?').next().unwrap_or(url), String::from_utf8_lossy(&o.stderr).trim());
        }
        let raw = std::fs::read_to_string(&dout).unwrap_or_default();
        // the last header block (after any 100 Continue)
        let block = raw.split("\r\n\r\n").filter(|b| b.starts_with("HTTP/")).last().unwrap_or("");
        let mut lines = block.lines();
        let status = lines.next().and_then(|l| l.split_whitespace().nth(1)).and_then(|s| s.parse().ok()).unwrap_or(0);
        let headers = lines.filter_map(|l| l.split_once(':').map(|(k, v)| (k.trim().to_string(), v.trim().to_string()))).collect();
        let body = std::fs::read(&bout).unwrap_or_default();
        let _ = std::fs::remove_file(&dout);
        let _ = std::fs::remove_file(&bout);
        Ok(Resp { status, headers, body })
    }
}

impl Drop for Http {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.dir);
    }
}

// ---------------------------------------------------------------------------------------------------------------
// SRP-6a (Apple's variant: x = H(salt | H(":" | PBKDF2(H(password)))), M1 over the unpadded A and B)

const N_HEX: &str = "AC6BDB41324A9A9BF166DE5E1389582FAF72B6651987EE07FC3192943DB56050A37329CBB4A099ED8193E0757767A13DD52312AB4B03310DCD7F48A9DA04FD50E8083969EDB767B0CF6095179A163AB3661A05FBD5FAAAE82918A9962F0B93B855F97993EC975EEAA80D740ADBF4FF747359D041D5C33EA71D281E446B14773BCA97B43A23FB801676BD207A436C6481F1D2B9078717461A5B9D32E688F87748544523B524B0D57D5EA77A2775D2ECFA032CFBDBF52FB3786160279004E57AE6AF874E7303CE53299CCC041C7BC308D82A5698F3A8D0C38271AE35F8E9DBFBB694B5C803D89F7AE435DE236D525F54759B65E372FCD68EF20FA7111F9E4AFF73";

fn sha256(parts: &[&[u8]]) -> [u8; 32] {
    let mut h = Sha256::new();
    for p in parts {
        h.update(p);
    }
    h.finalize().into()
}

fn pad(b: &[u8], n: usize) -> Vec<u8> {
    let mut v = vec![0u8; n.saturating_sub(b.len())];
    v.extend_from_slice(b);
    v
}

fn random_bytes(n: usize) -> Result<Vec<u8>> {
    let mut b = vec![0u8; n];
    std::fs::File::open("/dev/urandom")?.read_exact(&mut b)?;
    Ok(b)
}

struct Srp {
    n: BigUint,
    g: BigUint,
    a: BigUint,
    pub_a: BigUint,
}

impl Srp {
    fn new() -> Result<Srp> {
        let n = BigUint::parse_bytes(N_HEX.as_bytes(), 16).unwrap();
        let g = BigUint::from(2u32);
        let a = BigUint::from_bytes_be(&random_bytes(32)?);
        let pub_a = g.modpow(&a, &n);
        Ok(Srp { n, g, a, pub_a })
    }
    fn a_bytes(&self) -> Vec<u8> {
        self.pub_a.to_bytes_be()
    }
    /// M1 and the expected M2 for the server's challenge
    fn proof(&self, user: &str, password: &str, salt: &[u8], iterations: u32, fo: bool, raw_b: &[u8]) -> Result<(Vec<u8>, Vec<u8>)> {
        let (n, g) = (&self.n, &self.g);
        let len = n.to_bytes_be().len();
        let b = BigUint::from_bytes_be(raw_b);
        anyhow::ensure!(&b % n != BigUint::from(0u32), "Apple's sign-in sent an invalid SRP value");
        let hp = sha256(&[password.as_bytes()]);
        let input: Vec<u8> = if fo { hex(&hp).into_bytes() } else { hp.to_vec() };
        let mut key = [0u8; 32];
        pbkdf2::pbkdf2_hmac::<Sha256>(&input, salt, iterations, &mut key);
        let x = BigUint::from_bytes_be(&sha256(&[salt, &sha256(&[b":", &key])]));
        let a_bytes = self.a_bytes();
        let u = BigUint::from_bytes_be(&sha256(&[&pad(&a_bytes, len), &pad(raw_b, len)]));
        let k = BigUint::from_bytes_be(&sha256(&[&n.to_bytes_be(), &pad(&g.to_bytes_be(), len)]));
        let kgx = (&k * g.modpow(&x, n)) % n;
        let base = ((&b + n) - kgx) % n;
        let s = base.modpow(&(&self.a + &u * &x), n);
        let kk = sha256(&[&s.to_bytes_be()]);
        let hn = sha256(&[&n.to_bytes_be()]);
        let hg = sha256(&[&pad(&g.to_bytes_be(), len)]);
        let xor: Vec<u8> = hn.iter().zip(hg.iter()).map(|(a, b)| a ^ b).collect();
        let hi = sha256(&[user.as_bytes()]);
        let m1 = sha256(&[&xor, &hi, salt, &a_bytes, raw_b, &kk]).to_vec();
        let m2 = sha256(&[&a_bytes, &m1, &kk]).to_vec();
        Ok((m1, m2))
    }
}

pub fn hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{x:02x}")).collect()
}

/// Apple's hashcash for the sign-in: "1:bits:date:challenge::counter" whose SHA-1 starts with `bits` zero bits
fn hashcash(bits: u32, challenge: &str) -> String {
    let date = {
        let t = now() as i64;
        let (d, s) = (t.div_euclid(86400), t.rem_euclid(86400));
        let (y, m, dd) = civil(d);
        format!("{:04}{:02}{:02}{:02}{:02}{:02}", y, m, dd, s / 3600, s / 60 % 60, s % 60)
    };
    for counter in 0u64.. {
        let s = format!("1:{bits}:{date}:{challenge}::{counter}");
        let d = sha1_smol::Sha1::from(s.as_bytes()).digest().bytes();
        let zero = d.iter().map(|b| b.leading_zeros()).scan(true, |go, z| {
            if !*go {
                return None;
            }
            *go = z == 8;
            Some(z)
        });
        if zero.sum::<u32>() >= bits {
            return s;
        }
    }
    unreachable!()
}

/// days since 1970-01-01 -> (year, month, day) (Howard Hinnant's civil_from_days)
fn civil(z: i64) -> (i64, u32, u32) {
    let z = z + 719468;
    let era = z.div_euclid(146097);
    let doe = z - era * 146097;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32;
    (yoe + era * 400 + i64::from(m <= 2), m, d)
}

pub fn date(t: u64) -> String {
    let (y, m, d) = civil(t as i64 / 86400);
    format!("{y:04}-{m:02}-{d:02}")
}

// ---------------------------------------------------------------------------------------------------------------
// the sign-in

/// A trusted phone number (two-factor by SMS)
#[derive(Clone, Debug)]
pub struct Phone {
    pub id: u64,
    pub number: String,
}

/// What a two-factor prompt is about
#[derive(Clone, Debug)]
pub struct CodePrompt {
    /// "device" (pushed to the account's trusted devices), "sms" (texted to `sms_to`) or "xtool" (xtool's own sign-in)
    pub sent: String,
    pub sms_to: String,
    pub length: usize,
    /// the trusted numbers an SMS can go to instead
    pub phones: Vec<Phone>,
    /// the last code was wrong
    pub retry: bool,
}

pub enum CodeAnswer {
    Code(String),
    /// send an SMS to this trusted number instead
    Sms(u64),
}

/// The person at the keyboard: progress lines, the two-factor code and a choice (xtool's team)
pub trait Ask {
    fn say(&mut self, line: &str);
    fn code(&mut self, p: &CodePrompt) -> Result<CodeAnswer>;
    fn choose(&mut self, title: &str, options: &[String]) -> Result<usize>;
}

fn auth_headers<'a>(key: &'a str, sess: &'a (String, String)) -> Vec<(&'a str, &'a str)> {
    let mut h = vec![("Content-Type", "application/json"), ("Accept", "application/json, text/javascript"), ("X-Requested-With", "XMLHttpRequest"), ("X-Apple-Widget-Key", key)];
    if !sess.0.is_empty() {
        h.push(("X-Apple-ID-Session-Id", sess.0.as_str()));
        h.push(("scnt", sess.1.as_str()));
    }
    h
}

/// Signs in with the Apple ID and password (two-factor through `ask`), keeps the session and returns its status.
/// `password` is wiped before this returns.
pub fn login(apple_id: &str, password: &mut String, ask: &mut dyn Ask) -> Result<Status> {
    let r = login_inner(apple_id.trim(), password, ask);
    // never keep the password around
    unsafe {
        for b in password.as_mut_vec().iter_mut() {
            std::ptr::write_volatile(b, 0);
        }
    }
    password.clear();
    r
}

fn login_inner(apple_id: &str, password: &str, ask: &mut dyn Ask) -> Result<Status> {
    anyhow::ensure!(!apple_id.is_empty(), "no Apple ID given");
    anyhow::ensure!(!password.is_empty(), "no password given");
    // the old session's cookies: Apple's "trusted browser" cookie skips two-factor while it lasts
    let old = load_session().filter(|s| s.apple_id.eq_ignore_ascii_case(apple_id)).map(|s| s.cookies).unwrap_or_default();
    let http = Http::new(&old)?;
    ask.say("Contacting Apple…");
    let key = widget_key(&http)?;
    let none = (String::new(), String::new());
    let hc = http.req("GET", &format!("{IDMSA}/signin?widgetKey={key}"), &[("Accept", "text/html")], None)?;
    let hashcash = match (hc.header("X-Apple-HC-Bits").and_then(|b| b.parse::<u32>().ok()), hc.header("X-Apple-HC-Challenge")) {
        (Some(bits), Some(ch)) => Some(hashcash(bits, ch)),
        _ => None,
    };
    let srp = Srp::new()?;
    let init = http.req(
        "POST",
        &format!("{IDMSA}/signin/init"),
        &auth_headers(&key, &none),
        Some(serde_json::to_vec(&json!({"a": B64.encode(srp.a_bytes()), "accountName": apple_id, "protocols": ["s2k", "s2k_fo"]}))?.as_slice()),
    )?;
    if init.status != 200 {
        bail!("{}", sign_in_error(&init, apple_id));
    }
    let v = init.json();
    let field = |k: &str| v.get(k).and_then(|x| x.as_str()).map(String::from).with_context(|| format!("Apple's sign-in answer had no {k}"));
    let salt = B64.decode(field("salt")?)?;
    let b = B64.decode(field("b")?)?;
    let c = field("c")?;
    let proto = field("protocol")?;
    let iterations = v.get("iteration").and_then(|x| x.as_u64()).context("Apple's sign-in answer had no iteration count")? as u32;
    anyhow::ensure!(proto == "s2k" || proto == "s2k_fo", "Apple asked for sign-in protocol {proto:?}, which x86Sim doesn't speak");
    let (m1, m2) = srp.proof(apple_id, password, &salt, iterations, proto == "s2k_fo", &b)?;
    let mut hs = auth_headers(&key, &none);
    if let Some(h) = &hashcash {
        hs.push(("X-Apple-HC", h.as_str()));
    }
    let done = http.req(
        "POST",
        &format!("{IDMSA}/signin/complete?isRememberMeEnabled=true"),
        &hs,
        Some(serde_json::to_vec(&json!({"accountName": apple_id, "rememberMe": true, "m1": B64.encode(&m1), "c": c, "m2": B64.encode(&m2)}))?.as_slice()),
    )?;
    match done.status {
        200 => ask.say("Signed in (this computer is still trusted: no code needed)"),
        409 => {
            let sess = (done.header("X-Apple-ID-Session-Id").unwrap_or("").to_string(), done.header("scnt").unwrap_or("").to_string());
            anyhow::ensure!(!sess.0.is_empty(), "Apple asked for two-factor authentication but sent no session");
            two_factor(&http, &key, &sess, ask)?;
        }
        412 => bail!(
            "Apple wants something acknowledged on this account first (new terms, a privacy notice or a security upgrade): sign in once at https://appleid.apple.com or https://developer.apple.com/account in a browser, then try again"
        ),
        _ => bail!("{}", sign_in_error(&done, apple_id)),
    }
    // who it is (App Store Connect's session; a plain Apple ID without a developer account still gets one)
    let me = http.req("GET", &format!("{OLYMPUS}/session"), &[("Accept", "application/json")], None)?;
    let mv = me.json();
    let name = mv.pointer("/user/fullName").and_then(|x| x.as_str()).unwrap_or("").to_string();
    let provider = mv.pointer("/provider/name").and_then(|x| x.as_str()).unwrap_or("").to_string();
    let s = Session { apple_id: apple_id.to_string(), cookies: http.cookies(), signed_in: now(), name, provider };
    drop(http);
    let m = save(&s)?;
    ask.say(&format!("Session kept in the {}", if m.store == "keyring" { "Secret Service keyring" } else { "0600 file ~/.config/x86sim/apple-account.session (no keyring found)" }));
    status(true)
}

/// The sign-in widget key of developer.apple.com's own sign-in page (the page /account redirects to carries it)
fn widget_key(http: &Http) -> Result<String> {
    let page = http.req_follow("https://developer.apple.com/account")?;
    let text = String::from_utf8_lossy(&page.body);
    let key = text.find("widgetKey").map(|i| &text[i + 9..]).and_then(|r| {
        let r = r.trim_start_matches(|c: char| c == '"' || c == '\\' || c == ':' || c == '=' || c == ' ' || c == '\'');
        let k: String = r.chars().take_while(|c| c.is_ascii_hexdigit()).collect();
        (k.len() >= 32).then_some(k)
    });
    if let Some(k) = key {
        return Ok(k);
    }
    // App Store Connect's sign-in configuration (older Xcode download tools read the key there)
    let cfg = http.req("GET", &format!("{OLYMPUS}/app/config?hostname=itunesconnect.apple.com"), &[("Accept", "application/json")], None)?;
    cfg.json().get("authServiceKey").and_then(|v| v.as_str()).map(String::from).with_context(|| format!("couldn't find Apple's sign-in key (developer.apple.com/account HTTP {}, App Store Connect HTTP {})", page.status, cfg.status))
}

fn sign_in_error(r: &Resp, apple_id: &str) -> String {
    let msg = r.apple_message();
    let code = r.apple_code();
    match (r.status, code.as_str()) {
        (401, _) | (_, "-20101") => format!("wrong Apple ID or password for {apple_id}{}", if msg.is_empty() { String::new() } else { format!(" (Apple: {msg})") }),
        (403, _) | (_, "-20209") | (_, "-20283") => {
            format!("Apple refused the sign-in: this Apple ID looks locked or disabled{}. Unlock it at https://iforgot.apple.com", if msg.is_empty() { String::new() } else { format!(" ({msg})") })
        }
        (s, _) => format!("Apple's sign-in failed (HTTP {s}){}", if msg.is_empty() { String::new() } else { format!(": {msg}") }),
    }
}

fn two_factor(http: &Http, key: &str, sess: &(String, String), ask: &mut dyn Ask) -> Result<()> {
    let opts = http.req("GET", IDMSA, &auth_headers(key, sess), None)?;
    let v = opts.json();
    if v.pointer("/securityCode/securityCodeLocked").and_then(|x| x.as_bool()) == Some(true) || v.pointer("/securityCode/tooManyCodesSent").and_then(|x| x.as_bool()) == Some(true) {
        bail!("Apple has locked two-factor codes for now (too many codes sent or tried): wait a while and sign in again");
    }
    let phones: Vec<Phone> = v
        .get("trustedPhoneNumbers")
        .and_then(|x| x.as_array())
        .map(|a| a.iter().filter_map(|p| Some(Phone { id: p.get("id")?.as_u64()?, number: p.get("numberWithDialCode").or(p.get("obfuscatedNumber")).and_then(|n| n.as_str()).unwrap_or("?").to_string() })).collect())
        .unwrap_or_default();
    let length = v.pointer("/securityCode/length").and_then(|x| x.as_u64()).unwrap_or(6) as usize;
    let no_devices = v.get("noTrustedDevices").and_then(|x| x.as_bool()).unwrap_or(false);
    let mut prompt = CodePrompt { sent: "device".into(), sms_to: String::new(), length, phones: phones.clone(), retry: false };
    // no trusted device: Apple texts the only number (or the one picked)
    let send_sms = |id: u64, prompt: &mut CodePrompt| -> Result<()> {
        let r = http.req("PUT", &format!("{IDMSA}/verify/phone"), &auth_headers(key, sess), Some(serde_json::to_vec(&json!({"phoneNumber": {"id": id}, "mode": "sms"}))?.as_slice()))?;
        if r.status >= 300 {
            bail!("Apple couldn't send the SMS (HTTP {}): {}", r.status, r.apple_message());
        }
        prompt.sent = "sms".into();
        prompt.sms_to = phones.iter().find(|p| p.id == id).map(|p| p.number.clone()).unwrap_or_default();
        Ok(())
    };
    if no_devices {
        let id = match phones.len() {
            0 => bail!("this Apple ID has two-factor authentication but no trusted device or phone number Apple can send a code to"),
            1 => phones[0].id,
            _ => phones[ask.choose("Send the code by SMS to", &phones.iter().map(|p| p.number.clone()).collect::<Vec<_>>())?.min(phones.len() - 1)].id,
        };
        send_sms(id, &mut prompt)?;
    }
    let mut tries = 0;
    loop {
        match ask.code(&prompt)? {
            CodeAnswer::Sms(id) => {
                send_sms(id, &mut prompt)?;
                prompt.retry = false;
                continue;
            }
            CodeAnswer::Code(code) => {
                let code = code.trim().to_string();
                let r = if prompt.sent == "sms" {
                    let id = phones.iter().find(|p| p.number == prompt.sms_to).map(|p| p.id).unwrap_or(1);
                    http.req(
                        "POST",
                        &format!("{IDMSA}/verify/phone/securitycode"),
                        &auth_headers(key, sess),
                        Some(serde_json::to_vec(&json!({"securityCode": {"code": code}, "phoneNumber": {"id": id}, "mode": "sms"}))?.as_slice()),
                    )?
                } else {
                    http.req("POST", &format!("{IDMSA}/verify/trusteddevice/securitycode"), &auth_headers(key, sess), Some(serde_json::to_vec(&json!({"securityCode": {"code": code}}))?.as_slice()))?
                };
                if r.status < 300 {
                    break;
                }
                tries += 1;
                if r.status == 400 && tries < 3 {
                    prompt.retry = true;
                    continue;
                }
                bail!("Apple didn't take the code (HTTP {}){}", r.status, if r.apple_message().is_empty() { String::new() } else { format!(": {}", r.apple_message()) });
            }
        }
    }
    // trust this computer: the next sign-ins skip two-factor for a while (Apple's DES cookie)
    let t = http.req("GET", &format!("{IDMSA}/2sv/trust"), &auth_headers(key, sess), None)?;
    if t.status >= 300 {
        bail!("Apple took the code but didn't finish the sign-in (HTTP {}): {}", t.status, t.apple_message());
    }
    ask.say("Two-factor authentication done");
    Ok(())
}

/// A code prompt that waits on a channel (the launcher's sign-in form answers it); gives up after CODE_TIMEOUT
pub fn wait_code(rx: &std::sync::mpsc::Receiver<CodeAnswer>) -> Result<CodeAnswer> {
    rx.recv_timeout(CODE_TIMEOUT).map_err(|_| anyhow!("no two-factor code within {} minutes: sign in again", CODE_TIMEOUT.as_secs() / 60))
}

// ---------------------------------------------------------------------------------------------------------------
// signing: xtool's own sign-in (its state)

/// xtool's sign-in state (`xtool auth status`): (Apple ID, team, token expiry) when signed in
pub fn xtool_status() -> Option<(String, String, String)> {
    let xt = crate::dev::which("xtool").or_else(|| Some(home().join(".local/bin/xtool")).filter(|p| p.exists()))?;
    let mut c = crate::dev::command(xt);
    c.args(["auth", "status"]).stdin(Stdio::null()).stderr(Stdio::null());
    let o = c.output().ok()?;
    let t = String::from_utf8_lossy(&o.stdout);
    if !t.contains("Logged in") {
        return None;
    }
    let get = |k: &str| t.lines().find_map(|l| l.trim().trim_start_matches("- ").strip_prefix(k).map(|v| v.trim().to_string())).unwrap_or_default();
    Some((get("Apple ID:"), get("Team ID:"), get("Token expiry:")))
}

// ---------------------------------------------------------------------------------------------------------------
// status

#[derive(Serialize, Clone, Default, Debug)]
pub struct Status {
    pub signed_in: bool,
    pub apple_id: String,
    pub name: String,
    /// "keyring" / "file"
    pub store: String,
    pub signed_in_on: String,
    /// the session still works with Apple (checked live when asked)
    pub session_ok: Option<bool>,
    /// developer downloads: "ok", or why not
    pub downloads: String,
    /// signing (xtool): "ok: Apple ID, team T, until D", or why not
    pub signing: String,
    /// two-factor is skipped until (YYYY-MM-DD), "" when unknown
    pub trusted_until: String,
    /// what to do when (renewal)
    pub renew: String,
}

/// The account's state; `live` asks Apple whether the session still works and what it can download
pub fn status(live: bool) -> Result<Status> {
    let mut st = Status::default();
    let xs = xtool_status();
    st.signing = match &xs {
        Some((id, team, exp)) => format!("ok: xtool signed in as {id}, team {team}, token until {exp}"),
        None => "xtool not signed in (x86sim dev auth)".into(),
    };
    let Some(m) = load_meta() else {
        st.renew = "not signed in: x86sim account login".into();
        st.downloads = "needs a sign-in".into();
        return Ok(st);
    };
    st.signed_in = true;
    st.apple_id = m.apple_id.clone();
    st.name = m.name.clone();
    st.store = m.store.clone();
    st.signed_in_on = date(m.signed_in);
    if m.trusted_until > 0 {
        st.trusted_until = date(m.trusted_until);
    }
    if let Some((id, _, _)) = &xs {
        if !id.eq_ignore_ascii_case(&m.apple_id) {
            st.signing = format!("{} (a different Apple ID than this account's)", st.signing);
        }
    }
    if live {
        let s = load_session().context("the session is gone from the keyring: sign in again")?;
        let http = Http::new(&s.cookies)?;
        // developer.apple.com's download list: what the session is for (App Store Connect's own session, which only
        // gives the name at sign-in, ends within the hour)
        st.downloads = downloads_state(&http);
        let ok = st.downloads != "session expired";
        st.session_ok = Some(ok);
        // keep refreshed cookies
        let jar = http.cookies();
        drop(http);
        if ok && jar != s.cookies {
            let _ = save(&Session { cookies: jar, ..s });
        }
    } else {
        st.downloads = "not checked (x86sim account status checks it)".into();
    }
    st.renew = match (st.session_ok, m.trusted_until) {
        (Some(false), t) if t > now() => format!("session expired: sign in again (password only, no code until {})", date(t)),
        (Some(false), _) => "session expired: sign in again (password and a two-factor code)".into(),
        (_, t) if t > now() => format!("Apple ends web sessions after a while (often a day or so): signing in again then needs the password only, no code until {}", date(t)),
        _ => "Apple ends web sessions after a while (often a day or so): sign in again then".into(),
    };
    Ok(st)
}

fn downloads_state(http: &Http) -> String {
    match http.req("POST", LIST_DOWNLOADS, &[("Accept", "application/json"), ("Content-Type", "application/json")], Some(b"{}")) {
        Ok(r) if r.status == 200 => {
            let v = r.json();
            match v.get("resultCode").and_then(|x| x.as_i64()) {
                Some(0) => "ok".into(),
                Some(c) => agreement_hint(c, &r.apple_message()),
                None => format!("unexpected answer from developer.apple.com (HTTP {})", r.status),
            }
        }
        Ok(r) if r.status == 401 || r.status == 403 => "session expired".into(),
        Ok(r) => format!("developer.apple.com answered HTTP {}", r.status),
        Err(e) => format!("{e:#}"),
    }
}

fn agreement_hint(code: i64, msg: &str) -> String {
    format!(
        "developer.apple.com refused the download list ({code}{}): accept the Apple Developer Agreement once at https://developer.apple.com/account (any Apple ID, free), then try again",
        if msg.is_empty() { String::new() } else { format!(": {msg}") }
    )
}
