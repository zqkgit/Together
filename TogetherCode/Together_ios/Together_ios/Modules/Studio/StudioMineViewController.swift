import UIKit
import SnapKit
import SwiftyJSON

/// 工作室端「我的」（对齐设计稿 studioMy · 结构对齐家长「我的」页）
/// 顶部封面（身份胶囊 / 设置 / 机构资料 / 白色经营统计卡）**固定不滚动**，下方菜单区独立滚动
final class StudioMineViewController: BaseViewController {

    // MARK: - 菜单

    private struct MenuItem {
        let icon: String
        let title: String
    }

    /// 第一组：经营与教务
    private let managementItems: [MenuItem] = [
        MenuItem(icon: "book.closed.fill", title: "课程管理"),
        MenuItem(icon: "person.3.fill", title: "学员管理"),
        MenuItem(icon: "person.crop.circle.badge.checkmark", title: "老师管理"),
        MenuItem(icon: "arrow.uturn.backward.circle.fill", title: "退款审核")
    ]

    /// 第二组：财务与分销
    private let financeItems: [MenuItem] = [
        MenuItem(icon: "yensign.circle.fill", title: "提现"),
        MenuItem(icon: "hands.sparkles.fill", title: "分销返利设置"),
        MenuItem(icon: "chart.bar.fill", title: "收益中心"),
        MenuItem(icon: "gearshape.fill", title: "设置")
    ]

    // MARK: - 视图

    /// 顶部固定封面（含白色经营统计卡），不随滚动
    private let headerView = StudioMineHeaderView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let menuCard = UIView()

    // MARK: - 数据

    private var studioProfile: StudioMineProfile?
    private var studioStats = StudioMineStats.empty
    /// /auth/me（身份切换弹窗需要 roles / current_role）
    private var mineProfile: MineProfile?

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "我的"
        view.backgroundColor = Theme.Color.bg
        setupLayout()
        refreshData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
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
        // 透明 tabbar 悬浮于内容之上：底部留出安全区（含 tabbar 高度）+ 间距，滚动到底时最后一行完整可见
        let bottom = view.safeAreaInsets.bottom + 12
        scrollView.contentInset.bottom = bottom
        scrollView.verticalScrollIndicatorInsets.bottom = bottom
    }

    // MARK: - 布局

    private func setupLayout() {
        view.backgroundColor = Theme.Color.bg

        // 顶部固定封面（含白色经营统计卡）：直接挂在 view 上，不进滚动视图
        headerView.onSettings = { [weak self] in self?.openSettings() }
        headerView.onIdentityTapped = { [weak self] in self?.showRoleSheet() }
        view.addSubview(headerView)
        headerView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
        }

        // 菜单区：封面下方独立滚动
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

        // 菜单卡（两组，卡片圆角 + 暖阴影）
        menuCard.backgroundColor = Theme.Color.surface
        menuCard.layer.cornerRadius = 18
        menuCard.layer.shadowColor = UIColor(hex: 0x2B2621).cgColor
        menuCard.layer.shadowOpacity = 0.05
        menuCard.layer.shadowRadius = 14
        menuCard.layer.shadowOffset = CGSize(width: 0, height: 6)
        contentView.addSubview(menuCard)
        menuCard.snp.makeConstraints {
            $0.top.equalToSuperview().offset(6)
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.bottom.equalToSuperview().inset(24)
        }
        setupMenu()
    }

    private func setupMenu() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        menuCard.addSubview(stack)
        stack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0))
        }

        for item in managementItems {
            stack.addArrangedSubview(makeMenuRow(item))
        }

        // 分组间隔
        let spacer = UIView()
        spacer.snp.makeConstraints { $0.height.equalTo(18) }
        stack.addArrangedSubview(spacer)

        for item in financeItems {
            stack.addArrangedSubview(makeMenuRow(item))
        }
    }

    private func makeMenuRow(_ item: MenuItem) -> StudioMenuRow {
        let row = StudioMenuRow(icon: item.icon, title: item.title)
        row.onTap = { [weak self] in self?.handleMenuTap(item) }
        return row
    }

    // MARK: - 数据

    private func refreshData() {
        StudioService.fetchMine { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let data):
                self.studioProfile = data.profile
                if let stats = data.stats { self.studioStats = stats }
                // 统计卡在封面头内部，随头部一起刷新（固定不动）
                self.headerView.refresh(profile: data.profile, stats: self.studioStats)
            case .failure(let error):
                self.headerView.refresh(profile: nil)
                self.showToast(error.message ?? "加载失败")
            }
        }

        MineService.fetchMe { [weak self] result in
            if case .success(let profile) = result {
                self?.mineProfile = profile
            }
        }
    }

    // MARK: - 菜单点击

    private func handleMenuTap(_ item: MenuItem) {
        // 设置项直接进入设置页（与封面右上角齿轮一致）
        if item.title == "设置" {
            openSettings()
            return
        }
        let tips: [String: String] = [
            "课程管理": "课程上下架、班级与排课管理将在下一阶段开放。",
            "学员管理": "按班级查看学员、剩余课时与续费提醒将在下一阶段开放。",
            "老师管理": "教师邀请、绑定审核与解绑将在下一阶段开放。",
            "退款审核": "退款申请审核与打款将在下一阶段开放。",
            "提现": "课程收入结算、提现与账单明细将在下一阶段开放。",
            "分销返利设置": "全局返利比例与单课程覆盖设置将在下一阶段开放。",
            "收益中心": "收入结算、账单明细与流水导出将在下一阶段开放。"
        ]
        let vc = StudioPlaceholderViewController(
            title: item.title,
            icon: item.icon,
            tip: tips[item.title] ?? "该功能将在下一阶段开放。"
        )
        navigationController?.pushViewController(vc, animated: true)
    }

    private func openSettings() {
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }

    // MARK: - 身份切换

    private func showRoleSheet() {
        let owned = mineProfile?.roles ?? [1, TokenManager.shared.userRole]
        var statuses: [Int: String] = [:]
        RoleSwitchSheet.show(
            roles: owned,
            currentRole: mineProfile?.current_role ?? TokenManager.shared.userRole,
            authStatuses: statuses,
            teacherName: mineProfile?.teacherRealName,
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
        // 已在当前身份：收起点选即可
        guard role != TokenManager.shared.userRole else { return }
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
            case .failure(let error):
                self.showToast(error.message ?? "切换失败")
            }
        }
    }
}

// MARK: - 菜单行
/// 工作室「我的」菜单行：浅绿圆角图标块 + 标题 + 右侧箭头
private final class StudioMenuRow: UIControl {

    var onTap: (() -> Void)?

    private let iconTile = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let chevron = UIImageView()

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? Theme.Color.surfaceAlt : .clear }
    }

    init(icon: String, title: String) {
        super.init(frame: .zero)
        setup(icon: icon, title: title)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup(icon: String, title: String) {
        backgroundColor = .clear
        addTarget(self, action: #selector(didTap), for: .touchUpInside)

        snp.makeConstraints { $0.height.equalTo(60) }

        iconTile.backgroundColor = Theme.Color.brandSoft
        iconTile.layer.cornerRadius = 10
        iconTile.isUserInteractionEnabled = false
        addSubview(iconTile)
        iconTile.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(18)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(34)
        }

        iconView.image = UIImage(systemName: icon)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 17, weight: .regular))
        iconView.tintColor = Theme.Color.brand
        iconView.contentMode = .scaleAspectFit
        iconTile.addSubview(iconView)
        iconView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.width.height.equalTo(20)
        }

        chevron.image = UIImage(systemName: "chevron.right")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold))
        chevron.tintColor = Theme.Color.muted
        chevron.contentMode = .scaleAspectFit
        chevron.isUserInteractionEnabled = false
        addSubview(chevron)
        chevron.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(16)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(8)
            $0.height.equalTo(14)
        }

        titleLabel.text = title
        titleLabel.font = .appSection(15)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(iconTile.snp.trailing).offset(12)
            $0.centerY.equalToSuperview()
            $0.trailing.lessThanOrEqualTo(chevron.snp.leading).offset(-8)
        }
    }

    @objc private func didTap() {
        onTap?()
    }
}

