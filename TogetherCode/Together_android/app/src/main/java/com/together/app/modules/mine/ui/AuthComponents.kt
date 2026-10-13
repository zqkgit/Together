package com.together.app.modules.mine.ui

import android.content.Context
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.together.app.core.component.TogetherTag
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import kotlinx.serialization.json.JsonObject
import java.io.File

// MARK: - 认证导航缓存（页面间传递 status / reason / apply）

/**
 * 认证页导航缓存（对齐 iOS TeacherAuthViewController(status:reason:apply:) 初始化）
 * MineViewModel.handleNeedAuth 查询状态后写入，认证页读取后清除
 */
object AuthNavCache {
    var status: String = "unauth"
    var reason: String? = null
    var applyData: JsonObject? = null

    fun set(status: String, reason: String?, apply: JsonObject?) {
        this.status = status
        this.reason = reason
        this.applyData = apply
    }

    fun consume(): Triple<String, String?, JsonObject?> {
        val result = Triple(status, reason, applyData)
        return result
    }
}

// MARK: - 审核中页面（对齐 iOS showPendingView）

@Composable
fun AuthPendingView(
    title: String,
    desc: String,
    onDone: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
            .padding(horizontal = AppDimens.L),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(Modifier.height(96.dp))
        Icon(
            imageVector = Icons.Filled.Schedule,
            contentDescription = null,
            tint = AppColors.Brand,
            modifier = Modifier.size(64.dp)
        )
        Spacer(Modifier.height(AppDimens.M))
        Text(
            text = title,
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.Ink
        )
        Spacer(Modifier.height(AppDimens.M))
        Text(
            text = desc,
            fontSize = 14.sp,
            color = AppColors.Sub,
            lineHeight = 21.sp,
            modifier = Modifier.padding(horizontal = 32.dp)
        )
        Spacer(Modifier.height(32.dp))

        // 步骤条
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            listOf("已提交", "平台审核中", "等待结果").forEachIndexed { index, step ->
                val active = index < 2
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(
                        modifier = Modifier
                            .size(12.dp)
                            .clip(CircleShape)
                            .background(if (active) AppColors.Brand else AppColors.SurfaceAlt)
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        text = step,
                        fontSize = 11.sp,
                        color = if (active) AppColors.Brand else AppColors.Sub
                    )
                }
            }
        }

        Spacer(Modifier.weight(1f))

        Button(
            onClick = onDone,
            modifier = Modifier
                .fillMaxWidth()
                .height(44.dp),
            shape = RoundedCornerShape(22.dp),
            colors = ButtonDefaults.buttonColors(containerColor = AppColors.Brand)
        ) {
            Text("知道了", fontSize = 17.sp, color = Color.White)
        }
        Spacer(Modifier.height(AppDimens.L))
    }
}

// MARK: - 驳回提示条

@Composable
fun AuthRejectBar(reason: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.WarnTint)
            .padding(AppDimens.CardInner),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Filled.Warning,
            contentDescription = null,
            tint = Color(0xFFF59E0B),
            modifier = Modifier.size(18.dp)
        )
        Spacer(Modifier.width(AppDimens.S))
        Text(
            text = "上次被驳回：$reason",
            fontSize = 13.sp,
            color = AppColors.Ink,
            lineHeight = 19.sp
        )
    }
}

// MARK: - 说明卡

@Composable
fun AuthHeroCard(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, desc: String) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.L)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = AppColors.Brand,
                modifier = Modifier.size(22.dp)
            )
            Spacer(Modifier.width(AppDimens.S))
            Text(
                text = title,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink
            )
        }
        Spacer(Modifier.height(AppDimens.S))
        Text(
            text = desc,
            fontSize = 13.sp,
            color = AppColors.Sub,
            lineHeight = 19.sp
        )
    }
}

// MARK: - 表单卡片容器

@Composable
fun AuthFormCard(content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(vertical = AppDimens.L)
    ) {
        content()
    }
}

// MARK: - 字段标题

@Composable
fun FieldLabel(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text,
        fontSize = 13.sp,
        color = AppColors.Sub,
        modifier = modifier.padding(horizontal = AppDimens.L)
    )
}

// MARK: - 文本输入行（对齐 iOS addField）

@Composable
fun AuthFieldRow(
    title: String,
    value: String,
    placeholder: String,
    onValueChange: (String) -> Unit,
    singleLine: Boolean = true,
    keyboardType: androidx.compose.ui.text.input.KeyboardType = androidx.compose.ui.text.input.KeyboardType.Text
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        FieldLabel(title)
        Spacer(Modifier.height(AppDimens.S))
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            placeholder = {
                Text(placeholder, fontSize = 15.sp, color = AppColors.Muted)
            },
            singleLine = singleLine,
            keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType = keyboardType),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = AppColors.Brand,
                unfocusedBorderColor = AppColors.Line,
                focusedTextColor = AppColors.Ink,
                unfocusedTextColor = AppColors.Ink
            ),
            shape = RoundedCornerShape(10.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = AppDimens.L)
        )
    }
}

// MARK: - 多行文本（简介，100 字限制）

@Composable
fun AuthIntroField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String = "一句话介绍..."
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        OutlinedTextField(
            value = value,
            onValueChange = { if (it.length <= 100) onValueChange(it) },
            placeholder = {
                Text(placeholder, fontSize = 14.sp, color = AppColors.Muted)
            },
            minLines = 3,
            maxLines = 4,
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = AppColors.Brand,
                unfocusedBorderColor = AppColors.Line,
                focusedTextColor = AppColors.Ink,
                unfocusedTextColor = AppColors.Ink,
                focusedContainerColor = AppColors.SurfaceAlt,
                unfocusedContainerColor = AppColors.SurfaceAlt
            ),
            shape = RoundedCornerShape(10.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = AppDimens.L)
        )
        Text(
            text = "${value.length}/100",
            fontSize = 11.sp,
            color = AppColors.Sub,
            modifier = Modifier
                .fillMaxWidth()
                .padding(end = AppDimens.L, top = 4.dp),
            textAlign = androidx.compose.ui.text.style.TextAlign.Right
        )
    }
}

// MARK: - 可选标签流（单选/多选）

@Composable
fun SelectableTagFlow(
    options: List<String>,
    selected: Set<String>,
    onToggle: (String) -> Unit
) {
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(AppDimens.S),
        verticalArrangement = Arrangement.spacedBy(AppDimens.Xs),
        modifier = Modifier.padding(horizontal = AppDimens.L)
    ) {
        options.forEach { option ->
            val isSelected = option in selected
            TogetherTag(
                text = option,
                color = if (isSelected) Color.White else AppColors.Sub,
                bgColor = if (isSelected) AppColors.Brand else AppColors.SurfaceAlt,
                modifier = Modifier.clickable { onToggle(option) }
            )
        }
    }
}

// MARK: - 照片九宫格（对齐 iOS TeacherCertCell / StudioPhotoCell）

@Composable
fun PhotoGridField(
    uris: List<Uri>,
    maxCount: Int,
    onAdd: () -> Unit,
    onRemove: (Int) -> Unit
) {
    Column(modifier = Modifier.padding(horizontal = AppDimens.L)) {
        val slotCount = uris.size + if (uris.size < maxCount) 1 else 0
        val rows = (maxOf(slotCount, 1) + 2) / 3
        for (r in 0 until rows) {
            if (r > 0) Spacer(Modifier.height(8.dp))
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                for (c in 0 until 3) {
                    val idx = r * 3 + c
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .aspectRatio(1f)
                    ) {
                        when {
                            idx < uris.size -> PhotoSlot(uri = uris[idx], onRemove = { onRemove(idx) })
                            idx == uris.size && uris.size < maxCount -> AddPhotoSlot(onAdd = onAdd)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PhotoSlot(uri: Uri, onRemove: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(12.dp))
    ) {
        AsyncImage(
            model = uri,
            contentDescription = null,
            modifier = Modifier.fillMaxSize(),
            contentScale = androidx.compose.ui.layout.ContentScale.Crop
        )
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(4.dp)
                .size(24.dp)
                .clip(CircleShape)
                .background(Color.Black.copy(alpha = 0.4f))
                .clickable(onClick = onRemove),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Filled.Close,
                contentDescription = "删除",
                tint = Color.White,
                modifier = Modifier.size(14.dp)
            )
        }
    }
}

@Composable
private fun AddPhotoSlot(onAdd: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(12.dp))
            .background(AppColors.SurfaceAlt)
            .clickable(onClick = onAdd),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            Icons.Filled.Add,
            contentDescription = "添加照片",
            tint = AppColors.Sub,
            modifier = Modifier.size(28.dp)
        )
        Spacer(Modifier.height(4.dp))
        Text("添加照片", fontSize = 11.sp, color = AppColors.Sub)
    }
}

// MARK: - 提交按钮

@Composable
fun AuthSubmitButton(
    text: String,
    enabled: Boolean,
    onClick: () -> Unit
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L)
            .height(44.dp),
        shape = RoundedCornerShape(22.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = AppColors.Brand,
            disabledContainerColor = AppColors.Brand.copy(alpha = 0.5f)
        )
    ) {
        Text(text, fontSize = 17.sp, color = Color.White)
    }
}

// MARK: - Uri → File 工具

fun authUriToFile(context: Context, uri: Uri): File {
    val input = context.contentResolver.openInputStream(uri)
        ?: throw IllegalStateException("无法读取图片")
    val file = File(context.cacheDir, "auth_${System.currentTimeMillis()}_${uri.hashCode()}.jpg")
    input.use { src ->
        file.outputStream().use { dst -> src.copyTo(dst) }
    }
    return file
}