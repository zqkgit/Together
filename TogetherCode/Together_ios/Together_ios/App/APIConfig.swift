import Foundation

/// 环境配置：Debug 默认连本地后端，可一键切换
enum AppEnvironment {
    case debug
    case staging
    case production

    var baseURL: String {
        // 临时覆盖优先级最高：UserDefaults custom_base_url，如 http://127.0.0.1:3001
        if let custom = UserDefaults.standard.string(forKey: "custom_base_url"), !custom.isEmpty {
            return custom
        }
        switch self {
        case .debug:
            #if targetEnvironment(simulator)
            // 模拟器共享 Mac 网络栈，127.0.0.1 指向运行后端的 Mac，本机联调恒定有效、不随网络变化
            return "http://127.0.0.1:3001"
            #else
            // 真机走 Mac 局域网 IP（换网络后需更新为当前 Mac IP；当前网络 10.6.x）
            return "http://10.6.1.89:3001"
            #endif
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

    /// 图片等静态资源根地址（无 /v1 前缀）
    static var imageBaseURL: String {
        AppEnvironment.current.baseURL
    }

    // MARK: - 极光推送

    /// 极光 AppKey（极光控制台获取；留空则跳过极光初始化，App 内消息仍走 WebSocket/轮询）
    /// TODO: 上线前填入真实 AppKey 与 masterSecret（后端 env JPUSH_APP_KEY / JPUSH_MASTER_SECRET）
    static let jpushAppKey = ""

    /// 渠道标识（极光后台统计用，与发布渠道一致即可）
    static let jpushChannel = "App Store"

    /// 是否生产环境推送（发布时改为 true，对应极光「生产证书」）
    static let jpushIsProduction = false

    // MARK: - 友盟统计

    /// 友盟 U-App AppKey（友盟+控制台创建应用后获取；留空则跳过统计初始化）
    /// TODO: 上线前填入真实 AppKey
    static let umengAppKey = ""

    /// 渠道标识（与极光共用渠道命名即可）
    static let umengChannel = "App Store"

    // MARK: - 接口加密（RSA-OAEP 传会话密钥 + AES-256-GCM）

    /// 是否启用接口加密（与后端 API_ENCRYPT_ENABLED 保持一致；上线开启，开发联调可关）
    static let apiEncryptEnabled = false

    /// 后端 RSA 公钥（DER SPKI，base64）——由后端 config/api_enc_public.der 导出
    static let apiEncryptPublicKey = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAoAgbPsM0kaTfV0JdccSz/KYu78D21rD9o1cWSRUVQX8KvxnweWZ74f0ALoxBA9v9wyL30y/SRJBJmn/CBX83oeP+/zMre7E2KamNV+Gj47q/1DmQBsNrVAKRIE1ON1lX/TCJr2XGIF5LoM6pLobLTOoLNg/Xk6qUUpGEHTjCrDoOW3+0OGouWvC9UjhTMDhJwu9quWgLRq1frZL0PzyJpXBZtFTRwVVNo4jQpeisS5LzdviU2NuTxtQ/eIUHAf3pktqxxRYYUOaEqYJP8EE/j07X6y4IOSlLg5xYxbUQ2xN15mo8CYNAYd1HMRqAXz8X7lGfhyDmarNTos37jQeFAQIDAQAB"
}

/// 相对路径图片 URL（后端上传返回 /uploads/...）统一转绝对地址
extension String {
    var resolvedImageURL: String {
        hasPrefix("http") ? self : APIConfig.imageBaseURL + self
    }
}
