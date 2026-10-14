package com.together.app.services

import com.together.app.core.network.ApiService
import com.together.app.core.network.JsonHelper.decode
import com.together.app.core.network.JsonHelper.decodeList
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * 公开主页服务（老师主页 + 工作室主页，无需登录）
 * 对齐 iOS TeacherProfileService + StudioHomepageService
 */
object ProfileService {

    // MARK: - 老师主页

    @Serializable
    data class TeacherProfileData(
        val user: TeacherProfileUser? = null,
        val profile: TeacherProfileInfo? = null,
        val studios: List<TeacherProfileStudio>? = null,
        val courses: List<TeacherProfileCourse>? = null,
        val works: WorkPage? = null,
        @SerialName("student_works") val studentWorks: WorkPage? = null
    )

    @Serializable
    data class TeacherProfileUser(
        @SerialName("user_id") val userId: String? = null,
        val nickname: String? = null,
        val avatar: String? = null,
        val city: String? = null
    )

    @Serializable
    data class TeacherProfileInfo(
        @SerialName("teacher_id") val teacherId: String = "",
        @SerialName("real_name") val realName: String? = null,
        val subjects: List<String>? = null,
        val years: Int? = null,
        val intro: String? = null,
        val portfolio: List<String>? = null,
        val rating: Double? = null,
        @SerialName("student_count") val studentCount: Int? = null,
        @SerialName("work_count") val workCount: Int? = null,
        val fans: Int? = null
    ) {
        val displayName: String get() = realName ?: "老师"
        val subjectsText: String
            get() = (subjects ?: emptyList()).takeIf { it.isNotEmpty() }?.joinToString(" / ") ?: "暂未填写擅长方向"
        val yearsText: String get() = if ((years ?: 0) > 0) "教龄${years}年" else ""
    }

    @Serializable
    data class TeacherProfileStudio(
        @SerialName("studio_id") val studioId: String = "",
        val name: String? = null,
        val cover: String? = null,
        val address: String? = null
    )

    @Serializable
    data class TeacherProfileCourse(
        @SerialName("course_id") val courseId: String = "",
        val title: String = "",
        val cover: String? = null,
        val price: Int = 0,
        @SerialName("age_min") val ageMin: Int? = null,
        @SerialName("age_max") val ageMax: Int? = null,
        @SerialName("total_lessons") val totalLessons: Int? = null,
        val rating: Double? = null
    )

    @Serializable
    data class WorkPage(
        val total: Int? = null,
        val page: Int? = null,
        val size: Int? = null,
        val list: List<WorkItem>? = null
    )

    @Serializable
    data class WorkItem(
        @SerialName("post_id") val postId: String = "",
        val type: Int? = null,
        val images: List<String>? = null,
        val content: String? = null,
        @SerialName("like_count") val likeCount: Int? = null,
        @SerialName("comment_count") val commentCount: Int? = null,
        @SerialName("created_at") val createdAt: String? = null
    ) {
        val firstImage: String? get() = images?.firstOrNull()
    }

    @Serializable
    data class TeacherReviewsData(
        val total: Int? = null,
        val average: Double? = null,
        @SerialName("rating_distribution") val ratingDistribution: Map<String, Int>? = null,
        val list: List<TeacherReview>? = null
    )

    @Serializable
    data class TeacherReview(
        @SerialName("review_id") val reviewId: String? = null,
        val rating: Int? = null,
        val content: String? = null,
        @SerialName("created_at") val createdAt: String? = null,
        val user: ReviewUser? = null,
        val course: ReviewCourse? = null
    ) {
        val dateText: String get() = createdAt?.takeIf { it.length >= 10 }?.substring(0, 10) ?: ""
        val starsText: String
            get() {
                val r = (rating ?: 0).coerceIn(0, 5)
                return "★".repeat(r) + "☆".repeat(5 - r)
            }
    }

    @Serializable
    data class ReviewUser(
        @SerialName("user_id") val userId: String? = null,
        val nickname: String? = null,
        val avatar: String? = null
    )

    @Serializable
    data class ReviewCourse(
        @SerialName("course_id") val courseId: String? = null,
        val title: String? = null
    )

    /** 老师主页详情 */
    suspend fun fetchTeacherHomepage(teacherId: String, page: Int = 1): TeacherProfileData {
        return ApiService.get("/profile/teacher/$teacherId/homepage", mapOf("page" to page, "size" to 10))
            .decode<TeacherProfileData>() ?: TeacherProfileData()
    }

    /** 老师公开评价 */
    suspend fun fetchTeacherReviews(teacherId: String, page: Int = 1): TeacherReviewsData {
        return ApiService.get("/profile/teacher/$teacherId/reviews", mapOf("page" to page, "size" to 10))
            .decode<TeacherReviewsData>() ?: TeacherReviewsData()
    }

    /** 老师学员作品分页 */
    suspend fun fetchTeacherStudentWorks(teacherId: String, page: Int = 1): WorkPage {
        return ApiService.get("/profile/teacher/$teacherId/student-works", mapOf("page" to page, "size" to 10))
            .decode<WorkPage>() ?: WorkPage()
    }

    // MARK: - 工作室主页

    @Serializable
    data class StudioHomepageData(
        val studio: StudioHomepageInfo? = null,
        val courses: StudioCoursePage? = null,
        val teachers: List<StudioHomepageTeacher>? = null,
        @SerialName("student_works") val studentWorks: StudioStudentWorkPage? = null
    )

    @Serializable
    data class StudioHomepageInfo(
        @SerialName("studio_id") val studioId: String = "",
        @SerialName("user_id") val userId: String? = null,
        val name: String = "",
        val cover: String? = null,
        @SerialName("type_tags") val typeTags: List<String>? = null,
        val intro: String? = null,
        val address: String? = null,
        val phone: String? = null,
        val hours: String? = null,
        val photos: List<String>? = null,
        val city: String? = null,
        @SerialName("business_type") val businessType: String? = null,
        val rating: Double? = null,
        @SerialName("course_count") val courseCount: Int? = null,
        @SerialName("teacher_count") val teacherCount: Int? = null
    ) {
        val displayName: String get() = name.ifEmpty { "工作室" }
        val tagsText: String get() = (typeTags ?: emptyList()).take(3).joinToString(" · ")
        val locationText: String
            get() = listOfNotNull(
                city?.takeIf { it.isNotEmpty() },
                businessType?.takeIf { it.isNotEmpty() }
            ).joinToString(" · ")
    }

    @Serializable
    data class StudioHomepageCourse(
        @SerialName("course_id") val courseId: String = "",
        val title: String = "",
        val cover: String? = null,
        val price: Int = 0,
        @SerialName("original_price") val originalPrice: Int? = null,
        @SerialName("age_min") val ageMin: Int? = null,
        @SerialName("age_max") val ageMax: Int? = null,
        @SerialName("lesson_count") val lessonCount: Int? = null
    )

    @Serializable
    data class StudioCoursePage(
        val total: Int? = null,
        val page: Int? = null,
        val size: Int? = null,
        val list: List<StudioHomepageCourse>? = null
    )

    @Serializable
    data class StudioHomepageTeacher(
        @SerialName("teacher_id") val teacherId: String = "",
        @SerialName("user_id") val userId: String? = null,
        val nickname: String? = null,
        val avatar: String? = null,
        @SerialName("real_name") val realName: String? = null,
        val subjects: List<String>? = null,
        val years: Int? = null,
        val rating: Double? = null
    ) {
        val displayName: String get() = realName ?: nickname ?: "老师"
        val subjectText: String get() = (subjects ?: emptyList()).take(2).joinToString(" / ")
        val subtitle: String
            get() {
                val parts = mutableListOf<String>()
                if (subjectText.isNotEmpty()) parts.add(subjectText)
                val r = rating ?: 0.0
                if (r > 0) parts.add("⭐${String.format("%.1f", r)}")
                if ((years ?: 0) > 0) parts.add("教龄${years}年")
                return if (parts.isEmpty()) "暂未填写擅长方向" else parts.joinToString(" · ")
            }
    }

    @Serializable
    data class StudioStudentWork(
        @SerialName("post_id") val postId: String = "",
        val type: Int? = null,
        val images: List<String>? = null,
        val content: String? = null,
        @SerialName("like_count") val likeCount: Int? = null,
        @SerialName("comment_count") val commentCount: Int? = null,
        @SerialName("created_at") val createdAt: String? = null
    ) {
        val firstImage: String? get() = images?.firstOrNull()
    }

    @Serializable
    data class StudioStudentWorkPage(
        val total: Int? = null,
        val page: Int? = null,
        val size: Int? = null,
        val list: List<StudioStudentWork>? = null
    )

    /** 工作室主页详情 */
    suspend fun fetchStudioHomepage(studioId: String, page: Int = 1): StudioHomepageData {
        return ApiService.get("/profile/studio/$studioId/homepage", mapOf("page" to page, "size" to 10))
            .decode<StudioHomepageData>() ?: StudioHomepageData()
    }

    /** 工作室学员作品分页 */
    suspend fun fetchStudioStudentWorks(studioId: String, page: Int = 1): StudioStudentWorkPage {
        return ApiService.get("/profile/studio/$studioId/student-works", mapOf("page" to page, "size" to 10))
            .decode<StudioStudentWorkPage>() ?: StudioStudentWorkPage()
    }
}