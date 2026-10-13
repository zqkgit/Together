package com.together.app.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.together.app.core.network.ApiService
import com.together.app.modules.login.ui.LoginScreen
import com.together.app.modules.login.ui.PhoneLoginScreen
import com.together.app.modules.login.ui.VerifyCodeScreen
import com.together.app.modules.main.ui.MainTabScreen
import com.together.app.modules.order.OrderViewModel
import com.together.app.modules.order.ui.MyOrdersScreen
import com.together.app.modules.order.ui.OrderDetailScreen
import com.together.app.modules.order.ui.OrderRefundScreen
import com.together.app.modules.order.ui.PaymentVoucherScreen
import com.together.app.modules.order.ui.RefundDetailScreen
import com.together.app.modules.studio.ui.StudioOverviewScreen
import com.together.app.modules.teacher.ui.TeacherWorkbenchScreen
import kotlinx.coroutines.launch

/**
 * 全局导航：登录态判断 + 登录流程接线 + 401 全局处理
 * 对齐 iOS AppDelegate 路由逻辑
 *
 * 流程：
 * 1. 启动时检查 token：已登录 → 按角色进主界面；未登录 → 品牌页
 * 2. 品牌页 → 手机号登录页 → 验证码页 → 按角色进主界面
 * 3. 任意页面收到 401 → 清 token → 回品牌页
 */
@Composable
fun AppNavigator() {
    val navController = rememberNavController()
    val context = LocalContext.current
    val app = context.applicationContext as TogetherApplication
    val tokenStore = app.tokenStore
    val scope = rememberCoroutineScope()

    // 登录成功 → 按角色跳主界面
    fun goMain() {
        scope.launch {
            val role = tokenStore.getRoleSync()
            navController.navigate(mainRouteForRole(role)) {
                popUpTo(0) { inclusive = true }
            }
        }
    }

    // 启动时判断登录态
    var startChecked by remember { mutableStateOf(false) }
    var startDestination by remember { mutableStateOf(AppRoutes.Login) }

    LaunchedEffect(Unit) {
        val loggedIn = tokenStore.isLoggedInSync()
        if (loggedIn) {
            startDestination = mainRouteForRole(tokenStore.getRoleSync())
        }
        startChecked = true
    }

    // 401 全局处理：清 token → 回登录页
    LaunchedEffect(Unit) {
        ApiService.authExpiredFlow.collect {
            tokenStore.clear()
            navController.navigate(AppRoutes.Login) {
                popUpTo(0) { inclusive = true }
            }
        }
    }

    if (!startChecked) return

    NavHost(
        navController = navController,
        startDestination = startDestination
    ) {
        // 品牌页
        composable(AppRoutes.Login) {
            LoginScreen(
                onNavigateToPhoneLogin = {
                    navController.navigate(AppRoutes.PhoneLogin)
                },
                onLoginSuccess = { goMain() }
            )
        }

        // 手机号登录页
        composable(AppRoutes.PhoneLogin) {
            PhoneLoginScreen(
                onNavigateToVerifyCode = { phone ->
                    navController.navigate(AppRoutes.verifyCode(phone))
                },
                onLoginSuccess = { goMain() }
            )
        }

        // 验证码页（注册流程）
        composable(
            route = AppRoutes.VerifyCode,
            arguments = listOf(navArgument("phone") { type = NavType.StringType })
        ) { entry ->
            val phone = entry.arguments?.getString("phone") ?: ""
            VerifyCodeScreen(
                phone = phone,
                onLoginSuccess = { goMain() }
            )
        }

        // 家长端主界面
        composable(AppRoutes.ParentMain) {
            MainTabScreen()
        }

        // 老师端工作台
        composable(AppRoutes.TeacherMain) {
            TeacherWorkbenchScreen()
        }

        // 工作室端总览
        composable(AppRoutes.StudioMain) {
            StudioOverviewScreen()
        }

        // MARK: - 订单模块

        // 我的订单
        composable(AppRoutes.MyOrders) {
            MyOrdersScreen(
                onBack = { navController.popBackStack() },
                onOrderClick = { orderId ->
                    navController.navigate(AppRoutes.orderDetail(orderId))
                },
                onUploadVoucher = { order ->
                    OrderViewModel.navOrder = order
                    navController.navigate(AppRoutes.paymentVoucher(order.orderId ?: ""))
                },
                onStudy = { _, _, _ -> /* TODO: 学习页（孩子模块） */ },
                onRefundDetail = { refundId ->
                    navController.navigate(AppRoutes.refundDetail(refundId))
                },
                onReorder = { _ -> /* TODO: 课程详情重新报名 */ }
            )
        }

        // 订单详情
        composable(
            route = AppRoutes.OrderDetail,
            arguments = listOf(navArgument("orderId") { type = NavType.StringType })
        ) { entry ->
            val orderId = entry.arguments?.getString("orderId") ?: ""
            OrderDetailScreen(
                orderId = orderId,
                onBack = { navController.popBackStack() },
                onUploadVoucher = { order ->
                    OrderViewModel.navOrder = order
                    navController.navigate(AppRoutes.paymentVoucher(order.orderId ?: ""))
                },
                onStudy = { _, _, _ -> /* TODO: 学习页（孩子模块） */ },
                onRefundDetail = { refundId ->
                    navController.navigate(AppRoutes.refundDetail(refundId))
                },
                onReorder = { _ -> /* TODO: 课程详情重新报名 */ },
                onRefund = { order ->
                    OrderViewModel.navOrder = order
                    navController.navigate(AppRoutes.orderRefund(order.orderId ?: ""))
                }
            )
        }

        // 上传付款凭证（需从 navOrder 缓存读取订单对象）
        composable(
            route = AppRoutes.PaymentVoucher,
            arguments = listOf(navArgument("orderId") { type = NavType.StringType })
        ) {
            val order = OrderViewModel.navOrder
            if (order != null) {
                PaymentVoucherScreen(
                    order = order,
                    onBack = { navController.popBackStack() },
                    onSubmitted = { /* 返回后列表/详情自动刷新 */ }
                )
            } else {
                LaunchedEffect(Unit) { navController.popBackStack() }
            }
        }

        // 申请退款（需从 navOrder 缓存读取订单对象）
        composable(
            route = AppRoutes.OrderRefund,
            arguments = listOf(navArgument("orderId") { type = NavType.StringType })
        ) {
            val order = OrderViewModel.navOrder
            if (order != null) {
                OrderRefundScreen(
                    order = order,
                    onBack = { navController.popBackStack() },
                    onSuccess = { /* 返回后详情自动刷新 */ }
                )
            } else {
                LaunchedEffect(Unit) { navController.popBackStack() }
            }
        }

        // 退款详情
        composable(
            route = AppRoutes.RefundDetail,
            arguments = listOf(navArgument("refundId") { type = NavType.StringType })
        ) { entry ->
            val refundId = entry.arguments?.getString("refundId") ?: ""
            RefundDetailScreen(
                refundId = refundId,
                onBack = { navController.popBackStack() }
            )
        }
    }
}

/** 按角色返回主界面路由 */
private fun mainRouteForRole(role: Int): String = when (role) {
    2 -> AppRoutes.TeacherMain
    3 -> AppRoutes.StudioMain
    else -> AppRoutes.ParentMain
}