package com.together.app.modules.teacher.ui

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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.component.TogetherAvatar
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.services.TeacherService
import androidx.compose.runtime.collectAsState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter

/**
 * 排课详情（对齐 iOS ScheduleDetailViewController）
 * 排课信息卡（日期/时间/消课状态/课程·班级/地点）+ 学员消课列表（勾选消课/撤销消课）+ 底部操作栏
 */
class ScheduleDetailViewModel(app: android.app.Application) : AndroidViewModel(app) {

    companion object {
        /** 页面间传参：进入前设置排课项 */
        var schedule: TeacherService.TimetableItem? = null
    }

    data class State(
        val students: List<TeacherService.WorkbenchStudent> = emptyList(),
        val selectedIds: Set<String> = emptySet(),
        val loading: Boolean = false,
        val submitting: Boolean = false,
        val error: String? = null,
        val toast: String? = null
    )

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state.asStateFlow()

    /** 撤销确认弹窗 */
    data class UndoConfirm(
        val childId: String,
        val childName: String,
        val isPostSource: Boolean
    )

    private val _undoConfirm = MutableStateFlow<UndoConfirm?>(null)
    val undoConfirm: StateFlow<UndoConfirm?> = _undoConfirm.asStateFlow()

    fun clearToast() { _state.value = _state.value.copy(toast = null) }
    fun dismissUndoConfirm() { _undoConfirm.value = null }

    fun loadStudents() {
        val schedule = schedule ?: return
        val classId = schedule.classRef?.classId?.takeIf { it.isNotEmpty() } ?: return
        viewModelScope.launch {
            _state.value = _state.value.copy(loading = true, error = null)
            try {
                val list = TeacherService.fetchClassStudents(classId, schedule.scheduleId)
                _state.value = _state.value.copy(students = list, selectedIds = emptySet(), loading = false)
            } catch (e: Exception) {
                _state.value = _state.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    fun toggleStudent(childId: String) {
        val current = _state.value
        val set = current.selectedIds.toMutableSet()
        if (set.contains(childId)) set.remove(childId) else set.add(childId)
        _state.value = current.copy(selectedIds = set)
    }

    fun submitAttendance() {
        val schedule = schedule ?: return
        val ids = _state.value.selectedIds.toList()
        if (ids.isEmpty() || _state.value.submitting) return
        viewModelScope.launch {
            _state.value = _state.value.copy(submitting = true)
            try {
                TeacherService.submitAttendance(
                    scheduleId = schedule.scheduleId,
                    childIds = ids,
                    note = "老师排课详情点名消课"
                )
                _state.value = _state.value.copy(toast = "消课成功", submitting = false)
                loadStudents()
            } catch (e: Exception) {
                _state.value = _state.value.copy(toast = e.message ?: "消课失败", submitting = false)
            }
        }
    }

    fun requestUndo(student: TeacherService.WorkbenchStudent) {
        _undoConfirm.value = UndoConfirm(
            childId = student.childId,
            childName = student.name,
            isPostSource = student.consumeSource == 1
        )
    }

    fun confirmUndo() {
        val schedule = schedule ?: return
        val confirm = _undoConfirm.value ?: return
        viewModelScope.launch {
            try {
                TeacherService.undoAttendance(schedule.scheduleId, listOf(confirm.childId))
                _state.value = _state.value.copy(
                    toast = if (confirm.isPostSource) "已撤销，课时已退还，帖子消课记录已取消" else "已撤销消课"
                )
                _undoConfirm.value = null
                loadStudents()
            } catch (e: Exception) {
                _state.value = _state.value.copy(toast = e.message ?: "撤销失败")
                _undoConfirm.value = null
            }
        }
    }
}

@Composable
fun ScheduleDetailScreen(
    onBack: () -> Unit = {},
    viewModel: ScheduleDetailViewModel = viewModel()
) {
    val state by viewModel.state.collectAsState()
    val undoConfirm by viewModel.undoConfirm.collectAsState()
    val context = LocalContext.current
    val schedule = ScheduleDetailViewModel.schedule

    LaunchedEffect(Unit) {
        viewModel.loadStudents()
    }

    // Toast
    LaunchedEffect(state.toast) {
        state.toast?.let {
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
    ) {
        TogetherTopBar(title = "排课详情", onBack = onBack)

        if (schedule == null) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Text("排课信息缺失", color = AppColors.Muted, fontSize = 14.sp)
            }
            return
        }

        // 内容区
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .weight(1f),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(
                start = AppDimens.M,
                end = AppDimens.M,
                top = AppDimens.M,
                bottom = AppDimens.Xl
            ),
            verticalArrangement = Arrangement.spacedBy(AppDimens.M)
        ) {
            // 排课信息卡
            item {
                ScheduleHeaderCard(item = schedule)
            }
            // 学员消卡列表
            item {
                StudentListCard(
                    students = state.students,
                    selectedIds = state.selectedIds,
                    loading = state.loading,
                    error = state.error,
                    onToggle = { viewModel.toggleStudent(it) },
                    onUndo = { viewModel.requestUndo(it) },
                    onRetry = { viewModel.loadStudents() }
                )
            }
        }

        // 底部操作栏
        BottomActionBar(
            selectedCount = state.selectedIds.size,
            submitting = state.submitting,
            onSubmit = { viewModel.submitAttendance() }
        )
    }
}

// MARK: - 排课信息卡

@Composable
private fun ScheduleHeaderCard(item: TeacherService.TimetableItem) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.CardInner)
    ) {
        // 第一行：日期 + 状态标签
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = formatLessonDate(item.lessonDate),
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.Ink,
                modifier = Modifier.weight(1f)
            )
            val (statusColor, statusBg) = when (item.consumeStatus) {
                "completed" -> AppColors.Success to AppColors.SuccessTint
                "partial" -> AppColors.Brand to AppColors.BrandSoft
                else -> AppColors.Clay to AppColors.WarnTint
            }
            Text(
                text = item.consumeText,
                color = statusColor,
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier
                    .clip(RoundedCornerShape(10.dp))
                    .background(statusBg)
                    .padding(horizontal = AppDimens.S, vertical = AppDimens.Xs)
            )
        }
        // 第二行：时间 · 时长
        val timeText = listOfNotNull(item.startTime?.take(5), item.endTime?.take(5))
            .joinToString(" - ")
            .ifEmpty { "--:--" }
        val duration = item.course?.durationMin
        val timeFull = if (duration != null && duration > 0) "$timeText  ·  ${duration}分钟" else timeText
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = timeFull,
            fontSize = 13.sp,
            color = AppColors.Muted
        )
        // 第三行：课程 · 班级
        Spacer(modifier = Modifier.height(AppDimens.M))
        val courseTitle = item.course?.title ?: "课程"
        val className = item.classRef?.name ?: ""
        val titleText = if (className.isEmpty()) courseTitle else "$courseTitle · $className"
        Text(
            text = titleText,
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.Ink,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        // 第四行：地点
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = "地点：${item.location?.takeIf { it.isNotEmpty() } ?: "教室"}",
            fontSize = 11.sp,
            color = AppColors.Sub,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

/** "2026-10-14" → "10月14日 周三" */
private fun formatLessonDate(dateStr: String?): String {
    if (dateStr.isNullOrEmpty()) return "未排日期"
    return try {
        val date = LocalDate.parse(dateStr, DateTimeFormatter.ofPattern("yyyy-MM-dd"))
        val weekdays = listOf("周一", "周二", "周三", "周四", "周五", "周六", "周日")
        val weekday = weekdays[date.dayOfWeek.value - 1]
        date.format(DateTimeFormatter.ofPattern("MM月dd日")) + " $weekday"
    } catch (e: Exception) {
        dateStr
    }
}

// MARK: - 学员消卡列表

@Composable
private fun StudentListCard(
    students: List<TeacherService.WorkbenchStudent>,
    selectedIds: Set<String>,
    loading: Boolean,
    error: String?,
    onToggle: (String) -> Unit,
    onUndo: (TeacherService.WorkbenchStudent) -> Unit,
    onRetry: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.CardInner)
    ) {
        Text(
            text = if (students.isEmpty()) "学员消课" else "学员消课（${students.size}）",
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.Ink
        )
        Spacer(modifier = Modifier.height(AppDimens.S))

        when {
            loading -> {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(80.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text("加载中...", color = AppColors.Muted, fontSize = 13.sp)
                }
            }
            error != null -> {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = AppDimens.M),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(error, color = AppColors.Danger, fontSize = 13.sp)
                    Spacer(modifier = Modifier.height(AppDimens.S))
                    Text(
                        "点击重试",
                        color = AppColors.Brand,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.clickable { onRetry() }
                    )
                }
            }
            students.isEmpty() -> {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(60.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text("暂无学员", color = AppColors.Muted, fontSize = 13.sp)
                }
            }
            else -> {
                students.forEachIndexed { index, student ->
                    DetailStudentRow(
                        student = student,
                        selected = selectedIds.contains(student.childId),
                        showDivider = index < students.size - 1,
                        onTap = {
                            if (!student.isLeave) {
                                if (student.isConsumed) {
                                    onUndo(student)
                                } else {
                                    onToggle(student.childId)
                                }
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - 学员行

@Composable
private fun DetailStudentRow(
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
                .height(52.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            TogetherAvatar(
                url = student.avatar,
                name = student.name,
                size = 34.dp
            )
            Spacer(modifier = Modifier.width(AppDimens.M))
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
            val stateText = when {
                student.isLeave -> "请假"
                student.isConsumed -> "已消课"
                else -> "剩余 ${student.remaining} 节"
            }
            val stateColor = when {
                student.isLeave -> AppColors.Warn
                else -> AppColors.Muted
            }
            Text(
                text = stateText,
                fontSize = 11.sp,
                color = stateColor
            )
            Spacer(modifier = Modifier.width(AppDimens.M))
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

// MARK: - 底部操作栏

@Composable
private fun BottomActionBar(
    selectedCount: Int,
    submitting: Boolean,
    onSubmit: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M, vertical = AppDimens.S)
            .navigationBarsPadding()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.M)
            .height(56.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "已选 $selectedCount 人",
            fontSize = 13.sp,
            color = AppColors.Sub,
            modifier = Modifier.weight(1f)
        )
        val btnBg = if (selectedCount > 0) AppColors.Brand else AppColors.SurfaceAlt
        val btnText = if (selectedCount > 0) "消课 $selectedCount 人" else "请选择学员"
        val btnEnabled = selectedCount > 0 && !submitting
        val btnTextColor = if (selectedCount > 0) Color.White else AppColors.Muted
        Box(
            modifier = Modifier
                .width(120.dp)
                .height(38.dp)
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