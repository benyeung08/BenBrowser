package com.example.browser

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/**
 * Android 平台：基于系统 Chromium WebView。
 */
actual abstract class PlatformWebView {
    actual abstract fun loadUrl(url: String)
    actual abstract fun goBack()
    actual abstract fun goForward()
    actual abstract fun reload()
    @Composable actual abstract fun ComposeContent()
}

@Composable
actual fun rememberPlatformWebView(
    viewModel: BrowserViewModel,
    modifier: Modifier,
): PlatformWebView = AndroidWebView(viewModel)
