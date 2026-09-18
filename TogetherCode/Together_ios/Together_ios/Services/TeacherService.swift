import Foundation
import Alamofire
import SwiftyJSON

// MARK: - 老师工作台

struct TeacherWorkbenchStats: Codable {
    let today_pending: Int?
    let active_students: Int?
    let attendance_rate: Int?

    var todayPending: Int { today_pending ?? 0 }
    var activeStudents: Int { active_students ?? 0 }
    var attendanceRate: Int { attendance_rate ?? 0 }
}

struct TeacherWorkbenchStudent: Codable {
    let child_id: String
    let nickname: String?
    let avatar: String?
    let leave: Bool?
    let consumed: Bool?
    let consumed_source: Int?
    let remaining_lessons: Int?

    var name: String { nickname ?? "宝宝" }
    var isLeave: Bool { leave ?? false }
    var isConsumed: Bool { consumed ?? false }
    var remaining: Int { remaining_lessons ?? 0 }
    /// 1=老师发帖自动消课 / 2=老师点名消课
    var consumeSource: Int { consumed_source ?? 0 }
}

struct TeacherWorkbenchSchedule: Codable {
    let schedule_id: String
    let start_time: String?
    let end_time: String?
    let location: String?
    let is_makeup: Bool?
    let consume_status: String?
    let `class`: TeacherClassRef?
    let course: TeacherCourse?
    let students: [TeacherWorkbenchStudent]?

    var statusText: String {
        switch consume_status {
        case "completed": return "已消课"
        case "partial": return "部分消课"
        default: return "待消课"
        }
    }
    var isCompleted: Bool { consume_status == "completed" }
}

struct TeacherWorkbench: Codable {
    let stats: TeacherWorkbenchStats?
    let today: [TeacherWorkbenchSchedule]?
}

// MARK: - 老师我的页

struct TeacherMineStudio: Codable {
    let studio_id: String?
    let name: String?
}

struct TeacherMineProfile: Codable {
    let teacher_id: String?
    let real_name: String?
    let nickname: String?
    let avatar: String?
    let subjects: [String]?
    let years: Int?
    let intro: String?
    let cert_status: Int?
    let studio: TeacherMineStudio?

    var name: String {
        if let real = real_name, !real.isEmpty { return real }
        return nickname ?? "老师"
    }
    var subjectText: String {
        guard let subjects, !subjects.isEmpty else { return "未设置科目" }
        return subjects.joined(separator: "/")
    }
    var yearsText: String { "教龄\(years ?? 0)年" }
    /// 副标题：工作室 · 科目 · 教龄
    var subtitle: String {
        var parts: [String] = []
        if let studioName = studio?.name, !studioName.isEmpty {
            parts.append(studioName)
        }
        let subj = subjectText
        if subj != "未设置科目" {
            parts.append(subj)
        }
        parts.append(yearsText)
        return parts.joined(separator: " · ")
    }
}

struct TeacherMineStats: Codable {
    let active_students: Int?
    let total_lessons: Int?
    let post_count: Int?

    var activeStudents: Int { active_students ?? 0 }
    var totalLessons: Int { total_lessons ?? 0 }
    var postCount: Int { post_count ?? 0 }
}

struct TeacherMineData: Codable {
    let profile: TeacherMineProfile?
    let stats: TeacherMineStats?
}

// MARK: - 我教的课程

struct TeacherCourseClassItem: Codable {
    let class_id: String?
    let name: String?
    let student_count: Int?

    var studentCount: Int { student_count ?? 0 }
}

struct TeacherCourseItem: Codable {
    let course_id: String?
    let studio_name: String?
    let title: String?
    let total_lessons: Int?
    let consumed_lessons: Int?
    let progress: Int?
    let student_count: Int?
    let classes: [TeacherCourseClassItem]?

    var total: Int { total_lessons ?? 0 }
    var consumed: Int { consumed_lessons ?? 0 }
    var progressValue: Int { progress ?? 0 }
    var studentCount: Int { student_count ?? 0 }
    /// 归属文案：工作室 · 班级（工作室-课程-班级三要素）
    var classText: String {
        let studio = (studio_name?.isEmpty == false) ? "\(studio_name!) · " : ""
        guard let classes, !classes.isEmpty else { return studio + "暂无班级" }
        return studio + classes.map { "\($0.name ?? "")\($0.studentCount)人" }.joined(separator: "·")
    }
}

struct TeacherCourseList: Codable {
    let total: Int?
    let list: [TeacherCourseItem]?
}

// MARK: - 我的学生

struct TeacherStudentClassSummary: Codable {
    let class_id: String?
    let name: String?
    let studio_name: String?

    /// 筛选展示：工作室·班级（多工作室同名班可区分）
    var displayName: String {
        let studio = (studio_name?.isEmpty == false) ? "\(studio_name!)·" : ""
        return studio + (name ?? "班级")
    }
}

struct TeacherStudentCourse: Codable {
    let course_id: String?
    let title: String?
    let class_id: String?
    let class_name: String?
    let remaining_lessons: Int?
    let total_lessons: Int?

    var remaining: Int { remaining_lessons ?? 0 }
    var total: Int { total_lessons ?? 0 }
}

struct TeacherStudentRow: Codable {
    let child_id: String?
    let nickname: String?
    let avatar: String?
    let birthday: String?
    let courses: [TeacherStudentCourse]?
    let today_scheduled: Bool?
    let leaving: Bool?

    var name: String { nickname ?? "宝宝" }
    var todayScheduled: Bool { today_scheduled ?? false }
    var isLeaving: Bool { leaving ?? false }
    var primaryCourse: TeacherStudentCourse? { courses?.first }
    /// 任一门课剩余课时 ≤ 2 → 课时不足
    var lowLessons: Bool {
        guard let courses, !courses.isEmpty else { return false }
        return courses.contains { $0.remaining <= 2 }
    }
    var ageText: String {
        guard let birthday, birthday.count >= 10 else { return "" }
        let year = Int(birthday.prefix(4)) ?? 0
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        let age = max(currentYear - year, 0)
        return age > 0 ? "\(age)岁" : ""
    }
}

struct TeacherStudentListData: Codable {
    let total: Int?
    let classes: [TeacherStudentClassSummary]?
    let list: [TeacherStudentRow]?
}

struct TeacherReviewData: Codable {
    let total: Int?
    let average: Double?
    let rating_distribution: [String: Int]?
    let list: [TeacherReviewItem]?
}

struct TeacherReviewItem: Codable {
    let review_id: String?
    let rating: Int?
    let content: String?
    let created_at: String?
    let user: TeacherReviewUser?
    let course: TeacherReviewCourse?

    var starsText: String {
        let r = max(0, min(5, rating ?? 0))
        return String(repeating: "★", count: r) + String(repeating: "☆", count: 5 - r)
    }

    var timeText: String {
        guard let created_at, created_at.count >= 10 else { return "" }
        return String(created_at.prefix(10))
    }
}

struct TeacherReviewUser: Codable {
    let user_id: String?
    let nickname: String?
    let avatar: String?
}

struct TeacherReviewCourse: Codable {
    let course_id: String?
    let title: String?
}

// MARK: - 请假

struct TeacherLeaveChild: Codable {
    let child_id: String?
    let nickname: String?
}

struct TeacherLeaveCourse: Codable {
    let course_id: String?
    let title: String?
}

struct TeacherLeaveClass: Codable {
    let class_id: String?
    let name: String?
    let course: TeacherLeaveCourse?
}

struct TeacherLeaveSchedule: Codable {
    let lesson_date: String?
    let start_time: String?
    let end_time: String?
    let location: String?
}

struct TeacherLeaveItem: Codable {
    let leave_id: String?
    let reason: String?
    let status: Int?
    let studio_id: String?
    let studio_name: String?
    let child: TeacherLeaveChild?
    let `class`: TeacherLeaveClass?
    let schedule: TeacherLeaveSchedule?
    let makeup_status: Int?
    let makeup_schedule_id: String?
    let makeup_schedule: TeacherLeaveSchedule?

    /// 卡片副标题：工作室·课程·班级·日期时间
    var infoText: String {
        var parts: [String] = []
        if let studio = studio_name, !studio.isEmpty { parts.append(studio) }
        if let title = `class`?.course?.title, !title.isEmpty { parts.append(title) }
        if let name = `class`?.name, !name.isEmpty { parts.append(name) }
        if let date = schedule?.lesson_date, !date.isEmpty { parts.append(date) }
        if let t = schedule?.start_time, !t.isEmpty { parts.append(t) }
        return parts.joined(separator: "·")
    }

    /// 是否有已安排的补课（待补）
    var hasPendingMakeup: Bool {
        (makeup_status ?? 0) == 0 && makeup_schedule_id != nil
    }

    /// 补课状态行文案
    var makeupText: String? {
        switch makeup_status {
        case 1:
            return "补课已完成 · 课时已消耗"
        case 2:
            return "已放弃补课"
        case 0:
            if let ms = makeup_schedule {
                var parts = ["补课：\(ms.lesson_date ?? "") \(ms.start_time ?? "")-\(ms.end_time ?? "")"]
                if let loc = ms.location, !loc.isEmpty { parts.append(loc) }
                return parts.joined(separator: " · ")
            }
            return "未安排补课"
        default:
            return nil
        }
    }

    /// 是否需要「安排补课」入口（未安排 / 已放弃）
    var canArrangeMakeup: Bool {
        !hasPendingMakeup && (makeup_status ?? 0) != 1
    }
}

/// 补课候选课次
struct TeacherMakeupCandidate: Codable {
    let schedule_id: String?
    let lesson_date: String?
    let start_time: String?
    let end_time: String?
    let location: String?
    let remark: String?

    /// 展示文案：10-19 18:30-20:00 · 3号教室
    var displayText: String {
        var parts = ["\(lesson_date ?? "") \(start_time ?? "")-\(end_time ?? "")"]
        if let loc = location, !loc.isEmpty { parts.append(loc) }
        return parts.joined(separator: " · ")
    }
}

/// 老师端服务：工作台 / 点名消课（App 侧 /v1/teacher/*）
enum TeacherService {

    /// 老师工作台聚合（今日课程 + 学员点名态 + 统计）
    static func fetchWorkbench(completion: @escaping (Result<TeacherWorkbench, APIError>) -> Void) {
        APIClient.shared.request("/teacher/workbench", method: .get) { result in
            switch result {
            case .success(let json):
                completion(.success(JSONKit.decode(TeacherWorkbench.self, from: json) ?? TeacherWorkbench(stats: nil, today: nil)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 老师「我的」页：资料 + 统计（在读学生/累计课时/作品数）
    static func fetchMine(completion: @escaping (Result<TeacherMineData, APIError>) -> Void) {
        APIClient.shared.request("/teacher/mine", method: .get) { result in
            switch result {
            case .success(let json):
                completion(.success(JSONKit.decode(TeacherMineData.self, from: json) ?? TeacherMineData(profile: nil, stats: nil)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 我教的课程（按课程聚合班级 + 进度）
    static func fetchCourses(completion: @escaping (Result<[TeacherCourseItem], APIError>) -> Void) {
        APIClient.shared.request("/teacher/courses", method: .get) { result in
            switch result {
            case .success(let json):
                let data = JSONKit.decode(TeacherCourseList.self, from: json)
                completion(.success(data?.list ?? []))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 我的学生：学生聚合（课程/剩余课时/今日上课/请假中）+ 班级列表
    static func fetchStudents(
        classId: String? = nil,
        completion: @escaping (Result<TeacherStudentListData, APIError>) -> Void
    ) {
        var parameters: [String: Any] = [:]
        if let classId { parameters["class_id"] = classId }
        APIClient.shared.request(
            "/teacher/students",
            method: .get,
            parameters: parameters,
            encoding: URLEncoding.queryString
        ) { result in
            switch result {
            case .success(let json):
                let data = JSONKit.decode(TeacherStudentListData.self, from: json)
                completion(.success(data ?? TeacherStudentListData(total: nil, classes: nil, list: nil)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 待处理请假（status=0）
    static func fetchTeacherReviews(completion: @escaping (Result<TeacherReviewData, APIError>) -> Void) {
        APIClient.shared.request("/teacher/reviews", method: .get) { result in
            switch result {
            case .success(let json):
                let data = JSONKit.decode(TeacherReviewData.self, from: json)
                completion(.success(data ?? TeacherReviewData(total: nil, average: nil, rating_distribution: nil, list: nil)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    static func fetchPendingLeaves(
        studioId: String? = nil,
        completion: @escaping (Result<[TeacherLeaveItem], APIError>) -> Void
    ) {
        var parameters: [String: Any] = ["status": 0]
        if let studioId { parameters["studio_id"] = studioId }
        APIClient.shared.request(
            "/teacher/leaves",
            method: .get,
            parameters: parameters,
            encoding: URLEncoding.queryString
        ) { result in
            switch result {
            case .success(let json):
                let list = JSONKit.decode([TeacherLeaveItem].self, from: json["list"]) ?? []
                completion(.success(list))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 已同意请假（status=1，用于补课管理）
    static func fetchApprovedLeaves(
        studioId: String? = nil,
        completion: @escaping (Result<[TeacherLeaveItem], APIError>) -> Void
    ) {
        var parameters: [String: Any] = ["status": 1]
        if let studioId { parameters["studio_id"] = studioId }
        APIClient.shared.request(
            "/teacher/leaves",
            method: .get,
            parameters: parameters,
            encoding: URLEncoding.queryString
        ) { result in
            switch result {
            case .success(let json):
                let list = JSONKit.decode([TeacherLeaveItem].self, from: json["list"]) ?? []
                completion(.success(list))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 补课候选课次（同班级、原课次之后、未消课）
    static func fetchMakeupCandidates(
        leaveId: String,
        completion: @escaping (Result<[TeacherMakeupCandidate], APIError>) -> Void
    ) {
        APIClient.shared.request(
            "/teacher/leaves/\(leaveId)/makeup-candidates",
            method: .get
        ) { result in
            switch result {
            case .success(let json):
                let list = JSONKit.decode([TeacherMakeupCandidate].self, from: json["list"]) ?? []
                completion(.success(list))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 安排补课 / 放弃补课
    static func updateMakeup(
        leaveId: String,
        makeupScheduleId: String? = nil,
        abandon: Bool = false,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        var parameters: [String: Any] = [:]
        if abandon {
            parameters["action"] = "abandon"
        } else if let makeupScheduleId {
            parameters["makeup_schedule_id"] = makeupScheduleId
        }
        APIClient.shared.request(
            "/teacher/leaves/\(leaveId)/makeup",
            method: .put,
            parameters: parameters
        ) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 审批请假：action=agree 同意保留课时 / reject 婉拒
    static func reviewLeave(
        leaveId: String,
        action: String,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        APIClient.shared.request(
            "/teacher/leaves/\(leaveId)",
            method: .put,
            parameters: ["action": action]
        ) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 一键点名消课（status=1 出勤消课；已请假/已消课学员后端会拦截）
    static func submitAttendance(
        scheduleId: String,
        childIds: [String],
        note: String? = nil,
        completion: @escaping (Result<JSON, APIError>) -> Void
    ) {
        let students = childIds.map { ["child_id": $0, "status": 1] }
        var parameters: [String: Any] = ["students": students]
        if let note, !note.isEmpty {
            parameters["note"] = note
        }
        APIClient.shared.request(
            "/teacher/schedules/\(scheduleId)/attendance",
            method: .post,
            parameters: parameters
        ) { result in
            switch result {
            case .success(let json):
                completion(.success(json))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 撤销点名消课（只撤老师点名 source=2 的记录，自动还原课时）
    static func undoAttendance(
        scheduleId: String,
        childIds: [String],
        completion: @escaping (Result<JSON, APIError>) -> Void
    ) {
        let parameters: [String: Any] = ["child_ids": childIds]
        APIClient.shared.request(
            "/teacher/schedules/\(scheduleId)/attendance/undo",
            method: .post,
            parameters: parameters
        ) { result in
            switch result {
            case .success(let json):
                completion(.success(json))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 课表详情：班级花名册 + 该排课已消课回显（consumed/selectable/leave）
    static func fetchClassStudents(
        classId: String,
        scheduleId: String = "",
        completion: @escaping (Result<[TeacherWorkbenchStudent], APIError>) -> Void
    ) {
        APIClient.shared.request(
            "/teacher/classes/\(classId)/students",
            method: .get,
            parameters: ["schedule_id": scheduleId],
            encoding: URLEncoding.queryString
        ) { result in
            switch result {
            case .success(let json):
                let list = JSONKit.decode([TeacherWorkbenchStudent].self, from: json["list"]) ?? []
                completion(.success(list))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
