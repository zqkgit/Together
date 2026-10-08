import UIKit
import SnapKit
import ESPullToRefresh

/// 工作室端「收益中心」：订单营收统计概览
/// 只展示财务数据看板，佣金审核在独立页面
final class StudioRevenueViewController: BaseViewController {

    // MARK: - 数据

    private var finance: StudioFinanceData?
    private var firstLoad = true

    // 日期筛选状态
    private var startDate: String = DateRangePreset.thisMonth.dates().0
    private var endDate: String = DateRangePreset.thisMonth.dates().1
    private var selectedPreset: DateRangePreset = .thisMonth

    // MARK: - 视图

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

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
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.loadFinance()
        }
    }

    // MARK: - 数据加载

    private func loadFinance(silent: Bool = false) {
        StudioService.fetchFinance(startDate: startDate, endDate: endDate) { [weak self] result in
            guard let self else { return }
            self.firstLoad = false
            self.tableView.es.stopPullToRefresh()
            if case .success(let data) = result {
                self.finance = data
            }
            self.tableView.reloadData()
        }
    }

    // MARK: - 日期筛选

    private func showDateFilter() {
        let titles = DateRangePreset.allCases.map { $0.title }
        let sheet = ThemeActionSheet(
            title: "选择时间范围",
            actions: titles.map { ($0, false) }
        )
        sheet.onSelect = { [weak self] index in
            guard let self, let preset = DateRangePreset.allCases[safe: index] else { return }
            if case .custom = preset {
                self.presentCustomDatePicker()
            } else {
                let (s, e) = preset.dates()
                self.selectedPreset = preset
                self.startDate = s
                self.endDate = e
                self.loadFinance()
            }
        }
        present(sheet, animated: false)
    }

    private func presentCustomDatePicker() {
        let pickerVC = CustomDateRangeViewController(start: startDate, end: endDate)
        pickerVC.onConfirm = { [weak self] start, end in
            self?.selectedPreset = .custom
            self?.startDate = start
            self?.endDate = end
            self?.loadFinance()
        }
        let nav = UINavigationController(rootViewController: pickerVC)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
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
            cell.configure(with: finance?.summary, preset: selectedPreset, period: finance?.period)
            cell.onCardTap = { [weak self] in
                self?.navigationController?.pushViewController(CommissionWithdrawalsViewController(), animated: true)
            }
            cell.onPeriodTap = { [weak self] in
                self?.showDateFilter()
            }
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: StudioFinanceDetailCell.reuseID, for: indexPath) as! StudioFinanceDetailCell
        cell.configure(with: finance?.summary)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    // 显式设置 section header / footer，避免默认大间距
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 8 }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 8 }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? { UIView() }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { UIView() }
}

// MARK: - 营收概览卡

private final class StudioFinanceHeaderCell: UITableViewCell {
    static let reuseID = "StudioFinanceHeaderCell"

    var onCardTap: (() -> Void)?
    var onPeriodTap: (() -> Void)?

    private let card = UIView()
    private let titleLabel = UILabel()
    private let periodButton = UIButton(type: .system)
    private let gmvLabel = UILabel()
    private let gmvCaption = UILabel()
    private let columns: [FinanceColumn] = [FinanceColumn(), FinanceColumn(), FinanceColumn(), FinanceColumn()]
    private let cardGradient = CAGradientLayer()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        card.backgroundColor = Theme.Color.brand
        card.layer.cornerRadius = Theme.Radius.card
        card.layer.masksToBounds = true
        card.isUserInteractionEnabled = true
        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapCard)))

        // 明快渐变：左上主色 → 右下亮绿（与经营概览营收卡统一）
        cardGradient.colors = [Theme.Color.brand.cgColor, UIColor(hex: 0x46C76D).cgColor]
        cardGradient.startPoint = CGPoint(x: 0, y: 0)
        cardGradient.endPoint = CGPoint(x: 1, y: 1)
        card.layer.insertSublayer(cardGradient, at: 0)
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
            $0.top.leading.equalToSuperview().offset(Theme.Spacing.cardInner)
        }

        // 右上角：时间筛选按钮（期间 + 下箭头）
        periodButton.titleLabel?.font = .appLabel(11)
        periodButton.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .normal)
        periodButton.setImage(UIImage(systemName: "chevron.down")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 8, weight: .semibold)),
            for: .normal)
        periodButton.tintColor = UIColor.white.withAlphaComponent(0.5)
        periodButton.semanticContentAttribute = .forceRightToLeft
        periodButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 2, bottom: 0, right: 0)
        periodButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: -2)
        periodButton.addTarget(self, action: #selector(didTapPeriod), for: .touchUpInside)
        card.addSubview(periodButton)
        periodButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.cardInner)
            $0.centerY.equalTo(titleLabel)
        }

        gmvLabel.font = .appHero(28)
        gmvLabel.textColor = .white
        gmvLabel.text = "¥0"
        card.addSubview(gmvLabel)
        gmvLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.xs)
            $0.leading.equalToSuperview().offset(Theme.Spacing.cardInner)
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
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.cardInner)
            $0.top.equalTo(gmvLabel.snp.bottom).offset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.l)
            $0.height.equalTo(38)
        }
        columns.forEach { columnStack.addArrangedSubview($0) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        cardGradient.frame = card.bounds
    }

    @objc private func didTapCard() {
        onCardTap?()
    }

    @objc private func didTapPeriod() {
        onPeriodTap?()
    }

    func configure(with summary: StudioFinanceSummary?, preset: DateRangePreset?, period: StudioFinancePeriod? = nil) {
        let s = summary ?? StudioFinanceSummary(
            gmv_total: nil, gmv_period: nil, refund_total: nil, refund_period: nil,
            distribution_total: nil, net_total: nil, net_period: nil
        )
        gmvLabel.text = StudioAmount.text(s.gmvTotal)
        // 右上角按钮文案
        if let preset {
            periodButton.setTitle(preset.title, for: .normal)
        } else if let start = period?.start_date, let end = period?.end_date,
                  !start.isEmpty, !end.isEmpty {
            let s = String(start.suffix(5))
            let e = String(end.suffix(5))
            periodButton.setTitle("\(s)~\(e)", for: .normal)
        } else {
            periodButton.setTitle("本月", for: .normal)
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
            $0.edges.equalToSuperview().inset(Theme.Spacing.cardInner)
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