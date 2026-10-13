package com.together.app.modules.order.ui

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
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
import com.together.app.core.model.RefundDetail
import com.together.app.core.model.RefundStep
import com.together.app.core.model.fmtTime
import com.together.app.modules.order.OrderViewModel

/**
 * 退款详情（家长端）
 * 对齐 iOS RefundDetailViewController
 *
 * 状态流转：提交申请(0待审核) → 机构审核并线下退款(1待家长确认) → 家长确认收到(3已退款)；驳回为 2
 */
@Composable
fun RefundDetailScreen(
    refundId: String,
    onBack: () -> Unit,
    viewModel: OrderViewModel = viewModel()
) {
    val context = LocalContext.current
    val refundState by viewModel.refundState.collectAsState()
    var showConfirmDialog by remember { mutableStateOf(false) }

    LaunchedEffect(refundId) { viewModel.loadRefund(refundId) }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "退款详情", onBack = onBack)

        Box(modifier = Modifier.weight(1f)) {
            when {
                refundState.loading -> LoadingView()
                refundState.error != null -> ErrorView(
                    message = refundState.error!!,
                    onRetry = { viewModel.loadRefund(refundId) }
                )
                refundState.refund != null -> {
                    val refund = refundState.refund!!
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                            .padding(bottom = if (refund.canConfirm == true) 80.dp else 24.dp)
                    ) {
                        // 1. 状态卡
                        StatusCard(refund = refund)
                        Spacer(Modifier.height(AppDimens.M))

                        // 2. 退款信息
                        SectionTitle("退款信息")
                        InfoCardContainer { RefundInfoRows(refund) }

                        // 3. 机构打款凭证（如有）
                        if (!refund.voucherImages.isNullOrEmpty()) {
                            Spacer(Modifier.height(AppDimens.M))
                            SectionTitle("机构打款凭证")
                            VoucherRow(images = refund.voucherImages!!)
                        }

                        // 4. 退款进度
                        Spacer(Modifier.height(AppDimens.M))
                        SectionTitle("退款进度")
                        InfoCardContainer { RefundSteps(refund.steps ?: emptyList()) }
                    }
                }
                else -> EmptyStateView(message = "退款单不存在")
            }
        }

        // 底部确认按钮（canConfirm 时显示）
        if (refundState.refund?.canConfirm == true) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = AppDimens.L, vertical = AppDimens.M)
                    .height(44.dp)
                    .clip(RoundedCornerShape(22.dp))
                    .background(if (refundState.confirming) AppColors.Muted else AppColors.Brand)
                    .clickable(enabled = !refundState.confirming) { showConfirmDialog = true },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    if (refundState.confirming) "提交中..." else "确认收到退款",
                    color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Medium
                )
            }
        }
    }

    // 确认退款对话框
    if (showConfirmDialog) {
        AlertDialog(
            onDismissRequest = { showConfirmDialog = false },
            title = { Text("请确认已收到退款") },
            text = { Text("请确认你已在线下实际收到机构退回的款项。确认后将扣减相应课时、订单转为已退款，且不可撤销。") },
            confirmButton = {
                TextButton(onClick = {
                    showConfirmDialog = false
                    viewModel.confirmRefund(
                        refundId,
                        onSuccess = { Toast.makeText(context, "已确认收款", Toast.LENGTH_SHORT).show() },
                        onError = { Toast.makeText(context, it, Toast.LENGTH_SHORT).show() }
                    )
                }) { Text("已收到，确认", color = AppColors.Brand) }
            },
            dismissButton = {
                TextButton(onClick = { showConfirmDialog = false }) { Text("再想想") }
            }
        )
    }
}

// MARK: - 区块标题

@Composable
private fun SectionTitle(text: String) {
    Text(
        text = text,
        color = AppColors.Ink,
        fontSize = 16.sp,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier.padding(start = AppDimens.L + 4.dp, bottom = AppDimens.S)
    )
}

// MARK: - 状态卡

@Composable
private fun StatusCard(refund: RefundDetail) {
    val (desc, statusColor) = when (refund.status) {
        0 -> "退款申请已提交，等待机构审核" to AppColors.Brand
        1 -> "机构已登记线下退款，请核对下方凭证后，点击底部「确认收到退款」" to AppColors.Brand
        2 -> "申请未通过，可查看驳回原因后在订单详情重新申请" to AppColors.Danger
        3 -> "退款已完成，相应课时已扣减" to AppColors.Brand
        else -> "退款处理中，请留意到账通知" to AppColors.Brand
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L, vertical = AppDimens.Xs)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.L)
    ) {
        Text(refund.statusText ?: "退款", color = statusColor, fontSize = 17.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(AppDimens.S))
        Text(refund.amountText ?: "-", color = AppColors.Ink, fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(2.dp))
        Text(desc, color = AppColors.Sub, fontSize = 13.sp, lineHeight = 19.sp)
    }
}

// MARK: - 信息卡容器

@Composable
private fun InfoCardContainer(content: @Composable () -> Unit) {
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

// MARK: - 退款信息行

@Composable
private fun RefundInfoRows(refund: RefundDetail) {
    InfoRow(label = "申请课时", value = "${refund.requestedLessons ?: 0}节（可退 ${refund.refundableLessons ?: 0}节）")
    val approved = refund.approvedLessons
    if (approved != null) {
        val requested = refund.requestedLessons ?: approved
        if (approved < requested) {
            InfoRow(label = "本次实退", value = "${approved}节（申请${requested}节，期间已上课）", valueColor = AppColors.Warn)
        } else {
            InfoRow(label = "本次实退", value = "${approved}节", valueColor = AppColors.Brand)
        }
    }
    refund.refundMethodText?.takeIf { it.isNotEmpty() }?.let { InfoRow(label = "退款方式", value = it) }
    refund.unitPriceText?.takeIf { it.isNotEmpty() }?.let { InfoRow(label = "课时单价", value = it) }
    InfoRow(label = "退款金额", value = refund.amountText ?: "-", valueColor = AppColors.Brand)
    if (refund.status == 2) {
        refund.rejectReason?.takeIf { it.isNotEmpty() }?.let {
            InfoRow(label = "驳回原因", value = it, valueColor = AppColors.Danger)
        }
    }
    refund.reason?.takeIf { it.isNotEmpty() }?.let { InfoRow(label = "退款原因", value = it) }
    refund.createdAt?.let { InfoRow(label = "申请时间", value = fmtTime(it)) }
    refund.reviewedAt?.let { InfoRow(label = "审核时间", value = fmtTime(it)) }
    refund.confirmedAt?.let { InfoRow(label = "确认时间", value = fmtTime(it)) }
}

// MARK: - 机构打款凭证横滑

@Composable
private fun VoucherRow(images: List<String>) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(vertical = 12.dp)
    ) {
        LazyRow(
            contentPadding = PaddingValues(horizontal = AppDimens.L),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(images) { url ->
                AsyncImage(
                    model = resolveImageUrl(url),
                    contentDescription = "打款凭证",
                    modifier = Modifier.size(88.dp).clip(RoundedCornerShape(10.dp)),
                    contentScale = ContentScale.Crop
                )
            }
        }
    }
}

// MARK: - 退款进度时间线

@Composable
private fun RefundSteps(steps: List<RefundStep>) {
    steps.forEachIndexed { idx, step ->
        val isLast = idx == steps.size - 1
        val isActive = step.current == true || step.done == true
        val timeText = when {
            !step.time.isNullOrBlank() -> fmtTime(step.time)
            step.current == true -> "等待处理中"
            else -> "-"
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(IntrinsicSize.Min)
                .padding(vertical = 4.dp)
        ) {
            // 左侧：圆点 + 连线
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.fillMaxHeight().padding(top = 4.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(10.dp)
                        .clip(CircleShape)
                        .background(if (isActive) AppColors.Brand else AppColors.Line)
                )
                if (!isLast) {
                    Spacer(Modifier.height(4.dp))
                    Box(
                        modifier = Modifier
                            .width(2.dp)
                            .weight(1f)
                            .background(AppColors.Line)
                    )
                }
            }
            Spacer(Modifier.width(AppDimens.M))
            // 右侧：标题 + 时间
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(bottom = if (isLast) 0.dp else 12.dp)
            ) {
                Text(step.title ?: "", color = if (isActive) AppColors.Ink else AppColors.Sub, fontSize = 15.sp)
                Spacer(Modifier.height(4.dp))
                Text(timeText, color = AppColors.Sub, fontSize = 12.sp)
            }
        }
    }
}