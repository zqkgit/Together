package com.together.app.services

import com.together.app.core.network.ApiService
import com.together.app.core.network.JsonHelper.str
import com.together.app.core.network.JsonHelper.strOrNull
import com.together.app.core.network.JsonHelper.int
import com.together.app.core.network.JsonHelper.obj
import com.together.app.core.storage.TokenStore
import kotlinx.serialization.Serializable

/**
 * 认证服务：登录、注册、验证码、角色切换、资料、密码、注销
 * 对齐 iOS AuthService.swift
 */
object AuthService {

    // MARK: - 登录载荷

    @Serializable
    data class LoginPayload(
        val token: String = "",
        val userId: String = "",
        val role: Int = 1,
        val nickname: String = "",
        val phone: String = ""
    )

    private fun parseLoginResponse(json: kotlinx.serialization.json.JsonObject): LoginPayload? {
        val token = json.str("access_token")
        if (token.isEmpty()) return null
        val user = json.obj("user")
        return LoginPayload(
            token = token,
            userId = user.str("user_id"),
            role = json.int("current_role"),
            nickname = user.str("nickname"),
            phone = user.str("phone")
        )
    }

    // MARK: - 验证码

    /** 发送验证码（后端自动判断：已注册=登录，未注册=注册） */
    suspend fun sendCode(phone: String): kotlinx.serialization.json.JsonObject {
        return ApiService.post("/auth/send-code", mapOf("phone" to phone))
    }

    // MARK: - 登录 / 注册

    /** 密码登录 */
    suspend fun loginPassword(phone: String, password: String): LoginPayload {
        val json = ApiService.post("/auth/login-password", mapOf(
            "phone" to phone, "password" to password
        ))
        return parseLoginResponse(json) ?: throw com.together.app.core.network.ApiException.Parse("登录响应解析失败")
    }

    /** 验证码登录（已注册用户） */
    suspend fun loginWithCode(phone: String, code: String): LoginPayload {
        val json = ApiService.post("/auth/login", mapOf(
            "phone" to phone, "code" to code
        ))
        return parseLoginResponse(json) ?: throw com.together.app.core.network.ApiException.Parse("登录响应解析失败")
    }

    /** 注册（未注册手机号 + 验证码；注册即登录） */
    suspend fun register(phone: String, code: String): LoginPayload {
        val json = ApiService.post("/auth/register", mapOf(
            "phone" to phone, "code" to code
        ))
        return parseLoginResponse(json) ?: throw com.together.app.core.network.ApiException.Parse("注册响应解析失败")
    }

    // MARK: - 角色切换

    /** 角色切换（1 家长 / 2 老师 / 3 工作室） */
    suspend fun switchRole(role: Int): kotlinx.serialization.json.JsonObject {
        return ApiService.post("/auth/role/switch", mapOf("role" to role))
    }

    // MARK: - 角色认证申请

    /** 查询认证申请状态（teacher / studio） */
    suspend fun getRoleApplyStatus(role: String): kotlinx.serialization.json.JsonObject {
        return ApiService.get("/auth/role/apply/$role")
    }

    /** 提交老师认证 / 工作室入驻申请 */
    suspend fun submitRoleApply(
        role: String,
        payload: Map<String, Any?>
    ): kotlinx.serialization.json.JsonObject {
        return ApiService.post("/auth/role/apply", mapOf(
            "role" to role, "payload" to payload
        ))
    }

    // MARK: - 个人资料

    @Serializable
    data class UserProfile(
        val userId: String = "",
        val phone: String = "",
        val nickname: String = "",
        val avatar: String? = null,
        val city: String? = null,
        val signature: String? = null,
        val role: Int = 1,
        val teacherRealName: String? = null
    )

    /** 当前用户资料 */
    suspend fun fetchMe(): UserProfile {
        val json = ApiService.get("/auth/me")
        val user = json.obj("user")
        return UserProfile(
            userId = user.str("user_id"),
            phone = user.str("phone"),
            nickname = user.str("nickname"),
            avatar = user.strOrNull("avatar"),
            city = user.strOrNull("city"),
            signature = user.strOrNull("signature"),
            role = user.int("role"),
            teacherRealName = json.obj("teacher_profile").strOrNull("real_name")
        )
    }

    /** 更新资料（只传需要修改的字段） */
    suspend fun updateProfile(
        nickname: String? = null,
        avatar: String? = null,
        city: String? = null,
        signature: String? = null
    ) {
        val params = mutableMapOf<String, Any?>()
        nickname?.let { params["nickname"] = it }
        avatar?.let { params["avatar"] = it }
        city?.let { params["city"] = it }
        signature?.let { params["signature"] = it }
        if (params.isNotEmpty()) {
            ApiService.put("/me/profile", params)
        }
    }

    // MARK: - 账号与安全

    /** 修改登录密码（验证码模式） */
    suspend fun changePassword(code: String, newPassword: String) {
        ApiService.post("/auth/change-password", mapOf(
            "code" to code, "new_password" to newPassword
        ))
    }

    /** 更换绑定手机号 */
    suspend fun changePhone(phone: String, code: String) {
        ApiService.post("/auth/change-phone", mapOf(
            "phone" to phone, "code" to code
        ))
    }

    /** 设置支付密码 */
    suspend fun setPayPassword(payPassword: String) {
        ApiService.post("/me/pay-password", mapOf("pay_password" to payPassword))
    }

    /** 注销账号 */
    suspend fun deactivateAccount(code: String) {
        ApiService.post("/auth/deactivate", mapOf("code" to code))
    }

    // MARK: - 登出（本地清理）

    /** 登出（清除本地登录态） */
    suspend fun logout(tokenStore: com.together.app.core.storage.TokenStore) {
        tokenStore.clear()
    }
}