import Foundation

// MARK: - 课程详情（详情页 + 报名页用）

struct CourseDetail: Codable {
    let course_id: String
    let title: String?
    let price: Int?
    let original_price: Int?
    let cover: String?
    let intro: String?
    let category: Int?
    let age_min: Int?
    let age_max: Int?
    let total_lessons: Int?
    let duration_min: Int?
    let class_size: Int?
    let rating: Double?
    let sales: Int?
    let studio: CourseStudio?
    let teacher: CourseDetailTeacher?
    let packages: [PackageItem]?
    let classes: [CourseClassItem]?

    /// 价格文案「¥1280」；无价格「价格咨询」
    var priceText: String {
        if let price, price > 0 {
            return price.fenToYuanText
        }
        return "价格咨询"
    }

    /// 原价划线（> 现价才显示）
    var originalPriceText: String? {
        guard let original = original_price, let price, original > price else { return nil }
        return original.fenToYuanText
    }

    /// 评分「4.8」；无评分「新课程」
    var ratingText: String {
        guard let rating, rating > 0 else { return "新课程" }
        return String(format: "%.1f", rating)
    }

    /// 年龄标签「4-8岁」；只有下界「6岁+」
    var ageRangeText: String? {
        if let min = age_min, let max = age_max, max > min {
            return "\(min)-\(max)岁"
        }
        if let min = age_min { return "\(min)岁+" }
        if let max = age_max { return "\(max)岁以内" }
        return nil
    }

    /// 班型标签「小班 6 人」
    var classSizeText: String? {
        guard let size = class_size, size > 0 else { return nil }
        return "小班 \(size)人"
    }

    /// 标签行（年龄 · 班型）
    var tagTexts: [String] {
        [ageRangeText, classSizeText].compactMap { $0 }
    }

    /// 副标题：机构 · 总课时
    var subtitleText: String {
        var parts: [String] = []
        if let studioName = studio?.name, !studioName.isEmpty { parts.append(studioName) }
        if let lessons = total_lessons, lessons > 0 { parts.append("\(lessons) 课时") }
        return parts.joined(separator: " · ")
    }

    /// 机构 · 老师
    var studioTeacherText: String {
        if let studioName = studio?.name, let teacherName = teacher?.real_name, !teacherName.isEmpty {
            return "\(studioName) · \(teacherName)"
        }
        return studio?.name ?? "未知机构"
    }

    /// 在售课包（兼容旧数据）
    var activePackages: [PackageItem] {
        (packages ?? []).filter { ($0.status ?? 1) == 1 }
    }
}

struct CourseStudio: Codable {
    let studio_id: String
    let name: String?
    let address: String?
    let phone: String?
}

struct CourseDetailTeacher: Codable {
    let teacher_id: String
    let real_name: String?
    let intro: String?
    let rating: Double?
}

struct PackageItem: Codable {
    let package_id: String
    let name: String?
    let lessons: Int?
    let price: Int?
    let original_price: Int?
    let status: Int?

    /// 课包副标题「16 课时 · ¥1280」
    var subtitleText: String {
        var parts: [String] = []
        if let lessons, lessons > 0 { parts.append("\(lessons) 课时") }
        if let price, price > 0 { parts.append(price.fenToYuanText) }
        return parts.joined(separator: " · ")
    }
}

/// 班级（详情页展示）
struct CourseClassItem: Codable {
    let class_id: String
    let name: String?
    let capacity: Int?
    let enrolled: Int?
    let start_date: String?
    let end_date: String?
    let time: String?
    let teacher_name: String?

    /// 时段「09:30-11:00」
    var timeText: String { time ?? "时间待定" }

    /// 满员
    var isFull: Bool {
        guard let capacity, capacity > 0 else { return false }
        return (enrolled ?? 0) >= capacity
    }

    /// 人数「8/10」
    var seatText: String {
        "\(enrolled ?? 0)/\(capacity ?? 0)"
    }

    /// 副标题：老师 · 时段 · 人数
    var subtitleText: String {
        var parts: [String] = []
        if let teacher = teacher_name, !teacher.isEmpty { parts.append(teacher) }
        parts.append(timeText)
        parts.append(seatText)
        return parts.joined(separator: " · ")
    }
}

// MARK: - 课程评价（详情页家长评价）

struct CourseReviewItem: Codable {
    let review_id: String?
    let rating: Int?
    let content: String?
    let images: [String]?
    let nickname: String?
    let avatar: String?
    let reply_content: String?
    let teacher_reply_content: String?
    let created_at: String?

    var authorName: String { nickname ?? "艺启家长" }
    var timeText: String { created_at?.shortRelativeTime ?? "" }
}

/// 课程评价汇总（评分分布 + 总数）
struct CourseReviewSummary: Codable {
    let rating_count: Int?
    let rating_distribution: [String: Int]?

    var total: Int { rating_count ?? 0 }
    /// 1...5 星数量（缺失补 0）
    func count(of star: Int) -> Int {
        rating_distribution?[String(star)] ?? 0
    }
}

/// 我的评价（我的评价列表）
struct MyReviewItem: Codable {
    let review_id: String?
    let rating: Int?
    let content: String?
    let images: [String]?
    let status: Int?          // 0 待审核 / 1 通过 / 2 驳回
    let reject_reason: String?
    let reply_content: String?
    let teacher_reply_content: String?
    let created_at: String?
    let course: CourseBrief?

    var statusText: String {
        switch status ?? 0 {
        case 1: return "已通过"
        case 2: return "已驳回"
        default: return "待审核"
        }
    }
    var timeText: String { created_at?.shortRelativeTime ?? "" }
}

struct CourseBrief: Codable {
    let course_id: String?
    let title: String?
    let cover: String?
}

// MARK: - 我的课程（列表）

struct MyCourseItem: Codable {
    let child_id: String?
    let child_name: String?
    let course_id: String
    let course_title: String?
    let course_cover: String?
    let studio_name: String?
    let teacher_name: String?
    let total_lessons: Int
    let consumed_lessons: Int
    let remaining_lessons: Int
    let percent: Int
    let status: Int?
    let status_text: String?
    let next_lesson: NextLessonItem?

    /// 机构 · 老师（老师缺失时只显示机构）
    var studioTeacherText: String {
        if let studio = studio_name, let teacher = teacher_name, !teacher.isEmpty, teacher != "-" {
            return "\(studio)·\(teacher)"
        }
        return studio_name ?? "未知机构"
    }

    /// 下次课文案：有排课显示"周X HH:mm"，无排课显示"待开课"
    var nextLessonText: String {
        guard let next = next_lesson, let date = next.lesson_date else { return "待开课" }
        return "\(date.weekdayText) \(next.start_time ?? "")"
    }
}

struct NextLessonItem: Codable {
    let schedule_id: String?
    let lesson_date: String?
    let start_time: String?
    let end_time: String?
}

// MARK: - 课时进度（课程详情）

struct CourseScheduleItem: Codable {
    let schedule_id: String?
    let class_id: String?
    let lesson_no: Int?
    let lesson_title: String?
    let lesson_date: String?
    let start_time: String?
    let end_time: String?
    /// 0 待上 / 1 已上 / 2 今天
    let status: Int?
    /// 请假状态：0 无 / 1 待处理 / 2 已同意 / 3 已婉拒 / 4 已取消
    let leave_status: Int?
}

// MARK: - 日期辅助

extension String {
    /// "YYYY-MM-DD" → "周六"（非法格式返回原文）
    var weekdayText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "zh_CN")
        guard let date = formatter.date(from: self) else { return self }
        let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekdays[(weekday - 1 + 7) % 7]
    }

    /// "YYYY-MM-DD" → "MM-DD"
    var mmddText: String {
        guard count >= 10 else { return self }
        return String(dropFirst(5).prefix(5))
    }
}

// MARK: - 课时进度汇总

struct CourseScheduleSummary: Codable {
    let child_id: String?
    let child_name: String?
    let course_id: String?
    let course_title: String?
    let course_cover: String?
    let class_id: String?
    let studio_name: String?
    let teacher_name: String?
    let total_lessons: Int?
    let consumed_lessons: Int?
    let remaining_lessons: Int?
    let scheduled_count: Int?
    let pending_lessons: Int?
    let list: [CourseScheduleItem]?

    init() {
        child_id = nil; child_name = nil; course_id = nil; course_title = nil
        course_cover = nil; class_id = nil; studio_name = nil; teacher_name = nil
        total_lessons = nil; consumed_lessons = nil; remaining_lessons = nil
        scheduled_count = nil; pending_lessons = nil; list = []
    }

    /// 机构 · 老师
    var studioTeacherText: String {
        if let studio = studio_name, let teacher = teacher_name, !teacher.isEmpty, teacher != "-" {
            return "\(studio)·\(teacher)"
        }
        return studio_name ?? "未知机构"
    }
}

// MARK: - 孩子简要（我的课程筛选）

struct ChildBrief: Codable {
    let child_id: String?
    let child_name: String?

    var id: String { child_id ?? "" }
    var name: String { child_name ?? "孩子" }
}
