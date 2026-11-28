// SPDX-License-Identifier: GPL-3.0-or-later
use super::*;
use memmap2::MmapMut;
use std::fs::File;
use std::io;
use std::sync::atomic::{fence, AtomicU32, AtomicU64, Ordering};

/// The caller owns a fresh ring inode for the lifetime of this publisher.
/// Readers may map it before the first frame; seq zero means no frame.
pub struct Publisher {
    map: MmapMut,
    geometry: Geometry,
    seq: u64,
}

impl Publisher {
    /// The caller supplies a newly created, private, empty file. Never truncate a live ring.
    pub fn new(file: &File, geometry: Geometry) -> io::Result<Self> {
        if file.metadata()?.len() != 0 {
            return Err(io::Error::new(
                io::ErrorKind::AlreadyExists,
                "expected an empty ring",
            ));
        }
        let length = HEADER_BYTES as u64 + SLOT_COUNT as u64 * u64::from(geometry.frame_bytes());
        file.set_len(length)?;
        let mut map = unsafe { MmapMut::map_mut(file)? };
        map[..4].copy_from_slice(MAGIC);
        for (i, v) in [
            2,
            SLOT_COUNT as u32,
            geometry.frame_bytes(),
            geometry.width(),
            geometry.height(),
            geometry.stride(),
        ]
        .into_iter()
        .enumerate()
        {
            map[4 + i * 4..8 + i * 4].copy_from_slice(&v.to_le_bytes());
        }
        Ok(Self {
            map,
            geometry,
            seq: 0,
        })
    }

    /// Publish changed pixels and wake cross-process FUTEX_WAIT readers.
    pub fn present(&mut self, bgra: &[u8], unix_ns: u64) -> io::Result<bool> {
        let bytes = self.geometry.frame_bytes() as usize;
        if bgra.len() != bytes {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "unexpected BGRA frame length",
            ));
        }
        let latest = (self.seq % SLOT_COUNT as u64) as usize;
        let previous = HEADER_BYTES + latest * bytes;
        if self.seq != 0 && &self.map[previous..previous + bytes] == bgra {
            return Ok(false);
        }
        let seq = self
            .seq
            .checked_add(1)
            .ok_or_else(|| io::Error::other("ring sequence exhausted"))?;
        let slot = (seq % SLOT_COUNT as u64) as usize;
        let header = SLOT_TABLE + SLOT_HEADER * slot;
        let pixels = HEADER_BYTES + slot * bytes;
        let base = self.map.as_mut_ptr();
        // mmap returns a page-aligned address; sequence fields are 8-byte aligned.
        let slot_seq = unsafe { AtomicU64::from_ptr(base.add(header).cast()) };
        slot_seq.store(0, Ordering::SeqCst);
        fence(Ordering::SeqCst);
        self.map[pixels..pixels + bytes].copy_from_slice(bgra);
        self.map[header + 8..header + 16].copy_from_slice(&unix_ns.to_le_bytes());
        for (i, v) in [
            self.geometry.width(),
            self.geometry.height(),
            self.geometry.stride(),
        ]
        .into_iter()
        .enumerate()
        {
            let p = header + 16 + 4 * i;
            self.map[p..p + 4].copy_from_slice(&v.to_le_bytes());
        }
        unsafe {
            AtomicU64::from_ptr(base.add(header).cast()).store(seq.to_le(), Ordering::Release);
            AtomicU32::from_ptr(base.add(LATEST).cast())
                .store((slot as u32).to_le(), Ordering::Release);
            AtomicU64::from_ptr(base.add(SEQUENCE).cast()).store(seq.to_le(), Ordering::Release);
            libc::syscall(
                libc::SYS_futex,
                base.add(SEQUENCE).cast::<u32>(),
                libc::FUTEX_WAKE,
                i32::MAX,
                std::ptr::null::<libc::timespec>(),
                std::ptr::null::<u32>(),
                0u32,
            );
        }
        self.seq = seq;
        Ok(true)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use memmap2::Mmap;
    use std::fs::OpenOptions;
    use std::os::unix::fs::OpenOptionsExt;

    #[test]
    fn ring_wraps_and_unchanged_frames_keep_the_sequence() {
        let path = std::env::temp_dir().join(format!("simfb-writer-{}", std::process::id()));
        let file = OpenOptions::new()
            .create_new(true)
            .mode(0o600)
            .read(true)
            .write(true)
            .open(&path)
            .unwrap();
        std::fs::remove_file(path).unwrap();
        let mut publisher = Publisher::new(&file, Geometry::bgra(2, 1).unwrap()).unwrap();
        let reader = unsafe { Mmap::map(&file).unwrap() };
        assert!(Slot::latest(&reader).is_none());
        for n in 1..8 {
            assert!(publisher.present(&[n; 8], 100 + n as u64).unwrap());
            assert!(!publisher.present(&[n; 8], 100 + n as u64).unwrap());
            let slot = Slot::latest(&reader).unwrap();
            assert_eq!(
                (slot.width, slot.height, slot.stride, slot.seq, slot.time_ns),
                (2, 1, 8, n as u64, 100 + n as u64)
            );
            assert_eq!(slot.pixels, [n; 8]);
            assert!(slot.is_current());
        }
    }
}
