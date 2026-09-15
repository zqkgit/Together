import UIKit
import SnapKit

/// 设置（对齐 PR 设计图）：分组列表 + 退出登录
final class SettingsViewController: BaseViewController {

    fileprivate struct Row {
        let icon: String
        let title: String
        let value: String?
        let hasSwitch: Bool
    }

    private let sections: [[Row]] = [
        [
            Row(icon: "person.crop.circle", title: "个人资料", value: nil, hasSwitch: false),
            Row(icon: "lock.shield", title: "账号与安全", value: nil, hasSwitch: false)
        ],
        [
            Row(icon: "bell.badge", title: "消息通知", value: nil, hasSwitch: true),
            Row(icon: "creditcard", title: "支付与钱包", value: nil, hasSwitch: false)
        ],
        [
            Row(icon: "info.circle", title: "关于艺启", value: "v1.0", hasSwitch: false),
            Row(icon: "headphones", title: "联系客服", value: nil, hasSwitch: false)
        ]
    ]

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let logoutButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupTable()
        setupLogout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "设置")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    private func setupTable() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(SettingsCell.self, forCellReuseIdentifier: SettingsCell.reuseId)
        tableView.rowHeight = 54
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func setupLogout() {
        logoutButton.setTitle("退出登录", for: .normal)
        logoutButton.setTitleColor(UIColor(hex: 0xE5484D), for: .normal)
        logoutButton.titleLabel?.font = .appBody(15)
        logoutButton.backgroundColor = Theme.Color.surface
        logoutButton.layer.cornerRadius = 12
        logoutButton.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)
        view.addSubview(logoutButton)
        logoutButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(50)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-Theme.Spacing.xl)
        }
    }

    @objc private func logoutTapped() {
        ThemeAlertView.show(
            title: "退出登录",
            message: "确定要退出当前账号吗？",
            confirmTitle: "退出",
            cancelTitle: "取消",
            onConfirm: { [weak self] in
                guard let self else { return }
                self.showLoading("正在退出...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.hideLoading()
                    AppRouter.shared.showLogin()
                }
            }
        )
    }

    private func handleRow(_ indexPath: IndexPath) {
        let row = sections[indexPath.section][indexPath.row]
        switch row.title {
        case "个人资料":
            navigationController?.pushViewController(EditProfileViewController(), animated: true)
        case "账号与安全":
            navigationController?.pushViewController(AccountSecurityViewController(), animated: true)
        case "消息通知":
            break // 开关已内联处理
        case "支付与钱包":
            navigationController?.pushViewController(WalletViewController(), animated: true)
        case "关于艺启":
            navigationController?.pushViewController(AboutViewController(), animated: true)
        case "联系客服":
            ThemeAlertView.show(
                title: "联系客服",
                message: "客服微信：yiqi_kefu\n服务时间：9:00 - 21:00",
                confirmTitle: "知道了"
            )
        default:
            break
        }
    }
}

// MARK: - UITableView

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SettingsCell.reuseId, for: indexPath) as! SettingsCell
        let row = sections[indexPath.section][indexPath.row]
        cell.configure(row: row)
        cell.onSwitchChanged = { [weak self] isOn in
            // 通知开关持久化（本地）
            UserDefaults.standard.set(isOn, forKey: "push_notification_enabled")
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        handleRow(indexPath)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        UIView(frame: CGRect(x: 0, y: 0, width: 0, height: section == 0 ? 8 : 20))
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? 8 : 20
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { nil }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 0.01 }
}

// MARK: - 设置行

final class SettingsCell: UITableViewCell {

    static let reuseId = "SettingsCell"

    var onSwitchChanged: ((Bool) -> Void)?

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let chevron = UIImageView()
    private let switchControl = UISwitch()
    private let bottomLine = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.surface
        selectionStyle = .none

        iconView.tintColor = Theme.Color.brand
        iconView.contentMode = .scaleAspectFit
        contentView.addSubview(iconView)
        iconView.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(22)
        }

        titleLabel.font = .appBody(15)
        titleLabel.textColor = Theme.Color.ink
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(iconView.snp.trailing).offset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
        }

        valueLabel.font = .appLabel(13)
        valueLabel.textColor = Theme.Color.sub
        contentView.addSubview(valueLabel)
        valueLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(34)
            $0.centerY.equalToSuperview()
        }

        chevron.image = UIImage(systemName: "chevron.right")
        chevron.tintColor = Theme.Color.line
        chevron.contentMode = .scaleAspectFit
        contentView.addSubview(chevron)
        chevron.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(9)
            $0.height.equalTo(14)
        }

        switchControl.onTintColor = Theme.Color.brand
        switchControl.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        switchControl.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        contentView.addSubview(switchControl)
        switchControl.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
        }

        bottomLine.backgroundColor = Theme.Color.line
        contentView.addSubview(bottomLine)
        bottomLine.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(48)
            $0.trailing.bottom.equalToSuperview()
            $0.height.equalTo(0.5)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    fileprivate func configure(row: SettingsViewController.Row) {
        iconView.image = UIImage(systemName: row.icon)
        titleLabel.text = row.title
        if let value = row.value {
            valueLabel.text = value
        } else {
            valueLabel.text = ""
        }
        let hasSwitch = row.hasSwitch
        switchControl.isHidden = !hasSwitch
        chevron.isHidden = hasSwitch
        valueLabel.isHidden = hasSwitch
        if hasSwitch {
            switchControl.isOn = UserDefaults.standard.object(forKey: "push_notification_enabled") as? Bool ?? true
        }
    }

    @objc private func switchChanged() {
        onSwitchChanged?(switchControl.isOn)
    }
}

// MARK: - 关于艺启

final class AboutViewController: BaseViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg

        let iconLabel = UILabel()
        iconLabel.text = "艺"
        iconLabel.font = .boldSystemFont(ofSize: 34)
        iconLabel.textColor = .white
        iconLabel.textAlignment = .center
        iconLabel.backgroundColor = Theme.Color.brand
        iconLabel.layer.cornerRadius = 24
        iconLabel.clipsToBounds = true
        view.addSubview(iconLabel)
        iconLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(56)
            $0.width.height.equalTo(64)
        }

        let nameLabel = UILabel()
        nameLabel.text = "艺启"
        nameLabel.font = .appTitle(20)
        nameLabel.textColor = Theme.Color.ink
        nameLabel.textAlignment = .center
        view.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.top.equalTo(iconLabel.snp.bottom).offset(Theme.Spacing.m)
            $0.centerX.equalToSuperview()
        }

        let versionLabel = UILabel()
        versionLabel.text = "v1.0.0"
        versionLabel.font = .appLabel(13)
        versionLabel.textColor = Theme.Color.sub
        versionLabel.textAlignment = .center
        view.addSubview(versionLabel)
        versionLabel.snp.makeConstraints {
            $0.top.equalTo(nameLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.centerX.equalToSuperview()
        }

        let sloganLabel = UILabel()
        sloganLabel.text = "让每个孩子都能遇见好的艺术启蒙"
        sloganLabel.font = .appBody(13)
        sloganLabel.textColor = Theme.Color.sub
        sloganLabel.textAlignment = .center
        view.addSubview(sloganLabel)
        sloganLabel.snp.makeConstraints {
            $0.top.equalTo(versionLabel.snp.bottom).offset(Theme.Spacing.xl)
            $0.centerX.equalToSuperview()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "关于艺启")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }
}
