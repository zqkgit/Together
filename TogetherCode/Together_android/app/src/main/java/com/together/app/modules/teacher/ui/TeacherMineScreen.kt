package com.together.app.modules.teacher.ui

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
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
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
import com.together.app.core.component.TogetherAvatar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.mine.MineViewModel
import com.together.app.modules.mine.ui.RoleSwitchSheet
import com.together.app.services.TeacherService
import kotlinx.coroutines.launch

/**
 * 老师「我的」页（对齐 iOS TeacherMineViewController）
 *
 * 沉浸式头部（深绿渐变 + 身份胶囊 + 设置 + 头像/昵称/副标题 + 毛玻璃统计卡）
 * + 老师专属菜单卡（教学与教务 / 作品与财务）
 * 身份切换复用 MineViewModel + RoleSwitchSheet
 */
@Composable
fun TeacherMineScreen(
    onSettings: () -> Unit = {},
    onTimetable: () -> Unit = {},
    onWorkManagement: () -> Unit = {},
    onWallet: () -> Unit = {},
    onAuth: (role: Int, status: String, reason: String?) -> Unit = { _, _, _ -> },
    onMyTeachingCourses: () -> Unit = {},
    onMyStudents: () -> Unit = {},
    onLeaveApproval: () -> Unit = {},
    onReputation: () -> Unit = {},
    viewModel: MineViewModel = viewModel()
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val state by viewModel.state.collectAsState()
    val showSheet by viewModel.showRoleSheet.collectAsState()
    val authStatuses by viewModel.authStatuses.collectAsState()
    val toast by viewModel.toast.collectAsState()

    // 老师专属数据
    var teacherData by remember { mutableStateOf<TeacherService.MineData?>(null) }

    // ON_RESUME 刷新：老师数据 + 身份列表
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                viewModel.refreshData()
                scope.launch {
                    try {
                        teacherData = TeacherService.fetchMine()
                    } catch (_: Exception) { }
                }
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

    val profile = teacherData?.profile
    val stats = teacherData?.stats
    val mineProfile = state.profile

    Box(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        Column(modifier = Modifier.fillMaxSize()) {
            // 固定头部
            TeacherMineHeader(
                profile = profile,
                activeStudents = stats?.activeStudents ?: 0,
                totalLessons = stats?.totalLessons ?: 0,
                postCount = stats?.postCount ?: 0,
                onIdentityTapped = { viewModel.showRoleSheet() },
                onSettings = onSettings
            )

            // 菜单区
            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(bottom = AppDimens.Xl)
            ) {
                item {
                    TeacherMenuCard(
                        groups = listOf(teachingItems, serviceItems),
                        onSelect = { title ->
                            when (title) {
                                "我教的课程" -> onMyTeachingCourses()
                                "我的学生" -> onMyStudents()
                                "请假审批" -> onLeaveApproval()
                                "课表与排课" -> onTimetable()
                                "作品管理" -> onWorkManagement()
                                "收益中心" -> onWallet()
                                "评价与口碑" -> onReputation()
                                "设置" -> onSettings()
                            }
                        }
                    )
                }
            }
        }

        // 身份切换弹窗
        if (showSheet) {
            RoleSwitchSheet(
                roles = mineProfile?.roles ?: listOf(1, 2),
                currentRole = mineProfile?.currentRole ?: 2,
                authStatuses = authStatuses,
                teacherName = mineProfile?.teacherName ?: profile?.name,
                onRoleTapped = { role -> viewModel.onRoleRowTapped(role) },
                onDismiss = { viewModel.dismissRoleSheet() }
            )
        }
    }
}

// MARK: - 菜单数据

private data class TeacherMenuItem(val icon: ImageVector, val title: String)

/** 第一组：教学与教务 */
private val teachingItems = listOf(
    TeacherMenuItem(Icons.Filled.MenuBook, "我教的课程"),
    TeacherMenuItem(Icons.Filled.Groups, "我的学生"),
    TeacherMenuItem(Icons.Filled.CheckCircle, "请假审批"),
    TeacherMenuItem(Icons.Filled.CalendarMonth, "课表与排课")
)

/** 第二组：作品与财务 */
private val serviceItems = listOf(
    TeacherMenuItem(Icons.Filled.PhotoLibrary, "作品管理"),
    TeacherMenuItem(Icons.Filled.AccountBalanceWallet, "收益中心"),
    TeacherMenuItem(Icons.Filled.Star, "评价与口碑"),
    TeacherMenuItem(Icons.Filled.Settings, "设置")
)

// MARK: - 头部

@Composable
private fun TeacherMineHeader(
    profile: TeacherService.MineProfile?,
    activeStudents: Int,
    totalLessons: Int,
    postCount: Int,
    onIdentityTapped: () -> Unit,
    onSettings: () -> Unit
) {
    val name = profile?.name ?: "老师"
    val avatar = profile?.avatar
    val subtitle = profile?.subtitle ?: "教龄0年"

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(Brush.verticalGradient(listOf(AppColors.Brand, AppColors.BrandDark)))
    ) {
        // 装饰光晕
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
            // 顶行：身份胶囊 + 设置
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(AppDimens.RadiusTag))
                        .background(Color.White.copy(alpha = 0.16f))
                        .clickable(onClick = onIdentityTapped)
                        .padding(horizontal = 10.dp, vertical = 5.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "当前身份：老师",
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

            // 大头像 + 昵称 + 副标题（工作室·科目·教龄）
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
                        name = name,
                        size = 64.dp
                    )
                }
                Spacer(modifier = Modifier.width(AppDimens.M))
                Column {
                    Text(
                        text = name,
                        color = Color.White,
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = subtitle,
                        color = Color.White.copy(alpha = 0.82f),
                        fontSize = 12.sp,
                        maxLines = 2
                    )
                }
            }

            Spacer(modifier = Modifier.height(AppDimens.L))

            // 毛玻璃统计卡：在读学生 / 累计课时 / 我的作品
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(76.dp)
                    .clip(RoundedCornerShape(AppDimens.RadiusCard))
                    .background(Color.White.copy(alpha = 0.13f))
                    .padding(vertical = 12.dp)
            ) {
                TeacherStatCell(Modifier.weight(1f), "在读学生", activeStudents)
                TeacherStatDivider()
                TeacherStatCell(Modifier.weight(1f), "累计课时", totalLessons)
                TeacherStatDivider()
                TeacherStatCell(Modifier.weight(1f), "我的作品", postCount)
            }

            Spacer(modifier = Modifier.height(AppDimens.S))
        }
    }
}

@Composable
private fun TeacherStatCell(modifier: Modifier, label: String, value: Int) {
    Column(
        modifier = modifier.fillMaxWidth(),
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
private fun TeacherStatDivider() {
    Box(
        modifier = Modifier
            .width(0.5.dp)
            .height(40.dp)
            .background(Color.White.copy(alpha = 0.14f))
    )
}

// MARK: - 菜单卡

@Composable
private fun TeacherMenuCard(
    groups: List<List<TeacherMenuItem>>,
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
                    .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
                    .clip(RoundedCornerShape(AppDimens.RadiusCard))
                    .background(AppColors.Surface)
            ) {
                items.forEachIndexed { index, item ->
                    TeacherMenuRow(item, showDivider = index < items.size - 1, onClick = { onSelect(item.title) })
                }
            }
        }
    }
}

@Composable
private fun TeacherMenuRow(item: TeacherMenuItem, showDivider: Boolean, onClick: () -> Unit) {
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