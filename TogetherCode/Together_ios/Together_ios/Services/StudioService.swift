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

// MARK: - 工作室「经营概览」模型

/// 经营金额文案（设计稿口径：`¥ 86,420`，千分位、整数不带小数）
enum StudioAmount {
    /// 分 → 千分位数字（不带币种前缀），用于 `¥` 需单独排版的大字号场景
    static func groupedNumber(_ fen: Int) -> String {
        let yuan = Double(fen) / 100.0
        let isInteger = yuan == yuan.rounded()
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = isInteger ? 0 : 2
        return formatter.string(from: NSNumber(value: yuan)) ?? "0"
    }

    static func text(_ fen: Int) -> String {
        "¥ \(groupedNumber(fen))"
    }

    /// 带符号的增量文案（如 `+¥ 2,180`）
    static func signedText(_ fen: Int) -> String {
        "\(fen >= 0 ? "+" : "-")\(text(abs(fen)))"
    }
}

/// 营收卡（GET /studio/overview → revenue）
struct StudioOverviewRevenue: Codable {
    let month_income: Int?
    let withdrawable: Int?
    let distribution: Int?
    let settling: Int?

    static let empty = StudioOverviewRevenue(month_income: nil, withdrawable: nil, distribution: nil, settling: nil)

    var monthIncome: Int { month_income ?? 0 }
    var monthIncomeText: String { StudioAmount.text(monthIncome) }
    var withdrawableText: String { StudioAmount.text(withdrawable ?? 0) }
    var distributionText: String { StudioAmount.text(distribution ?? 0) }
    var settlingText: String { StudioAmount.text(settling ?? 0) }
}

/// 三项经营统计（GET /studio/overview → stats）
struct StudioOverviewStats: Codable {
    let active_students: Int?
    let online_courses: Int?
    let teachers: Int?

    static let empty = StudioOverviewStats(active_students: nil, online_courses: nil, teachers: nil)
}

/// 待办（GET /studio/overview → todos）
struct StudioOverviewTodos: Codable {
    let pending_refunds: Int?
    let pending_payouts: Int?
    let pending_settle_orders: Int?
    let pending_settle_amount: Int?

    static let empty = StudioOverviewTodos(pending_refunds: nil, pending_payouts: nil, pending_settle_orders: nil, pending_settle_amount: nil)

    var pendingRefunds: Int { pending_refunds ?? 0 }
    var pendingPayouts: Int { pending_payouts ?? 0 }
    var pendingSettleOrders: Int { pending_settle_orders ?? 0 }
    var pendingSettleAmountText: String { StudioAmount.text(pending_settle_amount ?? 0) }
}

/// 机构动态播报（GET /studio/overview → dynamic）
struct StudioOverviewDynamic: Codable {
    let studio_name: String?
    let today_enrolled: Int?
    let weekly_enrolled: Int?
    let weekly_income: Int?
    let distribution_ratio: Int?
    let headline: String?

    static let empty = StudioOverviewDynamic(
        studio_name: nil, today_enrolled: nil, weekly_enrolled: nil,
        weekly_income: nil, distribution_ratio: nil, headline: nil
    )

    var studioName: String {
        guard let studio_name, !studio_name.isEmpty else { return "我的工作室" }
        return studio_name
    }
    var todayEnrolled: Int { today_enrolled ?? 0 }
    var weeklyEnrolled: Int { weekly_enrolled ?? 0 }
    var weeklyIncome: Int { weekly_income ?? 0 }
    var weeklyIncomeText: String { StudioAmount.signedText(weeklyIncome) }
    var headlineText: String {
        guard let headline, !headline.isEmpty else { return "本周经营数据持续更新中。" }
        return headline
    }
}

struct StudioOverviewData: Codable {
    let revenue: StudioOverviewRevenue?
    let stats: StudioOverviewStats?
    let todos: StudioOverviewTodos?
    let dynamic: StudioOverviewDynamic?
}

// MARK: - 退款审核模型

/// 退款单关联的精简家长 / 孩子 / 课程 / 课时账户
struct StudioRefundParty: Codable {
    let user_id: String?
    let nickname: String?
    let avatar: String?
    let phone: String?
}
struct StudioRefundChild: Codable {
    let child_id: String?
    let nickname: String?
    let avatar: String?
}
struct StudioRefundCourse: Codable {
    let course_id: String?
    let title: String?
    let cover: String?
}
struct StudioRefundBalance: Codable {
    let total_lessons: Int?
    let consumed_lessons: Int?
    let remaining_lessons: Int?
}
struct StudioRefundOrder: Codable {
    let order_id: String?
    let order_no: String?
    let status: Int?
    let child: StudioRefundChild?
    let course: StudioRefundCourse?
    let user: StudioRefundParty?
    let balance: StudioRefundBalance?
}

/// 工作室退款单：status 0 申请中 / 1 待打款 / 2 已驳回 / 3 已打款；金额单位「分」
struct StudioRefund: Codable {
    let refund_id: String
    let order_id: String?
    let requested_lessons: Int?
    let refundable_lessons: Int?
    let unit_price: Int?
    let amount: Int?
    let reason: String?
    let status: Int
    let reviewed_at: String?
    let refunded_at: String?
    let created_at: String?
    let order: StudioRefundOrder?

    var amountFen: Int { amount ?? 0 }
    var parentName: String {
        if let n = order?.user?.nickname, !n.isEmpty { return n }
        if let c = order?.child?.nickname, !c.isEmpty { return c + "家长" }
        return "家长用户"
    }
    var parentAvatar: String? { order?.user?.avatar ?? order?.child?.avatar }
    var courseTitle: String { order?.course?.title ?? "课程" }
    var remaining: Int { order?.balance?.remaining_lessons ?? 0 }
    var totalLessons: Int { order?.balance?.total_lessons ?? 0 }
    var reasonText: String { reason ?? "" }

    /// 金额文案（两位小数，对齐设计稿 ¥440.00）
    var amountText: String {
        String(format: "¥%.2f", Double(amountFen) / 100.0)
    }
}

struct StudioRefundPage: Codable {
    let total: Int?
    let list: [StudioRefund]?
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

    /// 工作室「经营概览」：营收卡 + 三项统计 + 待办 + 机构动态
    static func fetchOverview(completion: @escaping (Result<StudioOverviewData, APIError>) -> Void) {
        APIClient.shared.request("/studio/overview", method: .get) { result in
            switch result {
            case .success(let json):
                let data = JSONKit.decode(StudioOverviewData.self, from: json)
                    ?? StudioOverviewData(revenue: nil, stats: nil, todos: nil, dynamic: nil)
                completion(.success(data))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: 退款审核

    /// 退款列表：status 0 申请中 / 1 待打款 / 2 已驳回 / 3 已打款；传 nil 为全部
    static func fetchRefunds(status: Int?, completion: @escaping (Result<[StudioRefund], APIError>) -> Void) {
        var params: [String: Any]?
        if let status { params = ["status": status] }
        APIClient.shared.request("/studio/refunds", method: .get, parameters: params) { result in
            switch result {
            case .success(let json):
                let page = JSONKit.decode(StudioRefundPage.self, from: json)
                completion(.success(page?.list ?? []))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 退款审核：action = approve 通过(→待打款) / reject 驳回(需 reason) / confirm 确认打款(→已打款)
    static func reviewRefund(
        refundId: String,
        action: String,
        reason: String? = nil,
        completion: @escaping (Result<StudioRefund?, APIError>) -> Void
    ) {
        var body: [String: Any] = ["action": action]
        if let reason, !reason.isEmpty { body["reason"] = reason }
        APIClient.shared.request("/studio/refunds/\(refundId)", method: .put, parameters: body) { result in
            switch result {
            case .success(let json):
                completion(.success(JSONKit.decode(StudioRefund.self, from: json)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
