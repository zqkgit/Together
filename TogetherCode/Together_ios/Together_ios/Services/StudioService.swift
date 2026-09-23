import Foundation
import Alamofire
import SwiftyJSON

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

/// 工作室退款单：status 0 待审核 / 1 待家长确认 / 2 已驳回 / 3 已退款；金额单位「分」
struct StudioRefund: Codable {
    let refund_id: String
    let order_id: String?
    let requested_lessons: Int?
    let approved_lessons: Int?
    let refundable_lessons: Int?
    let unit_price: Int?
    let amount: Int?
    let reason: String?
    let status: Int
    let refund_method: String?
    let voucher_images: [String]?
    let reject_reason: String?
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
    var voucherImageList: [String] { voucher_images ?? [] }
    var rejectReasonText: String { reject_reason ?? "" }

    /// 退款方式文案
    var refundMethodText: String {
        guard let m = refund_method, !m.isEmpty else { return "" }
        return PayMethodOption.all.first(where: { $0.value == m })?.label ?? m
    }

    /// 金额文案（两位小数，对齐设计稿 ¥440.00）
    var amountText: String {
        String(format: "¥%.2f", Double(amountFen) / 100.0)
    }

    /// 状态文案
    var statusText: String {
        switch status {
        case 0: return "待审核"
        case 1: return "待家长确认"
        case 2: return "已驳回"
        case 3: return "已退款"
        default: return "未知"
        }
    }

    /// 状态颜色
    var statusColor: UIColor {
        switch status {
        case 0: return Theme.Color.warn
        case 1: return Theme.Color.brand
        case 2: return Theme.Color.danger
        case 3: return Theme.Color.success
        default: return Theme.Color.muted
        }
    }

    /// 状态背景色
    var statusTintColor: UIColor {
        switch status {
        case 0: return Theme.Color.warnTint
        case 1: return Theme.Color.brandSoft
        case 2: return Theme.Color.dangerTint
        case 3: return Theme.Color.successTint
        default: return Theme.Color.bg
        }
    }
}

struct StudioRefundPage: Codable {
    let total: Int?
    let list: [StudioRefund]?
}

// MARK: - 银行卡模型

/// 银行卡列表分页
struct BankAccountPage: Codable {
    let total: Int?
    let list: [BankAccount]?
}

/// 银行卡账户
struct BankAccount: Codable {
    let account_id: String?
    let account_type: String?
    let account_name: String?
    let account_no: String?
    let bank_name: String?
    let is_default: Int?
    let status: Int?
    
    var accountId: String { account_id ?? "" }
    var accountType: String { account_type ?? "bank" }
    var accountName: String { account_name ?? "" }
    var accountNo: String { account_no ?? "" }
    var bankName: String { bank_name ?? "银行卡" }
    var isDefault: Int { is_default ?? 0 }
    
    /// 卡号后四位
    var lastFourDigits: String {
        String(accountNo.suffix(4))
    }
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

// MARK: - 老师管理模型

/// 老师管理统计（GET /studio/teachers → summary）
/// 口径：在职老师数 / 本工作室学员数 / 在职老师本月消课合计 / 待审合作申请
struct StudioTeacherSummary: Codable {
    let total_teachers: Int?
    let total_students: Int?
    let month_lessons: Int?
    let pending_applications: Int?

    static let empty = StudioTeacherSummary(
        total_teachers: nil,
        total_students: nil,
        month_lessons: nil,
        pending_applications: nil
    )

    var pendingCount: Int { pending_applications ?? 0 }
}

/// 在职老师（GET /studio/teachers → list）
struct StudioTeacherItem: Codable {
    let binding_id: String?
    let teacher_id: String
    let user_id: String?
    let real_name: String?
    let nickname: String?
    let avatar: String?
    let phone: String?
    let subjects: [String]?
    let years: Int?
    let intro: String?
    let cert_no: String?
    let cert_status: Int?
    let rating: Double?
    let bound_at: String?
    let course_count: Int?
    let student_count: Int?
    let month_lessons: Int?

    var displayName: String {
        guard let real_name, !real_name.isEmpty else { return "未命名老师" }
        return real_name
    }

    /// 副标题：水彩 / 硬笔书法 · 教龄 5 年
    var subtitle: String {
        var parts: [String] = []
        if let subjects, !subjects.isEmpty { parts.append(subjects.joined(separator: " / ")) }
        if let years { parts.append("教龄 \(years) 年") }
        return parts.isEmpty ? "暂未填写擅长方向" : parts.joined(separator: " · ")
    }

    var studentsText: String { "\(student_count ?? 0) 名学生" }

    var lessonsText: String { "月消课 \(month_lessons ?? 0) 节" }

    var isCertified: Bool { (cert_status ?? 0) == 1 }

    var ratingText: String { String(format: "%.1f", rating ?? 5) }

    var joinedText: String {
        guard let bound_at, bound_at.count >= 10 else { return "—" }
        return String(bound_at.prefix(10))
    }

    var yearsText: String {
        guard let years else { return "未填写" }
        return "\(years) 年"
    }

    var subjectsText: String {
        guard let subjects, !subjects.isEmpty else { return "暂未填写" }
        return subjects.joined(separator: " / ")
    }
}

struct StudioTeacherPage: Codable {
    let summary: StudioTeacherSummary?
    let total: Int?
    let list: [StudioTeacherItem]?
}

/// 老师在本工作室带的课程
struct StudioTeacherCourse: Codable {
    let course_id: String
    let title: String?
    let cover: String?
    let status: Int?
    let total_lessons: Int?
    let price: Int?
    let student_count: Int?
    let month_lessons: Int?

    var titleText: String {
        guard let title, !title.isEmpty else { return "课程" }
        return title
    }
    var isOnline: Bool { (status ?? 0) == 1 }
    var statusText: String { isOnline ? "在售" : "已下架" }
    var detailText: String { "共 \(total_lessons ?? 0) 节 · 本月消课 \(month_lessons ?? 0) 节" }
}

/// 老师名下的消课流水
struct StudioTeacherLog: Codable {
    let log_id: String?
    let created_at: String?
    let child_name: String?
    let course_title: String?
    let delta: Int?
    let balance_after: Int?
    let note: String?

    var dateText: String {
        guard let created_at, created_at.count >= 10 else { return "—" }
        return String(created_at.prefix(10))
    }
    var titleText: String {
        let name = child_name ?? "学员"
        let course = (course_title?.isEmpty == false) ? course_title! : "课程"
        return "\(name) · \(course)"
    }
    var deltaText: String {
        let value = delta ?? 0
        return value > 0 ? "+\(value)" : "\(value)"
    }
    var isIncrease: Bool { (delta ?? 0) > 0 }
    var detailText: String {
        var text = "剩余 \(balance_after ?? 0) 节"
        if let note, !note.isEmpty { text += " · \(note)" }
        return text
    }
}

struct StudioTeacherDetail: Codable {
    let teacher: StudioTeacherItem?
    let courses: [StudioTeacherCourse]?
    let logs: [StudioTeacherLog]?
}

/// 合作申请筛选
enum StudioTeacherApplicationFilter: String, CaseIterable {
    case pending
    case approved
    case rejected
    case all

    var title: String {
        switch self {
        case .pending: return "待处理"
        case .approved: return "已通过"
        case .rejected: return "已驳回"
        case .all: return "全部"
        }
    }

    /// 接口 status 参数（nil 为全部）
    var apiValue: Int? {
        switch self {
        case .pending: return 0
        case .approved: return 1
        case .rejected: return 2
        case .all: return nil
        }
    }

    var emptyText: String {
        switch self {
        case .pending: return "暂无待处理的合作申请"
        case .approved: return "暂无已通过的合作申请"
        case .rejected: return "暂无已驳回的合作申请"
        case .all: return "暂无老师合作申请"
        }
    }
}

struct StudioTeacherApplicationSummary: Codable {
    let pending: Int?
    let approved: Int?
    let rejected: Int?
    let total: Int?

    static let empty = StudioTeacherApplicationSummary(pending: nil, approved: nil, rejected: nil, total: nil)

    func count(for filter: StudioTeacherApplicationFilter) -> Int {
        switch filter {
        case .pending: return pending ?? 0
        case .approved: return approved ?? 0
        case .rejected: return rejected ?? 0
        case .all: return total ?? 0
        }
    }
}

struct StudioTeacherApplication: Codable {
    let id: String
    let user_id: String?
    let real_name: String?
    let nickname: String?
    let avatar: String?
    let phone: String?
    let subjects: [String]?
    let years: Int?
    let intro: String?
    let cert_no: String?
    let status: Int?
    let submitted_at: String?
    let reviewed_at: String?
    let review_reason: String?

    var displayName: String {
        guard let real_name, !real_name.isEmpty else { return "未命名老师" }
        return real_name
    }
    var isPending: Bool { (status ?? 0) == 0 }
    var statusText: String {
        switch status {
        case 0: return "待处理"
        case 1: return "已通过"
        case 2: return "已驳回"
        default: return "未知"
        }
    }
    var subtitle: String {
        var parts: [String] = []
        if let subjects, !subjects.isEmpty { parts.append(subjects.joined(separator: " / ")) }
        if let years { parts.append("教龄 \(years) 年") }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
    var submittedText: String {
        guard let submitted_at, submitted_at.count >= 10 else { return "—" }
        return String(submitted_at.prefix(10))
    }
}

struct StudioTeacherApplicationPage: Codable {
    let summary: StudioTeacherApplicationSummary?
    let total: Int?
    let list: [StudioTeacherApplication]?
}

/// 邀请老师成功后的回执（data.teacher）
struct StudioTeacherInviteResult: Codable {
    let binding_id: String?
    let status: Int?
    let teacher: StudioTeacherInviteTeacher?

    struct StudioTeacherInviteTeacher: Codable {
        let teacher_id: String?
        let user_id: String?
        let real_name: String?
    }

    var teacherName: String { teacher?.real_name ?? "老师" }
}

// MARK: - 订单管理模型

/// 订单状态：0 待收款 / 1 已收款 / 2 已取消 / 3 已退款
enum StudioOrderStatus: Int, CaseIterable {
    case pending = 0
    case paid = 1
    case cancelled = 2
    case refunded = 3

    var title: String {
        switch self {
        case .pending: return "待收款"
        case .paid: return "已收款"
        case .cancelled: return "已取消"
        case .refunded: return "已退款"
        }
    }

    /// 接口 status 参数（nil 为全部）
    var apiValue: Int? {
        // "全部" 传 nil
        return self.rawValue
    }

    var emptyText: String {
        switch self {
        case .pending: return "暂无待收款订单"
        case .paid: return "暂无已收款订单"
        case .cancelled: return "暂无已取消订单"
        case .refunded: return "暂无已退款订单"
        }
    }
}

/// 订单筛选（含"全部"选项）
enum StudioOrderFilter: Int, CaseIterable {
    case all = -1
    case pending = 0
    case paid = 1
    case cancelled = 2
    case refunded = 3

    var title: String {
        switch self {
        case .all: return "全部"
        case .pending: return "待收款"
        case .paid: return "已收款"
        case .cancelled: return "已取消"
        case .refunded: return "已退款"
        }
    }

    /// 接口 status 参数（nil 为全部）
    var apiValue: Int? {
        switch self {
        case .all: return nil
        default: return self.rawValue
        }
    }

    var emptyText: String {
        switch self {
        case .all: return "暂无订单"
        case .pending: return "暂无待收款订单"
        case .paid: return "暂无已收款订单"
        case .cancelled: return "暂无已取消订单"
        case .refunded: return "暂无已退款订单"
        }
    }
}

/// 订单关联的学员
struct StudioOrderChild: Codable {
    let child_id: String?
    let nickname: String?
    let birthday: String?

    var displayName: String { nickname ?? "学员" }
}

/// 订单关联的家长
struct StudioOrderUser: Codable {
    let user_id: String?
    let nickname: String?
    let phone: String?
    let avatar: String?

    var displayName: String { nickname ?? "家长" }
}

/// 订单关联的课程
struct StudioOrderCourse: Codable {
    let course_id: String?
    let title: String?
    let cover: String?
    let validity_days: Int?

    var titleText: String { title ?? "课程" }
}

/// 订单关联的班级
struct StudioOrderClass: Codable {
    let class_id: String?
    let name: String?

    var displayName: String { name ?? "" }
}

/// 订单关联的套餐
struct StudioOrderPackage: Codable {
    let package_id: String?
    let name: String?
    let lessons: Int?

    var displayName: String { name ?? "套餐" }
}

/// 订单子项
struct StudioOrderItem: Codable {
    let item_id: String?
    let course_title: String?
    let package_name: String?
    let lessons: Int?
    let unit_price: Int?
    let total_price: Int?
}

/// 付款记录
struct StudioPayment: Codable {
    let payment_id: String?
    let payment_no: String?
    let channel: String?
    let pay_method: String?
    let pay_method_text: String?
    let amount: Int?
    let status: Int?
    let status_text: String?
    let voucher_images: [String]?
    let payer_note: String?
    let upload_by: Int?
    let reject_reason: String?
    let paid_at: String?
    let created_at: String?

    /// 凭证状态：0 待确认 / 1 已确认 / 2 已驳回
    var isPending: Bool { (status ?? 0) == 0 }
    var isConfirmed: Bool { (status ?? 0) == 1 }
    var isRejected: Bool { (status ?? 0) == 2 }

    var amountText: String { StudioAmount.text(amount ?? 0) }
    var methodText: String { pay_method_text ?? pay_method ?? "—" }
    var statusLabel: String { status_text ?? "未知" }
    var hasVoucher: Bool { !(voucher_images ?? []).isEmpty }
    var voucherURLs: [String] { voucher_images ?? [] }
    var noteText: String { payer_note ?? "" }
    var rejectText: String { reject_reason ?? "" }
    /// 是否家长上传（0 工作室 / 1 家长）
    var isUploadedByParent: Bool { (upload_by ?? 0) == 1 }
}

/// 订单关联的退款
struct StudioOrderRefund: Codable {
    let refund_id: String?
    let amount: Int?
    let requested_lessons: Int?
    let refundable_lessons: Int?
    let status: Int?
    let status_text: String?
    let reason: String?
    let created_at: String?

    var amountText: String { StudioAmount.text(amount ?? 0) }

    /// 退款单状态颜色
    var statusColor: UIColor {
        switch status ?? 0 {
        case 0: return Theme.Color.warn
        case 1: return Theme.Color.brand
        case 2: return Theme.Color.danger
        case 3: return Theme.Color.muted
        default: return Theme.Color.muted
        }
    }

    var statusTintColor: UIColor {
        switch status ?? 0 {
        case 0: return Theme.Color.warnTint
        case 1: return Theme.Color.brandSoft
        case 2: return Theme.Color.dangerTint
        case 3: return Theme.Color.surfaceAlt
        default: return Theme.Color.surfaceAlt
        }
    }
}

/// 订单课时余额
struct StudioOrderBalance: Codable {
    let balance_id: String?
    let total_lessons: Int?
    let consumed_lessons: Int?
    let refunded_lessons: Int?
    let remaining_lessons: Int?
    let valid_from: String?
    let valid_to: String?
    let status: Int?

    var remaining: Int { remaining_lessons ?? 0 }
    var total: Int { total_lessons ?? 0 }
    var consumed: Int { consumed_lessons ?? 0 }
    var refunded: Int { refunded_lessons ?? 0 }
}

/// 工作室订单（列表 + 详情共用）
struct StudioOrder: Codable {
    let order_id: String
    let order_no: String?
    let status: Int?
    let status_text: String?
    let source: Int?
    let source_text: String?
    let class_id: String?
    let total_lessons: Int?
    let consumed_lessons: Int?
    let refunded_lessons: Int?
    let remaining_lessons: Int?
    let total_amount: Int?
    let paid_amount: Int?
    let refund_amount: Int?
    let refund_status: Int?
    let refund_status_text: String?
    let pay_channel: String?
    let pay_method: String?
    let pay_method_text: String?
    let confirmed_by: String?
    let paid_at: String?
    let created_at: String?
    let child: StudioOrderChild?
    let user: StudioOrderUser?
    let `class`: StudioOrderClass?
    let studio: StudioOrderStudio?
    let course: StudioOrderCourse?
    let package: StudioOrderPackage?
    let items: [StudioOrderItem]?
    let payments: [StudioPayment]?
    let refunds: [StudioOrderRefund]?
    let balance: StudioOrderBalance?

    /// 订单状态枚举
    var orderStatus: StudioOrderStatus {
        StudioOrderStatus(rawValue: status ?? 0) ?? .pending
    }

    var isPending: Bool { orderStatus == .pending }
    var isPaid: Bool { orderStatus == .paid }
    var isCancelled: Bool { orderStatus == .cancelled }
    var isRefunded: Bool { orderStatus == .refunded }

    /// 家长昵称（优先家长，其次"XX家长"）
    var parentName: String {
        if let n = user?.nickname, !n.isEmpty { return n }
        if let n = child?.nickname, !n.isEmpty { return n + "家长" }
        return "家长用户"
    }

    /// 课程标题
    var courseTitle: String { course?.titleText ?? "课程" }

    /// 金额文案
    var totalAmountText: String { StudioAmount.text(total_amount ?? 0) }
    var paidAmountText: String { StudioAmount.text(paid_amount ?? 0) }
    var refundAmountText: String { StudioAmount.text(refund_amount ?? 0) }

    /// 课时文案
    var totalLessonsText: String { "\(total_lessons ?? 0) 节" }
    var remainingLessonsText: String { "\(remaining_lessons ?? 0) 节" }

    /// 来源文案
    var sourceLabel: String { source_text ?? "家长报名" }

    /// 状态文案
    var statusLabel: String { status_text ?? "未知" }

    /// 创建日期（yyyy-MM-dd）
    var createdDate: String {
        guard let created_at, created_at.count >= 10 else { return "—" }
        return String(created_at.prefix(10))
    }

    /// 待确认的付款凭证（家长上传、线上方式）
    var pendingPayment: StudioPayment? {
        (payments ?? []).first { $0.isPending }
    }

    /// 是否有待确认凭证
    var hasPendingPayment: Bool { pendingPayment != nil }
}

/// 订单关联的工作室（列表页不一定返回，但 formatOrder 包含）
struct StudioOrderStudio: Codable {
    let studio_id: String?
    let name: String?
}

/// 订单列表分页
struct StudioOrderPage: Codable {
    let total: Int?
    let list: [StudioOrder]?
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

    /// 退款审核：action = approve 通过(→待家长确认) / reject 驳回(需 reason) / confirm 确认打款(→已退款)
    /// approve 时需传 refund_method（必填）和 voucher_images（线上方式必填）
    static func reviewRefund(
        refundId: String,
        action: String,
        reason: String? = nil,
        refundMethod: String? = nil,
        voucherImages: [String]? = nil,
        completion: @escaping (Result<StudioRefund?, APIError>) -> Void
    ) {
        var body: [String: Any] = ["action": action]
        if let reason, !reason.isEmpty { body["reason"] = reason }
        if let refundMethod, !refundMethod.isEmpty { body["refund_method"] = refundMethod }
        if let voucherImages, !voucherImages.isEmpty { body["voucher_images"] = voucherImages }
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

    // MARK: - 老师管理

    /// 在职老师列表（含 summary：老师数 / 学员数 / 本月消课 / 待审申请）；keyword 匹配姓名或擅长方向
    static func fetchTeachers(
        keyword: String? = nil,
        completion: @escaping (Result<StudioTeacherPage, APIError>) -> Void
    ) {
        var params: [String: Any]?
        let trimmed = keyword?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { params = ["q": trimmed] }
        APIClient.shared.request("/studio/teachers", method: .get, parameters: params) { result in
            switch result {
            case .success(let json):
                let page = JSONKit.decode(StudioTeacherPage.self, from: json)
                completion(.success(page ?? StudioTeacherPage(summary: nil, total: 0, list: [])))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 老师详情：档案 + 本工作室带课 + 最近消课流水
    static func fetchTeacherDetail(
        teacherId: String,
        completion: @escaping (Result<StudioTeacherDetail, APIError>) -> Void
    ) {
        APIClient.shared.request("/studio/teachers/\(teacherId)", method: .get) { result in
            switch result {
            case .success(let json):
                let detail = JSONKit.decode(StudioTeacherDetail.self, from: json)
                completion(.success(detail ?? StudioTeacherDetail(teacher: nil, courses: [], logs: [])))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 老师合作申请列表；status nil 为全部
    static func fetchTeacherApplications(
        status: Int?,
        completion: @escaping (Result<StudioTeacherApplicationPage, APIError>) -> Void
    ) {
        var params: [String: Any]?
        if let status { params = ["status": status] }
        APIClient.shared.request("/studio/teachers/applications", method: .get, parameters: params) { result in
            switch result {
            case .success(let json):
                let page = JSONKit.decode(StudioTeacherApplicationPage.self, from: json)
                completion(.success(page ?? StudioTeacherApplicationPage(summary: nil, total: 0, list: [])))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 审批老师合作申请：action = approve 通过 / reject 驳回（需 reason）
    static func reviewTeacherApplication(
        id: String,
        action: String,
        reason: String? = nil,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        var body: [String: Any] = ["action": action]
        if let reason, !reason.isEmpty { body["reason"] = reason }
        APIClient.shared.request("/studio/teachers/applications/\(id)", method: .put, parameters: body) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 邀请老师（手机号）：对方需已通过平台老师认证，本接口只建立合作绑定
    static func inviteTeacher(
        phone: String,
        completion: @escaping (Result<StudioTeacherInviteResult?, APIError>) -> Void
    ) {
        APIClient.shared.request("/studio/teachers/invite", method: .post, parameters: ["phone": phone]) { result in
            switch result {
            case .success(let json):
                completion(.success(JSONKit.decode(StudioTeacherInviteResult.self, from: json)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 解除与老师的合作（老师档案与其他工作室绑定不受影响）
    static func releaseTeacher(
        teacherId: String,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        APIClient.shared.request("/studio/teachers/\(teacherId)", method: .delete) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 银行卡管理
    
    /// 获取工作室绑定的银行卡列表
    static func fetchBankAccounts(completion: @escaping (Result<[BankAccount], APIError>) -> Void) {
        APIClient.shared.request("/studio/accounts", method: .get) { result in
            switch result {
            case .success(let json):
                let page = JSONKit.decode(BankAccountPage.self, from: json)
                completion(.success(page?.list ?? []))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 绑定银行卡
    static func addBankAccount(
        accountType: String,
        accountName: String,
        accountNo: String,
        bankName: String,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        APIClient.shared.request("/studio/accounts", method: .post, parameters: [
            "account_type": accountType,
            "account_name": accountName,
            "account_no": accountNo,
            "bank_name": bankName
        ]) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 收益中心（财务对账 + 佣金审核）

    /// 财务对账数据（GET /studio/finance）
    static func fetchFinance(completion: @escaping (Result<StudioFinanceData, APIError>) -> Void) {
        APIClient.shared.request("/studio/finance", method: .get) { result in
            switch result {
            case .success(let json):
                let data = JSONKit.decode(StudioFinanceData.self, from: json)
                    ?? StudioFinanceData(period: nil, summary: nil, orders: nil)
                completion(.success(data))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 工作室佣金领取单列表（GET /studio/commissions）
    /// status: 0 待审核 / 1 待确认(已打款) / 2 已驳回 / 3 已完成
    static func fetchCommissionWithdrawals(
        status: Int? = nil,
        page: Int = 1,
        pageSize: Int = 20,
        completion: @escaping (Result<(total: Int, list: [CommissionWithdrawal]), APIError>) -> Void
    ) {
        var params: [String: Any] = ["page": page, "page_size": pageSize]
        if let status { params["status"] = status }
        APIClient.shared.request(
            "/studio/commissions",
            method: .get,
            parameters: params,
            encoding: URLEncoding.default
        ) { result in
            switch result {
            case .success(let json):
                let list = JSONKit.decodeList([CommissionWithdrawal].self, from: json["list"])
                completion(.success((json["total"].int ?? 0, list)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 工作室审核领取单（PUT /studio/commissions/:id）
    /// action: approve 通过(需 method/voucher_images) / reject 驳回(需 reject_reason)
    static func reviewCommissionWithdrawal(
        id: String,
        action: String,
        method: String? = nil,
        voucherImages: [String]? = nil,
        rejectReason: String? = nil,
        completion: @escaping (Result<CommissionWithdrawal?, APIError>) -> Void
    ) {
        var body: [String: Any] = ["action": action]
        if let method { body["method"] = method }
        if let voucherImages { body["voucher_images"] = voucherImages }
        if let rejectReason { body["reject_reason"] = rejectReason }
        APIClient.shared.request(
            "/studio/commissions/\(id)",
            method: .put,
            parameters: body
        ) { result in
            switch result {
            case .success(let json):
                completion(.success(JSONKit.decode(CommissionWithdrawal.self, from: json)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 订单管理

    /// 订单列表（GET /studio/orders）
    /// status: 0 待收款 / 1 已收款 / 2 已取消 / 3 已退款；nil 为全部
    static func fetchOrders(
        status: Int? = nil,
        keyword: String? = nil,
        page: Int = 1,
        pageSize: Int = 20,
        completion: @escaping (Result<(total: Int, list: [StudioOrder]), APIError>) -> Void
    ) {
        var params: [String: Any] = ["page": page, "page_size": pageSize]
        if let status { params["status"] = status }
        let trimmed = keyword?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { params["q"] = trimmed }
        APIClient.shared.request(
            "/studio/orders",
            method: .get,
            parameters: params,
            encoding: URLEncoding.default
        ) { result in
            switch result {
            case .success(let json):
                let list = JSONKit.decodeList([StudioOrder].self, from: json["list"])
                completion(.success((json["total"].int ?? 0, list)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 订单详情（GET /studio/orders/:id）
    static func fetchOrderDetail(
        orderId: String,
        completion: @escaping (Result<StudioOrder?, APIError>) -> Void
    ) {
        APIClient.shared.request("/studio/orders/\(orderId)", method: .get) { result in
            switch result {
            case .success(let json):
                completion(.success(JSONKit.decode(StudioOrder.self, from: json)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 确认收款（POST /studio/orders/:id/payments/confirm）
    /// body: { pay_method, voucher_images?, note? }
    static func confirmPayment(
        orderId: String,
        payMethod: String,
        voucherImages: [String]? = nil,
        note: String? = nil,
        completion: @escaping (Result<StudioOrder?, APIError>) -> Void
    ) {
        var body: [String: Any] = ["pay_method": payMethod]
        if let voucherImages, !voucherImages.isEmpty { body["voucher_images"] = voucherImages }
        if let note, !note.isEmpty { body["note"] = note }
        APIClient.shared.request(
            "/studio/orders/\(orderId)/payments/confirm",
            method: .post,
            parameters: body
        ) { result in
            switch result {
            case .success(let json):
                completion(.success(JSONKit.decode(StudioOrder.self, from: json)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 驳回家长付款凭证（POST /studio/orders/:id/payments/reject）
    /// body: { reason }
    static func rejectPayment(
        orderId: String,
        reason: String,
        completion: @escaping (Result<StudioOrder?, APIError>) -> Void
    ) {
        APIClient.shared.request(
            "/studio/orders/\(orderId)/payments/reject",
            method: .post,
            parameters: ["reason": reason]
        ) { result in
            switch result {
            case .success(let json):
                completion(.success(JSONKit.decode(StudioOrder.self, from: json)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 取消待收款订单（POST /studio/orders/:id/cancel）
    static func cancelOrder(
        orderId: String,
        completion: @escaping (Result<StudioOrder?, APIError>) -> Void
    ) {
        APIClient.shared.request(
            "/studio/orders/\(orderId)/cancel",
            method: .post
        ) { result in
            switch result {
            case .success(let json):
                completion(.success(JSONKit.decode(StudioOrder.self, from: json)))
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

// MARK: - 工作室财务对账模型（GET /studio/finance）

/// 财务统计区间
struct StudioFinancePeriod: Codable {
    let start_date: String?
    let end_date: String?
}

/// 财务汇总（金额单位：分）
struct StudioFinanceSummary: Codable {
    /// 累计营收
    let gmv_total: Int?
    /// 区间营收
    let gmv_period: Int?
    /// 累计退款
    let refund_total: Int?
    /// 区间退款
    let refund_period: Int?
    /// 累计分销支出
    let distribution_total: Int?
    /// 累计净收入
    let net_total: Int?
    /// 区间净收入
    let net_period: Int?

    var gmvTotal: Int { gmv_total ?? 0 }
    var gmvPeriod: Int { gmv_period ?? 0 }
    var refundTotal: Int { refund_total ?? 0 }
    var refundPeriod: Int { refund_period ?? 0 }
    var distributionTotal: Int { distribution_total ?? 0 }
    var netTotal: Int { net_total ?? 0 }
    var netPeriod: Int { net_period ?? 0 }
}

/// 区间订单明细
struct StudioFinanceOrder: Codable {
    let order_id: String?
    let order_no: String?
    let total_amount: Int?
    let status: Int?
    let paid_at: String?
}

/// GET /studio/finance 响应
struct StudioFinanceData: Codable {
    let period: StudioFinancePeriod?
    let summary: StudioFinanceSummary?
    let orders: [StudioFinanceOrder]?
}
