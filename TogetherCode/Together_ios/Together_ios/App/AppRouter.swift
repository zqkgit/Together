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
        if CommandLine.arguments.contains("--preview-teachers") {
            return makeTeacherPreviewRoot()
        }
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

    // MARK: - 临时预览钩子（验证后删除）

    private func makeTeacherPreviewRoot() -> UIViewController {
        let placeholder = UIViewController()
        placeholder.view.backgroundColor = Theme.Color.bg
        AuthService.loginPassword(phone: "13800000000", password: "123456") { result in
            guard case .success = result else { return }
            AuthService.switchRole(3) { _ in
                DispatchQueue.main.async {
                    guard let window = self.window() else { return }
                    var root: UIViewController = StudioTeacherListViewController()
                    if CommandLine.arguments.contains("--preview-teacher-apps") {
                        root = StudioTeacherApplicationViewController()
                    } else if CommandLine.arguments.contains("--preview-teacher-detail") {
                        root = StudioTeacherDetailViewController(teacherId: "1789980944623100591", name: "苏晚")
                    }
                    window.rootViewController = BaseNavigationController(rootViewController: root)
                }
            }
        }
        return placeholder
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
