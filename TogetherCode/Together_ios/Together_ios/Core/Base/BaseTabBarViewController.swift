import UIKit

/// 基础 TabBar 框架：统一 tabbar 外观（主题色选中态、不透明背景）+ 中间大加号发布按钮
/// 子类实现 setupTabs() 组装 tab 列表；普通 tab 用 makeTab，中间发布 tab 用 makeCenterTab
class BaseTabBarViewController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTabBar()
        setupTabs()
    }

    /// 子类实现：组装 tab 列表
    func setupTabs() {
        // 默认空实现，子类覆盖
    }

    // MARK: - TabBar 外观

    private func configureTabBar() {
        // 选中态主题色（未选中浅灰）
        tabBar.tintColor = Theme.Color.brand
        tabBar.unselectedItemTintColor = UIColor(hex: 0x9C948A)

        // 透明背景（沉浸式）：bar 不再遮挡页面内容，滚动到顶也不会"弹回"不透明
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear        // 去掉顶部分隔线
        appearance.backgroundEffect = nil       // 不要毛玻璃，纯透明
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        tabBar.isTranslucent = true
    }

    // MARK: - Tab 工厂

    /// 普通 tab：系统图标 + 标题，包一层 BaseNavigationController（push 自动隐藏 tabbar）
    func makeTab(_ vc: UIViewController, title: String, icon: String, tag: Int? = nil) -> BaseNavigationController {
        vc.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: icon),
            selectedImage: UIImage(systemName: icon)
        )
        if let tag {
            vc.tabBarItem.tag = tag
        }
        return BaseNavigationController(rootViewController: vc)
    }

    /// 中间发布 tab：大号加号图标（无标题），视觉上比普通 tab 更突出
    func makeCenterTab(_ vc: UIViewController, tag: Int? = nil) -> BaseNavigationController {
        let config = UIImage.SymbolConfiguration(pointSize: 32, weight: .medium)
        let image = UIImage(systemName: "plus.circle.fill", withConfiguration: config)
        vc.tabBarItem = UITabBarItem(title: nil, image: image, selectedImage: image)
        // 大图标在 49pt 的 tabbar 里会偏下，微调上移保持视觉居中
        vc.tabBarItem.imageInsets = UIEdgeInsets(top: -5, left: 0, bottom: 5, right: 0)
        vc.tabBarItem.tag = tag ?? 2
        return BaseNavigationController(rootViewController: vc)
    }
}
