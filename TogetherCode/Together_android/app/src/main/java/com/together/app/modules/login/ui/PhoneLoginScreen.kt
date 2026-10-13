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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.login.LoginViewModel

/**
 * 手机号登录页：验证码 / 密码双模式切换
 * 对齐 iOS PhoneLoginViewController
 */
@Composable
fun PhoneLoginScreen(
    onNavigateToVerifyCode: (phone: String) -> Unit,
    onLoginSuccess: () -> Unit,
    viewModel: LoginViewModel = viewModel()
) {
    val uiState by viewModel.uiState
    val context = LocalContext.current

    var phone by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var isCodeMode by remember { mutableStateOf(true) }

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

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
    ) {
        TogetherTopBar(title = "手机号登录", onBack = {
            // 返回由 Navigation 处理
        })

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = AppDimens.Xxl)
        ) {
            Spacer(modifier = Modifier.height(40.dp))

            // 欢迎语
            Text(
                text = "欢迎来到艺启",
                fontSize = 26.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.Ink
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "选择你习惯的登录方式",
                fontSize = 14.sp,
                color = AppColors.Sub
            )

            Spacer(modifier = Modifier.height(36.dp))

            // 手机号输入框
            InputBox {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "+86",
                        fontSize = 15.sp,
                        color = AppColors.Ink,
                        modifier = Modifier.padding(start = 16.dp)
                    )
                    Box(
                        modifier = Modifier
                            .padding(horizontal = 6.dp)
                            .width(1.dp)
                            .height(28.dp)
                            .background(AppColors.Line)
                    )
                    OutlinedTextField(
                        value = phone,
                        onValueChange = { if (it.length <= 11 && it.all { c -> c.isDigit() }) phone = it },
                        placeholder = { Text("请输入手机号", color = AppColors.Muted, fontSize = 16.sp) },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        colors = transparentFieldColors(),
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // 验证码行 / 密码行（同一位置切换）
            if (isCodeMode) {
                InputBox {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        OutlinedTextField(
                            value = code,
                            onValueChange = { if (it.length <= 4 && it.all { c -> c.isDigit() }) code = it },
                            placeholder = { Text("请输入4位验证码", color = AppColors.Muted, fontSize = 16.sp) },
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                            colors = transparentFieldColors(),
                            modifier = Modifier.weight(1f)
                        )
                        Box(
                            modifier = Modifier
                                .padding(end = 6.dp)
                                .width(1.dp)
                                .height(28.dp)
                                .background(AppColors.Line)
                        )
                        Box(
                            modifier = Modifier
                                .padding(end = 16.dp)
                                .clickable(enabled = uiState.countdown == 0) {
                                    if (viewModel.isValidPhone(phone)) {
                                        viewModel.sendCode(phone)
                                    } else {
                                        android.widget.Toast.makeText(
                                            context, "请输入正确的手机号", android.widget.Toast.LENGTH_SHORT
                                        ).show()
                                    }
                                },
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = if (uiState.countdown > 0) "${uiState.countdown}s后重发"
                                       else "获取验证码",
                                color = if (uiState.countdown > 0) AppColors.Muted else AppColors.Brand,
                                fontSize = 14.sp
                            )
                        }
                    }
                }
            } else {
                InputBox {
                    OutlinedTextField(
                        value = password,
                        onValueChange = { if (it.length <= 32) password = it },
                        placeholder = { Text("请输入密码", color = AppColors.Muted, fontSize = 16.sp) },
                        singleLine = true,
                        visualTransformation = PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                        colors = transparentFieldColors(),
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }

            Spacer(modifier = Modifier.height(20.dp))

            // 分段切换
            Row {
                Text(
                    text = "验证码登录",
                    fontSize = 14.sp,
                    fontWeight = if (isCodeMode) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (isCodeMode) AppColors.Brand else AppColors.Ink,
                    modifier = Modifier.clickable { isCodeMode = true }
                )
                Spacer(modifier = Modifier.width(24.dp))
                Text(
                    text = "密码登录",
                    fontSize = 14.sp,
                    fontWeight = if (!isCodeMode) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (!isCodeMode) AppColors.Brand else AppColors.Ink,
                    modifier = Modifier.clickable { isCodeMode = false }
                )
            }

            Spacer(modifier = Modifier.height(32.dp))

            // 登录按钮
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp)
                    .clip(RoundedCornerShape(AppDimens.RadiusButton))
                    .background(AppColors.Brand)
                    .clickable {
                        if (!viewModel.isValidPhone(phone)) {
                            android.widget.Toast.makeText(
                                context, "请输入正确的手机号", android.widget.Toast.LENGTH_SHORT
                            ).show()
                            return@clickable
                        }
                        if (isCodeMode) {
                            if (code.length != 4) {
                                android.widget.Toast.makeText(
                                    context, "请输入4位验证码", android.widget.Toast.LENGTH_SHORT
                                ).show()
                                return@clickable
                            }
                            viewModel.loginWithCode(phone, code)
                        } else {
                            if (password.isEmpty()) {
                                android.widget.Toast.makeText(
                                    context, "请输入密码", android.widget.Toast.LENGTH_SHORT
                                ).show()
                                return@clickable
                            }
                            viewModel.loginPassword(phone, password)
                        }
                    },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "登 录",
                    color = Color.White,
                    fontSize = 17.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            // 注册入口
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center
            ) {
                Text(
                    text = "还没有账号？",
                    color = AppColors.Sub,
                    fontSize = 14.sp
                )
                Text(
                    text = "立即注册",
                    color = AppColors.Brand,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    modifier = Modifier.clickable {
                        if (!viewModel.isValidPhone(phone)) {
                            android.widget.Toast.makeText(
                                context, "请输入正确的手机号", android.widget.Toast.LENGTH_SHORT
                            ).show()
                            return@clickable
                        }
                        // 先发验证码，成功后进验证码页
                        viewModel.sendCode(phone)
                        onNavigateToVerifyCode(phone)
                    }
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

// MARK: - 输入框容器

@Composable
private fun InputBox(content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
            .clip(RoundedCornerShape(AppDimens.RadiusInput))
            .background(AppColors.Surface)
            .border(1.dp, AppColors.Line, RoundedCornerShape(AppDimens.RadiusInput)),
        contentAlignment = Alignment.CenterStart
    ) {
        content()
    }
}

@Composable
private fun transparentFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedBorderColor = Color.Transparent,
    unfocusedBorderColor = Color.Transparent,
    focusedContainerColor = Color.Transparent,
    unfocusedContainerColor = Color.Transparent,
    cursorColor = AppColors.Brand,
    focusedTextColor = AppColors.Ink,
    unfocusedTextColor = AppColors.Ink
)