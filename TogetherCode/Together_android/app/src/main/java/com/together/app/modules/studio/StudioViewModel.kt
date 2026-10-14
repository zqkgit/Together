package com.together.app.modules.studio

import android.app.Application
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.together.app.core.network.ApiService
import com.together.app.core.network.JsonHelper.strList
import com.together.app.services.CommissionService
import com.together.app.services.StudioService
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import java.io.File

/**
 * 工作室模块 ViewModel（对齐 iOS 工作室各 ViewController 的状态管理）
 *
 * 覆盖页面：
 * - 经营概览（营收卡 + 三统计 + 待办 + 机构动态）
 * - 工作室我的（机构资料 + 统计 + 菜单）
 * - 退款审核（4 Tab + 审核/确认操作）
 * - 待办中心（3 行入口）
 * - 订单列表（筛选 + 搜索 + 分页）
 * - 订单详情（确认收款 / 驳回 / 取消）
 * - 老师列表（搜索 + 邀请）
 * - 老师详情（解除合作）
 * - 老师合作申请（4 Tab + 审批）
 * - 学员列表（3 筛选 + 搜索）
 * - 学员详情（余额 + 流水）
 * - 佣金审核（4 Tab + 审批打款）
 * - 财务对账（营收概览 + 明细）
 * - 课程管理（3 Tab + 上下架）
 */
class StudioViewModel(app: Application) : AndroidViewModel(app) {

    companion object {
        /** 页面间传递对象（Navigation Compose 不支持复杂对象参数） */
        var navRefund: StudioService.StudioRefund? = null
        var navOrder: StudioService.StudioOrder? = null
        var navTeacher: StudioService.StudioTeacherItem? = null
        var navStudent: StudioService.StudioStudentItem? = null
        var navCommission: CommissionService.CommissionWithdrawal? = null
    }

    // Toast 事件流
    private val _toast = MutableSharedFlow<String>()
    val toast: SharedFlow<String> = _toast

    private fun showToast(msg: String) {
        viewModelScope.launch { _toast.emit(msg) }
    }

    // MARK: - 经营概览

    data class OverviewState(
        val loading: Boolean = true,
        val data: StudioService.StudioOverviewData? = null,
        val error: String? = null
    )

    private val _overviewState = MutableStateFlow(OverviewState())
    val overviewState: StateFlow<OverviewState> = _overviewState

    fun loadOverview() {
        viewModelScope.launch {
            _overviewState.value = _overviewState.value.copy(loading = true, error = null)
            try {
                val data = StudioService.fetchOverview()
                _overviewState.value = _overviewState.value.copy(loading = false, data = data)
            } catch (e: Exception) {
                _overviewState.value = _overviewState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    // MARK: - 工作室我的

    data class MineState(
        val loading: Boolean = true,
        val profile: StudioService.StudioMineProfile? = null,
        val stats: StudioService.StudioMineStats? = null,
        val error: String? = null
    )

    private val _mineState = MutableStateFlow(MineState())
    val mineState: StateFlow<MineState> = _mineState

    fun loadMine() {
        viewModelScope.launch {
            _mineState.value = _mineState.value.copy(loading = true, error = null)
            try {
                val data = StudioService.fetchMine()
                _mineState.value = _mineState.value.copy(
                    loading = false,
                    profile = data.profile,
                    stats = data.stats
                )
            } catch (e: Exception) {
                _mineState.value = _mineState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    // MARK: - 退款审核

    enum class RefundTab(val title: String, val status: Int, val emptyText: String) {
        PENDING("待审核", 0, "暂无待审核退款"),
        CONFIRM("待确认", 1, "暂无待确认退款"),
        REJECTED("已驳回", 2, "暂无已驳回退款"),
        REFUNDED("已退款", 3, "暂无已退款记录");

        companion object {
            fun from(status: Int) = entries.firstOrNull { it.status == status } ?: PENDING
        }
    }

    data class RefundState(
        val loading: Boolean = true,
        val selectedTab: RefundTab = RefundTab.PENDING,
        val refunds: List<StudioService.StudioRefund> = emptyList(),
        val error: String? = null,
        val submitting: Boolean = false
    )

    private val _refundState = MutableStateFlow(RefundState())
    val refundState: StateFlow<RefundState> = _refundState

    fun selectRefundTab(tab: RefundTab) {
        if (_refundState.value.selectedTab == tab) return
        _refundState.value = _refundState.value.copy(selectedTab = tab)
        loadRefunds()
    }

    fun loadRefunds(initialTab: RefundTab? = null) {
        viewModelScope.launch {
            val tab = initialTab ?: _refundState.value.selectedTab
            if (initialTab != null) {
                _refundState.value = _refundState.value.copy(selectedTab = tab)
            }
            _refundState.value = _refundState.value.copy(loading = true, error = null)
            try {
                val list = StudioService.fetchRefunds(tab.status)
                _refundState.value = _refundState.value.copy(loading = false, refunds = list)
            } catch (e: Exception) {
                _refundState.value = _refundState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    /** 同意退款（选退款方式，线上方式需上传凭证） */
    fun approveRefund(
        refundId: String,
        refundMethod: String,
        voucherImages: List<String>? = null,
        onSuccess: () -> Unit = {},
        onError: (String) -> Unit = {}
    ) {
        viewModelScope.launch {
            _refundState.value = _refundState.value.copy(submitting = true)
            try {
                StudioService.reviewRefund(refundId, "approve", refundMethod = refundMethod, voucherImages = voucherImages)
                _refundState.value = _refundState.value.copy(submitting = false)
                showToast("已同意退款")
                onSuccess()
                loadRefunds()
            } catch (e: Exception) {
                _refundState.value = _refundState.value.copy(submitting = false)
                val msg = e.message ?: "操作失败"
                onError(msg)
            }
        }
    }

    /** 驳回退款 */
    fun rejectRefund(
        refundId: String,
        reason: String,
        onSuccess: () -> Unit = {},
        onError: (String) -> Unit = {}
    ) {
        viewModelScope.launch {
            _refundState.value = _refundState.value.copy(submitting = true)
            try {
                StudioService.reviewRefund(refundId, "reject", reason = reason)
                _refundState.value = _refundState.value.copy(submitting = false)
                showToast("已驳回退款")
                onSuccess()
                loadRefunds()
            } catch (e: Exception) {
                _refundState.value = _refundState.value.copy(submitting = false)
                onError(e.message ?: "操作失败")
            }
        }
    }

    /** 确认已打款（待确认 → 已退款） */
    fun confirmRefundPayout(
        refundId: String,
        onSuccess: () -> Unit = {},
        onError: (String) -> Unit = {}
    ) {
        viewModelScope.launch {
            _refundState.value = _refundState.value.copy(submitting = true)
            try {
                StudioService.reviewRefund(refundId, "confirm")
                _refundState.value = _refundState.value.copy(submitting = false)
                showToast("已确认打款")
                onSuccess()
                loadRefunds()
            } catch (e: Exception) {
                _refundState.value = _refundState.value.copy(submitting = false)
                onError(e.message ?: "操作失败")
            }
        }
    }

    // MARK: - 订单列表

    data class OrderListState(
        val loading: Boolean = true,
        val selectedFilter: StudioService.OrderFilter = StudioService.OrderFilter.ALL,
        val keyword: String = "",
        val orders: List<StudioService.StudioOrder> = emptyList(),
        val total: Int = 0,
        val page: Int = 1,
        val hasMore: Boolean = false,
        val loadingMore: Boolean = false,
        val error: String? = null
    )

    private val _orderListState = MutableStateFlow(OrderListState())
    val orderListState: StateFlow<OrderListState> = _orderListState

    fun selectOrderFilter(filter: StudioService.OrderFilter) {
        if (_orderListState.value.selectedFilter == filter) return
        _orderListState.value = _orderListState.value.copy(selectedFilter = filter, keyword = "")
        loadOrders()
    }

    fun updateOrderKeyword(keyword: String) {
        _orderListState.value = _orderListState.value.copy(keyword = keyword)
    }

    fun searchOrders() {
        loadOrders()
    }

    fun loadOrders() {
        viewModelScope.launch {
            _orderListState.value = _orderListState.value.copy(loading = true, error = null, page = 1)
            try {
                val s = _orderListState.value
                val (total, list) = StudioService.fetchOrders(
                    status = s.selectedFilter.apiValue,
                    keyword = s.keyword.takeIf { it.isNotEmpty() },
                    page = 1
                )
                _orderListState.value = s.copy(
                    loading = false,
                    orders = list,
                    total = total,
                    hasMore = list.size < total
                )
            } catch (e: Exception) {
                _orderListState.value = _orderListState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    fun loadMoreOrders() {
        val s = _orderListState.value
        if (s.loadingMore || !s.hasMore) return
        viewModelScope.launch {
            _orderListState.value = s.copy(loadingMore = true)
            try {
                val nextPage = s.page + 1
                val (total, list) = StudioService.fetchOrders(
                    status = s.selectedFilter.apiValue,
                    keyword = s.keyword.takeIf { it.isNotEmpty() },
                    page = nextPage
                )
                _orderListState.value = _orderListState.value.copy(
                    loadingMore = false,
                    orders = s.orders + list,
                    page = nextPage,
                    hasMore = s.orders.size + list.size < total
                )
            } catch (e: Exception) {
                _orderListState.value = _orderListState.value.copy(loadingMore = false)
            }
        }
    }

    // MARK: - 订单详情

    data class OrderDetailState(
        val loading: Boolean = true,
        val order: StudioService.StudioOrder? = null,
        val error: String? = null,
        val submitting: Boolean = false
    )

    private val _orderDetailState = MutableStateFlow(OrderDetailState())
    val orderDetailState: StateFlow<OrderDetailState> = _orderDetailState

    fun loadOrderDetail(orderId: String) {
        viewModelScope.launch {
            _orderDetailState.value = _orderDetailState.value.copy(loading = true, error = null)
            try {
                val order = StudioService.fetchOrderDetail(orderId)
                _orderDetailState.value = _orderDetailState.value.copy(loading = false, order = order)
            } catch (e: Exception) {
                _orderDetailState.value = _orderDetailState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    /** 确认收款 */
    fun confirmPayment(
        orderId: String,
        payMethod: String? = null,
        voucherImages: List<String>? = null,
        note: String? = null,
        onSuccess: () -> Unit = {},
        onError: (String) -> Unit = {}
    ) {
        viewModelScope.launch {
            _orderDetailState.value = _orderDetailState.value.copy(submitting = true)
            try {
                val order = StudioService.confirmPayment(orderId, payMethod, voucherImages, note)
                _orderDetailState.value = _orderDetailState.value.copy(
                    submitting = false,
                    order = order ?: _orderDetailState.value.order
                )
                showToast("已确认收款")
                onSuccess()
            } catch (e: Exception) {
                _orderDetailState.value = _orderDetailState.value.copy(submitting = false)
                onError(e.message ?: "操作失败")
            }
        }
    }

    /** 驳回付款凭证 */
    fun rejectPayment(
        orderId: String,
        reason: String,
        onSuccess: () -> Unit = {},
        onError: (String) -> Unit = {}
    ) {
        viewModelScope.launch {
            _orderDetailState.value = _orderDetailState.value.copy(submitting = true)
            try {
                val order = StudioService.rejectPayment(orderId, reason)
                _orderDetailState.value = _orderDetailState.value.copy(
                    submitting = false,
                    order = order ?: _orderDetailState.value.order
                )
                showToast("已驳回付款凭证")
                onSuccess()
            } catch (e: Exception) {
                _orderDetailState.value = _orderDetailState.value.copy(submitting = false)
                onError(e.message ?: "操作失败")
            }
        }
    }

    /** 取消订单 */
    fun cancelOrder(
        orderId: String,
        onSuccess: () -> Unit = {},
        onError: (String) -> Unit = {}
    ) {
        viewModelScope.launch {
            _orderDetailState.value = _orderDetailState.value.copy(submitting = true)
            try {
                val order = StudioService.cancelOrder(orderId)
                _orderDetailState.value = _orderDetailState.value.copy(
                    submitting = false,
                    order = order ?: _orderDetailState.value.order
                )
                showToast("已取消订单")
                onSuccess()
            } catch (e: Exception) {
                _orderDetailState.value = _orderDetailState.value.copy(submitting = false)
                onError(e.message ?: "操作失败")
            }
        }
    }

    // MARK: - 老师列表

    data class TeacherListState(
        val loading: Boolean = true,
        val teachers: List<StudioService.StudioTeacherItem> = emptyList(),
        val summary: StudioService.StudioTeacherSummary? = null,
        val keyword: String = "",
        val error: String? = null,
        val inviting: Boolean = false
    )

    private val _teacherListState = MutableStateFlow(TeacherListState())
    val teacherListState: StateFlow<TeacherListState> = _teacherListState

    fun updateTeacherKeyword(keyword: String) {
        _teacherListState.value = _teacherListState.value.copy(keyword = keyword)
    }

    fun loadTeachers() {
        viewModelScope.launch {
            _teacherListState.value = _teacherListState.value.copy(loading = true, error = null)
            try {
                val s = _teacherListState.value
                val page = StudioService.fetchTeachers(s.keyword.takeIf { it.isNotEmpty() })
                _teacherListState.value = s.copy(
                    loading = false,
                    teachers = page.list ?: emptyList(),
                    summary = page.summary
                )
            } catch (e: Exception) {
                _teacherListState.value = _teacherListState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    /** 邀请老师（手机号） */
    fun inviteTeacher(
        phone: String,
        onSuccess: () -> Unit = {},
        onError: (String) -> Unit = {}
    ) {
        viewModelScope.launch {
            _teacherListState.value = _teacherListState.value.copy(inviting = true)
            try {
                val result = StudioService.inviteTeacher(phone)
                _teacherListState.value = _teacherListState.value.copy(inviting = false)
                showToast("已邀请 ${result?.teacherName ?: "老师"}")
                onSuccess()
                loadTeachers()
            } catch (e: Exception) {
                _teacherListState.value = _teacherListState.value.copy(inviting = false)
                onError(e.message ?: "邀请失败")
            }
        }
    }

    // MARK: - 老师详情

    data class TeacherDetailState(
        val loading: Boolean = true,
        val detail: StudioService.StudioTeacherDetail? = null,
        val error: String? = null,
        val releasing: Boolean = false
    )

    private val _teacherDetailState = MutableStateFlow(TeacherDetailState())
    val teacherDetailState: StateFlow<TeacherDetailState> = _teacherDetailState

    fun loadTeacherDetail(teacherId: String) {
        viewModelScope.launch {
            _teacherDetailState.value = _teacherDetailState.value.copy(loading = true, error = null)
            try {
                val detail = StudioService.fetchTeacherDetail(teacherId)
                _teacherDetailState.value = _teacherDetailState.value.copy(loading = false, detail = detail)
            } catch (e: Exception) {
                _teacherDetailState.value = _teacherDetailState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    /** 解除合作 */
    fun releaseTeacher(
        teacherId: String,
        onSuccess: () -> Unit = {},
        onError: (String) -> Unit = {}
    ) {
        viewModelScope.launch {
            _teacherDetailState.value = _teacherDetailState.value.copy(releasing = true)
            try {
                StudioService.releaseTeacher(teacherId)
                _teacherDetailState.value = _teacherDetailState.value.copy(releasing = false)
                showToast("已解除合作")
                onSuccess()
            } catch (e: Exception) {
                _teacherDetailState.value = _teacherDetailState.value.copy(releasing = false)
                onError(e.message ?: "操作失败")
            }
        }
    }

    // MARK: - 老师合作申请

    data class ApplicationState(
        val loading: Boolean = true,
        val selectedFilter: StudioService.ApplicationFilter = StudioService.ApplicationFilter.PENDING,
        val applications: List<StudioService.StudioTeacherApplication> = emptyList(),
        val summary: StudioService.StudioTeacherApplicationSummary? = null,
        val error: String? = null,
        val submitting: Boolean = false
    )

    private val _applicationState = MutableStateFlow(ApplicationState())
    val applicationState: StateFlow<ApplicationState> = _applicationState

    fun selectApplicationFilter(filter: StudioService.ApplicationFilter) {
        if (_applicationState.value.selectedFilter == filter) return
        _applicationState.value = _applicationState.value.copy(selectedFilter = filter)
        loadApplications()
    }

    fun loadApplications() {
        viewModelScope.launch {
            _applicationState.value = _applicationState.value.copy(loading = true, error = null)
            try {
                val s = _applicationState.value
                val page = StudioService.fetchTeacherApplications(s.selectedFilter.apiValue)
                _applicationState.value = s.copy(
                    loading = false,
                    applications = page.list ?: emptyList(),
                    summary = page.summary
                )
            } catch (e: Exception) {
                _applicationState.value = _applicationState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    fun reviewApplication(
        id: String,
        action: String,
        reason: String? = null,
        onSuccess: () -> Unit = {},
        onError: (String) -> Unit = {}
    ) {
        viewModelScope.launch {
            _applicationState.value = _applicationState.value.copy(submitting = true)
            try {
                StudioService.reviewTeacherApplication(id, action, reason)
                _applicationState.value = _applicationState.value.copy(submitting = false)
                showToast(if (action == "approve") "已通过申请" else "已驳回申请")
                onSuccess()
                loadApplications()
            } catch (e: Exception) {
                _applicationState.value = _applicationState.value.copy(submitting = false)
                onError(e.message ?: "操作失败")
            }
        }
    }

    // MARK: - 学员列表

    data class StudentListState(
        val loading: Boolean = true,
        val selectedFilter: StudioService.StudentFilter = StudioService.StudentFilter.ALL,
        val students: List<StudioService.StudioStudentItem> = emptyList(),
        val summary: StudioService.StudioStudentSummary? = null,
        val keyword: String = "",
        val error: String? = null
    )

    private val _studentListState = MutableStateFlow(StudentListState())
    val studentListState: StateFlow<StudentListState> = _studentListState

    fun selectStudentFilter(filter: StudioService.StudentFilter) {
        if (_studentListState.value.selectedFilter == filter) return
        _studentListState.value = _studentListState.value.copy(selectedFilter = filter)
        loadStudents()
    }

    fun updateStudentKeyword(keyword: String) {
        _studentListState.value = _studentListState.value.copy(keyword = keyword)
    }

    fun loadStudents() {
        viewModelScope.launch {
            _studentListState.value = _studentListState.value.copy(loading = true, error = null)
            try {
                val s = _studentListState.value
                val page = StudioService.fetchStudents(s.selectedFilter, s.keyword.takeIf { it.isNotEmpty() })
                _studentListState.value = s.copy(
                    loading = false,
                    students = page.list ?: emptyList(),
                    summary = page.summary
                )
            } catch (e: Exception) {
                _studentListState.value = _studentListState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    // MARK: - 学员详情

    data class StudentDetailState(
        val loading: Boolean = true,
        val detail: StudioService.StudioStudentDetail? = null,
        val error: String? = null
    )

    private val _studentDetailState = MutableStateFlow(StudentDetailState())
    val studentDetailState: StateFlow<StudentDetailState> = _studentDetailState

    fun loadStudentDetail(childId: String) {
        viewModelScope.launch {
            _studentDetailState.value = _studentDetailState.value.copy(loading = true, error = null)
            try {
                val detail = StudioService.fetchStudentDetail(childId)
                _studentDetailState.value = _studentDetailState.value.copy(loading = false, detail = detail)
            } catch (e: Exception) {
                _studentDetailState.value = _studentDetailState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    // MARK: - 佣金审核

    enum class CommissionTab(val title: String, val status: Int, val emptyText: String) {
        PENDING("待审核", 0, "暂无待审核佣金"),
        CONFIRM("待确认", 1, "暂无待确认佣金"),
        REJECTED("已驳回", 2, "暂无已驳回佣金"),
        COMPLETED("已完成", 3, "暂无已完成佣金");

        companion object {
            fun from(status: Int) = entries.firstOrNull { it.status == status } ?: PENDING
        }
    }

    data class CommissionState(
        val loading: Boolean = true,
        val selectedTab: CommissionTab = CommissionTab.PENDING,
        val items: List<CommissionService.CommissionWithdrawal> = emptyList(),
        val total: Int = 0,
        val page: Int = 1,
        val hasMore: Boolean = false,
        val loadingMore: Boolean = false,
        val error: String? = null,
        val submitting: Boolean = false
    )

    private val _commissionState = MutableStateFlow(CommissionState())
    val commissionState: StateFlow<CommissionState> = _commissionState

    fun selectCommissionTab(tab: CommissionTab) {
        if (_commissionState.value.selectedTab == tab) return
        _commissionState.value = _commissionState.value.copy(selectedTab = tab)
        loadCommissions()
    }

    fun loadCommissions() {
        viewModelScope.launch {
            _commissionState.value = _commissionState.value.copy(loading = true, error = null, page = 1)
            try {
                val s = _commissionState.value
                val (total, list) = StudioService.fetchCommissionWithdrawals(s.selectedTab.status, page = 1)
                _commissionState.value = s.copy(
                    loading = false,
                    items = list,
                    total = total,
                    hasMore = list.size < total
                )
            } catch (e: Exception) {
                _commissionState.value = _commissionState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    fun loadMoreCommissions() {
        val s = _commissionState.value
        if (s.loadingMore || !s.hasMore) return
        viewModelScope.launch {
            _commissionState.value = s.copy(loadingMore = true)
            try {
                val nextPage = s.page + 1
                val (total, list) = StudioService.fetchCommissionWithdrawals(s.selectedTab.status, page = nextPage)
                _commissionState.value = _commissionState.value.copy(
                    loadingMore = false,
                    items = s.items + list,
                    page = nextPage,
                    hasMore = s.items.size + list.size < total
                )
            } catch (e: Exception) {
                _commissionState.value = _commissionState.value.copy(loadingMore = false)
            }
        }
    }

    /** 通过并打款 */
    fun approveCommission(
        id: String,
        method: String,
        voucherImages: List<String>? = null,
        onSuccess: () -> Unit = {},
        onError: (String) -> Unit = {}
    ) {
        viewModelScope.launch {
            _commissionState.value = _commissionState.value.copy(submitting = true)
            try {
                StudioService.reviewCommissionWithdrawal(id, "approve", method, voucherImages)
                _commissionState.value = _commissionState.value.copy(submitting = false)
                showToast("已通过并打款")
                onSuccess()
                loadCommissions()
            } catch (e: Exception) {
                _commissionState.value = _commissionState.value.copy(submitting = false)
                onError(e.message ?: "操作失败")
            }
        }
    }

    /** 驳回佣金领取 */
    fun rejectCommission(
        id: String,
        reason: String,
        onSuccess: () -> Unit = {},
        onError: (String) -> Unit = {}
    ) {
        viewModelScope.launch {
            _commissionState.value = _commissionState.value.copy(submitting = true)
            try {
                StudioService.reviewCommissionWithdrawal(id, "reject", rejectReason = reason)
                _commissionState.value = _commissionState.value.copy(submitting = false)
                showToast("已驳回")
                onSuccess()
                loadCommissions()
            } catch (e: Exception) {
                _commissionState.value = _commissionState.value.copy(submitting = false)
                onError(e.message ?: "操作失败")
            }
        }
    }

    // MARK: - 财务对账（收益中心）

    data class FinanceState(
        val loading: Boolean = true,
        val data: StudioService.StudioFinanceData? = null,
        val error: String? = null
    )

    private val _financeState = MutableStateFlow(FinanceState())
    val financeState: StateFlow<FinanceState> = _financeState

    fun loadFinance(startDate: String? = null, endDate: String? = null) {
        viewModelScope.launch {
            _financeState.value = _financeState.value.copy(loading = true, error = null)
            try {
                val data = StudioService.fetchFinance(startDate, endDate)
                _financeState.value = _financeState.value.copy(loading = false, data = data)
            } catch (e: Exception) {
                _financeState.value = _financeState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    // MARK: - 课程管理

    enum class CourseTab(val title: String, val status: Int, val emptyText: String) {
        ONLINE("在售", 1, "暂无在售课程"),
        REVIEWING("审核中", 0, "暂无审核中课程"),
        OFFLINE("已下架", 2, "暂无已下架课程");

        companion object {
            fun from(status: Int) = entries.firstOrNull { it.status == status } ?: ONLINE
        }
    }

    data class CourseState(
        val loading: Boolean = true,
        val selectedTab: CourseTab = CourseTab.ONLINE,
        val courses: List<StudioService.StudioCourseItem> = emptyList(),
        val error: String? = null,
        val toggling: Boolean = false
    )

    private val _courseState = MutableStateFlow(CourseState())
    val courseState: StateFlow<CourseState> = _courseState

    fun selectCourseTab(tab: CourseTab) {
        if (_courseState.value.selectedTab == tab) return
        _courseState.value = _courseState.value.copy(selectedTab = tab)
        loadCourses()
    }

    fun loadCourses() {
        viewModelScope.launch {
            _courseState.value = _courseState.value.copy(loading = true, error = null)
            try {
                val list = StudioService.fetchCourses(_courseState.value.selectedTab.status)
                _courseState.value = _courseState.value.copy(loading = false, courses = list)
            } catch (e: Exception) {
                _courseState.value = _courseState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    /** 上架/下架课程 */
    fun setCourseStatus(courseId: String, status: Int) {
        viewModelScope.launch {
            _courseState.value = _courseState.value.copy(toggling = true)
            try {
                StudioService.setCourseStatus(courseId, status)
                _courseState.value = _courseState.value.copy(toggling = false)
                showToast(if (status == 1) "已上架" else "已下架")
                loadCourses()
            } catch (e: Exception) {
                _courseState.value = _courseState.value.copy(toggling = false)
                showToast(e.message ?: "操作失败")
            }
        }
    }

    // MARK: - 图片上传工具

    /** Uri 列表 → 上传 → URL 列表 */
    suspend fun uploadImages(uris: List<Uri>, type: String = "voucher"): List<String> {
        if (uris.isEmpty()) return emptyList()
        val files = uris.map { uriToFile(it) }
        return try {
            val json = ApiService.upload(files, type)
            files.forEach { it.delete() }
            json.strList("urls")
        } catch (e: Exception) {
            files.forEach { it.delete() }
            throw e
        }
    }

    private fun uriToFile(uri: Uri): File {
        val app = getApplication<Application>()
        val input = app.contentResolver.openInputStream(uri)
            ?: throw IllegalStateException("无法读取图片")
        val file = File(app.cacheDir, "upload_${System.currentTimeMillis()}_${uri.hashCode()}.jpg")
        input.use { src ->
            file.outputStream().use { dst -> src.copyTo(dst) }
        }
        return file
    }
}