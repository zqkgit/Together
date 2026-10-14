package com.together.app.modules.studio.ui

import android.widget.Toast
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.AutoStories
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Handshake
import androidx.compose.material.icons.filled.Replay
import androidx.compose.material.icons.filled.School
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
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
import com.together.app.modules.mine.MineViewModel
import com.together.app.modules.mine.ui.RoleSwitchSheet
import com.together.app.modules.studio.StudioViewModel

/**
 * 工作室「我的」页（对齐 iOS StudioMineViewController）
 *
 * 结构：深绿渐变封面（身份胶囊+设置+机构资料+白色统计卡）+ 菜单两组
 * 数据：GET /studio/mine
 */
@Composable
fun StudioMineScreen(
    onSettings: () -> Unit = {},
    onCourses: () -> Unit = {},
    onStudents: () -> Unit = {},
    onTeachers: () -> Unit = {},
    onOrders: () -> Unit = {},
    onRefunds: () -> Unit = {},
    onRevenue: () -> Unit = {},
    onCommissions: () -> Unit = {},
    onToast: (String) -> Unit = {},
    onAuth: (role: Int, status: String, reason: String?) -> Unit = { _, _, _ -> },
    viewModel: StudioViewModel = viewModel(),
    mineViewModel: MineViewModel = viewModel()
) {
    val context = LocalContext.current
    val state by viewModel.mineState.collectAsState()

    // 身份切换状态
    val mineState by mineViewModel.state.collectAsState()
    val showSheet by mineViewModel.showRoleSheet.collectAsState()
    val authStatuses by mineViewModel.authStatuses.collectAsState()
    val toast by mineViewModel.toast.collectAsState()

    // ON_RESUME 刷新
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                viewModel.loadMine()
                mineViewModel.refreshData()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    // Toast
    LaunchedEffect(toast) {
        toast?.let {
            Toast.makeText(context, it, Toast.LENGTH_SHORT).show()
            mineViewModel.clearToast()
        }
    }

    // 认证页跳转
    LaunchedEffect(Unit) {
        mineViewModel.authNavigation.collect { nav ->
            onAuth(nav.role, nav.status, nav.reason)
        }
    }

    val profile = state.profile
    val stats = state.stats
    val name = profile?.displayName ?: "未命名工作室"
    val mineProfile = mineState.profile

    Box(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
    Column(
        modifier = Modifier
            .fillMaxSize()
    ) {
        // 封面区（渐变绿）
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.linearGradient(
                        colors = listOf(AppColors.Brand, AppColors.BrandDark)
                    )
                )
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .statusBarsPadding()
                    .padding(top = AppDimens.S)
            ) {
                // 身份胶囊 + 设置按钮
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 18.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(15.dp))
                            .background(Color.White.copy(alpha = 0.2f))
                            .clickable { mineViewModel.showRoleSheet() }
                            .padding(horizontal = 14.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "当前身份：工作室",
                            fontSize = 13.sp,
                            color = Color.White
                        )
                        Spacer(modifier = Modifier.width(5.dp))
                        Text(
                            text = "▾",
                            fontSize = 10.sp,
                            color = Color.White.copy(alpha = 0.85f)
                        )
                    }
                    Spacer(modifier = Modifier.weight(1f))
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(Color.White.copy(alpha = 0.18f))
                            .clickable { onSettings() },
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Default.Settings,
                            contentDescription = "设置",
                            tint = Color.White.copy(alpha = 0.95f),
                            modifier = Modifier.size(17.dp)
                        )
                    }
                }

                // 机构头像 + 名称 + 副标题
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 18.dp, end = 18.dp, top = AppDimens.L),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(62.dp)
                            .clip(RoundedCornerShape(20.dp))
                            .background(Color.White.copy(alpha = 0.16f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = name.firstOrNull()?.toString() ?: "—",
                            fontSize = 24.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                    }
                    Spacer(modifier = Modifier.width(14.dp))
                    Column {
                        Text(
                            text = name,
                            fontSize = 22.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                        Text(
                            text = profile?.subtitle ?: "已认证机构 · 资料完善中",
                            fontSize = 12.sp,
                            color = Color.White.copy(alpha = 0.85f),
                            modifier = Modifier.padding(top = 5.dp)
                        )
                    }
                }

                // 白色统计卡
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 16.dp, end = 16.dp, top = 22.dp, bottom = 14.dp)
                        .height(76.dp)
                        .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(18.dp))
                        .clip(RoundedCornerShape(18.dp))
                        .background(AppColors.Surface)
                ) {
                    Row(modifier = Modifier.fillMaxSize()) {
                        StatItem(
                            value = stats?.activeStudentCount ?: 0,
                            title = "在读学员",
                            modifier = Modifier.weight(1f)
                        )
                        Box(
                            modifier = Modifier
                                .width(0.5.dp)
                                .height(40.dp)
                                .align(Alignment.CenterVertically)
                                .background(AppColors.Line)
                        )
                        StatItem(
                            value = stats?.onlineCourseCount ?: 0,
                            title = "在售课程",
                            modifier = Modifier.weight(1f)
                        )
                        Box(
                            modifier = Modifier
                                .width(0.5.dp)
                                .height(40.dp)
                                .align(Alignment.CenterVertically)
                                .background(AppColors.Line)
                        )
                        StatItem(
                            value = stats?.teacherCount ?: 0,
                            title = "入驻教师",
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }
        }

        // 菜单区（可滚动）
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = AppDimens.M)
        ) {
            Spacer(modifier = Modifier.height(6.dp))

            // 第一组：经营与教务
            MenuCard(
                title = "经营与教务",
                items = listOf(
                    MenuItem(Icons.Default.AutoStories, "课程管理"),
                    MenuItem(Icons.Default.Group, "学员管理"),
                    MenuItem(Icons.Default.School, "老师管理"),
                    MenuItem(Icons.Default.Description, "订单管理"),
                    MenuItem(Icons.Default.Replay, "退款审核")
                ),
                onSelect = { title ->
                    when (title) {
                        "课程管理" -> onCourses()
                        "学员管理" -> onStudents()
                        "老师管理" -> onTeachers()
                        "订单管理" -> onOrders()
                        "退款审核" -> onRefunds()
                    }
                }
            )

            Spacer(modifier = Modifier.height(AppDimens.M))

            // 第二组：财务与分销
            MenuCard(
                title = "财务与分销",
                items = listOf(
                    MenuItem(Icons.Default.Handshake, "分销返利设置"),
                    MenuItem(Icons.Default.BarChart, "收益中心"),
                    MenuItem(Icons.Default.Verified, "佣金审核"),
                    MenuItem(Icons.Default.Settings, "设置")
                ),
                onSelect = { title ->
                    when (title) {
                        "分销返利设置" -> onToast("全局返利比例与单课程覆盖设置将在下一阶段开放")
                        "收益中心" -> onRevenue()
                        "佣金审核" -> onCommissions()
                        "设置" -> onSettings()
                    }
                }
            )

            Spacer(modifier = Modifier.height(AppDimens.Xl))
        }
    }

        // 身份切换弹窗
        if (showSheet) {
            RoleSwitchSheet(
                roles = mineProfile?.roles ?: listOf(1, 3),
                currentRole = mineProfile?.currentRole ?: 3,
                authStatuses = authStatuses,
                teacherName = mineProfile?.teacherName,
                onRoleTapped = { role -> mineViewModel.onRoleRowTapped(role) },
                onDismiss = { mineViewModel.dismissRoleSheet() }
            )
        }
    }
}

// MARK: - 统计项

@Composable
private fun StatItem(value: Int, title: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = value.toString(),
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.BrandDark
        )
        Text(
            text = title,
            fontSize = 11.sp,
            color = AppColors.Muted,
            modifier = Modifier.padding(top = 2.dp)
        )
    }
}

// MARK: - 菜单组

private data class MenuItem(val icon: ImageVector, val title: String)

@Composable
private fun MenuCard(
    title: String,
    items: List<MenuItem>,
    onSelect: (String) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.L, vertical = AppDimens.S)
    ) {
        Text(
            text = title,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.Sub,
            modifier = Modifier.padding(start = AppDimens.Xs, top = AppDimens.S, bottom = AppDimens.Xs)
        )
        items.forEachIndexed { index, item ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onSelect(item.title) }
                    .padding(vertical = 13.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    item.icon,
                    contentDescription = null,
                    tint = AppColors.Brand,
                    modifier = Modifier.size(22.dp)
                )
                Spacer(modifier = Modifier.width(AppDimens.M))
                Text(
                    text = item.title,
                    fontSize = 15.sp,
                    color = AppColors.Ink,
                    modifier = Modifier.weight(1f)
                )
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    tint = AppColors.Muted,
                    modifier = Modifier.size(18.dp)
                )
            }
            if (index < items.size - 1) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(0.5.dp)
                        .background(AppColors.Line)
                )
            }
        }
    }
}