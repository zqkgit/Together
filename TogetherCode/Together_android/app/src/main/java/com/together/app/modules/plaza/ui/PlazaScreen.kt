package com.together.app.modules.plaza.ui

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.staggeredgrid.LazyVerticalStaggeredGrid
import androidx.compose.foundation.lazy.staggeredgrid.StaggeredGridCells
import androidx.compose.foundation.lazy.staggeredgrid.StaggeredGridItemSpan
import androidx.compose.foundation.lazy.staggeredgrid.items
import androidx.compose.foundation.lazy.staggeredgrid.rememberLazyStaggeredGridState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.core.component.EmptyStateView
import com.together.app.core.component.ErrorView
import com.together.app.core.component.LoadingView
import com.together.app.core.component.resolveImageUrl
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.PostItem
import com.together.app.modules.plaza.PlazaViewModel

/**
 * 广场页（对齐 iOS PlazaViewController）
 * 排序 chips（最新/热门/附近）+ 双列瀑布流 + 下拉刷新 + 触底加载
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlazaScreen(
    onPostClick: (PostItem) -> Unit
) {
    val viewModel: PlazaViewModel = viewModel()
    val state by viewModel.plazaState.collectAsState()
    val context = LocalContext.current

    // 首次加载
    LaunchedEffect(Unit) {
        viewModel.loadTopics()
        viewModel.refresh()
    }

    // 定位权限请求
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) viewModel.onLocationPermissionGranted()
    }

    fun tryNearby() {
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
        if (granted) {
            viewModel.changeSort("near")
        } else {
            permissionLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
            .statusBarsPadding()
    ) {
        // 排序 chips
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = AppDimens.L, vertical = AppDimens.S),
            horizontalArrangement = Arrangement.spacedBy(AppDimens.S)
        ) {
            listOf("latest" to "最新", "hot" to "热门", "near" to "附近").forEach { (key, label) ->
                SortChip(
                    label = label,
                    selected = state.sort == key,
                    onClick = {
                        if (key == "near") tryNearby() else viewModel.changeSort(key)
                    }
                )
            }
        }

        // 定位失败提示
        if (state.locationDenied) {
            Text(
                text = "定位不可用，已显示最新内容",
                fontSize = 11.sp,
                color = AppColors.Muted,
                modifier = Modifier.padding(horizontal = AppDimens.L)
            )
        }

        // 瀑布流
        val gridState = rememberLazyStaggeredGridState()
        val shouldLoadMore by remember {
            derivedStateOf {
                val last = gridState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: -1
                val total = gridState.layoutInfo.totalItemsCount
                total > 0 && last >= total - 4 && state.hasMore && !state.loading
            }
        }
        LaunchedEffect(shouldLoadMore) {
            if (shouldLoadMore) viewModel.loadMore()
        }

        PullToRefreshBox(
            isRefreshing = state.refreshing,
            onRefresh = { viewModel.refresh() },
            modifier = Modifier.fillMaxSize()
        ) {
            when {
                state.posts.isEmpty() && state.loading && state.refreshing -> {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        LoadingView()
                    }
                }
                state.posts.isEmpty() && state.error != null -> {
                    ErrorView(message = state.error ?: "", onRetry = { viewModel.refresh() })
                }
                state.posts.isEmpty() -> {
                    EmptyStateView(message = "广场还没有内容，快来发布第一篇吧")
                }
                else -> {
                    LazyVerticalStaggeredGrid(
                        columns = StaggeredGridCells.Fixed(2),
                        state = gridState,
                        contentPadding = androidx.compose.foundation.layout.PaddingValues(
                            horizontal = AppDimens.M,
                            vertical = AppDimens.S
                        ),
                        verticalItemSpacing = AppDimens.M,
                        horizontalArrangement = Arrangement.spacedBy(AppDimens.M),
                        modifier = Modifier.fillMaxSize()
                    ) {
                        items(state.posts, key = { it.postId }) { post ->
                            WorkCard(item = post, onClick = { onPostClick(post) })
                        }
                        // 底部加载状态
                        item(span = StaggeredGridItemSpan.FullLine) {
                            Box(
                                Modifier.fillMaxWidth().padding(AppDimens.L),
                                contentAlignment = Alignment.Center
                            ) {
                                when {
                                    state.loading -> LoadingView()
                                    !state.hasMore -> Text(
                                        "没有更多了",
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

// MARK: - 排序 Chip

@Composable
private fun SortChip(label: String, selected: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(if (selected) AppColors.Brand else AppColors.SurfaceAlt)
            .clickable(onClick = onClick)
            .padding(horizontal = AppDimens.L, vertical = AppDimens.S)
    ) {
        Text(
            text = label,
            fontSize = 13.sp,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
            color = if (selected) Color.White else AppColors.Sub
        )
    }
}

// MARK: - 作品卡（对齐 iOS WorkCardView）

@Composable
fun WorkCard(item: PostItem, onClick: () -> Unit) {
    val colorPair = topicPalette(item.safeTopic)
    Column(
        modifier = Modifier
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable(onClick = onClick)
    ) {
        // 作品图（3:4，无图按话题色渐变占位）
        val firstImage = item.imageList.firstOrNull()
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(3f / 4f)
                .background(Brush.linearGradient(listOf(colorPair.first, colorPair.second)))
        ) {
            if (firstImage != null) {
                AsyncImage(
                    model = resolveImageUrl(firstImage),
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )
            } else {
                // 无图占位：话题名
                item.safeTopic?.let { topic ->
                    Text(
                        text = "#$topic",
                        color = Color.White.copy(alpha = 0.7f),
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium,
                        modifier = Modifier.align(Alignment.Center)
                    )
                }
            }
        }

        // 信息区
        Column(Modifier.padding(AppDimens.CardInner)) {
            Text(
                text = item.bodyText.ifEmpty { "作品分享" },
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(Modifier.height(AppDimens.Xs))
            Row(verticalAlignment = Alignment.CenterVertically) {
                var authorText = item.authorName
                item.distanceText?.let { authorText += " · $it" }
                Text(
                    text = authorText,
                    fontSize = 11.sp,
                    color = AppColors.Sub,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )
                Spacer(Modifier.width(AppDimens.Xs))
                Icon(
                    imageVector = if (item.isLiked == true) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
                    contentDescription = null,
                    tint = if (item.isLiked == true) AppColors.Clay else AppColors.Muted,
                    modifier = Modifier.size(12.dp)
                )
                Text(
                    text = " ${item.likeText}",
                    fontSize = 11.sp,
                    color = AppColors.Muted
                )
            }
            // 关联课程
            item.course?.title?.takeIf { it.isNotEmpty() }?.let { course ->
                Spacer(Modifier.height(AppDimens.Xs))
                Text(
                    text = "关联课程·$course",
                    fontSize = 11.sp,
                    color = AppColors.Brand,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

/** 话题 → 色系（对齐 iOS WorkCardView.palette） */
private fun topicPalette(topic: String?): Pair<Color, Color> {
    return when (topic) {
        "水彩" -> Color(0xFF7FB5C8) to Color(0xFF4A7C9B)
        "黏土" -> Color(0xFFE0A878) to Color(0xFFC15F2C)
        "书法" -> Color(0xFF8B8B8B) to Color(0xFF4A4A4A)
        "素描" -> Color(0xFFC9C4BC) to Color(0xFF8A8478)
        "国画" -> Color(0xFFA8BDA0) to Color(0xFF6E8A66)
        else -> AppColors.BrandSoft to AppColors.Brand
    }
}