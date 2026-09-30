import Foundation

// MARK: - 工作室主页详情

/// GET /v1/profile/studio/:id/homepage 响应
struct StudioHomepageData: Codable {
    let studio: StudioHomepageInfo?
    let courses: StudioHomepageCoursePage?
    let teachers: [StudioHomepageTeacher]?
    let student_works: StudioHomepageStudentWorkPage?
}

/// 工作室基本信息
struct StudioHomepageInfo: Codable {
    let studio_id: String
    let name: String
    let cover: String?
    let type_tags: [String]?
    let intro: String?
    let address: String?
    let phone: String?
    let hours: String?
    let photos: [String]?
    let plan_tier: Int?
    let city: String?
    let business_type: String?
    let rating: Double?
    let course_count: Int?
    let teacher_count: Int?

    var displayName: String { name.isEmpty ? "工作室" : name }
    var ratingText: String {
        guard let rating, rating > 0 else { return "—" }
        return String(format: "%.1f", rating)
    }
    var tagsText: String {
        (type_tags ?? []).prefix(3).joined(separator: " · ")
    }
    /// 城市与类型组合文本
    var locationText: String {
        var parts: [String] = []
        if let city, !city.isEmpty { parts.append(city) }
        if let bt = business_type, !bt.isEmpty { parts.append(bt) }
        return parts.joined(separator: " · ")
    }
    /// 统计行：「⭐ 4.8 · 12门课 · 8位老师」
    var statsText: String {
        var parts: [String] = []
        if let rating, rating > 0 { parts.append("⭐ \(String(format: "%.1f", rating))") }
        if let cc = course_count, cc > 0 { parts.append("\(cc)门课") }
        if let tc = teacher_count, tc > 0 { parts.append("\(tc)位老师") }
        return parts.isEmpty ? "暂无数据" : parts.joined(separator: " · ")
    }
    var hasPhone: Bool {
        guard let phone, !phone.isEmpty else { return false }
        return true
    }
}

/// 工作室主页课程卡片
struct StudioHomepageCourse: Codable {
    let course_id: String
    let title: String
    let cover: String?
    let price: Int
    let original_price: Int?
    let age_min: Int?
    let age_max: Int?
    let lesson_count: Int?
    let status: Int?

    var priceText: String { price.fenToYuanText }
    var originalPriceText: String? {
        guard let original_price, original_price > price else { return nil }
        return original_price.fenToYuanText
    }
    var ageRangeText: String? {
        guard age_min != nil || age_max != nil else { return nil }
        if let min = age_min, let max = age_max, max > min { return "\(min)-\(max)岁" }
        if let min = age_min { return "\(min)岁+" }
        if let max = age_max { return "\(max)岁以内" }
        return nil
    }
    var lessonsText: String {
        guard let lesson_count, lesson_count > 0 else { return "" }
        return "\(lesson_count)节"
    }
    /// 「¥1,280/16节 · 4-8岁」
    var detailText: String {
        var parts: [String] = [priceText]
        if !lessonsText.isEmpty { parts[0] += "/\(lessonsText)" }
        if let age = ageRangeText { parts.append(age) }
        return parts.joined(separator: " · ")
    }
}

/// 课程分页
struct StudioHomepageCoursePage: Codable {
    let total: Int?
    let page: Int?
    let size: Int?
    let list: [StudioHomepageCourse]?
}

/// 工作室主页老师卡片
struct StudioHomepageTeacher: Codable {
    let teacher_id: String
    let user_id: String?
    let nickname: String?
    let avatar: String?
    let real_name: String?
    let subjects: [String]?
    let years: Int?
    let rating: Double?

    var displayName: String { real_name ?? nickname ?? "老师" }
    var subjectText: String {
        let s = subjects ?? []
        return s.isEmpty ? "" : s.prefix(2).joined(separator: " / ")
    }
    var ratingText: String {
        guard let rating, rating > 0 else { return "" }
        return String(format: "⭐%.1f", rating)
    }
    /// 副标题：「水彩 / 素描 · ⭐4.9 · 教龄5年」
    var subtitle: String {
        var parts: [String] = []
        if !subjectText.isEmpty { parts.append(subjectText) }
        if !ratingText.isEmpty { parts.append(ratingText) }
        if let years, years > 0 { parts.append("教龄\(years)年") }
        return parts.isEmpty ? "暂未填写擅长方向" : parts.joined(separator: " · ")
    }
}

/// 工作室学员作品
struct StudioHomepageStudentWork: Codable {
    let post_id: String
    let type: Int?
    let images: [String]?
    let content: String?
    let like_count: Int?
    let comment_count: Int?
    let created_at: String?

    var firstImage: String? { images?.first }
    var likeText: String {
        guard let c = like_count, c > 0 else { return "" }
        return "❤️ \(c)"
    }
    var commentText: String {
        guard let c = comment_count, c > 0 else { return "" }
        return "💬 \(c)"
    }
}

/// 学员作品分页
struct StudioHomepageStudentWorkPage: Codable {
    let total: Int?
    let page: Int?
    let size: Int?
    let list: [StudioHomepageStudentWork]?
}