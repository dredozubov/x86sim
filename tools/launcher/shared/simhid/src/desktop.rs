// SPDX-License-Identifier: GPL-3.0-or-later
//! Desktop inputs carried by the simhid line socket. A touch controls an absolute pointer.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Event(pub u16, pub u16, pub i32);

impl Event {
    pub fn to_le_bytes(self) -> [u8; 8] {
        let mut out = [0; 8];
        out[..2].copy_from_slice(&self.0.to_le_bytes());
        out[2..4].copy_from_slice(&self.1.to_le_bytes());
        out[4..].copy_from_slice(&self.2.to_le_bytes());
        out
    }
}

fn number(token: &str) -> Option<u32> {
    match token.strip_prefix("0x") {
        Some(hex) => u32::from_str_radix(hex, 16).ok(),
        None => token.parse().ok(),
    }
}

// USB keyboard usages to Linux input-event-codes.
fn key(usage: u32) -> Option<u16> {
    Some(match usage {
        4..=29 => [
            30, 48, 46, 32, 18, 33, 34, 35, 23, 36, 37, 38, 50, 49, 24, 25, 16, 19, 31, 20, 22, 47,
            17, 45, 21, 44,
        ][usage as usize - 4],
        30..=39 => (usage - 28) as u16,
        40..=57 => [
            28, 1, 14, 15, 57, 12, 13, 26, 27, 43, 43, 39, 40, 41, 51, 52, 53, 58,
        ][usage as usize - 40],
        58..=67 => (usage + 1) as u16,
        68..=83 => [
            87, 88, 99, 70, 119, 110, 102, 104, 111, 107, 109, 106, 105, 108, 103, 69,
        ][usage as usize - 68],
        84..=103 => [
            98, 55, 74, 78, 96, 79, 80, 81, 75, 76, 77, 71, 72, 73, 82, 83, 86, 127, 116, 117,
        ][usage as usize - 84],
        224..=231 => [29, 42, 56, 125, 97, 54, 100, 126][usage as usize - 224],
        _ => return None,
    })
}

/// Decode one complete simhid command. Ignore simulator-only controls and unknown usage pages.
pub fn events(line: &str) -> Option<Vec<Event>> {
    let mut args = line.split_ascii_whitespace();
    let mut events = match args.next()? {
        "key" => {
            let down = match args.next()? {
                "down" => 1,
                "up" => 0,
                _ => return None,
            };
            let code = key(number(args.next()?)?)?;
            if args.next().is_some_and(|page| number(page) != Some(7)) {
                return None;
            }
            vec![Event(1, code, down)]
        }
        "touch" => {
            let phase = args.next()?;
            let coord = |v: &str| {
                let n: f64 = v.parse().ok()?;
                n.is_finite()
                    .then(|| (n.clamp(0.0, 1.0) * 32767.0).round() as i32)
            };
            let mut ev = vec![
                Event(3, 0, coord(args.next()?)?),
                Event(3, 1, coord(args.next()?)?),
            ];
            match phase {
                "move" => {}
                "down" | "up" => ev.push(Event(1, 272, i32::from(phase == "down"))),
                _ => return None,
            }
            if args
                .next()
                .is_some_and(|edge| !matches!(edge, "top" | "bottom" | "left" | "right"))
            {
                return None;
            }
            ev
        }
        _ => return None,
    };
    if args.next().is_some() {
        return None;
    }
    events.push(Event(0, 0, 0));
    Some(events)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn desktop_wire_records_have_a_report_boundary() {
        assert_eq!(
            events("key down 0x04"),
            Some(vec![Event(1, 30, 1), Event(0, 0, 0)])
        );
        assert_eq!(
            events("key up 0xe1 7").unwrap()[0].to_le_bytes(),
            [1, 0, 42, 0, 0, 0, 0, 0]
        );
        assert_eq!(
            events("touch down 0.5 1 right").unwrap(),
            [
                Event(3, 0, 16384),
                Event(3, 1, 32767),
                Event(1, 272, 1),
                Event(0, 0, 0)
            ]
        );
        for line in [
            "touch move NaN 1",
            "key down 0x04 0xc",
            "key down 0xc0",
            "kbidle 300",
        ] {
            assert_eq!(events(line), None);
        }
    }
}
