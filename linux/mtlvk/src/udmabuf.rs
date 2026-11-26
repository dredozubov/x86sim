//! x86Sim (issue #39): a guest memfd's pages as a dma-buf, through /dev/udmabuf.
//!
//! mtlvk imports a guest buffer's pages by their address (VK_EXT_external_memory_host). On amdgpu that is a userptr
//! BO, and libdrm's `amdgpu_create_bo_from_user_mem()` always asks AMDGPU_GEM_USERPTR_ANONONLY, which the kernel
//! refuses for file-backed pages: darlingserver's guest memory is memfd (shmem), so RADV refused every import and every
//! buffer was mirrored (mtlvk spent nearly all its time in memmove). udmabuf makes a dma-buf of a memfd range instead,
//! which RADV imports with VK_EXT_external_memory_dma_buf. The kernel takes only a memfd sealed F_SEAL_SHRINK (and not
//! F_SEAL_WRITE); darlingserver seals its memory-entry memfds so.
//!
//! MTLVK_UDMABUF=0 turns it off (buffers that the host-pointer import refuses are mirrored, as before);
//! MTLVK_UDMABUF=<path> opens another device node (a missing path: as if /dev/udmabuf were absent).

use std::os::fd::{AsRawFd, FromRawFd, OwnedFd, RawFd};
use std::sync::atomic::AtomicBool;
use std::sync::OnceLock;

/// `struct udmabuf_create` (linux/udmabuf.h).
#[repr(C)]
struct Create {
    memfd: u32,
    flags: u32,
    offset: u64,
    size: u64,
}

const UDMABUF_FLAGS_CLOEXEC: u32 = 0x01;
/// `_IOW('u', 0x42, struct udmabuf_create)`
const UDMABUF_CREATE: libc::c_ulong = (1 << 30) | ((std::mem::size_of::<Create>() as libc::c_ulong) << 16) | (0x75 << 8) | 0x42;

/// The device node, opened once; None where it is off, missing or not ours to open (logged once).
fn device() -> Option<&'static OwnedFd> {
    static DEV: OnceLock<Option<OwnedFd>> = OnceLock::new();
    DEV.get_or_init(|| {
        let path = match std::env::var("MTLVK_UDMABUF") {
            Ok(v) if v == "0" => {
                eprintln!("mtlvk: udmabuf off (MTLVK_UDMABUF=0)");
                crate::bufstate::set_udmabuf("off: MTLVK_UDMABUF=0".into());
                return None;
            }
            Ok(v) if v.starts_with('/') => v,
            _ => "/dev/udmabuf".to_owned(),
        };
        let c = std::ffi::CString::new(path.clone()).ok()?;
        // SAFETY: opening a path; the fd is owned below.
        let fd = unsafe { libc::open(c.as_ptr(), libc::O_RDWR | libc::O_CLOEXEC) };
        if fd < 0 {
            let e = std::io::Error::last_os_error();
            eprintln!("mtlvk: udmabuf: {path}: {e}; a buffer whose import is refused is mirrored");
            crate::bufstate::set_udmabuf(format!("unavailable: {path}: {e}"));
            return None;
        }
        crate::bufstate::set_udmabuf("on".into());
        // SAFETY: we just opened it.
        Some(unsafe { OwnedFd::from_raw_fd(fd) })
    })
    .as_ref()
}

/// Set once a host-pointer import was refused and a udmabuf one then succeeded: later buffers try udmabuf first
/// (RADV refuses every host-pointer import of a memfd, and each refusal is a failed vkAllocateMemory).
pub static FIRST: AtomicBool = AtomicBool::new(false);

/// A dma-buf of `size` bytes of `memfd` at `offset` (both page-aligned). Err: why not, for the log.
pub fn create(memfd: RawFd, offset: u64, size: u64) -> Result<OwnedFd, String> {
    let dev = device().ok_or("no /dev/udmabuf")?;
    let arg = Create { memfd: memfd as u32, flags: UDMABUF_FLAGS_CLOEXEC, offset, size };
    // SAFETY: the ioctl reads `arg`; it returns a new fd we own.
    let fd = unsafe { libc::ioctl(dev.as_raw_fd(), UDMABUF_CREATE, &arg) };
    if fd < 0 {
        let e = std::io::Error::last_os_error();
        let mut why = format!("UDMABUF_CREATE {size} bytes at {offset}: {e}");
        if e.raw_os_error() == Some(libc::EINVAL) {
            // SAFETY: a query of the memfd's seals.
            let seals = unsafe { libc::fcntl(memfd, libc::F_GET_SEALS) };
            if seals >= 0 && seals & libc::F_SEAL_SHRINK == 0 {
                why += " (memfd not sealed F_SEAL_SHRINK: an older darlingserver?)";
            } else if seals >= 0 && seals & libc::F_SEAL_WRITE != 0 {
                why += " (memfd sealed F_SEAL_WRITE)";
            } else {
                why += " (past udmabuf's size_limit_mb?)";
            }
        }
        return Err(why);
    }
    // SAFETY: the ioctl returned a new fd.
    Ok(unsafe { OwnedFd::from_raw_fd(fd) })
}
