import UIKit
import SnapKit

/// 工作室端「经营概览」（对齐设计稿 studioOverview）
///
/// 结构与「我的」页同构：**顶部 headerView 固定不动**（标题栏 + 营收卡 + 三张统计卡），
/// 下方 `UITableView` 独立滚动（待办事项列表：退款审核 / 订单结算 / 机构动态）。
/// 数据源：GET /v1/studio/overview（金额单位「分」，端上格式化）
final class StudioOverviewViewController: BaseViewController {

    // MARK: - 视图

    private let headerView = StudioOverviewHeaderView()
    private let tableView = UITableView(frame: .zero, style: .plain)

    // MARK: - 数据

    private var overview: StudioOverviewData?

    private enum Row {
        case refund, settle, dynamic
    }
    private let rows: [Row] = [.refund, .settle, .dynamic]

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupLayout()
        setupActions()
        refreshData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        // 处理完退款/结算返回后刷新数字
        refreshData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if navigationController?.viewControllers.count ?? 0 > 1 {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 列表底部对齐悬浮 tabbar 上沿（safeArea 已含 tabbar 高度），再留 12 间距
        tableView.contentInset.bottom = 12
        tableView.verticalScrollIndicatorInsets.bottom = 12
    }

    // MARK: - 布局

    private func setupLayout() {
        // 顶部固定区：不随内容滚动
        view.addSubview(headerView)
        headerView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
        }

        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        // 消除 iOS 15+ plain style 在首个 section 前的默认留白
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.dataSource = self
        tableView.delegate = self
        // 待办 cell 有自定义指定初始化器（图标 / 配色随类型而定），不走 register 自动创建
        tableView.register(OverviewDynamicCell.self, forCellReuseIdentifier: OverviewDynamicCell.reuseId)
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(headerView.snp.bottom)
            $0.leading.trailing.equalToSuperview()
            // 底部对齐悬浮 tabbar 上沿，避免最后一行被 tab 遮挡
            $0.bottom.equalTo(view.safeAreaLayoutGuide)
        }
    }

    private func setupActions() {
        headerView.onBell = { [weak self] in
            self?.tabBarController?.selectedIndex = 3
        }
        headerView.onWithdraw = { [weak self] in
            self?.openPlaceholder(title: "提现", icon: "yensign.circle.fill",
                                  tip: "课程收入结算、提现与账单明细将在下一阶段开放。")
        }
        headerView.onAllTodos = { [weak self] in self?.didTapAllTodos() }
    }

    // MARK: - 数据

    private func refreshData() {
        StudioService.fetchOverview { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let data):
                self.overview = data
                self.apply(data)
            case .failure(let error):
                self.showToast(error.message ?? "加载失败")
            }
        }
    }

    private func apply(_ data: StudioOverviewData) {
        headerView.apply(data)
        tableView.reloadData()
    }

    // MARK: - 交互

    @objc private func didTapAllTodos() {
        navigationController?.pushViewController(StudioTodoViewController(), animated: true)
    }

    private func openRefundReview() {
        navigationController?.pushViewController(StudioRefundViewController(initialStatus: 0), animated: true)
    }

    private func openSettleList() {
        openPlaceholder(title: "结算明细", icon: "doc.text.fill",
                        tip: "结算周期、打款进度与账单明细将在下一阶段开放。")
    }

    private func openStudioPosts() {
        tabBarController?.selectedIndex = 1
    }

    private func openPlaceholder(title: String, icon: String, tip: String) {
        navigationController?.pushViewController(
            StudioPlaceholderViewController(title: title, icon: icon, tip: tip),
            animated: true
        )
    }
}

// MARK: - UITableViewDataSource / Delegate

extension StudioOverviewViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let todos = overview?.todos ?? .empty

        switch rows[indexPath.row] {
        case .refund:
            let cell = (tableView.dequeueReusableCell(withIdentifier: OverviewTodoCell.refundId) as? OverviewTodoCell)
                ?? OverviewTodoCell.refund()
            cell.configure(
                title: "\(todos.pendingRefunds) 笔退款申请待审核",
                subtitle: "超时未处理将自动通过"
            )
            cell.onTap = { [weak self] in self?.openRefundReview() }
            return cell

        case .settle:
            let cell = (tableView.dequeueReusableCell(withIdentifier: OverviewTodoCell.settleId) as? OverviewTodoCell)
                ?? OverviewTodoCell.settle()
            if todos.pendingSettleOrders > 0 {
                cell.configure(
                    title: "\(todos.pendingSettleOrders) 笔课程订单待结算",
                    subtitle: "收入合计 \(todos.pendingSettleAmountText)"
                )
            } else {
                cell.configure(title: "暂无待结算订单", subtitle: "新课订单收款后将自动结算")
            }
            cell.onTap = { [weak self] in self?.openSettleList() }
            return cell

        case .dynamic:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: OverviewDynamicCell.reuseId,
                for: indexPath
            ) as! OverviewDynamicCell
            cell.configure(overview?.dynamic ?? .empty)
            cell.onTap = { [weak self] in self?.openStudioPosts() }
            return cell
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch rows[indexPath.row] {
        case .dynamic:
            return UITableView.automaticDimension
        default:
            return OverviewTodoCell.rowHeight
        }
    }

    /// 区头已随「待办事项 + 全部 ›」固定在 headerView 里，列表内不再渲染 section header
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
}

// MARK: - 待办行 Cell

/// 待办行 cell：**自带**一张待办卡（退款 / 结算两种样式由 reuseId 区分），左右 18、行间 12
private final class OverviewTodoCell: UITableViewCell {

    static let refundId = "OverviewTodoRefundCell"
    static let settleId = "OverviewTodoSettleCell"
    /// 卡片 76 + 行间 12
    static let rowHeight: CGFloat = 88

    var onTap: (() -> Void)?

    private let row: OverviewTodoRow

    init(icon: String, tint: UIColor, action: String, reuseId: String) {
        row = OverviewTodoRow(icon: icon, tint: tint, title: "", subtitle: "", action: action)
        super.init(style: .default, reuseIdentifier: reuseId)
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(row)
        row.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.height.equalTo(OverviewTodoCell.rowHeight - 12)
        }
        row.onTap = { [weak self] in self?.onTap?() }
    }

    /// 退款行
    static func refund() -> OverviewTodoCell {
        OverviewTodoCell(icon: "arrow.uturn.backward", tint: Theme.Color.brand,
                         action: "处理", reuseId: refundId)
    }

    /// 结算行
    static func settle() -> OverviewTodoCell {
        OverviewTodoCell(icon: "doc.text", tint: Theme.Color.wood,
                         action: "查看", reuseId: settleId)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, subtitle: String) {
        row.set(title: title)
        row.set(subtitle: subtitle)
    }
}

// MARK: - 机构动态 Cell

/// 机构动态 cell：自带机构播报卡，高度自适应
private final class OverviewDynamicCell: UITableViewCell {

    static let reuseId = "OverviewDynamicCell"

    var onTap: (() -> Void)? {
        didSet { card.onTap = onTap }
    }

    private let card = OverviewDynamicCard()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.bottom.equalToSuperview().inset(12)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ dynamic: StudioOverviewDynamic) {
        card.refresh(dynamic)
    }
}

// MARK: - 待办行卡

/// 白色待办卡：圆角方形图标块 + 标题 / 副标题 + 右侧动作文字
private final class OverviewTodoRow: UIControl {

    var onTap: (() -> Void)?

    private let iconTile = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let actionLabel = UILabel()
    private let actionChevron = UIImageView()

    init(icon: String, tint: UIColor, title: String, subtitle: String, action: String) {
        super.init(frame: .zero)
        backgroundColor = Theme.Color.surface
        layer.cornerRadius = 16
        layer.shadowColor = UIColor(hex: 0x2B2621).cgColor
        layer.shadowOpacity = 0.05
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 6)
        addTarget(self, action: #selector(didTap), for: .touchUpInside)

        iconTile.backgroundColor = tint
        iconTile.layer.cornerRadius = 14
        iconTile.isUserInteractionEnabled = false
        addSubview(iconTile)
        iconTile.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(14)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(46)
        }

        iconView.image = UIImage(systemName: icon)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold))
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        iconTile.addSubview(iconView)
        iconView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.width.height.equalTo(24)
        }

        // 右侧动作（先入层，避免被 titleLabel 约束跨层级引用）
        actionLabel.font = .appSection(13)
        actionLabel.textColor = Theme.Color.brand
        actionLabel.text = action
        actionLabel.isUserInteractionEnabled = false
        addSubview(actionLabel)

        actionChevron.image = UIImage(systemName: "chevron.right")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold))
        actionChevron.tintColor = Theme.Color.brand
        actionChevron.contentMode = .scaleAspectFit
        actionChevron.isUserInteractionEnabled = false
        addSubview(actionChevron)
        actionChevron.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(15)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(8)
        }
        actionLabel.snp.makeConstraints {
            $0.trailing.equalTo(actionChevron.snp.leading).offset(-3)
            $0.centerY.equalToSuperview()
        }

        titleLabel.font = .appSection(15)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.text = title
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(iconTile.snp.trailing).offset(12)
            $0.trailing.lessThanOrEqualTo(actionLabel.snp.leading).offset(-8)
            $0.bottom.equalTo(snp.centerY).offset(-2)
        }

        subtitleLabel.font = .appLabel(12)
        subtitleLabel.textColor = Theme.Color.muted
        subtitleLabel.text = subtitle
        subtitleLabel.isUserInteractionEnabled = false
        addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints {
            $0.leading.equalTo(titleLabel)
            $0.top.equalTo(snp.centerY).offset(3)
            $0.trailing.lessThanOrEqualTo(actionLabel.snp.leading).offset(-8)
        }

        snp.makeConstraints { $0.height.equalTo(76) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func set(title: String) {
        titleLabel.text = title
    }

    func set(subtitle: String) {
        subtitleLabel.text = subtitle
    }

    @objc private func didTap() {
        onTap?()
    }
}

// MARK: - 机构动态卡

/// 机构经营播报卡：机构名 + 工作室标签 + 今日招生 + 本周播报正文 + 本周报名 / 营收
private final class OverviewDynamicCard: UIControl {

    var onTap: (() -> Void)?

    private let iconTile = UIView()
    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    private let roleTag = UIView()
    private let roleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let headlineLabel = UILabel()
    private let enrolledLabel = UILabel()
    private let incomeLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.Color.surface
        layer.cornerRadius = 16
        layer.shadowColor = UIColor(hex: 0x2B2621).cgColor
        layer.shadowOpacity = 0.05
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 6)
        addTarget(self, action: #selector(didTap), for: .touchUpInside)

        iconTile.backgroundColor = Theme.Color.brand
        iconTile.layer.cornerRadius = 14
        addSubview(iconTile)
        iconTile.snp.makeConstraints {
            $0.top.leading.equalToSuperview().offset(14)
            $0.width.height.equalTo(46)
        }

        iconView.image = UIImage(systemName: "building.2")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold))
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconTile.addSubview(iconView)
        iconView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.width.height.equalTo(24)
        }

        // 机构名
        nameLabel.font = .appSection(15)
        nameLabel.textColor = Theme.Color.ink
        nameLabel.text = "我的工作室"
        addSubview(nameLabel)

        // 「工作室」标签（先入层，再被 nameLabel 约束引用）
        roleTag.backgroundColor = Theme.Color.brandSoft
        roleTag.layer.cornerRadius = 8
        addSubview(roleTag)
        roleLabel.font = .appLabel(10)
        roleLabel.textColor = Theme.Color.brand
        roleLabel.text = "工作室"
        roleTag.addSubview(roleLabel)
        roleLabel.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 2, left: 7, bottom: 2, right: 7))
        }

        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(iconTile.snp.trailing).offset(12)
            $0.centerY.equalTo(roleTag)
        }
        roleTag.snp.makeConstraints {
            $0.leading.equalTo(nameLabel.snp.trailing).offset(6)
            $0.top.equalToSuperview().offset(18)
        }

        subtitleLabel.font = .appLabel(12)
        subtitleLabel.textColor = Theme.Color.muted
        subtitleLabel.text = "今日招生 0 人"
        addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.top.equalTo(roleTag.snp.bottom).offset(5)
        }

        // 播报正文
        headlineLabel.font = .appBody(14)
        headlineLabel.textColor = Theme.Color.ink
        headlineLabel.numberOfLines = 0
        headlineLabel.text = "本周经营数据持续更新中。"
        addSubview(headlineLabel)
        headlineLabel.snp.makeConstraints {
            $0.top.equalTo(iconTile.snp.bottom).offset(14)
            $0.leading.trailing.equalToSuperview().inset(14)
        }

        // 底部指标：本周报名 / 营收
        let enrolledIcon = makeMetricIcon("person.badge.plus", color: Theme.Color.muted)
        addSubview(enrolledIcon)
        enrolledIcon.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(14)
            $0.top.equalTo(headlineLabel.snp.bottom).offset(12)
            $0.width.height.equalTo(13)
        }
        enrolledLabel.font = .appLabel(12)
        enrolledLabel.textColor = Theme.Color.sub
        enrolledLabel.text = "本周报名 0 人"
        addSubview(enrolledLabel)
        enrolledLabel.snp.makeConstraints {
            $0.leading.equalTo(enrolledIcon.snp.trailing).offset(5)
            $0.centerY.equalTo(enrolledIcon)
        }

        let incomeIcon = makeMetricIcon("arrow.up.right", color: Theme.Color.brand)
        addSubview(incomeIcon)
        incomeIcon.snp.makeConstraints {
            $0.leading.equalTo(enrolledLabel.snp.trailing).offset(18)
            $0.top.equalTo(headlineLabel.snp.bottom).offset(12)
            $0.width.height.equalTo(13)
        }
        incomeLabel.font = .appSection(12)
        incomeLabel.textColor = Theme.Color.brand
        incomeLabel.text = "营收 +¥ 0"
        addSubview(incomeLabel)
        incomeLabel.snp.makeConstraints {
            $0.leading.equalTo(incomeIcon.snp.trailing).offset(5)
            $0.centerY.equalTo(incomeIcon)
            $0.bottom.equalToSuperview().inset(16)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func makeMetricIcon(_ name: String, color: UIColor) -> UIImageView {
        let view = UIImageView(image: UIImage(systemName: name)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)))
        view.tintColor = color
        view.contentMode = .scaleAspectFit
        return view
    }

    func refresh(_ dynamic: StudioOverviewDynamic) {
        nameLabel.text = dynamic.studioName
        subtitleLabel.text = "今日招生 \(dynamic.todayEnrolled) 人"
        headlineLabel.text = dynamic.headlineText
        enrolledLabel.text = "本周报名 \(dynamic.weeklyEnrolled) 人"
        incomeLabel.text = "营收 \(dynamic.weeklyIncomeText)"
    }

    @objc private func didTap() {
        onTap?()
    }
}
