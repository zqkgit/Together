import Foundation

// MARK: - 订单状态（对齐后端 orders.status：0 待收款 / 1 待确认收款 / 2 已收款 / 3 退款审核中 / 4 待家长确认退款 / 5 已退款 / 6 已取消）

enum OrderStatus: Int {
    case pendingCollect = 0   // 待收款（线下付款后传凭证，等待机构确认）
    case paymentReview = 1    // 待确认收款（家长已上传凭证，等待机构确认）
    case collected = 2        // 已收款（机构确认到账，已发课时）
    case refundReview = 3     // 退款审核中
    case refundConfirm = 4    // 待家长确认退款
    case refunded = 5         // 已退款
    case cancelled = 6        // 已取消

    var text: String {
        switch self {
        case .pendingCollect: return "待付款"
        case .paymentReview: return "待确认"
        case .collected: return "已报名"
        case .refundReview: return "退款审核中"
        case .refundConfirm: return "待确认退款"
        case .refunded: return "已退款"
        case .cancelled: return "已取消"
        }
    }
}

// MARK: - 订单层退款聚合状态：0 无 / 1 退款中 / 2 已退款 / 3 已驳回

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

// MARK: - 线下付款方式（仅记录，不跳转支付、不展示收款码）

enum PayMethod: String, CaseIterable {
    case cash
    case wechat
    case alipay
    case bank
    case qrcode
    case other

    /// 后端枚举值
    var code: String { rawValue }

    var text: String {
        switch self {
        case .cash: return "现金"
        case .wechat: return "微信转账"
        case .alipay: return "支付宝转账"
        case .bank: return "银行转账"
        case .qrcode: return "扫码转账"
        case .other: return "其他"
        }
    }

    /// SF Symbol 图标
    var icon: String {
        switch self {
        case .cash: return "banknote"
        case .wechat: return "message.fill"
        case .alipay: return "a.circle.fill"
        case .bank: return "building.columns.fill"
        case .qrcode: return "qrcode"
        case .other: return "ellipsis.circle"
        }
    }

    /// 是否线上转账类（线上必须上传付款凭证；现金可免凭证）
    var isOnline: Bool { self != .cash }

    static func from(_ raw: String?) -> PayMethod? {
        guard let raw else { return nil }
        return PayMethod.allCases.first { $0.rawValue == raw }
    }
}

// MARK: - 付款记录（一笔=一次收款登记 / 一张凭证）

enum PaymentStatus: Int {
    case pending = 0    // 待机构确认
    case confirmed = 1  // 已确认（已收款）
    case rejected = 2   // 凭证被驳回

    var text: String {
        switch self {
        case .pending: return "待确认"
        case .confirmed: return "已确认"
        case .rejected: return "已驳回"
        }
    }
}

struct PaymentItem: Codable {
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
    /// 0 = 家长上传，1 = 工作室代登记
    let upload_by: Int?
    let reject_reason: String?
    let paid_at: String?
    let created_at: String?

    var statusValue: PaymentStatus { PaymentStatus(rawValue: status ?? 0) ?? .pending }
    var methodText: String { pay_method_text ?? PayMethod.from(pay_method ?? channel)?.text ?? "线下结算" }
    var images: [String] { voucher_images ?? [] }
    var isFromStudio: Bool { (upload_by ?? 0) == 1 }
    var timeText: String { PaymentItem.fmt(created_at ?? paid_at) }

    static func fmt(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "-" }
        return raw.replacingOccurrences(of: "T", with: " ").prefix(16).description
    }
}

// MARK: - 订单

struct OrderItem: Codable {
    let order_id: String?
    let order_no: String?
    let status: Int?
    /// 0 家长报名 / 1 工作室手动建单
    let source: Int?
    let source_text: String?
    let total_lessons: Int?
    let consumed_lessons: Int?
    let refunded_lessons: Int?
    let remaining_lessons: Int?
    let total_amount: Int?      // 分
    let paid_amount: Int?
    let refund_amount: Int?
    let refund_status: Int?
    let refund_status_text: String?
    let can_apply_refund: Bool?
    let refund_expire_at: String?
    let pay_channel: String?
    let pay_method: String?
    let pay_method_text: String?
    let paid_at: String?
    let created_at: String?
    let child: OrderChildBrief?
    let studio: OrderStudioBrief?
    let course: OrderCourseBrief?
    let package: OrderPackageBrief?
    let `class`: OrderClassBrief?
    let user: OrderUserBrief?
    let payments: [PaymentItem]?
    let refunds: [OrderRefundBrief]?

    var statusValue: OrderStatus { OrderStatus(rawValue: status ?? -1) ?? .cancelled }

    var refundStatusValue: OrderRefundStatus { OrderRefundStatus(rawValue: refund_status ?? 0) ?? .none }

    var hasActiveRefund: Bool { refundStatusValue == .processing }

    /// 最近一笔被驳回的凭证（待收款状态下提示重新上传）
    var rejectedPayment: PaymentItem? {
        (payments ?? []).first { $0.statusValue == .rejected }
    }

    /// 最近一笔待确认 / 已确认的付款记录
    var latestPayment: PaymentItem? {
        let list = payments ?? []
        return list.first { $0.statusValue == .pending } ?? list.first { $0.statusValue == .confirmed } ?? list.first
    }

    /// 付款凭证已提交、等待机构确认：此时不可重复上传凭证，也不可取消订单
    var isVoucherUnderReview: Bool {
        statusValue == .paymentReview
    }

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

    /// 机构 · 班级
    var studioClassText: String {
        let studioName = studio?.name ?? "未知机构"
        if let className = `class`?.name, !className.isEmpty {
            return "\(studioName) · \(className)"
        }
        return studioName
    }

    /// 机构（旧属性，兼容已有调用）
    var studioTeacherText: String { studio?.name ?? "未知机构" }

    var childName: String? { child?.nickname }

    /// 课程 · 班级（详情用）
    var courseClassText: String {
        let title = course?.title ?? "未知课程"
        if let className = `class`?.name, !className.isEmpty {
            return "\(title) · \(className)"
        }
        return title
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

struct OrderUserBrief: Codable {
    let user_id: String?
    let nickname: String?
    let phone: String?
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

struct OrderClassBrief: Codable {
    let class_id: String?
    let name: String?
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
    /// 机构审核锁定的实退课时（申请后若已消课，可能少于申请课时；nil=尚未审核）
    let approved_lessons: Int?
    let refundable_lessons: Int?
    let unit_price_text: String?
    let amount: Int?
    let amount_text: String?
    let reason: String?
    let status: Int?
    let status_text: String?
    /// 线下退款方式 / 文案
    let refund_method: String?
    let refund_method_text: String?
    /// 机构上传的线下打款凭证
    let voucher_images: [String]?
    let reject_reason: String?
    /// status=1 待家长确认时为 true
    let can_confirm: Bool?
    let confirmed_at: String?
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
