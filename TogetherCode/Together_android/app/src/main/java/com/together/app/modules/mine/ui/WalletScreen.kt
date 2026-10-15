package com.together.app.modules.mine.ui

import android.app.DatePickerDialog
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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.AccountBalance
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Storefront
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import com.together.app.core.component.AppPullRefreshBox
import androidx.compose.material3.rememberModalBottomSheetState
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.component.resolveImageUrl
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.mine.CommissionNavCache
import com.together.app.modules.mine.DateRangePreset
import com.together.app.modules.mine.WalletViewModel
import com.together.app.services.CommissionService
import com.together.app.services.PayMethodOption
import java.util.Calendar

/**
 * 收益中心（对齐 iOS WalletViewController）
 * 佣金总览 + 按工作室分组领取 + 领取记录入口
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WalletScreen(
    onBack: () -> Unit,
    onOpenWithdrawals: () -> Unit,
    onOpenStudioDetail: (CommissionService.StudioGroup) -> Unit,
    onOpenWithdrawalDetail: (CommissionService.CommissionWithdrawal) -> Unit,
    viewModel: WalletViewModel = viewModel()
) {
    val state by viewModel.state.collectAsState()
    val toast by viewModel.toast.collectAsState()
    val showPaySheet by viewModel.showPayMethodSheet.collectAsState()
    val submitting by viewModel.submitting.collectAsState()

    var showDateSheet by remember { mutableStateOf(false) }
    val context = LocalContext.current

    // 首次加载
    LaunchedEffect(Unit) { viewModel.refresh() }

    // Toast
    LaunchedEffect(toast) {
        if (toast != null) {
            android.widget.Toast.makeText(
                context, toast, android.widget.Toast.LENGTH_SHORT
            ).show()
            viewModel.clearToast()
        }
    }

    // 领取成功 → 跳详情
    LaunchedEffect(Unit) {
        viewModel.navigateToDetail.collect { item ->
            CommissionNavCache.withdrawal = item
            onOpenWithdrawalDetail(item)
        }
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "收益中心", onBack = onBack)

        AppPullRefreshBox(
            isRefreshing = state.refreshing,
            onRefresh = { viewModel.refresh(silent = true) }
        ) {
            if (state.loading && state.summary == null) {
                LoadingCenter()
            } else {
                val studios = state.summary?.studios ?: emptyList()
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(
                        bottom = AppDimens.Xl
                    )
                ) {
                    // 概览卡
                    item {
                        OverviewCard(
                            summary = state.summary,
                            presetTitle = periodTitle(state),
                            onCardClick = onOpenWithdrawals,
                            onPeriodClick = { showDateSheet = true }
                        )
                    }
                    // 工作室卡片 或 空态
                    if (studios.isEmpty()) {
                        item {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(top = 24.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    Text(text = "🍃", fontSize = 40.sp)
                                    Spacer(modifier = Modifier.height(AppDimens.M))
                                    Text(
                                        text = "还没有推广收益\n分享课程或海报即可获得佣金",
                                        color = AppColors.Muted,
                                        fontSize = 14.sp,
                                        lineHeight = 22.sp
                                    )
                                }
                            }
                        }
                    } else {
                        items(studios, key = { it.studioId ?: it.name ?: java.util.UUID.randomUUID().toString() }) { group ->
                            StudioWalletCard(
                                group = group,
                                onClick = { onOpenStudioDetail(group) },
                                onWithdraw = {
                                    group.studioId?.let { viewModel.requestWithdrawSheet(it) }
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    // 时间筛选弹窗
    if (showDateSheet) {
        DateRangeSheet(
            selected = state.selectedPreset,
            onSelect = { preset ->
                showDateSheet = false
                viewModel.selectPreset(preset)
            },
            onCustomRange = { start, end ->
                viewModel.selectCustomRange(start, end)
            },
            onDismiss = { showDateSheet = false }
        )
    }

    // 收款方式弹窗
    if (showPaySheet != null) {
        PayMethodSheet(
            onSelect = { method -> viewModel.confirmWithdraw(method) },
            onDismiss = { viewModel.dismissPayMethodSheet() }
        )
    }

    // 提交中遮罩
    if (submitting) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.2f))
                .clickable(enabled = false) {},
            contentAlignment = Alignment.Center
        ) {
            CircularProgressIndicator(color = AppColors.Brand)
        }
    }
}

/** 概览卡右上角按钮文案 */
private fun periodTitle(state: WalletViewModel.WalletState): String {
    if (state.selectedPreset != DateRangePreset.Custom) return state.selectedPreset.title
    val s = state.startDate.takeLast(5)
    val e = state.endDate.takeLast(5)
    return "$s~$e"
}

// MARK: - 收益总览深色卡

@Composable
private fun OverviewCard(
    summary: CommissionService.CommissionSummary?,
    presetTitle: String,
    onCardClick: () -> Unit,
    onPeriodClick: () -> Unit
) {
    val stats = summary?.stats
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M, vertical = AppDimens.S)
            .height(156.dp)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(
                Brush.linearGradient(
                    colors = listOf(AppColors.Brand, Color(0xFF46C76D))
                )
            )
            .clickable(onClick = onCardClick)
    ) {
        Column(modifier = Modifier.padding(AppDimens.L)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "累计佣金（元）",
                    color = Color.White.copy(alpha = 0.85f),
                    fontSize = 13.sp
                )
                Spacer(modifier = Modifier.weight(1f))
                // 时间筛选按钮
                Row(
                    modifier = Modifier.clickable(onClick = onPeriodClick),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = presetTitle,
                        color = Color.White.copy(alpha = 0.7f),
                        fontSize = 11.sp
                    )
                    Icon(
                        Icons.Filled.ArrowDropDown,
                        contentDescription = null,
                        tint = Color.White.copy(alpha = 0.5f),
                        modifier = Modifier.size(14.dp)
                    )
                }
            }
            Spacer(modifier = Modifier.height(AppDimens.Xs))
            Text(
                text = CommissionService.yuan(stats?.totalCommission),
                color = Color.White,
                fontSize = 32.sp,
                fontWeight = FontWeight.Bold
            )
        }
        // 底部三列
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.BottomCenter)
                .padding(horizontal = AppDimens.L)
                .padding(bottom = AppDimens.L),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            MiniColumn("待申请", stats?.receivableCommission ?: 0.0, Modifier.weight(1f))
            MiniColumn("申请中", stats?.applyingCommission ?: 0.0, Modifier.weight(1f))
            MiniColumn("已到账", stats?.settledCommission ?: 0.0, Modifier.weight(1f))
        }
    }
}

@Composable
private fun MiniColumn(title: String, value: Double, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(text = title, color = Color.White.copy(alpha = 0.7f), fontSize = 11.sp)
        Spacer(modifier = Modifier.height(2.dp))
        Text(
            text = String.format("¥%.2f", value),
            color = Color.White,
            fontSize = 15.sp
        )
    }
}

// MARK: - 工作室收益卡

@Composable
private fun StudioWalletCard(
    group: CommissionService.StudioGroup,
    onClick: () -> Unit,
    onWithdraw: () -> Unit
) {
    val receivable = group.receivable ?: 0.0
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M, vertical = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable(onClick = onClick)
            .padding(AppDimens.L)
    ) {
        // 顶部行：封面 + 名称 + 箭头
        Row(verticalAlignment = Alignment.CenterVertically) {
            val cover = group.cover
            if (!cover.isNullOrBlank()) {
                AsyncImage(
                    model = resolveImageUrl(cover),
                    contentDescription = null,
                    modifier = Modifier
                        .size(42.dp)
                        .clip(RoundedCornerShape(AppDimens.RadiusIcon))
                        .background(AppColors.WoodSoft)
                )
            } else {
                Box(
                    modifier = Modifier
                        .size(42.dp)
                        .clip(RoundedCornerShape(AppDimens.RadiusIcon))
                        .background(AppColors.Brand),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Filled.Storefront,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
            Spacer(modifier = Modifier.width(AppDimens.M))
            Text(
                text = group.name ?: "工作室",
                style = MaterialTheme.typography.titleMedium,
                color = AppColors.Ink,
                modifier = Modifier.weight(1f)
            )
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = AppColors.Muted,
                modifier = Modifier.size(18.dp)
            )
        }
        Spacer(modifier = Modifier.height(AppDimens.M))
        HorizontalDivider(color = AppColors.Line, thickness = 0.5.dp)
        Spacer(modifier = Modifier.height(AppDimens.M))
        // 统计行：数字在上、标题在下
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            StatColumn(receivable, "待申请", Modifier.weight(1f), highlight = receivable > 0)
            StatColumn(group.applying ?: 0.0, "申请中", Modifier.weight(1f))
            StatColumn(group.settled ?: 0.0, "已到账", Modifier.weight(1f))
        }
        // 领取按钮（仅有待申请金额时显示）
        if (receivable > 0) {
            Spacer(modifier = Modifier.height(AppDimens.M))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(44.dp)
                    .clip(RoundedCornerShape(22.dp))
                    .background(AppColors.Brand)
                    .clickable(onClick = onWithdraw),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "一键领取 ${String.format("¥%.2f", receivable)}",
                    color = Color.White,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
    }
}

/** 统计列：数字在上、标题在下 */
@Composable
fun StatColumn(
    value: Double,
    title: String,
    modifier: Modifier = Modifier,
    highlight: Boolean = false
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = String.format("¥%.2f", value),
            color = if (highlight) AppColors.Clay else AppColors.Ink,
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold
        )
        Spacer(modifier = Modifier.height(3.dp))
        Text(text = title, color = AppColors.Sub, fontSize = 11.sp)
    }
}

// MARK: - 时间筛选弹窗

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DateRangeSheet(
    selected: DateRangePreset,
    onSelect: (DateRangePreset) -> Unit,
    onCustomRange: (String, String) -> Unit,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = AppColors.Surface,
        dragHandle = null
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = AppDimens.L, bottom = AppDimens.Xl)
        ) {
            Text(
                text = "选择时间范围",
                style = MaterialTheme.typography.titleMedium,
                color = AppColors.Ink,
                modifier = Modifier.padding(horizontal = AppDimens.L, vertical = AppDimens.S)
            )
            DateRangePreset.entries.forEach { preset ->
                val isSelected = preset == selected
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            if (preset == DateRangePreset.Custom) {
                                // 弹出系统日期选择器：先选开始再选结束
                                val cal = Calendar.getInstance()
                                DatePickerDialog(
                                    context,
                                    { _, y, m, d ->
                                        val start = String.format("%04d-%02d-%02d", y, m + 1, d)
                                        DatePickerDialog(
                                            context,
                                            { _, y2, m2, d2 ->
                                                val end = String.format("%04d-%02d-%02d", y2, m2 + 1, d2)
                                                onDismiss()
                                                onCustomRange(start, end)
                                            },
                                            cal.get(Calendar.YEAR),
                                            cal.get(Calendar.MONTH),
                                            cal.get(Calendar.DAY_OF_MONTH)
                                        ).apply {
                                            setTitle("选择结束日期")
                                            show()
                                        }
                                    },
                                    cal.get(Calendar.YEAR),
                                    cal.get(Calendar.MONTH),
                                    cal.get(Calendar.DAY_OF_MONTH)
                                ).apply {
                                    setTitle("选择开始日期")
                                    show()
                                }
                            } else {
                                onDismiss()
                                onSelect(preset)
                            }
                        }
                        .padding(horizontal = AppDimens.L, vertical = AppDimens.M),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = preset.title,
                        color = if (isSelected) AppColors.Brand else AppColors.Ink,
                        fontSize = 15.sp,
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                        modifier = Modifier.weight(1f)
                    )
                    if (isSelected) {
                        Text(text = "✓", color = AppColors.Brand, fontSize = 14.sp)
                    }
                }
            }
        }
    }
}

// MARK: - 收款方式弹窗

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PayMethodSheet(
    onSelect: (String) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = AppColors.Surface,
        dragHandle = null
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = AppDimens.L, bottom = AppDimens.Xl)
        ) {
            Text(
                text = "选择收款方式（线下结算，平台不经手资金）",
                style = MaterialTheme.typography.titleMedium,
                color = AppColors.Ink,
                modifier = Modifier.padding(horizontal = AppDimens.L, vertical = AppDimens.S)
            )
            PayMethodOption.all.forEach { option ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            onDismiss()
                            onSelect(option.value)
                        }
                        .padding(horizontal = AppDimens.L, vertical = AppDimens.M),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Filled.AccountBalance,
                        contentDescription = null,
                        tint = AppColors.Muted,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(AppDimens.M))
                    Text(
                        text = option.label,
                        color = AppColors.Ink,
                        fontSize = 15.sp
                    )
                }
            }
        }
    }
}

// MARK: - 加载占位

@Composable
private fun LoadingCenter() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        CircularProgressIndicator(color = AppColors.Brand)
    }
}