import Foundation
import Alamofire
import SwiftyJSON

/// 帖子服务：广场流 / 详情 / 评论 / 点赞 / 收藏
enum PostService {

    /// 广场帖子流（分页 + 排序 + 话题筛选）
    /// - Parameters:
    ///   - page: 页码（从 1 开始）
    ///   - size: 每页条数
    ///   - sort: latest（推荐/最新）/ hot（热门）
    ///   - topic: 话题（传空 = 全部）
    static func fetchPlaza(page: Int, size: Int, sort: String, topic: String = "",
                           lat: Double? = nil, lng: Double? = nil,
                           completion: @escaping ([PostItem]?, Bool, String?) -> Void) {
        var params: [String: Any] = ["page": page, "size": size, "sort": sort]
        if !topic.isEmpty { params["topic"] = topic }
        if let lat { params["lat"] = lat }
        if let lng { params["lng"] = lng }
        APIClient.shared.request(
            "/posts/plaza",
            method: .get,
            parameters: params,
            encoding: URLEncoding.default
        ) { result in
            switch result {
            case .success(let json):
                let total = json["total"].intValue
                let list = JSONKit.decodeList([PostItem].self, from: json)
                completion(list, page * size < total, nil)
            case .failure(let error):
                completion(nil, false, error.message)
            }
        }
    }

    /// 发帖可选话题（公共接口，仅上架）
    static func fetchTopics(completion: @escaping ([String]?, String?) -> Void) {
        APIClient.shared.request("/topics", method: .get) { result in
            switch result {
            case .success(let json):
                completion(json.arrayValue.map { $0["name"].stringValue }, nil)
            case .failure(let error):
                completion(nil, error.message)
            }
        }
    }

    /// 我的作品（作品管理）：当前用户发布的全部帖子（含待审核/已驳回），按时间倒序
    /// status: all / public / private；counts 为 [全部, 公开, 未公开]
    static func fetchMyWorks(page: Int, size: Int, status: String,
                             completion: @escaping ([PostItem]?, [Int]?, Bool, String?) -> Void) {
        APIClient.shared.request(
            "/posts/mine",
            method: .get,
            parameters: ["page": page, "size": size, "status": status],
            encoding: URLEncoding.default
        ) { result in
            switch result {
            case .success(let json):
                let total = json["total"].intValue
                let list = JSONKit.decodeList([PostItem].self, from: json)
                let counts = json["counts"]
                let countsArray = [counts["all"].intValue, counts["public"].intValue, counts["private"].intValue]
                completion(list, countsArray, page * size < total, nil)
            case .failure(let error):
                completion(nil, nil, false, error.message)
            }
        }
    }

    /// 我的收藏（收藏与动态-收藏作品）
    static func fetchFavorites(page: Int, size: Int,
                               completion: @escaping ([FavoriteItem]?, Bool, String?) -> Void) {
        APIClient.shared.request(
            "/favorites",
            method: .get,
            parameters: ["target_type": "post", "page": page, "page_size": size],
            encoding: URLEncoding.default
        ) { result in
            switch result {
            case .success(let json):
                let total = json["total"].intValue
                let list = JSONKit.decodeList([FavoriteItem].self, from: json)
                completion(list, page * size < total, nil)
            case .failure(let error):
                completion(nil, false, error.message)
            }
        }
    }

    /// 孩子动态（收藏与动态）：我孩子相关的帖子（家长帖 + 老师关联帖）
    static func fetchChildFeed(page: Int, size: Int,
                               completion: @escaping ([PostItem]?, Bool, String?) -> Void) {
        APIClient.shared.request(
            "/posts/child-feed",
            method: .get,
            parameters: ["page": page, "size": size],
            encoding: URLEncoding.default
        ) { result in
            switch result {
            case .success(let json):
                let total = json["total"].intValue
                let list = JSONKit.decodeList([PostItem].self, from: json)
                completion(list, page * size < total, nil)
            case .failure(let error):
                completion(nil, false, error.message)
            }
        }
    }

    /// 帖子详情
    static func fetchDetail(postId: String, completion: @escaping (PostItem?, String?) -> Void) {
        APIClient.shared.request("/posts/\(postId)", method: .get) { result in
            switch result {
            case .success(let json):
                completion(JSONKit.decode(PostItem.self, from: json), nil)
            case .failure(let error):
                completion(nil, error.message)
            }
        }
    }

    /// 帖子详情撤销某学生的发帖消课（仅帖子作者/老师）
    static func undoPostStudentConsumption(
        postId: String,
        childIds: [String],
        completion: @escaping (Bool, String?) -> Void
    ) {
        APIClient.shared.request(
            "/teacher/posts/\(postId)/students/undo",
            method: .post,
            parameters: ["child_ids": childIds]
        ) { result in
            switch result {
            case .success:
                completion(true, nil)
            case .failure(let error):
                completion(false, error.message)
            }
        }
    }

    /// 评论点赞 / 取消点赞（帖子详情评论区）
    static func toggleCommentLike(postId: String, commentId: String, liked: Bool,
                                  completion: @escaping (Bool, String?) -> Void) {
        APIClient.shared.request(
            "/posts/\(postId)/comments/\(commentId)/like",
            method: liked ? .delete : .post
        ) { result in
            switch result {
            case .success:
                completion(true, nil)
            case .failure(let error):
                completion(false, error.message)
            }
        }
    }

    /// 关注 / 取消关注用户（帖子详情 "+关注"）
    static func followUser(userId: String, followed: Bool,
                           completion: @escaping (Bool, String?) -> Void) {
        APIClient.shared.request(
            "/users/\(userId)/follow",
            method: followed ? .delete : .post
        ) { result in
            switch result {
            case .success:
                completion(true, nil)
            case .failure(let error):
                completion(false, error.message)
            }
        }
    }

    /// 评论列表（分页）
    static func fetchComments(postId: String, page: Int, size: Int,
                              completion: @escaping ([CommentItem]?, Bool, String?) -> Void) {
        APIClient.shared.request(
            "/posts/\(postId)/comments",
            method: .get,
            parameters: ["page": page, "size": size],
            encoding: URLEncoding.default
        ) { result in
            switch result {
            case .success(let json):
                let total = json["total"].intValue
                let list = JSONKit.decodeList([CommentItem].self, from: json)
                completion(list, page * size < total, nil)
            case .failure(let error):
                completion(nil, false, error.message)
            }
        }
    }

    /// 发表评论
    /// 删除自己的评论
    static func deleteComment(commentId: String,
                              completion: @escaping (Bool, String?) -> Void) {
        APIClient.shared.request(
            "/posts/comments/\(commentId)",
            method: .delete
        ) { result in
            switch result {
            case .success:
                completion(true, nil)
            case .failure(let error):
                completion(false, error.message)
            }
        }
    }

    static func addComment(postId: String, content: String, parentId: String? = nil,
                           completion: @escaping (CommentItem?, String?) -> Void) {
        var parameters: [String: Any] = ["content": content]
        if let parentId, !parentId.isEmpty, parentId != "0" {
            parameters["parent_id"] = parentId
        }
        APIClient.shared.request(
            "/posts/\(postId)/comments",
            method: .post,
            parameters: parameters
        ) { result in
            switch result {
            case .success(let json):
                completion(JSONKit.decode(CommentItem.self, from: json), nil)
            case .failure(let error):
                completion(nil, error.message)
            }
        }
    }

    /// 点赞 / 取消点赞（接口返回状态，计数由调用方本地增减）
    static func toggleLike(postId: String, liked: Bool,
                           completion: @escaping (Bool, String?) -> Void) {
        APIClient.shared.request(
            "/posts/\(postId)/like",
            method: liked ? .delete : .post
        ) { result in
            switch result {
            case .success:
                completion(true, nil)
            case .failure(let error):
                completion(false, error.message)
            }
        }
    }

    /// 收藏 / 取消收藏（取消收藏为 query 传参）
    static func toggleFavorite(postId: String, favorited: Bool,
                               completion: @escaping (Bool?, String?) -> Void) {
        if favorited {
            APIClient.shared.request(
                "/favorites",
                method: .delete,
                parameters: ["target_type": "post", "target_id": postId],
                encoding: URLEncoding.default
            ) { result in
                switch result {
                case .success: completion(false, nil)
                case .failure(let error): completion(nil, error.message)
                }
            }
        } else {
            APIClient.shared.request(
                "/favorites",
                method: .post,
                parameters: ["target_type": "post", "target_id": postId]
            ) { result in
                switch result {
                case .success: completion(true, nil)
                case .failure(let error): completion(nil, error.message)
                }
            }
        }
    }
}


// MARK: - 发布（家长/老师双角色）

/// 老师班级（含课程信息，一个班级对应一门课）
struct TeacherClassItem: Codable {
    let class_id: String
    let name: String
    let course: TeacherCourse?

    var displayName: String {
        if let course = course, let title = course.title, !title.isEmpty {
            return "\(title) · \(name)"
        }
        return name
    }
}

/// 班级学生（花名册）
struct TeacherStudentItem: Codable {
    let child_id: String
    let nickname: String
    let avatar: String?
}

/// 老师排课（课次）
struct TeacherTimetableItem: Codable {
    let schedule_id: String
    let studio_name: String?
    let lesson_date: String?
    let start_time: String?
    let end_time: String?
    let location: String?
    let consume_status: String?      // pending / partial / completed
    let student_count: Int?
    let leave_count: Int?
    let consumed_count: Int?
    let status: Int?
    let `class`: TeacherClassRef?
    let course: TeacherCourse?

    var displayName: String {
        let date = lesson_date ?? ""
        let time = start_time ?? ""
        if date.isEmpty { return "课次 \(schedule_id)" }
        return date.isEmpty ? "未知课次" : "\(date) \(time)"
    }

    /// 消课状态文案
    var consumeText: String? {
        guard let consume_status else { return nil }
        switch consume_status {
        case "completed": return "已消课"
        case "partial": return "部分消课"
        default: return "待消课"
        }
    }
}

struct TeacherClassRef: Codable {
    let class_id: String
    let name: String?
    let enrolled: Int?
}

struct TeacherCourse: Codable {
    let course_id: String
    let title: String?
    let duration_min: Int?
}

extension PostService {

    /// 老师班级列表（含课程）
    static func fetchTeacherClasses(completion: @escaping (Result<[TeacherClassItem], APIError>) -> Void) {
        APIClient.shared.request("/teacher/classes", method: .get) { result in
            switch result {
            case .success(let json):
                completion(.success(JSONKit.decodeList([TeacherClassItem].self, from: json)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 老师排课（课次）；date = YYYY-MM-DD 查当天，week = 该周任意日期查整周
    static func fetchTeacherTimetable(date: String? = nil, week: String? = nil, completion: @escaping (Result<[TeacherTimetableItem], APIError>) -> Void) {
        var params: [String: Any] = [:]
        if let date, !date.isEmpty { params["date"] = date }
        if let week, !week.isEmpty { params["week"] = week }
        APIClient.shared.request("/teacher/timetable", method: .get, parameters: params, encoding: URLEncoding.queryString) { result in
            switch result {
            case .success(let json):
                completion(.success(JSONKit.decodeList([TeacherTimetableItem].self, from: json)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 班级学生（花名册）
    static func fetchTeacherClassStudents(classId: String, completion: @escaping (Result<[TeacherStudentItem], APIError>) -> Void) {
        APIClient.shared.request("/teacher/classes/\(classId)/students", method: .get) { result in
            switch result {
            case .success(let json):
                completion(.success(JSONKit.decodeList([TeacherStudentItem].self, from: json)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 家长发帖
    /// - Parameters:
    ///   - images: 已上传图片 URL 数组
    ///   - childId: 关联孩子
    ///   - topic: 话题（#成长记录 等）
    ///   - visibility: 1 仅好友 / 2 公开
    static func createPost(
        content: String,
        images: [String],
        childId: String,
        courseId: String? = nil,
        topic: String = "",
        visibility: Int = 2,
        type: Int = 1,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil,
        completion: @escaping (String?, String?) -> Void
    ) {
        var params: [String: Any] = [
            "content": content,
            "images": images,
            "child_id": childId,
            "visibility": visibility,
            "type": type
        ]
        if let courseId, !courseId.isEmpty { params["course_id"] = courseId }
        if !topic.isEmpty { params["topic"] = topic }
        if let latitude { params["latitude"] = latitude }
        if let longitude { params["longitude"] = longitude }
        if let locationName, !locationName.isEmpty { params["location_name"] = locationName }

        APIClient.shared.request("/posts", method: .post, parameters: params) { result in
            switch result {
            case .success(let json):
                completion(json["post_id"].string, nil)
            case .failure(let error):
                completion(nil, error.message)
            }
        }
    }

    /// 老师发帖：students=关联学生（家长可见/推送）；consume=true 时同步消课（扣课时，需 schedule_id）
    static func createTeacherPost(
        content: String,
        images: [String],
        courseId: String? = nil,
        classId: String? = nil,
        scheduleId: String? = nil,
        students: [[String: Any]] = [],
        consume: Bool = false,
        topic: String = "",
        visibility: Int = 2,
        type: Int = 2,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil,
        completion: @escaping (String?, String?) -> Void
    ) {
        var params: [String: Any] = [
            "content": content,
            "images": images,
            "visibility": visibility,
            "type": type,
            "consume": consume
        ]
        if let courseId, !courseId.isEmpty { params["course_id"] = courseId }
        if let classId, !classId.isEmpty { params["class_id"] = classId }
        if let scheduleId, !scheduleId.isEmpty { params["schedule_id"] = scheduleId }
        if !students.isEmpty { params["students"] = students }
        if !topic.isEmpty { params["topic"] = topic }
        if let latitude { params["latitude"] = latitude }
        if let longitude { params["longitude"] = longitude }
        if let locationName, !locationName.isEmpty { params["location_name"] = locationName }

        APIClient.shared.request("/teacher/posts", method: .post, parameters: params) { result in
            switch result {
            case .success(let json):
                completion(json["post_id"].string, nil)
            case .failure(let error):
                completion(nil, error.message)
            }
        }
    }

    /// 编辑家长作品帖（仅作者本人）
    static func updatePost(
        postId: String,
        content: String,
        images: [String]?,
        childId: String,
        courseId: String? = nil,
        topic: String = "",
        visibility: Int = 2,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil,
        clearLocation: Bool = false,
        completion: @escaping (String?, String?) -> Void
    ) {
        var params: [String: Any] = [
            "content": content,
            "child_id": childId,
            "visibility": visibility
        ]
        if let images, !images.isEmpty { params["images"] = images }
        if let courseId, !courseId.isEmpty { params["course_id"] = courseId }
        if !topic.isEmpty { params["topic"] = topic }
        if let latitude { params["latitude"] = latitude }
        if let longitude { params["longitude"] = longitude }
        if let locationName, !locationName.isEmpty { params["location_name"] = locationName }
        if clearLocation { params["clear_location"] = true }

        APIClient.shared.request("/posts/\(postId)", method: .put, parameters: params) { result in
            switch result {
            case .success:
                completion(nil, nil)
            case .failure(let error):
                completion(nil, error.message)
            }
        }
    }

    /// 编辑老师作品帖（仅作者本人；学生关联与消课不动，撤销走 undo）
    static func updateTeacherPost(
        postId: String,
        content: String,
        images: [String]?,
        topic: String = "",
        visibility: Int = 2,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil,
        clearLocation: Bool = false,
        completion: @escaping (String?, String?) -> Void
    ) {
        var params: [String: Any] = [
            "content": content,
            "visibility": visibility
        ]
        if let images, !images.isEmpty { params["images"] = images }
        if !topic.isEmpty { params["topic"] = topic }
        if let latitude { params["latitude"] = latitude }
        if let longitude { params["longitude"] = longitude }
        if let locationName, !locationName.isEmpty { params["location_name"] = locationName }
        if clearLocation { params["clear_location"] = true }

        APIClient.shared.request("/teacher/posts/\(postId)", method: .put, parameters: params) { result in
            switch result {
            case .success:
                completion(nil, nil)
            case .failure(let error):
                completion(nil, error.message)
            }
        }
    }

    /// 删除帖子（家长/老师统一；老师帖自动退消课课时）
    static func deletePost(
        postId: String,
        completion: @escaping (String?) -> Void
    ) {
        APIClient.shared.request("/posts/\(postId)", method: .delete, parameters: nil) { result in
            switch result {
            case .success:
                completion(nil)
            case .failure(let error):
                completion(error.message)
            }
        }
    }
}
