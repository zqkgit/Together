import Foundation
import Alamofire
import SwiftyJSON

// MARK: - 模型

/// 会话对方用户
struct ConversationPeer: Codable {
    let userId: String
    let nickname: String
    let avatar: String?
    let role: Int?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case nickname
        case avatar
        case role
    }
}

/// 会话关联孩子（老师-家长会话可能带学员上下文）
struct ConversationChild: Codable {
    let childId: String
    let nickname: String

    enum CodingKeys: String, CodingKey {
        case childId = "child_id"
        case nickname
    }
}

/// 会话最后一条消息
struct LastMessage: Codable {
    let messageId: String
    let senderId: String
    let type: String
    let content: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case senderId = "sender_id"
        case type
        case content
        case createdAt = "created_at"
    }
}

/// 会话条目
struct ConversationItem: Codable {
    let conversationId: String
    let peer: ConversationPeer?
    let child: ConversationChild?
    let lastMessage: LastMessage?
    let unreadCount: Int
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case peer
        case child
        case lastMessage = "last_message"
        case unreadCount = "unread_count"
        case updatedAt = "updated_at"
    }
}

/// 通知条目
struct NotificationItem: Codable {
    let notificationId: String
    let type: String
    let title: String
    let content: String
    let refType: String?
    let refId: String?
    let isRead: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case notificationId = "notification_id"
        case type
        case title
        case content
        case refType = "ref_type"
        case refId = "ref_id"
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

// MARK: - 服务

/// 消息服务：会话列表 / 通知列表 / 已读
enum MessageService {

    /// 会话列表（分页）
    /// - Returns: (会话列表, 总数, 未读总数, 错误)
    static func fetchConversations(
        page: Int,
        size: Int,
        completion: @escaping ([ConversationItem]?, Int, Int, String?) -> Void
    ) {
        APIClient.shared.request(
            "/messages/conversations",
            method: .get,
            parameters: ["page": page, "size": size],
            encoding: URLEncoding.default
        ) { result in
            switch result {
            case .success(let json):
                let total = json["total"].intValue
                let unread = json["unread_total"].intValue
                let list = JSONKit.decodeList([ConversationItem].self, from: json)
                completion(list, total, unread, nil)
            case .failure(let error):
                completion(nil, 0, 0, error.message)
            }
        }
    }

    /// 通知列表（分页，可按 type 过滤）
    /// - Returns: (通知列表, 总数, 未读总数, 错误)
    static func fetchNotifications(
        page: Int,
        size: Int,
        type: String = "",
        completion: @escaping ([NotificationItem]?, Int, Int, String?) -> Void
    ) {
        var params: [String: Any] = ["page": page, "size": size]
        if !type.isEmpty { params["type"] = type }
        APIClient.shared.request(
            "/messages/notifications",
            method: .get,
            parameters: params,
            encoding: URLEncoding.default
        ) { result in
            switch result {
            case .success(let json):
                let total = json["total"].intValue
                let unread = json["unread_total"].intValue
                let list = JSONKit.decodeList([NotificationItem].self, from: json)
                completion(list, total, unread, nil)
            case .failure(let error):
                completion(nil, 0, 0, error.message)
            }
        }
    }

    /// 单条通知已读
    static func markNotificationRead(
        id: String,
        completion: @escaping (Bool, String?) -> Void
    ) {
        APIClient.shared.request("/messages/notifications/\(id)/read", method: .put) { result in
            switch result {
            case .success:
                completion(true, nil)
            case .failure(let error):
                completion(false, error.message)
            }
        }
    }

    /// 全部通知已读
    static func markAllNotificationsRead(completion: @escaping (Bool, String?) -> Void) {
        APIClient.shared.request("/messages/notifications/read-all", method: .put) { result in
            switch result {
            case .success:
                completion(true, nil)
            case .failure(let error):
                completion(false, error.message)
            }
        }
    }
}

// MARK: - 时间格式化（消息列表专用）

/// 消息时间显示规则（对齐设计图）：
/// 今天 → HH:mm；昨天 → "昨天"；本周 → "周X"；更早 → "MM-dd"（跨年 → "yyyy-MM-dd"）
enum MessageTimeFormatter {

    private static let serverParsers: [DateFormatter] = {
        let iso = DateFormatter()
        iso.locale = Locale(identifier: "en_US_POSIX")
        iso.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"

        let withZ = DateFormatter()
        withZ.locale = Locale(identifier: "en_US_POSIX")
        withZ.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        let mysql = DateFormatter()
        mysql.locale = Locale(identifier: "en_US_POSIX")
        mysql.dateFormat = "yyyy-MM-dd HH:mm:ss"

        return [iso, withZ, mysql]
    }()

    /// 解析后端时间字符串 → Date（兼容 ISO8601 与 MySQL 格式）
    static func date(from string: String) -> Date? {
        for parser in serverParsers {
            if let date = parser.date(from: string) { return date }
        }
        return ISO8601DateFormatter().date(from: string)
    }

    static func display(_ dateString: String) -> String {
        guard let date = date(from: dateString) else { return dateString }
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            return "昨天"
        }
        // 本周（昨天之前，周一 ~ 周六）
        if let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
           date >= startOfWeek {
            let weekday = calendar.component(.weekday, from: date) // 1=周日
            let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
            return (weekday - 1 < names.count ? names[weekday - 1] : "周\(weekday)")
        }
        // 同年更早
        let formatter = DateFormatter()
        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            formatter.dateFormat = "MM-dd"
        } else {
            formatter.dateFormat = "yyyy-MM-dd"
        }
        return formatter.string(from: date)
    }
}
