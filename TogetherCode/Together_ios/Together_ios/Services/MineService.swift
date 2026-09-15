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

    // MARK: - 收益中心（艺启余额）

    /// 余额总览
    static func fetchWalletSummary(completion: @escaping (Result<WalletSummary, APIError>) -> Void) {
        APIClient.shared.request("/distribution/commission/summary", method: .get) { result in
            switch result {
            case .success(let json):
                let summary = JSONKit.decode(WalletSummary.self, from: json)
                    ?? WalletSummary(wallet: nil, stats: nil, withdrawable: 0)
                completion(.success(summary))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 返利明细（分页）
    static func fetchCommissionRecords(page: Int, pageSize: Int = 20, completion: @escaping (Result<CommissionPage, APIError>) -> Void) {
        APIClient.shared.request(
            "/distribution/commission/records",
            method: .get,
            parameters: ["page": page, "page_size": pageSize],
            encoding: URLEncoding.default
        ) { result in
            switch result {
            case .success(let json):
                let list = JSONKit.decodeList([CommissionRecordItem].self, from: json)
                completion(.success(CommissionPage(total: json["total"].int ?? 0, list: list)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 申请提现（余额 → 冻结，写提现单）
    static func requestWithdraw(amount: Double, method: String, account: String, completion: @escaping (Result<Void, APIError>) -> Void) {
        APIClient.shared.request(
            "/distribution/commission/withdraw",
            method: .post,
            parameters: ["amount": amount, "method": method, "account": account]
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

// MARK: - 收益中心模型

/// 余额总览
struct WalletSummary: Codable {
    struct WalletInfo: Codable {
        let balance: Double?
        let frozen: Double?
        let withdrawn: Double?
        let debt: Double?
    }
    struct WalletStats: Codable {
        let total_commission: Double?
        let settled_commission: Double?
        let pending_commission: Double?
        let total_withdrawn: Double?
    }
    let wallet: WalletInfo?
    let stats: WalletStats?
    let withdrawable: Double?
}

/// 返利明细单条
struct CommissionRecordItem: Codable {
    struct CourseBrief: Codable {
        let title: String?
    }
    let commission_id: String?
    let amount: Double?
    let status: Int?
    let created_at: String?
    let course: CourseBrief?
}

/// 返利分页结果
struct CommissionPage {
    let total: Int
    let list: [CommissionRecordItem]
}
