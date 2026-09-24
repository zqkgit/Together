import UIKit
import SnapKit
import Kingfisher

/// 工作室端「订单详情」：展示订单信息、付款凭证、课时账本，支持确认/驳回/取消操作
final class StudioOrderDetailViewController: BaseViewController {

    // MARK: - 数据

    private let orderId: String
    private var order: StudioOrder?
    private var isOperating = false

    // MARK: - 视图

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let bottomBar = UIView()

    // 详情区
    private let statusCard = UIView()
    private let statusPill = PaddingLabel()
    private let orderNoLabel = UILabel()
    private let createdLabel = UILabel()

    // 学员/家长
    private let infoCard = UIView()

    // 课程/套餐
    private let courseCard = UIView()

    // 金额
    private let amountCard = UIView()

    // 付款记录
    private let paymentSection = UIView()

    // 课时账本
    private let balanceSection = UIView()

    // 退款记录
    private let refundSection = UIView()

    // 底部按钮
    private let actionStack = UIStackView()

    // MARK: - 初始化

    init(order: StudioOrder) {
        self.orderId = order.order_id
        self.order = order
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        if let order { bind(order) } else { loadDetail() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "订单详情")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    // MARK: - 布局

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg

        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-64)
        }

        stackView.axis = .vertical
        stackView.spacing = Theme.Spacing.m
        stackView.alignment = .fill
        scrollView.addSubview(stackView)
        stackView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.width.equalTo(scrollView).offset(-Theme.Spacing.m * 2)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.l)
        }

        // 状态卡
        buildStatusCard()
        stackView.addArrangedSubview(statusCard)

        // 学员/家长卡
        buildInfoCard()
        stackView.addArrangedSubview(infoCard)

        // 课程卡
        buildCourseCard()
        stackView.addArrangedSubview(courseCard)

        // 金额卡
        buildAmountCard()
        stackView.addArrangedSubview(amountCard)

        // 付款记录
        buildPaymentSection()
        stackView.addArrangedSubview(paymentSection)

        // 课时账本
        buildBalanceSection()
        stackView.addArrangedSubview(balanceSection)

        // 退款记录
        buildRefundSection()
        stackView.addArrangedSubview(refundSection)

        // 底部操作栏
        bottomBar.backgroundColor = Theme.Color.surface
        view.addSubview(bottomBar)
        bottomBar.snp.makeConstraints {
            $0.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
            $0.height.equalTo(64)
        }

        actionStack.axis = .horizontal
        actionStack.distribution = .fillEqually
        actionStack.spacing = Theme.Spacing.m
        bottomBar.addSubview(actionStack)
        actionStack.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
            $0.height.equalTo(44)
        }
    }

    // MARK: - 状态卡

    private func buildStatusCard() {
        statusCard.backgroundColor = Theme.Color.surface
        statusCard.layer.cornerRadius = Theme.Radius.card

        statusPill.font = .appSection(14)
        statusPill.layer.cornerRadius = 14
        statusPill.clipsToBounds = true
        statusPill.textInsets = UIEdgeInsets(top: 4, left: 14, bottom: 4, right: 14)
        statusCard.addSubview(statusPill)
        statusPill.snp.makeConstraints {
            $0.top.equalToSuperview().inset(Theme.Spacing.l)
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
        }

        orderNoLabel.font = .appBody(14)
        orderNoLabel.textColor = Theme.Color.ink
        statusCard.addSubview(orderNoLabel)
        orderNoLabel.snp.makeConstraints {
            $0.top.equalTo(statusPill.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.equalTo(statusPill)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        createdLabel.font = .appLabel(12)
        createdLabel.textColor = Theme.Color.muted
        statusCard.addSubview(createdLabel)
        createdLabel.snp.makeConstraints {
            $0.top.equalTo(orderNoLabel.snp.bottom).offset(4)
            $0.leading.equalTo(statusPill)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    // MARK: - 学员/家长卡

    private func buildInfoCard() {
        infoCard.backgroundColor = Theme.Color.surface
        infoCard.layer.cornerRadius = Theme.Radius.card
    }

    // MARK: - 课程卡

    private func buildCourseCard() {
        courseCard.backgroundColor = Theme.Color.surface
        courseCard.layer.cornerRadius = Theme.Radius.card
    }

    // MARK: - 金额卡

    private func buildAmountCard() {
        amountCard.backgroundColor = Theme.Color.surface
        amountCard.layer.cornerRadius = Theme.Radius.card
    }

    // MARK: - 付款记录

    private func buildPaymentSection() {
        paymentSection.backgroundColor = Theme.Color.surface
        paymentSection.layer.cornerRadius = Theme.Radius.card
    }

    // MARK: - 课时账本

    private func buildBalanceSection() {
        balanceSection.backgroundColor = Theme.Color.surface
        balanceSection.layer.cornerRadius = Theme.Radius.card
    }

    // MARK: - 退款记录

    private func buildRefundSection() {
        refundSection.backgroundColor = Theme.Color.surface
        refundSection.layer.cornerRadius = Theme.Radius.card
    }

    // MARK: - 数据绑定

    private func bind(_ o: StudioOrder) {
        self.order = o

        // 状态
        let cfg = statusConfig(o.orderStatus)
        statusPill.text = o.statusLabel
        statusPill.textColor = cfg.1
        statusPill.backgroundColor = cfg.2
        orderNoLabel.text = "订单号：\(o.order_no ?? "—")"
        createdLabel.text = "创建时间：\(o.createdDate)"

        // 学员/家长
        rebuildInfoCard(o)

        // 课程
        rebuildCourseCard(o)

        // 金额
        rebuildAmountCard(o)

        // 付款记录
        rebuildPaymentSection(o)

        // 课时账本
        rebuildBalanceSection(o)

        // 退款记录
        rebuildRefundSection(o)

        // 操作按钮
        rebuildActions(o)
    }

    // MARK: - 重建子视图

    private func rebuildInfoCard(_ o: StudioOrder) {
        infoCard.subviews.forEach { $0.removeFromSuperview() }
        let title = makeSectionTitle("学员信息")
        infoCard.addSubview(title)
        title.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        var lastView: UIView = title
        if let child = o.child {
            let row = makeInfoRow(label: "学员", value: child.displayName)
            infoCard.addSubview(row)
            row.snp.makeConstraints {
                $0.top.equalTo(lastView.snp.bottom).offset(Theme.Spacing.m)
                $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            }
            lastView = row
        }
        if let user = o.user {
            let row = makeInfoRow(label: "家长", value: user.displayName)
            infoCard.addSubview(row)
            row.snp.makeConstraints {
                $0.top.equalTo(lastView.snp.bottom).offset(Theme.Spacing.m)
                $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            }
            lastView = row
            if let phone = user.phone, !phone.isEmpty {
                let phoneRow = makeInfoRow(label: "手机", value: phone)
                infoCard.addSubview(phoneRow)
                phoneRow.snp.makeConstraints {
                    $0.top.equalTo(lastView.snp.bottom).offset(Theme.Spacing.m)
                    $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
                }
                lastView = phoneRow
            }
        }
        lastView.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    private func rebuildCourseCard(_ o: StudioOrder) {
        courseCard.subviews.forEach { $0.removeFromSuperview() }
        let title = makeSectionTitle("课程信息")
        courseCard.addSubview(title)
        title.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        var lastView: UIView = title
        let courseRow = makeInfoRow(label: "课程", value: o.courseTitle)
        courseCard.addSubview(courseRow)
        courseRow.snp.makeConstraints {
            $0.top.equalTo(lastView.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        lastView = courseRow

        if let pkg = o.package {
            let pkgRow = makeInfoRow(label: "套餐", value: pkg.displayName)
            courseCard.addSubview(pkgRow)
            pkgRow.snp.makeConstraints {
                $0.top.equalTo(lastView.snp.bottom).offset(Theme.Spacing.m)
                $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            }
            lastView = pkgRow
        }
        if let cls = o.`class` {
            let clsRow = makeInfoRow(label: "班级", value: cls.displayName)
            courseCard.addSubview(clsRow)
            clsRow.snp.makeConstraints {
                $0.top.equalTo(lastView.snp.bottom).offset(Theme.Spacing.m)
                $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            }
            lastView = clsRow
        }

        let lessonsRow = makeInfoRow(label: "课时", value: o.totalLessonsText)
        courseCard.addSubview(lessonsRow)
        lessonsRow.snp.makeConstraints {
            $0.top.equalTo(lastView.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        lastView = lessonsRow

        lastView.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    private func rebuildAmountCard(_ o: StudioOrder) {
        amountCard.subviews.forEach { $0.removeFromSuperview() }
        let title = makeSectionTitle("金额信息")
        amountCard.addSubview(title)
        title.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        var lastView: UIView = title
        var rows: [(String, String)] = [
            ("订单金额", o.totalAmountText),
            ("已收金额", o.paidAmountText),
        ]
        if (o.refund_amount ?? 0) > 0 {
            rows.append(("退款金额", o.refundAmountText))
        }
        if let method = o.pay_method_text, !method.isEmpty {
            rows.append(("支付方式", method))
        }
        if !o.sourceLabel.isEmpty {
            rows.append(("来源", o.sourceLabel))
        }

        for (label, value) in rows {
            let row = makeInfoRow(label: label, value: value)
            amountCard.addSubview(row)
            row.snp.makeConstraints {
                $0.top.equalTo(lastView.snp.bottom).offset(Theme.Spacing.m)
                $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            }
            lastView = row
        }
        lastView.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    private func rebuildPaymentSection(_ o: StudioOrder) {
        paymentSection.subviews.forEach { $0.removeFromSuperview() }
        let payments = o.payments ?? []
        if payments.isEmpty {
            paymentSection.isHidden = true
            return
        }
        paymentSection.isHidden = false

        let title = makeSectionTitle("付款记录")
        paymentSection.addSubview(title)
        title.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        var lastView: UIView = title
        for (i, p) in payments.enumerated() {
            let card = makePaymentCard(p, isFirst: i == 0)
            paymentSection.addSubview(card)
            card.snp.makeConstraints {
                $0.top.equalTo(lastView.snp.bottom).offset(Theme.Spacing.m)
                $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            }
            lastView = card
        }
        lastView.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    private func rebuildBalanceSection(_ o: StudioOrder) {
        balanceSection.subviews.forEach { $0.removeFromSuperview() }
        guard let b = o.balance else {
            balanceSection.isHidden = true
            return
        }
        balanceSection.isHidden = false

        let title = makeSectionTitle("课时账本")
        balanceSection.addSubview(title)
        title.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        var lastView: UIView = title
        let rows: [(String, String)] = [
            ("总课时", "\(b.total) 节"),
            ("已消耗", "\(b.consumed) 节"),
            ("已退回", "\(b.refunded) 节"),
            ("剩余", "\(b.remaining) 节"),
        ]
        for (label, value) in rows {
            let row = makeInfoRow(label: label, value: value, valueColor: label == "剩余" ? Theme.Color.brand : Theme.Color.ink)
            balanceSection.addSubview(row)
            row.snp.makeConstraints {
                $0.top.equalTo(lastView.snp.bottom).offset(Theme.Spacing.m)
                $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            }
            lastView = row
        }
        lastView.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    private func rebuildRefundSection(_ o: StudioOrder) {
        refundSection.subviews.forEach { $0.removeFromSuperview() }
        guard let refunds = o.refunds, !refunds.isEmpty else {
            refundSection.isHidden = true
            return
        }
        refundSection.isHidden = false

        let title = makeSectionTitle("退款记录")
        refundSection.addSubview(title)
        title.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        var lastView: UIView = title
        for (i, r) in refunds.enumerated() {
            let card = makeRefundCard(r, isFirst: i == 0)
            refundSection.addSubview(card)
            card.snp.makeConstraints {
                $0.top.equalTo(lastView.snp.bottom).offset(Theme.Spacing.m)
                $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            }
            lastView = card
        }
        lastView.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    private func makeRefundCard(_ r: StudioOrderRefund, isFirst: Bool) -> UIView {
        let card = UIView()
        if !isFirst {
            let sep = UIView()
            sep.backgroundColor = Theme.Color.surfaceAlt
            card.addSubview(sep)
            sep.snp.makeConstraints {
                $0.top.leading.trailing.equalToSuperview()
                $0.height.equalTo(0.5)
            }
        }

        // 状态 pill + 金额
        let statusLabel = PaddingLabel()
        statusLabel.font = .appLabel(11)
        statusLabel.layer.cornerRadius = 10
        statusLabel.clipsToBounds = true
        statusLabel.textInsets = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
        statusLabel.text = r.status_text ?? "未知"
        statusLabel.textColor = r.statusColor
        statusLabel.backgroundColor = r.statusTintColor
        card.addSubview(statusLabel)
        statusLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(isFirst ? 0 : 12)
            $0.leading.equalToSuperview()
        }

        let amountLabel = UILabel()
        amountLabel.text = "-\(r.amountText)"
        amountLabel.font = .appSection(16)
        amountLabel.textColor = Theme.Color.danger
        card.addSubview(amountLabel)
        amountLabel.snp.makeConstraints {
            $0.centerY.equalTo(statusLabel)
            $0.trailing.equalToSuperview()
        }

        // 退款原因
        if let reason = r.reason, !reason.isEmpty {
            let reasonLabel = UILabel()
            reasonLabel.font = .appLabel(12)
            reasonLabel.textColor = Theme.Color.sub
            reasonLabel.numberOfLines = 0
            reasonLabel.text = "原因：\(reason)"
            card.addSubview(reasonLabel)
            reasonLabel.snp.makeConstraints {
                $0.top.equalTo(statusLabel.snp.bottom).offset(6)
                $0.leading.trailing.equalToSuperview()
                $0.bottom.equalToSuperview()
            }
        } else {
            // 无原因时 statusLabel 下方就是 bottom
            statusLabel.snp.makeConstraints {
                $0.bottom.equalToSuperview()
            }
        }

        // 退款课时
        if let requested = r.requested_lessons, requested > 0 {
            let lessonsLabel = UILabel()
            lessonsLabel.font = .appLabel(12)
            lessonsLabel.textColor = Theme.Color.muted
            lessonsLabel.text = "退 \(requested) 节"
            card.addSubview(lessonsLabel)
            lessonsLabel.snp.makeConstraints {
                $0.centerY.equalTo(statusLabel)
                $0.leading.equalTo(statusLabel.snp.trailing).offset(8)
            }
        }

        return card
    }

    private func rebuildActions(_ o: StudioOrder) {
        actionStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // 待收款(status=0)：无凭证时可确认收款/取消；有待确认凭证时可确认/驳回
        if o.isPending {
            if o.hasPendingPayment {
                actionStack.addArrangedSubview(makeButton(title: "驳回凭证", style: .outline, action: #selector(tapReject)))
                actionStack.addArrangedSubview(makeButton(title: "确认收款", style: .primary, action: #selector(tapConfirm)))
            } else {
                actionStack.addArrangedSubview(makeButton(title: "确认收款", style: .primary, action: #selector(tapConfirmNoVoucher)))
                actionStack.addArrangedSubview(makeButton(title: "取消订单", style: .danger, action: #selector(tapCancel)))
            }
        }
        // 待确认收款(status=1)：家长已上传凭证，可确认/驳回/取消
        else if o.isPaymentReview {
            actionStack.addArrangedSubview(makeButton(title: "驳回凭证", style: .outline, action: #selector(tapReject)))
            actionStack.addArrangedSubview(makeButton(title: "确认收款", style: .primary, action: #selector(tapConfirm)))
            actionStack.addArrangedSubview(makeButton(title: "取消订单", style: .danger, action: #selector(tapCancel)))
        }
    }

    // MARK: - 操作

    @objc private func tapConfirm() {
        guard order != nil else { return }
        showConfirmDialog()
    }

    @objc private func tapConfirmNoVoucher() {
        // 待收款但无凭证时，工作室直接登记收款
        showConfirmDialog()
    }

    @objc private func tapReject() {
        guard let o = order, let payment = o.pendingPayment else { return }
        showRejectAlert(payment: payment)
    }

    @objc private func tapCancel() {
        guard let o = order else { return }
        ThemeAlertView.show(
            title: "取消订单",
            message: "确认取消此订单？取消后不可恢复。",
            confirmTitle: "确认取消"
        ) { [weak self] in
            self?.performCancel()
        }
    }

    // MARK: - 确认收款弹窗

    private func showConfirmDialog() {
        ThemeInputAlertView.show(
            title: "确认收款",
            placeholder: "备注（选填）",
            maxCount: 200,
            confirmTitle: "确认"
        ) { [weak self] note in
            self?.performConfirm(note: note)
        }
    }

    // MARK: - 驳回弹窗

    private func showRejectAlert(payment: StudioPayment) {
        ThemeInputAlertView.show(
            title: "驳回凭证",
            placeholder: "请输入驳回原因",
            maxCount: 200,
            confirmTitle: "驳回"
        ) { [weak self] reason in
            guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self?.showToast("请输入驳回原因")
                return
            }
            self?.performReject(reason: reason)
        }
    }

    // MARK: - 网络请求

    private func loadDetail() {
        showLoading()
        StudioService.fetchOrderDetail(orderId: orderId) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success(let o):
                if let o { self.bind(o) }
            case .failure(let e):
                self.showToast(e.message ?? "加载失败")
            }
        }
    }

    private func performConfirm(note: String?) {
        guard !isOperating else { return }
        isOperating = true
        showLoading()
        StudioService.confirmPayment(
            orderId: orderId,
            payMethod: nil,
            note: note
        ) { [weak self] result in
            guard let self else { return }
            self.isOperating = false
            self.hideLoading()
            switch result {
            case .success(let o):
                self.showToast("确认成功")
                if let o { self.bind(o) }
            case .failure(let e):
                self.showToast(e.message ?? "操作失败")
            }
        }
    }

    private func performReject(reason: String) {
        guard !isOperating else { return }
        isOperating = true
        showLoading()
        StudioService.rejectPayment(orderId: orderId, reason: reason) { [weak self] result in
            guard let self else { return }
            self.isOperating = false
            self.hideLoading()
            switch result {
            case .success(let o):
                self.showToast("已驳回")
                if let o { self.bind(o) }
            case .failure(let e):
                self.showToast(e.message ?? "操作失败")
            }
        }
    }

    private func performCancel() {
        guard !isOperating else { return }
        isOperating = true
        showLoading()
        StudioService.cancelOrder(orderId: orderId) { [weak self] result in
            guard let self else { return }
            self.isOperating = false
            self.hideLoading()
            switch result {
            case .success(let o):
                self.showToast("订单已取消")
                if let o { self.bind(o) }
            case .failure(let e):
                self.showToast(e.message ?? "操作失败")
            }
        }
    }

    // MARK: - 辅助

    private func statusConfig(_ status: StudioOrderStatus) -> (String, UIColor, UIColor) {
        switch status {
        case .pending:        return ("待收款", Theme.Color.warn, Theme.Color.warnTint)
        case .paymentReview:  return ("待确认收款", Theme.Color.warn, Theme.Color.warnTint)
        case .collected:      return ("已收款", Theme.Color.success, Theme.Color.successTint)
        case .refundReview:   return ("退款审核中", Theme.Color.warn, Theme.Color.warnTint)
        case .refundConfirm:  return ("待确认退款", Theme.Color.warn, Theme.Color.warnTint)
        case .refunded:       return ("已退款", Theme.Color.danger, Theme.Color.dangerTint)
        case .cancelled:      return ("已取消", Theme.Color.muted, Theme.Color.surfaceAlt)
        }
    }

    private func makeSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .appSection(15)
        label.textColor = Theme.Color.ink
        return label
    }

    private func makeInfoRow(label: String, value: String, valueColor: UIColor = Theme.Color.ink) -> UIView {
        let row = UIView()
        let l = UILabel()
        l.text = label
        l.font = .appBody(14)
        l.textColor = Theme.Color.sub
        let v = UILabel()
        v.text = value
        v.font = .appBody(14)
        v.textColor = valueColor
        v.textAlignment = .right
        row.addSubview(l)
        row.addSubview(v)
        l.snp.makeConstraints {
            $0.leading.centerY.equalToSuperview()
        }
        v.snp.makeConstraints {
            $0.trailing.centerY.equalToSuperview()
            $0.leading.greaterThanOrEqualTo(l.snp.trailing).offset(8)
        }
        row.snp.makeConstraints {
            $0.height.equalTo(24)
        }
        return row
    }

    private func makePaymentCard(_ p: StudioPayment, isFirst: Bool) -> UIView {
        let card = UIView()
        if !isFirst {
            let sep = UIView()
            sep.backgroundColor = Theme.Color.surfaceAlt
            card.addSubview(sep)
            sep.snp.makeConstraints {
                $0.top.leading.trailing.equalToSuperview()
                $0.height.equalTo(0.5)
            }
        }

        // 状态 + 金额
        let statusLabel = PaddingLabel()
        statusLabel.font = .appLabel(11)
        statusLabel.layer.cornerRadius = 10
        statusLabel.clipsToBounds = true
        statusLabel.textInsets = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
        if p.isPending {
            statusLabel.text = "待确认"
            statusLabel.textColor = Theme.Color.warn
            statusLabel.backgroundColor = Theme.Color.warnTint
        } else if p.isConfirmed {
            statusLabel.text = "已确认"
            statusLabel.textColor = Theme.Color.success
            statusLabel.backgroundColor = Theme.Color.successTint
        } else {
            statusLabel.text = "已驳回"
            statusLabel.textColor = Theme.Color.danger
            statusLabel.backgroundColor = Theme.Color.dangerTint
        }
        card.addSubview(statusLabel)
        statusLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(isFirst ? 0 : 12)
            $0.leading.equalToSuperview()
        }

        let amountLabel = UILabel()
        amountLabel.text = p.amountText
        amountLabel.font = .appSection(16)
        amountLabel.textColor = Theme.Color.clay
        card.addSubview(amountLabel)
        amountLabel.snp.makeConstraints {
            $0.centerY.equalTo(statusLabel)
            $0.trailing.equalToSuperview()
        }

        // 方式 + 时间
        let metaLabel = UILabel()
        metaLabel.text = "\(p.methodText)  \(p.paid_at?.prefix(16) ?? p.created_at?.prefix(16) ?? "")"
        metaLabel.font = .appLabel(12)
        metaLabel.textColor = Theme.Color.muted
        card.addSubview(metaLabel)
        metaLabel.snp.makeConstraints {
            $0.top.equalTo(statusLabel.snp.bottom).offset(4)
            $0.leading.equalToSuperview()
        }

        // 凭证图片
        if p.hasVoucher {
            let imgStack = UIStackView()
            imgStack.axis = .horizontal
            imgStack.spacing = 6
            for (idx, url) in p.voucherURLs.enumerated() {
                let iv = UIImageView()
                iv.contentMode = .scaleAspectFill
                iv.clipsToBounds = true
                iv.layer.cornerRadius = 4
                iv.kf.setImage(with: URL(string: url), placeholder: UIImage(systemName: "photo"))
                iv.tag = idx
                iv.isUserInteractionEnabled = true
                let tap = UITapGestureRecognizer(target: self, action: #selector(previewVoucher(_:)))
                iv.addGestureRecognizer(tap)
                imgStack.addArrangedSubview(iv)
                iv.snp.makeConstraints { $0.width.height.equalTo(60) }
            }
            card.addSubview(imgStack)
            imgStack.snp.makeConstraints {
                $0.top.equalTo(metaLabel.snp.bottom).offset(8)
                $0.leading.trailing.equalToSuperview()
                $0.bottom.equalToSuperview()
            }
        } else {
            metaLabel.snp.makeConstraints {
                $0.bottom.equalToSuperview()
            }
        }

        // 驳回原因
        if p.isRejected, !p.rejectText.isEmpty {
            let rejectLabel = UILabel()
            rejectLabel.text = "驳回原因：\(p.rejectText)"
            rejectLabel.font = .appLabel(12)
            rejectLabel.textColor = Theme.Color.danger
            rejectLabel.numberOfLines = 0
            card.addSubview(rejectLabel)
            rejectLabel.snp.makeConstraints {
                if p.hasVoucher {
                    $0.top.equalTo(card.subviews.filter { $0 is UIStackView }.first!.snp.bottom).offset(6)
                } else {
                    $0.top.equalTo(metaLabel.snp.bottom).offset(6)
                }
                $0.leading.trailing.equalToSuperview()
                $0.bottom.equalToSuperview()
            }
        }

        // 备注
        if !p.noteText.isEmpty {
            let noteLabel = UILabel()
            noteLabel.text = "备注：\(p.noteText)"
            noteLabel.font = .appLabel(12)
            noteLabel.textColor = Theme.Color.sub
            noteLabel.numberOfLines = 0
            card.addSubview(noteLabel)
            // 约束放在最后
        }

        return card
    }

    @objc private func previewVoucher(_ gesture: UITapGestureRecognizer) {
        guard let iv = gesture.view as? UIImageView,
              iv.image != nil else { return }
        // 简单全屏预览
        let overlay = UIView(frame: UIScreen.main.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        overlay.alpha = 0
        let fullIV = UIImageView(image: iv.image)
        fullIV.contentMode = .scaleAspectFit
        fullIV.frame = overlay.bounds
        overlay.addSubview(fullIV)
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissPreview(_:)))
        overlay.addGestureRecognizer(tap)
        overlay.tag = 999
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first else { return }
        window.addSubview(overlay)
        UIView.animate(withDuration: 0.2) { overlay.alpha = 1 }
    }

    @objc private func dismissPreview(_ gesture: UITapGestureRecognizer) {
        guard let overlay = gesture.view else { return }
        UIView.animate(withDuration: 0.2, animations: { overlay.alpha = 0 }) { _ in
            overlay.removeFromSuperview()
        }
    }

    private enum ButtonStyle { case primary, outline, danger }

    private func makeButton(title: String, style: ButtonStyle, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .appBody(15)
        btn.layer.cornerRadius = 22
        btn.addTarget(self, action: action, for: .touchUpInside)
        switch style {
        case .primary:
            btn.backgroundColor = Theme.Color.brand
            btn.setTitleColor(.white, for: .normal)
        case .outline:
            btn.backgroundColor = .clear
            btn.layer.borderWidth = 1
            btn.layer.borderColor = Theme.Color.brand.cgColor
            btn.setTitleColor(Theme.Color.brand, for: .normal)
        case .danger:
            btn.backgroundColor = .clear
            btn.layer.borderWidth = 1
            btn.layer.borderColor = Theme.Color.danger.cgColor
            btn.setTitleColor(Theme.Color.danger, for: .normal)
        }
        return btn
    }
}