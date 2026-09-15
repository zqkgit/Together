import UIKit
import SnapKit

/// 退款详情（家长端，状态流转：提交申请 → 工作室审核 → 已通过并退款 / 已驳回）
final class RefundDetailViewController: BaseViewController {

    private let refundId: String
    private var detail: RefundDetail?

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    init(refundId: String) {
        self.refundId = refundId
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureImmersiveNav(title: "退款详情")
        setupTableView()
        loadData()
    }

    private func setupTableView() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.alwaysBounceVertical = true
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(RefundStatusCell.self, forCellReuseIdentifier: RefundStatusCell.reuseID)
        tableView.register(RefundRowCell.self, forCellReuseIdentifier: RefundRowCell.reuseID)
        tableView.register(RefundStepCell.self, forCellReuseIdentifier: RefundStepCell.reuseID)
        tableView.contentInset = UIEdgeInsets(top: Theme.Spacing.s, left: 0, bottom: 40, right: 0)
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.edges.equalTo(view.safeAreaLayoutGuide)
        }
    }

    private func loadData() {
        showLoading()
        OrderService.fetchRefundDetail(refundId: refundId) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success(let detail):
                self.detail = detail
                self.tableView.reloadData()
            case .failure(let error):
                self.showToast(error.message ?? "加载失败")
            }
        }
    }
}

// MARK: - DataSource / Delegate（3 分组：状态卡 / 退款信息 / 进度时间线）

extension RefundDetailViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        detail == nil ? 0 : 3
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1                       // 状态卡
        case 1: return detailInfoRows().count  // 退款信息
        case 2: return detail?.steps?.count ?? 0  // 时间线
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: RefundStatusCell.reuseID, for: indexPath) as! RefundStatusCell
            cell.configure(detail)
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: RefundRowCell.reuseID, for: indexPath) as! RefundRowCell
            let rows = detailInfoRows()
            cell.configure(title: rows[indexPath.row].0, value: rows[indexPath.row].1, brand: rows[indexPath.row].2)
            return cell
        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: RefundStepCell.reuseID, for: indexPath) as! RefundStepCell
            if let step = detail?.steps?[indexPath.row] {
                cell.configure(step, isLast: indexPath.row == (detail?.steps?.count ?? 1) - 1)
            }
            return cell
        default:
            return UITableViewCell()
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0: return 108
        case 1: return 46
        case 2: return 64
        default: return 44
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section > 0 else { return nil }
        let titles = ["", "退款信息", "退款进度"]
        let container = UIView()
        container.backgroundColor = .clear
        let label = UILabel()
        label.text = titles[section]
        label.font = .appBody(16)
        label.textColor = Theme.Color.ink
        container.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.centerY.equalToSuperview()
        }
        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? 0 : 40
    }

    private func detailInfoRows() -> [(String, String, Bool)] {
        guard let detail else { return [] }
        var rows: [(String, String, Bool)] = []
        rows.append(("申请课时", "\(detail.requested_lessons ?? 0)节", false))
        if let unit = detail.unit_price_text {
            rows.append(("课时单价", unit, false))
        }
        rows.append(("退款金额", detail.amount_text ?? "-", true))
        if let time = detail.created_at?.replacingOccurrences(of: "T", with: " ").prefix(16).description {
            rows.append(("申请时间", String(time), false))
        }
        if let reason = detail.reason, !reason.isEmpty {
            rows.append(("退款原因", reason, false))
        }
        return rows
    }
}

// MARK: - 状态卡 Cell

private final class RefundStatusCell: UITableViewCell {

    static let reuseID = "RefundStatusCell"

    private let statusLabel = UILabel()
    private let amountLabel = UILabel()
    private let descLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Theme.Color.surface
        contentView.backgroundColor = Theme.Color.surface

        statusLabel.font = .appSection(17)
        statusLabel.textColor = Theme.Color.brand
        amountLabel.font = .appSection(22)
        amountLabel.textColor = Theme.Color.ink
        descLabel.font = .appLabel(13)
        descLabel.textColor = Theme.Color.sub

        contentView.addSubview(statusLabel)
        contentView.addSubview(amountLabel)
        contentView.addSubview(descLabel)
        statusLabel.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        amountLabel.snp.makeConstraints {
            $0.top.equalTo(statusLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        descLabel.snp.makeConstraints {
            $0.top.equalTo(amountLabel.snp.bottom).offset(2)
            $0.leading.trailing.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ detail: RefundDetail?) {
        guard let detail else { return }
        statusLabel.text = detail.status_text ?? "退款"
        amountLabel.text = detail.amount_text ?? "-"
        let desc: String
        switch detail.status {
        case 2:
            desc = "申请未通过，如有疑问请联系机构"
        case 3:
            desc = "退款已原路退回，请注意查收"
        default:
            desc = "退款将原路退回，处理中请留意到账通知"
        }
        descLabel.text = desc
        statusLabel.textColor = detail.status == 2 ? Theme.Color.sub : Theme.Color.brand
    }
}

// MARK: - 信息行 Cell

private final class RefundRowCell: UITableViewCell {

    static let reuseID = "RefundRowCell"

    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Theme.Color.surface
        contentView.backgroundColor = Theme.Color.surface

        titleLabel.font = .appLabel(14)
        titleLabel.textColor = Theme.Color.sub
        valueLabel.font = .appBody(14)
        valueLabel.textColor = Theme.Color.ink
        valueLabel.textAlignment = .right
        valueLabel.numberOfLines = 0
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.centerY.equalToSuperview().inset(Theme.Spacing.l)
        }
        valueLabel.snp.makeConstraints {
            $0.trailing.centerY.equalToSuperview().inset(Theme.Spacing.l)
            $0.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Theme.Spacing.m)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, value: String, brand: Bool) {
        titleLabel.text = title
        valueLabel.text = value
        valueLabel.textColor = brand ? Theme.Color.brand : Theme.Color.ink
    }
}

// MARK: - 时间线 Cell

private final class RefundStepCell: UITableViewCell {

    static let reuseID = "RefundStepCell"

    private let dot = UIView()
    private let line = UIView()
    private let titleLabel = UILabel()
    private let timeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Theme.Color.surface
        contentView.backgroundColor = Theme.Color.surface

        dot.layer.cornerRadius = 5
        contentView.addSubview(dot)
        dot.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalToSuperview().offset(18)
            $0.width.height.equalTo(10)
        }

        line.backgroundColor = Theme.Color.line
        contentView.addSubview(line)
        line.snp.makeConstraints {
            $0.centerX.equalTo(dot)
            $0.top.equalTo(dot.snp.bottom)
            $0.bottom.equalToSuperview()
            $0.width.equalTo(2)
        }

        titleLabel.font = .appBody(15)
        titleLabel.textColor = Theme.Color.ink
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(dot.snp.trailing).offset(Theme.Spacing.m)
            $0.top.equalToSuperview().offset(12)
        }

        timeLabel.font = .appLabel(12)
        timeLabel.textColor = Theme.Color.sub
        contentView.addSubview(timeLabel)
        timeLabel.snp.makeConstraints {
            $0.leading.equalTo(titleLabel)
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ step: RefundStep, isLast: Bool) {
        titleLabel.text = step.title ?? ""
        titleLabel.textColor = (step.current == true || step.done == true) ? Theme.Color.ink : Theme.Color.sub
        dot.backgroundColor = (step.current == true || step.done == true) ? Theme.Color.brand : Theme.Color.line
        line.isHidden = isLast
        if let time = step.time?.replacingOccurrences(of: "T", with: " ").prefix(16).description {
            timeLabel.text = String(time)
        } else {
            timeLabel.text = (step.current == true) ? "等待处理中" : "-"
        }
    }
}
