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
import com.together.app.core.model.ChildItem
import com.together.app.modules.child.ChildViewModel
import com.together.app.modules.child.ui.AddChildScreen
import com.together.app.modules.child.ui.ChildBalanceScreen
import com.together.app.modules.child.ui.ChildHomeScreen
import com.together.app.modules.child.ui.MyChildrenScreen
import com.together.app.modules.course.ui.CourseDetailScreen
import com.together.app.modules.course.ui.CourseBrowseScreen
import com.together.app.modules.course.ui.CourseListScreen
import com.together.app.modules.course.ui.CourseStudyScreen
import com.together.app.modules.course.ui.MyCoursesScreen
import com.together.app.modules.course.ui.CourseReviewsScreen
import com.together.app.modules.course.ui.ReviewComposeScreen
import com.together.app.modules.course.ui.ReviewComposeViewModel
import com.together.app.modules.course.ui.MyReviewsScreen
import com.together.app.modules.login.ui.LoginScreen
import com.together.app.modules.login.ui.PhoneLoginScreen
import com.together.app.modules.login.ui.VerifyCodeScreen
import com.together.app.modules.main.ui.MainTabScreen
import com.together.app.modules.message.MessageViewModel
import com.together.app.modules.message.ui.ChatScreen
import com.together.app.modules.message.ui.FollowingListScreen
import com.together.app.modules.order.OrderViewModel
import com.together.app.modules.order.ui.MyOrdersScreen
import com.together.app.modules.order.ui.OrderDetailScreen
import com.together.app.modules.order.ui.OrderRefundScreen
import com.together.app.modules.order.ui.PaymentVoucherScreen
import com.together.app.modules.order.ui.RefundDetailScreen
import com.together.app.modules.mine.CommissionNavCache
import com.together.app.modules.mine.RoleEventBus
import com.together.app.modules.mine.ui.AccountSecurityScreen
import com.together.app.modules.mine.ui.AboutScreen
import com.together.app.modules.mine.ui.ChangePasswordScreen
import com.together.app.modules.mine.ui.ChangePhoneScreen
import com.together.app.modules.mine.ui.CommissionWithdrawalDetailScreen
import com.together.app.modules.mine.ui.CommissionWithdrawalsScreen
import com.together.app.modules.mine.ui.DeactivateAccountScreen
import com.together.app.modules.mine.ui.EditProfileScreen
import com.together.app.modules.mine.ui.FavoritesAndDynamicsScreen
import com.together.app.modules.mine.ui.SettingsScreen
import com.together.app.modules.mine.ui.StudioAuthScreen
import com.together.app.modules.mine.ui.StudioCommissionDetailScreen
import com.together.app.modules.mine.ui.TeacherAuthScreen
import com.together.app.modules.mine.ui.WalletScreen
import com.together.app.modules.mine.ui.WorkManagementScreen
import com.together.app.modules.plaza.PlazaViewModel
import com.together.app.modules.plaza.ui.PostCreateScreen
import com.together.app.modules.plaza.ui.PostDetailScreen
import com.together.app.modules.studio.ui.StudioCommissionReviewScreen
import com.together.app.modules.studio.ui.StudioCourseListScreen
import com.together.app.modules.studio.ui.StudioOrderDetailScreen
import com.together.app.modules.studio.ui.StudioOrderListScreen
import com.together.app.modules.studio.ui.StudioOverviewScreen
import com.together.app.modules.studio.ui.StudioRefundScreen
import com.together.app.modules.studio.ui.StudioRevenueScreen
import com.together.app.modules.studio.ui.StudioStudentDetailScreen
import com.together.app.modules.studio.ui.StudioStudentListScreen
import com.together.app.modules.studio.ui.StudioTeacherApplicationScreen
import com.together.app.modules.studio.ui.StudioTeacherDetailScreen
import com.together.app.modules.studio.ui.StudioTeacherListScreen
import com.together.app.modules.teacher.ui.TeacherTimetableScreen
import com.together.app.modules.teacher.ui.ScheduleDetailScreen
import com.together.app.modules.teacher.ui.ScheduleDetailViewModel
import com.together.app.modules.teacher.ui.ClassListScreen
import com.together.app.modules.teacher.ui.ClassListData
import com.together.app.modules.teacher.ui.ClassStudentsScreen
import com.together.app.modules.teacher.ui.ClassStudentsData
import com.together.app.modules.home.ui.StudiosScreen
import com.together.app.modules.teacher.ui.MyTeachingCoursesScreen
import com.together.app.modules.teacher.ui.MyStudentsScreen
import com.together.app.modules.teacher.ui.LeaveApprovalScreen
import com.together.app.modules.teacher.ui.ReputationScreen
import com.together.app.modules.search.ui.SearchScreen
import com.together.app.modules.profile.ui.TeacherProfileScreen
import com.together.app.modules.profile.ui.StudioHomepageScreen
import com.together.app.modules.teacher.ui.TeacherWorkbenchScreen
import com.together.app.services.MessageSocketService
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
            MessageSocketService.connect()
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
            MessageSocketService.connect()
        }
        startChecked = true
    }

    // 401 全局处理：清 token → 回登录页
    LaunchedEffect(Unit) {
        ApiService.authExpiredFlow.collect {
            MessageSocketService.disconnect()
            tokenStore.clear()
            navController.navigate(AppRoutes.Login) {
                popUpTo(0) { inclusive = true }
            }
        }
    }

    // 角色切换全局通知：MineViewModel 切换成功后跳对应主界面
    LaunchedEffect(Unit) {
        RoleEventBus.events.collect { role ->
            // 角色切换后 token 变化，重连 WebSocket
            MessageSocketService.disconnect()
            MessageSocketService.connect()
            navController.navigate(mainRouteForRole(role)) {
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
            MainTabScreen(
                onChildClick = { child ->
                    ChildViewModel.navChild = child
                    navController.navigate(AppRoutes.childHome(child.childId))
                },
                onAddChild = {
                    navController.navigate(AppRoutes.MyChildren)
                },
                onPostClick = { post ->
                    navController.navigate(AppRoutes.postDetail(post.postId))
                },
                onPublish = { role, postType ->
                    // 对齐 iOS：工作室(role 3)走家长通用发帖链路(/posts)
                    val effectiveRole = if (role == 3) 1 else role
                    navController.navigate(AppRoutes.postCreate(effectiveRole, postType))
                },
                onConversationClick = { conversation ->
                    MessageViewModel.navConversation = conversation
                    navController.navigate(AppRoutes.chat(conversation.conversationId))
                },
                onAddContact = {
                    navController.navigate(AppRoutes.FollowingList)
                },
                onNotificationClick = { notification ->
                    // 按 ref_type 跳转对应详情
                    val refId = notification.refId
                    if (refId != null) {
                        when (notification.refType) {
                            "post" -> navController.navigate(AppRoutes.postDetail(refId))
                            "order" -> navController.navigate(AppRoutes.orderDetail(refId))
                            "refund" -> navController.navigate(AppRoutes.refundDetail(refId))
                            "course" -> navController.navigate(AppRoutes.courseDetail(refId))
                            "withdraw" -> navController.navigate(AppRoutes.CommissionWithdrawals)
                        }
                    }
                },
                // 我的页面
                onSettings = { navController.navigate(AppRoutes.Settings) },
                onMyChildren = { navController.navigate(AppRoutes.MyChildren) },
                onMyCourses = { navController.navigate(AppRoutes.myCourses()) },
                onMyOrders = { navController.navigate(AppRoutes.MyOrders) },
                onMyReviews = { navController.navigate(AppRoutes.MyReviews) },
                onWorkManagement = { navController.navigate(AppRoutes.WorkManagement) },
                onFavorites = { navController.navigate(AppRoutes.Favorites) },
                onWallet = { navController.navigate(AppRoutes.Wallet) },
                onTimetable = { navController.navigate(AppRoutes.TeacherTimetable) },
                onAuth = { role, _, _ ->
                    navController.navigate(
                        if (role == 2) AppRoutes.TeacherAuth else AppRoutes.StudioAuth
                    )
                },
                onMyTeachingCourses = { navController.navigate(AppRoutes.MyTeachingCourses) },
                onMyStudents = { navController.navigate(AppRoutes.MyStudents) },
                onLeaveApproval = { navController.navigate(AppRoutes.LeaveApproval) },
                onReputation = { navController.navigate(AppRoutes.TeacherReputation) },
                onSearch = { navController.navigate(AppRoutes.Search) },
                onAllCourses = { navController.navigate(AppRoutes.CourseBrowse) },
                onAllStudios = { navController.navigate(AppRoutes.Studios) },
                onCourseClick = { course -> navController.navigate(AppRoutes.courseDetail(course.courseId)) },
                onStudioClick = { studio -> navController.navigate(AppRoutes.studioHomepage(studio.studioId)) },
                onStudioOrders = { navController.navigate(AppRoutes.StudioOrderList) },
                onStudioRefunds = { navController.navigate(AppRoutes.StudioRefund) },
                onStudioCourses = { navController.navigate(AppRoutes.StudioCourseList) },
                onStudioStudents = { navController.navigate(AppRoutes.StudioStudentList) },
                onStudioTeachers = { navController.navigate(AppRoutes.StudioTeacherList) },
                onStudioRevenue = { navController.navigate(AppRoutes.StudioRevenue) },
                onStudioCommissions = { navController.navigate(AppRoutes.StudioCommissionReview) }
            )
        }

        // 老师端工作台（独立路由，备用；主入口已统一走 MainTabScreen）
        composable(AppRoutes.TeacherMain) {
            TeacherWorkbenchScreen()
        }

        // 老师课表与排课
        composable(AppRoutes.TeacherTimetable) {
            TeacherTimetableScreen(
                onBack = { navController.popBackStack() },
                onScheduleClick = { item ->
                    ScheduleDetailViewModel.schedule = item
                    navController.navigate(AppRoutes.ScheduleDetail)
                }
            )
        }

        // 排课详情（消课管理）
        composable(AppRoutes.ScheduleDetail) {
            ScheduleDetailScreen(
                onBack = { navController.popBackStack() }
            )
        }

        // 班级列表（课程下的班级）
        composable(AppRoutes.ClassList) {
            ClassListScreen(
                onBack = { navController.popBackStack() },
                onClassClick = { cls ->
                    ClassStudentsData.classId = cls.classId ?: ""
                    ClassStudentsData.className = cls.name ?: ""
                    navController.navigate(AppRoutes.ClassStudents)
                }
            )
        }

        // 班级学生列表
        composable(AppRoutes.ClassStudents) {
            ClassStudentsScreen(
                onBack = { navController.popBackStack() }
            )
        }

        // 工作室更多页（找画室/找老师）
        composable(AppRoutes.Studios) {
            StudiosScreen(
                onBack = { navController.popBackStack() },
                onStudioClick = { studioId ->
                    navController.navigate(AppRoutes.studioHomepage(studioId))
                },
                onTeacherClick = { teacherId ->
                    navController.navigate(AppRoutes.teacherProfile(teacherId))
                }
            )
        }

        // 老师我教的课程
        composable(AppRoutes.MyTeachingCourses) {
            MyTeachingCoursesScreen(
                onBack = { navController.popBackStack() },
                onViewClassList = { item ->
                    ClassListData.courseTitle = item.title ?: ""
                    ClassListData.classes = item.classes ?: emptyList()
                    navController.navigate(AppRoutes.ClassList)
                },
                onPublishConsume = {
                    // 对齐 iOS：发作品消课 → TeacherPostCreateViewController(postType: 2)
                    navController.navigate(AppRoutes.postCreate(role = 2, postType = 2))
                }
            )
        }

        // 老师我的学生
        composable(AppRoutes.MyStudents) {
            MyStudentsScreen(
                onBack = { navController.popBackStack() }
            )
        }

        // 老师请假审批
        composable(AppRoutes.LeaveApproval) {
            LeaveApprovalScreen(
                onBack = { navController.popBackStack() }
            )
        }

        // 老师评价与口碑
        composable(AppRoutes.TeacherReputation) {
            ReputationScreen(
                onBack = { navController.popBackStack() }
            )
        }

        // 综合搜索
        composable(AppRoutes.Search) {
            SearchScreen(
                onBack = { navController.popBackStack() },
                onCourseClick = { courseId -> navController.navigate(AppRoutes.courseDetail(courseId)) },
                onStudioClick = { studioId -> navController.navigate(AppRoutes.studioHomepage(studioId)) },
                onTeacherClick = { teacherId -> navController.navigate(AppRoutes.teacherProfile(teacherId)) }
            )
        }

        // 老师主页（公开）
        composable(
            route = AppRoutes.TeacherProfile,
            arguments = listOf(navArgument("teacherId") { type = NavType.StringType })
        ) { backStackEntry ->
            val teacherId = backStackEntry.arguments?.getString("teacherId") ?: return@composable
            TeacherProfileScreen(
                teacherId = teacherId,
                onBack = { navController.popBackStack() },
                onCourseClick = { courseId -> navController.navigate(AppRoutes.courseDetail(courseId)) }
            )
        }

        // 工作室主页（公开）
        composable(
            route = AppRoutes.StudioHomepage,
            arguments = listOf(navArgument("studioId") { type = NavType.StringType })
        ) { backStackEntry ->
            val studioId = backStackEntry.arguments?.getString("studioId") ?: return@composable
            StudioHomepageScreen(
                studioId = studioId,
                onBack = { navController.popBackStack() },
                onCourseClick = { courseId -> navController.navigate(AppRoutes.courseDetail(courseId)) },
                onTeacherClick = { teacherId -> navController.navigate(AppRoutes.teacherProfile(teacherId)) },
                onPostClick = { postId -> navController.navigate(AppRoutes.postDetail(postId)) },
                onChat = { conversation ->
                    MessageViewModel.navConversation = conversation
                    navController.navigate(AppRoutes.chat(conversation.conversationId))
                }
            )
        }

        // 工作室端总览（独立路由，备用；主入口已统一走 MainTabScreen）
        composable(AppRoutes.StudioMain) {
            StudioOverviewScreen(
                onRevenue = { navController.navigate(AppRoutes.StudioRevenue) }
            )
        }

        // 工作室订单列表
        composable(AppRoutes.StudioOrderList) {
            StudioOrderListScreen(
                onBack = { navController.popBackStack() },
                onOrderClick = { order ->
                    navController.navigate(AppRoutes.studioOrderDetail(order.orderId))
                }
            )
        }

        // 工作室订单详情
        composable(
            AppRoutes.StudioOrderDetail,
            arguments = listOf(navArgument("orderId") { type = NavType.StringType })
        ) { entry ->
            val orderId = entry.arguments?.getString("orderId") ?: return@composable
            StudioOrderDetailScreen(
                orderId = orderId,
                onBack = { navController.popBackStack() }
            )
        }

        // 工作室退款审核
        composable(AppRoutes.StudioRefund) {
            StudioRefundScreen(
                initialStatus = 0,
                onBack = { navController.popBackStack() }
            )
        }

        // 工作室老师管理
        composable(AppRoutes.StudioTeacherList) {
            StudioTeacherListScreen(
                onBack = { navController.popBackStack() },
                onTeacherClick = { teacher ->
                    navController.navigate(
                        AppRoutes.studioTeacherDetail(teacher.teacherId, teacher.displayName)
                    )
                },
                onApplications = {
                    navController.navigate(AppRoutes.StudioTeacherApplication)
                }
            )
        }

        // 工作室老师详情
        composable(
            AppRoutes.StudioTeacherDetail,
            arguments = listOf(
                navArgument("teacherId") { type = NavType.StringType },
                navArgument("name") {
                    type = NavType.StringType
                    defaultValue = "老师详情"
                }
            )
        ) { entry ->
            val teacherId = entry.arguments?.getString("teacherId") ?: return@composable
            val name = entry.arguments?.getString("name") ?: "老师详情"
            StudioTeacherDetailScreen(
                teacherId = teacherId,
                teacherName = name,
                onBack = { navController.popBackStack() }
            )
        }

        // 工作室合作申请
        composable(AppRoutes.StudioTeacherApplication) {
            StudioTeacherApplicationScreen(
                onBack = { navController.popBackStack() }
            )
        }

        // 工作室学员管理
        composable(AppRoutes.StudioStudentList) {
            StudioStudentListScreen(
                onBack = { navController.popBackStack() },
                onStudentClick = { student ->
                    navController.navigate(
                        AppRoutes.studioStudentDetail(student.childId, student.displayName)
                    )
                }
            )
        }

        // 工作室学员详情
        composable(
            AppRoutes.StudioStudentDetail,
            arguments = listOf(
                navArgument("childId") { type = NavType.StringType },
                navArgument("name") {
                    type = NavType.StringType
                    defaultValue = "学员详情"
                }
            )
        ) { entry ->
            val childId = entry.arguments?.getString("childId") ?: return@composable
            val name = entry.arguments?.getString("name") ?: "学员详情"
            StudioStudentDetailScreen(
                childId = childId,
                studentName = name,
                onBack = { navController.popBackStack() }
            )
        }

        // 工作室佣金审核
        composable(AppRoutes.StudioCommissionReview) {
            StudioCommissionReviewScreen(
                onBack = { navController.popBackStack() }
            )
        }

        // 工作室收益中心
        composable(AppRoutes.StudioRevenue) {
            StudioRevenueScreen(
                onBack = { navController.popBackStack() },
                onWithdrawals = { navController.navigate(AppRoutes.CommissionWithdrawals) }
            )
        }

        // 工作室课程管理
        composable(AppRoutes.StudioCourseList) {
            StudioCourseListScreen(
                onBack = { navController.popBackStack() },
                onPreview = { courseId ->
                    navController.navigate(AppRoutes.courseDetail(courseId))
                }
            )
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
                onStudy = { childId, courseId, title ->
                    navController.navigate(AppRoutes.courseStudy(childId, courseId, title))
                },
                onRefundDetail = { refundId ->
                    navController.navigate(AppRoutes.refundDetail(refundId))
                },
                onReorder = { courseId ->
                    navController.navigate(AppRoutes.courseDetail(courseId))
                }
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
                onStudy = { childId, courseId, title ->
                    navController.navigate(AppRoutes.courseStudy(childId, courseId, title))
                },
                onRefundDetail = { refundId ->
                    navController.navigate(AppRoutes.refundDetail(refundId))
                },
                onReorder = { courseId ->
                    navController.navigate(AppRoutes.courseDetail(courseId))
                },
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

        // MARK: - 孩子模块

        // 我的孩子列表
        composable(AppRoutes.MyChildren) {
            MyChildrenScreen(
                onBack = { navController.popBackStack() },
                onChildClick = { child ->
                    ChildViewModel.navChild = child
                    navController.navigate(AppRoutes.childHome(child.childId))
                },
                onAddChild = {
                    navController.navigate(AppRoutes.AddChild)
                }
            )
        }

        // 添加孩子
        composable(AppRoutes.AddChild) {
            AddChildScreen(
                onClose = { navController.popBackStack() },
                onSaved = { navController.popBackStack() }
            )
        }

        // 孩子主页（需从 navChild 缓存读取孩子对象）
        composable(
            route = AppRoutes.ChildHome,
            arguments = listOf(navArgument("childId") { type = NavType.StringType })
        ) {
            val child = ChildViewModel.navChild
            if (child != null) {
                ChildHomeScreen(
                    child = child,
                    onBack = { navController.popBackStack() },
                    onBalanceDetail = { childId, nickname ->
                        navController.navigate(AppRoutes.childBalance(childId, nickname))
                    },
                    onWorkClick = { postId ->
                        navController.navigate(AppRoutes.postDetail(postId))
                    },
                    onCourseClick = { childId, courseId, courseTitle ->
                        navController.navigate(AppRoutes.courseStudy(childId, courseId, courseTitle))
                    }
                )
            } else {
                LaunchedEffect(Unit) { navController.popBackStack() }
            }
        }

        // 课时明细
        composable(
            route = AppRoutes.ChildBalance,
            arguments = listOf(
                navArgument("childId") { type = NavType.StringType },
                navArgument("nickname") {
                    type = NavType.StringType
                    defaultValue = ""
                }
            )
        ) { entry ->
            val childId = entry.arguments?.getString("childId") ?: ""
            val nickname = entry.arguments?.getString("nickname") ?: ""
            ChildBalanceScreen(
                childId = childId,
                childNickname = nickname,
                onBack = { navController.popBackStack() }
            )
        }

        // MARK: - 广场模块

        // 帖子详情
        composable(
            route = AppRoutes.PostDetail,
            arguments = listOf(navArgument("postId") { type = NavType.StringType })
        ) { entry ->
            val postId = entry.arguments?.getString("postId") ?: ""
            PostDetailScreen(
                postId = postId,
                onBack = { navController.popBackStack() },
                onEdit = { post ->
                    PlazaViewModel.navEditPost = post
                    // 工作室帖子按家长链路编辑（对齐发布侧 role 3→1）
                    val editRole = (post.author?.role ?: 1).let { if (it == 3) 1 else it }
                    navController.navigate(
                        AppRoutes.postCreate(editRole, post.type)
                    )
                },
                onEnroll = { courseId ->
                    navController.navigate(AppRoutes.courseDetail(courseId))
                },
                onDeleted = { navController.popBackStack() }
            )
        }

        // 发帖 / 编辑帖子（编辑模式通过 navEditPost 缓存触发）
        composable(
            route = AppRoutes.PostCreate,
            arguments = listOf(
                navArgument("role") { type = NavType.IntType },
                navArgument("postType") { type = NavType.IntType }
            )
        ) { entry ->
            val role = entry.arguments?.getInt("role") ?: 1
            val postType = entry.arguments?.getInt("postType") ?: 1
            PostCreateScreen(
                role = role,
                postType = postType,
                onClose = { navController.popBackStack() },
                onPublished = { navController.popBackStack() }
            )
        }

        // MARK: - 课程模块

        // 课程详情
        composable(
            route = AppRoutes.CourseDetail,
            arguments = listOf(navArgument("courseId") { type = NavType.StringType })
        ) { entry ->
            val courseId = entry.arguments?.getString("courseId") ?: ""
            CourseDetailScreen(
                courseId = courseId,
                onBack = { navController.popBackStack() },
                onEnrollSuccess = { orderId ->
                    navController.navigate(AppRoutes.orderDetail(orderId))
                },
                onAllReviews = {
                    navController.navigate(AppRoutes.courseReviews(courseId))
                },
                onWriteReview = { courseTitle ->
                    navController.navigate(AppRoutes.reviewCompose(courseId, courseTitle))
                },
                onChat = { conversation ->
                    MessageViewModel.navConversation = conversation
                    navController.navigate(AppRoutes.chat(conversation.conversationId))
                }
            )
        }

        // 课程浏览（首页「全部」入口，标签筛选列表）
        composable(AppRoutes.CourseBrowse) {
            CourseBrowseScreen(
                onBack = { navController.popBackStack() },
                onCourseClick = { courseId ->
                    navController.navigate(AppRoutes.courseDetail(courseId))
                }
            )
        }

        // 课程列表（搜索）
        composable(AppRoutes.CourseList) {
            CourseListScreen(
                onCourseClick = { courseId ->
                    navController.navigate(AppRoutes.courseDetail(courseId))
                }
            )
        }

        // 我的课程（在学课程列表）
        composable(
            route = AppRoutes.MyCourses,
            arguments = listOf(
                navArgument("childId") { type = NavType.StringType; defaultValue = "" },
                navArgument("childName") { type = NavType.StringType; defaultValue = "" }
            )
        ) { entry ->
            val childId = entry.arguments?.getString("childId")?.takeIf { it.isNotEmpty() }
            val childName = entry.arguments?.getString("childName")?.takeIf { it.isNotEmpty() }
            MyCoursesScreen(
                childId = childId,
                childName = childName,
                onBack = { navController.popBackStack() },
                onCourseClick = { cid, courseId, title ->
                    navController.navigate(AppRoutes.courseStudy(cid, courseId, title))
                }
            )
        }

        // 课程学习（课时进度 + 请假）
        composable(
            route = AppRoutes.CourseStudy,
            arguments = listOf(
                navArgument("childId") { type = NavType.StringType },
                navArgument("courseId") { type = NavType.StringType },
                navArgument("title") { type = NavType.StringType; defaultValue = "" }
            )
        ) { entry ->
            val childId = entry.arguments?.getString("childId") ?: ""
            val courseId = entry.arguments?.getString("courseId") ?: ""
            val title = entry.arguments?.getString("title") ?: ""
            CourseStudyScreen(
                childId = childId,
                courseId = courseId,
                courseTitle = title,
                onBack = { navController.popBackStack() }
            )
        }

        // 课程完整评价列表
        composable(
            route = AppRoutes.CourseReviews,
            arguments = listOf(navArgument("courseId") { type = NavType.StringType })
        ) { entry ->
            val courseId = entry.arguments?.getString("courseId") ?: return@composable
            CourseReviewsScreen(
                courseId = courseId,
                onBack = { navController.popBackStack() }
            )
        }

        // 写评价 / 编辑评价
        composable(
            route = AppRoutes.ReviewCompose,
            arguments = listOf(
                navArgument("courseId") { type = NavType.StringType },
                navArgument("courseTitle") { type = NavType.StringType; defaultValue = "" },
                navArgument("isEdit") { type = NavType.BoolType; defaultValue = false }
            )
        ) { entry ->
            val courseId = entry.arguments?.getString("courseId") ?: return@composable
            val courseTitle = entry.arguments?.getString("courseTitle") ?: ""
            val isEdit = entry.arguments?.getBoolean("isEdit") ?: false
            ReviewComposeScreen(
                courseId = courseId,
                courseTitle = courseTitle,
                isEditMode = isEdit,
                onBack = { navController.popBackStack() }
            )
        }

        // 我的评价
        composable(AppRoutes.MyReviews) {
            MyReviewsScreen(
                onBack = { navController.popBackStack() },
                onEditReview = { review ->
                    ReviewComposeViewModel.editReview = review
                    val courseId = review.course?.courseId ?: ""
                    val courseTitle = review.course?.title ?: ""
                    navController.navigate(AppRoutes.reviewCompose(courseId, courseTitle, isEdit = true))
                }
            )
        }

        // MARK: - 消息模块

        // 聊天页（会话对象通过 navConversation 缓存传递）
        composable(
            route = AppRoutes.Chat,
            arguments = listOf(navArgument("conversationId") { type = NavType.StringType })
        ) { entry ->
            val conversationId = entry.arguments?.getString("conversationId") ?: ""
            ChatScreen(
                conversationId = conversationId,
                onBack = { navController.popBackStack() }
            )
        }

        // 关注列表（选人发起聊天）
        composable(AppRoutes.FollowingList) {
            FollowingListScreen(
                onBack = { navController.popBackStack() },
                onConversationCreated = { conversation ->
                    MessageViewModel.navConversation = conversation
                    navController.navigate(AppRoutes.chat(conversation.conversationId)) {
                        popUpTo(AppRoutes.FollowingList) { inclusive = true }
                    }
                }
            )
        }

        // MARK: - 我的模块

        // 设置
        composable(AppRoutes.Settings) {
            SettingsScreen(
                onBack = { navController.popBackStack() },
                onEditProfile = { navController.navigate(AppRoutes.EditProfile) },
                onAccountSecurity = { navController.navigate(AppRoutes.AccountSecurity) },
                onWallet = { navController.navigate(AppRoutes.Wallet) },
                onAbout = { navController.navigate(AppRoutes.About) },
                onLoggedOut = {
                    MessageSocketService.disconnect()
                    navController.navigate(AppRoutes.Login) {
                        popUpTo(0) { inclusive = true }
                    }
                }
            )
        }

        // 编辑资料
        composable(AppRoutes.EditProfile) {
            EditProfileScreen(onBack = { navController.popBackStack() })
        }

        // 账号与安全
        composable(AppRoutes.AccountSecurity) {
            AccountSecurityScreen(
                onBack = { navController.popBackStack() },
                onChangePassword = { navController.navigate(AppRoutes.ChangePassword) },
                onChangePhone = { navController.navigate(AppRoutes.ChangePhone) },
                onDeactivate = { navController.navigate(AppRoutes.DeactivateAccount) }
            )
        }

        // 修改密码
        composable(AppRoutes.ChangePassword) {
            ChangePasswordScreen(onBack = { navController.popBackStack() })
        }

        // 更换手机号
        composable(AppRoutes.ChangePhone) {
            ChangePhoneScreen(onBack = { navController.popBackStack() })
        }

        // 注销账号
        composable(AppRoutes.DeactivateAccount) {
            DeactivateAccountScreen(
                onBack = { navController.popBackStack() },
                onLoggedOut = {
                    MessageSocketService.disconnect()
                    navController.navigate(AppRoutes.Login) {
                        popUpTo(0) { inclusive = true }
                    }
                }
            )
        }

        // 关于艺启
        composable(AppRoutes.About) {
            AboutScreen(onBack = { navController.popBackStack() })
        }

        // 收益中心
        composable(AppRoutes.Wallet) {
            WalletScreen(
                onBack = { navController.popBackStack() },
                onOpenWithdrawals = { navController.navigate(AppRoutes.CommissionWithdrawals) },
                onOpenStudioDetail = { group ->
                    CommissionNavCache.studioGroup = group
                    navController.navigate(AppRoutes.StudioCommissionDetail)
                },
                onOpenWithdrawalDetail = { item ->
                    CommissionNavCache.withdrawal = item
                    navController.navigate(AppRoutes.CommissionWithdrawalDetail)
                }
            )
        }

        // 领取记录列表
        composable(AppRoutes.CommissionWithdrawals) {
            CommissionWithdrawalsScreen(
                onBack = { navController.popBackStack() },
                onOpenDetail = { item ->
                    CommissionNavCache.withdrawal = item
                    navController.navigate(AppRoutes.CommissionWithdrawalDetail)
                }
            )
        }

        // 领取单详情
        composable(AppRoutes.CommissionWithdrawalDetail) {
            CommissionWithdrawalDetailScreen(
                onBack = { navController.popBackStack() }
            )
        }

        // 工作室佣金详情
        composable(AppRoutes.StudioCommissionDetail) {
            StudioCommissionDetailScreen(
                onBack = { navController.popBackStack() },
                onOpenWithdrawalDetail = { item ->
                    CommissionNavCache.withdrawal = item
                    navController.navigate(AppRoutes.CommissionWithdrawalDetail)
                }
            )
        }

        // 收藏与动态
        composable(AppRoutes.Favorites) {
            FavoritesAndDynamicsScreen(
                onBack = { navController.popBackStack() },
                onPostClick = { postId ->
                    navController.navigate(AppRoutes.postDetail(postId))
                }
            )
        }

        // 作品管理
        composable(AppRoutes.WorkManagement) {
            WorkManagementScreen(
                onBack = { navController.popBackStack() },
                onPostClick = { postId ->
                    navController.navigate(AppRoutes.postDetail(postId))
                },
                onPublish = {
                    navController.navigate(AppRoutes.postCreate(role = 1, postType = 1))
                }
            )
        }

        // 老师认证
        composable(AppRoutes.TeacherAuth) {
            TeacherAuthScreen(
                onBack = { navController.popBackStack() }
            )
        }

        // 工作室入驻认证
        composable(AppRoutes.StudioAuth) {
            StudioAuthScreen(
                onBack = { navController.popBackStack() }
            )
        }
    }
}

/** 按角色返回主界面路由：所有角色统一走 MainTabScreen（5 Tab），tab 内容按角色切换 */
private fun mainRouteForRole(role: Int): String = AppRoutes.ParentMain