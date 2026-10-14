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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
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
import com.together.app.services.StudioService
import kotlinx.coroutines.delay

/**
 * 工作室「学员管理」列表页（对齐 iOS StudioStudentListViewController）
 *
 * 分段筛选（全部/待续费/本月新增 带计数）+ 搜索 + 学员卡片（剩余课时，待续费转橙色）
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StudioStudentListScreen(
    onBack: () -> Unit = {},
    onStudentClick: (StudioService.StudioStudentItem) -> Unit = {},
    viewModel: StudioViewModel = viewModel()
) {
    val state by viewModel.studentListState.collectAsState()
    var showSearch by remember { mutableStateOf(false) }
    var searchText by remember { mutableStateOf("") }

    // ON_RESUME 刷新
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) viewModel.loadStudents()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    // 搜索防抖
    LaunchedEffect(searchText) {
        delay(350)
        val trimmed = searchText.trim()
        if (trimmed != state.keyword) {
            viewModel.updateStudentKeyword(trimmed)
            viewModel.loadStudents()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
            .statusBarsPadding()
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
                Text(
                    text = "学员管理",
                    fontSize = 17.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.Ink
                )
            }
            Spacer(modifier = Modifier.weight(1f))
            IconButton(onClick = { showSearch = !showSearch }) {
                Icon(
                    Icons.Default.Search,
                    contentDescription = "搜索",
                    tint = AppColors.Ink
                )
            }
        }

        // 搜索条（可展开）
        if (showSearch) {
            OutlinedTextField(
                value = searchText,
                onValueChange = { searchText = it },
                placeholder = { Text("搜索学员昵称 / 家长", fontSize = 14.sp) },
                singleLine = true,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = AppDimens.L, vertical = AppDimens.S)
            )
        }

        // 筛选条
        StudentFilterBar(
            selectedFilter = state.selectedFilter,
            summary = state.summary,
            onSelect = { viewModel.selectStudentFilter(it) }
        )

        // 列表
        PullToRefreshBox(
            isRefreshing = state.loading,
            onRefresh = { viewModel.loadStudents() },
            modifier = Modifier.fillMaxSize()
        ) {
            when {
                state.loading && state.students.isEmpty() -> LoadingView()
                state.error != null && state.students.isEmpty() -> ErrorView(
                    message = state.error ?: "加载失败",
                    onRetry = { viewModel.loadStudents() }
                )
                state.students.isEmpty() -> {
                    val text = if (state.keyword.isNotEmpty()) {
                        "没有找到「${state.keyword}」相关学员"
                    } else {
                        state.selectedFilter.emptyText
                    }
                    EmptyStateView(message = text)
                }
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(
                        start = AppDimens.L,
                        end = AppDimens.L,
                        top = AppDimens.S,
                        bottom = AppDimens.Xl
                    ),
                    verticalArrangement = Arrangement.spacedBy(AppDimens.S)
                ) {
                    items(state.students, key = { it.childId }) { student ->
                        StudentCard(student = student, onClick = { onStudentClick(student) })
                    }
                }
            }
        }
    }
}

// MARK: - 筛选条

@Composable
private fun StudentFilterBar(
    selectedFilter: StudioService.StudentFilter,
    summary: StudioService.StudioStudentSummary?,
    onSelect: (StudioService.StudentFilter) -> Unit
) {
    val filters = StudioService.StudentFilter.entries

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L, vertical = AppDimens.S)
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(4.dp)
    ) {
        filters.forEach { filter ->
            val selected = filter == selectedFilter
            val count = summary?.count(filter) ?: 0
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(13.dp))
                    .background(if (selected) AppColors.BrandSoft else AppColors.Surface)
                    .clickable { onSelect(filter) }
                    .padding(vertical = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "${filter.title} $count",
                    fontSize = 14.sp,
                    fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (selected) AppColors.Ink else AppColors.Sub,
                    maxLines = 1
                )
            }
        }
    }
}

// MARK: - 学员卡片

@Composable
private fun StudentCard(
    student: StudioService.StudioStudentItem,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable(onClick = onClick)
            .padding(horizontal = AppDimens.CardInner, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        TogetherAvatar(
            url = student.avatar,
            name = student.displayName,
            size = 42.dp
        )
        Spacer(modifier = Modifier.width(AppDimens.M))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = student.displayName,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = student.subtitle,
                fontSize = 12.sp,
                color = AppColors.Muted,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        Spacer(modifier = Modifier.width(AppDimens.S))
        Column(horizontalAlignment = Alignment.End) {
            Text(
                text = student.lessonsText,
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (student.isRenew) AppColors.Warn else AppColors.BrandDark
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = student.lessonsCaption,
                fontSize = 11.sp,
                color = if (student.isRenew) AppColors.Warn else AppColors.Muted
            )
        }
    }
}