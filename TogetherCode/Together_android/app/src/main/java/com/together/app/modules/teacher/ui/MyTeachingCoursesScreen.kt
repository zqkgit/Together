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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
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
import com.together.app.modules.teacher.TeacherViewModel
import com.together.app.services.TeacherService

/**
 * 我教的课程：工作室筛选 + 课程卡片（班级人数 + 进度 + 操作）
 * 对齐 iOS MyTeachingCoursesViewController
 */
@Composable
fun MyTeachingCoursesScreen(
    viewModel: TeacherViewModel = viewModel(),
    onBack: () -> Unit = {},
    onViewTimetable: () -> Unit = {},
    onViewClassList: (TeacherService.CourseItem) -> Unit = {},
    onPublishConsume: () -> Unit = {}
) {
    val state by viewModel.coursesState.collectAsState()
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    LaunchedEffect(Unit) { viewModel.loadTeachingCourses() }
    androidx.compose.runtime.DisposableEffect(lifecycleOwner) {
        val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME && state.allItems.isNotEmpty()) {
                viewModel.loadTeachingCourses()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "我教的课程", onBack = onBack)

        // 工作室筛选
        if (state.studios.isNotEmpty()) {
            LazyRow(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = AppDimens.L, vertical = AppDimens.S),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                item {
                    StudioChip("全部工作室", state.selectedStudioId == null) {
                        viewModel.selectCourseStudio(null)
                    }
                }
                items(state.studios) { (id, name) ->
                    StudioChip(name, state.selectedStudioId == id) {
                        viewModel.selectCourseStudio(id)
                    }
                }
            }
        }

        Box(modifier = Modifier.weight(1f)) {
            when {
                state.loading && state.allItems.isEmpty() -> LoadingView()
                state.error != null && state.allItems.isEmpty() -> ErrorView(
                    message = state.error!!,
                    onRetry = { viewModel.loadTeachingCourses() }
                )
                state.filteredItems.isEmpty() -> EmptyStateView(message = "暂无教授课程")
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(
                        start = AppDimens.L, end = AppDimens.L,
                        top = AppDimens.S, bottom = AppDimens.Xl
                    ),
                    verticalArrangement = Arrangement.spacedBy(AppDimens.S)
                ) {
                    items(state.filteredItems, key = { it.courseId ?: "" }) { item ->
                        TeachingCourseCard(
                            item = item,
                            onViewTimetable = onViewTimetable,
                            onViewStudents = {
                                val classes = item.classes ?: emptyList()
                                if (classes.isEmpty()) {
                                    Toast.makeText(context, "暂无班级", Toast.LENGTH_SHORT).show()
                                } else {
                                    onViewClassList(item)
                                }
                            },
                            onPublishConsume = onPublishConsume
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun StudioChip(text: String, selected: Boolean, onClick: () -> Unit) {
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
private fun TeachingCourseCard(
    item: TeacherService.CourseItem,
    onViewTimetable: () -> Unit,
    onViewStudents: () -> Unit,
    onPublishConsume: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.CardInner, vertical = AppDimens.L)
    ) {
        // 行1：课程名 + 进度
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = item.title?.takeIf { it.isNotEmpty() } ?: "未命名课程",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.Ink
                )
                if (!item.studioName.isNullOrEmpty()) {
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(text = item.studioName!!, fontSize = 12.sp, color = AppColors.Muted)
                }
            }
            val progress = item.progress ?: 0
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(11.dp))
                    .background(AppColors.BrandSoft)
                    .padding(horizontal = 10.dp, vertical = 4.dp)
            ) {
                Text(text = "进度$progress%", fontSize = 12.sp, color = AppColors.Brand, fontWeight = FontWeight.Medium)
            }
        }

        // 行2：班级 + 人数
        val classCount = item.classes?.size ?: 0
        val studentCount = item.studentCount ?: 0
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "${classCount}个班级 · ${studentCount}名学员 · 已上${item.consumedLessons ?: 0}/${item.totalLessons ?: 0}节",
            fontSize = 13.sp,
            color = AppColors.Sub
        )

        // 行3：操作按钮
        Spacer(modifier = Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            ActionButton("查看课表", onViewTimetable)
            ActionButton("查看班级", onViewStudents)
            ActionButton("发作品消课", onPublishConsume)
        }
    }
}

@Composable
private fun ActionButton(text: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(16.dp))
            .background(AppColors.SurfaceAlt)
            .clickable { onClick() }
            .padding(horizontal = 12.dp, vertical = 6.dp)
    ) {
        Text(text = text, fontSize = 12.sp, color = AppColors.Sub)
    }
}