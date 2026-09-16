import UIKit

/// 启动路由：有登录态进主 Tab，否则进登录页
final class AppRouter {
    static let shared = AppRouter()

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthExpired),
            name: .authExpired,
            object: nil
        )
    }

    /// 根控制器
    func rootViewController() -> UIViewController {
        if TokenManager.shared.isLoggedIn {
            MessageSocketService.shared.connect()
            return MainTabBarController()
        }
        return makeLoginNavigation()
    }

    /// 登录成功 / 启动
    func showMainTab() {
        MessageSocketService.shared.connect()
        guard let window = window() else { return }
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = MainTabBarController()
        }
    }

    /// 退出登录 / 登录态失效
    func showLogin() {
        MessageSocketService.shared.disconnect()
        TokenManager.shared.clear()
        guard let window = window() else { return }
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = self.makeLoginNavigation()
        }
    }

    private func makeLoginNavigation() -> UINavigationController {
        BaseNavigationController(rootViewController: LoginViewController())
    }

    private func window() -> UIWindow? {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first
    }

    @objc private func handleAuthExpired() {
        showLogin()
    }
}
