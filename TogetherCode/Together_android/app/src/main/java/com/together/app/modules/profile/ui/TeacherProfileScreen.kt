package com.together.app.modules.profile.ui

import android.app.Application
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
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.core.component.EmptyStateView
import com.together.app.core.component.LoadingView
import com.together.app.core.component.resolveImageUrl
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.services.ProfileService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * 老师主页 ViewModel
 */
class TeacherProfileViewModel(app: Application) : AndroidViewModel(app) {

    data class UiState(
        val loading: Boolean = true,
        val data: ProfileService.TeacherProfileData? = null,
        val works: List<ProfileService.WorkItem> = emptyList(),
        val studentWorks: List<ProfileService.WorkItem> = emptyList(),
        val reviews: List<ProfileService.TeacherReview> = emptyList(),
        val worksHasMore: Boolean = false,
        val studentWorksHasMore: Boolean = false,
        val reviewsHasMore: Boolean = false,
        val error: String? = null
    )

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    private var teacherId = ""
    private var workPage = 1
    private var studentWorkPage = 1
    private var reviewPage = 1

    fun init(teacherId: String) {
        if (this.teacherId == teacherId && _uiState.value.data != null) return
        this.teacherId = teacherId
        loadAll()
    }

    private fun loadAll() {
        loadHomepage(reset = true)
        loadStudentWorks(reset = true)
        loadReviews(reset = true)
    }

    private fun loadHomepage(reset: Boolean) {
        if (reset) workPage = 1
        viewModelScope.launch {
            try {
                val data = ProfileService.fetchTeacherHomepage(teacherId, workPage)
                val newWorks = if (reset || workPage <= 1) data.works?.list ?: emptyList()
                else _uiState.value.works + (data.works?.list ?: emptyList())
                _uiState.value = _uiState.value.copy(
                    loading = false,
                    data = data,
                    works = newWorks,
                    worksHasMore = newWorks.size < (data.works?.total ?: 0),
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
                val page = ProfileService.fetchTeacherStudentWorks(teacherId, studentWorkPage)
                val newList = if (reset || studentWorkPage <= 1) page.list ?: emptyList()
                else _uiState.value.studentWorks + (page.list ?: emptyList())
                _uiState.value = _uiState.value.copy(
                    studentWorks = newList,
                    studentWorksHasMore = newList.size < (page.total ?: 0)
                )
            } catch (_: Exception) { }
        }
    }

    private fun loadReviews(reset: Boolean) {
        if (reset) reviewPage = 1
        viewModelScope.launch {
            try {
                val data = ProfileService.fetchTeacherReviews(teacherId, reviewPage)
                val newList = if (reset || reviewPage <= 1) data.list ?: emptyList()
                else _uiState.value.reviews + (data.list ?: emptyList())
                _uiState.value = _uiState.value.copy(
                    reviews = newList,
                    reviewsHasMore = newList.size < (data.total ?: 0)
                )
            } catch (_: Exception) { }
        }
    }

    fun loadMoreWorks() {
        if (!_uiState.value.worksHasMore) return
        workPage++
        loadHomepage(reset = false)
    }

    fun loadMoreStudentWorks() {
        if (!_uiState.value.studentWorksHasMore) return
        studentWorkPage++
        loadStudentWorks(reset = false)
    }

    fun loadMoreReviews() {
        if (!_uiState.value.reviewsHasMore) return
        reviewPage++
        loadReviews(reset = false)
    }
}

/**
 * 老师主页（家长视角）：渐变头部 + 统计 + 作品/学员作品/评价三 tab
 * 对齐 iOS TeacherProfileViewController
 */
@Composable
fun TeacherProfileScreen(
    teacherId: String,
    viewModel: TeacherProfileViewModel = viewModel(),
    onBack: () -> Unit = {},
    onCourseClick: (String) -> Unit = {}
) {
    val state by viewModel.uiState.collectAsState()
    var selectedTab by remember { mutableIntStateOf(0) }

    LaunchedEffect(teacherId) { viewModel.init(teacherId) }

    if (state.loading) {
        LoadingView()
        return
    }

    val profile = state.data?.profile
    val user = state.data?.user

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        // 渐变头部
        TeacherProfileHeader(
            name = profile?.displayName ?: user?.nickname ?: "老师",
            avatar = user?.avatar,
            subjects = profile?.subjectsText ?: "",
            years = profile?.yearsText ?: "",
            rating = profile?.rating,
            studentCount = profile?.studentCount ?: 0,
            workCount = profile?.workCount ?: 0,
            fans = profile?.fans ?: 0,
            intro = profile?.intro,
            onBack = onBack
        )

        // Tab 栏
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = AppDimens.L, vertical = AppDimens.S)
                .clip(RoundedCornerShape(8.dp))
                .background(AppColors.SurfaceAlt)
                .padding(2.dp),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            listOf("作品", "学员作品", "评价").forEachIndexed { index, title ->
                val selected = selectedTab == index
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(6.dp))
                        .background(if (selected) AppColors.Surface else Color.Transparent)
                        .clickable { selectedTab = index }
                        .padding(vertical = 6.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = title,
                        fontSize = 13.sp,
                        fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                        color = if (selected) AppColors.Brand else AppColors.Sub
                    )
                }
            }
        }

        // 内容区
        Box(modifier = Modifier.weight(1f)) {
            when (selectedTab) {
                0 -> {
                    if (state.works.isEmpty()) {
                        EmptyStateView(message = "还没有作品\n老师发布作品后会展示在这里")
                    } else {
                        val listState = rememberLazyListState()
                        snapshotFlowCheck(listState) { viewModel.loadMoreWorks() }
                        LazyColumn(
                            state = listState,
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(horizontal = AppDimens.M, vertical = AppDimens.S)
                        ) {
                            items(state.works, key = { it.postId }) { work -> WorkCard(work) }
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
                            items(state.studentWorks, key = { it.postId }) { work -> WorkCard(work) }
                        }
                    }
                }
                2 -> {
                    if (state.reviews.isEmpty()) {
                        EmptyStateView(message = "暂无评价\n家长评价后会展示在这里")
                    } else {
                        val listState = rememberLazyListState()
                        snapshotFlowCheck(listState) { viewModel.loadMoreReviews() }
                        LazyColumn(
                            state = listState,
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(horizontal = AppDimens.M, vertical = AppDimens.S)
                        ) {
                            items(state.reviews, key = { it.reviewId ?: "" }) { review ->
                                ProfileReviewCard(review)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TeacherProfileHeader(
    name: String,
    avatar: String?,
    subjects: String,
    years: String,
    rating: Double?,
    studentCount: Int,
    workCount: Int,
    fans: Int,
    intro: String?,
    onBack: () -> Unit
) {
    val gradient = Brush.verticalGradient(
        colors = listOf(AppColors.Brand, AppColors.BrandLight, AppColors.Bg),
        startY = 0f, endY = 600f
    )
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(gradient)
            .statusBarsPadding()
            .padding(horizontal = AppDimens.L)
            .padding(top = AppDimens.S, bottom = AppDimens.L)
    ) {
        // 返回按钮
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(CircleShape)
                .background(Color.Black.copy(alpha = 0.28f))
                .clickable { onBack() },
            contentAlignment = Alignment.Center
        ) {
            Text("‹", color = Color.White, fontSize = 20.sp)
        }
        Spacer(modifier = Modifier.height(AppDimens.M))

        Row(verticalAlignment = Alignment.CenterVertically) {
            AsyncImage(
                model = resolveImageUrl(avatar),
                contentDescription = null,
                modifier = Modifier.size(64.dp).clip(CircleShape),
                contentScale = ContentScale.Crop
            )
            Spacer(modifier = Modifier.width(AppDimens.M))
            Column(modifier = Modifier.weight(1f)) {
                Text(name, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = Color.White)
                if (subjects.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(subjects, fontSize = 12.sp, color = Color.White.copy(alpha = 0.8f), maxLines = 1)
                }
                if (years.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(years, fontSize = 12.sp, color = Color.White.copy(alpha = 0.8f))
                }
            }
        }

        // 统计行
        Spacer(modifier = Modifier.height(AppDimens.M))
        Row(horizontalArrangement = Arrangement.spacedBy(AppDimens.L)) {
            val r = rating ?: 0.0
            StatItem("评分", if (r > 0) String.format("%.1f", r) else "—")
            StatItem("学员", "$studentCount")
            StatItem("作品", "$workCount")
            StatItem("粉丝", "$fans")
        }

        // 简介
        intro?.takeIf { it.isNotBlank() }?.let {
            Spacer(modifier = Modifier.height(AppDimens.M))
            Text(it, fontSize = 13.sp, color = Color.White.copy(alpha = 0.85f), lineHeight = 18.sp, maxLines = 3)
        }
    }
}

@Composable
private fun StatItem(label: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color.White)
        Text(label, fontSize = 11.sp, color = Color.White.copy(alpha = 0.7f))
    }
}

@Composable
private fun WorkCard(work: ProfileService.WorkItem) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(AppDimens.M)
    ) {
        work.firstImage?.let { img ->
            AsyncImage(
                model = resolveImageUrl(img),
                contentDescription = null,
                modifier = Modifier.size(80.dp).clip(RoundedCornerShape(AppDimens.RadiusIcon)),
                contentScale = ContentScale.Crop
            )
            Spacer(modifier = Modifier.width(AppDimens.M))
        }
        Column(modifier = Modifier.weight(1f)) {
            work.content?.takeIf { it.isNotEmpty() }?.let {
                Text(it, fontSize = 14.sp, color = AppColors.Ink, maxLines = 3, lineHeight = 20.sp)
            }
            Spacer(modifier = Modifier.height(4.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(AppDimens.M)) {
                val likes = work.likeCount ?: 0
                val comments = work.commentCount ?: 0
                if (likes > 0) Text("❤️ $likes", fontSize = 12.sp, color = AppColors.Muted)
                if (comments > 0) Text("💬 $comments", fontSize = 12.sp, color = AppColors.Muted)
            }
        }
    }
}

@Composable
private fun ProfileReviewCard(review: ProfileService.TeacherReview) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .clip(RoundedCornerShape(AppDimens.RadiusCard))
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.CardInner, vertical = AppDimens.L)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier.size(32.dp).clip(CircleShape).background(AppColors.SurfaceAlt),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = (review.user?.nickname ?: "家").take(1),
                    fontSize = 13.sp, color = AppColors.Wood
                )
            }
            Spacer(modifier = Modifier.width(AppDimens.S))
            Column(modifier = Modifier.weight(1f)) {
                Text(review.user?.nickname ?: "家长", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = AppColors.Ink)
                Text(review.starsText, fontSize = 12.sp, color = AppColors.Wood)
            }
            Text(review.dateText, fontSize = 11.sp, color = AppColors.Muted)
        }
        review.content?.takeIf { it.isNotEmpty() }?.let {
            Spacer(modifier = Modifier.height(AppDimens.S))
            Text(it, fontSize = 14.sp, color = AppColors.Ink, lineHeight = 20.sp)
        }
        review.course?.title?.takeIf { it.isNotEmpty() }?.let {
            Spacer(modifier = Modifier.height(AppDimens.S))
            Text(it, fontSize = 11.sp, color = AppColors.Sub)
        }
    }
}

/** LazyListState 滚动到底部触发加载更多的辅助（供 profile 包内复用） */
@Composable
internal fun snapshotFlowCheck(listState: androidx.compose.foundation.lazy.LazyListState, onLoadMore: () -> Unit) {
    LaunchedEffect(listState) {
        androidx.compose.runtime.snapshotFlow {
            val last = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            val total = listState.layoutInfo.totalItemsCount
            last >= total - 3 && total > 0
        }.collect { shouldLoad -> if (shouldLoad) onLoadMore() }
    }
}