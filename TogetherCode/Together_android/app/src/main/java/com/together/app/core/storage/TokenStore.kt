package com.together.app.core.storage

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.tokenDataStore by preferencesDataStore(name = "together_session")

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

    suspend fun save(accessToken: String, userId: String, role: Int) {
        context.tokenDataStore.edit { prefs ->
            prefs[ACCESS_TOKEN] = accessToken
            prefs[USER_ID] = userId
            prefs[USER_ROLE] = role
        }
    }

    suspend fun updateRole(role: Int) {
        context.tokenDataStore.edit { prefs ->
            prefs[USER_ROLE] = role
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
    }
}
