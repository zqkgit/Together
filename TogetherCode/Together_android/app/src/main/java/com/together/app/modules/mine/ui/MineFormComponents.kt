package com.together.app.modules.mine.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens

/**
 * 我的模块共享表单组件（对齐 iOS 账号安全/认证页表单样式）
 */

/** 信息展示卡：左标签 + 右值 */
@Composable
fun InfoCard(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.L),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, color = AppColors.Sub, fontSize = 14.sp)
        Spacer(modifier = Modifier.weight(1f))
        Text(value, color = AppColors.Ink, fontSize = 15.sp)
    }
}

/** 通用输入卡（52 高，Surface 底，RadiusInput 圆角） */
@Composable
fun InputFieldCard(
    placeholder: String,
    value: String,
    keyboardType: KeyboardType = KeyboardType.Text,
    modifier: Modifier = Modifier,
    onValueChange: (String) -> Unit
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = { Text(placeholder, color = AppColors.Muted, fontSize = 15.sp) },
        modifier = modifier.fillMaxWidth().height(52.dp),
        shape = RoundedCornerShape(12.dp),
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = AppColors.Brand,
            unfocusedBorderColor = AppColors.Line,
            focusedTextColor = AppColors.Ink,
            unfocusedTextColor = AppColors.Ink,
            focusedContainerColor = AppColors.Surface,
            unfocusedContainerColor = AppColors.Surface
        ),
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType)
    )
}

/** 密码输入卡（带遮罩） */
@Composable
fun PwFieldCard(
    placeholder: String,
    value: String,
    modifier: Modifier = Modifier,
    onValueChange: (String) -> Unit
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = { Text(placeholder, color = AppColors.Muted, fontSize = 15.sp) },
        modifier = modifier.fillMaxWidth().height(52.dp),
        shape = RoundedCornerShape(12.dp),
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = AppColors.Brand,
            unfocusedBorderColor = AppColors.Line,
            focusedTextColor = AppColors.Ink,
            unfocusedTextColor = AppColors.Ink,
            focusedContainerColor = AppColors.Surface,
            unfocusedContainerColor = AppColors.Surface
        ),
        singleLine = true,
        visualTransformation = PasswordVisualTransformation()
    )
}

/** 验证码输入卡：输入框 + 获取验证码按钮（60s 倒计时） */
@Composable
fun CodeFieldCard(
    code: String,
    onCodeChange: (String) -> Unit,
    countdown: Int,
    enabled: Boolean = true,
    onSendCode: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(AppColors.Surface),
        verticalAlignment = Alignment.CenterVertically
    ) {
        OutlinedTextField(
            value = code,
            onValueChange = onCodeChange,
            placeholder = { Text("请输入验证码", color = AppColors.Muted, fontSize = 15.sp) },
            modifier = Modifier
                .weight(1f)
                .height(52.dp)
                .padding(end = 4.dp),
            shape = RoundedCornerShape(12.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = AppColors.Line,
                unfocusedBorderColor = AppColors.Line,
                focusedTextColor = AppColors.Ink,
                unfocusedTextColor = AppColors.Ink,
                focusedContainerColor = AppColors.Surface,
                unfocusedContainerColor = AppColors.Surface
            ),
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
        )
        Text(
            text = if (countdown > 0) "${countdown}s 后重发" else "获取验证码",
            color = if (countdown > 0 || !enabled) AppColors.Sub else AppColors.Brand,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            modifier = Modifier
                .clickable(enabled = countdown <= 0 && enabled, onClick = onSendCode)
                .padding(horizontal = AppDimens.CardInner)
        )
    }
}

/** 主提交按钮（Brand 底，50 高，圆角 25） */
@Composable
fun SubmitButton(
    text: String,
    loading: Boolean = false,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(50.dp)
            .clip(RoundedCornerShape(25.dp))
            .background(AppColors.Brand)
            .clickable(enabled = !loading, onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = if (loading) "提交中..." else text,
            color = androidx.compose.ui.graphics.Color.White,
            fontSize = 16.sp,
            fontWeight = FontWeight.Medium
        )
    }
}