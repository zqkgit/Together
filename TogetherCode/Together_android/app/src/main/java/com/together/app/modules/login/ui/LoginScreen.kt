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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.login.LoginViewModel

/**
 * 品牌页：Logo + 标语 + 登录/注册入口 + 微信一键登录 + 协议
 * 对齐 iOS LoginViewController
 */
@Composable
fun LoginScreen(
    onNavigateToPhoneLogin: () -> Unit,
    onLoginSuccess: () -> Unit,
    viewModel: LoginViewModel = viewModel()
) {
    var agreed by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val uiState by viewModel.uiState.collectAsState()

    // toast 处理
    LaunchedEffect(uiState.toast) {
        uiState.toast?.let {
            android.widget.Toast.makeText(
                context, it, android.widget.Toast.LENGTH_SHORT
            ).show()
            viewModel.consumeToast()
        }
    }

    // 登录成功跳转
    LaunchedEffect(uiState.loginSuccess) {
        if (uiState.loginSuccess) {
            onLoginSuccess()
            viewModel.consumeLoginSuccess()
        }
    }

    // 渐变背景：绿-米白
    val gradient = Brush.verticalGradient(
        colors = listOf(
            Color(0xFFE9F1E4),
            Color(0xFFF7FAF4),
            AppColors.Bg
        ),
        startY = 0f,
        endY = 1200f
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(gradient)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = AppDimens.Xxl),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(140.dp))

            // Logo
            Box(
                modifier = Modifier
                    .size(78.dp)
                    .clip(RoundedCornerShape(22.dp))
                    .background(AppColors.Brand),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.Palette,
                    contentDescription = "艺启",
                    tint = Color.White,
                    modifier = Modifier.size(40.dp)
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            // 标题
            Text(
                text = "艺启",
                fontSize = 34.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.Ink
            )

            Spacer(modifier = Modifier.height(8.dp))

            // 标语
            Text(
                text = "让每一次创作，都被看见",
                fontSize = 14.sp,
                color = AppColors.Sub
            )

            Spacer(modifier = Modifier.weight(1f))

            // 登录/注册 按钮
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp)
                    .clip(RoundedCornerShape(AppDimens.RadiusButton))
                    .background(AppColors.Brand)
                    .clickable {
                        if (!agreed) {
                            android.widget.Toast.makeText(
                                context,
                                "请先阅读并同意用户协议与隐私政策",
                                android.widget.Toast.LENGTH_SHORT
                            ).show()
                        } else {
                            onNavigateToPhoneLogin()
                        }
                    },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "登录/注册",
                    color = Color.White,
                    fontSize = 17.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }

            Spacer(modifier = Modifier.height(14.dp))

            // 微信一键登录
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp)
                    .clip(RoundedCornerShape(AppDimens.RadiusButton))
                    .background(AppColors.Surface)
                    .border(1.dp, AppColors.Line, RoundedCornerShape(AppDimens.RadiusButton))
                    .clickable {
                        val ctx = context
                        if (!agreed) {
                            android.widget.Toast.makeText(
                                ctx, "请先阅读并同意用户协议与隐私政策", android.widget.Toast.LENGTH_SHORT
                            ).show()
                        } else {
                            android.widget.Toast.makeText(
                                ctx, "微信登录即将开放，请先使用手机号登录", android.widget.Toast.LENGTH_SHORT
                            ).show()
                        }
                    },
                contentAlignment = Alignment.Center
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(24.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(AppColors.Wechat),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "微",
                            color = Color.White,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                    Spacer(modifier = Modifier.width(10.dp))
                    Text(
                        text = "微信一键登录",
                        color = AppColors.Ink,
                        fontSize = 15.sp
                    )
                }
            }

            Spacer(modifier = Modifier.height(18.dp))

            // 协议行
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center,
                modifier = Modifier.padding(bottom = 32.dp)
            ) {
                Icon(
                    imageVector = if (agreed) Icons.Default.CheckCircle else Icons.Outlined.Circle,
                    contentDescription = "同意协议",
                    tint = AppColors.Brand,
                    modifier = Modifier
                        .size(24.dp)
                        .clickable { agreed = !agreed }
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text(
                    text = "已阅读并同意",
                    color = AppColors.Sub,
                    fontSize = 12.sp
                )
                Text(
                    text = "《用户协议》",
                    color = AppColors.Brand,
                    fontSize = 12.sp,
                    modifier = Modifier.clickable {
                        val ctx = context
                        android.widget.Toast.makeText(ctx, "《用户协议》即将开放", android.widget.Toast.LENGTH_SHORT).show()
                    }
                )
                Text(
                    text = "与",
                    color = AppColors.Sub,
                    fontSize = 12.sp
                )
                Text(
                    text = "《隐私政策》",
                    color = AppColors.Brand,
                    fontSize = 12.sp,
                    modifier = Modifier.clickable {
                        val ctx = context
                        android.widget.Toast.makeText(ctx, "《隐私政策》即将开放", android.widget.Toast.LENGTH_SHORT).show()
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