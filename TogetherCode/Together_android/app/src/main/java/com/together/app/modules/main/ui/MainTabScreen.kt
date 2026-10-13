package com.together.app.modules.main.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Work
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.together.app.app.TogetherApplication
import com.together.app.core.design.AppColors
import com.together.app.core.model.ChildItem
import com.together.app.core.model.ConversationItem
import com.together.app.core.model.NotificationItem
import com.together.app.core.model.PostItem
import com.together.app.modules.home.ui.HomeScreen
import com.together.app.modules.message.ui.MessageScreen
import com.together.app.modules.mine.ui.MineScreen
import com.together.app.modules.plaza.ui.PlazaScreen
import com.together.app.modules.studio.ui.StudioOverviewScreen
import com.together.app.modules.teacher.ui.TeacherWorkbenchScreen
import kotlinx.coroutines.launch

/**
 * 主 Tab 框架（对齐 iOS MainTabBarController）
 * 家长：首页 / 广场 / ➕发布 / 消息 / 我的
 * 老师：工作台 / 广场 / ➕发布 / 消息 / 我的
 * 工作室：概览 / 广场 / ➕发布 / 消息 / 我的
 * 中间"发布"为大加号按钮，点击后全屏打开发布页
 */
@Composable
fun MainTabScreen(
    onChildClick: (ChildItem) -> Unit = {},
    onAddChild: () -> Unit = {},
    onPostClick: (PostItem) -> Unit = {},
    onPublish: (Int) -> Unit = {},
    onConversationClick: (ConversationItem) -> Unit = {},
    onAddContact: () -> Unit = {},
    onNotificationClick: (NotificationItem) -> Unit = {},
    // 我的页面回调
    onSettings: () -> Unit = {},
    onMyChildren: () -> Unit = {},
    onMyCourses: () -> Unit = {},
    onMyOrders: () -> Unit = {},
    onWorkManagement: () -> Unit = {},
    onFavorites: () -> Unit = {},
    onWallet: () -> Unit = {},
    onAuth: (role: Int, status: String, reason: String?) -> Unit = { _, _, _ -> }
) {
    val context = LocalContext.current
    val app = context.applicationContext as TogetherApplication
    val tokenStore = app.tokenStore
    val scope = rememberCoroutineScope()

    var role by remember { mutableIntStateOf(1) }
    var selectedTab by remember { mutableIntStateOf(0) }
    var unread by remember { mutableIntStateOf(0) }

    // 读取角色
    LaunchedEffect(Unit) {
        role = tokenStore.getRoleSync()
    }

    // 拉取未读数（ON_RESUME 刷新：首次进入 + 从聊天页返回）
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                scope.launch {
                    try {
                        val (_, _, u) = com.together.app.services.MessageService.fetchConversations(page = 1)
                        unread = u
                    } catch (_: Exception) { }
                }
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    // Tab 定义：第 1 个和第 5 个按角色切换
    data class TabItem(val label: String, val icon: ImageVector)
    val tabs = remember(role) {
        val firstTab = when (role) {
            2 -> TabItem("工作台", Icons.Filled.Work)
            3 -> TabItem("概览", Icons.Filled.Home)
            else -> TabItem("首页", Icons.Filled.Home)
        }
        listOf(
            firstTab,
            TabItem("广场", Icons.Filled.Explore),
            TabItem("发布", Icons.Filled.Add),  // 中间大加号
            TabItem("消息", Icons.Filled.Email),
            TabItem("我的", Icons.Filled.Person)
        )
    }

    Box(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        // 内容区
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(bottom = 64.dp)
        ) {
            when (selectedTab) {
                0 -> when (role) {
                    2 -> TeacherWorkbenchScreen()
                    3 -> StudioOverviewScreen()
                    else -> HomeScreen(
                        onChildClick = onChildClick,
                        onAddChild = onAddChild
                    )
                }
                1 -> PlazaScreen(onPostClick = onPostClick)
                2 -> { /* 发布 tab 不切内容 */ }
                3 -> MessageScreen(
                    onConversationClick = onConversationClick,
                    onAddContact = onAddContact,
                    onNotificationClick = onNotificationClick
                )
                4 -> MineScreen(
                    onSettings = onSettings,
                    onMyChildren = onMyChildren,
                    onMyCourses = onMyCourses,
                    onMyOrders = onMyOrders,
                    onWorkManagement = onWorkManagement,
                    onFavorites = onFavorites,
                    onWallet = onWallet,
                    onAuth = onAuth
                )
            }
        }

        // 底部 TabBar
        Row(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .height(64.dp)
                .background(AppColors.Surface),
            verticalAlignment = Alignment.CenterVertically
        ) {
            tabs.forEachIndexed { index, tab ->
                if (index == 2) {
                    // 中间大加号
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth(),
                        contentAlignment = Alignment.Center
                    ) {
                        Box(
                            modifier = Modifier
                                .offset(y = (-14).dp)
                                .size(48.dp)
                                .shadow(elevation = 6.dp, shape = CircleShape)
                                .clip(CircleShape)
                                .background(AppColors.Brand)
                                .clickable {
                                    onPublish(role)
                                },
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                Icons.Filled.Add,
                                contentDescription = "发布",
                                tint = Color.White,
                                modifier = Modifier.size(28.dp)
                            )
                        }
                    }
                } else {
                    // 普通 tab
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth()
                            .clickable { selectedTab = index },
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        val selected = selectedTab == index
                        if (index == 3 && unread > 0) {
                            // 消息角标
                            BadgedBox(
                                badge = {
                                    Badge {
                                        Text(
                                            text = if (unread > 99) "99+" else unread.toString(),
                                            fontSize = 10.sp
                                        )
                                    }
                                }
                            ) {
                                Icon(
                                    tab.icon,
                                    contentDescription = tab.label,
                                    tint = if (selected) AppColors.Brand else AppColors.Muted,
                                    modifier = Modifier.size(24.dp)
                                )
                            }
                        } else {
                            Icon(
                                tab.icon,
                                contentDescription = tab.label,
                                tint = if (selected) AppColors.Brand else AppColors.Muted,
                                modifier = Modifier.size(24.dp)
                            )
                        }
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = tab.label,
                            fontSize = 10.sp,
                            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                            color = if (selected) AppColors.Brand else AppColors.Muted
                        )
                    }
                }
            }
        }

        // TabBar 顶部分割线
        Box(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 64.dp)
                .fillMaxWidth()
                .height(0.5.dp)
                .background(AppColors.Line)
        )
    }
}