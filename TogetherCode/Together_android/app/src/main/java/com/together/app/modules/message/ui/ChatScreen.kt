package com.together.app.modules.message.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.app.TogetherApplication
import com.together.app.core.component.TogetherAvatar
import com.together.app.core.component.resolveImageUrl
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.modules.message.MessageViewModel
import com.together.app.modules.message.MessageViewModel.ChatDisplay
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.first

/**
 * 聊天页（对齐 iOS ChatViewController）
 * 气泡（自己右 Brand / 对方左 Surface）+ 时间行 + 输入栏（文本+图片）+ 触顶加载 + 键盘避让
 */
@Composable
fun ChatScreen(
    conversationId: String,
    onBack: () -> Unit,
    viewModel: MessageViewModel = viewModel()
) {
    val context = LocalContext.current
    val app = context.applicationContext as TogetherApplication
    val tokenStore = app.tokenStore

    val state by viewModel.chatState.collectAsState()
    var inputText by remember { mutableStateOf("") }
    var myAvatar by remember { mutableStateOf<String?>(null) }
    var myNickname by remember { mutableStateOf("") }

    val lazyListState = rememberLazyListState()
    var hasInitialScroll by remember { mutableStateOf(false) }

    // 初始化：取用户信息 + 加载消息
    LaunchedEffect(conversationId) {
        val uid = tokenStore.userId.first() ?: ""
        myAvatar = tokenStore.avatar.first()
        myNickname = tokenStore.nickname.first()
        val conversation = MessageViewModel.navConversation
        if (conversation != null && conversation.conversationId == conversationId) {
            viewModel.initChat(conversation, uid)
        }
    }

    // 首次加载完成后滚动到底部（无动画）
    LaunchedEffect(state.displayItems.size) {
        if (state.displayItems.isNotEmpty() && !hasInitialScroll) {
            lazyListState.scrollToItem(state.displayItems.size - 1)
            hasInitialScroll = true
        }
    }

    // 新消息到来时（最后一条变化）滚动到底部（不干扰加载历史）
    val lastMessageId = state.displayItems.lastOrNull()
        ?.let { (it as? ChatDisplay.Msg)?.message?.messageId }
    LaunchedEffect(lastMessageId) {
        if (lastMessageId != null && hasInitialScroll) {
            lazyListState.animateScrollToItem(state.displayItems.size - 1)
        }
    }

    // 错误提示 2 秒后自动清除
    LaunchedEffect(state.error) {
        if (state.error != null) {
            kotlinx.coroutines.delay(2000)
            viewModel.clearChatError()
        }
    }

    // 触顶加载更早消息（跳过初始状态）
    LaunchedEffect(Unit) {
        snapshotFlow { lazyListState.firstVisibleItemIndex to lazyListState.firstVisibleItemScrollOffset }
            .filter { (index, offset) -> index == 0 && offset < 20 }
            .distinctUntilChanged()
            .drop(1)
            .collect {
                viewModel.loadMessages(reset = false)
            }
    }

    // 图片选择
    val imagePicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri != null) {
            viewModel.sendImage(uri)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
            .statusBarsPadding()
            .imePadding()
            .navigationBarsPadding()
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
                text = state.conversation?.peerName ?: "聊天",
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Ink
            )
        }

        // 分割线
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(0.5.dp)
                .background(AppColors.Line)
        )

        // 消息列表
        Box(modifier = Modifier.weight(1f)) {
            if (state.loading && state.displayItems.isEmpty()) {
                CircularProgressIndicator(
                    modifier = Modifier.align(Alignment.Center),
                    color = AppColors.Brand
                )
            } else if (state.displayItems.isEmpty()) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(top = 80.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(text = "🍃", fontSize = 40.sp)
                    Spacer(modifier = Modifier.height(AppDimens.M))
                    Text(text = "开始聊天吧", color = AppColors.Muted, fontSize = 14.sp)
                }
            } else {
                LazyColumn(
                    state = lazyListState,
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(
                        top = AppDimens.M,
                        bottom = AppDimens.M
                    )
                ) {
                    items(state.displayItems, key = { displayKey(it) }) { item ->
                        when (item) {
                            is ChatDisplay.Time -> TimeRow(item.text)
                            is ChatDisplay.Msg -> MessageBubble(
                                item = item,
                                myAvatar = myAvatar,
                                myNickname = myNickname,
                                peerAvatar = state.conversation?.peerAvatar,
                                peerName = state.conversation?.peerName ?: ""
                            )
                        }
                    }
                }
            }
        }

        // 错误提示
        state.error?.let { error ->
            Text(
                text = error,
                color = AppColors.Danger,
                fontSize = 12.sp,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = AppDimens.L, vertical = AppDimens.Xs)
            )
        }

        // 底部输入栏
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.Surface)
                .padding(horizontal = AppDimens.M, vertical = AppDimens.S),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // 图片按钮
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(AppColors.SurfaceAlt)
                    .clickable {
                        imagePicker.launch(
                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                        )
                    },
                contentAlignment = Alignment.Center
            ) {
                if (state.uploading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(18.dp),
                        strokeWidth = 2.dp,
                        color = AppColors.Brand
                    )
                } else {
                    Icon(
                        Icons.Filled.Image,
                        contentDescription = "发送图片",
                        tint = AppColors.Sub,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.width(AppDimens.S))

            // 输入框
            BasicTextField(
                value = inputText,
                onValueChange = { inputText = it },
                modifier = Modifier
                    .weight(1f)
                    .height(36.dp)
                    .clip(RoundedCornerShape(18.dp))
                    .background(AppColors.SurfaceAlt)
                    .padding(horizontal = 14.dp, vertical = 8.dp),
                textStyle = TextStyle(
                    fontSize = 14.sp,
                    color = AppColors.Ink
                ),
                cursorBrush = SolidColor(AppColors.Brand),
                singleLine = false,
                maxLines = 4,
                decorationBox = { innerTextField ->
                    Box(contentAlignment = Alignment.CenterStart) {
                        if (inputText.isEmpty()) {
                            Text(text = "输入消息…", color = AppColors.Muted, fontSize = 14.sp)
                        }
                        innerTextField()
                    }
                }
            )

            Spacer(modifier = Modifier.width(AppDimens.S))

            // 发送按钮
            val canSend = inputText.isNotBlank() && !state.sending
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(if (canSend) AppColors.Brand else AppColors.SurfaceAlt)
                    .clickable(enabled = canSend) {
                        viewModel.sendText(inputText)
                        inputText = ""
                    },
                contentAlignment = Alignment.Center
            ) {
                if (state.sending) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(16.dp),
                        strokeWidth = 2.dp,
                        color = Color.White
                    )
                } else {
                    Icon(
                        Icons.Filled.Send,
                        contentDescription = "发送",
                        tint = if (canSend) Color.White else AppColors.Muted,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        }

        // 输入栏顶部分割线
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(0.5.dp)
                .background(AppColors.Line)
        )
    }
}

// MARK: - 时间行

@Composable
private fun TimeRow(text: String) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = AppDimens.S),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            fontSize = 11.sp,
            color = AppColors.Muted,
            modifier = Modifier
                .clip(RoundedCornerShape(AppDimens.RadiusTag))
                .background(AppColors.SurfaceAlt)
                .padding(horizontal = 8.dp, vertical = 2.dp)
        )
    }
}

// MARK: - 消息气泡（自己右 Brand / 对方左 Surface，头像 30，圆角 14，最大宽 72%）

@Composable
private fun MessageBubble(
    item: ChatDisplay.Msg,
    myAvatar: String?,
    myNickname: String,
    peerAvatar: String?,
    peerName: String
) {
    val isMine = item.isMine
    val message = item.message

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.M, vertical = 3.dp),
        horizontalArrangement = if (isMine) Arrangement.End else Arrangement.Start,
        verticalAlignment = Alignment.Top
    ) {
        if (!isMine) {
            TogetherAvatar(url = peerAvatar, name = peerName, size = 30.dp)
            Spacer(modifier = Modifier.width(AppDimens.S))
        }

        if (message.isImage) {
            // 图片消息 180×180
            AsyncImage(
                model = resolveImageUrl(message.content),
                contentDescription = "图片",
                modifier = Modifier
                    .size(180.dp)
                    .clip(RoundedCornerShape(AppDimens.RadiusInput))
            )
        } else {
            // 文本气泡
            Box(
                modifier = Modifier
                    .widthIn(max = 260.dp)
                    .clip(RoundedCornerShape(AppDimens.RadiusInput))
                    .background(if (isMine) AppColors.Brand else AppColors.Surface)
                    .padding(horizontal = 12.dp, vertical = 8.dp)
            ) {
                Text(
                    text = message.content,
                    color = if (isMine) Color.White else AppColors.Ink,
                    fontSize = 15.sp,
                    lineHeight = 21.sp
                )
            }
        }

        if (isMine) {
            Spacer(modifier = Modifier.width(AppDimens.S))
            TogetherAvatar(url = myAvatar, name = myNickname.ifEmpty { "我" }, size = 30.dp)
        }
    }
}

// MARK: - 列表 key

private fun displayKey(item: ChatDisplay): String = when (item) {
    is ChatDisplay.Time -> "time_${item.text}_${item.hashCode()}"
    is ChatDisplay.Msg -> "msg_${item.message.messageId}"
}