package com.together.app.modules.child.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.core.component.EmptyStateView
import com.together.app.core.component.LoadingView
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.ChildItem
import com.together.app.modules.child.ChildViewModel
import com.together.app.services.ChildService.ChildGrowthEvent
import com.together.app.services.ChildService.ChildWorkItem

/**
 * 孩子主页（对齐 iOS ChildHomeViewController / PR 图2/3/4）
 * 深绿渐变头部（头像+昵称+统计）+ 课时明细入口 + 作品/课程/动态三 tab
 */
@Composable
fun ChildHomeScreen(
    child: ChildItem,
    viewModel: ChildViewModel = viewModel(),
    onBack: () -> Unit = {},
    onBalanceDetail: (childId: String, nickname: String) -> Unit = { _, _ -> },
    onWorkClick: (postId: String) -> Unit = {},
    onCourseClick: (childId: String, courseId: String, courseTitle: String) -> Unit = { _, _, _ -> }
) {
    val homeState by viewModel.homeState.collectAsState()

    LaunchedEffect(child.childId) {
        viewModel.loadChildHome(child.childId)
    }

    var selectedTab by remember { mutableIntStateOf(0) }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        // 深绿头部
        ChildHeader(
            child = child,
            worksCount = homeState.works.size,
            onBack = onBack
        )

        // 课时明细入口
        BalanceEntryCard(
            onClick = { onBalanceDetail(child.childId, child.nickname) }
        )

        // 分段
        ChildSegmentControl(
            titles = listOf("作品", "课程", "动态"),
            selectedIndex = selectedTab,
            onSelect = { selectedTab = it }
        )

        // 内容区
        when (selectedTab) {
            0 -> WorksTab(
                works = homeState.works,
                loading = homeState.loadingWorks,
                onWorkClick = onWorkClick
            )
            1 -> CoursesTab(
                courses = viewModel.aggregateCourses(child),
                childId = child.childId,
                onCourseClick = onCourseClick
            )
            2 -> DynamicsTab(
                dynamics = homeState.dynamics,
                loading = homeState.loadingGrowth
            )
        }
    }
}

// MARK: - 深绿头部

@Composable
private fun ChildHeader(
    child: ChildItem,
    worksCount: Int,
    onBack: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                Brush.linearGradient(
                    colors = listOf(AppColors.Brand, AppColors.BrandDark),
                    start = androidx.compose.ui.geometry.Offset(0f, 0f),
                    end = androidx.compose.ui.geometry.Offset(Float.POSITIVE_INFINITY, Float.POSITIVE_INFINITY * 0.8f)
                )
            )
    ) {
        // 装饰圆
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(top = 8.dp, end = 30.dp)
                .size(100.dp)
                .clip(CircleShape)
                .background(AppColors.Wood.copy(alpha = 0.15f))
        )

        Column(
            modifier = Modifier
                .statusBarsPadding()
                .padding(horizontal = AppDimens.L)
                .padding(bottom = AppDimens.L)
        ) {
            // 返回按钮（半透明黑底白箭头）
            Box(
                modifier = Modifier
                    .padding(top = AppDimens.S)
                    .size(32.dp)
                    .clip(CircleShape)
                    .background(Color.Black.copy(alpha = 0.28f))
                    .clickable { onBack() },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "返回",
                    tint = Color.White,
                    modifier = Modifier.size(20.dp)
                )
            }

            Spacer(modifier = Modifier.height(AppDimens.S))

            // 头像 + 昵称 + 信息
            Row(verticalAlignment = Alignment.CenterVertically) {
                // 头像：白底圆，emoji/URL/首字
                Box(
                    modifier = Modifier
                        .size(56.dp)
                        .clip(CircleShape)
                        .background(Color.White),
                    contentAlignment = Alignment.Center
                ) {
                    val avatar = child.avatar
                    if (!avatar.isNullOrBlank() && avatar.startsWith("http")) {
                        AsyncImage(
                            model = avatar,
                            contentDescription = child.nickname,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier.size(56.dp).clip(CircleShape)
                        )
                    } else if (!avatar.isNullOrBlank()) {
                        Text(text = avatar, fontSize = 28.sp)
                    } else {
                        Text(
                            text = child.nickname.firstOrNull()?.toString() ?: "?",
                            fontSize = 24.sp,
                            fontWeight = FontWeight.Bold,
                            color = AppColors.Brand
                        )
                    }
                }
                Spacer(modifier = Modifier.width(AppDimens.M))
                Column {
                    Text(
                        text = child.nickname,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                    Spacer(modifier = Modifier.height(3.dp))
                    val gender = when (child.gender) { 2 -> "女"; 1 -> "男"; else -> "" }
                    val courseName = child.balances?.firstNotNullOfOrNull { it.courseTitle } ?: ""
                    val info = listOf(gender, child.ageText ?: "", courseName)
                        .filter { it.isNotEmpty() }
                        .joinToString("·")
                    Text(
                        text = info,
                        fontSize = 12.sp,
                        color = Color.White.copy(alpha = 0.8f)
                    )
                }
            }

            Spacer(modifier = Modifier.height(AppDimens.L))

            // 统计卡（半透明白底）
            val balances = child.balances ?: emptyList()
            val courseCount = balances.mapNotNull { it.courseId }.distinct().size
            val totalLessons = balances.sumOf { it.totalLessons }
            val consumedLessons = balances.sumOf { it.consumedLessons }
            val attendance = if (totalLessons > 0) "${consumedLessons * 100 / totalLessons}%" else "—"

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(AppDimens.RadiusCard))
                    .background(Color.White.copy(alpha = 0.13f))
                    .padding(vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                StatColumn("在学课程", courseCount.toString(), Modifier.weight(1f))
                StatDivider()
                StatColumn("作品数", worksCount.toString(), Modifier.weight(1f))
                StatDivider()
                StatColumn("出勤率", attendance, Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun StatColumn(label: String, value: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(text = value, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = Color.White)
        Spacer(modifier = Modifier.height(4.dp))
        Text(text = label, fontSize = 11.sp, color = Color.White.copy(alpha = 0.75f))
    }
}

@Composable
private fun StatDivider() {
    Box(
        modifier = Modifier
            .width(0.5.dp)
            .height(28.dp)
            .background(Color.White.copy(alpha = 0.16f))
    )
}

// MARK: - 课时明细入口卡

@Composable
private fun BalanceEntryCard(onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L, vertical = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable { onClick() }
            .padding(horizontal = AppDimens.CardInner, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text = "📋", fontSize = 16.sp)
        Spacer(modifier = Modifier.width(AppDimens.S))
        Text(
            text = "课时明细",
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.Ink
        )
        Spacer(modifier = Modifier.weight(1f))
        Text(
            text = "查看课时余额与消课记录",
            fontSize = 12.sp,
            color = AppColors.Muted
        )
        Icon(
            Icons.Filled.ChevronRight,
            contentDescription = null,
            tint = AppColors.Muted,
            modifier = Modifier.size(18.dp)
        )
    }
}

// MARK: - 分段控件

@Composable
private fun ChildSegmentControl(
    titles: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L, vertical = AppDimens.M)
            .height(36.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(AppColors.SurfaceAlt)
            .padding(3.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        titles.forEachIndexed { index, title ->
            val selected = index == selectedIndex
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .height(30.dp)
                    .clip(RoundedCornerShape(15.dp))
                    .background(if (selected) AppColors.Brand else Color.Transparent)
                    .clickable { onSelect(index) },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = title,
                    fontSize = 13.sp,
                    fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (selected) Color.White else AppColors.Ink
                )
            }
        }
    }
}

// MARK: - 作品 Tab（2 列网格）

@Composable
private fun WorksTab(
    works: List<ChildWorkItem>,
    loading: Boolean,
    onWorkClick: (String) -> Unit
) {
    if (loading) {
        LoadingView()
        return
    }
    if (works.isEmpty()) {
        EmptyStateView(message = "还没有作品\n老师的课堂作品会自动归入这里")
        return
    }
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(
            start = AppDimens.L, end = AppDimens.L, top = AppDimens.M, bottom = AppDimens.Xl
        ),
        verticalArrangement = Arrangement.spacedBy(AppDimens.M)
    ) {
        // 两两一行
        items(works.chunked(2)) { rowWorks ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(AppDimens.M)
            ) {
                rowWorks.forEach { work ->
                    Box(modifier = Modifier.weight(1f)) {
                        WorkCard(work = work, onClick = {
                            val postId = work.postId
                            if (!postId.isNullOrBlank()) {
                                onWorkClick(postId)
                            }
                        })
                    }
                }
                // 奇数个时补占位
                if (rowWorks.size == 1) {
                    Spacer(modifier = Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun WorkCard(work: ChildWorkItem, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable { onClick() }
    ) {
        val imageUrl = work.images?.firstOrNull()
        if (!imageUrl.isNullOrBlank()) {
            AsyncImage(
                model = imageUrl,
                contentDescription = "作品",
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(160.dp)
                    .clip(RoundedCornerShape(topStart = AppDimens.RadiusCard, topEnd = AppDimens.RadiusCard))
            )
        } else {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(160.dp)
                    .background(AppColors.SurfaceAlt)
            )
        }
        Text(
            text = if (!work.content.isNullOrBlank()) work.content else (work.courseTitle ?: "作品"),
            fontSize = 12.sp,
            color = AppColors.Ink,
            maxLines = 1,
            modifier = Modifier.padding(AppDimens.S)
        )
    }
}

// MARK: - 课程 Tab（聚合卡）

@Composable
private fun CoursesTab(
    courses: List<ChildViewModel.ChildCourseAggregate>,
    childId: String,
    onCourseClick: (childId: String, courseId: String, courseTitle: String) -> Unit
) {
    if (courses.isEmpty()) {
        EmptyStateView(message = "暂无在学课程")
        return
    }
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(
            start = AppDimens.M, end = AppDimens.M, top = AppDimens.S, bottom = AppDimens.Xl
        ),
        verticalArrangement = Arrangement.spacedBy(AppDimens.S)
    ) {
        items(courses, key = { it.courseId }) { course ->
            CourseCard(
                course = course,
                onClick = {
                    if (!course.isRefunded) {
                        onCourseClick(childId, course.courseId, course.courseTitle)
                    }
                }
            )
        }
    }
}

@Composable
private fun CourseCard(
    course: ChildViewModel.ChildCourseAggregate,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable(enabled = !course.isRefunded) { onClick() }
            .padding(AppDimens.CardInner)
    ) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = course.courseTitle,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = if (course.isRefunded) AppColors.Sub else AppColors.Ink,
                    modifier = Modifier.weight(1f)
                )
                if (course.isRefunded) {
                    Text(
                        text = "已退款",
                        fontSize = 11.sp,
                        color = Color.White,
                        modifier = Modifier
                            .clip(RoundedCornerShape(4.dp))
                            .background(AppColors.Sub)
                            .padding(horizontal = 8.dp, vertical = 2.dp)
                    )
                }
            }
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = course.studioName ?: "艺术工坊",
                fontSize = 12.sp,
                color = AppColors.Muted
            )
            Spacer(modifier = Modifier.height(AppDimens.S))
            // 进度条 + 进度文字
            Row(verticalAlignment = Alignment.CenterVertically) {
                val total = maxOf(course.total, 1)
                val consumed = minOf(course.consumed, total)
                val ratio = consumed.toFloat() / total
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(6.dp)
                        .clip(RoundedCornerShape(3.dp))
                        .background(Color(0xFFE8E8E8))
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(ratio)
                            .height(6.dp)
                            .clip(RoundedCornerShape(3.dp))
                            .background(if (course.isRefunded) AppColors.Sub else AppColors.Brand)
                    )
                }
                Spacer(modifier = Modifier.width(AppDimens.S))
                Text(
                    text = "已上${consumed}/${course.total}节",
                    fontSize = 11.sp,
                    color = AppColors.Muted
                )
            }
        }
    }
}

// MARK: - 动态 Tab（成长时间线）

@Composable
private fun DynamicsTab(
    dynamics: List<ChildGrowthEvent>,
    loading: Boolean
) {
    if (loading) {
        LoadingView()
        return
    }
    if (dynamics.isEmpty()) {
        EmptyStateView(message = "还没有动态\n上课消课记录会展示在这里")
        return
    }
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(
            start = AppDimens.M, end = AppDimens.M, top = AppDimens.S, bottom = AppDimens.Xl
        ),
        verticalArrangement = Arrangement.spacedBy(AppDimens.S)
    ) {
        items(dynamics, key = { it.eventId ?: it.occurredAt ?: it.hashCode().toString() }) { event ->
            DynamicCard(event = event)
        }
    }
}

@Composable
private fun DynamicCard(event: ChildGrowthEvent) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.CardInner)
    ) {
        Column {
            // 头像 + 来源 + 事件图标 + 时间
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(AppColors.WoodSoft),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = event.sourceName.firstOrNull()?.toString() ?: "?",
                        fontSize = 14.sp,
                        color = AppColors.Wood
                    )
                }
                Spacer(modifier = Modifier.width(AppDimens.S))
                Text(
                    text = event.sourceName,
                    fontSize = 14.sp,
                    color = AppColors.Ink
                )
                Text(
                    text = eventTypeIcon(event.eventType),
                    fontSize = 13.sp,
                    modifier = Modifier.padding(start = 6.dp)
                )
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = formatGrowthTime(event.occurredAt),
                    fontSize = 11.sp,
                    color = AppColors.Muted
                )
            }
            Spacer(modifier = Modifier.height(AppDimens.S))
            Text(
                text = event.bodyText,
                fontSize = 14.sp,
                color = AppColors.Ink,
                maxLines = 5
            )
            // 关联课程标签
            val courseTitle = event.courseTitle
            if (!courseTitle.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(AppDimens.S))
                Text(
                    text = "关联课程·$courseTitle",
                    fontSize = 10.sp,
                    color = AppColors.Brand,
                    modifier = Modifier
                        .clip(RoundedCornerShape(11.dp))
                        .background(AppColors.BrandSoft)
                        .padding(horizontal = 8.dp, vertical = 3.dp)
                )
            }
        }
    }
}

// MARK: - 辅助

/** 事件类型 → emoji 图标 */
private fun eventTypeIcon(type: String?): String = when (type) {
    "consume" -> "📖"
    "refund" -> "💰"
    "post" -> "🎨"
    "enroll" -> "✨"
    else -> ""
}

/** 成长动态时间格式化：ISO(Z) / 本地格式 → yyyy-MM-dd HH:mm */
private fun formatGrowthTime(time: String?): String {
    if (time.isNullOrBlank()) return ""
    if (time.length < 16) return time
    return try {
        if (time.endsWith("Z")) {
            // ISO8601 → 本地
            val instant = java.time.Instant.parse(time)
            val formatter = java.time.format.DateTimeFormatter
                .ofPattern("yyyy-MM-dd HH:mm")
                .withZone(java.time.ZoneId.systemDefault())
            formatter.format(instant)
        } else {
            // 本地格式：取前 16 位 (yyyy-MM-dd HH:mm)
            time.take(16)
        }
    } catch (_: Exception) {
        time.take(16)
    }
}