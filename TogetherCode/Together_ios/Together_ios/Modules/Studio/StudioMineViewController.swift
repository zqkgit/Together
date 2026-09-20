import UIKit
import SnapKit
import SwiftyJSON

/// 工作室端「我的」（阶段 1：身份切换闭环；阶段 4 扩展为资料 / 教师管理 / 退款审核 / 财务结算等完整页）
final class StudioMineViewController: BaseViewController {

    private var profile: MineProfile?

    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "我的"
        view.backgroundColor = Theme.Color.bg
        setupUI()
        loadProfile()
    }

    private func setupUI() {
        let card = UIView()
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = 16
        view.addSubview(card)
        card.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        iconView.image = UIImage(systemName: "storefront.fill")
        iconView.tintColor = Theme.Color.brand
        iconView.contentMode = .scaleAspectFit
        card.addSubview(iconView)
        iconView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
            $0.top.bottom.equalToSuperview().inset(Theme.Spacing.l)
            $0.width.height.equalTo(48)
        }

        nameLabel.text = "工作室端"
        nameLabel.font = .appBody(16)
        nameLabel.textColor = Theme.Color.ink
        card.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(iconView.snp.trailing).offset(Theme.Spacing.m)
            $0.top.equalTo(iconView).offset(2)
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.l)
        }

        statusLabel.text = "已认证机构 · 经营功能陆续开放"
        statusLabel.font = .appLabel(12)
        statusLabel.textColor = Theme.Color.sub
        card.addSubview(statusLabel)
        statusLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.top.equalTo(nameLabel.snp.bottom).offset(4)
            $0.trailing.equalTo(nameLabel)
        }

        let switchButton = UIButton(type: .system)
        switchButton.setTitle("切换身份", for: .normal)
        switchButton.titleLabel?.font = .appBody(16)
        switchButton.setTitleColor(.white, for: .normal)
        switchButton.backgroundColor = Theme.Color.brand
        switchButton.layer.cornerRadius = 22
        switchButton.addTarget(self, action: #selector(didTapSwitch), for: .touchUpInside)
        view.addSubview(switchButton)
        switchButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalTo(card.snp.bottom).offset(Theme.Spacing.xl)
            $0.height.equalTo(44)
        }
    }

    private func loadProfile() {
        MineService.fetchMe { [weak self] result in
            if case .success(let profile) = result {
                self?.profile = profile
            }
        }
    }

    // MARK: - 身份切换

    @objc private func didTapSwitch() {
        let owned = profile?.roles ?? [1, TokenManager.shared.userRole]
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
            case .failure(let error):
                self.showToast(error.message ?? "切换失败")
            }
        }
    }
}
