package sim.x86.counter

import androidx.compose.ui.window.ComposeUIViewController
import platform.UIKit.UIViewController

/** The Compose UI as a UIViewController, for the SwiftUI app (iosApp/) */
fun MainViewController(): UIViewController = ComposeUIViewController { App() }
