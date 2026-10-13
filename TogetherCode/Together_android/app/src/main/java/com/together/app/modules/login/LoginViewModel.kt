package com.together.app.modules.login

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.together.app.app.TogetherApplication
import com.together.app.services.AuthService
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * 登录状态管理（品牌页 + 手机号登录 + 验证码）
 * 对齐 iOS LoginViewController / PhoneLoginViewController / VerifyCodeViewController
 */
class LoginViewModel(app: Application) : AndroidViewModel(app) {

    private val tokenStore get() = (app as TogetherApplication).tokenStore

    // MARK: - 状态

    data class LoginUiState(
        val loading: Boolean = false,
        val countdown: Int = 0,           // 验证码倒计时（秒），0=可发送
        val loginSuccess: Boolean = false, // 登录成功一次性事件
        val toast: String? = null          // 一次性提示
    )

    private val _uiState = MutableStateFlow(LoginUiState())
    val uiState: StateFlow<LoginUiState> = _uiState.asStateFlow()

    private var countdownJob: Job? = null

    // MARK: - 验证码

    /** 发送验证码 */
    fun sendCode(phone: String) {
        if (_uiState.value.countdown > 0) return
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(loading = true, toast = null)
            try {
                AuthService.sendCode(phone)
                _uiState.value = _uiState.value.copy(loading = false, toast = "验证码已发送")
                startCountdown()
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(loading = false, toast = e.message ?: "发送失败")
            }
        }
    }

    /** 启动 60s 倒计时 */
    private fun startCountdown() {
        countdownJob?.cancel()
        countdownJob = viewModelScope.launch {
            for (i in 60 downTo 1) {
                _uiState.value = _uiState.value.copy(countdown = i)
                delay(1000)
            }
            _uiState.value = _uiState.value.copy(countdown = 0)
        }
    }

    // MARK: - 登录

    /** 验证码登录 */
    fun loginWithCode(phone: String, code: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(loading = true, toast = null)
            try {
                val payload = AuthService.loginWithCode(phone, code)
                saveSession(payload)
                _uiState.value = _uiState.value.copy(loading = false, loginSuccess = true)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(loading = false, toast = e.message ?: "登录失败")
            }
        }
    }

    /** 密码登录 */
    fun loginPassword(phone: String, password: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(loading = true, toast = null)
            try {
                val payload = AuthService.loginPassword(phone, password)
                saveSession(payload)
                _uiState.value = _uiState.value.copy(loading = false, loginSuccess = true)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(loading = false, toast = e.message ?: "登录失败")
            }
        }
    }

    /** 注册（验证码注册即登录） */
    fun register(phone: String, code: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(loading = true, toast = null)
            try {
                val payload = AuthService.register(phone, code)
                saveSession(payload)
                _uiState.value = _uiState.value.copy(loading = false, loginSuccess = true, toast = "注册成功")
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(loading = false, toast = e.message ?: "注册失败")
            }
        }
    }

    /** 保存登录态 */
    private suspend fun saveSession(payload: AuthService.LoginPayload) {
        tokenStore.save(
            accessToken = payload.token,
            userId = payload.userId,
            role = payload.role,
            nickname = payload.nickname,
            phone = payload.phone
        )
    }

    // MARK: - 事件消费

    /** 消费 toast 事件 */
    fun consumeToast() {
        _uiState.value = _uiState.value.copy(toast = null)
    }

    /** 消费登录成功事件 */
    fun consumeLoginSuccess() {
        _uiState.value = _uiState.value.copy(loginSuccess = false)
    }

    // MARK: - 工具

    fun isValidPhone(phone: String): Boolean = phone.length == 11 && phone.startsWith("1")

    override fun onCleared() {
        super.onCleared()
        countdownJob?.cancel()
    }
}