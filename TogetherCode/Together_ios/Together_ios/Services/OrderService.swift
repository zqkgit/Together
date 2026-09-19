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

    /// 取消待支付订单
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

    /// 支付订单（channel: wechat_mini / ios_iap / offline；childId 可选：支付时切换上课孩子）
    static func payOrder(orderId: String, channel: String, childId: String? = nil, completion: @escaping (Result<Void, APIError>) -> Void) {
        var parameters: [String: Any] = ["channel": channel]
        if let childId, !childId.isEmpty {
            parameters["child_id"] = childId
        }
        APIClient.shared.request(
            "/orders/\(orderId)/pay",
            method: .post,
            parameters: parameters
        ) { result in
            switch result {
            case .success:
                // 统计：支付成功
                AnalyticsManager.shared.event("order_pay_success", params: ["channel": channel])
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
