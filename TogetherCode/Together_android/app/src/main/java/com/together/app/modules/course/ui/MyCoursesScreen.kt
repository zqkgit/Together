package com.together.app.modules.course.ui

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.component.EmptyStateView
import com.together.app.core.component.ErrorView
import com.together.app.core.component.LoadingView
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.MyCourseItem
import com.together.app.modules.course.MyCourseViewModel

/**
 * 我的课程（家长端：在学课程列表 + 进度 + 下一节课）
 * 对齐 iOS MyCoursesViewController
 * childId 为空时展示所有孩子的课程，顶部可按孩子筛选
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MyCoursesScreen(
    childId: String? = null,
    childName: String? = null,
    viewModel: MyCourseViewModel = viewModel(),
    onBack: () -> Unit = {},
    onCourseClick: (childId: String, courseId: String, courseTitle: String) -> Unit = { _, _, _ -> }
) {
    val state by viewModel.coursesState.collectAsState()
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    // 初始加载 + ON_RESUME 刷新
    LaunchedEffect(childId) {
        viewModel.loadMyCourses(childId)
    }
    androidx.compose.runtime.DisposableEffect(lifecycleOwner) {
        val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME && state.allItems.isNotEmpty()) {
                viewModel.loadMyCourses(childId)
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "我的课程", onBack = onBack)

        // 多孩子筛选 chips
        if (state.isMultiChild && (childId == null || childId.isEmpty())) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = AppDimens.L, vertical = AppDimens.S),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                FilterChip("全部", state.selectedChildId == null) {
                    viewModel.selectChild(null)
                }
                state.children.forEach { child ->
                    FilterChip(child.name, state.selectedChildId == child.childId) {
                        viewModel.selectChild(child.childId.takeIf { it.isNotEmpty() })
                    }
                }
            }
        }

        // 内容
        Box(modifier = Modifier.weight(1f)) {
            when {
                state.loading && state.allItems.isEmpty() -> LoadingView()
                state.error != null && state.allItems.isEmpty() -> ErrorView(
                    message = state.error!!,
                    onRetry = { viewModel.loadMyCourses(childId) }
                )
                state.filteredItems.isEmpty() -> EmptyStateView(
                    message = "${childName ?: "孩子"}还没有报名课程"
                )
                else -> PullToRefreshBox(
                    isRefreshing = state.loading,
                    onRefresh = { viewModel.loadMyCourses(childId) },
                    modifier = Modifier.fillMaxSize()
                ) {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(
                            start = AppDimens.L,
                            end = AppDimens.L,
                            top = AppDimens.S,
                            bottom = AppDimens.Xl
                        ),
                        verticalArrangement = Arrangement.spacedBy(AppDimens.S)
                    ) {
                        items(state.filteredItems, key = { it.balanceId.ifEmpty { it.courseId } }) { item ->
                            MyCourseCard(
                                item = item,
                                showsChildName = childId == null || childId.isEmpty(),
                                onClick = {
                                    onCourseClick(
                                        item.childId ?: "",
                                        item.courseId,
                                        item.courseTitle.ifEmpty { "课程学习" }
                                    )
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 筛选 Chip

@Composable
private fun FilterChip(text: String, selected: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(17.dp))
            .background(if (selected) AppColors.Brand else AppColors.SurfaceAlt)
            .clickable { onClick() }
            .padding(horizontal = 14.dp, vertical = 6.dp)
    ) {
        Text(
            text = text,
            fontSize = 13.sp,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
            color = if (selected) AppColors.Surface else AppColors.Sub
        )
    }
}

// MARK: - 课程卡片

@Composable
private fun MyCourseCard(
    item: MyCourseItem,
    showsChildName: Boolean,
    onClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable { onClick() }
            .padding(horizontal = AppDimens.CardInner, vertical = AppDimens.L)
    ) {
        // 行1：课程名 + 节数
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = item.courseTitle.ifEmpty { "未命名课程" },
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink,
                modifier = Modifier.weight(1f)
            )
            Text(
                text = "${item.consumedLessons}/${item.totalLessons}节",
                fontSize = 13.sp,
                color = AppColors.Sub
            )
        }

        // 下次课
        if (item.nextLessonText.isNotEmpty()) {
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = item.nextLessonText,
                fontSize = 13.sp,
                color = AppColors.Brand
            )
        }

        // 行2：孩子标签 + 工作室标签
        Spacer(modifier = Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            if (showsChildName && !item.childName.isNullOrEmpty()) {
                TagPill(text = item.childName!!, bg = AppColors.BrandSoft, fg = AppColors.Brand)
            }
            TagPill(text = item.studioTeacherText, bg = AppColors.SurfaceAlt, fg = AppColors.Sub)
        }

        // 行3：进度条 + 百分比
        Spacer(modifier = Modifier.height(10.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(6.dp)
                    .clip(RoundedCornerShape(3.dp))
                    .background(AppColors.SurfaceAlt)
            ) {
                val percent = item.progressPercent.coerceIn(0, 100)
                Box(
                    modifier = Modifier
                        .fillMaxWidth(percent / 100f)
                        .height(6.dp)
                        .clip(RoundedCornerShape(3.dp))
                        .background(AppColors.Brand)
                )
            }
            Spacer(modifier = Modifier.width(AppDimens.M))
            Text(
                text = "已学${percent(item)}%",
                fontSize = 12.sp,
                color = AppColors.Sub
            )
        }
    }
}

private fun percent(item: MyCourseItem): Int = item.progressPercent

@Composable
private fun TagPill(text: String, bg: androidx.compose.ui.graphics.Color, fg: androidx.compose.ui.graphics.Color) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(4.dp))
            .background(bg)
            .padding(horizontal = 10.dp, vertical = 4.dp)
    ) {
        Text(text = text, fontSize = 11.sp, color = fg)
    }
}