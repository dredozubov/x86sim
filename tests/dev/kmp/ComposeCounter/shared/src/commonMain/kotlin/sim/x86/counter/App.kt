package sim.x86.counter

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier

@Composable
fun App() {
    var count by remember { mutableStateOf(0) }
    MaterialTheme {
        Surface(Modifier.fillMaxSize()) {
            Column(
                Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("Compose Multiplatform on x86Sim", style = MaterialTheme.typography.titleMedium)
                Text("Count: $count", style = MaterialTheme.typography.headlineMedium)
                Button(onClick = { count++ }) { Text("Add one") }
            }
        }
    }
}
