import Foundation
import Alamofire
import SwiftyJSON

/// 孩子作品（帖子归档）
struct ChildWorkItem: Codable {
    let post_id: String?
    let content: String?
    let images: [String]?
    let course_title: String?
}

/// 成长动态（时间线事件：消课/发课/退款/作品）
struct ChildGrowthEvent: Codable {
    let event_id: String?
    let event_type: String?
    let course_title: String?
    let studio_name: String?
    let note: String?
    let occurred_at: String?
    let delta: Int?
    let post: ChildWorkItem?

    /// 动态标题（老师/来源）
    var sourceName: String { studio_name ?? "成长记录" }

    /// 动态正文：优先老师备注，其次作品内容
    var bodyText: String {
        if let note, !note.isEmpty { return note }
        return post?.content ?? "记录了新的成长瞬间"
    }
}

/// 孩子模块数据服务
enum ChildService {

    static func fetchChildren(completion: @escaping (Result<[ChildItem], APIError>) -> Void) {
        APIClient.shared.request("/children", method: .get) { result in
            switch result {
            case .success(let json):
                completion(.success(JSONKit.decodeList([ChildItem].self, from: json)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 孩子作品列表（帖子归档）
    static func fetchChildWorks(childId: String, completion: @escaping (Result<[ChildWorkItem], APIError>) -> Void) {
        APIClient.shared.request("/children/\(childId)/works", method: .get) { result in
            switch result {
            case .success(let json):
                completion(.success(JSONKit.decodeList([ChildWorkItem].self, from: json)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 成长动态时间线（接口返回 timeline 字段）
    static func fetchChildGrowth(childId: String, completion: @escaping (Result<[ChildGrowthEvent], APIError>) -> Void) {
        APIClient.shared.request("/children/\(childId)/growth", method: .get) { result in
            switch result {
            case .success(let json):
                completion(.success(JSONKit.decodeList([ChildGrowthEvent].self, from: json["timeline"])))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 添加孩子（avatar 传 emoji 字符 / OSS URL 均可）
    static func createChild(
        nickname: String,
        avatar: String?,
        birthday: String,
        gender: Int,
        interests: [String],
        completion: @escaping (Result<ChildItem, APIError>) -> Void
    ) {
        var parameters: [String: Any] = [
            "nickname": nickname,
            "birthday": birthday,
            "gender": gender
        ]
        if let avatar, !avatar.isEmpty { parameters["avatar"] = avatar }
        if !interests.isEmpty { parameters["interests"] = interests.joined(separator: ",") }

        APIClient.shared.request("/children", method: .post, parameters: parameters) { result in
            switch result {
            case .success(let json):
                completion(.success(JSONKit.decode(ChildItem.self, from: json) ?? ChildItem(
                    child_id: "", nickname: nickname, avatar: avatar, birthday: birthday,
                    gender: gender, interests: interests, total_remaining_lessons: 0, balances: nil)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 课时明细

    /// 课时余额列表（某孩子的所有课包）
    static func fetchChildBalances(childId: String, completion: @escaping (Result<[ChildBalance], APIError>) -> Void) {
        APIClient.shared.request("/parent/balances", method: .get) { result in
            switch result {
            case .success(let json):
                let children = JSONKit.decodeList([ChildBalanceChild].self, from: json["children"])
                let target = children.first(where: { $0.child_id == childId })
                completion(.success(target?.balances ?? []))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 消课记录
    static func fetchLessonLogs(childId: String, page: Int = 1, pageSize: Int = 50, completion: @escaping (Result<[LessonLogItem], APIError>) -> Void) {
        let params: [String: Any] = ["child_id": childId, "page": page, "page_size": pageSize]
        APIClient.shared.request("/parent/lesson-logs", method: .get, parameters: params) { result in
            switch result {
            case .success(let json):
                completion(.success(JSONKit.decodeList([LessonLogItem].self, from: json["list"])))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - 课时明细模型

/// 余额接口返回的孩子节点
private struct ChildBalanceChild: Codable {
    let child_id: String
    let balances: [ChildBalance]?
}

/// 消课记录
struct LessonLogItem: Codable {
    let log_id: String?
    let child_name: String?
    let course_title: String?
    let studio_name: String?
    let lesson_date: String?
    let start_time: String?
    let is_makeup: Bool?
    let delta: Int?
    let note: String?
}
