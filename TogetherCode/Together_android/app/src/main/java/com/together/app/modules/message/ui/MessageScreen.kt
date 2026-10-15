package com.together.app.modules.message.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalanceWallet
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ChatBubble
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.ReceiptLong
import androidx.compose.material.icons.filled.School
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import com.together.app.core.component.AppPullRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.component.TogetherAvatar
import com.together.app.core.component.TogetherDivider
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.ConversationItem
import com.together.app.core.model.NotificationItem
import com.together.app.modules.message.MessageViewModel
import com.together.app.modules.message.MessageViewModel.MessageState
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filter

/**
 * 消息中心（对齐 iOS MessageViewController）
 * 双 Tab（对话/通知）胶囊切换 + 角标 + 下拉刷新 + 触底加载
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MessageScreen(
    onConversationClick: (ConversationItem) -> Unit,
    onAddContact: () -> Unit,
    onNotificationClick: (NotificationItem) -> Unit,
    viewModel: MessageViewModel = viewModel()
) {
    val state by viewModel.messageState.collectAsState()

    // 监听 WebSocket 实时消息 → 静默刷新会话列表
    LaunchedEffect(Unit) {
        viewModel.observeConversationUpdates()
    }

    // ON_RESUME 刷新当前 Tab（首次进入 + 从聊天页返回 + 切 Tab 回来）
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                viewModel.reloadCurrent()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
            .statusBarsPadding()
    ) {
        // 标题行
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(AppDimens.TopBarHeight)
                .padding(horizontal = AppDimens.L),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "消息",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.Ink
            )
            Spacer(modifier = Modifier.weight(1f))
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(AppColors.SurfaceAlt)
                    .clickable { onAddContact() },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Filled.Add,
                    contentDescription = "发起聊天",
                    tint = AppColors.Sub,
                    modifier = Modifier.size(20.dp)
                )
            }
        }

        // 胶囊双 Tab
        SegmentedTabs(
            currentTab = state.currentTab,
            chatUnread = state.chatUnread,
            notifUnread = state.notifUnread,
            onTabChange = { viewModel.switchTab(it) }
        )

        // 内容
        if (state.currentTab == 0) {
            ConversationList(state, viewModel, onConversationClick)
        } else {
            NotificationList(state, viewModel, onNotificationClick)
        }
    }
}

// MARK: - 胶囊双 Tab（SurfaceAlt 底 + BrandSoft 选中，角标当前 Tab 不显示）

@Composable
private fun SegmentedTabs(
    currentTab: Int,
    chatUnread: Int,
    notifUnread: Int,
    onTabChange: (Int) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L, vertical = AppDimens.S)
            .clip(RoundedCornerShape(50))
            .background(AppColors.SurfaceAlt)
            .padding(3.dp)
    ) {
        TabButton(
            label = "对话",
            selected = currentTab == 0,
            badgeCount = if (currentTab != 0) chatUnread else 0,
            modifier = Modifier.weight(1f),
            onClick = { onTabChange(0) }
        )
        TabButton(
            label = "通知",
            selected = currentTab == 1,
            badgeCount = if (currentTab != 1) notifUnread else 0,
            modifier = Modifier.weight(1f),
            onClick = { onTabChange(1) }
        )
    }
}

@Composable
private fun TabButton(
    label: String,
    selected: Boolean,
    badgeCount: Int,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Box(
        modifier = modifier
            .height(34.dp)
            .clip(RoundedCornerShape(50))
            .background(if (selected) AppColors.BrandSoft else Color.Transparent)
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = label,
                fontSize = 14.sp,
                fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                color = if (selected) AppColors.BrandDark else AppColors.Sub
            )
            if (badgeCount > 0) {
                Spacer(modifier = Modifier.width(4.dp))
                Box(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(AppColors.Danger)
                        .padding(horizontal = 5.dp, vertical = 1.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = if (badgeCount > 99) "99+" else badgeCount.toString(),
                        color = Color.White,
                        fontSize = 10.sp
                    )
                }
            }
        }
    }
}

// MARK: - 会话列表

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ConversationList(
    state: MessageState,
    viewModel: MessageViewModel,
    onConversationClick: (ConversationItem) -> Unit
) {
    val listState = rememberLazyListState()

    // 触底加载更多
    LaunchedEffect(listState) {
        snapshotFlow {
            val lastVisible = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: -1
            val total = listState.layoutInfo.totalItemsCount
            lastVisible >= total - 3 && total > 0
        }
        .distinctUntilChanged()
        .filter { it }
        .collect { viewModel.loadMoreConversations() }
    }

    AppPullRefreshBox(
        isRefreshing = state.refreshing,
        onRefresh = { viewModel.refreshConversations() }
    ) {
        if (state.conversations.isEmpty() && state.loading && state.refreshing.not()) {
            CircularProgressIndicator(
                modifier = Modifier
                    .padding(top = 80.dp)
                    .align(Alignment.TopCenter),
                color = AppColors.Brand
            )
        } else if (state.conversations.isEmpty()) {
            EmptyOrError(state, "暂无会话") { viewModel.refreshConversations() }
        } else {
            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(bottom = AppDimens.Xl)
            ) {
                items(state.conversations, key = { it.conversationId }) { item ->
                    ConversationCell(item) { onConversationClick(item) }
                    TogetherDivider()
                }
                if (state.loading) {
                    item { FooterLoading() }
                }
            }
        }
    }
}

@Composable
private fun ConversationCell(item: ConversationItem, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.Surface)
            .clickable { onClick() }
            .padding(horizontal = AppDimens.L, vertical = AppDimens.M),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // 头像 + 未读角标
        Box {
            TogetherAvatar(
                url = item.peerAvatar,
                name = item.peerName,
                size = 52.dp
            )
            if (item.unreadCount > 0) {
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .offset(x = 4.dp, y = (-4).dp)
                        .clip(CircleShape)
                        .background(AppColors.Danger)
                        .padding(horizontal = 5.dp, vertical = 1.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = if (item.unreadCount > 99) "99+" else item.unreadCount.toString(),
                        color = Color.White,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }

        Spacer(modifier = Modifier.width(AppDimens.M))

        // 名称 + 预览（关联孩子加前缀）
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = item.peerName,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(2.dp))
            val prefix = item.child?.nickname?.takeIf { it.isNotEmpty() }?.let { "[$it] " } ?: ""
            Text(
                text = prefix + item.lastMessagePreview,
                fontSize = 13.sp,
                color = AppColors.Muted,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }

        Spacer(modifier = Modifier.width(AppDimens.S))

        Text(
            text = item.timeText,
            fontSize = 12.sp,
            color = AppColors.Muted
        )
    }
}

// MARK: - 通知列表

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun NotificationList(
    state: MessageState,
    viewModel: MessageViewModel,
    onNotificationClick: (NotificationItem) -> Unit
) {
    val listState = rememberLazyListState()

    // 触底加载更多
    LaunchedEffect(listState) {
        snapshotFlow {
            val lastVisible = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: -1
            val total = listState.layoutInfo.totalItemsCount
            lastVisible >= total - 3 && total > 0
        }
        .distinctUntilChanged()
        .filter { it }
        .collect { viewModel.loadMoreNotifications() }
    }

    AppPullRefreshBox(
        isRefreshing = state.refreshing,
        onRefresh = { viewModel.refreshNotifications() }
    ) {
        if (state.notifications.isEmpty() && state.loading && state.refreshing.not()) {
            CircularProgressIndicator(
                modifier = Modifier
                    .padding(top = 80.dp)
                    .align(Alignment.TopCenter),
                color = AppColors.Brand
            )
        } else if (state.notifications.isEmpty()) {
            EmptyOrError(state, "暂无通知") { viewModel.refreshNotifications() }
        } else {
            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(bottom = AppDimens.Xl)
            ) {
                items(state.notifications, key = { it.notificationId }) { item ->
                    NotificationCell(item) {
                        viewModel.markNotificationRead(item)
                        onNotificationClick(item)
                    }
                    TogetherDivider()
                }
                if (state.loading) {
                    item { FooterLoading() }
                }
            }
        }
    }
}

@Composable
private fun NotificationCell(item: NotificationItem, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.Surface)
            .clickable { onClick() }
            .padding(horizontal = AppDimens.L, vertical = AppDimens.M),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // 类型图标圆底 40
        val iconColor = notificationColor(item.type)
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(iconColor.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = notificationIcon(item.type),
                contentDescription = null,
                tint = iconColor,
                modifier = Modifier.size(20.dp)
            )
        }

        Spacer(modifier = Modifier.width(AppDimens.M))

        // 标题 + 内容（2 行）
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = item.title,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = item.content,
                fontSize = 13.sp,
                color = AppColors.Muted,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }

        Spacer(modifier = Modifier.width(AppDimens.S))

        // 时间 + 未读红点
        Column(horizontalAlignment = Alignment.End) {
            Text(
                text = item.timeText,
                fontSize = 12.sp,
                color = AppColors.Muted
            )
            if (!item.isRead) {
                Spacer(modifier = Modifier.height(4.dp))
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(AppColors.Danger)
                )
            }
        }
    }
}

// MARK: - 通知图标/颜色映射

private fun notificationIcon(type: String): ImageVector = when (type) {
    "order" -> Icons.Filled.ShoppingCart
    "order_refund", "refund" -> Icons.Filled.ReceiptLong
    "course" -> Icons.Filled.School
    "withdraw" -> Icons.Filled.AccountBalanceWallet
    "post_like" -> Icons.Filled.Favorite
    "post_comment" -> Icons.Filled.ChatBubble
    "follow" -> Icons.Filled.PersonAdd
    else -> Icons.Filled.Notifications
}

private fun notificationColor(type: String): Color = when (type) {
    "order" -> AppColors.Brand
    "order_refund", "refund" -> AppColors.Danger
    "course" -> AppColors.Wood
    "withdraw" -> AppColors.Wood
    "post_like" -> AppColors.Danger
    "post_comment" -> AppColors.Brand
    "follow" -> AppColors.Brand
    else -> AppColors.Muted
}

// MARK: - 通用

@Composable
private fun EmptyOrError(state: MessageState, emptyText: String, onRetry: () -> Unit) {
    val error = state.error
    if (error != null) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = 80.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(text = "⚠️", fontSize = 40.sp)
            Spacer(modifier = Modifier.height(AppDimens.M))
            Text(text = error, color = AppColors.Danger, fontSize = 14.sp)
            Spacer(modifier = Modifier.height(AppDimens.M))
            Text(
                text = "重试",
                color = AppColors.Brand,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier
                    .clip(RoundedCornerShape(AppDimens.RadiusButton))
                    .clickable { onRetry() }
                    .padding(horizontal = AppDimens.L, vertical = AppDimens.S)
            )
        }
    } else {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = 80.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(text = "🍃", fontSize = 40.sp)
            Spacer(modifier = Modifier.height(AppDimens.M))
            Text(text = emptyText, color = AppColors.Muted, fontSize = 14.sp)
        }
    }
}

@Composable
private fun FooterLoading() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = AppDimens.M),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        CircularProgressIndicator(
            modifier = Modifier.size(18.dp),
            strokeWidth = 2.dp,
            color = AppColors.Muted
        )
        Spacer(modifier = Modifier.width(AppDimens.S))
        Text(text = "加载中…", fontSize = 12.sp, color = AppColors.Muted)
    }
}