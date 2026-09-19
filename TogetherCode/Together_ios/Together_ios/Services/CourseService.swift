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

    /// 创建订单（报名：课程固定课时与价格 + 选择班级）
    static func createOrder(
        childId: String,
        courseId: String,
        classId: String? = nil,
        distributionCode: String? = nil,
        completion: @escaping (String?, String?) -> Void
    ) {
        var parameters: [String: Any] = [
            "child_id": childId,
            "course_id": courseId
        ]
        if let classId, !classId.isEmpty {
            parameters["class_id"] = classId
        }
        if let code = distributionCode, !code.isEmpty {
            parameters["distribution_code"] = code
        }
        APIClient.shared.request("/orders", method: .post, parameters: parameters) { result in
            switch result {
            case .success(let json):
                // json 已是 data 层（APIClient 已解包）
                let orderId = json["order_id"].string
                // 统计：下单成功
                AnalyticsManager.shared.event("order_create", params: ["course_id": courseId])
                completion(orderId, nil)
            case .failure(let error):
                completion(nil, error.message)
            }
        }
    }

    /// 课程评价（详情页家长评价）
    static func fetchReviews(
        courseId: String,
        completion: @escaping ([CourseReviewItem], String?) -> Void
    ) {
        APIClient.shared.request("/courses/\(courseId)/reviews", method: .get) { result in
            switch result {
            case .success(let json):
                completion(JSONKit.decodeList([CourseReviewItem].self, from: json["list"]), nil)
            case .failure(let error):
                completion([], error.message)
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

    /// 提交请假（家长端）
    static func submitLeave(
        classId: String,
        childId: String,
        scheduleId: String?,
        reason: String,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        var params: [String: Any] = [
            "class_id": classId,
            "child_id": childId,
            "reason": reason
        ]
        if let scheduleId, !scheduleId.isEmpty {
            params["schedule_id"] = scheduleId
        }
        APIClient.shared.request("/leave", method: .post, parameters: params) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 我的请假单（家长端）
    struct MyLeaveItem: Codable {
        let leave_id: String?
        let schedule_id: String?
        let child_id: String?
        let status: Int?
        /// 补课状态：0=待补课(已安排/未安排) 1=已完成 2=已放弃
        let makeup_status: Int?
        /// 补课排课信息
        let makeup_schedule: MakeupSchedule?

        struct MakeupSchedule: Codable {
            let schedule_id: String?
            let lesson_date: String?
            let start_time: String?
            let end_time: String?
            let location: String?
        }
    }

    /// 我的请假列表
    static func fetchMyLeaves(completion: @escaping (Result<[MyLeaveItem], APIError>) -> Void) {
        APIClient.shared.request(
            "/leave",
            method: .get,
            parameters: ["page": 1, "page_size": 50],
            encoding: URLEncoding.default
        ) { result in
            switch result {
            case .success(let json):
                let list = JSONKit.decode([MyLeaveItem].self, from: json["list"]) ?? []
                completion(.success(list))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 撤销请假（仅待审批可撤销）
    static func cancelLeave(leaveId: String, completion: @escaping (Result<Void, APIError>) -> Void) {
        APIClient.shared.request(
            "/leave/\(leaveId)/cancel",
            method: .put,
            parameters: [:]
        ) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
