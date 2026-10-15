@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.together.app.modules.mine.ui

import android.app.Application
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChatBubble
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import coil.compose.AsyncImage
import com.together.app.core.component.AppPullRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.component.TogetherAvatar
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.component.resolveImageUrl
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.PostItem
import com.together.app.modules.plaza.ui.topicPalette
import com.together.app.services.PostService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

// MARK: - ViewModel

/**
 * 收藏与动态 ViewModel（对齐 iOS FavoritesAndDynamicsViewController）
 */
class FavoritesViewModel(app: Application) : AndroidViewModel(app) {

    data class State(
        val favorites: List<PostItem> = emptyList(),
        val feeds: List<PostItem> = emptyList(),
        val loading: Boolean = false,
        val refreshing: Boolean = false,
        val loadingMore: Boolean = false,
        val favHasMore: Boolean = true,
        val feedHasMore: Boolean = true,
        val error: String? = null
    )

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state.asStateFlow()

    private val _toast = MutableStateFlow<String?>(null)
    val toast: StateFlow<String?> = _toast.asStateFlow()

    private var favPage = 1
    private var feedPage = 1

    fun clearToast() { _toast.value = null }

    fun loadFavorites(reset: Boolean) {
        val s = _state.value
        if (s.loading || s.loadingMore) return
        viewModelScope.launch {
            if (reset) {
                favPage = 1
                _state.value = s.copy(loading = s.favorites.isNotEmpty(), refreshing = s.favorites.isNotEmpty())
            } else {
                _state.value = s.copy(loadingMore = true)
            }
            try {
                val (items, hasMore) = PostService.fetchFavorites(page = favPage)
                val cur = _state.value
                _state.value = cur.copy(
                    favorites = if (reset) items else cur.favorites + items,
                    favHasMore = hasMore,
                    loading = false, refreshing = false, loadingMore = false, error = null
                )
                favPage++
            } catch (e: Exception) {
                val cur = _state.value
                _state.value = cur.copy(loading = false, refreshing = false, loadingMore = false)
                _toast.value = e.message ?: "加载失败"
            }
        }
    }

    fun loadChildFeed(reset: Boolean) {
        val s = _state.value
        if (s.loading || s.loadingMore) return
        viewModelScope.launch {
            if (reset) {
                feedPage = 1
                _state.value = s.copy(loading = s.feeds.isNotEmpty(), refreshing = s.feeds.isNotEmpty())
            } else {
                _state.value = s.copy(loadingMore = true)
            }
            try {
                val (items, hasMore) = PostService.fetchChildFeed(page = feedPage)
                val cur = _state.value
                _state.value = cur.copy(
                    feeds = if (reset) items else cur.feeds + items,
                    feedHasMore = hasMore,
                    loading = false, refreshing = false, loadingMore = false, error = null
                )
                feedPage++
            } catch (e: Exception) {
                val cur = _state.value
                _state.value = cur.copy(loading = false, refreshing = false, loadingMore = false)
                _toast.value = e.message ?: "加载失败"
            }
        }
    }
}

// MARK: - 收藏与动态页面

/**
 * 收藏与动态（对齐 iOS FavoritesAndDynamicsViewController）
 * 收藏作品 = 我收藏的他人作品（两列网格）；孩子动态 = 我孩子相关的帖子流
 */
@Composable
fun FavoritesAndDynamicsScreen(
    onBack: () -> Unit,
    onPostClick: (String) -> Unit,
    viewModel: FavoritesViewModel = viewModel()
) {
    val state by viewModel.state.collectAsState()
    val toast by viewModel.toast.collectAsState()
    var currentTab by remember { mutableIntStateOf(0) } // 0=收藏 1=动态
    val context = LocalContext.current

    LaunchedEffect(Unit) { viewModel.loadFavorites(reset = true) }

    LaunchedEffect(toast) {
        if (toast != null) {
            android.widget.Toast.makeText(
                context, toast, android.widget.Toast.LENGTH_SHORT
            ).show()
            viewModel.clearToast()
        }
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "收藏与动态", onBack = onBack)

        // 分段栏
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.Surface)
                .height(46.dp)
        ) {
            listOf("收藏作品", "孩子动态").forEachIndexed { index, title ->
                val isSelected = index == currentTab
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .clickable {
                            if (currentTab != index) {
                                currentTab = index
                                if (index == 0 && state.favorites.isEmpty()) {
                                    viewModel.loadFavorites(reset = true)
                                } else if (index == 1 && state.feeds.isEmpty()) {
                                    viewModel.loadChildFeed(reset = true)
                                }
                            }
                        },
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = title,
                        fontSize = if (isSelected) 16.sp else 15.sp,
                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                        color = if (isSelected) AppColors.Brand else AppColors.Sub,
                        modifier = Modifier.padding(top = 12.dp)
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Box(
                        modifier = Modifier
                            .width(44.dp)
                            .height(3.dp)
                            .clip(RoundedCornerShape(2.dp))
                            .background(if (isSelected) AppColors.Brand else AppColors.Surface)
                    )
                }
            }
        }

        // 内容区
        if (currentTab == 0) {
            FavoritesTab(state, viewModel, onPostClick)
        } else {
            ChildFeedTab(state, viewModel, onPostClick)
        }
    }
}

// MARK: - 收藏作品 Tab

@Composable
private fun FavoritesTab(
    state: FavoritesViewModel.State,
    viewModel: FavoritesViewModel,
    onPostClick: (String) -> Unit
) {
    AppPullRefreshBox(
        isRefreshing = state.refreshing,
        onRefresh = { viewModel.loadFavorites(reset = true) }
    ) {
        if (state.loading && state.favorites.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = AppColors.Brand)
            }
        } else if (state.favorites.isEmpty()) {
            EmptyContent("还没有收藏的作品")
        } else {
            val gridState = rememberLazyGridState()
            val shouldLoadMore by remember {
                derivedStateOf {
                    val last = gridState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
                    last >= gridState.layoutInfo.totalItemsCount - 3
                }
            }
            LaunchedEffect(shouldLoadMore) {
                if (shouldLoadMore && state.favHasMore && !state.loadingMore) {
                    viewModel.loadFavorites(reset = false)
                }
            }

            LazyVerticalGrid(
                state = gridState,
                columns = GridCells.Fixed(2),
                modifier = Modifier.fillMaxSize(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(
                    top = AppDimens.M, start = AppDimens.L, end = AppDimens.L, bottom = 108.dp
                ),
                horizontalArrangement = Arrangement.spacedBy(AppDimens.M),
                verticalArrangement = Arrangement.spacedBy(AppDimens.M)
            ) {
                items(state.favorites, key = { it.postId }) { item ->
                    FavoriteWorkCard(item = item, onClick = { onPostClick(item.postId) })
                }
            }
        }
    }
}

// MARK: - 孩子动态 Tab

@Composable
private fun ChildFeedTab(
    state: FavoritesViewModel.State,
    viewModel: FavoritesViewModel,
    onPostClick: (String) -> Unit
) {
    AppPullRefreshBox(
        isRefreshing = state.refreshing,
        onRefresh = { viewModel.loadChildFeed(reset = true) }
    ) {
        if (state.loading && state.feeds.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = AppColors.Brand)
            }
        } else if (state.feeds.isEmpty()) {
            EmptyContent("暂无孩子动态")
        } else {
            val listState = rememberLazyListState()
            val shouldLoadMore by remember {
                derivedStateOf {
                    val last = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
                    last >= listState.layoutInfo.totalItemsCount - 3
                }
            }
            LaunchedEffect(shouldLoadMore) {
                if (shouldLoadMore && state.feedHasMore && !state.loadingMore) {
                    viewModel.loadChildFeed(reset = false)
                }
            }

            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = 108.dp)
            ) {
                items(state.feeds, key = { it.postId }) { item ->
                    FeedCard(item = item, onClick = { onPostClick(item.postId) })
                }
                if (state.loadingMore) {
                    item {
                        Box(
                            Modifier.fillMaxWidth().padding(AppDimens.M),
                            contentAlignment = Alignment.Center
                        ) {
                            CircularProgressIndicator(
                                color = AppColors.Brand, modifier = Modifier.size(24.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 收藏作品卡片（对齐 iOS FavoriteWorkCell：封面0.8比例 + 标题1行 + 作者 + 点赞）

@Composable
private fun FavoriteWorkCard(item: PostItem, onClick: () -> Unit) {
    val colorPair = topicPalette(item.safeTopic)
    Column(
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(AppColors.Surface)
            .clickable(onClick = onClick)
    ) {
        // 封面（高 = 宽 × 0.8，无图按话题色渐变占位）
        val firstImage = item.imageList.firstOrNull()
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(1f / 0.8f)
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
        // 标题（1行）
        Text(
            text = item.bodyText.ifEmpty { "作品分享" },
            fontSize = 14.sp,
            color = AppColors.Ink,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 10.dp, start = AppDimens.M, end = AppDimens.M)
        )
        // 作者 + 点赞
        Row(
            modifier = Modifier.padding(top = 6.dp, start = AppDimens.M, end = AppDimens.M, bottom = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = item.authorName,
                fontSize = 11.sp,
                color = AppColors.Sub,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f)
            )
            Text(text = "♥ ${item.likeText}", fontSize = 11.sp, color = AppColors.Sub)
        }
    }
}

// MARK: - 孩子动态卡片（对齐 iOS PostCardView：头像36 + 角色徽章 + 九宫格图 + 点赞评论栏 + 边框阴影）

@Composable
private fun FeedCard(item: PostItem, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L, vertical = AppDimens.S)
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .border(1.dp, AppColors.Line, RoundedCornerShape(AppDimens.RadiusCard))
            .clickable(onClick = onClick)
            .padding(bottom = AppDimens.M)
    ) {
        // 头部：头像36 + 名字 + 角色徽章 + 时间
        Row(
            modifier = Modifier.padding(start = AppDimens.M, top = AppDimens.M, end = AppDimens.M),
            verticalAlignment = Alignment.CenterVertically
        ) {
            TogetherAvatar(url = item.authorAvatar, name = item.authorName, size = 36.dp)
            Spacer(Modifier.width(AppDimens.M))
            Row(modifier = Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = item.authorName,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.Ink,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                if (item.roleText.isNotEmpty()) {
                    Spacer(Modifier.width(AppDimens.Xs))
                    Box(
                        modifier = Modifier
                            .height(16.dp)
                            .clip(RoundedCornerShape(4.dp))
                            .background(AppColors.BrandSoft)
                            .padding(horizontal = 6.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(item.roleText, fontSize = 10.sp, color = AppColors.Brand)
                    }
                }
            }
            Text(text = item.timeText, fontSize = 11.sp, color = AppColors.Muted)
        }
        // 正文（3行，左对齐名字避开头像）
        if (item.bodyText.isNotEmpty()) {
            Text(
                text = item.bodyText,
                fontSize = 14.sp,
                color = AppColors.Ink,
                lineHeight = 21.sp,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(start = 60.dp, top = AppDimens.S, end = AppDimens.M)
            )
        }
        // 九宫格图片
        if (item.imageList.isNotEmpty()) {
            PostImageGrid(
                urls = item.imageList,
                modifier = Modifier.padding(start = 60.dp, top = AppDimens.S, end = AppDimens.M)
            )
        }
        // 底部栏：点赞 + 评论 + 关联文案
        Row(
            modifier = Modifier.padding(start = AppDimens.M, top = AppDimens.M, end = AppDimens.M),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = if (item.isLiked == true) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
                contentDescription = null,
                tint = AppColors.Muted,
                modifier = Modifier.size(14.dp)
            )
            Text(text = " ${item.likeText}", fontSize = 11.sp, color = AppColors.Muted)
            Spacer(Modifier.width(AppDimens.L))
            Icon(Icons.Filled.ChatBubble, contentDescription = null, tint = AppColors.Muted, modifier = Modifier.size(14.dp))
            Text(text = " ${item.commentText}", fontSize = 11.sp, color = AppColors.Muted)
            Spacer(Modifier.weight(1f))
            item.relationText?.let { relation ->
                Text(
                    text = relation,
                    fontSize = 11.sp,
                    color = AppColors.Brand,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

// MARK: - 九宫格图片（对齐 iOS PostImageGridView）

@Composable
private fun PostImageGrid(urls: List<String>, modifier: Modifier = Modifier) {
    if (urls.isEmpty()) return
    val spacing = 6.dp
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(spacing)) {
        if (urls.size == 1) {
            // 单张：宽 2/3 容器，4:3 比例
            AsyncImage(
                model = resolveImageUrl(urls[0]),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxWidth(2f / 3f)
                    .aspectRatio(4f / 3f)
                    .clip(RoundedCornerShape(8.dp))
                    .background(AppColors.SurfaceAlt)
            )
        } else {
            // 多张：2张=2列、3张=3列、4张=2列、5~9张=3列，正方形
            val columns = if (urls.size == 4) 2 else minOf(urls.size, 3)
            urls.chunked(columns).forEach { rowUrls ->
                Row(horizontalArrangement = Arrangement.spacedBy(spacing)) {
                    rowUrls.forEach { url ->
                        AsyncImage(
                            model = resolveImageUrl(url),
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .weight(1f)
                                .aspectRatio(1f)
                                .clip(RoundedCornerShape(8.dp))
                                .background(AppColors.SurfaceAlt)
                        )
                    }
                    // 补齐空位保持等宽
                    repeat(columns - rowUrls.size) {
                        Spacer(Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

// MARK: - 空态

@Composable
private fun EmptyContent(message: String) {
    Column(
        modifier = Modifier.fillMaxSize().padding(top = 80.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(text = "🍃", fontSize = 40.sp)
        Spacer(modifier = Modifier.height(AppDimens.M))
        Text(text = message, color = AppColors.Muted, fontSize = 14.sp)
    }
}