import UIKit
import SnapKit

/// 通用菜单 Cell：SF Symbol 图标 + 标题 + 右侧箭头
/// 家长「我的」/ 老师「我的」等菜单列表共用
final class MenuCell: UITableViewCell {

    static let reuseID = "MenuCell"

    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.surface
        selectionStyle = .none

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = Theme.Color.wood
        contentView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(20)
        }

        titleLabel.font = .appBody(15)
        titleLabel.textColor = Theme.Color.ink
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(iconImageView.snp.trailing).offset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
            $0.trailing.lessThanOrEqualToSuperview().inset(Theme.Spacing.xl)
        }

        accessoryType = .disclosureIndicator
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(icon: String, title: String) {
        iconImageView.image = UIImage(systemName: icon)
        titleLabel.text = title
    }
}
