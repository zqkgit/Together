package com.together.app.core.network

object ApiConfig {
    const val API_PREFIX = "/v1"
    const val API_ENCRYPT_ENABLED = false

    // MARK: - 极光推送（对齐 iOS APIConfig.jpushAppKey）
    // 极光控制台获取；留空则 PushManager.isEnabled=false，SDK 静默跳过，App 内消息仍走 WebSocket/轮询
    const val JPUSH_APPKEY = ""
    const val JPUSH_CHANNEL = "developer"

    val uploadFolders = listOf("common", "avatar", "course", "post", "work", "studio", "cert")

    var customBaseUrl: String? = null

    val hostBaseUrl: String
        get() = customBaseUrl ?: "http://127.0.0.1:3001"

    val baseUrl: String
        get() = hostBaseUrl + API_PREFIX + "/"

    val imageBaseUrl: String
        get() = hostBaseUrl
}
