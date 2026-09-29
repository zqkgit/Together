import UIKit
import SnapKit

/// 工作室「经营概览」顶部固定区：标题栏 + 深绿营收卡 + 三张统计卡 + 待办事项区头
///
/// 与「我的」页同构：本视图直接挂在 `view` 上（**不进滚动视图**），
/// 下方列表（UITableView）从它底部开始独立滚动。
/// 「待办事项 + 全部 ›」也在这里固定，不随列表滚动。
final class StudioOverviewHeaderView: UIView {

    // MARK: - 回调

    var onBell: (() -> Void)?
    var onCardTap: (() -> Void)?
    var onAllTodos: (() -> Void)?

    // MARK: - 视图

    private let titleLabel = UILabel()
    private let bellButton = UIButton(type: .system)

    private let revenueCard = UIView()
    private let revenueTitleLabel = UILabel()
    private let chevron = UIImageView()
    private let revenueAmountLabel = UILabel()
    private let revenueCaptionLabel = UILabel()
    private var revenueValueLabels: [UILabel] = []

    private let statsRow = UIStackView()
    private var statCards: [OverviewStatCard] = []

    private let todosTitleLabel = UILabel()
    private let allButton = UIControl()

    // MARK: - 生命周期

    init() {
        super.init(frame: .zero)
        backgroundColor = Theme.Color.bg
        setupTitleBar()
        setupRevenueCard()
        setupStatsRow()
        setupTodosBar()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }



    // MARK: - 布局

    private func setupTitleBar() {
        titleLabel.text = "经营概览"
        titleLabel.font = .appTitle(24)
        titleLabel.textColor = Theme.Color.ink
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide).offset(Theme.Spacing.s)
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
        addSubview(bellButton)
        bellButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(20)
            $0.centerY.equalTo(titleLabel)
            $0.width.height.equalTo(38)
        }
    }

    private func setupRevenueCard() {
        revenueCard.backgroundColor = Theme.Color.brandDark
        revenueCard.layer.cornerRadius = Theme.Radius.card
        revenueCard.layer.masksToBounds = true
        revenueCard.isUserInteractionEnabled = true
        revenueCard.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapCard)))
        addSubview(revenueCard)
        revenueCard.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.height.equalTo(156)
        }

        // 标题「营收概览」
        revenueTitleLabel.text = "营收概览"
        revenueTitleLabel.font = .appBody(13)
        revenueTitleLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        revenueCard.addSubview(revenueTitleLabel)
        revenueTitleLabel.snp.makeConstraints {
            $0.top.leading.equalToSuperview().offset(Theme.Spacing.cardInner)
        }

        // 右上角箭头（点击查看收益中心）
        chevron.image = UIImage(systemName: "chevron.right")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold))
        chevron.tintColor = UIColor.white.withAlphaComponent(0.5)
        chevron.contentMode = .scaleAspectFit
        revenueCard.addSubview(chevron)
        chevron.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.cardInner)
            $0.centerY.equalTo(revenueTitleLabel)
            $0.width.equalTo(8)
            $0.height.equalTo(12)
        }

        // 大数字
        revenueAmountLabel.font = .appHero(28)
        revenueAmountLabel.textColor = .white
        revenueAmountLabel.text = "¥0"
        revenueCard.addSubview(revenueAmountLabel)
        revenueAmountLabel.snp.makeConstraints {
            $0.top.equalTo(revenueTitleLabel.snp.bottom).offset(Theme.Spacing.xs)
            $0.leading.equalToSuperview().offset(Theme.Spacing.cardInner)
        }

        // 「本月营收」caption
        revenueCaptionLabel.text = "本月营收"
        revenueCaptionLabel.font = .appLabel(11)
        revenueCaptionLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        revenueCard.addSubview(revenueCaptionLabel)
        revenueCaptionLabel.snp.makeConstraints {
            $0.leading.equalTo(revenueAmountLabel.snp.trailing).offset(6)
            $0.bottom.equalTo(revenueAmountLabel).offset(-4)
        }

        // 底部两列：分销返利 / 结算中（与收益中心对齐，去掉可提现）
        let columnStack = UIStackView()
        columnStack.axis = .horizontal
        columnStack.distribution = .fillEqually
        revenueCard.addSubview(columnStack)
        columnStack.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.cardInner)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.l)
            $0.height.equalTo(38)
        }

        for title in ["分销返利", "结算中"] {
            let column = FinanceMiniColumn()
            column.configure(title: title, value: "¥0")
            revenueValueLabels.append(column.valueLabel)
            columnStack.addArrangedSubview(column)
        }
    }

    private func setupStatsRow() {
        statsRow.axis = .horizontal
        statsRow.spacing = 12
        statsRow.distribution = .fillEqually
        addSubview(statsRow)
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

    /// 「待办事项 + 全部 ›」区头：固定在头部区底部，不随列表滚动
    private func setupTodosBar() {
        todosTitleLabel.text = "待办事项"
        todosTitleLabel.font = .appSection(17)
        todosTitleLabel.textColor = Theme.Color.ink
        addSubview(todosTitleLabel)
        todosTitleLabel.snp.makeConstraints {
            $0.top.equalTo(statsRow.snp.bottom).offset(12)
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
        allButton.addSubview(allLabel)
        allButton.addSubview(allChevron)
        allLabel.snp.makeConstraints {
            $0.leading.centerY.equalToSuperview()
        }
        allChevron.snp.makeConstraints {
            $0.leading.equalTo(allLabel.snp.trailing).offset(3)
            $0.trailing.centerY.equalToSuperview()
            $0.width.height.equalTo(8)
        }
        allButton.addTarget(self, action: #selector(didTapAllTodos), for: .touchUpInside)
        addSubview(allButton)
        allButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(18)
            $0.centerY.equalTo(todosTitleLabel)
            $0.height.equalTo(28)
            $0.bottom.equalToSuperview().inset(8)
        }
    }

    // MARK: - 数据

    func apply(_ data: StudioOverviewData) {
        let revenue = data.revenue ?? .empty
        revenueAmountLabel.text = StudioAmount.text(revenue.monthIncome)
        let metrics = [revenue.distributionText, revenue.settlingText]
        for (index, text) in metrics.enumerated() where index < revenueValueLabels.count {
            revenueValueLabels[index].text = text
        }

        let stats = data.stats ?? .empty
        let values = [stats.active_students, stats.online_courses, stats.teachers]
        for (index, value) in values.enumerated() where index < statCards.count {
            statCards[index].setValue(value ?? 0)
        }
    }

    // MARK: - 交互

    @objc private func didTapBell() {
        onBell?()
    }

    @objc private func didTapCard() {
        onCardTap?()
    }

    @objc private func didTapAllTodos() {
        onAllTodos?()
    }
}

// MARK: - 统计小卡

/// 白色小卡：Hero 数字 + 标签
final class OverviewStatCard: UIView {

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
        valueLabel.textColor = Theme.Color.brand
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

// MARK: - 营收卡底部小列（与收益中心 MiniColumn 同构）

private final class FinanceMiniColumn: UIView {
    let valueLabel = UILabel()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        valueLabel.font = .appBody(15)
        valueLabel.textColor = .white
        valueLabel.textAlignment = .center
        addSubview(valueLabel)
        valueLabel.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.trailing.equalToSuperview()
        }

        titleLabel.font = .appBody(11)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        titleLabel.textAlignment = .center
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(valueLabel.snp.bottom).offset(2)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, value: String) {
        titleLabel.text = title
        valueLabel.text = value
    }
}
