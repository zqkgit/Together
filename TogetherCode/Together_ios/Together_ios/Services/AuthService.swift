import Foundation
import Alamofire
import SwiftyJSON

/// 认证相关接口：登录、注册、验证码、角色
final class AuthService {

    // MARK: - 登录成功载荷

    struct LoginPayload {
        let token: String
        let userId: String
        let role: Int
        let nickname: String
        let phone: String
    }

    /// 解析统一登录响应（data.access_token / data.user / data.current_role）
    private static func parseLoginResponse(_ json: JSON) -> LoginPayload? {
        let token = json["access_token"].stringValue
        guard !token.isEmpty else { return nil }
        return LoginPayload(
            token: token,
            userId: json["user"]["user_id"].stringValue,
            role: json["current_role"].intValue,
            nickname: json["user"]["nickname"].stringValue,
            phone: json["user"]["phone"].stringValue
        )
    }

    // MARK: - 发送验证码

    /// 发送验证码（后端自动判断：已注册=登录，未注册=注册）
    /// - Parameters:
    ///   - phone: 手机号
    ///   - completion: 成功时返回是否已注册（后端 purpose）
    static func sendCode(
        phone: String,
        completion: @escaping (Result<JSON, APIError>) -> Void
    ) {
        APIClient.shared.request(
            "/auth/send-code",
            method: .post,
            parameters: ["phone": phone]
        ) { result in
            completion(result)
        }
    }

    // MARK: - 密码登录

    /// 密码登录
    static func loginPassword(
        phone: String,
        password: String,
        completion: @escaping (Result<LoginPayload, APIError>) -> Void
    ) {
        APIClient.shared.request(
            "/auth/login-password",
            method: .post,
            parameters: ["phone": phone, "password": password]
        ) { result in
            switch result {
            case .success(let json):
                guard let payload = parseLoginResponse(json) else {
                    completion(.failure(.parse))
                    return
                }
                completion(.success(payload))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 验证码登录

    /// 验证码登录（已注册用户）
    static func loginWithCode(
        phone: String,
        code: String,
        completion: @escaping (Result<LoginPayload, APIError>) -> Void
    ) {
        APIClient.shared.request(
            "/auth/login",
            method: .post,
            parameters: ["phone": phone, "code": code]
        ) { result in
            switch result {
            case .success(let json):
                guard let payload = parseLoginResponse(json) else {
                    completion(.failure(.parse))
                    return
                }
                completion(.success(payload))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 注册（验证码注册，注册即登录）

    /// 注册（未注册手机号 + 验证码；后端默认密码，注册后直接返回登录态）
    static func register(
        phone: String,
        code: String,
        completion: @escaping (Result<LoginPayload, APIError>) -> Void
    ) {
        APIClient.shared.request(
            "/auth/register",
            method: .post,
            parameters: ["phone": phone, "code": code]
        ) { result in
            switch result {
            case .success(let json):
                guard let payload = parseLoginResponse(json) else {
                    completion(.failure(.parse))
                    return
                }
                completion(.success(payload))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 角色切换

    /// 角色切换（1 家长 / 2 老师 / 3 工作室）
    static func switchRole(
        _ role: Int,
        completion: @escaping (Result<JSON, APIError>) -> Void
    ) {
        APIClient.shared.request(
            "/auth/role/switch",
            method: .post,
            parameters: ["role": role]
        ) { result in
            switch result {
            case .success(let json):
                completion(.success(json))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 角色认证申请

    /// 查询认证申请状态（teacher / studio）
    /// 返回 data.status：unauth（从未申请）/ pending / approved / rejected（rejected 带 reason，可重提）
    static func getRoleApplyStatus(
        _ role: String,
        completion: @escaping (Result<JSON, APIError>) -> Void
    ) {
        APIClient.shared.request(
            "/auth/role/apply/\(role)",
            method: .get
        ) { result in
            completion(result)
        }
    }

    /// 提交老师认证 / 工作室入驻申请
    /// - Parameters:
    ///   - role: "teacher" / "studio"
    ///   - payload: teacher: real_name(必填)/subjects/years/intro/cert_no/portfolio；studio: name(必填)/cover/intro/address/phone/license/permit/photos
    static func submitRoleApply(
        role: String,
        payload: [String: Any],
        completion: @escaping (Result<JSON, APIError>) -> Void
    ) {
        APIClient.shared.request(
            "/auth/role/apply",
            method: .post,
            parameters: ["role": role, "payload": payload]
        ) { result in
            completion(result)
        }
    }
}
