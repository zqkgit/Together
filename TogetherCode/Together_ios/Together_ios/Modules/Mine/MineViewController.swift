import UIKit
import SnapKit
import SwiftyJSON

/// 「我的」个人中心
/// 沉浸式固定头部（深绿延伸状态栏 + 毛玻璃统计卡）+ 下方菜单 TableView 独立滚动
final class MineViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {

    private struct MenuItem {
        let icon: String
        let title: String
    }

    private let tableView = UITableView(frame: .zero, style: .plain)

    private let menuItems: [MenuItem] = [
        MenuItem(icon: "figure.2.and.child.holdinghands", title: "我的孩子"),
        MenuItem(icon: "book.closed", title: "我的课程"),
        MenuItem(icon: "list.clipboard", title: "我的订单"),
        MenuItem(icon: "photo.on.rectangle.angled", title: "作品管理"),
        MenuItem(icon: "heart", title: "收藏与动态"),
        MenuItem(icon: "yensign.circle", title: "收益中心"),
        MenuItem(icon: "ticket", title: "优惠券"),
        MenuItem(icon: "gearshape", title: "设置")
    ]

    private let headerView = MineHeaderView()
    private var profile: MineProfile?
    private var stats = MineStats()

    private let authFooterView = MineAuthFooterView()

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
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
        // 背景深绿：头部与状态栏区域融为一体
        view.backgroundColor = Theme.Color.brandDark

        // 固定头部（不随列表滚动）
        headerView.onSettings = { [weak self] in self?.openSettings() }
        headerView.onIdentityTapped = { [weak self] in self?.showRoleSheet() }
        headerView.onStatTapped = { [weak self] index in
            guard let self else { return }
            let titles = ["我的孩子", "在学课程", "收藏作品"]
            if index == 0 {
                self.navigationController?.pushViewController(MyChildrenViewController(), animated: true)
                return
            }
            self.showToast("「\(titles[index])」功能开发中")
        }
        view.addSubview(headerView)
        headerView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
        }

        // 菜单列表：头部下方独立滚动
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.rowHeight = 56
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "MenuCell")
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(headerView.snp.bottom)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
        }

        authFooterView.onAuthTapped = { [weak self] in self?.showRoleSheet() }
        tableView.tableFooterView = authFooterView
    }

    // MARK: - 数据

    private func refreshData() {
        MineService.fetchMe { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let profile):
                self.profile = profile
                self.updateHeader()
                self.updateAuthFooter()
            case .failure(let error):
                self.showToast(error.message ?? "加载失败")
            }
        }

        MineService.fetchStats { [weak self] stats in
            guard let self else { return }
            self.stats = stats
            self.updateHeader()
        }
    }

    private func updateHeader() {
        headerView.refresh(profile: profile, stats: stats)
    }

    /// 已开通老师/工作室任一身份时隐藏底部开通条
    private func updateAuthFooter() {
        let needsAuth = !(profile?.hasRole(2) ?? false) && !(profile?.hasRole(3) ?? false)
        authFooterView.isHidden = !needsAuth
        if needsAuth {
            let width = view.bounds.width
            let targetSize = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
            let size = authFooterView.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
            authFooterView.frame = CGRect(x: 0, y: 0, width: width, height: size.height)
            tableView.tableFooterView = authFooterView
        }
    }

    // MARK: - 菜单

    private func openSettings() {
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }

    // MARK: - 身份弹窗

    private func showRoleSheet() {
        let owned = profile?.roles ?? (TokenManager.shared.userRole > 1 ? [1, TokenManager.shared.userRole] : [1])
        var statuses: [Int: String] = [:]
        RoleSwitchSheet.show(
            roles: owned,
            currentRole: profile?.current_role ?? TokenManager.shared.userRole,
            authStatuses: statuses,
            onSelect: { [weak self] role in
                self?.switchRole(role)
            },
            onNeedAuth: { [weak self] role in
                self?.handleNeedAuth(role)
            }
        )
        // 并行查询未开通身份的认证申请状态，返回后刷新弹窗行
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

    /// 未开通身份：查认证申请状态 → pending 显示审核中 / rejected 可重提 / unauth 进认证页
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
                    // 工作室认证占位（后续接入 StudioAuthViewController）
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
                    // 优先用后端返回的 user_id，避免旧空值覆盖（历史 bug）
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

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        menuItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MenuCell", for: indexPath)
        cell.backgroundColor = Theme.Color.surface
        cell.selectionStyle = .none

        let item = menuItems[indexPath.row]
        cell.imageView?.image = UIImage(systemName: item.icon)
        cell.imageView?.tintColor = Theme.Color.wood
        cell.textLabel?.text = item.title
        cell.textLabel?.font = .appBody(15)
        cell.textLabel?.textColor = Theme.Color.ink
        cell.accessoryType = .disclosureIndicator

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = menuItems[indexPath.row]
        if item.title == "设置" {
            openSettings()
            return
        }
        if item.title == "我的孩子" {
            navigationController?.pushViewController(MyChildrenViewController(), animated: true)
            return
        }
        if item.title == "我的课程" {
            openMyCourses()
            return
        }
        if item.title == "我的订单" {
            navigationController?.pushViewController(MyOrdersViewController(), animated: true)
            return
        }
        if item.title == "作品管理" {
            navigationController?.pushViewController(WorkManagementViewController(), animated: true)
            return
        }
        if item.title == "收藏与动态" {
            navigationController?.pushViewController(FavoritesAndDynamicsViewController(), animated: true)
            return
        }
        if item.title == "收益中心" {
            navigationController?.pushViewController(WalletViewController(), animated: true)
            return
        }
        showToast("「\(item.title)」功能开发中")
    }

    // MARK: - 我的课程

    /// 我的课程：直接进入，展示所有孩子的课程（页面内按孩子筛选）
    private func openMyCourses() {
        let vc = MyCoursesViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
}

/// 底部「开通老师/工作室身份」开通条
final class MineAuthFooterView: UIView {

    var onAuthTapped: (() -> Void)?

    private let container = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        addSubview(container)
        container.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.xl)
        }

        container.backgroundColor = Theme.Color.surface
        container.layer.cornerRadius = Theme.Radius.button
        container.layer.borderWidth = 1
        container.layer.borderColor = Theme.Color.line.cgColor

        let icon = UIImageView(image: UIImage(systemName: "person.badge.key"))
        icon.tintColor = Theme.Color.brand
        container.addSubview(icon)
        icon.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(22)
        }

        let label = UILabel()
        label.text = "开通老师/工作室身份，解锁教学与经营能力"
        label.font = .appLabel(12)
        label.textColor = Theme.Color.sub
        container.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalTo(icon.snp.trailing).offset(Theme.Spacing.s)
            $0.centerY.equalToSuperview()
            $0.trailing.lessThanOrEqualToSuperview().inset(96)
        }

        let button = UIButton(type: .system)
        button.setTitle("去认证", for: .normal)
        button.setTitleColor(Theme.Color.brand, for: .normal)
        button.titleLabel?.font = .appLabel(13)
        button.addTarget(self, action: #selector(didTap), for: .touchUpInside)
        container.addSubview(button)
        button.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
        }

        container.snp.makeConstraints { $0.height.equalTo(52) }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func didTap() {
        onAuthTapped?()
    }
}
