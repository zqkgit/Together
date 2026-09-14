import Foundation
import Alamofire
import SwiftyJSON

/// 「我的」页数据：用户资料 + 三项统计
struct MineUser: Codable {
    let user_id: String?
    let nickname: String?
    let avatar: String?
    let city: String?
}

struct MineProfile: Codable {
    let user: MineUser?
    let current_role: Int?
    let roles: [Int]?

    /// 是否已开通某角色（1 家长 / 2 老师 / 3 工作室）
    func hasRole(_ role: Int) -> Bool {
        roles?.contains(role) ?? false
    }
}

/// 头部统计
/// 口径：孩子数 = /children total；在学课程数 = 所有孩子课包 course_id 去重；收藏数 = /favorites total
struct MineStats {
    var childrenCount = 0
    var courseCount = 0
    var favoriteCount = 0
}

/// 「我的」页数据服务
enum MineService {

    static func fetchMe(completion: @escaping (Result<MineProfile, APIError>) -> Void) {
        APIClient.shared.request("/auth/me", method: .get) { result in
            switch result {
            case .success(let json):
                let profile = JSONKit.decode(MineProfile.self, from: json)
                    ?? MineProfile(user: nil, current_role: 1, roles: [1])
                completion(.success(profile))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 并行聚合三项统计（任一失败不阻塞其余，全部返回后回调）
    static func fetchStats(completion: @escaping (MineStats) -> Void) {
        let group = DispatchGroup()
        var stats = MineStats()

        group.enter()
        APIClient.shared.request("/children", method: .get) { result in
            defer { group.leave() }
            if case .success(let json) = result {
                stats.childrenCount = json["total"].int ?? JSONKit.decodeList([ChildItem].self, from: json).count
                // 在学课程 = 所有孩子课包 course_id 去重
                let children = JSONKit.decodeList([ChildItem].self, from: json)
                stats.courseCount = Set(children.flatMap { $0.balances?.compactMap { $0.course_id } ?? [] }).count
            }
        }

        group.enter()
        APIClient.shared.request("/favorites", method: .get,
                                 parameters: ["page": 1, "page_size": 1],
                                 encoding: URLEncoding.default) { result in
            defer { group.leave() }
            if case .success(let json) = result {
                stats.favoriteCount = json["total"].int ?? 0
            }
        }

        group.notify(queue: .main) {
            completion(stats)
        }
    }
}
