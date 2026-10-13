package com.together.app.modules.login.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.login.LoginViewModel

/**
 * 验证码输入页：4 格自动跳转 + 倒计时 + 下一步（注册流程）
 * 对齐 iOS VerifyCodeViewController
 */
@Composable
fun VerifyCodeScreen(
    phone: String,
    onLoginSuccess: () -> Unit,
    viewModel: LoginViewModel = viewModel()
) {
    val uiState by viewModel.uiState
    val context = LocalContext.current

    // 4 格验证码
    val codes = remember { List(4) { mutableStateOf("") } }
    val focusRequesters = remember { List(4) { FocusRequester() } }
    val filled = codes.all { it.value.length == 1 }
    val currentCode = codes.joinToString("") { it.value }

    // toast
    LaunchedEffect(uiState.toast) {
        uiState.toast?.let {
            android.widget.Toast.makeText(context, it, android.widget.Toast.LENGTH_SHORT).show()
            viewModel.consumeToast()
        }
    }

    // 登录成功
    LaunchedEffect(uiState.loginSuccess) {
        if (uiState.loginSuccess) {
            onLoginSuccess()
            viewModel.consumeLoginSuccess()
        }
    }

    // 自动聚焦第一格
    LaunchedEffect(Unit) {
        focusRequesters[0].requestFocus()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
    ) {
        TogetherTopBar(title = "输入验证码", onBack = {})

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = AppDimens.Xxl)
        ) {
            Spacer(modifier = Modifier.height(48.dp))

            Text(
                text = "验证码已发送",
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.Ink
            )
            Spacer(modifier = Modifier.height(10.dp))
            Text(
                text = "已发送至 +86 $phone，请查收短信",
                fontSize = 14.sp,
                color = AppColors.Sub
            )

            Spacer(modifier = Modifier.height(40.dp))

            // 4 格验证码输入
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                codes.forEachIndexed { index, codeState ->
                    OutlinedTextField(
                        value = codeState.value,
                        onValueChange = { newValue ->
                            if (newValue.length <= 1 && newValue.all { it.isDigit() }) {
                                codeState.value = newValue
                                // 自动跳下一格
                                if (newValue.isNotEmpty() && index < 3) {
                                    focusRequesters[index + 1].requestFocus()
                                } else if (newValue.isNotEmpty() && index == 3) {
                                    // 最后一格输入完成，收起键盘
                                }
                            } else if (newValue.isEmpty()) {
                                // 删除：回退上一格
                                codeState.value = ""
                                if (index > 0) {
                                    codes[index - 1].value = ""
                                    focusRequesters[index - 1].requestFocus()
                                }
                            }
                        },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        textStyle = androidx.compose.ui.text.TextStyle(
                            fontSize = 28.sp,
                            fontWeight = FontWeight.Bold,
                            color = AppColors.Ink,
                            textAlign = TextAlign.Center
                        ),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = AppColors.Brand,
                            unfocusedBorderColor = AppColors.Line,
                            focusedContainerColor = AppColors.Surface,
                            unfocusedContainerColor = AppColors.Surface,
                            cursorColor = AppColors.Brand
                        ),
                        shape = RoundedCornerShape(AppDimens.RadiusInput),
                        modifier = Modifier
                            .weight(1f)
                            .height(56.dp)
                            .focusRequester(focusRequesters[index])
                    )
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            // 倒计时 / 重发
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center
            ) {
                if (uiState.countdown > 0) {
                    Text(
                        text = "${uiState.countdown}s后可重新发送 ·",
                        color = AppColors.Muted,
                        fontSize = 13.sp
                    )
                    Text(
                        text = "重新发送",
                        color = AppColors.Muted,
                        fontSize = 13.sp
                    )
                } else {
                    Text(
                        text = "重新发送",
                        color = AppColors.Brand,
                        fontSize = 13.sp,
                        modifier = Modifier.clickable {
                            viewModel.sendCode(phone)
                        }
                    )
                }
            }

            Spacer(modifier = Modifier.height(36.dp))

            // 下一步按钮
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp)
                    .clip(RoundedCornerShape(AppDimens.RadiusButton))
                    .background(if (filled) AppColors.Brand else AppColors.Muted)
                    .clickable(enabled = filled) {
                        if (currentCode.length == 4) {
                            viewModel.register(phone, currentCode)
                        }
                    },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "下一步",
                    color = Color.White,
                    fontSize = 17.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        // 加载中
        if (uiState.loading) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.2f)),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = AppColors.Brand)
            }
        }
    }
}