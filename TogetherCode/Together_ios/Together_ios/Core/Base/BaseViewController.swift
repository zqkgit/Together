import UIKit
import MBProgressHUD

/// 基类控制器：统一背景、加载、提示、空态、沉浸式导航
class BaseViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupNavigationBar()
        // 系统返回按钮只显示箭头、不显示上一页标题（iOS 14+）
        navigationItem.backButtonDisplayMode = .minimal
    }

    private func setupNavigationBar() {
        navigationController?.navigationBar.prefersLargeTitles = false
    }

    // MARK: - 统一沉浸式导航（透明系统导航栏 + 系统返回箭头）

    /// 沉浸式导航：透明导航栏 + 系统返回箭头 + 居中标题。
    /// 全局导航栏外观已在 BaseNavigationController 统一为透明，这里只按页面需要设置标题色 / 返回箭头色
    /// （深色头、图片头页面传白色）。返回按钮统一用系统 backBarButtonItem：它固定在导航栏上，
    /// 手势返回时不会跟随页面横向移动、不抖动，且自带边缘侧滑返回与长按返回历史菜单。
    /// 子类在 viewWillAppear 调用；viewWillDisappear 调用 restoreSystemNav() 复位着色。
    /// - Parameters:
    ///   - title: 导航标题
    ///   - titleColor: 标题颜色
    ///   - backBackground: 已废弃（系统返回按钮无背景），保留参数以兼容旧调用
    ///   - backTint: 返回箭头颜色（深色头页面传 .white）
    func configureImmersiveNav(
        title: String? = nil,
        titleColor: UIColor = Theme.Color.ink,
        backBackground: UIColor = Theme.Color.ink.withAlphaComponent(0.06),
        backTint: UIColor = Theme.Color.ink
    ) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.shadowColor = .clear
        appearance.backgroundColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: titleColor,
            .font: UIFont.appSection(17)
        ]
        let back = UIBarButtonItemAppearance()
        back.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
        back.highlighted.titleTextAttributes = [.foregroundColor: UIColor.clear]
        appearance.backButtonAppearance = back

        guard let nav = navigationController else { return }
        nav.navigationBar.standardAppearance = appearance
        nav.navigationBar.scrollEdgeAppearance = appearance
        nav.navigationBar.compactAppearance = appearance
        nav.navigationBar.isTranslucent = true
        // 系统返回箭头颜色
        nav.navigationBar.tintColor = backTint
        navigationItem.title = title
    }

    /// 恢复默认导航外观（沉浸式页 viewWillDisappear 调用：只重置标题/箭头着色，背景保持透明，避免手势转场晃动）
    func restoreSystemNav() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: Theme.Color.ink,
            .font: UIFont.appSection(17)
        ]
        let back = UIBarButtonItemAppearance()
        back.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
        appearance.backButtonAppearance = back
        guard let nav = navigationController else { return }
        nav.navigationBar.standardAppearance = appearance
        nav.navigationBar.scrollEdgeAppearance = appearance
        nav.navigationBar.compactAppearance = appearance
        // 全局统一透明导航栏，isTranslucent 恒定 true
        nav.navigationBar.isTranslucent = true
        nav.navigationBar.tintColor = Theme.Color.ink
    }

    // MARK: - 加载

    private var hud: MBProgressHUD?

    func showLoading(_ text: String = "加载中...") {
        if hud == nil {
            hud = MBProgressHUD.showAdded(to: view, animated: true)
        }
        hud?.mode = .indeterminate
        hud?.label.text = text
    }

    func hideLoading() {
        hud?.hide(animated: true)
        hud = nil
    }

    // MARK: - 提示

    func showToast(_ message: String) {
        guard let window = view.window ?? (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first else {
            return
        }
        let hud = MBProgressHUD.showAdded(to: window, animated: true)
        hud.mode = .text
        hud.detailsLabel.text = message
        hud.hide(animated: true, afterDelay: 1.8)
    }
}
