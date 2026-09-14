import UIKit
import SnapKit

/// 通用空态视图：加载中 / 无数据 / 加载失败（可重试）
/// 全 App 列表页复用；父视图需在布局中预留足够高度
final class EmptyStateView: UIView {

    enum Style {
        case loading
        case empty(String)
        case error(String, retry: (() -> Void)?)
    }

    private let iconView = UIImageView()
    private let messageLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private var retryAction: (() -> Void)?
    private var spinner: UIActivityIndicatorView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = Theme.Color.muted
        addSubview(iconView)
        iconView.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-24)
            $0.width.height.equalTo(56)
        }

        messageLabel.font = .appBody(14)
        messageLabel.textColor = Theme.Color.muted
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        addSubview(messageLabel)
        messageLabel.snp.makeConstraints {
            $0.top.equalTo(iconView.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.xl)
        }

        retryButton.setTitle("重新加载", for: .normal)
        retryButton.titleLabel?.font = .appSection(14)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.backgroundColor = Theme.Color.brand
        retryButton.layer.cornerRadius = Theme.Radius.button
        retryButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 24, bottom: 8, right: 24)
        retryButton.isHidden = true
        retryButton.addTarget(self, action: #selector(didTapRetry), for: .touchUpInside)
        addSubview(retryButton)
        retryButton.snp.makeConstraints {
            $0.top.equalTo(messageLabel.snp.bottom).offset(Theme.Spacing.l)
            $0.centerX.equalToSuperview()
        }
    }

    func show(style: Style) {
        spinner?.stopAnimating()
        spinner?.removeFromSuperview()
        spinner = nil
        iconView.isHidden = false
        retryButton.isHidden = true

        switch style {
        case .loading:
            iconView.isHidden = true
            messageLabel.text = "加载中..."
            let spin = UIActivityIndicatorView(style: .medium)
            spin.color = Theme.Color.brand
            spin.startAnimating()
            addSubview(spin)
            spin.snp.makeConstraints {
                $0.center.equalToSuperview()
            }
            spinner = spin
        case .empty(let text):
            iconView.image = UIImage(systemName: "tray")
            messageLabel.text = text
        case .error(let text, let retry):
            iconView.image = UIImage(systemName: "wifi.exclamationmark")
            messageLabel.text = text
            retryAction = retry
            if retry != nil {
                retryButton.isHidden = false
            }
        }
    }

    @objc private func didTapRetry() {
        retryAction?()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
