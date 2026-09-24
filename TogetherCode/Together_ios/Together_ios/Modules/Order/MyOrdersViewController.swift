import UIKit
import SnapKit
import ESPullToRefresh

/// 我的订单（家长端 · 线下收款模式）
/// Tab：全部 / 待付款 / 待确认 / 已报名 / 已取消 / 已退款
/// 平台不经手资金：待付款订单线下付款后上传凭证，机构确认收款发课时。
final class MyOrdersViewController: BaseViewController {

    private enum Tab: Int, CaseIterable {
        case all, pending, paymentReview, enrolled, cancelled, refunded
        var title: String {
            switch self {
            case .all: return "全部"
            case .pending: return "待付款"
            case .paymentReview: return "待确认"
            case .enrolled: return "已报名"
            case .cancelled: return "已取消"
            case .refunded: return "已退款"
            }
        }
        var status: Int? {
            switch self {
            case .all: return nil
            case .pending: return 0
            case .paymentReview: return 1
            case .enrolled: return 2
            case .cancelled: return 6
            case .refunded: return 5
            }
        }
    }

    private var orders: [OrderItem] = []
    private var selectedTabIndex = 0
    private var isLoading = false

    private var chipRow: TagChipRow!
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = EmptyStateView()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureImmersiveNav(title: "我的订单")
        setupUI()
        loadOrders()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        restoreSystemNav()
        if !orders.isEmpty { loadOrders() }
    }

    private func setupUI() {
        chipRow = TagChipRow(chips: Tab.allCases.map { $0.title }, selectedIndex: 0)
        chipRow.onSelect = { [weak self] index in
            self?.selectedTabIndex = index
            self?.loadOrders()
        }
        view.addSubview(chipRow)
        chipRow.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(OrderCell.self, forCellReuseIdentifier: OrderCell.reuseID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 180
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(chipRow.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        emptyView.show(style: .empty("暂无订单"))
        emptyView.isHidden = true
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.center.equalTo(tableView)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.xl)
        }

        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.loadOrders()
        }
    }

    private func loadOrders() {
        guard !isLoading else { return }
        isLoading = true
        let tab = Tab(rawValue: selectedTabIndex) ?? .all

        OrderService.fetchOrders(status: tab.status) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                self.tableView.es.stopPullToRefresh()
                self.isLoading = false
                switch result {
                case .success(let list):
                    self.orders = list
                    self.emptyView.isHidden = !list.isEmpty
                    self.tableView.reloadData()
                case .failure(let error):
                    self.showToast(error.message ?? "加载失败")
                }
            }
        }
    }

    // MARK: - 操作

    fileprivate func handleAction(_ action: OrderCell.Action, order: OrderItem) {
        switch action {
        case .cancel:
            ThemeAlertView.show(
                title: "取消订单",
                message: "确定取消该待付款订单吗？",
                confirmTitle: "取消订单",
                cancelTitle: "再想想",
                onConfirm: { [weak self] in
                    guard let orderId = order.order_id else { return }
                    self?.cancelOrder(orderId)
                }
            )
        case .voucher:
            let vc = PaymentVoucherViewController(order: order)
            vc.onSubmitted = { [weak self] in self?.loadOrders() }
            navigationController?.pushViewController(vc, animated: true)
        case .study:
            guard let courseId = order.course?.course_id, let childId = order.child?.child_id else { return }
            navigationController?.pushViewController(
                CourseStudyViewController(childId: childId, courseId: courseId, courseTitle: order.course?.title ?? "课程学习"),
                animated: true
            )
        case .refundDetail:
            guard let refundId = order.latestRefundId else { return }
            navigationController?.pushViewController(RefundDetailViewController(refundId: refundId), animated: true)
        case .reorder:
            guard let courseId = order.course?.course_id else { return }
            navigationController?.pushViewController(CourseEnrollViewController(courseId: courseId), animated: true)
        }
    }

    private func cancelOrder(_ orderId: String) {
        showLoading()
        OrderService.cancelOrder(orderId: orderId) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                self.hideLoading()
                switch result {
                case .success:
                    self.showToast("订单已取消")
                    self.loadOrders()
                case .failure(let error):
                    self.showToast(error.message ?? "取消失败")
                }
            }
        }
    }
}

// MARK: - DataSource / Delegate

extension MyOrdersViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { orders.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: OrderCell.reuseID, for: indexPath) as! OrderCell
        let order = orders[indexPath.row]
        cell.configure(with: order)
        cell.onAction = { [weak self] action in
            self?.handleAction(action, order: order)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let orderId = orders[indexPath.row].order_id else { return }
        navigationController?.pushViewController(OrderDetailViewController(orderId: orderId), animated: true)
    }
}

// MARK: - 订单卡片（纵向 StackView 布局，隐藏提示自动折叠）

final class OrderCell: UITableViewCell {
    static let reuseID = "OrderCell"

    enum Action {
        case cancel, voucher, study, refundDetail, reorder
    }

    var onAction: ((Action) -> Void)?

    private let card = UIView()
    private let titleLabel = UILabel()
    private let statusBadge = PaddingLabel()
    private let subtitleLabel = UILabel()
    private let hintLabel = UILabel()
    private let amountLabel = UILabel()
    private let buttonRow = UIStackView()
    private let contentStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalToSuperview().offset(6)
            $0.bottom.equalToSuperview().offset(-6)
        }

        titleLabel.font = .appSection(15)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 2
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        statusBadge.font = .appLabel(11)
        statusBadge.layer.cornerRadius = 6
        statusBadge.clipsToBounds = true
        statusBadge.textAlignment = .center
        statusBadge.setContentHuggingPriority(.required, for: .horizontal)
        statusBadge.setContentCompressionResistancePriority(.required, for: .horizontal)
        statusBadge.snp.makeConstraints { $0.height.equalTo(20) }

        let titleRow = UIStackView(arrangedSubviews: [titleLabel, statusBadge])
        titleRow.axis = .horizontal
        titleRow.spacing = Theme.Spacing.s
        titleRow.alignment = .top

        subtitleLabel.font = .appLabel(12)
        subtitleLabel.textColor = Theme.Color.sub
        subtitleLabel.numberOfLines = 1

        hintLabel.font = .appLabel(12)
        hintLabel.numberOfLines = 0

        amountLabel.font = .appSection(17)
        amountLabel.textColor = Theme.Color.clay
        amountLabel.setContentHuggingPriority(.required, for: .horizontal)
        amountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        buttonRow.axis = .horizontal
        buttonRow.spacing = Theme.Spacing.s
        buttonRow.alignment = .center

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let bottomRow = UIStackView(arrangedSubviews: [amountLabel, spacer, buttonRow])
        bottomRow.axis = .horizontal
        bottomRow.alignment = .center

        contentStack.axis = .vertical
        contentStack.spacing = 8
        contentStack.alignment = .fill
        card.addSubview(contentStack)
        contentStack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(Theme.Spacing.l)
        }
        contentStack.addArrangedSubview(titleRow)
        contentStack.setCustomSpacing(6, after: titleRow)
        contentStack.addArrangedSubview(subtitleLabel)
        contentStack.setCustomSpacing(10, after: subtitleLabel)
        contentStack.addArrangedSubview(hintLabel)
        contentStack.setCustomSpacing(12, after: hintLabel)
        contentStack.addArrangedSubview(bottomRow)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with order: OrderItem) {
        titleLabel.text = order.courseTitleWithLessons
        subtitleLabel.text = order.studioClassText
        subtitleLabel.isHidden = order.studioClassText.isEmpty
        amountLabel.text = order.amountText

        // 状态 badge（退款聚合优先）
        let badgeText: String
        let badgeColor: UIColor
        let badgeBg: UIColor
        switch order.refundStatusValue {
        case .processing:
            badgeText = "退款中"; badgeColor = Theme.Color.warn; badgeBg = Theme.Color.warnTint
        case .refunded:
            badgeText = "已退款"; badgeColor = Theme.Color.brand; badgeBg = Theme.Color.brandSoft
        case .rejected:
            badgeText = "退款驳回"; badgeColor = Theme.Color.danger; badgeBg = Theme.Color.dangerTint
        case .none:
            switch order.statusValue {
            case .pendingCollect:
                badgeText = "待付款"; badgeColor = Theme.Color.warn; badgeBg = Theme.Color.warnTint
            case .paymentReview:
                badgeText = "待确认"; badgeColor = Theme.Color.warn; badgeBg = Theme.Color.warnTint
            case .collected:
                badgeText = "已报名"; badgeColor = Theme.Color.brand; badgeBg = Theme.Color.brandSoft
            case .refundReview:
                badgeText = "退款审核中"; badgeColor = Theme.Color.warn; badgeBg = Theme.Color.warnTint
            case .refundConfirm:
                badgeText = "待确认退款"; badgeColor = Theme.Color.warn; badgeBg = Theme.Color.warnTint
            case .refunded:
                badgeText = "已退款"; badgeColor = Theme.Color.brand; badgeBg = Theme.Color.brandSoft
            case .cancelled:
                badgeText = "已取消"; badgeColor = Theme.Color.muted; badgeBg = Theme.Color.surfaceAlt
            }
        }
        statusBadge.text = "  \(badgeText)  "
        statusBadge.textColor = badgeColor
        statusBadge.backgroundColor = badgeBg

        // 提示
        let hint: (text: String, color: UIColor)?
        switch order.refundStatusValue {
        case .processing:
            hint = ("退款处理中，请留意机构线下退款", Theme.Color.warn)
        case .rejected:
            hint = ("退款未通过，可在订单详情再次申请", Theme.Color.danger)
        case .refunded:
            hint = nil
        case .none:
            switch order.statusValue {
            case .pendingCollect:
                if order.rejectedPayment != nil {
                    hint = ("付款凭证未通过，请重新上传", Theme.Color.danger)
                } else {
                    hint = ("请线下付款后上传凭证，机构确认后发课时", Theme.Color.warn)
                }
            case .paymentReview:
                hint = ("凭证已提交，等待机构确认", Theme.Color.warn)
            case .collected:
                hint = ("报名成功，课时已到账", Theme.Color.brand)
            case .refundReview:
                hint = ("退款审核中，请等待机构处理", Theme.Color.warn)
            case .refundConfirm:
                hint = ("请确认退款信息", Theme.Color.warn)
            case .refunded:
                hint = nil
            case .cancelled:
                hint = nil
            }
        }
        if let hint {
            hintLabel.text = hint.text
            hintLabel.textColor = hint.color
            hintLabel.isHidden = false
        } else {
            hintLabel.text = nil
            hintLabel.isHidden = true
        }

        rebuildButtons(order)
        setNeedsLayout()
        layoutIfNeeded()
    }

    private func rebuildButtons(_ order: OrderItem) {
        buttonRow.arrangedSubviews.forEach {
            buttonRow.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for action in buttonActions(order) {
            let btn = makeButton(action)
            buttonRow.addArrangedSubview(btn)
            btn.snp.makeConstraints { $0.height.equalTo(32) }
        }
    }

    private func buttonActions(_ order: OrderItem) -> [Action] {
        if order.refundStatusValue != .none {
            return [.refundDetail]
        }
        switch order.statusValue {
        case .pendingCollect:
            return [.cancel, .voucher]
        case .paymentReview:
            // 凭证审核中：不允许重复上传或取消，仅展示等待提示
            return []
        case .collected:
            return [.study]
        case .refundReview, .refundConfirm:
            return [.refundDetail]
        case .refunded:
            return []
        case .cancelled:
            return [.reorder]
        }
    }

    private func makeButton(_ action: Action) -> UIButton {
        let titles: [Action: String] = [
            .cancel: "取消", .voucher: "上传凭证", .study: "去学习",
            .refundDetail: "查看退款", .reorder: "重新报名"
        ]
        let primary: Set<Action> = [.voucher, .study, .reorder]
        let btn = UIButton(type: .system)
        btn.setTitle(titles[action], for: .normal)
        btn.titleLabel?.font = .appLabel(13)
        btn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        btn.layer.cornerRadius = 16
        if primary.contains(action) {
            btn.backgroundColor = Theme.Color.brand
            btn.setTitleColor(.white, for: .normal)
        } else {
            btn.backgroundColor = Theme.Color.surfaceAlt
            btn.setTitleColor(Theme.Color.ink, for: .normal)
        }
        btn.addAction(UIAction { [weak self] _ in self?.onAction?(action) }, for: .touchUpInside)
        return btn
    }
}
