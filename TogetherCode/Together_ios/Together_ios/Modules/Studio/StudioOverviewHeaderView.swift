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
    var onWithdraw: (() -> Void)?
    var onAllTodos: (() -> Void)?

    // MARK: - 视图

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

    override func layoutSubviews() {
        super.layoutSubviews()
        // 渐变层跟随营收卡实际尺寸
        revenueGradient?.frame = revenueCard.bounds
    }

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
        revenueCard.layer.cornerRadius = 18
        revenueCard.layer.masksToBounds = true
        revenueCard.backgroundColor = Theme.Color.brandDark
        addSubview(revenueCard)
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

    // MARK: - 交互

    @objc private func didTapBell() {
        onBell?()
    }

    @objc private func didTapWithdraw() {
        onWithdraw?()
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
