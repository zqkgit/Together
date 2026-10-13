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
 * 日期范围预设（对齐 iOS DateRangePreset）
 */
enum class DateRangePreset(val title: String) {
    ThisMonth("本月"),
    LastMonth("上月"),
    Last3Months("近3月"),
    Custom("自定义");

    /** 返回 (startDate, endDate)，格式 yyyy-MM-dd */
    fun dates(): Pair<String, String> {
        val fmt = java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-dd")
        val now = java.time.LocalDate.now()
        return when (this) {
            ThisMonth -> {
                val start = now.withDayOfMonth(1)
                val end = start.plusMonths(1).minusDays(1)
                start.format(fmt) to end.format(fmt)
            }
            LastMonth -> {
                val thisMonthStart = now.withDayOfMonth(1)
                val start = thisMonthStart.minusMonths(1)
                val end = thisMonthStart.minusDays(1)
                start.format(fmt) to end.format(fmt)
            }
            Last3Months -> {
                val thisMonthStart = now.withDayOfMonth(1)
                val start = thisMonthStart.minusMonths(3)
                val end = thisMonthStart.minusDays(1)
                start.format(fmt) to end.format(fmt)
            }
            Custom -> ThisMonth.dates()
        }
    }
}

/**
 * 佣金页面间传递复杂数据的临时缓存（Compose Navigation 不支持对象参数）
 */
object CommissionNavCache {
    var studioGroup: CommissionService.StudioGroup? = null
    var withdrawal: CommissionService.CommissionWithdrawal? = null
}

/**
 * 收益中心 ViewModel（对齐 iOS WalletViewController）
 * 佣金总览 + 按工作室分组 + 日期筛选 + 一键领取
 */
class WalletViewModel(app: Application) : AndroidViewModel(app) {

    data class WalletState(
        val summary: CommissionService.CommissionSummary? = null,
        val loading: Boolean = false,
        val refreshing: Boolean = false,
        val error: String? = null,
        val selectedPreset: DateRangePreset = DateRangePreset.ThisMonth,
        val startDate: String = DateRangePreset.ThisMonth.dates().first,
        val endDate: String = DateRangePreset.ThisMonth.dates().second
    )

    private val _state = MutableStateFlow(WalletState())
    val state: StateFlow<WalletState> = _state.asStateFlow()

    private val _toast = MutableStateFlow<String?>(null)
    val toast: StateFlow<String?> = _toast.asStateFlow()

    /** 领取成功后跳详情 */
    private val _navigateToDetail = MutableSharedFlow<CommissionService.CommissionWithdrawal>(extraBufferCapacity = 1)
    val navigateToDetail: SharedFlow<CommissionService.CommissionWithdrawal> = _navigateToDetail.asSharedFlow()

    /** 收款方式弹窗：非 null 时显示，值为 studioId */
    private val _showPayMethodSheet = MutableStateFlow<String?>(null)
    val showPayMethodSheet: StateFlow<String?> = _showPayMethodSheet.asStateFlow()

    /** 提交中遮罩 */
    private val _submitting = MutableStateFlow(false)
    val submitting: StateFlow<Boolean> = _submitting.asStateFlow()

    fun clearToast() { _toast.value = null }
    fun dismissPayMethodSheet() { _showPayMethodSheet.value = null }

    /** 加载收益总览 */
    fun refresh(silent: Boolean = false) {
        val s = _state.value
        viewModelScope.launch {
            if (silent) _state.value = s.copy(refreshing = true)
            else _state.value = s.copy(loading = true, error = null)
            try {
                val summary = CommissionService.fetchSummary(s.startDate, s.endDate)
                _state.value = _state.value.copy(summary = summary, loading = false, refreshing = false, error = null)
            } catch (e: Exception) {
                _state.value = _state.value.copy(loading = false, refreshing = false, error = e.message)
                if (!silent) _toast.value = e.message ?: "加载失败"
            }
        }
    }

    /** 切换预设时间范围 */
    fun selectPreset(preset: DateRangePreset) {
        val (s, e) = preset.dates()
        _state.value = _state.value.copy(selectedPreset = preset, startDate = s, endDate = e)
        refresh(silent = false)
    }

    /** 自定义日期范围 */
    fun selectCustomRange(start: String, end: String) {
        _state.value = _state.value.copy(selectedPreset = DateRangePreset.Custom, startDate = start, endDate = end)
        refresh(silent = false)
    }

    /** 点击一键领取 → 弹出收款方式选择 */
    fun requestWithdrawSheet(studioId: String) {
        _showPayMethodSheet.value = studioId
    }

    /** 选定收款方式 → 发起领取（对齐 iOS startCommissionWithdraw） */
    fun confirmWithdraw(method: String) {
        val studioId = _showPayMethodSheet.value ?: return
        _showPayMethodSheet.value = null
        viewModelScope.launch {
            _submitting.value = true
            try {
                val item = CommissionService.requestWithdraw(studioId, method)
                _submitting.value = false
                _toast.value = "领取申请已提交，等待工作室打款"
                refresh(silent = true)
                _navigateToDetail.tryEmit(item)
            } catch (e: Exception) {
                _submitting.value = false
                _toast.value = e.message ?: "提交失败"
            }
        }
    }
}