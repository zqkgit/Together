package com.together.app.modules.message.ui

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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import com.together.app.core.component.AppPullRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.component.TogetherAvatar
import com.together.app.core.component.TogetherDivider
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.ConversationItem
import com.together.app.modules.message.MessageViewModel
import com.together.app.services.PostService

/**
 * 关注列表（选人发起聊天）（对齐 iOS FollowingListViewController）
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FollowingListScreen(
    onBack: () -> Unit,
    onConversationCreated: (ConversationItem) -> Unit,
    viewModel: MessageViewModel = viewModel()
) {
    val state by viewModel.followingState.collectAsState()

    LaunchedEffect(Unit) {
        viewModel.refreshFollowing()
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
                .background(AppColors.Surface)
                .padding(horizontal = AppDimens.S),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "返回",
                tint = AppColors.Ink,
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .clickable { onBack() }
                    .padding(6.dp)
            )
            Spacer(modifier = Modifier.width(AppDimens.S))
            Text(
                text = "发起聊天",
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink
            )
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(0.5.dp)
                .background(AppColors.Line)
        )

        // 列表
        AppPullRefreshBox(
            isRefreshing = state.refreshing,
            onRefresh = { viewModel.refreshFollowing() }
        ) {
            if (state.users.isEmpty() && state.loading && !state.refreshing) {
                CircularProgressIndicator(
                    modifier = Modifier
                        .padding(top = 80.dp)
                        .align(Alignment.TopCenter),
                    color = AppColors.Brand
                )
            } else if (state.users.isEmpty()) {
                val error = state.error
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(top = 80.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(text = if (error != null) "⚠️" else "🍃", fontSize = 40.sp)
                    Spacer(modifier = Modifier.height(AppDimens.M))
                    Text(
                        text = error ?: "暂无关注的人",
                        color = if (error != null) AppColors.Danger else AppColors.Muted,
                        fontSize = 14.sp
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = AppDimens.Xl)
                ) {
                    items(state.users, key = { it.userId ?: it.displayName }) { user ->
                        FollowingUserCell(
                            user = user,
                            creating = state.creatingConversation,
                            onClick = {
                                val uid = user.userId
                                if (uid != null) {
                                    viewModel.createConversation(uid) { conversation ->
                                        if (conversation != null) {
                                            onConversationCreated(conversation)
                                        }
                                    }
                                }
                            }
                        )
                        TogetherDivider()
                    }
                    if (state.loading) {
                        item {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = AppDimens.M),
                                horizontalArrangement = Arrangement.Center
                            ) {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(18.dp),
                                    strokeWidth = 2.dp,
                                    color = AppColors.Muted
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FollowingUserCell(
    user: PostService.FollowingUser,
    creating: Boolean,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.Surface)
            .clickable { onClick() }
            .padding(horizontal = AppDimens.L, vertical = AppDimens.M),
        verticalAlignment = Alignment.CenterVertically
    ) {
        TogetherAvatar(
            url = user.avatar,
            name = user.displayName,
            size = 44.dp
        )

        Spacer(modifier = Modifier.width(AppDimens.M))

        // 昵称 + 角色 badge
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = user.displayName,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink
            )
            Spacer(modifier = Modifier.height(2.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                // 角色 badge
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(AppDimens.RadiusTag))
                        .background(AppColors.BrandSoft)
                        .padding(horizontal = 6.dp, vertical = 1.dp)
                ) {
                    Text(
                        text = user.roleText,
                        fontSize = 10.sp,
                        color = AppColors.BrandDark
                    )
                }
                user.studioName?.takeIf { it.isNotEmpty() }?.let { studio ->
                    Spacer(modifier = Modifier.width(AppDimens.S))
                    Text(
                        text = studio,
                        fontSize = 12.sp,
                        color = AppColors.Muted,
                        maxLines = 1
                    )
                }
            }
        }

        if (creating) {
            CircularProgressIndicator(
                modifier = Modifier.size(18.dp),
                strokeWidth = 2.dp,
                color = AppColors.Muted
            )
        } else {
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = AppColors.Muted,
                modifier = Modifier.size(20.dp)
            )
        }
    }
}