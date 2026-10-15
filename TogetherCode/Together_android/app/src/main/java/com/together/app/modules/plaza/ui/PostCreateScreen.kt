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
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
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
 * 正文(≤100字) + 图片九宫格(≤9) + 话题 + 可见性 + 位置
 * 家长：关联孩子单选 + 关联课程（选课程=孩子作品）
 * 老师：课程班级 + 学生多选 + 消课开关（仅孩子作品）
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

    val title = when {
        state.isEditing -> "编辑"
        state.editingRole == 2 && state.postType == 2 -> "发布孩子作品"
        state.editingRole == 2 -> "发布动态"
        state.postType == 2 -> "发布孩子作品"
        else -> "发布动态"
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
            .statusBarsPadding()
    ) {
        // 顶栏
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp)
                .padding(horizontal = AppDimens.S),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "取消",
                fontSize = 15.sp,
                color = AppColors.Sub,
                modifier = Modifier
                    .clickable(onClick = onClose)
                    .padding(horizontal = AppDimens.M)
            )
            Text(
                text = title,
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink,
                modifier = Modifier.weight(1f),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center
            )
            // 占位保持标题居中
            Text(
                text = "取消",
                fontSize = 15.sp,
                color = Color.Transparent,
                modifier = Modifier.padding(horizontal = AppDimens.M)
            )
        }

        // 表单
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = AppDimens.L)
        ) {
            // 正文输入
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = AppDimens.M)
                    .clip(RoundedCornerShape(AppDimens.RadiusCard))
                    .background(AppColors.Surface)
                    .padding(AppDimens.CardInner)
            ) {
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
                            .height(100.dp),
                        decorationBox = { inner ->
                            if (state.content.isEmpty()) {
                                Text(
                                    "分享宝贝的艺术瞬间...",
                                    fontSize = 15.sp,
                                    color = AppColors.Muted
                                )
                            }
                            inner()
                        }
                    )
                    Text(
                        text = "${state.content.length}/100",
                        fontSize = 11.sp,
                        color = AppColors.Muted,
                        modifier = Modifier.align(Alignment.End)
                    )
                }
            }

            // 图片九宫格
            ImageGridSection(
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

            // 话题
            SectionLabel("话题")
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(AppDimens.S),
                verticalArrangement = Arrangement.spacedBy(AppDimens.Xs)
            ) {
                state.topics.forEach { topic ->
                    val selected = state.topic == topic
                    TogetherTag(
                        text = if (selected) "# $topic" else topic,
                        color = if (selected) Color.White else AppColors.Brand,
                        bgColor = if (selected) AppColors.Brand else AppColors.BrandSoft,
                        modifier = Modifier.clickable {
                            viewModel.selectTopic(if (selected) "" else topic)
                        }
                    )
                }
            }

            Spacer(Modifier.height(AppDimens.M))

            // 可见性
            SectionLabel("可见范围")
            Row(horizontalArrangement = Arrangement.spacedBy(AppDimens.S)) {
                listOf(2 to "公开", 1 to "仅好友").forEach { (vis, label) ->
                    val selected = state.visibility == vis
                    TogetherTag(
                        text = label,
                        color = if (selected) Color.White else AppColors.Sub,
                        bgColor = if (selected) AppColors.Brand else AppColors.SurfaceAlt,
                        modifier = Modifier.clickable { viewModel.selectVisibility(vis) }
                    )
                }
            }

            Spacer(Modifier.height(AppDimens.M))

            // 位置
            SectionLabel("位置")
            if (state.location != null) {
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(AppDimens.RadiusTag))
                        .background(AppColors.BrandSoft)
                        .padding(horizontal = AppDimens.M, vertical = AppDimens.S),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Filled.LocationOn,
                        contentDescription = null,
                        tint = AppColors.Brand,
                        modifier = Modifier.size(14.dp)
                    )
                    Text(
                        text = state.location?.name ?: "当前位置",
                        fontSize = 12.sp,
                        color = AppColors.Brand,
                        modifier = Modifier.padding(horizontal = AppDimens.Xs)
                    )
                    Icon(
                        Icons.Filled.Close,
                        contentDescription = "清除",
                        tint = AppColors.Brand,
                        modifier = Modifier
                            .size(14.dp)
                            .clickable { viewModel.clearLocation() }
                    )
                }
            } else {
                Text(
                    text = "+ 添加位置",
                    fontSize = 13.sp,
                    color = AppColors.Muted,
                    modifier = Modifier
                        .clip(RoundedCornerShape(AppDimens.RadiusTag))
                        .background(AppColors.SurfaceAlt)
                        .clickable {
                            viewModel.getCurrentLocationForCreate { lat, lng ->
                                viewModel.setLocation(lat, lng, "当前位置")
                            }
                        }
                        .padding(horizontal = AppDimens.M, vertical = AppDimens.S)
                )
            }

            Spacer(Modifier.height(AppDimens.M))

            // 家长分支：关联孩子 + 关联课程（工作室无孩子时隐藏整块）
            if (state.editingRole == 1 && state.childList.isNotEmpty()) {
                ParentSection(viewModel)
            }

            // 老师分支：班级 + 学生 + 消课（仅孩子作品）
            if (state.editingRole == 2 && state.postType == 2) {
                TeacherSection(viewModel)
            }

            Spacer(Modifier.height(AppDimens.Xl))
        }

        // 底部发布按钮
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.Surface)
                .padding(horizontal = AppDimens.L, vertical = AppDimens.S)
        ) {
            TogetherButton(
                text = if (state.isEditing) "保存" else "发布",
                onClick = { viewModel.publish() },
                enabled = !state.publishing,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

// MARK: - 区块标题

@Composable
private fun SectionLabel(text: String) {
    Text(
        text = text,
        fontSize = 14.sp,
        fontWeight = FontWeight.SemiBold,
        color = AppColors.Ink,
        modifier = Modifier.padding(vertical = AppDimens.S)
    )
}

// MARK: - 图片九宫格

@Composable
private fun ImageGridSection(
    images: List<PostImage>,
    onAdd: () -> Unit,
    onRemove: (Int) -> Unit
) {
    // 3 列网格：每行 3 个，正方形
    Column(verticalArrangement = Arrangement.spacedBy(AppDimens.S)) {
        val totalCells = images.size + if (images.size < 9) 1 else 0
        for (rowStart in 0 until totalCells step 3) {
            Row(horizontalArrangement = Arrangement.spacedBy(AppDimens.S)) {
                for (i in rowStart until minOf(rowStart + 3, totalCells)) {
                    if (i < images.size) {
                        // 已选图片
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .aspectRatio(1f)
                                .clip(RoundedCornerShape(AppDimens.RadiusTag))
                                .background(AppColors.SurfaceAlt)
                        ) {
                            val model = when (val img = images[i]) {
                                is PostImage.Existing -> resolveImageUrl(img.url)
                                is PostImage.New -> img.uri
                            }
                            AsyncImage(
                                model = model,
                                contentDescription = null,
                                contentScale = ContentScale.Crop,
                                modifier = Modifier.fillMaxSize()
                            )
                            // 删除角标
                            Box(
                                modifier = Modifier
                                    .align(Alignment.TopEnd)
                                    .padding(4.dp)
                                    .size(20.dp)
                                    .clip(CircleShape)
                                    .background(Color.Black.copy(alpha = 0.5f))
                                    .clickable { onRemove(i) },
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    Icons.Filled.Close,
                                    contentDescription = "删除",
                                    tint = Color.White,
                                    modifier = Modifier.size(12.dp)
                                )
                            }
                        }
                    } else {
                        // 添加按钮
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .aspectRatio(1f)
                                .clip(RoundedCornerShape(AppDimens.RadiusTag))
                                .background(AppColors.Surface)
                                .clickable(onClick = onAdd),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                Icons.Filled.Add,
                                contentDescription = "添加图片",
                                tint = AppColors.Muted,
                                modifier = Modifier.size(28.dp)
                            )
                        }
                    }
                }
                // 补齐空位保持对齐
                repeat(3 - minOf(3, totalCells - rowStart)) {
                    Spacer(Modifier.weight(1f))
                }
            }
        }
    }
}

// MARK: - 家长：关联孩子 + 关联课程

@Composable
private fun ParentSection(viewModel: PlazaViewModel) {
    val state by viewModel.createState.collectAsState()

    SectionLabel("关联孩子")
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

    Spacer(Modifier.height(AppDimens.M))

    // 关联课程（可选，选了=孩子作品）
    SectionLabel("关联课程（选填）")
    val balances = remember(state.selectedChildId, state.childList) {
        viewModel.activeBalances()
    }
    var courseMenuExpanded by remember { mutableStateOf(false) }
    Box {
        Row(
            modifier = Modifier
                .clip(RoundedCornerShape(AppDimens.RadiusTag))
                .background(AppColors.Surface)
                .clickable { if (balances.isNotEmpty()) courseMenuExpanded = true }
                .padding(horizontal = AppDimens.M, vertical = AppDimens.S),
            verticalAlignment = Alignment.CenterVertically
        ) {
            val selectedCourse = balances.firstOrNull { it.courseId == state.selectedCourseId }
            Text(
                text = selectedCourse?.courseText ?: "不关联课程",
                fontSize = 13.sp,
                color = if (selectedCourse != null) AppColors.Ink else AppColors.Muted
            )
            if (balances.isNotEmpty()) {
                Spacer(Modifier.width(AppDimens.Xs))
                Icon(
                    Icons.Filled.ExpandMore,
                    contentDescription = null,
                    tint = AppColors.Muted,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
        DropdownMenu(
            expanded = courseMenuExpanded,
            onDismissRequest = { courseMenuExpanded = false }
        ) {
            DropdownMenuItem(
                text = { Text("不关联课程") },
                onClick = {
                    courseMenuExpanded = false
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
                        courseMenuExpanded = false
                        viewModel.selectCourse(balance.courseId)
                    }
                )
            }
        }
    }

    Spacer(Modifier.height(AppDimens.M))
}

// MARK: - 老师：班级 + 学生多选 + 消课

@Composable
private fun TeacherSection(viewModel: PlazaViewModel) {
    val state by viewModel.createState.collectAsState()

    SectionLabel("课程班级")
    var classMenuExpanded by remember { mutableStateOf(false) }
    Box {
        Row(
            modifier = Modifier
                .clip(RoundedCornerShape(AppDimens.RadiusTag))
                .background(AppColors.Surface)
                .clickable { if (state.teacherClasses.isNotEmpty()) classMenuExpanded = true }
                .padding(horizontal = AppDimens.M, vertical = AppDimens.S),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = state.selectedClass?.displayName
                    ?: state.selectedClass?.course?.title
                    ?: if (state.teacherClasses.isEmpty()) "暂无可选班级" else "选择班级",
                fontSize = 13.sp,
                color = if (state.selectedClass != null) AppColors.Ink else AppColors.Muted
            )
            if (state.teacherClasses.isNotEmpty()) {
                Spacer(Modifier.width(AppDimens.Xs))
                Icon(
                    Icons.Filled.ExpandMore,
                    contentDescription = null,
                    tint = AppColors.Muted,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
        DropdownMenu(
            expanded = classMenuExpanded,
            onDismissRequest = { classMenuExpanded = false }
        ) {
            state.teacherClasses.forEach { cls ->
                DropdownMenuItem(
                    text = {
                        Text(
                            text = cls.displayName,
                            fontSize = 13.sp
                        )
                    },
                    onClick = {
                        classMenuExpanded = false
                        viewModel.selectClass(cls)
                    }
                )
            }
        }
    }

    Spacer(Modifier.height(AppDimens.M))

    // 学生多选
    if (state.classStudents.isNotEmpty()) {
        SectionLabel("上课学生（多选）")
        Column(verticalArrangement = Arrangement.spacedBy(AppDimens.S)) {
            state.classStudents.forEach { student ->
                val selected = student.childId in state.selectedStudentIds
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(AppDimens.RadiusTag))
                        .background(if (selected) AppColors.BrandSoft else AppColors.Surface)
                        .clickable { viewModel.toggleStudent(student.childId) }
                        .padding(horizontal = AppDimens.M, vertical = AppDimens.S),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    TogetherAvatar(
                        url = student.avatar,
                        name = student.nickname.ifEmpty { "学生" },
                        size = 36.dp
                    )
                    Spacer(Modifier.width(AppDimens.S))
                    Text(
                        text = student.nickname.ifEmpty { "学生" },
                        fontSize = 14.sp,
                        color = AppColors.Ink,
                        modifier = Modifier.weight(1f)
                    )
                    Icon(
                        imageVector = if (selected) Icons.Filled.Check else Icons.Filled.Add,
                        contentDescription = null,
                        tint = if (selected) AppColors.Brand else AppColors.Muted,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        }

        Spacer(Modifier.height(AppDimens.M))

        // 消课开关
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(AppDimens.RadiusCard))
                .background(AppColors.Surface)
                .padding(horizontal = AppDimens.CardInner, vertical = AppDimens.S),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(Modifier.weight(1f)) {
                Text(
                    text = "同步消课",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = AppColors.Ink
                )
                Text(
                    text = "为选中的学生各扣除 1 节课时",
                    fontSize = 11.sp,
                    color = AppColors.Muted
                )
            }
            Switch(
                checked = state.consumeEnabled,
                onCheckedChange = { viewModel.toggleConsume(it) },
                colors = SwitchDefaults.colors(
                    checkedTrackColor = AppColors.Brand
                )
            )
        }
    }
}

