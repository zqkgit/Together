package com.together.app.core.storage

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.tokenDataStore by preferencesDataStore(name = "together_session")

/**
 * 登录态存储：token + 用户信息
 * 对齐 iOS TokenManager.swift
 */
class TokenStore(private val context: Context) {

    val accessToken: Flow<String?> = context.tokenDataStore.data.map { prefs ->
        prefs[ACCESS_TOKEN]
    }

    val userId: Flow<String?> = context.tokenDataStore.data.map { prefs ->
        prefs[USER_ID]
    }

    val userRole: Flow<Int> = context.tokenDataStore.data.map { prefs ->
        prefs[USER_ROLE] ?: 1
    }

    val nickname: Flow<String> = context.tokenDataStore.data.map { prefs ->
        prefs[NICKNAME] ?: ""
    }

    val phone: Flow<String> = context.tokenDataStore.data.map { prefs ->
        prefs[PHONE] ?: ""
    }

    val avatar: Flow<String?> = context.tokenDataStore.data.map { prefs ->
        prefs[AVATAR]
    }

    /** 是否已登录 */
    val isLoggedIn: Flow<Boolean> = accessToken.map { !it.isNullOrBlank() }

    // MARK: - 同步读取（需在协程中调用）

    suspend fun getTokenSync(): String? = accessToken.first()
    suspend fun getRoleSync(): Int = userRole.first()
    suspend fun isLoggedInSync(): Boolean = !getTokenSync().isNullOrBlank()

    // MARK: - 写入

    suspend fun save(
        accessToken: String,
        userId: String,
        role: Int = 1,
        nickname: String = "",
        phone: String = "",
        avatar: String? = null
    ) {
        context.tokenDataStore.edit { prefs ->
            prefs[ACCESS_TOKEN] = accessToken
            prefs[USER_ID] = userId
            prefs[USER_ROLE] = role
            prefs[NICKNAME] = nickname
            prefs[PHONE] = phone
            if (avatar != null) prefs[AVATAR] = avatar
        }
    }

    suspend fun updateRole(role: Int) {
        context.tokenDataStore.edit { prefs ->
            prefs[USER_ROLE] = role
        }
    }

    suspend fun updateProfile(nickname: String? = null, avatar: String? = null, phone: String? = null) {
        context.tokenDataStore.edit { prefs ->
            nickname?.let { prefs[NICKNAME] = it }
            avatar?.let { prefs[AVATAR] = it }
            phone?.let { prefs[PHONE] = it }
        }
    }

    suspend fun clear() {
        context.tokenDataStore.edit { prefs ->
            prefs.clear()
        }
    }

    private companion object {
        val ACCESS_TOKEN = stringPreferencesKey("access_token")
        val USER_ID = stringPreferencesKey("user_id")
        val USER_ROLE = intPreferencesKey("user_role")
        val NICKNAME = stringPreferencesKey("nickname")
        val PHONE = stringPreferencesKey("phone")
        val AVATAR = stringPreferencesKey("avatar")
    }
}