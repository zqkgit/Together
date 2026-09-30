import Foundation
import Alamofire
import SwiftyJSON

/// 老师主页服务（公开接口，无需登录）
final class TeacherProfileService {

    static let shared = TeacherProfileService()

    /// 获取老师主页详情
    func fetchHomepage(teacherId: String, page: Int = 1, size: Int = 10,
                       completion: @escaping (Result<TeacherProfileData, APIError>) -> Void) {
        let params: [String: Any] = ["page": page, "size": size]
        APIClient.shared.request("/profile/teacher/\(teacherId)/homepage",
                                 method: .get,
                                 parameters: params,
                                 encoding: URLEncoding.default) { result in
            switch result {
            case .success(let json):
                let data = JSONKit.decode(TeacherProfileData.self, from: json)
                    ?? TeacherProfileData(user: nil, profile: nil, studios: nil, courses: nil, works: nil, student_works: nil)
                completion(.success(data))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 获取老师公开评价列表
    func fetchReviews(teacherId: String, page: Int = 1, size: Int = 10,
                      completion: @escaping (Result<TeacherReviewsData, APIError>) -> Void) {
        let params: [String: Any] = ["page": page, "size": size]
        APIClient.shared.request("/profile/teacher/\(teacherId)/reviews",
                                 method: .get,
                                 parameters: params,
                                 encoding: URLEncoding.default) { result in
            switch result {
            case .success(let json):
                let data = JSONKit.decode(TeacherReviewsData.self, from: json)
                    ?? TeacherReviewsData(total: 0, average: 0, rating_distribution: nil, list: nil)
                completion(.success(data))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 获取老师学员作品分页
    func fetchStudentWorks(teacherId: String, page: Int = 1, size: Int = 10,
                           completion: @escaping (Result<TeacherProfileWorkPage, APIError>) -> Void) {
        let params: [String: Any] = ["page": page, "size": size]
        APIClient.shared.request("/profile/teacher/\(teacherId)/student-works",
                                 method: .get,
                                 parameters: params,
                                 encoding: URLEncoding.default) { result in
            switch result {
            case .success(let json):
                let data = JSONKit.decode(TeacherProfileWorkPage.self, from: json)
                    ?? TeacherProfileWorkPage(total: 0, page: 1, size: size, list: nil)
                completion(.success(data))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}