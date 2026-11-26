// Compose Multiplatform sample of x86Sim's dev checks (tests/dev/kmp_e2e.py): a shared
// Kotlin module for iOS, linked on Linux by omarchy-apple-dev's kmp/build-framework.sh,
// inside the SwiftUI app in iosApp/ (an xtool project).
pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
        google()
    }
}
dependencyResolutionManagement {
    repositories {
        mavenCentral()
        google()
    }
}
rootProject.name = "ComposeCounter"
include(":shared")
