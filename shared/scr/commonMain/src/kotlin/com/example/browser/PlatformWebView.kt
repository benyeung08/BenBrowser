package com.example.browser

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/**
 * 平台 WebView 抽象接口。
 * Android 用系统 WebView，桌面用 KCEF/Chromium。
 */
expect abstract class PlatformWebView {
    fun loadUrl(url: String)
    fun goBack()
    fun goForward()
    fun reload()
    @Composable fun ComposeContent()
}

@Composable
expect fun rememberPlatformWebView(
    viewModel: BrowserViewModel,
    modifier: Modifier = Modifier,
): PlatformWebView
