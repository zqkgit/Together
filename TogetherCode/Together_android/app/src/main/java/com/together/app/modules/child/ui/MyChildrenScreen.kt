package com.together.app.modules.child.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.core.component.EmptyStateView
import com.together.app.core.component.LoadingView
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.ChildItem
import com.together.app.modules.child.ChildViewModel

/**
 * 我的孩子列表（对齐 iOS MyChildrenViewController / PR 图1）
 * 孩子卡片（头像/昵称/性别年龄/剩余课时/课程标签/查看）+ 底部虚线添加按钮
 */
@Composable
fun MyChildrenScreen(
    viewModel: ChildViewModel = viewModel(),
    onBack: () -> Unit = {},
    onChildClick: (ChildItem) -> Unit = {},
    onAddChild: () -> Unit = {}
) {
    val uiState by viewModel.listState.collectAsState()

    // 每次页面可见时刷新（含从添加孩子页返回）
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                viewModel.loadChildren()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "我的孩子", onBack = onBack)

        if (uiState.loading && uiState.children.isEmpty()) {
            LoadingView()
            return@Column
        }

        if (!uiState.loading && uiState.children.isEmpty() && uiState.error == null) {
            Column(modifier = Modifier.weight(1f)) {
                EmptyStateView(message = "还没有孩子档案\n点击下方「添加孩子」创建")
                DashedAddChildButton(onClick = onAddChild)
                Spacer(modifier = Modifier.height(AppDimens.Xl))
            }
            return@Column
        }

        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(
                top = AppDimens.S, bottom = AppDimens.Xl
            )
        ) {
            items(uiState.children, key = { it.childId }) { child ->
                ChildCard(child = child, onClick = { onChildClick(child) })
            }
            // 底部虚线添加按钮
            item {
                DashedAddChildButton(
                    onClick = onAddChild,
                    modifier = Modifier.padding(
                        top = AppDimens.L,
                        start = AppDimens.M, end = AppDimens.M
                    )
                )
            }
        }
    }
}

// MARK: - 孩子卡片

@Composable
private fun ChildCard(child: ChildItem, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M, vertical = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .border(1.dp, AppColors.Line, RoundedCornerShape(AppDimens.RadiusCard))
            .clickable { onClick() }
            .padding(AppDimens.L)
    ) {
        Column {
            // 头像 + 昵称/信息/课时 + 查看按钮
            Row(verticalAlignment = Alignment.CenterVertically) {
                ChildAvatarView(
                    avatar = child.avatar,
                    name = child.nickname,
                    size = 52.dp,
                    bgColor = AppColors.BrandSoft,
                    textColor = AppColors.Brand
                )
                Spacer(modifier = Modifier.width(AppDimens.M))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = child.nickname,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = AppColors.Ink
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = childInfoText(child),
                        fontSize = 12.sp,
                        color = AppColors.Sub
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = "剩余课时${child.totalRemainingLessons ?: 0}节",
                        fontSize = 12.sp,
                        color = AppColors.Brand
                    )
                }
                // 查看按钮
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(13.dp))
                        .background(AppColors.BrandSoft)
                        .clickable { onClick() }
                        .padding(horizontal = 14.dp, vertical = 5.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "查看",
                        fontSize = 12.sp,
                        color = AppColors.Brand
                    )
                }
            }

            Spacer(modifier = Modifier.height(AppDimens.M))

            // 课程标签（去重前 3）
            val courses = child.balances
                ?.mapNotNull { it.courseTitle }
                ?.distinct()
                ?.take(3)
                ?: emptyList()
            Row(horizontalArrangement = Arrangement.spacedBy(AppDimens.S)) {
                if (courses.isEmpty()) {
                    CourseTag(text = "未报名课程", color = AppColors.Muted)
                } else {
                    courses.forEach { CourseTag(text = it, color = AppColors.Wood) }
                }
            }
        }
    }
}

/** 性别·年龄 */
private fun childInfoText(child: ChildItem): String {
    val gender = when (child.gender) {
        2 -> "女"
        1 -> "男"
        else -> ""
    }
    val age = child.ageText ?: ""
    return listOf(gender, age).filter { it.isNotEmpty() }.joinToString("·")
}

// MARK: - 孩子头像（emoji / URL / 首字 三模式）

@Composable
fun ChildAvatarView(
    avatar: String?,
    name: String,
    size: androidx.compose.ui.unit.Dp,
    bgColor: androidx.compose.ui.graphics.Color = AppColors.BrandSoft,
    textColor: androidx.compose.ui.graphics.Color = AppColors.Brand,
    shape: androidx.compose.ui.graphics.Shape = CircleShape
) {
    if (!avatar.isNullOrBlank() && avatar.startsWith("http")) {
        AsyncImage(
            model = avatar,
            contentDescription = name,
            contentScale = ContentScale.Crop,
            modifier = Modifier.size(size).clip(shape)
        )
    } else if (!avatar.isNullOrBlank()) {
        // emoji 头像
        Box(
            modifier = Modifier.size(size).clip(shape).background(bgColor),
            contentAlignment = Alignment.Center
        ) {
            Text(text = avatar, fontSize = (size.value * 0.55f).sp)
        }
    } else {
        // 昵称首字
        Box(
            modifier = Modifier.size(size).clip(shape).background(bgColor),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = name.firstOrNull()?.toString() ?: "?",
                fontSize = (size.value * 0.45f).sp,
                fontWeight = FontWeight.Bold,
                color = textColor
            )
        }
    }
}

// MARK: - 课程标签

@Composable
private fun CourseTag(text: String, color: androidx.compose.ui.graphics.Color) {
    Text(
        text = text,
        color = color,
        fontSize = 11.sp,
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(color.copy(alpha = 0.12f))
            .padding(horizontal = 10.dp, vertical = 3.dp)
    )
}

// MARK: - 虚线添加按钮

@Composable
private fun DashedAddChildButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val radius = AppDimens.RadiusButton
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(56.dp)
            .clip(RoundedCornerShape(radius))
            .background(AppColors.BrandSoft)
            .drawBehind {
                drawRoundRect(
                    color = AppColors.Brand,
                    cornerRadius = CornerRadius(radius.toPx()),
                    style = Stroke(
                        width = 2f,
                        pathEffect = PathEffect.dashPathEffect(floatArrayOf(10f, 8f), 0f)
                    )
                )
            }
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = "+ 添加孩子",
            color = AppColors.Brand,
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium
        )
    }
}