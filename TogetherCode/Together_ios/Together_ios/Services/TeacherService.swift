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
        scheduleId: String,
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
