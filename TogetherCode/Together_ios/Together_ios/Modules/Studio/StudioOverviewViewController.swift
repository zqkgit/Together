import UIKit
import SnapKit

/// 工作室端「经营概览」（对齐设计稿 studioOverview）
/// 结构：标题栏（经营概览 + 通知铃铛）
///      → 深绿营收卡（本月营收 / 提现入口 / 可提现 · 分销返利 · 结算中）
///      → 三张经营统计卡（在读学员 / 在售课程 / 入驻教师）
///      → 待办事项（退款申请待审核 / 课程订单待结算 / 机构动态播报）
/// 数据源：GET /v1/studio/overview（金额单位「分」，端上格式化）
final class StudioOverviewViewController: BaseViewController {

    // MARK: - 视图

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let titleLabel = UILabel()
    private let bellButton = UIButton(type: .system)

    private let revenueCard = UIView()
    private let revenueCaptionLabel = UILabel()
    private let withdrawButton = UIButton(type: .system)
    private let revenueAmountLabel = UILabel()
    private var revenueValueLabels: [UILabel] = []
    private var revenueGradient: CAGradientLayer?

    private let statsRow = UIStackView()
    private var statCards: [OverviewStatCard] = []

    private let todosTitleLabel = UILabel()
    private let todosAllButton = UIControl()
    private let refundCard = OverviewTodoRow(
        icon: "arrow.uturn.backward",
        tint: Theme.Color.brand,
        title: "退款申请待审核",
        subtitle: "超时未处理将自动通过",
        action: "处理"
    )
    private let settleCard = OverviewTodoRow(
        icon: "doc.text",
        tint: Theme.Color.wood,
        title: "课程订单待结算",
        subtitle: "暂无待结算订单",
        action: "查看"
    )
    private let dynamicCard = OverviewDynamicCard()

    // MARK: - 数据

    private var overview: StudioOverviewData?

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupLayout()
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
        // 透明 tabbar 悬浮于内容之上：底部留出安全区（含 tabbar 高度）+ 间距
        let bottom = view.safeAreaInsets.bottom + 12
        scrollView.contentInset.bottom = bottom
        scrollView.verticalScrollIndicatorInsets.bottom = bottom
        // 渐变色层跟随营收卡尺寸
        revenueGradient?.frame = revenueCard.bounds
    }

    // MARK: - 布局

    private func setupLayout() {
        scrollView.backgroundColor = Theme.Color.bg
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }

        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.width.equalTo(scrollView)
        }

        setupTitleBar()
        setupRevenueCard()
        setupStatsRow()
        setupTodos()
    }

    private func setupTitleBar() {
        titleLabel.text = "经营概览"
        titleLabel.font = .appTitle(24)
        titleLabel.textColor = Theme.Color.ink
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(contentView.safeAreaLayoutGuide).offset(Theme.Spacing.s)
            $0.leading.equalToSuperview().offset(20)
        }

        bellButton.backgroundColor = Theme.Color.surface
        bellButton.layer.cornerRadius = 19
        bellButton.layer.shadowColor = UIColor(hex: 0x2B2621).cgColor
        bellButton.layer.shadowOpacity = 0.05
        bellButton.layer.shadowRadius = 10
        bellButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        bellButton.setImage(
            UIImage(systemName: "bell")?.withConfiguration(
                UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            ),
            for: .normal
        )
        bellButton.tintColor = Theme.Color.ink
        bellButton.addTarget(self, action: #selector(didTapBell), for: .touchUpInside)
        contentView.addSubview(bellButton)
        bellButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(20)
            $0.centerY.equalTo(titleLabel)
            $0.width.height.equalTo(38)
        }
    }

    // MARK: - 营收卡

    private func setupRevenueCard() {
        revenueCard.layer.cornerRadius = 18
        revenueCard.layer.masksToBounds = true
        revenueCard.backgroundColor = Theme.Color.brandDark
        contentView.addSubview(revenueCard)
        revenueCard.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.height.equalTo(178)
        }

        // 深绿渐变（brand → brandDark），与「我的」封面同源
        let gradient = CAGradientLayer()
        gradient.colors = [Theme.Color.brand.cgColor, Theme.Color.brandDark.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 0.7, y: 1)
        gradient.frame = CGRect(x: 0, y: 0, width: 375, height: 178)
        revenueCard.layer.insertSublayer(gradient, at: 0)
        revenueGradient = gradient

        // 右上装饰光晕
        let orb = UIView()
        orb.backgroundColor = Theme.Color.wood.withAlphaComponent(0.16)
        orb.layer.cornerRadius = 70
        orb.isUserInteractionEnabled = false
        revenueCard.addSubview(orb)
        orb.snp.makeConstraints {
            $0.top.equalToSuperview().offset(-40)
            $0.trailing.equalToSuperview().offset(40)
            $0.width.height.equalTo(140)
        }

        revenueCaptionLabel.text = "本月营收（元）"
        revenueCaptionLabel.font = .appLabel(12)
        revenueCaptionLabel.textColor = UIColor.white.withAlphaComponent(0.82)
        revenueCard.addSubview(revenueCaptionLabel)
        revenueCaptionLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(20)
            $0.leading.equalToSuperview().offset(18)
        }

        // 提现 pill（白底深绿字）
        var withdrawConfig = UIButton.Configuration.filled()
        withdrawConfig.baseBackgroundColor = Theme.Color.surface
        withdrawConfig.baseForegroundColor = Theme.Color.brandDark
        withdrawConfig.background.cornerRadius = 14
        withdrawConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15)
        withdrawConfig.attributedTitle = AttributedString(
            "提现",
            attributes: AttributeContainer([.font: UIFont.appSection(12.5)])
        )
        withdrawButton.configuration = withdrawConfig
        withdrawButton.addTarget(self, action: #selector(didTapWithdraw), for: .touchUpInside)
        revenueCard.addSubview(withdrawButton)
        withdrawButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(18)
            $0.centerY.equalTo(revenueCaptionLabel)
            $0.height.equalTo(28)
        }

        revenueAmountLabel.textColor = .white
        revenueAmountLabel.attributedText = revenueAmountText(for: 0)
        revenueCard.addSubview(revenueAmountLabel)
        revenueAmountLabel.snp.makeConstraints {
            $0.top.equalTo(revenueCaptionLabel.snp.bottom).offset(6)
            $0.leading.equalToSuperview().offset(18)
            $0.trailing.lessThanOrEqualToSuperview().inset(18)
        }

        // 三列：可提现 / 分销返利 / 结算中
        let metricsStack = UIStackView()
        metricsStack.axis = .horizontal
        metricsStack.distribution = .fillEqually
        metricsStack.alignment = .leading
        revenueCard.addSubview(metricsStack)
        metricsStack.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.bottom.equalToSuperview().inset(18)
        }

        for title in ["可提现", "分销返利", "结算中"] {
            let item = UIView()
            let value = UILabel()
            value.font = .appHero(16)
            value.textColor = .white
            value.text = "¥ 0"
            item.addSubview(value)
            value.snp.makeConstraints {
                $0.top.leading.equalToSuperview()
                $0.trailing.lessThanOrEqualToSuperview()
            }
            let label = UILabel()
            label.font = .appLabel(11)
            label.textColor = UIColor.white.withAlphaComponent(0.72)
            label.text = title
            item.addSubview(label)
            label.snp.makeConstraints {
                $0.top.equalTo(value.snp.bottom).offset(5)
                $0.leading.bottom.equalToSuperview()
                $0.trailing.lessThanOrEqualToSuperview()
            }
            revenueValueLabels.append(value)
            metricsStack.addArrangedSubview(item)
        }
    }

    /// 「¥ 86,420」：币种符号小一号，数字等宽防跳变
    private func revenueAmountText(for fen: Int) -> NSAttributedString {
        let text = NSMutableAttributedString(
            string: "¥ ",
            attributes: [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9)
            ]
        )
        text.append(NSAttributedString(
            string: StudioAmount.groupedNumber(fen),
            attributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 34, weight: .bold),
                .foregroundColor: UIColor.white
            ]
        ))
        return text
    }

    // MARK: - 三张统计卡

    private func setupStatsRow() {
        statsRow.axis = .horizontal
        statsRow.spacing = 12
        statsRow.distribution = .fillEqually
        contentView.addSubview(statsRow)
        statsRow.snp.makeConstraints {
            $0.top.equalTo(revenueCard.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.height.equalTo(80)
        }

        for title in ["在读学员", "在售课程", "入驻教师"] {
            let card = OverviewStatCard(title: title)
            statCards.append(card)
            statsRow.addArrangedSubview(card)
        }
    }

    // MARK: - 待办事项

    private func setupTodos() {
        todosTitleLabel.text = "待办事项"
        todosTitleLabel.font = .appSection(17)
        todosTitleLabel.textColor = Theme.Color.ink
        contentView.addSubview(todosTitleLabel)
        todosTitleLabel.snp.makeConstraints {
            $0.top.equalTo(statsRow.snp.bottom).offset(26)
            $0.leading.equalToSuperview().offset(20)
        }

        let allLabel = UILabel()
        allLabel.text = "全部"
        allLabel.font = .appLabel(12)
        allLabel.textColor = Theme.Color.sub
        let allChevron = UIImageView(image: UIImage(systemName: "chevron.right")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)))
        allChevron.tintColor = Theme.Color.muted
        allChevron.contentMode = .scaleAspectFit

        // 先入层再被引用（约束铁律）
        todosAllButton.addSubview(allLabel)
        todosAllButton.addSubview(allChevron)
        allLabel.snp.makeConstraints {
            $0.leading.centerY.equalToSuperview()
        }
        allChevron.snp.makeConstraints {
            $0.leading.equalTo(allLabel.snp.trailing).offset(3)
            $0.trailing.centerY.equalToSuperview()
            $0.width.height.equalTo(8)
        }
        todosAllButton.addTarget(self, action: #selector(didTapAllTodos), for: .touchUpInside)
        contentView.addSubview(todosAllButton)
        todosAllButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(18)
            $0.centerY.equalTo(todosTitleLabel)
            $0.height.equalTo(28)
        }

        refundCard.onTap = { [weak self] in self?.openRefundReview() }
        settleCard.onTap = { [weak self] in self?.openSettleList() }
        dynamicCard.onTap = { [weak self] in self?.openStudioPosts() }

        let stack = UIStackView(arrangedSubviews: [refundCard, settleCard, dynamicCard])
        stack.axis = .vertical
        stack.spacing = 12
        contentView.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalTo(todosTitleLabel.snp.bottom).offset(12)
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.bottom.equalToSuperview().inset(24)
        }
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
        let revenue = data.revenue ?? .empty
        revenueAmountLabel.attributedText = revenueAmountText(for: revenue.monthIncome)
        let metrics = [revenue.withdrawableText, revenue.distributionText, revenue.settlingText]
        for (index, text) in metrics.enumerated() where index < revenueValueLabels.count {
            revenueValueLabels[index].text = text
        }

        let stats = data.stats ?? .empty
        let values = [stats.active_students, stats.online_courses, stats.teachers]
        for (index, value) in values.enumerated() where index < statCards.count {
            statCards[index].setValue(value ?? 0)
        }

        let todos = data.todos ?? .empty
        refundCard.set(title: "\(todos.pendingRefunds) 笔退款申请待审核")
        if todos.pendingSettleOrders > 0 {
            settleCard.set(title: "\(todos.pendingSettleOrders) 笔课程订单待结算")
            settleCard.set(subtitle: "收入合计 \(todos.pendingSettleAmountText)")
        } else {
            settleCard.set(title: "暂无待结算订单")
            settleCard.set(subtitle: "新课订单收款后将自动结算")
        }

        dynamicCard.refresh(data.dynamic ?? .empty)
    }

    // MARK: - 交互

    @objc private func didTapBell() {
        tabBarController?.selectedIndex = 3
    }

    @objc private func didTapWithdraw() {
        openPlaceholder(title: "提现", icon: "yensign.circle.fill",
                        tip: "课程收入结算、提现与账单明细将在下一阶段开放。")
    }

    @objc private func didTapAllTodos() {
        openPlaceholder(title: "待办事项", icon: "checklist",
                        tip: "退款审核、订单结算与经营提醒的完整列表将在下一阶段开放。")
    }

    private func openRefundReview() {
        openPlaceholder(title: "退款审核", icon: "arrow.uturn.backward.circle.fill",
                        tip: "退款申请审核与打款将在下一阶段开放。")
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

// MARK: - 统计小卡

/// 白色小卡：Hero 数字 + 标签
private final class OverviewStatCard: UIView {

    private let valueLabel = UILabel()
    private let titleLabel = UILabel()

    init(title: String) {
        super.init(frame: .zero)
        backgroundColor = Theme.Color.surface
        layer.cornerRadius = 16
        layer.shadowColor = UIColor(hex: 0x2B2621).cgColor
        layer.shadowOpacity = 0.05
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 6)

        valueLabel.font = .appHero(24)
        valueLabel.textColor = Theme.Color.brandDark
        valueLabel.textAlignment = .center
        valueLabel.text = "0"
        addSubview(valueLabel)
        valueLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(17)
            $0.centerX.equalToSuperview()
            $0.height.equalTo(28)
        }

        titleLabel.font = .appLabel(11)
        titleLabel.textColor = Theme.Color.muted
        titleLabel.textAlignment = .center
        titleLabel.text = title
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(13)
            $0.centerX.equalToSuperview()
            $0.height.equalTo(15)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setValue(_ value: Int) {
        valueLabel.text = "\(value)"
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
