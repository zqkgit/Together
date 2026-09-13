import Foundation

/// 环境配置：Debug 默认连本地后端，可一键切换
enum AppEnvironment {
    case debug
    case staging
    case production

    var baseURL: String {
        switch self {
        case .debug:
            return UserDefaults.standard.string(forKey: "custom_base_url") ?? "http://127.0.0.1:3001"
        case .staging:
            return "https://staging-api.example.com"
        case .production:
            return "https://api.example.com"
        }
    }

    static var current: AppEnvironment = .debug
}

/// 全局配置
enum APIConfig {
    /// 后端接口前缀
    static let apiPrefix = "/v1"

    /// 上传目录白名单（与后端 /v1/upload folder 白名单一致）
    static let uploadFolders = ["common", "avatar", "course", "post", "work", "studio", "cert"]

    static var baseURL: String {
        AppEnvironment.current.baseURL + apiPrefix
    }
}
