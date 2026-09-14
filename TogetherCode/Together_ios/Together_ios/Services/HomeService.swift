import Foundation
import Alamofire
import SwiftyJSON

/// 首页数据聚合服务：孩子 / 公告 / 精选课程 / 推荐工作室 / 推荐老师 并行拉取
final class HomeService {

    static let shared = HomeService()

    struct HomeData {
        var children: [ChildItem] = []
        var courses: [CourseItem] = []
        var announcements: [AnnouncementItem] = []
        var studios: [StudioItem] = []
        var teachers: [TeacherItem] = []
        var posts: [PostItem] = []
    }

    /// 并行拉取首页全部数据，任一失败不影响其他模块（首个错误透出，无错误即成功）
    func fetchHome(completion: @escaping (Result<HomeData, APIError>) -> Void) {
        let group = DispatchGroup()
        var data = HomeData()
        var firstError: APIError?

        // 孩子（当前家长账号下）
        group.enter()
        APIClient.shared.request("/children", method: .get) { result in
            defer { group.leave() }
            switch result {
            case .success(let json):
                data.children = Self.decodeList([ChildItem].self, from: json)
            case .failure(let error):
                if firstError == nil { firstError = error }
            }
        }

        // 精选课程
        group.enter()
        APIClient.shared.request("/courses", method: .get,
                                 parameters: ["page": 1, "page_size": 6],
                                 encoding: URLEncoding.default) { result in
            defer { group.leave() }
            switch result {
            case .success(let json):
                data.courses = Self.decodeList([CourseItem].self, from: json)
            case .failure(let error):
                if firstError == nil { firstError = error }
            }
        }

        // 公告
        group.enter()
        APIClient.shared.request("/announcements", method: .get,
                                 parameters: ["page": 1, "page_size": 3],
                                 encoding: URLEncoding.default) { result in
            defer { group.leave() }
            switch result {
            case .success(let json):
                data.announcements = Self.decodeList([AnnouncementItem].self, from: json)
            case .failure(let error):
                if firstError == nil { firstError = error }
            }
        }

        // 推荐工作室
        group.enter()
        APIClient.shared.request("/studios", method: .get,
                                 parameters: ["page": 1, "page_size": 3],
                                 encoding: URLEncoding.default) { result in
            defer { group.leave() }
            switch result {
            case .success(let json):
                data.studios = Self.decodeList([StudioItem].self, from: json)
            case .failure(let error):
                if firstError == nil { firstError = error }
            }
        }

        // 推荐老师
        group.enter()
        APIClient.shared.request("/teachers", method: .get,
                                 parameters: ["page": 1, "page_size": 3],
                                 encoding: URLEncoding.default) { result in
            defer { group.leave() }
            switch result {
            case .success(let json):
                data.teachers = Self.decodeList([TeacherItem].self, from: json)
            case .failure(let error):
                if firstError == nil { firstError = error }
            }
        }

        // 老师动态（帖子流）
        group.enter()
        APIClient.shared.request("/posts", method: .get,
                                 parameters: ["page": 1, "page_size": 3],
                                 encoding: URLEncoding.default) { result in
            defer { group.leave() }
            switch result {
            case .success(let json):
                data.posts = Self.decodeList([PostItem].self, from: json)
            case .failure(let error):
                if firstError == nil { firstError = error }
            }
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
            } else {
                completion(.success(data))
            }
        }
    }

    // MARK: - 解码工具

    /// 列表接口统一结构 { total, page, page_size, list: [...] }
    private static func decodeList<T: Decodable>(_ type: [T].Type, from json: JSON) -> [T] {
        if let list = json["list"].array {
            let data = try? JSONSerialization.data(withJSONObject: list.map { $0.object })
            if let data, let items = try? JSONDecoder().decode([T].self, from: data) {
                return items
            }
        }
        return decode([T].self, from: json) ?? []
    }

    /// 直接数组 / 单对象解码
    private static func decode<T: Decodable>(_ type: [T].Type, from json: JSON) -> [T]? {
        guard let data = try? json.rawData() else { return nil }
        return try? JSONDecoder().decode([T].self, from: data)
    }
}
