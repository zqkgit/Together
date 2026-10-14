package com.together.app.modules.studio.ui

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.core.component.EmptyStateView
import com.together.app.core.component.ErrorView
import com.together.app.core.component.LoadingView
import com.together.app.core.component.TogetherDivider
import com.together.app.core.component.resolveImageUrl
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.studio.StudioViewModel
import com.together.app.services.StudioService

/**
 * 工作室「课程管理」页（对齐 iOS StudioCourseListViewController）
 *
 * 分段（在售/审核中/已下架）+ 课程卡片（封面+标题+状态+老师·年龄·已售+价格+编辑/上下架/预览）
 * + 右下新建 FAB
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StudioCourseListScreen(
    onBack: () -> Unit = {},
    onPreview: (String) -> Unit = {},
    viewModel: StudioViewModel = viewModel()
) {
    val state by viewModel.courseState.collectAsState()
    val context = LocalContext.current
    var pendingToggle by remember { mutableStateOf<StudioService.StudioCourseItem?>(null) }

    // ON_RESUME 刷新
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) viewModel.loadCourses()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // 顶栏
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(AppDimens.TopBarHeight)
                    .background(AppColors.Surface),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onBack) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "返回",
                        tint = AppColors.Ink
                    )
                }
                Text(
                    text = "课程管理",
                    fontSize = 17.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.Ink
                )
            }

            // 分段
            CourseTabBar(
                selectedTab = state.selectedTab,
                onSelect = { viewModel.selectCourseTab(it) }
            )

            // 列表
            PullToRefreshBox(
                isRefreshing = state.loading,
                onRefresh = { viewModel.loadCourses() },
                modifier = Modifier.fillMaxSize()
            ) {
                when {
                    state.loading && state.courses.isEmpty() -> LoadingView()
                    state.error != null && state.courses.isEmpty() -> ErrorView(
                        message = state.error ?: "加载失败",
                        onRetry = { viewModel.loadCourses() }
                    )
                    state.courses.isEmpty() -> EmptyStateView(message = state.selectedTab.emptyText)
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(
                            start = AppDimens.L,
                            end = AppDimens.L,
                            top = AppDimens.S,
                            bottom = AppDimens.Xl
                        ),
                        verticalArrangement = Arrangement.spacedBy(AppDimens.S)
                    ) {
                        items(state.courses, key = { it.courseId }) { course ->
                            CourseCard(
                                course = course,
                                onEdit = {
                                    Toast.makeText(context, "课程编辑请在 Web 工作室后台操作", Toast.LENGTH_SHORT).show()
                                },
                                onToggle = { pendingToggle = course },
                                onPreview = { onPreview(course.courseId) }
                            )
                        }
                    }
                }
            }
        }

        // 新建课程 FAB
        FloatingActionButton(
            onClick = {
                Toast.makeText(context, "课程创建请在 Web 工作室后台操作", Toast.LENGTH_SHORT).show()
            },
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = AppDimens.L, bottom = AppDimens.Xl)
                .size(56.dp),
            containerColor = AppColors.Brand,
            contentColor = Color.White,
            shape = RoundedCornerShape(28.dp)
        ) {
            Icon(Icons.Default.Add, contentDescription = "新建课程")
        }
    }

    // 上架/下架确认
    pendingToggle?.let { course ->
        val status = course.status ?: 1
        val isOffline = status == 2
        AlertDialog(
            onDismissRequest = { pendingToggle = null },
            title = { Text(if (isOffline) "重新上架" else "下架课程", fontWeight = FontWeight.SemiBold) },
            text = {
                Text(
                    if (isOffline) "确认将「${course.title ?: ""}」重新上架？上架后家长端可正常浏览报名。"
                    else "下架「${course.title ?: ""}」后，家长端将不再展示该课程，已有订单不受影响。确认下架？"
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        pendingToggle = null
                        viewModel.setCourseStatus(course.courseId, if (isOffline) 1 else 2)
                    }
                ) {
                    Text(
                        if (isOffline) "确认上架" else "确认下架",
                        color = if (isOffline) AppColors.Brand else AppColors.Danger
                    )
                }
            },
            dismissButton = {
                TextButton(onClick = { pendingToggle = null }) {
                    Text("取消", color = AppColors.Muted)
                }
            }
        )
    }
}

// MARK: - 分段条

@Composable
private fun CourseTabBar(
    selectedTab: StudioViewModel.CourseTab,
    onSelect: (StudioViewModel.CourseTab) -> Unit
) {
    val tabs = StudioViewModel.CourseTab.entries

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L, vertical = AppDimens.S)
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(4.dp)
    ) {
        tabs.forEach { tab ->
            val selected = tab == selectedTab
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(13.dp))
                    .background(if (selected) AppColors.BrandSoft else AppColors.Surface)
                    .clickable { onSelect(tab) }
                    .padding(vertical = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = tab.title,
                    fontSize = 14.sp,
                    fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (selected) AppColors.Ink else AppColors.Sub,
                    maxLines = 1
                )
            }
        }
    }
}

// MARK: - 课程卡片

@Composable
private fun CourseCard(
    course: StudioService.StudioCourseItem,
    onEdit: () -> Unit,
    onToggle: () -> Unit,
    onPreview: () -> Unit
) {
    val status = course.status ?: 1

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.CardInner)
    ) {
        // 封面 + 标题/状态/副标题/价格
        Row(verticalAlignment = Alignment.Top) {
            // 封面 78dp
            CourseCover(
                cover = course.cover,
                courseId = course.courseId,
                modifier = Modifier.size(78.dp)
            )
            Spacer(modifier = Modifier.width(AppDimens.M))
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.Top) {
                    Text(
                        text = "${course.title ?: "未命名课程"} · ${course.lessonsText}",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = AppColors.Ink,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f)
                    )
                    Spacer(modifier = Modifier.width(AppDimens.S))
                    StatusPill(status = status)
                }
                Spacer(modifier = Modifier.height(6.dp))
                val teacher = if (course.hasTeacher) course.teacherName else "未分配老师"
                Text(
                    text = "$teacher · ${course.ageText} · ${course.salesText}",
                    fontSize = 12.sp,
                    color = AppColors.Muted,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = "${course.priceText} / 全期",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.Ink
                )
            }
        }

        Spacer(modifier = Modifier.height(AppDimens.L))
        TogetherDivider()
        Spacer(modifier = Modifier.height(AppDimens.M))

        // 操作按钮
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(AppDimens.M)
        ) {
            ActionButton(
                text = "编辑",
                textColor = AppColors.Sub,
                borderColor = AppColors.Line,
                modifier = Modifier.weight(1f),
                onClick = onEdit
            )
            if (status != 0) {
                ActionButton(
                    text = if (status == 2) "上架" else "下架",
                    textColor = if (status == 2) AppColors.Brand else AppColors.Danger,
                    borderColor = if (status == 2) AppColors.Brand else AppColors.Danger,
                    modifier = Modifier.weight(1f),
                    onClick = onToggle
                )
            }
            ActionButton(
                text = "预览",
                textColor = AppColors.Sub,
                borderColor = AppColors.Line,
                modifier = Modifier.weight(1f),
                onClick = onPreview
            )
        }
    }
}

// MARK: - 课程封面

@Composable
private fun CourseCover(
    cover: String?,
    courseId: String,
    modifier: Modifier = Modifier
) {
    val shape = RoundedCornerShape(AppDimens.RadiusTag)
    if (!cover.isNullOrBlank()) {
        AsyncImage(
            model = resolveImageUrl(cover),
            contentDescription = "课程封面",
            modifier = modifier.clip(shape)
        )
    } else {
        // 按课程 id 稳定取一个主题色块
        val palette = listOf(AppColors.Brand, AppColors.Wood, AppColors.Clay)
        val tint = palette[kotlin.math.abs(courseId.hashCode()) % palette.size]
        Box(
            modifier = modifier
                .clip(shape)
                .background(tint),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Default.Palette,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(30.dp)
            )
        }
    }
}

// MARK: - 状态标签

@Composable
private fun StatusPill(status: Int) {
    val (text, color, bg) = when (status) {
        0 -> Triple("审核中", AppColors.Warn, AppColors.WarnTint)
        2 -> Triple("已下架", AppColors.Muted, AppColors.SurfaceAlt)
        else -> Triple("在售", AppColors.Brand, AppColors.BrandSoft)
    }
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(10.dp))
            .background(bg)
            .padding(horizontal = 10.dp, vertical = 3.dp)
    ) {
        Text(
            text = text,
            fontSize = 11.sp,
            color = color
        )
    }
}

// MARK: - 操作按钮

@Composable
private fun ActionButton(
    text: String,
    textColor: Color,
    borderColor: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Box(
        modifier = modifier
            .height(34.dp)
            .clip(RoundedCornerShape(17.dp))
            .background(AppColors.Surface)
            .border(1.dp, borderColor, RoundedCornerShape(17.dp))
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            fontSize = 13.sp,
            color = textColor
        )
    }
}