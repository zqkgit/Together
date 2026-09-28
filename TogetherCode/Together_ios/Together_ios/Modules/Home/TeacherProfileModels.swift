import Foundation

// MARK: - 老师主页详情

/// GET /v1/profile/teacher/:id/homepage 响应
struct TeacherProfileData: Codable {
    let user: TeacherProfileUser?
    let profile: TeacherProfileInfo?
    let studios: [TeacherProfileStudio]?
    let courses: [TeacherProfileCourse]?
    let works: TeacherProfileWorkPage?
}

/// 用户基本信息
struct TeacherProfileUser: Codable {
    let user_id: String?
    let nickname: String?
    let avatar: String?
    let city: String?
}

/// 老师档案
struct TeacherProfileInfo: Codable {
    let teacher_id: String
    let real_name: String?
    let subjects: [String]?
    let years: Int?
    let intro: String?
    let portfolio: [String]?
    let rating: Double?
    let student_count: Int?
    let work_count: Int?
    let fans: Int?

    var displayName: String { real_name ?? "老师" }
    var subjectsText: String {
        let s = subjects ?? []
        return s.isEmpty ? "暂未填写擅长方向" : s.joined(separator: " / ")
    }
    var yearsText: String {
        guard let years, years > 0 else { return "" }
        return "教龄\(years)年"
    }
    var ratingText: String {
        guard let rating, rating > 0 else { return "" }
        return String(format: "%.1f", rating)
    }
    /// 统计行：「⭐ 4.9 · 12名学员 · 36作品 · 128粉丝」
    var statsText: String {
        var parts: [String] = []
        if let rating, rating > 0 { parts.append("⭐ \(String(format: "%.1f", rating))") }
        if let sc = student_count, sc > 0 { parts.append("\(sc)名学员") }
        if let wc = work_count, wc > 0 { parts.append("\(wc)作品") }
        if let f = fans, f > 0 { parts.append("\(f)粉丝") }
        return parts.isEmpty ? "暂无数据" : parts.joined(separator: " · ")
    }
    var hasIntro: Bool {
        guard let intro, !intro.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return true
    }
    var hasPortfolio: Bool {
        guard let portfolio, !portfolio.isEmpty else { return false }
        return true
    }
}

/// 绑定工作室
struct TeacherProfileStudio: Codable {
    let studio_id: String
    let name: String?
    let cover: String?
    let address: String?
    let plan_tier: Int?

    var displayName: String { name ?? "工作室" }
}

/// 老师主页课程卡片
struct TeacherProfileCourse: Codable {
    let course_id: String
    let title: String
    let cover: String?
    let price: Int
    let age_min: Int?
    let age_max: Int?
    let total_lessons: Int?
    let rating: Double?
    let sales: Int?
    let studio_id: String?

    var priceText: String { price.fenToYuanText }
    var ageRangeText: String? {
        if let min = age_min, let max = age_max, max > min { return "\(min)-\(max)岁" }
        if let min = age_min { return "\(min)岁+" }
        if let max = age_max { return "\(max)岁以内" }
        return nil
    }
    var lessonsText: String {
        guard let total_lessons, total_lessons > 0 else { return "" }
        return "\(total_lessons)节"
    }
    /// 「¥1,280/16节 · 4-8岁」
    var detailText: String {
        var parts: [String] = [priceText]
        if !lessonsText.isEmpty { parts[0] += "/\(lessonsText)" }
        if let age = ageRangeText { parts.append(age) }
        return parts.joined(separator: " · ")
    }
    var ratingText: String {
        guard let rating, rating > 0 else { return "" }
        return String(format: "%.1f", rating)
    }
}

/// 作品分页
struct TeacherProfileWorkPage: Codable {
    let total: Int?
    let page: Int?
    let size: Int?
    let list: [TeacherProfileWork]?
}

/// 作品/动态
struct TeacherProfileWork: Codable {
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