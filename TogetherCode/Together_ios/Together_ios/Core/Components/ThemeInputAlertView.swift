import UIKit
import SnapKit

/// 主题输入弹框（替代系统 UIAlertController 输入场景，风格对齐 ThemeAlertView：
/// 米白卡片 + 输入框 + 品牌绿确认按钮）。用于请假事由、反馈等短文本输入。
final class ThemeInputAlertView: UIView {

    private var onConfirm: ((String) -> Void)?
    private var onCancel: (() -> Void)?

    private let backdropView = UIView()
    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let textField = UITextField()
    private let countLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let confirmButton = UIButton(type: .system)
    private let maxCount: Int

    /// 显示主题输入弹框（自动挂到 keyWindow 并淡入）
    /// - Parameters:
    ///   - title: 标题
    ///   - placeholder: 输入框占位
    ///   - maxCount: 最大字数（默认 200）
    ///   - initialText: 回显文本（编辑场景）
    @discardableResult
    static func show(
        title: String,
        placeholder: String,
        maxCount: Int = 200,
        initialText: String? = nil,
        confirmTitle: String = "提交",
        onConfirm: ((String) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) -> ThemeInputAlertView {
        let alert = ThemeInputAlertView(
            title: title,
            placeholder: placeholder,
            maxCount: maxCount,
            initialText: initialText,
            confirmTitle: confirmTitle,
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

    private init(
        title: String,
        placeholder: String,
        maxCount: Int,
        initialText: String?,
        confirmTitle: String,
        onConfirm: ((String) -> Void)?,
        onCancel: (() -> Void)?
    ) {
        self.maxCount = maxCount
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        super.init(frame: .zero)

        backdropView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        addSubview(backdropView)
        backdropView.snp.makeConstraints { $0.edges.equalToSuperview() }

        cardView.backgroundColor = Theme.Color.surface
        cardView.layer.cornerRadius = Theme.Radius.card
        addSubview(cardView)
        cardView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        titleLabel.text = title
        titleLabel.font = .appSection(17)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.textAlignment = .center
        cardView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        textField.placeholder = placeholder
        textField.font = .appBody(14)
        textField.textColor = Theme.Color.ink
        textField.backgroundColor = Theme.Color.bg
        textField.layer.cornerRadius = Theme.Radius.input
        textField.textAlignment = .center
        textField.returnKeyType = .done
        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        cardView.addSubview(textField)
        textField.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalTo(titleLabel)
            $0.height.equalTo(44)
        }

        countLabel.font = .appLabel(11)
        countLabel.textColor = Theme.Color.muted
        countLabel.textAlignment = .right
        countLabel.text = "0/\(maxCount)"
        cardView.addSubview(countLabel)
        countLabel.snp.makeConstraints {
            $0.top.equalTo(textField.snp.bottom).offset(4)
            $0.trailing.equalTo(titleLabel)
        }

        cancelButton.setTitle("取消", for: .normal)
        cancelButton.titleLabel?.font = .appBody(14)
        cancelButton.setTitleColor(Theme.Color.sub, for: .normal)
        cancelButton.layer.borderWidth = 1
        cancelButton.layer.borderColor = Theme.Color.line.cgColor
        cancelButton.layer.cornerRadius = Theme.Radius.button
        cancelButton.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)

        confirmButton.setTitle(confirmTitle, for: .normal)
        confirmButton.titleLabel?.font = .appBody(14)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.backgroundColor = Theme.Color.brand
        confirmButton.layer.cornerRadius = Theme.Radius.button
        confirmButton.addTarget(self, action: #selector(didTapConfirm), for: .touchUpInside)

        cardView.addSubview(cancelButton)
        cardView.addSubview(confirmButton)
        cancelButton.snp.makeConstraints {
            $0.top.equalTo(countLabel.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.equalTo(titleLabel)
            $0.height.equalTo(44)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
        confirmButton.snp.makeConstraints {
            $0.top.equalTo(cancelButton)
            $0.leading.equalTo(cancelButton.snp.trailing).offset(Theme.Spacing.m)
            $0.trailing.equalTo(titleLabel)
            $0.height.equalTo(cancelButton)
            $0.width.equalTo(cancelButton)
        }

        if let initialText {
            textField.text = initialText
            textChanged()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.textField.becomeFirstResponder()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func textChanged() {
        let text = textField.text ?? ""
        let trimmed = String(text.prefix(maxCount))
        if trimmed != text {
            textField.text = trimmed
        }
        countLabel.text = "\(trimmed.count)/\(maxCount)"
    }

    @objc private func didTapCancel() {
        dismiss()
        onCancel?()
    }

    @objc private func didTapConfirm() {
        let text = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            textField.layer.borderWidth = 1
            textField.layer.borderColor = Theme.Color.clay.cgColor
            return
        }
        dismiss()
        onConfirm?(text)
    }

    private func dismiss() {
        textField.resignFirstResponder()
        UIView.animate(withDuration: 0.15, animations: { self.alpha = 0 }) { _ in
            self.removeFromSuperview()
        }
    }
}
