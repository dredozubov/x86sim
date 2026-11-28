// SPDX-License-Identifier: GPL-3.0-or-later
//! Shared, little-endian BGRA scanout ring used by x86Sim viewers.
pub const HEADER_BYTES: usize = 4096;
pub const MAGIC: &[u8; 4] = b"SFBR";
pub const SEQUENCE: usize = 32;
pub const LATEST: usize = 40;
pub const SLOT_TABLE: usize = 64;
pub const SLOT_HEADER: usize = 32;
pub const SLOT_COUNT: usize = 3;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Geometry {
    width: u32,
    height: u32,
    stride: u32,
    bytes: u32,
}

impl Geometry {
    pub fn bgra(width: u32, height: u32) -> Option<Self> {
        let stride = width.checked_mul(4)?;
        let bytes = stride.checked_mul(height)?;
        (bytes > 0).then_some(Self {
            width,
            height,
            stride,
            bytes,
        })
    }
    pub fn width(self) -> u32 {
        self.width
    }
    pub fn height(self) -> u32 {
        self.height
    }
    pub fn stride(self) -> u32 {
        self.stride
    }
    pub fn frame_bytes(self) -> u32 {
        self.bytes
    }
}

#[cfg(target_os = "linux")]
mod writer;
#[cfg(target_os = "linux")]
pub use writer::Publisher;

/// A single slot observed in a mapped ring. Call `is_current` after reading the pixels.
pub struct Slot<'a> {
    pub width: u32,
    pub height: u32,
    pub stride: u32,
    pub seq: u64,
    pub time_ns: u64,
    pub pixels: &'a [u8],
    slot_sequence: &'a [u8; 8],
}

impl<'a> Slot<'a> {
    pub fn latest(map: &'a [u8]) -> Option<Self> {
        let u32_at = |off: usize| Some(u32::from_le_bytes(map.get(off..off + 4)?.try_into().ok()?));
        let u64_at = |off: usize| Some(u64::from_le_bytes(map.get(off..off + 8)?.try_into().ok()?));
        if map.get(..4)? != MAGIC || u64_at(SEQUENCE)? == 0 {
            return None;
        }
        let count = u32_at(8)? as usize;
        let bytes = u32_at(12)? as usize;
        let index = u32_at(LATEST)? as usize;
        if index >= count || index >= (HEADER_BYTES - SLOT_TABLE) / SLOT_HEADER {
            return None;
        }
        let h = SLOT_TABLE + SLOT_HEADER * index;
        let slot_sequence = map.get(h..h + 8)?.try_into().ok()?;
        let seq = sequence(slot_sequence);
        std::sync::atomic::fence(std::sync::atomic::Ordering::Acquire);
        let time_ns = u64_at(h + 8)?;
        let width = u32_at(h + 16)?;
        let height = u32_at(h + 20)?;
        let stride = u32_at(h + 24)?;
        let len = (stride as usize).checked_mul(height as usize)?;
        if seq == 0 || width == 0 || height == 0 || stride < width.checked_mul(4)? || len > bytes {
            return None;
        }
        let base = HEADER_BYTES.checked_add(index.checked_mul(bytes)?)?;
        let pixels = map.get(base..base.checked_add(len)?)?;
        Some(Self {
            width,
            height,
            stride,
            seq,
            time_ns,
            pixels,
            slot_sequence,
        })
    }

    pub fn is_current(&self) -> bool {
        std::sync::atomic::fence(std::sync::atomic::Ordering::SeqCst);
        sequence(self.slot_sequence) == self.seq
    }
}

fn sequence(field: &[u8; 8]) -> u64 {
    // The external producer changes the field between calls. Volatile byte reads also
    // support a byte slice whose first address is unaligned.
    u64::from_le_bytes(std::array::from_fn(|i| unsafe {
        field.as_ptr().add(i).read_volatile()
    }))
}
