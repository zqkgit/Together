import UIKit

/// 主 Tab 框架（对齐 PR 设计图 #parentHome）：首页 / 广场 / ➕发布 / 消息 / 我的
/// tabbar 外观与中间大加号由 BaseTabBarViewController 统一封装
/// 中间"发布"tab 点击后 present 模态发布页（右上角 × 关闭）
final class MainTabBarController: BaseTabBarViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // 消息未读数 → TabBar 角标
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUnreadChanged(_:)),
            name: .messageUnreadChanged,
            object: nil
        )
        // 切换身份（家长 ↔ 老师）→ 重建第一个 tab（首页/工作台）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRoleDidChange),
            name: .userRoleDidChange,
            object: nil
        )
    }

    @objc private func handleRoleDidChange() {
        setupTabs()
    }

    override func setupTabs() {
        // 第一个 tab 按角色切换：老师 → 工作台；家长 → 首页（PR #parentHome / #teacherWorkbench）
        let firstVC: UIViewController = TokenManager.shared.userRole == 2
            ? TeacherWorkbenchViewController()
            : HomeViewController()
        viewControllers = [
            makeTab(firstVC, title: TokenManager.shared.userRole == 2 ? "工作台" : "首页", icon: TokenManager.shared.userRole == 2 ? "briefcase" : "house"),
            makeTab(PlazaViewController(), title: "广场", icon: "rectangle.grid.2x2"),
            makeCenterTab(PlaceholderViewController(title: "发布"), tag: 2),
            makeTab(MessageViewController(), title: "消息", icon: "bell"),
            makeTab(MineViewController(), title: "我的", icon: "person")
        ]
        delegate = self
    }

    @objc private func handleUnreadChanged(_ note: Notification) {
        let unread = (note.userInfo?["unread"] as? Int) ?? 0
        guard let items = tabBar.items, items.count > 3 else { return }
        items[3].badgeValue = unread > 0 ? (unread > 99 ? "99+" : "\(unread)") : nil
    }
}

// MARK: - 中间发布 tab 拦截

extension MainTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        guard let index = viewControllers?.firstIndex(of: viewController), index == 2 else {
            return true
        }
        // 点击中间大加号 → 发布：老师先选类型（孩子作品/动态），家长直接进家长发布
        if TokenManager.shared.userRole == 2 {
            let sheet = ThemeActionSheet(title: "发布类型", actions: [("孩子作品", false), ("老师作品", false)])
            sheet.onSelect = { [weak self] index in
                guard let self else { return }
                let vc = TeacherPostCreateViewController(postType: index == 0 ? 2 : 1)
                let publish = BaseNavigationController(rootViewController: vc)
                publish.modalPresentationStyle = .fullScreen
                // 等类型菜单 dismiss 完成后再 present
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    self.present(publish, animated: true)
                }
            }
            present(sheet, animated: false)
        } else {
            let vc = ParentPostCreateViewController()
            let publish = BaseNavigationController(rootViewController: vc)
            publish.modalPresentationStyle = .fullScreen
            present(publish, animated: true)
        }
        return false
    }
}
