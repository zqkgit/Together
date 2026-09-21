import Foundation
import Alamofire

// MARK: - 工作室「我的」模型

/// 工作室机构资料（GET /studio/mine → profile）
struct StudioMineProfile: Codable {
    let studio_id: String?
    let user_id: String?
    let name: String?
    let cover: String?
    let avatar: String?
    let intro: String?
    let city: String?
    let address: String?
    let business_type: String?
    let type_tags: [String]?
    let phone: String?
    /// 1 已通过平台认证（正常运营）
    let cert_status: Int?
    let status: Int?
    let joined_at: String?
    let years: Int?
    let months: Int?

    var displayName: String {
        guard let name, !name.isEmpty else { return "未命名工作室" }
        return name
    }

    var isCertified: Bool { (cert_status ?? 0) == 1 }

    /// 业务类型标签文案（如「少儿美术 / 书法」）
    var tagsText: String {
        let tags = (type_tags ?? []).filter { !$0.isEmpty }
        if !tags.isEmpty { return tags.joined(separator: " / ") }
        guard let business_type, !business_type.isEmpty else { return "" }
        return business_type
    }

    /// 入驻时长文案（入驻 2 年 / 入驻 3 个月 / 新入驻）
    var entryText: String {
        let y = years ?? 0
        if y >= 1 { return "入驻 \(y) 年" }
        let m = months ?? 0
        if m >= 1 { return "入驻 \(m) 个月" }
        return "新入驻"
    }

    /// 封面副标题：认证状态 · 业务类型 · 入驻时长
    var subtitle: String {
        var parts: [String] = []
        if isCertified { parts.append("已认证机构") }
        let tags = tagsText
        if !tags.isEmpty { parts.append(tags) }
        parts.append(entryText)
        return parts.joined(separator: " · ")
    }
}

/// 工作室经营统计（GET /studio/mine → stats）
struct StudioMineStats: Codable {
    let active_students: Int?
    let online_courses: Int?
    let course_total: Int?
    let teachers: Int?
    let pending_refunds: Int?

    static let empty = StudioMineStats(
        active_students: nil,
        online_courses: nil,
        course_total: nil,
        teachers: nil,
        pending_refunds: nil
    )

    var activeStudents: Int { active_students ?? 0 }
    var onlineCourses: Int { online_courses ?? 0 }
    var courseTotal: Int { course_total ?? 0 }
    var teacherCount: Int { teachers ?? 0 }
    var pendingRefunds: Int { pending_refunds ?? 0 }
}

struct StudioMineData: Codable {
    let profile: StudioMineProfile?
    let stats: StudioMineStats?
}

// MARK: - 工作室数据服务

/// 工作室端（角色 3）App 接口：/v1/studio/*
enum StudioService {

    /// 工作室「我的」：机构资料 + 经营统计
    static func fetchMine(completion: @escaping (Result<StudioMineData, APIError>) -> Void) {
        APIClient.shared.request("/studio/mine", method: .get) { result in
            switch result {
            case .success(let json):
                let data = JSONKit.decode(StudioMineData.self, from: json)
                    ?? StudioMineData(profile: nil, stats: nil)
                completion(.success(data))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
