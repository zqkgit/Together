import UIKit
import SnapKit

/// 「我的」页沉浸式头部（重新设计，仅以 PR 图作参考）
/// 深绿渐变延伸至状态栏；身份胶囊 + 设置；大头像 + 昵称 + 城市徽章；毛玻璃统计卡
final class MineHeaderView: UIView {

    var onSettings: (() -> Void)?
    var onIdentityTapped: (() -> Void)?
    var onStatTapped: ((Int) -> Void)?

    private let identityChip = UIControl()
    private let identityLabel = UILabel()
    private let identityChevron = UIImageView()
    private let settingsButton = UIButton(type: .system)
    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    private let nicknameLabel = UILabel()
    private let cityChip = UIStackView()
    private let statCard = UIView()
    private var statValues: [UILabel] = []

    private let statTitles = ["我的孩子", "在学课程", "收藏作品"]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        // 深绿渐变背景（延伸到状态栏）
        let gradient = CAGradientLayer()
        gradient.colors = [
            Theme.Color.brand.cgColor,
            Theme.Color.brandDark.cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 0.8, y: 1)
        layer.insertSublayer(gradient, at: 0)
        backgroundColor = Theme.Color.brandDark

        // 装饰光晕：右上暖色大圆 + 左上柔和白圆（艺术感）
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

        // 身份胶囊 + 设置
        identityChip.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        identityChip.layer.cornerRadius = 15
        identityChip.addTarget(self, action: #selector(didTapIdentity), for: .touchUpInside)
        addSubview(identityChip)

        let chipStack = UIStackView(arrangedSubviews: [identityLabel, identityChevron])
        chipStack.axis = .horizontal
        chipStack.spacing = 4
        chipStack.alignment = .center
        chipStack.isUserInteractionEnabled = false
        identityChip.addSubview(chipStack)
        chipStack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 5, left: 12, bottom: 5, right: 10))
        }

        identityLabel.font = .appLabel(12)
        identityLabel.textColor = .white
        identityLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        identityChevron.image = UIImage(systemName: "chevron.down")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 9, weight: .semibold))
        identityChevron.tintColor = .white.withAlphaComponent(0.85)
        identityChevron.contentMode = .scaleAspectFit
        identityChevron.setContentHuggingPriority(.required, for: .horizontal)
        identityChevron.snp.makeConstraints { $0.width.equalTo(10) }
        identityChip.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide).offset(Theme.Spacing.s)
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
            $0.height.equalTo(30)
        }

        settingsButton.setImage(UIImage(systemName: "gearshape"), for: .normal)
        settingsButton.tintColor = UIColor.white.withAlphaComponent(0.9)
        settingsButton.addTarget(self, action: #selector(didTapSettings), for: .touchUpInside)
        addSubview(settingsButton)
        settingsButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalTo(identityChip)
            $0.width.height.equalTo(30)
        }

        // 用户行：大头像 + 昵称 + 城市徽章
        avatarView.backgroundColor = .white
        avatarView.layer.cornerRadius = 32
        avatarView.layer.borderWidth = 2
        avatarView.layer.borderColor = UIColor.white.withAlphaComponent(0.55).cgColor
        avatarView.layer.shadowColor = UIColor.black.cgColor
        avatarView.layer.shadowOpacity = 0.18
        avatarView.layer.shadowRadius = 8
        avatarView.layer.shadowOffset = CGSize(width: 0, height: 4)
        addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.top.equalTo(identityChip.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
            $0.width.height.equalTo(64)
        }

        avatarLabel.font = .appTitle(24)
        avatarLabel.textColor = Theme.Color.brand
        avatarLabel.textAlignment = .center
        avatarView.addSubview(avatarLabel)
        avatarLabel.snp.makeConstraints { $0.edges.equalToSuperview() }

        nicknameLabel.font = .appSection(22)
        nicknameLabel.textColor = .white
        nicknameLabel.text = "—"
        addSubview(nicknameLabel)
        nicknameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarView.snp.trailing).offset(Theme.Spacing.m)
            $0.trailing.lessThanOrEqualToSuperview().inset(Theme.Spacing.l)
            $0.top.equalTo(avatarView).offset(6)
        }

        cityChip.axis = .horizontal
        cityChip.spacing = 4
        cityChip.alignment = .center
        cityChip.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        cityChip.layer.cornerRadius = 11
        cityChip.isLayoutMarginsRelativeArrangement = true
        cityChip.layoutMargins = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
        addSubview(cityChip)
        cityChip.snp.makeConstraints {
            $0.leading.equalTo(nicknameLabel)
            $0.top.equalTo(nicknameLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.height.equalTo(22)
        }

        let pin = UIImageView(image: UIImage(systemName: "mappin.and.ellipse"))
        pin.tintColor = UIColor.white.withAlphaComponent(0.85)
        pin.contentMode = .scaleAspectFit
        pin.snp.makeConstraints { $0.width.height.equalTo(12) }
        cityChip.addArrangedSubview(pin)

        let cityLabel = UILabel()
        cityLabel.font = .appLabel(11)
        cityLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        cityLabel.text = "未设置"
        cityLabel.tag = 100
        cityChip.addArrangedSubview(cityLabel)

        // 毛玻璃统计卡
        statCard.backgroundColor = UIColor.white.withAlphaComponent(0.13)
        statCard.layer.cornerRadius = Theme.Radius.card
        statCard.layer.borderWidth = 1
        statCard.layer.borderColor = UIColor.white.withAlphaComponent(0.14).cgColor
        addSubview(statCard)
        statCard.snp.makeConstraints {
            $0.top.equalTo(avatarView.snp.bottom).offset(Theme.Spacing.xl)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(76)
        }

        var previous: UIView?
        for (index, title) in statTitles.enumerated() {
            let item = makeStatItem(index: index, title: title)
            statCard.addSubview(item)
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
            // 细分隔线（首项之后）
            if let previous {
                let divider = UIView()
                divider.backgroundColor = UIColor.white.withAlphaComponent(0.16)
                statCard.addSubview(divider)
                divider.snp.makeConstraints {
                    $0.leading.equalTo(previous.snp.trailing)
                    $0.centerY.equalToSuperview()
                    $0.width.equalTo(0.5)
                    $0.height.equalTo(32)
                }
            }
            previous = item
        }
    }

    private func makeStatItem(index: Int, title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.tag = index
        button.addTarget(self, action: #selector(didTapStat(_:)), for: .touchUpInside)

        let value = UILabel()
        value.tag = 200
        value.font = .appHero(22)
        value.textColor = .white
        value.textAlignment = .center
        value.text = "0"
        button.addSubview(value)
        value.snp.makeConstraints {
            $0.top.equalToSuperview().offset(14)
            $0.centerX.equalToSuperview()
            $0.height.equalTo(26)
        }

        let label = UILabel()
        label.font = .appLabel(11)
        label.textColor = UIColor.white.withAlphaComponent(0.75)
        label.textAlignment = .center
        label.text = title
        button.addSubview(label)
        label.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(10)
            $0.centerX.equalToSuperview()
            $0.height.equalTo(16)
        }

        return button
    }

    // MARK: - 刷新

    func refresh(profile: MineProfile?, stats: MineStats) {
        let nickname = profile?.user?.nickname ?? TokenManager.shared.nickname
        let finalName = nickname.isEmpty ? "未设置昵称" : nickname
        nicknameLabel.text = finalName

        if let city = profile?.user?.city, !city.isEmpty,
           let label = cityChip.viewWithTag(100) as? UILabel {
            label.text = city
        }

        if let avatar = profile?.user?.avatar, !avatar.isEmpty {
            avatarLabel.text = ""
        } else {
            avatarLabel.text = String(finalName.prefix(1))
        }

        let roleText: String
        switch profile?.current_role ?? TokenManager.shared.userRole {
        case 2: roleText = "当前身份：老师"
        case 3: roleText = "当前身份：工作室"
        default: roleText = "当前身份：家长"
        }
        identityLabel.text = roleText

        let values = ["\(stats.childrenCount)", "\(stats.courseCount)", "\(stats.favoriteCount)"]
        for (index, value) in values.enumerated() {
            if index < statCard.subviews.count,
               let button = statCard.subviews[index] as? UIButton,
               let label = button.viewWithTag(200) as? UILabel {
                label.text = value
            }
        }
    }

    // MARK: - 点击

    @objc private func didTapSettings() {
        onSettings?()
    }

    @objc private func didTapIdentity() {
        onIdentityTapped?()
    }

    @objc private func didTapStat(_ sender: UIButton) {
        onStatTapped?(sender.tag)
    }
}
