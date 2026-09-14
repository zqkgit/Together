import UIKit

/// 基础导航控制器：统一处理 push 时隐藏 tabBar（二级页不显示 tabbar，pop 回根自动恢复）
final class BaseNavigationController: UINavigationController {

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        // 非根页面自动隐藏底部 tabBar（pop 回根时系统自动恢复显示）
        if viewControllers.count > 0 {
            viewController.hidesBottomBarWhenPushed = true
        }
        super.pushViewController(viewController, animated: animated)
    }
}
