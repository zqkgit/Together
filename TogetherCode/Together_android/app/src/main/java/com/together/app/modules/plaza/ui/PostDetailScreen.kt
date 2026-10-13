package com.together.app.modules.plaza.ui

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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
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
import com.together.app.app.TogetherApplication
import com.together.app.core.component.LoadingView
import com.together.app.core.component.TogetherAvatar
import com.together.app.core.component.TogetherTag
import com.together.app.core.component.resolveImageUrl
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.PostCourse
import com.together.app.core.model.PostItem
import com.together.app.core.model.PostLocation
import com.together.app.core.model.fenToYuanText
import com.together.app.modules.plaza.PlazaViewModel
import kotlinx.coroutines.flow.first

/**
 * 帖子详情（对齐 iOS PostDetailViewController）
 * 图片轮播 → 作者行(关注) → 内容 → 课程卡(去报名) → 学生消课(撤销) → 位置 → 评论区 → 底部操作栏
 * 更多菜单：is_mine → 编辑/删除（老师孩子作品不可删）
 */
@Composable
fun PostDetailScreen(
    postId: String,
    viewModel: PlazaViewModel = viewModel(),
    onBack: () -> Unit = {},
    onEdit: (PostItem) -> Unit = {},
    onEnroll: (String) -> Unit = {},
    onDeleted: () -> Unit = {}
) {
    val state by viewModel.detailState.collectAsState()
    val context = LocalContext.current
    val tokenStore = (context.applicationContext as TogetherApplication).tokenStore

    var myRole by remember { mutableIntStateOf(1) }
    var myUserId by remember { mutableStateOf("") }
    LaunchedEffect(Unit) {
        myRole = tokenStore.getRoleSync()
        myUserId = tokenStore.userId.first() ?: ""
    }

    // ON_RESUME 加载/刷新（首次进入 + 编辑返回自动刷新）
    val lifecycleOwner = androidx.compose.ui.platform.LocalLifecycleOwner.current
    androidx.compose.runtime.DisposableEffect(lifecycleOwner) {
        val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
            if (event == androidx.lifecycle.Lifecycle.Event.ON_RESUME) {
                viewModel.loadDetail(postId)
                viewModel.loadComments(postId)
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    // 删除成功 → 返回
    LaunchedEffect(state.deleted) {
        if (state.deleted) {
            Toast.makeText(context, "已删除", Toast.LENGTH_SHORT).show()
            onDeleted()
        }
    }

    if (state.loading) {
        Box(Modifier.fillMaxSize().background(AppColors.Bg), contentAlignment = Alignment.Center) {
            LoadingView()
        }
        return
    }
    val post = state.post
    if (post == null) {
        Box(Modifier.fillMaxSize().background(AppColors.Bg), contentAlignment = Alignment.Center) {
            Text("帖子不存在或已删除", color = AppColors.Muted, fontSize = 14.sp)
        }
        return
    }

    var showMenu by remember { mutableStateOf(false) }
    var commentText by remember { mutableStateOf("") }
    val isMine = post.isMine == true || post.author?.userId == myUserId
    // 老师发布的孩子作品不可删（关联消课记录）
    val canDelete = isMine && !(post.author?.role == 2 && post.type == 2)

    Box(Modifier.fillMaxSize().background(AppColors.Bg)) {
        LazyColumn(
            contentPadding = PaddingValues(bottom = 88.dp),
            modifier = Modifier.fillMaxSize()
        ) {
            // 图片轮播
            item { PostGallery(post) }

            // 作者行
            item {
                AuthorRow(
                    post = post,
                    showFollow = !isMine,
                    onFollow = { viewModel.toggleFollow() }
                )
            }

            // 内容
            item { ContentSection(post) }

            // 课程卡（家长可报名）
            post.course?.let { course ->
                if (course.courseId.isNotEmpty()) {
                    item {
                        CourseCard(
                            course = course,
                            canEnroll = myRole == 1,
                            onEnroll = { onEnroll(course.courseId) }
                        )
                    }
                }
            }

            // 学生消课（老师帖）
            if (post.type == 2 && post.studentList.isNotEmpty()) {
                item {
                    StudentsSection(
                        post = post,
                        canUndo = isMine,
                        onUndo = { childId -> viewModel.undoStudent(postId, childId) }
                    )
                }
            }

            // 位置
            post.location?.takeIf { !it.name.isNullOrBlank() }?.let { loc ->
                item { LocationSection(loc, post.distanceText) }
            }

            // 评论区
            item {
                Text(
                    text = "评论 ${post.commentCount ?: 0}",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.Ink,
                    modifier = Modifier.padding(horizontal = AppDimens.L, vertical = AppDimens.M)
                )
            }
            if (state.commentRows.isEmpty()) {
                item {
                    Text(
                        text = "还没有评论，快来抢沙发",
                        fontSize = 13.sp,
                        color = AppColors.Muted,
                        modifier = Modifier.padding(horizontal = AppDimens.L).padding(bottom = AppDimens.L)
                    )
                }
            } else {
                items(state.commentRows, key = { it.comment.commentId }) { row ->
                    CommentRowItem(
                        row = row,
                        isMine = row.comment.user?.userId == myUserId,
                        onLike = { viewModel.toggleCommentLike(postId, row.comment.commentId) },
                        onReply = { viewModel.startReply(row) },
                        onDelete = { viewModel.deleteComment(row.comment.commentId) }
                    )
                }
            }
        }

        // 顶部导航（叠在图片上）
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(horizontal = AppDimens.M, vertical = AppDimens.S),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            // 返回
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(Color.Black.copy(alpha = 0.3f))
                    .clickable(onClick = onBack),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "返回",
                    tint = Color.White,
                    modifier = Modifier.size(20.dp)
                )
            }
            // 更多
            if (isMine) {
                Box {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(Color.Black.copy(alpha = 0.3f))
                            .clickable { showMenu = true },
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Filled.MoreVert,
                            contentDescription = "更多",
                            tint = Color.White,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                    DropdownMenu(expanded = showMenu, onDismissRequest = { showMenu = false }) {
                        DropdownMenuItem(
                            text = { Text("编辑") },
                            onClick = {
                                showMenu = false
                                onEdit(post)
                            }
                        )
                        if (canDelete) {
                            DropdownMenuItem(
                                text = { Text("删除", color = AppColors.Clay) },
                                onClick = {
                                    showMenu = false
                                    viewModel.deletePost(postId)
                                }
                            )
                        }
                    }
                }
            }
        }

        // 底部操作栏
        PostBottomBar(
            text = commentText,
            onTextChange = { commentText = it },
            replyingTo = state.replyingTo?.authorName,
            onCancelReply = { viewModel.cancelReply() },
            isLiked = post.isLiked == true,
            likeCount = post.likeCount ?: 0,
            isFavorite = post.isFavorite == true,
            onLike = { viewModel.toggleLike(postId) },
            onFavorite = { viewModel.toggleFavorite(postId) },
            onSend = {
                if (commentText.trim().isNotEmpty()) {
                    viewModel.sendComment(postId, commentText)
                    commentText = ""
                }
            }
        )
    }
}

// MARK: - 图片轮播

@Composable
private fun PostGallery(post: PostItem) {
    val images = post.imageList
    if (images.isEmpty()) return
    val pagerState = rememberPagerState(pageCount = { images.size })
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(340.dp)
            .background(AppColors.SurfaceAlt)
    ) {
        HorizontalPager(state = pagerState, modifier = Modifier.fillMaxSize()) { page ->
            AsyncImage(
                model = resolveImageUrl(images[page]),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )
        }
        // 页码指示器
        if (images.size > 1) {
            Box(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(AppDimens.M)
                    .clip(RoundedCornerShape(50))
                    .background(Color.Black.copy(alpha = 0.4f))
                    .padding(horizontal = AppDimens.S, vertical = 2.dp)
            ) {
                Text(
                    text = "${pagerState.currentPage + 1}/${images.size}",
                    color = Color.White,
                    fontSize = 11.sp
                )
            }
        }
    }
}

// MARK: - 作者行

@Composable
private fun AuthorRow(post: PostItem, showFollow: Boolean, onFollow: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L, vertical = AppDimens.M),
        verticalAlignment = Alignment.CenterVertically
    ) {
        TogetherAvatar(url = post.authorAvatar, name = post.authorName, size = 44.dp)
        Spacer(Modifier.width(AppDimens.S))
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = post.authorName,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.Ink,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                post.roleText.takeIf { it.isNotEmpty() }?.let { badge ->
                    Spacer(Modifier.width(AppDimens.Xs))
                    TogetherTag(text = badge, color = AppColors.Brand, bgColor = AppColors.BrandSoft)
                }
            }
            Text(
                text = "${post.timeText} · 广场",
                fontSize = 11.sp,
                color = AppColors.Muted
            )
        }
        // 关注按钮
        if (showFollow) {
            val following = post.isFollowing == true
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(if (following) AppColors.SurfaceAlt else AppColors.Brand)
                    .clickable(onClick = onFollow)
                    .padding(horizontal = AppDimens.M, vertical = AppDimens.Xs)
            ) {
                Text(
                    text = if (following) "已关注" else "+ 关注",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                    color = if (following) AppColors.Sub else Color.White
                )
            }
        }
    }
}

// MARK: - 内容区

@Composable
private fun ContentSection(post: PostItem) {
    Column(Modifier.padding(horizontal = AppDimens.L)) {
        // 正文
        if (post.bodyText.isNotEmpty()) {
            Text(
                text = post.bodyText,
                fontSize = 15.sp,
                lineHeight = 22.sp,
                color = AppColors.Ink
            )
        }
        // 话题 + 可见性
        val showTopic = post.safeTopic != null
        val notPublic = post.visibility != null && post.visibility != 2
        if (showTopic || notPublic) {
            Spacer(Modifier.height(AppDimens.S))
            Row(horizontalArrangement = Arrangement.spacedBy(AppDimens.Xs)) {
                post.safeTopic?.let { TogetherTag(text = "#$it") }
                if (notPublic) {
                    TogetherTag(text = post.visibilityText, color = AppColors.Muted, bgColor = AppColors.SurfaceAlt)
                }
            }
        }
        Spacer(Modifier.height(AppDimens.M))
    }
}

// MARK: - 课程卡

@Composable
private fun CourseCard(course: PostCourse, canEnroll: Boolean, onEnroll: () -> Unit) {
    Column(
        modifier = Modifier
            .padding(horizontal = AppDimens.L)
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.CardInner)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(
                    text = "关联课程",
                    fontSize = 11.sp,
                    color = AppColors.Muted
                )
                Spacer(Modifier.height(AppDimens.Xs))
                Text(
                    text = course.title ?: "未知课程",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.Ink,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            course.price?.let { price ->
                Text(
                    text = "¥${price.fenToYuanText()}",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.Clay
                )
            }
        }
        if (canEnroll) {
            Spacer(Modifier.height(AppDimens.S))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(AppDimens.RadiusButton))
                    .background(AppColors.Brand)
                    .clickable(onClick = onEnroll)
                    .padding(vertical = AppDimens.S),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "去报名",
                    color = Color.White,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
    }
    Spacer(Modifier.height(AppDimens.M))
}

// MARK: - 学生消课（老师帖）

@Composable
private fun StudentsSection(post: PostItem, canUndo: Boolean, onUndo: (String) -> Unit) {
    Column(
        modifier = Modifier
            .padding(horizontal = AppDimens.L)
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.CardInner)
    ) {
        Text(
            text = "上课学生",
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.Ink
        )
        Spacer(Modifier.height(AppDimens.S))
        post.studentList.forEach { student ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = AppDimens.Xs),
                verticalAlignment = Alignment.CenterVertically
            ) {
                TogetherAvatar(url = student.avatar, name = student.nickname ?: "学生", size = 32.dp)
                Spacer(Modifier.width(AppDimens.S))
                Text(
                    text = student.nickname ?: "学生",
                    fontSize = 13.sp,
                    color = AppColors.Ink,
                    modifier = Modifier.weight(1f)
                )
                if (student.deducted == true) {
                    TogetherTag(text = "已消课", color = AppColors.Brand, bgColor = AppColors.BrandSoft)
                    if (canUndo) {
                        Spacer(Modifier.width(AppDimens.Xs))
                        Text(
                            text = "撤销",
                            fontSize = 12.sp,
                            color = AppColors.Clay,
                            modifier = Modifier.clickable { onUndo(student.childId) }
                        )
                    }
                } else {
                    TogetherTag(text = "未消课", color = AppColors.Muted, bgColor = AppColors.SurfaceAlt)
                }
            }
        }
    }
    Spacer(Modifier.height(AppDimens.M))
}

// MARK: - 位置

@Composable
private fun LocationSection(location: PostLocation, distanceText: String?) {
    Row(
        modifier = Modifier
            .padding(horizontal = AppDimens.L)
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.CardInner),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "📍 ${location.name ?: "位置"}",
            fontSize = 13.sp,
            color = AppColors.Sub,
            modifier = Modifier.weight(1f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        distanceText?.let {
            Text(
                text = it,
                fontSize = 12.sp,
                color = AppColors.Muted
            )
        }
    }
    Spacer(Modifier.height(AppDimens.M))
}

// MARK: - 评论行

@Composable
private fun CommentRowItem(
    row: PlazaViewModel.CommentRow,
    isMine: Boolean,
    onLike: () -> Unit,
    onReply: () -> Unit,
    onDelete: () -> Unit
) {
    val comment = row.comment
    // level 0 不缩进 / level 1 缩进一档 / level 2 缩进两档
    val indent = when (row.level) {
        1 -> AppDimens.L
        2 -> AppDimens.L * 2
        else -> 0.dp
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = AppDimens.L + indent, end = AppDimens.L)
            .padding(vertical = AppDimens.Xs)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TogetherAvatar(url = comment.authorAvatar, name = comment.authorName, size = 32.dp)
            Spacer(Modifier.width(AppDimens.S))
            Column(Modifier.weight(1f)) {
                Text(
                    text = comment.authorName,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    color = AppColors.Sub,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = comment.timeText,
                    fontSize = 10.sp,
                    color = AppColors.Muted
                )
            }
            // 点赞
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.clickable(onClick = onLike)
            ) {
                Icon(
                    imageVector = if (comment.isLiked == true) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
                    contentDescription = null,
                    tint = if (comment.isLiked == true) AppColors.Clay else AppColors.Muted,
                    modifier = Modifier.size(14.dp)
                )
                if ((comment.likeCount ?: 0) > 0) {
                    Text(
                        text = " ${comment.likeCount}",
                        fontSize = 11.sp,
                        color = AppColors.Muted
                    )
                }
            }
        }
        Spacer(Modifier.height(AppDimens.Xs))
        // 内容（level 2 带"回复@xx："前缀）
        Row(Modifier.padding(start = 40.dp)) {
            val prefix = if (row.level == 2 && row.replyToName != null) "回复@${row.replyToName}：" else ""
            Text(
                text = prefix + comment.content,
                fontSize = 14.sp,
                lineHeight = 20.sp,
                color = AppColors.Ink
            )
        }
        // 操作：自己的评论→删除；别人的评论→回复
        Row(Modifier.padding(start = 40.dp).padding(top = AppDimens.Xs)) {
            if (isMine) {
                Text(
                    text = "删除",
                    fontSize = 11.sp,
                    color = AppColors.Muted,
                    modifier = Modifier.clickable(onClick = onDelete)
                )
            } else {
                Text(
                    text = "回复",
                    fontSize = 11.sp,
                    color = AppColors.Muted,
                    modifier = Modifier.clickable(onClick = onReply)
                )
            }
        }
    }
}

// MARK: - 底部操作栏

@Composable
private fun PostBottomBar(
    text: String,
    onTextChange: (String) -> Unit,
    replyingTo: String?,
    onCancelReply: () -> Unit,
    isLiked: Boolean,
    likeCount: Int,
    isFavorite: Boolean,
    onLike: () -> Unit,
    onFavorite: () -> Unit,
    onSend: () -> Unit
) {
    Column(
        modifier = Modifier
            .align(Alignment.BottomCenter)
            .fillMaxWidth()
            .background(AppColors.Surface)
            .navigationBarsPadding()
    ) {
        // 回复提示条
        if (replyingTo != null) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppColors.SurfaceAlt)
                    .padding(horizontal = AppDimens.L, vertical = AppDimens.Xs),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "回复 @$replyingTo",
                    fontSize = 12.sp,
                    color = AppColors.Sub,
                    modifier = Modifier.weight(1f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = "取消",
                    fontSize = 12.sp,
                    color = AppColors.Muted,
                    modifier = Modifier.clickable(onClick = onCancelReply)
                )
            }
        }
        // 分割线
        Box(Modifier.fillMaxWidth().height(0.5.dp).background(AppColors.Line))
        // 输入 + 操作
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = AppDimens.L, vertical = AppDimens.S),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // 输入胶囊
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(50))
                    .background(AppColors.SurfaceAlt)
                    .padding(horizontal = AppDimens.M, vertical = AppDimens.S)
            ) {
                BasicTextField(
                    value = text,
                    onValueChange = onTextChange,
                    singleLine = true,
                    textStyle = androidx.compose.ui.text.TextStyle(
                        fontSize = 14.sp,
                        color = AppColors.Ink
                    ),
                    modifier = Modifier.fillMaxWidth(),
                    cursorBrush = androidx.compose.ui.graphics.SolidColor(AppColors.Brand),
                    decorationBox = { inner ->
                        if (text.isEmpty()) {
                            Text("说点什么...", fontSize = 14.sp, color = AppColors.Muted)
                        }
                        inner()
                    }
                )
            }
            Spacer(Modifier.width(AppDimens.S))
            // 发送
            if (text.trim().isNotEmpty()) {
                Icon(
                    Icons.Filled.Send,
                    contentDescription = "发送",
                    tint = AppColors.Brand,
                    modifier = Modifier.size(22.dp).clickable(onClick = onSend)
                )
                Spacer(Modifier.width(AppDimens.S))
            }
            // 点赞
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.clickable(onClick = onLike)
            ) {
                Icon(
                    imageVector = if (isLiked) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
                    contentDescription = "点赞",
                    tint = if (isLiked) AppColors.Clay else AppColors.Muted,
                    modifier = Modifier.size(22.dp)
                )
                if (likeCount > 0) {
                    Text(
                        text = " $likeCount",
                        fontSize = 11.sp,
                        color = AppColors.Muted
                    )
                }
            }
            Spacer(Modifier.width(AppDimens.M))
            // 收藏
            Icon(
                imageVector = if (isFavorite) Icons.Filled.Bookmark else Icons.Filled.BookmarkBorder,
                contentDescription = "收藏",
                tint = if (isFavorite) AppColors.Brand else AppColors.Muted,
                modifier = Modifier.size(22.dp).clickable(onClick = onFavorite)
            )
        }
    }
}