package com.together.app.modules.mine

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.together.app.app.TogetherApplication
import com.together.app.core.network.JsonHelper.obj
import com.together.app.core.network.JsonHelper.objOrNull
import com.together.app.core.network.JsonHelper.str
import com.together.app.core.network.JsonHelper.strOrNull
import com.together.app.modules.mine.ui.AuthNavCache
import com.together.app.services.AuthService
import com.together.app.services.MineService
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * 全局角色切换事件总线：MineViewModel 切换成功后发射新角色，
 * AppNavigator 收集后跳转对应主界面（对齐 iOS NotificationCenter.userRoleDidChange）
 */
object RoleEventBus {
    private val _events = MutableSharedFlow<Int>(extraBufferCapacity = 1)
    val events: SharedFlow<Int> = _events.asSharedFlow()

    fun emit(role: Int) {
        _events.tryEmit(role)
    }
}

/**
 * 我的页面 ViewModel
 * 对齐 iOS MineViewController：资料+统计并行加载 / 身份弹窗 / 角色切换 / 认证状态查询
 */
class MineViewModel(app: Application) : AndroidViewModel(app) {

    private val tokenStore = (app as TogetherApplication).tokenStore

    // MARK: - 状态

    data class MineState(
        val profile: MineService.MineProfile? = null,
        val stats: MineService.MineStats = MineService.MineStats(),
        val loading: Boolean = false,
        val error: String? = null
    )

    private val _state = MutableStateFlow(MineState())
    val state: StateFlow<MineState> = _state.asStateFlow()

    /** 身份切换弹窗 */
    private val _showRoleSheet = MutableStateFlow(false)
    val showRoleSheet: StateFlow<Boolean> = _showRoleSheet.asStateFlow()

    /** 未开通角色的认证状态：role → "pending" / "rejected" / "unauth" */
    private val _authStatuses = MutableStateFlow<Map<Int, String>>(emptyMap())
    val authStatuses: StateFlow<Map<Int, String>> = _authStatuses.asStateFlow()

    /** Toast 消息 */
    private val _toast = MutableStateFlow<String?>(null)
    val toast: StateFlow<String?> = _toast.asStateFlow()

    /** 认证页跳转事件：role(2老师/3工作室) + status + reason */
    data class AuthNavigation(val role: Int, val status: String, val reason: String?)

    private val _authNavigation = MutableSharedFlow<AuthNavigation>(extraBufferCapacity = 1)
    val authNavigation: SharedFlow<AuthNavigation> = _authNavigation.asSharedFlow()

    fun clearToast() { _toast.value = null }
    fun dismissRoleSheet() { _showRoleSheet.value = false }

    // MARK: - 数据加载

    /** 并行加载资料 + 统计（ON_RESUME / 下拉刷新调用） */
    fun refreshData() {
        viewModelScope.launch {
            _state.value = _state.value.copy(loading = true, error = null)
            // 资料
            launch {
                try {
                    val profile = MineService.fetchMe()
                    _state.value = _state.value.copy(profile = profile)
                } catch (e: Exception) {
                    _state.value = _state.value.copy(error = e.message ?: "加载失败")
                }
            }
            // 统计
            launch {
                try {
                    val stats = MineService.fetchStats()
                    _state.value = _state.value.copy(stats = stats)
                } catch (_: Exception) { }
            }
            _state.value = _state.value.copy(loading = false)
        }
    }

    // MARK: - 身份弹窗

    /** 打开身份弹窗：先拉最新 roles（后台可能刚审核通过），再并行查未开通身份的认证状态 */
    fun showRoleSheet() {
        viewModelScope.launch {
            // 先刷新资料，确保 roles 最新
            try {
                val profile = MineService.fetchMe()
                _state.value = _state.value.copy(profile = profile)
            } catch (_: Exception) { }

            _authStatuses.value = emptyMap()
            _showRoleSheet.value = true

            // 并行查询未开通身份的认证状态
            val profile = _state.value.profile
            val owned = profile?.roles ?: listOf(1)
            val unowned = listOf(2, 3).filter { it !in owned }
            if (unowned.isEmpty()) return@launch

            val statuses = mutableMapOf<Int, String>()
            kotlinx.coroutines.coroutineScope {
                unowned.forEach { role ->
                    launch {
                        try {
                            val json = AuthService.getRoleApplyStatus(
                                if (role == 2) "teacher" else "studio"
                            )
                            statuses[role] = json.str("status").ifEmpty { "unauth" }
                        } catch (_: Exception) { }
                    }
                }
            }
            // 弹窗可能已关闭，仍更新状态（下次打开时用）
            _authStatuses.value = statuses
        }
    }

    // MARK: - 角色切换

    /** 已开通身份：切换角色（保存新 token → 通知全局跳转） */
    fun switchRole(role: Int) {
        viewModelScope.launch {
            try {
                val json = AuthService.switchRole(role)
                // 保存后端返回的新 token（切换角色会签发新 token），保留昵称头像等资料
                val token = json.strOrNull("access_token") ?: ""
                if (token.isNotEmpty()) {
                    val uid = json.obj("user").strOrNull("user_id")
                        ?: tokenStore.getUserIdSync() ?: ""
                    tokenStore.updateSession(accessToken = token, userId = uid, role = role)
                } else {
                    tokenStore.updateRole(role)
                }
                _toast.value = "已切换身份"
                RoleEventBus.emit(role)
            } catch (e: Exception) {
                _toast.value = e.message ?: "切换失败"
            }
        }
    }

    /** 未开通身份：查认证状态 → approved 直接切换 / 其他进认证页 */
    fun handleNeedAuth(role: Int) {
        viewModelScope.launch {
            try {
                val json = AuthService.getRoleApplyStatus(
                    if (role == 2) "teacher" else "studio"
                )
                val status = json.str("status").ifEmpty { "unauth" }
                if (status == "approved") {
                    // 档案已审核通过（本地身份缓存未刷新）→ 直接切换
                    switchRole(role)
                    return@launch
                }
                val reason = json.strOrNull("reason")
                val apply = json.objOrNull("apply")
                AuthNavCache.set(status, reason, apply)
                _authNavigation.tryEmit(AuthNavigation(role, status, reason))
            } catch (e: Exception) {
                _toast.value = e.message ?: "查询认证状态失败"
            }
        }
    }

    // MARK: - 弹窗行点击分发

    /** 弹窗行点击：已开通→切换 / 未开通→认证 */
    fun onRoleRowTapped(role: Int) {
        _showRoleSheet.value = false
        val owned = _state.value.profile?.roles ?: listOf(1)
        if (role in owned) {
            switchRole(role)
        } else {
            handleNeedAuth(role)
        }
    }
}