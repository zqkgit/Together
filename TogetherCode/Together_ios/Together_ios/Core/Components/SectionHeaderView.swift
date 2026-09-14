import UIKit
import SnapKit

/// 区块标题行：「标题（衬线粗体）+ 更多 ›」
final class SectionHeaderView: UIView {

    private let titleLabel = UILabel()
    private let moreButton = UIButton(type: .system)

    var onMore: (() -> Void)?

    init(title: String, more: String? = "更多") {
        super.init(frame: .zero)
        titleLabel.text = title
        titleLabel.font = .appSection(17)
        titleLabel.textColor = Theme.Color.ink
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { $0.leading.centerY.equalToSuperview() }

        if let more {
            moreButton.setTitle("\(more) ›", for: .normal)
            moreButton.setTitleColor(Theme.Color.sub, for: .normal)
            moreButton.titleLabel?.font = .appLabel(12)
            moreButton.addTarget(self, action: #selector(didTapMore), for: .touchUpInside)
            addSubview(moreButton)
            moreButton.snp.makeConstraints { $0.trailing.centerY.equalToSuperview() }
        }
        snp.makeConstraints { $0.height.equalTo(32) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func set(title: String, more: String?) {
        titleLabel.text = title
        moreButton.isHidden = more == nil
        if let more {
            moreButton.setTitle("\(more) ›", for: .normal)
        }
    }

    @objc private func didTapMore() {
        onMore?()
    }
}
