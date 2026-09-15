import UIKit
import SnapKit

/// 订单详情（家长端，对齐 PR：状态卡 / 课程信息 / 订单信息 / 课时进度 / 底部操作）
/// 使用 UITableView 分组（.insetGrouped）承载卡片，天然左右对称全宽
/// 按后端实际字段实现：无材料包/优惠券字段则省略；约可退 = 剩余课时 × (实付/总课时)
final class OrderDetailViewController: BaseViewController {

    private let orderId: String
    private var order: OrderItem?

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let bottomBar = UIView()
    private let primaryButton = UIButton(type: .system)
    private let secondaryButton = UIButton(type: .system)
    private var statusRow: RowType?
    private var courseRow: RowType?
    private var orderInfoRows: [RowType] = []
    private var progressRows: [RowType] = []

    fileprivate enum RowType {
        case status(title: String, desc: String)
        case course(title: String, subtitle: String)
        case row(title: String, value: String, brand: Bool)
    }

    init(orderId: String) {
        self.orderId = orderId
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureImmersiveNav(title: "订单详情")
        setupBottomBar()
        setupTableView()
        loadData()
    }

    // MARK: - UI

    private func setupTableView() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.alwaysBounceVertical = true
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(OrderDetailCell.self, forCellReuseIdentifier: OrderDetailCell.reuseID)
        tableView.contentInset = UIEdgeInsets(top: Theme.Spacing.s, left: 0, bottom: 100, right: 0)
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            $0.bottom.equalTo(bottomBar.snp.top)
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
        stack.distribution = .fillEqually
        bottomBar.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(44)
        }

        secondaryButton.titleLabel?.font = .appBody(15)
        secondaryButton.setTitleColor(Theme.Color.ink, for: .normal)
        secondaryButton.backgroundColor = Theme.Color.surfaceAlt
        secondaryButton.layer.cornerRadius = 22
        secondaryButton.addTarget(self, action: #selector(didTapSecondary), for: .touchUpInside)

        primaryButton.titleLabel?.font = .appBody(15)
        primaryButton.setTitleColor(.white, for: .normal)
        primaryButton.backgroundColor = Theme.Color.brand
        primaryButton.layer.cornerRadius = 22
        primaryButton.addTarget(self, action: #selector(didTapPrimary), for: .touchUpInside)

        stack.addArrangedSubview(secondaryButton)
        stack.addArrangedSubview(primaryButton)
    }

    // MARK: - Data

    private func loadData() {
        showLoading()
        OrderService.fetchOrderDetail(orderId: orderId) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success(let order):
                self.order = order
                self.render(order)
            case .failure(let error):
                self.showToast(error.message ?? "加载失败")
            }
        }
    }

    private func render(_ order: OrderItem) {
        statusRow = nil
        courseRow = nil
        orderInfoRows.removeAll()
        progressRows.removeAll()

        let statusTitle: String
        let statusDesc: String
        switch order.statusValue {
        case .enrolled:
            statusTitle = "√ 已报名 · 学习中"
            statusDesc = "已完成\(order.consumed_lessons ?? 0)/\(order.total_lessons ?? 0)节 · 剩余课时可申请退款"
        case .pending:
            statusTitle = "待支付"
            statusDesc = "订单待支付，请尽快完成支付"
        case .cancelled:
            statusTitle = "已取消"
            statusDesc = "订单已取消"
        case .completed:
            statusTitle = "已完成"
            statusDesc = "课程已完成"
        }
        statusRow = .status(title: statusTitle, desc: statusDesc)
        courseRow = .course(title: order.courseTitleWithLessons, subtitle: order.studioTeacherText)
        orderInfoRows = [
            .row(title: "订单号", value: order.order_no ?? "-", brand: false),
            .row(title: "下单时间", value: order.created_at?.replacingOccurrences(of: "T", with: " ").prefix(16).description ?? "-", brand: false),
            .row(title: "课程费用", value: OrderItem.fenToYuan(order.total_amount ?? 0), brand: false),
            .row(title: "实付", value: OrderItem.fenToYuan(order.paid_amount ?? order.total_amount ?? 0), brand: true)
        ]

        let consumed = order.consumed_lessons ?? 0
        let total = order.total_lessons ?? 0
        let remaining = order.remaining_lessons ?? max(total - consumed, 0)
        let refundHint = order.statusValue == .enrolled
            ? "\(remaining)节 · 约可退\(OrderItem.fenToYuan(estimatedRefund(order)))"
            : "\(remaining)节"
        progressRows = [
            .row(title: "已上课时", value: "\(consumed)节（已消课）", brand: false),
            .row(title: "剩余课时", value: refundHint, brand: order.statusValue == .enrolled)
        ]

        tableView.reloadData()
        updateBottomBar(order)
    }

    private func updateBottomBar(_ order: OrderItem) {
        switch order.statusValue {
        case .pending:
            secondaryButton.setTitle("取消", for: .normal)
            primaryButton.setTitle("去支付", for: .normal)
            primaryButton.isEnabled = true
            secondaryButton.isHidden = false
        case .enrolled, .completed:
            secondaryButton.setTitle("申请退款", for: .normal)
            primaryButton.setTitle("去学习", for: .normal)
            primaryButton.isEnabled = true
            secondaryButton.isHidden = false
        case .cancelled:
            primaryButton.setTitle("重新报名", for: .normal)
            primaryButton.isEnabled = false
            secondaryButton.isHidden = true
        }
    }

    private func estimatedRefund(_ order: OrderItem) -> Int {
        let total = order.total_lessons ?? 0
        let remaining = order.remaining_lessons ?? 0
        let paid = order.paid_amount ?? order.total_amount ?? 0
        guard total > 0 else { return 0 }
        return Int((Double(paid) * Double(remaining) / Double(total)).rounded())
    }

    // MARK: - Actions

    @objc private func didTapPrimary() {
        guard let order else { return }
        switch order.statusValue {
        case .pending:
            navigationController?.pushViewController(OrderPayViewController(order: order), animated: true)
        case .enrolled, .completed:
            showToast("去学习开发中")
        case .cancelled:
            break
        }
    }

    @objc private func didTapSecondary() {
        guard let order, let orderId = order.order_id else { return }
        switch order.statusValue {
        case .pending:
            let alert = UIAlertController(title: "取消订单", message: "确定取消该待支付订单吗？", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "再想想", style: .cancel))
            alert.addAction(UIAlertAction(title: "取消订单", style: .destructive) { [weak self] _ in
                self?.cancelOrder(orderId)
            })
            present(alert, animated: true)
        case .enrolled, .completed:
            let alert = UIAlertController(title: "申请退款", message: "退还将按剩余课时计算，确定申请吗？", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "再想想", style: .cancel))
            alert.addAction(UIAlertAction(title: "申请退款", style: .destructive) { [weak self] _ in
                self?.requestRefund(orderId)
            })
            present(alert, animated: true)
        case .cancelled:
            break
        }
    }

    private func cancelOrder(_ orderId: String) {
        showLoading()
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

    private func requestRefund(_ orderId: String) {
        showLoading()
        OrderService.requestRefund(orderId: orderId, lessons: 1, reason: nil) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success:
                self.showToast("退款申请已提交")
            case .failure(let error):
                self.showToast(error.message ?? "申请失败")
            }
        }
    }
}

// MARK: - UITableViewDataSource / Delegate

extension OrderDetailViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { 4 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return statusRow == nil ? 0 : 1
        case 1: return courseRow == nil ? 0 : 1
        case 2: return orderInfoRows.count
        case 3: return progressRows.count
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: OrderDetailCell.reuseID, for: indexPath) as! OrderDetailCell
        switch indexPath.section {
        case 0:
            if let statusRow { cell.configure(with: statusRow) }
        case 1:
            if let courseRow { cell.configure(with: courseRow) }
        case 2:
            cell.configure(with: orderInfoRows[indexPath.row])
        case 3:
            cell.configure(with: progressRows[indexPath.row])
        default:
            break
        }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        indexPath.section == 0 ? 100 : (indexPath.section == 1 ? 96 : 46)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section > 0 else { return nil }
        let titles = ["", "课程信息", "订单信息", "课时进度"]
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
}

// MARK: - Cell

private final class OrderDetailCell: UITableViewCell {

    static let reuseID = "OrderDetailCell"

    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let stack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Theme.Color.surface
        contentView.backgroundColor = Theme.Color.surface

        stack.axis = .vertical
        stack.spacing = 6
        contentView.addSubview(stack)

        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with row: OrderDetailViewController.RowType) {
        // 清理旧约束
        titleLabel.snp.removeConstraints()
        valueLabel.snp.removeConstraints()
        stack.snp.removeConstraints()
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        titleLabel.isHidden = true
        valueLabel.isHidden = true
        stack.isHidden = true

        switch row {
        case .status(let title, let desc):
            stack.isHidden = false
            let statusLabel = UILabel()
            statusLabel.text = title
            statusLabel.font = .appSection(17)
            statusLabel.textColor = Theme.Color.brand
            let descLabel = UILabel()
            descLabel.text = desc
            descLabel.font = .appLabel(13)
            descLabel.textColor = Theme.Color.sub
            descLabel.numberOfLines = 0
            stack.addArrangedSubview(statusLabel)
            stack.addArrangedSubview(descLabel)
            stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(Theme.Spacing.l) }

        case .course(let title, let subtitle):
            stack.isHidden = false
            let courseLabel = UILabel()
            courseLabel.text = title
            courseLabel.font = .appSection(17)
            courseLabel.textColor = Theme.Color.ink
            let studioLabel = UILabel()
            studioLabel.text = subtitle
            studioLabel.font = .appLabel(14)
            studioLabel.textColor = Theme.Color.sub
            stack.addArrangedSubview(courseLabel)
            stack.addArrangedSubview(studioLabel)
            stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(Theme.Spacing.l) }

        case .row(let title, let value, let brand):
            titleLabel.isHidden = false
            valueLabel.isHidden = false
            titleLabel.text = title
            titleLabel.font = .appLabel(14)
            titleLabel.textColor = Theme.Color.sub
            valueLabel.text = value
            valueLabel.font = .appBody(14)
            valueLabel.textColor = brand ? Theme.Color.brand : Theme.Color.ink
            valueLabel.textAlignment = .right
            valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            titleLabel.snp.makeConstraints {
                $0.leading.centerY.equalToSuperview().inset(Theme.Spacing.l)
            }
            valueLabel.snp.makeConstraints {
                $0.trailing.centerY.equalToSuperview().inset(Theme.Spacing.l)
                $0.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Theme.Spacing.m)
            }
        }
    }
}
