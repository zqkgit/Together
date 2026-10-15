package com.together.app.modules.plaza.ui

import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.core.component.TogetherAvatar
import com.together.app.core.component.TogetherButton
import com.together.app.core.component.TogetherTag
import com.together.app.core.component.resolveImageUrl
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.plaza.PlazaViewModel
import com.together.app.modules.plaza.PlazaViewModel.PostImage

/**
 * 发帖页（对齐 iOS BasePostCreateViewController + Parent/Teacher 子类）
 * 卡片式布局：正文 → 图片 → [关联孩子/课程 | 班级/消课] → 选择话题 → 谁可以看 → 位置
 * 家长：关联孩子单选 + 关联课程（选课程=孩子作品）
 * 老师：课程班级 + 学生多选标签 + 消课开关（仅孩子作品）
 * 编辑模式通过 PlazaViewModel.navEditPost 缓存触发
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun PostCreateScreen(
    role: Int,
    postType: Int = 1,
    viewModel: PlazaViewModel = viewModel(),
    onClose: () -> Unit = {},
    onPublished: () -> Unit = {}
) {
    val state by viewModel.createState.collectAsState()
    val context = LocalContext.current

    // 初始化：编辑缓存优先，否则新建
    LaunchedEffect(Unit) {
        val editPost = PlazaViewModel.navEditPost
        if (editPost != null) {
            PlazaViewModel.navEditPost = null
            viewModel.initEdit(editPost)
        } else {
            viewModel.initCreate(role, postType)
        }
    }

    // 发布成功
    LaunchedEffect(state.success) {
        if (state.success) {
            Toast.makeText(context, if (state.isEditing) "已更新" else "发布成功", Toast.LENGTH_SHORT).show()
            onPublished()
        }
    }

    // 错误提示
    LaunchedEffect(state.error) {
        state.error?.let {
            Toast.makeText(context, it, Toast.LENGTH_SHORT).show()
            viewModel.clearError()
        }
    }

    // 图片选择（多选，剩余可选数 = 9 - 已有）
    val imagePicker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(maxItems = 9)
    ) { uris ->
        if (uris.isNotEmpty()) viewModel.addImages(uris)
    }

    // 导航标题（对齐 iOS navTitle）
    val title = when {
        state.isEditing -> if (state.postType == 2) "编辑孩子作品" else "编辑"
        state.editingRole == 2 && state.postType == 2 -> "发布孩子作品"
        state.editingRole == 2 -> "发布老师作品"
        state.postType == 2 -> "发布孩子作品"
        else -> "发布动态"
    }

    // 发布按钮文字（对齐 iOS publishButton.setTitle）
    val publishButtonText = when {
        state.isEditing -> "保存"
        state.postType == 2 -> "发布孩子作品"
        state.editingRole == 2 -> "发布老师作品"
        else -> "发布动态"
    }

    // 占位文案（对齐 iOS TextCell.placeholder）
    val placeholder = if (state.editingRole == 2) {
        "记录这节课的精彩瞬间，分享给家长…"
    } else {
        "分享孩子的成长瞬间，老师和其他家长都能看到并点赞。"
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
            .statusBarsPadding()
    ) {
        // 顶栏：标题居中 + 右侧 × 关闭（对齐 iOS immersiveNav + xmark 按钮）
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp)
                .padding(horizontal = AppDimens.L),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Spacer(Modifier.weight(1f))
            Text(
                text = title,
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink
            )
            Spacer(Modifier.weight(1f))
            Box(
                modifier = Modifier
                    .size(38.dp)
                    .clip(CircleShape)
                    .background(AppColors.Ink.copy(alpha = 0.06f))
                    .clickable(onClick = onClose),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Filled.Close,
                    contentDescription = "关闭",
                    tint = AppColors.Ink,
                    modifier = Modifier.size(16.dp)
                )
            }
        }

        // 表单（卡片间距 16dp，对齐 iOS section header 16pt）
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = AppDimens.L)
        ) {
            // 正文卡片
            FormCard {
                Box(modifier = Modifier.fillMaxWidth()) {
                    Column {
                        BasicTextField(
                            value = state.content,
                            onValueChange = { if (it.length <= 100) viewModel.updateContent(it) },
                            textStyle = androidx.compose.ui.text.TextStyle(
                                fontSize = 15.sp,
                                lineHeight = 22.sp,
                                color = AppColors.Ink
                            ),
                            cursorBrush = androidx.compose.ui.graphics.SolidColor(AppColors.Brand),
                            modifier = Modifier
                                .fillMaxWidth()
                                .heightIn(min = 72.dp),
                            decorationBox = { inner ->
                                if (state.content.isEmpty()) {
                                    Text(
                                        placeholder,
                                        fontSize = 15.sp,
                                        lineHeight = 22.sp,
                                        color = AppColors.Sub.copy(alpha = 0.7f)
                                    )
                                }
                                inner()
                            }
                        )
                        Text(
                            text = "${state.content.length}/100",
                            fontSize = 11.sp,
                            color = AppColors.Sub.copy(alpha = 0.6f),
                            modifier = Modifier.align(Alignment.End)
                        )
                    }
                }
            }

            CardSpacer()

            // 图片卡片（横向滑动，对齐 iOS ImageGridCell）
            FormCard {
                ImageRowSection(
                    images = state.images,
                    onAdd = {
                        val remaining = 9 - state.images.size
                        if (remaining > 0) {
                            imagePicker.launch(
                                PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                            )
                        }
                    },
                    onRemove = { viewModel.removeImage(it) }
                )
            }

            CardSpacer()

            // 家长分支：关联孩子 + 关联课程（仅孩子作品，对齐 iOS section 2/3）
            if (state.editingRole == 1 && state.postType == 2 && state.childList.isNotEmpty()) {
                FormCard { ChildSelectSection(viewModel) }
                CardSpacer()
                val balances = remember(state.selectedChildId, state.childList) {
                    viewModel.activeBalances()
                }
                if (balances.isNotEmpty()) {
                    FormCard { CourseSelectSection(viewModel, balances) }
                    CardSpacer()
                }
            }

            // 老师分支：课程·班级 + 消课（仅孩子作品，对齐 iOS section 2/3）
            if (state.editingRole == 2 && state.postType == 2) {
                FormCard { ClassSelectSection(viewModel) }
                CardSpacer()
                if (!state.isEditing) {
                    FormCard { ConsumeSection(viewModel) }
                    CardSpacer()
                }
            }

            // 选择话题（对齐 iOS topicCell）
            FormCard { TopicSection(viewModel) }
            CardSpacer()

            // 谁可以看（对齐 iOS VisibilityCell）
            FormCard { VisibilitySection(viewModel) }
            CardSpacer()

            // 位置（对齐 iOS PickerCell locationCell）
            FormCard { LocationSection(viewModel) }

            Spacer(Modifier.height(AppDimens.Xl))
        }

        // 底部发布栏（对齐 iOS bottomBar + publishButton）
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.Surface)
                .navigationBarsPadding()
                .padding(horizontal = AppDimens.L)
                .padding(top = AppDimens.M, bottom = AppDimens.Xl)
        ) {
            TogetherButton(
                text = publishButtonText,
                onClick = { viewModel.publish() },
                enabled = !state.publishing,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

// MARK: - 卡片容器（对齐 iOS card()：白底圆角12、左右缩进16）

@Composable
private fun FormCard(content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(AppColors.Surface)
            .padding(horizontal = 16.dp, vertical = 16.dp),
        content = content
    )
}

@Composable
private fun CardSpacer() {
    Spacer(Modifier.height(16.dp))
}

/** 卡片内区块标题（对齐 iOS 13pt medium sub 色） */
@Composable
private fun CardLabel(text: String) {
    Text(
        text = text,
        fontSize = 13.sp,
        fontWeight = FontWeight.Medium,
        color = AppColors.Sub
    )
}

// MARK: - 选择行（对齐 iOS PickerCell：标题 + 详情 + 右箭头）

@Composable
private fun PickerRow(
    title: String,
    detail: String,
    detailColor: Color = AppColors.Sub,
    onClick: () -> Unit = {}
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title,
            fontSize = 15.sp,
            color = AppColors.Ink
        )
        Spacer(Modifier.weight(1f))
        if (detail.isNotEmpty()) {
            Text(
                text = detail,
                fontSize = 14.sp,
                color = detailColor,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.widthIn(max = 160.dp)
            )
            Spacer(Modifier.width(4.dp))
        }
        Icon(
            Icons.Filled.ChevronRight,
            contentDescription = null,
            tint = AppColors.Sub.copy(alpha = 0.5f),
            modifier = Modifier.size(14.dp)
        )
    }
}

// MARK: - 图片横滑区（对齐 iOS ImageGridCell：100dp 项 + 添加图片副标题 + xmark 删除）

@Composable
private fun ImageRowSection(
    images: List<PostImage>,
    onAdd: () -> Unit,
    onRemove: (Int) -> Unit
) {
    LazyRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        items(images.size) { index ->
            Box(
                modifier = Modifier
                    .size(100.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(AppColors.SurfaceAlt)
            ) {
                val model = when (val img = images[index]) {
                    is PostImage.Existing -> resolveImageUrl(img.url)
                    is PostImage.New -> img.uri
                }
                AsyncImage(
                    model = model,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )
                // 删除角标（对齐 iOS xmark.circle.fill 24pt 黑55%）
                Icon(
                    Icons.Filled.Cancel,
                    contentDescription = "删除",
                    tint = Color.Black.copy(alpha = 0.55f),
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .size(24.dp)
                        .clickable { onRemove(index) }
                        .padding(2.dp)
                )
            }
        }
        if (images.size < 9) {
            item {
                Box(
                    modifier = Modifier
                        .size(100.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(AppColors.SurfaceAlt)
                        .clickable(onClick = onAdd),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            text = "+",
                            fontSize = 38.sp,
                            fontWeight = FontWeight.Light,
                            color = AppColors.Sub
                        )
                        Text(
                            text = "添加图片",
                            fontSize = 10.sp,
                            color = AppColors.Sub.copy(alpha = 0.9f)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - 家长：关联孩子（对齐 iOS section 2：标题 + 头像单选 chips）

@Composable
private fun ChildSelectSection(viewModel: PlazaViewModel) {
    val state by viewModel.createState.collectAsState()

    CardLabel("关联孩子")
    Spacer(Modifier.height(AppDimens.S))
    Row(
        horizontalArrangement = Arrangement.spacedBy(AppDimens.M),
        modifier = Modifier.horizontalScroll(rememberScrollState())
    ) {
        state.childList.forEach { child ->
            val selected = state.selectedChildId == child.childId
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.clickable { viewModel.selectChild(child.childId) }
            ) {
                Box {
                    TogetherAvatar(
                        url = child.avatar,
                        name = child.nickname,
                        size = 48.dp
                    )
                    if (selected) {
                        Box(
                            modifier = Modifier
                                .align(Alignment.BottomEnd)
                                .size(18.dp)
                                .clip(CircleShape)
                                .background(AppColors.Brand),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                Icons.Filled.Check,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(12.dp)
                            )
                        }
                    }
                }
                Spacer(Modifier.height(AppDimens.Xs))
                Text(
                    text = child.nickname,
                    fontSize = 12.sp,
                    color = if (selected) AppColors.Brand else AppColors.Sub,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

// MARK: - 家长：关联课程（对齐 iOS section 3：PickerCell 样式）

@Composable
private fun CourseSelectSection(
    viewModel: PlazaViewModel,
    balances: List<com.together.app.core.model.ChildBalance>
) {
    val state by viewModel.createState.collectAsState()
    var expanded by remember { mutableStateOf(false) }

    Box {
        val selectedCourse = balances.firstOrNull { it.courseId == state.selectedCourseId }
        PickerRow(
            title = "关联课程",
            detail = selectedCourse?.courseText ?: "不关联",
            detailColor = if (selectedCourse != null) AppColors.Ink else AppColors.Sub,
            onClick = { expanded = true }
        )
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false }
        ) {
            DropdownMenuItem(
                text = { Text("不关联课程", fontSize = 13.sp) },
                onClick = {
                    expanded = false
                    viewModel.selectCourse(null)
                }
            )
            balances.forEach { balance ->
                DropdownMenuItem(
                    text = {
                        Text(
                            text = "${balance.courseText}（余${balance.remainingLessons}节）",
                            fontSize = 13.sp
                        )
                    },
                    onClick = {
                        expanded = false
                        viewModel.selectCourse(balance.courseId)
                    }
                )
            }
        }
    }
}

// MARK: - 老师：课程·班级 + 学生多选（对齐 iOS TeacherClassCell 合并卡）

@Composable
private fun ClassSelectSection(viewModel: PlazaViewModel) {
    val state by viewModel.createState.collectAsState()
    var expanded by remember { mutableStateOf(false) }

    Column {
        // 课程·班级行
        Box {
            PickerRow(
                title = "课程 · 班级",
                detail = state.selectedClass?.displayName
                    ?: if (state.teacherClasses.isEmpty()) "暂无可选班级" else "请选择",
                detailColor = if (state.selectedClass != null) AppColors.Ink else AppColors.Sub,
                onClick = { if (state.teacherClasses.isNotEmpty()) expanded = true }
            )
            DropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false }
            ) {
                state.teacherClasses.forEach { cls ->
                    DropdownMenuItem(
                        text = { Text(cls.displayName, fontSize = 13.sp) },
                        onClick = {
                            expanded = false
                            viewModel.selectClass(cls)
                        }
                    )
                }
            }
        }

        // 选了班级后：分割线 + 选择学生标签（对齐 iOS divider + TagSelectView）
        if (state.selectedClass != null && state.classStudents.isNotEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = AppDimens.S)
                    .height(0.5.dp)
                    .background(AppColors.Line)
            )
            CardLabel("选择学生")
            Spacer(Modifier.height(AppDimens.S))
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(AppDimens.S),
                verticalArrangement = Arrangement.spacedBy(AppDimens.S)
            ) {
                state.classStudents.forEach { student ->
                    val selected = student.childId in state.selectedStudentIds
                    TogetherTag(
                        text = student.nickname.ifEmpty { "学生" },
                        color = if (selected) Color.White else AppColors.Sub,
                        bgColor = if (selected) AppColors.Brand else AppColors.SurfaceAlt,
                        modifier = Modifier.clickable { viewModel.toggleStudent(student.childId) }
                    )
                }
            }
        }
    }
}

// MARK: - 老师：同步消课（对齐 iOS ConsumeCell）

@Composable
private fun ConsumeSection(viewModel: PlazaViewModel) {
    val state by viewModel.createState.collectAsState()

    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                text = "发布后同步消课",
                fontSize = 15.sp,
                color = AppColors.Ink
            )
            Text(
                text = "开启后为所选学生扣除本节课时（自动匹配最近课次）",
                fontSize = 12.sp,
                color = AppColors.Sub
            )
        }
        Spacer(Modifier.width(AppDimens.M))
        Switch(
            checked = state.consumeEnabled,
            onCheckedChange = { viewModel.toggleConsume(it) },
            colors = SwitchDefaults.colors(
                checkedTrackColor = AppColors.Brand
            )
        )
    }
}

// MARK: - 选择话题（对齐 iOS topicCell：标题 + # 标签流式布局）

@Composable
private fun TopicSection(viewModel: PlazaViewModel) {
    val state by viewModel.createState.collectAsState()

    CardLabel("选择话题")
    Spacer(Modifier.height(AppDimens.S))
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(AppDimens.M),
        verticalArrangement = Arrangement.spacedBy(AppDimens.M)
    ) {
        state.topics.forEach { topic ->
            val selected = state.topic == topic
            TogetherTag(
                text = "# $topic",
                color = if (selected) Color.White else AppColors.Brand,
                bgColor = if (selected) AppColors.Brand else AppColors.BrandSoft,
                modifier = Modifier.clickable {
                    viewModel.selectTopic(if (selected) "" else topic)
                }
            )
        }
    }
}

// MARK: - 谁可以看（对齐 iOS VisibilityCell：等宽胶囊按钮 40dp 高 + 圆角 20）

@Composable
private fun VisibilitySection(viewModel: PlazaViewModel) {
    val state by viewModel.createState.collectAsState()

    CardLabel("谁可以看")
    Spacer(Modifier.height(AppDimens.S))
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(AppDimens.S)
    ) {
        listOf(2 to "公开", 1 to "仅好友").forEach { (vis, label) ->
            val selected = state.visibility == vis
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(40.dp)
                    .clip(RoundedCornerShape(20.dp))
                    .background(if (selected) AppColors.Brand else AppColors.SurfaceAlt)
                    .clickable { viewModel.selectVisibility(vis) },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = label,
                    fontSize = 13.sp,
                    color = if (selected) Color.White else AppColors.Sub
                )
            }
        }
    }
}

// MARK: - 位置（对齐 iOS PickerCell locationCell + ActionSheet）

@Composable
private fun LocationSection(viewModel: PlazaViewModel) {
    val state by viewModel.createState.collectAsState()
    var showLocationDialog by remember { mutableStateOf(false) }

    val acquireLocation: () -> Unit = {
        viewModel.getCurrentLocationForCreate { lat, lng ->
            viewModel.setLocation(lat, lng, "当前位置")
        }
    }

    Box {
        if (state.location != null) {
            PickerRow(
                title = "位置",
                detail = state.location?.name ?: "当前位置",
                detailColor = AppColors.Ink,
                onClick = { showLocationDialog = true }
            )
        } else {
            PickerRow(
                title = "添加位置",
                detail = "",
                onClick = acquireLocation
            )
        }
    }

    // 已选位置点击：重新选择 / 不显示位置（对齐 iOS ThemeActionSheet）
    if (showLocationDialog) {
        AlertDialog(
            onDismissRequest = { showLocationDialog = false },
            title = null,
            text = null,
            confirmButton = {
                TextButton(onClick = {
                    showLocationDialog = false
                    acquireLocation()
                }) { Text("重新选择", color = AppColors.Brand) }
            },
            dismissButton = {
                TextButton(onClick = {
                    showLocationDialog = false
                    viewModel.clearLocation()
                }) { Text("不显示位置", color = AppColors.Ink) }
            }
        )
    }
}