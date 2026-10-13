package com.together.app.app

import android.app.Application
import com.together.app.core.network.ApiService
import com.together.app.core.storage.TokenStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class TogetherApplication : Application() {

    val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    lateinit var tokenStore: TokenStore
        private set

    override fun onCreate() {
        super.onCreate()
        instance = this
        tokenStore = TokenStore(this)

        // 注入 token 提供者（同步缓存，避免每次请求都读 DataStore）
        applicationScope.launch {
            tokenStore.accessToken.collect { token ->
                ApiService.tokenProvider = { token }
            }
        }
    }

    companion object {
        lateinit var instance: TogetherApplication
            private set
    }
}