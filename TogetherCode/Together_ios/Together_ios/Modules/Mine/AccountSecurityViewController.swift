import UIKit
import SnapKit

/// 账号与安全（设置 → 账号与安全）
/// 绑定手机号 / 修改登录密码 / 设置支付密码 / 注销账号
final class AccountSecurityViewController: BaseViewController {

    private struct Row {
        let icon: String
        let title: String
        let value: String?
        let danger: Bool
    }

    private var rows: [Row] = [
        Row(icon: "iphone", title: "绑定手机号", value: nil, danger: false),
        Row(icon: "lock", title: "修改登录密码", value: nil, danger: false),
        Row(icon: "number", title: "设置支付密码", value: nil, danger: false),
        Row(icon: "person.crop.circle.badge.minus", title: "注销账号", value: nil, danger: true)
    ]

    private let tableView = UITableView(frame: .zero, style: .grouped)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupTable()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "账号与安全")
        loadPhone()
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
        tableView.register(AccountSecurityCell.self, forCellReuseIdentifier: AccountSecurityCell.reuseId)
        tableView.rowHeight = 54
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    /// 拉取当前手机号，脱敏展示
    private func loadPhone() {
        AuthService.fetchMe { [weak self] profile, _ in
            guard let self else { return }
            if let phone = profile?.phone, !phone.isEmpty {
                self.rows[0] = Row(icon: "iphone", title: "绑定手机号", value: maskedPhone(phone), danger: false)
                self.tableView.reloadData()
            }
        }
    }
}

// MARK: - 脱敏工具

func maskedPhone(_ phone: String) -> String {
    guard phone.count == 11 else { return phone }
    let index = phone.index(phone.startIndex, offsetBy: 3)
    let end = phone.index(phone.startIndex, offsetBy: 7)
    return phone.replacingCharacters(in: index..<end, with: "****")
}

// MARK: - TableView

extension AccountSecurityViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AccountSecurityCell.reuseId, for: indexPath) as! AccountSecurityCell
        let row = rows[indexPath.row]
        cell.configure(icon: row.icon, title: row.title, value: row.value, danger: row.danger)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch rows[indexPath.row].title {
        case "绑定手机号":
            navigationController?.pushViewController(ChangePhoneViewController(), animated: true)
        case "修改登录密码":
            navigationController?.pushViewController(ChangePasswordViewController(), animated: true)
        case "设置支付密码":
            navigationController?.pushViewController(SetPayPasswordViewController(), animated: true)
        case "注销账号":
            ThemeAlertView.show(
                title: "注销账号",
                message: "注销后账号数据将无法恢复，确定要继续吗？",
                confirmTitle: "继续",
                onConfirm: { [weak self] in
                    self?.navigationController?.pushViewController(DeactivateAccountViewController(), animated: true)
                }
            )
        default:
            break
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 8))
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 8 }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { nil }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 0.01 }
}

// MARK: - 行

final class AccountSecurityCell: UITableViewCell {

    static let reuseId = "AccountSecurityCell"

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let chevron = UIImageView()
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

        bottomLine.backgroundColor = Theme.Color.line
        contentView.addSubview(bottomLine)
        bottomLine.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(48)
            $0.trailing.bottom.equalToSuperview()
            $0.height.equalTo(0.5)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(icon: String, title: String, value: String?, danger: Bool) {
        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = danger ? UIColor(hex: 0xE5484D) : Theme.Color.brand
        titleLabel.text = title
        titleLabel.textColor = danger ? UIColor(hex: 0xE5484D) : Theme.Color.ink
        valueLabel.text = value
        if let value, !value.isEmpty {
            valueLabel.isHidden = false
            chevron.isHidden = true
        } else {
            valueLabel.isHidden = true
            chevron.isHidden = false
        }
    }
}
