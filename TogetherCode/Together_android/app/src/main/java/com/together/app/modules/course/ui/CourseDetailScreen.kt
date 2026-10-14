package com.together.app.modules.course.ui

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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
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
import com.together.app.core.model.CourseClassItem
import com.together.app.core.model.CourseDetail
import com.together.app.core.model.CourseReviewItem
import com.together.app.core.model.fenToYuanText
import com.together.app.modules.course.CourseDetailViewModel

/**
 * 课程详情（对齐 iOS CourseDetailViewController / PR #courseDetail）
 * 封面 → 标签/标题/副标题 → 机构卡 → 介绍 → 班级 → 家长评价 → 底部报名栏
 */
@Composable
fun CourseDetailScreen(
    courseId: String,
    viewModel: CourseDetailViewModel = viewModel(),
    onBack: () -> Unit = {},
    onEnrollSuccess: (String) -> Unit = {},
    onAllReviews: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()

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

    // 报名弹窗
    var showEnrollSheet by remember { mutableStateOf(false) }

    Box(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = if (viewModel.canEnroll) 80.dp else 16.dp)
        ) {
            // 封面
            item { CourseCoverSection(course = course, onBack = onBack) }
            // 信息
            item { CourseInfoSection(course = course) }
            // 机构卡
            item { CourseStudioCard(course = course) }
            // 介绍
            item { CourseIntroSection(course = course) }
            // 班级列表
            if (!course.classes.isNullOrEmpty()) {
                item { CourseClassesSection(classes = course.classes!!) }
            }
            // 家长评价
            if (uiState.reviews.isNotEmpty()) {
                item { CourseReviewsSection(reviews = uiState.reviews, summary = uiState.reviewSummary, onAllReviews = onAllReviews) }
            }
        }

        // 底部报名栏（仅家长角色）
        if (viewModel.canEnroll) {
            BottomEnrollBar(
                modifier = Modifier.align(Alignment.BottomCenter),
                priceText = course.priceText,
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

// MARK: - 封面区

@Composable
private fun CourseCoverSection(course: CourseDetail, onBack: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(240.dp)
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
        // 返回按钮
        Box(
            modifier = Modifier
                .padding(12.dp)
                .size(36.dp)
                .clip(CircleShape)
                .background(Color.Black.copy(alpha = 0.3f))
                .clickable { onBack() },
            contentAlignment = Alignment.Center
        ) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回", tint = Color.White, modifier = Modifier.size(20.dp))
        }
    }
}

// MARK: - 信息区

@Composable
private fun CourseInfoSection(course: CourseDetail) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.Surface)
            .padding(AppDimens.L)
    ) {
        // 标签行
        Row(horizontalArrangement = Arrangement.spacedBy(AppDimens.Xs)) {
            course.ageRangeText?.let { age ->
                InfoTag(text = age, bg = AppColors.BrandSoft, fg = AppColors.Brand)
            }
            course.totalLessons?.let { lessons ->
                if (lessons > 0) InfoTag(text = "${lessons}课时", bg = AppColors.InfoTint, fg = AppColors.Info)
            }
            course.ratingText.let { rating ->
                if (rating != "新课程") InfoTag(text = "★ $rating", bg = AppColors.WarnTint, fg = AppColors.Warn)
            }
        }
        Spacer(modifier = Modifier.height(AppDimens.S))
        // 标题
        Text(
            text = course.title,
            color = AppColors.Ink,
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            lineHeight = 28.sp
        )
        Spacer(modifier = Modifier.height(AppDimens.Xs))
        // 副标题：机构 · 课时
        Text(
            text = course.studioName,
            color = AppColors.Muted,
            fontSize = 13.sp
        )
        Spacer(modifier = Modifier.height(AppDimens.S))
        // 价格行
        Row(verticalAlignment = Alignment.Bottom) {
            Text(course.priceText, color = AppColors.Clay, fontSize = 24.sp, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.width(AppDimens.Xs))
            course.originalPrice?.let { op ->
                if (op > course.price) {
                    Text(op.fenToYuanText(), color = AppColors.Muted, fontSize = 13.sp, textDecoration = TextDecoration.LineThrough)
                }
            }
            Spacer(modifier = Modifier.weight(1f))
            course.sales?.let { sales ->
                if (sales > 0) Text("已售 $sales", color = AppColors.Muted, fontSize = 12.sp)
            }
        }
    }
}

@Composable
private fun InfoTag(text: String, bg: Color, fg: Color) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(AppDimens.RadiusTag))
            .background(bg)
            .padding(horizontal = 8.dp, vertical = 3.dp)
    ) {
        Text(text, color = fg, fontSize = 11.sp)
    }
}

// MARK: - 机构卡

@Composable
private fun CourseStudioCard(course: CourseDetail) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L, vertical = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.M)
    ) {
        Text("授课机构", color = AppColors.Muted, fontSize = 12.sp)
        Spacer(modifier = Modifier.height(AppDimens.S))
        Row(verticalAlignment = Alignment.CenterVertically) {
            TogetherAvatar(url = null, name = course.studioName, size = 40.dp)
            Spacer(modifier = Modifier.width(AppDimens.M))
            Column(modifier = Modifier.weight(1f)) {
                Text(course.studioName, color = AppColors.Ink, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                course.studio?.address?.let { addr ->
                    if (addr.isNotEmpty()) {
                        Text(addr, color = AppColors.Muted, fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                }
            }
        }
        // 老师
        course.teacher?.realName?.let { teacherName ->
            if (teacherName.isNotEmpty()) {
                Spacer(modifier = Modifier.height(AppDimens.S))
                HorizontalDivider(color = AppColors.Line)
                Spacer(modifier = Modifier.height(AppDimens.S))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("主讲老师", color = AppColors.Muted, fontSize = 12.sp)
                    Spacer(modifier = Modifier.weight(1f))
                    Text(teacherName, color = AppColors.Ink, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

// MARK: - 介绍

@Composable
private fun CourseIntroSection(course: CourseDetail) {
    val intro = course.intro ?: return
    if (intro.isBlank()) return
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L, vertical = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.M)
    ) {
        Text("课程介绍", color = AppColors.Ink, fontSize = 16.sp, fontWeight = FontWeight.Bold)
        Spacer(modifier = Modifier.height(AppDimens.S))
        Text(
            text = intro,
            color = AppColors.Sub,
            fontSize = 14.sp,
            lineHeight = 22.sp
        )
    }
}

// MARK: - 班级列表

@Composable
private fun CourseClassesSection(classes: List<CourseClassItem>) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L, vertical = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.M)
    ) {
        Text("开班信息", color = AppColors.Ink, fontSize = 16.sp, fontWeight = FontWeight.Bold)
        Spacer(modifier = Modifier.height(AppDimens.M))
        classes.forEach { cls ->
            ClassRow(item = cls)
            Spacer(modifier = Modifier.height(AppDimens.S))
        }
    }
}

@Composable
private fun ClassRow(item: CourseClassItem) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusButton))
            .background(AppColors.SurfaceAlt)
            .padding(AppDimens.M),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(item.title, color = AppColors.Ink, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            Spacer(modifier = Modifier.height(2.dp))
            item.teacherName?.let { if (it.isNotEmpty()) Text(it, color = AppColors.Muted, fontSize = 12.sp) }
            item.scheduleText?.let { if (it.isNotEmpty()) Text(it, color = AppColors.Muted, fontSize = 12.sp) }
        }
        Spacer(modifier = Modifier.width(AppDimens.S))
        Text(
            text = item.enrollmentText,
            color = if (item.isFull) AppColors.Muted else AppColors.Brand,
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold
        )
    }
}

// MARK: - 家长评价

@Composable
private fun CourseReviewsSection(
    reviews: List<CourseReviewItem>,
    summary: com.together.app.services.CourseService.CourseReviewSummary?,
    onAllReviews: () -> Unit = {}
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L, vertical = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.M)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("家长评价", color = AppColors.Ink, fontSize = 16.sp, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.weight(1f))
            summary?.rating?.let { rating ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Star, contentDescription = null, tint = AppColors.Warn, modifier = Modifier.size(14.dp))
                    Spacer(modifier = Modifier.width(2.dp))
                    Text(String.format("%.1f", rating), color = AppColors.Warn, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                    summary.ratingCount?.let { count ->
                        Text(" ($count)", color = AppColors.Muted, fontSize = 12.sp)
                    }
                }
            }
            Spacer(modifier = Modifier.width(AppDimens.S))
            Text(
                "查看全部 ›",
                color = AppColors.Brand,
                fontSize = 13.sp,
                modifier = Modifier.clickable { onAllReviews() }
            )
        }
        Spacer(modifier = Modifier.height(AppDimens.M))
        reviews.take(5).forEach { review ->
            ReviewRow(item = review)
            Spacer(modifier = Modifier.height(AppDimens.M))
        }
    }
}

@Composable
private fun ReviewRow(item: CourseReviewItem) {
    Column {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TogetherAvatar(url = item.avatar, name = item.nickname, size = 28.dp)
            Spacer(modifier = Modifier.width(AppDimens.S))
            Text(item.nickname, color = AppColors.Ink, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
            // 星级
            Row {
                repeat(5) { i ->
                    Icon(
                        Icons.Default.Star,
                        contentDescription = null,
                        tint = if (i < item.rating) AppColors.Warn else AppColors.Line,
                        modifier = Modifier.size(12.dp)
                    )
                }
            }
        }
        Spacer(modifier = Modifier.height(AppDimens.Xs))
        if (item.content.isNotEmpty()) {
            Text(item.content, color = AppColors.Sub, fontSize = 13.sp, lineHeight = 20.sp)
        }
        Spacer(modifier = Modifier.height(2.dp))
        Text(item.timeText, color = AppColors.Muted, fontSize = 11.sp)
    }
}

// MARK: - 底部报名栏

@Composable
private fun BottomEnrollBar(modifier: Modifier = Modifier, priceText: String, enrolling: Boolean, onEnroll: () -> Unit) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(AppColors.Surface)
    ) {
        HorizontalDivider(color = AppColors.Line, thickness = 0.5.dp)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = AppDimens.L, vertical = AppDimens.S),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(priceText, color = AppColors.Clay, fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.weight(1f))
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(23.dp))
                    .background(AppColors.Brand)
                    .clickable { onEnroll() }
                    .padding(horizontal = 32.dp, vertical = 12.dp),
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