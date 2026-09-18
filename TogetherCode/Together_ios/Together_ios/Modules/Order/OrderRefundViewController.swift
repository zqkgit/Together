import UIKit
import SnapKit

/// 申请退款表单页（对齐小程序 refund 页：退款课时 + 原因 + 退款说明）
final class OrderRefundViewController: BaseViewController {

    private let order: OrderItem
    private let onSuccess: (() -> Void)?

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // 课时
    private let lessonsField = UITextField()
    private let remainingLabel = UILabel()

    // 原因（2x2 网格，选中品牌绿底白字）
    private let reasons = ["课程不适合孩子", "时间安排冲突", "工作室原因", "其他"]
    private var reasonButtons: [UIButton] = []
    private var selectedReason = ""
    private let customReasonField = UITextField()
    private let customReasonWrap = UIView()

    private let submitButton = UIButton(type: .system)
    private var submitting = false

    init(order: OrderItem, onSuccess: (() -> Void)? = nil) {
        self.order = order
        self.onSuccess = onSuccess
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureImmersiveNav(title: "申请退款")
        setupUI()
    }

    private var remainingLessons: Int {
        max(0, order.remaining_lessons ?? order.total_lessons ?? 0)
    }

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg

        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(76)
        }
        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.width.equalToSuperview()
        }

        // 1. 订单卡
        let orderCard = makeCard()
        contentView.addSubview(orderCard)
        orderCard.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        let courseTitle = UILabel()
        courseTitle.font = .appSection(17)
        courseTitle.textColor = Theme.Color.ink
        courseTitle.numberOfLines = 2
        courseTitle.text = order.courseTitleWithLessons
        orderCard.addSubview(courseTitle)
        courseTitle.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        let orderSub = UILabel()
        orderSub.font = .appLabel(13)
        orderSub.textColor = Theme.Color.sub
        var subParts = [order.studioTeacherText]
        if let childName = order.childName { subParts.append(childName) }
        orderSub.text = subParts.joined(separator: " · ")
        orderCard.addSubview(orderSub)
        orderSub.snp.makeConstraints {
            $0.top.equalTo(courseTitle.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        let orderNo = UILabel()
        orderNo.font = .appLabel(12)
        orderNo.textColor = Theme.Color.muted
        orderNo.text = "订单号 \(order.order_no ?? "-")"
        orderCard.addSubview(orderNo)
        orderNo.snp.makeConstraints {
            $0.top.equalTo(orderSub.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }

        // 2. 表单卡：课时 + 原因
        let formCard = makeCard()
        contentView.addSubview(formCard)
        formCard.snp.makeConstraints {
            $0.top.equalTo(orderCard.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        let lessonsLabel = makeLabel("退款课时")
        formCard.addSubview(lessonsLabel)
        lessonsLabel.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        let lessonsRow = UIView()
        formCard.addSubview(lessonsRow)
        lessonsRow.snp.makeConstraints {
            $0.top.equalTo(lessonsLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(44)
        }

        lessonsField.font = .appBody(15)
        lessonsField.textColor = Theme.Color.ink
        lessonsField.keyboardType = .numberPad
        lessonsField.text = String(remainingLessons)
        lessonsField.backgroundColor = Theme.Color.bg
        lessonsField.layer.cornerRadius = Theme.Radius.input
        lessonsField.layer.borderWidth = 1
        lessonsField.layer.borderColor = Theme.Color.line.cgColor
        lessonsField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 44))
        lessonsField.leftViewMode = .always
        lessonsRow.addSubview(lessonsField)
        lessonsField.snp.makeConstraints {
            $0.top.bottom.leading.equalToSuperview()
            $0.width.equalTo(120)
        }

        remainingLabel.font = .appLabel(13)
        remainingLabel.textColor = Theme.Color.sub
        remainingLabel.text = "课时（剩余 \(remainingLessons) 课时）"
        lessonsRow.addSubview(remainingLabel)
        remainingLabel.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.leading.equalTo(lessonsField.snp.trailing).offset(Theme.Spacing.s)
            $0.trailing.lessThanOrEqualToSuperview()
        }

        let reasonLabel = makeLabel("退款原因")
        formCard.addSubview(reasonLabel)
        reasonLabel.snp.makeConstraints {
            $0.top.equalTo(lessonsRow.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        let reasonGrid = UIStackView()
        reasonGrid.axis = .vertical
        reasonGrid.spacing = Theme.Spacing.s
        formCard.addSubview(reasonGrid)
        reasonGrid.snp.makeConstraints {
            $0.top.equalTo(reasonLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        for row in 0..<2 {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = Theme.Spacing.s
            rowStack.distribution = .fillEqually
            reasonGrid.addArrangedSubview(rowStack)
            for col in 0..<2 {
                let index = row * 2 + col
                let btn = UIButton(type: .custom)
                btn.setTitle(reasons[index], for: .normal)
                btn.titleLabel?.font = .appLabel(13)
                btn.tag = index
                btn.layer.cornerRadius = 15
                btn.addTarget(self, action: #selector(didSelectReason(_:)), for: .touchUpInside)
                rowStack.addArrangedSubview(btn)
                reasonButtons.append(btn)
            }
        }
        // 默认不选原因
        selectedReason = ""
        applyReasonSelection()

        // 自定义原因（仅「其他」时显示）
        customReasonWrap.isHidden = true
        formCard.addSubview(customReasonWrap)
        customReasonWrap.snp.makeConstraints {
            $0.top.equalTo(reasonGrid.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }

        customReasonField.font = .appBody(14)
        customReasonField.textColor = Theme.Color.ink
        customReasonField.placeholder = "请说明退款原因"
        customReasonField.backgroundColor = Theme.Color.bg
        customReasonField.layer.cornerRadius = Theme.Radius.input
        customReasonField.layer.borderWidth = 1
        customReasonField.layer.borderColor = Theme.Color.line.cgColor
        customReasonField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 44))
        customReasonField.leftViewMode = .always
        customReasonWrap.addSubview(customReasonField)
        customReasonField.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.height.equalTo(44)
        }

        // 3. 退款说明卡
        let tipsCard = makeCard()
        contentView.addSubview(tipsCard)
        tipsCard.snp.makeConstraints {
            $0.top.equalTo(formCard.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        let tipTitle = makeLabel("退款说明")
        tipTitle.font = .appSection(15)
        tipTitle.textColor = Theme.Color.ink
        tipsCard.addSubview(tipTitle)
        tipTitle.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        let tip1 = makeLabel("· 按剩余课时比例退回实付金额")
        let tip2 = makeLabel("· 提交后由工作室审核，审核通过后原路退回")
        tipsCard.addSubview(tip1)
        tip1.snp.makeConstraints {
            $0.top.equalTo(tipTitle.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        tipsCard.addSubview(tip2)
        tip2.snp.makeConstraints {
            $0.top.equalTo(tip1.snp.bottom).offset(Theme.Spacing.xs)
            $0.leading.trailing.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }

        contentView.snp.makeConstraints {
            $0.bottom.equalTo(tipsCard.snp.bottom).offset(Theme.Spacing.l)
        }

        // 4. 底部提交按钮
        submitButton.setTitle("提交退款申请", for: .normal)
        submitButton.titleLabel?.font = .appBody(15)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.backgroundColor = Theme.Color.brand
        submitButton.layer.cornerRadius = 22
        submitButton.addTarget(self, action: #selector(didTapSubmit), for: .touchUpInside)
        view.addSubview(submitButton)
        submitButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(Theme.Spacing.m)
            $0.height.equalTo(44)
        }
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
        label.font = .appLabel(13)
        label.textColor = Theme.Color.sub
        label.text = text
        label.numberOfLines = 0
        return label
    }

    private func applyReasonSelection() {
        for (i, btn) in reasonButtons.enumerated() {
            let selected = reasons[i] == selectedReason
            btn.backgroundColor = selected ? Theme.Color.brand : Theme.Color.surfaceAlt
            btn.setTitleColor(selected ? .white : Theme.Color.sub, for: .normal)
            btn.layer.borderWidth = selected ? 0 : 1
            btn.layer.borderColor = Theme.Color.line.cgColor
        }
        customReasonWrap.isHidden = selectedReason != "其他"
        if customReasonWrap.isHidden {
            customReasonField.resignFirstResponder()
        }
    }

    @objc private func didSelectReason(_ sender: UIButton) {
        selectedReason = reasons[sender.tag]
        applyReasonSelection()
    }

    @objc private func didTapSubmit() {
        guard !submitting else { return }
        let lessons = Int(lessonsField.text ?? "") ?? 0
        guard lessons > 0 else {
            showToast("请输入退款课时数")
            return
        }
        guard lessons <= remainingLessons else {
            showToast("最多可退 \(remainingLessons) 课时")
            return
        }
        guard !selectedReason.isEmpty else {
            showToast("请选择退款原因")
            return
        }
        let reason: String?
        if selectedReason == "其他" {
            let custom = customReasonField.text?.trimmingCharacters(in: .whitespaces) ?? ""
            reason = custom.isEmpty ? "其他" : custom
        } else {
            reason = selectedReason
        }

        submitting = true
        submitButton.alpha = 0.6
        showLoading()
        OrderService.requestRefund(
            orderId: order.order_id ?? "",
            lessons: lessons,
            reason: reason
        ) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            self.submitting = false
            self.submitButton.alpha = 1
            switch result {
            case .success:
                self.showToast("退款申请已提交")
                self.onSuccess?()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self.navigationController?.popViewController(animated: true)
                }
            case .failure(let error):
                self.showToast(error.message ?? "提交失败")
            }
        }
    }
}
