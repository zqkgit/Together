import UIKit

/// 基类导航控制器：
/// 1. push 二级页自动隐藏底部 tabBar（pop 回根时系统自动恢复）；
/// 2. 全局统一「透明导航栏 + 系统返回箭头（纯箭头无文字）」外观：
///    导航栏背景恒定透明，由各页面自行把背景色铺到顶部；
///    返回按钮统一用系统 backBarButtonItem —— 它固定在导航栏上，手势返回时不跟随页面移动、不抖动，
///    且系统自带的边缘侧滑返回手势（interactivePopGestureRecognizer）与长按返回历史菜单开箱即用、零维护。
final class BaseNavigationController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupGlobalNavBarAppearance()
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        // 非根页面自动隐藏底部 tabBar（pop 回根时系统自动恢复显示）
        if viewControllers.count > 0 {
            viewController.hidesBottomBarWhenPushed = true
        }
        super.pushViewController(viewController, animated: animated)
    }

    // MARK: - 全局导航栏外观

    private func setupGlobalNavBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.shadowColor = .clear
        appearance.backgroundColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: Theme.Color.ink,
            .font: UIFont.appSection(17)
        ]
        // 返回按钮：纯箭头、隐藏文字
        let back = UIBarButtonItemAppearance()
        back.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
        back.highlighted.titleTextAttributes = [.foregroundColor: UIColor.clear]
        appearance.backButtonAppearance = back

        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.isTranslucent = true
        // 返回箭头默认墨色；图片头 / 深色头页面可在 configureImmersiveNav 里改成白色
        navigationBar.tintColor = Theme.Color.ink
    }
}
