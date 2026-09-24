import UIKit
import SnapKit
import Kingfisher
import ESPullToRefresh

/// 工作室端「订单管理」：按状态分段查看订单列表，支持搜索
/// 状态：0 待收款 / 1 已收款 / 2 已取消 / 3 已退款
final class StudioOrderListViewController: BaseViewController {

    // MARK: - 分段

    private let filters = StudioOrderFilter.allCases

    // MARK: - 数据

    private var currentFilterIndex: Int = 0
    private var orders: [StudioOrder] = []
    private var page = 1
    private var total = 0
    private var isLoading = false
    private let pageSize = 20
    private var hasMore: Bool { orders.count < total }
    private var firstLoad = true
    private var searchKeyword: String = ""

    // MARK: - 视图

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = EmptyStateView()
    private var chipRow: TagChipRow?
    private var searchBar: StudioOrderSearchBar?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadOrders(reset: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "订单管理")
        if !firstLoad { loadOrders(reset: true) }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    // MARK: - 布局

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg

        // 分段切换
        let chipRow = TagChipRow(
            chips: filters.map { $0.title },
            selectedIndex: 0
        )
        chipRow.onSelect = { [weak self] index in
            guard let self else { return }
            self.currentFilterIndex = index
            self.loadOrders(reset: true)
        }
        view.addSubview(chipRow)
        chipRow.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.height.equalTo(34)
        }
        self.chipRow = chipRow

        // 搜索栏
        let searchBar = StudioOrderSearchBar()
        searchBar.onChange = { [weak self] keyword in
            self?.searchKeyword = keyword
        }
        searchBar.onSearch = { [weak self] in
            self?.loadOrders(reset: true)
        }
        searchBar.onCancel = { [weak self] in
            self?.searchKeyword = ""
            self?.loadOrders(reset: true)
        }
        view.addSubview(searchBar)
        searchBar.snp.makeConstraints {
            $0.top.equalTo(chipRow.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.height.equalTo(36)
        }
        self.searchBar = searchBar

        // 列表
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(StudioOrderCell.self, forCellReuseIdentifier: StudioOrderCell.reuseID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 160
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(searchBar.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.loadOrders(reset: true)
        }
        tableView.es.addInfiniteScrolling { [weak self] in
            self?.loadOrders(reset: false)
        }

        emptyView.isHidden = true
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.centerX.equalTo(tableView)
            $0.top.equalTo(tableView.snp.top).offset(200)
        }
    }

    // MARK: - 数据加载

    private func loadOrders(reset: Bool) {
        if reset { page = 1 }
        guard !isLoading else { return }
        isLoading = true
        let filter = filters[currentFilterIndex]
        let status = filter.apiValue

        StudioService.fetchOrders(
            status: status,
            keyword: searchKeyword.trimmingCharacters(in: .whitespacesAndNewlines),
            page: page,
            pageSize: pageSize
        ) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            self.firstLoad = false
            self.tableView.es.stopPullToRefresh()
            self.tableView.es.stopLoadingMore()
            switch result {
            case .success(let data):
                self.total = data.total
                if reset { self.orders = data.list } else { self.orders.append(contentsOf: data.list) }
                self.page += 1
                self.refreshEmptyState()
                self.tableView.reloadData()
            case .failure(let error):
                if reset { self.showToast(error.message ?? "加载失败") }
            }
        }
    }

    private func refreshEmptyState() {
        let isEmpty = orders.isEmpty
        emptyView.isHidden = !isEmpty
        if isEmpty {
            emptyView.show(style: .empty(filters[currentFilterIndex].emptyText))
        }
    }
}

// MARK: - TableView

extension StudioOrderListViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        orders.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: StudioOrderCell.reuseID, for: indexPath) as! StudioOrderCell
        let item = orders[indexPath.row]
        cell.configure(with: item)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let order = orders[indexPath.row]
        let vc = StudioOrderDetailViewController(order: order)
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - 搜索栏

private final class StudioOrderSearchBar: UIView, UITextFieldDelegate {

    var onChange: ((String) -> Void)?
    var onSearch: (() -> Void)?
    var onCancel: (() -> Void)?

    private let fieldCard = UIView()
    private let icon = UIImageView()
    private let textField = UITextField()

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear

        fieldCard.backgroundColor = Theme.Color.surface
        fieldCard.layer.cornerRadius = 14
        addSubview(fieldCard)

        icon.image = UIImage(systemName: "magnifyingglass")?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        )
        icon.tintColor = Theme.Color.muted
        icon.contentMode = .center
        fieldCard.addSubview(icon)
        icon.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(12)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(18)
        }

        textField.placeholder = "搜索订单号 / 学员 / 家长"
        textField.font = .appBody(14)
        textField.textColor = Theme.Color.ink
        textField.tintColor = Theme.Color.brand
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .search
        textField.delegate = self
        textField.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
        fieldCard.addSubview(textField)
        textField.snp.makeConstraints {
            $0.leading.equalTo(icon.snp.trailing).offset(8)
            $0.trailing.equalToSuperview().offset(-12)
            $0.centerY.equalToSuperview()
        }

        fieldCard.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
            $0.trailing.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func editingChanged() {
        onChange?(textField.text ?? "")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        onSearch?()
        return true
    }
}

// MARK: - 订单卡片

final class StudioOrderCell: UITableViewCell {
    static let reuseID = "StudioOrderCell"

    private let card = UIView()
    private let statusPill = PaddingLabel()
    private let orderNoLabel = UILabel()
    private let sourceLabel = UILabel()
    private let parentLabel = UILabel()
    private let courseLabel = UILabel()
    private let amountLabel = UILabel()
    private let lessonsLabel = UILabel()
    private let dateLabel = UILabel()
    private let pendingHint = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.top.equalToSuperview().offset(6)
            $0.bottom.equalToSuperview().offset(-6)
        }

        // 状态标签（右上）
        statusPill.font = .appLabel(11)
        statusPill.layer.cornerRadius = 12
        statusPill.clipsToBounds = true
        statusPill.textInsets = UIEdgeInsets(top: 3, left: 10, bottom: 3, right: 10)
        card.addSubview(statusPill)
        statusPill.snp.makeConstraints {
            $0.top.equalToSuperview().inset(Theme.Spacing.l)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        // 订单号
        orderNoLabel.font = .appLabel(13)
        orderNoLabel.textColor = Theme.Color.muted
        card.addSubview(orderNoLabel)
        orderNoLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalToSuperview().inset(Theme.Spacing.l)
            $0.trailing.lessThanOrEqualTo(statusPill.snp.leading).offset(-8)
        }

        // 来源
        sourceLabel.font = .appLabel(11)
        sourceLabel.textColor = Theme.Color.sub
        card.addSubview(sourceLabel)
        sourceLabel.snp.makeConstraints {
            $0.leading.equalTo(orderNoLabel)
            $0.top.equalTo(orderNoLabel.snp.bottom).offset(4)
        }

        // 家长
        parentLabel.font = .appSection(15)
        parentLabel.textColor = Theme.Color.ink
        card.addSubview(parentLabel)
        parentLabel.snp.makeConstraints {
            $0.leading.equalTo(orderNoLabel)
            $0.top.equalTo(sourceLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.trailing.lessThanOrEqualToSuperview().inset(Theme.Spacing.l)
        }

        // 课程
        courseLabel.font = .appLabel(13)
        courseLabel.textColor = Theme.Color.sub
        card.addSubview(courseLabel)
        courseLabel.snp.makeConstraints {
            $0.leading.equalTo(orderNoLabel)
            $0.top.equalTo(parentLabel.snp.bottom).offset(4)
            $0.trailing.lessThanOrEqualToSuperview().inset(Theme.Spacing.l)
        }

        // 金额（右下）
        amountLabel.font = .appSection(17)
        amountLabel.textColor = Theme.Color.clay
        amountLabel.textAlignment = .right
        card.addSubview(amountLabel)
        amountLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalTo(parentLabel)
        }

        // 课时
        lessonsLabel.font = .appLabel(12)
        lessonsLabel.textColor = Theme.Color.muted
        lessonsLabel.textAlignment = .right
        card.addSubview(lessonsLabel)
        lessonsLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalTo(amountLabel.snp.bottom).offset(4)
        }

        // 日期
        dateLabel.font = .appLabel(12)
        dateLabel.textColor = Theme.Color.muted
        card.addSubview(dateLabel)
        dateLabel.snp.makeConstraints {
            $0.leading.equalTo(orderNoLabel)
            $0.top.equalTo(courseLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }

        // 待确认凭证提示
        pendingHint.font = .appLabel(12)
        pendingHint.textColor = Theme.Color.warn
        pendingHint.text = "有待确认凭证"
        pendingHint.isHidden = true
        card.addSubview(pendingHint)
        pendingHint.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalTo(dateLabel)
        }
    }

    func configure(with order: StudioOrder) {
        orderNoLabel.text = order.order_no ?? ""
        sourceLabel.text = order.sourceLabel
        parentLabel.text = order.parentName
        courseLabel.text = order.courseTitle
        amountLabel.text = order.totalAmountText
        lessonsLabel.text = order.totalLessonsText
        dateLabel.text = order.createdDate
        pendingHint.isHidden = !order.hasPendingPayment
        configureStatus(order.orderStatus)
        setNeedsLayout()
    }

    private func configureStatus(_ status: StudioOrderStatus) {
        let config: (String, UIColor, UIColor)
        switch status {
        case .pending:        config = ("待收款", Theme.Color.warn, Theme.Color.warnTint)
        case .paymentReview:  config = ("待确认收款", Theme.Color.warn, Theme.Color.warnTint)
        case .collected:      config = ("已收款", Theme.Color.success, Theme.Color.successTint)
        case .refundReview:   config = ("退款审核中", Theme.Color.warn, Theme.Color.warnTint)
        case .refundConfirm:  config = ("待确认退款", Theme.Color.warn, Theme.Color.warnTint)
        case .refunded:       config = ("已退款", Theme.Color.danger, Theme.Color.dangerTint)
        case .cancelled:      config = ("已取消", Theme.Color.muted, Theme.Color.surfaceAlt)
        }
        statusPill.text = config.0
        statusPill.textColor = config.1
        statusPill.backgroundColor = config.2
    }
}