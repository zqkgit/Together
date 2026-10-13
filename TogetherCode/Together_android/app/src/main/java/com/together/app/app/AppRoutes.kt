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

    fun verifyCode(phone: String) = "verify_code/$phone"
    fun orderDetail(orderId: String) = "order_detail/$orderId"
    fun paymentVoucher(orderId: String) = "payment_voucher/$orderId"
    fun orderRefund(orderId: String) = "order_refund/$orderId"
    fun refundDetail(refundId: String) = "refund_detail/$refundId"
}