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

// MARK: - 我的课程（列表 + 课时进度）

    /// 我的课程（childId 为 nil 时返回所有孩子的课程 + 筛选用 children 数组）
    static func fetchMyCourses(
        childId: String? = nil,
        completion: @escaping (Result<([ChildBrief], [MyCourseItem]), APIError>) -> Void
    ) {
        var parameters: [String: Any] = [:]
        if let childId, !childId.isEmpty {
            parameters["child_id"] = childId
        }
        APIClient.shared.request(
            "/parent/my-courses",
            method: .get,
            parameters: parameters,
            encoding: URLEncoding.default
        ) { result in
            switch result {
            case .success(let json):
                let children = JSONKit.decodeList([ChildBrief].self, from: json["children"])
                let list = JSONKit.decodeList([MyCourseItem].self, from: json["list"])
                completion(.success((children, list)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 课时进度（课程详情下的排课 + 出勤状态）
    static func fetchCourseSchedules(
        childId: String,
        courseId: String,
        completion: @escaping (Result<CourseScheduleSummary, APIError>) -> Void
    ) {
        APIClient.shared.request(
            "/parent/course-schedules",
            method: .get,
            parameters: ["child_id": childId, "course_id": courseId],
            encoding: URLEncoding.default
        ) { result in
            switch result {
            case .success(let json):
                completion(.success(JSONKit.decode(CourseScheduleSummary.self, from: json) ?? CourseScheduleSummary()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
