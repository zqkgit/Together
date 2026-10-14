package com.together.app.modules.studio.ui

import android.widget.Toast
import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.component.EmptyStateView
import com.together.app.core.component.ErrorView
import com.together.app.core.component.InfoRow
import com.together.app.core.component.LoadingView
import com.together.app.core.component.TogetherAvatar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.studio.StudioViewModel
import com.together.app.services.StudioService

/**
 * 工作室「老师详情」页（对齐 iOS StudioTeacherDetailViewController）
 *
 * 老师档案卡（头像+姓名+认证/评分标签+擅长+教龄/手机/加入时间/证书+简介）
 * + 经营统计卡 + 带课课程 + 消课流水 + 底部解除合作
 */
@Composable
fun StudioTeacherDetailScreen(
    teacherId: String,
    teacherName: String = "老师详情",
    onBack: () -> Unit = {},
    viewModel: StudioViewModel = viewModel()
) {
    val state by viewModel.teacherDetailState.collectAsState()
    var showReleaseDialog by remember { mutableStateOf(false) }

    // ON_RESUME 刷新
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) viewModel.loadTeacherDetail(teacherId)
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
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
                .height(AppDimens.TopBarHeight)
                .background(AppColors.Surface),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "返回",
                    tint = AppColors.Ink
                )
            }
            Text(
                text = teacherName,
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink
            )
        }

        // 内容
        when {
            state.loading -> LoadingView()
            state.error != null -> ErrorView(
                message = state.error ?: "加载失败",
                onRetry = { viewModel.loadTeacherDetail(teacherId) }
            )
            state.detail?.teacher == null -> EmptyStateView(message = "老师信息不存在")
            else -> {
                val teacher = state.detail!!.teacher!!
                val courses = state.detail?.courses ?: emptyList()
                val logs = state.detail?.logs ?: emptyList()

                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(horizontal = AppDimens.L)
                        .padding(top = AppDimens.S, bottom = AppDimens.Xl),
                    verticalArrangement = Arrangement.spacedBy(AppDimens.L)
                ) {
                    // 档案卡
                    TeacherProfileCard(teacher)

                    // 统计卡
                    TeacherStatsCard(teacher)

                    // 带课课程
                    if (courses.isNotEmpty()) {
                        SectionTitle("本工作室带课")
                        TeacherCourseCard(courses)
                    }

                    // 消课流水
                    SectionTitle("最近消课流水")
                    TeacherLogCard(logs)

                    // 解除合作
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(48.dp)
                            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusButton))
                            .clip(RoundedCornerShape(AppDimens.RadiusButton))
                            .background(AppColors.Surface)
                            .clickable { showReleaseDialog = true },
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "解除合作",
                            fontSize = 15.sp,
                            color = AppColors.Danger
                        )
                    }
                }
            }
        }
    }

    // 解除合作确认弹窗
    if (showReleaseDialog) {
        AlertDialog(
            onDismissRequest = { showReleaseDialog = false },
            title = { Text("解除合作", fontWeight = FontWeight.SemiBold) },
            text = {
                Text(
                    text = "解除与「${teacherName}」的合作关系？\n解除后该老师不再出现在本工作室在职列表，其档案与其他工作室的绑定不受影响。",
                    fontSize = 14.sp,
                    color = AppColors.Sub
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showReleaseDialog = false
                        viewModel.releaseTeacher(
                            teacherId = teacherId,
                            onSuccess = { onBack() },
                            onError = { }
                        )
                    }
                ) { Text("确认解除", color = AppColors.Danger) }
            },
            dismissButton = {
                TextButton(onClick = { showReleaseDialog = false }) {
                    Text("取消", color = AppColors.Muted)
                }
            }
        )
    }
}

// MARK: - 档案卡

@Composable
private fun TeacherProfileCard(teacher: StudioService.StudioTeacherItem) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.CardInner)
    ) {
        // 头像 + 姓名 + 标签
        Row(verticalAlignment = Alignment.CenterVertically) {
            TogetherAvatar(
                url = teacher.avatar,
                name = teacher.displayName,
                size = 64.dp
            )
            Spacer(modifier = Modifier.width(AppDimens.M))
            Column {
                Text(
                    text = teacher.displayName,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.Ink,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(modifier = Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    // 认证标签
                    Tag(
                        text = if (teacher.isCertified) "已认证" else "未认证",
                        textColor = if (teacher.isCertified) AppColors.Brand else AppColors.Muted,
                        bgColor = if (teacher.isCertified) AppColors.BrandSoft else AppColors.SurfaceAlt
                    )
                    // 评分标签
                    Tag(
                        text = "评分 ${teacher.ratingText}",
                        textColor = AppColors.Wood,
                        bgColor = AppColors.SurfaceAlt
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = teacher.subjectsText,
                    fontSize = 12.sp,
                    color = AppColors.Muted,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }

        Spacer(modifier = Modifier.height(AppDimens.L))

        // 资料行
        InfoRow(label = "教龄", value = teacher.yearsText)
        Divider()
        InfoRow(label = "手机号", value = teacher.phone ?: "—")
        Divider()
        InfoRow(label = "加入时间", value = teacher.joinedText)
        Divider()
        InfoRow(label = "证书编号", value = teacher.certNo?.takeIf { it.isNotEmpty() } ?: "—")

        // 简介
        val intro = teacher.intro?.trim()
        if (!intro.isNullOrEmpty()) {
            Divider()
            Spacer(modifier = Modifier.height(AppDimens.M))
            Text(
                text = intro,
                fontSize = 13.sp,
                color = AppColors.Sub
            )
        }
    }
}

// MARK: - 统计卡

@Composable
private fun TeacherStatsCard(teacher: StudioService.StudioTeacherItem) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(vertical = AppDimens.L)
    ) {
        StatCell(Modifier.weight(1f), (teacher.studentCount ?: 0).toString(), "在读学员")
        Box(
            modifier = Modifier
                .width(0.5.dp)
                .height(40.dp)
                .align(Alignment.CenterVertically)
                .background(AppColors.Line)
        )
        StatCell(Modifier.weight(1f), (teacher.monthLessons ?: 0).toString(), "本月消课")
        Box(
            modifier = Modifier
                .width(0.5.dp)
                .height(40.dp)
                .align(Alignment.CenterVertically)
                .background(AppColors.Line)
        )
        StatCell(Modifier.weight(1f), (teacher.courseCount ?: 0).toString(), "带课")
    }
}

@Composable
private fun StatCell(modifier: Modifier, value: String, label: String) {
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = value,
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.BrandDark
        )
        Spacer(modifier = Modifier.height(2.dp))
        Text(
            text = label,
            fontSize = 11.sp,
            color = AppColors.Muted
        )
    }
}

// MARK: - 带课课程卡

@Composable
private fun TeacherCourseCard(courses: List<StudioService.StudioTeacherCourse>) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.L)
    ) {
        courses.forEachIndexed { index, course ->
            if (index > 0) {
                Divider()
                Spacer(modifier = Modifier.height(AppDimens.M))
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = course.titleText,
                        fontSize = 14.sp,
                        color = AppColors.Ink,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = course.detailText,
                        fontSize = 12.sp,
                        color = AppColors.Muted
                    )
                }
                Spacer(modifier = Modifier.width(AppDimens.S))
                Tag(
                    text = course.statusText,
                    textColor = if (course.isOnline) AppColors.Brand else AppColors.Muted,
                    bgColor = if (course.isOnline) AppColors.BrandSoft else AppColors.SurfaceAlt
                )
            }
            if (index < courses.size - 1) {
                Spacer(modifier = Modifier.height(AppDimens.M))
            }
        }
    }
}

// MARK: - 消课流水卡

@Composable
private fun TeacherLogCard(logs: List<StudioService.StudioTeacherLog>) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.L)
    ) {
        if (logs.isEmpty()) {
            Text(
                text = "暂无消课记录",
                fontSize = 13.sp,
                color = AppColors.Muted,
                modifier = Modifier.fillMaxWidth(),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center
            )
        } else {
            logs.forEachIndexed { index, log ->
                if (index > 0) {
                    Divider()
                    Spacer(modifier = Modifier.height(10.dp))
                }
                Row(verticalAlignment = Alignment.Top) {
                    Text(
                        text = log.dateText,
                        fontSize = 12.sp,
                        color = AppColors.Muted
                    )
                    Spacer(modifier = Modifier.width(AppDimens.S))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = log.titleText,
                            fontSize = 13.sp,
                            color = AppColors.Ink,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        Spacer(modifier = Modifier.height(3.dp))
                        Text(
                            text = log.detailText,
                            fontSize = 11.sp,
                            color = AppColors.Muted,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                    Spacer(modifier = Modifier.width(AppDimens.S))
                    Text(
                        text = log.deltaText,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = if (log.isIncrease) AppColors.Brand else AppColors.Warn
                    )
                }
                if (index < logs.size - 1) {
                    Spacer(modifier = Modifier.height(10.dp))
                }
            }
        }
    }
}

// MARK: - 通用小组件

@Composable
private fun SectionTitle(text: String) {
    Text(
        text = text,
        fontSize = 15.sp,
        fontWeight = FontWeight.SemiBold,
        color = AppColors.Ink,
        modifier = Modifier.padding(start = AppDimens.Xs)
    )
}

@Composable
private fun Tag(text: String, textColor: androidx.compose.ui.graphics.Color, bgColor: androidx.compose.ui.graphics.Color) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(AppDimens.RadiusTag))
            .background(bgColor)
            .padding(horizontal = 9.dp, vertical = 4.dp)
    ) {
        Text(
            text = text,
            fontSize = 11.sp,
            color = textColor
        )
    }
}

@Composable
private fun Divider() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(0.5.dp)
            .background(AppColors.Line)
    )
}