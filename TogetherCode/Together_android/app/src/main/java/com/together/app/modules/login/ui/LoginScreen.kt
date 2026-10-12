package com.together.app.modules.login.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens

@Composable
fun LoginScreen(
    onParentLogin: () -> Unit,
    onTeacherLogin: () -> Unit,
    onStudioLogin: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg),
        color = AppColors.Bg
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(AppDimens.Xl),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "Together",
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.Bold,
                color = AppColors.Ink
            )
            Spacer(modifier = Modifier.height(AppDimens.S))
            Text(
                text = "Android 原生工程骨架已就绪，先用角色入口占位。",
                style = MaterialTheme.typography.bodyLarge,
                color = AppColors.Sub
            )
            Spacer(modifier = Modifier.height(AppDimens.Xl))

            Button(
                onClick = onParentLogin,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("以家长角色进入")
            }

            Spacer(modifier = Modifier.height(AppDimens.M))

            Button(
                onClick = onTeacherLogin,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("以老师角色进入")
            }

            Spacer(modifier = Modifier.height(AppDimens.M))

            Button(
                onClick = onStudioLogin,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("以工作室角色进入")
            }
        }
    }
}
