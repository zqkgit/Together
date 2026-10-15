package com.together.app.modules.mine.ui

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
import androidx.compose.material.icons.filled.AccountBalance
import androidx.compose.material.icons.filled.Book
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.component.resolveImageUrl
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.mine.CommissionNavCache
import com.together.app.modules.mine.StudioCommissionDetailViewModel
import com.together.app.services.CommissionService
import com.together.app.services.PayMethodOption

/**
 * 工作室佣金详情（对齐 iOS StudioCommissionDetailViewController）
 * 按「课程」维度展示——在哪个课程推广、带来多少人报名、挣了多少佣金
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StudioCommissionDetailScreen(
    onBack: () -> Unit,
    onOpenWithdrawalDetail: (CommissionService.CommissionWithdrawal) -> Unit,
    viewModel: StudioCommissionDetailViewModel = viewModel()
) {
    val state by viewModel.state.collectAsState()
    val toast by viewModel.toast.collectAsState()
    val showPaySheet by viewModel.showPayMethodSheet.collectAsState()
    val submitting by viewModel.submitting.collectAsState()

    val group = CommissionNavCache.studioGroup
    val context = LocalContext.current

    LaunchedEffect(Unit) {
        viewModel.loadRecords(group?.studioId)
    }

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

    val receivable = group?.receivable ?: 0.0

    Box(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
            TogetherTopBar(title = group?.name ?: "工作室收益", onBack = onBack)

            AppPullRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = { viewModel.loadRecords(group?.studioId, silent = true) }
            ) {
                if (state.loading && state.groups.isEmpty()) {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = AppColors.Brand)
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = androidx.compose.foundation.layout.PaddingValues(
                            top = AppDimens.S, bottom = if (receivable > 0) 80.dp else AppDimens.Xl
                        )
                    ) {
                        item { group?.let { StudioSummaryCard(it) } }
                        if (state.groups.isEmpty()) {
                            item {
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(top = 24.dp),
                                    horizontalAlignment = Alignment.CenterHorizontally
                                ) {
                                    Text(text = "🍃", fontSize = 40.sp)
                                    Spacer(modifier = Modifier.height(AppDimens.M))
                                    Text(
                                        text = "暂无课程推广",
                                        color = AppColors.Muted,
                                        fontSize = 14.sp
                                    )
                                }
                            }
                        } else {
                            items(state.groups, key = { it.course?.courseId ?: java.util.UUID.randomUUID().toString() }) { cg ->
                                CourseCommissionCard(cg)
                            }
                        }
                    }
                }
            }
        }

        // 底部一键领取（悬浮在列表底部）
        if (receivable > 0) {
            Column(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
            ) {
                HorizontalDivider(color = AppColors.Line, thickness = 0.5.dp)
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(AppColors.Surface)
                        .padding(horizontal = AppDimens.L, vertical = AppDimens.M)
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(44.dp)
                            .clip(RoundedCornerShape(22.dp))
                            .background(AppColors.Brand)
                            .clickable { viewModel.requestWithdrawSheet() },
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

    // 收款方式弹窗
    if (showPaySheet) {
        StudioPayMethodSheet(
            onSelect = { method ->
                group?.studioId?.let { viewModel.confirmWithdraw(it, method) }
            },
            onDismiss = { viewModel.dismissPayMethodSheet() }
        )
    }
}

// MARK: - 工作室汇总卡

@Composable
private fun StudioSummaryCard(group: CommissionService.StudioGroup) {
    val receivable = group.receivable ?: 0.0
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M, vertical = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.L)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            val cover = group.cover
            if (!cover.isNullOrBlank()) {
                AsyncImage(
                    model = resolveImageUrl(cover),
                    contentDescription = null,
                    modifier = Modifier
                        .size(40.dp)
                        .clip(RoundedCornerShape(AppDimens.RadiusIcon))
                        .background(AppColors.WoodSoft)
                )
            } else {
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(RoundedCornerShape(AppDimens.RadiusIcon))
                        .background(AppColors.Brand),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Filled.Storefront,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
            Spacer(modifier = Modifier.width(AppDimens.M))
            Text(
                text = group.name ?: "工作室",
                style = MaterialTheme.typography.titleMedium,
                color = AppColors.Ink
            )
        }
        Spacer(modifier = Modifier.height(AppDimens.M))
        HorizontalDivider(color = AppColors.Line, thickness = 0.5.dp)
        Spacer(modifier = Modifier.height(AppDimens.M))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            StatColumn(receivable, "待申请", Modifier.weight(1f), highlight = receivable > 0)
            StatColumn(group.applying ?: 0.0, "申请中", Modifier.weight(1f))
            StatColumn(group.settled ?: 0.0, "已到账", Modifier.weight(1f))
        }
    }
}

// MARK: - 课程佣金卡

@Composable
private fun CourseCommissionCard(cg: StudioCommissionDetailViewModel.CourseGroup) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M, vertical = AppDimens.S)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.L)
    ) {
        // 课程头部
        Row(verticalAlignment = Alignment.CenterVertically) {
            val cover = cg.course?.cover
            if (!cover.isNullOrBlank()) {
                AsyncImage(
                    model = resolveImageUrl(cover),
                    contentDescription = null,
                    modifier = Modifier
                        .size(44.dp)
                        .clip(RoundedCornerShape(AppDimens.RadiusIcon))
                        .background(AppColors.BrandSoft)
                )
            } else {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(RoundedCornerShape(AppDimens.RadiusIcon))
                        .background(AppColors.BrandSoft),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Filled.Book,
                        contentDescription = null,
                        tint = AppColors.Brand,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
            Spacer(modifier = Modifier.width(AppDimens.M))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = cg.course?.title ?: "未知课程",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.Ink,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = "带来 ${cg.count} 人报名",
                    fontSize = 12.sp,
                    color = AppColors.Sub
                )
            }
            Text(
                text = String.format("¥%.2f", cg.total),
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.Clay
            )
        }
        Spacer(modifier = Modifier.height(AppDimens.M))
        HorizontalDivider(color = AppColors.Line, thickness = 0.5.dp)
        Spacer(modifier = Modifier.height(AppDimens.S))
        // 明细行
        cg.items.forEach { item ->
            RecordRow(item)
        }
    }
}

/** 单笔佣金明细行 */
@Composable
private fun RecordRow(item: CommissionService.CommissionRecordItem) {
    val status = item.status ?: 0
    val tail = (item.orderId ?: "").takeLast(6)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(34.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "订单 ****$tail · ${(item.rate ?: 0.0).toInt()}% 返",
            fontSize = 12.sp,
            color = AppColors.Sub,
            modifier = Modifier.weight(1f)
        )
        Text(
            text = item.statusText ?: "",
            fontSize = 11.sp,
            color = when (status) {
                1 -> AppColors.Clay
                3 -> AppColors.Info
                2 -> AppColors.Success
                else -> AppColors.Sub
            }
        )
        Spacer(modifier = Modifier.width(AppDimens.M))
        Text(
            text = String.format("¥%.2f", item.amount ?: 0.0),
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.Ink,
            textAlign = TextAlign.Right,
            modifier = Modifier.width(72.dp)
        )
    }
}

// MARK: - 收款方式弹窗

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun StudioPayMethodSheet(
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