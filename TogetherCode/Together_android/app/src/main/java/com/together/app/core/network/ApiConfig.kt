package com.together.app.core.network

object ApiConfig {
    const val API_PREFIX = "/v1"
    const val API_ENCRYPT_ENABLED = false

    val uploadFolders = listOf("common", "avatar", "course", "post", "work", "studio", "cert")

    var customBaseUrl: String? = null

    val hostBaseUrl: String
        get() = customBaseUrl ?: "http://127.0.0.1:3001"

    val baseUrl: String
        get() = hostBaseUrl + API_PREFIX + "/"

    val imageBaseUrl: String
        get() = hostBaseUrl
}
