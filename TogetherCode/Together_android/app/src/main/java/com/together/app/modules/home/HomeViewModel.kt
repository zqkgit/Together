package com.together.app.modules.home

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.together.app.app.TogetherApplication
import com.together.app.services.HomeService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * 首页状态管理
 * 对齐 iOS HomeViewController 数据流
 */
class HomeViewModel(app: Application) : AndroidViewModel(app) {

    private val tokenStore get() = getApplication<TogetherApplication>().tokenStore

    data class HomeUiState(
        val loading: Boolean = false,
        val data: HomeService.HomeData = HomeService.HomeData(),
        val nickname: String = "",
        val error: String? = null
    )

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    init {
        loadNickname()
        refresh()
    }

    private fun loadNickname() {
        viewModelScope.launch {
            tokenStore.nickname.collect { _uiState.value = _uiState.value.copy(nickname = it) }
        }
    }

    /** 加载/刷新首页数据 */
    fun refresh() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(loading = true, error = null)
            try {
                val data = HomeService.fetchHome()
                _uiState.value = _uiState.value.copy(loading = false, data = data)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }
}