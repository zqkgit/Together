package com.together.app.modules.mine

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.together.app.services.CommissionService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * 领取记录 ViewModel（对齐 iOS CommissionWithdrawalsViewController + Detail）
 */
class CommissionWithdrawalsViewModel(app: Application) : AndroidViewModel(app) {

    // MARK: - 列表

    data class ListState(
        val rows: List<CommissionService.CommissionWithdrawal> = emptyList(),
        val loading: Boolean = false,
        val refreshing: Boolean = false,
        val loadingMore: Boolean = false,
        val hasMore: Boolean = false,
        val error: String? = null
    )

    private val _listState = MutableStateFlow(ListState())
    val listState: StateFlow<ListState> = _listState.asStateFlow()

    private var page = 1
    private val pageSize = 20

    private val _toast = MutableStateFlow<String?>(null)
    val toast: StateFlow<String?> = _toast.asStateFlow()

    fun clearToast() { _toast.value = null }

    fun loadList(reset: Boolean) {
        val s = _listState.value
        if (s.loading || s.loadingMore) return
        viewModelScope.launch {
            if (reset) {
                page = 1
                _listState.value = s.copy(loading = true, refreshing = s.rows.isNotEmpty(), error = null)
            } else {
                _listState.value = s.copy(loadingMore = true)
            }
            try {
                val (items, hasMore) = CommissionService.fetchWithdrawals(page, pageSize)
                val current = _listState.value
                _listState.value = current.copy(
                    rows = if (reset) items else current.rows + items,
                    loading = false,
                    refreshing = false,
                    loadingMore = false,
                    hasMore = hasMore,
                    error = null
                )
                page++
            } catch (e: Exception) {
                val current = _listState.value
                _listState.value = current.copy(
                    loading = false, refreshing = false, loadingMore = false,
                    error = if (reset && current.rows.isEmpty()) e.message else null
                )
                _toast.value = e.message ?: "加载失败"
            }
        }
    }

    // MARK: - 详情

    data class DetailState(
        val item: CommissionService.CommissionWithdrawal? = null,
        val loading: Boolean = false,
        val confirming: Boolean = false
    )

    private val _detailState = MutableStateFlow(DetailState())
    val detailState: StateFlow<DetailState> = _detailState.asStateFlow()

    fun loadDetail(id: String) {
        viewModelScope.launch {
            _detailState.value = _detailState.value.copy(loading = true)
            try {
                val item = CommissionService.fetchWithdrawalDetail(id)
                _detailState.value = DetailState(item = item, loading = false)
            } catch (e: Exception) {
                _detailState.value = _detailState.value.copy(loading = false)
                _toast.value = e.message ?: "加载失败"
            }
        }
    }

    /** 初始化详情（从缓存带入 item，再后台刷新） */
    fun initDetail(item: CommissionService.CommissionWithdrawal) {
        _detailState.value = DetailState(item = item, loading = false)
        item.withdrawId?.let { loadDetail(it) }
    }

    /** 推广人确认已收到佣金 */
    fun confirmWithdrawal(onDone: () -> Unit) {
        val item = _detailState.value.item ?: return
        val id = item.withdrawId ?: return
        viewModelScope.launch {
            _detailState.value = _detailState.value.copy(confirming = true)
            try {
                val latest = CommissionService.confirmWithdrawal(id)
                _detailState.value = DetailState(item = latest, loading = false, confirming = false)
                _toast.value = "已确认，佣金标记为到账"
                onDone()
            } catch (e: Exception) {
                _detailState.value = _detailState.value.copy(confirming = false)
                _toast.value = e.message ?: "确认失败"
            }
        }
    }
}