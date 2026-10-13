package com.together.app.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// MARK: - 会话对方用户

@Serializable
data class ConversationPeer(
    @SerialName("user_id") val userId: String = "",
    @SerialName("nickname") val nickname: String = "",
    @SerialName("avatar") val avatar: String? = null,
    @SerialName("role") val role: Int? = null
)

// MARK: - 会话关联孩子

@Serializable
data class ConversationChild(
    @SerialName("child_id") val childId: String = "",
    @SerialName("nickname") val nickname: String = ""
)

// MARK: - 会话最后一条消息

@Serializable
data class LastMessage(
    @SerialName("message_id") val messageId: String = "",
    @SerialName("sender_id") val senderId: String = "",
    @SerialName("type") val type: Int = 1, // 1=文本 2=图片
    @SerialName("content") val content: String = "",
    @SerialName("created_at") val createdAt: String = ""
) {
    val previewText: String get() = if (type == 2) "[图片]" else content
}

// MARK: - 消息发送者

@Serializable
data class ChatMessageSender(
    @SerialName("user_id") val userId: String = "",
    @SerialName("nickname") val nickname: String = "",
    @SerialName("avatar") val avatar: String? = null,
    @SerialName("role") val role: Int? = null
)

// MARK: - 单条消息

@Serializable
data class ChatMessage(
    @SerialName("message_id") val messageId: String = "",
    @SerialName("conversation_id") val conversationId: String? = null,
    @SerialName("sender_id") val senderId: String? = null,
    @SerialName("type") val type: Int = 1, // 1=文本 2=图片
    @SerialName("content") val content: String = "",
    @SerialName("read_at") val readAt: String? = null,
    @SerialName("created_at") val createdAt: String = "",
    @SerialName("sender") val sender: ChatMessageSender? = null
) {
    val senderUserId: String? get() = senderId ?: sender?.userId
    val isImage: Boolean get() = type == 2
    val timeText: String get() = createdAt.shortRelativeTime()
}

// MARK: - 会话条目

@Serializable
data class ConversationItem(
    @SerialName("conversation_id") val conversationId: String = "",
    @SerialName("peer") val peer: ConversationPeer? = null,
    @SerialName("child") val child: ConversationChild? = null,
    @SerialName("last_message") val lastMessage: LastMessage? = null,
    @SerialName("unread_count") val unreadCount: Int = 0,
    @SerialName("updated_at") val updatedAt: String = ""
) {
    val peerName: String get() = peer?.nickname ?: "未知用户"
    val peerAvatar: String? get() = peer?.avatar
    val lastMessagePreview: String get() = lastMessage?.previewText ?: ""
    val timeText: String get() = updatedAt.shortRelativeTime()
}

// MARK: - 通知条目

@Serializable
data class NotificationItem(
    @SerialName("notification_id") val notificationId: String = "",
    @SerialName("type") val type: String = "",
    @SerialName("title") val title: String = "",
    @SerialName("content") val content: String = "",
    @SerialName("ref_type") val refType: String? = null,
    @SerialName("ref_id") val refId: String? = null,
    @SerialName("is_read") val isRead: Boolean = false,
    @SerialName("created_at") val createdAt: String = ""
) {
    val timeText: String get() = createdAt.shortRelativeTime()
}