package com.together.app.modules.course.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.together.app.core.component.TogetherAvatar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.CourseDetail
import com.together.app.modules.course.CourseDetailViewModel

/**
 * 报名底部弹窗（对齐 iOS CourseEnrollViewController）
 * 选择孩子 + 选择班级 → 确认报名 → 创建订单
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CourseEnrollSheet(
    viewModel: CourseDetailViewModel,
    course: CourseDetail,
    onDismiss: () -> Unit,
    onSuccess: (String) -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = AppColors.Surface,
        dragHandle = null
    ) {
        Column(
            modifier = Modifier.fillMaxWidth()
        ) {
            // 标题栏
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = AppDimens.L, vertical = AppDimens.M),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    "确认报名",
                    color = AppColors.Ink,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f)
                )
                Text(
                    "取消",
                    color = AppColors.Muted,
                    fontSize = 14.sp,
                    modifier = Modifier.clickable { onDismiss() }
                )
            }

            HorizontalDivider(color = AppColors.Line, thickness = 0.5.dp)

            // 课程简要
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = AppDimens.L, vertical = AppDimens.S),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(course.title, color = AppColors.Ink, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(course.studioName, color = AppColors.Muted, fontSize = 12.sp)
                }
                Text(course.priceText, color = AppColors.Clay, fontSize = 18.sp, fontWeight = FontWeight.Bold)
            }

            HorizontalDivider(color = AppColors.Line, thickness = 0.5.dp)

            // 内容滚动区
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 360.dp)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = AppDimens.L)
            ) {
                // 选择孩子
                Spacer(modifier = Modifier.height(AppDimens.M))
                Text("选择孩子", color = AppColors.Ink, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                Spacer(modifier = Modifier.height(AppDimens.S))
                if (uiState.children.isEmpty()) {
                    Text("暂无孩子，请先在「我的-孩子管理」添加", color = AppColors.Muted, fontSize = 13.sp)
                } else {
                    uiState.children.forEach { child ->
                        ChildSelectRow(
                            name = child.nickname,
                            avatar = child.avatar,
                            selected = child.childId == uiState.selectedChildId,
                            onClick = { viewModel.selectChild(child.childId) }
                        )
                    }
                }

                // 选择班级
                if (!course.classes.isNullOrEmpty()) {
                    Spacer(modifier = Modifier.height(AppDimens.M))
                    Text("选择班级", color = AppColors.Ink, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                    Spacer(modifier = Modifier.height(AppDimens.S))
                    course.classes!!.forEach { cls ->
                        ClassSelectRow(
                            title = cls.title,
                            subtitle = listOfNotNull(
                                cls.teacherName?.takeIf { it.isNotEmpty() },
                                cls.scheduleText?.takeIf { it.isNotEmpty() },
                                cls.enrollmentText.takeIf { it.isNotEmpty() }
                            ).joinToString(" · "),
                            selected = cls.classId == uiState.selectedClassId,
                            enabled = !cls.isFull,
                            onClick = { viewModel.selectClass(cls.classId) }
                        )
                    }
                }

                // 错误提示
                uiState.enrollError?.let { err ->
                    Spacer(modifier = Modifier.height(AppDimens.S))
                    Text(err, color = AppColors.Danger, fontSize = 13.sp)
                }

                Spacer(modifier = Modifier.height(AppDimens.L))
            }

            // 底部确认按钮
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .navigationBarsPadding()
                    .padding(horizontal = AppDimens.L, vertical = AppDimens.M)
                    .clip(RoundedCornerShape(AppDimens.RadiusButton))
                    .background(if (uiState.enrolling) AppColors.Brand.copy(alpha = 0.6f) else AppColors.Brand)
                    .clickable { viewModel.enroll(course.courseId, onSuccess) }
                    .padding(vertical = 14.dp),
                contentAlignment = Alignment.Center
            ) {
                if (uiState.enrolling) {
                    CircularProgressIndicator(color = Color.White, modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                } else {
                    Text("确认报名", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

// MARK: - 孩子选择行

@Composable
private fun ChildSelectRow(name: String, avatar: String?, selected: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = AppDimens.Xs)
            .clip(RoundedCornerShape(AppDimens.RadiusButton))
            .background(if (selected) AppColors.BrandSoft else AppColors.SurfaceAlt)
            .clickable { onClick() }
            .padding(horizontal = AppDimens.M, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        TogetherAvatar(url = avatar, name = name, size = 32.dp)
        Spacer(modifier = Modifier.width(AppDimens.S))
        Text(name, color = AppColors.Ink, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
        Icon(
            if (selected) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked,
            contentDescription = null,
            tint = if (selected) AppColors.Brand else AppColors.Muted,
            modifier = Modifier.size(20.dp)
        )
    }
}

// MARK: - 班级选择行

@Composable
private fun ClassSelectRow(title: String, subtitle: String, selected: Boolean, enabled: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = AppDimens.Xs)
            .clip(RoundedCornerShape(AppDimens.RadiusButton))
            .background(
                when {
                    !enabled -> AppColors.SurfaceAlt.copy(alpha = 0.5f)
                    selected -> AppColors.BrandSoft
                    else -> AppColors.SurfaceAlt
                }
            )
            .clickable(enabled = enabled) { onClick() }
            .padding(horizontal = AppDimens.M, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                title,
                color = if (enabled) AppColors.Ink else AppColors.Muted,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold
            )
            if (subtitle.isNotEmpty()) {
                Text(subtitle, color = AppColors.Muted, fontSize = 12.sp)
            }
        }
        if (!enabled) {
            Text("已满", color = AppColors.Muted, fontSize = 12.sp)
        } else {
            Icon(
                if (selected) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked,
                contentDescription = null,
                tint = if (selected) AppColors.Brand else AppColors.Muted,
                modifier = Modifier.size(20.dp)
            )
        }
    }
}