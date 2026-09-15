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
    let pay_channel: String?
    let paid_at: String?
    let created_at: String?
    let child: OrderChildBrief?
    let studio: OrderStudioBrief?
    let course: OrderCourseBrief?
    let package: OrderPackageBrief?

    var statusValue: OrderStatus { OrderStatus(rawValue: status ?? -1) ?? .completed }

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
