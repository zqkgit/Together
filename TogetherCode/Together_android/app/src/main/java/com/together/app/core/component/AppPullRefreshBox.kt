package com.together.app.core.component

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.king.ultraswiperefresh.NestedScrollMode
import com.king.ultraswiperefresh.UltraSwipeRefresh
import com.king.ultraswiperefresh.indicator.classic.ClassicRefreshFooter
import com.king.ultraswiperefresh.indicator.classic.ClassicRefreshHeader
import com.king.ultraswiperefresh.rememberUltraSwipeRefreshState
import com.together.app.core.design.AppColors

/**
 * 下拉刷新容器（基于 UltraSwipeRefresh 三方库，经典动画指示器）
 * API 兼容 Material3 PullToRefreshBox（含 BoxScope），直接替换即可
 */
@Composable
fun AppPullRefreshBox(
    isRefreshing: Boolean,
    onRefresh: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit
) {
    val state = rememberUltraSwipeRefreshState()

    // 同步外部刷新状态 → 内部指示器状态
    LaunchedEffect(isRefreshing) {
        state.isRefreshing = isRefreshing
    }

    UltraSwipeRefresh(
        state = state,
        onRefresh = {
            state.isRefreshing = true
            onRefresh()
        },
        onLoadMore = { },
        modifier = modifier,
        loadMoreEnabled = false,
        headerScrollMode = NestedScrollMode.Translate,
        headerIndicator = { ClassicRefreshHeader(it) }
    ) {
        Box {
            content()
        }
    }
}

/**
 * 下拉刷新 + 上拉加载更多容器（基于 UltraSwipeRefresh 三方库）
 * 顶部经典刷新动画 + 底部经典加载动画 / "没有更多了"提示
 */
@Composable
fun AppRefreshLoadMoreBox(
    isRefreshing: Boolean,
    isLoadingMore: Boolean,
    hasMore: Boolean,
    onRefresh: () -> Unit,
    onLoadMore: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit
) {
    val state = rememberUltraSwipeRefreshState()

    LaunchedEffect(isRefreshing) { state.isRefreshing = isRefreshing }
    LaunchedEffect(isLoadingMore) { state.isLoading = isLoadingMore }

    UltraSwipeRefresh(
        state = state,
        onRefresh = {
            state.isRefreshing = true
            onRefresh()
        },
        onLoadMore = {
            if (hasMore && !isLoadingMore) {
                state.isLoading = true
                onLoadMore()
            }
        },
        modifier = modifier,
        headerScrollMode = NestedScrollMode.Translate,
        footerScrollMode = NestedScrollMode.Translate,
        headerIndicator = { ClassicRefreshHeader(it) },
        footerIndicator = {
            if (hasMore) {
                ClassicRefreshFooter(it)
            } else {
                Box(
                    modifier = Modifier.fillMaxWidth(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "没有更多了",
                        color = AppColors.Muted,
                        fontSize = 13.sp,
                        modifier = Modifier.padding(vertical = 16.dp)
                    )
                }
            }
        }
    ) {
        Box {
            content()
        }
    }
}