import UIKit
import SnapKit

// MARK: - 修改登录密码

final class ChangePasswordViewController: BaseViewController {

    private let oldField = UITextField()
    private let newField = UITextField()
    private let confirmField = UITextField()
    private let saveButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "修改登录密码")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    private func setupUI() {
        let oldCard = makeFieldCard(field: oldField, placeholder: "请输入原密码", secure: true)
        view.addSubview(oldCard)
        oldCard.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(52)
        }

        let newCard = makeFieldCard(field: newField, placeholder: "请输入新密码（6-20 位）", secure: true)
        view.addSubview(newCard)
        newCard.snp.makeConstraints {
            $0.top.equalTo(oldCard.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(52)
        }

        let confirmCard = makeFieldCard(field: confirmField, placeholder: "请再次输入新密码", secure: true)
        view.addSubview(confirmCard)
        confirmCard.snp.makeConstraints {
            $0.top.equalTo(newCard.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(52)
        }

        saveButton.setTitle("确认修改", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = .appBody(16)
        saveButton.backgroundColor = Theme.Color.brand
        saveButton.layer.cornerRadius = 25
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        view.addSubview(saveButton)
        saveButton.snp.makeConstraints {
            $0.top.equalTo(confirmCard.snp.bottom).offset(32)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(50)
        }
    }

    private func makeFieldCard(field: UITextField, placeholder: String, secure: Bool) -> UIView {
        let card = UIView()
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = 12
        field.font = .appBody(15)
        field.textColor = Theme.Color.ink
        field.placeholder = placeholder
        field.isSecureTextEntry = secure
        field.clearButtonMode = .whileEditing
        card.addSubview(field)
        field.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
        }
        return card
    }

    @objc private func saveTapped() {
        let old = oldField.text ?? ""
        let new = newField.text ?? ""
        let confirm = confirmField.text ?? ""
        guard !old.isEmpty, !new.isEmpty else {
            showToast("请填写完整")
            return
        }
        guard new == confirm else {
            showToast("两次输入的新密码不一致")
            return
        }
        guard new.count >= 6, new.count <= 20 else {
            showToast("新密码长度需为 6-20 位")
            return
        }
        view.endEditing(true)
        showLoading("提交中...")
        AuthService.changePassword(oldPassword: old, newPassword: new) { [weak self] success, error in
            guard let self else { return }
            self.hideLoading()
            if success {
                self.showToast("密码已修改")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self.navigationController?.popViewController(animated: true)
                }
            } else {
                self.showToast(error ?? "修改失败")
            }
        }
    }
}

// MARK: - 更换绑定手机号

final class ChangePhoneViewController: BaseViewController {

    private let phoneField = UITextField()
    private let codeField = UITextField()
    private let codeButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private var countdown = 0
    private var timer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "更换手机号")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
        timer?.invalidate()
    }

    private func setupUI() {
        let phoneCard = UIView()
        phoneCard.backgroundColor = Theme.Color.surface
        phoneCard.layer.cornerRadius = 12
        view.addSubview(phoneCard)
        phoneCard.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(52)
        }

        phoneField.font = .appBody(15)
        phoneField.textColor = Theme.Color.ink
        phoneField.placeholder = "请输入新手机号"
        phoneField.keyboardType = .numberPad
        phoneField.clearButtonMode = .whileEditing
        phoneCard.addSubview(phoneField)
        phoneField.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
        }

        let codeCard = UIView()
        codeCard.backgroundColor = Theme.Color.surface
        codeCard.layer.cornerRadius = 12
        view.addSubview(codeCard)
        codeCard.snp.makeConstraints {
            $0.top.equalTo(phoneCard.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(52)
        }

        codeField.font = .appBody(15)
        codeField.textColor = Theme.Color.ink
        codeField.placeholder = "请输入验证码"
        codeField.keyboardType = .numberPad
        codeCard.addSubview(codeField)
        codeField.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().inset(110)
        }

        codeButton.setTitle("获取验证码", for: .normal)
        codeButton.setTitleColor(Theme.Color.brand, for: .normal)
        codeButton.titleLabel?.font = .appLabel(13)
        codeButton.addTarget(self, action: #selector(sendCodeTapped), for: .touchUpInside)
        codeCard.addSubview(codeButton)
        codeButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
        }

        let tipLabel = UILabel()
        tipLabel.text = "新手机号将替换当前登录手机号"
        tipLabel.font = .appLabel(12)
        tipLabel.textColor = Theme.Color.sub
        view.addSubview(tipLabel)
        tipLabel.snp.makeConstraints {
            $0.top.equalTo(codeCard.snp.bottom).offset(8)
            $0.leading.equalToSuperview().inset(Theme.Spacing.l + 4)
        }

        saveButton.setTitle("确认更换", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = .appBody(16)
        saveButton.backgroundColor = Theme.Color.brand
        saveButton.layer.cornerRadius = 25
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        view.addSubview(saveButton)
        saveButton.snp.makeConstraints {
            $0.top.equalTo(tipLabel.snp.bottom).offset(Theme.Spacing.xl)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(50)
        }
    }

    @objc private func sendCodeTapped() {
        let phone = phoneField.text ?? ""
        guard phone.count == 11 else {
            showToast("请输入正确的手机号")
            return
        }
        showLoading("发送中...")
        AuthService.sendCode(phone: phone) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success:
                self.showToast("验证码已发送")
                self.startCountdown()
            case .failure(let error):
                self.showToast(error.message ?? "发送失败")
            }
        }
    }

    private func startCountdown() {
        countdown = 60
        codeButton.isEnabled = false
        codeButton.setTitleColor(Theme.Color.sub, for: .disabled)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.countdown -= 1
            if self.countdown <= 0 {
                self.timer?.invalidate()
                self.timer = nil
                self.codeButton.isEnabled = true
                self.codeButton.setTitle("获取验证码", for: .normal)
            } else {
                self.codeButton.setTitle("\(self.countdown)s 后重发", for: .disabled)
            }
        }
    }

    @objc private func saveTapped() {
        let phone = phoneField.text ?? ""
        let code = codeField.text ?? ""
        guard phone.count == 11, !code.isEmpty else {
            showToast("请填写完整")
            return
        }
        view.endEditing(true)
        showLoading("提交中...")
        AuthService.changePhone(phone: phone, code: code) { [weak self] success, error in
            guard let self else { return }
            self.hideLoading()
            if success {
                self.showToast("手机号已更换")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self.navigationController?.popViewController(animated: true)
                }
            } else {
                self.showToast(error ?? "更换失败")
            }
        }
    }
}

// MARK: - 设置支付密码

final class SetPayPasswordViewController: BaseViewController {

    private let payField = UITextField()
    private let confirmField = UITextField()
    private let saveButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "设置支付密码")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    private func setupUI() {
        let payCard = makeFieldCard(field: payField, placeholder: "请输入 6 位数字支付密码", secure: true)
        view.addSubview(payCard)
        payCard.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(52)
        }

        let confirmCard = makeFieldCard(field: confirmField, placeholder: "请再次输入支付密码", secure: true)
        view.addSubview(confirmCard)
        confirmCard.snp.makeConstraints {
            $0.top.equalTo(payCard.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(52)
        }

        let tipLabel = UILabel()
        tipLabel.text = "支付密码用于佣金提现等操作时校验"
        tipLabel.font = .appLabel(12)
        tipLabel.textColor = Theme.Color.sub
        view.addSubview(tipLabel)
        tipLabel.snp.makeConstraints {
            $0.top.equalTo(confirmCard.snp.bottom).offset(8)
            $0.leading.equalToSuperview().inset(Theme.Spacing.l + 4)
        }

        saveButton.setTitle("确认设置", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = .appBody(16)
        saveButton.backgroundColor = Theme.Color.brand
        saveButton.layer.cornerRadius = 25
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        view.addSubview(saveButton)
        saveButton.snp.makeConstraints {
            $0.top.equalTo(tipLabel.snp.bottom).offset(Theme.Spacing.xl)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(50)
        }
    }

    private func makeFieldCard(field: UITextField, placeholder: String, secure: Bool) -> UIView {
        let card = UIView()
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = 12
        field.font = .appBody(15)
        field.textColor = Theme.Color.ink
        field.placeholder = placeholder
        field.isSecureTextEntry = secure
        field.keyboardType = .numberPad
        card.addSubview(field)
        field.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
        }
        return card
    }

    @objc private func saveTapped() {
        let pay = payField.text ?? ""
        let confirm = confirmField.text ?? ""
        guard pay.count == 6, confirm.count == 6 else {
            showToast("请输入 6 位数字支付密码")
            return
        }
        guard pay == confirm else {
            showToast("两次输入的支付密码不一致")
            return
        }
        view.endEditing(true)
        showLoading("提交中...")
        AuthService.setPayPassword(pay) { [weak self] success, error in
            guard let self else { return }
            self.hideLoading()
            if success {
                self.showToast("支付密码已设置")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self.navigationController?.popViewController(animated: true)
                }
            } else {
                self.showToast(error ?? "设置失败")
            }
        }
    }
}

// MARK: - 注销账号

final class DeactivateAccountViewController: BaseViewController {

    private let codeField = UITextField()
    private let codeButton = UIButton(type: .system)
    private let deactivateButton = UIButton(type: .system)
    private var countdown = 0
    private var timer: Timer?
    private var currentPhone = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupUI()
        AuthService.fetchMe { [weak self] profile, _ in
            self?.currentPhone = profile?.phone ?? ""
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "注销账号")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
        timer?.invalidate()
    }

    private func setupUI() {
        let warning = UILabel()
        warning.text = "注销后，您的账号数据（课程、订单、作品、收益等）将被停用且无法恢复。请谨慎操作。"
        warning.font = .appBody(13)
        warning.textColor = Theme.Color.sub
        warning.numberOfLines = 0
        view.addSubview(warning)
        warning.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        let codeCard = UIView()
        codeCard.backgroundColor = Theme.Color.surface
        codeCard.layer.cornerRadius = 12
        view.addSubview(codeCard)
        codeCard.snp.makeConstraints {
            $0.top.equalTo(warning.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(52)
        }

        codeField.font = .appBody(15)
        codeField.textColor = Theme.Color.ink
        codeField.placeholder = "请输入短信验证码确认"
        codeField.keyboardType = .numberPad
        codeCard.addSubview(codeField)
        codeField.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().inset(110)
        }

        codeButton.setTitle("获取验证码", for: .normal)
        codeButton.setTitleColor(Theme.Color.brand, for: .normal)
        codeButton.titleLabel?.font = .appLabel(13)
        codeButton.addTarget(self, action: #selector(sendCodeTapped), for: .touchUpInside)
        codeCard.addSubview(codeButton)
        codeButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
        }

        deactivateButton.setTitle("确认注销", for: .normal)
        deactivateButton.setTitleColor(.white, for: .normal)
        deactivateButton.titleLabel?.font = .appBody(16)
        deactivateButton.backgroundColor = UIColor(hex: 0xE5484D)
        deactivateButton.layer.cornerRadius = 25
        deactivateButton.addTarget(self, action: #selector(deactivateTapped), for: .touchUpInside)
        view.addSubview(deactivateButton)
        deactivateButton.snp.makeConstraints {
            $0.top.equalTo(codeCard.snp.bottom).offset(32)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(50)
        }
    }

    @objc private func sendCodeTapped() {
        guard !currentPhone.isEmpty else {
            showToast("手机号获取失败，请重试")
            return
        }
        showLoading("发送中...")
        AuthService.sendCode(phone: currentPhone) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success:
                self.showToast("验证码已发送")
                self.startCountdown()
            case .failure(let error):
                self.showToast(error.message ?? "发送失败")
            }
        }
    }

    private func startCountdown() {
        countdown = 60
        codeButton.isEnabled = false
        codeButton.setTitleColor(Theme.Color.sub, for: .disabled)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.countdown -= 1
            if self.countdown <= 0 {
                self.timer?.invalidate()
                self.timer = nil
                self.codeButton.isEnabled = true
                self.codeButton.setTitle("获取验证码", for: .normal)
            } else {
                self.codeButton.setTitle("\(self.countdown)s 后重发", for: .disabled)
            }
        }
    }

    @objc private func deactivateTapped() {
        let code = codeField.text ?? ""
        guard !code.isEmpty else {
            showToast("请输入验证码")
            return
        }
        ThemeAlertView.show(
            title: "确认注销",
            message: "注销后账号将无法登录，确定要注销吗？",
            confirmTitle: "确认注销",
            onConfirm: { [weak self] in
                guard let self else { return }
                self.showLoading("提交中...")
                AuthService.deactivateAccount(code: code) { success, error in
                    self.hideLoading()
                    if success {
                        self.showToast("账号已注销")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            AppRouter.shared.showLogin()
                        }
                    } else {
                        self.showToast(error ?? "注销失败")
                    }
                }
            }
        )
    }
}
