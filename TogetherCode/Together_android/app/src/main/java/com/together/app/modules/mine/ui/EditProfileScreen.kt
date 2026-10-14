package com.together.app.modules.mine.ui

import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.together.app.app.TogetherApplication
import com.together.app.core.component.TogetherAvatar
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.network.ApiService
import com.together.app.core.network.JsonHelper.strList
import com.together.app.services.AuthService
import kotlinx.coroutines.launch
import java.io.File

/**
 * 个人资料编辑（对齐 iOS EditProfileViewController）
 * 头像 / 昵称 / 城市 / 个性签名
 */
@Composable
fun EditProfileScreen(onBack: () -> Unit = {}) {
    val context = LocalContext.current
    val app = context.applicationContext as TogetherApplication
    val tokenStore = app.tokenStore
    val scope = rememberCoroutineScope()

    var nickname by remember { mutableStateOf("") }
    var city by remember { mutableStateOf("") }
    var signature by remember { mutableStateOf("") }
    var avatarUrl by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(false) }
    var saving by remember { mutableStateOf(false) }
    var loaded by remember { mutableStateOf(false) }

    // 加载资料
    LaunchedEffect(Unit) {
        loading = true
        try {
            val profile = AuthService.fetchMe()
            nickname = profile.nickname
            city = profile.city ?: ""
            signature = profile.signature ?: ""
            avatarUrl = profile.avatar
        } catch (e: Exception) {
            Toast.makeText(context, e.message ?: "加载失败", Toast.LENGTH_SHORT).show()
        }
        loading = false
        loaded = true
    }

    // 图片选择
    val imagePicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri != null) {
            scope.launch {
                loading = true
                try {
                    val file = uriToFile(context, uri)
                    val json = ApiService.upload(listOf(file), "avatar")
                    file.delete()
                    val urls = json.strList("urls")
                    if (urls.isNotEmpty()) {
                        avatarUrl = urls.first()
                    } else {
                        Toast.makeText(context, "上传失败", Toast.LENGTH_SHORT).show()
                    }
                } catch (e: Exception) {
                    Toast.makeText(context, e.message ?: "上传失败", Toast.LENGTH_SHORT).show()
                }
                loading = false
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
    ) {
        TogetherTopBar(title = "个人资料", onBack = onBack)

        if (loading) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = AppColors.Brand)
            }
        } else if (loaded) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = AppDimens.L)
            ) {
                Spacer(modifier = Modifier.height(AppDimens.Xl))

                // 头像
                Box(
                    modifier = Modifier
                        .align(Alignment.CenterHorizontally)
                        .size(84.dp)
                        .clip(CircleShape)
                        .background(AppColors.SurfaceAlt)
                        .clickable {
                            imagePicker.launch(
                                PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                            )
                        },
                    contentAlignment = Alignment.Center
                ) {
                    TogetherAvatar(
                        url = avatarUrl,
                        name = nickname.ifEmpty { "?" },
                        size = 84.dp
                    )
                }
                Spacer(modifier = Modifier.height(AppDimens.S))
                Text(
                    text = "点击更换头像",
                    color = AppColors.Sub,
                    fontSize = 12.sp,
                    modifier = Modifier.align(Alignment.CenterHorizontally)
                )

                Spacer(modifier = Modifier.height(AppDimens.Xl))

                // 昵称
                FieldTitle("昵称")
                Spacer(modifier = Modifier.height(6.dp))
                FieldCard(placeholder = "请输入昵称", value = nickname) { nickname = it }

                Spacer(modifier = Modifier.height(AppDimens.L))

                // 城市
                FieldTitle("城市")
                Spacer(modifier = Modifier.height(6.dp))
                FieldCard(placeholder = "请输入所在城市（选填）", value = city) { city = it }

                Spacer(modifier = Modifier.height(AppDimens.L))

                // 个性签名
                FieldTitle("个性签名")
                Spacer(modifier = Modifier.height(6.dp))
                androidx.compose.material3.OutlinedTextField(
                    value = signature,
                    onValueChange = { if (it.length <= 20) signature = it },
                    placeholder = {
                        Text(text = "一句话介绍自己（选填）", color = AppColors.Muted, fontSize = 15.sp)
                    },
                    trailingIcon = {
                        Text(
                            text = "${signature.length}/20",
                            color = AppColors.Sub,
                            fontSize = 11.sp
                        )
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(52.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = androidx.compose.material3.OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = AppColors.Brand,
                        unfocusedBorderColor = AppColors.Line,
                        focusedTextColor = AppColors.Ink,
                        unfocusedTextColor = AppColors.Ink,
                        focusedContainerColor = AppColors.Surface,
                        unfocusedContainerColor = AppColors.Surface
                    ),
                    singleLine = true
                )

                Spacer(modifier = Modifier.height(32.dp))

                // 保存按钮
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(50.dp)
                        .clip(RoundedCornerShape(25.dp))
                        .background(AppColors.Brand)
                        .clickable {
                            val name = nickname.trim()
                            if (name.isEmpty()) {
                                Toast.makeText(context, "昵称不能为空", Toast.LENGTH_SHORT).show()
                                return@clickable
                            }
                            scope.launch {
                                saving = true
                                try {
                                    AuthService.updateProfile(
                                        nickname = name,
                                        avatar = avatarUrl,
                                        city = city.trim().ifEmpty { null },
                                        signature = signature.trim().ifEmpty { null }
                                    )
                                    // 同步更新本地缓存
                                    tokenStore.updateProfile(nickname = name, avatar = avatarUrl)
                                    Toast.makeText(context, "保存成功", Toast.LENGTH_SHORT).show()
                                    kotlinx.coroutines.delay(600)
                                    onBack()
                                } catch (e: Exception) {
                                    Toast.makeText(context, e.message ?: "保存失败", Toast.LENGTH_SHORT).show()
                                }
                                saving = false
                            }
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = if (saving) "保存中..." else "保存",
                        color = Color.White,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
            }
        }
    }
}

// MARK: - 组件

@Composable
private fun FieldTitle(text: String) {
    Text(
        text = text,
        color = AppColors.Ink,
        fontSize = 14.sp,
        fontWeight = FontWeight.Medium,
        modifier = Modifier.padding(start = 4.dp)
    )
}

@Composable
private fun FieldCard(
    placeholder: String,
    value: String,
    modifier: Modifier = Modifier,
    onValueChange: (String) -> Unit
) {
    androidx.compose.material3.OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = {
            Text(text = placeholder, color = AppColors.Muted, fontSize = 15.sp)
        },
        modifier = modifier
            .fillMaxWidth()
            .height(52.dp),
        shape = RoundedCornerShape(12.dp),
        colors = androidx.compose.material3.OutlinedTextFieldDefaults.colors(
            focusedBorderColor = AppColors.Brand,
            unfocusedBorderColor = AppColors.Line,
            focusedTextColor = AppColors.Ink,
            unfocusedTextColor = AppColors.Ink,
            focusedContainerColor = AppColors.Surface,
            unfocusedContainerColor = AppColors.Surface
        ),
        singleLine = true
    )
}

// MARK: - Uri → File

private fun uriToFile(context: android.content.Context, uri: android.net.Uri): File {
    val input = context.contentResolver.openInputStream(uri)
        ?: throw IllegalStateException("无法读取图片")
    val file = File(context.cacheDir, "avatar_${System.currentTimeMillis()}_${uri.hashCode()}.jpg")
    input.use { src ->
        file.outputStream().use { dst -> src.copyTo(dst) }
    }
    return file
}