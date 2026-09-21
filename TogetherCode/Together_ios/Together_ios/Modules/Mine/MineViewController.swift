import UIKit
import SnapKit
import SwiftyJSON

/// 「我的」个人中心
/// 沉浸式固定头部（深绿延伸状态栏 + 毛玻璃统计卡）+ 下方菜单卡独立滚动
/// 菜单卡样式与老师端 / 工作室端统一（MineMenuCardView）
final class MineViewController: BaseViewController {

    /// 第一组：我的内容
    private static let contentItems: [MineMenuItem] = [
        MineMenuItem(icon: "figure.2.and.child.holdinghands", title: "我的孩子"),
        MineMenuItem(icon: "book.closed", title: "我的课程"),
        MineMenuItem(icon: "list.clipboard", title: "我的订单"),
        MineMenuItem(icon: "photo.on.rectangle.angled", title: "作品管理")
    ]

    /// 第二组：资产与服务
    private static let serviceItems: [MineMenuItem] = [
        MineMenuItem(icon: "heart", title: "收藏与动态"),
        MineMenuItem(icon: "yensign.circle", title: "收益中心"),
        MineMenuItem(icon: "ticket", title: "优惠券"),
        MineMenuItem(icon: "gearshape", title: "设置")
    ]

    private let headerView = MineHeaderView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let menuCard = MineMenuCardView(groups: [contentItems, serviceItems])
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
        // 从设置/资料编辑返回时刷新头部（昵称/头像/城市/签名变更即时生效）
        refreshData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if navigationController?.viewControllers.count ?? 0 > 1 {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 透明 tabbar 悬浮于内容之上：底部留出安全区（含 tabbar 高度）+ 间距
        let bottom = view.safeAreaInsets.bottom + 12
        scrollView.contentInset.bottom = bottom
        scrollView.verticalScrollIndicatorInsets.bottom = bottom
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

        // 菜单区：头部下方独立滚动
        scrollView.backgroundColor = Theme.Color.bg
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints {
            $0.top.equalTo(headerView.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.width.equalTo(scrollView)
        }

        // 菜单卡（与老师端 / 工作室端同源组件）
        menuCard.onSelect = { [weak self] item in self?.handleMenuTap(item) }
        contentView.addSubview(menuCard)
        menuCard.snp.makeConstraints {
            $0.top.equalToSuperview().offset(6)
            $0.leading.trailing.equalToSuperview().inset(18)
        }

        // 底部「开通老师/工作室身份」开通条
        authFooterView.onAuthTapped = { [weak self] in self?.showRoleSheet() }
        authFooterView.isHidden = true
        contentView.addSubview(authFooterView)
        authFooterView.snp.makeConstraints {
            $0.top.equalTo(menuCard.snp.bottom)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(0)
            $0.bottom.equalToSuperview().inset(24)
        }
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

        var height: CGFloat = 0
        if needsAuth {
            let width = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
            let targetSize = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
            height = authFooterView.systemLayoutSizeFitting(
                targetSize,
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            ).height
        }
        // 隐藏时高度归零，避免占位留白
        authFooterView.snp.remakeConstraints {
            $0.top.equalTo(menuCard.snp.bottom).offset(needsAuth ? Theme.Spacing.l : 0)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(height)
            $0.bottom.equalToSuperview().inset(24)
        }
    }

    // MARK: - 菜单

    private func openSettings() {
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }

    // MARK: - 身份弹窗

    private func showRoleSheet() {
        // 身份可能在 App 外发生变化（如平台刚在后台审核通过工作室入驻），先拉最新身份再弹窗，
        // 否则本地缓存的 roles 不含新身份，会把「已开通」误判成「去认证」
        MineService.fetchMe { [weak self] result in
            guard let self else { return }
            if case .success(let profile) = result {
                self.profile = profile
                self.updateHeader()
                self.updateAuthFooter()
            }
            self.presentRoleSheet()
        }
    }

    private func presentRoleSheet() {
        let owned = profile?.roles ?? (TokenManager.shared.userRole > 1 ? [1, TokenManager.shared.userRole] : [1])
        var statuses: [Int: String] = [:]
        RoleSwitchSheet.show(
            roles: owned,
            currentRole: profile?.current_role ?? TokenManager.shared.userRole,
            authStatuses: statuses,
            teacherName: profile?.teacherRealName,
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
                // 档案已审核通过（本地身份缓存可能尚未刷新）→ 直接切换，不再进入认证表单
                if status == "approved" {
                    self.switchRole(role)
                    return
                }
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
                    let vc: StudioAuthViewController
                    switch status {
                    case "pending":
                        vc = StudioAuthViewController(status: "pending")
                    case "rejected":
                        vc = StudioAuthViewController(status: "rejected", reason: reason, apply: apply)
                    default:
                        vc = StudioAuthViewController(apply: apply)
                    }
                    self.navigationController?.pushViewController(vc, animated: true)
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

    // MARK: - 菜单点击

    private func handleMenuTap(_ item: MineMenuItem) {
        switch item.title {
        case "设置":
            openSettings()
        case "我的孩子":
            push(MyChildrenViewController())
        case "我的课程":
            openMyCourses()
        case "我的订单":
            push(MyOrdersViewController())
        case "作品管理":
            push(WorkManagementViewController())
        case "收藏与动态":
            push(FavoritesAndDynamicsViewController())
        case "收益中心":
            push(WalletViewController())
        default:
            showToast("「\(item.title)」功能开发中")
        }
    }

    private func push(_ vc: UIViewController) {
        navigationController?.pushViewController(vc, animated: true)
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
