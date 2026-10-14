package com.together.app.modules.search

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.together.app.app.TogetherApplication
import com.together.app.core.model.CourseItem
import com.together.app.core.model.StudioItem
import com.together.app.core.model.TeacherItem
import com.together.app.services.SearchService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * 综合搜索 ViewModel：三Tab（课程/工作室/老师）+ 热词 + 历史
 * 对齐 iOS SearchViewController
 */
class SearchViewModel(app: Application) : AndroidViewModel(app) {

    enum class SearchTab(val title: String) {
        COURSE("课程"), STUDIO("工作室"), TEACHER("老师")
    }

    enum class ListState { IDLE, SEARCHING, RESULT, EMPTY }

    data class UiState(
        val state: ListState = ListState.IDLE,
        val currentTab: SearchTab = SearchTab.COURSE,
        val keyword: String = "",
        val loading: Boolean = false,
        val courses: List<CourseItem> = emptyList(),
        val studios: List<StudioItem> = emptyList(),
        val teachers: List<TeacherItem> = emptyList(),
        val hotKeywords: List<String> = emptyList(),
        val history: List<String> = emptyList(),
        val hasMore: Boolean = true,
        val error: String? = null
    )

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    private var currentPage = 1

    private val historyPref by lazy {
        getApplication<TogetherApplication>().getSharedPreferences("search_history", android.content.Context.MODE_PRIVATE)
    }

    init {
        loadInitData()
    }

    private fun loadInitData() {
        viewModelScope.launch {
            try {
                val hot = SearchService.fetchHotKeywords()
                _uiState.value = _uiState.value.copy(hotKeywords = hot)
            } catch (_: Exception) { }
            _uiState.value = _uiState.value.copy(history = loadHistory())
        }
    }

    fun selectTab(tab: SearchTab) {
        if (tab == _uiState.value.currentTab) return
        _uiState.value = _uiState.value.copy(
            currentTab = tab,
            courses = emptyList(),
            studios = emptyList(),
            teachers = emptyList(),
            state = if (_uiState.value.keyword.isNotEmpty()) ListState.SEARCHING else ListState.IDLE
        )
        val kw = _uiState.value.keyword
        if (kw.isNotEmpty()) {
            currentPage = 1
            _uiState.value = _uiState.value.copy(hasMore = true)
            loadResults(kw, 1)
        }
    }

    fun search(keyword: String) {
        val kw = keyword.trim()
        if (kw.isEmpty()) {
            clearKeyword()
            return
        }
        if (kw.isNotEmpty()) saveHistory(kw)
        currentPage = 1
        _uiState.value = _uiState.value.copy(
            state = ListState.SEARCHING,
            keyword = kw,
            courses = emptyList(),
            studios = emptyList(),
            teachers = emptyList(),
            hasMore = true,
            error = null,
            history = loadHistory()
        )
        loadResults(kw, 1)
    }

    fun loadMore() {
        val s = _uiState.value
        if (s.loading || !s.hasMore || s.keyword.isEmpty()) return
        loadResults(s.keyword, currentPage + 1)
    }

    private fun loadResults(keyword: String, page: Int) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(loading = true)
            try {
                val tab = _uiState.value.currentTab
                when (tab) {
                    SearchTab.COURSE -> {
                        val (items, hasMore) = SearchService.searchCourses(keyword, page)
                        currentPage = page
                        val merged = if (page == 1) items else _uiState.value.courses + items
                        _uiState.value = _uiState.value.copy(
                            state = if (merged.isEmpty()) ListState.EMPTY else ListState.RESULT,
                            courses = merged, hasMore = hasMore, loading = false
                        )
                    }
                    SearchTab.STUDIO -> {
                        val (items, hasMore) = SearchService.searchStudios(keyword, page)
                        currentPage = page
                        val merged = if (page == 1) items else _uiState.value.studios + items
                        _uiState.value = _uiState.value.copy(
                            state = if (merged.isEmpty()) ListState.EMPTY else ListState.RESULT,
                            studios = merged, hasMore = hasMore, loading = false
                        )
                    }
                    SearchTab.TEACHER -> {
                        val (items, hasMore) = SearchService.searchTeachers(keyword, page)
                        currentPage = page
                        val merged = if (page == 1) items else _uiState.value.teachers + items
                        _uiState.value = _uiState.value.copy(
                            state = if (merged.isEmpty()) ListState.EMPTY else ListState.RESULT,
                            teachers = merged, hasMore = hasMore, loading = false
                        )
                    }
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    loading = false,
                    error = e.message ?: "搜索失败"
                )
            }
        }
    }

    fun clearKeyword() {
        _uiState.value = _uiState.value.copy(
            state = ListState.IDLE,
            keyword = "",
            courses = emptyList(),
            studios = emptyList(),
            teachers = emptyList(),
            history = loadHistory()
        )
    }

    fun clearHistory() {
        historyPref.edit().remove("list").apply()
        _uiState.value = _uiState.value.copy(history = emptyList())
    }

    // MARK: - 搜索历史（SharedPreferences）

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
    }
}