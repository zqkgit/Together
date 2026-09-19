import Foundation
import Alamofire
import SwiftyJSON

/// 统一网络层：注入 token、解析 {code, message, data}、401 处理、上传
final class APIClient {
    static let shared = APIClient()

    private let session: Session

    private init() {
        let config = URLSessionConfiguration.af.default
        config.timeoutIntervalForRequest = 20
        session = Session(configuration: config)
    }

    typealias Completion = (Result<JSON, APIError>) -> Void

    /// 基础请求（GET/POST/PUT/DELETE）
    /// - Parameters:
    ///   - path: 相对路径（如 "/auth/login-password"），自动拼接 baseURL + /v1 前缀
    ///   - method: HTTP 方法
    ///   - parameters: 请求参数（body 传参 / query 由 encoding 决定）
    ///   - encoding: 默认 JSON body
    func request(
        _ path: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        encoding: ParameterEncoding = JSONEncoding.default,
        completion: @escaping Completion
    ) {
        let url = APIConfig.baseURL + path
        var headers: HTTPHeaders = ["Accept": "application/json"]
        if let token = TokenManager.shared.accessToken {
            headers.add(name: "Authorization", value: "Bearer \(token)")
        }

        // 接口加密：生成会话密钥 + 加密请求体 + 附加加密头（响应在 handle 里解密）
        var encSession: APICrypto.Session?
        var encParameters = parameters
        if APIConfig.apiEncryptEnabled, let session = APICrypto.makeSession() {
            encSession = session
            headers.add(name: "X-Enc-Key", value: session.encKey)
            headers.add(name: "X-Enc-Nonce", value: session.nonce)
            headers.add(name: "X-Enc-Timestamp", value: session.timestamp)
            // 仅写方法加密 body（GET 参数在 query，保持明文；服务端同样只解写方法 body）
            let isWrite = [.post, .put, .patch, .delete].contains(method)
            if isWrite, let parameters, let encrypted = APICrypto.encryptBody(parameters, session: session) {
                encParameters = encrypted
            }
        }

        session.request(url, method: method, parameters: encParameters, encoding: encoding, headers: headers)
            .validate(statusCode: 200..<600)
            .responseData { [weak self] response in
                self?.handle(response: response, session: encSession, completion: completion)
            }
    }

    /// 上传文件（POST /v1/upload，files ≤ 9，folder 白名单）
    func upload(
        files: [Data],
        folder: String,
        completion: @escaping Completion
    ) {
        let url = APIConfig.baseURL + "/upload"
        var headers: HTTPHeaders = ["Accept": "application/json"]
        if let token = TokenManager.shared.accessToken {
            headers.add(name: "Authorization", value: "Bearer \(token)")
        }

        session.upload(multipartFormData: { form in
            for (index, data) in files.enumerated() {
                form.append(data, withName: "files", fileName: "img_\(Int(Date().timeIntervalSince1970))_\(index).jpg", mimeType: "image/jpeg")
            }
            form.append(folder.data(using: .utf8) ?? Data(), withName: "folder")
        }, to: url, method: .post, headers: headers)
        .validate(statusCode: 200..<600)
        .responseData { [weak self] response in
            self?.handle(response: response, session: nil, completion: completion)
        }
    }

    // MARK: - 统一响应解析

    private func handle(response: AFDataResponse<Data>, session: APICrypto.Session?, completion: @escaping Completion) {
        switch response.result {
        case .success(let data):
            guard let json = try? JSON(data: data) else {
                completion(.failure(.parse))
                return
            }
            let code = json["code"].intValue
            if code == 0 {
                var payload = json["data"]
                // 响应加密：data 为 JSON 字符串 {"ct","tag","nonce"}，用本次会话密钥解密
                if json["enc"].boolValue, let session, let dict = APICrypto.payloadDict(from: payload) {
                    if let decrypted = APICrypto.decryptData(dict, session: session) {
                        payload = decrypted
                    } else {
                        completion(.failure(.parse))
                        return
                    }
                }
                completion(.success(payload))
            } else if code == 401 {
                // 登录态失效：清空并通知
                TokenManager.shared.clear()
                NotificationCenter.default.post(name: .authExpired, object: nil)
                completion(.failure(.unauthorized))
            } else {
                completion(.failure(APIError(code: code, message: json["message"].stringValue)))
            }
        case .failure:
            completion(.failure(.network))
        }
    }
}

extension Notification.Name {
    static let authExpired = Notification.Name("authExpired")
    static let userProfileUpdated = Notification.Name("userProfileUpdated")
    static let messageUnreadChanged = Notification.Name("messageUnreadChanged")
    static let userRoleDidChange = Notification.Name("userRoleDidChange")
}
