package com.together.app.modules.mine.ui

import android.widget.Toast
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalanceWallet
import androidx.compose.material.icons.filled.ChildCare
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.ReceiptLong
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.VpnKey
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.component.TogetherAvatar
import com.together.app.modules.mine.MineViewModel
import com.together.app.services.MineService
import androidx.compose.runtime.collectAsState

/**
 * 「我的」个人中心（对齐 iOS MineViewController）
 * 沉浸式固定头部（深绿延伸状态栏 + 毛玻璃统计卡）+ 下方菜单卡独立滚动
 */
@Composable
fun MineScreen(
    onSettings: () -> Unit = {},
    onMyChildren: () -> Unit = {},
    onMyCourses: () -> Unit = {},
    onMyOrders: () -> Unit = {},
    onWorkManagement: () -> Unit = {},
    onFavorites: () -> Unit = {},
    onWallet: () -> Unit = {},
    onAuth: (role: Int, status: String, reason: String?) -> Unit = {},
    viewModel: MineViewModel = viewModel()
) {
    val state by viewModel.state.collectAsState()
    val showSheet by viewModel.showRoleSheet.collectAsState()
    val authStatuses by viewModel.authStatuses.collectAsState()
    val toast by viewModel.toast.collectAsState()
    val context = LocalContext.current

    // ON_RESUME 刷新（从设置/资料编辑返回时刷新头部）
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                viewModel.refreshData()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    // Toast
    LaunchedEffect(toast) {
        toast?.let {
            Toast.makeText(context, it, Toast.LENGTH_SHORT).show()
            viewModel.clearToast()
        }
    }

    // 认证页跳转
    LaunchedEffect(Unit) {
        viewModel.authNavigation.collect { nav ->
            onAuth(nav.role, nav.status, nav.reason)
        }
    }

    val profile = state.profile
    val needsAuth = !(profile?.hasRole(2) ?: false) && !(profile?.hasRole(3) ?: false)

    Box(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        Column(modifier = Modifier.fillMaxSize()) {
            // 固定头部（深绿渐变，不随滚动）
            MineHeader(
                profile = profile,
                stats = state.stats,
                onIdentityTapped = { viewModel.showRoleSheet() },
                onSettings = onSettings,
                onStatTapped = { index ->
                    if (index == 0) {
                        onMyChildren()
                    } else {
                        val titles = listOf("我的孩子", "在学课程", "收藏作品")
                        Toast.makeText(context, "「${titles[index]}」功能开发中", Toast.LENGTH_SHORT).show()
                    }
                }
            )

            // 菜单区：头部下方独立滚动
            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(bottom = AppDimens.Xl)
            ) {
                item {
                    MineMenuCard(
                        groups = listOf(contentMenuItems, serviceMenuItems),
                        onSelect = { title ->
                            when (title) {
                                "我的孩子" -> onMyChildren()
                                "我的课程" -> onMyCourses()
                                "我的订单" -> onMyOrders()
                                "作品管理" -> onWorkManagement()
                                "收藏与动态" -> onFavorites()
                                "收益中心" -> onWallet()
                                "设置" -> onSettings()
                            }
                        }
                    )
                }
                // 底部开通条（未开通老师/工作室任一身份时显示）
                if (needsAuth) {
                    item {
                        MineAuthFooter(onAuthTapped = { viewModel.showRoleSheet() })
                    }
                }
            }
        }

        // 身份切换弹窗
        if (showSheet) {
            RoleSwitchSheet(
                roles = profile?.roles ?: listOf(1),
                currentRole = profile?.currentRole ?: 1,
                authStatuses = authStatuses,
                teacherName = profile?.teacherName,
                onRoleTapped = { role -> viewModel.onRoleRowTapped(role) },
                onDismiss = { viewModel.dismissRoleSheet() }
            )
        }
    }
}

// MARK: - 菜单数据

private data class MineMenuItem(val icon: ImageVector, val title: String)

private val contentMenuItems = listOf(
    MineMenuItem(Icons.Filled.ChildCare, "我的孩子"),
    MineMenuItem(Icons.Filled.MenuBook, "我的课程"),
    MineMenuItem(Icons.Filled.ReceiptLong, "我的订单"),
    MineMenuItem(Icons.Filled.PhotoLibrary, "作品管理")
)

private val serviceMenuItems = listOf(
    MineMenuItem(Icons.Filled.Favorite, "收藏与动态"),
    MineMenuItem(Icons.Filled.AccountBalanceWallet, "收益中心"),
    MineMenuItem(Icons.Filled.Settings, "设置")
)

// MARK: - 头部

@Composable
private fun MineHeader(
    profile: MineService.MineProfile?,
    stats: MineService.MineStats,
    onIdentityTapped: () -> Unit,
    onSettings: () -> Unit,
    onStatTapped: (Int) -> Unit
) {
    val roleText = when (profile?.currentRole) {
        2 -> "老师"
        3 -> "工作室"
        else -> "家长"
    }
    val nickname = profile?.user?.nickname ?: "未登录"
    val avatar = profile?.user?.avatar
    val city = profile?.user?.city

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(Brush.verticalGradient(listOf(AppColors.Brand, AppColors.BrandDark)))
    ) {
        // 装饰光晕：右上 Wood 大圆 + 左上白小圆
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .offset(x = 40.dp, y = (-20).dp)
                .size(140.dp)
                .clip(CircleShape)
                .background(AppColors.Wood.copy(alpha = 0.16f))
        )
        Box(
            modifier = Modifier
                .align(Alignment.TopStart)
                .offset(x = (-16).dp, y = 30.dp)
                .size(60.dp)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.07f))
        )

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(horizontal = AppDimens.L)
                .padding(top = AppDimens.S)
        ) {
            // 顶行：身份胶囊 + 设置按钮
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // 身份胶囊
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(AppDimens.RadiusTag))
                        .background(Color.White.copy(alpha = 0.16f))
                        .clickable(onClick = onIdentityTapped)
                        .padding(horizontal = 10.dp, vertical = 5.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = roleText,
                        color = Color.White,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium
                    )
                    Icon(
                        Icons.Filled.ArrowDropDown,
                        contentDescription = "切换身份",
                        tint = Color.White.copy(alpha = 0.8f),
                        modifier = Modifier.size(16.dp)
                    )
                }
                // 设置按钮
                Icon(
                    Icons.Filled.Settings,
                    contentDescription = "设置",
                    tint = Color.White.copy(alpha = 0.85f),
                    modifier = Modifier
                        .size(24.dp)
                        .clickable(onClick = onSettings)
                )
            }

            Spacer(modifier = Modifier.height(AppDimens.L))

            // 大头像 64 + 昵称 + 城市
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(68.dp)
                        .clip(CircleShape)
                        .background(Color.White)
                        .padding(2.dp),
                    contentAlignment = Alignment.Center
                ) {
                    TogetherAvatar(
                        url = avatar,
                        name = nickname,
                        size = 64.dp
                    )
                }
                Spacer(modifier = Modifier.width(AppDimens.M))
                Column {
                    Text(
                        text = nickname,
                        color = Color.White,
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Bold
                    )
                    if (!city.isNullOrBlank()) {
                        Spacer(modifier = Modifier.height(4.dp))
                        Row(
                            modifier = Modifier
                                .clip(RoundedCornerShape(AppDimens.RadiusTag))
                                .background(Color.White.copy(alpha = 0.14f))
                                .padding(horizontal = 8.dp, vertical = 3.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                Icons.Filled.LocationOn,
                                contentDescription = null,
                                tint = Color.White.copy(alpha = 0.8f),
                                modifier = Modifier.size(11.dp)
                            )
                            Spacer(modifier = Modifier.width(3.dp))
                            Text(
                                text = city,
                                color = Color.White.copy(alpha = 0.9f),
                                fontSize = 11.sp
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(AppDimens.L))

            // 毛玻璃统计卡
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(76.dp)
                    .clip(RoundedCornerShape(AppDimens.RadiusCard))
                    .background(Color.White.copy(alpha = 0.13f))
                    .padding(vertical = 12.dp)
            ) {
                StatCell("我的孩子", stats.childrenCount, 0, onStatTapped)
                StatDivider()
                StatCell("在学课程", stats.courseCount, 1, onStatTapped)
                StatDivider()
                StatCell("收藏作品", stats.favoriteCount, 2, onStatTapped)
            }

            Spacer(modifier = Modifier.height(AppDimens.S))
        }
    }
}

@Composable
private fun StatCell(label: String, value: Int, index: Int, onTap: (Int) -> Unit) {
    Column(
        modifier = Modifier
            .weight(1f)
            .fillMaxWidth()
            .clickable { onTap(index) },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = value.toString(),
            color = Color.White,
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold
        )
        Spacer(modifier = Modifier.height(2.dp))
        Text(
            text = label,
            color = Color.White.copy(alpha = 0.75f),
            fontSize = 11.sp
        )
    }
}

@Composable
private fun StatDivider() {
    Box(
        modifier = Modifier
            .width(0.5.dp)
            .height(40.dp)
            .background(Color.White.copy(alpha = 0.14f))
    )
}

// MARK: - 菜单卡

@Composable
private fun MineMenuCard(
    groups: List<List<MineMenuItem>>,
    onSelect: (String) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M)
            .padding(top = 6.dp)
    ) {
        groups.forEachIndexed { groupIndex, items ->
            if (groupIndex > 0) {
                Spacer(modifier = Modifier.height(AppDimens.M))
            }
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(AppDimens.RadiusCard))
                    .background(AppColors.Surface)
                    .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            ) {
                items.forEachIndexed { index, item ->
                    MenuRow(item, showDivider = index < items.size - 1, onClick = { onSelect(item.title) })
                }
            }
        }
    }
}

@Composable
private fun MenuRow(item: MineMenuItem, showDivider: Boolean, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = AppDimens.CardInner, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                item.icon,
                contentDescription = item.title,
                tint = AppColors.Brand,
                modifier = Modifier.size(22.dp)
            )
            Spacer(modifier = Modifier.width(AppDimens.M))
            Text(
                text = item.title,
                color = AppColors.Ink,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.weight(1f)
            )
            Icon(
                Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = AppColors.Muted,
                modifier = Modifier.size(18.dp)
            )
        }
        if (showDivider) {
            Box(
                modifier = Modifier
                    .padding(start = AppDimens.CardInner + 22.dp + AppDimens.M)
                    .fillMaxWidth()
                    .height(0.5.dp)
                    .background(AppColors.Line)
            )
        }
    }
}

// MARK: - 开通条

@Composable
private fun MineAuthFooter(onAuthTapped: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M)
            .padding(top = AppDimens.L)
            .height(52.dp)
            .clip(RoundedCornerShape(AppDimens.RadiusButton))
            .background(AppColors.Surface)
            .clickable(onClick = onAuthTapped)
            .padding(horizontal = AppDimens.M),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            Icons.Filled.VpnKey,
            contentDescription = null,
            tint = AppColors.Brand,
            modifier = Modifier.size(22.dp)
        )
        Spacer(modifier = Modifier.width(AppDimens.S))
        Text(
            text = "开通老师/工作室身份，解锁教学与经营能力",
            color = AppColors.Sub,
            fontSize = 12.sp,
            modifier = Modifier.weight(1f)
        )
        Text(
            text = "去认证",
            color = AppColors.Brand,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium
        )
    }
}