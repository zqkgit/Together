import UIKit
import SnapKit

/// 「我的」页通用菜单项
struct MineMenuItem {
    let icon: String
    let title: String
}

/// 「我的」页通用菜单卡（家长 / 老师 / 工作室三端共用，样式以工作室端为准）
/// 白色圆角卡 + 暖阴影，内部按分组排列菜单行，组间留 18pt 间隔
final class MineMenuCardView: UIView {

    /// 菜单点击回调
    var onSelect: ((MineMenuItem) -> Void)?

    private let stack = UIStackView()

    /// - Parameter groups: 分组菜单；多组之间自动插入 18pt 间隔
    init(groups: [[MineMenuItem]]) {
        super.init(frame: .zero)
        backgroundColor = Theme.Color.surface
        layer.cornerRadius = 18
        layer.shadowColor = UIColor(hex: 0x2B2621).cgColor
        layer.shadowOpacity = 0.05
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 6)

        stack.axis = .vertical
        stack.spacing = 0
        addSubview(stack)
        stack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0))
        }

        for (index, group) in groups.enumerated() {
            if index > 0 {
                let divider = UIView()
                divider.backgroundColor = Theme.Color.surfaceAlt
                stack.addArrangedSubview(divider)
                divider.snp.makeConstraints {
                    $0.height.equalTo(0.5)
                    $0.leading.trailing.equalToSuperview().inset(18)
                }
                let spacer = UIView()
                spacer.snp.makeConstraints { $0.height.equalTo(6) }
                stack.addArrangedSubview(spacer)
            }
            for item in group {
                stack.addArrangedSubview(makeRow(item))
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func makeRow(_ item: MineMenuItem) -> MineMenuRow {
        let row = MineMenuRow(icon: item.icon, title: item.title)
        row.onTap = { [weak self] in self?.onSelect?(item) }
        return row
    }
}

/// 「我的」页通用菜单行：浅绿圆角图标块 + 标题 + 右侧箭头（家长 / 老师 / 工作室共用）
final class MineMenuRow: UIControl {

    var onTap: (() -> Void)?

    private let iconTile = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let chevron = UIImageView()

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? Theme.Color.surfaceAlt : .clear }
    }

    init(icon: String, title: String) {
        super.init(frame: .zero)
        setup(icon: icon, title: title)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup(icon: String, title: String) {
        backgroundColor = .clear
        addTarget(self, action: #selector(didTap), for: .touchUpInside)

        snp.makeConstraints { $0.height.equalTo(60) }

        iconTile.backgroundColor = Theme.Color.brandSoft
        iconTile.layer.cornerRadius = 10
        iconTile.isUserInteractionEnabled = false
        addSubview(iconTile)
        iconTile.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(18)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(34)
        }

        iconView.image = UIImage(systemName: icon)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 17, weight: .regular))
        iconView.tintColor = Theme.Color.brand
        iconView.contentMode = .scaleAspectFit
        iconTile.addSubview(iconView)
        iconView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.width.height.equalTo(20)
        }

        // 先入层 chevron：titleLabel 的 trailing 会引用它的 leading，
        // 否则约束激活时二者无共同祖先 → NSGenericException 崩溃
        chevron.image = UIImage(systemName: "chevron.right")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold))
        chevron.tintColor = Theme.Color.muted
        chevron.contentMode = .scaleAspectFit
        chevron.isUserInteractionEnabled = false
        addSubview(chevron)
        chevron.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(16)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(8)
            $0.height.equalTo(14)
        }

        titleLabel.text = title
        titleLabel.font = .appSection(15)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(iconTile.snp.trailing).offset(12)
            $0.centerY.equalToSuperview()
            $0.trailing.lessThanOrEqualTo(chevron.snp.leading).offset(-8)
        }
    }

    @objc private func didTap() {
        onTap?()
    }
}
