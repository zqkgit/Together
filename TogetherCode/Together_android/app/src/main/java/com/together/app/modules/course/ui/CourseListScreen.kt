package com.together.app.modules.course.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.core.component.LoadingView
import com.together.app.core.component.resolveImageUrl
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.CourseItem
import com.together.app.modules.course.CourseViewModel
import com.together.app.modules.course.CourseViewModel.ListState

/**
 * 课程更多页（对齐 iOS CourseViewController）
 * 搜索栏 + 标签横滑 + 热词/历史面板 + 课程列表 + 分页
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun CourseListScreen(
    viewModel: CourseViewModel = viewModel(),
    onCourseClick: (String) -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()

    // 本地输入文本，与 ViewModel keyword 同步（点击热词/历史时回填）
    var inputText by remember { mutableStateOf("") }
    LaunchedEffect(uiState.keyword) { inputText = uiState.keyword }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        // 品牌色头部（搜索栏 + 标签横滑）
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.Brand)
                .padding(top = 48.dp)
        ) {
            // 搜索栏
            SearchBarRow(
                text = inputText,
                onTextChange = { inputText = it },
                onSearch = { viewModel.search(it) },
                onClear = {
                    inputText = ""
                    viewModel.clearKeyword()
                }
            )
            // 标签横滑
            TagScrollRow(
                tags = uiState.tags,
                selectedIndex = uiState.selectedTagIndex,
                onSelect = { index -> viewModel.search(uiState.keyword, index) }
            )
        }

        // 内容区
        when (uiState.state) {
            ListState.IDLE -> {
                // 热词 + 历史
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = AppDimens.M)
                ) {
                    if (uiState.hotKeywords.isNotEmpty()) {
                        Spacer(modifier = Modifier.height(AppDimens.M))
                        KeywordCard(
                            title = "🔥 搜索热词",
                            keywords = uiState.hotKeywords,
                            tagColor = AppColors.BrandSoft,
                            textColor = AppColors.Brand,
                            onClick = { viewModel.search(it) }
                        )
                    }
                    if (uiState.history.isNotEmpty()) {
                        Spacer(modifier = Modifier.height(AppDimens.M))
                        KeywordCard(
                            title = "搜索历史",
                            keywords = uiState.history,
                            tagColor = AppColors.SurfaceAlt,
                            textColor = AppColors.Sub,
                            onClick = { viewModel.search(it) },
                            onClear = { viewModel.clearHistory() }
                        )
                    }
                }
            }
            ListState.SEARCHING -> {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    LoadingView()
                }
            }
            ListState.EMPTY -> {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("🔍", fontSize = 40.sp)
                        Spacer(modifier = Modifier.height(AppDimens.M))
                        Text("暂无相关课程", color = AppColors.Muted, fontSize = 15.sp)
                    }
                }
            }
            ListState.RESULT -> {
                // 课程列表 + 分页
                val listState = rememberLazyListState()
                // 触底加载更多
                val shouldLoadMore by remember {
                    derivedStateOf {
                        val last = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
                        last >= uiState.courses.size - 3 && uiState.hasMore && !uiState.loading
                    }
                }
                LaunchedEffect(shouldLoadMore) {
                    if (shouldLoadMore) viewModel.loadMore()
                }

                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(
                        top = AppDimens.M, bottom = 100.dp
                    )
                ) {
                    items(uiState.courses, key = { it.courseId }) { course ->
                        CourseListCard(item = course, onClick = { onCourseClick(course.courseId) })
                    }
                    if (uiState.loading) {
                        item {
                            Box(
                                modifier = Modifier.fillMaxWidth().padding(AppDimens.L),
                                contentAlignment = Alignment.Center
                            ) {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(24.dp),
                                    color = AppColors.Brand,
                                    strokeWidth = 2.dp
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 搜索栏

@Composable
private fun SearchBarRow(text: String, onTextChange: (String) -> Unit, onSearch: (String) -> Unit, onClear: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M, vertical = AppDimens.S),
        verticalAlignment = Alignment.CenterVertically
    ) {
        OutlinedTextField(
            value = text,
            onValueChange = onTextChange,
            placeholder = { Text("搜索课程", color = Color.White.copy(alpha = 0.6f), fontSize = 14.sp) },
            leadingIcon = {
                Icon(Icons.Default.Search, contentDescription = null, tint = Color.White.copy(alpha = 0.6f), modifier = Modifier.size(16.dp))
            },
            trailingIcon = {
                if (text.isNotEmpty()) {
                    Icon(
                        Icons.Default.Close,
                        contentDescription = "清除",
                        tint = Color.White.copy(alpha = 0.6f),
                        modifier = Modifier.size(18.dp).clickable {
                            onTextChange("")
                            onClear()
                        }
                    )
                }
            },
            modifier = Modifier
                .weight(1f)
                .height(40.dp)
                .clip(RoundedCornerShape(20.dp)),
            colors = OutlinedTextFieldDefaults.colors(
                focusedContainerColor = Color.White.copy(alpha = 0.2f),
                unfocusedContainerColor = Color.White.copy(alpha = 0.2f),
                focusedTextColor = Color.White,
                unfocusedTextColor = Color.White,
                cursorColor = Color.White,
                focusedBorderColor = Color.Transparent,
                unfocusedBorderColor = Color.Transparent
            ),
            shape = RoundedCornerShape(20.dp),
            singleLine = true,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            keyboardActions = KeyboardActions(onSearch = { onSearch(text) })
        )
        Spacer(modifier = Modifier.width(AppDimens.S))
        // 搜索按钮
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(16.dp))
                .background(Color.White)
                .clickable { onSearch(text) }
                .padding(horizontal = 16.dp, vertical = 8.dp)
        ) {
            Text("搜索", color = AppColors.Brand, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

// MARK: - 标签横滑

@Composable
private fun TagScrollRow(
    tags: List<com.together.app.services.SearchService.TagItem>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = AppDimens.M),
        horizontalArrangement = Arrangement.spacedBy(AppDimens.S)
    ) {
        // "全部"按钮
        TagPill(text = "全部", selected = selectedIndex == -1, onClick = { onSelect(-1) })
        tags.forEachIndexed { index, tag ->
            TagPill(
                text = tag.name ?: "",
                selected = index == selectedIndex,
                onClick = { onSelect(index) }
            )
        }
    }
    Spacer(modifier = Modifier.height(AppDimens.S))
}

@Composable
private fun TagPill(text: String, selected: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(14.dp))
            .background(if (selected) Color.White else Color.White.copy(alpha = 0.15f))
            .clickable { onClick() }
            .padding(horizontal = 14.dp, vertical = 6.dp)
    ) {
        Text(
            text = text,
            color = if (selected) AppColors.Brand else Color.White.copy(alpha = 0.7f),
            fontSize = 13.sp,
            fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal
        )
    }
}

// MARK: - 热词/历史卡片

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun KeywordCard(
    title: String,
    keywords: List<String>,
    tagColor: Color,
    textColor: Color,
    onClick: (String) -> Unit,
    onClear: (() -> Unit)? = null
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.CardInner)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(title, color = AppColors.Ink, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
            onClear?.let {
                Text("清空", color = AppColors.Muted, fontSize = 12.sp, modifier = Modifier.clickable { it() })
            }
        }
        Spacer(modifier = Modifier.height(AppDimens.M))
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(AppDimens.S),
            verticalArrangement = Arrangement.spacedBy(AppDimens.S)
        ) {
            keywords.forEach { kw ->
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(AppDimens.RadiusTag))
                        .background(tagColor)
                        .clickable { onClick(kw) }
                        .padding(horizontal = 12.dp, vertical = 6.dp)
                ) {
                    Text(kw, color = textColor, fontSize = 13.sp)
                }
            }
        }
    }
}

// MARK: - 课程列表卡片（横向布局）

@Composable
private fun CourseListCard(item: CourseItem, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M, vertical = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable { onClick() }
            .padding(AppDimens.M)
    ) {
        // 封面
        Box(
            modifier = Modifier
                .size(100.dp)
                .clip(RoundedCornerShape(AppDimens.RadiusCard))
                .background(AppColors.SurfaceAlt)
        ) {
            if (!item.cover.isNullOrBlank()) {
                AsyncImage(
                    model = resolveImageUrl(item.cover),
                    contentDescription = item.title,
                    modifier = Modifier.fillMaxSize()
                )
            }
        }
        Spacer(modifier = Modifier.width(AppDimens.M))
        // 信息
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(
                text = item.title,
                color = AppColors.Ink,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = item.studioName,
                color = AppColors.Muted,
                fontSize = 12.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                item.ageRangeText?.let { age ->
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(AppDimens.RadiusTag))
                            .background(AppColors.BrandSoft)
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    ) {
                        Text(age, color = AppColors.Brand, fontSize = 10.sp)
                    }
                    Spacer(modifier = Modifier.width(AppDimens.Xs))
                }
                Text(item.ratingText, color = AppColors.Warn, fontSize = 12.sp)
            }
            Row(verticalAlignment = Alignment.Bottom) {
                Text(item.priceText, color = AppColors.Clay, fontSize = 17.sp, fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.width(4.dp))
                item.originalPriceText?.let { original ->
                    Text(original, color = AppColors.Muted, fontSize = 11.sp, textDecoration = androidx.compose.ui.text.style.TextDecoration.LineThrough)
                }
                Spacer(modifier = Modifier.weight(1f))
                item.sales?.let { sales ->
                    if (sales > 0) Text("已售${sales}", color = AppColors.Muted, fontSize = 11.sp)
                }
            }
        }
    }
}