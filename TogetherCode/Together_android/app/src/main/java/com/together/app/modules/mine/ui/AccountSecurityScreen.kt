package com.together.app.modules.mine.ui

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.PersonOff
import androidx.compose.material.icons.filled.PhoneIphone
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.services.AuthService
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private val DangerRed = Color(0xFFE5484D)

/** 手机号脱敏：138****1234 */
private fun maskedPhone(phone: String): String {
    if (phone.length != 11) return phone
    return phone.substring(0, 3) + "****" + phone.substring(7)
}

/**
 * 账号与安全（对齐 iOS AccountSecurityViewController）
 */
@Composable
fun AccountSecurityScreen(
    onBack: () -> Unit = {},
    onChangePassword: () -> Unit = {},
    onChangePhone: () -> Unit = {},
    onDeactivate: () -> Unit = {}
) {
    val context = LocalContext.current
    var phone by remember { mutableStateOf("") }

    LaunchedEffect(Unit) {
        try {
            phone = AuthService.fetchMe().phone
        } catch (_: Exception) { }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
            .statusBarsPadding()
    ) {
        TogetherTopBar(title = "账号与安全", onBack = onBack)

        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = AppDimens.L)
        ) {
            Spacer(modifier = Modifier.height(AppDimens.S))
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(AppDimens.RadiusCard))
                    .background(AppColors.Surface)
            ) {
                SecurityRow(Icons.Filled.PhoneIphone, "绑定手机号",
                    value = phone.ifEmpty { null }?.let { maskedPhone(it) },
                    onClick = onChangePhone)
                SecurityRow(Icons.Filled.Lock, "修改登录密码", onClick = onChangePassword)
                SecurityRow(Icons.Filled.PersonOff, "注销账号", danger = true) {
                    // 注销确认弹窗在调用方处理
                    onDeactivate()
                }
            }
        }
    }
}

@Composable
private fun SecurityRow(
    icon: ImageVector,
    title: String,
    value: String? = null,
    danger: Boolean = false,
    onClick: () -> Unit
) {
    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(54.dp)
                .clickable(onClick = onClick)
                .padding(horizontal = AppDimens.CardInner),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(icon, contentDescription = title,
                tint = if (danger) DangerRed else AppColors.Brand,
                modifier = Modifier.size(22.dp))
            Spacer(modifier = Modifier.width(AppDimens.M))
            Text(title, color = if (danger) DangerRed else AppColors.Ink,
                fontSize = 15.sp, modifier = Modifier.weight(1f))
            if (value != null) {
                Text(value, color = AppColors.Sub, fontSize = 13.sp)
            } else {
                Icon(Icons.Filled.ChevronRight, contentDescription = null,
                    tint = AppColors.Line, modifier = Modifier.size(16.dp))
            }
        }
        Box(modifier = Modifier
            .padding(start = 48.dp)
            .fillMaxWidth()
            .height(0.5.dp)
            .background(AppColors.Line))
    }
}

// MARK: - 修改登录密码

@Composable
fun ChangePasswordScreen(onBack: () -> Unit = {}) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var currentPhone by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    var newPw by remember { mutableStateOf("") }
    var confirmPw by remember { mutableStateOf("") }
    var countdown by remember { mutableIntStateOf(0) }
    var submitting by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        try { currentPhone = AuthService.fetchMe().phone } catch (_: Exception) { }
    }
    LaunchedEffect(countdown) {
        if (countdown > 0) {
            delay(1000)
            countdown--
        }
    }

    Column(
        modifier = Modifier.fillMaxSize().background(AppColors.Bg).statusBarsPadding()
    ) {
        TogetherTopBar(title = "修改登录密码", onBack = onBack)
        Column(modifier = Modifier.weight(1f).verticalScroll(rememberScrollState())
            .padding(horizontal = AppDimens.L)) {
            Spacer(modifier = Modifier.height(AppDimens.L))
            // 当前手机号
            InfoCard("当前手机号", if (currentPhone.isEmpty()) "加载中..." else maskedPhone(currentPhone))
            Spacer(modifier = Modifier.height(AppDimens.M))
            // 验证码
            CodeFieldCard(code, { code = it }, countdown, enabled = currentPhone.isNotEmpty()) {
                scope.launch {
                    try {
                        AuthService.sendCode(currentPhone)
                        Toast.makeText(context, "验证码已发送", Toast.LENGTH_SHORT).show()
                        countdown = 60
                    } catch (e: Exception) {
                        Toast.makeText(context, e.message ?: "发送失败", Toast.LENGTH_SHORT).show()
                    }
                }
            }
            Spacer(modifier = Modifier.height(AppDimens.M))
            PwFieldCard("请输入新密码（6-20 位）", newPw) { newPw = it }
            Spacer(modifier = Modifier.height(AppDimens.M))
            PwFieldCard("请再次输入新密码", confirmPw) { confirmPw = it }
            Spacer(modifier = Modifier.height(AppDimens.S))
            Text("密码长度 6-20 位，建议包含字母、数字和符号",
                color = AppColors.Sub, fontSize = 12.sp,
                modifier = Modifier.padding(start = 4.dp))
            Spacer(modifier = Modifier.height(AppDimens.Xl))
            SubmitButton("确认修改", submitting) {
                if (code.isEmpty() || newPw.isEmpty() || confirmPw.isEmpty()) {
                    Toast.makeText(context, "请填写完整", Toast.LENGTH_SHORT).show()
                } else if (newPw != confirmPw) {
                    Toast.makeText(context, "两次输入的新密码不一致", Toast.LENGTH_SHORT).show()
                } else if (newPw.length < 6 || newPw.length > 20) {
                    Toast.makeText(context, "新密码长度需为 6-20 位", Toast.LENGTH_SHORT).show()
                } else {
                    scope.launch {
                        submitting = true
                        try {
                            AuthService.changePassword(code, newPw)
                            Toast.makeText(context, "密码已修改", Toast.LENGTH_SHORT).show()
                            delay(800); onBack()
                        } catch (e: Exception) {
                            Toast.makeText(context, e.message ?: "修改失败", Toast.LENGTH_SHORT).show()
                        }
                        submitting = false
                    }
                }
            }
        }
    }
}

// MARK: - 更换手机号

@Composable
fun ChangePhoneScreen(onBack: () -> Unit = {}) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var phone by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    var countdown by remember { mutableIntStateOf(0) }
    var submitting by remember { mutableStateOf(false) }

    LaunchedEffect(countdown) {
        if (countdown > 0) { delay(1000); countdown-- }
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg).statusBarsPadding()) {
        TogetherTopBar(title = "更换手机号", onBack = onBack)
        Column(modifier = Modifier.weight(1f).verticalScroll(rememberScrollState())
            .padding(horizontal = AppDimens.L)) {
            Spacer(modifier = Modifier.height(AppDimens.L))
            InputFieldCard("请输入新手机号", phone, KeyboardType.Number) { phone = it }
            Spacer(modifier = Modifier.height(AppDimens.M))
            CodeFieldCard(code, { code = it }, countdown, enabled = true) {
                if (phone.length != 11) {
                    Toast.makeText(context, "请输入正确的手机号", Toast.LENGTH_SHORT).show()
                } else {
                    scope.launch {
                        try {
                            AuthService.sendCode(phone)
                            Toast.makeText(context, "验证码已发送", Toast.LENGTH_SHORT).show()
                            countdown = 60
                        } catch (e: Exception) {
                            Toast.makeText(context, e.message ?: "发送失败", Toast.LENGTH_SHORT).show()
                        }
                    }
                }
            }
            Spacer(modifier = Modifier.height(AppDimens.S))
            Text("新手机号将替换当前登录手机号",
                color = AppColors.Sub, fontSize = 12.sp,
                modifier = Modifier.padding(start = 4.dp))
            Spacer(modifier = Modifier.height(AppDimens.Xl))
            SubmitButton("确认更换", submitting) {
                if (phone.length != 11 || code.isEmpty()) {
                    Toast.makeText(context, "请填写完整", Toast.LENGTH_SHORT).show()
                } else {
                    scope.launch {
                        submitting = true
                        try {
                            AuthService.changePhone(phone, code)
                            Toast.makeText(context, "手机号已更换", Toast.LENGTH_SHORT).show()
                            delay(800); onBack()
                        } catch (e: Exception) {
                            Toast.makeText(context, e.message ?: "更换失败", Toast.LENGTH_SHORT).show()
                        }
                        submitting = false
                    }
                }
            }
        }
    }
}

// MARK: - 注销账号

@Composable
fun DeactivateAccountScreen(onBack: () -> Unit = {}, onLoggedOut: () -> Unit = {}) {
    val context = LocalContext.current
    val app = context.applicationContext as com.together.app.app.TogetherApplication
    val scope = rememberCoroutineScope()
    var currentPhone by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    var countdown by remember { mutableIntStateOf(0) }
    var submitting by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        try { currentPhone = AuthService.fetchMe().phone } catch (_: Exception) { }
    }
    LaunchedEffect(countdown) {
        if (countdown > 0) { delay(1000); countdown-- }
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg).statusBarsPadding()) {
        TogetherTopBar(title = "注销账号", onBack = onBack)
        Column(modifier = Modifier.weight(1f).verticalScroll(rememberScrollState())
            .padding(horizontal = AppDimens.L)) {
            Spacer(modifier = Modifier.height(AppDimens.L))
            Text("注销后，您的账号数据（课程、订单、作品、收益等）将被停用且无法恢复。请谨慎操作。",
                color = AppColors.Sub, fontSize = 13.sp)
            Spacer(modifier = Modifier.height(AppDimens.L))
            CodeFieldCard(code, { code = it }, countdown, enabled = currentPhone.isNotEmpty()) {
                scope.launch {
                    try {
                        AuthService.sendCode(currentPhone)
                        Toast.makeText(context, "验证码已发送", Toast.LENGTH_SHORT).show()
                        countdown = 60
                    } catch (e: Exception) {
                        Toast.makeText(context, e.message ?: "发送失败", Toast.LENGTH_SHORT).show()
                    }
                }
            }
            Spacer(modifier = Modifier.height(32.dp))
            // 红色确认注销按钮
            Box(modifier = Modifier.fillMaxWidth().height(50.dp)
                .clip(RoundedCornerShape(25.dp))
                .background(DangerRed)
                .clickable {
                    if (code.isEmpty()) {
                        Toast.makeText(context, "请输入验证码", Toast.LENGTH_SHORT).show()
                    } else {
                        scope.launch {
                            submitting = true
                            try {
                                AuthService.deactivateAccount(code)
                                app.tokenStore.clear()
                                Toast.makeText(context, "账号已注销", Toast.LENGTH_SHORT).show()
                                onLoggedOut()
                            } catch (e: Exception) {
                                Toast.makeText(context, e.message ?: "注销失败", Toast.LENGTH_SHORT).show()
                            }
                            submitting = false
                        }
                    }
                },
                contentAlignment = Alignment.Center) {
                Text(if (submitting) "提交中..." else "确认注销",
                    color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Medium)
            }
        }
    }
}