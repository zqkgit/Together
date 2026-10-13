package com.together.app.services

import com.together.app.core.model.ChildBalance
import com.together.app.core.model.ChildItem
import com.together.app.core.network.ApiService
import com.together.app.core.network.JsonHelper.decode
import com.together.app.core.network.JsonHelper.decodeList
import com.together.app.core.network.JsonHelper.listOf
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * 孩子模块数据服务
 * 对齐 iOS ChildService.swift
 */
object ChildService {

    // MARK: - 孩子作品 / 成长动态模型

    @Serializable
    data class ChildWorkItem(
        @SerialName("post_id") val postId: String? = null,
        val content: String? = null,
        val images: List<String>? = null,
        @SerialName("course_title") val courseTitle: String? = null
    )

    @Serializable
    data class ChildGrowthEvent(
        @SerialName("event_id") val eventId: String? = null,
        @SerialName("event_type") val eventType: String? = null,
        @SerialName("course_title") val courseTitle: String? = null,
        @SerialName("studio_name") val studioName: String? = null,
        val note: String? = null,
        @SerialName("occurred_at") val occurredAt: String? = null,
        val delta: Int? = null,
        val post: ChildWorkItem? = null
    ) {
        val sourceName: String get() = studioName ?: "成长记录"
        val bodyText: String
            get() {
                val n = note
                if (!n.isNullOrEmpty()) return n
                return post?.content ?: "记录了新的成长瞬间"
            }
    }

    @Serializable
    private data class ChildBalanceChild(
        @SerialName("child_id") val childId: String = "",
        val balances: List<ChildBalance>? = null
    )

    @Serializable
    data class LessonLogItem(
        @SerialName("log_id") val logId: String? = null,
        @SerialName("child_name") val childName: String? = null,
        @SerialName("course_title") val courseTitle: String? = null,
        @SerialName("studio_name") val studioName: String? = null,
        @SerialName("lesson_date") val lessonDate: String? = null,
        @SerialName("start_time") val startTime: String? = null,
        @SerialName("is_makeup") val isMakeup: Boolean? = null,
        val delta: Int? = null,
        val note: String? = null
    )

    // MARK: - 接口

    /** 孩子列表 */
    suspend fun fetchChildren(): List<ChildItem> {
        return ApiService.get("/children").decodeList<ChildItem>()
    }

    /** 孩子作品列表（帖子归档） */
    suspend fun fetchChildWorks(childId: String): List<ChildWorkItem> {
        return ApiService.get("/children/$childId/works").decodeList<ChildWorkItem>()
    }

    /** 成长动态时间线（接口返回 timeline 字段） */
    suspend fun fetchChildGrowth(childId: String): List<ChildGrowthEvent> {
        val json = ApiService.get("/children/$childId/growth")
        return json.decodeList<ChildGrowthEvent>("timeline")
    }

    /** 添加孩子（avatar 传 emoji 字符 / OSS URL 均可） */
    suspend fun createChild(
        nickname: String,
        avatar: String?,
        birthday: String,
        gender: Int,
        interests: List<String>
    ): ChildItem {
        val params = mutableMapOf<String, Any?>(
            "nickname" to nickname,
            "birthday" to birthday,
            "gender" to gender
        )
        avatar?.takeIf { it.isNotEmpty() }?.let { params["avatar"] = it }
        if (interests.isNotEmpty()) params["interests"] = interests.joinToString(",")

        val json = ApiService.post("/children", params)
        return json.decode<ChildItem>() ?: ChildItem(
            nickname = nickname,
            avatar = avatar,
            birthday = birthday,
            gender = gender,
            interests = interests
        )
    }

    /** 课时余额列表（某孩子的所有课包） */
    suspend fun fetchChildBalances(childId: String): List<ChildBalance> {
        val json = ApiService.get("/parent/balances")
        val children = json.decodeList<ChildBalanceChild>("children")
        return children.firstOrNull { it.childId == childId }?.balances ?: emptyList()
    }

    /** 消课记录 */
    suspend fun fetchLessonLogs(childId: String, page: Int = 1, pageSize: Int = 50): List<LessonLogItem> {
        val json = ApiService.get("/parent/lesson-logs", mapOf(
            "child_id" to childId, "page" to page, "page_size" to pageSize
        ))
        return json.decodeList<LessonLogItem>("list")
    }
}