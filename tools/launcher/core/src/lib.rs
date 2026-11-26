//! x86Sim launcher core: the chunked AOT image (static discovery, incremental builds driven through libarm64jit's
//! builder), per-device feature toggles and sim control. Shared by the `x86sim-aot` CLI, the `x86sim-mcp` server and
//! the egui launcher.
pub mod account;
pub mod aot;
pub mod ax;
pub mod axact;
/// Accessibility Inspector: properties, element at a point, accessibility actions; the audit
pub mod axaudit;
pub mod axinspect;
pub mod appcache;
pub mod apps;
pub mod appstate;
pub mod desktop;
pub mod dev;
pub mod devapp;
pub mod devdelete;
pub mod devpods;
pub mod devdotnet;
pub mod devgen;
pub mod devkmp;
pub mod devrust;
pub mod devweb;
pub mod devxcode;
pub mod discover;
pub mod dyldcache;
pub mod features;
pub mod hid;
pub mod host;
pub mod hot;
pub mod instance;
/// SpringBoard liveness: a phone whose shell stopped answering is "hung"
pub mod liveness;
pub mod key;
pub mod keymap;
pub mod logs;
pub mod pool;
pub mod profile;
pub mod record;
pub mod macho;
/// Screenshots that point at elements: marks (outlines with refs), one element cropped
pub mod marks;
/// Network capture of native apps (host/simnet): records, capture on / off, mocks
pub mod net;
/// Text in pixels: OCR of frames (snapshot ocr=true, views with no elements)
pub mod ocr;
pub mod ring;
/// Web Inspector: Safari and WKWebView pages over webinspectord (RWI)
pub mod rwi;
pub mod rtdelete;
pub mod rundir;
pub mod setup;
/// Share: phones in a browser (x86sim serve)
pub mod share;
pub mod sim;
pub mod update;
