package com.together.app.app

import android.Manifest
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import com.together.app.core.design.TogetherTheme
import com.together.app.core.push.PushManager

class MainActivity : ComponentActivity() {

    /** Android 13+ 通知权限（极光推送用，AppKey 未配置时不弹窗） */
    private val notificationPermissionLauncher: ActivityResultLauncher<String> =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        PushManager.requestNotificationPermissionIfNeeded(this, notificationPermissionLauncher)
        setContent {
            TogetherTheme {
                AppNavigator()
            }
        }
    }
}
