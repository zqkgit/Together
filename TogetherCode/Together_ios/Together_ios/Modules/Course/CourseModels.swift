import Foundation

// MARK: - 课程详情（报名页用）

struct CourseDetail: Codable {
    let course_id: String
    let title: String?
    let price: Int?
    let cover: String?
    let studio: CourseStudio?
    let packages: [PackageItem]?
}

struct CourseStudio: Codable {
    let studio_id: String
    let name: String?
}

struct PackageItem: Codable {
    let package_id: String
    let name: String?
    let lessons: Int?
    let price: Int?
    let original_price: Int?
    let status: Int?
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
    let schedule_id: String
    let lesson_no: Int?
    let lesson_title: String?
    let lesson_date: String?
    let start_time: String?
    let end_time: String?
    /// 0 待上 / 1 已上 / 2 今天
    let status: Int?
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
    let studio_name: String?
    let teacher_name: String?
    let total_lessons: Int?
    let consumed_lessons: Int?
    let remaining_lessons: Int?
    let list: [CourseScheduleItem]?

    init() {
        child_id = nil; child_name = nil; course_id = nil; course_title = nil
        course_cover = nil; studio_name = nil; teacher_name = nil
        total_lessons = nil; consumed_lessons = nil; remaining_lessons = nil; list = []
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
