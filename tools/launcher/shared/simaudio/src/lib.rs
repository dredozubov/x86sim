// SPDX-License-Identifier: GPL-3.0-or-later
//! PipeWire tap and browser audio framing used by x86Sim.
use std::io::Read;

pub const RATE: u32 = 48000;
/// frames a packet (10 ms)
pub const FRAMES: usize = 480;
pub const KIND_OPUS: u8 = 3;
pub const KIND_PCM: u8 = 4;
/// a browser's microphone frame on the socket (first byte of a binary message, then s16 LE mono 48 kHz)
pub const KIND_MIC: u8 = 5;

pub const OP_OPEN: u8 = 1;
pub const OP_DATA: u8 = 2;
pub const OP_CLOSE: u8 = 3;
pub const OP_MIC: u8 = 4;
pub const OP_MIC_OFF: u8 = 5;

pub fn read_msg(s: &mut impl Read) -> std::io::Result<(u8, u32, Vec<u8>)> {
    let mut h = [0u8; 9];
    s.read_exact(&mut h)?;
    let n = u32::from_le_bytes(h[5..9].try_into().unwrap()) as usize;
    if n > 1 << 22 {
        return Err(std::io::Error::other("tap message too large"));
    }
    let mut p = vec![0u8; n];
    s.read_exact(&mut p)?;
    Ok((h[0], u32::from_le_bytes(h[1..5].try_into().unwrap()), p))
}

pub fn tap_msg(op: u8, payload: &[u8]) -> Vec<u8> {
    let mut v = Vec::with_capacity(9 + payload.len());
    v.push(op);
    v.extend_from_slice(&0u32.to_le_bytes());
    v.extend_from_slice(&(payload.len() as u32).to_le_bytes());
    v.extend_from_slice(payload);
    v
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn tap_matches_the_python_service_header() {
        let message = tap_msg(OP_MIC, &[1, 2, 3, 4]);
        assert_eq!(message, [4, 0, 0, 0, 0, 4, 0, 0, 0, 1, 2, 3, 4]);
        assert_eq!(
            read_msg(&mut &message[..]).unwrap(),
            (OP_MIC, 0, vec![1, 2, 3, 4])
        );
        assert!(read_msg(&mut &[2, 1, 0, 0, 0, 0xff, 0xff, 0xff, 0xff][..]).is_err());
    }
}
