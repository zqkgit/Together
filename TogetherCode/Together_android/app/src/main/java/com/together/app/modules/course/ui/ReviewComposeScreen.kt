package com.together.app.modules.course.ui

import android.app.Application
import android.content.Context
import android.net.Uri
import android.provider.MediaStore
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.component.resolveImageUrl
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.network.ApiService
import com.together.app.core.network.JsonHelper.strList
import com.together.app.services.CourseService
import com.together.app.services.MineService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.File

/**
 * 写评价 / 编辑评价 ViewModel
 */
class ReviewComposeViewModel(app: Application) : AndroidViewModel(app) {

    companion object {
        /** 编辑模式传入的评价对象 */
        var editReview: MineService.MyReviewItem? = null
    }

    data class UiState(
        val submitting: Boolean = false,
        val error: String? = null,
        val success: Boolean = false
    )

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    fun submit(
        isEditMode: Boolean,
        courseId: String,
        reviewId: String?,
        rating: Int,
        content: String,
        originImageUrls: List<String>,
        newImageUris: List<Uri>
    ) {
        if (_uiState.value.submitting) return
        _uiState.value = _uiState.value.copy(submitting = true, error = null)
        viewModelScope.launch {
            try {
                // 上传新选图片
                val uploadedUrls = if (newImageUris.isNotEmpty()) {
                    val files = newImageUris.map { uriToFile(it) }
                    val json = ApiService.upload(files, "review")
                    json.strList("urls")
                } else {
                    emptyList()
                }
                val allUrls = originImageUrls + uploadedUrls

                if (isEditMode && reviewId != null) {
                    CourseService.updateReview(reviewId, rating, content.ifBlank { null }, allUrls)
                } else {
                    CourseService.postReview(courseId, rating, content.ifBlank { null }, allUrls)
                }
                _uiState.value = _uiState.value.copy(submitting = false, success = true)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(submitting = false, error = e.message ?: "提交失败")
            }
        }
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    private fun uriToFile(uri: Uri): File {
        val context = getApplication<Application>()
        val input = context.contentResolver.openInputStream(uri)!!
        val file = File(context.cacheDir, "review_${System.currentTimeMillis()}_${(0..9999).random()}.jpg")
        input.use { input -> file.outputStream().use { input.copyTo(it) } }
        return file
    }
}

/**
 * 写评价 / 编辑评价（家长课后评课程）
 * 对齐 iOS ReviewComposeViewController
 */
@Composable
fun ReviewComposeScreen(
    courseId: String,
    courseTitle: String,
    isEditMode: Boolean = false,
    viewModel: ReviewComposeViewModel = viewModel(),
    onBack: () -> Unit = {}
) {
    val state by viewModel.uiState.collectAsState()
    val context = LocalContext.current

    // 编辑模式回显数据
    val editReview = if (isEditMode) ReviewComposeViewModel.editReview else null
    var rating by remember { mutableIntStateOf(editReview?.rating ?: 5) }
    var content by remember { mutableStateOf(editReview?.content ?: "") }
    val originImages = remember { editReview?.images ?: emptyList() }
    var newImages by remember { mutableStateOf<List<Uri>>(emptyList()) }

    val allCount = originImages.size + newImages.size
    val maxPick = (9 - allCount).coerceAtLeast(0)

    val imagePicker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(maxItems = 9)
    ) { uris ->
        if (uris.isNotEmpty()) {
            newImages = (newImages + uris).take(9 - originImages.size)
        }
    }

    // 提交成功 → 返回
    androidx.compose.runtime.LaunchedEffect(state.success) {
        if (state.success) {
            onBack()
        }
    }

    val ratingHint = when (rating) {
        1 -> "很不满意"
        2 -> "不满意"
        3 -> "一般"
        4 -> "满意"
        else -> "非常满意"
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = if (isEditMode) "编辑评价" else "写评价", onBack = onBack)

        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = AppDimens.M),
        ) {
            // 整体评分卡
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = AppDimens.L)
                    .clip(RoundedCornerShape(AppDimens.RadiusCard))
                    .background(AppColors.Surface)
                    .padding(vertical = AppDimens.L)
            ) {
                Text(
                    "整体评分",
                    fontSize = 14.sp, color = AppColors.Sub,
                    modifier = Modifier.padding(horizontal = AppDimens.CardInner)
                )
                Spacer(modifier = Modifier.height(AppDimens.M))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.Center
                ) {
                    for (i in 1..5) {
                        val filled = i <= rating
                        Text(
                            text = "★",
                            fontSize = 28.sp,
                            color = if (filled) AppColors.Clay else AppColors.Line,
                            modifier = Modifier
                                .padding(horizontal = AppDimens.S)
                                .clickable { rating = i }
                        )
                    }
                }
                Spacer(modifier = Modifier.height(AppDimens.S))
                Text(
                    ratingHint,
                    fontSize = 12.sp, color = AppColors.Muted,
                    modifier = Modifier.fillMaxWidth(),
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center
                )
            }

            // 评价内容卡
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = AppDimens.L)
                    .clip(RoundedCornerShape(AppDimens.RadiusCard))
                    .background(AppColors.Surface)
                    .padding(vertical = AppDimens.L)
            ) {
                Text(
                    "评价内容",
                    fontSize = 14.sp, color = AppColors.Sub,
                    modifier = Modifier.padding(horizontal = AppDimens.CardInner)
                )
                Spacer(modifier = Modifier.height(AppDimens.M))
                OutlinedTextField(
                    value = content,
                    onValueChange = { content = it },
                    placeholder = { Text("说说孩子上课的感受吧（选填）", fontSize = 14.sp, color = AppColors.Muted) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = AppDimens.CardInner)
                        .height(120.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = AppColors.Brand,
                        unfocusedBorderColor = AppColors.Line,
                        focusedContainerColor = Color.Transparent,
                        unfocusedContainerColor = Color.Transparent
                    ),
                    textStyle = androidx.compose.ui.text.TextStyle(fontSize = 14.sp, color = AppColors.Ink)
                )
            }

            // 晒图卡
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = AppDimens.L, bottom = AppDimens.Xl)
                    .clip(RoundedCornerShape(AppDimens.RadiusCard))
                    .background(AppColors.Surface)
                    .padding(vertical = AppDimens.L)
            ) {
                Text(
                    "晒图（选填）",
                    fontSize = 14.sp, color = AppColors.Sub,
                    modifier = Modifier.padding(horizontal = AppDimens.CardInner)
                )
                Spacer(modifier = Modifier.height(AppDimens.M))
                // 3列网格
                val items = mutableListOf<@Composable () -> Unit>()
                originImages.forEach { url ->
                    items.add {
                        ReviewImageCell(
                            model = resolveImageUrl(url),
                            onRemove = { /* 原图在编辑模式下不可移除（简化处理） */ }
                        )
                    }
                }
                newImages.forEach { uri ->
                    items.add {
                        ReviewImageCell(
                            model = uri,
                            onRemove = { newImages = newImages - uri }
                        )
                    }
                }
                if (allCount < 9) {
                    items.add {
                        Box(
                            modifier = Modifier
                                .size(80.dp)
                                .clip(RoundedCornerShape(AppDimens.RadiusIcon))
                                .background(AppColors.SurfaceAlt)
                                .clickable {
                                    imagePicker.launch(
                                        PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                                    )
                                },
                            contentAlignment = Alignment.Center
                        ) {
                            Text("+", fontSize = 24.sp, color = AppColors.Muted)
                        }
                    }
                }
                // 按行排列
                items.chunked(3).forEach { rowItems ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = AppDimens.CardInner, vertical = 3.dp),
                        horizontalArrangement = Arrangement.spacedBy(AppDimens.S)
                    ) {
                        rowItems.forEach { item -> item() }
                        // 补齐空位
                        repeat(3 - rowItems.size) {
                            Spacer(modifier = Modifier.width(80.dp))
                        }
                    }
                }
            }
        }

        // 底部提交栏
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.Surface)
                .padding(horizontal = AppDimens.M, vertical = 10.dp)
        ) {
            val canSubmit = !state.submitting
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(46.dp)
                    .clip(RoundedCornerShape(AppDimens.RadiusButton))
                    .background(if (canSubmit) AppColors.Brand else AppColors.Muted)
                    .clickable(canSubmit) {
                        viewModel.submit(
                            isEditMode = isEditMode,
                            courseId = courseId,
                            reviewId = editReview?.reviewId,
                            rating = rating,
                            content = content.trim(),
                            originImageUrls = originImages,
                            newImageUris = newImages
                        )
                    },
                contentAlignment = Alignment.Center
            ) {
                if (state.submitting) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        color = Color.White, strokeWidth = 2.dp
                    )
                } else {
                    Text(
                        if (isEditMode) "保存修改" else "提交评价",
                        color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Medium
                    )
                }
            }
        }

        // 错误 Toast
        state.error?.let { error ->
            androidx.compose.runtime.LaunchedEffect(error) {
                android.widget.Toast.makeText(context, error, android.widget.Toast.LENGTH_SHORT).show()
                viewModel.clearError()
            }
        }
    }
}

@Composable
private fun ReviewImageCell(model: Any?, onRemove: () -> Unit) {
    Box(modifier = Modifier.size(80.dp)) {
        AsyncImage(
            model = model,
            contentDescription = null,
            modifier = Modifier
                .size(80.dp)
                .clip(RoundedCornerShape(AppDimens.RadiusIcon)),
            contentScale = ContentScale.Crop
        )
        // 删除按钮
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .size(20.dp)
                .clip(CircleShape)
                .background(Color.Black.copy(alpha = 0.5f))
                .clickable { onRemove() },
            contentAlignment = Alignment.Center
        ) {
            Text("×", color = Color.White, fontSize = 12.sp)
        }
    }
}