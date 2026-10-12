package com.together.app.core.network

import android.util.Log

object NetworkLogger {
    private const val TAG = "TogetherApi"

    fun log(message: String) {
        Log.d(TAG, message)
    }
}
