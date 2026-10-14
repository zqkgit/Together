package com.together.app.modules.studio.ui

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
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
import com.together.app.core.component.LoadingView
import com.together.app.core.component.TogetherAvatar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.studio.StudioViewModel
import com.together.app.services.StudioService

/**
 * 工作室「老师管理」列表页（对齐 iOS StudioTeacherListViewController）
 *
 * 老师卡片（头像+姓名+擅长·教龄+右侧学生数/月消课）+ 右上合作申请入口（带角标）+ 右下悬浮邀请老师
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StudioTeacherListScreen(
    onBack: () -> Unit = {},
    onTeacherClick: (StudioService.StudioTeacherItem) -> Unit = {},
    onApplications: () -> Unit = {},
    viewModel: StudioViewModel = viewModel()
) {
    val context = LocalContext.current
    val state by viewModel.teacherListState.collectAsState()

    var showInviteDialog by remember { mutableStateOf(false) }
    var invitePhone by remember { mutableStateOf("") }

    // ON_RESUME 刷新
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) viewModel.loadTeachers()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val pendingCount = state.summary?.pendingCount ?: 0

    Box(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        Column(modifier = Modifier.fillMaxSize().statusBarsPadding()) {
            // 顶栏：老师管理 + 右上合作申请按钮（带角标）
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(AppDimens.TopBarHeight)
                    .background(AppColors.Surface)
                    .padding(horizontal = AppDimens.S),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "老师管理",
                    fontSize = 17.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.Ink,
                    modifier = Modifier.clickable { onBack() }
                )
                Spacer(modifier = Modifier.weight(1f))
                // 合作申请按钮（白底圆角方块 + 待审角标）
                Box {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .shadow(2.dp, RoundedCornerShape(12.dp))
                            .clip(RoundedCornerShape(12.dp))
                            .background(AppColors.Surface)
                            .clickable { onApplications() },
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Default.PersonAdd,
                            contentDescription = "合作申请",
                            tint = AppColors.Ink,
                            modifier = Modifier.size(18.dp)
                        )
                    }
                    if (pendingCount > 0) {
                        Box(
                            modifier = Modifier
                                .offset(x = 4.dp, y = (-4).dp)
                                .align(Alignment.TopEnd)
                                .clip(RoundedCornerShape(8.dp))
                                .background(AppColors.Danger)
                                .padding(horizontal = 4.dp, vertical = 1.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = if (pendingCount > 99) "99+" else pendingCount.toString(),
                                fontSize = 10.sp,
                                color = Color.White,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }

            // 列表
            PullToRefreshBox(
                isRefreshing = state.loading,
                onRefresh = { viewModel.loadTeachers() },
                modifier = Modifier.fillMaxSize()
            ) {
                when {
                    state.loading && state.teachers.isEmpty() -> LoadingView()
                    state.error != null && state.teachers.isEmpty() -> ErrorView(
                        message = state.error ?: "加载失败",
                        onRetry = { viewModel.loadTeachers() }
                    )
                    state.teachers.isEmpty() -> EmptyStateView(
                        message = "还没有合作老师\n点右下角「+」邀请老师加入"
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(
                            start = AppDimens.L,
                            end = AppDimens.L,
                            top = AppDimens.S,
                            bottom = 92.dp
                        ),
                        verticalArrangement = Arrangement.spacedBy(AppDimens.S)
                    ) {
                        items(state.teachers, key = { it.teacherId }) { teacher ->
                            TeacherCard(teacher = teacher, onClick = { onTeacherClick(teacher) })
                        }
                    }
                }
            }
        }

        // 右下悬浮邀请按钮
        Box(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = 20.dp, bottom = 20.dp)
                .size(52.dp)
                .shadow(8.dp, RoundedCornerShape(16.dp), ambientColor = AppColors.Brand)
                .clip(RoundedCornerShape(16.dp))
                .background(AppColors.Brand)
                .clickable { showInviteDialog = true },
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Default.Add,
                contentDescription = "邀请老师",
                tint = Color.White,
                modifier = Modifier.size(24.dp)
            )
        }
    }

    // 邀请老师弹窗
    if (showInviteDialog) {
        AlertDialog(
            onDismissRequest = { showInviteDialog = false; invitePhone = "" },
            title = { Text("邀请老师", fontWeight = FontWeight.SemiBold) },
            text = {
                Column {
                    Text(
                        text = "输入对方手机号（需已通过老师认证）",
                        fontSize = 13.sp,
                        color = AppColors.Sub
                    )
                    Spacer(modifier = Modifier.height(AppDimens.S))
                    OutlinedTextField(
                        value = invitePhone,
                        onValueChange = { if (it.length <= 11) invitePhone = it },
                        placeholder = { Text("11 位手机号", fontSize = 14.sp) },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        val phone = invitePhone.trim()
                        if (phone.length != 11 || !phone.all { it.isDigit() }) {
                            Toast.makeText(context, "请输入 11 位手机号", Toast.LENGTH_SHORT).show()
                            return@TextButton
                        }
                        viewModel.inviteTeacher(
                            phone = phone,
                            onSuccess = { showInviteDialog = false; invitePhone = "" },
                            onError = { Toast.makeText(context, it, Toast.LENGTH_SHORT).show() }
                        )
                    }
                ) { Text("发送邀请", color = AppColors.Brand) }
            },
            dismissButton = {
                TextButton(onClick = { showInviteDialog = false; invitePhone = "" }) {
                    Text("取消", color = AppColors.Muted)
                }
            }
        )
    }
}

// MARK: - 老师卡片

@Composable
private fun TeacherCard(
    teacher: StudioService.StudioTeacherItem,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable(onClick = onClick)
            .padding(horizontal = AppDimens.CardInner, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        TogetherAvatar(
            url = teacher.avatar,
            name = teacher.displayName,
            size = 42.dp
        )
        Spacer(modifier = Modifier.width(AppDimens.M))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = teacher.displayName,
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = teacher.subtitle,
                fontSize = 12.sp,
                color = AppColors.Muted,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        Spacer(modifier = Modifier.width(AppDimens.S))
        Column(horizontalAlignment = Alignment.End) {
            Text(
                text = teacher.studentsText,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.BrandDark
            )
            Spacer(modifier = Modifier.height(3.dp))
            Text(
                text = teacher.lessonsText,
                fontSize = 11.sp,
                color = AppColors.Muted
            )
        }
    }
}