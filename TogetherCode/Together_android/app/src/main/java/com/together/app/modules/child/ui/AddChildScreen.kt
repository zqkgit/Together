package com.together.app.modules.child.ui

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
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.child.ChildViewModel

/**
 * 添加孩子表单（对齐 iOS AddChildViewController / PR 图5）
 * 头像选择（相册+5emoji）/ 昵称 / 出生年份 / 性别 / 兴趣多选 / 绑定学籍提示
 */
@Composable
fun AddChildScreen(
    viewModel: ChildViewModel = viewModel(),
    onClose: () -> Unit = {},
    onSaved: () -> Unit = {}
) {
    val context = LocalContext.current
    val addState by viewModel.addState.collectAsState()

    // 头像：5 emoji + 相册自定义
    val avatarOptions = remember { listOf("🌻", "🦊", "🐟", "🍀", "🎀") }
    var selectedEmoji by remember { mutableIntStateOf(0) } // -1 表示选了相册
    var customAvatarUri by remember { mutableStateOf<android.net.Uri?>(null) }

    // 昵称
    var nickname by remember { mutableStateOf("") }

    // 出生年份 2010-2024 倒序
    val currentYear = remember { java.time.Year.now().value }
    val years = remember { (2010..minOf(2024, currentYear)).toList().reversed() }
    var selectedYear by remember { mutableIntStateOf(years.firstOrNull { it == 2019 } ?: years.first()) }
    var showYearPicker by remember { mutableStateOf(false) }

    // 性别：2=女孩（默认） 1=男孩
    var selectedGender by remember { mutableIntStateOf(2) }

    // 兴趣多选
    val interestOptions = remember { listOf("水彩", "黏土", "书法", "国画", "儿童画", "素描") }
    val selectedInterests = remember { mutableStateOf(setOf<String>()) }

    // 相册选图
    val imagePicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri != null) {
            customAvatarUri = uri
            selectedEmoji = -1
        }
    }

    // 错误 toast
    LaunchedEffect(addState.error) {
        addState.error?.let { msg ->
            Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
            viewModel.clearAddError()
        }
    }

    // 保存
    fun save() {
        val name = nickname.trim()
        if (name.isEmpty()) {
            Toast.makeText(context, "请填写孩子昵称", Toast.LENGTH_SHORT).show()
            return
        }
        if (name.length > 20) {
            Toast.makeText(context, "昵称最多 20 个字", Toast.LENGTH_SHORT).show()
            return
        }
        val avatar = if (selectedEmoji >= 0) avatarOptions[selectedEmoji] else null
        viewModel.addChild(
            nickname = name,
            avatar = avatar,
            birthday = "$selectedYear-01-01",
            gender = selectedGender,
            interests = selectedInterests.value.toList(),
            customAvatarUri = customAvatarUri,
            onSuccess = {
                Toast.makeText(context, "添加成功", Toast.LENGTH_SHORT).show()
                onSaved()
            }
        )
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg).statusBarsPadding()) {
        // 顶栏：关闭 + 标题 + 保存
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(AppDimens.TopBarHeight)
                .background(AppColors.Surface)
                .padding(horizontal = AppDimens.S),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onClose) {
                Icon(Icons.Filled.Close, contentDescription = "关闭", tint = AppColors.Ink)
            }
            Text(
                text = "添加孩子",
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink,
                modifier = Modifier.weight(1f)
            )
            TextButton(
                onClick = { save() },
                enabled = !addState.saving
            ) {
                Text(
                    text = if (addState.saving) "保存中..." else "保存",
                    color = AppColors.Brand,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        // 表单
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(bottom = AppDimens.Xxl)
        ) {
            // 头像选择
            SectionTitle("选一个头像")
            AvatarRow(
                avatarOptions = avatarOptions,
                selectedEmoji = selectedEmoji,
                customAvatarUri = customAvatarUri,
                onSelectEmoji = { index ->
                    selectedEmoji = index
                    customAvatarUri = null
                },
                onPickAlbum = {
                    imagePicker.launch(
                        PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                    )
                }
            )

            // 昵称
            SectionTitle("孩子昵称")
            OutlinedTextField(
                value = nickname,
                onValueChange = { if (it.length <= 20) nickname = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = AppDimens.L)
                    .height(46.dp),
                placeholder = { Text("如：糖糖", color = AppColors.Muted, fontSize = 15.sp) },
                singleLine = true,
                shape = RoundedCornerShape(AppDimens.RadiusInput),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = AppColors.Brand,
                    unfocusedBorderColor = AppColors.Line,
                    focusedContainerColor = AppColors.Surface,
                    unfocusedContainerColor = AppColors.Surface,
                    cursorColor = AppColors.Brand
                )
            )

            // 出生年份
            SectionTitle("出生年份")
            Box(
                modifier = Modifier
                    .padding(end = AppDimens.L)
                    .size(width = 160.dp, height = 46.dp)
                    .clip(RoundedCornerShape(AppDimens.RadiusInput))
                    .background(AppColors.Surface)
                    .border(1.dp, AppColors.Line, RoundedCornerShape(AppDimens.RadiusInput))
                    .clickable { showYearPicker = true },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "${selectedYear}年（${maxOf(0, currentYear - selectedYear)}岁）",
                    fontSize = 15.sp,
                    color = AppColors.Ink,
                    textAlign = TextAlign.Center
                )
            }

            // 性别
            SectionTitle("性别")
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = AppDimens.L)
                    .height(44.dp),
                horizontalArrangement = Arrangement.spacedBy(AppDimens.L)
            ) {
                GenderButton(
                    text = "女孩",
                    selected = selectedGender == 2,
                    modifier = Modifier.weight(1f),
                    onClick = { selectedGender = 2 }
                )
                GenderButton(
                    text = "男孩",
                    selected = selectedGender == 1,
                    modifier = Modifier.weight(1f),
                    onClick = { selectedGender = 1 }
                )
            }

            // 兴趣方向
            SectionTitle("兴趣方向（可多选）")
            InterestTags(
                options = interestOptions,
                selected = selectedInterests.value,
                onToggle = { tag ->
                    selectedInterests.value = if (tag in selectedInterests.value) {
                        selectedInterests.value - tag
                    } else {
                        selectedInterests.value + tag
                    }
                }
            )

            Spacer(modifier = Modifier.height(AppDimens.L))

            // 绑定学籍提示卡
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = AppDimens.L)
                    .clip(RoundedCornerShape(AppDimens.RadiusCard))
                    .background(AppColors.Surface)
                    .padding(AppDimens.CardInner)
            ) {
                Column {
                    Text(
                        text = "绑定工作室学籍（可选）",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = AppColors.Ink
                    )
                    Spacer(modifier = Modifier.height(AppDimens.S))
                    Text(
                        text = "绑定学籍后，老师发布的课堂作品会自动归入孩子的成长档案。",
                        fontSize = 11.sp,
                        color = AppColors.Sub,
                        lineHeight = 16.sp
                    )
                }
            }
        }
    }

    // 年份选择弹窗
    if (showYearPicker) {
        AlertDialog(
            onDismissRequest = { showYearPicker = false },
            title = { Text("选择出生年份") },
            text = {
                Column(
                    modifier = Modifier.verticalScroll(rememberScrollState())
                ) {
                    years.forEach { year ->
                        val age = maxOf(0, currentYear - year)
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(8.dp))
                                .background(
                                    if (year == selectedYear) AppColors.BrandSoft else Color.Transparent
                                )
                                .clickable {
                                    selectedYear = year
                                    showYearPicker = false
                                }
                                .padding(vertical = 10.dp, horizontal = AppDimens.M),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = "${year}年（${age}岁）",
                                fontSize = 15.sp,
                                color = if (year == selectedYear) AppColors.Brand else AppColors.Ink,
                                fontWeight = if (year == selectedYear) FontWeight.SemiBold else FontWeight.Normal
                            )
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showYearPicker = false }) {
                    Text("取消", color = AppColors.Sub)
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
        fontSize = 14.sp,
        fontWeight = FontWeight.SemiBold,
        color = AppColors.Ink,
        modifier = Modifier.padding(
            start = AppDimens.L, end = AppDimens.L,
            top = AppDimens.Xl, bottom = AppDimens.M
        )
    )
}

// MARK: - 头像选择行（相册 + 5 emoji）

@Composable
private fun AvatarRow(
    avatarOptions: List<String>,
    selectedEmoji: Int,
    customAvatarUri: android.net.Uri?,
    onSelectEmoji: (Int) -> Unit,
    onPickAlbum: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.M)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            // 相册入口
            AvatarCircle(
                selected = selectedEmoji == -1,
                onClick = onPickAlbum,
                size = 44.dp
            ) {
                if (customAvatarUri != null) {
                    AsyncImage(
                        model = customAvatarUri,
                        contentDescription = "自定义头像",
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .size(40.dp)
                            .clip(CircleShape)
                    )
                } else {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            Icons.Filled.PhotoCamera,
                            contentDescription = "相册",
                            tint = AppColors.Sub,
                            modifier = Modifier.size(18.dp)
                        )
                        Text(text = "相册", fontSize = 8.sp, color = AppColors.Sub)
                    }
                }
            }
            // 5 emoji
            avatarOptions.forEachIndexed { index, emoji ->
                AvatarCircle(
                    selected = selectedEmoji == index,
                    onClick = { onSelectEmoji(index) },
                    size = 44.dp
                ) {
                    Text(text = emoji, fontSize = 22.sp)
                }
            }
        }
    }
}

@Composable
private fun AvatarCircle(
    selected: Boolean,
    onClick: () -> Unit,
    size: androidx.compose.ui.unit.Dp,
    content: @Composable () -> Unit
) {
    Box(
        modifier = Modifier
            .size(size)
            .clip(CircleShape)
            .background(if (selected) AppColors.BrandSoft else AppColors.SurfaceAlt)
            .border(
                width = if (selected) 2.dp else 0.dp,
                color = if (selected) AppColors.Brand else Color.Transparent,
                shape = CircleShape
            )
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        content()
    }
}

// MARK: - 性别按钮

@Composable
private fun GenderButton(
    text: String,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Box(
        modifier = modifier
            .height(44.dp)
            .clip(RoundedCornerShape(AppDimens.RadiusInput))
            .background(if (selected) AppColors.Brand else AppColors.Surface)
            .border(
                width = if (selected) 0.dp else 1.dp,
                color = if (selected) Color.Transparent else AppColors.Line,
                shape = RoundedCornerShape(AppDimens.RadiusInput)
            )
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            fontSize = 15.sp,
            color = if (selected) Color.White else AppColors.Sub
        )
    }
}

// MARK: - 兴趣标签多选

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun InterestTags(
    options: List<String>,
    selected: Set<String>,
    onToggle: (String) -> Unit
) {
    FlowRow(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L),
        horizontalArrangement = Arrangement.spacedBy(AppDimens.S),
        verticalArrangement = Arrangement.spacedBy(AppDimens.S)
    ) {
        options.forEach { tag ->
            val isSelected = tag in selected
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(AppDimens.RadiusInput))
                    .background(if (isSelected) AppColors.Brand else AppColors.Surface)
                    .border(
                        width = 1.dp,
                        color = if (isSelected) AppColors.Brand else AppColors.Line,
                        shape = RoundedCornerShape(AppDimens.RadiusInput)
                    )
                    .clickable { onToggle(tag) }
                    .padding(horizontal = 14.dp, vertical = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = tag,
                    fontSize = 13.sp,
                    color = if (isSelected) Color.White else AppColors.Sub
                )
            }
        }
    }
}