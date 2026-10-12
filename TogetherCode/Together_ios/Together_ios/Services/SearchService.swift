import Foundation
import Alamofire
import SwiftyJSON

/// 搜索服务：课程 / 工作室 / 老师搜索 + 热词
final class SearchService {

    static let shared = SearchService()

    /// 标签 ID → 名称 缓存（fetchTags 时自动填充，供课程列表将 tag_id 转为显示文字）
    private(set) var tagNameCache: [String: String] = [:]

    /// 根据 tag_id 查名称；找不到时回退返回原始 id
    func tagName(for id: String) -> String {
        tagNameCache[id] ?? id
    }

    // MARK: - 搜索课程

    func searchCourses(keyword: String = "", tag: String = "", page: Int = 1, size: Int = 20,
                       completion: @escaping (Result<[CourseItem], APIError>) -> Void) {
        var params: [String: Any] = ["page": page, "page_size": size]
        if !keyword.isEmpty { params["keyword"] = keyword }
        if !tag.isEmpty { params["tag"] = tag }
        APIClient.shared.request(
            "/courses",
            method: .get,
            parameters: params,
            encoding: URLEncoding.default
        ) { result in
            switch result {
            case .success(let json):
                let list = Self.decodeList([CourseItem].self, from: json)
                completion(.success(list))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 搜索工作室

    func searchStudios(keyword: String, page: Int = 1, size: Int = 20,
                       completion: @escaping (Result<[StudioItem], APIError>) -> Void) {
        APIClient.shared.request(
            "/studios",
            method: .get,
            parameters: ["keyword": keyword, "page": page, "page_size": size],
            encoding: URLEncoding.default
        ) { result in
            switch result {
            case .success(let json):
                let list = Self.decodeList([StudioItem].self, from: json)
                completion(.success(list))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 搜索老师

    func searchTeachers(keyword: String, page: Int = 1, size: Int = 20,
                        completion: @escaping (Result<[TeacherItem], APIError>) -> Void) {
        APIClient.shared.request(
            "/teachers",
            method: .get,
            parameters: ["keyword": keyword, "page": page, "page_size": size],
            encoding: URLEncoding.default
        ) { result in
            switch result {
            case .success(let json):
                let list = Self.decodeList([TeacherItem].self, from: json)
                completion(.success(list))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 热门搜索词

    func fetchHotKeywords(completion: @escaping (Result<[String], APIError>) -> Void) {
        APIClient.shared.request("/search/hot-keywords", method: .get) { result in
            switch result {
            case .success(let json):
                if let arr = json["list"].array {
                    let keywords = arr.compactMap { $0.string }
                    completion(.success(keywords))
                } else if let keywords = JSONKit.decode([String].self, from: json) {
                    completion(.success(keywords))
                } else {
                    completion(.success([]))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 兴趣标签

    func fetchTags(completion: @escaping (Result<[TagItem], APIError>) -> Void) {
        APIClient.shared.request("/tags", method: .get) { result in
            switch result {
            case .success(let json):
                // 接口返回数组 [{ tag_id, name, scope, sort, status }]
                let source = json.array ?? json["list"].array ?? []
                let items = source.compactMap { row -> TagItem? in
                    guard let name = row["name"].string, !name.isEmpty else { return nil }
                    return TagItem(
                        tagId: row["tag_id"].stringValue,
                        name: name,
                        scope: row["scope"].intValue,
                        sort: row["sort"].intValue
                    )
                }
                // 缓存 tag_id → name 映射，供课程列表标签显示
                Self.shared.tagNameCache = Dictionary(uniqueKeysWithValues: items.map { ($0.tagId, $0.name) })

                completion(.success(items))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 解码辅助

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