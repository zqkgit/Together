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
        // 切换身份（家长 / 老师 / 工作室）→ 重建整套 tab
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
        // 工作室角色：概览 / 广场 / ➕发布 / 消息 / 我的
        // 课程管理、学员管理、老师管理、退款审核已收进「我的」页菜单，不再单独占 tab
        if TokenManager.shared.userRole == 3 {
            viewControllers = [
                makeTab(StudioOverviewViewController(), title: "概览", icon: "house"),
                makeTab(PlazaViewController(), title: "广场", icon: "rectangle.grid.2x2"),
                makeCenterTab(PlaceholderViewController(title: "发布"), tag: 2),
                makeTab(MessageViewController(), title: "消息", icon: "bell"),
                makeTab(StudioMineViewController(), title: "我的", icon: "person")
            ]
            delegate = self
            return
        }

        // 第一个 tab 按角色切换：老师 → 工作台；家长 → 首页（PR #parentHome / #teacherWorkbench）
        // 第 5 个「我的」也按角色：老师 → TeacherMineViewController；家长 → MineViewController
        let isTeacher = TokenManager.shared.userRole == 2
        let firstVC: UIViewController = isTeacher
            ? TeacherWorkbenchViewController()
            : HomeViewController()
        let mineVC: UIViewController = isTeacher
            ? TeacherMineViewController()
            : MineViewController()
        viewControllers = [
            makeTab(firstVC, title: isTeacher ? "工作台" : "首页", icon: isTeacher ? "briefcase" : "house"),
            makeTab(PlazaViewController(), title: "广场", icon: "rectangle.grid.2x2"),
            makeCenterTab(PlaceholderViewController(title: "发布"), tag: 2),
            makeTab(MessageViewController(), title: "消息", icon: "bell"),
            makeTab(mineVC, title: "我的", icon: "person")
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
        // 点击中间大加号 → 发布：老师先选类型（孩子作品/动态）
        // 家长与工作室走通用动态发布（/v1/posts 无角色限制；
        // 老师作品链路 /v1/teacher/posts 目前 requireRole(2)，工作室如需发布作品需后端放行）
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
            let vc = ParentPostCreateViewController(postType: 2)
            let publish = BaseNavigationController(rootViewController: vc)
            publish.modalPresentationStyle = .fullScreen
            present(publish, animated: true)
        }
        return false
    }
}
