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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.component.EmptyStateView
import com.together.app.core.component.LoadingView
import com.together.app.core.component.TogetherAvatar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.teacher.TeacherViewModel
import com.together.app.services.TeacherService
import androidx.compose.runtime.collectAsState

/**
 * 老师工作台（对齐 iOS TeacherWorkbenchViewController）
 * 顶部数据卡（今日待消课 / 在读学生 / 本月出勤）+ 今日课程列表（学员勾选 → 一键点名消课）
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TeacherWorkbenchScreen(
    onOpenTimetable: () -> Unit = {},
    viewModel: TeacherViewModel = viewModel()
) {
    val state by viewModel.workbenchState.collectAsState()
    val toast by viewModel.toast.collectAsState()
    val undoConfirm by viewModel.undoConfirm.collectAsState()
    val context = LocalContext.current

    // ON_RESUME 刷新
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                viewModel.loadWorkbench()
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

    // 撤销确认弹窗
    undoConfirm?.let { confirm ->
        AlertDialog(
            onDismissRequest = { viewModel.dismissUndoConfirm() },
            title = { Text("撤销消课", fontWeight = FontWeight.Bold) },
            text = {
                Text(
                    if (confirm.isPostSource) {
                        "${confirm.childName} 是通过老师发帖自动消课的。撤销将退还课时，并同步取消帖子中的消课记录，确认撤销？"
                    } else {
                        "撤销 ${confirm.childName} 的本节消课？课时将自动退还。"
                    },
                    fontSize = 14.sp,
                    color = AppColors.Sub,
                    lineHeight = 20.sp
                )
            },
            confirmButton = {
                TextButton(onClick = { viewModel.confirmUndo() }) {
                    Text("撤销", color = AppColors.Danger, fontWeight = FontWeight.SemiBold)
                }
            },
            dismissButton = {
                TextButton(onClick = { viewModel.dismissUndoConfirm() }) {
                    Text("取消", color = AppColors.Muted)
                }
            },
            containerColor = AppColors.Surface,
            titleContentColor = AppColors.Ink
        )
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
            .statusBarsPadding()
    ) {
        // 顶栏
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(AppDimens.TopBarHeight)
                .padding(horizontal = AppDimens.L),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "工作台",
                style = MaterialTheme.typography.titleLarge,
                color = AppColors.Ink,
                fontWeight = FontWeight.Bold
            )
        }

        PullToRefreshBox(
            isRefreshing = state.loading,
            onRefresh = { viewModel.loadWorkbench() },
            modifier = Modifier.fillMaxSize()
        ) {
            when {
                state.today.isEmpty() && state.loading -> {
                    LoadingView()
                }
                state.today.isEmpty() && state.error != null -> {
                    Column(
                        modifier = Modifier.fillMaxSize(),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        Text("⚠️", fontSize = 40.sp)
                        Spacer(modifier = Modifier.height(AppDimens.M))
                        Text(state.error ?: "", color = AppColors.Danger, fontSize = 14.sp)
                        Spacer(modifier = Modifier.height(AppDimens.M))
                        Text(
                            "点击重试",
                            color = AppColors.Brand,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.clickable { viewModel.loadWorkbench() }
                        )
                    }
                }
                else -> {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(bottom = AppDimens.Xl),
                        verticalArrangement = Arrangement.spacedBy(0.dp)
                    ) {
                        // 顶部数据卡
                        item {
                            WorkbenchStatsRow(stats = state.stats)
                        }
                        // 今日课程标题 + 课表入口
                        item {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = AppDimens.L, vertical = AppDimens.S)
                                    .height(40.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = "今日课程",
                                    fontSize = 17.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = AppColors.Ink,
                                    modifier = Modifier.weight(1f)
                                )
                                Row(
                                    modifier = Modifier.clickable { onOpenTimetable() },
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        text = "课表",
                                        fontSize = 13.sp,
                                        color = AppColors.Brand,
                                        fontWeight = FontWeight.Medium
                                    )
                                    Icon(
                                        Icons.AutoMirrored.Filled.KeyboardArrowRight,
                                        contentDescription = "课表",
                                        tint = AppColors.Brand,
                                        modifier = Modifier.size(16.dp)
                                    )
                                }
                            }
                        }
                        if (state.today.isEmpty()) {
                            item {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(180.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        "今天没有排课，休息一下吧",
                                        color = AppColors.Muted,
                                        fontSize = 14.sp
                                    )
                                }
                            }
                        } else {
                            items(state.today.size) { index ->
                                WorkbenchScheduleCard(
                                    schedule = state.today[index],
                                    selectedIds = state.selectedBySchedule[state.today[index].scheduleId] ?: emptySet(),
                                    submitting = state.submitting,
                                    onToggleStudent = { childId ->
                                        viewModel.toggleStudent(state.today[index].scheduleId, childId)
                                    },
                                    onUndoStudent = { childId ->
                                        viewModel.requestUndo(state.today[index], childId)
                                    },
                                    onSubmit = { viewModel.submitAttendance(state.today[index]) }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 顶部数据卡

@Composable
private fun WorkbenchStatsRow(stats: TeacherService.WorkbenchStats) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M, vertical = AppDimens.M),
        horizontalArrangement = Arrangement.spacedBy(AppDimens.M)
    ) {
        StatsCard(
            value = "${stats.todayPending ?: 0}",
            title = "今日待消课",
            accent = AppColors.Clay,
            modifier = Modifier.weight(1f)
        )
        StatsCard(
            value = "${stats.activeStudents ?: 0}",
            title = "在读学生",
            accent = AppColors.Brand,
            modifier = Modifier.weight(1f)
        )
        StatsCard(
            value = "${stats.attendanceRate ?: 0}%",
            title = "本月出勤",
            accent = AppColors.Wood,
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun StatsCard(
    value: String,
    title: String,
    accent: Color,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(vertical = AppDimens.L),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = value,
            fontSize = 26.sp,
            fontWeight = FontWeight.Bold,
            color = accent
        )
        Spacer(modifier = Modifier.height(AppDimens.Xs))
        Text(
            text = title,
            fontSize = 12.sp,
            color = AppColors.Muted
        )
    }
}

// MARK: - 今日课程卡（含学员点名）

@Composable
private fun WorkbenchScheduleCard(
    schedule: TeacherService.WorkbenchSchedule,
    selectedIds: Set<String>,
    submitting: Boolean,
    onToggleStudent: (String) -> Unit,
    onUndoStudent: (String) -> Unit,
    onSubmit: () -> Unit
) {
    val students = schedule.students ?: emptyList()
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M, vertical = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.CardInner)
    ) {
        // 时间
        val timeText = listOfNotNull(schedule.startTime, schedule.endTime).joinToString(" - ")
        Text(
            text = timeText.ifEmpty { "--:--" },
            fontSize = 13.sp,
            color = AppColors.Clay,
            fontWeight = FontWeight.Medium
        )
        // 标题 + 状态标签
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = AppDimens.Xs),
            verticalAlignment = Alignment.CenterVertically
        ) {
            val courseTitle = schedule.course?.title ?: "课程"
            val className = schedule.classRef?.name ?: "班级"
            val location = schedule.location?.takeIf { it.isNotEmpty() }
            val titleText = buildString {
                append("$courseTitle · $className")
                location?.let { append("  $it") }
            }
            Text(
                text = titleText,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f)
            )
            Spacer(modifier = Modifier.width(AppDimens.S))
            // 状态标签
            val (statusColor, statusBg) = when (schedule.consumeStatus) {
                "completed" -> AppColors.Success to AppColors.SuccessTint
                "partial" -> AppColors.Brand to AppColors.BrandSoft
                else -> AppColors.Clay to AppColors.WarnTint
            }
            Text(
                text = schedule.statusText,
                color = statusColor,
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(statusBg)
                    .padding(horizontal = AppDimens.S, vertical = AppDimens.Xs)
            )
        }
        // 分隔线
        Spacer(modifier = Modifier.height(AppDimens.M))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(0.5.dp)
                .background(AppColors.Line)
        )
        // 学员列表
        students.forEachIndexed { index, student ->
            StudentRow(
                student = student,
                selected = selectedIds.contains(student.childId),
                showDivider = index < students.size - 1,
                onTap = {
                    if (!student.isLeave) {
                        if (student.isConsumed) {
                            onUndoStudent(student.childId)
                        } else {
                            onToggleStudent(student.childId)
                        }
                    }
                }
            )
        }
        // 提交按钮
        Spacer(modifier = Modifier.height(AppDimens.M))
        val count = selectedIds.size
        val (btnBg, btnText, btnEnabled) = if (schedule.isCompleted) {
            Triple(AppColors.SurfaceAlt, "已消课", false)
        } else if (count > 0) {
            Triple(AppColors.Brand, "一键点名消课（已选 $count 人）", !submitting)
        } else {
            Triple(AppColors.SurfaceAlt, "一键点名消课", false)
        }
        val btnTextColor = when {
            schedule.isCompleted -> AppColors.Muted
            count > 0 -> Color.White
            else -> AppColors.Muted
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(40.dp)
                .clip(RoundedCornerShape(AppDimens.RadiusButton))
                .background(btnBg)
                .clickable(btnEnabled) { onSubmit() },
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = btnText,
                color = btnTextColor,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

// MARK: - 学员行

@Composable
private fun StudentRow(
    student: TeacherService.WorkbenchStudent,
    selected: Boolean,
    showDivider: Boolean,
    onTap: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onTap() }
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
                .padding(vertical = AppDimens.S),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // 头像（首字占位）
            TogetherAvatar(
                url = student.avatar,
                name = student.name,
                size = 34.dp
            )
            Spacer(modifier = Modifier.width(AppDimens.M))
            // 姓名
            val nameColor = when {
                student.isLeave -> AppColors.Muted
                student.isConsumed -> AppColors.Muted
                else -> AppColors.Ink
            }
            Text(
                text = student.name,
                fontSize = 14.sp,
                color = nameColor,
                modifier = Modifier.weight(1f)
            )
            // 状态文字
            val stateText = when {
                student.isLeave -> "请假"
                student.isConsumed -> "已消课"
                else -> "剩余 ${student.remaining} 节"
            }
            val stateColor = when {
                student.isLeave -> AppColors.Warn
                student.isConsumed -> AppColors.Muted
                else -> AppColors.Muted
            }
            Text(
                text = stateText,
                fontSize = 11.sp,
                color = stateColor
            )
            Spacer(modifier = Modifier.width(AppDimens.M))
            // 勾选图标
            when {
                student.isLeave -> { /* 请假不显示勾选 */ }
                student.isConsumed -> {
                    Icon(
                        Icons.Filled.CheckCircle,
                        contentDescription = "已消课",
                        tint = AppColors.SuccessTint,
                        modifier = Modifier.size(22.dp)
                    )
                }
                else -> {
                    Icon(
                        if (selected) Icons.Filled.CheckCircle else Icons.Outlined.Circle,
                        contentDescription = if (selected) "已选" else "未选",
                        tint = if (selected) AppColors.Brand else AppColors.Line,
                        modifier = Modifier.size(22.dp)
                    )
                }
            }
        }
        if (showDivider) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(0.5.dp)
                    .background(AppColors.Line)
            )
        }
    }
}