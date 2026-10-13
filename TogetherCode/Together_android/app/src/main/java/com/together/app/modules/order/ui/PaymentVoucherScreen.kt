package com.together.app.modules.order.ui

import android.net.Uri
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
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalance
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Payment
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.core.component.TogetherDivider
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.OrderItem
import com.together.app.core.model.PayMethod
import com.together.app.modules.order.OrderViewModel

/**
 * 线下付款凭证（家长端）
 * 对齐 iOS PaymentVoucherViewController
 *
 * 平台不经手学费：家长与机构线下结算后，选择付款方式、上传凭证、填写备注；
 * 机构在后台核对到账并「确认收款」后发放全部课时。
 * 现金可免凭证；微信/支付宝/银行/扫码/其他必须上传至少 1 张凭证截图。
 */
@Composable
fun PaymentVoucherScreen(
    order: OrderItem,
    onBack: () -> Unit,
    onSubmitted: () -> Unit,
    viewModel: OrderViewModel = viewModel()
) {
    val context = LocalContext.current
    val voucherState by viewModel.voucherState.collectAsState()

    // 驳回重传：预选上次选择的支付方式（凭证图需重新上传）
    var selectedMethod by remember {
        mutableStateOf(
            PayMethod.from(order.rejectedPayment?.payMethod ?: order.rejectedPayment?.channel)
                ?: PayMethod.WECHAT
        )
    }
    var pickedUris by remember { mutableStateOf<List<Uri>>(emptyList()) }
    var note by remember { mutableStateOf("") }

    // 图片选择器（最多 9 张，返回时截取剩余额度）
    val imagePicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickMultipleVisualMedia(maxItems = 9)
    ) { uris ->
        val remain = 9 - pickedUris.size
        if (uris.isNotEmpty()) pickedUris = pickedUris + uris.take(remain)
    }

    // 提交成功 → Toast + 回调 + 返回
    LaunchedEffect(voucherState.success) {
        if (voucherState.success) {
            Toast.makeText(context, "凭证已提交，等待机构确认", Toast.LENGTH_SHORT).show()
            viewModel.resetVoucherState()
            onSubmitted()
            onBack()
        }
    }

    // 提交失败 → Toast
    LaunchedEffect(voucherState.error) {
        voucherState.error?.let {
            Toast.makeText(context, it, Toast.LENGTH_SHORT).show()
            viewModel.clearVoucherError()
        }
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "线下付款", onBack = onBack)

        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(bottom = 100.dp)
        ) {
            // 1. 提示卡（驳回时红色提示 + 原因）
            TipCard(rejectReason = order.rejectedPayment?.rejectReason)
            Spacer(Modifier.height(AppDimens.S))

            // 2. 课程信息卡
            CourseInfoCard(order = order)
            Spacer(Modifier.height(AppDimens.M))

            // 3. 付款方式（6 选 1）
            SectionTitle("付款方式")
            MethodCard(selectedMethod = selectedMethod, onSelect = { selectedMethod = it })
            Spacer(Modifier.height(AppDimens.M))

            // 4. 付款凭证九宫格
            SectionTitle(voucherHeaderTitle(selectedMethod))
            VoucherGridCard(
                uris = pickedUris,
                onAdd = {
                    val remain = 9 - pickedUris.size
                    if (remain > 0) {
                        imagePicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                    } else {
                        Toast.makeText(context, "最多上传 9 张凭证", Toast.LENGTH_SHORT).show()
                    }
                },
                onRemove = { idx -> pickedUris = pickedUris.filterIndexed { i, _ -> i != idx } }
            )
            Spacer(Modifier.height(AppDimens.M))

            // 5. 备注（选填）
            SectionTitle("备注")
            NoteCard(note = note, onNoteChange = { note = it })
        }

        // 底部栏：应付金额 + 提交按钮
        BottomBar(
            amountText = order.amountText,
            submitting = voucherState.submitting,
            onSubmit = {
                if (selectedMethod.isOnline && pickedUris.isEmpty()) {
                    Toast.makeText(context, "请上传${selectedMethod.text}的付款凭证截图", Toast.LENGTH_SHORT).show()
                    return@BottomBar
                }
                order.orderId?.let {
                    viewModel.uploadAndSubmitVoucher(it, selectedMethod.code, pickedUris, note.trim().ifEmpty { null })
                }
            }
        )
    }
}

// MARK: - 区块标题

@Composable
private fun SectionTitle(text: String) {
    Text(
        text = text,
        color = AppColors.Sub,
        fontSize = 15.sp,
        modifier = Modifier.padding(start = AppDimens.L + 4.dp, bottom = AppDimens.S)
    )
}

private fun voucherHeaderTitle(method: PayMethod): String =
    if (method.isOnline) "付款凭证（必传，转账 / 付款截图，最多 9 张）"
    else "付款凭证（现金可不上传，由机构核对登记）"

// MARK: - 提示卡

@Composable
private fun TipCard(rejectReason: String?) {
    val isRejected = !rejectReason.isNullOrBlank()
    val bgColor = if (isRejected) AppColors.DangerTint else AppColors.BrandSoft
    val iconTint = if (isRejected) AppColors.Danger else AppColors.Brand
    val titleColor = if (isRejected) AppColors.Danger else AppColors.Ink
    val title = if (isRejected) "上次付款凭证未通过，请重新上传" else "线下付款 · 平台不经手学费"
    val desc = if (isRejected) {
        "原因：$rejectReason\n平台不经手学费，请与机构线下结算后重新上传付款凭证，机构确认到账后发放课时。"
    } else {
        "请与机构线下完成付款，并在此上传付款凭证；机构核对到账并确认后，课时将自动发放到孩子账户。"
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L, vertical = AppDimens.Xs)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(bgColor)
            .padding(AppDimens.L)
    ) {
        Icon(Icons.Filled.Info, contentDescription = null, tint = iconTint, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(AppDimens.S))
        Column(modifier = Modifier.weight(1f)) {
            Text(title, color = titleColor, fontSize = 14.sp, fontWeight = FontWeight.Medium)
            Spacer(Modifier.height(6.dp))
            Text(desc, color = AppColors.Sub, fontSize = 13.sp, lineHeight = 19.sp)
        }
    }
}

// MARK: - 课程信息卡

@Composable
private fun CourseInfoCard(order: OrderItem) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L, vertical = AppDimens.Xs)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.L)
    ) {
        Text(order.courseTitleWithLessons, color = AppColors.Ink, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, maxLines = 2)
        Spacer(Modifier.height(6.dp))
        Text(order.studioClassText, color = AppColors.Sub, fontSize = 13.sp, maxLines = 1)
        Spacer(Modifier.height(10.dp))
        Text("应付 ${order.amountText}", color = AppColors.Clay, fontSize = 17.sp, fontWeight = FontWeight.Bold)
    }
}

// MARK: - 付款方式图标映射（iOS SF Symbol → Material Icon）

private fun payMethodIcon(method: PayMethod): ImageVector = when (method) {
    PayMethod.CASH -> Icons.Filled.Payments
    PayMethod.WECHAT -> Icons.Filled.Chat
    PayMethod.ALIPAY -> Icons.Filled.Payment
    PayMethod.BANK -> Icons.Filled.AccountBalance
    PayMethod.QRCODE -> Icons.Filled.QrCodeScanner
    PayMethod.OTHER -> Icons.Filled.MoreHoriz
}

// MARK: - 付款方式单选卡（6 行）

@Composable
private fun MethodCard(selectedMethod: PayMethod, onSelect: (PayMethod) -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
    ) {
        PayMethod.entries.forEachIndexed { idx, method ->
            if (idx > 0) TogetherDivider(modifier = Modifier.padding(horizontal = AppDimens.L))
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onSelect(method) }
                    .padding(horizontal = AppDimens.L, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(payMethodIcon(method), contentDescription = null, tint = AppColors.Brand, modifier = Modifier.size(22.dp))
                Spacer(Modifier.width(AppDimens.M))
                Text(method.text, color = AppColors.Ink, fontSize = 15.sp, modifier = Modifier.weight(1f))
                Icon(
                    if (method == selectedMethod) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked,
                    contentDescription = null,
                    tint = if (method == selectedMethod) AppColors.Brand else AppColors.Line,
                    modifier = Modifier.size(22.dp)
                )
            }
        }
    }
}

// MARK: - 凭证九宫格

@Composable
private fun VoucherGridCard(uris: List<Uri>, onAdd: () -> Unit, onRemove: (Int) -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.L)
    ) {
        val slotCount = uris.size + if (uris.size < 9) 1 else 0
        val rows = (maxOf(slotCount, 1) + 2) / 3
        for (r in 0 until rows) {
            if (r > 0) Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                for (c in 0 until 3) {
                    val idx = r * 3 + c
                    Box(modifier = Modifier.weight(1f).aspectRatio(1f)) {
                        when {
                            idx < uris.size -> ImageSlot(uri = uris[idx], onRemove = { onRemove(idx) })
                            idx == uris.size && uris.size < 9 -> AddSlot(onAdd = onAdd)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ImageSlot(uri: Uri, onRemove: () -> Unit) {
    Box(modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(8.dp))) {
        AsyncImage(
            model = uri,
            contentDescription = null,
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Crop
        )
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(4.dp)
                .size(22.dp)
                .clip(CircleShape)
                .background(Color.Black.copy(alpha = 0.35f))
                .clickable(onClick = onRemove),
            contentAlignment = Alignment.Center
        ) {
            Icon(Icons.Filled.Close, contentDescription = "删除", tint = Color.White, modifier = Modifier.size(14.dp))
        }
    }
}

@Composable
private fun AddSlot(onAdd: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(8.dp))
            .background(AppColors.SurfaceAlt)
            .border(1.dp, AppColors.Line, RoundedCornerShape(8.dp))
            .clickable(onClick = onAdd),
        contentAlignment = Alignment.Center
    ) {
        Icon(Icons.Filled.PhotoCamera, contentDescription = "添加凭证", tint = AppColors.Muted)
    }
}

// MARK: - 备注

@Composable
private fun NoteCard(note: String, onNoteChange: (String) -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.L, vertical = 6.dp)
    ) {
        OutlinedTextField(
            value = note,
            onValueChange = onNoteChange,
            modifier = Modifier.fillMaxWidth(),
            placeholder = { Text("选填：付款时间、转账姓名、备注说明等", color = AppColors.Muted, fontSize = 14.sp) },
            maxLines = 3,
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = Color.Transparent,
                unfocusedBorderColor = Color.Transparent,
                focusedContainerColor = Color.Transparent,
                unfocusedContainerColor = Color.Transparent,
                cursorColor = AppColors.Brand,
                focusedTextColor = AppColors.Ink,
                unfocusedTextColor = AppColors.Ink
            )
        )
    }
}

// MARK: - 底部栏

@Composable
private fun BottomBar(amountText: String, submitting: Boolean, onSubmit: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.L, vertical = AppDimens.M),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text("应付 $amountText", color = AppColors.Ink, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
        Box(
            modifier = Modifier
                .width(140.dp)
                .height(44.dp)
                .clip(RoundedCornerShape(22.dp))
                .background(if (submitting) AppColors.Muted else AppColors.Brand)
                .clickable(enabled = !submitting, onClick = onSubmit),
            contentAlignment = Alignment.Center
        ) {
            Text(
                if (submitting) "提交中..." else "提交凭证",
                color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Medium
            )
        }
    }
}