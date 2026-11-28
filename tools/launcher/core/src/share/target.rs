//! Framebuffer and socket endpoints used by the GTK and browser viewers.
use crate::hid::{self, Hid};
use crate::instance::Instance;
use std::path::{Path, PathBuf};

/// What a browser sees of a phone and where its touches go (the launcher's Viewer::set_display rule)
#[derive(Clone, Debug, PartialEq)]
pub struct Target {
    pub ring: PathBuf,
    /// the screen's size upright, device pixels
    pub size: (u32, u32),
    /// the picture's turn (hid::unrotate / Frame::png convention)
    pub rot: u32,
    /// for hid: a second display (SFB id, its turn) and the main screen's turn
    pub display: Option<(u32, u32)>,
    pub main_rot: u32,
}

/// Which screen a stream shows: `Auto` the one in use (target), or a two-screen phone's inner or outer screen as it
/// is, never turned by the device orientation (the web page's 3D model turns the phone instead, as duo3d.rs does)
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Screen {
    Auto,
    Inner,
    Outer,
}

/// Device discovery and orientation belong to the producer. The viewer only needs these endpoints.
pub trait GuestDisplayTarget {
    fn primary(&self) -> (&Path, (u32, u32));
    fn input_socket(&self) -> &Path;
    fn audio_tap(&self) -> Option<PathBuf>;

    fn hid(&self) -> Hid {
        Hid::new(self.input_socket())
    }

    fn screen(&self, _which: Screen, _orient: &mut u32) -> Target {
        let (ring, size) = self.primary();
        Target {
            ring: ring.to_owned(),
            size,
            rot: 0,
            display: None,
            main_rot: 0,
        }
    }
}

impl Instance {
    pub(super) fn simulator_audio_tap(&self) -> PathBuf {
        self.state_dir.join("simaudio-tap.sock")
    }
}

impl GuestDisplayTarget for Instance {
    fn primary(&self) -> (&Path, (u32, u32)) {
        (&self.ring, self.screen)
    }

    fn input_socket(&self) -> &Path {
        &self.sock
    }

    fn audio_tap(&self) -> Option<PathBuf> {
        Some(self.simulator_audio_tap())
    }

    fn screen(&self, which: Screen, orient: &mut u32) -> Target {
        match (which, &self.inner) {
            (Screen::Inner, Some(d)) => {
                return Target {
                    ring: d.ring.clone(),
                    size: d.upright(),
                    rot: d.rotation,
                    display: Some((d.id, d.rotation)),
                    main_rot: 0,
                };
            }
            (Screen::Outer, Some(_)) => {
                return Target {
                    ring: self.ring.clone(),
                    size: self.screen,
                    rot: 0,
                    display: None,
                    main_rot: 0,
                };
            }
            _ => {}
        }
        if self.platform == "ios" {
            if let Some(o) = self.orientation().and_then(|o| hid::orientation_rot(&o)) {
                *orient = o;
            }
        }
        let o = *orient;
        let (ring, screen, panel) = match &self.inner {
            Some(d) if self.inner_active() => (d.ring.clone(), d.upright(), Some((d.id, d.rotation))),
            _ => (self.ring.clone(), self.screen, None),
        };
        let size = if o % 180 == 90 { (screen.1, screen.0) } else { screen };
        Target {
            ring,
            size,
            rot: (panel.map(|p| p.1).unwrap_or(0) + o) % 360,
            display: panel.map(|(id, r)| (id, (r + o) % 360)),
            main_rot: o,
        }
    }
}

/// One upright display supplied by a process outside the simulator.
#[derive(Clone)]
pub struct StandaloneDisplay {
    pub ring: PathBuf,
    pub size: (u32, u32),
    pub input_socket: PathBuf,
    pub audio_tap: Option<PathBuf>,
}

impl GuestDisplayTarget for StandaloneDisplay {
    fn primary(&self) -> (&Path, (u32, u32)) {
        (&self.ring, self.size)
    }

    fn input_socket(&self) -> &Path {
        &self.input_socket
    }

    fn audio_tap(&self) -> Option<PathBuf> {
        self.audio_tap.clone()
    }
}

#[cfg(all(test, target_os = "linux"))]
mod tests {
    use super::*;
    use crate::share::{audio, video};
    use simfb_ring::{Geometry, Publisher};
    use std::io::{BufRead, BufReader};
    use std::os::unix::net::UnixListener;
    use std::sync::{atomic::Ordering, mpsc};
    use std::time::{Duration, Instant};

    #[test]
    fn standalone_browser_frame_input_and_optional_audio() {
        let dir = std::env::temp_dir().join(format!("x86sim-display-target-{}", std::process::id()));
        std::fs::create_dir(&dir).unwrap();
        let mut guest = StandaloneDisplay {
            ring: dir.join("frame.ring"),
            size: (32, 16),
            input_socket: dir.join("keyboard.sock"),
            audio_tap: None,
        };
        let ring = std::fs::File::create_new(&guest.ring).unwrap();
        let mut publisher = Publisher::new(&ring, Geometry::bgra(32, 16).unwrap()).unwrap();
        let pixels = [0x10, 0x20, 0x30, 0xff].repeat(32 * 16);
        publisher.present(&pixels, 1_000_000).unwrap();
        let png = video::snapshot_png(&guest).unwrap();
        assert_eq!(&png[..8], b"\x89PNG\r\n\x1a\n");
        let (send, recv) = mpsc::sync_channel(8);
        let key = video::StreamKey {
            phone: "standalone".into(),
            codec: video::Codec::Jpeg,
            width: 32,
            quality: 1,
            fps: 30,
            screen: Screen::Auto,
        };
        let (stream, sub) = video::join(&guest, key, send);
        let timeout = Duration::from_secs(3);
        let pkt = loop {
            if let video::Out::Video(pkt, _) = recv.recv_timeout(timeout).unwrap() {
                break pkt;
            }
        };
        assert_eq!(&pkt[..6], &[2, 1, 32, 0, 16, 0]);
        assert_eq!(&pkt[video::HDR_LEN..video::HDR_LEN + 2], &[0xff, 0xd8]);
        stream.leave(sub);

        let listener = UnixListener::bind(&guest.input_socket).unwrap();
        let mut hid = guest.hid();
        hid.key(true, 4);
        hid.touch("down", 0.5, 0.25, None);
        let mut lines = BufReader::new(listener.accept().unwrap().0).lines();
        assert!(lines.next().unwrap().unwrap().starts_with("kbidle "));
        assert_eq!(lines.next().unwrap().unwrap(), "key down 4");
        assert_eq!(lines.next().unwrap().unwrap(), "touch down 0.50000 0.25000");

        let (send, _recv) = mpsc::sync_channel(8);
        assert!(audio::join_target(&guest, send.clone(), audio::Codec::Pcm).is_none());
        let tap = dir.join("speaker.sock");
        let listener = UnixListener::bind(&tap).unwrap();
        guest.audio_tap = Some(tap);
        let (sound, sub) = audio::join_target(&guest, send, audio::Codec::Pcm).unwrap();
        let until = Instant::now() + timeout;
        while !sound.connected.load(Ordering::Acquire) {
            assert!(Instant::now() < until, "the mixer did not connect to the supplied tap");
            std::thread::sleep(Duration::from_millis(5));
        }
        let mut peer = listener.accept().unwrap().0;
        peer.set_read_timeout(Some(timeout)).unwrap();
        sound.mic(sub, &16384i16.to_le_bytes());
        assert_eq!(
            simaudio::read_msg(&mut peer).unwrap(),
            (simaudio::OP_MIC, 0, 0.5f32.to_le_bytes().to_vec())
        );
        sound.leave(sub);
        std::fs::remove_dir_all(dir).unwrap();
    }
}
