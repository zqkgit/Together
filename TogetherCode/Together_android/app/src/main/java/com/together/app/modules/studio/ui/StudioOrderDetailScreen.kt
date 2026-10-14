package com.together.app.modules.studio.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.TextButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.core.component.EmptyStateView
import com.together.app.core.component.ErrorView
import com.together.app.core.component.InfoRow
import com.together.app.core.component.LoadingView
import com.together.app.core.component.SectionHeader
import com.together.app.core.component.StatusTag
import com.together.app.core.component.TogetherCard
import com.together.app.core.component.TogetherDivider
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.component.resolveImageUrl
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.studio.StudioViewModel
import com.together.app.services.StudioService

/**
 * 工作室「订单详情」页（对齐 iOS StudioOrderDetailViewController）
 *
 * 状态卡 + 学员信息 + 课程信息 + 金额明细 + 付款记录 + 课时账本 + 退款记录 + 底部操作栏
 * 操作：确认收款（备注弹窗）/ 驳回凭证（原因弹窗）/ 取消订单（确认弹窗）
 */
@Composable
fun StudioOrderDetailScreen(
    orderId: String,
    onBack: () -> Unit = {},
    viewModel: StudioViewModel = viewModel()
) {
    val state by viewModel.orderDetailState.collectAsState()
    val order = state.order

    var showConfirmDialog by remember { mutableStateOf(false) }
    var showRejectDialog by remember { mutableStateOf(false) }
    var showCancelDialog by remember { mutableStateOf(false) }
    var previewVouchers by remember { mutableStateOf<List<String>?>(null) }

    // ON_RESUME 刷新
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) viewModel.loadOrderDetail(orderId)
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "订单详情", onBack = onBack)

        Box(modifier = Modifier.weight(1f)) {
            when {
                state.loading && order == null -> LoadingView()
                state.error != null && order == null -> ErrorView(
                    message = state.error!!,
                    onRetry = { viewModel.loadOrderDetail(orderId) }
                )
                order != null -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(
                        start = AppDimens.L,
                        end = AppDimens.L,
                        top = AppDimens.S,
                        bottom = AppDimens.Xl
                    ),
                    verticalArrangement = Arrangement.spacedBy(AppDimens.M)
                ) {
                    // 状态卡
                    item { OrderStatusCard(order) }
                    // 学员信息卡
                    item { OrderStudentCard(order) }
                    // 课程信息卡
                    item { OrderCourseCard(order) }
                    // 金额明细卡
                    item { OrderAmountCard(order) }
                    // 付款记录
                    if (!order.payments.isNullOrEmpty()) {
                        item { SectionHeader(title = "付款记录") }
                        items(order.payments!!, key = { it.paymentId ?: it.hashCode().toString() }) { payment ->
                            PaymentRecordCard(payment, onVoucherTap = { previewVouchers = it })
                        }
                    }
                    // 课时账本
                    if (order.balance != null) {
                        item { SectionHeader(title = "课时账本") }
                        item { OrderBalanceCard(order.balance!!) }
                    }
                    // 退款记录
                    if (!order.refunds.isNullOrEmpty()) {
                        item { SectionHeader(title = "退款记录") }
                        items(order.refunds!!, key = { it.refundId ?: it.hashCode().toString() }) { refund ->
                            RefundRecordCard(refund)
                        }
                    }
                }
            }
        }

        // 底部操作栏
        if (order != null) {
            OrderBottomBar(
                order = order,
                submitting = state.submitting,
                onConfirm = { showConfirmDialog = true },
                onReject = { showRejectDialog = true },
                onCancel = { showCancelDialog = true }
            )
        }
    }

    // 提交中遮罩
    if (state.submitting) {
        Box(
            modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.3f)),
            contentAlignment = Alignment.Center
        ) {
            CircularProgressIndicator(color = AppColors.Brand)
        }
    }

    // 确认收款弹窗（输入备注）
    if (showConfirmDialog && order != null) {
        NoteInputDialog(
            title = "确认收款",
            placeholder = "备注（选填，家长可见）",
            confirmText = "确认收款",
            onDismiss = { showConfirmDialog = false },
            onConfirm = { note ->
                showConfirmDialog = false
                viewModel.confirmPayment(
                    orderId = order.orderId,
                    note = note.takeIf { it.isNotEmpty() },
                    onError = { /* toast 由 ViewModel 处理 */ }
                )
            }
        )
    }

    // 驳回凭证弹窗（输入原因）
    if (showRejectDialog && order != null) {
        NoteInputDialog(
            title = "驳回付款凭证",
            placeholder = "请填写驳回原因（家长可见）",
            confirmText = "确认驳回",
            confirmColor = AppColors.Danger,
            onDismiss = { showRejectDialog = false },
            onConfirm = { reason ->
                showRejectDialog = false
                viewModel.rejectPayment(order.orderId, reason)
            }
        )
    }

    // 取消订单确认弹窗
    if (showCancelDialog && order != null) {
        AlertDialog(
            onDismissRequest = { showCancelDialog = false },
            title = { Text("取消订单", fontWeight = FontWeight.SemiBold) },
            text = { Text("确认取消订单「${order.orderNo}」？取消后不可恢复。") },
            confirmButton = {
                TextButton(onClick = {
                    showCancelDialog = false
                    viewModel.cancelOrder(order.orderId)
                }) { Text("确认取消", color = AppColors.Danger) }
            },
            dismissButton = {
                TextButton(onClick = { showCancelDialog = false }) { Text("再想想") }
            }
        )
    }

    // 凭证全屏预览
    previewVouchers?.let { urls ->
        OrderVoucherPreviewDialog(urls = urls, onDismiss = { previewVouchers = null })
    }
}

// MARK: - 状态卡

@Composable
private fun OrderStatusCard(order: StudioService.StudioOrder) {
    TogetherCard(modifier = Modifier.fillMaxWidth()) {
        Column {
            StatusTag(status = order.status ?: 0, statusText = order.statusLabel)
            Spacer(modifier = Modifier.height(AppDimens.M))
            Text(
                text = order.orderNo ?: "—",
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "创建于 ${order.createdDate}",
                fontSize = 12.sp,
                color = AppColors.Muted
            )
        }
    }
}

// MARK: - 学员信息卡

@Composable
private fun OrderStudentCard(order: StudioService.StudioOrder) {
    TogetherCard(modifier = Modifier.fillMaxWidth()) {
        Column {
            Text(
                text = "学员信息",
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink
            )
            Spacer(modifier = Modifier.height(AppDimens.S))
            TogetherDivider()
            InfoRow(label = "学员", value = order.child?.displayName ?: "—")
            InfoRow(label = "家长", value = order.user?.displayName ?: "—")
            InfoRow(label = "手机", value = order.user?.phone ?: "—")
        }
    }
}

// MARK: - 课程信息卡

@Composable
private fun OrderCourseCard(order: StudioService.StudioOrder) {
    TogetherCard(modifier = Modifier.fillMaxWidth()) {
        Column {
            Text(
                text = "课程信息",
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink
            )
            Spacer(modifier = Modifier.height(AppDimens.S))
            TogetherDivider()
            InfoRow(label = "课程", value = order.courseTitle)
            InfoRow(label = "套餐", value = order.pkg?.displayName ?: "—")
            InfoRow(label = "班级", value = order.classRef?.displayName.ifNullOrBlank { "—" })
            InfoRow(label = "课时", value = order.totalLessonsText)
        }
    }
}

// MARK: - 金额明细卡

@Composable
private fun OrderAmountCard(order: StudioService.StudioOrder) {
    TogetherCard(modifier = Modifier.fillMaxWidth()) {
        Column {
            Text(
                text = "金额明细",
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink
            )
            Spacer(modifier = Modifier.height(AppDimens.S))
            TogetherDivider()
            InfoRow(label = "订单金额", value = order.totalAmountText, valueColor = AppColors.Clay)
            InfoRow(label = "已收金额", value = order.paidAmountText)
            InfoRow(label = "退款金额", value = order.refundAmountText, valueColor = AppColors.Danger)
            InfoRow(label = "支付方式", value = order.payMethodText ?: "—")
            InfoRow(label = "来源", value = order.sourceLabel)
        }
    }
}

// MARK: - 付款记录卡

@Composable
private fun PaymentRecordCard(
    payment: StudioService.StudioPayment,
    onVoucherTap: (List<String>) -> Unit
) {
    TogetherCard(modifier = Modifier.fillMaxWidth()) {
        Column {
            // 状态 pill + 金额
            Row(verticalAlignment = Alignment.CenterVertically) {
                StatusTag(status = payment.status ?: 0, statusText = payment.statusLabel)
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = payment.amountText,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.Ink
                )
            }
            Spacer(modifier = Modifier.height(AppDimens.S))
            // 方式 + 时间
            Text(
                text = "${payment.methodText}  ${payment.paidAt?.take(10) ?: payment.createdAt?.take(10) ?: ""}",
                fontSize = 12.sp,
                color = AppColors.Muted
            )
            // 备注
            if (payment.noteText.isNotEmpty()) {
                Spacer(modifier = Modifier.height(AppDimens.S))
                Text(
                    text = "备注：${payment.noteText}",
                    fontSize = 12.sp,
                    color = AppColors.Sub
                )
            }
            // 驳回原因
            if (payment.isRejected && payment.rejectText.isNotEmpty()) {
                Spacer(modifier = Modifier.height(AppDimens.S))
                Text(
                    text = "驳回原因：${payment.rejectText}",
                    fontSize = 12.sp,
                    color = AppColors.Danger
                )
            }
            // 凭证缩略图
            if (payment.hasVoucher) {
                Spacer(modifier = Modifier.height(AppDimens.S))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    payment.voucherURLs.take(5).forEach { url ->
                        AsyncImage(
                            model = resolveImageUrl(url),
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .size(60.dp)
                                .clip(RoundedCornerShape(8.dp))
                                .background(AppColors.Bg)
                                .clickable { onVoucherTap(payment.voucherURLs) }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - 课时账本卡

@Composable
private fun OrderBalanceCard(balance: StudioService.StudioOrderBalance) {
    TogetherCard(modifier = Modifier.fillMaxWidth()) {
        Column {
            // 四格统计
            Row(modifier = Modifier.fillMaxWidth()) {
                BalanceCell("总课时", "${balance.total}", AppColors.Ink, Modifier.weight(1f))
                BalanceCell("已消耗", "${balance.consumed}", AppColors.Sub, Modifier.weight(1f))
                BalanceCell("已退回", "${balance.refunded}", AppColors.Muted, Modifier.weight(1f))
                BalanceCell("剩余", "${balance.remaining}", AppColors.Brand, Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun BalanceCell(label: String, value: String, color: Color, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(text = value, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = color)
        Spacer(modifier = Modifier.height(2.dp))
        Text(text = label, fontSize = 11.sp, color = AppColors.Muted)
    }
}

// MARK: - 退款记录卡

@Composable
private fun RefundRecordCard(refund: StudioService.StudioOrderRefund) {
    TogetherCard(modifier = Modifier.fillMaxWidth()) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                StatusTag(status = refund.status ?: 0, statusText = refund.statusText ?: "未知")
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = "-${refund.amountText}",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.Danger
                )
            }
            Spacer(modifier = Modifier.height(AppDimens.S))
            Text(
                text = "退 ${refund.requestedLessons ?: 0} 节课",
                fontSize = 12.sp,
                color = AppColors.Sub
            )
            if (!refund.reason.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "原因：${refund.reason}",
                    fontSize = 12.sp,
                    color = AppColors.Muted,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

// MARK: - 底部操作栏

@Composable
private fun OrderBottomBar(
    order: StudioService.StudioOrder,
    submitting: Boolean,
    onConfirm: () -> Unit,
    onReject: () -> Unit,
    onCancel: () -> Unit
) {
    val showReject = (order.isPending && order.hasPendingPayment) || order.isPaymentReview
    val showConfirm = order.isPending || order.isPaymentReview
    val showCancel = (order.isPending && !order.hasPendingPayment) || order.isPaymentReview

    if (!showReject && !showConfirm && !showCancel) return

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.L, vertical = AppDimens.M)
            .navigationBarsPadding(),
        horizontalArrangement = Arrangement.spacedBy(AppDimens.M),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (showCancel) {
            OrderBarButton(
                text = "取消订单",
                filled = false,
                enabled = !submitting,
                onClick = onCancel,
                modifier = Modifier.weight(1f)
            )
        }
        if (showReject) {
            OrderBarButton(
                text = "驳回凭证",
                filled = false,
                danger = true,
                enabled = !submitting,
                onClick = onReject,
                modifier = Modifier.weight(1f)
            )
        }
        if (showConfirm) {
            OrderBarButton(
                text = "确认收款",
                filled = true,
                enabled = !submitting,
                onClick = onConfirm,
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun OrderBarButton(
    text: String,
    filled: Boolean,
    danger: Boolean = false,
    enabled: Boolean = true,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val bgColor = when {
        !enabled -> AppColors.Line
        filled -> AppColors.Brand
        danger -> Color.Transparent
        else -> Color.Transparent
    }
    val textColor = when {
        !enabled -> AppColors.Muted
        filled -> Color.White
        danger -> AppColors.Danger
        else -> AppColors.Ink
    }
    val borderColor = if (danger) AppColors.Danger else AppColors.Line
    Box(
        modifier = modifier
            .height(42.dp)
            .clip(RoundedCornerShape(AppDimens.RadiusButton))
            .background(bgColor)
            .then(if (!filled) Modifier.border(1.dp, borderColor, RoundedCornerShape(AppDimens.RadiusButton)) else Modifier)
            .clickable(enabled = enabled) { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = textColor
        )
    }
}

// MARK: - 备注/原因输入弹窗

@Composable
private fun NoteInputDialog(
    title: String,
    placeholder: String,
    confirmText: String,
    confirmColor: Color = AppColors.Brand,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit
) {
    var text by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title, fontWeight = FontWeight.SemiBold) },
        text = {
            OutlinedTextField(
                value = text,
                onValueChange = { if (it.length <= 100) text = it },
                placeholder = { Text(placeholder) },
                modifier = Modifier.fillMaxWidth(),
                maxLines = 3
            )
        },
        confirmButton = {
            TextButton(onClick = {
                val trimmed = text.trim()
                onConfirm(trimmed)
            }) { Text(confirmText, color = confirmColor) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("取消") }
        }
    )
}

// MARK: - 凭证全屏预览

@Composable
private fun OrderVoucherPreviewDialog(
    urls: List<String>,
    onDismiss: () -> Unit
) {
    if (urls.isEmpty()) return
    val pagerState = rememberPagerState(pageCount = { urls.size })
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.92f))
            .clickable { onDismiss() }
    ) {
        HorizontalPager(state = pagerState, modifier = Modifier.fillMaxSize()) { page ->
            AsyncImage(
                model = resolveImageUrl(urls[page]),
                contentDescription = null,
                contentScale = ContentScale.Fit,
                modifier = Modifier.fillMaxSize()
            )
        }
        if (urls.size > 1) {
            Text(
                text = "${pagerState.currentPage + 1}/${urls.size}",
                color = Color.White,
                fontSize = 14.sp,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 40.dp)
            )
        }
        Text(
            text = "✕",
            color = Color.White,
            fontSize = 20.sp,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(top = 48.dp, end = AppDimens.L)
                .clip(RoundedCornerShape(50))
                .clickable { onDismiss() }
                .padding(12.dp)
        )
    }
}

// MARK: - 工具

private fun String?.ifNullOrBlank(fallback: () -> String): String =
    if (this.isNullOrBlank()) fallback() else this