import UIKit
import SnapKit

/// 手机号登录页：验证码 / 密码双模式切换（对齐高保真原型）
final class PhoneLoginViewController: BaseViewController {

    private enum Mode {
        case code, password
    }
    private var mode: Mode = .code

    private let phoneField = UITextField()
    private let codeField = UITextField()
    private let passwordField = UITextField()
    private var codeRow = UIView()
    private var passwordRow = UIView()
    private let sendCodeButton = UIButton(type: .system)
    private let loginButton = UIButton(type: .system)
    private let codeSegment = UIButton(type: .system)
    private let passwordSegment = UIButton(type: .system)

    /// 验证码倒计时
    private var countdown = 0
    private var timer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "手机号登录"
        view.backgroundColor = Theme.Color.bg
        setupUI()
        updateModeUI()
    }

    @MainActor
    deinit {
        timer?.invalidate()
    }

    // MARK: - UI

    private func setupUI() {
        // 欢迎语
        let welcomeLabel = UILabel()
        welcomeLabel.text = "欢迎来到艺启"
        welcomeLabel.font = .appTitle(26)
        welcomeLabel.textColor = Theme.Color.ink

        let subtitleLabel = UILabel()
        subtitleLabel.text = "选择你习惯的登录方式"
        subtitleLabel.font = .appBody(14)
        subtitleLabel.textColor = Theme.Color.sub

        // 手机号输入
        let phoneBox = makeInputRow(field: phoneField)
        phoneField.keyboardType = .numberPad
        phoneField.delegate = self
        phoneField.tag = 1
        let prefixLabel = UILabel()
        prefixLabel.text = "+86"
        prefixLabel.font = .appBody(15)
        prefixLabel.textColor = Theme.Color.ink
        phoneBox.addSubview(prefixLabel)
        prefixLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
        }
        phoneField.snp.remakeConstraints { make in
            make.left.equalTo(prefixLabel.snp.right).offset(10)
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.height.equalTo(46)
        }

        // 验证码行
        sendCodeButton.setTitle("获取验证码", for: .normal)
        sendCodeButton.setTitleColor(Theme.Color.brand, for: .normal)
        sendCodeButton.titleLabel?.font = .appBody(14)
        sendCodeButton.addTarget(self, action: #selector(didTapSendCode), for: .touchUpInside)

        codeField.placeholder = "请输入4位验证码"
        codeField.keyboardType = .numberPad
        codeField.font = .appBody(16)
        codeField.textColor = Theme.Color.ink
        codeField.delegate = self
        codeField.tag = 2

        let codeInput = makeInputRow(field: codeField)
        codeInput.addSubview(sendCodeButton)
        sendCodeButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }
        codeField.snp.remakeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.right.equalTo(sendCodeButton.snp.left).offset(-8)
            make.centerY.equalToSuperview()
            make.height.equalTo(46)
        }

        // 密码行
        passwordField.placeholder = "请输入密码"
        passwordField.isSecureTextEntry = true
        passwordField.font = .appBody(16)
        passwordField.textColor = Theme.Color.ink
        passwordField.delegate = self
        passwordField.tag = 3

        let passwordBox = makeInputRow(field: passwordField)

        // 分段切换
        let segmentRow = UIView()
        codeSegment.setTitle("验证码登录", for: .normal)
        passwordSegment.setTitle("密码登录", for: .normal)
        for seg in [codeSegment, passwordSegment] {
            seg.titleLabel?.font = .appBody(14)
            seg.layer.cornerRadius = 999
            seg.addTarget(self, action: #selector(didTapSegment(_:)), for: .touchUpInside)
        }
        codeSegment.tag = 0
        passwordSegment.tag = 1
        codeSegment.accessibilityLabel = "验证码登录"
        passwordSegment.accessibilityLabel = "密码登录"
        segmentRow.addSubview(codeSegment)
        segmentRow.addSubview(passwordSegment)
        codeSegment.snp.makeConstraints { make in
            make.left.centerY.equalToSuperview()
            make.width.equalTo(96)
            make.height.equalTo(32)
        }
        passwordSegment.snp.makeConstraints { make in
            make.left.equalTo(codeSegment.snp.right).offset(8)
            make.centerY.equalToSuperview()
            make.width.equalTo(96)
            make.height.equalTo(32)
        }

        // 登录按钮
        loginButton.setTitle("登 录", for: .normal)
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.titleLabel?.font = .appSection(17)
        loginButton.backgroundColor = Theme.Color.brand
        loginButton.layer.cornerRadius = Theme.Radius.button
        loginButton.addTarget(self, action: #selector(didTapLogin), for: .touchUpInside)

        // 注册入口
        let registerLabel = UILabel()
        let text = "还没有账号？立即注册"
        let attributed = NSMutableAttributedString(string: text)
        attributed.addAttribute(.font, value: UIFont.appBody(14), range: NSRange(location: 0, length: text.count))
        attributed.addAttribute(.foregroundColor, value: Theme.Color.sub, range: NSRange(location: 0, length: 6))
        attributed.addAttribute(.foregroundColor, value: Theme.Color.brand, range: NSRange(location: 6, length: 4))
        registerLabel.attributedText = attributed
        registerLabel.isUserInteractionEnabled = true
        registerLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapRegister)))

        let registerRow = UIView()
        registerRow.addSubview(registerLabel)
        registerLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        view.addSubview(welcomeLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(phoneBox)
        view.addSubview(segmentRow)
        view.addSubview(codeInput)
        view.addSubview(passwordBox)
        view.addSubview(loginButton)
        view.addSubview(registerRow)

        welcomeLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(40)
            make.left.equalToSuperview().offset(32)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(welcomeLabel.snp.bottom).offset(8)
            make.left.equalTo(welcomeLabel)
        }
        phoneBox.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(36)
            make.left.right.equalToSuperview().inset(32)
            make.height.equalTo(50)
        }
        segmentRow.snp.makeConstraints { make in
            make.top.equalTo(phoneBox.snp.bottom).offset(24)
            make.left.equalTo(phoneBox)
            make.right.equalTo(passwordSegment)
            make.height.equalTo(32)
        }
        // 验证码行 / 密码行同一位置切换
        codeInput.snp.makeConstraints { make in
            make.top.equalTo(segmentRow.snp.bottom).offset(14)
            make.left.right.equalTo(phoneBox)
            make.height.equalTo(50)
        }
        passwordBox.snp.makeConstraints { make in
            make.top.equalTo(segmentRow.snp.bottom).offset(14)
            make.left.right.equalTo(phoneBox)
            make.height.equalTo(50)
        }
        loginButton.snp.makeConstraints { make in
            make.top.equalTo(codeInput.snp.bottom).offset(32)
            make.left.right.equalTo(phoneBox)
            make.height.equalTo(50)
        }
        registerRow.snp.makeConstraints { make in
            make.top.equalTo(loginButton.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
            make.width.equalTo(240)
            make.height.equalTo(28)
        }

        codeRow = codeInput
        passwordRow = passwordBox
    }

    /// 构造统一样式输入框容器（白底 + 1px 边 + radius 14）
    private func makeInputRow(field: UITextField) -> UIView {
        let box = UIView()
        box.backgroundColor = Theme.Color.surface
        box.layer.cornerRadius = Theme.Radius.input
        box.layer.borderWidth = 1
        box.layer.borderColor = Theme.Color.line.cgColor

        box.addSubview(field)
        field.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.height.equalTo(46)
        }
        return box
    }

    private func updateModeUI() {
        let isCode = mode == .code
        codeRow.isHidden = !isCode
        passwordRow.isHidden = isCode
        segmentRowStyle(codeSegment, selected: isCode)
        segmentRowStyle(passwordSegment, selected: !isCode)
        // 密码模式下，验证码行占位折叠，分段上移
    }

    private func segmentRowStyle(_ button: UIButton, selected: Bool) {
        button.setTitleColor(selected ? .white : Theme.Color.sub, for: .normal)
        button.backgroundColor = selected ? Theme.Color.brand : .clear
        button.layer.borderWidth = selected ? 0 : 1
        button.layer.borderColor = Theme.Color.line.cgColor
    }

    // MARK: - Actions

    @objc private func didTapSegment(_ sender: UIButton) {
        mode = sender.tag == 0 ? .code : .password
        updateModeUI()
    }

    @objc private func didTapSendCode() {
        let phone = phoneField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard isValidPhone(phone) else {
            showToast("请输入正确的手机号")
            return
        }
        guard countdown == 0 else { return }

        showLoading("发送中...")
        AuthService.sendCode(phone: phone) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success:
                self.showToast("验证码已发送")
                self.startCountdown()
            case .failure(let error):
                self.showToast(error.message)
            }
        }
    }

    @objc private func didTapLogin() {
        let phone = phoneField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard isValidPhone(phone) else {
            showToast("请输入正确的手机号")
            return
        }

        switch mode {
        case .code:
            let code = codeField.text?.trimmingCharacters(in: .whitespaces) ?? ""
            guard code.count == 4 else {
                showToast("请输入4位验证码")
                return
            }
            showLoading("登录中...")
            AuthService.loginWithCode(phone: phone, code: code) { [weak self] result in
                self?.handleLoginResult(result)
            }
        case .password:
            let password = passwordField.text ?? ""
            guard !password.isEmpty else {
                showToast("请输入密码")
                return
            }
            showLoading("登录中...")
            AuthService.loginPassword(phone: phone, password: password) { [weak self] result in
                self?.handleLoginResult(result)
            }
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
            NSLog("[Login] failure code=\(error.code) msg=\(error.message)")
            showToast(error.message)
        }
    }

    @objc private func didTapRegister() {
        let phone = phoneField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard isValidPhone(phone) else {
            showToast("请输入正确的手机号")
            return
        }
        // 先进验证码页，自动发送验证码
        showLoading("发送中...")
        AuthService.sendCode(phone: phone) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success:
                let vc = VerifyCodeViewController(phone: phone, purpose: .register)
                self.navigationController?.pushViewController(vc, animated: true)
            case .failure(let error):
                self.showToast(error.message)
            }
        }
    }

    // MARK: - 工具

    private func isValidPhone(_ phone: String) -> Bool {
        phone.count == 11 && phone.first == "1"
    }

    private func startCountdown() {
        countdown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { return }
            self.countdown -= 1
            if self.countdown <= 0 {
                self.countdown = 0
                self.sendCodeButton.setTitle("获取验证码", for: .normal)
                self.sendCodeButton.setTitleColor(Theme.Color.brand, for: .normal)
                timer.invalidate()
            } else {
                self.sendCodeButton.setTitle("\(self.countdown)s后重发", for: .normal)
                self.sendCodeButton.setTitleColor(Theme.Color.muted, for: .normal)
            }
        }
    }
}

extension PhoneLoginViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text as NSString? else { return true }
        let new = text.replacingCharacters(in: range, with: string)
        switch textField.tag {
        case 1: // 手机号：11 位数字
            if new.count > 11 { showToast("最多11位"); return false }
            let allowed = CharacterSet.decimalDigits
            return new.rangeOfCharacter(from: allowed.inverted) == nil
        case 2: // 验证码：4 位数字
            if new.count > 4 { showToast("最多4位"); return false }
            let allowed = CharacterSet.decimalDigits
            return new.rangeOfCharacter(from: allowed.inverted) == nil
        default: // 密码：任意字符，最长 32
            return new.count <= 32
        }
    }
}
