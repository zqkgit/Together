package com.together.app.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// MARK: - 订单状态（对齐后端 orders.status：0 待收款 / 1 待确认收款 / 2 已收款 / 3 退款审核中 / 4 待家长确认退款 / 5 已退款 / 6 已取消）

enum class OrderStatus(val raw: Int, val text: String) {
    PENDING_COLLECT(0, "待付款"),    // 待收款（线下付款后传凭证，等待机构确认）
    PAYMENT_REVIEW(1, "待确认"),     // 待确认收款（家长已上传凭证，等待机构确认）
    COLLECTED(2, "已报名"),          // 已收款（机构确认到账，已发课时）
    REFUND_REVIEW(3, "退款审核中"),
    REFUND_CONFIRM(4, "待确认退款"),
    REFUNDED(5, "已退款"),
    CANCELLED(6, "已取消");

    companion object {
        fun from(raw: Int?): OrderStatus = entries.firstOrNull { it.raw == raw } ?: CANCELLED
    }
}

// MARK: - 订单层退款聚合状态：0 无 / 1 退款中 / 2 已退款 / 3 已驳回

enum class OrderRefundStatus(val raw: Int, val text: String) {
    NONE(0, "无"),
    PROCESSING(1, "退款中"),
    REFUNDED(2, "已退款"),
    REJECTED(3, "已驳回");

    companion object {
        fun from(raw: Int?): OrderRefundStatus = entries.firstOrNull { it.raw == raw } ?: NONE
    }
}

// MARK: - 线下付款方式（仅记录，不跳转支付、不展示收款码）

enum class PayMethod(val code: String, val text: String, val icon: String, val isOnline: Boolean) {
    CASH("cash", "现金", "banknote", false),
    WECHAT("wechat", "微信转账", "message", true),
    ALIPAY("alipay", "支付宝转账", "a_circle", true),
    BANK("bank", "银行转账", "building", true),
    QRCODE("qrcode", "扫码转账", "qrcode", true),
    OTHER("other", "其他", "ellipsis", true);

    companion object {
        fun from(raw: String?): PayMethod? = entries.firstOrNull { it.code == raw }
    }
}

// MARK: - 付款记录状态

enum class PaymentStatus(val raw: Int, val text: String) {
    PENDING(0, "待确认"),    // 待机构确认
    CONFIRMED(1, "已确认"),  // 已确认（已收款）
    REJECTED(2, "已驳回");   // 凭证被驳回

    companion object {
        fun from(raw: Int?): PaymentStatus = entries.firstOrNull { it.raw == raw } ?: PENDING
    }
}

// MARK: - 付款记录（一笔=一次收款登记 / 一张凭证）

@Serializable
data class PaymentItem(
    @SerialName("payment_id") val paymentId: String? = null,
    @SerialName("payment_no") val paymentNo: String? = null,
    @SerialName("channel") val channel: String? = null,
    @SerialName("pay_method") val payMethod: String? = null,
    @SerialName("pay_method_text") val payMethodText: String? = null,
    @SerialName("amount") val amount: Int? = null,
    @SerialName("status") val status: Int? = null,
    @SerialName("status_text") val statusText: String? = null,
    @SerialName("voucher_images") val voucherImages: List<String>? = null,
    @SerialName("payer_note") val payerNote: String? = null,
    /** 0 = 家长上传，1 = 工作室代登记 */
    @SerialName("upload_by") val uploadBy: Int? = null,
    @SerialName("reject_reason") val rejectReason: String? = null,
    @SerialName("paid_at") val paidAt: String? = null,
    @SerialName("created_at") val createdAt: String? = null
) {
    val statusValue: PaymentStatus get() = PaymentStatus.from(status)
    val methodText: String get() = payMethodText ?: PayMethod.from(payMethod ?: channel)?.text ?: "线下结算"
    val images: List<String> get() = voucherImages ?: emptyList()
    val isFromStudio: Boolean get() = (uploadBy ?: 0) == 1
    val timeText: String get() = fmtTime(createdAt ?: paidAt)
    val amountText: String get() = (amount ?: 0).fenToYuanText()
}

/** 时间格式化：去掉 T，取前 16 字符 */
fun fmtTime(raw: String?): String {
    if (raw.isNullOrBlank()) return "-"
    return raw.replace("T", " ").take(16)
}

// MARK: - 订单子模型

@Serializable
data class OrderUserBrief(
    @SerialName("user_id") val userId: String? = null,
    @SerialName("nickname") val nickname: String? = null,
    @SerialName("phone") val phone: String? = null
)

@Serializable
data class OrderChildBrief(
    @SerialName("child_id") val childId: String? = null,
    @SerialName("nickname") val nickname: String? = null,
    @SerialName("birthday") val birthday: String? = null
)

@Serializable
data class OrderStudioBrief(
    @SerialName("studio_id") val studioId: String? = null,
    @SerialName("name") val name: String? = null
)

@Serializable
data class OrderCourseBrief(
    @SerialName("course_id") val courseId: String? = null,
    @SerialName("title") val title: String? = null,
    @SerialName("cover") val cover: String? = null
)

@Serializable
data class OrderClassBrief(
    @SerialName("class_id") val classId: String? = null,
    @SerialName("name") val name: String? = null
)

@Serializable
data class OrderPackageBrief(
    @SerialName("package_id") val packageId: String? = null,
    @SerialName("name") val name: String? = null,
    @SerialName("lessons") val lessons: Int? = null
)

@Serializable
data class OrderRefundBrief(
    @SerialName("refund_id") val refundId: String? = null,
    @SerialName("amount") val amount: Int? = null,
    @SerialName("requested_lessons") val requestedLessons: Int? = null,
    @SerialName("refundable_lessons") val refundableLessons: Int? = null,
    @SerialName("status") val status: Int? = null,
    @SerialName("status_text") val statusText: String? = null,
    @SerialName("reason") val reason: String? = null,
    @SerialName("created_at") val createdAt: String? = null
)

// MARK: - 订单

@Serializable
data class OrderItem(
    @SerialName("order_id") val orderId: String? = null,
    @SerialName("order_no") val orderNo: String? = null,
    @SerialName("status") val status: Int? = null,
    /** 0 家长报名 / 1 工作室手动建单 */
    @SerialName("source") val source: Int? = null,
    @SerialName("source_text") val sourceText: String? = null,
    @SerialName("total_lessons") val totalLessons: Int? = null,
    @SerialName("consumed_lessons") val consumedLessons: Int? = null,
    @SerialName("refunded_lessons") val refundedLessons: Int? = null,
    @SerialName("remaining_lessons") val remainingLessons: Int? = null,
    @SerialName("total_amount") val totalAmount: Int? = null,      // 分
    @SerialName("paid_amount") val paidAmount: Int? = null,
    @SerialName("refund_amount") val refundAmount: Int? = null,
    @SerialName("refund_status") val refundStatus: Int? = null,
    @SerialName("refund_status_text") val refundStatusText: String? = null,
    /** 当前应跳转的退款单 id（多笔退款时指向最新有效单） */
    @SerialName("current_refund_id") val currentRefundId: String? = null,
    @SerialName("can_apply_refund") val canApplyRefund: Boolean? = null,
    @SerialName("refund_expire_at") val refundExpireAt: String? = null,
    @SerialName("pay_channel") val payChannel: String? = null,
    @SerialName("pay_method") val payMethod: String? = null,
    @SerialName("pay_method_text") val payMethodText: String? = null,
    @SerialName("paid_at") val paidAt: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("child") val child: OrderChildBrief? = null,
    @SerialName("studio") val studio: OrderStudioBrief? = null,
    @SerialName("course") val course: OrderCourseBrief? = null,
    @SerialName("package") val pkg: OrderPackageBrief? = null,
    @SerialName("class") val klass: OrderClassBrief? = null,
    @SerialName("user") val user: OrderUserBrief? = null,
    @SerialName("payments") val payments: List<PaymentItem>? = null,
    @SerialName("refunds") val refunds: List<OrderRefundBrief>? = null
) {
    val statusValue: OrderStatus get() = OrderStatus.from(status)
    val refundStatusValue: OrderRefundStatus get() = OrderRefundStatus.from(refundStatus)

    val hasActiveRefund: Boolean get() = refundStatusValue == OrderRefundStatus.PROCESSING

    /** 最近一笔被驳回的凭证（待收款状态下提示重新上传） */
    val rejectedPayment: PaymentItem?
        get() = (payments ?: emptyList()).firstOrNull { it.statusValue == PaymentStatus.REJECTED }

    /** 最近一笔待确认 / 已确认的付款记录 */
    val latestPayment: PaymentItem?
        get() {
            val list = payments ?: emptyList()
            return list.firstOrNull { it.statusValue == PaymentStatus.PENDING }
                ?: list.firstOrNull { it.statusValue == PaymentStatus.CONFIRMED }
                ?: list.firstOrNull()
        }

    /** 付款凭证已提交、等待机构确认：此时不可重复上传凭证，也不可取消订单 */
    val isVoucherUnderReview: Boolean get() = statusValue == OrderStatus.PAYMENT_REVIEW

    /** 最近一笔退款单（详情页跳转退款进度用） */
    val latestRefundId: String?
        get() = currentRefundId ?: refunds?.firstOrNull()?.refundId

    /** 金额（分 → 元） */
    val amountText: String get() = (totalAmount ?: 0).fenToYuanText()

    /** 课程名 · 节数（如 森林水彩启蒙·16节） */
    val courseTitleWithLessons: String
        get() {
            val title = course?.title ?: "未知课程"
            val lessons = pkg?.lessons ?: totalLessons ?: 0
            return "${title}·${lessons}节"
        }

    /** 机构 · 班级 */
    val studioClassText: String
        get() {
            val studioName = studio?.name ?: "未知机构"
            val className = klass?.name
            return if (!className.isNullOrBlank()) "$studioName · $className" else studioName
        }

    /** 机构 */
    val studioTeacherText: String get() = studio?.name ?: "未知机构"

    val childName: String? get() = child?.nickname

    /** 课程 · 班级（详情用） */
    val courseClassText: String
        get() {
            val title = course?.title ?: "未知课程"
            val className = klass?.name
            return if (!className.isNullOrBlank()) "$title · $className" else title
        }
}

// MARK: - 退款详情（GET /orders/refunds/:id）

@Serializable
data class RefundDetail(
    @SerialName("refund_id") val refundId: String? = null,
    @SerialName("order_id") val orderId: String? = null,
    @SerialName("order_no") val orderNo: String? = null,
    @SerialName("course_title") val courseTitle: String? = null,
    @SerialName("course_cover") val courseCover: String? = null,
    @SerialName("studio_name") val studioName: String? = null,
    @SerialName("child_name") val childName: String? = null,
    @SerialName("total_lessons") val totalLessons: Int? = null,
    @SerialName("consumed_lessons") val consumedLessons: Int? = null,
    @SerialName("refunded_lessons") val refundedLessons: Int? = null,
    @SerialName("balance_remaining") val balanceRemaining: Int? = null,
    @SerialName("valid_to") val validTo: String? = null,
    @SerialName("requested_lessons") val requestedLessons: Int? = null,
    /** 机构审核锁定的实退课时（申请后若已消课，可能少于申请课时；nil=尚未审核） */
    @SerialName("approved_lessons") val approvedLessons: Int? = null,
    @SerialName("refundable_lessons") val refundableLessons: Int? = null,
    @SerialName("unit_price_text") val unitPriceText: String? = null,
    @SerialName("amount") val amount: Int? = null,
    @SerialName("amount_text") val amountText: String? = null,
    @SerialName("reason") val reason: String? = null,
    @SerialName("status") val status: Int? = null,
    @SerialName("status_text") val statusText: String? = null,
    /** 线下退款方式 / 文案 */
    @SerialName("refund_method") val refundMethod: String? = null,
    @SerialName("refund_method_text") val refundMethodText: String? = null,
    /** 机构上传的线下打款凭证 */
    @SerialName("voucher_images") val voucherImages: List<String>? = null,
    @SerialName("reject_reason") val rejectReason: String? = null,
    /** status=1 待家长确认时为 true */
    @SerialName("can_confirm") val canConfirm: Boolean? = null,
    @SerialName("confirmed_at") val confirmedAt: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("reviewed_at") val reviewedAt: String? = null,
    @SerialName("refunded_at") val refundedAt: String? = null,
    @SerialName("steps") val steps: List<RefundStep>? = null
)

@Serializable
data class RefundStep(
    @SerialName("key") val key: String? = null,
    @SerialName("title") val title: String? = null,
    @SerialName("time") val time: String? = null,
    @SerialName("done") val done: Boolean? = null,
    @SerialName("current") val current: Boolean? = null
)