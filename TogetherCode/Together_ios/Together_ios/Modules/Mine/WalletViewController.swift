import UIKit
import SnapKit
import SwiftyJSON
import Kingfisher
import ESPullToRefresh

/// 收益中心：佣金总览 + 按工作室分组领取 + 领取记录入口
/// 平台不碰资金：佣金由工作室线下审核打款，推广人按工作室分别申请、确认到账。
/// 分组 TableView（insetGrouped，左右间距天然一致）
final class WalletViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var summary: CommissionSummary?
    private var hasLoaded = false

    // 日期筛选状态
    private var startDate: String = DateRangePreset.thisMonth.dates().0
    private var endDate: String = DateRangePreset.thisMonth.dates().1
    private var selectedPreset: DateRangePreset = .thisMonth

    /// 分组数：概览卡 + 工作室卡片（无数据时 1 个空态占位）
    private var totalSections: Int {
        1 + max(summary?.studios?.count ?? 0, 1)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "收益中心")
        loadData(silent: hasLoaded)
        hasLoaded = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    // MARK: - 布局

    private func setupUI() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(OverviewCardCell.self, forCellReuseIdentifier: OverviewCardCell.reuseID)
        tableView.register(StudioWalletCell.self, forCellReuseIdentifier: StudioWalletCell.reuseID)
        tableView.register(WalletEmptyCell.self, forCellReuseIdentifier: WalletEmptyCell.reuseID)
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.loadData(silent: true)
        }
    }

    // MARK: - 数据

    private func loadData(silent: Bool) {
        if !silent { showLoading() }
        CommissionService.fetchSummary(startDate: startDate, endDate: endDate) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            self.tableView.es.stopPullToRefresh()
            switch result {
            case .success(let summary):
                self.summary = summary
                self.tableView.reloadData()
            case .failure(let error):
                if !silent { self.showToast(error.message) }
            }
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
                self.loadData(silent: false)
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
            self?.loadData(silent: false)
        }
        let nav = UINavigationController(rootViewController: pickerVC)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    // MARK: - TableView

    func numberOfSections(in tableView: UITableView) -> Int { totalSections }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: OverviewCardCell.reuseID, for: indexPath) as! OverviewCardCell
            cell.configure(with: summary, preset: selectedPreset)
            cell.onCardTap = { [weak self] in
                self?.navigationController?.pushViewController(CommissionWithdrawalsViewController(), animated: true)
            }
            cell.onPeriodTap = { [weak self] in
                self?.showDateFilter()
            }
            return cell
        }
        // 工作室卡片 或 空态
        let studios = summary?.studios ?? []
        if studios.isEmpty {
            return tableView.dequeueReusableCell(withIdentifier: WalletEmptyCell.reuseID, for: indexPath)
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: StudioWalletCell.reuseID, for: indexPath) as! StudioWalletCell
        let group = studios[indexPath.section - 1]
        cell.configure(with: group)
        cell.onTapWithdraw = { [weak self] in
            self?.startCommissionWithdraw(studioId: group.studio_id ?? "")
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let studios = summary?.studios ?? []
        if !studios.isEmpty, indexPath.section >= 1, indexPath.section <= studios.count {
            navigationController?.pushViewController(
                StudioCommissionDetailViewController(group: studios[indexPath.section - 1]),
                animated: true
            )
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 { return 156 }
        if (summary?.studios ?? []).isEmpty { return 200 }
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat { 180 }

    // 显式设置 section header / footer，避免默认大间距（相邻卡片间距 16）
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 8 }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 8 }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? { UIView() }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { UIView() }
}

// MARK: - 收益总览深色卡

private final class OverviewCardCell: UITableViewCell {
    static let reuseID = "OverviewCardCell"

    var onCardTap: (() -> Void)?
    var onPeriodTap: (() -> Void)?

    private let card = UIView()
    private let titleLabel = UILabel()
    private let periodButton = UIButton(type: .system)
    private let totalLabel = UILabel()
    private let columnStack = UIStackView()
    private let columns: [MiniColumn] = [MiniColumn(), MiniColumn(), MiniColumn()]
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

        // 明快渐变：左上主色 → 右下亮绿（与营收卡统一）
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

        titleLabel.text = "累计佣金（元）"
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

        totalLabel.font = .appHero(32)
        totalLabel.textColor = .white
        totalLabel.text = "¥0.00"
        card.addSubview(totalLabel)
        totalLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.xs)
            $0.leading.equalToSuperview().offset(Theme.Spacing.cardInner)
        }

        columnStack.axis = .horizontal
        columnStack.distribution = .fillEqually
        card.addSubview(columnStack)
        columnStack.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.cardInner)
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

    func configure(with summary: CommissionSummary?, preset: DateRangePreset?) {
        let stats = summary?.stats
        totalLabel.text = CommissionService.yuan(stats?.total_commission)
        // 右上角按钮文案
        if let preset {
            periodButton.setTitle(preset.title, for: .normal)
        } else if let start = summary?.period?.start_date, let end = summary?.period?.end_date,
                  !start.isEmpty, !end.isEmpty {
            let s = String(start.suffix(5))
            let e = String(end.suffix(5))
            periodButton.setTitle("\(s)~\(e)", for: .normal)
        } else {
            periodButton.setTitle("本月", for: .normal)
        }
        let items: [(String, Double?)] = [
            ("待申请", stats?.receivable_commission),
            ("申请中", stats?.applying_commission),
            ("已到账", stats?.settled_commission)
        ]
        for (i, item) in items.enumerated() {
            columns[i].configure(title: item.0, value: item.1 ?? 0)
        }
    }
}

private final class MiniColumn: UIView {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = .appBody(11)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        titleLabel.textAlignment = .center
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.trailing.equalToSuperview()
        }

        valueLabel.font = .appBody(15)
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

    func configure(title: String, value: Double) {
        titleLabel.text = title
        valueLabel.text = String(format: "¥%.2f", value)
    }
}

// MARK: - 工作室收益卡

private final class StudioWalletCell: UITableViewCell {
    static let reuseID = "StudioWalletCell"

    var onTapWithdraw: (() -> Void)?

    private let coverView = UIImageView()
    private let nameLabel = UILabel()
    private let chevron = UIImageView()
    private let statsRow = UIStackView()
    private let receivableCol = StatColumn()
    private let applyingCol = StatColumn()
    private let settledCol = StatColumn()
    private let withdrawButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        let card = UIView()
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        card.layer.masksToBounds = true
        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.s)
        }

        // 垂直 stack 统一布局，约束链完整
        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = Theme.Spacing.m
        card.addSubview(cardStack)
        cardStack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(Theme.Spacing.l)
        }

        // 顶部行：封面 + 名称 + 箭头
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.spacing = Theme.Spacing.m
        headerRow.alignment = .center
        cardStack.addArrangedSubview(headerRow)

        coverView.contentMode = .scaleAspectFill
        coverView.backgroundColor = Theme.Color.brand
        coverView.layer.cornerRadius = 10
        coverView.layer.masksToBounds = true
        coverView.snp.makeConstraints { $0.size.equalTo(42) }
        headerRow.addArrangedSubview(coverView)

        nameLabel.font = .appSection(16)
        nameLabel.textColor = Theme.Color.ink
        headerRow.addArrangedSubview(nameLabel)

        chevron.image = UIImage(systemName: "chevron.right")
        chevron.tintColor = Theme.Color.muted
        chevron.snp.makeConstraints { $0.width.equalTo(9) }
        headerRow.addArrangedSubview(chevron)

        // 分隔线
        let divider = UIView()
        divider.backgroundColor = Theme.Color.line
        divider.snp.makeConstraints { $0.height.equalTo(0.5) }
        cardStack.addArrangedSubview(divider)

        // 统计行：数字在上、标题在下
        statsRow.axis = .horizontal
        statsRow.distribution = .fillEqually
        [receivableCol, applyingCol, settledCol].forEach { statsRow.addArrangedSubview($0) }
        cardStack.addArrangedSubview(statsRow)

        // 领取按钮（铺满，仅有待申请金额时显示）
        withdrawButton.titleLabel?.font = .appSection(15)
        withdrawButton.setTitleColor(.white, for: .normal)
        withdrawButton.backgroundColor = Theme.Color.brand
        withdrawButton.layer.cornerRadius = 22
        withdrawButton.addTarget(self, action: #selector(didTapWithdraw), for: .touchUpInside)
        withdrawButton.snp.makeConstraints { $0.height.equalTo(44) }
        cardStack.addArrangedSubview(withdrawButton)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with group: CommissionSummary.StudioGroup) {
        nameLabel.text = group.name ?? "工作室"
        if let cover = group.cover, let url = URL(string: cover.resolvedImageURL) {
            coverView.kf.setImage(with: url)
            coverView.backgroundColor = Theme.Color.woodSoft
        } else {
            coverView.image = UIImage(
                systemName: "building.2.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .medium)
            )
            coverView.tintColor = .white
            coverView.backgroundColor = Theme.Color.brand
        }
        let receivable = group.receivable ?? 0
        receivableCol.configure(value: receivable, title: "待申请", highlight: receivable > 0)
        applyingCol.configure(value: group.applying ?? 0, title: "申请中")
        settledCol.configure(value: group.settled ?? 0, title: "已到账")

        let canWithdraw = receivable > 0
        withdrawButton.isHidden = !canWithdraw
        if canWithdraw {
            withdrawButton.setTitle("一键领取 \(String(format: "¥%.2f", receivable))", for: .normal)
        }
    }

    @objc private func didTapWithdraw() { onTapWithdraw?() }
}

/// 统计列：数字在上（居中）、标题在下（居中），完整 top-bottom 约束
final class StatColumn: UIView {
    private let valueLabel = UILabel()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        valueLabel.font = .appSection(16)
        valueLabel.textColor = Theme.Color.ink
        valueLabel.textAlignment = .center
        addSubview(valueLabel)
        valueLabel.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.trailing.equalToSuperview()
        }

        titleLabel.font = .appBody(11)
        titleLabel.textColor = Theme.Color.sub
        titleLabel.textAlignment = .center
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(valueLabel.snp.bottom).offset(3)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(value: Double, title: String, highlight: Bool = false) {
        valueLabel.text = String(format: "¥%.2f", value)
        valueLabel.textColor = highlight ? Theme.Color.clay : Theme.Color.ink
        titleLabel.text = title
    }
}

// MARK: - 空态 cell

private final class WalletEmptyCell: UITableViewCell {
    static let reuseID = "WalletEmptyCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        let empty = EmptyStateView()
        contentView.addSubview(empty)
        empty.snp.makeConstraints { $0.edges.equalToSuperview() }
        empty.show(style: .empty("还没有推广收益，分享课程或海报即可获得佣金"))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}


