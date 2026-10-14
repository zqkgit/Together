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
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
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
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.teacher.TeacherViewModel
import com.together.app.services.TeacherService
import androidx.compose.runtime.collectAsState
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale

/**
 * 老师课表（对齐 iOS TeacherTimetableViewController）
 * 顶部：周切换（周一~周日，选中日绿色高亮）
 * 列表：当天排课（时间 / 课程·班级 / 教室·学生数 / 消课状态标签）
 * 仅查看：不提供新增排课入口
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TeacherTimetableScreen(
    onBack: () -> Unit = {},
    viewModel: TeacherViewModel = viewModel()
) {
    val state by viewModel.timetableState.collectAsState()
    val context = LocalContext.current

    // 进入页面加载当天课表
    LaunchedEffect(Unit) {
        viewModel.loadTimetable()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
    ) {
        TogetherTopBar(title = "课表与排课", onBack = onBack)

        // 周切换栏
        WeekDayBar(
            selectedDate = state.selectedDate,
            onSelectDate = { viewModel.selectDate(it) }
        )

        // 排课列表
        PullToRefreshBox(
            isRefreshing = state.loading,
            onRefresh = { viewModel.loadTimetable() },
            modifier = Modifier.fillMaxSize()
        ) {
            if (state.items.isEmpty() && !state.loading) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        "当天没有排课，休息一下吧",
                        color = AppColors.Muted,
                        fontSize = 14.sp
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(
                        start = AppDimens.M,
                        end = AppDimens.M,
                        top = AppDimens.S,
                        bottom = AppDimens.Xl
                    ),
                    verticalArrangement = Arrangement.spacedBy(AppDimens.S)
                ) {
                    items(state.items.size) { index ->
                        TimetableCard(item = state.items[index])
                    }
                }
            }
        }
    }
}

// MARK: - 周切换栏

@Composable
private fun WeekDayBar(
    selectedDate: LocalDate,
    onSelectDate: (LocalDate) -> Unit
) {
    val today = LocalDate.now()
    // 当前周的周一~周日
    val monday = today.with(DayOfWeek.MONDAY)
    val weekDays = (0..6).map { monday.plusDays(it.toLong()) }

    val weekdayNames = listOf("周一", "周二", "周三", "周四", "周五", "周六", "周日")

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(88.dp)
            .padding(horizontal = AppDimens.M),
        horizontalArrangement = Arrangement.spacedBy(0.dp)
    ) {
        weekDays.forEachIndexed { index, day ->
            val isSelected = day == selectedDate
            Column(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxSize()
                    .clickable { onSelectDate(day) },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Text(
                    text = weekdayNames[index],
                    fontSize = 12.sp,
                    color = if (isSelected) AppColors.Brand else AppColors.Muted
                )
                Spacer(modifier = Modifier.height(AppDimens.Xs))
                Box(
                    modifier = Modifier
                        .size(30.dp)
                        .clip(CircleShape)
                        .background(if (isSelected) AppColors.Brand else Color.Transparent),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "${day.dayOfMonth}",
                        fontSize = 15.sp,
                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                        color = if (isSelected) Color.White else AppColors.Ink
                    )
                }
            }
        }
    }
}

// MARK: - 排课卡

@Composable
private fun TimetableCard(item: TeacherService.TimetableItem) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.M),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // 左：时间
        Column(
            modifier = Modifier.width(56.dp),
            horizontalAlignment = Alignment.Start
        ) {
            Text(
                text = item.startTime?.take(5)?.ifEmpty { "--:--" } ?: "--:--",
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.Ink
            )
            Spacer(modifier = Modifier.height(AppDimens.Xs))
            Text(
                text = "${item.course?.durationMin ?: 60}分钟",
                fontSize = 11.sp,
                color = AppColors.Muted
            )
        }
        // 中：课程·班级 / 教室·学生
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = AppDimens.M),
            verticalArrangement = Arrangement.spacedBy(AppDimens.Xs)
        ) {
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
            val location = item.location ?: "教室"
            val studentCount = item.studentCount ?: 0
            val studio = item.studioName?.takeIf { it.isNotEmpty() }?.let { "$it · " } ?: ""
            Text(
                text = "$studio$location · ${studentCount}名学生",
                fontSize = 11.sp,
                color = AppColors.Sub,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        // 右：状态标签
        val (statusColor, statusBg) = when (item.consumeStatus) {
            "completed" -> AppColors.Success to AppColors.SuccessTint
            "partial" -> AppColors.Warn to AppColors.WarnTint
            else -> AppColors.Muted to AppColors.SurfaceAlt
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
}