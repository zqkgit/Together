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
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "退出登录", style: .destructive) { _ in
            AppRouter.shared.showLogin()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: 40, width: 1, height: 1)
        }
        present(alert, animated: true)
    }

    // MARK: - 身份弹窗

    private func showRoleSheet() {
        RoleSwitchSheet.show(
            roles: profile?.roles ?? (TokenManager.shared.userRole > 1 ? [1, TokenManager.shared.userRole] : [1]),
            onSelect: { [weak self] role in
                self?.switchRole(role)
            },
            onNeedAuth: { [weak self] role in
                let name = role == 2 ? "老师" : "工作室"
                self?.showToast("「\(name)」认证功能开发中")
            }
        )
    }

    private func switchRole(_ role: Int) {
        AuthService.switchRole(role) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let json):
                if let token = json["access_token"].string, !token.isEmpty {
                    TokenManager.shared.save(token: token, userId: TokenManager.shared.userId ?? "", role: role)
                }
                self.showToast("已切换身份")
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
        showToast("「\(item.title)」功能开发中")
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
