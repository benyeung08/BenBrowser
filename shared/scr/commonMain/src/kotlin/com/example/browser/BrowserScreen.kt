package com.example.browser

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue

/**
 * 顶层浏览器画面：共享 UI + 平台 WebView 内容。
 */
@Composable
fun BrowserScreen(
    viewModel: BrowserViewModel,
    webView: PlatformWebView,
) {
    var showBookmarks by remember { mutableStateOf(false) }
    val bookmarks by viewModel.bookmarks.collectAsState()

    BrowserScaffold(
        viewModel = viewModel,
        webContent = { webView.ComposeContent() },
        onNavigate = { url ->
            viewModel.updateUrl(url)
            webView.loadUrl(url)
        },
        onBack = { webView.goBack() },
        onForward = { webView.goForward() },
        onReload = { webView.reload() },
        onHome = {
            val home = "https://www.google.com"
            viewModel.updateUrl(home)
            webView.loadUrl(home)
        },
        onToggleDesktop = {
            viewModel.uiState.value.desktopMode.let { current ->
                val next = !current
                viewModel.setDesktopMode(next)
                // 桌面端可通过 UA 切换实现，这里统一 reload 以生效设置
                webView.reload()
            }
        },
        onAddBookmark = {
            val s = viewModel.uiState.value
            if (s.currentUrl.isNotBlank()) {
                viewModel.addBookmark(Bookmark(title = s.pageTitle.ifBlank { s.currentUrl }, url = s.currentUrl))
            }
        },
        onShowBookmarks = { showBookmarks = true }
    )

    if (showBookmarks) {
        BookmarkDialog(
            bookmarks = bookmarks,
            onDismiss = { showBookmarks = false },
            onOpen = { bm ->
                viewModel.updateUrl(bm.url)
                webView.loadUrl(bm.url)
                showBookmarks = false
            },
            onDelete = { viewModel.removeBookmark(it) }
        )
    }
}

@Composable
private fun BookmarkDialog(
    bookmarks: List<Bookmark>,
    onDismiss: () -> Unit,
    onOpen: (Bookmark) -> Unit,
    onDelete: (String) -> Unit,
) {
    androidx.compose.ui.window.Dialog(onDismissRequest = onDismiss) {
        androidx.compose.material.Surface(shape = androidx.compose.material.MaterialTheme.shapes.medium) {
            androidx.compose.foundation.lazy.LazyColumn(modifier = androidx.compose.ui.Modifier.padding(16.dp)) {
                item { androidx.compose.material.Text("书签", style = androidx.compose.material.MaterialTheme.typography.h6) }
                items(bookmarks.size) { i ->
                    val bm = bookmarks[i]
                    androidx.compose.foundation.clickable { onOpen(bm) }
                        .padding(8.dp)
                    androidx.compose.material.Text(bm.title.ifBlank { bm.url })
                    androidx.compose.material.Text(bm.url, style = androidx.compose.material.MaterialTheme.typography.caption)
                }
            }
        }
    }
}
