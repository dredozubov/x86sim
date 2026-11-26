# simfb: display and frame output

`host/simfb/simfb.c` builds `SimFramebuffer.framework`, a stand-in for CoreSimulator's framework of the same name.
backboardd (CoreAnimation's render server) loads it from `SIMULATOR_FRAMEBUFFER_FRAMEWORK` (set by
`cli/libexec/mksimdevice.py`). The API it implements is declared in `host/simfb/SimFramebuffer.h` (reconstructed from
the runtime's QuartzCore/backboardd callers). The main display must be named `LCD`: QuartzCore treats any other
name as no main display.

There is no host: simfb reports the device's built-in display (its size and scale from `sim.env`'s
`SIMULATOR_MAINSCREEN_WIDTH` / `HEIGHT` / `SCALE`, which `mksimdevice.py` sets per model), hands CoreAnimation
IOSurface-backed swapchain buffers and, on every present (`SFBSwapchainSwapSubmit`), copies the frame out once the GPU
work for it has completed (with Metal, simfb waits for the MTLSimCommandBuffer completion; a 1 s watchdog copies
anyway).

- **Several screens.** A device whose capabilities (`$SIMULATOR_CAPABILITIES`) list two or more `integrated` displays
  (the iPhone Duo: the outer `LCD`, 1398x2034, and the inner `LCD-1`, 2007x2853) gets one SFB display per entry, each
  with its own frame ring (the first `$SIMFB_RING`, display N `<ring>-N.ring`), present queue and refresh pacing.
  `SIMFB_DISPLAYS=1` forces one display.
- **Apple TV.** Its screen is the device type's `tvOut` display; simfb reports it as an external display (SFB type 1)
  with an sRGB mode, as Apple's tvOS simulator does (`SIMFB_DISPLAY_TYPE` overrides).
- **Backpressure.** `SFBSwapchainSwapBegin` returns only once fewer than `SIMFB_MAX_INFLIGHT` (default 1) of the
  display's presents still wait for the GPU, waiting at most `SIMFB_BEGIN_WAIT_MS` (default 100; 0 in either turns
  the wait off). Apple's render server cannot start a frame before a swapchain surface is free; without this the
  render server queued more frames than a slow GPU could draw.
- **Pacing.** A present whose GPU work is done is published at the next refresh slot after the previous publish
  (`SIMFB_HZ`, default 60; 0 publishes at once); a newer ready present replaces one still waiting (counted as
  superseded).

## Frame ring

One ring per display, written in the user's runtime directory: `sim.env`'s `SIMFB_RING` is
`/Volumes/SystemRoot/run/user/<uid>/x86sim-a64[-<name>]-simfb.ring` for device `device-a64[-<name>]`
(`cli/lib/x86config.py` `run_dir`: `$XDG_RUNTIME_DIR`, else `/run/user/<uid>`, else a private `/tmp/x86sim-<uid>`).
boot-a64.sh links it from `/dev/shm/<same name>`, and `$SIMFB_RING_LINUX` (default
`/dev/shm/x86sim-a64-simfb.ring`, the default device's) names the ring for the Python readers. Readers:
`cli/libexec/fbring.py` (library), `simview.py` (viewer), `fb2png.py`, `fpsmeter.py`, `framecheck.py`, and the
launcher's `tools/launcher/core/src/ring.rs` (which reads a booted device's ring path from its `sim.env`).

```
x86Sim: reader for host/simfb's shared-memory frame ring (/dev/shm/x86sim-simfb.ring).
Layout (little-endian), written by simfb in SFBSwapchainSwapSubmit's copy:
  header (4096 bytes): magic 'SFBR' u32, version u32, nslots u32, slot_bytes u32, width u32, height u32,
      stride u32, pad u32, seq u64 (frames published), latest u32 (slot of frame seq), pad u32,
      then per slot (at 64 + 32*i): seq u64 (0 while being written), time_ns u64 (CLOCK_REALTIME at publish),
      width u32, height u32, stride u32, pad u32
  statistics at 192 (u64 each, since simfb's process started): submits, superseded (a newer present came while
      waiting for the GPU), watchdog (copied after 1 s without GPU completion), copied, ready_at_submit, wait_ns
      (sum of submit->GPU-complete waits of copied presents), wait_max_ns, copy_ns (sum of copy times), copy_max_ns, pid
  slot i at 4096 + i*slot_bytes: BGRA rows (stride bytes each).
simfb writes a slot other than the latest, then sets its slot seq and the header's latest/seq. A reader copies the
latest slot and checks the slot's seq is unchanged afterwards (it only changes once nslots-1 newer frames came).
Fallback: the old framebuffer.bgra file ({w, h, stride, seq} + rows), which simfb still writes every 2 s.
    cli/libexec/fbring.py            print the ring's state
```

(The block above is `fbring.py`'s own header.) In `simfb.c` the last u32 of a slot record is `age_us`: the publish
time minus the present's `SwapSubmit` time in microseconds. `nslots` is 3; the header keeps room for 4 slot records,
so the statistics stay at 192.

**Repeated frames.** A present whose pixels equal the latest frame is not copied into a new slot. The latest slot is
republished at most once a second (its seq and time only), for readers waiting on a newer frame.

**Idle trim.** After `SIMFB_RING_IDLE_MS` (default 1500; 0 = never) without a new frame, the slots other than the
latest are given back to the system (`MADV_REMOVE` on the tmpfs range; a later write takes new zeroed pages). A
still screen costs one frame of shared memory per display.

**Wakeups (version 2).** After each publish simfb calls Linux `futex(FUTEX_WAKE)` on the low 32 bits of the
header's `seq` (offset 32; a shared futex, the page is a `/dev/shm` file; Darling processes make Linux syscalls
directly). Readers wait with `FUTEX_WAIT` on that word (`fbring.Ring.wait(seq, timeout)`, which falls back to 4 ms
polling for a version-1 ring), so nothing wakes while the screen is still.

The ring is recreated by each boot's simfb (a new file per process, renamed into place, so readers of an older ring
see its inode go away); the boot deletes the old file first so a stale frame is never taken for the new boot's.

## framebuffer.bgra (legacy)

`$SIMFB_OUT` (default `$HOME/framebuffer.bgra`, i.e. `<device>/data/framebuffer.bgra` for backboardd): 16-byte header
`{u32 w, h, stride, seq}` + BGRA rows, written at most every 2 s. Kept for tools that predate the ring.
