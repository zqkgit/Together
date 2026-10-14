package com.together.app.modules.studio.ui

import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.TextButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.core.component.TogetherAvatar
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.component.EmptyStateView
import com.together.app.core.component.ErrorView
import com.together.app.core.component.LoadingView
import com.together.app.core.component.resolveImageUrl
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.PayMethod
import com.together.app.modules.studio.StudioViewModel
import com.together.app.services.StudioService
import kotlinx.coroutines.launch

/**
 * 工作室「退款审核」页（对齐 iOS StudioRefundViewController）
 *
 * 状态分段：待审核(0) / 待确认(1) / 已驳回(2) / 已退款(3)
 * - 待审核：同意退款（选退款方式+上传凭证）/ 拒绝并留言
 * - 待确认：线下打款后「确认已打款」
 */
@Composable
fun StudioRefundScreen(
    initialStatus: Int = 0,
    onBack: () -> Unit = {},
    viewModel: StudioViewModel = viewModel()
) {
    val state by viewModel.refundState.collectAsState()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var approveTarget by remember { mutableStateOf<StudioService.StudioRefund?>(null) }
    var rejectTarget by remember { mutableStateOf<StudioService.StudioRefund?>(null) }
    var confirmTarget by remember { mutableStateOf<StudioService.StudioRefund?>(null) }
    var previewVouchers by remember { mutableStateOf<List<String>?>(null) }
    var uploadingVoucher by remember { mutableStateOf(false) }
    var pendingRefund by remember { mutableStateOf<StudioService.StudioRefund?>(null) }
    var pendingMethod by remember { mutableStateOf<PayMethod?>(null) }

    LaunchedEffect(Unit) {
        val tab = StudioViewModel.RefundTab.entries.firstOrNull { it.status == initialStatus }
            ?: StudioViewModel.RefundTab.PENDING
        viewModel.loadRefunds(tab)
    }

    val imagePicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickMultipleVisualMedia(maxItems = 9)
    ) { uris ->
        val refund = pendingRefund
        val method = pendingMethod
        pendingRefund = null
        pendingMethod = null
        if (uris.isNotEmpty() && refund != null && method != null) {
            scope.launch {
                uploadingVoucher = true
                try {
                    val urls = viewModel.uploadImages(uris, "refund")
                    if (urls.isEmpty()) {
                        Toast.makeText(context, "凭证上传失败", Toast.LENGTH_SHORT).show()
                    } else {
                        viewModel.approveRefund(refund.refundId, method.code, urls) { msg ->
                            Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
                        }
                    }
                } catch (e: Exception) {
                    Toast.makeText(context, e.message ?: "凭证上传失败", Toast.LENGTH_SHORT).show()
                }
                uploadingVoucher = false
            }
        }
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "退款审核", onBack = onBack)

        RefundTabChipRow(
            selectedTab = state.selectedTab,
            onSelect = viewModel::selectRefundTab
        )

        Box(modifier = Modifier.weight(1f)) {
            when {
                state.loading && state.refunds.isEmpty() -> LoadingView()
                state.error != null && state.refunds.isEmpty() -> ErrorView(
                    message = state.error!!,
                    onRetry = { viewModel.loadRefunds() }
                )
                state.refunds.isEmpty() -> EmptyStateView(message = state.selectedTab.emptyText)
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(horizontal = AppDimens.M, vertical = AppDimens.Xs)
                ) {
                    items(state.refunds, key = { it.refundId }) { refund ->
                        RefundCard(
                            refund = refund,
                            onApprove = { approveTarget = refund },
                            onReject = { rejectTarget = refund },
                            onConfirm = { confirmTarget = refund },
                            onVoucherTap = { previewVouchers = it }
                        )
                    }
                }
            }
        }
    }

    if (uploadingVoucher) {
        Box(
            modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.4f)),
            contentAlignment = Alignment.Center
        ) {
            CircularProgressIndicator(color = AppColors.Brand)
        }
    }

    approveTarget?.let { refund ->
        MethodSelectDialog(
            onDismiss = { approveTarget = null },
            onSelect = { method ->
                approveTarget = null
                if (method == PayMethod.CASH) {
                    viewModel.approveRefund(refund.refundId, method.code, null) { msg ->
                        Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
                    }
                } else {
                    pendingRefund = refund
                    pendingMethod = method
                    imagePicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                }
            }
        )
    }

    rejectTarget?.let { refund ->
        RejectReasonDialog(
            onDismiss = { rejectTarget = null },
            onConfirm = { reason ->
                rejectTarget = null
                viewModel.rejectRefund(refund.refundId, reason) { msg ->
                    Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
                }
            }
        )
    }

    confirmTarget?.let { refund ->
        AlertDialog(
            onDismissRequest = { confirmTarget = null },
            title = { Text("确认已打款", fontWeight = FontWeight.SemiBold) },
            text = { Text("确认已向「${refund.parentName}」完成退款 ${refund.amountText}？\n确认后将扣减相应课时，不可撤销。") },
            confirmButton = {
                TextButton(onClick = {
                    confirmTarget = null
                    viewModel.confirmRefundPayout(refund.refundId) { msg ->
                        Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
                    }
                }) { Text("确认打款", color = AppColors.Brand) }
            },
            dismissButton = {
                TextButton(onClick = { confirmTarget = null }) { Text("取消") }
            }
        )
    }

    previewVouchers?.let { urls ->
        VoucherPreviewDialog(urls = urls, onDismiss = { previewVouchers = null })
    }
}

// MARK: - Tab 横滑行

@Composable
private fun RefundTabChipRow(
    selectedTab: StudioViewModel.RefundTab,
    onSelect: (StudioViewModel.RefundTab) -> Unit
) {
    LazyRow(
        modifier = Modifier.fillMaxWidth(),
        contentPadding = PaddingValues(horizontal = AppDimens.L, vertical = AppDimens.S),
        horizontalArrangement = Arrangement.spacedBy(AppDimens.S)
    ) {
        items(StudioViewModel.RefundTab.entries) { tab ->
            val selected = tab == selectedTab
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(AppDimens.RadiusTag))
                    .background(if (selected) AppColors.Brand else AppColors.SurfaceAlt)
                    .clickable { onSelect(tab) }
                    .padding(horizontal = AppDimens.M, vertical = 6.dp)
            ) {
                Text(
                    text = tab.title,
                    color = if (selected) Color.White else AppColors.Sub,
                    fontSize = 13.sp,
                    fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal
                )
            }
        }
    }
}

// MARK: - 退款卡片

@Composable
private fun RefundCard(
    refund: StudioService.StudioRefund,
    onApprove: () -> Unit,
    onReject: () -> Unit,
    onConfirm: () -> Unit,
    onVoucherTap: (List<String>) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.L)
    ) {
        // 头部：头像 / 家长称呼 / 金额
        Row(verticalAlignment = Alignment.CenterVertically) {
            TogetherAvatar(url = refund.parentAvatar, name = refund.parentName, size = 40.dp)
            Spacer(modifier = Modifier.width(AppDimens.M))
            Text(
                text = refund.parentName,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink,
                maxLines = 1,
                modifier = Modifier.weight(1f)
            )
            // 金额：¥ 小字 + 数字加粗（红色）
            val amountText = refund.amountText
            Row(verticalAlignment = Alignment.Top) {
                if (amountText.startsWith("¥")) {
                    Text(
                        text = "¥",
                        fontSize = 12.sp,
                        color = AppColors.Danger,
                        modifier = Modifier.padding(top = 2.dp)
                    )
                    Text(
                        text = amountText.substring(1),
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Bold,
                        color = AppColors.Danger
                    )
                } else {
                    Text(
                        text = amountText,
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Bold,
                        color = AppColors.Danger
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(AppDimens.M))

        // 明细 key-value
        val kvRows = buildList {
            add("申请时间" to refundTimeText(refund.createdAt))
            add("退款课程" to refund.courseTitle)
            add("剩余课时" to "${refund.remaining}/${refund.totalLessons} 节")
            add("退款原因" to (refund.reasonText.ifEmpty { "家长未填写" }))
            when (refund.status) {
                2 -> {
                    if (refund.rejectReasonText.isNotEmpty()) {
                        add("驳回原因" to refund.rejectReasonText)
                    }
                }
                1, 3 -> {
                    if (refund.refundMethodText.isNotEmpty()) {
                        add("退款方式" to refund.refundMethodText)
                    }
                    if (refund.voucherImageList.isNotEmpty()) {
                        add("打款凭证" to "__VOUCHERS__")
                    }
                }
            }
        }
        kvRows.forEachIndexed { index, (key, value) ->
            val isLast = index == kvRows.size - 1
            if (value == "__VOUCHERS__") {
                RefundKVRow(
                    key = key,
                    showSeparator = !isLast
                ) {
                    VoucherThumbRow(
                        images = refund.voucherImageList,
                        onTap = onVoucherTap
                    )
                }
            } else {
                val isRejectReason = key == "驳回原因"
                RefundKVRow(
                    key = key,
                    showSeparator = !isLast
                ) {
                    Text(
                        text = value,
                        fontSize = 13.sp,
                        color = if (isRejectReason) AppColors.Danger else AppColors.Ink
                    )
                }
            }
        }

        // 操作区
        when (refund.status) {
            0 -> {
                Spacer(modifier = Modifier.height(AppDimens.L))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(AppDimens.M)
                ) {
                    // 拒绝并留言（描边）
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(40.dp)
                            .clip(RoundedCornerShape(20.dp))
                            .background(AppColors.Surface)
                            .border(1.dp, AppColors.Line, RoundedCornerShape(20.dp))
                            .clickable { onReject() },
                        contentAlignment = Alignment.Center
                    ) {
                        Text("拒绝并留言", fontSize = 15.sp, color = AppColors.Ink)
                    }
                    // 同意退款（实心）
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(40.dp)
                            .clip(RoundedCornerShape(20.dp))
                            .background(AppColors.Brand)
                            .clickable { onApprove() },
                        contentAlignment = Alignment.Center
                    ) {
                        Text("同意退款", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
                    }
                }
            }
            1 -> {
                Spacer(modifier = Modifier.height(AppDimens.L))
                Text(
                    text = "审核已通过，请在线下完成打款后点击确认",
                    fontSize = 12.sp,
                    color = AppColors.Success
                )
                Spacer(modifier = Modifier.height(AppDimens.S))
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(40.dp)
                        .clip(RoundedCornerShape(20.dp))
                        .background(AppColors.Brand)
                        .clickable { onConfirm() },
                    contentAlignment = Alignment.Center
                ) {
                    Text("确认已打款", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
                }
            }
            3 -> {
                Spacer(modifier = Modifier.height(AppDimens.L))
                Text(
                    text = "已退款",
                    fontSize = 12.sp,
                    color = AppColors.Success,
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(AppColors.SuccessTint)
                        .padding(horizontal = 12.dp, vertical = 4.dp)
                )
            }
        }
    }
}

// MARK: - 明细 key-value 行

@Composable
private fun RefundKVRow(
    key: String,
    showSeparator: Boolean = true,
    content: @Composable () -> Unit
) {
    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 10.dp)
        ) {
            Text(
                text = key,
                fontSize = 13.sp,
                color = AppColors.Muted,
                modifier = Modifier.width(64.dp)
            )
            Spacer(modifier = Modifier.width(AppDimens.M))
            Box(modifier = Modifier.weight(1f)) {
                content()
            }
        }
        if (showSeparator) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(0.5.dp)
                    .background(AppColors.Line)
            )
        }
    }
}

// MARK: - 凭证缩略图行

@Composable
private fun VoucherThumbRow(
    images: List<String>,
    onTap: (List<String>) -> Unit
) {
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        images.take(5).forEach { url ->
            AsyncImage(
                model = resolveImageUrl(url),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(44.dp)
                    .clip(RoundedCornerShape(6.dp))
                    .background(AppColors.Bg)
                    .clickable { onTap(images) }
            )
        }
        if (images.size > 5) {
            Text(
                text = "+${images.size - 5}",
                fontSize = 11.sp,
                color = AppColors.Muted,
                modifier = Modifier.align(Alignment.CenterVertically)
            )
        }
    }
}

// MARK: - 退款方式选择弹窗

@Composable
private fun MethodSelectDialog(
    onDismiss: () -> Unit,
    onSelect: (PayMethod) -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("选择退款方式", fontWeight = FontWeight.SemiBold) },
        text = {
            Column {
                Text(
                    text = "线下结算，平台不经手资金",
                    fontSize = 12.sp,
                    color = AppColors.Muted
                )
                Spacer(modifier = Modifier.height(AppDimens.M))
                PayMethod.entries.forEach { method ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(AppDimens.RadiusTag))
                            .clickable { onSelect(method) }
                            .padding(vertical = 12.dp, horizontal = AppDimens.S),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = method.text,
                            fontSize = 15.sp,
                            color = AppColors.Ink,
                            modifier = Modifier.weight(1f)
                        )
                        if (method.isOnline) {
                            Text(
                                text = "需上传凭证",
                                fontSize = 11.sp,
                                color = AppColors.Muted
                            )
                        } else {
                            Text(
                                text = "无需凭证",
                                fontSize = 11.sp,
                                color = AppColors.Muted
                            )
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text("取消") }
        }
    )
}

// MARK: - 拒绝原因输入弹窗

@Composable
private fun RejectReasonDialog(
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit
) {
    var reason by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("拒绝并留言", fontWeight = FontWeight.SemiBold) },
        text = {
            OutlinedTextField(
                value = reason,
                onValueChange = { if (it.length <= 100) reason = it },
                placeholder = { Text("请填写拒绝原因（家长可见）") },
                modifier = Modifier.fillMaxWidth(),
                maxLines = 3,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Text)
            )
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val trimmed = reason.trim()
                    if (trimmed.isEmpty()) return@TextButton
                    onConfirm(trimmed)
                }
            ) { Text("确认拒绝", color = AppColors.Danger) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("取消") }
        }
    )
}

// MARK: - 凭证全屏预览

@Composable
private fun VoucherPreviewDialog(
    urls: List<String>,
    onDismiss: () -> Unit
) {
    if (urls.isEmpty()) return
    val pagerState = rememberPagerState(pageCount = { urls.size })
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.92f))
            .clickable { onDismiss() }
    ) {
        HorizontalPager(state = pagerState, modifier = Modifier.fillMaxSize()) { page ->
            AsyncImage(
                model = resolveImageUrl(urls[page]),
                contentDescription = null,
                contentScale = ContentScale.Fit,
                modifier = Modifier.fillMaxSize()
            )
        }
        // 页码
        if (urls.size > 1) {
            Text(
                text = "${pagerState.currentPage + 1}/${urls.size}",
                color = Color.White,
                fontSize = 14.sp,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 40.dp)
            )
        }
        // 关闭按钮
        Text(
            text = "✕",
            color = Color.White,
            fontSize = 20.sp,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(top = 48.dp, end = AppDimens.L)
                .clip(RoundedCornerShape(50))
                .clickable { onDismiss() }
                .padding(12.dp)
        )
    }
}

// MARK: - 申请时间格式化

/** 今天 HH:mm / 昨天 HH:mm / 本周 周X HH:mm / 今年 MM-dd HH:mm / 更早 yyyy-MM-dd */
private fun refundTimeText(iso: String?): String {
    if (iso.isNullOrBlank()) return ""
    val dateTime = try {
        java.time.OffsetDateTime.parse(iso).toLocalDateTime()
    } catch (_: Exception) {
        try {
            java.time.LocalDateTime.parse(iso)
        } catch (_: Exception) {
            return iso.take(16).replace("T", " ")
        }
    }
    val now = java.time.LocalDateTime.now()
    val today = now.toLocalDate()
    val date = dateTime.toLocalDate()
    val timeFmt = java.time.format.DateTimeFormatter.ofPattern("HH:mm")
    val weekName = when (date.dayOfWeek) {
        java.time.DayOfWeek.MONDAY -> "周一"
        java.time.DayOfWeek.TUESDAY -> "周二"
        java.time.DayOfWeek.WEDNESDAY -> "周三"
        java.time.DayOfWeek.THURSDAY -> "周四"
        java.time.DayOfWeek.FRIDAY -> "周五"
        java.time.DayOfWeek.SATURDAY -> "周六"
        java.time.DayOfWeek.SUNDAY -> "周日"
    }
    val mondayThisWeek = today.with(java.time.DayOfWeek.MONDAY)
    return when {
        date.isEqual(today) -> "今天 ${dateTime.format(timeFmt)}"
        date.isEqual(today.minusDays(1)) -> "昨天 ${dateTime.format(timeFmt)}"
        !date.isBefore(mondayThisWeek) && date.year == today.year -> "本周 $weekName ${dateTime.format(timeFmt)}"
        date.year == today.year -> dateTime.format(java.time.format.DateTimeFormatter.ofPattern("MM-dd HH:mm"))
        else -> dateTime.format(java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-dd"))
    }
}