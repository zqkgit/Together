import UIKit
import SnapKit
import SwiftyJSON

/// 老师「我的」页（与家长 MineViewController 拆分）
/// 沉浸式头部（身份切换 + 资料 + 统计）+ 老师专属菜单卡
/// 菜单卡样式与家长端 / 工作室端统一（MineMenuCardView）
final class TeacherMineViewController: BaseViewController {

    /// 第一组：教学与教务
    private static let teachingItems: [MineMenuItem] = [
        MineMenuItem(icon: "book.closed.fill", title: "我教的课程"),
        MineMenuItem(icon: "person.3.fill", title: "我的学生"),
        MineMenuItem(icon: "checkmark.seal.fill", title: "请假审批"),
        MineMenuItem(icon: "calendar", title: "课表与排课")
    ]

    /// 第二组：作品与财务
    private static let serviceItems: [MineMenuItem] = [
        MineMenuItem(icon: "photo.on.rectangle.angled", title: "作品管理"),
        MineMenuItem(icon: "yensign.circle", title: "收益中心"),
        MineMenuItem(icon: "star.fill", title: "评价与口碑"),
        MineMenuItem(icon: "gearshape", title: "设置")
    ]

    private let headerView = TeacherMineHeaderView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let menuCard = MineMenuCardView(groups: [teachingItems, serviceItems])
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
        // 从设置/资料编辑返回时刷新头部（名字/头像/签名变更即时生效）
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
        view.addSubview(headerView)
        headerView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            // 高度由内部约束自适应（与家长端一致，统计卡不压缩/不悬空）
        }
        headerView.onSettings = { [weak self] in self?.openSettings() }
        headerView.onIdentityTapped = { [weak self] in self?.showRoleSheet() }

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

        // 菜单卡（与家长端 / 工作室端同源组件）
        menuCard.onSelect = { [weak self] item in self?.handleMenuTap(item) }
        contentView.addSubview(menuCard)
        menuCard.snp.makeConstraints {
            $0.top.equalToSuperview().offset(6)
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.bottom.equalToSuperview().inset(24)
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
            teacherName: profile?.name,
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

    // MARK: - 菜单点击

    private func handleMenuTap(_ item: MineMenuItem) {
        switch item.title {
        case "我教的课程":
            push(MyTeachingCoursesViewController())
        case "我的学生":
            push(MyStudentsViewController())
        case "请假审批":
            push(LeaveApprovalViewController())
        case "课表与排课":
            push(TeacherTimetableViewController())
        case "作品管理":
            push(WorkManagementViewController())
        case "收益中心":
            push(WalletViewController())
        case "评价与口碑":
            push(ReputationViewController())
        case "设置":
            openSettings()
        default:
            showToast("「\(item.title)」功能开发中")
        }
    }

    private func push(_ vc: UIViewController) {
        navigationController?.pushViewController(vc, animated: true)
    }
}
