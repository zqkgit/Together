package com.together.app.modules.course.ui

import android.app.Application
import androidx.compose.foundation.background
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
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.component.EmptyStateView
import com.together.app.core.component.LoadingView
import com.together.app.core.component.TogetherAvatar
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.CourseReviewItem
import com.together.app.services.CourseService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * 课程完整评价列表 ViewModel
 */
class CourseReviewsViewModel(app: Application) : AndroidViewModel(app) {

    data class UiState(
        val loading: Boolean = true,
        val items: List<CourseReviewItem> = emptyList(),
        val hasMore: Boolean = false,
        val error: String? = null
    )

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    private var courseId = ""
    private var page = 1

    fun init(courseId: String) {
        if (this.courseId == courseId && _uiState.value.items.isNotEmpty()) return
        this.courseId = courseId
        load(reset = true)
    }

    private fun load(reset: Boolean) {
        if (reset) page = 1
        viewModelScope.launch {
            try {
                val (list, more) = CourseService.fetchCourseReviews(courseId, page)
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
 * 课程完整评价列表（课程详情「查看全部」进入）
 * 对齐 iOS CourseReviewsViewController
 */
@Composable
fun CourseReviewsScreen(
    courseId: String,
    viewModel: CourseReviewsViewModel = viewModel(),
    onBack: () -> Unit = {}
) {
    val state by viewModel.uiState.collectAsState()

    LaunchedEffect(courseId) { viewModel.init(courseId) }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "课程评价", onBack = onBack)

        if (state.loading) {
            LoadingView()
        } else if (state.items.isEmpty()) {
            EmptyStateView(message = "暂无评价\n家长评价后会展示在这里")
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
                items(state.items, key = { it.reviewId }) { review ->
                    CourseReviewCard(review)
                }
            }
        }
    }
}

@Composable
private fun CourseReviewCard(item: CourseReviewItem) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.CardInner, vertical = AppDimens.L)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TogetherAvatar(url = item.avatar, name = item.nickname, size = 36.dp)
            Spacer(modifier = Modifier.width(AppDimens.S))
            Column(modifier = Modifier.weight(1f)) {
                Text(item.nickname, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = AppColors.Ink)
                Text(item.timeText, fontSize = 11.sp, color = AppColors.Muted)
            }
            // 星级
            val rating = item.rating.coerceIn(0, 5)
            Text("★".repeat(rating) + "☆".repeat(5 - rating), fontSize = 14.sp, color = AppColors.Clay)
        }
        if (item.content.isNotEmpty()) {
            Spacer(modifier = Modifier.height(AppDimens.S))
            Text(item.content, fontSize = 14.sp, color = AppColors.Ink, lineHeight = 20.sp)
        }
        // 评价图片
        item.images?.takeIf { it.isNotEmpty() }?.let { images ->
            Spacer(modifier = Modifier.height(AppDimens.S))
            Row(horizontalArrangement = Arrangement.spacedBy(AppDimens.S)) {
                images.take(3).forEach { url ->
                    coil.compose.AsyncImage(
                        model = com.together.app.core.component.resolveImageUrl(url),
                        contentDescription = null,
                        modifier = Modifier
                            .weight(1f)
                            .height(80.dp)
                            .clip(RoundedCornerShape(AppDimens.RadiusIcon)),
                        contentScale = androidx.compose.ui.layout.ContentScale.Crop
                    )
                }
            }
        }
    }
}