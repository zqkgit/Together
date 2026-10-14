package com.together.app.modules.mine.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material.icons.filled.Headphones
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.together.app.app.TogetherApplication
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import kotlinx.coroutines.launch

/**
 * 设置页（对齐 iOS SettingsViewController）
 * 三组列表 + 退出登录
 */
@Composable
fun SettingsScreen(
    onBack: () -> Unit = {},
    onEditProfile: () -> Unit = {},
    onAccountSecurity: () -> Unit = {},
    onWallet: () -> Unit = {},
    onAbout: () -> Unit = {},
    onLoggedOut: () -> Unit = {}
) {
    val context = LocalContext.current
    val app = context.applicationContext as TogetherApplication
    val tokenStore = app.tokenStore
    val scope = rememberCoroutineScope()

    var showLogoutDialog by remember { mutableStateOf(false) }
    var showServiceDialog by remember { mutableStateOf(false) }
    var notificationEnabled by remember { mutableStateOf(true) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
    ) {
        TogetherTopBar(title = "设置", onBack = onBack)

        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = AppDimens.L)
        ) {
            Spacer(modifier = Modifier.height(AppDimens.S))

            // 第一组：个人资料 / 账号与安全
            SettingsGroup {
                SettingsRow(Icons.Filled.Person, "个人资料", onClick = onEditProfile)
                SettingsRow(Icons.Filled.Lock, "账号与安全", onClick = onAccountSecurity)
            }

            Spacer(modifier = Modifier.height(AppDimens.M))

            // 第二组：消息通知 / 支付与钱包
            SettingsGroup {
                SettingsRow(Icons.Filled.Notifications, "消息通知", hasSwitch = true,
                    switchValue = notificationEnabled,
                    onSwitchChange = { notificationEnabled = it }
                )
                SettingsRow(Icons.Filled.CreditCard, "支付与钱包", onClick = onWallet)
            }

            Spacer(modifier = Modifier.height(AppDimens.M))

            // 第三组：关于艺启 / 联系客服
            SettingsGroup {
                SettingsRow(Icons.Filled.Info, "关于艺启", value = "v1.0", onClick = onAbout)
                SettingsRow(Icons.Filled.Headphones, "联系客服", onClick = { showServiceDialog = true })
            }

            Spacer(modifier = Modifier.height(AppDimens.Xl))

            // 退出登录按钮
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(AppColors.Surface)
                    .clickable { showLogoutDialog = true },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "退出登录",
                    color = Color(0xFFE5484D),
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }

    // 退出登录确认弹窗
    if (showLogoutDialog) {
        AlertDialog(
            onDismissRequest = { showLogoutDialog = false },
            title = { Text("退出登录", fontWeight = FontWeight.Bold) },
            text = { Text("确定要退出当前账号吗？") },
            confirmButton = {
                TextButton(onClick = {
                    showLogoutDialog = false
                    scope.launch {
                        tokenStore.clear()
                        onLoggedOut()
                    }
                }) {
                    Text("退出", color = Color(0xFFE5484D))
                }
            },
            dismissButton = {
                TextButton(onClick = { showLogoutDialog = false }) {
                    Text("取消", color = AppColors.Sub)
                }
            },
            containerColor = AppColors.Surface
        )
    }

    // 联系客服弹窗
    if (showServiceDialog) {
        AlertDialog(
            onDismissRequest = { showServiceDialog = false },
            title = { Text("联系客服", fontWeight = FontWeight.Bold) },
            text = { Text("客服微信：yiqi_kefu\n服务时间：9:00 - 21:00") },
            confirmButton = {
                TextButton(onClick = { showServiceDialog = false }) {
                    Text("知道了", color = AppColors.Brand)
                }
            },
            containerColor = AppColors.Surface
        )
    }
}

// MARK: - 设置分组

@Composable
private fun SettingsGroup(content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
    ) {
        content()
    }
}

// MARK: - 设置行

@Composable
private fun SettingsRow(
    icon: ImageVector,
    title: String,
    value: String? = null,
    hasSwitch: Boolean = false,
    switchValue: Boolean = true,
    onSwitchChange: (Boolean) -> Unit = {},
    onClick: () -> Unit = {}
) {
    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(54.dp)
                .clickable(enabled = !hasSwitch, onClick = onClick)
                .padding(horizontal = AppDimens.CardInner),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                icon,
                contentDescription = title,
                tint = AppColors.Brand,
                modifier = Modifier.size(22.dp)
            )
            Spacer(modifier = Modifier.width(AppDimens.M))
            Text(
                text = title,
                color = AppColors.Ink,
                fontSize = 15.sp,
                modifier = Modifier.weight(1f)
            )
            if (hasSwitch) {
                Switch(
                    checked = switchValue,
                    onCheckedChange = onSwitchChange,
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = Color.White,
                        checkedTrackColor = AppColors.Brand
                    )
                )
            } else {
                if (value != null) {
                    Text(
                        text = value,
                        color = AppColors.Sub,
                        fontSize = 13.sp
                    )
                    Spacer(modifier = Modifier.width(AppDimens.S))
                }
                Icon(
                    Icons.Filled.ChevronRight,
                    contentDescription = null,
                    tint = AppColors.Line,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
        // 底部分隔线（缩进 48）
        Box(
            modifier = Modifier
                .padding(start = 48.dp)
                .fillMaxWidth()
                .height(0.5.dp)
                .background(AppColors.Line)
        )
    }
}

// MARK: - 关于艺启

/**
 * 关于艺启页（对齐 iOS AboutViewController）
 */
@Composable
fun AboutScreen(onBack: () -> Unit = {}) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
            .navigationBarsPadding()
    ) {
        TogetherTopBar(title = "关于艺启", onBack = onBack)

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = 56.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // 艺 icon
            Box(
                modifier = Modifier
                    .size(64.dp)
                    .clip(RoundedCornerShape(24.dp))
                    .background(AppColors.Brand),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "艺",
                    color = Color.White,
                    fontSize = 34.sp,
                    fontWeight = FontWeight.Bold
                )
            }
            Spacer(modifier = Modifier.height(AppDimens.M))
            Text(
                text = "艺启",
                color = AppColors.Ink,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(AppDimens.S))
            Text(
                text = "v1.0.0",
                color = AppColors.Sub,
                fontSize = 13.sp
            )
            Spacer(modifier = Modifier.height(AppDimens.Xl))
            Text(
                text = "让每个孩子都能遇见好的艺术启蒙",
                color = AppColors.Sub,
                fontSize = 13.sp,
                textAlign = TextAlign.Center
            )
        }
    }
}