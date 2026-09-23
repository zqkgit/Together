import UIKit
import SnapKit
import SwiftyJSON
import Kingfisher
import ESPullToRefresh

// MARK: - 领取记录列表

final class CommissionWithdrawalsViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var rows: [CommissionWithdrawal] = []
    private var page = 1
    private var total = 0
    private var isLoading = false
    private let pageSize = 20
    private var hasMore: Bool { rows.count < total }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        loadData(reset: true)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleUpdated), name: .commissionUpdated, object: nil
        )
    }

    @objc private func handleUpdated() { loadData(reset: true) }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "领取记录")
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    private func setupTableView() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(WithdrawalRowCell.self, forCellReuseIdentifier: WithdrawalRowCell.reuseID)
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.bottom.equalToSuperview()
        }
        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.loadData(reset: true)
        }
        tableView.es.addInfiniteScrolling { [weak self] in
            self?.loadData(reset: false)
        }
    }

    private func loadData(reset: Bool) {
        if reset { page = 1 }
        guard !isLoading else { return }
        isLoading = true
        CommissionService.fetchWithdrawals(page: page, pageSize: pageSize) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            self.tableView.es.stopPullToRefresh()
            self.tableView.es.stopLoadingMore()
            switch result {
            case .success(let data):
                self.total = data.total
                if reset { self.rows = data.list } else { self.rows.append(contentsOf: data.list) }
                self.page += 1
                self.tableView.reloadData()
            case .failure(let error):
                self.showToast(error.message)
            }
        }
    }

    // 每单一个 section（独立白卡）
    func numberOfSections(in tableView: UITableView) -> Int { max(rows.count, 1) }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: WithdrawalRowCell.reuseID, for: indexPath) as! WithdrawalRowCell
        if rows.isEmpty {
            cell.configureEmpty()
        } else {
            cell.configure(with: rows[indexPath.section])
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !rows.isEmpty else { return }
        navigationController?.pushViewController(
            CommissionWithdrawalDetailViewController(item: rows[indexPath.section]), animated: true
        )
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        rows.isEmpty ? 180 : UITableView.automaticDimension
    }
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat { 130 }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { section == 0 ? 8 : 8 }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        section == numberOfSections(in: tableView) - 1 ? 24 : 8
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? { UIView() }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { UIView() }
}

// MARK: - 领取单 row cell

private final class WithdrawalRowCell: UITableViewCell {
    static let reuseID = "WithdrawalRowCell"

    private let card = UIView()
    private let nameLabel = UILabel()
    private let statusTag = StatusTagLabel()
    private let amountLabel = UILabel()
    private let methodLabel = UILabel()
    private let timeLabel = UILabel()
    private let confirmButton = UIButton(type: .system)
    private var onConfirm: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        card.layer.masksToBounds = true
        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.s)
        }

        nameLabel.font = .appSection(15)
        nameLabel.textColor = Theme.Color.ink
        card.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
        }

        card.addSubview(statusTag)
        statusTag.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.l)
            $0.centerY.equalTo(nameLabel)
            $0.leading.greaterThanOrEqualTo(nameLabel.snp.trailing).offset(Theme.Spacing.s)
        }

        amountLabel.font = .appHero(20)
        amountLabel.textColor = Theme.Color.clay
        card.addSubview(amountLabel)
        amountLabel.snp.makeConstraints {
            $0.top.equalTo(nameLabel.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.equalTo(nameLabel)
        }

        methodLabel.font = .appBody(12)
        methodLabel.textColor = Theme.Color.sub
        card.addSubview(methodLabel)
        methodLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.l)
            $0.centerY.equalTo(amountLabel)
        }

        timeLabel.font = .appBody(11)
        timeLabel.textColor = Theme.Color.muted
        card.addSubview(timeLabel)
        timeLabel.snp.makeConstraints {
            $0.top.equalTo(amountLabel.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.equalTo(nameLabel)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.l)
        }

        confirmButton.setTitle("确认到账", for: .normal)
        confirmButton.titleLabel?.font = .appSection(13)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.backgroundColor = Theme.Color.brand
        confirmButton.layer.cornerRadius = 18
        confirmButton.addTarget(self, action: #selector(didTapConfirm), for: .touchUpInside)
        card.addSubview(confirmButton)
        confirmButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.l)
            $0.centerY.equalTo(timeLabel)
            $0.width.equalTo(104)
            $0.height.equalTo(36)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configureEmpty() {
        nameLabel.text = "暂无领取记录"
        statusTag.isHidden = true
        amountLabel.text = ""
        methodLabel.text = ""
        timeLabel.text = "分享课程获得佣金后，可在此发起领取"
        confirmButton.isHidden = true
    }

    func configure(with item: CommissionWithdrawal) {
        nameLabel.text = item.studio?.name ?? "历史提现"
        statusTag.setStatus(item.status ?? 0, text: item.status_text ?? "")
        amountLabel.text = item.amount_text ?? CommissionService.yuan(item.amount)
        methodLabel.text = item.method != nil ? (item.method_text ?? "") : ""
        timeLabel.text = CommissionService.fmtTime(item.created_at)

        let canConfirm = item.can_confirm ?? false
        confirmButton.isHidden = !canConfirm
        onConfirm = canConfirm ? { [weak self] in self?.confirmAction(item) } : nil
    }

    private func confirmAction(_ item: CommissionWithdrawal) {
        ThemeAlertView.show(
            title: "确认收到佣金",
            message: "请确认你已在线下实际收到「\(item.studio?.name ?? "工作室")」打款的 \(item.amount_text ?? "")。确认后将标记为已完成。",
            confirmTitle: "确认已收到",
            cancelTitle: "再核对一下",
            onConfirm: {
                CommissionService.confirmWithdrawal(id: item.withdraw_id ?? "") { [weak self] result in
                    guard let self else { return }
                    let host = self.parentViewController() as? BaseViewController
                    switch result {
                    case .success:
                        host?.showToast("已确认，佣金标记为到账")
                        NotificationCenter.default.post(name: .commissionUpdated, object: nil)
                    case .failure(let error):
                        host?.showToast(error.message)
                    }
                }
            }
        )
    }

    @objc private func didTapConfirm() { onConfirm?() }
}

// MARK: - 状态标签

private final class StatusTagLabel: UILabel {
    override init(frame: CGRect) {
        super.init(frame: frame)
        font = .appLabel(11)
        textAlignment = .center
        layer.cornerRadius = 6
        layer.masksToBounds = true
        contentEdgeInset()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func contentEdgeInset() {
        // 通过 attributed 不好做内边距，改用 drawText 内边距
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.insetBy(dx: 8, dy: 3))
    }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + 16, height: s.height + 6)
    }

    func setStatus(_ status: Int, text: String) {
        self.text = text
        switch status {
        case 0:
            backgroundColor = Theme.Color.warnTint
            textColor = Theme.Color.warn
        case 1:
            backgroundColor = Theme.Color.warnTint
            textColor = Theme.Color.clay
        case 2:
            backgroundColor = Theme.Color.dangerTint
            textColor = Theme.Color.danger
        default:
            backgroundColor = Theme.Color.successTint
            textColor = Theme.Color.success
        }
    }
}

// MARK: - 领取单详情

final class CommissionWithdrawalDetailViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var item: CommissionWithdrawal
    private var sections: [DSec] = [.steps, .payment, .commissions]

    private let bottomBar = UIView()
    private let confirmButton = UIButton(type: .system)

    enum DSec { case steps, payment, commissions, reject }

    init(item: CommissionWithdrawal) {
        self.item = item
        super.init(nibName: nil, bundle: nil)
        rebuildSections()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupBottomBar()
        refreshDetail()
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleUpdated), name: .commissionUpdated, object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "领取单详情")
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    private func rebuildSections() {
        sections = [.steps, .payment, .commissions]
        if item.status == 2 { sections.append(.reject) }
    }

    private func setupTableView() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(StepsCell.self, forCellReuseIdentifier: StepsCell.reuseID)
        tableView.register(PaymentCell.self, forCellReuseIdentifier: PaymentCell.reuseID)
        tableView.register(CommissionLineCell.self, forCellReuseIdentifier: CommissionLineCell.reuseID)
        tableView.register(RejectCell.self, forCellReuseIdentifier: RejectCell.reuseID)
        view.addSubview(tableView)
        let hasBar = item.can_confirm ?? false
        tableView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
            if hasBar { $0.bottom.equalTo(bottomBar.snp.top) } else { $0.bottom.equalToSuperview() }
        }
    }

    private func setupBottomBar() {
        guard item.can_confirm ?? false else { return }
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

        confirmButton.setTitle("确认已收到佣金", for: .normal)
        confirmButton.titleLabel?.font = .appSection(15)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.backgroundColor = Theme.Color.brand
        confirmButton.layer.cornerRadius = 22
        confirmButton.addTarget(self, action: #selector(didTapConfirm), for: .touchUpInside)
        bottomBar.addSubview(confirmButton)
        confirmButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.height.equalTo(44)
        }
    }

    private func refreshDetail() {
        guard let id = item.withdraw_id else { return }
        CommissionService.fetchWithdrawalDetail(id: id) { [weak self] result in
            guard let self else { return }
            if case .success(let latest) = result {
                self.item = latest
                self.rebuildSections()
                self.tableView.reloadData()
            }
        }
    }

    @objc private func handleUpdated() { refreshDetail() }

    @objc private func didTapConfirm() {
        ThemeAlertView.show(
            title: "确认收到佣金",
            message: "请确认你已在线下实际收到工作室打款的 \(item.amount_text ?? "")。确认后将标记为已完成。",
            confirmTitle: "确认已收到",
            cancelTitle: "再核对一下",
            onConfirm: { [weak self] in
                guard let self else { return }
                self.showLoading()
                CommissionService.confirmWithdrawal(id: self.item.withdraw_id ?? "") { [weak self] result in
                    guard let self else { return }
                    self.hideLoading()
                    switch result {
                    case .success(let latest):
                        self.item = latest
                        self.rebuildSections()
                        self.tableView.reloadData()
                        self.bottomBar.isHidden = true
                        self.tableView.snp.remakeConstraints {
                            $0.top.equalTo(self.view.safeAreaLayoutGuide)
                            $0.leading.trailing.bottom.equalToSuperview()
                        }
                        self.showToast("已确认，佣金标记为到账")
                        NotificationCenter.default.post(name: .commissionUpdated, object: nil)
                    case .failure(let error):
                        self.showToast(error.message)
                    }
                }
            }
        )
    }

    // MARK: DataSource

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .steps, .payment, .reject: return 1
        case .commissions:
            return max(item.commissions?.count ?? 0, 1)
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .steps:
            let cell = tableView.dequeueReusableCell(withIdentifier: StepsCell.reuseID, for: indexPath) as! StepsCell
            cell.configure(with: item)
            return cell
        case .payment:
            let cell = tableView.dequeueReusableCell(withIdentifier: PaymentCell.reuseID, for: indexPath) as! PaymentCell
            cell.configure(with: item)
            return cell
        case .reject:
            let cell = tableView.dequeueReusableCell(withIdentifier: RejectCell.reuseID, for: indexPath) as! RejectCell
            cell.configure(reason: item.reject_reason)
            return cell
        case .commissions:
            let cell = tableView.dequeueReusableCell(withIdentifier: CommissionLineCell.reuseID, for: indexPath) as! CommissionLineCell
            let list = item.commissions ?? []
            if list.isEmpty {
                cell.configureEmpty()
            } else {
                cell.configure(with: list[indexPath.row])
            }
            return cell
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch sections[indexPath.section] {
        case .steps: return 168
        case .payment: return UITableView.automaticDimension
        case .commissions: return 64
        case .reject: return UITableView.automaticDimension
        }
    }
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat { 140 }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 8 }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        section == sections.count - 1 ? 24 : 8
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? { UIView() }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { UIView() }
}

// MARK: - 进度 steps cell

private final class StepsCell: UITableViewCell {
    static let reuseID = "StepsCell"
    private let statusLabel = UILabel()
    private let amountLabel = UILabel()
    private let dotsStack = UIStackView()
    private let titlesStack = UIStackView()

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

        statusLabel.font = .appSection(16)
        statusLabel.textColor = Theme.Color.ink
        card.addSubview(statusLabel)
        statusLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
        }

        amountLabel.font = .appHero(22)
        amountLabel.textColor = Theme.Color.clay
        card.addSubview(amountLabel)
        amountLabel.snp.makeConstraints {
            $0.centerY.equalTo(statusLabel)
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.l)
        }

        dotsStack.axis = .horizontal
        dotsStack.distribution = .fillEqually
        card.addSubview(dotsStack)
        dotsStack.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalTo(statusLabel.snp.bottom).offset(Theme.Spacing.xl)
        }

        titlesStack.axis = .horizontal
        titlesStack.distribution = .fillEqually
        card.addSubview(titlesStack)
        titlesStack.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalTo(dotsStack.snp.bottom).offset(Theme.Spacing.s)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.l)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with item: CommissionWithdrawal) {
        statusLabel.text = item.status_text
        amountLabel.text = item.amount_text
        let steps = item.steps ?? []
        dotsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        titlesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for step in steps {
            let dot = StepDot()
            dot.set(step.done ?? false, current: step.current ?? false)
            dotsStack.addArrangedSubview(dot)
            dot.snp.makeConstraints { $0.height.equalTo(26) }

            let title = UILabel()
            title.text = step.title
            title.font = .appBody(11)
            title.textAlignment = .center
            title.numberOfLines = 2
            title.textColor = (step.done ?? false) ? Theme.Color.success : Theme.Color.muted
            titlesStack.addArrangedSubview(title)
        }
    }
}

private final class StepDot: UIView {
    private let circle = UIView()
    private let mark = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(circle)
        circle.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(26)
        }
        circle.layer.cornerRadius = 13

        mark.font = .appBody(12)
        mark.textAlignment = .center
        circle.addSubview(mark)
        mark.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
    required init?(coder: NSCoder) { fatalError() }

    func set(_ done: Bool, current: Bool) {
        if done {
            circle.backgroundColor = Theme.Color.success
            mark.textColor = .white
            mark.text = "✓"
        } else if current {
            circle.backgroundColor = .white
            circle.layer.borderWidth = 1.5
            circle.layer.borderColor = Theme.Color.success.cgColor
            mark.textColor = Theme.Color.success
        } else {
            circle.backgroundColor = Theme.Color.surfaceAlt
            mark.textColor = Theme.Color.muted
        }
    }
}

// MARK: - 打款信息 cell

private final class PaymentCell: UITableViewCell {
    static let reuseID = "PaymentCell"
    private let titleLabel = UILabel()
    private let rowsStack = UIStackView()
    private let voucherScroll = UIScrollView()
    private var voucherStack = UIStackView()

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

        titleLabel.text = "打款信息"
        titleLabel.font = .appSection(15)
        titleLabel.textColor = Theme.Color.ink
        card.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.leading.equalToSuperview().offset(Theme.Spacing.l)
        }

        rowsStack.axis = .vertical
        rowsStack.spacing = Theme.Spacing.s
        card.addSubview(rowsStack)
        rowsStack.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        voucherScroll.showsHorizontalScrollIndicator = false
        card.addSubview(voucherScroll)
        voucherScroll.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(rowsStack.snp.bottom).offset(Theme.Spacing.m)
            $0.height.equalTo(0)
        }

        voucherStack.axis = .horizontal
        voucherStack.spacing = Theme.Spacing.s
        voucherScroll.addSubview(voucherStack)
        voucherStack.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.height.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with item: CommissionWithdrawal) {
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        voucherStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let status = item.status ?? 0
        if status >= 1 {
            rowsStack.addArrangedSubview(InfoRow(title: "打款方式", value: item.method_text ?? "-"))
            if let account = item.account, !account.isEmpty {
                rowsStack.addArrangedSubview(InfoRow(title: "收款账号", value: account))
            }
            if let processed = item.processed_at {
                rowsStack.addArrangedSubview(InfoRow(title: "打款时间", value: CommissionService.fmtFull(processed)))
            }
            if let confirmed = item.confirmed_at {
                rowsStack.addArrangedSubview(InfoRow(title: "确认时间", value: CommissionService.fmtFull(confirmed)))
            }
        } else {
            let wait = UILabel()
            wait.text = "等待工作室在线下完成打款，打款后会在此展示方式与凭证"
            wait.font = .appBody(12)
            wait.textColor = Theme.Color.sub
            wait.numberOfLines = 0
            rowsStack.addArrangedSubview(wait)
        }

        let images = item.voucher_images ?? []
        if images.isEmpty {
            voucherScroll.snp.updateConstraints { $0.height.equalTo(0) }
            rowsStack.snp.makeConstraints { $0.bottom.equalToSuperview().offset(-Theme.Spacing.l) }
        } else {
            voucherScroll.snp.updateConstraints { $0.height.equalTo(80) }
            for (i, url) in images.enumerated() {
                let thumb = VoucherThumb()
                thumb.configure(url: url) { [weak self] in
                    let preview = ImagePreviewViewController(images: images, startIndex: i)
                    self?.parentViewController()?.present(preview, animated: true)
                }
                voucherStack.addArrangedSubview(thumb)
                thumb.snp.makeConstraints { $0.size.equalTo(80) }
            }
            voucherScroll.snp.makeConstraints { $0.bottom.equalToSuperview().offset(-Theme.Spacing.l) }
        }
    }
}

private final class InfoRow: UIView {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    init(title: String, value: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        titleLabel.font = .appBody(12)
        titleLabel.textColor = Theme.Color.sub
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.leading.bottom.equalToSuperview()
        }

        valueLabel.text = value
        valueLabel.font = .appBody(13)
        valueLabel.textColor = Theme.Color.ink
        valueLabel.textAlignment = .right
        addSubview(valueLabel)
        valueLabel.snp.makeConstraints {
            $0.top.bottom.trailing.equalToSuperview()
            $0.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Theme.Spacing.m)
        }
    }
    required init?(coder: NSCoder) { fatalError() }
}

private final class VoucherThumb: UIView {
    private let imageView = UIImageView()
    private var action: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 10
        imageView.layer.masksToBounds = true
        addSubview(imageView)
        imageView.snp.makeConstraints { $0.edges.equalToSuperview() }

        let control = UIControl()
        control.addTarget(self, action: #selector(didTap), for: .touchUpInside)
        addSubview(control)
        control.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(url: String, action: @escaping () -> Void) {
        self.action = action
        if let u = URL(string: url.resolvedImageURL) {
            imageView.kf.setImage(with: u)
        }
    }

    @objc private func didTap() { action?() }
}

// MARK: - 佣金明细行

private final class CommissionLineCell: UITableViewCell {
    static let reuseID = "CommissionLineCell"
    private let card = UIView()
    private let orderLabel = UILabel()
    private let rateLabel = UILabel()
    private let statusLabel = UILabel()
    private let amountLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        card.backgroundColor = Theme.Color.surface
        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.s)
        }

        orderLabel.font = .appBody(12)
        orderLabel.textColor = Theme.Color.sub
        card.addSubview(orderLabel)
        orderLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.s)
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
        }

        rateLabel.font = .appBody(11)
        rateLabel.textColor = Theme.Color.muted
        card.addSubview(rateLabel)
        rateLabel.snp.makeConstraints {
            $0.leading.equalTo(orderLabel)
            $0.top.equalTo(orderLabel.snp.bottom).offset(2)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.s)
        }

        statusLabel.font = .appBody(11)
        statusLabel.textColor = Theme.Color.muted
        card.addSubview(statusLabel)
        statusLabel.snp.makeConstraints {
            $0.centerY.equalToSuperview()
        }

        amountLabel.font = .appSection(15)
        amountLabel.textColor = Theme.Color.ink
        card.addSubview(amountLabel)
        amountLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.l)
            $0.centerY.equalToSuperview()
            $0.leading.greaterThanOrEqualTo(statusLabel.snp.trailing).offset(Theme.Spacing.m)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with c: CommissionWithdrawal.CommissionBrief) {
        orderLabel.text = "订单 \(c.order_id ?? "-")"
        rateLabel.text = "费率 \(Int(c.rate ?? 0))%"
        statusLabel.text = c.status_text
        amountLabel.text = CommissionService.yuan(c.amount)
    }

    func configureEmpty() {
        orderLabel.text = "无明细（历史数据）"
        rateLabel.text = ""
        statusLabel.text = ""
        amountLabel.text = ""
    }
}

// MARK: - 驳回原因 cell

private final class RejectCell: UITableViewCell {
    static let reuseID = "RejectCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(reason: String?) {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        let card = UIView()
        card.backgroundColor = Theme.Color.dangerTint
        card.layer.cornerRadius = Theme.Radius.card
        card.layer.masksToBounds = true
        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.s)
        }

        let title = UILabel()
        title.text = "驳回原因"
        title.font = .appSection(14)
        title.textColor = Theme.Color.danger
        card.addSubview(title)
        title.snp.makeConstraints {
            $0.top.leading.equalToSuperview().offset(Theme.Spacing.l)
        }

        let body = UILabel()
        body.text = reason
        body.font = .appBody(13)
        body.textColor = Theme.Color.danger
        body.numberOfLines = 0
        card.addSubview(body)
        body.snp.makeConstraints {
            $0.top.equalTo(title.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.l)
        }
    }
}

// MARK: - UIView 工具

private extension UIView {
    func parentViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }
}

// MARK: - Notification

extension Notification.Name {
    static let commissionUpdated = Notification.Name("commissionUpdated")
}
