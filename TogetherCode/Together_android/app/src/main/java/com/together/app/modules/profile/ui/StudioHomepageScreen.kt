package com.together.app.modules.profile.ui

import android.app.Application
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Business
import androidx.compose.material.icons.filled.ChatBubble
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Tag
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.app.TogetherApplication
import com.together.app.core.component.EmptyStateView
import com.together.app.core.component.LoadingView
import com.together.app.core.component.resolveImageUrl
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.model.ConversationItem
import com.together.app.services.MessageService
import com.together.app.services.ProfileService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * 工作室主页 ViewModel
 */
class StudioHomepageViewModel(app: Application) : AndroidViewModel(app) {

    data class UiState(
        val loading: Boolean = true,
        val data: ProfileService.StudioHomepageData? = null,
        val courses: List<ProfileService.StudioHomepageCourse> = emptyList(),
        val studentWorks: List<ProfileService.StudioStudentWork> = emptyList(),
        val coursesHasMore: Boolean = false,
        val studentWorksHasMore: Boolean = false,
        val error: String? = null,
        // 咨询
        val chatCreating: Boolean = false,
        // 是否显示咨询/电话按钮（非本人工作室）
        val showNavButtons: Boolean = false
    )

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    private var studioId = ""
    private var coursePage = 1
    private var studentWorkPage = 1

    private val tokenStore get() = getApplication<TogetherApplication>().tokenStore

    fun init(studioId: String) {
        if (this.studioId == studioId && _uiState.value.data != null) return
        this.studioId = studioId
        loadAll()
    }

    private fun loadAll() {
        loadHomepage(reset = true)
        loadStudentWorks(reset = true)
    }

    private fun loadHomepage(reset: Boolean) {
        if (reset) coursePage = 1
        viewModelScope.launch {
            try {
                val data = ProfileService.fetchStudioHomepage(studioId, coursePage)
                val newCourses = if (reset || coursePage <= 1) data.courses?.list ?: emptyList()
                else _uiState.value.courses + (data.courses?.list ?: emptyList())
                // 判断是否显示咨询/电话按钮：工作室 userId 存在且非本人
                val myUserId = try { tokenStore.getUserIdSync() } catch (_: Exception) { null }
                val studioUserId = data.studio?.userId
                val showNav = !studioUserId.isNullOrEmpty() && studioUserId != myUserId
                _uiState.value = _uiState.value.copy(
                    loading = false,
                    data = data,
                    courses = newCourses,
                    coursesHasMore = newCourses.size < (data.courses?.total ?: 0),
                    showNavButtons = showNav,
                    error = null
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    private fun loadStudentWorks(reset: Boolean) {
        if (reset) studentWorkPage = 1
        viewModelScope.launch {
            try {
                val page = ProfileService.fetchStudioStudentWorks(studioId, studentWorkPage)
                val newList = if (reset || studentWorkPage <= 1) page.list ?: emptyList()
                else _uiState.value.studentWorks + (page.list ?: emptyList())
                _uiState.value = _uiState.value.copy(
                    studentWorks = newList,
                    studentWorksHasMore = newList.size < (page.total ?: 0)
                )
            } catch (_: Exception) { }
        }
    }

    fun loadMoreCourses() {
        if (!_uiState.value.coursesHasMore) return
        coursePage++
        loadHomepage(reset = false)
    }

    fun loadMoreStudentWorks() {
        if (!_uiState.value.studentWorksHasMore) return
        studentWorkPage++
        loadStudentWorks(reset = false)
    }

    /** 咨询工作室：创建会话（对齐 iOS didTapChat） */
    fun createConversation(peerUserId: String, onResult: (ConversationItem?) -> Unit) {
        if (_uiState.value.chatCreating) return
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(chatCreating = true)
            try {
                val conversation = MessageService.createConversation(peerUserId)
                _uiState.value = _uiState.value.copy(chatCreating = false)
                onResult(conversation)
            } catch (_: Exception) {
                _uiState.value = _uiState.value.copy(chatCreating = false)
                onResult(null)
            }
        }
    }
}

/**
 * 工作室主页（家长视角）：渐变头部 + 统计卡 + 课程/学员作品/老师/介绍四 tab
 * 对齐 iOS StudioHomepageViewController
 */
@Composable
fun StudioHomepageScreen(
    studioId: String,
    viewModel: StudioHomepageViewModel = viewModel(),
    onBack: () -> Unit = {},
    onCourseClick: (String) -> Unit = {},
    onTeacherClick: (String) -> Unit = {},
    onPostClick: (String) -> Unit = {},
    onChat: (ConversationItem) -> Unit = {}
) {
    val state by viewModel.uiState.collectAsState()
    var selectedTab by remember { mutableIntStateOf(0) }
    val context = LocalContext.current

    LaunchedEffect(studioId) { viewModel.init(studioId) }

    if (state.loading) {
        LoadingView()
        return
    }

    val studio = state.data?.studio

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        // 渐变头部
        StudioHomepageHeader(
            name = studio?.displayName ?: "工作室",
            cover = studio?.cover,
            tags = studio?.tagsText ?: "",
            location = studio?.locationText ?: "",
            courseCount = studio?.courseCount ?: 0,
            teacherCount = studio?.teacherCount ?: 0,
            rating = studio?.rating,
            showNavButtons = state.showNavButtons,
            chatCreating = state.chatCreating,
            onBack = onBack,
            onChat = {
                val uid = studio?.userId
                if (uid.isNullOrEmpty()) {
                    Toast.makeText(context, "无法获取工作室信息", Toast.LENGTH_SHORT).show()
                } else {
                    viewModel.createConversation(uid) { conversation ->
                        if (conversation != null) onChat(conversation)
                        else Toast.makeText(context, "创建会话失败", Toast.LENGTH_SHORT).show()
                    }
                }
            },
            onCall = {
                val phone = studio?.phone
                if (phone.isNullOrEmpty()) {
                    Toast.makeText(context, "暂无联系电话", Toast.LENGTH_SHORT).show()
                } else {
                    context.startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phone")))
                }
            }
        )

        // Tab 栏（对齐 iOS UISegmentedControl：选中 brand 底 + 白字）
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = AppDimens.L, vertical = AppDimens.S)
                .clip(RoundedCornerShape(8.dp))
                .background(AppColors.SurfaceAlt)
                .padding(2.dp),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            listOf("课程", "学员作品", "老师", "介绍").forEachIndexed { index, title ->
                val selected = selectedTab == index
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(6.dp))
                        .background(if (selected) AppColors.Brand else Color.Transparent)
                        .clickable { selectedTab = index }
                        .padding(vertical = 6.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = title,
                        fontSize = 13.sp,
                        fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                        color = if (selected) Color.White else AppColors.Sub
                    )
                }
            }
        }

        // 内容区
        Box(modifier = Modifier.weight(1f)) {
            when (selectedTab) {
                0 -> {
                    if (state.courses.isEmpty()) {
                        EmptyStateView(message = "暂无课程\n工作室发布课程后会展示在这里")
                    } else {
                        val listState = rememberLazyListState()
                        snapshotFlowCheck(listState) { viewModel.loadMoreCourses() }
                        LazyColumn(
                            state = listState,
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(horizontal = AppDimens.M, vertical = AppDimens.S)
                        ) {
                            items(state.courses, key = { it.courseId }) { course ->
                                StudioCourseCard(course, onClick = { onCourseClick(course.courseId) })
                            }
                        }
                    }
                }
                1 -> {
                    if (state.studentWorks.isEmpty()) {
                        EmptyStateView(message = "暂无学员作品\n老师发布学员作品后会展示在这里")
                    } else {
                        val listState = rememberLazyListState()
                        snapshotFlowCheck(listState) { viewModel.loadMoreStudentWorks() }
                        LazyColumn(
                            state = listState,
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(horizontal = AppDimens.M, vertical = AppDimens.S)
                        ) {
                            items(state.studentWorks, key = { it.postId }) { work ->
                                StudioStudentWorkCard(work, onClick = { onPostClick(work.postId) })
                            }
                        }
                    }
                }
                2 -> {
                    val teachers = state.data?.teachers ?: emptyList()
                    if (teachers.isEmpty()) {
                        EmptyStateView(message = "暂无老师")
                    } else {
                        LazyColumn(
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(horizontal = AppDimens.M, vertical = AppDimens.S)
                        ) {
                            items(teachers, key = { it.teacherId }) { teacher ->
                                StudioTeacherCard(teacher, onClick = { onTeacherClick(teacher.teacherId) })
                            }
                        }
                    }
                }
                3 -> {
                    StudioIntroTab(studio = studio, photos = studio?.photos ?: emptyList())
                }
            }
        }
    }
}
// MARK: - 渐变头部

@Composable
private fun StudioHomepageHeader(
    name: String,
    cover: String?,
    tags: String,
    location: String,
    courseCount: Int,
    teacherCount: Int,
    rating: Double?,
    showNavButtons: Boolean,
    chatCreating: Boolean,
    onBack: () -> Unit,
    onChat: () -> Unit,
    onCall: () -> Unit
) {
    val gradient = Brush.linearGradient(
        colors = listOf(AppColors.Brand, AppColors.BrandDark),
        start = androidx.compose.ui.geometry.Offset(0f, 0f),
        end = androidx.compose.ui.geometry.Offset(800f, 1000f)
    )
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(gradient)
    ) {
        // 装饰圆（对齐 iOS orb）
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .offset(x = 30.dp, y = 8.dp)
                .size(100.dp)
                .clip(CircleShape)
                .background(AppColors.Wood.copy(alpha = 0.15f))
        )
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(horizontal = AppDimens.L)
                .padding(top = AppDimens.S, bottom = AppDimens.L)
        ) {
            // 返回 + 咨询/电话按钮
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(Color.Black.copy(alpha = 0.28f))
                        .clickable { onBack() },
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回", tint = Color.White, modifier = Modifier.size(18.dp))
                }
                Spacer(modifier = Modifier.weight(1f))
                if (showNavButtons) {
                    // 咨询按钮
                    Box(
                        modifier = Modifier
                            .size(32.dp)
                            .clip(CircleShape)
                            .background(AppColors.Brand.copy(alpha = 0.6f))
                            .clickable { onChat() },
                        contentAlignment = Alignment.Center
                    ) {
                        if (chatCreating) {
                            androidx.compose.material3.CircularProgressIndicator(color = Color.White, modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                        } else {
                            Icon(Icons.Default.ChatBubble, contentDescription = "咨询", tint = Color.White, modifier = Modifier.size(16.dp))
                        }
                    }
                    Spacer(modifier = Modifier.width(AppDimens.S))
                    // 电话按钮
                    Box(
                        modifier = Modifier
                            .size(32.dp)
                            .clip(CircleShape)
                            .background(Color.Black.copy(alpha = 0.3f))
                            .clickable { onCall() },
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.Default.Phone, contentDescription = "电话", tint = Color.White, modifier = Modifier.size(16.dp))
                    }
                }
            }
            Spacer(modifier = Modifier.height(AppDimens.M))

            // 封面 + 名称
            Row(verticalAlignment = Alignment.CenterVertically) {
                AsyncImage(
                    model = resolveImageUrl(cover),
                    contentDescription = null,
                    modifier = Modifier.size(56.dp).clip(RoundedCornerShape(28.dp)),
                    contentScale = ContentScale.Crop
                )
                Spacer(modifier = Modifier.width(AppDimens.M))
                Column(modifier = Modifier.weight(1f)) {
                    Text(name, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color.White)
                    if (tags.isNotEmpty()) {
                        Spacer(modifier = Modifier.height(3.dp))
                        Text(tags, fontSize = 12.sp, color = Color.White.copy(alpha = 0.85f), maxLines = 1)
                    }
                    if (location.isNotEmpty()) {
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(location, fontSize = 12.sp, color = Color.White.copy(alpha = 0.7f), maxLines = 1)
                    }
                }
            }

            // 统计卡
            Spacer(modifier = Modifier.height(AppDimens.L))
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(AppDimens.RadiusCard))
                    .background(Color.White.copy(alpha = 0.13f))
                    .padding(vertical = 12.dp),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                val r = rating ?: 0.0
                StatItem("课程数", "$courseCount")
                Box(
                    modifier = Modifier.width(0.5.dp).height(28.dp).align(Alignment.CenterVertically)
                        .background(Color.White.copy(alpha = 0.16f))
                ) {}
                StatItem("老师数", "$teacherCount")
                Box(
                    modifier = Modifier.width(0.5.dp).height(28.dp).align(Alignment.CenterVertically)
                        .background(Color.White.copy(alpha = 0.16f))
                ) {}
                StatItem("评分", if (r > 0) String.format("%.1f", r) else "—")
            }
        }
    }
}

@Composable
private fun StatItem(label: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(value, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = Color.White)
        Text(label, fontSize = 11.sp, color = Color.White.copy(alpha = 0.75f))
    }
}

// MARK: - 课程卡片

@Composable
private fun StudioCourseCard(course: ProfileService.StudioHomepageCourse, onClick: () -> Unit = {}) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable { onClick() }
            .padding(horizontal = AppDimens.CardInner, vertical = AppDimens.M)
    ) {
        AsyncImage(
            model = resolveImageUrl(course.cover),
            contentDescription = null,
            modifier = Modifier.size(72.dp).clip(RoundedCornerShape(10.dp)),
            contentScale = ContentScale.Crop
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(course.title, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Ink, maxLines = 2)
            Spacer(modifier = Modifier.height(4.dp))
            Text(course.detailText, fontSize = 12.sp, color = AppColors.Sub)
            Spacer(modifier = Modifier.height(4.dp))
            Text(course.priceText, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Clay)
        }
    }
}

// MARK: - 学员作品卡片

@Composable
private fun StudioStudentWorkCard(work: ProfileService.StudioStudentWork, onClick: () -> Unit = {}) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable { onClick() }
            .padding(horizontal = AppDimens.CardInner, vertical = AppDimens.M)
    ) {
        work.firstImage?.let { img ->
            AsyncImage(
                model = resolveImageUrl(img),
                contentDescription = null,
                modifier = Modifier.size(80.dp).clip(RoundedCornerShape(10.dp)),
                contentScale = ContentScale.Crop
            )
            Spacer(modifier = Modifier.width(12.dp))
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(work.content ?: "学员作品", fontSize = 14.sp, color = AppColors.Ink, maxLines = 2, lineHeight = 20.sp)
            Spacer(modifier = Modifier.height(4.dp))
            work.createdAt?.takeIf { it.length >= 10 }?.let {
                Text(it.take(10), fontSize = 11.sp, color = AppColors.Muted)
            }
            val likes = work.likeCount ?: 0
            val comments = work.commentCount ?: 0
            if (likes > 0 || comments > 0) {
                Spacer(modifier = Modifier.height(2.dp))
                val parts = mutableListOf<String>()
                if (likes > 0) parts.add("❤️ $likes")
                if (comments > 0) parts.add("💬 $comments")
                Text(parts.joinToString("  "), fontSize = 11.sp, color = AppColors.Sub)
            }
        }
    }
}

// MARK: - 老师卡片

@Composable
private fun StudioTeacherCard(teacher: ProfileService.StudioHomepageTeacher, onClick: () -> Unit = {}) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .clickable { onClick() }
            .padding(horizontal = AppDimens.CardInner, vertical = AppDimens.M),
        verticalAlignment = Alignment.CenterVertically
    ) {
        AsyncImage(
            model = resolveImageUrl(teacher.avatar),
            contentDescription = null,
            modifier = Modifier.size(44.dp).clip(CircleShape),
            contentScale = ContentScale.Crop
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(teacher.displayName, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Ink)
            Spacer(modifier = Modifier.height(4.dp))
            Text(teacher.subtitle, fontSize = 12.sp, color = AppColors.Sub, maxLines = 2)
        }
        Text("›", fontSize = 20.sp, color = AppColors.Muted)
    }
}

// MARK: - 介绍 Tab

@Composable
private fun StudioIntroTab(
    studio: ProfileService.StudioHomepageInfo?,
    photos: List<String>
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = AppDimens.M, vertical = AppDimens.S),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        // 工作室介绍
        studio?.intro?.takeIf { it.isNotEmpty() }?.let { intro ->
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(AppDimens.RadiusCard))
                        .background(AppColors.Surface)
                        .padding(horizontal = AppDimens.CardInner, vertical = AppDimens.L)
                ) {
                    Text("工作室介绍", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Ink)
                    Spacer(modifier = Modifier.height(AppDimens.S))
                    Text(intro, fontSize = 14.sp, color = AppColors.Sub, lineHeight = 20.sp)
                }
            }
        }
        // 详情信息（图标行，对齐 iOS StudioDetailInfoCell）
        studio?.let { s ->
            val hasDetail = !s.address.isNullOrEmpty() || !s.hours.isNullOrEmpty() ||
                !s.city.isNullOrEmpty() || !s.businessType.isNullOrEmpty() || !s.phone.isNullOrEmpty()
            if (hasDetail) {
                item {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(AppDimens.RadiusCard))
                            .background(AppColors.Surface)
                            .padding(horizontal = AppDimens.CardInner, vertical = AppDimens.L),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        s.address?.takeIf { it.isNotEmpty() }?.let {
                            IntroIconRow(Icons.Default.LocationOn, it)
                        }
                        s.hours?.takeIf { it.isNotEmpty() }?.let {
                            IntroIconRow(Icons.Default.Schedule, it)
                        }
                        s.city?.takeIf { it.isNotEmpty() }?.let {
                            IntroIconRow(Icons.Default.Business, it)
                        }
                        s.businessType?.takeIf { it.isNotEmpty() }?.let {
                            IntroIconRow(Icons.Default.Tag, it)
                        }
                        s.phone?.takeIf { it.isNotEmpty() }?.let {
                            IntroIconRow(Icons.Default.Phone, it)
                        }
                    }
                }
            }
        }
        // 环境照片（横滑，对齐 iOS StudioPhotoSectionCell）
        if (photos.isNotEmpty()) {
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(AppDimens.RadiusCard))
                        .background(AppColors.Surface)
                        .padding(vertical = AppDimens.L)
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = AppDimens.CardInner),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("环境照片", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Ink)
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("(${photos.size})", fontSize = 12.sp, color = AppColors.Muted)
                    }
                    Spacer(modifier = Modifier.height(AppDimens.S))
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState())
                            .padding(horizontal = AppDimens.CardInner),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        photos.forEach { url ->
                            AsyncImage(
                                model = resolveImageUrl(url),
                                contentDescription = null,
                                modifier = Modifier
                                    .width(240.dp)
                                    .height(170.dp)
                                    .clip(RoundedCornerShape(AppDimens.RadiusCard)),
                                contentScale = ContentScale.Crop
                            )
                        }
                    }
                }
            }
        }
    }
}

/** 详情信息图标行（对齐 iOS makeRow：图标 + 文本） */
@Composable
private fun IntroIconRow(icon: ImageVector, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = AppColors.Brand, modifier = Modifier.size(16.dp))
        Spacer(modifier = Modifier.width(8.dp))
        Text(text, fontSize = 14.sp, color = AppColors.Ink, maxLines = 2, modifier = Modifier.weight(1f))
    }
}