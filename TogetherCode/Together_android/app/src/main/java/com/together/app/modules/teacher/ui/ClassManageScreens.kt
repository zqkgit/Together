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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
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

// ============================================================
// 班级列表（对齐 iOS ClassListViewController）
// 静态数据：课程下的所有班级，点击进入班级学生
// ============================================================

object ClassListData {
    var courseTitle: String = ""
    var classes: List<TeacherService.CourseClassItem> = emptyList()
}

@Composable
fun ClassListScreen(
    onBack: () -> Unit = {},
    onClassClick: (TeacherService.CourseClassItem) -> Unit = {}
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
    ) {
        TogetherTopBar(title = "班级列表", onBack = onBack)

        if (ClassListData.classes.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Text("暂无班级", color = AppColors.Muted, fontSize = 14.sp)
            }
            return
        }

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
            items(ClassListData.classes.size) { index ->
                val cls = ClassListData.classes[index]
                ClassRow(
                    name = cls.name ?: "未命名班级",
                    count = cls.studentCount ?: 0,
                    onClick = { onClassClick(cls) }
                )
            }
        }
    }
}

@Composable
private fun ClassRow(name: String, count: Int, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable { onClick() }
            .padding(horizontal = AppDimens.L, vertical = AppDimens.M),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = name,
            fontSize = 15.sp,
            color = AppColors.Ink,
            modifier = Modifier.weight(1f)
        )
        Text(
            text = "${count}人",
            fontSize = 13.sp,
            color = AppColors.Muted
        )
        Spacer(modifier = Modifier.width(AppDimens.S))
        Icon(
            Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = AppColors.Muted,
            modifier = Modifier.size(18.dp)
        )
    }
}

// ============================================================
// 班级学生列表（对齐 iOS ClassStudentsViewController）
// 班级维度：学生 + 剩余课时（无排课上下文）
// ============================================================

object ClassStudentsData {
    var classId: String = ""
    var className: String = ""
}

class ClassStudentsViewModel(app: android.app.Application) : AndroidViewModel(app) {

    data class State(
        val students: List<TeacherService.WorkbenchStudent> = emptyList(),
        val loading: Boolean = false,
        val error: String? = null
    )

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state.asStateFlow()

    fun load() {
        val classId = ClassStudentsData.classId.takeIf { it.isNotEmpty() } ?: return
        viewModelScope.launch {
            _state.value = _state.value.copy(loading = true, error = null)
            try {
                val list = TeacherService.fetchClassStudents(classId)
                _state.value = _state.value.copy(students = list, loading = false)
            } catch (e: Exception) {
                _state.value = _state.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }
}

@Composable
fun ClassStudentsScreen(
    onBack: () -> Unit = {},
    viewModel: ClassStudentsViewModel = viewModel()
) {
    val state by viewModel.state.collectAsState()
    val context = LocalContext.current

    LaunchedEffect(Unit) { viewModel.load() }

    LaunchedEffect(state.error) {
        state.error?.let {
            Toast.makeText(context, it, Toast.LENGTH_SHORT).show()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
    ) {
        TogetherTopBar(title = ClassStudentsData.className.ifEmpty { "班级学生" }, onBack = onBack)

        when {
            state.loading -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text("加载中...", color = AppColors.Muted, fontSize = 14.sp)
                }
            }
            state.students.isEmpty() -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text("暂无学员", color = AppColors.Muted, fontSize = 14.sp)
                }
            }
            else -> {
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
                    items(state.students.size) { index ->
                        ClassStudentRow(student = state.students[index])
                    }
                }
            }
        }
    }
}

@Composable
private fun ClassStudentRow(student: TeacherService.WorkbenchStudent) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.M, vertical = AppDimens.M),
        verticalAlignment = Alignment.CenterVertically
    ) {
        TogetherAvatar(
            url = student.avatar,
            name = student.name,
            size = 40.dp
        )
        Spacer(modifier = Modifier.width(AppDimens.M))
        Text(
            text = student.name,
            fontSize = 15.sp,
            color = AppColors.Ink,
            modifier = Modifier.weight(1f)
        )
        Text(
            text = "剩余${student.remaining}课时",
            fontSize = 13.sp,
            color = AppColors.Muted
        )
    }
}