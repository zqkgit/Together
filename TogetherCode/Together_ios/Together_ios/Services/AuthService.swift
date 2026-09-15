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

    // MARK: - 个人资料（设置）

    struct UserProfile {
        let userId: String
        let phone: String
        let nickname: String
        let avatar: String?
        let city: String?
        let signature: String?
        let role: Int
    }

    /// 当前用户资料
    static func fetchMe(completion: @escaping (UserProfile?, String?) -> Void) {
        APIClient.shared.request("/auth/me", method: .get) { result in
            switch result {
            case .success(let json):
                let user = json["user"]
                completion(UserProfile(
                    userId: user["user_id"].stringValue,
                    phone: user["phone"].stringValue,
                    nickname: user["nickname"].stringValue,
                    avatar: user["avatar"].string,
                    city: user["city"].string,
                    signature: user["signature"].string,
                    role: user["role"].intValue
                ), nil)
            case .failure(let error):
                completion(nil, error.message)
            }
        }
    }

    /// 更新资料（昵称/头像/城市，只传需要修改的字段）
    static func updateProfile(nickname: String? = nil, avatar: String? = nil, city: String? = nil, signature: String? = nil,
                              completion: @escaping (Bool, String?) -> Void) {
        var params: [String: Any] = [:]
        if let nickname { params["nickname"] = nickname }
        if let avatar { params["avatar"] = avatar }
        if let city { params["city"] = city }
        if let signature { params["signature"] = signature }
        guard !params.isEmpty else {
            completion(true, nil)
            return
        }
        APIClient.shared.request("/me/profile", method: .put, parameters: params) { result in
            switch result {
            case .success:
                completion(true, nil)
            case .failure(let error):
                completion(false, error.message)
            }
        }
    }

    // MARK: - 账号与安全

    /// 修改登录密码
    static func changePassword(oldPassword: String, newPassword: String,
                               completion: @escaping (Bool, String?) -> Void) {
        APIClient.shared.request("/auth/change-password", method: .post,
                                 parameters: ["old_password": oldPassword, "new_password": newPassword]) { result in
            switch result {
            case .success:
                completion(true, nil)
            case .failure(let error):
                completion(false, error.message)
            }
        }
    }

    /// 更换绑定手机号
    static func changePhone(phone: String, code: String,
                            completion: @escaping (Bool, String?) -> Void) {
        APIClient.shared.request("/auth/change-phone", method: .post,
                                 parameters: ["phone": phone, "code": code]) { result in
            switch result {
            case .success:
                completion(true, nil)
            case .failure(let error):
                completion(false, error.message)
            }
        }
    }

    /// 设置支付密码
    static func setPayPassword(_ payPassword: String,
                               completion: @escaping (Bool, String?) -> Void) {
        APIClient.shared.request("/me/pay-password", method: .post,
                                 parameters: ["pay_password": payPassword]) { result in
            switch result {
            case .success:
                completion(true, nil)
            case .failure(let error):
                completion(false, error.message)
            }
        }
    }

    /// 注销账号
    static func deactivateAccount(code: String,
                                  completion: @escaping (Bool, String?) -> Void) {
        APIClient.shared.request("/auth/deactivate", method: .post,
                                 parameters: ["code": code]) { result in
            switch result {
            case .success:
                completion(true, nil)
            case .failure(let error):
                completion(false, error.message)
            }
        }
    }
}
