package com.example.browser

import kotlinx.serialization.Serializable

@Serializable
data class Bookmark(
    val title: String,
    val url: String,
    val createdAt: Long = kotlinx.datetime.Clock.System.now().toEpochMilliseconds()
)
