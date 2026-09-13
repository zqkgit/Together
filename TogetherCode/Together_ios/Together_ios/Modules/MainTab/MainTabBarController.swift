import UIKit

/// 主 Tab 框架：首页 / 课程 / 广场 / 消息 / 我的
final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        viewControllers = [
            makeTab(HomeViewController(), title: "首页", icon: "house"),
            makeTab(CourseViewController(), title: "课程", icon: "book"),
            makeTab(PlazaViewController(), title: "广场", icon: "rectangle.grid.2x2"),
            makeTab(MessageViewController(), title: "消息", icon: "bell"),
            makeTab(MineViewController(), title: "我的", icon: "person")
        ]
    }

    private func makeTab(_ vc: UIViewController, title: String, icon: String) -> UINavigationController {
        vc.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: icon),
            selectedImage: UIImage(systemName: icon + ".fill")
        )
        return UINavigationController(rootViewController: vc)
    }
}
