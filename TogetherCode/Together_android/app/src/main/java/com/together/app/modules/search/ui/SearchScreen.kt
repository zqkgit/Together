package com.together.app.modules.search.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.core.component.EmptyStateView
import com.together.app.core.component.LoadingView
import com.together.app.core.component.resolveImageUrl
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.CourseItem
import com.together.app.core.model.StudioItem
import com.together.app.core.model.TeacherItem
import com.together.app.modules.search.SearchViewModel
import com.together.app.services.SearchService

/**
 * 综合搜索页：品牌色头部 + 三Tab（课程/工作室/老师）+ 热词历史 + 行卡结果
 * 对齐 iOS SearchViewController
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun SearchScreen(
    viewModel: SearchViewModel = viewModel(),
    onBack: () -> Unit = {},
    onCourseClick: (String) -> Unit = {},
    onStudioClick: (String) -> Unit = {},
    onTeacherClick: (String) -> Unit = {}
) {
    val state by viewModel.uiState.collectAsState()
    var inputText by remember { mutableStateOf("") }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        // 品牌色头部（状态栏 + 搜索栏 + Tab栏）
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.Brand)
                .statusBarsPadding()
        ) {
            // 搜索栏
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = AppDimens.M, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    Icons.Default.ArrowBack,
                    contentDescription = "返回",
                    tint = Color.White,
                    modifier = Modifier.size(24.dp).clickable { onBack() }
                )
                Spacer(modifier = Modifier.width(AppDimens.S))

                // 搜索输入框
                OutlinedTextField(
                    value = inputText,
                    onValueChange = { inputText = it },
                    placeholder = { Text("搜索课程、工作室、老师", color = Color.White.copy(alpha = 0.6f), fontSize = 14.sp) },
                    leadingIcon = { Icon(Icons.Default.Search, null, tint = Color.White.copy(alpha = 0.6f), modifier = Modifier.size(16.dp)) },
                    trailingIcon = {
                        if (inputText.isNotEmpty()) {
                            Icon(Icons.Default.Close, "清除", tint = Color.White.copy(alpha = 0.6f),
                                modifier = Modifier.size(18.dp).clickable {
                                    inputText = ""
                                    viewModel.clearKeyword()
                                })
                        }
                    },
                    modifier = Modifier.weight(1f).height(40.dp),
                    shape = RoundedCornerShape(20.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedTextColor = Color.White,
                        unfocusedTextColor = Color.White,
                        focusedBorderColor = Color.Transparent,
                        unfocusedBorderColor = Color.Transparent,
                        focusedContainerColor = Color.White.copy(alpha = 0.2f),
                        unfocusedContainerColor = Color.White.copy(alpha = 0.2f)
                    ),
                    textStyle = TextStyle(fontSize = 14.sp),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                    keyboardActions = KeyboardActions(onSearch = {
                        viewModel.search(inputText)
                    })
                )

                Spacer(modifier = Modifier.width(AppDimens.S))
                // 搜索按钮
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(16.dp))
                        .background(Color.White)
                        .clickable { viewModel.search(inputText) }
                        .padding(horizontal = 14.dp, vertical = 6.dp)
                ) {
                    Text("搜索", fontSize = 14.sp, color = AppColors.Brand, fontWeight = FontWeight.Medium)
                }
            }

            // Tab 栏
            Row(
                modifier = Modifier.fillMaxWidth().height(40.dp),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                SearchViewModel.SearchTab.entries.forEach { tab ->
                    val selected = state.currentTab == tab
                    Column(
                        modifier = Modifier
                            .clickable { viewModel.selectTab(tab) }
                            .padding(horizontal = 20.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = tab.title,
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
            }
        }

        // 内容区
        Box(modifier = Modifier.weight(1f)) {
            when (state.state) {
                SearchViewModel.ListState.IDLE -> {
                    // 默认态：热词 + 历史
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(AppDimens.M)
                    ) {
                        // 热词卡片
                        if (state.hotKeywords.isNotEmpty()) {
                            item {
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clip(RoundedCornerShape(AppDimens.RadiusCard))
                                        .background(AppColors.Surface)
                                        .padding(AppDimens.CardInner)
                                ) {
                                    Text("搜索热词", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Ink)
                                    Spacer(modifier = Modifier.height(AppDimens.M))
                                    FlowRow(
                                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                                        verticalArrangement = Arrangement.spacedBy(8.dp)
                                    ) {
                                        state.hotKeywords.forEach { keyword ->
                                            KeywordChip(keyword) {
                                                inputText = keyword
                                                viewModel.search(keyword)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        // 历史卡片
                        if (state.history.isNotEmpty()) {
                            item {
                                Spacer(modifier = Modifier.height(AppDimens.M))
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clip(RoundedCornerShape(AppDimens.RadiusCard))
                                        .background(AppColors.Surface)
                                        .padding(AppDimens.CardInner)
                                ) {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Text("搜索历史", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Ink)
                                        Text(
                                            "清空",
                                            fontSize = 12.sp,
                                            color = AppColors.Muted,
                                            modifier = Modifier.clickable { viewModel.clearHistory() }
                                        )
                                    }
                                    Spacer(modifier = Modifier.height(AppDimens.M))
                                    FlowRow(
                                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                                        verticalArrangement = Arrangement.spacedBy(8.dp)
                                    ) {
                                        state.history.forEach { keyword ->
                                            KeywordChip(keyword) {
                                                inputText = keyword
                                                viewModel.search(keyword)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                SearchViewModel.ListState.SEARCHING -> LoadingView()

                SearchViewModel.ListState.EMPTY -> {
                    val msg = when (state.currentTab) {
                        SearchViewModel.SearchTab.COURSE -> "暂无相关课程"
                        SearchViewModel.SearchTab.STUDIO -> "暂无相关工作室"
                        SearchViewModel.SearchTab.TEACHER -> "暂无相关老师"
                    }
                    EmptyStateView(message = msg)
                }

                SearchViewModel.ListState.RESULT -> {
                    val listState = rememberLazyListState()
                    // 加载更多
                    LaunchedEffect(listState) {
                        snapshotFlow {
                            val last = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
                            val total = listState.layoutInfo.totalItemsCount
                            last >= total - 3
                        }.collect { shouldLoad ->
                            if (shouldLoad) viewModel.loadMore()
                        }
                    }

                    LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = AppDimens.M, vertical = AppDimens.S)
                    ) {
                        when (state.currentTab) {
                            SearchViewModel.SearchTab.COURSE -> items(state.courses, key = { it.courseId }) { course ->
                                SearchCourseCard(course) { onCourseClick(course.courseId) }
                            }
                            SearchViewModel.SearchTab.STUDIO -> items(state.studios, key = { it.studioId }) { studio ->
                                SearchStudioCard(studio) { onStudioClick(studio.studioId) }
                            }
                            SearchViewModel.SearchTab.TEACHER -> items(state.teachers, key = { it.teacherId }) { teacher ->
                                SearchTeacherCard(teacher) { onTeacherClick(teacher.teacherId) }
                            }
                        }
                        if (state.loading) {
                            item {
                                Box(
                                    modifier = Modifier.fillMaxWidth().padding(16.dp),
                                    contentAlignment = Alignment.Center
                                ) { Text("加载中…", fontSize = 12.sp, color = AppColors.Muted) }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun KeywordChip(text: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(14.dp))
            .background(AppColors.SurfaceAlt)
            .clickable { onClick() }
            .padding(horizontal = 12.dp, vertical = 6.dp)
    ) {
        Text(text = text, fontSize = 12.sp, color = AppColors.Sub)
    }
}

@Composable
private fun SearchCourseCard(item: CourseItem, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable { onClick() }
            .padding(AppDimens.M),
        verticalAlignment = Alignment.CenterVertically
    ) {
        AsyncImage(
            model = resolveImageUrl(item.cover),
            contentDescription = null,
            modifier = Modifier.size(100.dp, 75.dp).clip(RoundedCornerShape(AppDimens.RadiusIcon)),
            contentScale = ContentScale.Crop
        )
        Spacer(modifier = Modifier.width(AppDimens.M))
        Column(modifier = Modifier.weight(1f)) {
            Text(item.title, fontSize = 15.sp, fontWeight = FontWeight.Medium, color = AppColors.Ink, maxLines = 2)
            Spacer(modifier = Modifier.height(4.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                (item.tags ?: emptyList())
                    .take(3)
                    .map { SearchService.cachedTagName(it) }
                    .filter { it.isNotEmpty() }
                    .forEach { tag -> TagPill(tag) }
                item.ageRangeText?.let { TagPill(it) }
            }
            Spacer(modifier = Modifier.height(4.dp))
            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    text = if (item.price > 0) item.priceText else "免费",
                    fontSize = 16.sp, fontWeight = FontWeight.Bold, color = AppColors.Danger
                )
                item.originalPriceText?.let {
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(it, fontSize = 12.sp, color = AppColors.Muted, textDecoration = TextDecoration.LineThrough)
                }
            }
        }
    }
}

@Composable
private fun SearchStudioCard(item: StudioItem, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable { onClick() }
            .padding(AppDimens.M),
        verticalAlignment = Alignment.CenterVertically
    ) {
        AsyncImage(
            model = resolveImageUrl(item.cover),
            contentDescription = null,
            modifier = Modifier.size(100.dp, 75.dp).clip(RoundedCornerShape(AppDimens.RadiusIcon)),
            contentScale = ContentScale.Crop
        )
        Spacer(modifier = Modifier.width(AppDimens.M))
        Column(modifier = Modifier.weight(1f)) {
            Text(item.name, fontSize = 15.sp, fontWeight = FontWeight.Medium, color = AppColors.Ink, maxLines = 1)
            Spacer(modifier = Modifier.height(4.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                (item.typeTags ?: emptyList()).take(3).forEach { tag -> TagPill(tag) }
            }
            Spacer(modifier = Modifier.height(4.dp))
            Text(item.rowMetaText, fontSize = 12.sp, color = AppColors.Muted, maxLines = 1)
        }
    }
}

@Composable
private fun SearchTeacherCard(item: TeacherItem, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
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
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(item.displayName, fontSize = 15.sp, fontWeight = FontWeight.Medium, color = AppColors.Ink)
                if (item.subjectText.isNotEmpty()) {
                    Spacer(modifier = Modifier.width(AppDimens.S))
                    TagPill(item.subjectText)
                }
            }
            val studioText = (item.studios ?: emptyList()).mapNotNull { it.name }.take(2).joinToString(" · ")
            Text(
                if (studioText.isNotEmpty()) studioText else "暂无工作室",
                fontSize = 12.sp,
                color = AppColors.Muted,
                maxLines = 1
            )
        }
    }
}

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