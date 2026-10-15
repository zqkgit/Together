package com.together.app.modules.order.ui

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import com.together.app.core.component.AppPullRefreshBox
import androidx.compose.material3.ExperimentalMaterial3Api
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.component.EmptyStateView
import com.together.app.core.component.ErrorView
import com.together.app.core.component.LoadingView
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.OrderItem
import com.together.app.core.model.OrderRefundStatus
import com.together.app.core.model.OrderStatus
import com.together.app.modules.order.OrderViewModel
import com.together.app.modules.order.OrderViewModel.OrderTab

/**
 * 我的订单（家长端 · 线下收款模式）
 * 对齐 iOS MyOrdersViewController
 *
 * Tab：全部 / 待付款 / 待确认 / 已报名 / 已取消 / 已退款
 * 平台不经手资金：待付款订单线下付款后上传凭证，机构确认收款发课时。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MyOrdersScreen(
    onBack: () -> Unit,
    onOrderClick: (String) -> Unit,
    onUploadVoucher: (OrderItem) -> Unit,
    onStudy: (childId: String, courseId: String, title: String) -> Unit,
    onRefundDetail: (String) -> Unit,
    onReorder: (String) -> Unit,
    viewModel: OrderViewModel = viewModel()
) {
    val listState by viewModel.listState.collectAsState()
    var cancelTarget by remember { mutableStateOf<OrderItem?>(null) }
    val context = LocalContext.current

    LaunchedEffect(Unit) { viewModel.loadOrders() }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "我的订单", onBack = onBack)

        // Tab 横滑行
        TabChipRow(
            selectedTab = listState.selectedTab,
            onSelect = viewModel::selectTab
        )

        // 内容区
        Box(modifier = Modifier.weight(1f)) {
            when {
                listState.loading && listState.orders.isEmpty() -> LoadingView()
                listState.error != null && listState.orders.isEmpty() -> ErrorView(
                    message = listState.error!!,
                    onRetry = { viewModel.loadOrders() }
                )
                listState.orders.isEmpty() -> EmptyStateView(message = "暂无订单")
                else -> AppPullRefreshBox(
                    isRefreshing = listState.loading,
                    onRefresh = { viewModel.loadOrders() },
                    modifier = Modifier.fillMaxSize()
                ) {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = AppDimens.L, vertical = AppDimens.Xs)
                    ) {
                        items(listState.orders, key = { it.orderId ?: it.orderNo ?: "" }) { order ->
                            OrderCard(
                                order = order,
                                onClick = { order.orderId?.let(onOrderClick) },
                                onCancel = { cancelTarget = order },
                                onVoucher = { onUploadVoucher(order) },
                                onStudy = {
                                    val childId = order.child?.childId ?: return@OrderCard
                                    val courseId = order.course?.courseId ?: return@OrderCard
                                    onStudy(childId, courseId, order.course?.title ?: "课程学习")
                                },
                                onRefundDetail = { order.latestRefundId?.let(onRefundDetail) },
                                onReorder = { order.course?.courseId?.let(onReorder) }
                            )
                        }
                    }
                }
            }
        }
    }

    // 取消订单确认弹窗
    cancelTarget?.let { order ->
        AlertDialog(
            onDismissRequest = { cancelTarget = null },
            title = { Text("取消订单", fontWeight = FontWeight.SemiBold) },
            text = { Text("确定取消该待付款订单吗？") },
            confirmButton = {
                TextButton(onClick = {
                    val orderId = order.orderId
                    cancelTarget = null
                    if (orderId != null) {
                        viewModel.cancelOrder(orderId) { msg ->
                            Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
                        }
                    }
                }) { Text("取消订单", color = AppColors.Danger) }
            },
            dismissButton = {
                TextButton(onClick = { cancelTarget = null }) { Text("再想想") }
            }
        )
    }
}

// MARK: - Tab 横滑行

@Composable
private fun TabChipRow(
    selectedTab: OrderTab,
    onSelect: (OrderTab) -> Unit
) {
    LazyRow(
        modifier = Modifier.fillMaxWidth(),
        contentPadding = PaddingValues(horizontal = AppDimens.L, vertical = AppDimens.S),
        horizontalArrangement = Arrangement.spacedBy(AppDimens.S)
    ) {
        items(OrderTab.entries) { tab ->
            val selected = tab == selectedTab
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(AppDimens.RadiusTag))
                    .background(if (selected) AppColors.Brand else AppColors.SurfaceAlt)
                    .clickable { onSelect(tab) }
                    .padding(horizontal = AppDimens.M, vertical = AppDimens.Xs + 2.dp)
            ) {
                Text(
                    text = tab.title,
                    color = if (selected) Color.White else AppColors.Sub,
                    fontSize = 13.sp,
                    fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal
                )
            }
        }
    }
}

// MARK: - 订单卡片

@Composable
private fun OrderCard(
    order: OrderItem,
    onClick: () -> Unit,
    onCancel: () -> Unit,
    onVoucher: () -> Unit,
    onStudy: () -> Unit,
    onRefundDetail: () -> Unit,
    onReorder: () -> Unit
) {
    val badge = order.badgeInfo()
    val hint = order.hintInfo()

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable { onClick() }
            .padding(AppDimens.L)
    ) {
        // 标题行：课程名 + 状态 badge
        Row(verticalAlignment = Alignment.Top) {
            Text(
                text = order.courseTitleWithLessons,
                color = AppColors.Ink,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f)
            )
            Spacer(modifier = Modifier.width(AppDimens.S))
            StatusBadge(text = badge.first, color = badge.second, bgColor = badge.third)
        }

        // 副标题：机构 · 班级
        val subtitle = order.studioClassText
        if (subtitle.isNotEmpty()) {
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = subtitle,
                color = AppColors.Sub,
                fontSize = 12.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }

        // 提示
        if (hint != null) {
            Spacer(modifier = Modifier.height(10.dp))
            Text(
                text = hint.first,
                color = hint.second,
                fontSize = 12.sp
            )
        }

        // 底部行：金额 + 按钮
        Spacer(modifier = Modifier.height(12.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = order.amountText,
                color = AppColors.Clay,
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.weight(1f))
            OrderButtons(
                order = order,
                onCancel = onCancel,
                onVoucher = onVoucher,
                onStudy = onStudy,
                onRefundDetail = onRefundDetail,
                onReorder = onReorder
            )
        }
    }
}

// MARK: - 状态 Badge

@Composable
private fun StatusBadge(text: String, color: Color, bgColor: Color) {
    Text(
        text = text,
        color = color,
        fontSize = 11.sp,
        fontWeight = FontWeight.Medium,
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(bgColor)
            .padding(horizontal = AppDimens.S, vertical = 2.dp)
    )
}

// MARK: - 按钮行

@Composable
private fun OrderButtons(
    order: OrderItem,
    onCancel: () -> Unit,
    onVoucher: () -> Unit,
    onStudy: () -> Unit,
    onRefundDetail: () -> Unit,
    onReorder: () -> Unit
) {
    Row(horizontalArrangement = Arrangement.spacedBy(AppDimens.S)) {
        // 退款聚合优先
        if (order.refundStatusValue != OrderRefundStatus.NONE) {
            SmallButton(text = "查看退款", primary = false, onClick = onRefundDetail)
            return@Row
        }
        when (order.statusValue) {
            OrderStatus.PENDING_COLLECT -> {
                SmallButton(text = "取消", primary = false, onClick = onCancel)
                SmallButton(text = "上传凭证", primary = true, onClick = onVoucher)
            }
            OrderStatus.PAYMENT_REVIEW -> { /* 凭证审核中，无按钮 */ }
            OrderStatus.COLLECTED -> SmallButton(text = "去学习", primary = true, onClick = onStudy)
            OrderStatus.REFUND_REVIEW, OrderStatus.REFUND_CONFIRM -> {
                SmallButton(text = "查看退款", primary = false, onClick = onRefundDetail)
            }
            OrderStatus.REFUNDED -> { /* 无按钮 */ }
            OrderStatus.CANCELLED -> SmallButton(text = "重新报名", primary = true, onClick = onReorder)
        }
    }
}

@Composable
private fun SmallButton(text: String, primary: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .height(32.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(if (primary) AppColors.Brand else AppColors.SurfaceAlt)
            .clickable { onClick() }
            .padding(horizontal = 14.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            color = if (primary) Color.White else AppColors.Ink,
            fontSize = 13.sp,
            fontWeight = if (primary) FontWeight.SemiBold else FontWeight.Normal
        )
    }
}

// MARK: - 状态 Badge 数据（退款聚合优先）

private fun OrderItem.badgeInfo(): Triple<String, Color, Color> {
    // 退款聚合状态优先
    when (refundStatusValue) {
        OrderRefundStatus.PROCESSING -> return Triple("退款中", AppColors.Warn, AppColors.WarnTint)
        OrderRefundStatus.REFUNDED -> return Triple("已退款", AppColors.Brand, AppColors.BrandSoft)
        OrderRefundStatus.REJECTED -> return Triple("退款驳回", AppColors.Danger, AppColors.DangerTint)
        OrderRefundStatus.NONE -> {}
    }
    return when (statusValue) {
        OrderStatus.PENDING_COLLECT -> Triple("待付款", AppColors.Warn, AppColors.WarnTint)
        OrderStatus.PAYMENT_REVIEW -> Triple("待确认", AppColors.Warn, AppColors.WarnTint)
        OrderStatus.COLLECTED -> Triple("已报名", AppColors.Brand, AppColors.BrandSoft)
        OrderStatus.REFUND_REVIEW -> Triple("退款审核中", AppColors.Warn, AppColors.WarnTint)
        OrderStatus.REFUND_CONFIRM -> Triple("待确认退款", AppColors.Warn, AppColors.WarnTint)
        OrderStatus.REFUNDED -> Triple("已退款", AppColors.Brand, AppColors.BrandSoft)
        OrderStatus.CANCELLED -> Triple("已取消", AppColors.Muted, AppColors.SurfaceAlt)
    }
}

// MARK: - 提示文案（null = 不显示）

private fun OrderItem.hintInfo(): Pair<String, Color>? {
    when (refundStatusValue) {
        OrderRefundStatus.PROCESSING -> return "退款处理中，请留意机构线下退款" to AppColors.Warn
        OrderRefundStatus.REJECTED -> return "退款未通过，可在订单详情再次申请" to AppColors.Danger
        OrderRefundStatus.REFUNDED -> return null
        OrderRefundStatus.NONE -> {}
    }
    return when (statusValue) {
        OrderStatus.PENDING_COLLECT -> {
            if (rejectedPayment != null) "付款凭证未通过，请重新上传" to AppColors.Danger
            else "请线下付款后上传凭证，机构确认后发课时" to AppColors.Warn
        }
        OrderStatus.PAYMENT_REVIEW -> "凭证已提交，等待机构确认" to AppColors.Warn
        OrderStatus.COLLECTED -> "报名成功，课时已到账" to AppColors.Brand
        OrderStatus.REFUND_REVIEW -> "退款审核中，请等待机构处理" to AppColors.Warn
        OrderStatus.REFUND_CONFIRM -> "请确认退款信息" to AppColors.Warn
        OrderStatus.REFUNDED -> null
        OrderStatus.CANCELLED -> null
    }
}