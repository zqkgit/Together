package com.together.app.modules.teacher.ui

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.component.EmptyStateView
import com.together.app.core.component.ErrorView
import com.together.app.core.component.LoadingView
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.teacher.TeacherViewModel
import com.together.app.services.TeacherService

/**
 * 请假审批：待审批（同意/婉拒）+ 已同意（补课管理）
 * 对齐 iOS LeaveApprovalViewController
 */
@Composable
fun LeaveApprovalScreen(
    viewModel: TeacherViewModel = viewModel(),
    onBack: () -> Unit = {}
) {
    val state by viewModel.leaveState.collectAsState()
    val lifecycleOwner = LocalLifecycleOwner.current
    val context = LocalContext.current

    // 补课候选弹窗状态
    var makeupLeaveId by remember { mutableStateOf<String?>(null) }
    var makeupCandidates by remember { mutableStateOf<List<TeacherService.MakeupCandidate>>(emptyList()) }
    var makeupLoading by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) { viewModel.loadLeaves() }
    androidx.compose.runtime.DisposableEffect(lifecycleOwner) {
        val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME && (state.pending.isNotEmpty() || state.approved.isNotEmpty())) {
                viewModel.loadLeaves(state.selectedStudioId)
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    // Toast
    LaunchedEffect(state.toast) {
        state.toast?.let {
            android.widget.Toast.makeText(context, it, android.widget.Toast.LENGTH_SHORT).show()
            viewModel.clearLeaveToast()
        }
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "请假审批", onBack = onBack)

        // 工作室筛选
        if (state.studioOptions.isNotEmpty()) {
            LazyRow(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = AppDimens.L, vertical = AppDimens.S),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                item {
                    LeaveStudioChip("全部工作室", state.selectedStudioId == null) {
                        viewModel.loadLeaves(null)
                    }
                }
                items(state.studioOptions) { (sid, name) ->
                    LeaveStudioChip(name, state.selectedStudioId == sid) {
                        viewModel.loadLeaves(sid)
                    }
                }
            }
        }

        Box(modifier = Modifier.weight(1f)) {
            when {
                state.loading && state.pending.isEmpty() && state.approved.isEmpty() -> LoadingView()
                state.error != null && state.pending.isEmpty() && state.approved.isEmpty() -> ErrorView(
                    message = state.error!!,
                    onRetry = { viewModel.loadLeaves(state.selectedStudioId) }
                )
                state.pending.isEmpty() && state.approved.isEmpty() -> EmptyStateView(message = "暂无请假记录")
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(
                        start = AppDimens.M, end = AppDimens.M,
                        top = AppDimens.Xs, bottom = AppDimens.Xl
                    )
                ) {
                    if (state.pending.isNotEmpty()) {
                        item {
                            SectionLabel("待审批（${state.pending.size}）")
                        }
                        items(state.pending, key = { "p_${it.leaveId}" }) { leave ->
                            PendingLeaveCard(leave) { action ->
                                leave.leaveId?.let { lid ->
                                    viewModel.reviewLeave(lid, action, state.selectedStudioId)
                                }
                            }
                        }
                    }
                    if (state.approved.isNotEmpty()) {
                        item {
                            SectionLabel("已同意·补课管理（${state.approved.size}）")
                        }
                        items(state.approved, key = { "a_${it.leaveId}" }) { leave ->
                            ApprovedLeaveCard(
                                leave,
                                onArrange = { lid ->
                                    makeupLeaveId = lid
                                    makeupLoading = true
                                    viewModel.loadMakeupCandidates(lid) { list ->
                                        makeupCandidates = list
                                        makeupLoading = false
                                    }
                                },
                                onAbandon = { lid ->
                                    viewModel.abandonMakeup(lid, state.selectedStudioId)
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    // 补课候选弹窗
    if (makeupLeaveId != null) {
        AlertDialog(
            onDismissRequest = {
                makeupLeaveId = null
                makeupCandidates = emptyList()
            },
            title = { Text("选择补课课次", fontWeight = FontWeight.SemiBold) },
            text = {
                if (makeupLoading) {
                    Text("加载中…", color = AppColors.Muted)
                } else if (makeupCandidates.isEmpty()) {
                    Text("暂无可选课次", color = AppColors.Muted)
                } else {
                    Column {
                        makeupCandidates.forEach { candidate ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(8.dp))
                                    .clickable {
                                        viewModel.arrangeMakeup(
                                            makeupLeaveId!!,
                                            candidate.scheduleId ?: "",
                                            state.selectedStudioId
                                        )
                                        makeupLeaveId = null
                                        makeupCandidates = emptyList()
                                    }
                                    .padding(vertical = 10.dp, horizontal = 8.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = candidate.displayText,
                                    fontSize = 13.sp,
                                    color = AppColors.Ink
                                )
                            }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    makeupLeaveId = null
                    makeupCandidates = emptyList()
                }) { Text("取消", color = AppColors.Sub) }
            }
        )
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text = text,
        fontSize = 13.sp,
        fontWeight = FontWeight.SemiBold,
        color = AppColors.Sub,
        modifier = Modifier.padding(start = AppDimens.Xs, top = AppDimens.M, bottom = AppDimens.Xs)
    )
}

@Composable
private fun LeaveStudioChip(text: String, selected: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(17.dp))
            .background(if (selected) AppColors.Brand else AppColors.SurfaceAlt)
            .clickable { onClick() }
            .padding(horizontal = 14.dp, vertical = 6.dp)
    ) {
        Text(
            text = text,
            fontSize = 13.sp,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
            color = if (selected) AppColors.Surface else AppColors.Sub
        )
    }
}

@Composable
private fun PendingLeaveCard(
    leave: TeacherService.LeaveItem,
    onAction: (String) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.CardInner, vertical = AppDimens.L)
    ) {
        Text(
            text = leave.child?.nickname ?: "宝宝",
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
            color = AppColors.Ink
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(text = leave.infoText, fontSize = 12.sp, color = AppColors.Muted, maxLines = 2)
        leave.reason?.takeIf { it.isNotEmpty() }?.let {
            Spacer(modifier = Modifier.height(4.dp))
            Text(text = "请假原因：$it", fontSize = 12.sp, color = AppColors.Sub, maxLines = 2)
        }
        Spacer(modifier = Modifier.height(AppDimens.M))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            ActionButton("同意", AppColors.Brand, AppColors.Surface, Modifier.weight(1f)) {
                onAction("agree")
            }
            ActionButton("婉拒", AppColors.Clay, AppColors.WarnTint, Modifier.weight(1f)) {
                onAction("reject")
            }
        }
    }
}

@Composable
private fun ApprovedLeaveCard(
    leave: TeacherService.LeaveItem,
    onArrange: (String) -> Unit,
    onAbandon: (String) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.CardInner, vertical = AppDimens.L)
    ) {
        Text(
            text = leave.child?.nickname ?: "宝宝",
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
            color = AppColors.Ink
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(text = leave.infoText, fontSize = 12.sp, color = AppColors.Muted, maxLines = 2)
        leave.makeupText?.let {
            Spacer(modifier = Modifier.height(6.dp))
            Text(text = it, fontSize = 12.sp, color = AppColors.Wood)
        }
        if (leave.canArrangeMakeup) {
            Spacer(modifier = Modifier.height(AppDimens.M))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                ActionButton("安排补课", AppColors.Brand, AppColors.Surface, Modifier.weight(1f)) {
                    leave.leaveId?.let(onArrange)
                }
                if (leave.hasPendingMakeup) {
                    ActionButton("放弃补课", AppColors.Clay, AppColors.WarnTint, Modifier.weight(1f)) {
                        leave.leaveId?.let(onAbandon)
                    }
                }
            }
        }
    }
}

@Composable
private fun ActionButton(
    text: String,
    fg: androidx.compose.ui.graphics.Color,
    bg: androidx.compose.ui.graphics.Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(AppDimens.RadiusButton))
            .background(bg)
            .clickable { onClick() }
            .padding(vertical = 8.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(text = text, fontSize = 13.sp, color = fg, fontWeight = FontWeight.Medium)
    }
}