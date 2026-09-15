import UIKit
import SnapKit
import SwiftyJSON
import ESPullToRefresh

/// 收益中心：艺启余额总览 + 返利明细 + 提现
/// 分组 TableView（insetGrouped，左右间距天然一致）；底部固定提现栏
final class WalletViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var summary: WalletSummary?
    private var records: [CommissionRecordItem] = []
    private var page = 1
    private var hasMore = true
    private var isLoadingMore = false
    private let pageSize = 20

    private let bottomBar = UIView()
    private let amountLabel = UILabel()
    private let withdrawButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupBottomBar()
        loadSummary()
        loadRecords(reset: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "收益中心")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    // MARK: - 布局

    private func setupTableView() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(BalanceCardCell.self, forCellReuseIdentifier: BalanceCardCell.reuseID)
        tableView.register(WalletRecordCell.self, forCellReuseIdentifier: WalletRecordCell.reuseID)
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 96, right: 0)
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            guard let self else { return }
            self.loadSummary()
            self.loadRecords(reset: true)
        }
        tableView.es.addInfiniteScrolling { [weak self] in
            self?.loadRecords(reset: false)
        }
    }

    private func setupBottomBar() {
        bottomBar.backgroundColor = Theme.Color.surface
        bottomBar.layer.shadowColor = UIColor.black.withAlphaComponent(0.06).cgColor
        bottomBar.layer.shadowOffset = CGSize(width: 0, height: -2)
        bottomBar.layer.shadowOpacity = 1
        bottomBar.layer.shadowRadius = 8
        view.addSubview(bottomBar)
        bottomBar.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.top.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-64)
        }

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Theme.Spacing.m
        stack.alignment = .center
        bottomBar.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(44)
        }

        amountLabel.font = .appSection(16)
        amountLabel.textColor = Theme.Color.ink
        amountLabel.text = "可提现 ¥0.00"

        withdrawButton.setTitle("提现", for: .normal)
        withdrawButton.titleLabel?.font = .appBody(15)
        withdrawButton.setTitleColor(.white, for: .normal)
        withdrawButton.backgroundColor = Theme.Color.brand
        withdrawButton.layer.cornerRadius = 22
        withdrawButton.addTarget(self, action: #selector(didTapWithdraw), for: .touchUpInside)

        stack.addArrangedSubview(amountLabel)
        stack.addArrangedSubview(withdrawButton)
        withdrawButton.snp.makeConstraints {
            $0.width.equalTo(96)
            $0.height.equalTo(44)
        }
    }

    // MARK: - 数据

    private func loadSummary() {
        MineService.fetchWalletSummary { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let summary):
                self.summary = summary
                self.amountLabel.text = String(format: "可提现 ¥%.2f", summary.withdrawable ?? 0)
                self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
            case .failure:
                break
            }
        }
    }

    private func loadRecords(reset: Bool) {
        if reset {
            page = 1
            hasMore = true
        }
        guard hasMore, !isLoadingMore else {
            tableView.es.stopPullToRefresh()
            tableView.es.stopLoadingMore()
            return
        }
        isLoadingMore = true
        MineService.fetchCommissionRecords(page: page, pageSize: pageSize) { [weak self] result in
            guard let self else { return }
            self.isLoadingMore = false
            self.tableView.es.stopPullToRefresh()
            self.tableView.es.stopLoadingMore()
            switch result {
            case .success(let pageResult):
                if reset {
                    self.records = pageResult.list
                } else {
                    self.records.append(contentsOf: pageResult.list)
                }
                self.hasMore = self.records.count < pageResult.total
                self.page += 1
                self.tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
            case .failure:
                break
            }
        }
    }

    // MARK: - TableView

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : records.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: BalanceCardCell.reuseID, for: indexPath) as! BalanceCardCell
            cell.configure(with: summary)
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: WalletRecordCell.reuseID, for: indexPath) as! WalletRecordCell
        cell.configure(with: records[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        indexPath.section == 0 ? 168 : UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        indexPath.section == 0 ? 168 : 72
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 1 ? "返利明细" : nil
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard section == 1, let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font = .appSection(15)
        header.textLabel?.textColor = Theme.Color.ink
    }

    // MARK: - 时间格式化

    static func formatTime(_ iso: String?) -> String {
        guard let iso, let date = ISO8601DateFormatter().date(from: iso) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - 提现

    @objc private func didTapWithdraw() {
        let balance = summary?.withdrawable ?? 0
        guard balance > 0 else {
            showToast("暂无可提现余额")
            return
        }
        WithdrawSheetView.show(balance: balance) { [weak self] amount, method, account in
            guard let self else { return }
            self.showLoading()
            MineService.requestWithdraw(amount: amount, method: method, account: account) { [weak self] result in
                guard let self else { return }
                self.hideLoading()
                switch result {
                case .success:
                    self.showToast("提现申请已提交，审核后到账")
                    self.loadSummary()
                    self.loadRecords(reset: true)
                case .failure(let error):
                    self.showToast(error.message)
                }
            }
        }
    }
}

// MARK: - 余额卡片

private final class BalanceCardCell: UITableViewCell {
    static let reuseID = "BalanceCardCell"

    private let card = UIView()
    private let titleLabel = UILabel()
    private let balanceLabel = UILabel()
    private let statStack = UIStackView()
    private let statViews: [StatView] = [StatView(), StatView(), StatView()]

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

        titleLabel.text = "可用余额（艺启余额）"
        titleLabel.font = .appBody(13)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        card.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.leading.equalToSuperview().offset(Theme.Spacing.l)
        }

        balanceLabel.font = .appHero(34)
        balanceLabel.textColor = .white
        balanceLabel.text = "¥0.00"
        card.addSubview(balanceLabel)
        balanceLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
        }

        statStack.axis = .horizontal
        statStack.distribution = .fillEqually
        card.addSubview(statStack)
        statStack.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.l)
            $0.height.equalTo(34)
        }
        statViews.forEach { statStack.addArrangedSubview($0) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with summary: WalletSummary?) {
        balanceLabel.text = String(format: "¥%.2f", summary?.withdrawable ?? 0)
        let stats = summary?.stats
        let items: [(String, Double)] = [
            ("累计返利", stats?.total_commission ?? 0),
            ("已提现", stats?.total_withdrawn ?? 0),
            ("冻结中", summary?.wallet?.frozen ?? 0)
        ]
        for (index, item) in items.enumerated() {
            statViews[index].configure(title: item.0, value: item.1)
        }
    }
}

private final class StatView: UIView {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = .appBody(12)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.leading.equalToSuperview()
        }
        valueLabel.font = .appBody(14)
        valueLabel.textColor = .white
        addSubview(valueLabel)
        valueLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.xs)
            $0.leading.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, value: Double) {
        titleLabel.text = title
        valueLabel.text = String(format: "¥%.2f", value)
    }
}

// MARK: - 返利明细行

private final class WalletRecordCell: UITableViewCell {
    static let reuseID = "WalletRecordCell"

    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let amountLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.surface
        selectionStyle = .none

        // 先全部 addSubview，再统一约束（跨视图引用需同 hierarchy）
        titleLabel.font = .appBody(15)
        titleLabel.textColor = Theme.Color.ink
        contentView.addSubview(titleLabel)

        timeLabel.font = .appBody(12)
        timeLabel.textColor = Theme.Color.sub
        contentView.addSubview(timeLabel)

        amountLabel.font = .appBody(16)
        amountLabel.textColor = Theme.Color.success
        amountLabel.textAlignment = .right
        contentView.addSubview(amountLabel)

        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
            $0.trailing.lessThanOrEqualTo(amountLabel.snp.leading).offset(-Theme.Spacing.m)
        }
        timeLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.xs)
            $0.leading.equalTo(titleLabel)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.m)
        }
        amountLabel.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.l)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with record: CommissionRecordItem) {
        titleLabel.text = record.course?.title ?? "分享返利"
        timeLabel.text = WalletViewController.formatTime(record.created_at)
        let amount = record.amount ?? 0
        amountLabel.text = String(format: "+¥%.2f", amount)
    }
}
