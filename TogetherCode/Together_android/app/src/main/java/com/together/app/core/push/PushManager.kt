package com.together.app.core.push

import android.Manifest
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.core.content.ContextCompat
import cn.jpush.android.api.JPushInterface
import com.together.app.core.network.ApiConfig
import com.together.app.core.network.ApiService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * 极光推送（JPush）统一封装 —— 对齐 iOS PushManager.swift
 *
 * 1. App 启动时初始化极光（AppKey 未配置时整体跳过，不影响开发环境）
 * 2. 拿到极光 registrationID 后，登录态存在则自动上报 POST /messages/devices
 * 3. 登录/注册成功（TokenStore.save）后再次触发上报（幂等，后端同 registration_id 复用）
 * 4. 退出登录（TokenStore.clear）前解绑 DELETE /messages/devices
 *
 * 未配置 JPush 时 App 内消息仍走 WebSocket 实时通道 + 轮询兜底。
 */
object PushManager {

    /** 是否启用极光（配置了 AppKey 才初始化；未配置时静默跳过） */
    val isEnabled: Boolean
        get() = ApiConfig.JPUSH_APPKEY.isNotEmpty()

    private const val RID_KEY = "together_jpush_registration_id"
    private const val PREFS_NAME = "together_push"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private var registrationID: String? = null

    // MARK: - 初始化

    /** Application.onCreate 调用（对齐 iOS PushManager.setup） */
    fun setup(context: Context) {
        if (!isEnabled) {
            // 未配置 AppKey：跳过极光初始化，不影响主流程
            return
        }

        // 隐私合规：用户同意后才允许 SDK 采集（JPush 5.x 必须）
        cn.jiguang.api.utils.JCollectionAuth.setAuth(context, true)
        JPushInterface.init(context)

        // 恢复缓存的 registrationID
        val cached = getPrefs(context).getString(RID_KEY, null)
        if (!cached.isNullOrBlank()) registrationID = cached

        // registrationID 异步获取（首次注册需 1~3s；轮询最多 15s，拿到即上报）
        scope.launch {
            val rid = waitForRegistrationID(context)
            if (!rid.isNullOrBlank()) {
                registrationID = rid
                getPrefs(context).edit().putString(RID_KEY, rid).apply()
                reportIfNeeded()
            }
        }
    }

    /** Android 13+ 通知权限请求（对齐 iOS APNs 授权弹窗，AppKey 未配置时跳过） */
    fun requestNotificationPermissionIfNeeded(
        activity: ComponentActivity,
        launcher: ActivityResultLauncher<String>
    ) {
        if (!isEnabled) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                launcher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
    }

    /** 登录态就绪/变化后调用：登记当前设备（对齐 iOS PushManager.reportDevice） */
    fun reportDevice() {
        reportIfNeeded()
    }

    /**
     * 退出登录：解绑当前设备的极光推送（软删，重新登录自动复用）
     * 对齐 iOS PushManager.unbindDevice —— token 由调用方在清空前传入
     */
    fun unbindDevice(token: String?) {
        if (!isEnabled) return
        val rid = registrationID?.takeIf { it.isNotBlank() } ?: return
        if (token.isNullOrBlank()) return
        // 退出登录时 token 即将被清空，先由调用方捕获再发独立请求
        scope.launch {
            try {
                ApiService.tokenProvider = { token }
                ApiService.delete("messages/devices", mapOf("registration_id" to rid))
            } catch (_: Exception) {
                // 解绑失败静默（重新登录会自动换绑/复用）
            }
        }
    }

    // MARK: - 内部

    /** 上报设备（登录态存在时） */
    private fun reportIfNeeded() {
        if (!isEnabled) return
        val rid = registrationID?.takeIf { it.isNotBlank() } ?: return
        scope.launch {
            try {
                ApiService.post(
                    "messages/devices",
                    buildJsonObject {
                        put("registration_id", rid)
                        put("platform", "android")
                    }
                )
            } catch (_: Exception) {
                // 上报失败静默（下次登录/冷启动再报），不影响主流程
            }
        }
    }

    /** 轮询获取 registrationID（JPush 注册异步，最多等 15s） */
    private suspend fun waitForRegistrationID(context: Context): String? {
        repeat(15) {
            val rid = JPushInterface.getRegistrationID(context)
            if (!rid.isNullOrBlank()) return rid
            delay(1000)
        }
        return null
    }

    private fun getPrefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}