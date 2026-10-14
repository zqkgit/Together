package com.together.app.modules.course

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.together.app.core.model.CourseStudySummary
import com.together.app.core.model.MyCourseItem
import com.together.app.services.CourseService
import com.together.app.services.CourseService.ChildBrief
import com.together.app.services.CourseService.MyLeaveItem
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/**
 * 我的课程 ViewModel（家长端：在学课程列表 + 课程学习详情）
 * 对齐 iOS MyCoursesViewController + CourseStudyViewController
 */
class MyCourseViewModel(app: Application) : AndroidViewModel(app) {

    // MARK: - 我的课程列表

    data class MyCoursesState(
        val loading: Boolean = false,
        val children: List<ChildBrief> = emptyList(),
        val allItems: List<MyCourseItem> = emptyList(),
        val selectedChildId: String? = null, // null = 全部
        val error: String? = null
    ) {
        val filteredItems: List<MyCourseItem>
            get() = if (selectedChildId != null) allItems.filter { it.childId == selectedChildId } else allItems
        val isMultiChild: Boolean get() = children.size > 1
    }

    private val _coursesState = MutableStateFlow(MyCoursesState())
    val coursesState: StateFlow<MyCoursesState> = _coursesState

    fun loadMyCourses(childId: String? = null) {
        viewModelScope.launch {
            _coursesState.value = _coursesState.value.copy(loading = true, error = null)
            try {
                val (children, items) = CourseService.fetchMyCourses(childId)
                _coursesState.value = MyCoursesState(
                    loading = false,
                    children = children,
                    allItems = items
                )
            } catch (e: Exception) {
                _coursesState.value = _coursesState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    fun selectChild(childId: String?) {
        _coursesState.value = _coursesState.value.copy(selectedChildId = childId)
    }

    // MARK: - 课程学习（课时进度）

    data class StudyState(
        val loading: Boolean = false,
        val summary: CourseStudySummary? = null,
        /** schedule_id → 我的请假单（仅当前孩子） */
        val leaveMap: Map<String, MyLeaveItem> = emptyMap(),
        val error: String? = null,
        val toast: String? = null
    )

    private val _studyState = MutableStateFlow(StudyState())
    val studyState: StateFlow<StudyState> = _studyState

    fun loadStudy(childId: String, courseId: String) {
        viewModelScope.launch {
            _studyState.value = _studyState.value.copy(loading = true, error = null)
            try {
                val summary = CourseService.fetchCourseSchedules(childId, courseId)
                _studyState.value = _studyState.value.copy(loading = false, summary = summary)
            } catch (e: Exception) {
                _studyState.value = _studyState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
        // 并行拉取请假单
        viewModelScope.launch {
            try {
                val leaves = CourseService.fetchMyLeaves()
                val rank = mapOf(0 to 0, 1 to 1, 2 to 2, 3 to 3)
                val map = mutableMapOf<String, MyLeaveItem>()
                for (item in leaves) {
                    val sid = item.scheduleId?.takeIf { it.isNotEmpty() } ?: continue
                    if (item.childId != null && item.childId != childId) continue
                    val old = map[sid]
                    if (old != null) {
                        val oldRank = rank[old.status ?: 9] ?: 9
                        val newRank = rank[item.status ?: 9] ?: 9
                        if (newRank >= oldRank) continue
                    }
                    map[sid] = item
                }
                _studyState.value = _studyState.value.copy(leaveMap = map)
            } catch (_: Exception) { }
        }
    }

    fun submitLeave(classId: String, childId: String, scheduleId: String, reason: String) {
        viewModelScope.launch {
            try {
                CourseService.submitLeave(classId, childId, scheduleId, reason)
                _studyState.value = _studyState.value.copy(toast = "请假已提交，等待老师审批")
                loadStudy(childId, _studyState.value.summary?.courseId ?: "")
            } catch (e: Exception) {
                _studyState.value = _studyState.value.copy(toast = e.message ?: "提交失败")
            }
        }
    }

    fun cancelLeave(leaveId: String, childId: String) {
        viewModelScope.launch {
            try {
                CourseService.cancelLeave(leaveId)
                _studyState.value = _studyState.value.copy(toast = "请假已撤销")
                loadStudy(childId, _studyState.value.summary?.courseId ?: "")
            } catch (e: Exception) {
                _studyState.value = _studyState.value.copy(toast = e.message ?: "撤销失败")
            }
        }
    }

    fun clearToast() {
        _studyState.value = _studyState.value.copy(toast = null)
    }
}