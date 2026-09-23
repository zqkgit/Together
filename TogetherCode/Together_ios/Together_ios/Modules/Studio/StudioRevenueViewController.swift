import UIKit
import SnapKit
import ESPullToRefresh

/// 工作室端「收益中心」：订单营收统计概览
/// 只展示财务数据看板，佣金审核在独立页面
final class StudioRevenueViewController: BaseViewController {

    // MARK: - 数据

    private var finance: StudioFinanceData?
    private var firstLoad = true

    // MARK: - 视图

    private let tableView = UITableView(frame: .zero, style: .plain)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadFinance()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "收益中心")
        if !firstLoad { loadFinance() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    // MARK: - 布局

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(StudioFinanceHeaderCell.self, forCellReuseIdentifier: StudioFinanceHeaderCell.reuseID)
        tableView.register(StudioFinanceDetailCell.self, forCellReuseIdentifier: StudioFinanceDetailCell.reuseID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.m)
            $0.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.loadFinance()
        }
    }

    // MARK: - 数据加载

    private func loadFinance() {
        StudioService.fetchFinance { [weak self] result in
            guard let self else { return }
            self.firstLoad = false
            self.tableView.es.stopPullToRefresh()
            if case .success(let data) = result {
                self.finance = data
            }
            self.tableView.reloadData()
        }
    }
}

// MARK: - TableView

extension StudioRevenueViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        2 // 0: 概览卡  1: 明细行
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: StudioFinanceHeaderCell.reuseID, for: indexPath) as! StudioFinanceHeaderCell
            cell.configure(with: finance?.summary, period: finance?.period)
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: StudioFinanceDetailCell.reuseID, for: indexPath) as! StudioFinanceDetailCell
        cell.configure(with: finance?.summary)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - 营收概览卡

private final class StudioFinanceHeaderCell: UITableViewCell {
    static let reuseID = "StudioFinanceHeaderCell"

    private let card = UIView()
    private let titleLabel = UILabel()
    private let periodLabel = UILabel()
    private let gmvLabel = UILabel()
    private let gmvCaption = UILabel()
    private let columns: [FinanceColumn] = [FinanceColumn(), FinanceColumn(), FinanceColumn(), FinanceColumn()]

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        card.backgroundColor = Theme.Color.brandDark
        card.layer.cornerRadius = Theme.Radius.card
        card.layer.masksToBounds = true
        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.s)
        }

        titleLabel.text = "营收概览"
        titleLabel.font = .appBody(13)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        card.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.leading.equalToSuperview().offset(Theme.Spacing.l)
        }

        periodLabel.font = .appLabel(11)
        periodLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        card.addSubview(periodLabel)
        periodLabel.snp.makeConstraints {
            $0.centerY.equalTo(titleLabel)
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.l)
        }

        gmvLabel.font = .appHero(28)
        gmvLabel.textColor = .white
        gmvLabel.text = "¥0"
        card.addSubview(gmvLabel)
        gmvLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.xs)
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
        }

        gmvCaption.text = "累计营收"
        gmvCaption.font = .appLabel(11)
        gmvCaption.textColor = UIColor.white.withAlphaComponent(0.55)
        card.addSubview(gmvCaption)
        gmvCaption.snp.makeConstraints {
            $0.leading.equalTo(gmvLabel.snp.trailing).offset(6)
            $0.bottom.equalTo(gmvLabel).offset(-4)
        }

        let columnStack = UIStackView()
        columnStack.axis = .horizontal
        columnStack.distribution = .fillEqually
        card.addSubview(columnStack)
        columnStack.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalTo(gmvLabel.snp.bottom).offset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.l)
            $0.height.equalTo(38)
        }
        columns.forEach { columnStack.addArrangedSubview($0) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with summary: StudioFinanceSummary?, period: StudioFinancePeriod?) {
        let s = summary ?? StudioFinanceSummary(
            gmv_total: nil, gmv_period: nil, refund_total: nil, refund_period: nil,
            distribution_total: nil, net_total: nil, net_period: nil
        )
        gmvLabel.text = StudioAmount.text(s.gmvTotal)
        // 区间
        if let start = period?.start_date, let end = period?.end_date {
            periodLabel.text = "\(start) ~ \(end)"
        } else {
            periodLabel.text = ""
        }
        let items: [(String, Int)] = [
            ("本月营收", s.gmvPeriod),
            ("累计退款", s.refundTotal),
            ("分销支出", s.distributionTotal),
            ("净收入", s.netTotal)
        ]
        for (i, item) in items.enumerated() {
            columns[i].configure(title: item.0, value: item.1)
        }
    }
}

// MARK: - 明细行（区间退款 + 区间净收入）

private final class StudioFinanceDetailCell: UITableViewCell {
    static let reuseID = "StudioFinanceDetailCell"

    private let card = UIView()
    private let rows: [FinanceDetailRow] = [FinanceDetailRow(), FinanceDetailRow()]

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.top.equalToSuperview().offset(6)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().offset(-6)
        }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        card.addSubview(stack)
        stack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(Theme.Spacing.l)
        }
        rows.forEach { stack.addArrangedSubview($0) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with summary: StudioFinanceSummary?) {
        let s = summary ?? StudioFinanceSummary(
            gmv_total: nil, gmv_period: nil, refund_total: nil, refund_period: nil,
            distribution_total: nil, net_total: nil, net_period: nil
        )
        rows[0].configure(title: "区间退款", value: StudioAmount.text(s.refundPeriod))
        rows[1].configure(title: "区间净收入", value: StudioAmount.text(s.netPeriod))
    }
}

// MARK: - 财务列（概览卡内小列）

private final class FinanceColumn: UIView {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = .appBody(10)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.65)
        titleLabel.textAlignment = .center
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.trailing.equalToSuperview()
        }

        valueLabel.font = .appBody(14)
        valueLabel.textColor = .white
        valueLabel.textAlignment = .center
        addSubview(valueLabel)
        valueLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(2)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, value: Int) {
        titleLabel.text = title
        valueLabel.text = StudioAmount.groupedNumber(value)
    }
}

// MARK: - 明细行（标题 + 金额）

private final class FinanceDetailRow: UIView {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = .appBody(14)
        titleLabel.textColor = Theme.Color.sub
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
        }

        valueLabel.font = .appSection(15)
        valueLabel.textColor = Theme.Color.ink
        valueLabel.textAlignment = .right
        addSubview(valueLabel)
        valueLabel.snp.makeConstraints {
            $0.trailing.top.bottom.equalToSuperview()
            $0.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, value: String) {
        titleLabel.text = title
        valueLabel.text = value
    }
}