package com.example.browser

import android.webkit.CookieManager
import android.webkit.WebView
import android.webkit.WebViewClient
import android.webkit.WebChromeClient
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView

/**
 * Android 端 WebView 实现 —— 基于系统 Chromium WebView。
 * 支持 Google 账号登录所需的第三方 Cookie 与 DOM storage。
 */
actual class AndroidWebView(
    private val viewModel: BrowserViewModel,
) : PlatformWebView {

    private var webView: WebView? = null

    override fun loadUrl(url: String) { webView?.loadUrl(url) }
    override fun goBack() { if (webView?.canGoBack() == true) webView?.goBack() }
    override fun goForward() { if (webView?.canGoForward() == true) webView?.goForward() }
    override fun reload() { webView?.reload() }

    @Composable
    override fun ComposeContent() {
        AndroidView(
            modifier = Modifier.fillMaxSize(),
            factory = { ctx ->
                WebView(ctx).apply {
                    webView = this
                    configureForBrowser(viewModel)
                }
            },
            update = { /* 状态由 ViewModel 驱动 */ }
        )
    }

    private fun WebView.configureForBrowser(vm: BrowserViewModel) {
        settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            loadWithOverviewMode = true
            useWideViewPort = true
            mediaPlaybackRequiresUserGesture = false
            javaScriptCanOpenWindowsAutomatically = true
            setSupportMultipleWindows(true)
            mixedContentMode = android.webkit.WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
            userAgentString = chromeUserAgent(this.userAgentString)
        }

        // Google 账号登录：允许 accounts.google.com 的第三方 Cookie
        CookieManager.getInstance().apply {
            setAcceptCookie(true)
            setAcceptThirdPartyCookies(this@configureForBrowser, true)
        }

        webViewClient = object : WebViewClient() {
            override fun onPageStarted(view: WebView?, url: String?, favicon: android.graphics.Bitmap?) {
                super.onPageStarted(view, url, favicon)
                vm.updateLoading(true)
                url?.let(vm::updateUrl)
            }
            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                vm.updateLoading(false)
                vm.updateNavigation(view?.canGoBack() == true, view?.canGoForward() == true)
                vm.updateTitle(view?.title.orEmpty())
            }
        }

        webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                super.onProgressChanged(view, newProgress)
                vm.updateLoading(newProgress < 100, newProgress / 100f)
            }
        }

        loadUrl(vm.uiState.value.currentUrl)
    }

    private fun chromeUserAgent(original: String): String =
        "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36"

    fun dispose() { webView = null }
}

actual fun PlatformWebView.androidWebViewFactory(viewModel: BrowserViewModel): PlatformWebView =
    AndroidWebView(viewModel)
