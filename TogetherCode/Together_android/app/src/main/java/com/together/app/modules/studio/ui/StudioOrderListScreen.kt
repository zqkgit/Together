package com.together.app.modules.studio.ui

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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import com.together.app.core.component.AppPullRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
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
import com.together.app.core.component.SearchBar
import com.together.app.core.component.StatusTag
import com.together.app.core.component.TogetherCard
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.studio.StudioViewModel
import com.together.app.services.StudioService

/**
 * 工作室「订单管理」列表页（对齐 iOS StudioOrderListViewController）
 *
 * 6 个筛选 chips + 搜索栏 + 订单卡列表 + 分页加载 + 下拉刷新
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StudioOrderListScreen(
    onBack: () -> Unit = {},
    onOrderClick: (StudioService.StudioOrder) -> Unit = {},
    viewModel: StudioViewModel = viewModel()
) {
    val state by viewModel.orderListState.collectAsState()

    // ON_RESUME 刷新
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) viewModel.loadOrders()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "订单管理", onBack = onBack)

        // 筛选 chips
        OrderFilterChipRow(
            selected = state.selectedFilter,
            onSelect = { viewModel.selectOrderFilter(it) }
        )

        // 搜索栏
        SearchBar(
            placeholder = "搜索订单号/学员/家长",
            value = state.keyword,
            onValueChange = { viewModel.updateOrderKeyword(it) },
            onSearch = { viewModel.searchOrders() },
            modifier = Modifier.padding(horizontal = AppDimens.L, vertical = AppDimens.S)
        )

        // 内容区
        Box(modifier = Modifier.weight(1f)) {
            when {
                state.loading && state.orders.isEmpty() -> LoadingView()
                state.error != null && state.orders.isEmpty() -> ErrorView(
                    message = state.error!!,
                    onRetry = { viewModel.loadOrders() }
                )
                state.orders.isEmpty() -> EmptyStateView(message = state.selectedFilter.emptyText)
                else -> AppPullRefreshBox(
                    isRefreshing = state.loading,
                    onRefresh = { viewModel.loadOrders() },
                    modifier = Modifier.fillMaxSize()
                ) {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(
                            start = AppDimens.L,
                            end = AppDimens.L,
                            top = AppDimens.S,
                            bottom = AppDimens.Xl
                        ),
                        verticalArrangement = Arrangement.spacedBy(AppDimens.M)
                    ) {
                        items(state.orders, key = { it.orderId }) { order ->
                            OrderCard(order = order, onClick = { onOrderClick(order) })
                        }
                        // 分页加载更多
                        if (state.hasMore) {
                            item(key = "load_more") {
                                LaunchedEffect(Unit) { viewModel.loadMoreOrders() }
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(vertical = AppDimens.M),
                                    contentAlignment = Alignment.Center
                                ) {
                                    if (state.loadingMore) {
                                        androidx.compose.material3.CircularProgressIndicator(
                                            modifier = Modifier.size(24.dp),
                                            color = AppColors.Brand,
                                            strokeWidth = 2.dp
                                        )
                                    } else {
                                        androidx.compose.material3.Text(
                                            text = "上拉加载更多",
                                            fontSize = 12.sp,
                                            color = AppColors.Muted
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 筛选 chips

@Composable
private fun OrderFilterChipRow(
    selected: StudioService.OrderFilter,
    onSelect: (StudioService.OrderFilter) -> Unit
) {
    LazyRow(
        modifier = Modifier.fillMaxWidth(),
        contentPadding = PaddingValues(horizontal = AppDimens.L, vertical = AppDimens.S),
        horizontalArrangement = Arrangement.spacedBy(AppDimens.S)
    ) {
        items(StudioService.OrderFilter.entries) { filter ->
            val isSelected = filter == selected
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(AppDimens.RadiusTag))
                    .background(if (isSelected) AppColors.Brand else AppColors.SurfaceAlt)
                    .clickable { onSelect(filter) }
                    .padding(horizontal = AppDimens.M, vertical = 6.dp)
            ) {
                androidx.compose.material3.Text(
                    text = filter.title,
                    color = if (isSelected) Color.White else AppColors.Sub,
                    fontSize = 13.sp,
                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal
                )
            }
        }
    }
}

// MARK: - 订单卡

@Composable
private fun OrderCard(
    order: StudioService.StudioOrder,
    onClick: () -> Unit
) {
    TogetherCard(
        modifier = Modifier.fillMaxWidth().clickable { onClick() }
    ) {
        Column {
            // 第一行：订单号 + 状态 pill
            Row(verticalAlignment = Alignment.CenterVertically) {
                androidx.compose.material3.Text(
                    text = order.orderNo ?: "—",
                    fontSize = 13.sp,
                    color = AppColors.Muted,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )
                Spacer(modifier = Modifier.width(AppDimens.S))
                StatusTag(status = order.status ?: 0, statusText = order.statusLabel)
            }

            Spacer(modifier = Modifier.height(AppDimens.S))

            // 家长名 + 来源
            Row(verticalAlignment = Alignment.CenterVertically) {
                androidx.compose.material3.Text(
                    text = order.parentName,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.Ink,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )
                androidx.compose.material3.Text(
                    text = order.sourceLabel,
                    fontSize = 12.sp,
                    color = AppColors.Muted
                )
            }

            Spacer(modifier = Modifier.height(4.dp))

            // 课程名
            androidx.compose.material3.Text(
                text = order.courseTitle,
                fontSize = 13.sp,
                color = AppColors.Sub,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )

            Spacer(modifier = Modifier.height(AppDimens.S))

            // 底部：日期+课时 | 金额
            Row(verticalAlignment = Alignment.Bottom) {
                Column(modifier = Modifier.weight(1f)) {
                    androidx.compose.material3.Text(
                        text = order.totalLessonsText,
                        fontSize = 12.sp,
                        color = AppColors.Muted
                    )
                    androidx.compose.material3.Text(
                        text = order.createdDate,
                        fontSize = 12.sp,
                        color = AppColors.Muted
                    )
                }
                androidx.compose.material3.Text(
                    text = order.totalAmountText,
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.Clay
                )
            }

            // 有待确认凭证提示
            if (order.hasPendingPayment && order.pendingPayment?.hasVoucher == true) {
                Spacer(modifier = Modifier.height(AppDimens.S))
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(AppDimens.RadiusTag))
                        .background(AppColors.WarnTint)
                        .padding(horizontal = AppDimens.M, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    androidx.compose.material3.Text(
                        text = "家长已上传付款凭证，待确认",
                        fontSize = 12.sp,
                        color = AppColors.Warn
                    )
                }
            }
        }
    }
}