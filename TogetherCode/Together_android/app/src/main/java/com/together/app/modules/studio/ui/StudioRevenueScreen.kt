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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.component.ErrorView
import com.together.app.core.component.LoadingView
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.studio.StudioViewModel
import com.together.app.services.StudioService
import java.time.LocalDate
import java.time.format.DateTimeFormatter

/**
 * 工作室「收益中心」页（对齐 iOS StudioRevenueViewController）
 *
 * 营收概览渐变卡（累计营收 + 本月营收/累计退款/分销支出/净收入 四列 + 时间筛选）
 * + 明细卡（区间退款 + 区间净收入）
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StudioRevenueScreen(
    onBack: () -> Unit = {},
    onWithdrawals: () -> Unit = {},
    viewModel: StudioViewModel = viewModel()
) {
    val state by viewModel.financeState.collectAsState()
    var selectedPreset by remember { mutableStateOf(DatePreset.THIS_MONTH) }
    var showDateFilter by remember { mutableStateOf(false) }

    // ON_RESUME 刷新
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                val (s, e) = selectedPreset.dates()
                viewModel.loadFinance(s, e)
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    fun applyPreset(preset: DatePreset) {
        selectedPreset = preset
        showDateFilter = false
        val (s, e) = preset.dates()
        viewModel.loadFinance(s, e)
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
                text = "收益中心",
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink
            )
        }

        // 内容
        PullToRefreshBox(
            isRefreshing = state.loading,
            onRefresh = {
                val (s, e) = selectedPreset.dates()
                viewModel.loadFinance(s, e)
            },
            modifier = Modifier.fillMaxSize()
        ) {
            when {
                state.loading && state.data == null -> LoadingView()
                state.error != null && state.data == null -> ErrorView(
                    message = state.error ?: "加载失败",
                    onRetry = {
                        val (s, e) = selectedPreset.dates()
                        viewModel.loadFinance(s, e)
                    }
                )
                else -> {
                    val summary = state.data?.summary
                    val period = state.data?.period
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                            .padding(horizontal = AppDimens.L, vertical = AppDimens.S),
                        verticalArrangement = Arrangement.spacedBy(AppDimens.M)
                    ) {
                        // 营收概览渐变卡
                        RevenueOverviewCard(
                            summary = summary,
                            presetTitle = periodTitle(selectedPreset, period),
                            onCardClick = onWithdrawals,
                            onPeriodClick = { showDateFilter = true }
                        )

                        // 明细卡
                        DetailCard(summary = summary)

                        Spacer(modifier = Modifier.height(AppDimens.Xl))
                    }
                }
            }
        }
    }

    // 日期筛选弹窗
    if (showDateFilter) {
        AlertDialog(
            onDismissRequest = { showDateFilter = false },
            title = { Text("选择时间范围", fontWeight = FontWeight.SemiBold) },
            text = {
                Column {
                    DatePreset.entries.forEach { preset ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { applyPreset(preset) }
                                .padding(vertical = 12.dp, horizontal = 4.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = preset.title,
                                fontSize = 15.sp,
                                fontWeight = if (preset == selectedPreset) FontWeight.SemiBold else FontWeight.Normal,
                                color = if (preset == selectedPreset) AppColors.Brand else AppColors.Ink
                            )
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showDateFilter = false }) {
                    Text("取消", color = AppColors.Muted)
                }
            }
        )
    }
}

// MARK: - 日期预设

enum class DatePreset(val title: String) {
    THIS_MONTH("本月"),
    LAST_MONTH("上月"),
    LAST_7_DAYS("近7天"),
    LAST_30_DAYS("近30天"),
    ALL("全部");

    fun dates(): Pair<String?, String?> {
        val today = LocalDate.now()
        val fmt = DateTimeFormatter.ofPattern("yyyy-MM-dd")
        return when (this) {
            THIS_MONTH -> today.withDayOfMonth(1).format(fmt) to today.format(fmt)
            LAST_MONTH -> {
                val last = today.minusMonths(1)
                last.withDayOfMonth(1).format(fmt) to last.withDayOfMonth(last.lengthOfMonth()).format(fmt)
            }
            LAST_7_DAYS -> today.minusDays(6).format(fmt) to today.format(fmt)
            LAST_30_DAYS -> today.minusDays(29).format(fmt) to today.format(fmt)
            ALL -> null to null
        }
    }
}

private fun periodTitle(preset: DatePreset, period: StudioService.StudioFinancePeriod?): String {
    if (preset != DatePreset.ALL) return preset.title
    val s = period?.startDate?.takeIf { it.isNotEmpty() } ?: return "全部"
    val e = period?.endDate?.takeIf { it.isNotEmpty() } ?: return "全部"
    return "${s.takeLast(5)}~${e.takeLast(5)}"
}

// MARK: - 营收概览渐变卡

@Composable
private fun RevenueOverviewCard(
    summary: StudioService.StudioFinanceSummary?,
    presetTitle: String,
    onCardClick: () -> Unit,
    onPeriodClick: () -> Unit
) {
    val gradient = Brush.linearGradient(
        colors = listOf(AppColors.Brand, Color(0xFF46C76D))
    )

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(gradient)
            .clickable(onClick = onCardClick)
            .padding(AppDimens.CardInner)
    ) {
        // 标题行 + 时间筛选
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = "营收概览",
                fontSize = 13.sp,
                color = Color.White.copy(alpha = 0.85f)
            )
            Spacer(modifier = Modifier.weight(1f))
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .clickable(onClick = onPeriodClick)
                    .padding(horizontal = 6.dp, vertical = 2.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = presetTitle,
                    fontSize = 11.sp,
                    color = Color.White.copy(alpha = 0.7f)
                )
                Spacer(modifier = Modifier.width(2.dp))
                Icon(
                    Icons.Default.KeyboardArrowDown,
                    contentDescription = null,
                    tint = Color.White.copy(alpha = 0.5f),
                    modifier = Modifier.height(14.dp)
                )
            }
        }

        Spacer(modifier = Modifier.height(AppDimens.Xs))

        // 大金额
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                text = StudioService.amountText(summary?.gmvTotalValue ?: 0),
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
            Spacer(modifier = Modifier.width(6.dp))
            Text(
                text = "累计营收",
                fontSize = 11.sp,
                color = Color.White.copy(alpha = 0.55f),
                modifier = Modifier.padding(bottom = 4.dp)
            )
        }

        Spacer(modifier = Modifier.height(AppDimens.L))

        // 四列
        val items = listOf(
            "本月营收" to StudioService.groupedNumber(summary?.gmvPeriodValue ?: 0),
            "累计退款" to StudioService.groupedNumber(summary?.refundTotalValue ?: 0),
            "分销支出" to StudioService.groupedNumber(summary?.distributionTotalValue ?: 0),
            "净收入" to StudioService.groupedNumber(summary?.netTotalValue ?: 0)
        )
        Row(modifier = Modifier.fillMaxWidth()) {
            items.forEach { (title, value) ->
                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = title,
                        fontSize = 10.sp,
                        color = Color.White.copy(alpha = 0.65f)
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = value,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                }
            }
        }
    }
}

// MARK: - 明细卡

@Composable
private fun DetailCard(summary: StudioService.StudioFinanceSummary?) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.CardInner)
    ) {
        DetailRow(
            title = "区间退款",
            value = StudioService.amountText(summary?.refundPeriodValue ?: 0)
        )
        Spacer(modifier = Modifier.height(AppDimens.M))
        DetailRow(
            title = "区间净收入",
            value = StudioService.amountText(summary?.netPeriodValue ?: 0)
        )
    }
}

@Composable
private fun DetailRow(title: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title,
            fontSize = 14.sp,
            color = AppColors.Sub
        )
        Text(
            text = value,
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.Ink
        )
    }
}