import Foundation
import Alamofire
import SwiftyJSON

/// 工作室主页详情服务
final class StudioHomepageService {

    static let shared = StudioHomepageService()

    /// 获取工作室主页详情（公开接口，无需登录）
    func fetchHomepage(studioId: String, page: Int = 1, size: Int = 10,
                       completion: @escaping (Result<StudioHomepageData, APIError>) -> Void) {
        let params: [String: Any] = ["page": page, "size": size]
        APIClient.shared.request("/profile/studio/\(studioId)/homepage",
                                 method: .get,
                                 parameters: params,
                                 encoding: URLEncoding.default) { result in
            switch result {
            case .success(let json):
                let data = JSONKit.decode(StudioHomepageData.self, from: json)
                    ?? StudioHomepageData(studio: nil, courses: nil, teachers: nil)
                completion(.success(data))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}