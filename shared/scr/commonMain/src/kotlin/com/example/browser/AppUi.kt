package com.example.browser

import androidx.compose.foundation.layout.*
import androidx.compose.material.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp

/**
 * 跨平台地址栏 + 工具栏。
 * 各平台在背后挂载自己的 WebView 实现。
 */
@Composable
fun BrowserScaffold(
    viewModel: BrowserViewModel,
    webContent: @Composable () -> Unit,
    onNavigate: (String) -> Unit,
    onBack: () -> Unit,
    onForward: () -> Unit,
    onReload: () -> Unit,
    onHome: () -> Unit,
    onToggleDesktop: () -> Unit,
    onAddBookmark: () -> Unit,
    onShowBookmarks: () -> Unit,
) {
    val state by viewModel.uiState.collectAsState()
    var text by remember(state.currentUrl) { mutableStateOf(TextFieldValue(state.currentUrl)) }
    var editing by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            Column {
                TopAppBar(
                    title = {
                        TextField(
                            value = text,
                            onValueChange = { text = it; editing = true },
                            singleLine = true,
                            placeholder = { Text("输入网址…") },
                            modifier = Modifier.fillMaxWidth(),
                            colors = TextFieldDefaults.textFieldColors(
                                backgroundColor = MaterialTheme.colors.surface.copy(alpha = 0.12f)
                            )
                        )
                    },
                    actions = {
                        IconButton(onClick = {
                            val input = text.text.trim()
                            val url = if (input.startsWith("http")) input
                            else "https://$input"
                            editing = false
                            onNavigate(url)
                        }) { Text("前往") }
                    }
                )
                TopAppBar(
                    title = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            IconButton(onClick = onBack, enabled = state.canGoBack) {
                                Text("←")
                            }
                            IconButton(onClick = onForward, enabled = state.canGoForward) {
                                Text("→")
                            }
                            IconButton(onClick = onReload) { Text("↻") }
                            IconButton(onClick = onHome) { Text("⌂") }
                            IconButton(onClick = onToggleDesktop) {
                                Text(if (state.desktopMode) "🖥" else "📱")
                            }
                            IconButton(onClick = onAddBookmark) { Text("★") }
                            IconButton(onClick = onShowBookmarks) { Text("☰") }
                        }
                    }
                )
                if (state.isLoading) {
                    LinearProgressIndicator(
                        progress = state.progress,
                        modifier = Modifier.fillMaxWidth().height(2.dp)
                    )
                }
            }
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize()) {
            webContent()
        }
    }
}
