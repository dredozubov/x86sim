//! Characters to keyboard presses on a US layout: HID keyboard page (0x07) usages, as host/simhid sends them.

/// One key press for a character: the usage and whether Shift is held with it.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Stroke {
    pub usage: u32,
    pub shift: bool,
}

// The keyboard page's contiguous runs, each listed as (first usage, unshifted legends, shifted legends). '\0' marks a
// usage with no US legend (0x32, the ISO key next to Enter).
const RUNS: [(u32, &str, &str); 3] = [
    (0x04, "abcdefghijklmnopqrstuvwxyz", "ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
    (0x1e, "1234567890", "!@#$%^&*()"),
    (0x2d, "-=[]\\\0;'`,./", "_+{}|\0:\"~<>?"),
];

/// The key that types `c` on a US keyboard, or None when no single key does.
pub fn us_stroke(c: char) -> Option<Stroke> {
    match c {
        '\n' => return Some(Stroke { usage: 0x28, shift: false }),
        '\t' => return Some(Stroke { usage: 0x2b, shift: false }),
        ' ' => return Some(Stroke { usage: 0x2c, shift: false }),
        '\0' => return None,
        _ => {}
    }
    RUNS.iter().find_map(|&(first, plain, shifted)| {
        let at = |legends: &str| legends.chars().position(|l| l == c).map(|i| first + i as u32);
        at(plain).map(|usage| Stroke { usage, shift: false }).or_else(|| at(shifted).map(|usage| Stroke { usage, shift: true }))
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_printable_ascii_has_one_key() {
        for b in 0x20u8..0x7f {
            assert!(us_stroke(b as char).is_some(), "{:?}", b as char);
        }
        assert_eq!(us_stroke('é'), None);
        assert_eq!(us_stroke('\u{7f}'), None);
    }

    #[test]
    fn shift_pairs_share_a_key() {
        for (lo, hi) in [('q', 'Q'), ('7', '&'), ('0', ')'), ('[', '{'), ('\'', '"'), ('/', '?')] {
            let (a, b) = (us_stroke(lo).unwrap(), us_stroke(hi).unwrap());
            assert_eq!(a.usage, b.usage, "{lo} {hi}");
            assert!(!a.shift && b.shift, "{lo} {hi}");
        }
    }

    #[test]
    fn spec_usages() {
        let u = |c| us_stroke(c).unwrap().usage;
        assert_eq!((u('x'), u('9'), u('\n'), u('`'), u('\\'), u(';')), (0x1b, 0x26, 0x28, 0x35, 0x31, 0x33));
    }
}
