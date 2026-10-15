package com.together.app.modules.studio.ui

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import com.together.app.core.component.AppPullRefreshBox
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
import com.together.app.core.component.LoadingView
import com.together.app.core.component.TogetherAvatar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.studio.StudioViewModel
import com.together.app.services.StudioService

/**
 * 工作室「老师合作申请」页（对齐 iOS StudioTeacherApplicationViewController）
 *
 * 分段筛选（待处理/已通过/已驳回/全部 带计数）+ 申请卡片
 * 待处理卡片可直接「通过」或「驳回并留言」
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StudioTeacherApplicationScreen(
    onBack: () -> Unit = {},
    viewModel: StudioViewModel = viewModel()
) {
    val state by viewModel.applicationState.collectAsState()

    var approveTarget by remember { mutableStateOf<StudioService.StudioTeacherApplication?>(null) }
    var rejectTarget by remember { mutableStateOf<StudioService.StudioTeacherApplication?>(null) }
    var rejectReason by remember { mutableStateOf("") }

    // ON_RESUME 刷新
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) viewModel.loadApplications()
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
                text = "合作申请",
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink
            )
        }

        // 筛选条
        ApplicationFilterBar(
            selectedFilter = state.selectedFilter,
            summary = state.summary,
            onSelect = { viewModel.selectApplicationFilter(it) }
        )

        // 列表
        AppPullRefreshBox(
            isRefreshing = state.loading,
            onRefresh = { viewModel.loadApplications() },
            modifier = Modifier.fillMaxSize()
        ) {
            when {
                state.loading && state.applications.isEmpty() -> LoadingView()
                state.error != null && state.applications.isEmpty() -> ErrorView(
                    message = state.error ?: "加载失败",
                    onRetry = { viewModel.loadApplications() }
                )
                state.applications.isEmpty() -> EmptyStateView(message = state.selectedFilter.emptyText)
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(
                        start = AppDimens.L,
                        end = AppDimens.L,
                        top = AppDimens.S,
                        bottom = AppDimens.Xl
                    ),
                    verticalArrangement = Arrangement.spacedBy(AppDimens.S)
                ) {
                    items(state.applications, key = { it.id }) { app ->
                        ApplicationCard(
                            application = app,
                            onApprove = { approveTarget = app },
                            onReject = { rejectTarget = app; rejectReason = "" }
                        )
                    }
                }
            }
        }
    }

    // 通过确认弹窗
    approveTarget?.let { app ->
        AlertDialog(
            onDismissRequest = { approveTarget = null },
            title = { Text("通过合作申请", fontWeight = FontWeight.SemiBold) },
            text = {
                Text(
                    text = "通过后「${app.displayName}」加入本工作室，可被指派到班级并开始排课。",
                    fontSize = 14.sp,
                    color = AppColors.Sub
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.reviewApplication(
                            id = app.id,
                            action = "approve",
                            onSuccess = { approveTarget = null },
                            onError = { approveTarget = null }
                        )
                    }
                ) { Text("确认通过", color = AppColors.Brand) }
            },
            dismissButton = {
                TextButton(onClick = { approveTarget = null }) {
                    Text("再想想", color = AppColors.Muted)
                }
            }
        )
    }

    // 驳回弹窗（输入原因）
    rejectTarget?.let { app ->
        AlertDialog(
            onDismissRequest = { rejectTarget = null },
            title = { Text("驳回并留言", fontWeight = FontWeight.SemiBold) },
            text = {
                OutlinedTextField(
                    value = rejectReason,
                    onValueChange = { if (it.length <= 100) rejectReason = it },
                    placeholder = { Text("请填写驳回原因（老师可见）", fontSize = 14.sp) },
                    modifier = Modifier.fillMaxWidth()
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.reviewApplication(
                            id = app.id,
                            action = "reject",
                            reason = rejectReason.trim().ifEmpty { null },
                            onSuccess = { rejectTarget = null },
                            onError = { rejectTarget = null }
                        )
                    }
                ) { Text("确认驳回", color = AppColors.Danger) }
            },
            dismissButton = {
                TextButton(onClick = { rejectTarget = null }) {
                    Text("取消", color = AppColors.Muted)
                }
            }
        )
    }
}

// MARK: - 筛选条

@Composable
private fun ApplicationFilterBar(
    selectedFilter: StudioService.ApplicationFilter,
    summary: StudioService.StudioTeacherApplicationSummary?,
    onSelect: (StudioService.ApplicationFilter) -> Unit
) {
    val filters = StudioService.ApplicationFilter.entries

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L, vertical = AppDimens.S)
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(4.dp)
    ) {
        filters.forEach { filter ->
            val selected = filter == selectedFilter
            val count = summary?.count(filter) ?: 0
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(13.dp))
                    .background(if (selected) AppColors.BrandSoft else AppColors.Surface)
                    .clickable { onSelect(filter) }
                    .padding(vertical = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "${filter.title} $count",
                    fontSize = 13.sp,
                    fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (selected) AppColors.Ink else AppColors.Sub,
                    maxLines = 1
                )
            }
        }
    }
}

// MARK: - 申请卡片

@Composable
private fun ApplicationCard(
    application: StudioService.StudioTeacherApplication,
    onApprove: () -> Unit,
    onReject: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(AppDimens.CardShadowElevation, RoundedCornerShape(AppDimens.RadiusCard))
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(14.dp)
    ) {
        // 头像 + 姓名 + 副标题 + 状态标签
        Row(verticalAlignment = Alignment.CenterVertically) {
            TogetherAvatar(
                url = application.avatar,
                name = application.displayName,
                size = 42.dp
            )
            Spacer(modifier = Modifier.width(AppDimens.M))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = application.displayName,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.Ink,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "${application.subtitle} · 申请 ${application.submittedText}",
                    fontSize = 12.sp,
                    color = AppColors.Muted,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            Spacer(modifier = Modifier.width(AppDimens.S))
            // 状态标签
            val (statusColor, statusBg) = when (application.status) {
                1 -> AppColors.Brand to AppColors.BrandSoft
                2 -> AppColors.Muted to AppColors.SurfaceAlt
                else -> AppColors.Warn to AppColors.WarnTint
            }
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(AppDimens.RadiusTag))
                    .background(statusBg)
                    .padding(horizontal = 9.dp, vertical = 4.dp)
            ) {
                Text(
                    text = application.statusText,
                    fontSize = 11.sp,
                    color = statusColor
                )
            }
        }

        // 简介 + 证书
        Spacer(modifier = Modifier.height(AppDimens.M))
        val intro = application.intro?.trim()
        val certText = application.certNo?.takeIf { it.isNotEmpty() }?.let { "证书 $it" } ?: "未上传证书"
        Text(
            text = if (intro.isNullOrEmpty()) certText else "$intro · $certText",
            fontSize = 12.sp,
            color = AppColors.Sub,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis
        )

        // 驳回原因
        val reason = application.reviewReason?.trim()
        if (application.status == 2 && !reason.isNullOrEmpty()) {
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = "驳回原因：$reason",
                fontSize = 11.sp,
                color = AppColors.Warn,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }

        // 操作按钮（仅待处理）
        if (application.isPending) {
            Spacer(modifier = Modifier.height(AppDimens.M))
            Row {
                // 驳回按钮
                Box(
                    modifier = Modifier
                        .width(78.dp)
                        .height(40.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(AppColors.SurfaceAlt)
                        .clickable(onClick = onReject),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "驳回",
                        fontSize = 14.sp,
                        color = AppColors.Sub
                    )
                }
                Spacer(modifier = Modifier.width(10.dp))
                // 通过按钮
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(40.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(AppColors.Brand)
                        .clickable(onClick = onApprove),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "通过申请",
                        fontSize = 14.sp,
                        color = AppColors.Surface,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }
    }
}