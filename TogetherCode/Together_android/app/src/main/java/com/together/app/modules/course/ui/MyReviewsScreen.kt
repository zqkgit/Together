package com.together.app.modules.course.ui

import android.app.Application
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.component.EmptyStateView
import com.together.app.core.component.LoadingView
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.services.MineService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * 我的评价 ViewModel
 */
class MyReviewsViewModel(app: Application) : AndroidViewModel(app) {

    data class UiState(
        val loading: Boolean = true,
        val items: List<MineService.MyReviewItem> = emptyList(),
        val hasMore: Boolean = false,
        val error: String? = null
    )

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    private var page = 1

    fun load(reset: Boolean = true) {
        if (reset) page = 1
        viewModelScope.launch {
            try {
                val (list, more) = MineService.fetchMyReviews(page)
                val newItems = if (reset || page <= 1) list else _uiState.value.items + list
                _uiState.value = _uiState.value.copy(
                    loading = false, items = newItems, hasMore = more, error = null
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    fun loadMore() {
        if (!_uiState.value.hasMore) return
        page++
        load(reset = false)
    }
}

/**
 * 我的评价（课程名 + 评分 + 状态标签 + 内容 + 双回复）
 * 待审核 / 已驳回 可点击编辑
 * 对齐 iOS MyReviewsViewController
 */
@Composable
fun MyReviewsScreen(
    viewModel: MyReviewsViewModel = viewModel(),
    onBack: () -> Unit = {},
    onEditReview: (MineService.MyReviewItem) -> Unit = {}
) {
    val state by viewModel.uiState.collectAsState()

    // ON_RESUME 刷新（编辑/发布后返回时刷新）
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                viewModel.load(reset = true)
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "我的评价", onBack = onBack)

        if (state.loading) {
            LoadingView()
        } else if (state.items.isEmpty()) {
            EmptyStateView(message = "暂无评价\n上完课后可以给课程写评价哦")
        } else {
            val listState = rememberLazyListState()
            LaunchedEffect(listState) {
                androidx.compose.runtime.snapshotFlow {
                    val last = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
                    val total = listState.layoutInfo.totalItemsCount
                    last >= total - 3 && total > 0
                }.collect { shouldLoad -> if (shouldLoad) viewModel.loadMore() }
            }
            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(horizontal = AppDimens.M, vertical = AppDimens.S),
                verticalArrangement = Arrangement.spacedBy(AppDimens.S)
            ) {
                items(state.items, key = { it.reviewId ?: "" }) { item ->
                    MyReviewCard(item, onClick = {
                        // 待审核(0) / 已驳回(2) 可编辑；已通过(1) 不可编辑
                        val status = item.status ?: 0
                        if (status != 1) {
                            onEditReview(item)
                        }
                    })
                }
            }
        }
    }
}

@Composable
private fun MyReviewCard(item: MineService.MyReviewItem, onClick: () -> Unit = {}) {
    val status = item.status ?: 0
    val canEdit = status != 1

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable(canEdit) { onClick() }
            .padding(horizontal = AppDimens.CardInner, vertical = AppDimens.L)
    ) {
        // 课程名
        Text(
            item.course?.title ?: "课程评价",
            fontSize = 15.sp, fontWeight = FontWeight.Medium, color = AppColors.Ink,
            maxLines = 1
        )
        Spacer(modifier = Modifier.height(AppDimens.S))

        // 星级 + 状态标签
        Row(verticalAlignment = Alignment.CenterVertically) {
            val rating = (item.rating ?: 5).coerceIn(0, 5)
            Text("★".repeat(rating) + "☆".repeat(5 - rating), fontSize = 14.sp, color = AppColors.Clay)
            Spacer(modifier = Modifier.weight(1f))
            StatusTag(item.statusText, status)
        }

        // 内容
        item.content?.takeIf { it.isNotEmpty() }?.let {
            Spacer(modifier = Modifier.height(AppDimens.S))
            Text(it, fontSize = 14.sp, color = AppColors.Ink, lineHeight = 20.sp)
        }

        // 工作室回复
        item.replyContent?.takeIf { it.isNotEmpty() }?.let { reply ->
            Spacer(modifier = Modifier.height(AppDimens.S))
            ReplyRow(tag = "工作室", text = reply, tagColor = AppColors.Info, bgColor = AppColors.InfoTint)
        }

        // 老师回复
        item.teacherReplyContent?.takeIf { it.isNotEmpty() }?.let { reply ->
            Spacer(modifier = Modifier.height(AppDimens.S))
            ReplyRow(tag = "老师", text = reply, tagColor = AppColors.Wood, bgColor = AppColors.BrandSoft)
        }

        // 驳回原因
        if (status == 2) {
            item.rejectReason?.takeIf { it.isNotEmpty() }?.let { reason ->
                Spacer(modifier = Modifier.height(AppDimens.S))
                Text("驳回原因：$reason", fontSize = 12.sp, color = AppColors.Danger)
            }
        }

        // 时间
        Spacer(modifier = Modifier.height(AppDimens.S))
        Text(item.timeText, fontSize = 11.sp, color = AppColors.Muted)
    }
}

@Composable
private fun StatusTag(text: String, status: Int) {
    val (fg, bg) = when (status) {
        1 -> AppColors.Success to AppColors.SuccessTint
        2 -> AppColors.Danger to AppColors.DangerTint
        else -> AppColors.Warn to AppColors.WarnTint
    }
    Text(
        text,
        fontSize = 11.sp,
        color = fg,
        modifier = Modifier
            .clip(RoundedCornerShape(4.dp))
            .background(bg)
            .padding(horizontal = 8.dp, vertical = 2.dp)
    )
}

@Composable
private fun ReplyRow(tag: String, text: String, tagColor: androidx.compose.ui.graphics.Color, bgColor: androidx.compose.ui.graphics.Color) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(6.dp))
            .background(bgColor)
            .padding(horizontal = 10.dp, vertical = 8.dp)
    ) {
        Text(
            "${tag}回复：",
            fontSize = 12.sp, color = tagColor, fontWeight = FontWeight.Medium
        )
        Text(
            text,
            fontSize = 12.sp, color = AppColors.Sub,
            modifier = Modifier.weight(1f)
        )
    }
}