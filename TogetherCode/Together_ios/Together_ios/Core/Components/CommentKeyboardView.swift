import UIKit
import SnapKit

/// 评论键盘 accessory：键盘顶部的输入条
/// 包含：键盘收起按钮 + 输入框（回复态显示"回复 @xxx"）+ 发送按钮
/// 用法：作为某个 UITextField 的 inputAccessoryView，该输入框 becomeFirstResponder 时显示
final class CommentKeyboardView: UIView, UITextFieldDelegate {

    var onSend: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    private let inputField = UITextField()
    private let sendButton = UIButton(type: .system)
    private let dismissButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 54))
        autoresizingMask = [.flexibleWidth]
        backgroundColor = Theme.Color.surface
        layer.borderWidth = 1
        layer.borderColor = Theme.Color.line.cgColor

        // 键盘收起按钮
        dismissButton.setImage(UIImage(systemName: "keyboard.chevron.compact.down"), for: .normal)
        dismissButton.tintColor = Theme.Color.sub
        dismissButton.addTarget(self, action: #selector(didTapDismiss), for: .touchUpInside)
        addSubview(dismissButton)
        dismissButton.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(36)
            $0.height.equalTo(38)
        }

        // 发送按钮
        sendButton.setTitle("发送", for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.titleLabel?.font = .appLabel(14)
        sendButton.backgroundColor = Theme.Color.brand
        sendButton.layer.cornerRadius = Theme.Radius.button
        sendButton.addTarget(self, action: #selector(didTapSend), for: .touchUpInside)
        addSubview(sendButton)
        sendButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(64)
            $0.height.equalTo(38)
        }

        // 输入框
        inputField.font = .appBody(14)
        inputField.textColor = Theme.Color.ink
        inputField.backgroundColor = Theme.Color.surfaceAlt
        inputField.layer.cornerRadius = Theme.Radius.button
        inputField.returnKeyType = .send
        inputField.delegate = self
        inputField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        inputField.leftViewMode = .always
        addSubview(inputField)
        inputField.snp.makeConstraints {
            $0.leading.equalTo(dismissButton.snp.trailing).offset(8)
            $0.trailing.equalTo(sendButton.snp.leading).offset(-8)
            $0.centerY.equalToSuperview()
            $0.height.equalTo(38)
        }
    }

    /// 设置回复目标（nil = 普通评论）
    func setReplyTarget(name: String?) {
        if let name, !name.isEmpty {
            inputField.placeholder = "回复 @\(name)"
        } else {
            inputField.placeholder = "说点什么..."
        }
    }

    func clear() {
        inputField.text = ""
    }

    // MARK: - actions

    @objc private func didTapDismiss() { onDismiss?() }
    @objc private func didTapSend() { onSend?(inputField.text ?? "") }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        didTapSend()
        return true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
