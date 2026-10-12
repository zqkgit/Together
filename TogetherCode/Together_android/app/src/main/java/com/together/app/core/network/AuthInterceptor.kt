package com.together.app.core.network

import okhttp3.Interceptor
import okhttp3.Response

class AuthInterceptor(
    private val tokenProvider: () -> String?
) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val builder = chain.request().newBuilder()
            .addHeader("Accept", "application/json")

        tokenProvider()?.takeIf { it.isNotBlank() }?.let { token ->
            builder.addHeader("Authorization", "Bearer $token")
        }

        return chain.proceed(builder.build())
    }
}
