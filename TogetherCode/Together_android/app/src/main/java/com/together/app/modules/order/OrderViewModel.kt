package com.together.app.modules.order

import android.app.Application
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.together.app.core.model.OrderItem
import com.together.app.core.model.RefundDetail
import com.together.app.core.network.ApiService
import com.together.app.core.network.JsonHelper.strList
import com.together.app.services.OrderService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import java.io.File

/**
 * 订单模块 ViewModel（对齐 iOS 订单各 ViewController 的状态管理）
 *
 * 覆盖五个页面的状态：
 * - 订单列表（Tab 切换 + 加载 + 取消）
 * - 订单详情（加载 + 取消）
 * - 上传付款凭证（提交）
 * - 申请退款（提交）
 * - 退款详情（加载 + 确认退款）
 */
class OrderViewModel(app: Application) : AndroidViewModel(app) {

    companion object {
        /** 页面间传递订单对象（Navigation Compose 不支持复杂对象参数，进程被杀后需重新进入） */
        var navOrder: OrderItem? = null
    }

    // MARK: - 订单列表（MyOrdersScreen）

    /** Tab：全部 / 待付款0 / 待确认1 / 已报名2 / 已取消6 / 已退款5 */
    enum class OrderTab(val title: String, val status: Int?) {
        ALL("全部", null),
        PENDING("待付款", 0),
        PAYMENT_REVIEW("待确认", 1),
        ENROLLED("已报名", 2),
        CANCELLED("已取消", 6),
        REFUNDED("已退款", 5);
    }

    data class ListState(
        val loading: Boolean = true,
        val orders: List<OrderItem> = emptyList(),
        val error: String? = null,
        val selectedTab: OrderTab = OrderTab.ALL
    )

    private val _listState = MutableStateFlow(ListState())
    val listState: StateFlow<ListState> = _listState

    fun selectTab(tab: OrderTab) {
        if (_listState.value.selectedTab == tab) return
        _listState.value = _listState.value.copy(selectedTab = tab)
        loadOrders()
    }

    fun loadOrders() {
        viewModelScope.launch {
            _listState.value = _listState.value.copy(loading = true, error = null)
            try {
                val orders = OrderService.fetchOrders(_listState.value.selectedTab.status)
                _listState.value = _listState.value.copy(loading = false, orders = orders)
            } catch (e: Exception) {
                _listState.value = _listState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    /** 取消待付款订单（列表页调用，成功后自动刷新） */
    fun cancelOrder(orderId: String, onError: (String) -> Unit = {}) {
        viewModelScope.launch {
            try {
                OrderService.cancelOrder(orderId)
                loadOrders()
            } catch (e: Exception) {
                onError(e.message ?: "取消失败")
            }
        }
    }

    // MARK: - 订单详情（OrderDetailScreen）

    data class DetailState(
        val loading: Boolean = true,
        val order: OrderItem? = null,
        val error: String? = null,
        val cancelling: Boolean = false
    )

    private val _detailState = MutableStateFlow(DetailState())
    val detailState: StateFlow<DetailState> = _detailState

    fun loadDetail(orderId: String) {
        viewModelScope.launch {
            _detailState.value = _detailState.value.copy(loading = true, error = null)
            try {
                val order = OrderService.fetchOrderDetail(orderId)
                _detailState.value = _detailState.value.copy(loading = false, order = order)
            } catch (e: Exception) {
                _detailState.value = _detailState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    /** 取消订单（详情页调用，成功后重新加载详情） */
    fun cancelOrderFromDetail(orderId: String, onSuccess: () -> Unit, onError: (String) -> Unit) {
        viewModelScope.launch {
            _detailState.value = _detailState.value.copy(cancelling = true)
            try {
                OrderService.cancelOrder(orderId)
                _detailState.value = _detailState.value.copy(cancelling = false)
                onSuccess()
                loadDetail(orderId)
            } catch (e: Exception) {
                _detailState.value = _detailState.value.copy(cancelling = false)
                onError(e.message ?: "取消失败")
            }
        }
    }

    // MARK: - 上传付款凭证（PaymentVoucherScreen）

    data class VoucherState(
        val submitting: Boolean = false,
        val error: String? = null,
        val success: Boolean = false
    )

    private val _voucherState = MutableStateFlow(VoucherState())
    val voucherState: StateFlow<VoucherState> = _voucherState

    fun submitVoucher(orderId: String, payMethod: String, images: List<String>, note: String?) {
        viewModelScope.launch {
            _voucherState.value = _voucherState.value.copy(submitting = true, error = null)
            try {
                OrderService.submitPaymentVoucher(orderId, payMethod, images, note)
                _voucherState.value = _voucherState.value.copy(submitting = false, success = true)
            } catch (e: Exception) {
                _voucherState.value = _voucherState.value.copy(submitting = false, error = e.message ?: "提交失败")
            }
        }
    }

    fun resetVoucherState() {
        _voucherState.value = VoucherState()
    }

    /** 清除凭证提交错误（Toast 展示后调用） */
    fun clearVoucherError() {
        _voucherState.value = _voucherState.value.copy(error = null)
    }

    /**
     * 上传凭证图片并提交（对齐 iOS PaymentVoucherViewController.didTapSubmit）
     * 1. Uri → 缓存 File  2. ApiService.upload → urls  3. submitPaymentVoucher
     */
    fun uploadAndSubmitVoucher(orderId: String, payMethod: String, uris: List<Uri>, note: String?) {
        viewModelScope.launch {
            _voucherState.value = _voucherState.value.copy(submitting = true, error = null)
            try {
                val urls = if (uris.isEmpty()) {
                    emptyList()
                } else {
                    val files = uris.map { uriToFile(it) }
                    val json = ApiService.upload(files, "voucher")
                    files.forEach { it.delete() }
                    val urls = json.strList("urls")
                    if (urls.isEmpty()) throw IllegalStateException("凭证上传失败")
                    urls
                }
                OrderService.submitPaymentVoucher(orderId, payMethod, urls, note)
                _voucherState.value = _voucherState.value.copy(submitting = false, success = true)
            } catch (e: Exception) {
                _voucherState.value = _voucherState.value.copy(submitting = false, error = e.message ?: "提交失败")
            }
        }
    }

    /** Uri → 缓存文件（用于 multipart 上传） */
    private fun uriToFile(uri: Uri): File {
        val app = getApplication<Application>()
        val input = app.contentResolver.openInputStream(uri)
            ?: throw IllegalStateException("无法读取图片")
        val file = File(app.cacheDir, "voucher_${System.currentTimeMillis()}_${uri.hashCode()}.jpg")
        input.use { src ->
            file.outputStream().use { dst -> src.copyTo(dst) }
        }
        return file
    }

    // MARK: - 申请退款（OrderRefundScreen）

    data class RefundRequestState(
        val submitting: Boolean = false,
        val error: String? = null,
        val success: Boolean = false
    )

    private val _refundRequestState = MutableStateFlow(RefundRequestState())
    val refundRequestState: StateFlow<RefundRequestState> = _refundRequestState

    fun requestRefund(orderId: String, lessons: Int, reason: String?) {
        viewModelScope.launch {
            _refundRequestState.value = _refundRequestState.value.copy(submitting = true, error = null)
            try {
                OrderService.requestRefund(orderId, lessons, reason)
                _refundRequestState.value = _refundRequestState.value.copy(submitting = false, success = true)
            } catch (e: Exception) {
                _refundRequestState.value = _refundRequestState.value.copy(submitting = false, error = e.message ?: "提交失败")
            }
        }
    }

    fun resetRefundRequestState() {
        _refundRequestState.value = RefundRequestState()
    }

    /** 清除退款申请错误（Toast 展示后调用） */
    fun clearRefundRequestError() {
        _refundRequestState.value = _refundRequestState.value.copy(error = null)
    }

    // MARK: - 退款详情（RefundDetailScreen）

    data class RefundState(
        val loading: Boolean = true,
        val refund: RefundDetail? = null,
        val error: String? = null,
        val confirming: Boolean = false
    )

    private val _refundState = MutableStateFlow(RefundState())
    val refundState: StateFlow<RefundState> = _refundState

    fun loadRefund(refundId: String) {
        viewModelScope.launch {
            _refundState.value = _refundState.value.copy(loading = true, error = null)
            try {
                val refund = OrderService.fetchRefundDetail(refundId)
                _refundState.value = _refundState.value.copy(loading = false, refund = refund)
            } catch (e: Exception) {
                _refundState.value = _refundState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    /** 家长确认已在线下收到退款 */
    fun confirmRefund(refundId: String, onSuccess: () -> Unit, onError: (String) -> Unit) {
        viewModelScope.launch {
            _refundState.value = _refundState.value.copy(confirming = true)
            try {
                val refund = OrderService.confirmRefund(refundId)
                _refundState.value = _refundState.value.copy(
                    confirming = false,
                    refund = refund ?: _refundState.value.refund
                )
                onSuccess()
            } catch (e: Exception) {
                _refundState.value = _refundState.value.copy(confirming = false)
                onError(e.message ?: "确认失败")
            }
        }
    }
}