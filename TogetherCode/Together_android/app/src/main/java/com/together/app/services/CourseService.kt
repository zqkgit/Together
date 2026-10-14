package com.together.app.services

import com.together.app.core.model.ChildItem
import com.together.app.core.model.CourseDetail
import com.together.app.core.model.CourseReviewItem
import com.together.app.core.model.CourseStudySummary
import com.together.app.core.model.MyCourseItem
import com.together.app.core.network.ApiService
import com.together.app.core.network.JsonHelper.decode
import com.together.app.core.network.JsonHelper.decodeList
import com.together.app.core.network.JsonHelper.int
import com.together.app.core.network.JsonHelper.obj
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject

/**
 * 课程相关接口（报名闭环）
 * 对齐 iOS CourseService.swift
 */
object CourseService {

    // MARK: - 课程详情

    /** 课程详情（含课包、工作室） */
    suspend fun fetchDetail(courseId: String): CourseDetail? {
        return ApiService.get("/courses/$courseId").decode<CourseDetail>()
    }

    /** 我的孩子列表 */
    suspend fun fetchChildren(): List<ChildItem> {
        return ApiService.get("/children").decodeList<ChildItem>()
    }

    /** 创建订单（报名：课程固定课时与价格 + 选择班级）→ 返回 orderId */
    suspend fun createOrder(
        childId: String,
        courseId: String,
        classId: String? = null,
        distributionCode: String? = null
    ): String {
        val params = mutableMapOf<String, Any?>(
            "child_id" to childId,
            "course_id" to courseId
        )
        classId?.takeIf { it.isNotEmpty() }?.let { params["class_id"] = it }
        distributionCode?.takeIf { it.isNotEmpty() }?.let { params["distribution_code"] = it }
        val json = ApiService.post("/orders", params)
        return json.let { it["order_id"]?.toString()?.trim('"') ?: "" }
    }

    // MARK: - 课程评价

    @Serializable
    data class CourseReviewSummary(
        val rating: Double? = null,
        val ratingCount: Int? = null,
        val distribution: Map<String, Int>? = null
    )

    /** 课程评价（详情页家长评价）+ 评分汇总 */
    suspend fun fetchReviews(courseId: String): Pair<List<CourseReviewItem>, CourseReviewSummary?> {
        val json = ApiService.get("/courses/$courseId/reviews", mapOf("page" to 1, "page_size" to 10))
        val items = json.decodeList<CourseReviewItem>("list")
        val summary = json.decode<CourseReviewSummary>()
        return items to summary
    }

    /** 课程完整评价列表（分页）→ (items, hasMore) */
    suspend fun fetchCourseReviews(courseId: String, page: Int): Pair<List<CourseReviewItem>, Boolean> {
        val json = ApiService.get("/courses/$courseId/reviews", mapOf("page" to page, "page_size" to 10))
        val items = json.decodeList<CourseReviewItem>("list")
        val total = json.int("rating_count")
        return items to (page * 10 < total)
    }

    /** 发表评价 */
    suspend fun postReview(courseId: String, rating: Int, content: String?, imageUrls: List<String>) {
        val body = mutableMapOf<String, Any?>("rating" to rating)
        content?.takeIf { it.isNotEmpty() }?.let { body["content"] = it }
        if (imageUrls.isNotEmpty()) body["images"] = imageUrls
        ApiService.post("/courses/$courseId/reviews", body)
    }

    /** 编辑我的评价 */
    suspend fun updateReview(reviewId: String, rating: Int, content: String?, imageUrls: List<String>?) {
        val body = mutableMapOf<String, Any?>("rating" to rating)
        content?.takeIf { it.isNotEmpty() }?.let { body["content"] = it }
        imageUrls?.let { body["images"] = it }
        ApiService.put("/reviews/$reviewId", body)
    }

    // MARK: - 我的课程

    @Serializable
    data class ChildBrief(
        @SerialName("child_id") val childId: String = "",
        @SerialName("child_name") val childName: String = ""
    ) {
        val name: String get() = childName.takeIf { it.isNotEmpty() } ?: "孩子"
    }

    /** 我的课程（childId 为 null 时返回所有孩子的课程 + 筛选用 children 数组） */
    suspend fun fetchMyCourses(childId: String? = null): Pair<List<ChildBrief>, List<MyCourseItem>> {
        val params = mutableMapOf<String, Any?>()
        childId?.takeIf { it.isNotEmpty() }?.let { params["child_id"] = it }
        val json = ApiService.get("/parent/my-courses", params)
        val children = json.decodeList<ChildBrief>("children")
        val list = json.decodeList<MyCourseItem>("list")
        return children to list
    }

    /** 课时进度（课程详情下的排课 + 出勤状态） */
    suspend fun fetchCourseSchedules(childId: String, courseId: String): CourseStudySummary? {
        val json = ApiService.get("/parent/course-schedules", mapOf(
            "child_id" to childId, "course_id" to courseId
        ))
        return json.decode<CourseStudySummary>()
    }

    // MARK: - 请假

    @Serializable
    data class MyLeaveItem(
        val leaveId: String? = null,
        val scheduleId: String? = null,
        val childId: String? = null,
        val status: Int? = null,
        val makeupStatus: Int? = null,
        val makeupSchedule: MakeupSchedule? = null
    ) {
        @Serializable
        data class MakeupSchedule(
            val scheduleId: String? = null,
            val lessonDate: String? = null,
            val startTime: String? = null,
            val endTime: String? = null,
            val location: String? = null
        )
    }

    /** 提交请假（家长端） */
    suspend fun submitLeave(classId: String, childId: String, scheduleId: String?, reason: String) {
        val params = mutableMapOf<String, Any?>(
            "class_id" to classId,
            "child_id" to childId,
            "reason" to reason
        )
        scheduleId?.takeIf { it.isNotEmpty() }?.let { params["schedule_id"] = it }
        ApiService.post("/leave", params)
    }

    /** 我的请假列表 */
    suspend fun fetchMyLeaves(): List<MyLeaveItem> {
        val json = ApiService.get("/leave", mapOf("page" to 1, "page_size" to 50))
        return json.decodeList<MyLeaveItem>("list")
    }

    /** 撤销请假（仅待审批可撤销） */
    suspend fun cancelLeave(leaveId: String) {
        ApiService.put("/leave/$leaveId/cancel")
    }
}