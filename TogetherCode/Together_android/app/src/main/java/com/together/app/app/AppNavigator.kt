package com.together.app.app

import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.together.app.modules.login.ui.LoginScreen
import com.together.app.modules.main.ui.MainTabScreen
import com.together.app.modules.studio.ui.StudioOverviewScreen
import com.together.app.modules.teacher.ui.TeacherWorkbenchScreen

@Composable
fun AppNavigator() {
    val navController = rememberNavController()

    NavHost(
        navController = navController,
        startDestination = AppRoutes.Login
    ) {
        composable(AppRoutes.Login) {
            LoginScreen(
                onParentLogin = {
                    navController.navigate(AppRoutes.ParentMain) {
                        popUpTo(AppRoutes.Login) { inclusive = true }
                    }
                },
                onTeacherLogin = {
                    navController.navigate(AppRoutes.TeacherMain) {
                        popUpTo(AppRoutes.Login) { inclusive = true }
                    }
                },
                onStudioLogin = {
                    navController.navigate(AppRoutes.StudioMain) {
                        popUpTo(AppRoutes.Login) { inclusive = true }
                    }
                }
            )
        }

        composable(AppRoutes.ParentMain) {
            MainTabScreen()
        }

        composable(AppRoutes.TeacherMain) {
            TeacherWorkbenchScreen()
        }

        composable(AppRoutes.StudioMain) {
            StudioOverviewScreen()
        }
    }
}
