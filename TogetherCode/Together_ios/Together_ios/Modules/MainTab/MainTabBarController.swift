import UIKit

/// 主 Tab 框架（对齐 PR 设计图 #parentHome）：首页 / 广场 / ➕发布 / 消息 / 我的
final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        viewControllers = [
            makeTab(HomeViewController(), title: "首页", icon: "house"),
            makeTab(PlazaViewController(), title: "广场", icon: "rectangle.grid.2x2"),
            makeTab(PlaceholderViewController(title: "发布"), title: "", icon: "plus.circle.fill", tag: 2),
            makeTab(MessageViewController(), title: "消息", icon: "bell"),
            makeTab(MineViewController(), title: "我的", icon: "person")
        ]
    }

    private func makeTab(_ vc: UIViewController, title: String, icon: String, tag: Int? = nil) -> UINavigationController {
        vc.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: icon),
            selectedImage: UIImage(systemName: icon)
        )
        if let tag {
            vc.tabBarItem.tag = tag
        }
        return UINavigationController(rootViewController: vc)
    }
}
