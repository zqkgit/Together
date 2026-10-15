package com.together.app.modules.course.ui

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import com.together.app.core.component.AppPullRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.component.EmptyStateView
import com.together.app.core.component.ErrorView
import com.together.app.core.component.LoadingView
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.CourseScheduleItem
import com.together.app.services.CourseService.MyLeaveItem
import com.together.app.modules.course.MyCourseViewModel

/**
 * 课程学习（课时进度详情 + 请假）
 * 对齐 iOS CourseStudyViewController
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CourseStudyScreen(
    childId: String,
    courseId: String,
    courseTitle: String = "课程学习",
    viewModel: MyCourseViewModel = viewModel(),
    onBack: () -> Unit = {}
) {
    val state by viewModel.studyState.collectAsState()
    val context = LocalContext.current

    var leaveTarget by remember { mutableStateOf<CourseScheduleItem?>(null) }
    var leaveReason by remember { mutableStateOf("") }
    var cancelTarget by remember { mutableStateOf<MyLeaveItem?>(null) }

    LaunchedEffect(childId, courseId) {
        viewModel.loadStudy(childId, courseId)
    }

    // Toast
    LaunchedEffect(state.toast) {
        state.toast?.let {
            Toast.makeText(context, it, Toast.LENGTH_SHORT).show()
            viewModel.clearToast()
        }
    }

    val summary = state.summary
    val schedules = summary?.list ?: emptyList()

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "课程学习", onBack = onBack)

        Box(modifier = Modifier.weight(1f)) {
            when {
                state.loading && summary == null -> LoadingView()
                state.error != null && summary == null -> ErrorView(
                    message = state.error!!,
                    onRetry = { viewModel.loadStudy(childId, courseId) }
                )
                schedules.isEmpty() -> EmptyStateView(message = "暂无课时安排")
                else -> AppPullRefreshBox(
                    isRefreshing = state.loading,
                    onRefresh = { viewModel.loadStudy(childId, courseId) },
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
                        verticalArrangement = Arrangement.spacedBy(AppDimens.Xs)
                    ) {
                        // 头部卡
                        item {
                            StudyHeaderCard(
                                title = summary?.courseTitle?.takeIf { it.isNotEmpty() } ?: courseTitle,
                                subtitle = summary?.studioTeacherText ?: "",
                                consumed = summary?.consumedLessons ?: 0,
                                total = summary?.totalLessons ?: 0
                            )
                        }
                        // 课时列表
                        items(schedules, key = { it.scheduleId ?: "${it.lessonNo}" }) { item ->
                            val leave = state.leaveMap[item.scheduleId ?: ""]
                            ScheduleCard(
                                item = item,
                                leave = leave,
                                onLeave = { leaveTarget = item },
                                onCancelLeave = { cancelTarget = leave }
                            )
                        }
                    }
                }
            }
        }
    }

    // 请假弹窗
    leaveTarget?.let { target ->
        AlertDialog(
            onDismissRequest = { leaveTarget = null; leaveReason = "" },
            title = { Text("请假申请", fontWeight = FontWeight.SemiBold) },
            text = {
                OutlinedTextField(
                    value = leaveReason,
                    onValueChange = { if (it.length <= 100) leaveReason = it },
                    placeholder = { Text("请输入请假事由") },
                    modifier = Modifier.fillMaxWidth()
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        val classId = target.classId ?: summary?.classId ?: ""
                        if (classId.isEmpty()) {
                            Toast.makeText(context, "未找到班级信息，暂时无法请假", Toast.LENGTH_SHORT).show()
                            return@TextButton
                        }
                        viewModel.submitLeave(classId, childId, target.scheduleId ?: "", leaveReason)
                        leaveTarget = null
                        leaveReason = ""
                    }
                ) { Text("提交", color = AppColors.Brand) }
            },
            dismissButton = {
                TextButton(onClick = { leaveTarget = null; leaveReason = "" }) {
                    Text("取消", color = AppColors.Muted)
                }
            }
        )
    }

    // 撤销请假确认
    cancelTarget?.let { target ->
        AlertDialog(
            onDismissRequest = { cancelTarget = null },
            title = { Text("撤销请假", fontWeight = FontWeight.SemiBold) },
            text = { Text("确定撤销这条请假申请吗？撤销后老师不再审批。") },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.cancelLeave(target.leaveId ?: "", childId)
                    cancelTarget = null
                }) { Text("撤销", color = AppColors.Clay) }
            },
            dismissButton = {
                TextButton(onClick = { cancelTarget = null }) {
                    Text("再想想", color = AppColors.Muted)
                }
            }
        )
    }
}

// MARK: - 头部卡

@Composable
private fun StudyHeaderCard(title: String, subtitle: String, consumed: Int, total: Int) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.CardInner, vertical = AppDimens.L),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.Ink
            )
            if (subtitle.isNotEmpty()) {
                Spacer(modifier = Modifier.height(4.dp))
                Text(text = subtitle, fontSize = 13.sp, color = AppColors.Sub)
            }
        }
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(12.dp))
                .background(AppColors.BrandSoft)
                .padding(horizontal = 12.dp, vertical = 6.dp)
        ) {
            Text(
                text = "已学${consumed}/${total}节",
                fontSize = 12.sp,
                color = AppColors.Brand,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

// MARK: - 课时卡

@Composable
private fun ScheduleCard(
    item: CourseScheduleItem,
    leave: MyLeaveItem?,
    onLeave: () -> Unit,
    onCancelLeave: () -> Unit
) {
    // 待排课：虚线卡
    if (item.status == 3) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(AppDimens.RadiusCard))
                .background(AppColors.Surface)
                .border(1.dp, AppColors.Line, RoundedCornerShape(AppDimens.RadiusCard))
                .padding(horizontal = AppDimens.CardInner, vertical = AppDimens.L)
        ) {
            Text(text = item.titleText, fontSize = 15.sp, color = AppColors.Sub, fontWeight = FontWeight.Medium)
            Spacer(modifier = Modifier.height(4.dp))
            Text(text = "待排课", fontSize = 13.sp, color = AppColors.Sub)
        }
        return
    }

    val leaveStatus = leave?.status?.plus(1) ?: item.leaveStatus
    val canCancel = leaveStatus == 1 && !leave?.leaveId.isNullOrEmpty()
    val canLeave = !canCancel && (item.status == 0 || item.status == 2) &&
        (leaveStatus == 0 || leaveStatus == 3 || leaveStatus == 4)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.CardInner, vertical = AppDimens.L)
    ) {
        // 行1：标题
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = item.titleText,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = AppColors.Ink,
                modifier = Modifier.weight(1f)
            )
            StatusPill(item, leaveStatus)
        }

        // 行2：日期 + 时间 + 操作按钮
        Spacer(modifier = Modifier.height(5.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (canCancel) {
                ActionPill("撤销请假", AppColors.WarnTint, AppColors.Clay, onCancelLeave)
                Spacer(modifier = Modifier.width(8.dp))
            } else if (canLeave) {
                ActionPill("请假", AppColors.WarnTint, AppColors.Clay, onLeave)
                Spacer(modifier = Modifier.width(8.dp))
            }
            Text(text = item.dateText, fontSize = 13.sp, color = AppColors.Sub)
            if (item.timeText.isNotEmpty()) {
                Spacer(modifier = Modifier.width(8.dp))
                Text(text = item.timeText, fontSize = 13.sp, color = AppColors.Sub)
            }
        }

        // 行3：补课信息（已同意请假且有补课安排时）
        val makeupText = makeupTextFor(leave)
        if (makeupText != null) {
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = makeupText,
                fontSize = 12.sp,
                color = AppColors.Clay,
                maxLines = 1
            )
        }
    }
}

/** 已同意请假单的补课展示文本 */
private fun makeupTextFor(leave: MyLeaveItem?): String? {
    if (leave == null || leave.status != 1) return null
    val makeupStatus = leave.makeupStatus ?: 0
    if (makeupStatus == 1) return "补课已完成 · 课时已消耗"
    if (makeupStatus == 2) return "已放弃补课"
    val ms = leave.makeupSchedule ?: return null
    val date = ms.lessonDate?.takeIf { it.isNotEmpty() } ?: return null
    val time = listOfNotNull(ms.startTime, ms.endTime).joinToString("-")
    val loc = ms.location ?: ""
    var text = "补课：${date.take(10).let { if (it.length >= 10) it.substring(5) else it }}"
    if (time.isNotEmpty()) text += " $time"
    if (loc.isNotEmpty()) text += " · $loc"
    return text
}

@Composable
private fun StatusPill(item: CourseScheduleItem, leaveStatus: Int) {
    val (text, fg, bg) = when {
        leaveStatus == 1 -> Triple("请假中", AppColors.Clay, AppColors.WarnTint)
        leaveStatus == 2 -> Triple("已请假", AppColors.Brand, AppColors.BrandSoft)
        item.status == 1 -> Triple("已上", AppColors.Brand, AppColors.BrandSoft)
        item.status == 2 -> Triple("今天", AppColors.BrandDark, AppColors.BrandSoft)
        else -> Triple("待上", AppColors.Sub, AppColors.SurfaceAlt)
    }
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(11.dp))
            .background(bg)
            .padding(horizontal = 12.dp, vertical = 4.dp)
    ) {
        Text(text = text, fontSize = 12.sp, color = fg, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun ActionPill(text: String, bg: androidx.compose.ui.graphics.Color, fg: androidx.compose.ui.graphics.Color, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(bg)
            .clickable { onClick() }
            .padding(horizontal = 12.dp, vertical = 5.dp)
    ) {
        Text(text = text, fontSize = 12.sp, color = fg)
    }
}