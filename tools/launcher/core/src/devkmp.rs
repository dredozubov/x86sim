//! x86sim dev: Kotlin Multiplatform / Compose Multiplatform apps. The iOS app of a KMP project is an xtool project whose
//! xtool.env names the Gradle build of its shared module (KMP_GRADLE_ROOT, KMP_MODULE, KMP_FRAMEWORK). Such a project is
//! built by omarchy-apple-dev's kmp/build-app.sh instead of ship.sh: Gradle builds the klibs, Kotlin/Native links the
//! framework for the simulator with the Darwin SDK and ld64.lld (kmp/build-framework.sh), ship.sh builds the app around
//! it and the Compose resources are copied in. Its output ends with ship.sh's "simulator app ready: <app>" line.

use std::path::{Path, PathBuf};

/// The value of KEY in an xtool.env (shell assignments: KEY=value, optionally quoted, # comments)
fn env_value(text: &str, key: &str) -> Option<String> {
    text.lines().filter_map(|l| l.trim().strip_prefix("export ").unwrap_or(l.trim()).strip_prefix(&format!("{key}="))).last()
        .map(|v| v.split(" #").next().unwrap_or(v).trim().trim_matches('"').trim_matches('\'').to_string()).filter(|v| !v.is_empty())
}

/// The Gradle root of a KMP app project (its xtool.env's KMP_GRADLE_ROOT, relative to the project), if it is one
pub fn gradle_root(dir: &Path) -> Option<PathBuf> {
    let text = std::fs::read_to_string(dir.join("xtool.env")).ok()?;
    env_value(&text, "KMP_GRADLE_ROOT").map(|r| dir.join(r))
}

/// The script that builds PROJECT for the simulator: kmp/build-app.sh for a KMP app, else ship.sh
pub fn sim_build_script(dir: &Path) -> PathBuf {
    let fork = crate::dev::fork_dir();
    match gradle_root(dir) {
        Some(_) => fork.join("kmp/build-app.sh"),
        None => fork.join("ship.sh"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_the_gradle_root() {
        let t = "# the shared module\nKMP_GRADLE_ROOT=.. # its Gradle build\nKMP_MODULE=:shared\n";
        assert_eq!(env_value(t, "KMP_GRADLE_ROOT").as_deref(), Some(".."));
        assert_eq!(env_value("export KMP_GRADLE_ROOT=\"../kmp\"\n", "KMP_GRADLE_ROOT").as_deref(), Some("../kmp"));
        assert_eq!(env_value("APP_ICON=AppIcon\n", "KMP_GRADLE_ROOT"), None);
        assert_eq!(env_value("KMP_GRADLE_ROOT=\n", "KMP_GRADLE_ROOT"), None);
    }
}
