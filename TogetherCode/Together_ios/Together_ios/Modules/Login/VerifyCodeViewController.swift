import UIKit
import SnapKit

/// 验证码输入页：4 格自动跳转 + 倒计时 + 下一步（注册流程，返回箭头在左侧）
final class VerifyCodeViewController: BaseViewController {

    private let phone: String
    private let purpose: Purpose

    enum Purpose {
        /// 注册（新用户，验证码注册即登录）
        case register
        /// 其他预留（登录等）
        case login
    }

    private var codeFields: [UITextField] = []
    private let tipLabel = UILabel()
    private let countdownLabel = UILabel()
    private let resendButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)

    private var countdown = 60
    private var timer: Timer?

    init(phone: String = "", purpose: Purpose = .register) {
        self.phone = phone
        self.purpose = purpose
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "输入验证码"
        view.backgroundColor = Theme.Color.bg
        setupUI()
        startCountdown()
        // 未传手机号时由调用方预填；这里若为空引导回上一页
        if phone.isEmpty {
            showToast("请先输入手机号")
        }
    }

    @MainActor
    deinit {
        timer?.invalidate()
    }

    private func setupUI() {
        // 顶部提示
        let titleLabel = UILabel()
        titleLabel.text = "验证码已发送"
        titleLabel.font = .appTitle(22)
        titleLabel.textColor = Theme.Color.ink

        let desc = phone.isEmpty ? "" : "已发送至 +86 \(phone)，请查收短信"
        tipLabel.text = desc
        tipLabel.font = .appBody(14)
        tipLabel.textColor = Theme.Color.sub

        // 4 格输入框
        let codeStack = UIStackView()
        codeStack.axis = .horizontal
        codeStack.spacing = 16
        codeStack.distribution = .fillEqually
        for i in 0..<4 {
            let field = UITextField()
            field.font = .appTitle(28)
            field.textColor = Theme.Color.ink
            field.textAlignment = .center
            field.keyboardType = .numberPad
            field.delegate = self
            field.tag = i
            field.layer.cornerRadius = Theme.Radius.input
            field.layer.borderWidth = 1
            field.layer.borderColor = Theme.Color.line.cgColor
            field.backgroundColor = Theme.Color.surface
            field.addTarget(self, action: #selector(textDidChange(_:)), for: .editingChanged)
            codeFields.append(field)
            codeStack.addArrangedSubview(field)
        }

        // 倒计时 / 重发
        countdownLabel.font = .appBody(13)
        countdownLabel.textColor = Theme.Color.muted

        resendButton.setTitle("重新发送", for: .normal)
        resendButton.titleLabel?.font = .appBody(13)
        resendButton.setTitleColor(Theme.Color.muted, for: .normal)
        resendButton.isEnabled = false
        resendButton.addTarget(self, action: #selector(didTapResend), for: .touchUpInside)

        let resendRow = UIView()
        resendRow.addSubview(countdownLabel)
        resendRow.addSubview(resendButton)
        countdownLabel.snp.makeConstraints { make in
            make.left.centerY.equalToSuperview()
        }
        resendButton.snp.makeConstraints { make in
            make.left.equalTo(countdownLabel.snp.right).offset(4)
            make.centerY.equalToSuperview()
        }

        // 下一步
        nextButton.setTitle("下一步", for: .normal)
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.titleLabel?.font = .appSection(17)
        nextButton.backgroundColor = Theme.Color.muted
        nextButton.isEnabled = false
        nextButton.layer.cornerRadius = Theme.Radius.button
        nextButton.addTarget(self, action: #selector(didTapNext), for: .touchUpInside)

        view.addSubview(titleLabel)
        view.addSubview(tipLabel)
        view.addSubview(codeStack)
        view.addSubview(resendRow)
        view.addSubview(nextButton)

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(48)
            make.left.equalToSuperview().offset(32)
        }
        tipLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.left.equalTo(titleLabel)
        }
        codeStack.snp.makeConstraints { make in
            make.top.equalTo(tipLabel.snp.bottom).offset(40)
            make.left.right.equalToSuperview().inset(32)
            make.height.equalTo(56)
        }
        resendRow.snp.makeConstraints { make in
            make.top.equalTo(codeStack.snp.bottom).offset(14)
            make.centerX.equalToSuperview()
            make.height.equalTo(24)
        }
        nextButton.snp.makeConstraints { make in
            make.top.equalTo(resendRow.snp.bottom).offset(36)
            make.left.right.equalToSuperview().inset(32)
            make.height.equalTo(50)
        }
    }

    // MARK: - 倒计时

    private func startCountdown() {
        countdown = 60
        timer?.invalidate()
        updateCountdownUI()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { return }
            self.countdown -= 1
            self.updateCountdownUI()
            if self.countdown <= 0 {
                timer.invalidate()
            }
        }
    }

    private func updateCountdownUI() {
        if countdown > 0 {
            countdownLabel.text = "\(countdown)s后可重新发送 ·"
            countdownLabel.textColor = Theme.Color.muted
            resendButton.isEnabled = false
            resendButton.setTitleColor(Theme.Color.muted, for: .normal)
        } else {
            countdownLabel.text = ""
            resendButton.isEnabled = true
            resendButton.setTitleColor(Theme.Color.brand, for: .normal)
        }
    }

    @objc private func didTapResend() {
        let phone = self.phone
        guard !phone.isEmpty else { return }
        showLoading("发送中...")
        AuthService.sendCode(phone: phone) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success:
                self.showToast("验证码已重新发送")
                self.startCountdown()
            case .failure(let error):
                self.showToast(error.message)
            }
        }
    }

    // MARK: - 输入

    @objc private func textDidChange(_ field: UITextField) {
        let text = field.text ?? ""
        if text.count >= 1 {
            // 自动跳下一格
            if field.tag < 3 {
                codeFields[field.tag + 1].becomeFirstResponder()
            } else {
                field.resignFirstResponder()
            }
        }
        updateNextState()
    }

    private func currentCode() -> String {
        codeFields.map { $0.text ?? "" }.joined()
    }

    private func updateNextState() {
        let filled = currentCode().count == 4
        nextButton.isEnabled = filled
        nextButton.backgroundColor = filled ? Theme.Color.brand : Theme.Color.muted
    }

    @objc private func didTapNext() {
        let code = currentCode()
        guard code.count == 4 else { return }
        let phone = self.phone
        guard !phone.isEmpty else { return }

        switch purpose {
        case .register:
            showLoading("注册中...")
            AuthService.register(phone: phone, code: code) { [weak self] result in
                self?.handleRegisterResult(result)
            }
        case .login:
            showLoading("登录中...")
            AuthService.loginWithCode(phone: phone, code: code) { [weak self] result in
                self?.handleLoginResult(result)
            }
        }
    }

    private func handleRegisterResult(_ result: Result<AuthService.LoginPayload, APIError>) {
        hideLoading()
        switch result {
        case .success(let payload):
            let userInfo: [String: Any] = [
                "nickname": payload.nickname,
                "phone": payload.phone
            ]
            TokenManager.shared.save(token: payload.token, userId: payload.userId, role: payload.role, userInfo: userInfo)
            showToast("注册成功")
            AppRouter.shared.showMainTab()
        case .failure(let error):
            showToast(error.message)
        }
    }

    private func handleLoginResult(_ result: Result<AuthService.LoginPayload, APIError>) {
        hideLoading()
        switch result {
        case .success(let payload):
            let userInfo: [String: Any] = [
                "nickname": payload.nickname,
                "phone": payload.phone
            ]
            TokenManager.shared.save(token: payload.token, userId: payload.userId, role: payload.role, userInfo: userInfo)
            AppRouter.shared.showMainTab()
        case .failure(let error):
            showToast(error.message)
        }
    }
}

extension VerifyCodeViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // 删除键：为空时回退上一格
        if string.isEmpty {
            if (textField.text ?? "").isEmpty, textField.tag > 0 {
                codeFields[textField.tag - 1].becomeFirstResponder()
                codeFields[textField.tag - 1].text = ""
            }
            return true
        }
        // 仅数字，每格 1 位
        let allowed = CharacterSet.decimalDigits
        guard string.rangeOfCharacter(from: allowed.inverted) == nil else { return false }
        let new = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        return new.count <= 1
    }
}
