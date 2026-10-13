package com.together.app.modules.mine.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.School
import androidx.compose.material.icons.filled.Storefront
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens

/**
 * 「切换身份」底部弹窗（对齐 iOS RoleSwitchSheet）
 * 家长（当前/切换）/ 老师（去认证/审核中/已驳回）/ 工作室（同上），各行带功能说明
 * 未开通身份的认证状态由调用方异步拉取后刷新
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RoleSwitchSheet(
    roles: List<Int>,
    currentRole: Int = 1,
    authStatuses: Map<Int, String> = emptyMap(),
    teacherName: String? = null,
    onRoleTapped: (Int) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = AppColors.Surface,
        dragHandle = null,
        shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(bottom = AppDimens.Xl + 24.dp)
        ) {
            // 标题
            Text(
                text = "切换身份",
                color = AppColors.Ink,
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = AppDimens.L),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center
            )

            // 三行身份
            RoleRow.all.forEach { row ->
                var title = row.title
                if (row.role == 2 && !teacherName.isNullOrBlank()) {
                    title = "老师 · $teacherName"
                }
                val owned = row.role in roles
                val statusText: String
                val statusColor: Color
                if (owned) {
                    statusText = if (row.role == currentRole) "当前" else "切换"
                    statusColor = AppColors.Brand
                } else {
                    when (authStatuses[row.role]) {
                        "pending" -> {
                            statusText = "审核中"
                            statusColor = Color(0xFFFF9500) // systemOrange
                        }
                        "rejected" -> {
                            statusText = "已驳回"
                            statusColor = Color(0xFFE5484D) // systemRed
                        }
                        else -> {
                            statusText = "去认证"
                            statusColor = AppColors.Muted
                        }
                    }
                }

                RoleRowItem(
                    icon = row.icon,
                    title = title,
                    subtitle = row.subtitle,
                    statusText = statusText,
                    statusColor = statusColor,
                    isCurrent = owned && row.role == currentRole,
                    onClick = { onRoleTapped(row.role) }
                )
                Spacer(modifier = Modifier.height(AppDimens.S))
            }
        }
    }
}

// MARK: - 身份行数据

private data class RoleRow(
    val role: Int,
    val title: String,
    val subtitle: String,
    val icon: ImageVector
) {
    companion object {
        val all = listOf(
            RoleRow(1, "家长", "报名课程·看孩子成长", Icons.Filled.Person),
            RoleRow(2, "老师", "消课·发作品·带学生", Icons.Filled.School),
            RoleRow(3, "工作室", "经营数据·课程管理", Icons.Filled.Storefront)
        )
    }
}

// MARK: - 身份行 UI

@Composable
private fun RoleRowItem(
    icon: ImageVector,
    title: String,
    subtitle: String,
    statusText: String,
    statusColor: Color,
    isCurrent: Boolean,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L)
            .height(64.dp)
            .clip(RoundedCornerShape(AppDimens.RadiusButton))
            .background(AppColors.SurfaceAlt)
            .clickable(onClick = onClick)
            .padding(horizontal = AppDimens.M),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            icon,
            contentDescription = title,
            tint = AppColors.Brand,
            modifier = Modifier.size(24.dp)
        )
        Spacer(modifier = Modifier.width(AppDimens.M))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                color = AppColors.Ink,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = subtitle,
                color = AppColors.Sub,
                fontSize = 11.sp
            )
        }
        Text(
            text = statusText,
            color = statusColor,
            fontSize = 12.sp,
            fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.Medium
        )
    }
}