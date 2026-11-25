//! Screenshots that point at elements, for agents that work from images: `screenshot marks=true` outlines every
//! element of a snapshot with its @ref beside it (`marks=actionable`: only what can be acted on), `screenshot
//! target=@e3` crops the picture to one element with a margin.
//!
//! The picture is the frame upright in the snapshot's points (scaled by `div` as screenshot does). Each outline is a
//! colored line with a dark edge and each tag a filled box with white digits in a small built-in bitmap font (no font
//! files), so both read on light and dark content. A tag goes above its element's top left corner, else inside it,
//! below it, right or left of it: the first place that overlaps no tag already drawn (else the one that overlaps least).
use crate::ax::{self, El, Snapshot};
use crate::instance::Instance;
use anyhow::{bail, Result};

/// Which elements get a mark
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Marks {
    All,
    /// controls, links, fields, icons and text read from pixels (a game's drawn buttons): what tap acts on
    Actionable,
}

impl Marks {
    /// "true" / "all" / "1" -> All, "actionable" -> Actionable, anything else (false, none, "") -> None
    pub fn parse(s: &str) -> Option<Marks> {
        match s.trim().to_ascii_lowercase().as_str() {
            "true" | "all" | "1" | "yes" => Some(Marks::All),
            "actionable" => Some(Marks::Actionable),
            _ => None,
        }
    }
}

/// 5 x 7 glyphs, a row a byte (bit 4 the left column)
fn glyph(c: char) -> [u8; 7] {
    match c {
        '0' => [0x0e, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0e],
        '1' => [0x04, 0x0c, 0x04, 0x04, 0x04, 0x04, 0x0e],
        '2' => [0x0e, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1f],
        '3' => [0x1e, 0x01, 0x01, 0x0e, 0x01, 0x01, 0x1e],
        '4' => [0x02, 0x06, 0x0a, 0x12, 0x1f, 0x02, 0x02],
        '5' => [0x1f, 0x10, 0x1e, 0x01, 0x01, 0x11, 0x0e],
        '6' => [0x06, 0x08, 0x10, 0x1e, 0x11, 0x11, 0x0e],
        '7' => [0x1f, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08],
        '8' => [0x0e, 0x11, 0x11, 0x0e, 0x11, 0x11, 0x0e],
        '9' => [0x0e, 0x11, 0x11, 0x0f, 0x01, 0x02, 0x0c],
        'e' => [0x00, 0x00, 0x0e, 0x11, 0x1f, 0x10, 0x0e],
        '@' => [0x0e, 0x11, 0x17, 0x15, 0x17, 0x10, 0x0e],
        _ => [0; 7],
    }
}

/// Distinct colors, dark enough for white digits on them
const PALETTE: [[u8; 3]; 8] = [[230, 25, 75], [0, 130, 200], [60, 150, 40], [145, 30, 180], [220, 100, 0], [0, 128, 128], [200, 0, 160], [90, 90, 200]];

struct Canvas<'a> {
    px: &'a mut [u8],
    w: usize,
    h: usize,
}

impl Canvas<'_> {
    fn set(&mut self, x: i64, y: i64, c: [u8; 3]) {
        if x >= 0 && y >= 0 && (x as usize) < self.w && (y as usize) < self.h {
            let o = (y as usize * self.w + x as usize) * 3;
            self.px[o..o + 3].copy_from_slice(&c);
        }
    }
    fn fill(&mut self, x0: i64, y0: i64, x1: i64, y1: i64, c: [u8; 3]) {
        for y in y0.max(0)..y1.min(self.h as i64) {
            for x in x0.max(0)..x1.min(self.w as i64) {
                self.set(x, y, c);
            }
        }
    }
    /// a rectangle's outline `t` thick, inside (x0, y0)-(x1, y1)
    fn frame(&mut self, x0: i64, y0: i64, x1: i64, y1: i64, t: i64, c: [u8; 3]) {
        self.fill(x0, y0, x1, y0 + t, c);
        self.fill(x0, y1 - t, x1, y1, c);
        self.fill(x0, y0, x0 + t, y1, c);
        self.fill(x1 - t, y0, x1, y1, c);
    }
    fn text(&mut self, x: i64, y: i64, s: &str, k: i64, c: [u8; 3]) {
        for (i, ch) in s.chars().enumerate() {
            let g = glyph(ch);
            let gx = x + i as i64 * 6 * k;
            for (row, bits) in g.iter().enumerate() {
                for col in 0..5 {
                    if bits & (0x10 >> col) != 0 {
                        self.fill(gx + col * k, y + row as i64 * k, gx + (col + 1) * k, y + (row as i64 + 1) * k, c);
                    }
                }
            }
        }
    }
}

fn wants(e: &El, m: Marks, screen: (f64, f64)) -> bool {
    if e.offscreen || e.covered || e.layer == "status" || e.frame[2] < 1.0 || e.frame[3] < 1.0 {
        return false;
    }
    // a web view or container as large as the screen: its outline is the screen's edge and its tag hides the clock
    if e.frame[2] * e.frame[3] >= 0.9 * screen.0 * screen.1 {
        return false;
    }
    m == Marks::All || e.ocr || !matches!(e.role.as_str(), "text" | "heading" | "image" | "element" | "webview")
}

/// Draws the marks on an upright RGB picture of the snapshot's screen (`f`: pixels per point). Answers how many.
pub fn draw(rgb: &mut [u8], w: usize, h: usize, snap: &Snapshot, m: Marks) -> usize {
    let f = w as f64 / snap.screen.0.max(1.0);
    let mut cv = Canvas { px: rgb, w, h };
    let els: Vec<&El> = snap.elements.iter().filter(|e| wants(e, m, snap.screen)).collect();
    let line = ((f * 1.5).round() as i64).max(1);
    let k = ((f * 1.6).round() as i64).max(1);
    let pad = k;
    let mut placed: Vec<[i64; 4]> = Vec::new();
    // outlines first, so no outline crosses a tag
    let rects: Vec<[i64; 4]> = els
        .iter()
        .map(|e| {
            let [x, y, ew, eh] = e.frame;
            [(x * f).round() as i64, (y * f).round() as i64, ((x + ew) * f).round() as i64, ((y + eh) * f).round() as i64]
        })
        .collect();
    for (i, r) in rects.iter().enumerate() {
        let c = PALETTE[i % PALETTE.len()];
        // a dark edge on both sides of the colored line: it shows on white and on black
        cv.frame(r[0] - 1, r[1] - 1, r[2] + 1, r[3] + 1, line + 2, [20, 20, 20]);
        cv.frame(r[0], r[1], r[2], r[3], line, c);
    }
    for (i, (e, r)) in els.iter().zip(&rects).enumerate() {
        let c = PALETTE[i % PALETTE.len()];
        let s = format!("@{}", e.r);
        let (tw, th) = (s.chars().count() as i64 * 6 * k - k + 2 * pad, 7 * k + 2 * pad);
        let cands = [(r[0], r[1] - th), (r[0] + line, r[1] + line), (r[0], r[3]), (r[2], r[1]), (r[0] - tw, r[1])];
        let clamp = |(x, y): (i64, i64)| (x.clamp(0, (w as i64 - tw).max(0)), y.clamp(0, (h as i64 - th).max(0)));
        let overlap = |(x, y): (i64, i64)| -> i64 {
            placed.iter().map(|p| ((x + tw).min(p[2]) - x.max(p[0])).max(0) * ((y + th).min(p[3]) - y.max(p[1])).max(0)).sum()
        };
        let best = cands.iter().map(|&p| clamp(p)).min_by_key(|&p| overlap(p)).unwrap_or((0, 0));
        let (x, y) = best;
        cv.fill(x - 1, y - 1, x + tw + 1, y + th + 1, [20, 20, 20]);
        cv.fill(x, y, x + tw, y + th, c);
        cv.text(x + pad, y + pad, &s, k, [255, 255, 255]);
        placed.push([x, y, x + tw, y + th]);
    }
    els.len()
}

fn png(rgb: &[u8], w: usize, h: usize) -> Result<Vec<u8>> {
    let mut out = Vec::new();
    {
        let mut e = png::Encoder::new(&mut out, w as u32, h as u32);
        e.set_color(png::ColorType::Rgb);
        e.set_depth(png::BitDepth::Eight);
        e.write_header()?.write_image_data(rgb)?;
    }
    Ok(out)
}

/// A screenshot with marks, of a fresh snapshot (`ocr`: also the whole screen's text read from pixels). Answers the
/// PNG, its size, how many marks, and the snapshot (its text says what each ref is).
pub fn marked(inst: &Instance, m: Marks, div: u32, ocr: bool) -> Result<(Vec<u8>, u32, u32, usize, Snapshot)> {
    let snap = ax::snapshot(inst, ax::SnapOpts { ocr, ..Default::default() })?;
    if snap.platform == "xros" {
        bail!("Vision Pro: element frames are in each window's own points, not the display's: no marks");
    }
    let (mut rgb, w, h, _) = ax::upright_frame(inst, snap.rot, div)?;
    let n = draw(&mut rgb, w, h, &snap, m);
    Ok((png(&rgb, w, h)?, w as u32, h as u32, n, snap))
}

/// A screenshot of one element (ref, id:, text: as tap finds it), cropped to its frame and a margin of a quarter of
/// its size (at least 12 points, at most 60). Answers the PNG, its size and the element.
pub fn element_shot(inst: &Instance, target: &str, div: u32) -> Result<(Vec<u8>, u32, u32, El)> {
    if matches!(ax::parse_target(target), ax::Target::Point(..)) {
        bail!("target: an element (@ref, id:..., or its text), not a point");
    }
    let (e, snap) = ax::resolve(inst, target)?;
    if e.offscreen {
        bail!("@{} is scrolled out of view (scroll_to it first)", e.r);
    }
    let (rgb, w, h, _) = ax::upright_frame(inst, snap.rot, div)?;
    let f = w as f64 / snap.screen.0.max(1.0);
    let [x, y, ew, eh] = e.frame;
    let mx = (ew / 4.0).clamp(12.0, 60.0);
    let my = (eh / 4.0).clamp(12.0, 60.0);
    let x0 = (((x - mx) * f).floor().max(0.0) as usize).min(w.saturating_sub(1));
    let y0 = (((y - my) * f).floor().max(0.0) as usize).min(h.saturating_sub(1));
    let x1 = (((x + ew + mx) * f).ceil() as usize).clamp(x0 + 1, w);
    let y1 = (((y + eh + my) * f).ceil() as usize).clamp(y0 + 1, h);
    let (cw, ch) = (x1 - x0, y1 - y0);
    let mut out = Vec::with_capacity(cw * ch * 3);
    for row in y0..y1 {
        out.extend_from_slice(&rgb[(row * w + x0) * 3..(row * w + x1) * 3]);
    }
    Ok((png(&out, cw, ch)?, cw as u32, ch as u32, e))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn el(r: &str, role: &str, frame: [f64; 4]) -> El {
        El { r: r.into(), role: role.into(), frame, layer: "app".into(), enabled: true, ..Default::default() }
    }

    #[test]
    fn marks_outline_and_tag() {
        let snap = Snapshot { screen: (100.0, 100.0), elements: vec![el("e1", "button", [20.0, 40.0, 40.0, 20.0]), el("e2", "text", [20.0, 70.0, 40.0, 10.0])], ..Default::default() };
        let mut px = vec![255u8; 100 * 100 * 3];
        assert_eq!(draw(&mut px, 100, 100, &snap, Marks::Actionable), 1);
        // the outline's color at the element's left edge
        let o = (50 * 100 + 20) * 3;
        assert_eq!(&px[o..o + 3], &PALETTE[0]);
        let mut px = vec![0u8; 100 * 100 * 3];
        assert_eq!(draw(&mut px, 100, 100, &snap, Marks::All), 2);
        // white digits somewhere (the tags)
        assert!(px.chunks(3).any(|c| c == [255, 255, 255]));
    }

    #[test]
    fn parse_marks() {
        assert_eq!(Marks::parse("true"), Some(Marks::All));
        assert_eq!(Marks::parse("actionable"), Some(Marks::Actionable));
        assert_eq!(Marks::parse("false"), None);
    }
}
