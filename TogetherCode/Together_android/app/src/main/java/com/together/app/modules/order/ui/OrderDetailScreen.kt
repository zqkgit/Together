package com.together.app.modules.order.ui

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.core.component.EmptyStateView
import com.together.app.core.component.ErrorView
import com.together.app.core.component.InfoRow
import com.together.app.core.component.LoadingView
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.component.resolveImageUrl
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.OrderItem
import com.together.app.core.model.OrderRefundStatus
import com.together.app.core.model.OrderStatus
import com.together.app.core.model.PaymentItem
import com.together.app.core.model.PaymentStatus
import com.together.app.core.model.fenToYuanText
import com.together.app.core.model.fmtTime
import com.together.app.modules.order.OrderViewModel

/**
 * 订单详情（家长端 · 线下收款模式）
 * 对齐 iOS OrderDetailViewController
 *
 * 分组：状态卡 / 课程信息 / 订单信息 / 付款记录 / 课时进度
 * 平台不经手资金：待付款 → 家长线下付款并上传凭证 → 工作室确认收款 → 发课时
 */
@Composable
fun OrderDetailScreen(
    orderId: String,
    onBack: () -> Unit,
    onUploadVoucher: (OrderItem) -> Unit,
    onStudy: (childId: String, courseId: String, title: String) -> Unit,
    onRefundDetail: (String) -> Unit,
    onReorder: (String) -> Unit,
    onRefund: (OrderItem) -> Unit,
    viewModel: OrderViewModel = viewModel()
) {
    val detailState by viewModel.detailState.collectAsState()
    val order = detailState.order
    var showCancelDialog by remember { mutableStateOf(false) }
    val context = LocalContext.current

    LaunchedEffect(orderId) { viewModel.loadDetail(orderId) }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "订单详情", onBack = onBack)

        Box(modifier = Modifier.weight(1f)) {
            when {
                detailState.loading -> LoadingView()
                detailState.error != null -> ErrorView(
                    message = detailState.error!!,
                    onRetry = { viewModel.loadDetail(orderId) }
                )
                order == null -> EmptyStateView(message = "订单不存在")
                else -> Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(bottom = 100.dp)
                ) {
                    val status = order.statusInfo()
                    StatusCard(title = status.first, desc = status.second, toneColor = status.third)
                    Spacer(modifier = Modifier.height(AppDimens.S))
                    CourseCard(title = order.courseTitleWithLessons, subtitle = order.studioClassText)
                    Spacer(modifier = Modifier.height(AppDimens.M))
                    SectionTitle("订单信息")
                    InfoCard { OrderInfoRows(order) }
                    if (!order.payments.isNullOrEmpty()) {
                        Spacer(modifier = Modifier.height(AppDimens.M))
                        SectionTitle("付款记录")
                        order.payments!!.forEachIndexed { idx, payment ->
                            if (idx > 0) Spacer(modifier = Modifier.height(AppDimens.S))
                            PaymentRecordCard(payment)
                        }
                    }
                    if (order.statusValue == OrderStatus.COLLECTED || order.refundStatusValue != OrderRefundStatus.NONE) {
                        Spacer(modifier = Modifier.height(AppDimens.M))
                        SectionTitle("课时进度")
                        InfoCard { ProgressRows(order) }
                    }
                }
            }
        }

        // 底部按钮栏
        if (order != null) {
            BottomActionBar(
                order = order,
                onCancel = { showCancelDialog = true },
                onVoucher = { onUploadVoucher(order) },
                onStudy = {
                    val childId = order.child?.childId
                    val courseId = order.course?.courseId
                    if (childId != null && courseId != null) {
                        onStudy(childId, courseId, order.course?.title ?: "课程学习")
                    } else {
                        Toast.makeText(context, "课程信息缺失", Toast.LENGTH_SHORT).show()
                    }
                },
                onRefundDetail = {
                    val refundId = order.latestRefundId
                    if (refundId != null) onRefundDetail(refundId)
                    else Toast.makeText(context, "退款单不存在", Toast.LENGTH_SHORT).show()
                },
                onReorder = {
                    val courseId = order.course?.courseId
                    if (courseId != null) onReorder(courseId)
                    else Toast.makeText(context, "课程信息缺失", Toast.LENGTH_SHORT).show()
                },
                onRefund = { onRefund(order) }
            )
        }
    }

    // 取消订单确认弹窗
    if (showCancelDialog) {
        AlertDialog(
            onDismissRequest = { showCancelDialog = false },
            title = { Text("取消订单", fontWeight = FontWeight.SemiBold) },
            text = { Text("确定取消该待付款订单吗？") },
            confirmButton = {
                TextButton(onClick = {
                    showCancelDialog = false
                    viewModel.cancelOrderFromDetail(
                        orderId,
                        onSuccess = { Toast.makeText(context, "订单已取消", Toast.LENGTH_SHORT).show() },
                        onError = { Toast.makeText(context, it, Toast.LENGTH_SHORT).show() }
                    )
                }) { Text("取消订单", color = AppColors.Danger) }
            },
            dismissButton = {
                TextButton(onClick = { showCancelDialog = false }) { Text("再想想") }
            }
        )
    }
}

// MARK: - 状态卡

@Composable
private fun StatusCard(title: String, desc: String, toneColor: Color) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L, vertical = AppDimens.Xs)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.L)
    ) {
        Text(text = title, color = toneColor, fontSize = 17.sp, fontWeight = FontWeight.Bold)
        Spacer(modifier = Modifier.height(6.dp))
        Text(text = desc, color = AppColors.Sub, fontSize = 13.sp, lineHeight = 19.sp)
    }
}

// MARK: - 课程卡

@Composable
private fun CourseCard(title: String, subtitle: String) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L, vertical = AppDimens.Xs)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.L)
    ) {
        Text(text = title, color = AppColors.Ink, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, maxLines = 2)
        if (subtitle.isNotEmpty()) {
            Spacer(modifier = Modifier.height(6.dp))
            Text(text = subtitle, color = AppColors.Sub, fontSize = 13.sp, maxLines = 2)
        }
    }
}

// MARK: - 区块标题

@Composable
private fun SectionTitle(text: String) {
    Text(
        text = text,
        color = AppColors.Sub,
        fontSize = 15.sp,
        modifier = Modifier.padding(start = AppDimens.L + 4.dp, bottom = AppDimens.S)
    )
}

// MARK: - 信息卡容器

@Composable
private fun InfoCard(content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.L, vertical = AppDimens.Xs)
    ) {
        content()
    }
}

// MARK: - 订单信息行

@Composable
private fun OrderInfoRows(order: OrderItem) {
    InfoRow(label = "订单号", value = order.orderNo ?: "-")
    order.childName?.takeIf { it.isNotEmpty() }?.let { InfoRow(label = "上课孩子", value = it) }
    order.sourceText?.takeIf { it.isNotEmpty() }?.let { InfoRow(label = "报名来源", value = it) }
    order.klass?.name?.takeIf { it.isNotEmpty() }?.let { InfoRow(label = "上课班级", value = it) }
    InfoRow(label = "下单时间", value = fmtTime(order.createdAt))
    InfoRow(label = "课程费用", value = (order.totalAmount ?: 0).fenToYuanText())
    if (order.statusValue == OrderStatus.COLLECTED) {
        InfoRow(label = "实付金额", value = (order.paidAmount ?: order.totalAmount ?: 0).fenToYuanText(), valueColor = AppColors.Clay)
        val method = order.payMethodText ?: order.latestPayment?.methodText
        method?.takeIf { it.isNotEmpty() }?.let { InfoRow(label = "付款方式", value = it) }
    }
}

// MARK: - 课时进度行

@Composable
private fun ProgressRows(order: OrderItem) {
    val consumed = order.consumedLessons ?: 0
    val total = order.totalLessons ?: 0
    val remaining = order.remainingLessons ?: maxOf(total - consumed, 0)
    InfoRow(label = "已上课时", value = "${consumed}节（已消课）")
    val refundHint = if (order.statusValue == OrderStatus.COLLECTED) {
        val est = estimatedRefundFen(order)
        "${remaining}节 · 约可退${est.fenToYuanText()}"
    } else {
        "${remaining}节"
    }
    InfoRow(
        label = "剩余课时",
        value = refundHint,
        valueColor = if (order.statusValue == OrderStatus.COLLECTED) AppColors.Clay else AppColors.Ink
    )
}

private fun estimatedRefundFen(order: OrderItem): Int {
    val total = order.totalLessons ?: 0
    val remaining = order.remainingLessons ?: 0
    val paid = order.paidAmount ?: order.totalAmount ?: 0
    if (total <= 0) return 0
    return (paid.toDouble() * remaining / total).toInt()
}

// MARK: - 付款记录卡

@Composable
private fun PaymentRecordCard(payment: PaymentItem) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.L)
    ) {
        // 方式 + 金额
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = payment.methodText,
                color = AppColors.Ink,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.weight(1f)
            )
            Text(
                text = payment.amountText,
                color = AppColors.Clay,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            )
        }
        Spacer(modifier = Modifier.height(AppDimens.S))
        // 状态 badge + 上传方 · 时间
        Row(verticalAlignment = Alignment.CenterVertically) {
            PaymentStatusBadge(payment)
            Spacer(modifier = Modifier.width(AppDimens.S))
            val who = if (payment.isFromStudio) "工作室代登记" else "家长上传"
            Text(
                text = "$who · ${payment.timeText}",
                color = AppColors.Muted,
                fontSize = 12.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        // 备注
        payment.payerNote?.takeIf { it.isNotEmpty() }?.let { note ->
            Spacer(modifier = Modifier.height(AppDimens.S))
            Text(text = "备注：$note", color = AppColors.Sub, fontSize = 13.sp)
        }
        // 驳回原因
        if (payment.statusValue == PaymentStatus.REJECTED) {
            payment.rejectReason?.takeIf { it.isNotEmpty() }?.let { reason ->
                Spacer(modifier = Modifier.height(6.dp))
                Text(text = "未通过：$reason", color = AppColors.Danger, fontSize = 13.sp)
            }
        }
        // 凭证缩略图
        val images = payment.images
        if (images.isNotEmpty()) {
            Spacer(modifier = Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(AppDimens.S)) {
                images.take(4).forEach { url ->
                    AsyncImage(
                        model = resolveImageUrl(url),
                        contentDescription = "付款凭证",
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .size(56.dp)
                            .clip(RoundedCornerShape(8.dp))
                    )
                }
            }
        }
    }
}

// MARK: - 底部按钮栏

@Composable
private fun BottomActionBar(
    order: OrderItem,
    onCancel: () -> Unit,
    onVoucher: () -> Unit,
    onStudy: () -> Unit,
    onRefundDetail: () -> Unit,
    onReorder: () -> Unit,
    onRefund: () -> Unit
) {
    // 计算按钮配置：primary(文案, 可点) / secondary(文案?, 显示)
    data class BtnCfg(val primaryText: String, val primaryEnabled: Boolean, val secondaryText: String?)

    val cfg = if (order.refundStatusValue != OrderRefundStatus.NONE) {
        if (order.refundStatusValue == OrderRefundStatus.REJECTED) {
            BtnCfg("查看退款", true, "再次申请退款")
        } else {
            val text = if (order.refundStatusValue == OrderRefundStatus.PROCESSING) "查看退款进度" else "查看退款"
            BtnCfg(text, true, null)
        }
    } else {
        when (order.statusValue) {
            OrderStatus.PENDING_COLLECT -> {
                val hasRejected = order.rejectedPayment != null
                BtnCfg(if (hasRejected) "重新上传凭证" else "上传付款凭证", true, "取消订单")
            }
            OrderStatus.PAYMENT_REVIEW -> BtnCfg("凭证审核中 · 等待机构确认", false, null)
            OrderStatus.COLLECTED -> {
                if (order.canApplyRefund == true) BtnCfg("去学习", true, "申请退款")
                else BtnCfg("去学习", true, null)
            }
            OrderStatus.REFUND_REVIEW, OrderStatus.REFUND_CONFIRM, OrderStatus.REFUNDED -> BtnCfg("查看退款", true, null)
            OrderStatus.CANCELLED -> BtnCfg("重新报名", true, null)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.L, vertical = AppDimens.M)
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(AppDimens.M), modifier = Modifier.fillMaxWidth()) {
            // 次按钮
            if (cfg.secondaryText != null) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(44.dp)
                        .clip(RoundedCornerShape(22.dp))
                        .background(AppColors.SurfaceAlt)
                        .clickable {
                            when {
                                order.refundStatusValue == OrderRefundStatus.REJECTED -> onRefund()
                                order.statusValue == OrderStatus.PENDING_COLLECT -> onCancel()
                                order.statusValue == OrderStatus.COLLECTED -> onRefund()
                            }
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Text(text = cfg.secondaryText, color = AppColors.Ink, fontSize = 15.sp, fontWeight = FontWeight.Medium)
                }
            }
            // 主按钮
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(44.dp)
                    .clip(RoundedCornerShape(22.dp))
                    .background(if (cfg.primaryEnabled) AppColors.Brand else AppColors.Line)
                    .clickable(enabled = cfg.primaryEnabled) {
                        if (order.refundStatusValue != OrderRefundStatus.NONE) {
                            onRefundDetail()
                        } else {
                            when (order.statusValue) {
                                OrderStatus.PENDING_COLLECT -> onVoucher()
                                OrderStatus.COLLECTED -> onStudy()
                                OrderStatus.REFUND_REVIEW, OrderStatus.REFUND_CONFIRM, OrderStatus.REFUNDED -> onRefundDetail()
                                OrderStatus.CANCELLED -> onReorder()
                                OrderStatus.PAYMENT_REVIEW -> {}
                            }
                        }
                    },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = cfg.primaryText,
                    color = if (cfg.primaryEnabled) Color.White else AppColors.Sub,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
    }
}

// MARK: - 状态卡数据（退款聚合优先）

private fun OrderItem.statusInfo(): Triple<String, String, Color> {
    when (refundStatusValue) {
        OrderRefundStatus.PROCESSING ->
            return Triple("退款中", "退款处理中，请等待机构线下退款并留意确认通知", AppColors.Warn)
        OrderRefundStatus.REFUNDED ->
            return Triple("已退款", "退款 ${(refunds?.firstOrNull()?.amount ?: 0).fenToYuanText()}，请确认是否已收到", AppColors.Brand)
        OrderRefundStatus.REJECTED ->
            return Triple("退款已驳回", "退款申请未通过，如有疑问请联系机构", AppColors.Danger)
        OrderRefundStatus.NONE -> {}
    }
    return when (statusValue) {
        OrderStatus.PENDING_COLLECT -> {
            val rejected = rejectedPayment
            if (rejected?.rejectReason?.isNotEmpty() == true) {
                Triple("凭证未通过", "原因：${rejected.rejectReason}\n请重新上传付款凭证", AppColors.Danger)
            } else {
                Triple("待付款", "请与机构线下完成付款，并上传付款凭证；机构确认后发放课时", AppColors.Warn)
            }
        }
        OrderStatus.PAYMENT_REVIEW ->
            Triple("待机构确认", "付款凭证已提交，等待机构确认，确认后课时自动到账", AppColors.Warn)
        OrderStatus.COLLECTED ->
            Triple("已报名 · 学习中", "已完成${consumedLessons ?: 0}/${totalLessons ?: 0}节 · 剩余${remainingLessons ?: 0}节", AppColors.Brand)
        OrderStatus.REFUND_REVIEW ->
            Triple("退款审核中", "退款申请正在审核中，请等待机构处理", AppColors.Warn)
        OrderStatus.REFUND_CONFIRM ->
            Triple("待确认退款", "机构已审核通过退款，请确认退款信息", AppColors.Warn)
        OrderStatus.REFUNDED ->
            Triple("已退款", "退款已完成", AppColors.Brand)
        OrderStatus.CANCELLED ->
            Triple("已取消", "订单已取消，可重新报名", AppColors.Sub)
    }
}

@Composable
private fun PaymentStatusBadge(payment: PaymentItem) {
    val (color, bg) = when (payment.statusValue) {
        PaymentStatus.CONFIRMED -> AppColors.Brand to AppColors.BrandSoft
        PaymentStatus.PENDING -> AppColors.Warn to AppColors.WarnTint
        PaymentStatus.REJECTED -> AppColors.Danger to AppColors.DangerTint
    }
    Text(
        text = payment.statusText ?: payment.statusValue.text,
        color = color,
        fontSize = 11.sp,
        fontWeight = FontWeight.Medium,
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(bg)
            .padding(horizontal = AppDimens.S, vertical = 2.dp)
    )
}