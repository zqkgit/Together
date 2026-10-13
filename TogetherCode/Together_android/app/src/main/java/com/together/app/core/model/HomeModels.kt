package com.together.app.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// MARK: - 金额格式化（后端价格单位：分）

fun Int.fenToYuanText(): String {
    val v = this / 100.0
    return if (v == kotlin.math.round(v)) {
        "¥${v.toInt()}"
    } else {
        "¥${String.format("%.2f", v)}"
    }
}

fun Int.fenToYuan(): Double = this / 100.0

fun Double.yuanText(): String {
    return if (this == this.toLong().toDouble()) {
        "¥${this.toLong()}"
    } else {
        "¥${String.format("%.2f", this)}"
    }
}

// MARK: - 孩子

@Serializable
data class ChildItem(
    @SerialName("child_id") val childId: String = "",
    @SerialName("nickname") val nickname: String = "",
    @SerialName("avatar") val avatar: String? = null,
    @SerialName("birthday") val birthday: String? = null,
    @SerialName("gender") val gender: Int? = null,
    @SerialName("interests") val interests: List<String>? = null,
    @SerialName("total_remaining_lessons") val totalRemainingLessons: Int? = null,
    @SerialName("balances") val balances: List<ChildBalance>? = null
) {
    val mainBalance: ChildBalance?
        get() = balances?.firstOrNull { it.status == 1 } ?: balances?.firstOrNull()

    val ageText: String?
        get() {
            val b = birthday ?: return null
            if (b.length < 4) return null
            val year = b.take(4).toIntOrNull() ?: return null
            val age = java.time.Year.now().value - year
            return if (age >= 0) "${age}岁" else null
        }
}

@Serializable
data class ChildBalance(
    @SerialName("balance_id") val balanceId: String = "",
    @SerialName("course_id") val courseId: String? = null,
    @SerialName("course_title") val courseTitle: String? = null,
    @SerialName("course_cover") val courseCover: String? = null,
    @SerialName("studio_id") val studioId: String? = null,
    @SerialName("studio_name") val studioName: String? = null,
    @SerialName("total_lessons") val totalLessons: Int = 0,
    @SerialName("consumed_lessons") val consumedLessons: Int = 0,
    @SerialName("remaining_lessons") val remainingLessons: Int = 0,
    @SerialName("refunded_lessons") val refundedLessons: Int? = null,
    @SerialName("valid_from") val validFrom: String? = null,
    @SerialName("valid_to") val validTo: String? = null,
    @SerialName("status") val status: Int? = null,
    @SerialName("status_text") val statusText: String? = null
) {
    val progressPercent: Int
        get() = if (totalLessons > 0) minOf(100, (consumedLessons * 100 / totalLessons)) else 0

    val courseText: String get() = courseTitle ?: "未报名课程"
}

// MARK: - 公告

@Serializable
data class AnnouncementItem(
    @SerialName("announcement_id") val announcementId: String = "",
    @SerialName("title") val title: String = "",
    @SerialName("content") val content: String? = null,
    @SerialName("type") val type: Int = 0,
    @SerialName("image") val image: List<String> = emptyList(),
    @SerialName("publish_at") val publishAt: String? = null
)

// MARK: - 课程（列表卡片）

@Serializable
data class CourseItem(
    @SerialName("course_id") val courseId: String = "",
    @SerialName("title") val title: String = "",
    @SerialName("cover") val cover: String? = null,
    @SerialName("price") val price: Int = 0,
    @SerialName("original_price") val originalPrice: Int? = null,
    @SerialName("rating") val rating: Double? = null,
    @SerialName("sales") val sales: Int? = null,
    @SerialName("age_min") val ageMin: Int? = null,
    @SerialName("age_max") val ageMax: Int? = null,
    @SerialName("total_lessons") val totalLessons: Int? = null,
    @SerialName("studio") val studio: CourseStudio? = null,
    @SerialName("teacher") val teacher: CourseTeacher? = null,
    @SerialName("tags") val tags: List<String>? = null
) {
    val priceText: String get() = price.fenToYuanText()
    val originalPriceText: String?
        get() {
            val op = originalPrice ?: return null
            return if (op > price) op.fenToYuanText() else null
        }
    val studioName: String get() = studio?.name ?: ""
    val teacherName: String get() = teacher?.realName ?: ""
    val ratingText: String
        get() {
            val r = rating ?: return "新课程"
            return if (r > 0) String.format("%.1f", r) else "新课程"
        }

    val ageRangeText: String?
        get() {
            val min = ageMin
            val max = ageMax
            if (min != null && max != null && max > min) return "${min}-${max}岁"
            if (min != null) return "${min}岁+"
            if (max != null) return "${max}岁以内"
            return null
        }

    val pricePerLessonsText: String
        get() {
            val l = totalLessons ?: 0
            return if (l > 0) "${price.fenToYuanText()}/$l 节" else price.fenToYuanText()
        }
}

@Serializable
data class CourseStudio(
    @SerialName("studio_id") val studioId: String = "",
    @SerialName("name") val name: String? = null,
    @SerialName("address") val address: String? = null,
    @SerialName("phone") val phone: String? = null
)

@Serializable
data class CourseTeacher(
    @SerialName("teacher_id") val teacherId: String = "",
    @SerialName("real_name") val realName: String? = null,
    @SerialName("rating") val rating: Double? = null
)

// MARK: - 工作室

@Serializable
data class StudioItem(
    @SerialName("studio_id") val studioId: String = "",
    @SerialName("name") val name: String = "",
    @SerialName("cover") val cover: String? = null,
    @SerialName("type_tags") val typeTags: List<String>? = null,
    @SerialName("intro") val intro: String? = null,
    @SerialName("address") val address: String? = null,
    @SerialName("course_count") val courseCount: Int = 0,
    @SerialName("teacher_count") val teacherCount: Int = 0,
    @SerialName("rating") val rating: Double? = null,
    @SerialName("distance") val distance: Double? = null
) {
    val ratingText: String
        get() {
            val r = rating ?: return "—"
            return if (r > 0) String.format("%.1f", r) else "—"
        }
    val tagText: String
        get() = (typeTags ?: emptyList()).take(2).joinToString(" · ")
    val rowMetaText: String
        get() {
            val parts = mutableListOf<String>()
            val tags = tagText
            if (tags.isNotEmpty()) parts.add(tags)
            val d = distance
            if (d != null && d > 0) {
                parts.add(if (d < 1) "距离${(d * 1000).toInt()}m" else "距离${String.format("%.1f", d)}km")
            } else if (!address.isNullOrBlank()) {
                parts.add(address)
            } else {
                parts.add("$courseCount 门课")
            }
            return parts.joinToString(" · ")
        }
}

// MARK: - 老师

@Serializable
data class TeacherItem(
    @SerialName("teacher_id") val teacherId: String = "",
    @SerialName("user_id") val userId: String = "",
    @SerialName("nickname") val nickname: String = "",
    @SerialName("avatar") val avatar: String? = null,
    @SerialName("real_name") val realName: String? = null,
    @SerialName("subjects") val subjects: List<String>? = null,
    @SerialName("years") val years: Int? = null,
    @SerialName("intro") val intro: String? = null,
    @SerialName("rating") val rating: Double? = null,
    @SerialName("work_count") val workCount: Int? = null,
    @SerialName("studios") val studios: List<TeacherStudio>? = null
) {
    val displayName: String get() = realName ?: nickname
    val ratingText: String
        get() {
            val r = rating ?: return "—"
            return if (r > 0) String.format("%.1f", r) else "—"
        }
    val subjectText: String
        get() = (subjects ?: emptyList()).take(2).joinToString(" / ")
}

@Serializable
data class TeacherStudio(
    @SerialName("studio_id") val studioId: String = "",
    @SerialName("name") val name: String? = null
)

// MARK: - 相对时间

fun String?.shortRelativeTime(): String {
    if (this.isNullOrBlank()) return ""
    return try {
        val cleaned = replace("Z", "+00:00")
        val date = java.time.OffsetDateTime.parse(cleaned).toLocalDateTime()
        val now = java.time.LocalDateTime.now()
        val minutes = java.time.Duration.between(date, now).toMinutes()
        when {
            minutes < 1 -> "刚刚"
            minutes < 60 -> "${minutes}分钟前"
            date.toLocalDate() == now.toLocalDate() -> "今天 ${String.format("%02d:%02d", date.hour, date.minute)}"
            date.toLocalDate() == now.minusDays(1).toLocalDate() -> "昨天"
            minutes < 60 * 24 * 7 -> "${minutes / (60 * 24)}天前"
            else -> String.format("%02d-%02d", date.monthValue, date.dayOfMonth)
        }
    } catch (e: Exception) {
        this.take(10)
    }
}

/** "YYYY-MM-DD" → "周六" */
fun String?.weekdayText(): String {
    if (this.isNullOrBlank()) return ""
    return try {
        val date = java.time.LocalDate.parse(this.take(10))
        val weekdays = listOf("周一", "周二", "周三", "周四", "周五", "周六", "周日")
        weekdays[date.dayOfWeek.value - 1]
    } catch (e: Exception) {
        this
    }
}