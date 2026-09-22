import UIKit
import SnapKit
import Kingfisher
import ESPullToRefresh

/// 工作室 App 端 · 退款审核
/// 状态分段：待审核(0) / 待打款(1) / 已驳回(2) / 已打款(3)
/// - 待审核：同意退款（→待打款）/ 拒绝并留言（→已驳回）
/// - 待打款：工作室线下打款后「确认已打款」（→已打款，此时才扣课时）
final class StudioRefundViewController: BaseViewController {

    private struct Tab {
        let title: String
        let status: Int
        let empty: String
    }

    private let tabs: [Tab] = [
        Tab(title: "待审核", status: 0, empty: "暂无待审核退款"),
        Tab(title: "待打款", status: 1, empty: "暂无待打款退款"),
        Tab(title: "已驳回", status: 2, empty: "暂无已驳回退款"),
        Tab(title: "已打款", status: 3, empty: "暂无已打款退款")
    ]

    private var currentStatus: Int
    private var refunds: [StudioRefund] = []
    private var chipRow: TagChipRow?
    private var firstLoad = true

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = EmptyStateView()

    init(initialStatus: Int = 0) {
        self.currentStatus = initialStatus
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "退款审核")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg

        let chipRow = TagChipRow(
            chips: tabs.map(\.title),
            selectedIndex: max(0, tabs.firstIndex { $0.status == currentStatus } ?? 0)
        )
        chipRow.onSelect = { [weak self] index in
            guard let self else { return }
            self.currentStatus = self.tabs[index].status
            self.loadData()
        }
        view.addSubview(chipRow)
        chipRow.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.height.equalTo(34)
        }
        self.chipRow = chipRow

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(StudioRefundCell.self, forCellReuseIdentifier: StudioRefundCell.reuseID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 220
        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.loadData()
        }
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(chipRow.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        emptyView.isHidden = true
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.centerX.equalTo(tableView)
            $0.centerY.equalTo(tableView)
        }
    }

    private func currentTab() -> Tab {
        tabs.first { $0.status == currentStatus } ?? tabs[0]
    }

    private func loadData() {
        if firstLoad { emptyView.show(style: .loading) }
        StudioService.fetchRefunds(status: currentStatus) { [weak self] result in
            guard let self else { return }
            self.firstLoad = false
            self.tableView.es.stopPullToRefresh()
            switch result {
            case .success(let list):
                self.refunds = list
                self.tableView.reloadData()
                let isEmpty = list.isEmpty
                self.emptyView.isHidden = !isEmpty
                if isEmpty { self.emptyView.show(style: .empty(self.currentTab().empty)) }
            case .failure(let error):
                self.emptyView.isHidden = false
                self.emptyView.show(style: .error(error.message ?? "加载失败") { [weak self] in
                    self?.loadData()
                })
            }
        }
    }

    // MARK: - 审核操作

    private func approve(_ refund: StudioRefund) {
        ThemeAlertView.show(
            title: "同意退款",
            message: "确认通过「\(refund.parentName)」的退款申请？\n通过后进入待打款，课时将在确认打款后扣减。",
            confirmTitle: "同意退款",
            cancelTitle: "再想想",
            onConfirm: { [weak self] in
                self?.submit(refund, action: "approve")
            }
        )
    }

    private func reject(_ refund: StudioRefund) {
        ThemeInputAlertView.show(
            title: "拒绝并留言",
            placeholder: "请填写拒绝原因（家长可见）",
            maxCount: 100,
            confirmTitle: "确认拒绝",
            onConfirm: { [weak self] reason in
                self?.submit(refund, action: "reject", reason: reason)
            }
        )
    }

    private func confirmPaid(_ refund: StudioRefund) {
        ThemeAlertView.show(
            title: "确认已打款",
            message: "确认已向「\(refund.parentName)」完成退款 \(refund.amountText)？\n确认后将扣减相应课时，不可撤销。",
            confirmTitle: "确认打款",
            cancelTitle: "取消",
            onConfirm: { [weak self] in
                self?.submit(refund, action: "confirm")
            }
        )
    }

    private func submit(_ refund: StudioRefund, action: String, reason: String? = nil) {
        showLoading()
        StudioService.reviewRefund(refundId: refund.refund_id, action: action, reason: reason) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success:
                let msg: String
                switch action {
                case "approve": msg = "已通过，请及时打款"
                case "reject": msg = "已驳回"
                default: msg = "打款已确认"
                }
                self.showToast(msg)
                self.loadData()
            case .failure(let error):
                self.showToast(error.message ?? "操作失败")
            }
        }
    }
}

extension StudioRefundViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        refunds.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: StudioRefundCell.reuseID, for: indexPath) as! StudioRefundCell
        let refund = refunds[indexPath.row]
        cell.configure(refund)
        cell.onApprove = { [weak self] in self?.approve(refund) }
        cell.onReject = { [weak self] in self?.reject(refund) }
        cell.onConfirm = { [weak self] in self?.confirmPaid(refund) }
        return cell
    }
}

// MARK: - 退款卡片

private final class StudioRefundCell: UITableViewCell {
    static let reuseID = "StudioRefundCell"

    var onApprove: (() -> Void)?
    var onReject: (() -> Void)?
    var onConfirm: (() -> Void)?

    private let card = UIView()
    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let subLabel = UILabel()
    private let amountLabel = UILabel()
    private let reasonBar = UIView()
    private let reasonIcon = UIImageView()
    private let reasonLabel = UILabel()
    private let actionWrap = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.top.equalToSuperview().offset(6)
            $0.bottom.equalToSuperview().offset(-6)
        }

        // 头像
        avatarView.contentMode = .scaleAspectFill
        avatarView.layer.cornerRadius = 21
        avatarView.clipsToBounds = true
        avatarView.backgroundColor = Theme.Color.brandSoft
        card.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.leading.top.equalToSuperview().inset(Theme.Spacing.l)
            $0.width.height.equalTo(42)
        }

        // 家长称呼
        nameLabel.font = .appSection(15)
        nameLabel.textColor = Theme.Color.ink
        card.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarView.snp.trailing).offset(Theme.Spacing.m)
            $0.top.equalTo(avatarView).offset(2)
            $0.trailing.lessThanOrEqualToSuperview().inset(96)
        }

        // 副标题：课程 · 剩余 x/y 节 / 时间
        subLabel.font = .appLabel(12)
        subLabel.textColor = Theme.Color.muted
        subLabel.numberOfLines = 2
        card.addSubview(subLabel)
        subLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalTo(nameLabel.snp.bottom).offset(4)
        }

        // 右上金额
        amountLabel.textAlignment = .right
        card.addSubview(amountLabel)
        amountLabel.snp.makeConstraints {
            $0.top.equalTo(avatarView).offset(2)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        // 退款原因条（浅黄）
        reasonBar.backgroundColor = Theme.Color.warnTint
        reasonBar.layer.cornerRadius = Theme.Radius.icon
        card.addSubview(reasonBar)
        reasonBar.snp.makeConstraints {
            $0.top.equalTo(avatarView.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        reasonIcon.image = UIImage(systemName: "text.bubble.fill")
        reasonIcon.tintColor = Theme.Color.warn
        reasonIcon.contentMode = .scaleAspectFit
        reasonBar.addSubview(reasonIcon)
        reasonIcon.snp.makeConstraints {
            $0.leading.top.equalToSuperview().inset(Theme.Spacing.m)
            $0.width.height.equalTo(16)
        }
        reasonLabel.font = .appLabel(12.5)
        reasonLabel.textColor = Theme.Color.sub
        reasonLabel.numberOfLines = 0
        reasonBar.addSubview(reasonLabel)
        reasonLabel.snp.makeConstraints {
            $0.leading.equalTo(reasonIcon.snp.trailing).offset(Theme.Spacing.s)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.top.bottom.equalToSuperview().inset(Theme.Spacing.m)
            $0.centerY.equalTo(reasonIcon)
        }

        // 操作区
        card.addSubview(actionWrap)
        actionWrap.snp.makeConstraints {
            $0.top.equalTo(reasonBar.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    func configure(_ refund: StudioRefund) {
        nameLabel.text = refund.parentName
        if let urlString = refund.parentAvatar, let url = URL(string: urlString) {
            avatarView.kf.setImage(with: url, placeholder: UIImage(named: "avatar_placeholder"))
        } else {
            avatarView.image = UIImage(named: "avatar_placeholder")
        }

        let timeText = StudioRefundTimeText(refund.created_at)
        subLabel.text = "\(refund.courseTitle) · 剩余 \(refund.remaining)/\(refund.totalLessons) 节\n\(timeText)"
        amountLabel.attributedText = StudioRefundAmountText(refund.amountText)

        reasonLabel.text = refund.reasonText.isEmpty ? "家长未填写退款原因" : refund.reasonText

        rebuildActionArea(refund)
        setNeedsLayout()
    }

    private func rebuildActionArea(_ refund: StudioRefund) {
        actionWrap.subviews.forEach { $0.removeFromSuperview() }

        switch refund.status {
        case 0:
            // 待审核：拒绝并留言（描边） + 同意退款（实心）
            let rejectBtn = makeButton(title: "拒绝并留言", filled: false, action: #selector(tapReject))
            let approveBtn = makeButton(title: "同意退款", filled: true, action: #selector(tapApprove))
            actionWrap.addSubview(rejectBtn)
            actionWrap.addSubview(approveBtn)
            rejectBtn.snp.makeConstraints {
                $0.leading.top.bottom.equalToSuperview()
                $0.height.equalTo(40)
            }
            approveBtn.snp.makeConstraints {
                $0.leading.equalTo(rejectBtn.snp.trailing).offset(Theme.Spacing.m)
                $0.trailing.top.bottom.equalToSuperview()
                $0.width.equalTo(rejectBtn)
                $0.height.equalTo(40)
            }
        case 1:
            // 待打款：提示 + 确认已打款
            let tip = UILabel()
            tip.font = .appLabel(12)
            tip.textColor = Theme.Color.success
            tip.text = "审核已通过，请在线下完成打款后点击确认"
            tip.numberOfLines = 0
            let confirmBtn = makeButton(title: "确认已打款", filled: true, action: #selector(tapConfirm))
            actionWrap.addSubview(tip)
            actionWrap.addSubview(confirmBtn)
            tip.snp.makeConstraints {
                $0.top.leading.trailing.equalToSuperview()
            }
            confirmBtn.snp.makeConstraints {
                $0.top.equalTo(tip.snp.bottom).offset(Theme.Spacing.s)
                $0.leading.trailing.bottom.equalToSuperview()
                $0.height.equalTo(40)
            }
        default:
            // 2 已驳回 / 3 已打款：仅状态标签
            let done = refund.status == 3
            let pill = PaddingLabel()
            pill.text = done ? "已打款" : "已驳回"
            pill.font = .appLabel(12)
            pill.textColor = done ? Theme.Color.success : Theme.Color.danger
            pill.backgroundColor = done ? Theme.Color.successTint : Theme.Color.dangerTint
            pill.layer.cornerRadius = 12
            pill.clipsToBounds = true
            pill.textInsets = UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)
            actionWrap.addSubview(pill)
            pill.snp.makeConstraints {
                $0.leading.top.bottom.equalToSuperview()
                $0.height.equalTo(24)
            }
        }
    }

    private func makeButton(title: String, filled: Bool, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .appBody(14)
        btn.layer.cornerRadius = 20
        btn.clipsToBounds = true
        if filled {
            btn.backgroundColor = Theme.Color.brand
            btn.setTitleColor(.white, for: .normal)
        } else {
            btn.backgroundColor = Theme.Color.surface
            btn.setTitleColor(Theme.Color.ink, for: .normal)
            btn.layer.borderWidth = 1
            btn.layer.borderColor = Theme.Color.line.cgColor
        }
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    @objc private func tapApprove() { onApprove?() }
    @objc private func tapReject() { onReject?() }
    @objc private func tapConfirm() { onConfirm?() }
}

// MARK: - 金额 / 时间格式化

/// 金额：¥ 用小字号、数字加粗（设计稿红色 ¥440.00）
private func StudioRefundAmountText(_ text: String) -> NSAttributedString {
    let attr = NSMutableAttributedString(
        string: text,
        attributes: [.font: UIFont.appSection(17), .foregroundColor: Theme.Color.danger]
    )
    if text.hasPrefix("¥") {
        attr.addAttributes(
            [.font: UIFont.appLabel(12), .foregroundColor: Theme.Color.danger],
            range: NSRange(location: 0, length: 1)
        )
    }
    return attr
}

/// 申请时间：今天 HH:mm / 昨天 HH:mm / 本周 周X HH:mm / 今年 MM-dd HH:mm / 更早 yyyy-MM-dd
private func StudioRefundTimeText(_ iso: String?) -> String {
    guard let iso, !iso.isEmpty, let date = StudioRefundParseDate(iso) else { return "" }
    let cal = Calendar.current
    let hmFmt = DateFormatter()
    hmFmt.locale = Locale(identifier: "zh_CN")
    hmFmt.dateFormat = "HH:mm"
    let hm = hmFmt.string(from: date)

    if cal.isDateInToday(date) { return "今天 \(hm)" }
    if cal.isDateInYesterday(date) { return "昨天 \(hm)" }
    let weekday = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"][cal.component(.weekday, from: date) - 1]
    let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: Date())).day ?? 99
    if days < 7 { return "\(weekday) \(hm)" }

    let yearFmt = DateFormatter()
    yearFmt.locale = Locale(identifier: "zh_CN")
    if cal.component(.year, from: date) == cal.component(.year, from: Date()) {
        yearFmt.dateFormat = "MM-dd HH:mm"
    } else {
        yearFmt.dateFormat = "yyyy-MM-dd"
    }
    return yearFmt.string(from: date)
}

private func StudioRefundParseDate(_ iso: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    if let d = formatter.date(from: iso) { return d }
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    return formatter.date(from: iso)
}

/// 带内边距的文本标签（状态 pill / 角标，模块内复用）
final class PaddingLabel: UILabel {
    var textInsets = UIEdgeInsets.zero
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + textInsets.left + textInsets.right,
                      height: size.height + textInsets.top + textInsets.bottom)
    }
}
