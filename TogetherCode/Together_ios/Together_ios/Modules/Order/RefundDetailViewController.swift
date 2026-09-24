import UIKit
import SnapKit
import Kingfisher

/// 退款详情（家长端）
/// 状态流转：提交申请(0待审核) → 机构审核并线下退款(1待家长确认) → 家长确认收到(3已退款)；驳回为 2
final class RefundDetailViewController: BaseViewController {

    private let refundId: String
    private var detail: RefundDetail?

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let bottomBar = UIView()
    private let confirmButton = UIButton(type: .system)
    private var bottomBarTopConstraint: Constraint?

    private enum SectionKind { case status, info, voucher, steps }

    init(refundId: String) {
        self.refundId = refundId
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureImmersiveNav(title: "退款详情")
        setupBottomBar()
        setupTableView()
        loadData()
    }

    private var hasVoucher: Bool {
        !(detail?.voucher_images ?? []).isEmpty
    }

    private func sectionKind(_ section: Int) -> SectionKind {
        switch section {
        case 0: return .status
        case 1: return .info
        case 2: return hasVoucher ? .voucher : .steps
        default: return .steps
        }
    }

    private func setupTableView() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.alwaysBounceVertical = true
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 46
        tableView.register(RefundStatusCell.self, forCellReuseIdentifier: RefundStatusCell.reuseID)
        tableView.register(RefundRowCell.self, forCellReuseIdentifier: RefundRowCell.reuseID)
        tableView.register(RefundVoucherCell.self, forCellReuseIdentifier: RefundVoucherCell.reuseID)
        tableView.register(RefundStepCell.self, forCellReuseIdentifier: RefundStepCell.reuseID)
        tableView.contentInset = UIEdgeInsets(top: Theme.Spacing.s, left: 0, bottom: 24, right: 0)
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
        bottomBar.isHidden = true
        view.addSubview(bottomBar)
        bottomBar.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            self.bottomBarTopConstraint = $0.top.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(0).constraint
        }

        confirmButton.titleLabel?.font = .appBody(15)
        confirmButton.setTitle("确认收到退款", for: .normal)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.backgroundColor = Theme.Color.brand
        confirmButton.layer.cornerRadius = 22
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        bottomBar.addSubview(confirmButton)
        confirmButton.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(44)
        }
    }

    private func reloadBottomBar() {
        let show = detail?.can_confirm == true
        bottomBar.isHidden = !show
        bottomBarTopConstraint?.update(offset: show ? -64 : 0)
    }

    private func loadData() {
        showLoading()
        OrderService.fetchRefundDetail(refundId: refundId) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success(let detail):
                self.detail = detail
                self.tableView.reloadData()
                self.reloadBottomBar()
            case .failure(let error):
                self.showToast(error.message ?? "加载失败")
            }
        }
    }

    @objc private func confirmTapped() {
        view.endEditing(true)
        ThemeAlertView.show(
            title: "请确认已收到退款",
            message: "请确认你已在线下实际收到机构退回的款项。确认后将扣减相应课时、订单转为已退款，且不可撤销。",
            confirmTitle: "已收到，确认",
            cancelTitle: "再想想",
            onConfirm: { [weak self] in self?.submitConfirm() }
        )
    }

    private func submitConfirm() {
        confirmButton.isEnabled = false
        confirmButton.setTitle("提交中…", for: .normal)
        OrderService.confirmRefund(refundId: refundId) { [weak self] result in
            guard let self else { return }
            self.confirmButton.isEnabled = true
            self.confirmButton.setTitle("确认收到退款", for: .normal)
            switch result {
            case .success(let detail):
                self.detail = detail
                self.tableView.reloadData()
                self.reloadBottomBar()
                self.showToast("已确认收款")
            case .failure(let error):
                self.showToast(error.message ?? "确认失败，请稍后重试")
            }
        }
    }
}

// MARK: - DataSource / Delegate

extension RefundDetailViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        guard detail != nil else { return 0 }
        return hasVoucher ? 4 : 3
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sectionKind(section) {
        case .status: return 1
        case .info: return infoRows().count
        case .voucher: return 1
        case .steps: return detail?.steps?.count ?? 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sectionKind(indexPath.section) {
        case .status:
            let cell = tableView.dequeueReusableCell(withIdentifier: RefundStatusCell.reuseID, for: indexPath) as! RefundStatusCell
            cell.configure(detail)
            return cell
        case .info:
            let cell = tableView.dequeueReusableCell(withIdentifier: RefundRowCell.reuseID, for: indexPath) as! RefundRowCell
            let row = infoRows()[indexPath.row]
            cell.configure(title: row.0, value: row.1, color: row.2)
            return cell
        case .voucher:
            let cell = tableView.dequeueReusableCell(withIdentifier: RefundVoucherCell.reuseID, for: indexPath) as! RefundVoucherCell
            let images = detail?.voucher_images ?? []
            cell.configure(images: images) { [weak self] index in
                let resolved = images.map { $0.resolvedImageURL }
                let preview = ImagePreviewViewController(images: resolved, startIndex: index)
                self?.present(preview, animated: true)
            }
            return cell
        case .steps:
            let cell = tableView.dequeueReusableCell(withIdentifier: RefundStepCell.reuseID, for: indexPath) as! RefundStepCell
            if let step = detail?.steps?[indexPath.row] {
                cell.configure(step, isLast: indexPath.row == (detail?.steps?.count ?? 1) - 1)
            }
            return cell
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch sectionKind(indexPath.section) {
        case .status: return UITableView.automaticDimension
        case .info: return UITableView.automaticDimension
        case .voucher: return 112
        case .steps: return 64
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let kind = sectionKind(section)
        guard kind != .status, let title = sectionTitle(kind) else { return nil }
        let container = UIView()
        container.backgroundColor = .clear
        let label = UILabel()
        label.text = title
        label.font = .appBody(16)
        label.textColor = Theme.Color.ink
        container.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.centerY.equalToSuperview()
        }
        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        sectionKind(section) == .status ? 0 : 40
    }

    private func sectionTitle(_ kind: SectionKind) -> String? {
        switch kind {
        case .info: return "退款信息"
        case .voucher: return "机构打款凭证"
        case .steps: return "退款进度"
        default: return nil
        }
    }

    private func infoRows() -> [(String, String, UIColor)] {
        guard let detail else { return [] }
        var rows: [(String, String, UIColor)] = []
        rows.append(("申请课时", "\(detail.requested_lessons ?? 0)节（可退 \(detail.refundable_lessons ?? 0)节）", Theme.Color.ink))
        if let approved = detail.approved_lessons {
            let requested = detail.requested_lessons ?? approved
            if approved < requested {
                rows.append(("本次实退", "\(approved)节（申请\(requested)节，期间已上课）", Theme.Color.warn))
            } else {
                rows.append(("本次实退", "\(approved)节", Theme.Color.brand))
            }
        }
        if let method = detail.refund_method_text, !method.isEmpty {
            rows.append(("退款方式", method, Theme.Color.ink))
        }
        if let unit = detail.unit_price_text {
            rows.append(("课时单价", unit, Theme.Color.ink))
        }
        rows.append(("退款金额", detail.amount_text ?? "-", Theme.Color.brand))
        if detail.status == 2, let reject = detail.reject_reason, !reject.isEmpty {
            rows.append(("驳回原因", reject, Theme.Color.danger))
        }
        if let reason = detail.reason, !reason.isEmpty {
            rows.append(("退款原因", reason, Theme.Color.ink))
        }
        if let time = Self.fmt(detail.created_at) {
            rows.append(("申请时间", time, Theme.Color.ink))
        }
        if let time = Self.fmt(detail.reviewed_at) {
            rows.append(("审核时间", time, Theme.Color.ink))
        }
        if let time = Self.fmt(detail.confirmed_at) {
            rows.append(("确认时间", time, Theme.Color.ink))
        }
        return rows
    }

    private static func fmt(_ raw: String?) -> String? {
        guard let raw else { return nil }
        return raw.replacingOccurrences(of: "T", with: " ").prefix(16).description
    }
}

// MARK: - 状态卡 Cell

private final class RefundStatusCell: UITableViewCell {

    static let reuseID = "RefundStatusCell"

    private let statusLabel = UILabel()
    private let amountLabel = UILabel()
    private let descLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Theme.Color.surface
        contentView.backgroundColor = Theme.Color.surface

        statusLabel.font = .appSection(17)
        statusLabel.textColor = Theme.Color.brand
        amountLabel.font = .appSection(22)
        amountLabel.textColor = Theme.Color.ink
        descLabel.font = .appLabel(13)
        descLabel.textColor = Theme.Color.sub
        descLabel.numberOfLines = 0

        contentView.addSubview(statusLabel)
        contentView.addSubview(amountLabel)
        contentView.addSubview(descLabel)
        statusLabel.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        amountLabel.snp.makeConstraints {
            $0.top.equalTo(statusLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        descLabel.snp.makeConstraints {
            $0.top.equalTo(amountLabel.snp.bottom).offset(2)
            $0.leading.trailing.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ detail: RefundDetail?) {
        guard let detail else { return }
        statusLabel.text = detail.status_text ?? "退款"
        amountLabel.text = detail.amount_text ?? "-"
        let desc: String
        switch detail.status {
        case 0:
            desc = "退款申请已提交，等待机构审核"
            statusLabel.textColor = Theme.Color.brand
        case 1:
            desc = "机构已登记线下退款，请核对下方凭证后，点击底部「确认收到退款」"
            statusLabel.textColor = Theme.Color.brand
        case 2:
            desc = "申请未通过，可查看驳回原因后在订单详情重新申请"
            statusLabel.textColor = Theme.Color.danger
        case 3:
            desc = "退款已完成，相应课时已扣减"
            statusLabel.textColor = Theme.Color.brand
        default:
            desc = "退款处理中，请留意到账通知"
            statusLabel.textColor = Theme.Color.brand
        }
        descLabel.text = desc
    }
}

// MARK: - 信息行 Cell（标题 / 值，值可多行、可着色）

private final class RefundRowCell: UITableViewCell {

    static let reuseID = "RefundRowCell"

    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Theme.Color.surface
        contentView.backgroundColor = Theme.Color.surface

        titleLabel.font = .appLabel(14)
        titleLabel.textColor = Theme.Color.sub
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueLabel.font = .appBody(14)
        valueLabel.textColor = Theme.Color.ink
        valueLabel.textAlignment = .right
        valueLabel.numberOfLines = 0

        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalToSuperview().offset(12)
            $0.bottom.lessThanOrEqualToSuperview().offset(-12)
        }
        valueLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(12)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().offset(-12)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, value: String, color: UIColor) {
        titleLabel.text = title
        valueLabel.text = value
        valueLabel.textColor = color
    }
}

// MARK: - 打款凭证横向缩略图 Cell

private final class RefundVoucherCell: UITableViewCell {

    static let reuseID = "RefundVoucherCell"

    private let scrollView = UIScrollView()
    private var imageViews: [UIImageView] = []
    private var onTap: ((Int) -> Void)?

    private let itemSize: CGFloat = 88
    private let itemSpacing: CGFloat = 12

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Theme.Color.surface
        contentView.backgroundColor = Theme.Color.surface

        scrollView.showsHorizontalScrollIndicator = false
        contentView.addSubview(scrollView)
        scrollView.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(12)
            $0.leading.trailing.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(images: [String], onTap: @escaping (Int) -> Void) {
        imageViews.forEach { $0.removeFromSuperview() }
        imageViews.removeAll()
        self.onTap = onTap

        for (index, path) in images.enumerated() {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 10
            imageView.isUserInteractionEnabled = true
            imageView.tag = index
            imageView.kf.setImage(
                with: URL(string: path.resolvedImageURL),
                placeholder: WorkCardView.gradientPlaceholder(colors: [Theme.Color.surfaceAlt, Theme.Color.line])
            )
            imageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(imageTapped(_:))))
            scrollView.addSubview(imageView)
            imageViews.append(imageView)

            imageView.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.width.height.equalTo(itemSize)
                make.left.equalToSuperview().offset(CGFloat(index) * (itemSize + itemSpacing) + Theme.Spacing.l)
                if index == images.count - 1 {
                    make.right.equalToSuperview().offset(-Theme.Spacing.l)
                }
            }
        }
    }

    @objc private func imageTapped(_ gesture: UITapGestureRecognizer) {
        guard let index = gesture.view?.tag else { return }
        onTap?(index)
    }
}

// MARK: - 时间线 Cell

private final class RefundStepCell: UITableViewCell {

    static let reuseID = "RefundStepCell"

    private let dot = UIView()
    private let line = UIView()
    private let titleLabel = UILabel()
    private let timeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Theme.Color.surface
        contentView.backgroundColor = Theme.Color.surface

        dot.layer.cornerRadius = 5
        contentView.addSubview(dot)
        dot.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalToSuperview().offset(18)
            $0.width.height.equalTo(10)
        }

        line.backgroundColor = Theme.Color.line
        contentView.addSubview(line)
        line.snp.makeConstraints {
            $0.centerX.equalTo(dot)
            $0.top.equalTo(dot.snp.bottom)
            $0.bottom.equalToSuperview()
            $0.width.equalTo(2)
        }

        titleLabel.font = .appBody(15)
        titleLabel.textColor = Theme.Color.ink
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(dot.snp.trailing).offset(Theme.Spacing.m)
            $0.top.equalToSuperview().offset(12)
        }

        timeLabel.font = .appLabel(12)
        timeLabel.textColor = Theme.Color.sub
        contentView.addSubview(timeLabel)
        timeLabel.snp.makeConstraints {
            $0.leading.equalTo(titleLabel)
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ step: RefundStep, isLast: Bool) {
        titleLabel.text = step.title ?? ""
        titleLabel.textColor = (step.current == true || step.done == true) ? Theme.Color.ink : Theme.Color.sub
        dot.backgroundColor = (step.current == true || step.done == true) ? Theme.Color.brand : Theme.Color.line
        line.isHidden = isLast
        if let time = step.time?.replacingOccurrences(of: "T", with: " ").prefix(16).description {
            timeLabel.text = String(time)
        } else {
            timeLabel.text = (step.current == true) ? "等待处理中" : "-"
        }
    }
}
