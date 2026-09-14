import Foundation
import Alamofire
import SwiftyJSON

/// 帖子服务：广场流 / 帖子详情（后续点赞、评论、分享接入）
enum PostService {

    /// 广场帖子流（分页 + 排序 + 话题筛选）
    /// - Parameters:
    ///   - page: 页码（从 1 开始）
    ///   - size: 每页条数
    ///   - sort: latest（推荐/最新）/ hot（热门）
    ///   - topic: 话题（传空 = 全部）
    static func fetchPlaza(page: Int, size: Int, sort: String, topic: String = "",
                           completion: @escaping ([PostItem]?, Bool, String?) -> Void) {
        var params: [String: Any] = ["page": page, "size": size, "sort": sort]
        if !topic.isEmpty { params["topic"] = topic }
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
}
