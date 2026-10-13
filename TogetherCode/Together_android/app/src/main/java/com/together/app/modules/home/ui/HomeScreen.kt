package com.together.app.modules.home.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.core.component.LoadingView
import com.together.app.core.component.TogetherAvatar
import com.together.app.core.component.resolveImageUrl
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.ChildItem
import com.together.app.core.model.CourseItem
import com.together.app.core.model.PostItem
import com.together.app.core.model.StudioItem
import com.together.app.modules.home.HomeViewModel
import java.time.LocalTime

/**
 * 首页（对齐 iOS HomeViewController / PR 设计图 #parentHome）
 * 分区：顶部渐变(搜索+Hero) / 公告 / 为你推荐 / 附近热门工作室 / 老师动态
 */
@Composable
fun HomeScreen(
    viewModel: HomeViewModel = viewModel(),
    onChildClick: (ChildItem) -> Unit = {},
    onAddChild: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()

    if (uiState.loading && uiState.data.courses.isEmpty()) {
        LoadingView()
        return
    }

    val data = uiState.data

    Box(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = 80.dp)
        ) {
            // Hero 区（渐变背景 + 问候 + 孩子）
            item {
                HomeHeroSection(
                    nickname = uiState.nickname,
                    children = data.children,
                    onChildClick = onChildClick,
                    onAddChild = onAddChild
                )
            }

            // 公告条
            if (data.announcements.isNotEmpty()) {
                item {
                    HomeNoticeBar(title = data.announcements.first().title)
                }
            }

            // 为你推荐
            if (data.courses.isNotEmpty()) {
                item {
                    HomeSectionTitle(title = "为你推荐", moreText = "全部", onMore = { /* TODO: 课程列表 */ })
                }
                item {
                    HomeCourseRow(courses = data.courses)
                }
            }

            // 附近热门工作室
            if (data.studios.isNotEmpty()) {
                item {
                    HomeSectionTitle(title = "附近热门工作室", moreText = "更多", onMore = { /* TODO: 工作室列表 */ })
                }
                items(data.studios.size) { index ->
                    HomeStudioRow(item = data.studios[index])
                }
            }

            // 老师动态
            if (data.posts.isNotEmpty()) {
                item {
                    HomeSectionTitle(title = "老师动态", moreText = "更多", onMore = { /* TODO: 切到广场 */ })
                }
                items(data.posts.size) { index ->
                    HomePostCard(item = data.posts[index])
                }
            }
        }
    }
}

// MARK: - Hero 区

@Composable
private fun HomeHeroSection(
    nickname: String,
    children: List<ChildItem>,
    onChildClick: (ChildItem) -> Unit = {},
    onAddChild: () -> Unit
) {
    // 渐变背景：Brand → BrandLight → Bg
    val gradient = Brush.verticalGradient(
        colors = listOf(AppColors.Brand, AppColors.BrandLight, AppColors.Bg),
        startY = 0f,
        endY = 800f
    )

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(gradient)
            .padding(horizontal = AppDimens.L)
            .padding(top = 48.dp, bottom = AppDimens.L)
    ) {
        // 搜索栏
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(AppDimens.RadiusInput))
                .background(Color.White.copy(alpha = 0.15f))
                .clickable { /* TODO: 跳搜索页 */ }
                .padding(horizontal = AppDimens.M, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(Icons.Default.Search, contentDescription = null, tint = Color.White.copy(alpha = 0.7f), modifier = Modifier.size(16.dp))
            Spacer(modifier = Modifier.width(AppDimens.S))
            Text("搜索课程、工作室、作品", color = Color.White.copy(alpha = 0.6f), fontSize = 14.sp)
        }

        Spacer(modifier = Modifier.height(AppDimens.L))

        // 问候语
        val name = nickname.ifEmpty { "家长" }
        val greeting = when (LocalTime.now().hour) {
            in 5..11 -> "早上好"
            in 12..17 -> "下午好"
            else -> "晚上好"
        }
        Text(
            text = "$greeting，$name",
            color = Color.White,
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold
        )
        Spacer(modifier = Modifier.height(6.dp))
        Text(
            text = "让每一次创作，都被看见",
            color = Color.White.copy(alpha = 0.75f),
            fontSize = 13.sp
        )

        Spacer(modifier = Modifier.height(AppDimens.M))

        // 孩子卡片横滑 / 无孩子提示
        if (children.isEmpty()) {
            // 无孩子提示卡
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(AppDimens.RadiusCard))
                    .background(Color.White.copy(alpha = 0.12f))
                    .clickable { onAddChild() }
                    .padding(horizontal = AppDimens.L, vertical = 16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "添加孩子，开始记录成长",
                    color = Color.White.copy(alpha = 0.8f),
                    fontSize = 14.sp,
                    modifier = Modifier.weight(1f)
                )
                Icon(Icons.Default.ChevronRight, contentDescription = null, tint = Color.White.copy(alpha = 0.6f), modifier = Modifier.size(16.dp))
            }
        } else {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(AppDimens.M)
            ) {
                children.forEach { child ->
                    ChildProgressCard(item = child, onClick = { onChildClick(child) })
                }
                // 管理孩子按钮
                Column(
                    modifier = Modifier
                        .width(100.dp)
                        .clip(RoundedCornerShape(AppDimens.RadiusCard))
                        .background(Color.White.copy(alpha = 0.18f))
                        .clickable { onAddChild() }
                        .padding(vertical = AppDimens.M),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Icon(Icons.Default.Add, contentDescription = null, tint = Color.White, modifier = Modifier.size(20.dp))
                    Spacer(modifier = Modifier.height(4.dp))
                    Text("管理孩子", color = Color.White.copy(alpha = 0.8f), fontSize = 11.sp)
                }
            }
        }
    }
}

// MARK: - 孩子进度卡

@Composable
private fun ChildProgressCard(item: ChildItem, onClick: () -> Unit = {}) {
    val balance = item.mainBalance
    Column(
        modifier = Modifier
            .width(148.dp)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(Color.White.copy(alpha = 0.18f))
            .clickable { onClick() }
            .padding(AppDimens.M)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TogetherAvatar(url = item.avatar, name = item.nickname, size = 32.dp)
            Spacer(modifier = Modifier.width(AppDimens.S))
            Column {
                Text(item.nickname, color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
                item.ageText?.let { Text(it, color = Color.White.copy(alpha = 0.7f), fontSize = 11.sp) }
            }
        }
        Spacer(modifier = Modifier.height(AppDimens.S))
        if (balance != null) {
            Text(balance.courseText, color = Color.White.copy(alpha = 0.8f), fontSize = 11.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Spacer(modifier = Modifier.height(4.dp))
            // 进度条
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(Color.White.copy(alpha = 0.25f))
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(balance.progressPercent / 100f)
                        .height(4.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(Color.White)
                )
            }
            Spacer(modifier = Modifier.height(4.dp))
            Text("剩${balance.remainingLessons}节", color = Color.White.copy(alpha = 0.7f), fontSize = 10.sp)
        } else {
            Text("未报名课程", color = Color.White.copy(alpha = 0.6f), fontSize = 11.sp)
        }
    }
}

// MARK: - 公告条

@Composable
private fun HomeNoticeBar(title: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L)
            .padding(top = AppDimens.L)
            .clip(RoundedCornerShape(AppDimens.RadiusInput))
            .background(AppColors.SurfaceAlt)
            .clickable { }
            .padding(horizontal = AppDimens.M, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text("📢", fontSize = 14.sp)
        Spacer(modifier = Modifier.width(AppDimens.S))
        Text(
            text = title,
            color = AppColors.Ink,
            fontSize = 13.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f)
        )
        Icon(Icons.Default.ChevronRight, contentDescription = null, tint = AppColors.Muted, modifier = Modifier.size(14.dp))
    }
}

// MARK: - 区块标题

@Composable
private fun HomeSectionTitle(title: String, moreText: String, onMore: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L)
            .padding(top = AppDimens.Xl, bottom = AppDimens.S),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title,
            color = AppColors.Ink,
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.weight(1f)
        )
        Text(
            text = moreText,
            color = AppColors.Muted,
            fontSize = 13.sp,
            modifier = Modifier.clickable { onMore() }
        )
    }
}

// MARK: - 课程横滑卡

@Composable
private fun HomeCourseRow(courses: List<CourseItem>) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = AppDimens.L),
        horizontalArrangement = Arrangement.spacedBy(AppDimens.M)
    ) {
        courses.forEach { course ->
            CourseCard(item = course)
        }
    }
}

@Composable
private fun CourseCard(item: CourseItem) {
    Column(
        modifier = Modifier
            .width(148.dp)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable { }
    ) {
        // 封面
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(110.dp)
                .background(AppColors.SurfaceAlt)
        ) {
            if (!item.cover.isNullOrBlank()) {
                AsyncImage(
                    model = resolveImageUrl(item.cover),
                    contentDescription = item.title,
                    modifier = Modifier.fillMaxSize()
                )
            }
            item.ageRangeText?.let { age ->
                Box(
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(6.dp)
                        .clip(RoundedCornerShape(AppDimens.RadiusTag))
                        .background(AppColors.BrandSoft)
                        .padding(horizontal = 6.dp, vertical = 2.dp)
                ) {
                    Text(age, color = AppColors.Brand, fontSize = 10.sp)
                }
            }
        }
        // 信息
        Column(modifier = Modifier.padding(AppDimens.M)) {
            Text(
                text = item.title,
                color = AppColors.Ink,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = item.studioName,
                color = AppColors.Muted,
                fontSize = 11.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(6.dp))
            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    text = item.priceText,
                    color = AppColors.Clay,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = item.ratingText,
                    color = AppColors.Warn,
                    fontSize = 11.sp
                )
            }
        }
    }
}

// MARK: - 工作室行

@Composable
private fun HomeStudioRow(item: StudioItem) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L)
            .padding(top = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable { }
            .padding(AppDimens.M),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // 封面
        Box(
            modifier = Modifier
                .size(52.dp)
                .clip(RoundedCornerShape(AppDimens.RadiusCard))
                .background(AppColors.SurfaceAlt)
        ) {
            if (!item.cover.isNullOrBlank()) {
                AsyncImage(
                    model = resolveImageUrl(item.cover),
                    contentDescription = item.name,
                    modifier = Modifier.fillMaxSize()
                )
            }
        }
        Spacer(modifier = Modifier.width(AppDimens.M))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = item.name,
                color = AppColors.Ink,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = item.rowMetaText,
                color = AppColors.Muted,
                fontSize = 12.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        Spacer(modifier = Modifier.width(AppDimens.S))
        // 评分
        Column(horizontalAlignment = Alignment.End) {
            Text(item.ratingText, color = AppColors.Warn, fontSize = 14.sp, fontWeight = FontWeight.Bold)
            Text("${item.courseCount}门课", color = AppColors.Muted, fontSize = 10.sp)
        }
    }
}

// MARK: - 老师动态帖子卡

@Composable
private fun HomePostCard(item: PostItem) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L)
            .padding(top = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable { }
            .padding(AppDimens.M)
    ) {
        // 作者行
        Row(verticalAlignment = Alignment.CenterVertically) {
            TogetherAvatar(url = item.authorAvatar, name = item.authorName, size = 32.dp)
            Spacer(modifier = Modifier.width(AppDimens.S))
            Column(modifier = Modifier.weight(1f)) {
                Text(item.authorName, color = AppColors.Ink, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
                Text("${item.roleText} · ${item.timeText}", color = AppColors.Muted, fontSize = 11.sp)
            }
            item.safeTopic?.let { topic ->
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(AppDimens.RadiusTag))
                        .background(AppColors.BrandSoft)
                        .padding(horizontal = 8.dp, vertical = 3.dp)
                ) {
                    Text("#$topic", color = AppColors.Brand, fontSize = 11.sp)
                }
            }
        }
        Spacer(modifier = Modifier.height(AppDimens.S))
        // 正文
        if (item.bodyText.isNotEmpty()) {
            Text(
                text = item.bodyText,
                color = AppColors.Ink,
                fontSize = 14.sp,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis
            )
        }
        // 图片
        if (item.imageList.isNotEmpty()) {
            Spacer(modifier = Modifier.height(AppDimens.S))
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                item.imageList.take(3).forEach { img ->
                    AsyncImage(
                        model = resolveImageUrl(img),
                        contentDescription = null,
                        modifier = Modifier
                            .weight(1f)
                            .height(80.dp)
                            .clip(RoundedCornerShape(AppDimens.RadiusTag))
                    )
                }
            }
        }
        // 互动行
        Spacer(modifier = Modifier.height(AppDimens.S))
        Row {
            Text("❤️ ${item.likeText}", color = AppColors.Muted, fontSize = 12.sp)
            Spacer(modifier = Modifier.width(AppDimens.L))
            Text("💬 ${item.commentText}", color = AppColors.Muted, fontSize = 12.sp)
        }
    }
}