import Foundation

// MARK: - 订单状态（对齐后端 orders.status）

enum OrderStatus: Int {
    case pending = 0      // 待支付
    case enrolled = 1     // 已报名（已支付）
    case cancelled = 2    // 已取消
    case completed = 3    // 已完成

    var text: String {
        switch self {
        case .pending: return "待支付"
        case .enrolled: return "已报名"
        case .cancelled: return "已取消"
        case .completed: return "已完成"
        }
    }
}

// MARK: - 退款状态（订单层聚合：0 无 / 1 退款中 / 2 已退款 / 3 已驳回）

enum OrderRefundStatus: Int {
    case none = 0
    case processing = 1
    case refunded = 2
    case rejected = 3

    var text: String {
        switch self {
        case .none: return "无"
        case .processing: return "退款中"
        case .refunded: return "已退款"
        case .rejected: return "已驳回"
        }
    }
}

// MARK: - 订单

struct OrderItem: Codable {
    let order_id: String?
    let order_no: String?
    let status: Int?
    let total_lessons: Int?
    let consumed_lessons: Int?
    let refunded_lessons: Int?
    let remaining_lessons: Int?
    let total_amount: Int?      // 分
    let paid_amount: Int?
    let refund_amount: Int?
    let refund_status: Int?
    let refund_status_text: String?
    let pay_channel: String?
    let paid_at: String?
    let created_at: String?
    let child: OrderChildBrief?
    let studio: OrderStudioBrief?
    let course: OrderCourseBrief?
    let package: OrderPackageBrief?
    let refunds: [OrderRefundBrief]?

    var statusValue: OrderStatus { OrderStatus(rawValue: status ?? -1) ?? .completed }

    /// 订单层退款聚合状态
    var refundStatusValue: OrderRefundStatus { OrderRefundStatus(rawValue: refund_status ?? 0) ?? .none }

    /// 是否存在进行中退款（退款中 → 订单按钮/状态展示切换）
    var hasActiveRefund: Bool { refundStatusValue == .processing }

    /// 最近一笔退款单（详情页跳转退款进度用）
    var latestRefundId: String? {
        refunds?.first?.refund_id
    }

    /// 金额（分 → 元，千分位，如 ¥1,200）
    var amountText: String {
        Self.fenToYuan(total_amount ?? 0)
    }

    /// 课程名 · 节数（如 森林水彩启蒙·16节）
    var courseTitleWithLessons: String {
        let title = course?.title ?? "未知课程"
        let lessons = package?.lessons ?? total_lessons ?? 0
        return "\(title)·\(lessons)节"
    }

    /// 机构 · 老师（后端订单无老师字段，机构优先）
    var studioTeacherText: String {
        studio?.name ?? "未知机构"
    }

    /// 孩子名（可能为空，订单页可省略展示）
    var childName: String? {
        child?.nickname
    }

    static func fenToYuan(_ fen: Int) -> String {
        let yuan = Double(fen) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        let value = formatter.string(from: NSNumber(value: yuan)) ?? "\(yuan)"
        return "¥\(value)"
    }
}

struct OrderChildBrief: Codable {
    let child_id: String?
    let nickname: String?
    let birthday: String?
}

struct OrderStudioBrief: Codable {
    let studio_id: String?
    let name: String?
}

struct OrderCourseBrief: Codable {
    let course_id: String?
    let title: String?
    let cover: String?
}

struct OrderPackageBrief: Codable {
    let package_id: String?
    let name: String?
    let lessons: Int?
}

struct OrderRefundBrief: Codable {
    let refund_id: String?
    let amount: Int?
    let requested_lessons: Int?
    let refundable_lessons: Int?
    let status: Int?
    let status_text: String?
    let reason: String?
    let created_at: String?
}

// MARK: - 退款详情（GET /refunds/:id）

struct RefundDetail: Codable {
    let refund_id: String?
    let order_id: String?
    let order_no: String?
    let course_title: String?
    let course_cover: String?
    let studio_name: String?
    let child_name: String?
    let total_lessons: Int?
    let consumed_lessons: Int?
    let refunded_lessons: Int?
    let balance_remaining: Int?
    let valid_to: String?
    let requested_lessons: Int?
    let refundable_lessons: Int?
    let unit_price_text: String?
    let amount: Int?
    let amount_text: String?
    let reason: String?
    let status: Int?
    let status_text: String?
    let created_at: String?
    let reviewed_at: String?
    let refunded_at: String?
    let steps: [RefundStep]?
}

struct RefundStep: Codable {
    let key: String?
    let title: String?
    let time: String?
    let done: Bool?
    let current: Bool?
}
