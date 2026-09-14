import Foundation

// MARK: - 金额格式化（后端价格单位：分）

extension Int {
    /// 分 → 元文案：整数不带小数，其余保留两位
    var fenToYuanText: String {
        let v = Double(self) / 100.0
        if v == v.rounded() {
            return String(format: "¥%.0f", v)
        }
        return String(format: "¥%.2f", v)
    }
}

// MARK: - 孩子

struct ChildItem: Codable {
    let child_id: String
    let nickname: String
    let avatar: String?
    let birthday: String?
    let gender: Int?
    let total_remaining_lessons: Int?
    let balances: [ChildBalance]?

    /// 主课包（第一笔有效余额），用于 Hero 进度卡
    var mainBalance: ChildBalance? {
        balances?.first(where: { $0.status == 1 }) ?? balances?.first
    }

    /// 由生日算年龄（如 "2019-03-08" → "5岁"），无生日返回 nil
    var ageText: String? {
        guard let birthday, birthday.count >= 4 else { return nil }
        let year = Int(birthday.prefix(4))
        let currentYear = Calendar.current.component(.year, from: Date())
        guard let year else { return nil }
        let age = currentYear - year
        return age >= 0 ? "\(age)岁" : nil
    }
}

/// 孩子课程余额（Hero 进度卡数据源）
struct ChildBalance: Codable {
    let balance_id: String
    let course_id: String?
    let course_title: String?
    let total_lessons: Int
    let consumed_lessons: Int
    let remaining_lessons: Int
    let status: Int?

    /// 学期完成度（0-100），无课时返回 0
    var progressPercent: Int {
        guard total_lessons > 0 else { return 0 }
        return min(100, Int((Double(consumed_lessons) / Double(total_lessons)) * 100))
    }

    /// 「水彩 · 初级」式课名（后端无等级字段，直接展示课程名）
    var courseText: String { course_title ?? "未报名课程" }
}

// MARK: - 公告

struct AnnouncementItem: Codable {
    let announcement_id: String
    let title: String
    let content: String?
    let type: Int
    let image: [String]
    let publish_at: String?
}

// MARK: - 课程

struct CourseItem: Codable {
    let course_id: String
    let title: String
    let cover: String?
    let price: Int
    let original_price: Int?
    let rating: Double?
    let sales: Int?
    let age_min: Int?
    let age_max: Int?
    let total_lessons: Int?
    let studio: CourseStudio?
    let teacher: CourseTeacher?
    let tags: [String]?

    struct CourseStudio: Codable {
        let studio_id: String
        let name: String
    }

    struct CourseTeacher: Codable {
        let teacher_id: String
        let real_name: String?
        let rating: Double?
    }

    var priceText: String { price.fenToYuanText }
    var originalPriceText: String? {
        guard let original_price, original_price > price else { return nil }
        return original_price.fenToYuanText
    }
    var studioName: String { studio?.name ?? "" }
    var teacherName: String { teacher?.real_name ?? "" }

    /// 年龄标签「4-8岁」；只有下界时「6岁+」
    var ageRangeText: String? {
        guard age_min != nil || age_max != nil else { return nil }
        if let min = age_min, let max = age_max, max > min {
            return "\(min)-\(max)岁"
        }
        if let min = age_min {
            return "\(min)岁+"
        }
        if let max = age_max {
            return "\(max)岁以内"
        }
        return nil
    }

    /// 价格 + 节数「¥1,280/16节」；无节数只显示价格
    var pricePerLessonsText: String {
        if let lessons = total_lessons, lessons > 0 {
            return "\(price.fenToYuanText)/\(lessons)节"
        }
        return price.fenToYuanText
    }
}

// MARK: - 工作室

struct StudioItem: Codable {
    let studio_id: String
    let name: String
    let cover: String?
    let type_tags: [String]?
    let intro: String?
    let address: String?
    let course_count: Int
    let teacher_count: Int
    let rating: Double?
    let distance: Double?

    var ratingText: String {
        guard let rating, rating > 0 else { return "—" }
        return String(format: "%.1f", rating)
    }
    var tagText: String {
        (type_tags ?? []).prefix(2).joined(separator: " · ")
    }

    /// 行 meta「水彩 · 黏土 · 距离 1.2km」；无距离回退地址，再无显示课程数
    var rowMetaText: String {
        var parts: [String] = []
        let tags = tagText
        if !tags.isEmpty { parts.append(tags) }
        if let distance, distance > 0 {
            parts.append("距离 \(distance < 1 ? String(format: "%.0fm", distance * 1000) : String(format: "%.1fkm", distance))")
        } else if let address, !address.isEmpty {
            parts.append(address)
        } else {
            parts.append("\(course_count) 门课")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - 老师

struct TeacherItem: Codable {
    let teacher_id: String
    let user_id: String
    let nickname: String
    let avatar: String?
    let real_name: String?
    let subjects: [String]?
    let years: Int?
    let intro: String?
    let rating: Double?
    let work_count: Int?
    let studios: [TeacherStudio]?

    struct TeacherStudio: Codable {
        let studio_id: String
        let name: String?
    }

    var displayName: String { real_name ?? nickname }
    var ratingText: String {
        guard let rating, rating > 0 else { return "—" }
        return String(format: "%.1f", rating)
    }
    var subjectText: String {
        (subjects ?? []).prefix(2).joined(separator: " / ")
    }
}

// MARK: - 帖子（老师动态 feed）

struct PostItem: Codable {
    let post_id: String
    let author: PostAuthor?
    let author_role_text: String?
    let content: String?
    let images: [String]?
    let like_count: Int?
    let comment_count: Int?
    let share_count: Int?
    let child: PostChild?
    let course: PostCourse?
    let created_at: String?

    struct PostAuthor: Codable {
        let user_id: String
        let nickname: String
        let avatar: String?
        let role: Int?
    }

    struct PostChild: Codable {
        let child_id: String
        let nickname: String?
    }

    struct PostCourse: Codable {
        let course_id: String
        let title: String?
    }

    var authorName: String { author?.nickname ?? "匿名" }
    var authorAvatar: String? { author?.avatar }
    var roleText: String { author_role_text ?? "" }
    var bodyText: String { content ?? "" }
    var imageList: [String] { images ?? [] }
    var likeText: String { "\(like_count ?? 0)" }
    var commentText: String { "\(comment_count ?? 0)" }

    /// 关联文案：优先孩子，其次课程
    var relationText: String? {
        if let childName = child?.nickname, !childName.isEmpty {
            return "宝宝 · \(childName)"
        }
        if let courseTitle = course?.title, !courseTitle.isEmpty {
            return "课程 · \(courseTitle)"
        }
        return nil
    }

    /// 相对时间「刚刚 / N分钟前 / 今天 09:28 / N天前 / 日期」
    var timeText: String {
        guard let raw = created_at else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: raw)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: raw)
        }
        guard let date else { return "" }

        let cal = Calendar.current
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval / 60))分钟前" }
        if cal.isDateInToday(date) {
            let h = cal.component(.hour, from: date)
            let m = cal.component(.minute, from: date)
            return String(format: "今天 %02d:%02d", h, m)
        }
        if cal.isDateInYesterday(date) { return "昨天" }
        if interval < 86400 * 7 { return "\(Int(interval / 86400))天前" }
        let f = DateFormatter()
        f.dateFormat = "MM-dd"
        return f.string(from: date)
    }
}
