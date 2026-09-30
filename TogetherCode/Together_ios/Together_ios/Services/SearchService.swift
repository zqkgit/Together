import Foundation
import Alamofire
import SwiftyJSON

/// 搜索服务：帖子搜索 + 热词
final class SearchService {

    static let shared = SearchService()

    // MARK: - 搜索帖子

    func searchPosts(keyword: String, page: Int = 1, size: Int = 20,
                     completion: @escaping (Result<[PostItem], APIError>) -> Void) {
        APIClient.shared.request(
            "/posts/plaza",
            method: .get,
            parameters: ["keyword": keyword, "page": page, "size": size, "sort": "latest"],
            encoding: URLEncoding.default
        ) { result in
            switch result {
            case .success(let json):
                let list = JSONKit.decodeList([PostItem].self, from: json)
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
                if let arr = json["keywords"].array {
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
}