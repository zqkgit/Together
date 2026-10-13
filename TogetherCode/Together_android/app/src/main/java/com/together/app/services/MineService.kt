package com.together.app.services

import com.together.app.core.network.ApiService
import com.together.app.core.network.JsonHelper.decode
import com.together.app.core.network.JsonHelper.decodeList
import com.together.app.core.network.JsonHelper.int
import kotlinx.serialization.Serializable

/**
 * 我的页面相关接口（资料 / 统计 / 钱包 / 佣金 / 我的评价）
 * 对齐 iOS MineService.swift
 */
object MineService {

    // MARK: - 资料 / 统计

    @Serializable
    data class MineProfile(
        val userId: String? = null,
        val nickname: String? = null,
        val avatar: String? = null,
        val phone: String? = null,
        val role: Int? = null,
        val gender: Int? = null,
        val bio: String? = null,
        val studioName: String? = null,
        val studioId: String? = null,
        val teacherTitle: String? = null,
        val createdAt: String? = null
    )

    @Serializable
    data class MineStats(
        val childCount: Int? = null,
        val courseCount: Int? = null,
        val postCount: Int? = null,
        val followingCount: Int? = null,
        val followerCount: Int? = null,
        val favoriteCount: Int? = null
    )

    /** 我的资料 + 统计（并行获取） */
    suspend fun fetchMine(): Pair<MineProfile?, MineStats?> {
        val profile = ApiService.get("/user/profile").decode<MineProfile>()
        val stats = ApiService.get("/user/stats").decode<MineStats>()
        return profile to stats
    }

    // MARK: - 钱包

    @Serializable
    data class WalletSummary(
        val balance: Int? = null,          // 余额（分）
        val totalIncome: Int? = null,      // 累计收入（分）
        val totalWithdraw: Int? = null,    // 累计提现（分）
        val frozenAmount: Int? = null,     // 冻结金额（分）
        val pendingCommission: Int? = null // 待结算佣金（分）
    )

    /** 钱包概览 */
    suspend fun fetchWallet(): WalletSummary? {
        return ApiService.get("/wallet/summary").decode<WalletSummary>()
    }

    /** 佣金/收入记录（分页）→ (items, hasMore) */
    suspend fun fetchCommissionRecords(page: Int, type: String? = null): Pair<List<CommissionRecordItem>, Boolean> {
        val params = mutableMapOf<String, Any?>("page" to page, "page_size" to 20)
        type?.takeIf { it.isNotEmpty() }?.let { params["type"] = it }
        val json = ApiService.get("/wallet/commissions", params)
        val items = json.decodeList<CommissionRecordItem>("list")
        val total = json.int("total")
        return items to (page * 20 < total)
    }

    @Serializable
    data class CommissionRecordItem(
        val id: String? = null,
        val orderId: String? = null,
        val courseName: String? = null,
        val studentName: String? = null,
        val amount: Int? = null,        // 金额（分），正=收入 负=支出
        val type: Int? = null,          // 1=课程佣金 2=分销佣金 3=提现 4=退款
        val status: Int? = null,        // 0=待结算 1=已结算 2=已取消
        val createdAt: String? = null,
        val settledAt: String? = null
    ) {
        val isIncome: Boolean get() = (amount ?: 0) > 0
        val typeLabel: String
            get() = when (type) {
                1 -> "课程佣金"
                2 -> "分销佣金"
                3 -> "提现"
                4 -> "退款"
                else -> "其他"
            }
        val statusLabel: String
            get() = when (status) {
                0 -> "待结算"
                1 -> "已结算"
                2 -> "已取消"
                else -> ""
            }
    }

    // MARK: - 我的评价

    /** 我发表的课程评价 */
    suspend fun fetchMyReviews(page: Int): Pair<List<MyReviewItem>, Boolean> {
        val json = ApiService.get("/user/reviews", mapOf("page" to page, "page_size" to 10))
        val items = json.decodeList<MyReviewItem>("list")
        val total = json.int("total")
        return items to (page * 10 < total)
    }

    @Serializable
    data class MyReviewItem(
        val reviewId: String? = null,
        val courseId: String? = null,
        val courseName: String? = null,
        val studioName: String? = null,
        val rating: Int? = null,
        val content: String? = null,
        val images: List<String>? = null,
        val createdAt: String? = null
    )
}