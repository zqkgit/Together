package com.together.app.modules.course

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.together.app.app.TogetherApplication
import com.together.app.core.model.ChildItem
import com.together.app.core.model.CourseClassItem
import com.together.app.core.model.CourseDetail
import com.together.app.core.model.CourseReviewItem
import com.together.app.services.CourseService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/**
 * 课程详情 ViewModel（对齐 iOS CourseDetailViewController）
 */
class CourseDetailViewModel(app: Application) : AndroidViewModel(app) {

    data class UiState(
        val loading: Boolean = true,
        val course: CourseDetail? = null,
        val reviews: List<CourseReviewItem> = emptyList(),
        val reviewSummary: CourseService.CourseReviewSummary? = null,
        val error: String? = null,
        // 报名相关
        val children: List<ChildItem> = emptyList(),
        val selectedChildId: String = "",
        val selectedClassId: String = "",
        val enrolling: Boolean = false,
        val enrollError: String? = null,
        val enrolledOrderId: String? = null
    )

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState

    private val tokenStore get() = getApplication<TogetherApplication>().tokenStore

    /** 仅家长角色可报名 */
    private var _canEnroll = true
    val canEnroll: Boolean get() = _canEnroll

    init {
        viewModelScope.launch {
            _canEnroll = try { tokenStore.getRoleSync() == 1 } catch (_: Exception) { true }
        }
    }

    fun load(courseId: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(loading = true, error = null)
            try {
                val detail = CourseService.fetchDetail(courseId)
                val (reviews, summary) = try {
                    CourseService.fetchReviews(courseId)
                } catch (_: Exception) {
                    emptyList<CourseReviewItem>() to null
                }
                // 预选第一个班级
                val firstClass = detail?.classes?.firstOrNull()?.classId ?: ""
                _uiState.value = _uiState.value.copy(
                    loading = false,
                    course = detail,
                    reviews = reviews,
                    reviewSummary = summary,
                    selectedClassId = firstClass
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    /** 加载我的孩子（报名时需要） */
    fun loadChildren() {
        if (_uiState.value.children.isNotEmpty()) return
        viewModelScope.launch {
            try {
                val children = CourseService.fetchChildren()
                _uiState.value = _uiState.value.copy(
                    children = children,
                    selectedChildId = children.firstOrNull()?.childId ?: ""
                )
            } catch (_: Exception) { }
        }
    }

    fun selectChild(childId: String) {
        _uiState.value = _uiState.value.copy(selectedChildId = childId)
    }

    fun selectClass(classId: String) {
        _uiState.value = _uiState.value.copy(selectedClassId = classId)
    }

    /** 报名（创建订单） */
    fun enroll(courseId: String, onSuccess: (String) -> Unit) {
        val s = _uiState.value
        if (s.enrolling) return
        if (s.selectedChildId.isEmpty()) {
            _uiState.value = s.copy(enrollError = "请选择孩子")
            return
        }
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(enrolling = true, enrollError = null)
            try {
                val orderId = CourseService.createOrder(
                    childId = s.selectedChildId,
                    courseId = courseId,
                    classId = s.selectedClassId.ifEmpty { null }
                )
                _uiState.value = _uiState.value.copy(enrolling = false, enrolledOrderId = orderId)
                onSuccess(orderId)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(enrolling = false, enrollError = e.message ?: "报名失败")
            }
        }
    }
}