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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.component.EmptyStateView
import com.together.app.core.component.ErrorView
import com.together.app.core.component.LoadingView
import com.together.app.core.component.TogetherAvatar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.studio.StudioViewModel
import com.together.app.services.CommissionService
import com.together.app.services.PayMethodOption

/**
 * 工作室「佣金审核」页（对齐 iOS StudioCommissionReviewViewController）
 *
 * 分段（待审核/待确认/已驳回/已完成）+ 领取单卡片
 * 待审核可「通过并打款」（选打款方式）或「驳回」（填原因）
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StudioCommissionReviewScreen(
    onBack: () -> Unit = {},
    viewModel: StudioViewModel = viewModel()
) {
    val state by viewModel.commissionState.collectAsState()
    var pendingApprove by remember { mutableStateOf<CommissionService.CommissionWithdrawal?>(null) }
    var pendingReject by remember { mutableStateOf<CommissionService.CommissionWithdrawal?>(null) }
    var rejectReason by remember { mutableStateOf("") }

    // ON_RESUME 刷新
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) viewModel.loadCommissions()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    // 加载更多
    val listState = rememberLazyListState()
    val shouldLoadMore by remember {
        derivedStateOf {
            val lastVisible = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            val total = listState.layoutInfo.totalItemsCount
            state.hasMore && !state.loadingMore && !state.loading && total > 0 && lastVisible >= total - 3
        }
    }
    LaunchedEffect(shouldLoadMore) {
        if (shouldLoadMore) viewModel.loadMoreCommissions()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
    ) {
        // 顶栏
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(AppDimens.TopBarHeight)
                .background(AppColors.Surface),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "返回",
                    tint = AppColors.Ink
                )
            }
            Text(
                text = "佣金审核",
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink
            )
        }

        // 分段
        CommissionTabBar(
            selectedTab = state.selectedTab,
            onSelect = { viewModel.selectCommissionTab(it) }
        )

        // 列表
        PullToRefreshBox(
            isRefreshing = state.loading,
            onRefresh = { viewModel.loadCommissions() },
            modifier = Modifier.fillMaxSize()
        ) {
            when {
                state.loading && state.items.isEmpty() -> LoadingView()
                state.error != null && state.items.isEmpty() -> ErrorView(
                    message = state.error ?: "加载失败",
                    onRetry = { viewModel.loadCommissions() }
                )
                state.items.isEmpty() -> EmptyStateView(message = state.selectedTab.emptyText)
                else -> LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(
                        start = AppDimens.L,
                        end = AppDimens.L,
                        top = AppDimens.S,
                        bottom = AppDimens.Xl
                    ),
                    verticalArrangement = Arrangement.spacedBy(AppDimens.S)
                ) {
                    items(state.items, key = { it.withdrawId ?: it.hashCode().toString() }) { item ->
                        CommissionCard(
                            item = item,
                            onApprove = { pendingApprove = item },
                            onReject = { pendingReject = item; rejectReason = "" }
                        )
                    }
                    if (state.loadingMore) {
                        item {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(AppDimens.M),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = "加载中…",
                                    fontSize = 13.sp,
                                    color = AppColors.Muted
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // 通过并打款：选打款方式
    pendingApprove?.let { item ->
        AlertDialog(
            onDismissRequest = { pendingApprove = null },
            title = { Text("选择打款方式", fontWeight = FontWeight.SemiBold) },
            text = {
                Column {
                    PayMethodOption.all.forEach { option ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    pendingApprove = null
                                    item.withdrawId?.let { id ->
                                        viewModel.approveCommission(
                                            id = id,
                                            method = option.value,
                                            onError = { /* ViewModel 已 showToast */ }
                                        )
                                    }
                                }
                                .padding(vertical = 12.dp, horizontal = 4.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = option.label,
                                fontSize = 15.sp,
                                color = AppColors.Ink
                            )
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { pendingApprove = null }) {
                    Text("取消", color = AppColors.Muted)
                }
            }
        )
    }

    // 驳回：填原因
    pendingReject?.let { item ->
        AlertDialog(
            onDismissRequest = { pendingReject = null },
            title = { Text("驳回领取申请", fontWeight = FontWeight.SemiBold) },
            text = {
                OutlinedTextField(
                    value = rejectReason,
                    onValueChange = { if (it.length <= 100) rejectReason = it },
                    placeholder = { Text("请填写驳回原因（推广人可见）", fontSize = 14.sp) },
                    singleLine = false,
                    maxLines = 3,
                    modifier = Modifier.fillMaxWidth()
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        if (rejectReason.trim().isEmpty()) return@TextButton
                        val reason = rejectReason.trim()
                        pendingReject = null
                        item.withdrawId?.let { id ->
                            viewModel.rejectCommission(
                                id = id,
                                reason = reason,
                                onError = { /* ViewModel 已 showToast */ }
                            )
                        }
                    }
                ) {
                    Text("确认驳回", color = AppColors.Danger)
                }
            },
            dismissButton = {
                TextButton(onClick = { pendingReject = null }) {
                    Text("取消", color = AppColors.Muted)
                }
            }
        )
    }
}

// MARK: - 分段条

@Composable
private fun CommissionTabBar(
    selectedTab: StudioViewModel.CommissionTab,
    onSelect: (StudioViewModel.CommissionTab) -> Unit
) {
    val tabs = StudioViewModel.CommissionTab.entries

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L, vertical = AppDimens.S)
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(4.dp)
    ) {
        tabs.forEach { tab ->
            val selected = tab == selectedTab
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(13.dp))
                    .background(if (selected) AppColors.BrandSoft else AppColors.Surface)
                    .clickable { onSelect(tab) }
                    .padding(vertical = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = tab.title,
                    fontSize = 13.sp,
                    fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (selected) AppColors.Ink else AppColors.Sub,
                    maxLines = 1
                )
            }
        }
    }
}

// MARK: - 佣金领取单卡片

@Composable
private fun CommissionCard(
    item: CommissionService.CommissionWithdrawal,
    onApprove: () -> Unit,
    onReject: () -> Unit
) {
    val name = item.user?.nickname?.takeIf { it.isNotEmpty() } ?: "推广人"
    val status = item.status ?: 0

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.CardInner)
    ) {
        // 头部：头像 + 名称/时间 + 金额/方式
        Row(verticalAlignment = Alignment.CenterVertically) {
            TogetherAvatar(
                url = null,
                name = name,
                size = 42.dp
            )
            Spacer(modifier = Modifier.width(AppDimens.M))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = name,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.Ink,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = CommissionService.fmtTime(item.createdAt),
                    fontSize = 12.sp,
                    color = AppColors.Muted
                )
            }
            Spacer(modifier = Modifier.width(AppDimens.S))
            Column(horizontalAlignment = Alignment.End) {
                Text(
                    text = CommissionService.yuan(item.amount),
                    fontSize = 17.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.Clay
                )
                if (!item.methodText.isNullOrEmpty()) {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = item.methodText,
                        fontSize = 12.sp,
                        color = AppColors.Sub
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(AppDimens.S))

        // 状态标签
        val (statusText, statusColor, statusBg) = when (status) {
            0 -> Triple("待审核", AppColors.Warn, AppColors.WarnTint)
            1 -> Triple("待确认", AppColors.Info, AppColors.InfoTint)
            2 -> Triple("已驳回", AppColors.Danger, AppColors.DangerTint)
            3 -> Triple("已完成", AppColors.Success, AppColors.SuccessTint)
            else -> Triple("未知", AppColors.Muted, AppColors.SurfaceAlt)
        }
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(12.dp))
                .background(statusBg)
                .padding(horizontal = 10.dp, vertical = 3.dp)
        ) {
            Text(
                text = statusText,
                fontSize = 11.sp,
                color = statusColor
            )
        }

        // 驳回原因
        if (status == 2 && !item.rejectReason.isNullOrEmpty()) {
            Spacer(modifier = Modifier.height(AppDimens.S))
            Text(
                text = "驳回原因：${item.rejectReason}",
                fontSize = 12.sp,
                color = AppColors.Warn,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }

        // 操作区
        when (status) {
            0 -> {
                Spacer(modifier = Modifier.height(AppDimens.L))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(AppDimens.M)
                ) {
                    // 驳回
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(40.dp)
                            .clip(RoundedCornerShape(20.dp))
                            .background(AppColors.Surface)
                            .border(1.dp, AppColors.Line, RoundedCornerShape(20.dp))
                            .clickable(onClick = onReject),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "驳回",
                            fontSize = 15.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = AppColors.Ink
                        )
                    }
                    // 通过并打款
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(40.dp)
                            .clip(RoundedCornerShape(20.dp))
                            .background(AppColors.Brand)
                            .clickable(onClick = onApprove),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "通过并打款",
                            fontSize = 15.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = AppColors.Surface
                        )
                    }
                }
            }
            1 -> {
                Spacer(modifier = Modifier.height(AppDimens.S))
                Text(
                    text = "已登记打款，等待推广人确认到账",
                    fontSize = 12.sp,
                    color = AppColors.Info
                )
            }
        }
    }
}