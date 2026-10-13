@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.together.app.modules.mine.ui

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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.component.resolveImageUrl
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.mine.CommissionNavCache
import com.together.app.modules.mine.CommissionWithdrawalsViewModel
import com.together.app.services.CommissionService

// MARK: - 领取记录列表（对齐 iOS CommissionWithdrawalsViewController）

@Composable
fun CommissionWithdrawalsScreen(
    onBack: () -> Unit,
    onOpenDetail: (CommissionService.CommissionWithdrawal) -> Unit,
    viewModel: CommissionWithdrawalsViewModel = viewModel()
) {
    val state by viewModel.listState.collectAsState()
    val toast by viewModel.toast.collectAsState()
    val context = LocalContext.current

    LaunchedEffect(Unit) { viewModel.loadList(reset = true) }

    LaunchedEffect(toast) {
        if (toast != null) {
            android.widget.Toast.makeText(
                context, toast, android.widget.Toast.LENGTH_SHORT
            ).show()
            viewModel.clearToast()
        }
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "领取记录", onBack = onBack)

        PullToRefreshBox(
            isRefreshing = state.refreshing,
            onRefresh = { viewModel.loadList(reset = true) }
        ) {
            if (state.loading && state.rows.isEmpty()) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = AppColors.Brand)
                }
            } else if (state.rows.isEmpty()) {
                Column(
                    modifier = Modifier.fillMaxSize().padding(top = 80.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(text = if (state.error != null) "⚠️" else "🍃", fontSize = 40.sp)
                    Spacer(modifier = Modifier.height(AppDimens.M))
                    Text(
                        text = state.error ?: "暂无领取记录\n分享课程获得佣金后，可在此发起领取",
                        color = if (state.error != null) AppColors.Danger else AppColors.Muted,
                        fontSize = 14.sp,
                        lineHeight = 22.sp
                    )
                }
            } else {
                val listState = rememberLazyListState()
                // 滚动到底部自动加载更多
                val shouldLoadMore by remember {
                    derivedStateOf {
                        val last = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
                        last >= listState.layoutInfo.totalItemsCount - 3
                    }
                }
                LaunchedEffect(shouldLoadMore) {
                    if (shouldLoadMore && state.hasMore && !state.loadingMore) {
                        viewModel.loadList(reset = false)
                    }
                }

                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(
                        top = AppDimens.S, bottom = AppDimens.Xl
                    )
                ) {
                    items(state.rows, key = { it.withdrawId ?: java.util.UUID.randomUUID().toString() }) { item ->
                        WithdrawalCard(
                            item = item,
                            onClick = { onOpenDetail(item) }
                        )
                    }
                    if (state.loadingMore) {
                        item {
                            Box(
                                Modifier.fillMaxWidth().padding(AppDimens.M),
                                contentAlignment = Alignment.Center
                            ) {
                                CircularProgressIndicator(
                                    color = AppColors.Brand,
                                    modifier = Modifier.size(24.dp)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 领取单卡片

@Composable
private fun WithdrawalCard(
    item: CommissionService.CommissionWithdrawal,
    onClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M, vertical = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable(onClick = onClick)
            .padding(horizontal = AppDimens.L, vertical = AppDimens.L)
    ) {
        // 顶部：工作室名 + 状态标签
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = item.studio?.name ?: "历史提现",
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink,
                modifier = Modifier.weight(1f)
            )
            StatusTag(status = item.status ?: 0, text = item.statusText ?: "")
        }
        Spacer(modifier = Modifier.height(AppDimens.M))
        // 金额 + 方式
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = item.amountText ?: CommissionService.yuan(item.amount),
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.Clay
            )
            Spacer(modifier = Modifier.weight(1f))
            if (!item.method.isNullOrBlank()) {
                Text(
                    text = item.methodText ?: "",
                    fontSize = 12.sp,
                    color = AppColors.Sub
                )
            }
        }
        Spacer(modifier = Modifier.height(AppDimens.M))
        // 时间 + 确认按钮
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = CommissionService.fmtTime(item.createdAt),
                fontSize = 11.sp,
                color = AppColors.Muted,
                modifier = Modifier.weight(1f)
            )
            if (item.canConfirm == true) {
                Box(
                    modifier = Modifier
                        .width(104.dp)
                        .height(36.dp)
                        .clip(RoundedCornerShape(18.dp))
                        .background(AppColors.Brand),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "确认到账",
                        color = Color.White,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }
    }
}

/** 状态标签 */
@Composable
fun StatusTag(status: Int, text: String) {
    val (bg, fg) = when (status) {
        0 -> AppColors.WarnTint to AppColors.Warn
        1 -> AppColors.WarnTint to AppColors.Clay
        2 -> AppColors.DangerTint to AppColors.Danger
        else -> AppColors.SuccessTint to AppColors.Success
    }
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(bg)
            .padding(horizontal = 8.dp, vertical = 3.dp)
    ) {
        Text(text = text, color = fg, fontSize = 11.sp)
    }
}

// MARK: - 领取单详情（对齐 iOS CommissionWithdrawalDetailViewController）

@Composable
fun CommissionWithdrawalDetailScreen(
    onBack: () -> Unit,
    viewModel: CommissionWithdrawalsViewModel = viewModel()
) {
    val state by viewModel.detailState.collectAsState()
    val toast by viewModel.toast.collectAsState()
    var showConfirmDialog by remember { mutableStateOf(false) }
    val context = LocalContext.current

    // 从缓存初始化
    LaunchedEffect(Unit) {
        CommissionNavCache.withdrawal?.let { viewModel.initDetail(it) }
    }

    LaunchedEffect(toast) {
        if (toast != null) {
            android.widget.Toast.makeText(
                context, toast, android.widget.Toast.LENGTH_SHORT
            ).show()
            viewModel.clearToast()
        }
    }

    val item = state.item

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "领取单详情", onBack = onBack)

        if (item == null) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = AppColors.Brand)
            }
        } else {
            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(
                    top = AppDimens.S, bottom = AppDimens.Xl
                )
            ) {
                // 进度卡
                item { StepsCard(item) }
                // 打款信息卡
                item { PaymentInfoCard(item) }
                // 佣金明细
                val commissions = item.commissions ?: emptyList()
                if (commissions.isEmpty()) {
                    item { CommissionEmptyCard() }
                } else {
                    items(commissions, key = { it.commissionId ?: java.util.UUID.randomUUID().toString() }) { c ->
                        CommissionLineCard(c)
                    }
                }
                // 驳回原因
                if (item.status == 2) {
                    item { RejectCard(item.rejectReason) }
                }
            }

            // 底部确认按钮
            if (item.canConfirm == true) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(AppColors.Surface)
                ) {
                    HorizontalDivider(color = AppColors.Line, thickness = 0.5.dp)
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = AppDimens.L, vertical = AppDimens.M)
                            .height(44.dp)
                            .clip(RoundedCornerShape(22.dp))
                            .background(if (state.confirming) AppColors.Brand.copy(alpha = 0.6f) else AppColors.Brand)
                            .clickable(enabled = !state.confirming) { showConfirmDialog = true },
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "确认已收到佣金",
                            color = Color.White,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }
        }
    }

    // 确认弹窗
    if (showConfirmDialog) {
        AlertDialog(
            onDismissRequest = { showConfirmDialog = false },
            title = { Text("确认收到佣金", fontWeight = FontWeight.SemiBold) },
            text = {
                Text(
                    "请确认你已在线下实际收到「${item?.studio?.name ?: "工作室"}」打款的" +
                        "${item?.amountText ?: ""}。确认后将标记为已完成。"
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    showConfirmDialog = false
                    viewModel.confirmWithdrawal { }
                }) { Text("确认已收到", color = AppColors.Brand) }
            },
            dismissButton = {
                TextButton(onClick = { showConfirmDialog = false }) {
                    Text("再核对一下", color = AppColors.Sub)
                }
            },
            containerColor = AppColors.Surface
        )
    }
}

// MARK: - 进度卡

@Composable
private fun StepsCard(item: CommissionService.CommissionWithdrawal) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M, vertical = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.L)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = item.statusText ?: "",
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink,
                modifier = Modifier.weight(1f)
            )
            Text(
                text = item.amountText ?: CommissionService.yuan(item.amount),
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.Clay
            )
        }
        Spacer(modifier = Modifier.height(AppDimens.Xl))
        // 步骤点
        val steps = item.steps ?: emptyList()
        if (steps.isNotEmpty()) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                steps.forEach { step ->
                    Column(
                        modifier = Modifier.weight(1f),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        StepDot(done = step.done ?: false, current = step.current ?: false)
                        Spacer(modifier = Modifier.height(AppDimens.S))
                        Text(
                            text = step.title ?: "",
                            fontSize = 11.sp,
                            color = if (step.done == true) AppColors.Success else AppColors.Muted,
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                            lineHeight = 15.sp
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun StepDot(done: Boolean, current: Boolean) {
    Box(
        modifier = Modifier
            .size(26.dp)
            .clip(RoundedCornerShape(13.dp))
            .background(
                when {
                    done -> AppColors.Success
                    current -> AppColors.Surface
                    else -> AppColors.SurfaceAlt
                }
            ),
        contentAlignment = Alignment.Center
    ) {
        if (done) {
            Text(text = "✓", color = Color.White, fontSize = 12.sp)
        } else if (current) {
            Box(
                modifier = Modifier
                    .size(26.dp)
                    .clip(RoundedCornerShape(13.dp))
                    .background(AppColors.Surface)
                    .padding(1.5.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(AppColors.Success.copy(alpha = 0.15f))
            )
        }
    }
}

// MARK: - 打款信息卡

@Composable
private fun PaymentInfoCard(item: CommissionService.CommissionWithdrawal) {
    val status = item.status ?: 0
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M, vertical = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.L)
    ) {
        Text(
            text = "打款信息",
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.Ink
        )
        Spacer(modifier = Modifier.height(AppDimens.M))
        if (status >= 1) {
            InfoRow("打款方式", item.methodText ?: "-")
            if (!item.account.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(AppDimens.S))
                InfoRow("收款账号", item.account)
            }
            if (item.processedAt != null) {
                Spacer(modifier = Modifier.height(AppDimens.S))
                InfoRow("打款时间", CommissionService.fmtFull(item.processedAt))
            }
            if (item.confirmedAt != null) {
                Spacer(modifier = Modifier.height(AppDimens.S))
                InfoRow("确认时间", CommissionService.fmtFull(item.confirmedAt))
            }
        } else {
            Text(
                text = "等待工作室在线下完成打款，打款后会在此展示方式与凭证",
                fontSize = 12.sp,
                color = AppColors.Sub,
                lineHeight = 18.sp
            )
        }
        // 凭证图片
        val images = item.voucherImages ?: emptyList()
        if (images.isNotEmpty()) {
            Spacer(modifier = Modifier.height(AppDimens.M))
            Row(horizontalArrangement = Arrangement.spacedBy(AppDimens.S)) {
                images.take(4).forEach { url ->
                    AsyncImage(
                        model = resolveImageUrl(url),
                        contentDescription = "凭证",
                        modifier = Modifier
                            .size(80.dp)
                            .clip(RoundedCornerShape(AppDimens.RadiusIcon))
                            .background(AppColors.SurfaceAlt)
                    )
                }
            }
        }
    }
}

@Composable
private fun InfoRow(title: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(text = title, fontSize = 12.sp, color = AppColors.Sub)
        Spacer(modifier = Modifier.weight(1f))
        Text(
            text = value,
            fontSize = 13.sp,
            color = AppColors.Ink,
            textAlign = androidx.compose.ui.text.style.TextAlign.Right
        )
    }
}

// MARK: - 佣金明细行

@Composable
private fun CommissionLineCard(c: CommissionService.CommissionBrief) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M, vertical = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.L, vertical = AppDimens.M),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = "订单 ${c.orderId ?: "-"}",
                fontSize = 12.sp,
                color = AppColors.Sub
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = "费率 ${(c.rate ?: 0.0).toInt()}%",
                fontSize = 11.sp,
                color = AppColors.Muted
            )
        }
        Text(
            text = c.statusText ?: "",
            fontSize = 11.sp,
            color = AppColors.Muted
        )
        Spacer(modifier = Modifier.width(AppDimens.M))
        Text(
            text = CommissionService.yuan(c.amount),
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.Ink
        )
    }
}

@Composable
private fun CommissionEmptyCard() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M, vertical = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.L),
        contentAlignment = Alignment.Center
    ) {
        Text(text = "无明细（历史数据）", fontSize = 12.sp, color = AppColors.Muted)
    }
}

// MARK: - 驳回原因卡

@Composable
private fun RejectCard(reason: String?) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M, vertical = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.DangerTint)
            .padding(AppDimens.L)
    ) {
        Text(
            text = "驳回原因",
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.Danger
        )
        Spacer(modifier = Modifier.height(AppDimens.S))
        Text(
            text = reason ?: "",
            fontSize = 13.sp,
            color = AppColors.Danger,
            lineHeight = 20.sp
        )
    }
}