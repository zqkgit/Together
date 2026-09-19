import Foundation
import Security

/// 登录态存储：token（Keychain 安全存储）+ 用户信息（UserDefaults）
final class TokenManager {
    static let shared = TokenManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let accessToken = "together_access_token"
        static let userId = "together_user_id"
        static let userRole = "together_user_role"
        static let userInfo = "together_user_info"
    }

    private init() {}

    /// 当前登录 token
    var accessToken: String? {
        keychainGet(Keys.accessToken)
    }

    /// 是否已登录
    var isLoggedIn: Bool {
        guard let token = accessToken, !token.isEmpty else { return false }
        return true
    }

    /// 当前用户 id
    var userId: String? {
        defaults.string(forKey: Keys.userId)
    }

    /// 当前角色（1 家长 / 2 老师）
    var userRole: Int {
        defaults.integer(forKey: Keys.userRole)
    }

    /// 用户信息字典（昵称/手机号/头像等）
    private var userInfoDict: [String: Any]? {
        guard let data = defaults.data(forKey: Keys.userInfo) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// 昵称
    var nickname: String {
        userInfoDict?["nickname"] as? String ?? ""
    }

    /// 手机号
    var phone: String {
        userInfoDict?["phone"] as? String ?? ""
    }

    /// 头像
    var avatar: String? {
        userInfoDict?["avatar"] as? String
    }

    /// 保存登录态
    func save(token: String, userId: String, role: Int = 1, userInfo: [String: Any]? = nil) {
        keychainSet(token, forKey: Keys.accessToken)
        defaults.set(userId, forKey: Keys.userId)
        defaults.set(role, forKey: Keys.userRole)
        if let userInfo {
            if let data = try? JSONSerialization.data(withJSONObject: userInfo) {
                defaults.set(data, forKey: Keys.userInfo)
            }
        }
        // 登录/注册成功：上报极光设备（未配置 AppKey 或模拟器无 registrationID 时静默跳过）
        PushManager.shared.reportDevice()
        // 统计：登录成功
        AnalyticsManager.shared.event("user_login")
    }

    /// 更新角色
    func updateRole(_ role: Int) {
        defaults.set(role, forKey: Keys.userRole)
    }

    /// 退出登录：先解绑极光设备，再清空登录态
    func clear() {
        // 解绑极光推送（内部先捕获 token 再发请求；未配置/无 registrationID 时静默跳过）
        PushManager.shared.unbindDevice()
        keychainDelete(Keys.accessToken)
        defaults.removeObject(forKey: Keys.userId)
        defaults.removeObject(forKey: Keys.userRole)
        defaults.removeObject(forKey: Keys.userInfo)
    }

    // MARK: - Keychain（原生 SecItem）

    private var service = "ymjr.com.Together-ios"

    private func keychainSet(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        // 已存在则更新，否则新增
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var newQuery = query
            newQuery[kSecValueData as String] = data
            SecItemAdd(newQuery as CFDictionary, nil)
        }
    }

    private func keychainGet(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func keychainDelete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
