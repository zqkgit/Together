import Foundation
import Alamofire
import SwiftyJSON

/// 课程相关接口（报名闭环）
enum CourseService {

    /// 课程详情（含课包、工作室）
    static func fetchDetail(courseId: String, completion: @escaping (CourseDetail?, String?) -> Void) {
        APIClient.shared.request("/courses/\(courseId)", method: .get) { result in
            switch result {
            case .success(let json):
                completion(JSONKit.decode(CourseDetail.self, from: json), nil)
            case .failure(let error):
                completion(nil, error.message)
            }
        }
    }

    /// 我的孩子列表
    static func fetchChildren(completion: @escaping ([ChildItem], String?) -> Void) {
        APIClient.shared.request("/children", method: .get) { result in
            switch result {
            case .success(let json):
                completion(JSONKit.decodeList([ChildItem].self, from: json), nil)
            case .failure(let error):
                completion([], error.message)
            }
        }
    }

    /// 创建订单（报名）
    static func createOrder(
        childId: String,
        courseId: String,
        packageId: String,
        distributionCode: String? = nil,
        completion: @escaping (String?, String?) -> Void
    ) {
        var parameters: [String: Any] = [
            "child_id": childId,
            "course_id": courseId,
            "package_id": packageId
        ]
        if let code = distributionCode, !code.isEmpty {
            parameters["distribution_code"] = code
        }
        APIClient.shared.request("/orders", method: .post, parameters: parameters) { result in
            switch result {
            case .success(let json):
                let orderId = json["data"]["order_id"].string
                completion(orderId, nil)
            case .failure(let error):
                completion(nil, error.message)
            }
        }
    }
}
