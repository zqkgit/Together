package com.together.app.modules.course

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.together.app.app.TogetherApplication
import com.together.app.core.model.CourseItem
import com.together.app.services.SearchService
import com.together.app.services.SearchService.TagItem
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/**
 * 课程列表 ViewModel（对齐 iOS CourseViewController）
 * 状态机：idle（热词+历史）/ searching / result / empty
 */
class CourseViewModel(app: Application) : AndroidViewModel(app) {

    enum class ListState { IDLE, SEARCHING, RESULT, EMPTY }

    data class UiState(
        val state: ListState = ListState.IDLE,
        val keyword: String = "",
        val tags: List<TagItem> = emptyList(),
        val selectedTagIndex: Int = -1, // -1 = 全部
        val hotKeywords: List<String> = emptyList(),
        val history: List<String> = emptyList(),
        val courses: List<CourseItem> = emptyList(),
        val loading: Boolean = false,
        val hasMore: Boolean = true,
        val error: String? = null
    )

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState

    private var currentPage = 1

    private val historyPref by lazy {
        getApplication<TogetherApplication>().getSharedPreferences("search_history", android.content.Context.MODE_PRIVATE)
    }

    init {
        loadInitData()
    }

    private fun loadInitData() {
        viewModelScope.launch {
            // 标签
            try {
                val tags = SearchService.fetchTags()
                _uiState.value = _uiState.value.copy(tags = tags)
            } catch (_: Exception) { }
            // 热词
            try {
                val hot = SearchService.fetchHotKeywords()
                _uiState.value = _uiState.value.copy(hotKeywords = hot)
            } catch (_: Exception) { }
            // 历史
            _uiState.value = _uiState.value.copy(history = loadHistory())
        }
    }

    /** 搜索（关键词 + 标签） */
    fun search(keyword: String, tagIndex: Int = _uiState.value.selectedTagIndex) {
        val kw = keyword.trim()
        val tag = if (tagIndex in _uiState.value.tags.indices) _uiState.value.tags[tagIndex].id ?: "" else ""

        if (kw.isNotEmpty()) saveHistory(kw)

        currentPage = 1
        _uiState.value = _uiState.value.copy(
            state = ListState.SEARCHING,
            keyword = kw,
            selectedTagIndex = tagIndex,
            courses = emptyList(),
            hasMore = true,
            error = null
        )
        loadCourses(kw, tag, 1)
    }

    /** 下一页 */
    fun loadMore() {
        val s = _uiState.value
        if (s.loading || !s.hasMore) return
        val tag = if (s.selectedTagIndex in s.tags.indices) s.tags[s.selectedTagIndex].id ?: "" else ""
        loadCourses(s.keyword, tag, currentPage + 1)
    }

    private fun loadCourses(keyword: String, tag: String, page: Int) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(loading = true)
            try {
                val (items, hasMore) = SearchService.searchCourses(keyword, page, tag.ifEmpty { null })
                currentPage = page
                val merged = if (page == 1) items else _uiState.value.courses + items
                _uiState.value = _uiState.value.copy(
                    state = if (merged.isEmpty()) ListState.EMPTY else ListState.RESULT,
                    courses = merged,
                    hasMore = hasMore,
                    loading = false,
                    history = loadHistory()
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    loading = false,
                    error = e.message ?: "加载失败"
                )
            }
        }
    }

    /** 清空关键词 → 回到默认态 */
    fun clearKeyword() {
        _uiState.value = _uiState.value.copy(
            state = ListState.IDLE,
            keyword = "",
            selectedTagIndex = -1,
            courses = emptyList(),
            history = loadHistory()
        )
    }

    fun clearHistory() {
        historyPref.edit().remove("list").apply()
        _uiState.value = _uiState.value.copy(history = emptyList())
    }

    // MARK: - 搜索历史（SharedPreferences 存储）

    private fun loadHistory(): List<String> {
        val raw = historyPref.getString("list", "") ?: ""
        return if (raw.isEmpty()) emptyList() else raw.split("||")
    }

    private fun saveHistory(keyword: String) {
        val current = loadHistory().toMutableList()
        current.remove(keyword)
        current.add(0, keyword)
        if (current.size > 20) current.removeAt(current.size - 1)
        historyPref.edit().putString("list", current.joinToString("||")).apply()
        _uiState.value = _uiState.value.copy(history = current)
    }
}