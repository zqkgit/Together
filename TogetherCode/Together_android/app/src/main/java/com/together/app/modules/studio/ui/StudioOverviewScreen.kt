package com.together.app.modules.studio.ui

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.studio.StudioViewModel

/**
 * 工作室「经营概览」页（对齐 iOS StudioOverviewViewController）
 *
 * 结构：标题栏 + 深绿营收卡 + 三张统计卡 + 待办事项（退款/结算行）+ 机构动态卡
 * 数据：GET /studio/overview
 */
@Composable
fun StudioOverviewScreen(
    onRevenue: () -> Unit = {},
    onTodo: () -> Unit = {},
    onRefund: () -> Unit = {},
    onMessages: () -> Unit = {},
    onPlaza: () -> Unit = {},
    viewModel: StudioViewModel = viewModel()
) {
    val state by viewModel.overviewState.collectAsState()
    val context = LocalContext.current

    // ON_RESUME 刷新
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                viewModel.loadOverview()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val data = state.data
    val revenue = data?.revenue
    val stats = data?.stats
    val todos = data?.todos
    val dynamic = data?.dynamic

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
    ) {
        // 标题栏
        item {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 48.dp, start = 20.dp, end = 20.dp, bottom = 16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "经营概览",
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.Ink,
                    modifier = Modifier.weight(1f)
                )
                Box(
                    modifier = Modifier
                        .size(38.dp)
                        .shadow(3.dp, CircleShape)
                        .clip(CircleShape)
                        .background(AppColors.Surface)
                        .clickable { onMessages() },
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Default.Notifications,
                        contentDescription = "消息",
                        tint = AppColors.Ink,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        }

        // 营收卡（深绿渐变）
        item {
            Box(
                modifier = Modifier
                    .padding(horizontal = AppDimens.M)
                    .height(156.dp)
                    .clip(RoundedCornerShape(AppDimens.RadiusCard))
                    .background(
                        Brush.linearGradient(
                            colors = listOf(AppColors.Brand, Color(0xFF46C76D))
                        )
                    )
                    .clickable { onRevenue() }
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(AppDimens.CardInner)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = "营收概览",
                            fontSize = 13.sp,
                            color = Color.White.copy(alpha = 0.85f)
                        )
                        Spacer(modifier = Modifier.weight(1f))
                        Icon(
                            Icons.AutoMirrored.Filled.KeyboardArrowRight,
                            contentDescription = null,
                            tint = Color.White.copy(alpha = 0.5f),
                            modifier = Modifier.size(16.dp)
                        )
                    }
                    Row(
                        modifier = Modifier.padding(top = AppDimens.Xs),
                        verticalAlignment = Alignment.Bottom
                    ) {
                        Text(
                            text = revenue?.monthIncomeText ?: "¥ 0",
                            fontSize = 28.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = "本月营收",
                            fontSize = 11.sp,
                            color = Color.White.copy(alpha = 0.55f),
                            modifier = Modifier.padding(bottom = 4.dp)
                        )
                    }
                    Spacer(modifier = Modifier.weight(1f))
                    // 底部两列：分销返利 / 结算中
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceEvenly
                    ) {
                        MiniColumn(
                            title = "分销返利",
                            value = revenue?.distributionText ?: "¥ 0"
                        )
                        MiniColumn(
                            title = "结算中",
                            value = revenue?.settlingText ?: "¥ 0"
                        )
                    }
                }
            }
        }

        // 三张统计卡
        item {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 18.dp, vertical = AppDimens.L),
                horizontalArrangement = Arrangement.spacedBy(AppDimens.M)
            ) {
                StatCard(
                    title = "在读学员",
                    value = stats?.activeStudents ?: 0,
                    modifier = Modifier.weight(1f)
                )
                StatCard(
                    title = "在售课程",
                    value = stats?.onlineCourses ?: 0,
                    modifier = Modifier.weight(1f)
                )
                StatCard(
                    title = "入驻教师",
                    value = stats?.teachers ?: 0,
                    modifier = Modifier.weight(1f)
                )
            }
        }

        // 待办事项标题栏
        item {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 20.dp, end = 18.dp, bottom = AppDimens.M),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "待办事项",
                    fontSize = 17.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.Ink,
                    modifier = Modifier.weight(1f)
                )
                Row(
                    modifier = Modifier.clickable { onTodo() },
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "全部",
                        fontSize = 12.sp,
                        color = AppColors.Sub
                    )
                    Icon(
                        Icons.AutoMirrored.Filled.KeyboardArrowRight,
                        contentDescription = null,
                        tint = AppColors.Muted,
                        modifier = Modifier.size(14.dp)
                    )
                }
            }
        }

        // 退款待办行
        item {
            TodoRow(
                iconBg = AppColors.Brand,
                title = "${todos?.pendingRefundCount ?: 0} 笔退款申请待审核",
                subtitle = "超时未处理将自动通过",
                action = "处理",
                onClick = onRefund,
                modifier = Modifier.padding(horizontal = 18.dp)
            )
        }

        // 结算待办行
        item {
            TodoRow(
                iconBg = AppColors.Wood,
                title = if ((todos?.pendingSettleOrderCount ?: 0) > 0) {
                    "${todos?.pendingSettleOrderCount} 笔课程订单待结算"
                } else {
                    "暂无待结算订单"
                },
                subtitle = if ((todos?.pendingSettleOrderCount ?: 0) > 0) {
                    "收入合计 ${todos?.pendingSettleAmountText ?: "¥ 0"}"
                } else {
                    "新课订单收款后将自动结算"
                },
                action = "查看",
                onClick = onTodo,
                modifier = Modifier.padding(horizontal = 18.dp, vertical = AppDimens.M)
            )
        }

        // 机构动态卡
        item {
            DynamicCard(
                name = dynamic?.name ?: "我的工作室",
                todayEnrolled = dynamic?.todayEnrolledCount ?: 0,
                headline = dynamic?.headlineText ?: "本周经营数据持续更新中。",
                weeklyEnrolled = dynamic?.weeklyEnrolledCount ?: 0,
                weeklyIncome = dynamic?.weeklyIncomeText ?: "+¥ 0",
                onClick = onPlaza,
                modifier = Modifier.padding(horizontal = 18.dp)
            )
            Spacer(modifier = Modifier.height(AppDimens.Xl))
        }
    }
}

// MARK: - 营收卡底部小列

@Composable
private fun MiniColumn(title: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = value,
            fontSize = 15.sp,
            color = Color.White
        )
        Text(
            text = title,
            fontSize = 11.sp,
            color = Color.White.copy(alpha = 0.7f),
            modifier = Modifier.padding(top = 2.dp)
        )
    }
}

// MARK: - 统计小卡

@Composable
private fun StatCard(title: String, value: Int, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .height(80.dp)
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = value.toString(),
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.Brand
            )
            Text(
                text = title,
                fontSize = 11.sp,
                color = AppColors.Muted,
                modifier = Modifier.padding(top = 2.dp)
            )
        }
    }
}

// MARK: - 待办行

@Composable
private fun TodoRow(
    iconBg: Color,
    title: String,
    subtitle: String,
    action: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(76.dp)
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable { onClick() }
            .padding(horizontal = 14.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // 图标块
            Box(
                modifier = Modifier
                    .size(46.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(iconBg),
                contentAlignment = Alignment.Center
            ) {
                Box(
                    modifier = Modifier
                        .size(22.dp)
                        .clip(RoundedCornerShape(6.dp))
                        .background(Color.White.copy(alpha = 0.9f))
                )
            }
            Spacer(modifier = Modifier.width(AppDimens.M))
            // 标题+副标题
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Medium,
                    color = AppColors.Ink
                )
                Text(
                    text = subtitle,
                    fontSize = 12.sp,
                    color = AppColors.Muted,
                    modifier = Modifier.padding(top = 3.dp)
                )
            }
            // 动作
            Text(
                text = action,
                fontSize = 13.sp,
                color = AppColors.Brand
            )
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = AppColors.Brand,
                modifier = Modifier.size(14.dp)
            )
        }
    }
}

// MARK: - 机构动态卡

@Composable
private fun DynamicCard(
    name: String,
    todayEnrolled: Int,
    headline: String,
    weeklyEnrolled: Int,
    weeklyIncome: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable { onClick() }
            .padding(14.dp)
    ) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(46.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(AppColors.Brand),
                    contentAlignment = Alignment.Center
                ) {
                    Box(
                        modifier = Modifier
                            .size(22.dp)
                            .clip(RoundedCornerShape(6.dp))
                            .background(Color.White.copy(alpha = 0.9f))
                    )
                }
                Spacer(modifier = Modifier.width(AppDimens.M))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = name,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Medium,
                        color = AppColors.Ink
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "工作室",
                        fontSize = 10.sp,
                        color = AppColors.Brand,
                        modifier = Modifier
                            .clip(RoundedCornerShape(AppDimens.RadiusTag))
                            .background(AppColors.BrandSoft)
                            .padding(horizontal = 7.dp, vertical = 2.dp)
                    )
                }
            }
            Text(
                text = "今日招生 $todayEnrolled 人",
                fontSize = 12.sp,
                color = AppColors.Muted,
                modifier = Modifier.padding(top = 5.dp)
            )
            Text(
                text = headline,
                fontSize = 14.sp,
                color = AppColors.Ink,
                modifier = Modifier.padding(top = 14.dp)
            )
            Row(
                modifier = Modifier.padding(top = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "本周报名 $weeklyEnrolled 人",
                    fontSize = 12.sp,
                    color = AppColors.Sub
                )
                Spacer(modifier = Modifier.width(18.dp))
                Text(
                    text = "营收 $weeklyIncome",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.Brand
                )
            }
        }
    }
}