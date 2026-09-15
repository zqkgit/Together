import UIKit

/// 主 Tab 框架（对齐 PR 设计图 #parentHome）：首页 / 广场 / ➕发布 / 消息 / 我的
/// tabbar 外观与中间大加号由 BaseTabBarViewController 统一封装
final class MainTabBarController: BaseTabBarViewController {

    override func setupTabs() {
        viewControllers = [
            makeTab(HomeViewController(), title: "首页", icon: "house"),
            makeTab(PlazaViewController(), title: "广场", icon: "rectangle.grid.2x2"),
            makeCenterTab(PlaceholderViewController(title: "发布"), tag: 2),
            makeTab(MessageViewController(), title: "消息", icon: "bell"),
            makeTab(MineViewController(), title: "我的", icon: "person")
        ]

        // TEMP: 验证支付按钮高度
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self, let nav = self.selectedViewController as? UINavigationController else { return }
            nav.pushViewController(MyOrdersViewController(), animated: true)
        }
    }
}
