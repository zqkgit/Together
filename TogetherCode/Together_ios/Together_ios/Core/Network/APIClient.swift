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

    /// 一次请求的日志上下文
    fileprivate struct ReqContext {
        let id: Int
        let method: String
        let path: String
        let start: CFAbsoluteTime
    }

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
        var bodyEncrypted = false
        if APIConfig.apiEncryptEnabled, let session = APICrypto.makeSession() {
            encSession = session
            headers.add(name: "X-Enc-Key", value: session.encKey)
            headers.add(name: "X-Enc-Nonce", value: session.nonce)
            headers.add(name: "X-Enc-Timestamp", value: session.timestamp)
            // 仅写方法加密 body（GET 参数在 query，保持明文；服务端同样只解写方法 body）
            let isWrite = [.post, .put, .patch, .delete].contains(method)
            if isWrite, let parameters, let encrypted = APICrypto.encryptBody(parameters, session: session) {
                encParameters = encrypted
                bodyEncrypted = true
            }
        }

        let context = ReqContext(id: NetworkLogger.nextId(), method: method.rawValue, path: path, start: CFAbsoluteTimeGetCurrent())
        NetworkLogger.request(context: context, params: parameters, bodyEncrypted: bodyEncrypted)

        // GET 参数只能走 query string：JSONEncoding 会给 GET 生成 body，Alamofire 会判定「GET cannot have body data」直接失败
        let actualEncoding: ParameterEncoding = (method == .get) ? URLEncoding.queryString : encoding
        session.request(url, method: method, parameters: encParameters, encoding: actualEncoding, headers: headers)
            .validate(statusCode: 200..<600)
            .responseData { [weak self] response in
                self?.handle(response: response, session: encSession, context: context, completion: completion)
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

        let context = ReqContext(id: NetworkLogger.nextId(), method: "POST", path: "/upload", start: CFAbsoluteTimeGetCurrent())
        let totalBytes = files.reduce(0) { $0 + $1.count }
        NetworkLogger.upload(context: context, folder: folder, fileCount: files.count, totalBytes: totalBytes)

        session.upload(multipartFormData: { form in
            for (index, data) in files.enumerated() {
                form.append(data, withName: "files", fileName: "img_\(Int(Date().timeIntervalSince1970))_\(index).jpg", mimeType: "image/jpeg")
            }
            form.append(folder.data(using: .utf8) ?? Data(), withName: "folder")
        }, to: url, method: .post, headers: headers)
        .validate(statusCode: 200..<600)
        .responseData { [weak self] response in
            self?.handle(response: response, session: nil, context: context, completion: completion)
        }
    }

    // MARK: - 统一响应解析

    private func handle(
        response: AFDataResponse<Data>,
        session: APICrypto.Session?,
        context: ReqContext,
        completion: @escaping Completion
    ) {
        let httpStatus = response.response?.statusCode
        switch response.result {
        case .success(let data):
            guard let json = try? JSON(data: data) else {
                NetworkLogger.failure(context: context, httpStatus: httpStatus, kind: "响应不是合法 JSON", detail: String(data: data, encoding: .utf8))
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
                        NetworkLogger.failure(context: context, httpStatus: httpStatus, kind: "响应解密失败", detail: payload.rawString())
                        completion(.failure(.parse))
                        return
                    }
                }
                NetworkLogger.response(context: context, httpStatus: httpStatus, code: code, ok: true,
                                       message: nil, preview: payload.rawString())
                completion(.success(payload))
            } else if code == 401 {
                // 登录态失效：清空并通知
                TokenManager.shared.clear()
                NotificationCenter.default.post(name: .authExpired, object: nil)
                NetworkLogger.response(context: context, httpStatus: httpStatus, code: code, ok: false,
                                       message: "登录态失效（401）", preview: nil)
                completion(.failure(.unauthorized))
            } else {
                let message = json["message"].stringValue
                NetworkLogger.response(context: context, httpStatus: httpStatus, code: code, ok: false,
                                       message: message, preview: nil)
                completion(.failure(APIError(code: code, message: message)))
            }
        case .failure(let error):
            NetworkLogger.failure(context: context, httpStatus: httpStatus, kind: "网络请求失败", detail: error.localizedDescription)
            completion(.failure(.network))
        }
    }
}

// MARK: - 网络日志（仅 DEBUG 输出，Release 为空实现；不打印 Authorization / 加密密钥等请求头）

enum NetworkLogger {
    private static var seq = 0
    private static let lock = NSLock()
    private static let previewLimit = 1200

    fileprivate static func nextId() -> Int {
        lock.lock(); defer { lock.unlock() }
        seq += 1
        return seq
    }

    fileprivate static func request(context: APIClient.ReqContext, params: [String: Any]?, bodyEncrypted: Bool) {
        #if DEBUG
        var line = "➡️ [\(context.id)] \(context.method) \(context.path)"
        if bodyEncrypted { line += " 🔒body已加密" }
        NSLog(line)
        if let params, !params.isEmpty,
           let data = try? JSONSerialization.data(withJSONObject: params, options: [.sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            NSLog("   params: \(trim(str))")
        }
        #endif
    }

    fileprivate static func upload(context: APIClient.ReqContext, folder: String, fileCount: Int, totalBytes: Int) {
        #if DEBUG
        NSLog("➡️ [\(context.id)] \(context.method) \(context.path) 🔼upload \(fileCount)个文件 · \(humanSize(totalBytes)) · folder=\(folder)")
        #endif
    }

    fileprivate static func response(context: APIClient.ReqContext, httpStatus: Int?, code: Int, ok: Bool, message: String?, preview: String?) {
        #if DEBUG
        let ms = Int((CFAbsoluteTimeGetCurrent() - context.start) * 1000)
        let mark = ok ? "✅" : "⚠️"
        NSLog("\(mark) [\(context.id)] \(context.method) \(context.path) http=\(httpStatus.map(String.init) ?? "-") code=\(code) \(ms)ms")
        if let message, !message.isEmpty { NSLog("   message: \(message)") }
        if let preview, !preview.isEmpty, preview != "null" { NSLog("   data: \(trim(preview))") }
        #endif
    }

    fileprivate static func failure(context: APIClient.ReqContext, httpStatus: Int?, kind: String, detail: String?) {
        #if DEBUG
        let ms = Int((CFAbsoluteTimeGetCurrent() - context.start) * 1000)
        NSLog("❌ [\(context.id)] \(context.method) \(context.path) http=\(httpStatus.map(String.init) ?? "-") \(ms)ms · \(kind)")
        if let detail, !detail.isEmpty { NSLog("   \(trim(detail))") }
        #endif
    }

    #if DEBUG
    private static func trim(_ text: String) -> String {
        let one = text.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
        guard one.count > previewLimit else { return one }
        return String(one.prefix(previewLimit)) + "…"
    }

    private static func humanSize(_ bytes: Int) -> String {
        let fmt = ByteCountFormatter()
        fmt.countStyle = .binary
        return fmt.string(fromByteCount: Int64(bytes))
    }
    #endif
}

extension Notification.Name {
    static let authExpired = Notification.Name("authExpired")
    static let userProfileUpdated = Notification.Name("userProfileUpdated")
    static let messageUnreadChanged = Notification.Name("messageUnreadChanged")
    static let userRoleDidChange = Notification.Name("userRoleDidChange")
    static let reviewsDidChange = Notification.Name("reviewsDidChange")
}
