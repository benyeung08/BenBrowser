package com.example.browser

import androidx.compose.desktop.ui.Toolkit
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material.MaterialTheme
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import java.awt.Dimension

/**
 * 桌面端入口。
 *
 * 启动流程：
 *   1) 初始化 KCEF（首次运行会下载 Chromium 运行时，需联网）
 *   2) 下载完成后创建窗口并显示 BrowserScreen
 *   3) 关闭时释放 KCEF 全局资源
 */
fun main() = application {
    // 用于展示"下载运行时"进度的状态
    var initProgress by remember { mutableStateOf(0f) }
    var initError by remember { mutableStateOf<Throwable?>(null) }

    LaunchedEffect(Unit) {
        KcefInitializer.init(
            onProgress = { initProgress = it },
            onError = { initError = it }
        )
    }

    DisposableEffect(Unit) {
        onDispose { KcefInitializer.dispose() }
    }

    Window(
        onCloseRequest = ::exitApplication,
        title = "BrowserApp",
        state = rememberWindowState(width = 1024.dp, height = 720.dp)
    ) {
        // 设置最小窗口尺寸
        window.minimumSize = Dimension(480, 320)

        MaterialTheme {
            if (initError != null) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    androidx.compose.material.Text("初始化 Chromium 失败：${initError?.message}")
                }
            } else if (!KcefInitializer.isInitialized) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    androidx.compose.material.Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        androidx.compose.material.Text("正在下载 Chromium 运行时…")
                        androidx.compose.material.LinearProgressIndicator(progress = initProgress)
                        androidx.compose.material.Text("${(initProgress * 100).toInt()}%")
                    }
                }
            } else {
                val viewModel = remember { BrowserViewModel() }
                val webView = rememberPlatformWebView(viewModel)
                BrowserScreen(viewModel = viewModel, webView = webView)
            }
        }
    }
}
