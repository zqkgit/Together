package com.together.app.modules.studio.ui

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.Undo
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.studio.StudioViewModel

/** 待办行数据 */
private data class TodoRow(
    val icon: ImageVector,
    val tint: Color,
    val soft: Color,
    val title: String,
    val detail: String,
    val badge: Int,
    val onClick: () -> Unit
)

/**
 * 工作室「待办事项」页（对齐 iOS StudioTodoViewController）
 *
 * 聚合：退款审核（待审核）/ 待打款确认 / 订单待结算。
 * 前两类进入退款审核对应分段，结算暂在 Web 端处理。
 */
@Composable
fun StudioTodoScreen(
    onBack: () -> Unit = {},
    onRefundReview: () -> Unit = {},
    onRefundPayout: () -> Unit = {},
    viewModel: StudioViewModel = viewModel()
) {
    val state by viewModel.overviewState.collectAsState()
    val context = LocalContext.current

    // ON_RESUME 刷新（审核返回后刷新角标）
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                viewModel.loadOverview()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val todos = state.data?.todos
    val pendingRefunds = todos?.pendingRefundCount ?: 0
    val pendingPayouts = todos?.pendingPayoutCount ?: 0
    val pendingSettleOrders = todos?.pendingSettleOrderCount ?: 0

    val rows = listOf(
        TodoRow(
            icon = Icons.Filled.Undo,
            tint = AppColors.Danger,
            soft = AppColors.DangerTint,
            title = "退款审核",
            detail = if (pendingRefunds > 0) "$pendingRefunds 笔退款申请待审核" else "暂无待审核退款",
            badge = pendingRefunds,
            onClick = onRefundReview
        ),
        TodoRow(
            icon = Icons.Filled.Payments,
            tint = AppColors.Warn,
            soft = AppColors.WarnTint,
            title = "待打款确认",
            detail = if (pendingPayouts > 0) "$pendingPayouts 笔退款待打款确认" else "暂无待打款退款",
            badge = pendingPayouts,
            onClick = onRefundPayout
        ),
        TodoRow(
            icon = Icons.Filled.Description,
            tint = AppColors.Brand,
            soft = AppColors.BrandSoft,
            title = "订单结算",
            detail = if (pendingSettleOrders > 0)
                "$pendingSettleOrders 笔订单待结算 · ${todos?.pendingSettleAmountText ?: "¥ 0"}"
            else "暂无待结算订单",
            badge = pendingSettleOrders,
            onClick = {
                Toast.makeText(context, "订单结算请在 Web 工作室后台处理，App 端即将开放", Toast.LENGTH_SHORT).show()
            }
        )
    )

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "待办事项", onBack = onBack)

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(horizontal = AppDimens.M, vertical = AppDimens.S)
        ) {
            items(rows) { row ->
                TodoCard(row)
            }
        }
    }
}

// MARK: - 待办卡片

@Composable
private fun TodoCard(row: TodoRow) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp)
            .height(76.dp)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable { row.onClick() }
            .padding(horizontal = AppDimens.CardInner),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // 图标块
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(row.soft),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = row.icon,
                contentDescription = null,
                tint = row.tint,
                modifier = Modifier.size(20.dp)
            )
        }
        Spacer(modifier = Modifier.width(AppDimens.M))
        // 标题 + 详情
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = row.title,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink
            )
            Text(
                text = row.detail,
                fontSize = 12.sp,
                color = AppColors.Muted,
                modifier = Modifier.padding(top = 4.dp)
            )
        }
        // 角标
        if (row.badge > 0) {
            Text(
                text = if (row.badge > 99) "99+" else "${row.badge}",
                color = Color.White,
                fontSize = 11.sp,
                modifier = Modifier
                    .clip(RoundedCornerShape(10.dp))
                    .background(AppColors.Danger)
                    .padding(horizontal = 7.dp, vertical = 2.dp)
            )
            Spacer(modifier = Modifier.width(AppDimens.S))
        }
        // 箭头
        Icon(
            imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = AppColors.Muted,
            modifier = Modifier.size(16.dp)
        )
    }
}