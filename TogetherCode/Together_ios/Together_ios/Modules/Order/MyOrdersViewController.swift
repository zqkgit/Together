import UIKit
import SnapKit
import ESPullToRefresh

/// 我的订单（家长端，对齐 PR：全部/待支付/已报名 Tab + 订单卡片）
final class MyOrdersViewController: BaseViewController {

    private enum Tab: Int, CaseIterable {
        case all = 0
        case pending
        case enrolled

        var title: String {
            switch self {
            case .all: return "全部"
            case .pending: return "待支付"
            case .enrolled: return "已报名"
            }
        }
        /// 对应的后端 status（all 无过滤）
        var status: Int? {
            switch self {
            case .all: return nil
            case .pending: return 0
            case .enrolled: return 1
            }
        }
    }

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var tabBar: TabBarView!
    private var orders: [OrderItem] = []
    private var currentTab: Tab = .all
    private let emptyView = EmptyStateView()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureImmersiveNav(title: "我的订单")
        setupUI()
        loadData()
    }

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg

        // Tab 固定在导航下方
        tabBar = TabBarView(titles: Tab.allCases.map(\.title))
        tabBar.onSelect = { [weak self] index in
            guard let self, let tab = Tab(rawValue: index) else { return }
            self.currentTab = tab
            self.loadData()
        }
        view.addSubview(tabBar)
        tabBar.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(44)
        }

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(OrderCell.self, forCellReuseIdentifier: "OrderCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 150
        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.loadData()
        }
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(tabBar.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        emptyView.isHidden = true
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints { $0.center.equalToSuperview() }
    }

    private func loadData() {
        emptyView.show(style: .loading)
        OrderService.fetchOrders(status: currentTab.status) { [weak self] result in
            guard let self else { return }
            self.tableView.es.stopPullToRefresh()
            switch result {
            case .success(let list):
                self.orders = list
                self.tableView.reloadData()
                self.updateEmptyState()
            case .failure(let error):
                self.emptyView.show(style: .error(error.message) { [weak self] in
                    self?.loadData()
                })
            }
        }
    }

    private func updateEmptyState() {
        let isEmpty = orders.isEmpty
        emptyView.isHidden = !isEmpty
        if isEmpty {
            emptyView.show(style: .empty(currentTab == .all ? "暂无订单" : "\(currentTab.title)暂无订单"))
        }
    }

    // MARK: - 操作

    private func cancelOrder(_ order: OrderItem) {
        ThemeAlertView.show(
            title: "取消订单",
            message: "确定取消该待支付订单吗？",
            confirmTitle: "取消订单",
            cancelTitle: "再想想",
            onConfirm: { [weak self] in
                guard let self, let orderId = order.order_id else { return }
                self.showLoading()
                OrderService.cancelOrder(orderId: orderId) { [weak self] result in
                    guard let self else { return }
                    self.hideLoading()
                    switch result {
                    case .success:
                        self.showToast("订单已取消")
                        self.loadData()
                    case .failure(let error):
                        self.showToast(error.message ?? "取消失败")
                    }
                }
            }
        )
    }

    private func goPay(_ order: OrderItem) {
        let vc = OrderPayViewController(order: order)
        vc.onPaid = { [weak self] in
            self?.loadData()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func goCourse(_ order: OrderItem) {
        guard let courseId = order.course?.course_id, let childId = order.child?.child_id else {
            showToast("课程信息缺失")
            return
        }
        let vc = CourseStudyViewController(
            childId: childId,
            courseId: courseId,
            courseTitle: order.course?.title ?? "课程学习"
        )
        navigationController?.pushViewController(vc, animated: true)
    }
}

extension MyOrdersViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        orders.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "OrderCell", for: indexPath) as! OrderCell
        cell.configure(orders[indexPath.row])
        cell.onAction = { [weak self] action in
            guard let self else { return }
            let order = self.orders[indexPath.row]
            switch action {
            case .cancel: self.cancelOrder(order)
            case .pay: self.goPay(order)
            case .schedule: self.goCourse(order)
            case .study: self.goCourse(order)
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let orderId = orders[indexPath.row].order_id else { return }
        navigationController?.pushViewController(OrderDetailViewController(orderId: orderId), animated: true)
    }
}

// MARK: - 订单卡片 Cell

final class OrderCell: UITableViewCell {

    enum Action {
        case cancel      // 取消
        case pay         // 去支付
        case schedule    // 查看课表
        case study       // 去学习
    }

    var onAction: ((Action) -> Void)?

    private let card = UIView()
    private let orderNoLabel = UILabel()
    private let statusLabel = UILabel()
    private let titleLabel = UILabel()
    private let studioLabel = UILabel()
    private let amountLabel = UILabel()
    private let actionStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(card)
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        card.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        // 行1：订单号 + 状态
        orderNoLabel.font = .appLabel(12)
        orderNoLabel.textColor = Theme.Color.sub
        statusLabel.font = .appLabel(13)
        statusLabel.textAlignment = .right
        let row1 = UIStackView(arrangedSubviews: [orderNoLabel, statusLabel])
        row1.spacing = Theme.Spacing.s

        titleLabel.font = .appSection(17)
        titleLabel.textColor = Theme.Color.ink

        studioLabel.font = .appLabel(13)
        studioLabel.textColor = Theme.Color.sub

        // 行4：金额 + 按钮
        amountLabel.font = .appSection(17)
        amountLabel.textColor = Theme.Color.ink
        actionStack.axis = .horizontal
        actionStack.spacing = Theme.Spacing.m
        actionStack.setContentHuggingPriority(.required, for: .horizontal)
        let row4 = UIStackView(arrangedSubviews: [amountLabel, actionStack])
        row4.spacing = Theme.Spacing.s
        row4.alignment = .center

        let stack = UIStackView(arrangedSubviews: [row1, titleLabel, studioLabel, row4])
        stack.axis = .vertical
        stack.spacing = 8
        card.addSubview(stack)
        stack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ order: OrderItem) {
        orderNoLabel.text = "订单号\(order.order_no ?? "-")"
        statusLabel.text = order.statusValue.text
        statusLabel.textColor = statusColor(order.statusValue)
        titleLabel.text = order.courseTitleWithLessons
        studioLabel.text = order.studioTeacherText
        amountLabel.text = order.amountText

        actionStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let actions: [(String, Action, Bool)] = buttonActions(for: order)
        for (title, action, isPrimary) in actions {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .appLabel(13)
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
            button.layer.cornerRadius = 15
            if isPrimary {
                button.backgroundColor = Theme.Color.brand
                button.setTitleColor(.white, for: .normal)
            } else {
                button.backgroundColor = .clear
                button.setTitleColor(Theme.Color.ink, for: .normal)
                button.layer.borderWidth = 1
                button.layer.borderColor = Theme.Color.line.cgColor
            }
            button.onTap { [weak self] in
                self?.onAction?(action)
            }
            actionStack.addArrangedSubview(button)
        }
    }

    private func buttonActions(for order: OrderItem) -> [(String, Action, Bool)] {
        switch order.statusValue {
        case .pending:
            return [("取消", .cancel, false), ("去支付", .pay, true)]
        case .enrolled:
            return [("查看课表", .schedule, false), ("去学习", .study, true)]
        default:
            return []
        }
    }

    private func statusColor(_ status: OrderStatus) -> UIColor {
        switch status {
        case .pending: return UIColor.systemOrange
        case .enrolled: return Theme.Color.brand
        default: return Theme.Color.sub
        }
    }
}

private extension UIView {
    /// 轻量点击回调（避免引入 target-action 样板）
    func onTap(_ action: @escaping () -> Void) {
        isUserInteractionEnabled = true
        let recognizer = TapGestureRecognizer(action: action)
        addGestureRecognizer(recognizer)
    }
}

private final class TapGestureRecognizer: UITapGestureRecognizer {
    private var action: (() -> Void)?
    convenience init(action: @escaping () -> Void) {
        self.init()
        self.action = action
        addTarget(self, action: #selector(handle))
    }
    @objc private func handle() { action?() }
}
