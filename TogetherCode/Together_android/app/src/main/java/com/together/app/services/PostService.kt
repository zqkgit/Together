package com.together.app.services

import com.together.app.core.model.CommentItem
import com.together.app.core.model.PostItem
import com.together.app.core.network.ApiService
import com.together.app.core.network.JsonHelper.decode
import com.together.app.core.network.JsonHelper.decodeList
import com.together.app.core.network.JsonHelper.int
import kotlinx.serialization.Serializable

/**
 * 广场（帖子）相关接口
 * 对齐 iOS PostService.swift
 */
object PostService {

    // MARK: - 广场流

    /** 广场流（分页，可按话题/标签筛选）→ (items, hasMore) */
    suspend fun fetchFeed(page: Int, topic: String? = null, tag: String? = null): Pair<List<PostItem>, Boolean> {
        val params = mutableMapOf<String, Any?>("page" to page, "page_size" to 10)
        topic?.takeIf { it.isNotEmpty() }?.let { params["topic"] = it }
        tag?.takeIf { it.isNotEmpty() }?.let { params["tag"] = it }
        val json = ApiService.get("/posts", params)
        val items = json.decodeList<PostItem>("list")
        val total = json.int("total")
        return items to (page * 10 < total)
    }

    /** 热门话题列表 */
    suspend fun fetchTopics(): List<TopicItem> {
        val json = ApiService.get("/posts/topics")
        return json.decodeList<TopicItem>("list")
    }

    @Serializable
    data class TopicItem(
        val id: String? = null,
        val name: String? = null,
        val postCount: Int? = null
    )

    // MARK: - 我的帖子

    /** 我发布的帖子 */
    suspend fun fetchMyPosts(page: Int): Pair<List<PostItem>, Boolean> {
        val json = ApiService.get("/posts/mine", mapOf("page" to page, "page_size" to 10))
        val items = json.decodeList<PostItem>("list")
        val total = json.int("total")
        return items to (page * 10 < total)
    }

    /** 我的收藏帖子 */
    suspend fun fetchFavorites(page: Int): Pair<List<PostItem>, Boolean> {
        val json = ApiService.get("/posts/favorites", mapOf("page" to page, "page_size" to 10))
        val items = json.decodeList<PostItem>("list")
        val total = json.int("total")
        return items to (page * 10 < total)
    }

    /** 孩子动态（按孩子筛选） */
    suspend fun fetchChildPosts(childId: String?, page: Int): Pair<List<PostItem>, Boolean> {
        val params = mutableMapOf<String, Any?>("page" to page, "page_size" to 10)
        childId?.takeIf { it.isNotEmpty() }?.let { params["child_id"] = it }
        val json = ApiService.get("/posts/children", params)
        val items = json.decodeList<PostItem>("list")
        val total = json.int("total")
        return items to (page * 10 < total)
    }

    // MARK: - 详情 / 评论

    /** 帖子详情 */
    suspend fun fetchDetail(postId: String): PostItem? {
        return ApiService.get("/posts/$postId").decode<PostItem>()
    }

    /** 帖子评论列表（分页）→ (items, hasMore) */
    suspend fun fetchComments(postId: String, page: Int): Pair<List<CommentItem>, Boolean> {
        val json = ApiService.get("/posts/$postId/comments", mapOf("page" to page, "page_size" to 20))
        val items = json.decodeList<CommentItem>("list")
        val total = json.int("total")
        return items to (page * 20 < total)
    }

    /** 发表评论 */
    suspend fun postComment(postId: String, content: String, parentId: String? = null): CommentItem? {
        val params = mutableMapOf<String, Any?>("content" to content)
        parentId?.takeIf { it.isNotEmpty() }?.let { params["parent_id"] = it }
        return ApiService.post("/posts/$postId/comments", params).decode<CommentItem>()
    }

    // MARK: - 互动

    /** 点赞 / 取消点赞 */
    suspend fun toggleLike(postId: String, liked: Boolean) {
        if (liked) ApiService.delete("/posts/$postId/like")
        else ApiService.post("/posts/$postId/like")
    }

    /** 收藏 / 取消收藏 */
    suspend fun toggleFavorite(postId: String, favorited: Boolean) {
        if (favorited) ApiService.delete("/posts/$postId/favorite")
        else ApiService.post("/posts/$postId/favorite")
    }

    // MARK: - 关注

    /** 关注 / 取消关注用户 */
    suspend fun toggleFollow(userId: String, following: Boolean) {
        if (following) ApiService.delete("/users/$userId/follow")
        else ApiService.post("/users/$userId/follow")
    }

    /** 我的关注列表 */
    suspend fun fetchFollowing(page: Int): Pair<List<FollowingUser>, Boolean> {
        val json = ApiService.get("/users/following", mapOf("page" to page, "page_size" to 20))
        val items = json.decodeList<FollowingUser>("list")
        val total = json.int("total")
        return items to (page * 20 < total)
    }

    @Serializable
    data class FollowingUser(
        val userId: String? = null,
        val nickname: String? = null,
        val avatar: String? = null,
        val role: Int? = null,
        val studioName: String? = null
    )

    // MARK: - 发帖 / 编辑 / 删除

    /** 发帖 */
    suspend fun createPost(params: CreatePostParams): String {
        val json = ApiService.post("/posts", params.toBody())
        return json.decode<PostItem>()?.postId ?: ""
    }

    /** 编辑帖子 */
    suspend fun updatePost(postId: String, params: CreatePostParams) {
        ApiService.put("/posts/$postId", params.toBody())
    }

    /** 删除帖子 */
    suspend fun deletePost(postId: String) {
        ApiService.delete("/posts/$postId")
    }

    @Serializable
    data class CreatePostParams(
        val content: String,
        val imageUrls: List<String> = emptyList(),
        val childIds: List<String> = emptyList(),
        val topic: String? = null,
        val courseId: String? = null,
        val studioId: String? = null,
        val isPublic: Boolean = true,
        val location: String? = null
    ) {
        fun toBody(): Map<String, Any?> {
            val body = mutableMapOf<String, Any?>("content" to content)
            if (imageUrls.isNotEmpty()) body["images"] = imageUrls
            if (childIds.isNotEmpty()) body["child_ids"] = childIds
            topic?.takeIf { it.isNotEmpty() }?.let { body["topic"] = it }
            courseId?.takeIf { it.isNotEmpty() }?.let { body["course_id"] = it }
            studioId?.takeIf { it.isNotEmpty() }?.let { body["studio_id"] = it }
            body["is_public"] = isPublic
            location?.takeIf { it.isNotEmpty() }?.let { body["location"] = it }
            return body
        }
    }

    // MARK: - 老师端（班级 / 排课 / 花名册）

    /** 老师的班级列表 */
    suspend fun fetchTeacherClasses(): List<TeacherClassItem> {
        val json = ApiService.get("/teacher/classes")
        return json.decodeList<TeacherClassItem>("list")
    }

    @Serializable
    data class TeacherClassItem(
        val classId: String? = null,
        val className: String? = null,
        val courseId: String? = null,
        val courseName: String? = null,
        val studioId: String? = null,
        val studioName: String? = null,
        val studentCount: Int? = null,
        val scheduleText: String? = null
    )

    /** 老师的排课表（按周） */
    suspend fun fetchTeacherTimetable(weekStart: String? = null): List<TeacherTimetableItem> {
        val params = mutableMapOf<String, Any?>()
        weekStart?.takeIf { it.isNotEmpty() }?.let { params["week_start"] = it }
        val json = ApiService.get("/teacher/timetable", params)
        return json.decodeList<TeacherTimetableItem>("list")
    }

    @Serializable
    data class TeacherTimetableItem(
        val scheduleId: String? = null,
        val classId: String? = null,
        val className: String? = null,
        val courseId: String? = null,
        val courseName: String? = null,
        val lessonDate: String? = null,
        val startTime: String? = null,
        val endTime: String? = null,
        val location: String? = null,
        val studentCount: Int? = null
    )

    /** 班级花名册 */
    suspend fun fetchClassRoster(classId: String): List<RosterStudent> {
        val json = ApiService.get("/teacher/classes/$classId/students")
        return json.decodeList<RosterStudent>("list")
    }

    @Serializable
    data class RosterStudent(
        val childId: String? = null,
        val nickname: String? = null,
        val avatar: String? = null,
        val gender: Int? = null,
        val age: Int? = null,
        val remainingLessons: Int? = null,
        val attendedCount: Int? = null,
        val absentCount: Int? = null,
        val parentId: String? = null,
        val parentNickname: String? = null
    )
}