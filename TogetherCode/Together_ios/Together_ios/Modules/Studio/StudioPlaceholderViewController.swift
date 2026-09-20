import UIKit
import SnapKit

/// 工作室端通用建设中占位页（阶段 1 骨架，阶段 2/3/4 逐个替换为真实页面）
final class StudioPlaceholderViewController: BaseViewController {

    private let icon: String
    private let tip: String

    init(title: String, icon: String, tip: String) {
        self.icon = icon
        self.tip = tip
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg

        let card = UIView()
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = 16
        view.addSubview(card)
        card.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.xl)
        }

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = Theme.Color.brand
        iconView.contentMode = .scaleAspectFit
        card.addSubview(iconView)
        iconView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.xxl)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(46)
        }

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .appSection(17)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.textAlignment = .center
        card.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(iconView.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        let tipLabel = UILabel()
        tipLabel.text = tip
        tipLabel.font = .appLabel(13)
        tipLabel.textColor = Theme.Color.sub
        tipLabel.textAlignment = .center
        tipLabel.numberOfLines = 0
        card.addSubview(tipLabel)
        tipLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.xxl)
        }
    }
}
