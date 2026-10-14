package com.together.app.modules.home.ui

import android.widget.Toast
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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.core.component.resolveImageUrl
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.StudioItem
import com.together.app.core.model.TeacherItem
import com.together.app.services.SearchService
import androidx.compose.runtime.collectAsState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * 工作室更多页（对齐 iOS StudiosViewController）
 * 品牌色头部 + Tab（找画室/找老师）+ 列表 + 分页
 */
class StudiosViewModel(app: android.app.Application) : AndroidViewModel(app) {

    data class State(
        val tab: Int = 0, // 0=找画室 1=找老师
        val studios: List<StudioItem> = emptyList(),
        val teachers: List<TeacherItem> = emptyList(),
        val loading: Boolean = false,
        val hasMore: Boolean = true,
        val error: String? = null
    )

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state.asStateFlow()

    private var page = 1

    init {
        load(tab = 0, refresh = true)
    }

    fun switchTab(tab: Int) {
        if (tab == _state.value.tab) return
        _state.value = _state.value.copy(tab = tab)
        load(tab, refresh = true)
    }

    fun loadMore() {
        val s = _state.value
        if (s.loading || !s.hasMore) return
        load(s.tab, refresh = false)
    }

    private fun load(tab: Int, refresh: Boolean) {
        viewModelScope.launch {
            if (refresh) page = 1
            _state.value = _state.value.copy(loading = true, error = null)
            try {
                if (tab == 0) {
                    val (list, hasMore) = SearchService.searchStudios("", page)
                    val merged = if (refresh) list else _state.value.studios + list
                    _state.value = _state.value.copy(studios = merged, loading = false, hasMore = hasMore)
                } else {
                    val (list, hasMore) = SearchService.searchTeachers("", page)
                    val merged = if (refresh) list else _state.value.teachers + list
                    _state.value = _state.value.copy(teachers = merged, loading = false, hasMore = hasMore)
                }
                page++
            } catch (e: Exception) {
                _state.value = _state.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }
}

@Composable
fun StudiosScreen(
    onBack: () -> Unit = {},
    onStudioClick: (String) -> Unit = {},
    onTeacherClick: (String) -> Unit = {},
    viewModel: StudiosViewModel = viewModel()
) {
    val state by viewModel.state.collectAsState()
    val context = LocalContext.current

    // Toast 错误提示
    LaunchedEffect(state.error) {
        state.error?.let {
            Toast.makeText(context, it, Toast.LENGTH_SHORT).show()
        }
    }

    // 分页加载
    val listState = rememberLazyListState()
    LaunchedEffect(listState, state.tab) {
        snapshotFlow {
            val last = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            val total = listState.layoutInfo.totalItemsCount
            last >= total - 3 && total > 0
        }.collect { shouldLoad ->
            if (shouldLoad && !state.loading && state.hasMore) {
                viewModel.loadMore()
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
    ) {
        // 品牌色头部：返回 + Tab
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Brush.verticalGradient(listOf(AppColors.Brand, AppColors.BrandDark)))
                .statusBarsPadding()
        ) {
            // 返回按钮行
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(AppDimens.TopBarHeight)
                    .padding(horizontal = AppDimens.S),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "返回",
                    tint = Color.White,
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .clickable { onBack() }
                        .padding(4.dp)
                )
                Text(
                    text = "工作室",
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                    modifier = Modifier.padding(start = AppDimens.S)
                )
            }
            // Tab 栏
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(44.dp),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                TabButton("找画室", state.tab == 0) { viewModel.switchTab(0) }
                TabButton("找老师", state.tab == 1) { viewModel.switchTab(1) }
            }
        }

        // 列表
        if (state.tab == 0) {
            if (state.studios.isEmpty() && !state.loading) {
                EmptyText("暂无工作室")
            } else {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(
                        start = AppDimens.M,
                        end = AppDimens.M,
                        top = AppDimens.S,
                        bottom = AppDimens.Xl
                    ),
                    verticalArrangement = Arrangement.spacedBy(AppDimens.S)
                ) {
                    items(state.studios.size) { index ->
                        StudioListCard(item = state.studios[index]) {
                            onStudioClick(state.studios[index].studioId)
                        }
                    }
                    if (state.loading) {
                        item { LoadingText() }
                    }
                }
            }
        } else {
            if (state.teachers.isEmpty() && !state.loading) {
                EmptyText("暂无老师")
            } else {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(
                        start = AppDimens.M,
                        end = AppDimens.M,
                        top = AppDimens.S,
                        bottom = AppDimens.Xl
                    ),
                    verticalArrangement = Arrangement.spacedBy(AppDimens.S)
                ) {
                    items(state.teachers.size) { index ->
                        TeacherListCard(item = state.teachers[index]) {
                            onTeacherClick(state.teachers[index].teacherId)
                        }
                    }
                    if (state.loading) {
                        item { LoadingText() }
                    }
                }
            }
        }
    }
}

// MARK: - Tab 按钮

@Composable
private fun TabButton(text: String, selected: Boolean, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .clickable { onClick() }
            .padding(horizontal = AppDimens.L),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = text,
            fontSize = 14.sp,
            fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
            color = if (selected) Color.White else Color.White.copy(alpha = 0.7f)
        )
        Spacer(modifier = Modifier.height(4.dp))
        Box(
            modifier = Modifier
                .width(24.dp)
                .height(3.dp)
                .clip(RoundedCornerShape(1.5.dp))
                .background(if (selected) Color.White else Color.Transparent)
        )
    }
}

// MARK: - 工作室卡

@Composable
private fun StudioListCard(item: StudioItem, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable { onClick() }
            .padding(AppDimens.M),
        verticalAlignment = Alignment.CenterVertically
    ) {
        AsyncImage(
            model = resolveImageUrl(item.cover),
            contentDescription = null,
            modifier = Modifier
                .size(100.dp, 75.dp)
                .clip(RoundedCornerShape(AppDimens.RadiusIcon)),
            contentScale = ContentScale.Crop
        )
        Spacer(modifier = Modifier.width(AppDimens.M))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = item.name,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = AppColors.Ink,
                maxLines = 1
            )
            Spacer(modifier = Modifier.height(4.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                (item.typeTags ?: emptyList()).take(2).forEach { tag -> TagPill(tag) }
            }
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = item.rowMetaText,
                fontSize = 12.sp,
                color = AppColors.Muted,
                maxLines = 1
            )
        }
    }
}

// MARK: - 老师卡

@Composable
private fun TeacherListCard(item: TeacherItem, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable { onClick() }
            .padding(horizontal = AppDimens.M, vertical = AppDimens.L),
        verticalAlignment = Alignment.CenterVertically
    ) {
        AsyncImage(
            model = resolveImageUrl(item.avatar),
            contentDescription = null,
            modifier = Modifier.size(48.dp).clip(CircleShape),
            contentScale = ContentScale.Crop
        )
        Spacer(modifier = Modifier.width(AppDimens.M))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = item.displayName,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = AppColors.Ink
            )
            val studioText = (item.studios ?: emptyList()).mapNotNull { it.name }.take(2).joinToString(" · ")
            if (studioText.isNotEmpty()) {
                Text(studioText, fontSize = 12.sp, color = AppColors.Muted, maxLines = 1)
            }
            if (item.subjectText.isNotEmpty()) {
                Text(item.subjectText, fontSize = 12.sp, color = AppColors.Sub, maxLines = 1)
            }
        }
        Text(
            text = item.ratingText,
            fontSize = 14.sp,
            color = AppColors.Wood,
            fontWeight = FontWeight.Medium
        )
    }
}

// MARK: - 辅助

@Composable
private fun TagPill(text: String) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(10.dp))
            .background(AppColors.BrandSoft)
            .padding(horizontal = 8.dp, vertical = 2.dp)
    ) {
        Text(text = text, fontSize = 10.sp, color = AppColors.Brand)
    }
}

@Composable
private fun EmptyText(msg: String) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Text(msg, color = AppColors.Muted, fontSize = 14.sp)
    }
}

@Composable
private fun LoadingText() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = AppDimens.M),
        contentAlignment = Alignment.Center
    ) {
        Text("加载中...", color = AppColors.Muted, fontSize = 13.sp)
    }
}