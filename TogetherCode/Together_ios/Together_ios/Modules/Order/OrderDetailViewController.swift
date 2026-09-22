import UIKit
import SnapKit
import Kingfisher

/// 订单详情（家长端 · 线下收款模式）
/// 分组：状态卡 / 课程信息 / 订单信息 / 付款记录 / 课时进度
/// 平台不经手资金：待付款 → 家长线下付款并上传凭证 → 工作室确认收款 → 发课时
final class OrderDetailViewController: BaseViewController {

    private let orderId: String
    private var order: OrderItem?

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let bottomBar = UIView()
    private let primaryButton = UIButton(type: .system)
    private let secondaryButton = UIButton(type: .system)

    private enum Section {
        case status, course, info, payments, progress
    }
    private var sections: [Section] = []
    private var statusRow: RowType?
    private var courseRow: RowType?
    private var infoRows: [RowType] = []
    private var progressRows: [RowType] = []
    private var paymentItems: [PaymentItem] = []

    enum RowType {
        case status(title: String, desc: String, tone: Tone)
        case course(title: String, subtitle: String)
        case row(title: String, value: String, brand: Bool)
    }

    enum Tone { case brand, warn, danger, muted }

    init(orderId: String) {
        self.orderId = orderId
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureImmersiveNav(title: "订单详情")
        setupBottomBar()
        setupTableView()
        loadData()
    }

    // MARK: - UI

    private func setupTableView() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.alwaysBounceVertical = true
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(OrderDetailCell.self, forCellReuseIdentifier: OrderDetailCell.reuseID)
        tableView.register(PaymentRecordCell.self, forCellReuseIdentifier: PaymentRecordCell.reuseID)
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension
        tableView.contentInset = UIEdgeInsets(top: Theme.Spacing.s, left: 0, bottom: 100, right: 0)
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            $0.bottom.equalTo(bottomBar.snp.top)
        }
    }

    private func setupBottomBar() {
        bottomBar.backgroundColor = Theme.Color.surface
        bottomBar.layer.shadowColor = UIColor.black.withAlphaComponent(0.06).cgColor
        bottomBar.layer.shadowOffset = CGSize(width: 0, height: -2)
        bottomBar.layer.shadowOpacity = 1
        bottomBar.layer.shadowRadius = 8
        view.addSubview(bottomBar)
        bottomBar.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.top.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-64)
        }

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Theme.Spacing.m
        stack.distribution = .fillEqually
        bottomBar.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(44)
        }

        secondaryButton.titleLabel?.font = .appBody(15)
        secondaryButton.setTitleColor(Theme.Color.ink, for: .normal)
        secondaryButton.backgroundColor = Theme.Color.surfaceAlt
        secondaryButton.layer.cornerRadius = 22
        secondaryButton.addTarget(self, action: #selector(didTapSecondary), for: .touchUpInside)

        primaryButton.titleLabel?.font = .appBody(15)
        primaryButton.setTitleColor(.white, for: .normal)
        primaryButton.backgroundColor = Theme.Color.brand
        primaryButton.layer.cornerRadius = 22
        primaryButton.addTarget(self, action: #selector(didTapPrimary), for: .touchUpInside)

        stack.addArrangedSubview(secondaryButton)
        stack.addArrangedSubview(primaryButton)
    }

    // MARK: - Data

    private func loadData() {
        showLoading()
        OrderService.fetchOrderDetail(orderId: orderId) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success(let order):
                self.order = order
                self.render(order)
            case .failure(let error):
                self.showToast(error.message ?? "加载失败")
            }
        }
    }

    private func render(_ order: OrderItem) {
        statusRow = nil
        courseRow = nil
        infoRows.removeAll()
        progressRows.removeAll()
        paymentItems = order.payments ?? []

        // 状态卡（退款聚合优先）
        let statusTitle: String
        let statusDesc: String
        let tone: Tone
        switch order.refundStatusValue {
        case .processing:
            statusTitle = "退款中"
            statusDesc = "退款处理中，请等待机构线下退款并留意确认通知"
            tone = .warn
        case .refunded:
            statusTitle = "已退款"
            statusDesc = "退款 \(OrderItem.fenToYuan(order.refunds?.first?.amount ?? 0))，请确认是否已收到"
            tone = .brand
        case .rejected:
            statusTitle = "退款已驳回"
            statusDesc = "退款申请未通过，如有疑问请联系机构"
            tone = .danger
        case .none:
            switch order.statusValue {
            case .pendingCollect:
                if let rejected = order.rejectedPayment, let reason = rejected.reject_reason, !reason.isEmpty {
                    statusTitle = "凭证未通过"
                    statusDesc = "原因：\(reason)\n请重新上传付款凭证"
                    tone = .danger
                } else if order.latestPayment?.statusValue == .pending {
                    statusTitle = "待机构确认"
                    statusDesc = "付款凭证已提交，等待机构确认，确认后课时自动到账"
                    tone = .warn
                } else {
                    statusTitle = "待付款"
                    statusDesc = "请与机构线下完成付款，并上传付款凭证；机构确认后发放课时"
                    tone = .warn
                }
            case .collected:
                statusTitle = "已报名 · 学习中"
                statusDesc = "已完成\(order.consumed_lessons ?? 0)/\(order.total_lessons ?? 0)节 · 剩余\(order.remaining_lessons ?? 0)节"
                tone = .brand
            case .cancelled:
                statusTitle = "已取消"
                statusDesc = "订单已取消，可重新报名"
                tone = .muted
            }
        }
        statusRow = .status(title: statusTitle, desc: statusDesc, tone: tone)
        courseRow = .course(title: order.courseTitleWithLessons, subtitle: order.studioClassText)

        // 订单信息
        infoRows = [.row(title: "订单号", value: order.order_no ?? "-", brand: false)]
        if let source = order.source_text, !source.isEmpty {
            infoRows.append(.row(title: "报名来源", value: source, brand: false))
        }
        if let className = order.class?.name, !className.isEmpty {
            infoRows.append(.row(title: "上课班级", value: className, brand: false))
        }
        infoRows.append(.row(title: "下单时间",
                             value: String((order.created_at ?? "-").replacingOccurrences(of: "T", with: " ").prefix(16)),
                             brand: false))
        infoRows.append(.row(title: "课程费用", value: OrderItem.fenToYuan(order.total_amount ?? 0), brand: false))
        if order.statusValue == .collected {
            let method = order.pay_method_text ?? order.latestPayment?.methodText
            infoRows.append(.row(title: "实付金额", value: OrderItem.fenToYuan(order.paid_amount ?? order.total_amount ?? 0), brand: true))
            if let method, !method.isEmpty {
                infoRows.append(.row(title: "付款方式", value: method, brand: false))
            }
        }

        // 课时进度（已收款 / 退款态才有课时）
        if order.statusValue == .collected || order.refundStatusValue != .none {
            let consumed = order.consumed_lessons ?? 0
            let total = order.total_lessons ?? 0
            let remaining = order.remaining_lessons ?? max(total - consumed, 0)
            let refundHint = order.statusValue == .collected
                ? "\(remaining)节 · 约可退\(OrderItem.fenToYuan(estimatedRefund(order)))"
                : "\(remaining)节"
            progressRows = [
                .row(title: "已上课时", value: "\(consumed)节（已消课）", brand: false),
                .row(title: "剩余课时", value: refundHint, brand: order.statusValue == .collected)
            ]
        }

        // 组装分组
        sections = [.status, .course, .info]
        if !paymentItems.isEmpty { sections.append(.payments) }
        if !progressRows.isEmpty { sections.append(.progress) }

        tableView.reloadData()
        updateBottomBar(order)
    }

    private func updateBottomBar(_ order: OrderItem) {
        // 每次先重置主按钮为可点的主题样式（凭证审核中会临时置灰）
        primaryButton.isEnabled = true
        primaryButton.backgroundColor = Theme.Color.brand
        primaryButton.setTitleColor(.white, for: .normal)
        primaryButton.setTitleColor(Theme.Color.sub, for: .disabled)

        if order.refundStatusValue != .none {
            if order.refundStatusValue == .rejected {
                secondaryButton.isHidden = false
                secondaryButton.setTitle("再次申请退款", for: .normal)
                primaryButton.setTitle("查看退款", for: .normal)
            } else {
                secondaryButton.isHidden = true
                primaryButton.setTitle(order.refundStatusValue == .processing ? "查看退款进度" : "查看退款", for: .normal)
            }
            primaryButton.isEnabled = true
            return
        }
        secondaryButton.isHidden = false
        switch order.statusValue {
        case .pendingCollect:
            if order.isVoucherUnderReview {
                // 凭证审核中：不可重复上传、不可取消，仅展示等待状态
                secondaryButton.isHidden = true
                primaryButton.setTitle("凭证审核中 · 等待机构确认", for: .normal)
                primaryButton.backgroundColor = Theme.Color.line
                primaryButton.isEnabled = false
            } else {
                let hasRejected = order.rejectedPayment != nil
                secondaryButton.setTitle("取消订单", for: .normal)
                primaryButton.setTitle(hasRejected ? "重新上传凭证" : "上传付款凭证", for: .normal)
                primaryButton.isEnabled = true
            }
        case .collected:
            primaryButton.setTitle("去学习", for: .normal)
            primaryButton.isEnabled = true
            if order.can_apply_refund == true {
                secondaryButton.setTitle("申请退款", for: .normal)
                secondaryButton.isHidden = false
            } else {
                secondaryButton.isHidden = true
            }
        case .cancelled:
            primaryButton.setTitle("重新报名", for: .normal)
            primaryButton.isEnabled = true
            secondaryButton.isHidden = true
        }
    }

    private func estimatedRefund(_ order: OrderItem) -> Int {
        let total = order.total_lessons ?? 0
        let remaining = order.remaining_lessons ?? 0
        let paid = order.paid_amount ?? order.total_amount ?? 0
        guard total > 0 else { return 0 }
        return Int((Double(paid) * Double(remaining) / Double(total)).rounded())
    }

    // MARK: - Actions

    @objc private func didTapPrimary() {
        guard let order else { return }
        if order.refundStatusValue != .none {
            guard let refundId = order.latestRefundId else {
                showToast("退款单不存在"); return
            }
            navigationController?.pushViewController(RefundDetailViewController(refundId: refundId), animated: true)
            return
        }
        switch order.statusValue {
        case .pendingCollect:
            let vc = PaymentVoucherViewController(order: order)
            vc.onSubmitted = { [weak self] in self?.loadData() }
            navigationController?.pushViewController(vc, animated: true)
        case .collected:
            goStudy(order)
        case .cancelled:
            guard let courseId = order.course?.course_id else {
                showToast("课程信息缺失"); return
            }
            navigationController?.pushViewController(CourseEnrollViewController(courseId: courseId), animated: true)
        }
    }

    private func goStudy(_ order: OrderItem) {
        guard let courseId = order.course?.course_id, let childId = order.child?.child_id else {
            showToast("课程信息缺失"); return
        }
        let vc = CourseStudyViewController(
            childId: childId,
            courseId: courseId,
            courseTitle: order.course?.title ?? "课程学习"
        )
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func didTapSecondary() {
        guard let order, let orderId = order.order_id else { return }
        if order.refundStatusValue == .rejected {
            let vc = OrderRefundViewController(order: order) { [weak self] in self?.loadData() }
            navigationController?.pushViewController(vc, animated: true)
            return
        }
        guard order.refundStatusValue == .none else { return }
        switch order.statusValue {
        case .pendingCollect:
            ThemeAlertView.show(
                title: "取消订单",
                message: "确定取消该待付款订单吗？",
                confirmTitle: "取消订单",
                cancelTitle: "再想想",
                onConfirm: { [weak self] in self?.cancelOrder(orderId) }
            )
        case .collected:
            let vc = OrderRefundViewController(order: order) { [weak self] in self?.loadData() }
            navigationController?.pushViewController(vc, animated: true)
        case .cancelled:
            break
        }
    }

    private func cancelOrder(_ orderId: String) {
        showLoading()
        OrderService.cancelOrder(orderId: orderId) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success:
                self.showToast("订单已取消")
                self.loadData()
            case .failure(let error):
                self.showToast(error.message ?? "取消失败")
            }
        }
    }
}

// MARK: - DataSource / Delegate

extension OrderDetailViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    private func sectionKind(_ index: Int) -> Section { sections[index] }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sectionKind(section) {
        case .status: return statusRow == nil ? 0 : 1
        case .course: return courseRow == nil ? 0 : 1
        case .info: return infoRows.count
        case .payments: return paymentItems.count
        case .progress: return progressRows.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sectionKind(indexPath.section) {
        case .status:
            let cell = tableView.dequeueReusableCell(withIdentifier: OrderDetailCell.reuseID, for: indexPath) as! OrderDetailCell
            if let statusRow { cell.configure(with: statusRow) }
            return cell
        case .course:
            let cell = tableView.dequeueReusableCell(withIdentifier: OrderDetailCell.reuseID, for: indexPath) as! OrderDetailCell
            if let courseRow { cell.configure(with: courseRow) }
            return cell
        case .info:
            let cell = tableView.dequeueReusableCell(withIdentifier: OrderDetailCell.reuseID, for: indexPath) as! OrderDetailCell
            cell.configure(with: infoRows[indexPath.row])
            return cell
        case .payments:
            let cell = tableView.dequeueReusableCell(withIdentifier: PaymentRecordCell.reuseID, for: indexPath) as! PaymentRecordCell
            cell.configure(with: paymentItems[indexPath.row])
            cell.onTapImage = { [weak self] images, index in
                let preview = ImagePreviewViewController(images: images, startIndex: index)
                self?.navigationController?.pushViewController(preview, animated: true)
            }
            return cell
        case .progress:
            let cell = tableView.dequeueReusableCell(withIdentifier: OrderDetailCell.reuseID, for: indexPath) as! OrderDetailCell
            cell.configure(with: progressRows[indexPath.row])
            return cell
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch sectionKind(section) {
        case .status, .course: return nil
        case .info: return Self.headerTitle("订单信息")
        case .payments: return Self.headerTitle("付款记录")
        case .progress: return Self.headerTitle("课时进度")
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch sectionKind(section) {
        case .status: return 8
        case .course: return 8
        default: return 38
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 1 }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { UIView() }

    private static func headerTitle(_ text: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        let label = UILabel()
        label.text = text
        label.font = .appBody(15)
        label.textColor = Theme.Color.sub
        container.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(4)
            $0.centerY.equalToSuperview()
        }
        return container
    }
}

// MARK: - 通用内容 Cell

final class OrderDetailCell: UITableViewCell {

    static let reuseID = "OrderDetailCell"

    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let stack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Theme.Color.surface
        contentView.backgroundColor = Theme.Color.surface
        stack.axis = .vertical
        stack.spacing = 6
        contentView.addSubview(stack)
        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with row: OrderDetailViewController.RowType) {
        titleLabel.snp.removeConstraints()
        valueLabel.snp.removeConstraints()
        stack.snp.removeConstraints()
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        titleLabel.isHidden = true
        valueLabel.isHidden = true
        stack.isHidden = true

        switch row {
        case .status(let title, let desc, let tone):
            stack.isHidden = false
            let statusLabel = UILabel()
            statusLabel.text = title
            statusLabel.font = .appSection(17)
            statusLabel.textColor = Self.toneColor(tone)
            let descLabel = UILabel()
            descLabel.text = desc
            descLabel.font = .appLabel(13)
            descLabel.textColor = Theme.Color.sub
            descLabel.numberOfLines = 0
            stack.addArrangedSubview(statusLabel)
            stack.addArrangedSubview(descLabel)
            stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(Theme.Spacing.l) }

        case .course(let title, let subtitle):
            stack.isHidden = false
            let courseLabel = UILabel()
            courseLabel.text = title
            courseLabel.font = .appSection(16)
            courseLabel.textColor = Theme.Color.ink
            courseLabel.numberOfLines = 2
            let studioLabel = UILabel()
            studioLabel.text = subtitle
            studioLabel.font = .appLabel(13)
            studioLabel.textColor = Theme.Color.sub
            studioLabel.numberOfLines = 2
            stack.addArrangedSubview(courseLabel)
            stack.addArrangedSubview(studioLabel)
            stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(Theme.Spacing.l) }

        case .row(let title, let value, let brand):
            titleLabel.isHidden = false
            valueLabel.isHidden = false
            titleLabel.text = title
            titleLabel.font = .appLabel(14)
            titleLabel.textColor = Theme.Color.sub
            valueLabel.text = value
            valueLabel.font = .appBody(14)
            valueLabel.textColor = brand ? Theme.Color.clay : Theme.Color.ink
            valueLabel.textAlignment = .right
            valueLabel.numberOfLines = 0
            valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            titleLabel.snp.makeConstraints {
                $0.leading.equalToSuperview().inset(Theme.Spacing.l)
                $0.top.equalToSuperview().inset(13)
                $0.bottom.lessThanOrEqualToSuperview().inset(13)
            }
            valueLabel.snp.makeConstraints {
                $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
                $0.centerY.equalTo(titleLabel)
                $0.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Theme.Spacing.m)
                $0.top.bottom.equalToSuperview().inset(13)
            }
        }
    }

    static func toneColor(_ tone: OrderDetailViewController.Tone) -> UIColor {
        switch tone {
        case .brand: return Theme.Color.brand
        case .warn: return Theme.Color.warn
        case .danger: return Theme.Color.danger
        case .muted: return Theme.Color.sub
        }
    }
}

// MARK: - 付款记录 Cell

final class PaymentRecordCell: UITableViewCell {
    static let reuseID = "PaymentRecordCell"
    var onTapImage: (([String], Int) -> Void)?

    private let methodLabel = UILabel()
    private let amountLabel = UILabel()
    private let statusBadge = PaddingLabel()
    private let metaLabel = UILabel()
    private let noteLabel = UILabel()
    private let rejectLabel = UILabel()
    private let imageScroll = UIScrollView()
    private let imageStack = UIStackView()
    private var imageUrls: [String] = []

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Theme.Color.surface
        contentView.backgroundColor = Theme.Color.surface

        methodLabel.font = .appBody(15)
        methodLabel.textColor = Theme.Color.ink
        amountLabel.font = .appSection(16)
        amountLabel.textColor = Theme.Color.clay
        amountLabel.textAlignment = .right

        statusBadge.font = .appLabel(11)
        statusBadge.layer.cornerRadius = 6
        statusBadge.clipsToBounds = true
        statusBadge.textAlignment = .center

        metaLabel.font = .appLabel(12)
        metaLabel.textColor = Theme.Color.muted

        noteLabel.font = .appLabel(13)
        noteLabel.textColor = Theme.Color.sub
        noteLabel.numberOfLines = 0

        rejectLabel.font = .appLabel(13)
        rejectLabel.textColor = Theme.Color.danger
        rejectLabel.numberOfLines = 0

        imageScroll.showsHorizontalScrollIndicator = false
        imageStack.axis = .horizontal
        imageStack.spacing = 8
        imageScroll.addSubview(imageStack)

        [methodLabel, amountLabel, statusBadge, metaLabel, noteLabel, rejectLabel, imageScroll].forEach {
            contentView.addSubview($0)
        }
        methodLabel.snp.makeConstraints {
            $0.top.equalToSuperview().inset(Theme.Spacing.l)
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
        }
        amountLabel.snp.makeConstraints {
            $0.centerY.equalTo(methodLabel)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.leading.greaterThanOrEqualTo(methodLabel.snp.trailing).offset(8)
        }
        statusBadge.snp.makeConstraints {
            $0.top.equalTo(methodLabel.snp.bottom).offset(8)
            $0.leading.equalTo(methodLabel)
            $0.height.equalTo(20)
        }
        metaLabel.snp.makeConstraints {
            $0.centerY.equalTo(statusBadge)
            $0.leading.equalTo(statusBadge.snp.trailing).offset(8)
            $0.trailing.lessThanOrEqualToSuperview().inset(Theme.Spacing.l)
        }
        noteLabel.snp.makeConstraints {
            $0.top.equalTo(statusBadge.snp.bottom).offset(8)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        rejectLabel.snp.makeConstraints {
            $0.top.equalTo(noteLabel.snp.bottom).offset(6)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        imageScroll.snp.makeConstraints {
            $0.top.equalTo(rejectLabel.snp.bottom).offset(10)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(0)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
        imageStack.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.height.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with payment: PaymentItem) {
        methodLabel.text = payment.methodText
        amountLabel.text = OrderItem.fenToYuan(payment.amount ?? 0)

        let status = payment.statusValue
        statusBadge.text = "  \(payment.status_text ?? status.text)  "
        switch status {
        case .confirmed:
            statusBadge.textColor = Theme.Color.brand
            statusBadge.backgroundColor = Theme.Color.brandSoft
        case .pending:
            statusBadge.textColor = Theme.Color.warn
            statusBadge.backgroundColor = Theme.Color.warnTint
        case .rejected:
            statusBadge.textColor = Theme.Color.danger
            statusBadge.backgroundColor = Theme.Color.dangerTint
        }

        let who = payment.isFromStudio ? "工作室代登记" : "家长上传"
        metaLabel.text = "\(who) · \(payment.timeText)"

        if let note = payment.payer_note, !note.isEmpty {
            noteLabel.isHidden = false
            noteLabel.text = "备注：\(note)"
        } else {
            noteLabel.isHidden = true
        }
        if let reason = payment.reject_reason, !reason.isEmpty, status == .rejected {
            rejectLabel.isHidden = false
            rejectLabel.text = "未通过：\(reason)"
        } else {
            rejectLabel.isHidden = true
        }

        // 凭证缩略图
        imageStack.arrangedSubviews.forEach {
            imageStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        imageUrls = payment.images
        if imageUrls.isEmpty {
            imageScroll.snp.updateConstraints { $0.height.equalTo(0) }
        } else {
            imageScroll.snp.updateConstraints { $0.height.equalTo(56) }
            for (idx, urlStr) in imageUrls.enumerated() {
                let iv = UIImageView()
                iv.contentMode = .scaleAspectFill
                iv.clipsToBounds = true
                iv.layer.cornerRadius = 8
                iv.isUserInteractionEnabled = true
                iv.kf.setImage(with: URL(string: urlStr), placeholder: UIImage(systemName: "photo"))
                iv.tag = idx
                let tap = UITapGestureRecognizer(target: self, action: #selector(didTapImage(_:)))
                iv.addGestureRecognizer(tap)
                imageStack.addArrangedSubview(iv)
                iv.snp.makeConstraints { $0.width.height.equalTo(56) }
            }
        }
        needsUpdateConstraints()
    }

    @objc private func didTapImage(_ gesture: UITapGestureRecognizer) {
        guard let idx = gesture.view?.tag else { return }
        onTapImage?(imageUrls, idx)
    }
}
