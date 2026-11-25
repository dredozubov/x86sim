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
//!
//! Downloads: developer.apple.com's download list (listDownloads.action), the ADCDownloadAuth cookie from
//! devcenter/download.action, then download.developer.apple.com with curl (resumable: a .part file). The .xip is
//! checked before use: its size, the xar table of contents' checksum, Apple's signature on it (the certificate chain
//! in the file up to Apple Root CA, pinned by fingerprint; openssl), and the archived checksum of its content.
//!
//! Signing (xtool) can't take these cookies: Apple's developer services want a GrandSlam token that needs anisette
//! data. So `login` can also drive xtool's own password sign-in once, with the user's consent, from the same entry of
//! the password (and a second code if Apple asks for one): one sign-in for the user.
use anyhow::{anyhow, bail, Context, Result};
use base64::Engine as _;
use num_bigint::BigUint;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

const B64: base64::engine::GeneralPurpose = base64::engine::general_purpose::STANDARD;
const IDMSA: &str = "https://idmsa.apple.com/appleauth/auth";
const OLYMPUS: &str = "https://appstoreconnect.apple.com/olympus/v1";
const LIST_DOWNLOADS: &str = "https://developer.apple.com/services-account/QH65B2/downloadws/listDownloads.action";
const DOWNLOAD_AUTH: &str = "https://developer.apple.com/devcenter/download.action?path=";
const DOWNLOAD_HOST: &str = "https://download.developer.apple.com";
const UA: &str = "Mozilla/5.0 (X11; Linux x86_64) x86Sim";
/// the keyring item's attributes (secret-tool)
const SECRET_ATTRS: [&str; 2] = ["service", "x86sim-apple-account"];
/// Apple Root CA (the root of the certificate chain that signs Xcode.xip), SHA-256 of its DER
const APPLE_ROOT_CA_SHA256: &str = "b0b1730ecbc7ff4505142c49f1295e6eda6bcaed7e2c68c5be91b5a11001f024";
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
/// `password` is wiped before this returns. With `xtool`, xtool's own sign-in (signing) runs with the same password.
pub fn login(apple_id: &str, password: &mut String, xtool: bool, ask: &mut dyn Ask) -> Result<Status> {
    let r = login_inner(apple_id.trim(), password, xtool, ask);
    // never keep the password around
    unsafe {
        for b in password.as_mut_vec().iter_mut() {
            std::ptr::write_volatile(b, 0);
        }
    }
    password.clear();
    r
}

fn login_inner(apple_id: &str, password: &str, xtool: bool, ask: &mut dyn Ask) -> Result<Status> {
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
    if xtool {
        signing_login(apple_id, password, ask)?;
    }
    status(true)
}

/// Signs xtool in with the Apple ID unless it already is (its token lasts about a year; a new sign-in replaces it)
fn signing_login(apple_id: &str, password: &str, ask: &mut dyn Ask) -> Result<()> {
    match xtool_status() {
        Some((id, team, exp)) if id.eq_ignore_ascii_case(apple_id) => {
            ask.say(&format!("xtool is already signed in as {id} (team {team}, until {exp}): kept"));
            Ok(())
        }
        _ => xtool_login(apple_id, password, ask),
    }
}

/// Only the signing sign-in (xtool), with the password asked once: for when the account is signed in but xtool isn't
pub fn login_signing(apple_id: &str, password: &mut String, ask: &mut dyn Ask) -> Result<()> {
    let r = xtool_login(apple_id.trim(), password, ask);
    unsafe {
        for b in password.as_mut_vec().iter_mut() {
            std::ptr::write_volatile(b, 0);
        }
    }
    password.clear();
    r
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
// signing: xtool's own sign-in, driven once with the same password

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

/// Runs `xtool auth login --mode password`, typing the password and the code / team choice it asks for into its stdin
fn xtool_login(apple_id: &str, password: &str, ask: &mut dyn Ask) -> Result<()> {
    let xt = crate::dev::which("xtool").or_else(|| Some(home().join(".local/bin/xtool")).filter(|p| p.exists())).context("xtool is not installed (x86sim dev setup toolchain): signing not set up")?;
    ask.say("Signing in xtool (device builds and installs) with the same Apple ID…");
    let mut c = crate::dev::command(xt);
    c.args(["auth", "login", "--mode", "password", "--username", apple_id]).stdin(Stdio::piped()).stdout(Stdio::piped()).stderr(Stdio::piped());
    let mut ch = c.spawn().context("running xtool auth login")?;
    let mut stdin = ch.stdin.take().unwrap();
    stdin.write_all(password.as_bytes())?;
    stdin.write_all(b"\n")?;
    // stdout and stderr in one stream, read by a thread; prompts end without a newline
    let (tx, rx) = std::sync::mpsc::channel::<Vec<u8>>();
    for mut r in [Box::new(ch.stdout.take().unwrap()) as Box<dyn Read + Send>, Box::new(ch.stderr.take().unwrap())] {
        let tx = tx.clone();
        std::thread::spawn(move || {
            let mut b = [0u8; 4096];
            while let Ok(n) = r.read(&mut b) {
                if n == 0 || tx.send(b[..n].to_vec()).is_err() {
                    break;
                }
            }
        });
    }
    drop(tx);
    let mut buf = String::new();
    let mut teams: Vec<String> = vec![];
    let mut code_retry = false;
    let deadline = Instant::now() + Duration::from_secs(900);
    loop {
        let chunk = match rx.recv_timeout(Duration::from_millis(300)) {
            Ok(c) => Some(c),
            Err(std::sync::mpsc::RecvTimeoutError::Timeout) => None,
            Err(_) => break,
        };
        if Instant::now() > deadline {
            let _ = ch.kill();
            bail!("xtool's sign-in took too long");
        }
        let Some(chunk) = chunk else { continue };
        buf.push_str(&String::from_utf8_lossy(&chunk));
        // whole lines: progress (the heads-up text and team list included)
        while let Some(i) = buf.find('\n') {
            let line: String = buf.drain(..=i).collect();
            let l = line.trim();
            if !l.is_empty() && !l.starts_with("Password") {
                ask.say(&format!("xtool: {l}"));
            }
            // "[N] Team name (TEAMID)" lines of a team choice
            if let Some(rest) = l.strip_prefix('[').and_then(|r| r.split_once(']')) {
                teams.push(rest.1.trim().to_string());
            }
        }
        let tail = buf.trim_end();
        if tail.ends_with("Code:") {
            buf.clear();
            let p = CodePrompt { sent: "xtool".into(), sms_to: String::new(), length: 6, phones: vec![], retry: code_retry };
            code_retry = true;
            let code = match ask.code(&p)? {
                CodeAnswer::Code(c) => c,
                CodeAnswer::Sms(_) => bail!("xtool's sign-in takes the code from your trusted device only"),
            };
            stdin.write_all(code.trim().as_bytes())?;
            stdin.write_all(b"\n")?;
        } else if tail.starts_with("Choice (") && tail.ends_with(':') {
            buf.clear();
            let i = ask.choose("Development team for signing", &teams)?;
            stdin.write_all(format!("{i}\n").as_bytes())?;
            teams.clear();
        }
    }
    drop(stdin);
    let st = ch.wait()?;
    if !st.success() {
        bail!("xtool's sign-in failed (exit {}): device builds still need `x86sim dev auth`", st.code().unwrap_or(-1));
    }
    ask.say("xtool signed in: device builds and installs use this Apple ID");
    Ok(())
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
        None => "xtool not signed in (x86sim account login --signing)".into(),
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

// ---------------------------------------------------------------------------------------------------------------
// Xcode downloads

#[derive(Clone, Debug, Serialize)]
pub struct Release {
    pub name: String,
    pub version: String,
    /// /Developer_Tools/Xcode_27.2/Xcode_27.2.xip
    pub path: String,
    pub size: u64,
    pub prerelease: bool,
}

fn version_key(v: &str) -> Vec<u32> {
    v.split('.').map(|p| p.parse().unwrap_or(0)).collect()
}

/// The Xcode major the dev toolchain's Swift matches (dev.rs: 6.4 = Xcode 27, 6.3 = Xcode 26)
pub fn pinned_xcode_major() -> u32 {
    match crate::dev::SWIFT_VERSION.get(..3) {
        Some("6.3") => 26,
        _ => 27,
    }
}

fn session_http() -> Result<(Session, Http)> {
    let s = load_session().context("not signed in to an Apple Account: x86sim account login")?;
    let h = Http::new(&s.cookies)?;
    Ok((s, h))
}

fn list_with(http: &Http) -> Result<Vec<Release>> {
    let r = http.req("POST", LIST_DOWNLOADS, &[("Accept", "application/json"), ("Content-Type", "application/json")], Some(b"{}"))?;
    if r.status == 401 || r.status == 403 {
        bail!("the Apple Account session has expired: x86sim account login");
    }
    let v = r.json();
    match v.get("resultCode").and_then(|x| x.as_i64()) {
        Some(0) => {}
        Some(c) => bail!("{}", agreement_hint(c, &r.apple_message())),
        None => bail!("unexpected answer from developer.apple.com (HTTP {})", r.status),
    }
    let mut out = vec![];
    for d in v.get("downloads").and_then(|x| x.as_array()).into_iter().flatten() {
        let name = d.get("name").and_then(|x| x.as_str()).unwrap_or("");
        let Some(rest) = name.strip_prefix("Xcode ") else { continue };
        let version = rest.split_whitespace().next().unwrap_or("").to_string();
        if !version.chars().next().is_some_and(|c| c.is_ascii_digit()) {
            continue;
        }
        let lower = name.to_lowercase();
        let prerelease = lower.contains("beta") || lower.contains("release candidate") || lower.contains(" rc");
        // the .xip (one per release; the first if there are several)
        let file = d.get("files").and_then(|x| x.as_array()).into_iter().flatten().find(|f| f.get("remotePath").and_then(|x| x.as_str()).is_some_and(|p| p.ends_with(".xip")));
        if let Some(f) = file {
            if !out.iter().any(|r: &Release| r.name == name) {
                let path = f.get("remotePath").and_then(|x| x.as_str()).unwrap_or("").to_string();
                let size = f.get("fileSize").and_then(|x| x.as_u64()).unwrap_or(0);
                out.push(Release { name: name.to_string(), version, path, size, prerelease });
            }
        }
    }
    out.sort_by(|a, b| version_key(&b.version).cmp(&version_key(&a.version)).then(a.prerelease.cmp(&b.prerelease)));
    Ok(out)
}

/// The Xcode releases the account can download, newest first
pub fn list_xcodes() -> Result<Vec<Release>> {
    let (_, http) = session_http()?;
    list_with(&http)
}

/// The release a VERSION (or the pinned major's newest final release) means
pub fn pick_release(all: &[Release], version: Option<&str>) -> Result<Release> {
    if let Some(v) = version.map(str::trim).filter(|v| !v.is_empty()) {
        let v = v.trim_start_matches("Xcode").trim().trim_start_matches('_');
        let want = v.to_lowercase().replace('_', " ");
        if let Some(r) = all.iter().find(|r| r.name.to_lowercase() == format!("xcode {want}")) {
            return Ok(r.clone());
        }
        if let Some(r) = all.iter().find(|r| r.version == v && !r.prerelease) {
            return Ok(r.clone());
        }
        // a major or major.minor: its newest final release
        if let Some(r) = all.iter().find(|r| !r.prerelease && (r.version.starts_with(&format!("{v}.")) || r.version == v)) {
            return Ok(r.clone());
        }
        bail!("no Xcode {v} in the downloads this Apple Account sees (x86sim account download-xcode --list)");
    }
    let major = pinned_xcode_major();
    all.iter()
        .find(|r| !r.prerelease && version_key(&r.version).first() == Some(&major))
        .or_else(|| all.iter().find(|r| !r.prerelease))
        .cloned()
        .context("no Xcode release in the downloads this Apple Account sees")
}

fn gb(b: u64) -> String {
    format!("{:.2} GB", b as f64 / 1e9)
}

/// Downloads the release into DIR (resuming a .part left there), checks it and returns the .xip's path
pub fn download_xcode(version: Option<&str>, dir: &Path, say: &mut dyn FnMut(&str)) -> Result<PathBuf> {
    let (s, http) = session_http()?;
    say("== xcode: sign-in");
    let all = list_with(&http)?;
    let rel = pick_release(&all, version)?;
    let file = rel.path.rsplit('/').next().unwrap_or("Xcode.xip").to_string();
    std::fs::create_dir_all(dir)?;
    let out = dir.join(&file);
    say(&format!("{} ({}) from {DOWNLOAD_HOST}{}", rel.name, gb(rel.size), rel.path));
    if out.exists() && (rel.size == 0 || std::fs::metadata(&out)?.len() == rel.size) {
        say(&format!("{} is already there: checking it", out.display()));
    } else {
        let free = Some((crate::host::disk(dir).free_gb * 1e9) as u64).filter(|f| *f > 0);
        let part = out.with_extension("xip.part");
        let have = std::fs::metadata(&part).map(|m| m.len()).unwrap_or(0);
        if let Some(f) = free {
            anyhow::ensure!(f + have > rel.size + (1 << 30), "{} free in {}, the download needs {}", gb(f), dir.display(), gb(rel.size - have.min(rel.size)));
        }
        // the download cookie (ADCDownloadAuth) for this file
        let a = http.req("GET", &format!("{DOWNLOAD_AUTH}{}", rel.path), &[], None)?;
        if a.status >= 400 {
            bail!("developer.apple.com refused the download (HTTP {}): sign in again, or accept the agreement at https://developer.apple.com/account", a.status);
        }
        say("== xcode: download");
        if have > 0 {
            say(&format!("resuming at {}", gb(have)));
        }
        let mut c = Command::new("curl");
        c.args(["-sS", "--fail", "-L", "--retry", "5", "--retry-delay", "5", "-C", "-", "-H"])
            .arg(format!("User-Agent: {UA}"))
            .arg("-b")
            .arg(http.jar())
            .arg("-o")
            .arg(&part)
            .arg(format!("{DOWNLOAD_HOST}{}", rel.path))
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::piped());
        let mut ch = c.spawn().context("running curl")?;
        let t0 = Instant::now();
        let mut last = (Instant::now(), have);
        loop {
            if let Some(st) = ch.try_wait()? {
                let mut e = String::new();
                if let Some(mut er) = ch.stderr.take() {
                    let _ = er.read_to_string(&mut e);
                }
                if !st.success() {
                    bail!("the download stopped ({}): run it again to resume from {}", e.trim(), part.display());
                }
                break;
            }
            std::thread::sleep(Duration::from_secs(2));
            let n = std::fs::metadata(&part).map(|m| m.len()).unwrap_or(0);
            let rate = (n.saturating_sub(last.1)) as f64 / last.0.elapsed().as_secs_f64().max(0.1);
            last = (Instant::now(), n);
            let pct = if rel.size > 0 { n as f64 * 100.0 / rel.size as f64 } else { 0.0 };
            say(&format!("download: {pct:.1}% {} of {} {:.1} MB/s ({} s)", gb(n), gb(rel.size), rate / 1e6, t0.elapsed().as_secs()));
        }
        let n = std::fs::metadata(&part)?.len();
        anyhow::ensure!(rel.size == 0 || n == rel.size, "the download has {} of {}: run it again to resume", gb(n), gb(rel.size));
        std::fs::rename(&part, &out)?;
    }
    drop(http);
    let _ = s;
    say("== xcode: verify");
    verify_xip(&out, say)?;
    say(&format!("{} verified: signed by Apple", out.display()));
    Ok(out)
}

// ---------------------------------------------------------------------------------------------------------------
// .xip checks: a xar archive whose table of contents is hashed and signed by Apple

fn tag<'a>(xml: &'a str, start: usize, name: &str) -> Option<(usize, &'a str)> {
    let open = format!("<{name}");
    let i = start + xml[start..].find(&open)?;
    let gt = i + xml[i..].find('>')?;
    let close = format!("</{name}>");
    let j = gt + xml[gt..].find(&close)?;
    Some((j + close.len(), &xml[gt + 1..j]))
}

fn num(xml: &str, name: &str) -> Option<u64> {
    tag(xml, 0, name).and_then(|(_, v)| v.trim().parse().ok())
}

/// Checks a downloaded Xcode .xip: xar header, the TOC checksum, Apple's signature over it (certificate chain up to the
/// pinned Apple Root CA, with openssl) and the archived checksum of its Content. Fails with what is wrong.
pub fn verify_xip(p: &Path, say: &mut dyn FnMut(&str)) -> Result<()> {
    use std::io::{Seek, SeekFrom};
    let mut f = std::fs::File::open(p).with_context(|| format!("opening {}", p.display()))?;
    let mut h = [0u8; 28];
    f.read_exact(&mut h)?;
    anyhow::ensure!(&h[..4] == b"xar!", "{}: not a .xip (no xar header)", p.display());
    let hsize = u16::from_be_bytes([h[4], h[5]]) as u64;
    let toc_c = u64::from_be_bytes(h[8..16].try_into().unwrap());
    let alg = u32::from_be_bytes(h[24..28].try_into().unwrap());
    f.seek(SeekFrom::Start(hsize))?;
    let mut tocz = vec![0u8; toc_c as usize];
    f.read_exact(&mut tocz)?;
    let mut toc = String::new();
    flate2::read::ZlibDecoder::new(&tocz[..]).read_to_string(&mut toc).context("the .xip's table of contents doesn't decompress")?;
    let heap = hsize + toc_c;
    let read_heap = |f: &mut std::fs::File, off: u64, len: u64| -> Result<Vec<u8>> {
        f.seek(SeekFrom::Start(heap + off))?;
        let mut b = vec![0u8; len as usize];
        f.read_exact(&mut b)?;
        Ok(b)
    };
    // 1. the TOC's checksum
    let (_, ck) = tag(&toc, 0, "checksum").context("no checksum in the .xip's table of contents")?;
    let (off, len) = (num(ck, "offset").unwrap_or(0), num(ck, "size").unwrap_or(0));
    let stored = read_heap(&mut f, off, len)?;
    let (digest, md) = match alg {
        1 => (sha1_smol::Sha1::from(&tocz).digest().bytes().to_vec(), "sha1"),
        2 => (sha256(&[&tocz]).to_vec(), "sha256"),
        _ => {
            let mut hh = sha2::Sha512::new();
            hh.update(&tocz);
            (hh.finalize().to_vec(), "sha512")
        }
    };
    anyhow::ensure!(stored == digest, "{}: the table of contents doesn't match its checksum (damaged download)", p.display());
    say("table of contents: checksum ok");
    // 2. Apple's signature over that checksum
    let (_, sig) = tag(&toc, 0, "signature").context("the .xip isn't signed")?;
    let sig_bytes = read_heap(&mut f, num(sig, "offset").unwrap_or(0), num(sig, "size").unwrap_or(0))?;
    let mut certs = vec![];
    let mut at = 0;
    while let Some((next, c)) = tag(sig, at, "X509Certificate") {
        certs.push(B64.decode(c.split_whitespace().collect::<String>())?);
        at = next;
    }
    anyhow::ensure!(certs.len() >= 2, "the .xip's signature carries no certificate chain");
    let root = certs.iter().position(|c| hex(&sha256(&[c])) == APPLE_ROOT_CA_SHA256).context("the .xip's signature doesn't chain to Apple Root CA: not Apple's file")?;
    let tmp = std::env::temp_dir().join(format!("x86sim-xip-{}", std::process::id()));
    std::fs::create_dir_all(&tmp)?;
    let pem = |d: &[u8]| format!("-----BEGIN CERTIFICATE-----\n{}\n-----END CERTIFICATE-----\n", B64.encode(d).as_bytes().chunks(64).map(|c| String::from_utf8_lossy(c).into_owned()).collect::<Vec<_>>().join("\n"));
    std::fs::write(tmp.join("leaf.pem"), pem(&certs[0]))?;
    std::fs::write(tmp.join("root.pem"), pem(&certs[root]))?;
    std::fs::write(tmp.join("chain.pem"), certs.iter().enumerate().filter(|(i, _)| *i != 0 && *i != root).map(|(_, c)| pem(c)).collect::<String>())?;
    std::fs::write(tmp.join("digest"), &digest)?;
    std::fs::write(tmp.join("sig"), &sig_bytes)?;
    let run = |args: &[&str]| -> Result<String> {
        let o = Command::new("openssl").args(args).current_dir(&tmp).stdin(Stdio::null()).output().context("running openssl (needed to check Apple's signature)")?;
        if !o.status.success() {
            bail!("{}", String::from_utf8_lossy(&o.stdout).trim().to_string() + String::from_utf8_lossy(&o.stderr).trim());
        }
        Ok(String::from_utf8_lossy(&o.stdout).into_owned())
    };
    let r = (|| -> Result<()> {
        // an old Xcode's leaf certificate may have expired since: the chain is checked without the time
        run(&["verify", "-no_check_time", "-CAfile", "root.pem", "-untrusted", "chain.pem", "leaf.pem"]).context("the .xip's certificate chain doesn't check out")?;
        run(&["x509", "-in", "leaf.pem", "-pubkey", "-noout", "-out", "leaf.pub"])?;
        run(&["pkeyutl", "-verify", "-pubin", "-inkey", "leaf.pub", "-in", "digest", "-sigfile", "sig", "-pkeyopt", &format!("digest:{md}")]).context("Apple's signature over the .xip doesn't match")?;
        let subj = run(&["x509", "-in", "leaf.pem", "-noout", "-subject"])?;
        say(&format!("signature: ok ({})", subj.trim()));
        Ok(())
    })();
    let _ = std::fs::remove_dir_all(&tmp);
    r?;
    // 3. the content's archived checksum (the whole 3+ GB, read once)
    let mut at = 0;
    while let Some((next, file)) = tag(&toc, at, "file") {
        at = next;
        let name = tag(file, 0, "name").map(|x| x.1.trim().to_string()).unwrap_or_default();
        let Some((_, data)) = tag(file, 0, "data") else { continue };
        let Some((_, ack)) = tag(data, 0, "archived-checksum") else { continue };
        let style = data.find("archived-checksum style=\"").map(|i| &data[i + 25..]).and_then(|s| s.split('"').next()).unwrap_or("sha1").to_string();
        let (off, len) = (num(data, "offset").unwrap_or(0), num(data, "length").unwrap_or(0));
        say(&format!("checking {name} ({})…", gb(len)));
        f.seek(SeekFrom::Start(heap + off))?;
        let mut left = len;
        let mut buf = vec![0u8; 4 << 20];
        let mut s1 = sha1_smol::Sha1::new();
        let mut s2 = Sha256::new();
        while left > 0 {
            let n = left.min(buf.len() as u64) as usize;
            f.read_exact(&mut buf[..n])?;
            if style == "sha256" {
                s2.update(&buf[..n]);
            } else {
                s1.update(&buf[..n]);
            }
            left -= n as u64;
        }
        let got = if style == "sha256" { hex(&s2.finalize_reset()) } else { s1.digest().to_string() };
        anyhow::ensure!(got.eq_ignore_ascii_case(ack.trim()), "{}: {name} doesn't match its checksum (damaged download: delete it and download again)", p.display());
        say(&format!("{name}: checksum ok"));
    }
    Ok(())
}

// ---------------------------------------------------------------------------------------------------------------
// after the download: the SDK and the device types

/// Where downloads go unless told: XDG's download directory (xdg-user-dir DOWNLOAD), else ~/Downloads
pub fn default_download_dir() -> PathBuf {
    if let Ok(o) = Command::new("xdg-user-dir").arg("DOWNLOAD").output() {
        let s = String::from_utf8_lossy(&o.stdout).trim().to_string();
        if o.status.success() && !s.is_empty() && s != home().to_string_lossy() {
            return PathBuf::from(s);
        }
    }
    home().join("Downloads")
}

/// Runs tools/devicetypes/extract-devicetypes.py on the .xip into OUT and compares it with x86Sim's committed
/// cli/lib/devicetype*.json. Returns the names of files that differ (empty: the same). With `update`, writes cli/lib.
pub fn check_devicetypes(xip: &Path, out: &Path, update: bool, say: &mut dyn FnMut(&str)) -> Result<Vec<String>> {
    let root = crate::aot::repo_root();
    let script = root.join("tools/devicetypes/extract-devicetypes.py");
    anyhow::ensure!(script.exists(), "{} is missing", script.display());
    let _ = std::fs::remove_dir_all(out);
    std::fs::create_dir_all(out)?;
    let mut c = Command::new("python3");
    c.arg("-I").arg(&script).arg(xip).arg("--include-unsupported").arg("--out").arg(out);
    let rc = crate::dev::stream(c, say)?;
    anyhow::ensure!(rc == 0, "extract-devicetypes.py failed (exit {rc})");
    let lib = root.join("cli/lib");
    let mut diff = vec![];
    let mut names: Vec<String> = std::fs::read_dir(out)?.flatten().map(|e| e.file_name().to_string_lossy().into_owned()).filter(|n| n.starts_with("devicetype") && n.ends_with(".json")).collect();
    for e in std::fs::read_dir(&lib)?.flatten() {
        let n = e.file_name().to_string_lossy().into_owned();
        if n.starts_with("devicetype") && n.ends_with(".json") && !names.contains(&n) {
            names.push(n);
        }
    }
    names.sort();
    for n in &names {
        if std::fs::read(out.join(n)).ok() != std::fs::read(lib.join(n)).ok() {
            diff.push(n.clone());
        }
    }
    if update {
        for n in &diff {
            match std::fs::read(out.join(n)) {
                Ok(b) => std::fs::write(lib.join(n), b)?,
                Err(_) => say(&format!("{n}: only in cli/lib (left as is)")),
            }
        }
    }
    Ok(diff)
}

/// What "Download Xcode" does after the sign-in: options (the launcher's Develop page, `x86sim account download-xcode`)
#[derive(Clone, Debug, Default)]
pub struct GetXcode {
    /// "27.2", "27", "Xcode 27.3 beta 2"; None: the dev toolchain's Xcode (its newest final release)
    pub version: Option<String>,
    /// where the .xip goes (default: the download directory)
    pub dir: Option<PathBuf>,
    /// build the dev toolchain's SDK from it (x86sim dev setup sdk --xip)
    pub setup_sdk: bool,
    /// compare the device types in it with x86Sim's (tools/devicetypes/extract-devicetypes.py)
    pub devicetypes: bool,
    /// ... and write the new ones into cli/lib (a checkout)
    pub update_devicetypes: bool,
    /// delete the .xip at the end (else kept)
    pub delete_xip: bool,
}

/// Download, check, then the SDK and the device types; the .xip kept or deleted as asked. Returns the .xip's path.
pub fn get_xcode(o: &GetXcode, say: &mut dyn FnMut(&str)) -> Result<PathBuf> {
    let dir = o.dir.clone().unwrap_or_else(default_download_dir);
    let xip = download_xcode(o.version.as_deref(), &dir, say)?;
    let mut failed = vec![];
    if o.setup_sdk {
        say("== xcode: sdk (x86sim dev setup sdk --xip)");
        let rc = crate::dev::run_installer(None, Some(&xip), false, say)?;
        if rc != 0 {
            failed.push(format!("the SDK build failed (exit {rc}); retry: x86sim dev setup sdk --xip {}", xip.display()));
        } else {
            let mut s = crate::dev::load_settings();
            s.xip = xip.to_string_lossy().into_owned();
            let _ = crate::dev::save_settings(&s);
        }
    }
    if o.devicetypes {
        say("== xcode: device types (extract-devicetypes.py)");
        let out = crate::dev::work_dir().join("devicetypes");
        match check_devicetypes(&xip, &out, o.update_devicetypes, say) {
            Ok(d) if d.is_empty() => say("device types: the same as x86Sim's cli/lib/devicetype*.json"),
            Ok(d) => say(&format!(
                "device types: {} file(s) differ from x86Sim's ({}){}",
                d.len(),
                d.join(", "),
                if o.update_devicetypes { ": cli/lib updated".to_string() } else { format!("; the new ones are in {}", out.display()) }
            )),
            Err(e) => failed.push(format!("device types: {e:#}")),
        }
    }
    if o.delete_xip && failed.is_empty() {
        std::fs::remove_file(&xip)?;
        say(&format!("deleted {} (as asked)", xip.display()));
    } else {
        say(&format!("kept {}", xip.display()));
    }
    if !failed.is_empty() {
        bail!("{}", failed.join("; "));
    }
    say("== xcode: done");
    Ok(xip)
}
