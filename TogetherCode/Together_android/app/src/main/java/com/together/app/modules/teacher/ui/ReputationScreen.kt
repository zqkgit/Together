package com.together.app.modules.teacher.ui

import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
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
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.component.EmptyStateView
import com.together.app.core.component.ErrorView
import com.together.app.core.component.LoadingView
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.teacher.TeacherViewModel
import com.together.app.services.TeacherService

/**
 * 评价与口碑：均分 + 星级分布概览卡 + 评价列表
 * 对齐 iOS ReputationViewController
 */
@Composable
fun ReputationScreen(
    viewModel: TeacherViewModel = viewModel(),
    onBack: () -> Unit = {}
) {
    val state by viewModel.reviewState.collectAsState()
    val lifecycleOwner = LocalLifecycleOwner.current

    LaunchedEffect(Unit) { viewModel.loadReviews() }
    androidx.compose.runtime.DisposableEffect(lifecycleOwner) {
        val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME && state.data != null) {
                viewModel.loadReviews()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "评价与口碑", onBack = onBack)

        Box(modifier = Modifier.weight(1f)) {
            val data = state.data
            when {
                state.loading && data == null -> LoadingView()
                state.error != null && data == null -> ErrorView(
                    message = state.error!!,
                    onRetry = { viewModel.loadReviews() }
                )
                data == null || (data.list.isNullOrEmpty() && (data.total ?: 0) == 0) ->
                    EmptyStateView(message = "暂无评价")
                else -> {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(
                            start = AppDimens.M, end = AppDimens.M,
                            top = AppDimens.S, bottom = AppDimens.Xl
                        ),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        // 概览卡
                        item { ReviewOverviewCard(data) }
                        // 评价列表
                        items(data.list ?: emptyList(), key = { it.reviewId ?: "" }) { review ->
                            ReviewCard(review)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ReviewOverviewCard(data: TeacherService.ReviewData) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.CardInner, vertical = AppDimens.L)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = String.format("%.1f", data.average ?: 0.0),
                fontSize = 36.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.Wood
            )
            Spacer(modifier = Modifier.width(AppDimens.M))
            Column {
                Text(
                    text = "★".repeat((data.average ?: 0.0).toInt().coerceIn(0, 5))
                        .plus("☆".repeat(5 - (data.average ?: 0.0).toInt().coerceIn(0, 5))),
                    fontSize = 14.sp,
                    color = AppColors.Wood
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = "共${data.total ?: 0}条评价",
                    fontSize = 12.sp,
                    color = AppColors.Muted
                )
            }
        }

        // 星级分布
        val dist = data.ratingDistribution ?: emptyMap()
        val maxCount = dist.values.maxOrNull() ?: 1
        Spacer(modifier = Modifier.height(AppDimens.M))
        (5 downTo 1).forEach { star ->
            val count = dist[star.toString()] ?: 0
            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(text = "${star}星", fontSize = 11.sp, color = AppColors.Muted, modifier = Modifier.width(28.dp))
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(6.dp)
                        .clip(RoundedCornerShape(3.dp))
                        .background(AppColors.SurfaceAlt)
                ) {
                    if (count > 0) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth(if (maxCount > 0) count.toFloat() / maxCount else 0f)
                                .height(6.dp)
                                .clip(RoundedCornerShape(3.dp))
                                .background(AppColors.Wood)
                        )
                    }
                }
                Text(
                    text = "$count",
                    fontSize = 11.sp,
                    color = AppColors.Sub,
                    modifier = Modifier.width(28.dp).padding(start = 6.dp)
                )
            }
        }
    }
}

@Composable
private fun ReviewCard(review: TeacherService.ReviewItem) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.CardInner, vertical = AppDimens.L)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            // 头像
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(AppColors.SurfaceAlt),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = (review.user?.nickname ?: "家").take(1),
                    fontSize = 14.sp,
                    color = AppColors.Wood
                )
            }
            Spacer(modifier = Modifier.width(AppDimens.S))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = review.user?.nickname ?: "家长",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = AppColors.Ink
                )
                Text(text = review.starsText, fontSize = 12.sp, color = AppColors.Wood)
            }
            Text(text = review.timeText, fontSize = 11.sp, color = AppColors.Muted)
        }

        review.content?.takeIf { it.isNotEmpty() }?.let {
            Spacer(modifier = Modifier.height(AppDimens.S))
            Text(text = it, fontSize = 14.sp, color = AppColors.Ink, lineHeight = 20.sp)
        }

        review.course?.title?.takeIf { it.isNotEmpty() }?.let {
            Spacer(modifier = Modifier.height(AppDimens.S))
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(4.dp))
                    .background(AppColors.SurfaceAlt)
                    .padding(horizontal = 6.dp, vertical = 2.dp)
            ) {
                Text(text = it, fontSize = 11.sp, color = AppColors.Sub)
            }
        }
    }
}