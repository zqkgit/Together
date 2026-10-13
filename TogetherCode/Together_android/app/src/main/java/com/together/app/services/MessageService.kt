package com.together.app.services

import com.together.app.core.model.ChatMessage
import com.together.app.core.model.ConversationItem
import com.together.app.core.model.NotificationItem
import com.together.app.core.network.ApiService
import com.together.app.core.network.JsonHelper.decode
import com.together.app.core.network.JsonHelper.decodeList
import com.together.app.core.network.JsonHelper.int
import com.together.app.core.network.JsonHelper.strOrNull

/**
 * 消息相关接口（会话列表 / 通知 / 聊天 / WebSocket）
 * 对齐 iOS MessageService.swift
 */
object MessageService {

    // MARK: - 会话列表

    /** 会话列表（分页）→ (items, total, unreadTotal) */
    suspend fun fetchConversations(page: Int, size: Int = 20): Triple<List<ConversationItem>, Int, Int> {
        val json = ApiService.get("/messages/conversations", mapOf("page" to page, "size" to size))
        val items = json.decodeList<ConversationItem>("list")
        val total = json.int("total")
        val unread = json.int("unread_total")
        return Triple(items, total, unread)
    }

    // MARK: - 通知

    /** 通知列表（分页，可按 type 过滤）→ (items, total, unreadTotal) */
    suspend fun fetchNotifications(page: Int, size: Int = 20, type: String = ""): Triple<List<NotificationItem>, Int, Int> {
        val params = mutableMapOf<String, Any?>("page" to page, "size" to size)
        if (type.isNotEmpty()) params["type"] = type
        val json = ApiService.get("/messages/notifications", params)
        val items = json.decodeList<NotificationItem>("list")
        val total = json.int("total")
        val unread = json.int("unread_total")
        return Triple(items, total, unread)
    }

    /** 单条通知已读 */
    suspend fun markNotificationRead(id: String) {
        ApiService.put("/messages/notifications/$id/read")
    }

    /** 全部通知已读 */
    suspend fun markAllNotificationsRead() {
        ApiService.put("/messages/notifications/read-all")
    }

    // MARK: - 聊天

    /** 会话消息列表（服务端按时间倒序返回，index 0 最新；读取后自动标记已读）→ (items, total) */
    suspend fun fetchMessages(conversationId: String, page: Int, size: Int = 30): Pair<List<ChatMessage>, Int> {
        val json = ApiService.get("/messages/conversations/$conversationId/messages", mapOf("page" to page, "size" to size))
        val items = json.decodeList<ChatMessage>("list")
        val total = json.int("total")
        return items to total
    }

    /** 发送消息（type 1=文本 2=图片）→ 返回新消息 */
    suspend fun sendMessage(conversationId: String, content: String, type: Int = 1): ChatMessage? {
        val json = ApiService.post("/messages/conversations/$conversationId/messages", mapOf(
            "content" to content, "type" to type
        ))
        return json.decode<ChatMessage>()
    }

    // MARK: - WebSocket

    /** 获取 WebSocket 连接地址（ws ticket 5 分钟有效）→ ws_url */
    suspend fun fetchWsToken(): String? {
        val json = ApiService.get("/messages/ws/token")
        return json.strOrNull("ws_url")
    }

    // MARK: - 发起私聊

    /** 发起私聊（幂等：已有会话直接返回） */
    suspend fun createConversation(peerUserId: String, childId: String? = null): ConversationItem? {
        val params = mutableMapOf<String, Any?>("peer_user_id" to peerUserId)
        childId?.takeIf { it.isNotEmpty() }?.let { params["child_id"] = it }
        return ApiService.post("/messages/conversations", params).decode<ConversationItem>()
    }
}