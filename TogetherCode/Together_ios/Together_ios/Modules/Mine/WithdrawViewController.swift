import UIKit
import SnapKit
import SwiftyJSON

/// 提现记录页面：工作室角色「我的」→ 提现
/// 定位为记账工具：平台不碰资金，实际转账线下完成，App只做记录
/// 收款方式：艺启余额（余额记录，免手续费）/ 已绑定银行卡（动态加载，线下转账）
final class WithdrawViewController: BaseViewController, UITextFieldDelegate {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // 余额卡片
    private let balanceCard = UIView()
    private let balanceTitleLabel = UILabel()
    private let balanceValueLabel = UILabel()
    
    // 金额输入
    private let amountCard = UIView()
    private let amountTitleLabel = UILabel()
    private let amountField = UITextField()
    private let amountSuffixLabel = UILabel()
    private let withdrawAllButton = UIButton(type: .system)
    private let tipLabel = UILabel()
    private let feeLabel = UILabel()
    
    // 到账方式
    private let methodTitleLabel = UILabel()
    private let walletMethodRow = MethodRow(iconName: "yiqi_wallet", title: "艺启余额", subtitle: "余额记录 · 免手续费", selected: true)
    
    // 银行卡行（动态）
    private var bankRows: [MethodRow] = []
    private var bankAccounts: [BankAccount] = []
    
    // 添加银行卡按钮
    private let addBankButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("+ 添加银行卡", for: .normal)
        btn.titleLabel?.font = .appBody(14)
        btn.setTitleColor(Theme.Color.brand, for: .normal)
        btn.contentHorizontalAlignment = .left
        return btn
    }()
    
    // 底部确认按钮
    private let confirmButton = UIButton(type: .system)
    
    private var withdrawable: Double = 0
    private var selectedMethod = "wallet"  // "wallet" 或 "bank"
    private var selectedAccountId: String? = nil
    
    // MARK: - Init
    
    init(withdrawable: Double) {
        self.withdrawable = withdrawable
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
        amountField.delegate = self
        updateFeeLabel()
        loadBankAccounts()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "提现")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = Theme.Color.bg
        
        // 滚动层
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // 余额卡片（松绿）
        balanceCard.backgroundColor = Theme.Color.brandDark
        balanceCard.layer.cornerRadius = Theme.Radius.card
        balanceCard.layer.masksToBounds = true
        contentView.addSubview(balanceCard)
        
        balanceTitleLabel.text = "可提现余额（元）"
        balanceTitleLabel.font = .appBody(14)
        balanceTitleLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        balanceCard.addSubview(balanceTitleLabel)
        
        balanceValueLabel.text = String(format: "¥%.2f", withdrawable)
        balanceValueLabel.font = .appHero(36)
        balanceValueLabel.textColor = .white
        balanceCard.addSubview(balanceValueLabel)
        
        // 金额输入卡片
        amountCard.backgroundColor = Theme.Color.surface
        amountCard.layer.cornerRadius = Theme.Radius.card
        amountCard.layer.masksToBounds = true
        contentView.addSubview(amountCard)
        
        amountTitleLabel.text = "提现金额"
        amountTitleLabel.font = .appBody(14)
        amountTitleLabel.textColor = Theme.Color.sub
        amountCard.addSubview(amountTitleLabel)
        
        amountField.placeholder = "0.00"
        amountField.font = .appHero(28)
        amountField.textColor = Theme.Color.ink
        amountField.keyboardType = .decimalPad
        amountField.delegate = self
        amountField.textAlignment = .left
        amountCard.addSubview(amountField)
        
        amountSuffixLabel.text = "¥"
        amountSuffixLabel.font = .appHero(28)
        amountSuffixLabel.textColor = Theme.Color.ink
        amountCard.addSubview(amountSuffixLabel)
        
        withdrawAllButton.setTitle("全部提现", for: .normal)
        withdrawAllButton.titleLabel?.font = .appBody(14)
        withdrawAllButton.setTitleColor(Theme.Color.brand, for: .normal)
        withdrawAllButton.addTarget(self, action: #selector(didTapWithdrawAll), for: .touchUpInside)
        amountCard.addSubview(withdrawAllButton)
        
        tipLabel.text = "单笔限额 ¥50,000 · 银行卡手续费 0.1% · 线下转账请自行安排"
        tipLabel.font = .appBody(12)
        tipLabel.textColor = Theme.Color.sub
        amountCard.addSubview(tipLabel)
        
        feeLabel.text = "免手续费"
        feeLabel.font = .appBody(12)
        feeLabel.textColor = Theme.Color.success
        amountCard.addSubview(feeLabel)
        
        // 到账方式
        methodTitleLabel.text = "收款方式"
        methodTitleLabel.font = .appBody(14)
        methodTitleLabel.textColor = Theme.Color.sub
        contentView.addSubview(methodTitleLabel)
        
        walletMethodRow.onTap = { [weak self] in
            guard let self else { return }
            self.selectMethod("wallet")
        }
        contentView.addSubview(walletMethodRow)
        
        // 添加银行卡按钮
        addBankButton.addTarget(self, action: #selector(didTapAddBank), for: .touchUpInside)
        contentView.addSubview(addBankButton)
        
        // 底部确认按钮
        confirmButton.setTitle("确认记录", for: .normal)
        confirmButton.titleLabel?.font = .appBody(16)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.backgroundColor = Theme.Color.brand
        confirmButton.layer.cornerRadius = 24
        confirmButton.addTarget(self, action: #selector(didTapConfirm), for: .touchUpInside)
        view.addSubview(confirmButton)
    }
    
    // MARK: - 约束（银行卡行动态添加后需 rebuild）
    
    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(confirmButton.snp.top).offset(-Theme.Spacing.m)
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
        
        // 余额卡片
        balanceCard.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Theme.Spacing.m)
            make.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            make.height.equalTo(140)
        }
        
        balanceTitleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(Theme.Spacing.l)
        }
        
        balanceValueLabel.snp.makeConstraints { make in
            make.top.equalTo(balanceTitleLabel.snp.bottom).offset(Theme.Spacing.m)
            make.leading.equalToSuperview().inset(Theme.Spacing.l)
        }
        
        // 金额卡片
        amountCard.snp.makeConstraints { make in
            make.top.equalTo(balanceCard.snp.bottom).offset(Theme.Spacing.l)
            make.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            make.height.equalTo(160)
        }
        
        amountTitleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(Theme.Spacing.l)
        }
        
        amountSuffixLabel.snp.makeConstraints { make in
            make.top.equalTo(amountTitleLabel.snp.bottom).offset(Theme.Spacing.m)
            make.leading.equalToSuperview().inset(Theme.Spacing.l)
        }
        
        amountField.snp.makeConstraints { make in
            make.centerY.equalTo(amountSuffixLabel)
            make.leading.equalTo(amountSuffixLabel.snp.trailing).offset(Theme.Spacing.s)
            make.trailing.lessThanOrEqualTo(withdrawAllButton.snp.leading).offset(-Theme.Spacing.m)
        }
        
        withdrawAllButton.snp.makeConstraints { make in
            make.centerY.equalTo(amountSuffixLabel)
            make.trailing.equalToSuperview().inset(Theme.Spacing.l)
            make.width.equalTo(72)
        }
        
        tipLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview().inset(Theme.Spacing.l)
            make.leading.equalToSuperview().inset(Theme.Spacing.l)
        }
        
        feeLabel.snp.makeConstraints { make in
            make.centerY.equalTo(tipLabel)
            make.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        
        // 到账方式
        methodTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(amountCard.snp.bottom).offset(Theme.Spacing.xl)
            make.leading.equalToSuperview().inset(Theme.Spacing.m)
        }
        
        rebuildBankRowsConstraints()
        
        // 底部按钮
        confirmButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-Theme.Spacing.m)
            make.height.equalTo(48)
        }
    }
    
    /// 重建银行卡行约束（动态添加/删除银行卡后调用）
    private func rebuildBankRowsConstraints() {
        // 艺启余额
        walletMethodRow.snp.remakeConstraints { make in
            make.top.equalTo(methodTitleLabel.snp.bottom).offset(Theme.Spacing.m)
            make.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            make.height.equalTo(64)
        }
        
        // 银行卡行
        var previousView: UIView = walletMethodRow
        for row in bankRows {
            row.snp.remakeConstraints { make in
                make.top.equalTo(previousView.snp.bottom).offset(Theme.Spacing.m)
                make.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
                make.height.equalTo(64)
            }
            previousView = row
        }
        
        // 添加银行卡按钮
        addBankButton.snp.remakeConstraints { make in
            make.top.equalTo(previousView.snp.bottom).offset(Theme.Spacing.m)
            make.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            make.height.equalTo(44)
            make.bottom.equalToSuperview().offset(-Theme.Spacing.xl)
        }
    }
    
    private func setupActions() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    // MARK: - 银行卡加载
    
    private func loadBankAccounts() {
        StudioService.fetchBankAccounts { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let accounts):
                self.bankAccounts = accounts
                self.renderBankRows()
            case .failure:
                // 静默失败，银行卡列表为空
                break
            }
        }
    }
    
    /// 根据后端返回的银行卡列表，动态渲染银行卡行
    private func renderBankRows() {
        // 移除旧行
        bankRows.forEach { $0.removeFromSuperview() }
        bankRows.removeAll()
        
        // 为每张银行卡创建行
        for (index, account) in bankAccounts.enumerated() {
            let title = "\(account.bankName) (\(account.lastFourDigits))"
            let row = MethodRow(iconName: "bank_card", title: title, subtitle: "线下转账 · 手续费 0.1%", selected: false)
            row.onTap = { [weak self] in
                guard let self else { return }
                self.selectMethod("bank", accountId: account.accountId)
            }
            contentView.addSubview(row)
            bankRows.append(row)
        }
        
        // 如果有银行卡且是默认卡，自动选中
        if let defaultAccount = bankAccounts.first(where: { $0.isDefault == 1 }) {
            selectMethod("bank", accountId: defaultAccount.accountId)
        }
        
        rebuildBankRowsConstraints()
    }
    
    // MARK: - 逻辑
    
    private func selectMethod(_ method: String, accountId: String? = nil) {
        selectedMethod = method
        selectedAccountId = accountId
        walletMethodRow.setSelected(method == "wallet")
        bankRows.forEach { row in
            row.setSelected(false)
        }
        if method == "bank", let accountId = accountId {
            if let index = bankAccounts.firstIndex(where: { $0.accountId == accountId }) {
                bankRows[index].setSelected(true)
            }
        }
        // 切换收款方式时更新手续费显示
        updateFeeLabel()
    }
    
    @objc private func didTapWithdrawAll() {
        amountField.text = String(format: "%.2f", withdrawable)
        updateFeeLabel()
    }
    
    private func updateFeeLabel() {
        guard let amountText = amountField.text, let amount = Double(amountText), amount > 0 else {
            if selectedMethod == "wallet" {
                feeLabel.text = "免手续费"
                feeLabel.textColor = Theme.Color.success
            } else {
                feeLabel.text = "手续费：¥0.00"
                feeLabel.textColor = Theme.Color.warn
            }
            return
        }
        
        // 艺启余额：免手续费；银行卡：0.1%，最低0.1元
        if selectedMethod == "wallet" {
            feeLabel.text = "免手续费"
            feeLabel.textColor = Theme.Color.success
        } else {
            let fee = max(amount * 0.001, 0.1)
            feeLabel.text = String(format: "手续费：¥%.2f", fee)
            feeLabel.textColor = Theme.Color.warn
        }
    }
    
    @objc private func didTapAddBank() {
        let vc = AddBankCardViewController()
        vc.onAdded = { [weak self] in
            self?.loadBankAccounts()
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func didTapConfirm() {
        guard let text = amountField.text, let amount = Double(text), amount > 0 else {
            showToast("请输入正确的金额")
            return
        }
        if amount > withdrawable {
            showToast("金额超过可提现余额")
            return
        }
        if amount > 50000 {
            showToast("单笔记录不能超过 50,000 元")
            return
        }
        
        // 银行卡方式必须选中一张卡
        if selectedMethod == "bank" && selectedAccountId == nil {
            showToast("请选择收款银行卡")
            return
        }
        
        // 计算手续费：余额免手续费，银行卡0.1%
        let fee: Double
        if selectedMethod == "wallet" {
            fee = 0
        } else {
            fee = max(amount * 0.001, 0.1)
        }
        let actualAmount = amount - fee
        
        guard actualAmount > 0 else {
            showToast("金额扣除手续费后必须大于0")
            return
        }
        
        showLoading()
        MineService.requestWithdraw(
            amount: actualAmount,
            method: selectedMethod,
            account: selectedAccountId ?? ""
        ) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success:
                let msg = self.selectedMethod == "wallet"
                    ? "记录成功，余额已更新"
                    : "记录已提交，请线下完成转账"
                self.showToast(msg)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.navigationController?.popViewController(animated: true)
                    NotificationCenter.default.post(name: .walletBalanceUpdated, object: nil)
                }
            case .failure(let error):
                self.showToast(error.message)
            }
        }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - UITextFieldDelegate
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        
        let allowedCharacters = CharacterSet(charactersIn: "0123456789.")
        let characterSet = CharacterSet(charactersIn: string)
        guard allowedCharacters.isSuperset(of: characterSet) else { return false }
        
        if string == ".", currentText.contains(".") {
            return false
        }
        
        if let dotIndex = currentText.firstIndex(of: ".") {
            let decimalCount = currentText.distance(from: dotIndex, to: currentText.endIndex) - 1
            if decimalCount >= 2, !string.isEmpty {
                return false
            }
        }
        
        let isValid = updatedText.count <= 10
        
        if isValid {
            DispatchQueue.main.async {
                self.updateFeeLabel()
            }
        }
        
        return isValid
    }
}

// MARK: - 收款方式行组件

private final class MethodRow: UIView {
    var onTap: (() -> Void)?
    
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let radioView = RadioView()
    
    init(iconName: String, title: String, subtitle: String? = nil, selected: Bool) {
        super.init(frame: .zero)
        backgroundColor = Theme.Color.surface
        layer.cornerRadius = Theme.Radius.card
        layer.masksToBounds = true
        
        // 图标：使用 SF Symbol
        let icon: UIImage
        if iconName == "yiqi_wallet" {
            icon = UIImage(systemName: "wallet.pass.fill") ?? UIImage()
            iconView.tintColor = Theme.Color.brand
        } else if iconName == "bank_card" {
            icon = UIImage(systemName: "building.columns.fill") ?? UIImage()
            iconView.tintColor = Theme.Color.wood
        } else {
            icon = UIImage(systemName: "creditcard.fill") ?? UIImage()
            iconView.tintColor = Theme.Color.brand
        }
        iconView.image = icon
        iconView.contentMode = .scaleAspectFit
        addSubview(iconView)
        
        titleLabel.text = title
        titleLabel.font = .appBody(15)
        titleLabel.textColor = Theme.Color.ink
        addSubview(titleLabel)
        
        if let subtitle = subtitle {
            subtitleLabel.text = subtitle
            subtitleLabel.font = .appBody(11)
            subtitleLabel.textColor = Theme.Color.sub
            addSubview(subtitleLabel)
        }
        
        radioView.setSelected(selected)
        addSubview(radioView)
        
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Theme.Spacing.l)
            make.centerY.equalToSuperview()
            make.size.equalTo(32)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(Theme.Spacing.m)
            make.top.equalToSuperview().offset(subtitle != nil ? 14 : 0)
            if subtitle == nil {
                make.centerY.equalToSuperview()
            }
            make.trailing.lessThanOrEqualTo(radioView.snp.leading).offset(-Theme.Spacing.m)
        }
        
        if subtitle != nil {
            subtitleLabel.snp.makeConstraints { make in
                make.leading.equalTo(titleLabel)
                make.top.equalTo(titleLabel.snp.bottom).offset(2)
                make.trailing.lessThanOrEqualTo(radioView.snp.leading).offset(-Theme.Spacing.m)
            }
        }
        
        radioView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Theme.Spacing.l)
            make.centerY.equalToSuperview()
            make.size.equalTo(20)
        }
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        
        if selected {
            layer.borderWidth = 1.5
            layer.borderColor = Theme.Color.brand.cgColor
        } else {
            layer.borderWidth = 0
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setSelected(_ selected: Bool) {
        radioView.setSelected(selected)
        if selected {
            layer.borderWidth = 1.5
            layer.borderColor = Theme.Color.brand.cgColor
        } else {
            layer.borderWidth = 0
        }
    }
    
    @objc private func handleTap() {
        onTap?()
    }
}

// MARK: - 单选框组件

private final class RadioView: UIView {
    private let outerCircle = UIView()
    private let innerCircle = UIView()
    
    init() {
        super.init(frame: .zero)
        
        outerCircle.layer.borderWidth = 1.5
        outerCircle.layer.borderColor = Theme.Color.sub.cgColor
        outerCircle.layer.cornerRadius = 10
        addSubview(outerCircle)
        
        innerCircle.backgroundColor = Theme.Color.brand
        innerCircle.layer.cornerRadius = 6
        innerCircle.alpha = 0
        addSubview(innerCircle)
        
        outerCircle.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        innerCircle.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(12)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setSelected(_ selected: Bool) {
        if selected {
            outerCircle.layer.borderColor = Theme.Color.brand.cgColor
            innerCircle.alpha = 1
        } else {
            outerCircle.layer.borderColor = Theme.Color.sub.cgColor
            innerCircle.alpha = 0
        }
    }
}

// MARK: - 添加银行卡页面

final class AddBankCardViewController: BaseViewController {
    
    /// 绑定成功回调
    var onAdded: (() -> Void)?
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // 表单
    private let bankNameField = UITextField()
    private let accountNameField = UITextField()
    private let accountNoField = UITextField()
    
    private let submitButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "添加银行卡")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }
    
    private func setupUI() {
        view.backgroundColor = Theme.Color.bg
        
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // 开户行
        let bankCard = makeCard()
        contentView.addSubview(bankCard)
        
        let bankLabel = makeLabel("开户银行")
        bankCard.addSubview(bankLabel)
        
        bankNameField.placeholder = "如：招商银行"
        bankNameField.font = .appBody(15)
        bankNameField.textColor = Theme.Color.ink
        bankCard.addSubview(bankNameField)
        
        bankLabel.snp.makeConstraints { $0.top.leading.equalToSuperview().inset(Theme.Spacing.l) }
        bankNameField.snp.makeConstraints {
            $0.top.equalTo(bankLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.l)
        }
        
        // 持卡人
        let nameCard = makeCard()
        contentView.addSubview(nameCard)
        
        let nameLabel = makeLabel("持卡人姓名")
        nameCard.addSubview(nameLabel)
        
        accountNameField.placeholder = "与银行卡一致的真实姓名"
        accountNameField.font = .appBody(15)
        accountNameField.textColor = Theme.Color.ink
        nameCard.addSubview(accountNameField)
        
        nameLabel.snp.makeConstraints { $0.top.leading.equalToSuperview().inset(Theme.Spacing.l) }
        accountNameField.snp.makeConstraints {
            $0.top.equalTo(nameLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.l)
        }
        
        // 卡号
        let noCard = makeCard()
        contentView.addSubview(noCard)
        
        let noLabel = makeLabel("银行卡号")
        noCard.addSubview(noLabel)
        
        accountNoField.placeholder = "储蓄卡卡号"
        accountNoField.font = .appBody(15)
        accountNoField.textColor = Theme.Color.ink
        accountNoField.keyboardType = .numberPad
        noCard.addSubview(accountNoField)
        
        noLabel.snp.makeConstraints { $0.top.leading.equalToSuperview().inset(Theme.Spacing.l) }
        accountNoField.snp.makeConstraints {
            $0.top.equalTo(noLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.l)
        }
        
        // 提交按钮
        submitButton.setTitle("绑定银行卡", for: .normal)
        submitButton.titleLabel?.font = .appBody(16)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.backgroundColor = Theme.Color.brand
        submitButton.layer.cornerRadius = 24
        submitButton.addTarget(self, action: #selector(didTapSubmit), for: .touchUpInside)
        view.addSubview(submitButton)
        
        // 约束
        scrollView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(submitButton.snp.top).offset(-Theme.Spacing.m)
        }
        
        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.width.equalToSuperview()
        }
        
        bankCard.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }
        
        nameCard.snp.makeConstraints {
            $0.top.equalTo(bankCard.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }
        
        noCard.snp.makeConstraints {
            $0.top.equalTo(nameCard.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.xl)
        }
        
        submitButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-Theme.Spacing.m)
            $0.height.equalTo(48)
        }
        
        // 点击空白收起键盘
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    private func makeCard() -> UIView {
        let card = UIView()
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        card.layer.masksToBounds = true
        return card
    }
    
    private func makeLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .appBody(13)
        label.textColor = Theme.Color.sub
        return label
    }
    
    @objc private func didTapSubmit() {
        let bankName = bankNameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let accountName = accountNameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let accountNo = accountNoField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        
        guard !bankName.isEmpty else {
            showToast("请输入开户银行")
            return
        }
        guard !accountName.isEmpty else {
            showToast("请输入持卡人姓名")
            return
        }
        guard accountNo.count >= 10 else {
            showToast("请输入正确的银行卡号")
            return
        }
        
        showLoading()
        StudioService.addBankAccount(
            accountType: "bank",
            accountName: accountName,
            accountNo: accountNo,
            bankName: bankName
        ) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success:
                self.showToast("银行卡绑定成功")
                self.onAdded?()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self.navigationController?.popViewController(animated: true)
                }
            case .failure(let error):
                self.showToast(error.message)
            }
        }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}

// MARK: - Notification

extension Notification.Name {
    static let walletBalanceUpdated = Notification.Name("walletBalanceUpdated")
}
