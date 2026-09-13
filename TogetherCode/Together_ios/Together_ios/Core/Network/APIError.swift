import Foundation

/// 业务错误（后端 code != 0）
struct APIError: Error, LocalizedError {
    let code: Int
    let message: String

    init(code: Int, message: String) {
        self.code = code
        self.message = message
    }

    var errorDescription: String? { message }

    static let network = APIError(code: -1, message: "网络连接失败，请检查网络")
    static let unauthorized = APIError(code: 401, message: "登录已过期，请重新登录")
    static let parse = APIError(code: -2, message: "数据解析失败")
}
