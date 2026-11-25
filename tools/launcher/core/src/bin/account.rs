//! x86sim-account (`x86sim account ...`): the Apple Account sign-in for Xcode downloads and signing. No MCP tool:
//! agents never get the user's credentials. The logic is x86sim_core::account, shared with the launcher's Settings.
use std::io::{BufRead, IsTerminal, Write};
use std::path::PathBuf;
use std::process::ExitCode;
use x86sim_core::account::{self, Ask, CodeAnswer, CodePrompt};

const USAGE: &str = "usage: x86sim account <command> [args]

  status [--json] [--offline]
                       the Apple ID signed in, what it can do (developer downloads, signing with xtool) and when it
                       needs renewing; asks Apple whether the session still works (--offline: don't)
  login [APPLE_ID] [--signing | --signing-only] [--password-file FILE]
                       sign in: Apple ID, password (asked without echo; never stored) and a two-factor code (from
                       your trusted devices, or type `sms` for a text message). The session goes into the Secret
                       Service keyring (else a 0600 file in ~/.config/x86sim). --signing also signs xtool in with the
                       same password (device builds, installs: x86sim dev device / ship), once; an xtool already
                       signed in with this Apple ID is kept. --signing-only: only xtool's sign-in.
                       Two-factor codes are read from the terminal, or from stdin when it is not one.
  logout [--keep-signing]
                       forget the session; xtool's sign-in too unless --keep-signing
  download-xcode [VERSION] [--list] [--dir DIR] [--no-setup] [--no-devicetypes] [--update-devicetypes] [--delete-xip]
                       download Xcode.xip (default: the dev toolchain's Xcode, its newest release; VERSION: 27.2,
                       27, \"27.3 beta 2\") into DIR (default: your download folder; resumes a .part), check Apple's
                       signature and checksums, then build the dev SDK from it (x86sim dev setup sdk --xip) and
                       compare its device types with x86Sim's (--update-devicetypes writes cli/lib). The .xip is kept
                       unless --delete-xip. --list: the Xcode releases this account can download.
  verify-xip FILE      check a .xip's signature (Apple's certificate chain) and checksums";

fn take_opt(args: &mut Vec<String>, name: &str) -> Option<String> {
    let i = args.iter().position(|a| a == name)?;
    if i + 1 >= args.len() {
        return None;
    }
    let v = args.remove(i + 1);
    args.remove(i);
    Some(v)
}

fn take_flag(args: &mut Vec<String>, name: &str) -> bool {
    match args.iter().position(|a| a == name) {
        Some(i) => {
            args.remove(i);
            true
        }
        None => false,
    }
}

/// Reads a line from the terminal (or stdin when there is none), without echo when `secret`
fn read_line(prompt: &str, secret: bool) -> anyhow::Result<String> {
    eprint!("{prompt}");
    let _ = std::io::stderr().flush();
    let tty = std::fs::OpenOptions::new().read(true).write(true).open("/dev/tty").ok().filter(|_| std::io::stdin().is_terminal());
    let mut line = String::new();
    if let Some(t) = tty {
        use std::os::fd::AsRawFd;
        let fd = t.as_raw_fd();
        let mut old: libc::termios = unsafe { std::mem::zeroed() };
        let have = unsafe { libc::tcgetattr(fd, &mut old) } == 0;
        if secret && have {
            let mut n = old;
            n.c_lflag &= !libc::ECHO;
            unsafe { libc::tcsetattr(fd, libc::TCSANOW, &n) };
        }
        let r = std::io::BufReader::new(&t).read_line(&mut line);
        if secret && have {
            unsafe { libc::tcsetattr(fd, libc::TCSANOW, &old) };
            eprintln!();
        }
        r?;
    } else {
        let n = std::io::stdin().lock().read_line(&mut line)?;
        anyhow::ensure!(n > 0, "no input (stdin closed)");
    }
    Ok(line.trim_end_matches(['\n', '\r']).to_string())
}

struct Term;

impl Ask for Term {
    fn say(&mut self, line: &str) {
        println!("{line}");
    }
    fn code(&mut self, p: &CodePrompt) -> anyhow::Result<CodeAnswer> {
        if p.retry {
            println!("Apple didn't take that code: try again");
        }
        let what = match p.sent.as_str() {
            "sms" => format!("the {}-digit code texted to {}", p.length, p.sms_to),
            "xtool" => "xtool's sign-in: the code Apple shows on your trusted devices".to_string(),
            _ => format!("the {}-digit code shown on your trusted Apple devices", p.length),
        };
        if p.sent == "device" && !p.phones.is_empty() {
            println!("(no device? type sms for a text message{})", if p.phones.len() > 1 { ", or sms N for number N" } else { "" });
            if p.phones.len() > 1 {
                for (i, ph) in p.phones.iter().enumerate() {
                    println!("  {}. {}", i + 1, ph.number);
                }
            }
        }
        let (tx, rx) = std::sync::mpsc::channel();
        let prompt = format!("Enter {what}: ");
        std::thread::spawn(move || {
            let _ = tx.send(read_line(&prompt, false));
        });
        let l = rx.recv_timeout(account::CODE_TIMEOUT).map_err(|_| anyhow::anyhow!("no two-factor code within {} minutes: sign in again", account::CODE_TIMEOUT.as_secs() / 60))??;
        let l = l.trim();
        if let Some(rest) = l.strip_prefix("sms") {
            let i: usize = rest.trim().parse().unwrap_or(1);
            let ph = p.phones.get(i.saturating_sub(1)).or(p.phones.first()).ok_or_else(|| anyhow::anyhow!("no trusted phone number on this account"))?;
            return Ok(CodeAnswer::Sms(ph.id));
        }
        Ok(CodeAnswer::Code(l.to_string()))
    }
    fn choose(&mut self, title: &str, options: &[String]) -> anyhow::Result<usize> {
        println!("{title}:");
        for (i, o) in options.iter().enumerate() {
            println!("  {}. {o}", i + 1);
        }
        let l = read_line("Choice: ", false)?;
        Ok(l.trim().parse::<usize>().unwrap_or(1).saturating_sub(1).min(options.len().saturating_sub(1)))
    }
}

fn print_status(s: &account::Status) {
    if !s.signed_in {
        println!("Apple Account: not signed in (x86sim account login)");
    } else {
        println!("Apple Account: {}{}", s.apple_id, if s.name.is_empty() { String::new() } else { format!(" ({})", s.name) });
        println!("  signed in:    {} (session kept in the {})", s.signed_in_on, if s.store == "keyring" { "Secret Service keyring" } else { "0600 file in ~/.config/x86sim" });
        if let Some(ok) = s.session_ok {
            println!("  session:      {}", if ok { "works" } else { "expired" });
        }
        if !s.trusted_until.is_empty() {
            println!("  two-factor:   not asked again until {}", s.trusted_until);
        }
    }
    println!("  downloads:    {}", s.downloads);
    println!("  signing:      {}", s.signing);
    println!("  renewal:      {}", s.renew);
}

fn main() -> ExitCode {
    let mut args: Vec<String> = std::env::args().skip(1).collect();
    if args.is_empty() || matches!(args[0].as_str(), "help" | "-h" | "--help") {
        println!("{USAGE}");
        return if args.is_empty() { ExitCode::from(2) } else { ExitCode::SUCCESS };
    }
    let cmd = args.remove(0);
    match run(&cmd, args) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("x86sim account {cmd}: {e:#}");
            ExitCode::from(1)
        }
    }
}

fn run(cmd: &str, mut args: Vec<String>) -> anyhow::Result<ExitCode> {
    match cmd {
        "status" => {
            let json = take_flag(&mut args, "--json");
            let offline = take_flag(&mut args, "--offline");
            let s = account::status(!offline)?;
            if json {
                println!("{}", serde_json::to_string_pretty(&s)?);
            } else {
                print_status(&s);
            }
            Ok(ExitCode::from(if s.signed_in && s.session_ok != Some(false) { 0 } else { 1 }))
        }
        "login" => {
            let signing = take_flag(&mut args, "--signing");
            let signing_only = take_flag(&mut args, "--signing-only");
            let pwfile = take_opt(&mut args, "--password-file");
            let id = match args.first().filter(|a| !a.starts_with('-')) {
                Some(a) => a.clone(),
                None => read_line("Apple ID: ", false)?,
            };
            let mut pw = match pwfile {
                // a file the caller made (a secret store's one-use file): its first line
                Some(f) => std::fs::read_to_string(&f)?.lines().next().unwrap_or("").to_string(),
                None => read_line("Password: ", true)?,
            };
            if signing_only {
                account::login_signing(&id, &mut pw, &mut Term)?;
                return Ok(ExitCode::SUCCESS);
            }
            if signing {
                println!("--signing: xtool gets the same password once, for its own sign-in with Apple (it talks to Apple's developer services as a Mac would, using a third-party anisette service for the device identity; the password goes only to Apple)");
            }
            let s = account::login(&id, &mut pw, signing, &mut Term)?;
            print_status(&s);
            Ok(ExitCode::SUCCESS)
        }
        "logout" => {
            let keep = take_flag(&mut args, "--keep-signing");
            let had = account::logout()?;
            println!("{}", if had { "signed out" } else { "was not signed in" });
            if !keep && account::xtool_status().is_some() {
                let mut c = x86sim_core::dev::command(x86sim_core::dev::which("xtool").unwrap_or_else(|| PathBuf::from("xtool")));
                c.args(["auth", "logout"]);
                let ok = c.status().map(|s| s.success()).unwrap_or(false);
                println!("{}", if ok { "xtool signed out" } else { "xtool's sign-out failed (xtool auth logout)" });
            }
            Ok(ExitCode::SUCCESS)
        }
        "download-xcode" | "xcode" => {
            if take_flag(&mut args, "--list") {
                for r in account::list_xcodes()? {
                    println!("{:<34} {:>8.2} GB  {}", r.name, r.size as f64 / 1e9, r.path);
                }
                return Ok(ExitCode::SUCCESS);
            }
            let o = account::GetXcode {
                dir: take_opt(&mut args, "--dir").map(PathBuf::from),
                setup_sdk: !take_flag(&mut args, "--no-setup"),
                devicetypes: !take_flag(&mut args, "--no-devicetypes"),
                update_devicetypes: take_flag(&mut args, "--update-devicetypes"),
                delete_xip: take_flag(&mut args, "--delete-xip"),
                version: args.first().filter(|a| !a.starts_with('-')).cloned(),
            };
            let mut say = |l: &str| println!("{l}");
            let x = account::get_xcode(&o, &mut say)?;
            println!("{}", x.display());
            Ok(ExitCode::SUCCESS)
        }
        "verify-xip" => {
            let f = args.first().ok_or_else(|| anyhow::anyhow!("verify-xip FILE"))?;
            account::verify_xip(std::path::Path::new(f), &mut |l: &str| println!("{l}"))?;
            println!("ok: signed by Apple, checksums match");
            Ok(ExitCode::SUCCESS)
        }
        _ => {
            eprintln!("{USAGE}");
            Ok(ExitCode::from(2))
        }
    }
}
