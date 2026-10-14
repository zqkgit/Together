package com.together.app.modules.course.ui

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
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
import androidx.compose.material.icons.filled.Business
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
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
import com.together.app.core.model.ConversationItem
import com.together.app.core.model.CourseDetail
import com.together.app.core.model.CourseReviewItem
import com.together.app.modules.course.CourseDetailViewModel
import com.together.app.services.CourseService

/**
 * 课程详情（对齐 iOS CourseDetailViewController / PR #courseDetail）
 * 顶栏 → 封面卡 → 标签/标题/副标题 → 机构卡 → 介绍 → 课时安排 → 家长评价 → 底部报名栏
 */
@Composable
fun CourseDetailScreen(
    courseId: String,
    viewModel: CourseDetailViewModel = viewModel(),
    onBack: () -> Unit = {},
    onEnrollSuccess: (String) -> Unit = {},
    onAllReviews: () -> Unit = {},
    onWriteReview: (String) -> Unit = {},
    onChat: (ConversationItem) -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current

    LaunchedEffect(courseId) {
        viewModel.load(courseId)
        if (viewModel.canEnroll) viewModel.loadChildren()
    }

    if (uiState.loading) {
        Box(modifier = Modifier.fillMaxSize().background(AppColors.Bg), contentAlignment = Alignment.Center) {
            LoadingView()
        }
        return
    }

    val course = uiState.course ?: run {
        Box(modifier = Modifier.fillMaxSize().background(AppColors.Bg), contentAlignment = Alignment.Center) {
            Text(uiState.error ?: "课程不存在", color = AppColors.Muted)
        }
        return
    }

    var showEnrollSheet by remember { mutableStateOf(false) }
    val reviewTotal = uiState.reviewSummary?.total ?: 0

    Box(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = if (viewModel.canEnroll) 90.dp else 16.dp)
        ) {
            // 顶栏
            item { CourseTopBar(onBack = onBack) }
            // 封面卡
            item { CourseCoverCard(course = course) }
            // 信息卡
            item { CourseInfoCard(course = course) }
            // 机构卡
            if (course.studio != null || course.teacher?.realName?.isNotEmpty() == true) {
                item { CourseInstitutionCard(course = course) }
            }
            // 课程介绍
            course.intro?.takeIf { it.isNotBlank() }?.let {
                item { CourseIntroCard(intro = it) }
            }
            // 课时安排
            course.lessonTitles?.let { titles ->
                item { CourseLessonsCard(titles = titles) }
            }
            // 家长评价
            item {
                CourseReviewsHeader(
                    total = reviewTotal,
                    canWrite = viewModel.canEnroll,
                    summary = uiState.reviewSummary,
                    onWriteReview = { onWriteReview(course.title) }
                )
            }
            if (uiState.reviews.isEmpty()) {
                item { ReviewEmptyRow() }
            } else {
                items(uiState.reviews.take(2)) { review ->
                    CourseReviewCard(review = review)
                }
                if (uiState.reviews.size > 2) {
                    item { ReviewViewAllRow(count = uiState.reviews.size, onClick = onAllReviews) }
                }
            }
        }

        // 底部报名栏（仅家长角色）
        if (viewModel.canEnroll) {
            BottomEnrollBar(
                modifier = Modifier.align(Alignment.BottomCenter),
                priceText = course.priceText,
                totalLessons = course.totalLessons,
                chatCreating = uiState.chatCreating,
                onChat = {
                    val uid = course.studio?.userId
                    if (uid.isNullOrEmpty()) {
                        Toast.makeText(context, "该课程暂无工作室信息", Toast.LENGTH_SHORT).show()
                    } else {
                        viewModel.createConversation(uid) { conversation ->
                            if (conversation != null) {
                                onChat(conversation)
                            } else {
                                Toast.makeText(context, uiState.chatError ?: "创建会话失败", Toast.LENGTH_SHORT).show()
                            }
                        }
                    }
                },
                enrolling = uiState.enrolling,
                onEnroll = { showEnrollSheet = true }
            )
        }
    }

    // 报名弹窗
    if (showEnrollSheet) {
        CourseEnrollSheet(
            viewModel = viewModel,
            course = course,
            onDismiss = { showEnrollSheet = false },
            onSuccess = { orderId ->
                showEnrollSheet = false
                onEnrollSuccess(orderId)
            }
        )
    }
}

// MARK: - 顶栏

@Composable
private fun CourseTopBar(onBack: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .height(AppDimens.TopBarHeight)
            .padding(horizontal = AppDimens.S),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .clickable { onBack() },
            contentAlignment = Alignment.Center
        ) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回", tint = AppColors.Ink, modifier = Modifier.size(22.dp))
        }
        Spacer(modifier = Modifier.width(AppDimens.S))
        Text("课程详情", color = AppColors.Ink, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
    }
}

// MARK: - 封面卡

@Composable
private fun CourseCoverCard(course: CourseDetail) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M)
            .padding(bottom = AppDimens.S)
            .aspectRatio(1f / 0.78f)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.SurfaceAlt)
    ) {
        if (!course.cover.isNullOrBlank()) {
            AsyncImage(
                model = resolveImageUrl(course.cover),
                contentDescription = course.title,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop
            )
        }
    }
}

// MARK: - 信息卡

@Composable
private fun CourseInfoCard(course: CourseDetail) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M)
            .padding(bottom = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.L)
    ) {
        // 标签行（年龄 · 班型）
        if (course.tagTexts.isNotEmpty()) {
            Row(horizontalArrangement = Arrangement.spacedBy(AppDimens.S)) {
                course.tagTexts.forEach { text -> InfoTag(text) }
            }
            Spacer(modifier = Modifier.height(AppDimens.S))
        }
        // 标题
        Text(course.title, color = AppColors.Ink, fontSize = 19.sp, fontWeight = FontWeight.Bold, lineHeight = 26.sp)
        Spacer(modifier = Modifier.height(AppDimens.S))
        // 副标题：机构 · 总课时
        if (course.subtitleText.isNotEmpty()) {
            Text(course.subtitleText, color = AppColors.Sub, fontSize = 13.sp)
        }
    }
}

@Composable
private fun InfoTag(text: String) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(10.dp))
            .background(AppColors.BrandSoft)
            .padding(horizontal = 8.dp, vertical = 3.dp)
    ) {
        Text(text, color = AppColors.Brand, fontSize = 11.sp)
    }
}

// MARK: - 机构卡

@Composable
private fun CourseInstitutionCard(course: CourseDetail) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M)
            .padding(bottom = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.M)
    ) {
        course.studio?.let { studio ->
            val parts = mutableListOf<String>()
            course.rating?.takeIf { it > 0 }?.let { parts.add("评分 ${String.format("%.1f", it)}") }
            course.sales?.takeIf { it > 0 }?.let { parts.add("$it 人学过") }
            studio.address?.takeIf { it.isNotEmpty() }?.let { parts.add(it) }
            InstitutionRow(
                icon = Icons.Default.Business,
                title = studio.name ?: "未知机构",
                subtitle = parts.takeIf { it.isNotEmpty() }?.joinToString(" · ")
            )
        }
        course.teacher?.realName?.takeIf { it.isNotEmpty() }?.let { name ->
            if (course.studio != null) Spacer(modifier = Modifier.height(AppDimens.M))
            val subtitle = course.teacher?.intro?.takeIf { it.isNotEmpty() }
                ?: course.teacher?.rating?.takeIf { it > 0 }?.let { "评分 ${String.format("%.1f", it)}" }
            InstitutionRow(
                icon = Icons.Default.Person,
                title = name,
                subtitle = subtitle
            )
        }
    }
}

@Composable
private fun InstitutionRow(icon: ImageVector, title: String, subtitle: String?) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = AppColors.Brand, modifier = Modifier.size(20.dp))
        Spacer(modifier = Modifier.width(AppDimens.M))
        Text(
            title,
            color = AppColors.Ink,
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        if (subtitle != null) {
            Spacer(modifier = Modifier.width(AppDimens.M))
            Text(
                subtitle,
                color = AppColors.Muted,
                fontSize = 12.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.End,
                modifier = Modifier.weight(1f)
            )
        }
    }
}
// MARK: - 课程介绍

@Composable
private fun CourseIntroCard(intro: String) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M)
            .padding(bottom = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.L)
    ) {
        Text("课程介绍", color = AppColors.Ink, fontSize = 15.sp, fontWeight = FontWeight.Bold)
        Spacer(modifier = Modifier.height(AppDimens.S))
        Text(intro, color = AppColors.Sub, fontSize = 14.sp, lineHeight = 22.sp)
    }
}

// MARK: - 课时安排

@Composable
private fun CourseLessonsCard(titles: List<String>) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M)
            .padding(bottom = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.L)
    ) {
        Text("课时安排", color = AppColors.Ink, fontSize = 15.sp, fontWeight = FontWeight.Bold)
        Spacer(modifier = Modifier.height(AppDimens.S))
        titles.forEach { title ->
            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                verticalAlignment = Alignment.Top
            ) {
                Box(
                    modifier = Modifier
                        .padding(top = 7.dp)
                        .size(6.dp)
                        .clip(CircleShape)
                        .background(AppColors.Brand)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(title, color = AppColors.Sub, fontSize = 14.sp, lineHeight = 20.sp)
            }
        }
    }
}

// MARK: - 家长评价

@Composable
private fun CourseReviewsHeader(
    total: Int,
    canWrite: Boolean,
    summary: CourseService.CourseReviewSummary?,
    onWriteReview: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M)
            .padding(top = AppDimens.S, bottom = AppDimens.S)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("家长评价", color = AppColors.Ink, fontSize = 16.sp, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.width(AppDimens.S))
            Text("$total 条", color = AppColors.Muted, fontSize = 12.sp)
            Spacer(modifier = Modifier.weight(1f))
            if (canWrite) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .background(AppColors.BrandSoft)
                        .clickable { onWriteReview() }
                        .padding(horizontal = 10.dp, vertical = 4.dp)
                ) {
                    Text("写评价", color = AppColors.Brand, fontSize = 13.sp)
                }
            }
        }
        // 评分分布条
        if (total > 0 && summary != null) {
            Spacer(modifier = Modifier.height(AppDimens.S))
            for (star in 5 downTo 1) {
                DistributionBar(star = star, count = summary.count(star), total = total)
                if (star > 1) Spacer(modifier = Modifier.height(4.dp))
            }
        }
    }
}

@Composable
private fun DistributionBar(star: Int, count: Int, total: Int) {
    Row(
        modifier = Modifier.fillMaxWidth().height(14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text("${star}★", color = AppColors.Muted, fontSize = 10.sp, modifier = Modifier.width(26.dp))
        Spacer(modifier = Modifier.width(4.dp))
        Box(
            modifier = Modifier
                .weight(1f)
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(AppColors.SurfaceAlt)
        ) {
            val ratio = if (total > 0) count.toFloat() / total else 0f
            Box(
                modifier = Modifier
                    .fillMaxWidth(ratio)
                    .height(6.dp)
                    .clip(RoundedCornerShape(3.dp))
                    .background(AppColors.Clay)
            )
        }
        Spacer(modifier = Modifier.width(4.dp))
        Text("$count", color = AppColors.Muted, fontSize = 10.sp, modifier = Modifier.width(24.dp))
    }
}

@Composable
private fun CourseReviewCard(review: CourseReviewItem) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M)
            .padding(bottom = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.L)
    ) {
        // 头像 + 昵称 + 时间
        Row(verticalAlignment = Alignment.CenterVertically) {
            TogetherAvatar(url = review.avatar, name = review.authorName, size = 32.dp)
            Spacer(modifier = Modifier.width(AppDimens.S))
            Column {
                Text(review.authorName, color = AppColors.Ink, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                Text(review.timeText, color = AppColors.Muted, fontSize = 11.sp)
            }
        }
        Spacer(modifier = Modifier.height(AppDimens.S))
        if (review.content.isNotEmpty()) {
            Text(review.content, color = AppColors.Ink, fontSize = 14.sp, lineHeight = 22.sp)
        }
        // 工作室回复
        review.replyContent?.takeIf { it.isNotEmpty() }?.let { reply ->
            Spacer(modifier = Modifier.height(AppDimens.S))
            ReviewReplyRow(tag = "工作室", tagColor = AppColors.Info, tintColor = AppColors.InfoTint, text = reply)
        }
        // 老师回复
        review.teacherReplyContent?.takeIf { it.isNotEmpty() }?.let { reply ->
            Spacer(modifier = Modifier.height(AppDimens.S))
            ReviewReplyRow(tag = "老师", tagColor = AppColors.Violet, tintColor = AppColors.VioletTint, text = reply)
        }
    }
}

/** 评价回复条（工作室蓝 / 老师紫） */
@Composable
private fun ReviewReplyRow(tag: String, tagColor: Color, tintColor: Color, text: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(6.dp))
            .background(tintColor)
            .padding(horizontal = 8.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(tag, color = tagColor, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.width(34.dp))
        Spacer(modifier = Modifier.width(6.dp))
        Text(text, color = AppColors.Sub, fontSize = 12.sp, lineHeight = 18.sp, modifier = Modifier.weight(1f))
    }
}

@Composable
private fun ReviewEmptyRow() {
    Box(
        modifier = Modifier.fillMaxWidth().padding(vertical = AppDimens.Xl),
        contentAlignment = Alignment.Center
    ) {
        Text("暂无评价，快来写下第一条吧", color = AppColors.Muted, fontSize = 14.sp)
    }
}

@Composable
private fun ReviewViewAllRow(count: Int, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = AppDimens.M)
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Text("查看全部 $count 条评价 ›", color = AppColors.Sub, fontSize = 14.sp)
    }
}

// MARK: - 底部报名栏

@Composable
private fun BottomEnrollBar(
    modifier: Modifier = Modifier,
    priceText: String,
    totalLessons: Int?,
    chatCreating: Boolean,
    onChat: () -> Unit,
    enrolling: Boolean,
    onEnroll: () -> Unit
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .shadow(8.dp, spotColor = Color.Black.copy(alpha = 0.06f))
            .background(AppColors.Surface)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = AppDimens.M, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // 价格（¥xx/N节）
            val priceDisplay = if (totalLessons != null && totalLessons > 0) "$priceText/${totalLessons}节" else priceText
            Text(priceDisplay, color = AppColors.Clay, fontSize = 18.sp, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.weight(1f))
            // 咨询工作室（线框风格）
            Box(
                modifier = Modifier
                    .size(width = 90.dp, height = 46.dp)
                    .clip(RoundedCornerShape(23.dp))
                    .border(1.dp, AppColors.Brand, RoundedCornerShape(23.dp))
                    .clickable { onChat() },
                contentAlignment = Alignment.Center
            ) {
                if (chatCreating) {
                    CircularProgressIndicator(color = AppColors.Brand, modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                } else {
                    Text("咨询工作室", color = AppColors.Brand, fontSize = 14.sp)
                }
            }
            Spacer(modifier = Modifier.width(10.dp))
            // 我要报名
            Box(
                modifier = Modifier
                    .size(width = 120.dp, height = 46.dp)
                    .clip(RoundedCornerShape(23.dp))
                    .background(AppColors.Brand)
                    .clickable { onEnroll() },
                contentAlignment = Alignment.Center
            ) {
                if (enrolling) {
                    CircularProgressIndicator(color = Color.White, modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                } else {
                    Text("我要报名", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}