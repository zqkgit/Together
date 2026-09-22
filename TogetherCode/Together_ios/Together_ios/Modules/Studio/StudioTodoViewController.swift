import UIKit
import SnapKit
import ESPullToRefresh

/// 工作室 App 端 · 待办事项
/// 聚合：退款审核（待审核）/ 待打款确认 / 订单待结算。前两类进入退款审核对应分段，结算暂在 Web 端处理。
final class StudioTodoViewController: BaseViewController {

    struct Row {
        let icon: String
        let tint: UIColor
        let soft: UIColor
        let title: String
        let detail: String
        let badge: Int
        let type: TodoType
    }
    enum TodoType {
        case refundReview   // 退款审核（待审核）
        case refundPayout   // 待打款确认
        case settlement     // 订单结算（暂未在 App 开放）
    }

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = EmptyStateView()
    private var rows: [Row] = []
    private var overview: StudioOverviewData?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "待办事项")
        if overview != nil { loadData() }   // 审核返回后刷新角标
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(StudioTodoCell.self, forCellReuseIdentifier: StudioTodoCell.reuseID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 88
        // iOS 15+ plain style 会在首个 section 前预留约 22pt
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.loadData()
        }
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.m)
            $0.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        emptyView.isHidden = true
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints { $0.center.equalTo(tableView) }
    }

    private func loadData() {
        if overview == nil { emptyView.show(style: .loading) }
        StudioService.fetchOverview { [weak self] result in
            guard let self else { return }
            self.tableView.es.stopPullToRefresh()
            switch result {
            case .success(let data):
                self.overview = data
                self.buildRows(data)
                self.tableView.reloadData()
                self.emptyView.isHidden = true
            case .failure(let error):
                self.emptyView.isHidden = false
                self.emptyView.show(style: .error(error.message ?? "加载失败") { [weak self] in
                    self?.loadData()
                })
            }
        }
    }

    private func buildRows(_ data: StudioOverviewData) {
        let todos = data.todos ?? .empty
        rows = [
            Row(
                icon: "arrow.uturn.backward.circle.fill",
                tint: Theme.Color.danger,
                soft: Theme.Color.dangerTint,
                title: "退款审核",
                detail: todos.pendingRefunds > 0 ? "\(todos.pendingRefunds) 笔退款申请待审核" : "暂无待审核退款",
                badge: todos.pendingRefunds,
                type: .refundReview
            ),
            Row(
                icon: "banknote.fill",
                tint: Theme.Color.warn,
                soft: Theme.Color.warnTint,
                title: "待打款确认",
                detail: todos.pendingPayouts > 0 ? "\(todos.pendingPayouts) 笔退款待打款确认" : "暂无待打款退款",
                badge: todos.pendingPayouts,
                type: .refundPayout
            ),
            Row(
                icon: "doc.text.fill",
                tint: Theme.Color.brand,
                soft: Theme.Color.brandSoft,
                title: "订单结算",
                detail: todos.pendingSettleOrders > 0
                    ? "\(todos.pendingSettleOrders) 笔订单待结算 · \(todos.pendingSettleAmountText)"
                    : "暂无待结算订单",
                badge: todos.pendingSettleOrders,
                type: .settlement
            )
        ]
    }
}

extension StudioTodoViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: StudioTodoCell.reuseID, for: indexPath) as! StudioTodoCell
        cell.configure(rows[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch rows[indexPath.row].type {
        case .refundReview:
            navigationController?.pushViewController(StudioRefundViewController(initialStatus: 0), animated: true)
        case .refundPayout:
            navigationController?.pushViewController(StudioRefundViewController(initialStatus: 1), animated: true)
        case .settlement:
            showToast("订单结算请在 Web 工作室后台处理，App 端即将开放")
        }
    }
}

private final class StudioTodoCell: UITableViewCell {
    static let reuseID = "StudioTodoCell"
    /// 卡片高度（上下各留 6 → 行高 88）
    static let cardHeight: CGFloat = 76

    private let card = UIView()
    private let iconBox = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let badgeLabel = PaddingLabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        // 卡片：左右 12，行间 12，**显式高度**（内容全用 centerY/相对定位，
        // 不给高度的话 automaticDimension 会算出塌缩高度 → 多行挤在一起）
        contentView.addSubview(card)
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        card.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.top.equalToSuperview().offset(6)
            $0.bottom.equalToSuperview().offset(-6)
            $0.height.equalTo(Self.cardHeight)
        }

        // 右侧控件先入层（避免被左侧 label 约束跨层级引用）
        chevron.tintColor = Theme.Color.muted
        chevron.contentMode = .scaleAspectFit
        card.addSubview(chevron)
        chevron.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.width.equalTo(8)
        }

        badgeLabel.font = .appLabel(11)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = Theme.Color.danger
        badgeLabel.layer.cornerRadius = 10
        badgeLabel.clipsToBounds = true
        badgeLabel.textInsets = UIEdgeInsets(top: 2, left: 7, bottom: 2, right: 7)
        card.addSubview(badgeLabel)
        badgeLabel.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            // 角标位置必须用等式钉住，否则欠定会飘到卡片中间
            $0.trailing.equalTo(chevron.snp.leading).offset(-8)
        }

        iconBox.layer.cornerRadius = Theme.Radius.icon
        card.addSubview(iconBox)
        iconBox.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(40)
        }
        iconView.contentMode = .center
        iconBox.addSubview(iconView)
        iconView.snp.makeConstraints { $0.center.equalToSuperview() }

        titleLabel.font = .appSection(15)
        titleLabel.textColor = Theme.Color.ink
        card.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(iconBox.snp.trailing).offset(Theme.Spacing.m)
            $0.top.equalTo(iconBox).offset(2)
            $0.trailing.lessThanOrEqualTo(badgeLabel.snp.leading).offset(-8)
        }

        detailLabel.font = .appLabel(12)
        detailLabel.textColor = Theme.Color.muted
        card.addSubview(detailLabel)
        detailLabel.snp.makeConstraints {
            $0.leading.equalTo(titleLabel)
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
            $0.bottom.equalTo(iconBox).offset(-2)
            $0.trailing.lessThanOrEqualTo(badgeLabel.snp.leading).offset(-8)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ row: StudioTodoViewController.Row) {
        iconBox.backgroundColor = row.soft
        iconView.image = UIImage(systemName: row.icon)
        iconView.tintColor = row.tint
        titleLabel.text = row.title
        detailLabel.text = row.detail
        badgeLabel.isHidden = row.badge <= 0
        badgeLabel.text = row.badge > 99 ? "99+" : "\(row.badge)"
    }
}
