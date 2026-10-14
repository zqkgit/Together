package com.together.app.services

import com.together.app.core.network.ApiService
import com.together.app.core.network.JsonHelper.decodeList
import com.together.app.core.network.JsonHelper.int
import com.together.app.core.network.JsonHelper.obj
import com.together.app.core.network.JsonHelper.strOrNull
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * 我的页面相关接口（资料 / 统计 / 钱包 / 佣金 / 我的评价）
 * 对齐 iOS MineService.swift
 */
object MineService {

    // MARK: - 资料 / 统计

    @Serializable
    data class MineUser(
        val userId: String? = null,
        val nickname: String? = null,
        val avatar: String? = null,
        val city: String? = null
    )

    @Serializable
    data class MineProfile(
        val user: MineUser? = null,
        val currentRole: Int? = null,
        val roles: List<Int>? = null,
        val teacherRealName: String? = null
    ) {
        /** 已认证老师实名（切换身份弹框展示老师名字） */
        val teacherName: String?
            get() = teacherRealName?.takeIf { it.isNotEmpty() }

        /** 是否已开通某角色（1 家长 / 2 老师 / 3 工作室） */
        fun hasRole(role: Int): Boolean = roles?.contains(role) ?: false
    }

    /** 头部统计：孩子数 / 在学课程数 / 收藏数 */
    data class MineStats(
        var childrenCount: Int = 0,
        var courseCount: Int = 0,
        var favoriteCount: Int = 0
    )

    /** 我的资料（/auth/me） */
    suspend fun fetchMe(): MineProfile {
        val json = ApiService.get("/auth/me")
        val user = json.obj("user")
        return MineProfile(
            user = MineUser(
                userId = user.strOrNull("user_id"),
                nickname = user.strOrNull("nickname"),
                avatar = user.strOrNull("avatar"),
                city = user.strOrNull("city")
            ),
            currentRole = json.int("current_role").takeIf { it != 0 },
            roles = json["roles"]?.let { rolesEl ->
                (rolesEl as? kotlinx.serialization.json.JsonArray)
                    ?.mapNotNull { (it as? kotlinx.serialization.json.JsonPrimitive)?.content?.toIntOrNull() }
            },
            teacherRealName = json.obj("teacher_profile").strOrNull("real_name")
        )
    }

    /** 并行聚合三项统计（任一失败不阻塞其余） */
    suspend fun fetchStats(): MineStats {
        val stats = MineStats()
        // 孩子数 + 在学课程（课包 course_id 去重）
        try {
            val childrenJson = ApiService.get("/children")
            val children = childrenJson.decodeList<com.together.app.core.model.ChildItem>("list")
            stats.childrenCount = childrenJson.int("total").takeIf { it > 0 } ?: children.size
            stats.courseCount = children.flatMap { it.balances ?: emptyList() }
                .mapNotNull { it.courseId }
                .filter { it.isNotEmpty() }
                .toSet()
                .size
        } catch (_: Exception) { }
        // 收藏数
        try {
            val favJson = ApiService.get("/favorites", mapOf("page" to 1, "page_size" to 1))
            stats.favoriteCount = favJson.int("total")
        } catch (_: Exception) { }
        return stats
    }

    // 收益中心（佣金/提现）已移至 CommissionService.kt（对齐 iOS CommissionService）

    // MARK: - 我的评价

    @Serializable
    data class MyReviewItem(
        @SerialName("review_id") val reviewId: String? = null,
        val rating: Int? = null,
        val content: String? = null,
        val images: List<String>? = null,
        val status: Int? = null,           // 0 待审核 / 1 通过 / 2 驳回
        @SerialName("reject_reason") val rejectReason: String? = null,
        @SerialName("reply_content") val replyContent: String? = null,
        @SerialName("teacher_reply_content") val teacherReplyContent: String? = null,
        @SerialName("created_at") val createdAt: String? = null,
        val course: CourseBrief? = null
    ) {
        val statusText: String
            get() = when (status ?: 0) {
                1 -> "已通过"
                2 -> "已驳回"
                else -> "待审核"
            }
        val timeText: String get() = createdAt?.takeIf { it.length >= 10 }?.take(10) ?: ""
    }

    @Serializable
    data class CourseBrief(
        @SerialName("course_id") val courseId: String? = null,
        val title: String? = null,
        val cover: String? = null
    )

    /** 我的评价列表（分页）→ (items, hasMore) */
    suspend fun fetchMyReviews(page: Int): Pair<List<MyReviewItem>, Boolean> {
        val json = ApiService.get("/reviews/mine", mapOf("page" to page, "page_size" to 10))
        val items = json.decodeList<MyReviewItem>("list")
        val total = json.int("total")
        return items to (page * 10 < total)
    }
}