package com.together.app.app

object AppRoutes {
    const val Login = "login"
    const val PhoneLogin = "phone_login"
    const val VerifyCode = "verify_code/{phone}"

    const val ParentMain = "parent_main"
    const val TeacherMain = "teacher_main"
    const val StudioMain = "studio_main"

    // 订单模块
    const val MyOrders = "my_orders"
    const val OrderDetail = "order_detail/{orderId}"
    const val PaymentVoucher = "payment_voucher/{orderId}"
    const val OrderRefund = "order_refund/{orderId}"
    const val RefundDetail = "refund_detail/{refundId}"

    // 孩子模块
    const val MyChildren = "my_children"
    const val AddChild = "add_child"
    const val ChildHome = "child_home/{childId}"
    const val ChildBalance = "child_balance/{childId}?nickname={nickname}"

    // 广场模块
    const val PostDetail = "post_detail/{postId}"
    const val PostCreate = "post_create/{role}/{postType}"
    const val LocationSearch = "location_search"
    const val Search = "search"
    const val TeacherProfile = "teacher_profile/{teacherId}"
    const val StudioHomepage = "studio_homepage/{studioId}"

    // 课程模块
    const val CourseDetail = "course_detail/{courseId}"
    const val CourseList = "course_list"
    const val CourseBrowse = "course_browse"
    const val MyCourses = "my_courses?childId={childId}&childName={childName}"
    const val CourseStudy = "course_study/{childId}/{courseId}?title={title}"
    const val CourseReviews = "course_reviews/{courseId}"
    const val ReviewCompose = "review_compose/{courseId}?courseTitle={courseTitle}&isEdit={isEdit}"
    const val MyReviews = "my_reviews"

    // 消息模块
    const val Chat = "chat/{conversationId}"
    const val FollowingList = "following_list"

    // 收益中心（佣金）
    const val Wallet = "wallet"
    const val CommissionWithdrawals = "commission_withdrawals"
    const val CommissionWithdrawalDetail = "commission_withdrawal_detail"
    const val StudioCommissionDetail = "studio_commission_detail"

    // 我的模块
    const val Settings = "settings"
    const val EditProfile = "edit_profile"
    const val AccountSecurity = "account_security"
    const val ChangePassword = "change_password"
    const val ChangePhone = "change_phone"
    const val DeactivateAccount = "deactivate_account"
    const val About = "about"
    const val TeacherAuth = "teacher_auth"
    const val TeacherTimetable = "teacher_timetable"
    const val ScheduleDetail = "schedule_detail"
    const val ClassList = "class_list"
    const val ClassStudents = "class_students"

    // 工作室更多页
    const val Studios = "studios"
    const val MyTeachingCourses = "my_teaching_courses"
    const val MyStudents = "my_students"
    const val LeaveApproval = "leave_approval"
    const val TeacherReputation = "teacher_reputation"
    const val StudioAuth = "studio_auth"
    const val Favorites = "favorites"
    const val WorkManagement = "work_management"

    // 工作室模块
    const val StudioOrderList = "studio_order_list"
    const val StudioOrderDetail = "studio_order_detail/{orderId}"
    const val StudioRefund = "studio_refund"
    const val StudioTeacherList = "studio_teacher_list"
    const val StudioTeacherDetail = "studio_teacher_detail/{teacherId}?name={name}"
    const val StudioTeacherApplication = "studio_teacher_application"
    const val StudioStudentList = "studio_student_list"
    const val StudioStudentDetail = "studio_student_detail/{childId}?name={name}"
    const val StudioCommissionReview = "studio_commission_review"
    const val StudioRevenue = "studio_revenue"
    const val StudioCourseList = "studio_course_list"

    fun verifyCode(phone: String) = "verify_code/$phone"
    fun orderDetail(orderId: String) = "order_detail/$orderId"
    fun paymentVoucher(orderId: String) = "payment_voucher/$orderId"
    fun orderRefund(orderId: String) = "order_refund/$orderId"
    fun refundDetail(refundId: String) = "refund_detail/$refundId"
    fun childHome(childId: String) = "child_home/$childId"
    fun childBalance(childId: String, nickname: String) = "child_balance/$childId?nickname=$nickname"
    fun postDetail(postId: String) = "post_detail/$postId"
    fun postCreate(role: Int, postType: Int) = "post_create/$role/$postType"
    fun courseDetail(courseId: String) = "course_detail/$courseId"
    fun myCourses(childId: String? = null, childName: String? = null): String {
        val cid = childId?.takeIf { it.isNotEmpty() } ?: ""
        val cname = childName?.takeIf { it.isNotEmpty() } ?: ""
        return "my_courses?childId=$cid&childName=$cname"
    }
    fun courseStudy(childId: String, courseId: String, title: String = ""): String {
        return "course_study/$childId/$courseId?title=$title"
    }
    fun courseReviews(courseId: String) = "course_reviews/$courseId"
    fun reviewCompose(courseId: String, courseTitle: String = "", isEdit: Boolean = false): String {
        return "review_compose/$courseId?courseTitle=${courseTitle}&isEdit=$isEdit"
    }
    fun chat(conversationId: String) = "chat/$conversationId"
    fun teacherProfile(teacherId: String) = "teacher_profile/$teacherId"
    fun studioHomepage(studioId: String) = "studio_homepage/$studioId"
    fun studioOrderDetail(orderId: String) = "studio_order_detail/$orderId"
    fun studioTeacherDetail(teacherId: String, name: String) = "studio_teacher_detail/$teacherId?name=$name"
    fun studioStudentDetail(childId: String, name: String) = "studio_student_detail/$childId?name=$name"
}