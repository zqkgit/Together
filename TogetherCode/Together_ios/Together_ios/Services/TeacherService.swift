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
    let nickname: String?
    let avatar: String?
    let subjects: [String]?
    let years: Int?
    let intro: String?
    let cert_status: Int?
    let studio: TeacherMineStudio?

    var name: String { nickname ?? "老师" }
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
    /// 班级文案：朵朵班8人·芽芽班6人
    var classText: String {
        guard let classes, !classes.isEmpty else { return "暂无班级" }
        return classes.map { "\($0.name ?? "")\($0.studentCount)人" }.joined(separator: "·")
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
}

struct TeacherLeaveItem: Codable {
    let leave_id: String?
    let reason: String?
    let status: Int?
    let child: TeacherLeaveChild?
    let `class`: TeacherLeaveClass?
    let schedule: TeacherLeaveSchedule?

    /// 卡片副标题：课程·班级·日期时间
    var infoText: String {
        var parts: [String] = []
        if let title = `class`?.course?.title, !title.isEmpty { parts.append(title) }
        if let name = `class`?.name, !name.isEmpty { parts.append(name) }
        if let date = schedule?.lesson_date, !date.isEmpty { parts.append(date) }
        if let t = schedule?.start_time, !t.isEmpty { parts.append(t) }
        return parts.joined(separator: "·")
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
    static func fetchStudents(completion: @escaping (Result<TeacherStudentListData, APIError>) -> Void) {
        APIClient.shared.request("/teacher/students", method: .get) { result in
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
    static func fetchPendingLeaves(completion: @escaping (Result<[TeacherLeaveItem], APIError>) -> Void) {
        APIClient.shared.request(
            "/teacher/leaves",
            method: .get,
            parameters: ["status": 0],
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
