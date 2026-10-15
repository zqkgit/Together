@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.together.app.modules.mine.ui

import android.app.Application
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import com.together.app.core.component.AppPullRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.component.resolveImageUrl
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.PostItem
import com.together.app.services.PostService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

// MARK: - ViewModel

/**
 * 作品管理 ViewModel（对齐 iOS WorkManagementViewController）
 */
class WorkManagementViewModel(app: Application) : AndroidViewModel(app) {

    data class State(
        val works: List<PostItem> = emptyList(),
        val counts: List<Int> = listOf(0, 0, 0),
        val category: Int = 0, // 0=全部 1=公开 2=未公开
        val loading: Boolean = false,
        val refreshing: Boolean = false,
        val loadingMore: Boolean = false,
        val hasMore: Boolean = true
    )

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state.asStateFlow()

    private val _toast = MutableStateFlow<String?>(null)
    val toast: StateFlow<String?> = _toast.asStateFlow()

    private var page = 1

    fun clearToast() { _toast.value = null }

    private val statusParam: String get() = listOf("all", "public", "private")[_state.value.category]

    fun loadWorks(reset: Boolean) {
        val s = _state.value
        if (s.loading || s.loadingMore) return
        viewModelScope.launch {
            if (reset) {
                page = 1
                _state.value = s.copy(
                    loading = s.works.isNotEmpty(),
                    refreshing = s.works.isNotEmpty()
                )
            } else {
                _state.value = s.copy(loadingMore = true)
            }
            try {
                val (items, counts, hasMore) = PostService.fetchMyWorks(
                    page = page, status = statusParam
                )
                val cur = _state.value
                _state.value = cur.copy(
                    works = if (reset) items else cur.works + items,
                    counts = if (counts.size == 3) counts else cur.counts,
                    hasMore = hasMore,
                    loading = false, refreshing = false, loadingMore = false
                )
                page++
            } catch (e: Exception) {
                val cur = _state.value
                _state.value = cur.copy(loading = false, refreshing = false, loadingMore = false)
                _toast.value = e.message ?: "加载失败"
            }
        }
    }

    fun selectCategory(index: Int) {
        if (_state.value.category == index) return
        _state.value = _state.value.copy(category = index, works = emptyList(), hasMore = true)
        loadWorks(reset = true)
    }
}

// MARK: - 作品管理页面

/**
 * 作品管理（对齐 iOS WorkManagementViewController）
 * 分类 chips + 两列作品卡 + FAB 发布按钮
 */
@Composable
fun WorkManagementScreen(
    onBack: () -> Unit,
    onPostClick: (String) -> Unit,
    onPublish: () -> Unit,
    viewModel: WorkManagementViewModel = viewModel()
) {
    val state by viewModel.state.collectAsState()
    val toast by viewModel.toast.collectAsState()
    val context = LocalContext.current

    LaunchedEffect(Unit) { viewModel.loadWorks(reset = true) }

    LaunchedEffect(toast) {
        if (toast != null) {
            android.widget.Toast.makeText(
                context, toast, android.widget.Toast.LENGTH_SHORT
            ).show()
            viewModel.clearToast()
        }
    }

    Box(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        Column(modifier = Modifier.fillMaxSize()) {
            TogetherTopBar(title = "作品管理", onBack = onBack)

            // 分类 chips
            CategoryChips(
                counts = state.counts,
                selected = state.category,
                onSelect = { viewModel.selectCategory(it) }
            )

            // 作品网格
            AppPullRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = { viewModel.loadWorks(reset = true) },
                modifier = Modifier.weight(1f)
            ) {
                if (state.loading && state.works.isEmpty()) {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = AppColors.Brand)
                    }
                } else if (state.works.isEmpty()) {
                    Column(
                        modifier = Modifier.fillMaxSize(),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        Text(text = "🎨", fontSize = 40.sp)
                        Spacer(modifier = Modifier.height(AppDimens.M))
                        Text(
                            text = "还没有作品，点击右下角发布吧",
                            color = AppColors.Muted,
                            fontSize = 14.sp
                        )
                    }
                } else {
                    val gridState = rememberLazyGridState()
                    val shouldLoadMore by remember {
                        derivedStateOf {
                            val last = gridState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
                            last >= gridState.layoutInfo.totalItemsCount - 3
                        }
                    }
                    LaunchedEffect(shouldLoadMore) {
                        if (shouldLoadMore && state.hasMore && !state.loadingMore) {
                            viewModel.loadWorks(reset = false)
                        }
                    }

                    LazyVerticalGrid(
                        state = gridState,
                        columns = GridCells.Fixed(2),
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(
                            top = AppDimens.S, start = AppDimens.L, end = AppDimens.L, bottom = 108.dp
                        ),
                        horizontalArrangement = Arrangement.spacedBy(AppDimens.M),
                        verticalArrangement = Arrangement.spacedBy(AppDimens.M)
                    ) {
                        items(state.works, key = { it.postId }) { item ->
                            WorksManageCard(item = item, onClick = { onPostClick(item.postId) })
                        }
                        if (state.loadingMore) {
                            item(span = { GridItemSpan(2) }) {
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

        // FAB 发布按钮
        Box(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = AppDimens.L, bottom = AppDimens.L)
                .size(56.dp)
                .shadow(8.dp, CircleShape, ambientColor = Color.Black.copy(alpha = 0.18f))
                .clip(CircleShape)
                .background(AppColors.Brand)
                .clickable(onClick = onPublish),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Filled.Add,
                contentDescription = "发布",
                tint = Color.White,
                modifier = Modifier.size(28.dp)
            )
        }
    }
}

// MARK: - 分类 chips

@Composable
private fun CategoryChips(
    counts: List<Int>,
    selected: Int,
    onSelect: (Int) -> Unit
) {
    val titles = listOf("全部", "公开", "未公开").mapIndexed { index, title ->
        "$title${counts.getOrElse(index) { 0 }}"
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L, vertical = AppDimens.S),
        horizontalArrangement = Arrangement.spacedBy(AppDimens.S)
    ) {
        titles.forEachIndexed { index, title ->
            val isSelected = index == selected
            Text(
                text = title,
                fontSize = 13.sp,
                fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                color = if (isSelected) Color.White else AppColors.Sub,
                modifier = Modifier
                    .clip(RoundedCornerShape(AppDimens.RadiusTag))
                    .background(if (isSelected) AppColors.Brand else AppColors.SurfaceAlt)
                    .clickable { onSelect(index) }
                    .padding(horizontal = 14.dp, vertical = 7.dp)
            )
        }
    }
}

// MARK: - 作品管理卡片（对齐 iOS WorksManageCell）

@Composable
private fun WorksManageCard(item: PostItem, onClick: () -> Unit) {
    val colorPair = workPalette(item.safeTopic)
    Column(
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(AppColors.Surface)
            .clickable(onClick = onClick)
    ) {
        // 封面（0.78 比例）
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(1f / 0.78f)
                .background(Brush.linearGradient(listOf(colorPair.first, colorPair.second)))
        ) {
            val firstImage = item.imageList.firstOrNull()
            if (firstImage != null) {
                AsyncImage(
                    model = resolveImageUrl(firstImage),
                    contentDescription = null,
                    contentScale = androidx.compose.ui.layout.ContentScale.Crop,
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
            // 公开状态徽章
            Text(
                text = item.visibilityText,
                fontSize = 10.sp,
                color = Color.White,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(top = 8.dp, end = 8.dp)
                    .clip(RoundedCornerShape(9.dp))
                    .background(
                        if (item.isPublic) AppColors.Brand
                        else AppColors.Sub.copy(alpha = 0.7f)
                    )
                    .padding(horizontal = 8.dp, vertical = 2.dp)
            )
        }
        // 信息区
        Column(Modifier.padding(horizontal = AppDimens.M, vertical = AppDimens.S + 2.dp)) {
            Text(
                text = item.bodyText.ifEmpty { "作品分享" },
                fontSize = 14.sp,
                color = AppColors.Ink,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(6.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = item.timeText,
                    fontSize = 11.sp,
                    color = AppColors.Sub,
                    modifier = Modifier.weight(1f)
                )
                Icon(
                    imageVector = Icons.Filled.Favorite,
                    contentDescription = null,
                    tint = AppColors.Muted,
                    modifier = Modifier.size(11.dp)
                )
                Text(
                    text = " ${item.likeText}",
                    fontSize = 11.sp,
                    color = AppColors.Sub
                )
            }
            item.safeTopic?.let { topic ->
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "#$topic",
                    fontSize = 11.sp,
                    color = AppColors.Brand,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

// MARK: - 话题色板（对齐 iOS WorkCardView.palette / PlazaScreen.topicPalette）

private fun workPalette(topic: String?): Pair<Color, Color> {
    return when (topic) {
        "水彩" -> Color(0xFF7FB5C8) to Color(0xFF4A7C9B)
        "黏土" -> Color(0xFFE0A878) to Color(0xFFC15F2C)
        "书法" -> Color(0xFF8B8B8B) to Color(0xFF4A4A4A)
        "素描" -> Color(0xFFC9C4BC) to Color(0xFF8A8478)
        "国画" -> Color(0xFFA8BDA0) to Color(0xFF6E8A66)
        else -> AppColors.BrandSoft to AppColors.Brand
    }
}