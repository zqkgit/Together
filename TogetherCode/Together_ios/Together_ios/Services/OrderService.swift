import Foundation
import Alamofire
import SwiftyJSON

/// 家长端订单服务
enum OrderService {

    /// 我的订单列表（status 传 nil = 全部）
    static func fetchOrders(status: Int? = nil, completion: @escaping (Result<[OrderItem], APIError>) -> Void) {
        var parameters: [String: Any] = [:]
        if let status {
            parameters["status"] = status
        }
        APIClient.shared.request(
            "/orders",
            method: .get,
            parameters: parameters,
            encoding: URLEncoding.default
        ) { result in
            switch result {
            case .success(let json):
                completion(.success(JSONKit.decodeList([OrderItem].self, from: json["list"])))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 订单详情
    static func fetchOrderDetail(orderId: String, completion: @escaping (Result<OrderItem, APIError>) -> Void) {
        APIClient.shared.request("/orders/\(orderId)", method: .get) { result in
            switch result {
            case .success(let json):
                if let item = JSONKit.decode(OrderItem.self, from: json) {
                    completion(.success(item))
                } else {
                    completion(.failure(.parse))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 取消待收款订单（机构尚未确认收款，可取消）
    static func cancelOrder(orderId: String, completion: @escaping (Result<Void, APIError>) -> Void) {
        APIClient.shared.request("/orders/\(orderId)/cancel", method: .post) { result in
            switch result {
            case .success:
                // 统计：取消订单
                AnalyticsManager.shared.event("order_cancel")
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

extension OrderService {

    /// 提交线下付款凭证（平台不经手资金；家长线下向机构付款后上传，机构核对确认后发课时）
    /// - Parameters:
    ///   - payMethod: 付款方式（cash 现金可免凭证；其余线上转账必传凭证图）
    ///   - voucherImages: 付款凭证图 OSS URL（≤9）
    ///   - note: 备注（可选）
    static func submitPaymentVoucher(
        orderId: String,
        payMethod: String,
        voucherImages: [String],
        note: String? = nil,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        var parameters: [String: Any] = [
            "pay_method": payMethod,
            "voucher_images": voucherImages
        ]
        if let note, !note.isEmpty {
            parameters["note"] = note
        }
        APIClient.shared.request(
            "/orders/\(orderId)/payment-voucher",
            method: .post,
            parameters: parameters
        ) { result in
            switch result {
            case .success:
                AnalyticsManager.shared.event("payment_voucher_submit", params: ["method": payMethod])
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 艺启余额（返利钱包余额，单位元）
    static func fetchWalletBalance(completion: @escaping (Result<Double, APIError>) -> Void) {
        APIClient.shared.request("/distribution/commission/summary", method: .get) { result in
            switch result {
            case .success(let json):
                completion(.success(json["wallet"]["balance"].doubleValue))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 退款详情（状态流转）
    static func fetchRefundDetail(refundId: String, completion: @escaping (Result<RefundDetail, APIError>) -> Void) {
        APIClient.shared.request("/orders/refunds/\(refundId)", method: .get) { result in
            switch result {
            case .success(let json):
                if let detail = JSONKit.decode(RefundDetail.self, from: json) {
                    completion(.success(detail))
                } else {
                    completion(.failure(.parse))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 家长确认已在线下收到退款（status=1 待确认 → 3 已退款，并扣减课时）；返回最新详情
    static func confirmRefund(refundId: String, completion: @escaping (Result<RefundDetail, APIError>) -> Void) {
        APIClient.shared.request("/orders/refunds/\(refundId)/confirm", method: .post) { result in
            switch result {
            case .success(let json):
                if let detail = JSONKit.decode(RefundDetail.self, from: json) {
                    completion(.success(detail))
                } else {
                    completion(.failure(.parse))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 申请退款
    static func requestRefund(orderId: String, lessons: Int, reason: String? = nil, completion: @escaping (Result<Void, APIError>) -> Void) {
        var parameters: [String: Any] = ["lessons": lessons]
        if let reason, !reason.isEmpty {
            parameters["reason"] = reason
        }
        APIClient.shared.request(
            "/orders/\(orderId)/refunds",
            method: .post,
            parameters: parameters
        ) { result in
            switch result {
            case .success:
                // 统计：申请退款
                AnalyticsManager.shared.event("refund_apply", params: ["lessons": lessons])
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
