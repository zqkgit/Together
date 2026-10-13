package com.together.app.services

import com.together.app.core.network.ApiService
import com.together.app.core.network.JsonHelper.decode
import com.together.app.core.network.JsonHelper.decodeList
import com.together.app.core.network.JsonHelper.int
import kotlinx.serialization.Serializable

/**
 * 佣金（分销返利）服务（对齐 iOS CommissionService）
 * 口径：平台不碰资金。佣金由工作室线下审核打款，推广人按工作室分别申请、确认到账。
 */
object CommissionService {

    // MARK: - 收益总览

    @Serializable
    data class Period(
        val startDate: String? = null,
        val endDate: String? = null
    )

    @Serializable
    data class WalletInfo(
        val balance: Double? = null,
        val frozen: Double? = null,
        val withdrawn: Double? = null,
        val debt: Double? = null
    )

    @Serializable
    data class Stats(
        val totalCommission: Double? = null,
        val receivableCommission: Double? = null,
        val applyingCommission: Double? = null,
        val settledCommission: Double? = null
    )

    @Serializable
    data class StudioGroup(
        val studioId: String? = null,
        val receivable: Double? = null,
        val applying: Double? = null,
        val settled: Double? = null,
        val total: Double? = null,
        val name: String? = null,
        val cover: String? = null
    )

    @Serializable
    data class CommissionSummary(
        val period: Period? = null,
        val wallet: WalletInfo? = null,
        val stats: Stats? = null,
        val studios: List<StudioGroup>? = null
    )

    /** 收益总览（含按工作室分组），startDate/endDate 格式 yyyy-MM-dd */
    suspend fun fetchSummary(startDate: String? = null, endDate: String? = null): CommissionSummary {
        val params = mutableMapOf<String, Any>()
        startDate?.let { params["start_date"] = it }
        endDate?.let { params["end_date"] = it }
        return ApiService.get("/distribution/commission/summary", params).decode<CommissionSummary>()
    }

    // MARK: - 佣金领取单

    @Serializable
    data class UserBrief(
        val userId: String? = null,
        val nickname: String? = null,
        val phone: String? = null
    )

    @Serializable
    data class StudioBrief(
        val studioId: String? = null,
        val name: String? = null,
        val cover: String? = null
    )

    @Serializable
    data class CommissionBrief(
        val commissionId: String? = null,
        val orderId: String? = null,
        val amount: Double? = null,
        val rate: Double? = null,
        val status: Int? = null,
        val statusText: String? = null,
        val createdAt: String? = null
    )

    @Serializable
    data class Step(
        val title: String? = null,
        val done: Boolean? = null,
        val current: Boolean? = null
    )

    @Serializable
    data class CommissionWithdrawal(
        val withdrawId: String? = null,
        val user: UserBrief? = null,
        val studio: StudioBrief? = null,
        val amount: Double? = null,
        val amountText: String? = null,
        val method: String? = null,
        val methodText: String? = null,
        val account: String? = null,
        /** 0 待工作室审核 / 1 待推广人确认 / 2 已驳回 / 3 已完成 */
        val status: Int? = null,
        val statusText: String? = null,
        val voucherImages: List<String>? = null,
        val rejectReason: String? = null,
        val createdAt: String? = null,
        val processedAt: String? = null,
        val confirmedAt: String? = null,
        val canConfirm: Boolean? = null,
        val commissions: List<CommissionBrief>? = null,
        val steps: List<Step>? = null
    )

    /** 发起领取：一次领取某工作室全部「待申请」佣金 */
    suspend fun requestWithdraw(studioId: String, method: String): CommissionWithdrawal {
        return ApiService.post("/distribution/commission/withdraw", mapOf(
            "studio_id" to studioId, "method" to method
        )).decode<CommissionWithdrawal>()
    }

    /** 领取单列表（分页）→ (items, hasMore) */
    suspend fun fetchWithdrawals(page: Int, pageSize: Int = 20): Pair<List<CommissionWithdrawal>, Boolean> {
        val json = ApiService.get("/distribution/commission/withdrawals", mapOf(
            "page" to page, "page_size" to pageSize
        ))
        val items = json.decodeList<CommissionWithdrawal>("list")
        val total = json.int("total")
        return items to (page * pageSize < total)
    }

    /** 领取单详情 */
    suspend fun fetchWithdrawalDetail(id: String): CommissionWithdrawal {
        return ApiService.get("/distribution/commission/withdrawals/$id").decode<CommissionWithdrawal>()
    }

    /** 推广人确认已在线下收到佣金（status=1 → 3） */
    suspend fun confirmWithdrawal(id: String): CommissionWithdrawal {
        return ApiService.post("/distribution/commission/withdrawals/$id/confirm").decode<CommissionWithdrawal>()
    }

    // MARK: - 佣金明细

    @Serializable
    data class CourseBrief(
        val courseId: String? = null,
        val title: String? = null,
        val cover: String? = null
    )

    @Serializable
    data class CommissionRecordItem(
        val commissionId: String? = null,
        val orderId: String? = null,
        val amount: Double? = null,
        val rate: Double? = null,
        val status: Int? = null,
        val statusText: String? = null,
        val createdAt: String? = null,
        val studio: StudioBrief? = null,
        val course: CourseBrief? = null
    )

    /** 佣金明细（可按工作室过滤） */
    suspend fun fetchRecords(studioId: String? = null): List<CommissionRecordItem> {
        val params = mutableMapOf<String, Any>("page_size" to 100)
        studioId?.let { params["studio_id"] = it }
        return ApiService.get("/distribution/commission/records", params).decodeList("list")
    }

    // MARK: - 工具

    /** 金额格式化：¥12.34 */
    fun yuan(value: Double?): String = String.format("¥%.2f", value ?: 0.0)

    /** ISO 时间 → "MM-dd HH:mm" */
    fun fmtTime(iso: String?): String {
        if (iso.isNullOrBlank()) return ""
        return try {
            val input = java.time.OffsetDateTime.parse(iso)
            val out = java.time.format.DateTimeFormatter.ofPattern("MM-dd HH:mm")
            input.format(out)
        } catch (_: Exception) {
            try {
                val input = java.time.LocalDateTime.parse(iso)
                val out = java.time.format.DateTimeFormatter.ofPattern("MM-dd HH:mm")
                input.format(out)
            } catch (_: Exception) { iso }
        }
    }

    /** ISO 时间 → "yyyy-MM-dd HH:mm" */
    fun fmtFull(iso: String?): String {
        if (iso.isNullOrBlank()) return "-"
        return try {
            val input = java.time.OffsetDateTime.parse(iso)
            val out = java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")
            input.format(out)
        } catch (_: Exception) {
            try {
                val input = java.time.LocalDateTime.parse(iso)
                val out = java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")
                input.format(out)
            } catch (_: Exception) { iso }
        }
    }
}

// MARK: - 线下收款方式

data class PayMethodOption(val value: String, val label: String) {
    companion object {
        val all = listOf(
            PayMethodOption("wechat", "微信转账"),
            PayMethodOption("alipay", "支付宝转账"),
            PayMethodOption("bank", "银行转账"),
            PayMethodOption("qrcode", "收款码"),
            PayMethodOption("cash", "现金"),
            PayMethodOption("other", "其他")
        )
    }
}