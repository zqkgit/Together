import UIKit
import SnapKit
import SwiftyJSON

/// 老师「我的」页（与家长 MineViewController 拆分）
/// 沉浸式头部（身份切换 + 资料 + 统计）+ 老师专属菜单
final class TeacherMineViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {

    private struct MenuItem {
        let icon: String
        let title: String
    }

    private let tableView = UITableView(frame: .zero, style: .plain)

    private let menuItems: [MenuItem] = [
        MenuItem(icon: "book.closed.fill", title: "我教的课程"),
        MenuItem(icon: "person.3.fill", title: "我的学生"),
        MenuItem(icon: "calendar", title: "课表与排课"),
        MenuItem(icon: "photo.on.rectangle.angled", title: "作品管理"),
        MenuItem(icon: "yensign.circle", title: "收益中心"),
        MenuItem(icon: "star.fill", title: "评价与口碑"),
        MenuItem(icon: "gearshape", title: "设置")
    ]

    private let headerView = TeacherMineHeaderView()
    private var profile: TeacherMineProfile?
    private var stats = TeacherMineStats(active_students: nil, total_lessons: nil, post_count: nil)

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.brandDark
        setupLayout()
        refreshData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if navigationController?.viewControllers.count ?? 0 > 1 {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    private func setupLayout() {
        view.addSubview(headerView)
        headerView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(320)
        }
        headerView.onSettings = { [weak self] in self?.openSettings() }
        headerView.onIdentityTapped = { [weak self] in self?.showRoleSheet() }

        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.register(MenuCell.self, forCellReuseIdentifier: MenuCell.reuseID)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 56
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(headerView.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    // MARK: - 数据

    private func refreshData() {
        TeacherService.fetchMine { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let data):
                self.profile = data.profile
                if let s = data.stats {
                    self.stats = s
                }
                self.headerView.refresh(profile: self.profile, stats: self.stats)
            case .failure(let error):
                self.showToast(error.message ?? "加载失败")
            }
        }
    }

    private func openSettings() {
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }

    // MARK: - 身份弹窗（复用家长侧逻辑）

    private func showRoleSheet() {
        let owned = profile != nil ? [1, 2] : [1, TokenManager.shared.userRole > 1 ? TokenManager.shared.userRole : 1]
        var statuses: [Int: String] = [:]
        RoleSwitchSheet.show(
            roles: owned,
            currentRole: 2,
            authStatuses: statuses,
            onSelect: { [weak self] role in
                self?.switchRole(role)
            },
            onNeedAuth: { [weak self] role in
                self?.handleNeedAuth(role)
            }
        )
        let unownedRoles = [2, 3].filter { !owned.contains($0) }
        guard !unownedRoles.isEmpty else { return }
        let group = DispatchGroup()
        for role in unownedRoles {
            group.enter()
            AuthService.getRoleApplyStatus(role == 2 ? "teacher" : "studio") { result in
                defer { group.leave() }
                if case .success(let json) = result {
                    statuses[role] = json["status"].stringValue
                }
            }
        }
        group.notify(queue: .main) {
            RoleSwitchSheet.updateStatuses(statuses)
        }
    }

    private func handleNeedAuth(_ role: Int) {
        let roleKey = role == 2 ? "teacher" : "studio"
        showLoading()
        AuthService.getRoleApplyStatus(roleKey) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success(let json):
                let status = json["status"].stringValue
                let reason = json["reason"].string
                let apply = json["apply"]
                if role == 2 {
                    let vc: TeacherAuthViewController
                    switch status {
                    case "pending":
                        vc = TeacherAuthViewController(status: "pending")
                    case "rejected":
                        vc = TeacherAuthViewController(status: "rejected", reason: reason, apply: apply)
                    default:
                        vc = TeacherAuthViewController(apply: apply)
                    }
                    self.navigationController?.pushViewController(vc, animated: true)
                } else {
                    if status == "pending" {
                        self.showToast("工作室认证审核中，请等待平台审核")
                    } else {
                        self.showToast("「工作室」认证功能开发中")
                    }
                }
            case .failure(let error):
                self.showToast(error.message ?? "查询认证状态失败")
            }
        }
    }

    private func switchRole(_ role: Int) {
        AuthService.switchRole(role) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let json):
                if let token = json["access_token"].string, !token.isEmpty {
                    let uid = json["user"]["user_id"].string ?? TokenManager.shared.userId ?? ""
                    TokenManager.shared.save(token: token, userId: uid, role: role)
                }
                self.showToast("已切换身份")
                NotificationCenter.default.post(name: .userRoleDidChange, object: nil)
                self.refreshData()
            case .failure(let error):
                self.showToast(error.message ?? "切换失败")
            }
        }
    }

    // MARK: - TableView

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        menuItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MenuCell.reuseID, for: indexPath) as! MenuCell
        let item = menuItems[indexPath.row]
        cell.configure(icon: item.icon, title: item.title)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = menuItems[indexPath.row]
        switch item.title {
        case "我教的课程":
            navigationController?.pushViewController(MyTeachingCoursesViewController(), animated: true)
        case "课表与排课":
            navigationController?.pushViewController(TeacherTimetableViewController(), animated: true)
        case "作品管理":
            navigationController?.pushViewController(WorkManagementViewController(), animated: true)
        case "收益中心":
            navigationController?.pushViewController(WalletViewController(), animated: true)
        case "设置":
            openSettings()
        default:
            showToast("「\(item.title)」功能开发中")
        }
    }
}
