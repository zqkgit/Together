package com.together.app.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// MARK: - 帖子

@Serializable
data class PostItem(
    @SerialName("post_id") val postId: String = "",
    @SerialName("type") val type: Int = 1, // 1 动态 / 2 孩子作品
    @SerialName("author") val author: PostAuthor? = null,
    @SerialName("author_role") val authorRole: Int? = null,
    @SerialName("author_role_text") val authorRoleText: String? = null,
    @SerialName("content") val content: String? = null,
    @SerialName("images") val images: List<String>? = null,
    @SerialName("topic") val topic: String? = null,
    @SerialName("like_count") val likeCount: Int? = null,
    @SerialName("comment_count") val commentCount: Int? = null,
    @SerialName("share_count") val shareCount: Int? = null,
    @SerialName("is_liked") val isLiked: Boolean? = null,
    @SerialName("is_favorite") val isFavorite: Boolean? = null,
    @SerialName("is_following") val isFollowing: Boolean? = null,
    @SerialName("child") val child: PostChild? = null,
    @SerialName("course") val course: PostCourse? = null,
    @SerialName("class_id") val classId: String? = null,
    @SerialName("students") val students: List<PostStudentItem>? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("visibility") val visibility: Int? = null,
    @SerialName("status") val status: Int? = null,
    @SerialName("is_mine") val isMine: Boolean? = null,
    @SerialName("location") val location: PostLocation? = null,
    @SerialName("distance_km") val distanceKm: Double? = null
) {
    val authorName: String get() = author?.nickname ?: "匿名"
    val authorAvatar: String? get() = author?.avatar
    val roleText: String get() = authorRoleText ?: ""
    val bodyText: String get() = content ?: ""
    val imageList: List<String> get() = images ?: emptyList()
    val safeTopic: String?
        get() {
            val t = topic ?: return null
            if (t.isEmpty() || t.lowercase() == "null" || t.lowercase() == "nil") return null
            return t
        }
    val likeText: String get() = "${likeCount ?: 0}"
    val commentText: String get() = "${commentCount ?: 0}"
    val isPublic: Boolean get() = visibility == 2
    val visibilityText: String get() = if (isPublic) "公开" else "未公开"
    val statusLabel: String
        get() = when (status) {
            0 -> "审核中"
            -1 -> "已驳回"
            else -> "已发布"
        }
    val studentList: List<PostStudentItem> get() = students ?: emptyList()
    val hasConsumedStudents: Boolean get() = studentList.any { it.deducted == true }
    val timeText: String get() = createdAt.shortRelativeTime()
    val relationText: String?
        get() {
            val childName = child?.nickname
            if (!childName.isNullOrBlank()) return "宝宝 · $childName"
            val courseTitle = course?.title
            if (!courseTitle.isNullOrBlank()) return "课程 · $courseTitle"
            return null
        }
    val distanceText: String?
        get() {
            val km = distanceKm ?: return null
            if (km < 0) return null
            return if (km < 1) "${maxOf(0, (km * 1000).toInt())}m" else String.format("%.1fkm", km)
        }
}

@Serializable
data class PostAuthor(
    @SerialName("user_id") val userId: String = "",
    @SerialName("nickname") val nickname: String = "",
    @SerialName("avatar") val avatar: String? = null,
    @SerialName("role") val role: Int? = null
)

@Serializable
data class PostChild(
    @SerialName("child_id") val childId: String = "",
    @SerialName("nickname") val nickname: String? = null
)

@Serializable
data class PostCourse(
    @SerialName("course_id") val courseId: String = "",
    @SerialName("title") val title: String? = null,
    @SerialName("price") val price: Int? = null
)

@Serializable
data class PostStudentItem(
    @SerialName("child_id") val childId: String = "",
    @SerialName("nickname") val nickname: String? = null,
    @SerialName("avatar") val avatar: String? = null,
    @SerialName("deducted") val deducted: Boolean? = null
)

@Serializable
data class PostLocation(
    @SerialName("latitude") val latitude: Double? = null,
    @SerialName("longitude") val longitude: Double? = null,
    @SerialName("name") val name: String? = null,
    @SerialName("address") val address: String? = null
)

// MARK: - 帖子评论

@Serializable
data class CommentItem(
    @SerialName("comment_id") val commentId: String = "",
    @SerialName("content") val content: String = "",
    @SerialName("parent_id") val parentId: String? = null,
    @SerialName("like_count") val likeCount: Int? = null,
    @SerialName("is_liked") val isLiked: Boolean? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("user") val user: CommentUser? = null
) {
    val authorName: String get() = user?.nickname ?: "艺启用户"
    val authorAvatar: String? get() = user?.avatar
    val timeText: String get() = createdAt.shortRelativeTime()
}

@Serializable
data class CommentUser(
    @SerialName("user_id") val userId: String = "",
    @SerialName("nickname") val nickname: String = "",
    @SerialName("avatar") val avatar: String? = null
)