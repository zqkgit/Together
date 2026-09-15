import UIKit

/// 主 Tab 框架（对齐 PR 设计图 #parentHome）：首页 / 广场 / ➕发布 / 消息 / 我的
/// tabbar 外观与中间大加号由 BaseTabBarViewController 统一封装
/// 中间"发布"tab 点击后 present 模态发布页（右上角 × 关闭）
final class MainTabBarController: BaseTabBarViewController {

    override func setupTabs() {
        viewControllers = [
            makeTab(HomeViewController(), title: "首页", icon: "house"),
            makeTab(PlazaViewController(), title: "广场", icon: "rectangle.grid.2x2"),
            makeCenterTab(PlaceholderViewController(title: "发布"), tag: 2),
            makeTab(MessageViewController(), title: "消息", icon: "bell"),
            makeTab(MineViewController(), title: "我的", icon: "person")
        ]
        delegate = self
    }
}

// MARK: - 中间发布 tab 拦截

extension MainTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        guard let index = viewControllers?.firstIndex(of: viewController), index == 2 else {
            return true
        }
        // 点击中间大加号 → 模态发布页（按角色路由：老师走老师发布，家长走家长发布）
        let vc: UIViewController = TokenManager.shared.userRole == 2
            ? TeacherPostCreateViewController()
            : ParentPostCreateViewController()
        let publish = BaseNavigationController(rootViewController: vc)
        publish.modalPresentationStyle = .fullScreen
        present(publish, animated: true)
        return false
    }
}
