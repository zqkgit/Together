package com.together.app.core.storage

import kotlinx.coroutines.flow.Flow

class UserSessionStore(
    private val tokenStore: TokenStore
) {
    val accessToken: Flow<String?> = tokenStore.accessToken
    val userId: Flow<String?> = tokenStore.userId
    val userRole: Flow<Int> = tokenStore.userRole
}
