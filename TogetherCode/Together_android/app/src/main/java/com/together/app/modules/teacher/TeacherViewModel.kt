package com.together.app.modules.teacher

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.together.app.services.TeacherService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter

/**
 * 老师端 ViewModel：工作台 + 课表状态管理
 * 对齐 iOS TeacherWorkbenchViewController + TeacherTimetableViewController
 */
class TeacherViewModel(app: Application) : AndroidViewModel(app) {

    // MARK: - 工作台状态

    data class WorkbenchState(
        val stats: TeacherService.WorkbenchStats = TeacherService.WorkbenchStats(),
        val today: List<TeacherService.WorkbenchSchedule> = emptyList(),
        val loading: Boolean = false,
        val error: String? = null,
        /** 每节课已勾选的学员 child_id 集合 */
        val selectedBySchedule: Map<String, Set<String>> = emptyMap(),
        val submitting: Boolean = false
    )

    private val _workbenchState = MutableStateFlow(WorkbenchState())
    val workbenchState: StateFlow<WorkbenchState> = _workbenchState.asStateFlow()

    /** Toast 消息 */
    private val _toast = MutableStateFlow<String?>(null)
    val toast: StateFlow<String?> = _toast.asStateFlow()

    /** 撤销确认弹窗 */
    data class UndoConfirm(
        val schedule: TeacherService.WorkbenchSchedule,
        val childId: String,
        val childName: String,
        val isPostSource: Boolean
    )

    private val _undoConfirm = MutableStateFlow<UndoConfirm?>(null)
    val undoConfirm: StateFlow<UndoConfirm?> = _undoConfirm.asStateFlow()

    fun clearToast() { _toast.value = null }
    fun dismissUndoConfirm() { _undoConfirm.value = null }

    // MARK: - 工作台数据

    fun loadWorkbench() {
        viewModelScope.launch {
            _workbenchState.value = _workbenchState.value.copy(loading = true, error = null)
            try {
                val data = TeacherService.fetchWorkbench()
                _workbenchState.value = _workbenchState.value.copy(
                    stats = data.stats ?: TeacherService.WorkbenchStats(),
                    today = data.today ?: emptyList(),
                    selectedBySchedule = emptyMap(),
                    loading = false
                )
            } catch (e: Exception) {
                _workbenchState.value = _workbenchState.value.copy(
                    loading = false,
                    error = e.message ?: "加载失败"
                )
            }
        }
    }

    // MARK: - 学员勾选

    fun toggleStudent(scheduleId: String, childId: String) {
        val current = _workbenchState.value
        val set = current.selectedBySchedule[scheduleId]?.toMutableSet() ?: mutableSetOf()
        if (set.contains(childId)) set.remove(childId) else set.add(childId)
        _workbenchState.value = current.copy(
            selectedBySchedule = current.selectedBySchedule + (scheduleId to set)
        )
    }

    // MARK: - 点名消课

    fun submitAttendance(schedule: TeacherService.WorkbenchSchedule) {
        val ids = _workbenchState.value.selectedBySchedule[schedule.scheduleId]?.toList() ?: emptyList()
        if (ids.isEmpty() || _workbenchState.value.submitting) return
        viewModelScope.launch {
            _workbenchState.value = _workbenchState.value.copy(submitting = true)
            try {
                TeacherService.submitAttendance(
                    scheduleId = schedule.scheduleId,
                    childIds = ids,
                    note = "老师工作台点名消课"
                )
                _toast.value = "已消课 ${ids.size} 名学员"
                loadWorkbench()
            } catch (e: Exception) {
                _toast.value = e.message ?: "消课失败"
            } finally {
                _workbenchState.value = _workbenchState.value.copy(submitting = false)
            }
        }
    }

    // MARK: - 撤销消课

    /** 点击已消课学员 → 弹确认窗 */
    fun requestUndo(schedule: TeacherService.WorkbenchSchedule, childId: String) {
        val student = schedule.students?.find { it.childId == childId }
        val name = student?.name ?: "该学员"
        val isPostSource = student?.consumeSource == 1
        _undoConfirm.value = UndoConfirm(schedule, childId, name, isPostSource)
    }

    /** 确认撤销 */
    fun confirmUndo() {
        val confirm = _undoConfirm.value ?: return
        viewModelScope.launch {
            try {
                TeacherService.undoAttendance(confirm.schedule.scheduleId, listOf(confirm.childId))
                _toast.value = if (confirm.isPostSource) {
                    "已撤销，课时已退还，帖子消课记录已取消"
                } else {
                    "已撤销消课，课时已退还"
                }
                _undoConfirm.value = null
                loadWorkbench()
            } catch (e: Exception) {
                _toast.value = e.message ?: "撤销失败"
                _undoConfirm.value = null
            }
        }
    }

    // MARK: - 课表状态

    data class TimetableState(
        val selectedDate: LocalDate = LocalDate.now(),
        val items: List<TeacherService.TimetableItem> = emptyList(),
        val loading: Boolean = false,
        val error: String? = null
    )

    private val _timetableState = MutableStateFlow(TimetableState())
    val timetableState: StateFlow<TimetableState> = _timetableState.asStateFlow()

    private val dateFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")

    /** 当前选中日期（YYYY-MM-dd） */
    val selectedDateString: String get() = _timetableState.value.selectedDate.format(dateFormatter)

    fun loadTimetable() {
        viewModelScope.launch {
            _timetableState.value = _timetableState.value.copy(loading = true, error = null)
            try {
                val list = TeacherService.fetchTimetable(date = selectedDateString)
                _timetableState.value = _timetableState.value.copy(items = list, loading = false)
            } catch (e: Exception) {
                _timetableState.value = _timetableState.value.copy(
                    items = emptyList(),
                    loading = false,
                    error = e.message ?: "加载失败"
                )
            }
        }
    }

    fun selectDate(date: LocalDate) {
        _timetableState.value = _timetableState.value.copy(selectedDate = date)
        loadTimetable()
    }
}