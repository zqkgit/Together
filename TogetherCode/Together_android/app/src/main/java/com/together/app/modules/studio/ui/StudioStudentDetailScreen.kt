package com.together.app.modules.studio.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
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
import com.together.app.core.component.InfoRow
import com.together.app.core.component.LoadingView
import com.together.app.core.component.SectionHeader
import com.together.app.core.component.TogetherAvatar
import com.together.app.core.component.TogetherDivider
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.studio.StudioViewModel
import com.together.app.services.StudioService

/**
 * 工作室「学员详情」页（对齐 iOS StudioStudentDetailViewController）
 *
 * 学员信息卡（头像+昵称+年龄·性别+剩余课时+家长/电话/报名时间/课时合计）
 * + 课程课时卡（每门课剩余课时，≤3 节转橙色）+ 课时流水卡（变动记录）
 */
@Composable
fun StudioStudentDetailScreen(
    childId: String,
    studentName: String = "学员详情",
    onBack: () -> Unit = {},
    viewModel: StudioViewModel = viewModel()
) {
    val state by viewModel.studentDetailState.collectAsState()

    // ON_RESUME 刷新
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) viewModel.loadStudentDetail(childId)
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
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
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "返回",
                    tint = AppColors.Ink
                )
            }
            Text(
                text = studentName,
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }

        // 内容
        when {
            state.loading && state.detail == null -> LoadingView()
            state.error != null && state.detail == null -> ErrorView(
                message = state.error ?: "加载失败",
                onRetry = { viewModel.loadStudentDetail(childId) }
            )
            state.detail == null -> EmptyStateView(message = "未找到学员信息")
            else -> {
                val detail = state.detail!!
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(horizontal = AppDimens.L, vertical = AppDimens.S),
                    verticalArrangement = Arrangement.spacedBy(AppDimens.M)
                ) {
                    // 学员信息卡
                    StudentInfoCard(student = detail.student)

                    // 课程课时
                    if (!detail.balances.isNullOrEmpty()) {
                        SectionHeader(title = "课程课时")
                        detail.balances.forEach { balance ->
                            BalanceCard(balance = balance)
                        }
                    }

                    // 课时流水
                    if (!detail.logs.isNullOrEmpty()) {
                        SectionHeader(title = "课时流水")
                        detail.logs.forEach { log ->
                            LogCard(log = log)
                        }
                    }

                    Spacer(modifier = Modifier.height(AppDimens.Xl))
                }
            }
        }
    }
}

// MARK: - 学员信息卡

@Composable
private fun StudentInfoCard(student: StudioService.StudioStudentItem?) {
    if (student == null) return

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.CardInner)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TogetherAvatar(
                url = student.avatar,
                name = student.displayName,
                size = 52.dp
            )
            Spacer(modifier = Modifier.width(AppDimens.M))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = student.displayName,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.Ink,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = listOfNotNull(
                        student.age?.let { "$it 岁" },
                        student.genderText
                    ).joinToString(" · "),
                    fontSize = 13.sp,
                    color = AppColors.Sub
                )
            }
            Spacer(modifier = Modifier.width(AppDimens.S))
            Column(horizontalAlignment = Alignment.End) {
                Text(
                    text = student.lessonsText,
                    fontSize = 18.sp,
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

        Spacer(modifier = Modifier.height(AppDimens.M))
        TogetherDivider()

        Spacer(modifier = Modifier.height(AppDimens.M))
        InfoRow(label = "家长", value = student.parentName?.takeIf { it.isNotEmpty() } ?: "—")
        Spacer(modifier = Modifier.height(AppDimens.S))
        InfoRow(label = "电话", value = student.parentPhone?.takeIf { it.isNotEmpty() } ?: "—")
        Spacer(modifier = Modifier.height(AppDimens.S))
        InfoRow(label = "报名时间", value = student.enrolledText)
        Spacer(modifier = Modifier.height(AppDimens.S))
        InfoRow(
            label = "课时合计",
            value = "共 ${student.totalLessons ?: 0} 节 · 已消耗 ${student.consumedLessons ?: 0} 节"
        )
    }
}

// MARK: - 课程课时卡

@Composable
private fun BalanceCard(balance: StudioService.StudioStudentBalance) {
    val lowBalance = (balance.remainingLessons ?: 0) <= 3

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.CardInner, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = balance.titleText,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = balance.detailText,
                fontSize = 12.sp,
                color = AppColors.Muted
            )
            if (balance.validityText.isNotEmpty()) {
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = balance.validityText,
                    fontSize = 11.sp,
                    color = AppColors.Muted
                )
            }
        }
        Spacer(modifier = Modifier.width(AppDimens.S))
        Text(
            text = balance.remainingText,
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
            color = if (lowBalance) AppColors.Warn else AppColors.BrandDark
        )
    }
}

// MARK: - 课时流水卡

@Composable
private fun LogCard(log: StudioService.StudioStudentLog) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.CardInner, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = log.dateText,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.Sub
                )
                if (log.timeText.isNotEmpty()) {
                    Spacer(modifier = Modifier.width(AppDimens.S))
                    Text(
                        text = log.timeText,
                        fontSize = 12.sp,
                        color = AppColors.Muted
                    )
                }
            }
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = log.titleText,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(2.dp))
            val metaText = buildString {
                append(log.sourceText)
                log.balanceAfter?.let { append(" · 剩余 $it 节") }
            }
            Text(
                text = metaText,
                fontSize = 12.sp,
                color = AppColors.Muted
            )
            if (!log.note.isNullOrEmpty()) {
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = "备注：${log.note}",
                    fontSize = 12.sp,
                    color = AppColors.Muted,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
        Spacer(modifier = Modifier.width(AppDimens.S))
        Text(
            text = log.deltaText,
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
            color = if (log.isIncrease) AppColors.Brand else AppColors.Warn
        )
    }
}