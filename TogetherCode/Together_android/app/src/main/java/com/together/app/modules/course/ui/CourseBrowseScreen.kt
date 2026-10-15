package com.together.app.modules.course.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.together.app.core.component.LoadingView
import com.together.app.core.component.resolveImageUrl
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.CourseItem
import com.together.app.services.SearchService
import kotlinx.coroutines.launch

/**
 * 课程浏览页（对齐 iOS CourseBrowseViewController）
 * 首页「为你推荐 → 全部」入口：品牌色背景 + 标签横滑筛选 + 课程卡片列表，无搜索栏
 */
@Composable
fun CourseBrowseScreen(
    onBack: () -> Unit = {},
    onCourseClick: (String) -> Unit = {}
) {
    val scope = rememberCoroutineScope()

    var tags by remember { mutableStateOf<List<SearchService.TagItem>>(emptyList()) }
    var selectedTagIndex by remember { mutableIntStateOf(0) } // 0 = 全部
    var courses by remember { mutableStateOf<List<CourseItem>>(emptyList()) }
    var currentPage by remember { mutableIntStateOf(1) }
    var hasMore by remember { mutableStateOf(true) }
    var isLoading by remember { mutableStateOf(false) }
    var initialLoaded by remember { mutableStateOf(false) }

    // 加载标签
    LaunchedEffect(Unit) {
        runCatching { SearchService.fetchTags() }
            .onSuccess { tags = it }
    }

    // 加载课程
    fun loadCourses(page: Int) {
        if (isLoading) return
        scope.launch {
            isLoading = true
            try {
                val tagId = if (selectedTagIndex == 0) "" else tags.getOrNull(selectedTagIndex - 1)?.id ?: ""
                val (list, more) = SearchService.searchCourses("", page, tagId.ifEmpty { null })
                if (page == 1) courses = list else courses = courses + list
                hasMore = more && list.isNotEmpty()
                currentPage = page
            } catch (_: Exception) { }
            isLoading = false
            initialLoaded = true
        }
    }

    // 初始加载 + 切换标签时重新加载
    LaunchedEffect(selectedTagIndex) {
        courses = emptyList()
        currentPage = 1
        hasMore = true
        loadCourses(1)
    }

    val listState = rememberLazyListState()
    val shouldLoadMore by remember {
        derivedStateOf {
            val last = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            last >= courses.size - 3 && hasMore && !isLoading
        }
    }
    LaunchedEffect(shouldLoadMore) {
        if (shouldLoadMore) loadCourses(currentPage + 1)
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        // 品牌色头部：返回按钮 + 标题 + 标签横滑
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.Brand)
                .statusBarsPadding()
        ) {
            // 顶栏
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(44.dp)
            ) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "返回",
                    tint = Color.White,
                    modifier = Modifier
                        .align(Alignment.CenterStart)
                        .padding(start = AppDimens.M)
                        .size(24.dp)
                        .clickable { onBack() }
                )
                Text(
                    text = "课程列表",
                    color = Color.White,
                    fontSize = 17.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.align(Alignment.Center)
                )
            }
            // 标签横滑
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = AppDimens.M)
                    .padding(bottom = AppDimens.S),
                horizontalArrangement = Arrangement.spacedBy(AppDimens.S)
            ) {
                BrowseTagPill("全部", selectedTagIndex == 0) { selectedTagIndex = 0 }
                tags.forEachIndexed { index, tag ->
                    BrowseTagPill(tag.name ?: "", selectedTagIndex == index + 1) {
                        selectedTagIndex = index + 1
                    }
                }
            }
        }

        // 内容区
        if (!initialLoaded && isLoading) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                LoadingView()
            }
        } else if (courses.isEmpty() && !isLoading) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("🎨", fontSize = 40.sp)
                    Spacer(modifier = Modifier.height(AppDimens.M))
                    Text("暂无课程", color = AppColors.Muted, fontSize = 15.sp)
                }
            }
        } else {
            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(top = AppDimens.S, bottom = 100.dp)
            ) {
                items(courses, key = { it.courseId }) { course ->
                    BrowseCourseCard(item = course, onClick = { onCourseClick(course.courseId) })
                }
                if (isLoading) {
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

// MARK: - 标签 pill

@Composable
private fun BrowseTagPill(text: String, selected: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(14.dp))
            .background(if (selected) Color.White else Color.White.copy(alpha = 0.2f))
            .clickable { onClick() }
            .padding(horizontal = 14.dp, vertical = 6.dp)
    ) {
        Text(
            text = text,
            color = if (selected) AppColors.Brand else Color.White,
            fontSize = 13.sp,
            fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal
        )
    }
}

// MARK: - 课程卡片（对齐 iOS SearchCourseCell）

@Composable
private fun BrowseCourseCard(item: CourseItem, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M, vertical = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable { onClick() }
            .padding(AppDimens.M),
        verticalAlignment = Alignment.CenterVertically
    ) {
        AsyncImage(
            model = resolveImageUrl(item.cover),
            contentDescription = item.title,
            modifier = Modifier.size(100.dp, 75.dp).clip(RoundedCornerShape(AppDimens.RadiusIcon)),
            contentScale = ContentScale.Crop
        )
        Spacer(modifier = Modifier.width(AppDimens.M))
        Column(modifier = Modifier.weight(1f)) {
            // 标题（2行）
            Text(
                text = item.title,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = AppColors.Ink,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(4.dp))
            // 标签 pill（tag_id → 名称，取3个）+ 年龄段
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                (item.tags ?: emptyList())
                    .take(3)
                    .map { SearchService.cachedTagName(it) }
                    .filter { it.isNotEmpty() }
                    .forEach { name -> CourseTagPill(name) }
                item.ageRangeText?.let { CourseTagPill(it) }
            }
            Spacer(modifier = Modifier.height(4.dp))
            // 价格行
            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    text = if (item.price > 0) item.priceText else "免费",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.Danger
                )
                item.originalPriceText?.let {
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        it,
                        fontSize = 12.sp,
                        color = AppColors.Muted,
                        textDecoration = TextDecoration.LineThrough
                    )
                }
            }
        }
    }
}

@Composable
private fun CourseTagPill(text: String) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(10.dp))
            .background(AppColors.BrandSoft)
            .padding(horizontal = 8.dp, vertical = 2.dp)
    ) {
        Text(text = text, fontSize = 10.sp, color = AppColors.Brand)
    }
}