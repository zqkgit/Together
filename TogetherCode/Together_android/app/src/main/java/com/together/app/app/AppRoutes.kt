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

    // 课程模块
    const val CourseDetail = "course_detail/{courseId}"
    const val CourseList = "course_list"

    // 消息模块
    const val Chat = "chat/{conversationId}"
    const val FollowingList = "following_list"

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
    fun chat(conversationId: String) = "chat/$conversationId"
}