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
    private weak var codeRow: UIView!
    private weak var passwordRow: UIView!
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

        // 手机号输入行
        let phoneBox = makeInputBox()
        let prefixLabel = UILabel()
        prefixLabel.text = "+86"
        prefixLabel.font = .appBody(15)
        prefixLabel.textColor = Theme.Color.ink
        prefixLabel.textAlignment = .center
        prefixLabel.isUserInteractionEnabled = false
        phoneBox.addSubview(prefixLabel)
        prefixLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.equalTo(40)
        }
        phoneBox.addSubview(phoneField)
        phoneField.keyboardType = .numberPad
        phoneField.delegate = self
        phoneField.tag = 1
        phoneField.font = .appBody(16)
        phoneField.textColor = Theme.Color.ink
        phoneField.placeholder = "请输入手机号"
        phoneField.snp.makeConstraints { make in
            make.left.equalTo(prefixLabel.snp.right).offset(12)
            make.right.equalToSuperview().offset(-16)
            make.top.bottom.equalToSuperview()
        }
        // 分隔竖线
        let divider = UIView()
        divider.backgroundColor = Theme.Color.line
        phoneBox.addSubview(divider)
        divider.snp.makeConstraints { make in
            make.left.equalTo(prefixLabel.snp.right).offset(6)
            make.top.bottom.equalToSuperview().inset(12)
            make.width.equalTo(1)
        }
        // 修正 phoneField.left 跳过分隔线
        phoneField.snp.remakeConstraints { make in
            make.left.equalTo(divider.snp.right).offset(12)
            make.right.equalToSuperview().offset(-16)
            make.top.bottom.equalToSuperview()
        }

        // 分段切换
        let segmentRow = UIView()
        codeSegment.setTitle("验证码登录", for: .normal)
        codeSegment.setTitleColor(Theme.Color.ink, for: .normal)
        codeSegment.setTitleColor(.red, for: .selected)
        codeSegment.titleLabel?.font = .appBody(14)
        codeSegment.layer.cornerRadius = 999
        codeSegment.layer.masksToBounds = true
        codeSegment.tag = 0
        codeSegment.addTarget(self, action: #selector(didTapSegment(_:)), for: .touchUpInside)

        passwordSegment.setTitle("密码登录", for: .normal)
        passwordSegment.setTitleColor(Theme.Color.ink, for: .normal)
        passwordSegment.setTitleColor(.red, for: .selected)
        passwordSegment.titleLabel?.font = .appBody(14)
        passwordSegment.layer.cornerRadius = 999
        passwordSegment.layer.masksToBounds = true
        passwordSegment.tag = 1
        passwordSegment.addTarget(self, action: #selector(didTapSegment(_:)), for: .touchUpInside)
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

        // 验证码行
        let codeInput = makeInputBox()
        codeRow = codeInput
        sendCodeButton.setTitle("获取验证码", for: .normal)
        sendCodeButton.setTitleColor(Theme.Color.brand, for: .normal)
        sendCodeButton.titleLabel?.font = .appBody(14)
        sendCodeButton.addTarget(self, action: #selector(didTapSendCode), for: .touchUpInside)
        codeInput.addSubview(sendCodeButton)
        sendCodeButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.equalTo(92)
            make.height.equalTo(32)
        }
        let codeDivider = UIView()
        codeDivider.backgroundColor = Theme.Color.line
        codeInput.addSubview(codeDivider)
        codeDivider.snp.makeConstraints { make in
            make.right.equalTo(sendCodeButton.snp.left).offset(-8)
            make.top.bottom.equalToSuperview().inset(12)
            make.width.equalTo(1)
        }
        codeField.placeholder = "请输入4位验证码"
        codeField.keyboardType = .numberPad
        codeField.font = .appBody(16)
        codeField.textColor = Theme.Color.ink
        codeField.delegate = self
        codeField.tag = 2
        codeInput.addSubview(codeField)
        codeField.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.right.equalTo(codeDivider.snp.left).offset(-8)
            make.top.bottom.equalToSuperview()
        }

        // 密码行
        let passwordBox = makeInputBox()
        passwordRow = passwordBox
        passwordField.placeholder = "请输入密码"
        passwordField.isSecureTextEntry = true
        passwordField.font = .appBody(16)
        passwordField.textColor = Theme.Color.ink
        passwordField.delegate = self
        passwordField.tag = 3
        passwordBox.addSubview(passwordField)
        passwordField.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.top.bottom.equalToSuperview()
        }

        // 登录按钮
        loginButton.setTitle("登 录", for: .normal)
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.titleLabel?.font = .appSection(17)
        loginButton.backgroundColor = Theme.Color.brand
        loginButton.layer.cornerRadius = Theme.Radius.button
        loginButton.layer.masksToBounds = true
        loginButton.addTarget(self, action: #selector(didTapLogin), for: .touchUpInside)

        // 注册入口
        let registerLabel = UILabel()
        let text = "还没有账号？立即注册"
        let attributed = NSMutableAttributedString(string: text)
        attributed.addAttribute(.font, value: UIFont.appBody(14), range: NSRange(location: 0, length: text.count))
        attributed.addAttribute(.foregroundColor, value: Theme.Color.sub, range: NSRange(location: 0, length: 6))
        attributed.addAttribute(.foregroundColor, value: Theme.Color.brand, range: NSRange(location: 6, length: 4))
        registerLabel.attributedText = attributed
        registerLabel.textAlignment = .center
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
        view.addSubview(codeInput)
        view.addSubview(passwordBox)
        view.addSubview(segmentRow)
        view.addSubview(loginButton)
        view.addSubview(registerRow)

        welcomeLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(40)
            make.left.equalToSuperview().offset(32)
            make.right.equalToSuperview().offset(-32)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(welcomeLabel.snp.bottom).offset(8)
            make.left.equalTo(welcomeLabel)
        }
        phoneBox.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(36)
            make.left.right.equalToSuperview().inset(32)
            make.height.equalTo(52)
        }
        // 验证码行 / 密码行同一位置切换
        codeInput.snp.makeConstraints { make in
            make.top.equalTo(phoneBox.snp.bottom).offset(16)
            make.left.right.equalTo(phoneBox)
            make.height.equalTo(52)
        }
        passwordBox.snp.makeConstraints { make in
            make.edges.equalTo(codeInput)
        }
        segmentRow.snp.makeConstraints { make in
            make.top.equalTo(codeInput.snp.bottom).offset(20)
            make.left.right.equalTo(phoneBox)
            make.height.equalTo(32)
        }
        loginButton.snp.makeConstraints { make in
            make.top.equalTo(segmentRow.snp.bottom).offset(32)
            make.left.right.equalTo(phoneBox)
            make.height.equalTo(52)
        }
        registerRow.snp.makeConstraints { make in
            make.top.equalTo(loginButton.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
            make.width.equalTo(240)
            make.height.equalTo(28)
        }
    }

    /// 统一输入框容器：白底 + 1px 边 + radius 14
    private func makeInputBox() -> UIView {
        let box = UIView()
        box.backgroundColor = Theme.Color.surface
        box.layer.cornerRadius = Theme.Radius.input
        box.layer.borderWidth = 1
        box.layer.borderColor = Theme.Color.line.cgColor
        return box
    }

    private func updateModeUI() {
        let isCode = mode == .code
        codeRow.isHidden = !isCode
        passwordRow.isHidden = isCode
        segmentRowStyle(codeSegment, selected: isCode)
        segmentRowStyle(passwordSegment, selected: !isCode)
    }

    private func segmentRowStyle(_ button: UIButton, selected: Bool) {
        button.isSelected = selected
        button.backgroundColor = selected ? Theme.Color.brand : Theme.Color.surfaceAlt
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
