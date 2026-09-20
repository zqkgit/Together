import Foundation
import Alamofire
import SwiftyJSON

/// 标签使用场景（与 Web 端标签管理对齐：1 工作室 / 2 老师 / 3 通用）
enum TagScope: Int {
    case studio = 1
    case teacher = 2
    case common = 3
}

struct TagItem {
    let tagId: String
    let name: String
    let scope: Int
    let sort: Int
}

/// 公共兴趣标签库：App 端工作室/老师申请表单使用（仅启用中的标签）
/// 对应后端 GET /v1/tags?scope=1|2|3（公开接口，无需鉴权）
enum TagService {

    /// 拉取某场景下的启用标签
    /// - Parameter scope: 使用场景（工作室申请传 .studio）
    static func fetchTags(
        scope: TagScope,
        completion: @escaping (Result<[TagItem], APIError>) -> Void
    ) {
        APIClient.shared.request(
            "/tags",
            method: .get,
            parameters: ["scope": scope.rawValue]
        ) { result in
            switch result {
            case .success(let json):
                let items = json.arrayValue.compactMap { row -> TagItem? in
                    guard let name = row["name"].string, !name.isEmpty else { return nil }
                    return TagItem(
                        tagId: row["tag_id"].stringValue,
                        name: name,
                        scope: row["scope"].intValue,
                        sort: row["sort"].intValue
                    )
                }
                completion(.success(items))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
