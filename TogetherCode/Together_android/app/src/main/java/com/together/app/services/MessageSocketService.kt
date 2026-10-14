package com.together.app.services

import com.together.app.core.model.ChatMessage
import com.together.app.core.network.JsonHelper.decode
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import java.util.concurrent.TimeUnit

/**
 * 消息 WebSocket 服务（全局单例）
 * 对齐 iOS MessageSocketService.swift
 *
 * - 登录后 connect()，登出 / 401 时 disconnect()
 * - OkHttp pingInterval 30s 自动心跳（对齐服务端 30s ping）
 * - 断线指数退避重连（1s → 2s → 4s … 封顶 30s），token 失效自动重新拉取
 * - 收到 event("message") → 解码 ChatMessage → messageFlow 分发
 */
object MessageSocketService {

    /** 收到新聊天消息事件 */
    data class ChatMessageEvent(val conversationId: String, val message: ChatMessage)

    private val _messageFlow = MutableSharedFlow<ChatMessageEvent>(replay = 0, extraBufferCapacity = 16)
    val messageFlow: SharedFlow<ChatMessageEvent> = _messageFlow.asSharedFlow()

    private val _connectionFlow = MutableSharedFlow<Boolean>(replay = 0, extraBufferCapacity = 1)
    val connectionFlow: SharedFlow<Boolean> = _connectionFlow.asSharedFlow()

    /** 登录态提供者，由 Application 层注入（重连前判断是否仍需连接） */
    var loginStateProvider: () -> Boolean = { false }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val client: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(20, TimeUnit.SECONDS)
            .readTimeout(0, TimeUnit.MILLISECONDS)  // WebSocket 长连接不超时
            .pingInterval(30, TimeUnit.SECONDS)      // 自动 ping/pong 心跳
            .build()
    }

    @Volatile private var webSocket: WebSocket? = null
    @Volatile private var shouldReconnect = false
    @Volatile private var isConnecting = false
    @Volatile private var reconnectDelay = 1L

    /** 当前是否已连接 */
    val isConnected: Boolean get() = webSocket != null

    /** 登录后调用：建立 WebSocket 连接（幂等） */
    fun connect() {
        if (!loginStateProvider()) return
        if (isConnecting) return
        if (webSocket != null) return
        shouldReconnect = true
        reconnectDelay = 1
        establish()
    }

    /** 登出 / 退出登录时调用：断开连接 */
    fun disconnect() {
        shouldReconnect = false
        webSocket?.close(1000, "logout")
        webSocket = null
    }

    // MARK: - 连接

    private fun establish() {
        if (!shouldReconnect || !loginStateProvider() || isConnecting) return
        isConnecting = true
        scope.launch {
            try {
                val wsUrl = MessageService.fetchWsToken()
                isConnecting = false
                if (!shouldReconnect || wsUrl.isNullOrEmpty()) return@launch

                val request = Request.Builder().url(wsUrl).build()
                webSocket = client.newWebSocket(request, socketListener)
            } catch (_: Exception) {
                isConnecting = false
                scheduleReconnect()
            }
        }
    }

    private val socketListener = object : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: Response) {
            reconnectDelay = 1
            _connectionFlow.tryEmit(true)
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            handle(text)
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            onDisconnected(this)
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            onDisconnected(this)
        }
    }

    /** 连接断开（正常关闭 / 异常），清理引用并走重连 */
    private fun onDisconnected(listener: WebSocketListener) {
        _connectionFlow.tryEmit(false)
        // 仅当当前持有的 socket 断开时才清理（避免旧连接关闭影响新连接）
        val current = webSocket
        if (current != null) {
            synchronized(this) {
                if (webSocket === current) webSocket = null
            }
        }
        scheduleReconnect()
    }

    // MARK: - 消息处理

    private fun handle(text: String) {
        try {
            val json = Json.parseToJsonElement(text).jsonObject
            val event = json["event"]?.jsonPrimitive?.content ?: return
            when (event) {
                "connected" -> _connectionFlow.tryEmit(true)
                "message" -> {
                    val data = json["data"]?.jsonObject ?: return
                    val conversationId = data["conversation_id"]?.jsonPrimitive?.content ?: return
                    val message = data.decode<ChatMessage>() ?: return
                    _messageFlow.tryEmit(ChatMessageEvent(conversationId, message))
                }
            }
        } catch (_: Exception) { }
    }

    // MARK: - 重连（指数退避 1s → 30s 封顶）

    private fun scheduleReconnect() {
        if (!shouldReconnect || !loginStateProvider() || isConnecting) return
        val delayMs = reconnectDelay
        reconnectDelay = (reconnectDelay * 2).coerceAtMost(30)
        scope.launch {
            delay(delayMs * 1000)
            if (shouldReconnect && loginStateProvider()) {
                establish()
            }
        }
    }
}