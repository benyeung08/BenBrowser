package com.example.browser

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.awt.SwingPanel
import dev.datlag.kcef.KCEFBrowser
import dev.datlag.kcef.KCEF
import java.awt.BorderLayout
import javax.swing.JPanel

/**
 * 桌面端 WebView 实现 —— 基于 KCEF (Chromium Embedded Framework)。
 *
 * 注意：首次启动会从网络下载 Chromium 运行时（约数百 MB），
 * 需要给 Compose Desktop 配置 JVM flags 并初始化 KCEF。
 */
@Composable
actual fun rememberPlatformWebView(
    viewModel: BrowserViewModel,
    modifier: Modifier,
): PlatformWebView {
    val webView = remember { DesktopWebView(viewModel) }
    DisposableEffect(Unit) {
        onDispose { webView.dispose() }
    }
    return webView
}

class DesktopWebView(
    private val viewModel: BrowserViewModel,
) : PlatformWebView {

    private var browser: KCEFBrowser? = null
    private var panel: JPanel? = null

    override fun loadUrl(url: String) {
        browser?.loadURL(url)
    }

    override fun goBack() = browser?.goBack() ?: Unit
    override fun goForward() = browser?.goForward() ?: Unit
    override fun reload() = browser?.reload() ?: Unit

    override fun ComposeContent() {
        val b = remember { createBrowser() }
        browser = b
        SwingPanel(
            factory = { createPanel(b) },
            modifier = Modifier.fillMaxSize(),
            update = { /* 面板已创建 */ }
        )
    }

    private fun createBrowser(): KCEFBrowser {
        val client = KCEF.newClientBlocking()
        return client.createBrowser(
            viewModel.uiState.value.currentUrl,
            /* transparent = */ false,
            /* inspect = */ false
        ).apply {
            // 进度与加载状态回调
            onLoadingStateChange = { isLoading, canGoBack, canGoForward ->
                viewModel.updateLoading(isLoading)
                viewModel.updateNavigation(canGoBack, canGoForward)
            }
            onAddressChange = { address ->
                if (address != null) viewModel.updateUrl(address)
            }
            onTitleChange = { title ->
                if (title != null) viewModel.updateTitle(title)
            }
        }
    }

    private fun createPanel(b: KCEFBrowser): JPanel =
        object : JPanel(BorderLayout()) {
            override fun addNotify() {
                super.addNotify()
                b.uiComponent?.let { add(it, BorderLayout.CENTER) }
            }
        }.also { panel = it }

    fun dispose() {
        try { browser?.close() } catch (_: Exception) { }
        panel = null
        browser = null
    }
}

/**
 * KCEF 全局初始化帮助类。
 * 必须在 Application 启动时调用 KCEF.init(...)，关闭时调用 KCEF.disposeBlocking()。
 */
object KcefInitializer {
    var isInitialized: Boolean = false
        private set

    fun init(
        onProgress: (Float) -> Unit,
        onError: (Throwable) -> Unit,
    ) {
        KCEF.init(
            builder = {
                installDir = java.io.File("kcef-bundle")
                progress {
                    onProgress(it / 100f)
                }
                settings {
                    cachePath = java.io.File("cache").absolutePath
                }
            },
            onSuccess = { isInitialized = true },
            onError = { t -> onError(t) }
        )
    }

    fun dispose() = KCEF.disposeBlocking()
}
