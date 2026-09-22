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

// MARK: - 学员管理模型

/// 学员筛选（对应接口 filter）
enum StudioStudentFilter: String, CaseIterable {
    case all
    case renew
    case new

    var title: String {
        switch self {
        case .all: return "全部"
        case .renew: return "待续费"
        case .new: return "本月新增"
        }
    }

    var emptyText: String {
        switch self {
        case .all: return "暂无学员"
        case .renew: return "暂无待续费学员"
        case .new: return "本月暂无新增学员"
        }
    }
}

/// 学员统计（GET /studio/students → summary）
/// 口径：工作室全量学员，不随筛选 / 搜索变化
struct StudioStudentSummary: Codable {
    let all: Int?
    let renew: Int?
    let newCount: Int?

    private enum CodingKeys: String, CodingKey {
        case all
        case renew
        case newCount = "new"
    }

    static let empty = StudioStudentSummary(all: nil, renew: nil, newCount: nil)

    func count(for filter: StudioStudentFilter) -> Int {
        switch filter {
        case .all: return all ?? 0
        case .renew: return renew ?? 0
        case .new: return newCount ?? 0
        }
    }
}

/// 工作室学员（GET /studio/students → list）
struct StudioStudentItem: Codable {
    let child_id: String
    let nickname: String?
    let avatar: String?
    let gender: Int?
    let age: Int?
    let birthday: String?
    let course_title: String?
    let course_count: Int?
    let parent_name: String?
    let parent_phone: String?
    let remaining_lessons: Int?
    let total_lessons: Int?
    let consumed_lessons: Int?
    let renew: Bool?
    let is_new: Bool?
    let enrolled_at: String?
    let status: String?

    var displayName: String {
        guard let nickname, !nickname.isEmpty else { return "未命名学员" }
        return nickname
    }

    /// 待续费（剩余课时 ≤ 3，含课时耗尽）
    var isRenew: Bool { renew ?? false }

    var remaining: Int { remaining_lessons ?? 0 }

    /// 副标题：6 岁 · 森林水彩启蒙 · 家长：林女士（设计稿口径，课程取最近报名的一门）
    var subtitle: String {
        var parts: [String] = []
        if let age { parts.append("\(age) 岁") }
        if let title = course_title, !title.isEmpty { parts.append(title) }
        if let parent = parent_name, !parent.isEmpty { parts.append("家长：\(parent)") }
        return parts.joined(separator: " · ")
    }

    /// 剩余课时数文案（右侧大字）
    var lessonsText: String { "\(remaining) 节" }

    /// 右侧小字：待续费 / 剩余课时
    var lessonsCaption: String { isRenew ? "待续费" : "剩余课时" }

    /// 报名时间（yyyy-MM-dd）
    var enrolledText: String {
        guard let enrolled_at, enrolled_at.count >= 10 else { return "—" }
        return String(enrolled_at.prefix(10))
    }

    var genderText: String {
        switch gender {
        case 1: return "男孩"
        case 2: return "女孩"
        default: return "未填"
        }
    }
}

struct StudioStudentPage: Codable {
    let summary: StudioStudentSummary?
    let total: Int?
    let list: [StudioStudentItem]?
}

/// 学员详情：单门课程课时账本
struct StudioStudentBalance: Codable {
    let balance_id: String?
    let course_id: String?
    let course_title: String?
    let total_lessons: Int?
    let consumed_lessons: Int?
    let remaining_lessons: Int?
    let valid_from: String?
    let valid_to: String?
    let order_created_at: String?

    var titleText: String {
        guard let course_title, !course_title.isEmpty else { return "课程" }
        return course_title
    }
    var remainingText: String { "\(remaining_lessons ?? 0) 节" }
    var detailText: String {
        "共 \(total_lessons ?? 0) 节 · 已消耗 \(consumed_lessons ?? 0) 节"
    }
    var validityText: String {
        guard let from = valid_from, from.count >= 10 else { return "" }
        let start = String(from.prefix(10))
        guard let to = valid_to, to.count >= 10 else { return "有效期：\(start) 起" }
        return "有效期：\(start) ~ \(String(to.prefix(10)))"
    }
}

/// 学员课时流水
struct StudioStudentLog: Codable {
    let log_id: String?
    let course_id: String?
    let course_title: String?
    let lesson_date: String?
    let start_time: String?
    let end_time: String?
    let is_makeup: Bool?
    let source: Int?
    let delta: Int?
    let balance_after: Int?
    let note: String?
    let created_at: String?

    /// 0 课时到账 / 1 出勤打卡 / 2 排课消课 / 3 手动消课 / 4 退款扣减
    var sourceText: String {
        switch source ?? 0 {
        case 0: return "课时到账"
        case 1: return "出勤打卡"
        case 2: return "排课消课"
        case 3: return "手动消课"
        case 4: return "退款扣减"
        default: return "其他"
        }
    }

    var deltaText: String {
        let value = delta ?? 0
        return "\(value > 0 ? "+" : "")\(value) 节"
    }

    var isIncrease: Bool { (delta ?? 0) > 0 }

    var dateText: String {
        if let lesson_date, lesson_date.count >= 10 { return String(lesson_date.prefix(10)) }
        if let created_at, created_at.count >= 10 { return String(created_at.prefix(10)) }
        return "—"
    }

    var timeText: String {
        guard let start_time, let end_time, !start_time.isEmpty else { return "" }
        return "\(start_time)~\(end_time)"
    }

    var titleText: String {
        guard let course_title, !course_title.isEmpty else { return "课程" }
        return course_title
    }
}

struct StudioStudentDetail: Codable {
    let student: StudioStudentItem?
    let balances: [StudioStudentBalance]?
    let logs: [StudioStudentLog]?
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

    // MARK: - 课程管理

    /// 本工作室课程列表。status: 0 审核中 / 1 在售 / 2 已下架；nil 为全部。
    static func fetchCourses(status: Int?, completion: @escaping (Result<[StudioCourseItem], APIError>) -> Void) {
        var params: [String: Any]?
        if let status { params = ["status": status] }
        APIClient.shared.request("/studio/courses", method: .get, parameters: params) { result in
            switch result {
            case .success(let json):
                let page = JSONKit.decode(StudioCoursePage.self, from: json)
                completion(.success(page?.list ?? []))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 上架 / 下架课程。status: 1 在售 / 2 已下架。
    static func setCourseStatus(courseId: String, status: Int, completion: @escaping (Result<Void, APIError>) -> Void) {
        APIClient.shared.request("/studio/courses/\(courseId)/status", method: .patch, parameters: ["status": status]) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 学员管理

    /// 学员列表。filter：all 全部 / renew 待续费(剩余≤3) / new 本月新增；keyword 昵称或家长模糊
    static func fetchStudents(
        filter: StudioStudentFilter,
        keyword: String? = nil,
        completion: @escaping (Result<StudioStudentPage, APIError>) -> Void
    ) {
        var params: [String: Any] = ["filter": filter.rawValue]
        let trimmed = keyword?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { params["q"] = trimmed }
        APIClient.shared.request("/studio/students", method: .get, parameters: params) { result in
            switch result {
            case .success(let json):
                let page = JSONKit.decode(StudioStudentPage.self, from: json)
                completion(.success(page ?? StudioStudentPage(summary: nil, total: 0, list: [])))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 学员详情：学员信息 + 各课程课时余额 + 课时流水
    static func fetchStudentDetail(childId: String, completion: @escaping (Result<StudioStudentDetail, APIError>) -> Void) {
        APIClient.shared.request("/studio/students/\(childId)", method: .get) { result in
            switch result {
            case .success(let json):
                let detail = JSONKit.decode(StudioStudentDetail.self, from: json)
                completion(.success(detail ?? StudioStudentDetail(student: nil, balances: [], logs: [])))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}


// MARK: - 课程管理模型

struct StudioCourseTeacher: Codable {
    let teacher_id: String?
    let real_name: String?
}

struct StudioCourseItem: Codable {
    let course_id: String
    let title: String?
    let cover: String?
    let age_min: Int?
    let age_max: Int?
    let total_lessons: Int?
    let price: Int?
    let sales: Int?
    let status: Int?
    let teacher: StudioCourseTeacher?

    var teacherName: String { teacher?.real_name ?? "" }
    var hasTeacher: Bool {
        if let n = teacher?.real_name, !n.isEmpty { return true }
        return false
    }
    var lessonsText: String { "\(total_lessons ?? 0) 节" }
    var salesText: String { "已售 \(sales ?? 0)" }

    var ageText: String {
        if let mn = age_min, let mx = age_max, mx > mn { return "\(mn)-\(mx)岁" }
        if let mn = age_min { return "\(mn)岁+" }
        if let mx = age_max { return "\(mx)岁以内" }
        return "适龄"
    }

    /// 价格单位为分；整元显示整数带千分位，否则两位小数
    var priceText: String {
        guard let fen = price else { return "¥0" }
        let yuan = Double(fen) / 100.0
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.maximumFractionDigits = 2
        fmt.minimumFractionDigits = fen % 100 == 0 ? 0 : 2
        return "¥" + (fmt.string(from: NSNumber(value: yuan)) ?? "0")
    }
}

struct StudioCoursePage: Codable {
    let total: Int?
    let list: [StudioCourseItem]?
}
