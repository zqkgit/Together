package com.together.app.modules.mine

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.together.app.services.CommissionService
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * 工作室佣金详情 ViewModel（对齐 iOS StudioCommissionDetailViewController）
 * 按课程维度展示佣金明细 + 一键领取
 */
class StudioCommissionDetailViewModel(app: Application) : AndroidViewModel(app) {

    /** 按课程聚合 */
    data class CourseGroup(
        val course: CommissionService.CourseBrief?,
        val items: List<CommissionService.CommissionRecordItem>
    ) {
        val count: Int get() = items.size
        val total: Double get() = items.sumOf { it.amount ?: 0.0 }
    }

    data class State(
        val groups: List<CourseGroup> = emptyList(),
        val loading: Boolean = false,
        val refreshing: Boolean = false,
        val error: String? = null
    )

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state.asStateFlow()

    private val _toast = MutableStateFlow<String?>(null)
    val toast: StateFlow<String?> = _toast.asStateFlow()

    /** 收款方式弹窗 */
    private val _showPayMethodSheet = MutableStateFlow(false)
    val showPayMethodSheet: StateFlow<Boolean> = _showPayMethodSheet.asStateFlow()

    /** 领取成功后跳详情 */
    private val _navigateToDetail = MutableSharedFlow<CommissionService.CommissionWithdrawal>(extraBufferCapacity = 1)
    val navigateToDetail: SharedFlow<CommissionService.CommissionWithdrawal> = _navigateToDetail.asSharedFlow()

    private val _submitting = MutableStateFlow(false)
    val submitting: StateFlow<Boolean> = _submitting.asStateFlow()

    fun clearToast() { _toast.value = null }
    fun dismissPayMethodSheet() { _showPayMethodSheet.value = false }
    fun requestWithdrawSheet() { _showPayMethodSheet.value = true }

    /** 加载佣金明细并按课程分组 */
    fun loadRecords(studioId: String?, silent: Boolean = false) {
        if (studioId.isNullOrBlank()) return
        viewModelScope.launch {
            if (silent) _state.value = _state.value.copy(refreshing = true)
            else _state.value = _state.value.copy(loading = true, error = null)
            try {
                val records = CommissionService.fetchRecords(studioId)
                // 按 courseId 分组，保持原始顺序
                val order = mutableListOf<String>()
                val map = mutableMapOf<String, MutableList<CommissionService.CommissionRecordItem>>()
                for (item in records) {
                    val cid = item.course?.courseId ?: "unknown"
                    if (cid !in map) {
                        map[cid] = mutableListOf()
                        order.add(cid)
                    }
                    map[cid]?.add(item)
                }
                val groups = order.map { cid ->
                    CourseGroup(course = map[cid]?.firstOrNull()?.course, items = map[cid] ?: emptyList())
                }
                _state.value = State(groups = groups, loading = false, refreshing = false)
            } catch (e: Exception) {
                _state.value = _state.value.copy(loading = false, refreshing = false, error = e.message)
                if (!silent) _toast.value = e.message ?: "加载失败"
            }
        }
    }

    /** 选定收款方式 → 发起领取 */
    fun confirmWithdraw(studioId: String, method: String) {
        _showPayMethodSheet.value = false
        viewModelScope.launch {
            _submitting.value = true
            try {
                val item = CommissionService.requestWithdraw(studioId, method)
                _submitting.value = false
                _toast.value = "领取申请已提交，等待工作室打款"
                _navigateToDetail.tryEmit(item)
            } catch (e: Exception) {
                _submitting.value = false
                _toast.value = e.message ?: "提交失败"
            }
        }
    }
}