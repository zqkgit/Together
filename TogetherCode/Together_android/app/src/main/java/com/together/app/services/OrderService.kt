package com.together.app.services

import com.together.app.core.model.OrderItem
import com.together.app.core.model.RefundDetail
import com.together.app.core.network.ApiService
import com.together.app.core.network.JsonHelper.decode
import com.together.app.core.network.JsonHelper.decodeList
import com.together.app.core.network.JsonHelper.double
import com.together.app.core.network.JsonHelper.obj

/**
 * 家长端订单服务
 * 对齐 iOS OrderService.swift
 */
object OrderService {

    /** 我的订单列表（status 传 null = 全部） */
    suspend fun fetchOrders(status: Int? = null): List<OrderItem> {
        val params = mutableMapOf<String, Any?>()
        status?.let { params["status"] = it }
        return ApiService.get("/orders", params).decodeList<OrderItem>("list")
    }

    /** 订单详情 */
    suspend fun fetchOrderDetail(orderId: String): OrderItem? {
        return ApiService.get("/orders/$orderId").decode<OrderItem>()
    }

    /** 取消待收款订单 */
    suspend fun cancelOrder(orderId: String) {
        ApiService.post("/orders/$orderId/cancel")
    }

    /** 提交线下付款凭证 */
    suspend fun submitPaymentVoucher(
        orderId: String,
        payMethod: String,
        voucherImages: List<String>,
        note: String? = null
    ) {
        val params = mutableMapOf<String, Any?>(
            "pay_method" to payMethod,
            "voucher_images" to voucherImages
        )
        note?.takeIf { it.isNotEmpty() }?.let { params["note"] = it }
        ApiService.post("/orders/$orderId/payment-voucher", params)
    }

    /** 艺启余额（返利钱包余额，单位元） */
    suspend fun fetchWalletBalance(): Double {
        val json = ApiService.get("/distribution/commission/summary")
        return json.obj("wallet").double("balance")
    }

    /** 退款详情（状态流转） */
    suspend fun fetchRefundDetail(refundId: String): RefundDetail? {
        return ApiService.get("/orders/refunds/$refundId").decode<RefundDetail>()
    }

    /** 家长确认已在线下收到退款 */
    suspend fun confirmRefund(refundId: String): RefundDetail? {
        return ApiService.post("/orders/refunds/$refundId/confirm").decode<RefundDetail>()
    }

    /** 申请退款 */
    suspend fun requestRefund(orderId: String, lessons: Int, reason: String? = null) {
        val params = mutableMapOf<String, Any?>("lessons" to lessons)
        reason?.takeIf { it.isNotEmpty() }?.let { params["reason"] = it }
        ApiService.post("/orders/$orderId/refunds", params)
    }
}