package com.example.browser

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material.MaterialTheme

class MainActivity : ComponentActivity() {

    private val viewModel = BrowserViewModel()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 若由外部链接唤起，加载该 URL
        intent?.data?.toString()?.let { viewModel.updateUrl(it) }

        setContent {
            MaterialTheme {
                val webView = rememberPlatformWebView(viewModel)
                BrowserScreen(viewModel = viewModel, webView = webView)
            }
        }
    }

    override fun onBackPressed() {
        // 由 Compose 层处理返回
        super.onBackPressed()
    }
}
