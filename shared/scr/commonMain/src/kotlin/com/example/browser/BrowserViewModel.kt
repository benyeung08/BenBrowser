package com.example.browser

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.serialization.json.Json

/**
 * 跨平台浏览器状态容器。
 * 只持有状态，不直接依赖任何平台 WebView 实现，
 * 由各平台的实际 WebView 层驱动更新。
 */
class BrowserViewModel {

    private val _uiState = MutableStateFlow(BrowserUiState())
    val uiState: StateFlow<BrowserUiState> = _uiState.asStateFlow()

    private val _bookmarks = MutableStateFlow<List<Bookmark>>(emptyList())
    val bookmarks: StateFlow<List<Bookmark>> = _bookmarks.asStateFlow()

    fun updateUrl(url: String) {
        _uiState.update { it.copy(currentUrl = url) }
    }

    fun updateTitle(title: String) {
        _uiState.update { it.copy(pageTitle = title) }
    }

    fun updateLoading(isLoading: Boolean, progress: Float = 0f) {
        _uiState.update { it.copy(isLoading = isLoading, progress = progress) }
    }

    fun updateNavigation(canGoBack: Boolean, canGoForward: Boolean) {
        _uiState.update { it.copy(canGoBack = canGoBack, canGoForward = canGoForward) }
    }

    fun addBookmark(bookmark: Bookmark) {
        if (_bookmarks.value.any { it.url == bookmark.url }) return
        _bookmarks.update { it + bookmark }
    }

    fun removeBookmark(url: String) {
        _bookmarks.update { list -> list.filterNot { it.url == url } }
    }

    fun hasBookmark(url: String): Boolean =
        _bookmarks.value.any { it.url == url }

    fun setDesktopMode(enabled: Boolean) {
        _uiState.update { it.copy(desktopMode = enabled) }
    }

    companion object {
        private val json = Json { prettyPrint = true; ignoreUnknownKeys = true }
        fun bookmarksToJson(list: List<Bookmark>): String = json.encodeToString(list)
        fun bookmarksFromJson(text: String): List<Bookmark> =
            runCatching { json.decodeFromString<List<Bookmark>>(text) }.getOrDefault(emptyList())
    }
}

data class BrowserUiState(
    val currentUrl: String = "https://www.google.com",
    val pageTitle: String = "",
    val isLoading: Boolean = false,
    val progress: Float = 0f,
    val canGoBack: Boolean = false,
    val canGoForward: Boolean = false,
    val desktopMode: Boolean = false,
)
