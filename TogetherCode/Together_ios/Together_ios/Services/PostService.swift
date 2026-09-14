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
