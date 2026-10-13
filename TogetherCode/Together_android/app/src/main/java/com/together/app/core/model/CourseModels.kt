package com.together.app.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// MARK: - 课程详情

@Serializable
data class CourseDetail(
    @SerialName("course_id") val courseId: String = "",
    @SerialName("title") val title: String = "",
    @SerialName("cover") val cover: String? = null,
    @SerialName("intro") val intro: String? = null,
    @SerialName("price") val price: Int = 0,
    @SerialName("original_price") val originalPrice: Int? = null,
    @SerialName("rating") val rating: Double? = null,
    @SerialName("sales") val sales: Int? = null,
    @SerialName("age_min") val ageMin: Int? = null,
    @SerialName("age_max") val ageMax: Int? = null,
    @SerialName("total_lessons") val totalLessons: Int? = null,
    @SerialName("lesson_minutes") val lessonMinutes: Int? = null,
    @SerialName("tags") val tags: List<String>? = null,
    @SerialName("images") val images: List<String>? = null,
    @SerialName("studio") val studio: CourseStudio? = null,
    @SerialName("teacher") val teacher: CourseTeacher? = null,
    @SerialName("packages") val packages: List<PackageItem>? = null,
    @SerialName("classes") val classes: List<CourseClassItem>? = null,
    @SerialName("reviews") val reviews: List<CourseReviewItem>? = null,
    @SerialName("schedule") val schedule: List<CourseScheduleSummary>? = null
) {
    val priceText: String get() = price.fenToYuanText()
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
    val studioName: String get() = studio?.name ?: ""
    val teacherName: String get() = teacher?.realName ?: ""
}

// MARK: - 课程套餐

@Serializable
data class PackageItem(
    @SerialName("package_id") val packageId: String = "",
    @SerialName("title") val title: String = "",
    @SerialName("lessons") val lessons: Int = 0,
    @SerialName("price") val price: Int = 0,
    @SerialName("original_price") val originalPrice: Int? = null,
    @SerialName("status") val status: Int = 1,
    @SerialName("sort_order") val sortOrder: Int? = null
) {
    val priceText: String get() = price.fenToYuanText()
    val originalPriceText: String?
        get() {
            val op = originalPrice ?: return null
            return if (op > price) op.fenToYuanText() else null
        }
    val perLessonText: String
        get() = if (lessons > 0) "¥${String.format("%.1f", price / 100.0 / lessons)}/节" else priceText
    val descText: String get() = "${lessons}节 · ${priceText}"
}

// MARK: - 课程班级

@Serializable
data class CourseClassItem(
    @SerialName("class_id") val classId: String = "",
    @SerialName("title") val title: String = "",
    @SerialName("course_id") val courseId: String? = null,
    @SerialName("course_title") val courseTitle: String? = null,
    @SerialName("teacher_id") val teacherId: String? = null,
    @SerialName("teacher_name") val teacherName: String? = null,
    @SerialName("studio_id") val studioId: String? = null,
    @SerialName("studio_name") val studioName: String? = null,
    @SerialName("start_date") val startDate: String? = null,
    @SerialName("end_date") val endDate: String? = null,
    @SerialName("schedule_text") val scheduleText: String? = null,
    @SerialName("max_students") val maxStudents: Int = 0,
    @SerialName("enrolled_students") val enrolledStudents: Int = 0,
    @SerialName("status") val status: Int = 1
) {
    val remainingSlots: Int get() = (maxStudents - enrolledStudents).coerceAtLeast(0)
    val isFull: Boolean get() = remainingSlots <= 0
    val enrollmentText: String
        get() = if (maxStudents > 0) {
            if (isFull) "已满" else "余${remainingSlots}席"
        } else ""
}

// MARK: - 课程评价

@Serializable
data class CourseReviewItem(
    @SerialName("review_id") val reviewId: String = "",
    @SerialName("course_id") val courseId: String? = null,
    @SerialName("course_title") val courseTitle: String? = null,
    @SerialName("child_id") val childId: String? = null,
    @SerialName("child_name") val childName: String? = null,
    @SerialName("user_id") val userId: String? = null,
    @SerialName("nickname") val nickname: String = "",
    @SerialName("avatar") val avatar: String? = null,
    @SerialName("rating") val rating: Int = 0,
    @SerialName("content") val content: String = "",
    @SerialName("images") val images: List<String>? = null,
    @SerialName("created_at") val createdAt: String? = null
) {
    val timeText: String get() = createdAt.shortRelativeTime()
}

// MARK: - 我的课程

@Serializable
data class MyCourseItem(
    @SerialName("balance_id") val balanceId: String = "",
    @SerialName("course_id") val courseId: String = "",
    @SerialName("course_title") val courseTitle: String = "",
    @SerialName("course_cover") val courseCover: String? = null,
    @SerialName("studio_id") val studioId: String? = null,
    @SerialName("studio_name") val studioName: String? = null,
    @SerialName("teacher_id") val teacherId: String? = null,
    @SerialName("teacher_name") val teacherName: String? = null,
    @SerialName("total_lessons") val totalLessons: Int = 0,
    @SerialName("consumed_lessons") val consumedLessons: Int = 0,
    @SerialName("remaining_lessons") val remainingLessons: Int = 0,
    @SerialName("valid_from") val validFrom: String? = null,
    @SerialName("valid_to") val validTo: String? = null,
    @SerialName("status") val status: Int = 1,
    @SerialName("status_text") val statusText: String? = null,
    @SerialName("next_schedule") val nextSchedule: CourseScheduleSummary? = null
) {
    val progressPercent: Int
        get() = if (totalLessons > 0) minOf(100, (consumedLessons * 100 / totalLessons)) else 0
    val progressText: String get() = "已上 $consumedLessons/$totalLessons 节"
    val validText: String?
        get() {
            val from = validFrom?.take(10) ?: return null
            val to = validTo?.take(10) ?: return null
            return "有效期 $from ~ $to"
        }
}

// MARK: - 课程排课

@Serializable
data class CourseScheduleSummary(
    @SerialName("schedule_id") val scheduleId: String = "",
    @SerialName("class_id") val classId: String? = null,
    @SerialName("class_title") val classTitle: String? = null,
    @SerialName("lesson_no") val lessonNo: Int = 0,
    @SerialName("total_lessons") val totalLessons: Int? = null,
    @SerialName("lesson_date") val lessonDate: String? = null,
    @SerialName("start_time") val startTime: String? = null,
    @SerialName("end_time") val endTime: String? = null,
    @SerialName("status") val status: Int = 0,
    @SerialName("status_text") val statusText: String? = null,
    @SerialName("teacher_name") val teacherName: String? = null,
    @SerialName("studio_name") val studioName: String? = null
) {
    val dateText: String
        get() {
            val d = lessonDate?.take(10) ?: return ""
            val wd = lessonDate.weekdayText()
            return if (wd.isNotEmpty()) "$d $wd" else d
        }
    val timeText: String
        get() {
            val s = startTime?.take(5) ?: return ""
            val e = endTime?.take(5) ?: return s
            return "$s - $e"
        }
    val lessonText: String
        get() {
            val t = totalLessons ?: return "第${lessonNo}节"
            return "第${lessonNo}/$t 节"
        }
}

// MARK: - 请假

@Serializable
data class LeaveRequest(
    @SerialName("schedule_id") val scheduleId: String = "",
    @SerialName("child_id") val childId: String = "",
    @SerialName("reason") val reason: String = ""
)