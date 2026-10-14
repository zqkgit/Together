package com.together.app.services

import com.together.app.core.network.ApiService
import com.together.app.core.network.JsonHelper.decode
import com.together.app.core.network.JsonHelper.decodeList
import com.together.app.core.network.JsonHelper.int
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.text.DecimalFormat

/**
 * 工作室端服务（对齐 iOS StudioService）
 * 口径：App 侧 /v1/studio/ 前缀；金额单位「分」，端上格式化
 */
object StudioService {

    // MARK: - 金额格式化工具

    /** 分 → 千分位数字（不带币种前缀），整数不带小数 */
    fun groupedNumber(fen: Int): String {
        val yuan = fen / 100.0
        val isInteger = yuan == yuan.toLong().toDouble()
        val fmt = DecimalFormat("#,##0${if (isInteger) "" else ".00"}")
        return fmt.format(yuan)
    }

    /** 分 → "¥ 86,420" */
    fun amountText(fen: Int): String = "¥ ${groupedNumber(fen)}"

    /** 分 → 带符号增量文案 "+¥ 2,180" */
    fun signedAmountText(fen: Int): String =
        "${if (fen >= 0) "+" else "-"}${amountText(kotlin.math.abs(fen))}"

    /** 分 → "¥440.00"（两位小数） */
    fun amountText2(fen: Int): String = String.format("¥%.2f", fen / 100.0)

    // MARK: - 工作室「我的」模型

    @Serializable
    data class StudioMineProfile(
        @SerialName("studio_id") val studioId: String? = null,
        @SerialName("user_id") val userId: String? = null,
        val name: String? = null,
        val cover: String? = null,
        val avatar: String? = null,
        val intro: String? = null,
        val city: String? = null,
        val address: String? = null,
        @SerialName("business_type") val businessType: String? = null,
        @SerialName("type_tags") val typeTags: List<String>? = null,
        val phone: String? = null,
        @SerialName("cert_status") val certStatus: Int? = null,
        val status: Int? = null,
        @SerialName("joined_at") val joinedAt: String? = null,
        val years: Int? = null,
        val months: Int? = null
    ) {
        val displayName: String get() = name?.takeIf { it.isNotEmpty() } ?: "未命名工作室"
        val isCertified: Boolean get() = (certStatus ?: 0) == 1
        val tagsText: String
            get() {
                val tags = typeTags?.filter { it.isNotEmpty() } ?: emptyList()
                if (tags.isNotEmpty()) return tags.joinToString(" / ")
                return businessType?.takeIf { it.isNotEmpty() } ?: ""
            }
        val entryText: String
            get() {
                val y = years ?: 0
                if (y >= 1) return "入驻 $y 年"
                val m = months ?: 0
                if (m >= 1) return "入驻 $m 个月"
                return "新入驻"
            }
        val subtitle: String
            get() {
                val parts = mutableListOf<String>()
                if (isCertified) parts.add("已认证机构")
                val tags = tagsText
                if (tags.isNotEmpty()) parts.add(tags)
                parts.add(entryText)
                return parts.joinToString(" · ")
            }
    }

    @Serializable
    data class StudioMineStats(
        @SerialName("active_students") val activeStudents: Int? = null,
        @SerialName("online_courses") val onlineCourses: Int? = null,
        @SerialName("course_total") val courseTotal: Int? = null,
        val teachers: Int? = null,
        @SerialName("pending_refunds") val pendingRefunds: Int? = null
    ) {
        val activeStudentCount: Int get() = activeStudents ?: 0
        val onlineCourseCount: Int get() = onlineCourses ?: 0
        val courseTotalCount: Int get() = courseTotal ?: 0
        val teacherCount: Int get() = teachers ?: 0
        val pendingRefundCount: Int get() = pendingRefunds ?: 0
    }

    @Serializable
    data class StudioMineData(
        val profile: StudioMineProfile? = null,
        val stats: StudioMineStats? = null
    )

    // MARK: - 经营概览模型

    @Serializable
    data class StudioOverviewRevenue(
        @SerialName("month_income") val monthIncome: Int? = null,
        @SerialName("withdrawable") val withdrawable: Int? = null,
        @SerialName("distribution") val distribution: Int? = null,
        @SerialName("settling") val settling: Int? = null
    ) {
        val monthIncomeValue: Int get() = monthIncome ?: 0
        val monthIncomeText: String get() = amountText(monthIncomeValue)
        val withdrawableText: String get() = amountText(withdrawable ?: 0)
        val distributionText: String get() = amountText(distribution ?: 0)
        val settlingText: String get() = amountText(settling ?: 0)
    }

    @Serializable
    data class StudioOverviewStats(
        @SerialName("active_students") val activeStudents: Int? = null,
        @SerialName("online_courses") val onlineCourses: Int? = null,
        val teachers: Int? = null
    )

    @Serializable
    data class StudioOverviewTodos(
        @SerialName("pending_refunds") val pendingRefunds: Int? = null,
        @SerialName("pending_payouts") val pendingPayouts: Int? = null,
        @SerialName("pending_settle_orders") val pendingSettleOrders: Int? = null,
        @SerialName("pending_settle_amount") val pendingSettleAmount: Int? = null
    ) {
        val pendingRefundCount: Int get() = pendingRefunds ?: 0
        val pendingPayoutCount: Int get() = pendingPayouts ?: 0
        val pendingSettleOrderCount: Int get() = pendingSettleOrders ?: 0
        val pendingSettleAmountText: String get() = amountText(pendingSettleAmount ?: 0)
    }

    @Serializable
    data class StudioOverviewDynamic(
        @SerialName("studio_name") val studioName: String? = null,
        @SerialName("today_enrolled") val todayEnrolled: Int? = null,
        @SerialName("weekly_enrolled") val weeklyEnrolled: Int? = null,
        @SerialName("weekly_income") val weeklyIncome: Int? = null,
        @SerialName("distribution_ratio") val distributionRatio: Int? = null,
        val headline: String? = null
    ) {
        val name: String get() = studioName?.takeIf { it.isNotEmpty() } ?: "我的工作室"
        val todayEnrolledCount: Int get() = todayEnrolled ?: 0
        val weeklyEnrolledCount: Int get() = weeklyEnrolled ?: 0
        val weeklyIncomeText: String get() = signedAmountText(weeklyIncome ?: 0)
        val headlineText: String get() = headline?.takeIf { it.isNotEmpty() } ?: "本周经营数据持续更新中。"
    }

    @Serializable
    data class StudioOverviewData(
        val revenue: StudioOverviewRevenue? = null,
        val stats: StudioOverviewStats? = null,
        val todos: StudioOverviewTodos? = null,
        val dynamic: StudioOverviewDynamic? = null
    )

    // MARK: - 退款审核模型

    @Serializable
    data class StudioRefundParty(
        @SerialName("user_id") val userId: String? = null,
        val nickname: String? = null,
        val avatar: String? = null,
        val phone: String? = null
    )

    @Serializable
    data class StudioRefundChild(
        @SerialName("child_id") val childId: String? = null,
        val nickname: String? = null,
        val avatar: String? = null
    )

    @Serializable
    data class StudioRefundCourse(
        @SerialName("course_id") val courseId: String? = null,
        val title: String? = null,
        val cover: String? = null
    )

    @Serializable
    data class StudioRefundBalance(
        @SerialName("total_lessons") val totalLessons: Int? = null,
        @SerialName("consumed_lessons") val consumedLessons: Int? = null,
        @SerialName("remaining_lessons") val remainingLessons: Int? = null
    )

    @Serializable
    data class StudioRefundOrder(
        @SerialName("order_id") val orderId: String? = null,
        @SerialName("order_no") val orderNo: String? = null,
        val status: Int? = null,
        val child: StudioRefundChild? = null,
        val course: StudioRefundCourse? = null,
        val user: StudioRefundParty? = null,
        val balance: StudioRefundBalance? = null
    )

    /** 工作室退款单：status 0 待审核 / 1 待家长确认 / 2 已驳回 / 3 已退款；金额单位「分」 */
    @Serializable
    data class StudioRefund(
        @SerialName("refund_id") val refundId: String = "",
        @SerialName("order_id") val orderId: String? = null,
        @SerialName("requested_lessons") val requestedLessons: Int? = null,
        @SerialName("approved_lessons") val approvedLessons: Int? = null,
        @SerialName("refundable_lessons") val refundableLessons: Int? = null,
        @SerialName("unit_price") val unitPrice: Int? = null,
        val amount: Int? = null,
        val reason: String? = null,
        val status: Int = 0,
        @SerialName("refund_method") val refundMethod: String? = null,
        @SerialName("voucher_images") val voucherImages: List<String>? = null,
        @SerialName("reject_reason") val rejectReason: String? = null,
        @SerialName("reviewed_at") val reviewedAt: String? = null,
        @SerialName("refunded_at") val refundedAt: String? = null,
        @SerialName("created_at") val createdAt: String? = null,
        val order: StudioRefundOrder? = null
    ) {
        val amountFen: Int get() = amount ?: 0
        val parentName: String
            get() {
                order?.user?.nickname?.let { if (it.isNotEmpty()) return it }
                order?.child?.nickname?.let { if (it.isNotEmpty()) return "${it}家长" }
                return "家长用户"
            }
        val parentAvatar: String? get() = order?.user?.avatar ?: order?.child?.avatar
        val courseTitle: String get() = order?.course?.title?.takeIf { it.isNotEmpty() } ?: "课程"
        val remaining: Int get() = order?.balance?.remainingLessons ?: 0
        val totalLessons: Int get() = order?.balance?.totalLessons ?: 0
        val reasonText: String get() = reason ?: ""
        val voucherImageList: List<String> get() = voucherImages ?: emptyList()
        val rejectReasonText: String get() = rejectReason ?: ""
        val refundMethodText: String
            get() {
                val m = refundMethod?.takeIf { it.isNotEmpty() } ?: return ""
                return PayMethodOption.all.firstOrNull { it.value == m }?.label ?: m
            }
        val amountText: String get() = amountText2(amountFen)
        val statusText: String
            get() = when (status) {
                0 -> "待审核"
                1 -> "待家长确认"
                2 -> "已驳回"
                3 -> "已退款"
                else -> "未知"
            }
    }

    // MARK: - 银行卡模型

    @Serializable
    data class BankAccount(
        @SerialName("account_id") val accountId: String? = null,
        @SerialName("account_type") val accountType: String? = null,
        @SerialName("account_name") val accountName: String? = null,
        @SerialName("account_no") val accountNo: String? = null,
        @SerialName("bank_name") val bankName: String? = null,
        @SerialName("is_default") val isDefault: Int? = null,
        val status: Int? = null
    ) {
        val accountTypeValue: String get() = accountType ?: "bank"
        val accountNameValue: String get() = accountName ?: ""
        val accountNoValue: String get() = accountNo ?: ""
        val bankNameValue: String get() = bankName ?: "银行卡"
        val isDefaultBool: Boolean get() = (isDefault ?: 0) == 1
        val lastFourDigits: String get() = accountNoValue.takeLast(4)
    }

    // MARK: - 学员管理模型

    /** 学员筛选：all 全部 / renew 待续费 / new 本月新增 */
    enum class StudentFilter(val value: String, val title: String, val emptyText: String) {
        ALL("all", "全部", "暂无学员"),
        RENEW("renew", "待续费", "暂无待续费学员"),
        NEW("new", "本月新增", "本月暂无新增学员")
    }

    @Serializable
    data class StudioStudentSummary(
        val all: Int? = null,
        val renew: Int? = null,
        @SerialName("new") val newCount: Int? = null
    ) {
        fun count(filter: StudentFilter): Int = when (filter) {
            StudentFilter.ALL -> all ?: 0
            StudentFilter.RENEW -> renew ?: 0
            StudentFilter.NEW -> newCount ?: 0
        }
    }

    @Serializable
    data class StudioStudentItem(
        @SerialName("child_id") val childId: String = "",
        val nickname: String? = null,
        val avatar: String? = null,
        val gender: Int? = null,
        val age: Int? = null,
        val birthday: String? = null,
        @SerialName("course_title") val courseTitle: String? = null,
        @SerialName("course_count") val courseCount: Int? = null,
        @SerialName("parent_name") val parentName: String? = null,
        @SerialName("parent_phone") val parentPhone: String? = null,
        @SerialName("remaining_lessons") val remainingLessons: Int? = null,
        @SerialName("total_lessons") val totalLessons: Int? = null,
        @SerialName("consumed_lessons") val consumedLessons: Int? = null,
        val renew: Boolean? = null,
        @SerialName("is_new") val isNew: Boolean? = null,
        @SerialName("enrolled_at") val enrolledAt: String? = null,
        val status: String? = null
    ) {
        val displayName: String get() = nickname?.takeIf { it.isNotEmpty() } ?: "未命名学员"
        val isRenew: Boolean get() = renew ?: false
        val remaining: Int get() = remainingLessons ?: 0
        val subtitle: String
            get() {
                val parts = mutableListOf<String>()
                age?.let { parts.add("$it 岁") }
                courseTitle?.let { if (it.isNotEmpty()) parts.add(it) }
                parentName?.let { if (it.isNotEmpty()) parts.add("家长：$it") }
                return parts.joinToString(" · ")
            }
        val lessonsText: String get() = "$remaining 节"
        val lessonsCaption: String get() = if (isRenew) "待续费" else "剩余课时"
        val enrolledText: String get() = enrolledAt?.take(10) ?: "—"
        val genderText: String
            get() = when (gender) {
                1 -> "男孩"
                2 -> "女孩"
                else -> "未填"
            }
    }

    @Serializable
    data class StudioStudentPage(
        val summary: StudioStudentSummary? = null,
        val total: Int? = null,
        val list: List<StudioStudentItem>? = null
    )

    @Serializable
    data class StudioStudentBalance(
        @SerialName("balance_id") val balanceId: String? = null,
        @SerialName("course_id") val courseId: String? = null,
        @SerialName("course_title") val courseTitle: String? = null,
        @SerialName("total_lessons") val totalLessons: Int? = null,
        @SerialName("consumed_lessons") val consumedLessons: Int? = null,
        @SerialName("remaining_lessons") val remainingLessons: Int? = null,
        @SerialName("valid_from") val validFrom: String? = null,
        @SerialName("valid_to") val validTo: String? = null,
        @SerialName("order_created_at") val orderCreatedAt: String? = null
    ) {
        val titleText: String get() = courseTitle?.takeIf { it.isNotEmpty() } ?: "课程"
        val remainingText: String get() = "${remainingLessons ?: 0} 节"
        val detailText: String get() = "共 ${totalLessons ?: 0} 节 · 已消耗 ${consumedLessons ?: 0} 节"
        val validityText: String
            get() {
                val from = validFrom?.take(10) ?: return ""
                val to = validTo?.take(10) ?: return "有效期：$from 起"
                return "有效期：$from ~ $to"
            }
    }

    @Serializable
    data class StudioStudentLog(
        @SerialName("log_id") val logId: String? = null,
        @SerialName("course_id") val courseId: String? = null,
        @SerialName("course_title") val courseTitle: String? = null,
        @SerialName("lesson_date") val lessonDate: String? = null,
        @SerialName("start_time") val startTime: String? = null,
        @SerialName("end_time") val endTime: String? = null,
        @SerialName("is_makeup") val isMakeup: Boolean? = null,
        val source: Int? = null,
        val delta: Int? = null,
        @SerialName("balance_after") val balanceAfter: Int? = null,
        val note: String? = null,
        @SerialName("created_at") val createdAt: String? = null
    ) {
        val sourceText: String
            get() = when (source ?: 0) {
                0 -> "课时到账"
                1 -> "出勤打卡"
                2 -> "排课消课"
                3 -> "手动消课"
                4 -> "退款扣减"
                else -> "其他"
            }
        val deltaText: String
            get() {
                val v = delta ?: 0
                return "${if (v > 0) "+" else ""}$v 节"
            }
        val isIncrease: Boolean get() = (delta ?: 0) > 0
        val dateText: String
            get() {
                lessonDate?.take(10)?.let { if (it.length == 10) return it }
                createdAt?.take(10)?.let { if (it.length == 10) return it }
                return "—"
            }
        val timeText: String
            get() {
                val s = startTime ?: return ""
                val e = endTime ?: return ""
                if (s.isEmpty()) return ""
                return "$s~$e"
            }
        val titleText: String get() = courseTitle?.takeIf { it.isNotEmpty() } ?: "课程"
    }

    @Serializable
    data class StudioStudentDetail(
        val student: StudioStudentItem? = null,
        val balances: List<StudioStudentBalance>? = null,
        val logs: List<StudioStudentLog>? = null
    )

    // MARK: - 老师管理模型

    @Serializable
    data class StudioTeacherSummary(
        @SerialName("total_teachers") val totalTeachers: Int? = null,
        @SerialName("total_students") val totalStudents: Int? = null,
        @SerialName("month_lessons") val monthLessons: Int? = null,
        @SerialName("pending_applications") val pendingApplications: Int? = null
    ) {
        val pendingCount: Int get() = pendingApplications ?: 0
    }

    @Serializable
    data class StudioTeacherItem(
        @SerialName("binding_id") val bindingId: String? = null,
        @SerialName("teacher_id") val teacherId: String = "",
        @SerialName("user_id") val userId: String? = null,
        @SerialName("real_name") val realName: String? = null,
        val nickname: String? = null,
        val avatar: String? = null,
        val phone: String? = null,
        val subjects: List<String>? = null,
        val years: Int? = null,
        val intro: String? = null,
        @SerialName("cert_no") val certNo: String? = null,
        @SerialName("cert_status") val certStatus: Int? = null,
        val rating: Double? = null,
        @SerialName("bound_at") val boundAt: String? = null,
        @SerialName("course_count") val courseCount: Int? = null,
        @SerialName("student_count") val studentCount: Int? = null,
        @SerialName("month_lessons") val monthLessons: Int? = null
    ) {
        val displayName: String get() = realName?.takeIf { it.isNotEmpty() } ?: "未命名老师"
        val subtitle: String
            get() {
                val parts = mutableListOf<String>()
                subjects?.takeIf { it.isNotEmpty() }?.let { parts.add(it.joinToString(" / ")) }
                years?.let { parts.add("教龄 $it 年") }
                return if (parts.isEmpty()) "暂未填写擅长方向" else parts.joinToString(" · ")
            }
        val studentsText: String get() = "${studentCount ?: 0} 名学生"
        val lessonsText: String get() = "月消课 ${monthLessons ?: 0} 节"
        val isCertified: Boolean get() = (certStatus ?: 0) == 1
        val ratingText: String get() = String.format("%.1f", rating ?: 5.0)
        val joinedText: String get() = boundAt?.take(10) ?: "—"
        val yearsText: String get() = years?.let { "$it 年" } ?: "未填写"
        val subjectsText: String get() = subjects?.takeIf { it.isNotEmpty() }?.joinToString(" / ") ?: "暂未填写"
    }

    @Serializable
    data class StudioTeacherPage(
        val summary: StudioTeacherSummary? = null,
        val total: Int? = null,
        val list: List<StudioTeacherItem>? = null
    )

    @Serializable
    data class StudioTeacherCourse(
        @SerialName("course_id") val courseId: String = "",
        val title: String? = null,
        val cover: String? = null,
        val status: Int? = null,
        @SerialName("total_lessons") val totalLessons: Int? = null,
        val price: Int? = null,
        @SerialName("student_count") val studentCount: Int? = null,
        @SerialName("month_lessons") val monthLessons: Int? = null
    ) {
        val titleText: String get() = title?.takeIf { it.isNotEmpty() } ?: "课程"
        val isOnline: Boolean get() = (status ?: 0) == 1
        val statusText: String get() = if (isOnline) "在售" else "已下架"
        val detailText: String get() = "共 ${totalLessons ?: 0} 节 · 本月消课 ${monthLessons ?: 0} 节"
    }

    @Serializable
    data class StudioTeacherLog(
        @SerialName("log_id") val logId: String? = null,
        @SerialName("created_at") val createdAt: String? = null,
        @SerialName("child_name") val childName: String? = null,
        @SerialName("course_title") val courseTitle: String? = null,
        val delta: Int? = null,
        @SerialName("balance_after") val balanceAfter: Int? = null,
        val note: String? = null
    ) {
        val dateText: String get() = createdAt?.take(10) ?: "—"
        val titleText: String
            get() {
                val name = childName ?: "学员"
                val course = courseTitle?.takeIf { it.isNotEmpty() } ?: "课程"
                return "$name · $course"
            }
        val deltaText: String
            get() {
                val v = delta ?: 0
                return if (v > 0) "+$v" else "$v"
            }
        val isIncrease: Boolean get() = (delta ?: 0) > 0
        val detailText: String
            get() {
                var text = "剩余 ${balanceAfter ?: 0} 节"
                note?.let { if (it.isNotEmpty()) text += " · $it" }
                return text
            }
    }

    @Serializable
    data class StudioTeacherDetail(
        val teacher: StudioTeacherItem? = null,
        val courses: List<StudioTeacherCourse>? = null,
        val logs: List<StudioTeacherLog>? = null
    )

    /** 合作申请筛选 */
    enum class ApplicationFilter(val title: String, val apiValue: Int?, val emptyText: String) {
        PENDING("待处理", 0, "暂无待处理的合作申请"),
        APPROVED("已通过", 1, "暂无已通过的合作申请"),
        REJECTED("已驳回", 2, "暂无已驳回的合作申请"),
        ALL("全部", null, "暂无老师合作申请")
    }

    @Serializable
    data class StudioTeacherApplicationSummary(
        val pending: Int? = null,
        val approved: Int? = null,
        val rejected: Int? = null,
        val total: Int? = null
    ) {
        fun count(filter: ApplicationFilter): Int = when (filter) {
            ApplicationFilter.PENDING -> pending ?: 0
            ApplicationFilter.APPROVED -> approved ?: 0
            ApplicationFilter.REJECTED -> rejected ?: 0
            ApplicationFilter.ALL -> total ?: 0
        }
    }

    @Serializable
    data class StudioTeacherApplication(
        val id: String = "",
        @SerialName("user_id") val userId: String? = null,
        @SerialName("real_name") val realName: String? = null,
        val nickname: String? = null,
        val avatar: String? = null,
        val phone: String? = null,
        val subjects: List<String>? = null,
        val years: Int? = null,
        val intro: String? = null,
        @SerialName("cert_no") val certNo: String? = null,
        val status: Int? = null,
        @SerialName("submitted_at") val submittedAt: String? = null,
        @SerialName("reviewed_at") val reviewedAt: String? = null,
        @SerialName("review_reason") val reviewReason: String? = null
    ) {
        val displayName: String get() = realName?.takeIf { it.isNotEmpty() } ?: "未命名老师"
        val isPending: Boolean get() = (status ?: 0) == 0
        val statusText: String
            get() = when (status) {
                0 -> "待处理"
                1 -> "已通过"
                2 -> "已驳回"
                else -> "未知"
            }
        val subtitle: String
            get() {
                val parts = mutableListOf<String>()
                subjects?.takeIf { it.isNotEmpty() }?.let { parts.add(it.joinToString(" / ")) }
                years?.let { parts.add("教龄 $it 年") }
                return if (parts.isEmpty()) "—" else parts.joinToString(" · ")
            }
        val submittedText: String get() = submittedAt?.take(10) ?: "—"
    }

    @Serializable
    data class StudioTeacherApplicationPage(
        val summary: StudioTeacherApplicationSummary? = null,
        val total: Int? = null,
        val list: List<StudioTeacherApplication>? = null
    )

    @Serializable
    data class StudioTeacherInviteTeacher(
        @SerialName("teacher_id") val teacherId: String? = null,
        @SerialName("user_id") val userId: String? = null,
        @SerialName("real_name") val realName: String? = null
    )

    @Serializable
    data class StudioTeacherInviteResult(
        @SerialName("binding_id") val bindingId: String? = null,
        val status: Int? = null,
        val teacher: StudioTeacherInviteTeacher? = null
    ) {
        val teacherName: String get() = teacher?.realName ?: "老师"
    }

    // MARK: - 订单管理模型

    /** 订单状态：0 待收款 / 1 待确认收款 / 2 已收款 / 3 退款审核中 / 4 待家长确认退款 / 5 已退款 / 6 已取消 */
    enum class OrderStatus(val value: Int, val title: String, val emptyText: String) {
        PENDING(0, "待收款", "暂无待收款订单"),
        PAYMENT_REVIEW(1, "待确认收款", "暂无待确认收款订单"),
        COLLECTED(2, "已收款", "暂无已收款订单"),
        REFUND_REVIEW(3, "退款审核中", "暂无退款审核中订单"),
        REFUND_CONFIRM(4, "待确认退款", "暂无待确认退款订单"),
        REFUNDED(5, "已退款", "暂无已退款订单"),
        CANCELLED(6, "已取消", "暂无已取消订单")
    }

    /** 订单筛选（含"全部"选项） */
    enum class OrderFilter(val title: String, val apiValue: Int?, val emptyText: String) {
        ALL("全部", null, "暂无订单"),
        PENDING("待收款", 0, "暂无待收款订单"),
        PAYMENT_REVIEW("待确认", 1, "暂无待确认收款订单"),
        COLLECTED("已收款", 2, "暂无已收款订单"),
        CANCELLED("已取消", 6, "暂无已取消订单"),
        REFUNDED("已退款", 5, "暂无已退款订单")
    }

    @Serializable
    data class StudioOrderChild(
        @SerialName("child_id") val childId: String? = null,
        val nickname: String? = null,
        val birthday: String? = null
    ) {
        val displayName: String get() = nickname ?: "学员"
    }

    @Serializable
    data class StudioOrderUser(
        @SerialName("user_id") val userId: String? = null,
        val nickname: String? = null,
        val phone: String? = null,
        val avatar: String? = null
    ) {
        val displayName: String get() = nickname ?: "家长"
    }

    @Serializable
    data class StudioOrderCourse(
        @SerialName("course_id") val courseId: String? = null,
        val title: String? = null,
        val cover: String? = null,
        @SerialName("validity_days") val validityDays: Int? = null
    ) {
        val titleText: String get() = title ?: "课程"
    }

    @Serializable
    data class StudioOrderClass(
        @SerialName("class_id") val classId: String? = null,
        val name: String? = null
    ) {
        val displayName: String get() = name ?: ""
    }

    @Serializable
    data class StudioOrderPackage(
        @SerialName("package_id") val packageId: String? = null,
        val name: String? = null,
        val lessons: Int? = null
    ) {
        val displayName: String get() = name ?: "套餐"
    }

    @Serializable
    data class StudioOrderItem(
        @SerialName("item_id") val itemId: String? = null,
        @SerialName("course_title") val courseTitle: String? = null,
        @SerialName("package_name") val packageName: String? = null,
        val lessons: Int? = null,
        @SerialName("unit_price") val unitPrice: Int? = null,
        @SerialName("total_price") val totalPrice: Int? = null
    )

    @Serializable
    data class StudioPayment(
        @SerialName("payment_id") val paymentId: String? = null,
        @SerialName("payment_no") val paymentNo: String? = null,
        val channel: String? = null,
        @SerialName("pay_method") val payMethod: String? = null,
        @SerialName("pay_method_text") val payMethodText: String? = null,
        val amount: Int? = null,
        val status: Int? = null,
        @SerialName("status_text") val statusText: String? = null,
        @SerialName("voucher_images") val voucherImages: List<String>? = null,
        @SerialName("payer_note") val payerNote: String? = null,
        @SerialName("upload_by") val uploadBy: Int? = null,
        @SerialName("reject_reason") val rejectReason: String? = null,
        @SerialName("paid_at") val paidAt: String? = null,
        @SerialName("created_at") val createdAt: String? = null
    ) {
        val isPending: Boolean get() = (status ?: 0) == 0
        val isConfirmed: Boolean get() = (status ?: 0) == 1
        val isRejected: Boolean get() = (status ?: 0) == 2
        val amountText: String get() = amountText(amount ?: 0)
        val methodText: String get() = payMethodText ?: payMethod ?: "—"
        val statusLabel: String get() = statusText ?: "未知"
        val hasVoucher: Boolean get() = !voucherImages.isNullOrEmpty()
        val voucherURLs: List<String> get() = voucherImages ?: emptyList()
        val noteText: String get() = payerNote ?: ""
        val rejectText: String get() = rejectReason ?: ""
        val isUploadedByParent: Boolean get() = (uploadBy ?: 0) == 1
    }

    @Serializable
    data class StudioOrderRefund(
        @SerialName("refund_id") val refundId: String? = null,
        val amount: Int? = null,
        @SerialName("requested_lessons") val requestedLessons: Int? = null,
        @SerialName("refundable_lessons") val refundableLessons: Int? = null,
        val status: Int? = null,
        @SerialName("status_text") val statusText: String? = null,
        val reason: String? = null,
        @SerialName("created_at") val createdAt: String? = null
    ) {
        val amountText: String get() = amountText(amount ?: 0)
    }

    @Serializable
    data class StudioOrderBalance(
        @SerialName("balance_id") val balanceId: String? = null,
        @SerialName("total_lessons") val totalLessons: Int? = null,
        @SerialName("consumed_lessons") val consumedLessons: Int? = null,
        @SerialName("refunded_lessons") val refundedLessons: Int? = null,
        @SerialName("remaining_lessons") val remainingLessons: Int? = null,
        @SerialName("valid_from") val validFrom: String? = null,
        @SerialName("valid_to") val validTo: String? = null,
        val status: Int? = null
    ) {
        val remaining: Int get() = remainingLessons ?: 0
        val total: Int get() = totalLessons ?: 0
        val consumed: Int get() = consumedLessons ?: 0
        val refunded: Int get() = refundedLessons ?: 0
    }

    @Serializable
    data class StudioOrderStudio(
        @SerialName("studio_id") val studioId: String? = null,
        val name: String? = null
    )

    /** 工作室订单（列表 + 详情共用） */
    @Serializable
    data class StudioOrder(
        @SerialName("order_id") val orderId: String = "",
        @SerialName("order_no") val orderNo: String? = null,
        val status: Int? = null,
        @SerialName("status_text") val statusText: String? = null,
        val source: Int? = null,
        @SerialName("source_text") val sourceText: String? = null,
        @SerialName("class_id") val classId: String? = null,
        @SerialName("total_lessons") val totalLessons: Int? = null,
        @SerialName("consumed_lessons") val consumedLessons: Int? = null,
        @SerialName("refunded_lessons") val refundedLessons: Int? = null,
        @SerialName("remaining_lessons") val remainingLessons: Int? = null,
        @SerialName("total_amount") val totalAmount: Int? = null,
        @SerialName("paid_amount") val paidAmount: Int? = null,
        @SerialName("refund_amount") val refundAmount: Int? = null,
        @SerialName("refund_status") val refundStatus: Int? = null,
        @SerialName("refund_status_text") val refundStatusText: String? = null,
        @SerialName("pay_channel") val payChannel: String? = null,
        @SerialName("pay_method") val payMethod: String? = null,
        @SerialName("pay_method_text") val payMethodText: String? = null,
        @SerialName("confirmed_by") val confirmedBy: String? = null,
        @SerialName("paid_at") val paidAt: String? = null,
        @SerialName("created_at") val createdAt: String? = null,
        val child: StudioOrderChild? = null,
        val user: StudioOrderUser? = null,
        @SerialName("class") val classRef: StudioOrderClass? = null,
        val studio: StudioOrderStudio? = null,
        val course: StudioOrderCourse? = null,
        val pkg: StudioOrderPackage? = null,
        val items: List<StudioOrderItem>? = null,
        val payments: List<StudioPayment>? = null,
        val refunds: List<StudioOrderRefund>? = null,
        val balance: StudioOrderBalance? = null
    ) {
        val orderStatus: OrderStatus
            get() = OrderStatus.entries.firstOrNull { it.value == (status ?: 0) } ?: OrderStatus.PENDING
        val isPending: Boolean get() = orderStatus == OrderStatus.PENDING
        val isPaymentReview: Boolean get() = orderStatus == OrderStatus.PAYMENT_REVIEW
        val isCollected: Boolean get() = orderStatus == OrderStatus.COLLECTED
        val isCancelled: Boolean get() = orderStatus == OrderStatus.CANCELLED
        val isRefunded: Boolean get() = orderStatus == OrderStatus.REFUNDED
        val parentName: String
            get() {
                user?.nickname?.let { if (it.isNotEmpty()) return it }
                child?.nickname?.let { if (it.isNotEmpty()) return "${it}家长" }
                return "家长用户"
            }
        val courseTitle: String get() = course?.titleText ?: "课程"
        val totalAmountText: String get() = amountText(totalAmount ?: 0)
        val paidAmountText: String get() = amountText(paidAmount ?: 0)
        val refundAmountText: String get() = amountText(refundAmount ?: 0)
        val totalLessonsText: String get() = "${totalLessons ?: 0} 节"
        val remainingLessonsText: String get() = "${remainingLessons ?: 0} 节"
        val sourceLabel: String get() = sourceText ?: "家长报名"
        val statusLabel: String get() = statusText ?: "未知"
        val createdDate: String get() = createdAt?.take(10)?.takeIf { it.length == 10 } ?: "—"
        val pendingPayment: StudioPayment? get() = payments?.firstOrNull { it.isPending }
        val hasPendingPayment: Boolean get() = pendingPayment != null
    }

    // MARK: - 课程管理模型

    @Serializable
    data class StudioCourseTeacher(
        @SerialName("teacher_id") val teacherId: String? = null,
        @SerialName("real_name") val realName: String? = null
    )

    @Serializable
    data class StudioCourseItem(
        @SerialName("course_id") val courseId: String = "",
        val title: String? = null,
        val cover: String? = null,
        @SerialName("age_min") val ageMin: Int? = null,
        @SerialName("age_max") val ageMax: Int? = null,
        @SerialName("total_lessons") val totalLessons: Int? = null,
        val price: Int? = null,
        val sales: Int? = null,
        val status: Int? = null,
        val teacher: StudioCourseTeacher? = null
    ) {
        val teacherName: String get() = teacher?.realName ?: ""
        val hasTeacher: Boolean get() = !teacher?.realName.isNullOrEmpty()
        val lessonsText: String get() = "${totalLessons ?: 0} 节"
        val salesText: String get() = "已售 ${sales ?: 0}"
        val ageText: String
            get() {
                val mn = ageMin
                val mx = ageMax
                if (mn != null && mx != null && mx > mn) return "$mn-$mx 岁"
                if (mn != null) return "$mn 岁+"
                if (mx != null) return "$mx 岁以内"
                return "适龄"
            }
        val priceText: String
            get() {
                val fen = price ?: return "¥0"
                return amountText(fen)
            }
    }

    // MARK: - 财务对账模型

    @Serializable
    data class StudioFinancePeriod(
        @SerialName("start_date") val startDate: String? = null,
        @SerialName("end_date") val endDate: String? = null
    )

    @Serializable
    data class StudioFinanceSummary(
        @SerialName("gmv_total") val gmvTotal: Int? = null,
        @SerialName("gmv_period") val gmvPeriod: Int? = null,
        @SerialName("refund_total") val refundTotal: Int? = null,
        @SerialName("refund_period") val refundPeriod: Int? = null,
        @SerialName("distribution_total") val distributionTotal: Int? = null,
        @SerialName("net_total") val netTotal: Int? = null,
        @SerialName("net_period") val netPeriod: Int? = null
    ) {
        val gmvTotalValue: Int get() = gmvTotal ?: 0
        val gmvPeriodValue: Int get() = gmvPeriod ?: 0
        val refundTotalValue: Int get() = refundTotal ?: 0
        val refundPeriodValue: Int get() = refundPeriod ?: 0
        val distributionTotalValue: Int get() = distributionTotal ?: 0
        val netTotalValue: Int get() = netTotal ?: 0
        val netPeriodValue: Int get() = netPeriod ?: 0
    }

    @Serializable
    data class StudioFinanceOrder(
        @SerialName("order_id") val orderId: String? = null,
        @SerialName("order_no") val orderNo: String? = null,
        @SerialName("total_amount") val totalAmount: Int? = null,
        val status: Int? = null,
        @SerialName("paid_at") val paidAt: String? = null
    )

    @Serializable
    data class StudioFinanceData(
        val period: StudioFinancePeriod? = null,
        val summary: StudioFinanceSummary? = null,
        val orders: List<StudioFinanceOrder>? = null
    )

    // MARK: - API：我的 + 概览

    /** 工作室「我的」：机构资料 + 经营统计 */
    suspend fun fetchMine(): StudioMineData {
        return ApiService.get("/studio/mine").decode<StudioMineData>() ?: StudioMineData()
    }

    /** 工作室「经营概览」：营收卡 + 三项统计 + 待办 + 机构动态 */
    suspend fun fetchOverview(): StudioOverviewData {
        return ApiService.get("/studio/overview").decode<StudioOverviewData>() ?: StudioOverviewData()
    }

    // MARK: - API：退款审核

    /** 退款列表；status: 0 待审核 / 1 待家长确认 / 2 已驳回 / 3 已退款；null 为全部 */
    suspend fun fetchRefunds(status: Int? = null): List<StudioRefund> {
        val params = mutableMapOf<String, Any>()
        status?.let { params["status"] = it }
        return ApiService.get("/studio/refunds", params).decodeList("list")
    }

    /** 退款审核：action = approve / reject / confirm */
    suspend fun reviewRefund(
        refundId: String,
        action: String,
        reason: String? = null,
        refundMethod: String? = null,
        voucherImages: List<String>? = null
    ): StudioRefund? {
        val body = mutableMapOf<String, Any>("action" to action)
        reason?.let { if (it.isNotEmpty()) body["reason"] = it }
        refundMethod?.let { if (it.isNotEmpty()) body["refund_method"] = it }
        voucherImages?.let { if (it.isNotEmpty()) body["voucher_images"] = it }
        return ApiService.put("/studio/refunds/$refundId", body).decode<StudioRefund>()
    }

    // MARK: - API：课程管理

    /** 本工作室课程列表；status: 0 审核中 / 1 在售 / 2 已下架；null 为全部 */
    suspend fun fetchCourses(status: Int? = null): List<StudioCourseItem> {
        val params = mutableMapOf<String, Any>()
        status?.let { params["status"] = it }
        return ApiService.get("/studio/courses", params).decodeList("list")
    }

    /** 上架 / 下架课程。status: 1 在售 / 2 已下架 */
    suspend fun setCourseStatus(courseId: String, status: Int) {
        ApiService.patch("/studio/courses/$courseId/status", mapOf("status" to status))
    }

    // MARK: - API：学员管理

    /** 学员列表；filter: all / renew / new；keyword 昵称或家长模糊 */
    suspend fun fetchStudents(
        filter: StudentFilter = StudentFilter.ALL,
        keyword: String? = null
    ): StudioStudentPage {
        val params = mutableMapOf<String, Any>("filter" to filter.value)
        keyword?.trim()?.let { if (it.isNotEmpty()) params["q"] = it }
        return ApiService.get("/studio/students", params).decode<StudioStudentPage>()
            ?: StudioStudentPage()
    }

    /** 学员详情：学员信息 + 各课程课时余额 + 课时流水 */
    suspend fun fetchStudentDetail(childId: String): StudioStudentDetail {
        return ApiService.get("/studio/students/$childId").decode<StudioStudentDetail>()
            ?: StudioStudentDetail()
    }

    // MARK: - API：老师管理

    /** 在职老师列表；keyword 匹配姓名或擅长方向 */
    suspend fun fetchTeachers(keyword: String? = null): StudioTeacherPage {
        val params = mutableMapOf<String, Any>()
        keyword?.trim()?.let { if (it.isNotEmpty()) params["q"] = it }
        return ApiService.get("/studio/teachers", params).decode<StudioTeacherPage>()
            ?: StudioTeacherPage()
    }

    /** 老师详情：档案 + 本工作室带课 + 最近消课流水 */
    suspend fun fetchTeacherDetail(teacherId: String): StudioTeacherDetail {
        return ApiService.get("/studio/teachers/$teacherId").decode<StudioTeacherDetail>()
            ?: StudioTeacherDetail()
    }

    /** 老师合作申请列表；status null 为全部 */
    suspend fun fetchTeacherApplications(status: Int? = null): StudioTeacherApplicationPage {
        val params = mutableMapOf<String, Any>()
        status?.let { params["status"] = it }
        return ApiService.get("/studio/teachers/applications", params)
            .decode<StudioTeacherApplicationPage>() ?: StudioTeacherApplicationPage()
    }

    /** 审批老师合作申请：action = approve / reject */
    suspend fun reviewTeacherApplication(id: String, action: String, reason: String? = null) {
        val body = mutableMapOf<String, Any>("action" to action)
        reason?.let { if (it.isNotEmpty()) body["reason"] = it }
        ApiService.put("/studio/teachers/applications/$id", body)
    }

    /** 邀请老师（手机号） */
    suspend fun inviteTeacher(phone: String): StudioTeacherInviteResult? {
        return ApiService.post("/studio/teachers/invite", mapOf("phone" to phone))
            .decode<StudioTeacherInviteResult>()
    }

    /** 解除与老师的合作 */
    suspend fun releaseTeacher(teacherId: String) {
        ApiService.delete("/studio/teachers/$teacherId")
    }

    // MARK: - API：银行卡

    /** 获取工作室绑定的银行卡列表 */
    suspend fun fetchBankAccounts(): List<BankAccount> {
        return ApiService.get("/studio/accounts").decodeList("list")
    }

    /** 绑定银行卡 */
    suspend fun addBankAccount(
        accountType: String,
        accountName: String,
        accountNo: String,
        bankName: String
    ) {
        ApiService.post("/studio/accounts", mapOf(
            "account_type" to accountType,
            "account_name" to accountName,
            "account_no" to accountNo,
            "bank_name" to bankName
        ))
    }

    // MARK: - API：收益中心（财务对账 + 佣金审核）

    /** 财务对账数据；startDate/endDate 格式 yyyy-MM-dd */
    suspend fun fetchFinance(
        startDate: String? = null,
        endDate: String? = null
    ): StudioFinanceData {
        val params = mutableMapOf<String, Any>()
        startDate?.let { params["start_date"] = it }
        endDate?.let { params["end_date"] = it }
        return ApiService.get("/studio/finance", params).decode<StudioFinanceData>()
            ?: StudioFinanceData()
    }

    /** 工作室佣金领取单列表；status: 0 待审核 / 1 待确认 / 2 已驳回 / 3 已完成 */
    suspend fun fetchCommissionWithdrawals(
        status: Int? = null,
        page: Int = 1,
        pageSize: Int = 20
    ): Pair<Int, List<CommissionService.CommissionWithdrawal>> {
        val params = mutableMapOf<String, Any>("page" to page, "page_size" to pageSize)
        status?.let { params["status"] = it }
        val json = ApiService.get("/studio/commissions", params)
        val list = json.decodeList<CommissionService.CommissionWithdrawal>("list")
        return json.int("total") to list
    }

    /** 工作室审核领取单：action = approve(需 method) / reject(需 rejectReason) */
    suspend fun reviewCommissionWithdrawal(
        id: String,
        action: String,
        method: String? = null,
        voucherImages: List<String>? = null,
        rejectReason: String? = null
    ): CommissionService.CommissionWithdrawal? {
        val body = mutableMapOf<String, Any>("action" to action)
        method?.let { body["method"] = it }
        voucherImages?.let { body["voucher_images"] = it }
        rejectReason?.let { body["reject_reason"] = it }
        return ApiService.put("/studio/commissions/$id", body)
            .decode<CommissionService.CommissionWithdrawal>()
    }

    // MARK: - API：订单管理

    /** 订单列表；status: 0/1/2/3/4/5/6；nil 为全部；keyword 模糊搜索 */
    suspend fun fetchOrders(
        status: Int? = null,
        keyword: String? = null,
        page: Int = 1,
        pageSize: Int = 20
    ): Pair<Int, List<StudioOrder>> {
        val params = mutableMapOf<String, Any>("page" to page, "page_size" to pageSize)
        status?.let { params["status"] = it }
        keyword?.trim()?.let { if (it.isNotEmpty()) params["q"] = it }
        val json = ApiService.get("/studio/orders", params)
        val list = json.decodeList<StudioOrder>("list")
        return json.int("total") to list
    }

    /** 订单详情 */
    suspend fun fetchOrderDetail(orderId: String): StudioOrder? {
        return ApiService.get("/studio/orders/$orderId").decode<StudioOrder>()
    }

    /** 确认收款 */
    suspend fun confirmPayment(
        orderId: String,
        payMethod: String? = null,
        voucherImages: List<String>? = null,
        note: String? = null
    ): StudioOrder? {
        val body = mutableMapOf<String, Any>()
        payMethod?.let { body["pay_method"] = it }
        voucherImages?.let { if (it.isNotEmpty()) body["voucher_images"] = it }
        note?.let { if (it.isNotEmpty()) body["note"] = it }
        return ApiService.post("/studio/orders/$orderId/payments/confirm", body)
            .decode<StudioOrder>()
    }

    /** 驳回家长付款凭证 */
    suspend fun rejectPayment(orderId: String, reason: String): StudioOrder? {
        return ApiService.post("/studio/orders/$orderId/payments/reject", mapOf("reason" to reason))
            .decode<StudioOrder>()
    }

    /** 取消待收款订单 */
    suspend fun cancelOrder(orderId: String): StudioOrder? {
        return ApiService.post("/studio/orders/$orderId/cancel").decode<StudioOrder>()
    }
}