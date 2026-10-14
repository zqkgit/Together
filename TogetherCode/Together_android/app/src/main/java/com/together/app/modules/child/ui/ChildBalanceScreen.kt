package com.together.app.modules.child.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.core.component.EmptyStateView
import com.together.app.core.component.LoadingView
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.component.resolveImageUrl
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.ChildBalance
import com.together.app.modules.child.ChildViewModel
import com.together.app.services.ChildService.LessonLogItem

/**
 * 课时明细页（对齐 iOS ChildBalanceViewController / 小程序 child-balance）
 * 分段 Tab：课时余额（课包卡）/ 消课记录（消课卡）
 */
@Composable
fun ChildBalanceScreen(
    childId: String,
    childNickname: String = "",
    viewModel: ChildViewModel = viewModel(),
    onBack: () -> Unit = {}
) {
    val balanceState by viewModel.balanceState.collectAsState()
    var selectedTab by remember { mutableIntStateOf(0) }
    var logsLoaded by remember { mutableStateOf(false) }

    // 初始加载余额
    LaunchedEffect(childId) {
        viewModel.loadBalances(childId)
    }

    // 首次切到消课记录时加载
    LaunchedEffect(selectedTab) {
        if (selectedTab == 1 && !logsLoaded) {
            logsLoaded = true
            viewModel.loadLogs(childId)
        }
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "课时明细", onBack = onBack)

        // 分段
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
            listOf("课时余额", "消课记录").forEachIndexed { index, title ->
                val selected = index == selectedTab
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(30.dp)
                        .clip(RoundedCornerShape(15.dp))
                        .background(if (selected) AppColors.Brand else Color.Transparent)
                        .clickable { selectedTab = index },
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

        // 内容
        when (selectedTab) {
            0 -> {
                if (balanceState.loadingBalances) {
                    LoadingView()
                } else if (balanceState.balances.isEmpty()) {
                    EmptyStateView(message = "暂无课时包")
                } else {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = androidx.compose.foundation.layout.PaddingValues(
                            start = AppDimens.L, end = AppDimens.L,
                            top = AppDimens.S, bottom = AppDimens.Xl
                        ),
                        verticalArrangement = Arrangement.spacedBy(AppDimens.S)
                    ) {
                        items(balanceState.balances, key = { it.balanceId }) { balance ->
                            BalanceCard(balance = balance)
                        }
                    }
                }
            }
            1 -> {
                if (balanceState.loadingLogs) {
                    LoadingView()
                } else if (balanceState.logs.isEmpty()) {
                    EmptyStateView(message = "暂无消课记录")
                } else {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = androidx.compose.foundation.layout.PaddingValues(
                            start = AppDimens.L, end = AppDimens.L,
                            top = AppDimens.S, bottom = AppDimens.Xl
                        ),
                        verticalArrangement = Arrangement.spacedBy(AppDimens.S)
                    ) {
                        items(balanceState.logs, key = { it.logId ?: it.hashCode().toString() }) { log ->
                            LogCard(log = log)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 课时包卡片

@Composable
private fun BalanceCard(balance: ChildBalance) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.CardInner)
    ) {
        Column {
            // 封面 + 标题/工作室
            Row(verticalAlignment = Alignment.CenterVertically) {
                val cover = balance.courseCover
                if (!cover.isNullOrBlank()) {
                    AsyncImage(
                        model = resolveImageUrl(cover),
                        contentDescription = "课程封面",
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .size(48.dp)
                            .clip(RoundedCornerShape(AppDimens.RadiusIcon))
                    )
                } else {
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .clip(RoundedCornerShape(AppDimens.RadiusIcon))
                            .background(AppColors.SurfaceAlt)
                    )
                }
                Spacer(modifier = Modifier.width(AppDimens.M))
                Column {
                    Text(
                        text = balance.courseTitle ?: "未命名课程",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = AppColors.Ink
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = balance.studioName ?: "",
                        fontSize = 12.sp,
                        color = AppColors.Sub
                    )
                }
            }

            Spacer(modifier = Modifier.height(AppDimens.M))

            // 三列统计
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                StatItem(
                    value = balance.remainingLessons.toString(),
                    label = "剩余",
                    valueColor = AppColors.Brand,
                    modifier = Modifier.weight(1f)
                )
                StatItem(
                    value = balance.totalLessons.toString(),
                    label = "总课时",
                    valueColor = AppColors.Ink,
                    modifier = Modifier.weight(1f)
                )
                StatItem(
                    value = balance.consumedLessons.toString(),
                    label = "已消",
                    valueColor = AppColors.Ink,
                    modifier = Modifier.weight(1f)
                )
            }

            // 有效期
            val validTo = balance.validTo
            if (!validTo.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(AppDimens.S))
                Text(
                    text = "有效期至 ${validTo.take(10)}",
                    fontSize = 11.sp,
                    color = AppColors.Muted
                )
            }
        }
    }
}

@Composable
private fun StatItem(
    value: String,
    label: String,
    valueColor: Color,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(text = value, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = valueColor)
        Spacer(modifier = Modifier.height(2.dp))
        Text(text = label, fontSize = 11.sp, color = AppColors.Muted)
    }
}

// MARK: - 消课记录卡

@Composable
private fun LogCard(log: LessonLogItem) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.CardInner),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = log.courseTitle ?: "",
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink
            )
            Spacer(modifier = Modifier.height(3.dp))
            // 副标题：孩子·工作室·日期·时间·补课
            val parts = mutableListOf<String>()
            log.childName?.takeIf { it.isNotEmpty() }?.let { parts.add(it) }
            log.studioName?.takeIf { it.isNotEmpty() }?.let { parts.add(it) }
            log.lessonDate?.takeIf { it.isNotEmpty() }?.let { date ->
                parts.add(date)
                log.startTime?.takeIf { it.isNotEmpty() }?.let { parts.add(it) }
            }
            if (log.isMakeup == true) parts.add("补课")
            Text(
                text = parts.joinToString(" · "),
                fontSize = 12.sp,
                color = AppColors.Sub,
                maxLines = 2
            )
        }
        Spacer(modifier = Modifier.width(AppDimens.M))
        // delta
        val delta = log.delta
        if (delta != null) {
            Text(
                text = if (delta > 0) "+$delta 课时" else "$delta 课时",
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (delta > 0) AppColors.Brand else AppColors.Danger
            )
        }
    }
}