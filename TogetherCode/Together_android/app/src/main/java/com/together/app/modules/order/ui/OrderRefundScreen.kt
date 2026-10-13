package com.together.app.modules.order.ui

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.OrderItem
import com.together.app.modules.order.OrderViewModel

/**
 * 申请退款表单页（家长端）
 * 对齐 iOS OrderRefundViewController
 *
 * 退款课时（默认剩余课时）+ 退款原因（2x2 网格 + 自定义）+ 退款说明
 */
@Composable
fun OrderRefundScreen(
    order: OrderItem,
    onBack: () -> Unit,
    onSuccess: () -> Unit,
    viewModel: OrderViewModel = viewModel()
) {
    val context = LocalContext.current
    val refundState by viewModel.refundRequestState.collectAsState()

    val remainingLessons = maxOf(0, order.remainingLessons ?: order.totalLessons ?: 0)
    var lessonsText by remember { mutableStateOf(remainingLessons.toString()) }
    var selectedReason by remember { mutableStateOf("") }
    var customReason by remember { mutableStateOf("") }

    val reasons = listOf("课程不适合孩子", "时间安排冲突", "工作室原因", "其他")

    // 提交成功 → Toast + 回调 + 返回
    LaunchedEffect(refundState.success) {
        if (refundState.success) {
            Toast.makeText(context, "退款申请已提交", Toast.LENGTH_SHORT).show()
            viewModel.resetRefundRequestState()
            onSuccess()
            onBack()
        }
    }

    // 提交失败 → Toast
    LaunchedEffect(refundState.error) {
        refundState.error?.let {
            Toast.makeText(context, it, Toast.LENGTH_SHORT).show()
            viewModel.clearRefundRequestError()
        }
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "申请退款", onBack = onBack)

        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(bottom = 76.dp)
        ) {
            // 1. 订单卡
            OrderBriefCard(order = order)
            Spacer(Modifier.height(AppDimens.M))

            // 2. 表单卡：课时 + 原因
            FormCard(
                lessonsText = lessonsText,
                onLessonsChange = { lessonsText = it.filter { c -> c.isDigit() } },
                remainingLessons = remainingLessons,
                reasons = reasons,
                selectedReason = selectedReason,
                onSelectReason = { selectedReason = it },
                customReason = customReason,
                onCustomReasonChange = { customReason = it }
            )
            Spacer(Modifier.height(AppDimens.M))

            // 3. 退款说明卡
            TipsCard()
        }

        // 4. 底部提交按钮
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = AppDimens.L, vertical = AppDimens.M)
                .height(44.dp)
                .clip(RoundedCornerShape(22.dp))
                .background(if (refundState.submitting) AppColors.Muted else AppColors.Brand)
                .clickable(enabled = !refundState.submitting) {
                    val lessons = lessonsText.toIntOrNull() ?: 0
                    when {
                        lessons <= 0 -> Toast.makeText(context, "请输入退款课时数", Toast.LENGTH_SHORT).show()
                        lessons > remainingLessons -> Toast.makeText(context, "最多可退 $remainingLessons 课时", Toast.LENGTH_SHORT).show()
                        selectedReason.isEmpty() -> Toast.makeText(context, "请选择退款原因", Toast.LENGTH_SHORT).show()
                        else -> {
                            val reason = if (selectedReason == "其他") {
                                customReason.trim().ifEmpty { "其他" }
                            } else {
                                selectedReason
                            }
                            order.orderId?.let { viewModel.requestRefund(it, lessons, reason) }
                        }
                    }
                },
            contentAlignment = Alignment.Center
        ) {
            Text(
                if (refundState.submitting) "提交中..." else "提交退款申请",
                color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Medium
            )
        }
    }
}

// MARK: - 订单卡

@Composable
private fun OrderBriefCard(order: OrderItem) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.L)
    ) {
        Text(order.courseTitleWithLessons, color = AppColors.Ink, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, maxLines = 2)
        Spacer(Modifier.height(AppDimens.S))
        val subParts = mutableListOf(order.studioTeacherText)
        order.childName?.let { subParts.add(it) }
        Text(subParts.joinToString(" · "), color = AppColors.Sub, fontSize = 13.sp)
        Spacer(Modifier.height(AppDimens.S))
        Text("订单号 ${order.orderNo ?: "-"}", color = AppColors.Muted, fontSize = 12.sp)
    }
}

// MARK: - 表单卡（课时 + 原因）

@Composable
private fun FormCard(
    lessonsText: String,
    onLessonsChange: (String) -> Unit,
    remainingLessons: Int,
    reasons: List<String>,
    selectedReason: String,
    onSelectReason: (String) -> Unit,
    customReason: String,
    onCustomReasonChange: (String) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.L)
    ) {
        // 退款课时
        Text("退款课时", color = AppColors.Sub, fontSize = 13.sp)
        Spacer(Modifier.height(AppDimens.S))
        Row(verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(
                value = lessonsText,
                onValueChange = onLessonsChange,
                modifier = Modifier.width(120.dp),
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = AppColors.Brand,
                    unfocusedBorderColor = AppColors.Line,
                    focusedContainerColor = AppColors.Bg,
                    unfocusedContainerColor = AppColors.Bg,
                    cursorColor = AppColors.Brand,
                    focusedTextColor = AppColors.Ink,
                    unfocusedTextColor = AppColors.Ink
                ),
                shape = RoundedCornerShape(AppDimens.RadiusInput)
            )
            Spacer(Modifier.width(AppDimens.S))
            Text("课时（剩余 $remainingLessons 课时）", color = AppColors.Sub, fontSize = 13.sp)
        }

        Spacer(Modifier.height(AppDimens.L))

        // 退款原因（2x2 网格，选中品牌绿底白字）
        Text("退款原因", color = AppColors.Sub, fontSize = 13.sp)
        Spacer(Modifier.height(AppDimens.S))
        for (row in 0 until 2) {
            if (row > 0) Spacer(Modifier.height(AppDimens.S))
            Row(horizontalArrangement = Arrangement.spacedBy(AppDimens.S), modifier = Modifier.fillMaxWidth()) {
                for (col in 0 until 2) {
                    val reason = reasons[row * 2 + col]
                    val selected = reason == selectedReason
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(30.dp)
                            .clip(RoundedCornerShape(15.dp))
                            .background(if (selected) AppColors.Brand else AppColors.SurfaceAlt)
                            .border(
                                width = if (selected) 0.dp else 1.dp,
                                color = AppColors.Line,
                                shape = RoundedCornerShape(15.dp)
                            )
                            .clickable { onSelectReason(reason) },
                        contentAlignment = Alignment.Center
                    ) {
                        Text(reason, color = if (selected) Color.White else AppColors.Sub, fontSize = 13.sp)
                    }
                }
            }
        }

        // 自定义原因（仅「其他」时显示）
        if (selectedReason == "其他") {
            Spacer(Modifier.height(AppDimens.S))
            OutlinedTextField(
                value = customReason,
                onValueChange = onCustomReasonChange,
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("请说明退款原因", color = AppColors.Muted, fontSize = 14.sp) },
                singleLine = true,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = AppColors.Brand,
                    unfocusedBorderColor = AppColors.Line,
                    focusedContainerColor = AppColors.Bg,
                    unfocusedContainerColor = AppColors.Bg,
                    cursorColor = AppColors.Brand,
                    focusedTextColor = AppColors.Ink,
                    unfocusedTextColor = AppColors.Ink
                ),
                shape = RoundedCornerShape(AppDimens.RadiusInput)
            )
        }
    }
}

// MARK: - 退款说明卡

@Composable
private fun TipsCard() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.L)
    ) {
        Text("退款说明", color = AppColors.Ink, fontSize = 15.sp, fontWeight = FontWeight.Medium)
        Spacer(Modifier.height(AppDimens.S))
        Text("· 按剩余课时比例退回实付金额", color = AppColors.Sub, fontSize = 13.sp)
        Spacer(Modifier.height(AppDimens.Xs))
        Text("· 提交后由工作室审核，审核通过后原路退回", color = AppColors.Sub, fontSize = 13.sp)
    }
}