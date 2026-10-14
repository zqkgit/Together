package com.together.app.modules.teacher.ui

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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
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
import com.together.app.modules.teacher.TeacherViewModel
import com.together.app.services.TeacherService

/**
 * 我的学生：工作室筛选 + 学生列表（头像 + 名字 + 课程 + 剩余课时 + 状态标签）
 * 对齐 iOS MyStudentsViewController
 */
@Composable
fun MyStudentsScreen(
    viewModel: TeacherViewModel = viewModel(),
    onBack: () -> Unit = {}
) {
    val state by viewModel.studentsState.collectAsState()
    val lifecycleOwner = LocalLifecycleOwner.current

    LaunchedEffect(Unit) { viewModel.loadStudents() }
    androidx.compose.runtime.DisposableEffect(lifecycleOwner) {
        val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME && state.students.isNotEmpty()) {
                viewModel.loadStudents(state.selectedStudioId)
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "我的学生", onBack = onBack)

        // 工作室筛选
        if (state.studios.isNotEmpty()) {
            LazyRow(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = AppDimens.L, vertical = AppDimens.S),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                item {
                    StudentStudioChip("全部工作室", state.selectedStudioId == null) {
                        viewModel.loadStudents(null)
                    }
                }
                items(state.studios) { studio ->
                    StudentStudioChip(
                        studio.name?.takeIf { it.isNotEmpty() } ?: "工作室",
                        state.selectedStudioId == studio.studioId
                    ) {
                        viewModel.loadStudents(studio.studioId)
                    }
                }
            }
        }

        Box(modifier = Modifier.weight(1f)) {
            when {
                state.loading && state.students.isEmpty() -> LoadingView()
                state.error != null && state.students.isEmpty() -> ErrorView(
                    message = state.error!!,
                    onRetry = { viewModel.loadStudents(state.selectedStudioId) }
                )
                state.students.isEmpty() -> EmptyStateView(message = "暂无学生")
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(
                        start = AppDimens.M, end = AppDimens.M,
                        top = AppDimens.Xs, bottom = AppDimens.Xl
                    )
                ) {
                    items(state.students, key = { it.childId ?: "" }) { student ->
                        StudentCard(student)
                    }
                }
            }
        }
    }
}

@Composable
private fun StudentStudioChip(text: String, selected: Boolean, onClick: () -> Unit) {
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

@Composable
private fun StudentCard(student: TeacherService.StudentRow) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.CardInner, vertical = AppDimens.L),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // 头像
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(CircleShape)
                .background(AppColors.SurfaceAlt),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = student.name.take(1),
                fontSize = 16.sp,
                color = AppColors.Wood,
                fontWeight = FontWeight.Medium
            )
        }

        // 信息
        Column(modifier = Modifier.weight(1f).padding(start = AppDimens.M)) {
            Text(
                text = student.name,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = AppColors.Ink
            )
            val course = student.primaryCourse
            val courseText = listOfNotNull(
                course?.title?.takeIf { it.isNotEmpty() },
                course?.className?.takeIf { it.isNotEmpty() }
            ).joinToString("·")
            if (courseText.isNotEmpty()) {
                Spacer(modifier = Modifier.height(2.dp))
                Text(text = courseText, fontSize = 12.sp, color = AppColors.Muted, maxLines = 2)
            }
            val remaining = course?.remainingLessons ?: 0
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "剩余课时${remaining}节" + if (remaining <= 2) "·建议提醒续费" else "",
                fontSize = 12.sp,
                color = if (student.lowLessons) AppColors.Clay else AppColors.Muted
            )
        }

        // 状态标签
        val badge = when {
            student.isLeaving -> Badge("请假中", AppColors.Clay, AppColors.WarnTint)
            student.todayScheduled == true -> Badge("今日上课", AppColors.Surface, AppColors.Brand)
            else -> null
        }
        badge?.let {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(10.dp))
                    .background(it.bg)
                    .padding(horizontal = 10.dp, vertical = 4.dp)
            ) {
                Text(text = it.text, fontSize = 11.sp, color = it.fg, fontWeight = FontWeight.Medium)
            }
        } ?: Spacer(modifier = Modifier.width(0.dp))
    }
}

private data class Badge(val text: String, val fg: androidx.compose.ui.graphics.Color, val bg: androidx.compose.ui.graphics.Color)