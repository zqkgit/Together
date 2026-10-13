package com.together.app.services

import com.together.app.core.model.CommentItem
import com.together.app.core.model.PostItem
import com.together.app.core.network.ApiService
import com.together.app.core.network.ApiService.getElement
import com.together.app.core.network.JsonHelper.decode
import com.together.app.core.network.JsonHelper.decodeList
import com.together.app.core.network.JsonHelper.int
import com.together.app.core.network.JsonHelper.obj
import com.together.app.core.network.JsonHelper.str
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * 广场（帖子）相关接口
 * 对齐 iOS PostService.swift
 */
object PostService {

    private const val PAGE_SIZE = 10

    // MARK: - 广场流

    /**
     * 广场帖子流（分页 + 排序 + 话题筛选 + 附近）
     * @param sort latest（最新）/ hot（热门）/ near（附近，需传 lat/lng）
     */
    suspend fun fetchPlaza(
        page: Int,
        size: Int = PAGE_SIZE,
        sort: String = "latest",
        topic: String = "",
        lat: Double? = null,
        lng: Double? = null
    ): Pair<List<PostItem>, Boolean> {
        val params = mutableMapOf<String, Any?>("page" to page, "size" to size, "sort" to sort)
        if (topic.isNotEmpty()) params["topic"] = topic
        lat?.let { params["lat"] = it }
        lng?.let { params["lng"] = it }
        val json = ApiService.get("/posts/plaza", params)
        val items = json.decodeList<PostItem>("list")
        val total = json.int("total")
        return items to (page * size < total)
    }

    /** 发帖可选话题（公共接口，仅上架）→ 话题名列表 */
    suspend fun fetchTopics(): List<String> {
        val element = getElement("/topics")
        val arr = element as? JsonArray ?: return emptyList()
        return arr.mapNotNull { item ->
            (item as? JsonObject)?.str("name")?.takeIf { it.isNotEmpty() }
        }
    }

    // MARK: - 我的帖子 / 收藏 / 孩子动态

    /**
     * 我的作品（作品管理）：当前用户发布的全部帖子（含待审核/已驳回）
     * @param status all / public / private
     * @return (items, counts[全部, 公开, 未公开], hasMore)
     */
    suspend fun fetchMyWorks(
        page: Int,
        size: Int = PAGE_SIZE,
        status: String = "all"
    ): Triple<List<PostItem>, List<Int>, Boolean> {
        val json = ApiService.get("/posts/mine", mapOf("page" to page, "size" to size, "status" to status))
        val items = json.decodeList<PostItem>("list")
        val total = json.int("total")
        val countsObj = json.obj("counts")
        val counts = listOf(countsObj.int("all"), countsObj.int("public"), countsObj.int("private"))
        return Triple(items, counts, page * size < total)
    }

    /** 我的收藏（target_type=post） */
    suspend fun fetchFavorites(page: Int, size: Int = PAGE_SIZE): Pair<List<PostItem>, Boolean> {
        val json = ApiService.get(
            "/favorites",
            mapOf("target_type" to "post", "page" to page, "page_size" to size)
        )
        val items = json.decodeList<PostItem>("list")
        val total = json.int("total")
        return items to (page * size < total)
    }

    /** 孩子动态：我孩子相关的帖子（家长帖 + 老师关联帖） */
    suspend fun fetchChildFeed(page: Int, size: Int = PAGE_SIZE): Pair<List<PostItem>, Boolean> {
        val json = ApiService.get("/posts/child-feed", mapOf("page" to page, "size" to size))
        val items = json.decodeList<PostItem>("list")
        val total = json.int("total")
        return items to (page * size < total)
    }

    // MARK: - 详情 / 评论

    /** 帖子详情 */
    suspend fun fetchDetail(postId: String): PostItem? {
        return ApiService.get("/posts/$postId").decode<PostItem>()
    }

    /** 帖子评论列表（分页）→ (items, hasMore) */
    suspend fun fetchComments(postId: String, page: Int, size: Int = 50): Pair<List<CommentItem>, Boolean> {
        val json = ApiService.get("/posts/$postId/comments", mapOf("page" to page, "size" to size))
        val items = json.decodeList<CommentItem>("list")
        val total = json.int("total")
        return items to (page * size < total)
    }

    /** 发表评论（parentId 空/"0" 不传） */
    suspend fun postComment(postId: String, content: String, parentId: String? = null): CommentItem? {
        val params = mutableMapOf<String, Any?>("content" to content)
        parentId?.takeIf { it.isNotEmpty() && it != "0" }?.let { params["parent_id"] = it }
        return ApiService.post("/posts/$postId/comments", params).decode<CommentItem>()
    }

    /** 删除自己的评论 */
    suspend fun deleteComment(commentId: String) {
        ApiService.delete("/posts/comments/$commentId")
    }

    /** 评论点赞 / 取消点赞 */
    suspend fun toggleCommentLike(postId: String, commentId: String, liked: Boolean) {
        if (liked) ApiService.delete("/posts/$postId/comments/$commentId/like")
        else ApiService.post("/posts/$postId/comments/$commentId/like")
    }

    /** 帖子详情撤销某学生的发帖消课（仅帖子作者/老师） */
    suspend fun undoPostStudentConsumption(postId: String, childIds: List<String>) {
        ApiService.post("/teacher/posts/$postId/students/undo", mapOf("child_ids" to childIds))
    }

    // MARK: - 互动

    /** 帖子点赞 / 取消点赞 */
    suspend fun toggleLike(postId: String, liked: Boolean) {
        if (liked) ApiService.delete("/posts/$postId/like")
        else ApiService.post("/posts/$postId/like")
    }

    /** 收藏 / 取消收藏（对齐 iOS：POST /favorites body / DELETE /favorites?query） */
    suspend fun toggleFavorite(postId: String, favorited: Boolean) {
        if (favorited) {
            ApiService.delete("/favorites?target_type=post&target_id=$postId")
        } else {
            ApiService.post("/favorites", mapOf("target_type" to "post", "target_id" to postId))
        }
    }

    /** 关注 / 取消关注用户 */
    suspend fun toggleFollow(userId: String, following: Boolean) {
        if (following) ApiService.delete("/users/$userId/follow")
        else ApiService.post("/users/$userId/follow")
    }

    /** 我的关注列表（分页） */
    suspend fun fetchFollowing(page: Int, size: Int = 20): Pair<List<FollowingUser>, Boolean> {
        val json = ApiService.get("/following", mapOf("page" to page, "size" to size))
        val items = json.decodeList<FollowingUser>("list")
        val total = json.int("total")
        return items to (page * size < total)
    }

    @Serializable
    data class FollowingUser(
        val userId: String? = null,
        val nickname: String? = null,
        val avatar: String? = null,
        val role: Int? = null,
        val studioName: String? = null
    ) {
        val displayName: String get() = nickname ?: "艺启用户"
        val roleText: String
            get() = when (role) {
                2 -> "老师"
                3 -> "工作室"
                else -> "家长"
            }
    }

    // MARK: - 发帖 / 编辑 / 删除

    /** 家长发帖（POST /posts）→ post_id */
    suspend fun createPost(
        content: String,
        images: List<String>,
        childId: String,
        courseId: String? = null,
        topic: String = "",
        visibility: Int = 2,
        type: Int = 1,
        latitude: Double? = null,
        longitude: Double? = null,
        locationName: String? = null
    ): String {
        val body = buildJsonObject {
            put("content", content)
            put("images", JsonArray(images.map { JsonPrimitive(it) }))
            put("child_id", childId)
            put("visibility", visibility)
            put("type", type)
            courseId?.takeIf { it.isNotEmpty() }?.let { put("course_id", it) }
            topic.takeIf { it.isNotEmpty() }?.let { put("topic", it) }
            latitude?.let { put("latitude", it) }
            longitude?.let { put("longitude", it) }
            locationName?.takeIf { it.isNotEmpty() }?.let { put("location_name", it) }
        }
        return ApiService.post("/posts", body).str("post_id")
    }

    /** 老师发帖（POST /teacher/posts）：students=关联学生；consume=true 同步消课 */
    suspend fun createTeacherPost(
        content: String,
        images: List<String>,
        courseId: String? = null,
        classId: String? = null,
        scheduleId: String? = null,
        students: List<Map<String, Any>> = emptyList(),
        consume: Boolean = false,
        topic: String = "",
        visibility: Int = 2,
        type: Int = 2,
        latitude: Double? = null,
        longitude: Double? = null,
        locationName: String? = null
    ): String {
        val body = buildJsonObject {
            put("content", content)
            put("images", JsonArray(images.map { JsonPrimitive(it) }))
            put("visibility", visibility)
            put("type", type)
            put("consume", consume)
            courseId?.takeIf { it.isNotEmpty() }?.let { put("course_id", it) }
            classId?.takeIf { it.isNotEmpty() }?.let { put("class_id", it) }
            scheduleId?.takeIf { it.isNotEmpty() }?.let { put("schedule_id", it) }
            if (students.isNotEmpty()) {
                put("students", JsonArray(students.map { s ->
                    buildJsonObject {
                        s.forEach { (k, v) ->
                            when (v) {
                                is String -> put(k, v)
                                is Number -> put(k, v)
                                is Boolean -> put(k, v)
                            }
                        }
                    }
                }))
            }
            topic.takeIf { it.isNotEmpty() }?.let { put("topic", it) }
            latitude?.let { put("latitude", it) }
            longitude?.let { put("longitude", it) }
            locationName?.takeIf { it.isNotEmpty() }?.let { put("location_name", it) }
        }
        return ApiService.post("/teacher/posts", body).str("post_id")
    }

    /** 编辑家长作品帖（PUT /posts/{id}；仅作者本人） */
    suspend fun updatePost(
        postId: String,
        content: String,
        images: List<String>?,
        childId: String,
        courseId: String? = null,
        topic: String = "",
        visibility: Int = 2,
        latitude: Double? = null,
        longitude: Double? = null,
        locationName: String? = null,
        clearLocation: Boolean = false
    ) {
        val body = buildJsonObject {
            put("content", content)
            put("child_id", childId)
            put("visibility", visibility)
            images?.takeIf { it.isNotEmpty() }?.let { put("images", JsonArray(it.map { p -> JsonPrimitive(p) })) }
            courseId?.takeIf { it.isNotEmpty() }?.let { put("course_id", it) }
            topic.takeIf { it.isNotEmpty() }?.let { put("topic", it) }
            latitude?.let { put("latitude", it) }
            longitude?.let { put("longitude", it) }
            locationName?.takeIf { it.isNotEmpty() }?.let { put("location_name", it) }
            if (clearLocation) put("clear_location", true)
        }
        ApiService.put("/posts/$postId", body)
    }

    /** 编辑老师作品帖（PUT /teacher/posts/{id}；学生关联与消课不动，撤销走 undo） */
    suspend fun updateTeacherPost(
        postId: String,
        content: String,
        images: List<String>?,
        topic: String = "",
        visibility: Int = 2,
        latitude: Double? = null,
        longitude: Double? = null,
        locationName: String? = null,
        clearLocation: Boolean = false
    ) {
        val body = buildJsonObject {
            put("content", content)
            put("visibility", visibility)
            images?.takeIf { it.isNotEmpty() }?.let { put("images", JsonArray(it.map { p -> JsonPrimitive(p) })) }
            topic.takeIf { it.isNotEmpty() }?.let { put("topic", it) }
            latitude?.let { put("latitude", it) }
            longitude?.let { put("longitude", it) }
            locationName?.takeIf { it.isNotEmpty() }?.let { put("location_name", it) }
            if (clearLocation) put("clear_location", true)
        }
        ApiService.put("/teacher/posts/$postId", body)
    }

    /** 删除帖子（家长/老师统一；老师帖自动退消课课时） */
    suspend fun deletePost(postId: String) {
        ApiService.delete("/posts/$postId")
    }

    // MARK: - 老师端（班级 / 排课 / 花名册）

    /** 老师班级列表（含课程，一个班级对应一门课） */
    suspend fun fetchTeacherClasses(): List<TeacherClassItem> {
        val json = ApiService.get("/teacher/classes")
        return json.decodeList<TeacherClassItem>("list")
    }

    @Serializable
    data class TeacherCourse(
        @kotlinx.serialization.SerialName("course_id") val courseId: String = "",
        val title: String? = null,
        @kotlinx.serialization.SerialName("duration_min") val durationMin: Int? = null
    )

    @Serializable
    data class TeacherClassItem(
        @kotlinx.serialization.SerialName("class_id") val classId: String = "",
        val name: String = "",
        val course: TeacherCourse? = null
    ) {
        val displayName: String
            get() {
                val title = course?.title
                return if (!title.isNullOrBlank()) "$title · $name" else name
            }
    }

    /** 班级学生（花名册，发帖关联学生用） */
    suspend fun fetchTeacherClassStudents(classId: String): List<TeacherStudentItem> {
        val json = ApiService.get("/teacher/classes/$classId/students")
        return json.decodeList<TeacherStudentItem>("list")
    }

    @Serializable
    data class TeacherStudentItem(
        @kotlinx.serialization.SerialName("child_id") val childId: String = "",
        val nickname: String = "",
        val avatar: String? = null
    )

    /** 老师的排课表（按周/按天） */
    suspend fun fetchTeacherTimetable(date: String? = null, week: String? = null): List<TeacherTimetableItem> {
        val params = mutableMapOf<String, Any?>()
        date?.takeIf { it.isNotEmpty() }?.let { params["date"] = it }
        week?.takeIf { it.isNotEmpty() }?.let { params["week"] = it }
        val json = ApiService.get("/teacher/timetable", params)
        return json.decodeList<TeacherTimetableItem>("list")
    }

    @Serializable
    data class TeacherTimetableItem(
        @kotlinx.serialization.SerialName("schedule_id") val scheduleId: String = "",
        @kotlinx.serialization.SerialName("studio_name") val studioName: String? = null,
        @kotlinx.serialization.SerialName("lesson_date") val lessonDate: String? = null,
        @kotlinx.serialization.SerialName("start_time") val startTime: String? = null,
        @kotlinx.serialization.SerialName("end_time") val endTime: String? = null,
        val location: String? = null,
        @kotlinx.serialization.SerialName("consume_status") val consumeStatus: String? = null,
        @kotlinx.serialization.SerialName("student_count") val studentCount: Int? = null,
        @kotlinx.serialization.SerialName("leave_count") val leaveCount: Int? = null,
        @kotlinx.serialization.SerialName("consumed_count") val consumedCount: Int? = null,
        val status: Int? = null
    ) {
        val displayName: String
            get() {
                val d = lessonDate ?: ""
                val t = startTime ?: ""
                return if (d.isEmpty()) "课次 $scheduleId" else "$d $t"
            }
        val consumeText: String?
            get() = when (consumeStatus) {
                "completed" -> "已消课"
                "partial" -> "部分消课"
                "pending" -> "待消课"
                else -> null
            }
    }
}