import UIKit
import SnapKit

/// 工作室「我的」页沉浸式封面头（对齐 PR 原型 studioMy / 设计稿，结构对齐家长 MineHeaderView）
/// 深绿渐变封面（延伸到状态栏）+ 身份胶囊 + 圆角方形机构头像 + 机构名 / 认证 · 业务类型 · 入驻时长 + 白色经营统计卡
/// 说明：头部整体固定在页面顶部，不随下方菜单区滚动；统计卡置于封面内底部（与家长端毛玻璃统计卡同位）
final class StudioMineHeaderView: UIView {

    var onSettings: (() -> Void)?
    var onIdentityTapped: (() -> Void)?

    private let identityChip = UIControl()
    private let identityLabel = UILabel()
    private let identityChevron = UIImageView()
    private let settingsButton = UIButton(type: .system)
    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    private let nameLabel = UILabel()
    private let subtitleLabel = UILabel()

    private let statsCard = UIView()
    private let statTitles = ["在读学员", "在售课程", "入驻教师"]
    private var statValueLabels: [UILabel] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        // 深绿渐变（brand → brandDark），与家长/老师页统一
        let gradient = CAGradientLayer()
        gradient.colors = [
            Theme.Color.brand.cgColor,
            Theme.Color.brandDark.cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 0.8, y: 1)
        layer.insertSublayer(gradient, at: 0)
        backgroundColor = Theme.Color.brandDark

        // 装饰光晕（右上暖色大圆 + 左上柔和白圆）
        let warmOrb = UIView()
        warmOrb.backgroundColor = Theme.Color.wood.withAlphaComponent(0.16)
        warmOrb.layer.cornerRadius = 90
        addSubview(warmOrb)
        warmOrb.snp.makeConstraints {
            $0.top.equalToSuperview().offset(-30)
            $0.trailing.equalToSuperview().offset(46)
            $0.width.height.equalTo(180)
        }

        let softOrb = UIView()
        softOrb.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        softOrb.layer.cornerRadius = 36
        addSubview(softOrb)
        softOrb.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide).offset(30)
            $0.leading.equalToSuperview().offset(-22)
            $0.width.height.equalTo(72)
        }

        // 身份胶囊
        identityChip.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        identityChip.layer.cornerRadius = 15
        identityChip.addTarget(self, action: #selector(didTapIdentity), for: .touchUpInside)
        addSubview(identityChip)

        let chipStack = UIStackView(arrangedSubviews: [identityLabel, identityChevron])
        chipStack.axis = .horizontal
        chipStack.spacing = 5
        chipStack.alignment = .center
        chipStack.isUserInteractionEnabled = false
        identityChip.addSubview(chipStack)
        chipStack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 12))
        }

        identityLabel.font = .appSection(13)
        identityLabel.textColor = .white
        identityLabel.text = "当前身份：工作室"
        identityLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        identityChevron.image = UIImage(systemName: "chevron.down")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 9, weight: .semibold))
        identityChevron.tintColor = UIColor.white.withAlphaComponent(0.85)
        identityChevron.contentMode = .scaleAspectFit
        identityChevron.setContentHuggingPriority(.required, for: .horizontal)
        identityChevron.snp.makeConstraints { $0.width.equalTo(10) }

        identityChip.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide).offset(Theme.Spacing.s)
            $0.leading.equalToSuperview().offset(18)
            $0.height.equalTo(30)
        }

        // 设置（圆角方形半透明按钮）
        settingsButton.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        settingsButton.layer.cornerRadius = 12
        settingsButton.setImage(
            UIImage(systemName: "gearshape")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)),
            for: .normal
        )
        settingsButton.tintColor = UIColor.white.withAlphaComponent(0.95)
        settingsButton.addTarget(self, action: #selector(didTapSettings), for: .touchUpInside)
        addSubview(settingsButton)
        settingsButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(18)
            $0.centerY.equalTo(identityChip)
            $0.width.height.equalTo(36)
        }

        // 机构头像（圆角方形 + 细白边）
        avatarView.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        avatarView.layer.cornerRadius = 20
        avatarView.layer.borderWidth = 2.5
        avatarView.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        avatarView.snp.makeConstraints {
            $0.width.height.equalTo(62)
        }

        avatarLabel.font = .appTitle(24)
        avatarLabel.textColor = .white
        avatarLabel.textAlignment = .center
        avatarView.addSubview(avatarLabel)
        avatarLabel.snp.makeConstraints { $0.edges.equalToSuperview() }

        // 机构名（衬线感粗体大字）
        nameLabel.font = .appTitle(22)
        nameLabel.textColor = .white
        nameLabel.text = "—"
        nameLabel.numberOfLines = 1

        // 副标题：已认证机构 · 业务类型 · 入驻时长
        subtitleLabel.font = .appLabel(12)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        subtitleLabel.numberOfLines = 2

        // 机构信息块（头像 + 名称/副标题，垂直居中对齐）
        let infoStack = UIStackView(arrangedSubviews: [nameLabel, subtitleLabel])
        infoStack.axis = .vertical
        infoStack.spacing = 5
        infoStack.alignment = .leading

        let userRow = UIStackView(arrangedSubviews: [avatarView, infoStack])
        userRow.axis = .horizontal
        userRow.spacing = 14
        userRow.alignment = .center
        addSubview(userRow)
        userRow.snp.makeConstraints {
            $0.top.equalTo(identityChip.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.equalToSuperview().offset(18)
            $0.trailing.equalToSuperview().inset(18)
        }

        setupStatsCard(after: userRow)
    }

    // MARK: - 白色经营统计卡（封面内底部，随头部一起固定）

    private func setupStatsCard(after topView: UIView) {
        statsCard.backgroundColor = Theme.Color.surface
        statsCard.layer.cornerRadius = 18
        statsCard.layer.shadowColor = UIColor(hex: 0x2B2621).cgColor
        statsCard.layer.shadowOpacity = 0.05
        statsCard.layer.shadowRadius = 14
        statsCard.layer.shadowOffset = CGSize(width: 0, height: 6)
        addSubview(statsCard)
        statsCard.snp.makeConstraints {
            $0.top.equalTo(topView.snp.bottom).offset(22)
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.height.equalTo(76)
            // 封面高度由统计卡底部决定（下方留一截绿色）
            $0.bottom.equalToSuperview().inset(14)
        }

        var previous: UIView?
        for (index, title) in statTitles.enumerated() {
            let item = makeStatItem(title: title)
            statsCard.addSubview(item)
            item.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
                if let previous {
                    make.leading.equalTo(previous.snp.trailing)
                    make.width.equalTo(previous)
                } else {
                    make.leading.equalToSuperview()
                }
                if index == statTitles.count - 1 {
                    make.trailing.equalToSuperview()
                }
            }
            if let previous {
                let divider = UIView()
                divider.backgroundColor = Theme.Color.line
                statsCard.addSubview(divider)
                divider.snp.makeConstraints {
                    $0.leading.equalTo(previous.snp.trailing)
                    $0.centerY.equalToSuperview()
                    $0.width.equalTo(0.5)
                    $0.height.equalTo(40)
                }
            }
            previous = item
        }
    }

    private func makeStatItem(title: String) -> UIView {
        let item = UIView()

        let value = UILabel()
        value.font = .appHero(22)
        value.textColor = Theme.Color.brandDark
        value.textAlignment = .center
        value.text = "0"
        item.addSubview(value)
        value.snp.makeConstraints {
            $0.top.equalToSuperview().offset(15)
            $0.centerX.equalToSuperview()
            $0.height.equalTo(26)
        }
        statValueLabels.append(value)

        let label = UILabel()
        label.font = .appLabel(11)
        label.textColor = Theme.Color.muted
        label.textAlignment = .center
        label.text = title
        item.addSubview(label)
        label.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(11)
            $0.centerX.equalToSuperview()
            $0.height.equalTo(15)
        }

        return item
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.sublayers?.first?.frame = bounds
    }

    // MARK: - 刷新

    func refresh(profile: StudioMineProfile?, stats: StudioMineStats = .empty) {
        let name = profile?.displayName ?? "未命名工作室"
        nameLabel.text = name
        avatarLabel.text = String(name.prefix(1))
        subtitleLabel.text = profile?.subtitle ?? "已认证机构 · 资料完善中"
        identityLabel.text = "当前身份：工作室"

        let values = [
            "\(stats.activeStudents)",
            "\(stats.onlineCourses)",
            "\(stats.teacherCount)"
        ]
        for (index, value) in values.enumerated() where index < statValueLabels.count {
            statValueLabels[index].text = value
        }
    }

    // MARK: - 点击

    @objc private func didTapSettings() {
        onSettings?()
    }

    @objc private func didTapIdentity() {
        onIdentityTapped?()
    }
}
