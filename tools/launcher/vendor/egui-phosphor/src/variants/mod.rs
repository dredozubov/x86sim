// Every variant uses the same codepoints, so they share one table and each
// variant module re-exports it. `update.py` verifies this still holds.
// (x86Sim copy: only the regular variant; see ../../Cargo.toml.)
mod codepoints;

pub mod regular;

pub mod bytes {
    pub mod regular {
        pub const FONT: &[u8] = include_bytes!("../../res/Phosphor.ttf");
    }
}

#[derive(Debug, Clone, Copy)]
pub enum Variant {
    Regular,
}

impl Variant {
    pub fn font_bytes(&self) -> &'static [u8] {
        match self {
            Variant::Regular => bytes::regular::FONT,
        }
    }

    pub fn font_data(&self) -> egui::FontData {
        egui::FontData::from_static(self.font_bytes())
    }
}
