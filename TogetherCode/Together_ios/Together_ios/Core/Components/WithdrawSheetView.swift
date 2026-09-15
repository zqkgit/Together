import UIKit
import SnapKit

/// 提现弹层：金额输入 + 提现方式选择 + 确认
/// 底部弹出，遮罩点击取消；符合主题风（米白卡片 + 品牌绿胶囊按钮）
final class WithdrawSheetView: UIView, UITextFieldDelegate {

    typealias WithdrawHandler = (_ amount: Double, _ method: String, _ account: String) -> Void

    private let backdropView = UIView()
    private let sheet = UIView()
    private let amountField = UITextField()
    private let wechatChip = MethodChip(title: "微信")
    private let bankChip = MethodChip(title: "银行卡")
    private var selectedMethod = "wechat"
    private var balance: Double = 0
    private var handler: WithdrawHandler?

    // MARK: - 展示

    static func show(balance: Double, handler: @escaping WithdrawHandler) {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else { return }
        let sheetView = WithdrawSheetView(balance: balance, handler: handler)
        sheetView.frame = window.bounds
        window.addSubview(sheetView)
        sheetView.present()
    }

    private init(balance: Double, handler: @escaping WithdrawHandler) {
        super.init(frame: .zero)
        self.balance = balance
        self.handler = handler
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        backgroundColor = .clear

        backdropView.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        backdropView.alpha = 0
        addSubview(backdropView)
        backdropView.snp.makeConstraints { $0.edges.equalToSuperview() }
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSheet))
        backdropView.addGestureRecognizer(tap)

        sheet.backgroundColor = Theme.Color.bg
        sheet.layer.cornerRadius = Theme.Radius.card
        sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        addSubview(sheet)
        sheet.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
        }

        // 标题
        let titleLabel = UILabel()
        titleLabel.text = "申请提现"
        titleLabel.font = .appSection(17)
        titleLabel.textColor = Theme.Color.ink
        sheet.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.xl)
            $0.centerX.equalToSuperview()
        }

        // 可提现
        let balanceLabel = UILabel()
        balanceLabel.text = String(format: "可提现 ¥%.2f", balance)
        balanceLabel.font = .appBody(13)
        balanceLabel.textColor = Theme.Color.sub
        sheet.addSubview(balanceLabel)
        balanceLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.centerX.equalToSuperview()
        }

        // 金额输入
        amountField.placeholder = "请输入提现金额"
        amountField.font = .appBody(16)
        amountField.textColor = Theme.Color.ink
        amountField.keyboardType = .decimalPad
        amountField.delegate = self
        amountField.textAlignment = .center
        amountField.layer.cornerRadius = Theme.Radius.input
        amountField.backgroundColor = Theme.Color.surface
        sheet.addSubview(amountField)
        amountField.snp.makeConstraints {
            $0.top.equalTo(balanceLabel.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(48)
        }

        // 方式选择
        let methodLabel = UILabel()
        methodLabel.text = "提现方式"
        methodLabel.font = .appBody(13)
        methodLabel.textColor = Theme.Color.sub
        sheet.addSubview(methodLabel)
        methodLabel.snp.makeConstraints {
            $0.top.equalTo(amountField.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
        }

        let methodStack = UIStackView()
        methodStack.axis = .horizontal
        methodStack.spacing = Theme.Spacing.m
        sheet.addSubview(methodStack)
        methodStack.snp.makeConstraints {
            $0.top.equalTo(methodLabel.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
        }
        wechatChip.onTap = { [weak self] in self?.selectMethod("wechat") }
        bankChip.onTap = { [weak self] in self?.selectMethod("bank") }
        methodStack.addArrangedSubview(wechatChip)
        methodStack.addArrangedSubview(bankChip)
        selectMethod("wechat")

        // 确认
        let confirmButton = UIButton(type: .system)
        confirmButton.setTitle("确认提现", for: .normal)
        confirmButton.titleLabel?.font = .appBody(15)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.backgroundColor = Theme.Color.brand
        confirmButton.layer.cornerRadius = 22
        confirmButton.addTarget(self, action: #selector(didTapConfirm), for: .touchUpInside)
        sheet.addSubview(confirmButton)
        confirmButton.snp.makeConstraints {
            $0.top.equalTo(methodStack.snp.bottom).offset(Theme.Spacing.xl)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(44)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.xxxl)
        }
    }

    private func selectMethod(_ method: String) {
        selectedMethod = method
        wechatChip.setSelected(method == "wechat")
        bankChip.setSelected(method == "bank")
    }

    @objc private func didTapConfirm() {
        guard let text = amountField.text, let amount = Double(text), amount > 0 else {
            showToast("请输入正确的提现金额")
            return
        }
        if amount > balance {
            showToast("金额超过可提现余额")
            return
        }
        handler?(amount, selectedMethod, "")
        dismissSheet()
    }

    @objc private func dismissSheet() {
        amountField.resignFirstResponder()
        UIView.animate(withDuration: 0.25, animations: {
            self.sheet.transform = CGAffineTransform(translationX: 0, y: 420)
            self.backdropView.alpha = 0
        }) { _ in
            self.removeFromSuperview()
        }
    }

    private func present() {
        sheet.transform = CGAffineTransform(translationX: 0, y: 420)
        UIView.animate(withDuration: 0.3) {
            self.sheet.transform = .identity
            self.backdropView.alpha = 1
        }
        amountField.becomeFirstResponder()
    }

    private func showToast(_ message: String) {
        let toast = UILabel()
        toast.text = message
        toast.font = .appBody(13)
        toast.textColor = .white
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        toast.layer.cornerRadius = 10
        toast.clipsToBounds = true
        toast.textAlignment = .center
        addSubview(toast)
        toast.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalTo(sheet.snp.top).offset(-Theme.Spacing.xl)
            $0.width.equalTo(220)
            $0.height.equalTo(36)
        }
        UIView.animate(withDuration: 0.25, delay: 1.4, options: [], animations: {
            toast.alpha = 0
        }) { _ in
            toast.removeFromSuperview()
        }
    }
}

/// 提现方式 chip
private final class MethodChip: UIView {
    var onTap: (() -> Void)?

    private let label = UILabel()

    init(title: String) {
        super.init(frame: .zero)
        label.text = title
        label.font = .appBody(14)
        label.textAlignment = .center
        addSubview(label)
        label.snp.makeConstraints { $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 18, bottom: 8, right: 18)) }
        layer.cornerRadius = 16
        backgroundColor = Theme.Color.surfaceAlt
        setSelected(false)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handleTap() { onTap?() }

    func setSelected(_ selected: Bool) {
        if selected {
            backgroundColor = Theme.Color.brandSoft
            label.textColor = Theme.Color.brand
            label.font = .systemFont(ofSize: 14, weight: .semibold)
        } else {
            backgroundColor = Theme.Color.surfaceAlt
            label.textColor = Theme.Color.sub
            label.font = .appBody(14)
        }
    }
}
