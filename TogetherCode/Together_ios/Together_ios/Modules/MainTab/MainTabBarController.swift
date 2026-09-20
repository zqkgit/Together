import UIKit
import MBProgressHUD

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
        // 工作室角色：概览 / 课程 / ➕ / 学员 / 我的（无广场、无消息，对齐 PRD roles.studio）
        if TokenManager.shared.userRole == 3 {
            viewControllers = [
                makeTab(StudioPlaceholderViewController(title: "经营概览", icon: "house",
                                                         tip: "经营数据、退款待办与结算概览将在下一阶段开放"),
                        title: "概览", icon: "house"),
                makeTab(StudioPlaceholderViewController(title: "课程管理", icon: "book",
                                                         tip: "课程、班级与排课管理将在下一阶段开放"),
                        title: "课程", icon: "book"),
                makeCenterTab(PlaceholderViewController(title: "发布"), tag: 2),
                makeTab(StudioPlaceholderViewController(title: "学员管理", icon: "person.2",
                                                         tip: "按班级查看学员与课时明细"),
                        title: "学员", icon: "person.2"),
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
        // 工作室角色：阶段 1 中间「新建课程」尚未开放
        if TokenManager.shared.userRole == 3 {
            if let window = view.window
                ?? (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first {
                let hud = MBProgressHUD.showAdded(to: window, animated: true)
                hud.mode = .text
                hud.detailsLabel.text = "新建课程将在下一阶段开放"
                hud.hide(animated: true, afterDelay: 1.8)
            }
            return false
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
