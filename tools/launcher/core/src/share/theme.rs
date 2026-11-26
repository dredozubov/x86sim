//! The desktop's Omarchy theme for the browser page: the same theme files the launcher reads (gui/src/omarchy.rs:
//! `~/.local/state/omarchy/current/theme/colors.toml` + `shell.toml`, Hyprland's rounding, the system monospace font)
//! turned into the page's CSS variables with the launcher's colour rules (gui/src/theme.rs `Palette::from_theme`), so
//! the page and the launcher look alike. `generation()` changes with every theme or font switch; the page asks for it
//! every few seconds and reloads `theme.css` (a theme switch repaints the page live, as it does the launcher).
//! `X86SIM_OMARCHY_THEME_DIR` points at another theme directory (tests), as in the launcher.
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::time::SystemTime;

type Rgba = (u8, u8, u8, u8);

fn home() -> PathBuf {
    std::env::var_os("HOME").map(PathBuf::from).unwrap_or_default()
}

pub fn theme_dir() -> PathBuf {
    if let Some(d) = std::env::var_os("X86SIM_OMARCHY_THEME_DIR") {
        return PathBuf::from(d);
    }
    let base = std::env::var_os("XDG_STATE_HOME").map(PathBuf::from).unwrap_or_else(|| home().join(".local/state"));
    base.join("omarchy/current/theme")
}

/// Flat TOML as Omarchy writes it: `[section]` and `key = value`; keys as `section.key`
fn parse_toml(s: &str) -> HashMap<String, String> {
    let mut out = HashMap::new();
    let mut section = String::new();
    for line in s.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if let Some(h) = line.strip_prefix('[').and_then(|l| l.strip_suffix(']')) {
            section = h.trim().to_string();
            continue;
        }
        let Some((k, v)) = line.split_once('=') else { continue };
        let (k, v) = (k.trim(), v.trim());
        let v = if let Some(rest) = v.strip_prefix('"') { rest.split('"').next().unwrap_or("").to_string() } else { v.split('#').next().unwrap_or("").trim().to_string() };
        out.insert(if section.is_empty() { k.to_string() } else { format!("{section}.{k}") }, v);
    }
    out
}

/// "#rrggbb", "#rrggbbaa", "rgb(rrggbb)", "rgba(rrggbbaa)"; a gradient gives its first stop
fn parse_color(v: &str) -> Option<Rgba> {
    let v = v.trim();
    let hex = if let Some(h) = v.strip_prefix('#') {
        h.split_whitespace().next()?
    } else if let Some(r) = v.strip_prefix("rgba(").or_else(|| v.strip_prefix("rgb(")) {
        r.split(')').next()?.trim()
    } else {
        return None;
    };
    let n = u32::from_str_radix(hex, 16).ok()?;
    match hex.len() {
        6 => Some(((n >> 16) as u8, (n >> 8) as u8, n as u8, 255)),
        8 => Some(((n >> 24) as u8, (n >> 16) as u8, (n >> 8) as u8, n as u8)),
        _ => None,
    }
}

struct Theme {
    colors: HashMap<String, String>,
    shell: HashMap<String, String>,
}

impl Theme {
    fn load() -> Option<Theme> {
        let dir = theme_dir();
        let colors = std::fs::read_to_string(dir.join("colors.toml")).ok()?;
        let shell = std::fs::read_to_string(dir.join("shell.toml")).unwrap_or_default();
        Some(Theme { colors: parse_toml(&colors).into_iter().map(|(k, v)| (k.rsplit('.').next().unwrap_or(&k).to_string(), v)).collect(), shell: parse_toml(&shell) })
    }
    fn color(&self, k: &str) -> Option<Rgba> {
        self.colors.get(k).and_then(|v| parse_color(v))
    }
    fn f(&self, section: &str, key: &str, d: f32) -> f32 {
        self.shell.get(&format!("{section}.{key}")).and_then(|v| v.parse().ok()).unwrap_or(d)
    }
    /// a shell.toml colour; `hyprland.active-border`-style values point at another key
    fn shell_color(&self, section: &str, key: &str) -> Option<Rgba> {
        let mut v = self.shell.get(&format!("{section}.{key}"))?;
        for _ in 0..4 {
            match self.shell.get(v.as_str()) {
                Some(next) if !v.starts_with('#') => v = next,
                _ => break,
            }
        }
        parse_color(v)
    }
    /// a shell.toml value with `hyprland.active-border`-style references followed (a gradient stays whole)
    fn shell_raw(&self, section: &str, key: &str) -> Option<&str> {
        let mut v = self.shell.get(&format!("{section}.{key}"))?;
        for _ in 0..4 {
            match self.shell.get(v.as_str()) {
                Some(next) if !v.starts_with('#') => v = next,
                _ => break,
            }
        }
        Some(v)
    }
    /// a border as CSS: Hyprland's gradient ("rgba(..) rgba(..) 45deg") as a linear-gradient, a solid colour as a
    /// one-colour one, at the `<key>-alpha` companion
    fn shell_ring(&self, section: &str, key: &str) -> Option<String> {
        let a = self.f(section, &format!("{key}-alpha"), 1.0);
        gradient(self.shell_raw(section, key)?, a)
    }
    /// a border width ("N" or a CSS-style list: the first one), px
    fn width(&self, section: &str, key: &str, d: f32) -> f32 {
        self.shell.get(&format!("{section}.{key}")).and_then(|v| v.split_whitespace().next()?.parse().ok()).unwrap_or(d)
    }
    fn shell_color_a(&self, section: &str, key: &str) -> Option<Rgba> {
        let c = self.shell_color(section, key)?;
        let a = self.f(section, &format!("{key}-alpha"), 1.0);
        Some((c.0, c.1, c.2, (c.3 as f32 * a.clamp(0.0, 1.0)).round() as u8))
    }
    fn light(&self) -> bool {
        self.colors.get("mode").is_some_and(|m| m == "light")
    }
}

/// Hyprland's colour list ("rgba(798186ee) rgba(caccccee) 45deg", one colour, "#hex") as a CSS linear-gradient
fn gradient(v: &str, a: f32) -> Option<String> {
    let mut stops = vec![];
    let mut angle = 0.0f32;
    for tok in v.split_whitespace() {
        if let Some(d) = tok.strip_suffix("deg") {
            angle = d.parse().unwrap_or(0.0);
        } else if let Some(c) = parse_color(tok) {
            stops.push(rgba(c, a));
        }
    }
    match stops.len() {
        0 => None,
        1 => Some(format!("linear-gradient({0}, {0})", stops[0])),
        // Hyprland's 0deg runs left to right, CSS's runs upward
        _ => Some(format!("linear-gradient({}deg, {})", (90.0 + angle) % 360.0, stops.join(", "))),
    }
}

fn lum(c: Rgba) -> f32 {
    let ch = |v: u8| {
        let v = v as f32 / 255.0;
        if v <= 0.03928 { v / 12.92 } else { ((v + 0.055) / 1.055).powf(2.4) }
    };
    0.2126 * ch(c.0) + 0.7152 * ch(c.1) + 0.0722 * ch(c.2)
}

fn contrast(a: Rgba, b: Rgba) -> f32 {
    let (x, y) = (lum(a) + 0.05, lum(b) + 0.05);
    if x > y { x / y } else { y / x }
}

fn mix(a: Rgba, b: Rgba, t: f32) -> Rgba {
    let l = |x: u8, y: u8| (x as f32 + (y as f32 - x as f32) * t).round() as u8;
    (l(a.0, b.0), l(a.1, b.1), l(a.2, b.2), 255)
}

fn pick(c: &[Option<Rgba>], bg: Rgba, min: f32, fallback: Rgba) -> Rgba {
    c.iter().flatten().copied().find(|c| contrast(*c, bg) >= min).unwrap_or(fallback)
}

fn hex(c: Rgba) -> String {
    format!("#{:02x}{:02x}{:02x}", c.0, c.1, c.2)
}

fn rgba(c: Rgba, a: f32) -> String {
    format!("rgb({} {} {} / {:.3})", c.0, c.1, c.2, a.clamp(0.0, 1.0) * c.3 as f32 / 255.0)
}

/// Hyprland's window rounding (decoration:rounding)
fn rounding() -> Option<u8> {
    let out = std::process::Command::new("hyprctl").args(["getoption", "decoration:rounding", "-j"]).output().ok()?;
    if !out.status.success() {
        return None;
    }
    let s = String::from_utf8_lossy(&out.stdout);
    let i = s.find("\"int\"")?;
    let digits: String = s[i + 5..].chars().skip_while(|c| !c.is_ascii_digit()).take_while(|c| c.is_ascii_digit()).collect();
    digits.parse::<u32>().ok().map(|n| n.min(32) as u8)
}

fn fc(args: &[&str]) -> Option<String> {
    let out = std::process::Command::new("fc-match").args(args).output().ok()?;
    let s = String::from_utf8_lossy(&out.stdout).trim().to_string();
    (out.status.success() && !s.is_empty()).then_some(s)
}

/// The system monospace font (as fontconfig resolves "monospace"): its family name and regular file
pub fn mono_font() -> Option<(String, PathBuf)> {
    let family = fc(&["monospace", "-f", "%{family}"])?.split(',').next()?.trim().to_string();
    let file = PathBuf::from(fc(&[&family, "-f", "%{file}"])?);
    (!family.is_empty() && file.is_file()).then_some((family, file))
}

fn mtime(p: &Path) -> Option<SystemTime> {
    std::fs::metadata(p).ok().and_then(|m| m.modified().ok())
}

/// Changes with every theme or font switch (the files Omarchy rewrites), "" without an Omarchy theme
pub fn generation() -> String {
    let dir = theme_dir();
    if !dir.join("colors.toml").exists() {
        return String::new();
    }
    let parent = dir.parent().map(Path::to_path_buf).unwrap_or_default();
    let fontconf = std::env::var_os("XDG_CONFIG_HOME").map(PathBuf::from).unwrap_or_else(|| home().join(".config")).join("fontconfig/fonts.conf");
    let parts = [parent.join("theme.generation"), parent.join("theme.name"), dir.join("colors.toml"), dir.join("shell.toml"), fontconf];
    let mut h: u64 = 1469598103934665603;
    for p in parts.iter().map(|p| mtime(p)).chain(std::iter::once(std::fs::canonicalize(&dir).ok().and_then(|p| mtime(&p)))) {
        let n = p.and_then(|t| t.duration_since(SystemTime::UNIX_EPOCH).ok()).map(|d| d.as_nanos() as u64).unwrap_or(0);
        h = (h ^ n).wrapping_mul(1099511628211);
    }
    format!("{h:016x}")
}

/// The page's CSS variables from the theme (gui/src/theme.rs's rules), under `html[data-host-theme]` so a viewer who
/// picked the default look keeps it; None without an Omarchy theme
pub fn css() -> Option<String> {
    let t = Theme::load()?;
    let d_bg = (0x15, 0x17, 0x1a, 255);
    let bg = t.color("background").unwrap_or(d_bg);
    let fg = t.color("foreground").unwrap_or((0xd6, 0xd8, 0xdc, 255));
    let dark = t.color("dark_background").unwrap_or(bg);
    let darker = t.color("darker_background").unwrap_or(dark);
    let accent = t.color("accent").unwrap_or((0xff, 0xd6, 0x0a, 255));
    let selection = t.color("selection").unwrap_or(mix(bg, fg, 0.2));
    let active = t.color("active_border_color").or_else(|| t.color("hyprland_active_border")).unwrap_or(accent);
    let control = t.shell_color("controls", "normal-color").unwrap_or(fg);
    let (a_normal, a_hover, a_pressed, a_selected, a_border, a_border_hover) = (
        t.f("controls", "normal-fill-alpha", 0.04),
        t.f("controls", "hover-cursor-fill-alpha", 0.08),
        t.f("controls", "pressed-fill-alpha", 0.22),
        t.f("controls", "selected-fill-alpha", 0.18),
        t.f("controls", "normal-border-alpha", 0.4),
        t.f("controls", "hover-cursor-border-alpha", 0.25),
    );
    let light = t.light();
    let ink_2 = mix(fg, bg, 0.22);
    let mut t3 = 0.45;
    while t3 > 0.2 && contrast(mix(fg, bg, t3), bg) < 4.2 {
        t3 -= 0.05;
    }
    let ink_3 = mix(fg, bg, t3);
    let reds = [t.color("bright_red"), t.color("red")];
    let crit = pick(&reds, bg, 3.0, ink_2);
    let warn = pick(&[t.color("yellow"), t.color("bright_yellow")], bg, 3.0, ink_2);
    let good = pick(&[t.color("green"), t.color("bright_green")], bg, 3.0, ink_2);
    let blue = pick(&[t.color("blue"), t.color("bright_blue")], bg, 3.0, ink_2);
    let cyan = pick(&[t.color("cyan"), t.color("bright_cyan")], bg, 3.0, ink_2);
    let accent_ink = if contrast(accent, bg) >= 4.0 { accent } else { fg };
    let on_accent = if contrast(bg, accent) >= contrast(fg, accent) { bg } else { fg };
    let popup_border = t.shell_color_a("popups", "border").or_else(|| t.shell_color_a("menu", "border")).unwrap_or(active);
    let scrim = t.shell_color("menu", "scrim").unwrap_or(bg);
    let radius = rounding().unwrap_or(0);
    let font = mono_font().map(|(family, _)| family);
    let mut v: Vec<(&str, String)> = vec![
        ("--canvas", hex(bg)),
        ("--card", hex(bg)),
        ("--window", hex(dark)),
        ("--well", hex(darker)),
        ("--ink", hex(fg)),
        ("--ink-2", hex(ink_2)),
        ("--ink-3", hex(ink_3)),
        ("--line", hex(mix(bg, fg, 0.14))),
        ("--raised", rgba(control, a_normal)),
        ("--hover", rgba(control, a_hover)),
        ("--pressed", rgba(control, a_pressed)),
        ("--selected", rgba(control, a_selected)),
        ("--edge", rgba(control, a_border)),
        ("--edge-hover", rgba(accent_ink, 0.7)),
        ("--accent", hex(accent)),
        ("--accent-ink", hex(accent_ink)),
        ("--on-accent", hex(on_accent)),
        ("--active", hex(popup_border)),
        ("--good", hex(good)),
        ("--warn", hex(warn)),
        ("--crit", hex(crit)),
        ("--blue", hex(blue)),
        ("--cyan", hex(cyan)),
        ("--scrim", rgba(scrim, t.f("menu", "scrim-alpha", 0.5))),
        ("--bezel", hex(mix(darker, (0, 0, 0, 255), 0.5))),
        ("--r", format!("{radius}px")),
        ("--r-sm", format!("{}px", radius.min(4))),
        ("color-scheme", (if light { "light" } else { "dark" }).into()),
    ];
    let _ = a_border_hover;
    // the shell's own surfaces: flyouts and dialogs ([popups], else [menu]), notifications, the chosen menu row
    let popup = t.shell_color_a("popups", "background").or_else(|| t.shell_color_a("menu", "background"));
    let ring = t.shell_ring("popups", "border").or_else(|| t.shell_ring("menu", "border"));
    if let Some(c) = popup {
        v.push(("--popup", rgba(c, 1.0)));
    }
    if let Some(r) = &ring {
        v.push(("--ring", r.clone()));
    }
    if let Some(c) = t.shell_color_a("notifications", "background") {
        v.push(("--toast", rgba(c, 1.0)));
    }
    if let Some(r) = t.shell_ring("notifications", "border").or(ring) {
        v.push(("--toast-ring", r));
    }
    let on = popup.unwrap_or(bg);
    let hilite = t.shell_color("menu", "selected-text").or_else(|| t.shell_color("launcher", "selected-text")).filter(|c| contrast(*c, on) >= 3.0).unwrap_or(accent_ink);
    v.push(("--hilite", hex(hilite)));
    if let Some(c) = t.shell_color_a("menu", "selected-background") {
        v.push(("--hilite-fill", rgba(c, 1.0)));
    }
    // text selection, the keyboard focus, the theme's other hues
    v.push(("--selection", rgba(selection, t.f("controls", "selection-fill-alpha", 0.85).max(0.35))));
    let focus = t.shell_color("controls", "focus-border").unwrap_or(control);
    v.push(("--focus-edge", rgba(focus, (t.f("controls", "focus-border-alpha", 0.25) + a_border).min(1.0))));
    v.push(("--focus-fill", rgba(t.shell_color("controls", "focus-color").unwrap_or(control), t.f("controls", "focus-fill-alpha", 0.08))));
    v.push(("--magenta", hex(pick(&[t.color("magenta"), t.color("bright_magenta")], bg, 3.0, ink_2))));
    v.push(("--orange", hex(pick(&[t.color("orange"), t.color("bright_red"), t.color("red")], bg, 3.0, warn))));
    // control border widths ([controls] normal / focus)
    v.push(("--bw", format!("{}px", t.width("controls", "normal-border-width", 1.0))));
    v.push(("--bw-focus", format!("{}px", t.width("controls", "focus-border-width", 1.0).max(1.0))));
    if let Some(f) = &font {
        v.push(("--mono", format!("\"{}\", \"x86sim-host-mono\", ui-monospace, monospace", f.replace('"', ""))));
    }
    let mut s = String::from("/* x86Sim: this machine's Omarchy theme (share/theme.rs), applied when the page has data-host-theme (after app.css: it wins) */\n");
    if font.is_some() {
        s.push_str("@font-face { font-family: \"x86sim-host-mono\"; src: url(\"theme-font\"); font-display: swap; }\n");
    }
    s.push_str(":root[data-host-theme] {\n");
    for (k, val) in v {
        s.push_str(&format!("  {k}: {val};\n"));
    }
    s.push_str("}\n");
    Some(s)
}

// ---- push: theme switches reach the page at once, no polling

use std::sync::{Condvar, Mutex, OnceLock};
use std::time::Duration;

struct Watch {
    gen: Mutex<String>,
    changed: Condvar,
}

fn watch() -> &'static Watch {
    static W: OnceLock<&'static Watch> = OnceLock::new();
    W.get_or_init(|| {
        let w: &'static Watch = Box::leak(Box::new(Watch { gen: Mutex::new(generation()), changed: Condvar::new() }));
        std::thread::Builder::new().name("theme-watch".into()).spawn(move || inotify_loop(w)).ok();
        w
    })
}

/// inotify on what a theme or font switch rewrites: Omarchy's state dir (the `theme` symlink, theme.generation /
/// theme.name), the theme dir itself (colors.toml, shell.toml) and fontconfig's user dir; the thread sleeps in read()
/// until one of them changes, then publishes the new generation to every waiting page
fn inotify_loop(w: &'static Watch) {
    let fd = unsafe { libc::inotify_init1(libc::IN_CLOEXEC) };
    if fd < 0 {
        return;
    }
    let mask = libc::IN_CREATE | libc::IN_MOVED_TO | libc::IN_DELETE | libc::IN_CLOSE_WRITE | libc::IN_ATTRIB | libc::IN_MOVED_FROM;
    let fontconf = std::env::var_os("XDG_CONFIG_HOME").map(PathBuf::from).unwrap_or_else(|| home().join(".config")).join("fontconfig");
    let add = |p: &Path| {
        if let Ok(c) = std::ffi::CString::new(p.as_os_str().as_encoded_bytes()) {
            unsafe { libc::inotify_add_watch(fd, c.as_ptr(), mask) };
        }
    };
    let dir = theme_dir();
    let mut buf = [0u8; 4096];
    loop {
        // the theme dir is a symlink a switch replaces: watch where it points now, again after every event
        if let Some(parent) = dir.parent() {
            add(parent);
        }
        add(&dir);
        if let Ok(real) = std::fs::canonicalize(&dir) {
            add(&real);
        }
        add(&fontconf);
        let n = unsafe { libc::read(fd, buf.as_mut_ptr() as *mut libc::c_void, buf.len()) };
        if n <= 0 {
            std::thread::sleep(Duration::from_secs(1));
            continue;
        }
        // a switch writes several files in a row: let it finish, and take the events that came meanwhile
        std::thread::sleep(Duration::from_millis(150));
        unsafe {
            let fl = libc::fcntl(fd, libc::F_GETFL);
            libc::fcntl(fd, libc::F_SETFL, fl | libc::O_NONBLOCK);
            while libc::read(fd, buf.as_mut_ptr() as *mut libc::c_void, buf.len()) > 0 {}
            libc::fcntl(fd, libc::F_SETFL, fl);
        }
        let g = generation();
        let mut cur = w.gen.lock().unwrap();
        if *cur != g {
            *cur = g;
            w.changed.notify_all();
        }
    }
}

/// The current generation; waits up to `timeout` for one other than `last` ("" = answer at once)
pub fn wait_change(last: &str, timeout: Duration) -> String {
    let w = watch();
    let g = w.gen.lock().unwrap();
    if last.is_empty() || *g != last {
        return g.clone();
    }
    let (g, _) = w.changed.wait_timeout_while(g, timeout, |g| *g == last).unwrap();
    g.clone()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn colours_and_rules() {
        assert_eq!(parse_color("#798186"), Some((0x79, 0x81, 0x86, 255)));
        assert_eq!(parse_color("rgba(798186ee) rgba(caccccee)"), Some((0x79, 0x81, 0x86, 0xee)));
        assert!(contrast((0, 0, 0, 255), (255, 255, 255, 255)) > 20.0);
        // the launcher's default dark ramp (app.css's built-in values)
        assert_eq!(hex(mix((0xd6, 0xd8, 0xdc, 255), (0x15, 0x17, 0x1a, 255), 0.22)), "#acaeb1");
        assert_eq!(gradient("rgba(798186ee) rgba(caccccee)", 1.0).unwrap(), "linear-gradient(90deg, rgb(121 129 134 / 0.933), rgb(202 204 204 / 0.933))");
        assert_eq!(gradient("#ffffff", 0.5).unwrap(), "linear-gradient(rgb(255 255 255 / 0.500), rgb(255 255 255 / 0.500))");
    }

    #[test]
    fn css_from_a_theme_dir() {
        let d = std::env::temp_dir().join(format!("x86sim-theme-test-{}", std::process::id()));
        std::fs::create_dir_all(&d).unwrap();
        std::fs::write(d.join("colors.toml"), "background = \"#1a1b26\"\nforeground = \"#c0caf5\"\naccent = \"#7aa2f7\"\nmode = \"dark\"\n").unwrap();
        std::fs::write(d.join("shell.toml"), "[hyprland]\nactive-border = \"rgba(33ccffee) rgba(00ff99ee) 45deg\"\n[popups]\nbackground = \"#16161e\"\nborder = \"hyprland.active-border\"\n[controls]\nnormal-border-width = \"2 1\"\n").unwrap();
        std::env::set_var("X86SIM_OMARCHY_THEME_DIR", &d);
        let c = css().unwrap();
        assert!(c.contains("--canvas: #1a1b26;") && c.contains("--accent: #7aa2f7;") && c.contains("color-scheme: dark;"), "{c}");
        assert!(c.contains("--popup: rgb(22 22 30 / 1.000);") && c.contains("--ring: linear-gradient(135deg, rgb(51 204 255 / 0.933), rgb(0 255 153 / 0.933));") && c.contains("--bw: 2px;"), "{c}");
        assert!(!generation().is_empty());
        std::env::remove_var("X86SIM_OMARCHY_THEME_DIR");
        let _ = std::fs::remove_dir_all(&d);
    }
}
