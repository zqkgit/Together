package com.together.app.modules.message

import android.app.Application
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.together.app.core.model.ChatMessage
import com.together.app.core.model.ConversationItem
import com.together.app.core.model.NotificationItem
import com.together.app.core.network.ApiService
import com.together.app.core.network.JsonHelper.strList
import com.together.app.services.MessageService
import com.together.app.services.MessageSocketService
import com.together.app.services.PostService
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import java.io.File
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * 消息模块 ViewModel（对齐 iOS MessageViewController / ChatViewController / FollowingListViewController）
 * 三组状态：消息中心（对话+通知）/ 聊天 / 关注列表
 */
class MessageViewModel(app: Application) : AndroidViewModel(app) {

    companion object {
        /** 聊天页会话缓存（路由只传 conversationId，复杂对象走伴生缓存） */
        var navConversation: ConversationItem? = null
    }

    // MARK: - 消息中心

    data class MessageState(
        val currentTab: Int = 0,          // 0=对话 1=通知
        val conversations: List<ConversationItem> = emptyList(),
        val notifications: List<NotificationItem> = emptyList(),
        val chatUnread: Int = 0,
        val notifUnread: Int = 0,
        val refreshing: Boolean = false,
        val loading: Boolean = false,
        val error: String? = null
    )

    private val _messageState = MutableStateFlow(MessageState())
    val messageState: StateFlow<MessageState> = _messageState

    private var convPage = 1
    private var convHasMore = true
    private var notifPage = 1
    private var notifHasMore = true

    fun switchTab(tab: Int) {
        if (tab == _messageState.value.currentTab) return
        _messageState.value = _messageState.value.copy(currentTab = tab)
        reloadCurrent()
    }

    /** 进入页面/返回时刷新当前 Tab（列表非空时静默刷新，不显示刷新动画） */
    fun reloadCurrent() {
        val s = _messageState.value
        if (s.currentTab == 0) {
            if (s.conversations.isEmpty()) refreshConversations() else silentRefreshConversations()
        } else {
            if (s.notifications.isEmpty()) refreshNotifications() else silentRefreshNotifications()
        }
    }

    fun refreshConversations() {
        convPage = 1
        convHasMore = true
        _messageState.value = _messageState.value.copy(refreshing = true, error = null)
        loadConversations()
    }

    fun loadMoreConversations() {
        val s = _messageState.value
        if (s.loading || !convHasMore) return
        convPage += 1
        loadConversations()
    }

    private fun loadConversations() {
        val s = _messageState.value
        _messageState.value = s.copy(loading = true)
        viewModelScope.launch {
            try {
                val (items, total, unread) = MessageService.fetchConversations(page = convPage)
                val cur = _messageState.value
                _messageState.value = cur.copy(
                    conversations = if (convPage == 1) items else cur.conversations + items,
                    chatUnread = unread,
                    loading = false,
                    refreshing = false,
                    error = null
                )
                convHasMore = items.size >= 20 && _messageState.value.conversations.size < total
            } catch (e: Exception) {
                _messageState.value = _messageState.value.copy(
                    loading = false, refreshing = false, error = e.message ?: "加载失败"
                )
            }
        }
    }

    /** 静默刷新会话列表（不显示刷新动画，失败保留旧数据） */
    private fun silentRefreshConversations() {
        viewModelScope.launch {
            try {
                val (items, total, unread) = MessageService.fetchConversations(page = 1)
                convPage = 1
                convHasMore = items.size >= 20 && items.size < total
                _messageState.value = _messageState.value.copy(
                    conversations = items,
                    chatUnread = unread,
                    error = null
                )
            } catch (_: Exception) { }
        }
    }

    fun refreshNotifications() {
        notifPage = 1
        notifHasMore = true
        _messageState.value = _messageState.value.copy(refreshing = true, error = null)
        loadNotifications()
    }

    fun loadMoreNotifications() {
        val s = _messageState.value
        if (s.loading || !notifHasMore) return
        notifPage += 1
        loadNotifications()
    }

    private fun loadNotifications() {
        val s = _messageState.value
        _messageState.value = s.copy(loading = true)
        viewModelScope.launch {
            try {
                val (items, total, unread) = MessageService.fetchNotifications(page = notifPage)
                val cur = _messageState.value
                _messageState.value = cur.copy(
                    notifications = if (notifPage == 1) items else cur.notifications + items,
                    notifUnread = unread,
                    loading = false,
                    refreshing = false,
                    error = null
                )
                notifHasMore = items.size >= 20 && _messageState.value.notifications.size < total
            } catch (e: Exception) {
                _messageState.value = _messageState.value.copy(
                    loading = false, refreshing = false, error = e.message ?: "加载失败"
                )
            }
        }
    }

    /** 静默刷新通知列表（不显示刷新动画，失败保留旧数据） */
    private fun silentRefreshNotifications() {
        viewModelScope.launch {
            try {
                val (items, total, unread) = MessageService.fetchNotifications(page = 1)
                notifPage = 1
                notifHasMore = items.size >= 20 && items.size < total
                _messageState.value = _messageState.value.copy(
                    notifications = items,
                    notifUnread = unread,
                    error = null
                )
            } catch (_: Exception) { }
        }
    }

    /** 标记通知已读（本地+远程，然后静默刷新未读数） */
    fun markNotificationRead(item: NotificationItem) {
        if (item.isRead) return
        viewModelScope.launch {
            try {
                MessageService.markNotificationRead(item.notificationId)
                val cur = _messageState.value
                _messageState.value = cur.copy(
                    notifications = cur.notifications.map {
                        if (it.notificationId == item.notificationId) it.copy(isRead = true) else it
                    }
                )
                // 静默刷新未读角标
                val (_, _, unread) = MessageService.fetchNotifications(page = 1)
                _messageState.value = _messageState.value.copy(notifUnread = unread)
            } catch (_: Exception) { }
        }
    }

    /** 全部通知已读 */
    fun markAllNotificationsRead() {
        viewModelScope.launch {
            try {
                MessageService.markAllNotificationsRead()
                val cur = _messageState.value
                _messageState.value = cur.copy(
                    notifications = cur.notifications.map { it.copy(isRead = true) },
                    notifUnread = 0
                )
            } catch (_: Exception) { }
        }
    }

    // MARK: - 聊天

    /** 聊天展示项：时间行 / 消息行 */
    sealed class ChatDisplay {
        data class Time(val text: String) : ChatDisplay()
        data class Msg(val message: ChatMessage, val isMine: Boolean) : ChatDisplay()
    }

    data class ChatState(
        val conversation: ConversationItem? = null,
        val displayItems: List<ChatDisplay> = emptyList(),
        val loading: Boolean = true,
        val sending: Boolean = false,
        val uploading: Boolean = false,
        val error: String? = null,
        val myUserId: String = ""
    )

    private val _chatState = MutableStateFlow(ChatState())
    val chatState: StateFlow<ChatState> = _chatState

    private var serverMessages: List<ChatMessage> = emptyList()  // 服务端倒序（index 0 最新）
    private var chatPage = 1
    private var chatHasMore = true
    private var chatLoading = false
    private var realtimeJob: Job? = null

    fun initChat(conversation: ConversationItem, myUserId: String) {
        serverMessages = emptyList()
        chatPage = 1
        chatHasMore = true
        chatLoading = false
        _chatState.value = ChatState(
            conversation = conversation,
            myUserId = myUserId,
            loading = true
        )
        loadMessages(reset = true)
        observeRealtimeMessages()
    }

    // MARK: - 实时消息（WebSocket）

    /** 监听 WebSocket 实时消息，收到当前会话消息时追加显示（去重） */
    private fun observeRealtimeMessages() {
        realtimeJob?.cancel()
        realtimeJob = viewModelScope.launch {
            MessageSocketService.messageFlow.collect { event ->
                val conversation = _chatState.value.conversation ?: return@collect
                if (event.conversationId == conversation.conversationId) {
                    if (serverMessages.none { it.messageId == event.message.messageId }) {
                        serverMessages = listOf(event.message) + serverMessages
                        rebuildDisplay()
                    }
                }
            }
        }
    }

    /** 消息中心：监听任意会话来消息 → 静默刷新会话列表（幂等，重复调用无副作用） */
    private var convRealtimeJob: Job? = null
    fun observeConversationUpdates() {
        if (convRealtimeJob != null) return
        convRealtimeJob = viewModelScope.launch {
            MessageSocketService.messageFlow.collect {
                silentRefreshConversations()
            }
        }
    }

    /** 判断消息是否自己发送 */
    private fun isMyMessage(message: ChatMessage, myUserId: String, peerId: String?): Boolean {
        if (myUserId.isNotEmpty()) return message.senderUserId == myUserId
        if (!peerId.isNullOrEmpty()) return message.senderUserId != peerId
        return false
    }

    fun loadMessages(reset: Boolean) {
        if (chatLoading) return
        val conversation = _chatState.value.conversation ?: return
        if (reset) {
            chatPage = 1
            chatHasMore = true
            serverMessages = emptyList()
            _chatState.value = _chatState.value.copy(loading = true, displayItems = emptyList())
        }
        if (!chatHasMore) return
        chatLoading = true
        viewModelScope.launch {
            try {
                val (items, total) = MessageService.fetchMessages(
                    conversation.conversationId, page = chatPage
                )
                chatLoading = false
                if (items.isEmpty()) {
                    chatHasMore = false
                } else {
                    // 服务端倒序（最新在前），追加到已有列表末尾（更早的消息）
                    serverMessages = serverMessages + items
                    chatPage += 1
                    chatHasMore = serverMessages.size < total
                }
                rebuildDisplay()
                _chatState.value = _chatState.value.copy(loading = false, error = null)
            } catch (e: Exception) {
                chatLoading = false
                _chatState.value = _chatState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    /** 由 serverMessages 构建展示数组（旧→新，相邻间隔>5min 或跨天插时间行） */
    private fun rebuildDisplay() {
        val myUserId = _chatState.value.myUserId
        val peerId = _chatState.value.conversation?.peer?.userId
        val messages = serverMessages.reversed()  // 旧→新
        val items = mutableListOf<ChatDisplay>()
        var lastTime: LocalDateTime? = null
        for (msg in messages) {
            val time = parseDateTime(msg.createdAt)
            if (time != null) {
                val needTimeSeparator = lastTime == null ||
                        java.time.Duration.between(lastTime, time).seconds > 300 ||
                        !time.toLocalDate().isEqual(lastTime.toLocalDate())
                if (needTimeSeparator) {
                    items.add(ChatDisplay.Time(formatChatTime(time)))
                }
                lastTime = time
            }
            items.add(ChatDisplay.Msg(msg, isMyMessage(msg, myUserId, peerId)))
        }
        _chatState.value = _chatState.value.copy(displayItems = items)
    }

    /** 发送文本消息（乐观插入） */
    fun sendText(content: String) {
        val trimmed = content.trim()
        if (trimmed.isEmpty()) return
        send(trimmed, type = 1)
    }

    /** 发送图片消息（上传后发送 URL） */
    fun sendImage(uri: Uri) {
        if (_chatState.value.conversation == null) return
        _chatState.value = _chatState.value.copy(uploading = true)
        viewModelScope.launch {
            try {
                val file = uriToFile(uri)
                val json = ApiService.upload(listOf(file), "chat")
                val urls = json.strList("urls")
                val url = urls.firstOrNull()
                _chatState.value = _chatState.value.copy(uploading = false)
                if (url != null) {
                    send(url, type = 2)
                }
            } catch (e: Exception) {
                _chatState.value = _chatState.value.copy(uploading = false, error = "图片发送失败")
            }
        }
    }

    /** 发送消息（乐观插入 → 服务端回包替换临时消息） */
    private fun send(content: String, type: Int) {
        val conversation = _chatState.value.conversation ?: return
        if (_chatState.value.sending) return
        _chatState.value = _chatState.value.copy(sending = true)

        // 乐观插入临时消息
        val tempId = "local-${System.currentTimeMillis()}"
        val optimistic = ChatMessage(
            messageId = tempId,
            conversationId = conversation.conversationId,
            senderId = _chatState.value.myUserId,
            type = type,
            content = content,
            createdAt = nowString()
        )
        serverMessages = listOf(optimistic) + serverMessages
        rebuildDisplay()

        viewModelScope.launch {
            try {
                val message = MessageService.sendMessage(conversation.conversationId, content, type)
                _chatState.value = _chatState.value.copy(sending = false)
                if (message != null) {
                    // 用真实消息替换临时消息（去重）
                    serverMessages = serverMessages.filterNot { it.messageId == tempId }
                    if (serverMessages.none { it.messageId == message.messageId }) {
                        serverMessages = listOf(message) + serverMessages
                    }
                    rebuildDisplay()
                }
            } catch (e: Exception) {
                // 发送失败：移除临时消息
                _chatState.value = _chatState.value.copy(sending = false, error = e.message ?: "发送失败")
                serverMessages = serverMessages.filterNot { it.messageId == tempId }
                rebuildDisplay()
            }
        }
    }

    fun clearChatError() {
        _chatState.value = _chatState.value.copy(error = null)
    }

    // MARK: - 关注列表

    data class FollowingState(
        val users: List<PostService.FollowingUser> = emptyList(),
        val refreshing: Boolean = false,
        val loading: Boolean = false,
        val creatingConversation: Boolean = false,
        val error: String? = null
    )

    private val _followingState = MutableStateFlow(FollowingState())
    val followingState: StateFlow<FollowingState> = _followingState

    private var followingPage = 1
    private var followingHasMore = true

    fun refreshFollowing() {
        followingPage = 1
        followingHasMore = true
        _followingState.value = _followingState.value.copy(refreshing = true, error = null)
        loadFollowing()
    }

    fun loadMoreFollowing() {
        val s = _followingState.value
        if (s.loading || !followingHasMore) return
        followingPage += 1
        loadFollowing()
    }

    private fun loadFollowing() {
        _followingState.value = _followingState.value.copy(loading = true)
        viewModelScope.launch {
            try {
                val (items, hasMore) = PostService.fetchFollowing(page = followingPage)
                val cur = _followingState.value
                _followingState.value = cur.copy(
                    users = if (followingPage == 1) items else cur.users + items,
                    loading = false,
                    refreshing = false,
                    error = null
                )
                followingHasMore = hasMore
            } catch (e: Exception) {
                _followingState.value = _followingState.value.copy(
                    loading = false, refreshing = false, error = e.message ?: "加载失败"
                )
            }
        }
    }

    /** 选人发起聊天（幂等：已有会话直接返回）→ 返回会话 */
    fun createConversation(peerUserId: String, onResult: (ConversationItem?) -> Unit) {
        _followingState.value = _followingState.value.copy(creatingConversation = true)
        viewModelScope.launch {
            try {
                val conversation = MessageService.createConversation(peerUserId)
                _followingState.value = _followingState.value.copy(creatingConversation = false)
                onResult(conversation)
            } catch (e: Exception) {
                _followingState.value = _followingState.value.copy(
                    creatingConversation = false, error = e.message ?: "创建会话失败"
                )
                onResult(null)
            }
        }
    }

    // MARK: - 工具

    private fun uriToFile(uri: Uri): File {
        val context = getApplication<Application>()
        val input = context.contentResolver.openInputStream(uri)
            ?: throw IllegalStateException("无法读取图片")
        val file = File(context.cacheDir, "chat_${System.currentTimeMillis()}.jpg")
        input.use { i ->
            file.outputStream().use { output -> i.copyTo(output) }
        }
        return file
    }

    private fun nowString(): String =
        LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"))

    private fun parseDateTime(dateString: String): LocalDateTime? {
        return try {
            LocalDateTime.parse(dateString, DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"))
        } catch (_: Exception) {
            null
        }
    }

    /** 聊天时间显示：今天→HH:mm / 昨天→昨天 HH:mm / 同年→MM-dd HH:mm / 跨年→yyyy-MM-dd HH:mm */
    private fun formatChatTime(time: LocalDateTime): String {
        val now = LocalDateTime.now()
        val today = now.toLocalDate()
        val date = time.toLocalDate()
        return when {
            date.isEqual(today) -> time.format(DateTimeFormatter.ofPattern("HH:mm"))
            date.isEqual(today.minusDays(1)) -> "昨天 " + time.format(DateTimeFormatter.ofPattern("HH:mm"))
            date.year == today.year -> time.format(DateTimeFormatter.ofPattern("MM-dd HH:mm"))
            else -> time.format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm"))
        }
    }
}