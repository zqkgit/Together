import UIKit
import SnapKit

/// 主题确认弹框（替代系统 UIAlertController，风格对齐 App：米白卡片 + 品牌绿胶囊确认按钮）
final class ThemeAlertView: UIView {

    private var onConfirm: (() -> Void)?
    private var onCancel: (() -> Void)?

    private let backdropView = UIView()
    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let confirmButton = UIButton(type: .system)

    /// 显示主题弹框（自动挂到 keyWindow 并淡入）
    @discardableResult
    static func show(
        title: String,
        message: String? = nil,
        confirmTitle: String = "确定",
        cancelTitle: String = "取消",
        onConfirm: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) -> ThemeAlertView {
        let alert = ThemeAlertView()
        alert.configure(
            title: title,
            message: message,
            confirmTitle: confirmTitle,
            cancelTitle: cancelTitle,
            onConfirm: onConfirm,
            onCancel: onCancel
        )
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first else { return alert }
        window.addSubview(alert)
        alert.frame = window.bounds
        alert.alpha = 0
        UIView.animate(withDuration: 0.18) { alert.alpha = 1 }
        return alert
    }

    private override init(frame: CGRect) {
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configure(
        title: String,
        message: String?,
        confirmTitle: String,
        cancelTitle: String,
        onConfirm: (() -> Void)?,
        onCancel: (() -> Void)?
    ) {
        self.onConfirm = onConfirm
        self.onCancel = onCancel

        backdropView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        addSubview(backdropView)
        backdropView.snp.makeConstraints { $0.edges.equalToSuperview() }
        let backdropTap = UITapGestureRecognizer(target: self, action: #selector(handleBackdropTap))
        backdropView.addGestureRecognizer(backdropTap)

        cardView.backgroundColor = Theme.Color.surface
        cardView.layer.cornerRadius = 16
        addSubview(cardView)
        cardView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.xl)
        }

        titleLabel.text = title
        titleLabel.font = .appSection(17)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        cardView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.xl)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        var lastAnchor: ConstraintItem = titleLabel.snp.bottom
        if let message, !message.isEmpty {
            messageLabel.text = message
            messageLabel.font = .appLabel(14)
            messageLabel.textColor = Theme.Color.sub
            messageLabel.textAlignment = .center
            messageLabel.numberOfLines = 0
            cardView.addSubview(messageLabel)
            messageLabel.snp.makeConstraints {
                $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.s)
                $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            }
            lastAnchor = messageLabel.snp.bottom
        }

        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.spacing = Theme.Spacing.m
        buttonStack.distribution = .fillEqually
        cardView.addSubview(buttonStack)
        buttonStack.snp.makeConstraints {
            $0.top.equalTo(lastAnchor).offset(Theme.Spacing.xl)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(44)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }

        cancelButton.setTitle(cancelTitle, for: .normal)
        cancelButton.titleLabel?.font = .appBody(15)
        cancelButton.setTitleColor(Theme.Color.ink, for: .normal)
        cancelButton.backgroundColor = Theme.Color.surfaceAlt
        cancelButton.layer.cornerRadius = 22
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)

        confirmButton.setTitle(confirmTitle, for: .normal)
        confirmButton.titleLabel?.font = .appBody(15)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.backgroundColor = Theme.Color.brand
        confirmButton.layer.cornerRadius = 22
        confirmButton.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)

        buttonStack.addArrangedSubview(cancelButton)
        buttonStack.addArrangedSubview(confirmButton)
    }

    @objc private func handleBackdropTap() {
        dismiss(cancelled: true)
    }

    @objc private func handleCancel() {
        dismiss(cancelled: true)
    }

    @objc private func handleConfirm() {
        dismiss(cancelled: false)
    }

    private func dismiss(cancelled: Bool) {
        if cancelled {
            onCancel?()
        } else {
            onConfirm?()
        }
        onCancel = nil
        onConfirm = nil
        UIView.animate(withDuration: 0.15, animations: {
            self.alpha = 0
        }) { _ in
            self.removeFromSuperview()
        }
    }
}
